-- 终端列表：条目排序/字段、picker 参数、键位统一 <leader>t*（旧 Ctrl 开法已移除）
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")
local term = require("nvim-devkit.term")
local snacks_term = require("snacks.terminal")

lib.ok("<leader>tt/tn/tb/tl 映射存在",
  vim.fn.maparg(" tt", "n", false, true).callback ~= nil
    and vim.fn.maparg(" tn", "n", false, true).callback ~= nil
    and vim.fn.maparg(" tb", "n", false, true).callback ~= nil
    and vim.fn.maparg(" tl", "n", false, true).callback ~= nil)
lib.ok("旧的 <C-/> 开法已移除",
  vim.fn.maparg("<C-/>", "n") == "" and vim.fn.maparg("<C-/>", "t") == "",
  ("n=[%s] t=[%s]"):format(vim.fn.maparg("<C-/>", "n"), vim.fn.maparg("<C-/>", "t")))

lib.reset()
term.open_float(1)
vim.wait(300)
snacks_term.toggle("sleep 30", { count = 2, win = { position = "float", width = 0.6, height = 0.4 } })
vim.wait(300)

local items = term.items()
lib.ok("2 个终端按编号排序", #items == 2 and items[1].id == 1 and items[2].id == 2, vim.inspect(items))
lib.ok("条目含编号与命令", items[2].text:find("sleep", 1, true) ~= nil, items[2].text)

local sp = require("snacks.picker")
local orig = sp.pick
local captured
sp.pick = function(opts)
  captured = opts
end
local ok, err = pcall(term.picker)
sp.pick = orig
local keys = captured and captured.win and captured.win.list and captured.win.list.keys or {}
lib.ok("picker 参数完整（items/confirm/kill/new）",
  ok and captured ~= nil
    and type(captured.items) == "table"
    and type(captured.confirm) == "function"
    and type((captured.actions or {}).term_kill) == "function"
    and type((captured.actions or {}).term_new) == "function"
    and keys["<C-d>"] == "term_kill"
    and keys["<C-n>"] == "term_new",
  ("ok=%s err=%s"):format(tostring(ok), tostring(err)))

term.kill(1)
term.kill(2)
lib.finish()
