> 最后更新：2026-07-25 | 版本：v1.1

# F1.10 快捷键默认值修改 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法跟踪进度。本特性为单 Phase 一次性完成，所有任务严格按编号顺序执行，前一个任务的测试通过后才能开始下一个。

**目标：** 把 ClipMind 默认全局快捷键从冲突区的 `cmd+shift+v` 修改为 `cmd+shift+space`，扩展快捷键格式化工具对空格键的支持（解析、反向构造、显示），为已注册老用户执行无感迁移（仅迁移旧默认值，保留自定义值），并抽取测试常量集让后续再次修改默认值仅需调整一处。

**架构：** 在现有 `Models/AppSettings`、`UI/Settings/HotkeyRecorder`、`UI/Settings/GeneralSettingsView` 三个文件上做增量修改：`AppSettings` 新增 `defaultHotkey` / `legacyDefaultHotkey` 常量与 `migrateLegacyHotkey()` 方法成为默认值的唯一来源；`HotkeyFormatter` 键名映射表增加 `49 ↔ "space"` 与显示形式 `"Space"`；`HotkeyRecorder` 重置按钮与 `GeneralSettingsView` 的 `@AppStorage` 默认值改为引用 `AppSettings.defaultHotkey`；测试侧新增 `ClipMindTests/Hotkey/HotkeyTestConstants.swift` 集中管理 `default` / `legacyDefault` / `arbitrary` 三个常量。本特性不引入新模块、不修改快捷键配置 UI 交互、不改变 F1.9 触发行为（仍是呼出快速粘贴面板）。

**技术栈：** Swift 5.7 / macOS 13.0+ / SwiftUI + AppKit（@AppStorage / NSEvent）/ Carbon RegisterEventHotKey（全局快捷键，现有）/ XCTest + XCUITest / SQLite.swift（SPM，现有，本特性不涉及）

---

## 设计规范与评审

| 文档 | 路径 | 版本 |
|------|------|------|
| 需求文档 | `docs/planning/P0/F1/F1.10_快捷键默认值修改_需求文档.md` | v1.0 |
| 设计文档 | `docs/planning/P0/F1/F1.10_快捷键默认值修改_设计文档.md` | v1.1 |
| 视觉原型 | `docs/planning/P0/F1/F1.10_快捷键默认值修改_视觉原型.html` | v1.0 |
| 测试用例表 | `docs/planning/P0/F1/F1.10_快捷键默认值修改_测试用例表.md` | v1.0 |
| 需求文档审查结果 | `docs/planning/P0/F1/F1.10_快捷键默认值修改_需求文档_审查结果.md` | v1.0 |
| 设计文档审查结果 | `docs/planning/P0/F1/F1.10_快捷键默认值修改_设计文档_审查结果.md` | v1.0 |
| 视觉原型审查结果 | `docs/planning/P0/F1/F1.10_快捷键默认值修改_视觉原型_审查结果.md` | v1.0 |
| 测试用例表审查结果 | `docs/planning/P0/F1/F1.10_快捷键默认值修改_测试用例表_审查结果.md` | v1.0 |
| F1 主设计规范 | `docs/planning/P0/F1/F1_ClipMind_设计规范.md` | v1.10（待同步更新） |
| F1.9 测试用例表 | `docs/planning/P0/F1/F1.9_快捷粘贴面板_测试用例表.md` | v1.0（涉及默认快捷键字面值的位置需同步更新） |
| 编码规范 | `docs/CODING_STANDARDS.md` | — |
| XCTest 规则 | `docs/AI/trae-xctest-rules.md` | v3.1 |
| 文档同步规则 | `.trae/rules/docs.md` | — |
| 提交规范 | `.trae/rules/git-commit-message.md` | — |

**评审结论**：需求 / 设计 / 视觉原型 / 测试用例表 4 篇文档全部经 3 子代理审查通过，0 项必须修复，所有可选改进已在 v1.1 设计文档与测试用例表中落地。本计划基于审查通过的规格文档套件编写。

---

## Phase 列表

本特性按用户确认采用**单 Phase 一次性完成**。Phase 1 覆盖全部 10 条 AC（AC-F1.10-1 ~ AC-F1.10-10，含 1 条回归保护 AC），所有任务在一个 Phase 内严格按编号顺序串行执行。

| Phase | 标题 | 目标 | 涉及 AC | 任务数 | TDD 步骤数 | UI 证据任务数 | 合规风险 | 预计耗时 |
|-------|------|------|---------|--------|-----------|--------------|---------|---------|
| Phase 1 | 默认值修改与迁移 | 修改默认快捷键为 cmd+shift+space + 扩展格式化工具支持空格键 + 老用户无感迁移 + 测试常量集抽取 + 现有测试迁移 + XCUITest + 文档同步 | AC-F1.10-1 ~ AC-F1.10-10 全覆盖 | 13 | 32 | 2（XCUITest，不本地执行） | 零（仅修改默认值与扩展键名映射） | 2.5-3.5 小时 |

详见子计划：

- [phase-1-默认值修改与迁移.md](./phase-1-默认值修改与迁移.md)

---

## 涉及文件总览

### 新增生产代码文件（0 个）

本特性不新增任何生产代码文件，所有改动落在现有文件上。

### 修改的现有生产代码文件（4 个）

| 文件 | 职责变更 |
|------|---------|
| `ClipMind/Models/AppSettings.swift` | 新增 `static let defaultHotkey = "cmd+shift+space"` 与 `static let legacyDefaultHotkey = "cmd+shift+v"` 常量；`hotkey` 字段默认值从字面值 `"cmd+shift+v"` 改为引用 `AppSettings.defaultHotkey`；新增 `mutating func migrateLegacyHotkey()` 方法（仅当 `hotkey == legacyDefaultHotkey` 时迁移为 `defaultHotkey`，其他值不修改） |
| `ClipMind/UI/Settings/HotkeyRecorder.swift` | `HotkeyFormatter.keyName(for:)` 与 `keyCode(for:)` 增加 `49 ↔ "space"` 映射；`HotkeyFormatter.display(_:)` 处理 `"space"` token 返回 `"Space"`（首字母大写，与字母键显示风格一致）；`HotkeyRecorder.resetButton` 的 `hotkey = "cmd+shift+v"` 改为 `hotkey = AppSettings.defaultHotkey`；`hotkeyRecorder` 按钮添加 `.accessibilityLabel(HotkeyFormatter.display(hotkey))` 供 XCUITest 可靠断言（任务 11.0） |
| `ClipMind/UI/Settings/GeneralSettingsView.swift` | `@AppStorage("hotkey") private var hotkey = "cmd+shift+v"` 改为 `@AppStorage("hotkey") private var hotkey = AppSettings.defaultHotkey`；注释中"默认 cmd+shift+v"改为"默认 cmd+shift+space" |
| `ClipMind/App/ClipMindApp.swift` | `applyUITestOverrides()` 新增处理 `--UITEST_LEGACY_HOTKEY`（写入 `"cmd+shift+v"`）与 `--UITEST_CUSTOM_HOTKEY`（写入 `"ctrl+opt+a"`）启动参数，供 XCUITest 注入老用户旧默认值与自定义值（任务 11.0，测试基础设施） |

### 新增测试文件（5 个）

| 文件 | 覆盖 |
|------|------|
| `ClipMindTests/Hotkey/HotkeyTestConstants.swift` | 测试常量集（`default` / `legacyDefault` / `arbitrary`），FR-010 |
| `ClipMindTests/Hotkey/HotkeyFormatterSpaceKeyTests.swift` | TC-F1.10-1-01（解析新默认值）、TC-F1.10-2-01（显示新默认值） |
| `ClipMindTests/Hotkey/HotkeyFormatterRoundTripTests.swift` | TC-F1.10-3-01（反向构造新默认值）、TC-F1.10-3-02（往返测试）、TC-F1.10-10-01（旧默认值回归保护） |
| `ClipMindTests/Models/AppSettingsHotkeyMigrationTests.swift` | TC-F1.10-4-01（默认值断言）、TC-F1.10-5-01（老用户迁移）、TC-F1.10-6-01/02（自定义值与空值保留）、TC-F1.10-S-02（幂等性） |
| `ClipMindTests/UI/HotkeyRecorderResetTests.swift` | TC-F1.10-7-01（仅常量一致性，真实重置行为由 TC-F1.10-7-02 XCUITest 验证） |
| `ClipMindUITests/GeneralSettingsHotkeyDisplayUITests.swift` | TC-F1.10-9-01/02（设置页默认显示）、TC-F1.10-7-02（重置后显示更新） |

### 修改的现有测试文件（3 个）

| 文件 | 修改内容 |
|------|---------|
| `ClipMindTests/App/GlobalHotkeyServiceTests.swift` | `testParseStoredHotkey_CmdShiftV_ReturnsCorrectModifierAndKeyCode` 改用 `TestHotkeys.legacyDefault`（回归保护，保留）；`testGlobalHotkeyService_InitWithValidHotkey_RegistersWithCorrectParams` 改用 `TestHotkeys.default` 并断言 `keyCode == 49`；`testGlobalHotkeyService_Unregister_ClearsRegistration` / `testGlobalHotkeyService_RegistrarFails_IsNotRegistered` / `testGlobalHotkeyService_HotkeyPressed_PostsOpenQuickPasteNotification` 改用 `TestHotkeys.arbitrary`（hotkey 值非断言目标） |
| `ClipMindTests/App/GlobalHotkeyServiceQuickPasteTests.swift` | `testHotkeyPressed_PostsOpenQuickPasteNotification` / `testHotkeyPressed_DoesNotPostOpenMainWindowNotification` 改用 `TestHotkeys.arbitrary`（hotkey 值非断言目标） |
| `ClipMindTests/Models/ClipItemModelTests.swift` | 第 195 行 `XCTAssertEqual(settings.hotkey, "cmd+shift+v")` 改为 `XCTAssertEqual(settings.hotkey, TestHotkeys.default)` |

### 新增的 F1.10 专项测试文件（1 个，覆盖 AC-F1.10-8）

| 文件 | 覆盖 |
|------|------|
| `ClipMindTests/App/GlobalHotkeyServiceF1_10Tests.swift` | TC-F1.10-8-01（新默认值可注册）、TC-F1.10-8-02（按下新默认值触发"打开快速粘贴面板"通知） |

### 不修改的复用文件（仅读取/调用，不动）

| 文件 | 复用方式 |
|------|---------|
| `ClipMind/App/GlobalHotkeyService.swift` | 注册逻辑与触发逻辑完全不变；仅 hotkey 字面值从旧默认值变为新默认值（由调用方传入）；`HotkeyFormatter.parse(stored:)` 已扩展支持空格键 |
| `ClipMind/UI/QuickPaste/*` | F1.9 快速粘贴面板控制器、视图、协调器等不变 |
| `ClipMind/Utils/LogCategory.swift` | 复用 `LogCategory.app` / `LogCategory.ui` |

---

## 全局验证命令

每个任务完成后必须运行对应的最小验证命令；Phase 1 完成后必须运行完整回归命令。所有命令在 worktree 根目录执行：

```bash
# 工作目录（禁止切换到主仓库）
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.10-hotkey-default-change

# 1. SwiftLint strict（含 Swift 改动时强制运行，commit 前必过）
swiftlint lint --strict

# 2. 生成 Xcode 工程（修改 project.yml 后需要重新生成；本特性不修改 project.yml，但首次执行需要生成）
xcodegen generate

# 3. 单测试文件快速验证（本地可执行，按任务指定 -only-testing）
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindTests/<TestClass> \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -40

# 4. Phase 1 完成后完整回归（本地基线测试，与 CI 同一命令）
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -60

# 5. XCUITest 不本地执行，延迟到 CI（步骤 4.5b Smoke CI 或步骤 5.5 完整 CI）
# 仅在 commit 前执行 swiftlint + 完整 XCTest 回归即可
```

**说明**：

- XCUITest 涉及真实窗口与系统通知，本地 xcodebuild 环境不稳定，延迟到 CI 执行。本地只执行 XCTest 单元测试。
- 每个任务的"运行测试验证失败/通过"步骤会指定具体的 `-only-testing ClipMindTests/<TestClass>` 参数，避免全量测试浪费时间。
- Phase 1 完成后必须运行命令 4（完整 XCTest 回归）确保现有测试不破坏。

---

## 最终验收方式

Phase 1 全部任务完成后，按以下顺序验收：

1. **本地 XCTest 全量回归**：运行上述命令 4（`xcodebuild test -scheme ClipMind`），所有 XCTest 用例通过（含 F1.10 新增 + 现有迁移后的测试），无失败、无崩溃。
2. **本地 SwiftLint strict**：运行命令 1，无任何违规。
3. **本地编译检查**：运行命令 2 + 命令 3 的编译阶段，主 Scheme `ClipMind` 与测试 target 均编译通过。
4. **CI 触发**：Phase 合并到 develop 后，CI（`.github/workflows/ci.yml`）在 macOS 15 runner 上自动执行 SwiftLint strict → build → test（含 XCUITest），全部通过。
5. **手动验收（可选，发布前）**：
   - 真实环境按下 `Cmd+Shift+Space` 呼出快速粘贴面板（TC-F1.10-8-03）。
   - 老用户持久化 `cmd+shift+v` 后启动 App，验证自动迁移到 `cmd+shift+space`（TC-F1.10-5-01 真实环境验证）。
6. **代码审查（PR 阶段）**：
   - TC-F1.10-M-01：默认快捷键字面值在应用代码中仅出现一处（`AppSettings.defaultHotkey`）。
   - TC-F1.10-M-02：测试常量集位于 `ClipMindTests/Hotkey/`，生产代码不引用。
   - TC-F1.10-M-04：测试常量集包含 `default` / `legacyDefault` / `arbitrary` 三个常量。

**Phase 合并到 develop 的预期基线**：

- 全部 10 条 AC（AC-F1.10-1 ~ AC-F1.10-10）由测试覆盖（XCTest 8 处新增 + 1 处修改 + 1 处回归保护保留 + XCUITest 3 处新增延迟到 CI）。XCUITest 所需启动参数（`--UITEST_LEGACY_HOTKEY`、`--UITEST_CUSTOM_HOTKEY`）已在任务 11.0 实现，CI 无阻塞风险。
- 全部 11 条 FR（FR-001 ~ FR-011）由代码实现 + 测试验证。
- 全部 6 条 NFR（NFR-001 ~ NFR-006）落地（性能/稳定性/安全性由现有架构保证 + 可维护性由代码审查验证 + 合规性由"零合规风险"结论保证）。
- 主 Scheme `ClipMind` 仍完全合规（无新增 entitlement、无私有 API、App Sandbox 启用）。
- 现有测试（6 个迁移到测试常量集）全部通过，无回归破坏。
- 文档同步：F1 主设计规范、F1.9 测试用例表中涉及默认快捷键字面值的位置已同步更新；`docs/planning/P0/F1/historys/` 追加变更记录。

---

## 版本记录

| 版本 | 日期 | 变更说明 |
|------|------|---------|
| v1.0 | 2026-07-25 | 初始版本，单 Phase 实现计划，覆盖 F1.10 快捷键默认值修改全部 10 条 AC，13 个任务，32 个 TDD 步骤，2 个 UI 证据任务（XCUITest 延迟到 CI），零合规风险 |
| v1.1 | 2026-07-25 | 同步 phase-1 v1.1 修复：ClipMindApp.swift 纳入修改文件列表（任务 11.0 处理 `--UITEST_LEGACY_HOTKEY` / `--UITEST_CUSTOM_HOTKEY` 启动参数）；HotkeyRecorder.swift 新增 accessibilityLabel；HotkeyRecorderResetTests 降级为常量一致性检查；XCUITest 启动参数已实现，CI 无阻塞风险 |
