package com.murakabe.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import kotlin.math.min

/**
 * Namaz vakti "sayaç halkası" widget'ı — Alternatif 1. TEK sağlayıcı, iki
 * farklı RemoteViews düzeni arasında widget'ın ANA EKRANA yerleştirildiği
 * boyuta göre (onAppWidgetOptionsChanged) otomatik geçer:
 *  - Geniş/kısa yerleşim  → yatay: 6 vaktin kompakt listesi + sağda halka.
 *  - Dar/uzun (veya kare) → dikey: sadece ortalanmış, büyük halka (başlık/
 *    logo YOK — kullanıcı isteği).
 *
 * RemoteViews'ta hazır bir "dairesel progress" view'ı olmadığından halka
 * Canvas ile çizilip Bitmap olarak basılıyor (bkz. renderRing). Kalan süre
 * arttıkça/azaldıkça renkli yay tam da bu oranda küçülür — okuma yazması
 * olmayan kullanıcılar için de anlaşılır, sayı gerektirmeyen bir gösterge.
 */
class PrayerCountdownWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            updateWidget(context, appWidgetManager, id)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        updateWidget(context, appWidgetManager, appWidgetId, newOptions)
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
        options: Bundle? = null
    ) {
        val opts = options ?: appWidgetManager.getAppWidgetOptions(widgetId)
        val minWidth = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 250)
        val minHeight = opts.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 150)
        // Geniş ve göreceli kısa bir yerleşim → yatay; aksi halde (kare/uzun) dikey.
        val isHorizontal = minWidth >= minHeight * 1.3f

        val views = if (isHorizontal) {
            buildHorizontal(context, widgetId)
        } else {
            buildVertical(context, widgetId, minWidth, minHeight)
        }
        appWidgetManager.updateAppWidget(widgetId, views)
    }

    private fun buildHorizontal(context: Context, widgetId: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_prayer_countdown_horizontal)
        applyTheme(context, views)

        val primary = WidgetPrefs.primaryTextColor(context)
        val dim = WidgetPrefs.dimTextColor(context)
        val accent = WidgetPrefs.accentColor(context)
        val cardFill = WidgetPrefs.withAlpha(accent, 38)

        val nameIds = intArrayOf(R.id.tv_name_0, R.id.tv_name_1, R.id.tv_name_2, R.id.tv_name_3, R.id.tv_name_4, R.id.tv_name_5)
        val timeIds = intArrayOf(R.id.tv_time_0, R.id.tv_time_1, R.id.tv_time_2, R.id.tv_time_3, R.id.tv_time_4, R.id.tv_time_5)
        val cardBgIds = intArrayOf(R.id.card_bg_0, R.id.card_bg_1, R.id.card_bg_2, R.id.card_bg_3, R.id.card_bg_4, R.id.card_bg_5)

        val data = readPrayerData(context)
        if (data != null) {
            val (names, parsed, window) = data
            val timeFormatter = DateTimeFormatter.ofPattern("HH:mm")
            for (i in 0 until 6) {
                views.setTextViewText(nameIds[i], names[i])
                views.setTextViewText(timeIds[i], parsed[i].format(timeFormatter))
                val isNext = window != null && i == window.nextIdx
                views.setTextColor(nameIds[i], if (isNext) accent else dim)
                views.setTextColor(timeIds[i], if (isNext) accent else primary)
                if (isNext) {
                    views.setInt(cardBgIds[i], "setColorFilter", cardFill)
                    views.setViewVisibility(cardBgIds[i], View.VISIBLE)
                } else {
                    views.setViewVisibility(cardBgIds[i], View.INVISIBLE)
                }
            }
            applyRing(context, views, window, names, primary, accent, dim, diameterDp = 72, strokeDp = 6f)
        } else {
            applyRing(context, views, null, emptyList(), primary, accent, dim, diameterDp = 72, strokeDp = 6f)
        }

        setOpenAppIntent(context, views, 700 + widgetId)
        return views
    }

    private fun buildVertical(context: Context, widgetId: Int, minWidth: Int, minHeight: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.widget_prayer_countdown_vertical)
        applyTheme(context, views)

        val primary = WidgetPrefs.primaryTextColor(context)
        val dim = WidgetPrefs.dimTextColor(context)
        val accent = WidgetPrefs.accentColor(context)
        views.setTextColor(R.id.ring_label, dim)

        val diameter = (min(minWidth, minHeight) - 24).coerceIn(90, 220)

        val data = readPrayerData(context)
        if (data != null) {
            val (names, _, window) = data
            applyRing(context, views, window, names, primary, accent, dim, diameterDp = diameter, strokeDp = diameter * 0.075f)
        } else {
            applyRing(context, views, null, emptyList(), primary, accent, dim, diameterDp = diameter, strokeDp = diameter * 0.075f)
        }

        setOpenAppIntent(context, views, 800 + widgetId)
        return views
    }

    private fun applyTheme(context: Context, views: RemoteViews) {
        views.setInt(R.id.widget_root, "setBackgroundResource", WidgetPrefs.backgroundDrawableRes(context))
        views.setFloat(R.id.widget_root, "setAlpha", WidgetPrefs.opacityFraction(context))
    }

    private fun setOpenAppIntent(context: Context, views: RemoteViews, requestCode: Int) {
        val openApp = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pending = PendingIntent.getActivity(
            context, requestCode, openApp,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_root, pending)
    }

    /** SharedPreferences'tan vakit adlarını/saatlerini okur, geçerliyse pencereyi hesaplar. */
    private fun readPrayerData(context: Context): Triple<List<String>, List<LocalDateTime>, PrayerCalc.Window?>? {
        val names = WidgetPrefs.getString(context, "widget_prayer_names")
            .split(",").filter { it.isNotBlank() }
        val timesIso = WidgetPrefs.getString(context, "widget_prayer_times_iso")
            .split(",").filter { it.isNotBlank() }
        val parsed = timesIso.mapNotNull { PrayerCalc.parseLocal(it) }
        if (names.size != 6 || parsed.size != 6) return null
        val window = PrayerCalc.compute(parsed, LocalDateTime.now())
        return Triple(names, parsed, window)
    }

    private fun applyRing(
        context: Context,
        views: RemoteViews,
        window: PrayerCalc.Window?,
        names: List<String>,
        primary: Int,
        accent: Int,
        dim: Int,
        diameterDp: Int,
        strokeDp: Float
    ) {
        val fraction = window?.remainingFraction ?: 0f
        val bitmap = renderRing(context, diameterDp, strokeDp, fraction, WidgetPrefs.withAlpha(dim, 70), accent)
        views.setImageViewBitmap(R.id.ring_image, bitmap)

        if (window != null) {
            views.setTextViewText(R.id.ring_name, names[window.nextIdx])
            views.setTextViewText(R.id.ring_countdown, PrayerCalc.formatRemaining(window.remainingMinutes))
        } else {
            views.setTextViewText(R.id.ring_name, "--")
            views.setTextViewText(R.id.ring_countdown, "--:--")
        }
        views.setTextColor(R.id.ring_name, accent)
        views.setTextColor(R.id.ring_countdown, primary)
    }

    /**
     * Vakit aralığının ne kadarının kaldığını gösteren dairesel gösterge.
     * Tepe noktasından (-90°) başlar, saat yönünde [fraction] oranında yay
     * çizer — zaman geçtikçe bu yay geriye doğru küçülür (1f → 0f).
     */
    private fun renderRing(
        context: Context,
        sizeDp: Int,
        strokeDp: Float,
        fraction: Float,
        trackColor: Int,
        progressColor: Int
    ): Bitmap {
        val density = context.resources.displayMetrics.density
        val sizePx = (sizeDp * density).toInt().coerceAtLeast(1)
        val strokePx = (strokeDp * density).coerceAtLeast(1f)
        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)

        val inset = strokePx / 2f + density
        val rect = RectF(inset, inset, sizePx - inset, sizePx - inset)

        val trackPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = strokePx
            strokeCap = Paint.Cap.ROUND
            color = trackColor
        }
        canvas.drawArc(rect, 0f, 360f, false, trackPaint)

        if (fraction > 0.01f) {
            val progressPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE
                strokeWidth = strokePx
                strokeCap = Paint.Cap.ROUND
                color = progressColor
            }
            canvas.drawArc(rect, -90f, 360f * fraction, false, progressPaint)
        }

        return bitmap
    }
}
