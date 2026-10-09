# 贡献指南

## 本项目不接受外部 Pull Request

nvim-devkit 由作者独立开发与维护，**不接受来自外部的 Pull Request**（无论质量高低）。原因：

- 行为语义高度定制（见 README「文件 / 窗口 / 标签页语义」），合并外部改动需要大量回归成本
- 行为测试与文档必须同步演进，外部提交难以保证

**欢迎的参与方式：**

- 提交 **Issue**：Bug 报告、行为建议、兼容性问题
- 发起 **Discussion**：用法讨论、配置分享、想法交流
- **Fork 自用**：MIT 许可允许你自由 fork、修改、分发自己的版本；但上游不会合并你的改动

## 如果你要自己改（fork 后）

1. 任何交互行为的修改必须跑行为测试：

   ```bash
   ./tests/run.sh          # 31 个用例 / 132 项断言，必须全部通过
   scripts/checkhealth.sh  # 硬错误必须为 0
   ```

2. 行为变化需同步更新：`tests/cases/*`、`README.md`、`docs/CHEATSHEET.md`、`docs/LEARNING.md`
3. AI 协作者请先读仓库根目录的 `AGENTS.md`

## 报告 Issue 的建议

- 环境信息：`nvim-devkit --version`、`:checkhealth` 相关输出
- 复现步骤与预期行为（可对照 README 的行为契约 / `docs/TESTING.md`）
- 相关日志：测试失败日志在 `/tmp/nvim-devkit-tests/log-<用例>.txt`；编辑器内可用 `:messages`
