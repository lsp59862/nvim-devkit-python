-- 文件树显示所有文件：被 .gitignore 忽略的目录（result/）与点文件都必须出现在树里
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")

local root = lib.dir() .. "/explorer_all"
vim.fn.delete(root, "rf")
vim.fn.mkdir(root .. "/result", "p")
vim.fn.writefile({ "result/" }, root .. "/.gitignore")
vim.fn.writefile({ "ignored dir file" }, root .. "/result/out.txt")
vim.fn.writefile({ "dot" }, root .. "/.hidden.txt")
vim.fn.writefile({ "plain" }, root .. "/normal.txt")
vim.fn.system({ "git", "init", "-q", root })

local picker = require("snacks.picker")
picker.pick("explorer", { cwd = root })

local function items()
  local p = picker.get()[1]
  return p and p:items() or {}
end

-- 等 git status 异步标记完成（result 节点被标 ignored 且仍保留 = 过滤未生效）
local ready = vim.wait(10000, function()
  for _, it in ipairs(items()) do
    if it.file == root .. "/result" and it.ignored == true then
      return true
    end
  end
  return false
end, 50)
lib.ok("被 .gitignore 忽略的 result/ 可见（ignored 标记已加载）", ready, "items=" .. #items())

local names = {}
for _, it in ipairs(items()) do
  names[#names + 1] = it.file
end
local joined = table.concat(names, "\n")

lib.ok("隐藏点文件 .hidden.txt 可见", joined:find(root .. "/.hidden.txt", 1, true) ~= nil, "n=" .. #names)
lib.ok("普通文件 normal.txt 可见", joined:find(root .. "/normal.txt", 1, true) ~= nil, "n=" .. #names)

-- 配置契约：树 + 文件查找都默认显示所有
local cfg = require("snacks").config.picker
lib.ok("explorer 默认 hidden+ignored",
  cfg.sources.explorer.hidden == true and cfg.sources.explorer.ignored == true,
  vim.inspect(cfg.sources.explorer))
lib.ok("files 默认 hidden+ignored",
  cfg.sources.files.hidden == true and cfg.sources.files.ignored == true,
  vim.inspect(cfg.sources.files))

local p = picker.get()[1]
if p then
  p:close()
end
vim.wait(200)

-- files 查找（<leader>ff）同样能看到被忽略的文件（需 fd/rg；find 回退不支持 ignored）
if vim.fn.executable("fd") == 1 or vim.fn.executable("rg") == 1 then
  picker.files({ cwd = root })
  local found = vim.wait(10000, function()
    local pf = picker.get()[1]
    if not pf then
      return false
    end
    for _, it in ipairs(pf:items()) do
      if it.file == "result/out.txt" or it.file == root .. "/result/out.txt" then
        return true
      end
    end
    return false
  end, 50)
  local pf = picker.get()[1]
  lib.ok("files 查找可见被忽略的 result/out.txt", found,
    "n=" .. (pf and #pf:items() or 0))
  if pf then
    pf:close()
  end
  vim.wait(200)
end

lib.finish()
