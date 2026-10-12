-- 图片/PDF 查看器（等比缩放，普通窗口显示）：
--   · 把整图按等比缩放绘制到"窗口大小的画布"上：=1 适应窗口居中、<1 整图缩小居中、>1 放大后平移查看
--   · 画布像素尺寸与窗口格子一一对应，避免终端把图强行拉伸到整格导致的宽高比失真
--   · +/-/滚轮缩放（0.5x~8x），h/j/k/l 平移，0 适应窗口，q 关闭
--   · PDF 在 Kitty 终端下同样默认按页看图（]p/[p、滚轮翻页，<leader>rt 切文本）
local M = {}

local ZOOMS = { 0.5, 0.75, 1, 1.25, 1.5, 2, 3, 4, 6, 8 }
local PAN_STEP = 0.15

local function cache_dir()
  local dir = vim.fn.stdpath("cache") .. "/nvim-devkit/viewer"
  vim.fn.mkdir(dir, "p")
  return dir
end

local function magick()
  if vim.fn.executable("magick") == 1 then
    return "magick"
  end
  if vim.fn.executable("convert") == 1 then
    return "convert"
  end
end

local function notify(msg, level)
  vim.notify("查看器: " .. msg, level or vim.log.levels.INFO)
end

--- 查看器自己的 place() 调用（用于区分 snacks 自带挂载，见 setup 的包装）
local placing = false

--- SSH(remote) 下 snacks 逐 4KB 发图、每块强制 sleep(1ms)（≈250KB/s 上限）：
--- 查看器触发图片发送时临时把 uv.sleep 变为空操作，LAN 场景下快一到两个数量级
local function without_sleep(fn)
  local uv = vim.uv or vim.loop
  local orig = uv.sleep
  uv.sleep = function() end
  local ret = { pcall(fn) }
  uv.sleep = orig
  return unpack(ret)
end

--- 等比缩放渲染方案（纯函数，供测试）
--- 整图以 s = s0*zoom 的缩放绘制在 canvas 上，画布即窗口像素尺寸；
--- 返回原图取景裁剪、缩放目标、在画布上的落点（全部整数，供 magick 使用）
---@param iw number 原图宽（像素）
---@param ih number 原图高（像素）
---@param pw number 画布宽（像素，=窗口列数×单元格宽）
---@param ph number 画布高（像素）
---@param zoom number 相对于"适应窗口"的倍数
---@param px number 取景中心 x [0,1]
---@param py number 取景中心 y [0,1]
function M._plan(iw, ih, pw, ph, zoom, px, py)
  zoom = zoom or 1
  local s0 = math.min(pw / iw, ph / ih, 1) -- 适应窗口（小图不放大）
  local s = s0 * zoom
  local dw, dh = iw * s, ih * s

  local function clamp_axis(p, disp, canvas)
    if disp <= canvas then
      return 0.5, 0.5, 0.5 -- 整幅可见：锁定居中
    end
    local lo = canvas / (2 * disp)
    return math.max(lo, math.min(1 - lo, p or 0.5)), lo, 1 - lo
  end

  local cx, px_lo, px_hi = clamp_axis(px, dw, pw)
  local cy, py_lo, py_hi = clamp_axis(py, dh, ph)
  local dx = pw / 2 - cx * dw -- 整图左上角在画布中的位置
  local dy = ph / 2 - cy * dh

  -- 画布可见部分对应的原图区域（可能与整图相交）
  local x0 = math.max(0, -dx / s)
  local y0 = math.max(0, -dy / s)
  local x1 = math.min(iw, (pw - dx) / s)
  local y1 = math.min(ih, (ph - dy) / s)
  local fx0, fy0 = math.floor(x0), math.floor(y0)
  local cw = math.max(1, math.ceil(x1) - fx0)
  local ch = math.max(1, math.ceil(y1) - fy0)

  return {
    s = s,
    s0 = s0,
    canvas = { w = pw, h = ph },
    disp = { w = dw, h = dh },
    crop = { x = fx0, y = fy0, w = cw, h = ch },
    resize = { w = math.max(1, math.floor(cw * s + 0.5)), h = math.max(1, math.floor(ch * s + 0.5)) },
    offset = { x = math.floor(dx + fx0 * s + 0.5), y = math.floor(dy + fy0 * s + 0.5) },
    px = cx,
    py = cy,
    px_lo = px_lo,
    px_hi = px_hi,
    py_lo = py_lo,
    py_hi = py_hi,
  }
end

--- 构造渲染命令（纯函数，供测试）：
--- 透明画布 + 裁剪原图 + 等比缩放 + 按落点合成（不用 -extent，其偏移语义反直觉）
function M._render_cmd(cmd, src, out, plan)
  return {
    cmd,
    "-size", ("%dx%d"):format(plan.canvas.w, plan.canvas.h), "xc:none",
    "(",
    src,
    "-crop", ("%dx%d+%d+%d"):format(plan.crop.w, plan.crop.h, plan.crop.x, plan.crop.y), "+repage",
    "-resize", ("%dx%d"):format(plan.resize.w, plan.resize.h), "+repage",
    ")",
    "-geometry", ("%+d%+d"):format(plan.offset.x, plan.offset.y),
    "-composite",
    "-strip",
    -- PNG 编码等级 1：编码时间约减半（体积 +8%；SSH 发送已不受 snacks 的 1ms/4KB 限速，划算）
    "-define", "png:compression-level=1",
    out,
  }
end

--- 查看器状态按 buffer 存在模块内（放 vim.b 会被转成 VimL dict，读回是副本）
local states = {} ---@type table<number, table>
local function state(buf)
  local st = states[buf]
  if st then
    return st
  end
  local name = vim.api.nvim_buf_get_name(buf)
  local ext = vim.fn.fnamemodify(name, ":e"):lower()
  st = {
    src = name, -- 当前渲染源（PDF 会随页码变化）
    src_dims = nil, -- 源像素尺寸
    mode = ext == "pdf" and "pdf" or "image",
    zoom = 1,
    px = 0.5,
    py = 0.5,
    page = 1,
    pages = nil,
    gen = 0,
    plan = nil, -- 最近一次渲染方案
    canvas_key = nil, -- 最近一次画布缓存键
    canvas_file = nil, -- 最近一次画布文件
    wheel_token = 0, -- 滚轮合并渲染令牌（显式操作会使其失效）
    replace_token = 0, -- 窗口事件重定位令牌（静默合并，显式操作/渲染会使其失效）
    image_hidden = false, -- 因 UI 浮窗（命令行/消息/通知）暂时隐藏中
  }
  states[buf] = st
  return st
end

--- 查看器状态（测试/调试用）
function M.state(buf)
  return states[buf]
end

local function source_file(st)
  if st.mode == "pdf" then
    return ("%s#page=%d"):format(st.src, st.page)
  end
  return st.src
end

--- 显示该 buffer 的窗口格数（多窗取最小；未显示时给合理估计）
local function view_dims(buf)
  local W, H = vim.o.columns, vim.o.lines
  local wins = vim.fn.win_findbuf(buf)
  if #wins == 0 then
    return W, math.max(1, H - 2)
  end
  for _, win in ipairs(wins) do
    W = math.min(W, vim.api.nvim_win_get_width(win))
    H = math.min(H, vim.api.nvim_win_get_height(win))
  end
  return W, H
end

--- 画布几何：窗口格数 + 单元格像素 → 画布像素
--- 画布比"格数×单元格像素"多 1px，确保 snacks 的 fit 判定走"整数格子"分支。
--- SSH 等场景终端可能不上报像素尺寸（cell=0）：用默认 9×18 估算继续画布模式
--- （缩放/平移/居中全部可用，宽高比误差约 4%；可用 vim.g.nvkit_viewer_cell_w/_h 精调）
local function canvas_geom(buf)
  local term = require("snacks.image").terminal.size()
  local cw, ch = term.cell_width, term.cell_height
  local gw, gh = tonumber(vim.g.nvkit_viewer_cell_w), tonumber(vim.g.nvkit_viewer_cell_h)
  if gw and gh and gw > 0 and gh > 0 then
    cw, ch = gw, gh
  elseif not (cw and ch and cw > 0 and ch > 0) then
    cw, ch = 9, 18
  end
  local W, H = view_dims(buf)
  if not W then
    return
  end
  return W, H, math.floor(W * cw) + 1, math.floor(H * ch) + 1
end

local function plan_key(base, plan)
  return vim.fn.sha256(("%s|%d,%d,%d,%d|%d,%d|%d,%d|%d,%d"):format(
    base,
    plan.crop.w, plan.crop.h, plan.crop.x, plan.crop.y,
    plan.resize.w, plan.resize.h,
    plan.offset.x, plan.offset.y,
    plan.canvas.w, plan.canvas.h
  )):sub(1, 16)
end

--- 放置图片：先创建新 placement、稍后再撤旧 placement（避免"先清后画"的空白帧闪烁）。
--- 旧 placement 的自动更新会立即停用：WezTerm #7953 中每次 a=p 都会重复累积图片附件
--- （quad 数爆炸 → 崩溃），必须把重定位次数压到最低。
--- 关闭一个旧 placement：立刻停其自动更新；延迟用正确 id 显式删除后 close
local function close_placement(old)
  -- 立刻停掉旧 placement 的自动更新（防止其继续发 a=p 加剧 WezTerm #7953 的附件累积）
  pcall(vim.api.nvim_del_augroup_by_id, old.augroup)
  vim.defer_fn(function()
    -- snacks 的 Image:del 把 ipairs 下标当 placement id 发送（永远发 p=1），
    -- WezTerm 按 (image_id, placement_id) 匹配时会找不到真实 placement → 单元格里的
    -- 图片附件不会被摘下（逐次累积成 quad 爆炸）。这里用正确 id 显式删除一次。
    local ok_term, terminal = pcall(require, "snacks.image.terminal")
    if ok_term and terminal and old.img then
      pcall(terminal.request, { a = "d", d = "i", i = old.img.id, p = old.id })
    end
    pcall(function()
      old:close()
    end)
  end, 60)
end

--- 清理"别的代码"为本 buffer 创建的源图 placement（snacks 自带挂载可能晚于我们）
local function sweep_foreign(buf, st)
  if not (vim.api.nvim_buf_is_valid(buf) and states[buf] == st) then
    return
  end
  local ok_img, img = pcall(require("snacks.image").image.new, source_file(st))
  if ok_img and img and img.placements then
    for _, p in pairs(img.placements) do
      if p.buf == buf and p ~= st.placement and not p.closed then
        close_placement(p)
      end
    end
  end
end

local function place_impl(buf, st, file)
  local snacks = require("snacks.image")
  local olds = {}
  if st.placement then
    olds[#olds + 1] = st.placement
  end
  -- 把 snacks 初次挂载的 placement（仅本 buffer）也一起纳入延迟清理
  local ok_img, img = without_sleep(function()
    return snacks.image.new(source_file(st))
  end)
  if ok_img and img and img.placements then
    for _, p in pairs(img.placements) do
      if p.buf == buf then
        olds[#olds + 1] = p
      end
    end
  end

  st.image_hidden = false
  local ok_p, newp = without_sleep(function()
    return snacks.placement.new(buf, file, {
      conceal = true,
      -- 不挂 snacks 的 auto_resize（它在任何 WinNew/WinClosed/WinEnter 都会重定位发 a=p）；
      -- 改由本模块"静默合并"策略触发（schedule_replace），把 a=p 收敛到用户停手后一次
      auto_resize = false,
      on_update_pre = function(p)
        if p.closed then
          return
        end
        local W, H = canvas_geom(buf)
        if W then
          p.opts.width, p.opts.height = W, H
        end
        -- 画布缺失（窗口尺寸/缩放/平移变化或转换完成）时补烘焙
        M._ensure_canvas(buf, st, p)
      end,
    })
  end)
  if not ok_p then
    error(newp)
  end
  st.placement = newp

  for _, old in ipairs(olds) do
    if old ~= st.placement then
      close_placement(old)
    end
  end
end

--- 放置图片：先创建新 placement、稍后再撤旧 placement（避免"先清后画"的空白帧闪烁）。
--- 旧 placement 的自动更新会立即停用：WezTerm #7953 中每次 a=p 都会重复累积图片附件
--- （quad 数爆炸 → 崩溃），必须把重定位次数压到最低。
local function place(buf, st, file)
  placing = true
  local ok, err = pcall(place_impl, buf, st, file)
  placing = false
  if not ok then
    error(err)
  end
end

--- 渲染当前状态：等比缩放绘制到窗口画布
local function render(buf, st)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  st.gen = st.gen + 1
  st.replace_token = (st.replace_token or 0) + 1 -- 新渲染接管，作废挂起的静默重定位
  local gen = st.gen
  local snacks = require("snacks.image")
  local ok_img, img = without_sleep(function()
    return snacks.image.new(source_file(st))
  end)
  local base = ok_img and img and img.file or nil
  if type(base) ~= "string" then
    return
  end
  st.src = base

  local okdim, dims = pcall(snacks.util.dim, base)
  if not okdim or not dims then
    place(buf, st, base) -- 转换未完成（如 PDF 首页）：普通放置，完成后再补
    return
  end
  st.src_dims = dims

  local okgeom, W, H, pw, ph = pcall(canvas_geom, buf)
  local cmd = magick()
  if not (okgeom and W and cmd) then
    -- 无 ImageMagick / 无单元格像素信息：退化为普通放置（左上角、不可缩放）。
    -- 同一源图已在展示时直接返回，避免每次按键重建 placement（无意义 a=p 累积）
    local cur = st.placement
    if cur and not cur.closed and cur.img and cur.img.file == base then
      return
    end
    place(buf, st, base)
    if okgeom and W then
      st.plan = M._plan(dims.width, dims.height, pw, ph, st.zoom, st.px, st.py)
      st.canvas_key = plan_key(base, st.plan)
    end
    return
  end

  local plan = M._plan(dims.width, dims.height, pw, ph, st.zoom, st.px, st.py)
  st.plan = plan
  st.px, st.py = plan.px, plan.py
  local key = plan_key(base, plan)
  st.canvas_key = key
  local out = ("%s/%s.png"):format(cache_dir(), key)
  if vim.fn.filereadable(out) == 0 then
    local res = vim.system(M._render_cmd(cmd, base, out, plan), { text = true }):wait(20000)
    if res.code ~= 0 then
      notify("绘制失败：" .. vim.trim(res.stderr or "unknown"), vim.log.levels.WARN)
      place(buf, st, base)
      return
    end
  end
  if st.gen ~= gen then
    return
  end
  -- 幂等：当前 placement 已在展示同一画布时不再重建（避免无意义 a=p）
  if
    st.canvas_file == out
    and st.placement
    and not st.placement.closed
    and st.placement.img
    and st.placement.img.file == out
  then
    return
  end
  st.canvas_file = out
  place(buf, st, out)
end

--- placement 更新时确保画布与当前窗口/缩放状态一致（窗口缩放、PDF 转换完成等触发）
--- 只处理"当前 placement"：旧 placement 在延迟关闭窗口内的 update 不得污染状态或触发重渲染
function M._ensure_canvas(buf, st, p)
  if p.closed or p ~= st.placement then
    return
  end
  local file = p.img and p.img.file
  if type(file) ~= "string" then
    return
  end
  if file ~= st.canvas_file then
    local ok, dims = pcall(require("snacks.image").util.dim, file)
    if not ok or not dims then
      return
    end
    st.src = file
    st.src_dims = dims
  end
  if not st.src_dims then
    return
  end
  local okgeom, W, H, pw, ph = pcall(canvas_geom, buf)
  if not (okgeom and W) then
    return
  end
  local plan = M._plan(st.src_dims.width, st.src_dims.height, pw, ph, st.zoom, st.px, st.py)
  local key = plan_key(st.src, plan)
  if key ~= st.canvas_key then
    st.canvas_key = key
    vim.schedule(function()
      render(buf, st)
    end)
  end
end

--- 使挂起的滚轮合并渲染失效（显式操作立即生效且不重复渲染）
local function cancel_wheel(st)
  st.wheel_token = (st.wheel_token or 0) + 1
end

--- 缩放前置环境检查：不满足时给出可操作提示并返回 true
local function zoom_blocked()
  if not magick() then
    notify("缩放需要 ImageMagick（可用 ./install.sh --with-magick 安装；" ..
      "或用 ~/.local/bin/nvim-devkit 启动以带上工具 PATH）", vim.log.levels.WARN)
    return true
  end
  return false
end

-- 窗口事件（浮窗开关/分屏/切换）静默多久后合并一次重定位。
-- WezTerm ≤ 未合并 PR #8035 的版本里，重定位（a=p）与滚动 interplay 会重复累积图片
-- 附件（wezterm#7953）→ quad 爆炸崩溃；因此不做"每次事件都重定位"，而是静默后一次。
local REPLACE_MS = 800

--- 作废挂起的静默重定位（显式操作/新渲染/关闭接管）
local function cancel_replace(st)
  st.replace_token = (st.replace_token or 0) + 1
end

--- 当前是否有 UI 浮窗（noice 的命令行/消息、通知、picker、终端面板等）
--- 终端把图片画在文字上层，全窗画布会盖住这些浮窗 → 有浮窗时需暂时隐藏图片
local function ui_floats_visible()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(win).relative ~= "" then
      return true
    end
  end
  return false
end

--- 暂时隐藏图片：真正发删除清空单元格附件（fallback 路径下 snacks 的 hide() 不生效）
--- 幂等：浮窗事件风暴时不重复发 a=d
local function hide_image(st)
  if st.image_hidden then
    return
  end
  local p = st.placement
  if p and not p.closed then
    st.image_hidden = true
    pcall(function()
      p:del()
    end)
  end
end

--- 静默合并重定位：窗口事件落定后对当前画布重新放置一次（仅一次 a=p）
local function schedule_replace(buf, st)
  st.replace_token = (st.replace_token or 0) + 1
  local token = st.replace_token
  vim.defer_fn(function()
    if st.replace_token ~= token or not vim.api.nvim_buf_is_valid(buf) or states[buf] ~= st then
      return
    end
    local p = st.placement
    if not (p and not p.closed and p:ready()) or #vim.fn.win_findbuf(buf) == 0 then
      return
    end
    if ui_floats_visible() then
      return -- 界面仍有浮窗（消息/通知/picker）：保持隐藏，等 WinClosed 再恢复
    end
    -- snacks 的 update 在状态未变时直接 return（不发 a=p）；这里清掉缓存强制重贴一次
    st.image_hidden = false
    p._state = nil
    pcall(function()
      p:update()
    end)
  end, REPLACE_MS)
end

--- UI 浮窗出现则隐藏图片；界面清空后静默合并恢复
local function sync_visibility(buf, st)
  if not (vim.api.nvim_buf_is_valid(buf) and states[buf] == st) then
    return
  end
  if ui_floats_visible() then
    cancel_replace(st)
    hide_image(st)
  else
    schedule_replace(buf, st)
  end
end


--- 阶梯档位下标（最接近当前 zoom 的档）
local function ladder_index(zoom)
  local idx = 1
  for i, v in ipairs(ZOOMS) do
    if math.abs(v - zoom) < 0.001 then
      idx = i
    end
  end
  return idx
end

local function set_zoom(buf, st, zoom)
  cancel_wheel(st)
  st.zoom = zoom
  if zoom <= 1 then
    st.px, st.py = 0.5, 0.5
  end
  render(buf, st)
end

local function zoom_step(buf, st, delta)
  if zoom_blocked() then
    return
  end
  local idx = ladder_index(st.zoom)
  local next_idx = math.max(1, math.min(#ZOOMS, idx + delta))
  if next_idx == idx then
    if idx == 1 then
      notify(("已是最小缩放 %d%%"):format(ZOOMS[1] * 100))
    else
      notify(("已是最大缩放 %d%%"):format(ZOOMS[#ZOOMS] * 100))
    end
    return
  end
  set_zoom(buf, st, ZOOMS[next_idx])
end

-- 滚轮缩放：连续拨动只调档位（立即生效），停下 WHEEL_MS 后合并成一次渲染+一次通知。
-- WezTerm ≤ 未合并 PR #8035 的版本里，每次 placement 重定位（a=p）都会在单元格里重复
-- 累积图片附件（#7953），滚轮每步都渲染会飞快把 quad 数推到千万级并崩溃；合并后每次
-- 滚动突发只产生 1 次重定位。
local WHEEL_MS = 140

local function wheel_zoom(buf, st, delta)
  if zoom_blocked() then
    return
  end
  local idx = ladder_index(st.zoom)
  local next_idx = math.max(1, math.min(#ZOOMS, idx + delta))
  if next_idx == idx then
    return -- 到顶/到底：静默（合并渲染会给出最终状态提示）
  end
  st.wheel_token = (st.wheel_token or 0) + 1
  local token = st.wheel_token
  st.zoom = ZOOMS[next_idx]
  if st.zoom <= 1 then
    st.px, st.py = 0.5, 0.5
  end
  vim.defer_fn(function()
    if st.wheel_token ~= token or not vim.api.nvim_buf_is_valid(buf) or states[buf] ~= st then
      return -- 已被后续滚轮或显式操作取代
    end
    render(buf, st)
  end, WHEEL_MS)
end

local function pan(buf, st, dx, dy)
  local plan = st.plan
  if not plan or (plan.disp.w <= plan.canvas.w and plan.disp.h <= plan.canvas.h) then
    notify("先放大再平移（+ 放大）")
    return
  end
  cancel_wheel(st)
  st.px = math.max(plan.px_lo, math.min(plan.px_hi, st.px + dx))
  st.py = math.max(plan.py_lo, math.min(plan.py_hi, st.py + dy))
  render(buf, st)
end

local function page(buf, st, delta)
  if st.mode ~= "pdf" then
    return
  end
  local target = st.page + delta
  if target < 1 then
    notify("已在第一页")
    return
  end
  if st.pages and target > st.pages then
    notify(("已在最后一页（共 %d 页）"):format(st.pages))
    return
  end
  cancel_wheel(st)
  st.page = target
  render(buf, st)
  if st.pages then
    notify(("第 %d/%d 页"):format(st.page, st.pages))
  else
    notify(("第 %d 页"):format(st.page))
  end
end

local function fetch_pages(buf, st)
  if st.mode ~= "pdf" or st.pages then
    return
  end
  require("nvim-devkit.pdf").count_pages(st.src, function(n)
    if n and vim.api.nvim_buf_is_valid(buf) and states[buf] == st then
      st.pages = n
    end
  end)
end

local did_setup = false
local function setup()
  if did_setup then
    return
  end
  did_setup = true
  -- 查看器接管的 buffer：阻止 snacks 自带 buf 挂载再画一张源图
  -- （它晚于我们的画布创建、贴左上角盖满屏幕——"一开始霸屏"的元凶）
  pcall(function()
    local pmod = require("snacks.image.placement")
    if type(pmod.new) == "function" and not pmod.__nvkit_patched then
      pmod.__nvkit_patched = true
      local orig_new = pmod.new
      pmod.new = function(buf, src, opts)
        if not placing and type(buf) == "number" and vim.b[buf] and vim.b[buf].nvkit_viewer_keys then
          return -- 由查看器接管
        end
        return orig_new(buf, src, opts)
      end
    end
  end)
  vim.api.nvim_create_autocmd("VimResized", {
    group = vim.api.nvim_create_augroup("nvim_devkit_viewer", { clear = true }),
    callback = function()
      for buf, st in pairs(states) do
        if vim.api.nvim_buf_is_valid(buf) and st.placement and not st.placement.closed then
          vim.schedule(function()
            if states[buf] == st then
              render(buf, st)
            end
          end)
        end
      end
    end,
  })
end

--- 关闭查看（wipe=true 时删除图片 buffer）
function M.close(buf, wipe)
  local st = states[buf]
  if st then
    cancel_wheel(st)
    cancel_replace(st)
  end
  if st and st.placement and not st.placement.closed then
    pcall(function()
      st.placement:close()
    end)
  end
  if wipe and vim.api.nvim_buf_is_valid(buf) then
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end
end

--- 为 ft=image 的 buffer 安装查看器（键位 + 等比渲染），幂等
function M.attach(buf)
  setup()
  if not vim.b[buf].nvkit_viewer_keys then
    vim.b[buf].nvkit_viewer_keys = true
    local st = state(buf)
    fetch_pages(buf, st)

    local function map(lhs, fn, desc)
      vim.keymap.set("n", lhs, fn, { buffer = buf, silent = true, desc = desc })
    end

    map("q", function()
      M.close(buf, true)
    end, "关闭图片")
    map("+", function()
      zoom_step(buf, st, 1)
    end, "放大")
    map("=", function()
      zoom_step(buf, st, 1)
    end, "放大")
    map("-", function()
      zoom_step(buf, st, -1)
    end, "缩小")
    map("0", function()
      set_zoom(buf, st, 1)
    end, "适应窗口")
    map("h", function()
      pan(buf, st, -PAN_STEP, 0)
    end, "左移")
    map("j", function()
      pan(buf, st, 0, PAN_STEP)
    end, "下移")
    map("k", function()
      pan(buf, st, 0, -PAN_STEP)
    end, "上移")
    map("l", function()
      pan(buf, st, PAN_STEP, 0)
    end, "右移")

    -- 逃生阀：vim.g.nvkit_viewer_wheel = 0 时滚轮缩放改为空操作（消费事件，避免触发 WezTerm 滚动）
    local wheel = vim.g.nvkit_viewer_wheel == 0 and function() end or nil

    if st.mode == "pdf" then
      map("]p", function()
        page(buf, st, 1)
      end, "下一页")
      map("[p", function()
        page(buf, st, -1)
      end, "上一页")
      map("<PageDown>", function()
        page(buf, st, 1)
      end, "下一页")
      map("<PageUp>", function()
        page(buf, st, -1)
      end, "上一页")
      map("<ScrollWheelDown>", wheel or function()
        page(buf, st, 1)
      end, wheel and "翻页已禁用（vim.g.nvkit_viewer_wheel=0）" or "下一页")
      map("<ScrollWheelUp>", wheel or function()
        page(buf, st, -1)
      end, wheel and "翻页已禁用（vim.g.nvkit_viewer_wheel=0）" or "上一页")
      map("<leader>rt", function()
        require("nvim-devkit.pdf").open(st.src)
      end, "切换到文本模式")
    else
      map("<ScrollWheelDown>", wheel or function()
        wheel_zoom(buf, st, -1)
      end, wheel and "缩放已禁用（vim.g.nvkit_viewer_wheel=0）" or "缩小")
      map("<ScrollWheelUp>", wheel or function()
        wheel_zoom(buf, st, 1)
      end, wheel and "缩放已禁用（vim.g.nvkit_viewer_wheel=0）" or "放大")
    end

    -- 事件钩子（重定位/浮窗避让）放在键位之后且整体 pcall：
    -- 任何环境差异都不影响最基本的查看键位可用
    pcall(function()
      local aug = vim.api.nvim_create_augroup("nvim_devkit_viewer_replace_" .. buf, { clear = true })
      vim.api.nvim_create_autocmd("BufWipeout", {
        buffer = buf,
        once = true,
        callback = function()
          states[buf] = nil
          pcall(vim.api.nvim_del_augroup_by_id, aug)
        end,
      })
      -- 自己接管重定位触发（auto_resize=false）：窗口事件静默合并为一次 a=p
      vim.api.nvim_create_autocmd({ "BufWinEnter", "BufEnter" }, {
        group = aug,
        buffer = buf,
        callback = function()
          schedule_replace(buf, st)
        end,
      })
      vim.api.nvim_create_autocmd({ "WinEnter", "WinClosed", "WinNew", "WinResized" }, {
        group = aug,
        callback = function()
          -- 延后一个 tick：WinClosed 触发时被关的浮窗可能仍在窗口列表里
          vim.schedule(function()
            if vim.api.nvim_buf_is_valid(buf) and states[buf] == st and #vim.fn.win_findbuf(buf) > 0 then
              sync_visibility(buf, st)
            end
          end)
        end,
      })
      -- 命令行（noice 会渲染成浮窗）打开时隐藏图片；离开后在界面清空时恢复
      vim.api.nvim_create_autocmd("CmdlineEnter", {
        group = aug,
        callback = function()
          cancel_replace(st)
          hide_image(st)
        end,
      })
      vim.api.nvim_create_autocmd("CmdlineLeave", {
        group = aug,
        callback = function()
          sync_visibility(buf, st)
        end,
      })
    end)
  end
  -- 源文件不存在时不渲染（转换必然失败，只会在后台刷错误）
  local name = vim.api.nvim_buf_get_name(buf)
  if name ~= "" and vim.fn.filereadable(name) == 1 then
    pcall(render, buf, state(buf))
    -- 安全网：snacks 自带的源图挂载可能晚于我们（异步终端探测），稍后清扫几次
    for _, delay in ipairs({ 400, 1500, 3000 }) do
      vim.defer_fn(function()
        pcall(sweep_foreign, buf, state(buf))
      end, delay)
    end
  end
  if not vim.g.nvkit_viewer_env_warned then
    vim.g.nvkit_viewer_env_warned = true
    if not magick() then
      notify("未安装 ImageMagick：图片按原始布局显示、缩放暂不可用（./install.sh --with-magick 可安装）",
        vim.log.levels.WARN)
    end
  end
end

return M
