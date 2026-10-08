-- 补全键位契约（blink.cmp preset 只认 C-y，导致"回车/Tab 没反应"的历史 bug）：
-- Enter=接受 / Tab=下一项 / S-Tab=上一项 / Esc=取消预览，且不破坏 normal 的 Tab
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")
local A = lib.fixture("A.py", { "x = 1" })

lib.reset()
vim.cmd.edit(A)

-- blink 的 setup 在 fuzzy 下载回调里异步执行，等它注册好 InsertEnter 再手动触发一次
require("lazy").load({ plugins = { "blink.cmp" } })
vim.wait(1500, function()
  for _, a in ipairs(vim.api.nvim_get_autocmds({ event = "InsertEnter" })) do
    if a.group_name ~= "lazy_handler_event" then
      return true
    end
  end
  return false
end)
vim.api.nvim_exec_autocmds("InsertEnter", { buffer = 0 })
vim.wait(200)

local expect = {
  ["<CR>"] = "Accept",
  ["<Tab>"] = "Select Next",
  ["<S-Tab>"] = "Select Prev",
  ["<Esc>"] = "Cancel",
  ["<C-y>"] = "Select And Accept",
}
for key, word in pairs(expect) do
  local m = vim.fn.maparg(key, "i", false, true)
  local desc = type(m) == "table" and m.desc or nil
  lib.ok(("insert %s → %s"):format(key, word),
    desc ~= nil and desc:find("blink.cmp:", 1, true) ~= nil and desc:find(word, 1, true) ~= nil,
    tostring(desc))
end

local n = vim.fn.maparg("\t", "n", false, true)
local rhs = type(n) == "table" and tostring(n.rhs or "") or ""
lib.ok("normal Tab 仍是 bnext", rhs:lower():find("bnext") ~= nil, rhs)

lib.finish()
