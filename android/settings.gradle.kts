// File: android/settings.gradle.kts
// This is the final, most robust version.

pluginManagement {
    repositories {
        // مخزن‌های داخلی یا تحریم‌دور
        maven { url 'https://maven.aliyun.com/repository/google' }
        maven { url 'https://maven.aliyun.com/repository/central' }

        // مخزن‌های رسمی
        google()
        mavenCentral()
        gradlePluginPortal()
        maven { url 'https://storage.googleapis.com/download.flutter.io' }
    }
}


dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        // این خط هم برای برخی پکیج‌ها اینجا لازم است
        maven {
            url = uri("https://storage.googleapis.com/download.flutter.io")
        }
    }
}

rootProject.name = "android"
include(":app")
