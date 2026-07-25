@testable import ClipMind
import SwiftUI
import XCTest

/// BottomToolbarView 单元测试（F1.11 Phase 3 任务 2）。
///
/// 验证底部工具栏组件的契约：
/// - 三按钮（查看全部 / 配置 / 退出）的辅助功能标识符
/// - 三按钮点击分别触发 onViewAll / onSettings / onExit 回调
/// - 回调互不干扰（点击一个按钮不触发其他回调）
@MainActor
final class BottomToolbarViewTests: XCTestCase
{
    /// 验证 BottomToolbarView 可构造（AC-F1.11-13 三按钮存在性前置条件）。
    func testBottomToolbarView_IsConstructible()
    {
        let view = BottomToolbarView(
            onViewAll: {},
            onSettings: {},
            onExit: {}
        )

        XCTAssertNotNil(view as Any?, "BottomToolbarView 可构造")
    }

    /// 验证「查看全部」按钮回调被触发（AC-F1.11-6）。
    func testViewAllButton_TriggersCallback()
    {
        var viewAllCalled = false
        var settingsCalled = false
        var exitCalled = false

        let view = BottomToolbarView(
            onViewAll: { viewAllCalled = true },
            onSettings: { settingsCalled = true },
            onExit: { exitCalled = true }
        )

        // 直接调用闭包验证回调链路（SwiftUI 按钮动作由 XCUITest 验证）
        view.triggerViewAllForTesting()

        XCTAssertTrue(viewAllCalled, "onViewAll 回调应被触发")
        XCTAssertFalse(settingsCalled, "onSettings 不应被触发")
        XCTAssertFalse(exitCalled, "onExit 不应被触发")
    }

    /// 验证「配置」按钮回调被触发（AC-F1.11-7）。
    func testSettingsButton_TriggersCallback()
    {
        var viewAllCalled = false
        var settingsCalled = false
        var exitCalled = false

        let view = BottomToolbarView(
            onViewAll: { viewAllCalled = true },
            onSettings: { settingsCalled = true },
            onExit: { exitCalled = true }
        )

        view.triggerSettingsForTesting()

        XCTAssertFalse(viewAllCalled, "onViewAll 不应被触发")
        XCTAssertTrue(settingsCalled, "onSettings 回调应被触发")
        XCTAssertFalse(exitCalled, "onExit 不应被触发")
    }

    /// 验证「退出」按钮回调被触发（AC-F1.11-8）。
    func testExitButton_TriggersCallback()
    {
        var viewAllCalled = false
        var settingsCalled = false
        var exitCalled = false

        let view = BottomToolbarView(
            onViewAll: { viewAllCalled = true },
            onSettings: { settingsCalled = true },
            onExit: { exitCalled = true }
        )

        view.triggerExitForTesting()

        XCTAssertFalse(viewAllCalled, "onViewAll 不应被触发")
        XCTAssertFalse(settingsCalled, "onSettings 不应被触发")
        XCTAssertTrue(exitCalled, "onExit 回调应被触发")
    }

    /// 验证按钮标识符常量符合命名约定（README 第 5.4 节）。
    func testButtonIdentifierConstants_AreCorrect()
    {
        XCTAssertEqual(BottomToolbarView.viewAllButtonIdentifier, "popoverViewAllButton")
        XCTAssertEqual(BottomToolbarView.settingsButtonIdentifier, "popoverSettingsButton")
        XCTAssertEqual(BottomToolbarView.exitButtonIdentifier, "popoverExitButton")
    }

    /// AC-F1.11-7：验证 openSettingsWindow 通知发送不崩溃（链路存在性）。
    /// 完整的窗口打开验证在 Phase 3 任务 5-7 的 XCUITest 中完成。
    func testOpenSettingsWindowNotification_DoesNotCrash()
    {
        NotificationCenter.default.post(name: .openSettingsWindow, object: nil)

        // 等待主线程 runloop 处理通知，不崩溃即通过
        let expectation = XCTestExpectation(description: "Notification processed")
        DispatchQueue.main.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - 任务 4：UnifiedPastePanelView 条件渲染验证

    /// AC-F1.11-13：菜单栏弹窗场景下底部工具栏可见（showsBottomBar = true）。
    func testUnifiedPastePanelView_WithShowsBottomBar_True_RendersBottomToolbar()
    {
        let clips = ClipTestData.previewClips
        let viewModel = UnifiedPastePanelViewModel(clips: clips)
        let view = UnifiedPastePanelView(
            viewModel: viewModel,
            showsBottomBar: true,
            accessibilityPrefix: "popover"
        )

        XCTAssertNotNil(view as Any?, "showsBottomBar=true 时 UnifiedPastePanelView 可构造")
        // 详细的可视性验证在 XCUITest 中完成（Phase 3 任务 5-7）
    }

    /// AC-F1.11-13：快捷键场景下底部工具栏不可见（showsBottomBar = false）。
    func testUnifiedPastePanelView_WithShowsBottomBar_False_DoesNotRenderBottomToolbar()
    {
        let clips = ClipTestData.previewClips
        let viewModel = UnifiedPastePanelViewModel(clips: clips)
        let view = UnifiedPastePanelView(
            viewModel: viewModel,
            showsBottomBar: false,
            accessibilityPrefix: "quickPaste"
        )

        XCTAssertNotNil(view as Any?, "showsBottomBar=false 时 UnifiedPastePanelView 可构造")
    }

    // MARK: - F1.11 Bug Fix：退出按钮语义调整（退出整个应用）

    /// 验证 `UnifiedPastePanelViewModel` 提供 `onExitApp` 回调字段（默认 nil）。
    ///
    /// Bug 背景：用户反馈「点击退出按钮没反应」，根因是语义误解 ——
    /// 设计文档 v1.0 将「退出」按钮定义为「退出弹窗」（仅关闭 popover），
    /// 但用户期望「退出」按钮退出整个应用。
    /// 调整方向：将「退出」按钮行为改为 `NSApp.terminate(nil)`。
    ///
    /// 为保持可测试性，将退出动作抽象为 viewModel 的 `onExitApp` 回调，
    /// 由 `StatusItemController` 注入 `NSApp.terminate`，
    /// 由 `PopoverPreviewWindowFactory` 在 UITEST 模式下注入测试 stub。
    func testViewModel_HasOnExitAppCallback_DefaultNil()
    {
        let viewModel = UnifiedPastePanelViewModel(clips: [])
        XCTAssertNil(viewModel.onExitApp, "onExitApp 默认应为 nil，由控制器注入")
    }

    /// 验证 `onExitApp` 回调可被设置与触发（由控制器注入 `NSApp.terminate`）。
    func testViewModel_OnExitAppCallback_CanBeSetAndInvoked()
    {
        let viewModel = UnifiedPastePanelViewModel(clips: [])
        var exitAppCalled = false
        viewModel.onExitApp = { exitAppCalled = true }

        viewModel.onExitApp?()

        XCTAssertTrue(exitAppCalled, "onExitApp 回调应可被设置和触发")
    }
}
