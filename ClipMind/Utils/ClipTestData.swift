import Foundation

/// UI 预览与测试数据辅助。
///
/// 为 popover 和主窗口提供预览用的 ClipItem 数据，覆盖 11 种 ContentType。
/// 在 UI 测试模式下通过 launchArguments 触发注入。
enum ClipTestData {
    /// F1.14：预览夹具稳定 UUID 列表，确保同一夹具跨三个 UI-test 入口具有相同 ID、
    /// 系统标签和用户标签关系。索引与 `previewClips` 一一对应。
    static let previewClipIDs: [UUID] = [
        UUID(uuidString: "00000000-0000-4000-8000-000000000001")!,
        UUID(uuidString: "00000000-0000-4000-8000-000000000002")!,
        UUID(uuidString: "00000000-0000-4000-8000-000000000003")!,
        UUID(uuidString: "00000000-0000-4000-8000-000000000004")!,
        UUID(uuidString: "00000000-0000-4000-8000-000000000005")!,
        UUID(uuidString: "00000000-0000-4000-8000-000000000006")!,
        UUID(uuidString: "00000000-0000-4000-8000-000000000007")!,
        UUID(uuidString: "00000000-0000-4000-8000-000000000008")!,
        UUID(uuidString: "00000000-0000-4000-8000-000000000009")!,
        UUID(uuidString: "00000000-0000-4000-8000-00000000000A")!,
        UUID(uuidString: "00000000-0000-4000-8000-00000000000B")!,
        UUID(uuidString: "00000000-0000-4000-8000-00000000000C")!
    ]

    /// 预览用剪贴条目（覆盖 11 种 ContentType，3 种来源 App）
    static let previewClips: [ClipItem] = [
        makeClip(
            id: previewClipIDs[0],
            text: "func viewDidLoad() { super.viewDidLoad() }",
            contentType: .code,
            sourceApp: "com.apple.Xcode",
            sourceAppName: "Xcode"
        ),
        makeClip(
            id: previewClipIDs[1],
            text: "https://github.com/user/repo",
            contentType: .link,
            sourceApp: "com.apple.Safari",
            sourceAppName: "Safari"
        ),
        makeClip(
            id: previewClipIDs[2],
            text: "Fatal error: Unexpectedly found nil while unwrapping",
            contentType: .error,
            sourceApp: "com.apple.Terminal",
            sourceAppName: "Terminal"
        ),
        makeClip(
            id: previewClipIDs[3],
            text: "The future of artificial intelligence in everyday applications",
            contentType: .article,
            sourceApp: "com.apple.Safari",
            sourceAppName: "Safari"
        ),
        makeClip(
            id: previewClipIDs[4],
            text: "- [ ] Fix login bug before Friday",
            contentType: .todo,
            sourceApp: "com.apple.Notes",
            sourceAppName: "Notes"
        ),
        makeClip(
            id: previewClipIDs[5],
            text: "Meeting notes: Discussed Q4 roadmap and team assignments",
            contentType: .meeting,
            sourceApp: "com.apple.Notes",
            sourceAppName: "Notes"
        ),
        makeClip(
            id: previewClipIDs[6],
            text: "Hello World -> Bonjour le Monde",
            contentType: .translation,
            sourceApp: "com.apple.Safari",
            sourceAppName: "Safari"
        ),
        makeClip(
            id: previewClipIDs[7],
            text: "User Story: As a user, I want to login with email",
            contentType: .requirement,
            sourceApp: "com.apple.Notes",
            sourceAppName: "Notes"
        ),
        makeClip(
            id: previewClipIDs[8],
            text: "GET /api/v1/users - Returns list of users",
            contentType: .apiDoc,
            sourceApp: "com.apple.Xcode",
            sourceAppName: "Xcode"
        ),
        makeClip(
            id: previewClipIDs[9],
            text: "Documentation: How to configure the application settings",
            contentType: .englishDoc,
            sourceApp: "com.apple.Safari",
            sourceAppName: "Safari"
        ),
        makeClip(
            id: previewClipIDs[10],
            text: "12345 67890 abcdef",
            contentType: .other,
            sourceApp: "com.apple.Terminal",
            sourceAppName: "Terminal"
        ),
        // F1.16: 多行文本预览测试数据（验证列表行显示最多两行）
        makeClip(
            id: previewClipIDs[11],
            text: "多行剪贴内容第一行\n多行剪贴内容第二行",
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

    /// 创建预览 ClipItem（带稳定 UUID 和时间偏移，使时间戳递减）
    ///
    /// F1.14：`tagState` 设为 `.newItem(contentType:)`，确保持久化到 EncryptedStore 后
    /// 系统标签已关联、迁移不重置 orderedTagIDs，使 `TagUITestSupport` 夹具注入的
    /// 用户标签不会被迁移覆盖。
    private static func makeClip(
        id: UUID,
        text: String,
        contentType: ContentType,
        sourceApp: String,
        sourceAppName: String
    ) -> ClipItem {
        ClipItem(
            id: id,
            content: .text(text),
            contentType: contentType,
            sourceApp: sourceApp,
            sourceAppName: sourceAppName,
            timestamp: Date(),
            summary: nil,
            translation: nil,
            rewrite: nil,
            todos: nil,
            embeddings: nil,
            tagState: .newItem(contentType: contentType)
        )
    }

    // MARK: - F1.14 Phase 3 标签筛选夹具

    /// `--UITEST_TAG_FILTER_FIXTURE` 启动参数。
    static let tagFilterFixtureArg = "--UITEST_TAG_FILTER_FIXTURE"

    /// 标签筛选夹具使用的 4 条稳定 UUID。
    /// 对应计划 phase-3 任务 4 表格中的 `tag-result-1`～`tag-result-4`。
    static let tagFilterFixtureClipIDs: [UUID] = [
        UUID(uuidString: "00000000-0000-4000-8000-000000000301")!,
        UUID(uuidString: "00000000-0000-4000-8000-000000000302")!,
        UUID(uuidString: "00000000-0000-4000-8000-000000000303")!,
        UUID(uuidString: "00000000-0000-4000-8000-000000000304")!
    ]

    /// 标签筛选夹具使用的 2 个用户标签稳定 UUID。
    static let tagFilterFixtureUserTagIDs: [UUID] = [
        UUID(uuidString: "00000000-0000-4000-8000-000000000311")!,
        UUID(uuidString: "00000000-0000-4000-8000-000000000312")!
    ]

    /// 标签筛选夹具：4 条固定 ClipItem，覆盖搜索、来源和标签交集场景。
    ///
    /// | 索引 | resultId | 内容 | 来源 | 标签 |
    /// |------|----------|------|------|------|
    /// | 0 | tag-result-1 | 含"需求" | Pages | REQ、重要、待处理 |
    /// | 1 | tag-result-2 | 含"需求" | Pages | REQ、重要 |
    /// | 2 | tag-result-3 | 含"需求" | Xcode | CODE、重要、待处理 |
    /// | 3 | tag-result-4 | 不含查询 | Pages | REQ、重要、待处理 |
    static let tagFilterFixtureClips: [ClipItem] = [
        makeTagFilterClip(
            id: tagFilterFixtureClipIDs[0],
            text: "需求分析文档：用户登录流程",
            contentType: .requirement,
            sourceApp: "com.apple.Pages",
            sourceAppName: "Pages"
        ),
        makeTagFilterClip(
            id: tagFilterFixtureClipIDs[1],
            text: "需求评审记录：性能指标",
            contentType: .requirement,
            sourceApp: "com.apple.Pages",
            sourceAppName: "Pages"
        ),
        makeTagFilterClip(
            id: tagFilterFixtureClipIDs[2],
            text: "需求代码实现：Swift 版本",
            contentType: .code,
            sourceApp: "com.apple.Xcode",
            sourceAppName: "Xcode"
        ),
        makeTagFilterClip(
            id: tagFilterFixtureClipIDs[3],
            text: "设计文档：系统架构",
            contentType: .requirement,
            sourceApp: "com.apple.Pages",
            sourceAppName: "Pages"
        )
    ]

    /// 当前 UI 测试模式激活的夹具数据。
    ///
    /// `--UITEST_TAG_FILTER_FIXTURE` 优先返回标签筛选夹具；
    /// 否则返回 `previewClips`（11 种 ContentType 预览数据）。
    static var activeFixtureClips: [ClipItem]
    {
        if CommandLine.arguments.contains(tagFilterFixtureArg)
        {
            return tagFilterFixtureClips
        }
        return previewClips
    }

    /// 创建标签筛选夹具 ClipItem（带稳定 UUID 和 `tagState: .newItem`）。
    private static func makeTagFilterClip(
        id: UUID,
        text: String,
        contentType: ContentType,
        sourceApp: String,
        sourceAppName: String
    ) -> ClipItem {
        ClipItem(
            id: id,
            content: .text(text),
            contentType: contentType,
            sourceApp: sourceApp,
            sourceAppName: sourceAppName,
            timestamp: Date(),
            summary: nil,
            translation: nil,
            rewrite: nil,
            todos: nil,
            embeddings: nil,
            tagState: .newItem(contentType: contentType)
        )
    }

    /// 判断当前是否为 UI 测试模式
    static var isUITesting: Bool {
        CommandLine.arguments.contains("--UITEST_PREVIEW_DATA")
    }
}
