import XCTest

/// 菜单栏弹窗无权限降级浮层 UI 测试（F1.11 Phase 2 任务 9）。
///
/// 覆盖 AC-F1.11-10：无辅助功能权限时双击文本行显示降级浮层。
/// 沿用 F1.9 `QuickPasteOverlayUITests` 的检测方式：通过 `UITest_overlayVisible`
/// UserDefaults 键 + CFPreferences 轮询读取被测应用的偏好设置域。
final class PopoverOverlayUITests: XCTestCase
{
    override func setUp()
    {
        super.setUp()
        continueAfterFailure = false
        cleanOverlayState()
    }

    override func tearDown()
    {
        XCUIApplication().terminate()
        super.tearDown()
    }

    /// 清理浮层可见性状态，避免上次测试残留干扰。
    private func cleanOverlayState()
    {
        CFPreferencesSetAppValue(
            "UITest_overlayVisible" as CFString,
            nil,
            "com.clipmind.app" as CFString
        )
        CFPreferencesAppSynchronize("com.clipmind.app" as CFString)
    }

    // MARK: - AC-F1.11-10 无辅助功能权限时双击显示降级浮层

    /// 验证无权限时双击文本行显示降级浮层。
    ///
    /// `--UITEST_FORCE_NO_PERMISSION` 注入 `PopoverUITestNoPermissionChecker`（始终返回 false），
    /// 触发 PasteCoordinator 走降级路径，显示 `PasteOverlayController` 浮层。
    /// 浮层可见性通过 `UITest_overlayVisible` 键检测（与 F1.9 `QuickPasteOverlayUITests` 一致）。
    func test15_NoPermission_ShowsDegradedOverlay()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_POPOVER_WINDOW",
            "--UITEST_PREVIEW_DATA",
            "--UITEST_FORCE_NO_PERMISSION",
            "--UITEST_OVERLAY_TIMEOUT_1S"
        ]
        app.launch()
        app.activate()

        // 双击文本行（第一条 previewClips 是文本）
        let firstRow = app.descendants(matching: .any)["popoverRow_0_selected"].firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 3), "第一行应存在")
        firstRow.doubleClick()

        // 通过 CFPreferences 轮询检测浮层状态
        XCTAssertTrue(
            waitOverlayState(app: app, visible: true, timeout: 5),
            "无权限路径应显示降级浮层"
        )
    }

    /// 等待浮层出现或消失（沿用 F1.9 QuickPasteOverlayUITests 的实现方式）。
    /// - Parameters:
    ///   - app: XCUIApplication
    ///   - visible: 期望状态（true=出现, false=消失）
    ///   - timeout: 超时秒数
    /// - Returns: 是否在超时内达到期望状态
    private func waitOverlayState(
        app: XCUIApplication,
        visible: Bool,
        timeout: TimeInterval
    ) -> Bool
    {
        let key = "UITest_overlayVisible"
        let appBundleId = "com.clipmind.app"
        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout
        {
            let currentValue = CFPreferencesGetAppBooleanValue(
                key as CFString,
                appBundleId as CFString,
                nil
            )
            if currentValue == visible { return true }
            usleep(100_000) // 100ms
        }
        return CFPreferencesGetAppBooleanValue(
            key as CFString,
            appBundleId as CFString,
            nil
        ) == visible
    }
}
