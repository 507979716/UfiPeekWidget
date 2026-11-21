package com.ufipeek.widget

import android.app.job.JobParameters
import android.app.job.JobService
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent

open class BaseWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        WidgetUpdater.schedulePeriodic(context)
        WidgetUpdater.requestRefresh(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == WidgetUpdater.ACTION_REFRESH) {
            WidgetUpdater.requestRefresh(context)
        }
    }

    override fun onEnabled(context: Context) {
        WidgetUpdater.schedulePeriodic(context)
    }

    override fun onDisabled(context: Context) {
        if (!WidgetUpdater.hasWidgets(context)) WidgetUpdater.cancelPeriodic(context)
    }
}

/** 中号 4×2：完整复刻 UfiPeek */
class MediumWidget : BaseWidget()

/** 小号 2×2：流量 + 电量 */
class SmallWidget : BaseWidget()

/** 后台取数，JobScheduler 给足时间，不受广播 10 秒限制 */
class RefreshJobService : JobService() {
    override fun onStartJob(params: JobParameters): Boolean {
        val app = applicationContext
        Thread {
            try {
                val cfg = Prefs.load(app)
                val fresh = UfiClient(cfg).fetch()
                val shown = if (fresh.error == null) {
                    Prefs.saveSnapshot(app, fresh)
                    fresh
                } else {
                    // 失败时保留上次数据，只提示错误
                    val last = Prefs.lastSnapshot(app)
                    if (last != null && last.hasData) last.apply { error = fresh.error } else fresh
                }
                WidgetUpdater.render(app, shown, false)
            } catch (e: Exception) {
                WidgetUpdater.render(app, Prefs.lastSnapshot(app), false)
            } finally {
                jobFinished(params, false)
            }
        }.start()
        return true
    }

    override fun onStopJob(params: JobParameters): Boolean = false
}
