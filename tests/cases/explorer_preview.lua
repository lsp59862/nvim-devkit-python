-- 文件浏览器预览模式：单一复用 buffer、焦点不动、文本/图片、被修改/关闭时清理
local lib = dofile((vim.env.NVIM_DEVKIT_TESTS or vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")) .. "/lib.lua")
local explorer = require("nvim-devkit.explorer")

lib.reset()
local parent = vim.api.nvim_get_current_win()
explorer.parent = parent
explorer.mode = true

-- 文本预览：显示在父窗口、不切焦点、buffe r不列出
local f1 = lib.dir() .. "/preview_a.lua"
vim.fn.writefile({ "print('a1')", "print('a2')" }, f1)
explorer.preview_item(nil, { file = f1 })
vim.wait(300, function() return explorer.buf ~= nil end, 20)
local b1 = explorer.buf
lib.ok("文本预览：父窗口显示预览 buffer", vim.api.nvim_win_get_buf(parent) == b1,
  ("winbuf=%s preview=%s"):format(tostring(vim.api.nvim_win_get_buf(parent)), tostring(b1)))
lib.ok("预览不切换焦点", vim.api.nvim_get_current_win() == parent,
  vim.inspect(vim.api.nvim_get_current_win()))
lib.ok("预览 buffer 不列出（且非 nofile，便于 modified 跟踪）",
  vim.bo[b1].buflisted == false and vim.bo[b1].buftype == "",
  ("buftype=%q listed=%s"):format(vim.bo[b1].buftype, tostring(vim.bo[b1].buflisted)))
lib.eq("文本内容正确", vim.api.nvim_buf_get_lines(b1, 0, 1, false)[1], "print('a1')")

-- 复用：换一个文本文件仍是同一个 buffer
local f2 = lib.dir() .. "/preview_b.py"
vim.fn.writefile({ "print('b1')" }, f2)
explorer.preview_item(nil, { file = f2 })
vim.wait(300)
lib.ok("文本预览复用同一 buffer", explorer.buf == b1, ("buf=%s→%s"):format(tostring(b1), tostring(explorer.buf)))
lib.eq("复用后内容更新", vim.api.nvim_buf_get_lines(b1, 0, 1, false)[1], "print('b1')")

-- 选中变化不自动预览（<CR> 才预览）：on_change 不应更新预览内容
explorer.on_change(nil, { file = f1 })
vim.wait(250)
lib.ok("移动选择不自动预览（内容保持不变）",
  explorer.buf == b1 and vim.api.nvim_buf_get_lines(b1, 0, 1, false)[1] == "print('b1')",
  ("buf=%s line=%s"):format(tostring(explorer.buf),
    tostring(explorer.buf and vim.api.nvim_buf_get_lines(explorer.buf, 0, 1, false)[1])))

-- 文本预览被修改 → 自动清理
-- （headless 的 luafile/vim.wait 上下文不会自动触发 BufModifiedSet；真实主循环会，
--   这里显式触发事件验证"事件 → 清理"的接线）
vim.api.nvim_exec_autocmds("BufModifiedSet", { buffer = b1 })
vim.wait(100, function()
  return not (explorer.buf and vim.api.nvim_buf_is_valid(explorer.buf))
end, 20)
lib.ok("文本预览被修改后自动删除", not (explorer.buf and vim.api.nvim_buf_is_valid(explorer.buf)),
  "buf=" .. tostring(explorer.buf))

-- 图片预览（需要 magick）：ft=image + 查看器状态（在父窗口显示、焦点不动）
if vim.fn.executable("magick") == 1 then
  local png = lib.dir() .. "/preview_img.png"
  vim.system({ "magick", "-size", "120x90", "xc:#3a7", png }):wait(10000)
  explorer.preview_item(nil, { file = png })
  vim.wait(300, function() return explorer.buf ~= nil end, 20)
  local ib = explorer.buf
  local st = require("nvim-devkit.viewer").state(ib)
  local ok = vim.wait(3000, function()
    return st ~= nil and st.view ~= nil
  end, 50)
  lib.ok("图片预览：查看器已渲染（预览 buffer 不挂 ft=image 键位）",
    ib ~= nil and ok and st.view ~= nil and vim.bo[ib].filetype ~= "image",
    ("ft=%s st=%s"):format(tostring(ib and vim.bo[ib].filetype), tostring(st ~= nil)))
  lib.ok("图片预览显示在父窗口、焦点不动",
    vim.api.nvim_win_get_buf(parent) == ib and vim.api.nvim_get_current_win() == parent,
    ("winbuf=%s cur=%s"):format(tostring(vim.api.nvim_win_get_buf(parent)), tostring(vim.api.nvim_get_current_win())))
  -- 图片之间复用同一 buffer
  local png2 = lib.dir() .. "/preview_img2.png"
  vim.system({ "magick", "-size", "100x80", "xc:#a37", png2 }):wait(10000)
  explorer.preview_item(nil, { file = png2 })
  vim.wait(300)
  lib.ok("图片预览复用同一 buffer", explorer.buf == ib,
    ("buf=%s→%s"):format(tostring(ib), tostring(explorer.buf)))
else
  lib.ok("图片预览（需要 ImageMagick，跳过）", true, "optional")
end

-- 回归：切图/切文本时删除旧 placement（旧图不得残留叠加）
do
  local viewer = require("nvim-devkit.viewer")
  local events = {}
  local orig_req7 = require("snacks.image").terminal.request
  Snacks.image.terminal.request = function(opts)
    if type(opts) == "table" and (opts.a == "p" or opts.a == "d") then
      events[#events + 1] = { a = opts.a, i = opts.i }
    end
    return orig_req7(opts)
  end
  -- 当前预览是图片：切换到文本预览时应删除当前图片的 placement
  local st_now = viewer.state(explorer.buf)
  local cur_id = st_now and st_now.img and st_now.img.id
  local tmix = lib.dir() .. "/preview_mix.lua"
  vim.fn.writefile({ "print('mix')" }, tmix)
  explorer.preview_item(nil, { file = tmix })
  vim.wait(400)
  local deleted = false
  for _, e in ipairs(events) do
    if e.a == "d" and e.i == cur_id then
      deleted = true
    end
  end
  lib.ok("切到文本预览时删除图片 placement（防旧图残留）",
    cur_id ~= nil and deleted, ("cur=%s events=%s"):format(tostring(cur_id), vim.inspect(events)))
  Snacks.image.terminal.request = orig_req7
end

-- 回归：预览 buffer 被手动关闭后，后续预览仍能恢复（不再永久失效）
do
  explorer.mode = true
  local p3 = lib.dir() .. "/preview_c.lua"
  vim.fn.writefile({ "print('c')" }, p3)
  explorer.preview_item(nil, { file = p3 })
  vim.wait(300)
  local bc = explorer.buf
  lib.ok("预览 buffer 创建", bc ~= nil and vim.api.nvim_buf_is_valid(bc), tostring(bc))
  if bc then
    pcall(vim.api.nvim_buf_delete, bc, { force = true })
  end
  vim.wait(100)
  local p4 = lib.dir() .. "/preview_d.lua"
  vim.fn.writefile({ "print('d')" }, p4)
  explorer.preview_item(nil, { file = p4 })
  vim.wait(500)
  local bd = explorer.buf
  lib.ok("手动关闭预览 buffer 后仍可继续预览（新 buffer）",
    bd ~= nil and vim.api.nvim_buf_is_valid(bd) and bd ~= bc
      and vim.api.nvim_buf_get_lines(bd, 0, 1, false)[1] == "print('d')",
    ("bc=%s bd=%s"):format(tostring(bc), tostring(bd)))
end

-- 回归：<CR> 与 l 行为一致（统一走 explorer.confirm）
-- 目录：无论是否预览模式都展开/折叠（picker:action("confirm")），不触发预览
local function fake_picker(item)
  local acts = {}
  local pk = {
    current = function()
      return item
    end,
    action = function(_, name)
      acts[#acts + 1] = name
    end,
  }
  return pk, acts
end

explorer.mode = true
local fdir = lib.dir() .. "/preview_dir"
vim.fn.mkdir(fdir, "p")
local pk_dir, acts_dir = fake_picker({ file = fdir, dir = true })
local buf_before = explorer.buf
explorer.confirm(pk_dir)
vim.wait(150)
lib.ok("预览模式下对目录 <CR>/l → 展开/折叠（不是预览）",
  acts_dir[1] == "confirm" and explorer.buf == buf_before,
  ("acts=%s buf=%s→%s"):format(vim.inspect(acts_dir), tostring(buf_before), tostring(explorer.buf)))

-- 文件 + 预览模式：只预览，不调用 confirm（不打开、不移焦点）
local ffile = lib.dir() .. "/preview_key.lua"
vim.fn.writefile({ "print('key')" }, ffile)
local pk_file, acts_file = fake_picker({ file = ffile })
explorer.confirm(pk_file)
vim.wait(300)
lib.ok("预览模式下对文件 <CR>/l → 预览、不打开",
  #acts_file == 0 and explorer.buf ~= nil
    and vim.api.nvim_buf_get_lines(explorer.buf, 0, 1, false)[1] == "print('key')",
  ("acts=%s buf=%s"):format(vim.inspect(acts_file), tostring(explorer.buf)))
lib.ok("预览模式下 <CR>/l 不移动焦点", vim.api.nvim_get_current_win() == parent,
  tostring(vim.api.nvim_get_current_win()))

-- 文件 + 正常模式：打开（confirm）并清掉预览
explorer.mode = false
local pk_norm, acts_norm = fake_picker({ file = ffile })
explorer.confirm(pk_norm)
vim.wait(100)
lib.ok("正常模式下对文件 <CR>/l → 打开并清理预览",
  acts_norm[1] == "confirm" and not (explorer.buf and vim.api.nvim_buf_is_valid(explorer.buf)),
  ("acts=%s buf=%s"):format(vim.inspect(acts_norm), tostring(explorer.buf)))
explorer.mode = true

-- 键位接线：真实 picker 的 list 键里 l 是我们的函数（不是默认 "confirm"）
local real = explorer.open({ layout = { preset = "sidebar", preview = false } })
vim.wait(500, function()
  return real ~= nil and real.opts ~= nil
end, 20)
lib.ok("文件树 list 键 l 已接管道 confirm（函数）",
  real ~= nil and real.opts ~= nil and type(real.opts.win.list.keys["l"]) == "function",
  type(real ~= nil and real.opts and real.opts.win and real.opts.win.list.keys["l"]))
-- 预览模式指示器：自定义 toggle 注册 + 跟随模式开关
lib.ok("标题栏注册预览模式指示器",
  real ~= nil and real.opts ~= nil and real.opts.toggles ~= nil
    and real.opts.toggles.nvkit_preview ~= nil and real.opts.nvkit_preview == true,
  vim.inspect(real and real.opts and real.opts.toggles))
if real then
  explorer.toggle(real) -- 关闭预览模式 → 指示器应消失
  lib.ok("关闭预览模式后指示器消失（opts 标记 false）",
    real.opts.nvkit_preview == false, tostring(real.opts.nvkit_preview))
  explorer.mode = true -- 恢复，供后续“关闭预览模式 → 清理”断言使用
end
if real then
  pcall(function()
    real:close()
  end)
end
vim.wait(100)

-- 关闭预览模式 → 清理
explorer.toggle(nil)
vim.wait(100)
lib.ok("关闭预览模式后删除预览 buffer",
  explorer.mode == false and not (explorer.buf and vim.api.nvim_buf_is_valid(explorer.buf)),
  ("mode=%s buf=%s"):format(tostring(explorer.mode), tostring(explorer.buf)))

lib.finish()
