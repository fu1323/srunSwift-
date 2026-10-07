
import Foundation
import SwiftUI

@MainActor
final class PortalViewModel: ObservableObject {
    @Published var username = ""
    @Published var password = ""
    @Published var rootURL = "http://192.168.88.7"
    @Published var testIP = "223.5.5.5"
    @Published var saveCredentials = true

    @Published var status = "等待操作"
    @Published var currentIP: String?
    @Published var errorMessage: String?
    @Published var isBusy = false
    @Published var isSuccess = false

    private let keychain = KeychainStore()
    private let client = SrunClient()

    func load() {
        username = UserDefaults.standard.string(forKey: "username") ?? ""
        rootURL = UserDefaults.standard.string(forKey: "rootURL") ?? "http://192.168.88.7"
        testIP = UserDefaults.standard.string(forKey: "testIP") ?? "223.5.5.5"

        if let saved = keychain.read(service: "SrunPortal", account: username), !saved.isEmpty {
            password = saved
        }
    }

    func checkAndLogin() async {
        isBusy = true
        isSuccess = false
        errorMessage = nil
        currentIP = nil
        status = "正在检查网络…"

        if saveCredentials {
            UserDefaults.standard.set(username, forKey: "username")
            UserDefaults.standard.set(rootURL, forKey: "rootURL")
            UserDefaults.standard.set(testIP, forKey: "testIP")
            keychain.save(password, service: "SrunPortal", account: username)
        }

        do {
            let result = try await client.checkAndLogin(
                username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password,
               // rootURL: normalizedRootURL(rootURL),
                testIP: testIP.trimmingCharacters(in: .whitespacesAndNewlines),
                progress: { [weak self] message in
                    Task { @MainActor in
                        self?.status = message
                    }
                }
            )

            currentIP = result.ip
            status = result.loggedIn ? "认证成功" : "当前网络已正常，无需认证"
            isSuccess = true
        } catch {
            status = "认证失败"
            errorMessage = error.localizedDescription
        }

        isBusy = false
    }

    private func normalizedRootURL(_ value: String) -> String {
        var v = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if !v.hasPrefix("http://") && !v.hasPrefix("https://") {
            v = "http://" + v
        }
        while v.hasSuffix("/") { v.removeLast() }
        return v
    }
}
