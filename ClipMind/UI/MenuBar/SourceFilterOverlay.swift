import SwiftUI

/// 来源筛选浮层内容组件（F1.13 Phase 1 任务 2）。
///
/// 渲染「全部来源」Checkbox + Divider + 各应用 Checkbox 列表。
/// 由 UnifiedPastePanelView 通过 .popover 修饰符呈现，本组件只负责内容渲染。
struct SourceFilterOverlay: View
{
    @Binding var selection: SourceFilterSelection
    let availableApps: [String]

    var body: some View
    {
        VStack(alignment: .leading, spacing: 0)
        {
            SourceFilterCheckboxRow(
                label: "全部来源",
                isSelected: selection.isAllSelected,
                onToggle: { selection.toggleAll() }
            )
            .accessibilityLabel("全部来源")
            .accessibilityAddTraits(.isButton)

            if !availableApps.isEmpty
            {
                Divider()
                    .padding(.vertical, 4)

                ForEach(availableApps, id: \.self)
                { appName in
                    SourceFilterCheckboxRow(
                        label: appName,
                        isSelected: selection.selectedSources.contains(appName),
                        onToggle: { selection.toggleSource(appName) }
                    )
                    .accessibilityLabel("来源: \(appName)")
                    .accessibilityAddTraits(.isButton)
                }
            }
        }
        .padding(8)
        .frame(minWidth: 160)
    }
}

// MARK: - Checkbox 行组件

/// 来源筛选单行 Checkbox 组件。
private struct SourceFilterCheckboxRow: View
{
    let label: String
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View
    {
        Button(action: onToggle)
        {
            HStack(spacing: 6)
            {
                Image(systemName: isSelected ? "checkmark.square" : "square")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                Text(label)
                    .foregroundColor(.primary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 2)
    }
}
