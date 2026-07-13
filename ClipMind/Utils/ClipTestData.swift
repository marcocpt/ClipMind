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

    // MARK: - 首启注入用示例数据

    /// 首启注入用示例数据（13 条，覆盖 11 种 ContentType）。
    ///
    /// 时间戳从当前时间递减分布（5 ~ 240 分钟前），模拟用户在过去 4 小时陆续复制。
    /// embeddings 留空（nil），由 SampleDataSeeder 实时计算后填充。
    /// 每条 isSample=true，便于清除时按 is_sample 列过滤。
    static var sampleClipsForSeeding: [ClipItem] {
        [
            makeSample(
                text: """
                func fetchUser(id: UUID) async throws -> User {
                    let url = URL(string: "https://api.example.com/users/\\(id)")!
                    let (data, response) = try await URLSession.shared.data(from: url)
                    guard let http = response as? HTTPURLResponse,
                          http.statusCode == 200 else {
                        throw UserError.notFound
                    }
                    return try JSONDecoder().decode(User.self, from: data)
                }
                """,
                contentType: .code,
                sourceApp: "com.apple.dt.Xcode",
                sourceAppName: "Xcode",
                minutesAgo: 5
            ),
            makeSample(
                text: """
                import requests

                def get_weather(city: str) -> dict:
                    url = f"https://api.weather.com/v1/{city}"
                    response = requests.get(url, params={"key": "YOUR_API_KEY"})
                    response.raise_for_status()
                    return response.json()
                """,
                contentType: .code,
                sourceApp: "com.apple.Terminal",
                sourceAppName: "Terminal",
                minutesAgo: 12
            ),
            makeSample(
                text: """
                https://developer.apple.com/documentation/swiftui
                SwiftUI Framework Reference - Apple Developer Documentation
                """,
                contentType: .link,
                sourceApp: "com.apple.Safari",
                sourceAppName: "Safari",
                minutesAgo: 18
            ),
            makeSample(
                text: """
                报错 Thread 1: Fatal error: Unexpectedly found nil while unwrapping an Optional value
                Crash occurred in AppDelegate.swift line 42
                """,
                contentType: .error,
                sourceApp: "com.apple.dt.Xcode",
                sourceAppName: "Xcode",
                minutesAgo: 25
            ),
            makeSample(
                text: """
                Traceback (most recent call last):
                  File "scraper.py", line 45, in <module>
                    main()
                  File "scraper.py", line 28, in main
                    items = parse_index(html)
                  File "scraper.py", line 15, in parse_index
                    return data['results'][0]['items']
                IndexError: list index out of range
                """,
                contentType: .error,
                sourceApp: "com.apple.Terminal",
                sourceAppName: "Terminal",
                minutesAgo: 32
            ),
            makeSample(
                text: """
                AI 如何改变软件开发：从自动补全到智能调试
                近年来，大语言模型正在重塑开发者的工作流。代码补全、重构建议、bug 修复都能 \
                通过自然语言描述完成。开发者可以专注于架构设计，将重复性工作交给 AI 助手。
                """,
                contentType: .article,
                sourceApp: "com.apple.Safari",
                sourceAppName: "Safari",
                minutesAgo: 45
            ),
            makeSample(
                text: """
                ## 本周待办
                - [x] 完成 F1.8 设计评审
                - [ ] 实现 SampleDataSeeder 注入逻辑
                - [ ] 补充 UI 测试
                - [ ] 联调首启注入流程
                """,
                contentType: .todo,
                sourceApp: "com.apple.Notes",
                sourceAppName: "Notes",
                minutesAgo: 60
            ),
            makeSample(
                text: """
                ## 产品评审会 - 2026-07-14
                参会人：张三、李四、王五
                议题：F1.8 示例数据特性进度
                决议：7-15 前完成测试并入 main
                """,
                contentType: .meeting,
                sourceApp: "com.apple.Notes",
                sourceAppName: "Notes",
                minutesAgo: 90
            ),
            makeSample(
                text: """
                The quick brown fox jumps over the lazy dog. \
                This pangram contains every letter of the English alphabet, \
                making it useful for testing font rendering and translation systems.
                """,
                contentType: .translation,
                sourceApp: "com.apple.Safari",
                sourceAppName: "Safari",
                minutesAgo: 120
            ),
            makeSample(
                text: """
                用户故事：语义搜索
                作为评审，我希望搜索"报错"能找到 error 类型内容。
                验收标准：搜索"报错"返回 Top-5 含 .error 条目
                """,
                contentType: .requirement,
                sourceApp: "com.apple.Notes",
                sourceAppName: "Notes",
                minutesAgo: 150
            ),
            makeSample(
                text: """
                GET /api/v1/clips
                Query Parameters:
                  - limit (int, default 20): Maximum number of clips
                  - offset (int, default 0): Pagination offset
                  - content_type (string): Filter by type
                Response 200 OK:
                  { "clips": [...], "total": 100 }
                """,
                contentType: .apiDoc,
                sourceApp: "com.apple.dt.Xcode",
                sourceAppName: "Xcode",
                minutesAgo: 180
            ),
            makeSample(
                text: """
                SwiftUI is a modern way to declare user interfaces for any Apple platform. \
                Create beautiful, dynamic apps quickly with declarative syntax.
                """,
                contentType: .englishDoc,
                sourceApp: "com.apple.Safari",
                sourceAppName: "Safari",
                minutesAgo: 210
            ),
            makeSample(
                text: """
                $ md5sum clipmind.db
                a3f5e2b8c9d1f0e7  clipmind.db
                """,
                contentType: .other,
                sourceApp: "com.apple.Terminal",
                sourceAppName: "Terminal",
                minutesAgo: 240
            )
        ]
    }

    /// 构造示例 ClipItem（isSample=true，带时间偏移）
    private static func makeSample(
        text: String,
        contentType: ContentType,
        sourceApp: String,
        sourceAppName: String,
        minutesAgo: Int
    ) -> ClipItem {
        ClipItem(
            id: UUID(),
            content: .text(text),
            contentType: contentType,
            sourceApp: sourceApp,
            sourceAppName: sourceAppName,
            timestamp: Date().addingTimeInterval(-Double(minutesAgo) * 60),
            summary: nil,
            translation: nil,
            rewrite: nil,
            todos: nil,
            embeddings: nil,
            isSample: true
        )
    }
}
