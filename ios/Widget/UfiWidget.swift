import WidgetKit
import SwiftUI
import AppIntents

// 长按小组件 →「编辑小组件」即可填写；留空则使用 App 里保存的设置
struct UfiConfigIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "UfiPeek 设置"
    static var description = IntentDescription("填写 UFI-TOOLS 后台地址与密码。留空则使用 UfiPeek App 内保存的设置。")

    @Parameter(title: "后台地址", description: "留空时使用 App 设置，未设置则使用 http://192.168.88.1:2333")
    var url: String?

    @Parameter(title: "UFI 密码")
    var password: String?

    @Parameter(title: "ZTE 密码（可留空）")
    var ztePassword: String?
}

// 点击整张卡片刷新
struct RefreshIntent: AppIntent {
    static var title: LocalizedStringResource = "刷新 UfiPeek"

    func perform() async throws -> some IntentResult {
        .result()
    }
}

struct UfiEntry: TimelineEntry {
    let date: Date
    let snap: UfiSnapshot
}

struct UfiProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> UfiEntry {
        UfiEntry(date: Date(), snap: .placeholder)
    }

    func snapshot(for configuration: UfiConfigIntent, in context: Context) async -> UfiEntry {
        let cached = cachedSnapshot(for: resolvedConfig(configuration))
        let fallback = context.isPreview ? UfiSnapshot.placeholder : unavailableSnapshot()
        return UfiEntry(date: Date(), snap: cached ?? fallback)
    }

    func timeline(for configuration: UfiConfigIntent, in context: Context) async -> Timeline<UfiEntry> {
        let cfg = resolvedConfig(configuration)
        let cached = cachedSnapshot(for: cfg)
        let isConfiguredInWidget = configuration.url?.trimmed.isEmpty == false
            || configuration.password?.trimmed.isEmpty == false
            || configuration.ztePassword?.trimmed.isEmpty == false
        let snap = await load(cfg, cached: cached, isConfiguredInWidget: isConfiguredInWidget)
        let next = Date().addingTimeInterval(15 * 60)
        return Timeline(entries: [UfiEntry(date: Date(), snap: snap)], policy: .after(next))
    }

    private func resolvedConfig(_ c: UfiConfigIntent) -> UfiConfig {
        var cfg = UfiStore.load()
        if let u = c.url, !u.trimmed.isEmpty { cfg.url = u }
        if let p = c.password, !p.trimmed.isEmpty { cfg.password = p }
        if let z = c.ztePassword, !z.trimmed.isEmpty { cfg.ztePassword = z }

        return cfg
    }

    private func cachedSnapshot(for cfg: UfiConfig) -> UfiSnapshot? {
        guard cfg.usesSameConnection(as: UfiStore.load()),
              let snap = UfiStore.lastSnapshot(), snap.hasData else { return nil }
        return snap
    }

    private func unavailableSnapshot(reason: String? = nil) -> UfiSnapshot {
        var snap = UfiSnapshot()
        snap.error = reason ?? "打开 UfiPeek 测试连接并保存"
        return snap
    }

    private func load(_ cfg: UfiConfig, cached: UfiSnapshot?, isConfiguredInWidget: Bool) async -> UfiSnapshot {
        // 刚在 App 内保存的数据已可用，无需让 WidgetKit 再等一轮网络。
        if let cached = cached, (-5...20).contains(Date().timeIntervalSince(cached.updatedAt)) {
            return cached
        }
        let fresh = await UfiClient(config: cfg).fetchForWidget()
        if fresh.hasData && fresh.error == nil {
            UfiStore.saveSnapshot(fresh, for: cfg)
            return fresh
        }
        if var cached = cached {
            cached.error = fresh.error
            return cached
        }
        if !UfiStore.canShareWithWidget && !isConfiguredInWidget {
            return unavailableSnapshot(reason: "长按小组件，在「编辑小组件」里填写地址和密码")
        }
        return unavailableSnapshot(reason: fresh.error)
    }
}

struct UfiWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var scheme
    let entry: UfiEntry

    var body: some View {
        let p = UfiPalette(dark: scheme == .dark)
        content
            .containerBackground(for: .widget) {
                if family == .accessoryRectangular {
                    Color.clear
                } else {
                    p.widgetBackground
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryRectangular:
            if entry.snap.hasData {
                LockRectView(snap: entry.snap)
            } else {
                WidgetStatusView(message: entry.snap.error, lockScreen: true)
            }
        case .systemSmall:
            Button(intent: RefreshIntent()) {
                if entry.snap.hasData {
                    SmallWidgetView(snap: entry.snap)
                } else {
                    WidgetStatusView(message: entry.snap.error)
                }
            }
            .buttonStyle(.plain)
        default:
            Button(intent: RefreshIntent()) {
                if entry.snap.hasData {
                    MediumWidgetView(snap: entry.snap)
                } else {
                    WidgetStatusView(message: entry.snap.error)
                }
            }
            .buttonStyle(.plain)
        }
    }
}

struct UfiWidget: Widget {
    let kind = "UfiPeekWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: UfiConfigIntent.self, provider: UfiProvider()) { entry in
            UfiWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("UfiPeek")
        .description("随身 WiFi 流量 / 电量 / 信号，点一下刷新")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}

@main
struct UfiWidgetBundle: WidgetBundle {
    var body: some Widget {
        UfiWidget()
    }
}
