import XCTest

final class ToastReplaceUITests: XCTestCase
{
    override func setUpWithError() throws
    {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    // AC-04 快速多次保存触发替换：500ms 间隔触发 a.md 与 b.md
    func testAC04RapidReplaceShowsLatestFileName() throws
    {
        let app = XCUIApplication()
        app.launchArguments += [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_RESET_ONBOARDING",
            "--UITEST_RESET_AUTOSAVE_SETTINGS",
            "--UITEST_ENABLE_AUTOSAVE",
            "--UITEST_TOAST_TRIGGER_MULTIPLE", "a.md|500|b.md"
        ]
        app.launch()

        let fileNameText = app.staticTexts["toast-filename-text"]
        XCTAssertTrue(fileNameText.waitForExistence(timeout: 3.0), "Toast 应出现显示 a.md")

        // 等待第二次触发（500ms 后）+ 进入动画完成（200ms）
        let waitExpectation = XCTestExpectation(description: "wait for b.md")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5)
        {
            waitExpectation.fulfill()
        }
        wait(for: [waitExpectation], timeout: 2.0)

        XCTAssertEqual(fileNameText.value as? String, "b.md", "AC-04: Toast 应切换显示最新文件名 b.md")

        // 仅存在一个 toast-container（无新旧并存）
        let toastContainers = app.descendants(matching: .any)
            .matching(identifier: "toast-container").allElementsBoundByIndex
        XCTAssertEqual(toastContainers.count, 1, "AC-04: 不应新旧 Toast 并存")

        // 从切换时刻起 2 秒后消失（含退出动画余量）
        let disappearExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: fileNameText
        )
        wait(for: [disappearExpectation], timeout: 3.5)
        XCTAssertFalse(fileNameText.exists, "AC-04: 2 秒后 Toast 应消失")
    }
}
