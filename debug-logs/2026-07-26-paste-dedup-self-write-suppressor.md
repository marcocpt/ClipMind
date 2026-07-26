# Bug 3：双击粘贴后列表出现重复条目

> 调试日期：2026-07-26 | 关联功能：F1.9 / F1.11

## 问题描述

用户在快速粘贴面板（或菜单栏弹窗、主窗口）双击列表中的剪贴项触发粘贴后，
列表顶部出现一条与已存在条目内容完全相同的重复记录。

## 复现条件

1. 用户先复制内容 A → ClipMind 入库（lastContentHash = hash(A)）
2. 用户再复制内容 B → ClipMind 入库（lastContentHash = hash(B)）
3. 用户呼出快速粘贴面板，双击列表中的 A 触发粘贴
4. PasteCoordinator → ClipboardWriter.write(text: A) → 剪贴板 changeCount +1
5. PasteboardWatcher 检测到 changeCount 变化，走捕获流程
6. Deduplicator.isDuplicate(A): lastContentHash == hash(B)，A ≠ B，返回 false（不视为重复）
7. A 被当作新捕获的内容入库 → 列表出现重复

## 根因调查

### 数据流追踪

- 双击入口：`UnifiedPastePanelViewModel.handleDoubleClick(clip:)` → `onPasteTriggered?(clip)`
- 粘贴协调：`PasteCoordinator.handlePaste(clip:)` ([PasteCoordinator.swift#L89-L131](file:///Users/dengdeng/Working/Competition/ClipMind-worktrees/fix/F1.11-list-toolbar-dedup/ClipMind/UI/QuickPaste/PasteCoordinator.swift#L89-L131))
- 写入剪贴板：`ClipboardWriter.write(text:)` ([ClipboardWriter.swift#L29-L39](file:///Users/dengdeng/Working/Competition/ClipMind-worktrees/fix/F1.11-list-toolbar-dedup/ClipMind/UI/QuickPaste/ClipboardWriter.swift#L29-L39))
- 监听剪贴板：`PasteboardWatcher.handlePasteboardChange()` ([PasteboardWatcher.swift#L91-L131](file:///Users/dengdeng/Working/Competition/ClipMind-worktrees/fix/F1.11-list-toolbar-dedup/ClipMind/Capture/PasteboardWatcher.swift#L91-L131))
- 自我写入抑制：`SelfWriteSuppressor` ([SelfWriteSuppressor.swift](file:///Users/dengdeng/Working/Competition/ClipMind-worktrees/fix/F1.11-list-toolbar-dedup/ClipMind/AutoSave/SelfWriteSuppressor.swift))

### 已有抑制机制（仅 F2.1 路径使用）

`SelfWriteSuppressor` 已经存在并被正确接入 F2.1 自动保存路径：

- `ClipMindApp.swift` 创建唯一共享实例：`let suppressor = SelfWriteSuppressor()` (line 210)
- 注入到 `AutoSaveService`（F2.1 替换剪贴板为文件路径后，由 `ClipboardReplacer.replace` 内部调用 `markSelfWrite`）
- 注入到 `PasteboardWatcher`（在 `handlePasteboardChange` 中调用 `checkAndReset` 命中则跳过捕获）

### 缺陷：F1.9 粘贴路径未接入抑制器

`PasteCoordinator` 装配点共有 3 处，每处都新建 `ClipboardWriter()` 实例，**均未传入共享的 `SelfWriteSuppressor`**：

1. `QuickPasteAssembly.makePasteCoordinator` ([QuickPasteAssembly.swift#L108-L122](file:///Users/dengdeng/Working/Competition/ClipMind-worktrees/fix/F1.11-list-toolbar-dedup/ClipMind/App/QuickPasteAssembly.swift#L108-L122))
2. `StatusItemAssembly.setupStatusItemController` ([StatusItemAssembly.swift#L34-L39](file:///Users/dengdeng/Working/Competition/ClipMind-worktrees/fix/F1.11-list-toolbar-dedup/ClipMind/App/StatusItemAssembly.swift#L34-L39))
3. `PopoverPreviewWindowFactory` ([PopoverPreviewWindowFactory.swift#L118-L122](file:///Users/dengdeng/Working/Competition/ClipMind-worktrees/fix/F1.11-list-toolbar-dedup/ClipMind/App/PopoverPreviewWindowFactory.swift#L118-L122))

并且 `ClipboardWriter` 本身也没有 `suppressor` 入参，写入成功后不会调用 `markSelfWrite`。

### 根因结论

**F1.9 粘贴路径缺少自我写入抑制：`ClipboardWriter` 写入剪贴板后未通知 `SelfWriteSuppressor`，导致 `PasteboardWatcher` 把这次"应用自己写入"误识别为"用户外部新复制"，从而把已存在的 clip 当作新内容入库。**

为什么 `Deduplicator` 没拦住？`Deduplicator` 只比较"上一条已入库内容的哈希"。若用户在外部先复制了 B（lastContentHash=hash(B)），再双击粘贴 A，A 与 B 不同 → 不视为重复 → 入库。只有当用户连续两次双击同一个 A 时 deduplicator 才能拦住，但实际场景中用户经常在外部复制新内容后回头双击历史里的旧条目。

## 修复方案

将共享的 `SelfWriteSuppressor` 注入到 `ClipboardWriter`，写入成功后立即调用 `markSelfWrite(changeCount:)`：

1. `ClipboardWriter`：新增 `suppressor: SelfWriteSuppressor? = nil` 入参；`write(text:)` 成功后读取 `pasteboard.changeCount` 并调用 `suppressor?.markSelfWrite(changeCount:)`
2. `ClipMindApp`：将 `selfWriteSuppressor` 由 `private` 改为 `internal`，使 extension 可访问
3. `QuickPasteAssembly` / `StatusItemAssembly` / `PopoverPreviewWindowFactory`：构造 `ClipboardWriter` 时传入共享 `selfWriteSuppressor`

## 红灯测试

- `testWriteText_MarksSelfWrite_WhenSuppressorProvided`：写入成功后应调用 markSelfWrite，使 checkAndReset 命中
- `testWriteText_WithSharedSuppressor_PasteboardWatcherSkipsCapture`：端到端验证 ClipboardWriter 写入后 PasteboardWatcher 不触发 onPasteboardChange 回调

## 绿灯修复

### 修改文件

1. `ClipMind/UI/QuickPaste/ClipboardWriter.swift`：新增 `suppressor: SelfWriteSuppressor? = nil` 入参；`write(text:)` 成功后读取 `pasteboard.changeCount` 并调用 `suppressor?.markSelfWrite(changeCount:)`
2. `ClipMind/App/ClipMindApp.swift`：将 `selfWriteSuppressor` 由 `private` 改为 `internal`，使 extension 可访问；`PopoverPreviewWindowFactory.show` 调用点传入共享 suppressor
3. `ClipMind/App/QuickPasteAssembly.swift`：`makePasteCoordinator` 内 `ClipboardWriter(suppressor: selfWriteSuppressor)`
4. `ClipMind/App/StatusItemAssembly.swift`：`setupStatusItemController` 内 `ClipboardWriter(suppressor: selfWriteSuppressor)`
5. `ClipMind/App/PopoverPreviewWindowFactory.swift`：`show` 与 `configurePasteTrigger` 新增 `suppressor` 参数，`--UITEST_FORCE_NO_PERMISSION` 路径注入到 ClipboardWriter

### 本地 XCTest 绿灯验证

```
Test Suite 'ClipboardWriterTests' passed (0.007 seconds)
  Executed 7 tests, with 0 failures (0 unexpected)
  - testWriteText_ReturnsTrue_AndWritesToPasteboard ✓
  - testWriteText_EmptyString_ReturnsTrue ✓
  - testWriteText_IncreasesChangeCount ✓
  - testWriteText_MultibyteContent_PersistsCorrectly ✓
  - testWriteText_MarksSelfWrite_WhenSuppressorProvided ✓ (新)
  - testWriteText_WithoutSuppressor_StillSucceeds ✓ (新)
  - testWriteText_WithSharedSuppressor_PasteboardWatcherSkipsCapture ✓ (新)

Test Suite 'SelfWriteSuppressorTests' passed (0.213 seconds)
  Executed 5 tests, with 0 failures (0 unexpected)
```

XCUITest 全量回归与全量 XCTest 回归延迟到步骤 3.2.5 提交后由 CI 验证。

## 总结

F1.9 粘贴流程的"自身写入抑制"未接入，是 F2.1 设计时遗留的盲区。本修复将 F2.1 已建立的 `SelfWriteSuppressor` 共享机制延伸到 F1.9 粘贴路径，使两条路径对"应用自己写剪贴板"的处理一致。
