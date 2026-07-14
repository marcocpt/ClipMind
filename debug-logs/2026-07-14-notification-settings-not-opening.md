# 通知授权按钮点击后未弹出通知设置

> 日期：2026-07-14 | 功能：F1.11 通知权限设置

## 问题描述

在权限设置页（`PermissionRequestView`）点击「授权通知」按钮后，没有弹出通知设置对话框。用户反馈：点击按钮后无任何可见反应。

## [前置] 步骤 0 获取的运行日志信息

步骤 0 用户选择「无日志，跳过日志获取」。AI-test 与当前 worktree 的 logs 目录均为空。

## 根因分析

### 当前实现

`PermissionRequestView.requestNotificationPermission()` 直接调用 `UNUserNotificationCenter.requestAuthorization`，不检查当前 `authorizationStatus`。

### macOS 通知权限行为

`UNUserNotificationCenter.requestAuthorization` 的系统行为：

| `authorizationStatus` | `requestAuthorization` 行为 |
|---|---|
| `.notDetermined`（首次） | 弹出系统授权对话框 ✅ |
| `.authorized` / `.provisional` / `.ephemeral` | 直接返回 granted=true，不弹窗 |
| `.denied`（用户曾拒绝） | **直接返回 granted=false，不弹窗** ❌ |

当用户曾经拒绝过通知权限后，再次点击「授权通知」按钮，系统直接回调 `granted=false`，不弹任何对话框，用户看到点击按钮无反应。

### 对比辅助功能权限处理

`openAccessibilitySettings()` 会打开系统设置的辅助功能面板，用户可手动开启。通知权限缺少类似处理。

### 根本原因

`requestNotificationPermission()` 没有检查 `authorizationStatus`，对 `.denied` 状态没有引导用户去系统设置。

## [红灯] 测试用例

XCTest 单元测试（`PermissionRequesterTests.swift`）：

1. `testRequestNotificationWhenNotDeterminedCallsAuthorization`：status 为 `.notDetermined` 时调用 `requestAuthorization`，不打开系统设置
2. `testRequestNotificationWhenDeniedOpensSystemSettings`：status 为 `.denied` 时打开系统设置通知页面，不调用 `requestAuthorization`
3. `testRequestNotificationWhenAuthorizedDoesNothing`：status 为 `.authorized` 时不执行任何操作

**红灯验证**：因本地网络问题（SPM 依赖 SQLite.swift 无法克隆），xcodebuild test 无法本地执行。通过代码审查确认测试逻辑正确：三个测试用例覆盖所有关键分支，断言反映功能预期。骨架行为（不检查 status 直接 requestAuthorization）会导致测试 2 和 3 失败。

## [绿灯] 修复实施

### 修改文件

1. **`ClipMind/Privacy/PermissionRequester.swift`**：
   - 新增三个可注入闭包：`notificationAuthorizationStatusProvider`、`notificationAuthorizationRequester`、`notificationSettingsURLHandler`
   - 新增 `requestNotification(completion:)` 方法，根据 `authorizationStatus` 分支处理：
     - `.notDetermined`：调用 `requestAuthorization` 弹出系统对话框
     - `.denied`：调用 `notificationSettingsURLHandler` 打开系统设置通知页面
     - `.authorized` / `.provisional` / `.ephemeral`：不执行操作
     - `@unknown default`：不执行操作
   - 所有 completion 保证在主线程执行

2. **`ClipMind/UI/Onboarding/PermissionRequestView.swift`**：
   - `requestNotificationPermission()` 改为调用 `PermissionRequester.requestNotification`
   - completion 中调用 `refreshPermissionStatus()`

3. **`ClipMindTests/Privacy/PermissionRequesterTests.swift`**：
   - setUp/tearDown 保存恢复新增的三个闭包
   - 新增三个测试用例覆盖 `.notDetermined`、`.denied`、`.authorized` 分支

### XCTest 本地绿灯结果

因本地网络问题（SPM 依赖无法克隆），xcodebuild test 无法本地执行。绿灯验证延迟到步骤 3.2.5 CI 执行。

## 总结

**根本原因**：`requestNotificationPermission()` 不检查 `authorizationStatus`，对 `.denied` 状态（用户曾拒绝）没有引导用户去系统设置，导致点击按钮无反应。

**修复方案**：在 `PermissionRequester` 中新增 `requestNotification(completion:)` 方法，根据 `authorizationStatus` 分支处理。`.denied` 时打开系统设置通知页面（`x-apple.systempreferences:com.apple.preference.notifications`），与辅助功能权限的处理方式一致。

**验证状态**：XCTest 本地因网络问题无法执行，绿灯验证延迟到步骤 3.2.5 CI。
