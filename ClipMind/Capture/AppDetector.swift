import AppKit
import Foundation

/// 前台应用检测器。
///
/// 通过 NSWorkspace.shared.frontmostApplication 获取当前前台 App 的
/// bundleId 和 appName，用于记录剪贴板内容的来源应用。
final class AppDetector {
    /// 获取当前前台应用信息
    /// - Returns: 包含 bundleId 和 appName 的元组；若 frontmostApplication 为 nil 则返回 nil
    func currentFrontmostApp() -> (bundleId: String, appName: String)? {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }
        return (app.bundleIdentifier ?? "unknown", app.localizedName ?? "Unknown")
    }
}
