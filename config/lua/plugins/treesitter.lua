local parsers = require("nvim-devkit.parsers").list

return {
  {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      local ts = require("nvim-treesitter")
      local cfg = require("nvim-treesitter.config")
      local list_installed = cfg.get_installed or cfg.installed_parsers
      local installed = list_installed and list_installed() or {}
      local missing = vim.tbl_filter(function(p)
        return not vim.tbl_contains(installed, p)
      end, parsers)
      if #missing > 0 then
        ts.install(missing)
      end

      -- 有 parser 的 buffer 自动开启高亮
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("nvim_devkit_ts", { clear = true }),
        callback = function(args)
          local ft = vim.bo[args.buf].filetype
          local lang = vim.treesitter.language.get_lang(ft) or ft
          if vim.treesitter.language.add and pcall(vim.treesitter.language.add, lang) then
            pcall(vim.treesitter.start, args.buf, lang)
          end
        end,
      })
    end,
  },

  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch = "main",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    init = function()
      vim.g.no_plugin_maps = true
    end,
    config = function()
      require("nvim-treesitter-textobjects").setup({ select = { lookahead = true }, move = { set_jumps = true } })
      local select = require("nvim-treesitter-textobjects.select")
      local map = vim.keymap.set
      local function sel(obj)
        return function()
          select.select_textobject(obj, "textobjects")
        end
      end
      map({ "x", "o" }, "af", sel("@function.outer"), { desc = "函数整体" })
      map({ "x", "o" }, "if", sel("@function.inner"), { desc = "函数内部" })
      map({ "x", "o" }, "ac", sel("@class.outer"), { desc = "类整体" })
      map({ "x", "o" }, "ic", sel("@class.inner"), { desc = "类内部" })
    end,
  },
}
