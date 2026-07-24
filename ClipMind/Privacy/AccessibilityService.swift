import AppKit
import ApplicationServices
import Foundation

#if CLIPMIND_DEV

/// caret 位置定位协议（依赖注入，便于测试 mock）。
///
/// 设计文档第 3.5 节。有权限时获取前台应用 caret 位置用于面板定位。
/// 无 caret 时返回 nil，由调用方降级到鼠标位置。
protocol CaretLocating: AnyObject
{
    /// 获取前台应用当前 caret 位置。
    /// - Returns: caret 坐标（屏幕坐标系），无 caret 时返回 nil
    func locateCaret() -> NSPoint?
}

/// 鼠标位置提供协议（依赖注入，便于测试 mock）。
///
/// 设计文档第 3.5 节。无 caret 时降级到鼠标当前位置。
protocol MousePositionProviding: AnyObject
{
    /// 获取当前鼠标位置（屏幕坐标系）。
    func currentMouseLocation() -> NSPoint
}

/// 辅助功能服务（合规待定，仅 ClipMind-Dev Scheme 编译）。
///
/// 设计文档第 3.5 节 + 第 10.3 节「合规待定」标注。
/// 职责：
/// 1. 运行时查询辅助功能权限状态（不弹 TCC 提示）
/// 2. 有权限时获取前台应用 caret 位置（仅坐标，不读取文本内容）
/// 3. 无 caret 时降级返回鼠标当前位置
///
/// 合规说明：
/// - 使用公开辅助功能 API 查询权限状态（复用 PermissionRequester.axTrustedCheck(false)）
/// - 使用公开辅助功能 API 获取 caret 坐标（AXUIElementCopyAttributeValue）
/// - 使用公开系统事件 API 获取鼠标位置（CGEventCreate + CGEventGetLocation）
/// - 不读取 caret 处的文本内容
/// - 不缓存权限状态（每次粘贴流程重新检测，AC-F1.9-12）
///
/// 遵循 PastePermissionChecking 协议，替代 Phase 3 的 SystemPastePermissionChecker。
final class AccessibilityService: PastePermissionChecking, CaretLocating, MousePositionProviding
{
    private let caretProvider: CaretLocating?
    private let mouseProvider: MousePositionProviding?

    /// - Parameters:
    ///   - caretProvider: caret 定位提供器（测试注入 mock；生产用 nil 表示使用真实 AXUIElement 实现）
    ///   - mouseProvider: 鼠标位置提供器（测试注入 mock；生产用 nil 表示使用真实 CGEvent 实现）
    init(
        caretProvider: CaretLocating? = nil,
        mouseProvider: MousePositionProviding? = nil
    )
    {
        self.caretProvider = caretProvider
        self.mouseProvider = mouseProvider
    }

    // MARK: - PastePermissionChecking

    func isAccessibilityGranted() -> Bool
    {
        // 每次调用都重新检测，不缓存（AC-F1.9-12，设计文档第 7.2 节）
        // prompt: false 不弹 TCC 提示对话框（需求文档第 11.2 节）
        PermissionRequester.axTrustedCheck(false)
    }

    // MARK: - CaretLocating

    func locateCaret() -> NSPoint?
    {
        if let caretProvider = caretProvider
        {
            return caretProvider.locateCaret()
        }
        return locateCaretViaAccessibilityAPI()
    }

    // MARK: - MousePositionProviding

    func currentMouseLocation() -> NSPoint
    {
        if let mouseProvider = mouseProvider
        {
            return mouseProvider.currentMouseLocation()
        }
        return locateMouseViaCGEvent()
    }

    // MARK: - 私有：AXUIElement caret 定位

    /// 通过辅助功能 API 获取前台应用 caret 坐标。
    ///
    /// 实现思路：
    /// 1. 获取前台应用 AXUIElement（NSWorkspace.shared.frontmostApplication）
    /// 2. 获取前台应用 focused UI element
    /// 3. 查询 focused element 的 AXSelectedTextRange 属性
    /// 4. 查询 AXBoundsForRange 属性获取 caret 位置 CGRect
    /// 5. 转换为 NSPoint（屏幕坐标系）
    ///
    /// 无 caret（前台应用无文本输入）时返回 nil。
    private func locateCaretViaAccessibilityAPI() -> NSPoint?
    {
        guard let focusedElement = fetchFocusedUIElement()
        else
        {
            return nil
        }

        guard let boundsValue = fetchCaretBoundsValue(focusedElement: focusedElement)
        else
        {
            return nil
        }

        var caretBounds = CGRect.zero
        AXValueGetValue(boundsValue, .cgRect, &caretBounds)

        // AXUIElement 返回的坐标是屏幕左上角原点，转换为 NSPoint（屏幕左下角原点）
        let screenHeight = NSScreen.main?.frame.height ?? 0
        return NSPoint(x: caretBounds.origin.x, y: screenHeight - caretBounds.origin.y)
    }

    // MARK: - 私有：AXUIElement 辅助

    /// CFTypeRef 转换为 AXUIElement/AXValue：编译器提示该 downcast 总是成功，
    /// 使用 unsafeBitCast 避免 SwiftLint force_cast 规则（CF 类型桥接）。
    private func castToAXUIElement(_ ref: CFTypeRef) -> AXUIElement
    {
        unsafeBitCast(ref, to: AXUIElement.self)
    }

    /// 同上，转换为 AXValue。
    private func castToAXValue(_ ref: CFTypeRef) -> AXValue
    {
        unsafeBitCast(ref, to: AXValue.self)
    }

    /// 获取前台应用的 focused UI element。
    private func fetchFocusedUIElement() -> AXUIElement?
    {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication
        else
        {
            LogCategory.privacy.info("No frontmost application found")
            return nil
        }

        let appElement = AXUIElementCreateApplication(frontmostApp.processIdentifier)

        var focusedElementRef: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElementRef
        )

        guard focusedResult == .success,
              let focusedElementRef = focusedElementRef
        else
        {
            LogCategory.privacy.info("No focused UI element found")
            return nil
        }
        return castToAXUIElement(focusedElementRef)
    }

    /// 通过 focused element 的 AXSelectedTextRange 与 AXBoundsForRange 获取 caret 边界。
    private func fetchCaretBoundsValue(focusedElement: AXUIElement) -> AXValue?
    {
        var rangeValueRef: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(
            focusedElement,
            kAXSelectedTextRangeAttribute as CFString,
            &rangeValueRef
        )

        guard rangeResult == .success,
              let rangeValueRef = rangeValueRef
        else
        {
            LogCategory.privacy.info("No selected text range found")
            return nil
        }
        let rangeValue = castToAXValue(rangeValueRef)

        var range = CFRange()
        AXValueGetValue(rangeValue, .cfRange, &range)

        guard let boundsQueryValue = AXValueCreate(.cfRange, &range)
        else
        {
            LogCategory.privacy.info("Failed to create bounds query value")
            return nil
        }

        var boundsRef: CFTypeRef?
        let boundsResult = AXUIElementCopyParameterizedAttributeValue(
            focusedElement,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            boundsQueryValue,
            &boundsRef
        )

        guard boundsResult == .success,
              let boundsRef = boundsRef
        else
        {
            LogCategory.privacy.info("No bounds for range found")
            return nil
        }
        return castToAXValue(boundsRef)
    }

    // MARK: - 私有：CGEvent 鼠标位置

    /// 通过 CGEvent 获取当前鼠标位置（公开 API，沙盒内可用）。
    private func locateMouseViaCGEvent() -> NSPoint
    {
        if let event = CGEvent(source: nil)
        {
            let location = event.location
            // CGEvent 返回的是全局坐标（屏幕左上角原点），转换为 NSPoint（屏幕左下角原点）
            let screenHeight = NSScreen.main?.frame.height ?? 0
            return NSPoint(x: location.x, y: screenHeight - location.y)
        }
        return NSEvent.mouseLocation
    }
}

#endif
