import Combine
import SwiftUI

/// 标签选择菜单的 ViewModel。
///
/// 投影 `TagStore` 快照到当前条目的标签候选、勾选与创建状态。所有规则结果由
/// `TagService` 最终裁决；ViewModel 的禁用态只作及时表达，不复制重名/来源权限。
///
/// 通过订阅 `store.objectWillChange` 并转发，确保 `store.snapshot` 变化时
/// `TagPickerView` 的 body 重新评估（`accessibilityValue` 等派生属性随之刷新）。
/// 否则 `@StateObject` 的 ViewModel 不会因 `store` 变化而通知 SwiftUI。
@MainActor
final class TagPickerViewModel: ObservableObject
{
    /// 当前模式。
    enum Mode: Equatable
    {
        case browse
        case create
    }

    /// 搜索文本。
    @Published var searchText = ""
    /// 创建模式下用户输入的候选名称。
    @Published var proposedName = ""
    /// 创建模式下用户选择的颜色。
    @Published var selectedColor = ClipTagColor.violet
    /// 当前模式。
    @Published var mode = Mode.browse

    /// 标签所属条目 ID。
    let clipID: UUID
    /// 条目 ContentType，决定候选中的自身系统标签。
    let contentType: ContentType

    private let store: TagStore
    private var cancellables = Set<AnyCancellable>()

    init(clipID: UUID, contentType: ContentType, store: TagStore)
    {
        self.clipID = clipID
        self.contentType = contentType
        self.store = store

        // 转发 store 的 objectWillChange：mutation 排空后 snapshot 更新，
        // 需要触发 viewModel → view 刷新，否则 candidateRow 的 accessibilityValue
        // 不会更新，XCUITest waitForValue 会超时。
        store.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    /// 候选标签 = 当前条目自身系统标签 + 全部用户标签。
    /// 系统标签不论是否已移除，均保留在候选中以便用户恢复。
    var candidateTags: [ClipTag]
    {
        var candidates: [ClipTag] = [SystemTagCatalog.tag(for: contentType)]
        candidates.append(contentsOf: store.snapshot.userTags)
        return candidates
    }

    /// 经过搜索过滤后的候选标签。大小写不敏感包含匹配。
    var filteredTags: [ClipTag]
    {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return candidateTags }

        let key = trimmed.folding(
            options: [.caseInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        return candidateTags.filter
        {
            $0.name.folding(
                options: [.caseInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            ).contains(key)
        }
    }

    /// 当前条目已选标签 ID 集合。
    var selectedTagIDs: Set<ClipTagID>
    {
        let state = store.snapshot.tagStatesByClipID[clipID, default: .legacy]
        return Set(state.orderedTagIDs)
    }

    /// 是否达到标签上限（每条目最多 5 个）。
    var isAtLimit: Bool
    {
        selectedTagIDs.count >= TagService.maximumTagsPerClip
    }

    /// 是否可以创建新标签。
    ///
    /// - 搜索文本非空且 trim 后非空；
    /// - 名称在现有标签中无重复（大小写不敏感）；
    /// - 未达到标签上限；
    /// - 没有匹配候选（避免重名候选同时出现创建入口）。
    var canCreate: Bool
    {
        guard mode != .create else { return validateProposedName() }

        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if isAtLimit { return false }
        if !filteredTags.isEmpty { return false }
        return !isDuplicateName(trimmed)
    }

    /// 指定标签是否已勾选。
    func isSelected(_ tag: ClipTag) -> Bool
    {
        selectedTagIDs.contains(tag.id)
    }

    /// 指定标签是否应被禁用。
    ///
    /// 达到上限时，未选项禁用；已选项始终可取消。
    func isDisabled(_ tag: ClipTag) -> Bool
    {
        guard isAtLimit else { return false }
        return !isSelected(tag)
    }

    /// 切换标签勾选状态，入队 `setAttached` mutation。
    func toggle(_ tag: ClipTag)
    {
        let isAttached = isSelected(tag)
        store.perform(.setAttached(!isAttached, tagID: tag.id, clipID: clipID))
    }

    /// 进入创建模式，预填搜索词为候选名称。
    func beginCreate()
    {
        mode = .create
        proposedName = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 取消创建，回到浏览模式并清空名称。
    func cancelCreate()
    {
        mode = .browse
        proposedName = ""
    }

    /// 确认创建：入队 createAndAttach mutation，成功后清空搜索与名称。
    func confirmCreate()
    {
        guard validateProposedName() else { return }
        let name = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        let color = selectedColor
        store.perform(.create(name: name, color: color, clipID: clipID))
        proposedName = ""
        searchText = ""
        mode = .browse
    }

    /// 重试，委托给 `TagStore.retry()`。
    func retry()
    {
        store.retry()
    }

    /// 暴露 store 的安全错误文案供 UI 显示。
    var errorMessage: String?
    {
        store.errorMessage
    }

    // MARK: - Private

    /// 校验创建模式下 `proposedName` 是否有效（trim 非空 + 无重名）。
    private func validateProposedName() -> Bool
    {
        let trimmed = proposedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return !isDuplicateName(trimmed)
    }

    /// 大小写不敏感地检查候选中是否已存在同名标签。
    private func isDuplicateName(_ candidate: String) -> Bool
    {
        let key = candidate.folding(
            options: [.caseInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        return candidateTags.contains
        {
            $0.name.folding(
                options: [.caseInsensitive],
                locale: Locale(identifier: "en_US_POSIX")
            ) == key
        }
    }
}

/// 标签选择菜单视图。
///
/// 提供搜索、多选、创建、系统标签移除/恢复、上限提示和失败重试 UI。
/// 所有标签主动作通过 `TagPickerViewModel` 入队到共享 `TagStore`，
/// 不直接访问持久化或 service。
struct TagPickerView: View
{
    @StateObject private var viewModel: TagPickerViewModel
    @FocusState private var isSearchFocused: Bool

    init(clipID: UUID, contentType: ContentType, store: TagStore)
    {
        _viewModel = StateObject(
            wrappedValue: TagPickerViewModel(
                clipID: clipID,
                contentType: contentType,
                store: store
            )
        )
    }

    var body: some View
    {
        VStack(alignment: .leading, spacing: 12)
        {
            titleView
            searchField
            if viewModel.mode == .create
            {
                createFormView
            } else {
                candidateListView
            }
            if viewModel.isAtLimit
            {
                limitHintView
            }
            if let errorMessage = viewModel.errorMessage
            {
                errorRetryView(errorMessage)
            }
        }
        .padding(16)
        .frame(width: 320)
        .onAppear
        {
            isSearchFocused = true
        }
    }

    // MARK: - Subviews

    private var titleView: some View
    {
        Text("选择标签")
            .font(.headline)
            .accessibilityIdentifier("tagPickerTitle")
    }

    private var searchField: some View
    {
        TextField("搜索标签", text: $viewModel.searchText)
            .textFieldStyle(.roundedBorder)
            .focused($isSearchFocused)
            .accessibilityIdentifier("tagPickerSearch")
    }

    private var candidateListView: some View
    {
        ScrollView
        {
            VStack(alignment: .leading, spacing: 4)
            {
                ForEach(viewModel.filteredTags)
                { tag in
                    candidateRow(tag)
                }
                if viewModel.filteredTags.isEmpty && viewModel.canCreate
                {
                    createEntryButton
                }
            }
        }
        // 固定高度（非 maxHeight）：NSPanel + NSHostingController 上下文中，
        // 外层 VStack 只有 width 约束无 height 约束，maxHeight 会让 ScrollView
        // 坍缩到 0，导致内部 Button 存在于 accessibility 树但无 hit point 不可点击。
        // 固定 240pt 确保候选行可点击，与 title+search+padding 总高适配 360pt 面板。
        .frame(height: 240)
    }

    private func candidateRow(_ tag: ClipTag) -> some View
    {
        let isSelected = viewModel.isSelected(tag)
        let isDisabled = viewModel.isDisabled(tag)

        return Button
        {
            viewModel.toggle(tag)
        } label: {
            HStack(spacing: 8)
            {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? tag.color.swiftUIColor : .secondary)
                Circle()
                    .fill(tag.color.swiftUIColor)
                    .frame(width: 10, height: 10)
                Text(tag.name)
                    .font(.body)
                    .foregroundColor(.primary)
                Spacer()
                Text(tag.source == .system ? "自动分类" : "用户")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityIdentifier("tagOption_\(tag.id.rawValue)")
        .accessibilityValue(isSelected ? "已选择" : "未选择")
    }

    private var createEntryButton: some View
    {
        Button
        {
            viewModel.beginCreate()
        } label: {
            HStack(spacing: 8)
            {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(.accentColor)
                Text("创建标签「\(viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines))」")
                    .font(.body)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tagCreateEntry")
    }

    private var createFormView: some View
    {
        VStack(alignment: .leading, spacing: 8)
        {
            TextField("标签名称", text: $viewModel.proposedName)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("tagCreateNameField")

            Text("选择颜色")
                .font(.caption)
                .foregroundColor(.secondary)

            colorPickerView

            HStack
            {
                Button("取消", action: viewModel.cancelCreate)
                    .accessibilityIdentifier("tagCreateCancel")
                Spacer()
                Button("创建", action: viewModel.confirmCreate)
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("tagCreateConfirm")
                    .disabled(!viewModel.canCreate)
            }
        }
    }

    private var colorPickerView: some View
    {
        HStack(spacing: 6)
        {
            ForEach(ClipTagColor.allCases, id: \.self)
            { color in
                colorButton(color)
            }
        }
    }

    private func colorButton(_ color: ClipTagColor) -> some View
    {
        let isSelected = viewModel.selectedColor == color

        return Button
        {
            viewModel.selectedColor = color
        } label: {
            Circle()
                .fill(color.swiftUIColor)
                .frame(width: 22, height: 22)
                .overlay(
                    Circle().stroke(
                        isSelected ? Color.primary : Color.clear,
                        lineWidth: 2
                    )
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("tagColor_\(color.rawValue)")
        .accessibilityLabel(color.displayName)
        .accessibilityValue(isSelected ? "已选择" : "未选择")
    }

    private var limitHintView: some View
    {
        Text("每条条目最多 5 个标签")
            .font(.caption)
            .foregroundColor(.secondary)
            .accessibilityIdentifier("tagLimitHint")
    }

    private func errorRetryView(_ message: String) -> some View
    {
        VStack(alignment: .leading, spacing: 6)
        {
            Text(message)
                .font(.caption)
                .foregroundColor(.red)
                .accessibilityIdentifier("tagErrorMessage")
            Button("重试", action: viewModel.retry)
                .accessibilityIdentifier("tagRetryButton")
        }
    }
}
