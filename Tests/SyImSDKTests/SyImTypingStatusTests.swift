import XCTest
@testable import SyImSDK

/// 与 Android TypingStatusTest 对应。
final class SyImTypingStatusTests: XCTestCase {
    func testParsesOpenImInputStatusJson() {
        let s = SyImTypingStatus.parse(#"{"conversationID":"si_u1_u2","userID":"u2","platformIDs":[2,5]}"#)
        XCTAssertEqual(s, SyImTypingStatus(conversationId: "si_u1_u2", userId: "u2", platformIds: [2, 5]))
        XCTAssertEqual(s?.typing, true)
    }

    func testEmptyOrMissingPlatformsMeansStopped() {
        XCTAssertEqual(SyImTypingStatus.parse(#"{"conversationID":"c","userID":"u2","platformIDs":[]}"#)?.typing, false)
        XCTAssertEqual(SyImTypingStatus.parse(#"{"conversationID":"c","userID":"u2"}"#)?.typing, false)
    }

    func testRejectsGarbage() {
        XCTAssertNil(SyImTypingStatus.parse(nil))
        XCTAssertNil(SyImTypingStatus.parse(""))
        XCTAssertNil(SyImTypingStatus.parse("yes"))
        XCTAssertNil(SyImTypingStatus.parse(#"{"conversationID":"c"}"#))
    }
}
