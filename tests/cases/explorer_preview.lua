-- 文件浏览器预览模式：单一复用 buffer、焦点不动、文本/图片、被修改/关闭时清理
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")
local explorer = require("nvim-devkit.explorer")

lib.reset()
local parent = vim.api.nvim_get_current_win()
explorer.parent = parent
explorer.mode = true

-- 文本预览：显示在父窗口、不切焦点、buffe r不列出
local f1 = lib.dir() .. "/preview_a.lua"
vim.fn.writefile({ "print('a1')", "print('a2')" }, f1)
explorer.on_change(nil, { file = f1 })
local b1 = explorer.buf
lib.ok("文本预览：父窗口显示预览 buffer", vim.api.nvim_win_get_buf(parent) == b1,
  ("winbuf=%s preview=%s"):format(tostring(vim.api.nvim_win_get_buf(parent)), tostring(b1)))
lib.ok("预览不切换焦点", vim.api.nvim_get_current_win() == parent,
  vim.inspect(vim.api.nvim_get_current_win()))
lib.ok("预览 buffer 不列出（且非 nofile，便于 modified 跟踪）",
  vim.bo[b1].buflisted == false and vim.bo[b1].buftype == "",
  ("buftype=%q listed=%s"):format(vim.bo[b1].buftype, tostring(vim.bo[b1].buflisted)))
lib.eq("文本内容正确", vim.api.nvim_buf_get_lines(b1, 0, 1, false)[1], "print('a1')")

-- 复用：换一个文本文件仍是同一个 buffer
local f2 = lib.dir() .. "/preview_b.py"
vim.fn.writefile({ "print('b1')" }, f2)
explorer.on_change(nil, { file = f2 })
lib.ok("文本预览复用同一 buffer", explorer.buf == b1, ("buf=%s→%s"):format(tostring(b1), tostring(explorer.buf)))
lib.eq("复用后内容更新", vim.api.nvim_buf_get_lines(b1, 0, 1, false)[1], "print('b1')")

-- 文本预览被修改 → 自动清理
-- （headless 的 luafile/vim.wait 上下文不会自动触发 BufModifiedSet；真实主循环会，
--   这里显式触发事件验证"事件 → 清理"的接线）
vim.api.nvim_exec_autocmds("BufModifiedSet", { buffer = b1 })
vim.wait(100, function()
  return not (explorer.buf and vim.api.nvim_buf_is_valid(explorer.buf))
end, 20)
lib.ok("文本预览被修改后自动删除", not (explorer.buf and vim.api.nvim_buf_is_valid(explorer.buf)),
  "buf=" .. tostring(explorer.buf))

-- 图片预览（需要 magick）：ft=image + 查看器状态（在父窗口显示、焦点不动）
if vim.fn.executable("magick") == 1 then
  local png = lib.dir() .. "/preview_img.png"
  vim.system({ "magick", "-size", "120x90", "xc:#3a7", png }):wait(10000)
  explorer.on_change(nil, { file = png })
  local ib = explorer.buf
  local st = require("nvim-devkit.viewer").state(ib)
  local ok = vim.wait(3000, function()
    return st ~= nil and st.view ~= nil
  end, 50)
  lib.ok("图片预览：ft=image 且查看器已渲染",
    ib ~= nil and vim.bo[ib].filetype == "image" and ok and st.view ~= nil,
    ("ft=%s st=%s"):format(tostring(ib and vim.bo[ib].filetype), tostring(st ~= nil)))
  lib.ok("图片预览显示在父窗口、焦点不动",
    vim.api.nvim_win_get_buf(parent) == ib and vim.api.nvim_get_current_win() == parent,
    ("winbuf=%s cur=%s"):format(tostring(vim.api.nvim_win_get_buf(parent)), tostring(vim.api.nvim_get_current_win())))
  -- 图片之间复用同一 buffer
  local png2 = lib.dir() .. "/preview_img2.png"
  vim.system({ "magick", "-size", "100x80", "xc:#a37", png2 }):wait(10000)
  explorer.on_change(nil, { file = png2 })
  lib.ok("图片预览复用同一 buffer", explorer.buf == ib,
    ("buf=%s→%s"):format(tostring(ib), tostring(explorer.buf)))
else
  lib.ok("图片预览（需要 ImageMagick，跳过）", true, "optional")
end

-- 关闭预览模式 → 清理
explorer.toggle(nil)
vim.wait(100)
lib.ok("关闭预览模式后删除预览 buffer",
  explorer.mode == false and not (explorer.buf and vim.api.nvim_buf_is_valid(explorer.buf)),
  ("mode=%s buf=%s"):format(tostring(explorer.mode), tostring(explorer.buf)))

lib.finish()
