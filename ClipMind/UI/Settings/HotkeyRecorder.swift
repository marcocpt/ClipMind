import AppKit
import SwiftUI

/// 快捷键录制组件。
///
/// 点击按钮进入录制模式，监听 NSEvent 键盘事件捕获组合键，
/// 录制完成后通过 @Binding 回传（存储格式如 "cmd+shift+v"）。
/// 支持 Esc 键取消录制，显示格式如 "⌘⇧V"。
///
/// 对应设计规范 3.8 节快捷键配置。
///
/// ## UI 验证状态
///
/// - 组件存在性：已由 SettingsUITests.testGeneralSettingsComponentsExist 覆盖（Layer 1 XCUITest）
/// - 录制流程（点击→按键→更新显示）：**手动验收项**
///   XCUITest 难以模拟 NSEvent.addLocalMonitorForEvents 的键盘事件捕获，
///   录制流程需在 Phase 4 T4.4 补充手动验收证据（截图/录屏）
/// - 重置功能（resetHotkeyButton）：**手动验收项**，同上原因
struct HotkeyRecorder: View {
    @Binding var hotkey: String
    @State private var isRecording = false
    @State private var monitor: Any?

    /// Esc 键 keyCode
    private static let keyCodeEsc: UInt16 = 53

    var body: some View {
        HStack {
            recordingIndicator
            resetButton
        }
        .onDisappear { stopRecording() }
    }

    // MARK: - 子视图

    @ViewBuilder
    private var recordingIndicator: some View {
        if isRecording {
            Text("按下快捷键...")
                .foregroundColor(.secondary)
                .accessibilityIdentifier("hotkeyRecordingHint")
        } else {
            Button(action: startRecording) {
                Text(HotkeyFormatter.display(hotkey))
                    .frame(minWidth: 80)
            }
            .accessibilityIdentifier("hotkeyRecorder")
        }
    }

    @ViewBuilder
    private var resetButton: some View {
        if !isRecording && !hotkey.isEmpty {
            Button("重置") {
                hotkey = "cmd+shift+v"
                LogCategory.app.info("快捷键已重置为默认值")
            }
            .accessibilityIdentifier("resetHotkeyButton")
        }
    }

    // MARK: - 录制逻辑

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKeyEvent(event)
            return nil
        }
        LogCategory.app.info("开始录制快捷键")
    }

    private func stopRecording() {
        if let activeMonitor = monitor {
            NSEvent.removeMonitor(activeMonitor)
            monitor = nil
        }
        isRecording = false
    }

    private func handleKeyEvent(_ event: NSEvent) {
        if event.keyCode == Self.keyCodeEsc {
            stopRecording()
            LogCategory.app.info("取消快捷键录制")
            return
        }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard let stored = HotkeyFormatter.parse(modifiers: modifiers, keyCode: event.keyCode) else {
            return
        }

        hotkey = stored
        stopRecording()
        LogCategory.app.info("快捷键已更新: \(stored)")
    }
}

/// 快捷键格式化工具。
///
/// 负责存储格式（cmd+shift+v）与显示格式（⌘⇧V）之间的转换，
/// 以及从 NSEvent 解析出存储格式。
enum HotkeyFormatter {
    /// 将存储格式转为显示格式（符号 + 大写字母）。
    static func display(_ stored: String) -> String {
        stored.split(separator: "+").map { token -> String in
            switch token.lowercased() {
            case "cmd":
                return "⌘"
            case "shift":
                return "⇧"
            case "opt", "option":
                return "⌥"
            case "ctrl", "control":
                return "⌃"
            default:
                return token.uppercased()
            }
        }.joined()
    }

    /// 从 NSEvent 修饰键和 keyCode 解析出存储格式。
    static func parse(modifiers: NSEvent.ModifierFlags, keyCode: UInt16) -> String? {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("ctrl") }
        if modifiers.contains(.option) { parts.append("opt") }
        if modifiers.contains(.shift) { parts.append("shift") }
        if modifiers.contains(.command) { parts.append("cmd") }

        // 至少需要一个主修饰键
        guard !parts.isEmpty else { return nil }

        guard let key = keyName(for: keyCode) else { return nil }
        parts.append(key)
        return parts.joined(separator: "+")
    }

    /// 从存储格式解析出 Carbon API 需要的修饰键 mask 和 keyCode。
    ///
    /// 用于全局快捷键注册（RegisterEventHotKey）。
    /// - Parameter stored: 存储格式，如 "cmd+shift+v"
    /// - Returns: 解析结果，无效格式返回 nil
    static func parse(stored: String) -> ParsedHotkey? {
        let tokens = stored.split(separator: "+").map { $0.lowercased() }
        guard !tokens.isEmpty else { return nil }

        var modifiers: UInt32 = 0
        var keyToken: String?

        for token in tokens {
            switch token {
            case "cmd":
                modifiers |= 0x0100 // cmdKey
            case "shift":
                modifiers |= 0x0200 // shiftKey
            case "opt", "option":
                modifiers |= 0x0800 // optionKey
            case "ctrl", "control":
                modifiers |= 0x1000 // controlKey
            default:
                keyToken = token
            }
        }

        // 至少需要一个修饰键和一个普通键
        guard modifiers != 0, let key = keyToken else { return nil }

        guard let keyCode = keyCode(for: key) else { return nil }

        return ParsedHotkey(modifiers: modifiers, keyCode: keyCode)
    }

    /// 将 keyCode 映射为小写字母或数字字符串。
    private static func keyName(for keyCode: UInt16) -> String? {
        let keyMap: [UInt16: String] = [
            0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g",
            6: "z", 7: "x", 8: "c", 9: "v", 11: "b", 12: "q",
            13: "w", 14: "e", 15: "r", 16: "y", 17: "t", 18: "1",
            19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 25: "9",
            26: "7", 28: "8", 29: "0", 31: "o", 32: "u", 34: "i",
            35: "p", 37: "l", 38: "j", 40: "k", 45: "n", 46: "m"
        ]
        return keyMap[keyCode]
    }

    /// 将小写字母或数字字符串映射回 keyCode。
    private static func keyCode(for key: String) -> UInt32? {
        let keyMap: [String: UInt32] = [
            "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5,
            "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12,
            "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "1": 18,
            "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "9": 25,
            "7": 26, "8": 28, "0": 29, "o": 31, "u": 32, "i": 34,
            "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46
        ]
        return keyMap[key]
    }
}

/// 解析后的快捷键参数，用于 Carbon API 注册。
struct ParsedHotkey {
    let modifiers: UInt32
    let keyCode: UInt32
}
