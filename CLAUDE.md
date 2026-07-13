# Claude Code Guide

> 最后更新：2026-07-14 | 版本：v1.0

## 1. 入口规则

Claude Code 在本仓库工作时，先阅读并遵守 `AGENTS.md`。`AGENTS.md` 是共享 AI 代理规则来源，本文件只记录 Claude Code 的补充约定。

如果 `CLAUDE.md` 与 `AGENTS.md` 出现冲突，以 `AGENTS.md` 为准，除非用户在当前任务中明确要求例外。

## 2. Claude Code 补充约定

- 开始实现前先确认任务范围、相关文档和当前 git 状态。
- 不复制 `AGENTS.md` 的主体规则，避免两份入口文档漂移。
- 涉及 Superpowers skill 的任务，按对应 skill 流程执行，并尊重用户对流程的明确要求。
- 修改文件前说明将要编辑的范围；不要改动与任务无关的文件。
- 完成后说明实际运行过的验证命令；无法运行时说明原因。

## 3. 常用入口

- 共享代理规则：`AGENTS.md`
- 编码规范：`docs/CODING_STANDARDS.md`
- 文档规范：`.trae/rules/docs.md`
- 提交规范：`.trae/rules/git-commit-message.md`
- 功能设计规范：`docs/planning/P0/F1/F1_ClipMind_设计规范.md`

## 版本记录

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0 | 2026-07-14 | 初始版本，建立 Claude Code 轻量入口 |
