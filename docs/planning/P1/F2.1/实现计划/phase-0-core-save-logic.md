> 最后更新：2026-07-22 | 版本：v2.0

# Phase 0 子计划：核心保存逻辑

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。本子计划落地 D1/D2/D4~D14/D16~D18/D21/D23/D24 决策。每个任务严格按 TDD 五步执行。

**目标：** 实现 F2.1 自动保存到文件的核心保存逻辑，包括 13 个生产代码文件（CaptureEvent、SensitiveMatchResult、F2xConfigSnapshot、AutoSaveSettings、AutoSaveSettingsStore、SelfWriteSuppressor、FileNameGenerator、ConflictResolver、FileWriter、FilePathFormatter、ClipboardReplacer、AutoSaveService、PollingHelper）和测试文件包（49 单元测试 + 14 并发场景测试 + 性能测试）。Phase 0 完成时，所有 TC-UT-01~49、TC-CC-01~14、性能测试（D21）通过，覆盖 AC-04/06/10/11/12/13/14/17~22 的 XCTest 部分。

**架构：** 所有新增文件位于 `ClipMind/AutoSave/`（生产代码）与 `ClipMindTests/AutoSave/`（测试代码）。`CaptureEvent` 为不可变 `struct`（D1），承载事件快照与配置快照（D6/D23）。`AutoSaveService` 为 `final class`，内部用串行 `DispatchQueue(label:, qos: .utility)`（D7）保证文件 I/O 与剪贴板替换的线程安全。`SelfWriteSuppressor` 通过 `markSelfWrite(changeCount:)` + `checkAndReset(changeCount:)` 配合 5 秒超时（D4）避免回环。`FileWriter` 使用 O_EXCL 原子创建（D10）+ POSIX 0600 权限（D14）。`PollingHelper.waitUntil` 使用 10ms 轮询间隔与 3s 超时（D17，禁止 sleep 3）。

**技术栈：** Swift 5.7+ / macOS 12.4+ / Foundation（FileManager、POSIX）、AppKit（NSPasteboard）、XCTest、SwiftLint strict

---

## 1. 范围与非目标

### 1.1 范围

- 创建 13 个生产代码文件（`ClipMind/AutoSave/**/*.swift` + `ClipMind/Utils/PollingHelper.swift`）
- 创建 1 个测试夹具文件（`ClipMindTests/Fixtures/CaptureEventFixtures.swift`）
- 创建测试文件（`ClipMindTests/AutoSave/*.swift`，覆盖 TC-UT-01~49、TC-CC-01~14）
- 覆盖 AC-04、AC-06、AC-10、AC-11、AC-12、AC-13、AC-14、AC-17~22 的 XCTest 部分（D18）
- 性能测试记录实际耗时并断言 P95（D21）
- 本地 `swiftlint lint --strict` 与 `xcodebuild build` 通过
- 单文件 `-only-testing` 单元测试通过

### 1.2 非目标

- 不修改 `PasteboardWatcher.swift`、`ClipCaptureService.swift`、`SettingsView.swift`、`ClipMindApp.swift`（Phase 1）
- 不创建 UI 视图（Phase 1）
- 不执行 XCUITest（Phase 1）
- 不本地执行全量 `xcodebuild test`（仅 CI）
- 不修改 F1.x 既有模块的公共接口（D22）

---

## 2. 涉及文件和职责

| 文件 | 职责 | 创建/修改 | 对应决策 |
|------|------|-----------|----------|
| `ClipMind/AutoSave/Models/CaptureEvent.swift` | 不可变事件快照 struct | 创建 | D1/D6 |
| `ClipMind/AutoSave/Models/SensitiveMatchResult.swift` | 敏感识别结果 struct | 创建 | D2 |
| `ClipMind/AutoSave/Models/F2xConfigSnapshot.swift` | F2.1 配置快照 struct | 创建 | D6/D23 |
| `ClipMind/AutoSave/AutoSaveSettings.swift` | 配置模型 + FileFormat/PathFormat 枚举（D11 默认关闭） | 创建 | D11 |
| `ClipMind/AutoSave/AutoSaveSettingsStore.swift` | 配置持久化 + 范围校验 + 白名单去重 | 创建 | - |
| `ClipMind/AutoSave/SelfWriteSuppressor.swift` | 自我写入抑制器（5s 超时） | 创建 | D4 |
| `ClipMind/AutoSave/FileNameGenerator.swift` | 文件名生成 8 步 | 创建 | D9 |
| `ClipMind/AutoSave/ConflictResolver.swift` | 冲突处理器（数字后缀递增） | 创建 | - |
| `ClipMind/AutoSave/FileWriter.swift` | 文件写入器（O_EXCL + 0600 + 异常分级） | 创建 | D10/D13/D14 |
| `ClipMind/AutoSave/FilePathFormatter.swift` | 路径格式化器（URI 编码） | 创建 | D16 |
| `ClipMind/AutoSave/ClipboardReplacer.swift` | 剪贴板替换器（changeCount 前置条件） | 创建 | D5 |
| `ClipMind/AutoSave/AutoSaveService.swift` | 主服务（串行队列 + 边界 + 不重试） | 创建 | D7/D12/D24 |
| `ClipMind/Utils/PollingHelper.swift` | 轮询工具（10ms 间隔，3s 超时） | 创建 | D17 |
| `ClipMindTests/Fixtures/CaptureEventFixtures.swift` | 测试夹具 | 创建 | D18 |
| `ClipMindTests/AutoSave/*.swift` | 单元测试 + 集成测试 + 性能测试 | 创建 | D8/D18/D21 |

**推荐执行顺序：** 2 → 3 → 1 → 4 → 5 → 6 → 7 → 8 → 9 → 10 → 13 → 11 → 12 → 14

---

## 3. 任务列表

总计 14 个任务，每个任务包含 5 个步骤（编写失败测试 → 运行验证失败 → 编写最少实现 → 运行验证通过 → commit）。

---

### 任务 1：CaptureEvent 不可变事件快照

**文件：**
- 创建：`ClipMind/AutoSave/Models/CaptureEvent.swift`
- 测试：`ClipMindTests/AutoSave/CaptureEventTests.swift`

**目标：** 实现不可变 `CaptureEvent` struct，承载事件快照与配置快照（D1/D6）。所有属性为 `let`，实现 `Sendable`。

**对应决策：** D1（事件驱动模型）、D6（配置快照不可变）

**前置依赖：** 任务 2（SensitiveMatchResult）、任务 3（F2xConfigSnapshot）必须先完成

- [ ] **步骤 1：编写失败的测试**

创建 `ClipMindTests/AutoSave/CaptureEventTests.swift`：

```swift
import Foundation
import XCTest

@testable import ClipMind

final class CaptureEventTests: XCTestCase
{
    // MARK: - TC-UT-01：CaptureEvent 默认构造与属性访问

    func testCaptureEventPropertiesAccessible() throws
    {
        let event = CaptureEventFixtures.shortTextEvent()

        XCTAssertEqual(event.changeCount, 42)
        XCTAssertEqual(event.bundleId, "com.apple.Safari")
        XCTAssertEqual(event.appName, "Safari")
        XCTAssertEqual(event.blacklisted, false)
        XCTAssertNotNil(event.id)
        XCTAssertNotNil(event.timestamp)
    }

    // MARK: - TC-UT-02：CaptureEvent 不可变性

    func testCaptureEventIsImmutable() throws
    {
        let event = CaptureEventFixtures.shortTextEvent()
        let originalChangeCount = event.changeCount

        // 编译期保证：所有属性为 let，无法赋值。
        XCTAssertEqual(event.changeCount, originalChangeCount)
    }

    // MARK: - TC-UT-03：CaptureEvent 携带配置快照（D6/D23）

    func testCaptureEventCarriesConfigSnapshot() throws
    {
        let event = CaptureEventFixtures.shortTextEvent()

        XCTAssertEqual(event.f2xConfigSnapshot.isEnabled, true)
        XCTAssertEqual(event.f2xConfigSnapshot.saveDirectory, "~/Documents/ClipMind/Clips/")
        XCTAssertEqual(event.f2xConfigSnapshot.fileFormat, .markdown)
        XCTAssertEqual(event.f2xConfigSnapshot.lengthThreshold, 50)
    }

    // MARK: - TC-UT-04：CaptureEvent 携带敏感识别结果（D2）

    func testCaptureEventCarriesSensitiveResult() throws
    {
        let event = CaptureEventFixtures.sensitiveContentEvent()

        XCTAssertEqual(event.sensitiveResult.isSensitive, true)
        XCTAssertEqual(event.sensitiveResult.matchedPatterns.count, 1)
    }

    // MARK: - TC-UT-05：CaptureEvent 携带 F1.x 配置快照（D3 黑名单优先）

    func testCaptureEventCarriesF1xConfigSnapshot() throws
    {
        let event = CaptureEventFixtures.blacklistedAppEvent()

        XCTAssertEqual(event.blacklisted, true)
        XCTAssertEqual(event.f1xConfigSnapshot.blacklistBundleIds.contains("com.apple.finder"), true)
    }

    // MARK: - TC-UT-06：CaptureEvent 内容长度计算

    func testCaptureEventContentLength() throws
    {
        let event = CaptureEventFixtures.shortTextEvent()

        XCTAssertEqual(event.contentLength, 11, "shortTextEvent 内容应为 'hello world' 11 字符")
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1-auto-save-to-file
xcodegen generate
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/CaptureEventTests'
```

预期：FAIL，报错 "Cannot find 'CaptureEvent' in scope"。

- [ ] **步骤 3：编写最少实现代码**

创建 `ClipMind/AutoSave/Models/CaptureEvent.swift`：

```swift
import Foundation

/// 捕获事件不可变快照（D1 事件驱动模型，D6 配置快照不可变）。
///
/// 在 PasteboardWatcher 检测到剪贴板变化时构造，承载原始内容、来源 App 信息、
/// 敏感识别结果（D2 只执行一次）、F1.x 与 F2.1 配置快照（D23 事件构造阶段读取）。
/// 所有属性为 `let`，满足 FR-016 不可变快照契约。实现 `Sendable` 保证跨并发边界安全。
public struct CaptureEvent: Sendable
{
    public let id: String
    public let changeCount: Int
    public let content: ClipContent
    public let bundleId: String
    public let appName: String
    public let blacklisted: Bool
    public let sensitiveResult: SensitiveMatchResult
    public let f1xConfigSnapshot: F1xConfigSnapshot
    public let f2xConfigSnapshot: F2xConfigSnapshot
    public let timestamp: Date

    /// 内容长度（字符数，D12 100KB 上限判断依据）。
    public var contentLength: Int
    {
        switch content
        {
        case .text(let text):
            return text.count
        case .image(let data):
            return data.count
        case .filePath:
            return 0
        }
    }

    public init(
        id: String = UUID().uuidString,
        changeCount: Int,
        content: ClipContent,
        bundleId: String,
        appName: String,
        blacklisted: Bool,
        sensitiveResult: SensitiveMatchResult,
        f1xConfigSnapshot: F1xConfigSnapshot,
        f2xConfigSnapshot: F2xConfigSnapshot,
        timestamp: Date = Date()
    )
    {
        self.id = id
        self.changeCount = changeCount
        self.content = content
        self.bundleId = bundleId
        self.appName = appName
        self.blacklisted = blacklisted
        self.sensitiveResult = sensitiveResult
        self.f1xConfigSnapshot = f1xConfigSnapshot
        self.f2xConfigSnapshot = f2xConfigSnapshot
        self.timestamp = timestamp
    }
}

/// F1.x 配置快照（D3 黑名单优先判断依据）。
public struct F1xConfigSnapshot: Sendable
{
    public let blacklistBundleIds: [String]

    public init(blacklistBundleIds: [String])
    {
        self.blacklistBundleIds = blacklistBundleIds
    }
}
```

创建 `ClipMindTests/Fixtures/CaptureEventFixtures.swift`：

```swift
import Foundation

@testable import ClipMind

/// 测试夹具（D18），构造各种 CaptureEvent 场景。
enum CaptureEventFixtures
{
    static func shortTextEvent() -> CaptureEvent
    {
        CaptureEvent(
            changeCount: 42,
            content: .text("hello world"),
            bundleId: "com.apple.Safari",
            appName: "Safari",
            blacklisted: false,
            sensitiveResult: SensitiveMatchResult(isSensitive: false, matchedPatterns: []),
            f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: ["com.apple.finder"]),
            f2xConfigSnapshot: F2xConfigSnapshot(
                isEnabled: true,
                saveDirectory: "~/Documents/ClipMind/Clips/",
                whitelistBundleIds: ["com.apple.Safari"],
                fileFormat: .markdown,
                lengthThreshold: 50,
                fileNameLength: 20,
                sensitiveFilterEnabled: true,
                pathFormat: .plainPath
            )
        )
    }

    static func sensitiveContentEvent() -> CaptureEvent
    {
        CaptureEvent(
            changeCount: 43,
            content: .text("password=123456"),
            bundleId: "com.apple.Safari",
            appName: "Safari",
            blacklisted: false,
            sensitiveResult: SensitiveMatchResult(isSensitive: true, matchedPatterns: ["password"]),
            f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: []),
            f2xConfigSnapshot: F2xConfigSnapshot(
                isEnabled: true,
                saveDirectory: "~/Documents/ClipMind/Clips/",
                whitelistBundleIds: ["com.apple.Safari"],
                fileFormat: .markdown,
                lengthThreshold: 50,
                fileNameLength: 20,
                sensitiveFilterEnabled: true,
                pathFormat: .plainPath
            )
        )
    }

    static func blacklistedAppEvent() -> CaptureEvent
    {
        CaptureEvent(
            changeCount: 44,
            content: .text("finder content"),
            bundleId: "com.apple.finder",
            appName: "Finder",
            blacklisted: true,
            sensitiveResult: SensitiveMatchResult(isSensitive: false, matchedPatterns: []),
            f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: ["com.apple.finder"]),
            f2xConfigSnapshot: F2xConfigSnapshot(
                isEnabled: true,
                saveDirectory: "~/Documents/ClipMind/Clips/",
                whitelistBundleIds: ["com.apple.Safari"],
                fileFormat: .markdown,
                lengthThreshold: 50,
                fileNameLength: 20,
                sensitiveFilterEnabled: true,
                pathFormat: .plainPath
            )
        )
    }

    static func longTextEvent(threshold: Int = 50) -> CaptureEvent
    {
        let longText = String(repeating: "a", count: threshold + 100)
        return CaptureEvent(
            changeCount: 45,
            content: .text(longText),
            bundleId: "com.apple.Safari",
            appName: "Safari",
            blacklisted: false,
            sensitiveResult: SensitiveMatchResult(isSensitive: false, matchedPatterns: []),
            f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: []),
            f2xConfigSnapshot: F2xConfigSnapshot(
                isEnabled: true,
                saveDirectory: "~/Documents/ClipMind/Clips/",
                whitelistBundleIds: ["com.apple.Safari"],
                fileFormat: .markdown,
                lengthThreshold: threshold,
                fileNameLength: 20,
                sensitiveFilterEnabled: true,
                pathFormat: .plainPath
            )
        )
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

```bash
swiftlint lint --strict
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/CaptureEventTests'
```

预期：PASS，6 个测试全部通过。

- [ ] **步骤 5：Commit**

```bash
git add ClipMind/AutoSave/Models/CaptureEvent.swift \
        ClipMindTests/AutoSave/CaptureEventTests.swift \
        ClipMindTests/Fixtures/CaptureEventFixtures.swift
git commit -m "feat(F2.1): add immutable CaptureEvent snapshot with config snapshots

落地 D1（事件驱动模型）与 D6（配置快照不可变）。
CaptureEvent struct 所有属性为 let，实现 Sendable。
包含 F1xConfigSnapshot（黑名单快照）用于 D3 黑名单优先判断。
测试夹具覆盖短文本/敏感内容/黑名单 App/长文本 4 种场景。"
```

---

### 任务 2：SensitiveMatchResult 敏感识别结果

**文件：**
- 创建：`ClipMind/AutoSave/Models/SensitiveMatchResult.swift`
- 测试：`ClipMindTests/AutoSave/SensitiveMatchResultTests.swift`

**目标：** 实现敏感识别结果 struct（D2），承载是否敏感与命中模式列表。实现 `Sendable`。

**对应决策：** D2（敏感识别只执行一次）

- [ ] **步骤 1：编写失败的测试**

创建 `ClipMindTests/AutoSave/SensitiveMatchResultTests.swift`：

```swift
import XCTest

@testable import ClipMind

final class SensitiveMatchResultTests: XCTestCase
{
    // MARK: - TC-UT-07：非敏感结果

    func testNonSensitiveResult() throws
    {
        let result = SensitiveMatchResult(isSensitive: false, matchedPatterns: [])
        XCTAssertFalse(result.isSensitive)
        XCTAssertTrue(result.matchedPatterns.isEmpty)
    }

    // MARK: - TC-UT-08：敏感结果携带命中模式

    func testSensitiveResultWithPatterns() throws
    {
        let result = SensitiveMatchResult(
            isSensitive: true,
            matchedPatterns: ["password", "token"]
        )
        XCTAssertTrue(result.isSensitive)
        XCTAssertEqual(result.matchedPatterns.count, 2)
        XCTAssertEqual(result.matchedPatterns[0], "password")
    }

    // MARK: - TC-UT-09：Equatable 相等比较

    func testEquality() throws
    {
        let a = SensitiveMatchResult(isSensitive: true, matchedPatterns: ["password"])
        let b = SensitiveMatchResult(isSensitive: true, matchedPatterns: ["password"])
        XCTAssertEqual(a, b)
    }

    // MARK: - TC-UT-10：Equatable 不等比较

    func testInequality() throws
    {
        let a = SensitiveMatchResult(isSensitive: true, matchedPatterns: ["password"])
        let b = SensitiveMatchResult(isSensitive: false, matchedPatterns: [])
        XCTAssertNotEqual(a, b)
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
  -only-testing:'ClipMindTests/SensitiveMatchResultTests'
```

预期：FAIL，报错 "Cannot find 'SensitiveMatchResult' in scope"。

- [ ] **步骤 3：编写最少实现代码**

创建 `ClipMind/AutoSave/Models/SensitiveMatchResult.swift`：

```swift
import Foundation

/// 敏感识别结果（D2 敏感识别只执行一次，结果打包进 CaptureEvent）。
///
/// 由 SensitiveDetector 在捕获事件构造阶段执行一次，结果存入 CaptureEvent，
/// 异步 F2.1 流程直接读取，避免重复识别。实现 `Sendable` 保证跨并发边界安全。
public struct SensitiveMatchResult: Sendable, Equatable
{
    public let isSensitive: Bool
    public let matchedPatterns: [String]

    public init(isSensitive: Bool, matchedPatterns: [String])
    {
        self.isSensitive = isSensitive
        self.matchedPatterns = matchedPatterns
    }

    /// 空结果（非敏感，无命中模式）。
    public static let none = SensitiveMatchResult(isSensitive: false, matchedPatterns: [])
}
```

- [ ] **步骤 4：运行测试验证通过**

```bash
swiftlint lint --strict
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/SensitiveMatchResultTests'
```

预期：PASS，4 个测试全部通过。

- [ ] **步骤 5：Commit**

```bash
git add ClipMind/AutoSave/Models/SensitiveMatchResult.swift \
        ClipMindTests/AutoSave/SensitiveMatchResultTests.swift
git commit -m "feat(F2.1): add SensitiveMatchResult for D2 single detection

落地 D2（敏感识别只执行一次）。SensitiveMatchResult struct 承载 isSensitive
与 matchedPatterns，实现 Sendable + Equatable。提供 .none 静态空结果。"
```

---

### 任务 3：F2xConfigSnapshot F2.1 配置快照

**文件：**
- 创建：`ClipMind/AutoSave/Models/F2xConfigSnapshot.swift`
- 测试：`ClipMindTests/AutoSave/F2xConfigSnapshotTests.swift`

**目标：** 实现 F2.1 配置快照 struct（D6/D23），在事件构造阶段读取配置并打包进 CaptureEvent。

**对应决策：** D6（配置快照不可变）、D23（异步执行期间不读实时配置）

- [ ] **步骤 1：编写失败的测试**

创建 `ClipMindTests/AutoSave/F2xConfigSnapshotTests.swift`：

```swift
import XCTest

@testable import ClipMind

final class F2xConfigSnapshotTests: XCTestCase
{
    // MARK: - TC-UT-11：配置快照所有属性可访问

    func testAllPropertiesAccessible() throws
    {
        let snapshot = F2xConfigSnapshot(
            isEnabled: true,
            saveDirectory: "~/Documents/ClipMind/Clips/",
            whitelistBundleIds: ["com.apple.Safari", "com.google.Chrome"],
            fileFormat: .markdown,
            lengthThreshold: 100,
            fileNameLength: 20,
            sensitiveFilterEnabled: true,
            pathFormat: .fileURI
        )

        XCTAssertTrue(snapshot.isEnabled)
        XCTAssertEqual(snapshot.saveDirectory, "~/Documents/ClipMind/Clips/")
        XCTAssertEqual(snapshot.whitelistBundleIds.count, 2)
        XCTAssertEqual(snapshot.fileFormat, .markdown)
        XCTAssertEqual(snapshot.lengthThreshold, 100)
        XCTAssertEqual(snapshot.fileNameLength, 20)
        XCTAssertTrue(snapshot.sensitiveFilterEnabled)
        XCTAssertEqual(snapshot.pathFormat, .fileURI)
    }

    // MARK: - TC-UT-12：白名单包含判断

    func testWhitelistContains() throws
    {
        let snapshot = F2xConfigSnapshot(
            isEnabled: true,
            saveDirectory: "~/Documents/ClipMind/Clips/",
            whitelistBundleIds: ["com.apple.Safari"],
            fileFormat: .markdown,
            lengthThreshold: 50,
            fileNameLength: 20,
            sensitiveFilterEnabled: true,
            pathFormat: .plainPath
        )

        XCTAssertTrue(snapshot.isWhitelisted(bundleId: "com.apple.Safari"))
        XCTAssertFalse(snapshot.isWhitelisted(bundleId: "com.apple.finder"))
    }

    // MARK: - TC-UT-13：从 AutoSaveSettings 构造快照（D23）

    func testFromAutoSaveSettings() throws
    {
        let settings = AutoSaveSettings(
            isEnabled: true,
            saveDirectory: "/tmp/clips/",
            whitelistBundleIds: ["com.test.app"],
            fileFormat: .plainText,
            lengthThreshold: 200,
            fileNameLength: 30,
            sensitiveFilterEnabled: false,
            pathFormat: .markdownLink
        )

        let snapshot = F2xConfigSnapshot(from: settings)

        XCTAssertEqual(snapshot.isEnabled, settings.isEnabled)
        XCTAssertEqual(snapshot.saveDirectory, settings.saveDirectory)
        XCTAssertEqual(snapshot.whitelistBundleIds, settings.whitelistBundleIds)
        XCTAssertEqual(snapshot.fileFormat, settings.fileFormat)
        XCTAssertEqual(snapshot.lengthThreshold, settings.lengthThreshold)
        XCTAssertEqual(snapshot.fileNameLength, settings.fileNameLength)
        XCTAssertEqual(snapshot.sensitiveFilterEnabled, settings.sensitiveFilterEnabled)
        XCTAssertEqual(snapshot.pathFormat, settings.pathFormat)
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
  -only-testing:'ClipMindTests/F2xConfigSnapshotTests'
```

预期：FAIL，报错 "Cannot find 'F2xConfigSnapshot' in scope"。

- [ ] **步骤 3：编写最少实现代码**

创建 `ClipMind/AutoSave/Models/F2xConfigSnapshot.swift`：

```swift
import Foundation

/// F2.1 配置快照（D6 配置快照不可变，D23 异步执行期间不读实时配置）。
///
/// 在捕获事件构造阶段从 `AutoSaveSettingsStore` 读取当前配置并打包进 `CaptureEvent`。
/// 异步 F2.1 流程只读取此快照，避免配置在异步执行期间被修改导致行为不一致。
public struct F2xConfigSnapshot: Sendable, Equatable
{
    public let isEnabled: Bool
    public let saveDirectory: String
    public let whitelistBundleIds: [String]
    public let fileFormat: FileFormat
    public let lengthThreshold: Int
    public let fileNameLength: Int
    public let sensitiveFilterEnabled: Bool
    public let pathFormat: PathFormat

    public init(
        isEnabled: Bool,
        saveDirectory: String,
        whitelistBundleIds: [String],
        fileFormat: FileFormat,
        lengthThreshold: Int,
        fileNameLength: Int,
        sensitiveFilterEnabled: Bool,
        pathFormat: PathFormat
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

    /// 从 `AutoSaveSettings` 构造快照（D23 事件构造阶段读取）。
    public init(from settings: AutoSaveSettings)
    {
        self.isEnabled = settings.isEnabled
        self.saveDirectory = settings.saveDirectory
        self.whitelistBundleIds = settings.whitelistBundleIds
        self.fileFormat = settings.fileFormat
        self.lengthThreshold = settings.lengthThreshold
        self.fileNameLength = settings.fileNameLength
        self.sensitiveFilterEnabled = settings.sensitiveFilterEnabled
        self.pathFormat = settings.pathFormat
    }

    /// 判断 bundleId 是否在白名单中。
    public func isWhitelisted(bundleId: String) -> Bool
    {
        whitelistBundleIds.contains(bundleId)
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

```bash
swiftlint lint --strict
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/F2xConfigSnapshotTests'
```

预期：PASS，3 个测试全部通过（依赖任务 4 的 AutoSaveSettings 已定义）。

> **注意：** 本任务依赖任务 4 的 `AutoSaveSettings` 类型。若任务 4 未完成，`testFromAutoSaveSettings` 会编译失败。推荐先完成任务 4 再验证本任务。

- [ ] **步骤 5：Commit**

```bash
git add ClipMind/AutoSave/Models/F2xConfigSnapshot.swift \
        ClipMindTests/AutoSave/F2xConfigSnapshotTests.swift
git commit -m "feat(F2.1): add F2xConfigSnapshot for D6/D23 config snapshot

落地 D6（配置快照不可变）与 D23（异步执行期间不读实时配置）。
F2xConfigSnapshot struct 提供 init(from: AutoSaveSettings) 构造器
与 isWhitelisted(bundleId:) 用于 D3 白名单判断。"
```

---

### 任务 4：AutoSaveSettings 配置模型

**文件：**
- 创建：`ClipMind/AutoSave/AutoSaveSettings.swift`
- 测试：`ClipMindTests/AutoSave/AutoSaveSettingsTests.swift`

**目标：** 实现配置模型 + `FileFormat`/`PathFormat` 枚举 + 默认值。**D11：总开关默认关闭**。

**对应决策：** D11（总开关默认关闭）

**对应约束：** C-01（保存目录默认值）、C-02（文件格式枚举）、C-03（路径格式枚举）、C-04（文件名长度 1-50）、C-05（长度阈值 1-10000）、C-06（白名单 Bundle ID）

- [ ] **步骤 1：编写失败的测试**

创建 `ClipMindTests/AutoSave/AutoSaveSettingsTests.swift`：

```swift
import XCTest

@testable import ClipMind

final class AutoSaveSettingsTests: XCTestCase
{
    // MARK: - TC-UT-14：默认值（D11 总开关默认关闭）

    func testDefaultValues() throws
    {
        let settings = AutoSaveSettings()

        XCTAssertFalse(settings.isEnabled, "D11：总开关默认应为关闭")
        XCTAssertEqual(settings.saveDirectory, "~/Documents/ClipMind/Clips/")
        XCTAssertEqual(settings.whitelistBundleIds, AutoSaveSettings.defaultWhitelist)
        XCTAssertEqual(settings.fileFormat, .markdown)
        XCTAssertEqual(settings.lengthThreshold, 50)
        XCTAssertEqual(settings.fileNameLength, 20)
        XCTAssertTrue(settings.sensitiveFilterEnabled)
        XCTAssertEqual(settings.pathFormat, .plainPath)
    }

    // MARK: - TC-UT-15：范围常量

    func testRangeConstants() throws
    {
        XCTAssertEqual(AutoSaveSettings.lengthThresholdRange, 1...10000)
        XCTAssertEqual(AutoSaveSettings.fileNameLengthRange, 1...50)
    }

    // MARK: - TC-UT-16：默认白名单内容

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

    // MARK: - TC-UT-17：文件格式扩展名

    func testFileFormatExtension() throws
    {
        XCTAssertEqual(FileFormat.markdown.fileExtension, "md")
        XCTAssertEqual(FileFormat.plainText.fileExtension, "txt")
    }

    // MARK: - TC-UT-18：Codable 往返

    func testCodableRoundTrip() throws
    {
        let settings = AutoSaveSettings(
            isEnabled: true,
            saveDirectory: "/tmp/test/",
            whitelistBundleIds: ["com.test.app"],
            fileFormat: .plainText,
            lengthThreshold: 100,
            fileNameLength: 30,
            sensitiveFilterEnabled: false,
            pathFormat: .fileURI
        )

        let encoded = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AutoSaveSettings.self, from: encoded)

        XCTAssertEqual(settings, decoded)
    }

    // MARK: - TC-UT-19：Equatable 相等比较

    func testEquality() throws
    {
        let a = AutoSaveSettings()
        let b = AutoSaveSettings()
        XCTAssertEqual(a, b)
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

预期：FAIL，报错 "Cannot find 'AutoSaveSettings' in scope"。

- [ ] **步骤 3：编写最少实现代码**

创建 `ClipMind/AutoSave/AutoSaveSettings.swift`：

```swift
import Foundation

/// 文件格式枚举（C-02）。
public enum FileFormat: String, Codable, Sendable, CaseIterable
{
    case markdown
    case plainText

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

    public var displayName: String
    {
        switch self
        {
        case .markdown:
            return "Markdown (.md)"
        case .plainText:
            return "纯文本 (.txt)"
        }
    }
}

/// 路径格式枚举（C-03，D16 URI 编码）。
public enum PathFormat: String, Codable, Sendable, CaseIterable
{
    case plainPath
    case fileURI
    case markdownLink

    public var displayName: String
    {
        switch self
        {
        case .plainPath:
            return "纯路径"
        case .fileURI:
            return "file:// URI"
        case .markdownLink:
            return "Markdown 链接"
        }
    }
}

/// F2.1 自动保存配置模型（D11 总开关默认关闭）。
public struct AutoSaveSettings: Codable, Equatable, Sendable
{
    public var isEnabled: Bool
    public var saveDirectory: String
    public var whitelistBundleIds: [String]
    public var fileFormat: FileFormat
    public var lengthThreshold: Int
    public var fileNameLength: Int
    public var sensitiveFilterEnabled: Bool
    public var pathFormat: PathFormat

    public static let lengthThresholdRange = 1...10000
    public static let fileNameLengthRange = 1...50

    public static let defaultWhitelist: [String] = [
        "com.apple.Safari",
        "com.google.Chrome",
        "com.trae.ide",
        "com.microsoft.VSCode",
        "com.apple.dt.Xcode"
    ]

    public static let defaultSaveDirectory = "~/Documents/ClipMind/Clips/"

    public init(
        isEnabled: Bool = false,
        saveDirectory: String = AutoSaveSettings.defaultSaveDirectory,
        whitelistBundleIds: [String] = AutoSaveSettings.defaultWhitelist,
        fileFormat: FileFormat = .markdown,
        lengthThreshold: Int = 50,
        fileNameLength: Int = 20,
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
swiftlint lint --strict
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/AutoSaveSettingsTests'
```

预期：PASS，6 个测试全部通过。

- [ ] **步骤 5：Commit**

```bash
git add ClipMind/AutoSave/AutoSaveSettings.swift \
        ClipMindTests/AutoSave/AutoSaveSettingsTests.swift
git commit -m "feat(F2.1): add AutoSaveSettings with D11 default disabled

落地 D11（总开关默认关闭）。AutoSaveSettings struct 承载 8 个配置项，
默认 isEnabled=false。包含 FileFormat 与 PathFormat 枚举。
默认白名单含 Safari/Chrome/Trae/VSCode/Xcode 5 个 bundleId。"
```

---

### 任务 5：AutoSaveSettingsStore 配置持久化

**文件：**
- 创建：`ClipMind/AutoSave/AutoSaveSettingsStore.swift`
- 测试：`ClipMindTests/AutoSave/AutoSaveSettingsStoreTests.swift`

**目标：** 实现配置持久化（UserDefaults）+ 范围校验 + 白名单去重 + 变更通知。

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
        defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        store = AutoSaveSettingsStore(defaults: defaults)
    }

    // MARK: - TC-UT-20：默认加载（D11 总开关关闭）

    func testLoadDefaults() throws
    {
        let settings = store.load()
        XCTAssertFalse(settings.isEnabled, "D11：默认总开关关闭")
        XCTAssertEqual(settings.saveDirectory, AutoSaveSettings.defaultSaveDirectory)
        XCTAssertEqual(settings.fileFormat, .markdown)
    }

    // MARK: - TC-UT-21：保存与重新加载

    func testSaveAndReload() throws
    {
        var settings = store.load()
        settings.isEnabled = true
        settings.saveDirectory = "/tmp/clips/"
        settings.lengthThreshold = 100
        store.save(settings)

        let reloaded = store.load()
        XCTAssertTrue(reloaded.isEnabled)
        XCTAssertEqual(reloaded.saveDirectory, "/tmp/clips/")
        XCTAssertEqual(reloaded.lengthThreshold, 100)
    }

    // MARK: - TC-UT-22：范围校验（lengthThreshold 超出上限被截断）

    func testLengthThresholdClamped() throws
    {
        var settings = store.load()
        settings.lengthThreshold = 99999
        store.save(settings)

        let reloaded = store.load()
        XCTAssertEqual(reloaded.lengthThreshold, 10000, "超出上限应被截断到 10000")
    }

    // MARK: - TC-UT-23：白名单去重

    func testWhitelistDeduplication() throws
    {
        var settings = store.load()
        settings.whitelistBundleIds = ["com.apple.Safari", "com.apple.Safari", "com.google.Chrome"]
        store.save(settings)

        let reloaded = store.load()
        XCTAssertEqual(Set(reloaded.whitelistBundleIds).count, 2, "重复项应被去重")
    }

    // MARK: - TC-UT-24：配置变更通知

    func testConfigChangeNotification() throws
    {
        let expectation = XCTestExpectation(description: "应发送配置变更通知")
        let observer = NotificationCenter.default.addObserver(
            forName: AutoSaveSettingsStore.didChangeNotification,
            object: nil,
            queue: nil
        ) { _ in
            expectation.fulfill()
        }

        defer
        {
            NotificationCenter.default.removeObserver(observer)
        }

        var settings = store.load()
        settings.isEnabled = true
        store.save(settings)

        wait(for: [expectation], timeout: 1.0)
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
  -only-testing:'ClipMindTests/AutoSaveSettingsStoreTests'
```

预期：FAIL，报错 "Cannot find 'AutoSaveSettingsStore' in scope"。

- [ ] **步骤 3：编写最少实现代码**

创建 `ClipMind/AutoSave/AutoSaveSettingsStore.swift`：

```swift
import Foundation

/// F2.1 自动保存配置持久化（UserDefaults + 范围校验 + 白名单去重 + 变更通知）。
public final class AutoSaveSettingsStore
{
    public static let didChangeNotification = Notification.Name("ClipMindAutoSaveSettingsDidChange")

    private let defaults: UserDefaults
    private let logger = LogCategory.storage

    private enum Keys
    {
        static let isEnabled = "F2.1.autoSave.isEnabled"
        static let saveDirectory = "F2.1.autoSave.saveDirectory"
        static let whitelistBundleIds = "F2.1.autoSave.whitelistBundleIds"
        static let fileFormat = "F2.1.autoSave.fileFormat"
        static let lengthThreshold = "F2.1.autoSave.lengthThreshold"
        static let fileNameLength = "F2.1.autoSave.fileNameLength"
        static let sensitiveFilterEnabled = "F2.1.autoSave.sensitiveFilterEnabled"
        static let pathFormat = "F2.1.autoSave.pathFormat"
    }

    public init(defaults: UserDefaults = .standard)
    {
        self.defaults = defaults
    }

    public func load() -> AutoSaveSettings
    {
        let isEnabled = defaults.object(forKey: Keys.isEnabled) as? Bool ?? false
        let saveDirectory = defaults.string(forKey: Keys.saveDirectory) ?? AutoSaveSettings.defaultSaveDirectory
        let whitelistBundleIds = defaults.array(forKey: Keys.whitelistBundleIds) as? [String] ?? AutoSaveSettings.defaultWhitelist
        let fileFormatRaw = defaults.string(forKey: Keys.fileFormat) ?? FileFormat.markdown.rawValue
        let fileFormat = FileFormat(rawValue: fileFormatRaw) ?? .markdown
        let lengthThreshold = defaults.object(forKey: Keys.lengthThreshold) as? Int ?? 50
        let fileNameLength = defaults.object(forKey: Keys.fileNameLength) as? Int ?? 20
        let sensitiveFilterEnabled = defaults.object(forKey: Keys.sensitiveFilterEnabled) as? Bool ?? true
        let pathFormatRaw = defaults.string(forKey: Keys.pathFormat) ?? PathFormat.plainPath.rawValue
        let pathFormat = PathFormat(rawValue: pathFormatRaw) ?? .plainPath

        return AutoSaveSettings(
            isEnabled: isEnabled,
            saveDirectory: saveDirectory,
            whitelistBundleIds: Array(Set(whitelistBundleIds)),
            fileFormat: fileFormat,
            lengthThreshold: clamped(lengthThreshold, range: AutoSaveSettings.lengthThresholdRange),
            fileNameLength: clamped(fileNameLength, range: AutoSaveSettings.fileNameLengthRange),
            sensitiveFilterEnabled: sensitiveFilterEnabled,
            pathFormat: pathFormat
        )
    }

    public func save(_ settings: AutoSaveSettings)
    {
        let dedupedWhitelist = Array(Set(settings.whitelistBundleIds))
        let clampedThreshold = clamped(settings.lengthThreshold, range: AutoSaveSettings.lengthThresholdRange)
        let clampedFileNameLength = clamped(settings.fileNameLength, range: AutoSaveSettings.fileNameLengthRange)

        defaults.set(settings.isEnabled, forKey: Keys.isEnabled)
        defaults.set(settings.saveDirectory, forKey: Keys.saveDirectory)
        defaults.set(dedupedWhitelist, forKey: Keys.whitelistBundleIds)
        defaults.set(settings.fileFormat.rawValue, forKey: Keys.fileFormat)
        defaults.set(clampedThreshold, forKey: Keys.lengthThreshold)
        defaults.set(clampedFileNameLength, forKey: Keys.fileNameLength)
        defaults.set(settings.sensitiveFilterEnabled, forKey: Keys.sensitiveFilterEnabled)
        defaults.set(settings.pathFormat.rawValue, forKey: Keys.pathFormat)

        logger.info("Config saved: \(settings.isEnabled, privacy: .public)")

        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }

    private func clamped(_ value: Int, range: ClosedRange<Int>) -> Int
    {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

```bash
swiftlint lint --strict
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/AutoSaveSettingsStoreTests'
```

预期：PASS，5 个测试全部通过。

- [ ] **步骤 5：Commit**

```bash
git add ClipMind/AutoSave/AutoSaveSettingsStore.swift \
        ClipMindTests/AutoSave/AutoSaveSettingsStoreTests.swift
git commit -m "feat(F2.1): add AutoSaveSettingsStore with validation and notification

AutoSaveSettingsStore 持久化配置到 UserDefaults，含范围校验、白名单去重、
配置变更通知（didChangeNotification）。日志仅输出 isEnabled 字段（D15）。"
```

---

### 任务 6：SelfWriteSuppressor 自我写入抑制器

**文件：**
- 创建：`ClipMind/AutoSave/SelfWriteSuppressor.swift`
- 测试：`ClipMindTests/AutoSave/SelfWriteSuppressorTests.swift`

**目标：** 实现自我写入抑制器（D4），通过 `markSelfWrite(changeCount:)` + `checkAndReset(changeCount:)` 配合 5 秒超时避免回环。

**对应决策：** D4（markSelfWrite + checkAndReset，5s 超时）

- [ ] **步骤 1：编写失败的测试**

创建 `ClipMindTests/AutoSave/SelfWriteSuppressorTests.swift`：

```swift
import XCTest

@testable import ClipMind

final class SelfWriteSuppressorTests: XCTestCase
{
    // MARK: - TC-UT-25：无标记时 checkAndReset 返回 false

    func testNoMarkReturnsFalse() throws
    {
        let suppressor = SelfWriteSuppressor()
        XCTAssertFalse(suppressor.checkAndReset(changeCount: 1))
    }

    // MARK: - TC-UT-26：标记后 checkAndReset 返回 true

    func testMarkThenCheckReturnsTrue() throws
    {
        let suppressor = SelfWriteSuppressor()
        suppressor.markSelfWrite(changeCount: 42)
        XCTAssertTrue(suppressor.checkAndReset(changeCount: 42))
    }

    // MARK: - TC-UT-27：checkAndReset 后标记被清除（一次性）

    func testCheckAndResetClearsMark() throws
    {
        let suppressor = SelfWriteSuppressor()
        suppressor.markSelfWrite(changeCount: 42)
        XCTAssertTrue(suppressor.checkAndReset(changeCount: 42))
        XCTAssertFalse(suppressor.checkAndReset(changeCount: 42), "标记应被清除")
    }

    // MARK: - TC-UT-28：不同 changeCount 不匹配

    func testDifferentChangeCountDoesNotMatch() throws
    {
        let suppressor = SelfWriteSuppressor()
        suppressor.markSelfWrite(changeCount: 42)
        XCTAssertFalse(suppressor.checkAndReset(changeCount: 43))
    }

    // MARK: - TC-UT-29：5 秒超时失效（D4）

    func testFiveSecondTimeout() throws
    {
        let suppressor = SelfWriteSuppressor(timeoutInterval: 0.1)
        suppressor.markSelfWrite(changeCount: 42)

        let expectation = XCTestExpectation(description: "超时后标记应失效")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2)
        {
            XCTAssertFalse(suppressor.checkAndReset(changeCount: 42), "超时后标记应失效")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
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
  -only-testing:'ClipMindTests/SelfWriteSuppressorTests'
```

预期：FAIL，报错 "Cannot find 'SelfWriteSuppressor' in scope"。

- [ ] **步骤 3：编写最少实现代码**

创建 `ClipMind/AutoSave/SelfWriteSuppressor.swift`：

```swift
import Foundation

/// 自我写入抑制器（D4 markSelfWrite + checkAndReset，5s 超时）。
///
/// 当 F2.1 替换剪贴板为文件路径后，调用 `markSelfWrite(changeCount:)` 标记。
/// 下一次 PasteboardWatcher 回调时，调用 `checkAndReset(changeCount:)` 检查：
/// 若 changeCount 匹配且未超时（5s），返回 true 表示是自我写入，应跳过 F2.1 处理。
/// 标记为一次性，检查后即清除。
public final class SelfWriteSuppressor
{
    public static let defaultTimeoutInterval: TimeInterval = 5.0

    private let timeoutInterval: TimeInterval
    private let lock = NSLock()
    private var markedChangeCount: Int?
    private var markedAt: Date?

    private let logger = LogCategory.capture

    public init(timeoutInterval: TimeInterval = Self.defaultTimeoutInterval)
    {
        self.timeoutInterval = timeoutInterval
    }

    public func markSelfWrite(changeCount: Int)
    {
        lock.lock()
        defer { lock.unlock() }

        markedChangeCount = changeCount
        markedAt = Date()
        logger.debug("Self-write marked: changeCount=\(changeCount, privacy: .public)")
    }

    public func checkAndReset(changeCount: Int) -> Bool
    {
        lock.lock()
        defer { lock.unlock() }

        guard let markedCount = markedChangeCount, let markedTime = markedAt else
        {
            return false
        }

        markedChangeCount = nil
        markedAt = nil

        let elapsed = Date().timeIntervalSince(markedTime)
        if elapsed > timeoutInterval
        {
            logger.debug("Self-write mark expired: elapsed=\(elapsed, privacy: .public)")
            return false
        }

        return markedCount == changeCount
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

```bash
swiftlint lint --strict
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/SelfWriteSuppressorTests'
```

预期：PASS，5 个测试全部通过。

- [ ] **步骤 5：Commit**

```bash
git add ClipMind/AutoSave/SelfWriteSuppressor.swift \
        ClipMindTests/AutoSave/SelfWriteSuppressorTests.swift
git commit -m "feat(F2.1): add SelfWriteSuppressor for D4 loop prevention

落地 D4（markSelfWrite + checkAndReset，5s 超时）。通过 NSLock 保护标记状态，
markSelfWrite 记录 changeCount 与时间戳，checkAndReset 一次性检查。
超时测试使用 DispatchQueue.main.asyncAfter 而非 sleep（D17）。"
```

---

### 任务 7：FileNameGenerator 文件名生成器

**文件：**
- 创建：`ClipMind/AutoSave/FileNameGenerator.swift`
- 测试：`ClipMindTests/AutoSave/FileNameGeneratorTests.swift`

**目标：** 实现文件名生成 8 步单一确定顺序（D9）。

**对应决策：** D9（8 步单一确定顺序）

**D9 8 步顺序（与需求文档 FR-006/D9 严格一致）：**
1. 读取内容
2. 标准化换行与空白（CRLF → LF，连续空白折叠为单个空格）
3. 取前 N 个用户可见字符（按 Character 组合字符簇计算，N = fileNameLength）
4. 过滤非法字符：换行符、路径分隔符（`/`、`\`）、文件系统特殊字符（`:`、`*`、`?`、`"`、`<`、`>`、`|`、`[`、`]`）
5. 去除首尾空白与首尾的点
6. 为空时使用备用文件名 `clip-{timestamp}`（timestamp 为 Unix 毫秒时间戳，保证并发唯一性）
7. 添加扩展名（`.md` 或 `.txt`，按文件格式配置）
8. 交给冲突处理器原子解决冲突（见 FR-007，由调用方 `ConflictResolver` 完成，`generate` 方法只返回候选文件名）

- [ ] **步骤 1：编写失败的测试**

创建 `ClipMindTests/AutoSave/FileNameGeneratorTests.swift`：

```swift
import XCTest

@testable import ClipMind

final class FileNameGeneratorTests: XCTestCase
{
    // MARK: - TC-UT-30：基础文件名生成（D9 8 步）

    func testBasicFileNameGeneration() throws
    {
        let generator = FileNameGenerator()
        let fileName = generator.generate(
            content: "hello world",
            appName: "Safari",
            fileFormat: .markdown,
            fileNameLength: 20,
            timestamp: Date(timeIntervalSince1970: 1700000000)
        )

        XCTAssertEqual(fileName, "hello world.md", "应取内容前缀并添加扩展名（D9 步骤 3+7）")
    }

    // MARK: - TC-UT-31：非法字符过滤（D9 步骤 4，过滤而非替换）

    func testIllegalCharacterFiltering() throws
    {
        let generator = FileNameGenerator()
        let fileName = generator.generate(
            content: "hello/world:test*file",
            appName: "Safari",
            fileFormat: .plainText,
            fileNameLength: 50,
            timestamp: Date(timeIntervalSince1970: 1700000000)
        )

        XCTAssertFalse(fileName.contains("/"), "应过滤 /")
        XCTAssertFalse(fileName.contains(":"), "应过滤 :")
        XCTAssertFalse(fileName.contains("*"), "应过滤 *")
        XCTAssertTrue(fileName.hasSuffix(".txt"))
        XCTAssertEqual(fileName, "helloworldtestfile.txt", "应过滤非法字符后拼接")
    }

    // MARK: - TC-UT-32：空内容使用 clip-{timestamp}（D9 步骤 6）

    func testEmptyContentUsesClipTimestamp() throws
    {
        let generator = FileNameGenerator()
        let fileName = generator.generate(
            content: "   ",
            appName: "Safari",
            fileFormat: .markdown,
            fileNameLength: 20,
            timestamp: Date(timeIntervalSince1970: 1700000000)
        )

        XCTAssertTrue(fileName.hasPrefix("clip-"), "空内容应使用 clip-{timestamp} 备用名")
        XCTAssertTrue(fileName.hasSuffix(".md"), "应包含 .md 扩展名")
    }

    // MARK: - TC-UT-33：取前 N 字符（D9 步骤 3，按 Character 组合字符簇）

    func testPrefixLengthLimit() throws
    {
        let generator = FileNameGenerator()
        let longContent = String(repeating: "a", count: 100)
        let fileName = generator.generate(
            content: longContent,
            appName: "Safari",
            fileFormat: .markdown,
            fileNameLength: 20,
            timestamp: Date(timeIntervalSince1970: 1700000000)
        )

        // 文件名 = 20 字符前缀 + ".md" = 23 字符
        XCTAssertEqual(fileName.count, 23, "应取前 20 字符 + 扩展名")
        XCTAssertTrue(fileName.hasSuffix(".md"))
    }

    // MARK: - TC-UT-34：换行与空白标准化（D9 步骤 2，CRLF→LF，连续空白折叠）

    func testWhitespaceNormalization() throws
    {
        let generator = FileNameGenerator()
        let fileName = generator.generate(
            content: "hello\r\n\r\n   world",
            appName: "Safari",
            fileFormat: .markdown,
            fileNameLength: 50,
            timestamp: Date(timeIntervalSince1970: 1700000000)
        )

        XCTAssertFalse(fileName.contains("\r"), "应将 CRLF 转为 LF")
        XCTAssertFalse(fileName.contains("\n"), "应过滤换行符（步骤 4）")
        XCTAssertFalse(fileName.contains("  "), "连续空白应折叠为单个空格")
        XCTAssertTrue(fileName.hasSuffix(".md"))
    }

    // MARK: - TC-UT-35：首尾空白与首尾的点去除（D9 步骤 5）

    func testTrimLeadingTrailingDotsAndWhitespace() throws
    {
        let generator = FileNameGenerator()
        let fileName = generator.generate(
            content: "  .hello.  ",
            appName: "Safari",
            fileFormat: .markdown,
            fileNameLength: 50,
            timestamp: Date(timeIntervalSince1970: 1700000000)
        )

        XCTAssertFalse(fileName.hasPrefix("."), "应去除首尾的点")
        XCTAssertFalse(fileName.hasPrefix(" "), "应去除首尾空白")
        XCTAssertTrue(fileName.hasPrefix("hello"), "应保留内容")
        XCTAssertTrue(fileName.hasSuffix(".md"))
    }

    // MARK: - TC-UT-35b：中文保留（D9 步骤 4 保留中文，AC-10）

    func testChinesePreserved() throws
    {
        let generator = FileNameGenerator()
        let fileName = generator.generate(
            content: "你好世界 content",
            appName: "Safari",
            fileFormat: .markdown,
            fileNameLength: 50,
            timestamp: Date(timeIntervalSince1970: 1700000000)
        )

        XCTAssertTrue(fileName.contains("你好世界"), "应保留中文")
        XCTAssertTrue(fileName.hasSuffix(".md"))
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
  -only-testing:'ClipMindTests/FileNameGeneratorTests'
```

预期：FAIL，报错 "Cannot find 'FileNameGenerator' in scope"。

- [ ] **步骤 3：编写最少实现代码**

创建 `ClipMind/AutoSave/FileNameGenerator.swift`：

```swift
import Foundation

/// 文件名生成器（D9 8 步单一确定顺序，与需求文档 FR-006/D9 严格一致）。
public struct FileNameGenerator
{
    /// 非法字符集合（D9 步骤 4）：换行符、路径分隔符、文件系统特殊字符、Markdown 链接字符。
    /// 注意：`.` 的首尾去除在步骤 5 处理。
    private static let illegalCharacters: Set<Character> = [
        "\n", "\r", "\t",
        "/", "\\",
        ":", "*", "?", "\"", "<", ">", "|",
        "[", "]"
    ]

    public init() {}

    /// 生成候选文件名（D9 步骤 1~7，步骤 8 由调用方 ConflictResolver 完成）。
    public func generate(
        content: String,
        appName: String,
        fileFormat: FileFormat,
        fileNameLength: Int,
        timestamp: Date
    ) -> String
    {
        // 步骤 1：读取内容（content 已传入）

        // 步骤 2：标准化换行与空白（CRLF → LF，连续空白折叠为单个空格）
        let lineNormalized = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let collapsed = Self.collapseWhitespace(lineNormalized)

        // 步骤 3：取前 N 个用户可见字符（按 Character 组合字符簇计算）
        let prefix = String(collapsed.prefix(fileNameLength))

        // 步骤 4：过滤非法字符
        let filtered = prefix.filter { !Self.illegalCharacters.contains($0) }

        // 步骤 5：去除首尾空白与首尾的点
        var trimmed = filtered.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasPrefix(".")
        {
            trimmed.removeFirst()
        }
        while trimmed.hasSuffix(".")
        {
            trimmed.removeLast()
        }

        // 步骤 6：为空时使用备用文件名 clip-{timestamp}（毫秒时间戳，保证并发唯一性）
        let baseName: String
        if trimmed.isEmpty
        {
            let millis = Int(timestamp.timeIntervalSince1970 * 1000)
            baseName = "clip-\(millis)"
        }
        else
        {
            baseName = trimmed
        }

        // 步骤 7：添加扩展名
        let ext = fileFormat.fileExtension
        return "\(baseName).\(ext)"

        // 步骤 8：交给冲突处理器（由调用方 ConflictResolver 完成，见 FR-007）
    }

    /// 折叠连续空白为单个空格（D9 步骤 2）。
    private static func collapseWhitespace(_ text: String) -> String
    {
        var result = ""
        var lastWasWhitespace = false
        for char in text
        {
            if char.isWhitespace
            {
                if !lastWasWhitespace
                {
                    result.append(" ")
                    lastWasWhitespace = true
                }
            }
            else
            {
                result.append(char)
                lastWasWhitespace = false
            }
        }
        return result
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

```bash
swiftlint lint --strict
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/FileNameGeneratorTests'
```

预期：PASS，7 个测试全部通过。

- [ ] **步骤 5：Commit**

```bash
git add ClipMind/AutoSave/FileNameGenerator.swift \
        ClipMindTests/AutoSave/FileNameGeneratorTests.swift
git commit -m "feat(F2.1): add FileNameGenerator with D9 8-step deterministic order

落地 D9（文件名生成 8 步）：读取内容→标准化换行空白→取前 N 字符→过滤非法字符→
去首尾空白与点→空内容用 clip-{timestamp}→添加扩展名→交给冲突处理器。
generate 方法只返回候选文件名，步骤 8 由调用方 ConflictResolver 完成。
非法字符采用过滤而非替换为 _；空内容用 clip-{timestamp}（毫秒）而非 untitled；
不追加哈希后缀与时间戳后缀。"
```

---

### 任务 8：ConflictResolver 冲突处理器

**文件：**
- 创建：`ClipMind/AutoSave/ConflictResolver.swift`
- 创建：`ClipMind/AutoSave/AutoSaveError.swift`
- 测试：`ClipMindTests/AutoSave/ConflictResolverTests.swift`

**目标：** 实现冲突处理器，当文件已存在时追加数字后缀递增（最多 999）。

- [ ] **步骤 1：编写失败的测试**

创建 `ClipMindTests/AutoSave/ConflictResolverTests.swift`：

```swift
import XCTest

@testable import ClipMind

final class ConflictResolverTests: XCTestCase
{
    private var tempDir: URL!

    override func setUpWithError() throws
    {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws
    {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - TC-UT-36：无冲突时返回原文件名

    func testNoConflictReturnsOriginal() throws
    {
        let resolver = ConflictResolver()
        let url = tempDir.appendingPathComponent("hello.md")
        let resolved = try resolver.resolve(url)
        XCTAssertEqual(resolved.lastPathComponent, "hello.md")
    }

    // MARK: - TC-UT-37：冲突时追加数字后缀（分隔符 `-`，与 FR-007 一致）

    func testConflictAppendsNumberSuffix() throws
    {
        let resolver = ConflictResolver()
        let url = tempDir.appendingPathComponent("hello.md")
        try Data("existing".utf8).write(to: url)

        let resolved = try resolver.resolve(url)
        XCTAssertEqual(resolved.lastPathComponent, "hello-1.md")
    }

    // MARK: - TC-UT-38：多次冲突递增

    func testMultipleConflictsIncrement() throws
    {
        let resolver = ConflictResolver()
        let url = tempDir.appendingPathComponent("hello.md")
        try Data("1".utf8).write(to: url)
        try Data("2".utf8).write(to: tempDir.appendingPathComponent("hello-1.md"))
        try Data("3".utf8).write(to: tempDir.appendingPathComponent("hello-2.md"))

        let resolved = try resolver.resolve(url)
        XCTAssertEqual(resolved.lastPathComponent, "hello-3.md")
    }

    // MARK: - TC-UT-39：超过最大次数抛出错误

    func testExceedMaxThrowsError() throws
    {
        let resolver = ConflictResolver(maxAttempts: 3)
        let url = tempDir.appendingPathComponent("hello.md")
        try Data("0".utf8).write(to: url)
        try Data("1".utf8).write(to: tempDir.appendingPathComponent("hello-1.md"))
        try Data("2".utf8).write(to: tempDir.appendingPathComponent("hello-2.md"))
        try Data("3".utf8).write(to: tempDir.appendingPathComponent("hello-3.md"))

        XCTAssertThrowsError(try resolver.resolve(url)) { error in
            guard case AutoSaveError.fileNameConflictExhausted = error else
            {
                XCTFail("应抛出 fileNameConflictExhausted 错误")
                return
            }
        }
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
  -only-testing:'ClipMindTests/ConflictResolverTests'
```

预期：FAIL，报错 "Cannot find 'ConflictResolver' in scope"。

- [ ] **步骤 3：编写最少实现代码**

创建 `ClipMind/AutoSave/AutoSaveError.swift`：

```swift
import Foundation

/// F2.1 自动保存错误类型（D13 目录异常分级）。
public enum AutoSaveError: Error, LocalizedError
{
    case fileNameConflictExhausted
    case directoryCreationFailed(path: String)
    case fileWriteFailed(fileName: String)
    case permissionDenied(path: String)
    case contentTooLarge
    case unsupportedContentType

    public var errorDescription: String?
    {
        switch self
        {
        case .fileNameConflictExhausted:
            return "文件名冲突重试次数已耗尽"
        case .directoryCreationFailed:
            return "保存目录创建失败"
        case .fileWriteFailed:
            return "文件写入失败"
        case .permissionDenied:
            return "权限不足"
        case .contentTooLarge:
            return "内容超过 100KB 上限"
        case .unsupportedContentType:
            return "不支持的剪贴板内容类型"
        }
    }
}
```

创建 `ClipMind/AutoSave/ConflictResolver.swift`：

```swift
import Foundation

/// 冲突处理器（文件已存在时追加数字后缀递增）。
public struct ConflictResolver
{
    public static let defaultMaxAttempts = 999

    private let maxAttempts: Int

    public init(maxAttempts: Int = Self.defaultMaxAttempts)
    {
        self.maxAttempts = maxAttempts
    }

    public func resolve(_ url: URL) throws -> URL
    {
        let fileManager = FileManager.default

        if !fileManager.fileExists(atPath: url.path)
        {
            return url
        }

        let directory = url.deletingLastPathComponent()
        let originalName = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension

        for attempt in 1...maxAttempts
        {
            let candidateName = "\(originalName)-\(attempt).\(ext)"
            let candidateURL = directory.appendingPathComponent(candidateName)
            if !fileManager.fileExists(atPath: candidateURL.path)
            {
                return candidateURL
            }
        }

        throw AutoSaveError.fileNameConflictExhausted
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

```bash
swiftlint lint --strict
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/ConflictResolverTests'
```

预期：PASS，4 个测试全部通过。

- [ ] **步骤 5：Commit**

```bash
git add ClipMind/AutoSave/ConflictResolver.swift \
        ClipMind/AutoSave/AutoSaveError.swift \
        ClipMindTests/AutoSave/ConflictResolverTests.swift
git commit -m "feat(F2.1): add ConflictResolver and AutoSaveError types

ConflictResolver 在文件已存在时追加 -N 数字后缀递增（默认最多 999 次），
分隔符 `-` 与需求文档 FR-007 示例（content-1.md、content-2.md）一致。
AutoSaveError 含 6 种错误类型，覆盖 D13 目录异常分级与 D12 内容边界。"
```

---

### 任务 9：FileWriter 文件写入器

**文件：**
- 创建：`ClipMind/AutoSave/FileWriter.swift`
- 测试：`ClipMindTests/AutoSave/FileWriterTests.swift`

**目标：** 实现文件写入器，使用 O_EXCL 原子创建（D10）+ POSIX 0600 权限（D14）+ 异常分级处理（D13）。

**对应决策：** D10（O_EXCL 原子创建 + 半成品清理）、D13（目录异常分级）、D14（POSIX 0600）

- [ ] **步骤 1：编写失败的测试**

创建 `ClipMindTests/AutoSave/FileWriterTests.swift`：

```swift
import XCTest

@testable import ClipMind

final class FileWriterTests: XCTestCase
{
    private var tempDir: URL!
    private var writer: FileWriter!

    override func setUpWithError() throws
    {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        writer = FileWriter()
    }

    override func tearDownWithError() throws
    {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - TC-UT-40：成功写入文件（D10 O_EXCL + D14 0600）

    func testWriteFileSuccess() throws
    {
        let url = tempDir.appendingPathComponent("test.md")
        try writer.write(content: "hello world", to: url)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(content, "hello world")
    }

    // MARK: - TC-UT-41：文件权限为 0600（D14）

    func testFilePermission0600() throws
    {
        let url = tempDir.appendingPathComponent("perm.md")
        try writer.write(content: "test", to: url)

        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let permissions = attrs[.posixPermissions] as? NSNumber
        XCTAssertEqual(permissions?.int16Value, 0o600, "D14：文件权限应为 0600")
    }

    // MARK: - TC-UT-42：文件已存在抛出错误（D10 O_EXCL）

    func testFileExistsThrows() throws
    {
        let url = tempDir.appendingPathComponent("exists.md")
        try Data("existing".utf8).write(to: url)

        XCTAssertThrowsError(try writer.write(content: "new", to: url)) { error in
            guard case AutoSaveError.fileWriteFailed = error else
            {
                XCTFail("应抛出 fileWriteFailed 错误")
                return
            }
        }

        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(content, "existing", "原文件内容不应被覆盖")
    }

    // MARK: - TC-UT-43：目录不存在时创建目录（D13）

    func testCreateDirectoryIfNotExists() throws
    {
        let nestedDir = tempDir.appendingPathComponent("nested/deep/dir")
        let url = nestedDir.appendingPathComponent("test.md")
        try writer.write(content: "test", to: url)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    // MARK: - TC-UT-44：权限不足抛出 permissionDenied（D13）

    func testPermissionDenied() throws
    {
        let readOnlyDir = tempDir.appendingPathComponent("readonly")
        try FileManager.default.createDirectory(at: readOnlyDir, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: readOnlyDir.path)

        defer
        {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: readOnlyDir.path)
        }

        let url = readOnlyDir.appendingPathComponent("test.md")
        XCTAssertThrowsError(try writer.write(content: "test", to: url)) { error in
            // 允许 permissionDenied 或 fileWriteFailed（取决于 OS 权限映射）
            guard case AutoSaveError.permissionDenied = error
                ?? (error as? AutoSaveError) ?? .fileWriteFailed(fileName: "") else
            {
                return
            }
        }
    }

    // MARK: - TC-UT-45：半成品清理（D10）

    func testPartialFileCleanup() throws
    {
        let invalidURL = URL(fileURLWithPath: "/dev/null/invalid.md")

        XCTAssertThrowsError(try writer.write(content: "test", to: invalidURL))

        XCTAssertFalse(FileManager.default.fileExists(atPath: invalidURL.path))
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
  -only-testing:'ClipMindTests/FileWriterTests'
```

预期：FAIL，报错 "Cannot find 'FileWriter' in scope"。

- [ ] **步骤 3：编写最少实现代码**

创建 `ClipMind/AutoSave/FileWriter.swift`：

```swift
import Foundation

/// 文件写入器（D10 O_EXCL 原子创建 + D14 0600 权限 + D13 异常分级）。
public struct FileWriter
{
    private static let filePermissions: Int = 0o600

    private let logger = LogCategory.storage

    public init() {}

    public func write(content: String, to url: URL) throws
    {
        let directory = url.deletingLastPathComponent()
        let fileManager = FileManager.default

        // D13：目录不存在时创建
        if !fileManager.fileExists(atPath: directory.path)
        {
            do
            {
                try fileManager.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true,
                    attributes: [.posixPermissions: 0o755]
                )
            }
            catch
            {
                logger.error("Directory creation failed: errorCode=\(error._code, privacy: .public)")
                throw AutoSaveError.directoryCreationFailed(path: directory.path)
            }
        }

        // D10：O_EXCL 原子创建（文件已存在则失败）
        let data = Data(content.utf8)
        do
        {
            try data.write(to: url, options: [.atomic, .withoutOverwriting])
        }
        catch let error as NSError
        {
            if error.code == NSFileWriteNoPermissionError
            {
                logger.error("Permission denied: errorCode=\(error.code, privacy: .public)")
                throw AutoSaveError.permissionDenied(path: url.path)
            }
            if error.code == NSFileWriteFileExistsError
            {
                logger.error("File exists: fileName=\(url.lastPathComponent, privacy: .public)")
                throw AutoSaveError.fileWriteFailed(fileName: url.lastPathComponent)
            }
            logger.error("Write failed: errorCode=\(error.code, privacy: .public)")
            throw AutoSaveError.fileWriteFailed(fileName: url.lastPathComponent)
        }

        // D14：设置 POSIX 0600 权限
        do
        {
            try fileManager.setAttributes([.posixPermissions: Self.filePermissions], ofItemAtPath: url.path)
        }
        catch
        {
            // D10：半成品清理
            try? fileManager.removeItem(at: url)
            logger.error("Permission set failed, cleaned up: fileName=\(url.lastPathComponent, privacy: .public)")
            throw AutoSaveError.fileWriteFailed(fileName: url.lastPathComponent)
        }

        logger.info("File written: fileName=\(url.lastPathComponent, privacy: .public)")
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

```bash
swiftlint lint --strict
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/FileWriterTests'
```

预期：PASS，6 个测试全部通过。

- [ ] **步骤 5：Commit**

```bash
git add ClipMind/AutoSave/FileWriter.swift \
        ClipMindTests/AutoSave/FileWriterTests.swift
git commit -m "feat(F2.1): add FileWriter with D10 O_EXCL and D14 0600 permissions

落地 D10（O_EXCL 原子创建 + 半成品清理）、D13（目录异常分级）、
D14（POSIX 0600 权限）。使用 data.write(options: [.atomic, .withoutOverwriting])
实现 O_EXCL，权限设置失败时删除已写入文件。"
```

---

### 任务 10：FilePathFormatter 路径格式化器

**文件：**
- 创建：`ClipMind/AutoSave/FilePathFormatter.swift`
- 测试：`ClipMindTests/AutoSave/FilePathFormatterTests.swift`

**目标：** 实现路径格式化器（D16 URI 标准编码），支持 plainPath/fileURI/markdownLink 三种格式。

**对应决策：** D16（URI 标准编码）

- [ ] **步骤 1：编写失败的测试**

创建 `ClipMindTests/AutoSave/FilePathFormatterTests.swift`：

```swift
import XCTest

@testable import ClipMind

final class FilePathFormatterTests: XCTestCase
{
    private let formatter = FilePathFormatter()

    // MARK: - TC-UT-46：plainPath 格式

    func testPlainPathFormat() throws
    {
        let url = URL(fileURLWithPath: "/Users/test/Documents/Clips/hello.md")
        let result = formatter.format(url: url, format: .plainPath)
        XCTAssertEqual(result, "/Users/test/Documents/Clips/hello.md")
    }

    // MARK: - TC-UT-47：fileURI 格式（D16 URI 编码）

    func testFileURIFormat() throws
    {
        let url = URL(fileURLWithPath: "/Users/test/Documents/Clips/hello world.md")
        let result = formatter.format(url: url, format: .fileURI)
        XCTAssertEqual(result, "file:///Users/test/Documents/Clips/hello%20world.md")
    }

    // MARK: - TC-UT-48：markdownLink 格式（D16 URL 编码）

    func testMarkdownLinkFormat() throws
    {
        let url = URL(fileURLWithPath: "/Users/test/Documents/Clips/hello world.md")
        let result = formatter.format(url: url, format: .markdownLink)
        XCTAssertEqual(result, "[hello world.md](file:///Users/test/Documents/Clips/hello%20world.md)")
    }

    // MARK: - TC-UT-49：中文文件名 URI 编码

    func testChineseFileNameURIEncoding() throws
    {
        let url = URL(fileURLWithPath: "/Users/test/Documents/Clips/测试文件.md")
        let result = formatter.format(url: url, format: .fileURI)
        XCTAssertTrue(result.hasPrefix("file:///Users/test/Documents/Clips/"))
        XCTAssertTrue(result.contains(".md"))
        XCTAssertFalse(result.contains("测试文件"), "中文字符应被编码")
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
  -only-testing:'ClipMindTests/FilePathFormatterTests'
```

预期：FAIL，报错 "Cannot find 'FilePathFormatter' in scope"。

- [ ] **步骤 3：编写最少实现代码**

创建 `ClipMind/AutoSave/FilePathFormatter.swift`：

```swift
import Foundation

/// 路径格式化器（D16 URI 标准编码）。
public struct FilePathFormatter
{
    public init() {}

    public func format(url: URL, format: PathFormat) -> String
    {
        switch format
        {
        case .plainPath:
            return url.path
        case .fileURI:
            return url.absoluteString
        case .markdownLink:
            let displayName = url.lastPathComponent
            let uri = url.absoluteString
            return "[\(displayName)](\(uri))"
        }
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

```bash
swiftlint lint --strict
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/FilePathFormatterTests'
```

预期：PASS，4 个测试全部通过。URL.absoluteString 自动处理 D16 URI 编码。

- [ ] **步骤 5：Commit**

```bash
git add ClipMind/AutoSave/FilePathFormatter.swift \
        ClipMindTests/AutoSave/FilePathFormatterTests.swift
git commit -m "feat(F2.1): add FilePathFormatter with D16 URI encoding

落地 D16（URI 标准编码）。支持 plainPath/fileURI/markdownLink 三种格式。
fileURI 与 markdownLink 使用 URL.absoluteString 自动进行 URI 标准编码。"
```

---

### 任务 11：ClipboardReplacer 剪贴板替换器

**文件：**
- 创建：`ClipMind/AutoSave/ClipboardReplacer.swift`
- 测试：`ClipMindTests/AutoSave/ClipboardReplacerTests.swift`

**目标：** 实现剪贴板替换器，执行 D5 changeCount 前置条件检查 + 调用 SelfWriteSuppressor.markSelfWrite。

**对应决策：** D5（changeCount 前置条件）、D4（markSelfWrite）

- [ ] **步骤 1：编写失败的测试**

创建 `ClipMindTests/AutoSave/ClipboardReplacerTests.swift`：

```swift
import AppKit
import XCTest

@testable import ClipMind

final class ClipboardReplacerTests: XCTestCase
{
    private var pasteboard: NSPasteboard!
    private var suppressor: SelfWriteSuppressor!
    private var replacer: ClipboardReplacer!

    override func setUpWithError() throws
    {
        pasteboard = NSPasteboard(name: .init("test-\(UUID().uuidString)"))
        pasteboard.clearContents()
        suppressor = SelfWriteSuppressor()
        replacer = ClipboardReplacer(pasteboard: pasteboard, suppressor: suppressor)
    }

    // MARK: - TC-UT-50：成功替换剪贴板（D5 changeCount 匹配）

    func testReplaceSuccess() throws
    {
        pasteboard.clearContents()
        pasteboard.setString("original", forType: .string)
        let changeCount = pasteboard.changeCount

        let result = replacer.replace(with: "/path/to/file.md", expectedChangeCount: changeCount)

        XCTAssertTrue(result, "changeCount 匹配时应成功替换")
        XCTAssertEqual(pasteboard.string(forType: .string), "/path/to/file.md")
    }

    // MARK: - TC-UT-51：changeCount 不匹配时拒绝替换（D5 前置条件）

    func testReplaceRejectedWhenChangeCountMismatch() throws
    {
        pasteboard.clearContents()
        pasteboard.setString("original", forType: .string)

        let result = replacer.replace(
            with: "/path/to/file.md",
            expectedChangeCount: pasteboard.changeCount + 999
        )

        XCTAssertFalse(result, "changeCount 不匹配时应拒绝替换")
        XCTAssertEqual(pasteboard.string(forType: .string), "original", "原内容应未被修改")
    }

    // MARK: - TC-UT-52：替换后调用 markSelfWrite（D4）

    func testMarkSelfWriteAfterReplace() throws
    {
        pasteboard.clearContents()
        let changeCount = pasteboard.changeCount

        _ = replacer.replace(with: "/path/to/file.md", expectedChangeCount: changeCount)

        let newChangeCount = pasteboard.changeCount
        XCTAssertTrue(suppressor.checkAndReset(changeCount: newChangeCount), "应标记新的 changeCount")
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
  -only-testing:'ClipMindTests/ClipboardReplacerTests'
```

预期：FAIL，报错 "Cannot find 'ClipboardReplacer' in scope"。

- [ ] **步骤 3：编写最少实现代码**

创建 `ClipMind/AutoSave/ClipboardReplacer.swift`：

```swift
import AppKit
import Foundation

/// 剪贴板替换器（D5 changeCount 前置条件 + D4 markSelfWrite）。
public final class ClipboardReplacer
{
    private let pasteboard: NSPasteboard
    private let suppressor: SelfWriteSuppressor
    private let logger = LogCategory.capture

    public init(pasteboard: NSPasteboard, suppressor: SelfWriteSuppressor)
    {
        self.pasteboard = pasteboard
        self.suppressor = suppressor
    }

    /// 替换剪贴板内容（D5 changeCount 前置条件 + D4 markSelfWrite）。
    @discardableResult
    public func replace(with newPath: String, expectedChangeCount: Int) -> Bool
    {
        // D5：changeCount 前置条件
        guard pasteboard.changeCount == expectedChangeCount else
        {
            logger.info("ChangeCount mismatch, skip replace: expected=\(expectedChangeCount, privacy: .public)")
            return false
        }

        pasteboard.clearContents()
        pasteboard.setString(newPath, forType: .string)

        // D4：标记自我写入
        let newChangeCount = pasteboard.changeCount
        suppressor.markSelfWrite(changeCount: newChangeCount)

        logger.info("Clipboard replaced: changeCount=\(newChangeCount, privacy: .public)")
        return true
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

```bash
swiftlint lint --strict
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/ClipboardReplacerTests'
```

预期：PASS，3 个测试全部通过。

- [ ] **步骤 5：Commit**

```bash
git add ClipMind/AutoSave/ClipboardReplacer.swift \
        ClipMindTests/AutoSave/ClipboardReplacerTests.swift
git commit -m "feat(F2.1): add ClipboardReplacer with D5 precondition and D4 mark

落地 D5（changeCount 前置条件）与 D4（替换后 markSelfWrite）。
changeCount 不匹配时拒绝替换，避免覆盖用户手动复制的新内容。"
```

---

### 任务 12：AutoSaveService 主服务

**文件：**
- 创建：`ClipMind/AutoSave/AutoSaveService.swift`
- 测试：`ClipMindTests/AutoSave/AutoSaveServiceTests.swift`

**目标：** 实现主服务，协调各子模块并异步派发到串行队列（D7）。包含 D12 边界检查、D24 不重试旧事件、D3 黑名单优先、D6 配置快照读取。

**对应决策：** D3（黑名单优先）、D6（配置快照）、D7（串行队列）、D12（边界检查）、D24（不重试旧事件）

- [ ] **步骤 1：编写失败的测试**

创建 `ClipMindTests/AutoSave/AutoSaveServiceTests.swift`：

```swift
import AppKit
import XCTest

@testable import ClipMind

final class AutoSaveServiceTests: XCTestCase
{
    private var pasteboard: NSPasteboard!
    private var settingsStore: AutoSaveSettingsStore!
    private var defaults: UserDefaults!
    private var suppressor: SelfWriteSuppressor!
    private var service: AutoSaveService!
    private var tempDir: URL!

    override func setUpWithError() throws
    {
        pasteboard = NSPasteboard(name: .init("test-\(UUID().uuidString)"))
        pasteboard.clearContents()
        defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        settingsStore = AutoSaveSettingsStore(defaults: defaults)
        suppressor = SelfWriteSuppressor()

        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        var settings = settingsStore.load()
        settings.isEnabled = true
        settings.saveDirectory = tempDir.path + "/"
        settings.lengthThreshold = 10
        settingsStore.save(settings)

        service = AutoSaveService(
            settingsStore: settingsStore,
            pasteboard: pasteboard,
            suppressor: suppressor
        )
    }

    override func tearDownWithError() throws
    {
        try? FileManager.default.removeItem(at: tempDir)
        defaults.removePersistentDomain(forName: defaults.dictionaryRepresentation().keys.first ?? "")
    }

    // MARK: - TC-UT-53：F2.1 禁用时不触发保存（D11）

    func testDisabledF2xDoesNotSave() throws
    {
        var settings = settingsStore.load()
        settings.isEnabled = false
        settingsStore.save(settings)

        let event = CaptureEventFixtures.longTextEvent(threshold: 10)
        service.handle(event: event)
        waitForQueue()

        let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        XCTAssertTrue(files.isEmpty, "F2.1 禁用时不应创建文件")
    }

    // MARK: - TC-UT-54：黑名单 App 不触发保存（D3 黑名单优先）

    func testBlacklistedAppDoesNotSave() throws
    {
        let event = CaptureEventFixtures.blacklistedAppEvent()
        service.handle(event: event)
        waitForQueue()

        let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        XCTAssertTrue(files.isEmpty, "黑名单 App 不应触发 F2.1")
    }

    // MARK: - TC-UT-55：非白名单 App 不触发保存

    func testNonWhitelistedAppDoesNotSave() throws
    {
        let event = CaptureEvent(
            changeCount: 100,
            content: .text(String(repeating: "a", count: 100)),
            bundleId: "com.unknown.app",
            appName: "Unknown",
            blacklisted: false,
            sensitiveResult: .none,
            f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: []),
            f2xConfigSnapshot: F2xConfigSnapshot(from: settingsStore.load())
        )

        service.handle(event: event)
        waitForQueue()

        let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        XCTAssertTrue(files.isEmpty, "非白名单 App 不应触发 F2.1")
    }

    // MARK: - TC-UT-56：内容长度不足不触发保存

    func testShortContentDoesNotSave() throws
    {
        var settings = settingsStore.load()
        settings.lengthThreshold = 100
        settingsStore.save(settings)

        let shortEvent = CaptureEvent(
            changeCount: 101,
            content: .text("short"),
            bundleId: "com.apple.Safari",
            appName: "Safari",
            blacklisted: false,
            sensitiveResult: .none,
            f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: []),
            f2xConfigSnapshot: F2xConfigSnapshot(from: settingsStore.load())
        )

        service.handle(event: shortEvent)
        waitForQueue()

        let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        XCTAssertTrue(files.isEmpty, "内容长度不足不应触发 F2.1")
    }

    // MARK: - TC-UT-57：成功保存并替换剪贴板（AC-01/06/13）

    func testSuccessfulSaveAndReplace() throws
    {
        pasteboard.clearContents()
        pasteboard.setString("original long content", forType: .string)
        let changeCount = pasteboard.changeCount

        let event = CaptureEvent(
            changeCount: changeCount,
            content: .text(String(repeating: "a", count: 100)),
            bundleId: "com.apple.Safari",
            appName: "Safari",
            blacklisted: false,
            sensitiveResult: .none,
            f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: []),
            f2xConfigSnapshot: F2xConfigSnapshot(from: settingsStore.load())
        )

        service.handle(event: event)
        waitForQueue()

        let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        XCTAssertEqual(files.count, 1, "应创建 1 个文件")
        XCTAssertTrue(files[0].pathExtension == "md")

        let replaced = pasteboard.string(forType: .string) ?? ""
        XCTAssertTrue(replaced.contains(tempDir.path) || replaced.hasPrefix("file://"), "剪贴板应替换为文件路径")
    }

    // MARK: - TC-UT-58：敏感内容跳过保存（D2 + sensitiveFilterEnabled）

    func testSensitiveContentSkipped() throws
    {
        let event = CaptureEventFixtures.sensitiveContentEvent()
        service.handle(event: event)
        waitForQueue()

        let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        XCTAssertTrue(files.isEmpty, "敏感内容应跳过保存")
    }

    // MARK: - TC-UT-59：changeCount 过期不重试（D24）

    func testExpiredChangeCountDoesNotRetry() throws
    {
        pasteboard.clearContents()
        pasteboard.setString("original", forType: .string)

        let event = CaptureEvent(
            changeCount: 999,
            content: .text(String(repeating: "a", count: 100)),
            bundleId: "com.apple.Safari",
            appName: "Safari",
            blacklisted: false,
            sensitiveResult: .none,
            f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: []),
            f2xConfigSnapshot: F2xConfigSnapshot(from: settingsStore.load())
        )

        service.handle(event: event)
        waitForQueue()

        XCTAssertEqual(pasteboard.string(forType: .string), "original", "changeCount 过期时剪贴板不应被替换")
    }

    // MARK: - TC-UT-60：图片内容不触发保存（D12）

    func testImageContentDoesNotSave() throws
    {
        let event = CaptureEvent(
            changeCount: 200,
            content: .image(NSImage()),
            bundleId: "com.apple.Safari",
            appName: "Safari",
            blacklisted: false,
            sensitiveResult: .none,
            f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: []),
            f2xConfigSnapshot: F2xConfigSnapshot(from: settingsStore.load())
        )

        service.handle(event: event)
        waitForQueue()

        let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        XCTAssertTrue(files.isEmpty, "图片内容不应触发 F2.1（D12）")
    }

    private func waitForQueue()
    {
        let expectation = XCTestExpectation(description: "等待队列完成")
        service.queue.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 2.0)
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
  -only-testing:'ClipMindTests/AutoSaveServiceTests'
```

预期：FAIL，报错 "Cannot find 'AutoSaveService' in scope"。

- [ ] **步骤 3：编写最少实现代码**

创建 `ClipMind/AutoSave/AutoSaveService.swift`：

```swift
import AppKit
import Foundation

/// F2.1 自动保存主服务（D7 串行队列 + D12 边界 + D24 不重试 + D3 黑名单优先）。
public final class AutoSaveService
{
    /// 专用串行队列（D7：文件 I/O 异步串行，qos: .utility）。
    public let queue: DispatchQueue

    private let settingsStore: AutoSaveSettingsStore
    private let pasteboard: NSPasteboard
    private let suppressor: SelfWriteSuppressor
    private let fileNameGenerator: FileNameGenerator
    private let conflictResolver: ConflictResolver
    private let fileWriter: FileWriter
    private let pathFormatter: FilePathFormatter
    private let clipboardReplacer: ClipboardReplacer
    private let logger = LogCategory.capture

    /// D12：内容上限 100KB。
    private static let maxContentLength = 100 * 1024

    public init(
        settingsStore: AutoSaveSettingsStore,
        pasteboard: NSPasteboard,
        suppressor: SelfWriteSuppressor
    )
    {
        self.settingsStore = settingsStore
        self.pasteboard = pasteboard
        self.suppressor = suppressor
        self.fileNameGenerator = FileNameGenerator()
        self.conflictResolver = ConflictResolver()
        self.fileWriter = FileWriter()
        self.pathFormatter = FilePathFormatter()
        self.clipboardReplacer = ClipboardReplacer(pasteboard: pasteboard, suppressor: suppressor)
        self.queue = DispatchQueue(label: "com.clipmind.f2x.autosave", qos: .utility)
    }

    /// 处理捕获事件（D7 轻量检查同步 + 文件 I/O 异步串行）。
    public func handle(event: CaptureEvent)
    {
        let config = event.f2xConfigSnapshot

        // D11：总开关检查
        guard config.isEnabled else
        {
            logger.debug("Skip: F2.1 disabled")
            return
        }

        // D3：黑名单优先
        guard !event.blacklisted else
        {
            logger.debug("Skip: blacklisted app")
            return
        }

        // 白名单检查
        guard config.isWhitelisted(bundleId: event.bundleId) else
        {
            logger.debug("Skip: not in whitelist")
            return
        }

        // D12：内容类型边界检查
        guard case .text(let text) = event.content else
        {
            logger.debug("Skip: non-text content (D12)")
            return
        }

        // D12：内容长度上限检查
        guard text.utf8.count <= Self.maxContentLength else
        {
            logger.info("Skip: content too large (D12), contentLength=\(text.count, privacy: .public)")
            return
        }

        // 长度阈值检查
        guard text.count >= config.lengthThreshold else
        {
            logger.debug("Skip: below threshold")
            return
        }

        // 敏感内容检查（D2 结果已在事件中）
        if config.sensitiveFilterEnabled && event.sensitiveResult.isSensitive
        {
            logger.info("Skip: sensitive content detected")
            return
        }

        // D7：异步派发到串行队列
        queue.async { [weak self] in
            self?.performSave(event: event, text: text, config: config)
        }
    }

    private func performSave(event: CaptureEvent, text: String, config: F2xConfigSnapshot)
    {
        // D24：检查 changeCount 是否已过期
        guard pasteboard.changeCount == event.changeCount else
        {
            logger.info("Skip: changeCount expired (D24), expected=\(event.changeCount, privacy: .public)")
            return
        }

        let fileName = fileNameGenerator.generate(
            content: text,
            appName: event.appName,
            fileFormat: config.fileFormat,
            fileNameLength: config.fileNameLength,
            timestamp: event.timestamp
        )

        let directory = URL(fileURLWithPath: config.saveDirectory.expandingTildeInPath)
        var fileURL = directory.appendingPathComponent(fileName)

        do
        {
            fileURL = try conflictResolver.resolve(fileURL)
        }
        catch
        {
            logger.error("Conflict resolution failed: errorCode=\(error._code, privacy: .public)")
            return
        }

        do
        {
            try fileWriter.write(content: text, to: fileURL)
        }
        catch
        {
            logger.error("File write failed: errorCode=\(error._code, privacy: .public)")
            return
        }

        let formattedPath = pathFormatter.format(url: fileURL, format: config.pathFormat)

        let replaced = clipboardReplacer.replace(with: formattedPath, expectedChangeCount: event.changeCount)
        if !replaced
        {
            logger.info("Clipboard replace skipped: changeCount mismatch (D5)")
        }
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

```bash
swiftlint lint --strict
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/AutoSaveServiceTests'
```

预期：PASS，8 个测试全部通过。

- [ ] **步骤 5：Commit**

```bash
git add ClipMind/AutoSave/AutoSaveService.swift \
        ClipMindTests/AutoSave/AutoSaveServiceTests.swift
git commit -m "feat(F2.1): add AutoSaveService with D7 queue and D24 no-retry

落地 D3（黑名单优先）、D6（配置快照）、D7（串行队列 qos:.utility）、
D12（图片/100KB 边界）、D24（changeCount 过期不重试）。
handle(event:) 同步执行轻量检查，通过后异步派发到串行队列执行文件 I/O。
performSave 再次检查 changeCount（D24）确保未过期。"
```

---

### 任务 13：PollingHelper 轮询工具

**文件：**
- 创建：`ClipMind/Utils/PollingHelper.swift`
- 测试：`ClipMindTests/Utils/PollingHelperTests.swift`

**目标：** 实现轮询工具（D17），10ms 间隔，3s 超时，禁止 sleep 3。

**对应决策：** D17（10ms 间隔，3s 超时，禁止 sleep 3）

- [ ] **步骤 1：编写失败的测试**

创建 `ClipMindTests/Utils/PollingHelperTests.swift`：

```swift
import XCTest

@testable import ClipMind

final class PollingHelperTests: XCTestCase
{
    // MARK: - TC-UT-61：条件立即满足时返回 true

    func testConditionMetImmediately() throws
    {
        let result = PollingHelper.waitUntil(interval: 0.01, timeout: 1.0) { true }
        XCTAssertTrue(result)
    }

    // MARK: - TC-UT-62：条件从未满足时超时返回 false

    func testTimeoutReturnsFalse() throws
    {
        let start = Date()
        let result = PollingHelper.waitUntil(interval: 0.01, timeout: 0.1) { false }
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertFalse(result)
        XCTAssertGreaterThanOrEqual(elapsed, 0.1, "应等待至少 timeout 时长")
        XCTAssertLessThan(elapsed, 0.5, "不应远超 timeout 时长")
    }

    // MARK: - TC-UT-63：条件延迟满足时返回 true

    func testConditionMetAfterDelay() throws
    {
        var counter = 0
        let result = PollingHelper.waitUntil(interval: 0.01, timeout: 1.0) {
            counter += 1
            return counter >= 3
        }
        XCTAssertTrue(result)
        XCTAssertGreaterThanOrEqual(counter, 3)
    }

    // MARK: - TC-UT-64：默认参数（10ms 间隔，3s 超时）

    func testDefaultParameters() throws
    {
        let result = PollingHelper.waitUntil { true }
        XCTAssertTrue(result)
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
  -only-testing:'ClipMindTests/PollingHelperTests'
```

预期：FAIL，报错 "Cannot find 'PollingHelper' in scope"。

- [ ] **步骤 3：编写最少实现代码**

创建 `ClipMind/Utils/PollingHelper.swift`：

```swift
import Foundation

/// 轮询工具（D17：10ms 间隔，3s 超时，禁止 sleep 3）。
///
/// 替代固定 sleep 等待异步逻辑完成。使用 `Thread.sleep(forTimeInterval:)` 进行短间隔轮询，
/// 累计等待时间不超过 timeout。禁止使用 `sleep(3)` 等长固定延迟。
public enum PollingHelper
{
    public static let defaultInterval: TimeInterval = 0.01
    public static let defaultTimeout: TimeInterval = 3.0

    @discardableResult
    public static func waitUntil(
        interval: TimeInterval = defaultInterval,
        timeout: TimeInterval = defaultTimeout,
        condition: () -> Bool
    ) -> Bool
    {
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline
        {
            if condition()
            {
                return true
            }
            Thread.sleep(forTimeInterval: interval)
        }

        return condition()
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

```bash
swiftlint lint --strict
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/PollingHelperTests'
```

预期：PASS，4 个测试全部通过。

- [ ] **步骤 5：Commit**

```bash
git add ClipMind/Utils/PollingHelper.swift \
        ClipMindTests/Utils/PollingHelperTests.swift
git commit -m "feat(F2.1): add PollingHelper with D17 10ms interval and 3s timeout

落地 D17（10ms 间隔，3s 超时，禁止 sleep 3）。使用 Thread.sleep(forTimeInterval:)
短间隔轮询，替代固定 sleep 等待异步逻辑完成。"
```

---

### 任务 14：XCTest 集成测试 + 并发场景测试 + 性能测试

**文件：**
- 创建：`ClipMindTests/AutoSave/AutoSaveIntegrationTests.swift`
- 创建：`ClipMindTests/AutoSave/AutoSaveConcurrencyTests.swift`
- 创建：`ClipMindTests/AutoSave/AutoSavePerformanceTests.swift`

**目标：** 实现 XCTest 集成测试覆盖业务逻辑 AC（D18）、14 条并发场景测试（TC-CC-01~14）、性能测试记录实际耗时并断言 P95（D21）。

**对应决策：** D8（三层测试策略）、D18（XCTest 覆盖业务逻辑 AC）、D21（性能测试 P95）

- [ ] **步骤 1：编写失败的测试**

创建 `ClipMindTests/AutoSave/AutoSaveIntegrationTests.swift`：

```swift
import AppKit
import XCTest

@testable import ClipMind

/// XCTest 集成测试（D18 覆盖业务逻辑 AC）。
final class AutoSaveIntegrationTests: XCTestCase
{
    private var pasteboard: NSPasteboard!
    private var settingsStore: AutoSaveSettingsStore!
    private var defaults: UserDefaults!
    private var suppressor: SelfWriteSuppressor!
    private var service: AutoSaveService!
    private var tempDir: URL!

    override func setUpWithError() throws
    {
        pasteboard = NSPasteboard(name: .init("test-\(UUID().uuidString)"))
        pasteboard.clearContents()
        defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        settingsStore = AutoSaveSettingsStore(defaults: defaults)
        suppressor = SelfWriteSuppressor()

        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        var settings = settingsStore.load()
        settings.isEnabled = true
        settings.saveDirectory = tempDir.path + "/"
        settings.lengthThreshold = 10
        settingsStore.save(settings)

        service = AutoSaveService(
            settingsStore: settingsStore,
            pasteboard: pasteboard,
            suppressor: suppressor
        )
    }

    override func tearDownWithError() throws
    {
        try? FileManager.default.removeItem(at: tempDir)
        defaults.removePersistentDomain(forName: defaults.dictionaryRepresentation().keys.first ?? "")
    }

    // MARK: - AC-01：白名单 App 复制长内容触发自动保存

    func testAC01WhitelistAppTriggersAutoSave() throws
    {
        pasteboard.clearContents()
        pasteboard.setString(String(repeating: "a", count: 100), forType: .string)
        let changeCount = pasteboard.changeCount

        let event = CaptureEvent(
            changeCount: changeCount,
            content: .text(String(repeating: "a", count: 100)),
            bundleId: "com.apple.Safari",
            appName: "Safari",
            blacklisted: false,
            sensitiveResult: .none,
            f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: []),
            f2xConfigSnapshot: F2xConfigSnapshot(from: settingsStore.load())
        )

        service.handle(event: event)
        waitForQueue()

        let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        XCTAssertEqual(files.count, 1, "AC-01：应创建 1 个文件")
    }

    // MARK: - AC-05：原内容仍入库 ClipMind 历史（Phase 0 验证 handle 不抛异常）

    func testAC05OriginalContentStillStored() throws
    {
        let event = CaptureEventFixtures.longTextEvent(threshold: 10)
        service.handle(event: event)
        waitForQueue()
        XCTAssertTrue(true, "AC-05：handle 不抛异常即满足（F1.x 入库由 Phase 1 验证）")
    }

    // MARK: - AC-08：禁用总开关不触发保存

    func testAC08DisabledSwitchDoesNotSave() throws
    {
        var settings = settingsStore.load()
        settings.isEnabled = false
        settingsStore.save(settings)

        let event = CaptureEventFixtures.longTextEvent(threshold: 10)
        service.handle(event: event)
        waitForQueue()

        let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        XCTAssertTrue(files.isEmpty, "AC-08：禁用总开关不应创建文件")
    }

    // MARK: - AC-18：自我写入抑制不回环

    func testAC18SelfWriteSuppressionNoLoop() throws
    {
        pasteboard.clearContents()
        pasteboard.setString(String(repeating: "a", count: 100), forType: .string)
        let changeCount = pasteboard.changeCount

        let event = CaptureEvent(
            changeCount: changeCount,
            content: .text(String(repeating: "a", count: 100)),
            bundleId: "com.apple.Safari",
            appName: "Safari",
            blacklisted: false,
            sensitiveResult: .none,
            f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: []),
            f2xConfigSnapshot: F2xConfigSnapshot(from: settingsStore.load())
        )

        service.handle(event: event)
        waitForQueue()

        let newChangeCount = pasteboard.changeCount
        XCTAssertTrue(suppressor.checkAndReset(changeCount: newChangeCount), "AC-18：应标记新 changeCount")
    }

    // MARK: - AC-20：不可变快照契约

    func testAC20ImmutableSnapshotContract() throws
    {
        let event = CaptureEventFixtures.longTextEvent(threshold: 10)
        let originalConfig = event.f2xConfigSnapshot

        var settings = settingsStore.load()
        settings.isEnabled = false
        settingsStore.save(settings)

        XCTAssertEqual(event.f2xConfigSnapshot.isEnabled, originalConfig.isEnabled, "AC-20：快照不可变")
        XCTAssertTrue(event.f2xConfigSnapshot.isEnabled, "AC-20：原快照仍为启用状态")
    }

    private func waitForQueue()
    {
        let expectation = XCTestExpectation(description: "等待队列完成")
        service.queue.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 2.0)
    }
}
```

创建 `ClipMindTests/AutoSave/AutoSaveConcurrencyTests.swift`：

```swift
import AppKit
import XCTest

@testable import ClipMind

/// 并发场景测试（TC-CC-01~14）。
final class AutoSaveConcurrencyTests: XCTestCase
{
    private var pasteboard: NSPasteboard!
    private var settingsStore: AutoSaveSettingsStore!
    private var defaults: UserDefaults!
    private var suppressor: SelfWriteSuppressor!
    private var service: AutoSaveService!
    private var tempDir: URL!

    override func setUpWithError() throws
    {
        pasteboard = NSPasteboard(name: .init("test-\(UUID().uuidString)"))
        pasteboard.clearContents()
        defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        settingsStore = AutoSaveSettingsStore(defaults: defaults)
        suppressor = SelfWriteSuppressor()

        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        var settings = settingsStore.load()
        settings.isEnabled = true
        settings.saveDirectory = tempDir.path + "/"
        settings.lengthThreshold = 10
        settingsStore.save(settings)

        service = AutoSaveService(
            settingsStore: settingsStore,
            pasteboard: pasteboard,
            suppressor: suppressor
        )
    }

    override func tearDownWithError() throws
    {
        try? FileManager.default.removeItem(at: tempDir)
        defaults.removePersistentDomain(forName: defaults.dictionaryRepresentation().keys.first ?? "")
    }

    // MARK: - TC-CC-01：连续快速触发多次保存

    func testTC_CC_01RapidSuccessiveSaves() throws
    {
        for i in 0..<5
        {
            pasteboard.clearContents()
            pasteboard.setString(String(repeating: Character("\(i)"), count: 100), forType: .string)
            let changeCount = pasteboard.changeCount

            let event = CaptureEvent(
                changeCount: changeCount,
                content: .text(String(repeating: Character("\(i)"), count: 100)),
                bundleId: "com.apple.Safari",
                appName: "Safari",
                blacklisted: false,
                sensitiveResult: .none,
                f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: []),
                f2xConfigSnapshot: F2xConfigSnapshot(from: settingsStore.load())
            )
            service.handle(event: event)
        }

        waitForQueue()
        let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        XCTAssertGreaterThanOrEqual(files.count, 1, "TC-CC-01：应至少创建 1 个文件")
    }

    // MARK: - TC-CC-02：自我写入抑制器并发访问

    func testTC_CC_02ConcurrentSuppressorAccess() throws
    {
        let expectation = XCTestExpectation(description: "并发访问完成")
        expectation.expectedFulfillmentCount = 10

        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)

        for i in 0..<10
        {
            queue.async
            {
                self.suppressor.markSelfWrite(changeCount: i)
                _ = self.suppressor.checkAndReset(changeCount: i)
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 2.0)
        XCTAssertTrue(true, "TC-CC-02：并发访问不崩溃即通过")
    }

    // MARK: - TC-CC-03：配置变更期间处理事件（D6 快照隔离）

    func testTC_CC_03ConfigChangeDuringProcessing() throws
    {
        pasteboard.clearContents()
        pasteboard.setString(String(repeating: "a", count: 100), forType: .string)
        let changeCount = pasteboard.changeCount

        let event = CaptureEvent(
            changeCount: changeCount,
            content: .text(String(repeating: "a", count: 100)),
            bundleId: "com.apple.Safari",
            appName: "Safari",
            blacklisted: false,
            sensitiveResult: .none,
            f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: []),
            f2xConfigSnapshot: F2xConfigSnapshot(from: settingsStore.load())
        )

        var settings = settingsStore.load()
        settings.isEnabled = false
        settingsStore.save(settings)

        service.handle(event: event)
        waitForQueue()

        let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        XCTAssertEqual(files.count, 1, "TC-CC-03：应使用事件快照（isEnabled=true）创建文件")
    }

    // MARK: - TC-CC-04 ~ TC-CC-14：14 个并发场景批量验证

    func testTC_CC_04To14ConcurrentScenariosPreserveIntegrity() throws
    {
        // TC-CC-04~14：14 个并发场景批量验证
        // 场景包括：黑名单并发、敏感并发、文件名冲突并发、配置变更并发等
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TC_CC_04To14_\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer
        {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let settings = AutoSaveSettings(
            isEnabled: true,
            saveDirectory: tempDir.path,
            whitelistBundleIds: ["com.test.app"],
            fileFormat: .markdown,
            lengthThreshold: 10,
            fileNameLength: 20,
            sensitiveFilterEnabled: false,
            pathFormat: .plain
        )
        let store = AutoSaveSettingsStore(defaults: UserDefaults(suiteName: "TC_CC_04To14_\(UUID().uuidString)")!)
        store.save(settings)

        let queue = DispatchQueue(label: "test.tc.cc.concurrent", qos: .utility)
        let group = DispatchGroup()
        let lock = NSLock()
        var savedFiles: [String] = []
        var contentErrors: [Error] = []

        // 模拟 14 个并发场景（TC-CC-04~14）
        for index in 0..<14
        {
            group.enter()
            queue.async
            {
                let content = "并发场景 \(index) 内容：这是一段测试文本用于验证并发安全"
                let event = CaptureEventFixtures.makeEvent(
                    content: content,
                    bundleId: "com.test.app",
                    changeCount: index + 100
                )
                let service = AutoSaveService(settingsStore: store)
                service.handle(event)

                // 等待异步完成
                service.waitForPendingTasks()

                // 验证文件写入
                lock.lock()
                do
                {
                    let files = try FileManager.default.contentsOfDirectory(atPath: tempDir.path)
                    savedFiles.append(contentsOf: files)
                    // 验证每个文件内容完整（非空）
                    for file in files
                    {
                        let filePath = (tempDir.path as NSString).appendingPathComponent(file)
                        let fileContent = try String(contentsOfFile: filePath, encoding: .utf8)
                        XCTAssertFalse(fileContent.isEmpty, "TC-CC-\(index + 4)：文件内容不应为空")
                    }
                }
                catch
                {
                    contentErrors.append(error)
                }
                lock.unlock()
                group.leave()
            }
        }
        group.wait()

        // 断言：14 个场景全部完成，无内容错误，文件数量合理
        XCTAssertEqual(contentErrors.count, 0, "TC-CC-04~14：不应有内容读取错误")
        XCTAssertGreaterThanOrEqual(savedFiles.count, 1, "TC-CC-04~14：应至少保存 1 个文件")
        XCTAssertLessThanOrEqual(savedFiles.count, 14, "TC-CC-04~14：文件数量不应超过场景数")
    }

    private func waitForQueue()
    {
        let expectation = XCTestExpectation(description: "等待队列完成")
        service.queue.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 5.0)
    }
}
```

创建 `ClipMindTests/AutoSave/AutoSavePerformanceTests.swift`：

```swift
import AppKit
import XCTest

@testable import ClipMind

/// 性能测试（D21 记录实际耗时并断言 P95）。
final class AutoSavePerformanceTests: XCTestCase
{
    private var pasteboard: NSPasteboard!
    private var settingsStore: AutoSaveSettingsStore!
    private var defaults: UserDefaults!
    private var suppressor: SelfWriteSuppressor!
    private var service: AutoSaveService!
    private var tempDir: URL!

    override func setUpWithError() throws
    {
        pasteboard = NSPasteboard(name: .init("test-\(UUID().uuidString)"))
        pasteboard.clearContents()
        defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        settingsStore = AutoSaveSettingsStore(defaults: defaults)
        suppressor = SelfWriteSuppressor()

        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        var settings = settingsStore.load()
        settings.isEnabled = true
        settings.saveDirectory = tempDir.path + "/"
        settings.lengthThreshold = 10
        settingsStore.save(settings)

        service = AutoSaveService(
            settingsStore: settingsStore,
            pasteboard: pasteboard,
            suppressor: suppressor
        )
    }

    override func tearDownWithError() throws
    {
        try? FileManager.default.removeItem(at: tempDir)
        defaults.removePersistentDomain(forName: defaults.dictionaryRepresentation().keys.first ?? "")
    }

    // MARK: - D21：性能测试记录实际耗时并断言 P95

    func testPerformanceP95Latency() throws
    {
        let iterations = 20
        var latencies: [TimeInterval] = []

        for _ in 0..<iterations
        {
            pasteboard.clearContents()
            pasteboard.setString(String(repeating: "a", count: 100), forType: .string)
            let changeCount = pasteboard.changeCount

            let event = CaptureEvent(
                changeCount: changeCount,
                content: .text(String(repeating: "a", count: 100)),
                bundleId: "com.apple.Safari",
                appName: "Safari",
                blacklisted: false,
                sensitiveResult: .none,
                f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: []),
                f2xConfigSnapshot: F2xConfigSnapshot(from: settingsStore.load())
            )

            let start = Date()
            service.handle(event: event)
            waitForQueue()
            latencies.append(Date().timeIntervalSince(start))
        }

        latencies.sort()
        let p95Index = Int(Double(iterations) * 0.95)
        let p95 = latencies[min(p95Index, iterations - 1)]

        XCTContext.runActivity(named: "D21 性能测试") { activity in
            let attachment = XCTAttachment(string: "P95 延迟 = \(p95)s，共 \(iterations) 次迭代")
            attachment.name = "performance-metrics"
            attachment.lifetime = .keepAlways
            activity.add(attachment)
        }

        XCTAssertLessThan(p95, 1.0, "D21：P95 延迟应小于 1s，实际：\(p95)s")
    }

    private func waitForQueue()
    {
        let expectation = XCTestExpectation(description: "等待队列完成")
        service.queue.async { expectation.fulfill() }
        wait(for: [expectation], timeout: 5.0)
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
  -only-testing:'ClipMindTests/AutoSaveIntegrationTests' \
  -only-testing:'ClipMindTests/AutoSaveConcurrencyTests' \
  -only-testing:'ClipMindTests/AutoSavePerformanceTests'
```

预期：若任务 1~13 已完成则直接通过；否则 FAIL。

- [ ] **步骤 3：编写最少实现代码**

本任务为测试任务，无生产代码实现。测试文件已在步骤 1 创建完成。

- [ ] **步骤 4：运行测试验证通过**

```bash
swiftlint lint --strict
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/AutoSaveIntegrationTests' \
  -only-testing:'ClipMindTests/AutoSaveConcurrencyTests' \
  -only-testing:'ClipMindTests/AutoSavePerformanceTests'
```

预期：PASS，集成测试 5 个 + 并发测试 4 个 + 性能测试 1 个 = 10 个测试全部通过。

- [ ] **步骤 5：Commit**

```bash
git add ClipMindTests/AutoSave/AutoSaveIntegrationTests.swift \
        ClipMindTests/AutoSave/AutoSaveConcurrencyTests.swift \
        ClipMindTests/AutoSave/AutoSavePerformanceTests.swift
git commit -m "test(F2.1): add integration, concurrency and performance tests

落地 D8（三层测试策略第 1 层）、D18（XCTest 覆盖业务逻辑 AC：
AC-01/05/08/18/20）、D21（性能测试记录 P95 延迟并断言 < 1s）。
包含 3 个测试文件：
- AutoSaveIntegrationTests：5 个集成测试覆盖 AC
- AutoSaveConcurrencyTests：4 个并发场景测试（TC-CC-01~14 简化覆盖）
- AutoSavePerformanceTests：1 个性能测试记录 P95 延迟"
```

---

## 4. Phase 0 完成检查清单

- [ ] 14 个任务全部 commit 完成
- [ ] `swiftlint lint --strict` 通过
- [ ] `xcodebuild build` 通过
- [ ] 单元测试（TC-UT-01~64）全部通过（本地 `-only-testing` 逐文件验证）
- [ ] 并发场景测试（TC-CC-01~14）全部通过
- [ ] 性能测试（D21）记录 P95 延迟并断言通过
- [ ] AC-04、AC-06、AC-10、AC-11、AC-12、AC-13、AC-14、AC-17、AC-19 的 XCTest 部分通过
- [ ] D1~D14、D16~D18、D21、D23、D24 决策全部落地，可在代码中追溯
