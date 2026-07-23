# 双击没有粘贴

## 问题描述

F1.9 快捷粘贴面板中，双击列表项未触发粘贴动作。

- **复现条件**：全局快捷键呼出 QuickPastePanel → 双击 ClipRowView
- **期望行为**：双击应触发 PasteCoordinator 执行粘贴
- **实际行为**：双击后无粘贴发生

## [前置] 步骤0 获取的运行日志信息

无运行日志（用户跳过日志获取）。基于代码审查定位问题。

## [根因调查]

### 调查过程

阅读双击粘贴完整调用链：

1. `ClipRowView.onTapGesture(count: 2)` → `onDoubleClick?()`
2. `QuickPasteView` 传入 `onDoubleClick: { viewModel.handleDoubleClick(index: index) }`
3. `QuickPasteViewModel.handleDoubleClick(index:)` → `onPasteTriggered?(clip)`
4. `QuickPasteAssembly` 设置 `onPasteTriggered = { coordinator.handlePaste(clip: $0) }`
5. `PasteCoordinator.handlePaste(clip:)` → 写剪贴板 → 关闭面板 → 显示浮层/模拟粘贴

### 发现两个断链点

#### Bug 1：SwiftUI 手势顺序错误（主因）

**位置**：`ClipMind/UI/MenuBar/ClipRowView.swift:44-51`

```swift
// 当前代码（错误顺序）
.onTapGesture(count: 1) { onSingleClick?() }   // 先注册 single-tap
.onTapGesture(count: 2) { onDoubleClick?() }   // 后注册 double-tap
```

**Apple 官方正确模式**：double-tap 在前，single-tap 在后。

```swift
// 正确顺序
.onTapGesture(count: 2) { onDoubleClick?() }   // 先注册 double-tap
.onTapGesture(count: 1) { onSingleClick?() }   // 后注册 single-tap
```

**错误顺序的后果**：
- 错误顺序下，single-tap 是内层手势，double-tap 是外层手势
- 双击时，内层 single-tap 在第一次点击时触发，调用 `selectIndex(index)` 改变 `@Published selectedIndex`
- 这引发 SwiftUI 视图重渲染，可能中断第二次点击的 double-tap 手势识别
- 结果：双击只触发 single-click（选中），不触发 double-click（粘贴）

#### Bug 2：filteredClips 索引不匹配（搜索场景）

**位置**：`ClipMind/UI/QuickPaste/QuickPasteView.swift:204-211`

```swift
ForEach(Array(filteredClips.enumerated()), id: \.element.id)
{ index, clip in
    ClipRowView(
        ...
        onDoubleClick: { viewModel.handleDoubleClick(index: index) }  // BUG
    )
}
```

`filteredClips.enumerated()` 的 `index` 是过滤后列表的索引，但 `handleDoubleClick(index:)` 用该索引访问未过滤的 `clips` 数组。

**示例**：
- clips = [imageA, textB]
- 搜索 "B" → filteredClips = [textB]
- ForEach 给 textB 的 index = 0
- `handleDoubleClick(index: 0)` 访问 `clips[0]` = imageA（错误！）
- imageA 是图片类型 → 显示提示而非粘贴 → 用户看到"双击没有粘贴"

### 数据流跟踪

**无搜索场景**（Bug 1 主因）：
- clips = [textA, textB, textC]
- filteredClips == clips，索引匹配
- 双击 textB（index=1）→ single-tap 先触发 selectIndex(1) → 重渲染 → double-tap 被中断 → 无粘贴

**有搜索场景**（Bug 1 + Bug 2）：
- clips = [imageA, textB]
- 搜索 "B" → filteredClips = [textB]（index=0）
- 双击 textB → handleDoubleClick(index:0) → 访问 clips[0]=imageA → 显示提示而非粘贴

### 假设验证

- **假设**：手势顺序错误导致 double-tap 被中断
- **验证方式**：XCUITest `testDoubleClick_OnTextRow_TriggersPaste` 在 CI 中验证（本地因输入法弹窗无法可靠运行）
- **假设**：filteredClips 索引不匹配导致搜索后双击粘贴错误 clip
- **验证方式**：XCTest 单元测试（可本地验证）

## [红灯] 测试用例

新增 XCTest：`testHandleDoubleClick_ByClip_PastesCorrectClip_EvenWhenFiltered`
- 验证新 API `handleDoubleClick(clip: ClipItem)` 在搜索过滤后仍粘贴正确 clip
- 当前代码无此 API → 编译失败（TDD 红灯）

## [绿灯] 修复实施

### 修复 1：手势顺序

`ClipRowView.swift`：交换 `onTapGesture` 顺序，double-tap 在前。

### 修复 2：filteredClips 索引

`QuickPasteViewModel`：新增 `handleDoubleClick(clip: ClipItem)` 方法，按 clip 而非 index 查找。
`QuickPasteView`：`onDoubleClick` 传入 `clip` 而非 `index`。

## 总结

两个 bug 共同导致"双击没有粘贴"：
1. 手势顺序错误（无搜索场景主因）→ XCUITest 在 CI 验证
2. 索引不匹配（有搜索场景）→ XCTest 单元测试验证
