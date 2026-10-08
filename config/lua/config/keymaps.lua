local map = vim.keymap.set
local recover = require("nvim-devkit.recover")

-- ── 恢复 / 防误触 ─────────────────────────────────────
map("n", "<C-g>", recover.panic, { desc = "恐慌重置：正常模式+关浮窗+停宏+清高亮" })
map("x", "<C-g>", recover.panic, { desc = "恐慌重置" })
map("i", "<C-g>", "<Esc>", { desc = "退出插入模式" })
map("c", "<C-g>", "<Esc>", { desc = "退出命令行" })
map("t", "<C-g>", [[<C-\><C-n>]], { desc = "退出终端模式" })
map("n", "<Esc>", "<cmd>nohlsearch<CR>", { desc = "清除搜索高亮" })
map("n", "Q", "<nop>", { desc = "已禁用（原 Ex 模式，防误触）" })

-- 撤销 / 时间旅行
map("n", "<leader>uE", function() recover.time_travel("earlier") end, { desc = "回退到 N 时间前（如 10m）" })
map("n", "<leader>uL", function() recover.time_travel("later") end, { desc = "前进到 N 时间后" })
map("n", "<leader>ur", "<cmd>edit<CR>", { desc = "重新加载当前文件" })
map("n", "<leader>uR", "<cmd>edit!<CR>", { desc = "强制重载（丢弃未保存修改）" })

-- 保存
map({ "n", "i", "v" }, "<C-s>", "<cmd>w<CR><Esc>", { desc = "保存" })
map("n", "<leader>fs", "<cmd>w<CR>", { desc = "保存" })

-- ── 行首 / 行末（Alt+1 / Alt+0，任何模式都不切换）──────
map({ "n", "x" }, "<M-1>", "^", { desc = "移到行首（首个非空白）" })
map({ "n", "x" }, "<M-0>", "$", { desc = "移到行末" })
map("i", "<M-1>", "<C-o>^", { desc = "移到行首（保持插入模式）" })
map("i", "<M-0>", "<C-o>$", { desc = "移到行末（保持插入模式）" })

-- ── 窗口（误按 <C-w> 后的恢复路径）────────────────────
map("n", "<C-h>", "<C-w>h", { desc = "左窗口" })
map("n", "<C-j>", "<C-w>j", { desc = "下窗口" })
map("n", "<C-k>", "<C-w>k", { desc = "上窗口" })
map("n", "<C-l>", "<C-w>l", { desc = "右窗口" })
map("n", "<leader>wo", "<C-w>o", { desc = "只保留当前窗口" })
map("n", "<leader>w=", "<C-w>=", { desc = "均分窗口" })
map("n", "<leader>wd", function()
  require("nvim-devkit.winbuf").close_window()
end, { desc = "关闭当前窗口（单窗口/dashboard 上会拒绝）" })

-- ── 标签页 ───────────────────────────────────────────
map("n", "<C-Tab>", "<cmd>tabnext<CR>", { desc = "下一个标签页" })
map("n", "<C-S-Tab>", "<cmd>tabprevious<CR>", { desc = "上一个标签页" })

-- ── Buffer ───────────────────────────────────────────
map("n", "<Tab>", "<cmd>bnext<CR>", { desc = "下一个 buffer" })
map("n", "<S-Tab>", "<cmd>bprevious<CR>", { desc = "上一个 buffer" })
map("n", "<leader>bd", function()
  require("nvim-devkit.winbuf").delete_buffer_and_windows()
end, { desc = "关闭文件+窗口（最后一个回启动页；只关文件用 :q）" })
map("n", "<leader>bo", function() require("snacks").bufdelete.other() end, { desc = "关闭其他 buffer" })

-- ── 文件 / 搜索（snacks picker）──────────────────────
map("n", "<leader>e", function() require("snacks").explorer() end, { desc = "文件树" })
map({ "n", "x" }, "<leader><space>", function() require("snacks").picker.smart() end, { desc = "智能查找文件" })
map("n", "<leader>ff", function() require("snacks").picker.files() end, { desc = "查找文件" })
map("n", "<leader>fg", function() require("snacks").picker.git_files() end, { desc = "查找 Git 文件" })
map("n", "<leader>fr", function() require("snacks").picker.recent() end, { desc = "最近文件" })
map("n", "<leader>fp", function() require("snacks").picker.projects() end, { desc = "项目列表" })
map("n", "<leader>,", function() require("snacks").picker.buffers() end, { desc = "Buffer 列表" })
map({ "n", "x" }, "<leader>/", function() require("snacks").picker.grep() end, { desc = "全项目搜索" })
map({ "n", "x" }, "<leader>sw", function() require("snacks").picker.grep_word() end, { desc = "搜索光标下单词" })
map("n", "<leader>sd", function() require("snacks").picker.diagnostics() end, { desc = "诊断列表" })
map("n", "<leader>sk", function() require("snacks").picker.keymaps() end, { desc = "快捷键大全" })
map("n", "<leader>sc", function() require("snacks").picker.commands() end, { desc = "命令列表" })
map("n", "<leader>sh", function() require("snacks").picker.help() end, { desc = "帮助文档" })

-- ── 会话（关错终端/重启后恢复现场；保存是退出时自动的）──
map("n", "<leader>qs", function() require("persistence").load() end, { desc = "恢复本目录会话" })
map("n", "<leader>ql", function() require("persistence").load({ last = true }) end, { desc = "恢复上次会话" })

local function session_autosave(enabled)
  local p = require("persistence")
  if enabled == p.active() then
    vim.notify(("会话自动保存已%s"):format(enabled and "开启" or "停止"), vim.log.levels.INFO, { title = "会话" })
    return
  end
  if enabled then
    if type(p.start) ~= "function" then
      vim.notify("当前 persistence 版本无法重新开启，请重启 nvim", vim.log.levels.WARN, { title = "会话" })
      return
    end
    p.start()
    vim.notify("会话自动保存已重新开启", vim.log.levels.INFO, { title = "会话" })
  else
    p.stop()
    vim.notify("会话自动保存已停止（<leader>qe 重新开启）", vim.log.levels.WARN, { title = "会话" })
  end
end
map("n", "<leader>qd", function() session_autosave(false) end, { desc = "停止会话自动保存（qe 可重新开启）" })
map("n", "<leader>qe", function() session_autosave(true) end, { desc = "重新开启会话自动保存" })

-- ── 回主页 ───────────────────────────────────────────
local function home()
  require("nvim-devkit.winbuf").open_dashboard()
end
map("n", "<leader>qh", home, { desc = "回到启动页" })
vim.api.nvim_create_user_command("NvkitHome", home, { desc = "打开启动页（dashboard，普通窗口）" })

-- ── Git ─────────────────────────────────────────────
map("n", "<leader>gg", function() require("snacks").lazygit() end, { desc = "Lazygit" })
map("n", "<leader>gB", function() require("snacks").gitbrowse() end, { desc = "浏览器打开" })

-- ── 终端 ─────────────────────────────────────────────
map({ "n", "t" }, "<C-/>", function() require("snacks").terminal() end, { desc = "浮动终端" })
map({ "n", "t" }, "<C-_>", function() require("snacks").terminal() end, { desc = "浮动终端（Ctrl+/ 别名）" })

-- ── 搜索跳转后保持上下文 ──────────────────────────────
map("n", "n", "nzzzv", { desc = "下一个匹配（居中）" })
map("n", "N", "Nzzzv", { desc = "上一个匹配（居中）" })
