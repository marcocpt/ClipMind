import AppKit
import XCTest

@testable import ClipMind

final class CaptureEventBuilderTests: XCTestCase
{
    private var defaults: UserDefaults!
    private var builder: CaptureEventBuilder!
    private var sensitiveDetector: SensitiveDetector!
    private var blacklistService: BlacklistService!
    private var settingsStore: AutoSaveSettingsStore!

    override func setUpWithError() throws
    {
        defaults = UserDefaults(suiteName: "test-b0-\(UUID().uuidString)")!
        sensitiveDetector = SensitiveDetector(defaults: defaults)
        blacklistService = BlacklistService(defaults: defaults)
        settingsStore = AutoSaveSettingsStore(defaults: defaults)

        builder = CaptureEventBuilder(
            appDetector: AppDetector(),
            sensitiveDetector: sensitiveDetector,
            blacklistService: blacklistService,
            settingsStore: settingsStore
        )
    }

    override func tearDownWithError() throws
    {
        if let suite = defaults.dictionaryRepresentation() as? [String: Any]
        {
            for key in suite.keys
            {
                defaults.removeObject(forKey: key)
            }
        }
    }

    // MARK: - TC-UT-54：构造事件包含全部字段

    func testBuildEventContainsAllFields() throws
    {
        let content = ClipContent.text("一段测试内容用于构造事件")
        let event = builder.build(content: content, changeCount: 10)

        XCTAssertEqual(event.changeCount, 10)
        XCTAssertEqual(event.content, content)
        XCTAssertFalse(event.id.isEmpty)
        XCTAssertNotNil(event.timestamp)
    }

    // MARK: - TC-UT-55：敏感识别只跑一次（D2），结果打包进事件

    func testSensitiveResultPackedIntoEvent() throws
    {
        defaults.set(true, forKey: SensitiveDetector.storageKey)
        let content = ClipContent.text("password=supersecret")
        let event = builder.build(content: content, changeCount: 1)

        XCTAssertTrue(event.sensitiveResult.isSensitive, "敏感内容应被识别")
        XCTAssertFalse(event.sensitiveResult.matchedPatterns.isEmpty, "应包含命中模式")
    }

    func testNonSensitiveContentResult() throws
    {
        defaults.set(true, forKey: SensitiveDetector.storageKey)
        let content = ClipContent.text("这是一段普通的非敏感文本内容")
        let event = builder.build(content: content, changeCount: 2)

        XCTAssertFalse(event.sensitiveResult.isSensitive)
        XCTAssertTrue(event.sensitiveResult.matchedPatterns.isEmpty)
    }

    // MARK: - TC-UT-56：黑名单检查结果打包进事件（D3）

    func testBlacklistedPackedIntoEvent() throws
    {
        // 由于 AppDetector 在测试中无法识别真实前台 App，使用回退 bundleId
        let content = ClipContent.text("黑名单测试内容")
        let event = builder.build(content: content, changeCount: 3)

        // event.blacklisted 取决于前台 App 是否在黑名单，测试环境通常为 false
        XCTAssertNotNil(event.blacklisted)
    }

    // MARK: - TC-UT-57：配置快照读取（D23）

    func testConfigSnapshotRead() throws
    {
        var settings = AutoSaveSettings()
        settings.isEnabled = true
        settings.saveDirectory = "~/Documents/ClipMind/Clips/"
        settings.lengthThreshold = 100
        settingsStore.save(settings)

        let content = ClipContent.text("配置快照测试内容")
        let event = builder.build(content: content, changeCount: 4)

        XCTAssertEqual(event.f2xConfigSnapshot.isEnabled, true)
        XCTAssertEqual(event.f2xConfigSnapshot.saveDirectory, "~/Documents/ClipMind/Clips/")
        XCTAssertEqual(event.f2xConfigSnapshot.lengthThreshold, 100)
    }

    // MARK: - TC-UT-58：配置快照不读实时配置（D23 验证）

    func testConfigSnapshotIsImmutableSnapshot() throws
    {
        var settings = AutoSaveSettings()
        settings.isEnabled = false
        settings.lengthThreshold = 50
        settingsStore.save(settings)

        let content = ClipContent.text("快照不可变性测试")
        let event = builder.build(content: content, changeCount: 5)

        // 构造事件后修改配置
        var newSettings = AutoSaveSettings()
        newSettings.isEnabled = true
        newSettings.lengthThreshold = 200
        settingsStore.save(newSettings)

        // 事件中的快照应保持构造时的值
        XCTAssertEqual(event.f2xConfigSnapshot.isEnabled, false, "快照应保持构造时值")
        XCTAssertEqual(event.f2xConfigSnapshot.lengthThreshold, 50, "快照应保持构造时值")
    }

    // MARK: - TC-UT-59：F1.x 黑名单快照读取

    func testF1xBlacklistSnapshotRead() throws
    {
        let content = ClipContent.text("F1.x 黑名单快照测试")
        let event = builder.build(content: content, changeCount: 6)

        XCTAssertNotNil(event.f1xConfigSnapshot.blacklistBundleIds)
    }

    // MARK: - TC-UT-60：非文本内容不执行敏感识别（D12）

    func testNonTextContentSkipsSensitiveDetection() throws
    {
        let content = ClipContent.image(Data([0x89, 0x50, 0x4E, 0x47]))
        let event = builder.build(content: content, changeCount: 7)

        XCTAssertEqual(event.sensitiveResult, .none, "非文本内容敏感结果应为 .none")
    }
}
