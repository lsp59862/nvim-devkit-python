-- 仓库根目录定位（兼容 ~/.config/nvim-devkit -> <repo>/config 的软链接安装方式）
local M = {}

function M.repo_root()
  local src = debug.getinfo(1, "S").source:sub(2)
  local resolved = vim.fn.resolve(vim.fn.fnamemodify(src, ":p"))
  local dir = vim.fn.fnamemodify(resolved, ":h")
  for _ = 1, 8 do
    if vim.fn.filereadable(dir .. "/install.sh") == 1 and vim.fn.isdirectory(dir .. "/docs") == 1 then
      return dir
    end
    local parent = vim.fn.fnamemodify(dir, ":h")
    if parent == dir then
      break
    end
    dir = parent
  end
  -- 兜底：config/lua/nvim-devkit/paths.lua -> repo
  return vim.fn.fnamemodify(resolved, ":h:h:h:h")
end

function M.file(rel)
  return M.repo_root() .. "/" .. rel
end

return M
