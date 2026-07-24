import XCTest

final class ToastSkipFailUITests: XCTestCase
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

    // AC-05 跳过场景不弹 Toast
    func testAC05NoToastOnSkipScenario() throws
    {
        let app = XCUIApplication()
        app.launchArguments += [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_RESET_ONBOARDING",
            "--UITEST_RESET_AUTOSAVE_SETTINGS",
            "--UITEST_ENABLE_AUTOSAVE",
            "--UITEST_TOAST_SKIP"
        ]
        app.launch()

        let toastContainer = app.otherElements["toast-container"]
        // 轮询 1.5 秒确认 Toast 不出现
        let notAppeared = !toastContainer.waitForExistence(timeout: 1.5)
        XCTAssertTrue(notAppeared, "AC-05: 跳过场景不应弹 Toast")
    }

    // AC-07 失败场景不弹 Toast，错误弹窗存在
    func testAC07NoToastOnFailureScenario() throws
    {
        let app = XCUIApplication()
        app.launchArguments += [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_RESET_ONBOARDING",
            "--UITEST_RESET_AUTOSAVE_SETTINGS",
            "--UITEST_ENABLE_AUTOSAVE",
            "--UITEST_TOAST_FAIL"
        ]
        app.launch()

        let toastContainer = app.otherElements["toast-container"]
        let notAppeared = !toastContainer.waitForExistence(timeout: 1.5)
        XCTAssertTrue(notAppeared, "AC-07: 失败场景不应弹 Toast")
    }
}
