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
        var updated = clip
        switch clip.content {
        case .text:
            updated = ClipItem(
                id: updated.id,
                content: .text(editableText),
                contentType: updated.contentType,
                sourceApp: updated.sourceApp,
                sourceAppName: updated.sourceAppName,
                timestamp: updated.timestamp,
                summary: updated.summary,
                translation: updated.translation,
                rewrite: updated.rewrite,
                todos: updated.todos,
                embeddings: updated.embeddings
            )
        case .filePath:
            let paths = editableText.components(separatedBy: "\n")
            updated = ClipItem(
                id: updated.id,
                content: .filePath(paths.map { URL(fileURLWithPath: $0) }),
                contentType: updated.contentType,
                sourceApp: updated.sourceApp,
                sourceAppName: updated.sourceAppName,
                timestamp: updated.timestamp,
                summary: updated.summary,
                translation: updated.translation,
                rewrite: updated.rewrite,
                todos: updated.todos,
                embeddings: updated.embeddings
            )
        case .image:
            return
        }
        onUpdateClip?(updated)
        onContentSaved?(updated)
        saveError = nil
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
