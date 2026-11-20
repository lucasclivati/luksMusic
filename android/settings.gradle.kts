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
// (left out with -Pluksmusic.desktopOnly=true: the desktop app's Linux build runs in a container without the Android SDK)
if (providers.gradleProperty("luksmusic.desktopOnly").orNull != "true") include(":app")
// desktop: the Linux desktop app for the Steam Deck (Compose Multiplatform for Desktop), sharing core
include(":desktop")
