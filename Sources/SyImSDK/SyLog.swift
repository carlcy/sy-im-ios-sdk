#if canImport(os.log)
import os.log
#else
/// Linux 自测用的空实现。iOS 上走系统 os.log，客户工程不会编到这里。
struct OSLog {
    init(subsystem: String, category: String) {}
}

struct OSLogType {
    static let info = OSLogType()
    static let error = OSLogType()
    static let debug = OSLogType()
    static let `default` = OSLogType()
}

func os_log(_ message: StaticString, log: OSLog, type: OSLogType, _ args: CVarArg...) {}
#endif
