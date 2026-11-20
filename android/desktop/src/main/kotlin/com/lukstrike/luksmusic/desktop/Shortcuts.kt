// Shortcuts.kt — the keys the app answers to. In desktop mode SteamOS turns the Deck's buttons into keys (the
// suggested Steam Input layout in README.md: D-pad = arrows, A = Enter, B = Esc, X = Space, Y = Tab, L1/R1 =
// Page Up/Down, ☰ = S, ⧉ = F11), so every screen works from the buttons as well as by touch.
package com.lukstrike.luksmusic.desktop

import androidx.compose.ui.input.key.Key

enum class Shortcut {
    BACK, FULLSCREEN, SETTINGS, SWITCH_SCREEN,
    LEFT, RIGHT, UP, DOWN, ENTER, SPACE, PAGE_UP, PAGE_DOWN,
    HINT, REPEAT, HAND_RIGHT, HAND_LEFT, HAND_BOTH, NOTES, ORDER,
    METRONOME, VIEW, TEMPO_UP, TEMPO_DOWN, IMPORT, OPEN_STUDY, DELETE,
}

object Shortcuts {
    fun of(key: Key): Shortcut? = when (key) {
        Key.Escape, Key.Back, Key.Backspace -> Shortcut.BACK
        Key.F11 -> Shortcut.FULLSCREEN
        Key.S, Key.Menu, Key.F10 -> Shortcut.SETTINGS
        Key.Tab -> Shortcut.SWITCH_SCREEN
        Key.DirectionLeft -> Shortcut.LEFT
        Key.DirectionRight -> Shortcut.RIGHT
        Key.DirectionUp -> Shortcut.UP
        Key.DirectionDown -> Shortcut.DOWN
        Key.Enter, Key.NumPadEnter -> Shortcut.ENTER
        Key.Spacebar -> Shortcut.SPACE
        Key.PageUp -> Shortcut.PAGE_UP
        Key.PageDown -> Shortcut.PAGE_DOWN
        Key.H -> Shortcut.HINT
        Key.R -> Shortcut.REPEAT
        Key.One, Key.NumPad1 -> Shortcut.HAND_RIGHT
        Key.Two, Key.NumPad2 -> Shortcut.HAND_LEFT
        Key.Three, Key.NumPad3 -> Shortcut.HAND_BOTH
        Key.N -> Shortcut.NOTES
        Key.O -> Shortcut.ORDER
        Key.M -> Shortcut.METRONOME
        Key.V -> Shortcut.VIEW
        Key.Plus, Key.Equals, Key.NumPadAdd -> Shortcut.TEMPO_UP
        Key.Minus, Key.NumPadSubtract -> Shortcut.TEMPO_DOWN
        Key.I -> Shortcut.IMPORT
        Key.P -> Shortcut.OPEN_STUDY
        Key.Delete -> Shortcut.DELETE
        else -> null
    }
}
