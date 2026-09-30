# nvim-devkit 速查卡

> 一页纸版本（打印/贴屏用）：救命键位、键位地图、科研流程、环境坑。
> 配套文档：`README.md`（部署运维）· `docs/LEARNING.md`（3 周课程）· 启动页按 `c` 直达本文件。
>
> 术语：**`<leader>` = 空格键**（先按空格、再按后面的键）；`Esc` 取消一切；懵了按 `Ctrl-g`。

---

## 0. 三条命令

| 命令 | 作用 |
| --- | --- |
| `nvim-devkit` | 启动（独立配置，不影响服务器上的 nvim） |
| `~/nvim-devkit/install.sh --update` | 更新插件 / LSP / parser |
| `~/nvim-devkit/scripts/checkhealth.sh` | 健康检查（硬错误应为 0） |
| `nvim-devkit --headless "+Lazy restore" +qa` | 插件出问题时回滚到锁定版本 |

---

## 1. 救命区（懵了先看这里）

**黄金法则：不管什么状态，`Ctrl-g` 一键归零**（回正常模式 + 停止宏录制 + 关闭所有浮窗 + 清搜索高亮）。

| 误按 / 事故 | 恢复 |
| --- | --- |
| 文字被改乱 | `u` 撤销；`Ctrl-r` 重做；`<leader>uu` 撤销树挑版本 |
| 乱按后整个人懵了 | **`Ctrl-g`** |
| `q` 误触开始录宏（状态栏 `● 录制`） | 再按 `q` 停止；忘了就 `Ctrl-g` |
| `@q` 误触宏回放 | `u`；大范围 `:earlier 1m` |
| `Q`（旧版进 Ex 模式） | 已禁用，按了没反应 |
| `q:` 命令行窗口 | `Esc` 或 `:q` |
| `ZZ`/`ZQ` 误退出 | 重开：`<leader>fr` 最近文件 / `<leader>ql` 恢复会话（撤销历史仍在） |
| `dd`/`cc`/可视 `p` 覆盖 | `u`；被覆盖内容在寄存器 `"1`，`"1p` 找回 |
| 搜索后到处跳 | `Esc` 清高亮；`Ctrl-o` 回跳；`` `` `` 回上次位置 |
| 窗口被拆碎 | `<leader>wo` 只留当前；`<leader>w=` 均分；`<leader>ql` 恢复布局 |
| 关文件时误伤了窗口布局 | 只关文件用 `:q` / `:wq`（布局不动，同文件其他分屏不受影响）；关文件+窗口才用 `:bd` / `<leader>bd` |
| 浮窗/补全卡住 | `Esc`；不行 `Ctrl-g` |
| 终端模式出不来 | `<Esc><Esc>` |
| 想回到 10 分钟前的整棵树 | `<leader>uE` → 输入 `10m`；前进 `<leader>uL` |
| 彻底不确定 | `Ctrl-g` → `<leader>ql` → `<leader>uu` |

### 文件 / 窗口 / 标签的关系

- **buffer** = 内存中的文件（`:ls` / `<leader>,` 查看）；**window** = 分屏视口，永远显示某个 buffer；**tab** = 一组窗口的布局容器（不是"文件标签"，一般用不到）
- 同一个文件可以被多个分屏同时显示；**关窗口不动文件；关文件会关掉显示它的窗口**（`:bd`）；`:q` 则两头都照顾——关文件但布局不动

| 想做什么 | 输入 | 布局 | 文件 |
| --- | --- | --- | --- |
| 只关文件，布局不动 | `:q` / `:wq` / `:x`（可加 `!`） | 窗口/tab 不变 | 关闭；当前窗口切到最近使用的其它文件；没有其它文件时显示 dashboard（程序不退出）；**在 dashboard 上 `:q` 才退出 nvim**（多 tab 则只关当前 tab）；`:new` 的无名 buffer 同样按文件处理 |
| 关文件 +（多窗口时）关当前窗口 | `:bd` / `<leader>bd`（可加 `!`） | 多窗口时少一个分屏；单窗口不变 | 关闭（未保存弹三选项）；没有其它文件时回 dashboard；dashboard 上**拒绝**（提示用 `:q`） |
| 只关窗口 | `<leader>wd` | 多窗口时少一个分屏 | 保留；单窗口 / dashboard 上拒绝并提示 |
| 退出 nvim | `:exit` / `:qa` | — | `:exit` 无条件强制退出（不提示保存） |

---

## 2. 键位地图（leader = 空格）

### leader 分组

| 前缀 | 主题 | 高频键 |
| --- | --- | --- |
| `<leader>e` / `<leader><space>` | 文件树 / 智能查找 | `e` `ff` `fg` `fr` `fp` |
| `<leader>/` `<leader>s*` | 搜索 | `/` `sw`（光标词）`sd`（诊断）`sk`（键位）`sh`（帮助） |
| `<leader>u*` | 撤销/恢复 | `uu` 撤销树 · `uE` 回到 N 时间前 · `uL` 前进 · `ur` 重载 |
| `<leader>b*` | Buffer | `bd` 关文件+窗口 · `bo` 只留当前 |
| `<leader>w*` | 窗口 | `wo` `w=` `wd` |
| `<leader>c*` | 代码（LSP） | `ca` 操作 · `cr` 重命名 · `cf` 格式化 · `cd` 行诊断 |
| `<leader>d*` | 调试 | `db` 断点 · `du` 面板 · `dm` 调测试方法 · `dr` REPL · `dt` 结束 |
| `<leader>m*` | Jupyter | `mi` 初始化 · `ml` 跑行 · `mv` 跑选中 · `mr` 重跑 · `mo/mh` 显示隐藏 |
| `<leader>g*` | Git | `gg` lazygit · `gs` 暂存块 · `gr` 撤销块 · `gp` 预览 · `gb` blame |
| `<leader>o*` | opencode | `oa` 提问（带上下文）· `os` 动作面板 · `ot` 面板开关 · `of` 整文件 |
| `<leader>q*` | 会话 / 主页 | `qs` 存/恢复本目录 · `ql` 恢复上次 · `qd` 停止记录 · `qh` 回启动页 |
| `<leader>r*` | 渲染 | `rt` PDF 图片模式（Kitty 终端） |

### 高频单键

| 键 | 作用 | 键 | 作用 |
| --- | --- | --- | --- |
| `Ctrl-g` | **恐慌重置** | `Esc` | 取消一切 + 清高亮 |
| `u` / `Ctrl-r` | 撤销 / 重做 | `<C-s>` | 保存 |
| `s` / `S` | Flash 跳转 / 选节点 | `gd` `gr` `K` | 定义 / 引用 / 文档 |
| `n` / `N` | 下/上个匹配（居中） | `[d` `]d` | 上/下个诊断 |
| `<C-h/j/k/l>` | 跨窗口 | `[c` `]c` | 上/下个 Git 改动 |
| `Tab` / `<S-Tab>` | 切 buffer | `gc` `gcc` | 注释 |
| `sa` `sd` `sr` | 加/删/换包围（mini.surround） | `<M-h/j/k/l>` | 移动行/块（mini.move） |
| `daa` `cia` | 删/改一个参数（mini.ai） | `af` / `if` | 整个/内部函数（treesitter） |
| `s` 后输入词 | 任意位置三键直达 | `<C-/>` / `<C-_>` | 浮动终端 |
| `<C-Tab>` / `<C-S-Tab>` | 下/上一个 tab | `:exit` | 无条件退出 nvim |

> 不确定的按键：**停 200ms**，which-key 会把所有可能路径列出来；`<leader>sk` 可搜索全部键位。

---

## 3. 科研流程速查

### 写代码（LSP）
1. 先 `conda activate <环境>` **再**启动 nvim（basedpyright/debugpy 自动指向该环境）
2. `gd` 跳定义 → `gr` 查引用 → `<leader>cr` 安全重命名
3. `<leader>ca` 快速修复/自动 import；`<leader>cf` ruff 格式化
4. `[d/]d` 逐个诊断，`<leader>cd` 看详情

### 调试
`F5` 启动（选 file 或 pytest）→ `F10/F11/F12` 单步 → `<leader>du` 看变量/栈/断点 → `<leader>dr` 在 REPL 里现场算表达式 → `<leader>dt` 结束。
条件断点 `<leader>dB`；调试光标下的测试：`<leader>dm`（方法）/ `<leader>dc`（类）。

### Jupyter（molten）
`<leader>mi` 选 `devkit-python` 初始化 → 选中代码 `<leader>mv` 或 `<leader>ml` 跑当前行 → 输出以虚拟文本常驻在 cell 下方 → `<leader>mx` 中断长任务。
图像输出需要 Kitty 协议终端；文本输出任何终端可见。`.ipynb` 打开会自动转 py/md。

### Git
`<leader>gg` lazygit 全功能；行内：`]c/[c` 跳改动、`<leader>gp` 预览、`<leader>gs` 暂存、`<leader>gr` 撤销、`<leader>gb` 看这行谁写的。

### opencode
`<leader>oa` 提问（自动带 `@this` 光标处上下文）；`<leader>of` 整个文件；`<leader>op` 只发 prompt。
它改文件后 buffer 自动刷新，并弹出 diff：`da` 接受 / `dr` 拒绝 / 逐 hunk 处理。

### 读文献 / 数据
- Markdown：打开即渲染（标题/表格/公式）；`:RenderMarkdown toggle` 切原始
- CSV：打开即表格视图（粘性表头），`:CsvViewToggle` 开关
- PDF：`:e paper.pdf` 自动转文本，`]p/[p` 翻页；Kitty 终端下 `<leader>rt` 切图片模式

### 终端速记
- 只做编辑/调试：任何终端都行
- 要看图（matplotlib / Markdown 内嵌图 / PDF 图片模式）：
  - **WezTerm**（推荐）：新版默认开启图形协议，无需配置；Windows 下图片不显示时用 `wezterm ssh` 连接（绕 ConPTY）
  - VS Code **≥1.110**：开 `terminal.integrated.enableImages` + `gpuAcceleration=on`（Windows 再加 `windowsUseConptyDll`），必要时 `NVIM_DEVKIT_IMAGES=1 nvim-devkit`
  - Windows Terminal：只能走 `NVIM_DEVKIT_IMAGE_BACKEND=sixel`（仅 matplotlib/molten 图，需 ImageMagick）
- 图片体系默认自动探测；`NVIM_DEVKIT_IMAGES=1` 强制开、`=0` 强制关

---

## 4. 环境要点

| 事项 | 说明 |
| --- | --- |
| conda/venv | **先激活环境再启动 nvim**，LSP/调试器才认对解释器 |
| 图片渲染 | 默认自动探测（含 SSH 下的 WezTerm 运行时查询）；`NVIM_DEVKIT_IMAGES=1` 强制开，`=0` 强制关。WezTerm 新版免配置，VS Code 需 ≥1.110 开 `enableImages` |
| 图片后端 | `NVIM_DEVKIT_IMAGE_BACKEND=kitty｜sixel｜none`；Windows Terminal(≥1.22) 用 `sixel`（仅 matplotlib/molten 图，Markdown 内嵌图不支持） |
| tmux 嵌套 | 图片需 `set -g allow-passthrough on` |
| ImageMagick | PNG 免转换；其他格式/PDF 图片模式/sixel 必需；有 conda 可 `./install.sh --with-magick` |
| GitHub 不通 | `./install.sh --mirror https://gh-proxy.com`（或导出 `NVIM_DEVKIT_MIRROR` 长期生效） |
| 新服务器部署 | `git clone <仓库> ~/nvim-devkit && cd ~/nvim-devkit && ./install.sh`（5-10 分钟，免 sudo） |
| 插件版本 | `config/lazy-lock.json` 锁死；所有服务器一致；升级后建议 review 再提交 |

**已知噪音**（不是故障）：
- `:checkhealth` 里 `vim.health` 的 System Info 报错 —— Neovim 0.12.5 上游 bug（`--clean` 同样复现）
- headless 下 Snacks 的 `vim.ui.input/select`、图片工具会误报 —— 真实终端正常
- 本机 checkhealth 截图级别的 ERROR 大多是"没有 kitty 终端/ImageMagick"

---

## 5. 故障排除 Top 5

| 症状 | 处方 |
| --- | --- |
| 补全/跳转不工作 | `:checkhealth` + `:LspInfo` 看是否 attach；确认 nvim 启动前已 `conda activate`；`<leader>ur` 重载文件 |
| 调试找错环境/缺包 | 检查 `:lua print(vim.env.CONDA_PREFIX)`；或用 `.vscode/launch.json` 显式指定 `pythonPath` |
| 图/公式不显示 | 换 WezTerm/kitty；`NVIM_DEVKIT_IMAGES=1 nvim-devkit`；tmux 开 passthrough；缺 magick 先不管 PNG 图 |
| 某个插件报错 | `nvim-devkit --headless "+Lazy restore" +qa` 回锁定版本；再不行 `:Lazy! sync` |
| 更新后坏了 | `git -C ~/nvim-devkit log --oneline -5` → `git checkout <旧提交> -- config/` → 重跑 `install.sh --update` |
| 分屏分不清 / 压暗不够 | 增强已默认开启：`:NvkitSplits` 开关；调强度 `:lua local t=require("nvim-devkit.theme"); t.options.fg_fade=0.7; t.options.bg_fade=0.5; t.dim_inactive(false); t.dim_inactive(true)`（数值 0~1，越大越明显） |

---

## 6. 改配置入口

| 想改什么 | 文件 |
| --- | --- |
| 选项（缩进/折叠/行为） | `config/lua/config/options.lua` |
| 键位 | `config/lua/config/keymaps.lua` |
| 自动命令 | `config/lua/config/autocmds.lua` |
| 插件（增删改） | `config/lua/plugins/*.lua`（按主题拆分） |
| 恐慌恢复/PDF 等自研模块 | `config/lua/nvim-devkit/*.lua` |

加插件模板：

```lua
-- config/lua/plugins/my.lua
return {
  { "作者/插件名", event = "VeryLazy", opts = {} },
}
```

保存后 `:Lazy sync` 立即装；稳定后把 `lazy-lock.json` 一起提交。
想彻底卸载：`~/nvim-devkit/uninstall.sh --purge`。
