-- 终端同类循环：<M-j>/<M-k> 只在当前面板内循环，<M-n> 新建同类
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")
local term = require("nvim-devkit.term")
term.setup()

lib.ok("<M-j>/<M-k>/<M-n>/<M-r> 终端模式映射存在",
  vim.fn.maparg("<M-j>", "t", false, true).callback ~= nil
    and vim.fn.maparg("<M-k>", "t", false, true).callback ~= nil
    and vim.fn.maparg("<M-n>", "t", false, true).callback ~= nil
    and vim.fn.maparg("<M-r>", "t", false, true).callback ~= nil)

lib.reset()
term.summon("float")
vim.wait(300)
term.new_like_current()
vim.wait(200)
term.new_like_current()
vim.wait(200)
local f = term.terms("float")
lib.ok("Alt+N 连开 3 台浮动且当前为最后一台", term.count("float") == 3 and term.cur("float") == f[3].id,
  ("n=%d cur=%s"):format(term.count("float"), tostring(term.cur("float"))))

term.select("float", f[1].id)
vim.wait(100)
term.cycle(1)
vim.wait(100)
lib.ok("float 内下一个 → #2", term.cur("float") == f[2].id, tostring(term.cur("float")))
term.cycle(1)
lib.ok("float 内下一个 → #3", term.cur("float") == f[3].id, tostring(term.cur("float")))
term.cycle(1)
lib.ok("float 内回绕 → #1", term.cur("float") == f[1].id, tostring(term.cur("float")))
term.cycle(-1)
lib.ok("float 内上一个 → #3", term.cur("float") == f[3].id, tostring(term.cur("float")))

term.summon("bottom")
vim.wait(300)
local b = term.terms("bottom")[1]
term.select("bottom", b.id)
vim.wait(100)
term.cycle(1)
vim.wait(100)
lib.ok("底部单台循环不跨类", term.cur("bottom") == b.id and term.cur("float") == f[3].id,
  ("bcur=%s fcur=%s"):format(tostring(term.cur("bottom")), tostring(term.cur("float"))))

term.select("float", f[1].id)
vim.wait(100)
term.cycle(1)
lib.ok("浮动循环不影响底部", term.cur("float") == f[2].id and term.cur("bottom") == b.id,
  ("fcur=%s bcur=%s"):format(tostring(term.cur("float")), tostring(term.cur("bottom"))))

term.kill(f[1].id)
term.kill(f[2].id)
term.kill(f[3].id)
term.kill(b.id)
vim.wait(400)
lib.ok("全部清理", term.count() == 0, "n=" .. term.count())

lib.finish()
