-- 真实按键路径：:bd 无参数、最后一个文件 → dashboard
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")
local A = lib.fixture("A.py", { "A" })

lib.reset()
vim.cmd.edit(A)
vim.api.nvim_feedkeys(lib.keys(":bd<CR>"), "x", false)
vim.wait(500)
lib.ok("按键 :bd 最后文件 → dashboard",
  lib.is_dashboard() and vim.fn.buflisted(vim.fn.bufnr(A)) == 0,
  ("ft=%s A_listed=%s"):format(vim.bo.filetype, tostring(vim.fn.buflisted(vim.fn.bufnr(A)) == 1)))
lib.finish()
