-- 分屏清晰化（可选，对任意主题生效，默认关闭）
--   :NvkitSplits                     一键切换：压暗非活动窗口 + 加亮分界线
--   :lua require("nvim-devkit.theme").clear_splits(true|false)
--   :lua require("nvim-devkit.theme").dim_inactive(true)    只要窗口压暗
--   :lua require("nvim-devkit.theme").vivid_separator(true) 只要分界线加亮
-- 主题自带同类功能的可直接用：tokyonight 的 dim_inactive、catppuccin 的 dim_inactive、kanagawa 的 dimInactive
local M = {}

local dim_group = "NvkitDimmed"
local sep_group = "WinSeparator"
local dim_active = false
local sep_active = false

local augroup = vim.api.nvim_create_augroup("nvim_devkit_theme", { clear = true })

local function blend_toward(bg)
  -- 深色主题向黑压暗，浅色主题向白淡化，保持可读对比
  local r = math.floor(bg / 65536) % 256
  local g = math.floor(bg / 256) % 256
  local b = bg % 256
  local target = vim.o.background == "dark" and 0 or 255
  local keep = 0.78
  local function mix(c)
    return math.floor(c * keep + target * (1 - keep) + 0.5)
  end
  return mix(r) * 65536 + mix(g) * 256 + mix(b)
end

local function refresh_dim_group()
  local bg = vim.api.nvim_get_hl(0, { name = "Normal", link = false }).bg
  if not bg then
    return false
  end
  vim.api.nvim_set_hl(0, dim_group, { bg = blend_toward(bg) })
  return true
end

local function apply_dim()
  if not dim_active then
    return
  end
  local cur = vim.api.nvim_get_current_win()
  local tab = vim.api.nvim_get_current_tabpage()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_tabpage(win) == tab then
      vim.wo[win].winhighlight = (win == cur) and "" or ("NormalNC:" .. dim_group)
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

--- 非当前窗口背景压暗（nil = 切换）
function M.dim_inactive(enable)
  if enable == nil then
    enable = not dim_active
  end
  dim_active = enable and true or false
  if dim_active and refresh_dim_group() then
    apply_dim()
  elseif dim_active then
    vim.notify("当前主题没有 Normal 背景色，无法压暗非活动窗口", vim.log.levels.WARN)
    dim_active = false
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
    -- 交还给主题：清掉覆盖后由 ColorScheme 重载生效
    vim.cmd("highlight clear " .. sep_group)
    vim.cmd.colorscheme(vim.g.colors_name or "tokyonight")
  end
  return sep_active
end

--- 一键分屏增强（nil = 切换两者）
function M.clear_splits(enable)
  if enable == nil then
    enable = not (dim_active or sep_active)
  end
  M.dim_inactive(enable)
  M.vivid_separator(enable)
  vim.notify(
    enable and "分屏增强已开启：非活动窗口压暗 + 分界线加亮"
      or "分屏增强已关闭（如需永久生效可改主题自带的 dim_inactive）",
    vim.log.levels.INFO
  )
end

vim.api.nvim_create_autocmd({ "WinEnter", "WinLeave", "TabEnter" }, {
  group = augroup,
  callback = apply_dim,
})

vim.api.nvim_create_autocmd("ColorScheme", {
  group = augroup,
  callback = function()
    if dim_active then
      refresh_dim_group()
      apply_dim()
    end
    if sep_active then
      apply_sep()
    end
  end,
})

vim.api.nvim_create_user_command("NvkitSplits", function()
  M.clear_splits()
end, { desc = "切换分屏增强（压暗非活动窗口 + 加亮分界线）" })

return M
