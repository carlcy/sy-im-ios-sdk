import Foundation

/// 已读回执（单聊 + 群聊统一）。与 Android `ImReadReceipt`、Flutter `SyImReadReceipt` 字段和语义相同：
/// - `conversationId`：OpenIM 会话 id（单聊 `si_<小 uid>_<大 uid>`，群 `sg_<groupId>`）；推导不出时为空串。
/// - `userId`：已读方。`groupId`：群聊为群 id，单聊为 nil。
/// - `msgIds`：该已读方本次已读的客户端消息 id。`readTime`：毫秒，OpenIM 没给时为 0。
public struct SyImReadReceipt: Equatable {
    public let conversationId: String
    public let userId: String
    public let groupId: String?
    public let msgIds: [String]
    public let readTime: Int64

    public init(conversationId: String, userId: String, groupId: String?, msgIds: [String], readTime: Int64 = 0) {
        self.conversationId = conversationId
        self.userId = userId
        self.groupId = groupId
        self.msgIds = msgIds
        self.readTime = readTime
    }

    public var isGroup: Bool { !(groupId ?? "").isEmpty }
}

/// 群消息已读概况，三端相同。`source`：`openim`（OpenIM 给了成员）、`controlPlane`（成员来自控制面
/// who-read 花名册）、`none`（只有人数）。花名册只含调用过 `reportGroupMessagesRead` 的成员，不是全员名单。
public struct SyImGroupReadInfo: Equatable {
    public static let sourceOpenIm = "openim"
    public static let sourceControlPlane = "controlPlane"
    public static let sourceNone = "none"

    public let clientMsgId: String
    public let hasReadCount: Int
    public let unreadCount: Int
    public let readUserIds: [String]
    public let source: String
}

/// 已读回执的纯逻辑，三端规则相同（Android `ImReadReceipts`）。
public enum SyImReadReceipts {
    public static func singleConversationId(_ a: String, _ b: String) -> String {
        guard !a.isEmpty, !b.isEmpty else { return "" }
        return "si_" + [a, b].sorted().joined(separator: "_")
    }

    public static func groupConversationId(_ groupId: String) -> String {
        groupId.isEmpty ? "" : "sg_\(groupId)"
    }

    public static func groupId(ofConversation id: String) -> String? {
        guard id.hasPrefix("sg_"), id.count > 3 else { return nil }
        return String(id.dropFirst(3))
    }

    /// 「每条消息 → 已读成员」转成「每个已读者 → 消息 id」，已读者按首次出现顺序。
    public static func perReader(conversationId: String, perMessage: [(String, [String])]) -> [SyImReadReceipt] {
        var order: [String] = []
        var byReader: [String: [String]] = [:]
        for (msgId, readers) in perMessage where !msgId.isEmpty {
            for r in readers where !r.isEmpty {
                if byReader[r] == nil { order.append(r); byReader[r] = [] }
                if !(byReader[r]!.contains(msgId)) { byReader[r]!.append(msgId) }
            }
        }
        let gid = groupId(ofConversation: conversationId)
        return order.map { SyImReadReceipt(conversationId: conversationId, userId: $0, groupId: gid, msgIds: byReader[$0] ?? []) }
    }

    /// 控制面 `who-read` 的 `list[].readerUid` → 去重后的已读者（保持服务端顺序）。
    public static func readers(fromWhoRead list: [[String: Any]]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for row in list {
            guard let uid = row["readerUid"] as? String, !uid.isEmpty, !seen.contains(uid) else { continue }
            seen.insert(uid)
            out.append(uid)
        }
        return out
    }

    /// OpenIM 有成员 id 用 OpenIM；否则用控制面花名册（nil 表示没查）。花名册人数多于 OpenIM 时以花名册为准，未读相应减少。
    public static func merge(clientMsgId: String, hasReadCount: Int, unreadCount: Int,
                             openImReaders: [String], roster: [String]?) -> SyImGroupReadInfo {
        if !openImReaders.isEmpty {
            return SyImGroupReadInfo(clientMsgId: clientMsgId, hasReadCount: max(hasReadCount, openImReaders.count),
                                     unreadCount: unreadCount, readUserIds: openImReaders, source: SyImGroupReadInfo.sourceOpenIm)
        }
        if let roster, !roster.isEmpty {
            let read = max(hasReadCount, roster.count)
            let unread = max(0, unreadCount - (read - hasReadCount))
            return SyImGroupReadInfo(clientMsgId: clientMsgId, hasReadCount: read, unreadCount: unread,
                                     readUserIds: roster, source: SyImGroupReadInfo.sourceControlPlane)
        }
        return SyImGroupReadInfo(clientMsgId: clientMsgId, hasReadCount: hasReadCount, unreadCount: unreadCount,
                                 readUserIds: [], source: SyImGroupReadInfo.sourceNone)
    }
}

/// OpenIM 本地查到的一条群消息已读数据。
struct SyImRawGroupReadInfo {
    let hasReadCount: Int
    let unreadCount: Int
    let readers: [String]
    let seq: Int64
    let found: Bool
}
