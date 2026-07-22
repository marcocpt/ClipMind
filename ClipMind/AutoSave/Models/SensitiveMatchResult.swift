import Foundation

/// 敏感识别结果（D2 敏感识别只执行一次，结果打包进 CaptureEvent）。
///
/// 由 SensitiveDetector 在捕获事件构造阶段执行一次，结果存入 CaptureEvent，
/// 异步 F2.1 流程直接读取，避免重复识别。实现 `Sendable` 保证跨并发边界安全。
public struct SensitiveMatchResult: Sendable, Equatable
{
    public let isSensitive: Bool
    public let matchedPatterns: [String]

    public init(isSensitive: Bool, matchedPatterns: [String])
    {
        self.isSensitive = isSensitive
        self.matchedPatterns = matchedPatterns
    }

    /// 空结果（非敏感，无命中模式）。
    public static let none = SensitiveMatchResult(isSensitive: false, matchedPatterns: [])
}
