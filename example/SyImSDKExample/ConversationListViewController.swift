import UIKit
import SyImSDK

/// 会话 Tab。总未读显示在 `tabBarItem.badgeValue` 上，随 `onUnreadChanged` 实时变化。
final class ConversationListViewController: UITableViewController {
    static weak var current: ConversationListViewController?

    private var rows: [SyImConversation] = []
    private var totalUnread = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        ConversationListViewController.current = self
        title = "会话"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "conversation")
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "刷新",
            style: .plain,
            target: self,
            action: #selector(reload)
        )
        let version = UILabel()
        version.text = "SyImSDK \(SyImSDKVersion.current)"
        version.font = .systemFont(ofSize: 12)
        version.textColor = .secondaryLabel
        version.textAlignment = .center
        version.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: 36)
        tableView.tableFooterView = version
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reload()
    }

    /// 主线程调用。更新总未读角标，以及对应行的未读数。
    func apply(_ update: SyImUnreadUpdate) {
        totalUnread = update.totalUnreadCount
        if let id = update.conversationId,
           let count = update.conversationUnreadCount,
           let index = rows.firstIndex(where: { $0.conversationId == id }) {
            rows[index].unreadCount = count
        }
        applyBadge()
        tableView.reloadData()
    }

    @objc private func reload() {
        guard let engine = SyImEngine.instance, engine.isLoggedIn else {
            rows = []
            totalUnread = 0
            applyBadge()
            tableView.reloadData()
            return
        }
        Task {
            do {
                let list = try await engine.getConversations()
                let total = (try? await engine.getTotalUnreadCount()) ?? list.reduce(0) { $0 + $1.unreadCount }
                await MainActor.run {
                    self.rows = list.sorted { lhs, rhs in
                        if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
                        return false
                    }
                    self.totalUnread = total
                    self.applyBadge()
                    self.tableView.reloadData()
                }
            } catch {
                await MainActor.run {
                    self.rows = []
                    self.tableView.reloadData()
                }
            }
        }
    }

    private func applyBadge() {
        let item = navigationController?.tabBarItem ?? tabBarItem
        if totalUnread <= 0 {
            item.badgeValue = nil
        } else if totalUnread > 99 {
            item.badgeValue = "99+"
        } else {
            item.badgeValue = String(totalUnread)
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "conversation", for: indexPath)
        let row = rows[indexPath.row]
        let name = row.showName ?? row.conversationId
        let pin = row.isPinned ? "[顶] " : ""
        let draft = (row.draftText?.isEmpty == false) ? "草稿:\(row.draftText ?? "") " : ""
        var title = "\(pin)\(name)"
        if let latest = row.latestText, !latest.isEmpty {
            title += "  \(draft)\(latest)"
        } else if !draft.isEmpty {
            title += "  \(draft)"
        }
        cell.textLabel?.text = title
        cell.textLabel?.numberOfLines = 2
        cell.accessoryView = row.unreadCount > 0 ? unreadLabel(row.unreadCount) : nil
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let id = rows[indexPath.row].conversationId
        Task {
            try? await SyImEngine.instance?.markConversationAsRead(conversationId: id)
        }
    }

    private func unreadLabel(_ count: Int) -> UILabel {
        let label = UILabel()
        label.text = count > 99 ? "99+" : String(count)
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .white
        label.backgroundColor = .systemRed
        label.textAlignment = .center
        label.layer.cornerRadius = 10
        label.clipsToBounds = true
        let width = max(20, label.intrinsicContentSize.width + 12)
        label.frame = CGRect(x: 0, y: 0, width: width, height: 20)
        return label
    }
}
