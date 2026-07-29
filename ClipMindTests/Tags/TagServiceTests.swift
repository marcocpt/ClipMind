@testable import ClipMind
import XCTest

final class TagServiceTests: XCTestCase
{
    private var repository: CapturingTagRepository!
    private var logger: CapturingTagLogger!
    private var service: TagService!

    override func setUp()
    {
        repository = CapturingTagRepository()
        logger = CapturingTagLogger()
        service = TagService(repository: repository, logger: logger)
    }

    // MARK: - DOM-002: trim 后空名称拒绝

    func testCreateRejectsEmptyName() async throws
    {
        let clip = makeClip(contentType: .article)

        do
        {
            _ = try await service.createAndAttach(name: "   ", color: .blue, clipID: clip.id)
            XCTFail("应抛出 emptyName 错误")
        } catch let error as TagError {
            XCTAssertEqual(error, .emptyName)
        }

        XCTAssertTrue(repository.appliedMutations.isEmpty, "空名称不应产生 mutation")
        XCTAssertTrue(logger.recordedFailure(for: .create, error: .emptyName))
    }

    // MARK: - DOM-003: 与系统标签大小写不敏感重名拒绝

    func testCreateRejectsCaseInsensitiveDuplicateWithSystemTag() async throws
    {
        let clip = makeClip(contentType: .article)
        repository.snapshot = TagSnapshot(
            userTags: [],
            tagStatesByClipID: [clip.id: .newItem(contentType: .article)]
        )

        do
        {
            _ = try await service.createAndAttach(name: "code", color: .blue, clipID: clip.id)
            XCTFail("应抛出 duplicateName 错误")
        } catch let error as TagError {
            XCTAssertEqual(error, .duplicateName)
        }

        XCTAssertTrue(repository.appliedMutations.isEmpty)
        XCTAssertTrue(logger.recordedFailure(for: .create, error: .duplicateName))
    }

    // MARK: - DOM-003: 与用户标签大小写不敏感重名拒绝

    func testCreateRejectsCaseInsensitiveDuplicateWithUserTag() async throws
    {
        let clip = makeClip(contentType: .article)
        let existingTag = ClipTag(id: .user(), name: "Important", color: .amber, source: .user)
        repository.snapshot = TagSnapshot(
            userTags: [existingTag],
            tagStatesByClipID: [clip.id: .newItem(contentType: .article)]
        )

        do
        {
            _ = try await service.createAndAttach(name: "IMPORTANT", color: .blue, clipID: clip.id)
            XCTFail("应抛出 duplicateName 错误")
        } catch let error as TagError {
            XCTAssertEqual(error, .duplicateName)
        }
    }

    // MARK: - DOM-004: 第六个标签拒绝

    func testCreateRejectsSixthTag() async throws
    {
        let clip = makeClip(contentType: .article)
        var state = ClipTagState.newItem(contentType: .article)
        // 添加 4 个用户标签，加上系统标签共 5 个
        for index in 0..<4
        {
            let suffix = String(format: "%012d", index)
            let idString = "00000000-0000-0000-0000-\(suffix)"
            state.orderedTagIDs.append(.user(UUID(uuidString: idString)!))
        }
        let existingUserTags = state.orderedTagIDs.filter { SystemTagCatalog.contentType(for: $0) == nil }
            .map { ClipTag(id: $0, name: "tag\($0.rawValue.suffix(1))", color: .blue, source: .user) }

        repository.snapshot = TagSnapshot(
            userTags: existingUserTags,
            tagStatesByClipID: [clip.id: state]
        )

        do
        {
            _ = try await service.createAndAttach(name: "sixth", color: .blue, clipID: clip.id)
            XCTFail("应抛出 tagLimitReached 错误")
        } catch let error as TagError {
            XCTAssertEqual(error, .tagLimitReached)
        }
    }

    // MARK: - DOM-005: 成功创建并关联

    func testCreateSucceedsAndAttaches() async throws
    {
        let clip = makeClip(contentType: .article)
        repository.snapshot = TagSnapshot(
            userTags: [],
            tagStatesByClipID: [clip.id: .newItem(contentType: .article)]
        )

        let snapshot = try await service.createAndAttach(
            name: "重要",
            color: .amber,
            clipID: clip.id
        )

        XCTAssertEqual(repository.appliedMutations.count, 1)
        if case let .createAndAttach(tag, attachedClipID) = repository.appliedMutations[0]
        {
            XCTAssertEqual(tag.name, "重要")
            XCTAssertEqual(tag.color, .amber)
            XCTAssertEqual(tag.source, .user)
            XCTAssertEqual(attachedClipID, clip.id)
        } else {
            XCTFail("Expected createAndAttach mutation")
        }

        XCTAssertTrue(logger.recordedSuccess(for: .create, count: 1))
        XCTAssertEqual(snapshot.userTags.count, 0, "snapshot 来自 repository 重新读取")
    }

    // MARK: - DOM-006: CODE 条目只能恢复 CODE，不能关联 LINK

    func testAttachRejectsNonMatchingSystemTag() async throws
    {
        let clip = makeClip(contentType: .code)
        repository.snapshot = TagSnapshot(
            userTags: [],
            tagStatesByClipID: [clip.id: .newItem(contentType: .code)]
        )

        do
        {
            _ = try await service.setAttached(true, tagID: .system(.link), clipID: clip.id)
            XCTFail("应抛出 systemTagNotEligible 错误")
        } catch let error as TagError {
            XCTAssertEqual(error, .systemTagNotEligible)
        }
    }

    // MARK: - DOM-009: 系统标签拒绝全局重命名

    func testRenameRejectsSystemTag() async throws
    {
        do
        {
            _ = try await service.renameUserTag(id: .system(.code), name: "newname")
            XCTFail("应抛出 systemTagReadOnly 错误")
        } catch let error as TagError {
            XCTAssertEqual(error, .systemTagReadOnly)
        }
    }

    // MARK: - DOM-009: 系统标签拒绝全局删除

    func testDeleteRejectsSystemTag() async throws
    {
        do
        {
            _ = try await service.deleteUserTag(id: .system(.code))
            XCTFail("应抛出 systemTagReadOnly 错误")
        } catch let error as TagError {
            XCTAssertEqual(error, .systemTagReadOnly)
        }
    }

    // MARK: - DOM-008: 重命名保持 ID/关联/顺序

    func testRenamePreservesAssociations() async throws
    {
        let tag = ClipTag(id: .user(), name: "oldname", color: .emerald, source: .user)
        repository.snapshot = TagSnapshot(
            userTags: [tag],
            tagStatesByClipID: [:]
        )

        _ = try await service.renameUserTag(id: tag.id, name: "newname")

        XCTAssertEqual(repository.appliedMutations.count, 1)
        if case let .rename(tagID, name) = repository.appliedMutations[0]
        {
            XCTAssertEqual(tagID, tag.id)
            XCTAssertEqual(name, "newname")
        } else {
            XCTFail("Expected rename mutation")
        }
    }

    // MARK: - DOM-008: 重命名排除自身

    func testRenameExcludesSelf() async throws
    {
        let tag = ClipTag(id: .user(), name: "samename", color: .blue, source: .user)
        repository.snapshot = TagSnapshot(
            userTags: [tag],
            tagStatesByClipID: [:]
        )

        _ = try await service.renameUserTag(id: tag.id, name: "SAMENAME")

        XCTAssertEqual(repository.appliedMutations.count, 1, "重命名时排除自身，不应拒绝")
    }

    // MARK: - DOM-010: 系统标签先于用户标签，用户标签稳定关联顺序

    func testAttachUserTagKeepsSystemTagFirst() async throws
    {
        let clip = makeClip(contentType: .article)
        let userTag = ClipTag(id: .user(), name: "custom", color: .teal, source: .user)
        repository.snapshot = TagSnapshot(
            userTags: [userTag],
            tagStatesByClipID: [clip.id: .newItem(contentType: .article)]
        )

        _ = try await service.setAttached(true, tagID: userTag.id, clipID: clip.id)

        XCTAssertEqual(repository.appliedMutations.count, 1)
        if case let .attach(tagID, attachedClipID) = repository.appliedMutations[0]
        {
            XCTAssertEqual(tagID, userTag.id)
            XCTAssertEqual(attachedClipID, clip.id)
        } else {
            XCTFail("Expected attach mutation")
        }
    }

    // MARK: - DOM-010: 取消关联无需确认

    func testDetachSucceeds() async throws
    {
        let clip = makeClip(contentType: .article)
        let userTag = ClipTag(id: .user(), name: "custom", color: .teal, source: .user)
        var state = ClipTagState.newItem(contentType: .article)
        state.orderedTagIDs.append(userTag.id)
        repository.snapshot = TagSnapshot(
            userTags: [userTag],
            tagStatesByClipID: [clip.id: state]
        )

        _ = try await service.setAttached(false, tagID: userTag.id, clipID: clip.id)

        XCTAssertEqual(repository.appliedMutations.count, 1)
        if case let .detach(tagID, detachedClipID) = repository.appliedMutations[0]
        {
            XCTAssertEqual(tagID, userTag.id)
            XCTAssertEqual(detachedClipID, clip.id)
        } else {
            XCTFail("Expected detach mutation")
        }
    }

    // MARK: - DOM-010: 重命名不存在标签拒绝

    func testRenameRejectsUnknownTag() async throws
    {
        repository.snapshot = TagSnapshot.empty

        do
        {
            _ = try await service.renameUserTag(id: .user(), name: "newname")
            XCTFail("应抛出 tagNotFound 错误")
        } catch let error as TagError {
            XCTAssertEqual(error, .tagNotFound)
        }
    }

    // MARK: - DOM-010: 删除不存在标签拒绝

    func testDeleteRejectsUnknownTag() async throws
    {
        repository.snapshot = TagSnapshot.empty

        do
        {
            _ = try await service.deleteUserTag(id: .user())
            XCTFail("应抛出 tagNotFound 错误")
        } catch let error as TagError {
            XCTAssertEqual(error, .tagNotFound)
        }
    }

    // MARK: - DOM-010: attach 不存在的条目拒绝

    func testAttachRejectsUnknownClip() async throws
    {
        let userTag = ClipTag(id: .user(), name: "custom", color: .teal, source: .user)
        repository.snapshot = TagSnapshot(
            userTags: [userTag],
            tagStatesByClipID: [:]
        )

        do
        {
            _ = try await service.setAttached(true, tagID: userTag.id, clipID: UUID())
            XCTFail("应抛出 clipNotFound 错误")
        } catch let error as TagError {
            XCTAssertEqual(error, .clipNotFound)
        }
    }

    // MARK: - DOM-010: 底层错误映射为 persistenceFailed

    func testRepositoryErrorMapsToPersistenceFailed() async throws
    {
        repository.shouldThrow = true
        repository.snapshot = TagSnapshot.empty

        do
        {
            _ = try await service.snapshot()
            XCTFail("应抛出 persistenceFailed 错误")
        } catch let error as TagError {
            XCTAssertEqual(error, .persistenceFailed)
        }
    }

    // MARK: - 辅助

    private func makeClip(contentType: ContentType) -> ClipItem
    {
        TagTestFixture.makeClip(contentType: contentType)
    }
}
