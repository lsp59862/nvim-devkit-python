-- nvim-devkit 自检（headless: nvim-devkit --headless -l scripts/health.lua）
local fails = 0
local warns = 0

local function check(name, ok, hint)
  if ok then
    print(("  ✓ %s"):format(name))
  else
    fails = fails + 1
    print(("  ✗ %s%s"):format(name, hint and ("  → " .. hint) or ""))
  end
end

local function soft(name, ok, hint)
  if ok then
    print(("  ✓ %s"):format(name))
  else
    warns = warns + 1
    print(("  ○ %s%s"):format(name, hint and ("  → " .. hint) or ""))
  end
end

print("nvim-devkit 自检")
print(("  Neovim %s"):format(vim.version()))
check("配置文件已加载", vim.g.mapleader == " ")

for _, exe in ipairs({ "git", "rg", "fd", "fzf", "tree-sitter" }) do
  check("可执行: " .. exe, vim.fn.executable(exe) == 1, "重跑 install.sh")
end
soft("可执行: lazygit（可选，Git 浮窗）", vim.fn.executable("lazygit") == 1)
soft("可执行: gcc（parser 编译）", vim.fn.executable("gcc") == 1 or vim.fn.executable("cc") == 1)
soft(
  "ImageMagick（图片/PDF 图像，可选）",
  vim.fn.executable("magick") == 1 or vim.fn.executable("convert") == 1
)

-- Python venv
local vpy = vim.fn.stdpath("data") .. "/venv/bin/python3"
if vim.fn.executable(vpy) ~= 1 then
  vpy = vim.fn.stdpath("data") .. "/venv/bin/python"
end
if vim.fn.executable(vpy) == 1 then
  check("Python venv: " .. vpy, true)
  local obj = vim.system({
    vpy,
    "-c",
    "import debugpy, pynvim, jupyter_client; print('ok')",
  }, { text = true }):wait(30000)
  check("venv 组件: debugpy/pynvim/jupyter_client", obj.code == 0, (obj.stderr or ""):sub(1, 120))
  soft(
    "basedpyright-langserver",
    vim.fn.executable(vim.fn.stdpath("data") .. "/venv/bin/basedpyright-langserver") == 1
  )
else
  fails = fails + 1
  print("  ✗ Python venv 不存在 → 重跑 install.sh")
end

-- treesitter
local ok_ts, ts_config = pcall(require, "nvim-treesitter.config")
if ok_ts then
  local list_installed = ts_config.get_installed or ts_config.installed_parsers
  local installed = list_installed and list_installed() or {}
  check(("treesitter parser: %d 个已安装"):format(#installed), #installed > 0, ":TSInstall python")
else
  fails = fails + 1
  print("  ✗ nvim-treesitter 未加载")
end

-- 插件
local ok_lazy = pcall(require, "lazy")
check("lazy.nvim 可用", ok_lazy)
soft("snacks.nvim 可用", pcall(require, "snacks"))
soft("blink.cmp 可用", pcall(require, "blink.cmp"))
soft("nvim-dap 可用", pcall(require, "dap"))
soft("opencode CLI", vim.fn.executable("opencode") == 1, "https://opencode.ai")

print(("结果: %d 个失败, %d 个提示"):format(fails, warns))
if fails > 0 then
  os.exit(1)
end
