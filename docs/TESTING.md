# 行为测试（nvim-devkit）

> **给未来的 AI / 贡献者（必读）**
>
> 任何影响交互行为的功能修改（`config/lua/nvim-devkit/**`、`keymaps.lua`、`options.lua`、
> 插件语义、安装器行为等），提交前必须运行：
>
> ```bash
> ./tests/run.sh          # 行为测试，必须全部通过
> scripts/checkhealth.sh  # 健康检查，硬错误必须为 0
> ```
>
> 若行为变化是有意的：同步更新 `tests/cases/*`、`README.md`、`docs/CHEATSHEET.md`、
> `docs/LEARNING.md`，并在提交信息中说明。否则视为功能回归。

## 运行方式

```bash
cd ~/nvim-devkit
./tests/run.sh
```

- 使用**仓库里的 config**（通过 `XDG_CONFIG_HOME` 临时软链），不依赖本机是否已经安装；插件/解析器复用已安装的数据目录
- 每个用例跑在**独立 nvim 进程**（`--headless`），避免状态互相污染
- `XDG_STATE_HOME` 指向测试目录（`$WORK/xdg-state`）：会话 / undo / shada 全部沙箱，不会写真实的 `~/.local/state/nvim-devkit`
- nvim 可执行文件查找顺序：`NVIM_DEVKIT_BIN` 环境变量 → `~/.local/share/nvim-devkit/nvim/bin/nvim` → PATH 中的 `nvim`
- 失败时完整日志留在 `/tmp/nvim-devkit-tests/log-<用例>.txt`

## 覆盖范围（30 个用例 / 109 项断言）

| 用例 | 覆盖行为 |
| --- | --- |
| `winbuf_file` | `:q`（单窗切换 / 单文件回 dashboard / 同文件分屏 / 多窗不同文件）· `:bd`（单窗最后文件 / 多窗关窗口 / dashboard 上拒绝）· `<leader>wd`（单窗拒绝 / 多窗关窗 / dashboard 拒绝）· 无名 buffer · 键位映射存在性 |
| `keymaps_alt` | `Alt+1` / `Alt+0` 行首 / 行末：映射存在（普通+插入）、插入 rhs 语义、普通模式落点、插入模式落点（插入未中断由"输入字符的落点"证明） |
| `keymaps_ctrl_bs` | 词级删除：`<C-BS>`（插入/命令行）与 `<C-H>` 回退删前词 · `<C-Del>` 删后词（词尾含空格 / 词首只删本词） |
| `winbuf_typed_q` | 真实按键 `:q` → dashboard 且程序不退出 |
| `winbuf_typed_qbang` | 真实按键 `:q!` → 丢弃修改并回 dashboard |
| `winbuf_typed_wq` / `winbuf_typed_wq_multi` / `winbuf_typed_x` | `:wq` / `:x` 先写盘再关闭；有其它文件时切换到它 |
| `winbuf_typed_bd` / `winbuf_typed_bd_bang` | 真实按键 `:bd` 最后文件 → dashboard；`:bd!` 强制删除 |
| `winbuf_typed_bd_dashboard` | 在 dashboard 上 `:bd` → 拒绝（提示用 `:q`） |
| `winbuf_typed_passthrough` | `:bd <nr>` 带参数透传原生行为 |
| `winbuf_user_scenario` | 三窗口（左 L / 右上 L / 右下 `[NoName]`）bd 的 dashboard 落位与焦点（历史 bug 回归） |
| `winbuf_dashboard_tab` | 多 tab 时在 dashboard 上 `:q` 只关当前 tab、程序不退出 |
| `scope_isolation` | tab 列表隔离与切回恢复 · 同文件双 tab 两边可见 · `bnext` 作用域 · help/dashboard 免疫 |
| `scope_quit` | tab 内 `:q` 回 dashboard，其它 tab 不受影响 |
| `scope_tabclose` | "关过 tab 再新增"后序列化不错位 |
| `scope_session_save` / `scope_session_load` | 各 tab 文件归属随会话保存/恢复（含关过 tab 的场景） |
| `session_toggle` | 会话自动保存开关闭环：前置开启 · `qd` 停止后退出不写会话文件 · `qe` 重新开启后恢复写入且含当前文件 |
| `session_restore` | 自动恢复（opt-in）门闸：默认关 · headless 永不恢复 · 开关/参数/UI/快照四条件真值表 · `session_file` 有无快照两态 |
| `completion_keys` | 补全键位契约：Enter=接受 · Tab/S-Tab=下/上一项 · Esc=取消预览 · C-y 仍可接受 · normal Tab 不受影响 |
| `tutor` | 官方教程未被禁用：`:Tutor` 存在且能打开（按 v:lang 自动选中文版） |
| `terminal_multi` | 终端多开：同类互斥（开两台只显示一台）· `tt`/`tb` 关可见、再按唤回 · 编号递增与复用 · `kill` 真正结束进程 |
| `terminal_cycle` | `<M-j>`/`<M-k>` 循环切换：无终端自动开一台 · 下一个/回绕/上一个（共享列表） |
| `terminal_list` | 终端列表：条目按编号排序含命令 · picker 参数（items/confirm/`<C-d>` 杀/`<C-n>` 新建）· `<leader>t*` 映射且旧 `<C-/>` 已移除 |
| `opencode_keys` | opencode 插件 1.x 公开 API 存在性（`ask/select/prompt/operator`，无 `toggle`）· `<leader>ot` 映射存在（n/t）· stub 验证调用 `snacks.terminal.toggle("opencode --port", 右侧面板)` |
| `dashboard_keys` | 启动页按键契约：`r` = 恢复会话（persistence.load）· `q` = `:q`（防回退到 snacks 默认的 `<cmd>bd`）· buffer 内映射存在 |
| `winbuf_exit_dashboard` | 退出类：dashboard 上 `:q` → 退出 nvim |
| `winbuf_exit_command` | 退出类：`:exit` 有无未保存修改都直接退出 |

## 被测试锁定的行为契约

以下语义由 `tests/cases/*` 覆盖，修改配置时不得无意破坏（完整说明见 `README.md`）：

| 操作 | 行为 |
| --- | --- |
| `:q` / `:wq` / `:x`（可加 `!`） | 只关文件、布局不动；有其它文件 → 当前窗口切换；没有 → 显示 dashboard（程序不退出）；dashboard 上 → 单 tab 退出 / 多 tab 关当前 tab；有修改时 `:q` 拒绝、`:q!` 丢弃、`:wq` 先写 |
| `:bd` / `<leader>bd` | 关文件 +（多窗口时）关当前窗口；未保存弹三选项（`!` 跳过）；dashboard 上拒绝；最后一个文件回 dashboard |
| `<leader>wd` | 只关窗口；单窗口 / dashboard 上拒绝并提示 |
| `:exit` | 无条件退出 nvim |
| tab 工作区（scope） | 每个 tab 独立文件列表；同一文件跨 tab 仍是同一个 buffer |
| 会话（persistence + scope_bridge） | 各 tab 的文件归属随会话保存/恢复；自动保存在退出且 ≥1 有名文件时触发；`qd` / `qe` 成对开关 |
| 会话自动恢复（opt-in） | 默认关；仅"开开关 + 无参数 + 有 UI + 有快照"时恢复；headless 永不动作；启动页有快照时显示提示行 |
| 启动页按键 | 普通键 `r` 恢复会话；`q` 与 `:q` 一致（单 tab 退出 / 多 tab 关当前 tab） |
| 补全键位（blink.cmp） | 插入模式 Enter 接受 / Tab、S-Tab 浏览 / Esc、C-e 取消预览；normal 的 Tab 仍为 bnext |
| 词级删除 | 插入/命令行 `<C-BS>` 与插入 `<C-H>` 删前词；插入 `<C-Del>` 按 VS Code 语义删后词（跳过空格，不吃下一个词） |
| 官方教程 | `:Tutor` 可用（runtime 的 tutor 插件未被 lazy 禁用） |
| 终端管理 | 终端只用 `<leader>t*` 开（无 Ctrl 开法）；浮动/底部各自**同时只显示一台**（同类互斥）· 共享一个列表 · `<M-j>`/`<M-k>` 循环切换 · `<C-d>` 杀进程 · 隐藏不杀进程 |

## 新增用例

1. 在 `tests/cases/` 新建 `<name>.lua`，复制现有用例开头的 lib 引入行
2. 用 `lib.ok(id, 条件, 详情)` 断言；结尾调用 `lib.finish()`
3. **退出类**用例：打印 `[RUN]` 后执行动作，若程序仍在则打印 `[ALIVE]`；在 `tests/run.sh` 中按 `expect_exit=1` 登记
4. 在 `tests/run.sh` 的用例列表登记（有依赖顺序的用例放在前面，如 save 在 load 前）

## 已知限制（写测试时注意）

- **headless 下同一进程连续 `feedkeys` 偶发不展开缩写**（测试工具假象，真实终端不受影响）：
  每个脚本只发一次真实按键；需要多步连续输入的用例改用直接调用函数（见 `winbuf_file.lua`）
- 通知等**浮窗不计入窗口数**：`lib.wins()` 只统计真实分屏
- 会话用例有执行顺序依赖（`scope_session_save` 必须在 `scope_session_load` 前），runner 已固定顺序
- 首次在某台机器跑测试前，需要该机器已装好依赖（`./install.sh`），否则插件/解析器缺失
