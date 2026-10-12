-- 查看器：缩放裁剪几何、PDF 页数解析、ft=image 键位安装
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")
local viewer = require("nvim-devkit.viewer")
local pdf = require("nvim-devkit.pdf")

-- 缩放几何（纯函数）
local fit = viewer._crop(1000, 500, 1, 0.5, 0.5)
lib.ok("适应窗口：裁剪=原图", fit.w == 1000 and fit.h == 500 and fit.x == 0 and fit.y == 0,
  vim.inspect(fit))
local half = viewer._crop(1000, 500, 2, 0.5, 0.5)
lib.ok("2x：中心裁剪一半", half.w == 500 and half.h == 250 and half.x == 250 and half.y == 125,
  vim.inspect(half))
local clamped = viewer._crop(1000, 500, 2, 2, -1)
lib.ok("平移越界被夹紧", clamped.x == 500 and clamped.y == 0, vim.inspect(clamped))
local cmd = viewer._crop_cmd("magick", "in.png", "out.png", half)
lib.ok("裁剪命令正确", cmd[1] == "magick" and cmd[3] == "-crop" and cmd[4] == "500x250+250+125",
  vim.inspect(cmd))

-- PDF 页数解析（pdfinfo 输出）
lib.eq("pdfinfo Pages 解析", pdf.parse_pages("Title: x\nPages:          12\nPage size: 595 x 842 pts"), 12)
lib.eq("pdfinfo 无 Pages 行", pdf.parse_pages("Author: y"), nil)

-- ft=image 的 buffer 安装查看器键位
lib.reset()
local img = lib.fixture("viewer_probe.png", { "not-a-real-png" })
vim.cmd("edit " .. vim.fn.fnameescape(img))
vim.bo.filetype = "image" -- 触发 FileType autocmd（snacks 已挂载后的状态）
local keys = {}
for _, m in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
  keys[m.lhs] = true
end
lib.ok("图片键位：q/+/=/−/0", keys["q"] and keys["+"] and keys["="] and keys["-"] and keys["0"],
  vim.inspect(vim.tbl_keys(keys)))
lib.ok("图片键位：平移 h/j/k/l", keys["h"] and keys["j"] and keys["k"] and keys["l"])
lib.ok("图片键位：滚轮缩放", keys["<ScrollWheelUp>"] and keys["<ScrollWheelDown>"])
lib.ok("图片无翻页键", not keys["]p"])

-- 另一 buffer 的 pdf 场景：翻页 + rt 切文本
lib.reset()
local pdfbuf = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(pdfbuf, "/tmp/nvim-devkit-tests/viewer_probe.pdf")
vim.api.nvim_set_current_buf(pdfbuf)
vim.bo.filetype = "image"
local pkeys = {}
for _, m in ipairs(vim.api.nvim_buf_get_keymap(pdfbuf, "n")) do
  pkeys[m.lhs] = true
end
lib.ok("PDF 图片模式：]p/[p 翻页", pkeys["]p"] and pkeys["[p"])
lib.ok("PDF 图片模式：滚轮翻页", pkeys["<ScrollWheelDown>"] and pkeys["<ScrollWheelUp>"])
lib.ok("PDF 图片模式：<leader>rt 切文本", pkeys[" rt"] == true)

-- 模拟 Kitty 协议 + ImageMagick：PDF 默认按页看图（BufReadCmd 放行给 snacks.image）
vim.env.NVIM_DEVKIT_IMAGE_BACKEND = "kitty"
vim.fn.writefile({ "#!/bin/sh", "exit 0" }, lib.dir() .. "/magick")
vim.fn.setfperm(lib.dir() .. "/magick", "rwxr-xr-x")
vim.env.PATH = lib.dir() .. ":" .. vim.env.PATH
require("snacks.image").config.force = true

local fakepdf = lib.dir() .. "/fake.pdf"
vim.fn.writefile({ "%PDF-1.4", "%%EOF" }, fakepdf)
lib.reset()
vim.cmd("edit " .. vim.fn.fnameescape(fakepdf))
vim.wait(3000)
lib.eq("PDF 默认图片模式（Kitty+magick）", vim.bo.filetype, "image")
local dkeys = {}
for _, m in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
  dkeys[m.lhs] = true
end
lib.ok("默认图片模式下翻页键可用", dkeys["]p"] == true and dkeys["<ScrollWheelDown>"] == true)

lib.finish()
