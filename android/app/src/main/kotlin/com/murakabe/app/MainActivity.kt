package com.murakabe.app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val widgetsChannel = "com.murakabe.app/widgets"
    private val audioChannel = "com.murakabe.app/audio"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Dart tarafı (WidgetBridgeService) namaz vakti/zikir/günlük içerik
        // verisini SharedPreferences'a yazdıktan sonra bu kanaldan
        // "refreshAllWidgets" çağırır — biz de üç widget sağlayıcısına da
        // APPWIDGET_UPDATE broadcast'i göndeririz, onUpdate() taze veriyi
        // okuyup RemoteViews'i yeniden çizer.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, widgetsChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "refreshAllWidgets" -> {
                        WidgetRefresher.refreshAll(applicationContext)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }

        // Kullanıcının kendi alarm sesini seçip cihazına eklemesi
        // (bkz. AlarmService.pickAndAddCustomSound / AudioPicker.kt).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, audioChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickAndSaveAudio" -> AudioPicker.pickAudioFile(this, result)
                    "deleteCustomAudio" -> {
                        val uri = call.argument<String>("uri")
                        if (uri == null) {
                            result.error("BAD_ARGS", "uri eksik", null)
                        } else {
                            AudioPicker.deleteCustomAudio(applicationContext, uri)
                            result.success(null)
                        }
                    }
                    "previewAudio" -> {
                        val uri = call.argument<String>("uri")
                        if (uri == null) {
                            result.error("BAD_ARGS", "uri eksik", null)
                        } else {
                            AudioPicker.preview(applicationContext, uri)
                            result.success(null)
                        }
                    }
                    "stopPreviewAudio" -> {
                        AudioPicker.stopPreview()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        AudioPicker.handleActivityResult(applicationContext, requestCode, resultCode, data)
    }

    override fun onDestroy() {
        AudioPicker.stopPreview()
        super.onDestroy()
    }
}
