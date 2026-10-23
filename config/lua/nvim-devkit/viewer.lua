-- 图片/PDF 查看器（等比缩放，普通窗口显示）：
--   · 把整图按等比缩放绘制到"窗口大小的画布"上：=1 适应窗口居中、<1 整图缩小居中、>1 放大后平移查看
--   · 画布像素尺寸与窗口格子一一对应，避免终端把图强行拉伸到整格导致的宽高比失真
--   · +/-/滚轮缩放（0.5x~8x），h/j/k/l 平移，0 适应窗口，q 关闭
--   · PDF 在 Kitty 终端下同样默认按页看图（]p/[p、滚轮翻页，<leader>rt 切文本）
local M = {}

local ZOOMS = { 0.5, 0.75, 1, 1.25, 1.5, 2, 3, 4, 6, 8 }
local PAN_STEP = 0.05 -- 平移步长（取景范围的百分比；越小平移越细腻）

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

--- 同步预发送：图片就绪时立即发送（无 sleep、一次到位）；未就绪返回 nil，
--- 由 ensure_image 延迟重试。注意：不在这里 vim.wait——在 picker 等异步流程中
--- 阻塞会与窗口关闭等 autocmd 相互干扰（曾触发 E855 并让预览永久失效）。
local function presend(file)
  local ok, img = pcall(require("snacks.image").image.new, file)
  if not (ok and img) or img.sent then
    return img
  end
  if img:failed() then
    return nil
  end
  if not img:ready() then
    return nil
  end
  without_sleep(function()
    pcall(function()
      img:send()
    end)
  end)
  return img.sent and img or nil
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

--- 视口方案（纯函数，供测试）：
--- zoom>=1：源矩形模式——图片只传输一次，平移/缩放仅发"源矩形放置"请求（x/y/w/h + c/r）；
---         补边画布 = zoom=1 的视口（源像素坐标），内容居中，透明补边保证任何平移不越界；
--- zoom<1：画布模式——整图缩小+居中（需要补边空间，走 magick 烘焙一次并缓存）。
function M._view(iw, ih, W, H, pw, ph, zoom, px, py)
  zoom = zoom or 1
  local s0 = math.min(pw / iw, ph / ih, 1)
  if zoom < 1 then
    local plan = M._plan(iw, ih, pw, ph, zoom, px, py)
    return {
      mode = "canvas",
      plan = plan,
      px = plan.px,
      py = plan.py,
      px_lo = plan.px_lo,
      px_hi = plan.px_hi,
      py_lo = plan.py_lo,
      py_hi = plan.py_hi,
      disp = plan.disp,
      canvas = plan.canvas,
      s0 = plan.s0,
      s = plan.s,
    }
  end
  local Pw = math.max(iw, math.floor(pw / s0 + 0.5))
  local Ph = math.max(ih, math.floor(ph / s0 + 0.5))
  local ox = math.floor((Pw - iw) / 2)
  local oy = math.floor((Ph - ih) / 2)
  local s = s0 * zoom
  local dw, dh = iw * s, ih * s
  local function clamp_axis(p, disp, canvas)
    if disp <= canvas then
      return 0.5, 0.5, 0.5
    end
    local lo = canvas / (2 * disp)
    return math.max(lo, math.min(1 - lo, p or 0.5)), lo, 1 - lo
  end
  local cx, px_lo, px_hi = clamp_axis(px, dw, pw)
  local cy, py_lo, py_hi = clamp_axis(py, dh, ph)
  local rw = math.max(1, math.floor(pw / s + 0.5))
  local rh = math.max(1, math.floor(ph / s + 0.5))
  local center_x = ox + cx * iw
  local center_y = oy + cy * ih
  local x = math.max(0, math.min(Pw - rw, math.floor(center_x - rw / 2 + 0.5)))
  local y = math.max(0, math.min(Ph - rh, math.floor(center_y - rh / 2 + 0.5)))
  return {
    mode = "rect",
    s0 = s0,
    s = s,
    pad = { w = Pw, h = Ph, ox = ox, oy = oy },
    rect = { x = x, y = y, w = rw, h = rh },
    cells = { w = W, h = H },
    px = cx,
    py = cy,
    px_lo = px_lo,
    px_hi = px_hi,
    py_lo = py_lo,
    py_hi = py_hi,
    disp = { w = dw, h = dh },
    canvas = { w = pw, h = ph },
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
    orig = name, -- 用户视角的源文件（预览 buffer 用；render 不会改写）
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
    replace_token = 0, -- 窗口事件重定位令牌（静默合并，显式操作/渲染会使其失效）
    image_hidden = false, -- 因 UI 浮窗（命令行/消息/通知）暂时隐藏中
    view = nil, -- 当前视口方案（_view 的结果）
    draw_token = 0, -- 节流渲染令牌
    last_draw = 0, -- 上次实际渲染时间（uv.now）
    img = nil, -- 当前发送/放置的图片对象（snacks Image）
    pid = nil, -- 查看器自己的 placement id
    last_id = nil, -- 上一张图的 image id（换图时清理其 placement）
    last_file = nil, -- 上一张图文件（换图判断）
  }
  states[buf] = st
  return st
end

--- 查看器状态（测试/调试用）
function M.state(buf)
  return states[buf]
end

local function source_file(st)
  local src = st.orig or st.src
  if st.mode == "pdf" then
    return ("%s#page=%d"):format(src, st.page)
  end
  return src
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
  return W, H, cw, ch
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
--- 释放终端里的位图数据（大写 d=I）。
--- 注意：小写 d=i 只摘 placement，解码后的数据会一直留到 WezTerm 的 320MiB 预算回收；
--- 主动释放才能把内存真正降下来。释放后 sent=false，下次显示会自动重传。
local function free_image(img)
  if not (img and img.id) then
    return
  end
  local ok, snacks = pcall(require, "snacks.image")
  local terminal = ok and snacks and snacks.terminal
  if terminal then
    pcall(terminal.request, { a = "d", d = "I", i = img.id })
  end
  img.sent = false
end

--- 关闭一个旧 placement：立刻停其自动更新；延迟用正确 id 显式删除后 close
local function close_placement(old, free)
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
    if free and old.img then
      free_image(old.img) -- 被替换的旧画布/旧源图不再需要
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
  -- 从源矩形模式切换过来：只摘旧 placement，保留源图数据
  -- （放大回源矩形模式时无需重传；内存已由 nvkit_viewer_max_pixels 上限约束）
  if st.img and st.pid then
    local ok_t, terminal = pcall(require, "snacks.image.terminal")
    if ok_t then
      pcall(terminal.request, { a = "d", d = "i", i = st.img.id, p = st.pid })
    end
    st.last_id = nil
    st.last_file = nil
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
  presend(file) -- 画布图片先同步发送（避免 placement 内部的异步慢发送）
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
      -- 旧画布释放数据；源图（st.img）保留，放大回源矩形模式无需重传
      close_placement(old, old.img ~= st.img)
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

--- 把光标放到窗口左上角（与 snacks render_fallback 相同规则；0 号是"从 editor 顶部起算"的偏移）
local function position_cursor(buf)
  local wins = vim.fn.win_findbuf(buf)
  if #wins == 0 then
    return
  end
  local ok, terminal = pcall(require, "snacks.image.terminal")
  if not ok then
    return
  end
  local pos = vim.api.nvim_win_get_position(wins[1])
  local Snacks = require("snacks")
  if
    (Snacks.config.styles.snacks_image.relative ~= "editor")
    and ((vim.o.showtabline == 2) or (vim.o.showtabline == 1 and vim.fn.tabpagenr("$") > 1))
  then
    terminal.set_cursor({ pos[1], pos[2] })
  else
    terminal.set_cursor({ pos[1] + 1, pos[2] })
  end
end

--- 大图传输前降采样：终端按解码后的 RGBA 计内存（宽×高×4 字节），
--- 全分辨率传输一张 4000×3000 照片就是 48MB。默认上限 8MP（约 32MB RGBA），
--- 可用 vim.g.nvkit_viewer_max_pixels 调整（0 = 不限制）。
local function bounded_base(file, dims)
  local cap = tonumber(vim.g.nvkit_viewer_max_pixels)
  if cap == nil then
    cap = 8 * 1024 * 1024
  end
  if cap <= 0 or not dims.width or not dims.height then
    return file, dims
  end
  if dims.width * dims.height <= cap then
    return file, dims
  end
  local cmd = magick()
  if not cmd then
    return file, dims
  end
  local scale = math.sqrt(cap / (dims.width * dims.height))
  local tw = math.max(1, math.floor(dims.width * scale))
  local th = math.max(1, math.floor(dims.height * scale))
  local key = vim.fn.sha256(("%s|bounded|%d"):format(file, cap)):sub(1, 16)
  local out = ("%s/%s.png"):format(cache_dir(), key)
  if vim.fn.filereadable(out) == 0 then
    local res = vim.system({
      cmd,
      file,
      "-resize", ("%dx%d!"):format(tw, th),
      "+repage",
      "-strip",
      "-define", "png:compression-level=1",
      out,
    }, { text = true }):wait(30000)
    if res.code ~= 0 then
      return file, dims
    end
  end
  local ok, ndims = pcall(require("snacks.image").util.dim, out)
  return out, (ok and ndims) or { width = tw, height = th }
end

--- 确保 file 对应的图片对象存在（同步预发送；未就绪时延迟重试渲染）
local function ensure_image(buf, st, file)
  if st.img and st.img.file == file and st.img.sent then
    return st.img
  end
  local img = presend(file)
  if img then
    if st.img and st.img ~= img then
      free_image(st.img) -- 换图：上一张的位图数据不再需要
    end
    st.img = img
    return img
  end
  -- 转换/识别尚未完成：稍后重试（不阻塞、不依赖事件）
  local gen = st.gen
  st.retry = (st.retry or 0) + 1
  if st.retry <= 200 then
    vim.defer_fn(function()
      if states[buf] == st and st.gen == gen then
        pcall(render, buf, st)
      end
    end, 40)
  end
  return nil
end

local pid_seq = 1000

--- 结束当前查看：删除 placement 并释放位图数据（切换预览/擦除预览 buffer/关闭查看器）
--- 只用于"不再显示"；暂时隐藏用 hide_image（保留数据便于秒恢复）
local function clear_placement(st)
  local ok, snacks = pcall(require, "snacks.image")
  local terminal = ok and snacks and snacks.terminal
  if st.img and st.pid and terminal then
    -- 先摘 placement（小写 i + 正确 placement id），再释放数据（大写 I）
    pcall(terminal.request, { a = "d", d = "i", i = st.img.id, p = st.pid })
  end
  if st.img then
    free_image(st.img)
    st.img = nil
  end
  if st.placement and not st.placement.closed then
    local p = st.placement
    st.placement = nil
    if terminal and p.img then
      pcall(terminal.request, { a = "d", d = "i", i = p.img.id, p = p.id })
      free_image(p.img)
    end
    pcall(function()
      p:close()
    end)
  end
  for _, im in pairs(st.placed or {}) do
    if im ~= st.img then
      free_image(im)
    end
  end
  st.placed = nil
end

--- 源矩形模式：图片只传一次，平移/缩放仅发放置请求（极廉价）；补边画布按需烘焙并缓存
local function draw_rect(buf, st, base, view, W, H)
  local dims = st.src_dims
  local need_pad = view.pad.w > dims.width or view.pad.h > dims.height
  local file = base
  if need_pad then
    if not magick() then
      place(buf, st, base) -- 无 magick 无法补边：退回普通放置（降级）
      st.view = nil
      return
    end
    local key = vim.fn.sha256(("%s|pad|%dx%d"):format(base, view.pad.w, view.pad.h)):sub(1, 16)
    file = ("%s/%s.png"):format(cache_dir(), key)
    if vim.fn.filereadable(file) == 0 then
      local res = vim.system({
        magick(),
        base,
        "-background", "none",
        "-gravity", "center",
        "-extent", ("%dx%d"):format(view.pad.w, view.pad.h),
        "+repage",
        "-strip",
        "-define", "png:compression-level=1",
        file,
      }, { text = true }):wait(30000)
      if res.code ~= 0 then
        notify("补边失败：" .. vim.trim(res.stderr or "unknown"), vim.log.levels.WARN)
        place(buf, st, base)
        st.view = nil
        return
      end
    end
  end

  local img = ensure_image(buf, st, file)
  if not img then
    return
  end
  local ok_term, terminal = pcall(require, "snacks.image.terminal")
  if not ok_term then
    return
  end
  -- 从画布/降级模式切换过来：关闭 snacks 的 placement
  if st.placement and not st.placement.closed then
    close_placement(st.placement)
  end
  st.placement = nil
  st.pid = st.pid or (pid_seq + buf)
  -- 换图：删除本 buffer 此前放置过的所有图片（切图先清旧，避免旧图残留/叠层），
  -- 并释放旧图的位图数据（只挂 placement 会一直占着终端内存）
  for id, old in pairs(st.placed or {}) do
    if id ~= img.id then
      pcall(terminal.request, { a = "d", d = "i", i = id, p = st.pid })
      free_image(old)
    end
  end
  st.placed = { [img.id] = img }
  st.last_id = img.id
  st.last_file = file
  st.canvas_file = file

  position_cursor(buf)
  pcall(terminal.request, {
    a = "p",
    i = img.id,
    p = st.pid,
    x = view.rect.x,
    y = view.rect.y,
    w = view.rect.w,
    h = view.rect.h,
    c = W,
    r = H,
    C = 1,
    q = 2,
  })
  st.image_hidden = false
end

--- 渲染当前状态：等比缩放绘制到窗口画布
local function render(buf, st)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  st.gen = st.gen + 1
  st.replace_token = (st.replace_token or 0) + 1 -- 新渲染接管，作废挂起的静默重定位
  st.draw_token = (st.draw_token or 0) + 1 -- 作废挂起的节流渲染（最新状态优先）
  local gen = st.gen
  local snacks = require("snacks.image")
  local ok_img, img = without_sleep(function()
    return snacks.image.new(source_file(st))
  end)
  local base = ok_img and img and img.file or nil
  if type(base) ~= "string" then
    return
  end
  local okdim, dims = pcall(snacks.util.dim, base)
  if not okdim or not dims then
    st.src = base
    place(buf, st, base) -- 转换未完成（如 PDF 首页）：普通放置，完成后再补
    return
  end
  base, dims = bounded_base(base, dims)
  st.src = base -- 记降采样后的实际传输路径
  st.src_dims = dims

  local okgeom, W, H, cw, ch = pcall(canvas_geom, buf)
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
      st.plan = M._plan(dims.width, dims.height, math.floor(W * cw) + 1, math.floor(H * ch) + 1,
        st.zoom, st.px, st.py)
      st.canvas_key = plan_key(base, st.plan)
    end
    return
  end

  -- 视口方案：zoom>=1 → 源矩形模式（一次传输 + 廉价放置，精确像素）；zoom<1 → 画布模式
  local view = M._view(dims.width, dims.height, W, H, W * cw, H * ch, st.zoom, st.px, st.py)
  st.view = view
  st.px, st.py = view.px, view.py
  if view.mode == "rect" then
    return draw_rect(buf, st, base, view, W, H)
  end

  -- 画布模式沿用"多 1px 走整数格"的技巧
  local pw, ph = math.floor(W * cw) + 1, math.floor(H * ch) + 1
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
  local okgeom, W, H, cw, ch = pcall(canvas_geom, buf)
  if not (okgeom and W) then
    return
  end
  local plan = M._plan(st.src_dims.width, st.src_dims.height, math.floor(W * cw) + 1, math.floor(H * ch) + 1,
    st.zoom, st.px, st.py)
  local key = plan_key(st.src, plan)
  if key ~= st.canvas_key then
    st.canvas_key = key
    vim.schedule(function()
      render(buf, st)
    end)
  end
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
-- 恢复延迟：界面清空后尽快重放（浮窗仍在时由下方轮询检查兜底，不再依赖长去抖）。
-- 旧值 800ms 会让"同一 buffer 重开"（没有 BufEnter）等近 1 秒，体感像"按键才显示"。
local REPLACE_MS = 150
-- 切回图片 buffer（BufWinEnter/BufEnter）时同样尽快恢复
local ENTER_MS = 120
-- 界面仍有浮窗时的恢复重试间隔/上限（不再依赖"某一次 WinClosed 必然到达"）
local RETRY_MS = 200
local RETRY_MAX = 50

--- 作废挂起的静默重定位（显式操作/新渲染/关闭接管）
local function cancel_replace(st)
  st.replace_token = (st.replace_token or 0) + 1
end

--- 渲染节流：按键连发（长按平移/缩放）时合并重绘，降低终端重绘压力，
--- 避免"按键快于终端刷新"导致的明显卡顿。间隔可用
--- vim.g.nvkit_viewer_throttle_ms（默认 60）调整；最后一次状态一定会绘制。
local function draw_soon(buf, st)
  st.draw_token = (st.draw_token or 0) + 1
  local token = st.draw_token
  local now = vim.uv.now()
  local ms = tonumber(vim.g.nvkit_viewer_throttle_ms) or 60
  local gap = math.max(0, (st.last_draw or 0) + ms - now)
  vim.defer_fn(function()
    if st.draw_token ~= token or not vim.api.nvim_buf_is_valid(buf) or states[buf] ~= st then
      return
    end
    st.last_draw = vim.uv.now()
    render(buf, st)
  end, gap)
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
  st.draw_token = (st.draw_token or 0) + 1 -- 作废挂起的节流绘制（浮窗期间不重画图片）
  if st.img and st.pid then
    -- 源矩形模式：删除查看器自己的 placement（数据保留，恢复时直接重放）
    st.image_hidden = true
    local ok, terminal = pcall(require, "snacks.image.terminal")
    if ok then
      pcall(terminal.request, { a = "d", d = "i", i = st.img.id, p = st.pid })
    end
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

--- 合并重定位：窗口事件落定后对当前画布重新放置一次（仅一次 a=p）。
--- 浮窗（命令行/消息/通知/picker/文件树）仍在时按 RETRY_MS 轮询重试，
--- 关闭后尽快恢复——不会因为错过某次事件而永久隐藏。
local function schedule_replace(buf, st, delay)
  st.replace_token = (st.replace_token or 0) + 1
  local token = st.replace_token
  local function attempt(tries)
    if st.replace_token ~= token or not vim.api.nvim_buf_is_valid(buf) or states[buf] ~= st then
      return
    end
    if #vim.fn.win_findbuf(buf) == 0 then
      return
    end
    local p = st.placement
    if not (p and not p.closed and p:ready()) and not st.img then
      return
    end
    -- 预览 buffer（文件树预览模式）与文件树浮窗并存是预期状态，不做浮窗避让
    if not vim.b[buf].nvkit_preview and ui_floats_visible() then
      if tries < RETRY_MAX then
        vim.defer_fn(function()
          attempt(tries + 1)
        end, RETRY_MS)
      end
      return
    end
    if st.img then
      -- 源矩形模式：直接重放一次放置请求（极廉价，不重传图片）
      render(buf, st)
      return
    end
    -- 画布/降级模式：snacks 的 update 在状态未变时直接 return；清掉缓存强制重贴一次
    st.image_hidden = false
    p._state = nil
    pcall(function()
      p:update()
    end)
  end
  vim.defer_fn(function()
    attempt(0)
  end, delay or REPLACE_MS)
end

--- UI 浮窗出现则隐藏图片；界面清空后静默合并恢复
local function sync_visibility(buf, st)
  if not (vim.api.nvim_buf_is_valid(buf) and states[buf] == st) then
    return
  end
  if vim.b[buf].nvkit_preview then
    -- 预览 buffer：文件树浮窗是预期状态；界面变化时直接重放（不做浮窗避让）
    schedule_replace(buf, st)
  elseif ui_floats_visible() then
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
  st.zoom = zoom
  if zoom <= 1 then
    st.px, st.py = 0.5, 0.5
  end
  draw_soon(buf, st)
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

-- 滚轮缩放：档位立即生效；重绘走与按键一致的节流（滚动过程中每 ~60ms 更新一次，
-- 停下后必然绘制最终状态）。此前用 140ms 尾部防抖，滚动期间画面完全不动、停下才跳一次，
-- 体感明显卡顿；节流同时仍把 a=p 频率压住（防 WezTerm #7953 的附件累积）。
local function wheel_zoom(buf, st, delta)
  if zoom_blocked() then
    return
  end
  local idx = ladder_index(st.zoom)
  local next_idx = math.max(1, math.min(#ZOOMS, idx + delta))
  if next_idx == idx then
    return -- 到顶/到底：静默
  end
  st.zoom = ZOOMS[next_idx]
  if st.zoom <= 1 then
    st.px, st.py = 0.5, 0.5
  end
  draw_soon(buf, st)
end

local function pan(buf, st, dx, dy)
  local v = st.view
  if not v or (v.disp.w <= v.canvas.w and v.disp.h <= v.canvas.h) then
    notify("先放大再平移（+ 放大）")
    return
  end
  st.px = math.max(v.px_lo, math.min(v.px_hi, st.px + dx))
  st.py = math.max(v.py_lo, math.min(v.py_hi, st.py + dy))
  draw_soon(buf, st)
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
  require("nvim-devkit.pdf").count_pages(st.orig or st.src, function(n)
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
    cancel_replace(st)
    clear_placement(st) -- 删 placement + 释放终端位图数据（内存不再等 320MiB 预算回收）
    st.image_hidden = true
  end
  if wipe and vim.api.nvim_buf_is_valid(buf) then
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end
end

--- 在指定 buffer 中显示/切换任意图片或 PDF（文件浏览器预览模式用；buffer 可复用）
function M.show(buf, src)
  if not vim.api.nvim_buf_is_valid(buf) or type(src) ~= "string" then
    return
  end
  local st = state(buf)
  local ext = vim.fn.fnamemodify(src, ":e"):lower()
  -- 预览 buffer 被擦除/重建时：删除 placement 并清理状态（删 buffer 不会清终端里的图）
  if not vim.b[buf].nvkit_preview_watched then
    vim.b[buf].nvkit_preview_watched = true
    vim.api.nvim_create_autocmd("BufWipeout", {
      buffer = buf,
      once = true,
      callback = function()
        local s2 = states[buf]
        if s2 then
          clear_placement(s2)
        end
        states[buf] = nil
      end,
    })
  end
  clear_placement(st) -- 先删旧图：新图绘制失败/变慢时也不会显示错误的旧图
  st.image_hidden = true
  st.orig = src
  st.src = src
  st.mode = ext == "pdf" and "pdf" or "image"
  st.zoom = 1
  st.px, st.py = 0.5, 0.5
  st.page = 1
  st.pages = nil
  st.retry = 0
  fetch_pages(buf, st)
  render(buf, st)
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
          if states[buf] then
            clear_placement(states[buf]) -- 擦除 buffer：释放终端位图数据
          end
          states[buf] = nil
          pcall(vim.api.nvim_del_augroup_by_id, aug)
        end,
      })
      -- 自己接管重定位触发（auto_resize=false）：窗口事件静默合并为一次 a=p
      vim.api.nvim_create_autocmd({ "BufWinEnter", "BufEnter" }, {
        group = aug,
        buffer = buf,
        callback = function()
          -- 重新进入图片 buffer：尽快恢复（120ms），不必等窗口事件的 800ms 合并窗口
          schedule_replace(buf, st, ENTER_MS)
        end,
      })
      -- 离开窗口时真正删除 placement：空 buffer 之间切换时 nvim 不会重绘单元格，
      -- kitty 图片附件会残留在窗口里（旧图叠在新图下面/底层）——必须主动清除
      vim.api.nvim_create_autocmd({ "BufWinLeave", "BufLeave" }, {
        group = aug,
        buffer = buf,
        callback = function()
          vim.schedule(function()
            if vim.api.nvim_buf_is_valid(buf) and states[buf] == st and #vim.fn.win_findbuf(buf) == 0 then
              hide_image(st)
            end
          end)
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
        if vim.api.nvim_buf_is_valid(buf) then
          pcall(sweep_foreign, buf, state(buf))
        end
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
