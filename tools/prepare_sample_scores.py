"""Prepare the public-domain pieces the app seeds into a new library.

    python -P tools/prepare_sample_scores.py <name>=<score.mxl> [...]

Each <score.mxl> is a CC0 or public-domain MuseScore edition from the PDMX dataset (zenodo.org/records/15571083).
Writes luksMusic/SampleScores/<name>.musicxml with repeats and voltas written out (music21), so the app reads and
draws the notes in the order they are played, and prints the measure and note counts the unit tests check.

Needs `pip install music21`.
"""
import os
import re
import sys
import tempfile
import xml.etree.ElementTree as ET
import zipfile

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "luksMusic", "SampleScores")


def musicxml_text(path):
    if zipfile.is_zipfile(path):
        with zipfile.ZipFile(path) as z:
            name = next(n for n in z.namelist() if not n.startswith("META-INF") and n.endswith((".xml", ".musicxml")))
            return z.read(name).decode("utf-8")
    with open(path, encoding="utf-8") as f:
        return f.read()


def without_broken_tempo_marks(text):
    """Drop tempo directions written with a private-use (SMuFL) glyph: MuseScore's text left behind as '<glyph> ='
    with a tempo nobody plays (Moonlight's first mark says 450 before the real 45)."""
    def keep(m):
        block = m.group(0)
        return "" if re.search(r"[-]", block) and "<sound tempo" in block else block
    return re.sub(r"<direction\b.*?</direction>", keep, text, flags=re.S)


def written_out(text):
    """The score with repeats and voltas expanded, or the text itself when it has none."""
    if not re.search(r"<repeat[ />]|<ending[ />]", text):
        return text
    import music21
    with tempfile.TemporaryDirectory() as tmp:
        src = os.path.join(tmp, "score.musicxml")
        with open(src, "w", encoding="utf-8") as f:
            f.write(text)
        unrolled = music21.converter.parse(src).expandRepeats()
        out = os.path.join(tmp, "written_out.musicxml")
        unrolled.write("musicxml", fp=out)
        with open(out, encoding="utf-8") as f:
            return f.read()


def counts(text):
    """Measures of the first part and its notes the app plays or holds (not rests, grace or cue notes)."""
    root = ET.fromstring(text.encode("utf-8"))
    part = root.find("part")
    notes = [n for n in part.iter("note") if n.find("rest") is None and n.find("grace") is None and n.find("cue") is None]
    return len(part.findall("measure")), len(notes)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for arg in sys.argv[1:]:
        name, path = arg.split("=", 1)
        text = written_out(without_broken_tempo_marks(musicxml_text(path)))
        out = os.path.join(OUT_DIR, f"{name}.musicxml")
        with open(out, "w", encoding="utf-8", newline="\n") as f:
            f.write(text)
        measures, notes = counts(text)
        print(f'"{name}": ({measures}, {notes}),  # {os.path.getsize(out) // 1024} KB')


if __name__ == "__main__":
    main()
