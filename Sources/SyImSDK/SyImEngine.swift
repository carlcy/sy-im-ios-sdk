import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(os.log)
import os.log
#endif

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

    /// 总未读或单个会话未读变化。OpenIM 会话监听，以及 `markConversationAsRead` 成功后立刻回调。
    /// 回调线程不保证是主线程，刷新 UI 请切回主线程。
    public var onUnreadChanged: ((SyImUnreadUpdate) -> Void)?

    private let unreadLock = NSLock()
    private var unreadByConversation: [String: Int] = [:]
    private var cachedTotalUnread: Int = 0
    /// 服务端总未读里，还没落到 `unreadByConversation` 的部分，避免总未读和单会话回调互相加两次。
    private var untrackedUnread: Int = 0

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
        publish(resetUnreadCache())
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
    /// 只写入未读缓存，不回调 `onUnreadChanged`，避免刷新列表时循环。
    public func getConversations() async throws -> [SyImConversation] {
        let list = try await client.conversations()
        seedUnreadCache(list)
        return list
    }

    /// 全部会话未读数之和。登录后有效。写入缓存，不额外发未读回调。
    public func getTotalUnreadCount() async throws -> Int {
        guard isLoggedIn else { throw SyImError.notLoggedIn }
        let count = try await client.totalUnreadCount()
        _ = applyServerTotal(count)
        return count
    }

    /// 将会话标为已读。
    /// 单聊同时向对方发送已读回执（对方 `onRecvC2CReadReceipt`）；群聊只清除本端未读。
    /// 成功后立刻回调未读变化（该会话为 0，总未读扣掉原未读），再用总未读接口校正。
    public func markConversationAsRead(conversationId: String) async throws {
        guard isLoggedIn else { throw SyImError.notLoggedIn }
        let id = conversationId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty else { throw SyImError.invalidArgument("conversationId required") }
        try await client.markConversationAsRead(conversationId: id)
        publish(noteConversationUnread(conversationId: id, unreadCount: 0))
        if let confirmed = try? await client.totalUnreadCount() {
            publish(applyServerTotal(confirmed))
        }
    }

    /// 撤回一条客户端消息。`clientMsgId` 是 OpenIM clientMsgID。
    /// 控制面按 seq 撤回仍用 `revokeMessage(userId:conversationId:seq:)`。
    public func recallMessage(conversationId: String, clientMsgId: String) async throws {
        guard isLoggedIn else { throw SyImError.notLoggedIn }
        try await client.recall(
            conversationId: try requireId(conversationId, name: "conversationId"),
            clientMsgId: try requireId(clientMsgId, name: "clientMsgId")
        )
    }

    /// 群 @ 文本。`atAll == true` 时忽略 `atUserIds`。
    @discardableResult
    public func sendAtTextMessage(
        groupId: String,
        text: String,
        atUserIds: [String] = [],
        atAll: Bool = false
    ) async throws -> String {
        guard isLoggedIn else { throw SyImError.notLoggedIn }
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { throw SyImError.invalidArgument("text required") }
        return try await client.sendAtText(
            groupId: try requireId(groupId, name: "groupId"),
            text: body,
            atUserIds: atUserIds,
            atAll: atAll
        )
    }

    /// 自定义消息。`data` 为业务 JSON/文本，`description` / `ext` 可选。
    @discardableResult
    public func sendCustomMessage(
        userId: String? = nil,
        groupId: String? = nil,
        data: String,
        description: String? = nil,
        ext: String? = nil
    ) async throws -> String {
        guard isLoggedIn else { throw SyImError.notLoggedIn }
        guard (userId?.isEmpty == false) || (groupId?.isEmpty == false) else {
            throw SyImError.invalidArgument("provide userId or groupId")
        }
        let payload = data.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !payload.isEmpty else { throw SyImError.invalidArgument("data required") }
        return try await client.sendCustom(userId: userId, groupId: groupId, data: payload, description: description, ext: ext)
    }

    public func searchConversations(keyword: String) async throws -> [SyImConversation] {
        guard isLoggedIn else { throw SyImError.notLoggedIn }
        return try await client.searchConversations(keyword: try requireId(keyword, name: "keyword"))
    }

    public func searchMessages(keyword: String, conversationId: String? = nil) async throws -> [SyImSearchHit] {
        guard isLoggedIn else { throw SyImError.notLoggedIn }
        return try await client.searchMessages(
            keyword: try requireId(keyword, name: "keyword"),
            conversationId: conversationId
        )
    }

    public func searchUsers(keyword: String) async throws -> [SyImUserBrief] {
        guard isLoggedIn else { throw SyImError.notLoggedIn }
        return try await client.searchUsers(keyword: try requireId(keyword, name: "keyword"))
    }

    public func pinConversation(conversationId: String, isPinned: Bool) async throws {
        guard isLoggedIn else { throw SyImError.notLoggedIn }
        try await client.pinConversation(
            conversationId: try requireId(conversationId, name: "conversationId"),
            isPinned: isPinned
        )
    }

    public func setConversationDraft(conversationId: String, draft: String) async throws {
        guard isLoggedIn else { throw SyImError.notLoggedIn }
        try await client.setDraft(
            conversationId: try requireId(conversationId, name: "conversationId"),
            draft: draft
        )
    }

    /// 免打扰。`notNotify` 在线接收但不通知，`notReceive` 不接收。
    public func setConversationReceiveOption(conversationId: String, option: SyImReceiveOption) async throws {
        guard isLoggedIn else { throw SyImError.notLoggedIn }
        try await client.setReceiveOption(
            conversationId: try requireId(conversationId, name: "conversationId"),
            option: option.rawValue
        )
    }

    /// 发送正在输入（OpenIM `changeInputStates`）。对端回调 `ImEventListener.onTypingStatusChanged(_:)`。
    /// OpenIM 3.8.3+hotfix.3.1 的 iOS 回调原本是空方法，SDK 在运行时补上了转发。
    public func sendTyping(conversationId: String, focus: Bool) async throws {
        guard isLoggedIn else { throw SyImError.notLoggedIn }
        try await client.sendTyping(
            conversationId: try requireId(conversationId, name: "conversationId"),
            focus: focus
        )
    }

    /// 自己的自定义资料，写入 OpenIM 用户 `ex`。
    public func setSelfCustomInfo(_ ex: String) async throws {
        guard isLoggedIn else { throw SyImError.notLoggedIn }
        try await client.setSelfEx(ex)
    }

    public func getSelfCustomInfo() async throws -> String? {
        guard isLoggedIn else { throw SyImError.notLoggedIn }
        return try await client.selfEx()
    }

    /// 群自定义资料，写入 OpenIM 群 `ex`。先读再写，避免清掉其他字段。
    public func setGroupCustomInfo(groupId: String, ex: String) async throws {
        guard isLoggedIn else { throw SyImError.notLoggedIn }
        try await client.setGroupEx(groupId: try requireId(groupId, name: "groupId"), ex: ex)
    }

    public func addToBlacklist(userId: String) async throws {
        guard isLoggedIn else { throw SyImError.notLoggedIn }
        try await client.addBlacklist(userId: try requireId(userId, name: "userId"))
    }

    public func removeFromBlacklist(userId: String) async throws {
        guard isLoggedIn else { throw SyImError.notLoggedIn }
        try await client.removeBlacklist(userId: try requireId(userId, name: "userId"))
    }

    public func getBlacklist() async throws -> [SyImUserBrief] {
        guard isLoggedIn else { throw SyImError.notLoggedIn }
        return try await client.blacklist()
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

    // MARK: - 表情回应（lite）与会话标签（控制面）

    /// 对一条消息加 / 取消表情回应。`POST /api/user/im/reaction`。
    ///
    /// 服务端以 Custom(110) 消息发出（`data` 里 `sy=reaction_lite`），对端按普通自定义消息收到，用
    /// `SyImReaction.parse(_:)` 解析。不是 OpenIM 原生回应接口，也没有服务端聚合计数。
    /// 单聊传 `toUserId`，群聊传 `groupId`；目标消息用 `targetClientMsgId` 或 `targetSeq`。
    @discardableResult
    public func reactToMessage(
        fromUserId: String,
        emoji: String,
        toUserId: String? = nil,
        groupId: String? = nil,
        targetClientMsgId: String? = nil,
        targetSeq: Int64 = 0,
        targetSenderId: String? = nil,
        add: Bool = true
    ) async throws -> [String: Any] {
        let body = SyImReaction.requestBody(
            fromUserId: try requireId(fromUserId, name: "fromUserId"), emoji: emoji,
            toUserId: toUserId, groupId: groupId, targetClientMsgId: targetClientMsgId,
            targetSeq: targetSeq, targetSenderId: targetSenderId, add: add)
        return try await controlPlaneObject(path: "/api/user/im/reaction", body: body)
    }

    /// 新建会话标签（每个用户自己的分组，存在 SY 服务端）。返回值含 `tag`。
    @discardableResult
    public func createConversationTag(ownerUserId: String, name: String, color: String = "", remark: String = "") async throws -> [String: Any] {
        try await controlPlaneObject(path: "/api/user/im/conversations/tags/create", body: [
            "ownerUserId": try requireId(ownerUserId, name: "ownerUserId"),
            "name": try requireId(name, name: "name"), "color": color, "remark": remark,
        ])
    }

    /// 列出会话标签。`list` 每项含 `id` / `name` / `memberCount` / `members`（会话 id，最多 200）。
    public func listConversationTags(ownerUserId: String) async throws -> [String: Any] {
        try await controlPlaneObject(path: "/api/user/im/conversations/tags/list", body: [
            "ownerUserId": try requireId(ownerUserId, name: "ownerUserId"),
        ])
    }

    /// 删除会话标签。
    public func deleteConversationTag(ownerUserId: String, tagId: Int64) async throws {
        _ = try await controlPlaneObject(path: "/api/user/im/conversations/tags/delete", body: [
            "ownerUserId": try requireId(ownerUserId, name: "ownerUserId"), "tagId": tagId,
        ])
    }

    /// 把会话加入标签。
    public func addConversationsToTag(ownerUserId: String, tagId: Int64, conversationIds: [String]) async throws {
        _ = try await controlPlaneObject(path: "/api/user/im/conversations/tags/members", body: [
            "ownerUserId": try requireId(ownerUserId, name: "ownerUserId"), "tagId": tagId,
            "action": "add", "conversationIds": conversationIds,
        ])
    }

    /// 把会话移出标签。
    public func removeConversationsFromTag(ownerUserId: String, tagId: Int64, conversationIds: [String]) async throws {
        _ = try await controlPlaneObject(path: "/api/user/im/conversations/tags/members", body: [
            "ownerUserId": try requireId(ownerUserId, name: "ownerUserId"), "tagId": tagId,
            "action": "remove", "conversationIds": conversationIds,
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
        try SyImErrorCode.check(httpStatus: code, json: json)
        return (json["data"] as? [String: Any]) ?? [:]
    }

    /// 控制面 REST：friends/groups/send/history/revoke（需 User JWT）。实时收发仍走 OpenIM 客户端。
    public func controlPlanePost(path: String, userJwt: String, body: [String: Any]) async throws -> [String: Any] {
        let data = try await controlPlaneData(path: path, userJwt: userJwt, body: body)
        return data as? [String: Any] ?? [:]
    }

    private func seedUnreadCache(_ conversations: [SyImConversation]) {
        unreadLock.lock()
        defer { unreadLock.unlock() }
        var next: [String: Int] = [:]
        for item in conversations {
            next[item.conversationId] = item.unreadCount
        }
        unreadByConversation = next
        let known = next.values.reduce(0, +)
        if cachedTotalUnread > known {
            untrackedUnread = cachedTotalUnread - known
        } else {
            untrackedUnread = 0
            cachedTotalUnread = known
        }
    }

    private func noteConversationUnread(conversationId: String, unreadCount: Int) -> SyImUnreadUpdate {
        unreadLock.lock()
        defer { unreadLock.unlock() }
        let old = unreadByConversation[conversationId] ?? 0
        let knownBefore = unreadByConversation.values.reduce(0, +)
        let delta = unreadCount - old
        unreadByConversation[conversationId] = unreadCount
        let knownAfter = knownBefore + delta
        if delta > 0 {
            // 总未读回调若先到，多出来的部分在 untracked，这里扣掉，避免加两次。
            untrackedUnread = max(0, untrackedUnread - delta)
            cachedTotalUnread = max(0, knownAfter + untrackedUnread)
        } else if delta < 0 && cachedTotalUnread < knownBefore + untrackedUnread {
            // 总未读已经低于会话未读之和，说明服务端总数先到了，不要再减一次。
            untrackedUnread = max(0, cachedTotalUnread - knownAfter)
        } else if delta < 0 {
            cachedTotalUnread = max(0, knownAfter + untrackedUnread)
        }
        return SyImUnreadUpdate(
            totalUnreadCount: cachedTotalUnread,
            conversationId: conversationId,
            conversationUnreadCount: unreadCount
        )
    }

    private func applyServerTotal(_ count: Int) -> SyImUnreadUpdate {
        unreadLock.lock()
        defer { unreadLock.unlock() }
        let known = unreadByConversation.values.reduce(0, +)
        let total = max(0, count)
        untrackedUnread = max(0, total - known)
        cachedTotalUnread = total
        return SyImUnreadUpdate(totalUnreadCount: total)
    }

    private func resetUnreadCache() -> SyImUnreadUpdate {
        unreadLock.lock()
        defer { unreadLock.unlock() }
        unreadByConversation.removeAll()
        untrackedUnread = 0
        cachedTotalUnread = 0
        return SyImUnreadUpdate(totalUnreadCount: 0)
    }

    private func publish(_ update: SyImUnreadUpdate) {
        eventListener?.onUnreadChanged(update)
        eventListener?.onTotalUnreadCountChanged(count: update.totalUnreadCount)
        if let id = update.conversationId, let count = update.conversationUnreadCount {
            eventListener?.onConversationUnreadChanged(conversationId: id, unreadCount: count)
        }
        onUnreadChanged?(update)
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
        try SyImErrorCode.check(httpStatus: code, json: json)
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
    func imOnTotalUnreadCountChanged(count: Int) {
        publish(applyServerTotal(count))
    }
    func imOnConversationUnreadChanged(conversationId: String, unreadCount: Int) {
        publish(noteConversationUnread(conversationId: conversationId, unreadCount: unreadCount))
    }
    func imOnMessageRecalled(clientMsgId: String, revokerUserId: String) {
        eventListener?.onMessageRecalled(clientMsgId: clientMsgId, revokerUserId: revokerUserId)
    }
    func imOnRecvC2CReadReceipt(userId: String, msgIds: [String]) {
        eventListener?.onRecvC2CReadReceipt(userId: userId, msgIds: msgIds)
    }
    func imOnRecvGroupReadReceipt(groupId: String, msgIds: [String]) {
        eventListener?.onRecvGroupReadReceipt(groupId: groupId, msgIds: msgIds)
    }
    func imOnRecvFriendApplication(fromUserId: String, reqMsg: String?) {
        eventListener?.onRecvFriendApplication(fromUserId: fromUserId, reqMsg: reqMsg)
    }
    func imOnTypingStatusChanged(_ status: SyImTypingStatus) {
        eventListener?.onTypingStatusChanged(status)
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
    /// 控制面（`/api/user/im/…`）失败。`code` 为服务端业务码（见 `SyImErrorCode`），响应体没有 code 时为 HTTP 状态码。
    case controlPlane(code: Int, httpStatus: Int, message: String)

    /// 控制面业务码；其他错误为 nil。
    public var code: Int? {
        if case .controlPlane(let code, _, _) = self { return code }
        return nil
    }

    public var errorDescription: String? {
        switch self {
        case .notLoggedIn: return "login required"
        case .notInitialized: return "call SyImEngine.initialize first"
        case .invalidArgument(let s): return s
        case .openImUnreachable(let s): return s
        case .openImLoginFailed(let s): return "OpenIM login failed: \(s)"
        case .openImApi(let s): return s
        case .openImSendDenied(let s): return s
        case .controlPlane(let code, _, let message): return "[\(code)] \(message)"
        }
    }
}
