import AppKit
import SwiftUI

extension Notification.Name {
    static let openMainWindow = Notification.Name("ClipMindOpenMainWindow")
}

final class StatusItemController: NSObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: "doc.on.clipboard.fill",
                accessibilityDescription: "ClipMind"
            )
            button.setAccessibilityLabel("ClipMind")
            button.target = self
            button.action = #selector(togglePopover)
        }
        popover = NSPopover()
        popover?.contentViewController = NSHostingController(rootView: PopoverView())
        popover?.behavior = .transient
    }

    @objc private func togglePopover() {
        guard let popover = popover, let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
