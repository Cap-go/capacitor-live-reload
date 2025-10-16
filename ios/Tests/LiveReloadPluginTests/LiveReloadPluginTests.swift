import XCTest
@testable import LiveReloadPlugin

final class LiveReloadPluginTests: XCTestCase {
    func testStatusConversion() throws {
        let status = LiveReloadStatus(connected: true, url: "https://example.com")
        let result = status.toResult()
        XCTAssertEqual(result["connected"] as? Bool, true)
        XCTAssertEqual(result["url"] as? String, "https://example.com")
    }
}
