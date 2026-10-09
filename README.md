# 运行截图
<img width="1640" height="2360" alt="IMG_0561" src="https://github.com/user-attachments/assets/34afc9f7-016e-4ba1-a5e2-f20f6f2084a7" />

<br>

# SRun Portal iPadOS
感谢Chatgpt<br>
这是 `srunportal` Java 版本的原生 Swift / SwiftUI iPadOS 重写。
<br>
Java原版的仓库:https://github.com/fu1323/srunportal  <br>
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
- 认证服务器 URL，例如 `http://192.168.88.7`（程序会自动探测，如果地址变化，或者使用了tls，程序会自动跟着走，不会一直用这个预配置地址）
- 联网检测地址，默认 `223.5.5.5`(因为阿里云dns的80端口是开着的，如果网络正常，get请求会响应404，如果需要认证，会响应一个页面，用js的方式跳转到认证页面（状态碼是200，所以本程序会从html提取出认证地址，地址中包含ac_id参数（后续使用），如果ac_id提取失败会静默使用1，此时可能会造成认证失败）)

## 注意
（给独立逆向的人一个提示：注意那个xxtea发http请求的时候用的编码方式，服务器一直提示验证失败，本人在哪里卡了好久才发现）
这个项目允许 HTTP 请求，因为很多校园网 Portal 仍然使用 HTTP。生产环境如果认证服务器全部支持 HTTPS，建议删除 `NSAllowsArbitraryLoads` 并配置精确的 ATS 例外。

Java 原版中有一个 `ac_id` 自动探测步骤；本 Swift 版目前把它保留在 `rad_user_info` 流程中。如果你学校的 Portal 页面本身能直接提供 `ac_id`，后续可以再加入完全一致的页面解析。
