-- 多 tab：在 dashboard 上 :q → 只关当前 tab，程序不退出（原生行为）
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")
local wb = require("nvim-devkit.winbuf")
local A = lib.fixture("A.py", { "A" })

lib.reset()
vim.cmd.edit(A)
vim.cmd("tabnew")
wb.open_dashboard()
vim.wait(200)
lib.ok("前置：2 个 tab 且当前是 dashboard", vim.fn.tabpagenr("$") == 2 and lib.is_dashboard(),
  ("tabs=%d ft=%s"):format(vim.fn.tabpagenr("$"), vim.bo.filetype))

vim.api.nvim_feedkeys(lib.keys(":q<CR>"), "x", false)
vim.wait(500)
lib.ok("dashboard 上 :q 只关当前 tab", vim.fn.tabpagenr("$") == 1 and not lib.is_dashboard(),
  ("tabs=%d ft=%s"):format(vim.fn.tabpagenr("$"), vim.bo.filetype))
lib.finish()
