# API Key 跳过提示框图标延迟显示

## 问题描述

在 API Key 配置页面点击「跳过」按钮时，提示框（alert）立即出现，但提示框中的图标（App 图标）有明显延迟才渲染出来。期望行为是图标与提示框同步显示。

## [前置] 运行日志信息

无运行日志（步骤 0 扫描 logs 目录为空）。

## [红灯] 测试用例

新增 XCUITest `testAPIKeySkipAlertShowsContentImmediately`，验证点击「跳过」后 alert sheet 内容（标题、按钮）完整出现。由于图标延迟是渲染时序问题，XCUITest 无法直接检测图标元素（App 图标不是 accessibility element），但可验证 alert 内容完整呈现作为回归保护。

XCUITest 禁止本地执行，延迟到步骤 3.2.5 走 CI 验证。

## [根因调查]

### 代码流追踪

1. `OnboardingView.swift` L81-83：用户点击「跳过」→ `showSkipAlert = true`（父视图状态）
2. `APIKeyGuideView.swift` L16：`triggerSkipAlert: Binding<Bool>?` 接收绑定
3. `APIKeyGuideView.swift` L81-86：`onChange(of: triggerSkipAlert)` 检测到变化
   - 设 `showSkipAlert = true`（本地状态）→ SwiftUI 开始呈现 alert
   - 设 `triggerSkipAlert?.wrappedValue = false` → 传播回父视图 `OnboardingView.showSkipAlert = false`
4. 父视图重渲染（`showSkipAlert` 从 true 变 false）→ 传播回子视图
5. alert 在呈现过程中收到重渲染信号 → 内容分两步渲染

### 根本原因

**两步 `onChange` 绑定导致渲染循环**：
- `showSkipAlert = true` 和 `triggerSkipAlert?.wrappedValue = false` 在同一个 `onChange` 回调中执行
- 第一个状态变更触发 alert 呈现
- 第二个状态变更传播回父视图，引起整个视图树重渲染
- alert 在呈现过程中被重渲染打断，导致图形资源（App 图标）延迟加载

### 辅助因素

AppIcon.appiconset/Contents.json 仅有一个 512x512@2x（1024x1024）条目。NSAlert 需要 64x64 尺寸的图标，运行时缩放可能加重延迟。

## [绿灯] 修复实施

### 修复方案

移除 `triggerSkipAlert: Binding<Bool>?` + `onChange` 两步绑定机制，改用直接 `@Binding var showSkipAlert: Bool`。

**修改文件**：
1. `APIKeyGuideView.swift`：`triggerSkipAlert: Binding<Bool>?` → `@Binding var showSkipAlert: Bool`，移除本地 `@State private var showSkipAlert` 和 `onChange`
2. `OnboardingView.swift`：`triggerSkipAlert: $showSkipAlert` → `showSkipAlert: $showSkipAlert`

### 验证结果

- XCTest 本地绿灯：步骤 2.3 本地执行（无 GUI 依赖）
- XCUITest + 全量回归：延迟到步骤 3.2.5 CI 验证

## 总结

根因是 `onChange` 两步绑定引起渲染循环，导致 alert 呈现过程中被重渲染打断。修复方案是用直接 `@Binding` 替代两步绑定，消除渲染循环。
