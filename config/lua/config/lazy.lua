local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local repo = "https://github.com/folke/lazy.nvim.git"
  local mirror = vim.env.NVIM_DEVKIT_MIRROR
  if mirror and mirror ~= "" then
    repo = mirror:gsub("/$", "") .. "/" .. repo
  end
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", repo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({ { "lazy.nvim 安装失败: " .. out, "ErrorMsg" } }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)
vim.loader.enable()

local lazy_opts = {
  spec = { { import = "plugins" } },
  defaults = { lazy = false },
  install = { missing = true },
  -- 更新统一走 `./install.sh --update`，避免编辑器启动时静默变更状态
  checker = { enabled = false },
  change_detection = { enabled = false },
  -- 禁用 luarocks（image.nvim 的 lazy.lua 会声明 magick rock，这里显式关闭）
  rocks = { enabled = false },
  performance = {
    cache = { enabled = true },
    rtp = {
      disabled_plugins = { "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin", "netrwPlugin" },
    },
  },
  ui = { border = "rounded" },
}

local mirror = vim.env.NVIM_DEVKIT_MIRROR
if mirror and mirror ~= "" then
  lazy_opts.git = { url_format = mirror:gsub("/$", "") .. "/https://github.com/%s.git" }
end

require("lazy").setup(lazy_opts)

-- 默认开启分屏增强：非活动窗口压暗 + 分界线加亮
-- 关闭方式：启动前 NVIM_DEVKIT_SPLITS=0，或运行时 :NvkitSplits
if vim.env.NVIM_DEVKIT_SPLITS ~= "0" then
  pcall(function()
    require("nvim-devkit.theme").clear_splits(true, true)
  end)
end
