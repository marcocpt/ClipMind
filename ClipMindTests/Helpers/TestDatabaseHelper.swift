import CommonCrypto
import CryptoKit
import Foundation
import XCTest

/// 测试辅助工具：创建临时数据库路径、提供固定密钥、清理临时文件
enum TestDatabaseHelper {
    /// 创建临时数据库文件 URL，调用方负责清理
    static func makeTempDBPath(suffix: String = "") throws -> URL {
        let tempDir = NSTemporaryDirectory()
        let dir = (tempDir as NSString).appendingPathComponent("ClipMindTests")
        try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let filename = "test_\(UUID().uuidString)\(suffix).db"
        return URL(fileURLWithPath: (dir as NSString).appendingPathComponent(filename))
    }

    /// 固定的测试密钥（避免依赖设备 UUID），256 位
    static func makeTestKey() -> SymmetricKey {
        SymmetricKey(data: Data(repeating: 0xAB, count: 32))
    }

    /// 用已知数据派生测试密钥，便于跨进程一致
    static func makeTestKey(password: String, salt: Data) -> SymmetricKey {
        var derived = Data(count: 32)
        let result = derived.withUnsafeMutableBytes { derivedBytes -> Int32 in
            salt.withUnsafeBytes { saltBytes in
                password.withCString { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes,
                        strlen(passwordBytes),
                        saltBytes.baseAddress,
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        10000,
                        derivedBytes.baseAddress,
                        32
                    )
                }
            }
        }
        precondition(result == 0, "PBKDF2 密钥派生失败")
        return SymmetricKey(data: derived)
    }

    /// 删除临时数据库文件及其附属文件（-wal、-shm）
    static func cleanup(at url: URL) {
        let fileManager = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            let path = url.path + suffix
            if fileManager.fileExists(atPath: path) {
                try? fileManager.removeItem(atPath: path)
            }
        }
    }
}
