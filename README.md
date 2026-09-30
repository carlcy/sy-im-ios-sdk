# SyImSDK 0.5.0

SY 即时通信 iOS SDK。数据面走官方 OpenIMSDK，控制面用 SY 签发 IM Token。

客户只按**库名和版本号**接入，不要下载、解压 framework 或 zip。

## 快速开始

最低系统 iOS 13。需要 Xcode 15+（Swift 5.9）。

### 1. 添加依赖

在业务工程的 `Podfile` 写入：

```ruby
platform :ios, '13.0'
use_frameworks! :linkage => :static

target 'YourApp' do
  pod 'SyImSDK', '~> 0.5.0'
end
```

然后：

```bash
pod install
```

用生成的 `.xcworkspace` 打开工程，不要打开 `.xcodeproj`。

`SyImSDK.podspec` 已经声明 `OpenIMSDK (= 3.8.3+hotfix.3.1)`（以及它带上的 `OpenIMSDKCore 3.8.3+3`）。执行 `pod install` 时 CocoaPods 会自动解析，**业务 Podfile 不要再写 `pod 'OpenIMSDK'`，也不要手动拖入 xcframework**。

必须 `use_frameworks! :linkage => :static`。OpenIM 的核心是静态 xcframework，动态链接会报 transitive static binary 错误。

版本 `0.5.0` 发布到 CocoaPods trunk 之后，上面这一行才能解析。发布步骤见文末。

### 2. 初始化

```swift
import SyImSDK

let im = SyImEngine.initialize(
    appId: "your_app_id",
    apiBaseUrl: "https://47.105.48.196",
    imApiAddr: "https://47.105.48.196/openim",
    imWsAddr: "wss://47.105.48.196/msg_gateway"
)
im.setEventListener(self)
try await im.prepare()
```

`backend` 默认是 `.openImSdk`（CocoaPods 链上的 `RealOpenImClient`）。只有链不上 OpenIMSDK 时才显式传 `backend: .httpWs`。

`imApiAddr` / `imWsAddr` 也可以先留空，等下一步 Token 接口返回后再填。示例工程预填了上面的地址。

### 3. 用 Token 登录

IM Token 由业务后端经 SY 控制面签发，客户端不持有 OpenIM secret。用户 JWT 调用：

```swift
im.setControlPlaneAccessToken(userJwt)
let data = try await im.getToken(userId: "u1001", userJwt: userJwt)
let token = data["token"] as? String ?? ""
let imUserId = data["imUserId"] as? String ?? "\(im.appId)_u1001"
try await im.login(userId: imUserId, token: token)
```

OpenIM 用户 ID 是 `{appId}_{业务 uid}`。`imApiAddr` / `imWsAddr` 在 `initialize` 时写死。若 Token 响应里的地址和初始化时不同，先 `SyImEngine.reset()`，再用新地址重新 `initialize`，然后 `prepare()`。

登录失败、被踢、Token 过期通过 `ImEventListener` 回调。

### 4. 发送文本消息

```swift
let msgId = try await im.sendTextMessage(userId: "\(im.appId)_u1002", text: "你好")
```

单聊传 `userId`，群聊传 `groupId`，二选一。返回值是 clientMsgID。

收消息：

```swift
func onRecvNewMessage(msgId: String, fromUserId: String, groupId: String?, text: String?) {
    // text 为 nil 表示非文本
}
```

自签 HTTPS：把 `https://47.105.48.196/downloads/sy-rtc-server-ca.crt` 安装到设备信任区。公网域名仍被 ICP/WAF 拦住，联调继续用 IP。

## 为什么不是 SPM

查过 OpenIM iOS（[open-im-sdk-ios](https://github.com/openimsdk/open-im-sdk-ios) 标签 `3.8.3+hotfix.3.1`，以及 CocoaPods trunk 上的 `OpenIMSDK`）：

- 官方安装方式只有 `pod 'OpenIMSDK'`。
- 核心 `OpenIMSDKCore` 是 vendored `xcframework`，没有 `Package.swift`。
- SPM 不能依赖一个 CocoaPod。把 xcframework 再打成 binary target，等于让客户下载 framework，不符合接入要求。

因此生产路径只有 CocoaPods。仓库里的 `Package.swift` 只保留源码布局，**不能**当客户接入方式：它链不上 OpenIMSDK，`backend: .openImSdk` 会失败。

## 示例

示例工程与客户工程同一行依赖：

```ruby
pod 'SyImSDK', '~> 0.5.0'
```

```bash
cd example
pod install
open SyImSDKExample.xcworkspace
```

界面有两个 Tab。**会话** Tab 把总未读显示在 `tabBarItem.badgeValue`（0 不显示，大于 99 显示 `99+`），OpenIM 未读监听和标已读之后都会立刻变。**联调** Tab：填写 User JWT → 获取 IM Token → 初始化 → 登录 → 发送文本。

版本号四处一致：`SyImSDK.podspec`、`VERSION`、`SyImSDKVersion.current`、示例 `MARKETING_VERSION` / `CFBundleShortVersionString`，都是 `0.5.0`。

`0.5.0` 尚未推到 trunk 之前，`pod install` 找不到 `SyImSDK`。先完成文末发布。

## 公开 API（在原有初始化 / 登录 / 发消息之上追加）

原有方法签名没有改。

| 方法 | 作用 |
|------|------|
| `getTotalUnreadCount()` | 总未读。会话上的 `unreadCount` 仍是单会话未读 |
| `markConversationAsRead(conversationId:)` | 标已读。单聊同时发已读回执 |
| `onRecvC2CReadReceipt` / `onRecvGroupReadReceipt` | 收到已读回执 |
| `onUnreadChanged` / `SyImEngine.onUnreadChanged` | 总未读和单会话未读。监听和标已读后都会到 |
| `onTotalUnreadCountChanged(count:)` | 总未读变化（`onUnreadChanged` 同时也会带上） |
| `onConversationUnreadChanged(conversationId:unreadCount:)` | 单个会话未读 |
| `addFriend(fromUserId:toUserId:reqMsg:)` | 好友申请，`POST /api/user/im/friends/add` |
| `listFriends(ownerUserId:)` | `POST /api/user/im/friends/list` |
| `getReceivedFriendApplications()` | 收到的好友申请 |
| `acceptFriendApplication` / `refuseFriendApplication` | 同意 / 拒绝 |
| `onRecvFriendApplication` | 新的好友申请 |
| `createGroup(ownerUserId:groupName:memberUserIds:)` | `POST /api/user/im/groups/create` |
| `listGroups(ownerUserId:)` | `POST /api/user/im/groups/list` |
| `getJoinedGroups()` | OpenIM 本地已加入群 |
| `inviteToGroup` / `kickFromGroup` / `quitGroup` / `dismissGroup` | 邀请、踢人、退群、解散 |
| `messageHistory(...)` | `POST /api/user/im/messages/history` |
| `revokeMessage(userId:conversationId:seq:)` | `POST /api/user/im/messages/revoke` |

控制面方法要先 `setControlPlaneAccessToken(userJwt)`。已读、未读、处理好友申请、邀请/踢人/退群/解散走 OpenIMSDK，显式 `backend: .httpWs` 时这些调用会抛错（总未读除外，它用会话未读相加）。

### 未读实时刷新

```swift
im.onUnreadChanged = { update in
    // update.totalUnreadCount 总未读
    // update.conversationId / conversationUnreadCount 有值时是单会话
}
func onUnreadChanged(_ update: SyImUnreadUpdate) {}
```

`getConversations()` / `getTotalUnreadCount()` 只更新缓存，不触发上面的回调。`markConversationAsRead` 成功后先按本地缓存把该会话未读记为 0 并回调，再拉一次总未读校正。

### 与腾讯云 IM 对齐、且 OpenIM 支持的能力

这些方法走默认 `backend: .openImSdk`。`backend: .httpWs` 会抛错。

| 方法 | 作用 |
|------|------|
| `recallMessage(conversationId:clientMsgId:)` | 按 clientMsgID 撤回。按 seq 撤回仍用 `revokeMessage` |
| `onMessageRecalled(clientMsgId:revokerUserId:)` | 收到撤回 |
| `sendAtTextMessage(groupId:text:atUserIds:atAll:)` | 群 @。`atAll == true` 时 @所有人 |
| `searchConversations` / `searchMessages` / `searchUsers` | 搜会话、本地消息、好友 |
| `pinConversation` / `setConversationDraft` | 置顶、草稿 |
| `setConversationReceiveOption(_:option:)` | 免打扰：`.receive` / `.notReceive` / `.notNotify` |
| `sendTyping(conversationId:focus:)` | 发送正在输入。本 OpenIM 版本收不到对端输入状态 |
| `sendCustomMessage(userId:groupId:data:description:ext:)` | 自定义消息 |
| `setSelfCustomInfo` / `getSelfCustomInfo` | 用户自定义字段 `ex` |
| `setGroupCustomInfo(groupId:ex:)` | 群自定义字段 `ex` |
| `addToBlacklist` / `removeFromBlacklist` / `getBlacklist` | 黑名单 |

`SyImConversation` 增加了 `isPinned`、`draftText`、`receiveOption`，旧的初始化参数都有默认值。

## 维护者：打 0.5.0 发布

本机没有 CocoaPods trunk 权限，需要仓库所有者在 **macOS + Xcode** 上执行。CocoaPods trunk 计划在 **2026-12-02** 变为只读，请在那之前推上去。

1. 确认 `SyImSDK.podspec` 的 `s.version`、`VERSION`、`SyImSDKVersion.current`、示例 `MARKETING_VERSION` 都是 `0.5.0`。`s.source` 的 tag 是 `v0.5.0`。
2. 把本分支合并进 `main` 并推送。
3. 打 tag（必须先有 tag，`pod trunk push` 会按 tag 拉源码）：

   ```bash
   git checkout main
   git pull
   git tag v0.5.0
   git push origin v0.5.0
   ```

4. 第一次发布先登记会话（只需一次）：

   ```bash
   pod trunk register you@example.com 'Your Name' --description='SyImSDK'
   ```

   点开邮件里的确认链接。

5. 在 macOS 上校验（本仓库的 Linux 环境没有 Xcode，不能代替这一步）：

   ```bash
   pod lib lint SyImSDK.podspec --allow-warnings
   ```

6. 推到 trunk：

   ```bash
   pod trunk push SyImSDK.podspec --allow-warnings
   ```

7. 确认客户可以解析：

   ```bash
   pod trunk info SyImSDK
   cd example && pod install
   ```

   `pod install` 应锁到 `SyImSDK 0.5.0`，并自动带上 `OpenIMSDK 3.8.3+hotfix.3.1`。

以后发 0.5.x：改 `s.version` 和 `VERSION`，打 `v` 前缀 tag，再 `pod trunk push`。客户那行 `~> 0.5.0` 会吃到 `>= 0.5.0` 且 `< 0.6.0`。不要复用已经发布过的版本号。

若 trunk 已只读，改用私有 spec 仓库：`pod repo push <repo> SyImSDK.podspec`。客户 Podfile 要先加 `source`，依赖行仍然是 `pod 'SyImSDK', '~> 0.5.0'`。
