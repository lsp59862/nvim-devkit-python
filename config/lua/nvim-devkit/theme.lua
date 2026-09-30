-- 分屏清晰化：非活动窗口压暗 + 分界线加亮（默认开启，对任意主题生效）
--   :NvkitSplits                     运行时开关
--   启动时关闭: NVIM_DEVKIT_SPLITS=0 nvim-devkit
--   调整强度（0~1，bg_fade 越大背景越暗，fg_fade 越大文字越淡）：
--     :lua local t=require("nvim-devkit.theme"); t.options.bg_fade=0.5; t.options.fg_fade=0.7; t.dim_inactive(false); t.dim_inactive(true)
local M = {}

---@class NvkitThemeOptions
M.options = {
  bg_fade = 0.35, -- 非活动窗口背景向黑/白靠拢比例
  fg_fade = 0.55, -- 非活动窗口文字向背景淡出比例
}

local dim_group = "NvkitDimmed"
local sep_group = "WinSeparator"
local dim_active = false
local sep_active = false

local augroup = vim.api.nvim_create_augroup("nvim_devkit_theme", { clear = true })

local function channels(c)
  return math.floor(c / 65536) % 256, math.floor(c / 256) % 256, c % 256
end

local function blend(c1, c2, t) -- t = c2 的权重
  local r1, g1, b1 = channels(c1)
  local r2, g2, b2 = channels(c2)
  local r = math.floor(r1 * (1 - t) + r2 * t + 0.5)
  local g = math.floor(g1 * (1 - t) + g2 * t + 0.5)
  local b = math.floor(b1 * (1 - t) + b2 * t + 0.5)
  return r * 65536 + g * 256 + b
end

local function refresh_dim_group()
  local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
  if not normal.bg then
    return false
  end
  local target = vim.o.background == "dark" and 0x000000 or 0xffffff
  local hl = { bg = blend(normal.bg, target, M.options.bg_fade) }
  if normal.fg then
    hl.fg = blend(normal.fg, normal.bg, M.options.fg_fade)
  end
  vim.api.nvim_set_hl(0, dim_group, hl)
  return true
end

local function dim_hl()
  local parts = {}
  for _, g in ipairs({ "NormalNC", "LineNr", "SignColumn", "EndOfBuffer", "WinBarNC" }) do
    parts[#parts + 1] = g .. ":" .. dim_group
  end
  return table.concat(parts, ",")
end

local function apply_dim()
  if not dim_active then
    return
  end
  local cur = vim.api.nvim_get_current_win()
  local tab = vim.api.nvim_get_current_tabpage()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_tabpage(win) == tab then
      pcall(function()
        vim.wo[win].winhighlight = (win == cur) and "" or dim_hl()
      end)
    end
  end
end

local function apply_sep()
  if not sep_active then
    return
  end
  local function hl_fg(name)
    local hl = vim.api.nvim_get_hl(0, { name = name, link = false })
    return hl and hl.fg or nil
  end
  -- 用主题的功能色（通常是亮色）作为分界线，找不到就退回普通前景色
  local fg = hl_fg("Function") or hl_fg("Keyword") or hl_fg("Normal")
  if fg then
    vim.api.nvim_set_hl(0, sep_group, { fg = fg, bold = true })
  end
end

local function refresh_all()
  if dim_active then
    refresh_dim_group()
    apply_dim()
  end
  if sep_active then
    apply_sep()
  end
end

--- 非当前窗口压暗（nil = 切换）
function M.dim_inactive(enable, silent)
  if enable == nil then
    enable = not dim_active
  end
  dim_active = enable and true or false
  if dim_active then
    if refresh_dim_group() then
      apply_dim()
    elseif not silent then
      vim.notify("主题尚未就绪，配色加载后将自动应用压制", vim.log.levels.INFO)
    end
  else
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      vim.wo[win].winhighlight = ""
    end
  end
  return dim_active
end

--- 分界线加亮（nil = 切换）
function M.vivid_separator(enable)
  if enable == nil then
    enable = not sep_active
  end
  sep_active = enable and true or false
  if sep_active then
    apply_sep()
  else
    vim.cmd("highlight clear " .. sep_group)
    vim.cmd.colorscheme(vim.g.colors_name or "tokyonight")
  end
  return sep_active
end

--- 一键分屏增强（nil = 切换两者）；silent 用于启动时默认应用
function M.clear_splits(enable, silent)
  if enable == nil then
    enable = not (dim_active or sep_active)
  end
  M.dim_inactive(enable, silent)
  M.vivid_separator(enable)
  if not silent then
    vim.notify(
      enable and "分屏增强已开启：非活动窗口压暗 + 分界线加亮"
        or "分屏增强已关闭（NVIM_DEVKIT_SPLITS=0 可在启动时保持关闭）",
      vim.log.levels.INFO
    )
  end
end

--- 当前状态（调试/测试用）
function M.status()
  return { dim = dim_active, sep = sep_active }
end

vim.api.nvim_create_autocmd({ "WinEnter", "WinLeave", "WinNew", "TabEnter" }, {
  group = augroup,
  callback = apply_dim,
})

vim.api.nvim_create_autocmd("ColorScheme", {
  group = augroup,
  callback = refresh_all,
})

-- 兜底：配色/启动时序偏晚时再刷新一次
vim.api.nvim_create_autocmd("User", {
  group = augroup,
  pattern = "VeryLazy",
  callback = refresh_all,
})

vim.api.nvim_create_user_command("NvkitSplits", function()
  M.clear_splits()
end, { desc = "切换分屏增强（压暗非活动窗口 + 加亮分界线）" })

return M
