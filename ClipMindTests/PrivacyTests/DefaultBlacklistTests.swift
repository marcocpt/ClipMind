@testable import ClipMind
import Foundation
import XCTest

/// DefaultBlacklist 单元测试（T3.4）
final class DefaultBlacklistTests: XCTestCase {
    /// 默认黑名单条目
    private var entries: [BlacklistEntry]!

    override func setUpWithError() throws {
        entries = DefaultBlacklist.entries
    }

    override func tearDownWithError() throws {
        entries = nil
    }

    // MARK: - 默认黑名单包含 7 个条目

    func testDefaultBlacklistHas7Entries() {
        XCTAssertEqual(entries.count, 7, "默认黑名单应包含 7 个条目")
    }

    // MARK: - 包含 1Password

    func testContains1Password() {
        let onePassword = entries.first { $0.bundleId == "com.agilebits.onepassword-os" }
        XCTAssertNotNil(onePassword, "应包含 1Password")
        XCTAssertEqual(onePassword?.appName, "1Password", "应用名称应为 1Password")
    }

    // MARK: - 包含钥匙串访问

    func testContainsKeychainAccess() {
        let keychain = entries.first { $0.bundleId == "com.apple.keychainaccess" }
        XCTAssertNotNil(keychain, "应包含钥匙串访问")
        XCTAssertEqual(keychain?.appName, "钥匙串访问", "应用名称应为 钥匙串访问")
    }

    // MARK: - 包含 5 家银行

    func testContainsAll5Banks() {
        let bankBundleIds = entries
            .filter { $0.bundleId.hasSuffix(".*") }
            .map(\.bundleId)
        XCTAssertTrue(bankBundleIds.contains("com.icbc.*"), "应包含工商银行")
        XCTAssertTrue(bankBundleIds.contains("com.cmb.*"), "应包含招商银行")
        XCTAssertTrue(bankBundleIds.contains("com.chinaccb.*"), "应包含建设银行")
        XCTAssertTrue(bankBundleIds.contains("com.abchina.*"), "应包含农业银行")
        XCTAssertTrue(bankBundleIds.contains("com.boc.*"), "应包含中国银行")
    }

    // MARK: - 所有条目 isDefault=true

    func testAllEntriesAreDefault() {
        for entry in entries {
            XCTAssertTrue(
                entry.isDefault,
                "条目 \(entry.appName) 的 isDefault 应为 true"
            )
        }
    }

    // MARK: - bundleId 正确

    func testBundleIdsAreCorrect() {
        let bundleIds = Set(entries.map(\.bundleId))
        XCTAssertTrue(bundleIds.contains("com.agilebits.onepassword-os"), "应包含 1Password 的 bundleId")
        XCTAssertTrue(bundleIds.contains("com.apple.keychainaccess"), "应包含钥匙串访问的 bundleId")
        XCTAssertTrue(bundleIds.contains("com.icbc.*"), "应包含工商银行的 bundleId")
        XCTAssertTrue(bundleIds.contains("com.cmb.*"), "应包含招商银行的 bundleId")
        XCTAssertTrue(bundleIds.contains("com.chinaccb.*"), "应包含建设银行的 bundleId")
        XCTAssertTrue(bundleIds.contains("com.abchina.*"), "应包含农业银行的 bundleId")
        XCTAssertTrue(bundleIds.contains("com.boc.*"), "应包含中国银行的 bundleId")
    }

    // MARK: - createEntries 返回 7 个条目

    func testCreateEntriesReturns7Entries() {
        let created = DefaultBlacklist.createEntries()
        XCTAssertEqual(created.count, 7, "createEntries 应返回 7 个条目")
        XCTAssertEqual(Set(created.map(\.bundleId)).count, 7, "7 个 bundleId 应唯一")
    }
}
