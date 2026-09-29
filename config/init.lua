-- nvim-devkit — 一键部署的科研版 Neovim
-- 设计原则：可预测、可恢复、一切状态都能一键还原（Ctrl-g 恐慌重置）

vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("config.options")
require("config.keymaps")
require("config.autocmds")
require("config.lazy")
