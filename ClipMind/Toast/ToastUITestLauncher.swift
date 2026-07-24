import Foundation

/// F2.1.1 UITEST 入口分发器：根据启动参数派发模拟通知。
///
/// 从 AppDelegate 抽出，避免 AppDelegate 类型体过大触发 SwiftLint 警告。
/// 所有方法仅用于 XCUITest 环境，生产环境不触发。
enum ToastUITestLauncher
{
    /// 根据启动参数派发对应的模拟通知。
    /// 支持：`--UITEST_TOAST_TRIGGER`、`--UITEST_TOAST_TRIGGER_MULTIPLE`、
    /// `--UITEST_TOAST_SKIP`、`--UITEST_TOAST_FAIL`。
    static func launchIfNeeded()
    {
        let args = CommandLine.arguments
        triggerSingleIfNeeded(args: args)
        triggerMultipleIfNeeded(args: args)
        triggerSkipIfNeeded(args: args)
        triggerFailIfNeeded(args: args)
    }

    /// 单次触发：`--UITEST_TOAST_TRIGGER <fileName>`
    private static func triggerSingleIfNeeded(args: [String])
    {
        guard let triggerIndex = args.firstIndex(of: "--UITEST_TOAST_TRIGGER") else
        {
            return
        }
        let fileName = (triggerIndex + 1 < args.count)
            ? args[triggerIndex + 1]
            : "test.md"
        LogCategory.app.logger.info("UITEST 触发 Toast: fileName=\(fileName, privacy: .public)")
        DispatchQueue.main.async
        {
            NotificationCenter.default.post(
                name: AutoSaveService.savedNotification,
                object: nil,
                userInfo: [
                    "eventId": "uitest-toast-trigger",
                    "fileName": fileName,
                    "skipped": false
                ]
            )
        }
    }

    /// 多次触发：`--UITEST_TOAST_TRIGGER_MULTIPLE "a.md|500|b.md|1000|c.md"`
    private static func triggerMultipleIfNeeded(args: [String])
    {
        guard let multiIndex = args.firstIndex(of: "--UITEST_TOAST_TRIGGER_MULTIPLE") else
        {
            return
        }
        let payload = (multiIndex + 1 < args.count)
            ? args[multiIndex + 1]
            : "test.md"
        let parts = payload.split(separator: "|").map(String.init)
        var delay: TimeInterval = 0.5
        var index = 0
        for part in parts
        {
            if let intervalMs = Double(part)
            {
                delay += intervalMs / 1000.0
            } else {
                let fileName = part
                let fireDelay = delay
                let fireIndex = index
                DispatchQueue.main.asyncAfter(deadline: .now() + fireDelay)
                {
                    NotificationCenter.default.post(
                        name: AutoSaveService.savedNotification,
                        object: nil,
                        userInfo: [
                            "eventId": "uitest-toast-trigger-\(fireIndex)",
                            "fileName": fileName,
                            "skipped": false
                        ]
                    )
                }
                index += 1
            }
        }
    }

    /// 跳过场景：`--UITEST_TOAST_SKIP`（skipped=true，不弹 Toast）
    private static func triggerSkipIfNeeded(args: [String])
    {
        guard args.contains("--UITEST_TOAST_SKIP") else
        {
            return
        }
        DispatchQueue.main.async
        {
            NotificationCenter.default.post(
                name: AutoSaveService.savedNotification,
                object: nil,
                userInfo: [
                    "eventId": "uitest-toast-skip",
                    "skipped": true
                ]
            )
        }
    }

    /// 失败场景：`--UITEST_TOAST_FAIL`（skipped=true + errorNotification）
    private static func triggerFailIfNeeded(args: [String])
    {
        guard args.contains("--UITEST_TOAST_FAIL") else
        {
            return
        }
        DispatchQueue.main.async
        {
            NotificationCenter.default.post(
                name: AutoSaveService.savedNotification,
                object: nil,
                userInfo: [
                    "eventId": "uitest-toast-fail",
                    "skipped": true
                ]
            )
            NotificationCenter.default.post(
                name: AutoSaveService.errorNotification,
                object: nil,
                userInfo: ["errorCode": "uitest-failure"]
            )
        }
    }
}
