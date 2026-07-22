import XCTest

@testable import ClipMind

final class AutoSaveSettingsTests: XCTestCase
{
    // MARK: - TC-UT-14：默认值（D11 总开关默认关闭）

    func testDefaultValues() throws
    {
        let settings = AutoSaveSettings()

        XCTAssertFalse(settings.isEnabled, "D11：总开关默认应为关闭")
        XCTAssertEqual(settings.saveDirectory, "~/Documents/ClipMind/Clips/")
        XCTAssertEqual(settings.whitelistBundleIds, AutoSaveSettings.defaultWhitelist)
        XCTAssertEqual(settings.fileFormat, .markdown)
        XCTAssertEqual(settings.lengthThreshold, 50)
        XCTAssertEqual(settings.fileNameLength, 20)
        XCTAssertTrue(settings.sensitiveFilterEnabled)
        XCTAssertEqual(settings.pathFormat, .plainPath)
    }

    // MARK: - TC-UT-15：范围常量

    func testRangeConstants() throws
    {
        XCTAssertEqual(AutoSaveSettings.lengthThresholdRange, 1...10000)
        XCTAssertEqual(AutoSaveSettings.fileNameLengthRange, 1...50)
    }

    // MARK: - TC-UT-16：默认白名单内容

    func testDefaultWhitelistContains() throws
    {
        let whitelist = AutoSaveSettings.defaultWhitelist
        XCTAssertEqual(whitelist.count, 5)
        XCTAssertTrue(whitelist.contains("com.apple.Safari"))
        XCTAssertTrue(whitelist.contains("com.google.Chrome"))
        XCTAssertTrue(whitelist.contains("com.trae.ide"))
        XCTAssertTrue(whitelist.contains("com.microsoft.VSCode"))
        XCTAssertTrue(whitelist.contains("com.apple.dt.Xcode"))
    }

    // MARK: - TC-UT-17：文件格式扩展名

    func testFileFormatExtension() throws
    {
        XCTAssertEqual(FileFormat.markdown.fileExtension, "md")
        XCTAssertEqual(FileFormat.plainText.fileExtension, "txt")
    }

    // MARK: - TC-UT-18：Codable 往返

    func testCodableRoundTrip() throws
    {
        let settings = AutoSaveSettings(
            isEnabled: true,
            saveDirectory: "/tmp/test/",
            whitelistBundleIds: ["com.test.app"],
            fileFormat: .plainText,
            lengthThreshold: 100,
            fileNameLength: 30,
            sensitiveFilterEnabled: false,
            pathFormat: .fileURI
        )

        let encoded = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AutoSaveSettings.self, from: encoded)

        XCTAssertEqual(settings, decoded)
    }

    // MARK: - TC-UT-19：Equatable 相等比较

    func testEquality() throws
    {
        let lhs = AutoSaveSettings()
        let rhs = AutoSaveSettings()
        XCTAssertEqual(lhs, rhs)
    }
}
