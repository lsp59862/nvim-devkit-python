-- S5 tabclose 后有序序列化不串台（bridge 的核心价值）
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")
local A = lib.fixture("A.py", { "A" })
local C = lib.fixture("C.py", { "C" })
local D = lib.fixture("D.md", { "D" })

lib.reset()
vim.cmd.edit(A)
vim.cmd("tabnew"); vim.cmd.edit(C)
vim.cmd("tabnew"); vim.cmd.edit(D)
vim.wait(100)
local before = vim.fn.tabpagenr("$")
pcall(vim.cmd, "tabclose 2") -- 制造"关过 tab"的场景
local sok, state = pcall(function()
  return vim.json.decode(require("nvim-devkit.scope_bridge").serialize())
end)
local groups_ok = sok
  and #state == 2
  and lib.base(state[1][1]) == "A.py"
  and lib.base(state[2][1]) == "D.md"
lib.ok("S5 tabclose 后序列化正确", before == 3 and vim.fn.tabpagenr("$") == 2 and groups_ok,
  ("tabs %d→%d state=%s"):format(before, vim.fn.tabpagenr("$"), sok and vim.inspect(state) or "decode失败"))
lib.finish()
