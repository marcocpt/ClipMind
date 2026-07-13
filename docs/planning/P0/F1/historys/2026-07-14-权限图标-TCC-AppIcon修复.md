> 最后更新：2026-07-14 | 版本：v1.0

# 权限图标 / TCC 自动添加 / AppIcon 修复

## 改了什么

修复 3 个用户反馈的 bug，并同步更新设计规范、视觉原型、测试用例表。

### 代码改动（commit ae2f036）

| Bug | 修复文件 | 改动摘要 |
|-----|---------|---------|
| 辅助功能图标不显示 | `ClipMind/UI/Onboarding/PermissionRequestView.swift` | `icon: "accessibility"` → `icon: "hand.raised.fill"`（macOS 13 运行时前者返回 nil） |
| 点击「打开系统设置」未自动添加 app | `ClipMind/Privacy/PermissionRequester.swift`（新建）+ `PermissionRequestView.swift` | 新建 `PermissionRequester` 封装 `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])`，`openAccessibilitySettings()` 先调用它触发系统 TCC 提示再打开系统设置面板 |
| 无 App 图标 | `ClipMind/Assets.xcassets/`（新建）+ `ClipMind/Resources/Info.plist` + `project.yml` | 创建 Asset Catalog + `AppIcon.appiconset`（1024x1024 PNG，紫青渐变背景 + 白色描边剪贴板，按 `docs/ClipMind.html` logo-mark 设计）+ `CFBundleIconName=AppIcon` + `ASSETCATALOG_COMPILER_APPICON_NAME=AppIcon` |

### 新增测试

| 测试文件 | 测试用例 |
|---------|---------|
| `ClipMindTests/UI/PermissionIconSymbolTests.swift` | `testAccessibilityIconSFSymbolCanBeLoaded`（验证 `hand.raised.fill` 可加载）、`testBellFillSFSymbolCanBeLoaded`（对照组） |
| `ClipMindTests/Privacy/PermissionRequesterTests.swift` | `testRequestAccessibilityPassesPromptTrue`（验证 prompt=true）、`testRequestAccessibilityReturnsTrueWhenGranted` |
| `ClipMindTests/App/AppIconAssetTests.swift` | `testAssetsCatalogCompiledIntoBundle`、`testAppIconImageExistsInBundle` |

### 文档同步（本次 commit）

| 文档 | 改动 |
|------|------|
| `F1_ClipMind_设计规范.md` | 版本 v1.6 → v1.7；6.1.3 节辅助功能权限描述从 `AXIsProcessTrusted()` 更新为 `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])`，标注首次启动时弹出系统 TCC 提示并自动加入权限列表 |
| `F1_ClipMind_视觉原型.html` | 版本 v1.1 → v1.2（基于设计规范 v1.7）；L3336 辅助功能权限卡片图标从「时钟」SVG 改为「举手」SVG（Lucide hand 路径，对应 SF Symbol `hand.raised.fill`）；L3340 补充「点击打开系统设置会自动弹出系统 TCC 提示并把 ClipMind 加入权限列表」描述；L2324/L2326/L3804/L3808 版本与设计规范引用同步更新 |
| `F1_ClipMind_测试用例表.md` | 版本 v1.4 → v1.5（基于设计规范 v1.7）；新增 TC-24-05 辅助功能请求触发 TCC 提示（PermissionRequesterTests.testRequestAccessibilityPassesPromptTrue，XCTest，✅ COVERED）；6.1 节总数 82→83、平均每 AC 用例数 3.15→3.19；6.2 节 AC-24 用例数 3→4（✅3 ❌1）；6.3 节 XCTest 54→55、合计 82→83；6.4 节 ✅ COVERED 43→44、合计 82→83；6.5 节 F1.7 用例数 22→23、XCTest 13→14；1.4 节测试组织结构树补充 `App/AppIconAssetTests.swift`、`Privacy/PermissionRequesterTests.swift`、`UI/PermissionIconSymbolTests.swift` |

## 为什么

### Bug 1：辅助功能图标不显示

**根因**：`Image(systemName: "accessibility")` 使用的 SF Symbol 名称在 macOS 13 运行时不可用（`NSImage(systemSymbolName: "accessibility", accessibilityDescription: nil)` 返回 nil），SwiftUI 静默渲染为空。对照组 `bell.fill` 正常加载。

**修复**：改用 `hand.raised.fill`（macOS 11+ 可用，语义上表示"举手请求权限"）。

### Bug 2：点击「打开系统设置」未自动添加 app

**根因**：`PermissionRequestView.openAccessibilitySettings()` 仅调用 `NSWorkspace.shared.open(url)` 打开系统设置面板，未调用 `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])` 触发系统级 TCC 提示。此 URL scheme 不会自动把当前 app 加入权限列表，用户需手动点 + 添加。

**修复**：新建 `PermissionRequester` 封装 `AXIsProcessTrustedWithOptions` 调用，`openAccessibilitySettings()` 先调用 `PermissionRequester.requestAccessibility()` 触发 TCC 提示，再打开系统设置面板。系统 TCC 提示对话框会自动把 ClipMind 加入辅助功能权限列表，用户只需点开关。

### Bug 3：无 App 图标

**根因**：项目无 `Assets.xcassets`，`project.yml` 未配置 `ASSETCATALOG_COMPILER_APPICON_NAME`，`Info.plist` 无 `CFBundleIconName`。构建产物 `ClipMind.app/Contents/Resources/` 下无 `.icns` 文件、无 `Assets.car`。

**修复**：按 `docs/ClipMind.html` 中 `.logo-mark` 设计（32x32 圆角矩形，紫青渐变背景 #8b5cf6 → #22d3ee，白色剪贴板 SVG）生成 1024x1024 PNG，创建 Asset Catalog（传统 macOS 格式 `idiom="mac", scale="2x", size="512x512"`），配置 Info.plist 和 project.yml。

### AppIcon.appiconset/Contents.json 格式踩坑

初始使用 `universal/macos` 新格式导致 actool 警告 "has an unassigned child"，actool 静默失败不生成 Assets.car。改为传统 macOS 格式（`idiom="mac", scale="2x", size="512x512"`，对应 1024x1024 像素 PNG）后正常编译。

## 影响哪些部分

### 用户可见行为

- 首次启动引导的「权限设置」页面辅助功能权限行前会显示举手图标
- 点击「打开系统设置」按钮会先弹出系统 TCC 提示对话框（自动把 ClipMind 加入权限列表），再跳转到系统设置辅助功能面板
- App 在 Dock / 菜单栏 / 启动台显示品牌图标（紫青渐变 + 白色剪贴板）

### 代码模块

- 新增 `ClipMind/Privacy/PermissionRequester.swift`：封装辅助功能权限请求，提供可注入的 `axTrustedCheck` 闭包便于测试
- `ClipMind/UI/Onboarding/PermissionRequestView.swift`：辅助功能图标 SF Symbol 名称 + `openAccessibilitySettings()` 调用链
- 新增 `ClipMind/Assets.xcassets/`：AppIcon 资源
- `ClipMind/Resources/Info.plist`：新增 `CFBundleIconName`
- `project.yml`：新增 `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`

### 测试

- 新增 6 个 XCTest 用例（3 个测试文件 × 2 个用例），全部通过
- CI 全量回归通过（Build & Test 5m28s 全绿）

### 文档

- 设计规范 v1.7：6.1.3 节权限要求表更新
- 视觉原型 v1.2：辅助功能权限卡片图标 + 描述更新
- 测试用例表 v1.5：新增 TC-24-05 + 统计数字更新

## 关键决策

| 决策 | 选择 | 理由 |
|------|------|------|
| 辅助功能图标 SF Symbol | `hand.raised.fill` | macOS 11+ 可用，语义"举手请求权限"贴合首次启动引导场景；`accessibility` 在 macOS 13 运行时返回 nil |
| TCC 触发 API | `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: true])` | 系统级 API，触发 TCC 提示对话框并自动加入权限列表；可注入闭包便于测试 |
| AppIcon 格式 | 传统 macOS 格式（`idiom="mac", scale="2x", size="512x512"`） | `universal/macos` 新格式导致 actool 警告，传统格式兼容性更好 |
| AppIcon 设计 | 按 `docs/ClipMind.html` logo-mark：紫青渐变 + 白色描边剪贴板 | 与品牌视觉一致 |
| PermissionRequester 测试策略 | 注入 mock 闭包验证 prompt 参数 | 不依赖真实 TCC 状态，测试可重复执行 |
