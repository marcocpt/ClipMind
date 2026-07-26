# 全局热键面板缺底部工具栏 + 按钮换图标 Bug 修复日志

> 日期：2026-07-26
> 关联：F1.11 菜单栏弹窗双击粘贴后续 bug

## 问题描述

用户反馈：
1. 全局热键打开的窗口（快速粘贴面板）也要加底部工具栏，与菜单栏弹窗一致
2. 三个按钮丢换成图标（"查看全部" / "配置" / "退出" → 图标）

## 期望行为

- 全局热键面板（QuickPaste panel）显示底部三按钮工具栏
- 三按钮在菜单栏弹窗与全局热键面板中均使用图标渲染
- 行为与菜单栏弹窗一致：
  - "查看全部"：关闭面板 + 发送 openMainWindow 通知
  - "配置"：关闭面板 + 发送 openSettingsWindow 通知
  - "退出"：终止整个应用

## 根因调查

### 全局热键面板缺底部工具栏

`ClipMind/App/QuickPasteAssembly.swift:138-142`:

```swift
let view = UnifiedPastePanelView(
    viewModel: viewModel,
    showsBottomBar: false,        // ← Bug：快捷键场景未显示底部工具栏
    accessibilityPrefix: "quickPaste"
)
```

`UnifiedPastePanelView` 通过 `showsBottomBar` 参数控制底部工具栏显隐，菜单栏弹窗场景传 `true`，快捷键场景传 `false`，导致两套面板视觉不一致。

### 文字按钮渲染

`ClipMind/UI/MenuBar/BottomToolbarView.swift:44-58`:

```swift
Button("查看全部", action: onViewAll)
    .buttonStyle(.borderless)
    .accessibilityIdentifier(Self.viewAllButtonIdentifier)
// ... 同样模式的 "配置" / "退出"
```

`Button("文字", action:)` 直接渲染文字标签，未使用 `Image(systemName:)` 图标。

### 缺少 onExitApp 回调

`QuickPasteAssembly.makeQuickPasteContentController` 未设置 `viewModel.onExitApp`，若直接打开底部工具栏，"退出" 按钮点击后 `onExitApp?()` 为 nil 不执行任何操作。

对比 `StatusItemController.makeUnifiedPanelView`:

```swift
viewModel.onExitApp = {
    NSApp.terminate(nil)
}
```

## 红灯测试

新增 XCUITest `testQuickPastePanelHasBottomToolbarButtons`：

```swift
func testQuickPastePanelHasBottomToolbarButtons() {
    let app = XCUIApplication()
    app.launchArguments = [
        "--UITEST_SHOW_MAIN_WINDOW",
        "--UITEST_QUICK_PASTE_PANEL",
        "--UITEST_PREVIEW_DATA"
    ]
    app.launch()
    app.activate()

    let searchField = app.textFields["quickPasteSearchField"]
    XCTAssertTrue(searchField.waitForExistence(timeout: 5))

    XCTAssertTrue(app.buttons["popoverViewAllButton"].waitForExistence(timeout: 3))
    XCTAssertTrue(app.buttons["popoverSettingsButton"].exists)
    XCTAssertTrue(app.buttons["popoverExitButton"].exists)
}
```

## 绿灯修复

### 1. QuickPasteAssembly.swift

```swift
viewModel.onExitApp = {
    NSApp.terminate(nil)
}
let view = UnifiedPastePanelView(
    viewModel: viewModel,
    showsBottomBar: true,           // ← 改为 true
    accessibilityPrefix: "quickPaste"
)
```

### 2. BottomToolbarView.swift（图标替换）

```swift
Button(action: onViewAll) {
    Image(systemName: "list.bullet")
        .imageScale(.large)
}
.buttonStyle(.borderless)
.accessibilityIdentifier(Self.viewAllButtonIdentifier)
.accessibilityLabel("查看全部")  // 保留 VoiceOver 标签
// ... "配置" → gearshape, "退出" → power 同样模式
```

### 3. UnifiedPastePanelView.swift 文档同步

注释中 `快捷键面板场景（QuickPastePanelController 包装）：showsBottomBar = false` 改为 `= true`。

## 总结

两处独立修复：
1. `QuickPasteAssembly` 的 `showsBottomBar` 从 `false` 改为 `true`，并补充 `onExitApp` 回调，使全局热键面板与菜单栏弹窗视觉和行为对齐
2. `BottomToolbarView` 的三按钮从 `Button("文字", action:)` 改为 `Button(action:) { Image(systemName:) }`，并保留 `accessibilityLabel` 维持 VoiceOver 支持
