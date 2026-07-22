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
        XCTAssertTrue(settings.showFilePathInHistory, "showFilePathInHistory 默认应为开启")
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

    // MARK: - TC-UT-70：clampedInt 静态方法 - 字符串解析与夹紧

    /// 验证 clampedInt 静态方法对各种输入的处理：
    /// - 有效数字：直接返回
    /// - 越界：夹紧到边界
    /// - 空值/非数字/空白：回退到 fallback
    /// 决策 C2（夹紧到边界）+ C3（空值/非数字回退到当前值）

    func testClampedIntParsesValidNumber() throws
    {
        let result = AutoSaveSettings.clampedInt(
            "100",
            range: AutoSaveSettings.lengthThresholdRange,
            fallback: 50
        )
        XCTAssertEqual(result, 100, "有效数字应直接返回")
    }

    func testClampedIntClampsAboveRange() throws
    {
        let result = AutoSaveSettings.clampedInt(
            "10001",
            range: AutoSaveSettings.lengthThresholdRange,
            fallback: 50
        )
        XCTAssertEqual(result, 10000, "越界上界应夹紧到 upperBound")
    }

    func testClampedIntClampsBelowRange() throws
    {
        let result = AutoSaveSettings.clampedInt(
            "0",
            range: AutoSaveSettings.lengthThresholdRange,
            fallback: 50
        )
        XCTAssertEqual(result, 1, "越界下界应夹紧到 lowerBound")
    }

    func testClampedIntClampsNegative() throws
    {
        let result = AutoSaveSettings.clampedInt(
            "-5",
            range: AutoSaveSettings.lengthThresholdRange,
            fallback: 50
        )
        XCTAssertEqual(result, 1, "负数应夹紧到 lowerBound")
    }

    func testClampedIntEmptyFallback() throws
    {
        let result = AutoSaveSettings.clampedInt(
            "",
            range: AutoSaveSettings.lengthThresholdRange,
            fallback: 50
        )
        XCTAssertEqual(result, 50, "空字符串应回退到 fallback")
    }

    func testClampedIntNonNumericFallback() throws
    {
        let result = AutoSaveSettings.clampedInt(
            "abc",
            range: AutoSaveSettings.lengthThresholdRange,
            fallback: 50
        )
        XCTAssertEqual(result, 50, "非数字应回退到 fallback")
    }

    func testClampedIntWhitespaceFallback() throws
    {
        let result = AutoSaveSettings.clampedInt(
            "   ",
            range: AutoSaveSettings.lengthThresholdRange,
            fallback: 50
        )
        XCTAssertEqual(result, 50, "纯空白应回退到 fallback")
    }

    // MARK: - TC-UT-71：clampedInt 套用 fileNameLengthRange

    func testClampedIntFileNameLengthRange() throws
    {
        XCTAssertEqual(
            AutoSaveSettings.clampedInt(
                "30",
                range: AutoSaveSettings.fileNameLengthRange,
                fallback: 20
            ),
            30,
            "fileNameLength 范围内有效数字应直接返回"
        )

        XCTAssertEqual(
            AutoSaveSettings.clampedInt(
                "100",
                range: AutoSaveSettings.fileNameLengthRange,
                fallback: 20
            ),
            50,
            "fileNameLength 越界上界应夹紧到 50"
        )

        XCTAssertEqual(
            AutoSaveSettings.clampedInt(
                "0",
                range: AutoSaveSettings.fileNameLengthRange,
                fallback: 20
            ),
            1,
            "fileNameLength 越界下界应夹紧到 1"
        )

        XCTAssertEqual(
            AutoSaveSettings.clampedInt(
                "",
                range: AutoSaveSettings.fileNameLengthRange,
                fallback: 20
            ),
            20,
            "fileNameLength 空字符串应回退到 fallback"
        )
    }
}
