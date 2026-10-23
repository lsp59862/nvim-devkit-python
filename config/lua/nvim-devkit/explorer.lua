-- 文件浏览器（snacks explorer）的预览模式：
--   <A-p> 切换；开启后 <CR> / l / 双击 在"原窗口"预览（单一可复用 buffer，焦点留在文件树）
--   支持文本 / 图片 / PDF（图片/PDF 走查看器）
--   <CR> 与 l 行为始终一致：目录 → 展开/折叠；文件 → 预览模式只预览、正常模式打开并清场。
--   预览 buffer（unlisted/nofile）在以下情况自动删除：关闭预览模式、正常打开文件、
--   文本预览被修改、父窗口关闭。
local M = {}

M.mode = false -- 预览模式开关（跨会话保持）
M.parent = nil -- 打开文件浏览器时的窗口
M.buf = nil -- 复用的预览 buffer
M.kind = nil -- "text" | "image" | "pdf"
M.picker = nil
M.updating = false
M.prev_buf = nil -- 预览前父窗口里的 buffer（删除预览 buffer 前先切回，避免窗口被关）

local PREVIEW_NAME = "nvkit://preview"
local TOGGLE_HL = "SnacksPickerToggleNvkitPreview"

-- 预览模式指示器文字颜色：跟随主题的 DiagnosticInfo（失败则用标题色兜底）
vim.api.nvim_set_hl(0, TOGGLE_HL, { link = "DiagnosticInfo" })

local IMAGE_EXT = { "png", "jpg", "jpeg", "webp", "gif", "bmp", "tif", "tiff" }

local function notify(msg)
  vim.notify("文件树预览: " .. msg, vim.log.levels.INFO)
end

local function valid_buf()
  return M.buf ~= nil and vim.api.nvim_buf_is_valid(M.buf)
end

--- 删除预览 buffer（结束预览/正常打开/被修改时调用）
--- 注意：nvim 的 :bdelete 会关闭显示该 buffer 的窗口（存在其它窗口时），
--- 因此先把父窗口切回原 buffer，再删除预览 buffer。
function M.clear()
  local buf = M.buf
  M.buf = nil
  M.kind = nil
  local win = M.parent
  if
    buf
    and vim.api.nvim_buf_is_valid(buf)
    and win
    and vim.api.nvim_win_is_valid(win)
    and vim.api.nvim_win_get_buf(win) == buf
  then
    local prev = M.prev_buf
    if prev and prev ~= buf and vim.api.nvim_buf_is_valid(prev) then
      pcall(vim.api.nvim_win_set_buf, win, prev)
    else
      vim.api.nvim_win_call(win, function()
        require("nvim-devkit.winbuf").open_dashboard()
      end)
    end
  end
  M.prev_buf = nil
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
      local ft = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
      if not ft:match("^snacks_") then -- 跳过文件树/选择器的布局窗口
        M.parent = win
      end
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
  -- 预览 buffer 不设置 ft=image：不安装查看器的键位/事件钩子（避免与文件树浮窗的
  -- 窗口/autocmd 生命周期相互干扰）；图片由 viewer.show 直接渲染
  if kind == "text" then
    vim.bo[buf].filetype = "text"
  end
  vim.b[buf].nvkit_preview = true -- 让查看器知道这是预览 buffer（文件树浮窗属预期）
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf,
    once = true,
    callback = function()
      if M.buf == buf then
        M.buf = nil
        M.kind = nil
        M.prev_buf = nil
      end
    end,
  })
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
  end
  if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) ~= buf then
    local cur = vim.api.nvim_win_get_buf(win)
    if cur ~= buf and vim.api.nvim_buf_is_valid(cur) then
      M.prev_buf = M.prev_buf or cur -- 记录预览前的 buffer 供 clear 恢复
    end
    vim.api.nvim_win_set_buf(win, buf) -- 换显示但不切焦点
  end
  if kind ~= "text" then
    -- 图片/PDF：先让预览 buffer 显示在窗口里，再渲染（查看器按窗口定位）
    local ok, err = pcall(function()
      require("nvim-devkit.viewer").show(buf, src)
    end)
    if not ok then
      M.clear()
      vim.notify("文件树预览: 渲染失败 " .. tostring(err), vim.log.levels.WARN)
    end
  end
end

--- 选中项变化：不自动预览（移动不渲染，避免快速滚动卡顿）。
--- 预览由 <CR>/双击（preview_item）显式触发。
function M.on_change(_picker, _item)
  return
end

--- 显式预览某一项（<CR>/双击、或开启预览模式时）；延后合并、避免在 picker 节流回调里做重活
function M.preview_item(_picker, item)
  if not M.mode then
    return
  end
  local path = item and (item.file or item.name)
  if type(path) ~= "string" or path == "" then
    return
  end
  M.token = (M.token or 0) + 1
  local token = M.token
  vim.defer_fn(function()
    if M.token ~= token or not M.mode then
      return
    end
    if not parent_win() then
      if not M.warned then
        M.warned = true
        vim.notify("文件树预览: 预览窗口已关闭，重新打开文件树（<leader>e）后继续", vim.log.levels.WARN)
      end
      return
    end
    M.warned = false
    local ok, err = pcall(show, vim.fs.normalize(path))
    if not ok then
      M.clear()
      vim.notify("文件树预览: " .. tostring(err), vim.log.levels.WARN)
    end
  end, 40)
end

--- 确认键统一行为（<CR> / l / 双击）：
--- 目录 → 总是展开/折叠（与预览模式无关）；文件 → 预览模式只预览，正常模式打开并清场
function M.confirm(picker)
  local cur = picker and picker:current()
  if not cur then
    return
  end
  if cur.dir then
    picker:action("confirm")
    return
  end
  if M.mode then
    M.preview_item(picker, cur)
    return
  end
  M.clear()
  picker:action("confirm")
end

--- 切换预览模式
local function update_indicator(picker)
  if not (picker and picker.opts) then
    return
  end
  picker.opts.nvkit_preview = M.mode
  if type(picker.update_titles) == "function" then
    pcall(picker.update_titles, picker)
  end
end

function M.toggle(picker)
  M.mode = not M.mode
  update_indicator(picker)
  if M.mode then
    notify("预览模式开（<A-p> 关闭；<CR> 预览选中项）")
    local cur = picker and picker:current()
    if cur then
      M.preview_item(picker, cur)
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
    M.confirm(picker)
  end
  local merged = vim.tbl_deep_extend("force", opts or {}, {
    -- 预览模式指示器：显示在标题栏 {flags} 处（有颜色，且带图标与文字）
    toggles = {
      nvkit_preview = { icon = "󰈈 预览中", value = true },
    },
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
          ["l"] = function()
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
  update_indicator(picker)
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
