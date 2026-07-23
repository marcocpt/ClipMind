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
