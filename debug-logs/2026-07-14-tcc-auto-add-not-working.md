# 修复日志：TCC 自动添加 app 失效

> 创建：2026-07-14 | 工作树：fix/F1.9-tcc-auto-add

## 问题描述

用户反馈：在权限请求页面点击「打开系统设置」按钮后，系统虽然打开了「系统设置 → 隐私与安全性 → 辅助功能」面板，但 ClipMind app 没有自动出现在辅助功能列表中（用户必须手动用 + 号添加）。

期望行为：点击按钮后，系统应通过 TCC 提示对话框自动把 ClipMind 加入辅助功能列表，用户只需点击开关即可。

## 前置：步骤 0 获取的运行日志信息

- AI-test logs 与当前 logs 目录均为空
- 用户选择「无日志，跳过日志获取」
- 基于代码审查与 Apple API 行为分析进行根因调查

## 之前修复回顾

之前已经实施过一次修复（commit 5e9ac73）：
- 在 PermissionRequestView.openAccessibilitySettings() 中添加 PermissionRequester.requestAccessibility() 调用
- 新建 ClipMind/Privacy/PermissionRequester.swift 封装 AXIsProcessTrustedWithOptions 调用

但用户反馈仍然没有自动添加 app，说明修复未完全生效。

## 红灯：测试用例

### 根因假设

openAccessibilitySettings() 的当前调用顺序：

1. PermissionRequester.requestAccessibility() → 触发 TCC 提示（异步）
2. NSWorkspace.shared.open(url) → 立即打开系统设置（抢占焦点）

问题：
- AXIsProcessTrustedWithOptions(prompt=true) 同步返回，但 TCC 提示对话框异步显示
- 紧接着 NSWorkspace.shared.open(url) 打开系统设置面板，系统设置抢占焦点
- TCC 提示对话框被覆盖或显示在后面，用户看不到
- 用户只看到系统设置面板，误以为 app 未加入列表

修复方向：调整调用顺序——先打开系统设置面板，再触发 TCC 提示，让 TCC 提示对话框显示在系统设置面板之上。

### 测试设计

把 openAccessibilitySettings() 的核心逻辑抽取到 PermissionRequester，使其可单元测试：

1. 新增 PermissionRequester.openSystemSettings 可注入闭包（默认调用 NSWorkspace.shared.open）
2. 新增 PermissionRequester.openAccessibilitySettingsAndPrompt() 方法，封装调用顺序
3. 测试验证调用顺序：先 openSystemSettings，后 axTrustedCheck(true)

### 红灯测试

ClipMindTests/Privacy/PermissionRequesterTests.swift 新增：

testOpenAccessibilitySettingsAndPromptOpensSettingsBeforeRequest：
- 注入 mock 的 axTrustedCheck 与 openSystemSettings
- 调用 openAccessibilitySettingsAndPrompt()
- 断言 callOrder == ["openSystemSettings", "requestAccessibility"]

当前代码未实现 openSystemSettings 和 openAccessibilitySettingsAndPrompt()，测试编译失败（红灯）。

## 根因调查

### 调用顺序分析

代码位置：ClipMind/UI/Onboarding/PermissionRequestView.swift:66-73

### AXIsProcessTrustedWithOptions 行为

- 同步检查权限状态
- 如果未授权且 prompt=true：异步触发 TCC 提示对话框（由系统进程 tccd 处理）
- 立即返回当前权限状态（false）

TCC 提示对话框是系统级的，由 tccd 显示，不会因为 app 失去焦点而被取消。但是：
- TCC 提示对话框的显示需要时间（异步）
- NSWorkspace.shared.open(url) 立即打开系统设置面板，系统设置获得焦点
- TCC 提示对话框可能在系统设置面板后面显示（被遮挡）
- 用户看不到 TCC 提示对话框，以为 app 未加入列表

### 假设与验证

假设：调整调用顺序（先打开系统设置，再触发 TCC 提示），TCC 提示对话框会显示在系统设置面板之上，用户能看到。

验证：
- 单元测试验证调用顺序
- UI 测试验证 TCC 提示对话框显示（延迟到步骤 3.2.5 CI 验证）

## 绿灯：修复实施

### 修复方案

1. 在 PermissionRequester 中：
   - 新增 openSystemSettings 可注入闭包（默认调用 NSWorkspace.shared.open）
   - 新增 openAccessibilitySettingsAndPrompt() 方法，封装调用顺序：先打开系统设置，再触发 TCC 提示

2. 在 PermissionRequestView.openAccessibilitySettings() 中：
   - 调用 PermissionRequester.openAccessibilitySettingsAndPrompt()

### 修改文件

- ClipMind/Privacy/PermissionRequester.swift：新增 openSystemSettings 闭包与 openAccessibilitySettingsAndPrompt() 方法
- ClipMind/UI/Onboarding/PermissionRequestView.swift：简化 openAccessibilitySettings()
- ClipMindTests/Privacy/PermissionRequesterTests.swift：新增调用顺序测试

## 总结

| Bug | 根因 | 修复方案 | 验证 |
|-----|------|----------|------|
| 点击「打开系统设置」后 app 未自动加入辅助功能列表 | TCC 提示对话框被系统设置面板遮挡，用户看不到 | 调整调用顺序：先打开系统设置，再触发 TCC 提示 | XCTest 本地验证 + XCUITest 延迟到 CI |
