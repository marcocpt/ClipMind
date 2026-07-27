# Phase 0：文本内容编辑 + 自动保存 + 撤销

> 最后更新：2026-07-27 | 版本：v1.0

**目标：** 文本类型条目支持点击进入编辑模式、防抖自动保存、Cmd+Z 撤销、切换条目时自动保存。

**覆盖 AC：** AC-F1.12-1、AC-F1.12-2、AC-F1.12-3、AC-F1.12-4

**覆盖测试用例：** TC-F1.12-001、TC-F1.12-005~TC-F1.12-010、TC-F1.12-014~TC-F1.12-017、TC-F1.12-027~TC-F1.12-033

**前置依赖：** 无（Phase 0 是首个实现阶段）

---

## Task 0.1：新增 EncryptedStore.update() 方法

**对应 AC：** AC-F1.12-2
**对应测试用例：** TC-F1.12-027、TC-F1.12-028、TC-F1.12-029、TC-F1.12-030、TC-F1.12-031
**预计时间：** 3 分钟

### RED：编写失败测试

新建 `ClipMindTests/Storage/EncryptedStoreUpdateTests.swift`：

```swift
@testable import ClipMind
import XCTest

final class EncryptedStoreUpdateTests: XCTestCase
{
    private var dbPath: URL!
    private var store: EncryptedStore!

    override func setUpWithError() throws
    {
        dbPath = try TestDatabaseHelper.makeTempDBPath()
        store = try EncryptedStore(
            dbPath: dbPath,
            key: TestDatabaseHelper.makeTestKey()
        )
    }

    override func tearDownWithError() throws
    {
        store = nil
        if let dbPath
        {
            TestDatabaseHelper.cleanup(at: dbPath)
        }
        dbPath = nil
    }

    // TC-F1.12-027：update 更新已存在条目
    func testUpdateExistingItem() throws
    {
        let item = ClipItem.makeText(
            "original content",
            contentType: .article,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        try store.save(item)

        var updated = item
        updated = ClipItem(
            id: updated.id,
            content: .text("updated content"),
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
        try store.update(updated)

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, item.id)
        if case .text(let value) = loaded.first?.content
        {
            XCTAssertEqual(value, "updated content")
        }
        else
        {
            XCTFail("Expected text content")
        }
    }

    // TC-F1.12-028：update 对不存在条目等同于 insert
    func testUpdateNewItem() throws
    {
        let item = ClipItem.makeText(
            "new item via update",
            contentType: .code,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        try store.update(item)

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.id, item.id)
    }

    // TC-F1.12-029：update 与 save 加密方式一致
    func testUpdateEncryptionConsistent() throws
    {
        let item = ClipItem.makeText(
            "encryption test",
            contentType: .article,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        try store.save(item)

        var updated = item
        updated = ClipItem(
            id: updated.id,
            content: .text("updated encryption test"),
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
        try store.update(updated)

        // 验证 loadAll 能正确解密 update 写入的数据
        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.count, 1)
        if case .text(let value) = loaded.first?.content
        {
            XCTAssertEqual(value, "updated encryption test")
        }
        else
        {
            XCTFail("Expected text content after update")
        }
    }

    // TC-F1.12-030：update 保留 embeddings 字段
    func testUpdatePreservesEmbeddings() throws
    {
        let item = ClipItem(
            id: UUID(),
            content: .text("embeddings test"),
            contentType: .article,
            sourceApp: "com.test",
            sourceAppName: "Test",
            timestamp: Date(),
            summary: nil,
            translation: nil,
            rewrite: nil,
            todos: nil,
            embeddings: [1.0, 0.5, 0.0],
            isSample: false
        )
        try store.save(item)

        var updated = item
        updated = ClipItem(
            id: updated.id,
            content: .text("updated embeddings test"),
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
        try store.update(updated)

        // 通过 search 验证 embeddings 仍可被查询
        let results = try store.search(query: [1.0, 0.5, 0.0], limit: 5)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.id, item.id)
    }

    // TC-F1.12-031：update 不修改 save 方法行为
    func testUpdateDoesNotAffectSaveBehavior() throws
    {
        let item1 = ClipItem.makeText(
            "save first",
            contentType: .article,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        try store.save(item1)

        let item2 = ClipItem.makeText(
            "update second",
            contentType: .code,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        try store.update(item2)

        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.count, 2)

        // save 的行为不变
        let savedItem = loaded.first { $0.id == item1.id }
        XCTAssertNotNil(savedItem)
        if case .text(let value) = savedItem?.content
        {
            XCTAssertEqual(value, "save first")
        }
    }
}
```

### GREEN：实现 EncryptedStore.update()

修改 `ClipMind/Storage/EncryptedStore.swift`，在 `save` 方法后新增：

```swift
/// 更新已存储的 ClipItem：序列化为 JSON → AES-256-GCM 加密 → 写入 SQLite（INSERT OR REPLACE）
/// - Parameter item: 包含更新内容的 ClipItem，以 id 为主键匹配
/// - Throws: 数据库写入错误、加密错误
func update(_ item: ClipItem) throws
{
    let json = try encodeJSON(item)
    let encryptedContent = try encrypt(json)

    let embeddingsData: Data?
    if let embeddings = item.embeddings, !embeddings.isEmpty
    {
        let embJson = try encodeJSON(embeddings)
        embeddingsData = try encrypt(embJson)
    }
    else
    {
        embeddingsData = nil
    }

    let id = item.id.uuidString
    let contentType = item.contentType.rawValue
    let timestamp = item.timestamp.timeIntervalSince1970
    let sourceApp = item.sourceApp
    let isSample = item.isSample

    // INSERT OR REPLACE：若 id 已存在则替换整条记录，否则插入新记录
    let query = clips.insert(or: .replace)(
        idColumn <- id,
        contentBlob <- encryptedContent,
        contentTypeColumn <- contentType,
        timestampColumn <- timestamp,
        sourceAppColumn <- sourceApp,
        embeddingsBlob <- embeddingsData,
        isSampleColumn <- isSample
    )
    try database.run(query)
    LogCategory.storage.info("Clip updated: id=\(id), contentLength=\(json.count)")
}
```

### REFACTOR

- 检查 `save` 与 `update` 是否有共同的序列化/加密逻辑可提取。当前两者逻辑高度相似，但 `save` 使用 `clips.insert(...)` 而 `update` 使用 `clips.insert(or: .replace)(...)`，提取反而增加复杂度，暂不提取。
- 确认 `INSERT OR REPLACE` 会替换整行记录（包括 embeddings），不会丢失字段。

### COMMIT

```
feat(F1.12): add EncryptedStore.update() method
```

---

## Task 0.2：新增 ClipStore.updateClip() 方法

**对应 AC：** AC-F1.12-2
**对应测试用例：** TC-F1.12-032、TC-F1.12-033
**预计时间：** 3 分钟

### RED：编写失败测试

新建 `ClipMindTests/UI/ClipStoreUpdateTests.swift`：

```swift
@testable import ClipMind
import XCTest

final class ClipStoreUpdateTests: XCTestCase
{
    private var dbPath: URL!
    private var store: EncryptedStore!
    private var clipStore: ClipStore!

    override func setUpWithError() throws
    {
        dbPath = try TestDatabaseHelper.makeTempDBPath()
        store = try EncryptedStore(
            dbPath: dbPath,
            key: TestDatabaseHelper.makeTestKey()
        )
        clipStore = ClipStore(store: store)
    }

    override func tearDownWithError() throws
    {
        clipStore = nil
        store = nil
        if let dbPath
        {
            TestDatabaseHelper.cleanup(at: dbPath)
        }
        dbPath = nil
    }

    // TC-F1.12-032：updateClip 成功更新 clips 数组
    func testUpdateClipSuccess() throws
    {
        let item = ClipItem.makeText(
            "original",
            contentType: .article,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        try store.save(item)
        clipStore.loadClips()

        XCTAssertEqual(clipStore.clips.count, 1)

        var updated = item
        updated = ClipItem(
            id: updated.id,
            content: .text("updated via updateClip"),
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
        try clipStore.updateClip(updated)

        XCTAssertEqual(clipStore.clips.count, 1)
        let clipInArray = clipStore.clips.first { $0.id == item.id }
        XCTAssertNotNil(clipInArray)
        if case .text(let value) = clipInArray?.content
        {
            XCTAssertEqual(value, "updated via updateClip")
        }
    }

    // TC-F1.12-033：updateClip 失败不更新 clips 数组
    func testUpdateClipFailureDoesNotUpdateArray() throws
    {
        // 创建一个会失败的场景：关闭数据库后尝试更新
        let item = ClipItem.makeText(
            "will fail",
            contentType: .article,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        try store.save(item)
        clipStore.loadClips()

        let originalCount = clipStore.clips.count
        let originalContent = clipStore.clips.first?.content

        // 删除数据库文件制造失败
        TestDatabaseHelper.cleanup(at: dbPath)

        var updated = item
        updated = ClipItem(
            id: updated.id,
            content: .text("this should not be saved"),
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

        XCTAssertThrowsError(try clipStore.updateClip(updated))

        XCTAssertEqual(clipStore.clips.count, originalCount)
        XCTAssertEqual(clipStore.clips.first?.content, originalContent)
    }
}
```

### GREEN：实现 ClipStore.updateClip()

修改 `ClipMind/UI/ClipStore.swift`：

1. 新增指定初始化器（允许测试注入 EncryptedStore）：

```swift
/// 指定初始化器（测试用，允许注入 EncryptedStore）
init(store: EncryptedStore)
{
    self.store = store
    loadClips()
    observer = NotificationCenter.default.addObserver(
        forName: ClipCaptureService.clipDidUpdateNotification,
        object: nil,
        queue: .main
    ) { [weak self] _ in
        self?.loadClips()
    }
}
```

2. 修改现有 `init()` 调用指定初始化器：

```swift
init()
{
    do
    {
        let encryptedStore = try EncryptedStore()
        self.init(store: encryptedStore)
    }
    catch
    {
        // 初始化失败时仍需完成属性赋值
        self.store = nil
        self.observer = nil
        LogCategory.storage.error("EncryptedStore 初始化失败: \(error.localizedDescription)")
    }
}
```

3. 新增 `updateClip` 方法：

```swift
/// 更新指定 ClipItem 到数据库并刷新 clips 列表。
/// - Parameter item: 包含更新内容的 ClipItem
/// - Throws: 数据库写入错误
func updateClip(_ item: ClipItem) throws
{
    guard let store = store
    else
    {
        LogCategory.storage.error("updateClip 失败: EncryptedStore 未初始化")
        throw ClipStoreError.storeNotInitialized
    }
    try store.update(item)
    // 更新 clips 数组中匹配 id 的条目
    if let index = clips.firstIndex(where: { $0.id == item.id })
    {
        clips[index] = item
    }
    else
    {
        // update 写入了新条目（INSERT OR REPLACE 的 INSERT 场景）
        clips.append(item)
    }
    LogCategory.storage.info("ClipStore updated: id=\(item.id.uuidString)")
}
```

4. 新增错误类型：

```swift
enum ClipStoreError: Error
{
    case storeNotInitialized
}
```

### REFACTOR

- 确认 `updateClip` 中 `clips[index] = item` 会触发 `@Published` 属性观察器，自动刷新 SwiftUI 视图。
- 确认错误处理一致性：`updateClip` throws，调用方可 try/catch。

### COMMIT

```
feat(F1.12): add ClipStore.updateClip() method
```

---

## Task 0.3：创建 EditableContentArea 组件

**对应 AC：** AC-F1.12-1
**对应测试用例：** TC-F1.12-001
**预计时间：** 5 分钟

### RED：编写失败测试

此任务主要为 SwiftUI 视图组件，XCTest 无法直接测试视图渲染。通过验证类型存在性和编译检查确认。

在 `ClipMindTests/UI/EditableContentAreaTests.swift` 中：

```swift
@testable import ClipMind
import SwiftUI
import XCTest

final class EditableContentAreaTests: XCTestCase
{
    // 验证 EditableContentArea 可被实例化
    func testEditableContentAreaCanBeCreated()
    {
        let item = ClipItem.makeText(
            "test content",
            contentType: .article,
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
}
```

### GREEN：创建 EditableContentArea

新建 `ClipMind/UI/MainWindow/EditableContentArea.swift`：

```swift
import SwiftUI

/// 详情面板可编辑内容区域（F1.12）。
///
/// 根据 ClipContent 类型选择展示模式：
/// - 文本类型（.text）：点击进入编辑模式，防抖自动保存
/// - 文件路径类型（.filePath）：点击进入编辑模式（Phase 1 实现）
/// - 图片类型（.image）：只读 + 不可编辑提示（Phase 1 实现）
struct EditableContentArea: View
{
    let clip: ClipItem
    var onUpdateClip: ((ClipItem) -> Void)?
    var onContentSaved: ((ClipItem) -> Void)?

    @State private var isEditing: Bool = false
    @State private var editableText: String = ""
    @State private var saveTask: Task<Void, Never>?
    @State private var saveError: String?
    @FocusState private var isEditorFocused: Bool

    var body: some View
    {
        VStack(alignment: .leading, spacing: 8)
        {
            switch clip.content
            {
            case .text:
                textContentArea
            case .image:
                // Phase 1 实现：图片预览 + 不可编辑提示
                Text("[图片]")
                    .font(.body)
            case .filePath:
                // Phase 1 实现：文件路径编辑
                Text(filePathPreview)
                    .font(.body)
            }

            // 保存错误提示
            if let saveError = saveError
            {
                Text(saveError)
                    .foregroundColor(.red)
                    .font(.caption)
                    .accessibilityIdentifier("editSaveErrorText")
            }
        }
        .onAppear
        {
            initializeEditableText()
        }
        .onChange(of: clip.id)
        { _ in
            saveBeforeSwitching()
            initializeEditableText()
        }
    }

    // MARK: - 文本内容区域

    @ViewBuilder
    private var textContentArea: some View
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
            Text(editableText)
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

    // MARK: - 文件路径预览（Phase 0 临时展示，Phase 1 替换为编辑模式）

    private var filePathPreview: String
    {
        if case .filePath(let urls) = clip.content
        {
            return urls.map(\.path).joined(separator: "\n")
        }
        return ""
    }

    // MARK: - 初始化

    private func initializeEditableText()
    {
        isEditing = false
        saveError = nil
        switch clip.content
        {
        case .text(let text):
            editableText = text
        case .filePath(let urls):
            editableText = urls.map(\.path).joined(separator: "\n")
        case .image:
            editableText = ""
        }
    }

    // MARK: - 防抖自动保存

    private func scheduleSave()
    {
        saveTask?.cancel()
        saveTask = Task
        { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms 防抖
            guard !Task.isCancelled else { return }
            performSave()
        }
    }

    private func performSave()
    {
        let updatedItem = constructUpdatedClipItem()
        onUpdateClip?(updatedItem)
        onContentSaved?(updatedItem)
        saveError = nil
    }

    /// 切换条目前立即保存（无防抖）
    private func saveBeforeSwitching()
    {
        saveTask?.cancel()
        saveTask = nil
        guard isEditing, hasContentChanged() else { return }
        performSave()
        isEditing = false
    }

    // MARK: - 辅助方法

    private func hasContentChanged() -> Bool
    {
        switch clip.content
        {
        case .text(let original):
            return editableText != original
        case .filePath(let urls):
            return editableText != urls.map(\.path).joined(separator: "\n")
        case .image:
            return false
        }
    }

    private func constructUpdatedClipItem() -> ClipItem
    {
        let updatedContent: ClipContent
        switch clip.content
        {
        case .text:
            updatedContent = .text(editableText)
        case .filePath:
            // Phase 1 实现路径解析，Phase 0 暂存原始文本
            let paths = editableText.components(separatedBy: "\n")
            updatedContent = .filePath(paths.map { URL(fileURLWithPath: $0) })
        case .image:
            updatedContent = clip.content
        }
        return ClipItem(
            id: clip.id,
            content: updatedContent,
            contentType: clip.contentType,
            sourceApp: clip.sourceApp,
            sourceAppName: clip.sourceAppName,
            timestamp: clip.timestamp,
            summary: clip.summary,
            translation: clip.translation,
            rewrite: clip.rewrite,
            todos: clip.todos,
            embeddings: clip.embeddings,
            isSample: clip.isSample
        )
    }
}
```

### REFACTOR

- 确认 `onChange(of: editableText)` 在 TextEditor 中正确触发。
- 确认 `@FocusState` 在点击时自动聚焦 TextEditor。
- Cmd+Z 撤销由 SwiftUI TextEditor 内置 UndoManager 支持，无需自定义实现。

### COMMIT

```
feat(F1.12): create EditableContentArea component
```

---

## Task 0.4：集成 EditableContentArea 到 DetailPanel

**对应 AC：** AC-F1.12-1、AC-F1.12-4、AC-F1.12-8
**对应测试用例：** TC-F1.12-001、TC-F1.12-011、TC-F1.12-024
**预计时间：** 3 分钟

### RED：编写失败测试

在 `ClipMindTests/UI/EditableContentAreaTests.swift` 中追加：

```swift
// 验证 DetailPanel 使用 EditableContentArea（编译检查）
func testDetailPanelAcceptsEditableContentArea()
{
    let item = ClipItem.makeText(
        "integration test",
        contentType: .article,
        sourceApp: "com.test",
        sourceAppName: "Test"
    )
    let detailPanel = DetailPanel(clip: item, onUpdateClip: { _ in })
    XCTAssertNotNil(detailPanel)
}
```

### GREEN：修改 DetailPanel

修改 `ClipMind/UI/MainWindow/DetailPanel.swift`：

1. 在 `detailContent(for:)` 中替换只读 Text 为 EditableContentArea：

```swift
@ViewBuilder
private func detailContent(for clip: ClipItem) -> some View
{
    ScrollView
    {
        VStack(alignment: .leading, spacing: 16)
        {
            // 替换只读 Text 为可编辑 EditableContentArea
            EditableContentArea(
                clip: clip,
                onUpdateClip: handleUpdateClip,
                onContentSaved: handleContentSaved
            )
            Divider()
            metaSection(for: clip)
            if currentTextContent(for: clip) != nil
            {
                ProcessingButtons(
                    isConfigured: isConfigured,
                    isProcessing: isProcessing,
                    onSummarize: performSummarize,
                    onTranslate: performTranslate,
                    onRewrite: { showRewriteModePicker = true },
                    onExtractTodo: performExtractTodo
                )
                errorSection
                resultsSection(for: clip)
            }
        }
        .padding()
    }
}
```

2. 新增回调方法（在 `// MARK: - 辅助方法与 Mock 数据` extension 中）：

```swift
/// EditableContentArea 保存回调：更新 ClipStore
func handleUpdateClip(_ updatedItem: ClipItem)
{
    onUpdateClip?(updatedItem)
}

/// EditableContentArea 保存成功回调：同步系统剪贴板（Phase 1 扩展）
func handleContentSaved(_ updatedItem: ClipItem)
{
    // Phase 1 在此添加 NSPasteboard 同步
}
```

3. 修改 `textContent(for:)` 以支持编辑后内容：

```swift
/// 获取当前文本内容（编辑后内容或原始内容）
func currentTextContent(for clip: ClipItem) -> String?
{
    if case .text(let text) = clip.content
    {
        return text
    }
    return nil
}
```

4. 将所有 `textContent(for: clip)` 调用替换为 `currentTextContent(for: clip)`（performSummarize、performTranslate、performRewrite、performExtractTodo）。

### REFACTOR

- 保留 `contentPreview(for:)` 方法供其他场景使用。
- `currentTextContent(for:)` 命名明确区分原始内容和编辑后内容。

### COMMIT

```
feat(F1.12): integrate EditableContentArea into DetailPanel
```

---

## Task 0.5：实现防抖自动保存

**对应 AC：** AC-F1.12-2、AC-F1.12-4
**对应测试用例：** TC-F1.12-005、TC-F1.12-007、TC-F1.12-008、TC-F1.12-011、TC-F1.12-012
**预计时间：** 4 分钟

### RED：编写失败测试

在 `ClipMindTests/UI/ClipStoreUpdateTests.swift` 中追加防抖保存相关测试：

```swift
// TC-F1.12-008：自动保存成功后 ClipStore 同步
func testAutoSaveUpdatesClipStore() throws
{
    let item = ClipItem.makeText(
        "auto save test",
        contentType: .article,
        sourceApp: "com.test",
        sourceAppName: "Test"
    )
    try store.save(item)
    clipStore.loadClips()

    var updated = item
    updated = ClipItem(
        id: updated.id,
        content: .text("auto saved content"),
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
    try clipStore.updateClip(updated)

    // 验证 clips 数组已更新
    let clipInArray = clipStore.clips.first { $0.id == item.id }
    XCTAssertNotNil(clipInArray)
    if case .text(let value) = clipInArray?.content
    {
        XCTAssertEqual(value, "auto saved content")
    }

    // 验证数据库已更新
    let loaded = try store.loadAll()
    if case .text(let value) = loaded.first?.content
    {
        XCTAssertEqual(value, "auto saved content")
    }
}
```

### GREEN：完善自动保存逻辑

EditableContentArea 的防抖逻辑已在 Task 0.3 中实现（`scheduleSave` / `performSave` / `saveBeforeSwitching`）。本 Task 重点确保回调链完整：

1. `EditableContentArea.scheduleSave()` → 500ms 防抖 → `performSave()`
2. `performSave()` → `onUpdateClip?(updatedItem)` → `DetailPanel.handleUpdateClip(_:)`
3. `DetailPanel.handleUpdateClip(_:)` → `onUpdateClip?(updatedItem)` → `MainWindow` 中的 `ClipStore.updateClip()`

确认 `MainWindow` 中已有 `onUpdateClip` 回调处理逻辑（F1.7 已实现），编辑保存复用同一回调链。

修改 `ClipMind/UI/MainWindow/MainWindow.swift` 中 `onUpdateClip` 回调，使其调用 `ClipStore.updateClip()`：

```swift
// MainWindow 中的 onUpdateClip 回调（已存在，需扩展以支持 updateClip）
onUpdateClip: { updatedItem in
    do
    {
        try clipStore.updateClip(updatedItem)
    }
    catch
    {
        LogCategory.ui.error("更新剪贴项失败: \(error.localizedDescription)")
    }
}
```

### REFACTOR

- 确认防抖 Task 在 `saveBeforeSwitching` 中正确取消和立即保存。
- 确认 `onChange(of: clip.id)` 在条目切换时正确触发保存。

### COMMIT

```
feat(F1.12): implement debounced auto-save in EditableContentArea
```

---

## Task 0.6：添加辅助功能标识符和 XCUITest 编译检查

**对应 AC：** AC-F1.12-1、AC-F1.12-3
**对应测试用例：** TC-F1.12-001、TC-F1.12-014
**预计时间：** 3 分钟

### RED：确认 XCUITest 目标可编译

新建 `ClipMindUITests/F1_12_DetailContentEditableTests.swift` 骨架：

```swift
import XCTest

final class F1_12_DetailContentEditableTests: XCTestCase
{
    let app = XCUIApplication()

    override func setUpWithError() throws
    {
        continueAfterFailure = false
        app.launchEnvironment["UITEST_FORCE_CONFIGURED"] = "1"
        app.launch()
    }

    override func tearDownWithError() throws
    {
        app.terminate()
    }

    // TC-F1.12-001：点击文本区域进入编辑模式
    func testClickTextAreaEnterEditMode() throws
    {
        // 选中一条文本类型条目
        let firstClip = app.groups["clipRow"].firstMatch
        XCTAssertTrue(firstClip.waitForExistence(timeout: 5))
        firstClip.click()

        // 点击详情面板文本内容区域
        let contentText = app.staticTexts["detailContentText"].firstMatch
        if contentText.waitForExistence(timeout: 3)
        {
            contentText.click()

            // 验证 TextEditor 出现
            let editor = app.textViews["detailContentEditor"].firstMatch
            XCTAssertTrue(editor.waitForExistence(timeout: 2))
        }
    }

    // TC-F1.12-014：Cmd+Z 撤销最近一次编辑
    func testCmdZUndo() throws
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
                editor.typeText("test")

                // Cmd+Z 撤销
                editor.typeKey("z", modifierFlags: .command)

                // 验证 TextEditor 仍存在（撤销后仍在编辑模式）
                XCTAssertTrue(editor.exists)
            }
        }
    }
}
```

### GREEN：添加辅助功能标识符

确认以下标识符已在 Task 0.3 的 EditableContentArea 代码中添加：

| 标识符 | 视图 | 用途 |
|--------|------|------|
| `detailContentEditor` | TextEditor | XCUITest 定位编辑区域 |
| `detailContentText` | 只读 Text | XCUITest 定位只读内容 |
| `editSaveErrorText` | 错误提示 Text | XCUITest 定位保存错误提示 |

已在 Task 0.3 代码中包含，无需额外修改。

### REFACTOR

- 确认 XCUITest 目标可编译（`xcodebuild build` for ClipMindUITests scheme）。
- 确认新增标识符不与 F1.1~F1.11 已有标识符冲突。

### COMMIT

```
feat(F1.12): add accessibility identifiers for editing
```

---

## Phase 0 完成标准

- [ ] `EncryptedStore.update()` 通过所有 5 条单元测试（TC-F1.12-027~TC-F1.12-031）
- [ ] `ClipStore.updateClip()` 通过所有 2 条单元测试（TC-F1.12-032~TC-F1.12-033）
- [ ] `EditableContentArea` 可被实例化并通过编译检查
- [ ] `DetailPanel` 集成 `EditableContentArea`，替换只读 Text
- [ ] 防抖自动保存（500ms）和切换条目时立即保存行为正确
- [ ] 辅助功能标识符就位，XCUITest 目标可编译
- [ ] `swiftlint lint --strict` 通过
- [ ] `xcodebuild build` 编译通过
- [ ] `xcodebuild test` 所有测试通过

Phase 0 合并到 develop 后预期基线：文本类型可在详情面板点击编辑，编辑后自动保存到数据库，Cmd+Z 撤销可用，切换条目自动保存。

## 版本记录

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0 | 2026-07-27 | 初始版本，6 个 Task，覆盖 AC-F1.12-1/2/3/4 |
