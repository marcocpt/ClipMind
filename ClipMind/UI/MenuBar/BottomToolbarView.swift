import SwiftUI

/// 底部工具栏组件（F1.11 Phase 3）。
///
/// 渲染菜单栏弹窗底部的「查看全部 / 配置 / 退出」三按钮，处理按钮点击事件转发。
/// 通过外部回调接收点击行为，由 `UnifiedPastePanelView` 在 `showsBottomBar == true` 时渲染。
///
/// 设计文档第 3.4 节。
struct BottomToolbarView: View
{
    /// 「查看全部」按钮辅助功能标识符（命名约定见 README 第 5.4 节）。
    static let viewAllButtonIdentifier = "popoverViewAllButton"

    /// 「配置」按钮辅助功能标识符。
    static let settingsButtonIdentifier = "popoverSettingsButton"

    /// 「退出」按钮辅助功能标识符。
    static let exitButtonIdentifier = "popoverExitButton"

    /// 「查看全部」按钮回调（由控制器关闭面板 + 发送 openMainWindow 通知）。
    private let onViewAll: () -> Void

    /// 「配置」按钮回调（由控制器关闭面板 + 发送 openSettingsWindow 通知）。
    private let onSettings: () -> Void

    /// 「退出」按钮回调（由控制器关闭面板，不发送通知）。
    private let onExit: () -> Void

    init(
        onViewAll: @escaping () -> Void,
        onSettings: @escaping () -> Void,
        onExit: @escaping () -> Void
    )
    {
        self.onViewAll = onViewAll
        self.onSettings = onSettings
        self.onExit = onExit
    }

    var body: some View
    {
        HStack(spacing: 0)
        {
            Button(action: onViewAll)
            {
                Image(systemName: Self.viewAllIconName)
                    .imageScale(.large)
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier(Self.viewAllButtonIdentifier)
            .accessibilityLabel("查看全部")

            Spacer()

            Button(action: onSettings)
            {
                Image(systemName: Self.settingsIconName)
                    .imageScale(.large)
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier(Self.settingsButtonIdentifier)
            .accessibilityLabel("配置")

            Spacer()

            Button(action: onExit)
            {
                Image(systemName: Self.exitIconName)
                    .imageScale(.large)
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier(Self.exitButtonIdentifier)
            .accessibilityLabel("退出")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: 36)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - 图标常量

    /// 「查看全部」按钮 SF Symbol 名称。
    static let viewAllIconName = "list.bullet"

    /// 「配置」按钮 SF Symbol 名称。
    static let settingsIconName = "gearshape"

    /// 「退出」按钮 SF Symbol 名称。
    static let exitIconName = "power"

    // MARK: - 测试辅助

    /// 仅供单元测试触发「查看全部」回调（SwiftUI 按钮动作在 XCUITest 中验证）。
    func triggerViewAllForTesting()
    {
        onViewAll()
    }

    /// 仅供单元测试触发「配置」回调。
    func triggerSettingsForTesting()
    {
        onSettings()
    }

    /// 仅供单元测试触发「退出」回调。
    func triggerExitForTesting()
    {
        onExit()
    }
}
