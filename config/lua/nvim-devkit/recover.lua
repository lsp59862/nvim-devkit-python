-- 恐慌恢复：误按一串键之后，一键回到已知状态
local M = {}

local function close_cmdwin()
  if vim.fn.getcmdwintype() ~= "" then
    pcall(vim.cmd, "quit")
  end
end

local function close_floats()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local cfg = vim.api.nvim_win_get_config(win)
    if cfg.relative and cfg.relative ~= "" then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end
end

--- 回正常模式 / 停宏录制 / 关浮窗 / 清搜索高亮
function M.panic()
  close_cmdwin()
  local esc = vim.api.nvim_replace_termcodes("<Esc>", true, false, true)
  vim.api.nvim_feedkeys(esc, "nx", false)
  if vim.fn.reg_recording() ~= "" then
    vim.api.nvim_feedkeys("q", "nx", false)
  end
  vim.schedule(function()
    close_floats()
    vim.cmd("nohlsearch")
    vim.notify("已重置：正常模式 / 浮窗已关闭 / 宏已停止 / 高亮已清除", vim.log.levels.INFO, { title = "recover" })
  end)
end

--- 时间旅行：:earlier 10m / :later 2h
function M.time_travel(dir)
  local label = dir == "earlier" and "回退" or "前进"
  vim.ui.input({ prompt = label .. "到多久前？(如 10m / 2h / 1d): ", default = "10m" }, function(input)
    if not input or input == "" then
      return
    end
    local ok = pcall(vim.cmd, ("%s %s"):format(dir, input))
    if ok then
      vim.notify(("已%s %s"):format(label, input), vim.log.levels.INFO, { title = "recover" })
    else
      vim.notify("时间格式无效，示例：10m / 2h / 1d", vim.log.levels.WARN)
    end
  end)
end

return M
