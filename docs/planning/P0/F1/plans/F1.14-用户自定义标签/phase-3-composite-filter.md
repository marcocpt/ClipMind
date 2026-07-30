# Phase 3：主窗口组合筛选

> 最后更新：2026-07-30 | 版本：v1.1

**目标：** 由一个业务类型统一解释搜索、来源与多标签交集，让历史列表和搜索结果使用相同
resultId 集合，并明确区分无数据与条件无匹配。

**IN：** Phase 0 的来源筛选基线、Phase 1 标签快照、Phase 2 主窗口标签显示。

**OUT：** FLT-001～006 和 REG-002 的 XCTest 通过，主窗口可选择全部系统/用户标签。

**范围：** AC-10、11、14、24。

**非目标：** 改变语义搜索排序、把标签筛选加入菜单栏弹窗/快捷粘贴面板、持久化筛选状态。

---

## 任务 1：完整筛选意图与纯业务解释器

**文件：**

- 创建：`ClipMind/UI/MainWindow/CompositeClipFilter.swift`
- 创建：`ClipMindTests/UI/CompositeClipFilterTests.swift`

- [x] **步骤 1：编写 RED 测试**

固定 6 条 ClipItem，覆盖：

- 查询为空 + 全部来源 + 无标签返回全部；
- 搜索词只匹配文本内容；
- 搜索 + 单来源 + 单标签使用 AND；
- 两标签只返回同时含两者的条目；
- 选择当前条目没有的系统标签返回空；
- 清除标签后搜索和来源不变；
- 历史入口与搜索入口传相同 intent 时 resultId 集合相同。

- [x] **步骤 2：实现筛选值类型**

```swift
import Foundation

struct ClipFilterIntent: Equatable
{
    var query: String
    var selectedSourceApps: Set<String>
    var allSourceApps: Set<String>
    var selectedTagIDs: Set<ClipTagID>

    var isSourceFilterActive: Bool
    {
        selectedSourceApps != allSourceApps
    }

    var isTagFilterActive: Bool
    {
        !selectedTagIDs.isEmpty
    }

    var hasAnyCondition: Bool
    {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || isSourceFilterActive
            || isTagFilterActive
    }
}

enum CompositeClipFilter
{
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
}
```

同文件完整实现：

```swift
private static func matchesQuery(_ clip: ClipItem, query: String) -> Bool
{
    guard !query.isEmpty else { return true }
    guard case .text(let text) = clip.content else { return false }
    return text.localizedCaseInsensitiveContains(query)
}

private static func matchesSource(_ clip: ClipItem, intent: ClipFilterIntent) -> Bool
{
    guard intent.isSourceFilterActive else { return true }
    return intent.selectedSourceApps.contains(clip.sourceAppName)
}

private static func matchesTags(
    _ clip: ClipItem,
    selectedTagIDs: Set<ClipTagID>,
    snapshot: TagSnapshot
) -> Bool
{
    guard !selectedTagIDs.isEmpty else { return true }
    let clipTagIDs = Set(snapshot.tagStatesByClipID[clip.id, default: clip.tagState].orderedTagIDs)
    return selectedTagIDs.isSubset(of: clipTagIDs)
}
```

不读取 View、不查询数据库、不改变输入顺序；搜索结果因此保留原相关度顺序。

- [x] **步骤 3：运行 GREEN**

运行 `ClipMindTests/CompositeClipFilterTests`。预期：全部 PASS。

## 任务 2：标签筛选多选 UI

**文件：**

- 创建：`ClipMind/UI/Tags/TagFilterView.swift`
- 扩充：`ClipMindTests/UI/CompositeClipFilterTests.swift`

- [x] **步骤 1：定义选择状态**

```swift
struct TagFilterSelection: Equatable
{
    var selectedTagIDs: Set<ClipTagID> = []

    mutating func toggle(_ tagID: ClipTagID)
    {
        if selectedTagIDs.contains(tagID)
        {
            selectedTagIDs.remove(tagID)
        }
        else
        {
            selectedTagIDs.insert(tagID)
        }
    }

    mutating func clear()
    {
        selectedTagIDs.removeAll()
    }
}
```

测试初始空、toggle、clear，不使用 UserDefaults。

- [x] **步骤 2：实现 `TagFilterView`**

`TagFilterView` 接收 `@Binding TagFilterSelection` 与 `TagSnapshot`：

- label 为“标签：全部”或“标签：N 个”；
- popover 候选使用 `snapshot.allTags`，因此包含 11 个系统标签和全部用户标签；
- 每项 identifier 为 `tagFilterOption_<tagID>`；
- 活动 chip identifier 为 `activeTagFilter_<tagID>`，带可聚焦关闭按钮；
- “清除标签筛选”只调用 `selection.clear()`；
- 系统标签显示“自动分类”，但不因全局只读而禁用筛选。

选择项使用 `aria` 等价的 SwiftUI accessibility value“已选择/未选择”，不使用颜色作为唯一状态。

- [x] **步骤 3：运行 GREEN**

运行 `CompositeClipFilterTests` 的选择状态测试。预期：全部 PASS。

## 任务 3：主窗口只计算一次结果

**文件：**

- 修改：`ClipMind/UI/MainWindow/MainWindow.swift`
- 修改：`ClipMind/UI/MainWindow/HistoryListView.swift`
- 修改：`ClipMind/UI/MainWindow/SearchResultsView.swift`
- 修改：`ClipMindTests/UI/MainWindowLayoutTests.swift`

- [x] **步骤 1：编写 RED 结果状态测试**

为纯状态函数断言：

- 原始 `allClips` 为空 → `.noHistory`；
- 原始非空、完整 intent 结果为空 → `.noMatches`；
- 结果非空 → `.results`；
- 清除标签后 query/source 值未改变；
- search/historical UI 使用同一 `filteredClips`。
- 仅修改 `searchText` 不改变结果；调用 `performSearch` 提交后才更新 `committedQuery`。

- [x] **步骤 2：收敛 `MainWindow` 状态**

新增：

```swift
@State private var tagFilterSelection = TagFilterSelection()
@State private var committedQuery = ""

private var filterIntent: ClipFilterIntent
{
    ClipFilterIntent(
        query: committedQuery,
        selectedSourceApps: sourceFilterSelection.selectedSources,
        allSourceApps: Set(sourceApps),
        selectedTagIDs: tagFilterSelection.selectedTagIDs
    )
}

private var filteredClips: [ClipItem]
{
    CompositeClipFilter.filter(
        allClips,
        intent: filterIntent,
        snapshot: tagStore.snapshot
    )
}
```

`searchPanel` 在现有 `SearchBar`、`SourceFilter` 后加入 `TagFilterView`。
删除 `searchResults`、`filteredSearchResults` 两套二次过滤状态；
`performSearch(_:)` 仍只由 `SearchBar.onCommit` 调用，trim 后写入 `committedQuery`；
`isSearching` 由 `committedQuery` 是否为空推导。输入但未提交的新 `searchText` 不改变结果，
因此未选标签时保留现有“提交后搜索”语义。来源/标签变化可以基于同一个 committed query
即时重算，但不能隐式提交正在输入的文字。

- [x] **步骤 3：让两个列表消费已过滤结果**

`HistoryListView` 改为：

```swift
struct HistoryListView: View
{
    @Binding var selectedClip: ClipItem?
    let allClips: [ClipItem]
    let filteredClips: [ClipItem]
    let tagStore: TagStore
}
```

它不再创建自己的 `ClipStore`。`allClips.isEmpty` 显示 `historyEmptyState`；
`filteredClips.isEmpty` 显示 `historyFilterEmptyState`，文案为“没有符合当前条件的剪贴项”。

`SearchResultsView` 接收相同 `filteredClips`；空态 identifier 使用 `searchFilterEmptyState`，
文案同样指出条件无匹配，不改为无历史。

- [x] **步骤 4：验证来源更新不清空有效交集**

`sourceApps` 变化时，新的 `SourceFilterSelection` 保留仍存在的已选来源；
只移除已不存在的来源。标签选择保持原值；已删除标签由 Phase 4 的 TagStore snapshot 更新时移除。

- [x] **步骤 5：运行 GREEN 和来源回归**

运行：

```text
ClipMindTests/CompositeClipFilterTests
ClipMindTests/MainWindowLayoutTests
ClipMindTests/SourceFilterTests
ClipMindTests/SearchServiceTests
```

预期：全部 PASS。

## 任务 4：UI-test 标签筛选夹具

**文件：**

- 修改：`ClipMind/Utils/ClipTestData.swift`
- 修改：`ClipMind/App/AppDelegate+UITestOverrides.swift`

- [x] **步骤 1：增加固定夹具**

`--UITEST_TAG_FIXTURE` 必须生成稳定的：

| resultId | 内容 | 来源 | 标签 |
|----------|------|------|------|
| `tag-result-1` | 含“需求” | Pages | REQ、重要、待处理 |
| `tag-result-2` | 含“需求” | Pages | REQ、重要 |
| `tag-result-3` | 含“需求” | Xcode | CODE、重要、待处理 |
| `tag-result-4` | 不含查询 | Pages | REQ、重要、待处理 |

UUID 使用固定合法 UUID 常量；不得从 Swift `hashValue` 派生。
Tag catalog 中存在“重要”“待处理”，颜色固定。

- [x] **步骤 2：暴露真实 resultId**

每个主窗口 row 的 `.accessibilityValue` 为 `clip.id.uuidString`；
测试读取实际显示集合，不读取 `CompositeClipFilter` 内部状态。

- [x] **步骤 3：提交组合筛选**

```bash
git add \
  ClipMind/UI/MainWindow \
  ClipMind/UI/Tags/TagFilterView.swift \
  ClipMind/Utils/ClipTestData.swift \
  ClipMind/App/AppDelegate+UITestOverrides.swift \
  ClipMindTests/UI/CompositeClipFilterTests.swift \
  ClipMindTests/UI/MainWindowLayoutTests.swift
git commit -m "feat(tags): add composite tag filtering"
```

## 任务 5：同步标签筛选 UI Smoke

**文件：**

- 创建：`ClipMindUITests/TagFilterUITests.swift`
- 修改：`.github/workflows/tag-ui-smoke.yml`

- [x] **步骤 1：编写 FLT-002～006 当前能力测试**

使用任务 4 的固定 resultId，通过真实主窗口搜索框、来源筛选和标签筛选执行：

1. 搜索“需求” + Pages + “重要”得到两个 resultId；
2. 再选“待处理”只剩一个；
3. 选择无匹配系统标签显示筛选空态；
4. 移除该标签恢复前一集合；
5. 清除标签不改变搜索和来源 chip；
6. 空数据库显示历史空态，不显示筛选空态。

- [x] **步骤 2：把测试加入 Smoke**

workflow 新增 `TagFilterUITests` 选择器并绑定当前提交 SHA。运行成功后才允许 Phase 3 Gate
通过；Phase 5 只扩充跨容器一致性与失败探针，不回补本 Phase 已有能力。

- [x] **步骤 3：提交筛选 Smoke**

```bash
git add \
  .github/workflows/tag-ui-smoke.yml \
  ClipMindUITests/TagFilterUITests.swift
git commit -m "test(tags): add tag filter UI smoke"
```

## Phase 3 Local Gate

- FLT-001、FLT-005、REG-002 XCTest 通过。
- 历史和搜索结果只有一个 `CompositeClipFilter` 调用路径。
- 多标签是集合子集判断，不是 OR。
- 清除标签不修改搜索文本或来源集合。
- 系统标签完整出现在筛选候选。
- 两类空状态由原始数据是否为空判定。
- SwiftLint strict 0 violation，无签名 build succeeded。
- 当前 SHA 的 `TagFilterUITests` 远程 Smoke 成功。

## 版本记录

| 版本 | 日期 | 变更说明 |
|------|------|---------|
| v1.0 | 2026-07-29 | 固定完整筛选意图、多标签交集、主窗口单一结果和 UI-test resultId 夹具。 |
| v1.1 | 2026-07-30 | 同步状态：17 个步骤已全部完成并勾选；Phase 3 主体由 `af4655c` 提交，UI Smoke 由 `07dc7ca` 提交，后续 11 个 `fix(tags):` 修复 TagFilterUITests 稳定性，最新 `60289a5` 的 F1.14 Tag UI Smoke 与主 CI 全绿。 |
