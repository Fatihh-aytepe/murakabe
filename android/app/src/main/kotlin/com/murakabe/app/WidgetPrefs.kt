package com.murakabe.app

import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color

/**
 * Flutter'ın `shared_preferences` eklentisinin Android'de kullandığı
 * SharedPreferences dosyasını doğrudan okur/yazar (dosya adı ve
 * "flutter." anahtar öneki bu eklentinin sabit, uzun süredir değişmeyen
 * davranışıdır — pubspec.yaml'daki shared_preferences: ^2.2.2 bu şemayı
 * kullanır). Böylece ayrı bir native köprü paketine ihtiyaç duymadan
 * lib/data/local/local_storage.dart ile aynı verileri paylaşırız.
 *
 * NOT: Anahtar isimlerini değiştirirsen lib/data/local/local_storage.dart
 * içindeki karşılıklarını da güncellemen gerekir.
 */
object WidgetPrefs {
    private const val PREFS_NAME = "FlutterSharedPreferences"
    private const val KEY_PREFIX = "flutter."

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun getString(context: Context, key: String, default: String = ""): String =
        prefs(context).getString(KEY_PREFIX + key, default) ?: default

    fun getInt(context: Context, key: String, default: Int = 0): Int =
        try {
            prefs(context).getInt(KEY_PREFIX + key, default)
        } catch (_: ClassCastException) {
            default
        }

    fun putInt(context: Context, key: String, value: Int) {
        prefs(context).edit().putInt(KEY_PREFIX + key, value).apply()
    }

    // ── Görünüm ayarları ─────────────────────────────────────────────────
    fun themeMode(context: Context): String = getString(context, "widget_theme_mode", "signature")
    fun bgOpacity(context: Context): Int = getInt(context, "widget_bg_opacity", 100)
    fun accentColor(context: Context): Int {
        val hex = getString(context, "widget_accent_hex", "D4AF37")
        return try {
            Color.parseColor("#$hex")
        } catch (_: IllegalArgumentException) {
            Color.parseColor("#D4AF37")
        }
    }

    /** Seçili temaya göre arka plan drawable kaynağını döner. */
    fun backgroundDrawableRes(context: Context): Int {
        return when (themeMode(context)) {
            "light" -> R.drawable.widget_bg_light
            "dark" -> R.drawable.widget_bg_dark
            else -> R.drawable.widget_bg_signature
        }
    }

    fun primaryTextColor(context: Context): Int {
        return when (themeMode(context)) {
            "light" -> Color.parseColor("#2C2C2C")
            else -> Color.WHITE
        }
    }

    fun dimTextColor(context: Context): Int {
        return when (themeMode(context)) {
            "light" -> Color.parseColor("#8A8478")
            else -> Color.parseColor("#B9C2CC")
        }
    }

    fun opacityFraction(context: Context): Float =
        (bgOpacity(context).coerceIn(20, 100)) / 100f

    /** Bir rengin aynı tonda, verilen alfa (0-255) değerine sahip halini döner.
     * Chip/rozet zeminleri gibi "hangi vurgu rengi seçilirse seçilsin göze
     * batmasın" gereken yerlerde kullanılır — bkz. DailyContentWidgetProvider,
     * PrayerTimesWidgetProvider. */
    fun withAlpha(color: Int, alpha: Int): Int =
        Color.argb(alpha, Color.red(color), Color.green(color), Color.blue(color))
}
