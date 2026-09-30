# 示例说明

依赖写法与客户一致：`pod 'SyImSDK', '~> 0.5.0'`。OpenIMSDK 随 podspec 自动解析。

- **默认**：`pod install` 成功后走 OpenIMSDK（`RealOpenImClient`）。
- **HttpWs**：只有显式 `backend: .httpWs` 才用。登录走 msg_gateway；发消息可走控制面。已读回执、处理好友申请、邀请/踢人/退群/解散在这条路径上不可用。
- **Mock**：`backend: .mock`，或 HttpWs 但地址为空。
- **会话 Tab**：总未读角标走 `onUnreadChanged`，标已读后立即刷新。示例版本号是 0.5.0。
