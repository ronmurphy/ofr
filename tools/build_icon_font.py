"""Rebuild assets/fonts/ofr_icons.ttf from the full Nerd Font.

    python3 tools/build_icon_font.py

The map is drawn entirely with this subset, so it has to contain every
character any theme can put on screen. It derives that list FROM THE THEMES
rather than from a hand-kept list, because a hand-kept list is exactly what
went wrong before: the letters mode draws Omega for braziers and a cap for
shrines, neither survived the original subsetting, and for as long as the mode
existed those four tiles rendered as blank coloured squares. Nothing errored,
and the test that should have caught it was checking the wrong font.

So: read AsciiTheme.TABLE for characters, GlyphTheme.OVERRIDES for codepoints,
add ASCII and a few box-drawing pieces the wall renderer uses, and subset to
exactly that. Add a monster, run this, and its glyph is in the font.

It also measures every glyph in the result and writes src/render/glyph_metrics.gd,
which the 3D view sizes its billboards from. To rewrite only that file from the
font already shipped, without rebuilding the font:

    python3 tools/build_icon_font.py --metrics

And to rewrite only tools/icon_names.json (the Nerd Font name of every icon
the themes use, for tools/art_reference.gd):

    python3 tools/build_icon_font.py --names

Requires fonttools:  pip install fonttools
"""
import pathlib
import re
import subprocess
import sys

ROOT = pathlib.Path(__file__).parent.parent
SOURCE = ROOT / "tools" / "fonts" / "JetBrainsMonoNerdFontMono-Regular.ttf"
OUT = ROOT / "assets" / "fonts" / "ofr_icons.ttf"
ASCII_THEME = ROOT / "src" / "render" / "ascii_theme.gd"
GLYPH_THEME = ROOT / "src" / "render" / "glyph_theme.gd"
SYMBOL_THEME = ROOT / "src" / "render" / "symbol_theme.gd"
## Not a theme, but it names a codepoint: the look panel draws md-skull for
## "killed by". Scanned for the same reason the themes are -- so the subset is
## derived from what the game actually asks for, and adding an icon anywhere
## never means remembering to edit a list over here as well.
SIDEBAR = ROOT / "src" / "ui" / "sidebar.gd"
## Written from the finished font, never by hand -- see write_metrics().
METRICS = ROOT / "src" / "render" / "glyph_metrics.gd"

## Everything printable, so the map, the legend and every panel can render text
## through the same face if they ever need to.
BASE = set(range(0x20, 0x7F))

GRID = ROOT / "src" / "render" / "glyph_grid.gd"

## The wall renderer draws its corners from a table of its own rather than from
## a theme, so those characters are invisible to the theme scan. Read from that
## table for the same reason everything else here is read rather than listed:
## a blanket range(0x2500, 0x2580) worked, and doubled the shipped font for 128
## box pieces nothing draws.
def box_chars():
    if not GRID.exists():
        return set()
    text = GRID.read_text()
    start = text.find("const BOX := {")
    if start < 0:
        return set()
    end = text.find("}", start)
    return {ord(ch) for m in re.finditer(r'"(.)"', text[start:end])
            for ch in m.group(1)}


def chars_in(path):
    """Every literal character a theme can draw."""
    out = set()
    if not path.exists():
        return out
    for m in re.finditer(r'"ch":\s*"((?:\\.|[^"])*)"', path.read_text()):
        text = m.group(1).replace('\\"', '"').replace("\\\\", "\\")
        for ch in text:
            out.add(ord(ch))
    return out


def codepoints_in(path):
    """Every 0x... codepoint a theme names."""
    if not path.exists():
        return set()
    return {int(m.group(1), 16)
            for m in re.finditer(r"0x([0-9A-Fa-f]{4,5})", path.read_text())}


def main():
    if not SOURCE.exists():
        print("missing source font: %s" % SOURCE)
        print("download JetBrainsMono Nerd Font and put it there.")
        return 1

    wanted = set(BASE) | box_chars()
    wanted |= chars_in(ASCII_THEME)
    wanted |= chars_in(SYMBOL_THEME)
    wanted |= codepoints_in(GLYPH_THEME)
    wanted |= codepoints_in(SIDEBAR)

    # Alternates: a handful of spares per role, so changing one's mind about a
    # picture costs a line in GlyphTheme rather than a font rebuild. Kept
    # because that promise is written down in the README.
    keep_spares = sorted(c for c in _current_spares() if c not in wanted)
    wanted |= set(keep_spares)

    from fontTools.ttLib import TTFont
    src_cmap = TTFont(SOURCE).getBestCmap()
    have = set(src_cmap)

    # Does each codepoint's comment say what that codepoint actually IS?
    #
    # The check below only proves a codepoint exists in the source font, which
    # is true of any number typed by mistake. `&"bear": 0xF0A72,  # md-paw`
    # passed every test for a day and drew md-solar_power, because the real
    # md-paw is 0xF03E9. A comment asserting what a hex number means is a claim
    # nothing was verifying -- so verify it.
    wrong = []
    for path in (GLYPH_THEME, SIDEBAR):
        if not path.exists():
            continue
        for m in re.finditer(r"(0x[0-9A-Fa-f]{4,5})\s*,?\s*#\s*([a-z]+-[a-z0-9_]+)",
                             path.read_text()):
            cp = int(m.group(1), 16)
            claimed = m.group(2)
            actual = src_cmap.get(cp)
            if actual != claimed:
                wrong.append("   %s in %s says %s, is actually %s"
                             % (m.group(1), path.name, claimed, actual or "absent"))
    if wrong:
        print("CODEPOINT COMMENTS THAT LIE:")
        for w in wrong:
            print(w)
        return 1

    missing = sorted(c for c in wanted if c not in have)
    if missing:
        print("NOT IN THE SOURCE FONT -- these would render as nothing:")
        for c in missing:
            print("   U+%04X" % c)
        return 1

    unicodes = ",".join("U+%04X" % c for c in sorted(wanted))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    cmd = [sys.executable, "-m", "fontTools.subset", str(SOURCE),
           "--unicodes=" + unicodes, "--output-file=" + str(OUT),
           "--layout-features=", "--drop-tables+=DSIG",
           # No hinting. Godot rasterises with its own settings and the map is
           # drawn at 16-18px where TrueType hinting does nothing visible --
           # but the cvt/fpgm/prep tables it lives in are a third of the file.
           # The subset that shipped before this script existed had them
           # stripped too; rediscovered by measuring 32KB against its 20KB.
           "--no-hinting", "--notdef-outline"]
    before = OUT.stat().st_size if OUT.exists() else 0
    subprocess.run(cmd, check=True)
    after = OUT.stat().st_size
    print("  %d codepoints -> %s" % (len(wanted), OUT.relative_to(ROOT)))
    print("  %d bytes (was %d)" % (after, before))
    print("  source is %d bytes, so this ships %.1f%% of it"
          % (SOURCE.stat().st_size, 100.0 * after / SOURCE.stat().st_size))
    return write_metrics()


def write_metrics():
    """Measure every glyph in the shipped font and write glyph_metrics.gd.

    The 3D view stands pictures up as billboards and sizes them in map cells,
    which needs to know how much of each glyph's em box is actually drawn. The
    font does not normalise its icons -- md-human_child is 928 units tall and
    md-human 666 -- so sizing by the em box would put the size ladder back to
    front, the bug GlyphTheme.GLYPH_SCALE exists to correct in the classic
    view. Measured here, from the same file the game loads, so the numbers
    cannot drift from the font the way a hand-kept table would.
    """
    from fontTools.ttLib import TTFont
    from fontTools.pens.boundsPen import BoundsPen
    if not OUT.exists():
        print("missing font: %s" % OUT)
        return 1
    font = TTFont(OUT)
    upm = float(font["head"].unitsPerEm)
    hhea = font["hhea"]
    glyphs = font.getGlyphSet()
    hmtx = font["hmtx"]
    rows = []
    for cp, name in sorted(font.getBestCmap().items()):
        pen = BoundsPen(glyphs)
        glyphs[name].draw(pen)
        if pen.bounds is None:
            continue  # nothing drawn: space and friends
        x0, y0, x1, y1 = pen.bounds
        advance = hmtx[name][0]
        rows.append("\t0x%04X: [%.3f, %.3f, %.3f, %.3f, %.3f],  # %s" % (
            cp, advance / upm, x0 / upm, y0 / upm, x1 / upm, y1 / upm, name))
    METRICS.write_text("\n".join([
        "class_name GlyphMetrics",
        "extends RefCounted",
        "",
        "## GENERATED by tools/build_icon_font.py from assets/fonts/ofr_icons.ttf.",
        "## Do not edit: run `python3 tools/build_icon_font.py --metrics` and this",
        "## file is rewritten from the font itself.",
        "",
        "## The font's line box, in em. Label3D lays text out from these.",
        "const ASCENT := %.3f" % (hhea.ascent / upm),
        "const DESCENT := %.3f" % (-hhea.descent / upm),
        "",
        "## codepoint -> [advance, ink left, ink bottom, ink right, ink top], in em,",
        "## measured from the pen position on the baseline, y upwards.",
        "const GLYPHS := {",
        *rows,
        "}",
        "",
    ]))
    print("  %d glyphs measured -> %s" % (len(rows), METRICS.relative_to(ROOT)))
    return 0


def _current_spares():
    """Icons already in the shipped subset that no theme names yet.

    Preserved across rebuilds so the existing alternates do not silently vanish
    the first time this runs.
    """
    from fontTools.ttLib import TTFont
    if not OUT.exists():
        return set()
    named = codepoints_in(GLYPH_THEME)
    return {c for c in TTFont(OUT).getBestCmap() if c >= 0xE000 and c not in named}


## The source font names its glyphs (md-door_closed, fa-monument, cod-person);
## the subset does not. tools/art_reference.gd shows an artist which icon each
## picture is, so every codepoint a theme (or the sidebar) names is looked up
## here and written beside its name. Rerun when an icon is added.
NAMES = ROOT / "tools" / "icon_names.json"


def write_names():
    import json
    from fontTools.ttLib import TTFont
    cmap = TTFont(SOURCE).getBestCmap()
    cps = set()
    for path in (GLYPH_THEME, SIDEBAR):
        cps |= codepoints_in(path)
    names = {"U+%X" % cp: cmap.get(cp, "") for cp in sorted(cps) if cp >= 0xE000}
    NAMES.write_text(json.dumps(names, indent=1) + "\n")
    missing = [k for k, v in names.items() if not v]
    print("wrote %s: %d icons named%s" % (NAMES.relative_to(ROOT), len(names),
        ", UNNAMED: %s" % missing if missing else ""))
    return 1 if missing else 0


if __name__ == "__main__":
    if "--metrics" in sys.argv[1:]:
        raise SystemExit(write_metrics())
    if "--names" in sys.argv[1:]:
        raise SystemExit(write_names())
    code = main()
    write_names()
    raise SystemExit(code)
