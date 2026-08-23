import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
var isKeystoreValid = false

if (keystorePropertiesFile.exists()) {
    try {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
        val storePath = keystoreProperties.getProperty("storeFile")
        if (storePath != null) {
            val sFile = if (storePath.startsWith("/")) file(storePath) else rootProject.file(storePath)
            if (sFile.exists()) {
                isKeystoreValid = true
            }
        }
    } catch (e: Exception) {
        println("Keystore load notice: ${e.message}")
    }
}

android {
    namespace = "com.keyflow.keyflow_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.keyflow.keyflow_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (isKeystoreValid) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                val storePath = keystoreProperties.getProperty("storeFile")
                storeFile = if (storePath.startsWith("/")) file(storePath) else rootProject.file(storePath)
                storePassword = keystoreProperties.getProperty("storePassword")
            } else {
                initWith(getByName("debug"))
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
