-- 图片避让浮窗：只有真正遮挡图片窗口的浮窗才隐藏；
-- 文件树 sidebar（左侧 split，其 input/list 是 split 内浮窗）不应导致图片消失。
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")
local viewer = require("nvim-devkit.viewer")
local magick = vim.fn.executable("magick") == 1 and "magick"
  or (vim.fn.executable("convert") == 1 and "convert" or nil)
if not magick then
  lib.ok("ImageMagick 缺失：跳过浮窗避让测试", true, "optional dependency")
  lib.finish()
  return
end
require("snacks.image").config.force = true

lib.reset()
local png = lib.dir() .. "/float_img.png"
vim.system({ magick, "-size", "800x600", "xc:#3a7", png }):wait(10000)
vim.cmd.edit(png)
vim.wait(4000, function()
  return vim.bo.filetype == "image"
end, 50)
local buf = vim.api.nvim_get_current_buf()
local st = viewer.state(buf)
lib.ok("图片查看器就绪（浮窗测试）", st ~= nil and st.view ~= nil,
  vim.inspect(st and { view = st.view ~= nil, img = st.img ~= nil }))

-- 打开真实文件树：左侧 split + 其内部 input/list 浮窗 → 图片应保持显示
local ex = require("nvim-devkit.explorer")
local pk = ex.open({ layout = { preset = "sidebar", preview = false } })
vim.wait(1500, function()
  local ok, items = pcall(function()
    return pk and pk:items()
  end)
  return ok and type(items) == "table" and #items > 0
end, 20)
vim.wait(500)
vim.api.nvim_exec_autocmds("WinEnter", {})
vim.wait(800)
local s1 = viewer.state(buf)
lib.ok("文件树打开时图片保持显示（侧边栏浮窗不遮挡图片窗口）",
  s1 ~= nil and s1.image_hidden == false
    and (s1.img ~= nil or (s1.placement ~= nil and not s1.placement.closed)),
  ("hidden=%s img=%s plac=%s"):format(tostring(s1 and s1.image_hidden),
    tostring(s1 and s1.img ~= nil), tostring(s1 and s1.placement ~= nil)))

-- 命令行来去：短暂隐藏后应恢复（文件树仍开着）
vim.api.nvim_exec_autocmds("CmdlineEnter", {})
vim.wait(100)
local hidden_cmd = viewer.state(buf) and viewer.state(buf).image_hidden
vim.api.nvim_exec_autocmds("CmdlineLeave", {})
local restored_cmd = vim.wait(2000, function()
  local x = viewer.state(buf)
  return x ~= nil and x.image_hidden == false
end, 50)
lib.ok("命令行关闭后图片自动恢复（文件树仍开着）",
  hidden_cmd == true and restored_cmd,
  ("hidden_cmd=%s restored=%s"):format(tostring(hidden_cmd), tostring(restored_cmd)))

if pk then
  pcall(function()
    pk:close()
  end)
end
vim.wait(500)

-- 遮挡图片窗口的浮窗：隐藏；关闭后自动恢复
local fb = vim.api.nvim_create_buf(false, true)
local fwin = vim.api.nvim_open_win(fb, false, {
  relative = "editor",
  row = 1,
  col = 1,
  width = 30,
  height = 5,
  style = "minimal",
})
vim.wait(300)
vim.api.nvim_exec_autocmds("WinEnter", {})
vim.wait(600)
local hidden = viewer.state(buf) and viewer.state(buf).image_hidden
pcall(vim.api.nvim_win_close, fwin, true)
local restored = vim.wait(2000, function()
  local x = viewer.state(buf)
  return x ~= nil and x.image_hidden == false
end, 50)
lib.ok("遮挡浮窗出现时图片隐藏", hidden == true, tostring(hidden))
lib.ok("遮挡浮窗关闭后图片自动恢复", restored, tostring(restored))

-- 已在 buffer 的图片 + 文件树开着 + 分屏内 :buffer → 仍能显示
vim.cmd("enew")
vim.wait(300)
local pk2 = ex.open({ layout = { preset = "sidebar", preview = false } })
vim.wait(1000)
vim.cmd("split")
vim.wait(300)
vim.cmd("buffer " .. buf)
local okpaint = vim.wait(5000, function()
  local x = viewer.state(buf)
  return x ~= nil and x.image_hidden == false
    and (x.img ~= nil or (x.placement ~= nil and not x.placement.closed))
end, 50)
lib.ok("文件树开着时 :b 切回已加载图片（分屏窗口）能显示", okpaint,
  vim.inspect(viewer.state(buf) and {
    hidden = viewer.state(buf).image_hidden,
    img = viewer.state(buf).img ~= nil,
  }))
if pk2 then
  pcall(function()
    pk2:close()
  end)
end

vim.cmd("silent! only")
vim.cmd("silent! %bwipeout!")
lib.finish()
