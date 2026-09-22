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
/// OpenIM iOS 无官方 SPM — 生产请用 CocoaPods（见 example/Podfile）。
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

    /// Conversation list stub — real OpenIM `getAllConversationList` when wired.
    public func getConversations() async throws -> [SyImConversation] {
        try await client.conversations()
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
        return (json["data"] as? [String: Any]) ?? [:]
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
