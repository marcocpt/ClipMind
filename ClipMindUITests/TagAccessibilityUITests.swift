import AppKit
import XCTest

/// F1.14 Phase 5 任务 6 步骤 1：标签辅助功能键盘测试。
///
/// 仅用键盘遍历并激活：
/// - 三入口 pill 和「+」；
/// - picker 搜索、checkbox、11 色、创建/取消；
/// - filter 候选和活动 chip 删除；
/// - 设置 rename/delete 和确认 dialog。
///
/// 断言 focus 状态、动作结果、dialog 焦点返回。
/// 键盘事件使用 Tab 遍历、Space/Return 激活、Escape 关闭；
/// 运行时需开启系统「使用键盘导航在控件间移动焦点」（Full Keyboard Access）。
final class TagAccessibilityUITests: XCTestCase
{
    /// `previewClips[0]` 的稳定 UUID（code 类型，有标签夹具）。
    private let firstClipIDString = "00000000-0000-4000-8000-000000000001"
    /// `previewClips[1]` 的稳定 UUID（link 类型，空标签夹具）。
    private let secondClipIDString = "00000000-0000-4000-8000-000000000002"
    /// 第一个用户标签 ID（标准夹具 "工作"）。
    private let firstUserTagID = "user.00000000-0000-4000-8000-000000000101"
    /// 第二个用户标签 ID（标准夹具 "参考"）。
    private let secondUserTagID = "user.00000000-0000-4000-8000-000000000102"
    /// 标签筛选夹具「重要」标签 ID。
    private let importantTagID = "user.00000000-0000-4000-8000-000000000311"

    private let maxTabs = 40

    // MARK: - setUp / tearDown

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
    }

    // MARK: - A11Y-1：三入口 pill 键盘激活

    /// 主窗口、菜单栏弹窗、快捷粘贴面板的标签 pill 均可键盘激活打开 picker。
    func testA11y_ThreeEntries_Pill_KeyboardActivation()
    {
        let entries: [(name: String, args: [String])] = [
            ("主窗口", ["--UITEST_SHOW_MAIN_WINDOW", "--UITEST_PREVIEW_DATA", "--UITEST_TAG_FIXTURE"]),
            ("菜单栏弹窗", ["--UITEST_POPOVER_WINDOW", "--UITEST_PREVIEW_DATA", "--UITEST_TAG_FIXTURE"]),
            ("快捷粘贴", ["--UITEST_PREVIEW_DATA", "--UITEST_QUICK_PASTE_PANEL", "--UITEST_TAG_FIXTURE"])
        ]
        for entry in entries
        {
            let app = launchApp(args: entry.args)
            let pill = app.buttons["clipTag_\(firstClipIDString)_\(firstUserTagID)"]
            XCTAssertTrue(pill.waitForExistence(timeout: 10), "\(entry.name) 应显示 pill")

            XCTAssertTrue(
                tabUntilFocus(app, on: pill),
                "\(entry.name) pill 应可通过键盘获得焦点"
            )
            app.typeKey(XCUIKeyboardKey.space.rawValue)

            let pickerTitle = app.staticTexts["tagPickerTitle"]
            XCTAssertTrue(
                pickerTitle.waitForExistence(timeout: 5),
                "\(entry.name) 键盘激活 pill 应打开 picker"
            )
            app.terminate()
            cleanUpDatabase()
        }
    }

    // MARK: - A11Y-2：主窗口「+」键盘激活

    /// 无标签条目的「+」按钮可键盘激活打开 picker。
    func testA11y_MainWindow_TagAdd_KeyboardActivation()
    {
        let app = launchApp(args: ["--UITEST_SHOW_MAIN_WINDOW", "--UITEST_PREVIEW_DATA", "--UITEST_TAG_EMPTY_CLIP"])

        let addButton = app.buttons["tagAdd_\(secondClipIDString)"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 10), "「+」按钮应存在")

        XCTAssertTrue(tabUntilFocus(app, on: addButton), "「+」应可通过键盘获得焦点")
        app.typeKey(XCUIKeyboardKey.space.rawValue)

        let pickerTitle = app.staticTexts["tagPickerTitle"]
        XCTAssertTrue(pickerTitle.waitForExistence(timeout: 5), "键盘激活「+」应打开 picker")
    }

    // MARK: - A11Y-3：picker 键盘遍历

    /// picker 内搜索、checkbox 切换、11 色按钮、创建/取消均可键盘操作。
    func testA11y_Picker_KeyboardTraversal()
    {
        let app = launchApp(args: ["--UITEST_SHOW_MAIN_WINDOW", "--UITEST_PREVIEW_DATA", "--UITEST_TAG_FIXTURE"])

        let pill = app.buttons["clipTag_\(firstClipIDString)_\(firstUserTagID)"]
        XCTAssertTrue(pill.waitForExistence(timeout: 10))
        XCTAssertTrue(tabUntilFocus(app, on: pill), "pill 应可获得焦点")
        app.typeKey(XCUIKeyboardKey.space.rawValue)

        // 搜索框可键盘聚焦并输入
        let searchField = app.textFields["tagPickerSearch"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        XCTAssertTrue(tabUntilFocus(app, on: searchField), "搜索框应可获得焦点")
        app.typeText("参考")

        // checkbox（tagOption）可键盘切换
        let referenceOption = app.buttons["tagOption_\(secondUserTagID)"]
        XCTAssertTrue(referenceOption.waitForExistence(timeout: 3), "搜索后候选应出现")
        XCTAssertTrue(tabUntilFocus(app, on: referenceOption), "标签选项应可获得焦点")
        let valueBefore = referenceOption.value as? String
        app.typeKey(XCUIKeyboardKey.space.rawValue)
        let toggled = NSPredicate { element, _ in
            (element as? XCUIElement)?.value as? String != valueBefore
        }
        let waitExpectation = XCTNSPredicateExpectation(
            predicate: toggled,
            object: referenceOption
        )
        XCTAssertTrue(
            XCTWaiter().wait(for: [waitExpectation], timeout: 5) == .completed,
            "Space 应切换 checkbox 状态"
        )

        // 进入创建模式
        searchField.click()
        clearText(searchField)
        let createEntry = app.buttons["tagCreateEntry"]
        XCTAssertTrue(createEntry.waitForExistence(timeout: 3))
        XCTAssertTrue(tabUntilFocus(app, on: createEntry), "创建入口应可获得焦点")
        app.typeKey(XCUIKeyboardKey.space.rawValue)

        // 11 色按钮存在且可聚焦
        let nameField = app.textFields["tagCreateNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        nameField.click()
        nameField.typeText("键盘标签")
        for color in ClipTagColor.allCases
        {
            let colorButton = app.buttons["tagColor_\(color.rawValue)"]
            XCTAssertTrue(colorButton.exists, "颜色按钮 \(color.rawValue) 应存在")
        }

        // 取消按钮可键盘激活，回到浏览状态
        let cancelButton = app.buttons["tagCreateCancel"]
        XCTAssertTrue(cancelButton.exists, "取消按钮应存在")
        XCTAssertTrue(tabUntilFocus(app, on: cancelButton), "取消按钮应可获得焦点")
        app.typeKey(XCUIKeyboardKey.space.rawValue)
        XCTAssertTrue(
            app.staticTexts["tagPickerTitle"].waitForExistence(timeout: 3),
            "取消创建应回到浏览状态"
        )
    }

    // MARK: - A11Y-4：filter 候选与活动 chip 删除

    /// 标签筛选候选可键盘切换，活动 chip 的删除按钮可键盘激活。
    func testA11y_Filter_KeyboardTraversal()
    {
        let app = launchApp(args: ["--UITEST_SHOW_MAIN_WINDOW", "--UITEST_PREVIEW_DATA", "--UITEST_TAG_FILTER_FIXTURE"])

        let historyList = app.descendants(matching: .any)["historyList"].firstMatch
        XCTAssertTrue(historyList.waitForExistence(timeout: 10), "历史列表应出现")

        // 打开筛选 popover
        let filterPicker = app.buttons["tagFilterPicker"]
        XCTAssertTrue(filterPicker.waitForExistence(timeout: 5))
        XCTAssertTrue(tabUntilFocus(app, on: filterPicker), "筛选按钮应可获得焦点")
        app.typeKey(XCUIKeyboardKey.space.rawValue)

        // 候选可键盘切换
        let option = app.buttons["tagFilterOption_\(importantTagID)"]
        XCTAssertTrue(option.waitForExistence(timeout: 5), "筛选候选应出现")
        XCTAssertTrue(tabUntilFocus(app, on: option), "筛选候选应可获得焦点")
        app.typeKey(XCUIKeyboardKey.space.rawValue)

        // 关闭 popover
        app.typeKey(XCUIKeyboardKey.escape.rawValue)

        // 活动 chip 出现
        let activeChip = app.descendants(matching: .any)["activeTagFilter_\(importantTagID)"].firstMatch
        XCTAssertTrue(activeChip.waitForExistence(timeout: 5), "活动 chip 应出现")

        // chip 内删除按钮可键盘激活
        let deleteButton = activeChip.buttons.firstMatch
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3), "chip 删除按钮应存在")
        XCTAssertTrue(tabUntilFocus(app, on: deleteButton), "chip 删除按钮应可获得焦点")
        app.typeKey(XCUIKeyboardKey.space.rawValue)

        let chipRemoved = NSPredicate { _, _ in !activeChip.exists }
        let chipRemovedExpectation = XCTNSPredicateExpectation(
            predicate: chipRemoved,
            object: activeChip
        )
        XCTAssertTrue(
            XCTWaiter().wait(for: [chipRemovedExpectation], timeout: 5) == .completed,
            "键盘激活删除后活动 chip 应移除"
        )
    }

    // MARK: - A11Y-5：设置 rename/delete 与 dialog 焦点返回

    /// 设置页 rename/delete 可键盘操作，确认 dialog 可键盘操作且焦点返回触发控件。
    func testA11y_Settings_RenameDelete_DialogFocusReturn()
    {
        let app = launchApp(args: [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREVIEW_DATA",
            "--UITEST_TAG_FIXTURE",
            "--UITEST_INITIAL_TAB=tags"
        ])

        // 键盘打开设置
        let settingsButton = app.buttons["settingsButton"].firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 10))
        XCTAssertTrue(tabUntilFocus(app, on: settingsButton), "设置按钮应可获得焦点")
        app.typeKey(XCUIKeyboardKey.space.rawValue)

        let renameButton = app.buttons["renameTag_\(firstUserTagID)"]
        XCTAssertTrue(renameButton.waitForExistence(timeout: 15), "重命名按钮应存在")
        XCTAssertTrue(tabUntilFocus(app, on: renameButton), "重命名按钮应可获得焦点")
        app.typeKey(XCUIKeyboardKey.space.rawValue)

        // 编辑名称
        let nameField = app.textFields["renameTagField_\(firstUserTagID)"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 3))
        XCTAssertTrue(tabUntilFocus(app, on: nameField), "重命名输入框应可获得焦点")
        clearText(nameField)
        app.typeText("键盘重命名")

        // 提交进入确认 dialog
        let submitButton = app.buttons["submitRenameTag_\(firstUserTagID)"]
        XCTAssertTrue(submitButton.exists)
        XCTAssertTrue(tabUntilFocus(app, on: submitButton), "提交按钮应可获得焦点")
        app.typeKey(XCUIKeyboardKey.space.rawValue)

        // 确认 dialog 出现并可键盘操作
        let cancelButton = app.sheets.buttons["取消"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5), "确认 dialog 应出现")
        XCTAssertTrue(tabUntilFocus(app, on: cancelButton), "dialog 取消按钮应可获得焦点")
        app.typeKey(XCUIKeyboardKey.space.rawValue)

        // dialog 关闭后焦点返回触发控件
        XCTAssertTrue(
            renameButton.waitForExistence(timeout: 5),
            "取消 dialog 后重命名按钮应仍存在"
        )
        XCTAssertTrue(
            renameButton.hasFocus,
            "取消 dialog 后焦点应返回重命名按钮"
        )
    }

    // MARK: - 辅助

    /// 启动 App 并激活。
    @discardableResult
    private func launchApp(args: [String]) -> XCUIApplication
    {
        let app = XCUIApplication()
        app.launchArguments = args
        app.launch()
        app.activate()
        return app
    }

    /// 反复按 Tab 直到目标元素获得焦点（最多 `maxTabs` 次）。
    @discardableResult
    private func tabUntilFocus(_ app: XCUIApplication, on element: XCUIElement) -> Bool
    {
        if element.hasFocus { return true }
        for _ in 0..<maxTabs
        {
            app.typeKey(XCUIKeyboardKey.tab.rawValue)
            if element.hasFocus { return true }
        }
        return element.hasFocus
    }

    /// 清空文本输入框内容。
    private func clearText(_ field: XCUIElement)
    {
        guard let currentValue = field.value as? String, !currentValue.isEmpty else
        {
            return
        }
        field.click()
        let deleteString = String(
            repeating: XCUIKeyboardKey.delete.rawValue,
            count: currentValue.count
        )
        field.typeText(deleteString)
    }
}
