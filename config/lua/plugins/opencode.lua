return {
  {
    "nickjvandyke/opencode.nvim",
    version = "*",
    dependencies = {
      { "folke/snacks.nvim", optional = true },
    },
    keys = {
      {
        "<leader>oa",
        mode = { "n", "x" },
        function()
          require("opencode").ask("@this: ", { submit = true })
        end,
        desc = "询问 opencode（自动带上下文）",
      },
      {
        "<leader>os",
        mode = { "n", "x" },
        function()
          require("opencode").select()
        end,
        desc = "opencode 动作面板",
      },
      {
        "<leader>ot",
        mode = { "n", "t" },
        function()
          require("opencode").toggle()
        end,
        desc = "opencode 面板开关",
      },
      {
        "<leader>op",
        mode = { "n", "x" },
        function()
          require("opencode").prompt("@this ")
        end,
        desc = "发送 prompt（带上下文）",
      },
      {
        "<leader>of",
        mode = { "n", "x" },
        function()
          require("opencode").prompt("@buffer ")
        end,
        desc = "把整个 buffer 发给 opencode",
      },
      {
        "<leader>or",
        mode = { "n", "x" },
        function()
          return require("opencode").operator("@this ")
        end,
        expr = true,
        desc = "选中范围加入下一条消息",
      },
    },
    config = function()
      vim.o.autoread = true -- opencode 改文件后 buffer 自动刷新

      local term_opts = {
        interactive = true,
        auto_close = true,
        win = { position = "right", width = 0.42 },
      }
      local cmd = "opencode --port"

      vim.g.opencode_opts = {
        server = {
          start = function()
            require("snacks.terminal").open(cmd, term_opts)
          end,
          stop = function()
            local win = require("snacks.terminal").get(cmd, { create = false })
            if win then
              win:close()
            end
          end,
          toggle = function()
            require("snacks.terminal").toggle(cmd, term_opts)
          end,
        },
      }
    end,
  },
}
