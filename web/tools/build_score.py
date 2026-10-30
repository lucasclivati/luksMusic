"""Engrave a MusicXML piano score for the luksMusic web player.

    python -P build_score.py <score.mxl> <out_dir> [--zoom 80] [--treble-staves 0]

Writes into <out_dir>:
  page_N.svg   A4 pages engraved by Verovio
  score.js     window.SCORE_DATA (notes per measure), MEASURE_LAYOUT (measure boxes, page %)
               and NOTE_COLUMNS (notehead x of every onset, page %), the format index.html reads
  score.mid    MIDI rendered from the same notes
and prints the catalog numbers (measures, pages, bpm, duration).

Needs `pip install verovio music21`. Repeats and voltas are written out first (music21), so the engraving
follows the order the music is played in. Beats are quarter notes counted from 1 at each barline. Notes of
the staves in --treble-staves (0-based, top to bottom) play on the player's "treble" channel (right hand,
or Primo in a duet) and the others on "bass".
"""
import argparse
import base64
import json
import os
import re
import tempfile
import xml.etree.ElementTree as ET
import zipfile
from collections import Counter, defaultdict

import verovio

SVG_NS = "{http://www.w3.org/2000/svg}"


def classes(el):
    return (el.get("class") or "").split()


def translate_of(use):
    m = re.search(r"translate\(\s*(-?[\d.]+)[ ,]+(-?[\d.]+)\s*\)", use.get("transform", ""))
    if m:
        return float(m.group(1)), float(m.group(2))
    return float(use.get("x", 0)), float(use.get("y", 0))


def staff_lines(staff):
    """(x1, x2, [y of each line]) of a staff's five lines."""
    xs, ys = [], []
    for path in staff.findall(f"{SVG_NS}path"):
        m = re.match(r"M\s*(-?[\d.]+)\s+(-?[\d.]+)\s+L\s*(-?[\d.]+)\s+(-?[\d.]+)", path.get("d", ""))
        if m and abs(float(m.group(2)) - float(m.group(4))) < 0.5:
            xs += [float(m.group(1)), float(m.group(3))]
            ys.append(float(m.group(2)))
    return (min(xs), max(xs), sorted(ys)) if ys else None


def minify_svg(svg):
    """Drop element ids nothing refers to and the indentation; glyphs and the style's root id keep theirs."""
    used = set(re.findall(r'#([A-Za-z][\w-]*)', svg))
    svg = re.sub(r' id="([^"]+)"', lambda m: m.group(0) if m.group(1) in used else "", svg)
    return re.sub(r">\s+<", "><", svg)


def musicxml_text(path):
    if zipfile.is_zipfile(path):
        with zipfile.ZipFile(path) as z:
            name = next(n for n in z.namelist() if not n.startswith("META-INF") and n.endswith((".xml", ".musicxml")))
            return z.read(name).decode("utf-8")
    with open(path, encoding="utf-8") as f:
        return f.read()


def written_out(path):
    """Path of the score with its repeats and voltas expanded (the score itself when it has none)."""
    if not re.search(r"<repeat[ />]|<ending[ />]", musicxml_text(path)):
        return path
    import music21
    unrolled = music21.converter.parse(path).expandRepeats()
    out = os.path.join(tempfile.mkdtemp(), "written_out.musicxml")
    unrolled.write("musicxml", fp=out)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("score")
    ap.add_argument("out_dir")
    ap.add_argument("--zoom", type=float, default=80, help="engraving size in percent (100 = 7.2 mm staves)")
    ap.add_argument("--treble-staves", default="0", help="comma-separated staves played on the treble channel")
    args = ap.parse_args()
    treble_staves = {int(i) for i in args.treble_staves.split(",")}

    tk = verovio.toolkit()
    tk.setOptions({
        "pageWidth": round(2100 * 100 / args.zoom),
        "pageHeight": round(2970 * 100 / args.zoom),
        "scale": args.zoom,
        "adjustPageHeight": False,
        "breaks": "auto",
        "footer": "none",
        "svgViewBox": True,
    })
    if not tk.loadFile(written_out(args.score)):
        raise SystemExit(f"Verovio could not read {args.score}")
    os.makedirs(args.out_dir, exist_ok=True)

    # Onset/offset (quarter notes from the start) of every sounding note, measure starts and tempi
    timemap = tk.renderToTimemap({"includeMeasures": True})
    note_on, note_off = {}, {}
    measure_start = {}
    tempo_at = []
    for ev in timemap:
        q = ev["qstamp"]
        for nid in ev.get("on", []):
            note_on[nid] = q
        for nid in ev.get("off", []):
            note_off[nid] = q
        if "measureOn" in ev:
            measure_start[ev["measureOn"]] = q
        if "tempo" in ev:
            tempo_at.append((q, ev["tempo"]))
    end_q = max(ev["qstamp"] for ev in timemap)

    def tempo_for(q):
        bpm = tempo_at[0][1] if tempo_at else 100
        for tq, t in tempo_at:
            if tq <= q + 1e-6:
                bpm = t
        return bpm

    # Walk the engraved pages: measure boxes and notehead positions
    measures = []          # in score order: {id, page, system, box(pct), notes: [(nid, staff_idx, x_center_pct)]}
    pages = tk.getPageCount()
    for page in range(1, pages + 1):
        svg = tk.renderToSVG(page)
        root = ET.fromstring(svg)
        inner = root.find(f"{SVG_NS}svg")
        vb_w, vb_h = [float(v) for v in inner.get("viewBox").split()[2:4]]
        margin = inner.find(f"{SVG_NS}g")
        mx, my = translate_of(margin)

        def px(x):
            return round((x + mx) / vb_w * 100, 3)

        def py(y):
            return round((y + my) / vb_h * 100, 3)

        system_idx = -1
        for system in margin.iter(f"{SVG_NS}g"):
            if "system" not in classes(system):
                continue
            system_idx += 1
            for measure in system.iter(f"{SVG_NS}g"):
                if "measure" not in classes(measure):
                    continue
                staves = [s for s in measure if s.tag == f"{SVG_NS}g" and "staff" in classes(s)]
                lines = [staff_lines(s) for s in staves]
                if not lines or not all(lines):
                    continue
                x1 = min(l[0] for l in lines)
                x2 = max(l[1] for l in lines)
                y1 = lines[0][2][0]
                y2 = lines[-1][2][-1]
                space = (lines[0][2][-1] - lines[0][2][0]) / 4
                notes = []
                for staff_idx, staff in enumerate(staves):
                    for note in staff.iter(f"{SVG_NS}g"):
                        if "note" not in classes(note) or note.get("id") not in note_on:
                            continue
                        head = next((g.find(f"{SVG_NS}use") for g in note
                                     if g.tag == f"{SVG_NS}g" and "notehead" in classes(g)), None)
                        if head is None:
                            continue
                        hx, _ = translate_of(head)
                        notes.append((note.get("id"), staff_idx, px(hx + 0.59 * space)))
                measures.append({
                    "id": measure.get("id"),
                    "page": page,
                    "system": system_idx,
                    "left_pct": px(x1),
                    "top_pct": py(y1),
                    "width_pct": round(px(x2) - px(x1), 3),
                    "height_pct": round(py(y2) - py(y1), 3),
                    "notes": notes,
                })
        with open(os.path.join(args.out_dir, f"page_{page}.svg"), "w", encoding="utf-8", newline="\n") as f:
            f.write(minify_svg(svg))

    starts = [measure_start.get(m["id"]) for m in measures]
    if any(s is None for s in starts) or len(measure_start) != len(measures):
        raise SystemExit("the engraved measures don't match the playback timeline")
    lengths = [round((starts[i + 1] if i + 1 < len(starts) else end_q) - starts[i], 4) for i in range(len(starts))]
    beats_per_measure = Counter(lengths).most_common(1)[0][0]
    base_bpm = round(tempo_for(0))

    score_data, layout, columns = [], [], {}
    for i, m in enumerate(measures):
        number = i + 1
        start = starts[i]
        label = tk.getElementAttr(m["id"]).get("n") or str(number)
        groups = defaultdict(list)
        onset_x = {}
        for nid, staff_idx, x in m["notes"]:
            beat = round(note_on[nid] - start + 1, 3)
            length = round(note_off.get(nid, note_on[nid]) - note_on[nid], 3)
            pitch = tk.getMIDIValuesForElement(nid)["pitch"]
            hand = "treble" if staff_idx in treble_staves else "bass"
            groups[(hand, beat, length)].append(pitch)
            onset_x[beat] = min(onset_x.get(beat, x), x)
        entry = {"number": number}
        if label != str(number):
            entry["label"] = label
        if abs(lengths[i] - beats_per_measure) > 1e-3:
            entry["beats"] = lengths[i]
        bpm = round(tempo_for(start))
        if bpm != base_bpm:
            entry["bpm"] = bpm
        for hand in ("treble", "bass"):
            entry[hand] = [
                {"chord": sorted(set(p)), "beat": b, "len": l}
                for (h, b, l), p in sorted(groups.items(), key=lambda kv: (kv[0][1], kv[0][2]))
                if h == hand
            ]
        score_data.append(entry)
        layout.append({k: m[k] for k in ("page", "system", "left_pct", "top_pct", "width_pct", "height_pct")} | {"number": number})
        columns[str(number)] = [[b, onset_x[b]] for b in sorted(onset_x)]

    with open(os.path.join(args.out_dir, "score.js"), "w", encoding="utf-8", newline="\n") as f:
        f.write("// luksMusic - generated by web/tools/build_score.py from " + os.path.basename(args.score) + "\n")
        f.write("window.SCORE_DATA = " + json.dumps(score_data, separators=(",", ":")) + ";\n")
        f.write("window.MEASURE_LAYOUT = " + json.dumps(layout, separators=(",", ":")) + ";\n")
        f.write("window.NOTE_COLUMNS = " + json.dumps(columns, separators=(",", ":")) + ";\n")
    with open(os.path.join(args.out_dir, "score.mid"), "wb") as f:
        f.write(base64.b64decode(tk.renderToMIDI()))

    seconds = sum(lengths[i] * 60 / tempo_for(starts[i]) for i in range(len(starts)))
    print(json.dumps({
        "measures": len(measures),
        "pages": pages,
        "bpm": base_bpm,
        "beatsPerMeasure": beats_per_measure,
        "durationLabel": f"{int(seconds // 60):02d}:{int(seconds % 60):02d}",
        "tempoChanges": len({round(t) for _, t in tempo_at}),
    }))


if __name__ == "__main__":
    main()
