> 最后更新：2026-07-23 | 版本：v1.2

# Phase 4：Accessibility 路径

> **面向 AI 代理的工作者：** 本 Phase 在 Phase 1/2/3 的基础上实现有辅助功能权限时的自动粘贴路径。**合规高风险**：方案1（有权限路径）标注「合规待定」（设计文档第 10.3 节），所有有权限路径代码用 `#if CLIPMIND_DEV` 编译条件包裹，主 Scheme `ClipMind` 不编译这些代码，仅 `ClipMind-Dev` Scheme 编译。使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现。步骤使用复选框（`- [ ]`）语法跟踪进度。前置条件：Phase 1 + Phase 2 + Phase 3 全部测试通过。所有任务严格按编号顺序执行。

## 目标

实现有辅助功能权限时的完整自动粘贴路径：双击/回车文本行 → 检测权限（运行时检测，不弹 TCC）→ 写入剪贴板 → 关闭快速粘贴面板 → 模拟系统标准 Cmd+V 粘贴按键到前台应用 caret 位置。同时实现面板的 caret 附近定位（有 caret 时定位到 caret 附近，无 caret 时降级到鼠标位置），以及权限撤销时自动降级到无权限路径。所有有权限路径代码通过 `#if CLIPMIND_DEV` 编译条件隔离，主 Scheme `ClipMind` 保持 App Store 完全合规（行为与 Phase 3 一致，所有粘贴流程走降级浮层路径）。

## 范围

- `ClipMind-Dev` Scheme 与 `CLIPMIND_DEV` 编译条件（project.yml 配置）
- `AccessibilityService`：辅助功能服务（运行时权限检测 + caret 定位 + 鼠标位置降级，`#if CLIPMIND_DEV`）
- `PasteSimulator`：模拟粘贴按键模块（仅发送系统标准 Cmd+V，`#if CLIPMIND_DEV`）
- `CaretPanelLocator`：caret 附近面板定位（有 caret 用 caret，无 caret 降级鼠标位置，无权限降级屏幕中央/上次位置，`#if CLIPMIND_DEV`）
- `PasteCoordinator` 扩展有权限路径分支（`#if CLIPMIND_DEV` 包裹模拟粘贴调用）
- `AppDelegate` 根据编译条件切换 PanelLocator + 注入 AccessibilityService（`#if CLIPMIND_DEV`）
- 单元测试 10 条 + UI 测试 4 条（覆盖 AC-F1.9-2, AC-F1.9-6, AC-F1.9-10 有权限路径, AC-F1.9-12 真实环境, TC-F1.9-SEC-03）

## 非目标

- 不修改 Phase 1/2/3 的无权限降级路径行为（主 Scheme 保持 Phase 3 行为）
- 不修改 `QuickPasteSettings` / `ClipboardWriter` / `ClipboardConsumerWatcher` / `PasteOverlayController` 的接口
- 不实现批量自动化粘贴（仅响应用户双击/回车单次操作）
- 不读取 caret 处的文本内容（仅获取 caret 坐标用于面板定位）
- 不发送任意按键序列（仅发送系统标准 Cmd+V）
- 不缓存辅助功能权限状态（每次粘贴流程重新检测）
- 不修改菜单栏 popover 的任何行为

## 涉及文件和职责

### 新增文件（6 个：3 生产代码 + 3 测试）

| 文件 | 职责 |
|------|------|
| `ClipMind/Privacy/AccessibilityService.swift` | 辅助功能服务：`CaretLocating` 协议 + `MousePositionProviding` 协议 + `AccessibilityService` 类（权限检测 + caret 定位 + 鼠标位置降级），全部 `#if CLIPMIND_DEV` 包裹 |
| `ClipMind/UI/QuickPaste/PasteSimulator.swift` | 模拟粘贴按键模块：`PasteSimulating` 协议 + `PasteSimulator` 类（仅发送 Cmd+V），全部 `#if CLIPMIND_DEV` 包裹 |
| `ClipMind/UI/QuickPaste/CaretPanelLocator.swift` | caret 附近面板定位：`CaretPanelLocator` 类遵循 `PanelScreenLocating`，全部 `#if CLIPMIND_DEV` 包裹 |
| `ClipMindTests/Privacy/AccessibilityServiceTests.swift` | TC-F1.9-12-01（权限检测不缓存）, TC-F1.9-2-01/02（caret 定位 mock），全部 `#if CLIPMIND_DEV` 包裹 |
| `ClipMindTests/UI/PasteSimulatorTests.swift` | TC-F1.9-SEC-03（仅发送标准粘贴按键），全部 `#if CLIPMIND_DEV` 包裹 |
| `ClipMindTests/UI/CaretPanelLocatorTests.swift` | caret 定位与降级逻辑，全部 `#if CLIPMIND_DEV` 包裹 |

### 修改文件（3 个）

| 文件 | 职责变更 |
|------|---------|
| `project.yml` | 新增 `ClipMind-Dev` Scheme + `CLIPMIND_DEV` 编译条件配置 |
| `ClipMind/UI/QuickPaste/PasteCoordinator.swift` | `init` 新增 `pasteSimulator` 可选参数（`#if CLIPMIND_DEV`）；有权限路径分支调用 `pasteSimulator.simulatePaste()`（`#if CLIPMIND_DEV`），主 Scheme 有权限路径回退到显示浮层 |
| `ClipMind/App/ClipMindApp.swift` | `setupQuickPastePanelController()` 根据 `#if CLIPMIND_DEV` 选择 PanelLocator（CaretPanelLocator vs ScreenCenterPanelLocator）+ 注入 AccessibilityService + PasteSimulator；新增 `--UITEST_FORCE_PERMISSION` 启动参数 |

### 测试用例覆盖说明

- **本 Phase 覆盖**：TC-F1.9-2-01/02（caret 定位 mock）, TC-F1.9-6-01（有权限剪贴板写入 + 面板关闭）, TC-F1.9-10-01（有权限路径粘贴后关闭）, TC-F1.9-12-01（有权限分支降级逻辑）, TC-F1.9-SEC-03（仅发送标准粘贴按键）（共 10 条单元 + UI）
- **延后覆盖**：TC-F1.9-2-01/02（caret 定位真实环境手动验证）, TC-F1.9-6-02（真实插入文本手动验证）, TC-F1.9-12-02（权限撤销真实环境手动验证）标记为 ⏸️ DEFERRED，发布前手动执行

---

## 任务 1：创建 ClipMind-Dev Scheme 与 CLIPMIND_DEV 编译条件

**文件：**
- 修改：`project.yml`
- 测试：无（工程配置任务，通过编译验证）

### 步骤

- [ ] **1.1 编写失败的测试**

本任务是工程配置任务，无单元测试。验证方式为：修改 `project.yml` 后重新生成 Xcode 工程，确认 `ClipMind-Dev` Scheme 存在且主 Scheme `ClipMind` 编译不受影响。

先记录当前 `project.yml` 的 schemes 段落内容，作为对比基线：

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.9-quick-paste-panel
sed -n '/^schemes:/,$p' project.yml
```

预期输出：当前只有 `ClipMind` 一个 Scheme。

- [ ] **1.2 运行测试验证失败**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.9-quick-paste-panel
xcodebuild -list -project ClipMind.xcodeproj 2>&1 | grep -A 20 "Schemes:"
```

预期输出：只有 `ClipMind` 一个 Scheme，没有 `ClipMind-Dev`。

- [ ] **1.3 编写最少实现代码**

修改 `project.yml`，在文件末尾的 `schemes:` 段落之后追加 `ClipMind-Dev` Scheme 配置。

将 `project.yml` 末尾的：

```yaml
schemes:
  ClipMind:
    build:
      targets:
        ClipMind: all
        ClipMindTests: [test]
        ClipMindUITests: [test]
    test:
      targets:
        - ClipMindTests
        - ClipMindUITests
      gatherCoverageData: true
    run:
      config: Debug
    archive:
      config: Release
```

替换为：

```yaml
schemes:
  ClipMind:
    build:
      targets:
        ClipMind: all
        ClipMindTests: [test]
        ClipMindUITests: [test]
    test:
      targets:
        - ClipMindTests
        - ClipMindUITests
      gatherCoverageData: true
    run:
      config: Debug
    archive:
      config: Release
  ClipMind-Dev:
    build:
      targets:
        ClipMind: all
        ClipMindTests: [test]
        ClipMindUITests: [test]
    test:
      targets:
        - ClipMindTests
        - ClipMindUITests
      gatherCoverageData: true
    run:
      config: Debug
    # archive: ClipMind-Dev 仅用于本地验证，不归档发布构建，archive 步骤跳过（AGENTS.md 第 10 节）
```

> **说明**：`ClipMind-Dev` Scheme 复用 `ClipMind` target，通过 target 级别的编译条件（`DebugDev` 配置）区分。`ClipMind-Dev` 仅用于本地验证与技术可行性评估，不归档发布构建，因此 `archive` 步骤跳过（AGENTS.md 第 10 节）。

需要在 target 级别配置 `CLIPMIND_DEV` 编译条件。修改 `project.yml` 的 `targets:` 段落，在 `ClipMind` target 的 `settings` 中添加配置。

找到 `project.yml` 中 `ClipMind` target 的 `settings` 段落（通常在文件前半部分），追加 `CLIPMIND_DEV` 编译条件配置。由于 xcodegen 的 Scheme 无法直接设置编译条件，采用以下方案：

**方案**：创建一个独立的 build configuration `DebugDev`，在其中设置 `SWIFT_ACTIVE_COMPILATION_CONDITIONS` 包含 `CLIPMIND_DEV`。

在 `project.yml` 顶部 `name:` 之后的合适位置（`options:` 或 `settings:` 段落），添加 `configs` 定义：

```yaml
configs:
  Debug: debug
  Release: release
  DebugDev: debug
```

在 `ClipMind` target 的 `settings` 段落中，为 `DebugDev` 配置追加编译条件：

```yaml
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
      configs:
        DebugDev:
          SWIFT_ACTIVE_COMPILATION_CONDITIONS: CLIPMIND_DEV
```

然后修改 `ClipMind-Dev` Scheme 的 `run` 和 `test` 使用 `DebugDev` 配置：

```yaml
  ClipMind-Dev:
    build:
      targets:
        ClipMind: all
        ClipMindTests: [test]
        ClipMindUITests: [test]
    test:
      targets:
        - ClipMindTests
        - ClipMindUITests
      gatherCoverageData: true
      config: DebugDev
    run:
      config: DebugDev
    # archive: ClipMind-Dev 仅用于本地验证，不归档发布构建，archive 步骤跳过（AGENTS.md 第 10 节）
```

> **关键说明**：`DebugDev` 配置基于 `debug` 类型，但额外定义 `SWIFT_ACTIVE_COMPILATION_CONDITIONS: CLIPMIND_DEV`。`ClipMind-Dev` Scheme 的 `run`/`test` 使用 `DebugDev` 配置，确保编译时 `#if CLIPMIND_DEV` 包裹的代码被包含。`ClipMind-Dev` 不归档发布构建（`archive` 步骤跳过），因此无需 release 类型的 `ReleaseDev` 配置。主 Scheme `ClipMind` 仍使用 `Debug`/`Release` 配置，不包含 `CLIPMIND_DEV`，`#if CLIPMIND_DEV` 包裹的代码被排除。

- [ ] **1.4 运行测试验证通过**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.9-quick-paste-panel
xcodegen generate 2>&1 | tail -5
```

预期：`⚙  Generating plists...` + `Created project:`，无错误。

```bash
xcodebuild -list -project ClipMind.xcodeproj 2>&1 | grep -A 20 "Schemes:"
```

预期输出：包含 `ClipMind` 和 `ClipMind-Dev` 两个 Scheme。

验证主 Scheme 编译不受影响：

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.9-quick-paste-panel
xcodebuild build \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10
```

预期：`** BUILD SUCCEEDED **`，主 Scheme 编译成功（此时 `#if CLIPMIND_DEV` 代码尚未添加，编译不受影响）。

- [ ] **1.5 运行 SwiftLint**

```bash
swiftlint lint --strict
```

预期：零违规（`project.yml` 非 Swift 文件，SwiftLint 不检查，但确保现有 Swift 文件无回归）。

- [ ] **1.6 Commit**

```bash
git add project.yml ClipMind.xcodeproj
git commit -m "chore(scheme): add ClipMind-Dev scheme with CLIPMIND_DEV compilation condition"
```

> **注意**：`ClipMind.xcodeproj` 是 xcodegen 生成的产物，通常在 `.gitignore` 中。如果被 gitignore，则只提交 `project.yml`。提交前用 `git status` 确认。

---

## 任务 2：AccessibilityService 辅助功能服务

**文件：**
- 创建：`ClipMind/Privacy/AccessibilityService.swift`
- 测试：`ClipMindTests/Privacy/AccessibilityServiceTests.swift`（新增）

### 步骤

- [ ] **2.1 编写失败的测试**

创建 `ClipMindTests/Privacy/AccessibilityServiceTests.swift`：

```swift
@testable import ClipMind
import AppKit
import XCTest

#if CLIPMIND_DEV
final class AccessibilityServiceTests: XCTestCase
{
    // MARK: - TC-F1.9-12-01 权限检测不缓存（每次调用都重新检测）

    func testIsAccessibilityGranted_DoesNotCache_ChecksEveryTime()
    {
        let provider = MockAXTrustedProvider(granted: false)
        PermissionRequester.axTrustedCheck = { _ in provider.granted }

        let service = AccessibilityService()

        let firstResult = service.isAccessibilityGranted()
        XCTAssertFalse(firstResult, "首次检测应返回 false")

        provider.granted = true
        let secondResult = service.isAccessibilityGranted()
        XCTAssertTrue(secondResult, "权限状态变更后应返回 true（不缓存）")

        provider.granted = false
        let thirdResult = service.isAccessibilityGranted()
        XCTAssertFalse(thirdResult, "权限再次变更后应返回 false（不缓存）")

        // 恢复默认实现
        PermissionRequester.axTrustedCheck = { prompt in
            let options: NSDictionary = [
                "AXTrustedCheckOptionPrompt" as NSString: NSNumber(value: prompt)
            ]
            return AXIsProcessTrustedWithOptions(options as CFDictionary)
        }
    }

    // MARK: - TC-F1.9-2-01 有权限时获取 caret 位置

    func testLocateCaret_ReturnsCaretPosition_WhenAvailable()
    {
        let service = AccessibilityService(caretProvider: MockCaretProvider(caret: NSPoint(x: 300, y: 400)))

        let caret = service.locateCaret()

        XCTAssertNotNil(caret, "有 caret 时应返回坐标")
        XCTAssertEqual(caret?.x, 300, accuracy: 0.01)
        XCTAssertEqual(caret?.y, 400, accuracy: 0.01)
    }

    // MARK: - TC-F1.9-2-02 前台应用无 caret 时降级到鼠标位置

    func testLocateCaret_ReturnsNil_WhenNoCaret()
    {
        let service = AccessibilityService(caretProvider: MockCaretProvider(caret: nil))

        let caret = service.locateCaret()

        XCTAssertNil(caret, "无 caret 时应返回 nil（由调用方降级到鼠标位置）")
    }

    // MARK: - 鼠标位置降级

    func testCurrentMouseLocation_ReturnsNonZeroPoint()
    {
        let service = AccessibilityService(mouseProvider: MockMouseProvider(location: NSPoint(x: 500, y: 600)))

        let location = service.currentMouseLocation()

        XCTAssertEqual(location.x, 500, accuracy: 0.01)
        XCTAssertEqual(location.y, 600, accuracy: 0.01)
    }

    // MARK: - 权限检测调用 PermissionRequester.axTrustedCheck(false) 不弹 TCC

    func testIsAccessibilityGranted_CallsAXTrustedCheckWithFalsePrompt()
    {
        var capturedPrompt: Bool?
        PermissionRequester.axTrustedCheck = { prompt in
            capturedPrompt = prompt
            return false
        }

        let service = AccessibilityService()
        _ = service.isAccessibilityGranted()

        XCTAssertEqual(capturedPrompt, false, "权限检测应传入 prompt: false 不弹 TCC")

        // 恢复默认实现
        PermissionRequester.axTrustedCheck = { prompt in
            let options: NSDictionary = [
                "AXTrustedCheckOptionPrompt" as NSString: NSNumber(value: prompt)
            ]
            return AXIsProcessTrustedWithOptions(options as CFDictionary)
        }
    }

    // MARK: - 测试辅助 Mock

    private final class MockAXTrustedProvider
    {
        var granted: Bool
        init(granted: Bool) { self.granted = granted }
    }

    private final class MockCaretProvider: CaretLocating
    {
        let caret: NSPoint?
        init(caret: NSPoint?) { self.caret = caret }

        func locateCaret() -> NSPoint? { caret }
    }

    private final class MockMouseProvider: MousePositionProviding
    {
        let location: NSPoint
        init(location: NSPoint) { self.location = location }

        func currentMouseLocation() -> NSPoint { location }
    }
}
#endif
```

- [ ] **2.2 运行测试验证失败**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.9-quick-paste-panel
xcodegen generate && xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind-Dev \
  -destination 'platform=macOS' \
  -configuration DebugDev \
  -only-testing ClipMindTests/AccessibilityServiceTests \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：编译失败，报错 `cannot find type 'AccessibilityService' in scope` / `CaretLocating` / `MousePositionProviding`。

> **注意**：必须使用 `-scheme ClipMind-Dev` 和 `-configuration DebugDev`，否则 `#if CLIPMIND_DEV` 包裹的测试类不会被编译。

- [ ] **2.3 编写最少实现代码**

创建 `ClipMind/Privacy/AccessibilityService.swift`：

```swift
import AppKit
import ApplicationServices
import Foundation

#if CLIPMIND_DEV

/// caret 位置定位协议（依赖注入，便于测试 mock）。
///
/// 设计文档第 3.5 节。有权限时获取前台应用 caret 位置用于面板定位。
/// 无 caret 时返回 nil，由调用方降级到鼠标位置。
protocol CaretLocating: AnyObject
{
    /// 获取前台应用当前 caret 位置。
    /// - Returns: caret 坐标（屏幕坐标系），无 caret 时返回 nil
    func locateCaret() -> NSPoint?
}

/// 鼠标位置提供协议（依赖注入，便于测试 mock）。
///
/// 设计文档第 3.5 节。无 caret 时降级到鼠标当前位置。
protocol MousePositionProviding: AnyObject
{
    /// 获取当前鼠标位置（屏幕坐标系）。
    func currentMouseLocation() -> NSPoint
}

/// 辅助功能服务（合规待定，仅 ClipMind-Dev Scheme 编译）。
///
/// 设计文档第 3.5 节 + 第 10.3 节「合规待定」标注。
/// 职责：
/// 1. 运行时查询辅助功能权限状态（不弹 TCC 提示）
/// 2. 有权限时获取前台应用 caret 位置（仅坐标，不读取文本内容）
/// 3. 无 caret 时降级返回鼠标当前位置
///
/// 合规说明：
/// - 使用公开辅助功能 API 查询权限状态（复用 PermissionRequester.axTrustedCheck(false)）
/// - 使用公开辅助功能 API 获取 caret 坐标（AXUIElementCopyAttributeValue）
/// - 使用公开系统事件 API 获取鼠标位置（CGEventCreate + CGEventGetLocation）
/// - 不读取 caret 处的文本内容
/// - 不缓存权限状态（每次粘贴流程重新检测，AC-F1.9-12）
///
/// 遵循 PastePermissionChecking 协议，替代 Phase 3 的 SystemPastePermissionChecker。
final class AccessibilityService: PastePermissionChecking, CaretLocating, MousePositionProviding
{
    private let caretProvider: CaretLocating?
    private let mouseProvider: MousePositionProviding?

    /// - Parameters:
    ///   - caretProvider: caret 定位提供器（测试注入 mock；生产用 nil 表示使用真实 AXUIElement 实现）
    ///   - mouseProvider: 鼠标位置提供器（测试注入 mock；生产用 nil 表示使用真实 CGEvent 实现）
    init(
        caretProvider: CaretLocating? = nil,
        mouseProvider: MousePositionProviding? = nil
    )
    {
        self.caretProvider = caretProvider
        self.mouseProvider = mouseProvider
    }

    // MARK: - PastePermissionChecking

    func isAccessibilityGranted() -> Bool
    {
        // 每次调用都重新检测，不缓存（AC-F1.9-12，设计文档第 7.2 节）
        // prompt: false 不弹 TCC 提示对话框（需求文档第 11.2 节）
        PermissionRequester.axTrustedCheck(false)
    }

    // MARK: - CaretLocating

    func locateCaret() -> NSPoint?
    {
        // 测试 mock 路径
        if let caretProvider = caretProvider
        {
            return caretProvider.locateCaret()
        }

        // 生产路径：使用 AXUIElement 获取前台应用 caret
        return locateCaretViaAccessibilityAPI()
    }

    // MARK: - MousePositionProviding

    func currentMouseLocation() -> NSPoint
    {
        // 测试 mock 路径
        if let mouseProvider = mouseProvider
        {
            return mouseProvider.currentMouseLocation()
        }

        // 生产路径：使用 CGEvent 获取鼠标位置
        return locateMouseViaCGEvent()
    }

    // MARK: - 私有：AXUIElement caret 定位

    /// 通过辅助功能 API 获取前台应用 caret 坐标。
    ///
    /// 实现思路：
    /// 1. 获取前台应用 AXUIElement（NSWorkspace.shared.frontmostApplication）
    /// 2. 获取前台应用 focused UI element
    /// 3. 查询 focused element 的 AXSelectedTextRange 属性
    /// 4. 查询 AXBoundsForRange 属性获取 caret 位置 CGRect
    /// 5. 转换为 NSPoint（屏幕坐标系）
    ///
    /// 无 caret（前台应用无文本输入）时返回 nil。
    private func locateCaretViaAccessibilityAPI() -> NSPoint?
    {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication
        else
        {
            LogCategory.privacy.info("No frontmost application found")
            return nil
        }

        let appElement = AXUIElementCreateApplication(frontmostApp.processIdentifier)

        var focusedElementRef: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElementRef
        )

        guard focusedResult == .success,
              let focusedElement = focusedElementRef
        else
        {
            LogCategory.privacy.info("No focused UI element found")
            return nil
        }

        let focusedAXElement = focusedElement as! AXUIElement

        // 获取 AXSelectedTextRange
        var rangeValueRef: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(
            focusedAXElement,
            kAXSelectedTextRangeAttribute as CFString,
            &rangeValueRef
        )

        guard rangeResult == .success,
              let rangeValue = rangeValueRef
        else
        {
            LogCategory.privacy.info("No selected text range found")
            return nil
        }

        // rangeValue 是 AXValue (CFRange)
        var range = CFRange()
        AXValueGetValue(rangeValue as! AXValue, .cfRange, &range)

        // 获取 AXBoundsForRange
        let boundsValue = AXValueCreate(.cfRange, &range)
        var boundsRef: CFTypeRef?
        let boundsResult = AXUIElementCopyParameterizedAttributeValue(
            focusedAXElement,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            boundsValue!,
            &boundsRef
        )

        guard boundsResult == .success,
              let boundsValue = boundsRef
        else
        {
            LogCategory.privacy.info("No bounds for range found")
            return nil
        }

        // boundsValue 是 AXValue (CGRect)
        var caretBounds = CGRect.zero
        AXValueGetValue(boundsValue as! AXValue, .cgRect, &caretBounds)

        // caret 位置取 CGRect 的左下角（NSPoint，屏幕坐标系）
        // AXUIElement 返回的坐标是屏幕左上角原点，需要转换为 NSPoint（屏幕左下角原点）
        let screenFrame = NSScreen.main?.frame ?? .zero
        let flippedY = screenFrame.height - caretBounds.origin.y
        return NSPoint(x: caretBounds.origin.x, y: flippedY)
    }

    // MARK: - 私有：CGEvent 鼠标位置

    /// 通过 CGEvent 获取当前鼠标位置（公开 API，沙盒内可用）。
    private func locateMouseViaCGEvent() -> NSPoint
    {
        // CGEventCreate(nil) 创建空事件，可获取当前鼠标位置
        if let event = CGEvent(source: nil)
        {
            let location = event.location
            // CGEvent 返回的是全局坐标（屏幕左上角原点），转换为 NSPoint（屏幕左下角原点）
            let screenFrame = NSScreen.main?.frame ?? .zero
            return NSPoint(x: location.x, y: screenFrame.height - location.y)
        }

        // 降级到 NSEvent.mouseLocation
        return NSEvent.mouseLocation
    }
}

#endif
```

- [ ] **2.4 运行测试验证通过**

运行同 2.2 的命令。

预期：`** TEST SUCCEEDED **`，5 个测试方法全部通过。

> **注意**：`testIsAccessibilityGranted_DoesNotCache_ChecksEveryTime` 和 `testIsAccessibilityGranted_CallsAXTrustedCheckWithFalsePrompt` 会临时替换 `PermissionRequester.axTrustedCheck` 闭包，测试末尾恢复默认实现。这是 Phase 3 已建立的模式。

- [ ] **2.5 运行 SwiftLint**

```bash
swiftlint lint --strict
```

预期：零违规。

- [ ] **2.6 Commit**

```bash
git add ClipMind/Privacy/AccessibilityService.swift ClipMindTests/Privacy/AccessibilityServiceTests.swift
git commit -m "feat(accessibility): add AccessibilityService with caret location and mouse fallback"
```

---

## 任务 3：PasteSimulator 模拟粘贴按键模块

**文件：**
- 创建：`ClipMind/UI/QuickPaste/PasteSimulator.swift`
- 测试：`ClipMindTests/UI/PasteSimulatorTests.swift`（新增）

### 步骤

- [ ] **3.1 编写失败的测试**

创建 `ClipMindTests/UI/PasteSimulatorTests.swift`：

```swift
@testable import ClipMind
import XCTest

#if CLIPMIND_DEV
final class PasteSimulatorTests: XCTestCase
{
    // MARK: - TC-F1.9-SEC-03 模拟粘贴仅发送系统标准粘贴按键

    func testSimulatePaste_SendsOnlyStandardPasteKeystroke()
    {
        let mock = MockPasteSimulator()
        let simulator = PasteSimulator(eventSender: mock)

        simulator.simulatePaste()

        XCTAssertEqual(mock.sentKeyCodes.count, 2, "应发送 2 个按键事件（Cmd 按下 + V 按下/释放）")
        // 验证发送的是 Cmd+V（keyCode 9 = V 键）
        XCTAssertTrue(mock.sentKeyCodes.contains(9), "应包含 V 键 keyCode")
        XCTAssertTrue(mock.commandModifierUsed, "应使用 Command 修饰键")
        XCTAssertFalse(mock.otherModifiersUsed, "不应使用其他修饰键（如 Option/Control）")
    }

    // MARK: - 模拟粘贴发送标准 Cmd+V（不发送其他按键序列）

    func testSimulatePaste_DoesNotSendArbitraryKeySequence()
    {
        let mock = MockPasteSimulator()
        let simulator = PasteSimulator(eventSender: mock)

        simulator.simulatePaste()

        // 仅允许 V 键（keyCode 9），不允许其他字母/数字键
        let allowedKeyCodes: Set<Int64> = [9] // V 键
        for keyCode in mock.sentKeyCodes
        {
            XCTAssertTrue(allowedKeyCodes.contains(keyCode), "仅允许 V 键，实际发送 keyCode: \(keyCode)")
        }
    }

    // MARK: - 默认实现使用真实 CGEvent（验证不崩溃）

    func testSimulatePaste_RealEventSender_DoesNotCrash()
    {
        let simulator = PasteSimulator()
        // 验证模拟粘贴按键不抛出异常（真实 CGEvent 发送到前台应用）
        XCTAssertNoThrow(simulator.simulatePaste(), "模拟粘贴按键不应抛出异常")
    }

    // MARK: - 测试辅助 Mock

    private final class MockPasteSimulator: PasteEventSending
    {
        var sentKeyCodes: [Int64] = []
        var commandModifierUsed = false
        var otherModifiersUsed = false

        func sendKeyEvent(keyCode: Int64, keyDown: Bool, withCommand: Bool, withOtherModifiers: Bool)
        {
            sentKeyCodes.append(keyCode)
            if withCommand { commandModifierUsed = true }
            if withOtherModifiers { otherModifiersUsed = true }
        }
    }
}
#endif
```

- [ ] **3.2 运行测试验证失败**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.9-quick-paste-panel
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind-Dev \
  -destination 'platform=macOS' \
  -configuration DebugDev \
  -only-testing ClipMindTests/PasteSimulatorTests \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：编译失败，报错 `cannot find type 'PasteSimulator' in scope` / `PasteEventSending`。

- [ ] **3.3 编写最少实现代码**

创建 `ClipMind/UI/QuickPaste/PasteSimulator.swift`：

```swift
import CoreGraphics
import Foundation

#if CLIPMIND_DEV

/// 粘贴按键事件发送协议（依赖注入，便于测试 mock）。
///
/// 设计文档第 3.6 节。仅发送系统标准粘贴按键（Cmd+V），不发送任意按键序列。
protocol PasteEventSending: AnyObject
{
    /// 发送按键事件。
    /// - Parameters:
    ///   - keyCode: 按键码（V 键 = 9）
    ///   - keyDown: true = 按下，false = 释放
    ///   - withCommand: 是否使用 Command 修饰键
    ///   - withOtherModifiers: 是否使用其他修饰键（Option/Control/Shift）
    func sendKeyEvent(
        keyCode: Int64,
        keyDown: Bool,
        withCommand: Bool,
        withOtherModifiers: Bool
    )
}

/// 模拟粘贴按键模块（合规待定，仅 ClipMind-Dev Scheme 编译）。
///
/// 设计文档第 3.6 节 + 第 10.3 节「合规待定」标注。
/// 职责：接收粘贴流程协调器的委托，模拟系统标准粘贴按键到前台应用。
///
/// 合规说明：
/// - 仅发送系统标准 Cmd+V 按键（keyCode 9 + Command 修饰键）
/// - 不发送任意按键序列（NFR-003 安全性）
/// - 响应用户双击操作触发单次粘贴（非批量自动化）
/// - 使用公开 CGEvent API（CoreGraphics）
final class PasteSimulator
{
    private let eventSender: PasteEventSending?

    /// V 键的 keyCode（macOS 固定值）。
    private static let vKeyCode: Int64 = 9

    /// - Parameter eventSender: 按键事件发送器（测试注入 mock；生产用 nil 表示使用真实 CGEvent 实现）
    init(eventSender: PasteEventSending? = nil)
    {
        self.eventSender = eventSender
    }

    /// 模拟系统标准 Cmd+V 粘贴按键。
    ///
    /// 发送顺序：Cmd 按下 → V 按下 → V 释放 → Cmd 释放。
    /// 仅发送标准粘贴按键，不发送其他按键序列（TC-F1.9-SEC-03）。
    func simulatePaste()
    {
        if let eventSender = eventSender
        {
            // 测试 mock 路径
            sendViaMock(eventSender)
        }
        else
        {
            // 生产路径：使用真实 CGEvent
            sendViaCGEvent()
        }
        LogCategory.ui.info("Paste simulated: Cmd+V sent")
        // test hook：UI 测试启动参数下记录 simulatePaste() 被调用，供 testPermissionGrantedPaste 验证（Phase 4 任务 7）
        if ProcessInfo.processInfo.arguments.contains("--UITEST_QUICK_PASTE_PANEL")
        {
            UserDefaults.standard.set(true, forKey: "UITest_pasteSimulatorCalled")
        }
    }

    // MARK: - 私有

    private func sendViaMock(_ eventSender: PasteEventSending)
    {
        eventSender.sendKeyEvent(keyCode: Self.vKeyCode, keyDown: true, withCommand: true, withOtherModifiers: false)
        eventSender.sendKeyEvent(keyCode: Self.vKeyCode, keyDown: false, withCommand: true, withOtherModifiers: false)
    }

    private func sendViaCGEvent()
    {
        let source = CGEventSource(stateID: .hidSystemState)

        // Cmd 按下 + V 按下
        let keyDown = CGEvent(
            keyboardEventSource: source,
            virtualKey: CGKeyCode(Self.vKeyCode),
            keyDown: true
        )
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cgi)

        // Cmd 释放 + V 释放
        let keyUp = CGEvent(
            keyboardEventSource: source,
            virtualKey: CGKeyCode(Self.vKeyCode),
            keyDown: false
        )
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cgi)
    }
}

#endif
```

- [ ] **3.4 运行测试验证通过**

运行同 3.2 的命令。

预期：`** TEST SUCCEEDED **`，3 个测试方法全部通过。

> **注意**：`testSimulatePaste_RealEventSender_DoesNotCrash` 会发送真实 Cmd+V 到前台应用，测试运行时不要在编辑器中聚焦输入框（避免粘贴干扰）。CI 环境中前台应用是测试 runner，不影响。

- [ ] **3.5 运行 SwiftLint**

```bash
swiftlint lint --strict
```

预期：零违规。

- [ ] **3.6 Commit**

```bash
git add ClipMind/UI/QuickPaste/PasteSimulator.swift ClipMindTests/UI/PasteSimulatorTests.swift
git commit -m "feat(paste-simulator): add PasteSimulator with Cmd+V only keystroke"
```

---

## 任务 4：CaretPanelLocator 面板 caret 定位

**文件：**
- 创建：`ClipMind/UI/QuickPaste/CaretPanelLocator.swift`
- 测试：`ClipMindTests/UI/CaretPanelLocatorTests.swift`（新增）

### 步骤

- [ ] **4.1 编写失败的测试**

创建 `ClipMindTests/UI/CaretPanelLocatorTests.swift`：

```swift
@testable import ClipMind
import AppKit
import XCTest

#if CLIPMIND_DEV
final class CaretPanelLocatorTests: XCTestCase
{
    // MARK: - 有 caret 时面板定位到 caret 附近（距离 ≤ 50px，不遮挡 caret）

    func testLocatePosition_WithCaret_ReturnsPositionNearCaret()
    {
        let caret = NSPoint(x: 500, y: 400)
        let mouse = NSPoint(x: 100, y: 100)
        let locator = CaretPanelLocator(
            accessibilityService: MockAccessibilityService(caret: caret, mouse: mouse, granted: true)
        )

        let position = locator.locatePosition(lastClosedPosition: nil)
        let panelSize = QuickPastePanelController.panelSize

        // 面板应在 caret 附近（距离 ≤ 50px）
        let distanceX = abs(position.x - caret.x)
        let distanceY = abs(position.y - caret.y)
        XCTAssertLessThanOrEqual(distanceX, 50 + panelSize.width, "面板 X 坐标应在 caret 附近")
        XCTAssertLessThanOrEqual(distanceY, 50 + panelSize.height, "面板 Y 坐标应在 caret 附近")
    }

    // MARK: - 无 caret 时降级到鼠标位置

    func testLocatePosition_NoCaret_FallsBackToMouseLocation()
    {
        let mouse = NSPoint(x: 700, y: 800)
        let locator = CaretPanelLocator(
            accessibilityService: MockAccessibilityService(caret: nil, mouse: mouse, granted: true)
        )

        let position = locator.locatePosition(lastClosedPosition: nil)
        let panelSize = QuickPastePanelController.panelSize

        // 面板应在鼠标位置附近
        let distanceX = abs(position.x - mouse.x)
        let distanceY = abs(position.y - mouse.y)
        XCTAssertLessThanOrEqual(distanceX, panelSize.width, "无 caret 时面板应在鼠标位置附近")
        XCTAssertLessThanOrEqual(distanceY, panelSize.height, "无 caret 时面板应在鼠标位置附近")
    }

    // MARK: - 无权限时降级到上次关闭位置

    func testLocatePosition_NoPermission_UsesLastClosedPosition()
    {
        let lastClosed = NSPoint(x: 200, y: 300)
        let locator = CaretPanelLocator(
            accessibilityService: MockAccessibilityService(caret: nil, mouse: NSPoint(x: 999, y: 999), granted: false)
        )

        let position = locator.locatePosition(lastClosedPosition: lastClosed)

        XCTAssertEqual(position.x, lastClosed.x, accuracy: 0.01, "无权限时应使用上次关闭位置")
        XCTAssertEqual(position.y, lastClosed.y, accuracy: 0.01, "无权限时应使用上次关闭位置")
    }

    // MARK: - 无权限且无上次关闭位置时降级到屏幕中央

    func testLocatePosition_NoPermission_NoLastClosed_UsesScreenCenter()
    {
        let locator = CaretPanelLocator(
            accessibilityService: MockAccessibilityService(caret: nil, mouse: NSPoint(x: 999, y: 999), granted: false)
        )

        let position = locator.locatePosition(lastClosedPosition: nil)
        let screenFrame = NSScreen.main?.frame ?? .zero
        let panelSize = QuickPastePanelController.panelSize

        // 面板应在屏幕中央
        let expectedX = screenFrame.midX - panelSize.width / 2.0
        let expectedY = screenFrame.midY - panelSize.height / 2.0
        XCTAssertEqual(position.x, expectedX, accuracy: 1.0, "无权限无上次位置时应使用屏幕中央")
        XCTAssertEqual(position.y, expectedY, accuracy: 1.0, "无权限无上次位置时应使用屏幕中央")
    }

    // MARK: - 面板不遮挡 caret（面板位于 caret 右侧或下方）

    func testLocatePosition_PanelDoesNotOverlapCaret()
    {
        let caret = NSPoint(x: 500, y: 400)
        let locator = CaretPanelLocator(
            accessibilityService: MockAccessibilityService(caret: caret, mouse: NSPoint(x: 100, y: 100), granted: true)
        )

        let position = locator.locatePosition(lastClosedPosition: nil)
        let panelSize = QuickPastePanelController.panelSize
        let panelRect = NSRect(origin: position, size: panelSize)

        // caret 不应在面板矩形内
        XCTAssertFalse(panelRect.contains(caret), "面板不应遮挡 caret")
    }

    // MARK: - 测试辅助 Mock

    private final class MockAccessibilityService: PastePermissionChecking, CaretLocating, MousePositionProviding
    {
        let caret: NSPoint?
        let mouse: NSPoint
        let granted: Bool

        init(caret: NSPoint?, mouse: NSPoint, granted: Bool)
        {
            self.caret = caret
            self.mouse = mouse
            self.granted = granted
        }

        func isAccessibilityGranted() -> Bool { granted }
        func locateCaret() -> NSPoint? { caret }
        func currentMouseLocation() -> NSPoint { mouse }
    }
}
#endif
```

- [ ] **4.2 运行测试验证失败**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.9-quick-paste-panel
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind-Dev \
  -destination 'platform=macOS' \
  -configuration DebugDev \
  -only-testing ClipMindTests/CaretPanelLocatorTests \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：编译失败，报错 `cannot find type 'CaretPanelLocator' in scope`。

- [ ] **4.3 编写最少实现代码**

创建 `ClipMind/UI/QuickPaste/CaretPanelLocator.swift`：

```swift
import AppKit
import Foundation

#if CLIPMIND_DEV

/// caret 附近面板定位器（合规待定，仅 ClipMind-Dev Scheme 编译）。
///
/// 设计文档第 3.1 节 + 第 4.1 节序列图 + 第 7.1 节。
/// 职责：根据权限状态与 caret 可用性计算面板显示坐标。
///
/// 定位优先级：
/// 1. 有权限 + 有 caret → caret 附近（偏移 50px，不遮挡 caret）
/// 2. 有权限 + 无 caret → 鼠标当前位置附近
/// 3. 无权限 + 有上次关闭位置 → 上次关闭位置
/// 4. 无权限 + 无上次关闭位置 → 屏幕中央
///
/// 遵循 PanelScreenLocating 协议（Phase 1 定义），替代 ScreenCenterPanelLocator。
final class CaretPanelLocator: PanelScreenLocating
{
    /// caret 附近的偏移量（像素），面板位于 caret 右下方，不遮挡 caret。
    private static let caretOffset: CGFloat = 50

    private let accessibilityService: PastePermissionChecking & CaretLocating & MousePositionProviding

    /// - Parameter accessibilityService: 辅助功能服务（提供权限检测 + caret 定位 + 鼠标位置）
    init(accessibilityService: PastePermissionChecking & CaretLocating & MousePositionProviding)
    {
        self.accessibilityService = accessibilityService
    }

    func locatePosition(lastClosedPosition: NSPoint?) -> NSPoint
    {
        let panelSize = QuickPastePanelController.panelSize
        let screenFrame = NSScreen.main?.frame ?? .zero

        // 有权限时尝试 caret 定位
        if accessibilityService.isAccessibilityGranted()
        {
            if let caret = accessibilityService.locateCaret()
            {
                // caret 附近：右下方偏移 50px，不遮挡 caret
                let position = NSPoint(
                    x: caret.x + Self.caretOffset,
                    y: caret.y - Self.caretOffset - panelSize.height
                )
                return clampToScreen(position, panelSize: panelSize, screenFrame: screenFrame)
            }
            else
            {
                // 无 caret 时降级到鼠标位置
                let mouse = accessibilityService.currentMouseLocation()
                let position = NSPoint(
                    x: mouse.x - panelSize.width / 2.0,
                    y: mouse.y - panelSize.height / 2.0
                )
                return clampToScreen(position, panelSize: panelSize, screenFrame: screenFrame)
            }
        }

        // 无权限时使用上次关闭位置或屏幕中央
        if let lastClosed = lastClosedPosition
        {
            return lastClosed
        }

        // 屏幕中央
        return NSPoint(
            x: screenFrame.midX - panelSize.width / 2.0,
            y: screenFrame.midY - panelSize.height / 2.0
        )
    }

    // MARK: - 私有

    /// 将面板位置限制在屏幕可视范围内（避免超出屏幕边界）。
    private func clampToScreen(position: NSPoint, panelSize: NSSize, screenFrame: NSRect) -> NSPoint
    {
        let clampedX = max(screenFrame.minX, min(position.x, screenFrame.maxX - panelSize.width))
        let clampedY = max(screenFrame.minY, min(position.y, screenFrame.maxY - panelSize.height))
        return NSPoint(x: clampedX, y: clampedY)
    }
}

#endif
```

- [ ] **4.4 运行测试验证通过**

运行同 4.2 的命令。

预期：`** TEST SUCCEEDED **`，5 个测试方法全部通过。

- [ ] **4.5 运行 SwiftLint**

```bash
swiftlint lint --strict
```

预期：零违规。

- [ ] **4.6 Commit**

```bash
git add ClipMind/UI/QuickPaste/CaretPanelLocator.swift ClipMindTests/UI/CaretPanelLocatorTests.swift
git commit -m "feat(quick-paste): add CaretPanelLocator with caret, mouse, and screen center fallback"
```

---

## 任务 5：PasteCoordinator 扩展有权限路径分支

**文件：**
- 修改：`ClipMind/UI/QuickPaste/PasteCoordinator.swift`
- 测试：`ClipMindTests/UI/PasteCoordinatorTests.swift`（追加测试）

### 步骤

- [ ] **5.1 编写失败的测试**

在 `ClipMindTests/UI/PasteCoordinatorTests.swift` 末尾追加（在最后一个 `}` 之前）：

```swift
    // MARK: - Phase 4：有权限路径测试（仅 ClipMind-Dev Scheme 编译）

    #if CLIPMIND_DEV

    // MARK: - TC-F1.9-6-01 有权限时双击自动粘贴（剪贴板写入 + 面板关闭 + 模拟粘贴）

    func testHandlePaste_WithPermission_WritesClipboard_ClosesPanel_SimulatesPaste()
    {
        let permissionChecker = MockPermissionChecker(granted: true)
        let writer = MockClipboardWriter()
        let panel = MockPanelCloser()
        let overlay = MockOverlayShower()
        let simulator = MockPasteSimulator()
        let coordinator = PasteCoordinator(
            permissionChecker: permissionChecker,
            clipboardWriter: writer,
            panelCloser: panel,
            overlayShower: overlay,
            pasteSimulator: simulator
        )

        let clip = ClipItem.makeText("文本", contentType: .other, sourceApp: "com.test", sourceAppName: "Test")
        coordinator.handlePaste(clip: clip)

        XCTAssertTrue(writer.writeCalled, "有权限时应写入剪贴板")
        XCTAssertEqual(writer.writtenText, "文本")
        XCTAssertTrue(panel.closeCalled, "有权限时应关闭面板")
        XCTAssertTrue(simulator.simulateCalled, "有权限时应模拟粘贴按键")
        XCTAssertFalse(overlay.showCalled, "有权限时不应显示降级浮层")
    }

    // MARK: - TC-F1.9-10-01 粘贴后面板自动关闭（有权限路径）

    func testHandlePaste_WithPermission_ClosesPanelBeforeSimulatingPaste()
    {
        let permissionChecker = MockPermissionChecker(granted: true)
        let writer = MockClipboardWriter()
        let panel = MockPanelCloser()
        let overlay = MockOverlayShower()
        let simulator = MockPasteSimulator()
        let coordinator = PasteCoordinator(
            permissionChecker: permissionChecker,
            clipboardWriter: writer,
            panelCloser: panel,
            overlayShower: overlay,
            pasteSimulator: simulator
        )

        let clip = ClipItem.makeText("文本", contentType: .other, sourceApp: "com.test", sourceAppName: "Test")
        coordinator.handlePaste(clip: clip)

        // 验证关闭顺序：先关闭面板，再模拟粘贴（设计文档第 7.4 节）
        XCTAssertTrue(panel.closeCalled)
        XCTAssertTrue(simulator.simulateCalled)
        XCTAssertLessThan(panel.callOrder, simulator.callOrder, "应先关闭面板再模拟粘贴")
    }

    // MARK: - TC-F1.9-12-01 权限被撤销时自动降级（有权限→无权限切换）

    func testHandlePaste_PermissionRevoked_SwitchesFromSimulateToOverlay()
    {
        let permissionChecker = MockPermissionChecker(granted: true)
        let writer = MockClipboardWriter()
        let panel = MockPanelCloser()
        let overlay = MockOverlayShower()
        let simulator = MockPasteSimulator()
        let coordinator = PasteCoordinator(
            permissionChecker: permissionChecker,
            clipboardWriter: writer,
            panelCloser: panel,
            overlayShower: overlay,
            pasteSimulator: simulator
        )

        let clip = ClipItem.makeText("文本", contentType: .other, sourceApp: "com.test", sourceAppName: "Test")

        // 第一次：有权限（模拟粘贴）
        coordinator.handlePaste(clip: clip)
        XCTAssertTrue(simulator.simulateCalled, "有权限时应模拟粘贴")
        XCTAssertFalse(overlay.showCalled, "有权限时不应显示浮层")

        // 重置 mock
        simulator.reset()
        overlay.reset()
        writer.reset()
        panel.reset()

        // 第二次：权限被撤销（显示浮层）
        permissionChecker.granted = false
        coordinator.handlePaste(clip: clip)

        XCTAssertFalse(simulator.simulateCalled, "权限撤销后不应模拟粘贴")
        XCTAssertTrue(overlay.showCalled, "权限撤销后应显示降级浮层")
    }

    // MARK: - 有权限但无 pasteSimulator 时回退到显示浮层（主 Scheme 行为模拟）

    func testHandlePaste_WithPermission_NoSimulator_FallsBackToOverlay()
    {
        let permissionChecker = MockPermissionChecker(granted: true)
        let writer = MockClipboardWriter()
        let panel = MockPanelCloser()
        let overlay = MockOverlayShower()
        // 不传入 pasteSimulator（模拟主 Scheme 编译时无 PasteSimulator 的情况）
        let coordinator = PasteCoordinator(
            permissionChecker: permissionChecker,
            clipboardWriter: writer,
            panelCloser: panel,
            overlayShower: overlay,
            pasteSimulator: nil
        )

        let clip = ClipItem.makeText("文本", contentType: .other, sourceApp: "com.test", sourceAppName: "Test")
        coordinator.handlePaste(clip: clip)

        XCTAssertTrue(writer.writeCalled, "应写入剪贴板")
        XCTAssertTrue(panel.closeCalled, "应关闭面板")
        XCTAssertTrue(overlay.showCalled, "无 pasteSimulator 时有权限路径应回退到显示浮层")
    }

    // MARK: - TC-F1.9-12-01 权限检测不缓存（有权限路径每次重新检测）

    func testHandlePaste_WithPermission_ChecksPermissionEveryTime()
    {
        let permissionChecker = MockPermissionChecker(granted: true)
        let writer = MockClipboardWriter()
        let panel = MockPanelCloser()
        let overlay = MockOverlayShower()
        let simulator = MockPasteSimulator()
        let coordinator = PasteCoordinator(
            permissionChecker: permissionChecker,
            clipboardWriter: writer,
            panelCloser: panel,
            overlayShower: overlay,
            pasteSimulator: simulator
        )

        let clip = ClipItem.makeText("文本", contentType: .other, sourceApp: "com.test", sourceAppName: "Test")

        coordinator.handlePaste(clip: clip)
        let firstCount = permissionChecker.checkCallCount

        coordinator.handlePaste(clip: clip)
        let secondCount = permissionChecker.checkCallCount

        XCTAssertEqual(secondCount, firstCount + 1, "每次粘贴流程都应重新检测权限")
    }

    // MARK: - Phase 4 测试辅助 Mock

    private final class MockPasteSimulator: PasteSimulating
    {
        private(set) var simulateCalled = false
        private(set) var callOrder = 0

        func simulatePaste()
        {
            simulateCalled = true
            PasteCoordinatorTests.sharedCallSequence += 1
            callOrder = PasteCoordinatorTests.sharedCallSequence
        }

        func reset()
        {
            simulateCalled = false
            callOrder = 0
        }
    }

    #endif
```

- [ ] **5.2 运行测试验证失败**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.9-quick-paste-panel
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind-Dev \
  -destination 'platform=macOS' \
  -configuration DebugDev \
  -only-testing ClipMindTests/PasteCoordinatorTests \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：编译失败，报错 `Extra argument 'pasteSimulator' in call`（PasteCoordinator.init 尚未支持 pasteSimulator 参数）和 `cannot find type 'PasteSimulating' in scope`。

- [ ] **5.3 编写最少实现代码**

**第一步**：修改 `ClipMind/UI/QuickPaste/PasteSimulator.swift`，在 `#if CLIPMIND_DEV` 块内追加 `PasteSimulating` 协议定义（任务 3 已创建文件，此处追加协议）。

在 `PasteSimulator.swift` 的 `#if CLIPMIND_DEV` 块内，`PasteEventSending` 协议定义之后追加：

```swift
/// 粘贴模拟协议（依赖注入，便于测试 mock）。
///
/// 设计文档第 3.6 节。PasteSimulator 默认实现遵循此协议。
protocol PasteSimulating: AnyObject
{
    /// 模拟系统标准粘贴按键。
    func simulatePaste()
}

/// 使 PasteSimulator 遵循 PasteSimulating 协议。
extension PasteSimulator: PasteSimulating {}
```

**第二步**：修改 `ClipMind/UI/QuickPaste/PasteCoordinator.swift`，扩展 init 支持 pasteSimulator + 有权限路径分支。

将现有的 `PasteCoordinator` 类定义替换为：

```swift
/// 粘贴流程协调器。
///
/// 设计文档第 3.3 节 + 第 4.2/4.3/4.4 节序列图。
/// 职责：接收双击/回车事件 → 检测权限 → 写剪贴板 → 关闭面板 → 分支有权限/无权限路径。
///
/// Phase 3 实现无权限降级分支（显示浮层）。
/// Phase 4 扩展有权限分支（模拟粘贴按键），通过 `pasteSimulator` 依赖实现。
///
/// 编译条件说明：
/// - 主 Scheme `ClipMind`（无 CLIPMIND_DEV）：`pasteSimulator` 参数类型为 `Any?`（默认 nil），不调用模拟粘贴，有权限路径回退到显示浮层
/// - ClipMind-Dev Scheme（有 CLIPMIND_DEV）：`pasteSimulator` 传入 `PasteSimulating?`，有权限路径通过 `as? PasteSimulating` 类型转换后调用模拟粘贴
///
/// 关键约束：
/// - 每次粘贴流程重新检测权限，不缓存（AC-F1.9-12）
/// - 图片/文件路径类型不写入剪贴板、不关闭面板（FR-012）
/// - 写入失败时不关闭面板、不显示浮层（错误处理）
/// - 日志不输出剪贴板原文（NFR-003）
final class PasteCoordinator
{
    private let permissionChecker: PastePermissionChecking
    private let clipboardWriter: ClipboardWriting
    private let panelCloser: PanelClosing
    private let overlayShower: OverlayShowing

    /// 模拟粘贴按键依赖。主 Scheme 下为 nil（不模拟粘贴，回退到显示浮层）；
    /// ClipMind-Dev Scheme 下传入 `PasteSimulating?`（通过 `#if CLIPMIND_DEV` 内的 `as? PasteSimulating` 类型转换访问）。
    /// 使用 `Any?` 避免条件编译包裹 init 参数导致的脆弱语法（前置逗号独占一行）。
    private let pasteSimulator: Any?

    init(
        permissionChecker: PastePermissionChecking,
        clipboardWriter: ClipboardWriting,
        panelCloser: PanelClosing,
        overlayShower: OverlayShowing,
        pasteSimulator: Any? = nil
    )
    {
        self.permissionChecker = permissionChecker
        self.clipboardWriter = clipboardWriter
        self.panelCloser = panelCloser
        self.overlayShower = overlayShower
        self.pasteSimulator = pasteSimulator
    }

    /// 处理粘贴请求（由 QuickPasteViewModel.onPasteTriggered 调用）。
    /// - Parameter clip: 用户双击/回车选中的剪贴项
    func handlePaste(clip: ClipItem)
    {
        // 图片/文件路径类型不进入粘贴流程
        guard case .text(let text) = clip.content
        else
        {
            LogCategory.ui.info("Paste skipped: non-text content type")
            return
        }

        // 运行时检测权限（不缓存）
        let hasPermission = permissionChecker.isAccessibilityGranted()
        LogCategory.app.info("Paste flow started, permission granted: \(hasPermission, privacy: .public)")

        // 写入剪贴板（仅文本）
        let writeSuccess = clipboardWriter.write(text: text)
        guard writeSuccess
        else
        {
            LogCategory.app.error("Clipboard write failed, abort paste flow")
            return
        }

        // 关闭快速粘贴面板
        panelCloser.closePanel()

        if hasPermission
        {
            #if CLIPMIND_DEV
            if let simulator = pasteSimulator as? PasteSimulating
            {
                // 有权限路径：模拟粘贴按键（设计文档第 7.4 节，面板关闭后再模拟粘贴）
                simulator.simulatePaste()
                LogCategory.app.info("Paste flow: permission granted path, paste simulated")
                return
            }
            #endif
            // 主 Scheme 或无 pasteSimulator 时：有权限路径回退到显示浮层（合规回退）
            overlayShower.showOverlay()
            LogCategory.app.info("Paste flow: permission granted path (compliance fallback, overlay shown)")
        }
        else
        {
            // 无权限降级路径：显示浮层
            overlayShower.showOverlay()
            LogCategory.app.info("Paste flow: degraded path, overlay shown")
        }
    }
}
```

> **关键设计说明**：
> - `pasteSimulator` 属性类型为 `Any?`（非条件编译），主 Scheme 与 ClipMind-Dev Scheme 都保留该 init 参数（默认 nil），避免条件编译包裹 init 参数的脆弱语法
> - `#if CLIPMIND_DEV` 仅包裹有权限路径的 `as? PasteSimulating` 类型转换与模拟粘贴调用，主 Scheme 编译时该分支为空，回退到显示浮层
> - 主 Scheme 行为：有权限和无权限路径都显示浮层（与 Phase 3 一致，合规无风险）
> - ClipMind-Dev Scheme 行为：有权限路径模拟粘贴，无权限路径显示浮层

- [ ] **5.4 运行测试验证通过**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.9-quick-paste-panel
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind-Dev \
  -destination 'platform=macOS' \
  -configuration DebugDev \
  -only-testing ClipMindTests/PasteCoordinatorTests \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：`** TEST SUCCEEDED **`，Phase 3 + Phase 4 全部测试通过（12 个测试方法）。

同时验证主 Scheme 编译不受影响（Phase 3 测试仍通过）：

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.9-quick-paste-panel
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindTests/PasteCoordinatorTests \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：`** TEST SUCCEEDED **`，Phase 3 的 7 个测试方法通过（Phase 4 的 5 个测试方法被 `#if CLIPMIND_DEV` 排除，不编译）。

- [ ] **5.5 运行 SwiftLint**

```bash
swiftlint lint --strict
```

预期：零违规。

- [ ] **5.6 Commit**

```bash
git add ClipMind/UI/QuickPaste/PasteCoordinator.swift ClipMind/UI/QuickPaste/PasteSimulator.swift ClipMindTests/UI/PasteCoordinatorTests.swift
git commit -m "feat(paste-coordinator): add permission-granted path with paste simulation under CLIPMIND_DEV"
```

---

## 任务 6：AppDelegate 根据编译条件切换 PanelLocator + 注入 AccessibilityService

**文件：**
- 修改：`ClipMind/App/ClipMindApp.swift`
- 测试：`ClipMindTests/UI/PasteCoordinatorTests.swift`（不修改，已覆盖逻辑层）

### 步骤

- [ ] **6.1 编写失败的测试**

本任务修改 AppDelegate 的初始化逻辑，无直接单元测试（AppDelegate 初始化涉及 UI 生命周期）。验证方式为：修改后编译通过 + UI 测试验证有权限路径行为。

先记录当前 `setupQuickPastePanelController()` 方法的权限检测器和 PanelLocator 选择逻辑，作为对比基线：

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.9-quick-paste-panel
grep -n "permissionChecker\|ScreenCenterPanelLocator\|SystemPastePermissionChecker" ClipMind/App/ClipMindApp.swift
```

预期输出：Phase 3 任务 6/7 中 `SystemPastePermissionChecker()` 和 `ScreenCenterPanelLocator()` 的调用位置。

- [ ] **6.2 运行测试验证失败**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.9-quick-paste-panel
xcodebuild build \
  -project ClipMind.xcodeproj \
  -scheme ClipMind-Dev \
  -destination 'platform=macOS' \
  -configuration DebugDev \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10
```

预期：编译成功（Phase 4 任务 5 已修改 PasteCoordinator，AppDelegate 尚未注入 pasteSimulator，但 `pasteSimulator` 有默认值 nil，编译不报错）。此时 ClipMind-Dev Scheme 编译成功，但运行时有权限路径不会模拟粘贴（因为 pasteSimulator 为 nil）。

- [ ] **6.3 编写最少实现代码**

修改 `ClipMind/App/ClipMindApp.swift` 的 `setupQuickPastePanelController()` 方法，根据 `#if CLIPMIND_DEV` 选择 PanelLocator + 注入 AccessibilityService + PasteSimulator。

将现有的 `setupQuickPastePanelController()` 方法替换为：

```swift
    /// 初始化快速粘贴面板控制器与粘贴流程协调器（F1.9）。
    private func setupQuickPastePanelController()
    {
        #if CLIPMIND_DEV
        // ClipMind-Dev Scheme：使用 CaretPanelLocator + AccessibilityService + PasteSimulator
        let accessibilityService = AccessibilityService()
        let locator = CaretPanelLocator(accessibilityService: accessibilityService)

        // UI 测试启动参数：强制无权限
        let permissionChecker: PastePermissionChecking
        if CommandLine.arguments.contains("--UITEST_FORCE_NO_PERMISSION")
        {
            permissionChecker = UITestNoPermissionChecker()
        }
        else if CommandLine.arguments.contains("--UITEST_FORCE_PERMISSION")
        {
            permissionChecker = UITestPermissionChecker()
        }
        else
        {
            permissionChecker = accessibilityService
        }
        #else
        // 主 Scheme：使用 ScreenCenterPanelLocator + SystemPastePermissionChecker
        let locator = ScreenCenterPanelLocator()

        let permissionChecker: PastePermissionChecking
        if CommandLine.arguments.contains("--UITEST_FORCE_NO_PERMISSION")
        {
            permissionChecker = UITestNoPermissionChecker()
        }
        else
        {
            permissionChecker = SystemPastePermissionChecker()
        }
        #endif

        let panelController = QuickPastePanelController(screenLocator: locator)
        quickPastePanelController = panelController

        // UI 测试启动参数：超时 1 秒加速
        let settings: QuickPasteSettings
        if CommandLine.arguments.contains("--UITEST_OVERLAY_TIMEOUT_1S")
        {
            let testDefaults = UserDefaults.standard
            testDefaults.set(1.0, forKey: "F1.9.quickPaste.overlayDuration")
            settings = QuickPasteSettings(defaults: testDefaults)
        }
        else if CommandLine.arguments.contains("--UITEST_OVERLAY_TIMEOUT_3S")
        {
            let testDefaults = UserDefaults.standard
            testDefaults.set(3.0, forKey: "F1.9.quickPaste.overlayDuration")
            settings = QuickPasteSettings(defaults: testDefaults)
        }
        else
        {
            settings = QuickPasteSettings()
        }

        // UI 测试启动参数：1 秒后模拟消费
        let consumerWatcher: ClipboardConsumerWatcherProtocol
        if CommandLine.arguments.contains("--UITEST_SIMULATE_CONSUMPTION_AFTER_1S")
        {
            consumerWatcher = UITestSimulatedConsumerWatcher(delay: 1.0)
        }
        else
        {
            consumerWatcher = ClipboardConsumerWatcher()
        }

        let overlayLocator = ScreenCenterOverlayLocator()
        let overlayController = PasteOverlayController(
            consumerWatcher: consumerWatcher,
            timerScheduler: OverlayTimer(),
            settings: settings,
            screenLocator: overlayLocator
        )

        #if CLIPMIND_DEV
        let coordinator = PasteCoordinator(
            permissionChecker: permissionChecker,
            clipboardWriter: ClipboardWriter(),
            panelCloser: panelController,
            overlayShower: overlayController,
            pasteSimulator: PasteSimulator()
        )
        #else
        let coordinator = PasteCoordinator(
            permissionChecker: permissionChecker,
            clipboardWriter: ClipboardWriter(),
            panelCloser: panelController,
            overlayShower: overlayController
        )
        #endif
        pasteCoordinator = coordinator

        if CommandLine.arguments.contains("--UITEST_QUICK_PASTE_PANEL")
        {
            if CommandLine.arguments.contains("--UITEST_PREPOPULATE_IMAGE_AND_FILEPATH")
            {
                prepopulateImageAndFilePathForTesting()
            }
            let contentController = makeQuickPasteContentController(coordinator: coordinator)
            panelController.showPanel(contentController: contentController)
        }
    }
```

在 `AppDelegate` 类末尾（`UITestSimulatedConsumerWatcher` 之后）追加 UI 测试辅助类：

```swift
    #if CLIPMIND_DEV
    /// UI 测试专用：始终返回有权限的权限检测器。
    private final class UITestPermissionChecker: PastePermissionChecking
    {
        func isAccessibilityGranted() -> Bool { true }
    }
    #endif
```

> **关键设计说明**：
> - `#if CLIPMIND_DEV` 区分 PanelLocator（CaretPanelLocator vs ScreenCenterPanelLocator）和权限检测器（AccessibilityService vs SystemPastePermissionChecker）
> - ClipMind-Dev Scheme 注入 `PasteSimulator()` 到 PasteCoordinator，启用有权限路径模拟粘贴
> - 主 Scheme 不注入 pasteSimulator（init 无此参数），有权限路径回退到显示浮层
> - 新增 `--UITEST_FORCE_PERMISSION` 启动参数（仅 ClipMind-Dev Scheme 有效），用于 UI 测试有权限路径

- [ ] **6.4 运行测试验证通过**

验证 ClipMind-Dev Scheme 编译通过：

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.9-quick-paste-panel
xcodebuild build \
  -project ClipMind.xcodeproj \
  -scheme ClipMind-Dev \
  -destination 'platform=macOS' \
  -configuration DebugDev \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10
```

预期：`** BUILD SUCCEEDED **`。

验证主 Scheme 编译通过（合规验证）：

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.9-quick-paste-panel
xcodebuild build \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10
```

预期：`** BUILD SUCCEEDED **`，主 Scheme 编译成功（`#if CLIPMIND_DEV` 代码被排除，不引用 AccessibilityService / PasteSimulator / CaretPanelLocator）。

验证主 Scheme 测试无回归：

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.9-quick-paste-panel
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindTests/PasteCoordinatorTests \
  -only-testing ClipMindTests/QuickPastePanelControllerTests \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：`** TEST SUCCEEDED **`，主 Scheme 测试通过（Phase 3 测试 + Phase 1 PanelController 测试无回归）。

- [ ] **6.5 运行 SwiftLint**

```bash
swiftlint lint --strict
```

预期：零违规。

- [ ] **6.6 Commit**

```bash
git add ClipMind/App/ClipMindApp.swift
git commit -m "feat(quick-paste): wire AccessibilityService and PasteSimulator under CLIPMIND_DEV"
```

---

## 任务 7：UI 测试 - 有权限路径粘贴 + 权限撤销降级

**文件：**
- 修改：`ClipMindUITests/QuickPasteOverlayUITests.swift`（追加 UI 测试）

### 步骤

- [ ] **7.1 编写失败的测试**

在 `ClipMindUITests/QuickPasteOverlayUITests.swift` 末尾追加：

```swift
    // MARK: - Phase 4：有权限路径 UI 测试（仅 ClipMind-Dev Scheme 运行）

    #if CLIPMIND_DEV

    // MARK: - TC-F1.9-6-01 有权限时双击自动粘贴（剪贴板写入 + 面板关闭）

    func testPermissionGrantedPaste_WritesClipboard_ClosesPanel()
    {
        // 重置 test hook：PasteSimulator 调用标记
        UserDefaults.standard.set(false, forKey: "UITest_pasteSimulatorCalled")
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREPOPULATE_SAMPLE_AND_REAL",
            "--UITEST_QUICK_PASTE_PANEL",
            "--UITEST_FORCE_PERMISSION"
        ]
        app.launch()

        // 记录剪贴板初始内容
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("__INITIAL__", forType: .string)
        let initialCount = pasteboard.changeCount

        let firstRow = app.descendants(matching: .any)["quickPasteRow_0_selected"].firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))

        firstRow.doubleClick()

        // 验证剪贴板已写入（changeCount 增加，NSPasteboard 无 string 属性，用 changeCount 判定消费）
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "changeCount > \(initialCount)"),
            object: pasteboard
        )
        wait(for: [expectation], timeout: 3.0)

        let clipboardContent = pasteboard.string(forType: .string)
        XCTAssertNotNil(clipboardContent, "剪贴板应已写入")
        XCTAssertNotEqual(clipboardContent, "__INITIAL__", "剪贴板应已写入新内容")

        // 验证面板已关闭（quickPasteRow 不再存在）
        let panelClosedExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == NO"),
            object: firstRow
        )
        wait(for: [panelClosedExpectation], timeout: 3.0)
        XCTAssertFalse(firstRow.exists, "有权限粘贴后面板应关闭")

        // UI 测试验证剪贴板写入 + 面板关闭 + PasteSimulator.simulatePaste() 被调用（通过 test hook）；
        // 真实粘贴到外部应用在手动验收（备忘录 caret 位置插入文本，录屏保存）。
        // test hook：PasteSimulator.simulatePaste() 在 --UITEST_QUICK_PASTE_PANEL 启动参数下写入
        // UserDefaults["UITest_pasteSimulatorCalled"]，UI 测试读取验证
        let pasteSimulatorCalled = UserDefaults.standard.bool(forKey: "UITest_pasteSimulatorCalled")
        XCTAssertTrue(pasteSimulatorCalled, "应调用 PasteSimulator 模拟粘贴")
    }

    // MARK: - TC-F1.9-10-01 粘贴后面板自动关闭（有权限路径）

    func testPermissionGrantedPaste_PanelClosesAfterPaste()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREPOPULATE_SAMPLE_AND_REAL",
            "--UITEST_QUICK_PASTE_PANEL",
            "--UITEST_FORCE_PERMISSION"
        ]
        app.launch()

        let firstRow = app.descendants(matching: .any)["quickPasteRow_0_selected"].firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))

        firstRow.doubleClick()

        // 验证面板关闭（quickPasteRow 消失）
        let panelClosedExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == NO"),
            object: firstRow
        )
        wait(for: [panelClosedExpectation], timeout: 3.0)
        XCTAssertFalse(firstRow.exists, "有权限路径粘贴后面板应自动关闭")

        // 验证降级浮层未显示（有权限路径不显示浮层）
        let overlayMessage = app.descendants(matching: .any)["pasteOverlayMessage"].firstMatch
        XCTAssertFalse(overlayMessage.exists, "有权限路径不应显示降级浮层")
    }

    // MARK: - TC-F1.9-12-01 权限撤销时自动降级（UI 层验证降级路径切换）

    func testPermissionRevoked_FallsBackFromSimulateToOverlay()
    {
        // 第一次：有权限（模拟粘贴，不显示浮层）
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREPOPULATE_SAMPLE_AND_REAL",
            "--UITEST_QUICK_PASTE_PANEL",
            "--UITEST_FORCE_PERMISSION"
        ]
        app.launch()

        let firstRow = app.descendants(matching: .any)["quickPasteRow_0_selected"].firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
        firstRow.doubleClick()

        // 验证有权限路径：面板关闭 + 无浮层
        let panelClosedExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == NO"),
            object: firstRow
        )
        wait(for: [panelClosedExpectation], timeout: 3.0)

        let overlayMessage = app.descendants(matching: .any)["pasteOverlayMessage"].firstMatch
        XCTAssertFalse(overlayMessage.exists, "有权限路径不应显示浮层")

        app.terminate()

        // 第二次：无权限（降级路径，显示浮层）
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREPOPULATE_SAMPLE_AND_REAL",
            "--UITEST_QUICK_PASTE_PANEL",
            "--UITEST_FORCE_NO_PERMISSION",
            "--UITEST_OVERLAY_TIMEOUT_1S"
        ]
        app.launch()

        let firstRow2 = app.descendants(matching: .any)["quickPasteRow_0_selected"].firstMatch
        XCTAssertTrue(firstRow2.waitForExistence(timeout: 5))
        firstRow2.doubleClick()

        let overlayMessage2 = app.descendants(matching: .any)["pasteOverlayMessage"].firstMatch
        XCTAssertTrue(overlayMessage2.waitForExistence(timeout: 3), "无权限时应显示降级浮层")

        // 等待浮层超时消失
        let disappearExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == NO"),
            object: overlayMessage2
        )
        wait(for: [disappearExpectation], timeout: 5.0)
    }

    // MARK: - TC-F1.9-2-01/02 caret 定位（XCUITest 仅验证面板出现，真实 caret 定位手动验证）

    func testCaretLocation_PanelAppears_WithPermission()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREPOPULATE_SAMPLE_AND_REAL",
            "--UITEST_QUICK_PASTE_PANEL",
            "--UITEST_FORCE_PERMISSION"
        ]
        app.launch()

        // 验证面板出现
        let firstRow = app.descendants(matching: .any)["quickPasteRow_0_selected"].firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5), "有权限时面板应出现（caret 定位或鼠标位置降级）")

        // CI 验证面板出现且位置非屏幕中央（区分 caret 定位/鼠标位置降级 与 屏幕中央降级）；
        // 真实 caret 偏移验证在手动验收（备忘录中点击光标 + 截图对比面板位置，距离 ≤ 50px）。
        // 注意：本测试文件顶部需 `import AppKit` 以使用 NSScreen。
        // CI 限制：若 CI 中 caret/鼠标定位失败回退屏幕中央，此断言可能失败，需手动验收补充真实 caret 偏移证据。
        let panelFrame = app.windows.containing(.textField, identifier: "quickPasteSearchField").firstMatch.frame
        let screenFrame = NSScreen.main?.frame ?? .zero
        XCTAssertFalse(
            abs(panelFrame.midY - screenFrame.midY) <= 50,
            "有权限时面板应定位在 caret/鼠标附近，而非屏幕中央降级位置"
        )
    }

    #endif
```

> **注意**：UI 测试文件中需要 `import AppKit` 以使用 `NSPasteboard`。在文件顶部确认已导入。

- [ ] **7.2 运行测试验证失败**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.9-quick-paste-panel
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind-Dev \
  -destination 'platform=macOS' \
  -configuration DebugDev \
  -only-testing ClipMindUITests/QuickPasteOverlayUITests/testPermissionGrantedPaste_WritesClipboard_ClosesPanel \
  -only-testing ClipMindUITests/QuickPasteOverlayUITests/testPermissionGrantedPaste_PanelClosesAfterPaste \
  -only-testing ClipMindUITests/QuickPasteOverlayUITests/testPermissionRevoked_FallsBackFromSimulateToOverlay \
  -only-testing ClipMindUITests/QuickPasteOverlayUITests/testCaretLocation_PanelAppears_WithPermission \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：测试可能通过（任务 6 已实现 `--UITEST_FORCE_PERMISSION` 启动参数和 PasteSimulator 注入）。若失败，检查 `--UITEST_FORCE_PERMISSION` 启动参数是否被正确识别。

> **注意**：`testPermissionGrantedPaste_WritesClipboard_ClosesPanel` 验证剪贴板写入，但 PasteSimulator 会发送真实 Cmd+V 到前台应用，可能导致测试 runner 粘贴内容。这是预期行为，不影响测试断言（测试只验证剪贴板内容和面板关闭）。

- [ ] **7.3 编写最少实现代码**

本任务的实现已在任务 6 中完成（`--UITEST_FORCE_PERMISSION` 启动参数 + PasteSimulator 注入）。若 7.2 测试失败，检查以下点：

1. `ClipMindUITests/QuickPasteOverlayUITests.swift` 顶部是否有 `import AppKit`（使用 NSPasteboard 需要）
2. `--UITEST_FORCE_PERMISSION` 启动参数在 `setupQuickPastePanelController()` 中是否被正确识别（任务 6 已实现）
3. ClipMind-Dev Scheme 的 UI 测试 target 是否使用 `DebugDev` 配置

若 `import AppKit` 缺失，在文件顶部追加：

```swift
import AppKit
import XCTest
```

- [ ] **7.4 运行测试验证通过**

运行同 7.2 的命令。

预期：`** TEST SUCCEEDED **`，4 个 UI 测试通过。

> **注意**：`testCaretLocation_PanelAppears_WithPermission` 仅验证面板出现，不验证 caret 定位准确性（caret 定位需真实环境手动验证，标记为 ⏸️ DEFERRED）。

- [ ] **7.5 运行 SwiftLint**

```bash
swiftlint lint --strict
```

预期：零违规。

- [ ] **7.6 运行 Phase 4 全量测试（回归验证）**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.9-quick-paste-panel
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind-Dev \
  -destination 'platform=macOS' \
  -configuration DebugDev \
  -only-testing ClipMindTests/AccessibilityServiceTests \
  -only-testing ClipMindTests/PasteSimulatorTests \
  -only-testing ClipMindTests/CaretPanelLocatorTests \
  -only-testing ClipMindTests/PasteCoordinatorTests \
  -only-testing ClipMindTests/ClipboardWriterTests \
  -only-testing ClipMindTests/ClipboardConsumerWatcherTests \
  -only-testing ClipMindTests/PasteOverlayControllerTests \
  -only-testing ClipMindTests/QuickPasteSettingsTests \
  -only-testing ClipMindTests/QuickPastePanelControllerTests \
  -only-testing ClipMindTests/QuickPasteViewTests \
  -only-testing ClipMindUITests/QuickPasteOverlayUITests \
  -only-testing ClipMindUITests/QuickPastePanelUITests \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：`** TEST SUCCEEDED **`，Phase 4 全部测试通过 + Phase 1/2/3 无回归。

同时验证主 Scheme 全量测试通过（合规验证）：

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.9-quick-paste-panel
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：`** TEST SUCCEEDED **`，主 Scheme 全量测试通过（Phase 1/2/3 测试 + Phase 4 中 `#if CLIPMIND_DEV` 排除的测试不编译）。

- [ ] **7.7 Commit**

```bash
git add ClipMindUITests/QuickPasteOverlayUITests.swift
git commit -m "test(quick-paste): add UI tests for permission-granted paste and revocation fallback"
```

---

## UI 证据任务

> **证据保存约定（Phase 4）**
>
> - **截图路径模板**：`docs/planning/P0/F1/screenshots/F1.9/phase4-ACx-场景描述.png`
> - **录屏路径模板**：`docs/planning/P0/F1/recordings/F1.9/phase4-ACx-场景描述.mov`
> - **保存规则**：
>   1. XCUITest 通过后，运行该测试用例时通过 `XCUIScreenshot` 附件捕获截图，保存到上述截图路径（文件名见各条目「证据保存」）。
>   2. 涉及真实环境交互的条目（标「手动验证」），发布前手动执行并录屏，保存到上述录屏路径。
>   3. 路径中 `phase4` 为 Phase 编号，`ACx` 为对应验收条件编号，`场景描述` 用中文简述场景。
>   4. 截图/录屏文件提交到仓库，作为发布前人工审查证据。
>   5. Phase 4 的 XCUITest 仅在 `ClipMind-Dev` Scheme 下运行（`#if CLIPMIND_DEV`），截图证据对应标注。

### UI-AC-F1.9-6-01：有权限时双击自动粘贴（剪贴板写入 + 面板关闭）

**对应 AC**：AC-F1.9-6
**对应测试**：`QuickPasteOverlayUITests.testPermissionGrantedPaste_WritesClipboard_ClosesPanel`（仅 ClipMind-Dev Scheme 运行）
**证据方式**：XCUITest 自动化（通过 `--UITEST_FORCE_PERMISSION` 启动参数强制有权限，双击文本行验证剪贴板写入 + 面板关闭 + 无降级浮层）+ 单元测试 `PasteCoordinatorTests.testHandlePaste_WithPermission_WritesClipboard_ClosesPanel_SimulatesPaste`（验证写入剪贴板 + 关闭面板 + 模拟粘贴）
**证据保存**：
- 截图：`docs/planning/P0/F1/screenshots/F1.9/phase4-AC6-有权限自动粘贴.png`（ClipMind-Dev Scheme XCUITest 通过后捕获）

### UI-AC-F1.9-10-01：粘贴后面板自动关闭（有权限路径）

**对应 AC**：AC-F1.9-10
**对应测试**：`QuickPasteOverlayUITests.testPermissionGrantedPaste_PanelClosesAfterPaste`（仅 ClipMind-Dev Scheme 运行）
**证据方式**：XCUITest 自动化（双击文本行验证面板关闭 + 无降级浮层）+ 单元测试 `PasteCoordinatorTests.testHandlePaste_WithPermission_ClosesPanelBeforeSimulatingPaste`（验证关闭顺序：先关闭面板再模拟粘贴）
**证据保存**：
- 截图：`docs/planning/P0/F1/screenshots/F1.9/phase4-AC10-有权限面板关闭.png`（ClipMind-Dev Scheme XCUITest 通过后捕获）

### UI-AC-F1.9-12-01：权限撤销时自动降级（有权限→无权限切换）

**对应 AC**：AC-F1.9-12
**对应测试**：`QuickPasteOverlayUITests.testPermissionRevoked_FallsBackFromSimulateToOverlay`（仅 ClipMind-Dev Scheme 运行）
**证据方式**：XCUITest 自动化（第一次 `--UITEST_FORCE_PERMISSION` 验证有权限路径无浮层，第二次 `--UITEST_FORCE_NO_PERMISSION` 验证降级路径显示浮层）+ 单元测试 `PasteCoordinatorTests.testHandlePaste_PermissionRevoked_SwitchesFromSimulateToOverlay`（验证权限撤销后从模拟粘贴切换到显示浮层）
**证据保存**：
- 截图：`docs/planning/P0/F1/screenshots/F1.9/phase4-AC12-权限撤销降级.png`（ClipMind-Dev Scheme XCUITest 通过后捕获）
- 录屏：`docs/planning/P0/F1/recordings/F1.9/phase4-AC12-权限撤销降级.mov`（手动验收真实权限撤销场景，发布前录制）

### UI-AC-F1.9-2-01：caret 定位（面板出现验证）

**对应 AC**：AC-F1.9-2
**对应测试**：`QuickPasteOverlayUITests.testCaretLocation_PanelAppears_WithPermission`（仅 ClipMind-Dev Scheme 运行，仅验证面板出现）+ 手动验证（caret 定位准确性需真实环境手动验证，标记 ⏸️ DEFERRED）
**证据方式**：XCUITest 自动化验证面板出现 + 单元测试 `CaretPanelLocatorTests.testLocatePosition_WithCaret_ReturnsPositionNearCaret`（验证 caret 附近定位逻辑）+ 手动验证（发布前在备忘录中点击光标，按快捷键验证面板出现在 caret 附近）
**证据保存**：
- 截图：`docs/planning/P0/F1/screenshots/F1.9/phase4-AC2-caret定位.png`（ClipMind-Dev Scheme XCUITest 通过后捕获）
- 录屏：`docs/planning/P0/F1/recordings/F1.9/phase4-AC2-caret定位.mov`（手动验收真实 caret 定位准确性，发布前录制，对应 ⏸️ DEFERRED 项）

---

## 合规风险评估

### 合规风险：高（合规待定）

Phase 4 的有权限路径（方案1）标注「合规待定」（设计文档第 10.3 节）。所有有权限路径代码通过 `#if CLIPMIND_DEV` 编译条件隔离：

| 模块 | 编译条件 | 使用的 API | 合规性 |
|------|---------|-----------|--------|
| AccessibilityService（权限检测） | `#if CLIPMIND_DEV` | `PermissionRequester.axTrustedCheck(false)` | 公开 API，仅查询不弹 TCC |
| AccessibilityService（caret 定位） | `#if CLIPMIND_DEV` | `AXUIElementCopyAttributeValue` + `AXUIElementCopyParameterizedAttributeValue` | 公开辅助功能 API，仅获取坐标不读取文本 |
| AccessibilityService（鼠标位置） | `#if CLIPMIND_DEV` | `CGEventCreate` + `CGEventGetLocation` / `NSEvent.mouseLocation` | 公开系统事件 API |
| PasteSimulator | `#if CLIPMIND_DEV` | `CGEvent(keyboardEventSource:virtualKey:keyDown:)` + `CGEvent.post(tap:)` | 公开 CoreGraphics API，仅发送 Cmd+V |
| CaretPanelLocator | `#if CLIPMIND_DEV` | 复用 AccessibilityService | 公开 API |
| PasteCoordinator（模拟粘贴调用） | `#if CLIPMIND_DEV` | 调用 `PasteSimulator.simulatePaste()` | 公开 API |
| AppDelegate（PanelLocator 切换） | `#if CLIPMIND_DEV` | 选择 CaretPanelLocator vs ScreenCenterPanelLocator | 公开 API |

### 主 Scheme `ClipMind` 合规状态

主 Scheme `ClipMind`（无 `CLIPMIND_DEV`）的 Phase 4 行为：

1. **不编译** AccessibilityService / PasteSimulator / CaretPanelLocator（`#if CLIPMIND_DEV` 排除）
2. **不编译** PasteCoordinator 的 `pasteSimulator` 属性和 init 参数
3. **不编译** PasteCoordinator 有权限路径的模拟粘贴调用
4. **行为与 Phase 3 一致**：有权限和无权限路径都显示降级浮层（合规回退）
5. **使用** ScreenCenterPanelLocator + SystemPastePermissionChecker（Phase 3 实现）

主 Scheme 完全合规：纯沙盒内实现，无私有 API，不绕过沙盒，不缓存权限，不弹 TCC，不输出剪贴板原文。

### ClipMind-Dev Scheme 合规状态

ClipMind-Dev Scheme（有 `CLIPMIND_DEV`）的 Phase 4 行为：

1. **编译** AccessibilityService / PasteSimulator / CaretPanelLocator
2. **编译** PasteCoordinator 的 `pasteSimulator` 属性和 init 参数
3. **编译** PasteCoordinator 有权限路径的模拟粘贴调用
4. **有权限路径**：写入剪贴板 + 关闭面板 + 模拟 Cmd+V 粘贴按键
5. **无权限路径**：写入剪贴板 + 关闭面板 + 显示降级浮层
6. **使用** CaretPanelLocator + AccessibilityService

ClipMind-Dev Scheme 仅用于本地验证与技术可行性评估，不进入 App Store 发布构建。

### 合规回退方案

若 App Store 审核拒绝有权限路径（方案1）：

1. 主 Scheme `ClipMind` 已自动回退（`#if CLIPMIND_DEV` 排除有权限路径代码）
2. 主 Scheme 行为与 Phase 3 一致（所有粘贴流程走降级浮层路径）
3. ClipMind-Dev Scheme 保留有权限路径实现，供未来合规方案验证
4. 在提交信息中说明合规方案
5. 在设计文档第 10.3 节记录审核结果

### 关键合规约束遵守

1. **不弹 TCC 提示对话框**：`AccessibilityService.isAccessibilityGranted()` 调用 `PermissionRequester.axTrustedCheck(false)`，`prompt: false` 不弹 TCC（需求文档第 11.2 节）
2. **不缓存权限状态**：`PasteCoordinator.handlePaste(clip:)` 每次调用都重新检测权限（AC-F1.9-12，设计文档第 7.2 节）
3. **不读取 caret 处的文本内容**：`AccessibilityService.locateCaretViaAccessibilityAPI()` 仅获取 caret 坐标（CGRect），不读取 `AXSelectedText` 属性（设计文档第 10.3 节审核备注）
4. **不发送任意按键序列**：`PasteSimulator.simulatePaste()` 仅发送 Cmd+V（keyCode 9 + Command 修饰键），不发送其他按键（NFR-003，设计文档第 10.3 节审核备注）
5. **不输出剪贴板原文**：所有日志仅记录元数据（NFR-003）
6. **不用 sleep 等待异步**：所有异步操作使用 DispatchSourceTimer 或回调（CODING_STANDARDS）
7. **响应单次用户操作**：模拟粘贴仅在用户双击/回车时触发一次，非批量自动化（设计文档第 10.3 节审核备注）

---

## 合并基线

Phase 4 完成后应满足：

1. `swiftlint lint --strict` 零违规
2. ClipMind-Dev Scheme `xcodebuild test` 全量通过（Phase 4 新增测试 + Phase 1/2/3 无回归）
3. 主 Scheme `ClipMind` `xcodebuild test` 全量通过（Phase 1/2/3 测试 + Phase 4 中 `#if CLIPMIND_DEV` 排除的测试不编译）
4. 主 Scheme `xcodebuild build` 编译成功（合规验证：`#if CLIPMIND_DEV` 代码被排除）
5. ClipMind-Dev Scheme `xcodebuild build` 编译成功（有权限路径代码被包含）
6. 7 个任务全部 commit，每个 commit 的 SwiftLint 已通过
7. 文档同步：在 `docs/planning/P0/F1/historys/` 追加 `2026-07-23-F1.9-Phase4-Accessibility路径完成.md`

**关键回归点**：
- Phase 3 的 `PasteCoordinatorTests`（验证 `#if CLIPMIND_DEV` 包裹的测试在主 Scheme 被排除，Phase 3 测试仍通过）
- Phase 3 的 `PasteOverlayControllerTests`（验证降级浮层行为无回归）
- Phase 1 的 `QuickPastePanelControllerTests`（验证 `showPanel(contentController:)` 默认参数不破坏现有调用）
- 菜单栏 popover 的 `PopoverUITests` 必须全通过
- 主 Scheme 编译无 `cannot find type 'AccessibilityService'` 等错误（验证 `#if CLIPMIND_DEV` 正确隔离）

---

## 手动验收（发布前补充）

1. **有权限路径真实粘贴**（TC-F1.9-6-02，⏸️ DEFERRED）：
   - 在备忘录中点击光标定位 caret
   - 按全局快捷键呼出快速粘贴面板
   - 双击某文本行
   - 验证备忘录 caret 位置插入该行文本
   - 录屏保存到 `docs/planning/P0/F1/recordings/F1.9/phase4-AC6-真实粘贴.mov`

2. **caret 定位准确性**（TC-F1.9-2-01，⏸️ DEFERRED）：
   - 在备忘录中点击光标定位 caret
   - 按全局快捷键
   - 截图记录面板位置与 caret 位置
   - 验证面板出现在 caret 附近（距离 ≤ 50px，不遮挡 caret）

3. **无 caret 降级到鼠标位置**（TC-F1.9-2-02，⏸️ DEFERRED）：
   - 切换到访达（无 caret）
   - 移动鼠标到某位置
   - 按全局快捷键
   - 验证面板出现在鼠标当前位置附近

4. **权限撤销自动降级**（TC-F1.9-12-02，⏸️ DEFERRED）：
   - 在系统设置中撤销辅助功能权限
   - 触发粘贴流程
   - 验证自动走降级路径（显示降级浮层）

5. **模拟粘贴仅发送 Cmd+V**（TC-F1.9-SEC-03 真实环境验证）：
   - 在备忘录中双击文本行
   - 验证仅插入剪贴板内容，不触发其他操作（如菜单打开、快捷键冲突）

6. **日志不输出剪贴板原文**（TC-F1.9-SEC-01）：
   - 触发有权限路径粘贴
   - 收集控制台日志
   - 验证日志仅记录元数据（"Paste simulated: Cmd+V sent"），不包含剪贴板原文

7. **合规验证**（TC-F1.9-COMP-01）：
   - 主 Scheme `ClipMind` 构建产物提交 App Store 审核前，确认：
     - 无权限降级路径（Phase 1-3）使用沙盒内公开 API
     - 有权限路径（Phase 4）代码被 `#if CLIPMIND_DEV` 排除，不编译
     - 设计文档第 10.3 节「合规待定」标注完整
     - 审核备注模板已准备

---

## 版本记录

| 版本 | 日期 | 变更说明 |
|------|------|---------|
| v1.0 | 2026-07-23 | 初始版本，Phase 4 Accessibility 路径，7 任务 42 TDD 步骤，4 UI 证据任务，覆盖 AC-F1.9-2, AC-F1.9-6, AC-F1.9-10 有权限路径, AC-F1.9-12 真实环境, TC-F1.9-SEC-03，合规高风险（方案1标注「合规待定」，`#if CLIPMIND_DEV` 隔离有权限路径代码，主 Scheme 保持 Phase 3 行为完全合规） |
| v1.1 | 2026-07-23 | 修订（Fix 7/9/10/17/18/15）：testSimulatePaste 改 XCTAssertNoThrow；project.yml 删除无效 macroTargets 字段 + archive 步骤跳过说明；PasteCoordinator init 改 pasteSimulator: Any? 非条件编译 + handlePaste 用 if let 解包；testCaretLocation 加位置断言（验证非屏幕中央）；PasteSimulator test hook 写 UserDefaults + testPermissionGrantedPaste 验证调用 + 手动验收录屏路径；UI 证据任务补充证据保存路径 |
| v1.2 | 2026-07-23 | 修复第二轮 check-plan 发现的 8 项必须修复项（文件计数、Fix 10 行为一致性、UI 测试 import/identifier/谓词） |
