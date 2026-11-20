pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "luksMusic"

// core: pure Kotlin (models, MusicXML, pitch detection, lessons) — runs on the JVM, tested without a device
include(":core")
// app: the Android app (Compose screens, audio, MIDI, storage, Firebase)
include(":app")
