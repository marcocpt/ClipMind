@testable import ClipMind
import XCTest

/// PromptTemplates 单元测试（T2.4）。
///
/// 验证 4 种 LLM 处理的 system prompt 模板符合设计规范：
/// - 每个 prompt 非空
/// - summarize prompt 指导输出 3-5 句核心要点
/// - translate prompt 指导中英对照 + 保留技术术语原文
/// - rewrite prompt 支持 3 种模式（adjustTone/condense/expand）
/// - extractTodo prompt 指导结构化 JSON 输出（task/assignee/dueDate）
final class PromptTemplateTests: XCTestCase {
    // MARK: - 非空校验

    func testSummarizeSystemPromptIsNotEmpty() {
        XCTAssertFalse(PromptTemplates.summarizeSystemPrompt.isEmpty, "summarize system prompt 不应为空")
    }

    func testTranslateSystemPromptIsNotEmpty() {
        XCTAssertFalse(PromptTemplates.translateSystemPrompt.isEmpty, "translate system prompt 不应为空")
    }

    func testRewriteSystemPromptIsNotEmpty() {
        XCTAssertFalse(PromptTemplates.rewriteSystemPrompt.isEmpty, "rewrite system prompt 不应为空")
    }

    func testExtractTodoSystemPromptIsNotEmpty() {
        XCTAssertFalse(PromptTemplates.extractTodoSystemPrompt.isEmpty, "extractTodo system prompt 不应为空")
    }

    // MARK: - summarize prompt 设计要点

    func testSummarizePromptMentionsThreeToFiveSentences() {
        // AC-13: 智能总结生成 3-5 句核心要点
        let prompt = PromptTemplates.summarizeSystemPrompt
        XCTAssertTrue(prompt.contains("3") || prompt.contains("三"), "summarize prompt 应提及最少句数")
        XCTAssertTrue(prompt.contains("5") || prompt.contains("五"), "summarize prompt 应提及最多句数")
    }

    // MARK: - translate prompt 设计要点

    func testTranslatePromptMentionsBilingualOutput() {
        // AC-14: 即时翻译生成中英对照
        let prompt = PromptTemplates.translateSystemPrompt
        XCTAssertTrue(prompt.contains("中英") || prompt.contains("对照") || prompt.contains("双语"),
                      "translate prompt 应指导中英对照输出")
    }

    func testTranslatePromptMentionsPreservingTechnicalTerms() {
        // AC-14: 技术术语保留原文
        let prompt = PromptTemplates.translateSystemPrompt
        XCTAssertTrue(prompt.contains("技术术语") || prompt.contains("原文"),
                      "translate prompt 应指导保留技术术语原文")
    }

    // MARK: - rewrite prompt 设计要点

    func testRewritePromptSupportsAdjustToneMode() {
        // AC-15: 智能改写提供 3 种模式
        let prompt = PromptTemplates.rewritePrompt(for: .adjustTone)
        XCTAssertFalse(prompt.isEmpty, "adjustTone 模式 prompt 不应为空")
        let lower = prompt.lowercased()
        XCTAssertTrue(prompt.contains("语气") || lower.contains("tone"),
                      "adjustTone prompt 应提及语气调整")
    }

    func testRewritePromptSupportsCondenseMode() {
        let prompt = PromptTemplates.rewritePrompt(for: .condense)
        XCTAssertFalse(prompt.isEmpty, "condense 模式 prompt 不应为空")
        let lower = prompt.lowercased()
        XCTAssertTrue(prompt.contains("精简") || lower.contains("condense") || prompt.contains("简短"),
                      "condense prompt 应提及精简")
    }

    func testRewritePromptSupportsExpandMode() {
        let prompt = PromptTemplates.rewritePrompt(for: .expand)
        XCTAssertFalse(prompt.isEmpty, "expand 模式 prompt 不应为空")
        let lower = prompt.lowercased()
        XCTAssertTrue(prompt.contains("扩写") || lower.contains("expand") || prompt.contains("扩展"),
                      "expand prompt 应提及扩写")
    }

    func testRewritePromptDiffersForEachMode() {
        // 3 种模式应产出不同的 prompt
        let adjustTone = PromptTemplates.rewritePrompt(for: .adjustTone)
        let condense = PromptTemplates.rewritePrompt(for: .condense)
        let expand = PromptTemplates.rewritePrompt(for: .expand)
        XCTAssertNotEqual(adjustTone, condense, "adjustTone 与 condense 的 prompt 应不同")
        XCTAssertNotEqual(adjustTone, expand, "adjustTone 与 expand 的 prompt 应不同")
        XCTAssertNotEqual(condense, expand, "condense 与 expand 的 prompt 应不同")
    }

    // MARK: - extractTodo prompt 设计要点

    func testExtractTodoPromptInstructsJsonOutput() {
        // AC-16: 提取待办返回结构化任务列表
        let prompt = PromptTemplates.extractTodoSystemPrompt
        XCTAssertTrue(prompt.contains("JSON") || prompt.contains("json"),
                      "extractTodo prompt 应指导输出 JSON")
    }

    func testExtractTodoPromptMentionsTaskFields() {
        let prompt = PromptTemplates.extractTodoSystemPrompt
        XCTAssertTrue(prompt.contains("task"), "extractTodo prompt 应提及 task 字段")
        XCTAssertTrue(prompt.contains("assignee"), "extractTodo prompt 应提及 assignee 字段")
        XCTAssertTrue(prompt.contains("dueDate"), "extractTodo prompt 应提及 dueDate 字段")
    }

    // MARK: - user prompt 构建辅助方法

    func testBuildSummarizeUserPrompt() {
        let userPrompt = PromptTemplates.buildSummarizeUserPrompt(text: "需要被总结的长文本")
        XCTAssertTrue(userPrompt.contains("需要被总结的长文本"), "user prompt 应包含输入文本")
    }

    func testBuildTranslateUserPrompt() {
        let userPrompt = PromptTemplates.buildTranslateUserPrompt(text: "Hello", from: "en", to: "zh")
        XCTAssertTrue(userPrompt.contains("Hello"), "user prompt 应包含输入文本")
    }

    func testBuildRewriteUserPrompt() {
        let userPrompt = PromptTemplates.buildRewriteUserPrompt(text: "原始文本", mode: .condense)
        XCTAssertTrue(userPrompt.contains("原始文本"), "user prompt 应包含输入文本")
    }

    func testBuildExtractTodoUserPrompt() {
        let userPrompt = PromptTemplates.buildExtractTodoUserPrompt(text: "明天张三完成需求文档")
        XCTAssertTrue(userPrompt.contains("明天张三完成需求文档"), "user prompt 应包含输入文本")
    }
}
