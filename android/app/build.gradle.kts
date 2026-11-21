plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.ufipeek.widget"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.ufipeek.widget"
        minSdk = 26
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
    }

    // 固定签名：以后更新可以直接覆盖安装
    signingConfigs {
        create("release") {
            storeFile = file("ufipeek.jks")
            storePassword = "ufipeek123"
            keyAlias = "ufipeek"
            keyPassword = "ufipeek123"
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            signingConfig = signingConfigs.getByName("release")
        }
        debug {
            signingConfig = signingConfigs.getByName("release")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
    lint {
        abortOnError = false
        checkReleaseBuilds = false
    }
}
