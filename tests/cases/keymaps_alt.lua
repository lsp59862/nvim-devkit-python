-- Alt+1 / Alt+0：行首 / 行末（普通、可视、插入模式都生效且不切换模式）
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")

-- 映射存在
local exists = vim.fn.maparg("<M-1>", "n") ~= ""
  and vim.fn.maparg("<M-0>", "n") ~= ""
  and vim.fn.maparg("<M-1>", "i") ~= ""
  and vim.fn.maparg("<M-0>", "i") ~= ""
lib.ok("映射存在（普通+插入）", exists,
  ("n1=%s n0=%s i1=%s i0=%s"):format(
    tostring(vim.fn.maparg("<M-1>", "n") ~= ""),
    tostring(vim.fn.maparg("<M-0>", "n") ~= ""),
    tostring(vim.fn.maparg("<M-1>", "i") ~= ""),
    tostring(vim.fn.maparg("<M-0>", "i") ~= "")
  ))
-- 插入模式的 rhs 语义（保持插入：<C-o>；maparg 会返回大写 <C-O>）
lib.ok("插入模式 rhs 保持插入",
  vim.fn.maparg("<M-1>", "i"):lower() == "<c-o>^" and vim.fn.maparg("<M-0>", "i"):lower() == "<c-o>$",
  ("i1=%s i0=%s"):format(vim.fn.maparg("<M-1>", "i"), vim.fn.maparg("<M-0>", "i")))

local LINE = "    hello world   " -- 18 字符：4 空格 + 11 字符 + 3 空格
local function fresh(cursor_col)
  vim.cmd("enew!")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { LINE })
  vim.api.nvim_win_set_cursor(0, { 1, cursor_col })
end
local function text()
  return vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
end
local function col()
  return vim.api.nvim_win_get_cursor(0)[2]
end

-- 普通模式
fresh(14)
vim.api.nvim_feedkeys(lib.keys("<M-1>"), "x", false)
vim.wait(50)
lib.ok("普通模式 <M-1> → 行首非空白", col() == 4, ("col=%d"):format(col()))

fresh(4)
vim.api.nvim_feedkeys(lib.keys("<M-0>"), "x", false)
vim.wait(50)
lib.ok("普通模式 <M-0> → 行末", col() == #LINE - 1, ("col=%d want=%d"):format(col(), #LINE - 1))

-- 插入模式：单次输入流验证（文本落点证明光标移动且插入未中断）
fresh(10)
vim.api.nvim_feedkeys(lib.keys("i<M-1>AB<Esc>"), "x", false)
vim.wait(80)
lib.ok("插入模式 <M-1> 后 AB 插到行首", text() == "    ABhello world   ",
  ("text=[%s]"):format(text()))

fresh(4)
vim.api.nvim_feedkeys(lib.keys("i<M-0>Y<Esc>"), "x", false)
vim.wait(80)
lib.ok("插入模式 <M-0> 后 Y 插到行末", text() == "    hello world   Y",
  ("text=[%s]"):format(text()))

-- 注：插入模式保持性已由上面两个"文本落点"断言证明
-- （若映射退出插入模式，AB/Y 会变成 normal 命令而不会被插入）

lib.finish()
