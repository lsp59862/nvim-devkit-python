-- 终端列表：键位新契约（tp/tb/tl，旧 tt/tn 移除）、[浮]/[底]/[面板] 区分、picker 参数
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")
local term = require("nvim-devkit.term")
local snacks_term = require("snacks.terminal")
term.setup()

lib.ok("<leader>tp/tb/tl 映射存在",
  vim.fn.maparg(" tp", "n", false, true).callback ~= nil
    and vim.fn.maparg(" tb", "n", false, true).callback ~= nil
    and vim.fn.maparg(" tl", "n", false, true).callback ~= nil)
lib.ok("旧的 <leader>tt/tn 已移除",
  vim.fn.maparg(" tt", "n") == "" and vim.fn.maparg(" tn", "n") == "",
  ("tt=[%s] tn=[%s]"):format(vim.fn.maparg(" tt", "n"), vim.fn.maparg(" tn", "n")))

lib.reset()
term.summon("float")
vim.wait(300)
term.summon("bottom")
vim.wait(300)
snacks_term.toggle("sleep 30", { count = 9, win = { position = "right", width = 0.3 } })
vim.wait(300)

local items = term.items()
local texts = {}
for _, it in ipairs(items) do
  texts[#texts + 1] = it.text
end
lib.ok("条目区分 [浮]/[底]/[面板]",
  table.concat(texts, "|"):find("[浮] bash", 1, true) ~= nil
    and table.concat(texts, "|"):find("[底] bash", 1, true) ~= nil
    and table.concat(texts, "|"):find("[面板] sleep", 1, true) ~= nil,
  vim.inspect(texts))
lib.ok("名字是简名不是绝对路径", table.concat(texts, "|"):find("/bin/", 1, true) == nil,
  vim.inspect(texts))

local sp = require("snacks.picker")
local orig = sp.pick
local captured
sp.pick = function(opts)
  captured = opts
end
local ok, err = pcall(term.picker)
sp.pick = orig
local keys = captured and captured.win and captured.win.list and captured.win.list.keys or {}
lib.ok("picker 参数完整（items/format/confirm/kill）",
  ok and captured ~= nil
    and type(captured.items) == "table"
    and captured.format == "text"
    and type(captured.confirm) == "function"
    and type((captured.actions or {}).term_kill) == "function"
    and keys["<C-d>"] == "term_kill",
  ("ok=%s err=%s"):format(tostring(ok), tostring(err)))

for _, t in ipairs(term.terms()) do
  term.kill(t.id)
end
for _, st in ipairs(snacks_term.list()) do
  if vim.api.nvim_buf_is_valid(st.buf) then
    vim.api.nvim_buf_delete(st.buf, { force = true })
  end
end
vim.wait(400)

lib.finish()
