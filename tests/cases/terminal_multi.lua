-- 终端多开：浮动位置、编号分配、kill 真正结束、编号复用
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")
local term = require("nvim-devkit.term")
local snacks_term = require("snacks.terminal")

lib.reset()
lib.ok("初始无终端", #snacks_term.list() == 0, "count=" .. #snacks_term.list())

term.open_float()
vim.wait(400)
lib.ok("开 1 台浮动终端", #snacks_term.list() == 1, "count=" .. #snacks_term.list())
local t1 = snacks_term.list()[1]
lib.ok("是浮窗（relative≈editor）",
  t1 and t1.win and vim.api.nvim_win_get_config(t1.win).relative ~= "",
  t1 and t1.win and vim.api.nvim_win_get_config(t1.win).relative or "nil")
lib.ok("next_count = 2", term.next_count() == 2, "next=" .. term.next_count())

term.open_float(term.next_count())
vim.wait(400)
lib.ok("开 2 台且编号 1,2", #snacks_term.list() == 2 and term.entries()[2].id == 2,
  vim.inspect(term.entries()))

term.kill(1)
vim.wait(200)
lib.ok("kill 1 后剩 1 台", #snacks_term.list() == 1, "count=" .. #snacks_term.list())
lib.ok("编号 1 可复用", term.next_count() == 1, "next=" .. term.next_count())
term.kill(2)
vim.wait(200)
lib.ok("全部清理", #snacks_term.list() == 0, "count=" .. #snacks_term.list())

lib.finish()
