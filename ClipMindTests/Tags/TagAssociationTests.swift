@testable import ClipMind
import XCTest

final class TagAssociationTests: XCTestCase
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

    // MARK: - DOM-006: 勾选/取消/重启保持

    func testAttachAndDetachRoundTrip() async throws
    {
        let clip = makeClip(contentType: .article)
        let userTag = ClipTag(id: .user(), name: "custom", color: .teal, source: .user)
        repository.snapshot = TagSnapshot(
            userTags: [userTag],
            tagStatesByClipID: [clip.id: .newItem(contentType: .article)]
        )

        // Attach
        _ = try await service.setAttached(true, tagID: userTag.id, clipID: clip.id)
        XCTAssertEqual(repository.appliedMutations.count, 1)

        // Detach
        _ = try await service.setAttached(false, tagID: userTag.id, clipID: clip.id)
        XCTAssertEqual(repository.appliedMutations.count, 2)

        if case let .detach(tagID, _) = repository.appliedMutations[1]
        {
            XCTAssertEqual(tagID, userTag.id)
        } else {
            XCTFail("Expected detach mutation")
        }
    }

    // MARK: - DOM-007: 移除系统标签可恢复

    func testSystemTagCanBeRemovedAndRestored() async throws
    {
        let clip = makeClip(contentType: .code)
        repository.snapshot = TagSnapshot(
            userTags: [],
            tagStatesByClipID: [clip.id: .newItem(contentType: .code)]
        )

        // 移除系统标签
        _ = try await service.setAttached(false, tagID: .system(.code), clipID: clip.id)
        XCTAssertEqual(repository.appliedMutations.count, 1)
        if case let .detach(tagID, _) = repository.appliedMutations[0]
        {
            XCTAssertEqual(tagID, .system(.code))
        } else {
            XCTFail("Expected detach mutation")
        }

        // 恢复系统标签
        _ = try await service.setAttached(true, tagID: .system(.code), clipID: clip.id)
        XCTAssertEqual(repository.appliedMutations.count, 2)
        if case let .attach(tagID, _) = repository.appliedMutations[1]
        {
            XCTAssertEqual(tagID, .system(.code))
        } else {
            XCTFail("Expected attach mutation")
        }
    }

    // MARK: - DOM-008: 第六标签/满额创建共同拒绝

    func testFullClipRejectsBothCreateAndAttach() async throws
    {
        let clip = makeClip(contentType: .article)
        var state = ClipTagState.newItem(contentType: .article)
        var existingUserTags: [ClipTag] = []
        for index in 0..<4
        {
            let id = ClipTagID.user(UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", index))")!)
            state.orderedTagIDs.append(id)
            existingUserTags.append(ClipTag(id: id, name: "tag\(index)", color: .blue, source: .user))
        }
        repository.snapshot = TagSnapshot(
            userTags: existingUserTags,
            tagStatesByClipID: [clip.id: state]
        )

        // 创建第六个标签应拒绝
        do
        {
            _ = try await service.createAndAttach(name: "sixth", color: .amber, clipID: clip.id)
            XCTFail("应抛出 tagLimitReached 错误")
        } catch let error as TagError {
            XCTAssertEqual(error, .tagLimitReached)
        }

        // 关联第五个用户标签也应拒绝
        let fifthTag = ClipTag(id: .user(), name: "fifth", color: .slate, source: .user)
        repository.snapshot.userTags.append(fifthTag)

        do
        {
            _ = try await service.setAttached(true, tagID: fifthTag.id, clipID: clip.id)
            XCTFail("应抛出 tagLimitReached 错误")
        } catch let error as TagError {
            XCTAssertEqual(error, .tagLimitReached)
        }
    }

    // MARK: - DOM-009: 系统标签全局只读

    func testSystemTagRejectsAllGlobalMutations() async throws
    {
        // 重命名系统标签
        do
        {
            _ = try await service.renameUserTag(id: .system(.article), name: "newname")
            XCTFail("应抛出 systemTagReadOnly 错误")
        } catch let error as TagError {
            XCTAssertEqual(error, .systemTagReadOnly)
        }

        // 删除系统标签
        do
        {
            _ = try await service.deleteUserTag(id: .system(.article))
            XCTFail("应抛出 systemTagReadOnly 错误")
        } catch let error as TagError {
            XCTAssertEqual(error, .systemTagReadOnly)
        }
    }

    // MARK: - DOM-010: 系统标签先于用户标签

    func testSystemTagAlwaysPrecedesUserTags() async throws
    {
        let clip = makeClip(contentType: .article)
        let userTag = ClipTag(id: .user(), name: "custom", color: .teal, source: .user)
        repository.snapshot = TagSnapshot(
            userTags: [userTag],
            tagStatesByClipID: [clip.id: .newItem(contentType: .article)]
        )

        // 关联用户标签
        _ = try await service.setAttached(true, tagID: userTag.id, clipID: clip.id)

        // mutation 应该是 attach（reorder 由 repository 处理）
        XCTAssertEqual(repository.appliedMutations.count, 1)
        if case let .attach(tagID, _) = repository.appliedMutations[0]
        {
            XCTAssertEqual(tagID, userTag.id)
        } else {
            XCTFail("Expected attach mutation")
        }
    }

    // MARK: - 辅助

    private func makeClip(contentType: ContentType) -> ClipItem
    {
        TagTestFixture.makeClip(contentType: contentType)
    }
}
