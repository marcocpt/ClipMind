# 侧边栏宽度太窄，至少 700

## 问题描述

ClipMind macOS App 的 MainWindow 使用 `NavigationView` 双栏布局，左侧栏（搜索面板 + 历史列表/搜索结果）当前未设置 `minWidth`，导致 macOS 默认侧边栏宽度偏窄（约 200-300pt），用户期望最小宽度为 700pt。

## 前置：步骤 0 获取的运行日志信息

无运行日志（两个 logs 目录均为空，用户选择跳过日志获取）。通过代码静态分析定位。

## [红灯] 测试用例

新增 UI 测试 `testSidebarMinWidth700`，验证侧边栏宽度 >= 700pt：

- 在 `MainWindow.swift` 的侧边栏 VStack 上添加 `accessibilityIdentifier("sidebarContainer")`（测试基础设施）
- 在 `MainWindowUITests.swift` 新增测试：启动 App → 查找 `sidebarContainer` → 断言 `frame.width >= 700`

## [根因调查] 调查过程

### 证据收集

1. `MainWindow.swift:16-25` 使用 `NavigationView`：
   ```swift
   NavigationView {
       VStack(spacing: 0) {
           searchPanel
           Divider()
           contentArea
       }
       DetailPanel(clip: selectedClip) { updated in
           selectedClip = updated
       }
   }
   ```
   - 侧边栏 VStack 无 `minWidth` 约束
   - DetailPanel 有 `minWidth: 200`（DetailPanel.swift:150）

2. `MainWindow.swift:34` 设置 `.frame(minWidth: 800, minHeight: 500)` — 窗口最小宽度 800pt
   - 若侧边栏需要 700pt + 详情面板需要 200pt = 900pt，当前窗口 minWidth 800 不足以容纳两者

### 数据流跟踪

- `NavigationView` 在 macOS 上创建 `NSSplitViewController`，第一列为侧边栏
- 侧边栏内容为 VStack(searchPanel + Divider + contentArea)
- 无 `minWidth` 时，`NSSplitView` 按系统默认（约 200pt）分配侧边栏宽度
- 用户拖拽分割线时，侧边栏可被压缩至 0

### 模式分析

对比 DetailPanel.swift:150 的 `.frame(minWidth: 200)`，侧边栏 VStack 缺少对等的 `minWidth` 约束。

### 假设与验证

**假设**：侧边栏 VStack 缺少 `minWidth` 约束是根本原因，因为 macOS NavigationView 默认侧边栏宽度由系统决定（约 200pt），不满足用户 700pt 需求。

**验证**：添加 `.frame(minWidth: 700)` 到侧边栏 VStack，并将窗口 minWidth 从 800 提升到 980（= 700 + 200 + 80 余量），确保两个最小宽度约束不冲突。

## [绿灯] 修复实施

### 修改文件

1. `ClipMind/UI/MainWindow/MainWindow.swift`：
   - 侧边栏 VStack 添加 `.frame(minWidth: 700)`
   - 窗口 `.frame(minWidth: 800, minHeight: 500)` → `.frame(minWidth: 980, minHeight: 500)`
2. `ClipMindUITests/MainWindowUITests.swift`：
   - 新增 `testSidebarMinWidth700` 测试，通过详情面板文本位置反推侧边栏宽度

### 单测试绿灯结果

本地执行 `xcodebuild test -only-testing:ClipMindUITests/MainWindowUITests/testSidebarMinWidth700`：
- 红灯：`XCTAssertGreaterThanOrEqual failed: ("343.0") is less than ("700.0")` — 侧边栏默认宽度 343pt
- 绿灯：Test passed (4.944 seconds) — 添加 `.frame(minWidth: 700)` 后通过

### 全量回归

延迟到步骤 3.3.5 走 CI 验证。

## 总结

- 根本原因：侧边栏 VStack 缺少 `minWidth` 约束
- 修复方案：添加 `.frame(minWidth: 700)` 并同步提升窗口 minWidth 至 980
- 测试：UI 测试验证侧边栏宽度 >= 700pt
