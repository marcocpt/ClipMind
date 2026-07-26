import AppKit
@testable import ClipMind
import Foundation

/// 测试共享调用顺序计数器（供 MockPanelCloser / MockOverlayShower / MockPasteSimulator 共享）。
/// F1.11 Bug 4：从 PasteCoordinatorTests.swift 抽取，缓解 file_length 违规。
var sharedCallSequence = 0

// MARK: - 测试辅助 Mock

final class MockPermissionChecker: PastePermissionChecking
{
    var granted: Bool
    private(set) var checkCallCount = 0

    init(granted: Bool)
    {
        self.granted = granted
    }

    func isAccessibilityGranted() -> Bool
    {
        checkCallCount += 1
        return granted
    }
}

final class MockClipboardWriter: ClipboardWriting
{
    var shouldSucceed = true
    private(set) var writeCalled = false
    private(set) var writtenText: String = ""

    func write(text: String) -> Bool
    {
        writeCalled = true
        writtenText = text
        return shouldSucceed
    }

    func reset()
    {
        writeCalled = false
        writtenText = ""
        shouldSucceed = true
    }
}

/// F1.11 Bug 4 测试 Mock：记录 `touch(id:)` 调用。
final class MockClipToucher: ClipTouching
{
    private(set) var touchCalled = false
    private(set) var touchedId: UUID?
    private(set) var callCount = 0

    @discardableResult
    func touch(id: UUID) -> Bool
    {
        touchCalled = true
        touchedId = id
        callCount += 1
        return true
    }

    func reset()
    {
        touchCalled = false
        touchedId = nil
        callCount = 0
    }
}

final class MockPanelCloser: PanelClosing
{
    private(set) var closeCalled = false
    private(set) var callOrder = 0

    var isPanelVisible: Bool { !closeCalled }

    func closePanel()
    {
        closeCalled = true
        sharedCallSequence += 1
        callOrder = sharedCallSequence
    }

    func reset()
    {
        closeCalled = false
        callOrder = 0
    }
}

final class MockOverlayShower: OverlayShowing
{
    private(set) var showCalled = false
    private(set) var callOrder = 0

    func showOverlay()
    {
        showCalled = true
        sharedCallSequence += 1
        callOrder = sharedCallSequence
    }

    func hideOverlay() {}

    func reset()
    {
        showCalled = false
        callOrder = 0
    }
}

@MainActor
final class ScreenCenterLocatorForIntegration: PanelScreenLocating
{
    func locatePosition(lastClosedPosition: NSPoint?) -> NSPoint
    {
        let screenFrame = NSScreen.main?.frame ?? .zero
        return NSPoint(
            x: screenFrame.midX - QuickPastePanelController.panelSize.width / 2.0,
            y: screenFrame.midY - QuickPastePanelController.panelSize.height / 2.0
        )
    }
}

#if CLIPMIND_DEV

final class MockPasteSimulator: PasteSimulating
{
    private(set) var simulateCalled = false
    private(set) var callOrder = 0

    func simulatePaste()
    {
        simulateCalled = true
        sharedCallSequence += 1
        callOrder = sharedCallSequence
    }

    func reset()
    {
        simulateCalled = false
        callOrder = 0
    }
}

#endif
