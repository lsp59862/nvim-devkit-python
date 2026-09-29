return {
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      signs = {
        add = { text = "▎" },
        change = { text = "▎" },
        delete = { text = "" },
        topdelete = { text = "" },
        changedelete = { text = "▎" },
        untracked = { text = "▎" },
      },
      current_line_blame = false,
      on_attach = function(bufnr)
        local gs = require("gitsigns")
        local map = function(lhs, rhs, desc)
          vim.keymap.set("n", lhs, rhs, { buffer = bufnr, desc = desc, silent = true })
        end
        map("]c", function() gs.nav_hunk("next") end, "下一个改动")
        map("[c", function() gs.nav_hunk("prev") end, "上一个改动")
        map("<leader>gs", gs.stage_hunk, "暂存本处改动")
        map("<leader>gr", gs.reset_hunk, "撤销本处改动")
        map("<leader>gS", gs.stage_buffer, "暂存整个文件")
        map("<leader>gR", gs.reset_buffer, "撤销整个文件改动")
        map("<leader>gp", gs.preview_hunk, "预览本处改动")
        map("<leader>gb", function() gs.blame_line({ full = true }) end, "行 blame")
        map("<leader>gt", gs.toggle_current_line_blame, "行 blame 开关")
        map("<leader>gd", gs.diffthis, "与 HEAD 对比")
      end,
    },
  },
}
