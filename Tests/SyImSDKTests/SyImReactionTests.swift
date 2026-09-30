import XCTest
@testable import SyImSDK

final class SyImReactionTests: XCTestCase {
    func testParsesServerReactionPayload() {
        let data = #"{"sy":"reaction_lite","action":"add","emoji":"👍","target":{"seq":12,"clientMsgId":"c1","senderId":"u2"}}"#
        let r = SyImReaction.parse(data)
        XCTAssertEqual(r, SyImReaction(emoji: "👍", added: true, targetClientMsgId: "c1", targetSeq: 12, targetSenderId: "u2"))
        XCTAssertEqual(SyImReaction.parse(data.replacingOccurrences(of: "\"add\"", with: "\"remove\""))?.added, false)
    }

    func testIgnoresOtherCustomMessages() {
        XCTAssertNil(SyImReaction.parse(nil))
        XCTAssertNil(SyImReaction.parse("not json"))
        XCTAssertNil(SyImReaction.parse(#"{"sy":"call_invite"}"#))
        XCTAssertNil(SyImReaction.parse(#"{"sy":"reaction_lite","emoji":""}"#))
    }

    func testRequestBodyMatchesBackendReactReq() {
        let group = SyImReaction.requestBody(fromUserId: "u1", emoji: "👍", toUserId: nil, groupId: "g1",
                                             targetClientMsgId: "c1", targetSeq: 0, targetSenderId: "u2", add: false)
        XCTAssertEqual(group["groupId"] as? String, "g1")
        XCTAssertNil(group["toUserId"])
        XCTAssertEqual(group["action"] as? String, "remove")
        XCTAssertNil(group["targetSeq"])
        let single = SyImReaction.requestBody(fromUserId: "u1", emoji: "❤️", toUserId: "u3", groupId: nil,
                                              targetClientMsgId: nil, targetSeq: 7, targetSenderId: nil, add: true)
        XCTAssertEqual(single["toUserId"] as? String, "u3")
        XCTAssertEqual(single["targetSeq"] as? Int64, 7)
        XCTAssertEqual(single["action"] as? String, "add")
    }
}
