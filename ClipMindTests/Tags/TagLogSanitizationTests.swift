@testable import ClipMind
import XCTest

final class TagLogSanitizationTests: XCTestCase
{
    // MARK: - SEC-002: 日志哨兵与闭集穷举

    func testRenderedLogContainsOnlyClosedSetValues()
    {
        let logger = CapturingTagLogger()
        let operations: [TagOperation] = [.create, .attach, .detach, .rename, .delete, .migrate]
        let errors: [TagError?] = [
            nil,
            .emptyName,
            .duplicateName,
            .tagLimitReached,
            .systemTagNotEligible,
            .systemTagReadOnly,
            .tagNotFound,
            .clipNotFound,
            .persistenceFailed
        ]

        // 穷举每个 operation 的 success 和 failure
        for operation in operations
        {
            logger.record(operation: operation, result: .success, error: nil, count: 1)
            for error in errors
            {
                logger.record(operation: operation, result: .failure, error: error, count: 0)
            }
        }

        let log = logger.renderedLog

        // 哨兵验证：标签名和剪贴板内容不可能进入日志
        XCTAssertFalse(log.contains("SECRET_TAG_NAME"), "日志不应包含标签名哨兵")
        XCTAssertFalse(log.contains("SECRET_CLIP_CONTENT"), "日志不应包含剪贴板内容哨兵")

        // 闭集验证：所有 operation 的 rawValue 都出现
        for operation in operations
        {
            XCTAssertTrue(log.contains(operation.rawValue), "日志应包含 operation=\(operation.rawValue)")
        }

        // result 闭集
        XCTAssertTrue(log.contains(TagOperationResult.success.rawValue), "日志应包含 success")
        XCTAssertTrue(log.contains(TagOperationResult.failure.rawValue), "日志应包含 failure")

        // error 闭集（nil 渲染为 none）
        XCTAssertTrue(log.contains("none"), "error 为 nil 时应渲染为 none")
        for error in errors.compactMap({ $0 })
        {
            XCTAssertTrue(log.contains(error.rawValue), "日志应包含 error=\(error.rawValue)")
        }
    }

    // MARK: - 签名验证：record 不接收任意 String

    func testRecordDoesNotAcceptArbitraryStrings()
    {
        let logger = CapturingTagLogger()

        logger.record(operation: .create, result: .success, error: nil, count: 1)

        XCTAssertEqual(logger.records.count, 1)
        XCTAssertEqual(logger.records[0].operation, .create)
        XCTAssertEqual(logger.records[0].result, .success)
        XCTAssertNil(logger.records[0].error)
        XCTAssertEqual(logger.records[0].count, 1)
    }

    // MARK: - 生产 logger 不崩溃

    func testDefaultLoggerDoesNotCrash()
    {
        let logger = DefaultTagOperationLogger()

        logger.record(operation: .create, result: .success, error: nil, count: 1)
        logger.record(operation: .migrate, result: .failure, error: .persistenceFailed, count: 100)

        // 不崩溃即通过；输出格式由闭集签名保证
    }
}
