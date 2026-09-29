-- PDF 阅读：优先文本提取（任何终端可用），支持时切图片模式（snacks.image）
local M = {}

local function repo_root()
  return require("nvim-devkit.paths").repo_root()
end

local function venv_python()
  for _, p in ipairs({
    vim.fn.stdpath("data") .. "/venv/bin/python3",
    vim.fn.stdpath("data") .. "/venv/bin/python",
  }) do
    if vim.fn.executable(p) == 1 then
      return p
    end
  end
  return vim.fn.exepath("python3")
end

local function extract(path, cb)
  if vim.fn.executable("pdftotext") == 1 then
    vim.system({ "pdftotext", "-layout", path, "-" }, { text = true }, function(obj)
      if obj.code == 0 then
        cb(obj.stdout or "", nil)
      else
        cb("", "pdftotext 失败: " .. (obj.stderr or "unknown"))
      end
    end)
  else
    local script = repo_root() .. "/scripts/pdf_extract.py"
    local py = venv_python()
    if py == "" then
      cb("", "没有可用的 PDF 提取器：请安装 pdftotext 或 python3")
      return
    end
    vim.system({ py, script, path }, { text = true }, function(obj)
      if obj.code == 0 then
        cb(obj.stdout or "", nil)
      else
        cb("", "PDF 提取失败: " .. (obj.stderr or "请检查 venv 中是否安装 pymupdf/pypdf"))
      end
    end)
  end
end

local function set_pdf_keymaps(buf, path)
  local map = function(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = buf, desc = desc, silent = true })
  end
  map("q", "<cmd>bd<CR>", "关闭 PDF")
  map("gr", function()
    M.open(path)
  end, "重新提取")
  map("]p", "/^──── 第 ", "下一页")
  map("[p", "?^──── 第 ", "上一页")
  map("<leader>rt", function()
    M.toggle_image(path)
  end, "切换图片模式")
end

local function image_supported()
  local caps = require("nvim-devkit.caps")
  if caps.effective_backend() ~= "kitty" then
    return false
  end
  local ok_snacks, snacks = pcall(require, "snacks")
  if not ok_snacks then
    return false
  end
  return caps.has_magick() and snacks.image.supports_terminal()
end

--- 以文本模式打开 PDF
function M.open(path)
  path = vim.fn.fnamemodify(path, ":p")
  local title = vim.fn.fnamemodify(path, ":t")
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.api.nvim_win_set_buf(0, buf)
  vim.bo[buf].filetype = "markdown"
  pcall(vim.api.nvim_buf_set_name, buf, ("%s [text]"):format(path))

  local hint = image_supported() and "  |  <leader>rt 图片模式" or ""
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    ("# %s"):format(title),
    "",
    ("提取中…%s"):format(hint),
  })
  vim.opt_local.modifiable = false

  extract(path, function(text, err)
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(buf) then
        return
      end
      if err and err ~= "" then
        vim.bo[buf].modifiable = true
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { ("# %s"):format(title), "", "⚠ " .. err })
        vim.opt_local.modifiable = false
        vim.notify(err, vim.log.levels.WARN)
        return
      end
      local pages = vim.split(text, "\f", { plain = true })
      local lines = { ("# %s"):format(title), "" }
      for i, page in ipairs(pages) do
        table.insert(lines, ("──── 第 %d 页 ────"):format(i))
        for _, l in ipairs(vim.split(page, "\n", { plain = true })) do
          table.insert(lines, l)
        end
        table.insert(lines, "")
      end
      vim.bo[buf].modifiable = true
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      vim.opt_local.modifiable = false
      vim.opt_local.foldenable = false
      set_pdf_keymaps(buf, path)
      vim.notify(("PDF 已转换：%s（%d 页）"):format(title, #pages), vim.log.levels.INFO)
    end)
  end)
end

--- 图片模式：交给 snacks.image（需 Kitty 协议终端 + ImageMagick）
function M.toggle_image(path)
  if not image_supported() then
    vim.notify(
      "当前终端不支持图片渲染（需要 kitty/ghostty/wezterm + ImageMagick），继续使用文本模式",
      vim.log.levels.WARN
    )
    return
  end
  vim.g.nvkit_pdf_raw = true
  vim.cmd("edit " .. vim.fn.fnameescape(path))
  vim.g.nvkit_pdf_raw = false
  vim.notify("图片模式：j/k 翻页，q 关闭（若空白说明该终端未启用图形协议穿透）", vim.log.levels.INFO)
end

return M
