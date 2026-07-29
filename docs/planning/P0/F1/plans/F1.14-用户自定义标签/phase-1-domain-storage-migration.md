# Phase 1：标签领域、加密持久化与迁移

> 最后更新：2026-07-29 | 版本：v1.0

**目标：** 建立统一标签模型、唯一业务规则边界、原子加密 mutation、可恢复旧数据迁移，
并保证新捕获条目与自身系统标签共同成功后才发布。

**IN：** Phase 0 Gate 全部通过。

**OUT：** DOM-001～011、MIG-001～003、SEC-001～002 的 XCTest 通过。

**范围：** AC-5～9、12～19 的领域/存储部分。

**非目标：** SwiftUI 标签菜单、主窗口标签筛选、设置管理 UI、XCUITest。

---

## 任务 1：系统标签和条目标签状态

**文件：**

- 创建：`ClipMind/Models/ClipTag.swift`
- 创建：`ClipMind/Models/ClipTagState.swift`
- 创建：`ClipMind/Models/SystemTagCatalog.swift`
- 创建：`ClipMindTests/Tags/SystemTagCatalogTests.swift`

- [ ] **步骤 1：编写 RED 测试**

测试必须逐项断言 11 个 `ContentType` 的稳定 ID、旧显示文本和颜色，并断言系统标签全局只读、
用户标签可全局管理：

```swift
@testable import ClipMind
import XCTest

final class SystemTagCatalogTests: XCTestCase
{
    func testDefinitionsMatchLegacyTextAndColor()
    {
        let expected: [(ContentType, String, ClipTagColor)] = [
            (.code, "CODE", .violet),
            (.link, "LINK", .cyan),
            (.error, "ERROR", .rose),
            (.article, "ARTICLE", .blue),
            (.todo, "TODO", .amber),
            (.meeting, "MEETING", .emerald),
            (.translation, "TRANS", .purple),
            (.requirement, "REQ", .orange),
            (.apiDoc, "API", .teal),
            (.englishDoc, "DOC", .slate),
            (.other, "OTHER", .gray)
        ]

        XCTAssertEqual(SystemTagCatalog.all.count, expected.count)
        for (contentType, name, color) in expected
        {
            let tag = SystemTagCatalog.tag(for: contentType)
            XCTAssertEqual(tag.id, .system(contentType))
            XCTAssertEqual(tag.name, name)
            XCTAssertEqual(tag.color, color)
            XCTAssertEqual(tag.source, .system)
        }
    }

    func testNewItemStateAssociatesOnlyItsOwnSystemTag()
    {
        let state = ClipTagState.newItem(contentType: .code)

        XCTAssertEqual(state.orderedTagIDs, [.system(.code)])
        XCTAssertEqual(state.systemTagDisposition, .associated)
        XCTAssertEqual(state.migrationVersion, ClipTagState.currentMigrationVersion)
    }

    func testLegacyStateRequiresMigration()
    {
        XCTAssertTrue(ClipTagState.legacy.requiresMigration)
        XCTAssertEqual(ClipTagState.legacy.systemTagDisposition, .pendingMigration)
    }
}
```

- [ ] **步骤 2：运行 RED**

运行：

```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:ClipMindTests/SystemTagCatalogTests
```

预期：FAIL，缺少 `ClipTag`、`ClipTagState` 和 `SystemTagCatalog`。

- [ ] **步骤 3：实现值类型**

`ClipTag.swift` 必须提供以下完整公共语义；业务常量不得散落到 View：

```swift
import Foundation

struct ClipTagID: RawRepresentable, Codable, Hashable, Comparable, Sendable
{
    let rawValue: String

    init(rawValue: String)
    {
        self.rawValue = rawValue
    }

    static func system(_ contentType: ContentType) -> ClipTagID
    {
        ClipTagID(rawValue: "system.\(contentType.rawValue)")
    }

    static func user(_ id: UUID = UUID()) -> ClipTagID
    {
        ClipTagID(rawValue: "user.\(id.uuidString.lowercased())")
    }

    static func < (lhs: ClipTagID, rhs: ClipTagID) -> Bool
    {
        lhs.rawValue < rhs.rawValue
    }
}

enum ClipTagSource: String, Codable, Equatable, Sendable
{
    case system
    case user
}

enum ClipTagColor: String, Codable, CaseIterable, Equatable, Sendable
{
    case violet
    case cyan
    case rose
    case blue
    case amber
    case emerald
    case purple
    case orange
    case teal
    case slate
    case gray
}

struct ClipTag: Identifiable, Codable, Equatable, Sendable
{
    let id: ClipTagID
    var name: String
    let color: ClipTagColor
    let source: ClipTagSource
}
```

`ClipTagState.swift`：

```swift
import Foundation

enum SystemTagDisposition: String, Codable, Equatable, Sendable
{
    case pendingMigration
    case associated
    case removed
}

struct ClipTagState: Codable, Equatable, Sendable
{
    static let currentMigrationVersion = 1

    var orderedTagIDs: [ClipTagID]
    var systemTagDisposition: SystemTagDisposition
    var migrationVersion: Int

    static let legacy = ClipTagState(
        orderedTagIDs: [],
        systemTagDisposition: .pendingMigration,
        migrationVersion: 0
    )

    static func newItem(contentType: ContentType) -> ClipTagState
    {
        ClipTagState(
            orderedTagIDs: [.system(contentType)],
            systemTagDisposition: .associated,
            migrationVersion: currentMigrationVersion
        )
    }

    var requiresMigration: Bool
    {
        migrationVersion < Self.currentMigrationVersion
    }
}
```

`SystemTagCatalog` 用一个 `switch` 返回任务 RED 测试中的 11 组值，并提供：

```swift
static let all: [ClipTag]
static func tag(for contentType: ContentType) -> ClipTag
static func contentType(for id: ClipTagID) -> ContentType?
```

`all` 必须按 `ContentType.allCases` 顺序构造；反向查询只接受 `system.` ID。

- [ ] **步骤 4：运行 GREEN**

重复步骤 2。预期：3 个测试全部 PASS。

## 任务 2：`ClipItem` 向后兼容与新条目默认关联

**文件：**

- 修改：`ClipMind/Models/ClipItem.swift`
- 修改：`ClipMindTests/Models/ClipItemDecodingTests.swift`
- 修改：`ClipMindTests/Models/ClipItemModelTests.swift`

- [ ] **步骤 1：为旧 JSON 和三个工厂编写 RED 测试**

新增断言：

```swift
func testLegacyPayloadDefaultsToPendingTagMigration() throws
{
    let item = try decodeLegacyFixtureWithoutTagState()

    XCTAssertEqual(item.tagState, .legacy)
}

func testFactoriesAssociateOwnSystemTag()
{
    let text = ClipItem.makeText(
        "value",
        contentType: .code,
        sourceApp: "com.test",
        sourceAppName: "Test"
    )
    let image = ClipItem.makeImage(
        Data([0x01]),
        contentType: .other,
        sourceApp: "com.test",
        sourceAppName: "Test"
    )
    let file = ClipItem.makeFilePath(
        [URL(fileURLWithPath: "/tmp/a")],
        contentType: .other,
        sourceApp: "com.test",
        sourceAppName: "Test"
    )

    XCTAssertEqual(text.tagState, .newItem(contentType: .code))
    XCTAssertEqual(image.tagState, .newItem(contentType: .other))
    XCTAssertEqual(file.tagState, .newItem(contentType: .other))
}
```

测试辅助 `decodeLegacyFixtureWithoutTagState()` 必须复用当前
`ClipItemDecodingTests` 的旧 payload 构造，不创建第二套 JSON 日期策略。

- [ ] **步骤 2：运行 RED**

运行 `ClipMindTests/ClipItemDecodingTests` 和 `ClipMindTests/ClipItemModelTests`。
预期：缺少 `tagState` 或工厂返回 `.legacy`。

- [ ] **步骤 3：实现兼容字段**

在 `ClipItem` 增加：

```swift
var tagState: ClipTagState = .legacy
```

`CodingKeys` 增加 `.tagState`，自定义 decoder 使用：

```swift
tagState = try container.decodeIfPresent(ClipTagState.self, forKey: .tagState) ?? .legacy
```

三个工厂的 memberwise 初始化均显式传入：

```swift
tagState: .newItem(contentType: contentType)
```

现有直接 memberwise 初始化因默认参数继续可编译，语义为旧数据夹具；需要新条目语义的测试必须改用工厂。

- [ ] **步骤 4：运行 GREEN 和解码回归**

运行：

```text
ClipMindTests/ClipItemDecodingTests
ClipMindTests/ClipItemModelTests
ClipMindTests/EncryptedStoreTests
```

预期：全部 PASS，旧数据仍可加载。

## 任务 3：标签快照、错误、日志和存储端口

**文件：**

- 创建：`ClipMind/Tags/TagError.swift`
- 创建：`ClipMind/Tags/TagNameValidator.swift`
- 创建：`ClipMind/Tags/TagSnapshot.swift`
- 创建：`ClipMind/Tags/TagRepository.swift`
- 创建：`ClipMind/Tags/TagOperationLogger.swift`
- 创建：`ClipMindTests/Tags/TagLogSanitizationTests.swift`

- [ ] **步骤 1：定义名称规范化合同**

`TagNameValidator` 是创建、重命名和 UI preflight 共同使用的纯领域边界：

```swift
import Foundation

enum TagNameValidator
{
    static func validate(
        candidate: String,
        existingTags: [ClipTag],
        excluding excludedID: ClipTagID? = nil
    ) throws -> String
    {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TagError.emptyName }

        let key = trimmed.folding(
            options: [.caseInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        let hasDuplicate = existingTags.contains
        {
            $0.id != excludedID
                && $0.name.folding(
                    options: [.caseInsensitive],
                    locale: Locale(identifier: "en_US_POSIX")
                ) == key
        }
        guard !hasDuplicate else { throw TagError.duplicateName }
        return trimmed
    }
}
```

`TagService` 和 Phase 4 ViewModel 都调用这一个 API；候选集合固定为
`SystemTagCatalog.all + snapshot.userTags`，重命名传 `excluding: currentTagID`。
XCTest 覆盖空白、`code` 对 `CODE`、` 重要 ` 对“重要”、排除自身和唯一名称。

- [ ] **步骤 2：定义快照、错误、日志和端口合同**

`TagSnapshot`：

```swift
import Foundation

struct TagSnapshot: Equatable, Sendable
{
    var userTags: [ClipTag]
    var tagStatesByClipID: [UUID: ClipTagState]

    static let empty = TagSnapshot(userTags: [], tagStatesByClipID: [:])

    var allTags: [ClipTag]
    {
        SystemTagCatalog.all + userTags
    }

    func tags(for clipID: UUID) -> [ClipTag]
    {
        let tagsByID = Dictionary(uniqueKeysWithValues: allTags.map { ($0.id, $0) })
        return tagStatesByClipID[clipID, default: .legacy].orderedTagIDs.compactMap
        {
            tagsByID[$0]
        }
    }
}
```

`TagError` 必须实现 `LocalizedError`，固定错误码和不含标签名的安全文案：

```swift
enum TagError: String, Error, LocalizedError, Equatable, Sendable
{
    case emptyName
    case duplicateName
    case tagLimitReached
    case systemTagNotEligible
    case systemTagReadOnly
    case tagNotFound
    case clipNotFound
    case persistenceFailed

    var errorDescription: String?
    {
        switch self
        {
        case .emptyName:
            return "标签名称不能为空"
        case .duplicateName:
            return "已存在同名标签"
        case .tagLimitReached:
            return "每条条目最多 5 个标签"
        case .systemTagNotEligible:
            return "该自动分类标签不适用于当前条目"
        case .systemTagReadOnly:
            return "自动分类标签不可全局修改"
        case .tagNotFound, .clipNotFound, .persistenceFailed:
            return "未能保存标签操作，已恢复之前的状态"
        }
    }
}
```

`TagRepository` 与 mutation：

```swift
protocol TagRepository: AnyObject
{
    func loadSnapshot() throws -> TagSnapshot
    func apply(_ mutation: TagMutation) throws
    func migrateNextBatch(limit: Int) throws -> TagMigrationBatchResult
}

enum TagMutation: Equatable
{
    case createAndAttach(tag: ClipTag, clipID: UUID)
    case attach(tagID: ClipTagID, clipID: UUID)
    case detach(tagID: ClipTagID, clipID: UUID)
    case rename(tagID: ClipTagID, name: String)
    case delete(tagID: ClipTagID)
}

struct TagMigrationBatchResult: Equatable
{
    let migratedCount: Int
    let remainingCount: Int
}
```

`TagOperationLogger` 只接收枚举和计数：

```swift
enum TagOperation: String
{
    case create
    case attach
    case detach
    case rename
    case delete
    case migrate
}

enum TagOperationResult: String
{
    case success
    case failure
}

protocol TagOperationLogging
{
    func record(
        operation: TagOperation,
        result: TagOperationResult,
        error: TagError?,
        count: Int
    )
}
```

生产 logger 调用 `LogCategory.storage`，格式只包含闭集 `operation`、`result`、
`error?.rawValue` 和 `count`；端口没有可传入任意 String 的参数。

- [ ] **步骤 3：编写日志哨兵测试**

使用测试 logger 捕获所有参数，对创建/关联/移除/重命名/删除成功与失败逐项执行；
断言标签哨兵和剪贴板哨兵未进入渲染后的日志，且穷举所有闭集 operation/result/error 分支。

- [ ] **步骤 4：运行 GREEN**

预期：纯值类型和测试 logger 用例 PASS。

## 任务 4：加密目录 blob 与原子 mutation

**文件：**

- 修改：`ClipMind/Storage/EncryptedStore.swift`
- 创建：`ClipMind/Storage/EncryptedStore+Tags.swift`
- 创建：`ClipMindTests/Storage/EncryptedTagStoreTests.swift`
- 修改：`ClipMindTests/Storage/EncryptedStoreUpdateTests.swift`
- 修改：`ClipMind/UI/MainWindow/EditableContentArea.swift`
- 创建：`ClipMindTests/UI/EditableContentAreaTests.swift`

- [ ] **步骤 1：编写 RED 集成测试**

覆盖：

1. 用户标签目录保存后，数据库原始字节不含名称、颜色 rawValue、来源 rawValue。
2. 解密 `loadSnapshot()` 后字段完整相等。
3. `createAndAttach` 在目录写入或 ClipItem 更新任一失败时全部回滚。
4. `delete` 在一个事务内删除目录项和所有条目关联。
5. `rename` 保持 tag ID、关联和顺序不变。
6. `attach/detach` 更新 `systemTagDisposition`，重启后保持。
7. 连接 A 完成标签 mutation 后，连接 B 用 mutation 前的旧 `ClipItem` 更新内容/摘要；
   最终内容更新成功，但 tag ID、顺序和 disposition 保持连接 A 的最新值。

原子回滚测试通过 SQLite trigger 在临时数据库内让目录或 clip UPDATE 明确失败；
trigger 在 test teardown 删除。不得给 `EncryptedStore` 增加 test-only 初始化参数，
也不 mock `EncryptedStore` 本身。

- [ ] **步骤 2：运行 RED**

运行 `ClipMindTests/EncryptedTagStoreTests`。预期：缺少 `TagRepository` conformance。

- [ ] **步骤 3：开放最小内部存储能力**

`EncryptedStore.swift` 只把下列成员从 `private` 改为模块内部，供同 target extension 使用：

```swift
let database: Connection
func encrypt(_ data: Data) throws -> Data
func decrypt(_ data: Data) throws -> Data
func encodeJSON<T: Encodable>(_ value: T) throws -> Data
func decodeJSON<T: Decodable>(_ type: T.Type, from data: Data) throws -> T
```

它们仍非 `public`。密钥、默认路径和表字段不扩大可见性。

- [ ] **步骤 4：实现 `EncryptedStore+Tags`**

文件内定义：

```swift
private enum TagStorageSchema
{
    static let catalog = Table("tag_catalog")
    static let key = Expression<String>("key")
    static let valueBlob = Expression<Data>("value_blob")
    static let catalogKey = "user-tags"
}

private struct PersistedTagCatalog: Codable, Equatable
{
    var userTags: [ClipTag]
}
```

初始化路径创建 `tag_catalog(key TEXT PRIMARY KEY, value_blob BLOB NOT NULL)`；
`value_blob` 是 `PersistedTagCatalog` 的 AES-256-GCM 密文。

`apply(_:)` 必须在 `database.transaction` 内按以下顺序执行：

1. 解密当前目录和受影响 `ClipItem`。
2. 应用已验证的 `TagMutation`。
3. 加密并更新目录与所有受影响的 `content_blob`。
4. mutation 任一步抛错时让 SQLite.swift 回滚事务。
5. 事务成功后才返回；不得在事务中发 UI 通知。

`createAndAttach` 同时写目录和一个 ClipItem；`delete` 解密所有 ClipItem，只有包含目标 ID 的行才重写；
`rename` 只改目录 blob。`attach/detach` 保持系统标签第一、用户标签稳定关联顺序，并去重 ID。

`EncryptedStore.update(_:)` 也必须进入事务：按 ID 解密数据库中的最新 `ClipItem`，只用调用方
替换非标签字段，强制保留最新 `tagState`，再写回密文；不存在 ID 时才使用调用方完整值。
`ClipStore.updateClip(_:)` 成功后调用 `loadClips()`，不把旧调用参数直接塞回内存列表。
这样标签事务与内容/摘要/翻译等旧快照更新无论先后都不会回滚标签。

`EditableContentArea.performSave()` 重建 `ClipItem` 时仍显式传
`tagState: updated.tagState`，并用 `EditableContentAreaTests` 证明 View 层不会制造
`.legacy` 短暂状态；持久化集成测试才是并发正确性的最终 Gate。

- [ ] **步骤 5：运行 GREEN 与原存储回归**

运行：

```text
ClipMindTests/EncryptedTagStoreTests
ClipMindTests/EncryptedStoreTests
ClipMindTests/EncryptedStoreUpdateTests
ClipMindTests/EncryptionTests
ClipMindTests/EditableContentAreaTests
```

预期：全部 PASS；原有 `content_type`、`timestamp`、`source_app` 索引行为不变。

## 任务 5：唯一业务规则边界

**文件：**

- 创建：`ClipMind/Tags/TagService.swift`
- 创建：`ClipMindTests/Tags/TagServiceTests.swift`
- 创建：`ClipMindTests/Tags/TagAssociationTests.swift`

- [ ] **步骤 1：编写 RED 规则测试**

覆盖 DOM-002～010：

- trim 后空名称拒绝；
- 与 11 个系统标签或用户标签大小写不敏感重名拒绝；
- 第六个标签与满额创建共同拒绝；
- CODE 条目只能恢复 CODE，不能关联 LINK；
- 系统标签拒绝全局重命名/删除；
- 取消关联无需确认；
- 重命名保持 ID/关联/顺序；
- 系统标签先于用户标签，用户标签稳定关联顺序。

- [ ] **步骤 2：实现 `TagService`**

```swift
protocol TagServicing: AnyObject
{
    func snapshot() async throws -> TagSnapshot
    func createAndAttach(name: String, color: ClipTagColor, clipID: UUID) async throws -> TagSnapshot
    func setAttached(_ isAttached: Bool, tagID: ClipTagID, clipID: UUID) async throws -> TagSnapshot
    func renameUserTag(id: ClipTagID, name: String) async throws -> TagSnapshot
    func deleteUserTag(id: ClipTagID) async throws -> TagSnapshot
    func migrateNextBatch(limit: Int) async throws -> TagMigrationBatchResult
}

actor TagService: TagServicing
{
    static let maximumTagsPerClip = 5

    private let repository: TagRepository
    private let logger: TagOperationLogging

    init(repository: TagRepository, logger: TagOperationLogging)
    {
        self.repository = repository
        self.logger = logger
    }
}
```

每个方法按“读取最新快照 → 业务校验 → 单次 repository mutation → 重新读取快照 → 固定 metadata 日志”
执行。名称调用 `TagNameValidator.validate(candidate:existingTags:excluding:)`；
不得在 ViewModel、Service 或存储层手写第二份 trim/重名规则。

不使用 locale-dependent `localizedLowercase`。错误只抛 `TagError`；底层未知错误映射为
`.persistenceFailed`，日志只记录底层错误的稳定类型码，不记录 `localizedDescription`。

- [ ] **步骤 3：运行 GREEN**

运行 `TagServiceTests`、`TagAssociationTests`、`EncryptedTagStoreTests`。预期：全部 PASS。

- [ ] **步骤 4：提交领域与存储边界**

```bash
git add \
  ClipMind/Models/ClipTag.swift \
  ClipMind/Models/ClipTagState.swift \
  ClipMind/Models/SystemTagCatalog.swift \
  ClipMind/Models/ClipItem.swift \
  ClipMind/Tags \
  ClipMind/Storage/EncryptedStore.swift \
  ClipMind/Storage/EncryptedStore+Tags.swift \
  ClipMind/UI/MainWindow/EditableContentArea.swift \
  ClipMindTests/Tags \
  ClipMindTests/Storage/EncryptedTagStoreTests.swift \
  ClipMindTests/Storage/EncryptedStoreUpdateTests.swift \
  ClipMindTests/UI/EditableContentAreaTests.swift \
  ClipMindTests/Models
git commit -m "feat(tags): persist encrypted tag state"
```

提交前必须运行 `swiftlint lint --strict`。

## 任务 6：可恢复迁移

**文件：**

- 创建：`ClipMind/Tags/TagMigrationCoordinator.swift`
- 创建：`ClipMind/App/TagBackendAssembly.swift`
- 创建：`ClipMindTests/Storage/TagMigrationTests.swift`
- 修改：`ClipMind/App/ClipMindApp.swift`
- 修改：`ClipMind/UI/ClipStore.swift`

- [ ] **步骤 1：编写 RED 迁移测试**

用 100 条覆盖 11 类的 legacy `ClipItem` 夹具断言：

- 每条迁移后只关联自身系统标签；
- 批次中断后 `remainingCount` 正确，重开 store 后继续；
- 重复运行不产生重复 ID；
- `systemTagDisposition == .removed` 的条目不被恢复；
- 迁移失败保留上一个成功批次。

- [ ] **步骤 2：实现 repository 批次事务**

`migrateNextBatch(limit:)` 查询 `tagState.migrationVersion < currentMigrationVersion` 的条目，
最多处理 `limit` 条。`.pendingMigration` 加入自身系统标签并转为 `.associated`；
`.removed` 保持无系统关联，只更新版本。每批一个事务。

- [ ] **步骤 3：实现协调器**

```swift
actor TagMigrationCoordinator
{
    static let batchSize = 100

    private let service: TagServicing
    private let notificationCenter: NotificationCenter

    init(service: TagServicing, notificationCenter: NotificationCenter = .default)
    {
        self.service = service
        self.notificationCenter = notificationCenter
    }

    func resume() async throws
    {
        var result: TagMigrationBatchResult
        repeat
        {
            result = try await service.migrateNextBatch(limit: Self.batchSize)
            if result.migratedCount > 0
            {
                await MainActor.run
                {
                    notificationCenter.post(name: .clipTagsDidUpdate, object: nil)
                }
            }
        }
        while result.remainingCount > 0
    }
}
```

通知名作为 `Notification.Name` 命名常量定义；它们不携带标签名或 clip 内容。

`TagBackendAssembly.swift` 定义：

```swift
struct TagBackend
{
    let service: TagServicing
    let migrationCoordinator: TagMigrationCoordinator
}

enum TagBackendFactory
{
    static func makeDefault() -> TagBackend
}
```

factory 只创建一个指向默认数据库的 `EncryptedStore`、`DefaultTagOperationLogger` 和
`TagService`，同一 service 同时交给 coordinator 和后续 Phase 2 的 `TagStore`。
初始化失败时改用 `UnavailableTagService`；其 snapshot/mutation/migrate 都抛
`.persistenceFailed`，不得创建第二个空数据库。

`AppDelegate` 以 `@MainActor lazy var tagBackend = TagBackendFactory.makeDefault()` 保存唯一
backend。`ClipMindApp` 在首个界面装配完成后用继承取消语义的 `Task` 调用
`appDelegate.tagBackend.migrationCoordinator.resume()`，catch 时只发布
`.clipTagMigrationNeedsRetry`；不使用 `Task.detached`。Phase 2 接入 `TagStore` 后，把该调用
收敛为 `tagStore.resumeMigration()`，由 UI 状态保存安全错误与 retry operation。
`ClipStore` 监听 `.clipTagsDidUpdate` 后刷新。

- [ ] **步骤 4：运行 GREEN 与 1000 条性能基线**

运行 `TagMigrationTests`；另用 1000 条夹具记录迁移时间，当前 Phase 只保存数值，
Phase 5 才执行 20 次 p95 Gate。预期：功能测试 PASS，无重复关联。

## 任务 7：新条目与默认系统标签共同发布

**文件：**

- 修改：`ClipMind/Capture/ClipCaptureService.swift`
- 修改：`ClipMind/App/ClipMindApp.swift`
- 创建：`ClipMindTests/Tags/NewClipTagIntegrationTests.swift`

- [ ] **步骤 1：编写 RED 集成测试**

对文本、图片和文件路径各断言成功保存后 `onClipStored` 收到带自身系统标签的条目。
注入保存失败时断言：

- `onClipStored` 未调用；
- `clipDidUpdateNotification` 未发送；
- 数据库不存在半完成条目；
- 日志不含内容或标签名称。

- [ ] **步骤 2：实现完整发布边界**

`ClipItem.makeText/makeImage/makeFilePath` 已创建默认关联，因此
`ClipCaptureService.saveAndNotify(item:)` 保持一个 `store.save(item)`：
只有加密 `content_blob`（含 tagState）成功后才通知和回调。
不得在分类前或保存后追加第二次标签写入。

文件路径自动保存的 `saveFilePathToHistory` 同样使用工厂，成功通知前不做补偿写入。

- [ ] **步骤 3：运行 GREEN 和捕获回归**

运行：

```text
ClipMindTests/NewClipTagIntegrationTests
ClipMindTests/ClipCaptureServiceTests
ClipMindTests/ClipCaptureServiceEventTests
ClipMindTests/EncryptedStoreTests
```

预期：全部 PASS。

- [ ] **步骤 4：提交迁移与接入**

```bash
git add \
  ClipMind/Tags/TagMigrationCoordinator.swift \
  ClipMind/App/TagBackendAssembly.swift \
  ClipMind/App/ClipMindApp.swift \
  ClipMind/UI/ClipStore.swift \
  ClipMind/Capture/ClipCaptureService.swift \
  ClipMindTests/Storage/TagMigrationTests.swift \
  ClipMindTests/Tags/NewClipTagIntegrationTests.swift
git commit -m "feat(tags): migrate system tag links"
```

## Phase 1 Local Gate

```bash
xcodegen generate
swiftlint lint --strict
xcodebuild build \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```

通过条件：

- DOM-001～011、MIG-001～003、SEC-001～002 自动化通过。
- 原始数据库不存在用户标签哨兵、颜色、来源或关联明文。
- 新条目保存失败不通知 UI。
- SwiftLint strict 0 violation，build succeeded。
- 两个 Phase 1 提交均可独立识别，工作树干净。

## 版本记录

| 版本 | 日期 | 变更说明 |
|------|------|---------|
| v1.0 | 2026-07-29 | 固定领域值类型、规则 actor、加密事务、可恢复迁移和新条目完整发布 TDD。 |
