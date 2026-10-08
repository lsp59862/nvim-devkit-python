-- VS Code 式词级删除：<C-BS>（插入/命令行）与 <C-H> 回退删前词，<C-Del> 删后词
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")

lib.reset()

local q_bs_i = vim.fn.maparg("<C-BS>", "i"):lower()
local q_bs_c = vim.fn.maparg("<C-BS>", "c"):lower()
local q_h_i = vim.fn.maparg("<C-H>", "i"):lower()
lib.ok("<C-BS> 映射（插入/命令行）", q_bs_i == "<c-w>" and q_bs_c == "<c-w>",
  ("i=%s c=%s"):format(q_bs_i, q_bs_c))
lib.ok("<C-H> 映射（^H 终端回退）", q_h_i == "<c-w>", q_h_i)
local cdel = vim.fn.maparg("<C-Del>", "i", false, true)
lib.ok("<C-Del> 映射存在", cdel.callback ~= nil, vim.inspect(cdel))

local function fresh(line, col)
  vim.cmd("enew!")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { line })
  vim.api.nvim_win_set_cursor(0, { 1, col })
end
local function text()
  return vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
end

fresh("foo bar baz", 0)
vim.api.nvim_feedkeys(lib.keys("A<C-BS><Esc>"), "x", false)
vim.wait(50)
lib.ok("<C-BS> 删前词（行尾）", text() == "foo bar ", ("[%s]"):format(text()))

fresh("foo bar baz", 0)
vim.api.nvim_feedkeys(lib.keys("A<C-H><Esc>"), "x", false)
vim.wait(50)
lib.ok("<C-H> 删前词（^H 终端）", text() == "foo bar ", ("[%s]"):format(text()))

fresh("foo bar baz", 3)
vim.api.nvim_feedkeys(lib.keys("i<C-Del><Esc>"), "x", false)
vim.wait(50)
lib.ok("<C-Del> 从词尾删后词（含空格）", text() == "foo baz", ("[%s]"):format(text()))

fresh("foo bar baz", 4)
vim.api.nvim_feedkeys(lib.keys("i<C-Del><Esc>"), "x", false)
vim.wait(50)
lib.ok("<C-Del> 词首只删本词", text() == "foo  baz", ("[%s]"):format(text()))

lib.finish()
