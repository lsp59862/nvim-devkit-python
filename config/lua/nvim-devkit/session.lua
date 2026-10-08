-- 会话自动恢复（opt-in）与启动页提示共用的判断逻辑
--
-- 默认关闭；NVIM_DEVKIT_AUTORESTORE=1 或 vim.g.nvkit_autorestore = true 时，
-- 交互式启动、无文件参数且本目录有快照，才自动 load。
-- 存档仍只发生在正常退出时（VimLeavePre，由 persistence 负责）。
local M = {}

function M.enabled()
  return vim.env.NVIM_DEVKIT_AUTORESTORE == "1" or vim.g.nvkit_autorestore == true
end

--- 本目录可用的快照路径；无则返回 nil（与 persistence.load 相同的分支回退逻辑）
---@return string?
function M.session_file()
  local ok, p = pcall(require, "persistence")
  if not ok then
    return nil
  end
  local ok2, file = pcall(function()
    local f = p.current()
    if vim.fn.filereadable(f) == 0 then
      f = p.current({ branch = false })
    end
    return vim.fn.filereadable(f) == 1 and f or nil
  end)
  return ok2 and file or nil
end

--- 自动恢复门闸；overrides 供测试注入四类条件
---@param o? { enabled?: boolean, argc?: integer, has_ui?: boolean, has_session?: boolean }
---@return boolean
function M.should_restore(o)
  o = o or {}
  local enabled = o.enabled
  if enabled == nil then
    enabled = M.enabled()
  end
  local argc = o.argc
  if argc == nil then
    argc = vim.fn.argc(-1)
  end
  local has_ui = o.has_ui
  if has_ui == nil then
    has_ui = #vim.api.nvim_list_uis() > 0
  end
  local has_session = o.has_session
  if has_session == nil then
    has_session = M.session_file() ~= nil
  end
  return enabled and argc == 0 and has_ui and has_session
end

---@param o? { enabled?: boolean, argc?: integer, has_ui?: boolean, has_session?: boolean }
---@return boolean 是否执行了恢复
function M.maybe_restore(o)
  if not M.should_restore(o) then
    return false
  end
  require("persistence").load()
  return true
end

function M.setup()
  vim.api.nvim_create_autocmd("VimEnter", {
    group = vim.api.nvim_create_augroup("nvim_devkit_session", { clear = true }),
    callback = function()
      vim.schedule(function()
        pcall(M.maybe_restore)
      end)
    end,
  })
end

return M
