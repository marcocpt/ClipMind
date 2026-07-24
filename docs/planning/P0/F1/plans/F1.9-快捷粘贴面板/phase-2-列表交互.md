> 最后更新：2026-07-23 | 版本：v1.1

# Phase 2：列表交互

> **面向 AI 代理的工作者：** 本 Phase 在 Phase 1 的面板基础上接入列表行交互。使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现。步骤使用复选框（`- [ ]`）语法跟踪进度。前置条件：Phase 1 全部测试通过。

## 目标

让快速粘贴面板的列表行支持完整的键盘+鼠标交互：单击高亮选中、双击触发粘贴回调、方向键上下移动高亮、回车键触发粘贴（等同双击）、图片/文件路径类型双击显示"仅支持文本粘贴"提示且不关闭面板。同时修改 `ClipRowView` 增加 `isSelected` 高亮视觉与可选回调，**不影响菜单栏 popover 的现有行为**（菜单栏 popover 不传回调即不触发新交互）。

## 范围

- `ClipRowView` 新增 `isSelected: Bool` 参数（高亮视觉：蓝色边框 + 浅蓝背景）+ `onSingleClick` / `onDoubleClick` 可选回调
- `QuickPasteViewModel` 接入 `onDoubleClick` 回调（触发粘贴流程，Phase 3 接入 PasteCoordinator）
- `QuickPasteView` 列表行接入双击手势 + 单击选中 + `isSelected` 视觉
- `QuickPasteView` 双击图片/文件路径类型行时显示"仅支持文本粘贴"行内提示，不关闭面板
- 单元测试 8 条 + UI 测试 5 条（覆盖 AC-F1.9-4, 5, 11）

## 非目标

- 不实现真实的粘贴流程（Phase 3 接入 PasteCoordinator）
- 不实现剪贴板写入（Phase 3）
- 不实现降级浮层（Phase 3）
- 不实现辅助功能权限检测（Phase 4）
- 不修改菜单栏 popover 的 `PopoverView`（菜单栏 popover 不传 `isSelected` 与回调，保持原有行为）
- 不实现多选批量粘贴（明确不做，见需求文档 9.3）

## 涉及文件和职责

### 修改文件（3 个）

| 文件 | 职责变更 |
|------|---------|
| `ClipMind/UI/MenuBar/ClipRowView.swift` | 新增 `isSelected: Bool = false` 参数 + `onSingleClick` / `onDoubleClick` 可选闭包；高亮视觉（蓝色边框 + 浅蓝背景）；菜单栏 popover 不传新参数即保持原有视觉 |
| `ClipMind/UI/QuickPaste/QuickPasteView.swift` | `QuickPasteViewModel` 新增 `handleDoubleClick(index:)` 方法（区分文本/图片/文件路径类型）；`QuickPasteView` 列表行接入双击手势 + `isSelected` + 行内提示状态 |
| `ClipMindTests/UI/QuickPasteViewTests.swift` | 追加 TC-F1.9-4-01/02, TC-F1.9-5-01/02, TC-F1.9-11-01/02/03 测试 |

### 新增测试文件（1 个）

| 文件 | 职责 |
|------|------|
| `ClipMindTests/UI/ClipRowViewInteractionTests.swift` | TC-F1.9-4-01, TC-F1.9-5-01（单元层验证 ClipRowView isSelected 视觉与回调触发） |

### 修改 UI 测试文件（1 个）

| 文件 | 职责变更 |
|------|---------|
| `ClipMindUITests/QuickPastePanelUITests.swift` | 追加 TC-F1.9-4-01/02, TC-F1.9-5-01/02, TC-F1.9-11-01/02/03 UI 测试 |

### 测试用例覆盖说明

- **本 Phase 覆盖**：TC-F1.9-4-01/02（单击/方向键）, TC-F1.9-5-01/02（双击/回车触发）, TC-F1.9-11-01/02/03（图片/文件路径提示）（共 7 条）
- **延后覆盖**：TC-F1.9-5-01/02 的"粘贴流程是否真正启动"需 Phase 3 接入 PasteCoordinator 后才能完整验证（Phase 2 仅验证回调被调用）

---

## 任务 1：ClipRowView 新增 isSelected 与可选回调

**文件：**
- 修改：`ClipMind/UI/MenuBar/ClipRowView.swift`
- 测试：`ClipMindTests/UI/ClipRowViewInteractionTests.swift`（新增）

### 步骤

- [ ] **1.1 编写失败的测试**

创建 `ClipMindTests/UI/ClipRowViewInteractionTests.swift`：

```swift
@testable import ClipMind
import XCTest

final class ClipRowViewInteractionTests: XCTestCase
{
    // MARK: - TC-F1.9-4-01 单击列表行高亮选中（单元层验证 isSelected 状态）

    func testClipRowView_AcceptsIsSelectedParameter_True()
    {
        let clip = ClipItem.makeText(
            "测试",
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        let row = ClipRowView(clip: clip, isSelected: true)
        XCTAssertTrue(row.isSelected, "isSelected=true 应被接受")
    }

    func testClipRowView_AcceptsIsSelectedParameter_False_Default()
    {
        let clip = ClipItem.makeText(
            "测试",
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        let row = ClipRowView(clip: clip)
        XCTAssertFalse(row.isSelected, "不传 isSelected 时默认 false")
    }

    // MARK: - TC-F1.9-5-01 双击触发回调（单元层验证闭包可注入）

    func testClipRowView_AcceptsOnDoubleClickClosure()
    {
        let clip = ClipItem.makeText(
            "测试",
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        var triggeredClip: ClipItem?
        let row = ClipRowView(
            clip: clip,
            onDoubleClick: { clip in triggeredClip = clip }
        )
        row.onDoubleClick?(clip)
        XCTAssertNotNil(triggeredClip, "双击回调应可被触发")
        XCTAssertEqual(triggeredClip?.id, clip.id)
    }

    // MARK: - 菜单栏 popover 兼容性：不传回调时不触发

    func testClipRowView_NoCallbacks_DoesNotCrash()
    {
        let clip = ClipItem.makeText(
            "测试",
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        let row = ClipRowView(clip: clip)
        XCTAssertNil(row.onSingleClick, "不传 onSingleClick 时应为 nil")
        XCTAssertNil(row.onDoubleClick, "不传 onDoubleClick 时应为 nil")
    }
}
```

- [ ] **1.2 运行测试验证失败**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.9-quick-paste-panel
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindTests/ClipRowViewInteractionTests \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：编译失败，报错 `extra argument 'isSelected' in call` 或 `value of type 'ClipRowView' has no member 'onDoubleClick'`。

- [ ] **1.3 编写最少实现代码**

将 `ClipMind/UI/MenuBar/ClipRowView.swift` 整个文件替换为：

```swift
import SwiftUI

struct ClipRowView: View
{
    let clip: ClipItem

    /// 是否高亮选中（F1.9 快速粘贴面板使用，菜单栏 popover 不传默认 false）。
    var isSelected: Bool = false

    /// 单击回调（F1.9 快速粘贴面板使用，菜单栏 popover 不传即 nil）。
    var onSingleClick: (() -> Void)?

    /// 双击回调（F1.9 快速粘贴面板使用，菜单栏 popover 不传即 nil）。
    var onDoubleClick: (() -> Void)?

    var body: some View
    {
        VStack(alignment: .leading, spacing: 6)
        {
            HStack(spacing: 8)
            {
                TypeTagView(contentType: clip.contentType)
                Spacer()
            }
            Text(contentPreview)
                .font(.system(size: 13))
                .lineLimit(2)
                .foregroundColor(.primary)
            HStack(spacing: 8)
            {
                Text(clip.sourceAppName)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(timeAgo)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(backgroundColor)
        .overlay(borderOverlay)
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture(count: 1)
        {
            onSingleClick?()
        }
        .onTapGesture(count: 2)
        {
            onDoubleClick?()
        }
    }

    private var backgroundColor: Color
    {
        isSelected ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.15)
    }

    private var borderOverlay: some View
    {
        Group
        {
            if isSelected
            {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor, lineWidth: 2)
            }
            else
            {
                Color.clear
            }
        }
    }

    private var contentPreview: String
    {
        switch clip.content
        {
        case .text(let text):
            return text
        case .image:
            return "[图片]"
        case .filePath(let urls):
            return urls.map(\.lastPathComponent).joined(separator: ", ")
        }
    }

    private var timeAgo: String
    {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: clip.timestamp, relativeTo: Date())
    }
}
```

> **兼容性说明**：菜单栏 popover 的 `PopoverView` 第 59 行调用 `ClipRowView(clip: clip)`，不传 `isSelected` / `onSingleClick` / `onDoubleClick`，使用默认值 `false` / `nil` / `nil`，行为与原版完全一致（无高亮、无回调）。F1.9 的 `QuickPasteView` 会传入这些参数。

- [ ] **1.4 运行测试验证通过**

运行同 1.2 的命令。

预期：`** TEST SUCCEEDED **`，4 个测试方法通过。

- [ ] **1.5 运行现有菜单栏 popover 测试（回归验证）**

```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindUITests/PopoverUITests \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：`** TEST SUCCEEDED **`，菜单栏 popover 测试无回归。

- [ ] **1.6 运行 SwiftLint**

```bash
swiftlint lint --strict
```

预期：零违规。

- [ ] **1.7 Commit**

```bash
git add ClipMind/UI/MenuBar/ClipRowView.swift ClipMindTests/UI/ClipRowViewInteractionTests.swift
git commit -m "feat(clip-row): add isSelected and click callbacks without breaking popover"
```

---

## 任务 2：QuickPasteViewModel 双击处理 + 类型判断

**文件：**
- 修改：`ClipMind/UI/QuickPaste/QuickPasteView.swift`（`QuickPasteViewModel` 新增双击处理）
- 测试：`ClipMindTests/UI/QuickPasteViewTests.swift`（追加测试）

### 步骤

- [ ] **2.1 编写失败的测试**

在 `ClipMindTests/UI/QuickPasteViewTests.swift` 末尾追加：

```swift
    // MARK: - TC-F1.9-5-01 双击文本行触发粘贴流程

    func testHandleDoubleClick_OnTextRow_TriggersPasteCallback()
    {
        let clips = QuickPasteViewTests.makeTextClips(count: 3)
        let viewModel = QuickPasteViewModel(clips: clips)
        var pastedClip: ClipItem?
        viewModel.onPasteTriggered = { clip in pastedClip = clip }

        viewModel.handleDoubleClick(index: 0)

        XCTAssertNotNil(pastedClip, "双击文本行应触发粘贴回调")
        XCTAssertEqual(pastedClip?.id, clips[0].id)
    }

    // MARK: - TC-F1.9-11-01 双击图片类型行显示提示不粘贴

    func testHandleDoubleClick_OnImageRow_DoesNotPaste_AndShowsHint()
    {
        let imageClip = ClipItem.makeImage(
            Data([0x89, 0x50, 0x4E, 0x47]),
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        let viewModel = QuickPasteViewModel(clips: [imageClip])
        var pasteCalled = false
        viewModel.onPasteTriggered = { _ in pasteCalled = true }

        viewModel.handleDoubleClick(index: 0)

        XCTAssertFalse(pasteCalled, "双击图片行不应触发粘贴")
        XCTAssertTrue(viewModel.shouldShowTextOnlyHint, "应显示'仅支持文本粘贴'提示")
    }

    // MARK: - TC-F1.9-11-02 双击文件路径类型行显示提示不粘贴

    func testHandleDoubleClick_OnFilePathRow_DoesNotPaste_AndShowsHint()
    {
        let filePathClip = ClipItem.makeFilePath(
            [URL(fileURLWithPath: "/tmp/test.txt")],
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        let viewModel = QuickPasteViewModel(clips: [filePathClip])
        var pasteCalled = false
        viewModel.onPasteTriggered = { _ in pasteCalled = true }

        viewModel.handleDoubleClick(index: 0)

        XCTAssertFalse(pasteCalled, "双击文件路径行不应触发粘贴")
        XCTAssertTrue(viewModel.shouldShowTextOnlyHint, "应显示'仅支持文本粘贴'提示")
    }

    // MARK: - TC-F1.9-11-03 提示后可继续操作其他行（提示状态可清除）

    func testHint_ClearsOnSelectOtherRow()
    {
        let imageClip = ClipItem.makeImage(
            Data([0x89]),
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        let textClip = ClipItem.makeText(
            "文本",
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        let viewModel = QuickPasteViewModel(clips: [imageClip, textClip])

        viewModel.handleDoubleClick(index: 0)
        XCTAssertTrue(viewModel.shouldShowTextOnlyHint)

        viewModel.selectIndex(1)
        XCTAssertFalse(viewModel.shouldShowTextOnlyHint, "选中其他行后提示应消失")
    }
```

- [ ] **2.2 运行测试验证失败**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.9-quick-paste-panel
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindTests/QuickPasteViewTests \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：编译失败，报错 `value of type 'QuickPasteViewModel' has no member 'handleDoubleClick(index:)'` 和 `'shouldShowTextOnlyHint'`。

- [ ] **2.3 编写最少实现代码**

修改 `ClipMind/UI/QuickPaste/QuickPasteView.swift` 的 `QuickPasteViewModel` 类，在 `handleEscKey()` 方法之前追加：

```swift
    /// 是否显示"仅支持文本粘贴"提示（双击图片/文件路径行时为 true）。
    @Published var shouldShowTextOnlyHint = false

    /// 双击处理：文本类型触发粘贴回调，图片/文件路径类型显示提示。
    /// - Parameter index: 被双击的行索引
    func handleDoubleClick(index: Int)
    {
        guard clips.indices.contains(index) else { return }
        let clip = clips[index]

        switch clip.content
        {
        case .text:
            shouldShowTextOnlyHint = false
            onPasteTriggered?(clip)
            // test hook：记录触发的 clip.id，供 UI 测试验证回调被调用（Phase 2 任务 5）
            lastTriggeredClipIdForTesting = clip.id
        case .image, .filePath:
            shouldShowTextOnlyHint = true
            LogCategory.ui.info("QuickPaste double-click on non-text row, showing hint")
        }
    }
```

修改 `selectIndex(_:)` 方法，在 `onSingleClick?(index)` 之前追加清除提示：

```swift
    func selectIndex(_ index: Int)
    {
        guard clips.indices.contains(index) else { return }
        selectedIndex = index
        shouldShowTextOnlyHint = false
        onSingleClick?(index)
    }
```

- [ ] **2.4 运行测试验证通过**

运行同 2.2 的命令。

预期：`** TEST SUCCEEDED **`，10 个测试方法（任务 6 的 6 个 + 任务 2 的 4 个）全部通过。

- [ ] **2.5 运行 SwiftLint**

```bash
swiftlint lint --strict
```

预期：零违规。

- [ ] **2.6 Commit**

```bash
git add ClipMind/UI/QuickPaste/QuickPasteView.swift ClipMindTests/UI/QuickPasteViewTests.swift
git commit -m "feat(quick-paste): add double-click handling with text-only hint for non-text rows"
```

---

## 任务 3：QuickPasteView 列表行接入 isSelected 与双击手势

**文件：**
- 修改：`ClipMind/UI/QuickPaste/QuickPasteView.swift`（列表行渲染逻辑）
- 测试：`ClipMindTests/UI/QuickPasteViewTests.swift`（追加集成测试）

### 步骤

- [ ] **3.1 编写失败的测试**

在 `ClipMindTests/UI/QuickPasteViewTests.swift` 末尾追加：

```swift
    // MARK: - 集成测试：双击文本行触发 onPasteTriggered（TC-F1.9-5-01 集成层）

    func testDoubleClick_OnTextRow_TriggersPasteViaViewModel()
    {
        let clips = QuickPasteViewTests.makeTextClips(count: 2)
        let viewModel = QuickPasteViewModel(clips: clips)
        var pasteCount = 0
        viewModel.onPasteTriggered = { _ in pasteCount += 1 }

        // 模拟双击第一行
        viewModel.handleDoubleClick(index: 0)
        // 模拟双击第二行
        viewModel.handleDoubleClick(index: 1)

        XCTAssertEqual(pasteCount, 2, "双击两行应触发两次粘贴回调")
    }

    // MARK: - 集成测试：双击图片行后选中其他行清除提示（TC-F1.9-11-03 集成层）

    func testHint_ClearsWhenSelectingOtherRow_AfterImageDoubleClick()
    {
        let imageClip = ClipItem.makeImage(
            Data([0x89]),
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        let textClip = ClipItem.makeText(
            "文本",
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        let viewModel = QuickPasteViewModel(clips: [imageClip, textClip])

        viewModel.handleDoubleClick(index: 0)
        XCTAssertTrue(viewModel.shouldShowTextOnlyHint)

        viewModel.selectIndex(1)
        XCTAssertFalse(viewModel.shouldShowTextOnlyHint)
        XCTAssertEqual(viewModel.selectedIndex, 1)
    }
```

- [ ] **3.2 运行测试验证失败**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.9-quick-paste-panel
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindTests/QuickPasteViewTests \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：新增的 2 个测试通过（因为任务 2 已实现 `handleDoubleClick` 与 `selectIndex` 清除提示）。任务 3 的实现代码主要是视图层接入（`ClipRowView` 传入 `isSelected` 与回调），单元测试已覆盖逻辑层。如果测试通过，说明逻辑层正确，继续实现视图层。

- [ ] **3.3 编写最少实现代码**

修改 `ClipMind/UI/QuickPaste/QuickPasteView.swift` 的 `contentList` 计算属性，把现有的 `ClipRowView(clip: clip)` 调用替换为：

```swift
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
            }
            else
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
                                onDoubleClick: { viewModel.handleDoubleClick(index: index) }
                            )
                            .accessibilityIdentifier("quickPasteRow_\(index)\(viewModel.isSelected(index: index) ? "_selected" : "")")
                            .accessibilityValue(clip.id)
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
                // 测试用元素：暴露 onPasteTriggered 触发的 clip.id（验证回调被调用，不影响视觉）
                Text(viewModel.lastTriggeredClipIdForTesting ?? "")
                    .accessibilityIdentifier("quickPasteTestTriggeredClipId")
                    .frame(width: 0, height: 0)
                    .opacity(0)
            }
        }
    }
```

> **说明**：移除任务 6 中 `QuickPasteView` 的 `.background(...)` / `.overlay(...)` / `.onTapGesture` 修饰符（这些视觉与手势现在由 `ClipRowView` 内部根据 `isSelected` / `onSingleClick` / `onDoubleClick` 处理），避免双重修饰。

- [ ] **3.4 运行测试验证通过**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.9-quick-paste-panel
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindTests/QuickPasteViewTests \
  -only-testing ClipMindTests/ClipRowViewInteractionTests \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：`** TEST SUCCEEDED **`，全部测试通过。

- [ ] **3.5 运行 SwiftLint**

```bash
swiftlint lint --strict
```

预期：零违规。

- [ ] **3.6 Commit**

```bash
git add ClipMind/UI/QuickPaste/QuickPasteView.swift ClipMindTests/UI/QuickPasteViewTests.swift
git commit -m "feat(quick-paste): wire ClipRowView isSelected and double-click into QuickPasteView"
```

---

## 任务 4：UI 测试 - 单击高亮 + 方向键导航（AC-F1.9-4）

**文件：**
- 修改：`ClipMindUITests/QuickPastePanelUITests.swift`（追加 UI 测试）

### 步骤

- [ ] **4.1 编写失败的测试**

在 `ClipMindUITests/QuickPastePanelUITests.swift` 末尾追加：

```swift
    // MARK: - TC-F1.9-4-01 单击列表行高亮选中

    func testSingleClick_OnSecondRow_HighlightsSecondRow()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREPOPULATE_SAMPLE_AND_REAL",
            "--UITEST_QUICK_PASTE_PANEL"
        ]
        app.launch()

        // 单击前：第一行高亮（quickPasteRow_0_selected），第二行未高亮（quickPasteRow_1）
        let row0Selected = app.descendants(matching: .any)["quickPasteRow_0_selected"].firstMatch
        let row1Selected = app.descendants(matching: .any)["quickPasteRow_1_selected"].firstMatch
        XCTAssertTrue(row0Selected.waitForExistence(timeout: 5), "初始第一行应高亮")
        XCTAssertFalse(row1Selected.exists, "初始第二行不应高亮")

        // 单击第二行（未高亮状态的 identifier）
        let row1 = app.descendants(matching: .any)["quickPasteRow_1"].firstMatch
        XCTAssertTrue(row1.waitForExistence(timeout: 2), "第二行应存在")
        row1.click()

        // 单击后：第二行高亮，第一行取消高亮
        XCTAssertTrue(row1Selected.waitForExistence(timeout: 2), "单击后第二行应高亮")
        XCTAssertFalse(
            app.descendants(matching: .any)["quickPasteRow_0_selected"].firstMatch.exists,
            "单击后第一行应取消高亮"
        )
    }

    // MARK: - TC-F1.9-4-02 方向键上下移动高亮

    func testArrowKeys_MoveHighlightDownAndUp()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREPOPULATE_SAMPLE_AND_REAL",
            "--UITEST_QUICK_PASTE_PANEL"
        ]
        app.launch()

        let searchField = app.textFields["quickPasteSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.click()

        // 初始：第一行高亮（quickPasteRow_0_selected）
        XCTAssertTrue(
            app.descendants(matching: .any)["quickPasteRow_0_selected"].firstMatch.exists,
            "初始第一行应高亮"
        )

        // 按下方向键 3 次（移到第四行，索引 3）
        searchField.typeKey(XCUIKeyboardKey.downArrow, modifierFlags: [])
        searchField.typeKey(XCUIKeyboardKey.downArrow, modifierFlags: [])
        searchField.typeKey(XCUIKeyboardKey.downArrow, modifierFlags: [])

        // 验证：第四行高亮（索引 3）
        XCTAssertTrue(
            app.descendants(matching: .any)["quickPasteRow_3_selected"].firstMatch.waitForExistence(timeout: 2),
            "按 3 次下方向键后第四行应高亮"
        )

        // 按上方向键 1 次（回到第三行，索引 2）
        searchField.typeKey(XCUIKeyboardKey.upArrow, modifierFlags: [])

        // 验证：第三行高亮（索引 2）
        XCTAssertTrue(
            app.descendants(matching: .any)["quickPasteRow_2_selected"].firstMatch.waitForExistence(timeout: 2),
            "按 1 次上方向键后第三行应高亮"
        )

        // 验证面板仍然存在（方向键不应关闭面板）
        XCTAssertTrue(searchField.exists, "方向键不应关闭面板")
    }
```

- [ ] **4.2 运行测试验证失败**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.9-quick-paste-panel
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindUITests/QuickPastePanelUITests/testSingleClick_OnSecondRow_HighlightsSecondRow \
  -only-testing ClipMindUITests/QuickPastePanelUITests/testArrowKeys_MoveHighlightDownAndUp \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：测试通过（因为 Phase 1 任务 6 已实现 `QuickPasteViewModel` 的方向键导航 + 任务 3 已接入 `ClipRowView.isSelected`）。如果失败，检查键盘事件监听是否在搜索框聚焦时生效。

- [ ] **4.3 运行 SwiftLint**

```bash
swiftlint lint --strict
```

预期：零违规。

- [ ] **4.4 Commit**

```bash
git add ClipMindUITests/QuickPastePanelUITests.swift
git commit -m "test(quick-paste): add UI tests for single-click highlight and arrow navigation"
```

---

## 任务 5：UI 测试 - 双击/回车触发粘贴回调（AC-F1.9-5）

**文件：**
- 修改：`ClipMindUITests/QuickPastePanelUITests.swift`（追加 UI 测试）

### 步骤

- [ ] **5.1 编写失败的测试**

在 `ClipMindUITests/QuickPastePanelUITests.swift` 末尾追加：

```swift
    // MARK: - TC-F1.9-5-01 双击文本行触发粘贴流程

    func testDoubleClick_OnTextRow_TriggersPaste()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREPOPULATE_SAMPLE_AND_REAL",
            "--UITEST_QUICK_PASTE_PANEL"
        ]
        app.launch()

        // 第一行默认高亮（identifier 带 _selected 后缀），读取其 clip.id（accessibilityValue）
        let firstRow = app.descendants(matching: .any)["quickPasteRow_0_selected"].firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5), "第一行应存在")
        let firstClipId = firstRow.value as? String

        firstRow.doubleClick()

        // Phase 2 验证回调触发；面板关闭与真实粘贴在 Phase 3/4 验证
        // test hook：双击触发 onPasteTriggered 后，viewModel.lastTriggeredClipIdForTesting 更新，
        // 通过测试元素 quickPasteTestTriggeredClipId 暴露触发的 clip.id
        let triggeredClipIdElement = app.descendants(matching: .any)["quickPasteTestTriggeredClipId"].firstMatch
        XCTAssertTrue(triggeredClipIdElement.waitForExistence(timeout: 2), "双击应触发粘贴回调")
        XCTAssertEqual(
            triggeredClipIdElement.value as? String,
            firstClipId,
            "双击应触发粘贴回调并传入正确 ClipItem"
        )
    }

    // MARK: - TC-F1.9-5-02 回车键触发粘贴流程

    func testEnterKey_TriggersPaste()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREPOPULATE_SAMPLE_AND_REAL",
            "--UITEST_QUICK_PASTE_PANEL"
        ]
        app.launch()

        // 默认高亮第一行，读取其 clip.id（accessibilityValue）
        let firstRow = app.descendants(matching: .any)["quickPasteRow_0_selected"].firstMatch
        XCTAssertTrue(firstRow.waitForExistence(timeout: 5), "第一行应存在")
        let firstClipId = firstRow.value as? String

        let searchField = app.textFields["quickPasteSearchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.click()

        // 按回车键
        searchField.typeKey(XCUIKeyboardKey.return, modifierFlags: [])

        // Phase 2 验证回调触发；面板关闭与真实粘贴在 Phase 3/4 验证
        // test hook：回车触发 onPasteTriggered 后，通过测试元素 quickPasteTestTriggeredClipId 暴露触发的 clip.id
        let triggeredClipIdElement = app.descendants(matching: .any)["quickPasteTestTriggeredClipId"].firstMatch
        XCTAssertTrue(triggeredClipIdElement.waitForExistence(timeout: 2), "回车应触发粘贴回调")
        XCTAssertEqual(
            triggeredClipIdElement.value as? String,
            firstClipId,
            "回车应触发粘贴回调并传入正确 ClipItem"
        )
    }
```

- [ ] **5.2 运行测试验证失败**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.9-quick-paste-panel
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindUITests/QuickPastePanelUITests/testDoubleClick_OnTextRow_TriggersPaste \
  -only-testing ClipMindUITests/QuickPastePanelUITests/testEnterKey_TriggersPaste \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：测试通过（Phase 2 通过 test hook 验证 `onPasteTriggered` 回调被调用并传入正确 ClipItem；面板关闭与真实粘贴在 Phase 3/4 验证）。

- [ ] **5.3 运行 SwiftLint**

```bash
swiftlint lint --strict
```

预期：零违规。

- [ ] **5.4 Commit**

```bash
git add ClipMindUITests/QuickPastePanelUITests.swift
git commit -m "test(quick-paste): add UI tests for double-click and enter key paste trigger"
```

---

## 任务 6：UI 测试 - 图片/文件路径双击提示（AC-F1.9-11）

**文件：**
- 修改：`ClipMindUITests/QuickPastePanelUITests.swift`（追加 UI 测试）

### 步骤

- [ ] **6.1 编写失败的测试**

在 `ClipMindUITests/QuickPastePanelUITests.swift` 末尾追加：

```swift
    // MARK: - TC-F1.9-11-01 双击图片类型行显示提示

    func testDoubleClick_OnImageRow_ShowsTextOnlyHint()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREPOPULATE_IMAGE_AND_FILEPATH",  // 新启动参数：预置图片+文件路径
            "--UITEST_QUICK_PASTE_PANEL"
        ]
        app.launch()

        // 找到图片行（通过 accessibilityIdentifier 后缀或类型标签）
        let imageRow = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier CONTAINS 'quickPasteRow'")
        ).firstMatch
        XCTAssertTrue(imageRow.waitForExistence(timeout: 5))

        imageRow.doubleClick()

        let hint = app.staticTexts["textOnlyHint"].firstMatch
        XCTAssertTrue(hint.waitForExistence(timeout: 2), "应显示'仅支持文本粘贴'提示")

        // 验证面板未关闭
        let searchField = app.textFields["quickPasteSearchField"]
        XCTAssertTrue(searchField.exists, "双击图片行不应关闭面板")
    }

    // MARK: - TC-F1.9-11-03 提示后可继续操作其他行

    func testHint_ClearsOnClickOtherRow()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_PREPOPULATE_IMAGE_AND_FILEPATH",
            "--UITEST_QUICK_PASTE_PANEL"
        ]
        app.launch()

        let rows = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier CONTAINS 'quickPasteRow'")
        )
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5))

        // 双击第一行（图片）显示提示
        rows.firstMatch.doubleClick()
        let hint = app.staticTexts["textOnlyHint"].firstMatch
        XCTAssertTrue(hint.waitForExistence(timeout: 2))

        // 单击第二行
        let secondRow = rows.element(boundBy: 1)
        if secondRow.exists
        {
            secondRow.click()
            let hintCleared = NSPredicate(format: "exists == NO")
            let expectation = XCTNSPredicateExpectation(
                predicate: hintCleared,
                object: hint
            )
            wait(for: [expectation], timeout: 2.0)
        }
    }
```

- [ ] **6.2 运行测试验证失败**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.9-quick-paste-panel
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindUITests/QuickPastePanelUITests/testDoubleClick_OnImageRow_ShowsTextOnlyHint \
  -only-testing ClipMindUITests/QuickPastePanelUITests/testHint_ClearsOnClickOtherRow \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：测试失败，因为 `--UITEST_PREPOPULATE_IMAGE_AND_FILEPATH` 启动参数未实现。

- [ ] **6.3 编写最少实现代码**

修改 `ClipMind/App/ClipMindApp.swift` 的 `setupQuickPastePanelController()` 方法，在 `--UITEST_QUICK_PASTE_PANEL` 分支内追加预置图片/文件路径数据的逻辑：

```swift
    /// 初始化快速粘贴面板控制器（F1.9）
    private func setupQuickPastePanelController()
    {
        let locator = ScreenCenterPanelLocator()
        quickPastePanelController = QuickPastePanelController(screenLocator: locator)

        // UI 测试启动参数：直接显示面板
        if CommandLine.arguments.contains("--UITEST_QUICK_PASTE_PANEL")
        {
            // 预置图片+文件路径数据（用于 AC-F1.9-11 UI 测试）
            if CommandLine.arguments.contains("--UITEST_PREPOPULATE_IMAGE_AND_FILEPATH")
            {
                prepopulateImageAndFilePathForTesting()
            }
            quickPastePanelController?.showPanel()
        }
    }

    /// UI 测试专用：预置图片+文件路径数据到 EncryptedStore。
    private func prepopulateImageAndFilePathForTesting()
    {
        do
        {
            let store = try EncryptedStore()
            let imageClip = ClipItem.makeImage(
                Data([0x89, 0x50, 0x4E, 0x47]),
                contentType: .other,
                sourceApp: "com.test",
                sourceAppName: "Test"
            )
            let filePathClip = ClipItem.makeFilePath(
                [URL(fileURLWithPath: "/tmp/test.txt")],
                contentType: .other,
                sourceApp: "com.test",
                sourceAppName: "Test"
            )
            let textClip = ClipItem.makeText(
                "文本内容",
                contentType: .other,
                sourceApp: "com.test",
                sourceAppName: "Test"
            )
            try store.save(imageClip)
            try store.save(filePathClip)
            try store.save(textClip)
            NotificationCenter.default.post(
                name: ClipCaptureService.clipDidUpdateNotification,
                object: nil
            )
        }
        catch
        {
            LogCategory.storage.error("预置图片/文件路径测试数据失败: \(error.localizedDescription)")
        }
    }
```

- [ ] **6.4 运行测试验证通过**

运行同 6.2 的命令。

预期：`** TEST SUCCEEDED **`，2 个 UI 测试通过。

- [ ] **6.5 运行 SwiftLint**

```bash
swiftlint lint --strict
```

预期：零违规。

- [ ] **6.6 运行 Phase 2 全量测试（回归验证）**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F1.9-quick-paste-panel
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  -only-testing ClipMindTests/QuickPasteViewTests \
  -only-testing ClipMindTests/ClipRowViewInteractionTests \
  -only-testing ClipMindUITests/QuickPastePanelUITests \
  -only-testing ClipMindUITests/PopoverUITests \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO 2>&1 | tail -30
```

预期：`** TEST SUCCEEDED **`，Phase 2 全部测试通过 + 菜单栏 popover 无回归。

- [ ] **6.7 Commit**

```bash
git add ClipMind/App/ClipMindApp.swift ClipMindUITests/QuickPastePanelUITests.swift
git commit -m "test(quick-paste): add UI tests for image/filepath hint with prepopulate arg"
```

---

## UI 证据任务

> **证据保存约定（Phase 2）**
>
> - **截图路径模板**：`docs/planning/P0/F1/screenshots/F1.9/phase2-ACx-场景描述.png`
> - **录屏路径模板**：`docs/planning/P0/F1/recordings/F1.9/phase2-ACx-场景描述.mov`
> - **保存规则**：
>   1. XCUITest 通过后，运行该测试用例时通过 `XCUIScreenshot` 附件捕获截图，保存到上述截图路径（文件名见各条目「证据保存」）。
>   2. 涉及真实环境交互的条目（标「手动补充」），发布前手动执行并录屏，保存到上述录屏路径。
>   3. 路径中 `phase2` 为 Phase 编号，`ACx` 为对应验收条件编号，`场景描述` 用中文简述场景。
>   4. 截图/录屏文件提交到仓库，作为发布前人工审查证据。

### UI-AC-F1.9-4-01：单击列表行高亮选中

**对应 AC**：AC-F1.9-4
**对应测试**：`QuickPastePanelUITests.testSingleClick_OnSecondRow_HighlightsSecondRow`
**证据方式**：XCUITest 自动化（单击第二行验证选中状态）+ 单元测试 `QuickPasteViewTests.testSelectIndex_UpdatesSelectedIndex`
**手动补充**：在真实环境验证高亮视觉（蓝色边框 + 浅蓝背景）
**证据保存**：
- 截图：`docs/planning/P0/F1/screenshots/F1.9/phase2-AC4-单击高亮.png`（XCUITest 通过后捕获）
- 录屏：`docs/planning/P0/F1/recordings/F1.9/phase2-AC4-单击高亮.mov`（手动验收高亮视觉，发布前录制）

### UI-AC-F1.9-4-02：方向键上下移动高亮

**对应 AC**：AC-F1.9-4
**对应测试**：`QuickPastePanelUITests.testArrowKeys_MoveHighlightDownAndUp`
**证据方式**：XCUITest 自动化（按方向键下面板不关闭）+ 单元测试 `QuickPasteViewTests.testMoveSelectionDown_FromFirstIndex_MovesToSecond`
**手动补充**：在真实环境验证方向键导航视觉反馈
**证据保存**：
- 截图：`docs/planning/P0/F1/screenshots/F1.9/phase2-AC4-方向键移动.png`（XCUITest 通过后捕获）
- 录屏：`docs/planning/P0/F1/recordings/F1.9/phase2-AC4-方向键移动.mov`（手动验收方向键视觉反馈，发布前录制）

### UI-AC-F1.9-11-01：双击图片类型行显示提示

**对应 AC**：AC-F1.9-11
**对应测试**：`QuickPastePanelUITests.testDoubleClick_OnImageRow_ShowsTextOnlyHint`
**证据方式**：XCUITest 自动化（双击图片行验证"仅支持文本粘贴"提示出现 + 面板未关闭）+ 单元测试 `QuickPasteViewTests.testHandleDoubleClick_OnImageRow_DoesNotPaste_AndShowsHint`
**证据保存**：
- 截图：`docs/planning/P0/F1/screenshots/F1.9/phase2-AC11-图片类型提示.png`（XCUITest 通过后捕获）

---

## 合并基线

Phase 2 完成后应满足：

1. `swiftlint lint --strict` 零违规
2. `xcodebuild test` 全量通过（Phase 2 新增测试 + Phase 1 无回归 + 菜单栏 popover 无回归）
3. `xcodebuild build` 编译成功
4. 6 个任务全部 commit
5. 文档同步：在 `docs/planning/P0/F1/historys/` 追加 `2026-07-23-F1.9-Phase2-列表交互完成.md`

**关键回归点**：菜单栏 popover 的 `PopoverUITests` 必须全通过（验证 `ClipRowView` 修改不影响菜单栏 popover）。

---

## 手动验收（发布前补充）

1. 打开快速粘贴面板，单击第二行验证高亮切换
2. 按方向键下/上验证高亮移动
3. 双击文本行验证粘贴流程触发（Phase 3 接入后真正粘贴）
4. 双击图片行验证"仅支持文本粘贴"提示出现且面板不关闭
5. 双击文件路径行验证提示出现
6. 显示提示后单击其他行验证提示消失
7. 验证菜单栏 popover 点击仍弹出原 popover（无高亮、无双击行为）

---

## 版本记录

| 版本 | 日期 | 变更说明 |
|------|------|---------|
| v1.0 | 2026-07-23 | 初始版本，Phase 2 列表交互，6 任务 36 TDD 步骤，3 UI 证据任务，覆盖 AC-F1.9-4, 5, 11 |
| v1.1 | 2026-07-23 | 修订（Fix 6/13/14/15）：handleDoubleClick test hook 记录 lastTriggeredClipIdForTesting；accessibilityIdentifier 加 _selected 后缀 + accessibilityValue；testSingleClick/testArrowKeys 改验证后缀迁移；双击/回车 UI 测试删除永真断言改用 test hook 验证回调；UI 证据任务补充证据保存路径 |
