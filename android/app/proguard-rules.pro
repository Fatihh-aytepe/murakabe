# R8/ProGuard kuralları — isMinifyEnabled=true olunca devreye girer.
# Çoğu modern Flutter eklentisi (firebase_*, flutter_local_notifications,
# image_picker, permission_handler, path_provider, audioplayers, geolocator,
# timezone) kendi consumer-rules.pro dosyasını AAR içinde taşır ve Android
# Gradle Plugin bunları otomatik birleştirir — bu yüzden liste kısa tutuldu.
# Aşağıdakiler, reflection ile erişilen ve R8'in yanlışlıkla silebileceği
# sınıflar için ek bir güvenlik ağı (yaygın, genel Flutter+Firebase kuralları).

# Firebase / Google Play Services — Firestore, Auth, Storage, Remote Config
# reflection ile model/serileştirme sınıflarına erişebiliyor.
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# flutter_local_notifications — bildirim receiver/servisleri manifest'ten
# reflection ile çağrılıyor.
-keep class com.dexterous.** { *; }

# Flutter'ın deferred component / Play Core altyapısı (bazı Flutter
# sürümlerinde split install için kullanılıyor).
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Genel: annotation/generic tip bilgisi Firebase serileştirmesi için gerekli.
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# ── ÖNEMLİ ─────────────────────────────────────────────────────────────────
# Bu kurallar derleme zamanında hata vermez ama minify açıkken bazı
# çalışma-zamanı hataları (ör. ClassNotFoundException, ekran açılmıyor,
# bildirim gelmiyor) SADECE gerçek cihazda release build test edilince
# ortaya çıkar. `flutter build appbundle --release` sonrası MUTLAKA gerçek
# cihazda kayıt/giriş, bildirimler ve widget'ları test et — bir şey
# bozulursa hatayı (adb logcat çıktısıyla birlikte) paylaş, eksik kuralı
# buraya ekleriz.
