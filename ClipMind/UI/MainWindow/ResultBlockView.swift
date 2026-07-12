import SwiftUI

/// AI 处理结果展示区块（T2.5）。
///
/// 显示处理类型标题 + 结果内容 + 复制按钮。
/// 支持总结/翻译/改写 3 种文本结果类型。
struct ResultBlockView: View {
    /// 区块标题（"总结" / "翻译" / "改写"）
    let title: String
    /// 结果文本
    let content: String
    /// 区块 accessibility identifier（如 "summaryResultBlock"）
    let blockIdentifier: String
    /// 复制按钮 accessibility identifier（如 "copySummaryButton"）
    let copyIdentifier: String
    /// 点击复制回调
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .accessibilityHidden(true)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier(copyIdentifier)
                .accessibilityLabel("复制")
            }
            Text(content)
                .font(.body)
                .textSelection(.enabled)
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(blockIdentifier)
    }
}

/// 待办结果展示区块（T2.5）。
///
/// 列表展示每个 TodoItem：任务 + 负责人 + 截止时间。
struct TodoResultBlockView: View {
    /// 待办列表
    let todos: [TodoItem]
    /// 区块 accessibility identifier（"todoResultBlock"）
    let blockIdentifier: String
    /// 复制按钮 accessibility identifier（"copyTodoButton"）
    let copyIdentifier: String
    /// 点击复制回调
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("待办")
                    .font(.headline)
                Spacer()
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .accessibilityHidden(true)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier(copyIdentifier)
                .accessibilityLabel("复制")
            }
            ForEach(todos) { todo in
                todoRow(todo)
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(blockIdentifier)
    }

    /// 单个待办行
    private func todoRow(_ todo: TodoItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(todo.task)
                .font(.body)
            HStack(spacing: 12) {
                if let assignee = todo.assignee {
                    Label(assignee, systemImage: "person")
                }
                if let dueDate = todo.dueDate {
                    Label(dueDate, systemImage: "calendar")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
