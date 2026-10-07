# SRun Portal iPadOS

这是 `srunportal` Java 版本的原生 Swift / SwiftUI iPadOS 重写。

## 功能

- 检测校园网 Portal
- 获取当前 IP / AC ID
- 获取 SRun challenge token
- HMAC-MD5 密码摘要
- SRun 自定义 XXTEA + Base64 `{SRBX1}` 编码
- SHA-1 `chksum`
- 提交 `/cgi-bin/srun_portal`
- iPad 原生 SwiftUI UI
- 账号密码可保存到 Keychain

## 使用

用 Xcode 打开 `SrunPortal.xcodeproj`，选择 iPad 模拟器或真机，然后运行。

首次运行填写：

- 用户名
- 密码
- 认证服务器 URL，例如 `http://192.168.88.7`
- 联网检测地址，默认 `223.5.5.5`

## 注意

这个项目允许 HTTP 请求，因为很多校园网 Portal 仍然使用 HTTP。生产环境如果认证服务器全部支持 HTTPS，建议删除 `NSAllowsArbitraryLoads` 并配置精确的 ATS 例外。

Java 原版中有一个 `ac_id` 自动探测步骤；本 Swift 版目前把它保留在 `rad_user_info` 流程中。如果你学校的 Portal 页面本身能直接提供 `ac_id`，后续可以再加入完全一致的页面解析。
