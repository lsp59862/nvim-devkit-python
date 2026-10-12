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

--- 画布几何：窗口格数 + 单元格像素 → 画布像素
--- 画布比"格数×单元格像素"多 1px，确保 snacks 的 fit 判定走"整数格子"分支
local function canvas_geom(buf)
  local term = require("snacks.image").terminal.size()
  local cw, ch = term.cell_width, term.cell_height
  if not (cw and ch and cw > 0 and ch > 0) then
    return
  end
  local W, H = vim.o.columns, vim.o.lines
  local wins = vim.fn.win_findbuf(buf)
  if #wins > 0 then
    for _, win in ipairs(wins) do
      W = math.min(W, vim.api.nvim_win_get_width(win))
      H = math.min(H, vim.api.nvim_win_get_height(win))
    end
  else
    H = math.max(1, H - 2)
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

--- 放置图片：先创建新 placement、稍后再撤旧 placement（避免"先清后画"的空白帧闪烁）
local function place(buf, st, file)
  local snacks = require("snacks.image")
  local olds = {}
  if st.placement then
    olds[#olds + 1] = st.placement
  end
  -- 首次替换时，把 snacks 初次挂载的 placement 也一起纳入延迟清理
  local ok_img, img = pcall(snacks.image.new, source_file(st))
  if ok_img and img and img.placements then
    for _, p in pairs(img.placements) do
      olds[#olds + 1] = p
    end
  end

  st.placement = snacks.placement.new(buf, file, {
    conceal = true,
    auto_resize = true,
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

  for _, old in ipairs(olds) do
    if old ~= st.placement then
      vim.defer_fn(function()
        pcall(function()
          old:close()
        end)
      end, 60)
    end
  end
end

--- 渲染当前状态：等比缩放绘制到窗口画布
local function render(buf, st)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  st.gen = st.gen + 1
  local gen = st.gen
  local snacks = require("snacks.image")
  local ok_img, img = pcall(snacks.image.new, source_file(st))
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
    place(buf, st, base) -- 无 ImageMagick / 无单元格像素信息：退化普通放置
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
  st.canvas_file = out
  place(buf, st, out)
end

--- placement 更新时确保画布与当前窗口/缩放状态一致（窗口缩放、PDF 转换完成等触发）
function M._ensure_canvas(buf, st, p)
  if p.closed then
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

local function set_zoom(buf, st, zoom)
  st.zoom = zoom
  if zoom <= 1 then
    st.px, st.py = 0.5, 0.5
  end
  render(buf, st)
  local pct = math.floor(zoom * 100 + 0.5)
  if zoom == 1 then
    notify("适应窗口")
  elseif zoom < 1 then
    notify(("缩小 %d%%"):format(pct))
  else
    notify(("缩放 %d%%（h/j/k/l 平移，0 适应窗口）"):format(pct))
  end
end

local function zoom_step(buf, st, delta)
  if not magick() then
    notify("缩放需要 ImageMagick（可用 ./install.sh --with-magick 安装）", vim.log.levels.WARN)
    return
  end
  local idx = 1
  for i, v in ipairs(ZOOMS) do
    if math.abs(v - st.zoom) < 0.001 then
      idx = i
    end
  end
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

local function pan(buf, st, dx, dy)
  local plan = st.plan
  if not plan or (plan.disp.w <= plan.canvas.w and plan.disp.h <= plan.canvas.h) then
    notify("先放大再平移（+ 放大）")
    return
  end
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
    vim.api.nvim_create_autocmd("BufWipeout", {
      buffer = buf,
      once = true,
      callback = function()
        states[buf] = nil
      end,
    })
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
      map("<ScrollWheelDown>", function()
        page(buf, st, 1)
      end, "下一页")
      map("<ScrollWheelUp>", function()
        page(buf, st, -1)
      end, "上一页")
      map("<leader>rt", function()
        require("nvim-devkit.pdf").open(st.src)
      end, "切换到文本模式")
    else
      map("<ScrollWheelDown>", function()
        zoom_step(buf, st, -1)
      end, "缩小")
      map("<ScrollWheelUp>", function()
        zoom_step(buf, st, 1)
      end, "放大")
    end
  end
  pcall(render, buf, state(buf))
end

return M
