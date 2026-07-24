> 最后更新：2026-07-23 | 版本：v1.3

# Phase 3：无权限降级

> **面向 AI 代理的工作者：** 本 Phase 在 Phase 1/2 的基础上实现无辅助功能权限时的降级粘贴流程。使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现。步骤使用复选框（`- [ ]`）语法跟踪进度。前置条件：Phase 1 + Phase 2 全部测试通过。所有任务严格按编号顺序执行。

## 目标

实现无辅助功能权限时的完整降级粘贴流程：双击/回车文本行 → 检测权限（运行时检测，不弹 TCC）→ 写入剪贴板 → 关闭快速粘贴面板 → 显示"已复制，按 Cmd+V 粘贴"降级浮层 → 浮层在剪贴板被消费或超时兜底后消失。同时新增设置面板的浮层超时兜底时长配置 UI（1-30 秒 Stepper），配置变更立即生效。所有实现纯沙盒内完成，App Store 完全合规。

## 范围

- `ClipboardWriter`：剪贴板写入模块（仅文本，通过 NSPasteboard）
- `ClipboardConsumerWatcher`：剪贴板消费监听器（轮询 changeCount，再次变化即视为消费）
- `PasteOverlayController`：降级浮层控制器（NSPanel + 通用文案 + 消费监听 + 超时计时器，两路消失互斥）
- `PasteCoordinator`：粘贴流程协调器（检测权限 → 写剪贴板 → 关闭面板 → 无权限分支显示浮层）
- `GeneralSettingsView`：新增"快速粘贴"分区（浮层超时兜底时长 Stepper 1-30 秒）
- `AppDelegate` 与 `QuickPastePanelController`、`QuickPasteView` 接入 PasteCoordinator
- 单元测试 14 条 + UI 测试 6 条（覆盖 AC-F1.9-7, AC-F1.9-10 无权限路径, AC-F1.9-12 降级逻辑, TC-F1.9-SEC-02）

## 非目标

- 不实现有权限路径的自动粘贴（Phase 4 接入 AccessibilityService + PasteSimulator）
- 不实现 caret 定位（Phase 4）
- 不实现模拟粘贴按键（Phase 4）
- 不实现真实的 AccessibilityService（Phase 4；Phase 3 通过 `PastePermissionChecking` 协议 + 默认实现复用 `PermissionRequester.axTrustedCheck(false)`）
- 不修改 `QuickPasteSettings` 的持久化逻辑（Phase 1 已完成，Phase 3 仅消费其值）
- 不修改菜单栏 popover 的任何行为

## 涉及文件和职责

### 新增文件（9 个：4 生产代码 + 4 单元测试 + 1 UI 测试 = 9 总）

| 文件 | 职责 |
|------|------|
| `ClipMind/UI/QuickPaste/ClipboardWriter.swift` | 剪贴板写入模块：`ClipboardWriting` 协议 + `ClipboardWriter` 默认实现（NSPasteboard 写入文本） |
| `ClipMind/UI/QuickPaste/ClipboardConsumerWatcher.swift` | 剪贴板消费监听器：`ClipboardChangeCountProviding` 协议 + `ClipboardConsumerWatcher`（轮询 changeCount，再次变化触发回调） |
| `ClipMind/UI/QuickPaste/PasteOverlayController.swift` | 降级浮层控制器：`OverlayShowing` 协议 + `OverlayTimerScheduling` 协议 + `PasteOverlayController`（NSPanel + 通用文案 + 消费监听 + 超时计时器） |
| `ClipMind/UI/QuickPaste/PasteCoordinator.swift` | 粘贴流程协调器：`PastePermissionChecking` 协议 + `PanelClosing` 协议 + `PasteCoordinator`（检测权限 → 写剪贴板 → 关闭面板 → 无权限显示浮层） |
| `ClipMindTests/UI/ClipboardWriterTests.swift` | 剪贴板写入模块单元测试 |
| `ClipMindTests/UI/ClipboardConsumerWatcherTests.swift` | 剪贴板消费监听器单元测试 |
| `ClipMindTests/UI/PasteOverlayControllerTests.swift` | TC-F1.9-7-02/03/04, TC-F1.9-SEC-02（浮层显示/消费消失/超时消失/文案不含原文） |
| `ClipMindTests/UI/PasteCoordinatorTests.swift` | TC-F1.9-7-01, TC-F1.9-10-02, TC-F1.9-12-01（降级逻辑正确性） |
| `ClipMindUITests/QuickPasteOverlayUITests.swift` | TC-F1.9-7-01/02/03/04 UI 层验证 |

### 修改文件（4 个）

| 文件 | 职责变更 |
|------|---------|
| `ClipMind/UI/Settings/GeneralSettingsView.swift` | 新增"快速粘贴"分区：浮层超时兜底时长 Stepper（1-30 秒）+ 说明文案 |
| `ClipMind/UI/QuickPaste/QuickPastePanelController.swift` | 遵循 `PanelClosing` 协议；新增 `setContentView(_:)` 方法设置面板内容视图（供 AppDelegate 注入 QuickPasteView） |
| `ClipMind/UI/QuickPaste/QuickPasteView.swift` | `QuickPasteView` 新增 `init(viewModel:)` 初始化器，支持外部注入 viewModel（携带 PasteCoordinator 回调） |
| `ClipMind/App/ClipMindApp.swift` | `AppDelegate` 新增 `pasteCoordinator` 持有；`setupQuickPastePanelController()` 创建 PasteCoordinator + QuickPasteView + 注入回调 + 设置 contentView |

### 测试用例覆盖说明

- **本 Phase 覆盖**：TC-F1.9-7-01/02/03/04（降级浮层全流程）, TC-F1.9-10-02（无权限路径粘贴后关闭）, TC-F1.9-12-01（降级逻辑正确性，权限不缓存）, TC-F1.9-SEC-02（浮层不显示原文）（共 8 条）
- **延后覆盖**：TC-F1.9-12-01 的有权限路径分支由 Phase 4 覆盖（Phase 3 仅验证无权限降级分支）

---

## 任务 1：ClipboardWriter 剪贴板写入模块

**文件：**
- 创建：`ClipMind/UI/QuickPaste/ClipboardWriter.swift`
- 测试：`ClipMindTests/UI/ClipboardWriterTests.swift`（新增）

### 步骤

- [ ] **1.1 编写失败的测试**

创建 `ClipMindTests/UI/ClipboardWriterTests.swift`：

```swift
@testable import ClipMind
import AppKit
import XCTest

final class ClipboardWriterTests: XCTestCase
{
    // MARK: - 写入文本成功

    func testWriteText_ReturnsTrue_AndWritesToPasteboard()
    {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("ClipMindTestPasteboard"))
        pasteboard.clearContents()
        let writer = ClipboardWriter(pasteboard: pasteboard)

        let success = writer.write(text: "测试文本内容")

        XCTAssertTrue(success, "写入文本应返回 true")
        let readString = pasteboard.string(forType: .string)
        XCTAssertEqual(readString, "测试文本内容", "剪贴板应包含写入的文本")
    }

    // MARK: - 写入空文本仍成功（不绕过敏感识别，敏感识别在捕获阶段处理）

    func testWriteText_EmptyString_ReturnsTrue()
    {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("ClipMindTestPasteboard"))
        pasteboard.clearContents()
        let writer = ClipboardWriter(pasteboard: pasteboard)

        let success = writer.write(text: "")

        XCTAssertTrue(success, "写入空文本应返回 true")
    }

    // MARK: - 写入后 changeCount 增加（验证写入确实生效）

    func testWriteText_IncreasesChangeCount()
    {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("ClipMindTestPasteboard"))
        pasteboard.clearContents()
        let writer = ClipboardWriter(pasteboard: pasteboard)

        let countBefore = pasteboard.changeCount
        _ = writer.write(text: "内容")
        let countAfter = pasteboard.changeCount

        XCTAssertGreaterThan(countAfter, countBefore, "写入后 changeCount 应增加")
    }

    // MARK: - 写入多字节文本（中文）

    func testWriteText_MultibyteContent_PersistsCorrectly()
    {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("ClipMindTestPasteboard"))
        pasteboard.clearContents()
        let writer = ClipboardWriter(pasteboard: pasteboard)

        let multibyte = "你好世界🌍 import SwiftUI"
        _ = writer.write(text: multibyte)

        XCTAssertEqual(pasteboard.string(forType: .string), multibyte, "多字节文本应完整写入")
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
  -only-testing ClipMindTests/ClipboardWriterTests \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：编译失败，报错 `cannot find type 'ClipboardWriter' in scope`。

- [ ] **1.3 编写最少实现代码**

创建 `ClipMind/UI/QuickPaste/ClipboardWriter.swift`：

```swift
import AppKit
import Foundation

/// 剪贴板写入协议（依赖注入，便于测试 mock）。
///
/// Phase 3 仅支持文本写入；图片/文件路径类型在 PasteCoordinator 层拦截（不调用写入）。
protocol ClipboardWriting: AnyObject
{
    /// 将文本写入剪贴板。
    /// - Parameter text: 待写入的文本
    /// - Returns: 写入是否成功
    func write(text: String) -> Bool
}

/// 剪贴板写入模块默认实现（使用 NSPasteboard）。
///
/// 设计文档第 3.7 节。仅写入文本类型，写入失败时返回 false 由协调器处理。
/// 日志仅记录元数据（文本长度），不记录原文（NFR-003 安全性）。
final class ClipboardWriter: ClipboardWriting
{
    private let pasteboard: NSPasteboard

    /// - Parameter pasteboard: NSPasteboard 实例（生产用 .general，测试注入隔离实例）
    init(pasteboard: NSPasteboard = .general)
    {
        self.pasteboard = pasteboard
    }

    func write(text: String) -> Bool
    {
        pasteboard.clearContents()
        let success = pasteboard.setString(text, forType: .string)
        if success
        {
            LogCategory.app.info("Clipboard written, length: \(text.count, privacy: .public)")
        }
        else
        {
            LogCategory.app.error("Clipboard write failed")
        }
        return success
    }
}
```

- [ ] **1.4 运行测试验证通过**

运行同 1.2 的命令。

预期：`** TEST SUCCEEDED **`，4 个测试方法全部通过。

- [ ] **1.5 运行 SwiftLint**

```bash
swiftlint lint --strict
```

预期：零违规。

- [ ] **1.6 Commit**

```bash
git add ClipMind/UI/QuickPaste/ClipboardWriter.swift ClipMindTests/UI/ClipboardWriterTests.swift
git commit -m "feat(paste-coordinator): add ClipboardWriter with text-only pasteboard write"
```

---

## 任务 2：ClipboardConsumerWatcher 剪贴板消费监听器

**文件：**
- 创建：`ClipMind/UI/QuickPaste/ClipboardConsumerWatcher.swift`
- 测试：`ClipMindTests/UI/ClipboardConsumerWatcherTests.swift`（新增）

### 步骤

- [ ] **2.1 编写失败的测试**

创建 `ClipMindTests/UI/ClipboardConsumerWatcherTests.swift`：

```swift
@testable import ClipMind
import XCTest

final class ClipboardConsumerWatcherTests: XCTestCase
{
    // MARK: - 启动监听记录基准 changeCount

    func testStart_CapturesBaselineChangeCount()
    {
        let provider = MockChangeCountProvider(changeCount: 10)
        let watcher = ClipboardConsumerWatcher(changeCountProvider: provider)

        watcher.start { }

        XCTAssertEqual(watcher.baselineChangeCountForTesting, 10, "启动时应记录基准 changeCount")
        watcher.stop()
    }

    // MARK: - changeCount 未变化时不触发回调

    func testPoll_NoChange_DoesNotTriggerCallback()
    {
        let provider = MockChangeCountProvider(changeCount: 10)
        var consumed = false
        let watcher = ClipboardConsumerWatcher(changeCountProvider: provider, pollInterval: 0.05)

        watcher.start { consumed = true }

        // 等待两个轮询周期，changeCount 未变化
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "consumed == YES"),
            object: self
        )
        expectation.isInverted = true
        wait(for: [expectation], timeout: 0.3)

        XCTAssertFalse(consumed, "changeCount 未变化时不应触发消费回调")
        watcher.stop()
    }

    // MARK: - changeCount 再次变化时触发回调

    func testPoll_ChangeCountIncreased_TriggersCallback()
    {
        let provider = MockChangeCountProvider(changeCount: 10)
        var consumed = false
        let watcher = ClipboardConsumerWatcher(changeCountProvider: provider, pollInterval: 0.05)

        watcher.start { consumed = true }

        // 模拟用户在其他应用按 Cmd+V 后剪贴板 changeCount 变化
        provider.changeCount = 11

        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "consumed == YES"),
            object: self
        )
        wait(for: [expectation], timeout: 1.0)

        XCTAssertTrue(consumed, "changeCount 变化时应触发消费回调")
    }

    // MARK: - stop 后不再触发回调

    func testStop_PreventsFurtherCallbacks()
    {
        let provider = MockChangeCountProvider(changeCount: 10)
        var consumed = false
        let watcher = ClipboardConsumerWatcher(changeCountProvider: provider, pollInterval: 0.05)

        watcher.start { consumed = true }
        watcher.stop()

        provider.changeCount = 11

        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "consumed == YES"),
            object: self
        )
        expectation.isInverted = true
        wait(for: [expectation], timeout: 0.3)

        XCTAssertFalse(consumed, "stop 后不应再触发回调")
    }

    // MARK: - 测试辅助

    private final class MockChangeCountProvider: ClipboardChangeCountProviding
    {
        var changeCount: Int

        init(changeCount: Int)
        {
            self.changeCount = changeCount
        }

        func currentChangeCount() -> Int
        {
            changeCount
        }
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
  -only-testing ClipMindTests/ClipboardConsumerWatcherTests \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：编译失败，报错 `cannot find type 'ClipboardConsumerWatcher' in scope` 和 `cannot find type 'ClipboardChangeCountProviding' in scope`。

- [ ] **2.3 编写最少实现代码**

创建 `ClipMind/UI/QuickPaste/ClipboardConsumerWatcher.swift`：

```swift
import Foundation

/// 剪贴板变化计数提供协议（依赖注入，便于测试 mock）。
///
/// 生产实现返回 `NSPasteboard.general.changeCount`；测试 mock 返回可控值。
protocol ClipboardChangeCountProviding: AnyObject
{
    /// 返回当前剪贴板变化计数。
    func currentChangeCount() -> Int
}

/// 系统剪贴板变化计数提供器（默认实现）。
final class SystemChangeCountProvider: ClipboardChangeCountProviding
{
    func currentChangeCount() -> Int
    {
        NSPasteboard.general.changeCount
    }
}

/// 剪贴板消费监听器。
///
/// 设计文档第 3.8 节 + 第 7.6 节。
/// 通过轮询剪贴板变化计数判定消费：写入时记录基准计数，
/// 当计数再次变化时（用户按 Cmd+V 后部分应用会重新写入剪贴板）视为被消费。
///
/// 不比对剪贴板内容（NFR-003 安全性，不读取剪贴板原文）。
/// 使用 DispatchSourceTimer 轮询，不使用 sleep（CODING_STANDARDS 禁止用 sleep 等待异步）。
final class ClipboardConsumerWatcher
{
    private let changeCountProvider: ClipboardChangeCountProviding
    private let pollInterval: TimeInterval
    private var timer: DispatchSourceTimer?
    private var baseline: Int = 0

    /// 消费回调（changeCount 再次变化时触发）。
    private var onConsumed: (() -> Void)?

    /// - Parameters:
    ///   - changeCountProvider: 剪贴板变化计数提供器
    ///   - pollInterval: 轮询间隔（秒），默认 0.2 秒
    init(
        changeCountProvider: ClipboardChangeCountProviding = SystemChangeCountProvider(),
        pollInterval: TimeInterval = 0.2
    )
    {
        self.changeCountProvider = changeCountProvider
        self.pollInterval = pollInterval
    }

    deinit
    {
        stop()
    }

    /// 启动消费监听。
    /// - Parameter onConsumed: 剪贴板被消费时的回调
    func start(onConsumed: @escaping () -> Void)
    {
        stop()
        baseline = changeCountProvider.currentChangeCount()
        self.onConsumed = onConsumed

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.scheduleRepeating(deadline: .now() + pollInterval, repeating: pollInterval)
        timer.setEventHandler { [weak self] in
            self?.checkChangeCount()
        }
        timer.resume()
        self.timer = timer
        LogCategory.ui.info("Clipboard consumer watcher started, baseline: \(baseline, privacy: .public)")
    }

    /// 停止消费监听。
    func stop()
    {
        timer?.cancel()
        timer = nil
        onConsumed = nil
    }

    // MARK: - 测试辅助

    /// 仅供单元测试读取基准 changeCount。
    var baselineChangeCountForTesting: Int
    {
        baseline
    }

    // MARK: - 私有

    private func checkChangeCount()
    {
        let current = changeCountProvider.currentChangeCount()
        guard current != baseline else { return }

        LogCategory.ui.info("Clipboard consumed, changeCount: \(baseline, privacy: .public) -> \(current, privacy: .public)")
        let callback = onConsumed
        stop()
        callback?()
    }
}
```

- [ ] **2.4 运行测试验证通过**

运行同 2.2 的命令。

预期：`** TEST SUCCEEDED **`，4 个测试方法全部通过。

- [ ] **2.5 运行 SwiftLint**

```bash
swiftlint lint --strict
```

预期：零违规。

- [ ] **2.6 Commit**

```bash
git add ClipMind/UI/QuickPaste/ClipboardConsumerWatcher.swift ClipMindTests/UI/ClipboardConsumerWatcherTests.swift
git commit -m "feat(overlay): add ClipboardConsumerWatcher with changeCount polling"
```

---

## 任务 3：PasteOverlayController 降级浮层控制器

**文件：**
- 创建：`ClipMind/UI/QuickPaste/PasteOverlayController.swift`
- 测试：`ClipMindTests/UI/PasteOverlayControllerTests.swift`（新增）

### 步骤

- [ ] **3.1 编写失败的测试**

创建 `ClipMindTests/UI/PasteOverlayControllerTests.swift`：

```swift
@testable import ClipMind
import AppKit
import XCTest

final class PasteOverlayControllerTests: XCTestCase
{
    // MARK: - TC-F1.9-7-01 显示浮层时文案为"已复制，按 Cmd+V 粘贴"

    func testShowOverlay_DisplaysGenericMessage_WithoutClipboardContent()
    {
        let controller = makeController()

        controller.showOverlay()

        XCTAssertTrue(controller.isOverlayVisible, "浮层应已显示")
        XCTAssertEqual(controller.overlayTextForTesting, "已复制，按 Cmd+V 粘贴", "浮层应显示通用文案")

        controller.hideOverlay()
    }

    // MARK: - TC-F1.9-SEC-02 浮层不显示剪贴板原文

    func testShowOverlay_MessageDoesNotContainClipboardContent()
    {
        let controller = makeController()

        controller.showOverlay()

        let message = controller.overlayTextForTesting
        XCTAssertFalse(message.contains("敏感内容"), "浮层文案不应包含剪贴板原文")
        XCTAssertFalse(message.contains("密码"), "浮层文案不应包含剪贴板原文")
        XCTAssertEqual(message, "已复制，按 Cmd+V 粘贴", "浮层仅显示通用文案")

        controller.hideOverlay()
    }

    // MARK: - TC-F1.9-7-02 剪贴板被消费后浮层消失

    func testHideOverlay_OnConsumption_Disappears()
    {
        let watcher = MockConsumerWatcher()
        let controller = makeController(consumerWatcher: watcher)

        controller.showOverlay()
        XCTAssertTrue(controller.isOverlayVisible)

        // 模拟剪贴板被消费
        watcher.simulateConsumed()

        XCTAssertFalse(controller.isOverlayVisible, "消费后浮层应消失")
    }

    // MARK: - TC-F1.9-7-03 超时兜底后浮层消失

    func testHideOverlay_OnTimeout_Disappears()
    {
        let timer = MockOverlayTimer()
        let controller = makeController(timerScheduler: timer)

        controller.showOverlay()
        XCTAssertTrue(controller.isOverlayVisible)

        // 模拟超时触发
        timer.simulateTimeout()

        XCTAssertFalse(controller.isOverlayVisible, "超时后浮层应消失")
    }

    // MARK: - 消费与超时互斥（先触发者生效，另一路径被取消）

    func testHideOverlay_ConsumptionFirst_CancelsTimeout()
    {
        let watcher = MockConsumerWatcher()
        let timer = MockOverlayTimer()
        let controller = makeController(consumerWatcher: watcher, timerScheduler: timer)

        controller.showOverlay()
        XCTAssertTrue(timer.isTimeoutScheduled, "显示浮层时应调度超时")

        watcher.simulateConsumed()
        XCTAssertFalse(controller.isOverlayVisible)

        // 消费后超时不应再触发关闭（已关闭）
        timer.simulateTimeout()
        XCTAssertFalse(controller.isOverlayVisible, "消费后超时不应重复关闭")
    }

    func testHideOverlay_TimeoutFirst_CancelsConsumption()
    {
        let watcher = MockConsumerWatcher()
        let timer = MockOverlayTimer()
        let controller = makeController(consumerWatcher: watcher, timerScheduler: timer)

        controller.showOverlay()

        timer.simulateTimeout()
        XCTAssertFalse(controller.isOverlayVisible)
        XCTAssertFalse(watcher.isWatching, "超时后应停止消费监听")
    }

    // MARK: - 超时时长从 QuickPasteSettings 读取

    func testShowOverlay_ReadsTimeoutDurationFromSettings()
    {
        let defaults = UserDefaults(suiteName: "ClipMind.OverlayTests.\(UUID().uuidString)")!
        let settings = QuickPasteSettings(defaults: defaults)
        settings.saveOverlayDuration(10.0)
        let timer = MockOverlayTimer()
        let controller = makeController(timerScheduler: timer, settings: settings)

        controller.showOverlay()

        XCTAssertEqual(timer.scheduledDuration, 10.0, "超时时长应从 QuickPasteSettings 读取")

        controller.hideOverlay()
        defaults.removePersistentDomain(forName: defaults.dictionaryRepresentation().keys.first ?? "")
    }

    // MARK: - 测试辅助

    private func makeController(
        consumerWatcher: ClipboardConsumerWatcherProtocol = MockConsumerWatcher(),
        timerScheduler: OverlayTimerScheduling = MockOverlayTimer(),
        settings: QuickPasteSettings = QuickPasteSettings(defaults: UserDefaults(suiteName: "ClipMind.OverlayTests.\(UUID().uuidString)")!)
    ) -> PasteOverlayController
    {
        PasteOverlayController(
            consumerWatcher: consumerWatcher,
            timerScheduler: timerScheduler,
            settings: settings,
            screenLocator: ScreenCenterOverlayLocator()
        )
    }

    /// 屏幕中央浮层定位器。
    private final class ScreenCenterOverlayLocator: OverlayScreenLocating
    {
        func locatePosition() -> NSPoint
        {
            let screenFrame = NSScreen.main?.frame ?? .zero
            return NSPoint(x: screenFrame.midX - 100, y: screenFrame.midY - 30)
        }
    }

    /// Mock 消费监听器。
    private final class MockConsumerWatcher: ClipboardConsumerWatcherProtocol
    {
        private var onConsumed: (() -> Void)?
        private(set) var isWatching = false

        func start(onConsumed: @escaping () -> Void)
        {
            self.onConsumed = onConsumed
            isWatching = true
        }

        func stop()
        {
            isWatching = false
            onConsumed = nil
        }

        func simulateConsumed()
        {
            onConsumed?()
            isWatching = false
            onConsumed = nil
        }
    }

    /// Mock 超时计时器。
    private final class MockOverlayTimer: OverlayTimerScheduling
    {
        private var timeoutHandler: (() -> Void)?
        private(set) var isTimeoutScheduled = false
        private(set) var scheduledDuration: TimeInterval = 0

        func scheduleTimeout(after duration: TimeInterval, handler: @escaping () -> Void)
        {
            scheduledDuration = duration
            timeoutHandler = handler
            isTimeoutScheduled = true
        }

        func cancelTimeout()
        {
            isTimeoutScheduled = false
            timeoutHandler = nil
        }

        func simulateTimeout()
        {
            let handler = timeoutHandler
            cancelTimeout()
            handler?()
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
  -only-testing ClipMindTests/PasteOverlayControllerTests \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：编译失败，报错 `cannot find type 'PasteOverlayController' in scope` / `OverlayTimerScheduling` / `ClipboardConsumerWatcherProtocol` / `OverlayScreenLocating`。

- [ ] **3.3 编写最少实现代码**

创建 `ClipMind/UI/QuickPaste/PasteOverlayController.swift`：

```swift
import AppKit
import Foundation
import SwiftUI

/// 浮层定位协议（依赖注入，便于测试 mock）。
protocol OverlayScreenLocating: AnyObject
{
    /// 计算浮层显示位置（左下角原点）。
    func locatePosition() -> NSPoint
}

/// 剪贴板消费监听协议（抽象 ClipboardConsumerWatcher 便于测试 mock）。
protocol ClipboardConsumerWatcherProtocol: AnyObject
{
    /// 启动消费监听。
    /// - Parameter onConsumed: 剪贴板被消费时的回调
    func start(onConsumed: @escaping () -> Void)

    /// 停止消费监听。
    func stop()
}

/// 使 ClipboardConsumerWatcher 遵循协议。
extension ClipboardConsumerWatcher: ClipboardConsumerWatcherProtocol {}

/// 浮层超时计时协议（依赖注入，便于测试 mock，避免等待真实超时）。
protocol OverlayTimerScheduling: AnyObject
{
    /// 调度超时回调。
    /// - Parameters:
    ///   - duration: 超时时长（秒）
    ///   - handler: 超时触发的回调
    func scheduleTimeout(after duration: TimeInterval, handler: @escaping () -> Void)

    /// 取消已调度的超时。
    func cancelTimeout()
}

/// 浮层超时计时器默认实现（使用 DispatchSourceTimer，不使用 sleep）。
final class OverlayTimer: OverlayTimerScheduling
{
    private var timer: DispatchSourceTimer?
    private var handler: (() -> Void)?

    func scheduleTimeout(after duration: TimeInterval, handler: @escaping () -> Void)
    {
        cancelTimeout()
        self.handler = handler
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + duration)
        timer.setEventHandler { [weak self] in
            let callback = self?.handler
            self?.cancelTimeout()
            callback?()
        }
        timer.resume()
        self.timer = timer
    }

    func cancelTimeout()
    {
        timer?.cancel()
        timer = nil
        handler = nil
    }
}

/// 浮层显示协议（供 PasteCoordinator 注入，便于测试 mock）。
protocol OverlayShowing: AnyObject
{
    /// 显示降级浮层。
    func showOverlay()

    /// 隐藏降级浮层（若已隐藏则忽略）。
    func hideOverlay()
}

/// 降级浮层控制器。
///
/// 设计文档第 3.4 节 + 第 5.2 节状态机。
/// 职责：显示"已复制，按 Cmd+V 粘贴"通用文案 + 启动消费监听 + 启动超时计时器。
/// 两条消失路径（消费/超时）互斥，先触发者生效，另一条路径被取消。
/// 浮层使用 NSPanel(.nonactivatingPanel) 不抢夺前台应用焦点。
/// 文案硬编码，不显示剪贴板原文（NFR-003 安全性）。
@MainActor
final class PasteOverlayController: OverlayShowing
{
    /// 浮层通用文案（硬编码，不显示剪贴板原文）。
    static let overlayMessage = "已复制，按 Cmd+V 粘贴"

    /// 浮层固定尺寸。
    private static let overlaySize = NSSize(width: 220, height: 60)

    private let consumerWatcher: ClipboardConsumerWatcherProtocol
    private let timerScheduler: OverlayTimerScheduling
    private let settings: QuickPasteSettings
    private let screenLocator: OverlayScreenLocating

    private var panel: NSPanel?
    private(set) var isOverlayVisible = false

    init(
        consumerWatcher: ClipboardConsumerWatcherProtocol,
        timerScheduler: OverlayTimerScheduling,
        settings: QuickPasteSettings,
        screenLocator: OverlayScreenLocating
    )
    {
        self.consumerWatcher = consumerWatcher
        self.timerScheduler = timerScheduler
        self.settings = settings
        self.screenLocator = screenLocator
    }

    deinit
    {
        hideOverlay()
    }

    // MARK: - OverlayShowing

    func showOverlay()
    {
        guard !isOverlayVisible else
        {
            LogCategory.ui.info("Paste overlay already visible, ignore show request")
            return
        }

        let panel = makePanel()
        self.panel = panel

        let position = screenLocator.locatePosition()
        panel.setFrameOrigin(position)
        panel.makeKeyAndOrderFront(nil)
        isOverlayVisible = true

        // 启动消费监听
        consumerWatcher.start { [weak self] in
            self?.hideOverlay()
        }

        // 启动超时计时器（时长从 QuickPasteSettings 读取）
        let duration = settings.loadOverlayDuration()
        timerScheduler.scheduleTimeout(after: duration) { [weak self] in
            self?.hideOverlay()
        }

        LogCategory.ui.info("Paste overlay shown, timeout: \(duration, privacy: .public)s")
    }

    func hideOverlay()
    {
        guard isOverlayVisible else { return }

        // 互斥：取消另一条消失路径
        consumerWatcher.stop()
        timerScheduler.cancelTimeout()

        panel?.orderOut(nil)
        panel = nil
        isOverlayVisible = false
        LogCategory.ui.info("Paste overlay hidden")
    }

    // MARK: - 测试辅助

    /// 仅供单元测试读取浮层文案。
    var overlayTextForTesting: String
    {
        Self.overlayMessage
    }

    // MARK: - 私有

    private func makePanel() -> NSPanel
    {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.overlaySize),
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

        let hostingView = NSHostingView(rootView: OverlayContentView(text: Self.overlayMessage))
        panel.contentView = hostingView
        return panel
    }
}

/// 浮层内容视图（SwiftUI）。
private struct OverlayContentView: View
{
    let text: String

    var body: some View
    {
        HStack(spacing: 8)
        {
            Image(systemName: "doc.on.clipboard")
                .foregroundColor(.accentColor)
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .accessibilityIdentifier("pasteOverlayMessage")
    }
}
```

- [ ] **3.4 运行测试验证通过**

运行同 3.2 的命令。

预期：`** TEST SUCCEEDED **`，8 个测试方法全部通过。

- [ ] **3.5 运行 SwiftLint**

```bash
swiftlint lint --strict
```

预期：零违规。

- [ ] **3.6 Commit**

```bash
git add ClipMind/UI/QuickPaste/PasteOverlayController.swift ClipMindTests/UI/PasteOverlayControllerTests.swift
git commit -m "feat(overlay): add PasteOverlayController with consumption and timeout dismissal"
```

---

## 任务 4：PasteCoordinator 粘贴流程协调器（无权限分支）

**文件：**
- 创建：`ClipMind/UI/QuickPaste/PasteCoordinator.swift`
- 测试：`ClipMindTests/UI/PasteCoordinatorTests.swift`（新增）

### 步骤

- [ ] **4.1 编写失败的测试**

创建 `ClipMindTests/UI/PasteCoordinatorTests.swift`：

```swift
@testable import ClipMind
import XCTest

final class PasteCoordinatorTests: XCTestCase
{
    // MARK: - 共享调用顺序计数器（供 MockPanelCloser / MockOverlayShower / Phase 4 MockPasteSimulator 共享）

    private static var sharedCallSequence = 0

    override func setUp()
    {
        super.setUp()
        PasteCoordinatorTests.sharedCallSequence = 0
    }

    // MARK: - TC-F1.9-7-01 无权限时双击降级粘贴流程

    func testHandlePaste_NoPermission_WritesClipboard_ClosesPanel_ShowsOverlay()
    {
        let permissionChecker = MockPermissionChecker(granted: false)
        let writer = MockClipboardWriter()
        let panel = MockPanelCloser()
        let overlay = MockOverlayShower()
        let coordinator = PasteCoordinator(
            permissionChecker: permissionChecker,
            clipboardWriter: writer,
            panelCloser: panel,
            overlayShower: overlay
        )

        let clip = ClipItem.makeText(
            "测试文本",
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        coordinator.handlePaste(clip: clip)

        XCTAssertTrue(writer.writeCalled, "无权限时应写入剪贴板")
        XCTAssertEqual(writer.writtenText, "测试文本", "应写入选中文本")
        XCTAssertTrue(panel.closeCalled, "应关闭面板")
        XCTAssertTrue(overlay.showCalled, "应显示降级浮层")
    }

    // MARK: - TC-F1.9-10-02 粘贴后面板自动关闭（无权限路径）

    func testHandlePaste_NoPermission_ClosesPanelBeforeShowingOverlay()
    {
        let permissionChecker = MockPermissionChecker(granted: false)
        let writer = MockClipboardWriter()
        let panel = MockPanelCloser()
        let overlay = MockOverlayShower()
        let coordinator = PasteCoordinator(
            permissionChecker: permissionChecker,
            clipboardWriter: writer,
            panelCloser: panel,
            overlayShower: overlay
        )

        let clip = ClipItem.makeText("文本", contentType: .other, sourceApp: "com.test", sourceAppName: "Test")
        coordinator.handlePaste(clip: clip)

        // 验证关闭顺序：先关闭面板，再显示浮层
        XCTAssertTrue(panel.closeCalled, "面板应已关闭")
        XCTAssertTrue(overlay.showCalled, "浮层应已显示")
        // closeCalled 在 showCalled 之前设置（通过 callOrder 验证）
        XCTAssertLessThan(panel.callOrder, overlay.callOrder, "应先关闭面板再显示浮层")
    }

    // MARK: - TC-F1.9-12-01 权限被撤销时自动降级（降级逻辑不缓存权限状态）

    func testHandlePaste_PermissionRevoked_SwitchesToDegradedPath()
    {
        let permissionChecker = MockPermissionChecker(granted: true)
        let writer = MockClipboardWriter()
        let panel = MockPanelCloser()
        let overlay = MockOverlayShower()
        let coordinator = PasteCoordinator(
            permissionChecker: permissionChecker,
            clipboardWriter: writer,
            panelCloser: panel,
            overlayShower: overlay
        )

        let clip = ClipItem.makeText("文本", contentType: .other, sourceApp: "com.test", sourceAppName: "Test")

        // 第一次：有权限（主 Scheme 沙盒内无法模拟 Cmd+V，有权限路径回退显示降级浮层作为合规回退，与 Phase 4 Fix 10 行为一致）
        coordinator.handlePaste(clip: clip)
        XCTAssertTrue(writer.writeCalled, "有权限时应写入剪贴板")
        XCTAssertTrue(panel.closeCalled, "有权限时应关闭面板")
        XCTAssertTrue(overlay.showCalled, "有权限时主 Scheme 应显示浮层作为合规回退（Fix 10）")

        // 重置 mock
        writer.reset()
        panel.reset()
        overlay.reset()

        // 第二次：权限被撤销（模拟用户在系统设置撤销权限）
        permissionChecker.granted = false
        coordinator.handlePaste(clip: clip)

        XCTAssertTrue(writer.writeCalled, "权限撤销后仍应写入剪贴板")
        XCTAssertTrue(panel.closeCalled, "权限撤销后应关闭面板")
        XCTAssertTrue(overlay.showCalled, "权限撤销后应走降级路径显示浮层")
    }

    // MARK: - 权限检测不缓存（每次粘贴流程都重新检测）

    func testHandlePaste_ChecksPermissionEveryTime_DoesNotCache()
    {
        let permissionChecker = MockPermissionChecker(granted: false)
        let writer = MockClipboardWriter()
        let panel = MockPanelCloser()
        let overlay = MockOverlayShower()
        let coordinator = PasteCoordinator(
            permissionChecker: permissionChecker,
            clipboardWriter: writer,
            panelCloser: panel,
            overlayShower: overlay
        )

        let clip = ClipItem.makeText("文本", contentType: .other, sourceApp: "com.test", sourceAppName: "Test")

        coordinator.handlePaste(clip: clip)
        let firstCallCount = permissionChecker.checkCallCount

        coordinator.handlePaste(clip: clip)
        let secondCallCount = permissionChecker.checkCallCount

        XCTAssertEqual(secondCallCount, firstCallCount + 1, "每次粘贴流程都应重新检测权限")
    }

    // MARK: - 图片类型不写入剪贴板不关闭面板

    func testHandlePaste_ImageType_DoesNotWriteOrClose()
    {
        let permissionChecker = MockPermissionChecker(granted: false)
        let writer = MockClipboardWriter()
        let panel = MockPanelCloser()
        let overlay = MockOverlayShower()
        let coordinator = PasteCoordinator(
            permissionChecker: permissionChecker,
            clipboardWriter: writer,
            panelCloser: panel,
            overlayShower: overlay
        )

        let imageClip = ClipItem.makeImage(
            Data([0x89, 0x50]),
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        coordinator.handlePaste(clip: imageClip)

        XCTAssertFalse(writer.writeCalled, "图片类型不应写入剪贴板")
        XCTAssertFalse(panel.closeCalled, "图片类型不应关闭面板")
        XCTAssertFalse(overlay.showCalled, "图片类型不应显示浮层")
    }

    // MARK: - 文件路径类型不写入剪贴板不关闭面板

    func testHandlePaste_FilePathType_DoesNotWriteOrClose()
    {
        let permissionChecker = MockPermissionChecker(granted: false)
        let writer = MockClipboardWriter()
        let panel = MockPanelCloser()
        let overlay = MockOverlayShower()
        let coordinator = PasteCoordinator(
            permissionChecker: permissionChecker,
            clipboardWriter: writer,
            panelCloser: panel,
            overlayShower: overlay
        )

        let filePathClip = ClipItem.makeFilePath(
            [URL(fileURLWithPath: "/tmp/test.txt")],
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        coordinator.handlePaste(clip: filePathClip)

        XCTAssertFalse(writer.writeCalled, "文件路径类型不应写入剪贴板")
        XCTAssertFalse(panel.closeCalled, "文件路径类型不应关闭面板")
        XCTAssertFalse(overlay.showCalled, "文件路径类型不应显示浮层")
    }

    // MARK: - 剪贴板写入失败时不显示浮层（错误处理）

    func testHandlePaste_WriteFailure_DoesNotShowOverlay()
    {
        let permissionChecker = MockPermissionChecker(granted: false)
        let writer = MockClipboardWriter()
        writer.shouldSucceed = false
        let panel = MockPanelCloser()
        let overlay = MockOverlayShower()
        let coordinator = PasteCoordinator(
            permissionChecker: permissionChecker,
            clipboardWriter: writer,
            panelCloser: panel,
            overlayShower: overlay
        )

        let clip = ClipItem.makeText("文本", contentType: .other, sourceApp: "com.test", sourceAppName: "Test")
        coordinator.handlePaste(clip: clip)

        XCTAssertTrue(writer.writeCalled, "应尝试写入剪贴板")
        XCTAssertFalse(panel.closeCalled, "写入失败时不应关闭面板")
        XCTAssertFalse(overlay.showCalled, "写入失败时不应显示浮层")
    }

    // MARK: - 测试辅助 Mock

    private final class MockPermissionChecker: PastePermissionChecking
    {
        var granted: Bool
        private(set) var checkCallCount = 0

        init(granted: Bool)
        {
            self.granted = granted
        }

        func isAccessibilityGranted() -> Bool
        {
            checkCallCount += 1
            return granted
        }
    }

    private final class MockClipboardWriter: ClipboardWriting
    {
        var shouldSucceed = true
        private(set) var writeCalled = false
        private(set) var writtenText: String = ""

        func write(text: String) -> Bool
        {
            writeCalled = true
            writtenText = text
            return shouldSucceed
        }

        func reset()
        {
            writeCalled = false
            writtenText = ""
            shouldSucceed = true
        }
    }

    private final class MockPanelCloser: PanelClosing
    {
        private(set) var closeCalled = false
        private(set) var callOrder = 0

        var isPanelVisible: Bool { !closeCalled }

        func closePanel()
        {
            closeCalled = true
            PasteCoordinatorTests.sharedCallSequence += 1
            callOrder = PasteCoordinatorTests.sharedCallSequence
        }

        func reset()
        {
            closeCalled = false
            callOrder = 0
        }
    }

    private final class MockOverlayShower: OverlayShowing
    {
        private(set) var showCalled = false
        private(set) var callOrder = 0

        func showOverlay()
        {
            showCalled = true
            PasteCoordinatorTests.sharedCallSequence += 1
            callOrder = PasteCoordinatorTests.sharedCallSequence
        }

        func hideOverlay() {}

        func reset()
        {
            showCalled = false
            callOrder = 0
        }
    }
}
```

- [ ] **4.2 运行测试验证失败**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.9-quick-paste-panel
xcodegen generate && xcodebuild test \
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

预期：编译失败，报错 `cannot find type 'PasteCoordinator' in scope` / `PastePermissionChecking` / `PanelClosing`。

- [ ] **4.3 编写最少实现代码**

创建 `ClipMind/UI/QuickPaste/PasteCoordinator.swift`：

```swift
import Foundation

/// 粘贴流程权限检测协议（依赖注入，便于测试 mock）。
///
/// Phase 3 提供默认实现 `SystemPastePermissionChecker` 复用 `PermissionRequester.axTrustedCheck(false)`。
/// Phase 4 的 `AccessibilityService` 会遵循此协议并提供 caret 定位能力。
protocol PastePermissionChecking: AnyObject
{
    /// 运行时查询辅助功能权限状态（不弹 TCC 提示）。
    /// - Returns: 当前是否已授权
    func isAccessibilityGranted() -> Bool
}

/// 系统权限检测器（默认实现，复用 PermissionRequester，prompt: false 不弹 TCC）。
///
/// 设计文档第 7.2 节：每次粘贴流程重新检测，不缓存。
/// 需求文档第 11.2 节：禁止弹 TCC 提示对话框。
final class SystemPastePermissionChecker: PastePermissionChecking
{
    func isAccessibilityGranted() -> Bool
    {
        PermissionRequester.axTrustedCheck(false)
    }
}

/// 面板关闭协议（抽象 QuickPastePanelController 便于测试 mock）。
protocol PanelClosing: AnyObject
{
    /// 关闭快速粘贴面板。
    func closePanel()

    /// 面板当前是否可见。
    var isPanelVisible: Bool { get }
}

/// 粘贴流程协调器。
///
/// 设计文档第 3.3 节 + 第 4.2/4.3/4.4 节序列图。
/// 职责：接收双击/回车事件 → 检测权限 → 写剪贴板 → 关闭面板 → 分支有权限/无权限路径。
///
/// Phase 3 实现无权限降级分支（显示浮层）。
/// Phase 4 会扩展有权限分支（模拟粘贴按键），通过新增 `pasteSimulator` 依赖实现。
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

    init(
        permissionChecker: PastePermissionChecking,
        clipboardWriter: ClipboardWriting,
        panelCloser: PanelClosing,
        overlayShower: OverlayShowing
    )
    {
        self.permissionChecker = permissionChecker
        self.clipboardWriter = clipboardWriter
        self.panelCloser = panelCloser
        self.overlayShower = overlayShower
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
            // Phase 3 阶段：主 Scheme 沙盒内无法模拟 Cmd+V，有权限路径回退显示降级浮层作为合规回退（Fix 10）
            // Phase 4 会在此分支接入 PasteSimulator 模拟粘贴按键（ClipMind-Dev Scheme）
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

- [ ] **4.4 运行测试验证通过**

运行同 4.2 的命令。

预期：`** TEST SUCCEEDED **`，7 个测试方法全部通过。

- [ ] **4.5 运行 SwiftLint**

```bash
swiftlint lint --strict
```

预期：零违规。

- [ ] **4.6 Commit**

```bash
git add ClipMind/UI/QuickPaste/PasteCoordinator.swift ClipMindTests/UI/PasteCoordinatorTests.swift
git commit -m "feat(paste-coordinator): add PasteCoordinator with degraded path and non-text guard"
```

---

## 任务 5：GeneralSettingsView 新增浮层超时配置 UI

**文件：**
- 修改：`ClipMind/UI/Settings/GeneralSettingsView.swift`
- 测试：`ClipMindUITests/PopoverUITests.swift`（不修改）+ 新增设置 UI 验证通过手动验收

### 步骤

- [ ] **5.1 编写失败的测试**

在 `ClipMindUITests/QuickPasteOverlayUITests.swift`（本任务先创建文件，任务 7 会追加更多测试）中创建：

```swift
import AppKit
import XCTest

final class QuickPasteOverlayUITests: XCTestCase
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
        // 清除浮层超时配置（避免上次配置干扰测试）
        UserDefaults.standard.removeObject(forKey: "F1.9.quickPaste.overlayDuration")
    }

    // MARK: - TC-F1.9-7-04 设置面板包含浮层超时配置 Stepper

    func testSettings_ContainsOverlayTimeoutStepper()
    {
        let app = XCUIApplication()
        app.launchArguments = ["--UITEST_SHOW_MAIN_WINDOW"]
        app.launch()

        // 打开设置窗口（通过菜单栏）
        let menuBars = app.menuBars.statusItems.firstMatch
        XCTAssertTrue(menuBars.waitForExistence(timeout: 5))
        menuBars.click()

        // 设置入口（菜单中的"设置..."或偏好设置）
        // 若设置窗口已通过主窗口工具栏打开，则直接定位
        let overlayStepper = app.steppers["overlayTimeoutStepper"].firstMatch
        XCTAssertTrue(overlayStepper.waitForExistence(timeout: 5), "设置面板应包含浮层超时 Stepper")
    }
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
  -only-testing ClipMindUITests/QuickPasteOverlayUITests/testSettings_ContainsOverlayTimeoutStepper \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：测试失败，因为 `overlayTimeoutStepper` 不存在（GeneralSettingsView 尚未新增浮层超时配置分区）。

- [ ] **5.3 编写最少实现代码**

修改 `ClipMind/UI/Settings/GeneralSettingsView.swift`，在 `body` 的 `Form` 中 `sampleDataSection` 之后追加 `quickPasteSection`：

```swift
    var body: some View
    {
        Form
        {
            launchAtLoginSection
            hotkeySection
            quickPasteSection
            sampleDataSection
        }
        .padding()
    }
```

在 `sampleDataSection` 计算属性之前追加 `quickPasteSection`：

```swift
    // MARK: - 快速粘贴（F1.9 新增）

    @State private var overlayTimeoutSeconds: Double = QuickPasteSettings.overlayDurationDefault
    private let quickPasteSettings = QuickPasteSettings()

    private var quickPasteSection: some View
    {
        Section("快速粘贴")
        {
            HStack
            {
                Text("浮层超时兜底时长")
                Spacer()
                Stepper(
                    value: $overlayTimeoutSeconds,
                    in: QuickPasteSettings.overlayDurationRange
                )
                {
                    Text("\(Int(overlayTimeoutSeconds)) 秒")
                        .monospacedDigit()
                }
                .accessibilityIdentifier("overlayTimeoutStepper")
            }

            Text("无辅助功能权限时，降级浮层提示的超时兜底时长（1-30 秒）。超时后浮层自动消失。")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .onAppear
        {
            overlayTimeoutSeconds = quickPasteSettings.loadOverlayDuration()
        }
        .onChange(of: overlayTimeoutSeconds) { newValue in
            quickPasteSettings.saveOverlayDuration(newValue)
        }
    }
```

> **说明**：`QuickPasteSettings` 已在 Phase 1 任务 1 创建，提供 `loadOverlayDuration()` / `saveOverlayDuration(_:)` / `overlayDurationRange` / `overlayDurationDefault`。`onChange` 闭包在 Stepper 值变化时立即保存，配置变更立即生效（FR-014）。

- [ ] **5.4 运行测试验证通过**

运行同 5.2 的命令。

预期：`** TEST SUCCEEDED **`，Stepper 存在性验证通过。

> **注意**：如果设置窗口在 UI 测试中打开方式与预期不同（菜单栏路径差异），可调整为通过主窗口的设置按钮打开。若 CI 环境不稳定，标记 `XCTSkip` 并记录到手动验收。但本地 macOS 15 应能通过。

- [ ] **5.5 运行 SwiftLint**

```bash
swiftlint lint --strict
```

预期：零违规。

- [ ] **5.6 Commit**

```bash
git add ClipMind/UI/Settings/GeneralSettingsView.swift ClipMindUITests/QuickPasteOverlayUITests.swift
git commit -m "feat(settings): add overlay timeout stepper with immediate persistence"
```

---

## 任务 6：PasteCoordinator 接入 AppDelegate 与 QuickPasteView

**文件：**
- 修改：`ClipMind/UI/QuickPaste/QuickPastePanelController.swift`（遵循 `PanelClosing` + 新增 `setContentView`）
- 修改：`ClipMind/UI/QuickPaste/QuickPasteView.swift`（新增 `init(viewModel:)`）
- 修改：`ClipMind/App/ClipMindApp.swift`（持有 PasteCoordinator + 注入回调 + 设置 contentView）
- 测试：`ClipMindTests/UI/PasteCoordinatorTests.swift`（不修改，已覆盖逻辑层）

### 步骤

- [ ] **6.1 编写失败的测试**

在 `ClipMindTests/UI/PasteCoordinatorTests.swift` 末尾追加集成测试：

```swift
    // MARK: - 集成测试：QuickPastePanelController 遵循 PanelClosing

    func testQuickPastePanelController_ConformsToPanelClosing()
    {
        let locator = ScreenCenterLocatorForIntegration()
        let controller = QuickPastePanelController(screenLocator: locator)
        XCTAssertTrue(controller is PanelClosing, "QuickPastePanelController 应遵循 PanelClosing 协议")
        _ = controller
    }

    // MARK: - 测试辅助

    private final class ScreenCenterLocatorForIntegration: PanelScreenLocating
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
```

- [ ] **6.2 运行测试验证失败**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.9-quick-paste-panel
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindTests/PasteCoordinatorTests/testQuickPastePanelController_ConformsToPanelClosing \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：编译失败，报错 `QuickPastePanelController does not conform to PanelClosing`（因为 `isPanelVisible` 是 `private(set)`，协议要求可读）。

- [ ] **6.3 编写最少实现代码**

**第一步**：修改 `ClipMind/UI/QuickPaste/QuickPastePanelController.swift`，在类声明后追加协议遵循声明与 `setContentView` 方法。

将类声明改为：

```swift
final class QuickPastePanelController: PanelClosing
```

在 `closePanelInternal()` 方法之后追加 `setContentView` 方法：

```swift
    /// 设置面板内容视图（供 AppDelegate 注入 QuickPasteView 的 NSHostingController）。
    /// - Parameter controller: 内容视图控制器
    func setContentView(_ controller: NSViewController)
    {
        panel?.contentViewController = controller
    }
```

> **说明**：`QuickPastePanelController` 已有 `func closePanel()` 和 `private(set) var isPanelVisible: Bool`，满足 `PanelClosing` 协议要求。`isPanelVisible` 的 `private(set)` 不影响协议遵循（协议只要求可读）。`setContentView` 在 `showPanel()` 创建 panel 后由 AppDelegate 调用。但由于 `showPanel()` 中 `panel` 被重新赋值，`setContentView` 需在 `showPanel()` 之后调用。因此修改 `showPanel()` 接受可选的 contentViewController 参数。

修改 `showPanel()` 方法签名为接受可选内容视图控制器：

```swift
    /// 显示面板（若已显示则忽略，保证状态机单一性）。
    /// - Parameter contentController: 面板内容视图控制器（nil 时使用空内容）
    func showPanel(contentController: NSViewController? = nil)
    {
        guard !isPanelVisible else
        {
            LogCategory.ui.info("QuickPaste panel already visible, ignore show request")
            return
        }

        let panel = makePanel()
        self.panel = panel

        if let contentController = contentController
        {
            panel.contentViewController = contentController
        }

        let position = screenLocator.locatePosition(lastClosedPosition: lastClosedPosition)
        panel.setFrameOrigin(position)
        panel.makeKeyAndOrderFront(nil)
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            self?.handleDidResignKey()
        }
        isPanelVisible = true
        LogCategory.ui.info("QuickPaste panel shown at position")
    }
```

> **注意**：Phase 1 任务 7 的 `setupQuickPastePanelController()` 调用 `quickPastePanelController?.showPanel()`，现在 `showPanel()` 有默认参数 `contentController: nil`，Phase 1 的调用不需要修改。Phase 3 任务 6 会修改 AppDelegate 传入真实的 contentController。

**第二步**：修改 `ClipMind/UI/QuickPaste/QuickPasteView.swift`，在现有 `init(clips:)` 之后追加 `init(viewModel:)` 初始化器：

```swift
    /// 外部注入 viewModel 的初始化器（供 AppDelegate 注入带 PasteCoordinator 回调的 viewModel）。
    init(viewModel: QuickPasteViewModel)
    {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
```

**第三步**：修改 `ClipMind/App/ClipMindApp.swift` 的 `AppDelegate` 类。

在持有属性区域（`quickPastePanelController` 之后）追加：

```swift
    private var pasteCoordinator: PasteCoordinator?
```

将 `setupQuickPastePanelController()` 方法替换为：

```swift
    /// 初始化快速粘贴面板控制器与粘贴流程协调器（F1.9）。
    private func setupQuickPastePanelController()
    {
        let locator = ScreenCenterPanelLocator()
        let panelController = QuickPastePanelController(screenLocator: locator)
        quickPastePanelController = panelController

        // 创建降级浮层控制器
        let overlayLocator = ScreenCenterOverlayLocator()
        let overlayController = PasteOverlayController(
            consumerWatcher: ClipboardConsumerWatcher(),
            timerScheduler: OverlayTimer(),
            settings: QuickPasteSettings(),
            screenLocator: overlayLocator
        )

        // 创建粘贴流程协调器（Phase 3 使用系统权限检测器，Phase 4 替换为 AccessibilityService）
        let coordinator = PasteCoordinator(
            permissionChecker: SystemPastePermissionChecker(),
            clipboardWriter: ClipboardWriter(),
            panelCloser: panelController,
            overlayShower: overlayController
        )
        pasteCoordinator = coordinator

        // UI 测试启动参数：直接显示面板
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

    /// 创建快速粘贴面板内容视图控制器。
    private func makeQuickPasteContentController(coordinator: PasteCoordinator) -> NSViewController
    {
        let clips = loadClipsForQuickPaste()
        let viewModel = QuickPasteViewModel(clips: clips)
        viewModel.onPasteTriggered = { clip in
            coordinator.handlePaste(clip: clip)
        }
        viewModel.onEscPressed = { [weak self] in
            self?.quickPastePanelController?.handleEscKey()
        }
        let view = QuickPasteView(viewModel: viewModel)
        return NSHostingController(rootView: view)
    }

    /// 加载剪贴项列表（快速粘贴面板数据源）。
    private func loadClipsForQuickPaste() -> [ClipItem]
    {
        do
        {
            let store = try EncryptedStore()
            return store.fetchRecent(limit: 50)
        }
        catch
        {
            LogCategory.storage.error("加载快速粘贴面板数据失败: \(error.localizedDescription)")
            return []
        }
    }
```

在 `AppDelegate` 类末尾（`ScreenCenterPanelLocator` 之后）追加 `ScreenCenterOverlayLocator`：

```swift
    /// 屏幕中央浮层定位器（降级浮层使用）。
    private final class ScreenCenterOverlayLocator: OverlayScreenLocating
    {
        func locatePosition() -> NSPoint
        {
            let screenFrame = NSScreen.main?.frame ?? .zero
            return NSPoint(
                x: screenFrame.midX - 110,
                y: screenFrame.midY - 30
            )
        }
    }
```

同时修改 `handleOpenQuickPaste()` 方法，使其显示面板时传入内容视图控制器：

```swift
    /// F1.9：接收全局快捷键通知，呼出快速粘贴面板。
    @objc private func handleOpenQuickPaste()
    {
        guard let coordinator = pasteCoordinator else { return }
        let contentController = makeQuickPasteContentController(coordinator: coordinator)
        quickPastePanelController?.showPanel(contentController: contentController)
    }
```

- [ ] **6.4 运行测试验证通过**

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

预期：`** TEST SUCCEEDED **`，PasteCoordinator 测试 + PanelController 测试全部通过。

> **注意**：`EncryptedStore.fetchRecent(limit:)` 是现有方法，若方法签名不同需按实际签名调整。若 `fetchRecent` 不存在，使用 `loadClips()` 或等价方法。

- [ ] **6.5 运行 SwiftLint**

```bash
swiftlint lint --strict
```

预期：零违规。

- [ ] **6.6 Commit**

```bash
git add ClipMind/UI/QuickPaste/QuickPastePanelController.swift ClipMind/UI/QuickPaste/QuickPasteView.swift ClipMind/App/ClipMindApp.swift ClipMindTests/UI/PasteCoordinatorTests.swift
git commit -m "feat(quick-paste): wire PasteCoordinator into AppDelegate and QuickPasteView"
```

---

## 任务 7：UI 测试 - 降级浮层显示 + 消费消失 + 超时消失（AC-F1.9-7）

**文件：**
- 修改：`ClipMindUITests/QuickPasteOverlayUITests.swift`（追加 UI 测试）

### 步骤

- [ ] **7.1 编写失败的测试**

在 `ClipMindUITests/QuickPasteOverlayUITests.swift` 末尾追加：

```swift
    // MARK: - TC-F1.9-7-01 无权限时双击降级粘贴流程

    func testDegradedPaste_ShowsOverlay_OnDoubleClick()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREPOPULATE_SAMPLE_AND_REAL",
            "--UITEST_QUICK_PASTE_PANEL",
            "--UITEST_FORCE_NO_PERMISSION"
        ]
        app.launch()

        let firstRow = app.descendants(matching: .any)["quickPasteRow_0_selected"].firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))

        firstRow.doubleClick()

        let overlayMessage = app.descendants(matching: .any)["pasteOverlayMessage"].firstMatch
        XCTAssertTrue(overlayMessage.waitForExistence(timeout: 3), "应显示降级浮层")
    }

    // MARK: - TC-F1.9-7-03 降级浮层在超时兜底后消失（默认 5 秒，测试用 1 秒加速）

    func testOverlay_Disappears_OnTimeout()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREPOPULATE_SAMPLE_AND_REAL",
            "--UITEST_QUICK_PASTE_PANEL",
            "--UITEST_FORCE_NO_PERMISSION",
            "--UITEST_OVERLAY_TIMEOUT_1S"
        ]
        app.launch()

        let firstRow = app.descendants(matching: .any)["quickPasteRow_0_selected"].firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
        firstRow.doubleClick()

        let overlayMessage = app.descendants(matching: .any)["pasteOverlayMessage"].firstMatch
        XCTAssertTrue(overlayMessage.waitForExistence(timeout: 3), "浮层应显示")

        // 等待超时消失（1 秒 + 余量）
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == NO"),
            object: overlayMessage
        )
        wait(for: [expectation], timeout: 5.0)
        XCTAssertFalse(overlayMessage.exists, "超时后浮层应消失")
    }

    // MARK: - TC-F1.9-7-02 降级浮层在剪贴板被消费后消失

    func testOverlay_Disappears_OnClipboardConsumption()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREPOPULATE_SAMPLE_AND_REAL",
            "--UITEST_QUICK_PASTE_PANEL",
            "--UITEST_FORCE_NO_PERMISSION",
            "--UITEST_SIMULATE_CONSUMPTION_AFTER_1S"
        ]
        app.launch()

        let firstRow = app.descendants(matching: .any)["quickPasteRow_0_selected"].firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
        firstRow.doubleClick()

        let overlayMessage = app.descendants(matching: .any)["pasteOverlayMessage"].firstMatch
        XCTAssertTrue(overlayMessage.waitForExistence(timeout: 3), "浮层应显示")

        // 等待消费模拟触发浮层消失
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == NO"),
            object: overlayMessage
        )
        wait(for: [expectation], timeout: 5.0)
        XCTAssertFalse(overlayMessage.exists, "消费后浮层应消失")
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
  -only-testing ClipMindUITests/QuickPasteOverlayUITests/testDegradedPaste_ShowsOverlay_OnDoubleClick \
  -only-testing ClipMindUITests/QuickPasteOverlayUITests/testOverlay_Disappears_OnTimeout \
  -only-testing ClipMindUITests/QuickPasteOverlayUITests/testOverlay_Disappears_OnClipboardConsumption \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：测试失败，因为 `--UITEST_FORCE_NO_PERMISSION`、`--UITEST_OVERLAY_TIMEOUT_1S`、`--UITEST_SIMULATE_CONSUMPTION_AFTER_1S` 启动参数未实现。

- [ ] **7.3 编写最少实现代码**

修改 `ClipMind/App/ClipMindApp.swift` 的 `setupQuickPastePanelController()` 方法，在创建 `PasteOverlayController` 之前根据启动参数注入测试用 mock：

```swift
    /// 初始化快速粘贴面板控制器与粘贴流程协调器（F1.9）。
    private func setupQuickPastePanelController()
    {
        let locator = ScreenCenterPanelLocator()
        let panelController = QuickPastePanelController(screenLocator: locator)
        quickPastePanelController = panelController

        // UI 测试启动参数：强制无权限（避免依赖真实辅助功能权限状态）
        let permissionChecker: PastePermissionChecking
        if CommandLine.arguments.contains("--UITEST_FORCE_NO_PERMISSION")
        {
            permissionChecker = UITestNoPermissionChecker()
        }
        else
        {
            permissionChecker = SystemPastePermissionChecker()
        }

        // UI 测试启动参数：超时 1 秒加速
        let settings: QuickPasteSettings
        if CommandLine.arguments.contains("--UITEST_OVERLAY_TIMEOUT_1S")
        {
            let testDefaults = UserDefaults.standard
            testDefaults.set(1.0, forKey: "F1.9.quickPaste.overlayDuration")
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

        let coordinator = PasteCoordinator(
            permissionChecker: permissionChecker,
            clipboardWriter: ClipboardWriter(),
            panelCloser: panelController,
            overlayShower: overlayController
        )
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

在 `AppDelegate` 类末尾（`ScreenCenterOverlayLocator` 之后）追加 UI 测试辅助类：

```swift
    /// UI 测试专用：始终返回无权限的权限检测器。
    private final class UITestNoPermissionChecker: PastePermissionChecking
    {
        func isAccessibilityGranted() -> Bool { false }
    }

    /// UI 测试专用：延迟后模拟消费的监听器。
    private final class UITestSimulatedConsumerWatcher: ClipboardConsumerWatcherProtocol
    {
        private let delay: TimeInterval
        private var workItem: DispatchWorkItem?

        init(delay: TimeInterval)
        {
            self.delay = delay
        }

        func start(onConsumed: @escaping () -> Void)
        {
            let workItem = DispatchWorkItem
            {
                onConsumed()
            }
            self.workItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        }

        func stop()
        {
            workItem?.cancel()
            workItem = nil
        }
    }
```

- [ ] **7.4 运行测试验证通过**

运行同 7.2 的命令。

预期：`** TEST SUCCEEDED **`，3 个 UI 测试通过。

- [ ] **7.5 运行 SwiftLint**

```bash
swiftlint lint --strict
```

预期：零违规。

- [ ] **7.6 Commit**

```bash
git add ClipMind/App/ClipMindApp.swift ClipMindUITests/QuickPasteOverlayUITests.swift
git commit -m "test(overlay): add UI tests for degraded overlay show, timeout, and consumption"
```

---

## 任务 8：UI 测试 - 超时配置变更立即生效 + 权限撤销降级逻辑（AC-F1.9-7, 12）

**文件：**
- 修改：`ClipMindUITests/QuickPasteOverlayUITests.swift`（追加 UI 测试）

### 步骤

- [ ] **8.1 编写失败的测试**

在 `ClipMindUITests/QuickPasteOverlayUITests.swift` 末尾追加：

```swift
    // MARK: - TC-F1.9-7-04 超时配置变更为 10 秒后立即生效

    func testOverlayTimeout_ConfigChangeTakesEffectImmediately()
    {
        // 第一次：配置 10 秒超时，验证 5 秒内浮层不消失
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREPOPULATE_SAMPLE_AND_REAL",
            "--UITEST_QUICK_PASTE_PANEL",
            "--UITEST_FORCE_NO_PERMISSION"
        ]
        // 启动前预设 10 秒超时配置（验证配置变更立即生效）
        UserDefaults.standard.set(10.0, forKey: "F1.9.quickPaste.overlayDuration")
        app.launch()

        let firstRow = app.descendants(matching: .any)["quickPasteRow_0_selected"].firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))
        firstRow.doubleClick()

        let overlayMessage = app.descendants(matching: .any)["pasteOverlayMessage"].firstMatch
        XCTAssertTrue(overlayMessage.waitForExistence(timeout: 3), "浮层应显示")

        // 验证浮层在 5 秒内不消失（配置为 10 秒）
        // isInverted = true：谓词 exists == NO 在 timeout 内未满足才算 fulfill
        let notDisappearedExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == NO"),
            object: overlayMessage
        )
        notDisappearedExpectation.isInverted = true
        wait(for: [notDisappearedExpectation], timeout: 5.0)
        XCTAssertTrue(overlayMessage.exists, "配置 10 秒后，5 秒内浮层应仍存在")

        // 第二次：修改配置为 3 秒超时，验证 4 秒内浮层消失
        app.terminate()
        UserDefaults.standard.set(3.0, forKey: "F1.9.quickPaste.overlayDuration")

        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREPOPULATE_SAMPLE_AND_REAL",
            "--UITEST_QUICK_PASTE_PANEL",
            "--UITEST_FORCE_NO_PERMISSION"
        ]
        app.launch()

        let firstRow2 = app.descendants(matching: .any)["quickPasteRow_0_selected"].firstMatch
        XCTAssertTrue(firstRow2.waitForExistence(timeout: 5))
        firstRow2.doubleClick()

        let overlayMessage2 = app.descendants(matching: .any)["pasteOverlayMessage"].firstMatch
        XCTAssertTrue(overlayMessage2.waitForExistence(timeout: 3), "浮层应再次显示")

        // 验证浮层在 4 秒内消失（配置为 3 秒，isInverted = false：谓词满足即 fulfill）
        let disappearExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == NO"),
            object: overlayMessage2
        )
        wait(for: [disappearExpectation], timeout: 4.0)
        XCTAssertFalse(overlayMessage2.exists, "配置 3 秒后，4 秒内浮层应消失")

        // 清理配置
        UserDefaults.standard.removeObject(forKey: "F1.9.quickPaste.overlayDuration")
    }

    // MARK: - TC-F1.9-12-01 权限撤销时自动降级（UI 层验证降级路径）

    func testPermissionRevoked_FallsBackToDegradedPath()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREPOPULATE_SAMPLE_AND_REAL",
            "--UITEST_QUICK_PASTE_PANEL",
            "--UITEST_FORCE_NO_PERMISSION",
            "--UITEST_OVERLAY_TIMEOUT_1S"
        ]
        app.launch()

        let firstRow = app.descendants(matching: .any)["quickPasteRow_0_selected"].firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5))

        // 验证无权限时走降级路径（显示浮层）
        firstRow.doubleClick()
        let overlayMessage = app.descendants(matching: .any)["pasteOverlayMessage"].firstMatch
        XCTAssertTrue(overlayMessage.waitForExistence(timeout: 3), "无权限时应显示降级浮层")

        // 等待浮层超时消失
        let disappearExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == NO"),
            object: overlayMessage
        )
        wait(for: [disappearExpectation], timeout: 5.0)
    }
```

- [ ] **8.2 运行测试验证失败**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.9-quick-paste-panel
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindUITests/QuickPasteOverlayUITests/testOverlayTimeout_ConfigChangeTakesEffectImmediately \
  -only-testing ClipMindUITests/QuickPasteOverlayUITests/testPermissionRevoked_FallsBackToDegradedPath \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：第一个测试可能因 `--UITEST_OVERLAY_TIMEOUT_3S` 未实现而失败；第二个测试应通过（任务 7 已实现 `--UITEST_FORCE_NO_PERMISSION` 和 `--UITEST_OVERLAY_TIMEOUT_1S`）。

- [ ] **8.3 编写最少实现代码**

修改 `ClipMind/App/ClipMindApp.swift` 的 `setupQuickPastePanelController()` 方法中的超时配置分支，增加 3 秒选项：

将现有的超时配置分支：

```swift
        let settings: QuickPasteSettings
        if CommandLine.arguments.contains("--UITEST_OVERLAY_TIMEOUT_1S")
        {
            let testDefaults = UserDefaults.standard
            testDefaults.set(1.0, forKey: "F1.9.quickPaste.overlayDuration")
            settings = QuickPasteSettings(defaults: testDefaults)
        }
        else
        {
            settings = QuickPasteSettings()
        }
```

替换为：

```swift
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
```

> **说明**：`testOverlayTimeout_ConfigChangeTakesEffectImmediately` 测试通过直接修改 `UserDefaults.standard` 验证配置变更立即生效。第二次启动时 `QuickPasteSettings()` 默认使用 `.standard`，会读取到 10.0 秒配置。`PasteOverlayController` 在 `showOverlay()` 时调用 `settings.loadOverlayDuration()` 读取最新值，确保配置变更立即生效（FR-014）。

- [ ] **8.4 运行测试验证通过**

运行同 8.2 的命令。

预期：`** TEST SUCCEEDED **`，2 个 UI 测试通过。

> **注意**：超时配置变更测试涉及多次启动应用和等待真实超时，在 CI 环境可能不稳定。若不稳定，标记 `XCTSkip` 并记录到手动验收。本地 macOS 15 应能通过。

- [ ] **8.5 运行 SwiftLint**

```bash
swiftlint lint --strict
```

预期：零违规。

- [ ] **8.6 运行 Phase 3 全量测试（回归验证）**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.9-quick-paste-panel
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindTests/ClipboardWriterTests \
  -only-testing ClipMindTests/ClipboardConsumerWatcherTests \
  -only-testing ClipMindTests/PasteOverlayControllerTests \
  -only-testing ClipMindTests/PasteCoordinatorTests \
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

预期：`** TEST SUCCEEDED **`，Phase 3 全部测试通过 + Phase 1/2 无回归。

- [ ] **8.7 Commit**

```bash
git add ClipMind/App/ClipMindApp.swift ClipMindUITests/QuickPasteOverlayUITests.swift
git commit -m "test(overlay): add UI tests for config change effect and permission revocation fallback"
```

---

## UI 证据任务

> **证据保存约定（Phase 3）**
>
> - **截图路径模板**：`docs/planning/P0/F1/screenshots/F1.9/phase3-ACx-场景描述.png`
> - **录屏路径模板**：`docs/planning/P0/F1/recordings/F1.9/phase3-ACx-场景描述.mov`
> - **保存规则**：
>   1. XCUITest 通过后，运行该测试用例时通过 `XCUIScreenshot` 附件捕获截图，保存到上述截图路径（文件名见各条目「证据保存」）。
>   2. 涉及真实环境交互的条目（标「手动补充」），发布前手动执行并录屏，保存到上述录屏路径。
>   3. 路径中 `phase3` 为 Phase 编号，`ACx` 为对应验收条件编号，`场景描述` 用中文简述场景。
>   4. 截图/录屏文件提交到仓库，作为发布前人工审查证据。

### UI-AC-F1.9-7-01：无权限时双击降级粘贴流程

**对应 AC**：AC-F1.9-7
**对应测试**：`QuickPasteOverlayUITests.testDegradedPaste_ShowsOverlay_OnDoubleClick`
**证据方式**：XCUITest 自动化（通过 `--UITEST_FORCE_NO_PERMISSION` 启动参数强制无权限，双击文本行验证降级浮层出现）+ 单元测试 `PasteCoordinatorTests.testHandlePaste_NoPermission_WritesClipboard_ClosesPanel_ShowsOverlay`（验证写入剪贴板 + 关闭面板 + 显示浮层）
**证据保存**：
- 截图：`docs/planning/P0/F1/screenshots/F1.9/phase3-AC7-降级浮层出现.png`（XCUITest 通过后捕获）

### UI-AC-F1.9-7-02：降级浮层在剪贴板被消费后消失

**对应 AC**：AC-F1.9-7
**对应测试**：`QuickPasteOverlayUITests.testOverlay_Disappears_OnClipboardConsumption`
**证据方式**：XCUITest 自动化（通过 `--UITEST_SIMULATE_CONSUMPTION_AFTER_1S` 启动参数模拟消费，验证浮层消失）+ 单元测试 `PasteOverlayControllerTests.testHideOverlay_OnConsumption_Disappears`
**证据保存**：
- 截图：`docs/planning/P0/F1/screenshots/F1.9/phase3-AC7-消费后浮层消失.png`（XCUITest 通过后捕获）

### UI-AC-F1.9-7-03：降级浮层在超时兜底后消失

**对应 AC**：AC-F1.9-7
**对应测试**：`QuickPasteOverlayUITests.testOverlay_Disappears_OnTimeout`
**证据方式**：XCUITest 自动化（通过 `--UITEST_OVERLAY_TIMEOUT_1S` 启动参数设置 1 秒超时，验证浮层超时消失）+ 单元测试 `PasteOverlayControllerTests.testHideOverlay_OnTimeout_Disappears`
**证据保存**：
- 截图：`docs/planning/P0/F1/screenshots/F1.9/phase3-AC7-超时浮层消失.png`（XCUITest 通过后捕获）

### UI-AC-F1.9-7-04：超时配置变更立即生效

**对应 AC**：AC-F1.9-7
**对应测试**：`QuickPasteOverlayUITests.testOverlayTimeout_ConfigChangeTakesEffectImmediately`
**证据方式**：XCUITest 自动化（第一次 3 秒超时验证消失，第二次改配置为 10 秒验证 5 秒时仍存在）+ 单元测试 `PasteOverlayControllerTests.testShowOverlay_ReadsTimeoutDurationFromSettings`
**证据保存**：
- 截图：`docs/planning/P0/F1/screenshots/F1.9/phase3-AC7-超时配置立即生效.png`（XCUITest 通过后捕获）

---

## 合规风险评估

### 合规风险：低（纯沙盒实现）

Phase 3 的所有实现纯沙盒内完成，完全 App Store 合规：

| 模块 | 使用的 API | 合规性 |
|------|-----------|--------|
| ClipboardWriter | `NSPasteboard.setString` | 公开 API，沙盒内 |
| ClipboardConsumerWatcher | `NSPasteboard.changeCount` | 公开 API，沙盒内 |
| PasteOverlayController | `NSPanel` + `NSHostingView` | 公开 API，沙盒内 |
| PasteCoordinator | `PermissionRequester.axTrustedCheck(false)` | 公开 API，仅查询不弹 TCC |
| GeneralSettingsView | `Stepper` + `QuickPasteSettings` | 公开 API，沙盒内 |

### 关键合规约束遵守

1. **不弹 TCC 提示对话框**：`SystemPastePermissionChecker` 调用 `PermissionRequester.axTrustedCheck(false)`，`prompt: false` 不弹 TCC（需求文档第 11.2 节）
2. **不缓存权限状态**：`PasteCoordinator.handlePaste(clip:)` 每次调用都重新检测权限（AC-F1.9-12，设计文档第 7.2 节）
3. **不输出剪贴板原文**：`ClipboardWriter` 日志仅记录文本长度，不记录原文（NFR-003）
4. **浮层不显示原文**：`PasteOverlayController.overlayMessage` 硬编码为"已复制，按 Cmd+V 粘贴"（NFR-003，设计文档第 7.5 节）
5. **不用 sleep 等待异步**：`ClipboardConsumerWatcher` 用 `DispatchSourceTimer` 轮询，`OverlayTimer` 用 `DispatchSourceTimer` 调度超时（CODING_STANDARDS）

---

## 合并基线

Phase 3 完成后应满足：

1. `swiftlint lint --strict` 零违规
2. `xcodebuild test` 全量通过（Phase 3 新增测试 + Phase 1/2 无回归 + 菜单栏 popover 无回归）
3. `xcodebuild build` 编译成功
4. 8 个任务全部 commit，每个 commit 的 SwiftLint 已通过
5. 文档同步：在 `docs/planning/P0/F1/historys/` 追加 `2026-07-23-F1.9-Phase3-无权限降级完成.md`

**关键回归点**：
- Phase 1 的 `QuickPastePanelController` 测试（验证 `showPanel(contentController:)` 默认参数不破坏现有调用）
- Phase 2 的 `QuickPasteView` 测试（验证 `init(viewModel:)` 不破坏 `init(clips:)`）
- 菜单栏 popover 的 `PopoverUITests` 必须全通过

---

## 手动验收（发布前补充）

1. 在真实环境无辅助功能权限时，双击文本行验证降级浮层出现，文案为"已复制，按 Cmd+V 粘贴"
2. 在其他应用按 Cmd+V 粘贴后，验证浮层立即消失（消费触发）
3. 不操作剪贴板，等待 5 秒（默认），验证浮层超时消失
4. 在设置面板调整浮层超时为 10 秒，再次触发降级粘贴，验证 10 秒后浮层消失
5. 在系统设置中撤销辅助功能权限，触发粘贴，验证自动走降级路径
6. 验证浮层不抢夺前台应用焦点（浮层显示时前台应用仍可输入）
7. 验证日志不包含剪贴板原文（收集控制台日志检查）

---

## 版本记录

| 版本 | 日期 | 变更说明 |
|------|------|---------|
| v1.0 | 2026-07-23 | 初始版本，Phase 3 无权限降级，8 任务 48 TDD 步骤，4 UI 证据任务，覆盖 AC-F1.9-7, AC-F1.9-10 无权限路径, AC-F1.9-12 降级逻辑, TC-F1.9-SEC-02，纯沙盒合规无风险 |
| v1.1 | 2026-07-23 | 修订（Fix 1/5/8/19/15）：NSPasteboard(name:) 4 处修正为 NSPasteboard.Name("ClipMindTestPasteboard")；文件计数修正为 8 个；PasteOverlayController 加 @MainActor；testOverlayTimeout_ConfigChangeTakesEffectImmediately 重写（删除死代码 stillVisibleExpectation，用 isInverted 验证 N 秒内不消失/消失）；UI 证据任务补充证据保存路径 |
| v1.2 | 2026-07-23 | 修复第二轮 check-plan 发现的 8 项必须修复项（文件计数、Fix 10 行为一致性、UI 测试 import/identifier/谓词） |
| v1.3 | 2026-07-23 | 修复第三轮 check-plan 发现的 4 项必须修复项（phase-1/3 任务数标题误改、Phase 3 任务 4.3 实现与测试断言一致、QuickPastePanelUITests 补 import AppKit） |
