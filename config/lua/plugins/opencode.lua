-- opencode 集成（nickjvandyke/opencode.nvim）
-- 注意：插件的公开 API 只有 ask/select/prompt/command/operator/format/statusline，
-- 没有 require("opencode").toggle()（1.x 移除了）；面板开关直接操作
-- snacks.terminal 里承载 `opencode --port` 的那个终端实例。
local CMD = "opencode --port"

local function term_opts()
  return {
    interactive = true,
    auto_close = true,
    win = { position = "right", width = 0.42 },
  }
end

local function panel_toggle()
  require("snacks.terminal").toggle(CMD, term_opts())
end

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
          require("opencode").ask("@this: ")
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
        panel_toggle,
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

      vim.g.opencode_opts = {
        server = {
          start = function()
            require("snacks.terminal").open(CMD, term_opts())
          end,
          stop = function()
            local win = require("snacks.terminal").get(CMD, { create = false })
            if win then
              win:close()
            end
          end,
          toggle = panel_toggle,
        },
      }
    end,
  },
}
