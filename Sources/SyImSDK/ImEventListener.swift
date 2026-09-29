import Foundation

/// IM 事件回调（对齐腾讯/即构风格；后续映射 OpenIM 连接/消息监听）。
public protocol ImEventListener: AnyObject {
    func onConnectSuccess()
    func onConnectFailed(code: Int, error: String)
    func onConnecting()
    func onKickedOffline()
    func onUserTokenExpired()
    func onRecvNewMessage(msgId: String, fromUserId: String, groupId: String?, text: String?)
    /// 总未读或单个会话未读变化。OpenIM 会话监听和标已读之后都会回调。
    func onUnreadChanged(_ update: SyImUnreadUpdate)
    /// OpenIM 会话总未读数变化。
    func onTotalUnreadCountChanged(count: Int)
    /// 单个会话未读变化。
    func onConversationUnreadChanged(conversationId: String, unreadCount: Int)
    /// 消息被撤回。
    func onMessageRecalled(clientMsgId: String, revokerUserId: String)
    /// 单聊已读回执。`msgIds` 为对方已读的 clientMsgID。
    func onRecvC2CReadReceipt(userId: String, msgIds: [String])
    /// 群聊已读回执。
    func onRecvGroupReadReceipt(groupId: String, msgIds: [String])
    /// 收到新的好友申请。
    func onRecvFriendApplication(fromUserId: String, reqMsg: String?)
}

public extension ImEventListener {
    func onConnectSuccess() {}
    func onConnectFailed(code: Int, error: String) {}
    func onConnecting() {}
    func onKickedOffline() {}
    func onUserTokenExpired() {}
    func onRecvNewMessage(msgId: String, fromUserId: String, groupId: String?, text: String?) {}
    func onUnreadChanged(_ update: SyImUnreadUpdate) {}
    func onTotalUnreadCountChanged(count: Int) {}
    func onConversationUnreadChanged(conversationId: String, unreadCount: Int) {}
    func onMessageRecalled(clientMsgId: String, revokerUserId: String) {}
    func onRecvC2CReadReceipt(userId: String, msgIds: [String]) {}
    func onRecvGroupReadReceipt(groupId: String, msgIds: [String]) {}
    func onRecvFriendApplication(fromUserId: String, reqMsg: String?) {}
}
