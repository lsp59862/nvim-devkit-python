# nvim-devkit 学习计划（3 周）

> 目标：3 周后你不再"怕按错"，并且能用 nvim 完成日常科研全流程（写代码 → 查引用 → 调试 → 跑 Jupyter → Git → AI 协作 → 读论文/写 Markdown）。
>
> 每天 20-40 分钟；每周末做一次"恢复演练"。

## 21 天打卡表（完成就打勾）

**第 1 周 · 生存与核心动作**
- [ ] Day 1 模式与移动：只用移动键逛完一个文件
- [ ] Day 2 操作符与文本对象：无鼠标改造一段函数
- [ ] Day 3 文件/Buffer/窗口/会话：重启后 `<leader>ql` 回到现场
- [ ] Day 4 搜索与替换：全项目找到函数所有调用点
- [ ] Day 5 撤销时间线 + Git：用 `:earlier 2m` 救回写坏的代码
- [ ] Day 6 终端与 opencode 入门：让 opencode 解释/修复一段代码
- [ ] Day 7 综合演练：通过第 1 周自测清单（见下）

**第 2 周 · 科研工作流**
- [ ] Day 8 LSP：改名函数并用 `gr` 验证所有引用
- [ ] Day 9 调试：断点检查 batch shape
- [ ] Day 10 Jupyter：molten 跑一个 cell 并看到输出
- [ ] Day 11 Markdown/CSV/PDF：读一篇论文 + 摘录笔记
- [ ] Day 12 opencode 深度：补测试 → diff 审阅 → 接受/拒绝
- [ ] Day 13 Git 进阶：hunk 级暂存拆出两个提交
- [ ] Day 14 项目与会话：模拟断线重连恢复现场

**第 3 周 · 定制与维护**
- [ ] Day 15-16 改配置：加一个自己的键位/选项
- [ ] Day 17 版本管理：跑通一次 `--update` 流程
- [ ] Day 18 健康检查与故障排除：处理一个真实报错
- [ ] Day 19 性能：记录并解释自己的启动耗时
- [ ] Day 20-21 自由实战：完整用 nvim 工作一整天

---

## 0. 先建立 4 个心智模型

1. **Vim 是语言**：`操作符 + 移动/文本对象`。如 `d + aw`（删除一个词）、`y + if`（复制函数体）、`c + i"`（改引号内容）。乱按出一堆字母不危险，`Esc` 取消后不会执行。
2. **一切皆可撤销**：`u` 撤销、`Ctrl-r` 重做、`:earlier 10m` 回到 10 分钟前的整棵编辑树、`<leader>uu` 可视化撤销树。撤销历史写盘，重启后仍在。
3. **任何状态都可以一键归零**：`Ctrl-g`（恐慌重置）= 回正常模式 + 停止宏录制 + 关闭所有浮窗 + 清除搜索高亮。
4. **不确定就停 200ms**：which-key 会弹出所有可能的后续按键（`<leader>` 前缀、`g`、`z`、`[`、`]`、`<C-w>` 等），按提示走，不再靠猜。

---

## 1. 误按恢复手册（打印贴在显示器旁）

| 误按 / 事故 | 发生了什么 | 恢复方式 |
| --- | --- | --- |
| 任何编辑被搞乱 | 文字被改/删 | `u` 反复撤销；`Ctrl-r` 重做；`<leader>uu` 看历史挑版本 |
| 连续乱按后整个人懵了 | 模式/浮窗/宏状态不明 | `Ctrl-g`（恐慌重置），一步回正常状态 |
| `q` 然后打字 | 开始录制宏（状态栏显示 `● 录制 @q`） | 再按 `q` 停止；忘了按也没事：`Ctrl-g` 会停 |
| `@q` 回放宏 | 误执行一串操作 | `u` 撤销；大范围用 `:earlier 1m` |
| `Q` | 老 Vim 会进 Ex 模式（已禁用） | 无需担心，按了没反应 |
| `q:` | 进入命令行历史窗口 | `Esc` 或 `:q` 退出（`Ctrl-c` 也行） |
| `ZZ` / `ZQ` | 保存退出 / 丢弃退出 | 重新打开：`<leader>fr`（最近文件）或 `<leader>ql`（恢复会话）；`.swp` 与 undofile 都在 |
| `dd`、`cc`、可视模式 `p` | 删除/覆盖了内容 | `u`；若粘贴覆盖了别的文本，被覆盖内容其实在寄存器 `"1`，`"1p` 找回 |
| `/` 搜索后跳得到处都是 | 光标乱飞 | `Esc` 清高亮；`Ctrl-o` 逐个跳回；`` `` `` 回上一次跳转点 |
| `Ctrl-w` 乱拆窗口 | 布局破碎 | `<leader>wo` 只留当前窗口；`<leader>w=` 均分；`<leader>ql` 恢复会话布局 |
| 浮窗/补全框卡住 | 找不到出口 | `Esc`；不行就 `Ctrl-g`（关全部浮窗） |
| 进了终端模式出不来 | 按键都被 shell 吃掉 | `<Esc><Esc>`（退出终端输入）或 `Ctrl-g` |
| 搜索替换前怕改错 | —— | 输入替换时 `inccommand` 已实时预览；`u` 可整体撤销 |
| 彻底崩坏/不确定 | —— | `Ctrl-g` → `<leader>ql`（恢复上次会话）→ `<leader>uu`（挑历史版本） |

> 建议每周做一次 "恢复演练"：故意按 `U`、`q`、`ZZ`、`Ctrl-w v`、`:vnew`，然后只用上面的恢复路径回到原状。

---

## 2. 第 1 周：生存与核心动作

### Day 1 — 模式与移动
- `i a o O` 进插入；`Esc` / `Ctrl-g` / 插入里的 `jk` 无所谓，`Esc` 最稳
- 移动：`w b e`（词）、`{ }`（段）、`gg G`、`42G`、`Ctrl-d / Ctrl-u`（半屏）、`zz`（居中）
- 行首/行末：`Alt+1` / `Alt+0`（普通、插入模式通用，不用退出插入去按 `^`/`$`；终端若占用了 Alt+数字会失效）
- 练习：打开任意文件，只用移动键逛 5 分钟，不用鼠标
- 自测：能不看键盘到达文件任意位置

### Day 2 — 操作符与文本对象（Vim 的精髓）
- 组合：`dw daw diw`、`ci"`、`da(`、`yap`、`>i{`
- treesitter 文本对象：`v if` / `v af`（函数内部/整体）、`v ic` / `v ac`（类）——也可直接配操作符（`dif` `yaf` `cif`）；mini.ai 补充 `aa`/`ia`（函数参数）等对象
- flash：`s` + 标签 = 任意位置 3 键直达
- 补全（blink.cmp）：打字自动弹；Enter 接受 · Tab / S-Tab 下/上一项 · Esc 或 C-e 取消预览（↑/↓ 浏览会把候选写进正文，Esc/C-e 可撤销；C-y 也能接受）
- 练习：改造一段 Python 函数：改名、换参数、复制函数体，全程用操作符

### Day 3 — 文件 / Buffer / 窗口 / 会话
- `<leader>e` 文件树、`<leader><space>` 智能查找、`<leader>ff` 找文件
- `<Tab> / <S-Tab>` 切 buffer；`<leader>bd` 关 buffer；`<leader>bo` 关其他
- `Ctrl-h/j/k/l` 跨窗口；`<leader>wo / w= / wd`；`Ctrl+Tab / Ctrl+Shift+Tab` 切标签页
- **tab = 工作区**：每个 tab 的文件列表相互隔离，切过去只看到那个 tab 的文件；同一文件跨 tab 是同一个 buffer（撤销/修改共享）
- **文件/窗口语义**：`:q`=关文件但布局不动（当前窗口切到最近使用的其它文件；同文件其他分屏继续显示；没有其它文件时显示 dashboard，程序不退出；在 dashboard 上 `:q` 才退出 nvim，多 tab 则只关当前 tab；`:new` 的无名 buffer 同样按文件处理）；`:bd`/`<leader>bd`=关文件+（多窗口时）关当前窗口（未保存弹三选项，dashboard 上拒绝）；`<leader>wd`=只关窗口（单窗口/dashboard 上拒绝）；`:exit`=无条件退出。tab 只是窗口布局容器，`<leader>qh` 在普通窗口打开启动页
- 会话：**退出时自动保存现场**（还要有文件才存）；`<leader>qs` 恢复本目录、`<leader>ql` 恢复最近、`<leader>qd` 停 / `<leader>qe` 重新开启自动保存；启动页普通键 `r` 恢复会话、`q` 同 `:q`；默认不自动恢复，`NVIM_DEVKIT_AUTORESTORE=1` 可选"启动即回现场"
- 练习：重启 nvim 后用 `<leader>ql` 回到所有打开的文件与光标位置

### Day 4 — 搜索与替换
- `/` `n` `N`（本配置会居中）、`*`（搜光标词）
- `<leader>/` 全项目搜索、`<leader>sw` 搜当前词、`<leader>sd` 诊断、`<leader>sk` 所有键位
- 替换：`:s/a/b/g`、`:%s/a/b/gc`（`c` 逐个确认，`inccommand` 实时预览）
- **练习场（12 题带答案，磨完即过关）**：`docs/practice/day4/README.md`
  ```bash
  cp -r ~/nvim-devkit/docs/practice/day4 /tmp/day4-drill && cd /tmp/day4-drill && nvim-devkit
  ```

### Day 5 — 撤销时间线与 Git 基本盘
- `u / Ctrl-r`、`<leader>uu` 打开撤销树（`j/k` 浏览、`Enter` 预览、`T` 时间戳）
- 时间旅行：`<leader>uE` 输入 `10m` 回到十分钟前；`<leader>uL` 前进
- Git：`]c / [c` 跳改动、`<leader>gs` 暂存本处、`<leader>gr` 撤销本处、`<leader>gp` 预览
- 练习：写坏一段代码 → 用 `:earlier 2m` 救回 → 再用 undotree 精确挑回某个中间版本

### Day 6 — 终端与 opencode 入门
- `<C-/>` 浮动终端；终端里 `<Esc><Esc>` 回普通模式
- `<leader>oa`：输入问题，`@this` 自动带上光标处上下文
- `<leader>ot`：右侧 opencode 面板开关；`<leader>os`：内置动作面板（解释/修复/审查等）
- 练习：让 opencode 解释当前函数、修复一个 lint 错误，并在 diff 里接受/拒绝

### Day 7 — 综合演练 + 自测
自测清单（全部脱稿完成即过关）：
- [ ] 用 `daw/ciw` 无鼠标改造一行
- [ ] `s` 跳到屏幕外某个词并修改
- [ ] 从"乱按 20 个随机键"状态用 `Ctrl-g` 恢复
- [ ] 用 `:earlier 5m` 找回早晨的版本
- [ ] 关掉 nvim，用 `<leader>ql` 恢复全部现场
- [ ] 在浮动终端跑 `git status` 并回到编辑

---

## 3. 第 2 周：科研工作流

### Day 8 — LSP：写代码的日常
- `gd` 定义、`gr` 引用、`gi` 实现、`K` 文档、`<C-k>` 签名
- `<leader>ca` 代码操作（自动 import、快速修复）、`<leader>cr` 全项目重命名、`<leader>cf` ruff 格式化
- `[d / ]d` 诊断跳转、`<leader>cd` 行诊断浮窗
- 环境识别：先 `conda activate <你的环境>` 再启动 nvim，basedpyright 自动指向该环境
- 练习：在真实数据集脚本里改名一个函数（`gr` 检查引用 → `cr` 重命名）

### Day 9 — 调试：比 print 更快
- `F5` 启动/继续（选 `file` 或 pytest 配置）、`F10/F11/F12` 单步
- `<leader>db` 断点、`<leader>dB` 条件断点、`<leader>du` 打开变量/栈/断点面板
- `<leader>dm` 调试光标下的测试方法、`<leader>dr` 打开 REPL 现场算表达式
- 练习：给一个数据加载函数打断点，检查 batch shape

### Day 10 — Jupyter / molten
- 打开 `.py`，`<leader>mi` 选 `devkit-python` 初始化内核
- `<leader>ml` 运行当前行、`<leader>mv` 运行选中、`<leader>mr` 重跑 cell
- `<leader>mo / mh` 显示/隐藏输出（virtual text 默认常驻）、`<leader>mx` 中断
- 图像输出需要 Kitty 协议终端（kitty/WezTerm/VS Code≥1.110 开 enableImages；Windows Terminal 走 `NVIM_DEVKIT_IMAGE_BACKEND=sixel`），文本输出任何终端可见；详见 README「终端与图片」表格
- `.ipynb`：直接打开会自动转 py/md（jupytext）
- 练习：写一个 cell 训练循环片段，打印 loss 曲线（或 at least 文本输出）

### Day 11 — Markdown / CSV / PDF（文献与数据）
- Markdown：打开即内联渲染；`<leader>sk` 里有 `:RenderMarkdown toggle` 可切原始视图
- CSV：打开即表格视图（`CsvViewToggle` 手动开关，粘性表头方便对列）
- PDF：直接 `:e paper.pdf` 自动转文本（分页标记）；`]p / [p` 翻页；Kitty 终端下 `<leader>rt` 切图片模式
- 练习：用 PDF 阅读 + `<leader>sw` 搜索 + 摘录到 Markdown 笔记

### Day 12 — opencode 深度协作
- `@this`（光标处）、`@buffer`（整个文件）：`<leader>op` 发送、`<leader>of` 发整个 buffer
- 编辑审阅：opencode 改文件后自动刷新 buffer，并在 diff 页 `da` 接受 / `dr` 拒绝 / 逐 hunk 处理
- `<leader>os` 动作面板：解释、重构建议、生成测试等
- 练习：让 opencode 为你的数据处理脚本补 pytest，审阅并接受

### Day 13 — Git 进阶
- `<leader>gg` 打开 lazygit（浮窗）：`s` 暂存、`c` 提交、`P` push、`b` 分支
- gitsigns：`<leader>gb` 行 blame、`<leader>gt` 常驻 blame、`<leader>gd` 与 HEAD 对比
- 练习：用 hunk 级别暂存把"调试代码"和"功能代码"拆成两个提交

### Day 14 — 项目与会话管理
- `<leader>fp` 项目列表、`<leader>fr` 最近文件、`<leader>fg` 只搜 Git 文件
- persistence 在退出时自动记录每个目录的会话（`<leader>qd` / `qe` 可停 / 开）；与 tmux 配合：重连 → nvim → `<leader>ql`
- 练习：模拟断线重连，恢复现场继续干活

---

## 4. 第 3 周：定制与长期维护

### Day 15-16 — 改配置
- 选项 `config/lua/config/options.lua`；键位 `keymaps.lua`
- 加插件模板：
  ```lua
  -- config/lua/plugins/xxx.lua
  return {
    { "作者/插件", event = "VeryLazy", opts = {} },
  }
  ```
  保存后 `:Lazy sync` 即可生效；确认稳定后把 `lazy-lock.json` 提交进仓库

### Day 17 — 版本管理与团队复现
- `lazy-lock.json` 锁插件 commit；`deps.lock` 兜底 CLI 版本
- 更新流程：仓库 `git pull` → `./install.sh --update` → 测试 → 提交新 lockfile
- 新服务器部署：`git clone + ./install.sh`；无外网时 `--mirror https://gh-proxy.com`

### Day 18 — 健康检查与故障排除
- `:checkhealth`（真实终端下看）、`:Lazy`（插件状态）、`:ConformInfo`（格式化器）、`:Mason`（LSP 工具）
- 常见症状 → 处方：
  - LSP 不触发：`:LspInfo` 看是否 attach；确认 `conda activate` 后启动
  - 调试找不到环境：检查 `CONDA_PREFIX`；或 `.vscode/launch.json` 自定义
  - 图片不显示：终端是否 Kitty 协议；`NVIM_DEVKIT_IMAGES=1` 强制
  - 插件报错：`:Lazy restore` 回到锁定版本

### Day 19 — 性能
- `nvim-devkit --startuptime /tmp/st.txt` 查看启动耗时
- `:Lazy profile` 找慢插件；懒加载事件（`event/ft/cmd/keys`）按需调整

### Day 20-21 — 自由实战
- 用 nvim 完整完成一天科研工作：写代码、跑实验、调 bug、记笔记、提交
- 给配置写你自己的第一批键位（比如数据集常用路径、`<leader>xx` 快捷命令）

---

## 5. 键位地图（leader = 空格）

| 前缀 | 主题 | 高频键 |
| --- | --- | --- |
| `<leader>e` / `<leader><space>` | 文件树 / 智能查找 | `e` `ff` `fg` `fr` `fp` |
| `<leader>/` `<leader>s*` | 搜索 | `/` `sw` `sd` `sk` |
| `<leader>u*` | 撤销/恢复 | `uu`（撤销树）`uE`（回到 N 分钟前）`uL` `ur` |
| `<leader>b*` | Buffer | `bd` `bo` |
| `<leader>w*` | 窗口 | `wo` `w=` `wd` |
| `<leader>c*` | 代码（LSP） | `ca` `cr` `cf` `cd` |
| `<leader>d*` | 调试 | `db` `du` `dm` `dr` `dt` |
| `<leader>m*` | Jupyter | `mi` `ml` `mv` `mr` `mo` |
| `<leader>g*` | Git | `gg`（lazygit）`gs` `gr` `gp` `gb` |
| `<leader>o*` | opencode | `oa` `os` `ot` `op` `of` |
| `<leader>q*` | 会话 | `qs` `ql` `qd` `qe` |
| `<leader>r*` | 渲染 | `rt`（PDF 图片模式） |
| `Ctrl-g` | **恐慌重置** | 任何时候按 |
| `s` / `S` | Flash 跳转 / 选节点 | |
| 插入模式 | 补全（blink.cmp） | Enter 接受 · Tab/S-Tab 下/上一项 · Esc/C-e 取消预览 · C-y 接受 |
| `g` `z` `[` `]` `<C-w>` | 等 200ms 看 which-key 提示 | |

## 6. 内置资源

- `:Tutor` —— 官方 30 分钟交互教程（按系统语言自动选择；中文系统即中文版）
- `<leader>sk` —— 全部键位搜索器；`<leader>sh` —— 帮助文档搜索
- `:help <主题>` —— 例如 `:help text-objects`、`:help :earlier`
- `docs/LEARNING.md`（本文件）—— 随时回看恢复手册
