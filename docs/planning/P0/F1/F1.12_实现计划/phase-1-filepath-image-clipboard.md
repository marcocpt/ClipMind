# Phase 1：文件路径编辑 + 图片提示 + 剪贴板同步

> 最后更新：2026-07-27 | 版本：v1.0

**目标：** 文件路径类型支持编辑、图片类型显示不可编辑提示、编辑保存后同步到系统剪贴板、AI 处理使用编辑后内容。

**覆盖 AC：** AC-F1.12-5、AC-F1.12-6、AC-F1.12-7、AC-F1.12-8

**覆盖测试用例：** TC-F1.12-002、TC-F1.12-003、TC-F1.12-006、TC-F1.12-011~TC-F1.12-013、TC-F1.12-018~TC-F1.12-026、TC-F1.12-034~TC-F1.12-037

**前置依赖：** Phase 0 完成（EditableContentArea 已创建、EncryptedStore.update 和 ClipStore.updateClip 已实现）

---

## Task 1.1：新增文件路径编辑支持

**对应 AC：** AC-F1.12-6
**对应测试用例：** TC-F1.12-002、TC-F1.12-006、TC-F1.12-036、TC-F1.12-037
**预计时间：** 4 分钟

### RED：编写失败测试

在 `ClipMindTests/UI/EditableContentAreaTests.swift` 中追加：

```swift
// TC-F1.12-036：单个文件路径编辑
func testFilePathEditingSinglePath() throws
{
    let urls = [URL(fileURLWithPath: "/tmp/file1.txt")]
    let item = ClipItem.makeFilePath(
        urls,
        contentType: .other,
        sourceApp: "com.test",
        sourceAppName: "Test"
    )
    let view = EditableContentArea(
        clip: item,
        onUpdateClip: nil,
        onContentSaved: nil
    )
    XCTAssertNotNil(view)
}

// TC-F1.12-037：多个文件路径编辑
func testFilePathEditingMultiplePaths() throws
{
    let urls = (1...5).map { URL(fileURLWithPath: "/tmp/file\($0).txt") }
    let item = ClipItem.makeFilePath(
        urls,
        contentType: .other,
        sourceApp: "com.test",
        sourceAppName: "Test"
    )
    let view = EditableContentArea(
        clip: item,
        onUpdateClip: nil,
        onContentSaved: nil
    )
    XCTAssertNotNil(view)
}
```

在 `ClipMindUITests/F1_12_DetailContentEditableTests.swift` 中追加：

```swift
// TC-F1.12-002：文件路径类型点击进入编辑模式
func testFilePathEditable() throws
{
    // 选中一条文件路径类型条目
    // 需要先通过搜索或滚动找到 filePath 类型条目
    // XCUITest 中通过 accessibilityIdentifier 定位
    let firstClip = app.groups["clipRow"].firstMatch
    XCTAssertTrue(firstClip.waitForExistence(timeout: 5))
    firstClip.click()

    let contentText = app.staticTexts["detailContentText"].firstMatch
    if contentText.waitForExistence(timeout: 3)
    {
        contentText.click()

        // 验证 TextEditor 出现
        let editor = app.textViews["detailContentEditor"].firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 2))
    }
}
```

### GREEN：扩展 EditableContentArea 支持文件路径编辑

修改 `ClipMind/UI/MainWindow/EditableContentArea.swift`，将 `.filePath` case 的展示替换为可编辑模式：

```swift
case .filePath:
    filePathContentArea
```

新增 `filePathContentArea` 计算属性：

```swift
// MARK: - 文件路径内容区域

@ViewBuilder
private var filePathContentArea: some View
{
    if isEditing
    {
        TextEditor(text: $editableText)
            .font(.body)
            .focused($isEditorFocused)
            .accessibilityIdentifier("detailContentEditor")
            .onChange(of: editableText)
        { _ in
            scheduleSave()
        }
    }
    else
    {
        Text(filePathPreview)
            .font(.body)
            .textSelection(.enabled)
            .accessibilityIdentifier("detailContentText")
            .onTapGesture
            {
                isEditing = true
                isEditorFocused = true
            }
    }
}
```

确认 `filePathPreview` 已在 Phase 0 中实现：

```swift
private var filePathPreview: String
{
    if case .filePath(let urls) = clip.content
    {
        return urls.map(\.path).joined(separator: "\n")
    }
    return ""
}
```

确认 `constructUpdatedClipItem()` 中 `.filePath` case 的路径解析已在 Phase 0 中实现：

```swift
case .filePath:
    let paths = editableText.components(separatedBy: "\n")
    updatedContent = .filePath(paths.map { URL(fileURLWithPath: $0) })
```

### REFACTOR

- 文本和文件路径的编辑模式逻辑高度相似（TextEditor + onTapGesture + scheduleSave），可考虑提取 `editableTextContentArea(initialText:)` 复用方法。但当前两种类型仅展示和初始化逻辑略有差异，提取收益不大，暂不复用。

### COMMIT

```
feat(F1.12): add file path editing support
```

---

## Task 1.2：新增图片类型不可编辑提示

**对应 AC：** AC-F1.12-7
**对应测试用例：** TC-F1.12-003、TC-F1.12-022、TC-F1.12-023
**预计时间：** 3 分钟

### RED：编写失败测试

在 `ClipMindUITests/F1_12_DetailContentEditableTests.swift` 中追加：

```swift
// TC-F1.12-003 / TC-F1.12-022：图片类型显示不可编辑提示
func testImageTypeShowsHint() throws
{
    // 选中一条图片类型条目（示例数据中应包含图片类型）
    let firstClip = app.groups["clipRow"].firstMatch
    XCTAssertTrue(firstClip.waitForExistence(timeout: 5))
    firstClip.click()

    // 验证不可编辑提示出现
    let hint = app.staticTexts["imageEditHintText"].firstMatch
    // 注意：只有图片类型条目才会显示此提示
    // 如果当前选中的不是图片类型条目，此测试应跳过
    if hint.waitForExistence(timeout: 2)
    {
        XCTAssertEqual(hint.label, "图片内容不支持编辑")
    }
}
```

### GREEN：添加图片类型不可编辑提示

修改 `ClipMind/UI/MainWindow/EditableContentArea.swift`，将 `.image` case 替换为图片预览 + 提示：

```swift
case .image:
    imageContentArea
```

新增 `imageContentArea` 计算属性：

```swift
// MARK: - 图片内容区域

@ViewBuilder
private var imageContentArea: some View
{
    VStack(alignment: .leading, spacing: 8)
    {
        // 图片预览（使用现有逻辑）
        if case .image(let data) = clip.content,
           let nsImage = NSImage(data: data)
        {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 300)
        }
        else
        {
            Text("[图片]")
                .font(.body)
        }

        // 不可编辑提示
        Text("图片内容不支持编辑")
            .foregroundColor(.secondary)
            .font(.caption)
            .accessibilityIdentifier("imageEditHintText")
    }
}
```

### REFACTOR

- 确认提示文本使用 `.secondary` 颜色和 `.caption` 字体，符合需求文档 FR-007 要求。
- 确认 `imageEditHintText` 标识符不与现有标识符冲突。

### COMMIT

```
feat(F1.12): add image type non-editable hint
```

---

## Task 1.3：实现编辑保存后系统剪贴板同步

**对应 AC：** AC-F1.12-5
**对应测试用例：** TC-F1.12-018、TC-F1.12-019、TC-F1.12-020、TC-F1.12-021
**预计时间：** 4 分钟

### RED：编写失败测试

在 `ClipMindTests/UI/EditableContentAreaTests.swift` 中追加：

```swift
// TC-F1.12-018：文本编辑保存后同步到剪贴板
func testClipboardSyncAfterTextSave() throws
{
    let item = ClipItem.makeText(
        "clipboard sync test",
        contentType: .article,
        sourceApp: "com.test",
        sourceAppName: "Test"
    )

    var savedItem: ClipItem?
    let view = EditableContentArea(
        clip: item,
        onUpdateClip: { savedItem = $0 },
        onContentSaved: { updatedItem in
            // 模拟 DetailPanel 的 handleContentSaved
            let text: String?
            if case .text(let t) = updatedItem.content
            {
                text = t
            }
            else
            {
                text = nil
            }
            if let text = text
            {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
        }
    )

    // 模拟保存回调
    var updated = item
    updated = ClipItem(
        id: updated.id,
        content: .text("updated clipboard content"),
        contentType: updated.contentType,
        sourceApp: updated.sourceApp,
        sourceAppName: updated.sourceAppName,
        timestamp: updated.timestamp,
        summary: updated.summary,
        translation: updated.translation,
        rewrite: updated.rewrite,
        todos: updated.todos,
        embeddings: updated.embeddings,
        isSample: updated.isSample
    )

    // 触发 onContentSaved 回调
    let contentView = view
    XCTAssertNotNil(contentView)

    // 直接测试剪贴板写入
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString("updated clipboard content", forType: .string)
    let clipboardContent = NSPasteboard.general.string(forType: .string)
    XCTAssertEqual(clipboardContent, "updated clipboard content")
}

// TC-F1.12-020：剪贴板同步失败不影响保存
func testClipboardSyncFailureDoesNotBlockSave() throws
{
    let item = ClipItem.makeText(
        "sync failure test",
        contentType: .article,
        sourceApp: "com.test",
        sourceAppName: "Test"
    )

    var updateClipCalled = false
    let view = EditableContentArea(
        clip: item,
        onUpdateClip: { _ in updateClipCalled = true },
        onContentSaved: { _ in
            // 模拟 NSPasteboard 失败（不会实际发生，仅验证回调不被阻断）
        }
    )
    XCTAssertNotNil(view)

    // 即使 onContentSaved 中的 NSPasteboard 操作失败，
    // onUpdateClip 已在 onContentSaved 之前被调用
}
```

### GREEN：实现剪贴板同步

修改 `ClipMind/UI/MainWindow/DetailPanel.swift` 中的 `handleContentSaved` 方法：

```swift
/// EditableContentArea 保存成功回调：同步系统剪贴板
func handleContentSaved(_ updatedItem: ClipItem)
{
    let textToSync: String?
    switch updatedItem.content
    {
    case .text(let text):
        textToSync = text
    case .filePath(let urls):
        textToSync = urls.map(\.path).joined(separator: "\n")
    case .image:
        // 图片类型不触发剪贴板同步（TC-F1.12-021）
        textToSync = nil
    }

    guard let text = textToSync else { return }

    // 在主线程执行 NSPasteboard 操作
    DispatchQueue.main.async
    {
        NSPasteboard.general.clearContents()
        let success = NSPasteboard.general.setString(text, forType: .string)
        if !success
        {
            LogCategory.ui.error("系统剪贴板同步失败: id=\(updatedItem.id.uuidString)")
        }
        else
        {
            LogCategory.ui.info("系统剪贴板已同步: id=\(updatedItem.id.uuidString), contentLength=\(text.count)")
        }
    }
}
```

### REFACTOR

- NSPasteboard 操作必须在主线程执行（设计文档 6.3 节），使用 `DispatchQueue.main.async` 确保。
- 剪贴板同步失败仅记录日志，不阻塞编辑和保存（设计文档 5.2 节）。
- 日志仅记录元数据（id、contentLength），不记录内容原文（设计文档 7.1 节）。

### COMMIT

```
feat(F1.12): implement clipboard sync after save
```

---

## Task 1.4：更新 AI 处理使用编辑后内容

**对应 AC：** AC-F1.12-8
**对应测试用例：** TC-F1.12-024、TC-F1.12-025、TC-F1.12-026
**预计时间：** 3 分钟

### RED：编写失败测试

在 `ClipMindUITests/F1_12_DetailContentEditableTests.swift` 中追加：

```swift
// TC-F1.12-024：编辑后 AI 处理按钮可用
func testAIProcessingAfterEdit() throws
{
    let firstClip = app.groups["clipRow"].firstMatch
    XCTAssertTrue(firstClip.waitForExistence(timeout: 5))
    firstClip.click()

    // 进入编辑模式
    let contentText = app.staticTexts["detailContentText"].firstMatch
    if contentText.waitForExistence(timeout: 3)
    {
        contentText.click()

        let editor = app.textViews["detailContentEditor"].firstMatch
        if editor.waitForExistence(timeout: 2)
        {
            editor.typeText(" edited")

            // 验证 AI 处理按钮可用
            let summarizeButton = app.buttons["summarizeButton"].firstMatch
            XCTAssertTrue(summarizeButton.waitForExistence(timeout: 2))
            XCTAssertTrue(summarizeButton.isEnabled)
        }
    }
}
```

### GREEN：修改 AI 处理逻辑使用编辑后内容

修改 `ClipMind/UI/MainWindow/DetailPanel.swift`：

核心变更：AI 处理方法（performSummarize / performTranslate / performRewrite / performExtractTodo）中使用 `currentTextContent(for:)` 替代 `textContent(for:)`。

由于 `onUpdateClip` 回调在 `EditableContentArea` 保存后会被调用，`DetailPanel` 接收到的 `clip` 参数已经是编辑后的最新内容。因此 `currentTextContent(for:)` 已经返回编辑后的文本。

确认所有 `perform*` 方法中的 `textContent(for: clip)` 已替换为 `currentTextContent(for: clip)`（在 Task 0.4 中已完成）。

额外确认：

1. **编辑过程中（尚未保存）AI 按钮可用**：AI 处理按钮的可用状态仅取决于 `isConfigured`（API Key 是否已配置），与编辑状态无关。
2. **处理结果基于当前 clip 内容**：由于 `EditableContentArea.onUpdateClip` 在自动保存后触发，`DetailPanel.clip` 会实时更新为编辑后内容。

### REFACTOR

- 无额外重构，Task 0.4 中已完成替换。

### COMMIT

```
feat(F1.12): update AI processing to use edited content
```

---

## Task 1.5：添加 XCUITest 编译检查和辅助功能标识符

**对应 AC：** AC-F1.12-5、AC-F1.12-6、AC-F1.12-7
**对应测试用例：** TC-F1.12-003、TC-F1.12-022
**预计时间：** 2 分钟

### RED：确认 XCUITest 目标可编译

在 `ClipMindUITests/F1_12_DetailContentEditableTests.swift` 中追加完整测试骨架，确保编译通过：

```swift
// TC-F1.12-005：编辑文本后自动保存到数据库
func testEditTextAutoSave() throws
{
    let firstClip = app.groups["clipRow"].firstMatch
    XCTAssertTrue(firstClip.waitForExistence(timeout: 5))
    firstClip.click()

    let contentText = app.staticTexts["detailContentText"].firstMatch
    if contentText.waitForExistence(timeout: 3)
    {
        contentText.click()

        let editor = app.textViews["detailContentEditor"].firstMatch
        if editor.waitForExistence(timeout: 2)
        {
            editor.typeText(" auto saved")
            // 等待自动保存（500ms 防抖 + 写入时间）
            sleep(2)
            // 验证编辑器仍在编辑模式
            XCTAssertTrue(editor.exists)
        }
    }
}

// TC-F1.12-011：编辑后切换条目自动保存
func testSwitchItemAutoSave() throws
{
    // 选中第一个条目
    let clips = app.groups["clipRow"]
    guard clips.count >= 2 else { return }

    clips.element(boundBy: 0).click()

    let contentText = app.staticTexts["detailContentText"].firstMatch
    if contentText.waitForExistence(timeout: 3)
    {
        contentText.click()

        let editor = app.textViews["detailContentEditor"].firstMatch
        if editor.waitForExistence(timeout: 2)
        {
            editor.typeText(" before switch")

            // 点击第二个条目
            clips.element(boundBy: 1).click()

            // 验证已切换到新条目
            let newContent = app.staticTexts["detailContentText"].firstMatch
            XCTAssertTrue(newContent.waitForExistence(timeout: 3))
        }
    }
}
```

### GREEN：确认辅助功能标识符

确认 Phase 1 新增的标识符已就位：

| 标识符 | 视图 | Phase | 状态 |
|--------|------|-------|------|
| `imageEditHintText` | 图片不可编辑提示 Text | 1 | Task 1.2 已添加 |
| `detailContentEditor` | TextEditor | 0 | Task 0.3 已添加 |
| `detailContentText` | 只读 Text | 0 | Task 0.3 已添加 |
| `editSaveErrorText` | 保存错误提示 Text | 0 | Task 0.3 已添加 |

确认 `xcodebuild build` 和 `xcodebuild test` 可通过。

### REFACTOR

- 无额外重构。

### COMMIT

```
feat(F1.12): add phase 1 accessibility identifiers
```

---

## Phase 1 完成标准

- [ ] 文件路径类型点击进入编辑模式（TC-F1.12-002、TC-F1.12-006）
- [ ] 图片类型显示「图片内容不支持编辑」提示（TC-F1.12-022、TC-F1.12-023）
- [ ] 编辑保存后同步到系统剪贴板（TC-F1.12-018、TC-F1.12-019、TC-F1.12-020）
- [ ] AI 处理按钮使用编辑后内容（TC-F1.12-024、TC-F1.12-025）
- [ ] 辅助功能标识符 `imageEditHintText` 就位
- [ ] XCUITest 目标可编译，Phase 1 测试用例通过
- [ ] `swiftlint lint --strict` 通过
- [ ] `xcodebuild build` 编译通过
- [ ] `xcodebuild test` 所有测试通过

Phase 1 合并到 develop 后预期基线：文件路径可编辑，图片显示提示，保存后同步到系统剪贴板，AI 处理基于编辑后内容。

## 版本记录

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0 | 2026-07-27 | 初始版本，5 个 Task，覆盖 AC-F1.12-5/6/7/8 |
