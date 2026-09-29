#!/usr/bin/env bash
# nvim-devkit 卸载：只清理用户目录内的链接与安装物，不动系统包与项目
set -euo pipefail

APPNAME="nvim-devkit"
PREFIX="${NVIM_DEVKIT_PREFIX:-$HOME/.local}"
BIN="$PREFIX/bin"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/$APPNAME"
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/$APPNAME"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/$APPNAME"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { printf '\033[1;34m[nvim-devkit]\033[0m %s\n' "$*"; }

if [[ -L "$CONF_DIR" ]]; then
  target="$(readlink -f "$CONF_DIR")"
  if [[ "$target" == "$ROOT/config" ]]; then
    rm -f "$CONF_DIR"
    log "已移除配置链接 $CONF_DIR"
  else
    log "跳过 $CONF_DIR（链接指向别处）"
  fi
fi

rm -f "$BIN/nvim-devkit"
[[ -L "$BIN/nvim" ]] && rm -f "$BIN/nvim"
log "已移除启动器"

if grep -qF "# >>> nvim-devkit >>>" "$HOME/.bashrc" 2>/dev/null; then
  sed -i '/# >>> nvim-devkit >>>/,/# <<< nvim-devkit <<</d' "$HOME/.bashrc"
  log "已清理 ~/.bashrc PATH 配置"
fi

if [[ "${1:-}" == "--purge" ]]; then
  rm -rf "$DATA_DIR" "$STATE_DIR"
  log "已删除插件/venv/数据目录（--purge）"
else
  log "保留数据目录: $DATA_DIR（加 --purge 可一并删除）"
fi
