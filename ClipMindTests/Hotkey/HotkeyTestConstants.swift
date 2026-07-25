@testable import ClipMind
import Foundation

/// F1.10 测试常量集：集中管理快捷键测试中的默认值与 fixture 值。
///
/// 后续再次修改默认值时，仅需修改本文件的 `default` 与 `legacyDefault` 两个常量，
/// 所有引用处自动同步。生产代码不引用本文件（满足 NFR-006 可维护性）。
enum TestHotkeys
{
    /// 当前默认值（与 `AppSettings.defaultHotkey` 保持一致）。
    /// 用于断言应用设置的默认值、设置页显示、新默认值解析与反向构造。
    static let `default` = "cmd+shift+space"

    /// 历史默认值（旧默认值，用于回归保护与老用户迁移测试）。
    /// 用于验证旧默认值仍可被解析、反向构造、显示；作为老用户迁移输入。
    static let legacyDefault = "cmd+shift+v"

    /// 任意有效值（自定义快捷键，用于服务层 fixture 测试中非断言目标的 hotkey 值）。
    /// 提升测试语义：当 hotkey 值不是断言目标时，使用 `arbitrary` 而非字面值。
    static let arbitrary = "ctrl+opt+a"
}
