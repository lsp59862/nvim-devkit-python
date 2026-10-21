-- 主题：终端同款 nvkit-terminal（透明背景、终端 16 色）
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")

local function fg(name)
  return vim.api.nvim_get_hl(0, { name = name, link = false }).fg
end
local function bg(name)
  return vim.api.nvim_get_hl(0, { name = name, link = false }).bg
end

lib.eq("默认主题为 nvkit-terminal", vim.g.colors_name, "nvkit-terminal")
lib.eq("Normal 前景 #b2b2b2", fg("Normal"), 0xb2b2b2)
lib.ok("背景透明（Normal.bg 为空）", bg("Normal") == nil, tostring(bg("Normal")))
lib.eq("Comment 灰", fg("Comment"), 0x555555)
lib.eq("String 绿", fg("String"), 0x55cc55)
lib.eq("Number 黄", fg("Number"), 0xcdcd55)
lib.eq("Keyword 品红", fg("Keyword"), 0xcc55cc)
lib.eq("Function 青", fg("Function"), 0x7acaca)
lib.eq("Search 黄底", bg("Search"), 0xcdcd55)
lib.eq("DiagnosticError 亮红", fg("DiagnosticError"), 0xff5555)
lib.eq("Treesitter @keyword 与 Keyword 同色", fg("@keyword"), 0xcc55cc)
lib.eq("Treesitter @string 与 String 同色", fg("@string"), 0x55cc55)

-- 透明背景下的分屏压暗：只压暗文字
require("nvim-devkit.theme").clear_splits(true, true)
local dim = vim.api.nvim_get_hl(0, { name = "NvkitDimmed", link = false })
lib.ok("透明主题下压暗只作用于文字", dim.fg ~= nil and dim.bg == nil,
  ("fg=%s bg=%s"):format(tostring(dim.fg), tostring(dim.bg)))
lib.ok("分界线高亮存在", fg("WinSeparator") ~= nil, tostring(fg("WinSeparator")))

-- 可切换回 tokyonight 再切回
vim.cmd.colorscheme("tokyonight")
lib.ok("可切换到 tokyonight", tostring(vim.g.colors_name):find("tokyonight", 1, true) == 1,
  tostring(vim.g.colors_name))
vim.cmd.colorscheme("nvkit-terminal")
lib.eq("可切回 nvkit-terminal", vim.g.colors_name, "nvkit-terminal")

-- 色板切换到 Windows Terminal Campbell
vim.g.nvkit_terminal_palette = "campbell"
vim.cmd.colorscheme("nvkit-terminal")
lib.eq("campbell 色板：Normal 前景 #cccccc", fg("Normal"), 0xcccccc)
lib.eq("campbell 色板：String 绿", fg("String"), 0x13a10e)
vim.g.nvkit_terminal_palette = nil
vim.cmd.colorscheme("nvkit-terminal")

lib.finish()
