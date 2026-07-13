import AppKit
import XCTest

/// AppIcon 资源存在性测试
///
/// 用户反馈应用在 Dock / 菜单栏显示默认占位图标。
/// 本测试验证 app bundle 中存在 AppIcon 资源（来自 Assets.xcassets）。
final class AppIconAssetTests: XCTestCase {
    /// Assets.xcassets 必须编译为 Assets.car 并打入 app bundle
    func testAssetsCatalogCompiledIntoBundle() {
        let carURL = Bundle.main.url(forResource: "Assets", withExtension: "car")
        XCTAssertNotNil(carURL, "Assets.car 应存在于 app bundle；若为 nil 说明未配置 Assets.xcassets")
    }

    /// AppIcon 命名资源必须可从 app bundle 加载
    func testAppIconImageExistsInBundle() {
        let icon = NSImage(named: "AppIcon")
        XCTAssertNotNil(icon, "NSImage(named: \"AppIcon\") 应返回非 nil；若为 nil 说明 Assets.xcassets 未包含 AppIcon")
    }
}
