@testable import ClipMind
import XCTest

final class SourceFilterViewModelTests: XCTestCase
{
    func testInitialState_allSelected()
    {
        let sources = Set(["Safari", "Xcode", "Notes"])
        let selected = SourceFilterSelection(allApps: sources)
        XCTAssertTrue(selected.isAllSelected)
        XCTAssertEqual(selected.selectedSources, sources)
    }

    func testToggleSingleApp_whenAllSelected_deselectsAll()
    {
        let sources = Set(["Safari", "Xcode", "Notes"])
        var selected = SourceFilterSelection(allApps: sources)
        selected.toggleSource("Safari")
        XCTAssertFalse(selected.isAllSelected)
        XCTAssertEqual(selected.selectedSources, ["Safari"])
    }

    func testToggleAll_selectsAllApps()
    {
        let sources = Set(["Safari", "Xcode", "Notes"])
        var selected = SourceFilterSelection(allApps: sources)
        selected.toggleSource("Safari")
        selected.toggleAll()
        XCTAssertTrue(selected.isAllSelected)
        XCTAssertEqual(selected.selectedSources, sources)
    }

    func testSelectAllAppsIndividually_autoSelectsAll()
    {
        let sources = Set(["Safari", "Xcode"])
        var selected = SourceFilterSelection(allApps: sources)
        selected.toggleAll()
        selected.toggleSource("Safari")
        selected.toggleSource("Xcode")
        XCTAssertTrue(selected.isAllSelected)
    }

    func testDeselectOneApp_afterAllSelected_deselectsAll()
    {
        let sources = Set(["Safari", "Xcode", "Notes"])
        var selected = SourceFilterSelection(allApps: sources)
        XCTAssertTrue(selected.isAllSelected)
        selected.deselectSource("Safari")
        XCTAssertFalse(selected.isAllSelected)
        XCTAssertEqual(selected.selectedSources, ["Xcode", "Notes"])
    }

    func testEmptySources_isAllSelected_returnTrue()
    {
        let selected = SourceFilterSelection(allApps: [])
        XCTAssertTrue(selected.isAllSelected)
        XCTAssertEqual(selected.selectedSources, [] as Set<String>)
    }
}
