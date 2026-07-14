# 导航栏宽度 700 过宽 & 窗口缩小内容溢出

## 问题描述

1. 导航栏（侧边栏）最小宽度为 700，太宽，需改为 350
2. 缩小窗口到最小时，导航栏中的搜索框和列表偏移出窗口，导致部分看不到

## [前置] 步骤 0 获取的运行日志信息

无日志（两个 logs 目录均为空），基于代码审查调试。

## [红灯] 测试用例

文件：`ClipMindTests/UI/MainWindowLayoutTests.swift`

- `testSidebarMinWidthIs350`：验证 `LayoutConstants.sidebarMinWidth == 350`（当前 700，失败）
- `testSidebarMinWidthDoesNotExceedHalfOfWindow`：验证侧边栏宽度 ≤ 窗口宽度的 50%（700 > 490，失败）
- `testDetailPanelHasPositiveSpaceAtWindowMinimum`：验证窗口最小时详情面板有正空间（通过但仅 280px）
- `testMainWindowMinimumDimensions`：回归保护，验证窗口最小尺寸 980×500（通过）

红灯结果：4 个测试中 2 个失败，符合预期。

## [根因调查] 调查过程

### 代码定位

`ClipMind/UI/MainWindow/MainWindow.swift`:
- 第 22 行：`.frame(minWidth: 700)` — 侧边栏（VStack）最小宽度，魔术数字
- 第 35 行：`.frame(minWidth: 980, minHeight: 500)` — 窗口最小尺寸，魔术数字

### 数据流分析

```
窗口最小宽度 980
├── 侧边栏 minWidth 700（当前）
└── 详情面板 980 - 700 = 280px（仅 280px，非常紧凑）
```

当 NavigationView 侧边栏被用户拖宽（例如 800px），然后窗口缩到最小 980px：
- 侧边栏无法收缩到 700 以下（minWidth 约束）
- 侧边栏 800px + 详情面板需要空间 → 总需求 > 980px
- 侧边栏内容（搜索框 + 列表）溢出窗口边界

### 模式对比

详情面板（DetailPanel.swift）未设置显式 minWidth（仅 rewriteModePicker sheet 有 minWidth 200），
因此侧边栏的 700 minWidth 是导致溢出的根本约束。

### 根本原因

侧边栏 minWidth=700 占窗口 minWidth=980 的 71.4%，远超合理比例。
窗口缩到最小时侧边栏无法充分收缩，搜索框和列表被挤出窗口边界。

## [绿灯] 修复实施

### 修复方案

1. 提取魔术数字为 `LayoutConstants` 命名常量（符合 AGENTS.md 编码规范"避免魔术数字"）
2. 将 `sidebarMinWidth` 从 700 改为 350
3. 更新 `MainWindow.swift` 使用常量替代魔术数字

### 修改文件

- `ClipMind/UI/MainWindow/LayoutConstants.swift`（新增）：布局常量定义
- `ClipMind/UI/MainWindow/MainWindow.swift`（修改）：使用 LayoutConstants 替代魔术数字
- `ClipMindTests/UI/MainWindowLayoutTests.swift`（新增）：布局常量测试

### 验证结果

- XCTest 本地绿灯：4 个测试全部通过
- XCUITest + 全量回归：延迟到步骤 3.2.5 走 CI

## 总结

根因为侧边栏 minWidth 700 过宽（占窗口 71.4%），窗口缩小时侧边栏无法收缩导致内容溢出。
修复为提取命名常量并调整为 350（占窗口 35.7%），留足空间给详情面板。
