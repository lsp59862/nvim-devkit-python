-- 终端能力探测（图片渲染后端 / 可选工具）
local M = {}

local function set(v)
  return v ~= nil and v ~= ""
end

function M.kitty_terminal()
  local override = vim.env.NVIM_DEVKIT_IMAGES
  if override == "1" then
    return true
  end
  if override == "0" then
    return false
  end
  local term = (vim.env.TERM or ""):lower()
  local term_program = vim.env.TERM_PROGRAM or ""
  return set(vim.env.KITTY_WINDOW_ID)
    or set(vim.env.WEZTERM_PANE)
    or set(vim.env.GHOSTTY_RESOURCES_DIR)
    -- VS Code 内置终端自 1.110 起支持 Kitty 图形协议（需 enableImages 设置）
    or set(vim.env.VSCODE_INJECTION)
    or term_program == "vscode"
    or term_program == "vscode-insiders"
    or term_program == "WezTerm"
    or term:find("kitty", 1, true) ~= nil
    or term:find("wezterm", 1, true) ~= nil
end

function M.has_magick()
  return vim.fn.executable("magick") == 1 or vim.fn.executable("convert") == 1
end

--- 静态判定: "kitty" | "sixel" | "none"（只看环境变量）
--- 手动指定: NVIM_DEVKIT_IMAGE_BACKEND=kitty|sixel|none
function M.image_backend()
  local override = vim.env.NVIM_DEVKIT_IMAGE_BACKEND
  if override == "kitty" or override == "sixel" or override == "none" then
    return override
  end
  if M.kitty_terminal() then
    return "kitty"
  end
  return "none"
end

function M.images_enabled()
  return M.image_backend() ~= "none"
end

--- 运行时探测：借助 snacks 的 XTVERSION 查询识别终端（SSH 下的 WezTerm 等也能认出来）
--- 仅在使用时调用（打开 PDF / 初始化 molten / 加载 markdown），结果缓存
function M.detect_backend()
  if M._detected then
    return M._detected
  end
  local ok, env = pcall(function()
    return require("snacks.image.terminal").env()
  end)
  M._detected = (ok and env and env.supported) and "kitty" or "none"
  return M._detected
end

--- 使用时的有效后端：显式环境变量 → 静态探测 → snacks 终端查询
function M.effective_backend()
  local override = vim.env.NVIM_DEVKIT_IMAGE_BACKEND
  if override == "kitty" or override == "sixel" or override == "none" then
    return override
  end
  if vim.env.NVIM_DEVKIT_IMAGES == "0" then
    return "none"
  end
  if M.kitty_terminal() then
    return "kitty"
  end
  return M.detect_backend()
end

return M
