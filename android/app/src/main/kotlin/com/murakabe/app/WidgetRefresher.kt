package com.murakabe.app

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context

/** Üç widget sağlayıcısının tümünü tek çağrıyla yeniden çizdirir. */
object WidgetRefresher {
    fun refreshAll(context: Context) {
        refresh(context, PrayerTimesWidgetProvider::class.java)
        refresh(context, PrayerCountdownWidgetProvider::class.java)
        refresh(context, ZikirWidgetProvider::class.java)
        refresh(context, DailyContentWidgetProvider::class.java)
    }

    private fun refresh(context: Context, provider: Class<*>) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, provider))
        if (ids.isEmpty()) return
        val intent = android.content.Intent(context, provider)
        intent.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
        intent.putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        context.sendBroadcast(intent)
    }
}
