-- 退出类（run.sh 以"进程退出且无 [ALIVE]"判定）：
-- :exit 有无未保存修改都必须直接退出
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")
local A = lib.fixture("A.py", { "A" })

lib.reset()
vim.cmd.edit(A)
vim.api.nvim_buf_set_lines(0, -1, -1, false, { "dirty" })
print("[RUN] :exit 有未保存修改也应直接退出")
vim.api.nvim_feedkeys(lib.keys(":exit<CR>"), "x", false)
vim.wait(800)
print("[ALIVE] :exit 后程序仍在 — 功能回归！")
vim.cmd("qa!")
