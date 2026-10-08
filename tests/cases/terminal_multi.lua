-- 终端多开：同类互斥（一次只显示一台浮动/底部）、编号分配复用、kill 真正结束
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")
local term = require("nvim-devkit.term")
local snacks_term = require("snacks.terminal")

local function count()
  return #snacks_term.list()
end
local function visible_floats()
  local n = 0
  for _, t in ipairs(snacks_term.list()) do
    if t:is_floating() then
      n = n + 1
    end
  end
  return n
end
local function visible_bottoms()
  local n = 0
  for _, t in ipairs(snacks_term.list()) do
    if t:valid() and not t:is_floating() and vim.b[t.buf].nvkit_term_kind == "bottom" then
      n = n + 1
    end
  end
  return n
end

lib.reset()
lib.ok("初始无终端", count() == 0, "count=" .. count())

term.open_float()
vim.wait(400)
lib.ok("开 1 台浮动终端且可见", count() == 1 and visible_floats() == 1,
  ("count=%d visible=%d"):format(count(), visible_floats()))
local t1 = snacks_term.list()[1]
lib.ok("是浮窗（relative≈editor）",
  t1 and t1.win and vim.api.nvim_win_get_config(t1.win).relative ~= "",
  t1 and t1.win and vim.api.nvim_win_get_config(t1.win).relative or "nil")
lib.ok("next_count = 2", term.next_count() == 2, "next=" .. term.next_count())

term.open_float(term.next_count())
vim.wait(400)
lib.ok("再开一台：列表 2 台但浮窗只显示 1 台", count() == 2 and visible_floats() == 1,
  ("count=%d visible=%d"):format(count(), visible_floats()))

term.open_float()
vim.wait(200)
lib.ok("tt 一次关掉可见浮窗", count() == 2 and visible_floats() == 0,
  ("count=%d visible=%d"):format(count(), visible_floats()))
term.open_float()
vim.wait(200)
lib.ok("再 tt 唤回最近浮窗", visible_floats() == 1, "visible=" .. visible_floats())

term.open_bottom()
vim.wait(400)
lib.ok("tb 开出底部终端（只 1 台可见）", count() == 3 and visible_bottoms() == 1,
  ("count=%d bottoms=%d"):format(count(), visible_bottoms()))
term.open_bottom()
vim.wait(200)
lib.ok("再 tb 关掉底部", visible_bottoms() == 0, "bottoms=" .. visible_bottoms())

term.kill(1)
term.kill(2)
term.kill(3)
vim.wait(300)
lib.ok("kill 后全部清理且编号 1 可复用", count() == 0 and term.next_count() == 1,
  ("count=%d next=%d"):format(count(), term.next_count()))

lib.finish()
