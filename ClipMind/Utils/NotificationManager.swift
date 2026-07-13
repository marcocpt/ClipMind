import Foundation
import UserNotifications

/// 通知管理器
///
/// 负责发送本地通知，如敏感内容忽略提示等。
struct NotificationManager {
    /// 发送敏感内容已忽略的通知
    static func sendSensitiveContentIgnoredNotification() {
        let content = UNMutableNotificationContent()
        content.title = "ClipMind"
        content.body = "已忽略敏感内容，未入库"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "sensitive-ignored",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                LogCategory.privacy.error("发送敏感内容通知失败: \(error.localizedDescription)")
            }
        }
    }
}
