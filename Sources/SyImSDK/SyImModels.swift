import Foundation

/// Lightweight conversation row for the example / public API.
/// Maps to OpenIM `ConversationInfo` after real SDK is wired.
public struct SyImConversation: Equatable, Sendable {
    public var conversationId: String
    public var userId: String?
    public var groupId: String?
    public var showName: String?
    public var latestText: String?
    public var unreadCount: Int
    public var isPinned: Bool
    public var draftText: String?
    /// 0 正常接收，1 不接收，2 在线接收但不通知（免打扰）。
    public var receiveOption: Int

    public init(
        conversationId: String,
        userId: String? = nil,
        groupId: String? = nil,
        showName: String? = nil,
        latestText: String? = nil,
        unreadCount: Int = 0,
        isPinned: Bool = false,
        draftText: String? = nil,
        receiveOption: Int = 0
    ) {
        self.conversationId = conversationId
        self.userId = userId
        self.groupId = groupId
        self.showName = showName
        self.latestText = latestText
        self.unreadCount = unreadCount
        self.isPinned = isPinned
        self.draftText = draftText
        self.receiveOption = receiveOption
    }
}

/// 未读变化。`conversationId == nil` 时只有总未读；否则同时带上该会话未读。
public struct SyImUnreadUpdate: Equatable, Sendable {
    public var totalUnreadCount: Int
    public var conversationId: String?
    public var conversationUnreadCount: Int?

    public init(
        totalUnreadCount: Int,
        conversationId: String? = nil,
        conversationUnreadCount: Int? = nil
    ) {
        self.totalUnreadCount = totalUnreadCount
        self.conversationId = conversationId
        self.conversationUnreadCount = conversationUnreadCount
    }
}

/// 会话接收选项，对齐 OpenIM `OIMReceiveMessageOpt` / 腾讯云免打扰。
public enum SyImReceiveOption: Int, Sendable {
    case receive = 0
    case notReceive = 1
    case notNotify = 2
}

public struct SyImUserBrief: Equatable, Sendable {
    public var userId: String
    public var nickname: String?
    public var faceURL: String?
    public var ex: String?

    public init(userId: String, nickname: String? = nil, faceURL: String? = nil, ex: String? = nil) {
        self.userId = userId
        self.nickname = nickname
        self.faceURL = faceURL
        self.ex = ex
    }
}

public struct SyImSearchHit: Equatable, Sendable {
    public var conversationId: String
    public var clientMsgId: String?
    public var text: String?
    public var sendUserId: String?

    public init(
        conversationId: String,
        clientMsgId: String? = nil,
        text: String? = nil,
        sendUserId: String? = nil
    ) {
        self.conversationId = conversationId
        self.clientMsgId = clientMsgId
        self.text = text
        self.sendUserId = sendUserId
    }
}

/// 与 podspec / VERSION / 示例工程同为 0.5.0。
public enum SyImSDKVersion {
    public static let current = "0.5.0"
}

/// Chat bubble used by the example UI (local mock or OpenIM message).
public struct SyImChatMessage: Equatable, Sendable {
    public var msgId: String
    public var fromUserId: String
    public var toUserId: String?
    public var groupId: String?
    public var text: String
    public var isOutgoing: Bool
    public var timestamp: Date

    public init(
        msgId: String,
        fromUserId: String,
        toUserId: String? = nil,
        groupId: String? = nil,
        text: String,
        isOutgoing: Bool,
        timestamp: Date = Date()
    ) {
        self.msgId = msgId
        self.fromUserId = fromUserId
        self.toUserId = toUserId
        self.groupId = groupId
        self.text = text
        self.isOutgoing = isOutgoing
        self.timestamp = timestamp
    }
}

/// 收到的好友申请。`handleResult`：-1 已拒绝，0 待处理，1 已同意。
public struct SyImFriendApplication: Equatable, Sendable {
    public var fromUserId: String
    public var fromNickname: String?
    public var toUserId: String?
    public var reqMsg: String?
    public var handleResult: Int
    public var handleMsg: String?

    public init(
        fromUserId: String,
        fromNickname: String? = nil,
        toUserId: String? = nil,
        reqMsg: String? = nil,
        handleResult: Int = 0,
        handleMsg: String? = nil
    ) {
        self.fromUserId = fromUserId
        self.fromNickname = fromNickname
        self.toUserId = toUserId
        self.reqMsg = reqMsg
        self.handleResult = handleResult
        self.handleMsg = handleMsg
    }
}

/// 已加入的群。
public struct SyImGroup: Equatable, Sendable {
    public var groupId: String
    public var groupName: String?
    public var memberCount: Int
    public var ownerUserId: String?

    public init(
        groupId: String,
        groupName: String? = nil,
        memberCount: Int = 0,
        ownerUserId: String? = nil
    ) {
        self.groupId = groupId
        self.groupName = groupName
        self.memberCount = memberCount
        self.ownerUserId = ownerUserId
    }
}

/// 对方输入状态（OpenIM `onConversationUserInputStatusChanged`）。
///
/// `platformIds` 是对方正在输入的端（OpenIM 平台号）；为空表示停止输入。
/// 字段与 Android `ImTypingStatus`、Flutter `SyImTypingStatus` 相同。
public struct SyImTypingStatus: Equatable, Sendable {
    public let conversationId: String
    public let userId: String
    public let platformIds: [Int]

    public var typing: Bool { !platformIds.isEmpty }

    public init(conversationId: String, userId: String, platformIds: [Int]) {
        self.conversationId = conversationId
        self.userId = userId
        self.platformIds = platformIds
    }

    /// 解析 OpenIM 原样 JSON（`{"conversationID","userID","platformIDs"}`）。缺 userID 时返回 nil。
    public static func parse(_ json: String?) -> SyImTypingStatus? {
        guard let json, let data = json.data(using: .utf8),
              let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let userId = obj["userID"] as? String, !userId.isEmpty else { return nil }
        let platforms = (obj["platformIDs"] as? [Any])?.compactMap { ($0 as? NSNumber)?.intValue } ?? []
        return SyImTypingStatus(
            conversationId: (obj["conversationID"] as? String) ?? "",
            userId: userId,
            platformIds: platforms
        )
    }
}
