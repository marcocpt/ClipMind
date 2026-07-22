import XCTest

@testable import ClipMind

final class F2xConfigSnapshotTests: XCTestCase
{
    // MARK: - TC-UT-11：配置快照所有属性可访问

    func testAllPropertiesAccessible() throws
    {
        let snapshot = F2xConfigSnapshot(
            isEnabled: true,
            saveDirectory: "~/Documents/ClipMind/Clips/",
            whitelistBundleIds: ["com.apple.Safari", "com.google.Chrome"],
            fileFormat: .markdown,
            lengthThreshold: 100,
            fileNameLength: 20,
            sensitiveFilterEnabled: true,
            pathFormat: .fileURI,
            showFilePathInHistory: true
        )

        XCTAssertTrue(snapshot.isEnabled)
        XCTAssertEqual(snapshot.saveDirectory, "~/Documents/ClipMind/Clips/")
        XCTAssertEqual(snapshot.whitelistBundleIds.count, 2)
        XCTAssertEqual(snapshot.fileFormat, .markdown)
        XCTAssertEqual(snapshot.lengthThreshold, 100)
        XCTAssertEqual(snapshot.fileNameLength, 20)
        XCTAssertTrue(snapshot.sensitiveFilterEnabled)
        XCTAssertEqual(snapshot.pathFormat, .fileURI)
        XCTAssertTrue(snapshot.showFilePathInHistory)
    }

    // MARK: - TC-UT-12：白名单包含判断

    func testWhitelistContains() throws
    {
        let snapshot = F2xConfigSnapshot(
            isEnabled: true,
            saveDirectory: "~/Documents/ClipMind/Clips/",
            whitelistBundleIds: ["com.apple.Safari"],
            fileFormat: .markdown,
            lengthThreshold: 50,
            fileNameLength: 20,
            sensitiveFilterEnabled: true,
            pathFormat: .plainPath,
            showFilePathInHistory: true
        )

        XCTAssertTrue(snapshot.isWhitelisted(bundleId: "com.apple.Safari"))
        XCTAssertFalse(snapshot.isWhitelisted(bundleId: "com.apple.finder"))
    }

    // MARK: - TC-UT-13：从 AutoSaveSettings 构造快照（D23）

    func testFromAutoSaveSettings() throws
    {
        let settings = AutoSaveSettings(
            isEnabled: true,
            saveDirectory: "/tmp/clips/",
            whitelistBundleIds: ["com.test.app"],
            fileFormat: .plainText,
            lengthThreshold: 200,
            fileNameLength: 30,
            sensitiveFilterEnabled: false,
            pathFormat: .markdownLink,
            showFilePathInHistory: false
        )

        let snapshot = F2xConfigSnapshot(from: settings)

        XCTAssertEqual(snapshot.isEnabled, settings.isEnabled)
        XCTAssertEqual(snapshot.saveDirectory, settings.saveDirectory)
        XCTAssertEqual(snapshot.whitelistBundleIds, settings.whitelistBundleIds)
        XCTAssertEqual(snapshot.fileFormat, settings.fileFormat)
        XCTAssertEqual(snapshot.lengthThreshold, settings.lengthThreshold)
        XCTAssertEqual(snapshot.fileNameLength, settings.fileNameLength)
        XCTAssertEqual(snapshot.sensitiveFilterEnabled, settings.sensitiveFilterEnabled)
        XCTAssertEqual(snapshot.pathFormat, settings.pathFormat)
        XCTAssertEqual(snapshot.showFilePathInHistory, settings.showFilePathInHistory)
    }
}
