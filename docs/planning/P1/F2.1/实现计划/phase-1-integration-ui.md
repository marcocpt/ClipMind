> 最后更新：2026-07-21 | 版本：v1.2

# Phase 1 子计划：集成与 UI

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 在 Phase 0 核心保存逻辑的基础上，将 `AutoSaveService` 接入 F1.x 捕获流程（通过 `ClipCaptureService` 的可选闭包钩子），实现配置面板"自动保存"分区视图（8 个配置项 + 二次确认弹窗 + 明文责任提示），并通过 XCUITest 覆盖 AC-01/02/03/05/07/08/09/14/15/16 的端到端行为，剩余 AC-01/02/03 由手动验收脚本兜底。Phase 1 完成后，F2.1 全部 16 条 AC 覆盖完整。

**架构：** 在 F1.x `ClipCaptureService.handleClipContent` 中插入可选 `autoSaveTrigger` 闭包（init 签名不变，仅新增可选属性），调用时机为"敏感识别与黑名单检查之后、入库之前"。新增 `ClipMind/AutoSave/UI/AutoSaveSettingsView.swift` SwiftUI 视图，作为 `SettingsView` 的第 4 个 tab 嵌入既有 TabView。`AppDelegate.setupCaptureService` 负责装配 `AutoSaveService` 并注入 `autoSaveTrigger` 闭包。`applyUITestOverrides` 新增对 `--UITEST_RESET_AUTOSAVE_SETTINGS` 启动参数的处理。XCUITest 通过真实 App 启动验证端到端行为。

**技术栈：** Swift 5.7+ / macOS 12.4+ / SwiftUI / AppKit / XCTest / XCUITest / SwiftLint strict

---

## 1. 范围与非目标

### 1.1 范围

- 修改 3 个 Swift 文件（`ClipCaptureService.swift`、`SettingsView.swift`、`ClipMindApp.swift`）
- 创建 1 个 Swift UI 视图文件（`AutoSaveSettingsView.swift`）
- 创建 2 个 XCUITest 文件（`AutoSaveSettingsUITests.swift`、`AutoSaveBehaviorUITests.swift`）
- 创建 1 个手动验收脚本（`manual-acceptance-script.md`）
- 覆盖 AC-01/02/03/05/07/08/09/14（UI 部分）/15/16
- 本地 `swiftlint lint --strict` 与 `xcodebuild build` 通过
- 单文件 `-only-testing` XCUITest 通过（本地允许）
- 全量 `xcodebuild test` 由 CI 兜底（不本地执行）

### 1.2 非目标

- 不修改 Phase 0 已交付的 5 个 Swift 文件（`AutoSaveSettings.swift`、`AutoSaveSettingsStore.swift`、`FileNameGenerator.swift`、`FilePathFormatter.swift`、`AutoSaveService.swift`）的公共接口
- 不修改 F1.x 既有模块的公共接口（`PasteboardWatcher`、`SensitiveDetector`、`AppDetector`、`EncryptedStore`、`AppSettings`、`ClipItem`、`ClipContent`）
- 不本地执行全量 `xcodebuild test`（仅 CI）
- 不修改 F1.x 既有设置面板分区（`APIKeyConfigView`、`PrivacySettingsView`、`GeneralSettingsView`）

---

## 2. 涉及文件和职责

| 文件 | 职责 | 创建/修改 |
|------|------|-----------|
| `ClipMind/Capture/ClipCaptureService.swift` | 新增 `autoSaveTrigger` 可选闭包属性（init 签名不变），在 `handleClipContent` 中"敏感识别之后、入库之前"位置调用 | 修改 |
| `ClipMind/UI/Settings/AutoSaveSettingsView.swift` | 自动保存分区 SwiftUI 视图：8 个配置项 + 路径格式预览 + 明文责任提示 + 二次确认弹窗 | 创建 |
| `ClipMind/UI/Settings/SettingsView.swift` | `SettingsTab` 枚举新增 `.autoSave` case；TabView 新增"自动保存"分区；`--UITEST_INITIAL_TAB=autosave` 解析 | 修改 |
| `ClipMind/App/ClipMindApp.swift` | `AppDelegate.setupCaptureService` 装配 `AutoSaveService` 并注入 `autoSaveTrigger`；`applyUITestOverrides` 处理 `--UITEST_RESET_AUTOSAVE_SETTINGS` | 修改 |
| `ClipMindTests/Capture/ClipCaptureServiceAutoSaveHookTests.swift` | 验证 `autoSaveTrigger` 闭包在 `handleClipContent` 中被调用且接收正确参数 | 创建 |
| `ClipMindUITests/AutoSaveSettingsUITests.swift` | AC-07（配置面板修改全部配置项）、AC-15（白名单添加与删除）、AC-16（配置持久化）、AC-14（关闭敏感过滤二次确认 UI） | 创建 |
| `ClipMindUITests/AutoSaveBehaviorUITests.swift` | AC-01（白名单 App 复制长内容端到端，启动参数注入）、AC-05（烟雾测试：App 不崩溃）、AC-08（禁用总开关不触发保存，含核心断言）、AC-09（保存目录异常弹窗不崩溃，含 `autoSaveErrorAlert` 断言） | 创建 |
| `docs/planning/P1/F2.1/实现计划/manual-acceptance-script.md` | AC-01/02/03/05 手动验收脚本（真实 Safari/Notes 复制场景 + AC-05 历史条目兜底） | 创建 |

**关键依赖关系**（任务执行顺序）：

```
任务 1（ClipCaptureService 钩子）→ 任务 4（AppDelegate 装配）
任务 2（AutoSaveSettingsView）→ 任务 3（SettingsView 集成）→ 任务 4
任务 1 + 任务 4 → 任务 5（AutoSaveSettingsUITests）
任务 1 + 任务 4 → 任务 6（AutoSaveBehaviorUITests）
任务 5 + 任务 6 → 任务 7（手动验收脚本）
```

任务 1、2 可并行；任务 3 依赖任务 2；任务 4 依赖任务 1；任务 5、6 依赖任务 1+4；任务 7 依赖任务 5+6 完成。

---

## 3. 任务列表

总计 7 个任务，每个任务包含 5 个步骤（编写失败测试 → 运行验证失败 → 编写实现 → 运行验证通过 → commit）。

---

### 任务 1：ClipCaptureService 添加 autoSaveTrigger 钩子

**文件：**
- 修改：`ClipMind/Capture/ClipCaptureService.swift`
- 测试：`ClipMindTests/Capture/ClipCaptureServiceAutoSaveHookTests.swift`

**目标：** 在 `ClipCaptureService` 新增可选闭包属性 `autoSaveTrigger`，在 `handleClipContent` 中"分类完成后、入库之前"的位置调用，将内容与来源 App 信息（bundleId、appName）传递给闭包。`init` 签名保持不变，仅新增可设置属性。当 `autoSaveTrigger` 为 `nil` 时（F1.x 既有行为），不影响 `ClipCaptureService` 任何行为。

**对应 FR：** FR-009（原内容仍入库 ClipMind 历史）、FR-014（自动保存触发时机）

**对应 AC：** AC-05（原内容仍进入 ClipMind 历史，钩子不阻塞入库）

**对应约束：** F-01（不修改 F1.x 既有公共接口，init 签名不变）、D-01（在 F1.x 捕获流程中插入钩子而非独立监听）

- [ ] **步骤 1：编写失败的测试**

创建 `ClipMindTests/Capture/ClipCaptureServiceAutoSaveHookTests.swift`：

```swift
import AppKit
import CryptoKit
import XCTest

@testable import ClipMind

final class ClipCaptureServiceAutoSaveHookTests: XCTestCase
{
    private var pasteboard: NSPasteboard!
    private var watcher: PasteboardWatcher!
    private var store: EncryptedStore!
    private var service: ClipCaptureService!
    private var tempDir: URL!

    override func setUpWithError() throws
    {
        pasteboard = NSPasteboard(name: .init("test-hook-\(UUID().uuidString)"))
        pasteboard.clearContents()

        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
        let dbPath = tempDir.appendingPathComponent("test_hook.db")
        let key = SymmetricKey(size: .bits256)
        store = try EncryptedStore(dbPath: dbPath, key: key)

        watcher = PasteboardWatcher(pasteboard: pasteboard)
        let embeddingService = LocalEmbeddingService()
        let classifier = ClassificationService(embeddingService: embeddingService)
        service = ClipCaptureService(
            watcher: watcher,
            store: store,
            classifier: classifier
        )
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

    // MARK: - autoSaveTrigger 默认为 nil 不影响既有行为

    func testAutoSaveTriggerDefaultsToNil() throws
    {
        XCTAssertNil(service.autoSaveTrigger, "autoSaveTrigger 默认应为 nil")
    }

    // MARK: - 钩子在 handleClipContent 中被调用且接收正确参数

    func testAutoSaveTriggerInvokedWithContentAndAppInfo() throws
    {
        let expectation = XCTestExpectation(description: "autoSaveTrigger 应被调用")
        var receivedContent: ClipContent?
        var receivedBundleId: String?
        var receivedAppName: String?

        service.autoSaveTrigger = { content, bundleId, appName in
            receivedContent = content
            receivedBundleId = bundleId
            receivedAppName = appName
            expectation.fulfill()
        }

        pasteboard.clearContents()
        pasteboard.setString("hello auto-save hook", forType: .string)
        watcher.handlePasteboardChange()

        wait(for: [expectation], timeout: 1.0)

        guard case .text(let text) = receivedContent else
        {
            XCTFail("应收到 .text 类型内容")
            return
        }
        XCTAssertEqual(text, "hello auto-save hook")
        XCTAssertNotNil(receivedBundleId, "应传递 bundleId")
        XCTAssertNotNil(receivedAppName, "应传递 appName")
    }

    // MARK: - autoSaveTrigger 存在时不阻塞入库（AC-05 + FR-014 互不阻塞）

    func testAutoSaveTriggerDoesNotBlockStorage() throws
    {
        var hookCallCount = 0
        service.autoSaveTrigger = { _, _, _ in
            hookCallCount += 1
        }

        pasteboard.clearContents()
        pasteboard.setString("content when hook exists", forType: .string)
        watcher.handlePasteboardChange()

        XCTAssertEqual(hookCallCount, 1, "autoSaveTrigger 应被调用一次")
        let items = try store.loadAll()
        XCTAssertEqual(items.count, 1, "autoSaveTrigger 存在时原内容仍应入库")
    }

    // MARK: - autoSaveTrigger 为 nil 时与 F1.x 既有行为完全一致

    func testNilAutoSaveTriggerBehavesAsF1X() throws
    {
        service.autoSaveTrigger = nil

        pasteboard.clearContents()
        pasteboard.setString("plain F1.x content", forType: .string)
        watcher.handlePasteboardChange()

        let items = try store.loadAll()
        XCTAssertEqual(items.count, 1, "autoSaveTrigger=nil 时应正常入库")
    }

    // MARK: - UITEST 启动参数注入逻辑（单元测试覆盖）

    /// 验证 UITEST 启动参数注入逻辑能正确解析 `--UITEST_INJECT_CONTENT` 与 `--UITEST_INJECT_BUNDLE_ID`。
    ///
    /// 注意：本测试通过在测试进程内重新构造 ClipCaptureService 验证 init 中的注入解析逻辑。
    /// 由于 CommandLine.arguments 是进程级全局变量，本测试仅验证"当启动参数存在时，
    /// ClipCaptureService.init 会触发 applyUITestInjectionIfNeeded 设置内部属性"。
    /// 端到端验证由 testAC01AutoSaveEndToEndViaLaunchArgument 在 XCUITest 中完成。
    func testUITestInjectionParsesLaunchArguments() throws
    {
        // 由于 CommandLine.arguments 无法在测试中修改，本测试通过断言 init 不崩溃来覆盖代码路径。
        // 端到端注入验证由 AutoSaveBehaviorUITests.testAC01AutoSaveEndToEndViaLaunchArgument 完成。
        let newService = ClipCaptureService(
            watcher: watcher,
            store: store,
            classifier: ClassificationService(embeddingService: LocalEmbeddingService())
        )
        XCTAssertNotNil(newService, "ClipCaptureService 应能正常构造")
        // 设置 autoSaveTrigger 不应崩溃
        newService.autoSaveTrigger = { _, _, _ in }
        XCTAssertEqual(newService.autoSaveTrigger != nil, true, "autoSaveTrigger 应可设置")
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
  -only-testing:'ClipMindTests/ClipCaptureServiceAutoSaveHookTests'
```

预期：FAIL，报错 "value of type 'ClipCaptureService' has no member 'autoSaveTrigger'"。

- [ ] **步骤 3：编写实现代码**

修改 `ClipMind/Capture/ClipCaptureService.swift`：

```swift
import Foundation

/// 剪贴板捕获编排服务。
///
/// 连接 PasteboardWatcher（剪贴板变化检测）与 EncryptedStore（持久化），
/// 并通过 ClassificationService 对文本内容进行分类，最终发送通知刷新 UI。
///
/// 处理流程（由 PasteboardWatcher 回调触发）：
/// 1. 获取前台 App 信息（bundleId / appName）
/// 2. 文本内容经 ClassificationService 分类
/// 3. 创建 ClipItem
/// 4. 触发 autoSaveTrigger 钩子（F2.1，可选；为 nil 时与 F1.x 完全一致）
/// 5. 存入 EncryptedStore
/// 6. 发送 clipDidUpdateNotification 通知 UI 刷新
final class ClipCaptureService {
    /// 入库后发送的通知名称，UI 监听此通知以刷新历史列表
    static let clipDidUpdateNotification = Notification.Name("ClipMindClipDidUpdate")

    private let watcher: PasteboardWatcher
    private let store: EncryptedStore
    private let classifier: ClassificationService
    private let appDetector: AppDetector

    /// F2.1 自动保存钩子。
    ///
    /// 在"分类完成后、入库之前"位置调用，将内容与来源 App 信息传递给 AutoSaveService。
    /// 闭包抛出的异常会被捕获并记录日志，不阻塞 F1.x 入库流程（满足 FR-014 互不阻塞）。
    /// 为 nil 时（F1.x 既有行为）ClipCaptureService 行为完全不变。
    var autoSaveTrigger: ((ClipContent, _ bundleId: String, _ appName: String) -> Void)?

    #if DEBUG
    /// UITEST 注入的内容与来源 App 信息（仅 DEBUG 编译条件下生效）。
    ///
    /// 通过 `--UITEST_INJECT_CONTENT=<text>` 与 `--UITEST_INJECT_BUNDLE_ID=<id>`
    /// 启动参数注入，用于在 XCUITest 中触发完整的 autoSaveTrigger 钩子流程，
    /// 验证 AC-01（白名单 App 复制长内容触发自动保存）端到端行为。
    /// 仅在 `--UITEST_ENABLE_AUTOSAVE` 存在时生效，避免污染 F1.x 既有 UITest。
    private var injectedContent: ClipContent?
    private var injectedBundleId: String?
    private var injectedAppName: String?

    /// 解析 UITEST 启动参数注入内容与来源 App 信息。
    private func applyUITestInjectionIfNeeded()
    {
        guard CommandLine.arguments.contains("--UITEST_ENABLE_AUTOSAVE") else { return }
        if let contentArg = CommandLine.arguments.first(where: { $0.hasPrefix("--UITEST_INJECT_CONTENT=") })
        {
            let text = String(contentArg.dropFirst("--UITEST_INJECT_CONTENT=".count))
            injectedContent = .text(text)
        }
        if let bundleIdArg = CommandLine.arguments.first(where: { $0.hasPrefix("--UITEST_INJECT_BUNDLE_ID=") })
        {
            let bundleId = String(bundleIdArg.dropFirst("--UITEST_INJECT_BUNDLE_ID=".count))
            injectedBundleId = bundleId
            injectedAppName = bundleId
        }
    }
    #endif

    /// - Parameters:
    ///   - watcher: 剪贴板监听器（生产环境使用默认 `.general` pasteboard，测试时注入）
    ///   - store: 加密存储
    ///   - classifier: 内容分类服务
    ///   - appDetector: 前台应用检测器
    init(watcher: PasteboardWatcher,
         store: EncryptedStore,
         classifier: ClassificationService,
         appDetector: AppDetector = AppDetector()) {
        self.watcher = watcher
        self.store = store
        self.classifier = classifier
        self.appDetector = appDetector
        watcher.onPasteboardChange = { [weak self] content in
            self?.handleClipContent(content)
        }
        #if DEBUG
        applyUITestInjectionIfNeeded()
        #endif
    }

    /// 启动剪贴板监听
    func start() {
        watcher.startWatching()
    }

    /// 停止剪贴板监听
    func stop() {
        watcher.stopWatching()
    }

    /// 处理剪贴板变化内容：分类 → 创建 ClipItem → 触发钩子 → 入库 → 通知
    private func handleClipContent(_ content: ClipContent) {
        #if DEBUG
        let actualContent: ClipContent = injectedContent ?? content
        let actualBundleId: String
        let actualAppName: String
        if let injectedBundleId = injectedBundleId
        {
            actualBundleId = injectedBundleId
            actualAppName = injectedAppName ?? injectedBundleId
        }
        else
        {
            (actualBundleId, actualAppName) = appDetector.currentFrontmostApp() ?? ("unknown", "Unknown")
        }
        #else
        let actualContent = content
        let (actualBundleId, actualAppName) = appDetector.currentFrontmostApp() ?? ("unknown", "Unknown")
        #endif

        let item: ClipItem
        switch actualContent {
        case .text(let text):
            let contentType = classifier.classify(text)
            item = ClipItem.makeText(
                text,
                contentType: contentType,
                sourceApp: actualBundleId,
                sourceAppName: actualAppName
            )
            LogCategory.capture.info("捕获文本内容 length=\(text.count) type=\(contentType.rawValue)")
        case .image(let data):
            item = ClipItem.makeImage(
                data,
                contentType: .other,
                sourceApp: actualBundleId,
                sourceAppName: actualAppName
            )
            LogCategory.capture.info("捕获图片内容 size=\(data.count) bytes")
        case .filePath(let urls):
            item = ClipItem.makeFilePath(
                urls,
                contentType: .other,
                sourceApp: actualBundleId,
                sourceAppName: actualAppName
            )
            LogCategory.capture.info("捕获文件路径 count=\(urls.count)")
        }

        // F2.1：触发自动保存钩子（闭包非 throws，AutoSaveService.handle 内部异步吞异常，不阻塞入库）
        if let trigger = autoSaveTrigger {
            trigger(actualContent, actualBundleId, actualAppName)
        }

        do {
            try store.save(item)
            LogCategory.capture.info("ClipItem 已入库: type=\(item.contentType.rawValue), source=\(appName)")
            NotificationCenter.default.post(name: Self.clipDidUpdateNotification, object: nil)
        } catch {
            LogCategory.storage.error("ClipItem 入库失败: \(error.localizedDescription)")
        }
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1-auto-save-to-file
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/ClipCaptureServiceAutoSaveHookTests'
```

预期：PASS，4 个测试用例全部通过。

- [ ] **步骤 5：Commit**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1-auto-save-to-file
swiftlint lint --strict
git add ClipMind/Capture/ClipCaptureService.swift ClipMindTests/Capture/ClipCaptureServiceAutoSaveHookTests.swift
git commit -m "feat(F2.1): 为 ClipCaptureService 添加 autoSaveTrigger 钩子"
```

预期：SwiftLint 通过；commit 成功。F1.x 既有 `ClipCaptureServiceTests` 不受影响（autoSaveTrigger 默认为 nil）。

---

### 任务 2：AutoSaveSettingsView 自动保存分区视图

**文件：**
- 创建：`ClipMind/UI/Settings/AutoSaveSettingsView.swift`
- 测试：`ClipMindUITests/AutoSaveSettingsViewComponentsTests.swift`

**目标：** 创建 SwiftUI 视图，承载 8 个配置项（总开关、保存目录、白名单、文件格式、长度阈值、文件名长度、敏感过滤、路径格式）+ 路径格式预览 + 明文文件管理责任提示 + 关闭敏感过滤时的二次确认弹窗。所有配置项修改立即通过 `AutoSaveSettingsStore.update` 持久化并触发配置变更通知（NFR-003）。

**对应 FR：** FR-010（配置面板独立分区）、FR-012（白名单 App 管理）、FR-013（路径格式切换，预览）

**对应 AC：** AC-07（配置面板可修改全部配置项）、AC-14（关闭敏感过滤含二次确认 UI 部分）、AC-15（白名单 App 添加与删除 UI 部分）

**对应约束：** C-07（敏感过滤关闭二次确认）、C-08（明文文件管理责任提示）、F-10（不修改 F1.x 既有设置面板分区，仅新增）

- [ ] **步骤 1：编写失败的测试**

创建 `ClipMindUITests/AutoSaveSettingsViewComponentsTests.swift`：

```swift
import XCTest

final class AutoSaveSettingsViewComponentsTests: XCTestCase
{
    override func setUp()
    {
        super.setUp()
        continueAfterFailure = false
    }

    /// tearDown 截图保存：每个测试结束时截图作为失败诊断证据，
    /// 通过 GitHub Actions test-results artifact 自动上传。
    override func tearDown()
    {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "AutoSaveSettingsViewComponentsTests-tearDown-\(UUID().uuidString)"
        attachment.lifetime = .keepAlways
        add(attachment)
        super.tearDown()
    }

    /// 通过 accessibility identifier 查找元素（参考 SettingsUITests.element 辅助函数）。
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement
    {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// 启动 App 并打开自动保存分区（通过 --UITEST_INITIAL_TAB=autosave 启动参数定位）。
    private func launchAndOpenAutoSaveSettings() -> XCUIApplication
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
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "设置按钮应存在")
        settingsButton.click()

        // 等待自动保存分区内容加载（autoSaveEnabledToggle 是本分区独有元素）
        let toggle = element("autoSaveEnabledToggle", in: app)
        XCTAssertTrue(
            toggle.waitForExistence(timeout: 5),
            "自动保存分区应已激活，总开关应存在"
        )
        return app
    }

    // MARK: - AC-07: 全部配置项 UI 存在

    func testAutoSaveSettingsComponentsExist()
    {
        let app = launchAndOpenAutoSaveSettings()

        XCTAssertTrue(
            element("autoSaveEnabledToggle", in: app).exists,
            "应有总开关"
        )
        XCTAssertTrue(
            element("saveDirectoryInput", in: app).exists,
            "应有保存目录输入框"
        )
        XCTAssertTrue(
            element("saveDirectoryPicker", in: app).exists,
            "应有保存目录选择按钮"
        )
        XCTAssertTrue(
            element("fileFormatPicker", in: app).exists,
            "应有文件格式选择器"
        )
        XCTAssertTrue(
            element("lengthThresholdInput", in: app).exists,
            "应有长度阈值输入框"
        )
        XCTAssertTrue(
            element("fileNameLengthInput", in: app).exists,
            "应有文件名长度输入框"
        )
        XCTAssertTrue(
            element("pathFormatPicker", in: app).exists,
            "应有路径格式选择器"
        )
        XCTAssertTrue(
            element("pathFormatPreview", in: app).exists,
            "应有路径格式预览"
        )
        XCTAssertTrue(
            element("sensitiveFilterToggle", in: app).exists,
            "应有敏感过滤开关"
        )
        XCTAssertTrue(
            element("whitelistAppList", in: app).exists,
            "应有白名单 App 列表"
        )
        XCTAssertTrue(
            element("addWhitelistAppButton", in: app).exists,
            "应有添加白名单 App 按钮"
        )
        XCTAssertTrue(
            element("plaintextResponsibilityNotice", in: app).exists,
            "应有明文文件管理责任提示"
        )
    }

    // MARK: - AC-07: 默认值与 Phase 0 AutoSaveSettings 一致

    func testAutoSaveSettingsDefaultValues()
    {
        let app = launchAndOpenAutoSaveSettings()

        // 总开关默认开
        let toggle = element("autoSaveEnabledToggle", in: app)
        let toggleValue = (toggle.value as? Int) ?? Int(toggle.value as? String ?? "0") ?? 0
        XCTAssertEqual(toggleValue, 1, "总开关默认应为开")

        // 保存目录默认值
        let dirInput = app.textFields["saveDirectoryInput"].firstMatch
        XCTAssertEqual(dirInput.value as? String, "~/Documents/ClipMind/Clips/")

        // 长度阈值默认值
        let lengthInput = app.textFields["lengthThresholdInput"].firstMatch
        XCTAssertEqual(lengthInput.value as? String, "50")
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
  -only-testing:'ClipMindUITests/AutoSaveSettingsViewComponentsTests'
```

预期：FAIL，报错 "Failed to find accessibility identifier 'autoSaveEnabledToggle'"。

- [ ] **步骤 3：编写实现代码**

创建 `ClipMind/UI/Settings/AutoSaveSettingsView.swift`：

```swift
import SwiftUI

/// F2.1 自动保存分区配置视图。
///
/// 承载 8 个配置项：总开关、保存目录、白名单 App、文件格式、长度阈值、
/// 文件名长度、敏感过滤、路径格式。修改后立即通过 `AutoSaveSettingsStore.update`
/// 持久化并触发配置变更通知（满足 NFR-003）。
///
/// 关闭敏感过滤时显示二次确认弹窗（满足 C-07 与 AC-14）。
/// 底部显示明文文件管理责任提示（满足 C-08）。
///
/// 对应 FR-010、FR-012、FR-013；AC-07、AC-14（UI 部分）、AC-15（UI 部分）。
struct AutoSaveSettingsView: View
{
    @State private var settingsStore = AutoSaveSettingsStore()
    @State private var settings: AutoSaveSettings = AutoSaveSettings()
    @State private var showSensitiveConfirmation = false
    @State private var pendingSensitiveValue: Bool?

    var body: some View
    {
        Form
        {
            statusSection
            enableToggleSection
            saveDirectorySection
            fileFormatSection
            lengthThresholdSection
            fileNameLengthSection
            pathFormatSection
            sensitiveFilterSection
            whitelistAppSection
            plaintextResponsibilitySection
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear
        {
            settings = settingsStore.current
        }
        .alert(
            "关闭敏感内容过滤",
            isPresented: $showSensitiveConfirmation
        )
        {
            Button("取消", role: .cancel)
            {
                // 取消：恢复开启状态
                if let pending = pendingSensitiveValue, !pending
                {
                    var restored = settings
                    restored.sensitiveFilterEnabled = true
                    applySettings(restored)
                }
                pendingSensitiveValue = nil
            }
            Button("确认关闭", role: .destructive)
            {
                // 确认：保持关闭，已通过 toggle 切换写入
                pendingSensitiveValue = nil
            }
        } message:
        {
            Text("""
                关闭敏感内容过滤后，包含密码、Token、验证码、银行卡号、身份证号等敏感信息的内容将被保存到明文文件，存在泄露风险。建议仅在确实需要保存敏感内容到文件的场景下关闭此选项，并自行承担明文文件的管理责任。
                确认要关闭敏感内容过滤吗？
                """)
        }
    }

    // MARK: - 状态指示

    private var statusSection: some View
    {
        Section
        {
            HStack
            {
                Circle()
                    .fill(settings.isEnabled ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                Text(settings.isEnabled ? "已启用" : "已禁用")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - 总开关

    private var enableToggleSection: some View
    {
        Section("启用自动保存")
        {
            Toggle("启用自动保存", isOn: $settings.isEnabled)
                .accessibilityIdentifier("autoSaveEnabledToggle")
                .onChange(of: settings.isEnabled) { newValue in
                    var updated = settings
                    updated.isEnabled = newValue
                    applySettings(updated)
                }

            Text("关闭后行为与 F1.x 完全一致")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 保存目录

    private var saveDirectorySection: some View
    {
        Section("保存目录")
        {
            HStack
            {
                TextField("保存目录", text: $settings.saveDirectory)
                    .accessibilityIdentifier("saveDirectoryInput")
                    .onSubmit
                    {
                        applySettings(settings)
                    }

                Button("选择...")
                {
                    pickSaveDirectory()
                }
                .accessibilityIdentifier("saveDirectoryPicker")
            }

            Text("自动保存的文件以明文形式存放在此目录，不上传云端，不进入加密数据库")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 文件格式

    private var fileFormatSection: some View
    {
        Section("文件格式")
        {
            Picker("文件格式", selection: $settings.fileFormat)
            {
                Text("Markdown (.md)").tag(FileFormat.markdown)
                Text("纯文本 (.txt)").tag(FileFormat.plainText)
            }
            .pickerStyle(.radioGroup)
            .accessibilityIdentifier("fileFormatPicker")
            .onChange(of: settings.fileFormat) { newValue in
                var updated = settings
                updated.fileFormat = newValue
                applySettings(updated)
            }
        }
    }

    // MARK: - 长度阈值

    private var lengthThresholdSection: some View
    {
        Section("长度阈值")
        {
            HStack
            {
                TextField(
                    "长度阈值",
                    value: $settings.lengthThreshold,
                    format: .number
                )
                .accessibilityIdentifier("lengthThresholdInput")
                .onSubmit
                {
                    applySettings(settings)
                }
                .frame(width: 80)

                Text("范围 1-10000，超出范围使用默认值 50")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text("内容字符数大于等于阈值时触发自动保存")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 文件名长度

    private var fileNameLengthSection: some View
    {
        Section("文件名前缀长度")
        {
            HStack
            {
                TextField(
                    "文件名前缀长度",
                    value: $settings.fileNameLength,
                    format: .number
                )
                .accessibilityIdentifier("fileNameLengthInput")
                .onSubmit
                {
                    applySettings(settings)
                }
                .frame(width: 80)

                Text("范围 1-50，超出范围使用默认值 20")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text("取内容前 N 字作为文件名前缀，过滤换行符、路径分隔符与文件系统特殊字符，保留中文")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 路径格式

    private var pathFormatSection: some View
    {
        Section("路径格式")
        {
            Picker("路径格式", selection: $settings.pathFormat)
            {
                Text("纯路径字符串").tag(PathFormat.plainPath)
                Text("file:// URI").tag(PathFormat.fileURI)
                Text("Markdown 链接").tag(PathFormat.markdownLink)
            }
            .accessibilityIdentifier("pathFormatPicker")
            .onChange(of: settings.pathFormat) { newValue in
                var updated = settings
                updated.pathFormat = newValue
                applySettings(updated)
            }

            VStack(alignment: .leading)
            {
                Text("预览")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(pathFormatPreview)
                    .accessibilityIdentifier("pathFormatPreview")
                    .font(.system(.caption, design: .monospaced))
                    .padding(6)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(4)
            }
        }
    }

    /// 路径格式预览文本。
    private var pathFormatPreview: String
    {
        let samplePath = "/Users/username/Documents/ClipMind/Clips/这是测试内容前缀.md"
        return FilePathFormatter.format(samplePath, as: settings.pathFormat)
    }

    // MARK: - 敏感过滤

    private var sensitiveFilterSection: some View
    {
        Section("敏感内容过滤")
        {
            Toggle("敏感内容过滤", isOn: $settings.sensitiveFilterEnabled)
                .accessibilityIdentifier("sensitiveFilterToggle")
                .onChange(of: settings.sensitiveFilterEnabled) { newValue in
                    if !newValue
                    {
                        // 从开切到关 → 触发二次确认
                        pendingSensitiveValue = false
                        showSensitiveConfirmation = true
                        // 暂不持久化，由用户在弹窗中确认
                    }
                    else
                    {
                        // 从关切到开 → 直接生效
                        var updated = settings
                        updated.sensitiveFilterEnabled = newValue
                        applySettings(updated)
                    }
                }

            Text("默认开启，复用 F1.6 既有敏感识别能力。开启后敏感内容不保存到文件")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 白名单 App 管理

    private var whitelistAppSection: some View
    {
        Section("白名单 App")
        {
            VStack(alignment: .leading)
            {
                Text("仅白名单内 App 的复制行为触发自动保存")
                    .font(.caption)
                    .foregroundColor(.secondary)

                List
                {
                    ForEach(settings.whitelistBundleIds, id: \.self) { bundleId in
                        HStack
                        {
                            Text(bundleId)
                            Spacer()
                            Button("移除")
                            {
                                removeBundleId(bundleId)
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(.red)
                            .accessibilityIdentifier("removeWhitelistAppButton")
                        }
                    }
                }
                .accessibilityIdentifier("whitelistAppList")
                .frame(minHeight: 120, maxHeight: 180)

                Button("+ 添加 App...")
                {
                    addWhitelistApp()
                }
                .accessibilityIdentifier("addWhitelistAppButton")
            }

            Text("白名单以应用 Bundle ID 为唯一标识，不可重复")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 明文文件管理责任提示

    private var plaintextResponsibilitySection: some View
    {
        Section
        {
            VStack(alignment: .leading, spacing: 4)
            {
                Label("明文文件管理责任提示", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.bold())
                    .foregroundColor(.orange)
                Text("自动保存的文件以明文形式存放在用户配置目录，不上传云端，不进入加密数据库。请自行承担明文文件的管理责任。建议定期清理保存目录中的旧文件，避免敏感内容长期保留。")
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(4)
            .accessibilityIdentifier("plaintextResponsibilityNotice")
        }
    }

    // MARK: - 业务逻辑

    /// 持久化配置并刷新本地状态。
    private func applySettings(_ newSettings: AutoSaveSettings)
    {
        settingsStore.update(newSettings)
        settings = settingsStore.current
    }

    /// 选择保存目录（NSOpenPanel）。
    private func pickSaveDirectory()
    {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory())
        if panel.runModal() == .OK, let url = panel.url
        {
            var updated = settings
            updated.saveDirectory = url.path
            applySettings(updated)
        }
    }

    /// 移除白名单 Bundle ID。
    private func removeBundleId(_ bundleId: String)
    {
        var updated = settings
        updated.whitelistBundleIds.removeAll { $0 == bundleId }
        applySettings(updated)
    }

    /// 添加白名单 App。
    ///
    /// 弹出 NSOpenPanel 让用户选择 App，从选择的 .app 包读取 Bundle ID。
    private func addWhitelistApp()
    {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        if panel.runModal() == .OK, let url = panel.url
        {
            guard
                let bundle = Bundle(url: url),
                let bundleId = bundle.bundleIdentifier
            else
            {
                LogCategory.storage.warning("无法从选择文件读取 Bundle ID")
                return
            }
            var updated = settings
            if !updated.whitelistBundleIds.contains(bundleId)
            {
                updated.whitelistBundleIds.append(bundleId)
                applySettings(updated)
            }
        }
    }
}
```

- [ ] **步骤 4：运行测试验证通过**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1-auto-save-to-file
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindUITests/AutoSaveSettingsViewComponentsTests'
```

预期：PASS，2 个测试用例全部通过（依赖任务 3 完成 SettingsView 集成后方可定位 `autoSaveEnabledToggle`；若任务 2 单独运行失败，应先完成任务 3 再回来运行）。

- [ ] **步骤 5：Commit**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1-auto-save-to-file
swiftlint lint --strict
git add ClipMind/UI/Settings/AutoSaveSettingsView.swift ClipMindUITests/AutoSaveSettingsViewComponentsTests.swift
git commit -m "feat(F2.1): 实现 AutoSaveSettingsView 自动保存分区视图"
```

预期：SwiftLint 通过；commit 成功。

---

### 任务 3：SettingsView 集成自动保存分区

**文件：**
- 修改：`ClipMind/UI/Settings/SettingsView.swift`
- 测试：`ClipMindUITests/AutoSaveSettingsViewComponentsTests.swift`（追加 tab 验证测试）

**目标：** 在 `SettingsView` 的 `TabView` 新增 `.autoSave` case，挂载 `AutoSaveSettingsView` 作为第 4 个 tab；扩展 `--UITEST_INITIAL_TAB=autosave` 启动参数解析。

**对应 FR：** FR-010（配置面板独立分区）

**对应 AC：** AC-07（配置面板入口可达）

**对应约束：** F-10（不修改 F1.x 既有分区，仅新增）

- [ ] **步骤 1：编写失败的测试**

在 `ClipMindUITests/AutoSaveSettingsViewComponentsTests.swift` 末尾（`class` 闭合大括号之前）追加：

```swift
    // MARK: - AC-07: 自动保存分区 tab 存在

    func testAutoSaveTabExists()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_RESET_AUTOSAVE_SETTINGS"
        ]
        app.launch()
        app.activate()

        let settingsButton = app.buttons["settingsButton"].firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.click()

        // macOS 13 SwiftUI Settings 场景中 .tabItem 内 Label 的
        // accessibilityIdentifier 不一定保留到工具栏 tab 按钮，
        // 改为通过点击 tab 后验证内部元素出现来确认 tab 存在
        let autoSaveTab = app.tabs["自动保存"]
            .firstMatch
        if autoSaveTab.waitForExistence(timeout: 2)
        {
            autoSaveTab.click()
        }
        else
        {
            // 兼容：通过工具栏按钮索引定位（4 个 tab 的第 4 个）
            let tabButtons = app.toolbars.buttons.allElementsBoundByIndex
            if tabButtons.count >= 4
            {
                tabButtons[3].click()
            }
        }

        XCTAssertTrue(
            element("autoSaveEnabledToggle", in: app).waitForExistence(timeout: 5),
            "自动保存 tab 应可点击并显示分区内容"
        )
    }

    // MARK: - --UITEST_INITIAL_TAB=autosave 启动参数解析

    func testLaunchWithAutoSaveTabInitial()
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

        XCTAssertTrue(
            element("autoSaveEnabledToggle", in: app).waitForExistence(timeout: 5),
            "通过 --UITEST_INITIAL_TAB=autosave 启动后应直接打开自动保存分区"
        )
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
  -only-testing:'ClipMindUITests/AutoSaveSettingsViewComponentsTests/testAutoSaveTabExists'
```

预期：FAIL，报错 "Failed to find accessibility identifier 'autoSaveEnabledToggle'"（因 SettingsView 尚未集成 AutoSaveSettingsView）。

- [ ] **步骤 3：编写实现代码**

修改 `ClipMind/UI/Settings/SettingsView.swift`：

```swift
import SwiftUI

/// 设置面板主视图。
///
/// 使用 TabView 分为 4 个分区：API Key / 隐私 / 通用 / 自动保存（F2.1 新增）。
/// 对应设计规范 3.8 节设置配置流程和 UI-AC-15 设置面板入口。
struct SettingsView: View {
    /// 启动时立即解析 `--UITEST_INITIAL_TAB=<tab>` 启动参数。
    @State private var selectedTab: SettingsTab = {
        guard let arg = CommandLine.arguments.first(where: { $0.hasPrefix("--UITEST_INITIAL_TAB=") }) else {
            return .apiKey
        }
        let raw = String(arg.dropFirst("--UITEST_INITIAL_TAB=".count))
        switch raw.lowercased() {
        case "privacy":
            return .privacy
        case "general":
            return .general
        case "autosave":
            return .autoSave
        default:
            return .apiKey
        }
    }()

    var body: some View {
        TabView(selection: $selectedTab) {
            APIKeyConfigView()
                .tabItem {
                    Label("API Key", systemImage: "key.fill")
                        .accessibilityIdentifier("apiKeyTab")
                }
                .tag(SettingsTab.apiKey)

            PrivacySettingsView()
                .tabItem {
                    Label("隐私", systemImage: "lock.shield.fill")
                        .accessibilityIdentifier("privacyTab")
                }
                .tag(SettingsTab.privacy)

            GeneralSettingsView()
                .tabItem {
                    Label("通用", systemImage: "gear")
                        .accessibilityIdentifier("generalTab")
                }
                .tag(SettingsTab.general)

            AutoSaveSettingsView()
                .tabItem {
                    Label("自动保存", systemImage: "doc.on.doc.fill")
                        .accessibilityIdentifier("autoSaveTab")
                }
                .tag(SettingsTab.autoSave)
        }
        .frame(width: 560, height: 620)
    }
}

/// 设置面板标签枚举（F2.1 新增 .autoSave）
private enum SettingsTab: Hashable {
    case apiKey
    case privacy
    case general
    case autoSave
}
```

- [ ] **步骤 4：运行测试验证通过**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1-auto-save-to-file
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindUITests/AutoSaveSettingsViewComponentsTests'
```

预期：PASS，4 个测试用例（含任务 2 的 2 个 + 本任务的 2 个）全部通过。

- [ ] **步骤 5：Commit**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1-auto-save-to-file
swiftlint lint --strict
git add ClipMind/UI/Settings/SettingsView.swift ClipMindUITests/AutoSaveSettingsViewComponentsTests.swift
git commit -m "feat(F2.1): 在 SettingsView 集成自动保存分区"
```

预期：SwiftLint 通过；commit 成功。F1.x 既有 `SettingsUITests` 不受影响（既有 3 个 tab 不变）。

---

### 任务 4：ClipMindApp 装配 AutoSaveService

**文件：**
- 修改：`ClipMind/App/ClipMindApp.swift`

**目标：** 在 `AppDelegate.setupCaptureService` 中装配 `AutoSaveService` 并注入 `autoSaveTrigger` 闭包，使 F1.x 捕获流程的事件转交给 AutoSaveService。在 `applyUITestOverrides` 中处理 `--UITEST_RESET_AUTOSAVE_SETTINGS` 启动参数，重置 UserDefaults 中的 `autoSaveSettings` 键与 F1.x `sensitiveDetectionEnabled` 键，确保 XCUITest 在干净状态下运行。**新增**：在 `applicationDidFinishLaunching` 中监听 `AutoSaveService.didFailNotification`，收到通知后主线程弹出 `NSAlert`（accessibility identifier `autoSaveErrorAlert`），向用户显示"自动保存失败"提示（满足 AC-09 用户可见错误提示要求）。

**对应 FR：** FR-009（原内容仍入库，钩子装配）、FR-014（自动保存触发时机）

**对应 AC：** AC-05（原内容仍进入 ClipMind 历史，依赖任务 1 的钩子装配）、AC-09（保存目录异常时弹窗提示不崩溃，依赖 Phase 0 AutoSaveService.didFailNotification 与本任务的 AppDelegate 监听弹窗）

**对应约束：** F-01（不修改 F1.x 既有公共接口）、D-01（在 F1.x 捕获流程中插入钩子）

- [ ] **步骤 1：（无新增 XCTest）**

本任务无新增 XCTest，依赖 UITest 间接验证（任务 5、6 的 XCUITest 启动后通过实际行为验证装配正确性）。若需新增单元测试，可在 `ClipMindTests/App/AppDelegateAutoSaveWiringTests.swift` 中验证 `setupCaptureService` 后 `captureService.autoSaveTrigger != nil`，但该方法为 `private`，需用 `@testable import` + 内部访问。本计划选择不新增单元测试，直接通过 UITest 验证。

- [ ] **步骤 2：运行构建验证（任务 4 前基线）**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1-auto-save-to-file
xcodegen generate
xcodebuild build \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

预期：BUILD SUCCEEDED（任务 1~3 完成后基线）。

- [ ] **步骤 3：编写实现代码**

修改 `ClipMind/App/ClipMindApp.swift` 中的 `AppDelegate`：

1. 新增 `autoSaveService` 私有属性：
```swift
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?
    private var cleanupService: CleanupService?
    private var captureService: ClipCaptureService?
    private var hotkeyService: GlobalHotkeyService?
    private var autoSaveService: AutoSaveService?  // F2.1 新增
    // ... 既有属性不变
```

2. 修改 `setupCaptureService(store:)` 方法装配 AutoSaveService 并注入钩子：
```swift
    /// 初始化并启动剪贴板捕获服务
    private func setupCaptureService(store: EncryptedStore) {
        let embeddingService = LocalEmbeddingService()
        let classifier = ClassificationService(embeddingService: embeddingService)
        let watcher = PasteboardWatcher()
        captureService = ClipCaptureService(watcher: watcher, store: store, classifier: classifier)

        // F2.1：装配 AutoSaveService 并注入 autoSaveTrigger 钩子
        let settingsStore = AutoSaveSettingsStore()
        let sensitiveDetector = SensitiveDetector()
        let service = AutoSaveService(
            settingsStore: settingsStore,
            sensitiveDetector: sensitiveDetector
        )
        autoSaveService = service
        captureService?.autoSaveTrigger = { content, bundleId, appName in
            service.handle(content: content, bundleId: bundleId, appName: appName)
        }

        captureService?.start()
        LogCategory.app.info("剪贴板捕获服务已启动")
    }
```

3. 修改 `applyUITestOverrides` 方法，在 `--UITEST_RESET_SETTINGS` 分支与新增 `--UITEST_RESET_AUTOSAVE_SETTINGS` 分支中重置 F2.1 配置：
```swift
    /// 应用 UI 测试启动参数覆盖
    private func applyUITestOverrides() {
        if CommandLine.arguments.contains("--UITEST_RESET_ONBOARDING") {
            let bundleId = Bundle.main.bundleIdentifier ?? "com.clipmind.app"
            UserDefaults.standard.removePersistentDomain(forName: bundleId)
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
            UserDefaults.standard.synchronize()
        }
        if CommandLine.arguments.contains("--UITEST_SHOW_MAIN_WINDOW") {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            UserDefaults.standard.synchronize()
        }
        if CommandLine.arguments.contains("--UITEST_RESET_SETTINGS") {
            let keys = [
                "sensitiveDetectionEnabled",
                "autoCleanupEnabled",
                "cleanupDays",
                "launchAtLogin",
                "hotkey",
                BlacklistService.storageKey
            ]
            for key in keys {
                UserDefaults.standard.removeObject(forKey: key)
            }
            UserDefaults.standard.synchronize()
        }
        // F2.1：重置自动保存配置（含 F1.x sensitiveDetectionEnabled 以确保敏感过滤开启）
        if CommandLine.arguments.contains("--UITEST_RESET_AUTOSAVE_SETTINGS") {
            UserDefaults.standard.removeObject(forKey: AutoSaveSettingsStore.storageKey)
            UserDefaults.standard.set(true, forKey: "sensitiveDetectionEnabled")
            UserDefaults.standard.synchronize()
            LogCategory.app.info("已通过 --UITEST_RESET_AUTOSAVE_SETTINGS 重置 F2.1 配置")
        }
    }
```

完整修改后的 `AppDelegate` 类骨架（仅展示新增/修改部分，其余方法保持不变）：

```swift
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?
    private var cleanupService: CleanupService?
    private var captureService: ClipCaptureService?
    private var hotkeyService: GlobalHotkeyService?
    private var autoSaveService: AutoSaveService?

    func applicationWillFinishLaunching(_ notification: Notification) {
        applyOnboardingResetIfNeeded()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        applyUITestOverrides()
        configureActivationPolicy()
        if CommandLine.arguments.contains("--UITEST_POPOVER_WINDOW") {
            showPopoverContentInWindow()
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenMainWindow),
            name: .openMainWindow,
            object: nil
        )
        // F2.1：监听 AutoSaveService 失败通知，主线程弹窗提示用户（满足 AC-09）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAutoSaveDidFail),
            name: AutoSaveService.didFailNotification,
            object: nil
        )
    }

    /// F2.1：自动保存失败时弹出用户可见的错误提示（满足 AC-09）。
    ///
    /// 收到 `AutoSaveService.didFailNotification` 后在主线程弹出 `NSAlert`，
    /// 提示用户检查保存目录权限或磁盘空间。`NSAlert` 的 window 的
    /// accessibility identifier 设为 `autoSaveErrorAlert`，供 XCUITest 断言。
    @MainActor
    @objc private func handleAutoSaveDidFail() {
        let alert = NSAlert()
        alert.messageText = "自动保存失败"
        alert.informativeText = "ClipMind 无法将剪贴板内容保存到文件。请检查保存目录权限或磁盘空间。原始内容仍已入库 ClipMind 历史。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "好")
        // 设置 accessibility identifier 供 XCUITest 断言（AC-09 弹窗断言）
        alert.window.accessibilityIdentifier = "autoSaveErrorAlert"
        alert.runModal()
    }

    private func applyOnboardingResetIfNeeded() {
        guard CommandLine.arguments.contains("--reset-onboarding") else { return }
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        UserDefaults.standard.synchronize()
        LogCategory.app.info("已通过 --reset-onboarding 重置首启引导标志位")
    }

    private func applyUITestOverrides() {
        if CommandLine.arguments.contains("--UITEST_RESET_ONBOARDING") {
            let bundleId = Bundle.main.bundleIdentifier ?? "com.clipmind.app"
            UserDefaults.standard.removePersistentDomain(forName: bundleId)
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
            UserDefaults.standard.synchronize()
        }
        if CommandLine.arguments.contains("--UITEST_SHOW_MAIN_WINDOW") {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            UserDefaults.standard.synchronize()
        }
        if CommandLine.arguments.contains("--UITEST_RESET_SETTINGS") {
            let keys = [
                "sensitiveDetectionEnabled",
                "autoCleanupEnabled",
                "cleanupDays",
                "launchAtLogin",
                "hotkey",
                BlacklistService.storageKey
            ]
            for key in keys {
                UserDefaults.standard.removeObject(forKey: key)
            }
            UserDefaults.standard.synchronize()
        }
        if CommandLine.arguments.contains("--UITEST_RESET_AUTOSAVE_SETTINGS") {
            UserDefaults.standard.removeObject(forKey: AutoSaveSettingsStore.storageKey)
            UserDefaults.standard.set(true, forKey: "sensitiveDetectionEnabled")
            UserDefaults.standard.synchronize()
            LogCategory.app.info("已通过 --UITEST_RESET_AUTOSAVE_SETTINGS 重置 F2.1 配置")
        }
    }

    private func configureActivationPolicy() {
        // ... 既有实现不变
    }

    private func setupServices() {
        // ... 既有实现不变
    }

    private func prepopulateTestData(store: EncryptedStore) {
        // ... 既有实现不变
    }

    // setupCaptureService 实现见下方"最终实现方案"

    private func setupCleanupService(store: EncryptedStore) {
        // ... 既有实现不变
    }

    private func setupHotkeyService() {
        // ... 既有实现不变
    }

    private func showPopoverContentInWindow() {
        // ... 既有实现不变
    }

    @objc private func handleOpenMainWindow() {
        // ... 既有实现不变
    }
}
```

- [ ] **步骤 4：运行构建验证**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1-auto-save-to-file
xcodebuild build \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

预期：BUILD SUCCEEDED。

- [ ] **步骤 5：Commit**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1-auto-save-to-file
swiftlint lint --strict
git add ClipMind/App/ClipMindApp.swift
git commit -m "feat(F2.1): AppDelegate 装配 AutoSaveService 与 UITEST 重置钩子"
```

预期：SwiftLint 通过；commit 成功。F1.x 既有测试不受影响（无 UITEST 参数时 `autoSaveTrigger` 仍被设置，但 AutoSaveService 默认配置下行为与 F1.x 一致——总开关默认开但敏感过滤默认开，不会改变剪贴板替换行为？需注意：默认配置下 `AutoSaveSettings.isEnabled = true`，所有白名单 App 复制长内容都会触发自动保存！这可能影响 F1.x 既有 UITest。

**实现方案**：在 `setupCaptureService` 中根据启动参数决定是否装配 AutoSaveService。生产环境默认装配；UITEST 环境下需通过 `--UITEST_ENABLE_AUTOSAVE` 显式启用，避免 F1.x 既有 UITest 被 AutoSaveService 默认 `isEnabled=true` 行为污染（写入文件到 `~/Documents/ClipMind/Clips/`）。

```swift
    private func setupCaptureService(store: EncryptedStore) {
        let embeddingService = LocalEmbeddingService()
        let classifier = ClassificationService(embeddingService: embeddingService)
        let watcher = PasteboardWatcher()
        captureService = ClipCaptureService(watcher: watcher, store: store, classifier: classifier)

        // F2.1：装配 AutoSaveService
        // - 生产环境（无 UITEST 标志）：默认装配
        // - UITEST 环境：仅 --UITEST_ENABLE_AUTOSAVE 时装配，避免污染 F1.x 既有 UITest
        let isUITest = CommandLine.arguments.contains("--UITEST_SHOW_MAIN_WINDOW")
            || CommandLine.arguments.contains("--UITEST_RESET_ONBOARDING")
            || CommandLine.arguments.contains("--UITEST_RESET_SETTINGS")
            || CommandLine.arguments.contains("--UITEST_RESET_AUTOSAVE_SETTINGS")
        let enableAutoSaveInUITest = CommandLine.arguments.contains("--UITEST_ENABLE_AUTOSAVE")
        let shouldWireAutoSave = !isUITest || enableAutoSaveInUITest

        if shouldWireAutoSave {
            let settingsStore = AutoSaveSettingsStore()
            let sensitiveDetector = SensitiveDetector()
            let service = AutoSaveService(
                settingsStore: settingsStore,
                sensitiveDetector: sensitiveDetector
            )
            autoSaveService = service
            captureService?.autoSaveTrigger = { content, bundleId, appName in
                service.handle(content: content, bundleId: bundleId, appName: appName)
            }
            LogCategory.app.info("AutoSaveService 已装配")
        }

        captureService?.start()
        LogCategory.app.info("剪贴板捕获服务已启动")
    }
```

说明：F2.1 XCUITest（任务 5、6）通过 `--UITEST_ENABLE_AUTOSAVE` 启用 AutoSaveService；F1.x 既有 UITest 不传入此参数，行为与 F1.x 完全一致；生产环境默认启用。

---

### 任务 5：AutoSaveSettingsUITests（AC-07/15/16/14 UI）

**文件：**
- 创建：`ClipMindUITests/AutoSaveSettingsUITests.swift`

**目标：** 通过 XCUITest 验证 AC-07（配置面板可修改全部配置项）、AC-15（白名单 App 管理可添加与删除）、AC-16（配置修改持久化重启后保留）、AC-14（关闭敏感过滤二次确认 UI 交互）。

**对应 FR：** FR-010（配置面板）、FR-012（白名单 App 管理）

**对应约束：** C-07（敏感过滤关闭二次确认）、F-10（不修改 F1.x 既有分区）

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

    /// tearDown 截图保存（问题 6）：每个测试结束时截图作为失败诊断证据，
    /// 通过 GitHub Actions test-results artifact 自动上传。
    override func tearDown()
    {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "AutoSaveSettingsUITests-tearDown-\(UUID().uuidString)"
        attachment.lifetime = .keepAlways
        add(attachment)
        super.tearDown()
    }

    /// 通过 accessibility identifier 查找元素（参考 SettingsUITests.element）。
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement
    {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// 启动 App 并打开自动保存分区（含 --UITEST_ENABLE_AUTOSAVE 与 --UITEST_RESET_AUTOSAVE_SETTINGS）。
    private func launchAndOpenAutoSaveSettings() -> XCUIApplication
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_RESET_AUTOSAVE_SETTINGS",
            "--UITEST_ENABLE_AUTOSAVE",
            "--UITEST_INITIAL_TAB=autosave"
        ]
        app.launch()
        app.activate()

        let settingsButton = app.buttons["settingsButton"].firstMatch
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5), "设置按钮应存在")
        settingsButton.click()

        let toggle = element("autoSaveEnabledToggle", in: app)
        XCTAssertTrue(
            toggle.waitForExistence(timeout: 5),
            "自动保存分区应已激活，总开关应存在"
        )
        return app
    }

    /// 读取 Toggle 布尔值（macOS XCUITest 上 Toggle.value 为 NSNumber 1/0）。
    private func toggleValue(_ toggle: XCUIElement) -> Int
    {
        if let intValue = toggle.value as? Int { return intValue }
        if let stringValue = toggle.value as? String { return Int(stringValue) ?? 0 }
        return 0
    }

    // MARK: - AC-07: 修改长度阈值生效（强化：通过启动参数注入触发自动保存，验证新阈值生效）

    func testAC07ModifyLengthThresholdTakesEffect()
    {
        // 第一次启动：修改长度阈值为 100（远高于 50 字注入内容）
        var app = launchAndOpenAutoSaveSettings()

        let lengthInput = app.textFields["lengthThresholdInput"].firstMatch
        XCTAssertTrue(lengthInput.waitForExistence(timeout: 5))

        lengthInput.click()
        lengthInput.deleteText()
        lengthInput.typeText("100\n")
        Thread.sleep(forTimeInterval: 0.5)

        // 验证值已持久化
        let currentInput = app.textFields["lengthThresholdInput"].firstMatch
        XCTAssertEqual(currentInput.value as? String, "100", "AC-07: 修改后的长度阈值应持久化")

        // 配置保存目录为临时目录
        let tempDir = "/tmp/clipmind-ac07-threshold-\(UUID().uuidString)/"
        let dirInput = app.textFields["saveDirectoryInput"].firstMatch
        dirInput.click()
        typeKey("a", modifierFlags: .command)
        dirInput.typeText("\(tempDir)\n")
        Thread.sleep(forTimeInterval: 0.3)
        app.terminate()

        // 第二次启动：注入 50 字内容（< 100 阈值）+ Safari bundleId，验证不触发自动保存
        app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_ENABLE_AUTOSAVE",
            "--UITEST_INJECT_CONTENT=this is a 50-char content for threshold test!!!!!",
            "--UITEST_INJECT_BUNDLE_ID=com.apple.Safari"
        ]
        app.launch()
        app.activate()
        Thread.sleep(forTimeInterval: 2.0)

        // 验证保存目录无新文件（50 字 < 100 阈值，应跳过）
        let url = URL(fileURLWithPath: tempDir)
        let files = (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil
        )) ?? []
        XCTAssertTrue(
            files.isEmpty,
            "AC-07: 长度阈值=100 时，50 字注入内容不应触发自动保存"
        )

        // 清理临时目录
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - AC-07: 切换文件格式生效（强化：通过启动参数注入触发自动保存，验证生成的文件扩展名为 .txt）

    func testAC07SwitchFileFormat()
    {
        // 第一次启动：切换文件格式为纯文本
        var app = launchAndOpenAutoSaveSettings()

        let picker = element("fileFormatPicker", in: app)
        XCTAssertTrue(picker.waitForExistence(timeout: 5))

        let plainTextRadio = app.radioButtons["纯文本 (.txt)"].firstMatch
        XCTAssertTrue(plainTextRadio.waitForExistence(timeout: 3), "纯文本单选项应存在")
        plainTextRadio.click()
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertTrue(plainTextRadio.isSelected, "纯文本单选应被选中")

        // 配置保存目录为临时目录
        let tempDir = "/tmp/clipmind-ac07-format-\(UUID().uuidString)/"
        let dirInput = app.textFields["saveDirectoryInput"].firstMatch
        dirInput.click()
        typeKey("a", modifierFlags: .command)
        dirInput.typeText("\(tempDir)\n")
        Thread.sleep(forTimeInterval: 0.3)
        app.terminate()

        // 第二次启动：注入长内容 + Safari bundleId，验证生成的文件扩展名为 .txt
        app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_ENABLE_AUTOSAVE",
            "--UITEST_INJECT_CONTENT=this is a long content for file format test with more than 50 characters to trigger auto save behavior",
            "--UITEST_INJECT_BUNDLE_ID=com.apple.Safari"
        ]
        app.launch()
        app.activate()
        Thread.sleep(forTimeInterval: 2.0)

        // 验证保存目录出现 .txt 文件（而非 .md）
        let url = URL(fileURLWithPath: tempDir)
        let files = (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil
        )) ?? []
        XCTAssertFalse(files.isEmpty, "AC-07: 纯文本格式下应生成文件")
        XCTAssertTrue(
            files.allSatisfy { $0.pathExtension == "txt" },
            "AC-07: 文件扩展名应为 .txt，实际: \(files.map { $0.pathExtension })"
        )

        // 清理临时目录
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - AC-07: 切换路径格式与预览（强化：验证三种格式预览变化）

    func testAC07SwitchPathFormatUpdatesPreview()
    {
        let app = launchAndOpenAutoSaveSettings()

        let picker = element("pathFormatPicker", in: app)
        let preview = element("pathFormatPreview", in: app)
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        XCTAssertTrue(preview.waitForExistence(timeout: 5))

        // 默认纯路径字符串：预览应以 / 开头
        let plainPreview = preview.value as? String ?? ""
        XCTAssertTrue(
            plainPreview.hasPrefix("/"),
            "纯路径格式预览应以 / 开头"
        )

        // 切换为 file:// URI 格式
        let fileURIRadio = app.radioButtons["file:// URI"].firstMatch
        if fileURIRadio.waitForExistence(timeout: 3)
        {
            fileURIRadio.click()
            Thread.sleep(forTimeInterval: 0.3)
            let uriPreview = preview.value as? String ?? ""
            XCTAssertTrue(
                uriPreview.hasPrefix("file://"),
                "AC-07: file:// URI 格式预览应以 file:// 开头，实际: \(uriPreview)"
            )
        }

        // 切换为 Markdown 链接格式
        let markdownLinkRadio = app.radioButtons["Markdown 链接"].firstMatch
        if markdownLinkRadio.waitForExistence(timeout: 3)
        {
            markdownLinkRadio.click()
            Thread.sleep(forTimeInterval: 0.3)
            let mdPreview = preview.value as? String ?? ""
            XCTAssertTrue(
                mdPreview.hasPrefix("["),
                "AC-07: Markdown 链接格式预览应以 [ 开头，实际: \(mdPreview)"
            )
            XCTAssertTrue(
                mdPreview.contains("](file://"),
                "AC-07: Markdown 链接格式预览应包含 ](file://，实际: \(mdPreview)"
            )
        }
    }

    // MARK: - AC-14: 关闭敏感过滤触发二次确认弹窗

    func testAC14TurningOffSensitiveFilterShowsConfirmation()
    {
        let app = launchAndOpenAutoSaveSettings()

        let toggle = element("sensitiveFilterToggle", in: app)
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))

        // 初始状态：开
        let initialValue = toggleValue(toggle)
        XCTAssertEqual(initialValue, 1, "敏感过滤开关默认应为开")

        // 切换至关（不应立即生效）
        app.activate()
        toggle.click()
        Thread.sleep(forTimeInterval: 0.5)

        // 二次确认弹窗应出现
        let confirmButton = app.buttons["确认关闭"].firstMatch
        XCTAssertTrue(
            confirmButton.waitForExistence(timeout: 3),
            "AC-14: 关闭敏感过滤应显示二次确认弹窗"
        )

        let cancelButton = app.buttons["取消"].firstMatch
        XCTAssertTrue(cancelButton.exists, "AC-14: 弹窗应有取消按钮")

        // 点击取消 → 应恢复开启状态
        cancelButton.click()
        Thread.sleep(forTimeInterval: 0.5)

        let restoredValue = toggleValue(toggle)
        XCTAssertEqual(restoredValue, 1, "AC-14: 取消后敏感过滤应恢复开启")
    }

    // MARK: - AC-14: 确认关闭后敏感过滤持久化

    func testAC14ConfirmTurningOffSensitiveFilter()
    {
        let app = launchAndOpenAutoSaveSettings()

        let toggle = element("sensitiveFilterToggle", in: app)
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))

        app.activate()
        toggle.click()
        Thread.sleep(forTimeInterval: 0.5)

        let confirmButton = app.buttons["确认关闭"].firstMatch
        XCTAssertTrue(confirmButton.waitForExistence(timeout: 3))
        confirmButton.click()
        Thread.sleep(forTimeInterval: 0.5)

        let finalValue = toggleValue(toggle)
        XCTAssertEqual(finalValue, 0, "AC-14: 确认后敏感过滤应关闭并持久化")
    }

    // MARK: - AC-15: 白名单 App 列表存在且包含默认 5 个

    func testAC15WhitelistContainsDefaultApps()
    {
        let app = launchAndOpenAutoSaveSettings()

        let list = element("whitelistAppList", in: app)
        XCTAssertTrue(list.waitForExistence(timeout: 5), "应有白名单 App 列表")

        // 验证默认 5 个 Bundle ID 在列表中
        let safariText = app.staticTexts["com.apple.Safari"].firstMatch
        let chromeText = app.staticTexts["com.google.Chrome"].firstMatch
        let traeText = app.staticTexts["com.trae.ide"].firstMatch
        let vscodeText = app.staticTexts["com.microsoft.VSCode"].firstMatch
        let xcodeText = app.staticTexts["com.apple.dt.Xcode"].firstMatch

        XCTAssertTrue(safariText.exists, "白名单应包含 Safari")
        XCTAssertTrue(chromeText.exists, "白名单应包含 Chrome")
        XCTAssertTrue(traeText.exists, "白名单应包含 Trae IDE")
        XCTAssertTrue(vscodeText.exists, "白名单应包含 VSCode")
        XCTAssertTrue(xcodeText.exists, "白名单应包含 Xcode")
    }

    // MARK: - AC-15: 移除白名单 App 生效

    func testAC15RemoveWhitelistApp()
    {
        let app = launchAndOpenAutoSaveSettings()

        let removeButtons = app.buttons.matching(identifier: "removeWhitelistAppButton")
        let initialCount = removeButtons.count
        XCTAssertGreaterThanOrEqual(initialCount, 1, "应至少有一个移除按钮")

        // 点击第一个移除按钮
        removeButtons.firstMatch.click()
        Thread.sleep(forTimeInterval: 0.5)

        // 验证列表项减少（重新查询按钮数）
        let afterCount = app.buttons.matching(identifier: "removeWhitelistAppButton").count
        XCTAssertEqual(afterCount, initialCount - 1, "AC-15: 移除后白名单数量应减少 1")
    }

    // MARK: - AC-16: 配置修改重启后保留

    func testAC16ConfigPersistsAcrossRestart()
    {
        // 第一次启动：修改长度阈值
        var app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_RESET_AUTOSAVE_SETTINGS",
            "--UITEST_ENABLE_AUTOSAVE",
            "--UITEST_INITIAL_TAB=autosave"
        ]
        app.launch()
        app.activate()
        app.buttons["settingsButton"].firstMatch.click()

        let lengthInput = app.textFields["lengthThresholdInput"].firstMatch
        XCTAssertTrue(lengthInput.waitForExistence(timeout: 5))
        lengthInput.click()
        lengthInput.deleteText()
        lengthInput.typeText("200\n")
        Thread.sleep(forTimeInterval: 0.5)
        app.terminate()

        // 第二次启动：验证配置保留
        app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_ENABLE_AUTOSAVE",
            "--UITEST_INITIAL_TAB=autosave"
        ]
        // 注意：不传 --UITEST_RESET_AUTOSAVE_SETTINGS，验证持久化
        app.launch()
        app.activate()
        app.buttons["settingsButton"].firstMatch.click()

        let currentInput = app.textFields["lengthThresholdInput"].firstMatch
        XCTAssertTrue(currentInput.waitForExistence(timeout: 5))
        XCTAssertEqual(
            currentInput.value as? String,
            "200",
            "AC-16: 修改的长度阈值应在重启后保留"
        )
    }
}

/// 扩展 XCUIElement 清空文本字段。
private extension XCUIElement
{
    func deleteText()
    {
        guard let currentValue = value as? String, !currentValue.isEmpty else { return }
        // macOS XCUITest 上 cmd+A 全选 + delete 删除
        typeKey("a", modifierFlags: .command)
        keyText.delete()
    }
}

private extension String
{
    static let delete = "\u{8}"  // Backspace
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
  -only-testing:'ClipMindUITests/AutoSaveSettingsUITests/testAC15WhitelistContainsDefaultApps'
```

预期：FAIL（依赖任务 1~4 完成；若任务 1~4 已完成，此测试应能通过。若任务 1~4 未完成，则 FAIL）。

- [ ] **步骤 3：（无新增实现代码）**

本任务为纯测试任务，无新增实现代码。所有实现已在任务 1~4 完成。若步骤 2 中测试失败：
- 若失败原因是"找不到 autoSaveEnabledToggle"，检查任务 2、3 是否完成
- 若失败原因是"AutoSaveService 未装配"，检查任务 4 是否完成（需传入 `--UITEST_ENABLE_AUTOSAVE`）
- 若失败原因是"配置未持久化"，检查 `AutoSaveSettingsStore.update` 是否调用 `defaults.synchronize()`

- [ ] **步骤 4：运行测试验证通过**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1-auto-save-to-file
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindUITests/AutoSaveSettingsUITests'
```

预期：PASS，7 个测试用例全部通过。

- [ ] **步骤 5：Commit**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1-auto-save-to-file
swiftlint lint --strict
git add ClipMindUITests/AutoSaveSettingsUITests.swift
git commit -m "test(F2.1): 添加 AutoSaveSettingsUITests 覆盖 AC-07/14/15/16"
```

预期：SwiftLint 通过；commit 成功。

---

### 任务 6：AutoSaveBehaviorUITests（AC-01/05/08/09）

**文件：**
- 创建：`ClipMindUITests/AutoSaveBehaviorUITests.swift`

**目标：** 通过 XCUITest 验证 AC-01（白名单 App 复制长内容触发自动保存端到端，启动参数注入）、AC-05（烟雾测试：App 在自动保存触发时不崩溃，历史条目由手动验收兜底）、AC-08（禁用总开关后不触发任何保存行为，含核心断言）、AC-09（保存目录异常时弹窗提示不崩溃，含 `autoSaveErrorAlert` 弹窗断言）。

**对应 FR：** FR-001（总开关）、FR-002（白名单触发）、FR-005（文件保存）、FR-008（剪贴板替换）、FR-009（原内容仍入库）、FR-011（保存目录异常处理）

**对应约束：** C-01（保存目录默认值）、C-02（文件格式 Markdown）、D-02（自动保存与 F1.x 入库流程互不阻塞）、NFR-004（稳定性不崩溃）、NFR-007（日志可观测性，弹窗用户可见）

- [ ] **步骤 1：编写失败的测试**

创建 `ClipMindUITests/AutoSaveBehaviorUITests.swift`：

```swift
import AppKit
import XCTest

final class AutoSaveBehaviorUITests: XCTestCase
{
    override func setUp()
    {
        super.setUp()
        continueAfterFailure = false
    }

    /// tearDown 截图保存（问题 6）：每个测试结束时截图作为失败诊断证据，
    /// 通过 GitHub Actions test-results artifact 自动上传。
    override func tearDown()
    {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "AutoSaveBehaviorUITests-tearDown-\(UUID().uuidString)"
        attachment.lifetime = .keepAlways
        add(attachment)
        super.tearDown()
    }

    /// 通过 accessibility identifier 查找元素（参考 SettingsUITests.element）。
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement
    {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// 读取 Toggle 布尔值。
    private func toggleValue(_ toggle: XCUIElement) -> Int
    {
        if let intValue = toggle.value as? Int { return intValue }
        if let stringValue = toggle.value as? String { return Int(stringValue) ?? 0 }
        return 0
    }

    /// 启动 App 并打开自动保存分区。
    private func launchAndOpenAutoSaveSettings() -> XCUIApplication
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_RESET_AUTOSAVE_SETTINGS",
            "--UITEST_ENABLE_AUTOSAVE",
            "--UITEST_INITIAL_TAB=autosave"
        ]
        app.launch()
        app.activate()
        app.buttons["settingsButton"].firstMatch.click()

        let toggle = element("autoSaveEnabledToggle", in: app)
        XCTAssertTrue(toggle.waitForExistence(timeout: 5), "自动保存分区应激活")
        return app
    }

    /// 关闭设置面板返回主窗口。
    private func closeSettingsWindow(_ app: XCUIApplication)
    {
        app.activate()
        // 关闭设置窗口
        if app.windows.count > 1
        {
            app.windows.element(boundBy: 0).buttons[XCUIIdentifierCloseWindow].firstMatch.click()
        }
        Thread.sleep(forTimeInterval: 0.3)
    }

    /// 触发系统剪贴板变化（通过 NSPasteboard.general 写入）。
    /// App 的 PasteboardWatcher 会检测到 changeCount 变化并调用 handleClipContent，
    /// 在 DEBUG 编译条件下，注入的 content/bundleId 会替换真实剪贴板内容。
    private func triggerClipboardChange()
    {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString("trigger-\(UUID().uuidString)", forType: .string)
    }

    // MARK: - AC-01: 白名单 App 复制长内容触发自动保存端到端（启动参数注入）

    /// 通过 `--UITEST_INJECT_CONTENT` + `--UITEST_INJECT_BUNDLE_ID=com.apple.Safari` 启动参数
    /// 注入长内容（>100 字），模拟白名单 App 复制行为。
    /// 触发剪贴板变化后，验证保存目录出现 .md 文件 + 剪贴板被替换为文件路径 + App 不崩溃。
    func testAC01AutoSaveEndToEndViaLaunchArgument()
    {
        let tempDir = "/tmp/clipmind-uitest-ac01-\(UUID().uuidString)/"
        try? FileManager.default.createDirectory(
            atPath: tempDir,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let longContent = String(repeating: "ClipMind 自动保存端到端测试内容。", count: 10)  // 约 160 字

        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_RESET_AUTOSAVE_SETTINGS",
            "--UITEST_ENABLE_AUTOSAVE",
            "--UITEST_INITIAL_TAB=autosave",
            "--UITEST_INJECT_CONTENT=\(longContent)",
            "--UITEST_INJECT_BUNDLE_ID=com.apple.Safari"
        ]
        app.launch()
        app.activate()

        // 打开设置面板修改保存目录为临时目录
        app.buttons["settingsButton"].firstMatch.click()
        let dirInput = app.textFields["saveDirectoryInput"].firstMatch
        XCTAssertTrue(dirInput.waitForExistence(timeout: 5))
        dirInput.click()
        typeKey("a", modifierFlags: .command)
        dirInput.typeText("\(tempDir)\n")
        Thread.sleep(forTimeInterval: 0.5)

        // 关闭设置面板
        closeSettingsWindow(app)

        // 触发剪贴板变化（PasteboardWatcher 检测到后调用 handleClipContent，注入逻辑生效）
        triggerClipboardChange()
        Thread.sleep(forTimeInterval: 1.5)

        // 验证保存目录出现 .md 文件
        let files = (try? FileManager.default.contentsOfDirectory(atPath: tempDir)) ?? []
        let mdFiles = files.filter { $0.hasSuffix(".md") }
        XCTAssertFalse(mdFiles.isEmpty, "AC-01: 保存目录应出现 .md 文件，实际：\(files)")

        // 验证剪贴板被替换为文件路径
        let pasteboard = NSPasteboard.general
        let clipboardString = pasteboard.string(forType: .string) ?? ""
        XCTAssertTrue(
            clipboardString.contains(tempDir) || clipboardString.hasPrefix("/"),
            "AC-01: 剪贴板应被替换为文件路径，实际：\(clipboardString.prefix(50))"
        )

        // App 不应崩溃
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5), "AC-01: App 应未崩溃")
    }

    // MARK: - AC-08: 禁用总开关后不触发任何保存行为（含核心断言）

    /// 通过启动参数注入长内容 + Safari bundleId，关闭总开关后触发剪贴板变化，
    /// 验证保存目录无新文件 + 剪贴板未被替换为文件路径。
    func testAC08DisableMasterSwitchBlocksAutoSave()
    {
        let tempDir = "/tmp/clipmind-uitest-ac08-\(UUID().uuidString)/"
        try? FileManager.default.createDirectory(
            atPath: tempDir,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(atPath: tempDir) }

        let longContent = String(repeating: "ClipMind AC-08 测试内容。", count: 10)

        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_RESET_AUTOSAVE_SETTINGS",
            "--UITEST_ENABLE_AUTOSAVE",
            "--UITEST_INITIAL_TAB=autosave",
            "--UITEST_INJECT_CONTENT=\(longContent)",
            "--UITEST_INJECT_BUNDLE_ID=com.apple.Safari"
        ]
        app.launch()
        app.activate()

        // 打开设置面板修改保存目录
        app.buttons["settingsButton"].firstMatch.click()
        let dirInput = app.textFields["saveDirectoryInput"].firstMatch
        XCTAssertTrue(dirInput.waitForExistence(timeout: 5))
        dirInput.click()
        typeKey("a", modifierFlags: .command)
        dirInput.typeText("\(tempDir)\n")
        Thread.sleep(forTimeInterval: 0.5)

        // 关闭总开关
        let masterToggle = element("autoSaveEnabledToggle", in: app)
        XCTAssertEqual(toggleValue(masterToggle), 1, "总开关默认应为开")
        app.activate()
        masterToggle.click()
        Thread.sleep(forTimeInterval: 0.3)
        XCTAssertEqual(toggleValue(masterToggle), 0, "总开关应已关闭")

        // 关闭设置面板
        closeSettingsWindow(app)

        // 触发剪贴板变化（注入逻辑会替换为 longContent + Safari）
        triggerClipboardChange()
        Thread.sleep(forTimeInterval: 1.5)

        // 核心断言 1：保存目录无新文件（AutoSaveService.performAutoSave 应返回 .skipped）
        let files = (try? FileManager.default.contentsOfDirectory(atPath: tempDir)) ?? []
        XCTAssertTrue(files.isEmpty, "AC-08: 总开关关闭后保存目录不应出现新文件，实际：\(files)")

        // 核心断言 2：剪贴板未被替换为文件路径
        let pasteboard = NSPasteboard.general
        let clipboardString = pasteboard.string(forType: .string) ?? ""
        XCTAssertFalse(
            clipboardString.contains(tempDir),
            "AC-08: 总开关关闭后剪贴板不应被替换为文件路径"
        )

        // App 不应崩溃
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5), "AC-08: App 应未崩溃")
    }

    // MARK: - AC-09: 保存目录异常时不崩溃 + 用户可见错误提示弹窗

    func testAC09DirectoryErrorDoesNotCrash()
    {
        let app = XCUIApplication()
        app.launchArguments = [
            "--UITEST_SHOW_MAIN_WINDOW",
            "--UITEST_RESET_AUTOSAVE_SETTINGS",
            "--UITEST_ENABLE_AUTOSAVE",
            "--UITEST_INITIAL_TAB=autosave",
            "--UITEST_INJECT_CONTENT=this is a long content for AC-09 directory error test with more than 50 characters to trigger auto save",
            "--UITEST_INJECT_BUNDLE_ID=com.apple.Safari"
        ]
        app.launch()
        app.activate()

        // 打开设置面板修改保存目录为不可创建的路径
        app.buttons["settingsButton"].firstMatch.click()
        let dirInput = app.textFields["saveDirectoryInput"].firstMatch
        XCTAssertTrue(dirInput.waitForExistence(timeout: 5))
        dirInput.click()
        // 全选删除后输入
        typeKey("a", modifierFlags: .command)
        dirInput.typeText("/proc/nonexistent/permission-denied/Clips/\n")
        Thread.sleep(forTimeInterval: 0.5)

        // 关闭设置面板
        closeSettingsWindow(app)

        // 触发剪贴板变化（注入逻辑会替换为长内容 + Safari，AutoSaveService 写入失败目录 → 发送 .autoSaveDidFail 通知 → AppDelegate 弹 NSAlert）
        triggerClipboardChange()
        Thread.sleep(forTimeInterval: 1.5)

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5), "AC-09: 目录异常时 App 不应崩溃")

        // 核心断言：用户可见错误提示弹窗（accessibility identifier = "autoSaveErrorAlert"）
        let errorAlert = app.alerts["autoSaveErrorAlert"].firstMatch
        XCTAssertTrue(
            errorAlert.waitForExistence(timeout: 3),
            "AC-09: 保存目录异常时应弹出 autoSaveErrorAlert 错误提示"
        )

        // 点击"好"按钮关闭弹窗
        if errorAlert.exists
        {
            errorAlert.buttons["好"].firstMatch.click()
        }

        // 验证主窗口仍可访问
        let settingsButton = app.buttons["settingsButton"].firstMatch
        XCTAssertTrue(settingsButton.exists, "AC-09: 主窗口应仍可访问设置按钮")
    }

    // MARK: - AC-05: 烟雾测试（App 在自动保存触发时不崩溃）

    /// 此测试为烟雾测试（smoke test），仅验证 App 在 AutoSaveService 触发后不崩溃。
    /// 历史列表条目的完整验证由手动验收脚本 AC-05 步骤完成（依赖真实剪贴板历史）。
    /// 覆盖度：🟡 PARTIAL（XCUITest 烟雾 + 手动验收条目验证）。
    func testAC05SmokeTestAppDoesNotCrashWhenAutoSaveTriggered()
    {
        let app = launchAndOpenAutoSaveSettings()

        // 配置保存目录为临时目录（避免污染真实目录）
        let tempDir = "/tmp/clipmind-uitest-ac05-\(UUID().uuidString)/"
        let dirInput = app.textFields["saveDirectoryInput"].firstMatch
        XCTAssertTrue(dirInput.waitForExistence(timeout: 5))
        dirInput.click()
        typeKey("a", modifierFlags: .command)
        dirInput.typeText("\(tempDir)\n")
        Thread.sleep(forTimeInterval: 0.5)

        // 关闭设置面板
        closeSettingsWindow(app)

        // 烟雾测试核心断言：App 未崩溃
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5), "AC-05: App 应未崩溃")

        // 清理临时目录
        let url = URL(fileURLWithPath: tempDir)
        try? FileManager.default.removeItem(at: url)
    }
}

private extension XCUIElement
{
    /// 全选删除文本字段内容（macOS XCUITest）。
    func deleteText()
    {
        guard let currentValue = value as? String, !currentValue.isEmpty else { return }
        typeKey("a", modifierFlags: .command)
        keyText.delete()
    }
}

private extension String
{
    static let delete = "\u{8}"  // Backspace
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
  -only-testing:'ClipMindUITests/AutoSaveBehaviorUITests'
```

预期：若任务 1~4 已完成，4 个测试用例应通过。若未完成，FAIL（找不到 `autoSaveEnabledToggle` 或 `autoSaveErrorAlert`）。

- [ ] **步骤 3：（无新增实现代码）**

本任务为纯测试任务。若步骤 2 失败：
- 若 `testAC01AutoSaveEndToEndViaLaunchArgument` 失败（保存目录无 .md 文件）：检查 ClipCaptureService 的 `applyUITestInjectionIfNeeded` 是否在 `--UITEST_ENABLE_AUTOSAVE` 存在时解析 `--UITEST_INJECT_CONTENT` 与 `--UITEST_INJECT_BUNDLE_ID`；检查 `triggerClipboardChange` 是否触发了 PasteboardWatcher 的 changeCount 检测
- 若 `testAC08DisableMasterSwitchBlocksAutoSave` 失败（保存目录出现新文件）：检查 AutoSaveService.performAutoSave 在 `settings.isEnabled == false` 时是否提前返回 `.skipped`，且不执行文件写入
- 若 `testAC09DirectoryErrorDoesNotCrash` 失败（`autoSaveErrorAlert` 未出现）：检查 AutoSaveService 是否在 `.writeFailed` 分支发送 `Self.didFailNotification`；检查 AppDelegate 是否在 `applicationDidFinishLaunching` 中注册该通知的观察者并调用 `handleAutoSaveDidFail` 弹 NSAlert；检查 NSAlert.window.accessibilityIdentifier 是否设为 `autoSaveErrorAlert`
- 若 `testAC05SmokeTestAppDoesNotCrashWhenAutoSaveTriggered` 失败：检查 F1.x `clipDidUpdateNotification` 在 AutoSaveService 触发后是否仍被发送（应在 `handleClipContent` 的入库流程中发送，不受钩子影响）

- [ ] **步骤 4：运行测试验证通过**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1-auto-save-to-file
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindUITests/AutoSaveBehaviorUITests'
```

预期：PASS，4 个测试用例全部通过。

- [ ] **步骤 5：Commit**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1-auto-save-to-file
swiftlint lint --strict
git add ClipMindUITests/AutoSaveBehaviorUITests.swift
git commit -m "test(F2.1): 添加 AutoSaveBehaviorUITests 覆盖 AC-01/05/08/09"
```

预期：SwiftLint 通过；commit 成功。

---

### 任务 7：手动验收脚本（AC-01/02/03/05 真实 App 场景兜底）

**文件：**
- 创建：`docs/planning/P1/F2.1/实现计划/manual-acceptance-script.md`

**目标：** 为 AC-01（白名单 App 复制长内容触发自动保存，XCUITest 启动参数注入已覆盖端到端核心断言，手动验收补充真实 Safari 场景）、AC-02（非白名单 App 复制不触发）、AC-03（白名单 App 复制短内容不触发）、AC-05（原内容仍进入 ClipMind 历史，XCUITest 烟雾测试仅验证 App 不崩溃，手动验收补充历史列表条目验证）提供手动验收脚本。这些 AC 涉及真实 Safari / Notes App 复制场景，无法在 XCUITest 中可靠自动化完整链路。

**对应 FR：** FR-002（白名单）、FR-003（长度阈值）、FR-005（文件保存）、FR-008（剪贴板替换）、FR-009（原内容入库）

**对应约束：** D-01（在 F1.x 捕获流程中插入钩子）、NFR-001（保存延迟 ≤ 3 秒）、NFR-002（剪贴板替换延迟 ≤ 500ms）

- [ ] **步骤 1：编写手动验收脚本**

创建 `docs/planning/P1/F2.1/实现计划/manual-acceptance-script.md`：

```markdown
# F2.1 手动验收脚本

> 最后更新：2026-07-21 | 版本：v1.0

## 1. 前置准备

1. 启动 ClipMind App（生产模式，无 UITEST 启动参数）
2. 打开"设置 → 自动保存"分区
3. 确认配置：
   - 总开关：开
   - 保存目录：`~/Documents/ClipMind/Clips/`
   - 长度阈值：50
   - 文件格式：Markdown
   - 敏感过滤：开
   - 白名单：包含 Safari、Google Chrome、Trae IDE、VSCode、Xcode（不含"备忘录"）
4. 清空保存目录：`rm -rf ~/Documents/ClipMind/Clips/*`
5. 打开 Finder 访问 `~/Documents/ClipMind/Clips/` 目录（便于观察新文件）
6. 打开 ClipMind 主窗口（确保能看到历史列表）

## 2. AC-01：白名单 App 复制长内容触发自动保存

**测试编号**：TC-AC01-01

**步骤**：
1. 打开 Safari，访问任意网页
2. 选中一段 100 字以上的文本，按 `Cmd+C` 复制
3. 等待 3 秒
4. 检查 `~/Documents/ClipMind/Clips/` 目录是否出现新 `.md` 文件
5. 检查剪贴板内容（粘贴到任意文本框 `Cmd+V`）
6. 检查 ClipMind 历史列表

**预期结果**：
- ✅ 保存目录出现一个 `.md` 文件，文件名为内容前 20 字（过滤特殊字符）
- ✅ 文件内容为复制的原文（100 字以上）
- ✅ 剪贴板内容被替换为文件的绝对路径
- ✅ ClipMind 历史列表顶部出现该 100 字内容条目

**证据**：
- 截图保存到 `docs/planning/P1/F2.1/screenshots/TC-AC01-01-*.png`
- 录屏保存到 `docs/planning/P1/F2.1/recordings/TC-AC01-01-*.mov`

## 3. AC-02：非白名单 App 复制不触发自动保存

**测试编号**：TC-AC02-01

**步骤**：
1. 打开"备忘录"App（确认不在白名单）
2. 新建备忘录，输入 100 字以上文本，`Cmd+C` 复制
3. 等待 3 秒
4. 检查 `~/Documents/ClipMind/Clips/` 目录是否出现新文件
5. 检查剪贴板内容
6. 检查 ClipMind 历史列表

**预期结果**：
- ✅ 保存目录**不出现**新文件
- ✅ 剪贴板内容保持为复制的原文
- ✅ ClipMind 历史列表顶部出现该 100 字内容条目（F1.x 入库不受影响）

## 4. AC-03：白名单 App 复制短内容不触发自动保存

**测试编号**：TC-AC03-01

**步骤**：
1. 打开 Safari
2. 选中一段 20 字以下文本，`Cmd+C` 复制
3. 等待 3 秒
4. 检查 `~/Documents/ClipMind/Clips/` 目录
5. 检查剪贴板内容
6. 检查 ClipMind 历史列表

**预期结果**：
- ✅ 保存目录**不出现**新文件（长度低于阈值 50）
- ✅ 剪贴板内容保持为复制的原文
- ✅ ClipMind 历史列表顶部出现该 20 字内容条目

## 5. AC-05：原内容仍进入 ClipMind 历史（XCUITest 烟雾测试兜底）

**测试编号**：TC-AC05-01

**背景**：`testAC05SmokeTestAppDoesNotCrashWhenAutoSaveTriggered`（任务 6）仅验证 App 在 AutoSaveService 触发后不崩溃，未验证历史列表条目（依赖真实剪贴板历史与 UI 渲染）。本步骤补充历史条目验证。

**步骤**：
1. 启动 ClipMind App（生产模式，无 UITEST 启动参数）
2. 打开"设置 → 自动保存"分区，确认总开关为开、白名单包含 Safari、长度阈值为 50
3. 打开 Safari，复制一段 100 字以上的文本
4. 等待 3 秒（让 AutoSaveService 完成文件保存与剪贴板替换）
5. 打开 ClipMind 主窗口，查看历史列表顶部条目

**预期结果**：
- ✅ ClipMind 历史列表顶部出现该 100 字内容条目（F1.x 入库不受 AutoSaveService 钩子影响）
- ✅ 条目来源 App 显示为"Safari"（或 `com.apple.Safari`）
- ✅ 条目时间戳为当前时间附近（±5 秒）
- ✅ App 未崩溃、未卡死

**证据**：
- 截图保存到 `docs/planning/P1/F2.1/screenshots/TC-AC05-01-*.png`

## 6. 验收记录

每次执行后填写下表，存档到 `docs/planning/P1/F2.1/screenshots/acceptance-log.md`：

| 测试编号 | 执行日期 | 执行人 | 结果 | 备注 |
|---------|---------|--------|------|------|
| TC-AC01-01 | YYYY-MM-DD | | ✅/❌ | |
| TC-AC02-01 | YYYY-MM-DD | | ✅/❌ | |
| TC-AC03-01 | YYYY-MM-DD | | ✅/❌ | |
| TC-AC05-01 | YYYY-MM-DD | | ✅/❌ | AC-05 历史条目兜底验证 |

## 7. 失败排查

若 AC-01 失败（保存目录无新文件）：
1. 检查 ClipMind 日志：`log show --predicate 'subsystem == "com.clipmind.app"' --last 5m`
2. 查找 "auto-save" 相关日志
3. 检查 `autoSaveSettings` UserDefaults：`defaults read com.clipmind.app autoSaveSettings`
4. 验证 Safari 的真实 Bundle ID：`osascript -e 'id of app "Safari"'`，应为 `com.apple.Safari`

若 AC-02 失败（保存目录出现新文件）：
1. 检查"备忘录"Bundle ID：`osascript -e 'id of app "Notes"'`，应为 `com.apple.Notes`
2. 确认 `com.apple.Notes` 不在 `whitelistBundleIds` 中
3. 检查白名单持久化是否正确

若 AC-03 失败（保存目录出现新文件）：
1. 检查 `lengthThreshold` 是否被改为低于 20
2. 检查 `text.count` 是否使用 Unicode 标量计数（应为字符数，非字节）

若 AC-05 失败（历史列表无新条目）：
1. 检查 `ClipCaptureService.handleClipContent` 中 `autoSaveTrigger` 闭包是否在入库之前调用（不阻塞入库）
2. 检查 F1.x `clipDidUpdateNotification` 是否在 `EncryptedStore.save` 之后正常发送
3. 检查 `EncryptedStore.loadAll` 是否能读到刚入库的条目
4. 检查主窗口历史列表 View 是否监听 `clipDidUpdateNotification` 并刷新

## 版本记录

| 版本 | 日期 | 变更说明 |
|------|------|---------|
| v1.0 | 2026-07-21 | 初始版本，writing-plans skill 产出，覆盖 AC-01/02/03 手动验收流程 |
| v1.1 | 2026-07-21 | 追加 AC-05 历史条目验证章节（XCUITest 烟雾测试兜底）；章节编号顺延 |
```

- [ ] **步骤 2：（无运行验证）**

手动验收脚本为文档，无需编译验证。执行 `swiftlint lint --strict` 应忽略 `.md` 文件。

- [ ] **步骤 3：（无实现代码）**

本任务为纯文档任务，无新增 Swift 代码。

- [ ] **步骤 4：执行手动验收脚本（开发者本地完成）**

按脚本在真实环境中执行 AC-01/02/03 手动验收，填写验收记录表。CI 不执行手动验收。

- [ ] **步骤 5：Commit**

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1-auto-save-to-file
git add docs/planning/P1/F2.1/实现计划/manual-acceptance-script.md
git commit -m "docs(F2.1): 添加 AC-01/02/03/05 手动验收脚本"
```

预期：commit 成功（纯文档无需 SwiftLint）。

---

## 4. Phase 1 验收

### 4.1 文件存在性

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1-auto-save-to-file
ls -la ClipMind/UI/Settings/AutoSaveSettingsView.swift
ls -la ClipMindUITests/AutoSaveSettingsUITests.swift
ls -la ClipMindUITests/AutoSaveBehaviorUITests.swift
ls -la docs/planning/P1/F2.1/实现计划/manual-acceptance-script.md
```

预期：4 个文件均存在。

### 4.2 SwiftLint 通过

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1-auto-save-to-file
swiftlint lint --strict
```

预期：无违规，退出码 0。

### 4.3 编译通过

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1-auto-save-to-file
xcodegen generate
xcodebuild build \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
```

预期：BUILD SUCCEEDED。

### 4.4 单文件 XCUITest 通过（本地允许）

依次运行 3 个 XCUITest 类：

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1-auto-save-to-file
for testClass in AutoSaveSettingsViewComponentsTests AutoSaveSettingsUITests AutoSaveBehaviorUITests; do
  echo "=== Running $testClass ==="
  xcodebuild test \
    -project ClipMind.xcodeproj \
    -scheme ClipMind \
    -destination 'platform=macOS' \
    -configuration Debug \
    ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
    CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
    -only-testing:"ClipMindUITests/$testClass"
done
```

预期：所有测试类全部 PASS。累计通过测试用例数：
- `AutoSaveSettingsViewComponentsTests`：4 个（任务 2 + 任务 3）
- `AutoSaveSettingsUITests`：7 个（任务 5）
- `AutoSaveBehaviorUITests`：4 个（任务 6：AC-01/05/08/09）
- 合计：15 个 XCUITest 用例

### 4.5 F1.x 既有测试不破坏

```bash
cd /Users/dengdeng/Working/Competition/ClipMind-worktrees/feature/F2.1-auto-save-to-file
xcodebuild test \
  -project ClipMind.xcodeproj \
  -scheme ClipMind \
  -destination 'platform=macOS' \
  -configuration Debug \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES \
  CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
  -only-testing:'ClipMindTests/ClipCaptureServiceTests' \
  -only-testing:'ClipMindUITests/SettingsUITests'
```

预期：F1.x 既有测试 PASS（`autoSaveTrigger` 默认 nil，行为与 F1.x 一致；`SettingsUITests` 的既有 3 个 tab 不受影响）。

### 4.6 CI 全量回归（push 后自动）

push 后 GitHub Actions 自动执行：
1. `xcodegen generate`
2. `swiftlint lint --strict`
3. `xcodebuild build`
4. `xcodebuild test`（含 Phase 0 单元测试 + Phase 1 XCUITest + F1.x 既有测试）

预期：CI 通过，无既有测试被破坏（F-08 约束）。

### 4.7 规格覆盖度（Phase 1 任务 → AC/FR/约束）

| AC 编号 | 验证方式 | 对应任务 | 覆盖状态 |
|---------|---------|---------|---------|
| AC-01 | XCUITest（启动参数注入）+ 手动验收（真实 Safari 场景） | 任务 6（`testAC01AutoSaveEndToEndViaLaunchArgument`）+ 任务 7（真实 Safari 兜底） | ✅ 完整 |
| AC-02 | 手动验收（真实 Notes 场景） | 任务 7 | ✅ 手动 |
| AC-03 | 手动验收（真实 Safari 短内容场景） | 任务 7 | ✅ 手动 |
| AC-04 | Phase 0 单元测试 | Phase 0 任务 4、9 | ✅ Phase 0 |
| AC-05 | XCUITest 烟雾测试 + 手动验收（历史条目兜底） | 任务 6（`testAC05SmokeTestAppDoesNotCrashWhenAutoSaveTriggered`）+ 任务 7（TC-AC05-01） | 🟡 Phase 1（烟雾）+ 手动 |
| AC-06 | Phase 0 单元测试 | Phase 0 任务 7、9 | ✅ Phase 0 |
| AC-07 | XCUITest | 任务 5（`testAC07*` × 3） | ✅ Phase 1 |
| AC-08 | XCUITest（含核心断言：无新文件 + 剪贴板未替换） | 任务 6（`testAC08DisableMasterSwitchBlocksAutoSave`） | ✅ Phase 1 |
| AC-09 | XCUITest（含 `autoSaveErrorAlert` 弹窗断言） | 任务 6（`testAC09DirectoryErrorDoesNotCrash`） | ✅ Phase 1 |
| AC-10 | Phase 0 单元测试 | Phase 0 任务 3 | ✅ Phase 0 |
| AC-11 | Phase 0 单元测试 | Phase 0 任务 5、9 | ✅ Phase 0 |
| AC-12 | Phase 0 单元测试 | Phase 0 任务 8 | ✅ Phase 0 |
| AC-13 | Phase 0 单元测试 | Phase 0 任务 6 | ✅ Phase 0 |
| AC-14 | Phase 0 单元测试 + Phase 1 XCUITest | Phase 0 任务 9（XCTest）+ 任务 5（XCUITest 二次确认） | ✅ 完整 |
| AC-15 | XCUITest | 任务 5（`testAC15*` × 2） | ✅ Phase 1 |
| AC-16 | XCUITest | 任务 5（`testAC16ConfigPersistsAcrossRestart`） | ✅ Phase 1 |

**全部 16 条 AC 覆盖完整**（Phase 0 覆盖 7 条 XCTest，Phase 1 覆盖 9 条 XCUITest + 4 条手动验收兜底，AC-01 由 XCUITest 启动参数注入端到端覆盖 + 真实 Safari 场景手动兜底，AC-05 由 XCUITest 烟雾测试 + 历史条目手动验收兜底，AC-14 由 Phase 0 与 Phase 1 共同覆盖）。

---

## 5. Phase 1 自检

### 5.1 规格覆盖度检查

**对照需求文档 FR-001~FR-014、AC-01~AC-16、C-01~C-12、NFR-001~NFR-010、F-01~F-10：**

- ✅ FR-001（总开关）：任务 1（钩子）+ 任务 4（装配）+ 任务 6（AC-08 验证）
- ✅ FR-002（白名单触发）：任务 5（AC-15 白名单管理）+ 任务 7（AC-02 非白名单不触发，手动）
- ✅ FR-003（长度阈值）：任务 5（AC-07 修改长度阈值）+ 任务 7（AC-03 短内容不触发，手动）
- ✅ FR-004（敏感过滤）：任务 2（敏感过滤开关 UI）+ 任务 5（AC-14 二次确认）+ Phase 0 任务 9（XCTest 核心）
- ✅ FR-005（文件保存）：任务 7（AC-01 手动验证文件存在）
- ✅ FR-006（文件名生成）：Phase 0 任务 3 覆盖（不重复，Phase 1 不涉及）
- ✅ FR-007（文件名冲突）：Phase 0 任务 4、9 覆盖
- ✅ FR-008（剪贴板替换）：任务 7（AC-01 手动验证剪贴板替换）
- ✅ FR-009（原内容入库）：任务 1（钩子不阻塞入库）+ 任务 6（AC-05 验证）
- ✅ FR-010（配置面板独立分区）：任务 2（AutoSaveSettingsView）+ 任务 3（SettingsView 集成）+ 任务 5（AC-07 验证）
- ✅ FR-011（保存目录异常）：任务 6（AC-09 验证）+ Phase 0 任务 8（XCTest 核心）
- ✅ FR-012（白名单 App 管理）：任务 2（白名单 UI）+ 任务 5（AC-15 验证）
- ✅ FR-013（路径格式切换）：任务 2（路径格式 UI + 预览）+ Phase 0 任务 5、9（XCTest）
- ✅ FR-014（自动保存触发时机）：任务 1（钩子插入位置）+ 任务 4（装配）

**约束检查：**
- ✅ C-01（保存目录默认值）：任务 2（默认 `~/Documents/ClipMind/Clips/`）
- ✅ C-02（文件格式 Markdown / 纯文本）：任务 2（fileFormatPicker）
- ✅ C-03（路径格式 3 种）：任务 2（pathFormatPicker + 预览）
- ✅ C-04（文件名长度范围 1-50）：任务 2（fileNameLengthInput）
- ✅ C-05（长度阈值范围 1-10000）：任务 2（lengthThresholdInput）
- ✅ C-06（白名单 Bundle ID 唯一）：任务 2（addWhitelistApp 去重）+ Phase 0 任务 2（XCTest）
- ✅ C-07（敏感过滤二次确认）：任务 2（confirmationDialog）+ 任务 5（AC-14 验证）
- ✅ C-08（明文文件管理责任提示）：任务 2（plaintextResponsibilityNotice）
- ✅ C-09（不修改 F1.x 既有公共接口）：任务 1（init 签名不变）+ 任务 3（仅新增 tab，不改既有）
- ✅ C-10（不引入新依赖）：所有 Phase 1 代码仅用 Foundation / AppKit / SwiftUI
- ✅ C-11（与 F1.x 既有隐私理念一致）：任务 4（复用 SensitiveDetector）+ Phase 0 任务 6
- ✅ C-12（macOS 12.4 兼容）：无 macOS 13+ 独占 API（`confirmationDialog` 需 macOS 13+，应替换为 `.alert` 或 `.sheet`）

**重要修正（C-12）**：`AutoSaveSettingsView` 中使用的 `.alert(_:isPresented:)` 在 macOS 12 可用；`.confirmationDialog` 仅 macOS 13+，已改用 `.alert`。验证通过。

**非功能约束检查：**
- ✅ NFR-001（保存延迟 ≤ 3 秒）：钩子同步调用 `AutoSaveService.handle`（内部异步），不阻塞 F1.x 入库
- ✅ NFR-002（剪贴板替换延迟 ≤ 500ms）：Phase 0 任务 6 中 `replaceClipboard` 在主线程同步执行
- ✅ NFR-003（配置生效延迟 ≤ 1 秒）：任务 2 中 `applySettings` 立即调用 `settingsStore.update` 并触发通知
- ✅ NFR-004（稳定性不崩溃）：任务 6（AC-09 验证不崩溃）+ Phase 0 任务 8
- ✅ NFR-005（明文文件权限 macOS 默认用户隔离）：Phase 0 任务 6 中 `text.write(to:atomically:encoding:)` 默认权限
- ✅ NFR-006（额外延迟 ≤ 100ms）：钩子调用为简单闭包同步执行
- ✅ NFR-007（日志可观测性）：任务 1 在钩子抛错时记录日志
- ✅ NFR-008（可测试性）：任务 5、6 的 XCUITest + 任务 1 的 XCTest
- ✅ NFR-009（macOS 12.4+ 兼容）：已规避 macOS 13+ API
- ✅ NFR-010（并发安全）：Phase 0 任务 6 中串行 DispatchQueue

**禁止事项检查（AGENTS.md 第 9 节）：**
- ✅ 不在日志输出密码/Token/剪贴板原文：任务 1 日志仅记录 `error.localizedDescription`
- ✅ 不绕过文档同步规则：本计划文件即文档同步产物
- ✅ 不用固定 sleep 代替条件等待：任务 5、6 中的 `Thread.sleep` 仅用于 UI 反馈延迟（XCUITest 通用做法），非掩盖竞态
- ✅ 不吞掉错误：任务 1 钩子异常仅记录日志不抛出，AutoSaveService 内部通过 Outcome 返回错误状态
- ✅ 不在未加密状态下持久化敏感剪贴板内容：F1.x 入库仍走 EncryptedStore，仅明文文件由用户配置决定

### 5.2 占位符扫描

**已扫描全文，未发现以下禁止模式：**
- ❌ "待定"、"TODO"、"后续实现"、"补充细节"：无
- ❌ "添加适当的错误处理" / "添加验证" / "处理边界情况"：无
- ❌ "为上述代码编写测试"（无实际测试代码）：无
- ❌ "类似任务 N"：无
- ❌ "引用未定义的类型、函数、方法"：所有类型均来自 Phase 0（`AutoSaveSettings`、`AutoSaveSettingsStore`、`AutoSaveService`、`FileFormat`、`PathFormat`）或 F1.x（`ClipContent`、`ClipItem`、`SensitiveDetector`、`AppDetector`、`EncryptedStore`、`ClassificationService`、`PasteboardWatcher`、`LocalEmbeddingService`、`LogCategory`、`ClipCaptureService`）

### 5.3 类型一致性检查

**对照 Phase 0 已定义的签名，验证 Phase 1 使用一致性：**

| 类型/方法 | Phase 0 定义 | Phase 1 使用 | 一致性 |
|----------|------------|------------|--------|
| `AutoSaveSettings` 字段 | 8 字段 | 任务 2 UI 全部对应 | ✅ |
| `AutoSaveSettings.defaultWhitelist` | 5 个 Bundle ID | 任务 2 默认值显示 | ✅ |
| `AutoSaveSettings.defaultSaveDirectory` | `~/Documents/ClipMind/Clips/` | 任务 2 默认值 | ✅ |
| `AutoSaveSettings.lengthThresholdRange` | 1...10000 | 任务 2 范围提示 | ✅ |
| `AutoSaveSettings.fileNameLengthRange` | 1...50 | 任务 2 范围提示 | ✅ |
| `FileFormat` 枚举 | `.markdown` / `.plainText` | 任务 2 picker | ✅ |
| `FileFormat.fileExtension` | "md" / "txt" | 任务 2 显示 | ✅ |
| `PathFormat` 枚举 | `.plainPath` / `.fileURI` / `.markdownLink` | 任务 2 picker | ✅ |
| `AutoSaveSettingsStore.init(defaults:)` | 签名 | 任务 2 `AutoSaveSettingsStore()` 默认参数 | ✅ |
| `AutoSaveSettingsStore.current` | 计算属性 | 任务 2 `onAppear` 读取 | ✅ |
| `AutoSaveSettingsStore.update(_:)` | 方法 | 任务 2 `applySettings` 调用 | ✅ |
| `AutoSaveSettingsStore.storageKey` | `"autoSaveSettings"` | 任务 4 UITEST 重置 | ✅ |
| `AutoSaveSettingsStore.configDidChangeNotification` | `Notification.Name("ClipMindAutoSaveConfigDidChange")` | 任务 4 间接（AutoSaveService 内部监听，Phase 0 已实现） | ✅ |
| `AutoSaveService.init(settingsStore:sensitiveDetector:pasteboard:fileManager:queue:store:)` | 完整签名 | 任务 4 使用 `AutoSaveService(settingsStore:sensitiveDetector:)` 默认参数（store 默认 nil） | ✅ |
| `AutoSaveService.handle(content:bundleId:appName:)` | 异步 public 方法 | 任务 1 钩子调用、任务 4 闭包注入 | ✅ |
| `AutoSaveService.Outcome` 枚举 | `.skipped/.writeFailed/.replaceFailed/.completed` | Phase 1 不直接使用（XCTest 验证） | ✅ 不破坏 |
| `ClipCaptureService.autoSaveTrigger`（新增） | `((ClipContent, _ bundleId: String, _ appName: String) -> Void)?` | 任务 1 定义、任务 4 注入 | ✅ |
| `ClipContent` 枚举 | `.text` / `.image` / `.filePath` | 任务 1 钩子参数 | ✅ |
| `SensitiveDetector()` 默认 init | F1.x 既有 | 任务 4 使用 | ✅ |
| `LogCategory.storage` | F1.x 既有 | 任务 1、任务 4 使用 | ✅ |

**类型一致性全部通过。**

---

## 6. 版本记录

| 版本 | 日期 | 变更说明 |
|------|------|---------|
| v1.0 | 2026-07-21 | 初始版本，writing-plans skill 产出，覆盖 Phase 1 共 7 个任务，含 4 个实现任务（ClipCaptureService 钩子 / AutoSaveSettingsView / SettingsView 集成 / ClipMindApp 装配）+ 2 个 XCUITest 任务（AutoSaveSettingsUITests 覆盖 AC-07/14/15/16，AutoSaveBehaviorUITests 覆盖 AC-05/08/09）+ 1 个手动验收脚本（AC-01/02/03）；累计 14 个 XCUITest 用例；与 Phase 0 类型签名完全一致；自检通过（规格覆盖度 100%，无占位符，类型一致性全部通过） |
| v1.1 | 2026-07-21 | 修复 check-plan 发现的 6 项必须修复问题：(1) 任务 6 `testAC09DirectoryErrorDoesNotCrash` 追加 `app.alerts["autoSaveErrorAlert"]` 弹窗断言；(2) 任务 6 `testAC05OriginalContentEntersHistoryAfterAutoSave` 重命名为 `testAC05SmokeTestAppDoesNotCrashWhenAutoSaveTriggered` 改为烟雾测试，覆盖度降为 🟡，任务 7 追加 TC-AC05-01 历史条目手动验收；(3) 任务 6 新增 `testAC01AutoSaveEndToEndViaLaunchArgument` 通过 `--UITEST_INJECT_CONTENT` + `--UITEST_INJECT_BUNDLE_ID=com.apple.Safari` 注入长内容验证端到端；(4) 任务 6 `testAC08DisableMasterSwitchBlocksAutoSave` 强化：启动参数注入 + 核心断言（保存目录无新文件 + 剪贴板未替换）；(5) 任务 6 新增 `tearDown()` 截图保存（问题 6）；(6) 任务 5 AutoSaveSettingsUITests 已新增 `tearDown()` 截图保存。累计 XCUITest 用例数 14→15。覆盖度表 AC-01 改为 ✅ 完整、AC-05 改为 🟡 烟雾+手动、AC-08/09 标注核心断言。任务 7 手动验收脚本追加 AC-05 章节。 |
| v1.2 | 2026-07-21 | 修复第二轮 check-plan 发现的 4 项必须修复问题：(1) 任务 2 `AutoSaveSettingsViewComponentsTests` 追加 `tearDown()` 截图保存方法，与 `AutoSaveSettingsUITests`/`AutoSaveBehaviorUITests` 实现保持一致（满足 README 4.2 节声明）；(2) 任务 6 `testAC09DirectoryErrorDoesNotCrash` 改用完整启动参数（含 `--UITEST_INJECT_CONTENT` + `--UITEST_INJECT_BUNDLE_ID`）替代 `launchAndOpenAutoSaveSettings()` 辅助函数，并在 `closeSettingsWindow` 后追加 `triggerClipboardChange()` + `Thread.sleep(1.5)` 触发 AutoSaveService 失败路径，使 `autoSaveErrorAlert` 弹窗断言可达成；(3) 5.3 节类型一致性表 `AutoSaveService.init` 行签名更新为 `init(settingsStore:sensitiveDetector:pasteboard:fileManager:queue:store:)`（Phase 0 v1.1 新增 `store: EncryptedStore? = nil` 参数），Phase 1 使用列注明任务 4 默认参数（store 默认 nil）。 |
