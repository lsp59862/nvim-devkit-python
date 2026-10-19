-- 文件路径显示：相对工作目录 + 智能缩略（保留文件名、省略中间、同名去歧义）
-- 例：./viz/…/v7_2/mask.jpg（首段 + 省略号 + 区分目录 + 文件名）
local M = {}

local function norm(p)
  if type(p) ~= "string" or p == "" then
    return ""
  end
  p = p:gsub("\\", "/"):gsub("/+", "/")
  return p
end

local function split(p)
  local out = {}
  for part in p:gmatch("[^/]+") do
    out[#out + 1] = part
  end
  return out
end

local function width(s)
  return vim.api.nvim_strwidth(s)
end

--- 计算 dirs 尾部的"最小唯一后缀"段数（与 siblings 的目录比较）
---@param dirs string[] 当前文件的目录段
---@param siblings string[][] 其它同名文件的目录段
---@return number
local function unique_tail(dirs, siblings)
  for k = 1, #dirs do
    local suffix = table.concat(vim.list_slice(dirs, #dirs - k + 1, #dirs), "/")
    local unique = true
    for _, other in ipairs(siblings) do
      if #other >= k then
        local osuf = table.concat(vim.list_slice(other, #other - k + 1, #other), "/")
        if osuf == suffix then
          unique = false
          break
        end
      end
    end
    if unique then
      return k
    end
  end
  return #dirs
end

--- 相对化：cwd 下 → "./..."；家目录下 → "~/..."；其余保持规范化的绝对路径
---@param path string
---@param cwd? string
---@return string relative, boolean is_cwd
function M.relative(path, cwd)
  path = norm(path)
  cwd = norm(cwd or vim.fn.getcwd(0))
  if cwd ~= "" and path:find(cwd .. "/", 1, true) == 1 then
    return "." .. path:sub(#cwd + 1), true
  end
  local home = norm(vim.fn.expand("~"))
  if home ~= "" and path:find(home .. "/", 1, true) == 1 then
    return "~" .. path:sub(#home + 1), false
  end
  return path, false
end

--- 缩略显示（纯函数，供测试）
---@param path string 绝对或相对路径
---@param opts? { cwd?: string, width?: number, siblings?: string[] }
---   siblings：同 basename 的其它文件完整路径（用于去歧义）
---@return string
function M.short(path, opts)
  opts = opts or {}
  local budget = opts.width or 60
  local rel, is_cwd = M.relative(path, opts.cwd)
  if width(rel) <= budget then
    return rel
  end
  local parts = split(rel)
  if #parts <= 1 then
    return rel
  end
  local base = parts[#parts]
  local dirs = vim.list_slice(parts, 1, #parts - 1)

  -- 同名兄弟：找到需要保留的唯一目录后缀段数
  local tail_n = 0
  if opts.siblings and #opts.siblings > 0 then
    local others = {}
    for _, s in ipairs(opts.siblings) do
      local orel = M.relative(s, opts.cwd)
      local oparts = split(orel)
      if oparts[#oparts] == base then
        others[#others + 1] = vim.list_slice(oparts, 1, #oparts - 1)
      end
    end
    if #others > 0 then
      tail_n = unique_tail(dirs, others)
    end
  end
  -- 无兄弟时保留最后一个目录段（提供上下文）
  if tail_n == 0 and #dirs > 0 then
    tail_n = 1
  end
  tail_n = math.min(tail_n, #dirs)

  local tail_dirs = tail_n > 0 and vim.list_slice(dirs, #dirs - tail_n + 1, #dirs) or {}
  local tail = (#tail_dirs > 0 and (table.concat(tail_dirs, "/") .. "/") or "") .. base

  -- 尝试：首段 + … + 尾段（唯一后缀 + 文件名）
  local lead = dirs[1]
  local has_gap = #dirs > tail_n + (lead and 1 or 0)
  local function build(with_lead, with_gap)
    if with_lead and lead then
      if with_gap then
        return lead .. "/…/" .. tail
      end
      return table.concat(dirs, "/") .. "/" .. base
    end
    return "…/" .. tail
  end
  local candidates = {
    build(true, has_gap),
    build(false, false),
  }
  for _, c in ipairs(candidates) do
    if width(c) <= budget then
      return c
    end
  end

  -- 超宽：保留文件名与后缀（宁可略超预算也不丢文件名）
  return candidates[#candidates]
end

--- buffers picker 使用的标签（自动收集同 basename 的兄弟用于去歧义）
---@param path string
---@param width? number
---@return string
function M.buffer_label(path, bw)
  path = norm(path)
  if path == "" then
    return path
  end
  local base = vim.fn.fnamemodify(path, ":t")
  local siblings = {}
  for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
    local name = norm(info.name)
    if name ~= "" and name ~= path and vim.fn.fnamemodify(name, ":t") == base then
      siblings[#siblings + 1] = name
    end
  end
  return M.short(path, { width = bw or 60, siblings = siblings })
end

return M
