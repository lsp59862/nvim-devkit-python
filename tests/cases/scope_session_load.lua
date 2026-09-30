-- 会话恢复：source 会话 + PersistenceLoadPost 后，各 tab 文件归属精确还原
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")
-- 确保 fixture 文件存在（内容与保存时一致不影响归属判断）
lib.fixture("A.py", { "A" })
lib.fixture("B.md", { "B" })
lib.fixture("D.md", { "D" })

local session = lib.dir() .. "/session.vim"
lib.ok("前置：会话文件存在", vim.fn.filereadable(session) == 1, session)

vim.cmd("source " .. vim.fn.fnameescape(session))
local has_state = vim.g.NvkitScopeState ~= nil
vim.api.nvim_exec_autocmds("User", { pattern = "PersistenceLoadPost" })
vim.wait(300)

lib.ok("恢复：会话内状态已随 globals 还原", has_state)
lib.ok("恢复：tab1=[A.py,B.md] tab2=[D.md]",
  lib.listed_tab(1) == "A.py,B.md" and lib.listed_tab(2) == "D.md",
  ("tab1=[%s] tab2=[%s]"):format(lib.listed_tab(1), lib.listed_tab(2)))
lib.finish()
