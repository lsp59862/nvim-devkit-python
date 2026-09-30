-- 真实按键路径：:q 单文件 → dashboard 且程序不退出
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")
local A = lib.fixture("A.py", { "A" })

lib.reset()
vim.cmd.edit(A)
vim.api.nvim_feedkeys(lib.keys(":q<CR>"), "x", false)
vim.wait(500)
lib.ok("按键 :q 单文件 → dashboard 存活", lib.is_dashboard() and lib.wins() == 1,
  ("ft=%s wins=%d"):format(vim.bo.filetype, lib.wins()))
lib.finish()
