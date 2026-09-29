import Foundation
import os.log

private let log = OSLog(subsystem: "com.sy.im.sdk", category: "SyImEngine")


/// Which OpenIM client backend to use.
///
/// - `openImSdk` (**default**): CocoaPods `OpenIMSDK` → `RealOpenImClient` (native send/recv).
/// - `httpWs`: explicit HTTP+WS fallback (login via msg_gateway; send prefer SY `/api/user/im/send`).
/// - `mock`: UI-only when addresses empty / offline demos.
/// - `auto`: same as `openImSdk` when the module is linked; otherwise requires you to pass `.httpWs`
///   explicitly (will not silently pick HttpWs).
public enum SyImClientBackend: String, Sendable {
    case openImSdk
    case httpWs
    case mock
    case auto
}


/// SY IM 引擎（iOS）。
///
/// 公共 API 与 Android `ImEngine` / Flutter `SyIm` 对齐。
/// **默认** `backend: .openImSdk` → CocoaPods `OpenIMSDK` / `RealOpenImClient`。
/// HttpWs 仅在显式 `backend: .httpWs` 时使用；地址为空且 `.mock` 时用 Mock。
/// 客户接入：`pod 'SyImSDK', '~> 0.5.0'`。OpenIM iOS 无 SPM，生产不要用 Package.swift。
public final class SyImEngine {
    public let appId: String
    public let apiBaseUrl: String
    public let imApiAddr: String
    public let imWsAddr: String

    private(set) public var isLoggedIn: Bool = false
    private(set) public var currentUserId: String?

    /// SY 控制面 JWT（可选）。设置后 HttpWs 发消息可走 POST /api/user/im/send（OpenIM admin 代理，真实落库）。
    public var controlPlaneAccessToken: String?

    private weak var eventListener: ImEventListener?
    private let client: OpenImClient
    private static var shared: SyImEngine?

    private init(
        appId: String,
        apiBaseUrl: String,
        imApiAddr: String,
        imWsAddr: String,
        client: OpenImClient
    ) {
        self.appId = appId
        self.apiBaseUrl = apiBaseUrl
        self.imApiAddr = imApiAddr
        self.imWsAddr = imWsAddr
        self.client = client
        client.setEventSink(self)
    }

    /// 初始化单例引擎。
    ///
    /// - Parameters:
    ///   - appId: 与 RTC 共用的应用 ID
    ///   - apiBaseUrl: SY 控制面（签发 IM Token），例如 `https://47.105.48.196`
    ///   - imApiAddr: OpenIM API，例如 `https://47.105.48.196/openim`
    ///   - imWsAddr: OpenIM WebSocket，例如 `wss://47.105.48.196/msg_gateway`
    ///   - backend: **默认 `.openImSdk`**（CocoaPods OpenIMSDK）。HttpWs 仅 `.httpWs` 显式回退。
    @discardableResult
    public static func initialize(
        appId: String,
        apiBaseUrl: String,
        imApiAddr: String = "",
        imWsAddr: String = "",
        backend: SyImClientBackend = .openImSdk
    ) -> SyImEngine {
        if let existing = shared {
            return existing
        }
        let apiTrim = imApiAddr.trimmingCharacters(in: .whitespacesAndNewlines)
        let wsTrim = imWsAddr.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasAddrs = !apiTrim.isEmpty && !wsTrim.isEmpty

        let backendClient: OpenImClient = makeClient(
            backend: backend,
            hasAddrs: hasAddrs,
            apiBaseUrl: apiBaseUrl,
            appId: appId,
            imApiAddr: imApiAddr,
            imWsAddr: imWsAddr
        )

        let engine = SyImEngine(
            appId: appId,
            apiBaseUrl: apiBaseUrl,
            imApiAddr: imApiAddr,
            imWsAddr: imWsAddr,
            client: backendClient
        )
        shared = engine
        return engine
    }

    private static func makeClient(
        backend: SyImClientBackend,
        hasAddrs: Bool,
        apiBaseUrl: String,
        appId: String,
        imApiAddr: String,
        imWsAddr: String
    ) -> OpenImClient {
        let want: SyImClientBackend
        switch backend {
        case .auto:
            #if canImport(OpenIMSDK)
            want = .openImSdk
            #else
            want = hasAddrs ? .openImSdk : .mock
            #endif
        default:
            want = backend
        }

        switch want {
        case .openImSdk, .auto:
            #if canImport(OpenIMSDK)
            os_log("DEFAULT RealOpenImClient (OpenIMSDK). api=%{public}@ ws=%{public}@", log: log, type: .info, imApiAddr, imWsAddr)
            return RealOpenImClient()
            #else
            os_log("OpenIMSDK not linked. Use CocoaPods (`pod SyImSDK`) or pass backend: .httpWs.", log: log, type: .error)
            return MissingOpenImSdkClient()
            #endif
        case .httpWs:
            if !hasAddrs {
                os_log("backend=.httpWs but addresses empty — MockOpenImClient", log: log, type: .info)
                return MockOpenImClient()
            }
            let http = HttpWsOpenImClient()
            http.controlPlaneBaseURL = apiBaseUrl
            http.appId = appId
            os_log("EXPLICIT HttpWsOpenImClient fallback. api=%{public}@ ws=%{public}@", log: log, type: .info, imApiAddr, imWsAddr)
            return http
        case .mock:
            os_log("MockOpenImClient (backend=.mock)", log: log, type: .info)
            return MockOpenImClient()
        }
    }

    @discardableResult
    public static func create(
        appId: String,
        apiBaseUrl: String,
        imApiAddr: String = "",
        imWsAddr: String = "",
        backend: SyImClientBackend = .openImSdk
    ) -> SyImEngine {
        initialize(appId: appId, apiBaseUrl: apiBaseUrl, imApiAddr: imApiAddr, imWsAddr: imWsAddr, backend: backend)
    }

    public static var instance: SyImEngine? { shared }

    /// Reset singleton (example / tests).
    public static func reset() {
        shared = nil
    }

    public func setEventListener(_ listener: ImEventListener?) {
        eventListener = listener
    }

    /// 绑定控制面 JWT，供 HttpWs 真实发信（/api/user/im/send）。
    public func setControlPlaneAccessToken(_ token: String?) {
        controlPlaneAccessToken = token
        if let http = client as? HttpWsOpenImClient {
            http.controlPlaneAccessToken = token
            http.controlPlaneBaseURL = apiBaseUrl
            http.appId = appId
        }
    }

    /// Initializes OpenIM (or mock). Safe to call more than once.
    public func prepare() async throws {
        let api = imApiAddr.isEmpty ? apiBaseUrl : imApiAddr
        let ws = imWsAddr
        try await client.initSdk(apiAddr: api, wsAddr: ws)
        eventListener?.onConnecting()
        eventListener?.onConnectSuccess()
    }

    public func login(userId: String, token: String) async throws {
        try await client.login(userId: userId, token: token)
        currentUserId = userId
        isLoggedIn = true
        eventListener?.onConnectSuccess()
    }

    public func logout() async throws {
        try await client.logout()
        isLoggedIn = false
        currentUserId = nil
    }

    /// 发送文本。单聊传 `userId`，群聊传 `groupId`（二选一）。
    @discardableResult
    public func sendTextMessage(
        userId: String? = nil,
        groupId: String? = nil,
        text: String
    ) async throws -> String {
        guard isLoggedIn else { throw SyImError.notLoggedIn }
        guard (userId?.isEmpty == false) || (groupId?.isEmpty == false) else {
            throw SyImError.invalidArgument("provide userId or groupId")
        }
        return try await client.sendText(userId: userId, groupId: groupId, text: text)
    }

    @discardableResult
    public func sendTextMessage(toUserId: String, text: String) async throws -> String {
        try await sendTextMessage(userId: toUserId, groupId: nil, text: text)
    }

    /// 会话列表。每条会话的 `unreadCount` 是该会话未读数。
    public func getConversations() async throws -> [SyImConversation] {
        try await client.conversations()
    }

    /// 全部会话未读数之和。登录后有效。
    public func getTotalUnreadCount() async throws -> Int {
        guard isLoggedIn else { throw SyImError.notLoggedIn }
        return try await client.totalUnreadCount()
    }

    /// 将会话标为已读。
    /// 单聊同时向对方发送已读回执（对方 `onRecvC2CReadReceipt`）；群聊只清除本端未读。
    public func markConversationAsRead(conversationId: String) async throws {
        guard isLoggedIn else { throw SyImError.notLoggedIn }
        let id = conversationId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { throw SyImError.invalidArgument("conversationId required") }
        try await client.markConversationAsRead(conversationId: id)
    }

    /// 收到的好友申请（待处理与已处理）。需要 OpenIMSDK（默认 CocoaPods 路径）。
    public func getReceivedFriendApplications() async throws -> [SyImFriendApplication] {
        guard isLoggedIn else { throw SyImError.notLoggedIn }
        return try await client.receivedFriendApplications()
    }

    /// 同意好友申请。`userId` 为申请方 OpenIM 用户 ID。
    public func acceptFriendApplication(userId: String, handleMsg: String = "") async throws {
        guard isLoggedIn else { throw SyImError.notLoggedIn }
        let uid = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !uid.isEmpty else { throw SyImError.invalidArgument("userId required") }
        try await client.acceptFriendApplication(userId: uid, handleMsg: handleMsg)
    }

    /// 拒绝好友申请。
    public func refuseFriendApplication(userId: String, handleMsg: String = "") async throws {
        guard isLoggedIn else { throw SyImError.notLoggedIn }
        let uid = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !uid.isEmpty else { throw SyImError.invalidArgument("userId required") }
        try await client.refuseFriendApplication(userId: uid, handleMsg: handleMsg)
    }

    /// 当前账号已加入的群（OpenIM 本地列表）。
    public func getJoinedGroups() async throws -> [SyImGroup] {
        guard isLoggedIn else { throw SyImError.notLoggedIn }
        return try await client.joinedGroups()
    }

    /// 邀请用户入群。
    public func inviteToGroup(groupId: String, userIds: [String], reason: String = "") async throws {
        guard isLoggedIn else { throw SyImError.notLoggedIn }
        try await client.inviteUsers(groupId: try requireId(groupId, name: "groupId"), userIds: userIds, reason: reason)
    }

    /// 将成员移出群。
    public func kickFromGroup(groupId: String, userIds: [String], reason: String = "") async throws {
        guard isLoggedIn else { throw SyImError.notLoggedIn }
        try await client.kickGroupMembers(groupId: try requireId(groupId, name: "groupId"), userIds: userIds, reason: reason)
    }

    /// 退出群。
    public func quitGroup(groupId: String) async throws {
        guard isLoggedIn else { throw SyImError.notLoggedIn }
        try await client.quitGroup(groupId: try requireId(groupId, name: "groupId"))
    }

    /// 解散群（群主）。
    public func dismissGroup(groupId: String) async throws {
        guard isLoggedIn else { throw SyImError.notLoggedIn }
        try await client.dismissGroup(groupId: try requireId(groupId, name: "groupId"))
    }

    /// 发起好友申请。控制面 `POST /api/user/im/friends/add`，需先 `setControlPlaneAccessToken`。
    public func addFriend(fromUserId: String, toUserId: String, reqMsg: String = "") async throws {
        _ = try await controlPlaneObject(path: "/api/user/im/friends/add", body: [
            "fromUserId": try requireId(fromUserId, name: "fromUserId"),
            "toUserId": try requireId(toUserId, name: "toUserId"),
            "reqMsg": reqMsg,
        ])
    }

    /// 好友列表。控制面 `POST /api/user/im/friends/list`。
    public func listFriends(ownerUserId: String) async throws -> [String: Any] {
        try await controlPlaneObject(path: "/api/user/im/friends/list", body: [
            "ownerUserId": try requireId(ownerUserId, name: "ownerUserId"),
        ])
    }

    /// 建群。控制面 `POST /api/user/im/groups/create`。返回值为响应里的 `data`（字典；若是数组则包在 `list` 下）。
    @discardableResult
    public func createGroup(
        ownerUserId: String,
        groupName: String,
        memberUserIds: [String] = []
    ) async throws -> [String: Any] {
        let name = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw SyImError.invalidArgument("groupName required") }
        return try await controlPlaneObject(path: "/api/user/im/groups/create", body: [
            "ownerUserId": try requireId(ownerUserId, name: "ownerUserId"),
            "groupName": name,
            "memberUserIds": memberUserIds,
        ])
    }

    /// 群列表。控制面 `POST /api/user/im/groups/list`。
    public func listGroups(ownerUserId: String) async throws -> [String: Any] {
        try await controlPlaneObject(path: "/api/user/im/groups/list", body: [
            "ownerUserId": try requireId(ownerUserId, name: "ownerUserId"),
        ])
    }

    /// 历史消息。控制面 `POST /api/user/im/messages/history`。
    public func messageHistory(
        userId: String,
        conversationId: String? = nil,
        peerUserId: String? = nil,
        groupId: String? = nil,
        count: Int = 20
    ) async throws -> [String: Any] {
        var body: [String: Any] = ["userId": try requireId(userId, name: "userId"), "count": count]
        if let conversationId, !conversationId.isEmpty { body["conversationId"] = conversationId }
        if let peerUserId, !peerUserId.isEmpty { body["peerUserId"] = peerUserId }
        if let groupId, !groupId.isEmpty { body["groupId"] = groupId }
        return try await controlPlaneObject(path: "/api/user/im/messages/history", body: body)
    }

    /// 撤回。控制面 `POST /api/user/im/messages/revoke`（`conversationId` + `seq`）。
    public func revokeMessage(userId: String, conversationId: String, seq: Int) async throws {
        _ = try await controlPlaneObject(path: "/api/user/im/messages/revoke", body: [
            "userId": try requireId(userId, name: "userId"),
            "conversationId": try requireId(conversationId, name: "conversationId"),
            "seq": seq,
        ])
    }

    /// 控制面拉取 IM Token：优先 User JWT → POST /api/user/im/token；否则需自行带 AppSecret 调 server 路径。
    public func getToken(userId: String, userJwt: String) async throws -> [String: Any] {
        let base = apiBaseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/api/user/im/token") else {
            throw SyImError.invalidArgument("bad apiBaseUrl")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(userJwt)", forHTTPHeaderField: "Authorization")
        req.setValue(appId, forHTTPHeaderField: "X-App-Id")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["appId": appId, "userId": userId])
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        let biz = json["code"] as? Int ?? (code >= 200 && code < 300 ? 0 : -1)
        guard code >= 200 && code < 300, biz == 0 else {
            throw SyImError.openImApi(json["msg"] as? String ?? "getToken HTTP \(code)")
        }
        return (json["data"] as? [String: Any]) ?? [:]
    }

    /// 控制面 REST：friends/groups/send/history/revoke（需 User JWT）。实时收发仍走 OpenIM 客户端。
    public func controlPlanePost(path: String, userJwt: String, body: [String: Any]) async throws -> [String: Any] {
        let data = try await controlPlaneData(path: path, userJwt: userJwt, body: body)
        return data as? [String: Any] ?? [:]
    }

    private func requireId(_ value: String, name: String) throws -> String {
        let id = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { throw SyImError.invalidArgument("\(name) required") }
        return id
    }

    private func requireControlPlaneJwt() throws -> String {
        let jwt = controlPlaneAccessToken?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !jwt.isEmpty else {
            throw SyImError.invalidArgument("call setControlPlaneAccessToken with the user JWT first")
        }
        return jwt
    }

    private func controlPlaneObject(path: String, body: [String: Any]) async throws -> [String: Any] {
        let data = try await controlPlaneData(path: path, userJwt: try requireControlPlaneJwt(), body: body)
        if let dict = data as? [String: Any] { return dict }
        if let list = data as? [Any] { return ["list": list] }
        if data is NSNull { return [:] }
        return [:]
    }

    private func controlPlaneData(path: String, userJwt: String, body: [String: Any]) async throws -> Any {
        let base = apiBaseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let p = path.hasPrefix("/") ? path : "/\(path)"
        guard let url = URL(string: "\(base)\(p)") else {
            throw SyImError.invalidArgument("bad path")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(userJwt)", forHTTPHeaderField: "Authorization")
        req.setValue(appId, forHTTPHeaderField: "X-App-Id")
        var payload = body
        if payload["appId"] == nil { payload["appId"] = appId }
        req.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, resp) = try await URLSession.shared.data(for: req)
        let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
        let json = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        let biz = json["code"] as? Int ?? (code >= 200 && code < 300 ? 0 : -1)
        guard code >= 200 && code < 300, biz == 0 else {
            throw SyImError.openImApi(json["msg"] as? String ?? "controlPlane HTTP \(code)")
        }
        return json["data"] ?? [:]
    }

}

extension SyImEngine: OpenImEventSink {
    func imOnConnecting() { eventListener?.onConnecting() }
    func imOnConnectSuccess() { eventListener?.onConnectSuccess() }
    func imOnConnectFailed(code: Int, error: String) { eventListener?.onConnectFailed(code: code, error: error) }
    func imOnKickedOffline() { eventListener?.onKickedOffline() }
    func imOnUserTokenExpired() { eventListener?.onUserTokenExpired() }
    func imOnRecvNewMessage(msgId: String, fromUserId: String, groupId: String?, text: String?) {
        eventListener?.onRecvNewMessage(msgId: msgId, fromUserId: fromUserId, groupId: groupId, text: text)
    }
    func imOnTotalUnreadCountChanged(count: Int) { eventListener?.onTotalUnreadCountChanged(count: count) }
    func imOnRecvC2CReadReceipt(userId: String, msgIds: [String]) {
        eventListener?.onRecvC2CReadReceipt(userId: userId, msgIds: msgIds)
    }
    func imOnRecvGroupReadReceipt(groupId: String, msgIds: [String]) {
        eventListener?.onRecvGroupReadReceipt(groupId: groupId, msgIds: msgIds)
    }
    func imOnRecvFriendApplication(fromUserId: String, reqMsg: String?) {
        eventListener?.onRecvFriendApplication(fromUserId: fromUserId, reqMsg: reqMsg)
    }
}


public enum SyImError: Error, LocalizedError {
    case notLoggedIn
    case notInitialized
    case invalidArgument(String)
    case openImUnreachable(String)
    case openImLoginFailed(String)
    case openImApi(String)
    case openImSendDenied(String)

    public var errorDescription: String? {
        switch self {
        case .notLoggedIn: return "login required"
        case .notInitialized: return "call SyImEngine.initialize first"
        case .invalidArgument(let s): return s
        case .openImUnreachable(let s): return s
        case .openImLoginFailed(let s): return "OpenIM login failed: \(s)"
        case .openImApi(let s): return s
        case .openImSendDenied(let s): return s
        }
    }
}
