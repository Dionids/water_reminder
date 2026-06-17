pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

// Авто-поиск SDK: если wear/local.properties нет, копируем из android/local.properties
run {
    val wearLocalProps = file("local.properties")
    if (!wearLocalProps.exists()) {
        val androidLocalProps = file("../android/local.properties")
        if (androidLocalProps.exists()) {
            val props = java.util.Properties()
            androidLocalProps.inputStream().use { props.load(it) }
            val sdkDir = props.getProperty("sdk.dir")
                ?: System.getenv("ANDROID_HOME")
                ?: System.getenv("ANDROID_SDK_ROOT")
            val ndkDir = props.getProperty("ndk.dir")
            if (sdkDir != null) {
                wearLocalProps.writeText(buildString {
                    appendLine("sdk.dir=${sdkDir.replace("\\", "\\\\")}")
                    if (ndkDir != null) appendLine("ndk.dir=${ndkDir.replace("\\", "\\\\")}")
                })
            }
        }
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.1.0" apply false
}

rootProject.name = "wear"
