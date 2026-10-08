# nvim-devkit

**一台服务器、一条命令、一个配置齐全的科研版 Neovim。**

面向 Python/CV 科研（VisDrone 类）的 Neovim 发行版：`git clone` + `./install.sh` 即可在任意 Linux 服务器（无 sudo）装好，包含文件浏览、Markdown/CSV/PDF 渲染、LSP、调试、Jupyter 内核、Git 与 opencode 集成，并针对"误按之后无法恢复"做了系统性的可恢复性设计。

## 文档

| 文档 | 用途 |
| --- | --- |
| `docs/CHEATSHEET.md` | **一页速查卡**：救命键位、键位地图、科研流程、故障排除（建议打印/贴屏；启动页按 `c` 直达） |
| `docs/LEARNING.md` | 3 周学习计划 + 误按恢复手册 |
| `docs/TESTING.md` | 行为测试说明与用例清单（改功能必跑 `./tests/run.sh`） |
| `README.md`（本文） | 部署、更新、卸载与定制 |

## 快速开始

```bash
git clone git@github.com:lsp59862/nvim-devkit-python.git ~/nvim-devkit
cd ~/nvim-devkit
./install.sh
nvim-devkit          # 启动（不影响服务器上已有的 nvim 配置）
```

首次安装会下载 Neovim 0.12、静态 CLI 工具（rg/fd/fzf/lazygit/tree-sitter）、创建独立 Python venv、按 `lazy-lock.json` 安装插件、编译 treesitter parser、安装 LSP。通常 5-10 分钟。

### 安装器选项

| 选项 | 作用 |
| --- | --- |
| `--update` | 拉取仓库更新并同步插件/LSP/parser |
| `--force` | 配置目录被占用时备份并接管 |
| `--as-default` | 让 `nvim` 命令指向 nvim-devkit |
| `--with-opencode` | 缺少 opencode CLI 时顺带安装 |
| `--mirror <URL>` | GitHub 镜像（如 `https://gh-proxy.com`） |
| `--no-image` | 纯文本终端模式（跳过图片依赖检查） |
| `--dry-run` | 只打印将要执行的操作 |

### 日常命令

```bash
nvim-devkit                            # 启动
~/nvim-devkit/scripts/checkhealth.sh   # 健康检查
~/nvim-devkit/install.sh --update      # 更新
~/nvim-devkit/uninstall.sh [--purge]   # 卸载（--purge 连数据目录一起删）
```

## 部署与更新

### 部署到新服务器

公开仓库，直接克隆即可（无需任何凭据）：

```bash
git clone git@github.com:lsp59862/nvim-devkit-python.git ~/nvim-devkit
# 或 HTTPS：
# git clone https://github.com/lsp59862/nvim-devkit-python.git ~/nvim-devkit
cd ~/nvim-devkit && ./install.sh
```

<details>
<summary>附注：如果你 fork 后设为私有，需要给目标服务器配置访问凭据</summary>

把目标服务器的 SSH 公钥加到 GitHub（仓库 → Settings → Deploy keys，或账号 → Settings → SSH and GPG keys）：

```bash
ssh-keygen -t ed25519 -C "$(hostname)"   # 已有密钥可跳过
cat ~/.ssh/id_ed25519.pub                # 粘贴到 GitHub 后：
git clone git@github.com/<你的账号>/nvim-devkit-python.git ~/nvim-devkit
```

没有 SSH 条件时可用 HTTPS + PAT（fine-grained 只需该仓库的 Contents: Read），克隆后记得清掉 URL 里的 PAT：
`git -C ~/nvim-devkit remote set-url origin https://github.com/<你的账号>/nvim-devkit-python.git`

</details>

### 更新已有服务器

```bash
cd ~/nvim-devkit
./install.sh --update     # 自动 git pull + 插件/LSP/parser 同步
```

### 修改配置的工作流（本机改 → 推送到所有服务器）

```bash
# ① 本机（有编辑环境的机器）
cd ~/nvim-devkit
#   改 config/lua/... 下的配置，存盘即生效，自测：
~/nvim-devkit/scripts/checkhealth.sh
git add -A && git commit -m "描述你的改动" && git push

# ② 每台服务器
cd ~/nvim-devkit && ./install.sh --update
```

`config/lazy-lock.json` 与 `deps.lock` 随仓库同步，保证所有服务器插件与工具版本一致。

## 功能一览

| 场景 | 方案 |
| --- | --- |
| 文件浏览 / 搜索 | snacks.explorer + snacks.picker（40+ 数据源，取代 netrw/telescope/neo-tree） |
| 代码高亮 | nvim-treesitter（main 分支，parser 本地编译） |
| 补全 | blink.cmp（锁 1.x 稳定版，rust 匹配器不可用时自动降级 Lua） |
| LSP | basedpyright + ruff + lua_ls + bashls + jsonls + yamlls（自动识别 conda/venv） |
| 调试 | nvim-dap + dap-view + nvim-dap-python（F5 起调，自动用项目环境） |
| Jupyter | molten-nvim + jupytext（`.py` 里跑 cell、输出内嵌；内核 `devkit-python`） |
| Markdown | render-markdown（标题/表格/公式内联渲染） |
| CSV | csvview（表格线、粘性表头、分隔符自动识别） |
| PDF | 文本双栏提取（任何终端）+ Kitty 终端下的图片模式（`<leader>rt`） |
| Git | gitsigns + lazygit 浮窗 + gitbrowse |
| AI | opencode.nvim（`<leader>oa` 提问并注入当前上下文，编辑 diff 审阅） |
| 终端 | 浮动 / 底部 / 多开 + 列表（`<leader>tt`/`tn`/`tb`/`tl`；`2tt` 第二台，终端内 `<M-j>`/`<M-k>` 循环切换） |
| 会话 | persistence（退出时自动存现场；`<leader>qs`/`ql` 恢复，`qd`/`qe` 开关） |
| 恢复 | 持久化撤销 + undotree + `:earlier 10m` + `Ctrl-g` 恐慌重置 |
| 窗口/文件语义 | 统一可预测的 `:q` / `:bd` / `<leader>wd` / `:exit` 行为（见下文「文件 / 窗口 / 标签页语义」） |

## 文件 / 窗口 / 标签页语义

Neovim 原生的"关文件 / 关窗口"语义很容易踩坑（同一个键在不同状态下行为不同）。本配置做了一套统一、可预测的规则，全部经过自动化回归测试。

### 先搞清三个概念

- **buffer** = 内存里的文件（`:ls` 或 `<leader>,` 可见）；**window** = 分屏视口，永远显示某个 buffer；**tab** = 一组窗口的布局容器（不是"文件标签"）
- 同一个文件可以被多个窗口 / 标签页同时显示，且**视图互不影响**：关掉某个视图只影响该视图

### `:q` / `:wq` / `:x`（可加 `!`）—— 只关文件，布局不动

| 场景 | 行为 |
| --- | --- |
| 还有其它文件 | 当前窗口切到最近使用的其它文件 |
| 没有其它文件 | 当前窗口显示 dashboard（程序不退出） |
| 同一文件还在其它分屏 | 只把当前分屏切走，文件保留在原分屏 |
| 在 dashboard 上 | 放行原生：单 tab 退出 nvim；多 tab 只关当前 tab |
| 有未保存修改 | `:q` 拒绝并提示；`:q!` 丢弃；`:wq` / `:x` 先写盘 |
| `:new` 的无名 buffer | 同样按"文件"处理（没有其它文件时回 dashboard） |

可以连按 `:q` 依次关闭所有打开的文件，最后停在 dashboard；在 dashboard 上再按一次 `:q` 才退出 nvim。

### `:bd` / `:bd!` / `<leader>bd` —— 关文件 +（多窗口时）关当前窗口

- 未保存时弹三选项：保存并关闭 / 丢弃修改 / 取消（`:bd!` 跳过确认）
- 该文件的**其它视图**先切到最近使用的其它文件（没有则显示 dashboard），再关掉当前窗口
- 删掉最后一个文件后回到 dashboard
- 在 dashboard 上拒绝操作（提示改用 `:q`）
- 带参数写法（`:bd 3`、`:1,5bd`）透传原生，不受影响

### `<leader>wd` —— 只关窗口，不动文件

- 多窗口时：关闭当前分屏，buffer 保留
- 单窗口时：友好拒绝并提示（用 `:q` 关文件，或 `:bd` 关文件+窗口）
- 在 dashboard 上：友好拒绝并提示（用 `:q`）

### 其它入口

| 操作 | 行为 |
| --- | --- |
| `<leader>qh` / `:NvkitHome` | 在当前窗口打开 dashboard（普通 buffer，非浮窗） |
| `:exit` / `:exit!` | 无条件退出 nvim（即使有未保存修改，也不提示） |
| `<leader>qs` / `<leader>ql` | 恢复本目录会话 / 恢复最近一次会话 |
| `<leader>qd` / `<leader>qe` | 停止 / 重新开启会话自动保存（成对可逆） |
| `<C-Tab>` / `<C-S-Tab>` | 下 / 上一个标签页（需终端支持发送 Ctrl+Tab） |

> 规则细节：只有"有名文件"参与自动切换；没有有名文件时一律显示 dashboard。help / quickfix / 终端 / 浮窗保持 Neovim 原生行为。

### tab = 工作区（隔离）

每个 tab 拥有独立的文件列表（由 scope.nvim 通过 `buflisted` 切换实现）：切换 tab 后，`:ls`、`<leader>,`（buffer 列表）、`:bnext` / `<Tab>` 只会看到/循环**当前 tab 的文件**；`:q` / `:bd` 的"其它文件"也只看本 tab（tab 内文件清空后回 dashboard）。退出时自动保存的会话（`<leader>qs` / `ql` 恢复）会保留各 tab 的文件归属。

- 同一文件在两个 tab 打开时**就是同一个 buffer**（内容、撤销历史、修改状态共享）——tab 只是窗口布局容器，这是 Neovim 的全局 buffer 模型；要完全独立只能开多个 nvim 实例
- 相关命令：`:ScopeList`（查看各 tab 的文件归属）、`:ScopeMoveBuf`（把当前 buffer 移到指定 tab）
- 新 tab 里打开"已在其它 tab 打开的文件"时，会在两个 tab 都可见（共享同一 buffer）

### 会话：什么时候自动存、q 之后会发生什么

会话 = 某个目录的现场快照（打开的文件、窗口 / tab 布局、各 tab 文件归属、光标 / 折叠）。规则：

- **自动保存**：只在退出 nvim 时存一次；当时还有 ≥1 个有名文件才存（只剩 dashboard 不会覆盖旧快照）
- **按目录隔离**：每个 cwd 一个快照（非 main/master 分支再按分支区分），存在 `~/.local/state/nvim-devkit/sessions/`
- **恢复**：`<leader>qs` 本目录 · `<leader>ql` 最近一次 · 启动页普通键 `r`；没有快照时静默返回
- **自动恢复（可选，默认关）**：`NVIM_DEVKIT_AUTORESTORE=1 nvim-devkit`（或 `vim.g.nvkit_autorestore = true`）后，交互式启动且无文件参数时，本目录有快照就直接进现场；启动页检测到快照也会提示按 `r`
- **开关**：`<leader>qd` 停止本次运行的自动保存，`<leader>qe` 重新开启（可逆）；启动页 `q` 与 `:q` 语义一致

每个 tab 只有两个状态，`:q` 的闭环如下：

```
  工作(≥1 文件) ── :q 关完最后一个文件 ──> dashboard ── :q ──> 退出(单 tab)
      ^                                     │               └─ 关当前 tab(多 tab)
      └────── 打开文件(e / f / picker…) ─────┘
```

dashboard 上各操作：`r` 恢复会话 · `q` / `:q` 退出（多 tab 时关当前 tab）· `:bd` / `<leader>wd` 拒绝并提示 · `:exit` 无条件退出。

## 目录结构

```
nvim-devkit/
├── install.sh / uninstall.sh   # 安装/卸载
├── deps.lock                   # CLI 工具版本锁（GitHub API 失败时的兜底）
├── config/                     # Neovim 配置（NVIM_APPNAME=nvim-devkit）
│   ├── init.lua
│   ├── lazy-lock.json          # 插件版本锁（请提交到 git）
│   └── lua/
│       ├── config/             # options / keymaps / autocmds / lazy
│       ├── nvim-devkit/        # recover(恐慌恢复) / pdf / parsers / caps
│       └── plugins/            # 按主题拆分的插件配置
├── scripts/                    # checkhealth / health.lua / pdf_extract.py
└── docs/                       # CHEATSHEET（速查卡）/ LEARNING（学习计划+恢复手册）
```

## 可恢复性设计（重点）

Vim 的"模式 + 前缀键 + 寄存器"让误按后果难以预期。本配置的对策：

1. **一切可撤销**：`undofile` 持久化撤销历史；`u` / `Ctrl-r`；`:earlier 10m` 按时间回退；`<leader>uu` 打开撤销树看全部历史。
2. **一条命令回到已知状态**：`Ctrl-g` = 恐慌重置（回正常模式、停宏录制、关所有浮窗、清搜索高亮）。
3. **可预测的取消语义**：`Esc` 取消一切待定操作并清高亮；插件浮窗一律 `Esc` 关闭。
4. **状态可见**：which-key 200ms 显示所有可能路径；状态栏显示模式与宏录制状态；noice 显示命令回显。
5. **防误触**：`Q`（Ex 模式）禁用；关闭自动执行项目内配置（`exrc=false`）。
6. **现场恢复**：退出时自动存现场，`<leader>qs` / `<leader>ql` 恢复（buffer / 窗口 / 布局 / 各 tab 归属）；`<leader>qd` / `<leader>qe` 可停 / 开自动保存；有快照时启动页会提示，`NVIM_DEVKIT_AUTORESTORE=1` 可开启"启动即回现场"。

完整对照表见 [docs/LEARNING.md](docs/LEARNING.md) 的「误按恢复手册」。

## 终端与图片

编辑、LSP、调试、Jupyter（文本输出）、Git、opencode 在任何终端都完整可用；差异只在"图形渲染"（Markdown 内嵌图、matplotlib 图、PDF 图片模式、LaTeX 公式）。

| 终端 | 图形协议 | 能解锁什么 | 备注 |
| --- | --- | --- | --- |
| **VS Code 内置终端 ≥ 1.110** | Kitty（2026-02 起） | 浮动图片、molten 图、PDF 图片模式；Markdown 内嵌图可能不显示 | 需 `terminal.integrated.enableImages=true`、`gpuAcceleration=on/auto`；Windows 另需 `windowsUseConptyDll=true`。协议为 MVP，暂不支持 Unicode 占位符/文件传输 |
| **WezTerm**（Windows/macOS/Linux） | Kitty（新版默认开启，无需配置） | 图片整体可用 | 推荐；Windows 下若图片不显示，用内置 `wezterm ssh` 连接绕开 ConPTY；Markdown 内嵌图有限制 |
| **kitty / ghostty** | Kitty | 完整 | Linux/macOS |
| **Windows Terminal ≥ 1.22** | Sixel（需开启） | Jupyter/matplotlib 图（走 sixel 后端） | Markdown 内嵌图不支持（snacks 只走 Kitty）；需服务器有 ImageMagick + `NVIM_DEVKIT_IMAGE_BACKEND=sixel` |
| 其他（macOS Terminal 等） | 无 | 自动降级为文本/占位 | PDF 走文本提取，功能不受影响 |

- 自动检测：静态识别 kitty / WezTerm / ghostty / VS Code 环境变量；识别不到时由 snacks 主动查询终端（SSH 下的 WezTerm 也能认出）。手动强制 `NVIM_DEVKIT_IMAGES=1 nvim-devkit`（`=0` 关闭）。
- 后端覆盖：`NVIM_DEVKIT_IMAGE_BACKEND=kitty|sixel|none`（Windows Terminal 用户设 `sixel`）。
- WezTerm 可选优化：本地 `.wezterm.lua` 加 `config.term = "wezterm"`（TERM 会随 SSH 转发，服务器静态识别更可靠；不加也能用）。
- 嵌套 tmux 时图片需要 `set -g allow-passthrough on`。
- ImageMagick 影响图片转换与 sixel（PNG 免转换）：有 conda 的服务器可 `./install.sh --with-magick` 自动安装到独立环境，否则系统 `apt install imagemagick`。

## 主题与分屏清晰度

默认主题是 **tokyonight night**。仓库另外装好了两套热门主题（只安装，**不会自动切换**，用 `:colorscheme` 手动试）：

| 主题 | 试用命令 | 分屏增强 |
| --- | --- | --- |
| catppuccin | `:colorscheme catppuccin-mocha`（另有 `macchiato` / `frappe` / `latte`） | 已启用 `dim_inactive`（非当前窗口压暗） |
| kanagawa | `:colorscheme kanagawa-wave`（另有 `dragon` / `lotus`） | 已启用 `dimInactive` |
| tokyonight | `:colorscheme tokyonight-storm` / `tokyonight-day` | 可在 `config/lua/plugins/ui.lua` 的 opts 里加 `dim_inactive = true` |

**分屏增强默认已开启**：非当前窗口的背景、文字、行号、符号列、空白符区一起压暗，分界线加亮加粗——分屏后两个文件的层次一眼可辨，对任意主题生效。

- 运行时开关：`:NvkitSplits`（再执行一次关闭）
- 启动时关闭：`NVIM_DEVKIT_SPLITS=0 nvim-devkit`
- **调整压暗强度**（0~1，越大越强；默认 `bg_fade=0.35` 背景趋黑比例、`fg_fade=0.55` 文字趋淡比例）：
  ```vim
  :lua local t=require("nvim-devkit.theme"); t.options.bg_fade=0.5; t.options.fg_fade=0.7; t.dim_inactive(false); t.dim_inactive(true)
  ```
  确认喜欢的数值后写进 `config/lua/config/autocmds.lua` 末尾即可持久化。
- 单独控制：`:lua require("nvim-devkit.theme").dim_inactive(...)` / `.vivid_separator(...)`

换默认主题：改 `config/lua/plugins/ui.lua` 里 tokyonight 的 `config` 一行，例如 `vim.cmd.colorscheme("catppuccin-mocha")`，然后提交推送、各服务器 `./install.sh --update`。

## 依赖要求

服务器需有：`git`、`curl`、`tar`、C 编译器（gcc，编译 treesitter parser）、可选 `python3`（venv 能力；conda 环境里的 python3 也可）。其余全部自动安装到 `~/.local`，无需 sudo。

## 已知问题

- Neovim 0.12.5 上游 bug：`:checkhealth` 中 `vim.health` 的 System Info 会报 `health.lua:560 ... nil value`（`--clean` 下同样复现），与配置无关，已在检测脚本中标记为已知噪音。
- headless 环境下 Snacks 的部分健康检查（`vim.ui.input` / 图片工具）会误报，真实终端中正常；`scripts/checkhealth.sh` 已过滤。
- 若服务器无法直连 GitHub：`./install.sh --mirror https://gh-proxy.com`（或导出 `NVIM_DEVKIT_MIRROR` 后长期生效）。
- Ubuntu 精简系统缺 `python3-venv` 时，安装器会自动改用其他 python3 / uv / conda 重试；全部失败会在末尾给出提示。

## 行为测试

```bash
./tests/run.sh           # 行为测试：30 个用例 / 109 项断言，必须全部通过
scripts/checkhealth.sh   # 健康检查：硬错误必须为 0
```

- 覆盖 `:q` / `:bd` / `<leader>wd` / `:exit` / dashboard / tab 工作区 / 会话恢复与自动保存开关等**全部交互语义**（含真实按键路径与"退出程序"类行为）
- 每个用例独立 nvim 进程、使用仓库里的 config，不依赖本机是否已安装
- **修改任何交互行为后必须跑一遍**，规则与用例清单见 `docs/TESTING.md` 与 `AGENTS.md`

## 仓库维护

| 项 | 值 |
| --- | --- |
| 远端 | `git@github.com:lsp59862/nvim-devkit-python.git`（public，`main` 分支） |
| 许可证 | MIT（见 [LICENSE](LICENSE)） |
| 插件版本锁 | `config/lazy-lock.json`（提交进 git，所有服务器一致） |
| 工具版本兜底 | `deps.lock`（GitHub API 不可用时的固定下载地址） |
| 提交前回归 | `./tests/run.sh` 全过 + `scripts/checkhealth.sh` 硬错误为 0 |

- 回滚配置：`git log --oneline` 找到上一个提交 → `git revert <hash>` 或 `git checkout <hash> -- config/` → `./install.sh --update`
- 插件单独升级：`:Lazy update` 会更新 lockfile，建议 review 后提交再推送

## 贡献

本项目由作者独立开发，**不接受外部 Pull Request**；欢迎通过 Issue 反馈问题、通过 Discussions 交流用法。Fork 自用（MIT 允许）没有问题，但外部改动不会合并回上游。详见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可证

本项目采用 [MIT License](LICENSE)。

第三方插件由 [lazy.nvim](https://github.com/folke/lazy.nvim) 在安装时从各自上游仓库按**其各自许可证**拉取，本仓库不直接分发插件源码；请留意个别插件上游未附许可证文件（例如 scope.nvim）的情况。

## 定制

- 改选项/键位：`config/lua/config/options.lua`、`keymaps.lua`
- 加插件：在 `config/lua/plugins/` 新建或追加 lazy.nvim spec
- 改完提交进 git；服务器上 `./install.sh --update` 同步
- 单独升级插件：`:Lazy update`（会更新 lockfile，建议在仓库里 review 后提交）
- 学习路径与每日练习：`docs/LEARNING.md`
