import SwiftUI

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

struct UfiPalette {
    let dark: Bool
    var bg: Color { dark ? Color(hex: 0x1A1A2E) : .white }
    var text: Color { dark ? Color(hex: 0xEBEBEB) : .black }
    var secondary: Color { dark ? Color(hex: 0xF1F5F9) : Color(hex: 0x172033) }
    var accent: Color { dark ? Color(hex: 0x4D8DFF) : Color(hex: 0x0056D6) }
    var chip: Color { dark ? Color.white.opacity(0.08) : Color(hex: 0xF1F4F8) }
    var divider: Color { dark ? Color.white.opacity(0.18) : Color(hex: 0xD7DEE8) }
    var router: Color { dark ? Color(hex: 0xD6D6D6) : Color(hex: 0x011D57) }
    var signal: Color { dark ? Color(hex: 0x3A87FE) : Color(hex: 0x0042A9) }
    var clock: Color { dark ? Color(hex: 0x96D35F) : Color(hex: 0x4E7A27) }
}

private func rounded(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
    .system(size: size, weight: weight, design: .rounded)
}

struct UfiChip: View {
    let icon: String
    let iconColor: Color
    let text: String
    let p: UfiPalette

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(iconColor)
            Text(text)
                .font(rounded(10.5))
                .foregroundStyle(p.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2.5)
        .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(p.chip))
    }
}

// MARK: - 中号：完整复刻 UfiPeek 布局

struct MediumWidgetView: View {
    let snap: UfiSnapshot
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = UfiPalette(dark: scheme == .dark)
        VStack(spacing: 4) {
            topBar(p)
            HStack(spacing: 0) {
                traffic("今日流量", snap.dailyValue, snap.dailyUnit, p).frame(maxWidth: .infinity)
                Rectangle().fill(p.divider).frame(width: 1, height: 32)
                traffic("本月流量", snap.monthlyValue, snap.monthlyUnit, p).frame(maxWidth: .infinity)
            }
            HStack(spacing: 4) {
                UfiChip(icon: "network", iconColor: Color(hex: 0x0891B2), text: snap.netSummary, p: p)
                UfiChip(icon: "antenna.radiowaves.left.and.right", iconColor: p.accent, text: snap.band, p: p)
                UfiChip(icon: "cpu.fill", iconColor: Color(hex: 0x2563EB), text: snap.cpuUsage + "%", p: p)
                UfiChip(icon: "thermometer.medium", iconColor: Color(hex: 0xEF4444), text: snap.cpuTemp + "℃", p: p)
            }
            HStack(spacing: 4) {
                UfiChip(icon: "wifi", iconColor: Color(hex: 0x0F766E), text: snap.ssid, p: p)
                    .layoutPriority(-1)
                UfiChip(icon: "dot.radiowaves.left.and.right", iconColor: Color(hex: 0x0F766E), text: snap.wifiBand, p: p)
                UfiChip(icon: "memorychip", iconColor: Color(hex: 0x7C3AED), text: snap.mem, p: p)
                UfiChip(icon: "laptopcomputer.and.iphone", iconColor: Color(hex: 0x7A219E), text: snap.wifiDevices, p: p)
                UfiChip(icon: snap.smsUnread > 0 ? "envelope.badge.fill" : "envelope",
                        iconColor: snap.smsUnread > 0 ? Color(hex: 0xDC2626) : p.accent,
                        text: String(snap.smsUnread), p: p)
            }
            bottomBar(p)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }

    private func topBar(_ p: UfiPalette) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "wifi.router.fill")
                .font(.system(size: 11))
                .foregroundStyle(p.router)
            Text(snap.model)
                .font(rounded(12, .bold))
                .foregroundStyle(p.text)
                .lineLimit(1)
            Text("UFI v\(snap.ufiVersion)")
                .font(rounded(9.5, .medium))
                .foregroundStyle(p.text.opacity(0.75))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer(minLength: 2)
            Image(systemName: "cellularbars", variableValue: snap.signalFraction)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(p.text)
            Text(snap.signalBar)
                .font(rounded(11, .bold))
                .foregroundStyle(p.text)
            Text("|")
                .font(rounded(10))
                .foregroundStyle(p.divider)
            Image(systemName: snap.batteryIcon)
                .font(.system(size: 13))
                .foregroundStyle(Color(hex: snap.batteryColorHex))
            Text("\(snap.battery)%")
                .font(rounded(11, .bold))
                .foregroundStyle(p.text)
        }
    }

    private func traffic(_ title: String, _ value: String, _ unit: String, _ p: UfiPalette) -> some View {
        VStack(spacing: 0) {
            Text(title)
                .font(rounded(10.5, .bold))
                .foregroundStyle(p.accent)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(rounded(28, .heavy))
                    .foregroundStyle(p.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(unit)
                    .font(.system(size: 12, weight: .bold, design: .serif))
                    .italic()
                    .foregroundStyle(p.text)
            }
        }
    }

    private func bottomBar(_ p: UfiPalette) -> some View {
        HStack(spacing: 6) {
            if let err = snap.error {
                HStack(spacing: 3) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color(hex: 0xDC2626))
                    Text(err)
                        .foregroundStyle(Color(hex: 0xDC2626))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            } else {
                HStack(spacing: 3) {
                    Image(systemName: "antenna.radiowaves.left.and.right.circle")
                        .foregroundStyle(p.signal)
                    Text("RSRP \(snap.rsrp) · RSRQ \(snap.rsrq) · SNR \(snap.snr)")
                        .foregroundStyle(p.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            HStack(spacing: 3) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(p.clock)
                Text(snap.updatedText)
                    .foregroundStyle(p.text)
                    .lineLimit(1)
            }
        }
        .font(rounded(9.5, .medium))
    }
}

// MARK: - 小号：流量 + 电量 + 网络

struct SmallWidgetView: View {
    let snap: UfiSnapshot
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let p = UfiPalette(dark: scheme == .dark)
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: "wifi.router.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(p.router)
                Text(snap.model)
                    .font(rounded(11, .bold))
                    .foregroundStyle(p.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 2)
                Image(systemName: snap.batteryIcon)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: snap.batteryColorHex))
                Text("\(snap.battery)%")
                    .font(rounded(10, .bold))
                    .foregroundStyle(p.text)
            }
            Spacer(minLength: 0)
            Text("今日流量")
                .font(rounded(10.5, .bold))
                .foregroundStyle(p.accent)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(snap.dailyValue)
                    .font(rounded(32, .heavy))
                    .foregroundStyle(p.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text(snap.dailyUnit)
                    .font(.system(size: 13, weight: .bold, design: .serif))
                    .italic()
                    .foregroundStyle(p.text)
            }
            HStack(spacing: 3) {
                Text("本月")
                    .font(rounded(10.5, .bold))
                    .foregroundStyle(p.accent)
                Text(snap.monthlyValue + snap.monthlyUnit)
                    .font(rounded(12, .bold))
                    .foregroundStyle(p.text)
            }
            Spacer(minLength: 0)
            HStack(spacing: 3) {
                Image(systemName: "cellularbars", variableValue: snap.signalFraction)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(p.text)
                Text(snap.error == nil ? snap.netSummary : "连接失败")
                    .foregroundStyle(snap.error == nil ? p.secondary : Color(hex: 0xDC2626))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 2)
                Text(snap.updatedShort)
                    .foregroundStyle(p.secondary.opacity(0.7))
            }
            .font(rounded(9.5, .medium))
        }
        .padding(12)
    }
}

// MARK: - 锁屏矩形

struct LockRectView: View {
    let snap: UfiSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 3) {
                Image(systemName: "wifi.router.fill")
                Text(snap.model).lineLimit(1)
                Spacer(minLength: 2)
                Image(systemName: snap.batteryIcon)
                Text("\(snap.battery)%")
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            Text("今日 \(snap.dailyValue)\(snap.dailyUnit)")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("本月 \(snap.monthlyValue)\(snap.monthlyUnit) · \(snap.netSummary)")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}
