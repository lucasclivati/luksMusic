# luksMusic for Android

The native Android version of luksMusic: **Kotlin + Jetpack Compose (Material 3)**, the Android counterpart of the
iOS app's Swift + SwiftUI. Both apps live in this repository and share the score renderer, the sample scores and the
Firebase backend.

## Requirements

- Android Studio (any recent version), or just a JDK 17+ and the Android SDK (platform 36)
- A device or emulator with Android 8.0 (API 26) or newer

## Build and run

Open the `android/` folder in Android Studio and press Run, or from a terminal:

```bash
cd android
./gradlew :app:installDebug          # build and install on the connected device/emulator
./gradlew :core:test                 # unit tests (MusicXML, pitch detection, lessons, practice scoring…)
./gradlew :app:assembleRelease       # release build (signed when keystore.properties exists, see below)
```

`local.properties` (not committed) points to the Android SDK; Android Studio writes it on first open.

## How the project is organized

```
android/
├── core/                      Pure Kotlin, no Android: runs and is tested on the JVM
│   └── com.lukstrike.luksmusic.core
│       ├── model/             Note, Measure, Score, Clef, PracticeSession, Tuning… (ports of luksMusic/Models)
│       ├── musicxml/          MusicXML parser/exporter, .mxl (zip)
│       ├── pitch/             YIN pitch detection, strike detection, tuner tracker
│       ├── playback/          Playback clock and note events built from a Score
│       ├── practice/          Note matching and scoring for Modo Estudo, MIDI message parsing
│       └── lessons/           Lessons, lesson catalog, reading drill
└── app/                       The Android app
    └── com.lukstrike.luksmusic
        ├── AppContainer.kt    The shared services (the iOS `.shared` singletons), made once
        ├── audio/             Piano synth (AudioTrack, low latency), metronome, microphone
        ├── midi/              External MIDI keyboards (android.media.midi, USB and Bluetooth)
        ├── account/           Firebase Auth + Firestore over REST (same backend as iOS)
        ├── data/              Score library, practice history, saved settings
        ├── ui/                Theme, navigation (tabs + routes), shared components (piano keyboard)
        └── feature/           One package per area, each with its own <Name>Graph.kt
            ├── learn/         Aprender: lessons, lesson player, reading drill
            ├── library/       Tocar: library, import, online catalog, editor
            ├── player/        Score player (OSMD in a WebView), playback
            ├── practice/      Modo Estudo: falling notes, feedback, stats
            ├── tuner/         Afinador (guitar and piano)
            └── account/       Login, Ajustes, Progresso
```

Rules of thumb that keep it easy to maintain:

- **Logic goes in `core`**, screens and Android I/O in `app`. Anything that can be tested without a phone (parsing,
  DSP, scoring, lessons) lives in `core` and has a unit test.
- **One feature, one package.** A feature registers its screens in its own `feature/<x>/<X>Graph.kt`; the routes used
  between features are in `ui/navigation/Routes.kt`. A new shared service is one line in `AppContainer.kt`.
- **Mirror the iOS names.** Kotlin files carry the same names as the Swift files they port (`PracticeViewModel`,
  `TunerPitchTracker`, `MusicXMLParser`…), so a change in one app is easy to find and repeat in the other.
- **Texts are never hardcoded.** English is the default (`res/values/strings_<feature>.xml`), Portuguese in
  `res/values-pt/`. Like on iOS, English shows for any device language other than Portuguese. The language can be
  changed in Ajustes and applies at once (per-app language, Android 13+, and AppCompat on older versions).

## Shared with the iOS app (not copied)

`app/build.gradle.kts` reads these folders directly as Android assets, so both apps always use the same files:

| Folder                    | What it is                                                    |
|---------------------------|---------------------------------------------------------------|
| `luksMusic/ScoreViewer/`  | `score-viewer.html` + OpenSheetMusicDisplay (score engraving) |
| `luksMusic/SampleScores/` | Public-domain pieces seeded into a new library                |

`score-viewer.html` talks to the native side through `window.webkit.messageHandlers.luks`; on Android a small shim
injected at document start provides that object, so the page itself stays identical for both apps. When you change
the page, test both apps.

The Firebase project (`luksmusic-5a7ff`), Firestore layout (`users/{uid}/scores/{id}`) and rules
(`firestore.rules`) are the same for both apps: a user sees the same synced library on iPhone and Android.

## Google sign-in setup (one time)

Google sign-in on Android uses Credential Manager, which needs, in the Firebase console of `luksmusic-5a7ff`:

1. **Project settings → Your apps → Add app → Android**, package `com.lukstrike.luksmusic`, with the SHA-1 of the
   debug key (`./gradlew :app:signingReport`) and later of the release/Play key.
2. **Authentication → Sign-in method → Google → Web SDK configuration**: copy the *Web client ID* into
   `WEB_CLIENT_ID` in `app/.../account/FirebaseConfig.kt`.

Until then e-mail/password and guest mode work, and the Google button explains it is not set up. Sign in with Apple
does not exist on Android; Apple users can use guest mode.

## Release signing

Create `android/keystore.properties` (never commit it, it is in `.gitignore`):

```properties
storeFile=../luksmusic-release.jks
storePassword=…
keyAlias=luksmusic
keyPassword=…
```

## Versioning

`versionName` / `versionCode` in `app/build.gradle.kts` follow the iOS `MARKETING_VERSION` /
`CURRENT_PROJECT_VERSION` in `project.yml`; bump both together.
