-- 文件(buffers) / 窗口(windows) 语义定制（Neovim 0.12）
--
--   :q / :q! / :wq / :wq! / :x / :x!   → 只关文件，窗口与 tab 布局不变
--     · 还有其它文件 → 当前窗口切到最近使用的其它文件              [1.1]
--     · 没有其它文件 → 当前窗口打开 dashboard（程序不退出）         [1.2]
--     · dashboard 窗口 → 放行原生：单 tab 退出 nvim / 多 tab 关当前 tab [1.3/3.1]
--   :bd / :bd! / <leader>bd             → 关文件 +（多窗口时）关当前窗口   [bd]
--     · dashboard 上拒绝（提示用 :q）
--     · 没有其它文件 → 打开 dashboard（程序不退出）
--   <leader>wd                          → 只关窗口，不动 buffer
--     · 单窗口 / dashboard 上拒绝并提示
--   :Exit（键入 :exit / :exit!）         → 无条件退出 nvim（qa!）
--
-- 仅接管"手动输入"的命令与以上键位，脚本/插件调用不受影响；
-- help/quickfix/终端/浮窗 一律保持原生行为。
local M = {}

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "winbuf" })
end

--- 当前 buffer 是否是 dashboard（启动页 / :NvkitHome 打开的普通窗口）
function M.is_dashboard()
  return vim.bo.filetype == "snacks_dashboard"
end

--- 在当前窗口打开 dashboard（普通 buffer，非浮窗）
function M.open_dashboard()
  require("snacks").dashboard.open({ win = 0 })
end

--- 普通窗口（不含浮窗）数量
local function normal_win_count()
  local n = 0
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(w).relative == "" then
      n = n + 1
    end
  end
  return n
end

--- 除了 buf 之外的"文件 buffer"（已列出且有名）
local function other_files(buf)
  return vim.tbl_filter(function(b)
    return b.bufnr ~= buf and b.name ~= ""
  end, vim.fn.getbufinfo({ buflisted = 1 }))
end

--- 当前窗口是否为"普通命名文件"（决定是否接管 :q 系列）
function M.is_file_window()
  if vim.fn.getcmdtype() ~= ":" then
    return false
  end
  local win = vim.api.nvim_get_current_win()
  if vim.api.nvim_win_get_config(win).relative ~= "" then
    return false -- 浮窗保持原生
  end
  local buf = vim.api.nvim_get_current_buf()
  return vim.bo[buf].buftype == ""
    and vim.bo[buf].buflisted
    and vim.api.nvim_buf_get_name(buf) ~= ""
end

--- :bd 的接管范围：普通命名文件窗口，或 dashboard 窗口（用来拒绝）
function M.is_bd_context()
  return M.is_file_window() or M.is_dashboard()
end

--- 把当前窗口切换到别的 buffer（文件继续在其他分屏显示）
local function switch_away(buf)
  local alt = vim.fn.bufnr("#")
  if alt >= 0 and alt ~= buf and vim.api.nvim_buf_is_valid(alt) and vim.bo[alt].buflisted then
    vim.api.nvim_win_set_buf(0, alt)
    return
  end
  local info = vim.fn.getbufinfo({ buflisted = 1 })
  table.sort(info, function(a, b)
    return a.lastused > b.lastused
  end)
  for _, b in ipairs(info) do
    if b.bufnr ~= buf and b.name ~= "" then
      vim.api.nvim_win_set_buf(0, b.bufnr)
      return
    end
  end
  M.open_dashboard()
end

--- 只关文件、布局不动（:q / :wq / :x）
---@param opts? { bang?: boolean, write?: boolean }
function M.close_file(opts)
  opts = opts or {}
  local buf = vim.api.nvim_get_current_buf()

  if opts.write then
    local ok, err = pcall(vim.cmd, opts.bang and "write!" or "write")
    if not ok then
      notify("写入失败：" .. tostring(err), vim.log.levels.ERROR)
      return
    end
  end

  if vim.bo[buf].modified and not opts.bang then
    notify("文件已修改：用 :wq 保存关闭，或 :q! 丢弃修改", vim.log.levels.WARN)
    return
  end

  local others = other_files(buf)

  -- 同一文件还在其他分屏显示：只把当前窗口切走，文件保持打开
  if #vim.fn.win_findbuf(buf) > 1 then
    if #others > 0 then
      switch_away(buf)
    else
      M.open_dashboard()
    end
    return
  end

  -- 当前窗口是该文件的最后一个视图
  if #others > 0 then
    -- 删除文件，窗口切到最近使用的其它文件
    require("snacks").bufdelete({ buf = buf, force = true })
  else
    -- 没有其它文件：回 dashboard，程序不退出
    M.open_dashboard()
    pcall(vim.cmd, "bdelete! " .. buf)
  end
end

--- 关文件 +（多窗口时）关当前窗口（:bd / <leader>bd）
---@param opts? { bang?: boolean }
function M.delete_buffer_and_windows(opts)
  opts = opts or {}
  local win = vim.api.nvim_get_current_win()

  if M.is_dashboard() then
    notify("dashboard 上请用 :q（单 tab 退出，多 tab 关当前 tab）", vim.log.levels.WARN)
    return
  end

  -- 非 dashboard 的浮窗：直接关窗
  if vim.api.nvim_win_get_config(win).relative ~= "" then
    pcall(vim.api.nvim_win_close, win, true)
    return
  end

  local buf = vim.api.nvim_get_current_buf()

  -- 未保存时先确认（bang 表示丢弃）
  if vim.bo[buf].modified and not opts.bang then
    local name = vim.fn.fnamemodify(vim.fn.bufname(buf), ":t")
    local choice = vim.fn.confirm(("文件 %s 已修改，保存？"):format(name), "&保存并关闭\n&丢弃修改\n&取消", 3)
    if choice == 0 or choice == 3 then
      return
    end
    if choice == 1 then
      local ok, err = pcall(vim.cmd, "write")
      if not ok then
        notify("写入失败：" .. tostring(err), vim.log.levels.ERROR)
        return
      end
    end
  end

  -- 删文件（布局暂时不动），多窗口时再关掉当前窗口
  require("snacks").bufdelete({ buf = buf, force = true })
  if vim.api.nvim_win_is_valid(win) and normal_win_count() > 1 then
    vim.api.nvim_win_close(win, true)
  end

  -- 已无任何其它文件 → 回 dashboard
  local named = vim.tbl_filter(function(b)
    return b.name ~= ""
  end, vim.fn.getbufinfo({ buflisted = 1 }))
  if #named == 0 and not M.is_dashboard() then
    M.open_dashboard()
  end
end

--- 只关窗口（<leader>wd）：单窗口 / dashboard 上拒绝
function M.close_window()
  if M.is_dashboard() then
    notify("dashboard 上请用 :q（单 tab 退出，多 tab 关当前 tab）", vim.log.levels.WARN)
    return
  end
  if normal_win_count() <= 1 then
    notify("单窗口不能关闭窗口：用 :q 关文件，或 :bd 关文件+窗口", vim.log.levels.WARN)
    return
  end
  local ok, err = pcall(vim.cmd, "close")
  if not ok then
    notify("关闭窗口失败：" .. tostring(err), vim.log.levels.WARN)
  end
end

--- cnoreabbrev 的展开函数（在展开瞬间读取 v:char 判断 !）
---@param lhs string
---@param vchar string
function M.expand(lhs, vchar)
  if lhs == "bd" then
    -- 带参数写法（:bd 3 / :bd! 3）在输入空格时不要展开
    if vchar == " " or vchar == "\t" then
      return lhs
    end
    -- 展开为自定义命令 NvkitBd；触发字符 "!" 会被自动追加成 NvkitBd!
    return "NvkitBd"
  end

  local bang = vchar == "!"
  local args
  if lhs == "q" then
    args = ("{ bang = %s }"):format(tostring(bang))
  elseif lhs == "wq" or lhs == "x" then
    args = ("{ write = true, bang = %s }"):format(tostring(bang))
  else
    return lhs
  end
  -- 末尾的 Lua 注释用来吞掉缩写展开后紧跟的触发字符（如 "!"）
  return ("lua require('nvim-devkit.winbuf').close_file(%s) -- "):format(args)
end

--- 注册命令重定向（只影响手动输入）
function M.setup()
  -- 键入 :bd / :bd! 的落地命令（无参数走新语义；带参数透传原生）
  vim.api.nvim_create_user_command("NvkitBd", function(cmd)
    if #cmd.fargs > 0 then
      vim.cmd("bd" .. (cmd.bang and "!" or "") .. " " .. table.concat(cmd.fargs, " "))
      return
    end
    M.delete_buffer_and_windows({ bang = cmd.bang })
  end, { nargs = "*", bang = true, desc = "关闭文件+窗口（无参数时）" })

  -- exit：无条件退出 nvim
  vim.api.nvim_create_user_command("Exit", function()
    vim.cmd("qa!")
  end, { bang = true, desc = "无条件退出 nvim" })

  local function def(lhs, cond)
    cond = cond or "is_file_window"
    local line = ([[cnoreabbrev <expr> %s (getcmdtype() == ':' && getcmdline() ==# '%s' && luaeval("require('nvim-devkit.winbuf').%s()")) ? luaeval("require('nvim-devkit.winbuf').expand('%s', vim.v.char)") : '%s']]):format(lhs, lhs, cond, lhs, lhs)
    pcall(vim.cmd, line)
  end
  def("q")
  def("wq")
  def("x")
  def("bd", "is_bd_context")

  -- 键入 :exit / :exit! → Exit（内建 :exit 是 :xit 的别名，会保存，这里改为无条件退出）
  pcall(vim.cmd, [[cnoreabbrev <expr> exit (getcmdtype() == ':' && getcmdline() ==# 'exit') ? 'Exit' : 'exit']])
end

return M
