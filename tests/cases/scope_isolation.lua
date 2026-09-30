-- tab = 工作区隔离（scope.nvim + bridge）
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")
local A = lib.fixture("A.py", { "A" })
local B = lib.fixture("B.md", { "B" })
local C = lib.fixture("C.py", { "C" })
local D = lib.fixture("D.md", { "D" })

-- S1 tab 之间列表隔离与切回恢复
lib.reset()
vim.cmd.edit(A); vim.cmd.edit(B)
vim.cmd("tabnew"); vim.cmd.edit(C)
vim.wait(150)
lib.ok("S1 tab 隔离", lib.listed_tab(1) == "A.py,B.md" and lib.listed_tab(2) == "C.py",
  ("tab1=[%s] tab2=[%s]"):format(lib.listed_tab(1), lib.listed_tab(2)))

-- S2 同一文件在两个 tab 打开：两边都可见，且 tabnew 空 buffer 被清理
lib.reset()
vim.cmd.edit(A)
vim.cmd("tabnew"); vim.cmd.edit(A)
vim.wait(200)
lib.ok("S2 同文件双 tab 两边可见（无 [NoName] 残留）",
  lib.listed_tab(1) == "A.py" and lib.listed_tab(2) == "A.py",
  ("tab1=[%s] tab2=[%s]"):format(lib.listed_tab(1), lib.listed_tab(2)))

-- S6 :bnext / <Tab> 只在当前 tab 内循环
lib.reset()
vim.cmd.edit(A); vim.cmd.edit(D)
vim.cmd("tabnew"); vim.cmd.edit(C); vim.cmd.edit(B)
vim.wait(50)
local seen = {}
for _ = 1, 3 do
  seen[#seen + 1] = lib.base(vim.fn.bufname())
  vim.cmd("bnext")
end
lib.ok("S6 bnext 只在当前 tab 循环", table.concat(seen, "→") == "B.md→C.py→B.md",
  table.concat(seen, "→"))

-- S4 help / dashboard 不受隔离影响
lib.reset()
vim.cmd.edit(A)
vim.cmd("tabnew"); vim.cmd.edit(C)
pcall(vim.cmd, "help q")
vim.wait(150)
local help_ok = vim.bo.filetype == "help"
pcall(vim.cmd, "close")
vim.wait(100)
require("nvim-devkit.winbuf").open_dashboard()
vim.wait(200)
lib.ok("S4 help 与 dashboard 不受影响", help_ok and lib.is_dashboard(),
  ("help_ok=%s ft=%s"):format(tostring(help_ok), vim.bo.filetype))

lib.finish()
