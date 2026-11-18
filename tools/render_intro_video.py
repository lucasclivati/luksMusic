#!/usr/bin/env python3
"""
Renders the luksMusic vertical full-screen animated lesson introduction (1080x1920, 60 fps)
using the app's PlayerTheme palette, Bravura engraving font, and Salamander Grand Piano samples.
"""

from __future__ import annotations

import argparse
import math
import pathlib
import subprocess
import tempfile
from dataclasses import dataclass

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
BRAVURA_FONT = ROOT / "web" / "Bravura.otf"
SALAMANDER_DIR = ROOT / "web" / "audio" / "salamander"

# PlayerTheme colors (RGB)
BG_COLOR = (11, 17, 32)          # #0b1120
PANEL_COLOR = (17, 24, 39)       # #111827
RAISED_COLOR = (30, 41, 59)      # #1e293b
BORDER_COLOR = (51, 65, 85)      # #334155
BLUE_COLOR = (59, 130, 246)      # #3b82f6
DEEP_BLUE = (37, 99, 235)        # #2563eb
CYAN_COLOR = (56, 189, 248)      # #38bdf8
ELECTRIC_CYAN = (0, 224, 255)
GREEN_COLOR = (74, 222, 128)     # #4ade80
STAFF_GREEN = (23, 158, 69)
STAFF_BLUE = (36, 107, 240)
INK_COLOR = (18, 23, 33)
TEXT_MAIN = (248, 250, 252)
TEXT_MUTED = (148, 163, 184)
WHITE = (255, 255, 255)

DURATION = 45.5


@dataclass
class Cue:
    start: float
    end: float
    phase: int
    phase_label: str
    title: str
    subtitle: str


@dataclass
class Press:
    idx: int
    token: str
    midi: int
    pos: int
    col: int
    onset: float
    hold: float
    spawns: bool
    callout: str


def build_cues(lang: str) -> list[Cue]:
    if lang == "en":
        return [
            Cue(0.0, 4.2, 1, "THE STAFF", "How sheet music begins",
                "Sheet music starts with 5 horizontal lines, always counted from the bottom up."),
            Cue(4.2, 8.0, 1, "THE STAFF", "Lines and spaces are steps",
                "Between the lines sit 4 spaces. Every line and every space acts as one step in pitch."),
            Cue(8.0, 14.3, 2, "MIDDLE C", "Where middle C lives",
                "Just left of the 2 black keys sits C. On the staff, it starts 2 steps below the 1st line, on a short extra line."),
            Cue(14.3, 17.8, 3, "UP THE LADDER", "D: climbing half a line",
                "Pressing the next white key moves the note up one step, right below the 1st line."),
            Cue(17.8, 21.2, 3, "UP THE LADDER", "E: on the 1st line",
                "One more key to the right and the note climbs another step, landing on the 1st line."),
            Cue(21.2, 24.6, 3, "UP THE LADDER", "F: in the 1st space",
                "The next key brings the note into the 1st space between the lines."),
            Cue(24.6, 28.0, 3, "UP THE LADDER", "G: on the 2nd line",
                "That's the line the curl of the treble clef wraps around — why it's called the G clef."),
            Cue(28.0, 34.8, 3, "UP THE LADDER", "A and B: space and line",
                "Going one key at a time, A lands in the 2nd space and B sits on the 3rd line, right in the middle."),
            Cue(34.8, 39.0, 4, "ONE OCTAVE", "C again: 1 octave!",
                "In the 3rd space we reach another C! From one C to the next is 8 white keys: one octave."),
            Cue(39.0, 45.5, 4, "ONE OCTAVE", "One note per key",
                "See how clear it is? Each neighboring white key climbs one step on the staff. Now it's your turn!"),
        ]
    return [
        Cue(0.0, 4.2, 1, "A PAUTA", "Como começa a partitura",
            "A partitura começa com 5 linhas horizontais, sempre contadas de baixo para cima."),
        Cue(4.2, 8.0, 1, "A PAUTA", "Linhas e espaços são degraus",
            "Entre as linhas ficam 4 espaços. Cada linha e cada espaço funciona como meio degrau de altura."),
        Cue(8.0, 14.3, 2, "O DÓ CENTRAL", "Onde nasce o Dó",
            "À esquerda das 2 teclas pretas fica o Dó. Na pauta, ele começa 2 degraus abaixo da 1ª linha, numa linha curta."),
        Cue(14.3, 17.8, 3, "SUBINDO A ESCADA", "Ré: subindo meia linha",
            "Apertando a próxima tecla branca, a nota sobe meio degrau e encosta logo abaixo da 1ª linha."),
        Cue(17.8, 21.2, 3, "SUBINDO A ESCADA", "Mi: em cima da 1ª linha",
            "Mais uma tecla para a direita e a nota sobe mais meia linha, pousando na 1ª linha."),
        Cue(21.2, 24.6, 3, "SUBINDO A ESCADA", "Fá: no 1º espaço",
            "A próxima tecla leva a nota para dentro do 1º espaço entre as linhas."),
        Cue(24.6, 28.0, 3, "SUBINDO A ESCADA", "Sol: na 2ª linha",
            "É a linha que a curva da Clave de Sol abraça — por isso ela tem esse nome."),
        Cue(28.0, 34.8, 3, "SUBINDO A ESCADA", "Lá e Si: linha e espaço",
            "Seguindo uma tecla por vez, o Lá entra no 2º espaço e o Si pousa na 3ª linha, bem no meio da pauta."),
        Cue(34.8, 39.0, 4, "UMA OITAVA", "Dó de novo: 1 oitava!",
            "No 3º espaço chegamos a outro Dó! De um Dó até o próximo são 8 teclas brancas: uma oitava."),
        Cue(39.0, 45.5, 4, "UMA OITAVA", "Uma nota por tecla",
            "Viu como é simples? Cada tecla branca vizinha sobe meio degrau na pauta. Agora é a sua vez!"),
    ]


def build_presses(lang: str) -> list[Press]:
    callouts_pt = [
        "Linha curta (2 abaixo)",
        "Embaixo da 1ª linha",
        "1ª linha",
        "1º espaço",
        "2ª linha (Sol)",
        "2º espaço",
        "3ª linha (meio)",
        "3º espaço (1 oitava)",
    ]
    callouts_en = [
        "Ledger line (2 below)",
        "Below the 1st line",
        "1st line",
        "1st space",
        "2nd line (G)",
        "2nd space",
        "3rd line (middle)",
        "3rd space (1 octave)",
    ]
    callouts = callouts_en if lang == "en" else callouts_pt
    base = [
        ("C4", 60, -6, 10.6),
        ("D4", 62, -5, 14.6),
        ("E4", 64, -4, 18.0),
        ("F4", 65, -3, 21.4),
        ("G4", 67, -2, 24.8),
        ("A4", 69, -1, 28.2),
        ("B4", 71,  0, 31.6),
        ("C5", 72,  1, 35.0),
    ]
    out: list[Press] = []
    for i, (tok, midi, pos, onset) in enumerate(base):
        out.append(Press(i, tok, midi, pos, i, onset, 1.35, True, callouts[i]))
    finale_start = 39.4
    gap = 0.48
    for i, (tok, midi, pos, _) in enumerate(base):
        hold = 1.4 if i == len(base) - 1 else 0.42
        out.append(Press(len(base) + i, tok, midi, pos, i, finale_start + i * gap, hold, False, ""))
    return out


def short_name(token: str, lang: str) -> str:
    letter = token[0]
    if lang == "en":
        return letter
    return {"C": "Dó", "D": "Ré", "E": "Mi", "F": "Fá", "G": "Sol", "A": "Lá", "B": "Si"}[letter]


def prog(t: float, start: float, dur: float) -> float:
    if dur <= 0:
        return 1.0 if t >= start else 0.0
    return min(1.0, max(0.0, (t - start) / dur))


def ease_out(x: float) -> float:
    return 1.0 - (1.0 - x) ** 3


def ease_in_out(x: float) -> float:
    return 4 * x * x * x if x < 0.5 else 1.0 - ((-2 * x + 2) ** 3) / 2.0


def bell(t: float, start: float, dur: float) -> float:
    p = prog(t, start, dur)
    return math.sin(p * math.pi) if 0.0 < p < 1.0 else 0.0


def smooth_win(t: float, fi0: float, fi1: float, fo0: float, fo1: float) -> float:
    if t <= fi0 or t >= fo1:
        return 0.0
    if t < fi1:
        return ease_out(prog(t, fi0, fi1 - fi0))
    if t > fo0:
        return 1.0 - ease_in_out(prog(t, fo0, fo1 - fo0))
    return 1.0


def spring_scale(p: float) -> float:
    if p >= 1.0:
        return 1.0
    if p < 0.65:
        u = p / 0.65
        return 0.25 + 0.90 * (1.0 - (1.0 - u) ** 3)
    u = (p - 0.65) / 0.35
    return 1.15 - 0.15 * u


def white_slot(midi: float) -> float:
    clamped = min(84.0, max(60.0, midi))
    rel = clamped - 60.0
    octave = math.floor(rel / 12.0)
    semi = rel - octave * 12.0
    anchors = [(0, 0), (2, 1), (4, 2), (5, 3), (7, 4), (9, 5), (11, 6), (12, 7)]
    local = 0.0
    for (s0, k0), (s1, k1) in zip(anchors, anchors[1:]):
        if s0 <= semi <= s1:
            f = (semi - s0) / (s1 - s0) if s1 > s0 else 0.0
            local = k0 + (k1 - k0) * f
            break
    return octave * 7.0 + local


def load_fonts() -> dict[str, ImageFont.FreeTypeFont]:
    win_fonts = pathlib.Path("C:/Windows/Fonts")
    regular = win_fonts / "segoeui.ttf"
    semibold = win_fonts / "seguisb.ttf"
    bold = win_fonts / "segoeuib.ttf"
    consolas = win_fonts / "consolab.ttf"
    if not semibold.exists():
        semibold = bold
    if not consolas.exists():
        consolas = bold

    return {
        "top_title": ImageFont.truetype(str(bold), 36),
        "top_sub": ImageFont.truetype(str(regular), 25),
        "badge": ImageFont.truetype(str(bold), 24),
        "phase": ImageFont.truetype(str(bold), 25),
        "cue_title": ImageFont.truetype(str(bold), 44),
        "cue_sub": ImageFont.truetype(str(regular), 32),
        "line_num": ImageFont.truetype(str(bold), 28),
        "guide_lbl": ImageFont.truetype(str(bold), 24),
        "note_lbl": ImageFont.truetype(str(bold), 31),
        "callout": ImageFont.truetype(str(bold), 28),
        "arch_lbl": ImageFont.truetype(str(bold), 28),
        "clock": ImageFont.truetype(str(consolas), 24),
        "btn": ImageFont.truetype(str(bold), 30),
        "key_lbl": ImageFont.truetype(str(semibold), 25),
        "key_c": ImageFont.truetype(str(bold), 26),
        "clef": ImageFont.truetype(str(BRAVURA_FONT), 224),  # 4 * space (space=56)
    }


def wrap_text(draw: ImageDraw.ImageDraw, text: str, font: ImageFont.FreeTypeFont, max_w: int) -> list[str]:
    words = text.split()
    lines: list[str] = []
    cur = ""
    for w in words:
        test = f"{cur} {w}".strip()
        bbox = draw.textbbox((0, 0), test, font=font)
        if bbox[2] - bbox[0] <= max_w or not cur:
            cur = test
        else:
            lines.append(cur)
            cur = w
    if cur:
        lines.append(cur)
    return lines


def draw_tilted_notehead(
    base: Image.Image, cx: float, cy: float, w: float, h: float, color: tuple[int, int, int, int]
) -> None:
    pad = int(max(w, h) * 1.4)
    tile = Image.new("RGBA", (pad * 2, pad * 2), (0, 0, 0, 0))
    td = ImageDraw.Draw(tile)
    td.ellipse((pad - w / 2, pad - h / 2, pad + w / 2, pad + h / 2), fill=color)
    rotated = tile.rotate(20, resample=Image.Resampling.BICUBIC)
    rw, rh = rotated.size
    base.paste(rotated, (int(round(cx - rw / 2)), int(round(cy - rh / 2))), mask=rotated)


def build_audio_track(presses: list[Press], out_wav: pathlib.Path) -> None:
    """Synthesizes the stereo piano soundtrack from the Salamander samples via FFmpeg."""
    # Map MIDI note to (sample_filename, semitone_shift)
    sample_map = {
        60: ("C4.mp3", 0),
        62: ("Ds4.mp3", -1),
        64: ("Ds4.mp3", 1),
        65: ("Fs4.mp3", -1),
        67: ("Fs4.mp3", 1),
        69: ("A4.mp3", 0),
        71: ("C5.mp3", -1),
        72: ("C5.mp3", 0),
    }

    inputs = ["-f", "lavfi", "-t", str(DURATION), "-i", "anullsrc=r=44100:cl=stereo"]
    filter_parts: list[str] = []
    mix_labels = ["[0:a]"]

    for idx, p in enumerate(presses, start=1):
        fname, shift = sample_map[p.midi]
        inputs += ["-i", str(SALAMANDER_DIR / fname)]
        rate_factor = 2.0 ** (shift / 12.0)
        delay_ms = int(round(p.onset * 1000))
        dur = p.hold + 0.65
        fade_out_start = max(0.05, p.hold)
        vol = 0.90 if p.spawns else 0.78
        lbl = f"[n{idx}]"
        chain = (
            f"[{idx}:a]asetrate=44100*{rate_factor:.6f},aresample=44100,"
            f"atrim=0:{dur:.3f},afade=t=out:st={fade_out_start:.3f}:d=0.60,"
            f"volume={vol:.2f},adelay={delay_ms}|{delay_ms}{lbl}"
        )
        filter_parts.append(chain)
        mix_labels.append(lbl)

    amix = f"{''.join(mix_labels)}amix=inputs={len(mix_labels)}:normalize=0,alimiter=limit=0.95[aout]"
    filter_parts.append(amix)

    cmd = [
        "ffmpeg", "-y",
        *inputs,
        "-filter_complex", ";".join(filter_parts),
        "-map", "[aout]",
        "-t", str(DURATION),
        str(out_wav),
    ]
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)


class IntroRenderer:
    W = 1080
    H = 1920

    def __init__(self, lang: str = "pt") -> None:
        self.lang = lang
        self.cues = build_cues(lang)
        self.presses = build_presses(lang)
        self.intro_presses = [p for p in self.presses if p.spawns]
        self.finale_presses = [p for p in self.presses if not p.spawns]
        self.fonts = load_fonts()

        # Layout vertical coordinates (matching LessonPlayerView + LessonIntroView)
        self.top_bar_h = 136
        self.sub_card_top = 162
        self.sub_card_h = 290
        self.staff_card_top = 476
        self.staff_card_h = 770
        self.transport_top = 1270
        self.transport_h = 122
        self.kb_top = 1416
        self.kb_h = self.H - self.kb_top  # 504 px

        # Staff metrics inside the 1024x770 white card
        self.card_x = 28
        self.card_w = self.W - 56
        self.unit = 28.0  # space = 56 px
        self.space = 56.0
        self.top_pos = 6
        self.origin_y = self.staff_card_top + 148
        self.staff_left = self.card_x + 36
        self.staff_right = self.card_x + self.card_w - 66
        self.clef_w = self.space * 2.85
        self.notes_start = self.staff_left + self.clef_w + self.space * 0.55
        self.col_w = (self.staff_right - self.notes_start - 16) / 8.0

        # Precompute keyboard keys (60...84)
        names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        blacks = {1, 3, 6, 8, 10}
        self.white_keys: list[tuple[int, str, int]] = []
        self.black_keys: list[tuple[int, str, int]] = []
        for m in range(60, 85):
            octv = (m // 12) - 1
            nm = names[m % 12]
            if (m % 12) in blacks:
                self.black_keys.append((m, nm, octv))
            else:
                self.white_keys.append((m, nm, octv))

    def pos_y(self, position: int) -> float:
        return self.origin_y + (self.top_pos - position) * self.unit

    def col_x(self, col: int) -> float:
        return self.notes_start + self.col_w * (col + 0.5)

    def cursor_state(self, t: float) -> tuple[float, float, float, tuple[int, float] | None]:
        first = self.presses[0]
        last = self.presses[-1]
        fi0 = first.onset - 1.2
        fo1 = last.onset + last.hold + 0.8
        opacity = smooth_win(t, fi0, first.onset - 0.3, last.onset + last.hold + 0.1, fo1)
        if opacity <= 0.001:
            return (0.0, float(first.midi), 0.0, None)

        midi_pos = float(first.midi)
        if t <= first.onset:
            g = ease_in_out(prog(t, fi0, first.onset - fi0))
            midi_pos = 64.0 + (first.midi - 64.0) * g
        else:
            for i, cur in enumerate(self.presses):
                if i + 1 < len(self.presses):
                    nxt = self.presses[i + 1]
                    if cur.onset <= t < nxt.onset:
                        gap = nxt.onset - cur.onset
                        mdur = min(0.65, gap * 0.42)
                        mstart = nxt.onset - mdur
                        if t <= mstart:
                            midi_pos = float(cur.midi)
                        else:
                            g = ease_in_out(prog(t, mstart, mdur))
                            midi_pos = cur.midi + (nxt.midi - cur.midi) * g
                        break
                elif t >= cur.onset:
                    midi_pos = float(cur.midi)

        depth = 0.0
        ripple: tuple[int, float] | None = None
        past = [p for p in self.presses if t >= p.onset]
        if past:
            act = past[-1]
            age = t - act.onset
            if age <= act.hold + 0.18:
                att = min(1.0, age / 0.07)
                rel = 1.0 if age <= act.hold else max(0.0, 1.0 - (age - act.hold) / 0.18)
                depth = att * rel
            if 0.0 <= age <= 0.55:
                ripple = (act.midi, age / 0.55)
        return (opacity, midi_pos, depth, ripple)

    def render_frame(self, t: float) -> Image.Image:
        img = Image.new("RGB", (self.W, self.H), BG_COLOR)
        draw = ImageDraw.Draw(img, "RGBA")

        cue = next((c for c in reversed(self.cues) if t >= c.start), self.cues[0])

        # --- 1. Top Bar (PlayerTopBar) ---
        draw.rectangle((0, 0, self.W, self.top_bar_h), fill=(*PANEL_COLOR, 255))
        draw.line((0, self.top_bar_h, self.W, self.top_bar_h), fill=(*RAISED_COLOR, 255), width=2)

        # Back button square
        draw.rounded_rectangle((28, 36, 102, 110), radius=18, fill=(*RAISED_COLOR, 255))
        draw.line([(72, 56), (54, 73), (72, 90)], fill=(*TEXT_MAIN, 255), width=5, joint="curve")

        lesson_title = "How to read sheet music" if self.lang == "en" else "Como ler a partitura"
        lesson_sub = "Step 1 of 5 · Intro" if self.lang == "en" else "Passo 1 de 5 · Introdução"
        draw.text((126, 36), lesson_title, font=self.fonts["top_title"], fill=(*TEXT_MAIN, 255))
        draw.text((126, 82), lesson_sub, font=self.fonts["top_sub"], fill=(*TEXT_MUTED, 255))

        # Lesson progress bar under top bar
        draw.rectangle((0, self.top_bar_h, self.W, self.top_bar_h + 6), fill=(*RAISED_COLOR, 255))
        bar_w = int(self.W * (0.05 + 0.15 * (t / DURATION)))
        draw.rectangle((0, self.top_bar_h, bar_w, self.top_bar_h + 6), fill=(*CYAN_COLOR, 255))

        # --- 2. Subtitle Card ---
        draw.rounded_rectangle(
            (self.card_x, self.sub_card_top, self.card_x + self.card_w, self.sub_card_top + self.sub_card_h),
            radius=28,
            fill=(*PANEL_COLOR, 255),
            outline=(*RAISED_COLOR, 255),
            width=2,
        )
        badge_txt = "VIDEO" if self.lang == "en" else "VÍDEO"
        bb = draw.textbbox((0, 0), badge_txt, font=self.fonts["badge"])
        pill_w = (bb[2] - bb[0]) + 58
        px0 = self.card_x + 28
        py0 = self.sub_card_top + 24
        draw.rounded_rectangle(
            (px0, py0, px0 + pill_w, py0 + 44),
            radius=22,
            fill=(*CYAN_COLOR, 42),
        )
        draw.polygon([(px0 + 20, py0 + 14), (px0 + 20, py0 + 30), (px0 + 34, py0 + 22)], fill=(*CYAN_COLOR, 255))
        draw.text((px0 + 42, py0 + 6), badge_txt, font=self.fonts["badge"], fill=(*CYAN_COLOR, 255))
        draw.text(
            (px0 + pill_w + 18, py0 + 6),
            f"{cue.phase}/4 · {cue.phase_label}",
            font=self.fonts["phase"],
            fill=(*TEXT_MUTED, 255),
        )

        draw.text((self.card_x + 30, self.sub_card_top + 84), cue.title, font=self.fonts["cue_title"], fill=(*TEXT_MAIN, 255))
        wrapped = wrap_text(draw, cue.subtitle, self.fonts["cue_sub"], self.card_w - 60)
        for idx, line in enumerate(wrapped[:3]):
            draw.text(
                (self.card_x + 30, self.sub_card_top + 148 + idx * 42),
                line,
                font=self.fonts["cue_sub"],
                fill=(*TEXT_MUTED, 255),
            )

        # --- 3. White Score Card ---
        draw.rounded_rectangle(
            (self.card_x, self.staff_card_top, self.card_x + self.card_w, self.staff_card_top + self.staff_card_h),
            radius=30,
            fill=(*WHITE, 255),
        )

        # Compute animated staff state
        line_prog = [ease_out(prog(t, 0.35 + i * 0.55, 0.65)) for i in range(5)]
        space_glow = [bell(t, 4.4 + i * 0.36, 1.4) * 0.85 for i in range(4)]
        line_glow = [0.0] * 5
        below_space_glow = 0.0
        clef_prog = ease_out(prog(t, 5.9, 1.1))
        clef_pulse = bell(t, 6.3, 1.6) * 0.65
        mc_guide = smooth_win(t, 8.3, 9.1, 13.5, 14.3)
        two_blacks_glow = smooth_win(t, 8.1, 8.7, 10.3, 11.1)

        active_callout: tuple[int, str, float] | None = None
        step_up: tuple[int, int, float] | None = None
        beam: tuple[int, int, int, float] | None = None
        cyan_key: int | None = None
        green_key: int | None = None

        visible_notes = []
        for p in self.intro_presses:
            if t < p.onset:
                continue
            age = t - p.onset
            appear = min(1.0, age / 0.42)
            act = smooth_win(t, p.onset, p.onset + 0.12, p.onset + 2.4, p.onset + 3.1)
            fin = 0.0
            rep = next((r for r in self.finale_presses if r.col == p.col), None)
            if rep and t >= rep.onset:
                fin = smooth_win(t, rep.onset, rep.onset + 0.08, rep.onset + rep.hold, rep.onset + rep.hold + 0.6)

            visible_notes.append((p, appear, act, fin))

            if act > 0.01:
                if p.pos == -5:
                    below_space_glow = max(below_space_glow, act)
                elif p.pos in (-4, -2, 0, 2, 4):
                    li = (p.pos + 4) // 2
                    line_glow[li] = max(line_glow[li], act)
                    if p.pos == -2:
                        clef_pulse = max(clef_pulse, act)
                elif p.pos in (-3, -1, 1, 3):
                    si = (p.pos + 3) // 2
                    space_glow[si] = max(space_glow[si], act)
                active_callout = (p.col, p.callout, act)

            if 0.0 <= age <= 0.75:
                beam = (p.midi, p.col, p.pos, age / 0.75)
            if p.col > 0 and 0.0 <= age <= 1.8:
                su = ease_out(min(1.0, age / 0.55)) * (1.0 - max(0.0, (age - 1.2) / 0.6))
                step_up = (p.col - 1, p.col, su)
            if 0.0 <= age <= p.hold:
                cyan_key = p.midi

        for rep in self.finale_presses:
            if 0.0 <= (t - rep.onset) <= rep.hold:
                green_key = rep.midi

        octave_arch = smooth_win(t, 35.4, 36.3, 44.8, 45.5)

        # Draw space highlights
        for si in range(4):
            g = space_glow[si]
            if g > 0.01:
                pos = -3 + si * 2
                y_top = int(self.pos_y(pos + 1) + 2)
                y_bot = int(self.pos_y(pos - 1) - 2)
                draw.rounded_rectangle(
                    (self.staff_left, y_top, self.staff_right, y_bot),
                    radius=8,
                    fill=(14, 165, 233, int(62 * g)),
                )
        if below_space_glow > 0.01:
            y_top = int(self.pos_y(-4) + 2)
            y_bot = int(self.pos_y(-6) - 2)
            draw.rounded_rectangle(
                (self.staff_left, y_top, self.staff_right, y_bot),
                radius=8,
                fill=(14, 165, 233, int(62 * below_space_glow)),
            )

        # Draw 5 staff lines & right-side numbers
        for li in range(5):
            pr = line_prog[li]
            if pr <= 0.005:
                continue
            pos = -4 + li * 2
            y = int(round(self.pos_y(pos)))
            end_x = int(round(self.staff_left + (self.staff_right - self.staff_left) * pr))
            gl = line_glow[li]
            if gl > 0.02:
                draw.line((self.staff_left, y, end_x, y), fill=(*STAFF_BLUE, int(90 * gl)), width=12)
            col = (*STAFF_BLUE, 255) if gl > 0.12 else (*INK_COLOR, 215)
            draw.line((self.staff_left, y, end_x, y), fill=col, width=5 if gl > 0.12 else 3)

            num_alpha = int(255 * min(1.0, pr * 1.4))
            num_col = (*STAFF_BLUE, num_alpha) if gl > 0.12 else (120, 130, 145, int(num_alpha * 0.85))
            draw.text((self.staff_right + 28, y), str(li + 1), font=self.fonts["line_num"], fill=num_col, anchor="mm")

        # Draw 2-steps-below dashed guides for Middle C
        if mc_guide > 0.01:
            cx = self.col_x(0)
            alpha = int(220 * mc_guide)
            for step_pos, lbl in [(-5, "-1"), (-6, "-2")]:
                gy = int(round(self.pos_y(step_pos)))
                for dx in range(-58, 56, 16):
                    draw.line((cx + dx, gy, cx + dx + 9, gy), fill=(14, 165, 233, alpha), width=3)
                draw.text((cx + 80, gy), lbl, font=self.fonts["guide_lbl"], fill=(14, 165, 233, alpha), anchor="mm")

        # Draw Treble Clef (Bravura U+E050 baseline sits directly on G4 line, pos -2)
        if clef_prog > 0.01:
            if clef_pulse > 0.01:
                ccx = int(self.staff_left + self.space * 1.15)
                ccy = int(self.pos_y(-2))
                rad = int(self.space * (1.05 + 0.25 * clef_pulse))
                draw.ellipse((ccx - rad, ccy - rad, ccx + rad, ccy + rad), fill=(14, 165, 233, int(52 * clef_pulse)))
            draw.text(
                (self.staff_left + 10, self.pos_y(-2)),
                "\uE050",
                font=self.fonts["clef"],
                fill=(*INK_COLOR, int(255 * clef_prog)),
                anchor="ls",
            )

        # Step-up arc between consecutive notes
        if step_up and step_up[2] > 0.02:
            c0, c1, sp_alpha = step_up
            x1, x2 = self.col_x(c0), self.col_x(c1)
            y1, y2 = self.pos_y(-6 + c0), self.pos_y(-6 + c1)
            pts = []
            ctrl_x = (x1 + x2) / 2
            ctrl_y = min(y1, y2) - self.space * 1.15
            for k in range(21):
                u = k / 20.0
                px = (1 - u) ** 2 * (x1 + 18) + 2 * (1 - u) * u * ctrl_x + u ** 2 * (x2 - 18)
                py = (1 - u) ** 2 * (y1 - 22) + 2 * (1 - u) * u * ctrl_y + u ** 2 * (y2 - 24)
                pts.append((px, py))
            draw.line(pts, fill=(14, 165, 233, int(225 * sp_alpha)), width=5)

        # Octave arch (C4 to C5)
        if octave_arch > 0.01:
            sx, ex = self.col_x(0), self.col_x(7)
            sy = self.pos_y(3)
            ctrl_y = self.pos_y(5) - self.space * 1.1
            pts = []
            for k in range(41):
                u = k / 40.0
                px = (1 - u) ** 2 * sx + 2 * (1 - u) * u * ((sx + ex) / 2) + u ** 2 * ex
                py = (1 - u) ** 2 * sy + 2 * (1 - u) * u * ctrl_y + u ** 2 * sy
                pts.append((px, py))
            for k in range(0, len(pts) - 1, 2):
                draw.line([pts[k], pts[k + 1]], fill=(*STAFF_GREEN, int(210 * octave_arch)), width=5)
            arch_txt = "1 octave (8 notes)" if self.lang == "en" else "1 oitava (8 notas)"
            draw.text(
                ((sx + ex) / 2, ctrl_y + 18),
                arch_txt,
                font=self.fonts["arch_lbl"],
                fill=(*STAFF_GREEN, int(255 * octave_arch)),
                anchor="mm",
            )

        # Draw spawned notes
        head_w = self.space * 1.24
        head_h = self.space * 0.90
        labels_y = self.pos_y(-7) + 46

        for p, appear, act, fin in visible_notes:
            x = self.col_x(p.col)
            y = self.pos_y(p.pos)
            sc = spring_scale(appear)
            rgb = STAFF_GREEN if fin > 0.15 else (STAFF_BLUE if act > 0.15 else INK_COLOR)

            halo = max(act, fin)
            if halo > 0.05:
                rad = int(head_w * (0.85 + 0.25 * halo))
                hcol = GREEN_COLOR if fin > 0.15 else CYAN_COLOR
                draw.ellipse((x - rad, y - rad, x + rad, y + rad), fill=(*hcol, int(55 * halo)))

            # Short ledger line for Middle C
            if p.pos <= -6:
                lh = head_w * 0.85 * sc
                ly = int(round(self.pos_y(-6)))
                lcol = (*STAFF_BLUE, 255) if act > 0.15 else (*INK_COLOR, 230)
                draw.line((x - lh, ly, x + lh, ly), fill=lcol, width=6 if act > 0.15 else 4)

            # Stem
            stem_up = p.pos < 0
            tip_pos = max(p.pos + 7, 0) if stem_up else min(p.pos - 7, 0)
            stem_x = x + (head_w * sc) / 2 - 2 if stem_up else x - (head_w * sc) / 2 + 2
            stem_end_y = y + (self.pos_y(tip_pos) - y) * sc
            draw.line(
                (stem_x, y, stem_x, stem_end_y),
                fill=(*rgb, int(255 * min(1.0, appear * 1.4))),
                width=4,
            )

            # Tilted elliptical notehead
            draw_tilted_notehead(img, x, y, head_w * sc, head_h * sc, (*rgb, 255))
            draw = ImageDraw.Draw(img, "RGBA")

            # Note name label below
            nm = short_name(p.token, self.lang)
            draw.text((x, labels_y), nm, font=self.fonts["note_lbl"], fill=(*rgb, 255), anchor="mt")

        # Active position callout pill
        if active_callout and active_callout[1] and active_callout[2] > 0.05:
            ccol, ctext, calpha = active_callout
            tx = min(max(self.staff_left + 180, self.col_x(ccol)), self.staff_right - 170)
            ty = self.staff_card_top + 44
            tb = draw.textbbox((0, 0), ctext, font=self.fonts["callout"])
            tw = tb[2] - tb[0] + 36
            draw.rounded_rectangle(
                (tx - tw / 2, ty - 24, tx + tw / 2, ty + 24),
                radius=22,
                fill=(*STAFF_BLUE, int(30 * calpha)),
            )
            draw.text((tx, ty), ctext, font=self.fonts["callout"], fill=(*STAFF_BLUE, int(255 * calpha)), anchor="mm")

        # --- 4. Transport Bar ---
        ty_mid = self.transport_top + self.transport_h // 2
        # Play/Pause button
        draw.rounded_rectangle(
            (self.card_x, ty_mid - 44, self.card_x + 88, ty_mid + 44),
            radius=20,
            fill=(*RAISED_COLOR, 255),
        )
        draw.rounded_rectangle((self.card_x + 30, ty_mid - 16, self.card_x + 39, ty_mid + 16), radius=3, fill=(*TEXT_MAIN, 255))
        draw.rounded_rectangle((self.card_x + 49, ty_mid - 16, self.card_x + 58, ty_mid + 16), radius=3, fill=(*TEXT_MAIN, 255))

        ready = t >= DURATION - 4.0
        btn_txt = ("Start playing ›" if self.lang == "en" else "Começar a tocar ›") if ready else ("Skip ›" if self.lang == "en" else "Pular ›")
        bb_btn = draw.textbbox((0, 0), btn_txt, font=self.fonts["btn"])
        btn_w = (bb_btn[2] - bb_btn[0]) + (56 if ready else 44)
        btn_right = self.card_x + self.card_w
        btn_left = btn_right - btn_w

        # Slider track
        sl_left = self.card_x + 112
        sl_right = btn_left - 26
        sl_y = ty_mid - 8
        draw.rounded_rectangle((sl_left, sl_y - 5, sl_right, sl_y + 5), radius=5, fill=(*RAISED_COLOR, 255))
        knob_x = sl_left + (sl_right - sl_left) * (t / DURATION)
        draw.rounded_rectangle((sl_left, sl_y - 5, knob_x, sl_y + 5), radius=5, fill=(*CYAN_COLOR, 255))
        draw.ellipse((knob_x - 13, sl_y - 13, knob_x + 13, sl_y + 13), fill=(*WHITE, 255))

        cur_sec = int(t)
        tot_sec = int(DURATION)
        draw.text((sl_left, sl_y + 18), f"{cur_sec // 60}:{cur_sec % 60:02d}", font=self.fonts["clock"], fill=(*TEXT_MUTED, 255))
        draw.text((sl_right, sl_y + 18), f"{tot_sec // 60}:{tot_sec % 60:02d}", font=self.fonts["clock"], fill=(*TEXT_MUTED, 255), anchor="ra")

        # Action button
        draw.rounded_rectangle(
            (btn_left, ty_mid - 44, btn_right, ty_mid + 44),
            radius=20,
            fill=(*DEEP_BLUE, 255) if ready else (*RAISED_COLOR, 255),
        )
        draw.text(((btn_left + btn_right) / 2, ty_mid), btn_txt, font=self.fonts["btn"], fill=(*WHITE, 255), anchor="mm")

        # --- 5. Two-Octave Keyboard (C4..C6, 15 white keys) ---
        draw.rectangle((0, self.kb_top - 4, self.W, self.H), fill=(*PANEL_COLOR, 255))
        kb_pad = 6
        w_width = (self.W - kb_pad * 2) / 15.0
        w_height = self.kb_h - 8
        b_width = w_width * 0.60
        b_height = w_height * 0.61

        c_op, c_midi, c_depth, c_ripple = self.cursor_state(t)

        # White keys
        for idx, (midi, nm, octv) in enumerate(self.white_keys):
            kx0 = kb_pad + idx * w_width + 1.5
            kx1 = kb_pad + (idx + 1) * w_width - 1.5
            depressed = (midi == cyan_key or midi == green_key) and c_depth > 0.1
            ky0 = self.kb_top + (7.0 * c_depth if depressed else 0.0)
            ky1 = self.kb_top + w_height

            if midi == green_key:
                fill_col = (*GREEN_COLOR, 255)
            elif midi == cyan_key:
                fill_col = (*ELECTRIC_CYAN, 255)
            else:
                fill_col = (244, 243, 240, 255)

            draw.rounded_rectangle((kx0, ky0, kx1, ky1), radius=9, fill=fill_col, outline=(170, 175, 182, 255), width=2)

            lbl = short_name(nm + str(octv), self.lang)
            if nm == "C":
                lbl = f"{lbl}{octv}"
            lbl_col = (20, 24, 32, 230) if (midi in (cyan_key, green_key) or nm == "C") else (130, 136, 146, 255)
            draw.text(
                ((kx0 + kx1) / 2, ky1 - 26),
                lbl,
                font=self.fonts["key_c"] if nm == "C" else self.fonts["key_lbl"],
                fill=lbl_col,
                anchor="mm",
            )

        # Black keys
        white_ids = [m for m, _, _ in self.white_keys]
        for midi, nm, octv in self.black_keys:
            prev_idx = max(i for i, wm in enumerate(white_ids) if wm < midi)
            bx_center = kb_pad + (prev_idx + 1) * w_width
            bx0 = bx_center - b_width / 2
            bx1 = bx_center + b_width / 2
            by0 = self.kb_top
            by1 = self.kb_top + b_height

            is_pair2 = midi in (61, 63, 73, 75)
            pg = two_blacks_glow if is_pair2 else 0.0
            if pg > 0.05:
                bfill = (int(28 + 28 * pg), int(38 + 140 * pg), int(50 + 190 * pg), 255)
                bout = (*CYAN_COLOR, int(255 * pg))
            else:
                bfill = (28, 30, 36, 255)
                bout = (10, 10, 14, 255)
            draw.rounded_rectangle((bx0, by0, bx1, by1), radius=8, fill=bfill, outline=bout, width=3 if pg > 0.05 else 2)

        # --- 6. Light Beam from Key to Staff Note ---
        if beam:
            b_midi, b_col, b_pos, b_prog = beam
            head_t = min(1.0, b_prog * 1.45)
            tail_t = max(0.0, (b_prog - 0.25) / 0.75)
            if head_t > tail_t:
                slot = white_slot(float(b_midi))
                sx = kb_pad + (slot + 0.5) * w_width
                sy = self.kb_top + 40
                ex = self.col_x(b_col)
                ey = self.pos_y(b_pos)
                cx_ctrl = sx + (ex - sx) * 0.35
                cy_ctrl = (sy + ey) * 0.5

                pts = []
                for k in range(31):
                    u = tail_t + (head_t - tail_t) * (k / 30.0)
                    px = (1 - u) ** 2 * sx + 2 * (1 - u) * u * cx_ctrl + u ** 2 * ex
                    py = (1 - u) ** 2 * sy + 2 * (1 - u) * u * cy_ctrl + u ** 2 * ey
                    pts.append((px, py))
                alpha_b = int(190 * (1.0 - b_prog * 0.6))
                draw.line(pts, fill=(*CYAN_COLOR, alpha_b), width=9)
                sp_x, sp_y = pts[-1]
                draw.ellipse((sp_x - 14, sp_y - 14, sp_x + 14, sp_y + 14), fill=(*WHITE, int(240 * (1.0 - b_prog * 0.65))))

        # --- 7. Motion-Capture Touch Orb ---
        if c_op > 0.01:
            slot = white_slot(c_midi)
            ox = kb_pad + (slot + 0.5) * w_width
            oy = self.kb_top + w_height * 0.72 + 7.0 * c_depth
            orb_rgb = GREEN_COLOR if green_key is not None else ELECTRIC_CYAN

            if c_ripple is not None:
                rmidi, rprog = c_ripple
                rslot = white_slot(float(rmidi))
                rx = kb_pad + (rslot + 0.5) * w_width
                ry = self.kb_top + w_height * 0.72 + 4.0
                rr = 34 + rprog * 56
                ralpha = int(220 * (1.0 - rprog) * c_op)
                draw.ellipse((rx - rr, ry - rr, rx + rr, ry + rr), outline=(*orb_rgb, ralpha), width=6)

            halo_r = 46
            draw.ellipse((ox - halo_r, oy - halo_r, ox + halo_r, oy + halo_r), fill=(*orb_rgb, int(76 * c_op)))
            core_r = 26 * (1.0 - 0.14 * c_depth)
            draw.ellipse((ox - core_r, oy - core_r, ox + core_r, oy + core_r), fill=(*orb_rgb, int(255 * c_op)))
            inner_r = core_r * 0.52
            draw.ellipse((ox - inner_r, oy - inner_r, ox + inner_r, oy + inner_r), fill=(*WHITE, int(245 * c_op)))

        return img


def render_video(out_mp4: pathlib.Path, lang: str = "pt", fps: int = 60) -> None:
    renderer = IntroRenderer(lang=lang)
    total_frames = int(round(DURATION * fps))

    with tempfile.TemporaryDirectory() as tmp:
        wav_path = pathlib.Path(tmp) / "audio.wav"
        build_audio_track(renderer.presses, wav_path)

        out_mp4.parent.mkdir(parents=True, exist_ok=True)
        cmd = [
            "ffmpeg", "-y",
            "-f", "rawvideo",
            "-pix_fmt", "rgb24",
            "-s", f"{renderer.W}x{renderer.H}",
            "-r", str(fps),
            "-i", "-",
            "-i", str(wav_path),
            "-c:v", "libx264",
            "-preset", "fast",
            "-crf", "18",
            "-pix_fmt", "yuv420p",
            "-c:a", "aac",
            "-b:a", "192k",
            "-movflags", "+faststart",
            "-shortest",
            str(out_mp4),
        ]
        proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        assert proc.stdin is not None
        for frame_idx in range(total_frames):
            t = frame_idx / fps
            frame = renderer.render_frame(t)
            proc.stdin.write(np.asarray(frame, dtype=np.uint8).tobytes())
        proc.stdin.close()
        stderr = proc.stderr.read() if proc.stderr else b""
        rc = proc.wait()
        if rc != 0:
            raise RuntimeError(f"FFmpeg failed ({rc}): {stderr.decode(errors='replace')}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Render luksMusic vertical intro video.")
    parser.add_argument("--out", type=pathlib.Path, required=True, help="Output MP4 path")
    parser.add_argument("--lang", choices=["pt", "en"], default="pt", help="Subtitle & note name language")
    parser.add_argument("--fps", type=int, default=60, help="Frames per second")
    parser.add_argument("--preview-dir", type=pathlib.Path, default=None, help="Optional dir to save keyframe PNGs")
    args = parser.parse_args()

    if args.preview_dir:
        args.preview_dir.mkdir(parents=True, exist_ok=True)
        r = IntroRenderer(lang=args.lang)
        for name, ts in [("01_lines.png", 3.6), ("02_middle_c.png", 11.1), ("03_climbing_g.png", 25.2), ("04_octave_finale.png", 41.2)]:
            r.render_frame(ts).save(args.preview_dir / name)

    render_video(args.out, lang=args.lang, fps=args.fps)
    print(f"Rendered {args.out} ({args.out.stat().st_size / (1024 * 1024):.2f} MB)")


if __name__ == "__main__":
    main()
