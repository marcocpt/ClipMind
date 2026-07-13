import SwiftUI

/// 设置面板主视图。
///
/// 使用 TabView 分为 3 个分区：API Key / 隐私 / 通用。
/// Phase 2 仅实现 API Key 分区，隐私和通用在 Phase 3 实现。
/// 对应设计规范 3.8 节设置配置流程和 UI-AC-15 设置面板入口。
struct SettingsView: View {
    var body: some View {
        TabView {
            APIKeyConfigView()
                .tabItem {
                    Label("API Key", systemImage: "key.fill")
                        .accessibilityIdentifier("apiKeyTab")
                }

            // Phase 3 预留
            Text("隐私设置将在 Phase 3 实现")
                .tabItem {
                    Label("隐私", systemImage: "lock.shield.fill")
                        .accessibilityIdentifier("privacyTab")
                }

            // Phase 3 预留
            Text("通用设置将在 Phase 3 实现")
                .tabItem {
                    Label("通用", systemImage: "gear")
                        .accessibilityIdentifier("generalTab")
                }
        }
        .frame(width: 500, height: 350)
    }
}
