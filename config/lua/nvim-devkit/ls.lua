-- :ls 缓冲区列表：工作目录相对路径 + 同名文件去歧义（保留区分目录）
-- 输入 :ls 自动展开为 :Ls（只影响手输命令，插件/脚本调用 :ls 不变）
local M = {}

local function norm(p)
  return (p or ""):gsub("\\", "/")
end

--- 生成缓冲区列表行（纯函数，便于测试）
---@param opts? { all?: boolean } all=true 包含未列出缓冲区（:ls!）
---@return string[]
function M.lines(opts)
  opts = opts or {}
  local pf = require("nvim-devkit.pathfmt")
  local cwd = vim.fn.getcwd(0)
  local infos = vim.fn.getbufinfo(opts.all and {} or { buflisted = 1 })
  table.sort(infos, function(a, b)
    return a.bufnr < b.bufnr
  end)

  -- 按 basename 分组，用于同名去歧义
  local by_base = {}
  for _, info in ipairs(infos) do
    local name = norm(info.name)
    if name ~= "" then
      local base = vim.fn.fnamemodify(name, ":t")
      by_base[base] = by_base[base] or {}
      table.insert(by_base[base], name)
    end
  end

  local lines = {}
  for _, info in ipairs(infos) do
    local name = norm(info.name)
    local label
    if name == "" then
      label = "[No Name]"
    else
      local base = vim.fn.fnamemodify(name, ":t")
      local siblings = {}
      for _, other in ipairs(by_base[base] or {}) do
        if other ~= name then
          siblings[#siblings + 1] = other
        end
      end
      label = pf.short(name, {
        cwd = cwd,
        width = 72,
        siblings = #siblings > 0 and siblings or nil,
      })
    end
    local cur = vim.api.nvim_get_current_buf() == info.bufnr
    local alt = vim.fn.bufnr("#") == info.bufnr
    local shown = #(info.windows or {}) > 0
    local flags = (cur and "%" or " ")
      .. (alt and "#" or " ")
      .. (shown and "a" or (info.loaded == 1 and "h" or " "))
      .. (info.changed == 1 and "+" or " ")
    lines[#lines + 1] = ("%3d %s %s"):format(info.bufnr, flags, label)
  end
  if #lines == 0 then
    lines[1] = "没有列出的缓冲区"
  end
  return lines
end

--- 以通知形式显示缓冲区列表
---@param opts? { all?: boolean }
function M.show(opts)
  vim.notify(table.concat(M.lines(opts), "\n"), vim.log.levels.INFO, { title = "buffers" })
end

function M.setup()
  vim.api.nvim_create_user_command("Ls", function(ev)
    M.show({ all = ev.bang })
  end, { bang = true, desc = "缓冲区列表（工作目录相对路径、同名去歧义）" })
  -- 手输 :ls / :ls! 时改用 :Ls（不影响脚本/插件调用原生 :ls）
  vim.cmd("cnoreabbrev <expr> ls getcmdtype() ==# ':' && getcmdline() ==# 'ls' ? 'Ls' : 'ls'")
  vim.cmd("cnoreabbrev <expr> ls! getcmdtype() ==# ':' && getcmdline() ==# 'ls!' ? 'Ls!' : 'ls!'")
end

return M
