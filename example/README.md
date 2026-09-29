# SyImSDK 示例

示例和客户工程用同一行依赖，不使用本地 `:path`，也不下载 framework / zip。

```ruby
pod 'SyImSDK', '~> 0.5.0'
```

`OpenIMSDK 3.8.3+hotfix.3.1` 由 `SyImSDK.podspec` 自动带上。Podfile 里不要再写一条 `pod 'OpenIMSDK'`。

维护者把 **0.5.0** 推到 CocoaPods trunk 之后：

```bash
cd example
pod install
open SyImSDKExample.xcworkspace
```

打开的是 `.xcworkspace`。

| 字段 | 预填值 |
|------|--------|
| SY API | `https://47.105.48.196` |
| OpenIM API | `https://47.105.48.196/openim` |
| OpenIM WS | `wss://47.105.48.196/msg_gateway` |

1. 粘贴 User JWT，点 **获取 IM Token**（`POST /api/user/im/token`）。
2. **初始化**（默认 `backend: .openImSdk`）。
3. **登录**。OpenIM 用户 ID 为 `{appId}_{uid}`。
4. **发送文本**。对端 ID 同样用 OpenIM 用户 ID。
5. **刷新会话** 会带上总未读数。

自签证书：把 `https://47.105.48.196/downloads/sy-rtc-server-ca.crt` 装进设备信任区。

`0.5.0` 还没上 trunk 时，`pod install` 会找不到 `SyImSDK`。发布步骤在仓库根目录 README 的「维护者：打 0.5.0 发布」。
