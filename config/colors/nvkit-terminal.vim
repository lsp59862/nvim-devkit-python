" 终端同款配色：黑底 + 终端原生 16 色（默认取 WezTerm 默认色板）
" 可用 vim.g.nvkit_terminal_palette = "wezterm" | "campbell" 切换色板
hi clear
if exists("syntax_on")
  syntax reset
endif
lua require("nvim-devkit.colors.terminal").load()
