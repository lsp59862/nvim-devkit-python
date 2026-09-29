#!/usr/bin/env bash
# nvim-devkit installer — git clone && ./install.sh
# 全程安装到用户目录，无需 sudo；幂等，可重复执行。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPNAME="nvim-devkit"
PREFIX="${NVIM_DEVKIT_PREFIX:-$HOME/.local}"
BIN="$PREFIX/bin"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/$APPNAME"
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/$APPNAME"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/$APPNAME"
MIRROR="${NVIM_DEVKIT_MIRROR:-}"

DO_UPDATE=0 FORCE=0 DRY=0 WITH_OPENCODE=0 AS_DEFAULT=0 WITH_MAGICK=0

# shellcheck source=deps.lock
[[ -f "$ROOT/deps.lock" ]] && source "$ROOT/deps.lock"
NVIM_VERSION="${NVIM_VERSION:-v0.12.5}"

usage() {
  cat <<'EOF'
用法: ./install.sh [选项]

  --update          拉取仓库更新并同步插件/LSP/parser
  --force           配置目录已存在且非本仓库链接时，强制备份并覆盖
  --as-default      让 PATH 中的 `nvim` 指向 nvim-devkit
  --with-opencode   若缺少 opencode CLI 则顺带安装
  --with-magick     有 conda 时安装 ImageMagick（sixel/图片转换需要）
  --no-image        跳过图片相关依赖检测（纯文本终端）
  --mirror <URL>    使用 GitHub 镜像代理（如 https://gh-proxy.com）
  --dry-run         只打印将要执行的操作
  -h, --help        显示帮助
EOF
}

log() { printf '\033[1;34m[nvim-devkit]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }
err() { printf '\033[1;31m[error]\033[0m %s\n' "$*" >&2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --update) DO_UPDATE=1 ;;
    --force) FORCE=1 ;;
    --as-default) AS_DEFAULT=1 ;;
    --with-opencode) WITH_OPENCODE=1 ;;
    --with-magick) WITH_MAGICK=1 ;;
    --no-image) NO_IMAGE=1 ;;
    --mirror)
      MIRROR="$2"
      shift
      ;;
    --mirror=*) MIRROR="${1#*=}" ;;
    --dry-run) DRY=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      err "未知参数: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

no_image=0
[[ "${NO_IMAGE:-0}" == 1 ]] && no_image=1

run() {
  if [[ $DRY == 1 ]]; then
    log "[dry-run] $*"
    return 0
  fi
  "$@"
}

need_cmd() { command -v "$1" >/dev/null 2>&1; }

version_ge() { # version_ge <have> <need>
  [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -1)" == "$2" ]]
}

gh() { # 给 GitHub 下载地址套镜像
  local url="$1"
  if [[ -n "$MIRROR" ]]; then
    printf '%s/%s' "${MIRROR%/}" "$url"
  else
    printf '%s' "$url"
  fi
}

github_asset_url() { # repo pattern -> url（取最新 release 中第一个匹配资产）
  local repo="$1" pattern="$2"
  curl -fsSL --connect-timeout 10 "https://api.github.com/repos/$repo/releases/latest" 2>/dev/null |
    grep -oE '"browser_download_url": *"[^"]+"' |
    cut -d'"' -f4 |
    grep -Ei "$pattern" | head -1 || true
}

fetch_file() { # url destfile
  local url="$1" dest="$2" tmp
  tmp="$(mktemp -d)"
  mkdir -p "$(dirname "$dest")"
  if ! curl -fL --retry 3 --connect-timeout 15 --progress-bar -o "$tmp/archive" "$url"; then
    rm -rf "$tmp"
    return 1
  fi
  case "$url" in
    *.tar.gz | *.tgz) tar -xzf "$tmp/archive" -C "$tmp" ;;
    *.tar.xz) tar -xJf "$tmp/archive" -C "$tmp" ;;
    *.gz) gunzip -c "$tmp/archive" >"$tmp/extracted" ;;
    *.zip) unzip -q "$tmp/archive" -d "$tmp" ;;
    *)
      warn "未知压缩格式: $url"
      rm -rf "$tmp"
      return 1
      ;;
  esac
  local found=""
  if [[ -f "$tmp/extracted" ]]; then
    found="$tmp/extracted"
  else
    found="$(find "$tmp" -type f -name "$(basename "$dest")" -print -quit)"
  fi
  if [[ -z "$found" ]]; then
    warn "压缩包中未找到 $(basename "$dest"): $url"
    rm -rf "$tmp"
    return 1
  fi
  mv "$found" "$dest"
  chmod +x "$dest"
  rm -rf "$tmp"
}

install_github_bin() { # name repo pattern fallback_url [binname]
  local name="$1" repo="$2" pattern="$3" fallback="${4:-}" binname="${5:-$1}"
  if need_cmd "$binname"; then
    log "$binname 已存在（$(command -v "$binname")）"
    return 0
  fi
  if [[ -x "$BIN/$binname" ]]; then
    log "$binname 已安装"
    return 0
  fi
  local url=""
  url="$(github_asset_url "$repo" "$pattern")"
  if [[ -z "$url" ]]; then
    if [[ -n "$fallback" ]]; then
      warn "GitHub API 解析失败，使用固定版本安装 $name"
      url="$fallback"
    else
      warn "跳过 $name（无法解析下载地址）"
      return 1
    fi
  fi
  log "安装 $name …"
  if [[ $DRY == 1 ]]; then
    log "[dry-run] $url -> $BIN/$binname"
    return 0
  fi
  fetch_file "$(gh "$url")" "$BIN/$binname" || {
    warn "$name 安装失败（不影响其他组件）"
    return 1
  }
}

# ── 架构 ─────────────────────────────────────────────
case "$(uname -m)" in
  x86_64)
    ARCH_RG="x86_64"
    ARCH_FZF="amd64"
    ARCH_LG="x86_64"
    ARCH_NVIM="x86_64"
    ARCH_TS="x64"
    ;;
  aarch64 | arm64)
    ARCH_RG="aarch64"
    ARCH_FZF="arm64"
    ARCH_LG="arm64"
    ARCH_NVIM="arm64"
    ARCH_TS="arm64"
    ;;
  *)
    err "不支持的架构: $(uname -m)"
    exit 1
    ;;
esac

# ── 0. 预检 ──────────────────────────────────────────
log "预检环境 …"
mkdir -p "$BIN" "$DATA_DIR" "$STATE_DIR"
for c in git curl tar; do
  if ! need_cmd "$c"; then
    err "缺少基础命令: $c（无法安装）"
    exit 1
  fi
done
if need_cmd gcc || need_cmd cc; then
  log "C 编译器: OK（treesitter parser 可本地编译）"
else
  warn "未找到 gcc/cc，treesitter parser 可能编译失败；若有系统包管理器请安装 build-essential"
fi
OS_NAME="$( (. /etc/os-release 2>/dev/null && echo "$PRETTY_NAME") || uname -s)"
log "系统: $OS_NAME / $(uname -m)"

# ── 1. Neovim ────────────────────────────────────────
NVIM_BIN=""
if [[ -x "$DATA_DIR/nvim/bin/nvim" ]]; then
  NVIM_BIN="$DATA_DIR/nvim/bin/nvim"
  log "使用已安装的 Neovim: $("$NVIM_BIN" --version | head -1)"
elif need_cmd nvim && version_ge "$(nvim --version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)" "0.12.0"; then
  NVIM_BIN="$(command -v nvim)"
  log "使用系统 Neovim: $NVIM_BIN"
else
  log "下载 Neovim $NVIM_VERSION（官方静态包）…"
  if [[ $DRY == 1 ]]; then
    log "[dry-run] neovim $NVIM_VERSION -> $DATA_DIR/nvim"
  else
    url="$(gh "https://github.com/neovim/neovim/releases/download/$NVIM_VERSION/nvim-linux-$ARCH_NVIM.tar.gz")"
    tmp="$(mktemp -d)"
    if curl -fL --retry 3 --connect-timeout 15 --progress-bar -o "$tmp/nvim.tar.gz" "$url"; then
      tar -xzf "$tmp/nvim.tar.gz" -C "$tmp"
      rm -rf "$DATA_DIR/nvim"
      mv "$tmp"/nvim-linux-* "$DATA_DIR/nvim"
      rm -rf "$tmp"
      NVIM_BIN="$DATA_DIR/nvim/bin/nvim"
      log "Neovim 安装完成: $("$NVIM_BIN" --version | head -1)"
    else
      rm -rf "$tmp"
      err "Neovim 下载失败，请检查网络或用 --mirror 指定镜像"
      exit 1
    fi
  fi
fi

# ── 2. CLI 工具（rg / fd / fzf / lazygit / tree-sitter）──
log "检查命令行依赖 …"
install_github_bin rg BurntSushi/ripgrep "${ARCH_RG}-unknown-linux-musl\\.tar\\.gz$" "${ripgrep_fallback:-}" rg || true
install_github_bin fd sharkdp/fd "${ARCH_RG}-unknown-linux-musl\\.tar\\.gz$" "${fd_fallback:-}" fd || true
install_github_bin fzf junegunn/fzf "linux_${ARCH_FZF}\\.tar\\.gz$" "${fzf_fallback:-}" fzf || true
install_github_bin lazygit jesseduffield/lazygit "Linux_${ARCH_LG}\\.tar\\.gz$" "${lazygit_fallback:-}" lazygit || true
install_github_bin tree-sitter tree-sitter/tree-sitter "tree-sitter-linux-${ARCH_TS}\\.gz$" "${tree_sitter_fallback:-}" tree-sitter || true

if [[ $no_image == 0 ]]; then
  if need_cmd magick || need_cmd convert; then
    log "ImageMagick: OK（图片/PDF 图像渲染可用）"
  elif [[ $WITH_MAGICK == 1 ]] && need_cmd conda; then
    log "通过 conda 安装 ImageMagick（--with-magick）…"
    if [[ $DRY == 1 ]]; then
      log "[dry-run] conda create -y -n nvim-devkit-tools -c conda-forge imagemagick"
    else
      conda create -y -q -n nvim-devkit-tools -c conda-forge imagemagick || warn "conda 安装 ImageMagick 失败"
    fi
  else
    warn "未找到 ImageMagick（可选）：图片/PDF 图像渲染需要它"
    warn "  有 conda 的服务器: ./install.sh --with-magick；或系统安装 imagemagick"
  fi
fi

# ── 3. Python venv（debugpy / basedpyright / jupyter / pdf）──
setup_python() {
  local venv="$DATA_DIR/venv"
  local vpy=""

  venv_ready() {
    local c
    for c in "$venv/bin/python3" "$venv/bin/python"; do
      if [[ -x "$c" ]] && "$c" -c "import pip" >/dev/null 2>&1; then
        vpy="$c"
        return 0
      fi
    done
    return 1
  }

  if ! venv_ready; then
    rm -rf "$venv"
    if [[ $DRY == 1 ]]; then
      log "[dry-run] 创建 venv 并安装 Python 组件"
      return 0
    fi
    local -a cands=()
    local c p
    for c in python3 /usr/bin/python3; do
      p="$(command -v "$c" 2>/dev/null || true)"
      [[ -n "$p" ]] && cands+=("$p")
    done
    local created=0
    for p in "${cands[@]}"; do
      log "尝试用 $p 创建 venv …"
      if "$p" -m venv "$venv" >/dev/null 2>&1 && venv_ready; then
        created=1
        break
      fi
      rm -rf "$venv"
    done
    if [[ $created == 0 ]] && need_cmd uv; then
      log "尝试用 uv 创建 venv …"
      if uv venv "$venv" >/dev/null 2>&1 && venv_ready; then
        created=1
      fi
    fi
    if [[ $created == 0 ]]; then
      warn "venv 创建失败（尝试了 python3 / /usr/bin/python3 / uv）。调试/LSP/Jupyter 组件将不可用"
      warn "提示：Ubuntu 可安装 python3-venv，或使用 conda 环境中的 python3 重跑"
      return 0
    fi
  fi

  [[ -n "$vpy" ]] || return 0
  "$vpy" -m pip install -q --upgrade pip >/dev/null 2>&1 || true
  log "安装 Python 组件（debugpy / pynvim / jupyter_client / jupytext / basedpyright / pymupdf / ipykernel）…"
  if ! "$vpy" -m pip install -q --retries 3 --timeout 60 --disable-pip-version-check \
    debugpy pynvim jupyter_client jupytext basedpyright pymupdf ipykernel; then
    warn "部分 Python 包安装失败；可稍后手动: $vpy -m pip install <包名>"
  fi
  log "注册 Jupyter 内核（devkit-python）…"
  "$vpy" -m ipykernel install --prefix "$DATA_DIR/venv" --name devkit-python \
    --display-name "Python (nvim-devkit)" >/dev/null 2>&1 || warn "ipykernel 注册失败（molten 可手动选择其他内核）"
  # molten 会把内核连接文件写到 jupyter runtime 目录，目录不存在会导致内核启动失败
  "$vpy" -c "from jupyter_core.paths import jupyter_runtime_dir; import os; os.makedirs(jupyter_runtime_dir(), exist_ok=True)" 2>/dev/null || true
}
setup_python

# ── 4. 配置链接 + 启动器 ─────────────────────────────
if [[ -L "$CONF_DIR" ]]; then
  target="$(readlink -f "$CONF_DIR")"
  if [[ "$target" != "$ROOT/config" ]]; then
    err "$CONF_DIR 已链接到 $target，拒绝覆盖（先手动处理）"
    exit 1
  fi
elif [[ -e "$CONF_DIR" ]]; then
  if [[ $FORCE == 1 ]]; then
    log "备份已存在的 $CONF_DIR -> $CONF_DIR.bak.$(date +%s)"
    run mv "$CONF_DIR" "$CONF_DIR.bak.$(date +%s)"
  else
    err "$CONF_DIR 已存在。加 --force 备份后接管，或先手动移走"
    exit 1
  fi
fi
run mkdir -p "$BIN" "$DATA_DIR" "$STATE_DIR" "$(dirname "$CONF_DIR")"
run ln -sfn "$ROOT/config" "$CONF_DIR"

MAGICK_PATH=""
if need_cmd conda; then
  CONDA_BASE="$(conda info --base 2>/dev/null || true)"
  if [[ -n "$CONDA_BASE" && -d "$CONDA_BASE/envs/nvim-devkit-tools/bin" ]]; then
    MAGICK_PATH="$CONDA_BASE/envs/nvim-devkit-tools/bin:"
  fi
fi

if [[ -n "$NVIM_BIN" && $DRY == 0 ]]; then
  cat >"$BIN/nvim-devkit" <<EOF
#!/usr/bin/env bash
export NVIM_APPNAME="$APPNAME"
# BIN 优先（rg/fzf/lazygit 等）；venv 放末尾，保证 conda/项目 python 优先被解析
export PATH="$BIN:${MAGICK_PATH}\$PATH:$DATA_DIR/venv/bin"
exec "$NVIM_BIN" "\$@"
EOF
  chmod +x "$BIN/nvim-devkit"
  if [[ $AS_DEFAULT == 1 ]]; then
    ln -sfn nvim-devkit "$BIN/nvim"
    log "已设置默认 nvim -> nvim-devkit"
  fi
fi

# PATH 写入 bashrc（带 marker，幂等）
marker="# >>> nvim-devkit >>>"
if ! grep -qF "$marker" "$HOME/.bashrc" 2>/dev/null; then
  run bash -c "cat >> '$HOME/.bashrc' <<'RCDONE'

$marker
export PATH=\"$BIN:\$PATH\"
# <<< nvim-devkit <<<
RCDONE"
  log "已把 $BIN 加入 ~/.bashrc PATH（重开 shell 或 source ~/.bashrc 生效）"
else
  log "~/.bashrc PATH 已配置"
fi

if [[ $DRY == 1 ]]; then
  log "dry-run 结束（未做任何修改）"
  exit 0
fi

if [[ -z "$NVIM_BIN" ]]; then
  err "Neovim 未就绪，无法继续引导"
  exit 1
fi

# ── 5. 引导插件 / LSP / parser ───────────────────────
if [[ $DO_UPDATE == 1 ]] && [[ -d "$ROOT/.git" ]]; then
  log "拉取仓库更新 …"
  git -C "$ROOT" pull --ff-only || warn "git pull 失败（本地有改动？）"
fi

log "同步插件（按 lazy-lock.json 锁定版本；首次需几分钟）…"
if ! "$BIN/nvim-devkit" --headless "+Lazy! restore" +qa; then
  warn "restore 失败（可能没有 lockfile），改用 sync"
  "$BIN/nvim-devkit" --headless "+Lazy! sync" +qa || warn "插件同步存在失败项，可重跑 ./install.sh --update"
fi

log "注册远程插件（molten/Jupyter）…"
"$BIN/nvim-devkit" --headless "+Lazy load molten-nvim" "+UpdateRemotePlugins" +qa || warn "UpdateRemotePlugins 失败"

log "安装 LSP / 格式化工具（Mason，失败不致命）…"
"$BIN/nvim-devkit" --headless "+Lazy load mason.nvim mason-lspconfig.nvim mason-tool-installer.nvim" "+MasonToolsInstallSync" +qa || warn "Mason 有失败项（basedpyright 已由 venv 兜底）"

log "预编译 treesitter parser（16 核并行，通常 1-3 分钟）…"
"$BIN/nvim-devkit" --headless "+lua local ts=require('nvim-treesitter'); ts.install(require('nvim-devkit.parsers').list):wait(900000)" +qa || warn "部分 parser 编译失败，可稍后 :TSInstall 补装"

log "更新 treesitter parser（--update 时）…"
if [[ $DO_UPDATE == 1 ]]; then
  "$BIN/nvim-devkit" --headless "+lua require('nvim-treesitter').update():wait(900000)" +qa || warn "parser 更新有失败项"
fi

if [[ $WITH_OPENCODE == 1 ]] && ! need_cmd opencode && ! need_cmd "$HOME/.opencode/bin/opencode"; then
  log "安装 opencode CLI …"
  run bash -c 'curl -fsSL https://opencode.ai/install | bash' || warn "opencode 安装失败，请参考 https://opencode.ai"
fi

# ── 6. 验证 ──────────────────────────────────────────
log "运行安装验证 …"
if "$ROOT/scripts/checkhealth.sh"; then
  log "验证通过 ✓"
else
  warn "验证存在失败项，请查看上方输出"
fi

cat <<EOF

╭──────────────────────────────────────────────────────╮
│  nvim-devkit 安装完成                                │
│                                                      │
│  启动:              nvim-devkit                      │
│  学习计划:          $ROOT/docs/LEARNING.md
│  健康检查:          $ROOT/scripts/checkhealth.sh
│  更新:              $ROOT/install.sh --update
│  恐慌恢复:          Ctrl-g（任何时候按）             │
│  取消/关闭浮窗:     Esc                              │
╰──────────────────────────────────────────────────────╯
EOF
