# Day 4 练习场：搜索与替换

配套 `docs/LEARNING.md` 的 Day 4。三个文件里故意埋好了目标词（调用点、重复词、TODO、未定义变量），**随便改**，练完用 `git checkout -- docs/practice/day4` 复原。

## 准备

```bash
cd ~/nvim-devkit/docs/practice/day4
nvim-devkit
```

迷路就 `Esc` 清高亮 / `Ctrl-g` 恐慌重置；改错了 `u` 撤销。

## 12 个练习（按顺序做）

### 1. `/` 搜索 + `n` / `N`
`gg` 回开头 → `/format_metric<回车>` → 连按 `n`。
- 目标：数出这个函数在 `a.py` 里出现几次（定义也算）
- 预期 **5 次**；`n` 往下、`N` 往回；`Esc` 清掉黄色高亮

### 2. `*` 搜光标词
光标放在任意 `format_metric` 上按 `*`。
- 效果：不用输字，直接高亮全文同名词并跳到下一个；接着 `n`/`N`
- 对比：`*` 只能搜"光标下的词"，`/` 可以搜任意内容

### 3. 全项目搜索 `<leader>/`
按 `空格` `/`，输入 `compute_loss` 回车。
- 应该看到 `c.py` 里的定义和调用（跨文件搜索）
- 这就是"找一个函数所有调用点"的正确姿势：结果列表里 ↑/↓ 或 `Ctrl-n/Ctrl-p` 移动、回车跳转、`Esc` 关闭

### 4. `<leader>sw` 搜当前词
光标放在 `compute_loss` 上，按 `空格 s w`：一键全项目搜当前词，效果同上但不用输字。

### 5. 行内替换 `:s`
在 `a.py` 找到这行：`metric_name = "metric"  # metric 出现第 1 次`
- 输入 `:s/metric/tensor/g` 回车
- 预期：**该行 3 处**全部变成 `tensor`；打字时注意底部实时预览（inccommand）；`u` 撤销重来

### 6. 不带 `g` 的 `:s`
同行按两次 `:s/metric/tensor`（没有 `g`）。
- 每次只换该行的**第一处**；两次才换完两处
- 结论：`:s` 只作用于当前行，`g` 决定是否替换行内全部

### 7. 全文件 + 逐个确认 `:%s//gc`
打开 `b.py`（先 `Esc` 清高亮），输入 `:%s/result/output/gc` 回车。
- 预期 **6 处**（含 `result_count` 里的子串）
- 每处跳出来时：`y` 替换 / `n` 跳过 / `q` 中止 / `a` 全部
- 观察每次确认前光标跳到哪，理解"逐个确认"的价值

### 8. smartcase 与单词边界（本配置 `ignorecase+smartcase`）
在 `b.py`：
- `/TODO` → **2 处**（含大写 → 区分大小写）
- `/todo` → **3 处**（全小写 → 自动忽略大小写）
- `:%s/TODO/DONE/gi` → 3 处全变（`i` 显式忽略大小写）
- 搜 `result` 会连带 `result_count` 里的子串；试 `/\v<result>`（单词边界）→ 只匹配独立的 `result` **3 处**

### 9. 诊断列表 `<leader>sd`
打开 `c.py`（里面有一个故意未定义的变量），按 `空格 s d`：
在列表里找到 `undefined_gap`，回车跳到现场。这是以后调试前的"扫雷"姿势。

### 10. 键位搜索 `<leader>sk`
按 `空格 s k`，输入 `grep` 或 `搜索`，看所有和搜索相关的键位——忘了键位就靠它。

### 11. 综合：改完全项目
把 `b.py` 里独立的 `result` 全部改成 `output`（先 `/result` 数清楚，再 `:%s/result/output/gc` 逐个确认）。
完成后 `空格 /` 全项目搜 `result`：应该只剩 `RESULT_LIMIT` 这类大写（默认区分大小写搜不到）。

### 12. 恢复练习
- `u` 撤销、`Ctrl-r` 重做
- `:earlier 2m` 回到两分钟前的整棵树
- 退出 nvim 后复原全部练习文件：`git checkout -- docs/practice/day4`

## 答案速查

| 练习 | 答案 |
| --- | --- |
| 1 | `format_metric` 共 **5** 处（1 定义 + 4 调用） |
| 7 | 小写 `result` 共 **6** 处（含 `result_count`） |
| 8 | `/TODO`=2、`/todo`=3、`:%s/TODO/DONE/gi`=3、`/\v<result>`=3 |
| 11 | 全项目 `result` 替换后应无小写命中（大写 `RESULT_LIMIT` 不算） |
