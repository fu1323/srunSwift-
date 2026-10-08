import Foundation

// MARK: - Models

struct LoginState {
    let callback: String
    let username: String
    let password: String
    let ip: String
    let acID: String
    let challengeToken: String
    let md5Password: String
    let n: String
    let type: String
    let info: String
    let encVer: String
}

struct LoginResult {
    let loggedIn: Bool
    let ip: String?
    let message: String
    let raw: String
}

struct UserInfo {
    let ip: String
}

// MARK: - Errors

enum SrunError: LocalizedError {

    case invalidResponse
    case invalidURL
    case invalidPortalURL

    case invalidUserInfoResponse
    case userIPMissing

    case invalidChallengeResponse
    case challengeMissing

    case invalidLoginResponse

    case httpError(Int)

    var errorDescription: String? {

        switch self {

        case .invalidResponse:
            return "服务器返回的不是有效 HTTP 响应"

        case .invalidURL:
            return "URL 无效"

        case .invalidPortalURL:
            return "校园网门户 URL 无效"

        case .invalidUserInfoResponse:
            return "无法解析用户信息"

        case .userIPMissing:
            return "服务器没有返回用户 IP"

        case .invalidChallengeResponse:
            return "无法解析 challenge 响应"

        case .challengeMissing:
            return "服务器没有返回 challenge"

        case .invalidLoginResponse:
            return "无法解析登录响应"

        case .httpError(let code):
            return "HTTP 错误：\(code)"
        }
    }
}

// MARK: - Client

@MainActor
final class SrunClient {

    private let session: URLSession

    init() {

        let config =
            URLSessionConfiguration.ephemeral

        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 15
        config.waitsForConnectivity = false

        config.httpAdditionalHeaders = [
            "User-Agent":
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " +
                "AppleWebKit/537.36 (KHTML, like Gecko) " +
                "Chrome/125.0.0.0 Safari/537.36"
        ]

        session =
            URLSession(
                configuration: config
            )
    }

    // MARK: - Main Flow

    func checkAndLogin(
        username: String,
        password: String,
        testIP: String = "223.5.5.5",
        progress: ((String) -> Void)? = nil,
        responseHandler: ((String, String) -> Void)? = nil
    ) async throws -> LoginResult {

        progress?("正在检查网络…")

        guard let testURL =
            URL(
                string: "http://\(testIP)"
            )
        else {
            throw SrunError.invalidURL
        }

        var request =
            URLRequest(
                url: testURL,
                timeoutInterval: 10
            )

        request.httpMethod = "GET"

        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " +
            "AppleWebKit/605.1.15 (KHTML, like Gecko) " +
            "Version/18.6 Safari/605.1.15",
            forHTTPHeaderField: "User-Agent"
        )

        request.setValue(
            "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            forHTTPHeaderField: "Accept"
        )

        // URLSession 默认会跟随 HTTP 302。
        let (data, response) =
            try await session.data(
                for: request
            )

        guard let httpResponse =
            response as? HTTPURLResponse
        else {
            throw SrunError.invalidResponse
        }

        let html =
            String(
                data: data,
                encoding: .utf8
            ) ?? ""

        print("")
        print("========== SRUN CHECK ==========")
        print("Final URL:")
        print(
            httpResponse.url?.absoluteString
            ?? "<nil>"
        )
        print("HTTP:", httpResponse.statusCode)
        print("Response:")
        print(html)
        print("================================")
        print("")

        let baseURL =
            httpResponse.url
            ?? testURL

        // ------------------------------------------------
        // 1. meta refresh
        // ------------------------------------------------

        if let portalURL =
            extractPortalURL(
                from: html,
                baseURL: baseURL
            ) {

            print(
                "Portal URL:",
                portalURL.absoluteString
            )

            progress?("发现校园网登录门户")

            return try await login(
                username: username,
                password: password,
                portalURL: portalURL,
                progress: progress,
                responseHandler: responseHandler
            )
        }

        // ------------------------------------------------
        // 2. location.href
        // ------------------------------------------------

        if let portalURL =
            extractLocationHref(
                from: html,
                baseURL: baseURL
            ) {

            print(
                "Portal URL:",
                portalURL.absoluteString
            )

            progress?("发现校园网登录门户")

            return try await login(
                username: username,
                password: password,
                portalURL: portalURL,
                progress: progress,
                responseHandler: responseHandler
            )
        }

        progress?("当前网络无需认证")

        return LoginResult(
            loggedIn: false,
            ip: nil,
            message: "当前网络已正常，无需认证",
            raw: html
        )
    }

    // MARK: - Login

    private func login(
        username: String,
        password: String,
        portalURL: URL,
        progress: ((String) -> Void)?,
        responseHandler: ((String, String) -> Void)?
    ) async throws -> LoginResult {

        guard let components =
            URLComponents(
                url: portalURL,
                resolvingAgainstBaseURL: true
            )
        else {
            throw SrunError.invalidPortalURL
        }

        print(
            "finalURL =",
            portalURL.absoluteString
        )

        print(
            "components =",
            components
        )

        print(
            "queryItems =",
            components.queryItems ?? []
        )

        // ------------------------------------------------
        // ac_id
        // ------------------------------------------------

        let acID =
            components.queryItems?
                .first(
                    where: {
                        $0.name == "ac_id"
                    }
                )?
                .value
            ?? "1"

        print(
            "acID =",
            acID
        )

        // ------------------------------------------------
        // root URL
        // ------------------------------------------------

        guard let scheme =
            portalURL.scheme,
              let host =
                portalURL.host
        else {
            throw SrunError.invalidPortalURL
        }

        var rootComponents =
            URLComponents()

        rootComponents.scheme = scheme
        rootComponents.host = host
        rootComponents.port = portalURL.port

        guard let rootURL =
            rootComponents.url
        else {
            throw SrunError.invalidPortalURL
        }

        let referer =
            buildReferer(
                rootURL: rootURL,
                acID: acID
            )

        print("")
        print("========== PORTAL ==========")
        print(
            "Root URL:",
            rootURL.absoluteString
        )
        print(
            "AC ID:",
            acID
        )
        print(
            "Referer:",
            referer
        )
        print("============================")
        print("")

        // ------------------------------------------------
        // 获取用户 IP
        // ------------------------------------------------

        progress?("正在获取用户信息…")

        let initialIP =
            extractInitialIP(
                from: portalURL
            )

        let userInfo =
            try await getUserInfo(
                rootURL: rootURL,
                ip: initialIP,
                acID: acID,
                responseHandler: responseHandler
            )

        let ip =
            userInfo.ip
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        guard !ip.isEmpty else {
            throw SrunError.userIPMissing
        }

        print(
            "User IP:",
            ip
        )

        // ------------------------------------------------
        // 获取 challenge
        // ------------------------------------------------

        progress?("正在获取认证 Token…")

        let callback =
            SrunTools.jqueryBuilder()

        let token =
            try await getChallenge(
                rootURL: rootURL,
                username: username,
                ip: ip,
                acID: acID,
                callback: callback,
                responseHandler: responseHandler
            )

        print(
            "Challenge:",
            token
        )

        // ------------------------------------------------
        // 计算认证参数
        // ------------------------------------------------

        progress?("正在计算认证参数…")

        let md5Password =
            SrunTools.md5Password(
                token: token,
                password: password
            )

        // SYNUSrun：
        // n=200
        // type=1

        let n = "200"
        let type = "1"
        let encVer = "srun_bx1"

        let info =
            SrunEncoder.build(
                username: username,
                password: password,
                ip: ip,
                acid: acID,
                encVer: encVer,
                token: token
            )

        let state =
            LoginState(
                callback: callback,
                username: username,
                password: password,
                ip: ip,
                acID: acID,
                challengeToken: token,
                md5Password: md5Password,
                n: n,
                type: type,
                info: info,
                encVer: encVer
            )

        let checksum =
            SrunTools.checksum(
                state
            )

        print("")
        print("========== LOGIN PARAM ==========")
        print(
            "username:",
            username
        )
        print(
            "ip:",
            ip
        )
        print(
            "ac_id:",
            acID
        )
        print(
            "n:",
            n
        )
        print(
            "type:",
            type
        )
        print(
            "enc_ver:",
            encVer
        )
        print(
            "md5:",
            md5Password
        )
        print(
            "info:",
            info
        )
        print(
            "checksum:",
            checksum
        )
        print("=================================")
        print("")

        progress?("正在登录校园网…")

        return try await srunPortal(
            rootURL: rootURL,
            state: state,
            checksum: checksum,
            responseHandler: responseHandler
        )
    }

    // MARK: - Initial IP

    private func extractInitialIP(
        from portalURL: URL
    ) -> String {

        let components =
            URLComponents(
                url: portalURL,
                resolvingAgainstBaseURL: false
            )

        if let ip =
            components?
                .queryItems?
                .first(
                    where: {
                        $0.name == "wlanuserip"
                    }
                )?
                .value,
           !ip.isEmpty {

            return
                ip.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
        }

        if let ip =
            components?
                .queryItems?
                .first(
                    where: {
                        $0.name == "ip"
                    }
                )?
                .value,
           !ip.isEmpty {

            return
                ip.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
        }

        return ""
    }

    // MARK: - rad_user_info

    private func getUserInfo(
        rootURL: URL,
        ip: String,
        acID: String,
        responseHandler: ((String, String) -> Void)?
    ) async throws -> UserInfo {

        let url =
            rootURL.appendingPathComponent(
                "cgi-bin/rad_user_info"
            )

        let callback =
            SrunTools.jqueryBuilder()

        var components =
            URLComponents(
                url: url,
                resolvingAgainstBaseURL: false
            )!

        components.queryItems = [

            URLQueryItem(
                name: "callback",
                value: callback
            ),

            URLQueryItem(
                name: "ip",
                value: ip
            ),

            URLQueryItem(
                name: "_",
                value: timestamp()
            )
        ]

        guard let finalURL =
            components.url
        else {
            throw SrunError.invalidURL
        }

        print("")
        print(
            "========== rad_user_info URL =========="
        )
        print(
            finalURL.absoluteString
        )
        print(
            "========================================"
        )
        print("")

        let request =
            makeRequest(
                url: finalURL,
                referer: buildReferer(
                    rootURL: rootURL,
                    acID: acID
                )
            )

        let (data, response) =
            try await session.data(
                for: request
            )

        try checkHTTPResponse(
            response
        )

        let text =
            String(
                data: data,
                encoding: .utf8
            ) ?? ""

        print("")
        print(
            "========== rad_user_info =========="
        )
        print(text)
        print(
            "===================================="
        )
        print("")

        responseHandler?("rad_user_info", text)

        return try parseUserInfo(
            text
        )
    }

    // MARK: - get_challenge

    private func getChallenge(
        rootURL: URL,
        username: String,
        ip: String,
        acID: String,
        callback: String,
        responseHandler: ((String, String) -> Void)?
    ) async throws -> String {

        let url =
            rootURL.appendingPathComponent(
                "cgi-bin/get_challenge"
            )

        var components =
            URLComponents(
                url: url,
                resolvingAgainstBaseURL: false
            )!

        components.queryItems = [

            URLQueryItem(
                name: "callback",
                value: callback
            ),

            URLQueryItem(
                name: "username",
                value: username
            ),

            URLQueryItem(
                name: "ip",
                value: ip
            ),

            URLQueryItem(
                name: "_",
                value: timestamp()
            )
        ]

        guard let finalURL =
            components.url
        else {
            throw SrunError.invalidURL
        }

        print("")
        print(
            "========== get_challenge URL =========="
        )
        print(
            finalURL.absoluteString
        )
        print(
            "======================================="
        )
        print("")

        let request =
            makeRequest(
                url: finalURL,
                referer: buildReferer(
                    rootURL: rootURL,
                    acID: acID
                )
            )

        let (data, response) =
            try await session.data(
                for: request
            )

        try checkHTTPResponse(
            response
        )

        let text =
            String(
                data: data,
                encoding: .utf8
            ) ?? ""

        print("")
        print(
            "========== get_challenge =========="
        )
        print(text)
        print(
            "===================================="
        )
        print("")

        responseHandler?("get_challenge", text)

        return try parseChallenge(
            text
        )
    }

    // MARK: - srun_portal

    private func srunPortal(
        rootURL: URL,
        state: LoginState,
        checksum: String,
        responseHandler: ((String, String) -> Void)?
    ) async throws -> LoginResult {

        let url =
            rootURL.appendingPathComponent(
                "cgi-bin/srun_portal"
            )

        var components =
            URLComponents(
                url: url,
                resolvingAgainstBaseURL: false
            )!

        // =================================================
        // 这里不能使用 queryItems。
        //
        // 我们需要严格模拟你抓到的成功请求：
        //
        // 空格 -> +
        // /    -> %2F
        // +    -> %2B
        // =    -> %3D
        // {    -> %7B
        // }    -> %7D
        // =================================================

        let encodedCallback =
            formEncode(
                state.callback
            )

        let encodedUsername =
            formEncode(
                state.username
            )

        let encodedPassword =
            formEncode(
                "{MD5}" +
                state.md5Password
            )

        let encodedOS =
            formEncode(
                "Mac OS"
            )

        let encodedName =
            formEncode(
                "Macintosh"
            )

        let encodedChecksum =
            formEncode(
                checksum
            )

        let encodedInfo =
            formEncode(
                state.info
            )

        let encodedACID =
            formEncode(
                state.acID
            )

        let encodedIP =
            formEncode(
                state.ip
            )

        let requestTimestamp =
            timestamp()

        // =================================================
        // 构造 percentEncodedQuery
        // =================================================

        components.percentEncodedQuery =
            "callback=\(encodedCallback)" +
            "&action=login" +
            "&username=\(encodedUsername)" +
            "&password=\(encodedPassword)" +
            "&os=\(encodedOS)" +
            "&name=\(encodedName)" +
            "&double_stack=0" +
            "&chksum=\(encodedChecksum)" +
            "&info=\(encodedInfo)" +
            "&ac_id=\(encodedACID)" +
            "&ip=\(encodedIP)" +
            "&n=200" +
            "&type=1" +
            "&_=\(requestTimestamp)"

        guard let finalURL =
            components.url
        else {
            throw SrunError.invalidURL
        }

        // =================================================
        // 打印最终 URL
        // =================================================

        print("")
        print(
            "========== SRUN LOGIN URL =========="
        )
        print(
            finalURL.absoluteString
        )
        print(
            "===================================="
        )
        print("")

        // =================================================
        // 编码检查
        // =================================================

        let absoluteURL =
            finalURL.absoluteString

        print("")
        print(
            "========== URL ENCODE CHECK =========="
        )

        print(
            "SRBX1 encoded:",
            absoluteURL.contains(
                "%7BSRBX1%7D"
            )
        )

        print(
            "slash encoded:",
            absoluteURL.contains(
                "%2F"
            )
        )

        print(
            "plus encoded:",
            absoluteURL.contains(
                "%2B"
            )
        )

        print(
            "equal encoded:",
            absoluteURL.contains(
                "%3D"
            )
        )

        print(
            "space as +:",
            absoluteURL.contains(
                "os=Mac+OS"
            )
        )

        print(
            "n=200:",
            absoluteURL.contains(
                "&n=200&"
            )
        )

        print(
            "======================================"
        )
        print("")

        // =================================================
        // HTTP Request
        // =================================================

        let request =
            makeRequest(
                url: finalURL,
                referer: buildReferer(
                    rootURL: rootURL,
                    acID: state.acID
                )
            )

        let (data, response) =
            try await session.data(
                for: request
            )

        try checkHTTPResponse(
            response
        )

        let text =
            String(
                data: data,
                encoding: .utf8
            ) ?? ""

        print("")
        print(
            "========== SRUN LOGIN RESPONSE =========="
        )
        print(text)
        print(
            "=========================================="
        )
        print("")

        responseHandler?("srun_portal", text)

        return parseLoginResult(
            text,
            ip: state.ip
        )
    }

    // MARK: - Form URL Encode

    private func formEncode(
        _ value: String
    ) -> String {

        // application/x-www-form-urlencoded
        //
        // 保留：
        // A-Z a-z 0-9
        // -
        // .
        // _
        // *
        //
        // 空格：
        // %20 -> +
        //
        // 其他全部 percent encode。

        var allowed =
            CharacterSet.alphanumerics

        allowed.insert(
            charactersIn: "-._*"
        )

        guard let encoded =
            value.addingPercentEncoding(
                withAllowedCharacters:
                    allowed
            )
        else {
            return value
        }

        return encoded.replacingOccurrences(
            of: "%20",
            with: "+"
        )
    }

    // MARK: - HTTP Request

    private func makeRequest(
        url: URL,
        referer: String
    ) -> URLRequest {

        var request =
            URLRequest(
                url: url,
                timeoutInterval: 10
            )

        request.httpMethod = "GET"

        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " +
            "AppleWebKit/537.36 (KHTML, like Gecko) " +
            "Chrome/125.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )

        request.setValue(
            "gzip, deflate",
            forHTTPHeaderField:
                "Accept-Encoding"
        )

        request.setValue(
            "text/javascript, application/javascript, " +
            "application/ecmascript, application/x-ecmascript, " +
            "*/*; q=0.01",
            forHTTPHeaderField:
                "Accept"
        )

        request.setValue(
            "zh-CN,zh;q=0.9",
            forHTTPHeaderField:
                "Accept-Language"
        )

        request.setValue(
            "XMLHttpRequest",
            forHTTPHeaderField:
                "X-Requested-With"
        )

        // Fetch Metadata

        request.setValue(
            "empty",
            forHTTPHeaderField:
                "Sec-Fetch-Dest"
        )

        request.setValue(
            "cors",
            forHTTPHeaderField:
                "Sec-Fetch-Mode"
        )

        request.setValue(
            "same-origin",
            forHTTPHeaderField:
                "Sec-Fetch-Site"
        )

        request.setValue(
            referer,
            forHTTPHeaderField:
                "Referer"
        )

        request.setValue(
            "lang=zh-CN",
            forHTTPHeaderField:
                "Cookie"
        )

        request.setValue(
            "keep-alive",
            forHTTPHeaderField:
                "Connection"
        )

        request.setValue(
            "u=3, i",
            forHTTPHeaderField:
                "Priority"
        )

        return request
    }

    // MARK: - Referer

    private func buildReferer(
        rootURL: URL,
        acID: String
    ) -> String {

        return
            "\(rootURL.absoluteString)" +
            "/srun_portal_pc" +
            "?ac_id=\(acID)" +
            "&theme=pro"
    }

    // MARK: - Timestamp

    private func timestamp() -> String {

        return String(
            Int(
                Date()
                    .timeIntervalSince1970
                    * 1000
            )
        )
    }

    // MARK: - Portal Detection

    private func extractPortalURL(
        from html: String,
        baseURL: URL
    ) -> URL? {

        let pattern =
            #"(?i)<meta[^>]+http-equiv=["']?refresh["']?[^>]+content=["'][^"']*url=([^"']+)["']"#

        guard let regex =
            try? NSRegularExpression(
                pattern: pattern
            )
        else {
            return nil
        }

        let range =
            NSRange(
                html.startIndex...,
                in: html
            )

        guard let match =
            regex.firstMatch(
                in: html,
                range: range
            )
        else {
            return nil
        }

        guard match.numberOfRanges > 1,
              let valueRange =
                Range(
                    match.range(at: 1),
                    in: html
                )
        else {
            return nil
        }

        let path =
            String(
                html[valueRange]
            )
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .replacingOccurrences(
                of: "&amp;",
                with: "&"
            )

        return URL(
            string: path,
            relativeTo: baseURL
        )?.absoluteURL
    }

    private func extractLocationHref(
        from html: String,
        baseURL: URL
    ) -> URL? {

        let pattern =
            #"(?i)location\.href\s*=\s*["']([^"']+)["']"#

        guard let regex =
            try? NSRegularExpression(
                pattern: pattern
            )
        else {
            return nil
        }

        let range =
            NSRange(
                html.startIndex...,
                in: html
            )

        guard let match =
            regex.firstMatch(
                in: html,
                range: range
            ),
            match.numberOfRanges > 1,
            let valueRange =
                Range(
                    match.range(at: 1),
                    in: html
                )
        else {
            return nil
        }

        let path =
            String(
                html[valueRange]
            )
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .replacingOccurrences(
                of: "&amp;",
                with: "&"
            )

        return URL(
            string: path,
            relativeTo: baseURL
        )?.absoluteURL
    }

    // MARK: - Parse User Info

    private func parseUserInfo(
        _ text: String
    ) throws -> UserInfo {

        guard let json =
            extractJSON(
                from: text
            )
        else {
            throw SrunError.invalidUserInfoResponse
        }

        guard let object =
            try? JSONSerialization.jsonObject(
                with: Data(json.utf8)
            ) as? [String: Any]
        else {
            throw SrunError.invalidUserInfoResponse
        }

        let ip: String

        if object["client_ip"] == nil {

            ip =
                object["online_ip"] as? String
                ?? ""

        } else {

            ip =
                object["client_ip"] as? String
                ?? ""
        }

        let cleanIP =
            ip.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !cleanIP.isEmpty else {
            throw SrunError.userIPMissing
        }

        return UserInfo(
            ip: cleanIP
        )
    }

    // MARK: - Parse Challenge

    private func parseChallenge(
        _ text: String
    ) throws -> String {

        guard let json =
            extractJSON(
                from: text
            )
        else {
            throw SrunError.invalidChallengeResponse
        }

        guard let object =
            try? JSONSerialization.jsonObject(
                with: Data(json.utf8)
            ) as? [String: Any]
        else {
            throw SrunError.invalidChallengeResponse
        }

        guard let challenge =
            object["challenge"] as? String,
            !challenge.isEmpty
        else {
            throw SrunError.challengeMissing
        }

        return challenge
    }

    // MARK: - Parse Login Result

    private func parseLoginResult(
        _ text: String,
        ip: String
    ) -> LoginResult {

        guard let json =
            extractJSON(
                from: text
            ),
            let object =
                try? JSONSerialization.jsonObject(
                    with: Data(json.utf8)
                ) as? [String: Any]
        else {

            return LoginResult(
                loggedIn: false,
                ip: ip.isEmpty ? nil : ip,
                message: "无法解析服务器响应",
                raw: text
            )
        }

        let error =
            object["error"] as? String
            ?? ""

        let message =
            object["error_msg"] as? String
            ?? object["msg"] as? String
            ?? ""

        let success =
            error == "ok"
            || error == "login_ok"
            || message.contains(
                "登录成功"
            )
            || message.contains(
                "成功"
            )
            || message.contains(
                "Login is successful"
            )

        return LoginResult(
            loggedIn: success,
            ip: ip.isEmpty ? nil : ip,
            message:
                message.isEmpty
                ? error
                : message,
            raw: text
        )
    }

    // MARK: - JSONP → JSON

    private func extractJSON(
        from text: String
    ) -> String? {

        guard let start =
            text.firstIndex(
                of: "{"
            ),
            let end =
                text.lastIndex(
                    of: "}"
                ),
            start <= end
        else {
            return nil
        }

        return String(
            text[start...end]
        )
    }

    // MARK: - HTTP Status

    private func checkHTTPResponse(
        _ response: URLResponse
    ) throws {

        guard let http =
            response as? HTTPURLResponse
        else {
            throw SrunError.invalidResponse
        }

        guard
            (200..<400).contains(
                http.statusCode
            )
        else {
            throw SrunError.httpError(
                http.statusCode
            )
        }
    }
}
