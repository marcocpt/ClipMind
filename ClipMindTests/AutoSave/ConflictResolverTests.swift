import XCTest

@testable import ClipMind

final class ConflictResolverTests: XCTestCase
{
    private var tempDir: URL!

    override func setUpWithError() throws
    {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws
    {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - TC-UT-36：无冲突时返回原文件名

    func testNoConflictReturnsOriginal() throws
    {
        let resolver = ConflictResolver()
        let url = tempDir.appendingPathComponent("hello.md")
        let resolved = try resolver.resolve(url)
        XCTAssertEqual(resolved.lastPathComponent, "hello.md")
    }

    // MARK: - TC-UT-37：冲突时追加数字后缀（分隔符 `-`，与 FR-007 一致）

    func testConflictAppendsNumberSuffix() throws
    {
        let resolver = ConflictResolver()
        let url = tempDir.appendingPathComponent("hello.md")
        try Data("existing".utf8).write(to: url)

        let resolved = try resolver.resolve(url)
        XCTAssertEqual(resolved.lastPathComponent, "hello-1.md")
    }

    // MARK: - TC-UT-38：多次冲突递增

    func testMultipleConflictsIncrement() throws
    {
        let resolver = ConflictResolver()
        let url = tempDir.appendingPathComponent("hello.md")
        try Data("1".utf8).write(to: url)
        try Data("2".utf8).write(to: tempDir.appendingPathComponent("hello-1.md"))
        try Data("3".utf8).write(to: tempDir.appendingPathComponent("hello-2.md"))

        let resolved = try resolver.resolve(url)
        XCTAssertEqual(resolved.lastPathComponent, "hello-3.md")
    }

    // MARK: - TC-UT-39：超过最大次数抛出错误

    func testExceedMaxThrowsError() throws
    {
        let resolver = ConflictResolver(maxAttempts: 3)
        let url = tempDir.appendingPathComponent("hello.md")
        try Data("0".utf8).write(to: url)
        try Data("1".utf8).write(to: tempDir.appendingPathComponent("hello-1.md"))
        try Data("2".utf8).write(to: tempDir.appendingPathComponent("hello-2.md"))
        try Data("3".utf8).write(to: tempDir.appendingPathComponent("hello-3.md"))

        XCTAssertThrowsError(try resolver.resolve(url)) { error in
            guard case AutoSaveError.fileNameConflictExhausted = error else
            {
                XCTFail("应抛出 fileNameConflictExhausted 错误")
                return
            }
        }
    }
}
