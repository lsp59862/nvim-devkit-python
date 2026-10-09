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
local SLIDE_MS = 420 -- 展开总时长（毫秒）
local SLIDE_MS_CLOSE = 300 -- 折叠总时长（毫秒，比展开略快更干脆）
local SLIDE_TICK = 16 -- 帧间隔（毫秒）
-- 中心展开动画的相位分界（0~1 的展开度）：
--   [0, OPEN_LINE)   点 → 水平中线
--   [OPEN_LINE, OPEN_SIDE) 中线 → 上下分裂
--   [OPEN_SIDE, 1]   侧边栏向左展开
local OPEN_LINE = 0.42
local OPEN_SIDE = 0.78
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
      set_float_wins(g, g.row, g.h, name_of(t))
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

--- 重配两个浮窗；h 为内容高度（可动画），row 为顶边框所在行
set_float_wins = function(g, row, h, title)
  local p = panel.float
  h = math.max(1, h or g.h)
  if is_win(p.side) then
    pcall(vim.api.nvim_win_set_config, p.side, {
      relative = "editor",
      style = "minimal",
      width = g.sw,
      height = h,
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
      height = h,
      row = row,
      col = g.col + g.sw + 2,
      border = "rounded",
      title = title and (" " .. title .. " ") or nil,
      title_pos = "center",
    })
  end
end

local function round(x)
  return math.floor(x + 0.5)
end

--- 由"展开度" q（0 = 中心一点，1 = 完全展开）计算两个浮窗几何。
--- 关键约束：nvim 会把浮窗夹回"完整可见"——所以全程都在屏内做文章：
--- 点 → 水平中线 → 上下分裂 → 侧栏左展开。
local function open_geom(g, q)
  local C = g.col + g.sw + 2 -- 主窗最终左缘
  local R = g.row -- 最终顶行
  local cx = C + (g.w + 2) / 2 -- 主窗最终中心 x（连续坐标）
  local cy = R + (g.h + 2) / 2 -- 最终中心 y
  local main, side
  if q < OPEN_LINE then
    local t = q / OPEN_LINE
    local w = math.max(1, round(1 + (g.w - 1) * t))
    main = { row = round(cy - 0.5), col = round(cx - w / 2), w = w, h = 1, border = "none" }
  elseif q < OPEN_SIDE then
    local t = (q - OPEN_LINE) / (OPEN_SIDE - OPEN_LINE)
    local h = math.max(1, round(1 + (g.h - 1) * t))
    local row0 = round(cy - 1.5) -- 加边框后的起始顶行
    main = { row = round(row0 + (R - row0) * t), col = C, w = g.w, h = h, border = "rounded" }
  else
    local t = (q - OPEN_SIDE) / (1 - OPEN_SIDE)
    local sw = math.max(1, round(1 + (g.sw - 1) * t))
    main = { row = R, col = C, w = g.w, h = g.h, border = "rounded" }
    side = { row = R, col = C - (sw + 2), w = sw, h = g.h, border = "rounded" }
  end
  return main, side
end

--- 关闭动画几何：q（1 = 完全展开，0 = 收成中心的点）
--- 与 open_geom 严格镜像（时间反放）：侧栏折回 → 带边框收成一条线 → 化线为点。
--- 相位分界与展开一致，保证逐帧可见、收尾不拖。
local function close_geom(g, q)
  local p = 1 - q
  local C = g.col + g.sw + 2
  local R = g.row
  local cx = C + (g.w + 2) / 2
  local cy = R + (g.h + 2) / 2
  local line_row = round(cy - 0.5) -- 无边框"线"所在行（与展开起点相同）
  local row0 = round(cy - 1.5) -- 带边框阶段的起始顶行（与展开衔接）
  local main, side
  if p < 1 - OPEN_SIDE then
    -- 反放展开的第 3 相：侧栏折回
    local t = p / (1 - OPEN_SIDE)
    local sw = math.max(1, round(g.sw + (1 - g.sw) * t))
    main = { row = R, col = C, w = g.w, h = g.h, border = "rounded" }
    side = { row = R, col = C - (sw + 2), w = sw, h = g.h, border = "rounded" }
  elseif p < 1 - OPEN_LINE then
    -- 反放展开的第 2 相：上下合拢成一条线
    local t = (p - (1 - OPEN_SIDE)) / (OPEN_SIDE - OPEN_LINE)
    local h = math.max(1, round(g.h + (1 - g.h) * t))
    main = { row = round(R + (row0 - R) * t), col = C, w = g.w, h = h, border = "rounded" }
  else
    -- 反放展开的第 1 相：线收成点
    local t = (p - (1 - OPEN_LINE)) / OPEN_LINE
    local w = math.max(1, round(g.w + (1 - g.w) * t))
    main = { row = line_row, col = round(cx - w / 2), w = w, h = 1, border = "none" }
  end
  return main, side
end

--- 应用一对窗口几何；侧栏窗口在需要时创建、不需要时关闭
local function apply_pair(mg, sg, title)
  local p = panel.float
  if is_win(p.win) and mg then
    -- 注意：border=none 时不能带 title/title_pos，否则 nvim 整条 set_config 拒绝
    local cfg = {
      relative = "editor",
      style = "minimal",
      width = mg.w,
      height = mg.h,
      row = mg.row,
      col = mg.col,
      border = mg.border,
    }
    if mg.border ~= "none" and title then
      cfg.title = " " .. title .. " "
      cfg.title_pos = "center"
    end
    pcall(vim.api.nvim_win_set_config, p.win, cfg)
  end
  if sg then
    if not is_win(p.side) then
      p.side = vim.api.nvim_open_win(ensure_side_buf("float"), false, {
        relative = "editor",
        style = "minimal",
        width = sg.w,
        height = sg.h,
        row = sg.row,
        col = sg.col,
        border = sg.border,
        zindex = 45,
      })
      vim.w[p.side].nvkit_no_dim = true
      vim.wo[p.side].winhighlight = ""
      watch(p.side, "float")
      M.refresh("float")
    else
      pcall(vim.api.nvim_win_set_config, p.side, {
        relative = "editor",
        style = "minimal",
        width = sg.w,
        height = sg.h,
        row = sg.row,
        col = sg.col,
        border = sg.border,
      })
    end
  elseif is_win(p.side) then
    -- 不置 nil：若这次关闭失败，收尾的 close_all 还能兜底重试
    pcall(vim.api.nvim_win_close, p.side, true)
  end
end

local function apply_open_geom(g, q, title)
  panel.float.q = q
  local mg, sg = open_geom(g, q)
  apply_pair(mg, sg, title)
end

local function apply_close_geom(g, q, title)
  panel.float.q = q
  local mg, sg = close_geom(g, q)
  apply_pair(mg, sg, title)
end

--- 展开/折叠动画（q 从 0→1 或 1→0；mode 决定几何曲线）
--- 按实际经过时间推进（ease-out cubic），每帧强制刷屏防重绘合并。
local function animate(g, q_from, q_to, done, mode)
  slide_token.float = slide_token.float + 1
  local token = slide_token.float
  -- 运行时旋钮（调试/慢链路用）：:lua vim.g.nvkit_term_anim_tick = 32 后重按 tp 生效
  local default_ms = mode == "close" and SLIDE_MS_CLOSE or SLIDE_MS
  local ms_var = mode == "close" and vim.g.nvkit_term_anim_ms_close or vim.g.nvkit_term_anim_ms
  local total_ms = tonumber(ms_var) or default_ms
  local tick_ms = tonumber(vim.g.nvkit_term_anim_tick) or SLIDE_TICK
  if tick_ms <= 0 then
    tick_ms = SLIDE_TICK
  end
  if total_ms <= 0 then
    total_ms = default_ms
  end
  local start = uv.hrtime()
  local total = total_ms * 1e6
  local total_frames = math.max(1, math.ceil(total_ms / tick_ms))
  local frame = 0
  local debug_frames = vim.g.nvkit_term_anim_debug and true or false
  local timer = assert(uv.new_timer())
  local finished = false
  -- 调试日志（:lua vim.g.nvkit_term_anim_log = "/tmp/nvkit_anim.log" 后触发动画）
  local log_path = vim.g.nvkit_term_anim_log
  local logf = type(log_path) == "string" and log_path ~= "" and io.open(log_path, "a") or nil
  local prev_tick
  local function close_log()
    if logf then
      pcall(function()
        logf:close()
      end)
      logf = nil
    end
  end
  local function finish()
    if finished then
      return
    end
    finished = true
    close_log()
    if timer then
      if not timer:is_closing() then
        timer:stop()
        timer:close()
      end
      timer = nil
    end
  end
  timer:start(0, tick_ms, function()
    vim.schedule(function()
      if token ~= slide_token.float then
        return finish()
      end
      local now = uv.hrtime()
      local t = math.min((now - start) / total, 1)
      -- 展开 ease-out（快起慢收）；折叠线性推进，干脆利落
      local eased = mode == "close" and t or (1 - (1 - t) ^ 3)
      local q = q_from + (q_to - q_from) * eased
      local cur = get(panel.float.cur)
      local title = cur and name_of(cur) or nil
      frame = frame + 1
      if debug_frames then
        title = ("帧 %d/%d"):format(math.min(frame, total_frames), total_frames)
      end
      local a = uv.hrtime()
      local applier = mode == "close" and apply_close_geom or apply_open_geom
      local ok_apply, apply_err = pcall(applier, g, q, title)
      local b = uv.hrtime()
      pcall(vim.api.nvim__redraw, { flush = true })
      local c = uv.hrtime()
      if logf then
        pcall(function()
          logf:write(
            ("t=%.1f dt=%s set=%.2f flush=%.2f q=%.3f mode=%s%s\n"):format(
              (now - start) / 1e6,
              prev_tick and ("%.1f"):format((now - prev_tick) / 1e6) or "-",
              (b - a) / 1e6,
              (c - b) / 1e6,
              q,
              vim.api.nvim_get_mode().mode,
              ok_apply and "" or (" APPLY_ERR:" .. tostring(apply_err))
            )
          )
          logf:flush()
        end)
      end
      prev_tick = now
      if t >= 1 then
        -- 容错收尾：先让最后一帧（点/全开）真实渲染一帧，再执行 done。
        -- 否则"应用最后一帧 + 立即关窗"发生在同一个回调里，终端根本看不到收尾帧。
        finish()
        if done then
          vim.defer_fn(function()
            local ok_done, done_err = pcall(done)
            pcall(vim.api.nvim__redraw, { flush = true })
            if not ok_done and type(log_path) == "string" and log_path ~= "" then
              pcall(function()
                local f = io.open(log_path, "a")
                if f then
                  f:write("DONE_ERR:" .. tostring(done_err) .. "\n")
                  f:close()
                end
              end)
            end
          end, tick_ms)
        else
          vim.schedule(function()
            pcall(vim.api.nvim__redraw, { flush = true })
          end)
        end
      end
    end)
  end)
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
    p.zoom_h, p.zoom_geom, p.q = nil, nil, nil
  end
  if kind == "float" and not soft and in_current_tab(p.win) then
    local g = read_geom()
    animate(g, p.q or 1, 0, close_all, "close")
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
    if p.closing then
      -- 折叠动画进行中又被唤出：取消折叠、拆掉迷你框，重新走一遍展开动画
      p.closing = false
      slide_token.float = slide_token.float + 1
      if is_win(p.win) then
        pcall(vim.api.nvim_win_close, p.win, true)
      end
      if is_win(p.side) then
        pcall(vim.api.nvim_win_close, p.side, true)
      end
      p.win, p.side = nil, nil
    else
      vim.api.nvim_set_current_win(p.win)
      vim.cmd("startinsert")
      return
    end
  end
  if is_win(p.win) then
    pcall(vim.api.nvim_win_close, p.win, true)
  end
  if is_win(p.side) then
    pcall(vim.api.nvim_win_close, p.side, true)
  end

  local cur = get(p.cur) or M.terms("float")[1]
  p.cur = cur.id
  p.closing = false
  local g = float_geom()
  -- 从屏幕中心的 1×1 "点"开始（无边框），再展开成中线、上下分裂、侧栏左展
  local mg = open_geom(g, 0)
  p.side = nil
  p.win = vim.api.nvim_open_win(cur.buf, true, {
    relative = "editor",
    style = "minimal",
    width = mg.w,
    height = mg.h,
    row = mg.row,
    col = mg.col,
    border = mg.border,
    zindex = 50,
  })
  p.visible = true
  watch(p.win, "float")
  M.refresh("float")
  animate(g, 0, 1)
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
    set_float_wins(g, g.row, g.h, name_of(t))
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

--- Ctrl+Shift+=：当前面板最大化 / 还原
--- 底部 = 高度撑满（编辑器留最小空间，nvim 自动 clamp）；浮动 = 全屏
function M.toggle_zoom()
  local kind = M.current_kind()
  if not kind then
    return
  end
  local p = panel[kind]
  if not in_current_tab(p.win) then
    return
  end
  local title = M.name_of(p.cur)
  if kind == "bottom" then
    if p.zoom_h then
      vim.api.nvim_win_set_height(p.win, p.zoom_h)
      p.zoom_h = nil
    else
      p.zoom_h = vim.api.nvim_win_get_height(p.win)
      vim.api.nvim_win_set_height(p.win, vim.o.lines)
    end
    return
  end
  -- 若展开/折叠动画还在跑，先取消，避免下一帧覆盖缩放几何
  slide_token.float = slide_token.float + 1
  p.q = nil
  if p.zoom_geom then
    set_float_wins(p.zoom_geom, p.zoom_geom.row, p.zoom_geom.h, title)
    p.zoom_geom = nil
  else
    p.zoom_geom = read_geom()
    local g = vim.deepcopy(p.zoom_geom)
    g.row = 0
    g.col = 0
    g.h = vim.o.lines - 2
    g.w = vim.o.columns - g.sw - 4
    set_float_wins(g, 0, g.h, title)
  end
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
      if p.zoom_geom then
        -- 缩放状态下保持全屏
        g.row = 0
        g.col = 0
        g.h = vim.o.lines - 2
        g.w = vim.o.columns - g.sw - 4
      end
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
