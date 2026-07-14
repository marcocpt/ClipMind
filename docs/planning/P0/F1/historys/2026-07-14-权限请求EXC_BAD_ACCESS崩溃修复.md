# 权限请求 EXC_BAD_ACCESS 崩溃修复

> 日期：2026-07-14 | 关联分支：fix/permission-tcc-crash

## 改了什么

### 代码修复

- `ClipMind/Privacy/PermissionRequester.swift`
  - `axTrustedCheck` 默认闭包中将 `kAXTrustedCheckOptionPrompt` 全局 CFString 常量替换为字符串字面量 `"AXTrustedCheckOptionPrompt"`
  - Bool 参数包装为 `NSNumber(value: prompt)` 保证类型稳定
  - 补充文档注释说明使用字符串字面量的原因（避免 dyld 加载时序导致全局常量为 NULL）

### 测试新增

- `ClipMindTests/Privacy/PermissionRequesterTests.swift`
  - 新增 `testDefaultAxTrustedCheckDoesNotCrash`：验证默认 `axTrustedCheck` 闭包稳定调用不崩溃（XCTest 单元测试）
- `ClipMindUITests/PermissionRequestUITests.swift`（新建文件）
  - 新增 `testOpenAccessibilitySettingsDoesNotCrashApp`：验证点击「打开系统设置」按钮后 app 不崩溃退出（XCUITest UI 测试）
  - tearDown 中启动带 `--UITEST_SHOW_MAIN_WINDOW` 参数的 app 恢复 `hasCompletedOnboarding=true`，避免污染后续依赖主窗口的测试

### 文档同步

- `docs/planning/P0/F1/F1_ClipMind_测试用例表.md`
  - 版本 v1.5 → v1.6
  - 新增 TC-24-06（点击「打开系统设置」不崩溃，XCUITest，✅ COVERED）
  - 6.1~6.5 节统计数字同步更新（总数 83→84、XCUITest 11→12、✅ COVERED 44→45、F1.7 用例数 23→24）
  - 追加 v1.6 版本记录

## 为什么

### 根因

`kAXTrustedCheckOptionPrompt` 是 ApplicationServices 框架中的 extern CFStringRef 全局常量。在 Hardened Runtime + 签名 app 上下文中，dyld 加载时序问题可能导致该常量在运行时为 NULL。当它作为 NSDictionary 字面量 key 被 bridge 为 NSString 后传入 `AXIsProcessTrustedWithOptions`，函数内部调用 `CFGetTypeID(nil)` 解引用 `nil + 0x8` 触发 `EXC_BAD_ACCESS (code=1, address=0x8)` 崩溃。

### 修复原理

改用字符串字面量 `"AXTrustedCheckOptionPrompt"`（该全局常量的实际字符串值）作为 NSDictionary key，消除对 dyld 加载时序的依赖，从根源上避免 NULL 解引用。

## 影响哪些部分

- **权限请求流程**：首次启动引导中点击「打开系统设置」不再崩溃，TCC 提示对话框正常弹出
- **测试覆盖**：新增 TC-24-06 回归保护此崩溃场景
- **CI 验证**：run 29302008253 conclusion=success，所有测试通过（含新增测试 + 全量回归）
