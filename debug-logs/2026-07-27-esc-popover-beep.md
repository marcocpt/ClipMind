# Bug 修复调试日志：按 ESC 关闭 popover 触发系统提示音

> 日期：2026-07-27 | 功能：F1.11 菜单栏弹窗 | 分支：fix/F1.11-esc-sound-no-beep

## 问题描述

按 ESC 关闭菜单栏 popover（NSPopover）时，macOS 播放系统默认提示音（NSBeep）。
期望行为：ESC 静默关闭 popover，不发出任何声音。

## [前置] 运行日志信息

无运行日志（用户跳过日志获取）。Bug 现象明确，可通过代码审查定位。

## [红灯] 测试用例

新增 `PanelKeyEventHandlerTests`：
- `test_handle_escKey_returnsNilToConsumeEvent`：ESC 事件经处理后应返回 nil（被消费）
- `test_handle_enterKey_propagatesEvent`：Enter 事件应原样返回（保留原行为）
- `test_handle_arrowKeys_propagateEvent`：方向键应原样返回
- `test_handle_unhandledKey_propagatesEvent`：未处理键应原样返回

## [根因调查]

### 代码路径

`UnifiedPastePanelView.startKeyMonitor()`（ClipMind/UI/MenuBar/UnifiedPastePanelView.swift:174-181）：

```swift
keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown)
{ event in
    self.handleKeyEvent(event)
    return event  // ← 问题根源：所有键事件都原样返回，继续传播
}
```

### 数据流追踪

1. 用户按 ESC
2. 系统派发 keyDown 事件
3. `addLocalMonitorForEvents` 闭包拦截：
   - 调用 `handleKeyEvent(event)` → `viewModel.handleEscKey()` → `onEscPressed` → `closePanel()` → popover 关闭
   - **`return event`** → 事件继续传播到 responder chain
4. popover 的 contentViewController / window 不处理 ESC
5. 事件冒泡到 NSResponder 默认实现 `cancelOperation(_:)`
6. `cancelOperation` 默认实现调用 `NSBeep()` → 系统提示音

### 模式对比

`NSEvent.addLocalMonitorForEvents` 闭包返回值语义：
- 返回 `nil` → 消费事件，阻止传播
- 返回 `event` → 继续传播

当前实现统一 `return event`，导致 ESC 必然触发 NSBeep。

## [假设与验证]

**假设**：ESC 事件未被消费是 NSBeep 的根本原因，因为 NSResponder.cancelOperation 默认实现会调用 NSBeep。

**验证方法**：
1. 提取 `PanelKeyEventHandler` 类型，使键盘事件路由逻辑可单元测试
2. 让 `handle(_:)` 对 ESC 返回 `nil`，对其他键返回原事件
3. 单元测试验证返回值契约
4. 实机验证 NSBeep 消失（步骤 4 启动 app 确认）

## [绿灯] 修复实施

### 修改文件

1. **新增** `ClipMind/UI/MenuBar/PanelKeyEventHandler.swift`：
   - 提取键盘事件路由逻辑为独立 struct
   - `handle(_:) -> NSEvent?`：ESC 返回 nil 消费，其他键返回原事件

2. **修改** `ClipMind/UI/MenuBar/UnifiedPastePanelView.swift`：
   - `startKeyMonitor` 闭包改为 `return handler.handle(event)`
   - 移除内联 `handleKeyEvent` 私有方法

### 设计权衡

- 仅消费 ESC，保留 Enter / 方向键传播：避免影响 TextField 文本编辑（箭头移动光标）
- 提取独立 struct：使键盘事件契约可单元测试，符合 TDD 与测试规范第 14 条「先说明最小重构点」

## 总结

根因：`NSEvent.addLocalMonitorForEvents` 闭包统一 `return event` 导致 ESC 传播到 NSResponder 默认 `cancelOperation` 触发 NSBeep。
修复：提取 `PanelKeyEventHandler`，对 ESC 返回 nil 消费事件，其他键保留原行为。
