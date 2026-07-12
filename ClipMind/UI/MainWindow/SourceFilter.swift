import SwiftUI

/// 来源 App 筛选器。
///
/// 提供下拉菜单选择来源 App，支持"全部"和具体 App 选项。
/// 对应 AC-12（来源 App 过滤）的 UI 部分。
struct SourceFilter: View {
    @Binding var selectedApp: String?
    let availableApps: [String]

    var body: some View {
        Picker("来源", selection: $selectedApp) {
            Text("全部来源").tag(String?.none)
            ForEach(availableApps, id: \.self) { app in
                Text(app).tag(String?.some(app))
            }
        }
        .pickerStyle(.menu)
        .accessibilityIdentifier("sourceFilterPicker")
    }
}
