-- 文件(buffers) / 窗口(windows) 语义定制（Neovim 0.12）
--
--   :q / :q! / :wq / :wq! / :x / :x!   → 只关文件，窗口布局不变
--     · 同一文件还在其他分屏显示时：只把当前分屏切到别的 buffer，文件保持打开
--     · 最后一个视图：还有其它 buffer → 切到最近使用的一个；一个都没有 → 退出程序
--   :bd / :bd! / <leader>bd             → 关文件 + 关当前窗口（未保存时三选项；最后一个文件回启动页）
--   <leader>wd                          → 只关窗口，文件保留（无改动）
--
-- 仅接管"手动输入"的命令（cnoreabbrev），脚本/插件调用不受影响；
-- help/quickfix/终端/浮窗/无名空 buffer 一律保持原生行为。
local M = {}

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "winbuf" })
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
  vim.cmd("enew")
end

--- 只关文件、布局不动（:q / :wq / :x 的新语义）
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

  -- 同一文件还有其他分屏：只把当前分屏切到别的 buffer，文件保持打开
  if #vim.fn.win_findbuf(buf) > 1 then
    switch_away(buf)
    return
  end

  -- 没有其它已列出的 buffer：退出程序（单窗口 = 退出 nvim；
  -- 若还有终端等窗口则只关当前窗口）
  local others = vim.tbl_filter(function(b)
    return b.bufnr ~= buf
  end, vim.fn.getbufinfo({ buflisted = 1 }))
  if #others == 0 then
    vim.cmd(opts.bang and "quit!" or "quit")
    return
  end

  -- 删除文件，窗口切到最近使用的其它 buffer
  require("snacks").bufdelete({ buf = buf, force = true })
end

--- 关文件 + 关当前窗口（<leader>bd / 键入 :bd；确定性的"关标签"语义）
--- · 文件在别的分屏也显示时：那些窗口切到其他 buffer，当前窗口关闭
--- · 单窗口时：窗口无法关闭（否则退出 nvim），文件关闭后窗口保留
--- · 已无命名文件 → 启动页
---@param opts? { bang?: boolean }
function M.delete_buffer_and_windows(opts)
  opts = opts or {}
  local win = vim.api.nvim_get_current_win()

  -- 浮窗（dashboard 等）没有"文件"概念：直接关窗
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

  -- 删文件（布局暂时不动），再关掉当前窗口（浮窗不计入，避免只剩浮窗的尴尬）
  require("snacks").bufdelete({ buf = buf, force = true })
  if vim.api.nvim_win_is_valid(win) and normal_win_count() > 1 then
    vim.api.nvim_win_close(win, true)
  end

  vim.schedule(function()
    local named = vim.tbl_filter(function(b)
      return b.name ~= ""
    end, vim.fn.getbufinfo({ buflisted = 1 }))
    if #named == 0 then
      require("snacks").dashboard.open()
    end
  end)
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
  end, { nargs = "*", bang = true, desc = "关闭文件+当前窗口（无参数时）" })

  local function def(lhs)
    local line = ([[cnoreabbrev <expr> %s (getcmdtype() == ':' && getcmdline() ==# '%s' && luaeval("require('nvim-devkit.winbuf').is_file_window()")) ? luaeval("require('nvim-devkit.winbuf').expand('%s', vim.v.char)") : '%s']]):format(lhs, lhs, lhs, lhs)
    pcall(vim.cmd, line)
  end
  def("q")
  def("wq")
  def("x")
  def("bd")
end

return M
