# ClipMind AI Agent Guide

> 最后更新：2026-07-23 | 版本：v1.1

## 1. 项目定位

ClipMind 是 Swift 5.7+ / macOS 13+ 的原生桌面 App，把系统剪贴板升级为会自动分类、总结、搜索和复用的 AI 信息库。核心价值：可找回、可理解、可复用、可安心。

当前代码以初赛 MVP（F1.x）为主线推进。处理需求时先确认它属于哪个功能阶段，再阅读对应规划文档。

## 2. 必读资料

开始改动前至少阅读与任务相关的权威文档：

- `docs/CODING_STANDARDS.md`：Swift 编码规范、测试规范、日志、并发和架构边界。
- `docs/planning/P0/F1/F1_ClipMind_设计规范.md`：产品定位、功能优先级、模块关系和阶段状态。
- `.trae/rules/docs.md`：`docs/` 下设计规范、实施草案、实现计划、视觉原型、history 日志的同步规则。
- `.trae/rules/git-commit-message.md`：Conventional Commits 提交信息规范。

如果任务涉及具体功能，继续阅读 `docs/planning/P0/...` 下对应的设计规范、实施草案、实现计划和 history 记录。

## 3. 架构边界

项目采用单 Xcode 工程多 target 结构（通过 xcodegen 生成）：

- `ClipMind`：App target，应用主代码。使用 SwiftUI + AppKit（NSStatusItem 菜单栏、NSPopover）。模块组织：`App`、`Capture`、`Classify`、`LLM`、`ML`、`Models`、`Privacy`、`Search`、`Storage`、`UI`、`Utils`。
- `ClipMindTests`：单元测试 target，使用 XCTest 验证核心逻辑。
- `ClipMindUITests`：UI 测试 target，通过 `XCUIApplication()` 验证端到端行为。

依赖方向：App target 内部模块按职责分层，`UI` → 业务模块（`Capture`/`Classify`/`LLM`/`ML`/`Search`/`Storage`/`Privacy`）→ `Models` / `Utils`。外部依赖通过 SQLite.swift（SPM）访问本地数据库。

## 4. 工作流程

1. 先看当前 git 状态，识别已有用户改动，避免覆盖无关文件。
2. 阅读相关规划和规范文档，确认目标、范围、验收标准和已有约束。
3. 涉及新功能、行为变化、UI 变化或架构调整时，先更新或创建设计规范、实施草案、实现计划，再改代码。
4. 实现时优先 TDD：先写能失败的 XCTest/XCUITest 或最小验证，再写实现，再运行验证。
5. 修改范围保持聚焦。不要顺手重构无关模块，不要把格式化噪音混入功能改动。
6. 完成前运行与风险匹配的验证命令，并在最终说明中列出实际运行结果。

## 5. 文档同步

遵守 `.trae/rules/docs.md`：

- 修改设计目标、范围、业务流程、接口或验收标准时，同步更新设计评审摘要。
- 修改技术架构、接口、数据模型或异常处理时，同步更新实施草案。
- 修改实施步骤、测试策略或任务拆分时，同步更新实现计划。
- 涉及 UI 行为变化时，同步更新视觉原型。
- 每次关键 docs、功能设计、实现计划或架构决策变更，都要在对应 `historys/` 目录追加 `YYYY-MM-DD-修改摘要.md`。
- Markdown 标题后第一行使用 `> 最后更新：YYYY-MM-DD | 版本：vX.Y`，末尾保留版本记录。

## 6. 编码规范

遵守 `docs/CODING_STANDARDS.md` 和 `.swiftlint.yml`：

- Swift 使用 Allman 大括号风格，4 空格缩进。
- 公共 API 必须有文档注释，复杂内部逻辑需要简洁说明。
- 使用 `LogCategory` 记录日志，禁止直接 `print()`。
- 错误日志需要上下文 metadata，日志不得输出敏感信息、用户输入内容或包含用户名的文件路径。
- UI 状态更新必须在主线程或 `@MainActor` 边界内完成。
- 避免魔术数字和魔术字符串；配置键、UserDefaults 键、通知名使用命名常量。
- Mock 只模拟外部依赖，不 mock 被测对象本身。

## 7. 验证命令

按改动范围选择验证。常用命令：

```bash
# 生成 Xcode 工程（修改 project.yml 后需要重新生成）
xcodegen generate

# Lint（含 Swift 改动时 commit 前强制 strict）
swiftlint lint --strict

# 完整测试（CI 与本地基线测试复用同一命令，基于 xcodebuild test）
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO

# 快速编译检查
xcodebuild build \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```

CI 使用 GitHub Actions（`.github/workflows/ci.yml`）在 macOS 15 runner 上执行：安装 swiftlint/xcodegen/xcbeautify → 生成工程 → SwiftLint strict → build → test。本地基线测试复用同一 xcodebuild test 命令。

如果无法运行某条命令，记录原因和替代验证，不要声称未运行的验证已经通过。

## 8. Git 与提交

- 每次执行 `git commit` 前，如本次改动包含 Swift 代码，必须先运行 `swiftlint lint --strict`；未通过不得提交。仅文档、配置等非代码改动可跳过。
- 仓库已配置 `.githooks/pre-commit` 钩子自动执行 SwiftLint strict 检查。
- 提交信息遵守 Conventional Commits：`<type>(<scope>): <subject>`。
- 常用 type：`feat`、`fix`、`docs`、`style`、`refactor`、`test`、`chore`。
- subject 使用简洁祈使语气，不超过 50 字符。
- 不提交无关文件、构建产物、DerivedData 或个人环境文件。
- 工作树中如有他人改动，必须保留并绕开，除非用户明确要求处理。

## 9. 禁止事项

- 禁止在日志中输出密码、Token、验证码等敏感信息或用户剪贴板原文。
- 禁止绕过文档同步规则直接改变用户可见行为。
- 禁止用固定 sleep 代替明确条件等待来掩盖异步竞态。
- 禁止吞掉错误或只写自然语言日志而没有可检索上下文。
- 禁止在未加密状态下持久化存储敏感剪贴板内容。

## 10. App Store 合规要求

ClipMind 计划上架 Mac App Store，所有面向发布的代码必须满足 App Store Review Guidelines 与 macOS 沙盒、隐私、权限等合规约束。

- 主 Scheme `ClipMind` 是 App Store 上架构建目标，必须保持完全合规：启用 App Sandbox、仅申请最小必要 entitlement、不使用私有 API、敏感剪贴板内容加密持久化、遵守 Privacy Manifest 与 TCC 权限声明。
- 实现新特性时，必须先尝试找到合规的实现方法（沙盒内 API、公开框架、标准权限流程）。
- 只有在穷尽合规方案仍无法实现时，才允许将该特性暂存到 `ClipMind-Dev` Scheme 中验证，不得直接合入主 Scheme。
- `ClipMind-Dev` 是开发验证用 Scheme，仅用于本地验证与技术可行性评估，不得进入 App Store 发布构建。
- 一旦为 `ClipMind-Dev` 中的特性找到合规实现，必须立即迁移回主 Scheme `ClipMind`，并在提交信息中说明合规方案。
- 暂存于 `ClipMind-Dev` 的特性需在对应设计规范/实施草案中标注「合规待定」状态，避免被误认为可发布。

## 版本记录

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0 | 2026-07-14 | 初始版本，建立 AI 代理主入口 |
| v1.1 | 2026-07-23 | 新增第 10 节 App Store 合规要求，区分主 Scheme `ClipMind` 与开发验证 Scheme `ClipMind-Dev` |
