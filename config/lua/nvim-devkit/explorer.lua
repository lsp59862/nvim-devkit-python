-- 文件浏览器（snacks explorer）的预览模式：
--   <A-p> 切换；开启后选中/点击文件即在"原窗口"预览（单一可复用 buffer，焦点留在文件树）
--   支持文本 / 图片 / PDF（图片/PDF 走查看器）；<CR> 在预览模式只预览、正常模式打开并清场。
--   预览 buffer（unlisted/nofile）在以下情况自动删除：关闭预览模式、正常打开文件、
--   文本预览被修改、父窗口关闭。
local M = {}

M.mode = false -- 预览模式开关（跨会话保持）
M.parent = nil -- 打开文件浏览器时的窗口
M.buf = nil -- 复用的预览 buffer
M.kind = nil -- "text" | "image" | "pdf"
M.picker = nil
M.updating = false

local PREVIEW_NAME = "nvkit://preview"

local IMAGE_EXT = { "png", "jpg", "jpeg", "webp", "gif", "bmp", "tif", "tiff" }

local function notify(msg)
  vim.notify("文件树预览: " .. msg, vim.log.levels.INFO)
end

local function valid_buf()
  return M.buf ~= nil and vim.api.nvim_buf_is_valid(M.buf)
end

--- 删除预览 buffer（结束预览/正常打开/被修改时调用）
function M.clear()
  local buf = M.buf
  M.buf = nil
  M.kind = nil
  if buf and vim.api.nvim_buf_is_valid(buf) then
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end
end

local function parent_win()
  if M.parent and vim.api.nvim_win_is_valid(M.parent) then
    return M.parent
  end
  M.parent = nil
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(win).relative == "" then
      M.parent = win
    end
  end
  return M.parent
end

local function classify(src)
  local ext = vim.fn.fnamemodify(src, ":e"):lower()
  if ext == "pdf" then
    return "pdf"
  end
  if vim.tbl_contains(IMAGE_EXT, ext) then
    return "image"
  end
  return "text"
end

local function new_buf(kind)
  local buf = vim.api.nvim_create_buf(false, false) -- unlisted，不污染 :ls / buffer 列表
  -- 注意：buftype=nofile 时 nvim 不维护 'modified'（BufModifiedSet 不会触发），
  -- 因此这里用普通 buftype（unlisted），以便"预览被修改 → 自动清理"可用
  vim.bo[buf].buftype = ""
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false
  pcall(vim.api.nvim_buf_set_name, buf, PREVIEW_NAME)
  vim.api.nvim_create_autocmd("BufModifiedSet", {
    buffer = buf,
    callback = function()
      -- 文本预览被用户修改 → 结束预览；图片/PDF 预览的临时写入（加载提示等）不算
      if M.kind == "text" and not M.updating then
        M.clear()
      end
    end,
  })
  if kind ~= "text" then
    vim.bo[buf].filetype = "image" -- 触发查看器 attach（键位/事件；初始渲染会因名字不可读而跳过）
  end
  M.buf = buf
  M.kind = kind
  return buf
end

local function show(src)
  local win = parent_win()
  if not win or vim.fn.filereadable(src) ~= 1 then
    return -- 目录 / 不可读：跳过
  end
  local kind = classify(src)
  if not (valid_buf() and M.kind == kind) then
    M.clear()
  end
  local buf = valid_buf() and M.buf or new_buf(kind)
  if kind == "text" then
    M.updating = true
    local ok, lines = pcall(vim.fn.readfile, src, "", 2000)
    if not ok then
      lines = { "（无法读取文件）" }
    end
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modified = false
    local ft = vim.filetype.match({ filename = src }) or "text"
    vim.bo[buf].filetype = ft
    M.updating = false
  else
    require("nvim-devkit.viewer").show(buf, src)
  end
  if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) ~= buf then
    vim.api.nvim_win_set_buf(win, buf) -- 换显示但不切焦点
  end
end

--- picker on_change：预览模式下选中项即预览
function M.on_change(_picker, item)
  if not M.mode then
    return
  end
  local path = item and (item.file or item.name)
  if type(path) ~= "string" or path == "" then
    return
  end
  show(vim.fs.normalize(path))
end

--- 切换预览模式
function M.toggle(picker)
  M.mode = not M.mode
  if M.mode then
    notify("预览模式开（<A-p> 关闭；<CR> 正常打开）")
    local cur = picker and picker:current()
    if cur then
      M.on_change(picker, cur)
    end
  else
    M.clear()
    notify("预览模式关")
  end
end

--- 打开文件浏览器（带预览模式支持）
function M.open(opts)
  M.parent = vim.api.nvim_get_current_win()
  local picker
  local function confirm()
    if M.mode then
      -- 预览模式：回车只预览，不打开、不关文件树
      local cur = picker and picker:current()
      if cur then
        M.on_change(picker, cur)
      end
      return
    end
    M.clear()
    if picker then
      picker:action("confirm")
    end
  end
  local merged = vim.tbl_deep_extend("force", opts or {}, {
    on_change = function(p, item)
      M.picker = p
      M.on_change(p, item)
    end,
    on_close = function()
      M.clear()
    end,
    win = {
      input = {
        keys = {
          ["<a-p>"] = { function()
            M.toggle(picker)
          end, mode = { "i", "n" } },
          ["<CR>"] = { function()
            confirm()
          end, mode = { "i", "n" } },
        },
      },
      list = {
        keys = {
          ["<a-p>"] = function()
            M.toggle(picker)
          end,
          ["<CR>"] = function()
            confirm()
          end,
          ["<2-LeftMouse>"] = function()
            confirm()
          end,
        },
      },
    },
  })
  picker = require("snacks").explorer(merged)
  return picker
end

-- 父窗口关闭 → 清场
vim.api.nvim_create_autocmd("WinClosed", {
  group = vim.api.nvim_create_augroup("nvim_devkit_explorer_preview", { clear = true }),
  callback = function(ev)
    if M.parent and tonumber(ev.match) == M.parent then
      M.clear()
      M.parent = nil
    end
  end,
})

return M
