import Foundation

/// UI 预览与测试数据辅助。
///
/// 为 popover 和主窗口提供预览用的 ClipItem 数据，覆盖 11 种 ContentType。
/// 在 UI 测试模式下通过 launchArguments 触发注入。
enum ClipTestData {
    /// 预览用剪贴条目（覆盖 11 种 ContentType，3 种来源 App）
    static let previewClips: [ClipItem] = [
        makeClip(
            text: "func viewDidLoad() { super.viewDidLoad() }",
            contentType: .code,
            sourceApp: "com.apple.Xcode",
            sourceAppName: "Xcode"
        ),
        makeClip(
            text: "https://github.com/user/repo",
            contentType: .link,
            sourceApp: "com.apple.Safari",
            sourceAppName: "Safari"
        ),
        makeClip(
            text: "Fatal error: Unexpectedly found nil while unwrapping",
            contentType: .error,
            sourceApp: "com.apple.Terminal",
            sourceAppName: "Terminal"
        ),
        makeClip(
            text: "The future of artificial intelligence in everyday applications",
            contentType: .article,
            sourceApp: "com.apple.Safari",
            sourceAppName: "Safari"
        ),
        makeClip(
            text: "- [ ] Fix login bug before Friday",
            contentType: .todo,
            sourceApp: "com.apple.Notes",
            sourceAppName: "Notes"
        ),
        makeClip(
            text: "Meeting notes: Discussed Q4 roadmap and team assignments",
            contentType: .meeting,
            sourceApp: "com.apple.Notes",
            sourceAppName: "Notes"
        ),
        makeClip(
            text: "Hello World -> Bonjour le Monde",
            contentType: .translation,
            sourceApp: "com.apple.Safari",
            sourceAppName: "Safari"
        ),
        makeClip(
            text: "User Story: As a user, I want to login with email",
            contentType: .requirement,
            sourceApp: "com.apple.Notes",
            sourceAppName: "Notes"
        ),
        makeClip(
            text: "GET /api/v1/users - Returns list of users",
            contentType: .apiDoc,
            sourceApp: "com.apple.Xcode",
            sourceAppName: "Xcode"
        ),
        makeClip(
            text: "Documentation: How to configure the application settings",
            contentType: .englishDoc,
            sourceApp: "com.apple.Safari",
            sourceAppName: "Safari"
        ),
        makeClip(
            text: "12345 67890 abcdef",
            contentType: .other,
            sourceApp: "com.apple.Terminal",
            sourceAppName: "Terminal"
        )
    ]

    /// 预览数据中的来源 App 列表（用于 SourceFilter）
    static let previewSourceApps: [String] = {
        let appNames = Set(previewClips.map(\.sourceAppName))
        return Array(appNames).sorted()
    }()

    /// 创建预览 ClipItem（带时间偏移，使时间戳递减）
    private static func makeClip(
        text: String,
        contentType: ContentType,
        sourceApp: String,
        sourceAppName: String
    ) -> ClipItem {
        ClipItem(
            id: UUID(),
            content: .text(text),
            contentType: contentType,
            sourceApp: sourceApp,
            sourceAppName: sourceAppName,
            timestamp: Date(),
            summary: nil,
            translation: nil,
            rewrite: nil,
            todos: nil,
            embeddings: nil
        )
    }

    /// 判断当前是否为 UI 测试模式
    static var isUITesting: Bool {
        CommandLine.arguments.contains("--UITEST_PREVIEW_DATA")
    }
}
