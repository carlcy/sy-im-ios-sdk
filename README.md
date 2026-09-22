# sy-im-ios-sdk 0.4.0

SY 即时通信 iOS SDK（OpenIM 数据面）。

## Default client = OpenIMSDK (CocoaPods)

| `backend` | Client | When |
|-----------|--------|------|
| **`.openImSdk` (DEFAULT)** | `RealOpenImClient` | CocoaPods links `OpenIMSDK` `3.8.3+hotfix.3.1` |
| `.httpWs` (**explicit only**) | `HttpWsOpenImClient` | No pod / SPM-only; login WS real; send via SY `/api/user/im/send` |
| `.mock` | `MockOpenImClient` | UI / offline demo |

OpenIM iOS has **no official SPM**. Production path:

```bash
# Host Podfile
pod 'SyImSDK', :path => './sy-im-ios-sdk'   # pulls OpenIMSDK 3.8.3+hotfix.3.1
# or unzip sy-im-ios-0.4.0.zip then path to that folder
```

Version pin that matches this server (`open-im-server` v3 @ `47.105.48.196`):

```text
OpenIMSDK (= 3.8.3+hotfix.3.1) → OpenIMSDKCore (= 3.8.3+3)
```

If a newer trunk OpenIMSDK fails against this server, keep the pin above (also locked in `example/Podfile.lock`).

## Example — send/receive against production IP

```bash
cd example
pod install          # must succeed (network + CocoaPods trunk)
open SyImSDKExample.xcworkspace   # NOT .xcodeproj
```

Prefilled endpoints:

| | URL |
|--|-----|
| SY API | `https://47.105.48.196` |
| OpenIM API | `https://47.105.48.196/openim` |
| OpenIM WS | `wss://47.105.48.196/msg_gateway` |

Flow:

1. Obtain User JWT from SY auth.
2. Tap **Get IM Token** → `POST /api/user/im/token` → fills `token` / `imUserId` / addrs.
3. **Init** → `SyImEngine.initialize(..., backend: .openImSdk)` (default) → `RealOpenImClient`.
4. **Login** → native `OIMManager.login`.
5. **Send** → native `sendMessage` (WS binary protocol). Peer / second device receives via OpenIMSDK callbacks.

Self-signed TLS: install `https://47.105.48.196/downloads/sy-rtc-server-ca.crt` into the device trust store, or see `docs/integration/CLIENT_TRUST.md`. Domain HTTPS is **not** fixed (ICP/WAF 403) — stay on IP.

### Explicit HttpWs fallback

```swift
let im = SyImEngine.initialize(
    appId: appId,
    apiBaseUrl: "https://47.105.48.196",
    imApiAddr: "https://47.105.48.196/openim",
    imWsAddr: "wss://47.105.48.196/msg_gateway",
    backend: .httpWs   // ONLY when OpenIMSDK cannot be linked
)
im.setControlPlaneAccessToken(syJwt) // needed for /api/user/im/send proxy
```

### `pod install` offline

1. Keep the pin; retry when trunk is reachable.
2. Or temporarily comment `pod 'OpenIMSDK'` / use SPM Package.swift with **`backend: .httpWs`** (not default).

## Public API

```swift
let im = SyImEngine.initialize(
    appId: "your_app_id",
    apiBaseUrl: "https://47.105.48.196",
    imApiAddr: "https://47.105.48.196/openim",
    imWsAddr: "wss://47.105.48.196/msg_gateway"
    // backend: .openImSdk  // default
)
im.setEventListener(MyListener())
try await im.prepare()
try await im.login(userId: "\(appId)_\(uid)", token: imTokenFromBackend)
_ = try await im.sendTextMessage(userId: "\(appId)_\(peer)", text: "hello")
```

## HTTPS (honest)

Prefer `https://47.105.48.196` (replaceable self-signed SAN). Public domain is ICP/WAF-blocked; Let’s Encrypt HTTP-01 returns 403 from validators. No fake LE/domain fix.
