# F2.1.2 剪贴板保留原始文本修复

> 日期：2026-07-25 | 功能：F2.1.2 | 分支：fix/F2.1.2-clipboard-preserve-original

## 问题描述

ChatGPT 网页点击「复制」按钮触发 F2.1 自动保存后，其他剪贴板 app（如 Paste）只能看到文件路径，看不到原始复制的文本内容。但 Cmd+C 快捷键复制则正常（其他剪贴板 app 能看到原始文本）。

## 前置：步骤 0 获取的运行日志信息

- F2.1 总开关已开启
- 其他剪贴板 app（Paste）中看到的内容：只看到文件路径
- Cmd+C 复制场景：ChatGPT 网页内 Cmd+C，符合 F2.1 预期，Paste 中能看到原始文本
- 无运行日志（用户选择跳过日志获取）

## 根因调查

### 代码路径分析

1. **F2.1 设计意图**（`docs/planning/P1/F2.1/F2.1_自动保存到文件_需求文档.md`）：
   - FR-008 明确规定「文件保存成功后，系统必须将系统剪贴板内容替换为已保存文件的路径」
   - AC-01 验收标准：「剪贴板内容被替换为该文件的纯路径字符串」
   - 这是设计预期的行为，不是实现 bug

2. **`ClipboardReplacer.replace()` 实现**（`ClipMind/AutoSave/ClipboardReplacer.swift`）：
   ```swift
   pasteboard.clearContents()           // 清空所有格式
   pasteboard.setString(newPath, forType: .string)  // 只写入文件路径作为纯文本
   ```
   - `clearContents()` 清空所有剪贴板格式（包括原始文本）
   - `setString(newPath, forType: .string)` 只写入文件路径
   - 结果：剪贴板只剩文件路径，原始文本完全丢失

3. **Cmd+C 与复制按钮的差异**：
   - Cmd+C：浏览器同步写入剪贴板，Paste 等剪贴板 app 有时间在 F2.1 替换前捕获原始文本
   - 网页复制按钮：通过 `navigator.clipboard.writeText()` 异步写入，ClipMind 的 PasteboardWatcher 检测到变化后立即触发 F2.1 替换，Paste 来不及捕获原始文本
   - 时序差异导致 Paste 在两种场景下行为不同

### 根本原因

`ClipboardReplacer.replace()` 调用 `clearContents()` 清空所有格式后，只写入文件路径作为 `public.utf8-plain-text`。原始文本完全丢失，其他剪贴板 app 只能看到文件路径。

## 红灯：测试用例

新增 5 个 XCTest 测试用例到 `ClipMindTests/AutoSave/ClipboardReplacerTests.swift`：

1. `testReplacePreservesOriginalTextAsHTML`：验证替换后剪贴板同时包含文件路径（`.string`）和原始文本（`.html`）
2. `testReplacePreservesOriginalTextWithHtmlSpecialCharacters`：验证 HTML 特殊字符正确转义（`<` → `&lt;` 等）
3. `testReplaceWithNilOriginalTextOnlyWritesPath`：验证 `originalText` 为 nil 时只写入文件路径（向后兼容）
4. `testReplaceWithEmptyOriginalTextOnlyWritesPath`：验证 `originalText` 为空字符串时只写入文件路径
5. `testReplaceWithOriginalTextMarksSelfWrite`：验证保留原文时也正确标记 markSelfWrite

红灯验证：编译失败，`extra argument 'originalText' in call`（5 处），符合预期。

## 绿灯：修复实施

### 修改文件

1. **`ClipMind/AutoSave/ClipboardReplacer.swift`**：
   - `replace(with:expectedChangeCount:)` 方法签名扩展为 `replace(with:originalText:expectedChangeCount:)`，`originalText` 默认值为 `nil`（向后兼容）
   - 当 `originalText` 非空时，调用 `wrapAsHTML(_:)` 包装为 HTML 文档后写入 `public.html` 格式
   - 新增私有静态方法 `wrapAsHTML(_:)`：转义 HTML 特殊字符（`&`、`<`、`>`、`"`、`'`），用 `<pre>` 标签保留原始换行与空白

2. **`ClipMind/AutoSave/AutoSaveService.swift`**：
   - `performSave(event:text:config:)` 中调用 `clipboardReplacer.replace()` 时，传入 `originalText: text`（从 `CaptureEvent.content` 提取的原始文本）

### 设计决策

- **文件路径作为 `public.utf8-plain-text` 主格式**：保留 `@文件路径` 工作流，Cmd+V 粘贴的是文件路径
- **原始文本作为 `public.html` 写入**：其他剪贴板 app（如 Paste）读取 HTML 格式可看到原文
- **`originalText` 默认 nil**：向后兼容，现有调用方不传该参数时行为不变
- **HTML 转义**：防止 XSS 与格式破坏，用 `<pre>` 保留空白格式

## 绿灯验证结果

- 本地 XCTest 单测试文件：8 个测试全部通过（5 新 + 3 旧）
- AutoSave 相关测试套件：AutoSaveServiceTests、AutoSaveIntegrationTests、AutoSaveConcurrencyTests 全部通过，无回归
- XCUITest 验证：延迟到步骤 3.2.5 走 CI

## 总结

bug 根因为 `ClipboardReplacer` 的 `clearContents() + setString(path, .string)` 操作丢失了原始文本，导致其他剪贴板 app 无法捕获原文。修复方案是在写入文件路径的同时，把原始文本以 HTML 格式写入剪贴板，实现「替换但多格式保留」。修复向后兼容（`originalText` 默认 nil），现有测试全部通过。

---

## Round 2：原子写入修复（2026-07-25）

### 用户反馈

Round 1 修复后用户验证：**未修复，Paste 会随机成功**。怀疑两个写入到剪贴板的间隔太短了。

### 根因调查（Round 2）

分析 Round 1 实现的写入时序：

```swift
pasteboard.clearContents()                    // changeCount++ (1)
pasteboard.setString(newPath, forType: .string)  // changeCount++ (2)
pasteboard.setString(html, forType: .html)       // changeCount++ (3)
```

- 每次 `setString(_:forType:)` 都触发 `changeCount++`
- 其他剪贴板 app（如 Paste）监听 changeCount 变化，每次变化时读取剪贴板
- 在 `setString(.string)` 之后、`setString(.html)` 之前读取，只看到文件路径，没看到原始文本
- 在 `setString(.html)` 之后读取，看到完整内容（文件路径 + 原始文本）
- **结果**：其他 app 的读取时机不同，导致"随机成功"

### 红灯：测试用例（Round 2）

新增 1 个 XCTest 测试用例：

- `testReplaceWithOriginalTextIsAtomicWrite`：验证 `replace()` 后 `changeCount` 增量 <= 2（约束原子写入，防止未来退化）

### 绿灯：修复实施（Round 2）

改用 `NSPasteboardItem` + `writeObjects(_:)` 原子写入所有类型：

```swift
let item = NSPasteboardItem()
item.setString(newPath, forType: .string)
if let originalText = originalText, !originalText.isEmpty
{
    let html = Self.wrapAsHTML(originalText)
    item.setString(html, forType: .html)
}
pasteboard.clearContents()
pasteboard.writeObjects([item])
```

- 先在 `NSPasteboardItem` 上设置所有类型，再一次 `writeObjects` 写入
- `clearContents()` + `writeObjects()` 只产生一个完整的对外可见状态
- 消除"只有 string 没 html"的中间不完整状态

### 绿灯验证结果（Round 2）

- 本地 XCTest 单测试文件：8 个测试全部通过（含新增原子写入测试）
- XCUITest 验证：延迟到步骤 3.2.5 走 CI

### 总结（Round 2）

Round 1 的多次 `setString` 产生多个中间状态，其他剪贴板 app 在中途读取到不完整内容。Round 2 改用 `NSPasteboardItem` + `writeObjects` 原子写入，消除中间不完整状态，确保其他 app 看到的要么是旧内容，要么是完整的新内容（文件路径 + 原始文本）。
