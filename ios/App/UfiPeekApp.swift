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
    private var p: UfiPalette { UfiPalette(dark: scheme == .dark) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                connectionCard
                preview
                widgetHelp
            }
            .frame(maxWidth: 520)
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
        }
        .background(p.screen.ignoresSafeArea())
        .foregroundStyle(p.text)
        .tint(p.accent)
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

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.router.fill")
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(p.accent)
                .frame(width: 48, height: 48)
                .background(p.daily, in: RoundedRectangle(cornerRadius: 12))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("UfiPeek")
                    .font(.title.bold())
                    .accessibilityAddTraits(.isHeader)
                Text("查看随身 WiFi 的流量、电量和信号")
                    .font(.footnote)
                    .foregroundStyle(p.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(p.widgetBackground, in: RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22).strokeBorder(p.divider)
        }
    }

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                heading("连接设置")
                Text("支持局域网与公网地址")
                    .font(.footnote)
                    .foregroundStyle(p.secondary)
            }
            field("后台地址", icon: "link") {
                TextField(UfiConfig.defaultURL, text: $url)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityLabel("后台地址")
            }
            field("UFI 密码", icon: "lock") {
                SecureField("UFI-TOOLS 后台密码", text: $password)
                    .accessibilityLabel("UFI 密码")
            }
            field("ZTE 密码（选填）", icon: "key") {
                SecureField("留空则使用 UFI 密码", text: $ztePassword)
                    .accessibilityLabel("ZTE 密码（选填）")
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    testButton
                    saveButton
                }
                VStack(spacing: 8) {
                    testButton
                    saveButton
                }
            }
            .padding(.top, 2)

            if testing {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("连接中…")
                }
                .font(.footnote)
                .foregroundStyle(p.secondary)
            } else if let result = testResult {
                let missing = result.missingNetworkData
                if let error = result.error {
                    Label(error, systemImage: "exclamationmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(p.error)
                } else if missing.isEmpty {
                    Label("连接成功", systemImage: "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(p.success)
                } else {
                    Label("已连接，未读到：\(missing.joined(separator: "、"))", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(p.secondary)
                }
            }
        }
        .padding(16)
        .background(p.surface, in: RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22).strokeBorder(p.divider)
        }
    }

    private func field<Content: View>(_ label: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.footnote.weight(.semibold))
                .accessibilityHidden(true)
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(p.secondary)
                    .frame(width: 18)
                    .accessibilityHidden(true)
                content()
            }
            .font(.subheadline)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(minHeight: 46)
            .background(p.field, in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12).strokeBorder(p.divider)
            }
        }
    }

    private var testButton: some View {
        Button {
            Task { await test() }
        } label: {
            actionLabel("测试连接", icon: "bolt.horizontal", fill: p.daily, color: p.text)
        }
        .buttonStyle(.plain)
        .disabled(!config.isConfigured || testing)
        .opacity(!config.isConfigured || testing ? 0.55 : 1)
    }

    private var saveButton: some View {
        Button {
            UfiStore.save(config)
            WidgetCenter.shared.reloadAllTimelines()
            savedTip = true
        } label: {
            actionLabel("保存并刷新", icon: "arrow.clockwise", fill: p.accent, color: p.onAccent)
        }
        .buttonStyle(.plain)
        .disabled(!config.isConfigured)
        .opacity(config.isConfigured ? 1 : 0.55)
    }

    private func actionLabel(_ title: String, icon: String, fill: Color, color: Color) -> some View {
        Label(title, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 48)
            .foregroundStyle(color)
            .background(fill, in: RoundedRectangle(cornerRadius: 12))
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                heading("小组件预览")
                Spacer()
                if snap == nil {
                    Text("示例数据")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(p.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(p.daily, in: Capsule())
                }
            }
            MediumWidgetView(snap: snap ?? .placeholder)
                .frame(height: 144)
                .background(p.widgetBackground, in: RoundedRectangle(cornerRadius: 22))
                .overlay {
                    RoundedRectangle(cornerRadius: 22).strokeBorder(p.divider)
                }
        }
    }

    private var widgetHelp: some View {
        VStack(alignment: .leading, spacing: 8) {
            heading("添加到桌面")
            Text("长按桌面空白处，在小组件列表中搜索 UfiPeek，可选择中号或小号。点一下小组件即可刷新。")
            Text("首次测试连接时请允许访问局域网。若小组件提示填写后台地址，请长按它，选择「编辑小组件」并填写连接设置。")
        }
        .font(.footnote)
        .foregroundStyle(p.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(p.surface, in: RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22).strokeBorder(p.divider)
        }
    }

    private func heading(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(p.text)
            .accessibilityAddTraits(.isHeader)
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
