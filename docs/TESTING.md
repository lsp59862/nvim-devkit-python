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
- nvim 可执行文件查找顺序：`NVIM_DEVKIT_BIN` 环境变量 → `~/.local/share/nvim-devkit/nvim/bin/nvim` → PATH 中的 `nvim`
- 失败时完整日志留在 `/tmp/nvim-devkit-tests/log-<用例>.txt`

## 覆盖范围（19 个用例 / 38 项断言）

| 用例 | 覆盖行为 |
| --- | --- |
| `winbuf_file` | `:q`（单窗切换 / 单文件回 dashboard / 同文件分屏 / 多窗不同文件）· `:bd`（单窗最后文件 / 多窗关窗口 / dashboard 上拒绝）· `<leader>wd`（单窗拒绝 / 多窗关窗 / dashboard 拒绝）· 无名 buffer · 键位映射存在性 |
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
| 会话（persistence + scope_bridge） | 各 tab 的文件归属随会话保存/恢复 |

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
