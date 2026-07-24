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
                    MainWindow()
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
            SettingsView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?
    private var cleanupService: CleanupService?
    private var captureService: ClipCaptureService?
    private var hotkeyService: GlobalHotkeyService?
    private var autoSaveService: AutoSaveService?
    private var selfWriteSuppressor: SelfWriteSuppressor?
    // internal 以便 QuickPasteAssembly.swift 同模块访问
    var quickPastePanelController: QuickPastePanelController?
    var pasteCoordinator: PasteCoordinator?

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
        // 监听 F2.1 自动保存错误通知（D13 目录异常分级处理）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAutoSaveError(_:)),
            name: AutoSaveService.errorNotification,
            object: nil
        )
    }

    /// 应用通用启动参数重置（非 UITEST 专用）
    ///
    /// 在 `applicationWillFinishLaunching` 中调用，早于 SwiftUI 读取 `@AppStorage`，
    /// 确保重置后 SwiftUI 直接渲染正确视图，避免先渲染 MainWindow 再切换的时序问题。
    private func applyOnboardingResetIfNeeded() {
        if CommandLine.arguments.contains("--reset-onboarding") {
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
            LogCategory.app.info("已通过 --reset-onboarding 重置首启引导标志位")
        }
        // --UITEST_SHOW_MAIN_WINDOW 必须在 SwiftUI 读取 @AppStorage 之前设置，
        // 否则 SwiftUI 先渲染 OnboardingView 再切换到 MainWindow，
        // 导致 MainWindow 中的 @ObservedObject 错过 OverlayTestState 的早期状态变化。
        if CommandLine.arguments.contains("--UITEST_SHOW_MAIN_WINDOW") {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        }
        UserDefaults.standard.synchronize()
    }

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
        if CommandLine.arguments.contains("--UITEST_RESET_AUTOSAVE_SETTINGS")
        {
            Self.resetAutoSaveSettings(in: UserDefaults.standard)
            LogCategory.app.logger.info("已通过 --UITEST_RESET_AUTOSAVE_SETTINGS 重置 F2.1 配置")
        }
    }

    /// 根据引导状态配置激活策略和服务
    @MainActor
    private func configureActivationPolicy() {
        let completed = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        LogCategory.app.info(
            "Launch: hasCompletedOnboarding=\(completed), "
            + "args=\(CommandLine.arguments.filter { $0.hasPrefix("--UITEST") })"
        )
        if completed {
            if CommandLine.arguments.contains("--UITEST_SHOW_MAIN_WINDOW") {
                NSApp.setActivationPolicy(.regular)
            } else {
                NSApp.setActivationPolicy(.accessory)
            }
            statusItemController = StatusItemController()
            statusItemController?.setup()
            setupServices()
            setupHotkeyService()
            setupQuickPastePanelController()
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

        let watcher = PasteboardWatcher(eventBuilder: eventBuilder, suppressor: suppressor)
        captureService = ClipCaptureService(watcher: watcher, store: store, classifier: classifier)
        captureService?.autoSaveService = autoSave
        captureService?.start()

        LogCategory.app.logger.info("剪贴板捕获服务已启动（含 F2.1 自动保存）")
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
    private func setupHotkeyService() {
        let settings = AppSettings()
        hotkeyService = GlobalHotkeyService(hotkey: settings.hotkey)
    }

    private func showPopoverContentInWindow() {
        NSApp.setActivationPolicy(.regular)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 480),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "PopoverPreview"
        window.contentViewController = NSHostingController(rootView: PopoverView())
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
