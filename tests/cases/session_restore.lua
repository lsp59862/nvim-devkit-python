-- 会话自动恢复（opt-in）门闸：默认关；headless 永不恢复；四条件齐备才恢复
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")

lib.reset()
local session = require("nvim-devkit.session")
local p = require("persistence")

vim.fn.delete(p.current())
lib.ok("无快照：session_file 返回 nil", session.session_file() == nil, tostring(session.session_file()))

vim.fn.writefile({ "let SessionLoad = 1" }, p.current())
lib.ok("有快照：session_file 返回路径", session.session_file() == p.current(), tostring(session.session_file()))

lib.ok("默认（未开开关、headless）：不恢复", session.should_restore() == false)

local prev = vim.env.NVIM_DEVKIT_AUTORESTORE
vim.env.NVIM_DEVKIT_AUTORESTORE = "1"
lib.ok("开关开但 headless：仍不恢复", session.should_restore() == false)
lib.ok("开关开 + 有 UI + 无参数 + 有快照：恢复", session.should_restore({ has_ui = true }) == true)
lib.ok("有参数时不恢复", session.should_restore({ has_ui = true, argc = 1 }) == false)
lib.ok("无快照时不恢复", session.should_restore({ has_ui = true, has_session = false }) == false)

local before = #vim.api.nvim_list_bufs()
local did = session.maybe_restore()
lib.ok("maybe_restore 在 headless 下不动作", did == false and #vim.api.nvim_list_bufs() == before,
  ("did=%s bufs=%d→%d"):format(tostring(did), before, #vim.api.nvim_list_bufs()))

vim.env.NVIM_DEVKIT_AUTORESTORE = prev or ""
vim.fn.delete(p.current())
lib.finish()
