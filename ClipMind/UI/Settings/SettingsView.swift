import SwiftUI

/// 设置面板主视图。
///
/// 使用 TabView 分为 3 个分区：API Key / 隐私 / 通用。
/// 对应设计规范 3.8 节设置配置流程和 UI-AC-15 设置面板入口。
struct SettingsView: View {
    /// 启动时立即解析 `--UITEST_INITIAL_TAB=<tab>` 启动参数。
    ///
    /// 使用 @State 初始化器而非 `.onAppear`，因为 macOS Settings 场景中
    /// onAppear 时机不稳定（设置窗口可能复用已存在的 SettingsView 实例），
    /// 在初始化时解析确保标签切换可靠。
    @State private var selectedTab: SettingsTab = {
        guard let arg = CommandLine.arguments.first(where: { $0.hasPrefix("--UITEST_INITIAL_TAB=") }) else {
            return .apiKey
        }
        let raw = String(arg.dropFirst("--UITEST_INITIAL_TAB=".count))
        switch raw.lowercased() {
        case "privacy":
            return .privacy
        case "general":
            return .general
        default:
            return .apiKey
        }
    }()

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

            GeneralSettingsView()
                .tabItem {
                    Label("通用", systemImage: "gear")
                        .accessibilityIdentifier("generalTab")
                }
                .tag(SettingsTab.general)
        }
        .frame(width: 520, height: 550)
    }
}

/// 设置面板标签枚举
private enum SettingsTab: Hashable {
    case apiKey
    case privacy
    case general
}
