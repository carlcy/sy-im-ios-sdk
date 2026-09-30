// swift-tools-version: 5.9
import PackageDescription

// OpenIM iOS（open-im-sdk-ios）只通过 CocoaPods 发布，核心 OpenIMSDKCore 是
// vendored xcframework，仓库里没有 Package.swift。SPM 不能声明 CocoaPods 依赖，
// 因此这里不能把生产依赖 OpenIMSDK 拉进来。
//
// 客户接入只写：pod 'SyImSDK', '~> 0.5.0'
// 不要用本 Package 的 URL 代替 CocoaPods，也不要下载 / 解压 framework。
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
    dependencies: [],
    targets: [
        .target(
            name: "SyImSDK",
            dependencies: [],
            path: "Sources/SyImSDK"
        ),
        .testTarget(
            name: "SyImSDKTests",
            dependencies: ["SyImSDK"],
            path: "Tests/SyImSDKTests"
        ),
    ]
)
