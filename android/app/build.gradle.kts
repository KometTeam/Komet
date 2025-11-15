import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.gwid.app.gwid"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    sourceSets {
        getByName("main") {
            jniLibs.srcDirs("src/main/jniLibs")
        }
    }

    defaultConfig {
        applicationId = "com.gwid.app.gwid"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
        }
    }

    val keyPropertiesFile = rootProject.file("key.properties")
    val keyProperties = Properties()
    
    signingConfigs {
        create("release") {
            val envStoreFile = System.getenv("RELEASE_STORE_FILE")
            val envStorePassword = System.getenv("RELEASE_STORE_PASSWORD")
            val envKeyAlias = System.getenv("RELEASE_KEY_ALIAS")
            val envKeyPassword = System.getenv("RELEASE_KEY_PASSWORD")

            if (envStoreFile != null && envStorePassword != null && 
                envKeyAlias != null && envKeyPassword != null) {
                storeFile = file(envStoreFile)
                storePassword = envStorePassword
                keyAlias = envKeyAlias
                keyPassword = envKeyPassword
            } else if (keyPropertiesFile.exists()) {
                keyProperties.load(FileInputStream(keyPropertiesFile))
                storeFile = file(keyProperties["storeFile"] as String? ?: "")
                storePassword = keyProperties["storePassword"] as String? ?: ""
                keyAlias = keyProperties["keyAlias"] as String? ?: ""
                keyPassword = keyProperties["keyPassword"] as String? ?: ""
            }
            
        }
    }

    buildTypes {
        getByName("release") {
            // Only use release signing if keys are available
            if (file(keyPropertiesFile).exists() || 
                System.getenv("RELEASE_STORE_FILE") != null) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"), 
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
