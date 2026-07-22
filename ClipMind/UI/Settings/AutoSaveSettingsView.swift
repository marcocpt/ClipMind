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

    /// 长度阈值 TextField 本地字符串（决策 C1：Stepper → TextField）
    @State private var lengthThresholdText = ""

    /// 文件名长度 TextField 本地字符串（决策 C1：Stepper → TextField）
    @State private var fileNameLengthText = ""

    /// 长度阈值输入框焦点状态（决策 C4：失焦自动应用）
    @FocusState private var lengthThresholdFocused: Bool

    /// 文件名长度输入框焦点状态（决策 C4：失焦自动应用）
    @FocusState private var fileNameLengthFocused: Bool

    init(store: AutoSaveSettingsStore = AutoSaveSettingsStore())
    {
        self.store = store
        let loaded = store.load()
        self._settings = State(initialValue: loaded)
        self._lengthThresholdText = State(initialValue: "\(loaded.lengthThreshold)")
        self._fileNameLengthText = State(initialValue: "\(loaded.fileNameLength)")
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
            filePathHistorySection
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
                Text("Markdown").tag(FileFormat.markdown)
                Text("纯文本").tag(FileFormat.plainText)
            }
            .accessibilityIdentifier("fileFormatPicker")
            .onChange(of: settings.fileFormat) { _ in saveSettings() }

            // 决策 C1：Stepper → TextField；决策 C4：回车+失焦双保险
            VStack(alignment: .leading, spacing: 2)
            {
                Text("长度阈值（字）")
                    .font(.caption)
                TextField("1-10000", text: $lengthThresholdText)
                    .accessibilityIdentifier("lengthThresholdField")
                    .focused($lengthThresholdFocused)
                    .onSubmit { applyLengthThreshold() }
                    .onChange(of: lengthThresholdFocused) { focused in
                        if !focused { applyLengthThreshold() }
                    }
                Text(lengthThresholdHint)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 2)
            {
                Text("文件名长度（字）")
                    .font(.caption)
                TextField("1-50", text: $fileNameLengthText)
                    .accessibilityIdentifier("fileNameLengthField")
                    .focused($fileNameLengthFocused)
                    .onSubmit { applyFileNameLength() }
                    .onChange(of: fileNameLengthFocused) { focused in
                        if !focused { applyFileNameLength() }
                    }
                Text(fileNameLengthHint)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - 路径格式

    private var pathFormatSection: some View
    {
        Section("路径格式")
        {
            Picker("路径格式", selection: $settings.pathFormat)
            {
                Text("纯路径").tag(PathFormat.plainPath)
                Text("file:// URI").tag(PathFormat.fileURI)
                Text("Markdown 链接").tag(PathFormat.markdownLink)
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
                    } else {
                        saveSettings()
                    }
                }

            Text("开启后，敏感内容不保存到文件；关闭时需二次确认")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - 文件路径进历史

    private var filePathHistorySection: some View
    {
        Section("历史显示")
        {
            Toggle("文件路径进历史", isOn: $settings.showFilePathInHistory)
                .accessibilityIdentifier("showFilePathInHistoryToggle")
                .onChange(of: settings.showFilePathInHistory) { _ in saveSettings() }

            Text("开启后，自动保存的文件路径以可拖拽格式进入历史列表")
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
        LogCategory.ui.logger.debug(
            "AutoSaveSettings updated: isEnabled=\(settings.isEnabled, privacy: .public)"
        )
    }

    // MARK: - TextField 失焦/回车应用（决策 C2 夹紧 + C3 回退 + C4 双保险）

    /// 长度阈值范围提示文本（决策 C6）
    private var lengthThresholdHint: String
    {
        let range = AutoSaveSettings.lengthThresholdRange
        return "范围 \(range.lowerBound)-\(range.upperBound) 字，超出范围自动夹紧到边界"
    }

    /// 文件名长度范围提示文本（决策 C6）
    private var fileNameLengthHint: String
    {
        let range = AutoSaveSettings.fileNameLengthRange
        return "范围 \(range.lowerBound)-\(range.upperBound) 字，超出范围自动夹紧到边界"
    }

    /// 应用长度阈值：解析 → 夹紧 → 写回 settings → 持久化 → 同步本地字符串
    private func applyLengthThreshold()
    {
        let clamped = AutoSaveSettings.clampedInt(
            lengthThresholdText,
            range: AutoSaveSettings.lengthThresholdRange,
            fallback: settings.lengthThreshold
        )
        settings.lengthThreshold = clamped
        lengthThresholdText = "\(clamped)"
        saveSettings()
    }

    /// 应用文件名长度：解析 → 夹紧 → 写回 settings → 持久化 → 同步本地字符串
    private func applyFileNameLength()
    {
        let clamped = AutoSaveSettings.clampedInt(
            fileNameLengthText,
            range: AutoSaveSettings.fileNameLengthRange,
            fallback: settings.fileNameLength
        )
        settings.fileNameLength = clamped
        fileNameLengthText = "\(clamped)"
        saveSettings()
    }
}
