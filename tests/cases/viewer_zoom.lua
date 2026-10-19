-- 查看器缩放路径（源矩形模式 + 画布模式）：
-- zoom>=1：图片只传输一次，平移/缩放仅发"源矩形放置"请求（x/y/w/h + c/r）→ 接近本地查看器；
-- zoom<1：画布模式（整图缩小居中，magick 烘焙一次并缓存）。
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

-- 正方形测试图（便于严格断言等比）
local png = lib.dir() .. "/zoom_probe.png"
vim.system({ magick, "-size", "1200x1200", "xc:#3a7", png }):wait(10000)
lib.ok("生成测试 PNG（1200x1200 正方形）", vim.fn.filereadable(png) == 1, png)

Snacks.image.config.force = true
local orig_sleep = vim.uv.sleep
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

local W = vim.api.nvim_win_get_width(0)
local H = vim.api.nvim_win_get_height(0)
local term = Snacks.image.terminal.size()
local pw, ph = W * term.cell_width, H * term.cell_height

local function file_dims(file)
  local ok, dims = pcall(Snacks.image.util.dim, file)
  if ok then
    return dims.width, dims.height
  end
end

vim.wait(3000, function()
  return st and st.canvas_file ~= nil and st.view ~= nil
end, 50)

-- 计数：图片传输（t=d/f）与放置（a=p）/删除（a=d）
local transmits, places, deletes = 0, 0, 0
local orig_req = require("snacks.image").terminal.request
Snacks.image.terminal.request = function(opts)
  if type(opts) == "table" then
    if opts.t == "d" or opts.t == "f" then
      transmits = transmits + 1
    end
    if opts.a == "p" then
      places = places + 1
    end
    if opts.a == "d" then
      deletes = deletes + 1
    end
  end
  return orig_req(opts)
end

-- z=1：源矩形模式（一次传输 + 补边画布 + 全窗放置）
do
  local v = st.view
  lib.ok("z=1 使用源矩形模式（图片只传一次）", v ~= nil and v.mode == "rect",
    v and v.mode or "nil")
  local dw, dh = file_dims(st.canvas_file)
  lib.ok("补边画布尺寸 = 纯函数 pad 几何（窗口像素宽高比）",
    v ~= nil and dw == v.pad.w and dh == v.pad.h,
    ("dims=%sx%s pad=%dx%d"):format(tostring(dw), tostring(dh), v and v.pad.w or -1, v and v.pad.h or -1))
  lib.ok("z=1 视口 = 整幅补边画布（居中留边、无裁剪）",
    v ~= nil and v.rect.x == 0 and v.rect.y == 0 and v.rect.w == v.pad.w and v.rect.h == v.pad.h,
    v and vim.inspect(v.rect) or "nil")
  lib.ok("放置格数 = 窗口格数（等比映射前提）",
    v ~= nil and v.cells.w == W and v.cells.h == H,
    v and ("cells=%dx%d win=%dx%d"):format(v.cells.w, v.cells.h, W, H) or "nil")
end

local plus = vim.fn.maparg("+", "n", false, true).callback
local minus = vim.fn.maparg("-", "n", false, true).callback
local pan_j = vim.fn.maparg("j", "n", false, true).callback
local reset = vim.fn.maparg("0", "n", false, true).callback
lib.ok("缩放/平移/复位键位存在", plus ~= nil and minus ~= nil and pan_j ~= nil and reset ~= nil)

-- 放大：只更新源矩形，不重传图片
local t0, p0, d0 = transmits, places, deletes
plus()
vim.wait(300)
do
  local v = st.view
  lib.ok("放大后倍数生效", st.zoom == 1.25, "zoom=" .. tostring(st.zoom))
  lib.ok("放大不重传图片（源矩形模式）", transmits == t0,
    ("transmits=%d→%d"):format(t0, transmits))
  lib.ok("放大只发一次放置请求", places == p0 + 1, ("places=%d→%d"):format(p0, places))
  local exp = viewer._view(1200, 1200, W, H, pw, ph, 1.25, 0.5, 0.5)
  lib.ok("视口与纯函数一致（x/y/w/h）",
    v.rect.x == exp.rect.x and v.rect.y == exp.rect.y and v.rect.w == exp.rect.w and v.rect.h == exp.rect.h,
    ("got=%s exp=%s"):format(vim.inspect(v.rect), vim.inspect(exp.rect)))
  lib.ok("放大后矩形小于补边画布（取景放大）",
    v.rect.w < v.pad.w or v.rect.h < v.pad.h,
    ("rect=%dx%d pad=%dx%d"):format(v.rect.w, v.rect.h, v.pad.w, v.pad.h))
end

-- 平移：仅改变矩形位置（继续不重传）
local y_before = st.view.rect.y
pan_j()
vim.wait(300)
lib.ok("平移改变取景中心", st.py > 0.5, "py=" .. tostring(st.py))
lib.ok("平移仅更新矩形位置（不重传图片）",
  transmits == t0 and st.view.rect.y > y_before,
  ("transmits=%d→%d y=%d→%d"):format(t0, transmits, y_before, st.view.rect.y))

-- 复位：矩形回到整幅，仍不重传
reset()
vim.wait(300)
lib.ok("复位回适应窗口（矩形=整幅补边画布）",
  st.zoom == 1 and st.view.rect.w == st.view.pad.w and st.view.rect.h == st.view.pad.h
    and transmits == t0,
  ("zoom=%s rect=%dx%d transmits=%d"):format(tostring(st.zoom), st.view.rect.w, st.view.rect.h, transmits))

-- 源矩形模式的缩放/平移全程零 a=d（只有廉价的放置请求）
lib.ok("源矩形模式缩放/平移不删除重建（无 a=d）", deletes == d0,
  ("deletes=%d→%d"):format(d0, deletes))

-- 缩小到适应窗口以下：切画布模式（整图缩小居中，烘焙一次并缓存）
minus()
vim.wait(500)
do
  local v = st.view
  lib.ok("缩小到 0.75 切画布模式（整图缩小、长宽相等）",
    st.zoom == 0.75 and v.mode == "canvas" and v.plan.resize.w == v.plan.resize.h
      and v.plan.resize.w < v.plan.canvas.w,
    vim.inspect(v.mode == "canvas" and { mode = v.mode, resize = v.plan.resize, canvas = v.plan.canvas } or v.mode))
  lib.ok("缩小后整图居中",
    math.abs(v.plan.offset.x - (v.plan.canvas.w - v.plan.resize.w) / 2) <= 1
      and math.abs(v.plan.offset.y - (v.plan.canvas.h - v.plan.resize.h) / 2) <= 1,
    vim.inspect(v.plan.offset))
  lib.ok("画布模式需要一次画布图片传输", transmits > t0,
    ("transmits=%d→%d"):format(t0, transmits))
end
minus()
vim.wait(500)
lib.ok("缩小到 0.5", st.zoom == 0.5, "zoom=" .. tostring(st.zoom))
minus()
vim.wait(150)
lib.ok("0.5 为最小档（不再缩小）", st.zoom == 0.5, "zoom=" .. tostring(st.zoom))
local t_canvas75 = transmits

reset()
vim.wait(400)
lib.ok("复位回源矩形模式且不重传（补边画布已缓存）",
  st.zoom == 1 and st.view.mode == "rect" and transmits == t_canvas75,
  ("zoom=%s mode=%s transmits=%d→%d"):format(tostring(st.zoom), st.view.mode, t_canvas75, transmits))

-- 渲染节流：按键连发合并（降低终端重绘压力；长按平移/缩放更顺）
do
  reset()
  vim.wait(300)
  plus()
  plus()
  vim.wait(300)
  lib.ok("节流前状态：1.5x 可平移", st.zoom == 1.5, "zoom=" .. tostring(st.zoom))
  local ap = 0
  local orig_req3 = require("snacks.image").terminal.request
  Snacks.image.terminal.request = function(opts)
    if type(opts) == "table" and opts.a == "p" then
      ap = ap + 1
    end
    return orig_req3(opts)
  end
  local py0 = st.py
  pan_j()
  pan_j()
  lib.ok("连发平移在节流窗口内不立即绘制", ap == 0, "ap=" .. tostring(ap))
  vim.wait(250)
  Snacks.image.terminal.request = orig_req3
  lib.ok("节流后合并为一次绘制（两段位移都生效）",
    ap == 1 and math.abs(st.py - (py0 + 0.10)) < 0.02,
    ("ap=%d py=%.3f→%.3f"):format(ap, py0, st.py))
  reset()
  vim.wait(300)
end

-- 幂等：重复复位不重传、不删除
do
  local t1, d1 = transmits, deletes
  reset()
  vim.wait(300)
  lib.ok("重复复位幂等（不重传、不删除）", transmits == t1 and deletes == d1,
    ("transmits=%d→%d deletes=%d→%d"):format(t1, transmits, d1, deletes))
end

-- 离开图片窗口要删除 placement（空 buffer 间切换不会重绘单元格，旧图会残留叠加）
do
  reset()
  vim.wait(300)
  local ad = 0
  local orig_req6 = require("snacks.image").terminal.request
  Snacks.image.terminal.request = function(opts)
    if type(opts) == "table" and opts.a == "d" then
      ad = ad + 1
    end
    return orig_req6(opts)
  end
  local win = vim.api.nvim_get_current_win()
  local textbuf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_name(textbuf, lib.dir() .. "/leave_text.lua")
  vim.api.nvim_win_set_buf(win, textbuf)
  vim.wait(400)
  lib.ok("离开图片窗口时删除 placement（防旧图残留叠加）", ad >= 1,
    "ad=" .. tostring(ad))
  vim.api.nvim_win_set_buf(win, buf)
  vim.wait(600)
  Snacks.image.terminal.request = orig_req6
  lib.ok("回到图片窗口后自动恢复显示", st.image_hidden == false and st.view ~= nil,
    ("hidden=%s view=%s"):format(tostring(st.image_hidden), tostring(st.view ~= nil)))
end

-- 滚轮缩放：档位立即生效 + 节流合并重绘（与按键一致：滚动中持续更新、停下必绘最终状态）
do
  reset()
  vim.wait(300)
  local wheel_up = vim.fn.maparg("<ScrollWheelUp>", "n", false, true).callback
  lib.ok("滚轮缩放键存在", wheel_up ~= nil)
  local gen0 = st.gen
  local ap = 0
  local notifications = 0
  local orig_notify = vim.notify
  vim.notify = function(msg, ...)
    if tostring(msg):find("^查看器:") then
      notifications = notifications + 1
    end
    return orig_notify(msg, ...)
  end
  local orig_wreq = require("snacks.image").terminal.request
  Snacks.image.terminal.request = function(opts)
    if type(opts) == "table" and opts.a == "p" then
      ap = ap + 1
    end
    return orig_wreq(opts)
  end
  if wheel_up then
    wheel_up()
    wheel_up()
    wheel_up()
  end
  lib.ok("滚轮连拨立即推进档位（1→2）", math.abs(st.zoom - 2) < 0.001, "zoom=" .. tostring(st.zoom))
  lib.ok("节流窗口内不重复绘制", ap == 0, "ap=" .. tostring(ap))
  local done = vim.wait(1500, function()
    return ap >= 1
  end, 20)
  vim.wait(200)
  Snacks.image.terminal.request = orig_wreq
  vim.notify = orig_notify
  lib.ok("滚轮停下后合并绘制一次（节流）", done and ap == 1 and st.gen == gen0 + 1,
    ("ap=%d gen=%d→%d"):format(ap, gen0, st.gen))
  lib.ok("图片变化不再通知", notifications == 0, "notifications=" .. tostring(notifications))
end

-- 传输入口不残留（uv.sleep 包装还原）
lib.ok("传输加速包装不残留（uv.sleep 已还原）", vim.uv.sleep == orig_sleep,
  ("same=%s"):format(tostring(vim.uv.sleep == orig_sleep)))

-- 窗口事件不再即时重定位；静默后合并重放（源矩形模式：一次 a=p、无重传）
do
  Snacks.image.terminal.request = orig_req
  reset()
  vim.wait(300)
  local ap, ad = 0, 0
  local t_before = transmits
  local count_req = function(opts)
    if type(opts) == "table" then
      if opts.a == "p" then
        ap = ap + 1
      elseif opts.a == "d" then
        ad = ad + 1
      end
    end
    return orig_req(opts)
  end
  Snacks.image.terminal.request = count_req
  pcall(function()
    require("snacks.notifier").hide()
  end)
  vim.wait(300)
  local fbuf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(fbuf, false, { relative = "editor", width = 10, height = 3, row = 1, col = 1 })
  vim.wait(200)
  lib.ok("浮窗出现时图片自动隐藏", ad >= 1 and st.image_hidden == true,
    ("ad=%d hidden=%s"):format(ad, tostring(st.image_hidden)))
  vim.api.nvim_win_close(win, true)
  vim.wait(1400)
  Snacks.image.terminal.request = orig_req
  lib.ok("浮窗关闭后自动重放恢复", ap >= 1 and st.image_hidden == false,
    ("ap=%d hidden=%s"):format(ap, tostring(st.image_hidden)))
end

-- 回归：文件浏览器流程下切回图片应快速恢复（不再"按键才显示"）
do
  reset()
  vim.wait(300)
  local ap = 0
  local orig_req4 = require("snacks.image").terminal.request
  Snacks.image.terminal.request = function(opts)
    if type(opts) == "table" and opts.a == "p" then
      ap = ap + 1
    end
    return orig_req4(opts)
  end
  local main = vim.api.nvim_get_current_win()
  local fbuf = vim.api.nvim_create_buf(false, true)
  local fwin = vim.api.nvim_open_win(fbuf, true, {
    relative = "editor",
    width = 30,
    height = 8,
    row = 5,
    col = 10,
    style = "minimal",
    border = "rounded",
  })
  vim.wait(150)
  local hidden_in_float = st.image_hidden
  -- picker 真实顺序：关浮窗 → 打开别的文件 → 再切回图片
  vim.api.nvim_win_close(fwin, true)
  local codebuf = vim.api.nvim_create_buf(true, false)
  vim.api.nvim_buf_set_name(codebuf, lib.dir() .. "/other.lua")
  vim.api.nvim_win_set_buf(main, codebuf)
  vim.wait(200)
  vim.api.nvim_win_set_buf(main, buf)
  local t0 = vim.uv.now()
  local done = vim.wait(1500, function()
    return ap >= 1
  end, 20)
  local elapsed = vim.uv.now() - t0
  Snacks.image.terminal.request = orig_req4
  lib.ok("浮窗打开时图片被隐藏", hidden_in_float == true, "hidden=" .. tostring(hidden_in_float))
  lib.ok("切回图片 1s 内自动恢复（不按键）", done and ap >= 1 and st.image_hidden == false,
    ("ap=%d elapsed=%dms hidden=%s"):format(ap, elapsed, tostring(st.image_hidden)))
end

-- 回归：同一 buffer 重开（:buffer <当前图片> 无任何进入事件）也要自动恢复
do
  reset()
  vim.wait(300)
  local ap = 0
  local orig_req5 = require("snacks.image").terminal.request
  Snacks.image.terminal.request = function(opts)
    if type(opts) == "table" and opts.a == "p" then
      ap = ap + 1
    end
    return orig_req5(opts)
  end
  local fbuf = vim.api.nvim_create_buf(false, true)
  local fwin = vim.api.nvim_open_win(fbuf, true, {
    relative = "editor",
    width = 30,
    height = 8,
    row = 5,
    col = 10,
    style = "minimal",
    border = "rounded",
  })
  vim.wait(150)
  vim.api.nvim_win_close(fwin, true)
  vim.cmd("buffer " .. buf) -- 真实 picker 对当前 buffer 的打开方式（无事件）
  local t0 = vim.uv.now()
  local done = vim.wait(1500, function()
    return ap >= 1
  end, 20)
  local elapsed = vim.uv.now() - t0
  Snacks.image.terminal.request = orig_req5
  lib.ok("同一 buffer 重开：浮窗关闭后 ≤600ms 自动恢复（不按键）",
    done and ap >= 1 and st.image_hidden == false and elapsed < 600,
    ("ap=%d elapsed=%dms hidden=%s"):format(ap, elapsed, tostring(st.image_hidden)))
end

-- 命令行浮窗（noice）打开时图片自动隐藏，界面清空后恢复
do
  reset()
  vim.wait(300)
  pcall(function()
    require("snacks.notifier").hide()
  end)
  vim.wait(300)
  local ap, ad = 0, 0
  local orig_req2 = require("snacks.image").terminal.request
  Snacks.image.terminal.request = function(opts)
    if type(opts) == "table" then
      if opts.a == "p" then
        ap = ap + 1
      elseif opts.a == "d" then
        ad = ad + 1
      end
    end
    return orig_req2(opts)
  end
  vim.api.nvim_exec_autocmds("CmdlineEnter", {})
  vim.wait(150)
  lib.ok("打开命令行时图片自动隐藏", ad >= 1, "ad=" .. tostring(ad))
  vim.api.nvim_exec_autocmds("CmdlineLeave", {})
  local done = vim.wait(2000, function()
    return ap >= 1
  end, 50)
  Snacks.image.terminal.request = orig_req2
  lib.ok("离开命令行且界面清空后图片恢复", done and ap >= 1, ("ap=%d ad=%d"):format(ap, ad))
end

vim.cmd("silent! %bwipeout!")
lib.finish()
