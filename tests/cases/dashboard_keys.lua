-- 启动页按键契约：r=恢复会话（persistence.load）、q=:q
-- 背景：q 曾是恢复会话；直接删掉会落到 snacks 默认 q→<cmd>bd</cmd>（绕过 winbuf 接管、销毁启动页）
-- 另含会话提示行：有快照才显示
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")

lib.reset()
require("snacks").dashboard.open({ win = 0 })
lib.ok("启动页已打开", lib.is_dashboard(), "filetype=" .. vim.bo.filetype)

local preset = require("snacks").config.dashboard.preset.keys or {}
local by_key = {}
for _, item in ipairs(preset) do
  by_key[item.key] = item
end
lib.ok("preset: r = 恢复会话", by_key.r ~= nil and by_key.r.action:find("persistence", 1, true) ~= nil,
  by_key.r and by_key.r.action or "missing")
lib.ok("preset: q = :q（不再恢复会话）", by_key.q ~= nil and by_key.q.action == ":q",
  by_key.q and by_key.q.action or "missing")

local r_map = vim.fn.maparg("r", "n", false, true)
local q_map = vim.fn.maparg("q", "n", false, true)
lib.ok("启动页内 r 映射存在", r_map.callback ~= nil, vim.inspect(r_map))
lib.ok("启动页内 q 映射存在", q_map.callback ~= nil, vim.inspect(q_map))

-- 会话提示行：无快照不显示，有快照显示
local p = require("persistence")
vim.fn.delete(p.current())
lib.reset()
require("snacks").dashboard.open({ win = 0 })
local no_session_text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
lib.ok("无快照：启动页无会话提示", no_session_text:find("本目录有会话存档", 1, true) == nil)

vim.fn.writefile({ "let SessionLoad = 1" }, p.current())
lib.reset()
require("snacks").dashboard.open({ win = 0 })
local has_session_text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
lib.ok("有快照：启动页显示会话提示", has_session_text:find("本目录有会话存档", 1, true) ~= nil,
  vim.inspect(vim.api.nvim_buf_get_lines(0, 0, -1, false)))
vim.fn.delete(p.current())

lib.finish()
