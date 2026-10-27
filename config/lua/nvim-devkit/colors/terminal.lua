-- 终端同款配色 nvkit-terminal
-- 色板来自终端自身的 16 色：默认 campbell（Windows Terminal 默认，背景 #0c0c0c）
-- 切换色板：:lua vim.g.nvkit_terminal_palette = "wezterm" | :colorscheme nvkit-terminal
-- 背景默认用色板实色；想透明露出终端背景：:lua vim.g.nvkit_terminal_transparent = true
local M = {}

local palettes = {
  -- WezTerm 默认色板（背景 #000000 / 前景 #b2b2b2）
  wezterm = {
    bg = "#000000",
    fg = "#b2b2b2",
    black = "#000000",
    red = "#cc5555",
    green = "#55cc55",
    yellow = "#cdcd55",
    blue = "#5455cb",
    magenta = "#cc55cc",
    cyan = "#7acaca",
    silver = "#cccccc",
    gray = "#555555",
    bright_red = "#ff5555",
    bright_green = "#55ff55",
    bright_yellow = "#ffff55",
    bright_blue = "#5555ff",
    bright_magenta = "#ff55ff",
    bright_cyan = "#55ffff",
    white = "#ffffff",
  },
  -- Windows Terminal 默认（Campbell）
  campbell = {
    bg = "#0c0c0c",
    fg = "#cccccc",
    black = "#0c0c0c",
    red = "#c50f1f",
    green = "#13a10e",
    yellow = "#c19c00",
    blue = "#0037da",
    magenta = "#881798",
    cyan = "#3a96dd",
    silver = "#cccccc",
    gray = "#767676",
    bright_red = "#e74856",
    bright_green = "#16c60c",
    bright_yellow = "#f9f1a5",
    bright_blue = "#3b78ff",
    bright_magenta = "#b4009e",
    bright_cyan = "#61d6d6",
    white = "#f2f2f2",
  },
}

local DEFAULT_PALETTE = "campbell"

local function hex(c)
  return tonumber((c:gsub("#", "")), 16)
end

local function blend(a, b, t)
  local ca, cb = hex(a), hex(b)
  local function ch(c, s)
    return math.floor(c / s) % 256
  end
  local function mix(x, y)
    return math.floor(x * (1 - t) + y * t + 0.5)
  end
  return ("#%02x%02x%02x"):format(
    mix(ch(ca, 65536), ch(cb, 65536)),
    mix(ch(ca, 256), ch(cb, 256)),
    mix(ch(ca, 1), ch(cb, 1))
  )
end

local function active()
  local name = vim.g.nvkit_terminal_palette
  if type(name) ~= "string" or not palettes[name] then
    name = DEFAULT_PALETTE
  end
  return palettes[name]
end

--- 当前色板名（wezterm | campbell）
function M.palette_name()
  local name = vim.g.nvkit_terminal_palette
  if type(name) ~= "string" or not palettes[name] then
    name = DEFAULT_PALETTE
  end
  return name
end

--- 当前色板 + 派生 UI 色（soft/sel/faint/wash）
function M.colors()
  local p = vim.deepcopy(active())
  p.soft = blend(p.bg, p.fg, 0.07)
  p.sel = blend(p.bg, p.fg, 0.20)
  p.faint = blend(p.bg, p.fg, 0.35)
  p.wash = blend(p.bg, p.fg, 0.10)
  return p
end

function M.load()
  local p = M.colors()
  vim.o.background = "dark"
  vim.o.termguicolors = true
  vim.g.colors_name = "nvkit-terminal"
  local transparent = vim.g.nvkit_terminal_transparent == true
  local normal_bg = p.bg
  if transparent then
    normal_bg = nil
  end
  vim.api.nvim_set_hl(0, "Normal", { fg = p.fg, bg = normal_bg })
  -- 编辑器界面
  local groups = {
    NormalNC = { fg = p.fg, bg = normal_bg },
    NormalFloat = { fg = p.fg, bg = p.bg },
    FloatBorder = { fg = p.gray, bg = p.bg },
    FloatTitle = { fg = p.white, bg = p.bg, bold = true },
    FloatFooter = { fg = p.gray, bg = p.bg },
    Cursor = { fg = p.bg, bg = p.fg },
    lCursor = { link = "Cursor" },
    CursorIM = { link = "Cursor" },
    TermCursor = { link = "Cursor" },
    TermCursorNC = { fg = p.bg, bg = p.gray },
    CursorLine = { bg = p.wash },
    CursorColumn = { bg = p.wash },
    CursorLineNr = { fg = p.silver, bold = true },
    LineNr = { fg = p.gray },
    SignColumn = {},
    EndOfBuffer = { fg = p.faint },
    ColorColumn = { bg = p.wash },
    Visual = { bg = p.sel },
    VisualNOS = { link = "Visual" },
    Search = { fg = p.bg, bg = p.yellow },
    IncSearch = { fg = p.bg, bg = p.bright_yellow },
    CurSearch = { link = "IncSearch" },
    MatchParen = { fg = p.bright_yellow, bold = true },
    Pmenu = { fg = p.fg, bg = p.soft },
    PmenuSel = { fg = p.white, bg = p.sel, bold = true },
    PmenuSbar = { bg = p.soft },
    PmenuThumb = { bg = p.gray },
    PmenuKind = { fg = p.cyan, bg = p.soft },
    PmenuExtra = { fg = p.gray, bg = p.soft },
    WildMenu = { fg = p.bg, bg = p.cyan },
    StatusLine = { fg = p.silver, bg = p.soft },
    StatusLineNC = { fg = p.gray },
    TabLine = { fg = p.gray },
    TabLineSel = { fg = p.white, bg = p.soft, bold = true },
    TabLineFill = { bg = p.bg },
    WinSeparator = { fg = p.gray },
    VertSplit = { link = "WinSeparator" },
    Folded = { fg = p.gray, bg = p.soft },
    FoldColumn = { fg = p.gray },
    DiffAdd = { fg = p.bright_green, bg = blend(p.bg, p.green, 0.14) },
    DiffChange = { fg = p.bright_yellow, bg = blend(p.bg, p.yellow, 0.10) },
    DiffDelete = { fg = p.bright_red, bg = blend(p.bg, p.red, 0.14) },
    DiffText = { fg = p.white, bg = blend(p.bg, p.yellow, 0.22) },
    Added = { fg = p.bright_green },
    Changed = { fg = p.bright_yellow },
    Removed = { fg = p.bright_red },
    Directory = { fg = p.cyan },
    ErrorMsg = { fg = p.bright_red },
    WarningMsg = { fg = p.bright_yellow },
    ModeMsg = { fg = p.fg, bold = true },
    MsgArea = { fg = p.fg },
    MoreMsg = { fg = p.green },
    Question = { fg = p.green },
    NonText = { fg = p.gray },
    SpecialKey = { fg = p.gray },
    Whitespace = { fg = p.faint },
    Conceal = { fg = p.gray },
    QuickFixLine = { bg = p.sel },
    SpellBad = { undercurl = true, sp = p.bright_red },
    SpellCap = { undercurl = true, sp = p.bright_yellow },
    SpellLocal = { undercurl = true, sp = p.cyan },
    SpellRare = { undercurl = true, sp = p.bright_magenta },
    Underlined = { underline = true },
    Ignore = { fg = p.gray },
    Error = { fg = p.bright_red },
    Todo = { fg = p.bg, bg = p.bright_yellow, bold = true },
    Title = { fg = p.white, bold = true },
    Bold = { bold = true },
    Italic = { italic = true },
    Strikethrough = { strikethrough = true },
    DiagnosticError = { fg = p.bright_red },
    DiagnosticWarn = { fg = p.bright_yellow },
    DiagnosticInfo = { fg = p.cyan },
    DiagnosticHint = { fg = p.green },
    DiagnosticOk = { fg = p.bright_green },
    DiagnosticDeprecated = { fg = p.gray, strikethrough = true },
    DiagnosticUnnecessary = { fg = p.gray },
    DiagnosticUnderlineError = { undercurl = true, sp = p.bright_red },
    DiagnosticUnderlineWarn = { undercurl = true, sp = p.bright_yellow },
    DiagnosticUnderlineInfo = { undercurl = true, sp = p.cyan },
    DiagnosticUnderlineHint = { undercurl = true, sp = p.green },
    DiagnosticUnderlineOk = { undercurl = true, sp = p.bright_green },
    DiagnosticVirtualTextError = { fg = p.bright_red, bg = p.soft },
    DiagnosticVirtualTextWarn = { fg = p.bright_yellow, bg = p.soft },
    DiagnosticVirtualTextInfo = { fg = p.cyan, bg = p.soft },
    DiagnosticVirtualTextHint = { fg = p.green, bg = p.soft },
    DiagnosticVirtualTextOk = { fg = p.bright_green, bg = p.soft },
    LspReferenceText = { bg = p.sel },
    LspReferenceRead = { bg = blend(p.bg, p.cyan, 0.14) },
    LspReferenceWrite = { bg = blend(p.bg, p.magenta, 0.14) },
    LspSignatureActiveParameter = { bg = p.sel },
    LspInlayHint = { fg = p.gray, italic = true },
    LspCodeLens = { fg = p.gray },
    -- 语法（legacy）
    Comment = { fg = p.gray },
    Constant = { fg = p.yellow },
    String = { fg = p.green },
    Character = { fg = p.bright_green },
    Number = { fg = p.yellow },
    Boolean = { fg = p.yellow },
    Float = { fg = p.yellow },
    Identifier = { fg = p.fg },
    Function = { fg = p.cyan },
    Statement = { fg = p.magenta },
    Conditional = { fg = p.magenta },
    Repeat = { fg = p.magenta },
    Label = { fg = p.yellow },
    Operator = { fg = p.silver },
    Keyword = { fg = p.magenta },
    Exception = { fg = p.bright_red },
    PreProc = { fg = p.magenta },
    Include = { fg = p.magenta },
    Define = { fg = p.magenta },
    Macro = { fg = p.magenta },
    PreCondit = { fg = p.magenta },
    Type = { fg = p.bright_blue },
    StorageClass = { fg = p.bright_blue },
    Structure = { fg = p.bright_blue },
    Typedef = { fg = p.bright_blue },
    Special = { fg = p.cyan },
    SpecialChar = { fg = p.bright_magenta },
    Tag = { fg = p.magenta },
    Delimiter = { fg = p.silver },
    SpecialComment = { fg = p.gray, bold = true },
    Debug = { fg = p.bright_red },
    -- Treesitter 捕获
    ["@comment"] = { link = "Comment" },
    ["@comment.documentation"] = { link = "Comment" },
    ["@comment.error"] = { fg = p.bright_red, bold = true },
    ["@comment.warning"] = { fg = p.bright_yellow, bold = true },
    ["@comment.todo"] = { link = "Todo" },
    ["@comment.note"] = { fg = p.cyan, bold = true },
    ["@constant"] = { link = "Constant" },
    ["@constant.builtin"] = { fg = p.bright_yellow },
    ["@constant.macro"] = { link = "Macro" },
    ["@number"] = { link = "Number" },
    ["@boolean"] = { link = "Boolean" },
    ["@float"] = { link = "Float" },
    ["@string"] = { link = "String" },
    ["@string.escape"] = { fg = p.cyan },
    ["@string.special"] = { fg = p.bright_magenta },
    ["@string.regexp"] = { fg = p.bright_green },
    ["@string.special.url"] = { fg = p.cyan, underline = true },
    ["@character"] = { link = "Character" },
    ["@variable"] = { fg = p.fg },
    ["@variable.builtin"] = { fg = p.magenta },
    ["@variable.parameter"] = { fg = p.fg },
    ["@variable.member"] = { fg = p.silver },
    ["@property"] = { fg = p.silver },
    ["@field"] = { fg = p.silver },
    ["@parameter"] = { fg = p.fg },
    ["@function"] = { link = "Function" },
    ["@function.call"] = { fg = p.cyan },
    ["@function.builtin"] = { fg = p.cyan, bold = true },
    ["@function.macro"] = { fg = p.magenta },
    ["@function.method"] = { fg = p.cyan },
    ["@constructor"] = { fg = p.bright_blue },
    ["@keyword"] = { link = "Keyword" },
    ["@keyword.function"] = { fg = p.magenta },
    ["@keyword.operator"] = { fg = p.silver },
    ["@keyword.return"] = { fg = p.magenta },
    ["@conditional"] = { link = "Conditional" },
    ["@repeat"] = { link = "Repeat" },
    ["@exception"] = { link = "Exception" },
    ["@operator"] = { link = "Operator" },
    ["@punctuation.delimiter"] = { fg = p.silver },
    ["@punctuation.bracket"] = { fg = p.silver },
    ["@punctuation.special"] = { fg = p.cyan },
    ["@type"] = { link = "Type" },
    ["@type.builtin"] = { fg = p.bright_blue },
    ["@type.qualifier"] = { fg = p.magenta },
    ["@type.definition"] = { fg = p.bright_blue },
    ["@namespace"] = { fg = p.silver },
    ["@module"] = { fg = p.silver },
    ["@label"] = { link = "Label" },
    ["@attribute"] = { fg = p.cyan },
    ["@tag"] = { fg = p.magenta },
    ["@tag.attribute"] = { fg = p.green },
    ["@tag.delimiter"] = { fg = p.gray },
    ["@markup.heading"] = { fg = p.white, bold = true },
    ["@markup.heading.1"] = { fg = p.bright_cyan, bold = true },
    ["@markup.heading.2"] = { fg = p.bright_blue, bold = true },
    ["@markup.heading.3"] = { fg = p.bright_magenta, bold = true },
    ["@markup.link"] = { fg = p.cyan, underline = true },
    ["@markup.link.label"] = { fg = p.cyan },
    ["@markup.link.url"] = { fg = p.cyan, underline = true },
    ["@markup.raw"] = { fg = p.green },
    ["@markup.raw.block"] = { fg = p.green },
    ["@markup.list"] = { fg = p.gray },
    ["@markup.quote"] = { fg = p.gray },
    ["@markup.italic"] = { italic = true },
    ["@markup.strong"] = { bold = true },
    ["@markup.strikethrough"] = { strikethrough = true },
    ["@markup.underline"] = { underline = true },
    ["@diff.plus"] = { fg = p.bright_green },
    ["@diff.minus"] = { fg = p.bright_red },
    ["@diff.delta"] = { fg = p.bright_yellow },
    ["@diagnostic.error"] = { link = "DiagnosticError" },
    ["@diagnostic.warn"] = { link = "DiagnosticWarn" },
    ["@diagnostic.info"] = { link = "DiagnosticInfo" },
    ["@diagnostic.hint"] = { link = "DiagnosticHint" },
    -- 常用插件
    GitSignsAdd = { fg = p.bright_green },
    GitSignsChange = { fg = p.bright_yellow },
    GitSignsDelete = { fg = p.bright_red },
    SnacksPickerMatch = { fg = p.bright_yellow, bold = true },
    SnacksPickerDirectory = { fg = p.cyan },
    SnacksPickerPathHidden = { fg = p.gray },
    SnacksPickerPathIgnored = { fg = p.gray },
    SnacksPickerComment = { fg = p.gray },
    SnacksPickerRow = { fg = p.green },
    SnacksPickerCol = { fg = p.gray },
    SnacksPickerSelected = { fg = p.yellow },
    SnacksNotifierTitle = { fg = p.cyan },
    SnacksNotifierBorder = { fg = p.gray },
    NoiceCmdlinePopupBorder = { fg = p.gray },
    NoiceCmdlineIcon = { fg = p.cyan },
    NoiceCmdlineIconSearch = { fg = p.bright_yellow },
    NoicePopupBorder = { fg = p.gray },
    NoicePopupmenuBorder = { fg = p.gray },
    NoiceMini = { fg = p.gray },
    BlinkCmpMenuBorder = { fg = p.gray },
    -- which-key（leader 菜单）
    WhichKeyFloat = { bg = p.soft },
    WhichKey = { fg = p.yellow },
    WhichKeyGroup = { fg = p.cyan },
    WhichKeyDesc = { fg = p.fg },
    WhichKeySeparator = { fg = p.gray },
    WhichKeyTitle = { fg = p.white, bg = p.soft, bold = true },
    WhichKeyBorder = { fg = p.gray, bg = p.soft },
    WhichKeyValue = { fg = p.gray },
    WhichKeyIcon = { fg = p.cyan },
    WhichKeyIconAzure = { fg = p.bright_blue },
    WhichKeyIconBlue = { fg = p.cyan },
    WhichKeyIconCyan = { fg = p.bright_cyan },
    WhichKeyIconGreen = { fg = p.green },
    WhichKeyIconGrey = { fg = p.gray },
    WhichKeyIconOrange = { fg = p.yellow },
    WhichKeyIconPurple = { fg = p.magenta },
    WhichKeyIconRed = { fg = p.red },
    WhichKeyIconYellow = { fg = p.bright_yellow },
    -- 启动页（dashboard）自绘卡片
    SnacksDashboardNormal = { fg = p.fg },
    SnacksDashboardBorder = { fg = p.gray },
    SnacksDashboardKey = { fg = p.bright_yellow, bold = true },
    SnacksDashboardIcon = { fg = p.cyan },
    SnacksDashboardDesc = { fg = p.fg },
    SnacksDashboardFile = { fg = p.silver },
    SnacksDashboardFooter = { fg = p.gray },
    SnacksDashboardSpecial = { fg = p.bright_cyan },
    SnacksDashboardSession = { fg = p.bright_green },
    BlinkCmpDocBorder = { fg = p.gray },
    BlinkCmpSignatureHelpBorder = { fg = p.gray },
  }
  for name, spec in pairs(groups) do
    vim.api.nvim_set_hl(0, name, spec)
  end
end

return M
