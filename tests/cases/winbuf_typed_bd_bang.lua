-- 真实按键路径：:bd! 有未保存修改 → 跳过确认直接删（→ dashboard）
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")
local A = lib.fixture("A.py", { "A" })

lib.reset()
vim.cmd.edit(A)
vim.api.nvim_buf_set_lines(0, -1, -1, false, { "dirty" })
vim.api.nvim_feedkeys(lib.keys(":bd!<CR>"), "x", false)
vim.wait(500)
lib.ok("按键 :bd! 强制删除 → dashboard",
  lib.is_dashboard() and vim.fn.buflisted(vim.fn.bufnr(A)) == 0,
  ("ft=%s A_listed=%s"):format(vim.bo.filetype, tostring(vim.fn.buflisted(vim.fn.bufnr(A)) == 1)))
lib.finish()
