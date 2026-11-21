import SwiftUI
import WidgetKit

@main
struct UfiPeekApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var url = ""
    @State private var password = ""
    @State private var ztePassword = ""
    @State private var testing = false
    @State private var snap: UfiSnapshot?
    @State private var testResult: UfiSnapshot?
    @State private var savedTip = false
    @Environment(\.colorScheme) private var scheme

    private var config: UfiConfig { UfiConfig(url: url, password: password, ztePassword: ztePassword) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    MediumWidgetView(snap: snap ?? .placeholder)
                        .frame(height: 146)
                        .background(UfiPalette(dark: scheme == .dark).widgetBackground,
                                    in: RoundedRectangle(cornerRadius: 22))
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                } header: {
                    HStack {
                        Text("小组件预览")
                        Spacer()
                        if snap == nil { Text("示例数据") }
                    }
                }

                Section("连接设置") {
                    field("后台地址") {
                        TextField(UfiConfig.defaultURL, text: $url)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityLabel("后台地址")
                    }
                    field("UFI 密码") {
                        SecureField("UFI-TOOLS 后台密码", text: $password)
                            .accessibilityLabel("UFI 密码")
                    }
                    field("ZTE 密码（选填）") {
                        SecureField("留空则使用 UFI 密码", text: $ztePassword)
                            .accessibilityLabel("ZTE 密码（选填）")
                    }
                }

                Section {
                    Button {
                        Task { await test() }
                    } label: {
                        HStack {
                            Text("测试连接")
                            Spacer()
                            if testing { ProgressView().controlSize(.small) }
                        }
                    }
                    .disabled(!config.isConfigured || testing)

                    Button {
                        UfiStore.save(config)
                        WidgetCenter.shared.reloadAllTimelines()
                        savedTip = true
                    } label: {
                        Text("保存并刷新").fontWeight(.semibold)
                    }
                    .disabled(!config.isConfigured)
                } footer: {
                    if testing {
                        Text("连接中…")
                    } else if let result = testResult {
                        if let error = result.error {
                            Text(error).foregroundStyle(.red)
                        } else if result.missingNetworkData.isEmpty {
                            Text("连接成功")
                        } else {
                            Text("已连接，未读到：\(result.missingNetworkData.joined(separator: "、"))")
                        }
                    }
                }

                Section("添加到桌面") {
                    Text("长按桌面空白处，在小组件列表中搜索 UfiPeek。点一下小组件即可刷新。")
                    Text("首次测试连接时请允许访问局域网。若小组件提示填写后台地址，请长按它，选择「编辑小组件」并填写连接设置。")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .navigationTitle("UfiPeek")
            .navigationBarTitleDisplayMode(.large)
            .scrollDismissesKeyboard(.interactively)
            .alert("已保存", isPresented: $savedTip) {
                Button("好") {}
            } message: {
                Text("已请求刷新小组件。")
            }
            .onAppear {
                let saved = UfiStore.load()
                url = saved.url
                password = saved.password
                ztePassword = saved.ztePassword
                snap = UfiStore.lastSnapshot()
            }
        }
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            content()
        }
        .padding(.vertical, 3)
    }

    @MainActor
    private func test() async {
        guard config.isConfigured && !testing else { return }
        testing = true
        defer { testing = false }
        let result = await UfiClient(config: config).fetch()
        snap = result
        testResult = result
        if result.error == nil { UfiStore.saveSnapshot(result) }
    }
}
