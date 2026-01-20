import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // ✅ Firebase / Google services plugin
    id("com.google.gms.google-services")
    id("kotlin-android")
    // ✅ Flutter plugin (must come last)
    id("dev.flutter.flutter-gradle-plugin")
}

// ---- Load keystore properties (android/key.properties) ----
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")

val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    FileInputStream(keystorePropertiesFile).use { fis ->
        keystoreProperties.load(fis)
    }
}

android {
    namespace = "com.balltalk.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    signingConfigs {
        // ✅ Debug signing (keep)
        getByName("debug") {
            storeFile = file(
                System.getenv("ANDROID_DEBUG_KEYSTORE")
                    ?: "${System.getProperty("user.home")}/.android/debug.keystore"
            )
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }

        // ✅ Release signing (NEW)
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storePassword = keystoreProperties["storePassword"] as String

                val storeFilePath = keystoreProperties["storeFile"] as String
                storeFile = rootProject.file(storeFilePath)
            }
        }
    }

    defaultConfig {
        applicationId = "com.balltalk.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // ✅ IMPORTANT: Use release signing for Play upload
            // If key.properties is missing, fall back to debug to avoid hard build failure.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // Optional but common:
            // isMinifyEnabled = false
            // isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
