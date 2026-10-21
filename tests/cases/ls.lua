-- :ls 缓冲区列表：cwd 相对路径 + 同名去歧义
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")
local ls = require("nvim-devkit.ls")

local d = lib.dir()
local root = d .. "/lsproj"
vim.fn.mkdir(root .. "/v7.4/logs", "p")
vim.fn.mkdir(root .. "/v7.5/logs", "p")
vim.fn.mkdir(root .. "/src", "p")
vim.fn.writefile({ "epoch 1" }, root .. "/v7.4/logs/train.log")
vim.fn.writefile({ "epoch 2" }, root .. "/v7.5/logs/train.log")
vim.fn.writefile({ "print(1)" }, root .. "/src/main.py")
vim.cmd("cd " .. vim.fn.fnameescape(root))

local b1 = vim.fn.bufadd(root .. "/v7.4/logs/train.log")
local b2 = vim.fn.bufadd(root .. "/v7.5/logs/train.log")
local b3 = vim.fn.bufadd(root .. "/src/main.py")
for _, b in ipairs({ b1, b2, b3 }) do
  vim.bo[b].buflisted = true
end
vim.fn.bufload(b3)
vim.cmd("buffer " .. b3)

local lines = ls.lines()
local text = table.concat(lines, "\n")
lib.ok("同名文件保留区分目录（v7.4 / v7.5）",
  text:find("v7.4", 1, true) ~= nil and text:find("v7.5", 1, true) ~= nil, text)
lib.ok("cwd 内使用 ./ 相对路径", text:find("./src/main.py", 1, true) ~= nil, text)
lib.ok("不再出现 ~ 前缀", text:find("~/", 1, true) == nil, text)
local main_line
for _, l in ipairs(lines) do
  if l:find("./src/main.py", 1, true) then
    main_line = l
  end
end
lib.ok("当前 buffer 带 % 标记", main_line ~= nil and main_line:find("%", 1, true) ~= nil,
  main_line or "(未找到 main.py 行)")

local l74, l75
for _, l in ipairs(lines) do
  if l:find("train.log", 1, true) then
    if l:find("v7.4", 1, true) then l74 = l end
    if l:find("v7.5", 1, true) then l75 = l end
  end
end
lib.ok("同名条目显示为不同路径", l74 ~= nil and l75 ~= nil and l74 ~= l75,
  (l74 or "nil") .. " | " .. (l75 or "nil"))

-- 工作目录外 → 绝对路径
local out = d .. "/outside/nested.txt"
vim.fn.mkdir(d .. "/outside", "p")
vim.fn.writefile({ "x" }, out)
local b4 = vim.fn.bufadd(out)
vim.bo[b4].buflisted = true
local text2 = table.concat(ls.lines(), "\n")
lib.ok("工作目录外显示绝对路径", text2:find(out, 1, true) ~= nil, text2)

-- :Ls → 通知（标题 buffers）
local notified
local orig_notify = vim.notify
vim.notify = function(msg, _level, opts)
  notified = { msg = msg, title = opts and opts.title }
end
vim.cmd("Ls")
vim.notify = orig_notify
lib.ok(":Ls 以通知展示且标题为 buffers", notified ~= nil and notified.title == "buffers",
  vim.inspect(notified and notified.title))
lib.ok("通知内容包含相对路径", notified ~= nil and notified.msg:find("./src/main.py", 1, true) ~= nil,
  notified and notified.msg or "")

lib.finish()
