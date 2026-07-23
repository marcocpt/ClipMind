import Foundation

@testable import ClipMind

/// F2.1.1 测试 Fixtures：构造 savedNotification 通知与 Mock 依赖。
enum ToastCoordinatorFixtures
{
    /// 构造保存完成通知。
    /// - Parameters:
    ///   - eventId: 事件标识（默认 "test-event-id"）
    ///   - fileName: 文件名（成功时传入，跳过时为 nil）
    ///   - skipped: 是否跳过（默认 false，即成功）
    static func makeSavedNotification(
        eventId: String = "test-event-id",
        fileName: String? = "test.md",
        skipped: Bool = false
    ) -> Notification
    {
        var userInfo: [String: Any] = ["eventId": eventId]
        if let fileName = fileName
        {
            userInfo["fileName"] = fileName
        }
        if skipped
        {
            userInfo["skipped"] = true
        }
        return Notification(
            name: AutoSaveService.savedNotification,
            object: nil,
            userInfo: userInfo
        )
    }
}

/// 测试专用：模拟 NSScreen.main 为 nil 的窗口承载模块（E4 场景）。
///
/// show 直接调用 onShowFailed 回调，模拟 ToastWindowManager 在
/// NSScreen.main 查询失败时的降级路径。
final class NoScreenToastWindowManager: ToastWindowManager
{
    override func show(fileName: String)
    {
        onShowFailed?()
    }
}

/// 测试专用：模拟窗口创建失败（E5 场景）。
///
/// 与 NoScreenToastWindowManager 行为一致，命名上区分场景。
final class FailOnShowToastWindowManager: ToastWindowManager
{
    override func show(fileName: String)
    {
        onShowFailed?()
    }
}

/// 测试专用：模拟进入动画失败的窗口承载模块（E6 场景）。
///
/// show 不主动触发任何回调，模拟动画启动异常、completionHandler
/// 未被调用的情况。测试通过 `simulateDidAppear` 手动触发兜底回调，
/// 模拟 ToastWindowManager 中 completionHandler 强制推进状态机的路径。
final class AnimFailureToastWindowManager: ToastWindowManager
{
    override func show(fileName: String)
    {
        // 不触发任何回调，等待测试手动调用 simulateDidAppear
    }

    /// 测试手动触发进入动画完成回调（模拟 completionHandler 兜底）。
    func simulateDidAppear()
    {
        onDidAppear?()
    }
}
