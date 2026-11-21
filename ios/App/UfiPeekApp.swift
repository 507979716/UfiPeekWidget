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
    @State private var savedTip = false
    @Environment(\.colorScheme) private var scheme

    private var config: UfiConfig { UfiConfig(url: url, password: password, ztePassword: ztePassword) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("http://192.168.0.1:2333", text: $url)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("UFI-TOOLS 后台密码", text: $password)
                    SecureField("ZTE 后台密码（不同才填，可留空）", text: $ztePassword)
                } header: {
                    Text("UFI-TOOLS 连接")
                } footer: {
                    Text("和 UfiPeek 脚本的三个设置项一致。公网地址、局域网地址都可以。")
                }

                Section {
                    Button {
                        UfiStore.save(config)
                        WidgetCenter.shared.reloadAllTimelines()
                        savedTip = true
                    } label: {
                        Label("保存并刷新小组件", systemImage: "square.and.arrow.down")
                    }
                    .disabled(!config.isConfigured)

                    Button {
                        Task { await test() }
                    } label: {
                        HStack {
                            Label("测试连接", systemImage: "bolt.horizontal.circle")
                            Spacer()
                            if testing { ProgressView() }
                        }
                    }
                    .disabled(!config.isConfigured || testing)
                }

                if let s = snap {
                    Section {
                        MediumWidgetView(snap: s)
                            .frame(height: 158)
                            .background(UfiPalette(dark: scheme == .dark).bg)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                            .listRowBackground(Color.clear)
                        if let e = s.error {
                            Text(e).foregroundStyle(.red)
                        } else {
                            Text(s.zreqOK ? "zreq 自动登录：成功" : "zreq 不可用，已回退为直接读取 goform")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("小组件预览")
                    }
                }

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("1. 先在上面填好并点「测试连接」，首次会弹出局域网权限，请允许。")
                        Text("2. 点「保存并刷新小组件」。")
                        Text("3. 回到桌面长按空白处 → 左上角「+」→ 搜索 UfiPeek → 选中号或小号。")
                        Text("4. 如果小组件显示「长按 → 编辑小组件」，说明自签名后 App 与小组件不能共享设置：长按小组件 → 编辑小组件，直接在里面填地址和密码即可。")
                        Text("5. 点一下小组件即可立即刷新；系统也会大约每 15 分钟自动刷新。")
                    }
                    .font(.footnote)
                } header: {
                    Text("添加到桌面")
                }
            }
            .navigationTitle("UfiPeek")
            .alert("已保存", isPresented: $savedTip) {
                Button("好") {}
            } message: {
                Text("小组件会在几秒内刷新。")
            }
            .onAppear {
                let c = UfiStore.load()
                url = c.url
                password = c.password
                ztePassword = c.ztePassword
                snap = UfiStore.lastSnapshot()
            }
        }
    }

    private func test() async {
        testing = true
        let result = await UfiClient(config: config).fetch()
        snap = result
        if result.error == nil { UfiStore.saveSnapshot(result) }
        testing = false
    }
}
