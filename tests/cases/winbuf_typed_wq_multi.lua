-- 真实按键路径：:wq 有其它文件 → 写盘 + 切到其它文件（程序不退）
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")
local A = lib.fixture("A.py", { "A" })
local B = lib.fixture("B.md", { "B" })

lib.reset()
vim.cmd.edit(B); vim.cmd.edit(A)
vim.api.nvim_buf_set_lines(0, -1, -1, false, { "wq-multi" })
vim.api.nvim_feedkeys(lib.keys(":wq<CR>"), "x", false)
vim.wait(500)
lib.ok("按键 :wq 有其它文件 → 写盘并切换",
  not lib.is_dashboard()
    and table.concat(vim.fn.readfile(A), "\n"):find("wq-multi", 1, true) ~= nil
    and vim.fn.bufname() == B
    and vim.fn.buflisted(vim.fn.bufnr(A)) == 0
    and lib.wins() == 1,
  ("当前=%s A_written=%s"):format(lib.base(vim.fn.bufname()), tostring(table.concat(vim.fn.readfile(A), "\n"):find("wq-multi", 1, true) ~= nil)))
lib.finish()
