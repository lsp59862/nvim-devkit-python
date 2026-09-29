return {
  -- Mason：LSP / 格式化器统一安装源（版本由 install.sh 触发安装）
  {
    "williamboman/mason.nvim",
    cmd = "Mason",
    opts = { ui = { border = "rounded" } },
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "mason.nvim" },
    event = { "BufReadPre", "BufNewFile" },
    opts = { automatic_enable = true },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "mason.nvim" },
    event = "VeryLazy",
    opts = {
      ensure_installed = {
        "ruff",
        "lua-language-server",
        "bash-language-server",
        "json-lsp",
        "yaml-language-server",
        "stylua",
        "basedpyright", -- venv 安装失败时的兜底
      },
      auto_update = false,
      run_on_start = false,
    },
  },

  -- LSP 配置（Neovim 0.12 原生 vim.lsp.config / vim.lsp.enable）
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = { "saghen/blink.cmp" },
    config = function()
      vim.lsp.config("*", {
        capabilities = require("blink.cmp").get_lsp_capabilities(),
      })

      -- Python：优先使用 venv 里 pip 安装的 basedpyright（不依赖 Node）
      local venv_ls = vim.fn.stdpath("data") .. "/venv/bin/basedpyright-langserver"
      if vim.fn.executable(venv_ls) == 1 then
        vim.lsp.config("basedpyright", { cmd = { venv_ls, "--stdio" } })
      end
      -- 自动识别激活中的 conda / venv 环境（科研流程常先 conda activate）
      local interpreter = nil
      if vim.env.CONDA_PREFIX and vim.env.CONDA_PREFIX ~= "" then
        interpreter = vim.env.CONDA_PREFIX .. "/bin/python"
      elseif vim.env.VIRTUAL_ENV and vim.env.VIRTUAL_ENV ~= "" then
        interpreter = vim.env.VIRTUAL_ENV .. "/bin/python"
      end
      vim.lsp.config("basedpyright", {
        settings = {
          python = interpreter and { pythonPath = interpreter } or {},
          basedpyright = {
            analysis = {
              typeCheckingMode = "basic",
              autoSearchPaths = true,
              useLibraryCodeForTypes = true,
              diagnosticMode = "openFilesOnly",
              inlayHints = {
                variableTypes = false,
                functionReturnTypes = false,
                callArgumentNames = false,
              },
            },
          },
        },
        root_markers = { "pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", ".git" },
      })

      vim.lsp.config("ruff", {
        root_markers = { "pyproject.toml", "ruff.toml", ".ruff.toml", ".git" },
      })
      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            runtime = { version = "LuaJIT" },
            workspace = { checkThirdParty = false },
            telemetry = { enable = false },
          },
        },
      })

      vim.lsp.enable({ "basedpyright", "ruff", "lua_ls", "bashls", "jsonls", "yamlls" })

      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local buf = args.buf
          local map = function(lhs, rhs, desc)
            vim.keymap.set("n", lhs, rhs, { buffer = buf, desc = desc })
          end
          map("gd", vim.lsp.buf.definition, "跳转定义")
          map("gD", vim.lsp.buf.declaration, "跳转声明")
          map("gr", vim.lsp.buf.references, "查看引用")
          map("gi", vim.lsp.buf.implementation, "跳转实现")
          map("gy", vim.lsp.buf.type_definition, "跳转类型定义")
          map("K", vim.lsp.buf.hover, "悬停文档")
          map("<C-k>", vim.lsp.buf.signature_help, "签名帮助")
          map("<leader>cr", vim.lsp.buf.rename, "重命名符号")
          map("<leader>ca", vim.lsp.buf.code_action, "代码操作")
          map("<leader>cd", vim.diagnostic.open_float, "行诊断详情")
          map("[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, "上一个诊断")
          map("]d", function() vim.diagnostic.jump({ count = 1, float = true }) end, "下一个诊断")
        end,
      })
    end,
  },

  -- 补全（锁 1.x 稳定版；rust 匹配器不可用时自动退回 lua）
  {
    "saghen/blink.cmp",
    version = "1.*",
    dependencies = { "rafamadriz/friendly-snippets" },
    event = { "InsertEnter", "CmdlineEnter" },
    build = function()
      pcall(function()
        require("blink.cmp").build():pwait(30000)
      end)
    end,
    opts = {
      keymap = { preset = "default" },
      appearance = { nerd_font_variant = "mono" },
      completion = {
        documentation = { auto_show = false },
        ghost_text = { enabled = true },
      },
      sources = { default = { "lsp", "path", "snippets", "buffer" } },
      fuzzy = { implementation = "prefer_rust" },
      signature = { enabled = true },
    },
  },

  -- 格式化（手动触发，保存不自动改代码，避免"按一下世界变了"）
  {
    "stevearc/conform.nvim",
    cmd = { "ConformInfo" },
    keys = {
      {
        "<leader>cf",
        function()
          require("conform").format({ async = true, lsp_format = "fallback" })
        end,
        desc = "格式化当前文件",
      },
    },
    opts = {
      formatters_by_ft = {
        python = { "ruff_format" },
        lua = { "stylua" },
      },
      default_format_opts = { lsp_format = "fallback" },
      format_on_save = false,
    },
  },
}
