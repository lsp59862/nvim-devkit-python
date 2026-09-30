-- 会话保存：各 tab 文件归属按 tab 顺序写入 vim.g.NvkitScopeState 并随 mksession 落盘
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")
local A = lib.fixture("A.py", { "A" })
local B = lib.fixture("B.md", { "B" })
local C = lib.fixture("C.py", { "C" })
local D = lib.fixture("D.md", { "D" })

lib.reset()
vim.cmd.edit(A); vim.cmd.edit(B)
vim.cmd("tabnew"); vim.cmd.edit(C)
vim.cmd("tabnew"); vim.cmd.edit(D)
vim.wait(100)
vim.cmd("tabclose 2") -- 关过 tab 再新增，验证有序

vim.api.nvim_exec_autocmds("User", { pattern = "PersistenceSavePre" })
local ok, state = pcall(function()
  return vim.json.decode(vim.g.NvkitScopeState or "")
end)
local groups_ok = ok
  and #state == 2
  and lib.base(state[1][1]) == "A.py"
  and lib.base(state[1][2]) == "B.md"
  and lib.base(state[2][1]) == "D.md"
lib.ok("保存：按 tab 顺序序列化", groups_ok,
  ok and vim.inspect(state) or "NvkitScopeState 缺失或无法解析")

local session = lib.dir() .. "/session.vim"
vim.cmd("mks! " .. vim.fn.fnameescape(session))
local content = table.concat(vim.fn.readfile(session), "\n")
lib.ok("保存：会话文件包含状态", vim.fn.filereadable(session) == 1 and content:find("NvkitScopeState", 1, true) ~= nil,
  ("session=%s"):format(session))
lib.finish()
