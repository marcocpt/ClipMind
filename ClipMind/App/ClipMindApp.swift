import SwiftUI

@main
struct ClipMindApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @AppStorage("hasCompletedOnboarding")
    var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    MainWindow(tagStore: appDelegate.tagStore)
                        .frame(
                            minWidth: LayoutConstants.appWindowMinWidth,
                            minHeight: LayoutConstants.appWindowMinHeight
                        )
                } else {
                    OnboardingView()
                        .frame(width: 560, height: 480)
                }
            }
            .id(hasCompletedOnboarding)
        }

        Settings {
            SettingsView(tagStore: appDelegate.tagStore)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    // F1.11：改为 internal 以便 StatusItemAssembly.swift 同模块访问
    var statusItemController: StatusItemController?
    private var cleanupService: CleanupService?
    private var captureService: ClipCaptureService?
    private var hotkeyService: GlobalHotkeyService?
    private var autoSaveService: AutoSaveService?
    // F1.11 Bug 3：由 private 改为 internal，使 QuickPasteAssembly / StatusItemAssembly /
    // PopoverPreviewWindowFactory 等 extension 可访问共享实例，注入到 ClipboardWriter，
    // 与 PasteboardWatcher 共享同一套自我写入抑制机制。
    var selfWriteSuppressor: SelfWriteSuppressor?
    // F1.11 Bug 4：双击粘贴后置顶器，供 PasteCoordinator 装配点共享。
    // 在 setupServices 中基于 EncryptedStore 初始化，注入到 QuickPaste/StatusItem 装配点。
    var clipToucher: EncryptedStoreClipToucher?
    // F2.1.1 新增：Toast 协调模块
    private var toastCoordinator: ToastCoordinator?
    // internal 以便 QuickPasteAssembly.swift 同模块访问
    var quickPastePanelController: QuickPastePanelController?
    var pasteCoordinator: PasteCoordinator?

    #if CLIPMIND_DEV
    /// F1.14 Phase 5：粘贴探针，仅在 `--UITEST_TAG_PASTE_PROBE` 模式下创建。
    /// 供 XCUITest 读取 `pasteReceiverText`/`pasteEventCount` 验证标签点击不触发粘贴。
    var tagPasteProbe: TagPasteProbe?
    #endif

    /// F1.14 标签后端：唯一 `TagServicing` 和迁移协调器。
    @MainActor lazy var tagBackend = TagBackendFactory.makeDefault()

    /// F1.14 共享标签 UI 状态：主窗口、菜单栏弹窗、快捷粘贴面板共用同一实例。
    ///
    /// 基于 `tagBackend` 构造，不在 UI 层再次创建 `EncryptedStore` 或 `TagService`。
    /// 初始化失败时仍持有 `UnavailableTagService` 后端，标签编辑显示安全错误并禁用。
    @MainActor lazy var tagStore = TagStore(
        service: tagBackend.service,
        migrationCoordinator: tagBackend.migrationCoordinator
    )

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
        "F2.1.autoSave.pathFormat",
        "F2.1.autoSave.showFilePathInHistory"
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

    func applicationWillFinishLaunching(_ notification: Notification) {
        // 在 SwiftUI 读取 @AppStorage 之前执行通用重置，避免先渲染错误视图再切换
        applyOnboardingResetIfNeeded()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        applyUITestOverrides()
        configureActivationPolicy()
        if CommandLine.arguments.contains("--UITEST_POPOVER_WINDOW") {
            showPopoverContentInWindow()
        }
        // F1.14：UITEST 模式下居中主窗口。
        // SwiftUI WindowGroup 会恢复上次保存的窗口位置，可能离屏导致 XCUITest
        // 无法点击标签 pill 等元素。在下一运行循环居中主窗口确保可见。
        // --UITEST_QUICK_PASTE_PANEL 也需要调用：SwiftUI WindowGroup 会创建主窗口，
        // 主窗口与面板存在同 ID 的标签 pill，隐藏主窗口避免 XCUITest 命中主窗口 pill。
        if CommandLine.arguments.contains("--UITEST_SHOW_MAIN_WINDOW")
            || CommandLine.arguments.contains("--UITEST_QUICK_PASTE_PANEL")
        {
            centerMainWindowForUITest()
        }
        // F1.14：UITEST 触发面板失焦关闭。
        // testPanelCloses_OnResignFocus 需要验证面板失焦后自动关闭，
        // 但 SwiftUI WindowGroup 创建的主窗口在 CI 中不可靠可见。
        // 通过创建临时窗口并抢夺 key 状态，触发面板 didResignKey → closePanel。
        if CommandLine.arguments.contains("--UITEST_TRIGGER_PANEL_RESIGN")
        {
            triggerPanelResignKey()
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenMainWindow),
            name: .openMainWindow,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenQuickPaste),
            name: .openQuickPaste,
            object: nil
        )
        // F1.11 Phase 3：监听「打开设置窗口」信号
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenSettings),
            name: .openSettingsWindow,
            object: nil
        )
        // 监听 F2.1 自动保存错误通知（D13 目录异常分级处理）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAutoSaveError(_:)),
            name: AutoSaveService.errorNotification,
            object: nil
        )
        // F2.1.1 测试入口：通过 --UITEST_TOAST_TRIGGER 模拟保存成功通知
        handleToastUITestTriggerIfNeeded()
        // F1.14：启动可恢复标签迁移
        startTagMigration()
    }

    /// F1.14：在首个界面装配后加载标签快照并启动可恢复迁移。
    ///
    /// 通过共享 `tagStore` 路由：先 `load()` 读取当前快照供 UI 渲染，再
    /// `resumeMigration()` 启动迁移。迁移失败时 `tagStore.failedOperation`
    /// 置为 `.migration`，由 `MainWindow` 的迁移重试 banner 展示安全错误，
    /// 不再发送 `.clipTagMigrationNeedsRetry`。
    @MainActor
    private func startTagMigration()
    {
        tagStore.load()
        tagStore.resumeMigration()
    }

    // F1.11 合并修复：UITest 启动参数处理方法（handleToastUITestTriggerIfNeeded /
    // applyOnboardingResetIfNeeded / applyUITestOverrides）已提取到
    // AppDelegate+UITestOverrides.swift，缓解 type_body_length 违规。

    /// 根据引导状态配置激活策略和服务
    @MainActor
    private func configureActivationPolicy() {
        let completed = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        LogCategory.app.info(
            "Launch: hasCompletedOnboarding=\(completed), "
            + "args=\(CommandLine.arguments.filter { $0.hasPrefix("--UITEST") })"
        )
        if completed {
            if CommandLine.arguments.contains("--UITEST_SHOW_MAIN_WINDOW")
                || CommandLine.arguments.contains("--UITEST_QUICK_PASTE_PANEL")
            {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
            } else {
                NSApp.setActivationPolicy(.accessory)
            }
            setupServices()
            setupHotkeyService()
            setupQuickPastePanelController()
            setupStatusItemController()
        } else {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// 初始化共享 EncryptedStore 并启动捕获与清理服务
    private func setupServices() {
        do {
            let store = try EncryptedStore()
            setupCaptureService(store: store)
            setupCleanupService(store: store)
            // F1.11 Bug 4：基于共享 store 创建置顶器，供 PasteCoordinator 装配点注入
            clipToucher = EncryptedStoreClipToucher(store: store)

            // UI 测试预置数据（仅 --UITEST_PREPOPULATE_SAMPLE_AND_REAL 启动参数时执行）
            if CommandLine.arguments.contains("--UITEST_PREPOPULATE_SAMPLE_AND_REAL") {
                prepopulateTestData(store: store)
            }
        } catch {
            LogCategory.storage.error("EncryptedStore 初始化失败: \(error.localizedDescription)")
        }
    }

    /// UI 测试专用：预置 13 条示例 + 2 条真实数据到 EncryptedStore。
    ///
    /// 用于 UI-SD-02/03 测试场景：启动后直接显示主窗口（跳过引导），
    /// 数据库已含示例 + 真实条目，便于验证清除示例后真实数据保留。
    /// 生产环境不调用此方法。
    private func prepopulateTestData(store: EncryptedStore) {
        let embeddingService = LocalEmbeddingService()
        SampleDataSeeder.seedIfNeeded(store: store, embeddingService: embeddingService)

        // 追加 2 条真实数据（isSample=false）
        let realItem1 = ClipItem.makeText(
            "真实复制的文本内容",
            contentType: .other,
            sourceApp: "com.test.real",
            sourceAppName: "RealApp",
            isSample: false
        )
        let realItem2 = ClipItem.makeText(
            "另一条真实复制内容",
            contentType: .other,
            sourceApp: "com.test.real",
            sourceAppName: "RealApp",
            isSample: false
        )
        do {
            try store.save(realItem1)
            try store.save(realItem2)
            NotificationCenter.default.post(
                name: ClipCaptureService.clipDidUpdateNotification,
                object: nil
            )
        } catch {
            LogCategory.storage.error("预置真实测试数据失败: \(error.localizedDescription)")
        }
    }

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

        // 装配 onFilePathSaved 回调：将文件路径以 ClipContent.filePath 存入历史
        autoSave.onFilePathSaved = { [weak self] savedURL, _ in
            self?.saveFilePathToHistory(savedURL, store: store)
        }

        // F2.1.1 装配：Toast 协调模块
        // - 注入 MainTimerSource 作为生产计时器源（D7）
        // - 注入 F2.1 总开关查询闭包，读取 AutoSaveSettingsStore 快照（D4）
        let toastWindowManager = ToastWindowManager()
        let toastCoordinator = ToastCoordinator(
            windowManager: toastWindowManager,
            timerSource: MainTimerSource(),
            isEnabledProvider: { settingsStore.load().isEnabled }
        )
        self.toastCoordinator = toastCoordinator

        let watcher = PasteboardWatcher(eventBuilder: eventBuilder, suppressor: suppressor)
        captureService = ClipCaptureService(watcher: watcher, store: store, classifier: classifier)
        captureService?.autoSaveService = autoSave
        captureService?.start()

        LogCategory.app.logger.info("剪贴板捕获服务已启动（含 F2.1 自动保存 + F2.1.1 Toast）")
    }

    /// 将文件路径存入 ClipMind 历史（以 ClipContent.filePath 可拖拽格式）。
    /// 由 AutoSaveService.onFilePathSaved 回调触发（在 AutoSave 串行队列上）。
    /// 派发到主线程执行 store.save，避免与 ClipCaptureService 的 store.save 产生 SQLite 竞态。
    private func saveFilePathToHistory(_ fileURL: URL, store: EncryptedStore)
    {
        DispatchQueue.main.async
        {
            let item = ClipItem.makeFilePath(
                [fileURL],
                contentType: .other,
                sourceApp: "com.clipmind.autoSave",
                sourceAppName: "ClipMind"
            )
            do {
                try store.save(item)
                LogCategory.capture.logger.info(
                    "FilePath saved to history: fileName=\(fileURL.lastPathComponent, privacy: .public)"
                )
                NotificationCenter.default.post(
                    name: ClipCaptureService.clipDidUpdateNotification, object: nil
                )
            } catch {
                LogCategory.storage.logger.error(
                    "FilePath history save failed: errorCode=\(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    /// 初始化清理服务并启动
    private func setupCleanupService(store: EncryptedStore) {
        let settings = AppSettings()
        cleanupService = CleanupService(store: store, settings: settings)
        cleanupService?.cleanupOnLaunch()
        cleanupService?.startPeriodicCleanup()
    }

    /// 初始化全局快捷键服务
    ///
    /// 从 UserDefaults 读取持久化 hotkey（保留用户自定义值），并执行 F1.10 旧默认值迁移。
    /// 迁移在 `migrateLegacyHotkey` 内部写回 UserDefaults，确保下次启动幂等。
    private func setupHotkeyService() {
        var settings = AppSettings(userDefaults: .standard)
        settings.migrateLegacyHotkey()
        hotkeyService = GlobalHotkeyService(hotkey: settings.hotkey)
    }

    @MainActor
    private func showPopoverContentInWindow() {
        NSApp.setActivationPolicy(.regular)
        // F1.11 Phase 2：委托给 PopoverPreviewWindowFactory 创建 NSPanel 承载视图。
        // 启动参数决定 clips 数据源：
        // - --UITEST_PREPOPULATE_IMAGE_AND_FILEPATH：预置图片/文件路径到 EncryptedStore 后加载
        // - --UITEST_PREVIEW_DATA_SMALL：使用 ClipTestData.previewClips 前 3 条（边界用例专用，避免 LazyVStack 滚动卡顿）
        // - --UITEST_PREVIEW_DATA：使用 ClipTestData.previewClips（11 条文本）
        // - 其他：空列表
        let clips: [ClipItem]
        if CommandLine.arguments.contains("--UITEST_PREPOPULATE_IMAGE_AND_FILEPATH")
        {
            prepopulateImageAndFilePathForTesting()
            clips = loadClipsForQuickPaste()
        } else if CommandLine.arguments.contains("--UITEST_PREVIEW_DATA_SMALL")
        {
            clips = Array(ClipTestData.previewClips.prefix(3))
        } else if ClipTestData.isUITesting
        {
            clips = ClipTestData.previewClips
        } else
        {
            clips = []
        }
        PopoverPreviewWindowFactory.show(
            clips: clips,
            suppressor: selfWriteSuppressor,
            clipToucher: clipToucher,
            tagStore: tagStore
        )
    }

    @objc private func handleOpenMainWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.canBecomeKey {
            window.makeKeyAndOrderFront(nil)
            break
        }
    }

    /// 处理 F2.1 自动保存错误，显示弹窗（AC-09）
    @objc private func handleAutoSaveError(_ notification: Notification)
    {
        let errorCode = notification.userInfo?["errorCode"] as? String ?? "unknown"
        LogCategory.app.error("AutoSave error: errorCode=\(errorCode)")

        DispatchQueue.main.async
        {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "自动保存失败"
            alert.informativeText = "保存目录异常，文件未能保存。剪贴板内容保持原文。"
            alert.addButton(withTitle: "确定")
            alert.runModal()
        }
    }
}
