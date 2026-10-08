-- 终端面板：tp/tb 呼出与创建、侧边栏名字与高亮、Alt+N 同类新建、kill 自动切换/收起
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")
local term = require("nvim-devkit.term")
term.setup()

local function side_lines(kind)
  local buf = term.side_buf(kind)
  return buf and vim.api.nvim_buf_get_lines(buf, 0, -1, false) or {}
end

lib.reset()
lib.ok("初始无终端且面板收起",
  term.count() == 0 and not term.visible("float") and not term.visible("bottom"),
  ("n=%d f=%s b=%s"):format(term.count(), tostring(term.visible("float")), tostring(term.visible("bottom"))))

term.summon("float")
vim.wait(400)
lib.ok("tp 创建并显示浮动面板", term.count("float") == 1 and term.visible("float"),
  ("n=%d vis=%s"):format(term.count("float"), tostring(term.visible("float"))))
lib.ok("浮动主窗是浮窗（relative≈editor）", (function()
  local w = term.main_win("float")
  return w ~= nil and vim.api.nvim_win_get_config(w).relative ~= ""
end)())
lib.ok("侧边栏：shell 简名 + 当前高亮", (function()
  local lines = side_lines("float")
  return #lines == 1 and lines[1]:find("bash", 1, true) ~= nil and lines[1]:find("▸", 1, true) ~= nil
end)(), vim.inspect(side_lines("float")))

term.summon("float")
vim.wait(400)
lib.ok("再按 tp 收起且不新建", term.count("float") == 1 and not term.visible("float"),
  ("n=%d vis=%s"):format(term.count("float"), tostring(term.visible("float"))))

term.summon("bottom")
vim.wait(300)
lib.ok("tb 创建底部面板", term.count("bottom") == 1 and term.visible("bottom"),
  ("n=%d vis=%s"):format(term.count("bottom"), tostring(term.visible("bottom"))))
lib.ok("底部主窗是 split（relative=''）", (function()
  local w = term.main_win("bottom")
  return w ~= nil and vim.api.nvim_win_get_config(w).relative == ""
end)())

term.new_like_current()
vim.wait(300)
local b = term.terms("bottom")
lib.ok("Alt+N 在底部新建同类", term.count("bottom") == 2 and term.cur("bottom") == b[2].id,
  ("n=%d cur=%s want=%s"):format(term.count("bottom"), tostring(term.cur("bottom")), tostring(b[2].id)))
lib.ok("重名自动编号且当前在第二行", (function()
  local lines = side_lines("bottom")
  return #lines == 2 and lines[1]:find("bash 1", 1, true) ~= nil and lines[2]:find("▸", 1, true) ~= nil
end)(), vim.inspect(side_lines("bottom")))

term.kill(b[1].id)
vim.wait(300)
lib.ok("kill 后面板切到剩下那台", term.count("bottom") == 1 and term.cur("bottom") == b[2].id,
  ("n=%d cur=%s"):format(term.count("bottom"), tostring(term.cur("bottom"))))
lib.ok("删除不重排编号（bash 2 不变成 bash 1）", (function()
  local lines = side_lines("bottom")
  return #lines == 1 and lines[1]:find("bash 2", 1, true) ~= nil
end)(), vim.inspect(side_lines("bottom")))

-- <M-r> 重命名：侧边栏与列表同步
local orig_input = vim.ui.input
vim.ui.input = function(_, cb)
  cb("训练")
end
term.rename_current()
vim.wait(100)
vim.ui.input = orig_input
lib.ok("Alt+R 重命名生效", (function()
  local lines = side_lines("bottom")
  return term.name_of(b[2].id) == "训练" and lines[1]:find("训练", 1, true) ~= nil
end)(), vim.inspect(side_lines("bottom")))

term.kill(b[2].id)
vim.wait(300)
lib.ok("最后 kill 后面板收起", term.count("bottom") == 0 and not term.visible("bottom"),
  ("n=%d vis=%s"):format(term.count("bottom"), tostring(term.visible("bottom"))))

local f = term.terms("float")[1]
term.kill(f.id)
vim.wait(400)
lib.ok("全部清理", term.count() == 0, "n=" .. term.count())

lib.finish()
