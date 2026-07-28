import SwiftUI

/// 来源 App 多选筛选器。
///
/// 提供下拉菜单多选来源 App，支持「全部」与各应用 Checkbox 联动。
/// 对应 AC-12（来源 App 过滤）的 UI 部分。
struct SourceFilter: View
{
    @Binding var selection: SourceFilterSelection
    let availableApps: [String]

    var body: some View
    {
        Menu(
            content: {
                Button(
                    action: { selection.toggleAll() },
                    label: {
                        HStack
                        {
                            if selection.isAllSelected
                            {
                                Image(systemName: "checkmark")
                            }
                            Text("全部来源")
                        }
                    }
                )

                Divider()

                ForEach(availableApps, id: \.self) { app in
                    Button(
                        action: { selection.toggleSource(app) },
                        label: {
                            HStack
                            {
                                if selection.selectedSources.contains(app)
                                {
                                    Image(systemName: "checkmark")
                                }
                                Text(app)
                            }
                        }
                    )
                }
            },
            label: {
                HStack(spacing: 4)
                {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text(selection.isAllSelected ? "全部来源" : "\(selection.selectedSources.count) 个来源")
                }
            }
        )
        .accessibilityIdentifier("sourceFilterPicker")
    }
}
