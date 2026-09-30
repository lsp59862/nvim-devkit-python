-- 真实按键路径：:x 等价 :wq（写盘后 → dashboard）
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")
local A = lib.fixture("A.py", { "A" })

lib.reset()
vim.cmd.edit(A)
vim.api.nvim_buf_set_lines(0, -1, -1, false, { "x-content" })
vim.api.nvim_feedkeys(lib.keys(":x<CR>"), "x", false)
vim.wait(500)
lib.ok("按键 :x 写盘后 → dashboard",
  lib.is_dashboard() and table.concat(vim.fn.readfile(A), "\n"):find("x-content", 1, true) ~= nil,
  ("ft=%s 文件=%s"):format(vim.bo.filetype, table.concat(vim.fn.readfile(A), "|")))
lib.finish()
