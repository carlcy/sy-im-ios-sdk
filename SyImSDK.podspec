Pod::Spec.new do |s|
  s.name             = 'SyImSDK'
  s.version          = '0.4.0'
  s.summary          = 'SY IM iOS SDK (OpenIMSDK default + HttpWs explicit fallback)'
  s.description      = <<-DESC
    SY control-plane IM Token + OpenIM data plane.
    Default client path is CocoaPods OpenIMSDK (RealOpenImClient).
    HttpWsOpenImClient is an explicit fallback only (backend: .httpWs).
  DESC
  s.homepage         = 'https://github.com/carlcy/sy-im-ios-sdk'
  s.license          = { :type => 'Proprietary' }
  s.author           = { 'SY' => 'dev@localhost' }
  s.source           = { :git => 'https://github.com/carlcy/sy-im-ios-sdk.git', :tag => "v#{s.version}" }
  s.ios.deployment_target = '13.0'
  s.swift_version    = '5.9'
  s.static_framework = true
  s.source_files     = 'Sources/SyImSDK/**/*.swift'
  # Pin matches CocoaPods trunk resolution used with OpenIM server v3 on 47.105.48.196
  s.dependency 'OpenIMSDK', '3.8.3+hotfix.3.1'
  s.pod_target_xcconfig = {
    'BUILD_LIBRARY_FOR_DISTRIBUTION' => 'YES',
    'IPHONEOS_DEPLOYMENT_TARGET' => '13.0'
  }
  s.user_target_xcconfig = {
    'IPHONEOS_DEPLOYMENT_TARGET' => '13.0'
  }
end
