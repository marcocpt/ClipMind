import CryptoKit
import Foundation

/// 剪贴板内容去重器。
///
/// 维护最后一条内容的 SHA256 哈希，连续相同内容判定为重复。
final class Deduplicator {
    /// 最后一条内容的哈希值（十六进制字符串）
    private var lastContentHash: String?

    /// 判断当前内容是否与上一条重复
    /// - Parameter content: 当前剪贴板内容
    /// - Returns: true 表示与上一条内容相同，应过滤；false 表示是新内容
    func isDuplicate(_ content: ClipContent) -> Bool {
        guard let lastContentHash else {
            return false
        }
        return hash(of: content) == lastContentHash
    }

    /// 更新最后一条内容的哈希
    /// - Parameter content: 已入库的内容
    func updateLastContent(_ content: ClipContent) {
        lastContentHash = hash(of: content)
    }

    // MARK: - 哈希计算

    /// 使用 SHA256 计算内容哈希，返回十六进制字符串
    private func hash(of content: ClipContent) -> String {
        let data: Data
        switch content {
        case .text(let text):
            data = Data(text.utf8)
        case .image(let imageData):
            data = imageData
        case .filePath(let urls):
            let joined = urls.map(\.absoluteString).joined(separator: "\n")
            data = Data(joined.utf8)
        }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
