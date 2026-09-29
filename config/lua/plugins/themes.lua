-- 可选主题（默认仍是 tokyonight night，本文件只负责"装好"，不自动切换）
-- 手动试用：
--   :colorscheme catppuccin-mocha | catppuccin-macchiato | catppuccin-frappe | catppuccin-latte
--   :colorscheme kanagawa-wave | kanagawa-dragon | kanagawa-lotus
--   :colorscheme tokyonight-storm | tokyonight-day
-- 想设为默认：在 config/lua/plugins/ui.lua 里把 tokyonight 的
-- colorscheme("tokyonight") 改成想要的名字，或在本文件 config 里 vim.cmd.colorscheme(...)
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
