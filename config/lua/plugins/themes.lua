-- 可选主题（默认是终端同款 nvkit-terminal，见 config/init.lua；本文件只负责"装好"，不自动切换）
-- 手动试用：
--   :colorscheme catppuccin-mocha | catppuccin-macchiato | catppuccin-frappe | catppuccin-latte
--   :colorscheme kanagawa-wave | kanagawa-dragon | kanagawa-lotus
--   :colorscheme tokyonight-storm | tokyonight-day
-- 想设为默认：把 config/init.lua 里的 vim.cmd.colorscheme("nvkit-terminal") 改成想要的名字
-- 终端同款主题的色板：vim.g.nvkit_terminal_palette = "wezterm" | "campbell"
return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    opts = {
      flavour = "mocha",
      -- 非当前窗口压暗：分屏时两个文件不在"同一平面"，边界清晰
      dim_inactive = { enabled = true, shade = "dark", percentage = 0.15 },
    },
  },
  {
    "rebelot/kanagawa.nvim",
    lazy = false,
    opts = {
      dimInactive = true,
      background = { dark = "wave" },
    },
  },
}
