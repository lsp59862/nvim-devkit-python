-- 查看器真实缩放路径（等比画布模型）：
-- 每档缩放在"窗口像素画布"上等比重绘：=1 适应窗口居中、<1 整图缩小居中、>1 放大后平移取景。
-- 画布像素与窗口格子一一对应；画布比格子数×单元格像素多 1px，确保映射到整数格子（避免拉伸失真）。
-- 覆盖回归：曾用"裁剪+格子取整"导致各档宽高比抖动；曾双层索引崩溃；曾先清后画闪烁。
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
local function placed()
  return st and st.placement and st.placement.img and st.placement.img.file or nil
end
local function file_dims(file)
  local ok, dims = pcall(Snacks.image.util.dim, file)
  if ok then
    return dims.width, dims.height
  end
end

vim.wait(2000, function()
  return st and st.placement and st.placement._state ~= nil
end, 50)

-- 画布几何（与实现同一公式）
local term = Snacks.image.terminal.size()
local W = vim.api.nvim_win_get_width(0)
local H = vim.api.nvim_win_get_height(0)
local pw = math.floor(W * term.cell_width) + 1
local ph = math.floor(H * term.cell_height) + 1

do
  local dw, dh = file_dims(placed())
  lib.ok("z=1 放置窗口画布（普通窗口、cache 内 PNG、画布像素尺寸精确）",
    vim.api.nvim_win_get_config(0).relative == "" and placed() ~= nil and placed():find(cache, 1, true) ~= nil
      and dw == pw and dh == ph,
    ("placed=%s dims=%dx%d expect=%dx%d"):format(tostring(placed()), dw or -1, dh or -1, pw, ph))
end
do
  local loc = st.placement._state and st.placement._state.loc
  lib.ok("画布按窗口整数格子映射（无拉伸失真前提）",
    loc ~= nil and loc.width == W and loc.height == H,
    ("loc=%s win=%dx%d"):format(loc and ("%sx%s"):format(loc.width, loc.height) or "nil", W, H))
end
do
  local plan = st.plan
  lib.ok("z=1 整图等比（正方形图 resize 长宽相等、无裁剪）",
    plan ~= nil and plan.resize.w == plan.resize.h and plan.crop.w == 1200 and plan.crop.h == 1200,
    vim.inspect(plan and { resize = plan.resize, crop = plan.crop }))
  lib.ok("z=1 整图居中（偏移≈画布余量一半）",
    plan ~= nil
      and math.abs(plan.offset.x - (pw - plan.resize.w) / 2) <= 1
      and math.abs(plan.offset.y - (ph - plan.resize.h) / 2) <= 1,
    vim.inspect(plan and plan.offset))
end

local plus = vim.fn.maparg("+", "n", false, true).callback
local minus = vim.fn.maparg("-", "n", false, true).callback
local pan_j = vim.fn.maparg("j", "n", false, true).callback
local reset = vim.fn.maparg("0", "n", false, true).callback
lib.ok("缩放/平移/复位键位存在", plus ~= nil and minus ~= nil and pan_j ~= nil and reset ~= nil)

-- 放大：仍是窗口画布，且等比（x/y 缩放系数一致）
local orig_sleep = vim.uv.sleep
plus()
vim.wait(300)
lib.ok("传输加速包装不残留（uv.sleep 已还原）", vim.uv.sleep == orig_sleep)
lib.ok("放大后倍数生效", st.zoom > 1.0001, "zoom=" .. tostring(st.zoom))
do
  local dw, dh = file_dims(placed())
  lib.ok("放大后放置的仍是窗口画布（cache 内 PNG）",
    placed() ~= nil and placed():find(cache, 1, true) ~= nil and dw == pw and dh == ph,
    ("placed=%s dims=%sx%s expect=%dx%d"):format(tostring(placed()), tostring(dw), tostring(dh), pw, ph))
end
do
  local plan = st.plan
  local sx = plan and plan.resize.w / plan.crop.w or 0
  local sy = plan and plan.resize.h / plan.crop.h or 0
  lib.ok("放大后等比（x/y 缩放系数一致）", math.abs(sx - sy) < 0.005,
    ("sx=%.4f sy=%.4f"):format(sx, sy))
end

-- 防闪烁（换图时旧的先保留，稍后再撤）
local old_p = st.placement
plus()
lib.ok("换图时旧 placement 暂不关闭（先画新、后撤旧）",
  st.placement ~= old_p and old_p.closed ~= true, ("old_closed=%s"):format(tostring(old_p.closed)))
do
  local ok, autocmds = pcall(vim.api.nvim_get_autocmds, { group = old_p.augroup })
  lib.ok("旧 placement 的自动更新已即时停用（少发 a=p）",
    not ok or #autocmds == 0, ok and ("autocmds=%d"):format(#autocmds) or "group 已删除")
end
vim.wait(400)
lib.ok("旧 placement 随后被清理", old_p.closed == true, ("old_closed=%s"):format(tostring(old_p.closed)))

-- 平移：改变取景中心（正方形图在宽窗下沿 y 可平移）
local py0 = st.py
pan_j()
vim.wait(300)
lib.ok("平移改变取景中心", st.py > py0, ("py=%.2f→%.2f"):format(py0, st.py))

-- 复位
reset()
vim.wait(300)
lib.ok("复位回适应窗口", st.zoom == 1 and placed() == st.canvas_file,
  ("zoom=%s placed=%s"):format(tostring(st.zoom), tostring(placed())))

-- 缩小到比适应窗口更小（0.75 / 0.5 档）
minus()
vim.wait(300)
do
  local plan = st.plan
  lib.ok("缩小到 0.75（整图缩小，长宽仍相等）",
    math.abs(st.zoom - 0.75) < 0.001 and plan ~= nil and plan.resize.w == plan.resize.h
      and plan.resize.w < pw and plan.crop.w == 1200,
    vim.inspect(plan and { zoom = st.zoom, resize = plan.resize, crop = plan.crop }))
  lib.ok("缩小后整图居中",
    plan ~= nil
      and math.abs(plan.offset.x - (pw - plan.resize.w) / 2) <= 1
      and math.abs(plan.offset.y - (ph - plan.resize.h) / 2) <= 1,
    vim.inspect(plan and plan.offset))
end
minus()
vim.wait(300)
lib.ok("缩小到 0.5", math.abs(st.zoom - 0.5) < 0.001, "zoom=" .. tostring(st.zoom))
minus()
vim.wait(100)
lib.ok("0.5 为最小档（不再缩小）", math.abs(st.zoom - 0.5) < 0.001, "zoom=" .. tostring(st.zoom))
reset()
vim.wait(300)
lib.ok("再次复位回适应窗口", st.zoom == 1 and placed() == st.canvas_file,
  ("zoom=%s placed=%s"):format(tostring(st.zoom), tostring(placed())))

-- 幂等：稳定状态下重复复位不重建 placement（避免无意义 a=p）
do
  local p_now = st.placement
  reset()
  vim.wait(250)
  lib.ok("重复复位幂等（不重建 placement）", st.placement == p_now and st.zoom == 1,
    ("same=%s zoom=%s"):format(tostring(st.placement == p_now), tostring(st.zoom)))
end

-- 滚轮合并渲染：连拨三次只渲染一次、只通知一次（防 WezTerm #7953 的 a=p 风暴）
do
  reset()
  vim.wait(300)
  local wheel_up = vim.fn.maparg("<ScrollWheelUp>", "n", false, true).callback
  lib.ok("滚轮缩放键存在", wheel_up ~= nil)
  local gen0 = st.gen
  local notifications = 0
  local orig_notify = vim.notify
  vim.notify = function(msg, ...)
    if tostring(msg):find("^查看器:") then
      notifications = notifications + 1
    end
    return orig_notify(msg, ...)
  end
  if wheel_up then
    wheel_up()
    wheel_up()
    wheel_up()
  end
  lib.ok("滚轮连拨立即推进档位（1→2）", math.abs(st.zoom - 2) < 0.001, "zoom=" .. tostring(st.zoom))
  vim.wait(60)
  lib.ok("合并窗口内不渲染", st.gen == gen0, ("gen=%d→%d"):format(gen0, st.gen))
  local done = vim.wait(1500, function()
    return st.gen > gen0
  end, 20)
  vim.wait(120)
  vim.notify = orig_notify
  lib.ok("停下后合并渲染一次", done and st.gen == gen0 + 1, ("gen=%d→%d"):format(gen0, st.gen))
  lib.ok("图片变化不再通知", notifications == 0, "notifications=" .. tostring(notifications))
end

-- 窗口事件不再即时重定位；静默 ~0.8s 后合并一次（WezTerm #7953 防护）
do
  reset()
  vim.wait(300)
  local ap, ad = 0, 0
  local orig_req = Snacks.image.terminal.request
  Snacks.image.terminal.request = function(opts)
    if type(opts) == "table" then
      if opts.a == "p" then
        ap = ap + 1
      elseif opts.a == "d" then
        ad = ad + 1
      end
    end
    return orig_req(opts)
  end
  -- 先清空前面用例积累的通知浮窗（它们的 WinClosed 会不断作废防抖计时）
  pcall(function()
    require("snacks.notifier").hide()
  end)
  vim.wait(300)
  local fbuf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(fbuf, false, { relative = "editor", width = 10, height = 3, row = 1, col = 1 })
  vim.wait(200)
  lib.ok("浮窗出现时图片自动隐藏（不再每次事件发 a=p）", ap == 0 and ad >= 1,
    ("ap=%d ad=%d"):format(ap, ad))
  vim.api.nvim_win_close(win, true)
  vim.wait(1400)
  Snacks.image.terminal.request = orig_req
  do
    local nf, names = 0, {}
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      local c = vim.api.nvim_win_get_config(w)
      if c.relative ~= "" then
        nf = nf + 1
        names[#names + 1] = ("%d:%s"):format(w, vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w)):sub(-24))
      end
    end
    lib.ok("浮窗关闭后静默合并重定位一次", ap == 1,
      ("ap=%d token=%s valid=%s wins=%d closed=%s floats=%d[%s]"):format(ap, tostring(st.replace_token),
        tostring(vim.api.nvim_buf_is_valid(buf)), #vim.fn.win_findbuf(buf),
        tostring(st.placement and st.placement.closed), nf, table.concat(names, ",")))
  end
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
  local orig_req = Snacks.image.terminal.request
  Snacks.image.terminal.request = function(opts)
    if type(opts) == "table" then
      if opts.a == "p" then
        ap = ap + 1
      elseif opts.a == "d" then
        ad = ad + 1
      end
    end
    return orig_req(opts)
  end
  vim.api.nvim_exec_autocmds("CmdlineEnter", {})
  vim.wait(150)
  lib.ok("打开命令行时图片自动隐藏", ad >= 1, "ad=" .. tostring(ad))
  vim.api.nvim_exec_autocmds("CmdlineLeave", {})
  local done = vim.wait(2000, function()
    return ap >= 1
  end, 50)
  Snacks.image.terminal.request = orig_req
  lib.ok("离开命令行且界面清空后图片恢复", done and ap >= 1, ("ap=%d ad=%d"):format(ap, ad))
end

vim.cmd("silent! %bwipeout!")
lib.finish()
