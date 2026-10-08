-- 终端管理：统一 <leader>t*（浮动 / 底部 / 列表），opencode 面板独立于 <leader>ot
--
-- snacks.terminal 以 cmd + cwd + 编号(count) 区分实例：数字前缀可多开，
-- 隐藏（q）不杀进程，列表里可切回；kill 才真正结束进程。
local M = {}

M.FLOAT = { position = "float", width = 0.8, height = 0.8, border = "rounded" }
M.BOTTOM = { position = "bottom", height = 0.3 }

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

function M.open_float(count)
  require("snacks.terminal").toggle(nil, { count = count, win = vim.deepcopy(M.FLOAT) })
end

function M.open_bottom(count)
  require("snacks.terminal").toggle(nil, { count = count, win = vim.deepcopy(M.BOTTOM) })
end

--- 聚焦某编号终端；已在其中则隐藏（可再次唤出）
function M.focus(count)
  require("snacks.terminal").focus(nil, { count = count, win = vim.deepcopy(M.FLOAT) })
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
  local title = e.title ~= "" and ("  " .. e.title) or ""
  return ("%d: %s  %s%s"):format(e.id, name, cwd, title)
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
