-- 查看器：等比缩放纯函数（_plan/_render_cmd）、PDF 页数解析、ft=image 普通窗口显示与键位
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")
local viewer = require("nvim-devkit.viewer")
local pdf = require("nvim-devkit.pdf")

-- _plan：z=1 整图适应画布（1000x500 图，500x250 画布 → s=0.5）
local p1 = viewer._plan(1000, 500, 500, 250, 1, 0.5, 0.5)
lib.ok("z=1：整图适应、无裁剪、落点 0,0",
  p1.crop.w == 1000 and p1.crop.h == 500 and p1.crop.x == 0 and p1.crop.y == 0
    and p1.resize.w == 500 and p1.resize.h == 250 and p1.offset.x == 0 and p1.offset.y == 0,
  vim.inspect(p1))

-- _plan：2x 中心取景（s=1）
local p2 = viewer._plan(1000, 500, 500, 250, 2, 0.5, 0.5)
lib.ok("2x：中心取景一半、等比铺满",
  p2.crop.w == 500 and p2.crop.h == 250 and p2.crop.x == 250 and p2.crop.y == 125
    and p2.resize.w == 500 and p2.resize.h == 250 and p2.offset.x == 0 and p2.offset.y == 0,
  vim.inspect(p2))

-- _plan：平移被夹紧（不允许取景越出原图）
local p3 = viewer._plan(1000, 500, 500, 250, 2, 0, 0.5)
lib.ok("平移夹紧到左边缘", p3.px == 0.25 and p3.crop.x == 0 and p3.offset.x == 0, vim.inspect(p3))
local p4 = viewer._plan(1000, 500, 500, 250, 2, 1, 0.5)
lib.ok("平移夹紧到右边缘", p4.px == 0.75 and p4.crop.x == 500, vim.inspect(p4))

-- _plan：z<1 整图缩小并居中
local p5 = viewer._plan(1000, 400, 500, 250, 0.5, 0.5, 0.5)
lib.ok("z=0.5：整图缩小并居中",
  p5.crop.w == 1000 and p5.crop.h == 400 and p5.crop.x == 0 and p5.crop.y == 0
    and p5.resize.w == 250 and p5.resize.h == 100 and p5.offset.x == 125 and p5.offset.y == 75,
  vim.inspect(p5))

-- _plan：等比（正方形图任意取景下 x/y 缩放系数一致）
local p6 = viewer._plan(1000, 1000, 500, 250, 2, 0.5, 0.5)
lib.ok("等比缩放系数一致（x/y 同为 0.5）",
  p6.resize.w / p6.crop.w == 0.5 and p6.resize.h / p6.crop.h == 0.5, vim.inspect(p6))

-- _render_cmd：透明画布 + 裁剪 + 等比缩放 + 按落点合成（不用 -extent）
local rcmd = viewer._render_cmd("magick", "in.png", "out.png", p2)
lib.ok("渲染命令结构正确",
  rcmd[1] == "magick" and rcmd[2] == "-size" and rcmd[3] == "500x250" and rcmd[4] == "xc:none"
    and rcmd[5] == "(" and rcmd[6] == "in.png"
    and rcmd[7] == "-crop" and rcmd[8] == "500x250+250+125"
    and rcmd[10] == "-resize" and rcmd[11] == "500x250"
    and rcmd[14] == "-geometry" and rcmd[15] == "+0+0" and rcmd[16] == "-composite",
  vim.inspect(rcmd))

-- PDF 页数解析（pdfinfo 输出）
lib.eq("pdfinfo Pages 解析", pdf.parse_pages("Title: x\nPages:          12\nPage size: 595 x 842 pts"), 12)
lib.eq("pdfinfo 无 Pages 行", pdf.parse_pages("Author: y"), nil)

-- 图片：普通窗口显示（无浮窗）+ 键位 + q 关闭
lib.reset()
local png_b64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
local img = lib.dir() .. "/viewer_probe.png"
do
  local f = assert(io.open(img, "wb"))
  f:write(vim.base64.decode(png_b64))
  f:close()
end
local wins_before = #vim.api.nvim_tabpage_list_wins(0)
vim.cmd("edit " .. vim.fn.fnameescape(img))
vim.bo.filetype = "image" -- 触发 FileType autocmd（真实路径由 snacks 设置）
local imgbuf = vim.api.nvim_get_current_buf()
local st = viewer.state(imgbuf)
lib.ok("图片在普通窗口显示（无浮窗）",
  vim.api.nvim_win_get_config(0).relative == "" and vim.api.nvim_get_current_buf() == imgbuf,
  ("win=%s buf=%s"):format(vim.inspect(vim.api.nvim_win_get_config(0).relative), tostring(imgbuf)))
lib.ok("未额外创建窗口", #vim.api.nvim_tabpage_list_wins(0) == wins_before,
  ("wins=%d before=%d"):format(#vim.api.nvim_tabpage_list_wins(0), wins_before))
lib.ok("查看器状态建立", st ~= nil, vim.inspect(st and { zoom = st.zoom, mode = st.mode }))

-- 防"一开始霸屏"：snacks 自带的源图挂载不应残留（它晚于画布创建且贴左上角盖满）
if vim.fn.executable("magick") == 1 then
  vim.wait(2200)
  local srcimg = require("snacks.image").image.new(vim.api.nvim_buf_get_name(imgbuf))
  local foreign = 0
  for _, p in pairs(srcimg.placements or {}) do
    if p.buf == imgbuf and not p.closed then
      foreign = foreign + 1
    end
  end
  lib.ok("初始不留 snacks 源图 placement（防霸屏）", foreign == 0, "foreign=" .. tostring(foreign))
else
  lib.ok("初始不留 snacks 源图 placement（需要 ImageMagick，跳过）", true, "optional")
end

local keys = {}
for _, m in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
  keys[m.lhs] = true
end
lib.ok("图片键位：q/+/=/−/0", keys["q"] and keys["+"] and keys["="] and keys["-"] and keys["0"],
  vim.inspect(vim.tbl_keys(keys)))
lib.ok("图片键位：平移 h/j/k/l", keys["h"] and keys["j"] and keys["k"] and keys["l"])
lib.ok("图片键位：滚轮缩放", keys["<ScrollWheelUp>"] and keys["<ScrollWheelDown>"])
lib.ok("图片无翻页键", not keys["]p"])

local q = vim.fn.maparg("q", "n", false, true).callback
if q then
  q()
  vim.wait(200)
  lib.ok("q 关闭并删除 buffer",
    not vim.api.nvim_buf_is_valid(imgbuf) and #vim.fn.win_findbuf(imgbuf) == 0,
    ("valid=%s wins=%d"):format(tostring(vim.api.nvim_buf_is_valid(imgbuf)), #vim.fn.win_findbuf(imgbuf)))
else
  lib.ok("q 键位存在", false, "callback=nil")
end

-- 逃生阀：vim.g.nvkit_viewer_wheel = 0 → 滚轮映射为空操作（不再缩放/渲染）
lib.reset()
vim.g.nvkit_viewer_wheel = 0
do
  local f = assert(io.open(img, "wb"))
  f:write(vim.base64.decode(png_b64))
  f:close()
end
vim.cmd("edit " .. vim.fn.fnameescape(img))
vim.bo.filetype = "image"
local wbuf = vim.api.nvim_get_current_buf()
local wst = viewer.state(wbuf)
local wheel_up = vim.fn.maparg("<ScrollWheelUp>", "n", false, true).callback
lib.ok("逃生阀：滚轮键位仍存在（消费事件）", wheel_up ~= nil)
local gen0 = wst.gen
if wheel_up then
  wheel_up()
end
vim.wait(250)
lib.ok("逃生阀：滚轮不改变缩放、不触发渲染", wst.zoom == 1 and wst.gen == gen0,
  ("zoom=%s gen=%d→%d"):format(tostring(wst.zoom), gen0, wst.gen))
vim.g.nvkit_viewer_wheel = nil

-- 单元格像素尺寸手动兜底（SSH 未上报像素尺寸时用 vim.g.nvkit_viewer_cell_w/_h）
if vim.fn.executable("magick") == 1 then
  lib.reset()
  vim.g.nvkit_viewer_cell_w = 10
  vim.g.nvkit_viewer_cell_h = 20
  do
    local f = assert(io.open(img, "wb"))
    f:write(vim.base64.decode(png_b64))
    f:close()
  end
  vim.cmd("edit " .. vim.fn.fnameescape(img))
  vim.bo.filetype = "image"
  local obuf = vim.api.nvim_get_current_buf()
  local ost = viewer.state(obuf)
  vim.wait(2500, function()
    return ost and ost.canvas_file ~= nil and ost.view ~= nil
  end, 50)
  local W = vim.api.nvim_win_get_width(0)
  local H = vim.api.nvim_win_get_height(0)
  local exp = viewer._view(1, 1, W, H, W * 10, H * 20, 1, 0.5, 0.5)
  local okd, dims = pcall(require("snacks.image").util.dim, ost.canvas_file)
  lib.ok("单元格尺寸手动兜底：补边几何按该尺寸计算",
    ost.canvas_file ~= nil and ost.view ~= nil and exp.mode == "rect" and okd
      and dims.width == exp.pad.w and dims.height == exp.pad.h,
    ("canvas=%s dims=%s expect=%dx%d"):format(tostring(ost.canvas_file),
      okd and ("%dx%d"):format(dims.width, dims.height) or "?",
      exp.pad.w, exp.pad.h))
  vim.g.nvkit_viewer_cell_w = nil
  vim.g.nvkit_viewer_cell_h = nil
else
  lib.ok("单元格尺寸手动兜底（需要 ImageMagick，跳过）", true, "optional")
end

-- 终端不上报像素尺寸（cell=0）时用默认 9×18 估算继续画布模式
if vim.fn.executable("magick") == 1 then
  lib.reset()
  local term = require("snacks.image").terminal.size()
  local ow, oh = term.cell_width, term.cell_height
  term.cell_width, term.cell_height = 0, 0
  do
    local f = assert(io.open(img, "wb"))
    f:write(vim.base64.decode(png_b64))
    f:close()
  end
  vim.cmd("edit " .. vim.fn.fnameescape(img))
  vim.bo.filetype = "image"
  local zst = viewer.state(vim.api.nvim_get_current_buf())
  vim.wait(2500, function()
    return zst and zst.canvas_file ~= nil and zst.view ~= nil
  end, 50)
  local W = vim.api.nvim_win_get_width(0)
  local H = vim.api.nvim_win_get_height(0)
  local exp = viewer._view(1, 1, W, H, W * 9, H * 18, 1, 0.5, 0.5)
  local okd, dims = pcall(require("snacks.image").util.dim, zst.canvas_file)
  term.cell_width, term.cell_height = ow, oh
  lib.ok("终端未上报像素尺寸时按默认 9×18 估算补边几何",
    zst.canvas_file ~= nil and zst.view ~= nil and okd
      and dims.width == exp.pad.w and dims.height == exp.pad.h,
    ("canvas=%s dims=%s expect=%dx%d"):format(tostring(zst.canvas_file),
      okd and ("%dx%d"):format(dims.width, dims.height) or "?",
      exp.pad.w, exp.pad.h))
else
  lib.ok("终端未上报像素尺寸默认估算（需要 ImageMagick，跳过）", true, "optional")
end

-- 环境缺 ImageMagick 时的降级：普通放置（左上角）、缩放不生效且不重建 placement
lib.reset()
local old_path = vim.env.PATH
vim.env.PATH = "/nonexistent"
do
  local f = assert(io.open(img, "wb"))
  f:write(vim.base64.decode(png_b64))
  f:close()
end
vim.cmd("edit " .. vim.fn.fnameescape(img))
vim.bo.filetype = "image"
local dbuf = vim.api.nvim_get_current_buf()
local dst = viewer.state(dbuf)
vim.wait(300)
lib.ok("无 magick 时退化为普通放置（不生成画布、直接放源图）",
  dst.canvas_file == nil and dst.placement ~= nil and dst.placement.img ~= nil
    and dst.placement.img.file == vim.api.nvim_buf_get_name(dbuf),
  ("canvas=%s placed=%s"):format(tostring(dst.canvas_file),
    tostring(dst.placement and dst.placement.img and dst.placement.img.file)))
local dp = dst.placement
local dplus = vim.fn.maparg("+", "n", false, true).callback
if dplus then
  dplus()
end
vim.wait(200)
lib.ok("无 magick 时缩放不生效、不重建 placement（仅提示）",
  dst.zoom == 1 and dst.placement == dp,
  ("zoom=%s same=%s"):format(tostring(dst.zoom), tostring(dst.placement == dp)))
vim.env.PATH = old_path

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
-- 假 magick：支持两种产物约定——`-write <file>`（snacks 转换）与"最后参数"（查看器画布），
-- 都拷贝一张真实 PNG；`.info` 结尾则写可解析的 identify 结果。避免"假成功但不产出"
-- 导致后续异步读取失败刷错误日志
vim.fn.writefile({
  "#!/bin/sh",
  'out=""; w=0; last=""',
  'for a; do last="$a"; if [ "$w" = 1 ]; then out="$a"; w=0; fi; [ "$a" = "-write" ] && w=1; done',
  'case "$last" in *.info) printf "PNG 1x1 72x72\n" > "$last" ;; esac',
  '[ -n "$out" ] || out="$last"',
  ('case "$out" in *.info) ;; *) cp %s "$out" ;; esac'):format(img),
  "exit 0",
}, lib.dir() .. "/magick")
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
