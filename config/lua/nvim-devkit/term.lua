-- 终端管理：统一 <leader>t*（浮动 / 底部 / 列表），opencode 面板独立于 <leader>ot
--
-- snacks.terminal 以 cmd + cwd + 编号(count) 区分实例，全部终端共享同一张列表
-- （浮动 / 底部 / opencode 面板都在里面）：
--   · 数字前缀操作指定编号（如 2tt）；tt / tb 不带前缀时开关各自"最近使用"的那台
--   · 隐藏（q）不杀进程，列表里可切回；kill 才真正结束进程
--   · <M-j>/<M-k> 在共享列表里循环切换（含 opencode 面板）
local M = {}

M.FLOAT = { position = "float", width = 0.8, height = 0.8, border = "rounded" }
M.BOTTOM = { position = "bottom", height = 0.3 }

local last = { float = nil, bottom = nil }

local function term_list()
  return require("snacks.terminal").list()
end

--- 当前存活终端，按编号排序
function M.entries()
  local out = {}
  for _, t in ipairs(term_list()) do
    local info = vim.b[t.buf].snacks_terminal or {}
    out[#out + 1] = {
      id = info.id or 1,
      cmd = info.cmd,
      cwd = info.cwd or "",
      title = vim.b[t.buf].term_title or "",
      buf = t.buf,
    }
  end
  table.sort(out, function(a, b)
    return a.id < b.id
  end)
  return out
end

--- 最小空闲编号（新建终端用）
function M.next_count()
  local used = {}
  for _, e in ipairs(M.entries()) do
    used[e.id] = true
  end
  local i = 1
  while used[i] do
    i = i + 1
  end
  return i
end

local function slot_alive(id)
  if id == nil then
    return false
  end
  for _, e in ipairs(M.entries()) do
    if e.id == id then
      return true
    end
  end
  return false
end

local function term_kind(t)
  return vim.b[t.buf].nvkit_term_kind
end

--- 同类终端是否正在显示（浮动含外部浮窗；底部只认本模块创建的）
local function is_kind(t, kind)
  if kind == "float" then
    return t:is_floating() or (t:valid() and term_kind(t) == "float")
  end
  return t:valid() and not t:is_floating() and term_kind(t) == "bottom"
end

local function visible_of_kind(kind)
  local out = {}
  for _, t in ipairs(term_list()) do
    if is_kind(t, kind) then
      out[#out + 1] = t
    end
  end
  return out
end

--- 同类互斥：显示某台时隐藏其它同类，避免多个浮窗/底部分屏同时占屏
local function hide_others(kind, keep_buf)
  for _, t in ipairs(visible_of_kind(kind)) do
    if t.buf ~= keep_buf then
      t:hide()
    end
  end
end

--- 不带编号时开关"当前可见"的同类终端（没有则唤回最近的/新建）；
--- 带编号则精确操作指定槽位
local function toggle_slot(kind, count)
  if count == nil then
    local vis = visible_of_kind(kind)
    if #vis > 0 then
      for _, t in ipairs(vis) do
        t:hide()
      end
      return
    end
    if not slot_alive(last[kind]) then
      last[kind] = M.next_count()
    end
    count = last[kind]
  end
  last[kind] = count
  local snacks_term = require("snacks.terminal")
  local win = kind == "float" and M.FLOAT or M.BOTTOM
  snacks_term.toggle(nil, { count = count, win = vim.deepcopy(win) })
  local t = snacks_term.get(nil, { count = count, win = vim.deepcopy(win) })
  if t then
    vim.b[t.buf].nvkit_term_kind = kind
    hide_others(kind, t.buf)
  end
end

function M.open_float(count)
  toggle_slot("float", count)
end

function M.open_bottom(count)
  toggle_slot("bottom", count)
end

--- 聚焦某编号终端；已在其中则隐藏（列表 Enter 用）
function M.focus(count)
  local cur = vim.api.nvim_get_current_buf()
  for _, t in ipairs(term_list()) do
    local info = vim.b[t.buf].snacks_terminal or {}
    if (info.id or 1) == count then
      if t:valid() and cur == t.buf then
        t:hide()
        return true
      end
      return M.show(count)
    end
  end
  return false
end

--- 显示并聚焦（不隐藏当前，循环切换用；同类互斥）
function M.show(count)
  for _, t in ipairs(term_list()) do
    local info = vim.b[t.buf].snacks_terminal or {}
    if (info.id or 1) == count then
      local kind = term_kind(t) or (t:is_floating() and "float" or nil)
      if kind then
        hide_others(kind, t.buf)
      end
      t:show():focus()
      return true
    end
  end
  return false
end

--- 共享列表里循环切换；delta=1 下一个 / -1 上一个（含 opencode 面板）
function M.cycle(delta)
  local entries = M.entries()
  if #entries == 0 then
    M.open_float()
    return
  end
  local cur = vim.api.nvim_get_current_buf()
  local idx
  for i, e in ipairs(entries) do
    if e.buf == cur then
      idx = i
      break
    end
  end
  if idx == nil then
    idx = delta > 0 and 1 or #entries
  else
    idx = ((idx - 1 + delta) % #entries) + 1
  end
  M.show(entries[idx].id)
end

--- 真正结束进程（wipe buffer → SIGHUP）
function M.kill(count)
  for _, t in ipairs(term_list()) do
    local info = vim.b[t.buf].snacks_terminal or {}
    if (info.id or 1) == count and t.buf and vim.api.nvim_buf_is_valid(t.buf) then
      vim.api.nvim_buf_delete(t.buf, { force = true })
      return true
    end
  end
  return false
end

local function label(e)
  local name = e.cmd
  if type(name) == "table" then
    name = table.concat(name, " ")
  end
  name = name or vim.fn.fnamemodify(vim.o.shell, ":t")
  local cwd = vim.fn.fnamemodify(e.cwd ~= "" and e.cwd or vim.fn.getcwd(), ":~")
  -- nvim 的 term_title 形如 term://cwd//pid:/bin/bash → 去掉前缀噪声
  local title = e.title:gsub("^term://.-//%d+:", "")
  -- 标题与命令名重复时不再显示（如 shell 的 /bin/bash vs bash）
  if title == "" or name:find(title, 1, true) or title:find(name, 1, true) then
    title = ""
  end
  return ("%d: %s  %s%s"):format(e.id, name, cwd, title ~= "" and ("  " .. title) or "")
end

function M.items()
  local out = {}
  for _, e in ipairs(M.entries()) do
    out[#out + 1] = { text = label(e), id = e.id }
  end
  return out
end

function M.picker()
  require("snacks.picker").pick({
    title = "终端",
    format = "text", -- 默认 file formatter 只认 item.file，会让只有 text 的条目显示成空白
    items = M.items(),
    confirm = function(_, item)
      M.focus(item.id)
    end,
    actions = {
      term_kill = function(picker, item)
        if item and M.kill(item.id) then
          picker:close()
        end
      end,
      term_new = function(picker)
        picker:close()
        M.open_float(M.next_count())
      end,
    },
    win = {
      list = {
        keys = {
          ["<C-d>"] = "term_kill",
          ["<C-n>"] = "term_new",
        },
      },
    },
  })
end

return M
