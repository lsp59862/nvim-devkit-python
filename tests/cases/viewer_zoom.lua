-- 查看器真实缩放路径：+/-/平移/复位 经 magick 裁剪视口并重新放置。
-- 覆盖回归：1) 曾误用 snacks.image.image 双层索引导致缩放崩溃；
-- 2) 曾"先清后画"导致换图闪烁（现在先创建新 placement，40ms 后再撤旧）；
-- 3) 尺寸须适配可视框（留边距、保持宽高比，避免上下贴边霸屏）。
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")
local Snacks = require("snacks")
local viewer = require("nvim-devkit.viewer")

local magick = vim.fn.executable("magick") == 1 and "magick"
  or (vim.fn.executable("convert") == 1 and "convert" or nil)
if not magick then
  lib.ok("ImageMagick 缺失：跳过真实缩放路径断言", true, "optional dependency")
  lib.finish()
  return
end
lib.ok("ImageMagick 可用", true, magick)

-- 真实 PNG（1600x1000，足够大以便被可视框约束）
local png = lib.dir() .. "/zoom_probe.png"
vim.system({ magick, "-size", "1600x1000", "xc:#3a7", png }):wait(10000)
lib.ok("生成测试 PNG", vim.fn.filereadable(png) == 1, png)

Snacks.image.config.force = true
lib.reset()
vim.cmd.edit(png)
vim.wait(2000, function()
  return vim.bo.filetype == "image"
end, 50)
lib.ok("图片 buffer 进入 ft=image", vim.bo.filetype == "image", vim.bo.filetype)

local buf = vim.api.nvim_get_current_buf()
local st = viewer.state(buf)
lib.ok("查看器状态已建立（zoom=1）", st ~= nil and st.zoom == 1,
  vim.inspect(st and { zoom = st.zoom, mode = st.mode }))

local cache = vim.fn.stdpath("cache") .. "/nvim-devkit/viewer"
local orig = Snacks.image.image.new(png).file
local function placed()
  return st and st.placement and st.placement.img and st.placement.img.file or nil
end

local plus = vim.fn.maparg("+", "n", false, true).callback
local minus = vim.fn.maparg("-", "n", false, true).callback
local pan_r = vim.fn.maparg("l", "n", false, true).callback
local reset = vim.fn.maparg("0", "n", false, true).callback
lib.ok("缩放/平移/复位键位存在",
  plus ~= nil and minus ~= nil and pan_r ~= nil and reset ~= nil)

-- 放大：产生裁剪产物；并校验尺寸适配与宽高比
plus()
vim.wait(300)
lib.ok("放大后倍数生效", st.zoom > 1.0001, "zoom=" .. tostring(st.zoom))
local zoomed = placed()
lib.ok("放大后放置的是 magick 裁剪产物（cache 内 PNG）",
  zoomed ~= nil and zoomed ~= orig and zoomed:find(cache, 1, true) ~= nil and vim.fn.filereadable(zoomed) == 1,
  ("placed=%s orig=%s"):format(tostring(zoomed), tostring(orig)))

local box_w, box_h = vim.o.columns - 2, vim.o.lines - 2
for _, win in ipairs(vim.fn.win_findbuf(buf)) do
  if vim.api.nvim_win_get_config(win).relative == "" then
    box_w = math.min(box_w, vim.api.nvim_win_get_width(win) - 2)
    box_h = math.min(box_h, vim.api.nvim_win_get_height(win) - 2)
  end
end
local loc = st.placement:state().loc
lib.ok("放置尺寸不超过可视框（上下/左右留边距）",
  loc.width <= box_w and loc.height <= box_h,
  ("loc=%dx%d box=%dx%d"):format(loc.width, loc.height, box_w, box_h))
do
  local term = Snacks.image.terminal.size()
  local okd, dims = pcall(Snacks.util.dim, zoomed)
  if okd and dims then
    local iw = dims.width / math.max(1, term.cell_width)
    local ih = dims.height / math.max(1, term.cell_height)
    local ratio_err = math.abs((loc.width / loc.height) / (iw / ih) - 1)
    lib.ok("放置尺寸保持原图宽高比", ratio_err < 0.25,
      ("loc=%.1fx%.1f img=%.1fx%.1f err=%.2f"):format(loc.width, loc.height, iw, ih, ratio_err))
  end
end

-- 缩小键（-）与滚轮同路径：阶梯回落
minus()
vim.wait(300)
lib.ok("- 缩小回适应窗口并放置原图", st.zoom == 1 and placed() == orig,
  ("zoom=%s placed=%s"):format(tostring(st.zoom), tostring(placed())))

-- 阶梯双向：+ + → 1.5；- → 1.25
plus()
vim.wait(200)
plus()
vim.wait(200)
lib.ok("连续放大到 1.5", math.abs(st.zoom - 1.5) < 0.001, "zoom=" .. tostring(st.zoom))
minus()
vim.wait(200)
lib.ok("- 阶梯回落到 1.25", math.abs(st.zoom - 1.25) < 0.001, "zoom=" .. tostring(st.zoom))

-- 平移 + 防闪烁（换图时旧的先保留，稍后再撤）
local px0 = st.px
local old_p = st.placement
pan_r()
lib.ok("平移改变取景中心", st.px > px0, ("px=%.2f→%.2f"):format(px0, st.px))
lib.ok("换图时旧 placement 暂不关闭（先画新、后撤旧）",
  st.placement ~= old_p and old_p.closed ~= true, ("old_closed=%s"):format(tostring(old_p.closed)))
vim.wait(400)
lib.ok("旧 placement 随后被清理", old_p.closed == true, ("old_closed=%s"):format(tostring(old_p.closed)))

-- 复位
reset()
vim.wait(300)
lib.ok("复位回适应窗口并放置原图", st.zoom == 1 and placed() == orig,
  ("zoom=%s placed=%s"):format(tostring(st.zoom), tostring(placed())))

vim.cmd("silent! %bwipeout!")
lib.finish()
