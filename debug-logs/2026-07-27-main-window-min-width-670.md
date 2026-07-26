# F1.15 主窗口最小宽度改为 670

## 问题描述

当前主窗口最小宽度为 980（`LayoutConstants.mainWindowMinWidth` 与 `LayoutConstants.appWindowMinWidth` 均为 980），过宽影响小屏使用体验。需求：将主窗口最小宽度调整为 670。

## 前置

- 步骤 0 获取的运行日志信息：仓库与 AI-Test worktree 均无 `logs/` 目录，跳过日志获取
- 基线 CI 状态：develop 分支原 ci.yml 不触发 CI，本次先开独立分支 `refactor/public-file-ci-develop-trigger` 修改 ci.yml 添加 develop 触发，合并后 push develop 触发 CI 验证基线（commit `253ed9b`，CI success）

## 红灯（TDD 步骤 2.1）

新增/修改 `ClipMindTests/UI/MainWindowLayoutTests.swift` 测试用例：

- 新增 `testMainWindowMinWidthIs670`：断言 `LayoutConstants.mainWindowMinWidth == 670`
- 新增 `testAppWindowMinWidthIs670`：断言 `LayoutConstants.appWindowMinWidth == 670`
- 修改 `testMainWindowMinimumDimensions`：断言 `mainWindowMinWidth == 670`（原 980）
- 修改 `testSidebarMinWidthDoesNotExceedHalfOfWindow` → `testSidebarMinWidthDoesNotExceedSixtyPercentOfWindow`：50% 约束放宽到 60%（350/670=52.2% > 50%，但详情面板剩 320px 仍大于 DetailPanel.minWidth=200）

红灯验证（`xcodebuild test -only-testing:ClipMindTests/MainWindowLayoutTests`）结果：

```
Executed 8 tests, with 3 failures (0 unexpected) in 0.201 (0.202) seconds
Failing tests:
    MainWindowLayoutTests.testAppWindowMinWidthIs670()
    MainWindowLayoutTests.testMainWindowMinimumDimensions()
    MainWindowLayoutTests.testMainWindowMinWidthIs670()
```

3 个测试因正确原因失败（980.0 != 670.0），非拼写错误。

## 根因调查

- 当前 `LayoutConstants.mainWindowMinWidth = 980`（F1.14 设定）
- 当前 `LayoutConstants.appWindowMinWidth = 980`（F1.14 与 mainWindowMinWidth 对齐）
- 需求：改为 670
- 连锁影响：
  - `appWindowMinWidth` 必须 >= `mainWindowMinWidth`（F1.14 约束），需同步改为 670
  - `sidebarMinWidth=350` 占 670 的 52.2%，超过原 50% 约束，需放宽到 60%
  - 详情面板剩 320px >= DetailPanel.minWidth=200，可正常显示

## 绿灯（TDD 步骤 2.3）

修改 `ClipMind/UI/MainWindow/LayoutConstants.swift`：

- `mainWindowMinWidth`: 980 → 670
- `appWindowMinWidth`: 980 → 670
- 同步更新注释说明 F1.15

绿灯验证（`xcodebuild test -only-testing:ClipMindTests/MainWindowLayoutTests`）结果：

```
Executed 8 tests, with 0 failures (0 unexpected) in 0.004 (0.005) seconds
** TEST SUCCEEDED **
```

8 个测试全部通过。

## 总结

- 修改文件：
  - `ClipMind/UI/MainWindow/LayoutConstants.swift`（mainWindowMinWidth + appWindowMinWidth 改为 670）
  - `ClipMindTests/UI/MainWindowLayoutTests.swift`（新增 2 个测试 + 更新 2 个测试断言）
- XCTest 本地绿灯结果：8/8 通过
- XCUITest + 全量回归延迟到步骤 3.2.5 走 CI
