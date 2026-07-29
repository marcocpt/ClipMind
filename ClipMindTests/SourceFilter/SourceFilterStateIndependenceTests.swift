@testable import ClipMind
import XCTest

/// 来源过滤状态独立性测试。
///
/// 验证多个 SourceFilterSelection 实例之间状态独立互不干扰，
/// 确保主窗口与弹窗可以各自维护不同的过滤状态。
final class SourceFilterStateIndependenceTests: XCTestCase
{
    private static let apps: Set<String> = ["Xcode", "Safari", "Terminal"]

    // MARK: - 主窗口与弹窗过滤状态独立

    func testSeparateInstancesHaveIndependentSelection() throws
    {
        var mainWindow = SourceFilterSelection(allApps: Self.apps)
        var popoverWindow = SourceFilterSelection(allApps: Self.apps)

        // 主窗口选择 Xcode
        mainWindow.toggleSource("Xcode")
        // 弹窗选择 Safari
        popoverWindow.toggleSource("Safari")

        XCTAssertEqual(
            mainWindow.selectedSources,
            ["Xcode"],
            "主窗口应只选中 Xcode"
        )
        XCTAssertEqual(
            popoverWindow.selectedSources,
            ["Safari"],
            "弹窗应只选中 Safari"
        )
        XCTAssertNotEqual(
            mainWindow.selectedSources,
            popoverWindow.selectedSources,
            "两个实例的选择应不同"
        )
    }

    // MARK: - 重置不影响另一实例

    func testResetDoesNotAffectOtherInstance() throws
    {
        var instanceA = SourceFilterSelection(allApps: Self.apps)
        var instanceB = SourceFilterSelection(allApps: Self.apps)

        // 两个实例都只选 Xcode
        instanceA.toggleSource("Xcode")
        instanceB.toggleSource("Xcode")

        // 实例 A 重置为全部
        instanceA.resetToAll()

        XCTAssertTrue(instanceA.isAllSelected, "实例 A 应恢复为全部")
        XCTAssertEqual(
            instanceB.selectedSources,
            ["Xcode"],
            "实例 B 应不受影响，仍只选中 Xcode"
        )
    }

    // MARK: - 重新初始化后恢复「全部」

    func testReinitializationRestoresAllSelected() throws
    {
        var selection = SourceFilterSelection(allApps: Self.apps)
        selection.toggleSource("Safari")
        XCTAssertFalse(selection.isAllSelected, "选择后应不是全部")

        // 重新初始化
        selection = SourceFilterSelection(allApps: Self.apps)
        XCTAssertTrue(selection.isAllSelected, "重新初始化后应恢复为全部")
        XCTAssertEqual(
            selection.selectedSources,
            Self.apps,
            "重新初始化后 selectedSources 应包含所有应用"
        )
    }

    // MARK: - toggleAll 不影响另一实例

    func testToggleAllDoesNotAffectOtherInstance() throws
    {
        var instanceA = SourceFilterSelection(allApps: Self.apps)
        var instanceB = SourceFilterSelection(allApps: Self.apps)

        instanceA.toggleSource("Terminal")
        instanceB.toggleSource("Safari")

        // 实例 A 全选
        instanceA.toggleAll()

        XCTAssertTrue(instanceA.isAllSelected, "实例 A toggleAll 后应全选")
        XCTAssertEqual(
            instanceB.selectedSources,
            ["Safari"],
            "实例 B 应不受 toggleAll 影响"
        )
    }

    // MARK: - 不同 allApps 集合的实例完全独立

    func testDifferentAllAppsSetsAreIndependent() throws
    {
        let appsA: Set<String> = ["Xcode", "Safari"]
        let appsB: Set<String> = ["Terminal", "Notes"]

        var instanceA = SourceFilterSelection(allApps: appsA)
        var instanceB = SourceFilterSelection(allApps: appsB)

        instanceA.toggleSource("Xcode")
        instanceB.toggleSource("Notes")

        XCTAssertEqual(instanceA.selectedSources, ["Xcode"])
        XCTAssertEqual(instanceB.selectedSources, ["Notes"])
        XCTAssertTrue(instanceA.isAllSelected == false)
        XCTAssertTrue(instanceB.isAllSelected == false)

        // 互不影响
        instanceA.resetToAll()
        XCTAssertTrue(instanceA.isAllSelected)
        XCTAssertFalse(instanceB.isAllSelected)
    }
}
