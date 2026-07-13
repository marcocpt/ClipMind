import SwiftUI

/// 设置面板主视图。
///
/// 使用 TabView 分为 3 个分区：API Key / 隐私 / 通用。
/// 对应设计规范 3.8 节设置配置流程和 UI-AC-15 设置面板入口。
struct SettingsView: View {
    @State private var selectedTab = SettingsTab.apiKey

    var body: some View {
        TabView(selection: $selectedTab) {
            APIKeyConfigView()
                .tabItem {
                    Label("API Key", systemImage: "key.fill")
                        .accessibilityIdentifier("apiKeyTab")
                }
                .tag(SettingsTab.apiKey)

            PrivacySettingsView()
                .tabItem {
                    Label("隐私", systemImage: "lock.shield.fill")
                        .accessibilityIdentifier("privacyTab")
                }
                .tag(SettingsTab.privacy)

            // Phase 3 预留
            Text("通用设置将在 Phase 3 实现")
                .tabItem {
                    Label("通用", systemImage: "gear")
                        .accessibilityIdentifier("generalTab")
                }
                .tag(SettingsTab.general)
        }
        .frame(width: 520, height: 550)
        .onAppear {
            applyInitialTabFromLaunchArgument()
        }
    }

    /// 解析 `--UITEST_INITIAL_TAB=<tab>` 启动参数，用于 UI 测试直接定位到指定标签。
    private func applyInitialTabFromLaunchArgument() {
        guard let arg = CommandLine.arguments.first(where: { $0.hasPrefix("--UITEST_INITIAL_TAB=") }) else {
            return
        }
        let raw = String(arg.dropFirst("--UITEST_INITIAL_TAB=".count))
        switch raw.lowercased() {
        case "privacy":
            selectedTab = .privacy
        case "general":
            selectedTab = .general
        default:
            selectedTab = .apiKey
        }
    }
}

/// 设置面板标签枚举
private enum SettingsTab: Hashable {
    case apiKey
    case privacy
    case general
}
