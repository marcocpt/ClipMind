import XCTest

@testable import ClipMind

/// AC-22 日志脱敏静态验证测试（NFR-007/D15）。
///
/// 通过读取生产代码源文件，断言日志语句中不包含敏感插值模式：
/// - `\(event.content` - 剪贴板原文
/// - `\(text,` / `\(text)` - 原始文本（属性访问如 `text.count` 不在此列）
/// - `\(url.lastPathComponent` - 文件名
/// - `fileName=` - 日志字段中的文件名
final class AutoSaveAC22LogSanitizationTests: XCTestCase
{
    private var autoSaveDirectory: URL!

    override func setUpWithError() throws
    {
        // #file = .../ClipMindTests/AutoSave/AutoSaveAC22LogSanitizationTests.swift
        // 上溯 3 级到项目根目录，再进入 ClipMind/AutoSave
        let testFileURL = URL(fileURLWithPath: #file)
        let projectRoot = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        autoSaveDirectory = projectRoot.appendingPathComponent("ClipMind/AutoSave")
    }

    // MARK: - AC-22：AutoSaveService 日志不输出剪贴板原文/文件名

    func testAutoSaveServiceLogSanitized() throws
    {
        let source = try readSource("AutoSaveService.swift")
        assertNoSensitivePatterns(in: source, fileName: "AutoSaveService.swift")
    }

    // MARK: - AC-22：FileWriter 日志不输出文件名/完整路径

    func testFileWriterLogSanitized() throws
    {
        let source = try readSource("FileWriter.swift")
        assertNoSensitivePatterns(in: source, fileName: "FileWriter.swift")
    }

    // MARK: - AC-22：ClipboardReplacer 日志不输出剪贴板原文

    func testClipboardReplacerLogSanitized() throws
    {
        let source = try readSource("ClipboardReplacer.swift")
        assertNoSensitivePatterns(in: source, fileName: "ClipboardReplacer.swift")
    }

    // MARK: - 辅助方法

    private func readSource(_ fileName: String) throws -> String
    {
        let url = autoSaveDirectory.appendingPathComponent(fileName)
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// 断言源码中不包含敏感日志插值模式（NFR-007/D15）。
    private func assertNoSensitivePatterns(in source: String, fileName: String)
    {
        // NFR-007：禁止输出剪贴板原文
        XCTAssertFalse(
            source.contains("\\(event.content"),
            "AC-22：\(fileName) 日志不应插值 event.content（剪贴板原文）"
        )

        // NFR-007：禁止直接插值 text 变量（属性访问如 text.count 不在此列）
        XCTAssertFalse(
            source.contains("\\(text,"),
            "AC-22：\(fileName) 日志不应直接插值 text 变量（应使用 text.count 等属性）"
        )
        XCTAssertFalse(
            source.contains("\\(text)"),
            "AC-22：\(fileName) 日志不应直接插值 text 变量（应使用 text.count 等属性）"
        )

        // NFR-007：禁止输出文件名
        XCTAssertFalse(
            source.contains("\\(url.lastPathComponent"),
            "AC-22：\(fileName) 日志不应插值 url.lastPathComponent（文件名）"
        )

        // NFR-007/D15：禁止日志字段中出现 fileName= 键
        XCTAssertFalse(
            source.contains("fileName="),
            "AC-22：\(fileName) 日志不应包含 fileName= 字段（文件名）"
        )
    }
}
