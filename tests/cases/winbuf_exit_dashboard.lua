-- 退出类（run.sh 以"进程退出且无 [ALIVE]"判定）：
-- dashboard 上 :q → 退出 nvim
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")
local wb = require("nvim-devkit.winbuf")

lib.reset()
wb.open_dashboard()
vim.wait(300)
print("[RUN] dashboard 上 :q 应退出 nvim")
vim.api.nvim_feedkeys(lib.keys(":q<CR>"), "x", false)
vim.wait(800)
print("[ALIVE] dashboard :q 后程序仍在 — 功能回归！")
vim.cmd("qa!")
