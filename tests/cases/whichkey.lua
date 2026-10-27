-- leader 菜单（which-key）：classic 网格 + 圆角边框 + 主题配色
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")

pcall(function()
  require("lazy").load({ plugins = { "which-key.nvim" } })
end)
vim.wait(2000, function()
  return package.loaded["which-key.config"] ~= nil
end, 50)

local ok, cfg = pcall(function()
  return require("which-key.config").options
end)
lib.ok("which-key 已加载并完成配置", ok and type(cfg) == "table",
  ok and type(cfg) or tostring(cfg))
lib.ok("圆角边框 + 居中标题",
  ok and cfg.win and cfg.win.border == "rounded" and cfg.win.title == true,
  vim.inspect(ok and cfg.win and { border = cfg.win.border, title = cfg.win.title }))
lib.ok("列宽收敛（22~34）",
  ok and cfg.layout and cfg.layout.width
    and cfg.layout.width.min == 22 and cfg.layout.width.max == 34,
  vim.inspect(ok and cfg.layout and cfg.layout.width))

local wkfloat = vim.api.nvim_get_hl(0, { name = "WhichKeyFloat", link = false })
local wkgroup = vim.api.nvim_get_hl(0, { name = "WhichKeyGroup", link = false })
lib.ok("主题为 leader 菜单定义了配色", wkfloat.bg ~= nil and wkgroup.fg ~= nil,
  ("float.bg=%s group.fg=%s"):format(tostring(wkfloat.bg), tostring(wkgroup.fg)))

lib.finish()
