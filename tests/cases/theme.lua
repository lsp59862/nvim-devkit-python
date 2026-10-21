-- 主题：终端同款 nvkit-terminal（默认 Campbell 色板、实色灰底、终端 16 色）
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")

local function fg(name)
  return vim.api.nvim_get_hl(0, { name = name, link = false }).fg
end
local function bg(name)
  return vim.api.nvim_get_hl(0, { name = name, link = false }).bg
end

lib.eq("默认主题为 nvkit-terminal", vim.g.colors_name, "nvkit-terminal")
lib.eq("默认色板为 campbell", require("nvim-devkit.colors.terminal").palette_name(), "campbell")
lib.eq("Normal 前景 #cccccc", fg("Normal"), 0xcccccc)
lib.eq("Normal 背景 #0c0c0c（Campbell 灰底）", bg("Normal"), 0x0c0c0c)
lib.eq("Comment 灰", fg("Comment"), 0x767676)
lib.eq("String 绿", fg("String"), 0x13a10e)
lib.eq("Number 黄", fg("Number"), 0xc19c00)
lib.eq("Keyword 品红", fg("Keyword"), 0x881798)
lib.eq("Function 青", fg("Function"), 0x3a96dd)
lib.eq("Search 黄底", bg("Search"), 0xc19c00)
lib.eq("DiagnosticError 亮红", fg("DiagnosticError"), 0xe74856)
lib.eq("Treesitter @keyword 与 Keyword 同色", fg("@keyword"), 0x881798)
lib.eq("Treesitter @string 与 String 同色", fg("@string"), 0x13a10e)

-- 状态栏模式块配色
local ltheme = require("lualine.themes.nvkit-terminal")
lib.eq("lualine normal 青", ltheme.normal.a.bg, "#3a96dd")
lib.eq("lualine insert 绿", ltheme.insert.a.bg, "#13a10e")
lib.eq("lualine terminal 蓝", ltheme.terminal.a.bg, "#0037da")

-- 实色背景下的分屏压暗：背景+文字一起压暗
require("nvim-devkit.theme").clear_splits(true, true)
local dim = vim.api.nvim_get_hl(0, { name = "NvkitDimmed", link = false })
lib.ok("实色主题下压暗背景与文字", dim.fg ~= nil and dim.bg ~= nil,
  ("fg=%s bg=%s"):format(tostring(dim.fg), tostring(dim.bg)))
lib.ok("分界线高亮存在", fg("WinSeparator") ~= nil, tostring(fg("WinSeparator")))

-- 可切换回 tokyonight 再切回
vim.cmd.colorscheme("tokyonight")
lib.ok("可切换到 tokyonight", tostring(vim.g.colors_name):find("tokyonight", 1, true) == 1,
  tostring(vim.g.colors_name))
vim.cmd.colorscheme("nvkit-terminal")
lib.eq("可切回 nvkit-terminal", vim.g.colors_name, "nvkit-terminal")

-- 切回 WezTerm 默认色板
vim.g.nvkit_terminal_palette = "wezterm"
vim.cmd.colorscheme("nvkit-terminal")
lib.eq("wezterm 色板：Normal 前景 #b2b2b2", fg("Normal"), 0xb2b2b2)
lib.eq("wezterm 色板：Normal 背景 #000000", bg("Normal"), 0x000000)

-- 可选透明背景
vim.g.nvkit_terminal_palette = nil
vim.g.nvkit_terminal_transparent = true
vim.cmd.colorscheme("nvkit-terminal")
lib.ok("透明选项：Normal.bg 为空", bg("Normal") == nil, tostring(bg("Normal")))
vim.g.nvkit_terminal_transparent = nil
vim.cmd.colorscheme("nvkit-terminal")
lib.eq("恢复实色背景", bg("Normal"), 0x0c0c0c)

lib.finish()
