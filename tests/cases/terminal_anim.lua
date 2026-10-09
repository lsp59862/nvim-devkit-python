-- 中心展开动画：点 → 中线 → 上下分裂 → 侧栏左展；每帧强制刷屏
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")
local term = require("nvim-devkit.term")
term.setup()

-- stub nvim__redraw 计数并自检（防止 stub 没生效导致假通过）
local real_redraw = vim.api.nvim__redraw
local flushes = 0
vim.api.nvim__redraw = function(...)
  flushes = flushes + 1
  return real_redraw(...)
end
local probe_before = flushes
pcall(vim.api.nvim__redraw, { flush = true })
lib.ok("redraw stub 生效", flushes == probe_before + 1, ("%d→%d"):format(probe_before, flushes))

lib.reset()
term.summon("float")
local first, last
local uniq, seen = {}, {}
for _ = 1, 55 do
  local w = term.main_win("float")
  if w then
    local c = vim.api.nvim_win_get_config(w)
    if first == nil then
      first = { w = c.width, h = c.height, border = c.border, row = c.row }
    end
    last = { w = c.width, h = c.height, border = c.border, row = c.row }
    if not seen[c.row] then
      seen[c.row] = true
      uniq[#uniq + 1] = c.row
    end
  end
  vim.wait(10)
end
vim.wait(300)
local fin = vim.api.nvim_win_get_config(term.main_win("float"))
lib.ok("首帧是屏幕中心的 1×1 点（无边框）",
  first ~= nil and first.w == 1 and first.h == 1 and first.border == "none",
  vim.inspect(first))
lib.ok("宽度展开到终值", last ~= nil and last.w == fin.width, ("last=%s fin=%s"):format(tostring(last and last.w), tostring(fin.width)))
lib.ok("多帧推进（不同 row ≥ 6）", #uniq >= 6, ("uniq=%d rows=%s"):format(#uniq, table.concat(uniq, ",")))
lib.ok("动画终点：带边框、高度与 row 到位",
  last ~= nil and type(last.border) == "table" and last.h == fin.height and uniq[#uniq] == fin.row,
  ("h=%s/%s row=%s/%s border=%s"):format(tostring(last and last.h), tostring(fin.height),
    tostring(uniq[#uniq]), tostring(fin.row), tostring(last and type(last.border))))

local before_close = flushes
term.summon("float") -- 折叠动画
local close_borders, close_min_w, close_min_h = {}, nil, nil
for _ = 1, 55 do
  local w = term.main_win("float")
  if w then
    local c = vim.api.nvim_win_get_config(w)
    close_borders[type(c.border)] = true
    close_min_w = math.min(close_min_w or 99, c.width)
    close_min_h = math.min(close_min_h or 99, c.height)
  end
  vim.wait(10)
end
vim.wait(300)
lib.ok("折叠为切入的镜像（先带边框收线，再化线为点）",
  close_borders.table == true and close_borders.string == true, vim.inspect(close_borders))
lib.ok("折叠收成 1×1 点后才消失", close_min_w == 1 and close_min_h == 1,
  ("min_w=%s min_h=%s"):format(tostring(close_min_w), tostring(close_min_h)))
lib.ok("折叠动画每帧刷屏（flush ≥ 10）", flushes - before_close >= 10, "flushes=" .. (flushes - before_close))
lib.ok("折叠后回到收起状态", not term.visible("float"))

vim.api.nvim__redraw = real_redraw
for _, t in ipairs(term.terms()) do
  term.kill(t.id)
end
vim.wait(400)
lib.finish()
