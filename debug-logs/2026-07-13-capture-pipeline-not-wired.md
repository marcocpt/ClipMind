# Bug 修复日志: 复制内容后 app 中没有任何内容

## 问题描述

用户复制任何内容后，ClipMind 的 popover 和主窗口均显示「暂无剪贴历史」，
没有任何被捕获的条目。

## [前置] 运行日志信息

无运行日志（PasteboardWatcher 从未启动，`[Capture]` 日志分类无任何输出）。

## [红灯] 测试用例

`CaptureServiceTests` (4 个测试):
- `testStartLoadsExistingClips` - 启动时加载已有历史
- `testCaptureNewTextAppendsToClips` - 新文本捕获后出现在 clips 列表
- `testCaptureSavesToStore` - 新内容持久化到 EncryptedStore
- `testMultipleCapturesAppendInOrder` - 多条捕获按时间倒序追加

## [根因调查] 调查过程

1. 检查 `PasteboardWatcher` 使用情况 → 仅在测试中调用，生产代码 0 引用
2. 检查 `AppDelegate.applicationDidFinishLaunching` → 仅创建 StatusItemController + CleanupService
3. 检查 `MainWindow` / `PopoverView` → `clips = ClipTestData.isUITesting ? ClipTestData.previewClips : []`
   非 UI Test 模式下始终为空
4. 检查 AC-01 设计规范 → "复制文本后 3 秒内出现在 popover 与主窗口历史" 未实现

## [绿灯] 修复实施

新建 `CaptureService`:
- 组装 `PasteboardWatcher` + `EncryptedStore` + `AppDetector`
- `start()`: 加载已有历史 + 设置 `onPasteboardChange` 回调 + 启动轮询
- `handleCapturedContent()`: 保存到 EncryptedStore + 追加到 clips 列表（表头插入）
- 下一轮将在 `AppDelegate` 中实例化并注入到 UI

## 总结

根因是缺少 `CaptureService` 层连接捕获管线到 UI。
单元测试已覆盖启动加载、新内容捕获、持久化、多条追加等核心场景。
下一步在 `AppDelegate` 中集成并注入到 `MainWindow`/`PopoverView`。
