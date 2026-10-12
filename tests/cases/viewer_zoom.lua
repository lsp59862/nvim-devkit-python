-- 查看器真实缩放路径：+/-/平移/复位 经 magick 裁剪视口并重新放置。
-- 回归背景：曾误用不存在的 snacks.util.dim，导致每次缩放都“读尺寸失败”回退适应窗口。
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")
local Snacks = require("snacks")

local magick = vim.fn.executable("magick") == 1 and "magick"
  or (vim.fn.executable("convert") == 1 and "convert" or nil)
if not magick then
  -- ImageMagick 是可选依赖：缺失时跳过真实裁剪断言（不算失败）
  lib.ok("ImageMagick 缺失：跳过真实缩放路径断言", true, "optional dependency")
  lib.finish()
  return
end
lib.ok("ImageMagick 可用", true, magick)

-- 真实 PNG（100x60）
local png = lib.dir() .. "/zoom_probe.png"
vim.system({ magick, "-size", "100x60", "xc:red", png }):wait(10000)
lib.ok("生成测试 PNG", vim.fn.filereadable(png) == 1, png)

Snacks.image.config.force = true
lib.reset()
vim.cmd.edit(png)
vim.wait(2000, function()
  return vim.bo.filetype == "image"
end, 50)
lib.ok("图片 buffer 进入 ft=image", vim.bo.filetype == "image", vim.bo.filetype)

local buf = vim.api.nvim_get_current_buf()
local st = require("nvim-devkit.viewer").state(buf)
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

-- 放大（render 内同步完成裁剪与放置）
plus()
vim.wait(300)
lib.ok("放大后倍数生效", st.zoom > 1.0001, "zoom=" .. tostring(st.zoom))
local zoomed = placed()
lib.ok("放大后放置的是 magick 裁剪产物（cache 内 PNG）",
  zoomed ~= nil and zoomed ~= orig and zoomed:find(cache, 1, true) ~= nil and vim.fn.filereadable(zoomed) == 1,
  ("placed=%s orig=%s"):format(tostring(zoomed), tostring(orig)))

-- 平移取景
local px0 = st.px
pan_r()
vim.wait(300)
lib.ok("平移改变取景中心", st.px > px0, ("px=%.2f→%.2f"):format(px0, st.px))

-- 复位
reset()
vim.wait(300)
lib.ok("复位回适应窗口并放置原图", st.zoom == 1 and placed() == orig,
  ("zoom=%s placed=%s"):format(tostring(st.zoom), tostring(placed())))

vim.cmd("silent! %bwipeout!")
lib.finish()
