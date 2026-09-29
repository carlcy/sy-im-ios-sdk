Pod::Spec.new do |s|
  s.name             = 'SyImSDK'
  s.version          = '0.5.0'
  s.summary          = 'SY IM iOS SDK. CocoaPods OpenIMSDK is the production client.'
  s.description      = <<-DESC
    SY instant messaging SDK for iOS. Customers add `pod 'SyImSDK', '~> 0.5.0'`.
    This pod depends on OpenIMSDK 3.8.3+hotfix.3.1, so CocoaPods resolves that
    pin automatically. Do not download or unzip a framework.
    OpenIM iOS publishes CocoaPods only (OpenIMSDKCore is a vendored xcframework)
    and has no Swift Package, so SPM cannot pull the production dependency.
    HttpWsOpenImClient remains an explicit fallback (`backend: .httpWs`).
  DESC
  s.homepage         = 'https://github.com/carlcy/sy-im-ios-sdk'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'SY' => 'carlcy2023@163.com' }
  s.source           = { :git => 'https://github.com/carlcy/sy-im-ios-sdk.git', :tag => "v#{s.version}" }
  s.ios.deployment_target = '13.0'
  s.swift_version    = '5.9'
  # OpenIMSDKCore vendors a static xcframework. Host apps must use
  # `use_frameworks! :linkage => :static`.
  s.static_framework = true
  s.source_files     = 'Sources/SyImSDK/**/*.swift'
  # Exact pin: matches open-im-server v3 used by this product. Do not float.
  s.dependency 'OpenIMSDK', '3.8.3+hotfix.3.1'
  s.pod_target_xcconfig = {
    'BUILD_LIBRARY_FOR_DISTRIBUTION' => 'YES',
    'DEFINES_MODULE' => 'YES',
    'IPHONEOS_DEPLOYMENT_TARGET' => '13.0'
  }
end
