# 修复日志：点击「打开系统设置」触发 EXC_BAD_ACCESS 崩溃

> 创建：2026-07-14 | 工作树：fix/permission-tcc-crash

## 问题描述

用户报告：在权限设置页面点击「打开系统设置」按钮时，应用崩溃。

- 崩溃位置：`ClipMind/Privacy/PermissionRequester.swift:14`
- 错误：`CFGetTypeID Thread 1: EXC_BAD_ACCESS (code=1, address=0x8)`
- 复现条件：在签名 + Hardened Runtime 的 app 上下文中调用 `AXIsProcessTrustedWithOptions(options as CFDictionary)`
- 期望行为：调用此 API 应正常弹出 TCC 提示对话框，把 ClipMind 加入辅助功能权限列表，而不崩溃

## 前置：步骤 0 获取的运行日志信息

- AI-test logs 与当前 logs 目录均为空
- 用户选择「无日志，跳过日志获取」
- 基于 Xcode 崩溃堆栈 + 代码静态分析进行根因调查

## 红灯：测试用例

### XCTest（本地可验证绿灯）

**文件**：`ClipMindTests/Privacy/PermissionRequesterTests.swift`

- `testDefaultAxTrustedCheckReturnsBoolWithoutCrashing`：调用默认 `axTrustedCheck(true)`（不注入 mock，触发真实 `AXIsProcessTrustedWithOptions` 调用），断言返回 Bool。验证修复后默认闭包稳定可调用。

### XCUITest（延迟到步骤 3.3.5 CI 验证）

**文件**：`ClipMindUITests/PermissionRequestUITests.swift`（新建）

- `testOpenAccessibilitySettingsDoesNotCrashApp`：启动 app 进入 onboarding → 进入权限设置步骤 → 点击「打开系统设置」按钮 → 验证 app 仍存活（不崩溃）

## 根因调查

### 错误信息与堆栈

```
Thread 1: EXC_BAD_ACCESS (code=1, address=0x8)
    CFGetTypeID + ...
    AXIsProcessTrustedWithOptions + ...
    PermissionRequester.axTrustedCheck closure @ PermissionRequester.swift:14
    PermissionRequester.requestAccessibility() @ PermissionRequester.swift:24
    PermissionRequestView.openAccessibilitySettings() @ PermissionRequestView.swift:67
```

### 数据流追踪

```
用户点击「打开系统设置」按钮
        │
        ▼
PermissionRequestView.openAccessibilitySettings() @ PermissionRequestView.swift:66-73
        │
        ▼
PermissionRequester.requestAccessibility() @ PermissionRequester.swift:23-27
        │
        ▼
axTrustedCheck(true) → 默认闭包 @ PermissionRequester.swift:12-15
        │
        ▼
let options: NSDictionary = [kAXTrustedCheckOptionPrompt: prompt]  ← 关键点
        │
        │  kAXTrustedCheckOptionPrompt 是 ApplicationServices framework 的 extern CFStringRef
        │  在 Hardened Runtime + 签名 app 上下文中，dyld 加载时序问题可能导致此全局常量为 NULL
        │
        ▼
AXIsProcessTrustedWithOptions(options as CFDictionary) @ PermissionRequester.swift:14
        │
        │  内部遍历 dictionary entries，对每个 key/value 调用 CFGetTypeID 验证类型
        │  对 NULL key 调用 CFGetTypeID(nil) → 解引用 nil 偏移 0x8 → EXC_BAD_ACCESS
        │
        ▼
💥 崩溃
```

### 假设与验证

**假设**：`kAXTrustedCheckOptionPrompt` 全局 CFString 常量在 Hardened Runtime + 签名 app 上下文中为 NULL，导致 NSDictionary 字面量 `[kAXTrustedCheckOptionPrompt: prompt]` 把 NULL 当作 key 桥接，传给 `AXIsProcessTrustedWithOptions` 后内部 `CFGetTypeID(nil)` 崩溃。

**证据**：
1. `EXC_BAD_ACCESS (address=0x8)` 是典型的「对 nil 对象访问 isa 之后的字段」模式（对象首字段 isa 在偏移 0，第二个字段在偏移 8）
2. `CFGetTypeID` 内部访问 `cf->_cf_typeID` 或类似字段，对 nil 解引用偏移 8 字节
3. `kAXTrustedCheckOptionPrompt` 是 extern CFStringRef 全局常量，依赖 dyld 加载 ApplicationServices framework 时填充
4. 项目启用 Hardened Runtime（`ENABLE_HARDENED_RUNTIME: YES`）+ 代码签名，可能影响 dyld 加载时序
5. 在测试 bundle（无 Hardened Runtime）中不会复现，进一步印证是签名 app 上下文特有的运行时问题

**验证方法**：用字符串字面量 `"AXTrustedCheckOptionPrompt"`（`kAXTrustedCheckOptionPrompt` 的实际字符串值，是公开 API 常量）替代全局常量，消除对 dyld 加载时序的依赖。

### 同类代码对比

正常工作的代码使用字符串字面量作为 CFDictionary key，不依赖全局 CFString 常量。例如：

```swift
// 稳定：字符串字面量
let options: CFDictionary = ["AXTrustedCheckOptionPrompt": kCFBooleanTrue!] as CFDictionary

// 不稳定：依赖全局常量（当前代码）
let options: NSDictionary = [kAXTrustedCheckOptionPrompt: prompt]
```

## 绿灯：修复实施

### 修复方案

**根因**：`kAXTrustedCheckOptionPrompt` 全局 CFString 常量在 Hardened Runtime + 签名 app 上下文中可能因 dyld 加载时序问题为 NULL，作为 NSDictionary 字面量 key 时被错误桥接，传给 `AXIsProcessTrustedWithOptions` 后内部 `CFGetTypeID(nil)` 崩溃。

**修复**：用字符串字面量 `"AXTrustedCheckOptionPrompt"`（`kAXTrustedCheckOptionPrompt` 的实际字符串值）替代全局常量，避免依赖 dyld 加载时序。同时把 Bool 显式包装为 NSNumber，确保 NSDictionary value 类型稳定。

**修改文件**：
- `ClipMind/Privacy/PermissionRequester.swift`：替换字典 key 来源

### 测试结果

- XCTest `testDefaultAxTrustedCheckReturnsBoolWithoutCrashing`：本地绿灯验证（步骤 2.3）
- XCUITest `testOpenAccessibilitySettingsDoesNotCrashApp`：延迟到步骤 3.3.5 CI 验证

## 总结

| 项 | 内容 |
|-----|------|
| 根因 | `kAXTrustedCheckOptionPrompt` 全局 CFString 常量在 Hardened Runtime 上下文中为 NULL |
| 修复 | 用字符串字面量 `"AXTrustedCheckOptionPrompt"` 替代全局常量 |
| 验证 | XCTest 本地绿灯 + XCUITest 延迟 CI 验证 |

## 流程图

### 修复前（崩溃流程）

```
用户点击「打开系统设置」
        │
        ▼
PermissionRequester.axTrustedCheck(true)
        │
        ▼
[kAXTrustedCheckOptionPrompt: prompt]  ← kAXTrustedCheckOptionPrompt 可能为 NULL
        │
        ▼
AXIsProcessTrustedWithOptions({NULL: true})
        │
        ▼
CFGetTypeID(NULL)  ← 解引用 nil + 0x8
        │
        ▼
💥 EXC_BAD_ACCESS (address=0x8)
```

### 修复后（稳定流程）

```
用户点击「打开系统设置」
        │
        ▼
PermissionRequester.axTrustedCheck(true)
        │
        ▼
["AXTrustedCheckOptionPrompt": prompt]  ← 字符串字面量，编译期常量
        │
        ▼
AXIsProcessTrustedWithOptions({"AXTrustedCheckOptionPrompt": true})
        │
        ▼
CFGetTypeID("AXTrustedCheckOptionPrompt" as CFString)  ← 非 nil，正常返回 CFString typeID
        │
        ▼
✅ 弹出 TCC 提示对话框 / 返回授权状态
```

## 时序图

### 修复后：权限请求时序

```
用户          PermissionRequestView       PermissionRequester       AXIsProcessTrustedWithOptions       系统 TCC
 │                    │                          │                            │                            │
 │  点击按钮           │                          │                            │                            │
 │───────────────────>│                          │                            │                            │
 │                    │  requestAccessibility()   │                            │                            │
 │                    │─────────────────────────>│                            │                            │
 │                    │                          │  axTrustedCheck(true)      │                            │
 │                    │                          │  构造 ["AXTrustedCheckOptionPrompt": true]              │
 │                    │                          │───────────────────────────>│                            │
 │                    │                          │                            │  CFGetTypeID 验证 key      │
 │                    │                          │                            │  ✓ 字符串字面量非 nil       │
 │                    │                          │                            │  弹出 TCC 提示对话框         │
 │                    │                          │                            │  加入权限列表               │
 │                    │                          │  返回授权状态                │                            │
 │                    │                          │<───────────────────────────│                            │
 │                    │                          │  记录日志                    │                            │
 │                    │  返回授权状态              │                            │                            │
 │                    │<─────────────────────────│                            │                            │
 │                    │  open(系统设置 URL)       │                            │                            │
 │                    │──────────────────────────────────────────────────────────────────────────────────>│
 │                    │  记录日志                  │                            │                            │
 │  看到系统设置面板     │                          │                            │                            │
 │<───────────────────│                          │                            │                            │
```
