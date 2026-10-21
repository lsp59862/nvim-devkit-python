-- lualine 主题：跟随 nvkit-terminal（透明状态栏 c 段，终端同款色）
local T = require("nvim-devkit.colors.terminal")
local p = T.colors()

local function sec(fg, bg, bold)
  return { fg = fg, bg = bg, gui = bold and "bold" or nil }
end

local b = sec(p.fg, p.soft)
local c = sec(p.fg, "NONE")

return {
  normal = { a = sec(p.bg, p.green, true), b = b, c = c },
  insert = { a = sec(p.bg, p.blue, true), b = b, c = c },
  visual = { a = sec(p.bg, p.magenta, true), b = b, c = c },
  replace = { a = sec(p.bg, p.bright_red, true), b = b, c = c },
  terminal = { a = sec(p.bg, p.cyan, true), b = b, c = c },
  inactive = {
    a = sec(p.gray, "NONE", true),
    b = sec(p.gray, "NONE"),
    c = sec(p.gray, "NONE"),
  },
}
