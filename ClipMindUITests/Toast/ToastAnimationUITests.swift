import XCTest

final class ToastAnimationUITests: XCTestCase
{
    override func setUpWithError() throws
    {
        try super.setUpWithError()
        if ProcessInfo.processInfo.environment["CLIPMIND_SKIP_PANEL_UITESTS"] == "1"
        {
            throw XCTSkip(
                "当前 CI 环境无法可靠验证 NSPanel Accessibility 可见性"
            )
        }
        continueAfterFailure = false
    }

    // AC-08 进入动画启动后立即断言 Toast 容器存在
    func testAC08ToastContainerExistsDuringEntryAnimation() throws
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

        // 进入动画启动后立即断言 toast-container 存在（不等待 0.2s 动画完成）
        let toastContainer = app.otherElements["toast-container"]
        let appeared = toastContainer.waitForExistence(timeout: 1.0)
        XCTAssertTrue(appeared, "AC-08: 进入动画启动后 Toast 容器应立即存在")

        // 断言动画期间 toast-container 仍可见
        XCTAssertTrue(toastContainer.isHittable, "AC-08: 进入动画期间 Toast 应可点击（可见）")
    }
}
