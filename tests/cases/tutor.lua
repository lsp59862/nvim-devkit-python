-- 官方教程恢复：lazy 的性能配置曾禁用 tutor 运行时插件
-- :Tutor 按系统语言自动选教程（本机 v:lang=zh_CN → 中文版）
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")

lib.ok(":Tutor 命令存在", vim.fn.exists(":Tutor") == 2, "exists=" .. vim.fn.exists(":Tutor"))

local ok, err = pcall(vim.cmd, "Tutor")
vim.wait(300)
lib.ok(":Tutor 可打开默认教程", ok, tostring(err))
if ok then
  lib.ok("打开的是 tutor buffer", vim.bo.filetype == "tutor",
    "filetype=" .. tostring(vim.bo.filetype) .. " name=" .. vim.fn.bufname())
  if vim.v.lang:match("^zh") then
    lib.ok("中文环境打开中文教程", vim.fn.bufname():find("/tutor/zh/", 1, true) ~= nil, vim.fn.bufname())
  end
end

lib.finish()
