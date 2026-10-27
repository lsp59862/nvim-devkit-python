-- 启动页：自绘双栏卡片（边框/按键徽标/最近文件/会话提示）+ 按键契约 + 窗口缩放重排
-- 背景：q 曾是恢复会话；直接删掉会落到 snacks 默认 q→<cmd>bd</cmd>（绕过 winbuf 接管、销毁启动页）
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")

lib.reset()
local dir = lib.dir()
vim.cmd("cd " .. vim.fn.fnameescape(dir))
vim.fn.writefile({ "x" }, dir .. "/dash_a.lua")
vim.fn.writefile({ "x" }, dir .. "/dash_b.png")
vim.v.oldfiles = { dir .. "/dash_a.lua", dir .. "/dash_b.png", "/etc/hosts" }
require("snacks").dashboard.open({ win = 0 })
lib.ok("启动页已打开", lib.is_dashboard(), "filetype=" .. vim.bo.filetype)

local text = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")

-- 按键内容不变
local preset = require("snacks").config.dashboard.preset.keys or {}
local by_key = {}
for _, item in ipairs(preset) do
  by_key[item.key] = item
end
lib.ok("preset: r = 恢复会话", by_key.r ~= nil and by_key.r.action:find("persistence", 1, true) ~= nil,
  by_key.r and by_key.r.action or "missing")
lib.ok("preset: q = :q（不再恢复会话）", by_key.q ~= nil and by_key.q.action == ":q",
  by_key.q and by_key.q.action or "missing")

local missing = {}
for _, k in ipairs({ "e", "f", "g", "u", "r", "q", "?", "c", "l" }) do
  if not text:find("[" .. k .. "]", 1, true) then
    missing[#missing + 1] = k
  end
end
lib.ok("9 个快捷键徽标齐全（内容不变）", #missing == 0, vim.inspect(missing))

local top_line
for _, l in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
  if l:find("╭", 1, true) then
    top_line = l
    break
  end
end
lib.ok("双栏卡片边框（圆角 + 中缝）",
  text:find("╭", 1, true) ~= nil and text:find("┬", 1, true) ~= nil
    and text:find("┼", 1, true) ~= nil and text:find("╰", 1, true) ~= nil,
  top_line or "(无边框)")
lib.ok("主页无 nvim-devkit / 科研版 字样",
  not text:find("nvim-devkit", 1, true) and not text:find("科研版", 1, true), top_line or "")
lib.ok("底部提示使用「状态重置」且无「恐慌」",
  text:find("状态重置", 1, true) ~= nil and text:find("恐慌", 1, true) == nil, top_line or "")

-- 最近文件：只列 cwd 内、带编号
lib.ok("最近文件只显示 cwd 内文件",
  text:find("./dash_a.lua", 1, true) ~= nil and text:find("./dash_b.png", 1, true) ~= nil
    and text:find("/etc/hosts", 1, true) == nil, top_line or "")
lib.ok("最近文件数字键映射存在", vim.fn.maparg("1", "n", false, true).callback ~= nil,
  vim.inspect(vim.fn.maparg("1", "n", false, true)))

-- 启动页内 r/q 映射存在
lib.ok("启动页内 r 映射存在", vim.fn.maparg("r", "n", false, true).callback ~= nil)
lib.ok("启动页内 q 映射存在", vim.fn.maparg("q", "n", false, true).callback ~= nil)

-- 会话提示：无快照不显示，有快照显示（含简单解释）
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
lib.ok("有快照：显示会话提示（恢复 r）",
  has_session_text:find("本目录有会话存档（恢复 r）", 1, true) ~= nil,
  vim.inspect(vim.api.nvim_buf_get_lines(0, 0, -1, false)))
vim.fn.delete(p.current())

-- 窗口缩放：布局应重排（宽度变化、边框仍完整）
local function top_width()
  for _, l in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
    if l:find("╭", 1, true) then
      return vim.api.nvim_strwidth(l)
    end
  end
end
lib.reset()
require("snacks").dashboard.open({ win = 0 })
vim.wait(300)
local w_before = top_width()
vim.cmd("vsplit")
vim.wait(300)
vim.api.nvim_exec_autocmds("WinResized", {}) -- headless 不自动触发窗口事件，这里显式触发
vim.wait(800)
local w_after = top_width()
lib.ok("窗口缩放后布局重排（宽度变化且仍有边框）",
  w_before ~= nil and w_after ~= nil and w_after ~= w_before,
  ("before=%s after=%s"):format(tostring(w_before), tostring(w_after)))
vim.cmd("silent! only")
lib.reset()

lib.finish()
