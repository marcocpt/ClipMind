@testable import ClipMind
import Foundation

// MARK: - 捕获型 Repository

final class CapturingTagRepository: TagRepository
{
    var snapshot: TagSnapshot = .empty
    var appliedMutations: [TagMutation] = []
    var shouldThrow = false
    var migrationResult = TagMigrationBatchResult(migratedCount: 0, remainingCount: 0)

    func loadSnapshot() throws -> TagSnapshot
    {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        return snapshot
    }

    func apply(_ mutation: TagMutation) throws
    {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        appliedMutations.append(mutation)
    }

    func migrateNextBatch(limit: Int) throws -> TagMigrationBatchResult
    {
        if shouldThrow { throw NSError(domain: "test", code: 1) }
        return migrationResult
    }
}

// MARK: - 捕获型 Logger

final class CapturingTagLogger: TagOperationLogging
{
    private(set) var records: [TagLogRecord] = []

    func record(
        operation: TagOperation,
        result: TagOperationResult,
        error: TagError?,
        count: Int
    )
    {
        records.append(
            TagLogRecord(operation: operation, result: result, error: error, count: count)
        )
    }

    func recordedSuccess(for operation: TagOperation, count: Int) -> Bool
    {
        records.contains
        {
            $0.operation == operation && $0.result == .success && $0.count == count
        }
    }

    func recordedFailure(for operation: TagOperation, error: TagError) -> Bool
    {
        records.contains
        {
            $0.operation == operation && $0.result == .failure && $0.error == error
        }
    }

    var renderedLog: String
    {
        records.map
        { record in
            let errorText = record.error?.rawValue ?? "none"
            let operationText = record.operation.rawValue
            let resultText = record.result.rawValue
            return "tag operation=\(operationText) result=\(resultText) error=\(errorText) count=\(record.count)"
        }.joined(separator: "\n")
    }
}

struct TagLogRecord
{
    let operation: TagOperation
    let result: TagOperationResult
    let error: TagError?
    let count: Int
}

// MARK: - 测试夹具

enum TagTestFixture
{
    static func makeClip(contentType: ContentType) -> ClipItem
    {
        ClipItem.makeText(
            "content",
            contentType: contentType,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
    }
}
