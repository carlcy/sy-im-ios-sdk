import Foundation

/// IM 事件回调（对齐腾讯/即构风格；后续映射 OpenIM 连接/消息监听）。
public protocol ImEventListener: AnyObject {
    func onConnectSuccess()
    func onConnectFailed(code: Int, error: String)
    func onConnecting()
    func onKickedOffline()
    func onUserTokenExpired()
    func onRecvNewMessage(msgId: String, fromUserId: String, groupId: String?, text: String?)
    /// OpenIM 会话总未读数变化。
    func onTotalUnreadCountChanged(count: Int)
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
    func onTotalUnreadCountChanged(count: Int) {}
    func onRecvC2CReadReceipt(userId: String, msgIds: [String]) {}
    func onRecvGroupReadReceipt(groupId: String, msgIds: [String]) {}
    func onRecvFriendApplication(fromUserId: String, reqMsg: String?) {}
}
