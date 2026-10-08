# AGENTS.md — nvim-devkit

本仓库是一个科研版 Neovim 发行版：配置 + 一键安装器 + 行为测试。

## 修改规则（必须遵守）

1. **任何影响交互行为的功能修改**（`config/lua/nvim-devkit/**`、`config/lua/config/keymaps.lua`、
   `options.lua`、插件语义、`install.sh`/`uninstall.sh` 行为等），提交前必须运行：
   ```bash
   ./tests/run.sh          # 行为测试（30 用例 / 109 断言），必须全部通过
   scripts/checkhealth.sh  # 健康检查，硬错误必须为 0
   ```
2. 行为契约见 `README.md`（文件/窗口/tab 语义、dashboard、`:q`/`:bd`/`wd`/`:exit` 等）与 `docs/TESTING.md`。
   **若行为变化是有意的**：同步更新 `tests/cases/*`、`README.md`、`docs/CHEATSHEET.md`、`docs/LEARNING.md`，
   并在提交信息中说明；测试与文档不同步视为回归。
3. 新增/更新插件后确认 `config/lazy-lock.json` 已更新并一并提交（版本可复现是发行版的核心承诺）。
4. 不要破坏：`NVIM_APPNAME` 隔离（不动 `~/.config/nvim`）、无 sudo 安装、`--update` 的幂等性。
5. 提交信息写清楚：改了什么行为、跑了哪些测试、结果如何。

## 目录速览

| 路径 | 说明 |
| --- | --- |
| `config/lua/nvim-devkit/` | 自研核心模块：`winbuf`（文件/窗口语义）、`scope_bridge`（tab 会话）、`theme`、`pdf`、`caps`、`recover` |
| `config/lua/config/` | options / keymaps / autocmds / lazy |
| `config/lua/plugins/` | 按主题拆分的插件配置 |
| `tests/` | 行为测试（`run.sh` 为入口，`cases/` 为用例） |
| `docs/` | `TESTING.md`（测试）、`CHEATSHEET.md`（速查）、`LEARNING.md`（学习计划） |
