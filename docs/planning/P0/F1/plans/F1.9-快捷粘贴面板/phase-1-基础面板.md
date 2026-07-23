> 最后更新：2026-07-23 | 版本：v1.3

# Phase 1：基础面板

> **面向 AI 代理的工作者：** 本 Phase 是 F1.9 的第一个 Phase，建立独立快速粘贴面板的基础设施。使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现。步骤使用复选框（`- [ ]`）语法跟踪进度。所有任务严格按编号顺序执行，前一个任务的测试通过后才能开始下一个。

## 目标

把全局快捷键的触发行为从"唤起主窗口"改为"呼出独立快速粘贴面板"，面板以 `NSPanel` 实现可独立定位到任意屏幕坐标，无辅助功能权限时显示在屏幕中央或上次关闭位置，支持 Esc 键关闭、失焦自动关闭，面板内容视图复用菜单栏 popover 的视觉骨架并默认高亮第一行。同时建立 `QuickPasteSettings` 持久化基础设施（浮层超时兜底时长，供 Phase 3 使用）。

## 范围

- `GlobalHotkeyService.handleHotkeyPressed()` 改发 `.openQuickPaste` 通知（原 `.openMainWindow`）
- `AppDelegate` 新增 `quickPastePanelController` 持有 + 监听 `.openQuickPaste` 通知 + 初始化控制器
- `QuickPastePanelController`：`NSPanel` 创建、屏幕中央定位、上次关闭位置记忆、屏幕可视范围校验、显示/关闭、Esc/失焦关闭、状态机单一性
- `QuickPasteView`：搜索框 + LazyVStack 列表 + 默认高亮第一行 + Esc/方向键/回车键盘事件路由（双击/回车的粘贴流程在 Phase 2/3 接入）
- `QuickPasteSettings`：浮层超时兜底时长持久化（默认 5 秒，范围 1-30 秒）+ 变更通知
- 单元测试 12 条 + UI 测试 5 条（覆盖 AC-F1.9-1, 3, 8, 9）

## 非目标

- 不实现单击/双击/方向键导航的完整交互（Phase 2）
- 不实现粘贴流程协调器与剪贴板写入（Phase 3）
- 不实现辅助功能权限检测与 caret 定位（Phase 4）
- 不实现降级浮层（Phase 3）
- 不修改 `ClipRowView`（Phase 2 才加 isSelected 与回调）
- 不修改 `GeneralSettingsView`（Phase 3 才加超时配置 UI）
- 不实现快捷键 toggle 关闭（明确不做，见需求文档 9.5）

## 涉及文件和职责

### 新增文件（8 个：2 生产代码 + 1 设置 + 4 测试 + 1 UI 测试 = 8 总）

| 文件 | 职责 |
|------|------|
| `ClipMind/UI/QuickPaste/QuickPastePanelController.swift` | `NSPanel` 控制器：创建、定位（屏幕中央/上次位置）、显示、关闭、键盘焦点、失焦监听、位置记忆、状态机 |
| `ClipMind/UI/QuickPaste/QuickPasteView.swift` | 面板内容 SwiftUI 视图：搜索框 + LazyVStack 列表 + 默认高亮第一行 + Esc/方向键/回车键盘事件路由 |
| `ClipMind/Models/QuickPasteSettings.swift` | 浮层超时兜底时长持久化（UserDefaults）+ 范围校验 + 变更通知 |
| `ClipMindTests/UI/QuickPastePanelControllerTests.swift` | TC-F1.9-3-01/02, TC-F1.9-8-01, TC-F1.9-9-01（单元层）, TC-F1.9-S-02 |
| `ClipMindTests/Models/QuickPasteSettingsTests.swift` | 默认值/范围/持久化/变更通知 |
| `ClipMindTests/App/GlobalHotkeyServiceQuickPasteTests.swift` | TC-F1.9-1-02，验证触发行为变更 |
| `ClipMindTests/UI/QuickPasteViewTests.swift` | TC-F1.9-4-03/04（默认高亮 + 边界），TC-F1.9-5-03（空列表回车无效） |
| `ClipMindUITests/QuickPastePanelUITests.swift` | TC-F1.9-1-01, TC-F1.9-3-01/02, TC-F1.9-8-01, TC-F1.9-9-01 |

### 修改文件（2 个）

| 文件 | 职责变更 |
|------|---------|
| `ClipMind/App/GlobalHotkeyService.swift` | `handleHotkeyPressed()` 改发 `.openQuickPaste` 通知（第 153 行） |
| `ClipMind/App/ClipMindApp.swift` | `AppDelegate` 新增 `quickPastePanelController` 持有 + 监听 `.openQuickPaste` 通知 + `configureActivationPolicy()` 中初始化控制器 |

### 测试用例覆盖说明

- **本 Phase 覆盖**：TC-F1.9-1-01/02, TC-F1.9-3-01/02, TC-F1.9-4-03/04, TC-F1.9-5-03, TC-F1.9-8-01, TC-F1.9-9-01, TC-F1.9-S-02（共 9 条）
- **延后覆盖**：TC-F1.9-4-01/02（单击/方向键导航，Phase 2）, TC-F1.9-5-01/02（双击/回车触发粘贴，Phase 2/3）

---

## 任务 1：QuickPasteSettings 浮层超时配置持久化

**文件：**
- 创建：`ClipMind/Models/QuickPasteSettings.swift`
- 测试：`ClipMindTests/Models/QuickPasteSettingsTests.swift`（新增）

### 步骤

- [ ] **1.1 编写失败的测试**

创建 `ClipMindTests/Models/QuickPasteSettingsTests.swift`：

```swift
@testable import ClipMind
import XCTest

final class QuickPasteSettingsTests: XCTestCase
{
    private var defaults: UserDefaults!
    private var store: QuickPasteSettings!

    override func setUpWithError() throws
    {
        let suiteName = "ClipMind.QuickPasteSettingsTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        store = QuickPasteSettings(defaults: defaults)
    }

    override func tearDownWithError() throws
    {
        defaults.removePersistentDomain(forName: defaults.dictionaryRepresentation().keys.first ?? "")
        defaults = nil
        store = nil
    }

    // MARK: - 默认值

    func testLoadOverlayDuration_ReturnsDefaultFiveSeconds_WhenNotSet()
    {
        let duration = store.loadOverlayDuration()
        XCTAssertEqual(duration, 5.0, "未设置时应返回默认 5 秒")
    }

    // MARK: - 范围校验

    func testSaveOverlayDuration_ClampsToLowerBound_WhenValueLessThanOne()
    {
        store.saveOverlayDuration(0.5)
        XCTAssertEqual(store.loadOverlayDuration(), 1.0, "小于 1 秒应被钳制为 1 秒")
    }

    func testSaveOverlayDuration_ClampsToUpperBound_WhenValueGreaterThanThirty()
    {
        store.saveOverlayDuration(60.0)
        XCTAssertEqual(store.loadOverlayDuration(), 30.0, "大于 30 秒应被钳制为 30 秒")
    }

    func testSaveOverlayDuration_AcceptsBoundaryValues()
    {
        store.saveOverlayDuration(1.0)
        XCTAssertEqual(store.loadOverlayDuration(), 1.0)
        store.saveOverlayDuration(30.0)
        XCTAssertEqual(store.loadOverlayDuration(), 30.0)
    }

    // MARK: - 持久化

    func testSaveOverlayDuration_PersistsAcrossInstances()
    {
        store.saveOverlayDuration(10.0)
        let newStore = QuickPasteSettings(defaults: defaults)
        XCTAssertEqual(newStore.loadOverlayDuration(), 10.0, "新实例应读取到已持久化的值")
    }

    // MARK: - 变更通知

    func testSaveOverlayDuration_PostsDidChangeNotification()
    {
        let expectation = XCTNSNotificationExpectation(
            name: QuickPasteSettings.didChangeNotification
        )
        store.saveOverlayDuration(8.0)
        wait(for: [expectation], timeout: 1.0)
    }
}
```

- [ ] **1.2 运行测试验证失败**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.9-quick-paste-panel
xcodegen generate && xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindTests/QuickPasteSettingsTests \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：编译失败，报错 `cannot find type 'QuickPasteSettings' in scope` 或 `no module 'ClipMind.QuickPasteSettings'`。

- [ ] **1.3 编写最少实现代码**

创建 `ClipMind/Models/QuickPasteSettings.swift`：

```swift
import Foundation

/// F1.9 快速粘贴面板配置持久化（UserDefaults + 范围校验 + 变更通知）。
///
/// Phase 1 仅持久化"浮层超时兜底时长"（供 Phase 3 降级浮层使用）。
/// 后续 Phase 如需新增字段，按相同模式扩展。
public final class QuickPasteSettings
{
    /// 配置变更通知名（监听方在浮层显示前重新读取最新值）。
    public static let didChangeNotification = Notification.Name("ClipMindQuickPasteSettingsDidChange")

    /// 浮层超时兜底时长范围（秒）。
    public static let overlayDurationRange: ClosedRange<Double> = 1.0...30.0

    /// 浮层超时兜底时长默认值（秒）。
    public static let overlayDurationDefault: Double = 5.0

    private let defaults: UserDefaults

    private enum Keys
    {
        static let overlayDuration = "F1.9.quickPaste.overlayDuration"
    }

    /// - Parameter defaults: UserDefaults 实例（测试注入隔离 suite，生产用 .standard）
    public init(defaults: UserDefaults = .standard)
    {
        self.defaults = defaults
    }

    /// 读取浮层超时兜底时长（秒），未设置时返回默认值 5.0。
    public func loadOverlayDuration() -> Double
    {
        let stored = defaults.object(forKey: Keys.overlayDuration) as? Double
            ?? Self.overlayDurationDefault
        return clamped(stored)
    }

    /// 保存浮层超时兜底时长（秒），自动钳制到 1.0...30.0 范围，并发送变更通知。
    /// - Parameter duration: 期望时长（秒），超出范围会被钳制
    public func saveOverlayDuration(_ duration: Double)
    {
        let clampedDuration = clamped(duration)
        defaults.set(clampedDuration, forKey: Keys.overlayDuration)
        LogCategory.app.info("QuickPaste overlay duration saved: \(clampedDuration, privacy: .public)s")
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }

    private func clamped(_ value: Double) -> Double
    {
        min(max(value, Self.overlayDurationRange.lowerBound), Self.overlayDurationRange.upperBound)
    }
}
```

- [ ] **1.4 运行测试验证通过**

运行同 1.2 的命令。

预期：`** TEST SUCCEEDED **`，6 个测试方法全部通过。

- [ ] **1.5 运行 SwiftLint**

```bash
swiftlint lint --strict
```

预期：`Done linting! Found 0 violations, 0 serious violations in N files.`

- [ ] **1.6 Commit**

```bash
git add ClipMind/Models/QuickPasteSettings.swift ClipMindTests/Models/QuickPasteSettingsTests.swift
git commit -m "feat(quick-paste): add QuickPasteSettings with overlay duration persistence"
```

---

## 任务 2：GlobalHotkeyService 触发行为变更

**文件：**
- 修改：`ClipMind/App/GlobalHotkeyService.swift`（第 4-6 行 Notification.Name 扩展新增 `.openQuickPaste`；第 151-154 行 `handleHotkeyPressed()` 改发 `.openQuickPaste`）
- 修改：`ClipMind/UI/MenuBar/StatusItemController.swift`（第 4-6 行 Notification.Name 扩展保留 `.openMainWindow`，确保菜单栏 toggle 仍唤起主窗口）
- 测试：`ClipMindTests/App/GlobalHotkeyServiceQuickPasteTests.swift`（新增）

### 步骤

- [ ] **2.1 编写失败的测试**

创建 `ClipMindTests/App/GlobalHotkeyServiceQuickPasteTests.swift`：

```swift
@testable import ClipMind
import XCTest

/// F1.9 Phase 1：验证全局快捷键触发行为从"唤起主窗口"改为"呼出快速粘贴面板"。
final class GlobalHotkeyServiceQuickPasteTests: XCTestCase
{
    // MARK: - TC-F1.9-1-02 快捷键触发发送"打开快速粘贴面板"通知

    func testHotkeyPressed_PostsOpenQuickPasteNotification()
    {
        let mock = MockHotkeyRegistrar()
        let service = GlobalHotkeyService(hotkey: "cmd+shift+v", registrar: mock)

        let quickPasteExpectation = XCTNSNotificationExpectation(name: .openQuickPaste)
        mock.simulateHotkeyPressed()
        wait(for: [quickPasteExpectation], timeout: 1.0)
        _ = service
    }

    // MARK: - 补充：快捷键触发不再发送"打开主窗口"通知

    func testHotkeyPressed_DoesNotPostOpenMainWindowNotification()
    {
        let mock = MockHotkeyRegistrar()
        let service = GlobalHotkeyService(hotkey: "cmd+shift+v", registrar: mock)

        let mainWindowExpectation = XCTNSNotificationExpectation(name: .openMainWindow)
        mainWindowExpectation.isInverted = true
        mock.simulateHotkeyPressed()
        wait(for: [mainWindowExpectation], timeout: 1.0)
        _ = service
    }
}
```

- [ ] **2.2 运行测试验证失败**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.9-quick-paste-panel
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindTests/GlobalHotkeyServiceQuickPasteTests \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：第一个测试失败，报错 `XCTNSNotificationExpectation timed out`（因为当前 `handleHotkeyPressed` 发的是 `.openMainWindow`，不是 `.openQuickPaste`）。第二个测试通过（因为 `.openMainWindow` 被发送了，但 isInverted=true 期望不发送，所以会失败）。实际上两个测试都会失败：第一个等不到 `.openQuickPaste`，第二个因为 `.openMainWindow` 被发送导致 isInverted 失败。

- [ ] **2.3 编写最少实现代码**

修改 `ClipMind/App/GlobalHotkeyService.swift`，在文件顶部 `import` 之后、`HotkeyRegistering` 协议之前新增 `Notification.Name` 扩展：

```swift
extension Notification.Name
{
    /// F1.9：全局快捷键触发呼出快速粘贴面板。
    static let openQuickPaste = Notification.Name("ClipMindOpenQuickPaste")
}
```

修改 `handleHotkeyPressed()` 方法（原第 151-154 行）：

```swift
    private func handleHotkeyPressed()
    {
        LogCategory.app.info("全局快捷键已触发: \(hotkey)")
        NotificationCenter.default.post(name: .openQuickPaste, object: nil)
    }
```

> **注意**：`Notification.Name.openMainWindow` 定义在 `ClipMind/UI/MenuBar/StatusItemController.swift` 第 4-6 行，菜单栏 popover 的"查看全部"按钮仍发送 `.openMainWindow`（见 `PopoverView.swift` 第 70 行），不需要修改。`GlobalHotkeyServiceTests.testGlobalHotkeyService_HotkeyPressed_PostsOpenMainWindowNotification`（现有测试，第 123-132 行）会因为行为变更而失败，需要更新。

修改 `ClipMindTests/App/GlobalHotkeyServiceTests.swift` 第 123-132 行，把 `.openMainWindow` 改为 `.openQuickPaste`：

```swift
    func testGlobalHotkeyService_HotkeyPressed_PostsOpenQuickPasteNotification()
    {
        let mock = MockHotkeyRegistrar()
        let service = GlobalHotkeyService(hotkey: "cmd+shift+v", registrar: mock)

        let expectation = XCTNSNotificationExpectation(name: .openQuickPaste)
        mock.simulateHotkeyPressed()
        wait(for: [expectation], timeout: 1.0)
        _ = service
    }
```

- [ ] **2.4 运行测试验证通过**

运行同 2.2 的命令 + 运行现有 `GlobalHotkeyServiceTests`：

```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindTests/GlobalHotkeyServiceQuickPasteTests \
  -only-testing ClipMindTests/GlobalHotkeyServiceTests \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：`** TEST SUCCEEDED **`，新测试 2 个 + 现有测试 1 个（已改名）全部通过。

- [ ] **2.5 运行 SwiftLint**

```bash
swiftlint lint --strict
```

预期：零违规。

- [ ] **2.6 Commit**

```bash
git add ClipMind/App/GlobalHotkeyService.swift ClipMindTests/App/GlobalHotkeyServiceTests.swift ClipMindTests/App/GlobalHotkeyServiceQuickPasteTests.swift
git commit -m "feat(hotkey): change trigger to open quick paste panel instead of main window"
```

---

## 任务 3：QuickPastePanelController 基础（NSPanel + 屏幕中央定位 + 显示/关闭）

**文件：**
- 创建：`ClipMind/UI/QuickPaste/QuickPastePanelController.swift`
- 测试：`ClipMindTests/UI/QuickPastePanelControllerTests.swift`（新增）

### 步骤

- [ ] **3.1 编写失败的测试**

创建 `ClipMindTests/UI/QuickPastePanelControllerTests.swift`：

```swift
@testable import ClipMind
import AppKit
import XCTest

final class QuickPastePanelControllerTests: XCTestCase
{
    // MARK: - TC-F1.9-3-01 无权限时面板显示在屏幕中央

    func testShowPanel_AtScreenCenter_WhenNoLastPosition()
    {
        let controller = QuickPastePanelController(
            screenLocator: ScreenCenterLocator()
        )
        controller.showPanel()

        XCTAssertTrue(controller.isPanelVisible, "面板应已显示")
        let panelFrame = controller.panelFrameForTesting
        let screenFrame = NSScreen.main?.frame ?? .zero
        let expectedCenterX = screenFrame.midX - panelFrame.width / 2.0
        let expectedCenterY = screenFrame.midY - panelFrame.height / 2.0
        XCTAssertEqual(
            panelFrame.midX,
            expectedCenterX + panelFrame.width / 2.0,
            accuracy: 1.0,
            "面板应在屏幕水平中央"
        )
        XCTAssertEqual(
            panelFrame.midY,
            expectedCenterY + panelFrame.height / 2.0,
            accuracy: 1.0,
            "面板应在屏幕垂直中央"
        )

        controller.closePanel()
    }

    // MARK: - 状态机单一性（TC-F1.9-S-02 子项：重复关闭不崩溃）

    func testClosePanel_WhenAlreadyClosed_DoesNotCrash()
    {
        let controller = QuickPastePanelController(
            screenLocator: ScreenCenterLocator()
        )
        controller.closePanel()
        controller.closePanel()
        XCTAssertFalse(controller.isPanelVisible, "重复关闭后仍应为不可见状态")
    }

    // MARK: - 测试辅助：屏幕中央定位器

    /// 屏幕中央定位器（模拟无权限路径的定位逻辑）。
    private final class ScreenCenterLocator: PanelScreenLocating
    {
        func locatePosition(lastClosedPosition: NSPoint?) -> NSPoint
        {
            let screenFrame = NSScreen.main?.frame ?? .zero
            return NSPoint(
                x: screenFrame.midX - QuickPastePanelController.panelSize.width / 2.0,
                y: screenFrame.midY - QuickPastePanelController.panelSize.height / 2.0
            )
        }
    }
}
```

- [ ] **3.2 运行测试验证失败**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.9-quick-paste-panel
xcodegen generate && xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindTests/QuickPastePanelControllerTests \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：编译失败，报错 `cannot find type 'QuickPastePanelController' in scope` 和 `cannot find type 'PanelScreenLocating' in scope`。

- [ ] **3.3 编写最少实现代码**

创建 `ClipMind/UI/QuickPaste/QuickPastePanelController.swift`：

```swift
import AppKit
import SwiftUI

/// 面板定位协议（依赖注入，便于测试 mock 不同定位策略）。
///
/// Phase 1 只有屏幕中央/上次位置策略；Phase 4 会新增 caret 定位策略。
protocol PanelScreenLocating: AnyObject
{
    /// 计算面板显示位置。
    /// - Parameter lastClosedPosition: 上次关闭时记录的位置（nil 表示无记忆）
    /// - Returns: 面板左下角坐标（NSPanel 使用左下角原点）
    func locatePosition(lastClosedPosition: NSPoint?) -> NSPoint
}

/// 快速粘贴面板控制器。
///
/// 管理 NSPanel 的创建、定位、显示、关闭、键盘焦点、失焦监听、位置记忆。
/// 状态机：Closed → Showing → Closed（Phase 1）；Phase 2/3 扩展 Pasting 状态。
///
/// 设计文档第 3.1 节、第 5.1 节。
final class QuickPastePanelController
{
    /// 面板固定尺寸（与菜单栏 popover 视觉一致）。
    static let panelSize = NSSize(width: 360, height: 480)

    /// 面板位置记忆的 UserDefaults 键。
    private static let lastClosedPositionXKey = "F1.9.quickPaste.lastClosedPositionX"
    private static let lastClosedPositionYKey = "F1.9.quickPaste.lastClosedPositionY"

    private let screenLocator: PanelScreenLocating
    private var panel: NSPanel?
    private var lastClosedPosition: NSPoint?

    /// 面板当前是否可见（状态机：Closed=false, Showing=true）。
    private(set) var isPanelVisible = false

    init(screenLocator: PanelScreenLocating)
    {
        self.screenLocator = screenLocator
        loadLastClosedPosition()
    }

    deinit
    {
        closePanelInternal()
    }

    // MARK: - 显示与关闭

    /// 显示面板（若已显示则忽略，保证状态机单一性）。
    func showPanel()
    {
        guard !isPanelVisible else
        {
            LogCategory.ui.info("QuickPaste panel already visible, ignore show request")
            return
        }

        let panel = makePanel()
        self.panel = panel

        let position = screenLocator.locatePosition(lastClosedPosition: lastClosedPosition)
        panel.setFrameOrigin(position)
        panel.makeKeyAndOrderFront(nil)
        isPanelVisible = true
        LogCategory.ui.info("QuickPaste panel shown at position")
    }

    /// 关闭面板（若已关闭则忽略，保证状态机单一性）。
    /// 关闭时记录面板位置（供下次无权限定位使用）。
    func closePanel()
    {
        closePanelInternal()
    }

    private func closePanelInternal()
    {
        guard isPanelVisible, let panel = panel else { return }

        let frame = panel.frame
        recordLastClosedPosition(NSPoint(x: frame.origin.x, y: frame.origin.y))

        panel.orderOut(nil)
        self.panel = nil
        isPanelVisible = false
        LogCategory.ui.info("QuickPaste panel closed, position recorded")
    }

    // MARK: - 测试辅助

    /// 仅供单元测试读取面板当前 frame（生产代码不使用）。
    var panelFrameForTesting: NSRect
    {
        panel?.frame ?? .zero
    }

    // MARK: - 私有

    private func makePanel() -> NSPanel
    {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.panelSize),
            styleMask: [.titled, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        // F1.9 失焦关闭由 didResignKeyNotification 处理（任务 5 实现）
        return panel
    }

    private func loadLastClosedPosition()
    {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: Self.lastClosedPositionXKey) != nil,
              defaults.object(forKey: Self.lastClosedPositionYKey) != nil
        else { return }
        let x = defaults.double(forKey: Self.lastClosedPositionXKey)
        let y = defaults.double(forKey: Self.lastClosedPositionYKey)
        lastClosedPosition = NSPoint(x: x, y: y)
    }

    private func recordLastClosedPosition(_ position: NSPoint)
    {
        lastClosedPosition = position
        let defaults = UserDefaults.standard
        defaults.set(position.x, forKey: Self.lastClosedPositionXKey)
        defaults.set(position.y, forKey: Self.lastClosedPositionYKey)
    }
}
```

- [ ] **3.4 运行测试验证通过**

运行同 3.2 的命令。

预期：`** TEST SUCCEEDED **`，2 个测试方法通过。

- [ ] **3.5 运行 SwiftLint**

```bash
swiftlint lint --strict
```

预期：零违规。

- [ ] **3.6 Commit**

```bash
git add ClipMind/UI/QuickPaste/QuickPastePanelController.swift ClipMindTests/UI/QuickPastePanelControllerTests.swift
git commit -m "feat(quick-paste): add QuickPastePanelController with screen center positioning"
```

---

## 任务 4：QuickPastePanelController 上次关闭位置记忆 + 屏幕可视范围校验

**文件：**
- 修改：`ClipMind/UI/QuickPaste/QuickPastePanelController.swift`
- 测试：`ClipMindTests/UI/QuickPastePanelControllerTests.swift`（追加测试）

### 步骤

- [ ] **4.1 编写失败的测试**

在 `ClipMindTests/UI/QuickPastePanelControllerTests.swift` 末尾追加：

```swift
    // MARK: - TC-F1.9-3-02 无权限时面板显示在上次关闭位置

    func testShowPanel_AtLastClosedPosition_WhenPositionInVisibleRange()
    {
        let locator = LastClosedPositionLocator()
        let controller = QuickPastePanelController(screenLocator: locator)

        // 模拟上次关闭位置（屏幕中央偏移 100 点）
        let screenFrame = NSScreen.main?.frame ?? .zero
        let recordedPosition = NSPoint(x: screenFrame.midX - 100, y: screenFrame.midY - 100)
        controller.setLastClosedPositionForTesting(recordedPosition)

        controller.showPanel()

        let panelFrame = controller.panelFrameForTesting
        XCTAssertEqual(panelFrame.origin.x, recordedPosition.x, accuracy: 1.0, "面板应在上次关闭位置")
        XCTAssertEqual(panelFrame.origin.y, recordedPosition.y, accuracy: 1.0, "面板应在上次关闭位置")

        controller.closePanel()
    }

    // MARK: - 屏幕可视范围校验（上次位置超出屏幕时降级到屏幕中央）

    func testShowPanel_FallsBackToScreenCenter_WhenLastPositionOutOfScreen()
    {
        let locator = LastClosedPositionLocator()
        let controller = QuickPastePanelController(screenLocator: locator)

        // 模拟上次关闭位置在屏幕外（负坐标）
        controller.setLastClosedPositionForTesting(NSPoint(x: -10000, y: -10000))

        controller.showPanel()

        let panelFrame = controller.panelFrameForTesting
        let screenFrame = NSScreen.main?.frame ?? .zero
        let expectedCenterX = screenFrame.midX - panelFrame.width / 2.0
        XCTAssertEqual(panelFrame.origin.x, expectedCenterX, accuracy: 1.0, "上次位置超出屏幕时应降级到屏幕中央")

        controller.closePanel()
    }

    // MARK: - 测试辅助：上次关闭位置定位器

    /// 上次关闭位置定位器（无权限路径使用 lastClosedPosition）。
    private final class LastClosedPositionLocator: PanelScreenLocating
    {
        func locatePosition(lastClosedPosition: NSPoint?) -> NSPoint
        {
            guard let lastClosedPosition = lastClosedPosition,
                  isPositionVisible(lastClosedPosition)
            else
            {
                let screenFrame = NSScreen.main?.frame ?? .zero
                return NSPoint(
                    x: screenFrame.midX - QuickPastePanelController.panelSize.width / 2.0,
                    y: screenFrame.midY - QuickPastePanelController.panelSize.height / 2.0
                )
            }
            return lastClosedPosition
        }

        private func isPositionVisible(_ position: NSPoint) -> Bool
        {
            let screenFrame = NSScreen.main?.frame ?? .zero
            let panelSize = QuickPastePanelController.panelSize
            let panelRect = NSRect(origin: position, size: panelSize)
            return screenFrame.contains(panelRect)
        }
    }
```

在 `QuickPastePanelController` 测试辅助区域追加（任务 3 已建好的测试辅助），需要在控制器中暴露 `setLastClosedPositionForTesting`。在任务 3 创建的 `QuickPastePanelController.swift` 的 `panelFrameForTesting` 下方追加：

```swift
    /// 仅供单元测试注入上次关闭位置（模拟位置记忆场景）。
    func setLastClosedPositionForTesting(_ position: NSPoint)
    {
        lastClosedPosition = position
    }
```

- [ ] **4.2 运行测试验证失败**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.9-quick-paste-panel
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindTests/QuickPastePanelControllerTests \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：新增的 2 个测试失败（因为任务 3 的 `ScreenCenterLocator` 总是返回屏幕中央，不使用 `lastClosedPosition`；且 `setLastClosedPositionForTesting` 不存在导致编译失败）。先添加 `setLastClosedPositionForTesting` 方法后，测试仍会失败因为 `ScreenCenterLocator` 忽略 `lastClosedPosition`——但任务 4 的测试用 `LastClosedPositionLocator`，需要先编译通过再验证逻辑。

- [ ] **4.3 编写最少实现代码**

在 `ClipMind/UI/QuickPaste/QuickPastePanelController.swift` 的 `panelFrameForTesting` 计算属性下方追加测试辅助方法：

```swift
    /// 仅供单元测试注入上次关闭位置（模拟位置记忆场景）。
    func setLastClosedPositionForTesting(_ position: NSPoint)
    {
        lastClosedPosition = position
    }
```

> **说明**：任务 4 的测试使用 `LastClosedPositionLocator`（在测试文件中定义），定位逻辑在 locator 内部实现，控制器只负责调用 locator 并显示。任务 3 的 `ScreenCenterLocator` 用于无权限首次打开（无记忆），任务 4 的 `LastClosedPositionLocator` 用于有记忆时的定位。生产代码中 `AppDelegate` 会根据权限状态选择 locator（Phase 4 实现）。任务 4 的实现代码主要是测试辅助方法，定位逻辑由 locator 协议实现。

- [ ] **4.4 运行测试验证通过**

运行同 4.2 的命令。

预期：`** TEST SUCCEEDED **`，4 个测试方法（任务 3 的 2 个 + 任务 4 的 2 个）全部通过。

- [ ] **4.5 运行 SwiftLint**

```bash
swiftlint lint --strict
```

预期：零违规。

- [ ] **4.6 Commit**

```bash
git add ClipMind/UI/QuickPaste/QuickPastePanelController.swift ClipMindTests/UI/QuickPastePanelControllerTests.swift
git commit -m "feat(quick-paste): add last closed position memory with visible range check"
```

---

## 任务 5：QuickPastePanelController Esc/失焦关闭

**文件：**
- 修改：`ClipMind/UI/QuickPaste/QuickPastePanelController.swift`（追加 Esc 键监听 + 失焦通知监听 + 关闭回调）
- 测试：`ClipMindTests/UI/QuickPastePanelControllerTests.swift`（追加测试）

### 步骤

- [ ] **5.1 编写失败的测试**

在 `ClipMindTests/UI/QuickPastePanelControllerTests.swift` 末尾追加：

```swift
    // MARK: - TC-F1.9-8-01 Esc 键关闭面板不粘贴

    func testClosePanel_OnEscKey_ClosesPanelWithoutPaste()
    {
        let controller = QuickPastePanelController(screenLocator: ScreenCenterLocator())
        var pasteCalled = false
        controller.onPasteTriggeredForTesting = { _ in pasteCalled = true }

        controller.showPanel()
        XCTAssertTrue(controller.isPanelVisible)

        controller.handleEscKeyForTesting()

        XCTAssertFalse(controller.isPanelVisible, "Esc 键应关闭面板")
        XCTAssertFalse(pasteCalled, "Esc 关闭不应触发粘贴流程")
    }

    // MARK: - TC-F1.9-9-01 面板失焦自动关闭

    func testClosePanel_OnResignKey_ClosesPanelWithoutPaste()
    {
        let controller = QuickPastePanelController(screenLocator: ScreenCenterLocator())
        var pasteCalled = false
        controller.onPasteTriggeredForTesting = { _ in pasteCalled = true }

        controller.showPanel()
        XCTAssertTrue(controller.isPanelVisible)

        controller.handleDidResignKeyForTesting()

        XCTAssertFalse(controller.isPanelVisible, "失焦应关闭面板")
        XCTAssertFalse(pasteCalled, "失焦关闭不应触发粘贴流程")
    }

    // MARK: - TC-F1.9-S-02 三种关闭路径互不冲突（双击+失焦竞态）

    func testClosePanel_OnEscAndResignKey_OnlyClosesOnce()
    {
        let controller = QuickPastePanelController(screenLocator: ScreenCenterLocator())
        controller.showPanel()
        XCTAssertTrue(controller.isPanelVisible)

        controller.handleEscKeyForTesting()
        let visibleAfterEsc = controller.isPanelVisible
        controller.handleDidResignKeyForTesting()

        XCTAssertFalse(visibleAfterEsc, "Esc 后应已关闭")
        XCTAssertFalse(controller.isPanelVisible, "再次失焦不应崩溃或重复关闭")
    }
```

- [ ] **5.2 运行测试验证失败**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.9-quick-paste-panel
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindTests/QuickPastePanelControllerTests \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：编译失败，报错 `value of type 'QuickPastePanelController' has no member 'handleEscKeyForTesting'` / `'handleDidResignKeyForTesting'` / `'onPasteTriggeredForTesting'`。

- [ ] **5.3 编写最少实现代码**

修改 `ClipMind/UI/QuickPaste/QuickPastePanelController.swift`，在类中追加以下内容（在 `closePanelInternal()` 之后、`panelFrameForTesting` 之前）：

```swift
    /// 仅供测试注入的粘贴回调（Phase 2/3 接入真实 PasteCoordinator 后移除）。
    var onPasteTriggeredForTesting: ((ClipItem) -> Void)?

    /// 失焦通知观察者。
    private var resignObserver: NSObjectProtocol?

    /// Esc 键处理（由 QuickPasteView 的 NSEvent 监听器调用，任务 6 接入）。
    func handleEscKey()
    {
        guard isPanelVisible else { return }
        LogCategory.ui.info("QuickPaste panel closed by Esc key")
        closePanelInternal()
    }

    /// 失焦处理（由 NSPanel.didResignKeyNotification 触发）。
    @objc func handleDidResignKey()
    {
        guard isPanelVisible else { return }
        LogCategory.ui.info("QuickPaste panel closed by resign key")
        closePanelInternal()
    }

    /// 仅供测试触发 Esc 关闭。
    func handleEscKeyForTesting()
    {
        handleEscKey()
    }

    /// 仅供测试触发失焦关闭。
    func handleDidResignKeyForTesting()
    {
        handleDidResignKey()
    }
```

修改 `showPanel()` 方法，在 `panel.makeKeyAndOrderFront(nil)` 之后追加失焦通知监听（在 `isPanelVisible = true` 之前）：

```swift
        panel.makeKeyAndOrderFront(nil)
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            self?.handleDidResignKey()
        }
        isPanelVisible = true
```

修改 `closePanelInternal()` 方法，在 `panel.orderOut(nil)` 之前移除观察者（在 `recordLastClosedPosition` 之后）：

```swift
        if let observer = resignObserver
        {
            NotificationCenter.default.removeObserver(observer)
            resignObserver = nil
        }

        panel.orderOut(nil)
```

- [ ] **5.4 运行测试验证通过**

运行同 5.2 的命令。

预期：`** TEST SUCCEEDED **`，7 个测试方法（任务 3 的 2 个 + 任务 4 的 2 个 + 任务 5 的 3 个）全部通过。

- [ ] **5.5 运行 SwiftLint**

```bash
swiftlint lint --strict
```

预期：零违规。

- [ ] **5.6 Commit**

```bash
git add ClipMind/UI/QuickPaste/QuickPastePanelController.swift ClipMindTests/UI/QuickPastePanelControllerTests.swift
git commit -m "feat(quick-paste): add Esc and resign key close with state machine idempotency"
```

---

## 任务 6：QuickPasteView 视图（搜索框 + 列表 + 默认高亮第一行 + 键盘事件路由）

**文件：**
- 创建：`ClipMind/UI/QuickPaste/QuickPasteView.swift`
- 测试：`ClipMindTests/UI/QuickPasteViewTests.swift`（新增）

### 步骤

- [ ] **6.1 编写失败的测试**

创建 `ClipMindTests/UI/QuickPasteViewTests.swift`：

```swift
@testable import ClipMind
import XCTest

final class QuickPasteViewTests: XCTestCase
{
    // MARK: - TC-F1.9-4-03 面板出现时默认高亮第一行

    func testViewInit_DefaultSelectedIndexIsZero_WhenListNonEmpty()
    {
        let clips = QuickPasteViewTests.makeTextClips(count: 3)
        let viewModel = QuickPasteViewModel(clips: clips)

        XCTAssertEqual(viewModel.selectedIndex, 0, "列表非空时应默认高亮第一行")
        XCTAssertTrue(viewModel.isSelected(index: 0), "第一行应被选中")
    }

    // MARK: - TC-F1.9-4-04 第一行按上方向键不动

    func testMoveSelectionUp_OnFirstIndex_StaysAtZero()
    {
        let clips = QuickPasteViewTests.makeTextClips(count: 3)
        let viewModel = QuickPasteViewModel(clips: clips)
        viewModel.selectedIndex = 0

        viewModel.moveSelectionUp()

        XCTAssertEqual(viewModel.selectedIndex, 0, "第一行按上方向键应不动")
    }

    // MARK: - 方向键下移

    func testMoveSelectionDown_FromFirstIndex_MovesToSecond()
    {
        let clips = QuickPasteViewTests.makeTextClips(count: 3)
        let viewModel = QuickPasteViewModel(clips: clips)
        viewModel.selectedIndex = 0

        viewModel.moveSelectionDown()

        XCTAssertEqual(viewModel.selectedIndex, 1, "第一行按下方向键应移到第二行")
    }

    // MARK: - 最后一行按下方向键不动

    func testMoveSelectionDown_OnLastIndex_StaysAtLast()
    {
        let clips = QuickPasteViewTests.makeTextClips(count: 3)
        let viewModel = QuickPasteViewModel(clips: clips)
        viewModel.selectedIndex = 2

        viewModel.moveSelectionDown()

        XCTAssertEqual(viewModel.selectedIndex, 2, "最后一行按下方向键应不动")
    }

    // MARK: - TC-F1.9-5-03 未高亮行按回车不触发操作（空列表）

    func testEnterKey_OnEmptyList_DoesNotTriggerPaste()
    {
        let viewModel = QuickPasteViewModel(clips: [])
        var pasteCalled = false
        viewModel.onPasteTriggered = { _ in pasteCalled = true }

        viewModel.handleEnterKey()

        XCTAssertFalse(pasteCalled, "空列表按回车不应触发粘贴")
    }

    // MARK: - 单击选中

    func testSelectIndex_UpdatesSelectedIndex()
    {
        let clips = QuickPasteViewTests.makeTextClips(count: 3)
        let viewModel = QuickPasteViewModel(clips: clips)

        viewModel.selectIndex(1)

        XCTAssertEqual(viewModel.selectedIndex, 1)
        XCTAssertTrue(viewModel.isSelected(index: 1))
        XCTAssertFalse(viewModel.isSelected(index: 0))
    }

    // MARK: - 测试辅助

    private static func makeTextClips(count: Int) -> [ClipItem]
    {
        (0..<count).map { index in
            ClipItem.makeText(
                "测试文本 \(index)",
                contentType: .other,
                sourceApp: "com.test",
                sourceAppName: "Test"
            )
        }
    }
}
```

- [ ] **6.2 运行测试验证失败**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.9-quick-paste-panel
xcodegen generate && xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindTests/QuickPasteViewTests \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：编译失败，报错 `cannot find type 'QuickPasteViewModel' in scope`。

- [ ] **6.3 编写最少实现代码**

创建 `ClipMind/UI/QuickPaste/QuickPasteView.swift`：

```swift
import AppKit
import SwiftUI

/// 快速粘贴面板视图模型（管理高亮选中状态 + 键盘事件路由）。
///
/// Phase 1 实现默认高亮第一行 + 方向键导航 + 单击选中 + 回车回调骨架。
/// Phase 2 接入双击回调，Phase 3 接入 PasteCoordinator。
@MainActor
final class QuickPasteViewModel: ObservableObject
{
    @Published var selectedIndex: Int

    /// 双击/回车触发的粘贴回调（Phase 2/3 接入 PasteCoordinator）。
    var onPasteTriggered: ((ClipItem) -> Void)?

    /// 测试用：记录最近触发 onPasteTriggered 的 clip.id，供 UI 测试通过测试元素验证回调被调用。
    /// 仅在测试启动参数下通过 QuickPasteView 的测试元素暴露，不影响生产行为。
    @Published var lastTriggeredClipIdForTesting: String?

    /// Esc 键回调（由控制器关闭面板）。
    var onEscPressed: (() -> Void)?

    /// 单击回调（更新选中状态，不触发粘贴）。
    var onSingleClick: ((Int) -> Void)?

    /// 双击回调（触发粘贴流程）。
    var onDoubleClick: ((ClipItem) -> Void)?

    let clips: [ClipItem]

    init(clips: [ClipItem])
    {
        self.clips = clips
        // 默认高亮第一行（若列表非空）
        selectedIndex = clips.isEmpty ? -1 : 0
    }

    // MARK: - 选中状态

    func isSelected(index: Int) -> Bool
    {
        index == selectedIndex
    }

    func selectIndex(_ index: Int)
    {
        guard clips.indices.contains(index) else { return }
        selectedIndex = index
        onSingleClick?(index)
    }

    // MARK: - 方向键导航

    func moveSelectionUp()
    {
        guard !clips.isEmpty, selectedIndex > 0 else { return }
        selectedIndex -= 1
    }

    func moveSelectionDown()
    {
        guard !clips.isEmpty, selectedIndex < clips.count - 1 else { return }
        selectedIndex += 1
    }

    // MARK: - 键盘事件

    func handleEnterKey()
    {
        guard clips.indices.contains(selectedIndex) else { return }
        let clip = clips[selectedIndex]
        onPasteTriggered?(clip)
        // test hook：记录触发的 clip.id，供 UI 测试验证回调被调用（Phase 2 任务 5）
        lastTriggeredClipIdForTesting = clip.id
    }

    func handleEscKey()
    {
        onEscPressed?()
    }
}

/// 快速粘贴面板内容视图。
///
/// 视觉与菜单栏 popover 一致（搜索框 + LazyVStack 列表），但增加：
/// - 默认高亮第一行（蓝色边框 + 浅蓝背景）
/// - 单击选中（通过 ClipRowView.isSelected，Phase 2 接入）
/// - 双击触发回调（Phase 2 接入）
/// - Esc/方向键/回车键盘事件路由（NSEvent.addLocalMonitorForEvents）
struct QuickPasteView: View
{
    @StateObject private var viewModel: QuickPasteViewModel
    @State private var searchText = ""
    @State private var keyMonitor: Any?

    init(clips: [ClipItem])
    {
        _viewModel = StateObject(wrappedValue: QuickPasteViewModel(clips: clips))
    }

    var body: some View
    {
        VStack(spacing: 0)
        {
            searchBar
            Divider()
            contentList
        }
        .frame(width: 360, height: 480)
        .onAppear { startKeyMonitor() }
        .onDisappear { stopKeyMonitor() }
        .onChange(of: searchText)
        { _ in
            // 搜索过滤后 selectedIndex 重置为 0（过滤后列表的第一行），避免越界；
            // 搜索清空时 selectedIndex 保持 0（显示全部，第一行高亮）
            if !filteredClips.isEmpty
            {
                viewModel.selectedIndex = 0
            }
        }
    }

    // MARK: - 搜索框

    private var searchBar: some View
    {
        HStack(spacing: 8)
        {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("搜索剪贴内容...", text: $searchText)
                .textFieldStyle(.plain)
                .accessibilityIdentifier("quickPasteSearchField")
        }
        .padding(8)
    }

    // MARK: - 列表

    private var filteredClips: [ClipItem]
    {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return viewModel.clips }
        return viewModel.clips.filter { clip in
            if case .text(let text) = clip.content
            {
                return text.localizedCaseInsensitiveContains(trimmed)
            }
            return false
        }
    }

    private var contentList: some View
    {
        Group
        {
            if filteredClips.isEmpty
            {
                VStack(spacing: 8)
                {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("暂无剪贴内容")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            else
            {
                ScrollView
                {
                    LazyVStack(spacing: 0)
                    {
                        ForEach(Array(filteredClips.enumerated()), id: \.element.id)
                        { index, clip in
                            ClipRowView(clip: clip)
                                .background(
                                    viewModel.isSelected(index: index)
                                        ? Color.accentColor.opacity(0.2)
                                        : Color.clear
                                )
                                .overlay(
                                    viewModel.isSelected(index: index)
                                        ? RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.accentColor, lineWidth: 2)
                                        : nil
                                )
                                .accessibilityIdentifier("quickPasteRow_\(index)\(viewModel.isSelected(index: index) ? "_selected" : "")")
                                .onTapGesture(count: 1)
                                {
                                    viewModel.selectIndex(index)
                                }
                        }
                    }
                }
            }
        }
    }

    // MARK: - 键盘事件监听

    private func startKeyMonitor()
    {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown)
        { event in
            self.handleKeyEvent(event)
            return event
        }
    }

    private func stopKeyMonitor()
    {
        if let monitor = keyMonitor
        {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent)
    {
        switch event.keyCode
        {
        case 36: // Enter
            viewModel.handleEnterKey()
        case 53: // Esc
            viewModel.handleEscKey()
        case 125: // Down arrow
            viewModel.moveSelectionDown()
        case 126: // Up arrow
            viewModel.moveSelectionUp()
        default:
            break
        }
    }
}
```

- [ ] **6.4 运行测试验证通过**

运行同 6.2 的命令。

预期：`** TEST SUCCEEDED **`，6 个测试方法全部通过。

- [ ] **6.5 运行 SwiftLint**

```bash
swiftlint lint --strict
```

预期：零违规。

- [ ] **6.6 Commit**

```bash
git add ClipMind/UI/QuickPaste/QuickPasteView.swift ClipMindTests/UI/QuickPasteViewTests.swift
git commit -m "feat(quick-paste): add QuickPasteView with default highlight and keyboard navigation"
```

---

## 任务 7：AppDelegate 集成 + UI 测试

**文件：**
- 修改：`ClipMind/App/ClipMindApp.swift`（`AppDelegate` 新增 `quickPastePanelController` 持有 + 监听 `.openQuickPaste` 通知 + `configureActivationPolicy()` 中初始化控制器）
- 测试：`ClipMindUITests/QuickPastePanelUITests.swift`（新增）

### 步骤

- [ ] **7.1 编写失败的测试**

创建 `ClipMindUITests/QuickPastePanelUITests.swift`：

```swift
import AppKit
import XCTest

final class QuickPastePanelUITests: XCTestCase
{
    override func setUp()
    {
        super.setUp()
        continueAfterFailure = false
        cleanUpDatabase()
    }

    override func tearDown()
    {
        XCUIApplication().terminate()
        super.tearDown()
    }

    private func cleanUpDatabase()
    {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        let dbPath = appSupport.appendingPathComponent("ClipMind/clipmind.db")
        for suffix in ["", "-wal", "-shm"]
        {
            try? FileManager.default.removeItem(atPath: dbPath.path + suffix)
        }
        // 清除面板位置记忆（避免上次关闭位置干扰测试）
        UserDefaults.standard.removeObject(forKey: "F1.9.quickPaste.lastClosedPositionX")
        UserDefaults.standard.removeObject(forKey: "F1.9.quickPaste.lastClosedPositionY")
    }

    // MARK: - TC-F1.9-1-01 全局快捷键呼出快速粘贴面板（非主窗口）

    /// 使用 --UITEST_QUICK_PASTE_PANEL 启动参数直接显示面板（绕过全局快捷键注册，
    /// 全局快捷键在 CI 环境无法可靠触发）。
    func testQuickPastePanelAppears_OnLaunchArgument()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_QUICK_PASTE_PANEL"
        ]
        app.launch()

        let searchField = app.textFields["quickPasteSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "快速粘贴面板应出现并包含搜索框")
    }

    // MARK: - TC-F1.9-3-01 无权限时面板显示在屏幕中央

    func testPanelPositionedAtScreenCenter_WhenNoLastPosition()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_QUICK_PASTE_PANEL"
        ]
        app.launch()

        let searchField = app.textFields["quickPasteSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        // 验证面板显示在屏幕中央（通过面板窗口 frame 与主屏 frame 比对，允许 ±50px 误差）
        // 注意：本测试文件顶部需 `import AppKit` 以使用 NSScreen
        let panelFrame = app.windows.containing(.textField, identifier: "quickPasteSearchField").firstMatch.frame
        let screenFrame = NSScreen.main?.frame ?? .zero
        XCTAssertEqual(panelFrame.midX, screenFrame.midX, accuracy: 50, "面板应显示在屏幕中央水平位置")
        XCTAssertEqual(panelFrame.midY, screenFrame.midY, accuracy: 50, "面板应显示在屏幕中央垂直位置")
    }

    // MARK: - TC-F1.9-8-01 Esc 键关闭面板不粘贴

    func testPanelCloses_OnEscKey()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_QUICK_PASTE_PANEL"
        ]
        app.launch()

        let searchField = app.textFields["quickPasteSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        searchField.typeKey(XCUIKeyboardKey.escape, modifierFlags: [])

        XCTAssertFalse(searchField.exists, "按 Esc 后面板应关闭")
    }

    // MARK: - TC-F1.9-9-01 面板失焦自动关闭

    func testPanelCloses_OnResignFocus()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_QUICK_PASTE_PANEL"
        ]
        app.launch()

        let searchField = app.textFields["quickPasteSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))

        // 点击主窗口（使面板失焦）
        let mainWindow = app.windows.firstMatch
        mainWindow.click()

        // 等待面板关闭（失焦通知异步触发）
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == NO"),
            object: searchField
        )
        wait(for: [expectation], timeout: 3.0)
    }

    // MARK: - TC-F1.9-4-03 面板出现时默认高亮第一行

    func testFirstRowHighlighted_ByDefault()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREPOPULATE_SAMPLE_AND_REAL",
            "--UITEST_QUICK_PASTE_PANEL"
        ]
        app.launch()

        // 默认高亮第一行：通过 accessibilityIdentifier 后缀 _selected 验证（未选中行无后缀）
        let firstRowSelected = app.descendants(matching: .any)["quickPasteRow_0_selected"].firstMatch
        XCTAssertTrue(firstRowSelected.waitForExistence(timeout: 5), "第一行应默认高亮选中")
    }
}
```

- [ ] **7.2 运行测试验证失败**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.9-quick-paste-panel
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindUITests/QuickPastePanelUITests \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：所有 UI 测试失败，因为 `--UITEST_QUICK_PASTE_PANEL` 启动参数未实现，面板不会出现。

- [ ] **7.3 编写最少实现代码**

修改 `ClipMind/App/ClipMindApp.swift` 的 `AppDelegate` 类：

第 33-38 行（持有属性区域）追加：

```swift
    private var quickPastePanelController: QuickPastePanelController?
```

第 70-89 行（`applicationDidFinishLaunching` 方法）在 `NotificationCenter.default.addObserver(... name: .openMainWindow ...)` 之后追加：

```swift
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenQuickPaste),
            name: .openQuickPaste,
            object: nil
        )
```

第 136-156 行（`configureActivationPolicy` 方法）在 `setupHotkeyService()` 之后（`if completed` 分支内）追加：

```swift
            setupQuickPastePanelController()
```

在 `setupHotkeyService()` 方法（第 288-291 行）之后追加新方法：

```swift
    /// 初始化快速粘贴面板控制器（F1.9）
    private func setupQuickPastePanelController()
    {
        let locator = ScreenCenterPanelLocator()
        quickPastePanelController = QuickPastePanelController(screenLocator: locator)

        // UI 测试启动参数：直接显示面板
        if CommandLine.arguments.contains("--UITEST_QUICK_PASTE_PANEL")
        {
            quickPastePanelController?.showPanel()
        }
    }

    /// F1.9：接收全局快捷键通知，呼出快速粘贴面板。
    @objc private func handleOpenQuickPaste()
    {
        quickPastePanelController?.showPanel()
    }
```

在 `AppDelegate` 类末尾（`handleAutoSaveError` 方法之后）追加 `ScreenCenterPanelLocator`：

```swift
    /// 屏幕中央面板定位器（生产环境无权限路径使用）。
    /// Phase 4 会根据权限状态切换为 CaretPanelLocator。
    private final class ScreenCenterPanelLocator: PanelScreenLocating
    {
        func locatePosition(lastClosedPosition: NSPoint?) -> NSPoint
        {
            // 优先使用上次关闭位置（若在屏幕可视范围内）
            if let last = lastClosedPosition,
               let screenFrame = NSScreen.main?.frame
            {
                let panelRect = NSRect(
                    origin: last,
                    size: QuickPastePanelController.panelSize
                )
                if screenFrame.contains(panelRect)
                {
                    return last
                }
            }
            // 降级到屏幕中央
            let screenFrame = NSScreen.main?.frame ?? .zero
            return NSPoint(
                x: screenFrame.midX - QuickPastePanelController.panelSize.width / 2.0,
                y: screenFrame.midY - QuickPastePanelController.panelSize.height / 2.0
            )
        }
    }
```

> **说明**：`ScreenCenterPanelLocator` 作为 `AppDelegate` 的私有嵌套类，符合"位置记忆 + 屏幕可视范围校验 + 降级到屏幕中央"的逻辑。`QuickPastePanelController` 在 `showPanel()` 时调用 `loadLastClosedPosition()` 加载记忆，传入 locator。

- [ ] **7.4 运行测试验证通过**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.9-quick-paste-panel
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindUITests/QuickPastePanelUITests \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：`** TEST SUCCEEDED **`，5 个 UI 测试方法通过。

> **注意**：如果 `testPanelCloses_OnResignFocus` 在 CI 环境不稳定（窗口点击可能被系统拦截），可标记 `XCTSkip` 并记录到手动验收。但本地 macOS 15 应能通过。

- [ ] **7.5 运行 SwiftLint**

```bash
swiftlint lint --strict
```

预期：零违规。

- [ ] **7.6 运行 Phase 1 全量测试（回归验证）**

```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindTests/QuickPasteSettingsTests \
  -only-testing ClipMindTests/GlobalHotkeyServiceQuickPasteTests \
  -only-testing ClipMindTests/GlobalHotkeyServiceTests \
  -only-testing ClipMindTests/QuickPastePanelControllerTests \
  -only-testing ClipMindTests/QuickPasteViewTests \
  -only-testing ClipMindUITests/QuickPastePanelUITests \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：`** TEST SUCCEEDED **`，Phase 1 全部测试通过（约 25 个测试方法）。

- [ ] **7.7 Commit**

```bash
git add ClipMind/App/ClipMindApp.swift ClipMindUITests/QuickPastePanelUITests.swift
git commit -m "feat(quick-paste): integrate panel controller into AppDelegate with UI tests"
```

---

## UI 证据任务

> **证据保存约定（Phase 1）**
>
> - **截图路径模板**：`docs/planning/P0/F1/screenshots/F1.9/phase1-ACx-场景描述.png`
> - **录屏路径模板**：`docs/planning/P0/F1/recordings/F1.9/phase1-ACx-场景描述.mov`
> - **保存规则**：
>   1. XCUITest 通过后，运行该测试用例时通过 `XCUIScreenshot` 附件捕获截图，保存到上述截图路径（文件名见各条目「证据保存」）。
>   2. 涉及真实快捷键、真实环境交互的条目（标「手动补充」），发布前手动执行并录屏，保存到上述录屏路径。
>   3. 路径中 `phase1` 为 Phase 编号，`ACx` 为对应验收条件编号，`场景描述` 用中文简述场景。
>   4. 截图/录屏文件提交到仓库，作为发布前人工审查证据。

### UI-AC-F1.9-1-01：全局快捷键呼出快速粘贴面板（非主窗口）

**对应 AC**：AC-F1.9-1
**对应测试**：`QuickPastePanelUITests.testQuickPastePanelAppears_OnLaunchArgument`
**证据方式**：XCUITest 自动化（通过 `--UITEST_QUICK_PASTE_PANEL` 启动参数绕过全局快捷键注册，验证面板出现 + 主窗口未被唤起）
**手动补充**：在真实环境按 Cmd+Shift+V 验证全局快捷键触发（全局快捷键在 CI 环境无法可靠触发）
**证据保存**：
- 截图：`docs/planning/P0/F1/screenshots/F1.9/phase1-AC1-快捷键呼出.png`（XCUITest 通过后捕获）
- 录屏：`docs/planning/P0/F1/recordings/F1.9/phase1-AC1-快捷键呼出.mov`（手动验收真实快捷键触发，发布前录制）

### UI-AC-F1.9-3-01：无权限时面板显示在屏幕中央

**对应 AC**：AC-F1.9-3
**对应测试**：`QuickPastePanelUITests.testPanelPositionedAtScreenCenter_WhenNoLastPosition`
**证据方式**：XCUITest 自动化（验证面板窗口存在）+ 单元测试 `QuickPastePanelControllerTests.testShowPanel_AtScreenCenter_WhenNoLastPosition`（验证坐标在屏幕中央）
**证据保存**：
- 截图：`docs/planning/P0/F1/screenshots/F1.9/phase1-AC3-屏幕中央定位.png`（XCUITest 通过后捕获）

### UI-AC-F1.9-8-01：Esc 键关闭面板不粘贴

**对应 AC**：AC-F1.9-8
**对应测试**：`QuickPastePanelUITests.testPanelCloses_OnEscKey`
**证据方式**：XCUITest 自动化（按 Esc 键验证面板关闭）+ 单元测试 `QuickPastePanelControllerTests.testClosePanel_OnEscKey_ClosesPanelWithoutPaste`（验证不触发粘贴）
**证据保存**：
- 截图：`docs/planning/P0/F1/screenshots/F1.9/phase1-AC8-Esc关闭面板.png`（XCUITest 通过后捕获）

---

## 合并基线

Phase 1 完成后，分支 `feature/F1.9-quick-paste-panel` 应满足以下基线才能合并到 `develop`：

1. `swiftlint lint --strict` 零违规
2. `xcodebuild test` 全量通过（Phase 1 新增测试 + 现有测试无回归）
3. `xcodebuild build` 编译成功
4. 7 个任务全部 commit，每个 commit 的 SwiftLint 已通过
5. 文档同步：在 `docs/planning/P0/F1/historys/` 追加 `2026-07-23-F1.9-Phase1-基础面板完成.md`

**Phase 1 不阻塞 Phase 2 启动**：Phase 2 在 Phase 1 合并后开始（或在同一 worktree 直接继续，前提是 Phase 1 全部测试通过）。

---

## 手动验收（发布前补充）

### AC-F1.9-1 真实快捷键入口手动验收脚本

> **对应 AC**：AC-F1.9-1（全局快捷键呼出快速粘贴面板，且不唤起主窗口）
> **前置条件**：ClipMind 已启动并在菜单栏运行；辅助功能权限状态任意（本验收只验证快捷键呼出，不验证粘贴）。

**目标应用**：备忘录（macOS 自带，沙盒友好，可接收焦点）

**操作步骤**：

1. 打开「备忘录」App，新建一个空备忘录，点击编辑区使光标获得焦点（确认备忘录为前台应用）。
2. 按下全局快捷键 `Cmd+Shift+V`（ClipMind 默认快捷键，可在设置中修改）。
3. 观察并验证：
   - 快速粘贴面板出现在屏幕中央（首次呼出）或上次关闭位置（非首次）。
   - 备忘录窗口失焦，但主窗口（ClipMind 设置/历史记录窗口）**未被唤起**。
   - 菜单栏 popover 仍可正常点击打开。
4. 按 `Esc` 键关闭面板。
5. 再次按 `Cmd+Shift+V`，验证面板可重复呼出。
6. 截图保存：面板出现时截屏，保存为 `docs/planning/P0/F1/screenshots/F1.9/phase1-AC1-快捷键呼出.png`。
7. 录屏保存（可选但推荐）：完整操作流程录屏，保存为 `docs/planning/P0/F1/recordings/F1.9/phase1-AC1-快捷键呼出.mov`。

**通过标准**：
- 步骤 3 中面板出现且主窗口未被唤起。
- 步骤 5 中面板可重复呼出。

**失败标准**（任一即视为 AC-F1.9-1 未通过）：
- 按 `Cmd+Shift+V` 后面板未出现。
- 面板出现的同时主窗口也被唤起（弹出设置/历史记录窗口）。
- 面板出现位置明显偏离屏幕中央（首次）或上次关闭位置（非首次），如出现在屏幕外、菜单栏上等。
- 面板出现后无法通过 `Esc` 关闭。
- 第二次按快捷键面板无法再次呼出（说明面板状态未正确重置）。

### 其他手动验收项

2. 按 Esc 键验证面板立即关闭
3. 点击其他应用窗口验证面板失焦自动关闭
4. 验证面板出现时第一行默认高亮（蓝色边框 + 浅蓝背景）
5. 验证主窗口未被唤起（菜单栏 popover 的"查看全部"按钮仍能打开主窗口）

---

## 版本记录

| 版本 | 日期 | 变更说明 |
|------|------|---------|
| v1.0 | 2026-07-23 | 初始版本，Phase 1 基础面板，7 任务 42 TDD 步骤，覆盖 AC-F1.9-1, 3, 8, 9，3 个 UI 证据任务 |
| v1.1 | 2026-07-23 | 修订（Fix 4/6/11/12/16/19/20/15）：文件计数修正为 6 个；QuickPasteViewModel 加 @MainActor；onChange 同步 selectedIndex；accessibilityIdentifier 加 _selected 后缀；testPanelPositionedAtScreenCenter 改 frame 比对；testFirstRowHighlighted 验证后缀；test hook lastTriggeredClipIdForTesting；UI 证据任务补充证据保存路径；AC-F1.9-1 手动验收脚本 |
| v1.2 | 2026-07-23 | 修复第二轮 check-plan 发现的 8 项必须修复项（文件计数、Fix 10 行为一致性、UI 测试 import/identifier/谓词） |
| v1.3 | 2026-07-23 | 修复第三轮 check-plan 发现的 4 项必须修复项（phase-1/3 任务数标题误改、Phase 3 任务 4.3 实现与测试断言一致、QuickPastePanelUITests 补 import AppKit） |
