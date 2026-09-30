import Foundation

/// SY 控制面（`/api/user/im/…`）返回的业务码。与 Android `ImErrorCode`、Flutter `SyImErrorCode`
/// 取值相同，与服务端 `errcode` 包一致。OpenIM SDK 自己的错误码（登录、收发）不在此列，原样透传。
public enum SyImErrorCode {
    /// 未登录或 User JWT 无效。
    public static let unauthorized = 401
    /// 无权访问该应用。
    public static let forbidden = 403
    /// 应用未开通 IM。
    public static let imNotEnabled = 3001
    /// 月活超出套餐。
    public static let quotaMau = 3003
    /// 消息量超出套餐。
    public static let quotaMessages = 3004
    /// 体验版已下线。
    public static let trialRetired = 4003
    /// 敏感词拦截（拒绝模式）。
    public static let sensitiveRejected = 4005
    /// 发送前内容审核拒绝，或审核服务不可达（阻断模式）。
    public static let contentRejected = 4006
    /// AppId 的访问凭证已暂停。
    public static let credentialSuspended = 4031
    /// AppId 的访问凭证已吊销。
    public static let credentialRevoked = 4032
    /// AppId 的访问凭证已过期。
    public static let credentialExpired = 4033
    /// 请求过于频繁。
    public static let rateLimited = 4290

    public static func isCredentialBlocked(_ code: Int) -> Bool {
        code == credentialSuspended || code == credentialRevoked || code == credentialExpired
    }

    /// 消息被内容策略拦截（敏感词或发送前审核）。
    public static func isContentRejected(_ code: Int) -> Bool {
        code == sensitiveRejected || code == contentRejected
    }

    /// 非 2xx 或业务码非 0 时抛 `SyImError.controlPlane`。
    static func check(httpStatus: Int, json: [String: Any]) throws {
        let ok = (200..<300).contains(httpStatus)
        let biz: Int
        if let n = json["code"] as? NSNumber {
            biz = n.intValue
        } else {
            biz = ok ? 0 : httpStatus
        }
        if ok && biz == 0 { return }
        let msg = (json["msg"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "HTTP \(httpStatus)"
        throw SyImError.controlPlane(code: biz, httpStatus: httpStatus, message: msg)
    }
}
