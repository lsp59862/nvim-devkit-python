-- 真实按键路径：:bd 在 dashboard 上 → 拒绝（提示用 :q）
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")
local wb = require("nvim-devkit.winbuf")

lib.reset()
wb.open_dashboard()
vim.wait(200)
vim.api.nvim_feedkeys(lib.keys(":bd<CR>"), "x", false)
vim.wait(500)
lib.ok("按键 :bd 在 dashboard 被拒绝", lib.is_dashboard() and lib.wins() == 1,
  ("ft=%s wins=%d"):format(vim.bo.filetype, lib.wins()))
lib.finish()
