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

    public init(
        conversationId: String,
        userId: String? = nil,
        groupId: String? = nil,
        showName: String? = nil,
        latestText: String? = nil,
        unreadCount: Int = 0
    ) {
        self.conversationId = conversationId
        self.userId = userId
        self.groupId = groupId
        self.showName = showName
        self.latestText = latestText
        self.unreadCount = unreadCount
    }
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
