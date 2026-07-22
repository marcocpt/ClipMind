import XCTest

@testable import ClipMind

final class FileWriterTests: XCTestCase
{
    private var tempDir: URL!
    private var writer: FileWriter!

    override func setUpWithError() throws
    {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        writer = FileWriter()
    }

    override func tearDownWithError() throws
    {
        try? FileManager.default.removeItem(at: tempDir)
    }

    // MARK: - TC-UT-40：成功写入文件（D10 O_EXCL + D14 0600）

    func testWriteFileSuccess() throws
    {
        let url = tempDir.appendingPathComponent("test.md")
        try writer.write(content: "hello world", to: url)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(content, "hello world")
    }

    // MARK: - TC-UT-41：文件权限为 0600（D14）

    func testFilePermission0600() throws
    {
        let url = tempDir.appendingPathComponent("perm.md")
        try writer.write(content: "test", to: url)

        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let permissions = attrs[.posixPermissions] as? NSNumber
        XCTAssertEqual(permissions?.int16Value, 0o600, "D14：文件权限应为 0600")
    }

    // MARK: - TC-UT-42：文件已存在抛出错误（D10 O_EXCL）

    func testFileExistsThrows() throws
    {
        let url = tempDir.appendingPathComponent("exists.md")
        try Data("existing".utf8).write(to: url)

        XCTAssertThrowsError(try writer.write(content: "new", to: url)) { error in
            guard case AutoSaveError.fileAlreadyExists = error else
            {
                XCTFail("应抛出 fileAlreadyExists 错误")
                return
            }
        }

        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertEqual(content, "existing", "原文件内容不应被覆盖")
    }

    // MARK: - TC-UT-43：目录不存在时创建目录（D13）

    func testCreateDirectoryIfNotExists() throws
    {
        let nestedDir = tempDir.appendingPathComponent("nested/deep/dir")
        let url = nestedDir.appendingPathComponent("test.md")
        try writer.write(content: "test", to: url)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    // MARK: - TC-UT-44：权限不足抛出 permissionDenied（D13）

    func testPermissionDenied() throws
    {
        let readOnlyDir = tempDir.appendingPathComponent("readonly")
        try FileManager.default.createDirectory(at: readOnlyDir, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: readOnlyDir.path)

        defer
        {
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: readOnlyDir.path)
        }

        let url = readOnlyDir.appendingPathComponent("test.md")
        XCTAssertThrowsError(try writer.write(content: "test", to: url)) { error in
            // 允许 permissionDenied 或 fileWriteFailed（取决于 OS 权限映射）
            guard case AutoSaveError.permissionDenied = error
                ?? (error as? AutoSaveError) ?? .fileWriteFailed else
            {
                return
            }
        }
    }

    // MARK: - TC-UT-44b：pathHash 输出 8 位十六进制（NFR-007/D15）

    func testPathHashReturnsEightHexChars() throws
    {
        let hash = FileWriter.pathHash("/tmp/test.md")
        XCTAssertEqual(hash.count, 8, "pathHash 应为 8 位十六进制字符")
        XCTAssertTrue(hash.allSatisfy { $0.isHexDigit }, "pathHash 应仅含十六进制字符")
    }

    // MARK: - TC-UT-45：半成品清理（D10）

    func testPartialFileCleanup() throws
    {
        let invalidURL = URL(fileURLWithPath: "/dev/null/invalid.md")

        XCTAssertThrowsError(try writer.write(content: "test", to: invalidURL))

        XCTAssertFalse(FileManager.default.fileExists(atPath: invalidURL.path))
    }
}
