package com.murakabe.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent

/** Üç widget sağlayıcısının tümünü tek çağrıyla yeniden çizdirir. */
object WidgetRefresher {

    /** Namaz vakti widget'larının "kalan vakit" göstergesini her dakika
     * tazelemek için kullanılan periyodik alarm'ın action'ı ve request kodu.
     * PrayerCountdownWidgetProvider bu action'ı onReceive'de yakalar. */
    const val ACTION_PRAYER_TICK = "com.murakabe.app.widget.PRAYER_TICK"
    private const val TICK_REQUEST_CODE = 900

    fun refreshAll(context: Context) {
        refresh(context, PrayerTimesWidgetProvider::class.java)
        refresh(context, PrayerCountdownWidgetProvider::class.java)
        refresh(context, ZikirWidgetProvider::class.java)
        refresh(context, DailyContentWidgetProvider::class.java)
    }

    /** Sadece namaz vakti widget'larını yeniden çizer — dakikalık "tick" bunu
     * kullanır, diğer widget'ları (zikir, günlük içerik) gereksiz yere
     * yeniden çizmemek için. */
    fun refreshPrayerWidgets(context: Context) {
        refresh(context, PrayerTimesWidgetProvider::class.java)
        refresh(context, PrayerCountdownWidgetProvider::class.java)
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

    private fun tickPendingIntent(context: Context): PendingIntent {
        val intent = Intent(context, PrayerCountdownWidgetProvider::class.java).apply {
            action = ACTION_PRAYER_TICK
        }
        return PendingIntent.getBroadcast(
            context, TICK_REQUEST_CODE, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    /**
     * Namaz vakti widget'larından en az biri ekranda olduğu sürece her
     * dakika bir kez PRAYER_TICK broadcast'i tetikleyen tekrarlı alarm'ı
     * (yeniden) kurar. `setInexactRepeating` + `AlarmManager.RTC` bilinçli
     * tercih: cihazı uyandırmaz (pil dostu), Doze'da bile birikimli olarak
     * er ya da geç tetiklenir — bir ana ekran widget'ının "kalan süre"
     * yazısı için saniye hassasiyeti gerekmiyor, dakika yeterli. Zaten
     * kayıtlıysa (aynı PendingIntent) tekrar çağırmak zararsız, üst üste
     * birikmez.
     */
    fun scheduleMinuteTick(context: Context) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        am.setInexactRepeating(
            AlarmManager.RTC,
            System.currentTimeMillis() + AlarmManager.INTERVAL_MINUTE,
            AlarmManager.INTERVAL_MINUTE,
            tickPendingIntent(context)
        )
    }

    /** Son namaz vakti widget'ı da kaldırıldıysa alarm'ı durdurur — gereksiz
     * arka plan çalışmasını (ve pil tüketimini) önler. */
    fun cancelMinuteTickIfNoPrayerWidgetsLeft(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val a = manager.getAppWidgetIds(ComponentName(context, PrayerTimesWidgetProvider::class.java))
        val b = manager.getAppWidgetIds(ComponentName(context, PrayerCountdownWidgetProvider::class.java))
        if (a.isNotEmpty() || b.isNotEmpty()) return
        val am = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        am.cancel(tickPendingIntent(context))
    }
}
