import Foundation

/// IM 事件回调（对齐腾讯/即构风格；后续映射 OpenIM 连接/消息监听）。
public protocol ImEventListener: AnyObject {
    func onConnectSuccess()
    func onConnectFailed(code: Int, error: String)
    func onConnecting()
    func onKickedOffline()
    func onUserTokenExpired()
    func onRecvNewMessage(msgId: String, fromUserId: String, groupId: String?, text: String?)
}

public extension ImEventListener {
    func onConnectSuccess() {}
    func onConnectFailed(code: Int, error: String) {}
    func onConnecting() {}
    func onKickedOffline() {}
    func onUserTokenExpired() {}
    func onRecvNewMessage(msgId: String, fromUserId: String, groupId: String?, text: String?) {}
}
