plugins {
    id("com.android.application")
    id("com.google.gms.google-services") // Firebase plugin
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.poling"
    compileSdk = flutter.compileSdkVersion

    // Ganti baris ini untuk menggunakan versi NDK yang dibutuhkan Firebase
    ndkVersion = "27.0.12077973"

    defaultConfig {
        applicationId = "com.example.poling"
        
        // Pastikan minSdk minimal 23
        // Meskipun kamu sudah pakai 31, kita ubah ke 23 agar lebih jelas
        minSdk = 23
        
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_21
    }

    kotlinOptions {
        jvmTarget = "21"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}