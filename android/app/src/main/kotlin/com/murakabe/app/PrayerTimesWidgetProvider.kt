package com.murakabe.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter

/**
 * Namaz vakitleri widget'ı. Veri Flutter tarafından (WidgetBridgeService)
 * SharedPreferences'a önceden yazılır; burada sadece okuyup çiziyoruz ve
 * "sıradaki vakit" hesabını GÜNCEL saate göre native tarafta yapıyoruz —
 * böylece kullanıcı uygulamayı hiç açmasa bile (widget periyodik olarak
 * kendini yeniden çizdiğinde) "sıradaki vakit" doğru kalır.
 */
class PrayerTimesWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, buildViews(context))
        }
        // "Kalan vakit" yazısı dakikada bir tazelensin diye periyodik tick'i
        // (yeniden) kur — PrayerCountdownWidgetProvider ile paylaşılan tek
        // alarm, iki widget türünü de birlikte tazeler.
        WidgetRefresher.scheduleMinuteTick(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        WidgetRefresher.cancelMinuteTickIfNoPrayerWidgetsLeft(context)
    }

    private fun buildViews(context: Context): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_prayer_times)

        views.setInt(R.id.widget_root, "setBackgroundResource", WidgetPrefs.backgroundDrawableRes(context))
        views.setFloat(R.id.widget_root, "setAlpha", WidgetPrefs.opacityFraction(context))

        val primary = WidgetPrefs.primaryTextColor(context)
        val dim = WidgetPrefs.dimTextColor(context)
        val accent = WidgetPrefs.accentColor(context)

        views.setTextColor(R.id.tv_hijri, accent)
        views.setTextColor(R.id.tv_next, primary)

        val hijri = WidgetPrefs.prayerHijriToday(context)
        views.setTextViewText(R.id.tv_hijri, hijri.ifEmpty { context.getString(R.string.widget_prayer_label) })

        val names = WidgetPrefs.getString(context, "widget_prayer_names")
            .split(",").filter { it.isNotBlank() }
        // Bugünün vakitleri 30 günlük tablodan (bkz. WidgetPrefs.prayerTimesIsoToday).
        val timesIso = WidgetPrefs.prayerTimesIsoToday(context)

        val nameIds = intArrayOf(R.id.tv_name_0, R.id.tv_name_1, R.id.tv_name_2, R.id.tv_name_3, R.id.tv_name_4, R.id.tv_name_5)
        val timeIds = intArrayOf(R.id.tv_time_0, R.id.tv_time_1, R.id.tv_time_2, R.id.tv_time_3, R.id.tv_time_4, R.id.tv_time_5)
        val cardBgIds = intArrayOf(R.id.card_bg_0, R.id.card_bg_1, R.id.card_bg_2, R.id.card_bg_3, R.id.card_bg_4, R.id.card_bg_5)
        val timeFormatter = DateTimeFormatter.ofPattern("HH:mm")

        val parsed = timesIso.mapNotNull { PrayerCalc.parseLocal(it) }
        // Kart zemini: hangi vurgu rengi seçilirse seçilsin göze batmayan,
        // diğer widget'larla (bkz. DailyContentWidgetProvider chipFill) aynı
        // düşük alfalı dolgu — "arkası farklı renkte kartlar" isteği.
        val cardFill = WidgetPrefs.withAlpha(accent, 38)

        if (names.size == 6 && parsed.size == 6) {
            val now = LocalDateTime.now()
            val window = PrayerCalc.compute(parsed, now)

            for (i in 0 until 6) {
                views.setTextViewText(nameIds[i], names[i])
                views.setTextViewText(timeIds[i], parsed[i].format(timeFormatter))
                // Kutucuk SIRADAKİ değil İÇİNDE BULUNULAN vakti vurgular —
                // bkz. PrayerCountdownWidgetProvider'daki aynı düzeltme.
                val isCurrent = window != null && i == window.prevIdx
                views.setTextColor(nameIds[i], if (isCurrent) accent else dim)
                views.setTextColor(timeIds[i], if (isCurrent) accent else primary)
                if (isCurrent) {
                    views.setInt(cardBgIds[i], "setColorFilter", cardFill)
                    views.setViewVisibility(cardBgIds[i], View.VISIBLE)
                } else {
                    views.setViewVisibility(cardBgIds[i], View.INVISIBLE)
                }
            }

            if (window != null) {
                val nextName = names[window.nextIdx]
                val leftText = PrayerCalc.formatRemaining(window.remainingMinutes)
                val suffix = PrayerCalc.dativeSuffix(nextName)
                views.setTextViewText(R.id.tv_next, "$nextName$suffix kalan: $leftText")
            } else {
                views.setTextViewText(R.id.tv_next, context.getString(R.string.widget_prayer_label))
            }
        } else {
            // Henüz veri gelmedi (uygulama hiç açılmadı / konum izni yok).
            views.setTextViewText(R.id.tv_next, context.getString(R.string.widget_prayer_label))
        }

        val openApp = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pending = PendingIntent.getActivity(
            context, 100, openApp,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_root, pending)

        return views
    }
}
