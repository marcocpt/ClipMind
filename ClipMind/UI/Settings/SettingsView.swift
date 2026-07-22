import SwiftUI

/// 设置面板主视图。
///
/// 使用 TabView 分为 4 个分区：API Key / 隐私 / 通用 / 自动保存（F2.1）。
/// 对应设计规范 3.8 节设置配置流程和 UI-AC-15 设置面板入口。
struct SettingsView: View
{
    /// 启动时立即解析 `--UITEST_INITIAL_TAB=<tab>` 启动参数。
    @State private var selectedTab: SettingsTab = {
        guard let arg = CommandLine.arguments.first(where: { $0.hasPrefix("--UITEST_INITIAL_TAB=") }) else
        {
            return .apiKey
        }
        return SettingsView.tabFromArgument(arg)
    }()

    var body: some View
    {
        TabView(selection: $selectedTab)
        {
            APIKeyConfigView()
                .tabItem
                {
                    Label("API Key", systemImage: "key.fill")
                        .accessibilityIdentifier("apiKeyTab")
                }
                .tag(SettingsTab.apiKey)

            PrivacySettingsView()
                .tabItem
                {
                    Label("隐私", systemImage: "lock.shield.fill")
                        .accessibilityIdentifier("privacyTab")
                }
                .tag(SettingsTab.privacy)

            GeneralSettingsView()
                .tabItem
                {
                    Label("通用", systemImage: "gear")
                        .accessibilityIdentifier("generalTab")
                }
                .tag(SettingsTab.general)

            AutoSaveSettingsView()
                .tabItem
                {
                    Label("自动保存", systemImage: "doc.on.clipboard.fill")
                        .accessibilityIdentifier("autoSaveTab")
                }
                .tag(SettingsTab.autoSave)
        }
        // 高度按内容调整：F2.1 AutoSaveSettingsView 有 7 个 section（含 TextField 改造后
        // 新增 hint caption2），总高度超过原 550pt，导致顶部内容被裁剪。
        // 调整为 700pt 容纳所有 tab 内容；TabView 默认顶部对齐，其他 tab 不会居中。
        .frame(width: 520, height: 700)
    }

    /// 解析 `--UITEST_INITIAL_TAB=<tab>` 启动参数为 SettingsTab。
    ///
    /// 提取为静态方法供 `@State` 初始化与单元测试共用，保证解析逻辑单一来源。
    /// 未知值回退到 `.apiKey`（F1.x 既有行为，不破坏兼容）。
    static func tabFromArgument(_ arg: String) -> SettingsTab
    {
        let raw = String(arg.dropFirst("--UITEST_INITIAL_TAB=".count))
        switch raw.lowercased()
        {
        case "privacy":
            return .privacy
        case "general":
            return .general
        case "autosave":
            return .autoSave
        default:
            return .apiKey
        }
    }
}

/// 设置面板标签枚举（internal 供 @testable 测试访问，D22 新增 case 不算修改 F1.x 既有接口）
enum SettingsTab: Hashable
{
    case apiKey
    case privacy
    case general
    case autoSave
}
