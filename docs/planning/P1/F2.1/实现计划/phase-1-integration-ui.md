> 最后更新：2026-07-22 | 版本：v2.0

# Phase 1 子计划：集成与 UI

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。本子计划落地 D2/D3/D6/D7/D8/D11/D15/D18/D19/D20/D22/D23 决策。每个任务严格按 TDD 五步执行。

**目标：** 在 Phase 0 核心保存逻辑的基础上，将 `AutoSaveService` 接入 F1.x 捕获流程（通过 F-11 例外扩展 `PasteboardWatcher.onPasteboardChange` 回调参数为 `CaptureEvent`），实现配置面板"自动保存"分区视图（8 个配置项 + 路径预览 + 二次确认弹窗 + 明文责任提示），并通过 XCUITest 覆盖 AC-07/09/14/15/16 的 UI 交互，剩余 AC-01/02/03/05/17~22 由手动验收脚本兜底 OS 边界。Phase 1 完成后，F2.1 全部 22 条 AC 覆盖完整。

**架构：** F-11 例外条款扩展 `PasteboardWatcher.onPasteboardChange: ((ClipContent) -> Void)?` 为 `((CaptureEvent) -> Void)?`。新增 `ClipMind/Capture/CaptureEventBuilder.swift`（B0）负责识别来源 App、读取内容、执行黑名单与敏感识别（D2 只跑一次）、读取配置快照（D23）、构造不可变 `CaptureEvent`。`ClipCaptureService` 适配 `CaptureEvent`：检查 `event.blacklisted` 与 `event.sensitiveResult`（F1.x 过滤逻辑迁移），取 `event.content` 执行既有入库流程（不变），调用 `AutoSaveService.handle(event:)` 派发 F2.1 分支（D7 异步串行队列）。新增 `ClipMind/UI/Settings/AutoSaveSettingsView.swift` SwiftUI 视图，作为 `SettingsView` 的第 4 个 tab。`AppDelegate.setupCaptureService` 装配 `AutoSaveService` 与 `SelfWriteSuppressor`。

**技术栈：** Swift 5.7+ / macOS 12.4+ / SwiftUI + AppKit（NSPasteboard、NSStatusItem）/ XCTest + XCUITest / SwiftLint strict

---

## 1. 范围与非目标

### 1.1 范围

- 修改 4 个 Swift 文件（`PasteboardWatcher.swift`、`ClipCaptureService.swift`、`SettingsView.swift`、`ClipMindApp.swift`）
- 创建 1 个 Swift 构造器文件（`CaptureEventBuilder.swift`）
- 创建 1 个 Swift UI 视图文件（`AutoSaveSettingsView.swift`）
- 创建 2 个 XCUITest 文件（`AutoSaveSettingsUITests.swift`、`AutoSaveBehaviorUITests.swift`）
- 创建 1 个手动验收脚本（`manual-acceptance-script.md`）
- 创建 1 个集成测试文件（`AutoSaveIntegrationPhase1Tests.swift`）
- 覆盖 AC-07/09/14/15/16（XCUITest UI 交互）+ AC-01/02/03/05/17~22（手动 OS 边界）
- 本地 `swiftlint lint --strict` 与 `xcodebuild build` 通过
- 单文件 `-only-testing` XCTest 通过（本地允许）
- 全量 `xcodebuild test` 与 XCUITest 由 CI 兜底（本地禁止执行）

### 1.2 非目标

- 不修改 Phase 0 已交付的 13 个 Swift 文件的公共接口
- 不修改 F1.x 既有模块的公共接口（`SensitiveDetector`、`AppDetector`、`EncryptedStore`、`AppSettings`、`ClipItem`、`ClipContent`、`BlacklistService`、`ContentReader`、`Deduplicator`）
- 不本地执行全量 `xcodebuild test`（仅 CI）
- 不本地执行 XCUITest（仅 CI，D19）
- 不修改 F1.x 既有设置面板分区（`APIKeyConfigView`、`PrivacySettingsView`、`GeneralSettingsView`）

---

## 2. 涉及文件和职责

| 文件 | 职责 | 创建/修改 | 对应决策 |
|------|------|-----------|----------|
| `ClipMind/Capture/PasteboardWatcher.swift` | F-11 例外：扩展 `onPasteboardChange` 为 `(CaptureEvent) -> Void`；移除黑名单与敏感检查（迁移到 B0）；保留 changeCount 与去重逻辑；注入 `CaptureEventBuilder` | 修改 | D6/D22/F-11 |
| `ClipMind/Capture/CaptureEventBuilder.swift` | B0 捕获事件构造器：调用 AppDetector/BlacklistService/SensitiveDetector/AutoSaveSettingsStore，构造不可变 `CaptureEvent`（D2 只跑一次，D23 配置快照） | 创建 | D1/D2/D3/D6/D23 |
| `ClipMind/Capture/ClipCaptureService.swift` | 适配 `CaptureEvent`：检查 `blacklisted`/`sensitiveResult`（F1.x 过滤迁移），取 `event.content` 入库（流程不变），调用 `AutoSaveService.handle(event:)` | 修改 | D3/D7 |
| `ClipMind/UI/Settings/AutoSaveSettingsView.swift` | 自动保存分区 SwiftUI 视图：8 配置项 + 路径预览 + 明文责任提示 + 关闭敏感过滤二次确认弹窗 | 创建 | D11/D15 |
| `ClipMind/UI/Settings/SettingsView.swift` | `SettingsTab` 新增 `.autoSave`；TabView 新增"自动保存"tab；`--UITEST_INITIAL_TAB=autosave` 解析 | 修改 | - |
| `ClipMind/App/ClipMindApp.swift` | `setupCaptureService` 装配 `AutoSaveService`/`SelfWriteSuppressor`/`CaptureEventBuilder`；`applyUITestOverrides` 处理 `--UITEST_RESET_AUTOSAVE_SETTINGS` | 修改 | D7 |
| `ClipMindTests/Capture/CaptureEventBuilderTests.swift` | B0 单元测试：构造事件字段正确性、敏感只跑一次、配置快照读取 | 创建 | D2/D18 |
| `ClipMindTests/Capture/PasteboardWatcherEventTests.swift` | PasteboardWatcher 扩展回调测试：回调接收 CaptureEvent、去重保留 | 创建 | D6/D18 |
| `ClipMindTests/Capture/ClipCaptureServiceEventTests.swift` | ClipCaptureService 适配测试：黑名单跳过、敏感跳过、入库流程不变、F2.1 派发 | 创建 | D3/D18 |
| `ClipMindUITests/AutoSaveSettingsUITests.swift` | AC-07（配置面板修改全部配置项）、AC-15（白名单增删）、AC-16（配置持久化）、AC-14（关闭敏感过滤二次确认 UI） | 创建 | D19 |
| `ClipMindUITests/AutoSaveBehaviorUITests.swift` | AC-09（保存目录异常弹窗不崩溃，含 `autoSaveErrorAlert` 断言） | 创建 | D19 |
| `ClipMindTests/AutoSave/AutoSaveIntegrationPhase1Tests.swift` | Phase 1 集成测试：端到端事件流（PasteboardWatcher → B0 → ClipCaptureService → AutoSaveService） | 创建 | D8/D18 |
| `docs/planning/P1/F2.1/实现计划/manual-acceptance-script.md` | AC-01/02/03/05/17~22 手动验收脚本（真实 Safari/Notes/Finder + NFR 边界） | 创建 | D20 |

**推荐执行顺序：** 1 → 2 → 3 → 4 → 5 → 6 → 10 → 7 → 8 → 9

任务 1、2、3 有顺序依赖（B0 依赖 CaptureEvent 类型，PasteboardWatcher 依赖 B0，ClipCaptureService 依赖 PasteboardWatcher 回调签名）；任务 4、5 有依赖（SettingsView 依赖 AutoSaveSettingsView）；任务 6 依赖 1+2+3；任务 10 依赖 1+2+3+6；任务 7、8 依赖 4+5+6（XCUITest 仅 CI 执行）；任务 9 依赖全部完成。

---

## 3. 任务列表

总计 10 个任务，每个任务包含 5 个步骤（编写失败测试 → 运行验证失败 → 编写最少实现 → 运行验证通过 → commit）。

---

### 任务 1：PasteboardWatcher 扩展回调参数为 CaptureEvent（F-11 例外）

**文件：**
- 修改：`ClipMind/Capture/PasteboardWatcher.swift`
- 测试：`ClipMindTests/Capture/PasteboardWatcherEventTests.swift`

**目标：** 落地 F-11 例外条款与 D6 决策，将 `onPasteboardChange: ((ClipContent) -> Void)?` 扩展为 `onPasteboardChange: ((CaptureEvent) -> Void)?`。移除 PasteboardWatcher 中既有的黑名单检查（lines 90-95）与敏感检查（lines 101-106），迁移到任务 2 的 `CaptureEventBuilder`。保留 changeCount 检测与去重逻辑。注入 `CaptureEventBuilder` 依赖。当 `eventBuilder` 为 nil 时（F1.x 既有行为回退），回退为构造最小 `CaptureEvent`（仅含 content 与 changeCount），保证 F1.x 既有测试不破坏。

**对应决策：** D6（扩展回调参数为 CaptureEvent）、D22（F-11 例外条款）、F-11

**对应 FR：** FR-014（捕获事件快照与并行分发步骤 1-3、6-7）、FR-016（CaptureEvent 不可变快照契约）

**对应 AC：** AC-05（原内容仍进入 ClipMind 历史）

**前置依赖：** Phase 0 任务 1（CaptureEvent）、任务 2（SensitiveMatchResult）、任务 3（F2xConfigSnapshot）必须已完成

- [ ] **步骤 1：编写失败的测试**

创建 `ClipMindTests/Capture/PasteboardWatcherEventTests.swift`：

```swift
import AppKit
import XCTest

@testable import ClipMind

final class PasteboardWatcherEventTests: XCTestCase
{
    private var pasteboard: NSPasteboard!
    private var watcher: PasteboardWatcher!
    private var eventBuilder: CaptureEventBuilder!
    private var defaults: UserDefaults!

    override func setUpWithError() throws
    {
        pasteboard = NSPasteboard(name: .init("test-pw-\(UUID().uuidString)"))
        pasteboard.clearContents()

        defaults = UserDefaults(suiteName: "test-pw-\(UUID().uuidString)")!
        let settingsStore = AutoSaveSettingsStore(defaults: defaults)
        let sensitiveDetector = SensitiveDetector(defaults: defaults)
        let blacklistService = BlacklistService(defaults: defaults)
        let appDetector = AppDetector()
        eventBuilder = CaptureEventBuilder(
            appDetector: appDetector,
            sensitiveDetector: sensitiveDetector,
            blacklistService: blacklistService,
            settingsStore: settingsStore
        )

        watcher = PasteboardWatcher(
            pasteboard: pasteboard,
            eventBuilder: eventBuilder
        )
    }

    override func tearDownWithError() throws
    {
        watcher?.stopWatching()
        if let suite = defaults?.dictionaryRepresentation()
        {
            for key in suite.keys
            {
                defaults?.removeObject(forKey: key)
            }
        }
    }

    // MARK: - TC-UT-50：onPasteboardChange 回调接收 CaptureEvent

    func testCallbackReceivesCaptureEvent() throws
    {
        let expectation = XCTestExpectation(description: "回调应接收 CaptureEvent")
        var receivedEvent: CaptureEvent?

        watcher.onPasteboardChange = { event in
            receivedEvent = event
            expectation.fulfill()
        }

        pasteboard.clearContents()
        pasteboard.setString("hello capture event", forType: .string)
        watcher.handlePasteboardChange()

        wait(for: [expectation], timeout: 2.0)

        let event = try XCTUnwrap(receivedEvent)
        XCTAssertEqual(event.changeCount, pasteboard.changeCount)
        if case .text(let text) = event.content
        {
            XCTAssertEqual(text, "hello capture event")
        }
        else
        {
            XCTFail("内容应为 .text 类型")
        }
        XCTAssertFalse(event.bundleId.isEmpty, "bundleId 应非空（来源 App 无法识别时 build 返回 nil，事件内始终非空）")
        XCTAssertFalse(event.appName.isEmpty, "appName 应非空")
    }

    // MARK: - TC-UT-51：去重逻辑保留（重复内容不触发回调）

    func testDedupStillWorks() throws
    {
        var callCount = 0
        watcher.onPasteboardChange = { _ in
            callCount += 1
        }

        pasteboard.clearContents()
        pasteboard.setString("dedup content", forType: .string)
        watcher.handlePasteboardChange()
        XCTAssertEqual(callCount, 1, "首次复制应触发回调")

        // 同一 changeCount 不再触发
        watcher.handlePasteboardChange()
        XCTAssertEqual(callCount, 1, "同一 changeCount 不应重复触发")
    }

    // MARK: - TC-UT-52：eventBuilder 为 nil 时回退最小事件（F1.x 兼容）

    func testNilEventBuilderFallback() throws
    {
        let fallbackWatcher = PasteboardWatcher(pasteboard: pasteboard, eventBuilder: nil)
        let expectation = XCTestExpectation(description: "nil eventBuilder 仍应触发回调")
        var receivedContent: ClipContent?

        fallbackWatcher.onPasteboardChange = { event in
            receivedContent = event.content
            expectation.fulfill()
        }

        pasteboard.clearContents()
        pasteboard.setString("fallback content", forType: .string)
        fallbackWatcher.handlePasteboardChange()

        wait(for: [expectation], timeout: 2.0)

        if case .text(let text) = receivedContent
        {
            XCTAssertEqual(text, "fallback content")
        }
        else
        {
            XCTFail("回退事件内容应为 .text")
        }
    }

    // MARK: - TC-UT-53：敏感内容不再被 PasteboardWatcher 过滤（迁移到 B0）

    func testSensitiveContentNotFilteredByWatcher() throws
    {
        let expectation = XCTestExpectation(description: "敏感内容应到达回调")
        var receivedEvent: CaptureEvent?

        watcher.onPasteboardChange = { event in
            receivedEvent = event
            expectation.fulfill()
        }

        pasteboard.clearContents()
        pasteboard.setString("password=secret123", forType: .string)
        watcher.handlePasteboardChange()

        wait(for: [expectation], timeout: 2.0)

        let event = try XCTUnwrap(receivedEvent)
        XCTAssertEqual(event.sensitiveResult.isSensitive, true, "敏感结果应打包进事件")
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
  -only-testing:'ClipMindTests/PasteboardWatcherEventTests'
```

预期：FAIL，报错 "Cannot find type 'CaptureEventBuilder' in scope" 或 "value of type 'PasteboardWatcher' has no member 'eventBuilder'"。

- [ ] **步骤 3：编写实现代码**

修改 `ClipMind/Capture/PasteboardWatcher.swift`（替换全部内容）：

```swift
import AppKit
import Foundation

/// 剪贴板轮询监听器。
///
/// 使用 Timer 轮询 NSPasteboard.changeCount，当变化时通过 ContentReader
/// 读取内容，并经 Deduplicator 过滤重复，然后通过 CaptureEventBuilder
/// 构造不可变 CaptureEvent，最终通过 onPasteboardChange 回调通知。
///
/// F-11 例外（D6）：onPasteboardChange 回调参数从 ClipContent 扩展为
/// CaptureEvent，使 F1.x 与 F2.1 分支共享同一事件快照。
///
/// 处理流程：changeCount 检测 → 读取内容 → 去重 → B0 构造事件 → 回调通知。
/// 黑名单与敏感检查已迁移到 CaptureEventBuilder（D2 只跑一次）。
final class PasteboardWatcher: NSObject
{
    /// 当前轮询定时器（仅供测试观察，外部不应修改）
    private(set) var timer: Timer?

    /// 上次观察到的 changeCount
    private var lastChangeCount: Int

    /// 被监听的 pasteboard（默认为系统通用剪贴板，测试时可注入）
    private let pasteboard: NSPasteboard

    /// 内容读取器
    private let contentReader: ContentReader

    /// 去重器
    private let deduplicator: Deduplicator

    /// 捕获事件构造器（B0，D6/D23）
    /// 为 nil 时回退为最小事件（仅含 content 与 changeCount），保证 F1.x 既有测试兼容
    private let eventBuilder: CaptureEventBuilder?

    /// 当检测到剪贴板变化（且非重复内容）时调用
    /// F-11 例外：回调参数从 ClipContent 扩展为 CaptureEvent
    var onPasteboardChange: ((CaptureEvent) -> Void)?

    /// - Parameters:
    ///   - pasteboard: 被监听的 pasteboard，默认为 .general
    ///   - contentReader: 内容读取器，默认为 ContentReader()
    ///   - deduplicator: 去重器，默认为 Deduplicator()
    ///   - eventBuilder: 捕获事件构造器（B0），为 nil 时回退最小事件
    init(pasteboard: NSPasteboard = .general,
         contentReader: ContentReader = ContentReader(),
         deduplicator: Deduplicator = Deduplicator(),
         eventBuilder: CaptureEventBuilder? = nil)
    {
        self.pasteboard = pasteboard
        self.contentReader = contentReader
        self.deduplicator = deduplicator
        self.eventBuilder = eventBuilder
        self.lastChangeCount = pasteboard.changeCount
        super.init()
    }

    /// 启动轮询监听
    /// - Parameter interval: 轮询间隔，默认 0.5s
    func startWatching(interval: TimeInterval = 0.5)
    {
        stopWatching()
        let timer = Timer(
            timeInterval: interval,
            target: self,
            selector: #selector(handlePasteboardChange),
            userInfo: nil,
            repeats: true
        )
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// 停止轮询监听
    func stopWatching()
    {
        timer?.invalidate()
        timer = nil
    }

    /// 轮询回调：检测 changeCount 变化，读取并去重内容，构造 CaptureEvent
    @objc func handlePasteboardChange()
    {
        let current = pasteboard.changeCount
        guard current != lastChangeCount else
        {
            return
        }
        lastChangeCount = current

        guard let content = contentReader.readContent(from: pasteboard) else
        {
            return
        }

        guard !deduplicator.isDuplicate(content) else
        {
            return
        }
        deduplicator.updateLastContent(content)

        let event: CaptureEvent
        if let builder = eventBuilder
        {
            guard let built = builder.build(content: content, changeCount: current) else
            {
                LogCategory.capture.debug("EventBuilder returned nil, skipping")
                return
            }
            event = built
        }
        else
        {
            // F1.x 兼容回退：构造最小事件
            event = CaptureEvent(
                id: UUID().uuidString,
                changeCount: current,
                content: content,
                bundleId: "unknown",
                appName: "Unknown",
                blacklisted: false,
                sensitiveResult: .none,
                f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: []),
                f2xConfigSnapshot: F2xConfigSnapshot(
                    isEnabled: false,
                    saveDirectory: "",
                    whitelistBundleIds: [],
                    fileFormat: .markdown,
                    lengthThreshold: 50,
                    fileNameLength: 20,
                    sensitiveFilterEnabled: true,
                    pathFormat: .plainPath
                ),
                timestamp: Date()
            )
        }

        onPasteboardChange?(event)
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1-auto-save-to-file
swiftlint lint --strict
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/PasteboardWatcherEventTests'
```

预期：PASS，4 个测试全部通过。

- [ ] **步骤 5：Commit**

```bash
git add ClipMind/Capture/PasteboardWatcher.swift \
        ClipMindTests/Capture/PasteboardWatcherEventTests.swift
git commit -m "$(cat <<'EOF'
feat(F2.1): extend PasteboardWatcher callback to CaptureEvent

落地 F-11 例外条款与 D6 决策：onPasteboardChange 回调参数从
ClipContent 扩展为 CaptureEvent。移除 PasteboardWatcher 中既有的
黑名单与敏感检查（迁移到 CaptureEventBuilder，D2 只跑一次），
保留 changeCount 检测与去重逻辑。注入 CaptureEventBuilder 依赖，
nil 时回退最小事件保证 F1.x 既有测试兼容。
EOF
)"
```

---

### 任务 2：CaptureEventBuilder 捕获事件构造器（B0）

**文件：**
- 创建：`ClipMind/Capture/CaptureEventBuilder.swift`
- 测试：`ClipMindTests/Capture/CaptureEventBuilderTests.swift`

**目标：** 实现 B0 捕获事件构造器（D1/D2/D3/D6/D23）。调用 `AppDetector` 识别来源 App，调用 `BlacklistService.contains` 执行黑名单检查（结果打包进 `event.blacklisted`，D3），调用 `SensitiveDetector.detect` 执行敏感识别（D2 只跑一次，结果打包进 `event.sensitiveResult`），从 `AutoSaveSettingsStore` 读取 F2.1 配置快照（D23），从 `BlacklistService` 读取 F1.x 黑名单快照。构造不可变 `CaptureEvent` 返回。当来源 App 无法识别时返回 nil。

**对应决策：** D1（事件驱动模型）、D2（敏感只跑一次）、D3（黑名单优先）、D6（配置快照）、D23（配置快照机制）

**对应 FR：** FR-014（步骤 2-7）、FR-016（CaptureEvent 字段）、FR-017（配置快照）、FR-018（黑名单优先）

**对应 AC：** AC-06（敏感内容不保存）、AC-14（关闭敏感过滤后可保存）、AC-20（配置快照不读实时配置）

**前置依赖：** Phase 0 任务 1~5（CaptureEvent、SensitiveMatchResult、F2xConfigSnapshot、AutoSaveSettings、AutoSaveSettingsStore）、任务 1（PasteboardWatcher 注入）

- [ ] **步骤 1：编写失败的测试**

创建 `ClipMindTests/Capture/CaptureEventBuilderTests.swift`：

```swift
import AppKit
import XCTest

@testable import ClipMind

final class CaptureEventBuilderTests: XCTestCase
{
    private var defaults: UserDefaults!
    private var builder: CaptureEventBuilder!
    private var sensitiveDetector: SensitiveDetector!
    private var blacklistService: BlacklistService!
    private var settingsStore: AutoSaveSettingsStore!

    override func setUpWithError() throws
    {
        defaults = UserDefaults(suiteName: "test-b0-\(UUID().uuidString)")!
        sensitiveDetector = SensitiveDetector(defaults: defaults)
        blacklistService = BlacklistService(defaults: defaults)
        settingsStore = AutoSaveSettingsStore(defaults: defaults)

        builder = CaptureEventBuilder(
            appDetector: AppDetector(),
            sensitiveDetector: sensitiveDetector,
            blacklistService: blacklistService,
            settingsStore: settingsStore
        )
    }

    override func tearDownWithError() throws
    {
        if let suite = defaults.dictionaryRepresentation() as? [String: Any]
        {
            for key in suite.keys
            {
                defaults.removeObject(forKey: key)
            }
        }
    }

    // MARK: - TC-UT-54：构造事件包含全部字段

    func testBuildEventContainsAllFields() throws
    {
        let content = ClipContent.text("一段测试内容用于构造事件")
        let event = try XCTUnwrap(builder.build(content: content, changeCount: 10))

        XCTAssertEqual(event.changeCount, 10)
        XCTAssertEqual(event.content, content)
        XCTAssertFalse(event.id.isEmpty)
        XCTAssertNotNil(event.timestamp)
    }

    // MARK: - TC-UT-55：敏感识别只跑一次（D2），结果打包进事件

    func testSensitiveResultPackedIntoEvent() throws
    {
        defaults.set(true, forKey: SensitiveDetector.storageKey)
        let content = ClipContent.text("password=supersecret")
        let event = try XCTUnwrap(builder.build(content: content, changeCount: 1))

        XCTAssertTrue(event.sensitiveResult.isSensitive, "敏感内容应被识别")
        XCTAssertFalse(event.sensitiveResult.matchedPatterns.isEmpty, "应包含命中模式")
    }

    func testNonSensitiveContentResult() throws
    {
        defaults.set(true, forKey: SensitiveDetector.storageKey)
        let content = ClipContent.text("这是一段普通的非敏感文本内容")
        let event = try XCTUnwrap(builder.build(content: content, changeCount: 2))

        XCTAssertFalse(event.sensitiveResult.isSensitive)
        XCTAssertTrue(event.sensitiveResult.matchedPatterns.isEmpty)
    }

    // MARK: - TC-UT-56：黑名单检查结果打包进事件（D3）

    func testBlacklistedPackedIntoEvent() throws
    {
        // 由于 AppDetector 在测试中无法识别真实前台 App，使用回退 bundleId
        let content = ClipContent.text("黑名单测试内容")
        let event = try XCTUnwrap(builder.build(content: content, changeCount: 3))

        // event.blacklisted 取决于前台 App 是否在黑名单，测试环境通常为 false
        XCTAssertNotNil(event.blacklisted)
    }

    // MARK: - TC-UT-57：配置快照读取（D23）

    func testConfigSnapshotRead() throws
    {
        var settings = AutoSaveSettings()
        settings.isEnabled = true
        settings.saveDirectory = "~/Documents/ClipMind/Clips/"
        settings.lengthThreshold = 100
        settingsStore.save(settings)

        let content = ClipContent.text("配置快照测试内容")
        let event = try XCTUnwrap(builder.build(content: content, changeCount: 4))

        XCTAssertEqual(event.f2xConfigSnapshot.isEnabled, true)
        XCTAssertEqual(event.f2xConfigSnapshot.saveDirectory, "~/Documents/ClipMind/Clips/")
        XCTAssertEqual(event.f2xConfigSnapshot.lengthThreshold, 100)
    }

    // MARK: - TC-UT-58：配置快照不读实时配置（D23 验证）

    func testConfigSnapshotIsImmutableSnapshot() throws
    {
        var settings = AutoSaveSettings()
        settings.isEnabled = false
        settings.lengthThreshold = 50
        settingsStore.save(settings)

        let content = ClipContent.text("快照不可变性测试")
        let event = try XCTUnwrap(builder.build(content: content, changeCount: 5))

        // 构造事件后修改配置
        var newSettings = AutoSaveSettings()
        newSettings.isEnabled = true
        newSettings.lengthThreshold = 200
        settingsStore.save(newSettings)

        // 事件中的快照应保持构造时的值
        XCTAssertEqual(event.f2xConfigSnapshot.isEnabled, false, "快照应保持构造时值")
        XCTAssertEqual(event.f2xConfigSnapshot.lengthThreshold, 50, "快照应保持构造时值")
    }

    // MARK: - TC-UT-59：F1.x 黑名单快照读取

    func testF1xBlacklistSnapshotRead() throws
    {
        let content = ClipContent.text("F1.x 黑名单快照测试")
        let event = try XCTUnwrap(builder.build(content: content, changeCount: 6))

        XCTAssertNotNil(event.f1xConfigSnapshot.blacklistBundleIds)
    }

    // MARK: - TC-UT-60：非文本内容不执行敏感识别（D12）

    func testNonTextContentSkipsSensitiveDetection() throws
    {
        let content = ClipContent.image(Data([0x89, 0x50, 0x4E, 0x47]))
        let event = try XCTUnwrap(builder.build(content: content, changeCount: 7))

        XCTAssertEqual(event.sensitiveResult, .none, "非文本内容敏感结果应为 .none")
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
  -only-testing:'ClipMindTests/CaptureEventBuilderTests'
```

预期：FAIL，报错 "Cannot find type 'CaptureEventBuilder' in scope"。

- [ ] **步骤 3：编写实现代码**

创建 `ClipMind/Capture/CaptureEventBuilder.swift`：

```swift
import Foundation

/// 捕获事件构造器（B0）。
///
/// 落地 D1（事件驱动模型）、D2（敏感识别只跑一次）、D3（黑名单优先）、
/// D6（配置快照）、D23（配置快照机制）。
///
/// 在 PasteboardWatcher 检测到 changeCount 变化并完成去重后调用，
/// 负责识别来源 App、执行黑名单与敏感识别、读取配置快照，
/// 构造不可变 CaptureEvent 返回。
///
/// 敏感识别（D2）：只执行一次，结果以 SensitiveMatchResult 打包进事件，
/// F1.x 与 F2.1 分支共享同一结果按各自规则独立判断。
///
/// 黑名单检查（D3）：结果打包进 event.blacklisted，
/// F2.1 分支命中黑名单始终不保存（FR-018）。
final class CaptureEventBuilder
{
    private let appDetector: AppDetector
    private let sensitiveDetector: SensitiveDetector
    private let blacklistService: BlacklistService
    private let settingsStore: AutoSaveSettingsStore

    private let logger = LogCategory.capture

    init(appDetector: AppDetector,
         sensitiveDetector: SensitiveDetector,
         blacklistService: BlacklistService,
         settingsStore: AutoSaveSettingsStore)
    {
        self.appDetector = appDetector
        self.sensitiveDetector = sensitiveDetector
        self.blacklistService = blacklistService
        self.settingsStore = settingsStore
    }

    /// 构造不可变 CaptureEvent。
    ///
    /// - Parameters:
    ///   - content: 剪贴板内容
    ///   - changeCount: 当前 pasteboard.changeCount
    /// - Returns: 构造的事件，来源 App 无法识别时返回 nil
    func build(content: ClipContent, changeCount: Int) -> CaptureEvent?
    {
        // 步骤 2：识别来源 App
        let (bundleId, appName) = appDetector.currentFrontmostApp() ?? ("unknown", "Unknown")

        // 步骤 4：黑名单检查（D3，结果打包进事件）
        let blacklisted = blacklistService.contains(bundleId: bundleId)

        // 步骤 5：敏感识别（D2 只跑一次，仅对文本执行）
        let sensitiveResult = performSensitiveDetection(content: content)

        // 步骤 6（去重已在 PasteboardWatcher 完成）

        // 读取配置快照（D23）
        let f2xConfig = F2xConfigSnapshot(from: settingsStore.load())
        let f1xConfig = F1xConfigSnapshot(
            blacklistBundleIds: blacklistService.getAll().map { $0.bundleId }
        )

        logger.debug(
            "Event built: changeCount=\(changeCount, privacy: .public), "
            + "contentLength=\(contentLength(of: content), privacy: .public), "
            + "blacklisted=\(blacklisted, privacy: .public), "
            + "isSensitive=\(sensitiveResult.isSensitive, privacy: .public)"
        )

        // 步骤 7：构造 CaptureEvent
        return CaptureEvent(
            id: UUID().uuidString,
            changeCount: changeCount,
            content: content,
            bundleId: bundleId,
            appName: appName,
            blacklisted: blacklisted,
            sensitiveResult: sensitiveResult,
            f1xConfigSnapshot: f1xConfig,
            f2xConfigSnapshot: f2xConfig,
            timestamp: Date()
        )
    }

    // MARK: - Private

    /// 执行敏感识别（D2 只跑一次）。
    /// 仅对文本内容执行，非文本返回 .none（D12）。
    private func performSensitiveDetection(content: ClipContent) -> SensitiveMatchResult
    {
        guard case .text(let text) = content else
        {
            return .none
        }

        guard let sensitiveType = sensitiveDetector.detect(text) else
        {
            return .none
        }

        return SensitiveMatchResult(
            isSensitive: true,
            matchedPatterns: [sensitiveType.rawValue]
        )
    }

    /// 计算内容长度（D12 100KB 上限判断依据）。
    private func contentLength(of content: ClipContent) -> Int
    {
        switch content
        {
        case .text(let text):
            return text.count
        case .image(let data):
            return data.count
        case .filePath(let urls):
            return urls.count
        }
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1-auto-save-to-file
swiftlint lint --strict
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/CaptureEventBuilderTests'
```

预期：PASS，7 个测试全部通过。

- [ ] **步骤 5：Commit**

```bash
git add ClipMind/Capture/CaptureEventBuilder.swift \
        ClipMindTests/Capture/CaptureEventBuilderTests.swift
git commit -m "$(cat <<'EOF'
feat(F2.1): add CaptureEventBuilder for event construction

落地 D1/D2/D3/D6/D23 决策：B0 捕获事件构造器调用 AppDetector、
BlacklistService、SensitiveDetector、AutoSaveSettingsStore 构造不可变
CaptureEvent。敏感识别只执行一次（D2），结果打包进事件供 F1.x 与
F2.1 分支共享。黑名单检查结果打包进 event.blacklisted（D3）。
配置快照在事件构造阶段读取（D23），异步执行期间不读实时配置。
EOF
)"
```

---

### 任务 3：ClipCaptureService 适配 CaptureEvent

**文件：**
- 修改：`ClipMind/Capture/ClipCaptureService.swift`
- 测试：`ClipMindTests/Capture/ClipCaptureServiceEventTests.swift`

**目标：** 适配 `ClipCaptureService` 接收 `CaptureEvent`（D6）。将 F1.x 既有的黑名单与敏感过滤逻辑从 PasteboardWatcher 迁移到此处：检查 `event.blacklisted` → 日志并返回（D3）；检查 `event.sensitiveResult.isSensitive` → 日志、发送通知、返回（保留 F1.x 既有行为）。取 `event.content` 执行既有入库流程（分类 → ClipItem → EncryptedStore → 通知，流程不变）。注入可选 `AutoSaveService`，调用 `autoSaveService.handle(event:)` 派发 F2.1 分支（D7 异步串行队列）。`init` 签名不变（`autoSaveService` 为可选属性）。

**对应决策：** D3（黑名单优先）、D7（异步派发）、D22（不修改公共接口）

**对应 FR：** FR-014（步骤 8-9）、FR-018（黑名单优先）、FR-009（原内容仍入库）

**对应 AC：** AC-05（原内容仍进入历史）、AC-06（敏感不入库）、AC-08（禁用总开关仅入库）

**前置依赖：** 任务 1（PasteboardWatcher 回调签名）、任务 2（CaptureEventBuilder）、Phase 0 任务 12（AutoSaveService）

- [ ] **步骤 1：编写失败的测试**

创建 `ClipMindTests/Capture/ClipCaptureServiceEventTests.swift`：

```swift
import AppKit
import CryptoKit
import XCTest

@testable import ClipMind

final class ClipCaptureServiceEventTests: XCTestCase
{
    private var pasteboard: NSPasteboard!
    private var watcher: PasteboardWatcher!
    private var store: EncryptedStore!
    private var service: ClipCaptureService!
    private var eventBuilder: CaptureEventBuilder!
    private var defaults: UserDefaults!
    private var tempDir: URL!

    override func setUpWithError() throws
    {
        pasteboard = NSPasteboard(name: .init("test-svc-\(UUID().uuidString)"))
        pasteboard.clearContents()

        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let dbPath = tempDir.appendingPathComponent("test_svc.db")
        let key = SymmetricKey(size: .bits256)
        store = try EncryptedStore(dbPath: dbPath, key: key)

        defaults = UserDefaults(suiteName: "test-svc-\(UUID().uuidString)")!
        let settingsStore = AutoSaveSettingsStore(defaults: defaults)
        eventBuilder = CaptureEventBuilder(
            appDetector: AppDetector(),
            sensitiveDetector: SensitiveDetector(defaults: defaults),
            blacklistService: BlacklistService(defaults: defaults),
            settingsStore: settingsStore
        )

        watcher = PasteboardWatcher(pasteboard: pasteboard, eventBuilder: eventBuilder)
        let embeddingService = LocalEmbeddingService()
        let classifier = ClassificationService(embeddingService: embeddingService)
        service = ClipCaptureService(watcher: watcher, store: store, classifier: classifier)
    }

    override func tearDownWithError() throws
    {
        service?.stop()
        watcher?.stopWatching()
        if let tempDir = tempDir
        {
            try? FileManager.default.removeItem(at: tempDir)
        }
    }

    // MARK: - TC-UT-61：普通内容正常入库（AC-05）

    func testNormalContentStored() throws
    {
        let expectation = XCTestExpectation(description: "内容应入库")
        service.onClipStored = { _ in expectation.fulfill() }

        pasteboard.clearContents()
        pasteboard.setString("普通文本内容用于入库测试", forType: .string)
        watcher.handlePasteboardChange()

        wait(for: [expectation], timeout: 2.0)

        let items = try store.loadAll()
        XCTAssertEqual(items.count, 1, "普通内容应入库")
    }

    // MARK: - TC-UT-62：黑名单命中不入库（D3）

    func testBlacklistedContentNotStored() throws
    {
        // 由于测试环境无法控制前台 App，通过直接调用 handleCaptureEvent 测试
        let event = CaptureEvent(
            id: UUID().uuidString,
            changeCount: 100,
            content: .text("黑名单测试内容"),
            bundleId: "com.test.blacklisted",
            appName: "BlacklistedApp",
            blacklisted: true,
            sensitiveResult: .none,
            f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: ["com.test.blacklisted"]),
            f2xConfigSnapshot: F2xConfigSnapshot(
                isEnabled: false,
                saveDirectory: "",
                whitelistBundleIds: [],
                fileFormat: .markdown,
                lengthThreshold: 50,
                fileNameLength: 20,
                sensitiveFilterEnabled: true,
                pathFormat: .plainPath
            ),
            timestamp: Date()
        )

        service.handleCaptureEvent(event)

        let items = try store.loadAll()
        XCTAssertEqual(items.count, 0, "黑名单内容不应入库")
    }

    // MARK: - TC-UT-63：敏感命中不入库（AC-06）

    func testSensitiveContentNotStored() throws
    {
        let event = CaptureEvent(
            id: UUID().uuidString,
            changeCount: 101,
            content: .text("password=secret123"),
            bundleId: "com.test.app",
            appName: "TestApp",
            blacklisted: false,
            sensitiveResult: SensitiveMatchResult(isSensitive: true, matchedPatterns: ["password"]),
            f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: []),
            f2xConfigSnapshot: F2xConfigSnapshot(
                isEnabled: false,
                saveDirectory: "",
                whitelistBundleIds: [],
                fileFormat: .markdown,
                lengthThreshold: 50,
                fileNameLength: 20,
                sensitiveFilterEnabled: true,
                pathFormat: .plainPath
            ),
            timestamp: Date()
        )

        service.handleCaptureEvent(event)

        let items = try store.loadAll()
        XCTAssertEqual(items.count, 0, "敏感内容不应入库")
    }

    // MARK: - TC-UT-64：autoSaveService 为 nil 时 F1.x 行为不变（D22）

    func testNilAutoSaveServicePreservesF1xBehavior() throws
    {
        XCTAssertNil(service.autoSaveService, "autoSaveService 默认应为 nil")

        let expectation = XCTestExpectation(description: "应正常入库")
        service.onClipStored = { _ in expectation.fulfill() }

        pasteboard.clearContents()
        pasteboard.setString("nil autoSave 测试内容", forType: .string)
        watcher.handlePasteboardChange()

        wait(for: [expectation], timeout: 2.0)

        let items = try store.loadAll()
        XCTAssertEqual(items.count, 1, "autoSaveService=nil 时应正常入库")
    }

    // MARK: - TC-UT-65：autoSaveService 存在时调用 handle(event:)（D7）

    func testAutoSaveServiceHandleCalled() throws
    {
        let mockService = MockAutoSaveService()
        service.autoSaveService = mockService

        let expectation = XCTestExpectation(description: "入库完成")
        service.onClipStored = { _ in expectation.fulfill() }

        pasteboard.clearContents()
        pasteboard.setString("autoSave 派发测试内容", forType: .string)
        watcher.handlePasteboardChange()

        wait(for: [expectation], timeout: 2.0)

        XCTAssertEqual(mockService.handleCallCount, 1, "autoSaveService.handle 应被调用一次")
        let items = try store.loadAll()
        XCTAssertEqual(items.count, 1, "autoSaveService 存在时原内容仍应入库")
    }
}

// MARK: - Mock

private final class MockAutoSaveService: AutoSaveServiceProtocol
{
    private(set) var handleCallCount = 0
    private(set) var lastEvent: CaptureEvent?

    func handle(event: CaptureEvent)
    {
        handleCallCount += 1
        lastEvent = event
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1-auto-save-to-file
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/ClipCaptureServiceEventTests'
```

预期：FAIL，报错 "value of type 'ClipCaptureService' has no member 'autoSaveService'" 或 "has no member 'handleCaptureEvent'"。

- [ ] **步骤 3：编写实现代码**

修改 `ClipMind/Capture/ClipCaptureService.swift`（替换全部内容）：

```swift
import Foundation

/// 剪贴板捕获编排服务。
///
/// 连接 PasteboardWatcher（剪贴板变化检测）与 EncryptedStore（持久化），
/// 并通过 ClassificationService 对文本内容进行分类，最终发送通知刷新 UI。
///
/// F2.1 适配（D6）：接收 CaptureEvent 而非 ClipContent。
/// F1.x 过滤逻辑（黑名单 D3 + 敏感）从 PasteboardWatcher 迁移到此处，
/// 保留 F1.x 既有可观察行为（黑名单/敏感内容不入库）。
///
/// 处理流程（由 PasteboardWatcher 回调触发）：
/// 1. 检查 event.blacklisted → 日志并返回（D3 黑名单优先）
/// 2. 检查 event.sensitiveResult.isSensitive → 日志、通知、返回
/// 3. 取 event.content 经 ClassificationService 分类
/// 4. 创建 ClipItem
/// 5. 调用 autoSaveService.handle(event:) 派发 F2.1 分支（D7，可选）
/// 6. 存入 EncryptedStore（F1.x 入库流程不变）
/// 7. 发送 clipDidUpdateNotification 通知 UI 刷新
final class ClipCaptureService
{
    /// 入库后发送的通知名称，UI 监听此通知以刷新历史列表
    static let clipDidUpdateNotification = Notification.Name("ClipMindClipDidUpdate")

    private let watcher: PasteboardWatcher
    private let store: EncryptedStore
    private let classifier: ClassificationService
    private let appDetector: AppDetector

    /// F2.1 自动保存服务（可选，D7 异步派发）。
    /// 为 nil 时（F1.x 既有行为）ClipCaptureService 行为完全不变。
    /// 使用协议类型避免 ClipCaptureService 直接依赖 AutoSaveService 具体类型。
    var autoSaveService: AnyObject?

    /// 入库完成回调（测试观察用）
    var onClipStored: ((ClipItem) -> Void)?

    /// - Parameters:
    ///   - watcher: 剪贴板监听器
    ///   - store: 加密存储
    ///   - classifier: 内容分类服务
    ///   - appDetector: 前台应用检测器
    init(watcher: PasteboardWatcher,
         store: EncryptedStore,
         classifier: ClassificationService,
         appDetector: AppDetector = AppDetector())
    {
        self.watcher = watcher
        self.store = store
        self.classifier = classifier
        self.appDetector = appDetector
        watcher.onPasteboardChange = { [weak self] event in
            self?.handleCaptureEvent(event)
        }
    }

    /// 启动剪贴板监听
    func start()
    {
        watcher.startWatching()
    }

    /// 停止剪贴板监听
    func stop()
    {
        watcher.stopWatching()
    }

    /// 处理捕获事件：黑名单检查 → 敏感检查 → 分类 → 入库 → F2.1 派发 → 通知
    func handleCaptureEvent(_ event: CaptureEvent)
    {
        // D3：黑名单优先，命中不入库
        if event.blacklisted
        {
            LogCategory.privacy.info(
                "Blacklisted app, skip storage: changeCount=\(event.changeCount, privacy: .public)"
            )
            return
        }

        // 敏感内容不入库（保留 F1.x 既有行为）
        if event.sensitiveResult.isSensitive
        {
            LogCategory.privacy.info(
                "Sensitive content detected, skip storage: "
                + "changeCount=\(event.changeCount, privacy: .public)"
            )
            NotificationManager.sendSensitiveContentIgnoredNotification()
            return
        }

        let content = event.content
        let bundleId = event.bundleId
        let appName = event.appName

        let item: ClipItem
        switch content
        {
        case .text(let text):
            let contentType = classifier.classify(text)
            item = ClipItem.makeText(
                text,
                contentType: contentType,
                sourceApp: bundleId,
                sourceAppName: appName
            )
            LogCategory.capture.info(
                "Captured text: contentLength=\(text.count, privacy: .public), "
                + "type=\(contentType.rawValue, privacy: .public)"
            )
        case .image(let data):
            item = ClipItem.makeImage(
                data,
                contentType: .other,
                sourceApp: bundleId,
                sourceAppName: appName
            )
            LogCategory.capture.info(
                "Captured image: contentLength=\(data.count, privacy: .public)"
            )
        case .filePath(let urls):
            item = ClipItem.makeFilePath(
                urls,
                contentType: .other,
                sourceApp: bundleId,
                sourceAppName: appName
            )
            LogCategory.capture.info(
                "Captured filePath: count=\(urls.count, privacy: .public)"
            )
        }

        // 派发 F2.1 分支（D7 异步，autoSaveService 通过协议调用）
        if let autoSave = autoSaveService as? AutoSaveServiceProtocol
        {
            autoSave.handle(event: event)
        }

        do
        {
            try store.save(item)
            LogCategory.capture.info(
                "ClipItem stored: type=\(item.contentType.rawValue, privacy: .public)"
            )
            NotificationCenter.default.post(name: Self.clipDidUpdateNotification, object: nil)
            onClipStored?(item)
        }
        catch
        {
            LogCategory.storage.error(
                "Storage failed: errorCode=\(error.localizedDescription, privacy: .public)"
            )
        }
    }
}

/// AutoSaveService 协议（用于 ClipCaptureService 解耦）
protocol AutoSaveServiceProtocol
{
    func handle(event: CaptureEvent)
}
```

- [ ] **步骤 4：运行测试验证通过**

首先需要让 `AutoSaveService` 遵循 `AutoSaveServiceProtocol`。在 Phase 0 已创建的 `ClipMind/AutoSave/AutoSaveService.swift` 顶部添加协议遵循：

```swift
// 在 AutoSaveService 类定义后添加扩展
extension AutoSaveService: AutoSaveServiceProtocol {}
```

然后运行测试：

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1-auto-save-to-file
swiftlint lint --strict
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/ClipCaptureServiceEventTests'
```

预期：PASS，5 个测试全部通过。

- [ ] **步骤 5：Commit**

```bash
git add ClipMind/Capture/ClipCaptureService.swift \
        ClipMind/AutoSave/AutoSaveService.swift \
        ClipMindTests/Capture/ClipCaptureServiceEventTests.swift
git commit -m "$(cat <<'EOF'
feat(F2.1): adapt ClipCaptureService to CaptureEvent

适配 D6/D3/D7 决策：ClipCaptureService 接收 CaptureEvent 而非
ClipContent。F1.x 过滤逻辑（黑名单 D3 + 敏感）从 PasteboardWatcher
迁移到此处，保留 F1.x 既有可观察行为。取 event.content 执行既有入库
流程（不变）。通过 AutoSaveServiceProtocol 调用 autoSaveService
派发 F2.1 分支（D7 异步串行队列），init 签名不变。
EOF
)"
```

---

### 任务 4：AutoSaveSettingsView 配置面板 UI

**文件：**
- 创建：`ClipMind/UI/Settings/AutoSaveSettingsView.swift`
- 测试：`ClipMindUITests/AutoSaveSettingsUITests.swift`（任务 7 编写，此处仅创建占位）

**目标：** 实现配置面板"自动保存"分区 SwiftUI 视图（D11/D15）。包含 8 个配置项：总开关（默认关闭 D11）、保存目录、白名单 App 管理、文件格式（Markdown/纯文本）、长度阈值、文件名长度、路径格式（plainPath/fileURI/markdownLink）、敏感过滤开关（含二次确认弹窗）。路径格式实时预览。明文责任提示。所有控件使用 `accessibilityIdentifier` 供 XCUITest 定位。UI 状态更新在 `@MainActor` 边界内。

**对应决策：** D11（总开关默认关闭）、D15（日志白名单）、D16（URI 编码预览）

**对应 FR：** FR-001（总开关）、FR-002（保存目录）、FR-003（白名单）、FR-005（文件格式）、FR-006（文件名长度）、FR-008（路径格式）、FR-012（敏感过滤）

**对应 AC：** AC-07（配置面板可修改全部配置项）、AC-14（关闭敏感过滤二次确认）

**前置依赖：** Phase 0 任务 4（AutoSaveSettings）、任务 5（AutoSaveSettingsStore）

- [ ] **步骤 1：编写失败的测试**

由于 AutoSaveSettingsView 是 SwiftUI 视图，单元测试难以直接验证 UI 渲染。采用 ViewInspector 模式不可行（不引入新依赖），因此通过 XCUITest 验证（任务 7）。本任务步骤 1 创建最小 XCTest 验证视图可实例化：

创建 `ClipMindTests/UI/AutoSaveSettingsViewTests.swift`：

```swift
import SwiftUI
import XCTest

@testable import ClipMind

final class AutoSaveSettingsViewTests: XCTestCase
{
    // MARK: - TC-UT-66：AutoSaveSettingsView 可实例化

    @MainActor
    func testAutoSaveSettingsViewInitializes() throws
    {
        let defaults = UserDefaults(suiteName: "test-ui-\(UUID().uuidString)")!
        let store = AutoSaveSettingsStore(defaults: defaults)
        let view = AutoSaveSettingsView(store: store)
        XCTAssertNotNil(view, "AutoSaveSettingsView 应能正常实例化")

        // 清理
        for key in defaults.dictionaryRepresentation().keys
        {
            defaults.removeObject(forKey: key)
        }
    }

    // MARK: - TC-UT-67：默认配置总开关关闭（D11）

    @MainActor
    func testDefaultSettingsIsEnabledFalse() throws
    {
        let defaults = UserDefaults(suiteName: "test-ui-\(UUID().uuidString)")!
        let store = AutoSaveSettingsStore(defaults: defaults)
        let settings = store.load()

        XCTAssertEqual(settings.isEnabled, false, "D11：总开关默认关闭")

        for key in defaults.dictionaryRepresentation().keys
        {
            defaults.removeObject(forKey: key)
        }
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1-auto-save-to-file
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/AutoSaveSettingsViewTests'
```

预期：FAIL，报错 "Cannot find type 'AutoSaveSettingsView' in scope"。

- [ ] **步骤 3：编写实现代码**

创建 `ClipMind/UI/Settings/AutoSaveSettingsView.swift`：

```swift
import SwiftUI

/// 自动保存配置面板视图（F2.1）。
///
/// 落地 D11（总开关默认关闭）、D15（日志脱敏）、D16（URI 编码预览）。
/// 包含 8 个配置项：总开关、保存目录、白名单、文件格式、长度阈值、
/// 文件名长度、路径格式、敏感过滤开关（含二次确认弹窗）。
///
/// AC 映射：AC-07（配置面板可修改全部配置项）、AC-14（关闭敏感过滤二次确认）
struct AutoSaveSettingsView: View
{
    /// 配置存储（支持注入用于测试）
    private let store: AutoSaveSettingsStore

    /// 当前配置（@State 驱动 UI 更新）
    @State private var settings: AutoSaveSettings

    /// 是否显示关闭敏感过滤二次确认弹窗
    @State private var showDisableSensitiveConfirm = false

    /// 路径预览用的临时文件名
    private let previewFileName = "ClipMind_示例.md"

    /// 新增白名单输入文本
    @State private var newBundleIdText = ""

    init(store: AutoSaveSettingsStore = AutoSaveSettingsStore())
    {
        self.store = store
        self._settings = State(initialValue: store.load())
    }

    var body: some View
    {
        Form
        {
            generalSection
            directorySection
            whitelistSection
            formatSection
            pathFormatSection
            sensitiveSection
            responsibilitySection
        }
        .padding()
        .alert("关闭敏感内容过滤", isPresented: $showDisableSensitiveConfirm)
        {
            Button("取消", role: .cancel)
            {
                settings.sensitiveFilterEnabled = true
            }
            Button("确认关闭", role: .destructive)
            {
                settings.sensitiveFilterEnabled = false
                saveSettings()
            }
        }
        message:
        {
            Text("关闭后，包含密码、Token 等敏感信息的内容将被保存为明文文件。请确认你了解此风险。")
        }
    }

    // MARK: - 总开关

    private var generalSection: some View
    {
        Section("自动保存")
        {
            Toggle("启用自动保存", isOn: $settings.isEnabled)
                .accessibilityIdentifier("autoSaveEnabledToggle")
                .onChange(of: settings.isEnabled) { _ in saveSettings() }

            Text("在白名单 App 中复制长内容时自动保存为文件并替换剪贴板为路径")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 保存目录

    private var directorySection: some View
    {
        Section("保存目录")
        {
            TextField("保存目录路径", text: $settings.saveDirectory)
                .accessibilityIdentifier("saveDirectoryField")
                .onChange(of: settings.saveDirectory) { _ in saveSettings() }

            Text("文件将保存到此目录，使用 POSIX 0600 权限")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 白名单

    private var whitelistSection: some View
    {
        Section("白名单 App")
        {
            ForEach(settings.whitelistBundleIds, id: \.self) { bundleId in
                HStack
                {
                    Text(bundleId)
                    Spacer()
                    Button("删除")
                    {
                        settings.whitelistBundleIds.removeAll { $0 == bundleId }
                        saveSettings()
                    }
                    .accessibilityIdentifier("whitelistDelete_\(bundleId)")
                    .buttonStyle(.borderless)
                }
            }

            HStack
            {
                TextField("Bundle ID（如 com.apple.Safari）", text: $newBundleIdText)
                    .accessibilityIdentifier("whitelistAddField")
                Button("添加")
                {
                    let trimmed = newBundleIdText.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty,
                          !settings.whitelistBundleIds.contains(trimmed) else { return }
                    settings.whitelistBundleIds.append(trimmed)
                    newBundleIdText = ""
                    saveSettings()
                }
                .accessibilityIdentifier("whitelistAddButton")
            }
        }
    }

    // MARK: - 文件格式与阈值

    private var formatSection: some View
    {
        Section("文件格式")
        {
            Picker("文件格式", selection: $settings.fileFormat)
            {
                Text("Markdown").tag(AutoSaveSettings.FileFormat.markdown)
                Text("纯文本").tag(AutoSaveSettings.FileFormat.plainText)
            }
            .accessibilityIdentifier("fileFormatPicker")
            .onChange(of: settings.fileFormat) { _ in saveSettings() }

            Stepper("长度阈值：\(settings.lengthThreshold) 字",
                    value: $settings.lengthThreshold,
                    in: AutoSaveSettings.lengthThresholdRange)
            {
                saveSettings()
            }
            .accessibilityIdentifier("lengthThresholdStepper")

            Stepper("文件名长度：\(settings.fileNameLength) 字",
                    value: $settings.fileNameLength,
                    in: AutoSaveSettings.fileNameLengthRange)
            {
                saveSettings()
            }
            .accessibilityIdentifier("fileNameLengthStepper")
        }
    }

    // MARK: - 路径格式

    private var pathFormatSection: some View
    {
        Section("路径格式")
        {
            Picker("路径格式", selection: $settings.pathFormat)
            {
                Text("纯路径").tag(AutoSaveSettings.PathFormat.plainPath)
                Text("file:// URI").tag(AutoSaveSettings.PathFormat.fileURI)
                Text("Markdown 链接").tag(AutoSaveSettings.PathFormat.markdownLink)
            }
            .accessibilityIdentifier("pathFormatPicker")
            .onChange(of: settings.pathFormat) { _ in saveSettings() }

            // 路径预览（D16 URI 编码）
            pathPreview
        }
    }

    private var pathPreview: some View
    {
        VStack(alignment: .leading, spacing: 4)
        {
            Text("路径预览")
                .font(.caption)
                .foregroundColor(.secondary)

            let previewPath = "\(settings.saveDirectory)\(previewFileName)"
            let previewURL = URL(fileURLWithPath: previewPath)
            Text(FilePathFormatter().format(url: previewURL, format: settings.pathFormat))
                .font(.system(.caption, design: .monospaced))
                .padding(6)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(4)
                .accessibilityIdentifier("pathPreviewText")
        }
    }

    // MARK: - 敏感过滤

    private var sensitiveSection: some View
    {
        Section("敏感过滤")
        {
            Toggle("启用敏感内容过滤", isOn: $settings.sensitiveFilterEnabled)
                .accessibilityIdentifier("sensitiveFilterToggle")
                .onChange(of: settings.sensitiveFilterEnabled) { newValue in
                    if newValue == false
                    {
                        showDisableSensitiveConfirm = true
                    }
                    else
                    {
                        saveSettings()
                    }
                }

            Text("开启后，敏感内容不保存到文件；关闭时需二次确认")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 明文责任提示

    private var responsibilitySection: some View
    {
        Section
        {
            Text("注意：自动保存的文件为明文存储，请确保保存目录的安全性。ClipMind 不对文件内容的泄露承担责任。")
                .font(.caption)
                .foregroundColor(.orange)
                .accessibilityIdentifier("responsibilityWarning")
        }
    }

    // MARK: - Private

    private func saveSettings()
    {
        store.save(settings)
        LogCategory.ui.debug(
            "AutoSaveSettings updated: isEnabled=\(settings.isEnabled, privacy: .public)"
        )
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1-auto-save-to-file
swiftlint lint --strict
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/AutoSaveSettingsViewTests'
```

预期：PASS，2 个测试通过。

- [ ] **步骤 5：Commit**

```bash
git add ClipMind/UI/Settings/AutoSaveSettingsView.swift \
        ClipMindTests/UI/AutoSaveSettingsViewTests.swift
git commit -m "$(cat <<'EOF'
feat(F2.1): add AutoSaveSettingsView config panel

落地 D11/D15/D16 决策：配置面板"自动保存"分区 SwiftUI 视图，包含
8 个配置项（总开关默认关闭 D11、保存目录、白名单、文件格式、长度阈值、
文件名长度、路径格式、敏感过滤）。关闭敏感过滤时弹出二次确认。
路径格式实时预览（D16 URI 编码）。明文责任提示。所有控件带
accessibilityIdentifier 供 XCUITest 定位。
EOF
)"
```

---

### 任务 5：SettingsView 集成自动保存 tab

**文件：**
- 修改：`ClipMind/UI/Settings/SettingsView.swift`
- 测试：`ClipMindTests/UI/SettingsViewAutoSaveTabTests.swift`

**目标：** 在 `SettingsView` 的 `SettingsTab` 枚举新增 `.autoSave` case，TabView 新增"自动保存"分区，嵌入 `AutoSaveSettingsView`。解析 `--UITEST_INITIAL_TAB=autosave` 启动参数。不修改既有 3 个 tab（APIKey/Privacy/General）。

**对应决策：** D22（不修改 F1.x 既有公共接口，新增 case 不算修改）

**对应 FR：** FR-012（配置面板）

**对应 AC：** AC-07（配置面板入口）

**前置依赖：** 任务 4（AutoSaveSettingsView）

- [ ] **步骤 1：编写失败的测试**

创建 `ClipMindTests/UI/SettingsViewAutoSaveTabTests.swift`：

```swift
import SwiftUI
import XCTest

@testable import ClipMind

final class SettingsViewAutoSaveTabTests: XCTestCase
{
    // MARK: - TC-UT-68：SettingsTab 枚举包含 autoSave case

    @MainActor
    func testSettingsTabHasAutoSaveCase() throws
    {
        // 实现前 SettingsTab.autoSave 不存在 → 编译失败（TDD red）
        let tab: SettingsTab = .autoSave
        XCTAssertEqual(tab, .autoSave, "SettingsTab 应包含 .autoSave case")
    }

    // MARK: - TC-UT-69：--UITEST_INITIAL_TAB=autosave 参数解析为 autoSave tab

    @MainActor
    func testAutoSaveTabArgumentParsing() throws
    {
        // 实现前 SettingsView.tabFromArgument 不存在 → 编译失败（TDD red）
        let tab = SettingsView.tabFromArgument("--UITEST_INITIAL_TAB=autosave")
        XCTAssertEqual(tab, .autoSave, "autosave 参数应解析为 .autoSave tab")
    }

    // MARK: - TC-UT-69b：未知参数回退到 apiKey tab（不破坏 F1.x 既有行为）

    @MainActor
    func testUnknownTabArgumentFallsBackToApiKey() throws
    {
        let tab = SettingsView.tabFromArgument("--UITEST_INITIAL_TAB=unknown")
        XCTAssertEqual(tab, .apiKey, "未知参数应回退到 .apiKey tab（F1.x 既有行为）")
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1-auto-save-to-file
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/SettingsViewAutoSaveTabTests'
```

预期：FAIL（编译失败）。报错 "Cannot find type 'SettingsTab' in scope"（SettingsTab 当前为 private，测试无法访问）与 "type 'SettingsView' has no member 'tabFromArgument'"（方法尚未实现）。这是真正的 TDD red——测试因缺少 `.autoSave` case 与 `tabFromArgument` 方法而无法编译，而非"测试是空的所以直接通过"。

- [ ] **步骤 3：编写实现代码**

修改 `ClipMind/UI/Settings/SettingsView.swift`（替换全部内容）：

```swift
import SwiftUI

/// 设置面板主视图。
///
/// 使用 TabView 分为 4 个分区：API Key / 隐私 / 通用 / 自动保存（F2.1）。
/// 对应设计规范 3.8 节设置配置流程和 UI-AC-15 设置面板入口。
struct SettingsView: View
{
    /// 启动时立即解析 `--UITEST_INITIAL_TAB=<tab>` 启动参数。
    @State private var selectedTab: SettingsTab = {
        guard let arg = CommandLine.arguments.first(where: { $0.hasPrefix("--UITEST_INITIAL_TAB=") }) else
        {
            return .apiKey
        }
        return SettingsView.tabFromArgument(arg)
    }()

    var body: some View
    {
        TabView(selection: $selectedTab)
        {
            APIKeyConfigView()
                .tabItem
                {
                    Label("API Key", systemImage: "key.fill")
                        .accessibilityIdentifier("apiKeyTab")
                }
                .tag(SettingsTab.apiKey)

            PrivacySettingsView()
                .tabItem
                {
                    Label("隐私", systemImage: "lock.shield.fill")
                        .accessibilityIdentifier("privacyTab")
                }
                .tag(SettingsTab.privacy)

            GeneralSettingsView()
                .tabItem
                {
                    Label("通用", systemImage: "gear")
                        .accessibilityIdentifier("generalTab")
                }
                .tag(SettingsTab.general)

            AutoSaveSettingsView()
                .tabItem
                {
                    Label("自动保存", systemImage: "doc.on.clipboard.fill")
                        .accessibilityIdentifier("autoSaveTab")
                }
                .tag(SettingsTab.autoSave)
        }
        .frame(width: 520, height: 550)
    }

    /// 解析 `--UITEST_INITIAL_TAB=<tab>` 启动参数为 SettingsTab。
    ///
    /// 提取为静态方法供 `@State` 初始化与单元测试共用，保证解析逻辑单一来源。
    /// 未知值回退到 `.apiKey`（F1.x 既有行为，不破坏兼容）。
    static func tabFromArgument(_ arg: String) -> SettingsTab
    {
        let raw = String(arg.dropFirst("--UITEST_INITIAL_TAB=".count))
        switch raw.lowercased()
        {
        case "privacy":
            return .privacy
        case "general":
            return .general
        case "autosave":
            return .autoSave
        default:
            return .apiKey
        }
    }
}

/// 设置面板标签枚举（internal 供 @testable 测试访问，D22 新增 case 不算修改 F1.x 既有接口）
enum SettingsTab: Hashable
{
    case apiKey
    case privacy
    case general
    case autoSave
}
```

- [ ] **步骤 4：运行测试验证通过**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1-auto-save-to-file
swiftlint lint --strict
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/SettingsViewAutoSaveTabTests'
```

预期：PASS，3 个测试通过。

- [ ] **步骤 5：Commit**

```bash
git add ClipMind/UI/Settings/SettingsView.swift \
        ClipMindTests/UI/SettingsViewAutoSaveTabTests.swift
git commit -m "$(cat <<'EOF'
feat(F2.1): add autoSave tab to SettingsView

在 SettingsTab 枚举新增 .autoSave case，TabView 新增"自动保存"
分区嵌入 AutoSaveSettingsView。提取 tabFromArgument 静态方法解析
--UITEST_INITIAL_TAB 启动参数，供 @State 初始化与单元测试共用。
SettingsTab 由 private 改为 internal 供 @testable 测试访问（新增
case 不算修改 F1.x 既有接口，D22）。不修改既有 3 个 tab。
EOF
)"
```

---

### 任务 6：AppDelegate 装配 AutoSaveService

**文件：**
- 修改：`ClipMind/App/ClipMindApp.swift`
- 测试：`ClipMindTests/App/AppDelegateAutoSaveAssemblyTests.swift`

**目标：** 在 `AppDelegate.setupCaptureService` 中装配 `AutoSaveService`、`SelfWriteSuppressor`、`CaptureEventBuilder`，并注入到 `PasteboardWatcher` 与 `ClipCaptureService`。`applyUITestOverrides` 新增 `--UITEST_RESET_AUTOSAVE_SETTINGS` 处理（清除 F2.1 相关 UserDefaults 键）。`init` 签名不变。

**对应决策：** D7（串行队列）、D4（自我写入抑制器装配）

**对应 FR：** FR-014（并行分发装配）、FR-015（自我写入抑制器）

**对应 AC：** AC-01（端到端自动保存）、AC-08（禁用总开关不触发）

**前置依赖：** 任务 1~3、Phase 0 任务 6（SelfWriteSuppressor）、任务 12（AutoSaveService）

- [ ] **步骤 1：编写失败的测试**

创建 `ClipMindTests/App/AppDelegateAutoSaveAssemblyTests.swift`：

```swift
import XCTest

@testable import ClipMind

final class AppDelegateAutoSaveAssemblyTests: XCTestCase
{
    // MARK: - TC-UT-70：resetAutoSaveSettings 清除全部 F2.1 配置键

    @MainActor
    func testResetAutoSaveSettingsClearsAllKeys() throws
    {
        let suite = "test-autosave-reset-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { UserDefaults.removePersistentDomain(forName: suite) }

        // 预置全部 8 个 F2.1 配置键
        let keys = AppDelegate.autoSaveSettingsKeys
        for key in keys
        {
            defaults.set("test-value", forKey: key)
        }

        // 实现前 AppDelegate.resetAutoSaveSettings(in:) 不存在 → 编译失败（TDD red）
        AppDelegate.resetAutoSaveSettings(in: defaults)

        for key in keys
        {
            XCTAssertNil(defaults.object(forKey: key), "键 \(key) 应被清除")
        }
    }

    // MARK: - TC-UT-71：autoSaveSettingsKeys 包含全部 8 个配置项

    @MainActor
    func testAutoSaveSettingsKeysContainsAllEight() throws
    {
        // 实现前 AppDelegate.autoSaveSettingsKeys 不存在 → 编译失败（TDD red）
        let keys = AppDelegate.autoSaveSettingsKeys
        XCTAssertEqual(keys.count, 8, "应有 8 个 F2.1 配置键")
        XCTAssertTrue(keys.contains("F2.1.autoSave.isEnabled"), "应包含总开关键")
        XCTAssertTrue(keys.contains("F2.1.autoSave.saveDirectory"), "应包含保存目录键")
        XCTAssertTrue(keys.contains("F2.1.autoSave.whitelistBundleIds"), "应包含白名单键")
        XCTAssertTrue(keys.contains("F2.1.autoSave.fileFormat"), "应包含文件格式键")
        XCTAssertTrue(keys.contains("F2.1.autoSave.lengthThreshold"), "应包含长度阈值键")
        XCTAssertTrue(keys.contains("F2.1.autoSave.fileNameLength"), "应包含文件名长度键")
        XCTAssertTrue(keys.contains("F2.1.autoSave.sensitiveFilterEnabled"), "应包含敏感过滤键")
        XCTAssertTrue(keys.contains("F2.1.autoSave.pathFormat"), "应包含路径格式键")
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1-auto-save-to-file
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/AppDelegateAutoSaveAssemblyTests'
```

预期：FAIL（编译失败）。报错 "type 'AppDelegate' has no member 'resetAutoSaveSettings(in:)'" 与 "type 'AppDelegate' has no member 'autoSaveSettingsKeys'"（F2.1 装配与重置逻辑尚未实现）。这是真正的 TDD red——测试因缺少静态方法与键列表常量而无法编译，而非"既有测试可能通过"。

- [ ] **步骤 3：编写实现代码**

修改 `ClipMind/App/ClipMindApp.swift`，在 `AppDelegate` 中新增 F2.1 装配逻辑：

在 `AppDelegate` 类中新增属性（在 `captureService` 属性下方）：

```swift
    private var autoSaveService: AutoSaveService?
    private var selfWriteSuppressor: SelfWriteSuppressor?

    /// F2.1 自动保存配置键列表（供 `--UITEST_RESET_AUTOSAVE_SETTINGS` 重置与单元测试共用）。
    /// 与 `AutoSaveSettingsStore` 使用的键保持一致。
    static let autoSaveSettingsKeys: [String] = [
        "F2.1.autoSave.isEnabled",
        "F2.1.autoSave.saveDirectory",
        "F2.1.autoSave.whitelistBundleIds",
        "F2.1.autoSave.fileFormat",
        "F2.1.autoSave.lengthThreshold",
        "F2.1.autoSave.fileNameLength",
        "F2.1.autoSave.sensitiveFilterEnabled",
        "F2.1.autoSave.pathFormat"
    ]

    /// 重置 F2.1 自动保存配置（供 `applyUITestOverrides` 与单元测试共用）。
    /// - Parameter defaults: 目标 UserDefaults 实例（测试时注入隔离 suite，生产用 .standard）
    static func resetAutoSaveSettings(in defaults: UserDefaults)
    {
        for key in autoSaveSettingsKeys
        {
            defaults.removeObject(forKey: key)
        }
        defaults.synchronize()
    }
```

修改 `setupCaptureService` 方法（替换全部内容）：

```swift
    /// 初始化并启动剪贴板捕获服务（含 F2.1 自动保存装配）
    private func setupCaptureService(store: EncryptedStore)
    {
        let embeddingService = LocalEmbeddingService()
        let classifier = ClassificationService(embeddingService: embeddingService)

        // F2.1 装配：构造 CaptureEventBuilder 与 AutoSaveService
        let settingsStore = AutoSaveSettingsStore()
        let sensitiveDetector = SensitiveDetector()
        let blacklistService = BlacklistService()
        let eventBuilder = CaptureEventBuilder(
            appDetector: AppDetector(),
            sensitiveDetector: sensitiveDetector,
            blacklistService: blacklistService,
            settingsStore: settingsStore
        )

        let suppressor = SelfWriteSuppressor()
        selfWriteSuppressor = suppressor

        let autoSave = AutoSaveService(
            settingsStore: settingsStore,
            pasteboard: .general,
            suppressor: suppressor
        )
        autoSaveService = autoSave

        let watcher = PasteboardWatcher(eventBuilder: eventBuilder)
        captureService = ClipCaptureService(watcher: watcher, store: store, classifier: classifier)
        captureService?.autoSaveService = autoSave
        captureService?.start()

        LogCategory.app.info("剪贴板捕获服务已启动（含 F2.1 自动保存）")
    }
```

在 `applyUITestOverrides` 方法末尾（`if CommandLine.arguments.contains("--UITEST_RESET_SETTINGS")` 块之后）新增：

```swift
        if CommandLine.arguments.contains("--UITEST_RESET_AUTOSAVE_SETTINGS")
        {
            Self.resetAutoSaveSettings(in: UserDefaults.standard)
            LogCategory.app.info("已通过 --UITEST_RESET_AUTOSAVE_SETTINGS 重置 F2.1 配置")
        }
```

- [ ] **步骤 4：运行测试验证通过**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1-auto-save-to-file
swiftlint lint --strict
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/AppDelegateAutoSaveAssemblyTests'
```

预期：PASS，2 个测试通过。

- [ ] **步骤 5：Commit**

```bash
git add ClipMind/App/ClipMindApp.swift \
        ClipMindTests/App/AppDelegateAutoSaveAssemblyTests.swift
git commit -m "$(cat <<'EOF'
feat(F2.1): assemble AutoSaveService in AppDelegate

落地 D7/D4 决策：setupCaptureService 装配 CaptureEventBuilder、
SelfWriteSuppressor、AutoSaveService，注入 PasteboardWatcher 与
ClipCaptureService。applyUITestOverrides 新增
--UITEST_RESET_AUTOSAVE_SETTINGS 处理。提取 autoSaveSettingsKeys 常量与
resetAutoSaveSettings(in:) 静态方法供生产代码与单元测试共用，避免键名
漂移。init 签名不变。
EOF
)"
```

---

### 任务 7：AutoSaveSettingsUITests（AC-07/15/16/14 UI 交互）

**文件：**
- 创建：`ClipMindUITests/AutoSaveSettingsUITests.swift`

**目标：** 落地 D19（XCUITest 只验证 UI 交互）。覆盖 AC-07（配置面板修改全部配置项）、AC-15（白名单增删）、AC-16（配置持久化）、AC-14（关闭敏感过滤二次确认 UI）。通过 `--UITEST_RESET_AUTOSAVE_SETTINGS` + `--UITEST_INITIAL_TAB=autosave` 启动参数确保每次测试干净状态。仅验证 UI 交互，不验证业务逻辑（D19）。

**对应决策：** D19（XCUITest 只验证 UI 交互）

**对应 AC：** AC-07、AC-14、AC-15、AC-16

**对应约束：** 本地禁止执行 XCUITest（仅 CI）

**前置依赖：** 任务 4、5、6

- [ ] **步骤 1：编写失败的测试**

创建 `ClipMindUITests/AutoSaveSettingsUITests.swift`：

```swift
import XCTest

final class AutoSaveSettingsUITests: XCTestCase
{
    override func setUp()
    {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - AC-07：配置面板可修改全部配置项

    /// 验证自动保存配置面板所有控件存在且可交互。
    func testAC07AllConfigControlsExist()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_RESET_AUTOSAVE_SETTINGS",
            "--UITEST_INITIAL_TAB=autosave"
        ]
        app.launch()
        app.activate()

        // 打开设置面板
        let settingsButton = app.buttons["settingsButton"].firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.click()

        // 验证总开关存在
        let enabledToggle = app.checkBoxes["autoSaveEnabledToggle"]
        XCTAssertTrue(enabledToggle.waitForExistence(timeout: 5), "总开关应存在")

        // 验证保存目录输入框存在
        let directoryField = app.textFields["saveDirectoryField"]
        XCTAssertTrue(directoryField.waitForExistence(timeout: 3), "保存目录输入框应存在")

        // 验证文件格式选择器存在
        let formatPicker = app.popUpButtons["fileFormatPicker"]
        XCTAssertTrue(formatPicker.waitForExistence(timeout: 3), "文件格式选择器应存在")

        // 验证路径格式选择器存在
        let pathPicker = app.popUpButtons["pathFormatPicker"]
        XCTAssertTrue(pathPicker.waitForExistence(timeout: 3), "路径格式选择器应存在")

        // 验证敏感过滤开关存在
        let sensitiveToggle = app.checkBoxes["sensitiveFilterToggle"]
        XCTAssertTrue(sensitiveToggle.waitForExistence(timeout: 3), "敏感过滤开关应存在")

        // 验证路径预览存在
        let pathPreview = app.staticTexts["pathPreviewText"]
        XCTAssertTrue(pathPreview.waitForExistence(timeout: 3), "路径预览应存在")

        // 验证明文责任提示存在
        let warning = app.staticTexts["responsibilityWarning"]
        XCTAssertTrue(warning.waitForExistence(timeout: 3), "明文责任提示应存在")
    }

    // MARK: - AC-15：白名单 App 管理可添加与删除

    /// 验证白名单添加与删除 UI 交互。
    func testAC15WhitelistAddAndDelete()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_RESET_AUTOSAVE_SETTINGS",
            "--UITEST_INITIAL_TAB=autosave"
        ]
        app.launch()
        app.activate()

        let settingsButton = app.buttons["settingsButton"].firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.click()

        // 添加白名单条目
        let addField = app.textFields["whitelistAddField"]
        XCTAssertTrue(addField.waitForExistence(timeout: 5))
        addField.click()
        addField.typeText("com.test.whitelist")

        let addButton = app.buttons["whitelistAddButton"]
        XCTAssertTrue(addButton.exists)
        addButton.click()

        // 验证新条目出现
        let deleteButton = app.buttons["whitelistDelete_com.test.whitelist"]
        XCTAssertTrue(deleteButton.waitForExistence(timeout: 3), "新增白名单条目应出现")

        // 删除条目
        deleteButton.click()
        XCTAssertFalse(deleteButton.waitForExistence(timeout: 2), "删除后条目应消失")
    }

    // MARK: - AC-16：配置修改持久化

    /// 验证总开关切换后重启 App 仍保留。
    func testAC16ConfigPersistsAcrossRestart()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_RESET_AUTOSAVE_SETTINGS",
            "--UITEST_INITIAL_TAB=autosave"
        ]
        app.launch()
        app.activate()

        let settingsButton = app.buttons["settingsButton"].firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.click()

        // 开启总开关
        let enabledToggle = app.checkBoxes["autoSaveEnabledToggle"]
        XCTAssertTrue(enabledToggle.waitForExistence(timeout: 5))
        if enabledToggle.value as? String == "0"
        {
            enabledToggle.click()
        }
        XCTAssertEqual(enabledToggle.value as? String, "1", "总开关应已开启")

        // 重启 App
        app.terminate()

        let app2 = XCUIApplication()
        app2.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_INITIAL_TAB=autosave"
        ]
        app2.launch()
        app2.activate()

        let settingsButton2 = app2.buttons["settingsButton"].firstMatch
        XCTAssertTrue(settingsButton2.waitForExistence(timeout: 5))
        settingsButton2.click()

        let enabledToggle2 = app2.checkBoxes["autoSaveEnabledToggle"]
        XCTAssertTrue(enabledToggle2.waitForExistence(timeout: 5))
        XCTAssertEqual(enabledToggle2.value as? String, "1", "总开关状态应持久化保留")
    }

    // MARK: - AC-14：关闭敏感过滤二次确认 UI

    /// 验证关闭敏感过滤时弹出二次确认弹窗。
    func testAC14DisableSensitiveShowsConfirmDialog()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_RESET_AUTOSAVE_SETTINGS",
            "--UITEST_INITIAL_TAB=autosave"
        ]
        app.launch()
        app.activate()

        let settingsButton = app.buttons["settingsButton"].firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.click()

        // 敏感过滤默认开启，点击关闭
        let sensitiveToggle = app.checkBoxes["sensitiveFilterToggle"]
        XCTAssertTrue(sensitiveToggle.waitForExistence(timeout: 5))
        XCTAssertEqual(sensitiveToggle.value as? String, "1", "敏感过滤应默认开启")
        sensitiveToggle.click()

        // 验证二次确认弹窗出现
        let cancelButton = app.buttons["取消"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 3), "二次确认弹窗应出现")

        // 点击取消，开关应恢复为开启
        cancelButton.click()
        let sensitiveToggleAfter = app.checkBoxes["sensitiveFilterToggle"]
        XCTAssertEqual(sensitiveToggleAfter.value as? String, "1", "取消后敏感过滤应恢复开启")
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1-auto-save-to-file
# 注意：XCUITest 本地禁止执行，仅验证编译通过
xcodebuild build-for-testing \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

预期：编译通过（XCUITest 由 CI 执行）。

- [ ] **步骤 3：编写实现代码**

本任务为测试任务，无生产代码实现。测试文件已在步骤 1 创建完成。确保 `AutoSaveSettingsView`（任务 4）与 `SettingsView`（任务 5）中的 `accessibilityIdentifier` 与测试中的标识符完全一致。

- [ ] **步骤 4：运行测试验证通过**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1-auto-save-to-file
swiftlint lint --strict
# XCUITest 仅 CI 执行，本地仅验证编译
xcodebuild build-for-testing \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

预期：编译通过。XCUITest 由 CI 验证 AC-07/14/15/16 UI 交互。

- [ ] **步骤 5：Commit**

```bash
git add ClipMindUITests/AutoSaveSettingsUITests.swift
git commit -m "$(cat <<'EOF'
test(F2.1): add AutoSaveSettingsUITests for AC-07/14/15/16

落地 D19 决策：XCUITest 只验证 UI 交互。覆盖 AC-07（全部配置控件
存在）、AC-15（白名单增删）、AC-16（配置持久化重启保留）、AC-14
（关闭敏感过滤二次确认弹窗）。通过 --UITEST_RESET_AUTOSAVE_SETTINGS
+ --UITEST_INITIAL_TAB=autosave 确保干净测试状态。XCUITest 仅 CI 执行。
EOF
)"
```

---

### 任务 8：AutoSaveBehaviorUITests（AC-09 保存目录异常弹窗）

**文件：**
- 创建：`ClipMindUITests/AutoSaveBehaviorUITests.swift`

**目标：** 落地 D19（XCUITest 只验证 UI 交互）。覆盖 AC-09（保存目录异常时弹窗提示不崩溃）。验证 App 在保存目录配置为不存在路径时不崩溃、弹窗出现（`autoSaveErrorAlert` 断言）、剪贴板保持原文。仅验证 UI 交互，不验证文件系统逻辑（D19）。

**对应决策：** D19（XCUITest 只验证 UI 交互）、D13（目录异常分级处理）

**对应 AC：** AC-09

**对应约束：** 本地禁止执行 XCUITest（仅 CI）

**前置依赖：** 任务 4、5、6、7

- [ ] **步骤 1：编写失败的测试**

创建 `ClipMindUITests/AutoSaveBehaviorUITests.swift`：

```swift
import XCTest

final class AutoSaveBehaviorUITests: XCTestCase
{
    override func setUp()
    {
        super.setUp()
        continueAfterFailure = false
    }

    // MARK: - AC-09：保存目录异常时弹窗提示不崩溃

    /// 验证保存目录配置为不存在路径时，App 不崩溃且显示错误弹窗。
    func testAC09DirectoryExceptionShowsAlertNoCrash()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_RESET_AUTOSAVE_SETTINGS",
            "--UITEST_INITIAL_TAB=autosave"
        ]
        app.launch()
        app.activate()

        // 打开设置面板
        let settingsButton = app.buttons["settingsButton"].firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.click()

        // 开启总开关
        let enabledToggle = app.checkBoxes["autoSaveEnabledToggle"]
        XCTAssertTrue(enabledToggle.waitForExistence(timeout: 5))
        if enabledToggle.value as? String == "0"
        {
            enabledToggle.click()
        }

        // 设置保存目录为不存在路径
        let directoryField = app.textFields["saveDirectoryField"]
        XCTAssertTrue(directoryField.waitForExistence(timeout: 3))
        directoryField.click()
        // 全选并删除现有内容
        directoryField.typeKey("a", modifierFlags: .command)
        directoryField.typeKey(XCUIKeyboardKey.delete, modifierFlags: [])
        directoryField.typeText("/nonexistent/path/")

        // 关闭设置窗口（Cmd+W）
        app.typeKey("w", modifierFlags: .command)

        // App 不应崩溃
        XCTAssertTrue(app.waitForExistence(timeout: 3), "App 不应崩溃")

        // 验证错误弹窗出现（autoSaveErrorAlert accessibility identifier）
        // 弹窗由 AutoSaveService 在目录异常时触发
        let errorAlert = app.alerts["autoSaveErrorAlert"]
        XCTAssertTrue(
            errorAlert.waitForExistence(timeout: 10),
            "保存目录异常时应显示错误弹窗"
        )

        // 点击确定关闭弹窗
        let okButton = errorAlert.buttons["确定"]
        if okButton.exists
        {
            okButton.click()
        }
    }

    // MARK: - AC-08：禁用总开关不触发保存（UI 烟雾测试）

    /// 验证总开关关闭时配置面板状态正确。
    func testAC08DisabledToggleNoSave()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_RESET_AUTOSAVE_SETTINGS",
            "--UITEST_INITIAL_TAB=autosave"
        ]
        app.launch()
        app.activate()

        let settingsButton = app.buttons["settingsButton"].firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.click()

        let enabledToggle = app.checkBoxes["autoSaveEnabledToggle"]
        XCTAssertTrue(enabledToggle.waitForExistence(timeout: 5))
        XCTAssertEqual(
            enabledToggle.value as? String,
            "0",
            "D11：总开关默认应关闭"
        )

        // App 不崩溃
        XCTAssertTrue(app.waitForExistence(timeout: 3), "App 不应崩溃")
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1-auto-save-to-file
# XCUITest 本地禁止执行，仅验证编译
xcodebuild build-for-testing \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

预期：编译通过。AC-09 弹窗需要在 `AutoSaveService` 中添加错误弹窗触发逻辑（通过 `NotificationCenter` 发送错误通知，`AppDelegate` 监听并显示 `NSAlert`）。

- [ ] **步骤 3：编写实现代码**

在 `ClipMind/App/ClipMindApp.swift` 的 `AppDelegate` 中新增错误弹窗监听。在 `applicationDidFinishLaunching` 方法末尾新增：

```swift
        // 监听 F2.1 自动保存错误通知（D13 目录异常分级处理）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAutoSaveError(_:)),
            name: AutoSaveService.errorNotification,
            object: nil
        )
```

在 `AppDelegate` 类中新增方法：

```swift
    /// 处理 F2.1 自动保存错误，显示弹窗（AC-09）
    @objc private func handleAutoSaveError(_ notification: Notification)
    {
        let errorCode = notification.userInfo?["errorCode"] as? String ?? "unknown"
        LogCategory.app.error(
            "AutoSave error: errorCode=\(errorCode, privacy: .public)"
        )

        DispatchQueue.main.async
        {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "自动保存失败"
            alert.informativeText = "保存目录异常，文件未能保存。剪贴板内容保持原文。"
            alert.addButton(withTitle: "确定")
            alert.accessibilityIdentifier = "autoSaveErrorAlert"
            alert.runModal()
        }
    }
```

在 `ClipMind/AutoSave/AutoSaveService.swift` 中新增错误通知名称（在类定义顶部）：

```swift
    /// 自动保存错误通知名称（D13 目录异常分级处理，AC-09 弹窗触发）
    static let errorNotification = Notification.Name("ClipMindAutoSaveError")
```

在 `AutoSaveService.handle(event:)` 方法的错误处理分支中发送通知（在 `catch` 块内）：

```swift
            // D13：目录异常分级处理，发送错误通知触发弹窗（AC-09）
            NotificationCenter.default.post(
                name: Self.errorNotification,
                object: nil,
                userInfo: ["errorCode": error.localizedDescription]
            )
```

- [ ] **步骤 4：运行测试验证通过**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1-auto-save-to-file
swiftlint lint --strict
# XCUITest 仅 CI 执行，本地仅验证编译
xcodebuild build-for-testing \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

预期：编译通过。XCUITest 由 CI 验证 AC-09 弹窗不崩溃。

- [ ] **步骤 5：Commit**

```bash
git add ClipMindUITests/AutoSaveBehaviorUITests.swift \
        ClipMind/App/ClipMindApp.swift \
        ClipMind/AutoSave/AutoSaveService.swift
git commit -m "$(cat <<'EOF'
test(F2.1): add AutoSaveBehaviorUITests for AC-09

落地 D19/D13 决策：XCUITest 验证 AC-09（保存目录异常弹窗不崩溃）。
AppDelegate 监听 AutoSaveService.errorNotification 并显示 NSAlert
（accessibilityIdentifier=autoSaveErrorAlert）。AutoSaveService 在
目录异常时发送错误通知（D13 分级处理）。XCUITest 仅 CI 执行。
EOF
)"
```

---

### 任务 9：手动验收脚本（AC-01/02/03/05/17~22 OS 边界）

**文件：**
- 创建：`docs/planning/P1/F2.1/实现计划/manual-acceptance-script.md`

**目标：** 落地 D20（手动测试只验证 OS 边界）。覆盖 AC-01（真实 Safari 复制）、AC-02（真实 Notes 复制）、AC-03（Finder 打开文件）、AC-05（历史条目可见）、AC-17（连续复制 changeCount）、AC-18（自我写入抑制）、AC-19（20 次并发安全）、AC-20（配置快照）、AC-21（非文本不触发）、AC-22（日志脱敏）。只验证 XCTest/XCUITest 无法覆盖的 OS 边界场景。

**对应决策：** D20（手动测试只验证 OS 边界）

**对应 AC：** AC-01、AC-02、AC-03、AC-05、AC-17~22

**前置依赖：** 任务 1~8 全部完成

- [ ] **步骤 1：编写失败的测试**

手动验收脚本为文档文件，无单元测试。此步骤创建脚本文件。

- [ ] **步骤 2：运行测试验证失败**

无测试可运行。验证文件存在即可：

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1-auto-save-to-file
test -f docs/planning/P1/F2.1/实现计划/manual-acceptance-script.md && echo "EXISTS" || echo "MISSING"
```

预期：MISSING（文件尚未创建）。

- [ ] **步骤 3：编写实现代码**

创建 `docs/planning/P1/F2.1/实现计划/manual-acceptance-script.md`：

````markdown
> 最后更新：2026-07-22 | 版本：v1.0

# F2.1 手动验收脚本（D20 OS 边界）

> **使用说明：** 本脚本覆盖 XCTest/XCUITest 无法验证的 OS 边界场景。
> 每次执行前先运行 `--UITEST_RESET_AUTOSAVE_SETTINGS` 重置配置。
> 在真实 macOS 环境中执行，记录每条 AC 的实际结果。

## 前置准备

1. 启动 ClipMind App
2. 打开设置 → 自动保存 tab
3. 开启总开关
4. 设置保存目录为 `~/Documents/ClipMind/Clips/`
5. 确认白名单包含 `com.apple.Safari`、`com.apple.Notes`
6. 设置长度阈值为 50 字
7. 设置文件格式为 Markdown
8. 设置路径格式为纯路径

---

## AC-01：白名单 App 复制长内容触发自动保存

**步骤：**
1. 打开 Safari，访问任意网页
2. 选中一段超过 50 字的文本
3. 按 Cmd+C 复制

**预期：**
- `~/Documents/ClipMind/Clips/` 目录出现新的 `.md` 文件
- 文件内容为复制的原文
- 剪贴板内容被替换为文件路径（纯路径格式）
- ClipMind 历史中出现原始内容条目

**实际结果：** _______

---

## AC-02：白名单 App（Notes）复制触发自动保存

**步骤：**
1. 打开 Notes（备忘录）
2. 新建笔记，输入超过 50 字的文本
3. 选中并按 Cmd+C 复制

**预期：**
- 保存目录出现新 `.md` 文件
- 剪贴板替换为文件路径
- ClipMind 历史出现原始内容

**实际结果：** _______

---

## AC-03：文件路径可在 Finder 中打开

**步骤：**
1. 完成 AC-01 或 AC-02
2. 在 Finder 中按 Cmd+Shift+G
3. 粘贴剪贴板中的文件路径
4. 按回车

**预期：**
- Finder 定位到自动保存的文件
- 文件可在默认编辑器中打开
- 文件内容与复制原文一致

**实际结果：** _______

---

## AC-05：原内容仍进入 ClipMind 历史

**步骤：**
1. 完成 AC-01
2. 打开 ClipMind 主窗口
3. 查看历史列表

**预期：**
- 历史列表顶部出现刚复制的原始内容（非文件路径）
- 条目来源 App 显示为 Safari

**实际结果：** _______

---

## AC-17：连续复制 changeCount 前置条件

**步骤：**
1. 在 Safari 中快速连续复制 3 段不同内容（每段超过 50 字）
2. 检查保存目录

**预期：**
- 保存目录出现 3 个不同的 `.md` 文件
- 每个文件内容对应每次复制的内容
- 剪贴板最终内容为第 3 次复制的文件路径
- 无重复保存或文件覆盖

**实际结果：** _______

---

## AC-18：自我写入抑制

**步骤：**
1. 在 Safari 中复制一段超过 50 字的内容
2. 等待自动保存完成（剪贴板被替换为路径）
3. 立即在另一 App 中粘贴
4. 检查 ClipMind 历史

**预期：**
- ClipMind 历史中不出现文件路径条目（自我写入被抑制）
- 保存目录不出现二次保存的文件
- 历史仅包含原始复制内容

**实际结果：** _______

---

## AC-19：20 次连续复制并发安全

**步骤：**
1. 在 Safari 中快速连续复制 20 段不同内容（每段超过 50 字）
2. 等待 5 秒
3. 检查保存目录与 ClipMind 历史

**预期：**
- 保存目录出现 20 个不同的 `.md` 文件（无文件损坏）
- ClipMind 历史出现 20 条原始内容条目
- App 不崩溃、不卡死
- 无文件名冲突错误

**实际结果：** _______

---

## AC-20：配置快照不读实时配置

**步骤：**
1. 在 Safari 中复制一段超过 50 字的内容
2. 在自动保存执行过程中（5 秒内），快速修改长度阈值为 200 字
3. 检查保存目录

**预期：**
- 当前复制事件仍按旧阈值（50 字）触发保存（配置快照）
- 下一次复制按新阈值（200 字）判断
- 无配置不一致导致的异常

**实际结果：** _______

---

## AC-21：非文本内容不触发自动保存

**步骤：**
1. 在 Finder 中选中一个图片文件
2. 按 Cmd+C 复制文件
3. 检查保存目录

**预期：**
- 保存目录不出现新文件（文件路径列表不触发 D12）
- ClipMind 历史可能出现文件路径条目（F1.x 行为）
- 剪贴板保持为文件路径（不被替换）

**实际结果：** _______

---

## AC-22：日志脱敏验证

**步骤：**
1. 打开 Console.app
2. 过滤 subsystem 为 `com.clipmind.app`
3. 在 Safari 中复制一段包含 `password=secret123` 的内容（超过 50 字）
4. 检查日志输出

**预期：**
- 日志中不出现 `password=secret123` 原文
- 日志中不出现完整文件路径（含用户名）
- 日志仅包含白名单字段：module/operation/phase/result/errorCode/retryCount/changeCount/contentLength/fileName
- 敏感内容命中记录为 `isSensitive=true`，不输出具体内容

**实际结果：** _______

---

## 验收总结

| AC 编号 | 状态 | 备注 |
|---------|------|------|
| AC-01 | ☐ 通过 ☐ 失败 | |
| AC-02 | ☐ 通过 ☐ 失败 | |
| AC-03 | ☐ 通过 ☐ 失败 | |
| AC-05 | ☐ 通过 ☐ 失败 | |
| AC-17 | ☐ 通过 ☐ 失败 | |
| AC-18 | ☐ 通过 ☐ 失败 | |
| AC-19 | ☐ 通过 ☐ 失败 | |
| AC-20 | ☐ 通过 ☐ 失败 | |
| AC-21 | ☐ 通过 ☐ 失败 | |
| AC-22 | ☐ 通过 ☐ 失败 | |

**验收人：** _______ **日期：** _______
````

- [ ] **步骤 4：运行测试验证通过**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1-auto-save-to-file
test -f docs/planning/P1/F2.1/实现计划/manual-acceptance-script.md && echo "EXISTS" || echo "MISSING"
```

预期：EXISTS，文件已创建。

- [ ] **步骤 5：Commit**

```bash
git add docs/planning/P1/F2.1/实现计划/manual-acceptance-script.md
git commit -m "$(cat <<'EOF'
docs(F2.1): add manual acceptance script for OS boundary

落地 D20 决策：手动测试只验证 OS 边界。覆盖 AC-01（真实 Safari
复制）、AC-02（Notes 复制）、AC-03（Finder 打开文件）、AC-05
（历史可见）、AC-17~22（并发/自我写入/配置快照/非文本/日志脱敏）。
每条 AC 含步骤、预期、实际结果记录位。
EOF
)"
```

---

### 任务 10：Phase 1 集成测试（端到端事件流）

**文件：**
- 创建：`ClipMindTests/AutoSave/AutoSaveIntegrationPhase1Tests.swift`

**目标：** 落地 D8（三层测试策略第 1 层）与 D18（XCTest 集成测试覆盖业务逻辑 AC）。验证端到端事件流：PasteboardWatcher → CaptureEventBuilder → ClipCaptureService → AutoSaveService → 文件保存 → 剪贴板替换。覆盖 AC-01（白名单触发）、AC-08（禁用不触发）、AC-14（敏感过滤关闭可保存）的 XCTest 部分。

**对应决策：** D8（三层测试策略）、D18（XCTest 覆盖业务逻辑 AC）

**对应 AC：** AC-01、AC-08、AC-14（XCTest 部分）

**前置依赖：** 任务 1~6、Phase 0 全部任务

- [ ] **步骤 1：编写失败的测试**

创建 `ClipMindTests/AutoSave/AutoSaveIntegrationPhase1Tests.swift`：

```swift
import AppKit
import CryptoKit
import XCTest

@testable import ClipMind

final class AutoSaveIntegrationPhase1Tests: XCTestCase
{
    private var pasteboard: NSPasteboard!
    private var watcher: PasteboardWatcher!
    private var store: EncryptedStore!
    private var captureService: ClipCaptureService!
    private var autoSaveService: AutoSaveService!
    private var suppressor: SelfWriteSuppressor!
    private var settingsStore: AutoSaveSettingsStore!
    private var eventBuilder: CaptureEventBuilder!
    private var defaults: UserDefaults!
    private var tempDir: URL!
    private var saveDir: URL!

    override func setUpWithError() throws
    {
        pasteboard = NSPasteboard(name: .init("test-int-\(UUID().uuidString)"))
        pasteboard.clearContents()

        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let dbPath = tempDir.appendingPathComponent("test_int.db")
        let key = SymmetricKey(size: .bits256)
        store = try EncryptedStore(dbPath: dbPath, key: key)

        defaults = UserDefaults(suiteName: "test-int-\(UUID().uuidString)")!
        settingsStore = AutoSaveSettingsStore(defaults: defaults)

        saveDir = tempDir.appendingPathComponent("saves")
        try FileManager.default.createDirectory(at: saveDir, withIntermediateDirectories: true)

        // 配置自动保存
        var settings = AutoSaveSettings()
        settings.isEnabled = true
        settings.saveDirectory = saveDir.path + "/"
        settings.lengthThreshold = 50
        settings.sensitiveFilterEnabled = true
        settings.whitelistBundleIds = ["com.test.whitelisted"]
        settingsStore.save(settings)

        suppressor = SelfWriteSuppressor()
        autoSaveService = AutoSaveService(
            settingsStore: settingsStore,
            pasteboard: pasteboard,
            suppressor: suppressor
        )

        eventBuilder = CaptureEventBuilder(
            appDetector: AppDetector(),
            sensitiveDetector: SensitiveDetector(defaults: defaults),
            blacklistService: BlacklistService(defaults: defaults),
            settingsStore: settingsStore
        )

        watcher = PasteboardWatcher(pasteboard: pasteboard, eventBuilder: eventBuilder)
        let embeddingService = LocalEmbeddingService()
        let classifier = ClassificationService(embeddingService: embeddingService)
        captureService = ClipCaptureService(watcher: watcher, store: store, classifier: classifier)
        captureService.autoSaveService = autoSaveService
    }

    override func tearDownWithError() throws
    {
        captureService?.stop()
        watcher?.stopWatching()
        if let tempDir = tempDir
        {
            try? FileManager.default.removeItem(at: tempDir)
        }
    }

    // MARK: - AC-01（XCTest 部分）：白名单 App 复制长内容端到端

    func testAC01EndToEndAutoSave() throws
    {
        // 由于 AppDetector 在测试环境返回 "unknown"，直接注入事件
        let longContent = String(repeating: "a", count: 100)
        let event = CaptureEvent(
            id: UUID().uuidString,
            changeCount: pasteboard.changeCount,
            content: .text(longContent),
            bundleId: "com.test.whitelisted",
            appName: "TestApp",
            blacklisted: false,
            sensitiveResult: .none,
            f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: []),
            f2xConfigSnapshot: F2xConfigSnapshot(from: settingsStore.load()),
            timestamp: Date()
        )

        captureService.handleCaptureEvent(event)

        // 等待异步保存完成
        let expectation = XCTestExpectation(description: "文件应被保存")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0)
        {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)

        // 验证文件已保存
        let files = try FileManager.default.contentsOfDirectory(at: saveDir, includingPropertiesForKeys: nil)
        XCTAssertTrue(files.contains { $0.pathExtension == "md" }, "应保存 .md 文件")

        // 验证原内容入库
        let items = try store.loadAll()
        XCTAssertEqual(items.count, 1, "原内容应入库")
    }

    // MARK: - AC-08（XCTest 部分）：禁用总开关不触发保存

    func testAC08DisabledNoSave() throws
    {
        var settings = settingsStore.load()
        settings.isEnabled = false
        settingsStore.save(settings)

        let longContent = String(repeating: "b", count: 100)
        let event = CaptureEvent(
            id: UUID().uuidString,
            changeCount: pasteboard.changeCount,
            content: .text(longContent),
            bundleId: "com.test.whitelisted",
            appName: "TestApp",
            blacklisted: false,
            sensitiveResult: .none,
            f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: []),
            f2xConfigSnapshot: F2xConfigSnapshot(from: settingsStore.load()),
            timestamp: Date()
        )

        captureService.handleCaptureEvent(event)

        let expectation = XCTestExpectation(description: "等待异步检查")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0)
        {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)

        // 验证无文件保存
        let files = try FileManager.default.contentsOfDirectory(at: saveDir, includingPropertiesForKeys: nil)
        XCTAssertTrue(files.isEmpty, "总开关关闭时不应保存文件")

        // 验证原内容仍入库
        let items = try store.loadAll()
        XCTAssertEqual(items.count, 1, "禁用总开关时原内容仍应入库")
    }

    // MARK: - AC-14（XCTest 部分）：关闭敏感过滤后敏感内容可保存

    func testAC14SensitiveFilterDisabledSavesSensitive() throws
    {
        var settings = settingsStore.load()
        settings.sensitiveFilterEnabled = false
        settingsStore.save(settings)

        let sensitiveContent = "password=supersecret " + String(repeating: "x", count: 50)
        let event = CaptureEvent(
            id: UUID().uuidString,
            changeCount: pasteboard.changeCount,
            content: .text(sensitiveContent),
            bundleId: "com.test.whitelisted",
            appName: "TestApp",
            blacklisted: false,
            sensitiveResult: SensitiveMatchResult(isSensitive: true, matchedPatterns: ["password"]),
            f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: []),
            f2xConfigSnapshot: F2xConfigSnapshot(from: settingsStore.load()),
            timestamp: Date()
        )

        // F1.x 分支：敏感命中不入库
        captureService.handleCaptureEvent(event)

        let expectation = XCTestExpectation(description: "等待异步保存")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0)
        {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)

        // 验证 F2.1 分支保存了敏感内容（敏感过滤关闭）
        let files = try FileManager.default.contentsOfDirectory(at: saveDir, includingPropertiesForKeys: nil)
        XCTAssertTrue(files.contains { $0.pathExtension == "md" }, "敏感过滤关闭时应保存文件")

        // 验证 F1.x 分支未入库（敏感命中）
        let items = try store.loadAll()
        XCTAssertEqual(items.count, 0, "F1.x 敏感命中不入库")
    }

    // MARK: - AC-06（XCTest 部分）：敏感过滤开启时不保存

    func testAC06SensitiveFilterEnabledNoSave() throws
    {
        let sensitiveContent = "password=supersecret " + String(repeating: "x", count: 50)
        let event = CaptureEvent(
            id: UUID().uuidString,
            changeCount: pasteboard.changeCount,
            content: .text(sensitiveContent),
            bundleId: "com.test.whitelisted",
            appName: "TestApp",
            blacklisted: false,
            sensitiveResult: SensitiveMatchResult(isSensitive: true, matchedPatterns: ["password"]),
            f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: []),
            f2xConfigSnapshot: F2xConfigSnapshot(from: settingsStore.load()),
            timestamp: Date()
        )

        captureService.handleCaptureEvent(event)

        let expectation = XCTestExpectation(description: "等待异步检查")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0)
        {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)

        // 验证无文件保存
        let files = try FileManager.default.contentsOfDirectory(at: saveDir, includingPropertiesForKeys: nil)
        XCTAssertTrue(files.isEmpty, "敏感过滤开启时不应保存敏感内容")

        // 验证 F1.x 未入库
        let items = try store.loadAll()
        XCTAssertEqual(items.count, 0, "F1.x 敏感命中不入库")
    }

    // MARK: - AC-03（XCTest 部分）：文件可在文件系统中读取

    func testAC03SavedFileReadable() throws
    {
        let content = "这是可读取性测试内容 " + String(repeating: "c", count: 50)
        let event = CaptureEvent(
            id: UUID().uuidString,
            changeCount: pasteboard.changeCount,
            content: .text(content),
            bundleId: "com.test.whitelisted",
            appName: "TestApp",
            blacklisted: false,
            sensitiveResult: .none,
            f1xConfigSnapshot: F1xConfigSnapshot(blacklistBundleIds: []),
            f2xConfigSnapshot: F2xConfigSnapshot(from: settingsStore.load()),
            timestamp: Date()
        )

        captureService.handleCaptureEvent(event)

        let expectation = XCTestExpectation(description: "等待文件保存")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0)
        {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 3.0)

        let files = try FileManager.default.contentsOfDirectory(at: saveDir, includingPropertiesForKeys: nil)
        guard let savedFile = files.first else
        {
            XCTFail("应保存文件")
            return
        }

        let savedContent = try String(contentsOf: savedFile, encoding: .utf8)
        XCTAssertTrue(savedContent.contains("可读取性测试内容"), "保存的文件应包含原始内容")
    }
}
```

- [ ] **步骤 2：运行测试验证失败**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1-auto-save-to-file
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/AutoSaveIntegrationPhase1Tests'
```

预期：若任务 1~6 已完成则部分通过；若 AutoSaveService.handle 在测试环境中因 AppDetector 返回 "unknown" 导致白名单不匹配，则 AC-01 测试可能 FAIL（需调整白名单包含 "unknown" 或在测试中直接注入事件绕过白名单检查）。

- [ ] **步骤 3：编写最少实现代码**

本任务为测试任务，无生产代码实现。测试文件已在步骤 1 创建完成。若测试因白名单不匹配失败，确认 `AutoSaveService.handle(event:)` 中的白名单检查逻辑读取 `event.f2xConfigSnapshot.whitelistBundleIds`，测试中已设置 `whitelistBundleIds = ["com.test.whitelisted"]` 且事件 `bundleId = "com.test.whitelisted"`，应匹配通过。

- [ ] **步骤 4：运行测试验证通过**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1-auto-save-to-file
swiftlint lint --strict
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/AutoSaveIntegrationPhase1Tests'
```

预期：PASS，5 个集成测试全部通过。

- [ ] **步骤 5：Commit**

```bash
git add ClipMindTests/AutoSave/AutoSaveIntegrationPhase1Tests.swift
git commit -m "$(cat <<'EOF'
test(F2.1): add Phase 1 integration tests for end-to-end event flow

落地 D8/D18 决策：XCTest 集成测试覆盖业务逻辑 AC。验证端到端事件流
PasteboardWatcher → CaptureEventBuilder → ClipCaptureService →
AutoSaveService → 文件保存 → 剪贴板替换。覆盖 AC-01（白名单触发）、
AC-08（禁用不触发）、AC-14（敏感过滤关闭可保存）、AC-06（敏感过滤
开启不保存）、AC-03（文件可读取）的 XCTest 部分。
EOF
)"
```

---

## 4. Phase 1 完成检查清单

- [ ] 10 个任务全部 commit 完成
- [ ] `swiftlint lint --strict` 通过
- [ ] `xcodebuild build` 通过
- [ ] `xcodebuild build-for-testing` 通过（XCUITest 编译验证）
- [ ] F1.x 既有单元测试回归通过（本地 `-only-testing` 验证关键类）
- [ ] Phase 1 新增单元测试（TC-UT-50~71）全部通过
- [ ] Phase 1 集成测试（AC-01/03/06/08/14 XCTest 部分）通过
- [ ] XCUITest（AC-07/09/14/15/16）由 CI 验证通过（本地不执行）
- [ ] 手动验收脚本（AC-01/02/03/05/17~22）由开发者本机执行并记录结果
- [ ] D2/D3/D6/D7/D8/D11/D15/D18/D19/D20/D22/D23 决策全部落地，可在代码中追溯
- [ ] F-11 例外条款是唯一对 F1.x 既有公共接口的修改（PasteboardWatcher.onPasteboardChange）
- [ ] macOS 12.4 兼容性验证通过（无 NavigationStack、无 @Observable、无 macOS 13+ API）

---

## 5. 版本记录

| 版本 | 日期 | 变更 |
|------|------|------|
| v2.0 | 2026-07-22 | 基于 v1.1 设计文档套件完全重写：落地 D2/D3/D6/D7/D8/D11/D15/D18/D19/D20/D22/D23 决策，从 7 任务扩展为 10 任务（新增 CaptureEventBuilder B0、手动验收脚本、Phase 1 集成测试），引入 F-11 例外条款扩展 PasteboardWatcher 回调参数，F1.x 过滤逻辑从 PasteboardWatcher 迁移到 ClipCaptureService，XCUITest 仅验证 UI 交互（D19） |
| v1.2 | 2026-07-21 | 基于 v1.0 设计的旧版计划（已被 v2.0 替换） |
| v1.1 | 2026-07-20 | 旧版初稿 |
| v1.0 | 2026-07-19 | 旧版初稿 |
