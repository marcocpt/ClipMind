import Foundation

/// 完整筛选意图。
///
/// 把搜索词、来源过滤和标签过滤收敛为一个值类型，由 `CompositeClipFilter` 统一解释。
/// 历史列表和搜索结果传相同 intent 时得到相同 resultId 集合。
struct ClipFilterIntent: Equatable
{
    /// 搜索查询词（未 trim，由 filter 内部 trim）。
    var query: String

    /// 当前选中的来源应用名称集合。
    var selectedSourceApps: Set<String>

    /// 全部可用来源应用名称集合。
    var allSourceApps: Set<String>

    /// 当前选中的标签 ID 集合（AND 交集）。
    var selectedTagIDs: Set<ClipTagID>

    /// 来源筛选是否激活（未选全部）。
    var isSourceFilterActive: Bool
    {
        selectedSourceApps != allSourceApps
    }

    /// 标签筛选是否激活（至少选了一个标签）。
    var isTagFilterActive: Bool
    {
        !selectedTagIDs.isEmpty
    }

    /// 是否有任何筛选条件。
    var hasAnyCondition: Bool
    {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || isSourceFilterActive
            || isTagFilterActive
    }
}

/// 列表空状态。
///
/// 由原始数据是否为空和筛选结果是否为空共同决定，区分「无历史」与「条件无匹配」。
enum ClipListState: Equatable
{
    /// 原始数据为空：从未复制过任何内容。
    case noHistory

    /// 原始数据非空但筛选结果为空：当前条件无匹配。
    case noMatches

    /// 筛选结果非空。
    case results

    /// 由原始数据和筛选结果解析列表状态。
    /// - Parameters:
    ///   - allClips: 原始全部 ClipItem（未经筛选）。
    ///   - filteredClips: 经 `CompositeClipFilter.filter` 筛选后的结果。
    /// - Returns: 列表空状态。
    static func resolve(allClips: [ClipItem], filteredClips: [ClipItem]) -> ClipListState
    {
        if allClips.isEmpty { return .noHistory }
        if filteredClips.isEmpty { return .noMatches }
        return .results
    }
}

/// 纯业务筛选解释器。
///
/// 不读取 View、不查询数据库、不改变输入顺序；搜索结果因此保留原相关度顺序。
/// 三个条件（查询、来源、标签）使用 AND 组合；多标签是集合子集判断（同时满足）。
enum CompositeClipFilter
{
    /// 按 intent 过滤 clips，返回满足全部条件的子集。
    /// - Parameters:
    ///   - clips: 原始 ClipItem 数组，顺序保持不变。
    ///   - intent: 完整筛选意图。
    ///   - snapshot: 当前标签快照，用于查询条目关联的标签。
    /// - Returns: 满足全部条件的 ClipItem 数组，保持输入顺序。
    static func filter(
        _ clips: [ClipItem],
        intent: ClipFilterIntent,
        snapshot: TagSnapshot
    ) -> [ClipItem]
    {
        let query = intent.query.trimmingCharacters(in: .whitespacesAndNewlines)

        return clips.filter
        { clip in
            matchesQuery(clip, query: query)
                && matchesSource(clip, intent: intent)
                && matchesTags(clip, selectedTagIDs: intent.selectedTagIDs, snapshot: snapshot)
        }
    }

    /// 文本内容大小写不敏感包含匹配。非文本类型不匹配。
    private static func matchesQuery(_ clip: ClipItem, query: String) -> Bool
    {
        guard !query.isEmpty else { return true }
        guard case .text(let text) = clip.content else { return false }
        return text.localizedCaseInsensitiveContains(query)
    }

    /// 来源筛选：未激活时返回全部，激活时只返回选中来源的条目。
    private static func matchesSource(_ clip: ClipItem, intent: ClipFilterIntent) -> Bool
    {
        guard intent.isSourceFilterActive else { return true }
        return intent.selectedSourceApps.contains(clip.sourceAppName)
    }

    /// 标签筛选：无选中标签时返回全部；有选中标签时要求条目包含全部选中标签（子集判断）。
    /// 若条目 ID 不在快照中，回退到条目自身的 `tagState`。
    private static func matchesTags(
        _ clip: ClipItem,
        selectedTagIDs: Set<ClipTagID>,
        snapshot: TagSnapshot
    ) -> Bool
    {
        guard !selectedTagIDs.isEmpty else { return true }
        let clipTagIDs = Set(
            snapshot.tagStatesByClipID[clip.id, default: clip.tagState].orderedTagIDs
        )
        return selectedTagIDs.isSubset(of: clipTagIDs)
    }
}
