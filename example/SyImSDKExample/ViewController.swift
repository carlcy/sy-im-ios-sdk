import UIKit
import SyImSDK

/// SY IM example — DEFAULT backend = OpenIMSDK (CocoaPods RealOpenImClient).
/// HttpWs only if you pass backend: .httpWs. Mock if backend: .mock / empty demo.
final class ViewController: UIViewController, UITextFieldDelegate, ImEventListener {
    private let scroll = UIScrollView()
    private let stack = UIStackView()

    private let appIdField = UITextField()
    private let apiBaseField = UITextField()
    private let imApiField = UITextField()
    private let imWsField = UITextField()
    private let userIdField = UITextField()
    private let tokenField = UITextField()
    private let jwtField = UITextField()
    private let peerField = UITextField()
    private let textField = UITextField()

    private let initBtn = UIButton(type: .system)
    private let loginBtn = UIButton(type: .system)
    private let sendBtn = UIButton(type: .system)
    private let logoutBtn = UIButton(type: .system)
    private let refreshBtn = UIButton(type: .system)
    private let fetchBtn = UIButton(type: .system)

    private let status = UILabel()
    private let convView = UITextView()
    private let logView = UITextView()

    private var engine: SyImEngine?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "SY IM Example"
        view.backgroundColor = .systemBackground
        setupUI()
        #if targetEnvironment(simulator)
        appendLog("默认 OpenIMSDK（pod install 后）。地址已预填生产 HTTPS/WSS。HttpWs 需显式 backend:.httpWs。")
        #else
        appendLog("真机：pod install → OpenIMSDK 原生收发。调试自签证书见 CLIENT_TRUST / sy-rtc-server-ca.crt。")
        #endif
    }

    @objc private func onInit() {
        SyImEngine.reset()
        let eng = SyImEngine.initialize(
            appId: val(appIdField),
            apiBaseUrl: val(apiBaseField),
            imApiAddr: val(imApiField),
            imWsAddr: val(imWsField)
        )
        eng.setEventListener(self)
        engine = eng
        Task {
            do {
                try await eng.prepare()
                await MainActor.run {
                    self.status.text = "已初始化（默认 OpenIMSDK；或显式 HttpWs/Mock）"
                    self.appendLog("prepare() ok appId=\(eng.appId)")
                }
            } catch {
                await MainActor.run {
                    self.status.text = "初始化失败"
                    self.appendLog("prepare error: \(error.localizedDescription)")
                }
            }
        }
    }


    @objc private func onFetchToken() {
        let api = val(apiBaseField).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let jwt = val(jwtField)
        let appId = val(appIdField)
        let uid = val(userIdField)
        guard !jwt.isEmpty else {
            appendLog("填写 User JWT 后才能请求 /api/user/im/token")
            return
        }
        guard let url = URL(string: api + "/api/user/im/token") else { return }
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.httpMethod = "POST"
        req.addValue("Bearer " + jwt, forHTTPHeaderField: "Authorization")
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["appId": appId, "userId": uid])
        appendLog("POST " + url.absoluteString)
        URLSession.shared.dataTask(with: req) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.appendLog("im/token error: \(error.localizedDescription)")
                    return
                }
                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    self.appendLog("im/token: bad json")
                    return
                }
                let code = json["code"] as? Int ?? -1
                if code != 0 {
                    self.appendLog("im/token fail code=\(code) msg=\(json["msg"] ?? "")")
                    return
                }
                guard let payload = json["data"] as? [String: Any] else {
                    self.appendLog("im/token: empty data")
                    return
                }
                self.tokenField.text = payload["token"] as? String ?? ""
                self.engine?.setControlPlaneAccessToken(jwt)
                if let api = payload["imApiAddr"] as? String, !api.isEmpty {
                    self.imApiField.text = api
                }
                if let ws = payload["imWsAddr"] as? String, !ws.isEmpty {
                    self.imWsField.text = ws
                }
                if let imUid = payload["imUserId"] as? String, !imUid.isEmpty {
                    self.appendLog("imUserId=\(imUid) — OpenIM login 使用此 ID（app userId 仍用于控制面）")
                    // Keep app-side userId in the field; login() below remaps if needed.
                    self.tokenField.accessibilityHint = imUid
                }
                if let v = payload["imApiAddr"] as? String, !v.isEmpty { self.imApiField.text = v }
                if let v = payload["imWsAddr"] as? String, !v.isEmpty { self.imWsField.text = v }
                self.appendLog("im/token ok")
            }
        }.resume()
    }

    @objc private func onLogin() {
        guard let engine else {
            appendLog("请先初始化")
            return
        }
        let appUid = val(userIdField)
        let token = val(tokenField)
        let appId = val(appIdField)
        // OpenIM userID is stably mapped as {appId}_{uid} by Go backend
        let openImUid: String = {
            let prefix = appId + "_"
            if appUid.hasPrefix(prefix) { return appUid }
            return prefix + appUid
        }()
        Task {
            do {
                engine.setControlPlaneAccessToken(self.val(self.jwtField))
                try await engine.login(userId: openImUid, token: token)
                await MainActor.run {
                    self.status.text = "已登录 \(openImUid)"
                    self.appendLog("login ok")
                }
                await self.reloadConversations()
            } catch {
                await MainActor.run {
                    self.appendLog("login error: \(error.localizedDescription)")
                }
            }
        }
    }

    @objc private func onSend() {
        guard let engine else { return }
        let peer = val(peerField)
        let text = val(textField)
        guard !peer.isEmpty, !text.isEmpty else {
            appendLog("填写对端 ID 和文本")
            return
        }
        Task {
            do {
                let id = try await engine.sendTextMessage(userId: peer, text: text)
                await MainActor.run {
                    self.appendLog("sent \(id): \(text)")
                    self.textField.text = ""
                }
                await self.reloadConversations()
            } catch {
                await MainActor.run {
                    self.appendLog("send error: \(error.localizedDescription)")
                }
            }
        }
    }

    @objc private func onLogout() {
        guard let engine else { return }
        Task {
            do {
                try await engine.logout()
                await MainActor.run {
                    self.status.text = "已登出"
                    self.appendLog("logout ok")
                }
            } catch {
                await MainActor.run { self.appendLog("logout error: \(error)") }
            }
        }
    }

    @objc private func onRefresh() {
        Task { await reloadConversations() }
    }

    private func reloadConversations() async {
        guard let engine else { return }
        do {
            let list = try await engine.getConversations()
            let body = list.isEmpty
                ? "(empty)"
                : list.map {
                    "\($0.showName ?? $0.conversationId): \($0.latestText ?? "")  unread=\($0.unreadCount)"
                }.joined(separator: "\n")
            await MainActor.run { self.convView.text = body }
        } catch {
            await MainActor.run { self.appendLog("conversations error: \(error)") }
        }
    }

    // MARK: - ImEventListener

    func onConnectSuccess() { DispatchQueue.main.async { self.appendLog("event: connect success") } }
    func onConnectFailed(code: Int, error: String) {
        DispatchQueue.main.async { self.appendLog("event: connect failed \(code) \(error)") }
    }
    func onConnecting() { DispatchQueue.main.async { self.appendLog("event: connecting") } }
    func onKickedOffline() { DispatchQueue.main.async { self.appendLog("event: kicked") } }
    func onUserTokenExpired() { DispatchQueue.main.async { self.appendLog("event: token expired") } }
    func onRecvNewMessage(msgId: String, fromUserId: String, groupId: String?, text: String?) {
        DispatchQueue.main.async {
            self.appendLog("recv \(fromUserId): \(text ?? "")")
        }
    }

    // MARK: - UI

    private func setupUI() {
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.keyboardDismissMode = .onDrag
        view.addSubview(scroll)
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        configure(appIdField, "AppId", "demo_app_id")
        configure(apiBaseField, "SY API Base", "https://47.105.48.196")
        configure(imApiField, "OpenIM API", "https://47.105.48.196/openim")
        configure(imWsField, "OpenIM WS", "wss://47.105.48.196/msg_gateway")
        configure(userIdField, "User ID", "u1001")
        configure(tokenField, "IM Token", "")
        configure(jwtField, "User JWT (for /api/user/im/token)", "")
        configure(peerField, "To user ID", "u1002")
        configure(textField, "Message", "hello from iOS")

        style(initBtn, "初始化", #selector(onInit))
        style(loginBtn, "登录", #selector(onLogin))
        style(sendBtn, "发送文本", #selector(onSend))
        style(logoutBtn, "登出", #selector(onLogout))
        style(refreshBtn, "刷新会话", #selector(onRefresh))
        style(fetchBtn, "获取 IM Token", #selector(onFetchToken))

        status.text = "未初始化"
        status.numberOfLines = 0
        status.font = .preferredFont(forTextStyle: .headline)

        convView.isEditable = false
        convView.font = .systemFont(ofSize: 13)
        convView.backgroundColor = .systemGray6
        convView.layer.cornerRadius = 8
        convView.heightAnchor.constraint(equalToConstant: 120).isActive = true

        logView.isEditable = false
        logView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        logView.backgroundColor = .systemGray6
        logView.layer.cornerRadius = 8
        logView.heightAnchor.constraint(equalToConstant: 160).isActive = true

        let hint = UILabel()
        hint.numberOfLines = 0
        hint.font = .systemFont(ofSize: 12)
        hint.textColor = .secondaryLabel
        hint.text = "默认 OpenIMSDK（CocoaPods）。基址 https://47.105.48.196 + /openim + wss msg_gateway。流程：User JWT → Get IM Token → Init/Login/Send。HttpWs 仅显式 backend:.httpWs。"

        [status, hint,
         labeled("AppId", appIdField),
         labeled("API Base", apiBaseField),
         labeled("OpenIM API", imApiField),
         labeled("OpenIM WS", imWsField),
         labeled("User ID", userIdField),
         labeled("User JWT", jwtField),
         labeled("Token", tokenField),
         row([fetchBtn, initBtn]),
         row([loginBtn, logoutBtn]),
         labeled("To", peerField),
         labeled("Text", textField),
         row([sendBtn, refreshBtn]),
         label("会话"), convView,
         label("日志"), logView].forEach { stack.addArrangedSubview($0) }

        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -24),
        ])
    }

    private func configure(_ f: UITextField, _ ph: String, _ text: String) {
        f.placeholder = ph
        f.text = text
        f.borderStyle = .roundedRect
        f.autocapitalizationType = .none
        f.autocorrectionType = .no
        f.delegate = self
        f.font = .systemFont(ofSize: 14)
        f.returnKeyType = .done
    }

    private func style(_ b: UIButton, _ title: String, _ sel: Selector) {
        b.setTitle(title, for: .normal)
        b.addTarget(self, action: sel, for: .touchUpInside)
        b.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
    }

    private func labeled(_ t: String, _ f: UITextField) -> UIStackView {
        let l = label(t)
        let s = UIStackView(arrangedSubviews: [l, f])
        s.axis = .vertical
        s.spacing = 2
        return s
    }

    private func label(_ t: String) -> UILabel {
        let l = UILabel()
        l.text = t
        l.font = .systemFont(ofSize: 12)
        l.textColor = .secondaryLabel
        return l
    }

    private func row(_ buttons: [UIButton]) -> UIStackView {
        let s = UIStackView(arrangedSubviews: buttons)
        s.axis = .horizontal
        s.spacing = 8
        s.distribution = .fillEqually
        return s
    }

    private func val(_ f: UITextField) -> String {
        (f.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func appendLog(_ msg: String) {
        let ts = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        logView.text += "[\(ts)] \(msg)\n"
        if logView.text.count > 1 {
            logView.scrollRangeToVisible(NSRange(location: logView.text.count - 1, length: 1))
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
