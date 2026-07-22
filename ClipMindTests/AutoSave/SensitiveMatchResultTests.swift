import XCTest

@testable import ClipMind

final class SensitiveMatchResultTests: XCTestCase
{
    // MARK: - TC-UT-07：非敏感结果

    func testNonSensitiveResult() throws
    {
        let result = SensitiveMatchResult(isSensitive: false, matchedPatterns: [])
        XCTAssertFalse(result.isSensitive)
        XCTAssertTrue(result.matchedPatterns.isEmpty)
    }

    // MARK: - TC-UT-08：敏感结果携带命中模式

    func testSensitiveResultWithPatterns() throws
    {
        let result = SensitiveMatchResult(
            isSensitive: true,
            matchedPatterns: ["password", "token"]
        )
        XCTAssertTrue(result.isSensitive)
        XCTAssertEqual(result.matchedPatterns.count, 2)
        XCTAssertEqual(result.matchedPatterns[0], "password")
    }

    // MARK: - TC-UT-09：Equatable 相等比较

    func testEquality() throws
    {
        let lhs = SensitiveMatchResult(isSensitive: true, matchedPatterns: ["password"])
        let rhs = SensitiveMatchResult(isSensitive: true, matchedPatterns: ["password"])
        XCTAssertEqual(lhs, rhs)
    }

    // MARK: - TC-UT-10：Equatable 不等比较

    func testInequality() throws
    {
        let lhs = SensitiveMatchResult(isSensitive: true, matchedPatterns: ["password"])
        let rhs = SensitiveMatchResult(isSensitive: false, matchedPatterns: [])
        XCTAssertNotEqual(lhs, rhs)
    }
}
