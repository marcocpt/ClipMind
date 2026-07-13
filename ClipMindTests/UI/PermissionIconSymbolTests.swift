import AppKit
import XCTest

/// 辅助功能权限行图标渲染测试
///
/// 原 `PermissionRequestView` 使用 `Image(systemName: "accessibility")`，
/// 但该 SF Symbol 在 macOS 13 运行时不可用（NSImage 返回 nil），导致图标不显示。
/// 修复后改用 `hand.raised.fill`（macOS 11+ 可用），语义上表示"举手请求权限"。
final class PermissionIconSymbolTests: XCTestCase {
    /// 辅助功能权限行修复后使用的 SF Symbol 必须可加载
    func testAccessibilityIconSFSymbolCanBeLoaded() {
        let image = NSImage(systemSymbolName: "hand.raised.fill", accessibilityDescription: nil)
        XCTAssertNotNil(image, "SF Symbol 'hand.raised.fill' 必须可加载；若为 nil 说明该名称在当前系统不可用")
    }

    /// 通知权限行使用的 SF Symbol 必须可加载（对照组）
    func testBellFillSFSymbolCanBeLoaded() {
        let image = NSImage(systemSymbolName: "bell.fill", accessibilityDescription: nil)
        XCTAssertNotNil(image, "SF Symbol 'bell.fill' 必须可加载")
    }
}
