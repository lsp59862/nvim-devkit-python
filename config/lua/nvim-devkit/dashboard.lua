-- 启动页（dashboard）自绘布局：带边框的双栏卡片
-- 左栏：会话提示 + 最近文件；右栏：快捷操作；底栏：启动耗时 + 提示。
-- 行由文本片段构成；按键/文件行带 action + key，回车与快捷键照常可用。
-- 宽度按 dashboard 窗口实时计算，窗口缩放后 snacks 触发重绘即可自适应。
local M = {}

local repo_path = require("nvim-devkit.paths").file

--- 快捷操作（内容与之前完全一致）
M.keys = {
  { icon = "", key = "e", desc = "文件树", action = ":lua require('nvim-devkit.explorer').open()" },
  { icon = "", key = "f", desc = "查找文件", action = ":lua Snacks.picker.smart()" },
  { icon = "", key = "g", desc = "全项目搜索", action = ":lua Snacks.picker.grep()" },
  { icon = "", key = "u", desc = "撤销树", action = ":UndotreeToggle" },
  { icon = "", key = "r", desc = "恢复会话", action = ":lua require('persistence').load()" },
  { icon = "", key = "q", desc = "退出 / 关当前 tab（同 :q）", action = ":q" },
  { icon = "", key = "?", desc = "快捷键大全", action = ":lua Snacks.picker.keymaps()" },
  { icon = "", key = "c", desc = "速查卡（救命键位）", action = ":e " .. repo_path("docs/CHEATSHEET.md") },
  { icon = "", key = "l", desc = "学习计划", action = ":e " .. repo_path("docs/LEARNING.md") },
}

local function sw(s)
  return vim.api.nvim_strwidth(s)
end

--- 右补空格到指定显示宽度（超宽则截断加 …）
local function pad(s, width)
  local w = sw(s)
  if w > width then
    local out = ""
    local used = 0
    for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
      local cw = sw(ch)
      if used + cw > width - 1 then
        break
      end
      out = out .. ch
      used = used + cw
    end
    return out .. "…"
  end
  return s .. (" "):rep(width - w)
end

local function chunks_width(chunks)
  local w = 0
  for _, c in ipairs(chunks) do
    w = w + sw(c[1] or "")
  end
  return w
end

--- 按显示宽度安全截断（不切坏 UTF-8）
local function truncate_to(s, width)
  local out, used = "", 0
  for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
    local w = sw(ch)
    if used + w > width then
      break
    end
    out = out .. ch
    used = used + w
  end
  return out, used
end

--- 把片段补齐/截断到固定宽度（保留高亮）
local function fit_chunks(chunks, width)
  local out = {}
  local used = 0
  for _, c in ipairs(chunks) do
    local text = c[1] or ""
    local cw = sw(text)
    if used + cw <= width then
      out[#out + 1] = c
      used = used + cw
    else
      local piece, pw = truncate_to(text, width - used)
      if pw > 0 then
        out[#out + 1] = { piece, c[2] }
        used = used + pw
      end
      break
    end
  end
  if used < width then
    out[#out + 1] = { (" "):rep(width - used) }
  end
  return out
end

local function border_line(ch)
  return { { ch, hl = "SnacksDashboardBorder" } }
end

--- 最近文件（cwd 内、最多 5 条、pathfmt 缩略）
local function recent_files(limit)
  limit = limit or 5
  local pf = require("nvim-devkit.pathfmt")
  local cwd = vim.fn.getcwd(0)
  local names, seen = {}, {}
  for _, f in ipairs(vim.v.oldfiles or {}) do
    if type(f) == "string" and f ~= "" then
      local abs = vim.fs.normalize(f)
      if not seen[abs] and vim.fn.filereadable(abs) == 1 and abs:find(cwd .. "/", 1, true) == 1 then
        seen[abs] = true
        names[#names + 1] = abs
        if #names >= limit then
          break
        end
      end
    end
  end
  local out = {}
  for i, abs in ipairs(names) do
    local siblings = {}
    for _, other in ipairs(names) do
      if other ~= abs then
        siblings[#siblings + 1] = other
      end
    end
    out[#out + 1] = {
      abs = abs,
      label = pf.short(abs, { cwd = cwd, width = 28, siblings = #siblings > 0 and siblings or nil }),
      idx = i,
    }
  end
  return out
end

local function startup_text()
  local ok, stats = pcall(function()
    return require("lazy.stats").stats()
  end)
  if not ok or not stats then
    return "⚡ 已就绪"
  end
  local ms = math.floor(stats.startuptime * 100 + 0.5) / 100
  return ("⚡ %sms · %d/%d 插件"):format(ms, stats.loaded, stats.count)
end

--- 独立的 dashboard 重排监听：
--- snacks 自带的 resize 钩子依赖实例记录的窗口，窗口被分割/复制（:sp、底部终端）时
--- 可能漏掉高度变化；这里按"当前实际显示 dashboard 的窗口"兜底重绘。
function M.watch()
  if M.watching then
    return
  end
  M.watching = true
  local function check()
    local inst = M.inst
    if not (inst and inst.buf and vim.api.nvim_buf_is_valid(inst.buf)) then
      M.inst = nil
      return
    end
    -- 目标窗口：当前窗口优先，否则第一个显示 dashboard 的窗口
    local cur = vim.api.nvim_get_current_win()
    local win
    if vim.api.nvim_win_is_valid(cur) and vim.api.nvim_win_get_buf(cur) == inst.buf then
      win = cur
    else
      local w = vim.fn.bufwinid(inst.buf)
      if w ~= -1 then
        win = w
      elseif vim.api.nvim_win_is_valid(inst.win or -1) then
        win = inst.win
      end
    end
    if not win then
      return
    end
    local width = vim.api.nvim_win_get_width(win)
    local height = vim.api.nvim_win_get_height(win)
    local last = M.last
    if last and last.win == win and last.width == width and last.height == height then
      return
    end
    inst.win = win
    M.last = { win = win, width = width, height = height }
    pcall(function()
      inst:update()
    end)
  end
  vim.api.nvim_create_autocmd(
    { "WinResized", "VimResized", "WinNew", "WinClosed", "WinEnter", "TabEnter" },
    {
      group = vim.api.nvim_create_augroup("nvkit_dashboard_resize", { clear = true }),
      callback = function()
        vim.schedule(function()
          pcall(check)
        end)
      end,
    }
  )
end

--- 生成整个 dashboard 的 items（两个等宽 pane，边框在中缝拼接）
---@param self any snacks dashboard 实例
---@return table[]
function M.section(self)
  M.inst = self
  M.watch()
  local win = self.win
  local win_w, win_h = 60, 24
  if win and vim.api.nvim_win_is_valid(win) then
    win_w = vim.api.nvim_win_get_width(win)
    win_h = vim.api.nvim_win_get_height(win)
  end
  -- 每个 pane 的宽度（含边框）：随窗口自适应（窄窗口也能完整显示边框）
  local W = math.floor((win_w - 2) / 2)
  W = math.max(18, math.min(42, W))
  self.opts.width = W
  self.opts.pane_gap = 0

  -- 垂直居中靠 buffer 顶部的空白行实现；snacks 重写 buffer 不会重置视图，
  -- 配合 scrolloff/光标定位可能停在滚动位置（看起来不居中）。
  -- 每次重排后把视图复位到第 1 行（在所有更新完成之后执行）。
  vim.schedule(function()
    if win and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == self.buf then
      pcall(vim.api.nvim_win_call, win, function()
        vim.fn.winrestview({ topline = 1, leftcol = 0 })
      end)
    end
  end)

  local L = W - 2 -- 左栏内容宽度（左竖线 + 内容 + 中缝竖线）
  local R = W - 1 -- 右栏内容宽度（内容 + 右竖线）

  -- 取足够多的候选（用于"还有 N 个"的准确计数），实际显示条数在下面统一裁剪
  local recents = recent_files(100)
  local rows = {} ---@type { left?: table[], right?: table[], lkey?: string, raction?: any, rkey?: string, laction?: any }[]

  local function add(left, right, opts)
    opts = opts or {}
    rows[#rows + 1] = {
      left = left,
      right = right,
      raw = opts.raw,
      lkey = opts.lkey,
      laction = opts.laction,
      rkey = opts.rkey,
      raction = opts.raction,
    }
  end

  -- 顶部边框
  add({ { "╭" .. ("─"):rep(L) .. "┬", hl = "SnacksDashboardBorder" } },
    { { ("─"):rep(R) .. "╮", hl = "SnacksDashboardBorder" } }, { raw = true })

  -- 最近文件：固定填满左侧
  -- 规则：≤8 条全列；>8 条则列 7 条 + 一行"（还有 N 个, 按 o 展开）"（左栏恰好占满）
  local avail = #M.keys
  local max_no_overflow = math.max(0, avail - 1)
  local shown, overflow = #recents, 0
  if #recents > max_no_overflow then
    shown = math.max(0, avail - 2)
    overflow = #recents - shown
  end
  local left_items = {
    { chunks = { { "最近文件", hl = "SnacksDashboardFooter" } } },
  }
  for i = 1, shown do
    local r = recents[i]
    left_items[#left_items + 1] = {
      chunks = {
        { ("%d "):format(i), hl = "SnacksDashboardKey" },
        { r.label, hl = "SnacksDashboardFile" },
      },
      key = tostring(i),
      action = ":e " .. vim.fn.fnameescape(r.abs),
    }
  end
  if overflow > 0 then
    left_items[#left_items + 1] = {
      chunks = {
        { "（还有 ", hl = "SnacksDashboardFooter" },
        { tostring(overflow), hl = "SnacksDashboardSession" },
        { " 个, 按 ", hl = "SnacksDashboardFooter" },
        { "o", hl = "SnacksDashboardKey" },
        { " 展开）", hl = "SnacksDashboardFooter" },
      },
      key = "o",
      action = ":lua Snacks.picker.recent()",
    }
  elseif #recents == 0 then
    left_items[#left_items + 1] = {
      chunks = { { "（暂无）", hl = "SnacksDashboardFooter" } },
    }
  end

  -- 右侧：快捷操作（内容不变）；有会话存档时在"恢复会话"后显示绿色 *
  local has_session = require("nvim-devkit.session").session_file() ~= nil
  local right_items = {}
  for i, k in ipairs(M.keys) do
    local chunks = {
      { (k.icon or "") .. " ", hl = "SnacksDashboardIcon" },
      { k.desc, hl = "SnacksDashboardDesc" },
    }
    if has_session and k.key == "r" then
      chunks[#chunks + 1] = { " *", hl = "SnacksDashboardSession" }
    end
    local used = chunks_width(chunks)
    local badge = ("[%s]"):format(k.key)
    chunks[#chunks + 1] = { (" "):rep(math.max(1, R - used - sw(badge) - 1)) }
    chunks[#chunks + 1] = { badge, hl = "SnacksDashboardKey" }
    chunks[#chunks + 1] = { " " }
    right_items[i] = {
      chunks = chunks,
      key = k.key,
      action = k.action,
    }
  end

  -- 左右按行合并（标题行与第一个快捷键同一行）
  local n = math.max(#left_items, #right_items)
  for i = 1, n do
    local left = left_items[i]
    local right = right_items[i]
    add(left and left.chunks, right and right.chunks, {
      lkey = left and left.key,
      laction = left and left.action,
      rkey = right and right.key,
      raction = right and right.action,
    })
  end

  -- 底部：分隔线 + 页脚（左：启动耗时；右：提示）
  add({ { "├" .. ("─"):rep(L) .. "┼", hl = "SnacksDashboardBorder" } },
    { { ("─"):rep(R) .. "┤", hl = "SnacksDashboardBorder" } }, { raw = true })
  add({
    { startup_text(), hl = "SnacksDashboardFooter" },
  }, {
    { "? 查看全部 · <C-g> 状态重置", hl = "SnacksDashboardFooter" },
  })
  -- 底部边框
  add({ { "╰" .. ("─"):rep(L) .. "┴", hl = "SnacksDashboardBorder" } },
    { { ("─"):rep(R) .. "╯", hl = "SnacksDashboardBorder" } }, { raw = true })

  -- 转成 dashboard items：左右 pane 各一行一条，宽度固定
  local items = {}
  for _, row in ipairs(rows) do
    local left_chunks = row.left or {}
    local right_chunks = row.right or {}
    local left_text, right_text
    if row.raw then
      left_text = left_chunks
      right_text = right_chunks
    else
      left_text = { { "│", hl = "SnacksDashboardBorder" } }
      vim.list_extend(left_text, fit_chunks(left_chunks, L))
      left_text[#left_text + 1] = { "│", hl = "SnacksDashboardBorder" }
      right_text = fit_chunks(right_chunks, R)
      right_text[#right_text + 1] = { "│", hl = "SnacksDashboardBorder" }
    end
    local left_item = { text = left_text }
    if row.lkey then
      left_item.key = row.lkey
    end
    if row.laction then
      left_item.action = row.laction
    end
    items[#items + 1] = left_item

    local right_item = { text = right_text, pane = 2 }
    if row.rkey then
      right_item.key = row.rkey
    end
    if row.raction then
      right_item.action = row.raction
    end
    items[#items + 1] = right_item
  end
  return items
end

return M
