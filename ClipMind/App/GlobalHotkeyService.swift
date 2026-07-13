import Carbon
import Foundation

/// 全局快捷键注册器协议。
///
/// 将 Carbon API 调用抽象为协议，便于测试时注入 mock，
/// 避免测试环境无法注册全局快捷键的问题。
protocol HotkeyRegistering: AnyObject {
    /// 注册全局快捷键，返回是否成功。
    func register(keyCode: UInt32, modifiers: UInt32, onTriggered: @escaping () -> Void) -> Bool

    /// 注销全局快捷键。
    func unregister()
}

/// 基于 Carbon API 的全局快捷键注册器。
final class CarbonHotkeyRegistrar: HotkeyRegistering {
    /// 应用签名，用于 EventHotKeyID（'CLMD' = ClipMind）。
    private static let hotkeySignature: OSType = 0x434C4D44

    private var hotkeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var onTriggered: (() -> Void)?

    var isRegistered: Bool {
        return hotkeyRef != nil
    }

    func register(keyCode: UInt32, modifiers: UInt32, onTriggered: @escaping () -> Void) -> Bool {
        self.onTriggered = onTriggered

        // 安装键盘事件处理器
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, _, userData) -> OSStatus in
                guard let userData = userData else { return noErr }
                let registrar = Unmanaged<CarbonHotkeyRegistrar>.fromOpaque(userData)
                    .takeUnretainedValue()
                registrar.onTriggered?()
                return noErr
            },
            1,
            &eventSpec,
            selfPtr,
            &eventHandler
        )

        guard installStatus == noErr else {
            LogCategory.app.error("安装快捷键事件处理器失败: \(installStatus)")
            return false
        }

        // 注册全局快捷键
        let hotkeyID = EventHotKeyID(
            signature: Self.hotkeySignature,
            id: UInt32(1)
        )

        let regStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        guard regStatus == noErr else {
            LogCategory.app.error("注册全局快捷键失败: \(regStatus)")
            hotkeyRef = nil
            return false
        }

        return true
    }

    func unregister() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
        onTriggered = nil
    }
}

/// 全局快捷键服务。
///
/// 读取 AppSettings.hotkey 配置，通过注册器注册全局快捷键。
/// 当快捷键被按下时发送 `.openMainWindow` 通知以唤醒应用窗口。
///
/// 对应设计规范 3.8 节快捷键配置。
final class GlobalHotkeyService {
    private let registrar: HotkeyRegistering
    private let hotkey: String
    private(set) var isRegistered = false

    /// 使用存储格式的快捷键初始化并自动注册。
    /// - Parameters:
    ///   - hotkey: 存储格式快捷键，如 "cmd+shift+v"。无效格式不会注册。
    ///   - registrar: 快捷键注册器，默认使用 CarbonHotkeyRegistrar。
    init(hotkey: String, registrar: HotkeyRegistering = CarbonHotkeyRegistrar()) {
        self.hotkey = hotkey
        self.registrar = registrar
        register()
    }

    deinit {
        unregister()
    }

    /// 注销全局快捷键。
    func unregister() {
        registrar.unregister()
        isRegistered = false
        LogCategory.app.info("全局快捷键已注销")
    }

    // MARK: - 注册

    private func register() {
        guard let parsed = HotkeyFormatter.parse(stored: hotkey) else {
            LogCategory.app.error("无法解析快捷键配置: \(hotkey)")
            return
        }

        isRegistered = registrar.register(
            keyCode: parsed.keyCode,
            modifiers: parsed.modifiers
        ) { [weak self] in
            self?.handleHotkeyPressed()
        }

        if isRegistered {
            LogCategory.app.info("全局快捷键已注册: \(hotkey)")
        }
    }

    // MARK: - 触发

    private func handleHotkeyPressed() {
        LogCategory.app.info("全局快捷键已触发: \(hotkey)")
        NotificationCenter.default.post(name: .openMainWindow, object: nil)
    }
}
