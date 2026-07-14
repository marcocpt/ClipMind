# 窗口缩小宽度时侧边栏内容移出显示窗口

## 问题描述

1. 缩小 ClipMind 主窗口宽度时，左侧侧边栏（NavigationView 第一栏，含搜索栏 SearchBar + 来源筛选 SourceFilter + 历史列表 HistoryListView）内的搜索栏和列表会移出窗口可见区域
2. 期望：缩小窗口宽度时左边导航栏（侧边栏）保持固定不动，不应被推出窗口，内部内容自适应收缩
3. F1.12 曾把侧边栏 minWidth 从 700 改为 350 声称修复"内容溢出"，但问题仍存在

## [前置] 步骤 0 获取的运行日志信息

无日志（AI-test/logs 与当前 logs 目录均为空，用户选择跳过日志获取），基于代码静态分析定位。

## [红灯] 测试用例

文件：`ClipMindTests/UI/MainWindowLayoutTests.swift`（在 F1.12 已有测试基础上追加）

- `testAppWindowMinWidthNotSmallerThanMainWindowMinWidth`：验证 `LayoutConstants.appWindowMinWidth(900) >= mainWindowMinWidth(980)` → 失败（红灯）
- `testAppWindowMinHeightNotSmallerThanMainWindowMinHeight`：验证 `appWindowMinHeight(600) >= mainWindowMinHeight(500)` → 通过（非红灯项）

测试基础设施：将 `ClipMindApp.swift` 外层 frame 字面量 `900/600` 提取为 `LayoutConstants.appWindowMinWidth/appWindowMinHeight` 常量并引用，使外层 frame 值可被单元测试观测。

红灯验证：本机 macOS 12.5.1 < deployment target 13.0，无法本地执行 xcodebuild test（与 F1.13 修复的 macOS 12 兼容性问题相同）。通过代码审查确认红灯逻辑：`XCTAssertGreaterThanOrEqual(900, 980)` = false → 失败。XCTest + XCUITest 全量验证延迟到步骤 3.2.5 CI。

## [根因调查] 调查过程

### 代码定位

`ClipMind/App/ClipMindApp.swift:14`（外层 frame）：
```swift
if hasCompletedOnboarding {
    MainWindow()
        .frame(minWidth: 900, minHeight: 600)  // ← 外层，值 900
}
```

`ClipMind/UI/MainWindow/MainWindow.swift:35`（内层 frame）：
```swift
.frame(minWidth: LayoutConstants.mainWindowMinWidth, minHeight: LayoutConstants.mainWindowMinHeight)  // ← 内层，值 980/500
```

`ClipMind/UI/MainWindow/MainWindow.swift:22`（侧边栏 VStack）：
```swift
.frame(minWidth: LayoutConstants.sidebarMinWidth)  // sidebarMinWidth = 350
```

### 数据流分析

```
WindowGroup 窗口最小尺寸 ← 由最外层视图 frame 决定 ← ClipMindApp 外层 frame(minWidth: 900)
                                                                    ↓ (嵌套)
                                    MainWindow 内层 frame(minWidth: 980) ← 期望 980 但实际收到 900
                                                                    ↓ (冲突)
                            NavigationView(NSSplitViewController) 在 900 宽度下布局
                                                                    ↓
                            sidebar minWidth 350 + detail panel 需要空间
                                                                    ↓ (用户拖宽 sidebar 后缩窗)
                            sidebar 当前宽度 + detail minWidth > 窗口实际宽度 900
                                                                    ↓
                            NSSplitView 将 sidebar 左边缘推出窗口左边界
                                                                    ↓
                            搜索栏 + 列表左侧部分移出窗口可见区域
```

### 模式分析

对比 F1.12 修复：F1.12 把 `LayoutConstants.mainWindowMinWidth` 设为 980（MainWindow 内层），但**遗漏了同步修改 ClipMindApp 外层 frame 的 900**。外层 frame 离窗口更近，优先级更高，实际窗口最小宽度被锁定在 900，内层 980 从未生效。这是 F1.12 修复不完整的遗留问题。

### 近期变更检查

`git log --oneline -3`：
```
5024dfe merge: 合并 F1.12 导航栏宽度溢出修复（700→350）
699b2fc merge: 合并 F1.11 通知权限请求分支修复
0cc0039 merge: 同步 main 分支
```

F1.12 提交修改了 LayoutConstants 与 MainWindow，未触及 ClipMindApp 外层 frame，确认遗漏。

### 根本原因

**ClipMindApp 外层 frame(minWidth: 900) 与 MainWindow 内层 frame(minWidth: 980) 嵌套冲突**。外层 900 < 内层 980，窗口被外层限制到 900，NavigationView 在小于内层期望的宽度下布局，缩窗时 NSSplitView 将侧边栏左边缘推出窗口左边界，导致搜索栏和列表移出可见区域。左边导航栏应固定不动，由窗口最小宽度统一为 980（sidebar 350 + detail 630）保证。

## [绿灯] 修复实施

### 修复方案

1. 在 `LayoutConstants` 新增 `appWindowMinWidth`/`appWindowMinHeight` 常量，初值与历史代码一致（900/600）使红灯可观测
2. `ClipMindApp.swift` 外层 frame 引用常量替代字面量
3. 将 `appWindowMinWidth` 调整为 980、`appWindowMinHeight` 调整为 500，与 `mainWindowMinWidth/Height` 对齐，消除嵌套冲突

### 修改文件

- `ClipMind/UI/MainWindow/LayoutConstants.swift`（修改）：新增 `appWindowMinWidth=980`、`appWindowMinHeight=500` 常量及文档注释
- `ClipMind/App/ClipMindApp.swift`（修改）：外层 frame 引用 `LayoutConstants.appWindowMinWidth/appWindowMinHeight` 替代字面量 900/600
- `ClipMindTests/UI/MainWindowLayoutTests.swift`（修改）：新增 `testAppWindowMinWidthNotSmallerThanMainWindowMinWidth`、`testAppWindowMinHeightNotSmallerThanMainWindowMinHeight` 两个不变量测试

### 验证结果

- XCTest 本地绿灯：本机 macOS 12.5.1 < 13.0 无法本地执行，通过代码审查确认绿灯逻辑（980>=980, 500>=500 均通过）
- XCUITest + 全量回归：延迟到步骤 3.2.5 走 CI（macOS 15 runner）

## 总结

根因为 F1.12 修复遗漏：改了 MainWindow 内层 frame(980) 但未同步 ClipMindApp 外层 frame(900)，嵌套冲突导致窗口实际最小宽度 900 小于内层期望 980，缩窗时侧边栏被推出窗口。修复为提取外层 frame 为命名常量并调整为 980/500 与内层对齐，新增不变量测试防止回归。
