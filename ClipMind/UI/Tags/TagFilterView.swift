import SwiftUI

/// 标签筛选多选状态。
///
/// 不使用 UserDefaults；筛选状态由 `MainWindow` 持有，随窗口生命周期释放。
struct TagFilterSelection: Equatable
{
    /// 当前选中的标签 ID 集合。
    var selectedTagIDs: Set<ClipTagID> = []

    /// 切换某个标签的选中状态。
    mutating func toggle(_ tagID: ClipTagID)
    {
        if selectedTagIDs.contains(tagID)
        {
            selectedTagIDs.remove(tagID)
        } else {
            selectedTagIDs.insert(tagID)
        }
    }

    /// 清除全部选中标签。
    mutating func clear()
    {
        selectedTagIDs.removeAll()
    }

    /// 是否选中了指定标签。
    func isSelected(_ tagID: ClipTagID) -> Bool
    {
        selectedTagIDs.contains(tagID)
    }
}

/// 标签筛选多选 UI。
///
/// 提供 popover 多选全部系统/用户标签，活动标签以 chip 形式显示并可单独移除。
/// 系统标签在候选中标注「自动分类」，但不因全局只读而禁用筛选。
struct TagFilterView: View
{
    @Binding var selection: TagFilterSelection
    let snapshot: TagSnapshot

    @State private var isPopoverPresented = false

    var body: some View
    {
        HStack(spacing: 6)
        {
            triggerButton
            activeChips
        }
    }

    // MARK: - 触发按钮

    private var triggerButton: some View
    {
        Button(
            action: { isPopoverPresented.toggle() },
            label: {
                HStack(spacing: 4)
                {
                    Image(systemName: "tag")
                    Text(labelText)
                }
            }
        )
        .buttonStyle(.plain)
        .accessibilityIdentifier("tagFilterPicker")
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom)
        {
            popoverContent
        }
    }

    private var labelText: String
    {
        selection.selectedTagIDs.isEmpty
            ? "标签：全部"
            : "标签：\(selection.selectedTagIDs.count) 个"
    }

    // MARK: - 活动 chip

    private var activeChips: some View
    {
        HStack(spacing: 4)
        {
            ForEach(Array(selection.selectedTagIDs), id: \.self)
            { tagID in
                if let tag = tagByID(tagID)
                {
                    activeChip(for: tag)
                }
            }
        }
    }

    private func activeChip(for tag: ClipTag) -> some View
    {
        HStack(spacing: 2)
        {
            Text(tag.name)
                .font(.caption)
            Button(
                action: { selection.toggle(tag.id) },
                label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            )
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(tag.color.swiftUIColor.opacity(0.2))
        .cornerRadius(8)
        .accessibilityIdentifier("activeTagFilter_\(tag.id.rawValue)")
    }

    // MARK: - Popover 内容

    private var popoverContent: some View
    {
        VStack(alignment: .leading, spacing: 0)
        {
            if !selection.selectedTagIDs.isEmpty
            {
                Button("清除标签筛选", action: { selection.clear() })
                .accessibilityIdentifier("tagFilterClearButton")
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                Divider()
            }
            ScrollView
            {
                LazyVStack(alignment: .leading, spacing: 0)
                {
                    ForEach(snapshot.allTags)
                    { tag in
                        tagOptionRow(tag)
                    }
                }
            }
            .frame(maxHeight: 300)
        }
        .padding(.vertical, 4)
        .frame(width: 240)
    }

    private func tagOptionRow(_ tag: ClipTag) -> some View
    {
        Button(
            action: { selection.toggle(tag.id) },
            label: {
                HStack(spacing: 8)
                {
                    Image(systemName: selection.isSelected(tag.id) ? "checkmark.square" : "square")
                        .foregroundColor(tag.color.swiftUIColor)
                    Circle()
                        .fill(tag.color.swiftUIColor)
                        .frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 1)
                    {
                        Text(tag.name)
                            .font(.body)
                        Text(tag.source == .system ? "自动分类" : "用户标签")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
        )
        .buttonStyle(.plain)
        .accessibilityIdentifier("tagFilterOption_\(tag.id.rawValue)")
        .accessibilityValue(selection.isSelected(tag.id) ? "已选择" : "未选择")
    }

    // MARK: - 辅助

    private func tagByID(_ id: ClipTagID) -> ClipTag?
    {
        snapshot.allTags.first { $0.id == id }
    }
}
