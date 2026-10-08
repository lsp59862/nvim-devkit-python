-- 会话自动保存开关闭环：qd 停止后退出不写会话文件，qe 重新开启后恢复写入
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")
local A = lib.fixture("A.py", { "A" })

lib.reset()
vim.cmd.edit(A)

local p = require("persistence")
lib.ok("前置：自动保存处于开启状态", p.active(), "active=" .. tostring(p.active()))

local session = p.current()
vim.fn.delete(session)

local qd = vim.fn.maparg(" qd", "n", false, true).callback
local qe = vim.fn.maparg(" qe", "n", false, true).callback
lib.ok("qd/qe 映射存在", qd ~= nil and qe ~= nil,
  ("qd=%s qe=%s"):format(tostring(qd ~= nil), tostring(qe ~= nil)))

if qd then
  pcall(qd)
  lib.ok("qd 后自动保存停止", p.active() == false, "active=" .. tostring(p.active()))
  pcall(vim.api.nvim_exec_autocmds, "VimLeavePre", {})
  lib.ok("qd 后退出不写会话文件", vim.fn.filereadable(session) == 0,
    ("session=%s readable=%s"):format(session, tostring(vim.fn.filereadable(session))))
end

if qe then
  pcall(qe)
  lib.ok("qe 后自动保存重新开启", p.active() == true, "active=" .. tostring(p.active()))
  pcall(vim.api.nvim_exec_autocmds, "VimLeavePre", {})
  local readable = vim.fn.filereadable(session) == 1
  local content_ok = readable and table.concat(vim.fn.readfile(session), "\n"):find("A%.py") ~= nil
  lib.ok("qe 后退出恢复写入且含当前文件", content_ok,
    ("session=%s readable=%s"):format(session, tostring(readable)))
end

lib.finish()
