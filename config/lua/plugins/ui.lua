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
    -- 默认主题是 nvkit-terminal（见 config/init.lua）；用 :colorscheme tokyonight 可随时切回
  },

  -- 图标（snacks / lualine / render-markdown 共用）
  { "echasnovski/mini.icons", lazy = false, opts = { file = { default = false } } },

  -- 按键提示：按前缀后 200ms 弹出所有可能路径（可预测性的核心）
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      delay = 200,
      preset = "classic",
      notify = false,
      icons = { mappings = false, keys = {} },
      -- 圆角卡片 + 居中标题，列宽收敛，和终端同款主题一致
      win = {
        border = "rounded",
        padding = { 0, 1 },
        title = true,
        title_pos = "center",
        height = { min = 4, max = 20 },
        wo = { winblend = 0, cursorline = false },
      },
      layout = { width = { min = 22, max = 34 }, spacing = 3 },
      spec = {
        { "<leader>u", group = "撤销/恢复", icon = { icon = "", hl = "WhichKeyIconPurple" } },
        { "<leader>f", group = "文件", icon = { icon = "󰈔", hl = "WhichKeyIconAzure" } },
        { "<leader>s", group = "搜索", icon = { icon = "", hl = "WhichKeyIconGreen" } },
        { "<leader>g", group = "Git", icon = { icon = "", hl = "WhichKeyIconOrange" } },
        { "<leader>d", group = "调试(DAP)", icon = { icon = "", hl = "WhichKeyIconRed" } },
        { "<leader>m", group = "Jupyter", icon = { icon = "", hl = "WhichKeyIconYellow" } },
        { "<leader>o", group = "opencode", icon = { icon = "󰚩", hl = "WhichKeyIconCyan" } },
        { "<leader>q", group = "会话", icon = { icon = "", hl = "WhichKeyIconBlue" } },
        { "<leader>w", group = "窗口", icon = { icon = "", hl = "WhichKeyIconBlue" } },
        { "<leader>c", group = "代码操作(LSP)", icon = { icon = "", hl = "WhichKeyIconCyan" } },
        { "<leader>r", group = "渲染/PDF", icon = { icon = "", hl = "WhichKeyIconPurple" } },
        { "<leader>b", group = "Buffer", icon = { icon = "󰈔", hl = "WhichKeyIconAzure" } },
        { "<leader>t", group = "终端面板", icon = { icon = "", hl = "WhichKeyIconRed" } },
        { "<leader>e", desc = "文件树", icon = { icon = "", hl = "WhichKeyIconAzure" } },
        { "<leader><space>", desc = "智能查找文件" },
        { "<leader>/", desc = "全项目搜索" },
        { "<C-g>", desc = "状态重置" },
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
        -- 自绘：带边框的双栏卡片（左=会话/最近文件，右=快捷操作，底=启动耗时/提示）
        -- 宽度按 dashboard 窗口实时计算，窗口缩放后自动重排
        sections = {
          function(self)
            return require("nvim-devkit.dashboard").section(self)
          end,
        },
        preset = {
          keys = require("nvim-devkit.dashboard").keys,
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
      picker = {
        enabled = true,
        ui_select = true,
        -- 文件树 / 文件查找默认显示所有文件：不被 .gitignore 过滤、不隐藏点文件
        -- （树内仍可按 Alt+i / Alt+h 临时反向切换；grep 保持默认，避免搜进 .git 等大目录）
        sources = {
          explorer = { hidden = true, ignored = true },
          files = { hidden = true, ignored = true },
          -- buffer 列表：相对工作目录显示；过长/同名时智能缩略（保留文件名与区分目录）
          buffers = {
            format = function(item, picker)
              local pf = require("nvim-devkit.pathfmt")
              local ret = {}
              ret[#ret + 1] = { ("%3d "):format(item.buf or 0), "SnacksPickerBufNr" }
              ret[#ret + 1] = { item.flags or "", "SnacksPickerBufFlags" }
              ret[#ret + 1] = { " " }
              local path = (item.file and item.file ~= "") and item.file or item.name or ""
              -- 显示宽度随 picker 窗口自适应（留出编号/标志前缀的空间）
              local bw = 60
              local ok, win = pcall(function()
                return picker.list and picker.list.win
              end)
              if ok and win and vim.api.nvim_win_is_valid(win) then
                bw = math.max(30, vim.api.nvim_win_get_width(win) - 24)
              end
              ret[#ret + 1] = { pf.buffer_label(path, bw), "SnacksPickerFile" }
              return ret
            end,
          },
        },
        -- 全局：所有选择器都能用 Alt+J/K 上下选择（输入框里也不用先打字）
        win = {
          input = {
            keys = {
              ["<M-j>"] = { "list_down", mode = { "i", "n" } },
              ["<M-k>"] = { "list_up", mode = { "i", "n" } },
            },
          },
          list = {
            keys = {
              ["<M-j>"] = "list_down",
              ["<M-k>"] = "list_up",
            },
          },
        },
      },
      quickfile = { enabled = true },
      scope = { enabled = true },
      scroll = { enabled = true },
      statuscolumn = { enabled = true },
      terminal = {
        enabled = true,
        win = { position = "float", width = 0.8, height = 0.8, border = "rounded" },
      },
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
      local function clock()
        return os.date("%H:%M")
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
      -- 状态栏时钟：lualine 不会自己按时间重绘，30 秒刷新一次（分钟精度足够）
      if not vim.g.nvkit_clock_timer then
        local timer = (vim.uv or vim.loop).new_timer()
        timer:start(30000, 30000, vim.schedule_wrap(function()
          pcall(vim.cmd, "redrawstatus")
        end))
        vim.g.nvkit_clock_timer = true
        _G.__nvkit_clock_timer = timer
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
          lualine_z = { "location", clock },
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
