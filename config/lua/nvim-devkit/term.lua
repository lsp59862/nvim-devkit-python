-- 终端面板（VS Code 式）：浮动 / 底部 各一个面板 = 侧边栏 + 终端区
--
--  · <leader>tp / <leader>tb：呼出/收起对应面板；没有终端时自动创建一台
--  · <leader>tl：终端列表（[浮]/[底]/[面板]，可切换、<C-d> 杀进程）
--  · 终端模式 <M-j>/<M-k>：按列表顺序向下/向上循环（只在本面板内）；
--    <M-n>：新建同类终端；<M-r>：重命名当前终端
--  · 侧边栏显示名字（shell 简名 + 创建序号，重命名后显示自定义名）并高亮当前；
--    鼠标点击 / <CR> 切换，q 收起
--  · 浮动面板从屏幕底部滑入、向底部滑出；opencode 面板不归此模块管（<leader>ot）
local M = {}

local uv = vim.uv or vim.loop

local FLOAT_RATIO = { w = 0.8, h = 0.8 }
local BOTTOM_RATIO = 0.3
local SIDE_MIN, SIDE_MAX = 12, 20
local SLIDE_STEPS, SLIDE_MS = 14, 22
local CURRENT_HL = "NvkitTermCurrent"
local NS = vim.api.nvim_create_namespace("nvkit_term_side")

---@class DevkitTerm
---@field id integer
---@field idx integer       -- 同类内创建序号（稳定，不因删除而重排）
---@field kind "float"|"bottom"
---@field buf integer
---@field job integer
---@field name string        -- 程序简名（如 bash）
---@field label? string      -- 用户重命名后的名字

local terms = {} ---@type DevkitTerm[]
local id_seq = 1
local kind_seq = { float = 0, bottom = 0 }
local esc_timers = {}
local slide_token = { float = 0 }

local panel = {
  float = { visible = false, win = nil, side = nil, cur = nil, closing = false },
  bottom = { visible = false, win = nil, side = nil, cur = nil, closing = false },
}
local side_buffers = { float = nil, bottom = nil }

-- 浮动窗口几何工具（定义在后，前端引用）
local read_geom, set_float_wins

local function is_win(w)
  return w ~= nil and vim.api.nvim_win_is_valid(w)
end

local function in_current_tab(w)
  return is_win(w) and vim.api.nvim_win_get_tabpage(w) == vim.api.nvim_get_current_tabpage()
end

local function get(id)
  for _, t in ipairs(terms) do
    if t.id == id then
      return t
    end
  end
end

local function term_of_buf(buf)
  for _, t in ipairs(terms) do
    if t.buf == buf then
      return t
    end
  end
end

local function name_of(t)
  return t.label or (t.name .. " " .. t.idx)
end

local function side_width()
  return math.min(SIDE_MAX, math.max(SIDE_MIN, math.floor(vim.o.columns * 0.16)))
end

local function float_geom()
  local cols, lines = vim.o.columns, vim.o.lines
  local h = math.max(10, math.floor(lines * FLOAT_RATIO.h))
  local w = math.max(30, math.floor(cols * FLOAT_RATIO.w) - side_width())
  local sw = side_width()
  -- 两个浮窗都带圆角边框：侧边栏外宽 sw+2，主窗 col 偏移 sw+2
  local total = sw + w + 4
  local col = math.max(0, math.floor((cols - total) / 2))
  local row = math.max(0, math.floor((lines - h) / 2) - 1)
  return { row = row, col = col, h = h, w = w, sw = sw }
end

-- ── 查询接口（测试与列表共用）──────────────────────────

function M.terms(kind)
  if not kind then
    return vim.deepcopy(terms)
  end
  local out = {}
  for _, t in ipairs(terms) do
    if t.kind == kind then
      out[#out + 1] = t
    end
  end
  return out
end

function M.count(kind)
  return #M.terms(kind)
end

function M.visible(kind)
  return in_current_tab(panel[kind].win)
end

function M.cur(kind)
  return panel[kind].cur
end

function M.main_win(kind)
  return panel[kind].win
end

function M.side_win(kind)
  return panel[kind].side
end

function M.side_buf(kind)
  return side_buffers[kind]
end

function M.name_of(id)
  local t = get(id)
  return t and name_of(t) or nil
end

function M.current_kind()
  local t = term_of_buf(vim.api.nvim_get_current_buf())
  return t and t.kind or nil
end

-- ── 终端进程 ─────────────────────────────────────────

local function setup_term_buffer(t)
  local buf = t.buf
  vim.keymap.set("n", "q", function()
    M.hide(t.kind)
  end, { buffer = buf, desc = "收起终端面板" })
  local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
  vim.keymap.set("t", "<Esc>", function()
    local timer = esc_timers[buf]
    if timer and timer:is_active() then
      timer:stop()
      vim.cmd("stopinsert")
      return ""
    end
    esc_timers[buf] = esc_timers[buf] or uv.new_timer()
    esc_timers[buf]:start(200, 0, function() end)
    return esc
  end, { buffer = buf, expr = true, desc = "双击 Esc 进入普通模式" })
end

--- 新建一台终端（默认浮动）；返回实例
--- termopen 只能作用于当前 buffer：在临时浮窗里开好再关窗，终端藏进隐藏 buffer
function M.create(kind)
  kind = kind or "float"
  local buf = vim.api.nvim_create_buf(false, false)
  local tmp = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    style = "minimal",
    width = 1,
    height = 1,
    row = 0,
    col = 0,
  })
  local job = vim.fn.termopen(vim.o.shell, {
    cwd = vim.fn.getcwd(),
    on_exit = function()
      vim.schedule(function()
        M.remove(buf)
      end)
    end,
  })
  if vim.api.nvim_win_is_valid(tmp) then
    pcall(vim.api.nvim_win_close, tmp, true)
  end
  if job <= 0 then
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
    return nil
  end
  vim.bo[buf].bufhidden = "hide"
  kind_seq[kind] = kind_seq[kind] + 1
  local t = {
    id = id_seq,
    idx = kind_seq[kind],
    kind = kind,
    buf = buf,
    job = job,
    name = vim.fn.fnamemodify(vim.o.shell, ":t"),
  }
  id_seq = id_seq + 1
  terms[#terms + 1] = t
  setup_term_buffer(t)
  if panel[kind].cur == nil then
    panel[kind].cur = t.id
  end
  return t
end

--- 从注册表移除（进程退出或 kill 共用）
function M.remove(buf, delete_buf)
  local idx
  for i, t in ipairs(terms) do
    if t.buf == buf then
      idx = i
      break
    end
  end
  if not idx then
    return
  end
  local t = table.remove(terms, idx)
  esc_timers[buf] = nil
  local p = panel[t.kind]
  if p.cur == t.id then
    local list = M.terms(t.kind)
    p.cur = list[1] and list[1].id or nil
    if in_current_tab(p.win) then
      if p.cur then
        vim.api.nvim_win_set_buf(p.win, get(p.cur).buf)
      end
    end
  end
  if p.cur == nil then
    M.hide(t.kind, true)
  else
    M.refresh(t.kind)
  end
  if delete_buf and vim.api.nvim_buf_is_valid(buf) then
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end
end

--- 真正结束进程并移除
function M.kill(id)
  local t = get(id)
  if not t then
    return false
  end
  if t.job and t.job > 0 then
    pcall(vim.fn.jobstop, t.job)
  end
  M.remove(t.buf, true)
  return true
end

--- <M-r>：重命名当前终端
function M.rename_current()
  local t = term_of_buf(vim.api.nvim_get_current_buf())
  if not t then
    return
  end
  vim.ui.input({ prompt = "终端名称: ", default = name_of(t) }, function(input)
    if input == nil then
      return
    end
    input = vim.trim(input)
    t.label = input ~= "" and input or nil
    M.refresh(t.kind)
    local p = panel[t.kind]
    if in_current_tab(p.win) and p.cur == t.id and t.kind == "float" then
      local g = read_geom()
      set_float_wins(g, g.row, name_of(t))
    end
    vim.schedule(function()
      if in_current_tab(p.win) and vim.api.nvim_get_current_win() == p.win then
        vim.cmd("startinsert")
      end
    end)
  end)
end

-- ── 侧边栏 ───────────────────────────────────────────

function M.refresh(kind)
  local buf = side_buffers[kind]
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end
  local p = panel[kind]
  local lines, hl = {}, nil
  for i, t in ipairs(M.terms(kind)) do
    lines[i] = ("%s%s"):format(t.id == p.cur and "▸ " or "  ", name_of(t))
    if t.id == p.cur then
      hl = i
    end
  end
  if #lines == 0 then
    lines = { "  (无终端)" }
  end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(buf, NS, 0, -1)
  if hl then
    vim.api.nvim_set_hl(0, CURRENT_HL, { link = "PmenuSel", default = true })
    vim.api.nvim_buf_add_highlight(buf, NS, CURRENT_HL, hl - 1, 0, -1)
  end
end

local function ensure_side_buf(kind)
  local buf = side_buffers[kind]
  if buf and vim.api.nvim_buf_is_valid(buf) then
    return buf
  end
  buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].modifiable = false
  vim.bo[buf].buftype = "nofile"
  local function pick_at(line)
    local t = M.terms(kind)[line]
    if t then
      M.select(kind, t.id)
    end
  end
  vim.keymap.set("n", "<CR>", function()
    pick_at(vim.api.nvim_win_get_cursor(0)[1])
  end, { buffer = buf, desc = "切换到该终端" })
  vim.keymap.set("n", "<LeftMouse>", function()
    local pos = vim.fn.getmousepos()
    if pos.winid and vim.api.nvim_win_get_buf(pos.winid) == buf and pos.line > 0 then
      pick_at(pos.line)
    end
  end, { buffer = buf, desc = "鼠标点击切换终端" })
  vim.keymap.set("n", "q", function()
    M.hide(kind)
  end, { buffer = buf, desc = "收起终端面板" })
  side_buffers[kind] = buf
  return buf
end

local function setup_side_win(win)
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].foldcolumn = "0"
  vim.wo[win].wrap = false
  vim.wo[win].cursorline = false
  vim.wo[win].winfixwidth = true
  vim.wo[win].list = false
  vim.wo[win].spell = false
end

-- ── 面板窗口 ─────────────────────────────────────────

local function watch(win, kind)
  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(win),
    once = true,
    callback = function()
      vim.schedule(function()
        local p = panel[kind]
        if p.closing then
          return
        end
        if p.win == win or p.side == win then
          if is_win(p.win) then
            pcall(vim.api.nvim_win_close, p.win, true)
          end
          if is_win(p.side) then
            pcall(vim.api.nvim_win_close, p.side, true)
          end
          p.win, p.side, p.visible = nil, nil, false
        end
      end)
    end,
  })
end

--- 读取当前浮窗几何（不变量：两个浮窗仍在）；供平移/标题更新全量重配
read_geom = function()
  local p = panel.float
  if not (is_win(p.win) and is_win(p.side)) then
    return float_geom()
  end
  local wc = vim.api.nvim_win_get_config(p.win)
  local sc = vim.api.nvim_win_get_config(p.side)
  return { row = wc.row, col = sc.col, h = wc.height, w = wc.width, sw = sc.width }
end

set_float_wins = function(g, row, title)
  local p = panel.float
  if is_win(p.side) then
    pcall(vim.api.nvim_win_set_config, p.side, {
      relative = "editor",
      style = "minimal",
      width = g.sw,
      height = g.h,
      row = row,
      col = g.col,
      border = "rounded",
    })
  end
  if is_win(p.win) then
    pcall(vim.api.nvim_win_set_config, p.win, {
      relative = "editor",
      style = "minimal",
      width = g.w,
      height = g.h,
      row = row,
      col = g.col + g.sw + 2,
      border = "rounded",
      title = title and (" " .. title .. " ") or nil,
      title_pos = "center",
    })
  end
end

--- 浮动面板平移（滑入/滑出）；ease-out 让进入更柔和
local function slide(g, title, row_from, row_to, done)
  slide_token.float = slide_token.float + 1
  local token = slide_token.float
  local function step(i)
    if token ~= slide_token.float then
      return
    end
    local t = i / SLIDE_STEPS
    local eased = 1 - (1 - t) * (1 - t)
    set_float_wins(g, math.floor(row_from + (row_to - row_from) * eased + 0.5), title)
    if i < SLIDE_STEPS then
      vim.defer_fn(function()
        step(i + 1)
      end, SLIDE_MS)
    elseif done then
      done()
    end
  end
  step(1)
end

--- 收起面板；soft=true 时不播放动画（终端被清空）
function M.hide(kind, soft)
  local p = panel[kind]
  if not p.visible and not is_win(p.win) and not is_win(p.side) then
    return
  end
  p.closing = true
  local function close_all()
    for _, w in ipairs({ p.side, p.win }) do
      if is_win(w) then
        pcall(vim.api.nvim_win_close, w, true)
      end
    end
    p.win, p.side, p.visible, p.closing = nil, nil, false, false
  end
  if kind == "float" and not soft and in_current_tab(p.win) then
    local g = read_geom()
    slide(g, M.name_of(p.cur), g.row, vim.o.lines, close_all)
  else
    close_all()
  end
end

local function show_float()
  local p = panel.float
  if M.count("float") == 0 then
    M.create("float")
  end
  if in_current_tab(p.win) then
    vim.api.nvim_set_current_win(p.win)
    vim.cmd("startinsert")
    return
  end
  if is_win(p.win) then
    pcall(vim.api.nvim_win_close, p.win, true)
  end
  if is_win(p.side) then
    pcall(vim.api.nvim_win_close, p.side, true)
  end

  local cur = get(p.cur) or M.terms("float")[1]
  p.cur = cur.id
  local g = float_geom()
  local start_row = vim.o.lines -- 从屏幕底部滑入
  p.side = vim.api.nvim_open_win(ensure_side_buf("float"), false, {
    relative = "editor",
    style = "minimal",
    width = g.sw,
    height = g.h,
    row = start_row,
    col = g.col,
    border = "rounded",
    zindex = 45,
  })
  vim.w[p.side].nvkit_no_dim = true
  vim.wo[p.side].winhighlight = ""
  p.win = vim.api.nvim_open_win(cur.buf, true, {
    relative = "editor",
    style = "minimal",
    width = g.w,
    height = g.h,
    row = start_row,
    col = g.col + g.sw + 2,
    border = "rounded",
    title = " " .. name_of(cur) .. " ",
    title_pos = "center",
    zindex = 50,
  })
  p.visible = true
  watch(p.win, "float")
  watch(p.side, "float")
  M.refresh("float")
  slide(g, name_of(cur), start_row, g.row)
  vim.cmd("startinsert")
end

local function show_bottom()
  local p = panel.bottom
  if M.count("bottom") == 0 then
    M.create("bottom")
  end
  if in_current_tab(p.win) then
    vim.api.nvim_set_current_win(p.win)
    vim.cmd("startinsert")
    return
  end
  if is_win(p.win) then
    pcall(vim.api.nvim_win_close, p.win, true)
  end
  if is_win(p.side) then
    pcall(vim.api.nvim_win_close, p.side, true)
  end

  local cur = get(p.cur) or M.terms("bottom")[1]
  p.cur = cur.id
  vim.cmd("botright split")
  p.win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_height(p.win, math.max(5, math.floor(vim.o.lines * BOTTOM_RATIO)))
  vim.cmd("leftabove vsplit")
  p.side = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_width(p.side, side_width())
  setup_side_win(p.side)
  vim.api.nvim_win_set_buf(p.side, ensure_side_buf("bottom"))
  vim.w[p.side].nvkit_no_dim = true
  vim.wo[p.side].winhighlight = ""
  vim.api.nvim_win_set_buf(p.win, cur.buf)
  vim.wo[p.win].winbar = ""
  p.visible = true
  watch(p.win, "bottom")
  watch(p.side, "bottom")
  M.refresh("bottom")
  vim.api.nvim_set_current_win(p.win)
  vim.cmd("startinsert")
end

--- 呼出/收起面板；没有终端时自动创建
function M.summon(kind)
  if in_current_tab(panel[kind].win) then
    M.hide(kind)
  elseif kind == "float" then
    show_float()
  else
    show_bottom()
  end
end

--- 在面板中切换到某终端（自动确保面板可见）
function M.select(kind, id)
  local t = get(id)
  if not t or t.kind ~= kind then
    return
  end
  panel[kind].cur = id
  if not in_current_tab(panel[kind].win) then
    if kind == "float" then
      show_float()
    else
      show_bottom()
    end
    return
  end
  local p = panel[kind]
  vim.api.nvim_win_set_buf(p.win, t.buf)
  if kind == "float" then
    local g = read_geom()
    set_float_wins(g, g.row, name_of(t))
  end
  M.refresh(kind)
  vim.api.nvim_set_current_win(p.win)
  vim.cmd("startinsert")
end

--- 当前面板内按列表顺序循环：delta=1 向下 / -1 向上
function M.cycle(delta)
  local kind = M.current_kind()
  if not kind then
    return
  end
  local list = M.terms(kind)
  if #list == 0 then
    return
  end
  local p = panel[kind]
  local idx = 1
  for i, t in ipairs(list) do
    if t.id == p.cur then
      idx = i
    end
  end
  idx = ((idx - 1 + delta) % #list) + 1
  M.select(kind, list[idx].id)
end

--- <M-n>：新建一台与当前终端同类型的终端
function M.new_like_current()
  local kind = M.current_kind() or "float"
  local t = M.create(kind)
  if t then
    M.select(kind, t.id)
  end
end

-- ── 终端列表（<leader>tl）────────────────────────────

local function snacks_items()
  local out = {}
  for _, st in ipairs(require("snacks.terminal").list()) do
    local info = vim.b[st.buf].snacks_terminal or {}
    local cmd = info.cmd
    if type(cmd) == "table" then
      cmd = table.concat(cmd, " ")
    end
    local name = "shell"
    if cmd then
      name = vim.fn.fnamemodify(vim.split(cmd, " ")[1], ":t")
    end
    out[#out + 1] = { text = ("[面板] %s"):format(name), snacks = st.buf }
  end
  return out
end

function M.items()
  local out = {}
  for _, spec in ipairs({ { "float", "浮" }, { "bottom", "底" } }) do
    local kind, tag = spec[1], spec[2]
    for _, t in ipairs(M.terms(kind)) do
      out[#out + 1] = { text = ("[%s] %s"):format(tag, name_of(t)), id = t.id, kind = kind }
    end
  end
  vim.list_extend(out, snacks_items())
  return out
end

function M.picker()
  require("snacks.picker").pick({
    title = "终端",
    format = "text",
    items = M.items(),
    -- 显式关闭 picker：snacks 的"进入其它窗口自动关闭"会跳过浮窗，
    -- 选中浮动终端时不会自动收起来（底部 split 则会）
    confirm = function(picker, item)
      picker:norm(function()
        picker:close()
        vim.schedule(function()
          if item.kind then
            M.select(item.kind, item.id)
          elseif item.snacks then
            for _, st in ipairs(require("snacks.terminal").list()) do
              if st.buf == item.snacks then
                st:show():focus()
                return
              end
            end
          end
        end)
      end)
    end,
    actions = {
      term_kill = function(picker, item)
        local ok = false
        if item.kind then
          ok = M.kill(item.id)
        elseif item.snacks and vim.api.nvim_buf_is_valid(item.snacks) then
          vim.api.nvim_buf_delete(item.snacks, { force = true })
          ok = true
        end
        if ok then
          picker:close()
        end
      end,
    },
    win = {
      list = {
        keys = {
          ["<C-d>"] = "term_kill",
        },
      },
    },
  })
end

-- ── 装配 ─────────────────────────────────────────────

function M.setup()
  vim.api.nvim_create_autocmd("VimResized", {
    group = vim.api.nvim_create_augroup("nvkit_term", { clear = true }),
    callback = function()
      local p = panel.float
      if not in_current_tab(p.win) then
        return
      end
      local g = float_geom()
      if is_win(p.side) then
        pcall(vim.api.nvim_win_set_config, p.side, {
          relative = "editor",
          style = "minimal",
          width = g.sw,
          height = g.h,
          row = g.row,
          col = g.col,
          border = "rounded",
        })
      end
      if is_win(p.win) then
        pcall(vim.api.nvim_win_set_config, p.win, {
          relative = "editor",
          style = "minimal",
          width = g.w,
          height = g.h,
          row = g.row,
          col = g.col + g.sw + 2,
          border = "rounded",
        })
      end
    end,
  })
end

return M
