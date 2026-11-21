import SwiftUI

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

    var text: Color { color(0x122C33, 0xF1F8F8) }
    var secondary: Color { color(0x49636A, 0xADC2C7) }
    var accent: Color { color(0x00685A, 0x74E4C6) }
    var onAccent: Color { color(0xFFFFFF, 0x112F2B) }
    var screen: Color { color(0xEEF5F4, 0x101C21) }
    var surface: Color { color(0xFFFFFF, 0x192C32) }
    var field: Color { color(0xF5F9F8, 0x131F24) }
    var divider: Color { color(0xD1E4E0, 0x314A50) }
    var daily: Color { color(0xD6F0E8, 0x1F403D) }
    var monthly: Color { color(0xF5FAFB, 0x23353E) }
    var chip: Color { color(0xFFFFFF, 0x21353B) }
    var success: Color { color(0x087263, 0x8EDBCD) }
    var error: Color { color(0xB23130, 0xFFB4AB) }
    var cpu: Color { color(0x215BB0, 0x9ABCF8) }
    var temperature: Color { color(0xAD392B, 0xFFB4A6) }
    var memory: Color { color(0x6443B5, 0xC9B4FF) }
    var devices: Color { color(0x6F468F, 0xDFB5FA) }

    var widgetBackground: LinearGradient {
        LinearGradient(
            colors: [color(0xF8FCFB, 0x14262B), color(0xEAF4F3, 0x111E24)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func color(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(hex: self.dark ? dark : light)
    }
}

private struct TrafficTile: View {
    let title: String
    let value: String
    let unit: String
    let p: UfiPalette
    var primary = false
    var numberSize: CGFloat = 24

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(primary ? p.accent : p.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: numberSize, weight: .bold))
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
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(primary ? p.daily : p.monthly, in: RoundedRectangle(cornerRadius: 11))
        .accessibilityElement(children: .combine)
    }
}

private struct UfiChip: View {
    let icon: String
    let label: String
    let value: String
    let tint: Color
    let p: UfiPalette
    var flexible = false

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(value)
                .foregroundStyle(p.text)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .font(.system(size: 10, weight: .medium))
        .frame(maxWidth: flexible ? .infinity : nil, alignment: .leading)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(p.chip, in: RoundedRectangle(cornerRadius: 6))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(value))
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
                .accessibilityHidden(true)
            Text(snap.model)
                .fontWeight(.bold)
                .foregroundStyle(p.text)
                .layoutPriority(1)
            if detailed {
                Text("UFI v\(snap.ufiVersion)")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(p.secondary)
            }
            Spacer(minLength: 2)
            if detailed {
                HStack(spacing: 3) {
                    Image(systemName: "cellularbars", variableValue: snap.signalFraction)
                        .foregroundStyle(p.accent)
                    Text(snap.signalBar)
                }
                .fixedSize()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("信号 \(snap.signalBar) 格"))
            }
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
        .font(.system(size: 11, weight: .medium))
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
        let signal = snap.hasSignalDetails
            ? "RSRP \(snap.rsrp) · RSRQ \(snap.rsrq) · SNR \(snap.snr)"
            : "蜂窝信号数据未返回"
        let summary = detailed ? signal : snap.netSummary
        HStack(spacing: 4) {
            Image(systemName: snap.error == nil ? "cellularbars" : "exclamationmark.circle.fill")
                .foregroundStyle(snap.error == nil ? p.accent : p.error)
                .accessibilityHidden(true)
            Text(snap.error ?? summary)
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
        VStack(spacing: 4) {
            WidgetHeader(snap: snap, p: p, detailed: true)
            HStack(spacing: 5) {
                TrafficTile(title: "今日流量", value: snap.dailyValue, unit: snap.dailyUnit, p: p, primary: true)
                TrafficTile(title: "本月流量", value: snap.monthlyValue, unit: snap.monthlyUnit, p: p)
            }
            HStack(spacing: 4) {
                UfiChip(icon: "network", label: "移动网络", value: snap.netSummary, tint: p.accent, p: p, flexible: true)
                UfiChip(icon: "antenna.radiowaves.left.and.right", label: "频段", value: snap.band, tint: p.accent, p: p)
                UfiChip(icon: "cpu", label: "CPU 占用", value: snap.cpuUsage + "%", tint: p.cpu, p: p)
                UfiChip(icon: "thermometer.medium", label: "CPU 温度", value: snap.cpuTemp + "℃", tint: p.temperature, p: p)
            }
            HStack(spacing: 4) {
                UfiChip(icon: "wifi", label: "WiFi 名称", value: snap.ssid, tint: p.accent, p: p, flexible: true)
                UfiChip(icon: "dot.radiowaves.left.and.right", label: "WiFi 频率", value: snap.wifiBand, tint: p.accent, p: p)
                UfiChip(icon: "memorychip", label: "内存占用", value: snap.mem, tint: p.memory, p: p)
                UfiChip(
                    icon: "laptopcomputer.and.iphone", label: "连接设备",
                    value: snap.wifiDeviceCount.map { String($0) } ?? "--", tint: p.devices, p: p
                )
                UfiChip(
                    icon: hasUnread ? "envelope.badge.fill" : "envelope", label: "未读短信",
                    value: snap.smsUnreadCount.map { String($0) } ?? "--", tint: hasUnread ? p.error : p.accent, p: p
                )
            }
            WidgetFooter(snap: snap, p: p, detailed: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            TrafficTile(title: "今日流量", value: snap.dailyValue, unit: snap.dailyUnit, p: p, primary: true, numberSize: 29)
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
            .padding(.horizontal, 3)
            Spacer(minLength: 0)
            WidgetFooter(snap: snap, p: p)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LockRectView: View {
    let snap: UfiSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: "wifi.router.fill")
                Text(snap.model)
                Spacer(minLength: 2)
                Image(systemName: snap.batteryIcon)
                Text("\(snap.battery)%")
                    .fixedSize()
            }
            .font(.system(size: 11, weight: .semibold))
            Text("今日 \(snap.dailyValue) \(snap.dailyUnit)")
                .font(.system(size: 15, weight: .bold))
            Text("本月 \(snap.monthlyValue) \(snap.monthlyUnit) · \(snap.netSummary)")
                .font(.system(size: 10, weight: .medium))
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }
}
