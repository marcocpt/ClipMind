> 最后更新：2026-07-21 | 版本：v1.1

# Phase 0 子计划：核心保存逻辑

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 实现 F2.1 自动保存到文件的核心保存逻辑，包括配置模型、配置持久化、文件名生成、冲突处理、路径格式化和主服务（含白名单/长度/敏感检查、文件写入、剪贴板替换）。所有 33 条单元测试与 AC-04/06/10/11/12/13/14 驱动的测试在 Phase 0 完成时通过。

**架构：** 5 个新增 Swift 文件位于 `ClipMind/AutoSave/`，按单一职责拆分（配置模型 / 持久化 / 文件名+冲突 / 路径格式化 / 主服务）。`AutoSaveService` 为 `final class`，内部用串行 `DispatchQueue` 保证文件写入与剪贴板替换的线程安全（NFR-010）。对外暴露同步 `performAutoSave(...)`（测试用，`internal` 访问级别）与异步 `handle(...)`（生产用，`public` 访问级别）。

**技术栈：** Swift 5.7+ / macOS 12.4+ / Foundation / AppKit（NSPasteboard）/ XCTest / SwiftLint strict

---

## 1. 范围与非目标

### 1.1 范围

- 创建 5 个 Swift 文件（`ClipMind/AutoSave/AutoSaveSettings.swift`、`AutoSaveSettingsStore.swift`、`FileNameGenerator.swift`、`FilePathFormatter.swift`、`AutoSaveService.swift`）
- 创建 6 个单元测试文件（`ClipMindTests/AutoSave/*.swift`）
- 覆盖 33 条单元测试（TC-UT-01~33）
- 覆盖 AC-04、AC-06、AC-10、AC-11、AC-12、AC-13、AC-14 的 XCTest 部分
- 本地 `swiftlint lint --strict` 与 `xcodebuild build` 通过
- 单文件 `-only-testing` 单元测试通过

### 1.2 非目标

- 不修改 `ClipCaptureService.swift`（Phase 1）
- 不创建 UI 视图（Phase 1）
- 不执行 XCUITest（Phase 1）
- 不修改 `AppDelegate.swift`（Phase 1）
- 不执行 XCUITest 中的端到端流程（Phase 1）
- 不本地执行全量 `xcodebuild test`（仅 CI）

---

## 2. 涉及文件和职责

| 文件 | 职责 | 创建/修改 |
|------|------|-----------|
| `ClipMind/AutoSave/AutoSaveSettings.swift` | `AutoSaveSettings` 配置模型（struct，Codable/Equatable）+ `FileFormat` 枚举（markdown/plainText，带 `fileExtension` 属性）+ `PathFormat` 枚举（plainPath/fileURI/markdownLink）+ 默认值常量 + 范围常量 | 创建 |
| `ClipMind/AutoSave/AutoSaveSettingsStore.swift` | `AutoSaveSettingsStore` 持久化（final class，UserDefaults 包装）+ 范围校验 + 白名单去重 + 配置变更通知 | 创建 |
| `ClipMind/AutoSave/FileNameGenerator.swift` | `FileNameGenerator` 文件名生成器（struct）+ `FileNameConflictResolver` 冲突处理器（struct） | 创建 |
| `ClipMind/AutoSave/FilePathFormatter.swift` | `FilePathFormatter` 路径格式化器（struct） | 创建 |
| `ClipMind/AutoSave/AutoSaveService.swift` | `AutoSaveService` 主服务（final class）+ `State` 状态枚举 + `Outcome` 结果枚举 + 串行队列 + 同步入口 `performAutoSave` + 异步入口 `handle` | 创建 |
| `ClipMindTests/AutoSave/AutoSaveSettingsTests.swift` | 配置模型单元测试 | 创建 |
| `ClipMindTests/AutoSave/AutoSaveSettingsStoreTests.swift` | 配置持久化单元测试（TC-UT-20~23） | 创建 |
| `ClipMindTests/AutoSave/FileNameGeneratorTests.swift` | 文件名生成器单元测试（TC-UT-08~10、TC-AC10） | 创建 |
| `ClipMindTests/AutoSave/FileNameConflictResolverTests.swift` | 冲突处理器单元测试（TC-UT-11~13、TC-AC04） | 创建 |
| `ClipMindTests/AutoSave/FilePathFormatterTests.swift` | 路径格式化器单元测试（TC-UT-14~16、TC-AC11） | 创建 |
| `ClipMindTests/AutoSave/AutoSaveServiceTests.swift` | 主服务单元测试（TC-UT-17~19、TC-UT-24~33、TC-AC06/12/13/14） | 创建 |

**关键依赖关系**（任务执行顺序）：

```
任务 1（AutoSaveSettings） → 任务 2（AutoSaveSettingsStore）
                       ↘
                        → 任务 3（FileNameGenerator） → 任务 4（FileNameConflictResolver）
                       ↘
                        → 任务 5（FilePathFormatter）
                       ↘
                        → 任务 6（AutoSaveService） → 任务 7（跳过路径测试）
                                                  → 任务 8（异常路径测试）
                                                  → 任务 9（集成测试）
```

---

## 3. 任务列表

总计 9 个任务，每个任务包含 5 个步骤（编写失败测试 → 运行验证失败 → 编写实现 → 运行验证通过 → commit）。

---

### 任务 1：AutoSaveSettings 配置模型

**文件：**
- 创建：`ClipMind/AutoSave/AutoSaveSettings.swift`
- 测试：`ClipMindTests/AutoSave/AutoSaveSettingsTests.swift`

**目标：** 实现配置模型与 `FileFormat`/`PathFormat` 枚举，承载 8 个配置项（总开关、保存目录、白名单、文件格式、长度阈值、文件名长度、敏感过滤开关、路径格式），提供默认值与范围常量。

**对应 FR：** FR-001（总开关）、FR-010（配置面板独立分区，配置模型承载）、FR-012（白名单管理，配置模型承载）

**对应 AC：** AC-16（配置修改持久化，配置模型承载）

**对应约束：** C-01（保存目录默认值）、C-02（文件格式枚举）、C-03（路径格式枚举）、C-04（文件名长度范围 1-50）、C-05（长度阈值范围 1-10000）、C-06（白名单 Bundle ID）

- [ ] **步骤 1：编写失败的测试**

创建 `ClipMindTests/AutoSave/AutoSaveSettingsTests.swift`：

```swift
import XCTest

@testable import ClipMind

final class AutoSaveSettingsTests: XCTestCase
{
    // MARK: - 默认值

    func testDefaultValues() throws
    {
        let settings = AutoSaveSettings()
        XCTAssertTrue(settings.isEnabled, "总开关默认应为开")
        XCTAssertEqual(settings.saveDirectory, "~/Documents/ClipMind/Clips/")
        XCTAssertEqual(settings.whitelistBundleIds, AutoSaveSettings.defaultWhitelist)
        XCTAssertEqual(settings.fileFormat, .markdown)
        XCTAssertEqual(settings.lengthThreshold, 50)
        XCTAssertEqual(settings.fileNameLength, 20)
        XCTAssertTrue(settings.sensitiveFilterEnabled)
        XCTAssertEqual(settings.pathFormat, .plainPath)
    }

    // MARK: - 范围常量

    func testRangeConstants() throws
    {
        XCTAssertEqual(AutoSaveSettings.lengthThresholdRange, 1...10000)
        XCTAssertEqual(AutoSaveSettings.fileNameLengthRange, 1...50)
    }

    // MARK: - 默认白名单内容

    func testDefaultWhitelistContains() throws
    {
        let whitelist = AutoSaveSettings.defaultWhitelist
        XCTAssertEqual(whitelist.count, 5)
        XCTAssertTrue(whitelist.contains("com.apple.Safari"))
        XCTAssertTrue(whitelist.contains("com.google.Chrome"))
        XCTAssertTrue(whitelist.contains("com.trae.ide"))
        XCTAssertTrue(whitelist.contains("com.microsoft.VSCode"))
        XCTAssertTrue(whitelist.contains("com.apple.dt.Xcode"))
    }

    // MARK: - 文件格式扩展名

    func testFileFormatExtension() throws
    {
        XCTAssertEqual(FileFormat.markdown.fileExtension, "md")
        XCTAssertEqual(FileFormat.plainText.fileExtension, "txt")
    }

    // MARK: - Codable 往返

    func testCodableRoundTrip() throws
    {
        let settings = AutoSaveSettings(
            isEnabled: false,
            saveDirectory: "/tmp/test/",
            whitelistBundleIds: ["com.test.app"],
            fileFormat: .plainText,
            lengthThreshold: 100,
            fileNameLength: 30,
            sensitiveFilterEnabled: false,
            pathFormat: .markdownLink
        )
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AutoSaveSettings.self, from: data)
        XCTAssertEqual(settings, decoded)
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

```bash
xcodegen generate
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/AutoSaveSettingsTests'
```

预期：FAIL，报错 "cannot find 'AutoSaveSettings' in scope" 或 "no such module"。

- [ ] **步骤 3：编写实现代码**

创建 `ClipMind/AutoSave/AutoSaveSettings.swift`：

```swift
import Foundation

/// F2.1 自动保存文件格式枚举。
///
/// 支持两种格式：Markdown（.md）与纯文本（.txt）。
/// 满足 C-02。
public enum FileFormat: String, Codable, CaseIterable
{
    case markdown = "markdown"
    case plainText = "plainText"

    /// 文件扩展名（不含点）
    public var fileExtension: String
    {
        switch self
        {
        case .markdown:
            return "md"
        case .plainText:
            return "txt"
        }
    }
}

/// F2.1 路径格式枚举。
///
/// 支持三种格式：纯路径字符串、file:// URI、Markdown 链接。
/// 满足 C-03。
public enum PathFormat: String, Codable, CaseIterable
{
    case plainPath = "plainPath"
    case fileURI = "fileURI"
    case markdownLink = "markdownLink"
}

/// F2.1 自动保存配置模型。
///
/// 承载 8 个配置项：总开关、保存目录、白名单 App、文件格式、长度阈值、
/// 文件名前缀长度、敏感过滤开关、路径格式。
/// 满足 FR-001、FR-010、FR-012、C-01、C-04、C-05、C-06。
public struct AutoSaveSettings: Codable, Equatable
{
    /// 总开关（默认开）
    public var isEnabled: Bool

    /// 保存目录（默认 ~/Documents/ClipMind/Clips/）
    public var saveDirectory: String

    /// 白名单 App Bundle ID 列表
    public var whitelistBundleIds: [String]

    /// 文件格式（默认 Markdown）
    public var fileFormat: FileFormat

    /// 长度阈值（默认 50，范围 1-10000）
    public var lengthThreshold: Int

    /// 文件名前缀长度（默认 20，范围 1-50）
    public var fileNameLength: Int

    /// 敏感过滤开关（默认开）
    public var sensitiveFilterEnabled: Bool

    /// 路径格式（默认纯路径字符串）
    public var pathFormat: PathFormat

    /// 默认白名单 App Bundle ID（5 个主流浏览器与 IDE）
    public static let defaultWhitelist: [String] = [
        "com.apple.Safari",
        "com.google.Chrome",
        "com.trae.ide",
        "com.microsoft.VSCode",
        "com.apple.dt.Xcode"
    ]

    /// 默认保存目录
    public static let defaultSaveDirectory: String = "~/Documents/ClipMind/Clips/"

    /// 默认长度阈值
    public static let defaultLengthThreshold: Int = 50

    /// 默认文件名前缀长度
    public static let defaultFileNameLength: Int = 20

    /// 长度阈值范围（1-10000）
    public static let lengthThresholdRange = 1...10000

    /// 文件名前缀长度范围（1-50）
    public static let fileNameLengthRange = 1...50

    public init(
        isEnabled: Bool = true,
        saveDirectory: String = defaultSaveDirectory,
        whitelistBundleIds: [String] = defaultWhitelist,
        fileFormat: FileFormat = .markdown,
        lengthThreshold: Int = defaultLengthThreshold,
        fileNameLength: Int = defaultFileNameLength,
        sensitiveFilterEnabled: Bool = true,
        pathFormat: PathFormat = .plainPath
    )
    {
        self.isEnabled = isEnabled
        self.saveDirectory = saveDirectory
        self.whitelistBundleIds = whitelistBundleIds
        self.fileFormat = fileFormat
        self.lengthThreshold = lengthThreshold
        self.fileNameLength = fileNameLength
        self.sensitiveFilterEnabled = sensitiveFilterEnabled
        self.pathFormat = pathFormat
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/AutoSaveSettingsTests'
```

预期：PASS，5 个测试用例全部通过。

- [ ] **步骤 5：Commit**

```bash
swiftlint lint --strict
git add ClipMind/AutoSave/AutoSaveSettings.swift ClipMindTests/AutoSave/AutoSaveSettingsTests.swift
git commit -m "feat(F2.1): 实现 AutoSaveSettings 配置模型"
```

预期：SwiftLint 通过；commit 成功。

---

### 任务 2：AutoSaveSettingsStore 持久化

**文件：**
- 创建：`ClipMind/AutoSave/AutoSaveSettingsStore.swift`
- 测试：`ClipMindTests/AutoSave/AutoSaveSettingsStoreTests.swift`

**目标：** 用 UserDefaults 持久化 `AutoSaveSettings`，提供范围校验（C-04/C-05）、白名单去重（C-06）、配置变更通知（NFR-003）。

**对应 FR：** FR-010（配置项修改后立即生效）、FR-016（配置持久化）

**对应 AC：** AC-16（配置修改持久化）

**对应单元测试：** TC-UT-20（长度阈值超范围）、TC-UT-21（文件名长度超范围）、TC-UT-22（白名单去重）、TC-UT-23（配置变更通知）

- [ ] **步骤 1：编写失败的测试**

创建 `ClipMindTests/AutoSave/AutoSaveSettingsStoreTests.swift`：

```swift
import XCTest

@testable import ClipMind

final class AutoSaveSettingsStoreTests: XCTestCase
{
    private var defaults: UserDefaults!
    private var store: AutoSaveSettingsStore!

    override func setUpWithError() throws
    {
        let suiteName = "test-autosave-store-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        store = AutoSaveSettingsStore(defaults: defaults)
    }

    override func tearDownWithError() throws
    {
        if let suiteName = defaults?.dictionaryRepresentation().keys.first
        {
            UserDefaults().removePersistentDomain(forName: suiteName)
        }
        defaults = nil
        store = nil
    }

    // MARK: - TC-UT-20: 长度阈值超范围（>10000）→ 使用默认值 50

    func testLengthThresholdOutOfRangeUsesDefault() throws
    {
        var settings = AutoSaveSettings()
        settings.lengthThreshold = 99999
        store.update(settings)
        XCTAssertEqual(store.current.lengthThreshold, 50, "长度阈值超范围应回退到默认 50")
    }

    func testLengthThresholdBelowMinimumUsesDefault() throws
    {
        var settings = AutoSaveSettings()
        settings.lengthThreshold = 0
        store.update(settings)
        XCTAssertEqual(store.current.lengthThreshold, 50)
    }

    // MARK: - TC-UT-21: 文件名长度超范围（>50）→ 使用默认值 20

    func testFileNameLengthOutOfRangeUsesDefault() throws
    {
        var settings = AutoSaveSettings()
        settings.fileNameLength = 100
        store.update(settings)
        XCTAssertEqual(store.current.fileNameLength, 20, "文件名长度超范围应回退到默认 20")
    }

    // MARK: - TC-UT-22: 白名单添加重复 Bundle ID → 拒绝添加（去重）

    func testWhitelistDuplicateBundleIdRemoved() throws
    {
        var settings = AutoSaveSettings()
        settings.whitelistBundleIds = [
            "com.apple.Safari",
            "com.apple.Safari",
            "com.google.Chrome"
        ]
        store.update(settings)
        XCTAssertEqual(
            store.current.whitelistBundleIds,
            ["com.apple.Safari", "com.google.Chrome"],
            "重复 Bundle ID 应被去重"
        )
    }

    // MARK: - TC-UT-23: 配置修改后 1 秒内推送变更通知

    func testConfigChangeNotificationPostedImmediately() throws
    {
        let expectation = XCTestExpectation(description: "配置变更应立即推送通知")
        let observer = NotificationCenter.default.addObserver(
            forName: AutoSaveSettingsStore.configDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        var settings = AutoSaveSettings()
        settings.lengthThreshold = 100
        store.update(settings)

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - 默认值

    func testDefaultSettingsWhenNoData() throws
    {
        XCTAssertEqual(store.current, AutoSaveSettings(), "无数据时应返回默认配置")
    }

    // MARK: - 持久化往返

    func testPersistAndLoad() throws
    {
        var settings = AutoSaveSettings()
        settings.isEnabled = false
        settings.saveDirectory = "/tmp/custom/"
        settings.whitelistBundleIds = ["com.test.app"]
        settings.fileFormat = .plainText
        settings.lengthThreshold = 200
        settings.fileNameLength = 15
        settings.sensitiveFilterEnabled = false
        settings.pathFormat = .fileURI

        store.update(settings)
        XCTAssertEqual(store.current, settings, "持久化往返应保持等价")
    }

    // MARK: - reset

    func testResetToDefault() throws
    {
        var settings = AutoSaveSettings()
        settings.lengthThreshold = 999
        store.update(settings)
        XCTAssertEqual(store.current.lengthThreshold, 50)

        store.reset()
        XCTAssertEqual(store.current, AutoSaveSettings(), "reset 后应回默认配置")
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/AutoSaveSettingsStoreTests'
```

预期：FAIL，报错 "cannot find 'AutoSaveSettingsStore' in scope"。

- [ ] **步骤 3：编写实现代码**

创建 `ClipMind/AutoSave/AutoSaveSettingsStore.swift`：

```swift
import Foundation

/// F2.1 自动保存配置持久化存储。
///
/// 使用 UserDefaults 持久化 AutoSaveSettings，提供范围校验、白名单去重、
/// 配置变更通知。
/// 满足 FR-010、FR-016、AC-16、NFR-003（1 秒内生效）、C-04、C-05、C-06。
public final class AutoSaveSettingsStore
{
    /// UserDefaults 键名
    public static let storageKey = "autoSaveSettings"

    /// 配置变更通知名（NFR-003）
    public static let configDidChangeNotification = Notification.Name("ClipMindAutoSaveConfigDidChange")

    /// UserDefaults 实例（支持注入用于测试）
    private let defaults: UserDefaults

    /// 初始化
    /// - Parameter defaults: UserDefaults 实例，默认为 .standard
    public init(defaults: UserDefaults = .standard)
    {
        self.defaults = defaults
    }

    /// 读取当前配置。
    ///
    /// 若 UserDefaults 无数据或反序列化失败，返回默认配置。
    public var current: AutoSaveSettings
    {
        guard let data = defaults.data(forKey: Self.storageKey) else
        {
            return AutoSaveSettings()
        }
        return (try? JSONDecoder().decode(AutoSaveSettings.self, from: data)) ?? AutoSaveSettings()
    }

    /// 更新配置。
    ///
    /// 持久化前进行范围校验与白名单去重，持久化后推送配置变更通知。
    /// - Parameter settings: 待持久化的配置
    public func update(_ settings: AutoSaveSettings)
    {
        let sanitized = sanitize(settings)
        guard let data = try? JSONEncoder().encode(sanitized) else
        {
            LogCategory.storage.error("AutoSaveSettings encode failed")
            return
        }
        defaults.set(data, forKey: Self.storageKey)
        NotificationCenter.default.post(name: Self.configDidChangeNotification, object: nil)
        LogCategory.storage.info("AutoSaveSettings updated")
    }

    /// 重置为默认配置。
    public func reset()
    {
        update(AutoSaveSettings())
    }

    /// 范围校验与白名单去重（C-04、C-05、C-06）。
    private func sanitize(_ settings: AutoSaveSettings) -> AutoSaveSettings
    {
        var sanitized = settings
        if !AutoSaveSettings.lengthThresholdRange.contains(sanitized.lengthThreshold)
        {
            sanitized.lengthThreshold = AutoSaveSettings.defaultLengthThreshold
        }
        if !AutoSaveSettings.fileNameLengthRange.contains(sanitized.fileNameLength)
        {
            sanitized.fileNameLength = AutoSaveSettings.defaultFileNameLength
        }
        var seen = Set<String>()
        sanitized.whitelistBundleIds = sanitized.whitelistBundleIds.filter { bundleId in
            if seen.contains(bundleId) { return false }
            seen.insert(bundleId)
            return true
        }
        return sanitized
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/AutoSaveSettingsStoreTests'
```

预期：PASS，8 个测试用例全部通过。

- [ ] **步骤 5：Commit**

```bash
swiftlint lint --strict
git add ClipMind/AutoSave/AutoSaveSettingsStore.swift ClipMindTests/AutoSave/AutoSaveSettingsStoreTests.swift
git commit -m "feat(F2.1): 实现 AutoSaveSettingsStore 配置持久化"
```

---

### 任务 3：FileNameGenerator 文件名生成器

**文件：**
- 创建：`ClipMind/AutoSave/FileNameGenerator.swift`（包含 `FileNameGenerator` 类型；任务 4 在此文件追加 `FileNameConflictResolver`）
- 测试：`ClipMindTests/AutoSave/FileNameGeneratorTests.swift`

**目标：** 根据内容前缀生成候选文件名，过滤换行符、路径分隔符、文件系统特殊字符，保留中文，按配置长度截断，附加扩展名。

**对应 FR：** FR-006（文件名生成）

**对应 AC：** AC-10（文件名过滤特殊字符保留中文）

**对应单元测试：** TC-UT-08（过滤特殊字符）、TC-UT-09（截断）、TC-UT-10（不足 N 字使用全部）

- [ ] **步骤 1：编写失败的测试**

创建 `ClipMindTests/AutoSave/FileNameGeneratorTests.swift`：

```swift
import XCTest

@testable import ClipMind

final class FileNameGeneratorTests: XCTestCase
{
    // MARK: - TC-UT-08: 内容含换行符、路径分隔符、问号 → 过滤后保留中文

    func testFilterSpecialCharsKeepChinese() throws
    {
        let content = "你好世界\n这是测试/content?extra"
        let name = FileNameGenerator.generate(
            from: content,
            length: 20,
            fileFormat: .markdown
        )
        XCTAssertEqual(name, "你好世界这是测试contentextra.md")
    }

    // MARK: - TC-AC10: AC-10 验证场景

    func testAC10Scenario() throws
    {
        // AC-10: 内容以"你好世界\n这是测试/content?"开头
        let content = "你好世界\n这是测试/content?这是超过 50 字的额外内容需要被截断"
        let name = FileNameGenerator.generate(
            from: content,
            length: 20,
            fileFormat: .markdown
        )
        XCTAssertEqual(name, "你好世界这是测试content.md", "AC-10: 过滤特殊字符保留中文")
    }

    // MARK: - TC-UT-09: 内容长度超过 N 字 → 截断为前 N 字

    func testTruncateToMaxLength() throws
    {
        let content = "abcdefghijklmnopqrstuvwxy"  // 25 字符
        let name = FileNameGenerator.generate(
            from: content,
            length: 10,
            fileFormat: .markdown
        )
        XCTAssertEqual(name, "abcdefghij.md")
    }

    // MARK: - TC-UT-10: 内容长度不足 N 字 → 使用全部内容

    func testUseAllContentWhenShorterThanN() throws
    {
        let name = FileNameGenerator.generate(
            from: "short",
            length: 20,
            fileFormat: .plainText
        )
        XCTAssertEqual(name, "short.txt")
    }

    // MARK: - 空内容使用默认前缀 "clip"

    func testEmptyContentUsesDefaultPrefix() throws
    {
        let name = FileNameGenerator.generate(
            from: "",
            length: 20,
            fileFormat: .markdown
        )
        XCTAssertEqual(name, "clip.md")
    }

    // MARK: - 仅特殊字符也应回退到默认前缀

    func testOnlySpecialCharsUsesDefaultPrefix() throws
    {
        let name = FileNameGenerator.generate(
            from: "\n/\\?*",
            length: 20,
            fileFormat: .markdown
        )
        XCTAssertEqual(name, "clip.md")
    }

    // MARK: - 文件格式扩展名

    func testMarkdownExtension() throws
    {
        XCTAssertEqual(
            FileNameGenerator.generate(from: "hello", length: 20, fileFormat: .markdown),
            "hello.md"
        )
    }

    func testPlainTextExtension() throws
    {
        XCTAssertEqual(
            FileNameGenerator.generate(from: "hello", length: 20, fileFormat: .plainText),
            "hello.txt"
        )
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/FileNameGeneratorTests'
```

预期：FAIL，报错 "cannot find 'FileNameGenerator' in scope"。

- [ ] **步骤 3：编写实现代码**

创建 `ClipMind/AutoSave/FileNameGenerator.swift`：

```swift
import Foundation

/// F2.1 文件名生成器。
///
/// 根据内容前缀与配置生成候选文件名（过滤特殊字符、长度截断、附加扩展名）。
/// 满足 FR-006 与 AC-10。
public struct FileNameGenerator
{
    /// 需要过滤的字符集：换行符 + 路径分隔符（/ \）+ 文件系统特殊字符（: * ? " < > |）
    private static let invalidCharacters: CharacterSet = {
        var set = CharacterSet.newlines
        set.insert(charactersIn: "/\\:*?\"<>|")
        return set
    }()

    /// 内容为空时的默认前缀
    private static let defaultPrefix = "clip"

    /// 根据内容生成候选文件名。
    ///
    /// - Parameters:
    ///   - content: 复制内容
    ///   - length: 文件名前缀最大长度（字符数）
    ///   - fileFormat: 文件格式
    /// - Returns: 候选文件名（如 "你好世界这是测试content.md"）
    public static func generate(
        from content: String,
        length: Int,
        fileFormat: FileFormat
    ) -> String
    {
        let prefix = sanitize(content, maxLength: length)
        return "\(prefix).\(fileFormat.fileExtension)"
    }

    /// 过滤特殊字符并截断到指定长度。
    private static func sanitize(_ content: String, maxLength: Int) -> String
    {
        // 取前 maxLength 字符（按 Unicode 标量，保留中文）
        let truncated = String(content.prefix(maxLength))
        // 过滤换行符、路径分隔符、特殊字符
        let cleaned = truncated
            .components(separatedBy: invalidCharacters)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? defaultPrefix : cleaned
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/FileNameGeneratorTests'
```

预期：PASS，8 个测试用例全部通过。

- [ ] **步骤 5：Commit**

```bash
swiftlint lint --strict
git add ClipMind/AutoSave/FileNameGenerator.swift ClipMindTests/AutoSave/FileNameGeneratorTests.swift
git commit -m "feat(F2.1): 实现 FileNameGenerator 文件名生成器"
```

---

### 任务 4：FileNameConflictResolver 冲突处理器

**文件：**
- 修改：`ClipMind/AutoSave/FileNameGenerator.swift`（在文件末尾追加 `FileNameConflictResolver` 类型）
- 测试：`ClipMindTests/AutoSave/FileNameConflictResolverTests.swift`

**目标：** 检测目标目录是否存在同名文件，存在则追加序号（content-1.md、content-2.md），序号从 1 递增直到无冲突。

**对应 FR：** FR-007（文件名冲突处理）

**对应 AC：** AC-04（文件名冲突自动追加序号）

**对应单元测试：** TC-UT-11（无冲突）、TC-UT-12（追加 1）、TC-UT-13（追加 2）

- [ ] **步骤 1：编写失败的测试**

创建 `ClipMindTests/AutoSave/FileNameConflictResolverTests.swift`：

```swift
import XCTest

@testable import ClipMind

final class FileNameConflictResolverTests: XCTestCase
{
    private var tempDir: URL!

    override func setUpWithError() throws
    {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
    }

    override func tearDownWithError() throws
    {
        if let tempDir = tempDir
        {
            try? FileManager.default.removeItem(at: tempDir)
        }
    }

    // MARK: - TC-UT-11: 无同名文件 → 返回原候选名

    func testNoConflictReturnsOriginal() throws
    {
        let resolved = FileNameConflictResolver.resolve(
            candidateName: "content.md",
            in: tempDir
        )
        XCTAssertEqual(resolved, "content.md")
    }

    // MARK: - TC-UT-12: 存在同名文件 → 追加序号 1

    func testConflictReturnsSuffix1() throws
    {
        let existing = tempDir.appendingPathComponent("content.md")
        try "old content".write(to: existing, atomically: true, encoding: .utf8)

        let resolved = FileNameConflictResolver.resolve(
            candidateName: "content.md",
            in: tempDir
        )
        XCTAssertEqual(resolved, "content-1.md")
    }

    // MARK: - TC-UT-13: 存在 content.md 与 content-1.md → 追加序号 2

    func testConflictReturnsSuffix2() throws
    {
        try "old".write(
            to: tempDir.appendingPathComponent("content.md"),
            atomically: true,
            encoding: .utf8
        )
        try "old1".write(
            to: tempDir.appendingPathComponent("content-1.md"),
            atomically: true,
            encoding: .utf8
        )

        let resolved = FileNameConflictResolver.resolve(
            candidateName: "content.md",
            in: tempDir
        )
        XCTAssertEqual(resolved, "content-2.md")
    }

    // MARK: - TC-AC04: 连续两次复制相同内容（集成场景）

    func testAC04SequentialConflict() throws
    {
        // 第一次：无冲突
        let first = FileNameConflictResolver.resolve(
            candidateName: "content.md",
            in: tempDir
        )
        XCTAssertEqual(first, "content.md")
        // 模拟写入文件
        try "first".write(
            to: tempDir.appendingPathComponent(first),
            atomically: true,
            encoding: .utf8
        )

        // 第二次：应追加 -1
        let second = FileNameConflictResolver.resolve(
            candidateName: "content.md",
            in: tempDir
        )
        XCTAssertEqual(second, "content-1.md", "AC-04: 第二次应追加 -1")
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/FileNameConflictResolverTests'
```

预期：FAIL，报错 "cannot find 'FileNameConflictResolver' in scope"。

- [ ] **步骤 3：编写实现代码**

在 `ClipMind/AutoSave/FileNameGenerator.swift` 末尾追加：

```swift

/// F2.1 文件名冲突处理器。
///
/// 检测目标目录是否存在同名文件，存在则追加序号（如 content-1.md、content-2.md），
/// 序号从 1 开始递增直到无冲突。
/// 满足 FR-007 与 AC-04。
public struct FileNameConflictResolver
{
    /// 解析文件名冲突。
    ///
    /// - Parameters:
    ///   - candidateName: 候选文件名（含扩展名，如 "content.md"）
    ///   - directory: 目标目录 URL
    ///   - fileManager: 文件管理器（支持注入用于测试）
    /// - Returns: 最终无冲突的文件名
    public static func resolve(
        candidateName: String,
        in directory: URL,
        fileManager: FileManager = .default
    ) -> String
    {
        let baseURL = directory.appendingPathComponent(candidateName)
        if !fileManager.fileExists(atPath: baseURL.path)
        {
            return candidateName
        }

        let nameStem = (candidateName as NSString).deletingPathExtension
        let ext = (candidateName as NSString).pathExtension
        var index = 1
        while true
        {
            let newName: String
            if ext.isEmpty
            {
                newName = "\(nameStem)-\(index)"
            }
            else
            {
                newName = "\(nameStem)-\(index).\(ext)"
            }
            let newURL = directory.appendingPathComponent(newName)
            if !fileManager.fileExists(atPath: newURL.path)
            {
                return newName
            }
            index += 1
        }
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/FileNameConflictResolverTests'
```

预期：PASS，4 个测试用例全部通过。

- [ ] **步骤 5：Commit**

```bash
swiftlint lint --strict
git add ClipMind/AutoSave/FileNameGenerator.swift ClipMindTests/AutoSave/FileNameConflictResolverTests.swift
git commit -m "feat(F2.1): 实现 FileNameConflictResolver 冲突处理器"
```

---

### 任务 5：FilePathFormatter 路径格式化器

**文件：**
- 创建：`ClipMind/AutoSave/FilePathFormatter.swift`
- 测试：`ClipMindTests/AutoSave/FilePathFormatterTests.swift`

**目标：** 将绝对路径按配置格式输出（纯路径字符串、file:// URI、Markdown 链接）。

**对应 FR：** FR-013（路径格式切换）

**对应 AC：** AC-11（路径格式可在三种格式间切换）

**对应单元测试：** TC-UT-14（纯路径）、TC-UT-15（file:// URI）、TC-UT-16（Markdown 链接）

- [ ] **步骤 1：编写失败的测试**

创建 `ClipMindTests/AutoSave/FilePathFormatterTests.swift`：

```swift
import XCTest

@testable import ClipMind

final class FilePathFormatterTests: XCTestCase
{
    private let testPath = "/Users/testuser/Documents/ClipMind/Clips/content.md"

    // MARK: - TC-UT-14: 纯路径字符串 → 输出绝对路径

    func testPlainPathFormat() throws
    {
        XCTAssertEqual(
            FilePathFormatter.format(testPath, as: .plainPath),
            testPath
        )
    }

    // MARK: - TC-UT-15: file:// URI 格式 → 输出 file:// + 绝对路径

    func testFileURIFormat() throws
    {
        XCTAssertEqual(
            FilePathFormatter.format(testPath, as: .fileURI),
            "file:///Users/testuser/Documents/ClipMind/Clips/content.md"
        )
    }

    // MARK: - TC-UT-16: Markdown 链接 → 输出 [文件名](file://绝对路径)

    func testMarkdownLinkFormat() throws
    {
        XCTAssertEqual(
            FilePathFormatter.format(testPath, as: .markdownLink),
            "[content.md](file:///Users/testuser/Documents/ClipMind/Clips/content.md)"
        )
    }

    // MARK: - TC-AC11: 三种格式切换

    func testAC11ThreeFormats() throws
    {
        XCTAssertEqual(
            FilePathFormatter.format(testPath, as: .plainPath),
            "/Users/testuser/Documents/ClipMind/Clips/content.md"
        )
        XCTAssertEqual(
            FilePathFormatter.format(testPath, as: .fileURI),
            "file:///Users/testuser/Documents/ClipMind/Clips/content.md"
        )
        XCTAssertEqual(
            FilePathFormatter.format(testPath, as: .markdownLink),
            "[content.md](file:///Users/testuser/Documents/ClipMind/Clips/content.md)"
        )
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/FilePathFormatterTests'
```

预期：FAIL，报错 "cannot find 'FilePathFormatter' in scope"。

- [ ] **步骤 3：编写实现代码**

创建 `ClipMind/AutoSave/FilePathFormatter.swift`：

```swift
import Foundation

/// F2.1 路径格式化器。
///
/// 将绝对路径按用户配置格式（纯路径字符串、file:// URI、Markdown 链接）输出。
/// 满足 FR-013 与 AC-11。
public struct FilePathFormatter
{
    /// 格式化绝对路径。
    ///
    /// - Parameters:
    ///   - absolutePath: 文件绝对路径（如 "/Users/xxx/Documents/ClipMind/Clips/content.md"）
    ///   - format: 路径格式
    /// - Returns: 格式化后的字符串
    public static func format(
        _ absolutePath: String,
        as format: PathFormat
    ) -> String
    {
        switch format
        {
        case .plainPath:
            return absolutePath
        case .fileURI:
            return "file://" + absolutePath
        case .markdownLink:
            let fileName = (absolutePath as NSString).lastPathComponent
            return "[\(fileName)](file://\(absolutePath))"
        }
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/FilePathFormatterTests'
```

预期：PASS，4 个测试用例全部通过。

- [ ] **步骤 5：Commit**

```bash
swiftlint lint --strict
git add ClipMind/AutoSave/FilePathFormatter.swift ClipMindTests/AutoSave/FilePathFormatterTests.swift
git commit -m "feat(F2.1): 实现 FilePathFormatter 路径格式化器"
```

---

### 任务 6：AutoSaveService 主服务（核心 + 主路径测试）

**文件：**
- 创建：`ClipMind/AutoSave/AutoSaveService.swift`
- 测试：`ClipMindTests/AutoSave/AutoSaveServiceTests.swift`

**目标：** 实现主服务，协调白名单/长度/敏感检查、文件名生成、冲突处理、文件写入、路径格式化、剪贴板替换。提供同步入口 `performAutoSave(...)`（测试用）与异步入口 `handle(...)`（生产用）。

**对应 FR：** FR-001（总开关）、FR-002（白名单）、FR-003（长度阈值）、FR-004（敏感过滤）、FR-005（文件保存）、FR-008（剪贴板替换）、FR-014（互不阻塞）

**对应 AC：** AC-01（主路径）、AC-13（入库失败不影响文件写入，仅 AutoSaveService 侧）

**对应单元测试：** TC-UT-17（目录可写→写入成功）、TC-UT-29（检查中→待写入）、TC-UT-31（写入中→待替换）

- [ ] **步骤 1：编写失败的测试（主路径）**

创建 `ClipMindTests/AutoSave/AutoSaveServiceTests.swift`：

```swift
import AppKit
import XCTest

@testable import ClipMind

final class AutoSaveServiceTests: XCTestCase
{
    private var defaults: UserDefaults!
    private var settingsStore: AutoSaveSettingsStore!
    private var sensitiveDetector: SensitiveDetector!
    private var pasteboard: NSPasteboard!
    private var tempDir: URL!
    private var service: AutoSaveService!

    override func setUpWithError() throws
    {
        let suiteName = "test-autosave-svc-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        settingsStore = AutoSaveSettingsStore(defaults: defaults)
        sensitiveDetector = SensitiveDetector(defaults: defaults)
        pasteboard = NSPasteboard(name: .init("test-pb-\(UUID().uuidString)"))
        pasteboard.clearContents()

        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )

        service = AutoSaveService(
            settingsStore: settingsStore,
            sensitiveDetector: sensitiveDetector,
            pasteboard: pasteboard,
            fileManager: .default
        )
    }

    override func tearDownWithError() throws
    {
        if let tempDir = tempDir
        {
            try? FileManager.default.removeItem(at: tempDir)
        }
        if let suiteName = defaults?.dictionaryRepresentation().keys.first
        {
            UserDefaults().removePersistentDomain(forName: suiteName)
        }
    }

    // MARK: - 辅助：保存目录 URL

    private var saveDirectoryURL: URL
    {
        tempDir.appendingPathComponent("Clips", isDirectory: true)
    }

    // MARK: - TC-UT-17: 目录可写 → 写入成功（TC-UT-29、TC-UT-31 主路径覆盖）

    func testWriteSuccessWhenDirectoryWritable() throws
    {
        var settings = AutoSaveSettings()
        settings.isEnabled = true
        settings.saveDirectory = saveDirectoryURL.path
        settings.whitelistBundleIds = ["com.apple.Safari"]
        settings.lengthThreshold = 10
        settings.sensitiveFilterEnabled = false
        settingsStore.update(settings)

        let outcome = service.performAutoSave(
            content: .text("hello world this is a long content"),
            bundleId: "com.apple.Safari",
            appName: "Safari"
        )

        if case .completed(let filePath, let clipboardContent) = outcome
        {
            XCTAssertTrue(FileManager.default.fileExists(atPath: filePath), "文件应已写入")
            XCTAssertEqual(clipboardContent, filePath, "纯路径格式应等于文件路径")
            // 验证剪贴板内容
            let pbContent = pasteboard.string(forType: .string)
            XCTAssertEqual(pbContent, filePath, "剪贴板应被替换为文件路径")
        }
        else
        {
            XCTFail("应完成，实际: \(outcome)")
        }
    }

    // MARK: - 非文本内容跳过

    func testSkipNonTextContent() throws
    {
        var settings = AutoSaveSettings()
        settings.isEnabled = true
        settings.saveDirectory = saveDirectoryURL.path
        settings.whitelistBundleIds = ["com.apple.Safari"]
        settings.lengthThreshold = 10
        settings.sensitiveFilterEnabled = false
        settingsStore.update(settings)

        let outcome = service.performAutoSave(
            content: .image(Data([0x00, 0x01, 0x02])),
            bundleId: "com.apple.Safari",
            appName: "Safari"
        )

        if case .skipped(let reason) = outcome
        {
            XCTAssertEqual(reason, "non-text")
        }
        else
        {
            XCTFail("非文本应跳过")
        }
    }

    // MARK: - AC-09 (Phase 0 部分): 失败时发送 .autoSaveDidFail 通知

    func testAutoSaveServicePostsNotificationOnFailure() throws
    {
        var settings = AutoSaveSettings()
        settings.isEnabled = true
        // /proc 在 macOS 上不存在，路径无法创建
        settings.saveDirectory = "/proc/nonexistent/permission-denied/Clips/"
        settings.whitelistBundleIds = ["com.apple.Safari"]
        settings.lengthThreshold = 10
        settings.sensitiveFilterEnabled = false
        settingsStore.update(settings)

        let expectation = XCTestExpectation(description: "失败时应发送 .autoSaveDidFail 通知")
        let observer = NotificationCenter.default.addObserver(
            forName: AutoSaveService.didFailNotification,
            object: nil,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        let outcome = service.performAutoSave(
            content: .text("hello world long content"),
            bundleId: "com.apple.Safari",
            appName: "Safari"
        )

        if case .writeFailed = outcome
        {
            // 期望写入失败
        }
        else
        {
            XCTFail("应返回写入失败，实际: \(outcome)")
        }
        wait(for: [expectation], timeout: 1.0)
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/AutoSaveServiceTests'
```

预期：FAIL，报错 "cannot find 'AutoSaveService' in scope"。

- [ ] **步骤 3：编写实现代码**

创建 `ClipMind/AutoSave/AutoSaveService.swift`：

```swift
import AppKit
import Foundation

/// F2.1 自动保存主服务。
///
/// 协调白名单检查、长度检查、敏感检查、文件名生成、冲突处理、文件写入、
/// 路径格式化、剪贴板替换。与 F1.x 入库流程互不阻塞：通过串行队列异步触发，
/// 调用方立即返回。
/// 满足 FR-014、NFR-006、NFR-010。
public final class AutoSaveService
{
    /// 自动保存流程结果（供测试与日志使用）。
    public enum Outcome: Equatable
    {
        /// 跳过（总开关关闭 / 非白名单 / 长度不足 / 命中敏感 / 非文本）
        case skipped(reason: String)
        /// 写入失败（目录异常 / 写入错误）
        case writeFailed(reason: String)
        /// 替换失败（剪贴板写入异常）
        case replaceFailed(reason: String)
        /// 已完成（文件写入 + 剪贴板替换均成功）
        case completed(filePath: String, clipboardContent: String)
    }

    /// 自动保存失败通知名（供 AppDelegate 监听并弹窗提示用户，满足 AC-09）。
    public static let didFailNotification = Notification.Name("ClipMindAutoSaveDidFail")

    private let settingsStore: AutoSaveSettingsStore
    private let sensitiveDetector: SensitiveDetector
    private let pasteboard: NSPasteboard
    private let fileManager: FileManager
    private let queue: DispatchQueue
    private let logger = LogCategory.storage

    /// 可选的加密存储（仅用于 Phase 0 测试 AC-13：模拟 F1.x 入库失败场景）。
    ///
    /// 生产环境为 nil，F1.x 入库仍由 `ClipCaptureService` 负责（满足 FR-014 互不阻塞）。
    /// 测试环境注入一个会抛异常的 store，验证文件已写入不受入库失败影响。
    private let store: EncryptedStore?

    /// 初始化
    /// - Parameters:
    ///   - settingsStore: 自动保存配置存储
    ///   - sensitiveDetector: F1.x 敏感识别器（复用，不修改其规则）
    ///   - pasteboard: 系统剪贴板（默认 .general，测试可注入）
    ///   - fileManager: 文件管理器（默认 .default，测试可注入）
    ///   - queue: 串行队列（默认新建，保证文件写入与剪贴板替换的线程安全）
    ///   - store: 可选加密存储（默认 nil；测试 AC-13 时注入会抛异常的 store）
    public init(
        settingsStore: AutoSaveSettingsStore,
        sensitiveDetector: SensitiveDetector,
        pasteboard: NSPasteboard = .general,
        fileManager: FileManager = .default,
        queue: DispatchQueue = DispatchQueue(label: "com.clipmind.app.autosave"),
        store: EncryptedStore? = nil
    )
    {
        self.settingsStore = settingsStore
        self.sensitiveDetector = sensitiveDetector
        self.pasteboard = pasteboard
        self.fileManager = fileManager
        self.queue = queue
        self.store = store
    }

    /// 异步触发自动保存。生产环境入口。
    ///
    /// 调用方立即返回，自动保存在串行队列上异步执行，与 F1.x 入库流程互不阻塞。
    /// - Parameters:
    ///   - content: 剪贴板内容
    ///   - bundleId: 来源 App Bundle ID
    ///   - appName: 来源 App 名称
    public func handle(content: ClipContent, bundleId: String, appName: String)
    {
        queue.async { [weak self] in
            self?.performAutoSave(content: content, bundleId: bundleId, appName: appName)
        }
    }

    /// 同步执行自动保存。仅供单元测试调用。
    ///
    /// - Returns: 自动保存结果
    internal func performAutoSave(
        content: ClipContent,
        bundleId: String,
        appName: String
    ) -> Outcome
    {
        let settings = settingsStore.current

        // 总开关检查（FR-001）
        guard settings.isEnabled else
        {
            logger.info("auto-save disabled, skip bundleId=\(bundleId, privacy: .public)")
            return .skipped(reason: "disabled")
        }

        // 仅处理文本内容（图片与文件路径不触发自动保存）
        guard case .text(let text) = content else
        {
            logger.info("non-text content, skip")
            return .skipped(reason: "non-text")
        }

        // 白名单检查（FR-002）
        guard settings.whitelistBundleIds.contains(bundleId) else
        {
            logger.info("bundleId not in whitelist, skip bundleId=\(bundleId, privacy: .public)")
            return .skipped(reason: "not-in-whitelist")
        }

        // 长度检查（FR-003）
        guard text.count >= settings.lengthThreshold else
        {
            logger.info("content length below threshold, skip length=\(text.count)")
            return .skipped(reason: "below-threshold")
        }

        // 敏感检查（FR-004，受敏感过滤开关控制，复用 F1.x SensitiveDetector）
        if settings.sensitiveFilterEnabled && sensitiveDetector.detect(text)
        {
            logger.info("sensitive content detected, skip")
            return .skipped(reason: "sensitive")
        }

        // 准备保存目录（FR-005、FR-011）
        let directory: URL
        do
        {
            directory = try prepareSaveDirectory(settings.saveDirectory)
        }
        catch
        {
            logger.error("directory preparation failed error=\(error.localizedDescription, privacy: .public)")
            NotificationCenter.default.post(name: Self.didFailNotification, object: nil)
            return .writeFailed(reason: "directory-error")
        }

        // 生成文件名并解决冲突（FR-006、FR-007）
        let candidateName = FileNameGenerator.generate(
            from: text,
            length: settings.fileNameLength,
            fileFormat: settings.fileFormat
        )
        let finalName = FileNameConflictResolver.resolve(
            candidateName: candidateName,
            in: directory,
            fileManager: fileManager
        )
        let fileURL = directory.appendingPathComponent(finalName)

        // 写入文件（FR-005，原子写入）
        do
        {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            logger.info("file written filename=\(finalName, privacy: .public)")
        }
        catch
        {
            logger.error("file write failed error=\(error.localizedDescription, privacy: .public)")
            NotificationCenter.default.post(name: Self.didFailNotification, object: nil)
            return .writeFailed(reason: "write-error")
        }

        // 格式化路径（FR-013）
        let formattedPath = FilePathFormatter.format(fileURL.path, as: settings.pathFormat)

        // 替换剪贴板（FR-008，在主线程执行避免 AppKit 警告）
        let replaceSuccess = replaceClipboard(with: formattedPath)
        if !replaceSuccess
        {
            logger.error("clipboard replace failed")
            NotificationCenter.default.post(name: Self.didFailNotification, object: nil)
            return .replaceFailed(reason: "clipboard-write-error")
        }
        logger.info("clipboard replaced with file path")

        // AC-13 验证：如果注入了 store，调用 store.save 模拟 F1.x 入库
        // 入库失败不影响已完成的文件写入（FR-014 互不阻塞）
        if let store = store
        {
            do
            {
                let item = ClipItem.makeText(
                    text,
                    contentType: .other,
                    sourceApp: bundleId,
                    sourceAppName: appName
                )
                try store.save(item)
            }
            catch
            {
                logger.warning("store save failed but file already written: \(error.localizedDescription, privacy: .public)")
            }
        }

        return .completed(filePath: fileURL.path, clipboardContent: formattedPath)
    }

    /// 展开路径中的 ~ 并返回目录 URL。
    private func prepareSaveDirectory(_ path: String) throws -> URL
    {
        let expanded = path.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "~", with: NSHomeDirectory())
        let url = URL(fileURLWithPath: expanded)
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// 替换剪贴板内容。必须在主线程调用。
    private func replaceClipboard(with string: String) -> Bool
    {
        let performReplace: () -> Bool = { [pasteboard] in
            pasteboard.clearContents()
            return pasteboard.setString(string, forType: .string)
        }
        if Thread.isMainThread
        {
            return performReplace()
        }
        else
        {
            return DispatchQueue.main.sync(execute: performReplace)
        }
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/AutoSaveServiceTests'
```

预期：PASS，2 个测试用例（`testWriteSuccessWhenDirectoryWritable`、`testSkipNonTextContent`）通过。

- [ ] **步骤 5：Commit**

```bash
swiftlint lint --strict
git add ClipMind/AutoSave/AutoSaveService.swift ClipMindTests/AutoSave/AutoSaveServiceTests.swift
git commit -m "feat(F2.1): 实现 AutoSaveService 主服务核心逻辑"
```

---

### 任务 7：AutoSaveService 跳过路径测试

**文件：**
- 修改：`ClipMindTests/AutoSave/AutoSaveServiceTests.swift`（追加 4 个测试方法）

**目标：** 验证 4 种跳过场景：总开关关闭、白名单不匹配、长度不足、命中敏感。

**对应单元测试：** TC-UT-25（总开关）、TC-UT-26（白名单）、TC-UT-27（长度）、TC-UT-28（敏感）、TC-UT-24（待触发→检查中）、TC-UT-33（替换中→已完成）

**对应 AC：** AC-02（非白名单 App）、AC-03（短内容）、AC-06（敏感内容默认不保存）

- [ ] **步骤 1：编写失败的测试**

在 `ClipMindTests/AutoSave/AutoSaveServiceTests.swift` 末尾（`class` 闭合大括号之前）追加：

```swift
    // MARK: - TC-UT-25: 跳过（总开关关闭）

    func testSkipWhenDisabled() throws
    {
        var settings = AutoSaveSettings()
        settings.isEnabled = false
        settings.saveDirectory = saveDirectoryURL.path
        settings.whitelistBundleIds = ["com.apple.Safari"]
        settings.lengthThreshold = 10
        settingsStore.update(settings)

        let outcome = service.performAutoSave(
            content: .text("hello world long content"),
            bundleId: "com.apple.Safari",
            appName: "Safari"
        )

        if case .skipped(let reason) = outcome
        {
            XCTAssertEqual(reason, "disabled")
        }
        else
        {
            XCTFail("应跳过，实际: \(outcome)")
        }
        // 验证未写入文件
        let files = (try? FileManager.default.contentsOfDirectory(
            at: saveDirectoryURL,
            includingPropertiesForKeys: nil
        )) ?? []
        XCTAssertTrue(files.isEmpty, "总开关关闭不应写入文件")
    }

    // MARK: - TC-UT-26 + AC-02: 跳过（白名单不匹配）

    func testSkipWhenNotInWhitelist() throws
    {
        var settings = AutoSaveSettings()
        settings.isEnabled = true
        settings.saveDirectory = saveDirectoryURL.path
        settings.whitelistBundleIds = ["com.apple.Safari"]
        settings.lengthThreshold = 10
        settings.sensitiveFilterEnabled = false
        settingsStore.update(settings)

        let outcome = service.performAutoSave(
            content: .text("hello world long content"),
            bundleId: "com.apple.Notes",
            appName: "Notes"
        )

        if case .skipped(let reason) = outcome
        {
            XCTAssertEqual(reason, "not-in-whitelist")
        }
        else
        {
            XCTFail("应跳过")
        }
    }

    // MARK: - TC-UT-27 + AC-03: 跳过（长度不足）

    func testSkipWhenBelowThreshold() throws
    {
        var settings = AutoSaveSettings()
        settings.isEnabled = true
        settings.saveDirectory = saveDirectoryURL.path
        settings.whitelistBundleIds = ["com.apple.Safari"]
        settings.lengthThreshold = 50
        settings.sensitiveFilterEnabled = false
        settingsStore.update(settings)

        let outcome = service.performAutoSave(
            content: .text("short"),
            bundleId: "com.apple.Safari",
            appName: "Safari"
        )

        if case .skipped(let reason) = outcome
        {
            XCTAssertEqual(reason, "below-threshold")
        }
        else
        {
            XCTFail("应跳过")
        }
    }

    // MARK: - TC-UT-28 + AC-06: 跳过（命中敏感）

    func testSkipWhenSensitiveDetected() throws
    {
        var settings = AutoSaveSettings()
        settings.isEnabled = true
        settings.saveDirectory = saveDirectoryURL.path
        settings.whitelistBundleIds = ["com.apple.Safari"]
        settings.lengthThreshold = 10
        settings.sensitiveFilterEnabled = true
        settingsStore.update(settings)

        // sk- + 32 位非空白字符触发 F1.x Token 模式
        let sensitiveContent = "sk-abcdefghijklmnopqrstuvwxyz123456 extra padding"
        let outcome = service.performAutoSave(
            content: .text(sensitiveContent),
            bundleId: "com.apple.Safari",
            appName: "Safari"
        )

        if case .skipped(let reason) = outcome
        {
            XCTAssertEqual(reason, "sensitive")
        }
        else
        {
            XCTFail("应跳过")
        }
    }
```

- [ ] **步骤 2：运行测试验证通过**

注：步骤 1 中追加的测试方法依赖任务 6 已实现的 `AutoSaveService.performAutoSave` 与 `Outcome` 枚举，因此直接运行应通过（验证实现与测试一致）。

```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/AutoSaveServiceTests'
```

预期：PASS，6 个测试用例全部通过（原 2 个 + 新增 4 个）。

- [ ] **步骤 3：修复实现（若失败）**

若 `testSkipWhenSensitiveDetected` 失败（如 `outcome` 为 `.skipped("non-text")` 或 `.completed`），检查：
- `sensitiveDetector.detect(text)` 是否在 `SensitiveDetector.init(defaults:)` 默认状态下返回 `true`（依赖 F1.x 默认 `sensitiveDetectionEnabled=true`）
- `settingsStore` 与 `sensitiveDetector` 是否共用同一 `defaults` 实例（`setUpWithError` 中已注入）

修复方式：在 `setUpWithError` 中显式设置 `defaults.set(true, forKey: "sensitiveDetectionEnabled")`（如有必要）。

- [ ] **步骤 4：运行全部测试再次验证**

```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/AutoSaveServiceTests'
```

预期：PASS，6 个测试用例全部通过。

- [ ] **步骤 5：Commit**

```bash
swiftlint lint --strict
git add ClipMindTests/AutoSave/AutoSaveServiceTests.swift
git commit -m "test(F2.1): 添加 AutoSaveService 跳过路径单元测试"
```

---

### 任务 8：AutoSaveService 异常路径测试

**文件：**
- 修改：`ClipMindTests/AutoSave/AutoSaveServiceTests.swift`（追加 2 个测试方法）

**目标：** 验证目录异常与无写权限场景下，AutoSaveService 返回 `.writeFailed`，不抛出致命异常，不替换剪贴板。

**对应 FR：** FR-011（保存目录异常处理）

**对应 AC：** AC-09（保存目录异常时不崩溃）、AC-12（自动保存失败不影响 F1.x 入库）

**对应单元测试：** TC-UT-18（目录不存在）、TC-UT-19（无写权限）、TC-UT-30（写入中→写入失败）

- [ ] **步骤 1：编写失败的测试**

在 `ClipMindTests/AutoSave/AutoSaveServiceTests.swift` 末尾（`class` 闭合大括号之前）追加：

```swift
    // MARK: - TC-UT-18 + AC-09 + AC-12: 目录不存在 → 返回错误，不抛致命异常

    func testWriteFailedWhenDirectoryNotCreatable() throws
    {
        var settings = AutoSaveSettings()
        settings.isEnabled = true
        // /proc 在 macOS 上不存在，路径无法创建
        settings.saveDirectory = "/proc/nonexistent/permission-denied/Clips/"
        settings.whitelistBundleIds = ["com.apple.Safari"]
        settings.lengthThreshold = 10
        settings.sensitiveFilterEnabled = false
        settingsStore.update(settings)

        // 不应抛出异常
        let outcome = service.performAutoSave(
            content: .text("hello world long content"),
            bundleId: "com.apple.Safari",
            appName: "Safari"
        )

        if case .writeFailed(let reason) = outcome
        {
            XCTAssertEqual(reason, "directory-error")
        }
        else
        {
            XCTFail("应返回写入失败，实际: \(outcome)")
        }
        // 验证剪贴板未被替换
        XCTAssertNil(pasteboard.string(forType: .string), "AC-12: 写入失败不应替换剪贴板")
    }

    // MARK: - TC-UT-19: 无写权限 → 返回错误

    func testWriteFailedWhenReadOnlyDirectory() throws
    {
        let readOnlyDir = tempDir.appendingPathComponent("readonly", isDirectory: true)
        try FileManager.default.createDirectory(
            at: readOnlyDir,
            withIntermediateDirectories: true
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o444],
            ofItemAtPath: readOnlyDir.path
        )
        defer
        {
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: readOnlyDir.path
            )
        }

        var settings = AutoSaveSettings()
        settings.isEnabled = true
        settings.saveDirectory = readOnlyDir.appendingPathComponent("subdir").path
        settings.whitelistBundleIds = ["com.apple.Safari"]
        settings.lengthThreshold = 10
        settings.sensitiveFilterEnabled = false
        settingsStore.update(settings)

        let outcome = service.performAutoSave(
            content: .text("hello world long content"),
            bundleId: "com.apple.Safari",
            appName: "Safari"
        )

        if case .writeFailed = outcome
        {
            // 期望写入失败（目录创建失败或文件写入失败）
        }
        else
        {
            XCTFail("应返回写入失败，实际: \(outcome)")
        }
    }
```

- [ ] **步骤 2：运行测试验证通过**

```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/AutoSaveServiceTests'
```

预期：PASS，8 个测试用例全部通过。

- [ ] **步骤 3：修复实现（若失败）**

若 `testWriteFailedWhenDirectoryNotCreatable` 返回了 `.completed` 而非 `.writeFailed`，检查 `prepareSaveDirectory` 是否对 `createDirectory(at:, withIntermediateDirectories: true)` 抛出错误。在 macOS 上 `/proc/` 路径根目录就不存在，`createDirectory` 会抛出 `NSFileNoSuchFileError`，应被 `do-catch` 捕获并返回 `.writeFailed(reason: "directory-error")`。

若 `testWriteFailedWhenReadOnlyDirectory` 未按预期失败（如 macOS 上以 root 权限运行测试时仍可写入只读目录），可改用 `settings.saveDirectory = "/dev/null/Clips/"` 验证不可写场景。

- [ ] **步骤 4：运行全部测试再次验证**

```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/AutoSaveServiceTests'
```

预期：PASS，8 个测试用例全部通过。

- [ ] **步骤 5：Commit**

```bash
swiftlint lint --strict
git add ClipMindTests/AutoSave/AutoSaveServiceTests.swift
git commit -m "test(F2.1): 添加 AutoSaveService 异常路径单元测试"
```

---

### 任务 9：AutoSaveService 集成测试（敏感过滤、路径格式、冲突、AC-13、AC-14）

**文件：**
- 修改：`ClipMindTests/AutoSave/AutoSaveServiceTests.swift`（追加 4 个测试方法）

**目标：** 验证 AC-06（敏感默认不保存）、AC-14（关闭敏感过滤后保存）、AC-11（路径格式切换）、AC-04（文件名冲突）、AC-13（入库失败不影响文件写入）。完成本任务后 Phase 0 全部单元测试通过。

**对应 AC：** AC-04、AC-06、AC-11、AC-13、AC-14

**对应单元测试：** TC-AC04、TC-AC06、TC-AC11、TC-AC13、TC-AC14

- [ ] **步骤 1：编写失败的测试**

在 `ClipMindTests/AutoSave/AutoSaveServiceTests.swift` 末尾（`class` 闭合大括号之前）追加：

```swift
    // MARK: - TC-AC06: 敏感内容默认不保存到文件

    func testAC06SensitiveContentNotSaved() throws
    {
        var settings = AutoSaveSettings()
        settings.isEnabled = true
        settings.saveDirectory = saveDirectoryURL.path
        settings.whitelistBundleIds = ["com.apple.Safari"]
        settings.lengthThreshold = 10
        settings.sensitiveFilterEnabled = true
        settingsStore.update(settings)

        let token = "sk-abcdefghijklmnopqrstuvwxyz123456 padding"
        let outcome = service.performAutoSave(
            content: .text(token),
            bundleId: "com.apple.Safari",
            appName: "Safari"
        )

        if case .skipped(let reason) = outcome
        {
            XCTAssertEqual(reason, "sensitive")
        }
        else
        {
            XCTFail("AC-06: 敏感内容应跳过，实际: \(outcome)")
        }
        let files = (try? FileManager.default.contentsOfDirectory(
            at: saveDirectoryURL,
            includingPropertiesForKeys: nil
        )) ?? []
        XCTAssertTrue(files.isEmpty, "AC-06: 不应写入文件")
    }

    // MARK: - TC-AC14: 关闭敏感过滤后敏感内容可保存到文件

    func testAC14SensitiveContentSavedWhenFilterDisabled() throws
    {
        var settings = AutoSaveSettings()
        settings.isEnabled = true
        settings.saveDirectory = saveDirectoryURL.path
        settings.whitelistBundleIds = ["com.apple.Safari"]
        settings.lengthThreshold = 10
        settings.sensitiveFilterEnabled = false
        settingsStore.update(settings)

        let token = "sk-abcdefghijklmnopqrstuvwxyz123456 padding"
        let outcome = service.performAutoSave(
            content: .text(token),
            bundleId: "com.apple.Safari",
            appName: "Safari"
        )

        if case .completed(let filePath, _) = outcome
        {
            XCTAssertTrue(FileManager.default.fileExists(atPath: filePath))
            let content = try String(contentsOfFile: filePath, encoding: .utf8)
            XCTAssertTrue(
                content.contains("sk-abcdefghijklmnopqrstuvwxyz123456"),
                "AC-14: 文件应包含敏感内容"
            )
        }
        else
        {
            XCTFail("AC-14: 关闭敏感过滤后应保存，实际: \(outcome)")
        }
    }

    // MARK: - TC-AC11: 路径格式可在三种格式间切换

    func testAC11ClipboardContentMatchesPathFormat() throws
    {
        var settings = AutoSaveSettings()
        settings.isEnabled = true
        settings.saveDirectory = saveDirectoryURL.path
        settings.whitelistBundleIds = ["com.apple.Safari"]
        settings.lengthThreshold = 10
        settings.sensitiveFilterEnabled = false
        settings.pathFormat = .plainPath
        settingsStore.update(settings)

        // 纯路径
        _ = service.performAutoSave(
            content: .text("plain path content test"),
            bundleId: "com.apple.Safari",
            appName: "Safari"
        )
        let plainClipboard = pasteboard.string(forType: .string)
        XCTAssertTrue(
            plainClipboard?.hasPrefix(saveDirectoryURL.path) == true,
            "AC-11: 纯路径应以保存目录开头"
        )

        // file:// URI
        pasteboard.clearContents()
        settings.pathFormat = .fileURI
        settingsStore.update(settings)
        _ = service.performAutoSave(
            content: .text("file uri content test"),
            bundleId: "com.apple.Safari",
            appName: "Safari"
        )
        let uriClipboard = pasteboard.string(forType: .string)
        XCTAssertTrue(
            uriClipboard?.hasPrefix("file://") == true,
            "AC-11: file:// URI 应以 file:// 开头"
        )

        // Markdown 链接
        pasteboard.clearContents()
        settings.pathFormat = .markdownLink
        settingsStore.update(settings)
        _ = service.performAutoSave(
            content: .text("markdown link content test"),
            bundleId: "com.apple.Safari",
            appName: "Safari"
        )
        let mdClipboard = pasteboard.string(forType: .string)
        XCTAssertTrue(
            mdClipboard?.hasPrefix("[") == true,
            "AC-11: Markdown 链接应以 [ 开头"
        )
        XCTAssertTrue(
            mdClipboard?.contains("](file://") == true,
            "AC-11: Markdown 链接应包含 ](file://"
        )
    }

    // MARK: - TC-AC04: 文件名冲突自动追加序号（集成）

    func testAC04ConflictResolutionIntegrated() throws
    {
        var settings = AutoSaveSettings()
        settings.isEnabled = true
        settings.saveDirectory = saveDirectoryURL.path
        settings.whitelistBundleIds = ["com.apple.Safari"]
        settings.lengthThreshold = 10
        settings.sensitiveFilterEnabled = false
        settings.fileNameLength = 20
        settings.fileFormat = .markdown
        settingsStore.update(settings)

        // 第一次：写入 content.md
        _ = service.performAutoSave(
            content: .text("content longer than threshold here"),
            bundleId: "com.apple.Safari",
            appName: "Safari"
        )
        // 第二次：同前缀，应追加 -1
        _ = service.performAutoSave(
            content: .text("content longer than threshold here again"),
            bundleId: "com.apple.Safari",
            appName: "Safari"
        )

        let files = (try? FileManager.default.contentsOfDirectory(
            at: saveDirectoryURL,
            includingPropertiesForKeys: nil
        )) ?? []
        let fileNames = files.map { $0.lastPathComponent }.sorted()
        XCTAssertTrue(
            fileNames.contains("content.md"),
            "AC-04: 应存在 content.md"
        )
        XCTAssertTrue(
            fileNames.contains(where: { $0.hasPrefix("content-") && $0.hasSuffix(".md") }),
            "AC-04: 应存在 content-N.md"
        )
    }

    // MARK: - TC-AC13: F1.x 入库失败不影响已完成的文件写入

    func testAC13FileWrittenWhenStoreSaveThrows() throws
    {
        // 构造一个损坏的 EncryptedStore：先创建有效 store 写入一条数据，
        // 再覆盖 dbPath 文件内容为无效数据，使后续 save 抛异常
        let corruptedDBPath = tempDir.appendingPathComponent("corrupted-\(UUID().uuidString).db")
        let key = SymmetricKey(size: .bits256)
        let validStore = try EncryptedStore(dbPath: corruptedDBPath, key: key)
        let initItem = ClipItem.makeText(
            "init",
            contentType: .other,
            sourceApp: "test",
            sourceAppName: "Test"
        )
        try validStore.save(initItem)
        // 覆盖 dbPath 文件内容为无效数据，使后续 save 抛异常
        try "invalid database content".write(
            to: corruptedDBPath,
            atomically: true,
            encoding: .utf8
        )
        // 重新构造 store（指向已损坏的 dbPath，后续 save 将抛异常）
        let corruptedStore = try EncryptedStore(dbPath: corruptedDBPath, key: key)

        // 注入到 AutoSaveService（store 参数非 nil，触发 AC-13 验证路径）
        service = AutoSaveService(
            settingsStore: settingsStore,
            sensitiveDetector: sensitiveDetector,
            pasteboard: pasteboard,
            fileManager: .default,
            store: corruptedStore
        )

        var settings = AutoSaveSettings()
        settings.isEnabled = true
        settings.saveDirectory = saveDirectoryURL.path
        settings.whitelistBundleIds = ["com.apple.Safari"]
        settings.lengthThreshold = 10
        settings.sensitiveFilterEnabled = false
        settingsStore.update(settings)

        let outcome = service.performAutoSave(
            content: .text("hello world long content for AC-13"),
            bundleId: "com.apple.Safari",
            appName: "Safari"
        )

        if case .completed(let filePath, _) = outcome
        {
            XCTAssertTrue(
                FileManager.default.fileExists(atPath: filePath),
                "AC-13: store.save 抛异常时文件仍应已写入"
            )
        }
        else
        {
            XCTFail("AC-13: 应完成（store.save 异常不影响文件写入），实际: \(outcome)")
        }
    }
```

- [ ] **步骤 2：运行测试验证通过**

```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/AutoSaveServiceTests'
```

预期：PASS，12 个测试用例全部通过。

- [ ] **步骤 3：修复实现（若失败）**

若 `testAC14SensitiveContentSavedWhenFilterDisabled` 失败：检查 `sensitiveDetector` 是否被传入 `defaults`（与 `settingsStore` 共用）。`SensitiveDetector` 通过 `defaults.bool(forKey: "sensitiveDetectionEnabled")` 读取开关，默认 `true`。但 `AutoSaveService.performAutoSave` 中的判断是 `if settings.sensitiveFilterEnabled && sensitiveDetector.detect(text)`，其中 `settings.sensitiveFilterEnabled` 是 F2.1 自己的开关（默认 `true`），与 F1.x `sensitiveDetectionEnabled` 不同。在 `testAC14SensitiveContentSavedWhenFilterDisabled` 中我们设置 `settings.sensitiveFilterEnabled = false`，应直接跳过 `sensitiveDetector.detect` 调用，返回 `.completed`。

如果失败原因不是上述：检查 `sensitiveDetector` 是否复用了 `defaults`，且 `defaults` 中 `sensitiveDetectionEnabled` 是否被设置为 `true`（在 `setUpWithError` 中可能未显式设置，但 `SensitiveDetector` 默认行为已正确）。

- [ ] **步骤 4：运行全部测试再次验证**

```bash
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/AutoSaveServiceTests'
```

预期：PASS，14 个测试用例全部通过。

- [ ] **步骤 5：Commit**

```bash
swiftlint lint --strict
git add ClipMindTests/AutoSave/AutoSaveServiceTests.swift
git commit -m "test(F2.1): 添加 AutoSaveService 集成测试覆盖 AC-04/06/11/13/14"
```

---

## 4. Phase 0 验收

### 4.1 文件存在性

```bash
ls -la ClipMind/AutoSave/
ls -la ClipMindTests/AutoSave/
```

预期：
- `ClipMind/AutoSave/` 含 5 个 `.swift` 文件：`AutoSaveSettings.swift`、`AutoSaveSettingsStore.swift`、`FileNameGenerator.swift`、`FilePathFormatter.swift`、`AutoSaveService.swift`
- `ClipMindTests/AutoSave/` 含 6 个 `.swift` 文件：`AutoSaveSettingsTests.swift`、`AutoSaveSettingsStoreTests.swift`、`FileNameGeneratorTests.swift`、`FileNameConflictResolverTests.swift`、`FilePathFormatterTests.swift`、`AutoSaveServiceTests.swift`

### 4.2 SwiftLint 通过

```bash
swiftlint lint --strict
```

预期：无违规，退出码 0。

### 4.3 编译通过

```bash
xcodebuild build \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

预期：BUILD SUCCEEDED。

### 4.4 单元测试通过（单文件快速反馈）

依次运行 6 个测试类：

```bash
for testClass in AutoSaveSettingsTests AutoSaveSettingsStoreTests FileNameGeneratorTests FileNameConflictResolverTests FilePathFormatterTests AutoSaveServiceTests; do
  echo "=== Running $testClass ==="
  xcodebuild test \
    -project ClipMind.xcodeproj \
    -scheme ClipMind \
    -destination 'platform=macOS' \
    -configuration Debug \
    ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
    CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
    -only-testing:"ClipMindTests/$testClass"
done
```

预期：所有测试类全部 PASS。累计通过测试用例数：
- `AutoSaveSettingsTests`：5 个
- `AutoSaveSettingsStoreTests`：8 个
- `FileNameGeneratorTests`：8 个
- `FileNameConflictResolverTests`：4 个
- `FilePathFormatterTests`：4 个
- `AutoSaveServiceTests`：14 个（含 v1.1 新增 testAutoSaveServicePostsNotificationOnFailure + testAC13FileWrittenWhenStoreSaveThrows）
- 合计：43 个测试用例（覆盖 33 个 TC-UT + 10 个 AC 驱动的集成测试，含 v1.1 新增 AC-09 通知测试 + AC-13 入库失败测试）

### 4.5 CI 全量回归（push 后自动）

push 后 GitHub Actions 自动执行：
1. `xcodegen generate`
2. `swiftlint lint --strict`
3. `xcodebuild build`
4. `xcodebuild test`（含 Phase 0 全部单元测试 + F1.x 既有测试）

预期：CI 通过，无既有测试被破坏（F-08 约束）。

### 4.6 规格覆盖度

| 测试用例 | 覆盖状态 | 任务 |
|---------|---------|------|
| TC-UT-01~02（白名单匹配） | ✅ 通过 `testSkipWhenNotInWhitelist`、`testWriteSuccessWhenDirectoryWritable` 间接覆盖 | 6、7 |
| TC-UT-03~04（长度阈值） | ✅ 通过 `testSkipWhenBelowThreshold`、`testWriteSuccessWhenDirectoryWritable` 覆盖 | 6、7 |
| TC-UT-05~07（敏感检查器） | ✅ 通过 `testSkipWhenSensitiveDetected`、`testAC14SensitiveContentSavedWhenFilterDisabled` 覆盖 | 7、9 |
| TC-UT-08~10（文件名生成器） | ✅ 任务 3 | 3 |
| TC-UT-11~13（冲突处理器） | ✅ 任务 4 | 4 |
| TC-UT-14~16（路径格式化器） | ✅ 任务 5 | 5 |
| TC-UT-17（目录可写） | ✅ 任务 6 | 6 |
| TC-UT-18（目录不存在） | ✅ 任务 8 | 8 |
| TC-UT-19（无写权限） | ✅ 任务 8 | 8 |
| TC-UT-20（长度阈值超范围） | ✅ 任务 2 | 2 |
| TC-UT-21（文件名长度超范围） | ✅ 任务 2 | 2 |
| TC-UT-22（白名单去重） | ✅ 任务 2 | 2 |
| TC-UT-23（配置变更通知） | ✅ 任务 2 | 2 |
| TC-UT-24（待触发→检查中） | ✅ 任务 6（每次 `performAutoSave` 调用即触发状态转换） | 6 |
| TC-UT-25（总开关关闭） | ✅ 任务 7 | 7 |
| TC-UT-26（白名单不匹配） | ✅ 任务 7 | 7 |
| TC-UT-27（长度不足） | ✅ 任务 7 | 7 |
| TC-UT-28（命中敏感） | ✅ 任务 7 | 7 |
| TC-UT-29（检查中→待写入） | ✅ 任务 6（主路径覆盖） | 6 |
| TC-UT-30（写入中→写入失败） | ✅ 任务 8 | 8 |
| TC-UT-31（写入中→待替换） | ✅ 任务 6（主路径覆盖） | 6 |
| TC-UT-32（替换中→替换失败） | 🟡 部分覆盖（NSPasteboard.setString 实际上不会失败，难以模拟；通过 `replaceFailed` 枚举分支保留可测试入口） | 6 |
| TC-UT-33（替换中→已完成） | ✅ 任务 6、9（每次成功写入即到达） | 6、9 |
| TC-AC04 | ✅ 任务 9 | 9 |
| TC-AC06 | ✅ 任务 9 | 9 |
| TC-AC10 | ✅ 任务 3 | 3 |
| TC-AC11 | ✅ 任务 9 | 9 |
| TC-AC12 | ✅ 任务 8 | 8 |
| TC-AC13 | ✅ 任务 9（`testAC13FileWrittenWhenStoreSaveThrows` 通过注入损坏 store 验证入库失败不影响文件写入） | 9 |
| TC-AC14 | ✅ 任务 9 | 9 |

---

## 版本记录

| 版本 | 日期 | 变更说明 |
|------|------|---------|
| v1.0 | 2026-07-21 | 初始版本，writing-plans skill 产出，覆盖 Phase 0 共 9 个任务，含 33 个单元测试 + 8 个 AC 集成测试 |
| v1.1 | 2026-07-21 | 修复 check-plan 发现的问题 1/5：AutoSaveService 新增 `.autoSaveDidFail` 通知（失败时发送，供 AppDelegate 监听弹窗）；`init` 增加 `store: EncryptedStore? = nil` 参数（生产 nil，测试注入损坏 store 验证 AC-13）；任务 6 新增 `testAutoSaveServicePostsNotificationOnFailure`；任务 9 新增 `testAC13FileWrittenWhenStoreSaveThrows`；覆盖度表 TC-AC13 状态更新为任务 9 |
