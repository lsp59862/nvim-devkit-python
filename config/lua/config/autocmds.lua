local aug = vim.api.nvim_create_augroup("nvim_devkit", { clear = true })

-- 注册 :NvkitSplits（分屏增强开关，默认不启用任何效果）
require("nvim-devkit.theme")
-- 注册 :q/:wq/:x 的"只关文件、布局不动"语义
require("nvim-devkit.winbuf").setup()

-- 复制高亮
vim.api.nvim_create_autocmd("TextYankPost", {
  group = aug,
  callback = function()
    vim.hl.on_yank({ timeout = 200 })
  end,
})

-- 回到上次编辑位置
vim.api.nvim_create_autocmd("BufReadPost", {
  group = aug,
  callback = function()
    local ft = vim.bo.filetype
    if vim.tbl_contains({ "gitcommit", "COMMIT_EDITMSG" }, ft) then
      return
    end
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- 外部修改自动重载（opencode 编辑文件后实时进 buffer）
vim.api.nvim_create_autocmd({ "FocusGained", "TermClose", "TermLeave" }, {
  group = aug,
  command = "checktime",
})

-- Markdown / gitcommit：折行 + 拼写（只用自带 en，避免触发拼写文件下载提示）
vim.api.nvim_create_autocmd("FileType", {
  group = aug,
  pattern = { "markdown", "text", "gitcommit" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.spell = true
    pcall(vim.opt_local.spelllang, { "en" })
  end,
})

-- 大文件保护（snacks.bigfile 由 snacks 自动处理，这里兜底关闭高亮类功能）
vim.api.nvim_create_autocmd("BufReadPre", {
  group = aug,
  callback = function(args)
    local ok, stats = pcall(vim.uv.fs_stat, args.file)
    if ok and stats and stats.size > 2 * 1024 * 1024 then
      vim.b[args.buf].bigfile = true
    end
  end,
})

-- CSV/TSV 表格视图（插件懒加载后自动生效）
vim.api.nvim_create_autocmd("FileType", {
  group = aug,
  pattern = { "csv", "tsv" },
  callback = function()
    local ok, csv = pcall(require, "csvview")
    if ok then
      csv.enable()
    end
  end,
})

-- PDF 拦截：Kitty 协议终端默认按页看图（snacks.image 接管），否则转文本阅读
vim.api.nvim_create_autocmd("BufReadCmd", {
  group = aug,
  pattern = "*.pdf",
  callback = function(args)
    if vim.g.nvkit_pdf_raw then
      return
    end
    local pdf = require("nvim-devkit.pdf")
    if pdf.image_supported() then
      pdf.image_hint() -- 让 snacks.image 的 BufReadCmd 渲染；本 handler 直接放行
      return
    end
    pdf.open(args.file)
  end,
})

-- 图片 / PDF 图片模式的查看器键位（ft=image 由 snacks.image 设置）
vim.api.nvim_create_autocmd("FileType", {
  group = aug,
  pattern = "image",
  callback = function(args)
    require("nvim-devkit.viewer").attach(args.buf)
  end,
})
