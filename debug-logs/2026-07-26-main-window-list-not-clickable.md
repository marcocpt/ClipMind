# 主窗口列表点击无响应 Bug 修复日志

> 日期：2026-07-26
> 关联：F1.11 菜单栏弹窗双击粘贴后续 bug

## 问题描述

用户反馈：主窗口中列表不能点击了。

期望行为：在主窗口点击列表中的任意一行，详情面板应更新显示该条目的内容。

## 复现条件

- 启动 app，打开主窗口
- 列表中有剪贴条目（生产数据或 `--UITEST_PREVIEW_DATA` 注入的预览数据）
- 点击任意一行
- 详情面板不更新（保持空状态 "选择一条剪贴内容查看详情"）

## 根因调查

### 代码定位

`ClipMind/UI/MainWindow/HistoryListView.swift`:

```swift
List(clips) { clip in
    ClipRowView(clip: clip)
        .contentShape(Rectangle())
        .onTapGesture { selectedClip = clip }
}
.accessibilityIdentifier("historyList")
```

`ClipMind/UI/MenuBar/ClipRowView.swift` 内部已自带手势：

```swift
.onTapGesture(count: 2) { onDoubleClick?() }
.onTapGesture(count: 1) { onSingleClick?() }
```

### 数据流分析

HistoryListView 创建 ClipRowView 时未传入 `onSingleClick` 回调，因此 `onSingleClick` 默认为 nil。

SwiftUI 手势解析规则：嵌套视图上的 tap gesture，内层优先。ClipRowView 内部的 `.onTapGesture(count: 1)` 会先消费点击事件，执行 `onSingleClick?()` —— 因为回调是 nil，等价于"吞掉"了点击事件。外层 `.onTapGesture { selectedClip = clip }` 不会触发。

### 对比验证

`UnifiedPastePanelView.swift` 中创建 ClipRowView 时正确传入了回调：

```swift
ClipRowView(
    clip: clip,
    isSelected: viewModel.isSelected(index: index),
    onSingleClick: { viewModel.selectIndex(index) },
    onDoubleClick: { viewModel.handleDoubleClick(clip: clip) }
)
```

证实 HistoryListView 漏传 `onSingleClick` 是根因。

## 红灯测试

新增 XCUITest `testMainWindowListClick_UpdatesDetailPanel`：

```swift
func testMainWindowListClick_UpdatesDetailPanel() {
    let app = XCUIApplication()
    app.launchArguments = ["--UITEST_SHOW_MAIN_WINDOW", "--UITEST_PREVIEW_DATA"]
    app.launch()
    app.activate()

    let emptyDetailText = app.staticTexts["选择一条剪贴内容查看详情"]
    XCTAssertTrue(emptyDetailText.waitForExistence(timeout: 5))

    let firstRowText = app.staticTexts["func viewDidLoad() { super.viewDidLoad() }"]
    XCTAssertTrue(firstRowText.waitForExistence(timeout: 3))
    firstRowText.click()

    // 修复前：selectedClip 不更新，空状态文本不消失
    XCTAssertFalse(emptyDetailText.exists, "点击行后详情面板应更新")
}
```

## 绿灯修复

`HistoryListView.swift` 修改：

```swift
List(clips) { clip in
    ClipRowView(clip: clip, onSingleClick: { selectedClip = clip })
}
.accessibilityIdentifier("historyList")
```

- 传入 `onSingleClick: { selectedClip = clip }`，让 ClipRowView 内部手势触发选中
- 删除外层冗余的 `.contentShape(Rectangle())` 和 `.onTapGesture { selectedClip = clip }`，避免双重手势竞争
- 与 `UnifiedPastePanelView` 的创建模式保持一致

## 总结

根因是 `HistoryListView` 创建 `ClipRowView` 时漏传 `onSingleClick` 回调，导致 ClipRowView 内部 `.onTapGesture(count: 1)` 吞掉点击事件但不执行任何操作。修复方式与 `UnifiedPastePanelView` 保持一致，将选中回调注入 ClipRowView。
