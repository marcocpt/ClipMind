import AppKit
import SwiftUI

/// 菜单栏弹窗预览窗口工厂（F1.11 Phase 2）。
///
/// 在 UITEST 模式下（`--UITEST_POPOVER_WINDOW`）创建独立 `NSPanel` 承载 `UnifiedPastePanelView`，
/// 使 XCUITest 能稳定定位元素。使用 `NSPanel`（与 F1.9 快捷键面板一致的窗口类型），
/// 避免 `NSWindow` 的 `.closable` styleMask 拦截 Esc 键导致 `onEscPressed` 不触发。
@MainActor
enum PopoverPreviewWindowFactory
{
    /// 创建并显示菜单栏弹窗预览窗口。
    /// - Parameter clips: 注入的剪贴项列表（UITEST 模式下为 `ClipTestData.previewClips`）
    static func show(clips: [ClipItem])
    {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 480),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isFloatingPanel = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.hidesOnDeactivate = false
        window.center()

        let viewModel = UnifiedPastePanelViewModel(clips: clips)
        // UITEST 模式下注入 Esc / 粘贴回调，模拟 NSPopover 的关闭行为
        viewModel.onEscPressed = { [weak window] in
            window?.close()
        }
        viewModel.onPasteTriggered = { [weak window] _ in
            // UITEST 模式下不接入 PasteCoordinator，仅模拟「粘贴触发后关闭面板」信号
            window?.close()
        }
        window.contentViewController = NSHostingController(
            rootView: UnifiedPastePanelView(
                viewModel: viewModel,
                showsBottomBar: true,
                accessibilityPrefix: "popover"
            )
        )
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
