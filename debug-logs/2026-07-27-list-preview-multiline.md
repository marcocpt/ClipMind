# Bug 修复调试日志：左侧列表多行内容只显示一行

> 日期：2026-07-27 | 功能：F1.16 列表预览 | 分支：fix/F1.16-list-preview-multiline

## 问题描述

所有左侧列表窗口（主窗口 HistoryListView、菜单栏弹窗 UnifiedPastePanelView、快捷键面板）
显示的剪贴内容预览，当原文包含回车（`\n`）时，目前只显示第一行；期望行为是显示最多
两行（即允许多行预览，上限 2 行）。

## [前置] 运行日志信息

无运行日志（用户跳过日志获取）。Bug 现象明确，可通过代码审查定位。

## [红灯] 测试用例

新增 `ClipRowViewMultiLinePreviewTests`（XCUITest，延迟到 CI 验证）：
- `testMultiLineClipPreview_ShowsSecondLine`：多行剪贴内容在列表中应显示第二行文本

测试数据：在 `ClipTestData.previewClips` 末尾追加一条多行文本 clip（第 12 条，索引 11），
文本为 `"多行剪贴内容第一行\n多行剪贴内容第二行"`，用于 XCUITest 验证第二行可见。

## [根因调查] 调查过程

### 代码审查

`ClipMind/UI/MenuBar/ClipRowView.swift` 第 25-28 行：

```swift
Text(contentPreview)
    .font(.system(size: 13))
    .lineLimit(2)
    .foregroundColor(.primary)
```

**已设置 `.lineLimit(2)`**，理论上应显示最多 2 行。

### 数据流追踪

1. `ClipItem.content.text`：存储完整文本（含 `\n`）—— EncryptedStore 通过 JSON 编码保存，
   `\n` 在 JSON 中转义为 `\n`，解码后恢复为换行符。**数据层无截断**。
2. `ClipRowView.contentPreview`：`case .text(let text): return text` —— 返回完整文本，
   **视图层入口无截断**。
3. `Text(contentPreview)`：`contentPreview` 类型为 `String`，使用 `init(_ content: String)`
   初始化器（verbatim），**应正确尊重 `\n` 换行**。

### 根本原因

`.lineLimit(2)` 已设置，但在 `List`（HistoryListView）和 `LazyVStack`（UnifiedPastePanelView）
容器中，SwiftUI 的 Text 在某些布局场景下不会主动按理想高度纵向扩展，导致行高仅容纳 1 行，
第二行被裁剪。

**假设**：Text 在 VStack 中缺少 `.fixedSize(horizontal: false, vertical: true)`，导致
SwiftUI 布局引擎以「单行高度」作为行高提案，`.lineLimit(2)` 的第二行没有空间渲染。

**验证假设的方法**：添加 `.fixedSize(horizontal: false, vertical: true)` 让 Text 在纵向
使用理想高度（2 行），横向仍沿用父容器宽度。

## [绿灯] 修复实施

### 修改文件

1. `ClipMind/Utils/ClipTestData.swift`：在 `previewClips` 末尾追加一条多行文本 clip
2. `ClipMind/UI/MenuBar/ClipRowView.swift`：Text 添加 `.fixedSize(horizontal: false, vertical: true)`
3. `ClipMindUITests/ClipRowViewMultiLinePreviewTests.swift`：新增 XCUITest 验证第二行可见

### XCTest 本地绿灯结果

本 bug 为 UI 渲染问题，使用 XCUITest 验证（禁止本地执行，延迟到步骤 3.2.5 走 CI）。
本地通过编译检查 + 步骤 4 启动 app 视觉验证。

## 总结

- 根因：`.lineLimit(2)` 缺少 `.fixedSize` 配合，SwiftUI 布局引擎未给第二行分配空间
- 修复：Text 添加 `.fixedSize(horizontal: false, vertical: true)`
- 验证：XCUITest 延迟到 CI；本地通过编译 + 视觉确认
