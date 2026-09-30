#!/usr/bin/env bash
# nvim-devkit 行为测试运行器
#
# 用法：./tests/run.sh
#   · 使用仓库里的 config（通过 XDG_CONFIG_HOME 指向临时链接），不用管本机是否已安装
#   · 每个用例独立 nvim 进程；退出类用例(expect_exit=1)以"进程退出且无 [ALIVE]"判定通过
#   · 任何功能修改后都必须运行本脚本并全部通过（见 docs/TESTING.md 与 AGENTS.md）
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTS="$ROOT/tests"
WORK="${NVIM_DEVKIT_TEST_DIR:-/tmp/nvim-devkit-tests}"

# ── nvim 可执行文件 ──────────────────────────────────────────
NVIM_BIN="${NVIM_DEVKIT_BIN:-}"
if [[ -z "$NVIM_BIN" ]]; then
  if [[ -x "$HOME/.local/share/nvim-devkit/nvim/bin/nvim" ]]; then
    NVIM_BIN="$HOME/.local/share/nvim-devkit/nvim/bin/nvim"
  elif command -v nvim >/dev/null 2>&1; then
    NVIM_BIN="$(command -v nvim)"
  else
    echo "找不到 nvim：可用 NVIM_DEVKIT_BIN=/path/to/nvim 指定" >&2
    exit 2
  fi
fi

# ── 用仓库 config，不动本机安装 ─────────────────────────────
rm -rf "$WORK"
mkdir -p "$WORK/xdg-config"
ln -sfn "$ROOT/config" "$WORK/xdg-config/nvim-devkit"
export XDG_CONFIG_HOME="$WORK/xdg-config"
export NVIM_APPNAME="nvim-devkit"
export NVIM_DEVKIT_TESTS="$TESTS"
export NVIM_DEVKIT_TEST_DIR="$WORK"

pass=0
fail=0

run_case() {
  local name="$1" expect_exit="${2:-0}"
  local file="$TESTS/cases/$name.lua"
  local log="$WORK/log-$name.txt"
  echo "── $name"
  local out code
  out="$(timeout 120 "$NVIM_BIN" --headless -c "luafile $file" 2>&1)"
  code=$?
  printf '%s\n' "$out" >"$log"
  printf '%s\n' "$out" | grep -E '^\[(PASS|FAIL|SUMMARY)\]' || true

  if [[ "$expect_exit" == 1 ]]; then
    if printf '%s' "$out" | grep -q '\[ALIVE\]'; then
      echo "[FAIL] $name — 进程未按预期退出（功能回归）"
      tail -5 "$log"
      fail=$((fail + 1))
      return
    fi
    if [[ $code -ne 0 ]]; then
      echo "[FAIL] $name — 退出码=$code"
      tail -5 "$log"
      fail=$((fail + 1))
      return
    fi
    echo "[PASS] $name（期望退出 ✓）"
    pass=$((pass + 1))
    return
  fi

  if [[ $code -ne 0 ]] || printf '%s\n' "$out" | grep -q '^\[FAIL\]'; then
    echo "[FAIL] $name — 退出码=$code（日志：$log）"
    tail -8 "$log"
    fail=$((fail + 1))
  else
    pass=$((pass + 1))
  fi
}

# 顺序有依赖：session_save 必须在 session_load 之前；退出类放最后
run_case winbuf_file 0
run_case winbuf_typed_q 0
run_case winbuf_typed_qbang 0
run_case winbuf_typed_wq 0
run_case winbuf_typed_wq_multi 0
run_case winbuf_typed_x 0
run_case winbuf_typed_bd 0
run_case winbuf_typed_bd_bang 0
run_case winbuf_typed_bd_dashboard 0
run_case winbuf_typed_passthrough 0
run_case winbuf_user_scenario 0
run_case winbuf_dashboard_tab 0
run_case scope_isolation 0
run_case scope_quit 0
run_case scope_tabclose 0
run_case scope_session_save 0
run_case scope_session_load 0
run_case winbuf_exit_dashboard 1
run_case winbuf_exit_command 1

echo
echo "=================================================="
echo "结果：$pass 通过 / $fail 失败"
echo "=================================================="
[[ $fail -eq 0 ]]
