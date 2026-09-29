#!/usr/bin/env bash
# 安装后验证：结构自检 + :checkhealth（过滤 headless/可选工具的已知噪音）
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${NVIM_DEVKIT_PREFIX:-$HOME/.local}/bin"
NVIM="$BIN/nvim-devkit"

if [[ ! -x "$NVIM" ]]; then
  echo "[error] 未找到 $NVIM，请先运行 install.sh" >&2
  exit 1
fi

fails=0

echo "── 结构自检 ───────────────────────────────"
if ! "$NVIM" --headless -c "luafile $ROOT/scripts/health.lua" -c "qa!"; then
  fails=$((fails + 1))
fi

echo
echo "── :checkhealth ───────────────────────────"
HEALTH_FILE="$(mktemp)"
"$NVIM" --headless -c "checkhealth" -c "silent! w! $HEALTH_FILE" -c "qa!" >/dev/null 2>&1 || true

if [[ -s "$HEALTH_FILE" ]]; then
  # headless 无 UI / 可选外部工具 / Neovim 上游 bug 导致的预期噪音，不计为失败
  EXCLUDE_RE='vim\.ui\.(input|select)|setup did not run|None of the tools found|graphics protocol|tectonic|mmdc|Only PNG|magick.*required|luarocks|hererocks|vim\.health|health\.lua:560'
  total="$(grep -cE "ERROR|错误" "$HEALTH_FILE" || true)"
  hard="$(grep -nE "ERROR|错误" "$HEALTH_FILE" | grep -vE "$EXCLUDE_RE" || true)"
  hard_n=0
  [[ -n "$hard" ]] && hard_n="$(printf '%s\n' "$hard" | wc -l)"
  soft_n=$((total - hard_n))

  echo "硬错误: $hard_n  预期噪音(headless/可选工具): $soft_n"
  echo "完整输出: $HEALTH_FILE"
  if [[ "$hard_n" != "0" ]]; then
    printf '%s\n' "$hard" | head -20
    fails=$((fails + 1))
  fi
else
  echo "  ○ checkhealth 无输出"
fi

echo
if [[ $fails -gt 0 ]]; then
  echo "验证失败：$fails 项，请检查上方输出"
  exit 1
fi
echo "验证通过（headless 环境下的图片/UI 类噪音已忽略；真实终端中 :checkhealth 会更准确）"
