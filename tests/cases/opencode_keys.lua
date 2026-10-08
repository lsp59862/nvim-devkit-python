-- opencode 集成回归：
-- 1) 插件 1.x 的公开 API 存在（曾把已移除的 require("opencode").toggle() 用在 <leader>ot 上）
-- 2) <leader>ot 走我们自己的 snacks.terminal 实现（用 stub 拦截，不真的开终端）
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")

-- 1) 插件可加载 + 我们用到的 API 存在
local ok, o = pcall(require, "opencode")
lib.ok("opencode 插件可加载", ok, not ok and tostring(o) or nil)
if ok then
  local detail = {}
  local all = true
  for _, fn in ipairs({ "ask", "select", "prompt", "operator" }) do
    detail[#detail + 1] = fn .. "=" .. type(o[fn])
    if type(o[fn]) ~= "function" then
      all = false
    end
  end
  lib.ok("公开 API 存在（ask/select/prompt/operator）", all, table.concat(detail, " "))
end

-- 2) <leader>ot 映射存在，且调用的是 snacks.terminal.toggle("opencode --port", 右侧面板)
local calls = {}
package.loaded["snacks.terminal"] = {
  toggle = function(cmd, opts)
    calls[#calls + 1] = { cmd = cmd, opts = opts }
  end,
  open = function() end,
  get = function() end,
}
local cb_n = vim.fn.maparg(" ot", "n", false, true).callback
local cb_t = vim.fn.maparg(" ot", "t", false, true).callback
lib.ok("<leader>ot 映射存在（n/t 模式）", cb_n ~= nil and cb_t ~= nil,
  ("n=%s t=%s"):format(tostring(cb_n ~= nil), tostring(cb_t ~= nil)))

if cb_n then
  local call_ok, err = pcall(cb_n)
  lib.ok("<leader>ot 调用不报错且命中 snacks.terminal.toggle",
    call_ok and calls[1] ~= nil and calls[1].cmd == "opencode --port",
    ("ok=%s err=%s cmd=%s"):format(tostring(call_ok), tostring(err), calls[1] and calls[1].cmd or "nil"))
  lib.ok("<leader>ot 面板在右侧（win.position=right）",
    calls[1] ~= nil and calls[1].opts ~= nil and calls[1].opts.win ~= nil and calls[1].opts.win.position == "right",
    vim.inspect(calls[1] and calls[1].opts or nil))
end

lib.finish()
