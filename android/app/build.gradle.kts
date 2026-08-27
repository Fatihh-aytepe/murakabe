import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.murakabe.app"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.murakabe.app"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    // key.properties gizli bir dosyadır ve repoya dahil edilmez (bkz. .gitignore).
    // Temiz bir klonda bu dosya yoksa release imzalama bilgisi bulunmaz; bu durumda
    // önceden "as String" ile zorunlu cast yapıldığından Gradle configuration
    // aşamasında (build türü seçilmeden önce) çöküyordu. Artık dosya yoksa release
    // derlemesi debug imzasına düşüyor, böylece `flutter run`/`flutter build apk`
    // temiz bir klonda da çalışır. Play Store'a yüklenecek gerçek bir release için
    // `android/key.properties` dosyasını oluşturup imzalama bilgilerini girin
    // (bkz. README.md).
    val hasSigningConfig = keystorePropertiesFile.exists()

    signingConfigs {
        create("release") {
            if (hasSigningConfig) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = if (hasSigningConfig) {
                signingConfigs.getByName("release")
            } else {
                // key.properties yok: debug imzasıyla derle (yalnızca yerel/test
                // amaçlı). Play Store'a yüklenecek APK/AAB için gerçek bir
                // imzalama yapılandırması şart.
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    implementation("androidx.multidex:multidex:2.0.1")
}
