# SyImSDK Example (iOS) — OpenIMSDK default

## Exact steps (production IP)

```bash
cd sy-im-ios-sdk/example
pod install
open SyImSDKExample.xcworkspace
```

Pin: `OpenIMSDK` **`3.8.3+hotfix.3.1`** (see Podfile / Podfile.lock). Matches OpenIM server v3 on `47.105.48.196`.

| Field | Value |
|-------|-------|
| SY API | `https://47.105.48.196` |
| OpenIM API | `https://47.105.48.196/openim` |
| OpenIM WS | `wss://47.105.48.196/msg_gateway` |

1. Paste User JWT → **Get IM Token**
2. **Init** (default `backend: .openImSdk` → `RealOpenImClient`)
3. **Login** → **Send** text to peer OpenIM user id (`{appId}_{uid}`)
4. Second device / OpenIM demo should receive via native SDK

TLS: trust `sy-rtc-server-ca.crt` from `/downloads/` (CLIENT_TRUST). Domain HTTPS skipped.

## HttpWs explicit fallback

Only if `pod install` cannot fetch OpenIMSDK:

```swift
SyImEngine.initialize(..., backend: .httpWs)
// + setControlPlaneAccessToken(jwt) for real send via SY proxy
```
