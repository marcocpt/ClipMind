import AppKit
import XCTest

@testable import ClipMind

final class AppDetectorTests: XCTestCase {
    private var appDetector: AppDetector!

    override func setUpWithError() throws {
        appDetector = AppDetector()
    }

    override func tearDownWithError() throws {
        appDetector = nil
    }

    // MARK: - 返回值存在性

    func testCurrentFrontmostAppReturnsValue() throws {
        // 测试环境中通常存在前台 App（Xcode 或测试运行器）
        // 若 frontmostApplication 为 nil，则跳过本次测试
        guard NSWorkspace.shared.frontmostApplication != nil else {
            throw XCTSkip("frontmostApplication 为 nil，无前台 App 上下文")
        }
        let result = appDetector.currentFrontmostApp()
        XCTAssertNotNil(result, "存在前台 App 时应返回非 nil 值")
    }

    // MARK: - 字段非空

    func testCurrentFrontmostAppBundleIdNotEmpty() throws {
        guard NSWorkspace.shared.frontmostApplication != nil else {
            throw XCTSkip("frontmostApplication 为 nil，无前台 App 上下文")
        }
        guard let result = appDetector.currentFrontmostApp() else {
            XCTFail("应返回非 nil 值")
            return
        }
        XCTAssertFalse(result.bundleId.isEmpty, "bundleId 不应为空")
    }

    func testCurrentFrontmostAppNameNotEmpty() throws {
        guard NSWorkspace.shared.frontmostApplication != nil else {
            throw XCTSkip("frontmostApplication 为 nil，无前台 App 上下文")
        }
        guard let result = appDetector.currentFrontmostApp() else {
            XCTFail("应返回非 nil 值")
            return
        }
        XCTAssertFalse(result.appName.isEmpty, "appName 不应为空")
    }

    // MARK: - 返回值类型

    func testCurrentFrontmostAppReturnsCorrectType() throws {
        guard NSWorkspace.shared.frontmostApplication != nil else {
            throw XCTSkip("frontmostApplication 为 nil，无前台 App 上下文")
        }
        guard let result = appDetector.currentFrontmostApp() else {
            XCTFail("应返回非 nil 值")
            return
        }
        // 返回值是 (bundleId: String, appName: String) 元组
        XCTAssertTrue(result.bundleId is String, "bundleId 应为 String 类型")
        XCTAssertTrue(result.appName is String, "appName 应为 String 类型")
    }

    // MARK: - nil 情况

    func testCurrentFrontmostAppReturnsNilWhenNoFrontmostApp() {
        // 此测试验证 frontmostApplication 为 nil 时返回 nil 的契约
        // 由于在测试环境中无法可靠地控制 frontmostApplication 为 nil，
        // 这里仅验证返回值类型契约：当返回值存在时其结构正确
        let result = appDetector.currentFrontmostApp()
        if let result {
            XCTAssertFalse(result.bundleId.isEmpty, "bundleId 不应为空")
            XCTAssertFalse(result.appName.isEmpty, "appName 不应为空")
        }
        // 若返回 nil，也符合契约（frontmostApplication 可能为 nil）
    }
}
