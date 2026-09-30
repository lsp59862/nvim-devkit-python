-- 用户原始三窗口场景：
-- 左=L / 右上=L / 右下=:new 的 [NoName]，焦点右上，<leader>bd
-- 预期：左=dashboard、右=[NoName]、焦点在 dashboard（不误伤新文件窗口）
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")
local wb = require("nvim-devkit.winbuf")
local L = lib.fixture("L.md", { "# L" })

lib.reset()
vim.cmd.edit(L)
vim.cmd.vsplit()    -- 左 L / 右 L
vim.cmd("new")      -- :new 会新开窗口 → 右下 [NoName]
vim.cmd("wincmd k") -- 焦点右上（L）
wb.delete_buffer_and_windows()
vim.wait(300)

local dash_win, nn_win
for _, w in ipairs(vim.api.nvim_list_wins()) do
  local b = vim.api.nvim_win_get_buf(w)
  if vim.bo[b].filetype == "snacks_dashboard" then
    dash_win = w
  elseif vim.bo[b].filetype == "" and vim.fn.bufname(b) == "" and vim.bo[b].buflisted then
    nn_win = w
  end
end
local col = function(w)
  return vim.api.nvim_win_get_position(w)[2]
end
lib.ok(
  "用户场景 bd：左 dashboard、右 [NoName]、焦点 dashboard",
  lib.wins() == 2
    and dash_win ~= nil
    and nn_win ~= nil
    and col(dash_win) < col(nn_win)
    and vim.api.nvim_get_current_win() == dash_win
    and vim.fn.buflisted(vim.fn.bufnr(L)) == 0,
  ("wins=%d dash=%s nn=%s focus=%s L_listed=%s"):format(
    lib.wins(), tostring(dash_win), tostring(nn_win), tostring(vim.api.nvim_get_current_win()),
    tostring(vim.fn.buflisted(vim.fn.bufnr(L)) == 1)
  )
)
lib.finish()
