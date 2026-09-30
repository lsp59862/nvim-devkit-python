-- nvim-devkit 行为测试辅助库
-- 由 tests/run.sh 通过 NVIM_DEVKIT_TESTS 环境变量定位
local M = { tests = 0, failures = 0 }

function M.ok(id, cond, detail)
  M.tests = M.tests + 1
  if cond then
    print(("[PASS] %s%s"):format(id, detail and (" — " .. tostring(detail)) or ""))
  else
    M.failures = M.failures + 1
    print(("[FAIL] %s%s"):format(id, detail and (" — " .. tostring(detail)) or ""))
  end
  return cond
end

function M.eq(id, got, want)
  return M.ok(id, got == want, ("got=%s want=%s"):format(tostring(got), tostring(want)))
end

function M.finish()
  print(("[SUMMARY] %d tests, %d failures"):format(M.tests, M.failures))
  os.exit(M.failures == 0 and 0 or 1)
end

--- 测试工作目录（run.sh 会创建并导出）
function M.dir()
  return vim.env.NVIM_DEVKIT_TEST_DIR or "/tmp/nvim-devkit-tests"
end

--- 生成测试用文件，返回绝对路径
function M.fixture(name, lines)
  local path = M.dir() .. "/" .. name
  vim.fn.writefile(lines or { name }, path)
  return path
end

--- 关浮窗 / 收 tab / 清 buffer / 单窗口，回到干净状态
function M.reset()
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(w).relative ~= "" then
      pcall(vim.api.nvim_win_close, w, true)
    end
  end
  vim.cmd("silent! tabonly")
  vim.cmd("silent! %bwipeout!")
  vim.cmd("silent! only")
end

--- 真实按键序列（配合 nvim_feedkeys(x) 使用；每个脚本只发一次，避免 headless 假象）
function M.keys(s)
  return vim.api.nvim_replace_termcodes(s, true, false, true)
end

--- 当前已列出的普通 buffer 的文件名（按名字排序，逗号连接）
function M.listed()
  local out = {}
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(b) and vim.bo[b].buflisted and vim.bo[b].buftype == "" then
      local n = vim.fn.bufname(b)
      out[#out + 1] = (n == "" and "[NoName]" or vim.fn.fnamemodify(n, ":t"))
    end
  end
  table.sort(out)
  return table.concat(out, ",")
end

--- 切到第 n 个 tab 后测量其列表
function M.listed_tab(n)
  vim.cmd("tabnext " .. n)
  return M.listed()
end

--- 真实分屏窗口数（不含通知等浮窗）
function M.wins()
  local n = 0
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_config(w).relative == "" then
      n = n + 1
    end
  end
  return n
end

function M.base(path)
  return vim.fn.fnamemodify(path, ":t")
end

--- 当前是否 dashboard
function M.is_dashboard()
  return vim.bo.filetype == "snacks_dashboard"
end

return M
