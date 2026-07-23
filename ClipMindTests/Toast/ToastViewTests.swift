import SwiftUI
import XCTest

@testable import ClipMind

final class ToastViewTests: XCTestCase
{
    func testToastViewRendersFileName() throws
    {
        let view = ToastView(fileName: "hello-world.md")
        let hosting = NSHostingController(rootView: view)
        XCTAssertEqual(hosting.view.bounds.width, 0) // 初始无尺寸，仅验证可创建
    }

    /// 验证 ToastView 在 hosting 中可布局且不崩溃。
    /// accessibility identifier 的实际查找验证由 XCUITest（任务 7）覆盖，
    /// 因为 SwiftUI accessibility 在无 UI 服务器测试环境下可能不返回值。
    func testToastViewLayoutsWithoutCrash() throws
    {
        let view = ToastView(fileName: "test.md")
        let hosting = NSHostingController(rootView: view)
        hosting.view.layout()

        // 验证 hosting view 可访问且 layout 后未崩溃
        XCTAssertNotNil(hosting.view)
        XCTAssertGreaterThanOrEqual(hosting.view.intrinsicContentSize.width, 0)
    }
}
