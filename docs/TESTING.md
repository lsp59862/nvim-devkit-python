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

## 覆盖范围（41 个用例 / 312 项断言）

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
| `terminal_multi` | 终端面板：`tp`/`tb` 呼出与自动创建（再按收起不新建）· 侧边栏 shell 简名、圆角包边、当前项高亮（`NvkitTermCurrent`）· 底部不再显示名字栏 · `Alt+N` 同类新建 · 删除不重排编号 · `Alt+R` 重命名 · `kill` 自动切换/最后收起 |
| `terminal_cycle` | 同类循环：3 台浮动正向/反向/回绕 · 底部单台不跨类 · 浮动循环不影响底部 · `<M-j>/<M-k>/<M-n>/<M-r>` 映射 |
| `terminal_zoom` | `Ctrl+Shift+=` 最大化/还原：底部高度撑满且侧边栏同步 · 二次还原原高度 · 浮动全屏并还原几何 · 无终端时 no-op · 多编码键位映射 |
| `terminal_anim` | 中心展开动画：首帧是 1×1 无边框点 · 宽度展开到终值 · 多帧推进 · 终点几何精确 · 折叠为精确镜像（带边框收线→化线为点）· 收成 1×1 点后消失 · 每帧强制刷屏 |
| `terminal_list` | 列表区分 `[浮]/[底]/[面板]` · 名字为简名（无绝对路径）· 所有 picker 的 `Alt+J`/`Alt+K` 选择键已配置 · picker 参数（format/confirm/`<C-d>` 杀）· 确认后 picker 必须收起（浮窗/底部两条路径，防残留）· 新键位 `tp/tb/tl` 且旧 `tt/tn` 已移除 |
| `opencode_keys` | opencode 插件 1.x 公开 API 存在性（`ask/select/prompt/operator`，无 `toggle`）· `<leader>ot` 映射存在（n/t）· stub 验证调用 `snacks.terminal.toggle("opencode --port", 右侧面板)` |
| `dashboard_keys` | 启动页按键契约：`r` = 恢复会话（persistence.load）· `q` = `:q`（防回退到 snacks 默认的 `<cmd>bd`）· buffer 内映射存在 |
| `explorer_all_files` | 文件树默认显示所有文件：被 `.gitignore` 忽略的 `result/`（ignored 标记加载后仍可见）· 点文件 · 普通文件；`explorer` 与 `files` 数据源默认 `hidden+ignored` |
| `viewer_keys` | 查看器：等比缩放纯函数 `_plan`（z=1 整图居中 / 2x 中心取景 / 平移夹紧 / z<1 整图缩小居中 / 正方形图 x/y 等比系数一致）· 渲染命令 `_render_cmd` 结构（透明画布+裁剪+缩放+按落点合成）· pdfinfo 页数解析 · `ft=image` 在普通窗口显示（无浮窗、不额外开窗）并安装图片键位（q/±/0/滚轮/hjkl，无翻页）· `q` 关闭并删除 buffer · PDF 键位（`]p/[p`、滚轮翻页、`<leader>rt` 切文本）· 逃生阀（`vim.g.nvkit_viewer_wheel=0` 时滚轮为空操作、不缩放不渲染）· 环境降级（PATH 无 ImageMagick 时普通放置源图、缩放不生效且不重建 placement）· 单元格尺寸兜底（终端未上报像素尺寸时按默认 9×18 估算补边几何，断言与 `_view` 纯函数一致；`vim.g.nvkit_viewer_cell_w/_h` 手动指定）· 初始不留 snacks 源图 placement（防"一开始霸屏"） |
| `explorer_preview` | 文件树预览模式：文本预览显示在父窗口且不切焦点 · 移动选择不自动预览（`<CR>` 才预览）· 预览 buffer 不列出 · 文本/图片复用同一 buffer · 文本预览被修改后自动删除 · 图片预览走查看器（预览 buffer 不挂 ft=image 键位/钩子，避免与文件树窗口生命周期冲突）· 手动关闭预览 buffer 后可继续预览（新 buffer）· 切图/切文本预览时删除旧 placement（防旧图残留叠加）· 目录上 `<CR>`/`l` 展开/折叠（两种模式一致）· 切图释放旧位图数据（d=I）· 路径复制（`y` 绝对 / `Y` 相对 nvim 工作目录、多选每行一个、写入剪贴板 `+`）· 大图 JPG 一次 `<CR>` 即出图（转换未完成回退后自动重试，期间不释放当前图）· 标题栏预览模式指示器随开关更新· 关闭预览模式清理 |
| `whichkey` | leader 菜单：classic 网格 · 圆角边框+居中标题 · 列宽 22~34 · nvkit-terminal 的 WhichKey* 主题配色 |
| `viewer_floats` | 浮窗避让只对真正遮挡图片窗口的浮窗生效（文件树 sidebar 的 split 内浮窗不遮挡） · 命令行/动作后图片自动恢复 · 遮挡浮窗关闭后恢复 · 文件树开着时 `:b` 切回已加载图片（分屏）能显示 |
| `theme` | 默认 `nvkit-terminal` + Campbell 色板 · `Normal` 前景 `#cccccc` / 背景 `#0c0c0c`（实色）· String/Number/Keyword/Function/Search 颜色 · Treesitter 捕获同色 · 实色背景下压暗背景与文字 · 可切到 tokyonight/切回 · wezterm 色板 · 透明选项 |
| `ls` | `:ls` 缓冲区列表：cwd 内 `./` 相对路径 · 同名文件保留区分目录（`./v7.4/…/train.log` vs `./v7.5/…/train.log`）· 工作目录外绝对路径 · `%` 当前 buffer 标记 · `:Ls` 通知标题为 `buffers` · 通知底部标志位图例 |
| `pathfmt` | 路径显示：cwd 下加 `./` 前缀 · 家目录 `~` 前缀 · 长路径缩略（`./…/masks/mask.jpg`，保留文件名与唯一后缀、不超预算）· 同名文件去歧义（保留各自不同的目录段）· `buffer_label` 从 buffer 列表自动收集同名兄弟 |
| `viewer_zoom` | 查看器真实缩放路径（源矩形模型 + 画布模型）：z=1 源矩形模式（图片只传一次、补边画布=纯函数 pad 几何、视口=整幅）· 放大/平移只更新源矩形（不重传、不删除，1 次 `a=p`，视口与 `_view` 纯函数一致）· z<1 切画布模式（整图缩小、长宽相等、居中，一次烘焙）· 复位复用缓存不重传 · 渲染节流（连发平移在节流窗口内不分次绘制、合并为一次且两段位移都生效；平移步长 0.05）· 滚轮与按键一致：档位立即生效、节流合并重绘（节流窗口内不重复绘制、停下后合并一次；不再通知）· 窗口事件静默后重放一次 · uv.sleep 加速包装不残留 · UI 浮窗自动避让（浮窗出现隐藏、CmdlineEnter/Leave 隐藏/恢复）· 浏览器流程回归（浮窗中切走再切回图片，≤1s 自动恢复、不按键）· 同一 buffer 重开（:buffer 当前图片，无进入事件）浮窗关闭后 ≤600ms 自动恢复 · 恢复统一为 150ms（浮窗仍在时按 200ms 轮询）· 关闭查看器释放终端位图数据（`d=I`、`sent=false`）· 暂时隐藏只摘 placement 保留数据（无 `d=I`）· 超过 `vim.g.nvkit_viewer_max_pixels` 先降采样（尺寸变小、取消后恢复原尺寸）· 正常打开 JPG（异步转换）自动出图、无需第二次操作 · 扁窗口（上下分屏）补边画布超限时自动改用窗口尺寸画布（避开 WezTerm 单图上限） · 切 buffer 时 rect→canvas 混合状态也删除画布 placement（旧图不残留）、切回自动恢复 · 离开图片窗口删除 placement（空 buffer 切换不重绘格子，防旧图残留叠加）、回到窗口自动恢复（无 ImageMagick 时跳过） |
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
| 终端面板 | `<leader>tp`/`tb` 呼出/收起（没有终端时自动创建）· 侧边栏圆角包边、显示简名 + **稳定编号**（删除不重排）、当前项高亮、鼠标/`<CR>` 切换 · 名字只在侧边栏/浮窗标题/列表出现（底部无名字栏）· `Alt+N` 同类新建 · `Alt+R` 重命名 · `Alt+J`/`Alt+K` 按列表向下/向上且只能同类循环 · `:q`/`q` 收起不杀进程 · 浮动面板从中心“点→线→分裂”展开、关闭镜像折叠（时长 420/300ms 可调） |
| 选择器导航 | 所有 snacks.picker 列表：`Alt+J`/`Alt+K` 上下选择（输入框内也生效，不必先打字） |
| 文件树 / 文件查找 | 默认显示所有文件：`explorer`/`files` 数据源 `hidden+ignored`（不被 `.gitignore` 过滤、不隐藏点文件）；树内仍可用 `Alt+i`/`Alt+h` 临时反向切换 |
| 图片 / PDF 查看器 | 图片/PDF（Kitty 协议终端）在当前窗口等比显示（留边距居中；`q` 关闭）；PDF 默认按页看图（`]p/[p`、滚轮、`PageUp/Down` 翻页；`+/-`/滚轮缩放 0.5x~8x；`h/j/k/l` 平移；`0` 适应窗口；`<leader>rt` 与文本互切），其他终端默认文本模式；缩放经窗口像素画布等比重绘（画布与格子一一对应，避免终端拉伸格子框导致的宽高比失真），换图先画新后撤旧（防闪烁）；滚轮缩放合并为"停下后约 0.15s 一次生效"（防 WezTerm 图片重定位附件累积崩溃 bug，wezterm#7953；仍崩可用 `vim.g.nvkit_viewer_wheel=0` 关滚轮） |
| 终端最大化 | 终端内（含终端窗口的普通模式）`Ctrl+Shift+=` 切换最大化/还原；底部撑满高度、浮窗全屏；再按还原 |

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
