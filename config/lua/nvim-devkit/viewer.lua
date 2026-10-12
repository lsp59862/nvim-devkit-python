-- 图片/PDF 查看器：适应窗口、缩放（ImageMagick 裁剪视口）、平移、PDF 翻页
-- 图片文件由 snacks.image 的 BufReadCmd 渲染；本模块在 ft=image 上补齐查看器交互
local M = {}

local ZOOMS = { 1, 1.25, 1.5, 2, 3, 4, 6, 8 }
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

--- 计算缩放视口的裁剪窗口（纯函数，供测试）
---@param iw number 原图宽（像素）
---@param ih number 原图高（像素）
---@param zoom number 1 = 适应窗口
---@param px number 水平中心 [0,1]
---@param py number 垂直中心 [0,1]
function M._crop(iw, ih, zoom, px, py)
  zoom = math.max(1, zoom or 1)
  local w = math.max(1, math.floor(iw / zoom))
  local h = math.max(1, math.floor(ih / zoom))
  local x = math.floor((iw - w) * (px or 0.5) + 0.5)
  local y = math.floor((ih - h) * (py or 0.5) + 0.5)
  x = math.max(0, math.min(iw - w, x))
  y = math.max(0, math.min(ih - h, y))
  return { w = w, h = h, x = x, y = y }
end

--- 构造裁剪命令（纯函数，供测试）
function M._crop_cmd(cmd, src, out, geom)
  return { cmd, src, "-crop", ("%dx%d+%d+%d"):format(geom.w, geom.h, geom.x, geom.y), "+repage", out }
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
    src = name,
    mode = ext == "pdf" and "pdf" or "image",
    zoom = 1,
    px = 0.5,
    py = 0.5,
    page = 1,
    pages = nil,
    gen = 0,
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

--- 可视区域（当前窗口或编辑器，留 2 格边距，避免图片上下贴边"霸屏"）
local function view_box(buf)
  local w, h = vim.o.columns, vim.o.lines
  for _, win in ipairs(vim.fn.win_findbuf(buf)) do
    if vim.api.nvim_win_get_config(win).relative == "" then
      w = math.min(w, vim.api.nvim_win_get_width(win))
      h = math.min(h, vim.api.nvim_win_get_height(win))
    end
  end
  return math.max(4, w - 2), math.max(2, h - 2)
end

--- 图片按单元格适配框内（保持宽高比）；尺寸未知返回 nil
local function fit_cells(file, box_w, box_h)
  local snacks = require("snacks.image")
  local term = snacks.terminal.size()
  local ok, dims = pcall(snacks.util.dim, file)
  if not ok or not dims then
    return nil
  end
  local iw = dims.width / math.max(1, term.cell_width)
  local ih = dims.height / math.max(1, term.cell_height)
  local s = math.min(box_w / iw, box_h / ih)
  return math.max(1, math.floor(iw * s + 0.5)), math.max(1, math.floor(ih * s + 0.5))
end

--- 放置图片：先创建新 placement、稍后再撤旧 placement。
--- 若"先清后画"，终端会出现一帧空白（观感即闪烁）；窗口缩放由 auto_resize +
--- on_update_pre 动态重算尺寸处理。
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
      local w, h = view_box(buf)
      local cw, ch = fit_cells(p.img.file or file, w, h)
      if cw then
        p.opts.width, p.opts.height = cw, ch
      end
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

--- 渲染当前状态；zoom > 1 时用 magick 裁剪视口后再交给 snacks 放置
local function render(buf, st)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  st.gen = st.gen + 1
  local gen = st.gen
  local snacks = require("snacks.image")
  local img = snacks.image.new(source_file(st))
  local base = img.file

  if st.zoom <= 1 then
    place(buf, st, base)
    return
  end

  local cmd = magick()
  if not cmd then
    st.zoom = 1
    notify("缩放需要 ImageMagick（可用 ./install.sh --with-magick 安装）", vim.log.levels.WARN)
    place(buf, st, base)
    return
  end

  -- PDF 页面转换是异步的，等产物就绪（有上限）
  if vim.fn.filereadable(base) == 0 then
    vim.wait(8000, function()
      return st.gen ~= gen or vim.fn.filereadable(base) == 1
    end, 50)
    if st.gen ~= gen then
      return
    end
  end
  if vim.fn.filereadable(base) == 0 then
    st.zoom = 1
    notify("图片转换未就绪，已回到适应窗口", vim.log.levels.WARN)
    place(buf, st, base)
    return
  end

  local ok, dims = pcall(snacks.util.dim, base)
  if not ok then
    st.zoom = 1
    notify("无法读取图片尺寸，已回到适应窗口", vim.log.levels.WARN)
    place(buf, st, base)
    return
  end

  local geom = M._crop(dims.width, dims.height, st.zoom, st.px, st.py)
  local hash = vim.fn.sha256(("%s|%dx%d+%d+%d"):format(base, geom.w, geom.h, geom.x, geom.y)):sub(1, 16)
  local out = ("%s/%s.png"):format(cache_dir(), hash)
  if vim.fn.filereadable(out) == 0 then
    local res = vim.system(M._crop_cmd(cmd, base, out, geom), { text = true }):wait(20000)
    if res.code ~= 0 then
      st.zoom = 1
      notify("缩放裁剪失败：" .. vim.trim(res.stderr or "unknown"), vim.log.levels.WARN)
      place(buf, st, base)
      return
    end
  end
  if st.gen ~= gen then
    return
  end
  place(buf, st, out)
end

local function set_zoom(buf, st, zoom)
  st.zoom = zoom
  if zoom <= 1 then
    st.px, st.py = 0.5, 0.5
  end
  render(buf, st)
  if zoom <= 1 then
    notify("适应窗口")
  else
    notify(("缩放 %d%%（h/j/k/l 平移，0 适应窗口）"):format(math.floor(zoom * 100 + 0.5)))
  end
end

local function zoom_step(buf, st, delta)
  local idx = 1
  for i, v in ipairs(ZOOMS) do
    if math.abs(v - st.zoom) < 0.001 then
      idx = i
    end
  end
  local next_idx = math.max(1, math.min(#ZOOMS, idx + delta))
  if next_idx == idx then
    if idx == 1 then
      notify("已是适应窗口")
    else
      notify(("已是最大缩放 %d%%"):format(ZOOMS[#ZOOMS] * 100))
    end
    return
  end
  set_zoom(buf, st, ZOOMS[next_idx])
end

local function pan(buf, st, dx, dy)
  if st.zoom <= 1 then
    notify("先缩放再平移（+ 放大）")
    return
  end
  st.px = math.max(0, math.min(1, st.px + dx))
  st.py = math.max(0, math.min(1, st.py + dy))
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
    if n and vim.api.nvim_buf_is_valid(buf) and vim.b[buf].nvkit_viewer == st then
      st.pages = n
    end
  end)
end

--- 为 ft=image 的 buffer 安装查看器键位（幂等）
function M.attach(buf)
  if vim.b[buf].nvkit_viewer_keys then
    return
  end
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

  map("q", "<cmd>bd<CR>", "关闭")
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

return M
