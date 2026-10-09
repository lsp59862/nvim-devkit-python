-- Ctrl+Shift+= 最大化/还原：底部撑满高度、浮动全屏、二次还原、无终端 no-op
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")
local term = require("nvim-devkit.term")
term.setup()

lib.ok("最大化键位映射存在（覆盖多种终端编码）",
  vim.fn.maparg("<C-S-=>", "t", false, true).callback ~= nil
    and vim.fn.maparg("<C-S-+>", "t", false, true).callback ~= nil
    and vim.fn.maparg("<C-=>", "n", false, true).callback ~= nil
    and vim.fn.maparg("<C-+>", "t", false, true).callback ~= nil)
lib.ok("<F13> 转发键映射存在（WezTerm 等占用 Ctrl+Shift+= 的终端）",
  vim.fn.maparg("<F13>", "t", false, true).callback ~= nil
    and vim.fn.maparg("<F13>", "n", false, true).callback ~= nil)

lib.reset()
lib.ok("无终端时 toggle_zoom 为 no-op", pcall(term.toggle_zoom))

-- 底部：高度撑满
term.summon("bottom")
vim.wait(300)
local h0 = vim.api.nvim_win_get_height(term.main_win("bottom"))
term.toggle_zoom()
vim.wait(100)
local h1 = vim.api.nvim_win_get_height(term.main_win("bottom"))
lib.ok("底部最大化：高度变大且接近满屏", h1 > h0 and h1 >= vim.o.lines - 5,
  ("h0=%d h1=%d lines=%d"):format(h0, h1, vim.o.lines))
lib.ok("最大化后侧边栏同步高度", vim.api.nvim_win_get_height(term.side_win("bottom")) == h1)
term.toggle_zoom()
vim.wait(100)
lib.ok("再按还原高度", vim.api.nvim_win_get_height(term.main_win("bottom")) == h0,
  ("h=%d want=%d"):format(vim.api.nvim_win_get_height(term.main_win("bottom")), h0))

-- 浮动：全屏
term.summon("float")
vim.wait(400)
local before = vim.api.nvim_win_get_config(term.main_win("float"))
term.toggle_zoom()
vim.wait(200)
local zoomed = vim.api.nvim_win_get_config(term.main_win("float"))
lib.ok("浮动最大化到全屏", zoomed.row == 0 and zoomed.height >= vim.o.lines - 3,
  ("row=%s h=%s"):format(tostring(zoomed.row), tostring(zoomed.height)))
term.toggle_zoom()
vim.wait(200)
local restored = vim.api.nvim_win_get_config(term.main_win("float"))
lib.ok("浮动还原原始几何",
  restored.row == before.row and restored.height == before.height and restored.width == before.width,
  ("row=%s→%s h=%s→%s w=%s→%s"):format(tostring(before.row), tostring(restored.row),
    tostring(before.height), tostring(restored.height), tostring(before.width), tostring(restored.width)))

for _, t in ipairs(term.terms()) do
  term.kill(t.id)
end
vim.wait(400)
lib.finish()
