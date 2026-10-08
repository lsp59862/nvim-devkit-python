-- 仓库内文档路径（兼容软链接安装）
local repo_path = require("nvim-devkit.paths").file

-- 用户强制开启图片时，给 snacks 指定探测结果：
-- 真 kitty/ghostty 走完整协议；WezTerm / VS Code 等无 Unicode 占位符的终端走 wezterm 模式
if vim.env.NVIM_DEVKIT_IMAGES == "1" then
  if vim.env.KITTY_WINDOW_ID or vim.env.GHOSTTY_RESOURCES_DIR then
    vim.env.SNACKS_KITTY = "true"
  else
    vim.env.SNACKS_WEZTERM = "true"
  end
end

return {
  -- 配色
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = { style = "night" },
    config = function(_, opts)
      require("tokyonight").setup(opts)
      vim.cmd.colorscheme("tokyonight")
    end,
  },

  -- 图标（snacks / lualine / render-markdown 共用）
  { "echasnovski/mini.icons", lazy = false, opts = { file = { default = false } } },

  -- 按键提示：按前缀后 200ms 弹出所有可能路径（可预测性的核心）
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      delay = 200,
      icons = { mappings = false, keys = {} },
      spec = {
        { "<leader>u", group = "撤销/恢复" },
        { "<leader>f", group = "文件" },
        { "<leader>s", group = "搜索" },
        { "<leader>g", group = "Git" },
        { "<leader>d", group = "调试(DAP)" },
        { "<leader>m", group = "Jupyter" },
        { "<leader>o", group = "opencode" },
        { "<leader>q", group = "会话" },
        { "<leader>w", group = "窗口" },
        { "<leader>c", group = "代码操作(LSP)" },
        { "<leader>r", group = "渲染/PDF" },
        { "<leader>b", group = "Buffer" },
        { "<leader>e", desc = "文件树" },
        { "<C-g>", desc = "恐慌重置" },
        { "<Esc>", desc = "清除搜索高亮" },
        { "Q", desc = "已禁用(防误触)" },
      },
    },
    config = function(_, opts)
      require("which-key").setup(opts)
      require("which-key").add(opts.spec)
    end,
  },

  -- 命令行/消息弹窗：让每次操作都有可见反馈
  {
    "folke/noice.nvim",
    event = "VeryLazy",
    dependencies = { "MunifTanjim/nui.nvim" },
    opts = {
      cmdline = { view = "cmdline_popup" },
      messages = { enabled = true },
      presets = { long_message_to_split = true, lsp_doc_border = true },
    },
  },

  -- 全套基础组件：picker / explorer / image / terminal / notifier / dashboard ...
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    opts = {
      bigfile = { enabled = true },
      dashboard = {
        enabled = true,
        sections = {
          { section = "header" },
          {
            pane = 2,
            section = "keys",
            gap = 1,
            padding = 1,
          },
          { section = "startup" },
        },
        preset = {
          header = table.concat({
            "                                     ",
            "  nvim-devkit  ·  科研版 Neovim      ",
            "  <C-g> 恐慌重置 · <leader>e 文件树   ",
            "                                     ",
          }, "\n"),
          keys = {
            { icon = "", key = "e", desc = "文件树", action = ":lua Snacks.explorer()" },
            { icon = "", key = "f", desc = "查找文件", action = ":lua Snacks.picker.smart()" },
            { icon = "", key = "g", desc = "全项目搜索", action = ":lua Snacks.picker.grep()" },
            { icon = "", key = "u", desc = "撤销树", action = ":UndotreeToggle" },
            { icon = "", key = "r", desc = "恢复会话", action = ":lua require('persistence').load()" },
            -- 覆盖 snacks 默认的 q→<cmd>bd（会绕过 winbuf 接管并销毁启动页）：q 与 :q 一致
            { icon = "", key = "q", desc = "退出 / 关当前 tab（同 :q）", action = ":q" },
            { icon = "", key = "?", desc = "快捷键大全", action = ":lua Snacks.picker.keymaps()" },
            { icon = "", key = "c", desc = "速查卡（救命键位）", action = ":e " .. repo_path("docs/CHEATSHEET.md") },
            { icon = "", key = "l", desc = "学习计划", action = ":e " .. repo_path("docs/LEARNING.md") },
          },
        },
      },
      explorer = { enabled = true, replace_netrw = true },
      -- snacks.image 只支持 Kitty 图形协议；默认开启，由 snacks 查询终端自行识别
      -- （NVIM_DEVKIT_IMAGES=0 可关闭；sixel 终端请用 molten/image.nvim 路径）
      image = {
        enabled = vim.env.NVIM_DEVKIT_IMAGES ~= "0",
        doc = { inline = true, float = true },
      },
      indent = { enabled = true },
      input = { enabled = true },
      notifier = { enabled = true, timeout = 3000 },
      picker = { enabled = true, ui_select = true },
      quickfile = { enabled = true },
      scope = { enabled = true },
      scroll = { enabled = true },
      statuscolumn = { enabled = true },
      terminal = { enabled = true },
      words = { enabled = true },
      git = { enabled = true },
      gitbrowse = { enabled = true },
      lazygit = { enabled = true },
      styles = { notification = { wo = { wrap = true } } },
    },
  },

  -- 状态栏：模式 / 宏录制 / opencode 状态
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = { "folke/tokyonight.nvim" },
    opts = function()
      local function macro_rec()
        local reg = vim.fn.reg_recording()
        if reg ~= "" then
          return "● 录制 @" .. reg
        end
        return ""
      end
      local function opencode_status()
        -- 不触发懒加载：仅在 opencode 已加载时显示
        if package.loaded["opencode"] then
          local ok, s = pcall(function()
            return require("opencode").statusline()
          end)
          if ok and s then
            return s
          end
        end
        return ""
      end
      return {
        options = {
          theme = "auto",
          globalstatus = true,
          section_separators = "",
          component_separators = "|",
          disabled_filetypes = { statusline = { "dashboard", "snacks_dashboard", "snacks_terminal" } },
        },
        sections = {
          lualine_a = { "mode" },
          lualine_b = { "branch", "diff" },
          lualine_c = { { "filename", path = 1 } },
          lualine_x = { macro_rec, opencode_status, "diagnostics", "filetype" },
          lualine_y = { "progress" },
          lualine_z = { "location" },
        },
      }
    end,
  },

  -- 会话恢复：重启/断线后回到现场
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts = {},
  },
}
