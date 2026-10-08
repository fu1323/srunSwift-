
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: PortalViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("校园网认证") {
                    TextField("用户名", text: $model.username)
                       // .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("密码", text: $model.password)

                    TextField("认证服务器 URL", text: $model.rootURL)
                      //  .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                     //   .keyboardType(.URL)

                    TextField("联网检测地址", text: $model.testIP)
                       // .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                      //  .keyboardType(.URL)
                }

                Section {
                    Button {
                        Task { await model.checkAndLogin() }
                    } label: {
                        HStack {
                            Spacer()
                            if model.isBusy {
                                ProgressView()
                            } else {
                                Text("检查网络并认证")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .disabled(model.isBusy || model.username.isEmpty || model.password.isEmpty)
                }

                Section("状态") {
                    Label(model.status, systemImage: model.isSuccess ? "checkmark.circle.fill" : "info.circle")
                        .foregroundStyle(model.isSuccess ? .green : .primary)

                    if let ip = model.currentIP {
                        LabeledContent("当前 IP", value: ip)
                    }

                    if let error = model.errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }

                Section("本次服务器响应") {
                    if model.responseLog.isEmpty {
                        Text("执行后会在这里显示本次认证过程中服务器返回的 JSONP 原文。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ScrollView([.vertical, .horizontal]) {
                            Text(model.responseLog)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                        }
                        .frame(minHeight: 180, maxHeight: 320)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.08))
                        )
                    }
                }

                Section {
                    Toggle("保存账号密码", isOn: $model.saveCredentials)
                } footer: {
                    Text("密码使用 iOS Keychain 保存，不写入普通配置文件。")
                }

                Section("说明") {
                    Text("这是深澜（SRun）校园网认证客户端的 iPadOS 原生实现。首次使用请填写认证服务器地址；通常填写校园网 Portal 使用的根地址，例如 http://192.168.x.x。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("SRun Portal")
            .task {
                model.load()
            }
        }
    }
}
