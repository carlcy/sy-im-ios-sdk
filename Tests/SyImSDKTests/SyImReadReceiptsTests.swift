import XCTest
@testable import SyImSDK

/// 与 Android ReadReceiptsTest、Flutter read_receipts_test 相同的期望。
final class SyImReadReceiptsTests: XCTestCase {
    func testConversationIds() {
        XCTAssertEqual(SyImReadReceipts.singleConversationId("b", "a"), "si_a_b")
        XCTAssertEqual(SyImReadReceipts.singleConversationId("", "a"), "")
        XCTAssertEqual(SyImReadReceipts.groupConversationId("g1"), "sg_g1")
        XCTAssertEqual(SyImReadReceipts.groupId(ofConversation: "sg_g1"), "g1")
        XCTAssertNil(SyImReadReceipts.groupId(ofConversation: "si_a_b"))
    }

    func testPerMessageGroupReceiptBecomesPerReader() {
        let out = SyImReadReceipts.perReader(conversationId: "sg_g1",
                                             perMessage: [("m1", ["u2", "u3"]), ("m2", ["u2"]), ("", ["u9"])])
        XCTAssertEqual(out.count, 2)
        XCTAssertEqual(out[0], SyImReadReceipt(conversationId: "sg_g1", userId: "u2", groupId: "g1", msgIds: ["m1", "m2"]))
        XCTAssertEqual(out[1].msgIds, ["m1"])
        XCTAssertTrue(out[0].isGroup)
        XCTAssertFalse(SyImReadReceipt(conversationId: "si_a_b", userId: "a", groupId: nil, msgIds: ["m"]).isGroup)
    }

    func testMergePrefersOpenImThenRoster() {
        let a = SyImReadReceipts.merge(clientMsgId: "m1", hasReadCount: 2, unreadCount: 3, openImReaders: ["u2", "u3"], roster: ["u9"])
        XCTAssertEqual(a.source, SyImGroupReadInfo.sourceOpenIm)
        XCTAssertEqual(a.readUserIds, ["u2", "u3"])
        let b = SyImReadReceipts.merge(clientMsgId: "m1", hasReadCount: 1, unreadCount: 3, openImReaders: [], roster: ["u2", "u3"])
        XCTAssertEqual(b.source, SyImGroupReadInfo.sourceControlPlane)
        XCTAssertEqual(b.hasReadCount, 2)
        XCTAssertEqual(b.unreadCount, 2)
        let c = SyImReadReceipts.merge(clientMsgId: "m1", hasReadCount: 4, unreadCount: 0, openImReaders: [], roster: nil)
        XCTAssertEqual(c.source, SyImGroupReadInfo.sourceNone)
        XCTAssertEqual(c.hasReadCount, 4)
        XCTAssertTrue(c.readUserIds.isEmpty)
    }

    func testWhoReadRosterDedupes() {
        let list: [[String: Any]] = [["readerUid": "u3", "seq": 7], ["readerUid": "u2"], ["readerUid": "u3"], ["x": 1]]
        XCTAssertEqual(SyImReadReceipts.readers(fromWhoRead: list), ["u3", "u2"])
    }
}
