-- 路径显示：相对工作目录 + 智能缩略（保留文件名、省略中间、同名去歧义）
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")
local pf = require("nvim-devkit.pathfmt")

local cwd = "/work/proj"
lib.eq("cwd 下相对路径加 ./ 前缀", pf.relative("/work/proj/a.lua", cwd), "./a.lua")
lib.eq("家目录用 ~ 前缀", pf.relative(vim.fn.expand("~/papers/x.lua"), cwd), "~/papers/x.lua")
lib.eq("短路径原样显示", pf.short("/work/proj/src/a.lua", { cwd = cwd, width = 60 }), "./src/a.lua")

local long = "/work/proj/viz/masks/v7_2/train/masks/mask.jpg"
local s = pf.short(long, { cwd = cwd, width = 30 })
lib.ok("长路径缩略：./ 前缀 + 保留文件名 + 省略中间",
  s:sub(1, 2) == "./" and s:find("…", 1, true) ~= nil and s:sub(-#"mask.jpg") == "mask.jpg"
    and s:find("viz/masks/v7_2", 1, true) == nil,
  s)
lib.ok("缩略结果不超过预算", vim.api.nvim_strwidth(s) <= 30, ("width=%d s=%s"):format(vim.api.nvim_strwidth(s), s))

-- 同名去歧义：保留各自不同的目录段
local a = "/work/proj/exp/v7_2/train/mask.jpg"
local b = "/work/proj/exp/v8_1/train/mask.jpg"
local sa = pf.short(a, { cwd = cwd, width = 40, siblings = { b } })
local sb = pf.short(b, { cwd = cwd, width = 40, siblings = { a } })
lib.ok("同名去歧义：标签不同且各自保留区分目录",
  sa ~= sb and sa:find("v7_2", 1, true) ~= nil and sb:find("v8_1", 1, true) ~= nil,
  sa .. " | " .. sb)
lib.ok("同名去歧义：都保留文件名", sa:sub(-#"mask.jpg") == "mask.jpg" and sb:sub(-#"mask.jpg") == "mask.jpg",
  sa .. " | " .. sb)

-- buffer_label：从 buffer 列表自动收集同名兄弟
lib.reset()
local root = vim.fn.getcwd()
local p1 = root .. "/exp/v7_2/train/mask.jpg"
local p2 = root .. "/exp/v8_1/train/mask.jpg"
local b1 = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(b1, p1)
local b2 = vim.api.nvim_create_buf(true, false)
vim.api.nvim_buf_set_name(b2, p2)
local l1 = pf.buffer_label(p1, 40)
local l2 = pf.buffer_label(p2, 40)
lib.ok("buffer_label 同名去歧义（自动收集兄弟）",
  l1 ~= l2 and l1:find("v7_2", 1, true) ~= nil and l2:find("v8_1", 1, true) ~= nil,
  l1 .. " | " .. l2)
lib.ok("buffer_label 保留文件名",
  l1:sub(-#"mask.jpg") == "mask.jpg" and l2:sub(-#"mask.jpg") == "mask.jpg", l1 .. " | " .. l2)

lib.finish()
