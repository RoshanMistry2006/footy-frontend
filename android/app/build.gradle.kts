plugins {
    id("com.android.application")
    // ✅ Firebase / Google services plugin
    id("com.google.gms.google-services")
    id("kotlin-android")
    // ✅ Flutter plugin (must come last)
    id("dev.flutter.flutter-gradle-plugin")
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

    // ✅ Add debug signing config so builds never fail for missing keystore
    signingConfigs {
        getByName("debug") {
            storeFile = file(
                System.getenv("ANDROID_DEBUG_KEYSTORE")
                    ?: "${System.getProperty("user.home")}/.android/debug.keystore"
            )
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }

    defaultConfig {
        // ✅ Must match your Firebase package name
        applicationId = "com.balltalk.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // ✅ Prevent Firebase method-limit issues
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // ✅ Uses debug signing for now (fine for dev builds)
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
