# Swift 编码规范：Trae AI 友好版

> 适用范围：Swift 5.7+ / macOS 13.0+ 项目  
> 适用工具：Trae IDE / Trae AI Project Rules / Agent Rules  
> 来源：由 `CODING_STANDARDS.md` 整理为更适合 AI 执行的短规则、工作流和 Prompt 模板。  
> 使用建议：不要把完整长规范直接塞进每次对话。优先把第 1 节放入 Trae Project Rules，把第 2 节放入相关 Agent Rules。

---

## 0. 使用方式

建议拆成 3 层使用：

| 放置位置 | 放什么 | 目的 |
|---|---|---|
| Trae Project Rules | 第 1 节「Project Rules」 | 每次生成、修改、重构 Swift 代码都默认遵守 |
| Trae Agent Rules | 第 2 节「Agent 工作流」 | 给代码生成、重构、审查 Agent 使用 |
| 单次 Prompt | 第 8 节模板 | 针对当前任务补充具体上下文 |

原则：

- **Project Rules 要短、硬、可执行**，不要放太多解释。
- **详细解释放在文档后半部分**，需要时再作为上下文给 AI。
- **能由 SwiftLint / CI 检查的规则交给工具**，AI 负责遵守和修正。
- **架构、日志、注释、并发、安全等难以自动检查的规则交给 PR Review + AI 自检**。

---

## 1. Trae Project Rules（建议直接粘贴）

下面内容适合直接放进 Trae 的 Project Rules。

```markdown
# Swift Project Rules

This is a Swift 5.7+ macOS 13.0+ project. Follow these rules for all code generation, editing, refactoring, and review.

## Core Principles

1. Prioritize consistency, readability, explicit intent, and maintainability.
2. Follow existing project style before introducing new patterns.
3. Prefer small, focused changes. Do not rewrite unrelated code.
4. Do not add dependencies, new architecture layers, or large abstractions unless explicitly requested.
5. If code is hard to test or maintain, explain the minimal refactor needed before changing it.

## Formatting

1. Use 4 spaces for indentation. Do not use tabs.
2. Keep line length under 120 characters when reasonable; never exceed 200 characters unless unavoidable.
3. Use Allman braces for Swift: opening braces must be on their own line for types, functions, initializers, operators, closures when practical, and control flow.
4. Use one blank line between functions and logical blocks.
5. Use `// MARK: - Section Name` for file organization.

## Naming

1. Follow Swift API Design Guidelines.
2. Use meaningful names. Avoid unclear abbreviations except common ones like URL, ID, HTTP.
3. Types use UpperCamelCase.
4. Variables, constants, functions, and enum cases use lowerCamelCase.
5. Boolean names should start with `is`, `has`, `should`, `can`, or another clear boolean phrase.
6. Do not include redundant type information in names, such as `nameString`.

## Comments and Documentation

1. All `public` and `open` types, functions, and important properties must have documentation comments.
2. Internal comments should explain why code exists, not repeat what the code already says.
3. Complex logic must have a short comment describing intent, constraints, and edge cases.
4. Use TODO/FIXME format: `// TODO: [owner] #issue-number reason`.

## Logging

1. Do not use `print()` for app logging.
2. Use the project `LogCategory` based logging abstraction (`os.Logger` with subsystem `com.clipmind.app`).
3. Error and fault logs must include useful metadata such as module, operation, phase, result, errorCode, or retryCount.
4. Never log sensitive user data, raw clipboard content, passwords, tokens, personal information, or full file paths containing usernames.
5. Prefer structured metadata over string interpolation.

## Error Handling

1. Do not swallow errors silently.
2. Convert unexpected errors into project-level typed errors where appropriate.
3. Log errors with context before rethrowing or mapping them.
4. For user-facing errors, prefer `LocalizedError` with `errorDescription`, `failureReason`, and `recoverySuggestion`.

## Concurrency

1. UI state and UI-related types must be isolated to `@MainActor` or updated through `MainActor.run`.
2. Prefer structured concurrency: `async/await`, `async let`, and `withTaskGroup`.
3. Do not use `Task.detached` unless the task intentionally outlives the caller and does not need inherited cancellation or priority.
4. Shared mutable state must be protected by `actor`, a serial executor, or a clear synchronization strategy.
5. Propagate cancellation. Do not hide `CancellationError` unless intentionally converting it.
6. Prefer value types and `Sendable` for data crossing concurrency boundaries.
7. Use `@unchecked Sendable` only with a clear synchronization explanation.

## Constants and Magic Values

1. Do not use magic numbers or magic strings for business meaning.
2. Extract business constants into named constants, enums, or configuration.
3. UserDefaults keys, notification names, API paths, and identifiers must be named constants.
4. Trivial values like array index `0`, `1`, and `-1` in obvious local contexts are allowed.

## File Organization

1. File name should match the primary type name.
2. Keep imports sorted: system frameworks first, third-party dependencies second, project modules last.
3. Inside a type, organize code as: type aliases, nested types, public properties, internal properties, private properties, initializers, public methods, internal methods, private methods.
4. Use extensions to group protocol conformances.

## Architecture

1. The project uses a single Xcode project with three targets: `ClipMind` (app), `ClipMindTests` (unit tests), `ClipMindUITests` (UI tests).
2. App modules are organized by responsibility: `App`, `Capture`, `Classify`, `LLM`, `ML`, `Models`, `Privacy`, `Search`, `Storage`, `UI`, `Utils`.
3. Dependency direction: `UI` → business modules → `Models` / `Utils`. Do not create reverse dependencies.
4. External dependencies (e.g., SQLite.swift) are managed via Swift Package Manager.
5. Prefer initializer injection for external dependencies.

## Testing

1. When behavior changes, add or update tests.
2. Tests must verify real observable behavior, not implementation details.
3. Do not mock the system under test. Mock or stub only external dependencies.
4. Async tests must not use `sleep`, `usleep`, fixed delay, or arbitrary `Task.sleep`.
5. Prefer `async/await` tests for Swift concurrency code.
6. Test names should clearly describe method, scenario, and expected result.

## SwiftLint and CI

1. Generated code must be compatible with SwiftLint strict mode unless the user says otherwise.
2. Do not introduce `print()`, force unwraps, force casts, unused code, or lint violations.
3. If you cannot run lint/build/test, state what should be run.
```

---

## 2. Trae Agent Rules：代码生成 / 重构 / 审查工作流

适合放进专门的 Coding Agent 或 Review Agent。

```markdown
# Swift Coding Agent Workflow

When asked to modify Swift code:

1. Inspect existing files and follow local style.
2. Identify the target behavior, affected types, dependencies, and tests.
3. Make the smallest safe change that satisfies the request.
4. Preserve public API unless the user explicitly asks to change it.
5. Avoid changing formatting outside the edited area unless formatting is part of the task.
6. Add or update tests when behavior changes.
7. Self-review before final response:
   - No `print()`
   - No sensitive logging (clipboard content, passwords, tokens)
   - No magic business values
   - No swallowed errors
   - No accidental `Task.detached`
   - No UI updates outside MainActor
   - No reverse module dependency
   - No untested behavior change
8. Final response should include:
   - What changed
   - Why it changed
   - Tests/lint/build run, or commands the user should run
   - Any risks or follow-up needed
```

```markdown
# Swift Code Review Agent Workflow

When asked to review code:

1. Separate findings into:
   - Must fix
   - Should improve
   - Nice to have
2. Focus on correctness, architecture, concurrency, logging, error handling, tests, and maintainability.
3. Do not nitpick style that SwiftLint can auto-fix unless it affects clarity.
4. For each finding, include:
   - Problem
   - Why it matters
   - Suggested fix
5. Check especially for:
   - `print()`
   - sensitive data in logs (clipboard content, passwords, tokens)
   - force unwrap / force cast
   - swallowed errors
   - magic numbers / strings
   - unstructured concurrency
   - UI updates off MainActor
   - missing tests for changed behavior
   - reverse module dependency
```

```markdown
# Swift Refactoring Agent Workflow

When asked to refactor:

1. Preserve external behavior.
2. Identify refactor goal: readability, testability, architecture, duplication, or performance.
3. Prefer small commits/patches.
4. Do not mix refactor with feature changes unless explicitly requested.
5. Before changing logic-heavy code, identify existing tests or suggest characterization tests.
6. After refactor, explain why behavior is preserved.
```

---

## 3. 代码生成硬规则

### 3.1 绝对禁止

AI 不得生成以下内容：

- `print()` 作为日志。
- 无上下文的错误日志。
- 输出密码、token、验证码、剪贴板原文、敏感个人信息、包含用户名的完整文件路径。
- 空 `catch` 或吞掉错误。
- 无理由的 `try?`。
- 无业务含义说明的魔术数字或魔术字符串。
- 随手使用 `Task.detached`。
- 从非主线程 / 非 `@MainActor` 上下文更新 UI。
- 在未加密状态下持久化存储敏感剪贴板内容。
- 为了测试而污染生产 API。
- 没有断言的测试。
- 只为了覆盖率而执行代码的测试。
- 用 `sleep` 或固定延迟等待异步逻辑。

### 3.2 默认偏好

AI 应默认采用：

- 小步修改。
- 构造器依赖注入。
- 明确错误类型。
- 结构化日志 metadata。
- `@MainActor` 隔离 UI 状态。
- `actor` 或不可变值类型保护并发共享状态。
- 命名常量替代业务魔术值。
- SwiftLint 可检查的代码风格。
- 测试验证行为，不验证实现。

---

## 4. Swift 风格速查

### 4.1 Allman 大括号

```swift
public final class ClipCaptureService
{
    public func processItems()
    {
        guard !items.isEmpty else
        {
            LogCategory.capture.info("No items to process")
            return
        }

        for item in items
        {
            process(item)
        }
    }
}
```

### 4.2 MARK 格式

```swift
// MARK: - Public API

// MARK: - Private Methods
```

### 4.3 import 顺序

```swift
import Foundation
import OSLog
import SwiftUI

import SQLite

import ClipMindModels
```

### 4.4 文件内部组织

```swift
public final class ClassificationService
{
    public typealias Completion = (Result<Void, Error>) -> Void

    public enum State
    {
        case idle
        case loading
        case ready
        case failed(ClipMindError)
    }

    public private(set) var state: State = .idle

    private let llmService: LLMServicing
    private let logger: LogCategory = .classify

    public init(llmService: LLMServicing)
    {
        self.llmService = llmService
    }

    public func classify() async
    {
        // ...
    }

    private func mapError(_ error: Error) -> ClipMindError
    {
        // ...
    }
}
```

---

## 5. 日志规则

### 5.1 正确模式

```swift
LogCategory.classify.error("Classification failed: \(errorCode, privacy: .public)")
```

### 5.2 错误模式

```swift
print("Classification failed: \(error)")
LogCategory.llm.error("Failed")
LogCategory.capture.debug("Clipboard content: \(rawContent)")
```

### 5.3 LogCategory 分类

| 分类 | 用途 |
|---|---|
| `LogCategory.capture` | 剪贴板捕获相关 |
| `LogCategory.classify` | 内容分类相关 |
| `LogCategory.search` | 搜索相关 |
| `LogCategory.llm` | LLM API 调用相关 |
| `LogCategory.storage` | 加密存储相关 |
| `LogCategory.privacy` | 隐私保护相关 |
| `LogCategory.ui` | UI 交互相关 |
| `LogCategory.app` | App 生命周期相关 |

日志子系统：`com.clipmind.app`

---

## 6. 错误处理规则

### 6.1 不要吞错误

```swift
do
{
    try performOperation()
}
catch let error as ClipMindError
{
    LogCategory.storage.error("Operation failed: \(error.localizedDescription, privacy: .public)")
    throw error
}
catch
{
    LogCategory.storage.error("Unexpected error: \(error.localizedDescription, privacy: .public)")
    throw ClipMindError.unknown(underlying: error)
}
```

### 6.2 用户可见错误

用户可见错误应优先提供：

- `errorDescription`
- `failureReason`
- `recoverySuggestion`

```swift
public enum ClipMindError: Error, LocalizedError
{
    case permissionDenied
    case apiTimeout(operation: String)

    public var errorDescription: String?
    {
        switch self
        {
        case .permissionDenied:
            return "Permission denied"
        case .apiTimeout(let operation):
            return "\(operation) timed out"
        }
    }

    public var failureReason: String?
    {
        switch self
        {
        case .permissionDenied:
            return "The app does not have the required permission."
        case .apiTimeout:
            return "The operation took too long to complete."
        }
    }

    public var recoverySuggestion: String?
    {
        switch self
        {
        case .permissionDenied:
            return "Grant permission in System Settings and try again."
        case .apiTimeout:
            return "Please try again later."
        }
    }
}
```

---

## 7. 并发规则

### 7.1 UI 与 MainActor

```swift
@MainActor
public final class HistoryViewModel: ObservableObject
{
    @Published public private(set) var state: State = .idle

    private let searchService: SearchServicing

    public init(searchService: SearchServicing)
    {
        self.searchService = searchService
    }

    public func search(_ query: String) async
    {
        state = .loading

        do
        {
            let results = try await searchService.search(query: query)
            state = .loaded(results)
        }
        catch is CancellationError
        {
            state = .idle
        }
        catch
        {
            state = .failed(error)
        }
    }
}
```

### 7.2 共享可变状态

```swift
public actor ClipStore
{
    private var items: [ClipItem] = []

    public func item(at index: Int) -> ClipItem?
    {
        guard items.indices.contains(index) else { return nil }
        return items[index]
    }

    public func append(_ item: ClipItem)
    {
        items.append(item)
    }
}
```

### 7.3 Task.detached 使用门槛

只有同时满足这些条件才可使用 `Task.detached`：

- 任务确实需要脱离调用者生命周期。
- 不需要继承调用者优先级。
- 不需要继承调用者取消语义。
- 不访问 UI 状态。
- 不访问未同步的共享可变状态。
- 代码注释说明为什么需要 detached。

---

## 8. Trae 单次 Prompt 模板

### 8.1 生成代码

```text
请根据当前项目风格实现以下功能。

要求：
1. 遵守 Swift Project Rules。
2. 使用 Swift 5.7+ / macOS 13.0+ 兼容写法。
3. 使用 Allman 大括号。
4. 不使用 print()，日志必须走 LogCategory，并包含上下文。
5. 不吞错误，必要时映射为项目错误类型。
6. UI 状态更新必须在 MainActor。
7. 不引入魔术数字/字符串。
8. 行为变化需要补测试。
9. 先说明设计思路和受影响文件，再修改代码。

任务：
<描述功能>
```

### 8.2 重构代码

```text
请重构以下代码，目标是提升可读性和可测试性。

约束：
1. 不改变外部行为。
2. 不改变 public API，除非必须并说明原因。
3. 不做无关格式化。
4. 保留现有日志语义，必要时补上下文。
5. 保留错误处理语义，不吞错误。
6. 若发现并发或架构问题，先指出最小修复方案。
7. 重构后说明如何验证行为未改变。

代码/文件：
<粘贴或引用文件>
```

### 8.3 审查代码

```text
请按 Swift Project Rules 审查以下改动。

请按以下格式输出：
1. Must fix
2. Should improve
3. Nice to have
4. 建议执行的验证命令

重点检查：
- SwiftLint 风格
- Allman 大括号
- 命名和文件组织
- 日志是否使用 LogCategory
- 是否泄露敏感信息（剪贴板内容、密码、token）
- 错误是否被吞掉
- 并发是否安全
- UI 是否在 MainActor
- 是否有魔术数字/字符串
- 模块依赖是否反向
- 测试是否覆盖行为变化

代码/ diff：
<粘贴代码或 diff>
```

### 8.4 修复 SwiftLint 问题

```text
请修复当前文件中的 SwiftLint 问题。

要求：
1. 不改变业务行为。
2. 保持 Allman 大括号。
3. 不做无关重构。
4. 修复后列出修改过的规则类型。
5. 如果某条规则不应自动修复，请说明原因。

文件：
<文件路径>
```

### 8.5 修复并发问题

```text
请检查并修复这段 Swift 并发代码。

重点：
1. UI 更新是否在 MainActor。
2. 是否误用 Task.detached。
3. 是否正确传播 CancellationError。
4. 共享可变状态是否安全。
5. 跨并发域类型是否需要 Sendable。
6. 修复时尽量保持 API 不变。

代码：
<代码>
```

---

## 9. AI 自检清单

每次生成或修改 Swift 代码后，AI 必须自检：

| 检查项 | 通过标准 |
|---|---|
| 风格 | Allman 大括号、4 空格、MARK 正确 |
| 命名 | 名称表达意图，无冗余类型后缀 |
| 注释 | public/open API 有文档注释，复杂逻辑有说明 |
| 日志 | 无 `print()`，使用 LogCategory，无敏感信息（剪贴板原文、密码、token） |
| 错误处理 | 无空 `catch`，无无理由 `try?`，错误有上下文 |
| 并发 | UI 在 MainActor，取消可传播，无误用 detached |
| 常量 | 无业务魔术数字/字符串 |
| 架构 | 模块依赖不反向，依赖通过注入传入 |
| 测试 | 行为变化有测试，异步测试不使用 sleep |
| 可维护性 | 修改聚焦，没有无关重写 |

---

## 10. 与原规范的映射

本 Trae 版保留并压缩了原规范中的关键要求：

| 原规范主题 | Trae 版位置 |
|---|---|
| SwiftLint / PR Review / CI | 第 1 节、第 9 节 |
| 注释规范 | 第 1 节、第 9 节 |
| 日志规范与敏感信息保护 | 第 1 节、第 5 节 |
| 命名规范 | 第 1 节、第 4 节 |
| Allman 大括号 | 第 1 节、第 4 节 |
| 魔术数字/字符串 | 第 1 节、第 3 节、第 9 节 |
| 文件组织 | 第 1 节、第 4 节 |
| 错误处理 | 第 1 节、第 6 节 |
| Swift 并发 | 第 1 节、第 7 节 |
| 测试规范 | 第 1 节、第 3 节、第 9 节 |
| 模块架构 | 第 1 节、第 9 节 |
| SwiftLint 推荐配置 | 第 1 节、第 8.4 节 |

---

## 11. 建议的仓库文件布局

可以在仓库中保存为：

```text
.trae/
  rules/
    docs.md
    git-commit-message.md

docs/
  CODING_STANDARDS.md
```

推荐做法：

- `.trae/rules/`：放文档规范和提交规范。
- `docs/CODING_STANDARDS.md`：保留完整长规范，供人工审查和深度上下文使用。

---

## 12. 最小 Project Rules 版本

如果 Trae 规则上下文有限，只放下面这段：

```markdown
This is a Swift 5.7+ macOS 13.0+ project.

Always follow:
- Use Allman braces.
- Use 4 spaces, no tabs.
- No `print()`; use LogCategory with os.Logger (subsystem: com.clipmind.app).
- Never log sensitive data (clipboard content, passwords, tokens, personal info).
- Do not swallow errors; map and log with context.
- UI state updates must be on MainActor.
- Prefer structured concurrency; avoid `Task.detached`.
- Protect shared mutable state with actor or clear synchronization.
- No magic business numbers or strings; use named constants.
- Module dependencies: UI → business → Models/Utils. No reverse dependencies.
- Use initializer dependency injection.
- Add or update tests for behavior changes.
- Tests verify observable behavior, not implementation details.
- Async tests must not use sleep or fixed delays.
- Make small focused changes and avoid unrelated rewrites.
```
