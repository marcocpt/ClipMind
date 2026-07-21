> 最后更新：2026-07-21 | 版本：v1.2

# F2.1 自动保存到文件 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在白名单 App 中复制长内容时，3 秒内自动保存为文件到指定目录并把剪贴板替换为文件路径，原始内容仍入库 ClipMind 历史。

**架构：** 在 F1.x 既有 `ClipCaptureService.handleClipContent` 入库流程中插入可选闭包钩子（不修改 `init` 签名），触发新增的 `AutoSaveService`。该服务协调白名单检查、长度检查、敏感检查（复用 F1.x `SensitiveDetector`）、文件名生成、冲突处理、文件写入、路径格式化、剪贴板替换，与 F1.x 入库流程互不阻塞。配置通过独立的 `AutoSaveSettingsStore`（UserDefaults 持久化）承载，配置变更立即生效。

**技术栈：** Swift 5.7+ / macOS 12.4+ / SwiftUI + AppKit / XCTest（单元）/ XCUITest（UI）/ SwiftLint strict / xcodegen / GitHub Actions CI（macOS 15 runner）

---

## 1. 必读资料（开始前必读）

| 资料 | 路径 | 用途 |
|------|------|------|
| 共享代理规则 | `AGENTS.md` | 项目工作流、Git 提交、禁止事项 |
| Claude 补充约定 | `CLAUDE.md` | Claude Code 入口规则 |
| 编码规范 | `docs/CODING_STANDARDS.md` | Allman 大括号、4 空格、日志、并发、测试 |
| 文档规则 | `.trae/rules/docs.md` | 文档同步规则 |
| 提交规范 | `.trae/rules/git-commit-message.md` | Conventional Commits |
| 需求文档 | `docs/planning/P1/F2.1/F2.1_自动保存到文件_需求文档.md` | 14 FR + 10 NFR + 16 AC + 12 约束 |
| 设计文档 | `docs/planning/P1/F2.1/F2.1_自动保存到文件_设计文档.md` | 12 新增模块 + 7 既有模块 + 10 关键决策 |
| 视觉原型 | `docs/planning/P1/F2.1/F2.1_自动保存到文件_视觉原型.html` | macOS 设置面板风格 + 8 配置项 + 二次确认弹窗 |
| 测试用例表 | `docs/planning/P1/F2.1/F2.1_自动保存到文件_测试用例表.md` | 16 AC + 33 单元测试 + 10 UI 可观测性 |
| 需求审查结果 | `docs/planning/P1/F2.1/F2.1_自动保存到文件_需求文档_审查结果.md` | 3 子代理审查通过 |
| 设计审查结果 | `docs/planning/P1/F2.1/F2.1_自动保存到文件_设计文档_审查结果.md` | 3 子代理审查通过 |
| 视觉原型审查 | `docs/planning/P1/F2.1/F2.1_自动保存到文件_视觉原型_审查结果.md` | 3 子代理审查通过 |
| 测试用例表审查 | `docs/planning/P1/F2.1/F2.1_自动保存到文件_测试用例表_审查结果.md` | 3 子代理审查通过 |

---

## 2. Phase 列表

| Phase | 目标 | 子计划文件 | 依赖 |
|-------|------|-----------|------|
| Phase 0 | 核心保存逻辑：配置模型 + 持久化 + 文件名生成 + 冲突处理 + 路径格式化 + 主服务（含白名单/长度/敏感/写入/替换）+ 全部单元测试 | `phase-0-core-save-logic.md` | 无 |
| Phase 1 | 集成与 UI：在 `ClipCaptureService` 插入钩子 + 配置面板 UI + AppDelegate 装配 + XCUITest 验证 | `phase-1-integration-ui.md` | Phase 0 完成 |

Phase 0 完成后可独立交付一个"无 UI、无集成"的可测试核心包；Phase 1 把核心包接入 F1.x 捕获流程并暴露配置面板。

---

## 3. 文件结构（任务拆分基础）

### 3.1 新增文件

| 文件路径 | 职责 | Phase |
|---------|------|-------|
| `ClipMind/AutoSave/AutoSaveSettings.swift` | 配置模型（含 `FileFormat`/`PathFormat` 枚举、默认值常量、`defaultWhitelist`） | 0 |
| `ClipMind/AutoSave/AutoSaveSettingsStore.swift` | 配置持久化（UserDefaults 包装、范围校验、去重、变更通知） | 0 |
| `ClipMind/AutoSave/FileNameGenerator.swift` | 文件名生成器（过滤、截断、扩展名）+ 冲突处理器（追加序号） | 0 |
| `ClipMind/AutoSave/FilePathFormatter.swift` | 路径格式化器（纯路径 / file:// URI / Markdown 链接） | 0 |
| `ClipMind/AutoSave/AutoSaveService.swift` | 主服务（final class + 串行队列；白名单/长度/敏感/写入/替换；钩子入口） | 0 |
| `ClipMind/UI/Settings/AutoSaveSettingsView.swift` | 配置面板 UI（8 配置项 + 二次确认弹窗 + 明文责任提示） | 1 |
| `ClipMindTests/AutoSave/AutoSaveSettingsTests.swift` | 配置模型单元测试 | 0 |
| `ClipMindTests/AutoSave/AutoSaveSettingsStoreTests.swift` | 配置持久化单元测试（TC-UT-20~23） | 0 |
| `ClipMindTests/AutoSave/FileNameGeneratorTests.swift` | 文件名生成器单元测试（TC-UT-08~10、TC-AC10） | 0 |
| `ClipMindTests/AutoSave/FileNameConflictResolverTests.swift` | 冲突处理器单元测试（TC-UT-11~13、TC-AC04） | 0 |
| `ClipMindTests/AutoSave/FilePathFormatterTests.swift` | 路径格式化器单元测试（TC-UT-14~16、TC-AC11） | 0 |
| `ClipMindTests/AutoSave/AutoSaveServiceTests.swift` | 主服务单元测试（TC-UT-17~19、TC-UT-24~33、TC-AC06/12/13/14） | 0 |
| `ClipMindUITests/AutoSaveSettingsUITests.swift` | 配置面板 XCUITest（TC-AC07、TC-AC15、TC-AC16、AC-14 二次确认） | 1 |
| `ClipMindUITests/AutoSaveBehaviorUITests.swift` | 端到端 XCUITest（TC-AC08 总开关禁用） | 1 |
| `docs/planning/P1/F2.1/实现计划/manual-acceptance-script.md` | AC-01/02/03/05 手动验收脚本 | 1 |

### 3.2 修改文件

| 文件路径 | 修改内容 | Phase |
|---------|---------|-------|
| `ClipMind/Capture/ClipCaptureService.swift` | 新增可选属性 `autoSaveTrigger: ((ClipContent, _ bundleId: String, _ appName: String) -> Void)?`；在 `handleClipContent` 入库前调用（不改 `init` 签名） | 1 |
| `ClipMind/UI/Settings/SettingsView.swift` | 在 `SettingsTab` 枚举新增 `.autoSave` case；在 `TabView` 新增 `AutoSaveSettingsView()` tab | 1 |
| `ClipMind/App/ClipMindApp.swift` | `AppDelegate.setupCaptureService` 中初始化 `AutoSaveSettingsStore` + `AutoSaveService`，注入 `autoSaveTrigger` 闭包；`applyUITestOverrides` 中处理 `--UITEST_RESET_AUTOSAVE_SETTINGS` | 1 |

### 3.3 不修改的文件（F-01 约束）

- `ClipMind/Capture/PasteboardWatcher.swift`（既有公共回调不变）
- `ClipMind/Capture/AppDetector.swift`（应用识别逻辑不变）
- `ClipMind/Privacy/SensitiveDetector.swift`（敏感识别规则不变）
- `ClipMind/Privacy/BlacklistService.swift`（黑名单逻辑不变）
- `ClipMind/Storage/EncryptedStore.swift`（加密数据库 Schema 不变）
- `ClipMind/Models/AppSettings.swift`（既有配置模型公共字段不变）
- `ClipMind/Models/ClipItem.swift` / `ClipContent.swift` / `ContentType.swift`（数据模型不变）
- `ClipMind/Utils/LogCategory.swift`（既有日志分类不变，F2.1 复用 `storage` 与 `privacy`）

---

## 4. 全局验证命令

### 4.1 本地允许（不执行 test）

```bash
# 生成 Xcode 工程（修改 project.yml 后需要；F2.1 新增目录与文件不需要修改 project.yml，因为 sources 指向 ClipMind 目录）
xcodegen generate

# SwiftLint strict（每次 commit 含 Swift 代码前必跑）
swiftlint lint --strict

# 编译检查（不跑测试，本地允许）
xcodebuild build \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO

# 单个 XCTest 文件快速验证（仅用于 Phase 0 单元测试快速反馈，不替代 CI）
# 注意：必须用 -only-testing-option 限定到具体测试类，避免触发其他测试
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/AutoSaveSettingsTests'
```

### 4.2 CI 必跑（push 后自动）

GitHub Actions（`.github/workflows/ci.yml`）在 macOS 15 runner 上执行：

1. `xcodegen generate`
2. `swiftlint lint --strict --reporter github-actions-logging`
3. `xcodebuild build`（编译）
4. `xcodebuild test`（全量回归 + XCUITest）

**禁止本地执行全量 `xcodebuild test`**，所有全量回归与 XCUITest 必须延迟到 push 后走 CI。本地仅允许 `xcodebuild build` 与单文件 `-only-testing` 单元测试快速反馈。

**XCUITest 附件上传**：所有 XCUITest 类（`AutoSaveSettingsViewComponentsTests`、`AutoSaveSettingsUITests`、`AutoSaveBehaviorUITests`）的 `tearDown()` 会通过 `XCTAttachment` 保存测试结束时的截图作为失败诊断证据。GitHub Actions test-results artifact 自动收集所有附件，便于在 CI 失败时定位问题。

### 4.3 失败处理

- SwiftLint strict 失败：不得 commit
- 编译失败：不得 commit，修复后重跑
- 单元测试失败：不得 commit，修复后重跑
- CI 失败：阻塞合并，根据 CI 上传的 test-results artifact 定位失败

---

## 5. 最终验收方式

### 5.1 Phase 0 验收

- 5 个新增 Swift 文件存在
- 6 个单元测试文件存在
- 本地 `swiftlint lint --strict` 通过
- 本地 `xcodebuild build` 通过
- 本地单文件 `-only-testing` 单元测试通过（覆盖 TC-UT-01~33、TC-AC04、TC-AC06、TC-AC10、TC-AC11、TC-AC12、TC-AC13、TC-AC14）
- CI 全量回归通过

### 5.2 Phase 1 验收

- 3 个修改文件改动完成（`ClipCaptureService.swift`、`SettingsView.swift`、`ClipMindApp.swift`）
- 2 个新增 UI 文件存在（`AutoSaveSettingsView.swift`、`ClipMindUITests/AutoSave*.swift`）
- 本地 `swiftlint lint --strict` 通过
- 本地 `xcodebuild build` 通过
- CI XCUITest 通过（覆盖 AC-01、AC-05 烟雾、AC-07、AC-08、AC-09、TC-AC15、TC-AC16、AC-14 二次确认）
- 手动验收（仅 CI 无法覆盖的场景）：
  - 在真实 Safari 中复制 100 字内容，3 秒内保存目录出现 Markdown 文件，剪贴板替换为路径
  - 在真实"备忘录"中复制 100 字内容，保存目录不出现新文件
  - 在真实 Safari 中复制 <50 字内容，保存目录不出现新文件
  - 截图存放到 `docs/planning/P1/F2.1/screenshots/`，录屏存放到 `docs/planning/P1/F2.1/recordings/`

### 5.3 整体验收

- 16 条 AC（AC-01~AC-16）全部覆盖
- 33 条单元测试（TC-UT-01~33）全部覆盖
- 10 项 UI 可观测性矩阵全部覆盖
- 文档同步：实现完成后更新 `F2.1_自动保存到文件_测试用例表.md` 的覆盖状态（将 ❌ MISSING 改为 ✅ COVERED）
- 在 `docs/planning/P1/F2.1/historys/` 追加 `YYYY-MM-DD-实现计划完成.md` 日志

---

## 6. 全局约束（每步必检）

1. **TDD 优先**：每个任务先写失败测试，再写实现，再验证通过
2. **每步即提交**：每个任务完成后 `git add` + `git commit`，遵循 Conventional Commits（如 `feat(F2.1): 实现 FileNameGenerator`）
3. **SwiftLint strict**：每次 commit 含 Swift 代码前必跑 `swiftlint lint --strict`
4. **Allman 大括号 + 4 空格**：所有 Swift 代码遵守
5. **LogCategory 日志**：禁止 `print()`，使用 `LogCategory.storage` 或 `LogCategory.privacy`
6. **不修改 F1.x 既有公共接口**：`PasteboardWatcher`、`AppDetector`、`SensitiveDetector`、`BlacklistService`、`EncryptedStore`、`AppSettings`、`ClipItem`、`ClipContent`、`ContentType` 不变；`ClipCaptureService.init` 签名不变（只新增可选属性）
7. **macOS 12.4 兼容性**：不使用 `NavigationStack`、`@Observable` 宏、`SwiftData` 等 macOS 13+ 独占 API
8. **不引入新的外部依赖**：仅使用 Foundation / AppKit / SwiftUI / OSLog / SQLite.swift（既有）
9. **类型一致性**：后续任务使用的类型、方法签名、属性名必须与前面任务定义的一致
10. **禁止占位符**：每个步骤必须包含实际代码或命令，不得出现"待定"/"TODO"/"后续实现"/"类似任务 N"/"添加适当的错误处理"等模糊描述

---

## 版本记录

| 版本 | 日期 | 变更说明 |
|------|------|---------|
| v1.0 | 2026-07-21 | 初始版本，writing-plans skill 产出，含总计划 + Phase 0/Phase 1 子计划，覆盖 14 FR + 16 AC + 33 单元测试 + 10 UI 可观测性 |
| v1.1 | 2026-07-21 | 修复 check-plan 发现的 9 项必须修复问题：修正 Phase 0 文件数量为 5；CI XCUITest 覆盖范围补充 AC-01/05/07/09；4.2 节追加 XCUITest 附件上传说明 |
| v1.2 | 2026-07-21 | 修复第二轮 check-plan 发现的 4 项必须修复问题：3.1 节新增文件表追加 `docs/planning/P1/F2.1/实现计划/manual-acceptance-script.md`（AC-01/02/03/05 手动验收脚本，Phase 1），与 phase-1 1.1 节"创建 1 个手动验收脚本"声明一致。 |
