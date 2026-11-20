# luksMusic for the Steam Deck (Linux desktop)

The desktop version of luksMusic, made for one setup: the **Steam Deck propped on the piano's music stand**, a
**USB MIDI keyboard or digital piano** plugged into the Deck, and the scores played on the real keys. The screen shows
big notation and big buttons; everything works by touch **and** by the Deck's buttons.

Built with **Compose Multiplatform for Desktop** and sharing `:core` with the Android app: the same MusicXML parser,
reading drill rules, Modo Estudo engine, playback clock, MIDI parsing and synthesized piano (`core/audio/synth`).

## What it does

| Screen | |
|---|---|
| **Library** | The bundled samples (`luksMusic/SampleScores`, shared with iOS and Android) and the scores you import (`.musicxml`, `.xml`, `.mxl`). Big cards, each opening the drill or Modo Estudo. |
| **Sight-Reading** (Treino de leitura) | A few notes at a time, on one staff (right or left hand) or a grand staff (both). Choose the hand, notes (one, two, full), order (in order or random) and notes per passage. Each key of the MIDI keyboard is checked: the note turns green, a wrong key shows faintly in red and is named, three misses show the answer. Previous / repeat / listen / hint / next. Where you stopped is remembered per score, hand and notes. |
| **Practice Mode** (Modo Estudo) | Falling notes over a key strip, or a scrolling grand staff. Modes: wait for me (guided), play along, right hand, left hand, slow. Tempo, play/pause/stop, metronome, accuracy and streak. |
| **Settings** (Ajustes) | MIDI keyboard status ("Teclado conectado"), search again, whether the app sounds the keyboard's notes, volume, full screen, and the list of keys. |

Switch between the drill and Modo Estudo with **Tab** (Y) or the button at the top of either screen. The language
follows the system: Portuguese (with solfège note names, Dó Ré Mi) when the locale is `pt`, English otherwise.
`LUKSMUSIC_LANG=pt` (or `en`) overrides it.

Files live in `~/.local/share/luksMusic` (`$XDG_DATA_HOME/luksMusic`): `settings.json` and `scores/` (each import as
JSON with its MusicXML beside it, like the Android app).

## Install on the Steam Deck

1. Copy `luksMusic-linux-x64.tar.gz` to the Deck (USB stick, KDE Connect, `scp`, or download it in desktop mode).
2. In **desktop mode**, open Konsole and run:
   ```sh
   mkdir -p ~/Applications
   tar -xzf ~/Downloads/luksMusic-linux-x64.tar.gz -C ~/Applications
   ~/Applications/luksMusic/install.sh      # adds luksMusic to the application menu
   ```
   The app brings its own Java runtime: nothing else to install, and SteamOS updates don't touch it.
3. **Add it to Steam**: Steam (desktop mode) → *Games* → *Add a Non-Steam Game to My Library* → tick **luksMusic**
   (or *Browse* to `~/Applications/luksMusic/bin/luksMusic`). It then starts from Game Mode too.
4. Plug the MIDI keyboard into the Deck's USB-C port (through a hub or a USB-C adapter if needed). It is found within
   two seconds, also when plugged in after the app started; the top bar turns green: **Keyboard connected / Teclado
   conectado**. Class-compliant USB MIDI keyboards need no driver (ALSA).

Run it from Konsole to see messages: `~/Applications/luksMusic/bin/luksMusic`. Opening it in a window instead of
full screen: `LUKSMUSIC_WINDOWED=1 ~/Applications/luksMusic/bin/luksMusic` (or F11).

**Sound**: a USB controller keyboard has no speakers, so the app plays its notes with the built-in piano (on by
default). With a digital piano that has its own speakers, turn off *Play the MIDI keyboard's notes* in Settings. The
sustain pedal is followed.

## Keys and Deck buttons

Every screen works with touch and with these keys:

| Key | Library | Sight-Reading | Practice Mode |
|---|---|---|---|
| ← → ↑ ↓ | move the selection | ← → previous / next passage | ← → previous / next measure, ↑ ↓ tempo |
| Enter | open the drill | next passage | start / pause |
| Space | open the drill | listen to the passage | start / pause |
| Tab | open Modo Estudo | switch to Modo Estudo | switch to the drill |
| Page Up / Down | | previous / next passage | previous / next measure |
| H, R | | hint, repeat the passage | R stops |
| 1 2 3, N, O | | hand (right, left, both), notes, order | |
| M, V, + − | | | metronome, view, tempo |
| I, P, Delete | import, open Modo Estudo, delete an import | | |
| S | settings | settings | settings |
| Esc / Backspace | close a dialog | back to the library | back to the library |
| F11 | full screen on/off | | |

### Recommended controller layout (Steam Input)

In desktop mode SteamOS maps the Deck's controls to a keyboard and mouse. For the best experience give luksMusic its own
layout: in Steam, open luksMusic → ⚙ → *Controller Layout* → *Edit* (start from the **Keyboard (WASD) and Mouse**
template) and set:

| Deck button | Key |
|---|---|
| D-pad | Arrow keys |
| A | Enter |
| B | Escape |
| X | Space |
| Y | Tab |
| L1 / R1 | Page Up / Page Down |
| Menu ☰ | S |
| View ⧉ | F11 |
| Right trackpad / touch screen | Mouse (already the default) |

With that, the Deck can sit on the music stand and be driven from the buttons: A for the next passage, X to hear it,
L1/R1 to go back and forth, Y to switch to Modo Estudo, X to start it.

## Build

From `android/` (JDK 17+; Android Studio's bundled JBR works):

```sh
./gradlew :desktop:run                 # run on this computer (Windows, macOS or Linux)
./gradlew :desktop:test                # unit tests (drill and Modo Estudo controllers, MIDI, library, settings)
./gradlew :desktop:screenshots         # renders the screens at 1280×800 into desktop/build/screens/
./gradlew :desktop:packageDeckTarball  # Linux only: build/dist/luksMusic-linux-x64.tar.gz
```

`jpackage` only makes Linux app images on Linux, so from Windows or macOS build the Deck package in Docker (from the
repository root):

```sh
docker run --rm -v "$PWD":/src -v luksmusic-gradle:/root/.gradle eclipse-temurin:21-jdk \
    sh /src/android/desktop/packaging/build-linux.sh
```

(On Git Bash for Windows prefix it with `MSYS_NO_PATHCONV=1` and use `"$(pwd -W)"`.) The script copies the sources
into the container, builds without the Android app (`-Pluksmusic.desktopOnly=true`, no Android SDK needed), runs the
tests, and writes `android/desktop/build/dist/luksMusic-linux-x64.tar.gz`: the `luksMusic/` app folder with its own
runtime, `luksMusic.desktop`, `install.sh` and the icon.

### Code

```
desktop/src/main/kotlin/com/lukstrike/luksmusic/desktop/
├── Main.kt, App.kt          window (full screen, F11), screens, MIDI and key routing
├── Shortcuts.kt             keys (and Deck buttons) → actions
├── SettingsPanel.kt         Ajustes
├── audio/                   DesktopAudio (core synth → javax.sound.sampled line, ~20 ms buffer), Metronome
├── midi/                    MidiInput (javax.sound.midi, hot-plug every 2 s)
├── data/                    ScoreLibrary (samples + imports), settings in ~/.local/share/luksMusic
├── drill/                   DrillController (ReadingTrainerViewModel without Android), DrillScreen
├── study/                   StudyController (PracticeViewModel without Android), falling notes, staff strip
└── ui/                      theme, strings (en/pt), staff and glyphs (adapted from the Android app), key strip
```

## Limitations and future work

- **Not included yet**: accounts and cloud sync (Firebase), the engraved score player (OpenSheetMusicDisplay needs a
  browser engine), the tuner, the score editor, the lessons (Aprender) and practice history.
- The staves are drawn by the app (the drill's staff and Modo Estudo's strip): no beams, ties or slurs, one stem per
  chord per staff; fine for reading notes, not a full engraving.
- Audio latency depends on the Deck's audio stack (PipeWire); the line buffer is ~20 ms, plus the system's. With a
  digital piano, its own sound is always the fastest.
- Only Linux x86-64 is packaged (the Steam Deck); the app also runs with `./gradlew :desktop:run` on Windows/macOS.
- The window's keys are read while it has focus; the Steam overlay or a Steam Input layout that sends other keys can
  change what a button does.
- The language follows the system locale (no in-app switch yet).
