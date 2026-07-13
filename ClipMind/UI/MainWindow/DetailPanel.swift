import AppKit
import SwiftUI

/// 详情面板（T2.5 增强）。
///
/// 在原有内容预览 + 来源 + 时间的基础上，增加 4 种 AI 处理按钮和结果展示。
/// 未配置 API Key 时按钮置灰（AC-17），已配置时点击触发对应处理。
struct DetailPanel: View {
    let clip: ClipItem?
    var onUpdateClip: ((ClipItem) -> Void)?

    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showRewriteModePicker = false

    private let apiKeyManager = APIKeyManager()

    init(clip: ClipItem?, onUpdateClip: ((ClipItem) -> Void)? = nil) {
        self.clip = clip
        self.onUpdateClip = onUpdateClip
    }

    var body: some View {
        Group {
            if let clip = clip {
                detailContent(for: clip)
            } else {
                emptyState
            }
        }
        .sheet(isPresented: $showRewriteModePicker) {
            if let clip = clip {
                rewriteModePicker(for: clip)
            }
        }
    }

    // MARK: - 详情内容

    @ViewBuilder
    private func detailContent(for clip: ClipItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(contentPreview(for: clip))
                    .font(.body)
                Divider()
                metaSection(for: clip)
                if textContent(for: clip) != nil {
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

    private func metaSection(for clip: ClipItem) -> some View {
        HStack {
            Label(clip.sourceAppName, systemImage: "app")
            Spacer()
            Label(timeAgo(for: clip), systemImage: "clock")
        }
        .foregroundColor(.secondary)
        .font(.caption)
    }

    @ViewBuilder
    private var errorSection: some View {
        if let errorMessage = errorMessage {
            Text(errorMessage)
                .foregroundColor(.red)
                .font(.caption)
                .accessibilityIdentifier("processingErrorText")
        }
    }

    @ViewBuilder
    private func resultsSection(for clip: ClipItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let summary = clip.summary {
                ResultBlockView(
                    title: "总结",
                    content: summary,
                    blockIdentifier: "summaryResultBlock",
                    copyIdentifier: "copySummaryButton",
                    onCopy: { copyToClipboard(summary) }
                )
            }
            if let translation = clip.translation {
                ResultBlockView(
                    title: "翻译",
                    content: translation,
                    blockIdentifier: "translationResultBlock",
                    copyIdentifier: "copyTranslationButton",
                    onCopy: { copyToClipboard(translation) }
                )
            }
            if let rewrite = clip.rewrite {
                ResultBlockView(
                    title: "改写",
                    content: rewrite,
                    blockIdentifier: "rewriteResultBlock",
                    copyIdentifier: "copyRewriteButton",
                    onCopy: { copyToClipboard(rewrite) }
                )
            }
            if let todos = clip.todos {
                TodoResultBlockView(
                    todos: todos,
                    blockIdentifier: "todoResultBlock",
                    copyIdentifier: "copyTodoButton",
                    onCopy: { copyToClipboard(formatTodos(todos)) }
                )
            }
        }
    }

    // MARK: - 改写模式选择

    private func rewriteModePicker(for clip: ClipItem) -> some View {
        VStack(spacing: 12) {
            Text("选择改写模式")
                .font(.headline)
            rewriteOptionButton("调整语气", identifier: "adjustToneOption") {
                showRewriteModePicker = false
                performRewrite(mode: .adjustTone)
            }
            rewriteOptionButton("精简", identifier: "condenseOption") {
                showRewriteModePicker = false
                performRewrite(mode: .condense)
            }
            rewriteOptionButton("扩写", identifier: "expandOption") {
                showRewriteModePicker = false
                performRewrite(mode: .expand)
            }
            Button("取消") {
                showRewriteModePicker = false
            }
            .accessibilityIdentifier("cancelRewriteButton")
        }
        .padding()
        .frame(minWidth: 200)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("rewriteModePicker")
    }

    private func rewriteOptionButton(
        _ title: String,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(title, action: action)
            .buttonStyle(.bordered)
            .accessibilityIdentifier(identifier)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("选择一条剪贴内容查看详情")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 原有辅助方法

    private func contentPreview(for clip: ClipItem) -> String {
        switch clip.content {
        case .text(let text):
            return text
        case .image:
            return "[图片]"
        case .filePath(let urls):
            return urls.map(\.lastPathComponent).joined(separator: ", ")
        }
    }

    private func timeAgo(for clip: ClipItem) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: clip.timestamp, relativeTo: Date())
    }
}

// MARK: - 处理动作

private extension DetailPanel {
    func performSummarize() {
        guard let clip = clip, let text = textContent(for: clip) else { return }
        // UITEST_MOCK_ERROR: 测试模式下直接设置错误信息，模拟 LLM 失败
        if let mockErr = mockError {
            errorMessage = mockErr
            return
        }
        if let mock = mockSummary {
            // UITEST_MOCK_DELAY: 测试模式下延迟返回结果，使 isProcessing 状态可被 UI 测试捕获
            if let delay = mockDelay, delay > 0 {
                isProcessing = true
                errorMessage = nil
                Task {
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    await MainActor.run {
                        var updated = clip
                        updated.summary = mock
                        onUpdateClip?(updated)
                        isProcessing = false
                    }
                }
            } else {
                var updated = clip
                updated.summary = mock
                onUpdateClip?(updated)
            }
            return
        }
        guard let service = createLLMService() else {
            errorMessage = LLMError.notConfigured.errorDescription
            return
        }
        isProcessing = true
        errorMessage = nil
        Task {
            do {
                let result = try await service.summarize(text: text)
                await MainActor.run {
                    var updated = clip
                    updated.summary = result
                    onUpdateClip?(updated)
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isProcessing = false
                }
            }
        }
    }

    func performTranslate() {
        guard let clip = clip, let text = textContent(for: clip) else { return }
        if let mock = mockTranslation {
            var updated = clip
            updated.translation = mock
            onUpdateClip?(updated)
            return
        }
        guard let service = createLLMService() else {
            errorMessage = LLMError.notConfigured.errorDescription
            return
        }
        let direction = detectTranslateDirection(text: text)
        isProcessing = true
        errorMessage = nil
        Task {
            do {
                let result = try await service.translate(text: text, from: direction.from, to: direction.to)
                await MainActor.run {
                    var updated = clip
                    updated.translation = result
                    onUpdateClip?(updated)
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isProcessing = false
                }
            }
        }
    }

    func performRewrite(mode: RewriteMode) {
        guard let clip = clip, let text = textContent(for: clip) else { return }
        if let mock = mockRewrite {
            var updated = clip
            updated.rewrite = mock
            onUpdateClip?(updated)
            return
        }
        guard let service = createLLMService() else {
            errorMessage = LLMError.notConfigured.errorDescription
            return
        }
        isProcessing = true
        errorMessage = nil
        Task {
            do {
                let result = try await service.rewrite(text: text, mode: mode)
                await MainActor.run {
                    var updated = clip
                    updated.rewrite = result
                    onUpdateClip?(updated)
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isProcessing = false
                }
            }
        }
    }

    func performExtractTodo() {
        guard let clip = clip, let text = textContent(for: clip) else { return }
        if let mock = mockTodos {
            var updated = clip
            updated.todos = mock
            onUpdateClip?(updated)
            return
        }
        guard let service = createLLMService() else {
            errorMessage = LLMError.notConfigured.errorDescription
            return
        }
        isProcessing = true
        errorMessage = nil
        Task {
            do {
                let todos = try await service.extractTodos(text: text)
                await MainActor.run {
                    var updated = clip
                    updated.todos = todos
                    onUpdateClip?(updated)
                    isProcessing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isProcessing = false
                }
            }
        }
    }
}

// MARK: - 辅助方法与 Mock 数据

private extension DetailPanel {
    func createLLMService() -> LLMService? {
        guard let provider = apiKeyManager.currentProvider,
              let key = apiKeyManager.loadKey(for: provider) else {
            return nil
        }
        return MultiProviderLLMService(provider: provider, apiKey: key)
    }

    func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func detectTranslateDirection(text: String) -> (from: String, to: String) {
        let isChinese = text.unicodeScalars.contains { $0.value >= 0x4E00 && $0.value <= 0x9FFF }
        return isChinese ? (from: "zh", to: "en") : (from: "en", to: "zh")
    }

    func formatTodos(_ todos: [TodoItem]) -> String {
        todos.enumerated().map { index, todo in
            var line = "\(index + 1). \(todo.task)"
            if let assignee = todo.assignee {
                line += " (@\(assignee))"
            }
            if let dueDate = todo.dueDate {
                line += " [\(dueDate)]"
            }
            return line
        }.joined(separator: "\n")
    }

    func textContent(for clip: ClipItem) -> String? {
        if case .text(let text) = clip.content {
            return text
        }
        return nil
    }

    var mockSummary: String? {
        ProcessInfo.processInfo.environment["UITEST_MOCK_SUMMARY"]
    }

    var mockTranslation: String? {
        ProcessInfo.processInfo.environment["UITEST_MOCK_TRANSLATION"]
    }

    var mockRewrite: String? {
        ProcessInfo.processInfo.environment["UITEST_MOCK_REWRITE"]
    }

    var mockTodos: [TodoItem]? {
        guard let json = ProcessInfo.processInfo.environment["UITEST_MOCK_TODOS"],
              let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([TodoItem].self, from: data)
    }

    /// UITEST_MOCK_ERROR: 测试模式下直接设置错误信息，模拟 LLM 失败
    var mockError: String? {
        ProcessInfo.processInfo.environment["UITEST_MOCK_ERROR"]
    }

    /// UITEST_MOCK_DELAY: 测试模式下延迟返回 mock 结果（秒），使 isProcessing 状态可被 UI 测试捕获
    var mockDelay: TimeInterval? {
        guard let raw = ProcessInfo.processInfo.environment["UITEST_MOCK_DELAY"],
              let value = TimeInterval(raw) else { return nil }
        return value
    }

    var forceConfigured: Bool {
        ProcessInfo.processInfo.environment["UITEST_FORCE_CONFIGURED"] != nil
    }

    var isConfigured: Bool {
        // UITEST_NO_API_KEY: 测试模式下强制未配置，避免 Keychain 历史数据干扰
        if CommandLine.arguments.contains("--UITEST_NO_API_KEY") {
            return false
        }
        return forceConfigured || apiKeyManager.isConfigured
    }
}
