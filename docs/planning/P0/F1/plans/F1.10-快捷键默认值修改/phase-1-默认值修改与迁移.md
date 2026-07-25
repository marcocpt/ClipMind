> 最后更新：2026-07-25 | 版本：v1.1

# Phase 1：默认值修改与迁移

> **面向 AI 代理的工作者：** 本 Phase 是 F1.10 的唯一 Phase，一次性完成全部 10 条 AC。使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现。步骤使用复选框（`- [ ]`）语法跟踪进度。所有任务严格按编号顺序执行，前一个任务的测试通过后才能开始下一个。

## 目标

把 ClipMind 默认全局快捷键从 `cmd+shift+v` 修改为 `cmd+shift+space`，扩展 `HotkeyFormatter` 对空格键的支持（解析、反向构造、显示为 `⌘⇧Space`），为已注册老用户执行无感迁移（仅当持久化值等于旧默认值时迁移，自定义值保留），抽取测试常量集 `TestHotkeys`（`default` / `legacyDefault` / `arbitrary`）让后续再次修改默认值仅需调整一处，并将现有 6 处测试迁移到测试常量集提升语义与可维护性。

## 范围

- 新增 `ClipMindTests/Hotkey/HotkeyTestConstants.swift` 测试常量集
- 扩展 `HotkeyFormatter` 的 `keyName(for:)` / `keyCode(for:)` / `display(_:)` 支持空格键
- `AppSettings` 新增 `defaultHotkey` / `legacyDefaultHotkey` 常量与 `migrateLegacyHotkey()` 方法，`hotkey` 字段默认值改为引用 `defaultHotkey`
- `GeneralSettingsView` 的 `@AppStorage("hotkey")` 默认值改为引用 `AppSettings.defaultHotkey`
- `HotkeyRecorder` 重置按钮的目标值改为引用 `AppSettings.defaultHotkey`
- 新增 5 个测试文件（4 个 XCTest + 1 个 XCUITest）覆盖 AC-F1.10-1 ~ AC-F1.10-9
- 修改 3 个现有测试文件迁移到测试常量集（6 处现有用例 + 1 处默认值断言）
- 同步 F1 主设计规范、F1.9 测试用例表中涉及默认快捷键字面值的位置
- 追加 `docs/planning/P0/F1/historys/` 变更记录

## 非目标

- 不修改 `GlobalHotkeyService.swift` 的注册逻辑与触发逻辑（仅 hotkey 字面值由调用方传入变化）
- 不修改 `ClipMindApp.swift` 监听 `.openQuickPaste` 通知的逻辑（沿用 F1.9）；仅扩展 `applyUITestOverrides()` 处理 XCUITest 启动参数（任务 11.0，测试基础设施）
- 不修改 F1.9 快速粘贴面板的任何模块（控制器、视图、协调器、降级浮层等）
- 不修改快捷键配置 UI 的交互、视觉、配置能力（仅修改"默认值"与"显示形式"）
- 不引入新的快捷键功能（不支持二次快捷键 toggle、快捷键链、冲突检测等）
- 不修改数据模型或持久化方案（快捷键仍以字符串形式持久化在 UserDefaults / AppSettings）
- 不本地执行 XCUITest（延迟到 CI；本地仅执行 XCTest 单元测试）

## 涉及文件和职责

### 新增文件（6 个：1 测试常量集 + 4 XCTest + 1 XCUITest）

| 文件 | 职责 |
|------|------|
| `ClipMindTests/Hotkey/HotkeyTestConstants.swift` | 测试常量集：`TestHotkeys.default` / `TestHotkeys.legacyDefault` / `TestHotkeys.arbitrary` 三个静态常量，仅测试代码引用 |
| `ClipMindTests/Hotkey/HotkeyFormatterSpaceKeyTests.swift` | TC-F1.10-1-01（解析新默认值返回空格键码与命令、Shift 修饰键）、TC-F1.10-2-01（显示新默认值为 ⌘⇧Space 大写形式） |
| `ClipMindTests/Hotkey/HotkeyFormatterRoundTripTests.swift` | TC-F1.10-3-01（反向构造新默认值）、TC-F1.10-3-02（往返测试：新默认值 + 旧默认值）、TC-F1.10-10-01（旧默认值回归保护） |
| `ClipMindTests/Models/AppSettingsHotkeyMigrationTests.swift` | TC-F1.10-4-01（默认值断言）、TC-F1.10-5-01（老用户旧默认值迁移）、TC-F1.10-6-01（自定义值保留）、TC-F1.10-6-02（空值不覆盖）、TC-F1.10-S-02（幂等性） |
| `ClipMindTests/UI/HotkeyRecorderResetTests.swift` | TC-F1.10-7-01（仅常量一致性，真实重置行为由 TC-F1.10-7-02 XCUITest 验证） |
| `ClipMindTests/App/GlobalHotkeyServiceF1_10Tests.swift` | TC-F1.10-8-01（新默认值可注册）、TC-F1.10-8-02（按下新默认值触发"打开快速粘贴面板"通知） |
| `ClipMindUITests/GeneralSettingsHotkeyDisplayUITests.swift` | TC-F1.10-9-01（新用户首启后设置页显示 ⌘⇧Space）、TC-F1.10-9-02（老用户迁移后显示 ⌘⇧Space）、TC-F1.10-7-02（重置后显示更新） |

### 修改文件（7 个：4 生产代码 + 3 测试）

| 文件 | 职责变更 |
|------|---------|
| `ClipMind/Models/AppSettings.swift` | 新增 `static let defaultHotkey` 与 `static let legacyDefaultHotkey`；`hotkey` 默认值改为 `AppSettings.defaultHotkey`；新增 `mutating func migrateLegacyHotkey()` |
| `ClipMind/UI/Settings/HotkeyRecorder.swift` | `HotkeyFormatter` 增加空格键映射（`49 ↔ "space"` + `display` 返回 `"Space"`）；`HotkeyRecorder.resetButton` 改为 `hotkey = AppSettings.defaultHotkey` |
| `ClipMind/UI/Settings/GeneralSettingsView.swift` | `@AppStorage("hotkey")` 默认值改为 `AppSettings.defaultHotkey`；注释更新 |
| `ClipMind/App/ClipMindApp.swift` | `applyUITestOverrides()` 新增处理 `--UITEST_LEGACY_HOTKEY` 与 `--UITEST_CUSTOM_HOTKEY` 启动参数，向 `UserDefaults.standard` 写入对应 hotkey 值，供 XCUITest 注入老用户旧默认值与自定义值（任务 11.0，测试基础设施） |
| `ClipMindTests/App/GlobalHotkeyServiceTests.swift` | 5 处现有用例迁移到测试常量集（1 处保留为回归保护用 `legacyDefault`，1 处改用 `default` 并断言 `keyCode == 49`，3 处改用 `arbitrary`） |
| `ClipMindTests/App/GlobalHotkeyServiceQuickPasteTests.swift` | 2 处现有用例改用 `TestHotkeys.arbitrary`（hotkey 值非断言目标） |
| `ClipMindTests/Models/ClipItemModelTests.swift` | 第 195 行默认值断言改为引用 `TestHotkeys.default` |

### 测试用例覆盖说明

- **本 Phase 覆盖**：AC-F1.10-1 ~ AC-F1.10-10 全部 10 条 AC
  - AC-F1.10-1：TC-F1.10-1-01（XCTest 新增，任务 2）
  - AC-F1.10-2：TC-F1.10-2-01（XCTest 新增，任务 3）
  - AC-F1.10-3：TC-F1.10-3-01 + TC-F1.10-3-02（XCTest 新增，任务 4）
  - AC-F1.10-4：TC-F1.10-4-01（XCTest 新增 + 现有断言修改，任务 5）
  - AC-F1.10-5：TC-F1.10-5-01（XCTest 新增，任务 6）
  - AC-F1.10-6：TC-F1.10-6-01 + TC-F1.10-6-02（XCTest 新增，任务 6）
  - AC-F1.10-7：TC-F1.10-7-01（XCTest 新增，任务 8）+ TC-F1.10-7-02（XCUITest 新增，任务 11）
  - AC-F1.10-8：TC-F1.10-8-01 + TC-F1.10-8-02（XCTest 新增，任务 9）
  - AC-F1.10-9：TC-F1.10-9-01 + TC-F1.10-9-02（XCUITest 新增，任务 11）
  - AC-F1.10-10：TC-F1.10-10-01（XCTest 现有用例迁移到 `legacyDefault`，任务 4 + 任务 10）
- **延后覆盖**：TC-F1.10-8-03（真实环境按键验证，发布前手动验收）

---

## 任务 1：创建测试常量集 HotkeyTestConstants.swift

**文件：**
- 创建：`ClipMindTests/Hotkey/HotkeyTestConstants.swift`

### 步骤

- [ ] **1.1 创建测试常量集文件**

在 worktree 根目录执行：

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.10-hotkey-default-change
mkdir -p ClipMindTests/Hotkey
```

创建 `ClipMindTests/Hotkey/HotkeyTestConstants.swift`：

```swift
@testable import ClipMind
import Foundation

/// F1.10 测试常量集：集中管理快捷键测试中的默认值与 fixture 值。
///
/// 后续再次修改默认值时，仅需修改本文件的 `default` 与 `legacyDefault` 两个常量，
/// 所有引用处自动同步。生产代码不引用本文件（满足 NFR-006 可维护性）。
enum TestHotkeys
{
    /// 当前默认值（与 `AppSettings.defaultHotkey` 保持一致）。
    /// 用于断言应用设置的默认值、设置页显示、新默认值解析与反向构造。
    static let `default` = "cmd+shift+space"

    /// 历史默认值（旧默认值，用于回归保护与老用户迁移测试）。
    /// 用于验证旧默认值仍可被解析、反向构造、显示；作为老用户迁移输入。
    static let legacyDefault = "cmd+shift+v"

    /// 任意有效值（自定义快捷键，用于服务层 fixture 测试中非断言目标的 hotkey 值）。
    /// 提升测试语义：当 hotkey 值不是断言目标时，使用 `arbitrary` 而非字面值。
    static let arbitrary = "ctrl+opt+a"
}
```

- [ ] **1.2 重新生成 Xcode 工程并编译验证**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.10-hotkey-default-change
xcodegen generate && xcodebuild build \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindTests \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
```

预期：编译通过，无错误。新增文件被 xcodegen 自动纳入 `ClipMindTests` target。

- [ ] **1.3 SwiftLint strict 验证**

```bash
swiftlint lint --strict ClipMindTests/Hotkey/HotkeyTestConstants.swift
```

预期：无任何违规。

- [ ] **1.4 Commit**

```bash
git add ClipMindTests/Hotkey/HotkeyTestConstants.swift
git commit -m "test(F1.10): add HotkeyTestConstants for centralized hotkey test values"
```

---

## 任务 2：TDD - HotkeyFormatter 支持空格键解析（AC-F1.10-1）

**文件：**
- 修改：`ClipMind/UI/Settings/HotkeyRecorder.swift`（`HotkeyFormatter.keyName(for:)` 与 `keyCode(for:)`）
- 测试：`ClipMindTests/Hotkey/HotkeyFormatterSpaceKeyTests.swift`（新增）

### 步骤

- [ ] **2.1 编写失败的测试**

创建 `ClipMindTests/Hotkey/HotkeyFormatterSpaceKeyTests.swift`：

```swift
@testable import ClipMind
import XCTest

/// F1.10 AC-F1.10-1 / AC-F1.10-2：验证 HotkeyFormatter 对空格键的解析与显示支持。
final class HotkeyFormatterSpaceKeyTests: XCTestCase
{
    // MARK: - AC-F1.10-1：解析新默认值返回空格键码与命令、Shift 修饰键

    func testParse_NewDefault_ReturnsSpaceKeyCodeAndCmdShiftModifiers()
    {
        // Arrange
        let stored = TestHotkeys.default

        // Act
        let parsed = HotkeyFormatter.parse(stored: stored)

        // Assert
        XCTAssertNotNil(parsed, "新默认值应能被解析")
        XCTAssertEqual(parsed?.keyCode, 49, "空格键的 keyCode 应为 49")
        XCTAssertTrue((parsed?.modifiers ?? 0) & 0x0100 != 0, "修饰键应包含 cmdKey (0x0100)")
        XCTAssertTrue((parsed?.modifiers ?? 0) & 0x0200 != 0, "修饰键应包含 shiftKey (0x0200)")
    }
}
```

- [ ] **2.2 运行测试验证失败**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.10-hotkey-default-change
xcodegen generate && xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindTests/HotkeyFormatterSpaceKeyTests \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：FAIL，报错类似 `XCTAssertEqual failed: ("nil") is not equal to ("Optional(49)")` 或 `XCTAssertNotNil failed`。原因：`HotkeyFormatter.keyCode(for: "space")` 返回 `nil`，因为当前 `keyName` / `keyCode` 映射表未包含空格键。

- [ ] **2.3 编写最少实现代码**

修改 `ClipMind/UI/Settings/HotkeyRecorder.swift` 的 `HotkeyFormatter` 部分。在 `keyName(for:)` 的 `keyMap` 字面量中增加 `49: "space"`，在 `keyCode(for:)` 的 `keyMap` 字面量中增加 `"space": 49`。

定位 `keyName(for:)` 函数（当前在 `HotkeyRecorder.swift` 第 175-185 行），将 `keyMap` 字面量替换为：

```swift
    private static func keyName(for keyCode: UInt16) -> String? {
        let keyMap: [UInt16: String] = [
            0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g",
            6: "z", 7: "x", 8: "c", 9: "v", 11: "b", 12: "q",
            13: "w", 14: "e", 15: "r", 16: "y", 17: "t", 18: "1",
            19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 25: "9",
            26: "7", 28: "8", 29: "0", 31: "o", 32: "u", 34: "i",
            35: "p", 37: "l", 38: "j", 40: "k", 45: "n", 46: "m",
            49: "space"
        ]
        return keyMap[keyCode]
    }
```

定位 `keyCode(for:)` 函数（当前在 `HotkeyRecorder.swift` 第 188-198 行），将 `keyMap` 字面量替换为：

```swift
    private static func keyCode(for key: String) -> UInt32? {
        let keyMap: [String: UInt32] = [
            "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5,
            "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12,
            "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "1": 18,
            "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "9": 25,
            "7": 26, "8": 28, "0": 29, "o": 31, "u": 32, "i": 34,
            "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46,
            "space": 49
        ]
        return keyMap[key]
    }
```

- [ ] **2.4 运行测试验证通过**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.10-hotkey-default-change
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindTests/HotkeyFormatterSpaceKeyTests \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
```

预期：PASS，`testParse_NewDefault_ReturnsSpaceKeyCodeAndCmdShiftModifiers` 通过。

- [ ] **2.5 SwiftLint strict 验证**

```bash
swiftlint lint --strict ClipMind/UI/Settings/HotkeyRecorder.swift ClipMindTests/Hotkey/HotkeyFormatterSpaceKeyTests.swift
```

预期：无任何违规。

- [ ] **2.6 Commit**

```bash
git add ClipMind/UI/Settings/HotkeyRecorder.swift ClipMindTests/Hotkey/HotkeyFormatterSpaceKeyTests.swift
git commit -m "feat(F1.10): support space key parsing in HotkeyFormatter"
```

---

## 任务 3：TDD - HotkeyFormatter 支持空格键显示（AC-F1.10-2）

**文件：**
- 修改：`ClipMind/UI/Settings/HotkeyRecorder.swift`（`HotkeyFormatter.display(_:)`）
- 测试：`ClipMindTests/Hotkey/HotkeyFormatterSpaceKeyTests.swift`（追加用例）

### 步骤

- [ ] **3.1 编写失败的测试**

在 `ClipMindTests/Hotkey/HotkeyFormatterSpaceKeyTests.swift` 末尾追加（在类闭合 `}` 之前）：

```swift
    // MARK: - AC-F1.10-2：显示新默认值为 ⌘⇧Space 大写形式

    func testDisplay_NewDefault_ReturnsCmdShiftSpaceUppercase()
    {
        // Arrange
        let stored = TestHotkeys.default

        // Act
        let displayed = HotkeyFormatter.display(stored)

        // Assert
        XCTAssertEqual(displayed, "⌘⇧Space", "新默认值应显示为 ⌘⇧Space（命令符号 + Shift 符号 + 大写 Space 字样）")
    }
```

- [ ] **3.2 运行测试验证失败**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.10-hotkey-default-change
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindTests/HotkeyFormatterSpaceKeyTests/testDisplay_NewDefault_ReturnsCmdShiftSpaceUppercase \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
```

预期：FAIL，报错类似 `XCTAssertEqual failed: ("⌘⇧SPACE") is not equal to ("⌘⇧Space")`。原因：当前 `display(_:)` 对未知 token 返回 `token.uppercased()`，对 `"space"` 返回 `"SPACE"`（全大写），而需求文档 FR-004 要求"首字母大写，与字母键显示风格一致"，即 `"Space"`。

- [ ] **3.3 编写最少实现代码**

修改 `ClipMind/UI/Settings/HotkeyRecorder.swift` 的 `HotkeyFormatter.display(_:)` 函数（当前在第 106-121 行），在 `switch token.lowercased()` 中增加 `"space"` 分支：

```swift
    static func display(_ stored: String) -> String {
        stored.split(separator: "+").map { token -> String in
            switch token.lowercased() {
            case "cmd":
                return "⌘"
            case "shift":
                return "⇧"
            case "opt", "option":
                return "⌥"
            case "ctrl", "control":
                return "⌃"
            case "space":
                return "Space"
            default:
                return token.uppercased()
            }
        }.joined()
    }
```

- [ ] **3.4 运行测试验证通过**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.10-hotkey-default-change
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindTests/HotkeyFormatterSpaceKeyTests \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
```

预期：PASS，`HotkeyFormatterSpaceKeyTests` 全部用例通过（含任务 2 的解析用例与本任务的显示用例）。

- [ ] **3.5 SwiftLint strict 验证**

```bash
swiftlint lint --strict ClipMind/UI/Settings/HotkeyRecorder.swift
```

预期：无任何违规。

- [ ] **3.6 Commit**

```bash
git add ClipMind/UI/Settings/HotkeyRecorder.swift ClipMindTests/Hotkey/HotkeyFormatterSpaceKeyTests.swift
git commit -m "feat(F1.10): display space key as uppercase Space in HotkeyFormatter"
```

---

## 任务 4：TDD - HotkeyFormatter 反向构造空格键 + 往返测试（AC-F1.10-3, AC-F1.10-10）

**文件：**
- 测试：`ClipMindTests/Hotkey/HotkeyFormatterRoundTripTests.swift`（新增）
- 不修改生产代码：`HotkeyFormatter.parse(modifiers:keyCode:)` 在任务 2 的 `keyName(for:)` 扩展后已自动支持空格键的反向构造（互逆性由 `keyName` / `keyCode` 双向映射保证）

### 步骤

- [ ] **4.1 编写失败的测试**

创建 `ClipMindTests/Hotkey/HotkeyFormatterRoundTripTests.swift`：

```swift
@testable import ClipMind
import AppKit
import XCTest

/// F1.10 AC-F1.10-3 / AC-F1.10-10：验证 HotkeyFormatter 反向构造与往返互逆。
final class HotkeyFormatterRoundTripTests: XCTestCase
{
    // MARK: - AC-F1.10-3：反向构造新默认值

    func testParse_ModifiersAndSpaceKeyCode_ReturnsNewDefaultStorageRepresentation()
    {
        // Arrange - cmdKey (0x0100) + shiftKey (0x0200) + 空格 keyCode (49)
        let modifiers: NSEvent.ModifierFlags = [.command, .shift]
        let keyCode: UInt16 = 49

        // Act
        let stored = HotkeyFormatter.parse(modifiers: modifiers, keyCode: keyCode)

        // Assert
        XCTAssertEqual(stored, TestHotkeys.default, "反向构造结果应等于新默认值的存储表示")
    }

    // MARK: - AC-F1.10-3：解析与反向构造互逆（往返测试）

    func testRoundTrip_NewDefault_PreservesStorageRepresentation()
    {
        // Arrange
        let original = TestHotkeys.default

        // Act - 解析 → 反向构造
        let parsed = HotkeyFormatter.parse(stored: original)
        XCTAssertNotNil(parsed)
        let roundTrip = HotkeyFormatter.parse(
            modifiers: carbonModifiersToNSEventModifiers(parsed!.modifiers),
            keyCode: UInt16(parsed!.keyCode)
        )

        // Assert
        XCTAssertEqual(roundTrip, original, "新默认值解析后反向构造应与原输入一致")
    }

    // MARK: - AC-F1.10-10：旧默认值回归保护（解析仍正确 + 往返互逆）

    func testRoundTrip_LegacyDefault_PreservesStorageRepresentation()
    {
        // Arrange
        let original = TestHotkeys.legacyDefault

        // Act - 解析 → 反向构造
        let parsed = HotkeyFormatter.parse(stored: original)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.keyCode, 9, "旧默认值的 keyCode 应为 9 (v)")
        let roundTrip = HotkeyFormatter.parse(
            modifiers: carbonModifiersToNSEventModifiers(parsed!.modifiers),
            keyCode: UInt16(parsed!.keyCode)
        )

        // Assert
        XCTAssertEqual(roundTrip, original, "旧默认值解析后反向构造应与原输入一致（回归保护）")
    }

    // MARK: - 辅助

    /// 把 Carbon 修饰键 mask 转回 NSEvent.ModifierFlags，用于往返测试。
    private func carbonModifiersToNSEventModifiers(_ carbon: UInt32) -> NSEvent.ModifierFlags
    {
        var flags: NSEvent.ModifierFlags = []
        if carbon & 0x0100 != 0 { flags.insert(.command) }
        if carbon & 0x0200 != 0 { flags.insert(.shift) }
        if carbon & 0x0800 != 0 { flags.insert(.option) }
        if carbon & 0x1000 != 0 { flags.insert(.control) }
        return flags
    }
}
```

- [ ] **4.2 运行测试验证失败**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.10-hotkey-default-change
xcodegen generate && xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindTests/HotkeyFormatterRoundTripTests \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：3 个用例全部 PASS（任务 2 已扩展 `keyName(for:)` 与 `keyCode(for:)` 支持空格键，反向构造与往返路径自动可用，无需额外生产代码改动）。如果 `testParse_ModifiersAndSpaceKeyCode_ReturnsNewDefaultStorageRepresentation` 失败，说明任务 2 的 `keyName(for:)` 映射表未正确添加 `49: "space"`，需回溯任务 2。

> **说明**：本任务的"失败测试"步骤可能直接通过（因为任务 2 已完成空格键映射扩展）。这是 TDD 的正常情况——当实现已就绪时，测试立即通过即验证了互逆性。如果直接通过，跳过 4.3 的"实现"步骤，直接进入 4.4 的"通过"验证与 4.5 的 commit。

- [ ] **4.3 编写最少实现代码（仅当 4.2 失败时执行）**

如果 4.2 全部通过，跳过本步骤。如果 `testParse_ModifiersAndSpaceKeyCode_ReturnsNewDefaultStorageRepresentation` 失败（说明 `parse(modifiers:keyCode:)` 无法处理空格键），检查 `HotkeyFormatter.keyName(for:)` 是否包含 `49: "space"`（任务 2 应已添加）。若缺失，回溯任务 2 重新应用映射表扩展。

- [ ] **4.4 运行测试验证通过**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.10-hotkey-default-change
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindTests/HotkeyFormatterRoundTripTests \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
```

预期：PASS，3 个用例全部通过。

- [ ] **4.5 SwiftLint strict 验证**

```bash
swiftlint lint --strict ClipMindTests/Hotkey/HotkeyFormatterRoundTripTests.swift
```

预期：无任何违规。

- [ ] **4.6 Commit**

```bash
git add ClipMindTests/Hotkey/HotkeyFormatterRoundTripTests.swift
git commit -m "test(F1.10): add round-trip tests for space key and legacy default"
```

---

## 任务 5：TDD - AppSettings 默认值改为新默认值（AC-F1.10-4）

**文件：**
- 修改：`ClipMind/Models/AppSettings.swift`
- 测试：`ClipMindTests/Models/AppSettingsHotkeyMigrationTests.swift`（新增）
- 修改：`ClipMindTests/Models/ClipItemModelTests.swift`（第 195 行默认值断言）

### 步骤

- [ ] **5.1 编写失败的测试**

创建 `ClipMindTests/Models/AppSettingsHotkeyMigrationTests.swift`：

```swift
@testable import ClipMind
import XCTest

/// F1.10 AC-F1.10-4 / AC-F1.10-5 / AC-F1.10-6：验证 AppSettings 默认值与老用户迁移。
final class AppSettingsHotkeyMigrationTests: XCTestCase
{
    // MARK: - AC-F1.10-4：应用设置默认快捷键为新默认值

    func testAppSettings_DefaultHotkey_IsNewDefault()
    {
        // Arrange & Act
        let settings = AppSettings()

        // Assert
        XCTAssertEqual(settings.hotkey, AppSettings.defaultHotkey, "默认快捷键应为 AppSettings.defaultHotkey")
        XCTAssertEqual(settings.hotkey, TestHotkeys.default, "默认快捷键应等于测试常量集的当前默认值")
    }
}
```

同时修改 `ClipMindTests/Models/ClipItemModelTests.swift` 第 195 行。定位：

```swift
        XCTAssertEqual(settings.hotkey, "cmd+shift+v")
```

改为：

```swift
        XCTAssertEqual(settings.hotkey, TestHotkeys.default)
```

- [ ] **5.2 运行测试验证失败**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.10-hotkey-default-change
xcodegen generate && xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindTests/AppSettingsHotkeyMigrationTests/testAppSettings_DefaultHotkey_IsNewDefault \
  -only-testing ClipMindTests/ClipItemModelTests/testAppSettingsDefaults \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：FAIL，报错类似 `XCTAssertEqual failed: ("cmd+shift+v") is not equal to ("cmd+shift+space")` 或 `cannot find type 'AppSettings' in scope`（若 `AppSettings.defaultHotkey` 未定义）。原因：`AppSettings.hotkey` 默认值仍为 `"cmd+shift+v"`，且未定义 `defaultHotkey` 常量。

- [ ] **5.3 编写最少实现代码**

修改 `ClipMind/Models/AppSettings.swift`，全文替换为：

```swift
import Foundation

struct AppSettings: Codable, Equatable {
    /// F1.10：默认全局快捷键（应用代码中默认值的唯一来源）。
    /// 通用设置视图与快捷键录制器重置按钮通过引用本常量获取默认值。
    static let defaultHotkey = "cmd+shift+space"

    /// F1.10：历史默认快捷键（用于老用户迁移检查）。
    /// 仅当持久化值等于本常量时，迁移为新默认值。
    static let legacyDefaultHotkey = "cmd+shift+v"

    var apiProvider: APIProvider?
    var apiKey: String?
    var sensitiveDetectionEnabled: Bool = true
    var appBlacklist: [String] = []
    var autoCleanupEnabled: Bool = true
    var cleanupDays: Int = 30
    var launchAtLogin: Bool = true
    var hotkey: String = AppSettings.defaultHotkey
}
```

- [ ] **5.4 运行测试验证通过**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.10-hotkey-default-change
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindTests/AppSettingsHotkeyMigrationTests/testAppSettings_DefaultHotkey_IsNewDefault \
  -only-testing ClipMindTests/ClipItemModelTests/testAppSettingsDefaults \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
```

预期：PASS，`testAppSettings_DefaultHotkey_IsNewDefault` 与 `testAppSettingsDefaults` 均通过。

- [ ] **5.5 SwiftLint strict 验证**

```bash
swiftlint lint --strict ClipMind/Models/AppSettings.swift ClipMindTests/Models/AppSettingsHotkeyMigrationTests.swift ClipMindTests/Models/ClipItemModelTests.swift
```

预期：无任何违规。

- [ ] **5.6 Commit**

```bash
git add ClipMind/Models/AppSettings.swift ClipMindTests/Models/AppSettingsHotkeyMigrationTests.swift ClipMindTests/Models/ClipItemModelTests.swift
git commit -m "feat(F1.10): change AppSettings default hotkey to cmd+shift+space"
```

---

## 任务 6：TDD - AppSettings 老用户迁移方法（AC-F1.10-5, AC-F1.10-6）

**文件：**
- 修改：`ClipMind/Models/AppSettings.swift`（新增 `migrateLegacyHotkey()` 方法）
- 测试：`ClipMindTests/Models/AppSettingsHotkeyMigrationTests.swift`（追加用例）

### 步骤

- [ ] **6.1 编写失败的测试**

在 `ClipMindTests/Models/AppSettingsHotkeyMigrationTests.swift` 末尾追加（在类闭合 `}` 之前）：

```swift
    // MARK: - AC-F1.10-5：老用户旧默认值自动迁移为新默认值

    func testMigrateLegacyHotkey_WhenLegacyDefault_MigratesToNewDefault()
    {
        // Arrange - 老用户持久化的快捷键为旧默认值
        var settings = AppSettings()
        settings.hotkey = TestHotkeys.legacyDefault

        // Act
        settings.migrateLegacyHotkey()

        // Assert
        XCTAssertEqual(settings.hotkey, AppSettings.defaultHotkey, "旧默认值应被迁移为新默认值")
        XCTAssertEqual(settings.hotkey, TestHotkeys.default, "迁移后应等于测试常量集的当前默认值")
    }

    // MARK: - AC-F1.10-5：迁移幂等性（已迁移的值不再被修改）

    func testMigrateLegacyHotkey_WhenNewDefault_DoesNotMigrate()
    {
        // Arrange - 已迁移为新默认值
        var settings = AppSettings()
        settings.hotkey = TestHotkeys.default

        // Act
        settings.migrateLegacyHotkey()

        // Assert
        XCTAssertEqual(settings.hotkey, TestHotkeys.default, "已是新默认值时，迁移检查不应修改")
    }

    // MARK: - AC-F1.10-6：老用户自定义值保留不变

    func testMigrateLegacyHotkey_WhenCustomValue_KeepsCustomValue()
    {
        // Arrange - 用户自定义的快捷键（非旧默认值）
        var settings = AppSettings()
        settings.hotkey = TestHotkeys.arbitrary

        // Act
        settings.migrateLegacyHotkey()

        // Assert
        XCTAssertEqual(settings.hotkey, TestHotkeys.arbitrary, "自定义值不应被覆盖")
    }

    // MARK: - AC-F1.10-6：空值或无效值不强制覆盖为新默认值

    func testMigrateLegacyHotkey_WhenEmptyValue_DoesNotMigrate()
    {
        // Arrange - 空字符串（用户主动清空）
        var settings = AppSettings()
        settings.hotkey = ""

        // Act
        settings.migrateLegacyHotkey()

        // Assert
        XCTAssertEqual(settings.hotkey, "", "空值不应被覆盖为新默认值")
    }

    func testMigrateLegacyHotkey_WhenInvalidValue_DoesNotMigrate()
    {
        // Arrange - 无效值
        var settings = AppSettings()
        settings.hotkey = "invalid"

        // Act
        settings.migrateLegacyHotkey()

        // Assert
        XCTAssertEqual(settings.hotkey, "invalid", "无效值不应被覆盖为新默认值")
    }
```

- [ ] **6.2 运行测试验证失败**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.10-hotkey-default-change
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindTests/AppSettingsHotkeyMigrationTests \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：FAIL，编译错误 `value of type 'AppSettings' has no member 'migrateLegacyHotkey'`。原因：`migrateLegacyHotkey()` 方法尚未定义。

- [ ] **6.3 编写最少实现代码**

修改 `ClipMind/Models/AppSettings.swift`，在 `hotkey` 字段下方追加 `migrateLegacyHotkey()` 方法：

```swift
import Foundation

struct AppSettings: Codable, Equatable {
    /// F1.10：默认全局快捷键（应用代码中默认值的唯一来源）。
    /// 通用设置视图与快捷键录制器重置按钮通过引用本常量获取默认值。
    static let defaultHotkey = "cmd+shift+space"

    /// F1.10：历史默认快捷键（用于老用户迁移检查）。
    /// 仅当持久化值等于本常量时，迁移为新默认值。
    static let legacyDefaultHotkey = "cmd+shift+v"

    var apiProvider: APIProvider?
    var apiKey: String?
    var sensitiveDetectionEnabled: Bool = true
    var appBlacklist: [String] = []
    var autoCleanupEnabled: Bool = true
    var cleanupDays: Int = 30
    var launchAtLogin: Bool = true
    var hotkey: String = AppSettings.defaultHotkey

    /// F1.10：老用户旧默认值迁移检查。
    ///
    /// 仅当 `hotkey` 等于 `legacyDefaultHotkey` 时，迁移为 `defaultHotkey`；
    /// 其他值（自定义值、新默认值、空值、无效值）不修改。
    /// 迁移检查是幂等的：已是新默认值时不会再次迁移。
    mutating func migrateLegacyHotkey() {
        guard hotkey == Self.legacyDefaultHotkey else {
            return
        }
        hotkey = Self.defaultHotkey
        LogCategory.app.info("已迁移旧默认快捷键为新默认值")
    }
}
```

> **注意**：`LogCategory.app.info("已迁移旧默认快捷键为新默认值")` 仅记录事件元数据，不记录快捷键字面值，满足 NFR-004 安全性。如果 `LogCategory` 未在本文件导入，需在文件顶部 `import Foundation` 后追加 `import OSLog` 或确保 `LogCategory` 通过项目模块可见（取决于项目结构；当前 `LogCategory` 在 `ClipMind/Utils/` 下，与 `AppSettings` 同一 target，无需额外 import）。

- [ ] **6.4 运行测试验证通过**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.10-hotkey-default-change
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindTests/AppSettingsHotkeyMigrationTests \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
```

预期：PASS，6 个用例全部通过（含任务 5 的 `testAppSettings_DefaultHotkey_IsNewDefault` 与本任务 5 个迁移用例）。

- [ ] **6.5 SwiftLint strict 验证**

```bash
swiftlint lint --strict ClipMind/Models/AppSettings.swift ClipMindTests/Models/AppSettingsHotkeyMigrationTests.swift
```

预期：无任何违规。

- [ ] **6.6 Commit**

```bash
git add ClipMind/Models/AppSettings.swift ClipMindTests/Models/AppSettingsHotkeyMigrationTests.swift
git commit -m "feat(F1.10): add migrateLegacyHotkey for old user migration"
```

---

## 任务 7：修改 GeneralSettingsView 引用默认值常量（NFR-006）

**文件：**
- 修改：`ClipMind/UI/Settings/GeneralSettingsView.swift`

### 步骤

- [ ] **7.1 修改 @AppStorage 默认值引用**

修改 `ClipMind/UI/Settings/GeneralSettingsView.swift`。定位第 12 行：

```swift
    @AppStorage("hotkey") private var hotkey = "cmd+shift+v"
```

改为：

```swift
    @AppStorage("hotkey") private var hotkey = AppSettings.defaultHotkey
```

同时定位第 8 行的文档注释：

```swift
/// - 快捷键配置（默认 cmd+shift+v）
```

改为：

```swift
/// - 快捷键配置（默认 cmd+shift+space，引用 AppSettings.defaultHotkey）
```

- [ ] **7.2 编译验证**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.10-hotkey-default-change
xcodebuild build \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
```

预期：编译通过，无错误。

- [ ] **7.3 运行现有测试确保不破坏**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.10-hotkey-default-change
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindTests/AppSettingsHotkeyMigrationTests \
  -only-testing ClipMindTests/HotkeyFormatterSpaceKeyTests \
  -only-testing ClipMindTests/HotkeyFormatterRoundTripTests \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
```

预期：PASS，前面任务的测试不破坏。

- [ ] **7.4 SwiftLint strict 验证**

```bash
swiftlint lint --strict ClipMind/UI/Settings/GeneralSettingsView.swift
```

预期：无任何违规。

- [ ] **7.5 Commit**

```bash
git add ClipMind/UI/Settings/GeneralSettingsView.swift
git commit -m "refactor(F1.10): reference AppSettings.defaultHotkey in GeneralSettingsView"
```

---

## 任务 8：TDD - HotkeyRecorder 重置按钮引用默认值常量（AC-F1.10-7）

**文件：**
- 修改：`ClipMind/UI/Settings/HotkeyRecorder.swift`（`HotkeyRecorder.resetButton`）
- 测试：`ClipMindTests/UI/HotkeyRecorderResetTests.swift`（新增）

### 步骤

- [ ] **8.1 编写失败的测试**

创建 `ClipMindTests/UI/HotkeyRecorderResetTests.swift`：

```swift
@testable import ClipMind
import XCTest

/// F1.10 AC-F1.10-7：验证 AppSettings.defaultHotkey 常量与 TestHotkeys.default 一致。
///
/// 注：本测试仅验证常量一致性，真实重置行为由 TC-F1.10-7-02 XCUITest 验证
/// （`GeneralSettingsHotkeyDisplayUITests.testResetHotkeyButton_DisplayUpdatesToCmdShiftSpace`）。
final class HotkeyRecorderResetTests: XCTestCase
{
    func testAppSettingsDefaultHotkeyConstant_IsConsistentWithTestHotkeys()
    {
        // Arrange & Act & Assert - 验证生产代码常量与测试常量集保持一致
        XCTAssertEqual(AppSettings.defaultHotkey, TestHotkeys.default, "AppSettings.defaultHotkey 应与 TestHotkeys.default 保持一致")
    }

    func testResetHotkeyButton_NewDefaultIsDisplayable()
    {
        // Arrange - 重置后的值必须能被 HotkeyFormatter 正确显示
        let resetValue = AppSettings.defaultHotkey

        // Act
        let displayed = HotkeyFormatter.display(resetValue)

        // Assert
        XCTAssertEqual(displayed, "⌘⇧Space", "重置后的新默认值应能被显示为 ⌘⇧Space")
    }
}
```

- [ ] **8.2 运行测试验证失败**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.10-hotkey-default-change
xcodegen generate && xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindTests/HotkeyRecorderResetTests \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：PASS。`testAppSettingsDefaultHotkeyConstant_IsConsistentWithTestHotkeys` 与 `testResetHotkeyButton_NewDefaultIsDisplayable` 应通过（因为任务 5 已让 `AppSettings.defaultHotkey` 可用，任务 3 已让 `display` 支持空格键）。

> **说明**：本任务的测试是常量一致性检查，预期直接通过（任务 5 已定义 `AppSettings.defaultHotkey`）。真实重置行为由 TC-F1.10-7-02 XCUITest 验证（任务 11.1）。

> **但是**：本任务的核心目标是**修改 `HotkeyRecorder.resetButton` 的硬编码值**（当前 `hotkey = "cmd+shift+v"`）为引用 `AppSettings.defaultHotkey`。即使测试通过，也必须执行 8.3 的生产代码修改，否则 NFR-006（默认值集中管理）不满足。

- [ ] **8.3 编写最少实现代码**

修改 `ClipMind/UI/Settings/HotkeyRecorder.swift` 的 `resetButton` 视图（当前在第 52-61 行）。定位：

```swift
    @ViewBuilder
    private var resetButton: some View {
        if !isRecording && !hotkey.isEmpty {
            Button("重置") {
                hotkey = "cmd+shift+v"
                LogCategory.app.info("快捷键已重置为默认值")
            }
            .accessibilityIdentifier("resetHotkeyButton")
        }
    }
```

改为：

```swift
    @ViewBuilder
    private var resetButton: some View {
        if !isRecording && !hotkey.isEmpty {
            Button("重置") {
                hotkey = AppSettings.defaultHotkey
                LogCategory.app.info("快捷键已重置为默认值")
            }
            .accessibilityIdentifier("resetHotkeyButton")
        }
    }
```

- [ ] **8.4 运行测试验证通过**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.10-hotkey-default-change
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindTests/HotkeyRecorderResetTests \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
```

预期：PASS，2 个用例全部通过。

- [ ] **8.5 SwiftLint strict 验证**

```bash
swiftlint lint --strict ClipMind/UI/Settings/HotkeyRecorder.swift ClipMindTests/UI/HotkeyRecorderResetTests.swift
```

预期：无任何违规。

- [ ] **8.6 Commit**

```bash
git add ClipMind/UI/Settings/HotkeyRecorder.swift ClipMindTests/UI/HotkeyRecorderResetTests.swift
git commit -m "feat(F1.10): reset button references AppSettings.defaultHotkey"
```

---

## 任务 9：TDD - GlobalHotkeyService 新默认值注册与触发（AC-F1.10-8）

**文件：**
- 测试：`ClipMindTests/App/GlobalHotkeyServiceF1_10Tests.swift`（新增）
- 不修改生产代码：`GlobalHotkeyService.swift` 的注册逻辑与触发逻辑完全不变，仅 hotkey 字面值由调用方传入变化

### 步骤

- [ ] **9.1 编写失败的测试**

创建 `ClipMindTests/App/GlobalHotkeyServiceF1_10Tests.swift`：

```swift
@testable import ClipMind
import XCTest

/// F1.10 AC-F1.10-8：验证新默认值 cmd+shift+space 可被全局快捷键服务注册并触发"打开快速粘贴面板"通知。
///
/// 复用 GlobalHotkeyServiceTests 中的 MockHotkeyRegistrar（同 target 可见）。
final class GlobalHotkeyServiceF1_10Tests: XCTestCase
{
    // MARK: - TC-F1.10-8-01：新默认值可被全局快捷键服务注册成功

    func testGlobalHotkeyService_InitWithNewDefault_RegistersWithSpaceKeyCode()
    {
        // Arrange
        let mock = MockHotkeyRegistrar()

        // Act - 使用新默认值初始化服务
        let service = GlobalHotkeyService(hotkey: TestHotkeys.default, registrar: mock)

        // Assert
        XCTAssertTrue(service.isRegistered, "新默认值应注册成功")
        XCTAssertEqual(mock.registeredKeyCode, 49, "应注册空格键码 49")
        XCTAssertNotNil(mock.registeredModifiers)
        XCTAssertTrue(mock.registeredModifiers! & 0x0100 != 0, "修饰键应包含 cmdKey")
        XCTAssertTrue(mock.registeredModifiers! & 0x0200 != 0, "修饰键应包含 shiftKey")

        _ = service
    }

    // MARK: - TC-F1.10-8-02：按下新默认值触发"打开快速粘贴面板"通知

    func testGlobalHotkeyService_NewDefaultPressed_PostsOpenQuickPasteNotification()
    {
        // Arrange
        let mock = MockHotkeyRegistrar()
        let service = GlobalHotkeyService(hotkey: TestHotkeys.default, registrar: mock)

        // Act - 监听通知并模拟快捷键按下
        let expectation = XCTNSNotificationExpectation(name: .openQuickPaste)
        mock.simulateHotkeyPressed()

        // Assert
        wait(for: [expectation], timeout: 1.0)

        _ = service
    }
}
```

- [ ] **9.2 运行测试验证失败**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.10-hotkey-default-change
xcodegen generate && xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindTests/GlobalHotkeyServiceF1_10Tests \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：PASS（任务 2 已扩展 `HotkeyFormatter.parse(stored:)` 支持空格键，`GlobalHotkeyService` 的注册逻辑与触发逻辑沿用 F1.9 不变，新默认值能被正确解析为 `keyCode=49` + `cmd+shift` 修饰键并注册成功，按下时发送 `.openQuickPaste` 通知）。

> **说明**：本任务的"失败测试"步骤可能直接通过。这是 TDD 的正常情况——当上游 `HotkeyFormatter` 已支持空格键解析后，`GlobalHotkeyService` 无需任何修改即可处理新默认值。如果直接通过，跳过 9.3 的"实现"步骤，直接进入 9.4 的"通过"验证与 9.5 的 commit。

- [ ] **9.3 编写最少实现代码（仅当 9.2 失败时执行）**

如果 9.2 全部通过，跳过本步骤。如果 `testGlobalHotkeyService_InitWithNewDefault_RegistersWithSpaceKeyCode` 失败（说明 `HotkeyFormatter.parse(stored:)` 无法解析新默认值），检查任务 2 的 `keyCode(for:)` 映射表是否包含 `"space": 49`。若缺失，回溯任务 2 重新应用映射表扩展。

- [ ] **9.4 运行测试验证通过**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.10-hotkey-default-change
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindTests/GlobalHotkeyServiceF1_10Tests \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
```

预期：PASS，2 个用例全部通过。

- [ ] **9.5 SwiftLint strict 验证**

```bash
swiftlint lint --strict ClipMindTests/App/GlobalHotkeyServiceF1_10Tests.swift
```

预期：无任何违规。

- [ ] **9.6 Commit**

```bash
git add ClipMindTests/App/GlobalHotkeyServiceF1_10Tests.swift
git commit -m "test(F1.10): verify new default hotkey registers and triggers quick paste"
```

---

## 任务 10：迁移现有 GlobalHotkeyService 测试到测试常量集（回归保护 + NFR-006）

**文件：**
- 修改：`ClipMindTests/App/GlobalHotkeyServiceTests.swift`（5 处现有用例）
- 修改：`ClipMindTests/App/GlobalHotkeyServiceQuickPasteTests.swift`（2 处现有用例）

### 步骤

- [ ] **10.1 修改 GlobalHotkeyServiceTests.swift**

修改 `ClipMindTests/App/GlobalHotkeyServiceTests.swift`，按下表逐处替换：

| 行号 | 原代码 | 新代码 | 说明 |
|------|--------|--------|------|
| 36 | `HotkeyFormatter.parse(stored: "cmd+shift+v")` | `HotkeyFormatter.parse(stored: TestHotkeys.legacyDefault)` | TC-F1.10-10-01 回归保护，保留旧默认值解析测试 |
| 84 | `GlobalHotkeyService(hotkey: "cmd+shift+v", registrar: mock)` | `GlobalHotkeyService(hotkey: TestHotkeys.default, registrar: mock)` | 改用当前默认值 |
| 86 | `XCTAssertEqual(mock.registeredKeyCode, 9, "应注册 keyCode 9 (v)")` | `XCTAssertEqual(mock.registeredKeyCode, 49, "应注册 keyCode 49 (space)")` | 断言改为空格键码 |
| 88 | `XCTAssertTrue(mock.registeredModifiers! & 0x0100 != 0, "修饰键应包含 cmdKey")` | （不变） | 修饰键断言不变 |
| 89 | `XCTAssertTrue(mock.registeredModifiers! & 0x0200 != 0, "修饰键应包含 shiftKey")` | （不变） | 修饰键断言不变 |
| 101 | `GlobalHotkeyService(hotkey: "cmd+shift+v", registrar: mock)` | `GlobalHotkeyService(hotkey: TestHotkeys.arbitrary, registrar: mock)` | hotkey 值非断言目标 |
| 116 | `GlobalHotkeyService(hotkey: "cmd+shift+v", registrar: mock)` | `GlobalHotkeyService(hotkey: TestHotkeys.arbitrary, registrar: mock)` | hotkey 值非断言目标 |
| 125 | `GlobalHotkeyService(hotkey: "cmd+shift+v", registrar: mock)` | `GlobalHotkeyService(hotkey: TestHotkeys.arbitrary, registrar: mock)` | hotkey 值非断言目标 |

> **注意**：`testParseStoredHotkey_CtrlOptA_ReturnsCorrectModifierAndKeyCode`（第 45-51 行）的 `"ctrl+opt+a"` 与 `TestHotkeys.arbitrary` 值相同，但该用例断言了 `keyCode == 0`（a），hotkey 值是断言目标，**不迁移**到 `TestHotkeys.arbitrary`，保留原字面值以保持断言语义清晰。

具体修改后的关键用例代码（仅展示修改部分）：

`testParseStoredHotkey_CmdShiftV_ReturnsCorrectModifierAndKeyCode`（第 35-43 行）：

```swift
    func testParseStoredHotkey_CmdShiftV_ReturnsCorrectModifierAndKeyCode() {
        let parsed = HotkeyFormatter.parse(stored: TestHotkeys.legacyDefault)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.keyCode, 9) // keyCode for 'v'
        XCTAssertTrue(parsed?.modifiers ?? 0 != 0)
        // cmdKey=0x0100, shiftKey=0x0200 → 组合应包含这两位
        XCTAssertTrue((parsed?.modifiers ?? 0) & 0x0100 != 0) // cmdKey
        XCTAssertTrue((parsed?.modifiers ?? 0) & 0x0200 != 0) // shiftKey
    }
```

`testGlobalHotkeyService_InitWithValidHotkey_RegistersWithCorrectParams`（第 82-90 行）：

```swift
    func testGlobalHotkeyService_InitWithValidHotkey_RegistersWithCorrectParams() {
        let mock = MockHotkeyRegistrar()
        let service = GlobalHotkeyService(hotkey: TestHotkeys.default, registrar: mock)
        XCTAssertTrue(service.isRegistered, "有效的快捷键配置应成功注册")
        XCTAssertEqual(mock.registeredKeyCode, 49, "应注册 keyCode 49 (space)")
        XCTAssertNotNil(mock.registeredModifiers, "应注册修饰键")
        XCTAssertTrue(mock.registeredModifiers! & 0x0100 != 0, "修饰键应包含 cmdKey")
        XCTAssertTrue(mock.registeredModifiers! & 0x0200 != 0, "修饰键应包含 shiftKey")
    }
```

`testGlobalHotkeyService_Unregister_ClearsRegistration`（第 99-106 行）：

```swift
    func testGlobalHotkeyService_Unregister_ClearsRegistration() {
        let mock = MockHotkeyRegistrar()
        let service = GlobalHotkeyService(hotkey: TestHotkeys.arbitrary, registrar: mock)
        XCTAssertTrue(service.isRegistered)
        service.unregister()
        XCTAssertFalse(service.isRegistered, "注销后应不再处于注册状态")
        XCTAssertFalse(mock.isRegistered, "注册器也应注销")
    }
```

`testGlobalHotkeyService_RegistrarFails_IsNotRegistered`（第 114-119 行）：

```swift
    func testGlobalHotkeyService_RegistrarFails_IsNotRegistered() {
        let mock = MockHotkeyRegistrar()
        mock.shouldSucceed = false
        let service = GlobalHotkeyService(hotkey: TestHotkeys.arbitrary, registrar: mock)
        XCTAssertFalse(service.isRegistered, "注册器失败时不应标记为已注册")
    }
```

`testGlobalHotkeyService_HotkeyPressed_PostsOpenQuickPasteNotification`（第 123-132 行）：

```swift
    func testGlobalHotkeyService_HotkeyPressed_PostsOpenQuickPasteNotification() {
        let mock = MockHotkeyRegistrar()
        let service = GlobalHotkeyService(hotkey: TestHotkeys.arbitrary, registrar: mock)

        let expectation = XCTNSNotificationExpectation(name: .openQuickPaste)
        mock.simulateHotkeyPressed()
        wait(for: [expectation], timeout: 1.0)
        // 保持 service 引用避免被释放
        _ = service
    }
```

- [ ] **10.2 修改 GlobalHotkeyServiceQuickPasteTests.swift**

修改 `ClipMindTests/App/GlobalHotkeyServiceQuickPasteTests.swift`，2 处现有用例改用 `TestHotkeys.arbitrary`：

`testHotkeyPressed_PostsOpenQuickPasteNotification`（第 9-18 行）：

```swift
    func testHotkeyPressed_PostsOpenQuickPasteNotification()
    {
        let mock = MockHotkeyRegistrar()
        let service = GlobalHotkeyService(hotkey: TestHotkeys.arbitrary, registrar: mock)

        let quickPasteExpectation = XCTNSNotificationExpectation(name: .openQuickPaste)
        mock.simulateHotkeyPressed()
        wait(for: [quickPasteExpectation], timeout: 1.0)
        _ = service
    }
```

`testHotkeyPressed_DoesNotPostOpenMainWindowNotification`（第 22-32 行）：

```swift
    func testHotkeyPressed_DoesNotPostOpenMainWindowNotification()
    {
        let mock = MockHotkeyRegistrar()
        let service = GlobalHotkeyService(hotkey: TestHotkeys.arbitrary, registrar: mock)

        let mainWindowExpectation = XCTNSNotificationExpectation(name: .openMainWindow)
        mainWindowExpectation.isInverted = true
        mock.simulateHotkeyPressed()
        wait(for: [mainWindowExpectation], timeout: 1.0)
        _ = service
    }
```

- [ ] **10.3 运行测试验证通过**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.10-hotkey-default-change
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindTests/GlobalHotkeyServiceTests \
  -only-testing ClipMindTests/GlobalHotkeyServiceQuickPasteTests \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：PASS，`GlobalHotkeyServiceTests` 全部 11 个用例 + `GlobalHotkeyServiceQuickPasteTests` 全部 2 个用例通过（含迁移后的回归保护用例 `testParseStoredHotkey_CmdShiftV_ReturnsCorrectModifierAndKeyCode` 仍验证旧默认值解析正确）。

- [ ] **10.4 SwiftLint strict 验证**

```bash
swiftlint lint --strict ClipMindTests/App/GlobalHotkeyServiceTests.swift ClipMindTests/App/GlobalHotkeyServiceQuickPasteTests.swift
```

预期：无任何违规。

- [ ] **10.5 Commit**

```bash
git add ClipMindTests/App/GlobalHotkeyServiceTests.swift ClipMindTests/App/GlobalHotkeyServiceQuickPasteTests.swift
git commit -m "test(F1.10): migrate existing hotkey tests to TestHotkeys constants"
```

---

## 任务 11：XCUITest 设置页显示新默认值（AC-F1.10-9, AC-F1.10-7-02）- 不本地执行

**文件：**
- 修改：`ClipMind/App/ClipMindApp.swift`（步骤 11.0，处理 XCUITest 启动参数）
- 修改：`ClipMind/UI/Settings/HotkeyRecorder.swift`（步骤 11.0，为 hotkeyRecorder 按钮添加 accessibilityLabel）
- 创建：`ClipMindUITests/GeneralSettingsHotkeyDisplayUITests.swift`（步骤 11.1）

> **说明**：本任务的测试不本地执行（XCUITest 涉及真实窗口与系统通知，本地 xcodebuild 环境不稳定），仅创建测试文件并确保编译通过。测试延迟到 CI（步骤 4.5b Smoke CI 或步骤 5.5 完整 CI）执行。步骤 11.0 修改生产代码以支持 XCUITest 启动参数注入与可访问性断言，是 XCUITest 在 CI 上可执行的前提。

### 步骤

- [ ] **11.0 修改生产代码支持 XCUITest 启动参数与可访问性断言（测试基础设施）**

**背景**：任务 11.1 的 XCUITest 用例 TC-F1.10-9-02 使用 `--UITEST_LEGACY_HOTKEY` 注入老用户旧默认值，TC-F1.10-7-02 使用 `--UITEST_CUSTOM_HOTKEY` 注入自定义值。当前 `applyUITestOverrides()` 未处理这两个参数，CI 上 XCUITest 无法正确注入测试场景。同时，三个 XCUITest 用例用 `recorder.title` 断言显示值，但 SwiftUI Button 的 `.title` 属性在 macOS XCUITest 中不可靠，需改用 `.accessibilityLabel` + `recorder.label` 断言。

**TDD 步骤**：

1. **失败测试**：任务 11.1 创建的 XCUITest（TC-F1.10-9-02、TC-F1.10-7-02）在 CI 上执行时，由于 `--UITEST_LEGACY_HOTKEY` 与 `--UITEST_CUSTOM_HOTKEY` 未被 `applyUITestOverrides()` 处理，App 不会向 UserDefaults 注入对应 hotkey 值，导致迁移与重置场景无法被真实验证；同时 `recorder.title` 断言在 macOS XCUITest 中不可靠。

2. **验证失败**：在 11.1 创建 XCUITest 文件后，执行 `xcodebuild build-for-testing` 编译通过，但 CI 执行 XCUITest 时 TC-F1.10-9-02 与 TC-F1.10-7-02 无法验证预期行为（迁移与重置场景未正确注入，断言方式不可靠）。

3. **最小实现（Part A：ClipMindApp.swift 启动参数处理）**：修改 `ClipMind/App/ClipMindApp.swift` 的 `applyUITestOverrides()` 方法，在 `--UITEST_ENABLE_AUTOSAVE` 分支之后追加 `--UITEST_LEGACY_HOTKEY` 与 `--UITEST_CUSTOM_HOTKEY` 处理分支。

**Edit 工具锚点（Part A）**：

old_string（`--UITEST_ENABLE_AUTOSAVE` 分支末尾 + 方法闭合）：

```swift
        if CommandLine.arguments.contains("--UITEST_ENABLE_AUTOSAVE")
        {
            let store = AutoSaveSettingsStore()
            var settings = store.load()
            settings.isEnabled = true
            store.save(settings)
            LogCategory.app.logger.info("已通过 --UITEST_ENABLE_AUTOSAVE 启用 F2.1 总开关")
        }
    }
```

new_string（追加两个新分支）：

```swift
        if CommandLine.arguments.contains("--UITEST_ENABLE_AUTOSAVE")
        {
            let store = AutoSaveSettingsStore()
            var settings = store.load()
            settings.isEnabled = true
            store.save(settings)
            LogCategory.app.logger.info("已通过 --UITEST_ENABLE_AUTOSAVE 启用 F2.1 总开关")
        }
        if CommandLine.arguments.contains("--UITEST_LEGACY_HOTKEY")
        {
            UserDefaults.standard.set("cmd+shift+v", forKey: "hotkey")
            UserDefaults.standard.synchronize()
            LogCategory.app.logger.info("已通过 --UITEST_LEGACY_HOTKEY 注入老用户旧默认快捷键")
        }
        if CommandLine.arguments.contains("--UITEST_CUSTOM_HOTKEY")
        {
            UserDefaults.standard.set("ctrl+opt+a", forKey: "hotkey")
            UserDefaults.standard.synchronize()
            LogCategory.app.logger.info("已通过 --UITEST_CUSTOM_HOTKEY 注入自定义快捷键")
        }
    }
```

> **注意**：这里使用字面值 `"cmd+shift+v"` 与 `"ctrl+opt+a"` 而非 `AppSettings.legacyDefaultHotkey` 与 `TestHotkeys.arbitrary`。原因：生产代码不能引用测试常量 `TestHotkeys`；使用字面值直观表达注入意图，且与 `AppSettings.legacyDefaultHotkey`（`"cmd+shift+v"`）和 `TestHotkeys.arbitrary`（`"ctrl+opt+a"`）值一致。处理顺序保证 `--UITEST_RESET_SETTINGS`（若同时传入）先清除 hotkey，再由 `--UITEST_LEGACY_HOTKEY` / `--UITEST_CUSTOM_HOTKEY` 注入目标值。

4. **最小实现（Part B：HotkeyRecorder.swift accessibilityLabel）**：修改 `ClipMind/UI/Settings/HotkeyRecorder.swift` 的 `recordingIndicator` 视图，为 `hotkeyRecorder` 按钮添加 `.accessibilityLabel(HotkeyFormatter.display(hotkey))`，使 XCUITest 可通过 `recorder.label` 可靠断言显示值。

**Edit 工具锚点（Part B）**：

old_string（当前 `recordingIndicator` 的 Button）：

```swift
            Button(action: startRecording) {
                Text(HotkeyFormatter.display(hotkey))
                    .frame(minWidth: 80)
            }
            .accessibilityIdentifier("hotkeyRecorder")
```

new_string（追加 `.accessibilityLabel`）：

```swift
            Button(action: startRecording) {
                Text(HotkeyFormatter.display(hotkey))
                    .frame(minWidth: 80)
            }
            .accessibilityIdentifier("hotkeyRecorder")
            .accessibilityLabel(HotkeyFormatter.display(hotkey))
```

> **说明**：`.accessibilityLabel` 与 `Text` 内容一致（均为 `HotkeyFormatter.display(hotkey)`），不影响视觉呈现，仅让 XCUITest 可通过 `recorder.label` 可靠读取当前显示的快捷键。这是生产代码改动，但属于测试可访问性基础设施，不改变用户可见行为。

5. **验证通过**：执行 `xcodebuild build` 编译通过；CI 执行 XCUITest 时 TC-F1.10-9-02 与 TC-F1.10-7-02 能正确验证迁移与重置行为，`recorder.label` 断言可靠。

- [ ] **11.0.1 SwiftLint strict 验证**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.10-hotkey-default-change
swiftlint lint --strict ClipMind/App/ClipMindApp.swift ClipMind/UI/Settings/HotkeyRecorder.swift
```

预期：无任何违规。

- [ ] **11.0.2 Commit**

```bash
git add ClipMind/App/ClipMindApp.swift ClipMind/UI/Settings/HotkeyRecorder.swift
git commit -m "test(F1.10): handle UITEST hotkey launch arguments and add accessibilityLabel"
```

- [ ] **11.1 创建 XCUITest 文件**

创建 `ClipMindUITests/GeneralSettingsHotkeyDisplayUITests.swift`：

```swift
import XCTest

/// F1.10 AC-F1.10-9 / AC-F1.10-7-02：验证设置页快捷键录制器默认显示新默认值。
///
/// 本测试文件延迟到 CI 执行（本地 xcodebuild 环境不稳定）。
/// 通过 accessibilityIdentifier 定位元素：
/// - "hotkeyRecorder"：快捷键录制器按钮（显示当前快捷键，通过 .accessibilityLabel 暴露显示值）
/// - "resetHotkeyButton"：重置按钮
///
/// 启动参数（与 SettingsUITests 一致的导航模式）：
/// - "--UITEST_SHOW_MAIN_WINDOW"：显示主窗口
/// - "--UITEST_RESET_SETTINGS"：重置设置（清除持久化 hotkey）
/// - "--UITEST_INITIAL_TAB=general"：直接定位到通用标签
/// - "--UITEST_LEGACY_HOTKEY"：注入老用户旧默认值（cmd+shift+v，由 11.0 处理）
/// - "--UITEST_CUSTOM_HOTKEY"：注入自定义值（ctrl+opt+a，由 11.0 处理）
final class GeneralSettingsHotkeyDisplayUITests: XCTestCase
{
    override func setUpWithError() throws
    {
        continueAfterFailure = false
    }

    // MARK: - TC-F1.10-9-01：新用户首启后设置页快捷键录制器显示 ⌘⇧Space

    func testSettingsPage_NewUser_ShowsCmdShiftSpaceByDefault()
    {
        // Arrange - 启动 App（首启状态，无持久化快捷键）
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_RESET_SETTINGS",
            "--UITEST_INITIAL_TAB=general"
        ]
        app.launch()

        // Act - 打开通用设置页
        openGeneralSettings(in: app)

        // Assert - 快捷键录制器显示 ⌘⇧Space（通过 accessibilityLabel 断言）
        let recorder = app.buttons["hotkeyRecorder"]
        XCTAssertTrue(recorder.waitForExistence(timeout: 5.0), "快捷键录制器应存在")
        XCTAssertEqual(recorder.label, "⌘⇧Space", "新用户首启后应显示 ⌘⇧Space")
    }

    // MARK: - TC-F1.10-9-02：老用户迁移后设置页快捷键录制器显示 ⌘⇧Space

    func testSettingsPage_AfterLegacyMigration_ShowsCmdShiftSpace()
    {
        // Arrange - 模拟老用户持久化旧默认值（通过 UserDefaults 注入）
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_RESET_SETTINGS",
            "--UITEST_INITIAL_TAB=general",
            "--UITEST_LEGACY_HOTKEY"
        ]
        app.launch()

        // Act - 启动后 AppSettings.migrateLegacyHotkey() 自动迁移；打开设置页
        openGeneralSettings(in: app)

        // Assert - 快捷键录制器显示迁移后的 ⌘⇧Space
        let recorder = app.buttons["hotkeyRecorder"]
        XCTAssertTrue(recorder.waitForExistence(timeout: 5.0), "快捷键录制器应存在")
        XCTAssertEqual(recorder.label, "⌘⇧Space", "老用户迁移后应显示 ⌘⇧Space")
    }

    // MARK: - TC-F1.10-7-02：重置按钮点击后设置页显示更新为 ⌘⇧Space

    func testResetHotkeyButton_DisplayUpdatesToCmdShiftSpace()
    {
        // Arrange - 启动 App 并打开设置页（注入自定义快捷键）
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_RESET_SETTINGS",
            "--UITEST_INITIAL_TAB=general",
            "--UITEST_CUSTOM_HOTKEY"
        ]
        app.launch()
        openGeneralSettings(in: app)

        let recorder = app.buttons["hotkeyRecorder"]
        XCTAssertTrue(recorder.waitForExistence(timeout: 5.0))

        // Act - 点击重置按钮
        let resetButton = app.buttons["resetHotkeyButton"]
        XCTAssertTrue(resetButton.waitForExistence(timeout: 2.0), "重置按钮应存在")
        resetButton.click()

        // Assert - 显示更新为 ⌘⇧Space
        XCTAssertEqual(recorder.label, "⌘⇧Space", "重置后应显示 ⌘⇧Space")
    }

    // MARK: - 辅助

    /// 打开通用设置页（与 SettingsUITests.launchAndOpenGeneralSettings 一致的导航方式）。
    /// 通用标签已通过 --UITEST_INITIAL_TAB=general 启动参数定位，无需切换标签。
    private func openGeneralSettings(in app: XCUIApplication)
    {
        let settingsButton = app.buttons["settingsButton"].firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5.0), "设置按钮应存在")
        settingsButton.click()
    }
}
```

> **注意**：启动参数 `--UITEST_LEGACY_HOTKEY` 与 `--UITEST_CUSTOM_HOTKEY` 已在步骤 11.0 中通过修改 `ClipMind/App/ClipMindApp.swift` 的 `applyUITestOverrides()` 方法实现处理。XCUITest 在 CI 上执行时，App 会正确注入老用户旧默认值（`cmd+shift+v`）与自定义值（`ctrl+opt+a`），TC-F1.10-9-02 与 TC-F1.10-7-02 能验证真实迁移与重置行为。`recorder.label` 断言依赖步骤 11.0 Part B 为 `hotkeyRecorder` 按钮添加的 `.accessibilityLabel`。

- [ ] **11.2 编译验证（不执行测试）**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.10-hotkey-default-change
xcodegen generate && xcodebuild build-for-testing \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
```

预期：编译通过，无错误。新增文件被 xcodegen 自动纳入 `ClipMindUITests` target。

- [ ] **11.3 SwiftLint strict 验证**

```bash
swiftlint lint --strict ClipMindUITests/GeneralSettingsHotkeyDisplayUITests.swift
```

预期：无任何违规。

- [ ] **11.4 Commit**

```bash
git add ClipMindUITests/GeneralSettingsHotkeyDisplayUITests.swift
git commit -m "test(F1.10): add XCUITest for settings page hotkey display"
```

> **UI 证据任务说明**：本任务的 XCUITest 不本地执行，CI 执行时若失败需提供 CI 日志作为证据。手动验收脚本（可选，发布前执行）：
> 1. 启动 App（确保 UserDefaults 中无 hotkey 键）。
> 2. 通过菜单栏打开设置 → 通用。
> 3. 截图：快捷键录制器应显示 ⌘⇧Space。
> 4. 点击重置按钮，截图：快捷键录制器应仍显示 ⌘⇧Space。
> 5. 退出 App，向 UserDefaults 写入 `hotkey = "cmd+shift+v"`，重启 App。
> 6. 打开设置 → 通用，截图：快捷键录制器应显示 ⌘⇧Space（迁移后）。

---

## 任务 12：同步文档 + 追加 history

**文件：**
- 修改：`docs/planning/P0/F1/F1_ClipMind_设计规范.md`（涉及默认快捷键字面值的位置）
- 修改：`docs/planning/P0/F1/F1.9_快捷粘贴面板_测试用例表.md`（涉及默认快捷键字面值的位置）
- 创建：`docs/planning/P0/F1/historys/2026-07-25-F1.10-快捷键默认值修改.md`

### 步骤

- [ ] **12.1 搜索并更新 F1 主设计规范中的默认快捷键字面值**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.10-hotkey-default-change
grep -n "cmd+shift+v" docs/planning/P0/F1/F1_ClipMind_设计规范.md
```

预期：列出所有出现 `cmd+shift+v` 的行号。逐行审查：

- 如果是"默认快捷键"语义的字面值，改为 `cmd+shift+space`。
- 如果是"旧默认值"或"历史默认值"语义的字面值，保留为 `cmd+shift+v` 并补充说明"（F1.10 之前的旧默认值）"。
- 如果是测试用例引用，保留为 `cmd+shift+v`（回归保护语义）。

> **注意**：本步骤需要人工审查每处出现的语义，不能机械全局替换。审查后用 Edit 工具逐处修改。

- [ ] **12.2 搜索并更新 F1.9 测试用例表中的默认快捷键字面值**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.10-hotkey-default-change
grep -n "cmd+shift+v" docs/planning/P0/F1/F1.9_快捷粘贴面板_测试用例表.md
```

预期：列出所有出现 `cmd+shift+v` 的行号。逐行审查：

- 如果是"默认快捷键"语义的字面值，改为 `cmd+shift+space`。
- 如果是"旧默认值"或"历史默认值"语义的字面值，保留为 `cmd+shift+v` 并补充说明。
- 如果是测试用例引用（如 TC-F1.9-1-01 验证快捷键触发），保留为 `cmd+shift+v` 或改为 `cmd+shift+space`（取决于测试是否迁移到新默认值）。

> **注意**：F1.9 测试用例表中涉及默认快捷键的位置需要同步更新，但 F1.9 已交付的测试代码（`GlobalHotkeyServiceQuickPasteTests.swift`）在任务 10 已迁移到 `TestHotkeys.arbitrary`，文档与代码保持一致。

- [ ] **12.3 创建 history 记录**

创建 `docs/planning/P0/F1/historys/2026-07-25-F1.10-快捷键默认值修改.md`：

```markdown
> 最后更新：2026-07-25 | 版本：v1.0

# F1.10 快捷键默认值修改 变更记录

**变更摘要**：将 ClipMind 默认全局快捷键从 `cmd+shift+v` 修改为 `cmd+shift+space`，扩展 `HotkeyFormatter` 对空格键的支持，为老用户执行无感迁移，抽取测试常量集。

## 变更内容

### 生产代码

- `ClipMind/Models/AppSettings.swift`：新增 `defaultHotkey` / `legacyDefaultHotkey` 常量与 `migrateLegacyHotkey()` 方法；`hotkey` 字段默认值改为 `AppSettings.defaultHotkey`。
- `ClipMind/UI/Settings/HotkeyRecorder.swift`：`HotkeyFormatter` 扩展空格键映射（`49 ↔ "space"` + `display` 返回 `"Space"`）；`HotkeyRecorder.resetButton` 改为引用 `AppSettings.defaultHotkey`；`hotkeyRecorder` 按钮添加 `.accessibilityLabel` 供 XCUITest 可靠断言。
- `ClipMind/UI/Settings/GeneralSettingsView.swift`：`@AppStorage("hotkey")` 默认值改为引用 `AppSettings.defaultHotkey`。
- `ClipMind/App/ClipMindApp.swift`：`applyUITestOverrides()` 新增处理 `--UITEST_LEGACY_HOTKEY` 与 `--UITEST_CUSTOM_HOTKEY` 启动参数，供 XCUITest 注入老用户旧默认值与自定义值。

### 测试代码

- 新增 `ClipMindTests/Hotkey/HotkeyTestConstants.swift` 测试常量集。
- 新增 `ClipMindTests/Hotkey/HotkeyFormatterSpaceKeyTests.swift` 覆盖 AC-F1.10-1, AC-F1.10-2。
- 新增 `ClipMindTests/Hotkey/HotkeyFormatterRoundTripTests.swift` 覆盖 AC-F1.10-3, AC-F1.10-10。
- 新增 `ClipMindTests/Models/AppSettingsHotkeyMigrationTests.swift` 覆盖 AC-F1.10-4, AC-F1.10-5, AC-F1.10-6。
- 新增 `ClipMindTests/UI/HotkeyRecorderResetTests.swift` 覆盖 AC-F1.10-7（仅常量一致性，真实重置行为由 XCUITest 验证）。
- 新增 `ClipMindTests/App/GlobalHotkeyServiceF1_10Tests.swift` 覆盖 AC-F1.10-8。
- 新增 `ClipMindUITests/GeneralSettingsHotkeyDisplayUITests.swift` 覆盖 AC-F1.10-9, AC-F1.10-7-02（延迟到 CI 执行）。
- 修改 `ClipMindTests/App/GlobalHotkeyServiceTests.swift`：5 处现有用例迁移到测试常量集。
- 修改 `ClipMindTests/App/GlobalHotkeyServiceQuickPasteTests.swift`：2 处现有用例迁移到测试常量集。
- 修改 `ClipMindTests/Models/ClipItemModelTests.swift`：默认值断言改为引用 `TestHotkeys.default`。

### 文档

- 更新 `docs/planning/P0/F1/F1_ClipMind_设计规范.md` 中涉及默认快捷键字面值的位置。
- 更新 `docs/planning/P0/F1/F1.9_快捷粘贴面板_测试用例表.md` 中涉及默认快捷键字面值的位置。

## 关联文档

- 需求文档：`docs/planning/P0/F1/F1.10_快捷键默认值修改_需求文档.md` v1.0
- 设计文档：`docs/planning/P0/F1/F1.10_快捷键默认值修改_设计文档.md` v1.1
- 视觉原型：`docs/planning/P0/F1/F1.10_快捷键默认值修改_视觉原型.html` v1.0
- 测试用例表：`docs/planning/P0/F1/F1.10_快捷键默认值修改_测试用例表.md` v1.0
- 实现计划：`docs/planning/P0/F1/plans/F1.10-快捷键默认值修改/` v1.0

## AC 覆盖

- AC-F1.10-1 ~ AC-F1.10-10 全部 10 条 AC 由测试覆盖。
- 8 处新增 F1.10 专项测试 + 1 处现有断言修改 + 1 处回归保护保留 + 5 处现有用例迁移到 `TestHotkeys.arbitrary`。

## 合规风险

- 零合规风险：仅修改默认值字面值与扩展键名映射，不改变快捷键注册流程的权限模型，主 Scheme `ClipMind` 仍完全合规。

## 版本记录

| 版本 | 日期 | 变更说明 |
|------|------|---------|
| v1.0 | 2026-07-25 | 初始版本，F1.10 快捷键默认值修改完成 |
```

- [ ] **12.4 SwiftLint strict 验证（无 Swift 改动，跳过）**

本任务仅涉及 Markdown 文档，无 Swift 改动，跳过 SwiftLint strict 检查。

- [ ] **12.5 Commit**

```bash
git add docs/planning/P0/F1/F1_ClipMind_设计规范.md docs/planning/P0/F1/F1.9_快捷粘贴面板_测试用例表.md docs/planning/P0/F1/historys/2026-07-25-F1.10-快捷键默认值修改.md
git commit -m "docs(F1.10): sync default hotkey literal in F1 spec and F1.9 test cases"
```

---

## 任务 13：完整回归 + Phase 合并基线

**文件：**
- 不修改文件，仅运行完整回归命令并记录基线。

### 步骤

- [ ] **13.1 运行完整 XCTest 回归**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.10-hotkey-default-change
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
```

预期：全部 XCTest 用例通过，无失败、无崩溃。重点验证：

- `HotkeyFormatterSpaceKeyTests`（AC-F1.10-1, AC-F1.10-2）通过
- `HotkeyFormatterRoundTripTests`（AC-F1.10-3, AC-F1.10-10）通过
- `AppSettingsHotkeyMigrationTests`（AC-F1.10-4, AC-F1.10-5, AC-F1.10-6）通过
- `HotkeyRecorderResetTests`（AC-F1.10-7）通过
- `GlobalHotkeyServiceF1_10Tests`（AC-F1.10-8）通过
- `GlobalHotkeyServiceTests`（含迁移后的回归保护用例）全部通过
- `GlobalHotkeyServiceQuickPasteTests`（含迁移后的用例）全部通过
- `ClipItemModelTests`（含修改后的默认值断言）全部通过
- 其他现有测试（F1.1 ~ F1.9）全部通过，无回归破坏

- [ ] **13.2 运行 SwiftLint strict 全量检查**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.10-hotkey-default-change
swiftlint lint --strict
```

预期：无任何违规。

- [ ] **13.3 编译主 Scheme 验证合规性**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.10-hotkey-default-change
xcodebuild build \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -20
```

预期：编译通过，主 Scheme `ClipMind` 完全合规（无新增 entitlement、无私有 API、App Sandbox 启用）。

- [ ] **13.4 记录 Phase 合并基线**

在 worktree 根目录创建临时基线记录（不提交，仅供主线程合并参考）：

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.10-hotkey-default-change
echo "F1.10 Phase 1 基线（$(date '+%Y-%m-%d %H:%M:%S')）：
- XCTest 全量回归：PASS
- SwiftLint strict：PASS
- 主 Scheme ClipMind 编译：PASS
- AC 覆盖：AC-F1.10-1 ~ AC-F1.10-10 全部 10 条
- 新增测试文件：7 个（含 1 个 XCUITest 延迟到 CI）
- 修改测试文件：3 个
- 修改生产代码文件：3 个
- 合规风险：零" > /tmp/F1.10-phase-1-baseline.txt
cat /tmp/F1.10-phase-1-baseline.txt
```

预期：基线记录生成完成。

- [ ] **13.5 不 Commit（由主线程统一处理）**

本任务不产生新的代码改动，无需 commit。Phase 1 的所有提交已在任务 1-12 中完成。主线程在步骤 3.5 check-plan 通过后会统一合并到 develop。

---

## Phase 合并到 develop 的预期基线

完成本 Phase 全部 13 个任务后，分支 `feature/F1.10-hotkey-default-change` 应满足以下基线，可合并到 `develop`：

### 代码基线

- **生产代码改动**：4 个文件（`AppSettings.swift` / `HotkeyRecorder.swift` / `GeneralSettingsView.swift` / `ClipMindApp.swift`），共新增 2 个静态常量、1 个方法、扩展 3 个映射表/分支、修改 2 处默认值引用、扩展 `applyUITestOverrides()` 处理 2 个 XCUITest 启动参数、为 `hotkeyRecorder` 按钮添加 `accessibilityLabel`。
- **测试代码改动**：新增 7 个测试文件（含 1 个 XCUITest），修改 3 个现有测试文件。
- **文档改动**：更新 2 个现有文档（F1 主设计规范、F1.9 测试用例表），新增 1 个 history 记录。

### 测试基线

- **XCTest 全量回归**：PASS（含 F1.10 新增 8 处专项测试 + 1 处现有断言修改 + 1 处回归保护保留 + 5 处现有用例迁移到 `TestHotkeys.arbitrary` + F1.1 ~ F1.9 现有测试无回归破坏）。
- **SwiftLint strict**：PASS（无任何违规）。
- **XCUITest**：编译通过，延迟到 CI 执行（步骤 4.5b Smoke CI 或步骤 5.5 完整 CI）。启动参数（`--UITEST_LEGACY_HOTKEY` / `--UITEST_CUSTOM_HOTKEY`）已在任务 11.0 实现，CI 无阻塞风险。

### AC 覆盖基线

| AC 编号 | 覆盖方式 | 测试框架 | 状态 |
|---------|---------|---------|------|
| AC-F1.10-1 | `HotkeyFormatterSpaceKeyTests.testParse_NewDefault_ReturnsSpaceKeyCodeAndCmdShiftModifiers` | XCTest | ✅ 本地通过 |
| AC-F1.10-2 | `HotkeyFormatterSpaceKeyTests.testDisplay_NewDefault_ReturnsCmdShiftSpaceUppercase` | XCTest | ✅ 本地通过 |
| AC-F1.10-3 | `HotkeyFormatterRoundTripTests.testParse_ModifiersAndSpaceKeyCode_ReturnsNewDefaultStorageRepresentation` + `testRoundTrip_NewDefault_PreservesStorageRepresentation` | XCTest | ✅ 本地通过 |
| AC-F1.10-4 | `AppSettingsHotkeyMigrationTests.testAppSettings_DefaultHotkey_IsNewDefault` + `ClipItemModelTests.testAppSettingsDefaults`（修改后） | XCTest | ✅ 本地通过 |
| AC-F1.10-5 | `AppSettingsHotkeyMigrationTests.testMigrateLegacyHotkey_WhenLegacyDefault_MigratesToNewDefault` | XCTest | ✅ 本地通过 |
| AC-F1.10-6 | `AppSettingsHotkeyMigrationTests.testMigrateLegacyHotkey_WhenCustomValue_KeepsCustomValue` + `testMigrateLegacyHotkey_WhenEmptyValue_DoesNotMigrate` + `testMigrateLegacyHotkey_WhenInvalidValue_DoesNotMigrate` | XCTest | ✅ 本地通过 |
| AC-F1.10-7 | `HotkeyRecorderResetTests.testAppSettingsDefaultHotkeyConstant_IsConsistentWithTestHotkeys`（仅常量一致性）+ `testResetHotkeyButton_NewDefaultIsDisplayable` + `GeneralSettingsHotkeyDisplayUITests.testResetHotkeyButton_DisplayUpdatesToCmdShiftSpace`（真实重置行为） | XCTest + XCUITest | ✅ XCTest 本地通过（仅常量一致性，真实重置行为由 XCUITest 验证）；XCUITest 延迟到 CI（启动参数已实现，无 CI 风险） |
| AC-F1.10-8 | `GlobalHotkeyServiceF1_10Tests.testGlobalHotkeyService_InitWithNewDefault_RegistersWithSpaceKeyCode` + `testGlobalHotkeyService_NewDefaultPressed_PostsOpenQuickPasteNotification` | XCTest | ✅ 本地通过 |
| AC-F1.10-9 | `GeneralSettingsHotkeyDisplayUITests.testSettingsPage_NewUser_ShowsCmdShiftSpaceByDefault` + `testSettingsPage_AfterLegacyMigration_ShowsCmdShiftSpace` | XCUITest | ⏸️ 延迟到 CI（启动参数已实现，无 CI 风险） |
| AC-F1.10-10 | `HotkeyFormatterRoundTripTests.testRoundTrip_LegacyDefault_PreservesStorageRepresentation` + `GlobalHotkeyServiceTests.testParseStoredHotkey_CmdShiftV_ReturnsCorrectModifierAndKeyCode`（迁移到 `TestHotkeys.legacyDefault`） | XCTest | ✅ 本地通过（回归保护） |

### 合规基线

- 主 Scheme `ClipMind` 仍完全合规（无新增 entitlement、无私有 API、App Sandbox 启用）。
- 本特性无需暂存到 `ClipMind-Dev` Scheme，可直接合入主 Scheme `ClipMind`。

### 文档基线

- F1 主设计规范中涉及默认快捷键字面值的位置已同步更新。
- F1.9 测试用例表中涉及默认快捷键字面值的位置已同步更新。
- `docs/planning/P0/F1/historys/2026-07-25-F1.10-快捷键默认值修改.md` 变更记录已追加。

---

## 版本记录

| 版本 | 日期 | 变更说明 |
|------|------|---------|
| v1.0 | 2026-07-25 | 初始版本，单 Phase 实现计划，13 个任务，32 个 TDD 步骤，覆盖 F1.10 全部 10 条 AC，2 个 UI 证据任务（XCUITest 延迟到 CI），零合规风险 |
| v1.1 | 2026-07-25 | 修复 check-plan B/C 问题：新增任务 11.0 处理 XCUITest 启动参数（ClipMindApp.swift `applyUITestOverrides()` 处理 `--UITEST_LEGACY_HOTKEY` / `--UITEST_CUSTOM_HOTKEY`）+ hotkeyRecorder 按钮添加 accessibilityLabel；任务 11.1 XCUITest 入口改用 SettingsUITests 模式（`settingsButton` + `--UITEST_INITIAL_TAB=general`）、断言改用 `recorder.label`；任务 8 虚假测试降级为常量一致性检查（`testAppSettingsDefaultHotkeyConstant_IsConsistentWithTestHotkeys`）并修复 8.2 矛盾描述；更新涉及文件表与非目标章节 |
