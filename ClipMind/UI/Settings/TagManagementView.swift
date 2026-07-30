import SwiftUI

// MARK: - TagManagementViewModel

/// 设置页标签管理状态机。
///
/// 维护两阶段重命名（编辑 → 独立确认）和删除二次确认的状态流转。
/// `submitRename()` 通过 `TagNameValidator` 在确认前拒绝空白与大小写重名，
/// 不自行 trim、fold 或遍历比较名称。`confirmRename/confirmDelete` 把
/// 结构化 operation 交给 `TagStore.perform(_:)` 串行排空，失败由 store
/// 保留最近成功快照并把错误回写到 `errorMessage`，ViewModel 回到 `.idle`。
@MainActor
final class TagManagementViewModel: ObservableObject
{
    /// 标签管理状态。
    enum State: Equatable
    {
        case idle
        case editing(tagID: ClipTagID)
        case confirmRename(tagID: ClipTagID, oldName: String, newName: String)
        case confirmDelete(tagID: ClipTagID, name: String)
    }

    /// 当前状态。
    @Published private(set) var state: State = .idle

    /// 编辑行 TextField 草稿，仅在 `.editing` 期间被 View 写入。
    @Published var draftName: String = ""

    /// 校验错误的安全文案（不包含标签名），供编辑行 inline 提示使用。
    @Published private(set) var validationMessage: String?

    /// 触发 confirm 的按钮 tag ID，供 View 焦点恢复使用。
    @Published private(set) var lastTriggeredTagID: ClipTagID?

    private let store: TagStore

    /// 构造 ViewModel。
    /// - Parameter store: 共享 `TagStore`，所有 mutation 通过它路由到 service。
    init(store: TagStore)
    {
        self.store = store
    }

    /// 进入重命名编辑态。系统标签直接忽略，保持在 `.idle`。
    /// - Parameter tag: 用户点击的标签。
    func beginRename(_ tag: ClipTag)
    {
        guard tag.source == .user else
        {
            logSystemTagGuarded(operation: "rename")
            return
        }
        state = .editing(tagID: tag.id)
        draftName = tag.name
        validationMessage = nil
        lastTriggeredTagID = tag.id
    }

    /// 提交编辑草稿。校验失败停留在 `.editing` 并设置 `validationMessage`；
    /// 校验通过进入 `.confirmRename`，尚未调用 service。
    func submitRename()
    {
        guard case let .editing(tagID) = state else { return }

        let existingTags = store.snapshot.allTags
        do
        {
            let validated = try TagNameValidator.validate(
                candidate: draftName,
                existingTags: existingTags,
                excluding: tagID
            )
            let oldName = store.snapshot.userTags
                .first { $0.id == tagID }?
                .name ?? ""
            validationMessage = nil
            state = .confirmRename(tagID: tagID, oldName: oldName, newName: validated)
        } catch let tagError as TagError {
            validationMessage = tagError.errorDescription
            LogCategory.ui.info("tag rename validation rejected errorCode=\(tagError.rawValue)")
        } catch {
            validationMessage = TagError.persistenceFailed.errorDescription
            LogCategory.ui.error("tag rename validation unexpected error errorCode=unknown")
        }
    }

    /// 取消重命名。从 `.editing` 或 `.confirmRename` 都回到 `.idle`，
    /// 不调用 service。
    func cancelRename()
    {
        switch state
        {
        case .editing, .confirmRename:
            state = .idle
            draftName = ""
            validationMessage = nil
        case .idle, .confirmDelete:
            return
        }
    }

    /// 确认重命名。把 `.rename` 操作排入 `TagStore` 并回到 `.idle`。
    /// 失败由 store 保留最近快照并设置 `errorMessage`，本方法不等待结果。
    func confirmRename()
    {
        guard case let .confirmRename(tagID, _, newName) = state else { return }
        store.perform(.rename(tagID: tagID, name: newName))
        state = .idle
        draftName = ""
        validationMessage = nil
    }

    /// 进入删除确认态。系统标签直接忽略。
    func beginDelete(_ tag: ClipTag)
    {
        guard tag.source == .user else
        {
            logSystemTagGuarded(operation: "delete")
            return
        }
        state = .confirmDelete(tagID: tag.id, name: tag.name)
        lastTriggeredTagID = tag.id
    }

    /// 取消删除，回到 `.idle`，不调用 service。
    func cancelDelete()
    {
        switch state
        {
        case .confirmDelete:
            state = .idle
        case .idle, .editing, .confirmRename:
            return
        }
    }

    /// 确认删除。把 `.delete` 操作排入 `TagStore` 并回到 `.idle`。
    func confirmDelete()
    {
        guard case let .confirmDelete(tagID, _) = state else { return }
        store.perform(.delete(tagID: tagID))
        state = .idle
    }

    // MARK: - Private Helpers

    /// 记录系统标签 guard 命中日志，仅写闭集 scope 与 operation，不写标签名。
    private func logSystemTagGuarded(operation: String)
    {
        LogCategory.ui.info("tag management guarded systemTag operation=\(operation)")
    }
}

// MARK: - TagManagementView

/// 设置页「标签」分区视图。
///
/// 列出系统标签只读目录和用户标签可管理目录。系统标签 section 不创建
/// 重命名/删除按钮；用户标签行提供两阶段重命名和删除二次确认。
/// 失败显示 `TagStore.errorMessage` 与 `settingsTagRetryButton`。
struct TagManagementView: View
{
    @ObservedObject var viewModel: TagManagementViewModel
    @ObservedObject var store: TagStore

    /// 焦点恢复状态：取消或完成后把焦点送回触发的 rename/delete button。
    @AccessibilityFocusState private var focusedTagID: ClipTagID?

    init(store: TagStore)
    {
        self.store = store
        let viewModel = TagManagementViewModel(store: store)
        self.viewModel = viewModel
    }

    var body: some View
    {
        Form
        {
            Section("自动分类标签")
            {
                ForEach(SystemTagCatalog.all)
                { tag in
                    systemTagRow(tag)
                        .accessibilityIdentifier("systemTagRow_\(tag.id.rawValue)")
                }
            }

            Section("用户自定义标签")
            {
                if store.snapshot.userTags.isEmpty
                {
                    Text("暂无用户自定义标签")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .accessibilityIdentifier("userTagsEmptyHint")
                }
                ForEach(store.snapshot.userTags)
                { tag in
                    userTagRow(tag)
                        .accessibilityIdentifier("userTagRow_\(tag.id.rawValue)")
                }
            }

            if let errorMessage = store.errorMessage
            {
                Section
                {
                    VStack(alignment: .leading, spacing: 8)
                    {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                            .accessibilityIdentifier("settingsTagErrorMessage")
                        Button("重试")
                        {
                            store.retry()
                        }
                        .accessibilityIdentifier("settingsTagRetryButton")
                    }
                }
            }
        }
        .alert(
            renameConfirmTitle,
            isPresented: renameConfirmBinding,
            presenting: renameConfirmPayload
        )
        { _ in
            Button("取消", role: .cancel)
            {
                viewModel.cancelRename()
                focusedTagID = viewModel.lastTriggeredTagID
            }
            Button("重命名", role: .destructive)
            {
                viewModel.confirmRename()
                focusedTagID = viewModel.lastTriggeredTagID
            }
        }
        .alert(
            deleteConfirmTitle,
            isPresented: deleteConfirmBinding,
            presenting: deleteConfirmPayload
        )
        { _ in
            Button("取消", role: .cancel)
            {
                viewModel.cancelDelete()
                focusedTagID = viewModel.lastTriggeredTagID
            }
            Button("删除", role: .destructive)
            {
                viewModel.confirmDelete()
                focusedTagID = viewModel.lastTriggeredTagID
            }
        }
    }

    // MARK: - Rows

    /// 系统标签行：仅展示 pill、来源说明和「颜色不可修改」caption，
    /// 不创建任何按钮。
    @ViewBuilder
    private func systemTagRow(_ tag: ClipTag) -> some View
    {
        HStack(spacing: 12)
        {
            TagPillView(tag: tag, isInteractive: false)
            VStack(alignment: .leading, spacing: 2)
            {
                Text("自动分类 · 可按条目移除")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("颜色不可修改")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    /// 用户标签行：展示 pill、来源说明，并根据 ViewModel 状态切换
    /// 编辑行/重命名按钮/删除按钮。
    @ViewBuilder
    private func userTagRow(_ tag: ClipTag) -> some View
    {
        if case let .editing(tagID) = viewModel.state, tagID == tag.id
        {
            editingRow(tag)
        } else {
            displayRow(tag)
        }
    }

    /// 编辑行：TextField + 取消 + 提交。`submitRename` 后行视图回到 display，
    /// 由上层 alert 接管两阶段确认。
    @ViewBuilder
    private func editingRow(_ tag: ClipTag) -> some View
    {
        HStack(spacing: 8)
        {
            TagPillView(tag: tag, isInteractive: false)
            TextField("标签名称", text: $viewModel.draftName)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("renameTagField_\(tag.id.rawValue)")
                .onSubmit { viewModel.submitRename() }
            Button("取消")
            {
                viewModel.cancelRename()
                focusedTagID = tag.id
            }
            .accessibilityIdentifier("cancelRenameTag_\(tag.id.rawValue)")
            Button("提交")
            {
                viewModel.submitRename()
            }
            .accessibilityIdentifier("submitRenameTag_\(tag.id.rawValue)")
        }
        if let message = viewModel.validationMessage
        {
            Text(message)
                .font(.caption2)
                .foregroundStyle(.red)
                .accessibilityIdentifier("renameValidationError_\(tag.id.rawValue)")
        }
    }

    /// 展示行：pill + 来源 + 重命名/删除按钮。
    @ViewBuilder
    private func displayRow(_ tag: ClipTag) -> some View
    {
        HStack(spacing: 12)
        {
            TagPillView(tag: tag, isInteractive: false)
            VStack(alignment: .leading, spacing: 2)
            {
                Text("用户标签")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("颜色不可修改")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button
            {
                viewModel.beginRename(tag)
            }
            label: {
                Label("重命名", systemImage: "pencil")
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("renameTag_\(tag.id.rawValue)")
            .accessibilityFocused($focusedTagID, equals: tag.id)

            Button
            {
                viewModel.beginDelete(tag)
            }
            label: {
                Label("删除", systemImage: "trash")
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("deleteTag_\(tag.id.rawValue)")
            .accessibilityFocused($focusedTagID, equals: tag.id)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Alert Bindings

    /// 重命名确认 alert 标题：固定文案，不含标签名透出额外信息。
    private var renameConfirmTitle: String
    {
        guard case let .confirmRename(_, oldName, newName) = viewModel.state
        else { return "" }
        return "将标签“\(oldName)”重命名为“\(newName)”？此操作将影响所有关联条目。"
    }

    private var renameConfirmBinding: Binding<Bool>
    {
        Binding(
            get: { isConfirmRenameState },
            set: { newValue in
                if !newValue { viewModel.cancelRename() }
            }
        )
    }

    private var renameConfirmPayload: TagManagementViewModel.State?
    {
        isConfirmRenameState ? viewModel.state : nil
    }

    private var isConfirmRenameState: Bool
    {
        if case .confirmRename = viewModel.state { return true }
        return false
    }

    /// 删除确认 alert 标题：固定文案。
    private var deleteConfirmTitle: String
    {
        guard case let .confirmDelete(_, name) = viewModel.state
        else { return "" }
        return "删除标签“\(name)”？该标签将从所有条目中移除，此操作不可撤销。"
    }

    private var deleteConfirmBinding: Binding<Bool>
    {
        Binding(
            get: { isConfirmDeleteState },
            set: { newValue in
                if !newValue { viewModel.cancelDelete() }
            }
        )
    }

    private var deleteConfirmPayload: TagManagementViewModel.State?
    {
        isConfirmDeleteState ? viewModel.state : nil
    }

    private var isConfirmDeleteState: Bool
    {
        if case .confirmDelete = viewModel.state { return true }
        return false
    }
}
