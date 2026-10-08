package com.murakabe.app

import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import org.json.JSONException
import org.json.JSONObject
import java.time.LocalDate

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

    // DÜZELTME (kritik — widget senkron sorunlarının önemli kısmı buydu):
    // Flutter'ın shared_preferences Android eklentisi, Dart'ın setInt()
    // çağrısındaki değeri SharedPreferences'a `putLong` ile yazar — Dart'ın
    // `int` tipi 64-bit'tir, 32-bit `putInt` kullanılırsa büyük değerlerde
    // sessiz taşma olurdu (bkz. shared_preferences_android eklentisinin
    // kendi kaynağı). SharedPreferences.getInt() ise dosyadaki değerin GERÇEK
    // saklama tipiyle (Long) eşleşmediğinde ClassCastException fırlatır; eski
    // kod bunu yakalayıp SESSİZCE varsayılan değere düşüyordu — bu yüzden
    // zikir sayısı/hedefi, widget saydamlığı ve içerik indeksi native tarafta
    // bazen "sıfırlanmış/değişmemiş" görünüyordu. Çözüm: ham değeri tip
    // ayrımı yapmadan `Number` olarak okuyup `toInt()` ile dönüştürmek —
    // hem Int hem Long (hatta Float/Double) olarak saklanmış eski/yeni
    // verilerle uyumlu.
    fun getInt(context: Context, key: String, default: Int = 0): Int {
        val raw = prefs(context).all[KEY_PREFIX + key]
        return when (raw) {
            is Number -> raw.toInt()
            else -> default
        }
    }

    // Yazarken de Flutter ile AYNI temsili (Long) kullanıyoruz — böylece
    // native tarafın yazdığı bir değer daha sonra Dart tarafından okunursa
    // (shared_preferences paketi zaten Number bazlı okuduğundan) ya da bu
    // dosyanın putInt'i üzerine yazdığı bir anahtar tekrar Dart'ın getInt'i
    // ile okunursa tip tutarsızlığı oluşmaz.
    fun putInt(context: Context, key: String, value: Int) {
        prefs(context).edit().putLong(KEY_PREFIX + key, value.toLong()).apply()
    }

    fun getBoolean(context: Context, key: String, default: Boolean = false): Boolean =
        try {
            prefs(context).getBoolean(KEY_PREFIX + key, default)
        } catch (_: ClassCastException) {
            default
        }

    fun putBoolean(context: Context, key: String, value: Boolean) {
        prefs(context).edit().putBoolean(KEY_PREFIX + key, value).apply()
    }

    fun putString(context: Context, key: String, value: String) {
        prefs(context).edit().putString(KEY_PREFIX + key, value).apply()
    }

    fun remove(context: Context, key: String) {
        prefs(context).edit().remove(KEY_PREFIX + key).apply()
    }

    // ── 30 günlük tablolar ───────────────────────────────────────────────
    // Dart tarafı (WidgetBridgeService) namaz vakti / günlük içerik / zikir
    // verisini {"yyyy-MM-dd": {...}} biçiminde 30 gün ileriye yazar. Widget
    // her çizildiğinde BUGÜNÜN kaydını buradan okur — böylece uygulama hiç
    // açılmasa da gün değişince doğru günün verisi gösterilir. Tabloda
    // bugünün kaydı yoksa (ör. eski sürümden gelen veri) çağıran taraf eski
    // tek günlük anahtarlara düşer.

    /** [key] tablosundan [date] gününün kaydı; yoksa null. */
    fun dayEntry(context: Context, key: String, date: LocalDate = LocalDate.now()): JSONObject? {
        val raw = getString(context, key)
        if (raw.isEmpty()) return null
        return try {
            JSONObject(raw).optJSONObject(date.toString())
        } catch (_: JSONException) {
            null
        }
    }

    /** Bugünün 6 vakti (ISO). Tabloda yoksa eski 'widget_prayer_times_iso'. */
    fun prayerTimesIsoToday(context: Context): List<String> {
        val arr = dayEntry(context, "widget_prayer_days")?.optJSONArray("t")
        if (arr != null && arr.length() == 6) {
            return (0 until 6).map { arr.optString(it) }
        }
        return getString(context, "widget_prayer_times_iso")
            .split(",").filter { it.isNotBlank() }
    }

    /** Bugünün hicri tarihi. Tabloda yoksa eski 'widget_prayer_hijri'. */
    fun prayerHijriToday(context: Context): String {
        val entry = dayEntry(context, "widget_prayer_days")
        return entry?.optString("h") ?: getString(context, "widget_prayer_hijri")
    }

    /** Günlük tablo alanı: bugünün kaydı VARSA onu (boş da olsa), yoksa eski anahtarı döner. */
    fun dayString(context: Context, tableKey: String, field: String, legacyKey: String): String {
        val entry = dayEntry(context, tableKey)
        return if (entry != null) entry.optString(field) else getString(context, legacyKey)
    }

    /** Bugünün zikir hedefi — tabloda yoksa eski 'widget_zikir_target'. */
    fun zikirTargetToday(context: Context): Int {
        val entry = dayEntry(context, "widget_zikir_days")
        val target = if (entry != null && entry.has("g")) {
            entry.optInt("g", 33)
        } else {
            getInt(context, "widget_zikir_target", 33)
        }
        return target.coerceAtLeast(1)
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
