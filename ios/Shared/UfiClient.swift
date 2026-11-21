import Foundation
import CryptoKit

// MARK: - 配置

struct UfiConfig: Equatable {
    static let defaultURL = "http://192.168.88.1:2333"

    var url: String
    var password: String
    var ztePassword: String

    var isConfigured: Bool { !url.trimmed.isEmpty }

    /// 规范化后的后台地址：补 http://，去掉末尾斜杠
    var baseURL: String {
        var s = url.trimmed
        if !s.lowercased().hasPrefix("http://") && !s.lowercased().hasPrefix("https://") {
            s = "http://" + s
        }
        while s.hasSuffix("/") { s.removeLast() }
        return s
    }

    var ufiPassword: String { password.trimmed.isEmpty ? "admin" : password.trimmed }
    var ztePasswordEffective: String { ztePassword.trimmed.isEmpty ? ufiPassword : ztePassword.trimmed }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

// MARK: - 本地存储（App Group，自签名时若 App Group 失效则各自独立）

enum UfiStore {
    static let groupID = "group.com.ufipeek.widget"
    static var defaults: UserDefaults { UserDefaults(suiteName: groupID) ?? .standard }

    static func load() -> UfiConfig {
        let d = defaults
        let savedURL = d.string(forKey: "url")?.trimmed ?? ""
        return UfiConfig(url: savedURL.isEmpty ? UfiConfig.defaultURL : savedURL,
                         password: d.string(forKey: "password") ?? "",
                         ztePassword: d.string(forKey: "zte_password") ?? "")
    }

    static func save(_ c: UfiConfig) {
        let d = defaults
        d.set(c.url.trimmed, forKey: "url")
        d.set(c.password, forKey: "password")
        d.set(c.ztePassword, forKey: "zte_password")
    }

    static func saveSnapshot(_ s: UfiSnapshot) {
        if let data = try? JSONEncoder().encode(s) { defaults.set(data, forKey: "last_snapshot") }
    }

    static func lastSnapshot() -> UfiSnapshot? {
        guard let data = defaults.data(forKey: "last_snapshot") else { return nil }
        guard var snapshot = try? JSONDecoder().decode(UfiSnapshot.self, from: data) else { return nil }
        if snapshot.netSummary == "-- --" { snapshot.netSummary = "--" }
        switch snapshot.wifiBand {
        case "5G": snapshot.wifiBand = "5 GHz"
        case "2.4G": snapshot.wifiBand = "2.4 GHz"
        default: break
        }
        return snapshot
    }
}

// MARK: - 数据快照（小组件显示用）

struct UfiSnapshot: Codable {
    var model = "--"
    var ufiVersion = "--"
    var cpuTemp = "--"
    var cpuUsage = "--"
    var battery = "--"
    var batteryLevel: Double = -1
    var charging = false
    var netSummary = "--"
    var signalBar = "--"
    var rsrp = "--"
    var rsrq = "--"
    var snr = "--"
    var ssid = "--"
    // 旧缓存用 0 表示未知，新的可选字段只保存已确认的结果。
    var smsUnreadCount: Int?
    var wifiDeviceCount: Int?
    var dailyValue = "--"
    var dailyUnit = ""
    var monthlyValue = "--"
    var monthlyUnit = ""
    var band = "—"
    var wifiBand = "--"
    var mem = "--"
    var updatedAt = Date()
    var zreqOK = false
    var error: String?

    var hasData: Bool { model != "--" || dailyValue != "--" || battery != "--" }

    var missingNetworkData: [String] {
        var missing = [String]()
        if netSummary == "--" { missing.append("运营商／网络制式") }
        if signalBar == "--" || rsrp == "--" || rsrq == "--" || snr == "--" { missing.append("蜂窝信号") }
        if band == "—" { missing.append("频段") }
        if ssid == "--" { missing.append("Wi-Fi 名称") }
        if wifiDeviceCount == nil { missing.append("连接设备数") }
        if smsUnreadCount == nil { missing.append("未读短信数") }
        return missing
    }

    var batteryIcon: String {
        if charging { return "battery.100percent.bolt" }
        if batteryLevel <= 0 { return "battery.0percent" }
        if batteryLevel <= 25 { return "battery.25percent" }
        if batteryLevel <= 50 { return "battery.50percent" }
        if batteryLevel <= 75 { return "battery.75percent" }
        return "battery.100percent"
    }

    /// 与原 UfiPeek 脚本一致的电池配色
    var batteryColorHex: UInt32 {
        if charging { return 0x16A34A }
        if batteryLevel <= 0 { return 0xF59E0B }
        if batteryLevel <= 25 { return 0xDC2626 }
        if batteryLevel <= 50 { return 0x0056D6 }
        if batteryLevel <= 75 { return 0xF59E0B }
        return 0x16A34A
    }

    var signalFraction: Double {
        guard let n = Double(signalBar) else { return 0 }
        return max(0, min(1, n / 5))
    }

    var updatedText: String {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f.string(from: updatedAt)
    }

    var updatedShort: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: updatedAt)
    }

    static var placeholder: UfiSnapshot {
        var s = UfiSnapshot()
        s.model = "U30 Air"; s.ufiVersion = "4.1.0"; s.cpuTemp = "48.4"; s.cpuUsage = "4"
        s.battery = "90"; s.batteryLevel = 90; s.netSummary = "中国移动 5G"; s.signalBar = "5"
        s.rsrp = "-90dBm"; s.rsrq = "-6"; s.snr = "12"; s.ssid = "ZTE_E8CDF6"
        s.wifiDeviceCount = 2; s.smsUnreadCount = 0
        s.dailyValue = "9.88"; s.dailyUnit = "GB"; s.monthlyValue = "40.7"; s.monthlyUnit = "GB"
        s.band = "N41"; s.wifiBand = "5 GHz"; s.mem = "58%"
        return s
    }
}

// MARK: - 客户端

enum UfiError: LocalizedError {
    case badURL, http(Int), noData, login(String)
    var errorDescription: String? {
        switch self {
        case .badURL: return "后台地址格式不对"
        case .http(let c): return "HTTP \(c)"
        case .noData: return "没有返回数据"
        case .login(let m): return "ZTE 登录失败：\(m)"
        }
    }
}

struct UfiClient {
    let config: UfiConfig

    static let devicePath = "/api/baseDeviceInfo"
    static let shellPath = "/api/user_shell"
    static let rootShellPath = "/api/root_shell"
    static let goformGetPath = "/api/goform/goform_get_cmd_process"
    static let goformSetPath = "/api/goform/goform_set_cmd_process"
    static let zreqBin = "/data/data/com.minikano.f50_sms/files/zreq"
    static let secretKey = "minikano_kOyXz0Ciz4V7wR0IeKmJFYFQ20jd"

    static let fields = [
        "model_name", "network_provider", "network_type", "network_signalbar",
        "battery_value", "battery_vol_percent", "battery_charging", "ppp_status",
        "network_information", "Lte_ca_status", "loginfo", "Z5g_rsrp", "nr_rsrq", "Nr_snr",
        "lte_rsrp", "lte_rsrq", "lte_snr", "Nr_bands", "Lte_bands",
        "sms_unread_num", "SSID1", "RadioOff", "station_list",
        "LD", "RD", "modem_main_state", "pin_status", "sim_pin_status",
    ]

    private static let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.timeoutIntervalForRequest = 12
        c.timeoutIntervalForResource = 25
        c.requestCachePolicy = .reloadIgnoringLocalCacheData
        c.waitsForConnectivity = false
        return URLSession(configuration: c)
    }()

    // MARK: 签名（与 UFI-TOOLS 前端一致）

    static func hex<S: Sequence>(_ bytes: S) -> String where S.Element == UInt8 {
        bytes.map { String(format: "%02x", $0) }.joined()
    }

    static func sha256Hex(_ s: String) -> String { hex(SHA256.hash(data: Data(s.utf8))) }

    static func kanoSign(method: String, path: String, timestamp: String) -> String {
        let raw = "minikano" + method.uppercased() + path + timestamp
        let mac = HMAC<Insecure.MD5>.authenticationCode(for: Data(raw.utf8),
                                                        using: SymmetricKey(data: Data(secretKey.utf8)))
        let bytes = Array(mac)
        let mid = bytes.count / 2
        let a = Array(SHA256.hash(data: Data(bytes[0..<mid])))
        let b = Array(SHA256.hash(data: Data(bytes[mid...])))
        return hex(SHA256.hash(data: Data(a + b)))
    }

    private func headers(method: String, path: String) -> [String: String] {
        let t = String(Int64(Date().timeIntervalSince1970 * 1000))
        return [
            "Authorization": Self.sha256Hex(config.ufiPassword),
            "kano-t": t,
            "kano-sign": Self.kanoSign(method: method, path: path, timestamp: t),
        ]
    }

    private var nowMs: String { String(Int64(Date().timeIntervalSince1970 * 1000)) }

    // MARK: 请求

    private func send(_ method: String, path: String, query: String? = nil, body: Data? = nil,
                      contentType: String? = nil, timeout: TimeInterval = 12) async throws -> Data {
        var s = config.baseURL + path
        if let q = query { s += "?" + q }
        guard let url = URL(string: s) else { throw UfiError.badURL }
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        req.httpMethod = method
        for (k, v) in headers(method: method, path: path) { req.setValue(v, forHTTPHeaderField: k) }
        if let ct = contentType { req.setValue(ct, forHTTPHeaderField: "Content-Type") }
        req.httpBody = body
        let (data, resp) = try await Self.session.data(for: req)
        if let h = resp as? HTTPURLResponse, !(200..<300).contains(h.statusCode) { throw UfiError.http(h.statusCode) }
        return data
    }

    private static func jsonDict(_ data: Data) -> [String: Any] {
        ((try? JSONSerialization.jsonObject(with: data)) as? [String: Any]) ?? [:]
    }

    private func postShell(_ command: String, path: String) async throws -> Any? {
        let body = try JSONSerialization.data(withJSONObject: ["command": command])
        let data = try await send("POST", path: path, body: body, contentType: "application/json", timeout: 15)
        return Self.jsonDict(data)["result"]
    }

    private static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Step 2：通过 user_shell 调设备本机 zreq，自动完成 ZTE 登录并取 goform 数据
    private func zreqBasic() async throws -> [String: Any] {
        let params = "cmd=" + Self.fields.joined(separator: ",") + "&multi_data=1&isTest=false"
        let cmd = Self.zreqBin + " -pwd " + Self.shellQuote(config.ztePasswordEffective)
            + " -method GET -params " + Self.shellQuote(params) + " -json"
        guard let r = try await postShell(cmd, path: Self.shellPath) as? [String: Any] else { throw UfiError.noData }
        let done = (r["done"] as? Bool) ?? false
        guard done else { throw UfiError.noData }
        if let dict = r["content"] as? [String: Any], !dict.isEmpty { return dict }
        guard let c = r["content"] as? String, let d = c.data(using: .utf8) else { throw UfiError.noData }
        let dict = Self.jsonDict(d)
        if dict.isEmpty { throw UfiError.noData }
        return dict
    }

    /// Step 2b：直接 GET goform
    private func goformGet() async throws -> [String: Any] {
        let q = "multi_data=1&isTest=false&cmd=" + Self.fields.joined(separator: ",") + "&_=" + nowMs
        let data = try await send("GET", path: Self.goformGetPath, query: q)
        return Self.jsonDict(data)
    }

    /// 回退：POST 登录 ZTE 后台
    private func loginZTE() async throws {
        let ldData = try await send("GET", path: Self.goformGetPath, query: "multi_data=1&isTest=false&cmd=LD&_=" + nowMs)
        let ldResp = Self.jsonDict(ldData)
        guard let ld = Self.str(ldResp["LD"]) else { throw UfiError.login("no LD") }
        let pwdHash = Self.sha256Hex(config.ztePasswordEffective).uppercased()
        let loginHash = Self.sha256Hex(pwdHash + ld).uppercased()
        let body = "goformId=LOGIN&isTest=false&user=admin&password=" + loginHash
        let loginData = try await send("POST", path: Self.goformSetPath, body: Data(body.utf8),
                                       contentType: "application/x-www-form-urlencoded; charset=UTF-8")
        let raw = String(data: loginData, encoding: .utf8) ?? ""
        if raw.contains("\"result\":0") || raw.contains("\"result\":\"0\"") { return }
        let vData = try await send("GET", path: Self.goformGetPath, query: "multi_data=1&isTest=false&cmd=loginfo&_=" + nowMs)
        let v = Self.jsonDict(vData)
        if Self.str(v["loginfo"]) == "ok" { return }
        throw UfiError.login("loginfo=\(Self.str(v["loginfo"]) ?? "?")")
    }

    /// Step 3：root_shell 读 WiFi 频率和内存
    private func rootInfo() async -> (freq: Int, memTotal: Int, memAvail: Int) {
        let cmd = "dumpsys wifi 2>/dev/null | grep -o 'frequency= [0-9]*' | head -1; grep -E 'MemTotal|MemAvailable' /proc/meminfo"
        guard let r = try? await postShell(cmd, path: Self.rootShellPath) else { return (0, 0, 0) }
        var s = ""
        if let str = r as? String { s = str }
        else if let d = r as? [String: Any] { s = (d["content"] as? String) ?? "\(d)" }
        else { s = "\(r)" }
        return (Self.firstInt(#"frequency=\s*(\d+)"#, in: s) ?? 0,
                Self.firstInt(#"MemTotal:\s*(\d+)"#, in: s) ?? 0,
                Self.firstInt(#"MemAvailable:\s*(\d+)"#, in: s) ?? 0)
    }

    private func deviceInfo() async -> [String: Any] {
        (try? await send("GET", path: Self.devicePath)).map { Self.jsonDict($0) } ?? [:]
    }

    private func zreqBasicSafe() async -> [String: Any] {
        (try? await zreqBasic()) ?? [:]
    }

    // MARK: 主流程

    func fetch() async -> UfiSnapshot {
        guard config.isConfigured else {
            var s = UfiSnapshot()
            s.error = "未设置后台地址"
            return s
        }
        async let devTask = deviceInfo()
        async let zreqTask = zreqBasicSafe()
        async let rootTask = rootInfo()

        let d = await devTask
        var g = await zreqTask
        let zreqOK = !g.isEmpty
        if !zreqOK {
            g = (try? await goformGet()) ?? [:]
            if Self.str(g["loginfo"]) == "no" {
                if (try? await loginZTE()) != nil {
                    g = (try? await goformGet()) ?? g
                }
            }
        }
        let r = await rootTask
        var snap = Self.build(d: d, g: g, freq: r.freq, memTotal: r.memTotal, memAvail: r.memAvail)
        snap.zreqOK = zreqOK
        if d.isEmpty && g.isEmpty { snap.error = "连接失败，请检查地址和密码" }
        return snap
    }

    // MARK: 数据整理（对应原脚本 bindStableData）

    static func build(d: [String: Any], g: [String: Any], freq: Int, memTotal: Int, memAvail: Int) -> UfiSnapshot {
        var s = UfiSnapshot()
        s.model = pick(d["model"], g["model_name"])

        let app = str(d["app_ver"]), code = str(d["app_ver_code"])
        if let a = app, let c = code { s.ufiVersion = a + "." + c }
        else { s.ufiVersion = app ?? code ?? "--" }

        var temp = normalizeTemp(d["cpu_temp"])
        if temp == nil, let list = d["cpu_temp_list"] as? [[String: Any]] {
            temp = list.compactMap { num($0["temp"]) }.filter { $0 > 0 }.max().map { $0 > 1000 ? $0 / 1000 : $0 }
        }
        s.cpuTemp = temp.map { roundText($0, 1) } ?? "--"
        s.cpuUsage = num(d["cpu_usage"]).map { roundText($0, 0) } ?? "--"

        s.battery = pick(d["battery"], g["battery_value"], g["battery_vol_percent"])
        s.batteryLevel = num(s.battery) ?? -1
        s.charging = str(g["battery_charging"]) == "1"

        let provider = pick(g["network_provider"])
        let netType = normNetType(str(g["network_type"]))
        let network = [provider, netType].filter { $0 != "--" }.joined(separator: " ")
        s.netSummary = network.isEmpty ? "--" : network
        s.signalBar = pick(g["network_signalbar"])

        if let rsrp = num(g["Z5g_rsrp"]) ?? num(g["lte_rsrp"]) { s.rsrp = roundText(rsrp, 0) + "dBm" }
        s.rsrq = pick(g["nr_rsrq"], g["lte_rsrq"])
        s.snr = pick(g["Nr_snr"], g["lte_snr"])

        s.ssid = pick(g["SSID1"])
        if let unread = Int(str(g["sms_unread_num"]) ?? ""), unread >= 0 {
            s.smsUnreadCount = unread
        }

        let daily = splitBytes(formatBytes(d["daily_data"]))
        s.dailyValue = daily.0; s.dailyUnit = daily.1
        let monthly = splitBytes(formatBytes(d["monthly_data"]))
        s.monthlyValue = monthly.0; s.monthlyUnit = monthly.1

        var sta: Any? = g["station_list"]
        if let str = sta as? String, !str.trimmed.isEmpty, let data = str.data(using: .utf8) {
            sta = try? JSONSerialization.jsonObject(with: data)
        }
        if let arr = sta as? [Any] { s.wifiDeviceCount = arr.count }
        else if let dict = sta as? [String: Any] { s.wifiDeviceCount = dict.count }

        let nr = str(g["Nr_bands"]) ?? "", lte = str(g["Lte_bands"]) ?? ""
        if isDigits(nr) { s.band = "N" + nr }
        else if isDigits(lte) { s.band = "B" + lte }

        if freq >= 4000 { s.wifiBand = "5 GHz" }
        else if freq > 0 { s.wifiBand = "2.4 GHz" }
        if memTotal > 0 && memAvail >= 0 {
            s.mem = String(Int((Double(memTotal - memAvail) / Double(memTotal) * 100).rounded())) + "%"
        }
        s.updatedAt = Date()
        return s
    }

    // MARK: 工具函数

    static func str(_ v: Any?) -> String? {
        guard let v = v, !(v is NSNull) else { return nil }
        var s: String
        if let x = v as? String { s = x }
        else if let n = v as? NSNumber { s = n.stringValue }
        else { s = "\(v)" }
        s = s.trimmed
        return (s.isEmpty || s == "--") ? nil : s
    }

    static func pick(_ vs: Any?...) -> String {
        for v in vs { if let s = str(v) { return s } }
        return "--"
    }

    static func num(_ v: Any?) -> Double? {
        guard let s = str(v) else { return nil }
        let cleaned = s.filter { "0123456789.-".contains($0) }
        guard let d = Double(cleaned), d.isFinite else { return nil }
        return d
    }

    static func normalizeTemp(_ v: Any?) -> Double? {
        guard let n = num(v) else { return nil }
        return n > 1000 ? n / 1000 : n
    }

    static func roundText(_ n: Double, _ digits: Int) -> String {
        let s = String(format: "%.\(digits)f", n)
        return s.replacingOccurrences(of: #"\.0+$"#, with: "", options: .regularExpression)
    }

    static func normNetType(_ v: String?) -> String {
        let s = v ?? "--"
        switch s {
        case "20", "5G", "LTE-NSA", "SA", "ENDC": return "5G"
        case "13", "LTE": return "4G"
        case "2", "WCDMA", "3G": return "3G"
        case "1", "GSM", "2G": return "2G"
        default: return s
        }
    }

    static func formatBytes(_ v: Any?) -> String {
        guard let n = num(v), n > 0 else { return "--" }
        let gb = n / 1_073_741_824
        if gb >= 1 {
            var s = String(format: gb >= 10 ? "%.1f" : "%.2f", gb)
            if s.hasSuffix(".0") { s.removeLast(2) }
            return s + "GB"
        }
        let mb = n / 1_048_576
        var s = String(format: mb >= 10 ? "%.0f" : "%.1f", mb)
        if s.hasSuffix(".0") { s.removeLast(2) }
        return s + "MB"
    }

    static func splitBytes(_ s: String) -> (String, String) {
        if s == "--" || s.isEmpty { return ("--", "") }
        if s.hasSuffix("GB") || s.hasSuffix("MB") { return (String(s.dropLast(2)), String(s.suffix(2))) }
        return (s, "")
    }

    static func isDigits(_ s: String) -> Bool { !s.isEmpty && s.allSatisfy { $0.isASCII && $0.isNumber } }

    static func firstInt(_ pattern: String, in s: String) -> Int? {
        guard let re = try? NSRegularExpression(pattern: pattern),
              let m = re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              m.numberOfRanges > 1,
              let r = Range(m.range(at: 1), in: s) else { return nil }
        return Int(s[r])
    }
}
