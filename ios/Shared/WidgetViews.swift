import SwiftUI
import WidgetKit

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

struct UfiPalette {
    let dark: Bool

    var text: Color { color(0x1C1C1E, 0xF5F5F7) }
    var secondary: Color { color(0x5F5F66, 0xAEAEB2) }
    var accent: Color { color(0x005EC4, 0x64ACFF) }
    var divider: Color { color(0xD1D1D6, 0x38383A) }
    var error: Color { color(0xB32626, 0xFF9A91) }
    var widgetBackground: Color { color(0xFFFFFF, 0x1C1C1E) }

    private func color(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(hex: self.dark ? dark : light)
    }
}

private struct TrafficValue: View {
    let title: String
    let value: String
    let unit: String
    let p: UfiPalette
    var numberSize: CGFloat = 28

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(p.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: numberSize, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(p.text)
                    .minimumScaleFactor(0.55)
                Text(unit)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(p.secondary)
                    .fixedSize()
            }
            .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct WidgetMetric: View {
    let icon: String
    let label: String
    let value: String?
    let p: UfiPalette
    var flexible = false
    var alert = false

    var body: some View {
        if let value = value {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .foregroundStyle(alert ? p.error : p.secondary)
                    .accessibilityHidden(true)
                Text(value)
                    .foregroundStyle(p.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .font(.system(size: 10, weight: .medium))
            .frame(maxWidth: flexible ? .infinity : nil, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(label))
            .accessibilityValue(Text(value))
        }
    }
}

private struct WidgetHeader: View {
    let snap: UfiSnapshot
    let p: UfiPalette
    var detailed = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "wifi.router.fill")
                .foregroundStyle(p.accent)
                .widgetAccentable()
                .accessibilityHidden(true)
            Text(snap.model == "--" ? "UfiPeek" : snap.model)
                .fontWeight(.semibold)
                .foregroundStyle(p.text)
                .layoutPriority(1)
            if detailed && snap.ufiVersion != "--" {
                Text("UFI v\(snap.ufiVersion)")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(p.secondary)
            }
            Spacer(minLength: 2)
            if detailed && snap.signalBar != "--" {
                HStack(spacing: 3) {
                    Image(systemName: "cellularbars", variableValue: snap.signalFraction)
                        .foregroundStyle(p.secondary)
                    Text(snap.signalBar)
                }
                .fixedSize()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("信号 \(snap.signalBar) 格"))
            }
            if snap.battery != "--" {
                HStack(spacing: 3) {
                    Image(systemName: snap.batteryIcon)
                        .font(.system(size: 13))
                        .foregroundStyle(Color(hex: snap.batteryColorHex))
                    Text("\(snap.battery)%")
                        .fontWeight(.semibold)
                }
                .fixedSize()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("电量 \(snap.battery)%"))
            }
        }
        .font(.system(size: 12, weight: .medium))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .foregroundStyle(p.text)
    }
}

private struct WidgetFooter: View {
    let snap: UfiSnapshot
    let p: UfiPalette
    var detailed = false

    var body: some View {
        let signal = [("RSRP", snap.rsrp), ("RSRQ", snap.rsrq), ("SNR", snap.snr)]
            .filter { $0.1 != "--" }
            .map { "\($0.0) \($0.1)" }
            .joined(separator: " · ")
        let summary = detailed ? signal : (snap.netSummary == "--" ? "" : snap.netSummary)
        HStack(spacing: 4) {
            Image(systemName: snap.error == nil ? "cellularbars" : "exclamationmark.circle.fill")
                .foregroundStyle(snap.error == nil ? p.secondary : p.error)
                .accessibilityHidden(true)
            Text(snap.error ?? (summary.isEmpty ? "暂无蜂窝数据" : summary))
                .foregroundStyle(snap.error == nil ? p.secondary : p.error)
                .minimumScaleFactor(0.75)
            Spacer(minLength: 1)
            if detailed {
                Image(systemName: "clock")
                    .accessibilityHidden(true)
            }
            Text(detailed ? snap.updatedText : snap.updatedShort)
                .monospacedDigit()
                .fixedSize()
                .accessibilityLabel(Text("更新于 \(detailed ? snap.updatedText : snap.updatedShort)"))
        }
        .font(.system(size: 9.5, weight: .medium))
        .foregroundStyle(p.secondary)
        .lineLimit(1)
    }
}

struct MediumWidgetView: View {
    let snap: UfiSnapshot
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = UfiPalette(dark: scheme == .dark)
        let hasUnread = (snap.smsUnreadCount ?? 0) > 0
        VStack(alignment: .leading, spacing: 6) {
            WidgetHeader(snap: snap, p: p, detailed: true)
            HStack(spacing: 10) {
                TrafficValue(title: "今日流量", value: snap.dailyValue, unit: snap.dailyUnit, p: p)
                Rectangle().fill(p.divider).frame(width: 1, height: 32)
                TrafficValue(title: "本月流量", value: snap.monthlyValue, unit: snap.monthlyUnit, p: p)
            }
            HStack(spacing: 8) {
                WidgetMetric(icon: "network", label: "移动网络", value: shown(snap.netSummary), p: p, flexible: true)
                WidgetMetric(icon: "antenna.radiowaves.left.and.right", label: "频段", value: shown(snap.band), p: p)
                WidgetMetric(icon: "cpu", label: "CPU 占用", value: shown(snap.cpuUsage).map { $0 + "%" }, p: p)
                WidgetMetric(icon: "thermometer.medium", label: "CPU 温度", value: shown(snap.cpuTemp).map { $0 + "℃" }, p: p)
            }
            HStack(spacing: 8) {
                WidgetMetric(icon: "wifi", label: "Wi-Fi 名称", value: shown(snap.ssid), p: p, flexible: true)
                WidgetMetric(icon: "dot.radiowaves.left.and.right", label: "Wi-Fi 频率", value: shown(snap.wifiBand), p: p)
                WidgetMetric(icon: "memorychip", label: "内存占用", value: shown(snap.mem), p: p)
                WidgetMetric(
                    icon: "laptopcomputer.and.iphone", label: "连接设备",
                    value: snap.wifiDeviceCount.map { String($0) }, p: p
                )
                WidgetMetric(
                    icon: hasUnread ? "envelope.badge.fill" : "envelope", label: "未读短信",
                    value: snap.smsUnreadCount.map { String($0) }, p: p, alert: hasUnread
                )
            }
            WidgetFooter(snap: snap, p: p, detailed: true)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func shown(_ value: String) -> String? {
        value == "--" || value == "—" ? nil : value
    }
}

struct SmallWidgetView: View {
    let snap: UfiSnapshot
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = UfiPalette(dark: scheme == .dark)
        VStack(alignment: .leading, spacing: 4) {
            WidgetHeader(snap: snap, p: p)
            Spacer(minLength: 0)
            TrafficValue(title: "今日流量", value: snap.dailyValue, unit: snap.dailyUnit, p: p, numberSize: 32)
            HStack(spacing: 4) {
                Text("本月")
                    .foregroundStyle(p.secondary)
                Text("\(snap.monthlyValue) \(snap.monthlyUnit)")
                    .monospacedDigit()
                    .foregroundStyle(p.text)
            }
            .font(.system(size: 11, weight: .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            Spacer(minLength: 0)
            WidgetFooter(snap: snap, p: p)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LockRectView: View {
    let snap: UfiSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: "wifi.router.fill")
                Text(snap.model == "--" ? "UfiPeek" : snap.model)
                Spacer(minLength: 2)
                if snap.battery != "--" {
                    Image(systemName: snap.batteryIcon)
                    Text("\(snap.battery)%")
                        .fixedSize()
                }
            }
            .font(.system(size: 11, weight: .semibold))
            Text("今日 \(snap.dailyValue) \(snap.dailyUnit)")
                .font(.system(size: 15, weight: .bold))
            Text(snap.error ?? monthlySummary)
                .font(.system(size: 10, weight: .medium))
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }

    private var monthlySummary: String {
        let traffic = "本月 \(snap.monthlyValue) \(snap.monthlyUnit)"
        return snap.netSummary == "--" ? traffic : "\(traffic) · \(snap.netSummary)"
    }
}
