package com.murakabe.app

import android.app.Activity
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.provider.OpenableColumns
import io.flutter.plugin.common.MethodChannel

/**
 * Kullanıcının kendi alarm/bildirim sesini cihazından seçip eklemesi.
 *
 * Sesin fiziksel olarak nerede tutulacağı sorusunun cevabı MediaStore'dur:
 * app-private dosya (files dir) + FileProvider yerine, MediaStore.Audio.Media
 * koleksiyonuna IS_NOTIFICATION=1 ile ekliyoruz. Bunun native tarafta
 * araştırılmış, bilinçli bir tercih olma sebebi: app-private bir dosyayı
 * FileProvider ile paylaşıp NotificationChannel'a vermek, sistemin
 * (systemui/notification servisi) o content:// URI'yi okuyabilmesi için
 * cihaza/OEM'e göre değişen, garantisi olmayan bir grantUriPermission
 * hack'i gerektiriyor. MediaStore'a IS_NOTIFICATION=1 ile eklenen bir kayıt
 * ise doğrudan sistemin kendi MediaProvider'ı üzerinden geldiği için her
 * cihazda güvenilir şekilde okunabiliyor — ayrıca Android 10+ scoped
 * storage sayesinde uygulamanın kendi eklediği kayıt için WRITE_EXTERNAL_STORAGE
 * izni de gerekmiyor (mevcut Play Store izin sadeleştirmesiyle tutarlı).
 *
 * minSdk ne olursa olsun, bu akış sadece Android 10 (API 29) ve üzerinde
 * çalışır — daha eskisi aktif kullanıcı tabanında ihmal edilebilir düzeyde
 * kaldığından bilinçli olarak desteklenmiyor (bkz. UNSUPPORTED_VERSION).
 */
object AudioPicker {
    const val REQUEST_PICK_AUDIO = 4711
    private const val MAX_BYTES = 8L * 1024 * 1024 // 8 MB

    private var pendingResult: MethodChannel.Result? = null
    private var previewPlayer: MediaPlayer? = null

    fun pickAudioFile(activity: Activity, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            result.error("UNSUPPORTED_VERSION", "Android 10+ gerekli", null)
            return
        }
        if (pendingResult != null) {
            // Zaten bekleyen bir seçim varsa (çift tıklama vb.) sessizce yut.
            result.success(null)
            return
        }
        pendingResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            type = "audio/*"
            addCategory(Intent.CATEGORY_OPENABLE)
        }
        try {
            activity.startActivityForResult(intent, REQUEST_PICK_AUDIO)
        } catch (e: Exception) {
            pendingResult = null
            result.error("PICKER_UNAVAILABLE", e.message, null)
        }
    }

    /** MainActivity.onActivityResult'tan çağrılır. */
    fun handleActivityResult(
        context: Context,
        requestCode: Int,
        resultCode: Int,
        data: Intent?
    ): Boolean {
        if (requestCode != REQUEST_PICK_AUDIO) return false
        val result = pendingResult
        pendingResult = null
        if (result == null) return true

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null) // Kullanıcı iptal etti.
            return true
        }

        // Kopyalama (disk G/Ç) ana thread'i bloklamasın diye arka planda
        // yapılır; MethodChannel sonucu yalnızca ana thread'e postlanarak
        // döndürülür (Flutter bunu zorunlu kılar).
        val sourceUri = data.data!!
        val mainHandler = Handler(Looper.getMainLooper())
        Thread {
            try {
                val picked = saveToMediaStore(context, sourceUri)
                mainHandler.post { result.success(picked) }
            } catch (e: TooLargeException) {
                mainHandler.post { result.error("TOO_LARGE", e.message, null) }
            } catch (e: Exception) {
                mainHandler.post { result.error("SAVE_FAILED", e.message, null) }
            }
        }.start()
        return true
    }

    private class TooLargeException(message: String) : Exception(message)

    private fun saveToMediaStore(context: Context, sourceUri: Uri): Map<String, Any> {
        val resolver = context.contentResolver

        var displayName = "ozel_ses"
        var size = -1L
        resolver.query(sourceUri, null, null, null, null)?.use { cursor: Cursor ->
            if (cursor.moveToFirst()) {
                val nameIdx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (nameIdx >= 0) displayName = cursor.getString(nameIdx) ?: displayName
                val sizeIdx = cursor.getColumnIndex(OpenableColumns.SIZE)
                if (sizeIdx >= 0) size = cursor.getLong(sizeIdx)
            }
        }
        // Boyut sağlayıcı tarafından biliniyorsa (size > 0) ve zaten limit
        // üstündeyse kopyalamaya bile gerek yok; bilinmiyorsa (-1/0) kopyalama
        // sırasında akış bazlı da kontrol ediliyor (aşağıda).
        if (size > MAX_BYTES) {
            throw TooLargeException("Dosya $MAX_BYTES bayttan büyük")
        }

        val mime = context.contentResolver.getType(sourceUri) ?: guessMime(displayName)

        val values = ContentValues().apply {
            put(MediaStore.Audio.Media.DISPLAY_NAME, displayName)
            put(MediaStore.Audio.Media.MIME_TYPE, mime)
            put(MediaStore.Audio.Media.IS_NOTIFICATION, 1)
            put(MediaStore.Audio.Media.IS_MUSIC, 0)
            put(MediaStore.Audio.Media.IS_ALARM, 0)
            put(MediaStore.Audio.Media.IS_RINGTONE, 0)
            put(
                MediaStore.Audio.Media.RELATIVE_PATH,
                Environment.DIRECTORY_NOTIFICATIONS + "/Murakabe"
            )
            put(MediaStore.Audio.Media.IS_PENDING, 1)
        }

        val collection = MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val insertedUri = resolver.insert(collection, values)
            ?: throw Exception("MediaStore kaydı oluşturulamadı")

        var writtenBytes = 0L
        try {
            resolver.openOutputStream(insertedUri)?.use { out ->
                resolver.openInputStream(sourceUri)?.use { input ->
                    val buffer = ByteArray(16 * 1024)
                    while (true) {
                        val read = input.read(buffer)
                        if (read == -1) break
                        writtenBytes += read
                        if (writtenBytes > MAX_BYTES) {
                            throw TooLargeException("Dosya $MAX_BYTES bayttan büyük")
                        }
                        out.write(buffer, 0, read)
                    }
                }
            }
        } catch (e: TooLargeException) {
            resolver.delete(insertedUri, null, null)
            throw e
        } catch (e: Exception) {
            resolver.delete(insertedUri, null, null)
            throw e
        }

        values.clear()
        values.put(MediaStore.Audio.Media.IS_PENDING, 0)
        resolver.update(insertedUri, values, null, null)

        return mapOf(
            "uri" to insertedUri.toString(),
            "name" to displayName,
            "size" to writtenBytes
        )
    }

    private fun guessMime(name: String): String = when {
        name.endsWith(".mp3", true) -> "audio/mpeg"
        name.endsWith(".wav", true) -> "audio/wav"
        name.endsWith(".m4a", true) -> "audio/mp4"
        name.endsWith(".ogg", true) -> "audio/ogg"
        else -> "audio/*"
    }

    // ── Silme ────────────────────────────────────────────────────────────
    fun deleteCustomAudio(context: Context, uriString: String) {
        try {
            context.contentResolver.delete(Uri.parse(uriString), null, null)
        } catch (_: Exception) {
            // Kayıt zaten yoksa/erişilemiyorsa sessizce geç — Dart tarafı
            // uygulama içi referansı zaten temizleyecek.
        }
    }

    // ── Uygulama içi önizleme ───────────────────────────────────────────
    fun preview(context: Context, uriString: String) {
        stopPreview()
        try {
            previewPlayer = MediaPlayer().apply {
                setDataSource(context, Uri.parse(uriString))
                setOnPreparedListener { it.start() }
                setOnCompletionListener { stopPreview() }
                setOnErrorListener { _, _, _ -> stopPreview(); true }
                prepareAsync()
            }
        } catch (_: Exception) {
            stopPreview()
        }
    }

    fun stopPreview() {
        previewPlayer?.let {
            try {
                if (it.isPlaying) it.stop()
                it.release()
            } catch (_: Exception) {
            }
        }
        previewPlayer = null
    }
}
