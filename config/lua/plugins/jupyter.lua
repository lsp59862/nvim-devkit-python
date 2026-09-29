return {
  -- 图片渲染后端（molten 输出 matplotlib 图用；kitty 或 sixel，均需 ImageMagick）
  -- backend 在使用时动态判定（支持 SSH 下的 WezTerm 等），cond 只做显式关闭
  {
    "3rd/image.nvim",
    lazy = true,
    cond = function()
      return vim.env.NVIM_DEVKIT_IMAGES ~= "0"
    end,
    rocks = { enabled = false },
    opts = function()
      local caps = require("nvim-devkit.caps")
      return {
        backend = caps.effective_backend() == "sixel" and "sixel" or "kitty",
        processor = "magick_cli",
        integrations = {
          markdown = { enabled = false },
          html = { enabled = false },
          neorg = { enabled = false },
        },
      }
    end,
  },

  -- Jupyter：在 .py 里按 cell 运行、图内嵌
  {
    "benlubas/molten-nvim",
    dependencies = { "3rd/image.nvim" },
    build = ":UpdateRemotePlugins",
    init = function()
      -- 防御：Jupyter runtime 目录不存在时 molten 内核连接文件会写入失败
      local data_home = vim.env.XDG_DATA_HOME or (vim.env.HOME .. "/.local/share")
      pcall(vim.fn.mkdir, vim.env.JUPYTER_RUNTIME_DIR or (data_home .. "/jupyter/runtime"), "p")
      vim.g.molten_virt_text_output = true -- 输出以虚拟文本展示，不抢焦点
      vim.g.molten_auto_open_output = false -- 不自动弹窗（可预测）
      vim.g.molten_auto_image_popup = false
      vim.g.molten_virt_text_max_lines = 20
      vim.g.molten_output_win_max_height = 24
      vim.g.molten_wrap_output = true
    end,
    config = function()
      -- provider 在使用时判定（此时可借助 snacks 的终端查询，SSH 下也能识别 WezTerm）
      local caps = require("nvim-devkit.caps")
      local backend = caps.effective_backend()
      vim.g.molten_image_provider = (backend ~= "none" and caps.has_magick()) and "image.nvim" or "none"
    end,
    keys = {
      { "<leader>mi", "<cmd>MoltenInit<CR>", desc = "初始化 Jupyter 内核" },
      { "<leader>ml", "<cmd>MoltenEvaluateLine<CR>", desc = "运行当前行" },
      { "<leader>mr", "<cmd>MoltenReevaluateCell<CR>", desc = "重跑当前 cell" },
      { "<leader>mv", mode = "x", "<cmd>MoltenEvaluateVisual<CR>gv", desc = "运行选中代码" },
      { "<leader>md", "<cmd>MoltenDelete<CR>", desc = "删除当前 cell 输出" },
      { "<leader>mo", "<cmd>MoltenShowOutput<CR>", desc = "显示输出" },
      { "<leader>mh", "<cmd>MoltenHideOutput<CR>", desc = "隐藏输出" },
      { "<leader>mx", "<cmd>MoltenInterrupt<CR>", desc = "中断运行" },
      { "<leader>mp", "<cmd>MoltenImagePopup<CR>", desc = "用系统查看器打开图片" },
    },
  },

  -- .ipynb 自动转 py/md（需要 venv 里的 jupytext CLI）
  {
    "goerz/jupytext.vim",
    ft = { "ipynb" },
    init = function()
      vim.g.jupytext_fmt = "py:percent"
    end,
  },
}
