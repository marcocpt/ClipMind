@testable import ClipMind
import XCTest

final class LocalEmbeddingServiceTests: XCTestCase {
    private var service: LocalEmbeddingService!

    override func setUp() {
        super.setUp()
        service = LocalEmbeddingService()
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    // MARK: - embed

    func testEmbedReturnsNonEmptyVector() {
        let vector = service.embed("Hello world")
        XCTAssertNotNil(vector)
        XCTAssertFalse(vector!.isEmpty)
    }

    func testEmbedSameTextReturnsSimilarVector() {
        let text = "SwiftUI is a modern UI framework"
        let vectorA = service.embed(text)
        let vectorB = service.embed(text)
        XCTAssertNotNil(vectorA)
        XCTAssertNotNil(vectorB)
        let similarity = LocalEmbeddingService.cosineSimilarity(vectorA!, vectorB!)
        XCTAssertEqual(similarity, 1.0, accuracy: 0.01)
    }

    func testEmbedSimilarTextsReturnHighSimilarity() {
        let vectorA = service.embed("How to fix a bug in Swift")
        let vectorB = service.embed("How to debug Swift code")
        XCTAssertNotNil(vectorA)
        XCTAssertNotNil(vectorB)
        let similarity = LocalEmbeddingService.cosineSimilarity(vectorA!, vectorB!)
        XCTAssertGreaterThan(similarity, 0.5)
    }

    func testEmbedDifferentTextsReturnLowSimilarity() {
        let vectorA = service.embed("func viewDidLoad() { super.viewDidLoad() }")
        let vectorB = service.embed("https://www.apple.com/swift")
        XCTAssertNotNil(vectorA)
        XCTAssertNotNil(vectorB)
        let similarity = LocalEmbeddingService.cosineSimilarity(vectorA!, vectorB!)
        XCTAssertLessThan(similarity, 0.8)
    }

    func testEmbedEmptyStringReturnsNil() {
        let vector = service.embed("")
        XCTAssertNil(vector)
    }

    func testEmbedWhitespaceOnlyReturnsNil() {
        let vector = service.embed("   ")
        XCTAssertNil(vector)
    }

    // MARK: - cosineSimilarity

    func testCosineSimilarityIdenticalVectors() {
        let vector = [1.0, 2.0, 3.0]
        let similarity = LocalEmbeddingService.cosineSimilarity(vector, vector)
        XCTAssertEqual(similarity, 1.0, accuracy: 0.001)
    }

    func testCosineSimilarityOrthogonalVectors() {
        let vectorA = [1.0, 0.0]
        let vectorB = [0.0, 1.0]
        let similarity = LocalEmbeddingService.cosineSimilarity(vectorA, vectorB)
        XCTAssertEqual(similarity, 0.0, accuracy: 0.001)
    }

    func testCosineSimilarityDifferentLengthReturnsZero() {
        let vectorA = [1.0, 2.0, 3.0]
        let vectorB = [1.0, 2.0]
        let similarity = LocalEmbeddingService.cosineSimilarity(vectorA, vectorB)
        XCTAssertEqual(similarity, 0.0)
    }
}
