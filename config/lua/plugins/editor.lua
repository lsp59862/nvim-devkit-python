return {
  -- 编辑增强套件（textobject / 自动配对 / 环绕 / 注释 / 移动 / 括号跳转）
  {
    "echasnovski/mini.nvim",
    version = false,
    config = function()
      require("mini.ai").setup({ n_lines = 500 })
      require("mini.pairs").setup()
      require("mini.surround").setup()
      require("mini.comment").setup()
      require("mini.move").setup()
      require("mini.bracketed").setup()
    end,
  },

  -- 快速跳转（s 进入，任意标签跳转，Esc 随时取消）
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {
      modes = { search = { enabled = false } },
      labels = "asdfghjklqwertyuiopzxcvbnm",
    },
    keys = {
      { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash 跳转" },
      { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash 选择节点" },
      { "r", mode = "o", function() require("flash").remote() end, desc = "Flash 远程" },
      { "R", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Flash TS 搜索" },
    },
  },

  -- 撤销树：可视化所有历史版本（配合 :earlier 时间旅行）
  {
    "mbbill/undotree",
    cmd = "UndotreeToggle",
    init = function()
      vim.g.undotree_WindowLayout = 3
      vim.g.undotree_SetFocusWhenToggle = 1
      vim.g.undotree_ShortIndicators = 1
      vim.g.undotree_RelativeTimestamp = 1
      vim.g.undotree_SplitWidth = 35
    end,
    keys = {
      { "<leader>uu", "<cmd>UndotreeToggle<CR>", desc = "撤销树（所有历史版本）" },
    },
  },
}
