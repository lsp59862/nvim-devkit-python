-- 文件/窗口语义（直接调用 winbuf 函数，覆盖 :q / :bd / <leader>wd 的核心分支）
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")
local wb = require("nvim-devkit.winbuf")

local A = lib.fixture("A.py", { "A" })
local B = lib.fixture("B.md", { "B" })
local listed = function(f)
  return vim.fn.buflisted(vim.fn.bufnr(f)) == 1
end

-- W0 关键键位映射存在
lib.ok("W0 键位映射存在",
  vim.fn.maparg(" bd", "n") ~= "" and vim.fn.maparg(" wd", "n") ~= "" and vim.fn.maparg("<C-Tab>", "n") ~= "",
  ("bd=%s wd=%s C-Tab=%s"):format(
    tostring(vim.fn.maparg(" bd", "n") ~= ""),
    tostring(vim.fn.maparg(" wd", "n") ~= ""),
    tostring(vim.fn.maparg("<C-Tab>", "n") ~= "")
  ))

-- W1 单窗双文件 :q → 切到另一个文件，程序不退
lib.reset(); vim.cmd.edit(A); vim.cmd.edit(B)
wb.close_file({})
lib.ok("W1 单窗双文件 :q", vim.fn.bufname() == A and not listed(B) and lib.wins() == 1,
  ("当前=%s wins=%d"):format(lib.base(vim.fn.bufname()), lib.wins()))

-- W2 单窗单文件 :q → dashboard，程序不退
lib.reset(); vim.cmd.edit(A)
wb.close_file({})
lib.ok("W2 单窗单文件 :q → dashboard", lib.is_dashboard() and lib.wins() == 1,
  ("ft=%s wins=%d"):format(vim.bo.filetype, lib.wins()))

-- W5 同文件双分屏 :q → 只切当前分屏，文件保留在另一分屏
lib.reset(); vim.cmd.edit(A); vim.cmd.vsplit()
wb.close_file({})
lib.ok("W5 同文件双窗 :q", lib.wins() == 2 and #vim.fn.win_findbuf(vim.fn.bufnr(A)) == 1 and lib.is_dashboard(),
  ("wins=%d A显示=%d ft=%s"):format(lib.wins(), #vim.fn.win_findbuf(vim.fn.bufnr(A)), vim.bo.filetype))

-- W6 同文件双分屏 + 有其它文件 :q → 当前分屏切到其它文件，A 保留
lib.reset(); vim.cmd.edit(B); vim.cmd.edit(A); vim.cmd.vsplit()
wb.close_file({})
lib.ok("W6 同文件双窗+其它 :q", lib.wins() == 2 and #vim.fn.win_findbuf(vim.fn.bufnr(A)) == 1 and vim.fn.bufname() == B,
  ("wins=%d A显示=%d 当前=%s"):format(lib.wins(), #vim.fn.win_findbuf(vim.fn.bufnr(A)), lib.base(vim.fn.bufname())))

-- W7 多窗不同文件 :q → 当前窗口切走，B 关闭，窗口数不变
lib.reset(); vim.cmd.edit(A); vim.cmd.vsplit(); vim.cmd.edit(B)
wb.close_file({})
lib.ok("W7 多窗不同文件 :q", lib.wins() == 2 and not listed(B) and vim.fn.bufname() == A,
  ("wins=%d B_listed=%s 当前=%s"):format(lib.wins(), tostring(listed(B)), lib.base(vim.fn.bufname())))

-- W8 bd 单窗最后文件 → dashboard
lib.reset(); vim.cmd.edit(A)
wb.delete_buffer_and_windows({})
lib.ok("W8 bd 单窗最后文件 → dashboard", lib.is_dashboard(),
  ("ft=%s"):format(vim.bo.filetype))

-- W9 bd 多窗 → 关文件 + 关当前窗口
lib.reset(); vim.cmd.edit(A); vim.cmd.vsplit(); vim.cmd.edit(B)
wb.delete_buffer_and_windows({})
lib.ok("W9 bd 多窗", lib.wins() == 1 and not listed(B) and vim.fn.bufname() == A,
  ("wins=%d B_listed=%s 当前=%s"):format(lib.wins(), tostring(listed(B)), lib.base(vim.fn.bufname())))

-- W10 bd 在 dashboard → 拒绝
lib.reset(); wb.open_dashboard(); vim.wait(200)
wb.delete_buffer_and_windows()
lib.ok("W10 bd 在 dashboard 拒绝", lib.is_dashboard(), ("ft=%s"):format(vim.bo.filetype))

-- W11 wd 单窗口 → 拒绝（不报错）
lib.reset(); vim.cmd.edit(A)
wb.close_window()
lib.ok("W11a wd 单窗拒绝", lib.wins() == 1 and listed(A) and vim.fn.bufname() == A,
  ("wins=%d listed=%s"):format(lib.wins(), tostring(listed(A))))

-- W11b wd 多窗口 → 只关窗口，不动 buffer
lib.reset(); vim.cmd.edit(A); vim.cmd.vsplit(); vim.cmd.edit(B)
wb.close_window()
lib.ok("W11b wd 多窗", lib.wins() == 1 and listed(A) and listed(B),
  ("wins=%d A=%s B=%s"):format(lib.wins(), tostring(listed(A)), tostring(listed(B))))

-- W11c wd 在 dashboard → 拒绝
lib.reset(); wb.open_dashboard(); vim.wait(200)
wb.close_window()
lib.ok("W11c wd 在 dashboard 拒绝", lib.is_dashboard(), ("ft=%s"):format(vim.bo.filetype))

-- W12 无名 buffer（:enew）单窗 :q → dashboard
lib.reset(); vim.cmd("enew")
wb.close_file({})
lib.ok("W12 无名 buffer :q → dashboard", lib.is_dashboard(),
  ("ft=%s"):format(vim.bo.filetype))

-- W13 无名 buffer + 隐藏文件 :q → 切到该文件
lib.reset(); vim.cmd.edit(A); vim.cmd("enew")
wb.close_file({})
lib.ok("W13 无名 buffer+隐藏文件 :q", vim.fn.bufname() == A and lib.wins() == 1,
  ("当前=%s wins=%d"):format(lib.base(vim.fn.bufname()), lib.wins()))

lib.finish()
