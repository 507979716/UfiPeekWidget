package com.ufipeek.widget

import android.content.Context
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class UfiSnapshot {
    var model = "--"
    var ufiVersion = "--"
    var cpuTemp = "--"
    var cpuUsage = "--"
    var battery = "--"
    var batteryLevel = -1.0
    var charging = false
    var netSummary = "--"
    var signalBar = "--"
    var rsrp = "--"
    var rsrq = "--"
    var snr = "--"
    var ssid = "--"
    var smsUnreadCount: Int? = null
    var wifiDeviceCount: Int? = null
    var dailyValue = "--"
    var dailyUnit = ""
    var monthlyValue = "--"
    var monthlyUnit = ""
    var band = "—"
    var wifiBand = "--"
    var mem = "--"
    var updatedAt = System.currentTimeMillis()
    var zreqOK = false
    var error: String? = null

    val hasData: Boolean get() = model != "--" || dailyValue != "--" || battery != "--"

    fun missingNetworkData(): List<String> = buildList {
        if (netSummary == "--") add("运营商／网络制式")
        if (signalBar == "--" || rsrp == "--" || rsrq == "--" || snr == "--") add("蜂窝信号")
        if (band == "—") add("频段")
        if (ssid == "--") add("Wi-Fi 名称")
        if (wifiDeviceCount == null) add("连接设备数")
        if (smsUnreadCount == null) add("未读短信数")
    }

    val batteryIconRes: Int
        get() = when {
            charging -> R.drawable.ic_bat_charge
            batteryLevel <= 0 -> R.drawable.ic_bat_0
            batteryLevel <= 25 -> R.drawable.ic_bat_25
            batteryLevel <= 50 -> R.drawable.ic_bat_50
            batteryLevel <= 75 -> R.drawable.ic_bat_75
            else -> R.drawable.ic_bat_100
        }

    /** 与原 UfiPeek 脚本一致的电池配色 */
    val batteryColor: Int
        get() = when {
            charging -> 0xFF16A34A.toInt()
            batteryLevel <= 0 -> 0xFFF59E0B.toInt()
            batteryLevel <= 25 -> 0xFFDC2626.toInt()
            batteryLevel <= 50 -> 0xFF0056D6.toInt()
            batteryLevel <= 75 -> 0xFFF59E0B.toInt()
            else -> 0xFF16A34A.toInt()
        }

    fun updatedText(): String = SimpleDateFormat("MM-dd HH:mm", Locale.getDefault()).format(Date(updatedAt))
    fun updatedShort(): String = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date(updatedAt))

    fun toJson(): String = JSONObject()
        .put("model", model).put("ufiVersion", ufiVersion).put("cpuTemp", cpuTemp).put("cpuUsage", cpuUsage)
        .put("battery", battery).put("batteryLevel", batteryLevel).put("charging", charging)
        .put("netSummary", netSummary).put("signalBar", signalBar).put("rsrp", rsrp).put("rsrq", rsrq)
        .put("snr", snr).put("ssid", ssid).put("smsUnreadCount", smsUnreadCount).put("wifiDeviceCount", wifiDeviceCount)
        .put("dailyValue", dailyValue).put("dailyUnit", dailyUnit).put("monthlyValue", monthlyValue)
        .put("monthlyUnit", monthlyUnit).put("band", band).put("wifiBand", wifiBand).put("mem", mem)
        .put("updatedAt", updatedAt).put("zreqOK", zreqOK)
        .toString()

    companion object {
        fun fromJson(text: String?): UfiSnapshot? {
            if (text.isNullOrBlank()) return null
            return try {
                val o = JSONObject(text)
                UfiSnapshot().apply {
                    model = o.optString("model", model)
                    ufiVersion = o.optString("ufiVersion", ufiVersion)
                    cpuTemp = o.optString("cpuTemp", cpuTemp)
                    cpuUsage = o.optString("cpuUsage", cpuUsage)
                    battery = o.optString("battery", battery)
                    batteryLevel = o.optDouble("batteryLevel", batteryLevel)
                    charging = o.optBoolean("charging", charging)
                    netSummary = o.optString("netSummary", netSummary).let { if (it == "-- --") "--" else it }
                    signalBar = o.optString("signalBar", signalBar)
                    rsrp = o.optString("rsrp", rsrp)
                    rsrq = o.optString("rsrq", rsrq)
                    snr = o.optString("snr", snr)
                    ssid = o.optString("ssid", ssid)
                    smsUnreadCount = o.optInt("smsUnreadCount", -1).takeIf { it >= 0 }
                    wifiDeviceCount = o.optInt("wifiDeviceCount", -1).takeIf { it >= 0 }
                    dailyValue = o.optString("dailyValue", dailyValue)
                    dailyUnit = o.optString("dailyUnit", dailyUnit)
                    monthlyValue = o.optString("monthlyValue", monthlyValue)
                    monthlyUnit = o.optString("monthlyUnit", monthlyUnit)
                    band = o.optString("band", band)
                    wifiBand = when (val saved = o.optString("wifiBand", wifiBand)) {
                        "5G" -> "5 GHz"
                        "2.4G" -> "2.4 GHz"
                        else -> saved
                    }
                    mem = o.optString("mem", mem)
                    updatedAt = o.optLong("updatedAt", updatedAt)
                    zreqOK = o.optBoolean("zreqOK", zreqOK)
                }
            } catch (e: Exception) {
                null
            }
        }

        fun placeholder(): UfiSnapshot = UfiSnapshot().apply {
            model = "U30 Air"; ufiVersion = "4.1.0"; cpuTemp = "48.4"; cpuUsage = "4"
            battery = "90"; batteryLevel = 90.0; netSummary = "中国移动 5G"; signalBar = "5"
            rsrp = "-90dBm"; rsrq = "-6"; snr = "12"; ssid = "ZTE_E8CDF6"
            wifiDeviceCount = 2; smsUnreadCount = 0
            dailyValue = "9.88"; dailyUnit = "GB"; monthlyValue = "40.7"; monthlyUnit = "GB"
            band = "N41"; wifiBand = "5 GHz"; mem = "58%"
        }
    }
}

object Prefs {
    private fun sp(ctx: Context) = ctx.applicationContext.getSharedPreferences("ufipeek", Context.MODE_PRIVATE)

    fun load(ctx: Context): UfiConfig {
        val p = sp(ctx)
        return UfiConfig(
            p.getString("url", null)?.takeUnless { it.isBlank() } ?: ctx.getString(R.string.default_backend_address),
            p.getString("password", "") ?: "",
            p.getString("zte_password", "") ?: ""
        )
    }

    fun save(ctx: Context, c: UfiConfig) {
        sp(ctx).edit()
            .putString("url", c.url.trim())
            .putString("password", c.password)
            .putString("zte_password", c.ztePassword)
            .apply()
    }

    fun saveSnapshot(ctx: Context, s: UfiSnapshot) {
        sp(ctx).edit().putString("last_snapshot", s.toJson()).apply()
    }

    fun lastSnapshot(ctx: Context): UfiSnapshot? = UfiSnapshot.fromJson(sp(ctx).getString("last_snapshot", null))
}
