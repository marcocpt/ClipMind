# 修复日志：辅助功能图标 / TCC 自动添加 / AppIcon

> 创建：2026-07-14 | 工作树：fix/permission-icon-tcc-appicon

## 问题描述

用户反馈 3 个 bug：

1. **辅助功能权限行无图标**：首次启动引导的「权限设置」页面中，辅助功能权限行前面没有图标显示。通知权限行的 `bell.fill` 图标正常显示。
2. **辅助功能未自动添加 app**：点击「打开系统设置」按钮后，仅跳转到系统设置的辅助功能面板，没有自动把 ClipMind 加入权限列表（需要用户手动点 + 添加）。
3. **无 App 图标**：应用在 Dock / 菜单栏 / 启动台显示默认占位图标，无品牌图标。需按 `docs/ClipMind.html` 中 logo-mark 设计：32x32 圆角矩形（border-radius 9px），紫色→青色渐变背景（#8b5cf6 → #22d3ee），中间白色剪贴板 SVG 图标。

## 前置：步骤 0 获取的运行日志信息

- AI-test logs 与当前 logs 目录均为空
- 用户选择「无日志，跳过日志获取」
- 基于 `docs/ClipMind.html` 设计稿与 `docs/planning/P0/F1/F1_ClipMind_视觉原型.html` 进行静态分析

## 红灯：测试用例

### Bug 1：辅助功能图标

**根因假设 1**：`Image(systemName: "accessibility")` 使用的 SF Symbol 名称在 macOS 13 运行时不可用，SwiftUI 静默渲染为空。

**测试**：`ClipMindTests/UI/PermissionIconSymbolTests.swift`
- `testAccessibilitySFSymbolCanBeLoaded`：断言 `NSImage(systemSymbolName: "accessibility", accessibilityDescription: nil) != nil`
- 对照组：`testBellFillSFSymbolCanBeLoaded` 断言 `bell.fill` 可加载

### Bug 2：TCC 未自动添加 app

**根因**：`PermissionRequestView.openAccessibilitySettings()` 仅调用 `NSWorkspace.shared.open(url)` 打开系统设置 URL，未调用 `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])` 触发系统 TCC 提示。

**测试**：`ClipMindTests/Privacy/PermissionRequesterTests.swift`
- `testRequestAccessibilityPassesPromptTrue`：注入 mock 的 `axTrustedCheck` 闭包，验证调用时 `prompt` 参数为 `true`

### Bug 3：无 App 图标

**根因**：项目根目录无 `Assets.xcassets`，`project.yml` 也未配置 AppIcon，Info.plist 无 `CFBundleIconName` 键。

**测试**：`ClipMindTests/App/AppIconAssetTests.swift`
- `testAppIconImageExistsInBundle`：断言 `NSImage(named: "AppIcon") != nil`
- `testAssetsCatalogCompiled`：断言 `Bundle.main.url(forResource: "Assets", withExtension: "car") != nil`

## 根因调查

### Bug 1 调查

代码位置：`ClipMind/UI/Onboarding/PermissionRequestView.swift:22` 与 `:82-95`

```swift
PermissionRow(
    icon: "accessibility",  // ← 此 SF Symbol 名称
    ...
)

private struct PermissionRow: View {
    let icon: String
    ...
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)
            ...
        }
    }
}
```

对照通知权限行使用 `bell.fill`（同样代码路径）能正常渲染，说明渲染管线正常。问题集中在 `accessibility` 这个 SF Symbol 名称。

### Bug 2 调查

代码位置：`ClipMind/UI/Onboarding/PermissionRequestView.swift:62-68`

```swift
private func openAccessibilitySettings() {
    let url = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    )!
    NSWorkspace.shared.open(url)
    LogCategory.app.info("已打开辅助功能系统设置")
}
```

此 URL scheme 仅打开「系统设置 → 隐私与安全性 → 辅助功能」面板，**不会**触发系统级 TCC 提示对话框，不会把当前 app 自动加入权限列表。

正确做法：调用 `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true] as CFDictionary)`。此 API 会：
1. 检查当前 app 是否已授权辅助功能
2. 如果未授权，弹出系统级 TCC 提示对话框，自动把当前 app 加入辅助功能权限列表（用户只需点开关）

### Bug 3 调查

- `project.yml` 配置中 `sources` 仅包含 `ClipMind` 目录，但目录下无 `Assets.xcassets`
- Info.plist 无 `CFBundleIconName` 键（使用 asset catalog 时 Xcode 自动注入）
- 构建产物 `ClipMind.app/Contents/Resources/` 下无 `.icns` 文件、无 `Assets.car`

设计参考：`docs/ClipMind.html` 中 `.logo-mark` 元素
- 尺寸：32x32
- 圆角：9px
- 背景：`linear-gradient(135deg, #8b5cf6 0%, #22d3ee 100%)`
- 内容：白色剪贴板 SVG，路径：
  - `M9 2h6a2 2 0 0 1 2 2v2h2a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h2V4a2 2 0 0 1 2-2z`（剪贴板主体 + 顶部夹子）
  - `M9 12h6M9 16h4`（两条横线表示文本）

## 绿灯：修复实施

### Bug 1 修复：辅助功能图标

**根因**：SF Symbol `"accessibility"` 在 macOS 13 运行时不可用（`NSImage(systemSymbolName:)` 返回 nil），SwiftUI `Image(systemName:)` 静默渲染为空。对照组 `"bell.fill"` 正常加载。

**修复**：将 `PermissionRequestView.swift:22` 的 `icon: "accessibility"` 改为 `icon: "hand.raised.fill"`（macOS 11+ 可用，语义上表示"举手请求权限"）。

**修改文件**：
- `ClipMind/UI/Onboarding/PermissionRequestView.swift`：icon 参数
- `ClipMindTests/UI/PermissionIconSymbolTests.swift`：测试断言改为验证 `hand.raised.fill` 可加载

### Bug 2 修复：TCC 自动添加 app

**根因**：`PermissionRequestView.openAccessibilitySettings()` 仅调用 `NSWorkspace.shared.open(url)` 打开系统设置面板，未调用 `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])` 触发系统级 TCC 提示。

**修复**：
1. 新建 `ClipMind/Privacy/PermissionRequester.swift`：封装 `AXIsProcessTrustedWithOptions` 调用，提供可注入的 `axTrustedCheck` 闭包便于测试
2. 修改 `PermissionRequestView.openAccessibilitySettings()`：先调用 `PermissionRequester.requestAccessibility()` 触发 TCC 提示，再打开系统设置面板

**修改文件**：
- `ClipMind/Privacy/PermissionRequester.swift`（新建）
- `ClipMind/UI/Onboarding/PermissionRequestView.swift`：openAccessibilitySettings 方法
- `ClipMindTests/Privacy/PermissionRequesterTests.swift`（新建）

### Bug 3 修复：AppIcon

**根因**：项目无 `Assets.xcassets`，`project.yml` 未配置 `ASSETCATALOG_COMPILER_APPICON_NAME`，`Info.plist` 无 `CFBundleIconName`。

**修复**：
1. 创建 `ClipMind/Assets.xcassets/Contents.json`
2. 创建 `ClipMind/Assets.xcassets/AppIcon.appiconset/Contents.json`（macOS 传统格式：idiom="mac", scale="2x", size="512x512"）
3. 用 Python + PIL + numpy 生成 1024x1024 AppIcon PNG（按 `docs/ClipMind.html` logo-mark 设计：紫青渐变背景 + 白色描边剪贴板）
4. 更新 `ClipMind/Resources/Info.plist`：添加 `CFBundleIconName = AppIcon`
5. 更新 `project.yml`：添加 `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`
6. 重新运行 `xcodegen generate`

**修改文件**：
- `ClipMind/Assets.xcassets/Contents.json`（新建）
- `ClipMind/Assets.xcassets/AppIcon.appiconset/Contents.json`（新建）
- `ClipMind/Assets.xcassets/AppIcon.appiconset/appicon-1024.png`（新生成）
- `ClipMind/Resources/Info.plist`：添加 CFBundleIconName
- `project.yml`：添加 ASSETCATALOG_COMPILER_APPICON_NAME

### 测试结果

```
Test Suite 'Selected tests' passed at 2026-07-14 06:29:47.378.
         Executed 6 tests, with 0 failures (0 unexpected) in 0.005 (0.008) seconds

** TEST SUCCEEDED **
```

- ✅ AppIconAssetTests（2 个测试通过）
- ✅ PermissionIconSymbolTests（2 个测试通过）
- ✅ PermissionRequesterTests（2 个测试通过）

## 总结

3 个 bug 全部修复并通过 TDD 验证：

| Bug | 根因 | 修复方案 | 验证 |
|-----|------|----------|------|
| 辅助功能图标不显示 | SF Symbol "accessibility" 在 macOS 13 不可用 | 改用 "hand.raised.fill" | ✅ |
| 点击"打开系统设置"未自动添加 app | 仅打开 URL，未触发 TCC 提示 | 调用 AXIsProcessTrustedWithOptions(prompt=true) | ✅ |
| 无 App 图标 | 无 Assets.xcassets | 创建 Asset Catalog + 1024x1024 图标 + Info.plist 配置 | ✅ |

全量回归验证延迟到步骤 3.3.5（提交后 CI 验证）。

## 流程图

### Bug 2 修复流程：点击「打开系统设置」按钮

```
用户点击「打开系统设置」
        │
        ▼
PermissionRequestView.openAccessibilitySettings()
        │
        ├─→ PermissionRequester.requestAccessibility()
        │       │
        │       ├─→ axTrustedCheck(true)
        │       │       │
        │       │       ├─→ AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])
        │       │       │       │
        │       │       │       ├─→ 已授权？ → 返回 true
        │       │       │       └─→ 未授权？ → 弹出系统 TCC 提示对话框
        │       │       │                       └─→ 自动把 ClipMind 加入辅助功能权限列表
        │       │       └─→ 返回授权状态
        │       └─→ LogCategory.app.info("请求辅助功能权限（TCC 提示），当前授权状态: ...")
        │
        ├─→ NSWorkspace.shared.open(系统设置 URL)
        │       └─→ 打开「系统设置 → 隐私与安全性 → 辅助功能」面板
        │
        └─→ LogCategory.app.info("已请求辅助功能权限并打开系统设置面板")
```

### Bug 1 修复流程：辅助功能图标渲染

```
PermissionRequestView.body
        │
        ▼
PermissionRow(icon: "hand.raised.fill", ...)
        │
        ▼
Image(systemName: "hand.raised.fill")
        │
        ├─→ NSImage(systemSymbolName: "hand.raised.fill") → 非 nil ✅
        └─→ SwiftUI 渲染 SF Symbol 图标
```

### Bug 3 修复流程：AppIcon 编译

```
xcodegen generate
        │
        ▼
project.yml (ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon)
        │
        ▼
xcodebuild build
        │
        ├─→ CompileAssetCatalog (actool)
        │       ├─→ 读取 Assets.xcassets/AppIcon.appiconset/Contents.json
        │       ├─→ 读取 appicon-1024.png (1024x1024)
        │       ├─→ 生成 AppIcon.icns (多尺寸)
        │       └─→ 生成 Assets.car
        │
        ├─→ ProcessInfoPlistFile
        │       └─→ 注入 CFBundleIconName=AppIcon, CFBundleIconFile=AppIcon
        │
        └─→ CpResource AppIcon.icns → ClipMind.app/Contents/Resources/
```

## 时序图

### Bug 2：辅助功能权限请求时序

```
用户          PermissionRequestView       PermissionRequester       AXIsProcessTrustedWithOptions       系统设置
 │                    │                          │                            │                            │
 │  点击按钮           │                          │                            │                            │
 │───────────────────>│                          │                            │                            │
 │                    │  requestAccessibility()   │                            │                            │
 │                    │─────────────────────────>│                            │                            │
 │                    │                          │  axTrustedCheck(true)      │                            │
 │                    │                          │───────────────────────────>│                            │
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

### Bug 3：AppIcon 编译时序

```
xcodebuild          actool              Assets.xcassets          Info.plist
   │                    │                      │                      │
   │  编译 Asset Catalog │                      │                      │
   │───────────────────>│                      │                      │
   │                    │  读取 Contents.json    │                      │
   │                    │─────────────────────>│                      │
   │                    │  读取 appicon-1024.png │                      │
   │                    │─────────────────────>│                      │
   │                    │  生成 AppIcon.icns     │                      │
   │                    │  生成 Assets.car       │                      │
   │                    │  生成 partial Info.plist│                     │
   │  返回编译结果        │                      │                      │
   │<───────────────────│                      │                      │
   │  合并 Info.plist    │                      │                      │
   │──────────────────────────────────────────────────────────────────>│
   │  CFBundleIconName=AppIcon                  │                      │
   │  CFBundleIconFile=AppIcon                  │                      │
   │                    │                      │                      │
```
