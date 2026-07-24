@testable import ClipMind
import XCTest

final class QuickPasteSettingsTests: XCTestCase
{
    private var defaults: UserDefaults!
    private var store: QuickPasteSettings!

    override func setUpWithError() throws
    {
        let suiteName = "ClipMind.QuickPasteSettingsTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        store = QuickPasteSettings(defaults: defaults)
    }

    override func tearDownWithError() throws
    {
        defaults.removePersistentDomain(forName: defaults.dictionaryRepresentation().keys.first ?? "")
        defaults = nil
        store = nil
    }

    // MARK: - 默认值

    func testLoadOverlayDuration_ReturnsDefaultFiveSeconds_WhenNotSet()
    {
        let duration = store.loadOverlayDuration()
        XCTAssertEqual(duration, 5.0, "未设置时应返回默认 5 秒")
    }

    // MARK: - 范围校验

    func testSaveOverlayDuration_ClampsToLowerBound_WhenValueLessThanOne()
    {
        store.saveOverlayDuration(0.5)
        XCTAssertEqual(store.loadOverlayDuration(), 1.0, "小于 1 秒应被钳制为 1 秒")
    }

    func testSaveOverlayDuration_ClampsToUpperBound_WhenValueGreaterThanThirty()
    {
        store.saveOverlayDuration(60.0)
        XCTAssertEqual(store.loadOverlayDuration(), 30.0, "大于 30 秒应被钳制为 30 秒")
    }

    func testSaveOverlayDuration_AcceptsBoundaryValues()
    {
        store.saveOverlayDuration(1.0)
        XCTAssertEqual(store.loadOverlayDuration(), 1.0)
        store.saveOverlayDuration(30.0)
        XCTAssertEqual(store.loadOverlayDuration(), 30.0)
    }

    // MARK: - 持久化

    func testSaveOverlayDuration_PersistsAcrossInstances()
    {
        store.saveOverlayDuration(10.0)
        let newStore = QuickPasteSettings(defaults: defaults)
        XCTAssertEqual(newStore.loadOverlayDuration(), 10.0, "新实例应读取到已持久化的值")
    }

    // MARK: - 变更通知

    func testSaveOverlayDuration_PostsDidChangeNotification()
    {
        let expectation = XCTNSNotificationExpectation(
            name: QuickPasteSettings.didChangeNotification
        )
        store.saveOverlayDuration(8.0)
        wait(for: [expectation], timeout: 1.0)
    }
}
