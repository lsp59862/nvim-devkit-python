return {
  -- Markdown 内联渲染（标题/表格/引用/公式）
  {
    "MeanderingProgrammer/render-markdown.nvim",
    ft = { "markdown" },
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    opts = function()
      -- LaTeX 公式渲染依赖图片体系，只在支持图片的终端启用
      return {
        render_modes = { "n", "c", "t" },
        code = { sign = false, width = "block", right_pad = 1, border = "thin" },
        heading = {
          sign = false,
          icons = { "󰲡 ", "󰲣 ", "󰲥 ", "󰲧 ", "󰲩 ", "󰲫 " },
        },
        checkbox = { enabled = true },
        -- 公式渲染依赖 snacks.image（Kitty 协议），运行时探测终端
        latex = { enabled = require("nvim-devkit.caps").effective_backend() == "kitty" },
      }
    end,
  },

  { "nvim-tree/nvim-web-devicons", lazy = true, opts = {} },

  -- CSV/TSV 表格视图（粘性表头、分隔符自动识别）
  {
    "hat0uma/csvview.nvim",
    ft = { "csv", "tsv" },
    cmd = { "CsvViewEnable", "CsvViewDisable", "CsvViewToggle" },
    opts = {
      parser = { comments = { "#", "//" } },
      view = {
        display_mode = "border",
        sticky_header = { enabled = true },
      },
    },
    config = function(_, opts)
      require("csvview").setup(opts)
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "csv", "tsv" },
        callback = function()
          require("csvview").enable()
        end,
      })
      if vim.tbl_contains({ "csv", "tsv" }, vim.bo.filetype) then
        require("csvview").enable()
      end
    end,
  },
}
