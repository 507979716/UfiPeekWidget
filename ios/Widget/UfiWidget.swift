import WidgetKit
import SwiftUI
import AppIntents

// 长按小组件 →「编辑小组件」即可填写；留空则使用 App 里保存的设置
struct UfiConfigIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "UfiPeek 设置"
    static var description = IntentDescription("填写 UFI-TOOLS 后台地址与密码。留空则使用 UfiPeek App 内保存的设置。")

    @Parameter(title: "后台地址", description: "例如 http://192.168.0.1:2333")
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
        if context.isPreview {
            return UfiEntry(date: Date(), snap: UfiStore.lastSnapshot() ?? .placeholder)
        }
        return UfiEntry(date: Date(), snap: await load(configuration))
    }

    func timeline(for configuration: UfiConfigIntent, in context: Context) async -> Timeline<UfiEntry> {
        let snap = await load(configuration)
        let next = Date().addingTimeInterval(15 * 60)
        return Timeline(entries: [UfiEntry(date: Date(), snap: snap)], policy: .after(next))
    }

    private func load(_ c: UfiConfigIntent) async -> UfiSnapshot {
        var cfg = UfiStore.load()
        if let u = c.url, !u.trimmed.isEmpty { cfg.url = u }
        if let p = c.password, !p.trimmed.isEmpty { cfg.password = p }
        if let z = c.ztePassword, !z.trimmed.isEmpty { cfg.ztePassword = z }

        guard cfg.isConfigured else {
            var s = UfiSnapshot()
            s.error = "长按 →编辑小组件，填写后台地址"
            return s
        }

        let fresh = await UfiClient(config: cfg).fetch()
        if fresh.error == nil {
            UfiStore.saveSnapshot(fresh)
            return fresh
        }
        // 失败时保留上次数据，只在底栏提示错误
        if var last = UfiStore.lastSnapshot(), last.hasData {
            last.error = fresh.error
            return last
        }
        return fresh
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
                family == .accessoryRectangular ? Color.clear : p.bg
            }
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryRectangular:
            LockRectView(snap: entry.snap)
        case .systemSmall:
            Button(intent: RefreshIntent()) {
                SmallWidgetView(snap: entry.snap)
            }
            .buttonStyle(.plain)
        default:
            Button(intent: RefreshIntent()) {
                MediumWidgetView(snap: entry.snap)
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
