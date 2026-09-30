-- 真实按键路径：:q! 丢弃修改 → dashboard，文件内容未写盘
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")
local A = lib.fixture("A.py", { "A" })

lib.reset()
vim.cmd.edit(A)
vim.api.nvim_buf_set_lines(0, -1, -1, false, { "discard-me" })
vim.api.nvim_feedkeys(lib.keys(":q!<CR>"), "x", false)
vim.wait(500)
lib.ok("按键 :q! 丢弃修改 → dashboard",
  lib.is_dashboard() and vim.fn.readfile(A)[1] == "A" and lib.wins() == 1,
  ("ft=%s 文件=%s"):format(vim.bo.filetype, vim.fn.readfile(A)[1]))
lib.finish()
