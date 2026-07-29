import SwiftUI

/// 可编辑内容区域：根据 ClipContent 类型选择展示模式
///
/// 文本/文件路径类型：点击进入编辑模式，支持实时自动保存和 Cmd+Z 撤销
/// 图片类型：显示不可编辑提示
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

    private let debounceDelay: UInt64 = 500_000_000 // 500ms

    var body: some View {
        Group {
            switch clip.content {
            case .text(let text):
                textContentArea(originalText: text)
            case .image:
                imageContentArea()
            case .filePath(let urls):
                filePathContentArea(urls: urls)
            }
        }
        .onChange(of: clip.id) { _ in
            saveBeforeSwitching()
            isEditing = false
            editableText = ""
            isEditorFocused = false
            saveError = nil
        }
        .onAppear {
            editableText = initialText
        }
    }

    // MARK: - Text Content

    @ViewBuilder
    private func textContentArea(originalText: String) -> some View {
        if isEditing {
            TextEditor(text: $editableText)
                .font(.body)
                .focused($isEditorFocused)
                .accessibilityIdentifier("detailContentEditor")
                .onChange(of: editableText) { _ in
                    scheduleAutoSave()
                }
        } else {
            Text(originalText)
                .font(.body)
                .onTapGesture {
                    isEditing = true
                    editableText = originalText
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        isEditorFocused = true
                    }
                }
                .accessibilityIdentifier("detailContentText")
        }
    }

    // MARK: - Image Content

    private func imageContentArea() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("[图片]")
                .font(.body)
            Text("图片内容不支持编辑")
                .foregroundColor(.secondary)
                .font(.caption)
                .accessibilityIdentifier("imageEditHintText")
        }
    }

    // MARK: - File Path Content

    @ViewBuilder
    private func filePathContentArea(urls: [URL]) -> some View {
        let pathText = urls.map(\.path).joined(separator: "\n")
        if isEditing {
            TextEditor(text: $editableText)
                .font(.body)
                .focused($isEditorFocused)
                .accessibilityIdentifier("detailContentEditor")
                .onChange(of: editableText) { _ in
                    scheduleAutoSave()
                }
        } else {
            Text(pathText)
                .font(.body)
                .onTapGesture {
                    isEditing = true
                    editableText = pathText
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        isEditorFocused = true
                    }
                }
                .accessibilityIdentifier("detailContentText")
        }
    }

    // MARK: - Auto-save

    private func scheduleAutoSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: debounceDelay)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                performSave()
            }
        }
    }

    private func saveBeforeSwitching() {
        saveTask?.cancel()
        guard isEditing else { return }
        let original = initialText
        guard editableText != original else { return }
        performSave()
    }

    private func performSave() {
        guard let updated = EditableContentArea.rebuild(clip: clip, with: editableText) else
        {
            return
        }
        onUpdateClip?(updated)
        onContentSaved?(updated)
        saveError = nil
    }

    /// 重建 ClipItem，保留当前 tagState，避免 .legacy 短暂状态。
    ///
    /// 图片类型返回 nil（不支持编辑）。
    static func rebuild(clip: ClipItem, with text: String) -> ClipItem?
    {
        switch clip.content
        {
        case .text:
            return ClipItem(
                id: clip.id,
                content: .text(text),
                contentType: clip.contentType,
                sourceApp: clip.sourceApp,
                sourceAppName: clip.sourceAppName,
                timestamp: clip.timestamp,
                summary: clip.summary,
                translation: clip.translation,
                rewrite: clip.rewrite,
                todos: clip.todos,
                embeddings: clip.embeddings,
                isSample: clip.isSample,
                tagState: clip.tagState
            )
        case .filePath:
            let paths = text.components(separatedBy: "\n")
            return ClipItem(
                id: clip.id,
                content: .filePath(paths.map { URL(fileURLWithPath: $0) }),
                contentType: clip.contentType,
                sourceApp: clip.sourceApp,
                sourceAppName: clip.sourceAppName,
                timestamp: clip.timestamp,
                summary: clip.summary,
                translation: clip.translation,
                rewrite: clip.rewrite,
                todos: clip.todos,
                embeddings: clip.embeddings,
                isSample: clip.isSample,
                tagState: clip.tagState
            )
        case .image:
            return nil
        }
    }

    // MARK: - Helpers

    private var initialText: String {
        switch clip.content {
        case .text(let text):
            return text
        case .filePath(let urls):
            return urls.map(\.path).joined(separator: "\n")
        case .image:
            return ""
        }
    }
}
