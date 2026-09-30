-- tab = 工作区：每个 tab 拥有独立的文件列表（scope.nvim 通过 buflisted 切换实现）
-- 注意：同一文件在两个 tab 打开仍是同一个 buffer（内容/撤销共享），这是 Neovim 的全局 buffer 模型
-- 会话持久化由 nvim-devkit.scope_bridge 接管（scope 自带的序列化顺序不可靠）
return {
  {
    "tiagovla/scope.nvim",
    lazy = false,
    config = function()
      require("scope").setup({ restore_state = false })
      require("nvim-devkit.scope_bridge").setup()
    end,
  },
}
