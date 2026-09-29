local aug = vim.api.nvim_create_augroup("nvim_devkit", { clear = true })

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

-- PDF 拦截：转文本阅读（BufReadCmd 在读取二进制前接管）
vim.api.nvim_create_autocmd("BufReadCmd", {
  group = aug,
  pattern = "*.pdf",
  callback = function(args)
    if vim.g.nvkit_pdf_raw then
      return
    end
    require("nvim-devkit.pdf").open(args.file)
  end,
})
