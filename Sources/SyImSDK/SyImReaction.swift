import Foundation

/// 表情回应（lite）。服务端 `POST /api/user/im/reaction` 发出的 Custom(110) 消息，`data` 为
/// `{"sy":"reaction_lite","action":"add|remove","emoji":"👍","target":{"seq":..,"clientMsgId":..,"senderId":..}}`。
/// 与 Android `ImReaction`、Flutter `SyImReaction` 解析规则相同。
public struct SyImReaction: Equatable {
    public static let description = "sy_reaction_lite"

    public let emoji: String
    public let added: Bool
    public let targetClientMsgId: String
    public let targetSeq: Int64
    public let targetSenderId: String

    /// 解析自定义消息的 `data` 字符串；不是回应消息时返回 nil。
    public static func parse(_ customData: String?) -> SyImReaction? {
        guard let customData, let raw = customData.data(using: .utf8),
              let obj = (try? JSONSerialization.jsonObject(with: raw)) as? [String: Any],
              obj["sy"] as? String == "reaction_lite" else { return nil }
        let emoji = ((obj["emoji"] as? String) ?? "").trimmingCharacters(in: .whitespaces)
        guard !emoji.isEmpty else { return nil }
        let target = obj["target"] as? [String: Any] ?? [:]
        return SyImReaction(
            emoji: emoji,
            added: (obj["action"] as? String) != "remove",
            targetClientMsgId: target["clientMsgId"] as? String ?? "",
            targetSeq: (target["seq"] as? NSNumber)?.int64Value ?? 0,
            targetSenderId: target["senderId"] as? String ?? ""
        )
    }

    static func requestBody(
        fromUserId: String, emoji: String, toUserId: String?, groupId: String?,
        targetClientMsgId: String?, targetSeq: Int64, targetSenderId: String?, add: Bool
    ) -> [String: Any] {
        var body: [String: Any] = ["fromUserId": fromUserId, "emoji": emoji, "action": add ? "add" : "remove"]
        if let groupId, !groupId.isEmpty { body["groupId"] = groupId } else { body["toUserId"] = toUserId ?? "" }
        if let targetClientMsgId, !targetClientMsgId.isEmpty { body["targetClientMsgId"] = targetClientMsgId }
        if targetSeq > 0 { body["targetSeq"] = targetSeq }
        if let targetSenderId, !targetSenderId.isEmpty { body["targetSenderId"] = targetSenderId }
        return body
    }
}
