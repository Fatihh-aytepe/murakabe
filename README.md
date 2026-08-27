# Murakabe

Günlük İslami İbadet Hatırlatıcı (Flutter + Firebase).

Bu depo, temiz bir klonun **derlenmesi için gereken bazı dosyaları kasıtlı
olarak içermez** (Firebase kimlik bilgileri, imzalama anahtarı gibi gizli
veriler). Aşağıdaki adımlar olmadan proje derlenmez.

## Gereken sürümler

`pubspec.lock` şu sürümlere kilitlenmiştir; daha eski bir Flutter/Dart ile
`flutter pub get` görünürde geçse bile derleme sırasında hatalar alabilirsiniz:

- Flutter >= 3.38.4
- Dart SDK >= 3.10.3
- Android `compileSdk`/`targetSdk` 36, NDK 28.2.13676358 (bkz.
  `android/app/build.gradle.kts` — Flutter/Android Studio kurulumunuzda bu NDK
  sürümü yoksa Android Studio SDK Manager'dan indirin)

Sürümünüzü kontrol edin: `flutter --version`. FVM kullanıyorsanız
`fvm install 3.38.4 && fvm use 3.38.4` ile sabitleyebilirsiniz.

## 1. Bağımlılıklar

```bash
flutter pub get
```

## 2. Firebase yapılandırması (zorunlu)

Proje `firebase_core`, `firebase_auth`, `cloud_firestore`,
`firebase_remote_config` ve `firebase_storage` kullanır. İki dosya elle
oluşturulmalıdır; ikisi de `.gitignore` içinde olduğu için repoya dahil
değildir:

1. **`lib/firebase_options.dart`** — `lib/firebase_options.dart.example`
   dosyasını kopyalayıp kendi Firebase projenizin değerleriyle doldurun:

   ```bash
   cp lib/firebase_options.dart.example lib/firebase_options.dart
   ```

   Değerleri [Firebase Console](https://console.firebase.google.com) →
   Proje Ayarları → "Uygulamalarınız" bölümünden alın, ya da
   `flutterfire configure` komutunu çalıştırıp dosyayı otomatik ürettirin
   (FlutterFire CLI kurulu olmalı: `dart pub global activate flutterfire_cli`).

2. **`android/app/google-services.json`** — Firebase Console → Proje
   Ayarları → Android uygulaması bölümünden indirip bu yola koyun.
   Paket adı `com.murakabe.app` ile eşleşmelidir (bkz.
   `android/app/build.gradle.kts` → `applicationId`).

Bu iki dosya olmadan `Firebase.initializeApp()` çağrısı (`lib/main.dart`)
istisna fırlatır ve uygulama açılışta çöker.

### Firestore kuralları ve indeksleri

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
```

`firestore.indexes.json` ve `firestore.rules` bu depoda mevcuttur; Firebase
projenize deploy etmeniz gerekir (aksi halde bileşik sorgular
`FAILED_PRECONDITION` hatası verir).

### App Check (kötüye kullanım/bulk istek koruması)

`lib/main.dart`, `FirebaseAppCheck.instance.activate()` çağırır — bu,
istemci kodunu içerir ama tek başına HİÇBİR isteği engellemez; Firebase
Console tarafında ayrıca kurulum gerekir:

1. [Firebase Console](https://console.firebase.google.com) → projeniz →
   **App Check** sekmesi → Android uygulamasını **Play Integrity**
   sağlayıcısıyla kaydedin.
2. Debug/emulator derlemesinde `AndroidProvider.debug` kullanılır; ilk
   çalıştırmada konsola (`adb logcat` veya `flutter run` çıktısı) bir debug
   token yazdırılır — bunu App Check → Apps → "Manage debug tokens"
   kısmına ekleyin, aksi halde debug derlemesinin istekleri App Check
   metriklerinde "geçersiz" görünür (enforce kapalıyken bu isteği
   ENGELLEMEZ).
3. **Enforce'u (Firestore/Storage/Auth için) bu güncelleme Play Store'a
   çıkıp kullanıcıların büyük kısmı güncellemeden ÖNCE AÇMAYIN** — aksi
   halde App Check'i içermeyen eski sürümü kullanan tüm kullanıcıların
   istekleri reddedilir. Önce Console'daki "İstek metrikleri" grafiğinde
   geçerli token oranının yükseldiğini doğrulayın, ancak sonra
   Enforce'u açın.

## 3. Android imzalama (yalnızca release build için)

`android/app/build.gradle.kts`, `android/key.properties` dosyası yoksa
release derlemesini otomatik olarak **debug imzasına düşürür** — yani
`flutter run` ve `flutter build apk --debug` bu dosya olmadan da çalışır.

Play Store'a yüklenecek gerçek bir release APK/AAB için:

1. Bir keystore oluşturun (yoksa):

   ```bash
   keytool -genkey -v -keystore ~/murakabe-release.jks -keyalg RSA \
     -keysize 2048 -validity 10000 -alias murakabe
   ```

2. `android/key.properties` dosyasını oluşturun (bu dosya da `.gitignore`
   içindedir, repoya eklenmez):

   ```properties
   storePassword=<keystore şifresi>
   keyPassword=<key şifresi>
   keyAlias=murakabe
   storeFile=/mutlak/yol/murakabe-release.jks
   ```

## 4. Çalıştırma

```bash
flutter pub get
flutter run                 # debug, bağlı cihaz/emülatörde
flutter build apk --release # release APK (key.properties varsa gerçek imza ile)
```

## 5. Testler

```bash
flutter test
```

Not: Şu an yalnızca ödül/rozet servislerini kapsayan sınırlı bir test seti
mevcuttur (`test/services`); auth, Firestore kuralları, hesap değiştirme,
not senkronizasyonu, widget ve bildirim akışları için test bulunmuyor. Her
push/PR'da `flutter analyze` + `flutter test` çalıştıran temel bir CI
(`.github/workflows/flutter_ci.yml`) mevcut, ancak bu yalnızca statik analiz
ve mevcut (dar kapsamlı) testleri doğrular — yukarıdaki eksik alanları
kapatmaz. Katkıda bulunurken yeni test eklemeniz teşvik edilir.

## Uygulama içi güncelleme (Remote Config)

Uygulama açılışta Firebase Remote Config'den şu anahtarları okur:

- `latest_version`, `apk_url`, `force_update` — mevcut davranış.
- `apk_sha256` (opsiyonel) — yayınlanan APK'nın SHA-256 özeti (hex).
  Doldurulursa, kullanıcı "Güncelle"ye bastığında uygulama dosyayı önce
  indirip özetini doğrular; eşleşmezse kurulum linki hiç açılmaz. Boş
  bırakılırsa doğrulama adımı atlanır (geriye dönük uyumlu davranış).
  Özeti hesaplamak için: `shasum -a 256 app-release.apk` (macOS/Linux) veya
  `certutil -hashfile app-release.apk SHA256` (Windows).

Not: Kurulum hâlâ kullanıcının tarayıcısı + Android'in kendi paket
yükleyicisi üzerinden yapılıyor (uygulama APK'yı kendi kurmuyor); bu yüzden
aynı imzayla imzalanmış bir güncelleme, önceki sürüm kaldırılmadan doğrudan
üzerine kurulabilir.

## iOS

iOS tarafı için `ios/Runner/GoogleService-Info.plist` ve ilgili Firebase iOS
uygulaması eklenmelidir; bu depoda şu an iOS için Firebase yapılandırması ve
bildirim (Darwin) kurulumu tamamlanmamıştır.
