# Phase 1：弹窗筛选按钮 + App 多选浮层 + 弹窗列表过滤

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 为菜单栏弹窗和快捷粘贴面板新增来源筛选按钮（漏斗图标）和 App 多选浮层，使弹窗列表受来源过滤影响，浮层点击外部可关闭，弹窗空状态提示正常显示。

**范围：** AC-F1.13-4（弹窗筛选按钮 + App 多选浮层）、AC-F1.13-5（弹窗列表过滤）、AC-F1.13-7（弹窗空状态提示）、AC-F1.13-10（浮层点击外部关闭）

**非目标：** 主窗口来源过滤器（Phase 0 已完成）、XCUITest UI 自动化测试（Phase 2）、VoiceOver 可访问性验证（手动）

---

## 涉及文件和职责

| 文件 | 职责 | 操作 |
|------|------|------|
| `ClipMind/UI/MenuBar/SourceFilterOverlay.swift` | 弹窗来源筛选浮层组件，Checkbox 多选列表 | 新增 |
| `ClipMind/UI/MenuBar/UnifiedPastePanelView.swift` | 新增来源筛选按钮；点击弹出浮层；列表根据过滤条件过滤；空状态提示 | 修改 |
| `ClipMind/UI/MenuBar/UnifiedPastePanelViewModel.swift` | 新增 `sourceFilterSelection` 过滤状态；来源应用列表提取；过滤后剪贴项列表计算；浮层开关状态 | 修改 |
| `ClipMindTests/UI/UnifiedPastePanelViewModelFilterTests.swift` | 统一粘贴面板 ViewModel 过滤逻辑单元测试 | 新增 |

---

## 前置依赖

Phase 0 必须已完成，以下模块可用：
- `SourceAppExtractor`：来源应用列表动态提取
- `SourceFilterSelection`：多选 Checkbox 联动逻辑
- `SourceFilter`：主窗口多选 Checkbox 组件（仅参考，弹窗使用独立的浮层组件）

---

## 任务 1：UnifiedPastePanelViewModel 新增来源过滤状态

**文件：**
- 修改：`ClipMind/UI/MenuBar/UnifiedPastePanelViewModel.swift`
- 新增：`ClipMindTests/UI/UnifiedPastePanelViewModelFilterTests.swift`

- [ ] **步骤 1：编写失败的测试 — ViewModel 过滤逻辑**

创建 `ClipMindTests/UI/UnifiedPastePanelViewModelFilterTests.swift`：

```swift
@testable import ClipMind
import XCTest

/// 统一粘贴面板 ViewModel 来源过滤逻辑测试。
@MainActor
final class UnifiedPastePanelViewModelFilterTests: XCTestCase
{
    // MARK: - 来源应用列表提取

    func testSourceApps_returnsSortedUniqueNames()
    {
        let clips = [
            makeClip(sourceAppName: "Safari"),
            makeClip(sourceAppName: "Xcode"),
            makeClip(sourceAppName: "Safari")
        ]
        let viewModel = UnifiedPastePanelViewModel(clips: clips)
        XCTAssertEqual(viewModel.sourceApps, ["Safari", "Xcode"])
    }

    func testSourceApps_emptyClips_returnsEmpty()
    {
        let viewModel = UnifiedPastePanelViewModel(clips: [])
        XCTAssertEqual(viewModel.sourceApps, [])
    }

    // MARK: - 过滤后剪贴项列表

    func testFilteredClips_allSelected_returnsAllClips()
    {
        let clips = [
            makeClip(sourceAppName: "Safari"),
            makeClip(sourceAppName: "Xcode")
        ]
        let viewModel = UnifiedPastePanelViewModel(clips: clips)
        XCTAssertTrue(viewModel.sourceFilterSelection.isAllSelected)
        XCTAssertEqual(viewModel.filteredClips.count, 2)
    }

    func testFilteredClips_singleSourceSelected_returnsFilteredClips()
    {
        let clips = [
            makeClip(sourceAppName: "Safari"),
            makeClip(sourceAppName: "Xcode"),
            makeClip(sourceAppName: "Safari")
        ]
        let viewModel = UnifiedPastePanelViewModel(clips: clips)
        viewModel.sourceFilterSelection.toggleSource("Safari")
        XCTAssertEqual(viewModel.filteredClips.count, 2)
        XCTAssertTrue(viewModel.filteredClips.allSatisfy { $0.sourceAppName == "Safari" })
    }

    func testFilteredClips_noSourceSelected_returnsEmpty()
    {
        let clips = [
            makeClip(sourceAppName: "Safari"),
            makeClip(sourceAppName: "Xcode")
        ]
        let viewModel = UnifiedPastePanelViewModel(clips: clips)
        viewModel.sourceFilterSelection.toggleAll()
        viewModel.sourceFilterSelection.selectedSources = [] // 手动清空
        XCTAssertTrue(viewModel.filteredClips.isEmpty)
    }

    // MARK: - 浮层开关状态

    func testShowFilterOverlay_initiallyFalse()
    {
        let clips = [makeClip(sourceAppName: "Safari")]
        let viewModel = UnifiedPastePanelViewModel(clips: clips)
        XCTAssertFalse(viewModel.showFilterOverlay)
    }

    func testToggleFilterOverlay()
    {
        let clips = [makeClip(sourceAppName: "Safari")]
        let viewModel = UnifiedPastePanelViewModel(clips: clips)
        viewModel.showFilterOverlay = true
        XCTAssertTrue(viewModel.showFilterOverlay)
    }

    // MARK: - 过滤状态不持久化

    func testFilterSelection_resetsOnReinit()
    {
        let clips = [
            makeClip(sourceAppName: "Safari"),
            makeClip(sourceAppName: "Xcode")
        ]
        let viewModel1 = UnifiedPastePanelViewModel(clips: clips)
        viewModel1.sourceFilterSelection.toggleSource("Safari")

        // 模拟弹窗重新打开
        let viewModel2 = UnifiedPastePanelViewModel(clips: clips)
        XCTAssertTrue(viewModel2.sourceFilterSelection.isAllSelected)
    }

    // MARK: - Helper

    private func makeClip(sourceAppName: String) -> ClipItem
    {
        ClipItem(
            id: UUID(),
            content: .text("test content"),
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
  -only-testing:ClipMindTests/UnifiedPastePanelViewModelFilterTests
```
预期：FAIL，报错 `Value of type 'UnifiedPastePanelViewModel' has no member 'sourceApps'`

- [ ] **步骤 3：修改 UnifiedPastePanelViewModel 新增过滤状态**

修改 `ClipMind/UI/MenuBar/UnifiedPastePanelViewModel.swift`，新增以下属性和方法：

```swift
import Foundation

/// 统一粘贴面板视图状态管理器（F1.11 Phase 1, F1.13 Phase 1）。
///
/// 由 F1.9 的 `QuickPasteViewModel` 迁移而来，承载两个场景共用的高亮选中状态、
/// 单击 / 双击 / 回车 / 方向键 / Esc 事件路由、`shouldShowTextOnlyHint` 提示状态。
/// F1.13 新增：来源过滤状态、来源应用列表提取、过滤后剪贴项列表。
@MainActor
final class UnifiedPastePanelViewModel: ObservableObject
{
    /// 当前高亮选中行索引（默认 0，空列表为 -1）。
    @Published var selectedIndex: Int

    /// 双击 / 回车触发的粘贴回调（由控制器注入 PasteCoordinator.handlePaste）。
    var onPasteTriggered: ((ClipItem) -> Void)?

    /// 测试用：记录最近触发 onPasteTriggered 的 clip.id，供 UI 测试通过测试元素验证回调被调用。
    @Published var lastTriggeredClipIdForTesting: String?

    /// 是否显示「仅支持文本粘贴」提示（双击图片 / 文件路径行时为 true）。
    @Published var shouldShowTextOnlyHint = false

    /// Esc 键回调（由控制器关闭面板）。
    var onEscPressed: (() -> Void)?

    /// 「退出」按钮回调（由控制器退出整个应用）。
    var onExitApp: (() -> Void)?

    /// 单击回调（更新选中状态，不触发粘贴）。
    var onSingleClick: ((Int) -> Void)?

    /// 双击回调（触发粘贴流程）。
    var onDoubleClick: ((ClipItem) -> Void)?

    /// 由外部注入的剪贴项列表（不直接读取剪贴板存储）。
    let clips: [ClipItem]

    // MARK: - F1.13 来源过滤

    /// 来源过滤选中状态（初始为「全部」选中）。
    @Published var sourceFilterSelection: SourceFilterSelection

    /// 来源筛选浮层是否显示。
    @Published var showFilterOverlay = false

    /// 来源应用名称列表（去重、排序）。
    var sourceApps: [String]
    {
        SourceAppExtractor.extract(from: clips)
    }

    /// 根据来源过滤条件过滤后的剪贴项列表。
    var filteredClips: [ClipItem]
    {
        if sourceFilterSelection.isAllSelected
        {
            return clips
        }
        return clips.filter { sourceFilterSelection.selectedSources.contains($0.sourceAppName) }
    }

    /// 来源过滤是否生效（非「全部」）。
    var isSourceFilterActive: Bool
    {
        !sourceFilterSelection.isAllSelected
    }

    init(clips: [ClipItem])
    {
        self.clips = clips
        self.selectedIndex = clips.isEmpty ? -1 : 0
        self.sourceFilterSelection = SourceFilterSelection(
            allApps: Set(clips.map(\.sourceAppName).filter { !$0.isEmpty })
        )
    }

    // MARK: - 选中状态

    func isSelected(index: Int) -> Bool
    {
        index == selectedIndex
    }

    func selectIndex(_ index: Int)
    {
        guard clips.indices.contains(index) else { return }
        selectedIndex = index
        shouldShowTextOnlyHint = false
        onSingleClick?(index)
    }

    // MARK: - 方向键导航

    func moveSelectionUp()
    {
        guard !clips.isEmpty, selectedIndex > 0 else { return }
        selectedIndex -= 1
    }

    func moveSelectionDown()
    {
        guard !clips.isEmpty, selectedIndex < clips.count - 1 else { return }
        selectedIndex += 1
    }

    // MARK: - 键盘事件

    func handleEnterKey()
    {
        guard clips.indices.contains(selectedIndex) else { return }
        let clip = clips[selectedIndex]
        onPasteTriggered?(clip)
        lastTriggeredClipIdForTesting = clip.id.uuidString
    }

    /// 双击处理（按 clip 查找）：文本类型触发粘贴回调，图片 / 文件路径类型显示提示。
    func handleDoubleClick(clip: ClipItem)
    {
        switch clip.content
        {
        case .text:
            shouldShowTextOnlyHint = false
            onPasteTriggered?(clip)
            lastTriggeredClipIdForTesting = clip.id.uuidString
        case .image, .filePath:
            shouldShowTextOnlyHint = true
            LogCategory.ui.info("UnifiedPastePanel double-click on non-text row, showing hint")
        }
    }

    func handleEscKey()
    {
        onEscPressed?()
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
  -only-testing:ClipMindTests/UnifiedPastePanelViewModelFilterTests
```
预期：PASS，7 个测试全绿

- [ ] **步骤 5：运行现有 ViewModel 测试确保未回归**

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
  -only-testing:ClipMindTests/UnifiedPastePanelViewModelTests
```
预期：PASS

- [ ] **步骤 6：Commit**

```bash
git add ClipMind/UI/MenuBar/UnifiedPastePanelViewModel.swift ClipMindTests/UI/UnifiedPastePanelViewModelFilterTests.swift
git commit -m "feat(source-filter): add source filter state to UnifiedPastePanelViewModel"
```

---

## 任务 2：SourceFilterOverlay 弹窗来源筛选浮层组件

**文件：**
- 新增：`ClipMind/UI/MenuBar/SourceFilterOverlay.swift`

- [ ] **步骤 1：创建 SourceFilterOverlay 组件**

创建 `ClipMind/UI/MenuBar/SourceFilterOverlay.swift`：

```swift
import SwiftUI

/// 弹窗来源筛选浮层组件（F1.13 Phase 1）。
///
/// 显示 Checkbox 列表，包含「全部」选项和各来源应用名称。
/// Checkbox 联动逻辑与主窗口 SourceFilter 一致：
/// - 选中「全部」时所有来源均通过过滤。
/// - 取消勾选「全部」后按各应用 Checkbox 选中状态过滤。
/// - 手动选中所有应用时自动选中「全部」。
struct SourceFilterOverlay: View
{
    @Binding var selection: SourceFilterSelection
    let availableApps: [String]

    var body: some View
    {
        VStack(alignment: .leading, spacing: 0)
        {
            // 「全部」选项
            SourceFilterCheckboxRow(
                title: "全部来源",
                isChecked: selection.isAllSelected
            )
            {
                selection.toggleAll()
            }

            if !availableApps.isEmpty
            {
                Divider().padding(.vertical, 4)

                // 各来源应用
                ForEach(availableApps, id: \.self) { app in
                    SourceFilterCheckboxRow(
                        title: app,
                        isChecked: selection.selectedSources.contains(app)
                    )
                    {
                        selection.toggleSource(app)
                    }
                }
            }
        }
        .padding(12)
        .frame(minWidth: 180)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
    }
}

/// Checkbox 行组件。
private struct SourceFilterCheckboxRow: View
{
    let title: String
    let isChecked: Bool
    let action: () -> Void

    var body: some View
    {
        Button(action: action)
        {
            HStack(spacing: 8)
            {
                Image(systemName: isChecked ? "checkmark.square" : "square")
                    .foregroundColor(isChecked ? .accentColor : .secondary)
                    .frame(width: 16, height: 16)
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)\(isChecked ? " 已选中" : " 未选中")")
        .accessibilityAddTraits(isChecked ? .isSelected : [])
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
预期：编译成功（SourceFilterOverlay 尚未被引用，但不影响编译）

- [ ] **步骤 3：Commit**

```bash
git add ClipMind/UI/MenuBar/SourceFilterOverlay.swift
git commit -m "feat(source-filter): add SourceFilterOverlay for popover source filtering"
```

---

## 任务 3：UnifiedPastePanelView 集成筛选按钮 + 浮层 + 过滤

**文件：**
- 修改：`ClipMind/UI/MenuBar/UnifiedPastePanelView.swift`

- [ ] **步骤 1：修改 UnifiedPastePanelView 集成来源筛选**

修改 `ClipMind/UI/MenuBar/UnifiedPastePanelView.swift`，关键变更点：

1. `searchBar` 新增来源筛选按钮（漏斗图标），按钮在有过滤生效时显示激活态
2. 新增 `filterOverlay` 浮层视图，使用 `popover` 修饰符定位
3. `filteredClips` 计算属性适配来源过滤
4. 列表使用 `viewModel.filteredClips` 替代 `viewModel.clips`
5. 空状态提示区分「来源过滤无匹配」

修改后的完整文件：

```swift
import AppKit
import SwiftUI

/// 统一粘贴面板视图（F1.11 Phase 1, F1.13 Phase 1）。
///
/// 合并 F1.9 `QuickPasteView` 与 `PopoverView`，承载两个场景共用的列表渲染、键盘事件、
/// 选中态逻辑。F1.13 新增来源筛选按钮和 App 多选浮层。
struct UnifiedPastePanelView: View
{
    @StateObject private var viewModel: UnifiedPastePanelViewModel
    @State private var searchText = ""
    @State private var keyMonitor: Any?

    private let showsBottomBar: Bool
    private let accessibilityPrefix: String

    init(viewModel: UnifiedPastePanelViewModel, showsBottomBar: Bool, accessibilityPrefix: String)
    {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.showsBottomBar = showsBottomBar
        self.accessibilityPrefix = accessibilityPrefix
    }

    var body: some View
    {
        VStack(spacing: 0)
        {
            searchBar
            Divider()
            contentList
            if showsBottomBar
            {
                Divider()
                bottomToolbar
            }
        }
        .frame(width: 360, height: 480)
        .onAppear { startKeyMonitor() }
        .onDisappear { stopKeyMonitor() }
        .onChange(of: searchText)
        { _ in
            if !searchFilteredClips.isEmpty
            {
                viewModel.selectedIndex = 0
            }
        }
    }

    // MARK: - 搜索框 + 来源筛选按钮

    private var searchBar: some View
    {
        HStack(spacing: 8)
        {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("搜索剪贴内容...", text: $searchText)
                .textFieldStyle(.plain)
                .accessibilityIdentifier("\(accessibilityPrefix)SearchField")

            // F1.13：来源筛选按钮
            Button(action: { viewModel.showFilterOverlay.toggle() })
            {
                Image(systemName: viewModel.isSourceFilterActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    .foregroundColor(viewModel.isSourceFilterActive ? .accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("来源筛选")
            .accessibilityIdentifier("\(accessibilityPrefix)SourceFilterButton")
            .popover(isPresented: $viewModel.showFilterOverlay, arrowEdge: .bottom)
            {
                SourceFilterOverlay(
                    selection: $viewModel.sourceFilterSelection,
                    availableApps: viewModel.sourceApps
                )
            }
        }
        .padding(8)
    }

    // MARK: - 列表

    /// 搜索文本过滤后的剪贴项（基于来源过滤后的列表）
    private var searchFilteredClips: [ClipItem]
    {
        let sourceFiltered = viewModel.filteredClips
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return sourceFiltered }
        return sourceFiltered.filter { clip in
            if case .text(let text) = clip.content
            {
                return text.localizedCaseInsensitiveContains(trimmed)
            }
            return false
        }
    }

    private var contentList: some View
    {
        Group
        {
            if searchFilteredClips.isEmpty
            {
                VStack(spacing: 8)
                {
                    Image(systemName: viewModel.isSourceFilterActive ? "line.3.horizontal.decrease.circle" : "tray")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text(viewModel.isSourceFilterActive ? "无匹配的剪贴项" : "暂无剪贴内容")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier(viewModel.isSourceFilterActive ? "popoverFilterEmptyState" : "popoverEmptyState")
            }
            else
            {
                ScrollView
                {
                    LazyVStack(spacing: 0)
                    {
                        ForEach(Array(searchFilteredClips.enumerated()), id: \.element.id)
                        { index, clip in
                            ClipRowView(
                                clip: clip,
                                isSelected: viewModel.isSelected(index: index),
                                onSingleClick: { viewModel.selectIndex(index) },
                                onDoubleClick: { viewModel.handleDoubleClick(clip: clip) }
                            )
                            .accessibilityIdentifier(
                                "\(accessibilityPrefix)Row_\(index)"
                                + "\(viewModel.isSelected(index: index) ? "_selected" : "")"
                            )
                            .accessibilityValue(clip.id.uuidString)
                        }

                        if viewModel.shouldShowTextOnlyHint
                        {
                            Text("仅支持文本粘贴")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity)
                                .accessibilityIdentifier("textOnlyHint")
                        }
                    }
                }
                Text(viewModel.lastTriggeredClipIdForTesting ?? "")
                    .accessibilityIdentifier("\(accessibilityPrefix)TestTriggeredClipId")
                    .frame(width: 0, height: 0)
                    .opacity(0)
            }
        }
    }

    // MARK: - 底部工具栏

    private var bottomToolbar: some View
    {
        BottomToolbarView(
            onViewAll:
            {
                viewModel.onEscPressed?()
                NotificationCenter.default.post(name: .openMainWindow, object: nil)
            },
            onSettings:
            {
                viewModel.onEscPressed?()
                NotificationCenter.default.post(name: .openSettingsWindow, object: nil)
            },
            onExit:
            {
                viewModel.onExitApp?()
            }
        )
    }

    // MARK: - 键盘事件监听

    private func startKeyMonitor()
    {
        let handler = PanelKeyEventHandler(
            onEnter: { viewModel.handleEnterKey() },
            onEsc: { viewModel.handleEscKey() },
            onMoveDown: { viewModel.moveSelectionDown() },
            onMoveUp: { viewModel.moveSelectionUp() }
        )
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown)
        { event in
            handler.handle(event)
        }
    }

    private func stopKeyMonitor()
    {
        if let monitor = keyMonitor
        {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
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
预期：编译成功

- [ ] **步骤 3：运行 Lint**

运行：
```bash
swiftlint lint --strict
```
预期：无错误

- [ ] **步骤 4：运行现有测试确保未回归**

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

- [ ] **步骤 5：Commit**

```bash
git add ClipMind/UI/MenuBar/UnifiedPastePanelView.swift
git commit -m "feat(source-filter): integrate source filter button and overlay into popover"
```

---

## 任务 4：弹窗过滤与搜索联动验证测试

**文件：**
- 修改：`ClipMindTests/UI/UnifiedPastePanelViewModelFilterTests.swift`

- [ ] **步骤 1：补充搜索 + 来源过滤联动测试**

在 `ClipMindTests/UI/UnifiedPastePanelViewModelFilterTests.swift` 末尾追加以下测试：

```swift
    // MARK: - 搜索 + 来源过滤联动

    func testFilteredClips_withSourceFilterAndSearchText_bothApplied()
    {
        let clips = [
            makeClip(sourceAppName: "Safari", text: "Hello World"),
            makeClip(sourceAppName: "Xcode", text: "Swift programming"),
            makeClip(sourceAppName: "Safari", text: "SwiftUI guide")
        ]
        let viewModel = UnifiedPastePanelViewModel(clips: clips)

        // 选中 Safari
        viewModel.sourceFilterSelection.toggleSource("Safari")
        XCTAssertEqual(viewModel.filteredClips.count, 2) // 2 条 Safari

        // 搜索 "Swift" 在 filteredClips 中
        let searchFiltered = viewModel.filteredClips.filter { clip in
            if case .text(let text) = clip.content
            {
                return text.localizedCaseInsensitiveContains("Swift")
            }
            return false
        }
        XCTAssertEqual(searchFiltered.count, 1) // 仅 "SwiftUI guide"
    }

    func testFilteredClips_sourceFilterChange_updatesImmediately()
    {
        let clips = [
            makeClip(sourceAppName: "Safari"),
            makeClip(sourceAppName: "Xcode")
        ]
        let viewModel = UnifiedPastePanelViewModel(clips: clips)

        // 初始全部
        XCTAssertEqual(viewModel.filteredClips.count, 2)

        // 选中 Safari
        viewModel.sourceFilterSelection.toggleSource("Safari")
        XCTAssertEqual(viewModel.filteredClips.count, 1)
        XCTAssertEqual(viewModel.filteredClips.first?.sourceAppName, "Safari")

        // 重置为全部
        viewModel.sourceFilterSelection.resetToAll()
        XCTAssertEqual(viewModel.filteredClips.count, 2)
    }

    func testIsSourceFilterActive_trueWhenPartialSelected()
    {
        let clips = [
            makeClip(sourceAppName: "Safari"),
            makeClip(sourceAppName: "Xcode")
        ]
        let viewModel = UnifiedPastePanelViewModel(clips: clips)

        XCTAssertFalse(viewModel.isSourceFilterActive)

        viewModel.sourceFilterSelection.toggleSource("Safari")
        XCTAssertTrue(viewModel.isSourceFilterActive)

        viewModel.sourceFilterSelection.resetToAll()
        XCTAssertFalse(viewModel.isSourceFilterActive)
    }

    private func makeClip(sourceAppName: String, text: String = "test content") -> ClipItem
    {
        ClipItem(
            id: UUID(),
            content: .text(text),
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
  -only-testing:ClipMindTests/UnifiedPastePanelViewModelFilterTests
```
预期：PASS，10 个测试全绿

- [ ] **步骤 3：运行 Lint**

运行：
```bash
swiftlint lint --strict
```
预期：无错误

- [ ] **步骤 4：Commit**

```bash
git add ClipMindTests/UI/UnifiedPastePanelViewModelFilterTests.swift
git commit -m "test(source-filter): add search + source filter integration tests for popover"
```

---

## 任务 5：Phase 1 全量验证 + Lint + UI 证据

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

- [ ] **步骤 4：UI 证据任务 — 手动启动 App 验证弹窗来源筛选行为**

运行 App，验证以下行为：
1. 打开菜单栏弹窗，搜索栏右侧显示漏斗图标按钮（默认态）
2. 点击漏斗图标，弹出 App 多选浮层，包含「全部来源」+ 各来源应用名称 Checkbox
3. 浮层中选中某个应用后，弹窗列表仅显示该来源的剪贴项，漏斗图标变为填充态（激活态）
4. 选中「全部来源」后，弹窗列表显示所有条目，漏斗图标恢复默认态
5. 点击浮层外区域关闭浮层，过滤状态保持
6. 过滤后无匹配结果时，弹窗列表显示「无匹配的剪贴项」空状态提示
7. 弹窗关闭后重新打开，来源过滤默认「全部」

---

## Phase 1 合并到 develop 的预期基线

Phase 1 完成后，合并到 develop 分支前应满足：

1. ✅ SwiftLint strict 无错误
2. ✅ xcodebuild build 编译成功
3. ✅ 全量单元测试通过（包含新增的 2 个测试文件 + Phase 0 已有测试）
4. ✅ 弹窗搜索栏旁有来源筛选按钮（AC-F1.13-4）
5. ✅ 点击筛选按钮弹出 App 多选浮层（AC-F1.13-4）
6. ✅ 弹窗列表受来源过滤影响（AC-F1.13-5）
7. ✅ 弹窗空状态提示正常显示（AC-F1.13-7 弹窗部分）
8. ✅ 浮层点击外部区域可关闭，过滤状态保持（AC-F1.13-10）
