package com.murakabe.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews

/**
 * Günlük esmâ / âyet / hadis widget'ı. ‹ › okları TAMAMEN native tarafta
 * işlenir — sadece paylaşılan 'widget_content_index' anahtarını (0=esmâ,
 * 1=âyet, 2=hadis) 3'e göre mod alarak değiştirir; Dart'a gidilmez.
 * İçeriğin kendisi (metinler) Flutter tarafından günlük olarak zaten
 * WidgetBridgeService._refreshDailyContent() ile önceden yazılmıştır —
 * uygulamanın "bugünün içeriği" mantığıyla birebir aynıdır.
 */
class DailyContentWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_PREV = "com.murakabe.app.widget.CONTENT_PREV"
        const val ACTION_NEXT = "com.murakabe.app.widget.CONTENT_NEXT"
        private const val TYPE_COUNT = 3
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, buildViews(context, id))
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val delta = when (intent.action) {
            ACTION_PREV -> -1
            ACTION_NEXT -> 1
            else -> return
        }

        val current = WidgetPrefs.getInt(context, "widget_content_index")
        val next = ((current + delta) % TYPE_COUNT + TYPE_COUNT) % TYPE_COUNT
        WidgetPrefs.putInt(context, "widget_content_index", next)

        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, DailyContentWidgetProvider::class.java))
        for (id in ids) {
            manager.updateAppWidget(id, buildViews(context, id))
        }
    }

    private fun buildViews(context: Context, widgetId: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_daily_content)

        views.setInt(R.id.widget_root, "setBackgroundResource", WidgetPrefs.backgroundDrawableRes(context))
        views.setFloat(R.id.widget_root, "setAlpha", WidgetPrefs.opacityFraction(context))

        val primary = WidgetPrefs.primaryTextColor(context)
        val dim = WidgetPrefs.dimTextColor(context)
        val accent = WidgetPrefs.accentColor(context)
        // Rozet/düğme zeminleri: hangi vurgu rengi seçilirse seçilsin göze
        // batmayacak, sabit düşük alfalı bir dolgu — "dengeyi koru" isteği.
        val chipFill = WidgetPrefs.withAlpha(accent, 38)
        // ‹ › ok butonlarının ARKA PLAN halkası tamamen saydam olmalı —
        // kullanıcı isteği: "arkaplanı şeffaflaştır, buton (ok ikonu) görünür
        // kalsın". Önceki denemede yanlışlıkla okun kendisi soluklaşmıştı;
        // bu yüzden burada SADECE zemin (…_bg) için alfa düşürülüyor, ok
        // ikonu aşağıda ayrıca ve her zaman TAM OPAK bırakılıyor.
        val navFill = WidgetPrefs.withAlpha(dim, 0)
        // Ok ikonlarının rengi — alfa kanalı ne olursa olsun (primary rengin
        // kendisi widget saydamlık ayarından etkilenmiş olabilir) 255'e
        // sabitleniyor, böylece ok her zaman net görünür.
        val navIconColor = WidgetPrefs.withAlpha(primary, 255)

        views.setInt(R.id.chip_content_type_bg, "setColorFilter", chipFill)
        views.setTextColor(R.id.tv_content_type, accent)
        views.setTextColor(R.id.tv_content_primary, primary)
        views.setTextColor(R.id.tv_content_secondary, dim)
        views.setTextColor(R.id.tv_esma_tr, primary)
        views.setTextColor(R.id.tv_esma_ar, primary)
        views.setTextColor(R.id.tv_esma_meaning, dim)

        // Zemin (arka plan halkası) tamamen saydam; ok ikonunun kendisi tam
        // opak ve setImageAlpha ile de garanti altına alınıyor — sadece
        // arka plan şeffaflaşsın, buton (ok) her zaman görünür kalsın.
        views.setInt(R.id.btn_content_prev_bg, "setColorFilter", navFill)
        views.setInt(R.id.btn_content_next_bg, "setColorFilter", navFill)
        views.setInt(R.id.btn_content_prev, "setColorFilter", navIconColor)
        views.setInt(R.id.btn_content_next, "setColorFilter", navIconColor)
        views.setInt(R.id.btn_content_prev, "setImageAlpha", 255)
        views.setInt(R.id.btn_content_next, "setImageAlpha", 255)

        val index = ((WidgetPrefs.getInt(context, "widget_content_index") % TYPE_COUNT) + TYPE_COUNT) % TYPE_COUNT

        if (index == 0) {
            // Esmâ'ül Hüsnâ: Arapça sağda, Türkçe adı solda, altında anlamı —
            // bu, tek satırlık genel gövde metninden farklı, kendine özel
            // bir düzen (bkz. layout'taki esma_group).
            views.setTextViewText(R.id.tv_content_type, context.getString(R.string.widget_content_type_esma))
            views.setTextViewText(
                R.id.tv_esma_tr,
                WidgetPrefs.getString(context, "widget_esma_tr").ifEmpty { "—" }
            )
            views.setTextViewText(R.id.tv_esma_ar, WidgetPrefs.getString(context, "widget_esma_ar"))
            views.setTextViewText(R.id.tv_esma_meaning, WidgetPrefs.getString(context, "widget_esma_meaning"))

            views.setViewVisibility(R.id.esma_group, View.VISIBLE)
            views.setViewVisibility(R.id.tv_content_primary, View.GONE)
            views.setViewVisibility(R.id.tv_content_secondary, View.GONE)
        } else {
            val (typeLabel, primaryText, secondaryText) = if (index == 1) {
                Triple(
                    context.getString(R.string.widget_content_type_ayet),
                    WidgetPrefs.getString(context, "widget_ayet_text"),
                    WidgetPrefs.getString(context, "widget_ayet_source")
                )
            } else {
                Triple(
                    context.getString(R.string.widget_content_type_hadis),
                    WidgetPrefs.getString(context, "widget_hadis_text"),
                    WidgetPrefs.getString(context, "widget_hadis_source")
                )
            }

            views.setTextViewText(R.id.tv_content_type, typeLabel)
            views.setTextViewText(
                R.id.tv_content_primary,
                primaryText.ifEmpty { context.getString(R.string.widget_content_label) }
            )
            views.setTextViewText(R.id.tv_content_secondary, secondaryText)

            views.setViewVisibility(R.id.esma_group, View.GONE)
            views.setViewVisibility(R.id.tv_content_primary, View.VISIBLE)
            views.setViewVisibility(
                R.id.tv_content_secondary,
                if (secondaryText.isBlank()) View.GONE else View.VISIBLE
            )
        }

        val prevIntent = Intent(context, DailyContentWidgetProvider::class.java).apply { action = ACTION_PREV }
        val nextIntent = Intent(context, DailyContentWidgetProvider::class.java).apply { action = ACTION_NEXT }
        val prevPending = PendingIntent.getBroadcast(
            context, 400 + widgetId, prevIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val nextPending = PendingIntent.getBroadcast(
            context, 500 + widgetId, nextIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.btn_content_prev, prevPending)
        views.setOnClickPendingIntent(R.id.btn_content_prev_bg, prevPending)
        views.setOnClickPendingIntent(R.id.btn_content_next, nextPending)
        views.setOnClickPendingIntent(R.id.btn_content_next_bg, nextPending)

        val openApp = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openPending = PendingIntent.getActivity(
            context, 600 + widgetId, openApp,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.tv_content_primary, openPending)
        views.setOnClickPendingIntent(R.id.tv_content_secondary, openPending)
        views.setOnClickPendingIntent(R.id.esma_group, openPending)

        return views
    }
}
