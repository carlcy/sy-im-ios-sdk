# Example 说明

- **Mock**：地址为空
- **HttpWs 真实登录 + 控制面真实发信**：填 OpenIM 地址 + User JWT + `setControlPlaneAccessToken`
- **OpenIMSDK 全真实**：`pod install` 成功后由 `canImport(OpenIMSDK)` 启用 `RealOpenImClient`
