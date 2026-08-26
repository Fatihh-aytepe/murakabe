package com.murakabe.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews

/**
 * Zikir sayacı widget'ı. "+1" dokunuşu TAMAMEN native tarafta işlenir —
 * Dart'a hiç gidilmez; paylaşılan 'zikirCurrentCount' anahtarı doğrudan
 * artırılır (ZikirSayacScreen ekranı da aynı anahtarı okuduğu için
 * uygulama açıldığında iki taraf otomatik senkron olur).
 */
class ZikirWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_INCREMENT = "com.murakabe.app.widget.ZIKIR_INCREMENT"
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
        if (intent.action != ACTION_INCREMENT) return

        // Hedefe ulaşınca (in-app davranışla birebir aynı) sayaç sıfırlanır.
        val target = WidgetPrefs.getInt(context, "widget_zikir_target", 33).coerceAtLeast(1)
        val current = WidgetPrefs.getInt(context, "zikirCurrentCount")
        val next = if (current + 1 >= target) 0 else current + 1
        WidgetPrefs.putInt(context, "zikirCurrentCount", next)

        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(ComponentName(context, ZikirWidgetProvider::class.java))
        for (id in ids) {
            manager.updateAppWidget(id, buildViews(context, id))
        }
    }

    private fun buildViews(context: Context, widgetId: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_zikir)

        views.setInt(R.id.widget_root, "setBackgroundResource", WidgetPrefs.backgroundDrawableRes(context))
        views.setFloat(R.id.widget_root, "setAlpha", WidgetPrefs.opacityFraction(context))

        val primary = WidgetPrefs.primaryTextColor(context)
        val dim = WidgetPrefs.dimTextColor(context)
        val accent = WidgetPrefs.accentColor(context)

        // NOT: Arapça boşsa RASTGELE/sabit bir Arapça metinle doldurmuyoruz —
        // kullanıcı özel zikrinde Arapça girmediyse (opsiyonel alan), widget'ta
        // Türkçesiyle eşleşmeyen bir Arapça göstermek yerine o satırı tamamen
        // gizliyoruz (daha önce buradaki sabit fallback bu senkron hatasına
        // sebep oluyordu).
        val arabic = WidgetPrefs.getString(context, "widget_zikir_arabic")
        val turkish = WidgetPrefs.getString(context, "widget_zikir_turkish")
            .ifEmpty { "Sübhanallah" }
        val target = WidgetPrefs.getInt(context, "widget_zikir_target", 33).coerceAtLeast(1)
        val current = WidgetPrefs.getInt(context, "zikirCurrentCount")

        if (arabic.isEmpty()) {
            views.setViewVisibility(R.id.tv_zikir_ar, View.GONE)
        } else {
            views.setViewVisibility(R.id.tv_zikir_ar, View.VISIBLE)
            views.setTextViewText(R.id.tv_zikir_ar, arabic)
            views.setTextColor(R.id.tv_zikir_ar, primary)
        }
        views.setTextViewText(R.id.tv_zikir_tr, turkish)
        views.setTextColor(R.id.tv_zikir_tr, dim)
        views.setTextViewText(R.id.tv_zikir_count, "$current / $target")
        views.setTextColor(R.id.tv_zikir_count, accent)

        // Sağdaki "+1" dairesi (widget_circle_solid.xml düz beyaz dolgu)
        // her zaman kullanıcının seçtiği vurgu rengiyle boyanır; etiket rengi
        // bu zeminle her zaman kontrastlı olsun diye sabit koyu lacivert
        // tutuluyor (altın/turkuaz/vs. hangi vurgu rengi seçilirse seçilsin
        // koyu lacivert üzerinde okunaklı kalır).
        views.setInt(R.id.btn_zikir_plus_bg, "setColorFilter", accent)
        views.setTextColor(R.id.btn_zikir_plus_label, Color.parseColor("#1C3050"))

        val plusIntent = Intent(context, ZikirWidgetProvider::class.java).apply {
            action = ACTION_INCREMENT
        }
        val plusPending = PendingIntent.getBroadcast(
            context, 200 + widgetId, plusIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.btn_zikir_plus, plusPending)
        views.setOnClickPendingIntent(R.id.btn_zikir_plus_bg, plusPending)
        views.setOnClickPendingIntent(R.id.btn_zikir_plus_label, plusPending)

        val openApp = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val openPending = PendingIntent.getActivity(
            context, 300 + widgetId, openApp,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        // Sol (metin) alan uygulamayı açar; sağdaki daire ise +1 yapar.
        views.setOnClickPendingIntent(R.id.tv_zikir_ar, openPending)
        views.setOnClickPendingIntent(R.id.tv_zikir_tr, openPending)
        views.setOnClickPendingIntent(R.id.tv_zikir_count, openPending)

        return views
    }
}
