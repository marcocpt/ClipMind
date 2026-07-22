import Foundation

/// 捕获事件构造器（B0）。
///
/// 落地 D1（事件驱动模型）、D2（敏感识别只跑一次）、D3（黑名单优先）、
/// D6（配置快照）、D23（配置快照机制）。
///
/// 在 PasteboardWatcher 检测到 changeCount 变化并完成去重后调用，
/// 负责识别来源 App、执行黑名单与敏感识别、读取配置快照，
/// 构造不可变 CaptureEvent 返回。
///
/// 敏感识别（D2）：只执行一次，结果以 SensitiveMatchResult 打包进事件，
/// F1.x 与 F2.1 分支共享同一结果按各自规则独立判断。
///
/// 黑名单检查（D3）：结果打包进 event.blacklisted，
/// F2.1 分支命中黑名单始终不保存（FR-018）。
final class CaptureEventBuilder
{
    /// 前台应用检测器
    private let appDetector: AppDetector

    /// 敏感内容识别器
    private let sensitiveDetector: SensitiveDetector

    /// 黑名单服务
    private let blacklistService: BlacklistService

    /// F2.1 自动保存配置存储
    private let settingsStore: AutoSaveSettingsStore

    /// 日志记录器
    private let logger = LogCategory.capture.logger

    /// - Parameters:
    ///   - appDetector: 前台应用检测器
    ///   - sensitiveDetector: 敏感内容识别器
    ///   - blacklistService: 黑名单服务
    ///   - settingsStore: F2.1 自动保存配置存储
    init(appDetector: AppDetector,
         sensitiveDetector: SensitiveDetector,
         blacklistService: BlacklistService,
         settingsStore: AutoSaveSettingsStore)
    {
        self.appDetector = appDetector
        self.sensitiveDetector = sensitiveDetector
        self.blacklistService = blacklistService
        self.settingsStore = settingsStore
    }

    /// 构造不可变 CaptureEvent。
    ///
    /// - Parameters:
    ///   - content: 剪贴板内容
    ///   - changeCount: 当前 pasteboard.changeCount
    /// - Returns: 构造的事件；来源 App 无法识别时使用回退值，始终返回非 nil 事件
    func build(content: ClipContent, changeCount: Int) -> CaptureEvent?
    {
        // 步骤 2：识别来源 App（无法识别时回退 "unknown"/"Unknown"）
        let (bundleId, appName) = appDetector.currentFrontmostApp() ?? ("unknown", "Unknown")

        // 步骤 4：黑名单检查（D3，结果打包进事件）
        let blacklisted = blacklistService.contains(bundleId: bundleId)

        // 步骤 5：敏感识别（D2 只跑一次，仅对文本执行）
        let sensitiveResult = performSensitiveDetection(content: content)

        // 步骤 6（去重已在 PasteboardWatcher 完成）

        // 读取配置快照（D23 事件构造阶段读取，异步执行期间不读实时配置）
        let f2xConfig = F2xConfigSnapshot(from: settingsStore.load())
        let f1xConfig = F1xConfigSnapshot(
            blacklistBundleIds: blacklistService.getAll().map { $0.bundleId }
        )

        let contentLen = contentLength(of: content)
        let isSensitive = sensitiveResult.isSensitive
        logger.debug(
            "Event: changeCount=\(changeCount, privacy: .public), length=\(contentLen, privacy: .public)"
        )
        logger.debug(
            "Flags: blacklisted=\(blacklisted, privacy: .public), sensitive=\(isSensitive, privacy: .public)"
        )

        // 步骤 7：构造 CaptureEvent
        return CaptureEvent(
            id: UUID().uuidString,
            changeCount: changeCount,
            content: content,
            bundleId: bundleId,
            appName: appName,
            blacklisted: blacklisted,
            sensitiveResult: sensitiveResult,
            f1xConfigSnapshot: f1xConfig,
            f2xConfigSnapshot: f2xConfig,
            timestamp: Date()
        )
    }

    // MARK: - Private

    /// 执行敏感识别（D2 只跑一次）。
    /// 仅对文本内容执行，非文本返回 .none（D12）。
    private func performSensitiveDetection(content: ClipContent) -> SensitiveMatchResult
    {
        guard case .text(let text) = content else
        {
            return .none
        }

        guard let sensitiveType = sensitiveDetector.detect(text) else
        {
            return .none
        }
        return SensitiveMatchResult(
            isSensitive: true,
            matchedPatterns: [sensitiveType.rawValue]
        )
    }

    /// 计算内容长度（用于日志记录，D12 100KB 上限判断依据）。
    private func contentLength(of content: ClipContent) -> Int
    {
        switch content
        {
        case .text(let text):
            return text.count
        case .image(let data):
            return data.count
        case .filePath(let urls):
            return urls.count
        }
    }
}
