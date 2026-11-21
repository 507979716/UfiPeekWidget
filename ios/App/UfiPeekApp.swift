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
    private enum PreviewSize: String, CaseIterable, Identifiable {
        case small = "小号"
        case medium = "中号"

        var id: Self { self }
    }

    private enum Field: Hashable { case address, password, ztePassword }

    @State private var url = UfiConfig.defaultURL
    @State private var password = ""
    @State private var ztePassword = ""
    @State private var testing = false
    @State private var snap: UfiSnapshot?
    @State private var testResult: UfiSnapshot?
    @State private var testedConfig: UfiConfig?
    @State private var saveMessage: String?
    @State private var previewSize: PreviewSize = .medium
    @FocusState private var focusedField: Field?
    @Environment(\.colorScheme) private var scheme

    private var config: UfiConfig { UfiConfig(url: url, password: password, ztePassword: ztePassword) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        Picker("预览尺寸", selection: $previewSize) {
                            ForEach(PreviewSize.allCases) { size in
                                Text(size.rawValue).tag(size)
                            }
                        }
                        .pickerStyle(.segmented)

                        widgetPreview
                    }
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
                            .focused($focusedField, equals: .address)
                            .accessibilityLabel("后台地址")
                    }
                    field("UFI 密码") {
                        SecureField("UFI-TOOLS 后台密码", text: $password)
                            .focused($focusedField, equals: .password)
                            .accessibilityLabel("UFI 密码")
                    }
                    field("ZTE 密码（选填）") {
                        SecureField("留空则使用 UFI 密码", text: $ztePassword)
                            .focused($focusedField, equals: .ztePassword)
                            .accessibilityLabel("ZTE 密码（选填）")
                    }
                }

                Section {
                    Button {
                        focusedField = nil
                        Task { await refresh(save: false) }
                    } label: {
                        HStack {
                            Label("测试连接", systemImage: "antenna.radiowaves.left.and.right")
                            Spacer()
                            if testing { ProgressView().controlSize(.small) }
                        }
                    }
                    .disabled(!config.isConfigured || testing)

                    Button {
                        focusedField = nil
                        Task { await refresh(save: true) }
                    } label: {
                        Label("保存并刷新", systemImage: "arrow.clockwise")
                            .fontWeight(.semibold)
                    }
                    .disabled(!config.isConfigured || testing)
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

                if !UfiStore.canShareWithWidget {
                    Section {
                        Label("当前签名无法在 App 和小组件之间共享设置", systemImage: "exclamationmark.circle")
                    } footer: {
                        Text("长按桌面上的 UfiPeek，点「编辑小组件」，在里面填写后台地址和密码。")
                    }
                }

                Section {
                    DisclosureGroup("添加小组件") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("主屏幕或锁屏都可以添加 UfiPeek。主屏幕的小组件点一下即可刷新。")
                            Text("首次测试请允许访问局域网。若 App 能连接但小组件没有数据，可长按小组件，在「编辑小组件」中填写连接设置。")
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("UfiPeek")
            .navigationBarTitleDisplayMode(.large)
            .scrollDismissesKeyboard(.interactively)
            .alert("已保存", isPresented: Binding(
                get: { saveMessage != nil },
                set: { if !$0 { saveMessage = nil } }
            )) {
                Button("好") {}
            } message: {
                if let saveMessage = saveMessage { Text(saveMessage) }
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

    private var widgetPreview: some View {
        let snapshot = snap ?? .placeholder
        let background = UfiPalette(dark: scheme == .dark).widgetBackground
        return Group {
            switch previewSize {
            case .small:
                SmallWidgetView(snap: snapshot)
                    .frame(width: 146, height: 146)
                    .background(background, in: RoundedRectangle(cornerRadius: 22))
                    .frame(maxWidth: .infinity)
            case .medium:
                MediumWidgetView(snap: snapshot)
                    .frame(height: 146)
                    .background(background, in: RoundedRectangle(cornerRadius: 22))
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
    private func refresh(save: Bool) async {
        guard config.isConfigured && !testing else { return }
        let requested = config
        testing = true
        defer { testing = false }
        let result: UfiSnapshot
        if save, let testedConfig = testedConfig, let tested = testResult,
           testedConfig.usesSameConnection(as: requested), tested.error == nil, tested.hasData,
           (-5...20).contains(Date().timeIntervalSince(tested.updatedAt)) {
            result = tested
        } else {
            result = await UfiClient(config: requested).fetch()
        }
        guard requested == config else { return }
        if save { UfiStore.save(requested) }
        snap = result
        testResult = result
        testedConfig = requested
        UfiStore.saveSnapshot(result, for: requested)
        if save || (result.error == nil && requested.usesSameConnection(as: UfiStore.load())) {
            WidgetCenter.shared.reloadAllTimelines()
        }
        guard save else { return }
        if let error = result.error {
            saveMessage = "设置已保存。\(error)"
        } else if !UfiStore.canShareWithWidget {
            saveMessage = "已读取设备数据。请长按桌面小组件，在「编辑小组件」里填写地址和密码。"
        } else {
            saveMessage = "已读取设备数据，并请求刷新小组件。"
        }
    }
}
