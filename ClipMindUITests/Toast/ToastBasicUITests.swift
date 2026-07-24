import AppKit
import XCTest

/// F2.1.1 Phase 0 XCUITest：Toast 基础显示行为验证（AC-01/02/03/06/09/11）。
///
/// 通过 `--UITEST_TOAST_TRIGGER <fileName>` 启动参数模拟保存成功通知：
/// - 需 Toast 出现的用例附带 `--UITEST_ENABLE_AUTOSAVE` 启用 F2.1 总开关
/// - AC-06 验证总开关关闭时不弹 Toast，故不附带启用参数
final class ToastBasicUITests: XCTestCase
{
    override func setUpWithError() throws
    {
        try super.setUpWithError()
        if ProcessInfo.processInfo.environment["CLIPMIND_SKIP_PANEL_UITESTS"] == "1"
            || ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] == "true"
        {
            throw XCTSkip(
                "当前 CI 环境无法可靠验证 NSPanel Accessibility 可见性"
            )
        }
        continueAfterFailure = false
    }

    // MARK: - AC-01 自动保存成功后弹出 Toast

    func testAC01ToastAppearsAfterSaveSuccess() throws
    {
        let app = XCUIApplication()
        app.launchArguments += [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_RESET_ONBOARDING",
            "--UITEST_RESET_AUTOSAVE_SETTINGS",
            "--UITEST_ENABLE_AUTOSAVE",
            "--UITEST_TOAST_TRIGGER", "hello-world.md"
        ]
        app.launch()

        let toastContainer = app.otherElements["toast-container"]
        let appeared = toastContainer.waitForExistence(timeout: 3.0)
        XCTAssertTrue(appeared, "AC-01: Toast 容器应在保存成功后出现")
    }

    // MARK: - AC-02 Toast 2 秒后自动消失

    func testAC02ToastDisappearsAfter2Seconds() throws
    {
        let app = XCUIApplication()
        app.launchArguments += [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_RESET_ONBOARDING",
            "--UITEST_RESET_AUTOSAVE_SETTINGS",
            "--UITEST_ENABLE_AUTOSAVE",
            "--UITEST_TOAST_TRIGGER", "hello-world.md"
        ]
        app.launch()

        let toastContainer = app.otherElements["toast-container"]
        XCTAssertTrue(toastContainer.waitForExistence(timeout: 3.0), "Toast 应出现")

        // 轮询 toast-container 不存在（含 0.2s 退出动画余量，超时 3.5s）
        let disappeared = NSPredicate(format: "exists == false")
        let expectation = expectation(for: disappeared, evaluatedWith: toastContainer, handler: nil)
        wait(for: [expectation], timeout: 3.5)
        XCTAssertFalse(toastContainer.exists, "AC-02: Toast 应在 2 秒后消失")
    }

    // MARK: - AC-03 Toast 显示文件名

    func testAC03ToastDisplaysFileName() throws
    {
        let app = XCUIApplication()
        app.launchArguments += [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_RESET_ONBOARDING",
            "--UITEST_RESET_AUTOSAVE_SETTINGS",
            "--UITEST_ENABLE_AUTOSAVE",
            "--UITEST_TOAST_TRIGGER", "hello-world.md"
        ]
        app.launch()

        let fileNameText = app.staticTexts["toast-filename-text"]
        XCTAssertTrue(fileNameText.waitForExistence(timeout: 3.0), "AC-03: toast-filename-text 应存在")
        XCTAssertEqual(fileNameText.value as? String, "hello-world.md", "AC-03: 应显示实际文件名")
    }

    // MARK: - AC-06 F2.1 总开关关闭时不弹 Toast

    func testAC06NoToastWhenF2xDisabled() throws
    {
        let app = XCUIApplication()
        app.launchArguments += [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_RESET_ONBOARDING",
            "--UITEST_RESET_AUTOSAVE_SETTINGS",
            "--UITEST_TOAST_TRIGGER", "hello-world.md"
        ]
        app.launch()

        // 不启用 F2.1 总开关，触发 Toast 应被过滤
        let toastContainer = app.otherElements["toast-container"]
        let notAppeared = !toastContainer.waitForExistence(timeout: 2.0)
        XCTAssertTrue(notAppeared, "AC-06: F2.1 总开关关闭时不应出现 Toast")
    }

    // MARK: - AC-09 Toast 位置在屏幕顶部居中

    func testAC09ToastPositionedAtTopCenter() throws
    {
        let app = XCUIApplication()
        app.launchArguments += [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_RESET_ONBOARDING",
            "--UITEST_RESET_AUTOSAVE_SETTINGS",
            "--UITEST_ENABLE_AUTOSAVE",
            "--UITEST_TOAST_TRIGGER", "hello-world.md"
        ]
        app.launch()

        let toastContainer = app.otherElements["toast-container"]
        XCTAssertTrue(toastContainer.waitForExistence(timeout: 3.0), "Toast 应出现")

        // CI 无头环境 NSScreen.main 可能为 nil（fallback bounds 仍能创建 Toast），
        // 仅跳过依赖真实屏幕几何的位置断言，Toast 出现的断言保留在 CI 自动验证。
        let hasRealScreen = NSScreen.main != nil || !NSScreen.screens.isEmpty
        try XCTSkipUnless(
            hasRealScreen,
            "精确 Toast 屏幕位置需要真实 NSScreen，CI 无头环境不验证"
        )

        let frame = toastContainer.frame
        let screen = NSScreen.main ?? NSScreen.screens.first
        let screenFrame = screen!.frame
        let screenCenterX = screenFrame.midX
        let toastCenterX = frame.midX
        XCTAssertEqual(toastCenterX, screenCenterX, accuracy: 5, "AC-09: Toast 应水平居中")

        let topInset = screenFrame.maxY - frame.maxY
        XCTAssertGreaterThanOrEqual(topInset, 16, "AC-09: 距顶部应 ≥ 16pt")
        XCTAssertLessThanOrEqual(topInset, 32, "AC-09: 距顶部应 ≤ 32pt")
    }

    // MARK: - AC-11 Toast 不依赖窗口焦点

    func testAC11ToastDoesNotRequireFocus() throws
    {
        let app = XCUIApplication()
        app.launchArguments += [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_RESET_ONBOARDING",
            "--UITEST_RESET_AUTOSAVE_SETTINGS",
            "--UITEST_ENABLE_AUTOSAVE",
            "--UITEST_TOAST_TRIGGER", "hello-world.md"
        ]
        app.launch()

        // Toast 是屏幕级浮层，不依赖主窗口激活
        let toastContainer = app.otherElements["toast-container"]
        XCTAssertTrue(
            toastContainer.waitForExistence(timeout: 3.0),
            "AC-11: Toast 应在不依赖焦点的情况下出现"
        )
    }
}
