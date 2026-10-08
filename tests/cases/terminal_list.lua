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

local pcfg = require("snacks").config.picker
lib.ok("所有 picker：Alt+J/K 上下选择已配置", (function()
  local i, l = pcfg.win.input.keys, pcfg.win.list.keys
  return i["<M-j>"] ~= nil and i["<M-k>"] ~= nil and l["<M-j>"] ~= nil and l["<M-k>"] ~= nil
end)(), vim.inspect({ i = pcfg.win.input.keys["<M-j>"], l = pcfg.win.list.keys["<M-j>"] }))

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

-- 实测：从列表确认后 picker 必须收起（snacks 的自动关闭会跳过浮窗，曾导致残留）
term.summon("float") -- 收起浮动面板，模拟"从列表恢复"
vim.wait(300)
term.picker()
vim.wait(400)
local pickers = require("snacks.picker").get()
lib.ok("picker 已打开", #pickers == 1, "n=" .. #pickers)

local function confirm_of(p)
  local acts = p and p.opts.actions or {}
  return acts.confirm or (p and p.opts.confirm)
end
local function item_of(kind)
  for _, it in ipairs(term.items()) do
    if it.kind == kind then
      return it
    end
  end
end

local pk = pickers[1]
local confirm = confirm_of(pk)
lib.ok("confirm 回调可取用", type(confirm) == "function")
if confirm then
  confirm(pk, item_of("float"))
  vim.wait(600)
  lib.ok("确认浮窗项后 picker 收起", #require("snacks.picker").get() == 0,
    "n=" .. #require("snacks.picker").get())
  lib.ok("浮窗面板已显示且聚焦",
    term.visible("float") and vim.api.nvim_get_current_win() == term.main_win("float"))

  term.picker()
  vim.wait(400)
  local pk2 = require("snacks.picker").get()[1]
  local confirm2 = confirm_of(pk2)
  if pk2 and confirm2 then
    confirm2(pk2, item_of("bottom"))
    vim.wait(600)
    lib.ok("确认底部项后 picker 收起且聚焦",
      #require("snacks.picker").get() == 0 and vim.api.nvim_get_current_win() == term.main_win("bottom"))
  end
end

for _, t in ipairs(term.terms()) do
  term.kill(t.id)
end
for _, st in ipairs(snacks_term.list()) do
  if vim.api.nvim_buf_is_valid(st.buf) then
    vim.api.nvim_buf_delete(st.buf, { force = true })
  end
end
for _, p in ipairs(require("snacks.picker").get()) do
  pcall(function()
    p:close()
  end)
end
vim.wait(400)

lib.finish()
