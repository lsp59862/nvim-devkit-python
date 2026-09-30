-- S3 tab 内 :q：只影响本 tab（tab 内无文件 → dashboard），其它 tab 不受影响
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")
local wb = require("nvim-devkit.winbuf")
local A = lib.fixture("A.py", { "A" })
local B = lib.fixture("B.md", { "B" })
local C = lib.fixture("C.py", { "C" })

lib.reset()
vim.cmd.edit(A); vim.cmd.edit(B)
vim.cmd("tabnew"); vim.cmd.edit(C)
vim.wait(150)
wb.close_file({})
lib.ok("S3 tab 内 :q → dashboard 且 tabs 不变",
  lib.is_dashboard() and vim.fn.tabpagenr("$") == 2 and lib.listed() == "",
  ("ft=%s tabs=%d tab2列表=[%s]"):format(vim.bo.filetype, vim.fn.tabpagenr("$"), lib.listed()))
lib.ok("S3 回 tab1 列表完整", lib.listed_tab(1) == "A.py,B.md", ("tab1=[%s]"):format(lib.listed_tab(1)))
lib.finish()
