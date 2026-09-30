-- 真实按键路径：:bd <nr> 带参数透传原生（只删指定 buffer）
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")
local A = lib.fixture("A.py", { "A" })
local B = lib.fixture("B.md", { "B" })

lib.reset()
vim.cmd.edit(A); vim.cmd.edit(B)
local nr = vim.fn.bufnr(A)
vim.api.nvim_feedkeys(lib.keys(":bd " .. nr .. "<CR>"), "x", false)
vim.wait(500)
lib.ok("按键 :bd <nr> 透传", vim.fn.buflisted(nr) == 0 and vim.fn.bufname() == B,
  ("A_listed=%s 当前=%s"):format(tostring(vim.fn.buflisted(nr) == 1), lib.base(vim.fn.bufname())))
lib.finish()
