import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        let conversations = UINavigationController(rootViewController: ConversationListViewController())
        conversations.tabBarItem = UITabBarItem(
            title: "会话",
            image: UIImage(systemName: "bubble.left.and.bubble.right"),
            tag: 0
        )
        let debug = UINavigationController(rootViewController: ViewController())
        debug.tabBarItem = UITabBarItem(
            title: "联调",
            image: UIImage(systemName: "slider.horizontal.3"),
            tag: 1
        )
        let tabs = UITabBarController()
        tabs.viewControllers = [conversations, debug]
        window?.rootViewController = tabs
        window?.makeKeyAndVisible()
        return true
    }
}
