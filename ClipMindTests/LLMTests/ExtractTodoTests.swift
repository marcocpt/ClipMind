@testable import ClipMind
import XCTest

/// 提取待办测试（AC-16）。
///
/// 验证：
/// - 返回结构化任务列表（task + assignee + dueDate）
/// - 多条 fixture 响应均包含有效字段
/// - 解析失败时的错误处理
final class ExtractTodoTests: XCTestCase {
    private var mock: MockLLMService!
    private var fixture: LLMFixture!

    override func setUpWithError() throws {
        mock = MockLLMService()
        fixture = try LLMFixtureLoader.load()
    }

    override func tearDown() {
        mock = nil
        fixture = nil
        super.tearDown()
    }

    // MARK: - AC-16: 提取待办返回结构化任务列表

    func testExtractTodosReturnsStructuredTasks() async throws {
        let fixtureTodos = fixture.responses.extractTodo[0].todos
        let todos = fixtureTodos.map {
            TodoItem(id: UUID(), task: $0.task, assignee: $0.assignee, dueDate: $0.dueDate)
        }
        mock.extractTodosResult = todos

        let result = try await mock.extractTodos(text: "会议纪要文本")

        XCTAssertFalse(result.isEmpty, "应返回非空任务列表")
        for todo in result {
            XCTAssertFalse(todo.task.isEmpty, "每个任务的 task 字段不应为空")
        }
    }

    func testExtractTodosContainsTaskField() async throws {
        let fixtureTodo = fixture.responses.extractTodo[0].todos[0]
        let todo = TodoItem(
            id: UUID(),
            task: fixtureTodo.task,
            assignee: fixtureTodo.assignee,
            dueDate: fixtureTodo.dueDate
        )
        mock.extractTodosResult = [todo]

        let result = try await mock.extractTodos(text: "any")

        XCTAssertEqual(result.first?.task, fixtureTodo.task, "task 字段应正确")
    }

    func testExtractTodosContainsAssigneeField() async throws {
        let fixtureTodo = fixture.responses.extractTodo[0].todos[0]
        let todo = TodoItem(
            id: UUID(),
            task: fixtureTodo.task,
            assignee: fixtureTodo.assignee,
            dueDate: fixtureTodo.dueDate
        )
        mock.extractTodosResult = [todo]

        let result = try await mock.extractTodos(text: "any")

        XCTAssertEqual(result.first?.assignee, "张三", "assignee 字段应正确")
    }

    func testExtractTodosContainsDueDateField() async throws {
        let fixtureTodo = fixture.responses.extractTodo[0].todos[0]
        let todo = TodoItem(
            id: UUID(),
            task: fixtureTodo.task,
            assignee: fixtureTodo.assignee,
            dueDate: fixtureTodo.dueDate
        )
        mock.extractTodosResult = [todo]

        let result = try await mock.extractTodos(text: "any")

        XCTAssertEqual(result.first?.dueDate, "2025-01-15", "dueDate 字段应正确")
    }

    // MARK: - 可选字段（assignee / dueDate 可为 nil）

    func testExtractTodosAllowsNilAssigneeAndDueDate() async throws {
        // 第 3 个 todo 的 assignee 和 dueDate 都是 nil
        let fixtureTodo = fixture.responses.extractTodo[0].todos[2]
        XCTAssertNil(fixtureTodo.assignee, "fixture 中第 3 个 todo 的 assignee 应为 nil")
        XCTAssertNil(fixtureTodo.dueDate, "fixture 中第 3 个 todo 的 dueDate 应为 nil")

        let todo = TodoItem(
            id: UUID(),
            task: fixtureTodo.task,
            assignee: fixtureTodo.assignee,
            dueDate: fixtureTodo.dueDate
        )
        mock.extractTodosResult = [todo]

        let result = try await mock.extractTodos(text: "any")

        XCTAssertNil(result.first?.assignee, "未明确负责人时 assignee 应为 nil")
        XCTAssertNil(result.first?.dueDate, "未明确截止时间时 dueDate 应为 nil")
    }

    // MARK: - 多任务场景

    func testExtractTodosReturnsMultipleTasks() async throws {
        let fixtureTodos = fixture.responses.extractTodo[0].todos
        let todos = fixtureTodos.map {
            TodoItem(id: UUID(), task: $0.task, assignee: $0.assignee, dueDate: $0.dueDate)
        }
        mock.extractTodosResult = todos

        let result = try await mock.extractTodos(text: "会议纪要")

        XCTAssertEqual(result.count, 3, "应返回 3 个任务")
    }

    func testExtractTodosSingleTask() async throws {
        let fixtureTodos = fixture.responses.extractTodo[1].todos
        let todos = fixtureTodos.map {
            TodoItem(id: UUID(), task: $0.task, assignee: $0.assignee, dueDate: $0.dueDate)
        }
        mock.extractTodosResult = todos

        let result = try await mock.extractTodos(text: "聊天记录")

        XCTAssertEqual(result.count, 1, "应返回 1 个任务")
    }

    // MARK: - 解析失败处理

    func testExtractTodosParseErrorWhenJsonInvalid() async {
        mock.extractTodosError = LLMError.parseError("Invalid JSON format")

        do {
            _ = try await mock.extractTodos(text: "any")
            XCTFail("应抛出 parseError")
        } catch let error as LLMError {
            if case .parseError(let message) = error {
                XCTAssertEqual(message, "Invalid JSON format")
            } else {
                XCTFail("应为 parseError")
            }
        } catch {
            XCTFail("应抛出 LLMError")
        }
    }

    func testExtractTodosEmptyResultWhenNoTasksFound() async throws {
        // 无任务时返回空数组
        mock.extractTodosResult = []

        let result = try await mock.extractTodos(text: "这段文本没有待办事项")

        XCTAssertTrue(result.isEmpty, "无任务时应返回空数组")
    }

    // MARK: - 调用参数记录

    func testExtractTodosRecordsInputText() async throws {
        mock.extractTodosResult = []

        _ = try await mock.extractTodos(text: "需要提取待办的文本")

        XCTAssertEqual(mock.extractTodosCalls, ["需要提取待办的文本"])
    }

    // MARK: - 未配置 API Key

    func testExtractTodosThrowsNotConfiguredWhenNoApiKey() async {
        mock.extractTodosError = LLMError.notConfigured

        do {
            _ = try await mock.extractTodos(text: "any")
            XCTFail("应抛出 notConfigured")
        } catch let error as LLMError {
            XCTAssertEqual(error, .notConfigured)
        } catch {
            XCTFail("应抛出 LLMError")
        }
    }
}
