> 最后更新：2026-07-14 | 版本：v1.0

# API Key 跳过提示框图标延迟显示修复

## 改了什么

修复 API Key 配置页面点击「跳过」按钮时提示框中图标延迟显示的 bug，并新增 XCUITest 回归测试。

### 代码改动（commit 10db04c）

| 改动 | 修复文件 | 改动摘要 |
|------|---------|---------|
| 移除 onChange 两步绑定 | `ClipMind/UI/Onboarding/APIKeyGuideView.swift` | `triggerSkipAlert: Binding<Bool>?` → `@Binding var showSkipAlert: Bool`，移除本地 `@State private var showSkipAlert` 和 `onChange(of:)` 代码块 |
| 更新调用方 | `ClipMind/UI/Onboarding/OnboardingView.swift` | `triggerSkipAlert: $showSkipAlert` → `showSkipAlert: $showSkipAlert` |

### 新增测试

| 测试文件 | 测试用例 |
|---------|---------|
| `ClipMindUITests/FirstLaunchUITests.swift` | `testAPIKeySkipAlertShowsContentImmediately`（TC-C-01，验证点击「跳过」后 alert sheet 内容完整出现：标题、确定按钮、取消按钮，点击确定后进入隐私提示页） |

### 文档同步（本次未提交）

| 文档 | 改动 |
|------|------|
| `F1_ClipMind_测试用例表.md` | 版本 v1.6 → v1.7（基于设计规范 v1.7）；新增 TC-C-01（跳过提示框内容完整呈现，XCUITest，✅ COVERED）；1.4 节测试组织结构树补充 `FirstLaunchUITests.swift`/`PermissionRequestUITests.swift`/`PrivacyUITests.swift`；6.1 节总数 84→85、平均 3.23→3.27；6.2 节 AC-24 用例数 5→7（✅4❌1 → ✅6❌1）；6.3 节 XCUITest 12→13、合计 84→85；6.4 节 COVERED 45→46（53.57%→54.12%）、合计 84→85；6.5 节 F1.7 用例数 24→25、XCUITest 5→6 |
| `F1_ClipMind_设计规范.md` | 无需更新（行为描述未变、AC-24 不变、无"当前问题"清单、APIKeyGuideView 内部实现不属于规范层级） |

## 为什么

### 根因：onChange 两步绑定导致渲染循环

`APIKeyGuideView` 使用 `triggerSkipAlert: Binding<Bool>?` + 本地 `@State showSkipAlert` + `onChange(of:)` 两步绑定：

1. 用户点击「跳过」→ 父视图 `showSkipAlert = true`
2. `onChange(of: triggerSkipAlert)` 检测到变化
3. 同一回调中执行两个状态变更：
   - `showSkipAlert = true`（本地状态）→ SwiftUI 开始呈现 alert
   - `triggerSkipAlert?.wrappedValue = false` → 传播回父视图 `showSkipAlert = false`
4. 父视图重渲染传播回子视图 → alert 在呈现过程中收到重渲染信号
5. 内容分两步渲染，图形资源（App 图标）延迟加载

### 修复方案

用直接 `@Binding var showSkipAlert: Bool` 替代两步绑定，消除渲染循环。alert 一次性完整呈现，图标与提示框同步显示。

### 辅助因素

`AppIcon.appiconset/Contents.json` 仅有一个 512x512@2x（1024x1024）条目。NSAlert 需要 64x64 尺寸的图标，运行时缩放可能加重延迟。本次未修复此辅助因素，留待后续优化。

## 版本记录

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0 | 2026-07-14 | 初始版本，记录 API Key 跳过提示框图标延迟显示修复 |
