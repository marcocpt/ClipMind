@testable import ClipMind
import XCTest

final class APIKeyManagerTests: XCTestCase {
    private var keyManager: APIKeyManager!

    override func setUp() {
        super.setUp()
        keyManager = APIKeyManager()
        // 清理之前的测试数据：所有 provider 的 key + UserDefaults 中的 provider
        clearAllKeychainKeys()
        UserDefaults.standard.removeObject(forKey: "apiProvider")
    }

    override func tearDown() {
        // 清理测试数据：所有 provider 的 key + UserDefaults 中的 provider
        clearAllKeychainKeys()
        UserDefaults.standard.removeObject(forKey: "apiProvider")
        keyManager = nil
        super.tearDown()
    }

    // MARK: - TC-17-01: 未配置 API Key 时 isConfigured 为 false

    func testIsConfiguredReturnsFalseWhenNoKey() {
        // 无任何配置时，isConfigured 必须为 false（按钮置灰判断依据）
        XCTAssertFalse(keyManager.isConfigured, "未配置 API Key 时 isConfigured 应为 false")
    }

    // MARK: - 保存 API Key 后 isConfigured 为 true

    func testIsConfiguredReturnsTrueAfterSave() throws {
        try keyManager.saveKey("test-key-openai", for: .openai)

        XCTAssertTrue(keyManager.isConfigured, "保存 API Key 后 isConfigured 应为 true")
    }

    // MARK: - 保存后能正确读取

    func testSaveAndLoadKey() throws {
        try keyManager.saveKey("test-key-openai-123", for: .openai)

        let loaded = keyManager.loadKey(for: .openai)
        XCTAssertEqual(loaded, "test-key-openai-123", "读取的 API Key 应与保存的相同")
    }

    // MARK: - 删除后 isConfigured 为 false

    func testDeleteKeyRemovesFromKeychain() throws {
        try keyManager.saveKey("test-key-openai", for: .openai)
        XCTAssertTrue(keyManager.isConfigured, "保存后应已配置")

        keyManager.deleteKey(for: .openai)

        XCTAssertNil(keyManager.loadKey(for: .openai), "删除后读取应返回 nil")
        XCTAssertFalse(keyManager.isConfigured, "删除后 isConfigured 应为 false")
    }

    // MARK: - 按 provider 区分存储

    func testKeysStoredPerProvider() throws {
        try keyManager.saveKey("test-key-openai", for: .openai)
        try keyManager.saveKey("test-key-zhipu", for: .zhipu)
        try keyManager.saveKey("test-key-qianwen", for: .qianwen)
        try keyManager.saveKey("test-key-deepseek", for: .deepseek)

        XCTAssertEqual(keyManager.loadKey(for: .openai), "test-key-openai")
        XCTAssertEqual(keyManager.loadKey(for: .zhipu), "test-key-zhipu")
        XCTAssertEqual(keyManager.loadKey(for: .qianwen), "test-key-qianwen")
        XCTAssertEqual(keyManager.loadKey(for: .deepseek), "test-key-deepseek")
    }

    // MARK: - 切换 provider 时 key 不混淆

    func testSwitchingProviderDoesNotMixKeys() throws {
        // 先保存 openai 的 key，并切换 currentProvider 到 openai
        try keyManager.saveKey("openai-key", for: .openai)
        XCTAssertEqual(keyManager.currentProvider, .openai)

        // 再保存 zhipu 的 key，currentProvider 切换到 zhipu
        try keyManager.saveKey("zhipu-key", for: .zhipu)
        XCTAssertEqual(keyManager.currentProvider, .zhipu)

        // openai 的 key 仍然存在，不会混淆
        XCTAssertEqual(keyManager.loadKey(for: .openai), "openai-key", "切换 provider 后 openai 的 key 不应丢失")
        XCTAssertEqual(keyManager.loadKey(for: .zhipu), "zhipu-key", "zhipu 的 key 应保持正确")
    }

    // MARK: - clearAll 清除所有配置

    func testClearAllRemovesEverything() throws {
        try keyManager.saveKey("openai-key", for: .openai)
        try keyManager.saveKey("zhipu-key", for: .zhipu)
        try keyManager.saveKey("qianwen-key", for: .qianwen)
        try keyManager.saveKey("deepseek-key", for: .deepseek)
        XCTAssertTrue(keyManager.isConfigured)

        keyManager.clearAll()

        // 所有 provider 的 key 都被清除
        for provider in APIProvider.allCases {
            XCTAssertNil(keyManager.loadKey(for: provider), "clearAll 后 \(provider) 的 key 应为 nil")
        }
        XCTAssertNil(keyManager.currentProvider, "clearAll 后 currentProvider 应为 nil")
        XCTAssertFalse(keyManager.isConfigured, "clearAll 后 isConfigured 应为 false")
    }

    // MARK: - currentProvider 从 UserDefaults 读取

    func testCurrentProviderReadsFromUserDefaults() {
        // 直接写入 UserDefaults，验证 currentProvider 能读到
        UserDefaults.standard.set(APIProvider.zhipu.rawValue, forKey: "apiProvider")

        XCTAssertEqual(keyManager.currentProvider, .zhipu, "currentProvider 应从 UserDefaults 读取")
    }

    // MARK: - 保存 key 时同时更新 provider

    func testSaveKeyUpdatesProvider() throws {
        // 初始状态：未配置 provider
        XCTAssertNil(keyManager.currentProvider)

        try keyManager.saveKey("test-key-deepseek", for: .deepseek)

        XCTAssertEqual(keyManager.currentProvider, .deepseek, "saveKey 应同时更新 currentProvider")
        // UserDefaults 也应同步更新
        let stored = UserDefaults.standard.string(forKey: "apiProvider")
        XCTAssertEqual(stored, APIProvider.deepseek.rawValue, "UserDefaults 中的 apiProvider 应被同步更新")
    }

    // MARK: - 保存空字符串 key 时抛出错误

    func testSaveEmptyKeyThrows() {
        XCTAssertThrowsError(try keyManager.saveKey("", for: .openai)) { error in
            // 空字符串应抛出 APIKeyError，而不是写入 Keychain
            XCTAssert(error is APIKeyError, "保存空 key 应抛出 APIKeyError")
        }
        // 验证没有写入任何内容
        XCTAssertNil(keyManager.loadKey(for: .openai), "空 key 不应被写入 Keychain")
        XCTAssertFalse(keyManager.isConfigured, "空 key 不应使 isConfigured 为 true")
    }

    // MARK: - 重复保存相同 provider 的 key 时更新而非报错

    func testSaveDuplicateKeyUpdates() throws {
        try keyManager.saveKey("old-key", for: .openai)
        XCTAssertEqual(keyManager.loadKey(for: .openai), "old-key")

        // 重复保存不应抛错（更新而非插入失败）
        try keyManager.saveKey("new-key", for: .openai)

        XCTAssertEqual(keyManager.loadKey(for: .openai), "new-key", "重复保存应更新为新的 key")
    }

    // MARK: - currentProvider 为 nil 时 isConfigured 为 false

    func testIsConfiguredFalseWhenProviderNotSet() throws {
        // 保存了某个 provider 的 key，但 currentProvider 不是这个 provider
        try keyManager.saveKey("openai-key", for: .openai)
        XCTAssertEqual(keyManager.currentProvider, .openai)
        XCTAssertTrue(keyManager.isConfigured)

        // 模拟用户清除 provider 选择，但 key 仍在 Keychain
        UserDefaults.standard.removeObject(forKey: "apiProvider")

        XCTAssertNil(keyManager.currentProvider, "清除 UserDefaults 后 currentProvider 应为 nil")
        XCTAssertFalse(keyManager.isConfigured, "currentProvider 为 nil 时 isConfigured 应为 false")
    }

    // MARK: - validateKey 在已配置时返回 .valid

    func testValidateKeyReturnsValidForConfiguredKey() async throws {
        try keyManager.saveKey("test-key-openai", for: .openai)

        let result = await keyManager.validateKey(for: .openai)

        // 测试环境无法发起真实 API 请求，预期返回 .valid 表示 key 已就绪可验证
        XCTAssertEqual(result, .valid, "已配置 key 时 validateKey 应返回 .valid")
    }

    func testValidateKeyReturnsInvalidWhenKeyMissing() async {
        // 未配置 key 时，validateKey 应返回 .invalid 而非 .networkError
        let result = await keyManager.validateKey(for: .openai)

        XCTAssertEqual(result, .invalid, "未配置 key 时 validateKey 应返回 .invalid")
    }

    // MARK: - 辅助方法

    private func clearAllKeychainKeys() {
        for provider in APIProvider.allCases {
            keyManager.deleteKey(for: provider)
        }
    }
}
