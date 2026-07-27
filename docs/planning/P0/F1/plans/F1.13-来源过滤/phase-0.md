# Phase 0：SourceFilter 多选改造 + 主窗口历史列表过滤

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 将主窗口来源过滤器从单选 Picker 改为多选 Checkbox，让历史列表和搜索结果均受来源过滤影响，来源应用列表从数据动态提取，过滤后无匹配结果显示空状态提示，主窗口过滤状态不持久化。

**范围：** AC-F1.13-1（多选 Checkbox）、AC-F1.13-2（历史列表过滤）、AC-F1.13-3（搜索结果过滤）、AC-F1.13-6（来源应用列表动态提取）、AC-F1.13-7（主窗口空状态提示）、AC-F1.13-8（状态独立，单元测试层面）、AC-F1.13-9（不持久化）

**非目标：** 弹窗筛选按钮和浮层（Phase 1）、XCUITest UI 自动化测试（Phase 2）、VoiceOver 可访问性验证（手动）

---

## 涉及文件和职责

| 文件 | 职责 | 操作 |
|------|------|------|
| `ClipMind/Utils/SourceAppExtractor.swift` | 来源应用列表动态提取（去重、排序） | 新增 |
| `ClipMind/UI/MainWindow/SourceFilter.swift` | 多选 Checkbox 来源过滤器 | 修改 |
| `ClipMind/UI/MainWindow/MainWindow.swift` | 适配集合过滤、传递过滤参数给历史列表和搜索 | 修改 |
| `ClipMind/UI/MainWindow/HistoryListView.swift` | 接收过滤参数、过滤剪贴项、空状态提示 | 修改 |
| `ClipMind/UI/MainWindow/SearchResultsView.swift` | 区分「搜索无结果」与「来源过滤无匹配」空状态 | 修改 |
| `ClipMind/Search/SearchService.swift` | sourceApp 单值参数改为集合参数 | 修改 |
| `ClipMind/Utils/ClipTestData.swift` | 新增 `previewSourceAppNames` 提供来源应用名称列表 | 修改 |
| `ClipMindTests/SourceFilter/SourceAppExtractorTests.swift` | 来源应用列表提取单元测试 | 新增 |
| `ClipMindTests/SourceFilter/SourceFilterViewModelTests.swift` | 多选 Checkbox 联动逻辑单元测试 | 新增 |
| `ClipMindTests/SourceFilter/SearchServiceMultiSelectAdapterTests.swift` | 搜索服务集合过滤适配单元测试 | 新增 |
| `ClipMindTests/SourceFilter/SourceFilterStateIndependenceTests.swift` | 过滤状态独立性单元测试 | 新增 |
| `ClipMindTests/SearchTests/SourceFilterTests.swift` | 适配 sourceApps 集合参数 | 修改 |

---

## 任务 1：SourceAppExtractor 来源应用列表提取工具

**文件：**
- 创建：`ClipMind/Utils/SourceAppExtractor.swift`
- 测试：`ClipMindTests/SourceFilter/SourceAppExtractorTests.swift`

- [ ] **步骤 1：编写失败的测试 — SourceAppExtractorTests**

创建测试文件 `ClipMindTests/SourceFilter/SourceAppExtractorTests.swift`：

```swift
@testable import ClipMind
import XCTest

final class SourceAppExtractorTests: XCTestCase
{
    // MARK: - 从剪贴项列表提取来源应用名称

    func testExtractFromClips_returnsSortedUniqueSourceAppNames()
    {
        let clips = [
            makeClip(sourceAppName: "Safari"),
            makeClip(sourceAppName: "Xcode"),
            makeClip(sourceAppName: "Notes"),
            makeClip(sourceAppName: "Safari") // 重复
        ]
        let result = SourceAppExtractor.extract(from: clips)
        XCTAssertEqual(result, ["Notes", "Safari", "Xcode"])
    }

    func testExtractFromClips_emptyList_returnsEmpty()
    {
        let result = SourceAppExtractor.extract(from: [])
        XCTAssertEqual(result, [])
    }

    func testExtractFromClips_singleSource_returnsSingleName()
    {
        let clips = [makeClip(sourceAppName: "Xcode")]
        let result = SourceAppExtractor.extract(from: clips)
        XCTAssertEqual(result, ["Xcode"])
    }

    func testExtractFromClips_ignoresEmptySourceAppName()
    {
        let clips = [
            makeClip(sourceAppName: "Safari"),
            makeClip(sourceAppName: ""),
            makeClip(sourceAppName: "Xcode")
        ]
        let result = SourceAppExtractor.extract(from: clips)
        XCTAssertEqual(result, ["Safari", "Xcode"])
    }

    func testExtractFromClips_preservesChineseCharacters()
    {
        let clips = [
            makeClip(sourceAppName: "备忘录"),
            makeClip(sourceAppName: "Safari")
        ]
        let result = SourceAppExtractor.extract(from: clips)
        // 中文字符排序按 Unicode 顺序
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.contains("备忘录"))
        XCTAssertTrue(result.contains("Safari"))
    }

    // MARK: - Helper

    private func makeClip(sourceAppName: String) -> ClipItem
    {
        ClipItem(
            id: UUID(),
            content: .text("test"),
            contentType: .other,
            sourceApp: "com.test.\(sourceAppName)",
            sourceAppName: sourceAppName,
            timestamp: Date(),
            summary: nil,
            translation: nil,
            rewrite: nil,
            todos: nil,
            embeddings: nil
        )
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：
```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:ClipMindTests/SourceAppExtractorTests
```
预期：FAIL，报错 `Cannot find 'SourceAppExtractor' in scope`

- [ ] **步骤 3：编写 SourceAppExtractor 实现**

创建文件 `ClipMind/Utils/SourceAppExtractor.swift`：

```swift
import Foundation

/// 来源应用列表提取工具。
///
/// 从剪贴项列表中动态提取来源应用名称，去重并按名称排序。
/// 供主窗口来源过滤器和弹窗来源筛选浮层共享使用。
enum SourceAppExtractor
{
    /// 从剪贴项列表中提取去重排序的来源应用名称列表。
    ///
    /// - Parameter clips: 剪贴项列表
    /// - Returns: 去重、按名称排序的来源应用名称数组
    static func extract(from clips: [ClipItem]) -> [String]
    {
        let names = Set(clips.map(\.sourceAppName).filter { !$0.isEmpty })
        return names.sorted()
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：
```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:ClipMindTests/SourceAppExtractorTests
```
预期：PASS，5 个测试全绿

- [ ] **步骤 5：Commit**

```bash
git add ClipMind/Utils/SourceAppExtractor.swift ClipMindTests/SourceFilter/SourceAppExtractorTests.swift
git commit -m "feat(source-filter): add SourceAppExtractor for dynamic source list extraction"
```

---

## 任务 2：SourceFilter 多选 Checkbox 联动逻辑测试

**文件：**
- 创建：`ClipMindTests/SourceFilter/SourceFilterViewModelTests.swift`

- [ ] **步骤 1：编写失败的测试 — Checkbox 联动逻辑**

创建测试文件 `ClipMindTests/SourceFilter/SourceFilterViewModelTests.swift`：

```swift
@testable import ClipMind
import XCTest

/// 来源过滤器多选 Checkbox 联动逻辑测试。
///
/// 验证「全部」选项与各应用 Checkbox 的互斥/联动行为。
final class SourceFilterViewModelTests: XCTestCase
{
    // MARK: - toggleSource 联动逻辑

    func testInitialState_allSelected()
    {
        let sources = Set(["Safari", "Xcode", "Notes"])
        let selected = SourceFilterSelection(allApps: sources)
        XCTAssertTrue(selected.isAllSelected)
        XCTAssertEqual(selected.selectedSources, sources)
    }

    func testToggleSingleApp_whenAllSelected_deselectsAll()
    {
        let sources = Set(["Safari", "Xcode", "Notes"])
        var selected = SourceFilterSelection(allApps: sources)
        // 选中 Safari（全部已选中，此时 toggle 表示只保留 Safari）
        selected.toggleSource("Safari")
        XCTAssertFalse(selected.isAllSelected)
        XCTAssertEqual(selected.selectedSources, ["Safari"])
    }

    func testToggleAll_selectsAllApps()
    {
        let sources = Set(["Safari", "Xcode", "Notes"])
        var selected = SourceFilterSelection(allApps: sources)
        // 先取消部分
        selected.toggleSource("Safari")
        // 此时 selectedSources 不含 Safari
        // 再点「全部」
        selected.toggleAll()
        XCTAssertTrue(selected.isAllSelected)
        XCTAssertEqual(selected.selectedSources, sources)
    }

    func testSelectAllAppsIndividually_autoSelectsAll()
    {
        let sources = Set(["Safari", "Xcode"])
        var selected = SourceFilterSelection(allApps: sources)
        // 取消全部
        selected.toggleAll()
        // 手动逐个选中
        selected.toggleSource("Safari")
        selected.toggleSource("Xcode")
        XCTAssertTrue(selected.isAllSelected)
    }

    func testDeselectOneApp_afterAllSelected_deselectsAll()
    {
        let sources = Set(["Safari", "Xcode", "Notes"])
        var selected = SourceFilterSelection(allApps: sources)
        XCTAssertTrue(selected.isAllSelected)
        // 取消一个
        selected.deselectSource("Safari")
        XCTAssertFalse(selected.isAllSelected)
        XCTAssertEqual(selected.selectedSources, ["Xcode", "Notes"])
    }

    func testEmptySources_isAllSelected_returnsTrue()
    {
        let selected = SourceFilterSelection(allApps: [])
        XCTAssertTrue(selected.isAllSelected)
        XCTAssertEqual(selected.selectedSources, [] as Set<String>)
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：
```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:ClipMindTests/SourceFilterViewModelTests
```
预期：FAIL，报错 `Cannot find 'SourceFilterSelection' in scope`

- [ ] **步骤 3：编写 SourceFilterSelection 实现**

创建文件 `ClipMind/Utils/SourceFilterSelection.swift`：

```swift
import Foundation

/// 来源过滤选中状态管理。
///
/// 管理「全部」选项与各应用 Checkbox 的联动逻辑：
/// - 初始状态为「全部」选中（所有来源均通过过滤）。
/// - 取消勾选「全部」后，按各应用 Checkbox 选中状态过滤。
/// - 手动选中所有应用时，自动选中「全部」。
/// - 选中某个应用且「全部」之前选中时，仅保留该应用（取消其余）。
///
/// 此状态为值类型，主窗口和弹窗各自持有独立实例，互不影响。
struct SourceFilterSelection
{
    /// 所有可用的来源应用名称集合。
    let allApps: Set<String>

    /// 当前选中的来源应用名称集合。
    /// 初始等于 allApps（即「全部」选中）。
    var selectedSources: Set<String>

    /// 是否处于「全部」选中状态（选中来源集合等于所有来源集合）。
    var isAllSelected: Bool
    {
        selectedSources == allApps
    }

    /// 初始化，默认「全部」选中。
    init(allApps: Set<String>)
    {
        self.allApps = allApps
        self.selectedSources = allApps
    }

    /// 切换「全部」选项。
    ///
    /// 无论当前状态，选中所有来源（等同于重置为「全部」）。
    mutating func toggleAll()
    {
        selectedSources = allApps
    }

    /// 切换某个来源应用的选中状态。
    ///
    /// 联动逻辑：
    /// - 如果「全部」当前选中，toggle 该应用表示只保留该应用（取消其余）。
    /// - 如果「全部」未选中，toggle 该应用表示切换该应用的勾选状态。
    /// - 切换后如果所有应用均选中，自动选中「全部」。
    mutating func toggleSource(_ app: String)
    {
        if isAllSelected
        {
            // 当前全部选中 → 只保留此应用
            selectedSources = [app]
        }
        else
        {
            if selectedSources.contains(app)
            {
                selectedSources.remove(app)
            }
            else
            {
                selectedSources.insert(app)
            }
            // 全部选中时自动选中「全部」
            if selectedSources == allApps
            {
                // isAllSelected 自然为 true
            }
        }
    }

    /// 取消选中某个来源应用。
    ///
    /// 从当前选中集合中移除指定应用，不触发「只保留」逻辑。
    mutating func deselectSource(_ app: String)
    {
        selectedSources.remove(app)
    }

    /// 重置为「全部」选中（等同于初始状态）。
    mutating func resetToAll()
    {
        selectedSources = allApps
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

运行：
```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:ClipMindTests/SourceFilterViewModelTests
```
预期：PASS，6 个测试全绿

- [ ] **步骤 5：Commit**

```bash
git add ClipMind/Utils/SourceFilterSelection.swift ClipMindTests/SourceFilter/SourceFilterViewModelTests.swift
git commit -m "feat(source-filter): add SourceFilterSelection for multi-select checkbox logic"
```

---

## 任务 3：SourceFilter 视图从单选 Picker 改为多选 Checkbox

**文件：**
- 修改：`ClipMind/UI/MainWindow/SourceFilter.swift`

- [ ] **步骤 1：重写 SourceFilter 为多选 Checkbox**

将 `ClipMind/UI/MainWindow/SourceFilter.swift` 的内容替换为：

```swift
import SwiftUI

/// 来源 App 多选筛选器。
///
/// 提供 Checkbox 列表选择来源 App，支持"全部"和具体 App 选项。
/// 「全部」选项与各应用 Checkbox 联动：
/// - 选中「全部」时所有来源均通过过滤。
/// - 取消勾选「全部」后按各应用 Checkbox 选中状态过滤。
/// - 手动选中所有应用时自动选中「全部」。
struct SourceFilter: View
{
    @Binding var selection: SourceFilterSelection
    let availableApps: [String]

    var body: some View
    {
        Menu
        {
            Button(action: { selection.toggleAll() })
            {
                HStack
                {
                    if selection.isAllSelected
                    {
                        Image(systemName: "checkmark")
                    }
                    Text("全部来源")
                }
            }

            Divider()

            ForEach(availableApps, id: \.self) { app in
                Button(action: { selection.toggleSource(app) })
                {
                    HStack
                    {
                        if selection.selectedSources.contains(app)
                        {
                            Image(systemName: "checkmark")
                        }
                        Text(app)
                    }
                }
            }
        } label: {
            HStack(spacing: 4)
            {
                Image(systemName: "line.3.horizontal.decrease.circle")
                Text(selection.isAllSelected ? "全部来源" : "\(selection.selectedSources.count) 个来源")
            }
        }
        .accessibilityIdentifier("sourceFilterPicker")
    }
}
```

- [ ] **步骤 2：编译检查**

运行：
```bash
xcodebuild build \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```
预期：编译失败（MainWindow.swift 还在用旧的 `selectedApp: String?` 绑定），下一步修复

- [ ] **步骤 3：Commit（暂不运行，等任务 4 一起编译通过后 commit）**

此步骤跳过单独 commit，与任务 4 合并。

---

## 任务 4：MainWindow 适配集合过滤 + HistoryListView 过滤

**文件：**
- 修改：`ClipMind/UI/MainWindow/MainWindow.swift`
- 修改：`ClipMind/UI/MainWindow/HistoryListView.swift`
- 修改：`ClipMind/Utils/ClipTestData.swift`

- [ ] **步骤 1：修改 MainWindow 适配集合过滤**

修改 `ClipMind/UI/MainWindow/MainWindow.swift`，将 `@State private var selectedSourceApp: String?` 改为 `@State private var sourceFilterSelection: SourceFilterSelection`，更新相关逻辑：

关键变更点：
1. `@State private var selectedSourceApp: String?` → `@State private var sourceFilterSelection: SourceFilterSelection`
2. `allClips` 计算属性保持不变
3. 新增 `sourceApps` 计算属性，使用 `SourceAppExtractor.extract(from: allClips)` 动态提取
4. `searchPanel` 中 `SourceFilter` 调用适配新 API
5. `contentArea` 中 `HistoryListView` 传入过滤参数
6. `filteredSearchResults` 适配集合过滤

修改后的 `MainWindow.swift` 关键部分：

```swift
struct MainWindow: View
{
    @State private var selectedClip: ClipItem?
    @State private var searchText = ""
    @State private var searchResults: [ClipItem] = []
    @State private var isSearching = false
    @State private var sourceFilterSelection = SourceFilterSelection(allApps: [])
    @StateObject private var clipStore = ClipStore()

    private var allClips: [ClipItem] {
        ClipTestData.isUITesting ? ClipTestData.previewClips : clipStore.clips
    }

    private var sourceApps: [String]
    {
        SourceAppExtractor.extract(from: allClips)
    }

    var body: some View
    {
        NavigationView
        {
            VStack(spacing: 0)
            {
                searchPanel
                Divider()
                contentArea
            }
            .frame(minWidth: LayoutConstants.sidebarMinWidth)
            DetailPanel(clip: selectedClip) { updated in
                selectedClip = updated
            }
        }
        .toolbar
        {
            ToolbarItem(placement: .primaryAction)
            {
                Button(action: openSettings, label: {
                    Image(systemName: "gearshape")
                })
                .accessibilityIdentifier("settingsButton")
            }
        }
        .frame(minWidth: LayoutConstants.mainWindowMinWidth, minHeight: LayoutConstants.mainWindowMinHeight)
        .onAppear
        {
            // 每次打开窗口默认「全部」选中
            sourceFilterSelection = SourceFilterSelection(allApps: Set(sourceApps))
            if CommandLine.arguments.contains("--UITEST_AUTO_SELECT_FIRST")
            {
                selectedClip = allClips.first
            }
        }
        .onChange(of: sourceApps)
        { newApps in
            // 来源应用列表变化时，重建 selection 保持「全部」
            sourceFilterSelection = SourceFilterSelection(allApps: Set(newApps))
        }
    }

    private var searchPanel: some View
    {
        HStack(spacing: 12)
        {
            SearchBar(text: $searchText, onCommit: performSearch)
            SourceFilter(
                selection: $sourceFilterSelection,
                availableApps: sourceApps
            )
        }
        .padding(12)
    }

    @ViewBuilder
    private var contentArea: some View
    {
        if isSearching
        {
            SearchResultsView(results: filteredSearchResults) { clip in
                selectedClip = clip
            }
        }
        else
        {
            HistoryListView(
                selectedClip: $selectedClip,
                sourceFilter: sourceFilterSelection.selectedSources
            )
        }
    }

    /// 搜索结果按来源过滤集合过滤
    private var filteredSearchResults: [ClipItem]
    {
        if sourceFilterSelection.isAllSelected
        {
            return searchResults
        }
        return searchResults.filter { sourceFilterSelection.selectedSources.contains($0.sourceAppName) }
    }

    // performSearch 和 openSettings 方法保持不变
    // ...
}
```

- [ ] **步骤 2：修改 HistoryListView 接收过滤参数**

修改 `ClipMind/UI/MainWindow/HistoryListView.swift`，新增 `sourceFilter` 参数，在视图层过滤：

```swift
import SwiftUI

struct HistoryListView: View
{
    @Binding var selectedClip: ClipItem?
    let sourceFilter: Set<String>
    @StateObject private var clipStore = ClipStore()

    private var clips: [ClipItem]
    {
        ClipTestData.isUITesting ? ClipTestData.previewClips : clipStore.clips
    }

    /// 根据来源过滤条件过滤后的剪贴项
    private var filteredClips: [ClipItem]
    {
        if sourceFilter.isEmpty || sourceFilter == Set(clips.map(\.sourceAppName))
        {
            return clips
        }
        return clips.filter { sourceFilter.contains($0.sourceAppName) }
    }

    var body: some View
    {
        if clips.isEmpty
        {
            VStack(spacing: 8)
            {
                Image(systemName: "tray")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("暂无剪贴历史")
                    .font(.title3)
                    .foregroundColor(.secondary)
                Text("复制任何内容，它将自动出现在这里")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("historyEmptyState")
        }
        else if filteredClips.isEmpty
        {
            VStack(spacing: 8)
            {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("无匹配的剪贴项")
                    .font(.title3)
                    .foregroundColor(.secondary)
                Text("当前来源过滤条件下没有剪贴项")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier("historyFilterEmptyState")
        }
        else
        {
            List(filteredClips) { clip in
                ClipRowView(clip: clip, onSingleClick: { selectedClip = clip })
            }
            .accessibilityIdentifier("historyList")
        }
    }
}
```

- [ ] **步骤 3：编译检查**

运行：
```bash
xcodebuild build \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```
预期：编译成功（SourceFilter、MainWindow、HistoryListView 均已适配）

- [ ] **步骤 4：运行 Lint**

运行：
```bash
swiftlint lint --strict
```
预期：无错误（如有则修复后重新运行）

- [ ] **步骤 5：运行现有测试确保未回归**

运行：
```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:ClipMindTests
```
预期：全部通过（SourceFilterTests 可能需要适配，在任务 5 中处理）

- [ ] **步骤 6：Commit（与任务 3 合并）**

```bash
git add ClipMind/UI/MainWindow/SourceFilter.swift ClipMind/UI/MainWindow/MainWindow.swift ClipMind/UI/MainWindow/HistoryListView.swift
git commit -m "feat(source-filter): convert SourceFilter to multi-select checkbox with history list filtering"
```

---

## 任务 5：SearchService 适配集合来源过滤

**文件：**
- 修改：`ClipMind/Search/SearchService.swift`
- 修改：`ClipMindTests/SearchTests/SourceFilterTests.swift`
- 新增：`ClipMindTests/SourceFilter/SearchServiceMultiSelectAdapterTests.swift`

- [ ] **步骤 1：编写失败的测试 — SearchServiceMultiSelectAdapterTests**

创建 `ClipMindTests/SourceFilter/SearchServiceMultiSelectAdapterTests.swift`：

```swift
@testable import ClipMind
import XCTest

/// 搜索服务多选集合过滤适配测试。
///
/// 验证 SearchService 的 sourceApps 参数从单值改为集合后的过滤行为。
final class SearchServiceMultiSelectAdapterTests: XCTestCase
{
    private var dbPath: URL!
    private var store: EncryptedStore!
    private var embeddingService: LocalEmbeddingService!
    private var searchService: SearchService!

    private static let xcodeApp = "com.apple.xcode"
    private static let safariApp = "com.apple.Safari"
    private static let vscodeApp = "com.microsoft.vscode"

    override func setUpWithError() throws
    {
        dbPath = try TestDatabaseHelper.makeTempDBPath()
        store = try EncryptedStore(dbPath: dbPath, key: TestDatabaseHelper.makeTestKey())
        embeddingService = LocalEmbeddingService()
        searchService = SearchService(embeddingService: embeddingService, store: store)

        try saveItem(text: "Swift programming for iOS", sourceApp: Self.xcodeApp)
        try saveItem(text: "Python data analysis", sourceApp: Self.vscodeApp)
        try saveItem(text: "JavaScript web development", sourceApp: Self.xcodeApp)
        try saveItem(text: "CSS styling guide", sourceApp: Self.safariApp)
    }

    override func tearDownWithError() throws
    {
        searchService = nil
        embeddingService = nil
        store = nil
        if let dbPath
        {
            TestDatabaseHelper.cleanup(at: dbPath)
        }
        dbPath = nil
    }

    private func saveItem(text: String, sourceApp: String) throws
    {
        let embeddings = embeddingService.embed(text)?.map { Float($0) }
        let item = ClipItem(
            id: UUID(),
            content: .text(text),
            contentType: .article,
            sourceApp: sourceApp,
            sourceAppName: sourceApp,
            timestamp: Date(),
            summary: nil,
            translation: nil,
            rewrite: nil,
            todos: nil,
            embeddings: embeddings
        )
        try store.save(item)
    }

    // MARK: - 集合过滤

    func testSearchWithMultipleSourceApps_returnsFilteredResults() throws
    {
        let results = try searchService.search(
            query: "development",
            limit: 10,
            sourceApps: [Self.xcodeApp, Self.safariApp]
        )
        XCTAssertFalse(results.isEmpty)
        for item in results
        {
            XCTAssertTrue(
                [Self.xcodeApp, Self.safariApp].contains(item.sourceApp),
                "结果应来自 Xcode 或 Safari，实际：\(item.sourceApp)"
            )
        }
    }

    func testSearchWithSingleSourceAppInSet_returnsFilteredResults() throws
    {
        let results = try searchService.search(
            query: "programming",
            limit: 5,
            sourceApps: [Self.xcodeApp]
        )
        XCTAssertFalse(results.isEmpty)
        for item in results
        {
            XCTAssertEqual(item.sourceApp, Self.xcodeApp)
        }
    }

    func testSearchWithEmptySourceAppsSet_returnsAll() throws
    {
        let results = try searchService.search(
            query: "development",
            limit: 10,
            sourceApps: [] as Set<String>
        )
        XCTAssertGreaterThanOrEqual(results.count, 2)
    }

    func testSearchWithNilSourceApps_returnsAll() throws
    {
        let results = try searchService.search(
            query: "development",
            limit: 10,
            sourceApps: nil
        )
        XCTAssertGreaterThanOrEqual(results.count, 2)
    }

    func testSearchWithScores_multiSelectFilter() throws
    {
        let results = try searchService.searchWithScores(
            query: "development",
            limit: 10,
            sourceApps: [Self.xcodeApp, Self.safariApp]
        )
        XCTAssertFalse(results.isEmpty)
        for result in results
        {
            XCTAssertTrue(
                [Self.xcodeApp, Self.safariApp].contains(result.item.sourceApp)
            )
        }
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：
```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:ClipMindTests/SearchServiceMultiSelectAdapterTests
```
预期：FAIL，报错 `Extra argument 'sourceApps' in call`（SearchService 还没有 `sourceApps` 参数）

- [ ] **步骤 3：修改 SearchService 支持 sourceApps 集合参数**

修改 `ClipMind/Search/SearchService.swift`，将 `sourceApp: String?` 参数改为 `sourceApps: Set<String>?`，保持向后兼容（旧 `sourceApp` 参数标记 deprecated）：

```swift
import Foundation

/// 语义搜索服务。
///
/// 使用 LocalEmbeddingService 生成查询向量，通过 EncryptedStore 进行余弦相似度搜索。
/// 支持跨语言搜索和来源 App 多选过滤。
final class SearchService
{
    private let embeddingService: LocalEmbeddingService
    private let store: EncryptedStore

    init(embeddingService: LocalEmbeddingService, store: EncryptedStore)
    {
        self.embeddingService = embeddingService
        self.store = store
    }

    /// 语义搜索。
    /// - Parameters:
    ///   - query: 自然语言查询文本
    ///   - limit: 返回结果数量，默认 5
    ///   - sourceApps: 可选来源 App 过滤集合（bundle ID），nil 或空集合表示不过滤
    /// - Returns: 按相似度降序排列的 ClipItem 数组
    /// - Throws: EncryptedStore 读取错误
    func search(query: String, limit: Int = 5, sourceApps: Set<String>? = nil) throws -> [ClipItem]
    {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        guard let queryVector = embeddingService.embed(trimmed) else
        {
            LogCategory.search.warning("Failed to generate embedding for query")
            return []
        }

        let floatQuery = queryVector.map { Float($0) }
        let results = try store.search(query: floatQuery, limit: limit, sourceApp: nil)

        // 在内存中按 sourceApps 集合过滤
        let filtered: [ClipItem]
        if let sourceApps = sourceApps, !sourceApps.isEmpty
        {
            filtered = results.filter { sourceApps.contains($0.sourceApp) }
        }
        else
        {
            filtered = results
        }

        LogCategory.search.info("Search returned \(filtered.count) results after source filter")
        return filtered
    }

    /// 语义搜索（兼容旧的单选 sourceApp 参数）。
    @available(*, deprecated, message: "Use sourceApps: Set<String>? instead")
    func search(query: String, limit: Int = 5, sourceApp: String?) throws -> [ClipItem]
    {
        let sourceApps: Set<String>? = sourceApp.map { [$0] }
        return try search(query: query, limit: limit, sourceApps: sourceApps)
    }

    /// 搜索并返回带分数的结果。
    /// - Parameters:
    ///   - query: 自然语言查询文本
    ///   - limit: 返回结果数量，默认 5
    ///   - sourceApps: 可选来源 App 过滤集合（bundle ID），nil 或空集合表示不过滤
    /// - Returns: 按相似度降序排列的 (ClipItem, 分数) 数组
    /// - Throws: EncryptedStore 读取错误
    func searchWithScores(
        query: String,
        limit: Int = 5,
        sourceApps: Set<String>? = nil
    ) throws -> [(item: ClipItem, score: Double)]
    {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        guard let queryVector = embeddingService.embed(trimmed) else
        {
            LogCategory.search.warning("Failed to generate embedding for query")
            return []
        }

        let allItems = try store.loadAll()
        var filtered = allItems
        if let sourceApps = sourceApps, !sourceApps.isEmpty
        {
            filtered = allItems.filter { sourceApps.contains($0.sourceApp) }
        }

        var scored: [(item: ClipItem, score: Double)] = []
        for item in filtered
        {
            guard let itemEmbeddings = item.embeddings, !itemEmbeddings.isEmpty else { continue }
            let itemVector = itemEmbeddings.map { Double($0) }
            guard itemVector.count == queryVector.count else { continue }

            let score = LocalEmbeddingService.cosineSimilarity(queryVector, itemVector)
            scored.append((item: item, score: score))
        }

        let results = scored.sorted { $0.score > $1.score }.prefix(limit).map { $0 }
        LogCategory.search.info("Search returned \(results.count) results with scores")
        return Array(results)
    }

    /// 搜索并返回带分数的结果（兼容旧的单选 sourceApp 参数）。
    @available(*, deprecated, message: "Use sourceApps: Set<String>? instead")
    func searchWithScores(
        query: String,
        limit: Int = 5,
        sourceApp: String?
    ) throws -> [(item: ClipItem, score: Double)]
    {
        let sourceApps: Set<String>? = sourceApp.map { [$0] }
        return try searchWithScores(query: query, limit: limit, sourceApps: sourceApps)
    }
}
```

- [ ] **步骤 4：适配旧测试 SourceFilterTests**

修改 `ClipMindTests/SearchTests/SourceFilterTests.swift`，将 `sourceApp:` 参数改为 `sourceApps:`：

将所有 `sourceApp: Self.xcodeApp` 改为 `sourceApps: [Self.xcodeApp]`，将 `sourceApp: "com.nonexistent.app"` 改为 `sourceApps: ["com.nonexistent.app"]`，将无 sourceApp 参数的调用保持不变（默认 nil）。

具体修改：
- `testSearchWithMatchingSourceAppReturnsFilteredResults`: `sourceApps: [Self.xcodeApp]`
- `testSearchWithNonMatchingSourceAppReturnsEmpty`: `sourceApps: ["com.nonexistent.app"]`
- `testSearchWithScoresRespectsSourceAppFilter`: `sourceApps: [Self.xcodeApp]`

- [ ] **步骤 5：运行测试验证通过**

运行：
```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:ClipMindTests/SearchServiceMultiSelectAdapterTests \
  -only-testing:ClipMindTests/SourceFilterTests
```
预期：PASS

- [ ] **步骤 6：运行 Lint**

运行：
```bash
swiftlint lint --strict
```
预期：无错误

- [ ] **步骤 7：Commit**

```bash
git add ClipMind/Search/SearchService.swift ClipMindTests/SearchTests/SourceFilterTests.swift ClipMindTests/SourceFilter/SearchServiceMultiSelectAdapterTests.swift
git commit -m "feat(source-filter): adapt SearchService to support Set<String> source filtering"
```

---

## 任务 6：SearchResultsView 空状态提示区分

**文件：**
- 修改：`ClipMind/UI/MainWindow/SearchResultsView.swift`

- [ ] **步骤 1：修改 SearchResultsView 增加来源过滤空状态提示**

修改 `ClipMind/UI/MainWindow/SearchResultsView.swift`，增加 `isSourceFilterActive` 参数区分空状态：

```swift
import SwiftUI

/// 搜索结果列表。
///
/// 显示搜索查询返回的 ClipItem 列表，每项包含类型标签、内容预览、来源和时间。
/// 对应 UI-AC-06 搜索交互：结果列表按相关度排序。
/// F1.13：支持来源过滤后无匹配结果的空状态提示。
struct SearchResultsView: View
{
    let results: [ClipItem]
    let onSelect: (ClipItem) -> Void
    /// 来源过滤是否生效（非「全部」）
    var isSourceFilterActive: Bool = false

    var body: some View
    {
        if results.isEmpty
        {
            VStack(spacing: 8)
            {
                Image(systemName: isSourceFilterActive ? "line.3.horizontal.decrease.circle" : "magnifyingglass")
                    .font(.system(size: 36))
                    .foregroundColor(.secondary)
                Text(isSourceFilterActive ? "无匹配的剪贴项" : "未找到匹配内容")
                    .font(.title3)
                    .foregroundColor(.secondary)
                Text(isSourceFilterActive ? "当前来源过滤条件下没有匹配的搜索结果" : "尝试输入其他关键词")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityIdentifier(isSourceFilterActive ? "searchFilterEmptyState" : "searchEmptyState")
        }
        else
        {
            List(results) { clip in
                ClipRowView(clip: clip)
                    .contentShape(Rectangle())
                    .onTapGesture { onSelect(clip) }
            }
            .accessibilityIdentifier("searchResultsList")
        }
    }
}
```

- [ ] **步骤 2：更新 MainWindow 传递 isSourceFilterActive**

在 `MainWindow.swift` 的 `contentArea` 中，`SearchResultsView` 调用时传入 `isSourceFilterActive`：

```swift
SearchResultsView(
    results: filteredSearchResults,
    onSelect: { clip in selectedClip = clip },
    isSourceFilterActive: !sourceFilterSelection.isAllSelected
)
```

- [ ] **步骤 3：编译检查**

运行：
```bash
xcodebuild build \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```
预期：编译成功

- [ ] **步骤 4：运行 Lint**

运行：
```bash
swiftlint lint --strict
```
预期：无错误

- [ ] **步骤 5：Commit**

```bash
git add ClipMind/UI/MainWindow/SearchResultsView.swift ClipMind/UI/MainWindow/MainWindow.swift
git commit -m "feat(source-filter): distinguish source filter empty state in SearchResultsView"
```

---

## 任务 7：过滤状态独立性测试

**文件：**
- 新增：`ClipMindTests/SourceFilter/SourceFilterStateIndependenceTests.swift`

- [ ] **步骤 1：编写并运行独立性测试**

创建 `ClipMindTests/SourceFilter/SourceFilterStateIndependenceTests.swift`：

```swift
@testable import ClipMind
import XCTest

/// 主窗口与弹窗过滤状态独立性测试。
///
/// 验证主窗口的 SourceFilterSelection 与弹窗的 SourceFilterSelection
/// 各自独立，修改一方不影响另一方。
final class SourceFilterStateIndependenceTests: XCTestCase
{
    func testMainWindowFilterChange_doesNotAffectPopoverFilter()
    {
        let allApps: Set<String> = ["Safari", "Xcode", "Notes"]

        // 模拟主窗口的过滤状态
        var mainWindowSelection = SourceFilterSelection(allApps: allApps)
        // 模拟弹窗的过滤状态
        var popoverSelection = SourceFilterSelection(allApps: allApps)

        // 主窗口选中 Safari
        mainWindowSelection.toggleSource("Safari")
        XCTAssertEqual(mainWindowSelection.selectedSources, ["Safari"])
        // 弹窗仍为「全部」
        XCTAssertTrue(popoverSelection.isAllSelected)
    }

    func testPopoverFilterChange_doesNotAffectMainWindowFilter()
    {
        let allApps: Set<String> = ["Safari", "Xcode", "Notes"]

        var mainWindowSelection = SourceFilterSelection(allApps: allApps)
        mainWindowSelection.toggleSource("Safari")

        var popoverSelection = SourceFilterSelection(allApps: allApps)
        popoverSelection.toggleSource("Xcode")

        // 主窗口仍为 Safari
        XCTAssertEqual(mainWindowSelection.selectedSources, ["Safari"])
        // 弹窗为 Xcode
        XCTAssertEqual(popoverSelection.selectedSources, ["Xcode"])
    }

    func testBothSelections_startAsAll()
    {
        let allApps: Set<String> = ["Safari", "Xcode"]
        let mainWindowSelection = SourceFilterSelection(allApps: allApps)
        let popoverSelection = SourceFilterSelection(allApps: allApps)

        XCTAssertTrue(mainWindowSelection.isAllSelected)
        XCTAssertTrue(popoverSelection.isAllSelected)
    }

    func testResetMainWindow_doesNotAffectPopover()
    {
        let allApps: Set<String> = ["Safari", "Xcode", "Notes"]

        var mainWindowSelection = SourceFilterSelection(allApps: allApps)
        var popoverSelection = SourceFilterSelection(allApps: allApps)

        // 两者都选中 Safari
        mainWindowSelection.toggleSource("Safari")
        popoverSelection.toggleSource("Safari")

        // 重置主窗口
        mainWindowSelection.resetToAll()
        XCTAssertTrue(mainWindowSelection.isAllSelected)
        // 弹窗仍为 Safari
        XCTAssertEqual(popoverSelection.selectedSources, ["Safari"])
    }

    func testFilterSelectionNotPersisted_afterReinit()
    {
        let allApps: Set<String> = ["Safari", "Xcode"]

        var selection = SourceFilterSelection(allApps: allApps)
        selection.toggleSource("Safari")
        XCTAssertEqual(selection.selectedSources, ["Safari"])

        // 模拟重新打开窗口：重新初始化
        let newSelection = SourceFilterSelection(allApps: allApps)
        XCTAssertTrue(newSelection.isAllSelected)
    }
}
```

- [ ] **步骤 2：运行测试验证通过**

运行：
```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:ClipMindTests/SourceFilterStateIndependenceTests
```
预期：PASS，5 个测试全绿

- [ ] **步骤 3：Commit**

```bash
git add ClipMindTests/SourceFilter/SourceFilterStateIndependenceTests.swift
git commit -m "test(source-filter): add state independence tests for main window and popover"
```

---

## 任务 8：Phase 0 全量验证 + Lint + Commit

- [ ] **步骤 1：运行 Lint**

运行：
```bash
swiftlint lint --strict
```
预期：无错误

- [ ] **步骤 2：运行全量单元测试**

运行：
```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:ClipMindTests
```
预期：全部通过

- [ ] **步骤 3：编译检查**

运行：
```bash
xcodebuild build \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```
预期：编译成功

- [ ] **步骤 4：UI 证据任务 — 手动启动 App 验证主窗口来源过滤行为**

运行 App，验证以下行为：
1. 主窗口打开后，来源过滤器默认显示「全部来源」
2. 点击来源过滤器下拉，显示 Checkbox 列表（「全部来源」+ 各来源应用名称）
3. 选中某个应用后，「全部来源」取消，历史列表仅显示该来源的条目
4. 选中「全部来源」后，历史列表显示所有条目
5. 过滤后无匹配结果时，历史列表显示「无匹配的剪贴项」空状态

---

## Phase 0 合并到 develop 的预期基线

Phase 0 完成后，合并到 develop 分支前应满足：

1. ✅ SwiftLint strict 无错误
2. ✅ xcodebuild build 编译成功
3. ✅ 全量单元测试通过（包含新增的 5 个测试文件）
4. ✅ 主窗口来源过滤器为多选 Checkbox（AC-F1.13-1）
5. ✅ 主窗口历史列表受来源过滤影响（AC-F1.13-2）
6. ✅ 主窗口搜索结果受来源过滤影响（AC-F1.13-3）
7. ✅ 来源应用列表从数据动态提取（AC-F1.13-6）
8. ✅ 主窗口空状态提示正常显示（AC-F1.13-7 主窗口部分）
9. ✅ 主窗口与弹窗过滤状态独立（AC-F1.13-8 单元测试层面）
10. ✅ 过滤状态不持久化（AC-F1.13-9 单元测试层面）
