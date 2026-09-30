import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(os.log)
import os.log
#endif

#if canImport(UIKit)
import UIKit
#endif

private let log = OSLog(subsystem: "com.sy.im.sdk", category: "OpenImClient")

/// Events forwarded from an OpenIM client into `SyImEngine`.
protocol OpenImEventSink: AnyObject {
    func imOnConnecting()
    func imOnConnectSuccess()
    func imOnConnectFailed(code: Int, error: String)
    func imOnKickedOffline()
    func imOnUserTokenExpired()
    func imOnRecvNewMessage(msgId: String, fromUserId: String, groupId: String?, text: String?)
    func imOnTotalUnreadCountChanged(count: Int)
    func imOnConversationUnreadChanged(conversationId: String, unreadCount: Int)
    func imOnRecvC2CReadReceipt(userId: String, msgIds: [String])
    func imOnRecvGroupReadReceipt(groupId: String, msgIds: [String])
    func imOnRecvFriendApplication(fromUserId: String, reqMsg: String?)
    func imOnMessageRecalled(clientMsgId: String, revokerUserId: String)
}

/// Backend used by `SyImEngine`.
protocol OpenImClient: AnyObject {
    func setEventSink(_ sink: OpenImEventSink?)
    func initSdk(apiAddr: String, wsAddr: String) async throws
    func login(userId: String, token: String) async throws
    func logout() async throws
    func sendText(userId: String?, groupId: String?, text: String) async throws -> String
    func conversations() async throws -> [SyImConversation]
    func totalUnreadCount() async throws -> Int
    func markConversationAsRead(conversationId: String) async throws
    func receivedFriendApplications() async throws -> [SyImFriendApplication]
    func acceptFriendApplication(userId: String, handleMsg: String) async throws
    func refuseFriendApplication(userId: String, handleMsg: String) async throws
    func joinedGroups() async throws -> [SyImGroup]
    func inviteUsers(groupId: String, userIds: [String], reason: String) async throws
    func kickGroupMembers(groupId: String, userIds: [String], reason: String) async throws
    func quitGroup(groupId: String) async throws
    func dismissGroup(groupId: String) async throws
    func recall(conversationId: String, clientMsgId: String) async throws
    func sendAtText(groupId: String, text: String, atUserIds: [String], atAll: Bool) async throws -> String
    func sendCustom(userId: String?, groupId: String?, data: String, description: String?, ext: String?) async throws -> String
    func searchConversations(keyword: String) async throws -> [SyImConversation]
    func searchMessages(keyword: String, conversationId: String?) async throws -> [SyImSearchHit]
    func searchUsers(keyword: String) async throws -> [SyImUserBrief]
    func pinConversation(conversationId: String, isPinned: Bool) async throws
    func setDraft(conversationId: String, draft: String) async throws
    func setReceiveOption(conversationId: String, option: Int) async throws
    func sendTyping(conversationId: String, focus: Bool) async throws
    func setSelfEx(_ ex: String) async throws
    func selfEx() async throws -> String?
    func setGroupEx(groupId: String, ex: String) async throws
    func addBlacklist(userId: String) async throws
    func removeBlacklist(userId: String) async throws
    func blacklist() async throws -> [SyImUserBrief]
}

extension OpenImClient {
    func setEventSink(_ sink: OpenImEventSink?) {}

    func totalUnreadCount() async throws -> Int {
        throw SyImError.openImApi(OpenImClientSupport.sdkRequired("getTotalUnreadCount"))
    }

    func markConversationAsRead(conversationId: String) async throws {
        throw SyImError.openImApi(OpenImClientSupport.sdkRequired("markConversationAsRead"))
    }

    func receivedFriendApplications() async throws -> [SyImFriendApplication] {
        throw SyImError.openImApi(OpenImClientSupport.sdkRequired("getReceivedFriendApplications"))
    }

    func acceptFriendApplication(userId: String, handleMsg: String) async throws {
        throw SyImError.openImApi(OpenImClientSupport.sdkRequired("acceptFriendApplication"))
    }

    func refuseFriendApplication(userId: String, handleMsg: String) async throws {
        throw SyImError.openImApi(OpenImClientSupport.sdkRequired("refuseFriendApplication"))
    }

    func joinedGroups() async throws -> [SyImGroup] {
        throw SyImError.openImApi(OpenImClientSupport.sdkRequired("getJoinedGroups"))
    }

    func inviteUsers(groupId: String, userIds: [String], reason: String) async throws {
        throw SyImError.openImApi(OpenImClientSupport.sdkRequired("inviteToGroup"))
    }

    func kickGroupMembers(groupId: String, userIds: [String], reason: String) async throws {
        throw SyImError.openImApi(OpenImClientSupport.sdkRequired("kickFromGroup"))
    }

    func quitGroup(groupId: String) async throws {
        throw SyImError.openImApi(OpenImClientSupport.sdkRequired("quitGroup"))
    }

    func dismissGroup(groupId: String) async throws {
        throw SyImError.openImApi(OpenImClientSupport.sdkRequired("dismissGroup"))
    }

    func recall(conversationId: String, clientMsgId: String) async throws {
        throw SyImError.openImApi(OpenImClientSupport.sdkRequired("recallMessage"))
    }

    func sendAtText(groupId: String, text: String, atUserIds: [String], atAll: Bool) async throws -> String {
        _ = (groupId, text, atUserIds, atAll)
        throw SyImError.openImApi(OpenImClientSupport.sdkRequired("sendAtTextMessage"))
    }

    func sendCustom(userId: String?, groupId: String?, data: String, description: String?, ext: String?) async throws -> String {
        _ = (userId, groupId, data, description, ext)
        throw SyImError.openImApi(OpenImClientSupport.sdkRequired("sendCustomMessage"))
    }

    func searchConversations(keyword: String) async throws -> [SyImConversation] {
        _ = keyword
        throw SyImError.openImApi(OpenImClientSupport.sdkRequired("searchConversations"))
    }

    func searchMessages(keyword: String, conversationId: String?) async throws -> [SyImSearchHit] {
        _ = (keyword, conversationId)
        throw SyImError.openImApi(OpenImClientSupport.sdkRequired("searchMessages"))
    }

    func searchUsers(keyword: String) async throws -> [SyImUserBrief] {
        _ = keyword
        throw SyImError.openImApi(OpenImClientSupport.sdkRequired("searchUsers"))
    }

    func pinConversation(conversationId: String, isPinned: Bool) async throws {
        _ = (conversationId, isPinned)
        throw SyImError.openImApi(OpenImClientSupport.sdkRequired("pinConversation"))
    }

    func setDraft(conversationId: String, draft: String) async throws {
        _ = (conversationId, draft)
        throw SyImError.openImApi(OpenImClientSupport.sdkRequired("setConversationDraft"))
    }

    func setReceiveOption(conversationId: String, option: Int) async throws {
        _ = (conversationId, option)
        throw SyImError.openImApi(OpenImClientSupport.sdkRequired("setConversationReceiveOption"))
    }

    func sendTyping(conversationId: String, focus: Bool) async throws {
        _ = (conversationId, focus)
        throw SyImError.openImApi(OpenImClientSupport.sdkRequired("sendTyping"))
    }

    func setSelfEx(_ ex: String) async throws {
        _ = ex
        throw SyImError.openImApi(OpenImClientSupport.sdkRequired("setSelfCustomInfo"))
    }

    func selfEx() async throws -> String? {
        throw SyImError.openImApi(OpenImClientSupport.sdkRequired("getSelfCustomInfo"))
    }

    func setGroupEx(groupId: String, ex: String) async throws {
        _ = (groupId, ex)
        throw SyImError.openImApi(OpenImClientSupport.sdkRequired("setGroupCustomInfo"))
    }

    func addBlacklist(userId: String) async throws {
        _ = userId
        throw SyImError.openImApi(OpenImClientSupport.sdkRequired("addToBlacklist"))
    }

    func removeBlacklist(userId: String) async throws {
        _ = userId
        throw SyImError.openImApi(OpenImClientSupport.sdkRequired("removeFromBlacklist"))
    }

    func blacklist() async throws -> [SyImUserBrief] {
        throw SyImError.openImApi(OpenImClientSupport.sdkRequired("getBlacklist"))
    }
}

enum OpenImClientSupport {
    static func sdkRequired(_ op: String) -> String {
        "\(op) requires CocoaPods OpenIMSDK (pod 'SyImSDK'). " +
        "HttpWs cannot send this call. Pass backend: .openImSdk (the default)."
    }

    static func failure(_ op: String, code: Int, message: String?) -> SyImError {
        .openImApi("\(op) code=\(code) \(message ?? "")")
    }
}

// MARK: - Mock (offline / empty addresses only)

/// In-memory mock when OpenIM addresses are empty / unreachable and you only need UI compile.
final class MockOpenImClient: OpenImClient {
    private var loggedIn = false
    private var userId: String?
    private var inbox: [SyImConversation] = []
    private var applications: [SyImFriendApplication] = []
    private var groups: [SyImGroup] = []
    private var hits: [SyImSearchHit] = []
    private var blocked: [SyImUserBrief] = []
    private var selfCustomEx: String?
    private var groupEx: [String: String] = [:]
    private weak var eventSink: OpenImEventSink?

    func setEventSink(_ sink: OpenImEventSink?) {
        eventSink = sink
    }

    func initSdk(apiAddr: String, wsAddr: String) async throws {
        os_log("MockOpenImClient initSDK apiAddr=%{public}@ wsAddr=%{public}@", log: log, type: .info, apiAddr, wsAddr)
    }

    func login(userId: String, token: String) async throws {
        self.userId = userId
        loggedIn = true
        if inbox.isEmpty {
            inbox = [
                SyImConversation(
                    conversationId: "c2c_demo_peer",
                    userId: "demo_peer",
                    showName: "Demo Peer",
                    latestText: "Mock 模式（未配置 imApiAddr/imWsAddr）。",
                    unreadCount: 2
                )
            ]
        }
    }

    func logout() async throws {
        loggedIn = false
        userId = nil
    }

    func sendText(userId: String?, groupId: String?, text: String) async throws -> String {
        guard loggedIn else { throw SyImError.notLoggedIn }
        let convId = groupId ?? userId ?? "unknown"
        if let idx = inbox.firstIndex(where: {
            $0.userId == userId || $0.groupId == groupId || $0.conversationId == convId
        }) {
            inbox[idx].latestText = text
        } else {
            inbox.insert(
                SyImConversation(
                    conversationId: convId,
                    userId: userId,
                    groupId: groupId,
                    showName: userId ?? groupId,
                    latestText: text,
                    unreadCount: 0
                ),
                at: 0
            )
        }
        let id = "mock_\(Int(Date().timeIntervalSince1970 * 1000))"
        hits.insert(
            SyImSearchHit(conversationId: convId, clientMsgId: id, text: text, sendUserId: self.userId),
            at: 0
        )
        return id
    }

    func conversations() async throws -> [SyImConversation] { inbox }

    func totalUnreadCount() async throws -> Int {
        guard loggedIn else { throw SyImError.notLoggedIn }
        return inbox.reduce(0) { $0 + $1.unreadCount }
    }

    func markConversationAsRead(conversationId: String) async throws {
        guard loggedIn else { throw SyImError.notLoggedIn }
        if let idx = inbox.firstIndex(where: { $0.conversationId == conversationId }) {
            inbox[idx].unreadCount = 0
        }
    }

    func receivedFriendApplications() async throws -> [SyImFriendApplication] {
        guard loggedIn else { throw SyImError.notLoggedIn }
        return applications
    }

    func acceptFriendApplication(userId: String, handleMsg: String) async throws {
        try updateApplication(userId: userId, handleMsg: handleMsg, result: 1)
    }

    func refuseFriendApplication(userId: String, handleMsg: String) async throws {
        try updateApplication(userId: userId, handleMsg: handleMsg, result: -1)
    }

    func joinedGroups() async throws -> [SyImGroup] {
        guard loggedIn else { throw SyImError.notLoggedIn }
        return groups
    }

    func inviteUsers(groupId: String, userIds: [String], reason: String) async throws {
        guard loggedIn else { throw SyImError.notLoggedIn }
        guard groups.contains(where: { $0.groupId == groupId }) else {
            throw SyImError.invalidArgument("unknown group \(groupId)")
        }
        _ = userIds
        _ = reason
    }

    func kickGroupMembers(groupId: String, userIds: [String], reason: String) async throws {
        guard loggedIn else { throw SyImError.notLoggedIn }
        guard groups.contains(where: { $0.groupId == groupId }) else {
            throw SyImError.invalidArgument("unknown group \(groupId)")
        }
        _ = userIds
        _ = reason
    }

    func quitGroup(groupId: String) async throws {
        guard loggedIn else { throw SyImError.notLoggedIn }
        groups.removeAll { $0.groupId == groupId }
    }

    func dismissGroup(groupId: String) async throws {
        guard loggedIn else { throw SyImError.notLoggedIn }
        groups.removeAll { $0.groupId == groupId }
    }

    func recall(conversationId: String, clientMsgId: String) async throws {
        guard loggedIn else { throw SyImError.notLoggedIn }
        hits.removeAll { $0.conversationId == conversationId && $0.clientMsgId == clientMsgId }
    }

    func sendAtText(groupId: String, text: String, atUserIds: [String], atAll: Bool) async throws -> String {
        let names = atAll ? "@所有人" : atUserIds.map { "@\($0)" }.joined(separator: " ")
        let body = names.isEmpty ? text : "\(names) \(text)"
        return try await sendText(userId: nil, groupId: groupId, text: body)
    }

    func sendCustom(userId: String?, groupId: String?, data: String, description: String?, ext: String?) async throws -> String {
        _ = ext
        return try await sendText(userId: userId, groupId: groupId, text: description ?? data)
    }

    func searchConversations(keyword: String) async throws -> [SyImConversation] {
        guard loggedIn else { throw SyImError.notLoggedIn }
        return inbox.filter {
            ($0.showName ?? "").localizedCaseInsensitiveContains(keyword)
                || $0.conversationId.localizedCaseInsensitiveContains(keyword)
                || ($0.latestText ?? "").localizedCaseInsensitiveContains(keyword)
        }
    }

    func searchMessages(keyword: String, conversationId: String?) async throws -> [SyImSearchHit] {
        guard loggedIn else { throw SyImError.notLoggedIn }
        return hits.filter {
            (conversationId == nil || $0.conversationId == conversationId)
                && ($0.text ?? "").localizedCaseInsensitiveContains(keyword)
        }
    }

    func searchUsers(keyword: String) async throws -> [SyImUserBrief] {
        guard loggedIn else { throw SyImError.notLoggedIn }
        return blocked.filter {
            $0.userId.localizedCaseInsensitiveContains(keyword)
                || ($0.nickname ?? "").localizedCaseInsensitiveContains(keyword)
        }
    }

    func pinConversation(conversationId: String, isPinned: Bool) async throws {
        guard loggedIn else { throw SyImError.notLoggedIn }
        guard let idx = inbox.firstIndex(where: { $0.conversationId == conversationId }) else {
            throw SyImError.invalidArgument("unknown conversation \(conversationId)")
        }
        inbox[idx].isPinned = isPinned
    }

    func setDraft(conversationId: String, draft: String) async throws {
        guard loggedIn else { throw SyImError.notLoggedIn }
        guard let idx = inbox.firstIndex(where: { $0.conversationId == conversationId }) else {
            throw SyImError.invalidArgument("unknown conversation \(conversationId)")
        }
        inbox[idx].draftText = draft.isEmpty ? nil : draft
    }

    func setReceiveOption(conversationId: String, option: Int) async throws {
        guard loggedIn else { throw SyImError.notLoggedIn }
        guard let idx = inbox.firstIndex(where: { $0.conversationId == conversationId }) else {
            throw SyImError.invalidArgument("unknown conversation \(conversationId)")
        }
        inbox[idx].receiveOption = option
    }

    func sendTyping(conversationId: String, focus: Bool) async throws {
        guard loggedIn else { throw SyImError.notLoggedIn }
        guard inbox.contains(where: { $0.conversationId == conversationId }) else {
            throw SyImError.invalidArgument("unknown conversation \(conversationId)")
        }
        _ = focus
    }

    func setSelfEx(_ ex: String) async throws {
        guard loggedIn else { throw SyImError.notLoggedIn }
        selfCustomEx = ex
    }

    func selfEx() async throws -> String? {
        guard loggedIn else { throw SyImError.notLoggedIn }
        return selfCustomEx
    }

    func setGroupEx(groupId: String, ex: String) async throws {
        guard loggedIn else { throw SyImError.notLoggedIn }
        guard groups.contains(where: { $0.groupId == groupId }) else {
            throw SyImError.invalidArgument("unknown group \(groupId)")
        }
        groupEx[groupId] = ex
    }

    func addBlacklist(userId: String) async throws {
        guard loggedIn else { throw SyImError.notLoggedIn }
        blocked.removeAll { $0.userId == userId }
        blocked.insert(SyImUserBrief(userId: userId), at: 0)
    }

    func removeBlacklist(userId: String) async throws {
        guard loggedIn else { throw SyImError.notLoggedIn }
        blocked.removeAll { $0.userId == userId }
    }

    func blacklist() async throws -> [SyImUserBrief] {
        guard loggedIn else { throw SyImError.notLoggedIn }
        return blocked
    }

    private func updateApplication(userId: String, handleMsg: String, result: Int) throws {
        guard loggedIn else { throw SyImError.notLoggedIn }
        guard let idx = applications.firstIndex(where: { $0.fromUserId == userId && $0.handleResult == 0 }) else {
            throw SyImError.invalidArgument("no pending friend application from \(userId)")
        }
        applications[idx].handleResult = result
        applications[idx].handleMsg = handleMsg
    }
}

// MARK: - Real HTTP + WebSocket minimal OpenIM client

/// Real path against OpenIM when `imApiAddr` / `imWsAddr` are reachable.
///
/// - Login: WebSocket to msggateway with `sendID` + `token` + `platformID` (OpenIM verifies token).
/// - Conversations: REST `POST /conversation/get_all_conversations` with user token.
/// - Send text: REST `POST /msg/send_msg` (documented OpenIM API; requires admin token on stock OpenIM —
///   when user token is rejected we surface the real errCode instead of silently mocking).
///
/// Official OpenIM iOS is CocoaPods-only. HttpWs is the explicit fallback when that pod is not linked.
final class HttpWsOpenImClient: NSObject, OpenImClient, URLSessionWebSocketDelegate {
    private var apiAddr: String = ""
    private var wsAddr: String = ""
    private var userId: String?
    private var token: String?
    private var loggedIn = false
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession!
    private var localInbox: [SyImConversation] = []
    private let platformID: Int = 1 // iOS

    /// SY control-plane base (for /api/user/im/send admin-proxy fallback).
    var controlPlaneBaseURL: String = ""
    var controlPlaneAccessToken: String?
    var appId: String = ""
    private var loginContinuation: CheckedContinuation<Void, Error>?
    private var pendingLoginUserId: String?
    private var pendingLoginToken: String?
    private let stateLock = NSLock()

    override init() {
        super.init()
        let cfg = URLSessionConfiguration.default
        #if !os(Linux)
        cfg.waitsForConnectivity = true
        #endif
        cfg.timeoutIntervalForRequest = 15
        session = URLSession(configuration: cfg, delegate: self, delegateQueue: nil)
    }

    func initSdk(apiAddr: String, wsAddr: String) async throws {
        self.apiAddr = apiAddr.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.wsAddr = wsAddr
        os_log("HttpWsOpenImClient initSDK api=%{public}@ ws=%{public}@", log: log, type: .info, self.apiAddr, self.wsAddr)
        // Probe API reachability (best-effort GET). Empty body / 404 still means host is up.
        guard let url = URL(string: self.apiAddr) else {
            throw SyImError.invalidArgument("bad imApiAddr")
        }
        var req = URLRequest(url: url, timeoutInterval: 5)
        req.httpMethod = "GET"
        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse {
                os_log("OpenIM API probe status=%{public}d", log: log, type: .info, http.statusCode)
            }
        } catch {
            // Try again with a trailing slash path — some setups only answer under /auth
            if let auth = URL(string: self.apiAddr + "/auth/parse_token") {
                var r2 = URLRequest(url: auth, timeoutInterval: 5)
                r2.httpMethod = "POST"
                r2.setValue("application/json", forHTTPHeaderField: "Content-Type")
                r2.httpBody = Data("{}".utf8)
                do {
                    _ = try await URLSession.shared.data(for: r2)
                } catch {
                    throw SyImError.openImUnreachable("imApiAddr \(self.apiAddr) unreachable: \(error.localizedDescription)")
                }
            } else {
                throw SyImError.openImUnreachable("imApiAddr \(self.apiAddr) unreachable: \(error.localizedDescription)")
            }
        }
    }

    func login(userId: String, token: String) async throws {
        guard !apiAddr.isEmpty, !wsAddr.isEmpty else {
            throw SyImError.invalidArgument("imApiAddr/imWsAddr required for real OpenIM login")
        }
        guard !userId.isEmpty, !token.isEmpty else {
            throw SyImError.invalidArgument("userId/token required")
        }
        // Close previous
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil

        guard var comps = URLComponents(string: wsAddr) else {
            throw SyImError.invalidArgument("bad imWsAddr")
        }
        var items = comps.queryItems ?? []
        items.removeAll { ["sendID", "token", "platformID"].contains($0.name) }
        items.append(URLQueryItem(name: "sendID", value: userId))
        items.append(URLQueryItem(name: "token", value: token))
        items.append(URLQueryItem(name: "platformID", value: String(platformID)))
        comps.queryItems = items
        guard let url = comps.url else {
            throw SyImError.invalidArgument("failed to build OpenIM WS URL")
        }

        os_log("OpenIM WS login %{public}@", log: log, type: .info, url.absoluteString.replacingOccurrences(of: token, with: "***"))

        pendingLoginUserId = userId
        pendingLoginToken = token
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            stateLock.lock()
            loginContinuation = cont
            stateLock.unlock()
            let task = session.webSocketTask(with: url)
            webSocketTask = task
            task.resume()
            // Success → urlSession(_:webSocketTask:didOpenWithProtocol:)
            // Failure → urlSession(_:task:didCompleteWithError:)
            // Timeout safety
            DispatchQueue.global().asyncAfter(deadline: .now() + 12) { [weak self] in
                guard let self else { return }
                self.stateLock.lock()
                let pending = self.loginContinuation
                self.loginContinuation = nil
                self.stateLock.unlock()
                pending?.resume(throwing: SyImError.openImLoginFailed("WebSocket login timeout (12s)"))
            }
        }
    }

    func logout() async throws {
        loggedIn = false
        userId = nil
        token = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
    }

    func sendText(userId: String?, groupId: String?, text: String) async throws -> String {
        guard loggedIn, let sendID = self.userId, let tok = self.token else {
            throw SyImError.notLoggedIn
        }
        // Documented OpenIM REST: POST /msg/send_msg
        // Stock OpenIM requires admin token; we still hit the real endpoint and surface errCode.
        let sessionType = (groupId?.isEmpty == false) ? 3 : 1
        let recvID = groupId ?? userId ?? ""
        let body: [String: Any] = [
            "sendID": sendID,
            "recvID": sessionType == 1 ? recvID : "",
            "groupID": sessionType == 3 ? recvID : "",
            "senderPlatformID": platformID,
            "contentType": 101,
            "sessionType": sessionType,
            "content": ["content": text],
        ]
        let data = try await postJSON(path: "/msg/send_msg", body: body, token: tok)
        // Prefer server clientMsgID / serverMsgID when present
        let msgId: String
        if let d = data["data"] as? [String: Any] {
            msgId = (d["clientMsgID"] as? String)
                ?? (d["serverMsgID"] as? String)
                ?? "sent_\(Int(Date().timeIntervalSince1970 * 1000))"
        } else if let errCode = data["errCode"] as? Int, errCode != 0 {
            let msg = (data["errMsg"] as? String) ?? "send_msg failed"
            // Fallback: if REST rejects user token (admin-only), keep local echo so UI still usable,
            // but mark message id with openim_rest_denied so it's not silent mock success.
            if errCode == 1001 || errCode == 1501 || errCode == 1002 || msg.lowercased().contains("permission") || msg.lowercased().contains("admin") {
                let localId = "local_\(Int(Date().timeIntervalSince1970 * 1000))"
                rememberOutgoing(userId: userId, groupId: groupId, text: text)
                throw SyImError.openImSendDenied(
                    "OpenIM /msg/send_msg errCode=\(errCode) \(msg). " +
                    "Login/WS is real; send_msg needs admin token or official OpenIMSDK. localId=\(localId)"
                )
            }
            throw SyImError.openImApi("send_msg errCode=\(errCode) \(msg)")
        } else {
            msgId = "sent_\(Int(Date().timeIntervalSince1970 * 1000))"
        }
        rememberOutgoing(userId: userId, groupId: groupId, text: text)
        return msgId
    }

    func conversations() async throws -> [SyImConversation] {
        guard loggedIn, let uid = userId, let tok = token else {
            throw SyImError.notLoggedIn
        }
        do {
            let data = try await postJSON(
                path: "/conversation/get_all_conversations",
                body: ["ownerUserID": uid],
                token: tok
            )
            if let errCode = data["errCode"] as? Int, errCode != 0 {
                os_log("get_all_conversations errCode=%{public}d — using local cache", log: log, type: .info, errCode)
                return localInbox
            }
            let list = (data["data"] as? [[String: Any]])
                ?? ((data["data"] as? [String: Any])?["conversations"] as? [[String: Any]])
                ?? []
            let mapped: [SyImConversation] = list.map { c in
                let latest = c["latestMsg"] as? [String: Any]
                let textElem = latest?["content"] as? String
                    ?? (latest?["textElem"] as? [String: Any])?["content"] as? String
                return SyImConversation(
                    conversationId: (c["conversationID"] as? String) ?? "",
                    userId: c["userID"] as? String,
                    groupId: c["groupID"] as? String,
                    showName: c["showName"] as? String,
                    latestText: textElem,
                    unreadCount: (c["unreadCount"] as? Int) ?? 0
                )
            }
            if !mapped.isEmpty {
                localInbox = mapped
            }
            return mapped.isEmpty ? localInbox : mapped
        } catch {
            os_log("conversations REST failed: %{public}@", log: log, type: .info, error.localizedDescription)
            return localInbox
        }
    }

    /// Sum of conversation unread counts. HttpWs has no read-receipt frame.
    func totalUnreadCount() async throws -> Int {
        let list = try await conversations()
        return list.reduce(0) { $0 + $1.unreadCount }
    }

    // MARK: - Helpers

    private func rememberOutgoing(userId: String?, groupId: String?, text: String) {
        let convId = groupId ?? userId ?? "unknown"
        if let idx = localInbox.firstIndex(where: {
            $0.userId == userId || $0.groupId == groupId || $0.conversationId == convId
        }) {
            localInbox[idx].latestText = text
        } else {
            localInbox.insert(
                SyImConversation(
                    conversationId: convId,
                    userId: userId,
                    groupId: groupId,
                    showName: userId ?? groupId,
                    latestText: text,
                    unreadCount: 0
                ),
                at: 0
            )
        }
    }

    private func postJSON(path: String, body: [String: Any], token: String) async throws -> [String: Any] {
        guard let url = URL(string: apiAddr + path) else {
            throw SyImError.invalidArgument("bad path \(path)")
        }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(UUID().uuidString, forHTTPHeaderField: "operationID")
        req.setValue(token, forHTTPHeaderField: "token")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode >= 400 {
            let raw = String(data: data, encoding: .utf8) ?? ""
            throw SyImError.openImApi("HTTP \(http.statusCode) \(path): \(raw)")
        }
        let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        return obj
    }

    private func listenWebSocket() {
        #if os(Linux)
        // swift-corelibs 只有 async receive。iOS 仍走下面的 completion。
        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await self.webSocketTask?.receive()
                self.listenWebSocket()
            } catch {
                os_log("OpenIM WS receive error: %{public}@", log: log, type: .error, error.localizedDescription)
            }
        }
        #else
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                os_log("OpenIM WS receive error: %{public}@", log: log, type: .error, error.localizedDescription)
            case .success:
                // Binary gob/protobuf frames — keep connection alive; full decode needs OpenIMSDK.
                self.listenWebSocket()
            }
        }
        #endif
    }

    // MARK: URLSessionWebSocketDelegate

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        os_log("OpenIM WS didOpen", log: log, type: .info)
        userId = pendingLoginUserId
        token = pendingLoginToken
        loggedIn = true
        listenWebSocket()
        stateLock.lock()
        let pending = loginContinuation
        loginContinuation = nil
        stateLock.unlock()
        pending?.resume()
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        _ = (closeCode, reason)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error else { return }
        os_log("OpenIM WS complete error: %{public}@", log: log, type: .error, error.localizedDescription)
        stateLock.lock()
        let pending = loginContinuation
        loginContinuation = nil
        stateLock.unlock()
        pending?.resume(throwing: SyImError.openImLoginFailed(error.localizedDescription))
        loggedIn = false
    }
}


// MARK: - Missing OpenIMSDK (SPM-only / no CocoaPods)

/// Thrown-path stub when `backend: .openImSdk` but OpenIMSDK module is not linked.
/// Fix: `pod install` with SyImSDK.podspec / example Podfile, or pass `backend: .httpWs`.
final class MissingOpenImSdkClient: OpenImClient {
    private func fail(_ op: String) -> SyImError {
        .openImApi(
            "OpenIMSDK not linked (\(op)). Default path requires CocoaPods OpenIMSDK " +
            "3.8.3+hotfix.3.1 (see SyImSDK.podspec / example/Podfile). " +
            "Explicit fallback: SyImEngine.initialize(..., backend: .httpWs)."
        )
    }

    func initSdk(apiAddr: String, wsAddr: String) async throws { throw fail("initSdk") }
    func login(userId: String, token: String) async throws { throw fail("login") }
    func logout() async throws { throw fail("logout") }
    func sendText(userId: String?, groupId: String?, text: String) async throws -> String { throw fail("sendText") }
    func conversations() async throws -> [SyImConversation] { throw fail("conversations") }
}

#if canImport(OpenIMSDK)
import OpenIMSDK

/// Full OpenIM path — DEFAULT when CocoaPods links `OpenIMSDK` 3.8.3+hotfix.3.1 (SyImSDK.podspec).
/// Official send/recv uses native WS binary protocol (not REST /msg/send_msg).
final class RealOpenImClient: NSObject, OpenImClient {
    private var apiAddr: String = ""
    private var wsAddr: String = ""
    private var loggedIn = false
    private weak var eventSink: OpenImEventSink?

    func setEventSink(_ sink: OpenImEventSink?) {
        eventSink = sink
    }

    func initSdk(apiAddr: String, wsAddr: String) async throws {
        self.apiAddr = apiAddr.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.wsAddr = wsAddr
        let config = OIMInitConfig()
        config.apiAddr = self.apiAddr
        config.wsAddr = self.wsAddr
        config.logLevel = 5
        // objectStorage lives on OIMManager (not OIMInitConfig) in OpenIMSDK 3.8.3+hotfix.3.1
        OIMManager.manager.objectStorage = "minio"
        wireListeners()
        let ok = OIMManager.manager.initSDK(
            with: config,
            onConnecting: { [weak self] in
                self?.eventSink?.imOnConnecting()
            },
            onConnectFailure: { [weak self] code, msg in
                os_log("OpenIMSDK connectFailure code=%{public}ld %{public}@", log: log, type: .error, code, msg ?? "")
                self?.eventSink?.imOnConnectFailed(code: Int(code), error: msg ?? "")
            },
            onConnectSuccess: { [weak self] in
                self?.eventSink?.imOnConnectSuccess()
            },
            onKickedOffline: { [weak self] in
                self?.eventSink?.imOnKickedOffline()
            },
            onUserTokenExpired: { [weak self] in
                self?.eventSink?.imOnUserTokenExpired()
            },
            onUserTokenInvalid: { [weak self] err in
                self?.eventSink?.imOnConnectFailed(code: -1, error: err ?? "user token invalid")
            }
        )
        if !ok {
            throw SyImError.openImApi("OIMManager.initSDKWithConfig returned false")
        }
    }

    /// Message / unread / friend callbacks. `login` calls `setListener`, which registers them.
    private func wireListeners() {
        let cb = OIMManager.callbacker
        cb.onRecvNewMessage = { [weak self] msg in
            guard let msg else { return }
            let groupId = (msg.groupID?.isEmpty == false) ? msg.groupID : nil
            self?.eventSink?.imOnRecvNewMessage(
                msgId: msg.clientMsgID ?? "",
                fromUserId: msg.sendID ?? "",
                groupId: groupId,
                text: msg.textElem?.content
            )
        }
        cb.onRecvC2CReadReceipt = { [weak self] list in
            for item in list ?? [] {
                self?.eventSink?.imOnRecvC2CReadReceipt(
                    userId: item.userID ?? "",
                    msgIds: item.msgIDList ?? []
                )
            }
        }
        cb.onRecvGroupReadReceipt = { [weak self] list in
            for item in list ?? [] {
                self?.eventSink?.imOnRecvGroupReadReceipt(
                    groupId: item.groupID ?? "",
                    msgIds: item.msgIDList ?? []
                )
            }
        }
        cb.onTotalUnreadMessageCountChanged = { [weak self] count in
            self?.eventSink?.imOnTotalUnreadCountChanged(count: Int(count))
        }
        cb.onConversationChanged = { [weak self] list in
            self?.forwardConversationUnread(list)
        }
        cb.onNewConversation = { [weak self] list in
            self?.forwardConversationUnread(list)
        }
        cb.onRecvMessageRevoked = { [weak self] info in
            self?.eventSink?.imOnMessageRecalled(
                clientMsgId: info?.clientMsgID ?? "",
                revokerUserId: info?.revokerID ?? ""
            )
        }
        cb.onFriendApplicationAdded = { [weak self] application in
            self?.eventSink?.imOnRecvFriendApplication(
                fromUserId: application?.fromUserID ?? "",
                reqMsg: application?.reqMsg
            )
        }
    }

    private func forwardConversationUnread(_ list: [OIMConversationInfo]?) {
        for item in list ?? [] {
            let id = item.conversationID ?? ""
            guard !id.isEmpty else { continue }
            eventSink?.imOnConversationUnreadChanged(
                conversationId: id,
                unreadCount: Int(item.unreadCount)
            )
        }
    }

    func login(userId: String, token: String) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            OIMManager.manager.login(userId, token: token, onSuccess: { _ in
                self.loggedIn = true
                cont.resume()
            }, onFailure: { code, msg in
                cont.resume(throwing: SyImError.openImLoginFailed("code=\(code) \(msg ?? "")"))
            })
        }
    }

    func logout() async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            OIMManager.manager.logoutWith(onSuccess: { _ in
                self.loggedIn = false
                cont.resume()
            }, onFailure: { code, msg in
                cont.resume(throwing: SyImError.openImApi("logout code=\(code) \(msg ?? "")"))
            })
        }
    }

    func sendText(userId: String?, groupId: String?, text: String) async throws -> String {
        guard loggedIn else { throw SyImError.notLoggedIn }
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            let msg = OIMMessageInfo.createTextMessage(text)
            OIMManager.manager.sendMessage(
                msg,
                recvID: userId,
                groupID: groupId,
                offlinePushInfo: nil,
                onSuccess: { info in
                    let id = info?.clientMsgID ?? "sdk_\(Int(Date().timeIntervalSince1970 * 1000))"
                    cont.resume(returning: id)
                },
                onProgress: { _ in },
                onFailure: { code, m in
                    cont.resume(throwing: SyImError.openImApi("send code=\(code) \(m ?? "")"))
                }
            )
        }
    }

    func conversations() async throws -> [SyImConversation] {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[SyImConversation], Error>) in
            OIMManager.manager.getAllConversationListWith(onSuccess: { list in
                let mapped = (list ?? []).map { Self.mapConversation($0) }
                cont.resume(returning: mapped)
            }, onFailure: { code, msg in
                cont.resume(throwing: SyImError.openImApi("conversations code=\(code) \(msg ?? "")"))
            })
        }
    }

    func totalUnreadCount() async throws -> Int {
        guard loggedIn else { throw SyImError.notLoggedIn }
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Int, Error>) in
            OIMManager.manager.getTotalUnreadMsgCountWith(onSuccess: { number in
                cont.resume(returning: Int(number))
            }, onFailure: { code, msg in
                cont.resume(throwing: OpenImClientSupport.failure("getTotalUnreadCount", code: Int(code), message: msg))
            })
        }
    }

    func markConversationAsRead(conversationId: String) async throws {
        guard loggedIn else { throw SyImError.notLoggedIn }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            OIMManager.manager.markConversationMessage(asRead: conversationId, onSuccess: { _ in
                cont.resume()
            }, onFailure: { code, msg in
                cont.resume(throwing: OpenImClientSupport.failure("markConversationAsRead", code: Int(code), message: msg))
            })
        }
    }

    func receivedFriendApplications() async throws -> [SyImFriendApplication] {
        guard loggedIn else { throw SyImError.notLoggedIn }
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[SyImFriendApplication], Error>) in
            OIMManager.manager.getFriendApplicationListAsRecipientWith(onSuccess: { list in
                let mapped = (list ?? []).map { item in
                    SyImFriendApplication(
                        fromUserId: item.fromUserID ?? "",
                        fromNickname: item.fromNickname,
                        toUserId: item.toUserID,
                        reqMsg: item.reqMsg,
                        handleResult: item.handleResult.rawValue,
                        handleMsg: item.handleMsg
                    )
                }
                cont.resume(returning: mapped)
            }, onFailure: { code, msg in
                cont.resume(throwing: OpenImClientSupport.failure("getReceivedFriendApplications", code: Int(code), message: msg))
            })
        }
    }

    func acceptFriendApplication(userId: String, handleMsg: String) async throws {
        guard loggedIn else { throw SyImError.notLoggedIn }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            OIMManager.manager.acceptFriendApplication(userId, handleMsg: handleMsg, onSuccess: { _ in
                cont.resume()
            }, onFailure: { code, msg in
                cont.resume(throwing: OpenImClientSupport.failure("acceptFriendApplication", code: Int(code), message: msg))
            })
        }
    }

    func refuseFriendApplication(userId: String, handleMsg: String) async throws {
        guard loggedIn else { throw SyImError.notLoggedIn }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            OIMManager.manager.refuseFriendApplication(userId, handleMsg: handleMsg, onSuccess: { _ in
                cont.resume()
            }, onFailure: { code, msg in
                cont.resume(throwing: OpenImClientSupport.failure("refuseFriendApplication", code: Int(code), message: msg))
            })
        }
    }

    func joinedGroups() async throws -> [SyImGroup] {
        guard loggedIn else { throw SyImError.notLoggedIn }
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[SyImGroup], Error>) in
            OIMManager.manager.getJoinedGroupListWith(onSuccess: { list in
                let mapped = (list ?? []).map { Self.mapGroup($0) }
                cont.resume(returning: mapped)
            }, onFailure: { code, msg in
                cont.resume(throwing: OpenImClientSupport.failure("getJoinedGroups", code: Int(code), message: msg))
            })
        }
    }

    func inviteUsers(groupId: String, userIds: [String], reason: String) async throws {
        guard loggedIn else { throw SyImError.notLoggedIn }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            OIMManager.manager.inviteUser(toGroup: groupId, reason: reason, usersID: userIds, onSuccess: { _ in
                cont.resume()
            }, onFailure: { code, msg in
                cont.resume(throwing: OpenImClientSupport.failure("inviteToGroup", code: Int(code), message: msg))
            })
        }
    }

    func kickGroupMembers(groupId: String, userIds: [String], reason: String) async throws {
        guard loggedIn else { throw SyImError.notLoggedIn }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            OIMManager.manager.kickGroupMember(groupId, reason: reason, usersID: userIds, onSuccess: { _ in
                cont.resume()
            }, onFailure: { code, msg in
                cont.resume(throwing: OpenImClientSupport.failure("kickFromGroup", code: Int(code), message: msg))
            })
        }
    }

    func quitGroup(groupId: String) async throws {
        guard loggedIn else { throw SyImError.notLoggedIn }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            OIMManager.manager.quitGroup(groupId, onSuccess: { _ in
                cont.resume()
            }, onFailure: { code, msg in
                cont.resume(throwing: OpenImClientSupport.failure("quitGroup", code: Int(code), message: msg))
            })
        }
    }

    func dismissGroup(groupId: String) async throws {
        guard loggedIn else { throw SyImError.notLoggedIn }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            OIMManager.manager.dismissGroup(groupId, onSuccess: { _ in
                cont.resume()
            }, onFailure: { code, msg in
                cont.resume(throwing: OpenImClientSupport.failure("dismissGroup", code: Int(code), message: msg))
            })
        }
    }

    func recall(conversationId: String, clientMsgId: String) async throws {
        guard loggedIn else { throw SyImError.notLoggedIn }
        try await awaitAck("recallMessage") { success, failure in
            OIMManager.manager.revokeMessage(conversationId, clientMsgID: clientMsgId, onSuccess: success, onFailure: failure)
        }
    }

    func sendAtText(groupId: String, text: String, atUserIds: [String], atAll: Bool) async throws -> String {
        guard loggedIn else { throw SyImError.notLoggedIn }
        let message: OIMMessageInfo
        if atAll {
            message = OIMMessageInfo.createText(atAllMessage: text, displayText: "@所有人", message: nil)
        } else {
            let infos: [OIMAtInfo] = atUserIds.map { uid in
                let info = OIMAtInfo()
                info.atUserID = uid
                info.groupNickname = uid
                return info
            }
            message = OIMMessageInfo.createText(atMessage: text, atUsersID: atUserIds, atUsersInfo: infos, message: nil)
        }
        return try await sendPrepared(message, userId: nil, groupId: groupId)
    }

    func sendCustom(userId: String?, groupId: String?, data: String, description: String?, ext: String?) async throws -> String {
        guard loggedIn else { throw SyImError.notLoggedIn }
        let message = OIMMessageInfo.createCustomMessage(data, extension: ext, description: description)
        return try await sendPrepared(message, userId: userId, groupId: groupId)
    }

    func searchConversations(keyword: String) async throws -> [SyImConversation] {
        guard loggedIn else { throw SyImError.notLoggedIn }
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[SyImConversation], Error>) in
            OIMManager.manager.searchConversation(keyword, onSuccess: { list in
                cont.resume(returning: (list ?? []).map { Self.mapConversation($0) })
            }, onFailure: { code, msg in
                cont.resume(throwing: OpenImClientSupport.failure("searchConversations", code: Int(code), message: msg))
            })
        }
    }

    func searchMessages(keyword: String, conversationId: String?) async throws -> [SyImSearchHit] {
        guard loggedIn else { throw SyImError.notLoggedIn }
        let param = OIMSearchParam()
        param.keywordList = [keyword]
        param.conversationID = conversationId ?? ""
        param.pageIndex = 1
        param.count = 20
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[SyImSearchHit], Error>) in
            OIMManager.manager.searchLocalMessages(param, onSuccess: { result in
                var hits: [SyImSearchHit] = []
                for item in result?.searchResultItems ?? [] {
                    for msg in item.messageList {
                        hits.append(SyImSearchHit(
                            conversationId: item.conversationID,
                            clientMsgId: msg.clientMsgID,
                            text: msg.textElem?.content ?? msg.content,
                            sendUserId: msg.sendID
                        ))
                    }
                }
                cont.resume(returning: hits)
            }, onFailure: { code, msg in
                cont.resume(throwing: OpenImClientSupport.failure("searchMessages", code: Int(code), message: msg))
            })
        }
    }

    func searchUsers(keyword: String) async throws -> [SyImUserBrief] {
        guard loggedIn else { throw SyImError.notLoggedIn }
        let param = OIMSearchFriendsParam()
        param.keywordList = [keyword]
        param.isSearchUserID = true
        param.isSearchNickname = true
        param.isSearchRemark = true
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[SyImUserBrief], Error>) in
            OIMManager.manager.searchFriends(param, onSuccess: { list in
                let mapped = (list ?? []).map {
                    SyImUserBrief(userId: $0.userID ?? "", nickname: $0.nickname, faceURL: $0.faceURL, ex: $0.ex)
                }
                cont.resume(returning: mapped)
            }, onFailure: { code, msg in
                cont.resume(throwing: OpenImClientSupport.failure("searchUsers", code: Int(code), message: msg))
            })
        }
    }

    func pinConversation(conversationId: String, isPinned: Bool) async throws {
        guard loggedIn else { throw SyImError.notLoggedIn }
        try await awaitAck("pinConversation") { success, failure in
            OIMManager.manager.pinConversation(conversationId, isPinned: isPinned, onSuccess: success, onFailure: failure)
        }
    }

    func setDraft(conversationId: String, draft: String) async throws {
        guard loggedIn else { throw SyImError.notLoggedIn }
        try await awaitAck("setConversationDraft") { success, failure in
            OIMManager.manager.setConversationDraft(conversationId, draftText: draft, onSuccess: success, onFailure: failure)
        }
    }

    func setReceiveOption(conversationId: String, option: Int) async throws {
        guard loggedIn else { throw SyImError.notLoggedIn }
        let status: OIMReceiveMessageOpt
        switch option {
        case SyImReceiveOption.notReceive.rawValue: status = .notReceive
        case SyImReceiveOption.notNotify.rawValue: status = .notNotify
        default: status = .receive
        }
        try await awaitAck("setConversationReceiveOption") { success, failure in
            OIMManager.manager.setConversationRecvMessageOpt(conversationId, status: status, onSuccess: success, onFailure: failure)
        }
    }

    func sendTyping(conversationId: String, focus: Bool) async throws {
        guard loggedIn else { throw SyImError.notLoggedIn }
        // 3.8.3+hotfix.3.1 的 OIMCallbacker.onConversationUserInputStatusChanged: 是空方法，收不到对端正在输入。
        try await awaitAck("sendTyping") { success, failure in
            OIMManager.manager.changeInputStates(conversationId, focus: focus, onSuccess: success, onFailure: failure)
        }
    }

    func setSelfEx(_ ex: String) async throws {
        guard loggedIn else { throw SyImError.notLoggedIn }
        let current: OIMUserInfo = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<OIMUserInfo, Error>) in
            OIMManager.manager.getSelfInfoWith(onSuccess: { user in
                cont.resume(returning: user ?? OIMUserInfo())
            }, onFailure: { code, msg in
                cont.resume(throwing: OpenImClientSupport.failure("getSelfCustomInfo", code: Int(code), message: msg))
            })
        }
        current.ex = ex
        try await awaitAck("setSelfCustomInfo") { success, failure in
            OIMManager.manager.setSelfInfo(current, onSuccess: success, onFailure: failure)
        }
    }

    func selfEx() async throws -> String? {
        guard loggedIn else { throw SyImError.notLoggedIn }
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String?, Error>) in
            OIMManager.manager.getSelfInfoWith(onSuccess: { user in
                cont.resume(returning: user?.ex)
            }, onFailure: { code, msg in
                cont.resume(throwing: OpenImClientSupport.failure("getSelfCustomInfo", code: Int(code), message: msg))
            })
        }
    }

    func setGroupEx(groupId: String, ex: String) async throws {
        guard loggedIn else { throw SyImError.notLoggedIn }
        let info: OIMGroupInfo = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<OIMGroupInfo, Error>) in
            OIMManager.manager.getSpecifiedGroupsInfo([groupId], onSuccess: { list in
                let group = list?.first ?? OIMGroupInfo()
                group.groupID = groupId
                cont.resume(returning: group)
            }, onFailure: { code, msg in
                cont.resume(throwing: OpenImClientSupport.failure("setGroupCustomInfo", code: Int(code), message: msg))
            })
        }
        info.ex = ex
        try await awaitAck("setGroupCustomInfo") { success, failure in
            OIMManager.manager.setGroupInfo(info, onSuccess: success, onFailure: failure)
        }
    }

    func addBlacklist(userId: String) async throws {
        guard loggedIn else { throw SyImError.notLoggedIn }
        try await awaitAck("addToBlacklist") { success, failure in
            OIMManager.manager.add(toBlackList: userId, onSuccess: success, onFailure: failure)
        }
    }

    func removeBlacklist(userId: String) async throws {
        guard loggedIn else { throw SyImError.notLoggedIn }
        try await awaitAck("removeFromBlacklist") { success, failure in
            OIMManager.manager.remove(fromBlackList: userId, onSuccess: success, onFailure: failure)
        }
    }

    func blacklist() async throws -> [SyImUserBrief] {
        guard loggedIn else { throw SyImError.notLoggedIn }
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[SyImUserBrief], Error>) in
            OIMManager.manager.getBlackListWith(onSuccess: { list in
                let mapped = (list ?? []).map {
                    SyImUserBrief(userId: $0.userID ?? "", nickname: $0.nickname, faceURL: $0.faceURL, ex: $0.ex)
                }
                cont.resume(returning: mapped)
            }, onFailure: { code, msg in
                cont.resume(throwing: OpenImClientSupport.failure("getBlacklist", code: Int(code), message: msg))
            })
        }
    }

    private func sendPrepared(_ message: OIMMessageInfo, userId: String?, groupId: String?) async throws -> String {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            OIMManager.manager.sendMessage(
                message,
                recvID: userId,
                groupID: groupId,
                offlinePushInfo: nil,
                onSuccess: { info in
                    cont.resume(returning: info?.clientMsgID ?? "sdk_\(Int(Date().timeIntervalSince1970 * 1000))")
                },
                onProgress: { _ in },
                onFailure: { code, msg in
                    cont.resume(throwing: SyImError.openImApi("send code=\(code) \(msg ?? "")"))
                }
            )
        }
    }

    private func awaitAck(
        _ op: String,
        _ body: (@escaping (String?) -> Void, @escaping (Int, String?) -> Void) -> Void
    ) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            body({ _ in
                cont.resume()
            }, { code, msg in
                cont.resume(throwing: OpenImClientSupport.failure(op, code: code, message: msg))
            })
        }
    }

    private static func mapConversation(_ c: OIMConversationInfo) -> SyImConversation {
        SyImConversation(
            conversationId: c.conversationID ?? "",
            userId: c.userID,
            groupId: c.groupID,
            showName: c.showName,
            latestText: c.latestMsg?.textElem?.content ?? c.latestMsg?.content,
            unreadCount: Int(c.unreadCount),
            isPinned: c.isPinned,
            draftText: c.draftText,
            receiveOption: c.recvMsgOpt.rawValue
        )
    }

    private static func mapGroup(_ info: OIMGroupInfo) -> SyImGroup {
        SyImGroup(
            groupId: info.groupID ?? "",
            groupName: info.groupName,
            memberCount: info.memberCount,
            ownerUserId: info.ownerUserID
        )
    }
}
#endif
