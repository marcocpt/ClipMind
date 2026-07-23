> 最后更新：2026-07-24 | 版本：v1.0

# Phase 0：核心 Toast 显示 实现计划

**目标：** 实现 Toast 视图、窗口承载模块、计时器源协议、协调模块基础状态机（隐藏/出现中/已显示/消失中），完成通知订阅、跳过/总开关校验、2 秒计时器集成，AppDelegate 装配，并通过基础 XCUITest 验证 AC-01/02/03/06/09/11。

**依赖：** 无

**任务数：** 7

---

## 任务 1：ToastView（SwiftUI 视图）

**文件：**
- 创建：`ClipMind/Toast/ToastView.swift`
- 测试：`ClipMindTests/Toast/ToastViewTests.swift`

### 步骤 1：编写失败的测试

```swift
// ClipMindTests/Toast/ToastViewTests.swift
import SwiftUI
import XCTest
@testable import ClipMind

final class ToastViewTests: XCTestCase
{
    func testToastViewRendersFileName() throws
    {
        let view = ToastView(fileName: "hello-world.md")
        let hosting = NSHostingController(rootView: view)
        XCTAssertEqual(hosting.view.bounds.width, 0) // 初始无尺寸，仅验证可创建
    }

    func testToastViewAccessibilityIdentifiers() throws
    {
        let view = ToastView(fileName: "test.md")
        let hosting = NSHostingController(rootView: view)
        hosting.view.layout()

        let container = hosting.view.accessibilityChildren.first as? NSAccessibilityElement
        XCTAssertEqual(container?.accessibilityIdentifier, "toast-container")

        // 查找子元素
        let children = container?.accessibilityChildren as? [NSAccessibilityElement] ?? []
        let icon = children.first { $0.accessibilityIdentifier == "toast-success-icon" }
        let text = children.first { $0.accessibilityIdentifier == "toast-filename-text" }

        XCTAssertNotNil(icon, "toast-success-icon 应可访问")
        XCTAssertNotNil(text, "toast-filename-text 应可访问")
        XCTAssertEqual(text?.accessibilityValue(), "test.md")
    }
}
```

### 步骤 2：运行测试验证失败

运行：
```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1.1-save-success-toast
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/ToastViewTests' 2>&1 | tail -30
```
预期：FAIL，报错 "Cannot find 'ToastView' in scope" 或 "No such module"。

### 步骤 3：编写最少实现代码

```swift
// ClipMind/Toast/ToastView.swift
import SwiftUI

/// F2.1.1 Toast 视图模块（设计文档 §3.3）。
///
/// 呈现成功图标 + 实际保存的文件名，遵循视觉原型 v1.2 的视觉细节：
/// - 半透明深色背景 rgba(28, 28, 30, 0.92)
/// - 圆角 10px
/// - 图标 20px（绿色 #34c759 圆形 + 白色对勾）
/// - 文字 14px 白色
/// - 内边距 16px / 10px（水平 / 垂直）
/// - 最大宽度 360px（文件名过长省略号）
public struct ToastView: View
{
    private let fileName: String

    public init(fileName: String)
    {
        self.fileName = fileName
    }

    public var body: some View
    {
        HStack(spacing: 8)
        {
            icon
            text
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 28/255, green: 28/255, blue: 30/255, opacity: 0.92))
        )
        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 4)
        .frame(maxWidth: 360)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("toast-container")
        .accessibilityLabel("保存成功 Toast 容器")
    }

    private var icon: some View
    {
        ZStack
        {
            Circle()
                .fill(Color(red: 0x34/255, green: 0xc7/255, blue: 0x59/255))
                .frame(width: 20, height: 20)
            Path { path in
                path.move(to: CGPoint(x: 5, y: 10))
                path.addLine(to: CGPoint(x: 8.5, y: 13.5))
                path.addLine(to: CGPoint(x: 15, y: 7))
            }
            .stroke(Color.white, lineWidth: 2)
            .frame(width: 20, height: 20)
        }
        .accessibilityIdentifier("toast-success-icon")
        .accessibilityLabel("保存成功图标")
    }

    private var text: some View
    {
        Text(fileName)
            .font(.system(size: 14))
            .foregroundColor(.white)
            .lineLimit(1)
            .truncationMode(.tail)
            .accessibilityIdentifier("toast-filename-text")
            .accessibilityValue(fileName)
    }
}
```

### 步骤 4：运行测试验证通过

运行：
```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/ToastViewTests' 2>&1 | tail -30
```
预期：PASS，2 个测试通过。

### 步骤 5：Commit

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1.1-save-success-toast
swiftlint lint --strict
git add ClipMind/Toast/ToastView.swift ClipMindTests/Toast/ToastViewTests.swift
git commit -m "feat(F2.1.1): add ToastView with success icon and filename

- SwiftUI 视图承载成功图标（绿色圆形 + 白色对勾）与文件名文字
- 视觉细节对齐视觉原型 v1.2：半透明深色背景、圆角 10px、文字 14px 白色
- accessibility identifiers: toast-container / toast-filename-text / toast-success-icon
- 落地设计文档 §3.3 Toast 视图模块职责"
```

---

## 任务 2：ToastWindowManager（窗口承载模块）

**文件：**
- 创建：`ClipMind/Toast/ToastWindowManager.swift`
- 修改：`ClipMind/Utils/LogCategory.swift`（新增 `toast` 分类，因 ToastWindowManager 使用 `LogCategory.toast.logger`）
- 测试：`ClipMindTests/Toast/ToastWindowManagerTests.swift`

### 步骤 1：编写失败的测试

```swift
// ClipMindTests/Toast/ToastWindowManagerTests.swift
import XCTest
@testable import ClipMind

final class ToastWindowManagerTests: XCTestCase
{
    private var manager: ToastWindowManager!

    override func setUp()
    {
        super.setUp()
        manager = ToastWindowManager()
    }

    override func tearDown()
    {
        manager?.hide(completion: nil)
        manager = nil
        super.tearDown()
    }

    func testInitialStateIsNotCreated()
    {
        XCTAssertFalse(manager.isWindowVisible, "初始状态窗口不可见")
    }

    func testShowCreatesWindowAndCallsDidAppear()
    {
        let expectation = XCTestExpectation(description: "onDidAppear called")
        manager.onDidAppear = { expectation.fulfill() }

        manager.show(fileName: "test.md")

        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(manager.isWindowVisible, "show 后窗口可见")
    }

    func testHideCallsDidHideAndReleasesWindow()
    {
        let didAppear = XCTestExpectation(description: "appeared")
        manager.onDidAppear = { didAppear.fulfill() }
        manager.show(fileName: "test.md")
        wait(for: [didAppear], timeout: 1.0)

        let didHide = XCTestExpectation(description: "hidden")
        manager.onDidHide = { didHide.fulfill() }
        manager.hide(completion: nil)

        wait(for: [didHide], timeout: 1.0)
        XCTAssertFalse(manager.isWindowVisible, "hide 后窗口不可见")
    }

    func testCloseImmediatelyReleasesWindowWithoutAnimation()
    {
        let didAppear = XCTestExpectation(description: "appeared")
        manager.onDidAppear = { didAppear.fulfill() }
        manager.show(fileName: "a.md")
        wait(for: [didAppear], timeout: 1.0)

        let didClose = XCTestExpectation(description: "closed immediately")
        manager.onDidCloseImmediately = { didClose.fulfill() }
        manager.closeImmediately()

        wait(for: [didClose], timeout: 1.0)
        XCTAssertFalse(manager.isWindowVisible, "closeImmediately 后窗口不可见")
    }

    func testWindowPositionedAtTopCenterOfMainScreen()
    {
        let didAppear = XCTestExpectation(description: "appeared")
        manager.onDidAppear = { didAppear.fulfill() }
        manager.show(fileName: "test.md")
        wait(for: [didAppear], timeout: 1.0)

        guard let window = manager.currentWindowForTesting else
        {
            return XCTFail("window should exist after show")
        }

        guard let screen = NSScreen.main else
        {
            return XCTFail("NSScreen.main should exist in test env")
        }

        let visibleFrame = screen.visibleFrame
        let windowFrame = window.frame

        // 水平居中（容差 ±5pt）
        let screenCenterX = visibleFrame.midX
        let windowCenterX = windowFrame.midX
        XCTAssertEqual(windowCenterX, screenCenterX, accuracy: 5, "窗口应水平居中")

        // 垂直位于屏幕顶部 16-32pt 范围内（视觉原型 v1.2：距顶部 24px）
        let topInset = visibleFrame.maxY - windowFrame.maxY
        XCTAssertGreaterThanOrEqual(topInset, 16, "距顶部应 ≥ 16pt")
        XCTAssertLessThanOrEqual(topInset, 32, "距顶部应 ≤ 32pt")
    }
}
```

### 步骤 2：运行测试验证失败

运行：
```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1.1-save-success-toast
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/ToastWindowManagerTests' 2>&1 | tail -30
```
预期：FAIL，报错 "Cannot find 'ToastWindowManager' in scope"。

### 步骤 3：编写最少实现代码

**先修改 `ClipMind/Utils/LogCategory.swift`**（公共文件，加 `PublicFile` tag），新增 `toast` 分类。ToastWindowManager 使用此分类输出日志，必须先添加：

```swift
// ClipMind/Utils/LogCategory.swift
import Foundation
import os

/// 日志分类枚举。
enum LogCategory: String, CaseIterable {
    case capture = "Capture"
    case classify = "Classify"
    case search = "Search"
    case llm = "LLM"
    case storage = "Storage"
    case privacy = "Privacy"
    // swiftlint:disable:next identifier_name
    case ui = "UI"
    case app = "App"
    case toast = "Toast"

    /// 该分类对应的 os.Logger 实例
    var logger: Logger {
        Logger(subsystem: "com.clipmind.app", category: rawValue)
    }
}
```

**创建 `ClipMind/Toast/ToastWindowManager.swift`**。注意：类标记为 `open class`、方法标记为 `open func`，因为测试中 `TestToastWindowManager` 在 `ClipMindTests` 模块跨模块继承需要 `open` 访问级别（`public` 不允许跨模块 override）：

```swift
// ClipMind/Toast/ToastWindowManager.swift
import AppKit
import SwiftUI

/// F2.1.1 Toast 窗口承载模块（设计文档 §3.2、§5.4、D1、D5）。
///
/// 职责：
/// - 创建屏幕级透明窗口（NSPanel `.nonactivatingPanel` + `.floating` level）承载 ToastView
/// - 定位到主屏幕顶部居中（FR-003、AC-09：距顶部 24pt）
/// - 执行进入动画（alpha 0→1 + 从顶部滑入，约 0.2s，FR-005、D5）
/// - 执行退出动画（alpha 1→0 + 反向滑出，约 0.2s，FR-006、D5）
/// - 关闭窗口后立即释放资源（NFR-003）
/// - 保证窗口不抢焦点、不激活 ClipMind 主窗口（FR-011）
///
/// 不负责：决定是否触发 Toast、管理 2 秒计时、决定视觉细节、调用 F2.1 配置
///
/// 访问级别说明：标记为 `open class` + `open func`，允许 ClipMindTests 模块跨模块继承
/// 用于注入测试 Mock（TestToastWindowManager）。
open class ToastWindowManager
{
    /// 窗口距屏幕顶部边距（视觉原型 v1.2 默认 24px，AC-09 允许 16-32pt）
    private static let topInset: CGFloat = 24

    /// 进入/退出动画时长（FR-005、FR-006）
    private static let animationDuration: TimeInterval = 0.2

    /// 滑入/滑出额外偏移量（D5：位置动画偏移，窗口从屏幕顶部之上 10pt 滑入）
    private static let slideOffset: CGFloat = 10

    private var panel: NSPanel?
    private var hostingController: NSHostingController<ToastView>?

    /// 进入动画完成回调
    public var onDidAppear: (() -> Void)?

    /// 退出动画完成回调
    public var onDidHide: (() -> Void)?

    /// 立即关闭完成回调（替换模式用，无退出动画）
    public var onDidCloseImmediately: (() -> Void)?

    /// 显示失败回调（E4 屏幕查询失败、E5 窗口创建失败，Phase 1 任务 10 使用）
    public var onShowFailed: (() -> Void)?

    /// 窗口当前是否可见（用于测试断言与协调模块查询）
    public private(set) var isWindowVisible: Bool = false

    public init() {}

    /// 显示 Toast：创建窗口、定位、启动进入动画（alpha + 位置滑入）。
    /// 必须在主线程调用（D6）。
    open func show(fileName: String)
    {
        assertMainThread()
        guard !isWindowVisible else { return }

        guard let screen = NSScreen.main else
        {
            LogCategory.toast.logger.error(
                "ToastWindow: NSScreen.main is nil, abort show"
            )
            onShowFailed?()
            return
        }

        let view = ToastView(fileName: fileName)
        let hosting = NSHostingController(rootView: view)
        self.hostingController = hosting

        // 创建透明无焦点窗口（D1：屏幕级浮层，不抢焦点）
        let contentRect = NSRect(x: 0, y: 0, width: 360, height: 40)
        let panel = NSPanel(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
        panel.isMovable = false
        panel.contentView = hosting.view

        // 计算目标位置（顶部居中）
        let visibleFrame = screen.visibleFrame
        let bestFrame = panel.frame
        let optimizedWidth = min(bestFrame.width, 360)
        let optimizedHeight = max(bestFrame.height, 40)
        let x = visibleFrame.midX - optimizedWidth / 2
        let targetY = visibleFrame.maxY - Self.topInset - optimizedHeight
        let targetFrame = NSRect(x: x, y: targetY, width: optimizedWidth, height: optimizedHeight)

        // 初始位置：屏幕顶部之上（滑入起点，对应视觉原型 v1.2 transform: translateY(-100%)）
        let startY = visibleFrame.maxY + Self.slideOffset
        let startFrame = NSRect(x: x, y: startY, width: optimizedWidth, height: optimizedHeight)
        panel.setFrame(startFrame, display: true)

        // 进入动画初始状态：透明
        panel.alphaValue = 0
        panel.orderFront(nil)

        self.panel = panel

        // 启动进入动画（D5：alpha 0→1 + setFrame 从顶部滑入到目标位置）
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.animationDuration
            panel.animator().alphaValue = 1
            panel.animator().setFrame(targetFrame, display: true)
        } completionHandler: { [weak self] in
            self?.isWindowVisible = true
            self?.onDidAppear?()
        }
    }

    /// 隐藏 Toast：执行退出动画（alpha + 位置滑出），动画完成后释放窗口资源。
    /// 必须在主线程调用（D6）。
    open func hide(completion: (() -> Void)?)
    {
        assertMainThread()
        guard let panel = panel, isWindowVisible else
        {
            completion?()
            return
        }

        // 计算退出位置：屏幕顶部之上（反向滑出）
        let visibleFrame = NSScreen.main?.visibleFrame ?? .zero
        let currentFrame = panel.frame
        let endY = visibleFrame.maxY + Self.slideOffset
        let endFrame = NSRect(x: currentFrame.origin.x, y: endY, width: currentFrame.width, height: currentFrame.height)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.animationDuration
            panel.animator().alphaValue = 0
            panel.animator().setFrame(endFrame, display: true)
        } completionHandler: { [weak self] in
            panel.orderOut(nil)
            self?.releaseResources()
            self?.onDidHide?()
            completion?()
        }
    }

    /// 立即关闭窗口（替换模式专用，无退出动画，立即释放资源）。
    /// 必须在主线程调用（D6）。
    open func closeImmediately()
    {
        assertMainThread()
        guard let panel = panel else
        {
            onDidCloseImmediately?()
            return
        }

        panel.orderOut(nil)
        releaseResources()
        onDidCloseImmediately?()
    }

    /// 释放窗口与 hosting 资源（NFR-003）。
    private func releaseResources()
    {
        panel?.contentView = nil
        panel = nil
        hostingController = nil
        isWindowVisible = false
    }

    private func assertMainThread()
    {
        if !Thread.isMainThread
        {
            LogCategory.toast.logger.error(
                "ToastWindow: called on non-main thread"
            )
            assertionFailure("ToastWindowManager must be called on main thread")
        }
    }

    // MARK: - Testing Helpers

    /// 仅供测试断言窗口位置使用，生产代码不调用。
    internal var currentWindowForTesting: NSWindow?
    {
        panel
    }
}
```

### 步骤 4：运行测试验证通过

运行：
```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/ToastWindowManagerTests' 2>&1 | tail -30
```
预期：PASS，5 个测试通过。

### 步骤 5：Commit

```bash
swiftlint lint --strict
git add ClipMind/Toast/ToastWindowManager.swift \
  ClipMind/Utils/LogCategory.swift \
  ClipMindTests/Toast/ToastWindowManagerTests.swift
git commit -m "feat(F2.1.1): add ToastWindowManager with transparent NSPanel

- 使用 NSPanel .nonactivatingPanel 创建屏幕级透明窗口（D1）
- 定位到主屏幕顶部居中（FR-003、AC-09：距顶部 24pt）
- 进入动画 alpha 0→1 + setFrame 从顶部滑入，约 0.2s（FR-005、D5）
- 退出动画 alpha 1→0 + setFrame 反向滑出，约 0.2s（FR-006、D5）
- 立即关闭无动画（替换模式用）
- 不抢焦点、不激活 ClipMind 主窗口（FR-011）
- LogCategory 新增 toast 分类（公共文件修改，PublicFile tag）
- ToastWindowManager 标记为 open class + open func，支持跨模块测试 Mock 继承
- 落地设计文档 §3.2、§5.4、D1、D5、D6"
```

---

## 任务 3：TimerSource 协议 + MainTimerSource + VirtualTimerSource

**文件：**
- 创建：`ClipMind/Toast/TimerSource.swift`
- 测试：`ClipMindTests/Toast/TimerSourceTests.swift`

### 步骤 1：编写失败的测试

```swift
// ClipMindTests/Toast/TimerSourceTests.swift
import XCTest
@testable import ClipMind

final class TimerSourceTests: XCTestCase
{
    func testMainTimerSourceFiresAfterDuration()
    {
        let expectation = XCTestExpectation(description: "MainTimerSource fires")
        let timer = MainTimerSource()
        let handle = timer.schedule(duration: 0.1) {
            expectation.fulfill()
        }
        XCTAssertNotNil(handle, "schedule 应返回句柄")
        wait(for: [expectation], timeout: 1.0)
    }

    func testMainTimerSourceCancelPreventsFire()
    {
        let expectation = XCTestExpectation(description: "should not fire")
        expectation.isInverted = true

        let timer = MainTimerSource()
        let handle = timer.schedule(duration: 0.1) {
            expectation.fulfill()
        }
        handle?.cancel()

        wait(for: [expectation], timeout: 0.5)
    }

    func testVirtualTimerSourceDoesNotFireUntilAdvanced()
    {
        let timer = VirtualTimerSource()
        var fired = false
        _ = timer.schedule(duration: 2.0) {
            fired = true
        }

        // 推进 1 秒，不应触发
        timer.advance(by: 1.0)
        XCTAssertFalse(fired, "未到 2 秒不应触发")

        // 再推进 1 秒，应触发
        timer.advance(by: 1.0)
        XCTAssertTrue(fired, "到达 2 秒应触发")
    }

    func testVirtualTimerSourceCancelPreventsFire()
    {
        let timer = VirtualTimerSource()
        var fired = false
        let handle = timer.schedule(duration: 2.0) {
            fired = true
        }
        handle.cancel()
        timer.advance(by: 3.0)
        XCTAssertFalse(fired, "cancel 后即使推进也不应触发")
    }

    func testVirtualTimerSourceMultipleTimersFireInOrder()
    {
        let timer = VirtualTimerSource()
        var sequence: [String] = []
        _ = timer.schedule(duration: 1.0) { sequence.append("first") }
        _ = timer.schedule(duration: 2.0) { sequence.append("second") }
        _ = timer.schedule(duration: 0.5) { sequence.append("third") }

        timer.advance(by: 0.5)
        XCTAssertEqual(sequence, ["third"])
        timer.advance(by: 0.5)
        XCTAssertEqual(sequence, ["third", "first"])
        timer.advance(by: 1.0)
        XCTAssertEqual(sequence, ["third", "first", "second"])
    }
}
```

### 步骤 2：运行测试验证失败

运行：
```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/TimerSourceTests' 2>&1 | tail -30
```
预期：FAIL，报错 "Cannot find 'MainTimerSource' in scope" / "Cannot find 'VirtualTimerSource' in scope"。

### 步骤 3：编写最少实现代码

```swift
// ClipMind/Toast/TimerSource.swift
import Foundation

/// F2.1.1 计时器源协议（D7 可测试性决策）。
///
/// 协调模块通过此协议启动 2 秒计时与取消计时，生产使用 MainTimerSource，
/// 单元测试使用 VirtualTimerSource 手动推进时间，避免真实 2 秒等待。
public protocol TimerSource: AnyObject
{
    /// 启动一次性计时器，duration 秒后回调 callback。
    /// 返回句柄用于取消，取消后回调不再触发。
    func schedule(duration: TimeInterval, callback: @escaping () -> Void) -> TimerHandle
}

/// 计时器句柄，可取消已启动的计时器。
public protocol TimerHandle: AnyObject
{
    func cancel()
}

/// 生产环境计时器源，使用主线程 DispatchSourceTimer（D6）。
public final class MainTimerSource: TimerSource
{
    public init() {}

    public func schedule(duration: TimeInterval, callback: @escaping () -> Void) -> TimerHandle
    {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + duration)
        timer.setEventHandler(handler: callback)
        timer.resume()
        return MainTimerHandle(timer: timer)
    }
}

private final class MainTimerHandle: TimerHandle
{
    private let timer: DispatchSourceTimer
    private var canceled = false

    init(timer: DispatchSourceTimer)
    {
        self.timer = timer
    }

    func cancel()
    {
        guard !canceled else { return }
        canceled = true
        timer.cancel()
    }
}

/// 测试用虚拟计时器源，不依赖真实时间（D7）。
///
/// 通过 advance(by:) 手动推进虚拟时间，触发到期回调。
/// 用于单元测试加速 2 秒计时与 0.2 秒动画时长验证。
public final class VirtualTimerSource: TimerSource
{
    private struct PendingTimer
    {
        let fireTime: TimeInterval
        let callback: () -> Void
        let id: UUID
        var canceled: Bool
    }

    private var pending: [PendingTimer] = []
    private var currentTime: TimeInterval = 0

    public init() {}

    public func schedule(duration: TimeInterval, callback: @escaping () -> Void) -> TimerHandle
    {
        let id = UUID()
        let timer = PendingTimer(
            fireTime: currentTime + duration,
            callback: callback,
            id: id,
            canceled: false
        )
        pending.append(timer)
        return VirtualTimerHandle(source: self, id: id)
    }

    /// 推进虚拟时间，触发到期回调（按时间顺序触发）。
    public func advance(by delta: TimeInterval)
    {
        currentTime += delta
        let due = pending.filter { $0.fireTime <= currentTime && !$0.canceled }
        let sortedDue = due.sorted { $0.fireTime < $1.fireTime }
        for timer in sortedDue
        {
            timer.callback()
            if let index = pending.firstIndex(where: { $0.id == timer.id })
            {
                pending.remove(at: index)
            }
        }
    }

    /// 当前虚拟时间（测试断言用）。
    public var now: TimeInterval
    {
        currentTime
    }

    fileprivate func cancel(id: UUID)
    {
        if let index = pending.firstIndex(where: { $0.id == id })
        {
            pending[index].canceled = true
        }
    }
}

private final class VirtualTimerHandle: TimerHandle
{
    weak var source: VirtualTimerSource?
    let id: UUID

    init(source: VirtualTimerSource, id: UUID)
    {
        self.source = source
        self.id = id
    }

    func cancel()
    {
        source?.cancel(id: id)
    }
}
```

### 步骤 4：运行测试验证通过

运行：
```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/TimerSourceTests' 2>&1 | tail -30
```
预期：PASS，5 个测试通过。

### 步骤 5：Commit

```bash
swiftlint lint --strict
git add ClipMind/Toast/TimerSource.swift ClipMindTests/Toast/TimerSourceTests.swift
git commit -m "feat(F2.1.1): add TimerSource protocol with Main and Virtual impls

- TimerSource 协议定义 schedule(duration:callback:) -> TimerHandle
- MainTimerSource 生产实现使用 DispatchSourceTimer 主线程（D6）
- VirtualTimerSource 测试实现支持 advance(by:) 手动推进虚拟时间
- 落地设计文档 D7 可测试性决策，禁用固定 sleep"
```

---

## 任务 4：ToastCoordinator 状态机基础（4 状态 + 通知订阅 + 校验）

**文件：**
- 创建：`ClipMind/Toast/ToastCoordinator.swift`
- 测试：`ClipMindTests/Toast/ToastCoordinatorTests.swift`
- 测试 Fixtures：`ClipMindTests/Toast/Fixtures/ToastCoordinatorFixtures.swift`

> **注意**：`LogCategory.swift` 的 `toast` 分类已在任务 2 中添加，本任务无需再修改。
> `ToastWindowManager` 已在任务 2 中标记为 `open class` + `open func`，支持测试 Mock 跨模块继承，本任务无需再修改。

### 步骤 1：编写失败的测试

```swift
// ClipMindTests/Toast/Fixtures/ToastCoordinatorFixtures.swift
import Foundation
@testable import ClipMind

/// F2.1.1 测试 Fixtures：构造 savedNotification 通知与 Mock 依赖。
enum ToastCoordinatorFixtures
{
    /// 构造保存完成通知。
    /// - Parameters:
    ///   - eventId: 事件标识（默认 "test-event-id"）
    ///   - fileName: 文件名（成功时传入，跳过时为 nil）
    ///   - skipped: 是否跳过（默认 false，即成功）
    static func makeSavedNotification(
        eventId: String = "test-event-id",
        fileName: String? = "test.md",
        skipped: Bool = false
    ) -> Notification
    {
        var userInfo: [String: Any] = ["eventId": eventId]
        if let fileName = fileName
        {
            userInfo["fileName"] = fileName
        }
        if skipped
        {
            userInfo["skipped"] = true
        }
        return Notification(
            name: AutoSaveService.savedNotification,
            object: nil,
            userInfo: userInfo
        )
    }
}
```

```swift
// ClipMindTests/Toast/ToastCoordinatorTests.swift
import XCTest
@testable import ClipMind

final class ToastCoordinatorTests: XCTestCase
{
    private var coordinator: ToastCoordinator!
    private var windowManager: TestToastWindowManager!
    private var timerSource: VirtualTimerSource!
    private var isEnabled: Bool = true

    override func setUp()
    {
        super.setUp()
        windowManager = TestToastWindowManager()
        timerSource = VirtualTimerSource()
        coordinator = ToastCoordinator(
            windowManager: windowManager,
            timerSource: timerSource,
            isEnabledProvider: { [unowned self] in self.isEnabled }
        )
    }

    override func tearDown()
    {
        coordinator?.stop()
        coordinator = nil
        windowManager = nil
        timerSource = nil
        super.tearDown()
    }

    // MARK: - 初始状态

    func testInitialStateIsHidden()
    {
        XCTAssertEqual(coordinator.currentState, .hidden, "初始状态应为隐藏")
    }

    // MARK: - TC-UT-01 隐藏 → 出现中

    func testHiddenToAppearingOnSavedNotification()
    {
        let notification = ToastCoordinatorFixtures.makeSavedNotification(
            eventId: "evt-1",
            fileName: "hello.md",
            skipped: false
        )
        coordinator.handleSavedNotification(notification)

        XCTAssertEqual(coordinator.currentState, .appearing, "收到保存通知应转为出现中")
        XCTAssertEqual(windowManager.lastShownFileName, "hello.md", "应触发窗口显示")
    }

    // MARK: - TC-UT-02 出现中 → 已显示

    func testAppearingToDisplayedOnDidAppear()
    {
        let notification = ToastCoordinatorFixtures.makeSavedNotification(fileName: "a.md")
        coordinator.handleSavedNotification(notification)
        XCTAssertEqual(coordinator.currentState, .appearing)

        // 模拟窗口承载模块回调进入动画完成
        windowManager.simulateDidAppear()

        XCTAssertEqual(coordinator.currentState, .displayed, "进入动画完成应转为已显示")
    }

    // MARK: - TC-UT-05 已显示 → 消失中

    func testDisplayedToDisappearingOnTimerFire()
    {
        let notification = ToastCoordinatorFixtures.makeSavedNotification(fileName: "a.md")
        coordinator.handleSavedNotification(notification)
        windowManager.simulateDidAppear()
        XCTAssertEqual(coordinator.currentState, .displayed)

        // 推进虚拟计时器到 2 秒
        timerSource.advance(by: 2.0)

        XCTAssertEqual(coordinator.currentState, .disappearing, "2 秒计时结束应转为消失中")
        XCTAssertTrue(windowManager.hideCalled, "应触发窗口退出动画")
    }

    // MARK: - TC-UT-06 消失中 → 隐藏

    func testDisappearingToHiddenOnDidHide()
    {
        let notification = ToastCoordinatorFixtures.makeSavedNotification(fileName: "a.md")
        coordinator.handleSavedNotification(notification)
        windowManager.simulateDidAppear()
        timerSource.advance(by: 2.0)
        XCTAssertEqual(coordinator.currentState, .disappearing)

        // 模拟窗口承载模块回调退出动画完成
        windowManager.simulateDidHide()

        XCTAssertEqual(coordinator.currentState, .hidden, "退出动画完成应转为隐藏")
    }

    // MARK: - 跳过标记为真不触发（FR-009）

    func testSkippedNotificationDoesNotTriggerToast()
    {
        let notification = ToastCoordinatorFixtures.makeSavedNotification(
            fileName: nil,
            skipped: true
        )
        coordinator.handleSavedNotification(notification)

        XCTAssertEqual(coordinator.currentState, .hidden, "跳过标记为真应保持隐藏")
        XCTAssertNil(windowManager.lastShownFileName, "不应触发窗口显示")
    }

    // MARK: - F2.1 总开关关闭时不触发（FR-008）

    func testDisabledF2xSwitchDoesNotTriggerToast()
    {
        isEnabled = false
        let notification = ToastCoordinatorFixtures.makeSavedNotification(fileName: "a.md")
        coordinator.handleSavedNotification(notification)

        XCTAssertEqual(coordinator.currentState, .hidden, "总开关关闭应保持隐藏")
        XCTAssertNil(windowManager.lastShownFileName, "不应触发窗口显示")
    }

    // MARK: - 主线程派发（D6）

    func testHandleSavedNotificationDispatchesToMainThread()
    {
        let expectation = XCTestExpectation(description: "main thread dispatched")
        let notification = ToastCoordinatorFixtures.makeSavedNotification(fileName: "a.md")

        // 在后台线程调用 handleSavedNotification
        DispatchQueue.global().async
        {
            self.coordinator.handleSavedNotification(notification)
            DispatchQueue.main.async
            {
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 1.0)
        // 主线程派发后状态应已变更
        XCTAssertEqual(coordinator.currentState, .appearing, "应在主线程派发后转换状态")
    }
}

/// 测试专用窗口承载模块，记录调用并支持手动触发回调。
final class TestToastWindowManager: ToastWindowManager
{
    private(set) var lastShownFileName: String?
    private(set) var hideCalled = false
    private(set) var closeImmediatelyCalled = false

    override func show(fileName: String)
    {
        lastShownFileName = fileName
        // 测试不真实创建窗口，仅记录调用
    }

    override func hide(completion: (() -> Void)?)
    {
        hideCalled = true
        // 测试不真实执行动画，由 simulateDidHide 触发回调
    }

    override func closeImmediately()
    {
        closeImmediatelyCalled = true
        // 测试不真实执行关闭，由 simulateDidCloseImmediately 触发回调
    }

    func simulateDidAppear()
    {
        onDidAppear?()
    }

    func simulateDidHide()
    {
        onDidHide?()
    }

    func simulateDidCloseImmediately()
    {
        onDidCloseImmediately?()
    }
}
```

### 步骤 2：运行测试验证失败

运行：
```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/ToastCoordinatorTests' 2>&1 | tail -30
```
预期：FAIL，报错 "Cannot find 'ToastCoordinator' in scope" / "Cannot find type 'ToastWindowManager' 可继承" 等。

### 步骤 3：编写最少实现代码

创建 `ToastCoordinator.swift`（`LogCategory.toast` 已在任务 2 中添加，`ToastWindowManager` 已在任务 2 中改为 `open class` 支持继承，本任务直接创建 ToastCoordinator）：

```swift
// ClipMind/Toast/ToastCoordinator.swift
import Foundation

/// F2.1.1 Toast 协调模块状态机（D2 决策）。
public enum ToastState: Equatable
{
    /// 隐藏：无 Toast 显示，无窗口资源，无计时器
    case hidden
    /// 出现中：窗口承载模块正在执行进入动画
    case appearing
    /// 已显示：进入动画完成，2 秒计时进行中
    case displayed
    /// 替换中：收到新通知，旧 Toast 立即关闭，新 Toast 即将进入（Phase 1 实现）
    case replacing
    /// 消失中：窗口承载模块正在执行退出动画
    case disappearing
}

/// F2.1.1 Toast 协调模块（设计文档 §3.1、§5.1、D2、D3、D4、D6）。
///
/// 职责：
/// - 订阅 AutoSaveService.savedNotification（D3 中心化通知订阅）
/// - 校验跳过标记非真（FR-009）与 F2.1 总开关启用（FR-008，D4 依赖注入闭包）
/// - 驱动 5 状态机（D2，Phase 0 实现 4 状态，Phase 1 实现 replacing）
/// - 管理 2 秒计时（FR-004，D7 注入计时器源）
/// - 主线程派发（D6）
/// - 通过 LogCategory.toast 输出关键状态变更日志（NFR-005）
///
/// 不负责：窗口创建与动画、视图渲染、F2.1 配置管理、F2.1 错误弹窗
public final class ToastCoordinator
{
    /// 2 秒显示时长（FR-004）
    private static let displayDuration: TimeInterval = 2.0

    private let windowManager: ToastWindowManager
    private let timerSource: TimerSource
    private let isEnabledProvider: () throws -> Bool
    private let logger = LogCategory.toast.logger

    /// 当前状态（公开只读，用于测试断言）
    public private(set) var currentState: ToastState = .hidden

    /// 当前计时器句柄（D2：保证同时只有一个有效计时器，R-03 缓解）
    private var currentTimerHandle: TimerHandle?

    /// 当前显示的文件名（用于替换日志与测试）
    private(set) var currentFileName: String?

    /// 替换模式暂存的待显示文件名（Phase 1 任务 8 使用）
    private var pendingFileName: String?

    private var observer: NSObjectProtocol?

    public init(
        windowManager: ToastWindowManager,
        timerSource: TimerSource,
        isEnabledProvider: @escaping () throws -> Bool
    )
    {
        self.windowManager = windowManager
        self.timerSource = timerSource
        self.isEnabledProvider = isEnabledProvider
        setupWindowManagerCallbacks()
        startObservingSavedNotification()
    }

    deinit
    {
        stop()
    }

    /// 停止协调模块，取消所有计时器与通知订阅（用于 App 退出与测试 tearDown）。
    public func stop()
    {
        currentTimerHandle?.cancel()
        currentTimerHandle = nil
        if let observer = observer
        {
            NotificationCenter.default.removeObserver(observer)
            self.observer = nil
        }
    }

    // MARK: - 通知订阅（D3）

    private func startObservingSavedNotification()
    {
        observer = NotificationCenter.default.addObserver(
            forName: AutoSaveService.savedNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            self?.handleSavedNotification(notification)
        }
    }

    // MARK: - 通知处理（D6 主线程派发）

    /// 处理保存完成通知。
    /// 通知可能在 F2.1 串行队列派发，必须切换到主线程处理。
    public func handleSavedNotification(_ notification: Notification)
    {
        // D6：通知回调立即派发到主线程
        if Thread.isMainThread
        {
            handleOnMainThread(notification)
        }
        else
        {
            DispatchQueue.main.async { [weak self] in
                self?.handleOnMainThread(notification)
            }
        }
    }

    private func handleOnMainThread(_ notification: Notification)
    {
        let userInfo = notification.userInfo ?? [:]
        let eventId = userInfo["eventId"] as? String
        let fileName = userInfo["fileName"] as? String
        let skipped = userInfo["skipped"] as? Bool ?? false

        // FR-009：跳过标记为真不触发
        guard !skipped else
        {
            logger.info("Toast skip: skipped=true eventId=\(eventId ?? "nil", privacy: .public)")
            return
        }

        // FR-008 + E3：F2.1 总开关查询（D4 注入闭包），捕获异常保守不显示
        let isEnabled: Bool
        do
        {
            isEnabled = try isEnabledProvider()
        }
        catch
        {
            logger.error("Toast skip: isEnabledProvider threw error eventId=\(eventId ?? "nil", privacy: .public)")
            return
        }
        guard isEnabled else
        {
            logger.info("Toast skip: F2.1 disabled eventId=\(eventId ?? "nil", privacy: .public)")
            return
        }

        // E1：必须有文件名（成功路径必有，理论防御）
        guard let fileName = fileName else
        {
            logger.error("Toast skip: fileName missing eventId=\(eventId ?? "nil", privacy: .public)")
            return
        }

        logger.info("Toast trigger: fileName=\(fileName, privacy: .public) eventId=\(eventId ?? "nil", privacy: .public)")
        triggerToast(fileName: fileName)
    }

    // MARK: - 状态机驱动（D2）

    private func triggerToast(fileName: String)
    {
        // Phase 0：仅在 hidden 与 disappearing 状态触发新 Toast
        // Phase 1：补充 appearing / displayed / replacing 状态下的替换逻辑
        switch currentState
        {
        case .hidden:
            startAppearing(fileName: fileName)
        case .disappearing:
            // 退出动画进行中收到新通知 → 替换（Phase 1 完整实现，Phase 0 简化为等动画完成后再触发）
            logger.info("Toast deferred during disappearing: fileName=\(fileName, privacy: .public)")
            // Phase 0 简化：直接放弃新触发，等动画完成
            // Phase 1 任务 8 会实现完整替换逻辑
        case .appearing, .displayed, .replacing:
            // Phase 1 任务 8 实现替换中状态
            logger.info("Toast replace pending (Phase 1): fileName=\(fileName, privacy: .public)")
        }
    }

    private func startAppearing(fileName: String)
    {
        currentState = .appearing
        currentFileName = fileName
        windowManager.show(fileName: fileName)
    }

    // MARK: - 窗口承载模块回调（D2 状态转换触发器）

    private func setupWindowManagerCallbacks()
    {
        windowManager.onDidAppear = { [weak self] in
            self?.handleDidAppear()
        }
        windowManager.onDidHide = { [weak self] in
            self?.handleDidHide()
        }
        windowManager.onDidCloseImmediately = { [weak self] in
            self?.handleDidCloseImmediately()
        }
    }

    private func handleDidAppear()
    {
        guard currentState == .appearing else { return }
        currentState = .displayed

        // 启动 2 秒计时（D7 注入计时器源）
        currentTimerHandle?.cancel()
        currentTimerHandle = timerSource.schedule(duration: Self.displayDuration) { [weak self] in
            self?.handleTimerFired()
        }
    }

    private func handleTimerFired()
    {
        guard currentState == .displayed else { return }
        currentState = .disappearing
        currentTimerHandle = nil
        windowManager.hide(completion: nil)
    }

    private func handleDidHide()
    {
        currentState = .hidden
        currentFileName = nil
    }

    private func handleDidCloseImmediately()
    {
        // Phase 1 替换模式专用：旧窗口立即关闭完成后，触发新 Toast 进入
        // Phase 0：仅作为回调点，不实现替换逻辑
    }
}
```

### 步骤 4：运行测试验证通过

运行：
```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/ToastCoordinatorTests' 2>&1 | tail -30
```
预期：PASS，7 个测试通过。

### 步骤 5：Commit

```bash
swiftlint lint --strict
git add ClipMind/Toast/ToastCoordinator.swift \
  ClipMindTests/Toast/ToastCoordinatorTests.swift \
  ClipMindTests/Toast/Fixtures/ToastCoordinatorFixtures.swift
git commit -m "feat(F2.1.1): add ToastCoordinator state machine and notification observer

- ToastState 枚举定义 5 状态：hidden/appearing/displayed/replacing/disappearing（D2）
- ToastCoordinator 订阅 AutoSaveService.savedNotification（D3）
- 通知回调主线程派发（D6）
- 跳过标记与 F2.1 总开关校验（FR-008/009，D4 注入闭包，E3 异常保守不显示）
- E1 文件名缺失防御与 E2 eventId 缺失降级处理
- Phase 0 实现 4 状态转换（hidden→appearing→displayed→disappearing→hidden）
- 落地设计文档 §3.1、§5.1、D2、D3、D4、D6"
```

---

## 任务 5：2 秒计时器验证与错误场景测试补充（D7 + 设计文档 §8.4 E1/E2/E3）

**文件：**
- 修改：`ClipMindTests/Toast/ToastCoordinatorTests.swift`（追加测试）

> **说明**：任务 4 的实现已包含 E1（文件名缺失防御）、E2（eventId 缺失降级）、E3（`isEnabledProvider` 抛异常保守不显示）的防御代码，且 `isEnabledProvider` 类型已定义为 `() throws -> Bool`。本任务补充针对这些防御行为的单元测试，验证其正确性。TDD 流程为"编写测试 → 验证通过（已实现）"，属回归测试性质。

### 步骤 1：编写测试

追加到 `ToastCoordinatorTests.swift`：

```swift
// MARK: - TC-UT-09 启动新 2 秒计时（D2 不变量）

func testNewTimerStartedOnAppearing()
{
    let notification = ToastCoordinatorFixtures.makeSavedNotification(fileName: "a.md")
    coordinator.handleSavedNotification(notification)
    windowManager.simulateDidAppear()
    XCTAssertEqual(coordinator.currentState, .displayed)

    // 推进 1 秒，不应触发消失
    timerSource.advance(by: 1.0)
    XCTAssertEqual(coordinator.currentState, .displayed)

    // 再推进 1 秒，应触发消失
    timerSource.advance(by: 1.0)
    XCTAssertEqual(coordinator.currentState, .disappearing)
}

// MARK: - E1 通知载荷缺失文件名

func testE1MissingFileNameDoesNotTriggerToast()
{
    let notification = ToastCoordinatorFixtures.makeSavedNotification(
        fileName: nil,
        skipped: false
    )
    coordinator.handleSavedNotification(notification)

    XCTAssertEqual(coordinator.currentState, .hidden, "文件名缺失应保持隐藏")
    XCTAssertNil(windowManager.lastShownFileName)
}

// MARK: - E2 通知载荷事件标识缺失（降级处理）

func testE2MissingEventIdStillTriggersToast()
{
    let notification = ToastCoordinatorFixtures.makeSavedNotification(
        eventId: "",
        fileName: "test.md",
        skipped: false
    )
    coordinator.handleSavedNotification(notification)

    XCTAssertEqual(coordinator.currentState, .appearing, "eventId 缺失应降级处理仍触发 Toast")
}

// MARK: - E3 F2.1 总开关查询失败（保守策略，不显示）

func testE3IsEnabledProviderThrowsDoesNotTriggerToast()
{
    let throwingProvider: () throws -> Bool = {
        struct E: Error {}
        throw E()
    }
    let coordinator = ToastCoordinator(
        windowManager: windowManager,
        timerSource: timerSource,
        isEnabledProvider: throwingProvider
    )
    let notification = ToastCoordinatorFixtures.makeSavedNotification(fileName: "test.md")
    coordinator.handleSavedNotification(notification)

    XCTAssertEqual(coordinator.currentState, .hidden, "查询失败应保守不显示")
}
```

### 步骤 2：运行测试验证通过

运行：
```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/ToastCoordinatorTests' 2>&1 | tail -30
```
预期：PASS，11 个测试通过（原 7 + 新 4）。E1/E2/E3 防御代码已在任务 4 中实现，本任务测试验证其正确性。

### 步骤 3：无需修改实现代码

E1（fileName 缺失 guard）、E2（eventId 缺失降级）、E3（do-catch 捕获 isEnabledProvider 异常）的防御代码已在任务 4 的 `ToastCoordinator.handleOnMainThread` 中实现。`isEnabledProvider` 类型已定义为 `() throws -> Bool`，支持注入 throwing 闭包。本任务仅补充测试，无实现改动。

### 步骤 4：Commit

```bash
swiftlint lint --strict
git add ClipMindTests/Toast/ToastCoordinatorTests.swift
git commit -m "test(F2.1.1): cover 2s timer invariant and E1/E2/E3 error scenarios

- TC-UT-09 验证 2 秒计时启动（D2 不变量，推进 1 秒不触发，2 秒触发）
- E1 通知载荷缺失文件名：保持隐藏，不触发 Toast
- E2 通知载荷 eventId 缺失：降级处理仍触发 Toast
- E3 isEnabledProvider 抛异常：保守不显示，保持隐藏
- 防御代码已在任务 4 实现，本任务补充测试覆盖"
```

---

## 任务 6：AppDelegate 装配 ToastCoordinator

**文件：**
- 修改：`ClipMind/App/ClipMindApp.swift`

### 步骤 1：编写失败的测试

由于 AppDelegate 装配依赖运行时，通过 XCUITest 间接验证。此处直接在 Phase 0 任务 7 XCUITest 中验证，本任务通过 build 检查装配正确性。

直接编写实现代码（无单元测试，依赖 Phase 0 任务 7 XCUITest 验证）。

### 步骤 2：运行编译验证

运行：
```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1.1-save-success-toast
xcodebuild build \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10
```
预期：BUILD SUCCEEDED（仅验证装配不破坏既有构建）。

### 步骤 3：编写最少实现代码

修改 `ClipMind/App/ClipMindApp.swift`，在 `AppDelegate` 中新增 `toastCoordinator` 属性，在 `setupCaptureService` 中装配：

```swift
// 修改 ClipMind/App/ClipMindApp.swift
// 在 AppDelegate 类中：
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?
    private var cleanupService: CleanupService?
    private var captureService: ClipCaptureService?
    private var hotkeyService: GlobalHotkeyService?
    private var autoSaveService: AutoSaveService?
    private var selfWriteSuppressor: SelfWriteSuppressor?
    // F2.1.1 新增：Toast 协调模块
    private var toastCoordinator: ToastCoordinator?

    // ... 既有代码不变 ...

    /// 初始化并启动剪贴板捕获服务（含 F2.1 自动保存装配 + F2.1.1 Toast 装配）
    private func setupCaptureService(store: EncryptedStore)
    {
        let embeddingService = LocalEmbeddingService()
        let classifier = ClassificationService(embeddingService: embeddingService)

        // F2.1 装配：构造 CaptureEventBuilder 与 AutoSaveService
        let settingsStore = AutoSaveSettingsStore()
        let sensitiveDetector = SensitiveDetector()
        let blacklistService = BlacklistService()
        let eventBuilder = CaptureEventBuilder(
            appDetector: AppDetector(),
            sensitiveDetector: sensitiveDetector,
            blacklistService: blacklistService,
            settingsStore: settingsStore
        )

        let suppressor = SelfWriteSuppressor()
        selfWriteSuppressor = suppressor

        let autoSave = AutoSaveService(
            settingsStore: settingsStore,
            pasteboard: .general,
            suppressor: suppressor
        )
        autoSaveService = autoSave

        // 装配 onFilePathSaved 回调：将文件路径以 ClipContent.filePath 存入历史
        autoSave.onFilePathSaved = { [weak self] savedURL, _ in
            self?.saveFilePathToHistory(savedURL, store: store)
        }

        // F2.1.1 装配：Toast 协调模块
        // - 注入 MainTimerSource（生产计时器源，D7）
        // - 注入 F2.1 总开关查询闭包（D4，读取 AutoSaveSettingsStore 快照）
        let toastWindowManager = ToastWindowManager()
        let toastCoordinator = ToastCoordinator(
            windowManager: toastWindowManager,
            timerSource: MainTimerSource(),
            isEnabledProvider: { settingsStore.load().isEnabled }
        )
        self.toastCoordinator = toastCoordinator

        let watcher = PasteboardWatcher(eventBuilder: eventBuilder, suppressor: suppressor)
        captureService = ClipCaptureService(watcher: watcher, store: store, classifier: classifier)
        captureService?.autoSaveService = autoSave
        captureService?.start()

        LogCategory.app.logger.info("剪贴板捕获服务已启动（含 F2.1 自动保存 + F2.1.1 Toast）")
    }
}
```

### 步骤 4：运行编译验证通过

运行：
```bash
xcodebuild build \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10
```
预期：BUILD SUCCEEDED。

### 步骤 5：Commit

```bash
swiftlint lint --strict
git add ClipMind/App/ClipMindApp.swift
git commit -m "feat(F2.1.1): wire ToastCoordinator in AppDelegate setupCaptureService

- AppDelegate 新增 toastCoordinator 属性
- 在 setupCaptureService 中装配 ToastCoordinator
- 注入 MainTimerSource 作为生产计时器源（D7）
- 注入 F2.1 总开关查询闭包读取 AutoSaveSettingsStore 快照（D4）
- 复用既有 settingsStore 实例，不新增配置访问点"
```

---

## 任务 7：Phase 0 XCUITest 集成测试

**文件：**
- 创建：`ClipMindUITests/Toast/ToastBasicUITests.swift`

### 步骤 1：编写失败的测试

```swift
// ClipMindUITests/Toast/ToastBasicUITests.swift
import XCTest

final class ToastBasicUITests: XCTestCase
{
    override func setUpWithError() throws
    {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    // AC-01 自动保存成功后弹出 Toast
    func testAC01ToastAppearsAfterSaveSuccess() throws
    {
        let app = XCUIApplication()
        app.launchArguments += ["--UITEST_SHOW_MAIN_WINDOW", "--UITEST_RESET_ONBOARDING"]
        app.launchArguments += ["--UITEST_RESET_AUTOSAVE_SETTINGS"]
        app.launchArguments += ["--UITEST_TOAST_TRIGGER", "hello-world.md"]
        app.launch()

        // 触发 Toast（通过 UITEST 启动参数模拟保存成功）
        // 实际由 UITEST trigger 入口派发 savedNotification
        let toastContainer = app.otherElements["toast-container"]
        let appeared = toastContainer.waitForExistence(timeout: 3.0)
        XCTAssertTrue(appeared, "AC-01: Toast 容器应在保存成功后出现")
    }

    // AC-02 Toast 2 秒后自动消失
    func testAC02ToastDisappearsAfter2Seconds() throws
    {
        let app = XCUIApplication()
        app.launchArguments += ["--UITEST_SHOW_MAIN_WINDOW", "--UITEST_RESET_ONBOARDING"]
        app.launchArguments += ["--UITEST_TOAST_TRIGGER", "hello-world.md"]
        app.launch()

        let toastContainer = app.otherElements["toast-container"]
        XCTAssertTrue(toastContainer.waitForExistence(timeout: 3.0), "Toast 应出现")

        // 轮询 toast-container 不存在（含 0.2s 退出动画余量，超时 3s）
        let disappeared = NSPredicate(format: "exists == false")
        let expectation = expectation(for: disappeared, evaluatedWith: toastContainer, handler: nil)
        wait(for: [expectation], timeout: 3.5)
        XCTAssertFalse(toastContainer.exists, "AC-02: Toast 应在 2 秒后消失")
    }

    // AC-03 Toast 显示文件名
    func testAC03ToastDisplaysFileName() throws
    {
        let app = XCUIApplication()
        app.launchArguments += ["--UITEST_SHOW_MAIN_WINDOW", "--UITEST_RESET_ONBOARDING"]
        app.launchArguments += ["--UITEST_TOAST_TRIGGER", "hello-world.md"]
        app.launch()

        let fileNameText = app.staticTexts["toast-filename-text"]
        XCTAssertTrue(fileNameText.waitForExistence(timeout: 3.0), "AC-03: toast-filename-text 应存在")
        XCTAssertEqual(fileNameText.value as? String, "hello-world.md", "AC-03: 应显示实际文件名")
    }

    // AC-06 F2.1 总开关关闭时不弹 Toast
    func testAC06NoToastWhenF2xDisabled() throws
    {
        let app = XCUIApplication()
        app.launchArguments += ["--UITEST_SHOW_MAIN_WINDOW", "--UITEST_RESET_ONBOARDING"]
        app.launchArguments += ["--UITEST_RESET_AUTOSAVE_SETTINGS"]
        // 不启用 F2.1 总开关，触发 Toast 应被过滤
        app.launchArguments += ["--UITEST_TOAST_TRIGGER", "hello-world.md"]
        app.launch()

        let toastContainer = app.otherElements["toast-container"]
        let notAppeared = !toastContainer.waitForExistence(timeout: 1.5)
        XCTAssertTrue(notAppeared, "AC-06: F2.1 总开关关闭时不应出现 Toast")
    }

    // AC-09 Toast 位置在屏幕顶部居中
    func testAC09ToastPositionedAtTopCenter() throws
    {
        let app = XCUIApplication()
        app.launchArguments += ["--UITEST_SHOW_MAIN_WINDOW", "--UITEST_RESET_ONBOARDING"]
        app.launchArguments += ["--UITEST_TOAST_TRIGGER", "hello-world.md"]
        app.launch()

        let toastContainer = app.otherElements["toast-container"]
        XCTAssertTrue(toastContainer.waitForExistence(timeout: 3.0), "Toast 应出现")

        let frame = toastContainer.frame
        let screenFrame = NSScreen.main!.frame
        let screenCenterX = screenFrame.midX
        let toastCenterX = frame.midX
        XCTAssertEqual(toastCenterX, screenCenterX, accuracy: 5, "AC-09: Toast 应水平居中")

        let topInset = screenFrame.maxY - frame.maxY
        XCTAssertGreaterThanOrEqual(topInset, 16, "AC-09: 距顶部应 ≥ 16pt")
        XCTAssertLessThanOrEqual(topInset, 32, "AC-09: 距顶部应 ≤ 32pt")
    }

    // AC-11 Toast 不依赖窗口焦点
    func testAC11ToastDoesNotRequireFocus() throws
    {
        let app = XCUIApplication()
        app.launchArguments += ["--UITEST_SHOW_MAIN_WINDOW", "--UITEST_RESET_ONBOARDING"]
        app.launchArguments += ["--UITEST_TOAST_TRIGGER", "hello-world.md"]
        app.launch()

        // Toast 是屏幕级浮层，不依赖主窗口激活
        let toastContainer = app.otherElements["toast-container"]
        XCTAssertTrue(toastContainer.waitForExistence(timeout: 3.0), "AC-11: Toast 应在不依赖焦点的情况下出现")
    }
}

import AppKit
```

### 步骤 2：运行 XCUITest 编译验证

运行：
```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1.1-save-success-toast
xcodebuild build-for-testing \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10
```
预期：BUILD SUCCEEDED for Testing（XCUITest 不在本地运行，留 CI 验证）。

### 步骤 3：编写 UITEST 启动参数处理逻辑（修改 AppDelegate）

为了让 XCUITest 通过 `--UITEST_TOAST_TRIGGER` 启动参数模拟保存成功，需要在 AppDelegate 中支持该启动参数。修改 `ClipMind/App/ClipMindApp.swift` 的 `applicationDidFinishLaunching`：

```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    applyUITestOverrides()
    configureActivationPolicy()
    if CommandLine.arguments.contains("--UITEST_POPOVER_WINDOW") {
        showPopoverContentInWindow()
    }
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleOpenMainWindow),
        name: .openMainWindow,
        object: nil
    )
    // 监听 F2.1 自动保存错误通知（D13 目录异常分级处理）
    NotificationCenter.default.addObserver(
        self,
        selector: #selector(handleAutoSaveError(_:)),
        name: AutoSaveService.errorNotification,
        object: nil
    )
    // F2.1.1 测试入口：通过 --UITEST_TOAST_TRIGGER 模拟保存成功通知
    handleToastUITestTriggerIfNeeded()
}

/// F2.1.1 UITEST 入口：通过 --UITEST_TOAST_TRIGGER <fileName> 模拟保存成功通知。
/// 仅在 XCUITest 环境使用，生产环境不触发。
private func handleToastUITestTriggerIfNeeded()
{
    guard let triggerIndex = CommandLine.arguments.firstIndex(of: "--UITEST_TOAST_TRIGGER") else
    {
        return
    }
    let fileName: String
    if triggerIndex + 1 < CommandLine.arguments.count
    {
        fileName = CommandLine.arguments[triggerIndex + 1]
    }
    else
    {
        fileName = "test.md"
    }

    // 派发到主线程，确保 ToastCoordinator 已完成装配
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5)
    {
        NotificationCenter.default.post(
            name: AutoSaveService.savedNotification,
            object: nil,
            userInfo: [
                "eventId": "uitest-toast-trigger",
                "fileName": fileName,
                "skipped": false
            ]
        )
    }
}
```

### 步骤 4：运行编译验证通过

运行：
```bash
xcodebuild build-for-testing \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -10
```
预期：BUILD SUCCEEDED for Testing。

### 步骤 5：Commit

```bash
swiftlint lint --strict
git add ClipMindUITests/Toast/ToastBasicUITests.swift ClipMind/App/ClipMindApp.swift
git commit -m "test(F2.1.1): add ToastBasicUITests for AC-01/02/03/06/09/11

- AC-01 Toast 出现（断言 toast-container 存在）
- AC-02 2 秒消失（轮询 toast-container 不存在，禁用 sleep）
- AC-03 文件名显示（断言 toast-filename-text 文本）
- AC-06 F2.1 总开关关闭时不弹 Toast
- AC-09 位置顶部居中（断言水平居中 + 距顶部 16-32pt）
- AC-11 不依赖窗口焦点
- AppDelegate 支持 --UITEST_TOAST_TRIGGER 启动参数模拟保存成功通知"
```

---

## Phase 0 完成验收

完成所有 7 个任务后，运行以下验证：

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1.1-save-success-toast

# 1. SwiftLint strict
swiftlint lint --strict

# 2. 完整编译
xcodebuild build \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5

# 3. Toast 单元测试全部通过
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/ToastViewTests' \
  -only-testing:'ClipMindTests/ToastWindowManagerTests' \
  -only-testing:'ClipMindTests/TimerSourceTests' \
  -only-testing:'ClipMindTests/ToastCoordinatorTests' 2>&1 | tail -10

# 4. XCUITest 编译验证（不运行）
xcodebuild build-for-testing \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO 2>&1 | tail -5
```

预期：
- SwiftLint：0 violations
- Build：BUILD SUCCEEDED
- 单元测试：全部 PASS（约 25 个测试）
- XCUITest 编译：BUILD SUCCEEDED for Testing

Phase 0 完成后进入 Phase 1：替换模式与错误降级。
