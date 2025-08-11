// File: android/settings.gradle.kts
// This is the final, most robust version.

pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
        // این خط به طور صریح آدرس پلاگین فلاتر را اضافه می‌کند
        maven {
            url = uri("https://storage.googleapis.com/download.flutter.io")
        }
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
