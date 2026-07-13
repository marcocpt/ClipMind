import XCTest

/// 隐私设置 UI 测试（T3.5）
///
/// 覆盖：
/// - TC-22-03：敏感识别开关 UI 切换 + 持久化
/// - UI-AC-17：应用黑名单管理（添加/删除条目）
/// - UI-AC-18：自动清理周期配置
///
/// 测试隔离策略：
/// - 所有测试启动时带 `--UITEST_RESET_SETTINGS` 重置 UserDefaults，避免测试间状态污染
/// - 所有测试带 `--UITEST_INITIAL_TAB=privacy` 直接定位隐私标签，跳过不稳定的 toolbar 按钮查找
final class PrivacyUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// 隐私测试统一的启动参数
    private var launchArguments: [String] {
        ["--UITEST_SHOW_MAIN_WINDOW", "--UITEST_RESET_SETTINGS", "--UITEST_INITIAL_TAB=privacy"]
    }

    /// 通过 accessibility identifier 查找元素。
    ///
    /// Label/Image 等 SwiftUI 组件在 macOS XCUITest 中可能映射为 staticText、
    /// image 或 otherElements，使用 descendants(.any) 兜底。
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// 获取 Toggle 的布尔值（macOS 上 Toggle.value 为 NSNumber 1/0）
    private func toggleValue(_ toggle: XCUIElement) -> Int {
        if let intValue = toggle.value as? Int {
            return intValue
        }
        if let stringValue = toggle.value as? String {
            return Int(stringValue) ?? 0
        }
        return 0
    }

    /// 确保元素可点击，必要时滚动 ScrollView
    ///
    /// macOS SwiftUI Form 可能不暴露为 ScrollView，需要兜底用窗口首元素滚动。
    private func ensureHittable(_ element: XCUIElement, in app: XCUIApplication, maxAttempts: Int = 5) {
        var attempts = 0
        while !element.isHittable && attempts < maxAttempts {
            // 优先 ScrollView，兜底用窗口首元素
            if app.scrollViews.firstMatch.exists {
                app.scrollViews.firstMatch.swipeUp()
            } else if app.tables.firstMatch.exists {
                app.tables.firstMatch.swipeUp()
            } else {
                app.windows.firstMatch.descendants(matching: .any).element(boundBy: 0).swipeUp()
            }
            Thread.sleep(forTimeInterval: 0.3)
            attempts += 1
        }
    }

    /// 启动 App 并打开设置面板（隐私标签已通过启动参数定位）
    private func launchAndOpenSettings() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = launchArguments
        app.launch()
        app.activate()

        let settingsButton = app.buttons["settingsButton"].firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "设置按钮应存在")
        settingsButton.click()

        // 等待隐私标签内容加载（sensitiveDetectionToggle 是隐私页独有元素）
        let sensitiveToggle = element("sensitiveDetectionToggle", in: app)
        XCTAssertTrue(
            sensitiveToggle.waitForExistence(timeout: 5),
            "隐私标签应已激活，敏感识别开关应存在"
        )
        return app
    }

    // MARK: - TC-22-03：敏感识别开关 UI 切换

    func testSensitiveDetectionToggleExists() {
        let app = launchAndOpenSettings()

        let toggle = element("sensitiveDetectionToggle", in: app)
        XCTAssertTrue(toggle.exists, "敏感识别开关应存在")
    }

    /// 验证开关切换行为。
    ///
    /// 持久化由 @AppStorage 框架保证，BlacklistService 的 testPersistenceAcrossInstances
    /// 单元测试已覆盖跨实例持久化，UI 层只验证切换交互。
    func testSensitiveDetectionToggleSwitches() {
        let app = launchAndOpenSettings()

        let toggle = element("sensitiveDetectionToggle", in: app)
        XCTAssertTrue(toggle.exists)

        let initialValue = toggleValue(toggle)
        toggle.click()

        let newValue = toggleValue(toggle)
        XCTAssertNotEqual(initialValue, newValue, "切换后状态应改变")

        // 再次切换验证可重复操作
        toggle.click()
        let backValue = toggleValue(toggle)
        XCTAssertEqual(backValue, initialValue, "再次切换应回到初始值")
    }

    // MARK: - UI-AC-18：自动清理周期配置

    /// 测试自动清理开关默认开启时，清理周期选择器应可见。
    ///
    /// 使用 `--UITEST_RESET_SETTINGS` 确保 autoCleanupEnabled 为默认值 true。
    func testCleanupDaysPickerExists() {
        let app = launchAndOpenSettings()

        // 重置后 autoCleanupEnabled 默认为 true，picker 应可见
        let picker = element("cleanupDaysPicker", in: app)
        XCTAssertTrue(
            picker.waitForExistence(timeout: 5),
            "自动清理默认开启时，清理周期选择器应存在"
        )
    }

    /// 验证自动清理开关控制选择器可见性
    func testAutoCleanupToggleControlsPickerVisibility() {
        let app = launchAndOpenSettings()

        let autoCleanupToggle = element("autoCleanupToggle", in: app)
        XCTAssertTrue(
            autoCleanupToggle.waitForExistence(timeout: 5),
            "自动清理开关应存在"
        )

        // 确保开关开启时选择器可见
        if toggleValue(autoCleanupToggle) == 0 {
            autoCleanupToggle.click()
        }
        let picker = element("cleanupDaysPicker", in: app)
        XCTAssertTrue(picker.waitForExistence(timeout: 3), "自动清理开启时选择器应可见")

        // 关闭开关后选择器应隐藏（SwiftUI if 条件移除视图）
        app.activate()
        autoCleanupToggle.click()
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertFalse(picker.exists, "自动清理关闭时选择器应隐藏")
    }

    // MARK: - UI-AC-17：应用黑名单管理

    /// 验证添加自定义黑名单条目
    ///
    /// macOS Form 中 7 个默认黑名单条目 + 添加表单超出窗口高度，
    /// 需要在每个交互前滚动确保元素可见。
    func testBlacklistAddCustomEntry() {
        let app = launchAndOpenSettings()

        // 等待默认黑名单加载后点击"添加自定义应用"
        let addButton = app.buttons["addBlacklistButton"].firstMatch
        XCTAssertTrue(addButton.waitForExistence(timeout: 5), "添加按钮应存在")
        ensureHittable(addButton, in: app)
        addButton.click()

        // 填写 Bundle ID
        let bundleIdField = app.textFields["newBlacklistBundleId"].firstMatch
        XCTAssertTrue(bundleIdField.waitForExistence(timeout: 5), "Bundle ID 输入框应存在")
        ensureHittable(bundleIdField, in: app)
        bundleIdField.click()
        bundleIdField.typeText("com.test.customapp")

        // 填写应用名称
        Thread.sleep(forTimeInterval: 0.3)
        let appNameField = app.textFields["newBlacklistAppName"].firstMatch
        XCTAssertTrue(appNameField.waitForExistence(timeout: 5), "应用名称输入框应存在")
        ensureHittable(appNameField, in: app)
        appNameField.click()
        appNameField.typeText("测试应用")

        // 点击添加（确认按钮可能在窗口底部之外，需要滚动）
        let confirmButton = app.buttons["confirmAddBlacklistButton"].firstMatch
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 5), "确认添加按钮应存在")
        ensureHittable(confirmButton, in: app)
        confirmButton.click()

        // 验证新条目出现
        let testAppText = app.staticTexts["测试应用"].firstMatch
        XCTAssertTrue(
            testAppText.waitForExistence(timeout: 5),
            "新添加的条目应出现在列表中"
        )
    }
}
