@testable import ClipMind
import XCTest

final class SourceAppExtractorTests: XCTestCase
{
    func testExtractFromClips_returnsSortedUniqueSourceAppNames()
    {
        let clips = [
            makeClip(sourceAppName: "Safari"),
            makeClip(sourceAppName: "Xcode"),
            makeClip(sourceAppName: "Notes"),
            makeClip(sourceAppName: "Safari")
        ]
        let result = SourceAppExtractor.extract(from: clips)
        XCTAssertEqual(result, ["Notes", "Safari", "Xcode"])
    }

    func testExtractFromClips_emptyList_returnsEmpty()
    {
        let result = SourceAppExtractor.extract(from: [])
        XCTAssertEqual(result, [])
    }

    func testExtractFromClips_singleSource_returnsSingleName()
    {
        let clips = [makeClip(sourceAppName: "Xcode")]
        let result = SourceAppExtractor.extract(from: clips)
        XCTAssertEqual(result, ["Xcode"])
    }

    func testExtractFromClips_ignoresEmptySourceAppName()
    {
        let clips = [
            makeClip(sourceAppName: "Safari"),
            makeClip(sourceAppName: ""),
            makeClip(sourceAppName: "Xcode")
        ]
        let result = SourceAppExtractor.extract(from: clips)
        XCTAssertEqual(result, ["Safari", "Xcode"])
    }

    func testExtractFromClips_preservesChineseCharacters()
    {
        let clips = [
            makeClip(sourceAppName: "备忘录"),
            makeClip(sourceAppName: "Safari")
        ]
        let result = SourceAppExtractor.extract(from: clips)
        XCTAssertEqual(result.count, 2)
        XCTAssertTrue(result.contains("备忘录"))
        XCTAssertTrue(result.contains("Safari"))
    }

    private func makeClip(sourceAppName: String) -> ClipItem
    {
        ClipItem(
            id: UUID(),
            content: .text("test"),
            contentType: .other,
            sourceApp: "com.test.\(sourceAppName)",
            sourceAppName: sourceAppName,
            timestamp: Date(),
            summary: nil,
            translation: nil,
            rewrite: nil,
            todos: nil,
            embeddings: nil
        )
    }
}
