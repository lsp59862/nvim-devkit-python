-- 终端多开：浮动/底部各自成台（tt/tb 不抢同一个槽位）、编号分配复用、kill 真正结束
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")
local term = require("nvim-devkit.term")
local snacks_term = require("snacks.terminal")

local function count()
  return #snacks_term.list()
end
local function pos_of(id)
  for _, t in ipairs(snacks_term.list()) do
    local info = vim.b[t.buf].snacks_terminal or {}
    if (info.id or 1) == id and t.win then
      return vim.api.nvim_win_get_config(t.win).relative or ""
    end
  end
end

lib.reset()
lib.ok("初始无终端", count() == 0, "count=" .. count())

term.open_float()
vim.wait(400)
lib.ok("开 1 台浮动终端", count() == 1, "count=" .. count())
local t1 = snacks_term.list()[1]
lib.ok("是浮窗（relative≈editor）",
  t1 and t1.win and vim.api.nvim_win_get_config(t1.win).relative ~= "",
  t1 and t1.win and vim.api.nvim_win_get_config(t1.win).relative or "nil")
lib.ok("next_count = 2", term.next_count() == 2, "next=" .. term.next_count())

term.open_bottom()
vim.wait(400)
lib.ok("tb 另开一台底部终端", count() == 2, "count=" .. count())
lib.ok("编号 2 是 split（relative=''）", pos_of(2) == "", "pos=" .. tostring(pos_of(2)))
term.open_float()
vim.wait(200)
lib.ok("tt 只切换浮动槽位不新开", count() == 2, "count=" .. count())

term.kill(1)
vim.wait(200)
lib.ok("kill 1 后剩 1 台", count() == 1, "count=" .. count())
lib.ok("编号 1 可复用", term.next_count() == 1, "next=" .. term.next_count())
term.kill(2)
vim.wait(200)
lib.ok("全部清理", count() == 0, "count=" .. count())

lib.finish()
