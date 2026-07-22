import Foundation

@testable import ClipMind

/// 测试夹具（D18），构造各种 CaptureEvent 场景。
enum CaptureEventFixtures
{
    static func shortTextEvent() -> CaptureEvent
    {
        CaptureEvent(
            changeCount: 42,
            content: .text("hello world"),
            bundleId: "com.apple.Safari",
            appName: "Safari",
            blacklisted: false,
            sensitiveResult: SensitiveMatchResult(isSensitive: false, matchedPatterns: []),
            f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: ["com.apple.finder"]),
            f2xConfigSnapshot: F2xConfigSnapshot(
                isEnabled: true,
                saveDirectory: "~/Documents/ClipMind/Clips/",
                whitelistBundleIds: ["com.apple.Safari"],
                fileFormat: .markdown,
                lengthThreshold: 50,
                fileNameLength: 20,
                sensitiveFilterEnabled: true,
                pathFormat: .plainPath
            )
        )
    }

    static func sensitiveContentEvent() -> CaptureEvent
    {
        CaptureEvent(
            changeCount: 43,
            content: .text("password=123456"),
            bundleId: "com.apple.Safari",
            appName: "Safari",
            blacklisted: false,
            sensitiveResult: SensitiveMatchResult(isSensitive: true, matchedPatterns: ["password"]),
            f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: []),
            f2xConfigSnapshot: F2xConfigSnapshot(
                isEnabled: true,
                saveDirectory: "~/Documents/ClipMind/Clips/",
                whitelistBundleIds: ["com.apple.Safari"],
                fileFormat: .markdown,
                lengthThreshold: 50,
                fileNameLength: 20,
                sensitiveFilterEnabled: true,
                pathFormat: .plainPath
            )
        )
    }

    static func blacklistedAppEvent() -> CaptureEvent
    {
        CaptureEvent(
            changeCount: 44,
            content: .text("finder content"),
            bundleId: "com.apple.finder",
            appName: "Finder",
            blacklisted: true,
            sensitiveResult: SensitiveMatchResult(isSensitive: false, matchedPatterns: []),
            f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: ["com.apple.finder"]),
            f2xConfigSnapshot: F2xConfigSnapshot(
                isEnabled: true,
                saveDirectory: "~/Documents/ClipMind/Clips/",
                whitelistBundleIds: ["com.apple.Safari"],
                fileFormat: .markdown,
                lengthThreshold: 50,
                fileNameLength: 20,
                sensitiveFilterEnabled: true,
                pathFormat: .plainPath
            )
        )
    }

    static func longTextEvent(threshold: Int = 50) -> CaptureEvent
    {
        let longText = String(repeating: "a", count: threshold + 100)
        return CaptureEvent(
            changeCount: 45,
            content: .text(longText),
            bundleId: "com.apple.Safari",
            appName: "Safari",
            blacklisted: false,
            sensitiveResult: SensitiveMatchResult(isSensitive: false, matchedPatterns: []),
            f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: []),
            f2xConfigSnapshot: F2xConfigSnapshot(
                isEnabled: true,
                saveDirectory: "~/Documents/ClipMind/Clips/",
                whitelistBundleIds: ["com.apple.Safari"],
                fileFormat: .markdown,
                lengthThreshold: threshold,
                fileNameLength: 20,
                sensitiveFilterEnabled: true,
                pathFormat: .plainPath
            )
        )
    }
}
