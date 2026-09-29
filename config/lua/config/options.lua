local opt = vim.opt

-- ── 界面 ─────────────────────────────────────────────
opt.number = true
opt.relativenumber = true
opt.signcolumn = "yes"
opt.cursorline = true
opt.termguicolors = true
opt.showmode = true
opt.showcmd = true
opt.laststatus = 3
opt.scrolloff = 8
opt.sidescrolloff = 8
opt.splitright = true
opt.splitbelow = true
opt.wrap = false
opt.linebreak = true
opt.pumheight = 12
opt.winminwidth = 4
opt.mouse = "a"
opt.mousescroll = "ver:3,hor:6"
opt.background = "dark"

-- ── 行为 / 恢复能力 ───────────────────────────────────
opt.undofile = true -- 撤销历史跨会话保留（:earlier / undotree 的基础）
opt.swapfile = true -- 崩溃后可恢复
opt.backup = false
opt.updatetime = 250
opt.timeoutlen = 300 -- 按键歧义等待缩短，路径更可预测
opt.ttimeoutlen = 20
opt.completeopt = { "menu", "menuone", "noselect" }
opt.confirm = true
opt.inccommand = "split" -- 替换实时预览，动手前能看到结果
opt.hidden = true
opt.jumpoptions = "view"
opt.sessionoptions = "buffers,curdir,folds,help,tabpages,winsize,globals"
opt.exrc = false -- 不执行项目内配置（安全，避免"状态被未知配置改变"）
opt.shada = { "'10", "<50", "s100", "h" }
opt.fileignorecase = true
opt.more = false
opt.virtualedit = "block"
opt.formatoptions:remove({ "c", "r", "o" })

local undodir = vim.fn.stdpath("state") .. "/undo"
if vim.fn.isdirectory(undodir) == 0 then
  vim.fn.mkdir(undodir, "p")
end
opt.undodir = undodir

-- ── 搜索 ─────────────────────────────────────────────
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true

-- ── 缩进 ─────────────────────────────────────────────
opt.expandtab = true
opt.shiftwidth = 4
opt.tabstop = 4
opt.softtabstop = 4
opt.autoindent = true
opt.smartindent = true
opt.breakindent = true

-- ── 剪贴板 ───────────────────────────────────────────
-- 本地终端用系统剪贴板；SSH 下自动走 OSC52（Windows Terminal / VSCode 终端均支持）
opt.clipboard = "unnamedplus"
if vim.env.SSH_TTY and vim.env.SSH_TTY ~= "" then
  local osc52 = require("vim.ui.clipboard.osc52")
  vim.g.clipboard = {
    name = "OSC 52",
    copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
    paste = { ["+"] = osc52.paste("+"), ["*"] = osc52.paste("*") },
  }
end

-- ── Python provider（molten / 远程插件用 devkit 独立 venv）──
do
  local data = vim.fn.stdpath("data")
  for _, p in ipairs({ data .. "/venv/bin/python3", data .. "/venv/bin/python" }) do
    if vim.fn.executable(p) == 1 then
      vim.g.python3_host_prog = p
      break
    end
  end
end
