return {
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "mfussenegger/nvim-dap-python",
      "theHamsta/nvim-dap-virtual-text",
    },
    keys = {
      { "<F5>", function() require("dap").continue() end, desc = "调试：启动/继续" },
      { "<F10>", function() require("dap").step_over() end, desc = "调试：单步跳过" },
      { "<F11>", function() require("dap").step_into() end, desc = "调试：单步进入" },
      { "<F12>", function() require("dap").step_out() end, desc = "调试：单步跳出" },
      { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "断点 开/关" },
      {
        "<leader>dB",
        function() require("dap").set_breakpoint(vim.fn.input("条件断点表达式: ")) end,
        desc = "条件断点",
      },
      { "<leader>dt", function() require("dap").terminate() end, desc = "结束调试" },
      { "<leader>dr", function() require("dap").repl.toggle() end, desc = "调试 REPL" },
      { "<leader>dl", function() require("dap").run_last() end, desc = "重跑上次调试" },
      { "<leader>dm", function() require("dap-python").test_method() end, desc = "调试当前测试方法" },
      { "<leader>dc", function() require("dap-python").test_class() end, desc = "调试当前测试类" },
    },
    config = function()
      -- 适配器用 devkit venv 里的 debugpy
      local adapter_py = vim.fn.stdpath("data") .. "/venv/bin/python3"
      if vim.fn.executable(adapter_py) ~= 1 then
        adapter_py = "python3"
      end
      require("dap-python").setup(adapter_py)

      -- 被调试的程序：优先当前项目的 conda / venv 环境
      require("dap-python").resolve_python = function()
        local conda = vim.env.CONDA_PREFIX
        if conda and conda ~= "" and vim.fn.executable(conda .. "/bin/python") == 1 then
          return conda .. "/bin/python"
        end
        local cwd = vim.fn.getcwd()
        for _, name in ipairs({ "venv", ".venv", "env", ".env" }) do
          local p = cwd .. "/" .. name .. "/bin/python"
          if vim.fn.executable(p) == 1 then
            return p
          end
        end
        local p = vim.fn.exepath("python3")
        return p ~= "" and p or "python3"
      end
    end,
  },

  {
    "igorlfs/nvim-dap-view",
    version = "1.*",
    dependencies = { "mfussenegger/nvim-dap" },
    opts = {},
    keys = {
      { "<leader>du", "<cmd>DapViewToggle<CR>", desc = "调试面板（变量/断点/栈）" },
    },
  },

  {
    "theHamsta/nvim-dap-virtual-text",
    dependencies = { "mfussenegger/nvim-dap" },
    opts = {},
  },

  {
    "mfussenegger/nvim-dap-python",
    dependencies = { "mfussenegger/nvim-dap" },
    lazy = true,
  },
}
