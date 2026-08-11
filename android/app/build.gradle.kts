import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Apply Google Services only once google-services.json is present, so the
// project still builds before Firebase credentials are dropped in.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

val keyProperties = Properties().apply {
    val keyPropsFile = rootProject.file("key.properties")
    if (keyPropsFile.exists()) load(keyPropsFile.reader())
}
val hasKeystore = rootProject.file("key.properties").exists()

android {
    namespace = "com.citadelclash.citadelclashgame"
    // compileSdk pinned to 36: some plugins ship compileSdk=34 while their
    // transitive deps require 36 (see gray_part_pitfalls §2).
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications 18+ needs java.time desugaring.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.citadelclash.citadelclashgame"
        // API 26 (Android 8.0) is the lowest the Firebase/AppsFlyer stack
        // supports; keep it here, don't raise without cause.
        minSdk = 26
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keyProperties["keyAlias"] as String?
            keyPassword = keyProperties["keyPassword"] as String?
            storeFile = keyProperties["storeFile"]?.let { file("$it") }
            storePassword = keyProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
