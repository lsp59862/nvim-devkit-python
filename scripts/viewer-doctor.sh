#!/usr/bin/env bash
# 查看器自检（远程排障用）：无需图形终端，检查环境与查看器装配状态并打印结果。
# 用法：~/nvim-devkit/scripts/viewer-doctor.sh
set -u

OUT="${NVIM_DEVKIT_DOCTOR_OUT:-/tmp/nvkit-viewer-doctor.txt}"

# nvim 可执行文件（优先官方安装位置）
NVIM_BIN="${NVIM_DEVKIT_BIN:-}"
if [[ -z "$NVIM_BIN" ]]; then
  if [[ -x "$HOME/.local/share/nvim-devkit/nvim/bin/nvim" ]]; then
    NVIM_BIN="$HOME/.local/share/nvim-devkit/nvim/bin/nvim"
  else
    NVIM_BIN="$(command -v nvim || true)"
  fi
fi
if [[ -z "$NVIM_BIN" ]]; then
  echo "找不到 nvim（可用 NVIM_DEVKIT_BIN=/path/to/nvim 指定）" >&2
  exit 2
fi

# 与启动器一致的 PATH（conda 里的 ImageMagick 等工具）
CONDA_BASE="${CONDA_PREFIX%/envs/*}"
for base in "$CONDA_BASE" "$HOME/anaconda3" "$HOME/miniconda3" "/data/lsp/anaconda3"; do
  if [[ -n "$base" && -d "$base/envs/nvim-devkit-tools/bin" ]]; then
    export PATH="$base/envs/nvim-devkit-tools/bin:$PATH"
    break
  fi
done

LUA="$(mktemp /tmp/nvkit-doctor-XXXXXX.lua)"
trap 'rm -f "$LUA"' EXIT
cat >"$LUA" <<'LUAEOF'
local png = "/tmp/nvkit-doctor-probe.png"
local b64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="
local f = assert(io.open(png, "wb"))
f:write(vim.base64.decode(b64))
f:close()
require("snacks.image").config.force = true
vim.cmd.edit(png)
vim.wait(2500)
local viewer = require("nvim-devkit.viewer")
local st = viewer.state(vim.api.nvim_get_current_buf())
local snacks_img = require("snacks.image")
local term = snacks_img.terminal.size()
local env = snacks_img.terminal.env()
local maps = {}
for _, m in ipairs(vim.api.nvim_buf_get_keymap(0, "n")) do
  maps[m.lhs] = true
end
local out = {
  commit = vim.trim(vim.fn.system({ "git", "-C", vim.fn.expand("~/nvim-devkit"), "log", "-1", "--format=%h %s" })),
  nvim = vim.version() and ("%d.%d.%d"):format(vim.version().major, vim.version().minor, vim.version().patch),
  filetype = vim.bo.filetype,
  magick = vim.fn.executable("magick"),
  convert = vim.fn.executable("convert"),
  cell = { w = term.cell_width, h = term.cell_height },
  env = {
    TERM = vim.env.TERM,
    TERM_PROGRAM = vim.env.TERM_PROGRAM,
    WEZTERM = vim.env.WEZTERM_PANE,
    KITTY = vim.env.KITTY_WINDOW_ID,
    GHOSTTY = vim.env.GHOSTTY_RESOURCES_DIR,
    VTE = vim.env.VTE_VERSION,
    TMUX = vim.env.TMUX,
    SSH = not not vim.env.SSH_CLIENT,
  },
  image_env = env,
  viewer = {
    has_state = st ~= nil,
    mode = st and st.mode,
    zoom = st and st.zoom,
    canvas = st and st.canvas_file,
    canvas_exists = st and st.canvas_file and vim.fn.filereadable(st.canvas_file) == 1 or false,
    hidden = st and st.image_hidden,
  },
  maps = maps,
  layout = { cmdheight = vim.o.cmdheight, laststatus = vim.o.laststatus, lines = vim.o.lines, columns = vim.o.columns },
}
local fd = assert(io.open(assert(os.getenv("NVIM_DEVKIT_DOCTOR_OUT")), "w"))
fd:write(vim.inspect(out))
fd:close()
LUAEOF

NVIM_APPNAME=nvim-devkit NVIM_DEVKIT_DOCTOR_OUT="$OUT" "$NVIM_BIN" --headless -c "luafile $LUA" -c "qa!" 2>&1 | tail -3

echo "──── 查看器自检（$OUT）────"
if [[ -f "$OUT" ]]; then
  cat "$OUT"
  echo
else
  echo "自检失败：未生成 $OUT"
  exit 1
fi
