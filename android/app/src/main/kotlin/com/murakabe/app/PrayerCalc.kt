package com.murakabe.app

import java.time.Duration
import java.time.LocalDateTime
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeParseException

/**
 * Namaz vakti "sıradaki vakit" ve "kalan süre yüzdesi" hesabı — hem klasik
 * (PrayerTimesWidgetProvider) hem de sayaçlı/dairesel (PrayerCountdownWidgetProvider)
 * widget'lar TAMAMEN AYNI mantığı kullansın diye tek yerde toplandı.
 */
object PrayerCalc {

    // Güneş (index 1) "sıradaki vakit" adayı değildir — sadece bilgi
    // amaçlı gösterilir (in-app davranışla birebir aynı).
    private val ELIGIBLE = listOf(0, 2, 3, 4, 5)

    data class Window(
        val nextIdx: Int,
        val nextTime: LocalDateTime,
        val prevIdx: Int,
        val remainingMinutes: Long,
        val totalMinutes: Long,
    ) {
        /** 1f = vakit aralığının henüz başı, 0f = sıradaki vakit geldi. */
        val remainingFraction: Float
            get() = (remainingMinutes.toFloat() / totalMinutes.toFloat()).coerceIn(0f, 1f)
    }

    fun parseLocal(iso: String): LocalDateTime? = try {
        // Dart'ın DateTime.toIso8601String() çıktısı 'Z'/offset içermiyorsa
        // yerel (cihaz) saatini temsil eder — WidgetBridgeService bu şekilde
        // yazıyor (adhan paketinin döndürdüğü DateTime local'dir).
        LocalDateTime.parse(iso.substringBefore('Z'), DateTimeFormatter.ISO_LOCAL_DATE_TIME)
    } catch (_: DateTimeParseException) {
        null
    }

    /** [parsed] tam olarak 6 eleman içermeli (İmsak, Güneş, Öğle, İkindi, Akşam, Yatsı). */
    fun compute(parsed: List<LocalDateTime>, now: LocalDateTime): Window? {
        if (parsed.size != 6) return null

        var nextPos = ELIGIBLE.indexOfFirst { parsed[it].isAfter(now) }
        if (nextPos == -1) nextPos = 0 // Yatsı da geçtiyse: yarının İmsak'ı
        val nextIdx = ELIGIBLE[nextPos]
        var nextTime = parsed[nextIdx]
        if (!nextTime.isAfter(now)) nextTime = nextTime.plusDays(1)

        val prevPos = (nextPos - 1 + ELIGIBLE.size) % ELIGIBLE.size
        val prevIdx = ELIGIBLE[prevPos]
        var prevTime = parsed[prevIdx]
        if (prevTime.isAfter(now)) prevTime = prevTime.minusDays(1)

        val totalMinutes = Duration.between(prevTime, nextTime).toMinutes().coerceAtLeast(1)
        val remainingMinutes = Duration.between(now, nextTime).toMinutes().coerceAtLeast(0)

        return Window(nextIdx, nextTime, prevIdx, remainingMinutes, totalMinutes)
    }

    fun formatRemaining(minutes: Long): String {
        val hours = minutes / 60
        val mins = minutes % 60
        return if (hours > 0) "${hours}s ${mins}dk" else "${mins}dk"
    }

    /** Sabit 6 vakit adı için doğru Türkçe yönelme (-e hali) eki. */
    fun dativeSuffix(name: String): String = when (name) {
        "İmsak" -> "'a"
        "Güneş" -> "'e"
        "Öğle" -> "'ye"
        "İkindi" -> "'ye"
        "Akşam" -> "'a"
        "Yatsı" -> "'ya"
        else -> "'a"
    }
}
