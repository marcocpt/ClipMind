@testable import ClipMind
import XCTest

private struct ExpectedTag
{
    let contentType: ContentType
    let name: String
    let color: ClipTagColor
}

final class SystemTagCatalogTests: XCTestCase
{
    func testDefinitionsMatchLegacyTextAndColor()
    {
        let expected: [ExpectedTag] = [
            ExpectedTag(contentType: .code, name: "CODE", color: .violet),
            ExpectedTag(contentType: .link, name: "LINK", color: .cyan),
            ExpectedTag(contentType: .error, name: "ERROR", color: .rose),
            ExpectedTag(contentType: .article, name: "ARTICLE", color: .blue),
            ExpectedTag(contentType: .todo, name: "TODO", color: .amber),
            ExpectedTag(contentType: .meeting, name: "MEETING", color: .emerald),
            ExpectedTag(contentType: .translation, name: "TRANS", color: .purple),
            ExpectedTag(contentType: .requirement, name: "REQ", color: .orange),
            ExpectedTag(contentType: .apiDoc, name: "API", color: .teal),
            ExpectedTag(contentType: .englishDoc, name: "DOC", color: .slate),
            ExpectedTag(contentType: .other, name: "OTHER", color: .gray)
        ]

        XCTAssertEqual(SystemTagCatalog.all.count, expected.count)
        for item in expected
        {
            let tag = SystemTagCatalog.tag(for: item.contentType)
            XCTAssertEqual(tag.id, .system(item.contentType))
            XCTAssertEqual(tag.name, item.name)
            XCTAssertEqual(tag.color, item.color)
            XCTAssertEqual(tag.source, .system)
        }
    }

    func testNewItemStateAssociatesOnlyItsOwnSystemTag()
    {
        let state = ClipTagState.newItem(contentType: .code)

        XCTAssertEqual(state.orderedTagIDs, [.system(.code)])
        XCTAssertEqual(state.systemTagDisposition, .associated)
        XCTAssertEqual(state.migrationVersion, ClipTagState.currentMigrationVersion)
    }

    func testLegacyStateRequiresMigration()
    {
        XCTAssertTrue(ClipTagState.legacy.requiresMigration)
        XCTAssertEqual(ClipTagState.legacy.systemTagDisposition, .pendingMigration)
    }
}
