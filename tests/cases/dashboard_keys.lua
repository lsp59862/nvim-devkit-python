-- 启动页：自绘双栏卡片（边框 / 按键徽标 / 最近文件 5~7 条 + 溢出行 / 会话 * 标记）+ 缩放重排
-- 背景：q 曾是恢复会话；直接删掉会落到 snacks 默认 q→<cmd>bd</cmd>（绕过 winbuf 接管、销毁启动页）
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")

lib.reset()
local dir = lib.dir()
vim.cmd("cd " .. vim.fn.fnameescape(dir))
local files = {}
for i = 1, 10 do
  local f = ("%s/rec_%02d.lua"):format(dir, i)
  vim.fn.writefile({ "x" }, f)
  files[#files + 1] = f
end
vim.v.oldfiles = files
require("snacks").dashboard.open({ win = 0 })
lib.ok("启动页已打开", lib.is_dashboard(), "filetype=" .. vim.bo.filetype)

local function lines()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end
local function text()
  return table.concat(lines(), "\n")
end

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
  if not text():find("[" .. k .. "]", 1, true) then
    missing[#missing + 1] = k
  end
end
lib.ok("9 个快捷键徽标齐全（内容不变）", #missing == 0, vim.inspect(missing))

-- 边框 + 第一行就是"最近文件"
local ls = lines()
local top_idx
for i, l in ipairs(ls) do
  if l:find("╭", 1, true) then
    top_idx = i
    break
  end
end
lib.ok("双栏卡片边框（圆角 + 中缝）",
  text():find("╭", 1, true) ~= nil and text():find("┬", 1, true) ~= nil
    and text():find("┼", 1, true) ~= nil and text():find("╰", 1, true) ~= nil,
  ls[top_idx] or "(无边框)")
lib.ok("左栏第一行是「最近文件」",
  top_idx ~= nil and ls[top_idx + 1] ~= nil and ls[top_idx + 1]:find("最近文件", 1, true) ~= nil,
  ls[top_idx + 1] or "(缺失)")
lib.ok("主页无 nvim-devkit / 科研版 字样",
  not text():find("nvim-devkit", 1, true) and not text():find("科研版", 1, true), "")
lib.ok("底部提示使用「状态重置」且无「恐慌」",
  text():find("状态重置", 1, true) ~= nil and text():find("恐慌", 1, true) == nil, "")

-- 最近文件：只列 cwd 内；超过 8 条 → 7 条 + 溢出行（左栏占满）
lib.ok("最近文件只显示 cwd 内文件",
  text():find("./rec_01.lua", 1, true) ~= nil and text():find("/etc/hosts", 1, true) == nil, "")
lib.ok("溢出时显示「（还有 3 个, 按 o 展开）」",
  text():find("（还有 3 个, 按 o 展开）", 1, true) ~= nil, text())
local num_ok = 0
for i = 1, 7 do
  if vim.fn.maparg(tostring(i), "n", false, true).callback ~= nil then
    num_ok = num_ok + 1
  end
end
lib.ok("最近文件 1~7 数字键可用（第 8 条收起）",
  num_ok == 7 and vim.fn.maparg("8", "n", false, true).callback == nil
    and vim.fn.maparg("o", "n", false, true).callback ~= nil,
  ("nums=%d key8=%s key_o=%s"):format(num_ok,
    tostring(vim.fn.maparg("8", "n", false, true).callback ~= nil),
    tostring(vim.fn.maparg("o", "n", false, true).callback ~= nil)))

lib.ok("启动页内 r 映射存在", vim.fn.maparg("r", "n", false, true).callback ~= nil)
lib.ok("启动页内 q 映射存在", vim.fn.maparg("q", "n", false, true).callback ~= nil)

-- 会话标记：有快照 → "恢复会话 *"；无快照 → 无 *（不再单独占一行）
local p = require("persistence")
vim.fn.delete(p.current())
lib.reset()
require("snacks").dashboard.open({ win = 0 })
local no_sess = text()
lib.ok("无快照：不显示独立会话提示行", no_sess:find("本目录有会话存档", 1, true) == nil)
local no_mark = true
for _, l in ipairs(lines()) do
  if l:find("恢复会话", 1, true) and l:find("*", 1, true) then
    no_mark = false
  end
end
lib.ok("无快照：恢复会话行无 * 标记", no_mark, "")

vim.fn.writefile({ "let SessionLoad = 1" }, p.current())
lib.reset()
require("snacks").dashboard.open({ win = 0 })
local has_mark = false
for _, l in ipairs(lines()) do
  if l:find("恢复会话 *", 1, true) then
    has_mark = true
  end
end
lib.ok("有快照：恢复会话行显示绿色 * 标记", has_mark, vim.inspect(lines()))
vim.fn.delete(p.current())

-- 最近文件不多时：全部列出、无溢出行
vim.v.oldfiles = { dir .. "/rec_01.lua", dir .. "/rec_02.lua", dir .. "/rec_03.lua" }
lib.reset()
require("snacks").dashboard.open({ win = 0 })
lib.ok("少量最近文件：全部列出且无溢出行",
  text():find("（还有", 1, true) == nil
    and vim.fn.maparg("4", "n", false, true).callback == nil, "")

-- 窗口缩放：布局应重排（宽度变化、边框仍完整）
local function top_row()
  for i, l in ipairs(lines()) do
    if l:find("╭", 1, true) then
      return i
    end
  end
end

local function top_width()
  for _, l in ipairs(lines()) do
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

-- 高度变化（:sp / 底部终端）也要重新纵向居中
lib.reset()
require("snacks").dashboard.open({ win = 0 })
vim.wait(300)
local r_before = top_row()
local w_before_h = top_width()
vim.cmd("split") -- 横向分割：当前窗口高度减半
vim.wait(300)
vim.api.nvim_exec_autocmds("WinResized", {})
vim.wait(800)
local r_after = top_row()
local w_after_h = top_width()
lib.ok("窗口高度变化后纵向重新居中（:sp）",
  r_before ~= nil and r_after ~= nil and r_after < r_before,
  ("row_before=%s row_after=%s"):format(tostring(r_before), tostring(r_after)))
lib.ok("高度变化不影响卡片宽度（仍完整）",
  w_before_h ~= nil and w_after_h ~= nil and w_after_h == w_before_h,
  ("w_before=%s w_after=%s"):format(tostring(w_before_h), tostring(w_after_h)))
vim.cmd("silent! only")
lib.reset()

-- 重排后视图回到顶部（居中依赖顶部空白行；snacks 不重置视图）
lib.reset()
require("snacks").dashboard.open({ win = 0 })
vim.wait(400)
local dwin = vim.api.nvim_get_current_win()
vim.api.nvim_win_call(dwin, function()
  vim.fn.winrestview({ topline = 5 })
end)
vim.cmd("vsplit") -- 任意尺寸变化，触发重排
vim.wait(300)
vim.api.nvim_exec_autocmds("WinResized", {})
vim.wait(800)
local cur_win = vim.api.nvim_get_current_win()
local topline = vim.api.nvim_win_call(cur_win, function()
  return vim.fn.winsaveview().topline
end)
lib.ok("重排后视图回到顶部（卡片保持居中）", topline == 1, "topline=" .. tostring(topline))
vim.cmd("silent! only")
lib.reset()

lib.finish()
