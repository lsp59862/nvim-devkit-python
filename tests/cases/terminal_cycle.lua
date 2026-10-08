-- 终端循环切换：<M-j> 上一个 / <M-k> 下一个（共享列表，含任意类型终端）
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")
local term = require("nvim-devkit.term")
local snacks_term = require("snacks.terminal")

lib.ok("<M-j>/<M-k> 终端模式映射存在",
  vim.fn.maparg("<M-j>", "t", false, true).callback ~= nil
    and vim.fn.maparg("<M-k>", "t", false, true).callback ~= nil)

local function cur_id()
  local cur = vim.api.nvim_get_current_buf()
  for _, e in ipairs(term.entries()) do
    if e.buf == cur then
      return e.id
    end
  end
end

lib.reset()
term.cycle(1) -- 没有终端时自动开一台
vim.wait(400)
lib.ok("无终端时 cycle 自动开一台", #snacks_term.list() == 1, "count=" .. #snacks_term.list())

snacks_term.toggle("sleep 30", { count = 2, win = { position = "float", width = 0.6, height = 0.4 } })
vim.wait(300)
snacks_term.toggle("sleep 30", { count = 3, win = { position = "float", width = 0.6, height = 0.4 } })
vim.wait(300)

term.show(1)
lib.ok("show(1) 后当前是 #1", cur_id() == 1, "cur=" .. tostring(cur_id()))

term.cycle(1)
lib.ok("cycle 下一个 → #2", cur_id() == 2, "cur=" .. tostring(cur_id()))
term.cycle(1)
lib.ok("cycle 下一个 → #3", cur_id() == 3, "cur=" .. tostring(cur_id()))
term.cycle(1)
lib.ok("cycle 回绕 → #1", cur_id() == 1, "cur=" .. tostring(cur_id()))
term.cycle(-1)
lib.ok("cycle 上一个 → #3", cur_id() == 3, "cur=" .. tostring(cur_id()))

term.kill(1)
term.kill(2)
term.kill(3)
lib.finish()
