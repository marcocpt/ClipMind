import os
import XCTest

@testable import ClipMind

final class LoggerTests: XCTestCase {
    // MARK: - LogCategory rawValue

    func testLogCategoryRawValue() throws {
        XCTAssertEqual(LogCategory.capture.rawValue, "Capture")
        XCTAssertEqual(LogCategory.classify.rawValue, "Classify")
        XCTAssertEqual(LogCategory.search.rawValue, "Search")
        XCTAssertEqual(LogCategory.llm.rawValue, "LLM")
        XCTAssertEqual(LogCategory.storage.rawValue, "Storage")
        XCTAssertEqual(LogCategory.privacy.rawValue, "Privacy")
        XCTAssertEqual(LogCategory.ui.rawValue, "UI")
        XCTAssertEqual(LogCategory.app.rawValue, "App")
    }

    // MARK: - LogCategory.allCases

    func testLogCategoryAllCases() throws {
        XCTAssertEqual(LogCategory.allCases.count, 8, "LogCategory 应有 8 个 case")
        // 验证每个 case 都存在
        let expectedCategories: Set<String> = [
            "Capture", "Classify", "Search", "LLM",
            "Storage", "Privacy", "UI", "App"
        ]
        let actualCategories = Set(LogCategory.allCases.map(\.rawValue))
        XCTAssertEqual(actualCategories, expectedCategories, "应包含全部 8 个分类")
    }

    // MARK: - LogCategory.logger

    func testLogCategoryLogger() throws {
        // 验证每个 case 的 logger 属性返回可用的 os.Logger
        for category in LogCategory.allCases {
            // 调用 logger 属性不应崩溃，且应返回非 nil 的 Logger
            let logger = category.logger
            XCTAssertNotNil(logger, "\(category.rawValue) 的 logger 不应为 nil")
        }
    }

    // MARK: - 日志级别调用不崩溃

    func testLoggerDebug() throws {
        // 调用 debug 不应崩溃
        LogCategory.capture.debug("test debug message")
        LogCategory.app.debug("test debug from app category")
    }

    func testLoggerInfo() throws {
        // 调用 info 不应崩溃
        LogCategory.classify.info("test info message")
        LogCategory.search.info("test info from search category")
    }

    func testLoggerWarning() throws {
        // 调用 warning 不应崩溃
        LogCategory.llm.warning("test warning message")
        LogCategory.storage.warning("test warning from storage category")
    }

    func testLoggerError() throws {
        // 调用 error 不应崩溃
        LogCategory.privacy.error("test error message")
        LogCategory.ui.error("test error from ui category")
    }

    // MARK: - 所有分类的所有级别

    func testAllCategoriesAllLevelsDoNotCrash() throws {
        // 验证所有分类的所有级别组合都不崩溃
        for category in LogCategory.allCases {
            category.debug("debug message for \(category.rawValue)")
            category.info("info message for \(category.rawValue)")
            category.warning("warning message for \(category.rawValue)")
            category.error("error message for \(category.rawValue)")
        }
    }
}
