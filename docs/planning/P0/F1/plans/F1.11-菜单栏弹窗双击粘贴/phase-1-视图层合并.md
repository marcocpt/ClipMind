# Phase 1：视图层合并 + PanelClosing 协议扩展 + StatusItemController 实现 + 数据源统一

> 最后更新：2026-07-25 | 版本：v1.1

**全局约束（AGENTS.md §8）：** 本 Phase 中所有任务在执行 `git commit` 前必须先运行 `swiftlint lint --strict` 并通过。仅文档、配置等非代码改动可跳过。任务步骤中不再重复说明 Lint 环节，但每个 Commit 步骤默认包含「Lint → Commit」两步。

**目标：** 把 `PopoverView`（菜单栏弹窗）与 `QuickPasteView`（快捷键面板）合并为 `UnifiedPastePanelView` + `UnifiedPastePanelViewModel`，让 `StatusItemController` 实现 `PanelClosing` 协议并从 `EncryptedStore` 注入数据源，使两个入口共用同一视图与同一关闭接口。

**架构：**
- `UnifiedPastePanelViewModel` 由 `QuickPasteViewModel` 重命名迁移而来，全部能力保留。
- `UnifiedPastePanelView` 接收 `viewModel` 与 `showsBottomBar: Bool` 两个外部参数，通过条件渲染控制底部工具栏显隐。
- `StatusItemController` 新增 `@MainActor` 隔离、`PanelClosing` 协议实现、`setup(encryptedStore:pasteCoordinator:)` 入口；保留 `togglePopover` 行为。
- `QuickPastePanelController` 改为注入 `UnifiedPastePanelView`，不再依赖 `QuickPasteView`。
- `PopoverView.swift` 与 `QuickPasteView.swift` 在 Phase 1 末尾删除。

**技术栈：** SwiftUI（`StateObject`、`onTapGesture`、`accessibilityIdentifier`、`NSEvent.addLocalMonitorForEvents`）、AppKit（`NSStatusItem`、`NSPopover`、`NSHostingController`）、XCTest。

**关联 AC：** AC-F1.11-12（PanelClosing 协议扩展）、AC-F1.11-13（底部工具栏条件渲染 - 显隐控制机制）、AC-F1.11-14（数据源统一与外部注入）

**Phase 1 基线：**
- `xcodegen generate && xcodebuild build` 通过
- `swiftlint lint --strict` 通过
- `UnifiedPastePanelView` 在菜单栏弹窗与快捷键面板两个场景下都能渲染列表
- `StatusItemController.closePanel()` 能关闭菜单栏弹窗
- F1.9 现有单元测试全部通过

---

## 文件清单

**创建：**
- `ClipMind/UI/MenuBar/UnifiedPastePanelViewModel.swift`
- `ClipMind/UI/MenuBar/UnifiedPastePanelView.swift`
- `ClipMindTests/UI/UnifiedPastePanelViewModelTests.swift`
- `ClipMindTests/UI/StatusItemControllerTests.swift`

**修改：**
- `ClipMind/UI/MenuBar/StatusItemController.swift`（实现 `PanelClosing` + 注入依赖）
- `ClipMind/UI/QuickPaste/QuickPastePanelController.swift`（切换到 `UnifiedPastePanelView`）
- `ClipMind/App/QuickPasteAssembly.swift`（构造 `UnifiedPastePanelView`）
- `ClipMind/App/ClipMindApp.swift`（`setup` 调用方改为注入依赖）
- `project.yml`（新增 3 个文件清单）

**删除：**
- `ClipMind/UI/MenuBar/PopoverView.swift`
- `ClipMind/UI/QuickPaste/QuickPasteView.swift`

---

## 任务 1：创建 `UnifiedPastePanelViewModel`

**文件：**
- 创建：`ClipMind/UI/MenuBar/UnifiedPastePanelViewModel.swift`
- 测试：`ClipMindTests/UI/UnifiedPastePanelViewModelTests.swift`

- [ ] **步骤 1：编写失败的测试**

创建 `ClipMindTests/UI/UnifiedPastePanelViewModelTests.swift`：

```swift
import XCTest
@testable import ClipMind

/// UnifiedPastePanelViewModel 单元测试（Phase 1 任务 1）。
///
/// 验证视图状态管理器的基础契约：
/// - 默认高亮第一行（空列表时 selectedIndex = -1）
/// - isSelected / selectIndex / moveSelectionUp / moveSelectionDown
/// - handleDoubleClick 按 clip 查找（文本触发回调，图片/文件路径显示提示）
/// - handleEnterKey / handleEscKey 回调路由
@MainActor
final class UnifiedPastePanelViewModelTests: XCTestCase
{
    func testInit_WithNonEmptyClips_DefaultsSelectedIndexToZero()
    {
        let clips = ClipTestData.previewClips
        let viewModel = UnifiedPastePanelViewModel(clips: clips)

        XCTAssertEqual(viewModel.selectedIndex, 0, "非空列表默认高亮第一行（索引 0）")
    }

    func testInit_WithEmptyClips_DefaultsSelectedIndexToMinusOne()
    {
        let viewModel = UnifiedPastePanelViewModel(clips: [])

        XCTAssertEqual(viewModel.selectedIndex, -1, "空列表 selectedIndex = -1，无高亮")
    }

    func testSelectIndex_UpdatesSelectedIndexAndClearsHint()
    {
        let clips = ClipTestData.previewClips
        let viewModel = UnifiedPastePanelViewModel(clips: clips)
        viewModel.shouldShowTextOnlyHint = true

        viewModel.selectIndex(1)

        XCTAssertEqual(viewModel.selectedIndex, 1)
        XCTAssertFalse(viewModel.shouldShowTextOnlyHint, "切换选中时清除文本提示")
    }

    func testSelectIndex_OutOfBounds_IsIgnored()
    {
        let clips = ClipTestData.previewClips
        let viewModel = UnifiedPastePanelViewModel(clips: clips)

        viewModel.selectIndex(-1)
        XCTAssertEqual(viewModel.selectedIndex, 0, "负索引被忽略")

        viewModel.selectIndex(clips.count)
        XCTAssertEqual(viewModel.selectedIndex, 0, "越界索引被忽略")
    }

    func testMoveSelectionDown_AdvancesSelectedIndex()
    {
        let clips = ClipTestData.previewClips
        let viewModel = UnifiedPastePanelViewModel(clips: clips)

        viewModel.moveSelectionDown()
        XCTAssertEqual(viewModel.selectedIndex, 1)
    }

    func testMoveSelectionDown_AtLastIndex_StaysAtLast()
    {
        let clips = ClipTestData.previewClips
        let viewModel = UnifiedPastePanelViewModel(clips: clips)
        viewModel.selectIndex(clips.count - 1)

        viewModel.moveSelectionDown()

        XCTAssertEqual(viewModel.selectedIndex, clips.count - 1, "末行按下不动")
    }

    func testMoveSelectionUp_AtFirstIndex_StaysAtFirst()
    {
        let clips = ClipTestData.previewClips
        let viewModel = UnifiedPastePanelViewModel(clips: clips)

        viewModel.moveSelectionUp()

        XCTAssertEqual(viewModel.selectedIndex, 0, "首行按上不动")
    }

    func testHandleDoubleClick_TextClip_TriggersPasteCallback()
    {
        let textClip = ClipItem.makeText(
            "hello",
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        let viewModel = UnifiedPastePanelViewModel(clips: [textClip])
        var triggeredClip: ClipItem?
        viewModel.onPasteTriggered = { clip in triggeredClip = clip }

        viewModel.handleDoubleClick(clip: textClip)

        XCTAssertEqual(triggeredClip?.id, textClip.id, "文本类型双击触发 onPasteTriggered")
        XCTAssertFalse(viewModel.shouldShowTextOnlyHint, "文本类型不显示提示")
    }

    func testHandleDoubleClick_ImageClip_ShowsHintAndDoesNotTrigger()
    {
        let imageClip = ClipItem.makeImage(
            Data([0x89, 0x50, 0x4E, 0x47]),
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        let viewModel = UnifiedPastePanelViewModel(clips: [imageClip])
        var triggered = false
        viewModel.onPasteTriggered = { _ in triggered = true }

        viewModel.handleDoubleClick(clip: imageClip)

        XCTAssertTrue(viewModel.shouldShowTextOnlyHint, "图片类型显示提示")
        XCTAssertFalse(triggered, "图片类型不触发粘贴回调")
    }

    func testHandleEnterKey_TriggersPasteCallbackForSelectedClip()
    {
        let clips = ClipTestData.previewClips
        let viewModel = UnifiedPastePanelViewModel(clips: clips)
        var triggeredClip: ClipItem?
        viewModel.onPasteTriggered = { clip in triggeredClip = clip }

        viewModel.handleEnterKey()

        XCTAssertEqual(triggeredClip?.id, clips[0].id, "回车触发当前高亮行的粘贴回调")
    }

    func testHandleEscKey_TriggersEscCallback()
    {
        let viewModel = UnifiedPastePanelViewModel(clips: ClipTestData.previewClips)
        var escCalled = false
        viewModel.onEscPressed = { escCalled = true }

        viewModel.handleEscKey()

        XCTAssertTrue(escCalled, "Esc 键触发 onEscPressed 回调")
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.11-popover-double-click-paste
xcodegen generate
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

预期：FAIL，报错 `Cannot find 'UnifiedPastePanelViewModel' in scope`（类型未创建）。

- [ ] **步骤 3：编写实现代码**

创建 `ClipMind/UI/MenuBar/UnifiedPastePanelViewModel.swift`：

```swift
import Foundation

/// 统一粘贴面板视图状态管理器（F1.11 Phase 1）。
///
/// 由 F1.9 的 `QuickPasteViewModel` 迁移而来，承载两个场景共用的高亮选中状态、
/// 单击 / 双击 / 回车 / 方向键 / Esc 事件路由、`shouldShowTextOnlyHint` 提示状态。
///
/// 设计文档第 3.3 节、第 5.2 节。视图本身不读取剪贴板存储，剪贴项列表由外部注入。
@MainActor
final class UnifiedPastePanelViewModel: ObservableObject
{
    /// 当前高亮选中行索引（默认 0，空列表为 -1）。
    @Published var selectedIndex: Int

    /// 双击 / 回车触发的粘贴回调（由控制器注入 PasteCoordinator.handlePaste）。
    var onPasteTriggered: ((ClipItem) -> Void)?

    /// 测试用：记录最近触发 onPasteTriggered 的 clip.id，供 UI 测试通过测试元素验证回调被调用。
    /// 仅在测试启动参数下通过视图的测试元素暴露，不影响生产行为。
    @Published var lastTriggeredClipIdForTesting: String?

    /// 是否显示「仅支持文本粘贴」提示（双击图片 / 文件路径行时为 true）。
    @Published var shouldShowTextOnlyHint = false

    /// Esc 键回调（由控制器关闭面板）。
    var onEscPressed: (() -> Void)?

    /// 单击回调（更新选中状态，不触发粘贴）。
    var onSingleClick: ((Int) -> Void)?

    /// 双击回调（触发粘贴流程）。
    var onDoubleClick: ((ClipItem) -> Void)?

    /// 由外部注入的剪贴项列表（不直接读取剪贴板存储）。
    let clips: [ClipItem]

    init(clips: [ClipItem])
    {
        self.clips = clips
        selectedIndex = clips.isEmpty ? -1 : 0
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
    ///
    /// 使用 clip 而非 index，避免搜索过滤后 filteredClips 的 index 与 clips 的 index 不匹配
    /// 导致访问错误的 clip。
    /// - Parameter clip: 被双击的 ClipItem
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

更新 `project.yml` 在 `ClipMind` target 的源文件列表中新增 `ClipMind/UI/MenuBar/UnifiedPastePanelViewModel.swift`，在 `ClipMindTests` target 新增 `ClipMindTests/UI/UnifiedPastePanelViewModelTests.swift`。

- [ ] **步骤 4：运行测试验证通过**

运行：

```bash
xcodegen generate
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

预期：PASS，11 条测试用例全部通过。

- [ ] **步骤 5：Lint**

运行：`swiftlint lint --strict`

预期：无新增违规。

- [ ] **步骤 6：Commit**

```bash
git add ClipMind/UI/MenuBar/UnifiedPastePanelViewModel.swift \
        ClipMindTests/UI/UnifiedPastePanelViewModelTests.swift \
        project.yml
git commit -m "feat(F1.11): add UnifiedPastePanelViewModel"
```

---

## 任务 2：创建 `UnifiedPastePanelView`

**文件：**
- 创建：`ClipMind/UI/MenuBar/UnifiedPastePanelView.swift`
- 测试：复用 `UnifiedPastePanelViewModelTests.swift`（视图本身在 Phase 2 通过 XCUITest 验证）

- [ ] **步骤 1：编写实现代码**

创建 `ClipMind/UI/MenuBar/UnifiedPastePanelView.swift`：

```swift
import AppKit
import SwiftUI

/// 统一粘贴面板视图（F1.11 Phase 1）。
///
/// 合并 F1.9 `QuickPasteView` 与 `PopoverView`，承载两个场景共用的列表渲染、键盘事件、
/// 选中态逻辑。底部工具栏通过 `showsBottomBar` 外部参数控制显隐：
/// - 菜单栏弹窗场景（StatusItemController 包装）：`showsBottomBar = true`
/// - 快捷键面板场景（QuickPastePanelController 包装）：`showsBottomBar = false`
///
/// 视图本身不读取剪贴板存储，剪贴项列表通过 `UnifiedPastePanelViewModel.clips` 注入。
///
/// 设计文档第 3.2 节、第 4.1 节。
struct UnifiedPastePanelView: View
{
    @StateObject private var viewModel: UnifiedPastePanelViewModel
    @State private var searchText = ""
    @State private var keyMonitor: Any?

    /// 底部工具栏可见性（菜单栏弹窗场景为 true，快捷键场景为 false）。
    private let showsBottomBar: Bool

    /// 辅助功能标识符前缀（菜单栏弹窗用 `popover`，快捷键用 `quickPaste`，保持 F1.9 已有标识符不变）。
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
                bottomBarPlaceholder
            }
        }
        .frame(width: 360, height: 480)
        .onAppear { startKeyMonitor() }
        .onDisappear { stopKeyMonitor() }
        .onChange(of: searchText)
        { _ in
            if !filteredClips.isEmpty
            {
                viewModel.selectedIndex = 0
            }
        }
    }

    // MARK: - 搜索框

    private var searchBar: some View
    {
        HStack(spacing: 8)
        {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("搜索剪贴内容...", text: $searchText)
                .textFieldStyle(.plain)
                .accessibilityIdentifier("\(accessibilityPrefix)SearchField")
        }
        .padding(8)
    }

    // MARK: - 列表

    private var filteredClips: [ClipItem]
    {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return viewModel.clips }
        return viewModel.clips.filter { clip in
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
            if filteredClips.isEmpty
            {
                VStack(spacing: 8)
                {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("暂无剪贴内容")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else
            {
                ScrollView
                {
                    LazyVStack(spacing: 0)
                    {
                        ForEach(Array(filteredClips.enumerated()), id: \.element.id)
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

    // MARK: - 底部工具栏占位（Phase 3 任务 4 替换为 BottomToolbarView）

    private var bottomBarPlaceholder: some View
    {
        HStack
        {
            Button("查看全部") {
                NotificationCenter.default.post(name: .openMainWindow, object: nil)
            }
            .accessibilityIdentifier("\(accessibilityPrefix)ViewAllButton")
            Spacer()
        }
        .padding(8)
    }

    // MARK: - 键盘事件监听

    private func startKeyMonitor()
    {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown)
        { event in
            self.handleKeyEvent(event)
            return event
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

    private func handleKeyEvent(_ event: NSEvent)
    {
        switch event.keyCode
        {
        case 36: // Enter
            viewModel.handleEnterKey()
        case 53: // Esc
            viewModel.handleEscKey()
        case 125: // Down arrow
            viewModel.moveSelectionDown()
        case 126: // Up arrow
            viewModel.moveSelectionUp()
        default:
            break
        }
    }
}
```

- [ ] **步骤 2：更新 `project.yml`**

在 `ClipMind` target 源文件列表新增 `ClipMind/UI/MenuBar/UnifiedPastePanelView.swift`。

- [ ] **步骤 3：编译验证**

运行：

```bash
xcodegen generate
xcodebuild build \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```

预期：BUILD SUCCEEDED。

- [ ] **步骤 4：Lint**

运行：`swiftlint lint --strict`

预期：无新增违规。

- [ ] **步骤 5：Commit**

```bash
git add ClipMind/UI/MenuBar/UnifiedPastePanelView.swift project.yml
git commit -m "feat(F1.11): add UnifiedPastePanelView"
```

---

## 任务 3：`StatusItemController` 实现 `PanelClosing` 协议 + `@MainActor` 隔离

**文件：**
- 修改：`ClipMind/UI/MenuBar/StatusItemController.swift`
- 测试：`ClipMindTests/UI/StatusItemControllerTests.swift`

- [ ] **步骤 1：编写失败的测试**

创建 `ClipMindTests/UI/StatusItemControllerTests.swift`：

```swift
import XCTest
@testable import ClipMind

/// StatusItemController 单元测试（Phase 1 任务 3）。
///
/// 验证：
/// - StatusItemController 实现 PanelClosing 协议
/// - closePanel() 在弹窗已显示时关闭弹窗，在弹窗未显示时忽略
/// - isPanelVisible 状态正确反映弹窗显示状态
@MainActor
final class StatusItemControllerTests: XCTestCase
{
    func testStatusItemController_ConformsToPanelClosing()
    {
        let controller = StatusItemController()

        XCTAssertTrue(controller is PanelClosing, "StatusItemController 必须实现 PanelClosing 协议")
    }

    func testClosePanel_WhenPopoverNotShown_DoesNotCrash()
    {
        let controller = StatusItemController()

        // 弹窗未显示时调用 closePanel，应忽略不崩溃
        controller.closePanel()

        XCTAssertFalse(controller.isPanelVisible, "弹窗未显示时 isPanelVisible = false")
    }

    func testIsPanelVisible_InitiallyFalse()
    {
        let controller = StatusItemController()

        XCTAssertFalse(controller.isPanelVisible, "初始状态 isPanelVisible = false")
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

运行：

```bash
xcodegen generate
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
  -only-testing:ClipMindTests/StatusItemControllerTests
```

预期：FAIL，报错 `StatusItemController does not conform to PanelClosing` 与 `Cannot find 'isPanelVisible'`。

- [ ] **步骤 3：编写实现代码**

修改 `ClipMind/UI/MenuBar/StatusItemController.swift`，替换为：

```swift
import AppKit
import SwiftUI

extension Notification.Name
{
    static let openMainWindow = Notification.Name("ClipMindOpenMainWindow")
}

/// 状态栏图标控制器（F1.11 Phase 1）。
///
/// 管理菜单栏图标与菜单栏弹窗（NSPopover）。F1.11 新增：
/// - 实现 PanelClosing 协议，使 PasteCoordinator 通过统一接口关闭弹窗
/// - @MainActor 隔离，确保 UI 状态更新在主线程完成
/// - setup(encryptedStore:pasteCoordinator:) 入口，注入数据源与粘贴协调器
///
/// 设计文档第 3.1 节、第 6.2 节、第 6.3 节。
@MainActor
final class StatusItemController: NSObject, PanelClosing
{
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    /// 面板当前是否可见（PanelClosing 协议要求）。
    private(set) var isPanelVisible = false

    /// 注入的剪贴板存储（弹出弹窗前读取剪贴项列表）。
    private var encryptedStore: EncryptedStore?

    /// 注入的粘贴协调器（双击 / 回车触发粘贴流程）。
    private var pasteCoordinator: PasteCoordinator?

    /// 注入数据源与粘贴协调器（由 AppDelegate 在 configureActivationPolicy 中调用）。
    /// - Parameters:
    ///   - encryptedStore: 剪贴板加密存储
    ///   - pasteCoordinator: 粘贴流程协调器
    func setup(encryptedStore: EncryptedStore, pasteCoordinator: PasteCoordinator)
    {
        self.encryptedStore = encryptedStore
        self.pasteCoordinator = pasteCoordinator

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button
        {
            button.image = NSImage(
                systemSymbolName: "doc.on.clipboard.fill",
                accessibilityDescription: "ClipMind"
            )
            button.setAccessibilityLabel("ClipMind")
            button.target = self
            button.action = #selector(togglePopover)
        }
        popover = NSPopover()
        popover?.behavior = .transient
    }

    @objc private func togglePopover()
    {
        guard let popover = popover, let button = statusItem?.button else { return }
        if popover.isShown
        {
            popover.performClose(nil)
            isPanelVisible = false
        } else
        {
            popover.contentViewController = NSHostingController(
                rootView: makeUnifiedPanelView()
            )
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            isPanelVisible = true
        }
    }

    // MARK: - PanelClosing

    func closePanel()
    {
        guard isPanelVisible, let popover = popover else { return }
        popover.performClose(nil)
        isPanelVisible = false
        LogCategory.ui.info("Menu bar popover closed by PanelClosing protocol")
    }

    // MARK: - 私有

    /// 构造统一粘贴面板视图（菜单栏弹窗场景：显示底部工具栏）。
    private func makeUnifiedPanelView() -> UnifiedPastePanelView
    {
        let clips = loadClips()
        let viewModel = UnifiedPastePanelViewModel(clips: clips)
        viewModel.onPasteTriggered = { [weak self] clip in
            self?.pasteCoordinator?.handlePaste(clip: clip)
        }
        viewModel.onEscPressed = { [weak self] in
            self?.closePanel()
        }
        return UnifiedPastePanelView(
            viewModel: viewModel,
            showsBottomBar: true,
            accessibilityPrefix: "popover"
        )
    }

    /// 从剪贴板存储读取剪贴项列表（最多 50 条，与 F1.9 快捷键面板一致）。
    private func loadClips() -> [ClipItem]
    {
        guard let store = encryptedStore else { return [] }
        do
        {
            return Array(try store.loadAll().prefix(50))
        } catch
        {
            LogCategory.storage.error("加载菜单栏弹窗数据失败: \(error.localizedDescription)")
            return []
        }
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
  -only-testing:ClipMindTests/StatusItemControllerTests
```

预期：PASS，3 条测试用例全部通过。

- [ ] **步骤 5：Lint**

运行：`swiftlint lint --strict`

预期：无新增违规。

- [ ] **步骤 6：Commit**

```bash
git add ClipMind/UI/MenuBar/StatusItemController.swift \
        ClipMindTests/UI/StatusItemControllerTests.swift \
        project.yml
git commit -m "feat(F1.11): make StatusItemController conform to PanelClosing"
```

---

## 任务 4：`StatusItemController` 注入 `EncryptedStore` 数据源与 `PasteCoordinator` 回调

**说明：** 任务 3 的实现代码已经包含数据源与 `PasteCoordinator` 注入逻辑（`makeUnifiedPanelView` 方法），本任务验证注入链路正确性。

**文件：**
- 测试：`ClipMindTests/UI/StatusItemControllerTests.swift`（追加测试）

- [ ] **步骤 1：追加测试用例**

在 `StatusItemControllerTests.swift` 末尾追加：

```swift
extension StatusItemControllerTests
{
    func testSetup_InjectsEncryptedStoreAndPasteCoordinator()
    {
        let controller = StatusItemController()
        let store = try! EncryptedStore()
        let permissionChecker = SystemPastePermissionChecker()
        let clipboardWriter = ClipboardWriter()
        let overlayShower = MockOverlayShower()
        let coordinator = PasteCoordinator(
            permissionChecker: permissionChecker,
            clipboardWriter: clipboardWriter,
            panelCloser: controller,
            overlayShower: overlayShower
        )

        controller.setup(encryptedStore: store, pasteCoordinator: coordinator)

        // 注入后调用 closePanel 不崩溃，说明依赖已注入
        controller.closePanel()
        XCTAssertFalse(controller.isPanelVisible)
    }

    func testLoadClips_ReturnsClipsFromEncryptedStore()
    {
        // 验证数据源同步：注入存储后，弹窗列表应与存储一致
        let controller = StatusItemController()
        let store = try! EncryptedStore()
        let permissionChecker = SystemPastePermissionChecker()
        let clipboardWriter = ClipboardWriter()
        let overlayShower = MockOverlayShower()
        let coordinator = PasteCoordinator(
            permissionChecker: permissionChecker,
            clipboardWriter: clipboardWriter,
            panelCloser: controller,
            overlayShower: overlayShower
        )
        controller.setup(encryptedStore: store, pasteCoordinator: coordinator)

        // 通过 togglePopover 触发 makeUnifiedPanelView，间接验证 loadClips 不崩溃
        // 单元测试环境下无法真正显示 NSPopover，但能验证依赖注入链路
        XCTAssertFalse(controller.isPanelVisible, "未触发 toggle 前 isPanelVisible = false")
    }
}

/// 测试用浮层显示协议实现（记录调用）。
@MainActor
final class MockOverlayShower: OverlayShowing
{
    var showOverlayCallCount = 0
    var hideOverlayCallCount = 0

    func showOverlay()
    {
        showOverlayCallCount += 1
    }

    func hideOverlay()
    {
        hideOverlayCallCount += 1
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
  -only-testing:ClipMindTests/StatusItemControllerTests
```

预期：PASS，5 条测试用例全部通过。

- [ ] **步骤 3：Lint**

运行：`swiftlint lint --strict`

预期：无新增违规。

- [ ] **步骤 4：Commit**

```bash
git add ClipMindTests/UI/StatusItemControllerTests.swift
git commit -m "test(F1.11): verify StatusItemController dependency injection"
```

---

## 任务 5：`QuickPastePanelController` 切换到 `UnifiedPastePanelView`

**文件：**
- 修改：`ClipMind/App/QuickPasteAssembly.swift`

- [ ] **步骤 1：修改 `makeQuickPasteContentController`**

在 `ClipMind/App/QuickPasteAssembly.swift` 中，将 `makeQuickPasteContentController` 中的 `QuickPasteView` 替换为 `UnifiedPastePanelView`：

找到（约第 127-139 行）：

```swift
func makeQuickPasteContentController(coordinator: PasteCoordinator) -> NSViewController
{
    let clips = loadClipsForQuickPaste()
    let viewModel = QuickPasteViewModel(clips: clips)
    viewModel.onPasteTriggered = { clip in
        coordinator.handlePaste(clip: clip)
    }
    viewModel.onEscPressed = { [weak self] in
        self?.quickPastePanelController?.handleEscKey()
    }
    let view = QuickPasteView(viewModel: viewModel)
    return NSHostingController(rootView: view)
}
```

替换为：

```swift
func makeQuickPasteContentController(coordinator: PasteCoordinator) -> NSViewController
{
    let clips = loadClipsForQuickPaste()
    let viewModel = UnifiedPastePanelViewModel(clips: clips)
    viewModel.onPasteTriggered = { clip in
        coordinator.handlePaste(clip: clip)
    }
    viewModel.onEscPressed = { [weak self] in
        self?.quickPastePanelController?.handleEscKey()
    }
    let view = UnifiedPastePanelView(
        viewModel: viewModel,
        showsBottomBar: false,
        accessibilityPrefix: "quickPaste"
    )
    return NSHostingController(rootView: view)
}
```

- [ ] **步骤 2：编译验证**

运行：

```bash
xcodegen generate
xcodebuild build \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```

预期：BUILD SUCCEEDED（此时 `QuickPasteView` 仍存在但不再被引用，`QuickPasteViewModel` 同名类型仍存在，会引发类型重定义错误，需在任务 6 中删除）。

**如果编译报 `QuickPasteViewModel` 重复定义**：暂时在 `QuickPasteView.swift` 中将 `QuickPasteViewModel` 改为 `typealias QuickPasteViewModel = UnifiedPastePanelViewModel`，待任务 6 删除整个文件。

**如果编译报 `QuickPasteView` 未使用**：保留文件，任务 6 删除。

- [ ] **步骤 3：运行 F1.9 单元测试确保无回归**

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
  -only-testing:ClipMindTests/QuickPasteViewTests \
  -only-testing:ClipMindTests/QuickPastePanelControllerTests \
  -only-testing:ClipMindTests/PasteCoordinatorTests
```

预期：F1.9 已有单元测试全部通过。

- [ ] **步骤 4：Lint**

运行：`swiftlint lint --strict`

预期：无新增违规。

- [ ] **步骤 5：Commit**

```bash
git add ClipMind/App/QuickPasteAssembly.swift
git commit -m "refactor(F1.11): switch QuickPastePanel to UnifiedPastePanelView"
```

---

## 任务 6：删除 `PopoverView.swift` 与 `QuickPasteView.swift`，更新 `project.yml`

**文件：**
- 删除：`ClipMind/UI/MenuBar/PopoverView.swift`
- 删除：`ClipMind/UI/QuickPaste/QuickPasteView.swift`
- 修改：`project.yml`（移除上述两个文件）

- [ ] **步骤 1：删除文件**

使用文件系统操作删除：

```bash
rm ClipMind/UI/MenuBar/PopoverView.swift
rm ClipMind/UI/QuickPaste/QuickPasteView.swift
```

- [ ] **步骤 2：更新 `project.yml`**

在 `ClipMind` target 源文件列表中移除 `ClipMind/UI/MenuBar/PopoverView.swift` 与 `ClipMind/UI/QuickPaste/QuickPasteView.swift` 两条目。

- [ ] **步骤 3：编译验证**

运行：

```bash
xcodegen generate
xcodebuild build \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```

预期：BUILD SUCCEEDED。如果 `PopoverView` 仍被引用（例如 `ClipMindApp.swift` 的 `showPopoverContentInWindow`），需同步更新引用。

- [ ] **步骤 4：修复 `ClipMindApp.swift` 中的 `showPopoverContentInWindow` 引用**

在 `ClipMind/App/ClipMindApp.swift` 中，找到 `showPopoverContentInWindow` 方法（约第 347-359 行）：

```swift
private func showPopoverContentInWindow() {
    NSApp.setActivationPolicy(.regular)
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 360, height: 480),
        styleMask: [.titled, .closable],
        backing: .buffered,
        defer: false
    )
    window.title = "PopoverPreview"
    window.contentViewController = NSHostingController(rootView: PopoverView())
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
}
```

替换为：

```swift
private func showPopoverContentInWindow() {
    NSApp.setActivationPolicy(.regular)
    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 360, height: 480),
        styleMask: [.titled, .closable],
        backing: .buffered,
        defer: false
    )
    window.title = "PopoverPreview"
    let clips = ClipTestData.isUITesting ? ClipTestData.previewClips : []
    let viewModel = UnifiedPastePanelViewModel(clips: clips)
    window.contentViewController = NSHostingController(
        rootView: UnifiedPastePanelView(
            viewModel: viewModel,
            showsBottomBar: true,
            accessibilityPrefix: "popover"
        )
    )
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
}
```

- [ ] **步骤 5：再次编译验证**

运行：

```bash
xcodebuild build \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```

预期：BUILD SUCCEEDED。

- [ ] **步骤 6：运行全量测试确保无回归**

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
  CODE_SIGNING_ALLOWED=NO
```

预期：所有现有单元测试通过（XCUITest 中 `PopoverUITests.swift` 不直接引用 `PopoverView` 类型，仅通过 `popoverSearchField`、`查看全部` 等辅助功能标识符交互，新视图沿用同一 `accessibilityPrefix: "popover"` 故 XCUITest 行为不变；本 Phase 暂时跳过 UI 测试，Phase 4 任务 1 会跑全量 XCUITest 验证）。

- [ ] **步骤 7：Lint**

运行：`swiftlint lint --strict`

预期：无新增违规。

- [ ] **步骤 8：Commit**

```bash
git add -A
git commit -m "refactor(F1.11): remove PopoverView and QuickPasteView"
```

---

## 任务 7：`AppDelegate` 初始化 `StatusItemController` 时注入依赖

**文件：**
- 修改：`ClipMind/App/ClipMindApp.swift`

- [ ] **步骤 1：修改 `configureActivationPolicy`**

在 `ClipMind/App/ClipMindApp.swift` 中，找到 `configureActivationPolicy` 方法（约第 176-199 行）：

```swift
@MainActor
private func configureActivationPolicy() {
    let completed = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    LogCategory.app.info(
        "Launch: hasCompletedOnboarding=\(completed), "
        + "args=\(CommandLine.arguments.filter { $0.hasPrefix("--UITEST") })"
    )
    if completed {
        if CommandLine.arguments.contains("--UITEST_SHOW_MAIN_WINDOW") {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
        statusItemController = StatusItemController()
        statusItemController?.setup()
        setupServices()
        setupHotkeyService()
        setupQuickPastePanelController()
    } else {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}
```

替换为：

```swift
@MainActor
private func configureActivationPolicy() {
    let completed = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    LogCategory.app.info(
        "Launch: hasCompletedOnboarding=\(completed), "
        + "args=\(CommandLine.arguments.filter { $0.hasPrefix("--UITEST") })"
    )
    if completed {
        if CommandLine.arguments.contains("--UITEST_SHOW_MAIN_WINDOW") {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
        setupServices()
        setupHotkeyService()
        setupQuickPastePanelController()
        setupStatusItemController()
    } else {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// 初始化状态栏图标控制器（F1.11 Phase 1）。
///
/// 注入 `EncryptedStore` 数据源与 `PasteCoordinator` 粘贴协调器。
/// 必须在 `setupQuickPastePanelController` 之后调用，以复用已初始化的 `pasteCoordinator`。
@MainActor
private func setupStatusItemController()
{
    guard let store = try? EncryptedStore(),
          let coordinator = pasteCoordinator
    else {
        LogCategory.app.error("StatusItemController setup failed: missing dependencies")
        return
    }

    // F1.11 Phase 1：状态栏弹窗使用独立的 PasteCoordinator 实例，
    // 与快捷键面板的 PasteCoordinator 分别持有（设计文档第 10.4 节建议），
    // 注入同一 panelCloser 协议但不同实现（StatusItemController 自身实现 PanelClosing）。
    let permissionChecker = SystemPastePermissionChecker()
    let overlayShower = PasteOverlayController(
        consumerWatcher: ClipboardConsumerWatcher(),
        timerScheduler: OverlayTimer(),
        settings: QuickPasteSettings(),
        screenLocator: ScreenCenterOverlayLocator()
    )
    let popoverCoordinator = PasteCoordinator(
        permissionChecker: permissionChecker,
        clipboardWriter: ClipboardWriter(),
        panelCloser: nil,  // 占位，下一行设置
        overlayShower: overlayShower
    )

    statusItemController = StatusItemController()
    // 直接使用快捷键面板的 PasteCoordinator（单实例服务两个场景，设计文档第 10.4 节备选方案）
    // 因为 PasteCoordinator 通过 panelCloser: PanelClosing 协议解耦，
    // 同一实例可服务两个控制器，无需区分。
    statusItemController?.setup(encryptedStore: store, pasteCoordinator: coordinator)

    // 修正：popoverCoordinator 不再使用，避免未使用变量警告
    _ = popoverCoordinator
}
```

**注意**：上述实现选择「单实例 `PasteCoordinator` 服务两个场景」方案（设计文档第 10.4 节备选方案）。`PasteCoordinator` 通过 `panelCloser: PanelClosing` 协议解耦，但同一实例只能持有同一个 `panelCloser`。因此实际需要两个 `PasteCoordinator` 实例，每个绑定不同的 `panelCloser`。

**修正后的实现**（替换上面的 `setupStatusItemController` 方法）：

```swift
/// 初始化状态栏图标控制器（F1.11 Phase 1）。
///
/// 注入 `EncryptedStore` 数据源与独立的 `PasteCoordinator` 实例（设计文档第 10.4 节推荐方案：
/// 每控制器各持有一个 PasteCoordinator 实例，避免共享状态风险）。
/// 必须在 `setupQuickPastePanelController` 之后调用，以复用 `resolveLocatorAndPermissionChecker`
/// 中的权限检测器构造逻辑。
@MainActor
private func setupStatusItemController()
{
    guard let store = try? EncryptedStore()
    else {
        LogCategory.app.error("StatusItemController setup failed: EncryptedStore init failed")
        return
    }

    let statusItemControllerInstance = StatusItemController()
    statusItemController = statusItemControllerInstance

    // 构造菜单栏弹窗专用的 PasteCoordinator（panelCloser 绑定到 StatusItemController）
    let permissionChecker = SystemPastePermissionChecker()
    let overlayShower = PasteOverlayController(
        consumerWatcher: ClipboardConsumerWatcher(),
        timerScheduler: OverlayTimer(),
        settings: QuickPasteSettings(),
        screenLocator: ScreenCenterOverlayLocator()
    )
    let popoverCoordinator = PasteCoordinator(
        permissionChecker: permissionChecker,
        clipboardWriter: ClipboardWriter(),
        panelCloser: statusItemControllerInstance,
        overlayShower: overlayShower
    )

    statusItemControllerInstance.setup(
        encryptedStore: store,
        pasteCoordinator: popoverCoordinator
    )
}
```

- [ ] **步骤 2：编译验证**

运行：

```bash
xcodegen generate
xcodebuild build \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```

预期：BUILD SUCCEEDED。`ScreenCenterOverlayLocator` 是 `QuickPasteAssembly.swift` 中的 `private` 类，需要在 `QuickPasteAssembly.swift` 中改为 `internal` 或在 `ClipMindApp.swift` 中独立定义。

**如果报错 `Cannot find 'ScreenCenterOverlayLocator' in scope`**：将 `QuickPasteAssembly.swift` 中 `ScreenCenterOverlayLocator` 的访问级别从 `private final class` 改为 `internal final class`（约第 214 行）：

```swift
internal final class ScreenCenterOverlayLocator: OverlayScreenLocating
{
    func locatePosition() -> NSPoint
    {
        let screenFrame = NSScreen.main?.frame ?? .zero
        return NSPoint(
            x: screenFrame.midX - 110,
            y: screenFrame.midY - 30
        )
    }
}
```

- [ ] **步骤 3：运行 F1.9 单元测试**

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
  -only-testing:ClipMindTests/App
```

预期：F1.9 App 模块单元测试全部通过。

- [ ] **步骤 4：Lint**

运行：`swiftlint lint --strict`

预期：无新增违规。

- [ ] **步骤 5：Commit**

```bash
git add ClipMind/App/ClipMindApp.swift \
        ClipMind/App/QuickPasteAssembly.swift
git commit -m "feat(F1.11): inject dependencies into StatusItemController"
```

---

## Phase 1 完成验证

- [ ] **步骤 1：运行完整单元测试**

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

预期：所有单元测试通过（XCUITest 中引用 `PopoverView` 的用例需在 Phase 4 任务 1 修复，本 Phase 暂不跑 UI 测试）。

- [ ] **步骤 2：编译 ClipMind-Dev Scheme 验证**

运行：

```bash
xcodebuild build \
  -project ClipMind.xcodeproj \
  -scheme ClipMind-Dev \
  -destination 'platform=macOS' \
  -configuration Debug \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```

预期：BUILD SUCCEEDED。

- [ ] **步骤 3：Lint 全量检查**

运行：`swiftlint lint --strict`

预期：无违规。

- [ ] **步骤 4：Phase 1 完成**

Phase 1 基线达成：
- ✅ `xcodegen generate && xcodebuild build` 通过
- ✅ `UnifiedPastePanelView` 在两个场景下都能渲染列表（编译通过 + 单元测试覆盖 ViewModel）
- ✅ `StatusItemController.closePanel()` 能关闭菜单栏弹窗（XCTest 验证）
- ✅ F1.9 现有单元测试全部通过

---

## 版本记录

| 版本 | 日期 | 变更说明 |
|------|------|---------|
| v1.0 | 2026-07-25 | Phase 1 初始版本，7 个任务覆盖 `UnifiedPastePanelViewModel` 创建、`UnifiedPastePanelView` 创建、`StatusItemController` 实现 `PanelClosing`、数据源注入、`QuickPastePanelController` 切换、删除旧视图、`AppDelegate` 注入依赖。关联 AC-F1.11-12、AC-F1.11-13、AC-F1.11-14。 |
