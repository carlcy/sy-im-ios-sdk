// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SyImSDK",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "SyImSDK",
            targets: ["SyImSDK"]
        ),
    ],
    dependencies: [
        // OpenIM iOS has NO official SPM.
        // PRODUCTION DEFAULT: CocoaPods — see SyImSDK.podspec (depends on OpenIMSDK 3.8.3+hotfix.3.1)
        //   → RealOpenImClient via canImport(OpenIMSDK)
        // SPM consumers: pass backend: .httpWs explicitly (HttpWsOpenImClient), or vendor OpenIMSDK.
    ],
    targets: [
        .target(
            name: "SyImSDK",
            dependencies: [],
            path: "Sources/SyImSDK"
        ),
    ]
)
