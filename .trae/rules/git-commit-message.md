---
alwaysApply: false
description: git 写 commit message
scene: git_message
---
## Git 提交信息规范

### Conventional Commits

遵循 [Conventional Commits](https://www.conventionalcommits.org/) 规范。

**格式：**
```
<type>(<scope>): <subject>

<body>

<footer>
```

**类型（type）：**
- `feat`: 新功能
- `fix`: Bug 修复
- `docs`: 文档更新
- `style`: 代码格式（不影响功能）
- `refactor`: 重构
- `test`: 测试相关
- `chore`: 构建/工具相关

**示例：**
```
feat(Capture): 添加剪贴板内容去重功能

- 实现内容哈希去重策略
- 添加去重阈值配置
- 支持手动清除重复项

Closes #123
```

**规则：**
1. subject 不超过 50 字符，以动词开头，使用祈使语气
2. body 使用换行分隔，每行不超过 72 字符
3. footer 用于引用 Issue 或 Breaking Changes
4. scope 为可选，用于标识修改范围
