package com.ufipeek.widget

import android.app.PendingIntent
import android.app.job.JobInfo
import android.app.job.JobScheduler
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews

object WidgetUpdater {
    const val ACTION_REFRESH = "com.ufipeek.widget.ACTION_REFRESH"
    private const val JOB_NOW = 1001
    private const val JOB_PERIODIC = 1002

    private fun ids(ctx: Context, cls: Class<*>): IntArray =
        AppWidgetManager.getInstance(ctx).getAppWidgetIds(ComponentName(ctx, cls))

    fun hasWidgets(ctx: Context): Boolean =
        ids(ctx, MediumWidget::class.java).isNotEmpty() || ids(ctx, SmallWidget::class.java).isNotEmpty()

    /** 把快照画到所有 UfiPeek 小组件上 */
    fun render(ctx: Context, snap: UfiSnapshot?, refreshing: Boolean) {
        val mgr = AppWidgetManager.getInstance(ctx)
        val configured = Prefs.load(ctx).isConfigured
        val s = snap ?: UfiSnapshot().apply {
            error = if (configured) "暂无数据，点一下刷新" else "未设置后台地址，点此设置"
        }
        if (!configured) s.error = "未设置后台地址，点此设置"

        val medium = ids(ctx, MediumWidget::class.java)
        if (medium.isNotEmpty()) mgr.updateAppWidget(medium, mediumViews(ctx, s, refreshing, configured))
        val small = ids(ctx, SmallWidget::class.java)
        if (small.isNotEmpty()) mgr.updateAppWidget(small, smallViews(ctx, s, refreshing, configured))
    }

    private fun mediumViews(ctx: Context, s: UfiSnapshot, refreshing: Boolean, configured: Boolean): RemoteViews {
        val full = buildMedium(ctx, s, R.layout.widget_medium, refreshing, configured)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val compact = buildMedium(ctx, s, R.layout.widget_medium_compact, refreshing, configured)
            return RemoteViews(mapOf(SizeF(200f, 80f) to compact, SizeF(200f, 135f) to full))
        }
        return full
    }

    fun buildMedium(ctx: Context, s: UfiSnapshot, layout: Int, refreshing: Boolean, configured: Boolean): RemoteViews {
        val v = RemoteViews(ctx.packageName, layout)
        v.setTextViewText(R.id.model, s.model)
        v.setTextViewText(R.id.ufi_ver, "UFI v" + s.ufiVersion)
        v.setTextViewText(R.id.signal_bar, s.signalBar)
        v.setViewVisibility(R.id.signal_bar, if (s.signalBar == "--") View.GONE else View.VISIBLE)
        v.setViewVisibility(R.id.signal_icon, if (s.signalBar == "--") View.GONE else View.VISIBLE)
        v.setImageViewResource(R.id.bat_icon, s.batteryIconRes)
        v.setInt(R.id.bat_icon, "setColorFilter", s.batteryColor)
        v.setTextViewText(R.id.battery, s.battery + "%")

        v.setTextViewText(R.id.daily_value, s.dailyValue)
        v.setTextViewText(R.id.daily_unit, s.dailyUnit)
        v.setTextViewText(R.id.monthly_value, s.monthlyValue)
        v.setTextViewText(R.id.monthly_unit, s.monthlyUnit)

        val mobile = listOf(
            Triple(R.id.net_metric, R.id.net, s.netSummary.takeUnless { it == "--" }),
            Triple(R.id.band_metric, R.id.band, s.band.takeUnless { it == "—" }),
            Triple(R.id.cpu_metric, R.id.cpu, s.cpuUsage.takeUnless { it == "--" }?.plus("%")),
            Triple(R.id.temp_metric, R.id.temp, s.cpuTemp.takeUnless { it == "--" }?.plus("℃")),
        )
        bindMetrics(v, R.id.mobile_metrics, mobile)

        if (layout != R.layout.widget_medium_compact) {
            val wifi = listOf(
                Triple(R.id.ssid_metric, R.id.ssid, s.ssid.takeUnless { it == "--" }),
                Triple(R.id.wifi_band_metric, R.id.wifi_band, s.wifiBand.takeUnless { it == "--" }),
                Triple(R.id.mem_metric, R.id.mem, s.mem.takeUnless { it == "--" }),
                Triple(R.id.devices_metric, R.id.devices, s.wifiDeviceCount?.toString()),
                Triple(R.id.sms_metric, R.id.sms, s.smsUnreadCount?.toString()),
            )
            bindMetrics(v, R.id.wifi_metrics, wifi)
            val smsColor = if ((s.smsUnreadCount ?: 0) > 0) R.color.error else R.color.secondary
            v.setInt(R.id.sms_icon, "setColorFilter", ctx.getColor(smsColor))
        }

        val err = s.error
        if (err != null) {
            v.setViewVisibility(R.id.signal_group, View.GONE)
            v.setViewVisibility(R.id.error_text, View.VISIBLE)
            v.setTextViewText(R.id.error_text, "⚠ $err")
        } else {
            v.setViewVisibility(R.id.signal_group, View.VISIBLE)
            v.setViewVisibility(R.id.error_text, View.GONE)
            val signal = listOf("RSRP" to s.rsrp, "RSRQ" to s.rsrq, "SNR" to s.snr)
                .filter { (_, value) -> value != "--" }
                .joinToString(" · ") { (label, value) -> "$label $value" }
            v.setTextViewText(R.id.signal_detail, signal.ifEmpty { ctx.getString(R.string.widget_signal_unavailable) })
        }
        v.setTextViewText(R.id.update_time, if (refreshing) "刷新中…" else s.updatedText())

        v.setOnClickPendingIntent(R.id.root, if (configured) refreshIntent(ctx) else settingsIntent(ctx))
        v.setOnClickPendingIntent(R.id.top_bar, settingsIntent(ctx))
        return v
    }

    private fun bindMetrics(views: RemoteViews, row: Int, metrics: List<Triple<Int, Int, String?>>) {
        views.setViewVisibility(row, if (metrics.any { it.third != null }) View.VISIBLE else View.GONE)
        for ((container, text, value) in metrics) {
            views.setViewVisibility(container, if (value != null) View.VISIBLE else View.GONE)
            if (value != null) views.setTextViewText(text, value)
        }
    }

    private fun smallViews(ctx: Context, s: UfiSnapshot, refreshing: Boolean, configured: Boolean): RemoteViews {
        val v = RemoteViews(ctx.packageName, R.layout.widget_small)
        v.setTextViewText(R.id.model, s.model)
        v.setImageViewResource(R.id.bat_icon, s.batteryIconRes)
        v.setInt(R.id.bat_icon, "setColorFilter", s.batteryColor)
        v.setTextViewText(R.id.battery, s.battery + "%")
        v.setTextViewText(R.id.daily_value, s.dailyValue)
        v.setTextViewText(R.id.daily_unit, s.dailyUnit)
        v.setTextViewText(R.id.monthly, listOf(s.monthlyValue, s.monthlyUnit).filter { it.isNotEmpty() }.joinToString(" "))

        val err = s.error
        v.setViewVisibility(R.id.signal_icon, if (err == null && s.netSummary != "--") View.VISIBLE else View.GONE)
        if (err != null) {
            v.setViewVisibility(R.id.net, View.GONE)
            v.setViewVisibility(R.id.error_text, View.VISIBLE)
            v.setTextViewText(R.id.error_text, err)
        } else {
            v.setViewVisibility(R.id.net, View.VISIBLE)
            v.setViewVisibility(R.id.error_text, View.GONE)
            v.setTextViewText(R.id.net, s.netSummary.takeUnless { it == "--" } ?: ctx.getString(R.string.widget_signal_unavailable))
        }
        v.setTextViewText(R.id.update_time, if (refreshing) "刷新中…" else s.updatedShort())

        v.setOnClickPendingIntent(R.id.root, if (configured) refreshIntent(ctx) else settingsIntent(ctx))
        v.setOnClickPendingIntent(R.id.top_bar, settingsIntent(ctx))
        return v
    }

    private fun refreshIntent(ctx: Context): PendingIntent {
        val i = Intent(ctx, MediumWidget::class.java).setAction(ACTION_REFRESH)
        return PendingIntent.getBroadcast(ctx, 0, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun settingsIntent(ctx: Context): PendingIntent {
        val i = Intent(ctx, ConfigActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        return PendingIntent.getActivity(ctx, 1, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    /** 立即刷新：先显示「刷新中…」，再交给 JobScheduler 在后台取数 */
    fun requestRefresh(ctx: Context) {
        val configured = Prefs.load(ctx).isConfigured
        render(ctx, Prefs.lastSnapshot(ctx), refreshing = configured)
        if (!configured) return
        val js = ctx.getSystemService(JobScheduler::class.java) ?: return
        val job = JobInfo.Builder(JOB_NOW, ComponentName(ctx, RefreshJobService::class.java))
            .setOverrideDeadline(1000)
            .build()
        try { js.schedule(job) } catch (e: Exception) { }
    }

    /** 周期刷新（系统最短 15 分钟） */
    fun schedulePeriodic(ctx: Context) {
        val js = ctx.getSystemService(JobScheduler::class.java) ?: return
        if (js.getPendingJob(JOB_PERIODIC) != null) return
        val job = JobInfo.Builder(JOB_PERIODIC, ComponentName(ctx, RefreshJobService::class.java))
            .setPeriodic(15 * 60 * 1000L)
            .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
            .setPersisted(true)
            .build()
        try { js.schedule(job) } catch (e: Exception) { }
    }

    fun cancelPeriodic(ctx: Context) {
        ctx.getSystemService(JobScheduler::class.java)?.cancel(JOB_PERIODIC)
    }
}
