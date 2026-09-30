-- scope.nvim 的有序会话持久化胶水
--
-- scope 自带的序列化按 tab handle 的 pairs 顺序输出，关过 tab 再新增会错位；
-- 这里改为按 tabpagenr 顺序序列化「tab → 文件名列表」，随 persistence.nvim 的
-- 会话保存/恢复（sessionoptions 含 globals，状态存 vim.g.NvkitScopeState）。
local M = {}

local STATE_VAR = "NvkitScopeState"

local function core()
  return require("scope.core")
end

--- 按 tabpagenr 顺序收集当前所有 tab 的文件名列表，返回 JSON
---@return string
function M.serialize()
  local c = core()
  -- 与 scope 的 ScopeSaveState 相同：先把当前 tab 的集合刷进 cache
  c.on_tab_leave()
  c.on_tab_enter()

  local state = {}
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local names = {}
    for _, b in ipairs(c.cache[tab] or {}) do
      if vim.api.nvim_buf_is_valid(b) and vim.bo[b].buftype == "" then
        local name = vim.api.nvim_buf_get_name(b)
        if name ~= "" then
          names[#names + 1] = name
        end
      end
    end
    state[#state + 1] = names
  end
  return vim.json.encode(state)
end

local function unlist_all()
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(b) and vim.bo[b].buflisted then
      vim.bo[b].buflisted = false
    end
  end
end

--- 恢复：按 tab 顺序把文件名还原为各 tab 的集合
---@return boolean
function M.restore()
  local raw = vim.g[STATE_VAR]
  if type(raw) ~= "string" or raw == "" then
    return false
  end
  local ok, state = pcall(vim.json.decode, raw)
  if not ok or type(state) ~= "table" then
    return false
  end

  local c = core()
  unlist_all()

  local cache = {}
  for i, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local bufs = {}
    for _, name in ipairs(state[i] or {}) do
      local b = vim.fn.bufnr(name)
      if b == -1 then
        pcall(vim.cmd, "badd " .. vim.fn.fnameescape(name))
        b = vim.fn.bufnr(name)
      end
      if b ~= -1 and vim.api.nvim_buf_is_valid(b) and vim.bo[b].buftype == "" then
        bufs[#bufs + 1] = b
      end
    end
    cache[tab] = bufs
  end
  -- badd 会把不存在的文件标记为 listed，这里再清一次，统一交给 on_tab_enter 恢复
  unlist_all()
  c.cache = cache
  c.on_tab_enter()
  return true
end

--- 旧会话没有保存状态时的降级：用每个 tab 窗口里显示的 buffer 作为集合
function M.restore_from_windows()
  local c = core()
  unlist_all()
  local cache = {}
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    local bufs = {}
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
      local b = vim.api.nvim_win_get_buf(win)
      if vim.bo[b].buftype == "" then
        bufs[#bufs + 1] = b
      end
    end
    cache[tab] = bufs
  end
  c.cache = cache
  c.on_tab_enter()
end

--- 清理 tabnew 遗留的无名空 buffer：
--- 在新 tab 打开"已加载的文件"时，空 buffer 不会被自动复用，会残留在列表里
local function cleanup_scratch()
  local cur = vim.api.nvim_get_current_buf()
  if vim.api.nvim_buf_get_name(cur) == "" and vim.bo[cur].buftype == "" then
    return
  end
  local c = core()
  local tab = vim.api.nvim_get_current_tabpage()
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if
      b ~= cur
      and vim.api.nvim_buf_is_valid(b)
      and vim.b[b].nvkit_scratch
      and vim.bo[b].buflisted
      and not vim.bo[b].modified
      and vim.api.nvim_buf_line_count(b) == 1
      and vim.api.nvim_buf_get_lines(b, 0, 1, false)[1] == ""
      and #vim.fn.win_findbuf(b) == 0
    then
      vim.bo[b].buflisted = false
      vim.b[b].nvkit_scratch = nil
      if c.cache[tab] then
        c.cache[tab] = vim.tbl_filter(function(x)
          return x ~= b
        end, c.cache[tab])
      end
    end
  end
end

function M.setup()
  if not pcall(require, "scope.core") then
    return
  end
  local group = vim.api.nvim_create_augroup("nvim_devkit_scope_bridge", { clear = true })

  -- tabnew 产生的空 buffer 打标记，之后被真实文件替代时清理
  vim.api.nvim_create_autocmd("TabNewEntered", {
    group = group,
    callback = function()
      local b = vim.api.nvim_get_current_buf()
      if
        vim.api.nvim_buf_get_name(b) == ""
        and vim.bo[b].buftype == ""
        and not vim.bo[b].modified
        and vim.api.nvim_buf_line_count(b) == 1
      then
        vim.b[b].nvkit_scratch = true
      end
    end,
  })
  vim.api.nvim_create_autocmd({ "BufFilePost", "BufEnter" }, {
    group = group,
    callback = function()
      vim.schedule(function()
        pcall(cleanup_scratch)
      end)
    end,
  })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "PersistenceSavePre",
    callback = function()
      local ok, encoded = pcall(M.serialize)
      if ok then
        vim.g[STATE_VAR] = encoded
      end
    end,
  })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "PersistenceLoadPost",
    callback = function()
      if not M.restore() then
        pcall(M.restore_from_windows)
      end
    end,
  })
end

return M
