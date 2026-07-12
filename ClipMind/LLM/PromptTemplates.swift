import Foundation

/// LLM 处理的 prompt 模板（T2.4）。
///
/// 为 4 种一键处理（智能总结、即时翻译、智能改写、提取待办）构建 system prompt 和 user prompt。
/// system prompt 固定不变，定义 LLM 的角色、输出格式和行为约束；
/// user prompt 拼接用户输入文本和上下文参数（如翻译方向、改写模式）。
enum PromptTemplates {
    // MARK: - 智能总结

    /// 智能总结的 system prompt。
    ///
    /// 设计要点（AC-13）：
    /// - 输出 3-5 句核心要点
    /// - 提取关键信息，保留事实
    /// - 去重去冗余，不展开细节
    static let summarizeSystemPrompt = """
    你是专业的信息总结助手。请将用户提供的文本总结为 3-5 句核心要点，遵循以下规则：
    1. 提取最关键的信息，保留事实和数据
    2. 去除冗余和重复内容
    3. 每句围绕一个核心要点，避免展开细节
    4. 使用简洁、客观的语言
    5. 直接输出总结内容，不要添加「总结：」等前缀
    """

    // MARK: - 即时翻译

    /// 即时翻译的 system prompt。
    ///
    /// 设计要点（AC-14）：
    /// - 中英对照输出（原文 + 译文）
    /// - 技术术语（如 NSWindowController、URLSession）保留原文
    /// - 识别源语言，自动翻译为目标语言
    static let translateSystemPrompt = """
    你是专业的翻译助手。请将用户提供的文本翻译为目标语言，遵循以下规则：
    1. 输出中英对照格式：先原文，再译文，逐句对应
    2. 技术术语（如类名、API 名、协议名，例如 NSWindowController、URLSession、Codable）保留原文不翻译
    3. 自动识别源语言，中文翻译为英文，英文翻译为中文
    4. 保持原文的语气和语境
    5. 直接输出对照内容，不要添加「翻译：」等前缀
    """

    // MARK: - 智能改写

    /// 智能改写的通用 system prompt 基础描述。
    ///
    /// 设计要点（AC-15）：支持 3 种模式
    /// - adjustTone: 调整语气
    /// - condense: 精简
    /// - expand: 扩写
    static let rewriteSystemPrompt = """
    你是专业的文本改写助手。请根据用户指定的模式改写文本，支持 3 种模式：
    - adjust_tone: 调整语气（使表达更得体、专业或友好）
    - condense: 精简（去除冗余，保留核心信息）
    - expand: 扩写（补充细节，使内容更丰富）
    直接输出改写后的内容，不要添加「改写：」等前缀。
    """

    // MARK: - 提取待办

    /// 提取待办的 system prompt。
    ///
    /// 设计要点（AC-16）：
    /// - 从会议纪要、聊天记录、需求文档中提取任务项
    /// - 结构化输出 JSON 数组
    /// - 每个任务包含 task（任务描述）、assignee（负责人，可选）、dueDate（截止时间，可选）
    static let extractTodoSystemPrompt = """
    你是专业的待办事项提取助手。请从用户提供的文本中提取任务项，输出为 JSON 数组，遵循以下规则：
    1. 输出格式为 JSON 数组，每个元素包含以下字段：
       - task: 任务描述（字符串，必填）
       - assignee: 负责人姓名（字符串，未明确时为 null）
       - dueDate: 截止时间（字符串格式 YYYY-MM-DD，未明确时为 null）
    2. 仅提取明确的任务，忽略泛泛而谈的内容
    3. 直接输出 JSON，不要添加 markdown 代码块标记或解释文字
    4. 示例输出：[{"task":"完成需求文档","assignee":"张三","dueDate":"2025-01-15"}]
    """

    // MARK: - user prompt 构建方法

    /// 构建智能总结的 user prompt。
    /// - Parameter text: 待总结的文本
    /// - Returns: 拼接好的 user prompt
    static func buildSummarizeUserPrompt(text: String) -> String {
        "请总结以下文本：\n\n\(text)"
    }

    // swiftlint:disable identifier_name
    /// 构建即时翻译的 user prompt。
    /// - Parameters:
    ///   - text: 待翻译的文本
    ///   - from: 源语言代码（如 "zh"、"en"）
    ///   - to: 目标语言代码
    /// - Returns: 拼接好的 user prompt
    static func buildTranslateUserPrompt(text: String, from: String, to: String) -> String {
        "请将以下文本从 \(from) 翻译为 \(to)，输出中英对照格式：\n\n\(text)"
    }
    // swiftlint:enable identifier_name

    /// 构建智能改写的 user prompt。
    /// - Parameters:
    ///   - text: 待改写的文本
    ///   - mode: 改写模式（adjustTone/condense/expand）
    /// - Returns: 拼接好的 user prompt，包含模式指令
    static func buildRewriteUserPrompt(text: String, mode: RewriteMode) -> String {
        let modeInstruction = rewritePrompt(for: mode)
        return "\(modeInstruction)\n\n请改写以下文本：\n\n\(text)"
    }

    /// 构建提取待办的 user prompt。
    /// - Parameter text: 待提取的文本（会议纪要、聊天、需求等）
    /// - Returns: 拼接好的 user prompt
    static func buildExtractTodoUserPrompt(text: String) -> String {
        "请从以下文本中提取待办事项，输出为 JSON 数组：\n\n\(text)"
    }

    // MARK: - 改写模式 prompt

    /// 根据 RewriteMode 返回对应的改写指令。
    /// - Parameter mode: 改写模式
    /// - Returns: 模式描述字符串
    static func rewritePrompt(for mode: RewriteMode) -> String {
        switch mode {
        case .adjustTone:
            return "调整语气：使表达更得体、专业或友好，保持原意不变。"
        case .condense:
            return "精简：去除冗余内容，保留核心信息，使文本更简短。"
        case .expand:
            return "扩写：补充相关细节和背景，使内容更丰富、完整。"
        }
    }
}
