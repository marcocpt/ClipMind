import Foundation

/// F1.9 快速粘贴面板配置持久化（UserDefaults + 范围校验 + 变更通知）。
///
/// Phase 1 仅持久化"浮层超时兜底时长"（供 Phase 3 降级浮层使用）。
/// 后续 Phase 如需新增字段，按相同模式扩展。
public final class QuickPasteSettings
{
    /// 配置变更通知名（监听方在浮层显示前重新读取最新值）。
    public static let didChangeNotification = Notification.Name("ClipMindQuickPasteSettingsDidChange")

    /// 浮层超时兜底时长范围（秒）。
    public static let overlayDurationRange: ClosedRange<Double> = 1.0...30.0

    /// 浮层超时兜底时长默认值（秒）。
    public static let overlayDurationDefault: Double = 5.0

    private let defaults: UserDefaults

    private enum Keys
    {
        static let overlayDuration = "F1.9.quickPaste.overlayDuration"
    }

    /// - Parameter defaults: UserDefaults 实例（测试注入隔离 suite，生产用 .standard）
    public init(defaults: UserDefaults = .standard)
    {
        self.defaults = defaults
    }

    /// 读取浮层超时兜底时长（秒），未设置时返回默认值 5.0。
    public func loadOverlayDuration() -> Double
    {
        let stored = defaults.object(forKey: Keys.overlayDuration) as? Double
            ?? Self.overlayDurationDefault
        return clamped(stored)
    }

    /// 保存浮层超时兜底时长（秒），自动钳制到 1.0...30.0 范围，并发送变更通知。
    /// - Parameter duration: 期望时长（秒），超出范围会被钳制
    public func saveOverlayDuration(_ duration: Double)
    {
        let clampedDuration = clamped(duration)
        defaults.set(clampedDuration, forKey: Keys.overlayDuration)
        LogCategory.app.info("QuickPaste overlay duration saved: \(clampedDuration)s")
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }

    private func clamped(_ value: Double) -> Double
    {
        min(max(value, Self.overlayDurationRange.lowerBound), Self.overlayDurationRange.upperBound)
    }
}
