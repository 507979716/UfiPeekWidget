package com.ufipeek.widget

import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.security.MessageDigest
import java.util.Locale
import java.util.concurrent.Callable
import java.util.concurrent.Executors
import java.util.concurrent.Future
import java.util.concurrent.TimeUnit
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec
import kotlin.math.roundToInt

data class UfiConfig(val url: String, val password: String, val ztePassword: String) {
    val isConfigured: Boolean get() = url.isNotBlank()

    val baseUrl: String
        get() {
            var s = url.trim()
            if (!s.startsWith("http://", true) && !s.startsWith("https://", true)) s = "http://$s"
            return s.trimEnd('/')
        }

    val ufiPassword: String get() = password.trim().ifEmpty { "admin" }
    val ztePasswordEffective: String get() = ztePassword.trim().ifEmpty { ufiPassword }
}

/** 与 UfiPeek v3.0 脚本相同的取数流程 */
class UfiClient(private val cfg: UfiConfig) {

    companion object {
        const val DEVICE_PATH = "/api/baseDeviceInfo"
        const val SHELL_PATH = "/api/user_shell"
        const val ROOT_SHELL_PATH = "/api/root_shell"
        const val GOFORM_GET_PATH = "/api/goform/goform_get_cmd_process"
        const val GOFORM_SET_PATH = "/api/goform/goform_set_cmd_process"
        const val ZREQ_BIN = "/data/data/com.minikano.f50_sms/files/zreq"
        private const val SECRET = "minikano_kOyXz0Ciz4V7wR0IeKmJFYFQ20jd"

        val FIELDS = listOf(
            "model_name", "network_provider", "network_type", "network_signalbar",
            "battery_value", "battery_vol_percent", "battery_charging", "ppp_status",
            "network_information", "Lte_ca_status", "loginfo", "Z5g_rsrp", "nr_rsrq", "Nr_snr",
            "lte_rsrp", "lte_rsrq", "lte_snr", "Nr_bands", "Lte_bands",
            "sms_unread_num", "SSID1", "RadioOff", "station_list",
            "LD", "RD", "modem_main_state", "pin_status", "sim_pin_status"
        )

        fun hex(b: ByteArray): String {
            val sb = StringBuilder(b.size * 2)
            for (x in b) {
                val v = x.toInt() and 0xff
                sb.append("0123456789abcdef"[v shr 4]).append("0123456789abcdef"[v and 0xf])
            }
            return sb.toString()
        }

        fun sha256(b: ByteArray): ByteArray = MessageDigest.getInstance("SHA-256").digest(b)

        fun sha256Hex(s: String): String = hex(sha256(s.toByteArray(Charsets.UTF_8)))

        fun kanoSign(method: String, path: String, timestamp: String): String {
            val mac = Mac.getInstance("HmacMD5")
            mac.init(SecretKeySpec(SECRET.toByteArray(Charsets.UTF_8), "HmacMD5"))
            val h = mac.doFinal(("minikano" + method.uppercase(Locale.ROOT) + path + timestamp).toByteArray(Charsets.UTF_8))
            val mid = h.size / 2
            val a = sha256(h.copyOfRange(0, mid))
            val b = sha256(h.copyOfRange(mid, h.size))
            return hex(sha256(a + b))
        }

        // ---------- 工具函数 ----------

        fun str(v: Any?): String? {
            if (v == null || v == JSONObject.NULL) return null
            val s = v.toString().trim()
            return if (s.isEmpty() || s == "--" || s == "null") null else s
        }

        fun pick(vararg vs: Any?): String {
            for (v in vs) str(v)?.let { return it }
            return "--"
        }

        fun num(v: Any?): Double? {
            val s = str(v) ?: return null
            val cleaned = s.filter { it in "0123456789.-" }
            val d = cleaned.toDoubleOrNull() ?: return null
            return if (d.isFinite()) d else null
        }

        fun roundText(n: Double, digits: Int): String =
            String.format(Locale.US, "%.${digits}f", n).replace(Regex("\\.0+$"), "")

        fun normalizeTemp(n: Double?): Double? = n?.let { if (it > 1000) it / 1000 else it }

        fun normNetType(v: String?): String = when (v ?: "--") {
            "20", "5G", "LTE-NSA", "SA", "ENDC" -> "5G"
            "13", "LTE" -> "4G"
            "2", "WCDMA", "3G" -> "3G"
            "1", "GSM", "2G" -> "2G"
            else -> v ?: "--"
        }

        fun formatBytes(v: Any?): String {
            val n = num(v) ?: return "--"
            if (n <= 0) return "--"
            val gb = n / 1073741824.0
            if (gb >= 1) {
                var s = String.format(Locale.US, if (gb >= 10) "%.1f" else "%.2f", gb)
                if (s.endsWith(".0")) s = s.dropLast(2)
                return s + "GB"
            }
            val mb = n / 1048576.0
            var s = String.format(Locale.US, if (mb >= 10) "%.0f" else "%.1f", mb)
            if (s.endsWith(".0")) s = s.dropLast(2)
            return s + "MB"
        }

        fun splitBytes(s: String): Pair<String, String> {
            if (s == "--" || s.isEmpty()) return "--" to ""
            if (s.endsWith("GB") || s.endsWith("MB")) return s.dropLast(2) to s.takeLast(2)
            return s to ""
        }

        private fun isDigits(s: String) = s.isNotEmpty() && s.all { it in '0'..'9' }

        private fun firstInt(pattern: String, s: String): Int? =
            Regex(pattern).find(s)?.groupValues?.getOrNull(1)?.toIntOrNull()

        private fun shellQuote(s: String) = "'" + s.replace("'", "'\\''") + "'"

        private fun parseObj(text: String?): JSONObject =
            try { if (text.isNullOrBlank()) JSONObject() else JSONObject(text) } catch (e: Exception) { JSONObject() }

        fun build(d: JSONObject, g: JSONObject, freq: Int, memTotal: Int, memAvail: Int): UfiSnapshot {
            val s = UfiSnapshot()
            s.model = pick(d.opt("model"), g.opt("model_name"))

            val app = str(d.opt("app_ver"))
            val code = str(d.opt("app_ver_code"))
            s.ufiVersion = if (app != null && code != null) "$app.$code" else app ?: code ?: "--"

            var temp = normalizeTemp(num(d.opt("cpu_temp")))
            if (temp == null) {
                val list = d.optJSONArray("cpu_temp_list")
                if (list != null) {
                    var m: Double? = null
                    for (i in 0 until list.length()) {
                        val t = num(list.optJSONObject(i)?.opt("temp")) ?: continue
                        if (t > 0 && (m == null || t > m)) m = t
                    }
                    temp = normalizeTemp(m)
                }
            }
            s.cpuTemp = temp?.let { roundText(it, 1) } ?: "--"
            s.cpuUsage = num(d.opt("cpu_usage"))?.let { roundText(it, 0) } ?: "--"

            s.battery = pick(d.opt("battery"), g.opt("battery_value"), g.opt("battery_vol_percent"))
            s.batteryLevel = num(s.battery) ?: -1.0
            s.charging = str(g.opt("battery_charging")) == "1"

            val provider = pick(g.opt("network_provider"))
            val netType = normNetType(str(g.opt("network_type")))
            s.netSummary = if (provider == "--" && netType == "--") "-- --" else "$provider $netType"
            s.signalBar = pick(g.opt("network_signalbar"))

            num(str(g.opt("Z5g_rsrp")) ?: str(g.opt("lte_rsrp")))?.let { s.rsrp = roundText(it, 0) + "dBm" }
            s.rsrq = pick(g.opt("nr_rsrq"), g.opt("lte_rsrq"))
            s.snr = pick(g.opt("Nr_snr"), g.opt("lte_snr"))

            s.ssid = pick(g.opt("SSID1"))
            s.smsUnread = str(g.opt("sms_unread_num"))?.toIntOrNull() ?: 0

            val daily = splitBytes(formatBytes(d.opt("daily_data")))
            s.dailyValue = daily.first; s.dailyUnit = daily.second
            val monthly = splitBytes(formatBytes(d.opt("monthly_data")))
            s.monthlyValue = monthly.first; s.monthlyUnit = monthly.second

            val rawSta: Any? = g.opt("station_list")
            val sta: Any? = if (rawSta is String) {
                val t = rawSta.trim()
                try {
                    when {
                        t.startsWith("[") -> JSONArray(t)
                        t.startsWith("{") -> JSONObject(t)
                        else -> null
                    }
                } catch (e: Exception) { null }
            } else rawSta
            val count = when (sta) {
                is JSONArray -> sta.length()
                is JSONObject -> sta.length()
                else -> 0
            }
            s.wifiDevices = count.toString()

            val nr = str(g.opt("Nr_bands")) ?: ""
            val lte = str(g.opt("Lte_bands")) ?: ""
            s.band = when {
                isDigits(nr) -> "N$nr"
                isDigits(lte) -> "B$lte"
                else -> "—"
            }

            s.wifiBand = if (freq > 0) (if (freq >= 4000) "5G" else "2.4G") else "--"
            if (memTotal > 0 && memAvail >= 0) {
                s.mem = ((memTotal - memAvail).toDouble() / memTotal * 100).roundToInt().toString() + "%"
            }
            s.updatedAt = System.currentTimeMillis()
            return s
        }
    }

    private fun nowMs() = System.currentTimeMillis().toString()

    private fun headers(method: String, path: String): Map<String, String> {
        val t = nowMs()
        return mapOf(
            "Authorization" to sha256Hex(cfg.ufiPassword),
            "kano-t" to t,
            "kano-sign" to kanoSign(method, path, t)
        )
    }

    private fun send(
        method: String, path: String, query: String? = null, body: String? = null,
        contentType: String? = null, readTimeoutMs: Int = 12000
    ): String {
        val url = URL(cfg.baseUrl + path + (if (query != null) "?$query" else ""))
        val c = url.openConnection() as HttpURLConnection
        try {
            c.requestMethod = method
            c.connectTimeout = 8000
            c.readTimeout = readTimeoutMs
            c.useCaches = false
            for ((k, v) in headers(method, path)) c.setRequestProperty(k, v)
            if (body != null) {
                c.doOutput = true
                if (contentType != null) c.setRequestProperty("Content-Type", contentType)
                c.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }
            }
            val code = c.responseCode
            if (code !in 200..299) throw IOException("HTTP $code")
            return c.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
        } finally {
            c.disconnect()
        }
    }

    private fun postShell(command: String, path: String): Any? {
        val body = JSONObject().put("command", command).toString()
        val text = send("POST", path, body = body, contentType = "application/json", readTimeoutMs = 15000)
        return parseObj(text).opt("result")
    }

    /** Step 2：user_shell 调用设备本机 zreq，自动登录 ZTE 并读 goform */
    private fun zreqBasic(): JSONObject? {
        val params = "cmd=" + FIELDS.joinToString(",") + "&multi_data=1&isTest=false"
        val cmd = ZREQ_BIN + " -pwd " + shellQuote(cfg.ztePasswordEffective) +
            " -method GET -params " + shellQuote(params) + " -json"
        val r = postShell(cmd, SHELL_PATH) as? JSONObject ?: return null
        if (!r.optBoolean("done", false)) return null
        val content = r.opt("content")
        val obj = when (content) {
            is JSONObject -> content
            is String -> parseObj(content)
            else -> JSONObject()
        }
        return if (obj.length() > 0) obj else null
    }

    private fun goformGet(): JSONObject =
        parseObj(send("GET", GOFORM_GET_PATH, query = "multi_data=1&isTest=false&cmd=" + FIELDS.joinToString(",") + "&_=" + nowMs()))

    private fun loginZTE(): Boolean {
        val ld = str(parseObj(send("GET", GOFORM_GET_PATH, query = "multi_data=1&isTest=false&cmd=LD&_=" + nowMs())).opt("LD"))
            ?: return false
        val pwdHash = sha256Hex(cfg.ztePasswordEffective).uppercase(Locale.ROOT)
        val loginHash = sha256Hex(pwdHash + ld).uppercase(Locale.ROOT)
        val raw = send(
            "POST", GOFORM_SET_PATH,
            body = "goformId=LOGIN&isTest=false&user=admin&password=$loginHash",
            contentType = "application/x-www-form-urlencoded; charset=UTF-8"
        )
        if (raw.contains("\"result\":0") || raw.contains("\"result\":\"0\"")) return true
        val v = parseObj(send("GET", GOFORM_GET_PATH, query = "multi_data=1&isTest=false&cmd=loginfo&_=" + nowMs()))
        return str(v.opt("loginfo")) == "ok"
    }

    /** Step 3：root_shell 读 WiFi 频率和内存，返回 [freq, memTotal, memAvail] */
    private fun rootInfo(): IntArray {
        val cmd = "dumpsys wifi 2>/dev/null | grep -o 'frequency= [0-9]*' | head -1; grep -E 'MemTotal|MemAvailable' /proc/meminfo"
        val r: Any = (try { postShell(cmd, ROOT_SHELL_PATH) } catch (e: Exception) { null }) ?: return intArrayOf(0, 0, 0)
        val s = when (r) {
            is JSONObject -> r.optString("content", r.toString())
            else -> r.toString()
        }
        return intArrayOf(
            firstInt("frequency=\\s*(\\d+)", s) ?: 0,
            firstInt("MemTotal:\\s*(\\d+)", s) ?: 0,
            firstInt("MemAvailable:\\s*(\\d+)", s) ?: 0
        )
    }

    private fun <T> await(f: Future<T>, fallback: T): T =
        try { f.get(30, TimeUnit.SECONDS) } catch (e: Exception) { fallback }

    /** 阻塞调用，必须在后台线程执行 */
    fun fetch(): UfiSnapshot {
        if (!cfg.isConfigured) return UfiSnapshot().apply { error = "未设置后台地址，点此设置" }
        val pool = Executors.newFixedThreadPool(3)
        try {
            val fDev = pool.submit(Callable { try { parseObj(send("GET", DEVICE_PATH)) } catch (e: Exception) { JSONObject() } })
            val fZreq = pool.submit(Callable<JSONObject?> { try { zreqBasic() } catch (e: Exception) { null } })
            val fRoot = pool.submit(Callable { rootInfo() })

            val d = await(fDev, JSONObject())
            var g = await(fZreq, null)
            val zreqOK = g != null
            if (g == null) {
                g = try { goformGet() } catch (e: Exception) { JSONObject() }
                if (str(g.opt("loginfo")) == "no") {
                    val ok = try { loginZTE() } catch (e: Exception) { false }
                    if (ok) g = try { goformGet() } catch (e: Exception) { g }
                }
            }
            val r = await(fRoot, intArrayOf(0, 0, 0))
            val snap = build(d, g ?: JSONObject(), r[0], r[1], r[2])
            snap.zreqOK = zreqOK
            if (d.length() == 0 && (g == null || g.length() == 0)) snap.error = "连接失败，请检查地址和密码"
            return snap
        } finally {
            pool.shutdownNow()
        }
    }
}
