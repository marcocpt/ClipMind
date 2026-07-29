@testable import ClipMind
import SQLite
import XCTest

final class EncryptedTagStoreTests: XCTestCase
{
    private var dbPath: URL!
    private var store: EncryptedStore!

    override func setUpWithError() throws
    {
        dbPath = try TestDatabaseHelper.makeTempDBPath(suffix: "_tags")
        store = try EncryptedStore(
            dbPath: dbPath,
            key: TestDatabaseHelper.makeTestKey()
        )
    }

    override func tearDownWithError() throws
    {
        store = nil
        if let dbPath
        {
            TestDatabaseHelper.cleanup(at: dbPath)
        }
        dbPath = nil
    }

    // MARK: - SEC-001: 用户标签目录加密持久化

    func testUserTagCatalogBytesAreEncrypted() throws
    {
        let tagName = "SECRET_USER_TAG_NAME"
        let tag = ClipTag(
            id: .user(),
            name: tagName,
            color: .rose,
            source: .user
        )
        let clip = ClipItem.makeText(
            "content",
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        try store.save(clip)
        try store.apply(.createAndAttach(tag: tag, clipID: clip.id))

        // 直接读取 catalog 表的 value_blob，检查密文不含明文
        let connection = try Connection(dbPath.path)
        let table = Table("tag_catalog")
        let valueBlob = Expression<Data>("value_blob")
        let rows = try connection.prepare(table.select(valueBlob))
        for row in rows
        {
            let blob = row[valueBlob]
            XCTAssertFalse(
                blob.range(of: Data(tagName.utf8)) != nil,
                "加密目录 blob 不应包含标签名明文"
            )
            XCTAssertFalse(
                blob.range(of: Data("rose".utf8)) != nil,
                "加密目录 blob 不应包含颜色 rawValue 明文"
            )
            XCTAssertFalse(
                blob.range(of: Data("\"source\":\"user\"".utf8)) != nil,
                "加密目录 blob 不应包含来源 JSON 明文"
            )
        }
    }

    // MARK: - DOM-005: loadSnapshot 字段完整相等

    func testLoadSnapshotReturnsCompleteFields() throws
    {
        let tag = ClipTag(
            id: .user(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!),
            name: "重要",
            color: .amber,
            source: .user
        )
        let clipID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let clip = ClipItem(
            id: clipID,
            content: .text("content"),
            contentType: .other,
            sourceApp: "com.test",
            sourceAppName: "Test",
            timestamp: Date(),
            summary: nil,
            translation: nil,
            rewrite: nil,
            todos: nil,
            embeddings: nil,
            isSample: false,
            tagState: .newItem(contentType: .other)
        )
        try store.save(clip)
        try store.apply(.createAndAttach(tag: tag, clipID: clipID))

        let snapshot = try store.loadSnapshot()

        XCTAssertEqual(snapshot.userTags.count, 1)
        XCTAssertEqual(snapshot.userTags.first?.id, tag.id)
        XCTAssertEqual(snapshot.userTags.first?.name, "重要")
        XCTAssertEqual(snapshot.userTags.first?.color, .amber)
        XCTAssertEqual(snapshot.userTags.first?.source, .user)

        let state = snapshot.tagStatesByClipID[clipID]
        XCTAssertEqual(state?.orderedTagIDs, [.system(.other), tag.id])
        XCTAssertEqual(state?.systemTagDisposition, .associated)
    }

    // MARK: - DOM-006: createAndAttach 原子事务

    func testCreateAndAttachRollsBackOnClipUpdateFailure() throws
    {
        // 通过 SQLite trigger 让 clips 表 UPDATE 失败
        let connection = try Connection(dbPath.path)
        try connection.run(
            "CREATE TRIGGER block_clip_update BEFORE UPDATE ON clips BEGIN SELECT RAISE(ABORT, 'blocked'); END"
        )

        let tag = ClipTag(
            id: .user(),
            name: "rollback",
            color: .cyan,
            source: .user
        )
        let clip = ClipItem.makeText(
            "content",
            contentType: .article,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        try store.save(clip)

        XCTAssertThrowsError(try store.apply(.createAndAttach(tag: tag, clipID: clip.id))) { _ in }

        // 目录不应保留这个标签（事务回滚）
        let snapshot = try? store.loadSnapshot()
        XCTAssertNotNil(snapshot)
        XCTAssertTrue(snapshot?.userTags.isEmpty ?? true, "回滚后目录不应包含失败标签")

        try connection.run("DROP TRIGGER block_clip_update")
    }

    // MARK: - DOM-007: delete 在一个事务内删除目录项和所有条目关联

    func testDeleteRemovesCatalogEntryAndAllAssociations() throws
    {
        let tag = ClipTag(
            id: .user(UUID(uuidString: "00000000-0000-0000-0000-000000000003")!),
            name: "todelete",
            color: .blue,
            source: .user
        )
        let clip1 = ClipItem.makeText(
            "c1",
            contentType: .article,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        let clip2 = ClipItem.makeText(
            "c2",
            contentType: .code,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        try store.save(clip1)
        try store.save(clip2)
        try store.apply(.createAndAttach(tag: tag, clipID: clip1.id))
        try store.apply(.attach(tagID: tag.id, clipID: clip2.id))

        try store.apply(.delete(tagID: tag.id))

        let snapshot = try store.loadSnapshot()
        XCTAssertTrue(snapshot.userTags.isEmpty, "目录中不应保留已删除标签")

        let state1 = snapshot.tagStatesByClipID[clip1.id]
        let state2 = snapshot.tagStatesByClipID[clip2.id]
        XCTAssertFalse(state1?.orderedTagIDs.contains(tag.id) ?? false, "clip1 不应保留已删除标签")
        XCTAssertFalse(state2?.orderedTagIDs.contains(tag.id) ?? false, "clip2 不应保留已删除标签")
    }

    // MARK: - DOM-008: rename 保持 ID/关联/顺序

    func testRenamePreservesAssociationsAndOrder() throws
    {
        let tag = ClipTag(
            id: .user(UUID(uuidString: "00000000-0000-0000-0000-000000000004")!),
            name: "oldname",
            color: .emerald,
            source: .user
        )
        let clip = ClipItem.makeText(
            "content",
            contentType: .article,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        try store.save(clip)
        try store.apply(.createAndAttach(tag: tag, clipID: clip.id))

        try store.apply(.rename(tagID: tag.id, name: "newname"))

        let snapshot = try store.loadSnapshot()
        XCTAssertEqual(snapshot.userTags.first?.id, tag.id, "rename 后 ID 不变")
        XCTAssertEqual(snapshot.userTags.first?.name, "newname")
        XCTAssertEqual(snapshot.userTags.first?.color, .emerald, "rename 后颜色不变")

        let state = snapshot.tagStatesByClipID[clip.id]
        XCTAssertEqual(state?.orderedTagIDs, [.system(.article), tag.id], "rename 后关联和顺序保持")
    }

    // MARK: - DOM-009: attach/detach 更新 systemTagDisposition，重启后保持

    func testDetachSystemTagUpdatesDispositionAndPersists() throws
    {
        let clip = ClipItem.makeText(
            "content",
            contentType: .code,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        try store.save(clip)

        try store.apply(.detach(tagID: .system(.code), clipID: clip.id))

        // 重新打开 store 模拟重启
        let reopened = try EncryptedStore(
            dbPath: dbPath,
            key: TestDatabaseHelper.makeTestKey()
        )
        let snapshot = try reopened.loadSnapshot()
        let state = snapshot.tagStatesByClipID[clip.id]
        XCTAssertEqual(state?.systemTagDisposition, .removed, "重启后 systemTagDisposition 保持 removed")
        XCTAssertFalse(state?.orderedTagIDs.contains(.system(.code)) ?? true, "重启后系统标签不关联")
    }

    func testReattachSystemTagRestoresAssociation() throws
    {
        let clip = ClipItem.makeText(
            "content",
            contentType: .code,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        try store.save(clip)
        try store.apply(.detach(tagID: .system(.code), clipID: clip.id))
        try store.apply(.attach(tagID: .system(.code), clipID: clip.id))

        let snapshot = try store.loadSnapshot()
        let state = snapshot.tagStatesByClipID[clip.id]
        XCTAssertEqual(state?.systemTagDisposition, .associated)
        XCTAssertEqual(state?.orderedTagIDs.first, .system(.code))
    }

    // MARK: - DOM-010: 标签事务与内容更新并发不回滚标签

    func testContentUpdatePreservesLatestTagState() throws
    {
        let clip = ClipItem.makeText(
            "original",
            contentType: .article,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        try store.save(clip)

        // 模拟连接 A：完成标签 mutation
        let tag = ClipTag(
            id: .user(UUID(uuidString: "00000000-0000-0000-0000-000000000005")!),
            name: "connA",
            color: .purple,
            source: .user
        )
        try store.apply(.createAndAttach(tag: tag, clipID: clip.id))

        // 模拟连接 B：用 mutation 前的旧 ClipItem 更新内容/摘要
        var staleClip = clip
        staleClip = ClipItem(
            id: staleClip.id,
            content: .text("modified by connB"),
            contentType: staleClip.contentType,
            sourceApp: staleClip.sourceApp,
            sourceAppName: staleClip.sourceAppName,
            timestamp: staleClip.timestamp,
            summary: "new summary",
            translation: staleClip.translation,
            rewrite: staleClip.rewrite,
            todos: staleClip.todos,
            embeddings: staleClip.embeddings
        )
        try store.update(staleClip)

        // 最终：内容更新成功，但 tag ID/顺序/disposition 保持连接 A 的最新值
        let loaded = try store.loadAll()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].tagState.orderedTagIDs, [.system(.article), tag.id])
        XCTAssertEqual(loaded[0].tagState.systemTagDisposition, .associated)

        if case .text(let text) = loaded[0].content
        {
            XCTAssertEqual(text, "modified by connB")
        } else {
            XCTFail("Expected text content")
        }
        XCTAssertEqual(loaded[0].summary, "new summary")
    }

    // MARK: - 系统标签先于用户标签，用户标签稳定关联顺序

    func testSystemTagPrecedesUserTagsAndUserOrderIsStable() throws
    {
        let clip = ClipItem.makeText(
            "content",
            contentType: .article,
            sourceApp: "com.test",
            sourceAppName: "Test"
        )
        try store.save(clip)

        let tag1 = ClipTag(
            id: .user(UUID(uuidString: "00000000-0000-0000-0000-000000000006")!),
            name: "first",
            color: .teal,
            source: .user
        )
        let tag2 = ClipTag(
            id: .user(UUID(uuidString: "00000000-0000-0000-0000-000000000007")!),
            name: "second",
            color: .slate,
            source: .user
        )
        try store.apply(.createAndAttach(tag: tag1, clipID: clip.id))
        try store.apply(.createAndAttach(tag: tag2, clipID: clip.id))

        let snapshot = try store.loadSnapshot()
        let state = snapshot.tagStatesByClipID[clip.id]
        XCTAssertEqual(
            state?.orderedTagIDs,
            [.system(.article), tag1.id, tag2.id],
            "系统标签第一，用户标签按关联顺序稳定"
        )
    }

    // MARK: - 空快照

    func testEmptySnapshotWhenNoUserTags() throws
    {
        let snapshot = try store.loadSnapshot()
        XCTAssertTrue(snapshot.userTags.isEmpty)
        XCTAssertTrue(snapshot.tagStatesByClipID.isEmpty)
    }
}
