> 最后更新：2026-07-22 | 版本：v2.2

# F2.1 自动保存到文件 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。本计划基于 v1.1 设计文档套件重写，落地 24 条决策（D1~D24）。每个任务都必须严格按 TDD 四步执行（编写失败测试 → 验证失败 → 最小实现 → 验证通过 → commit）。

**目标：** 在白名单 App（Safari/Chrome/Trae/VSCode/Xcode）中复制长内容（≥长度阈值）时，自动保存为文件（Markdown/纯文本）并把剪贴板替换为文件路径（plainPath/fileURI/markdownLink），同时 F1.x 原内容仍正常入库。F2.1 与 F1.x 入库流程并行执行，互不阻塞（FR-014）。

**架构：** 在 PasteboardWatcher 中构造不可变 `CaptureEvent` 快照（含 id/changeCount/content/bundleId/appName/blacklisted/sensitiveResult/f1xConfigSnapshot/f2xConfigSnapshot/timestamp），敏感识别只执行一次（D2）并打包进事件。F1.x 入库同步执行，F2.1 自动保存异步派发到专用串行队列 `DispatchQueue(label:, qos: .utility)`（D7）。自我写入抑制器（`SelfWriteSuppressor`）通过 `markSelfWrite(changeCount:)` + `checkAndReset(changeCount:)` 配合 5 秒超时避免回环（D4）。changeCount 前置条件（D5）保证替换剪贴板后不重复触发。F1.x 黑名单优先于 F2.1（D3，AND 关系：黑名单命中则跳过 F2.1）。

**技术栈：** Swift 5.7+ / macOS 12.4+ / SwiftUI + AppKit（NSStatusItem、NSPopover、NSPasteboard）/ Foundation（FileManager O_EXCL、POSIX 0600）/ XCTest + XCUITest / SwiftLint strict / xcodegen / Conventional Commits

---

## 1. 必读资料

执行任何任务前必须完整阅读以下文档（按顺序）：

| 序号 | 文档 | 版本 | 路径（相对仓库根） | 用途 |
|------|------|------|--------------------|------|
| 1 | 设计文档 | v1.1 | `docs/planning/P1/F2.1/F2.1_自动保存到文件_设计文档.md` | 架构契约，24 条决策（D1~D24）落地依据 |
| 2 | 需求文档 | v1.1 | `docs/planning/P1/F2.1/F2.1_自动保存到文件_需求文档.md` | 单一需求来源（18 FR + 11 NFR + 22 AC + 14 约束 + F-11 例外） |
| 3 | 测试用例表 | v1.2 | `docs/planning/P1/F2.1/F2.1_自动保存到文件_测试用例表.md` | 测试契约（49 单元测试 + 14 并发场景 + 22 AC 覆盖矩阵 + 11 NFR 矩阵） |
| 4 | 视觉原型 | v1.0 | `docs/planning/P1/F2.1/F2.1_自动保存到文件_视觉原型.html` | 配置面板 UI 契约（8 配置项 + 路径预览 + 二次确认） |
| 5 | 架构修订摘要 | v1.0 | `docs/planning/P1/F2.1/historys/2026-07-22-架构修订摘要.md` | v1.0 → v1.1 修订原因与 24 条决策概览 |
| 6 | 编码规范 | v1.0 | `docs/CODING_STANDARDS.md` | Allman 大括号 + 4 空格 + LogCategory + 并发规则 |
| 7 | 项目规则 | v1.0 | `AGENTS.md` + `.trae/rules/docs.md` + `.trae/rules/git-commit-message.md` | 工作流 + 文档同步 + 提交规范 |
| 8 | F1.x 设计规范 | v1.0 | `docs/planning/P0/F1/F1_ClipMind_设计规范.md` | F1.x 既有模块协作关系（不可修改公共接口） |

---

## 2. 24 条决策（D1~D24）落地位置索引

| 决策 | 摘要 | 落地 Phase | 落地任务 |
|------|------|-----------|----------|
| D1 | 事件驱动模型 CaptureEvent 快照 | Phase 0 | 任务 1（CaptureEvent）、任务 12（AutoSaveService 注入） |
| D2 | 敏感识别只执行一次，结果打包进事件 | Phase 1 | 任务 2（捕获事件构造器） |
| D3 | F1.x 黑名单优先于 F2.1（AND 关系） | Phase 1 | 任务 2（捕获事件构造器）、任务 3（ClipCaptureService 适配） |
| D4 | 自我写入抑制器（markSelfWrite + checkAndReset，5s 超时） | Phase 0 | 任务 6（SelfWriteSuppressor） |
| D5 | changeCount 前置条件（pasteboard.changeCount == event.changeCount） | Phase 0 | 任务 11（ClipboardReplacer）、任务 12（AutoSaveService） |
| D6 | 配置快照不可变（事件构造阶段读取，异步执行不读实时配置） | Phase 0 | 任务 3（F2xConfigSnapshot）、任务 12（AutoSaveService） |
| D7 | 轻量检查同步 + 文件 I/O 异步串行队列（100ms 内返回） | Phase 0 | 任务 12（AutoSaveService）、任务 13（PollingHelper） |
| D8 | 三层测试策略（XCTest 集成 + XCUITest UI + 手动 OS 边界） | 全局 | README §6 + Phase 0 任务 14 + Phase 1 任务 7~9 |
| D9 | 文件名生成 8 步单一确定顺序 | Phase 0 | 任务 7（FileNameGenerator） |
| D10 | O_EXCL 原子创建 + 半成品清理 | Phase 0 | 任务 9（FileWriter） |
| D11 | 总开关默认关闭（D11 修正需求文档 v1.0 的默认开） | Phase 0 | 任务 4（AutoSaveSettings 默认 isEnabled=false） |
| D12 | 文本输入边界（图片/文件路径列表不触发，100KB 上限） | Phase 0 | 任务 12（AutoSaveService 边界检查） |
| D13 | 目录异常分级处理（创建失败/写入失败/权限失败） | Phase 0 | 任务 9（FileWriter）、任务 12（AutoSaveService） |
| D14 | POSIX 0600 文件权限 | Phase 0 | 任务 9（FileWriter） |
| D15 | 日志白名单 9 字段 + 5 项禁输出 | 全局 | README §7 全局约束 6 + 所有任务日志语句 |
| D16 | URI 标准编码（file:// URI + Markdown 链接目标 URL 编码） | Phase 0 | 任务 10（FilePathFormatter） |
| D17 | PollingHelper.waitUntil 轮询（10ms 间隔，3s 超时，禁止 sleep 3） | Phase 0 | 任务 13（PollingHelper） |
| D18 | XCTest 集成测试覆盖业务逻辑 AC（AC-01~06、08、10~14、17~22） | Phase 0 | 任务 14（XCTest 集成测试） |
| D19 | XCUITest 只验证 UI 交互（AC-07、09、15、16） | Phase 1 | 任务 7（AutoSaveSettingsUITests）、任务 8（AutoSaveBehaviorUITests） |
| D20 | 手动测试只验证 OS 边界（Finder 打开/权限弹窗/真实 Safari） | Phase 1 | 任务 9（手动验收脚本） |
| D21 | 性能测试记录实际耗时并断言 P95 | Phase 0 | 任务 14（性能测试） |
| D22 | 不修改 F1.x 既有公共接口（F-11 例外：扩展 PasteboardWatcher.onPasteboardChange 回调参数） | Phase 1 | 任务 1（PasteboardWatcher 扩展） |
| D23 | 配置快照机制（事件构造阶段读取，异步执行期间不读实时配置） | Phase 0 | 任务 3（F2xConfigSnapshot）、任务 12（AutoSaveService） |
| D24 | 错误恢复不重试旧事件（changeCount 已过期即放弃） | Phase 0 | 任务 12（AutoSaveService） |

---

## 3. Phase 列表

| Phase | 目标 | 子计划文件 | 依赖 | 任务数 |
|-------|------|-----------|------|--------|
| Phase 0 | 核心保存逻辑：CaptureEvent、SensitiveMatchResult、F2xConfigSnapshot、AutoSaveSettings、AutoSaveSettingsStore、SelfWriteSuppressor、FileNameGenerator、ConflictResolver、FileWriter、FilePathFormatter、ClipboardReplacer、AutoSaveService、PollingHelper、XCTest 集成测试 | `phase-0-core-save-logic.md` | 无 | 14 |
| Phase 1 | 集成与 UI：PasteboardWatcher 扩展、捕获事件构造器、ClipCaptureService 适配、AutoSaveSettingsView UI、SettingsView tab、AppDelegate 装配、XCUITest×2、手动验收脚本、集成测试 | `phase-1-integration-ui.md` | Phase 0 完成 | 10 |

**总任务数：** 24 个任务（Phase 0：14，Phase 1：10）

---

## 4. 文件结构

### 4.1 Phase 0 新增文件（14 个）

| 文件路径 | 职责 | 对应任务 |
|----------|------|----------|
| `ClipMind/AutoSave/Models/CaptureEvent.swift` | 不可变事件快照 struct（D1/D6） | 任务 1 |
| `ClipMind/AutoSave/Models/SensitiveMatchResult.swift` | 敏感识别结果 struct（D2） | 任务 2 |
| `ClipMind/AutoSave/Models/F2xConfigSnapshot.swift` | F2.1 配置快照 struct（D6/D23） | 任务 3 |
| `ClipMind/AutoSave/AutoSaveSettings.swift` | 配置模型 + FileFormat/PathFormat 枚举 + 默认值（D11 总开关默认关闭） | 任务 4 |
| `ClipMind/AutoSave/AutoSaveSettingsStore.swift` | 配置持久化（UserDefaults）+ 范围校验 + 白名单去重 | 任务 5 |
| `ClipMind/AutoSave/SelfWriteSuppressor.swift` | 自我写入抑制器（D4 markSelfWrite + checkAndReset，5s 超时） | 任务 6 |
| `ClipMind/AutoSave/FileNameGenerator.swift` | 文件名生成 8 步（D9） | 任务 7 |
| `ClipMind/AutoSave/ConflictResolver.swift` | 冲突处理器（数字后缀递增） | 任务 8 |
| `ClipMind/AutoSave/FileWriter.swift` | 文件写入器（D10 O_EXCL + D14 0600 + D13 异常分级） | 任务 9 |
| `ClipMind/AutoSave/FilePathFormatter.swift` | 路径格式化器（D16 URI 编码） | 任务 10 |
| `ClipMind/AutoSave/ClipboardReplacer.swift` | 剪贴板替换器（D5 changeCount 前置条件） | 任务 11 |
| `ClipMind/AutoSave/AutoSaveService.swift` | 主服务（D7 串行队列 + D12 边界 + D24 不重试） | 任务 12 |
| `ClipMind/Utils/PollingHelper.swift` | 轮询工具（D17 10ms 间隔，3s 超时） | 任务 13 |
| `ClipMindTests/AutoSave/*.swift` | 单元测试 + 集成测试 + 性能测试（D8/D18/D21） | 任务 14 |
| `ClipMindTests/Fixtures/CaptureEventFixtures.swift` | 测试 Fixtures（D18 测试夹具） | 任务 14 |

### 4.2 Phase 1 新增文件（5 个）

| 文件路径 | 职责 | 对应任务 |
|----------|------|----------|
| `ClipMind/Capture/CaptureEventBuilder.swift` | 捕获事件构造器（B0，构造 CaptureEvent 含敏感识别与配置快照） | 任务 2 |
| `ClipMind/UI/Settings/AutoSaveSettingsView.swift` | 配置面板 SwiftUI 视图（8 配置项 + 路径预览 + 二次确认）。长度阈值/文件名长度控件类型变更：Stepper → TextField + @FocusState 失焦逻辑（决策 C1~C6，详见 `historys/2026-07-22-配置面板长度阈值改为TextField.md`） | 任务 4 |
| `ClipMindUITests/AutoSaveSettingsUITests.swift` | AC-07/15/16 UI 测试（D19） | 任务 7 |
| `ClipMindUITests/AutoSaveBehaviorUITests.swift` | AC-09 UI 测试（D19） | 任务 8 |
| `docs/planning/P1/F2.1/实现计划/manual-acceptance-script.md` | 手动验收脚本（D20 OS 边界） | 任务 9 |

### 4.3 Phase 1 修改文件（4 个，F-11 例外仅 1 处）

| 文件路径 | 修改内容 | 对应任务 | F-11 例外 |
|----------|----------|----------|-----------|
| `ClipMind/Capture/PasteboardWatcher.swift` | 扩展 `onPasteboardChange` 回调参数为 `CaptureEvent`（F-11 例外条款） | 任务 1 | ✅ 是 |
| `ClipMind/Capture/ClipCaptureService.swift` | 适配 CaptureEvent，调用 AutoSaveService.handle(event:)，F1.x 入库流程不变 | 任务 3 | 否（仅内部调用） |
| `ClipMind/UI/Settings/SettingsView.swift` | TabView 新增"自动保存"tab | 任务 5 | 否（新增 case） |
| `ClipMind/App/ClipMindApp.swift` | AppDelegate 装配 AutoSaveService 与 SelfWriteSuppressor | 任务 6 | 否（仅装配） |

### 4.4 不修改文件（F1.x 既有公共接口锁定）

- `ClipMind/Models/ClipItem.swift`、`ClipMind/Models/ClipContent.swift`
- `ClipMind/Storage/EncryptedStore.swift`
- `ClipMind/Capture/SensitiveDetector.swift`（仅读取其结果，不修改接口）
- `ClipMind/Capture/AppDetector.swift`
- `ClipMind/ML/LocalEmbeddingService.swift`、`ClipMind/Classify/ClassificationService.swift`
- F1.x 既有设置面板分区（`APIKeyConfigView.swift`、`PrivacySettingsView.swift`、`GeneralSettingsView.swift`）

---

## 5. 全局验证命令

### 5.1 本地允许执行的验证

```bash
# 工作目录
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1-auto-save-to-file

# 生成 Xcode 工程（修改 project.yml 后必跑）
xcodegen generate

# SwiftLint strict（任何 Swift 改动 commit 前必跑，未通过不得提交）
swiftlint lint --strict

# 快速编译检查（验证类型一致性与编译错误）
xcodebuild build \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO

# 单文件单元测试（Phase 0 任务验证，-only-testing 限定单个测试类）
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/AutoSaveSettingsTests'
```

### 5.2 CI 必跑（本地不执行）

```bash
# 全量测试（CI 兜底，本地禁止执行以避免 XCUITest 与全量回归开销）
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

### 5.3 失败处理

- **SwiftLint strict 失败**：必须修复后才能 commit，禁止用 `// swiftlint:disable` 绕过（除非有明确架构理由并在 commit message 说明）。
- **xcodebuild build 失败**：修复类型一致性错误（D 决策落地位置索引中的类型签名必须前后一致）。
- **xcodebuild test -only-testing 失败**：按 TDD 循环修复，不得跳过测试或降低断言强度。
- **XCUITest 失败（仅 CI）**：由 CI 报告，本地不执行；修复后由 CI 重新验证。

---

## 6. 三层测试策略（D8）

| 层级 | 工具 | 覆盖 AC | 执行位置 | 负责任务 |
|------|------|---------|----------|----------|
| 第 1 层：XCTest 集成测试 | XCTest | AC-01~06、08、10~14、17~22（业务逻辑部分） | 本地 `-only-testing` + CI 全量 | Phase 0 任务 14、Phase 1 任务 10 |
| 第 2 层：XCUITest UI 测试 | XCUITest | AC-07（配置面板修改）、AC-09（保存目录异常弹窗）、AC-15（白名单增删）、AC-16（配置持久化） | 仅 CI（本地禁止执行） | Phase 1 任务 7、8 |
| 第 3 层：手动 OS 边界测试 | 人工 | AC-01（真实 Safari 复制）、AC-02（真实 Notes 复制）、AC-03（Finder 打开文件）、AC-05（历史条目可见）、AC-17~22（NFR 性能与兼容性） | 开发者本机手动 | Phase 1 任务 9 |

**原则（D8）：** XCTest 覆盖所有业务逻辑可验证的 AC；XCUITest 只验证 UI 交互（不重复 XCTest 已覆盖的逻辑）；手动测试只验证 OS 边界（真实 App 行为、权限弹窗、Finder 集成），不验证可自动化的逻辑。

---

## 7. 全局约束（每步必检，共 10 条）

1. **禁止占位符**：任何步骤不得出现"待定"/"TODO"/"后续实现"/"类似任务 N"/"添加适当的错误处理"等模糊描述。每个代码步骤必须包含完整可执行代码。
2. **TDD 优先**：每个任务严格按"编写失败测试 → 运行验证失败 → 编写最少实现 → 运行验证通过 → commit"五步执行。不得跳过失败验证步骤。
3. **每步即提交**：每个任务完成后立即 commit，commit message 遵守 Conventional Commits：`<type>(F2.1): <subject>`。type 限定为 `feat`/`fix`/`test`/`refactor`/`docs`/`chore`。
4. **SwiftLint strict**：任何包含 Swift 代码的 commit 前必须运行 `swiftlint lint --strict` 并通过。禁止用 `// swiftlint:disable` 绕过。
5. **Allman 大括号 + 4 空格缩进**：所有 Swift 代码必须遵守 `docs/CODING_STANDARDS.md` §4.1。类型/函数/初始化器/控制流的大括号起始行必须独占一行。
6. **LogCategory 日志白名单（D15）**：日志只能输出以下 9 个字段：`module`、`operation`、`phase`、`result`、`errorCode`、`retryCount`、`changeCount`、`contentLength`、`fileName`。禁止输出：剪贴板原文、文件完整路径（含用户名）、密码、Token、验证码、bundleId 与 appName 的明文组合。使用 `LogCategory.capture` / `.storage` / `.ui` / `.app`。
7. **不修改 F1.x 既有公共接口（F-11 例外）**：F1.x 既有模块的 `public`/`open` 接口不得修改。唯一例外是 F-11：扩展 `PasteboardWatcher.onPasteboardChange` 回调参数为 `CaptureEvent`（Phase 1 任务 1）。
8. **macOS 12.4 兼容性**：不得使用 macOS 13+ 专属 API（如 `NavigationStack`、`@Observable`）。SwiftUI 使用 `NavigationView` + `ObservableObject`。`DispatchQueue` 与 `FileManager` API 必须在 macOS 12.4 可用。
9. **不引入新外部依赖**：仅使用 Foundation/AppKit/SwiftUI/XCTest/XCUITest + 既有 SQLite.swift。不得新增 SPM 依赖。
10. **类型一致性**：后续任务中使用的类型、方法签名、属性名必须与前面任务中定义的完全一致。例如 `CaptureEvent.changeCount` 在所有任务中必须是 `Int` 类型，`AutoSaveService.handle(event:)` 在所有任务中必须是 `(CaptureEvent) -> Void`。

---

## 8. 最终验收方式

### 8.1 Phase 0 验收（核心保存逻辑）

- [x] 14 个任务全部 commit 完成，commit history 可查（2026-07-22 验证：36 个 F2.1 commit）
- [x] `swiftlint lint --strict` 通过（2026-07-22 验证：0 violations, 155 files）
- [x] `xcodebuild build` 通过（2026-07-22 验证：BUILD SUCCEEDED）
- [x] 49 条单元测试（TC-UT-01~49）全部通过（本地 `-only-testing` 逐文件验证：2026-07-22 验证 81 tests, 0 failures）
- [x] 14 条并发场景测试（TC-CC-01~14）全部通过（2026-07-22 验证：AutoSaveConcurrencyTests 通过）
- [x] 性能测试（D21）记录实际耗时并断言 P95（2026-07-22 验证：AutoSavePerformanceTests 通过）
- [x] AC-04、AC-06、AC-10、AC-11、AC-12、AC-13、AC-14、AC-17~22 的 XCTest 部分通过（2026-07-22 验证）

### 8.2 Phase 1 验收（集成与 UI）

- [x] 10 个任务全部 commit 完成（2026-07-22 验证）
- [x] `swiftlint lint --strict` 通过（2026-07-22 验证：0 violations, 155 files）
- [x] `xcodebuild build` 通过（2026-07-22 验证：BUILD SUCCEEDED）
- [x] F1.x 既有单元测试全部回归通过（2026-07-22 验证：PasteboardWatcher/ClipCaptureService/SensitiveDetector/EncryptedStore 共 32 tests, 0 failures）
- [ ] XCUITest（AC-07/09/15/16）由 CI 验证通过（本地不执行，待 CI 兜底）
- [ ] 手动验收脚本（AC-01/02/03/05/17~22）由开发者本机执行并记录结果（待手动执行）

### 8.3 整体验收（F2.1 功能完整交付）

- [ ] 22 条 AC（AC-01~22）全部覆盖：XCTest 覆盖业务逻辑部分，XCUITest 覆盖 UI 交互部分，手动测试覆盖 OS 边界部分（待 XCUITest + 手动测试完成后勾选）
- [ ] 11 条 NFR（NFR-01~11）全部满足：性能（NFR-01~05）、可靠性（NFR-06~08）、安全（NFR-09~10）、兼容性（NFR-11）（待手动测试完成后勾选）
- [x] 14 条约束（C-01~14）全部遵守（2026-07-22 Phase 1 代码评审确认）
- [x] F-11 例外条款是唯一对 F1.x 既有公共接口的修改（2026-07-22 Phase 1 代码评审确认：仅 PasteboardWatcher.onPasteboardChange 回调参数扩展）
- [x] 24 条决策（D1~D24）全部落地，可在代码中追溯（2026-07-22 Phase 1 代码评审确认：质量等级 A-）

---

## 9. 版本记录

| 版本 | 日期 | 变更 |
|------|------|------|
| v2.1 | 2026-07-22 | 同步 §8.1/§8.2/§8.3 验收清单勾选状态：本地已验证项勾选（commit history/swiftlint/build/单元测试/并发测试/性能测试/F1.x 回归），§8.3 代码评审确认项勾选（约束/F-11/24 决策），XCUITest 与手动 OS 边界测试项保留 [ ] 待 CI 与开发者执行 |
| v2.2 | 2026-07-22 | 配置面板长度阈值/文件名长度控件从 Stepper 改为 TextField（决策 C1~C6，详见 `historys/2026-07-22-配置面板长度阈值改为TextField.md`）。§4.2 Phase 1 新增文件表 AutoSaveSettingsView.swift 备注控件类型变更（Stepper → TextField + @FocusState 失焦逻辑）。新增 AutoSaveSettings.clampedInt 静态方法（决策 C2 夹紧 + C3 回退）。验证：SwiftLint 0 violations，xcodebuild build SUCCEEDED，ClipMindTests 449 tests 0 failures（含新增 8 个 clampedInt 测试 case），UI 测试环境问题已 stash 验证非本次改动回归 |
| v2.0 | 2026-07-22 | 基于 v1.1 设计文档套件完全重写：落地 24 条决策（D1~D24），新增 CaptureEvent/SensitiveMatchResult/F2xConfigSnapshot/SelfWriteSuppressor/FileWriter/ClipboardReplacer/PollingHelper 7 个模块，Phase 0 从 9 任务扩展为 14 任务，Phase 1 从 7 任务扩展为 10 任务，引入三层测试策略（D8）与日志白名单（D15） |
| v1.2 | 2026-07-21 | 基于 v1.0 设计的旧版计划（已被 v2.0 替换） |
| v1.1 | 2026-07-20 | 旧版初稿 |
| v1.0 | 2026-07-19 | 旧版初稿 |
