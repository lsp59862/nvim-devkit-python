-- nvim-devkit — 一键部署的科研版 Neovim
-- 设计原则：可预测、可恢复、一切状态都能一键还原（Ctrl-g 恐慌重置）

vim.g.mapleader = " "
vim.g.maplocalleader = " "

require("config.options")
require("config.keymaps")
require("config.autocmds")
require("nvim-devkit.ls").setup()
-- 默认主题：终端同款（色板可用 vim.g.nvkit_terminal_palette 切换 wezterm/campbell）
vim.cmd.colorscheme("nvkit-terminal")
require("nvim-devkit.term").setup()
require("config.lazy")
