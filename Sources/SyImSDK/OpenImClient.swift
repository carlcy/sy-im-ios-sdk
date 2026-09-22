import Foundation
import os.log

#if canImport(UIKit)
import UIKit
#endif

private let log = OSLog(subsystem: "com.sy.im.sdk", category: "OpenImClient")

/// Backend used by `SyImEngine`.
protocol OpenImClient: AnyObject {
    func initSdk(apiAddr: String, wsAddr: String) async throws
    func login(userId: String, token: String) async throws
    func logout() async throws
    func sendText(userId: String?, groupId: String?, text: String) async throws -> String
    func conversations() async throws -> [SyImConversation]
}

// MARK: - Mock (offline / empty addresses only)

/// In-memory mock when OpenIM addresses are empty / unreachable and you only need UI compile.
final class MockOpenImClient: OpenImClient {
    private var loggedIn = false
    private var userId: String?
    private var inbox: [SyImConversation] = []

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
                    unreadCount: 0
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
        return "mock_\(Int(Date().timeIntervalSince1970 * 1000))"
    }

    func conversations() async throws -> [SyImConversation] { inbox }
}

// MARK: - Real HTTP + WebSocket minimal OpenIM client

/// Real path against OpenIM when `imApiAddr` / `imWsAddr` are reachable.
///
/// - Login: WebSocket to msggateway with `sendID` + `token` + `platformID` (OpenIM verifies token).
/// - Conversations: REST `POST /conversation/get_all_conversations` with user token.
/// - Send text: REST `POST /msg/send_msg` (documented OpenIM API; requires admin token on stock OpenIM —
///   when user token is rejected we surface the real errCode instead of silently mocking).
///
/// Official CocoaPods `OpenIMSDK` exists but has **no SPM**; this package stays SPM-first.
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
        cfg.waitsForConnectivity = true
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

    func initSdk(apiAddr: String, wsAddr: String) async throws {
        self.apiAddr = apiAddr.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.wsAddr = wsAddr
        let config = OIMInitConfig()
        config.apiAddr = self.apiAddr
        config.wsAddr = self.wsAddr
        config.logLevel = 5
        // objectStorage lives on OIMManager (not OIMInitConfig) in OpenIMSDK 3.8.3+hotfix.3.1
        OIMManager.manager.objectStorage = "minio"
        let ok = OIMManager.manager.initSDK(
            with: config,
            onConnecting: {},
            onConnectFailure: { code, msg in
                os_log("OpenIMSDK connectFailure code=%{public}ld %{public}@", log: log, type: .error, code, msg ?? "")
            },
            onConnectSuccess: {},
            onKickedOffline: {},
            onUserTokenExpired: {},
            onUserTokenInvalid: { _ in }
        )
        if !ok {
            throw SyImError.openImApi("OIMManager.initSDKWithConfig returned false")
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
                let mapped: [SyImConversation] = (list ?? []).map { c in
                    SyImConversation(
                        conversationId: c.conversationID ?? "",
                        userId: c.userID,
                        groupId: c.groupID,
                        showName: c.showName,
                        latestText: c.latestMsg?.textElem?.content ?? c.latestMsg?.content,
                        unreadCount: Int(c.unreadCount)
                    )
                }
                cont.resume(returning: mapped)
            }, onFailure: { code, msg in
                cont.resume(throwing: SyImError.openImApi("conversations code=\(code) \(msg ?? "")"))
            })
        }
    }
}
#endif
