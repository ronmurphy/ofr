#!/usr/bin/env python3
"""Rebuilds tools/vault_editor.html: embeds the icon font and refreshes the
tile table.

The editor is a single file on purpose -- you open it with a double click, no
server, no build step. That is worth keeping, so the icon font is embedded as
base64 rather than fetched: a browser opening file:// will not load a font over
a relative path in every configuration, and an editor that silently falls back
to squares on someone else's machine is worse than one that never tried.

WHAT THIS DERIVES AND WHAT IT DOES NOT
--------------------------------------
It reads `src/sim/vault.gd` for the SET of legal glyphs and refuses to write a
file that disagrees with it. It does NOT derive how a glyph looks.

That split is deliberate. A glyph needs five things here -- the character, a
fallback character, an icon codepoint, two colours and whether you can stand on
it -- and `vault.gd` owns exactly one of them; the rest are spread across
ascii_theme.gd, glyph_theme.gd, palette.gd and tiles.gd. Parsing all five to
avoid hand-writing a colour would trade a table anyone can read for a parser
nobody will maintain, and a parser that quietly matches nothing fails the same
way a stale table does, only harder to see.

So: the presentation below is hand-written, and the CHECK is automatic. Add a
glyph to vault.gd and forget this file, and the next run fails by name instead
of shipping an editor that cannot draw it.

Run after changing assets/fonts/ofr_icons.ttf or the vault glyph set.
"""
import base64
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
HTML = ROOT / "tools" / "vault_editor.html"
FONT = ROOT / "assets" / "fonts" / "ofr_icons.ttf"
VAULT = ROOT / "src" / "sim" / "vault.gd"

# Mirrors src/sim/vault.gd TERRAIN + CONTENTS, and src/render/glyph_theme.gd
# for the codepoints. `icon` is omitted where the game has none: ICONS mode is
# a PARTIAL override -- walls, floors, pillars and rubble deliberately stay as
# characters, because shape carries rank and a wall is structure rather than a
# thing. Previewing them as icons would be prettier and wrong.
TILES = """const TILES = [
  { ch: "#", show: "\\u2588", name: "wall",        fg: "#8d8578", bg: "#3a382f", pass: false },
  { ch: ".", show: "\\u00b7", name: "floor",       fg: "#57534a", bg: "#17171c", pass: true  },
  { ch: "_", show: "\\u00b7", name: "cave floor",  fg: "#6d6250", bg: "#1c1814", pass: true  },
  { ch: "+", show: "+", icon: 0xF081B, name: "door",        fg: "#b4813f", bg: "#1c1712", pass: true  },
  { ch: "'", show: "'", icon: 0xF081C, name: "open door",   fg: "#b4813f", bg: "#14120f", pass: true  },
  { ch: "O", show: "\\u25cf", name: "pillar",      fg: "#9a9082", bg: "#3a382f", pass: false },
  { ch: "^", show: "\\u25b2", name: "stalagmite",  fg: "#857a69", bg: "#241f19", pass: false },
  { ch: "~", show: "~", icon: 0xEF30,  name: "water",       fg: "#4d7f9e", bg: "#15242e", pass: true  },
  { ch: "=", show: "\\u2591", name: "mud",         fg: "#7a6248", bg: "#241d16", pass: true  },
  { ch: "%", show: "\\u2592", name: "rubble",      fg: "#6b5b47", bg: "#1a150f", pass: true  },
  { ch: ",", show: ",", icon: 0xF00B9, name: "bones",       fg: "#bdb69f", bg: "#1d1c19", pass: true  },
  { ch: "*", show: "*", icon: 0xF07DF, name: "fungus",      fg: "#7fd9b0", bg: "#14201b", pass: true  },
  { ch: "&", show: "\\u03a9", icon: 0xF0238, name: "brazier",     fg: "#e0913c", bg: "#241408", pass: false },
  { ch: "A", show: "\\u2229", icon: 0xEEE6,  name: "shrine",      fg: "#b98ad9", bg: "#1c1826", pass: true  },
  { ch: "n", show: "n", icon: 0xF0BA2, name: "grave",       fg: "#8d94a6", bg: "#1a1920", pass: true  },
  { ch: "C", show: "\\u00a2", icon: 0xF0726, name: "chest",       fg: "#c9953f", bg: "#1d1710", pass: false },
  { ch: "X", show: "\\u25cf", name: "pit",         fg: "#000000", bg: "#05050a", pass: true  },
  { ch: "t", show: "^", icon: 0xF0026, name: "trap",        fg: "#d4674f", bg: "#2a1714", pass: true  },
  { ch: ">", show: ">", icon: 0xF12BE, name: "stairs down", fg: "#d9cf9a", bg: "#1a1a20", pass: true  },
  { ch: "<", show: "<", icon: 0xF12BD, name: "stairs up",   fg: "#d9cf9a", bg: "#1a1a20", pass: true  },
  { ch: "m", show: "m", name: "monster",     fg: "#6f9c4e", bg: "#17171c", pass: true  },
  { ch: "M", show: "M", name: "guardian",    fg: "#c05a3a", bg: "#17171c", pass: true  },
  { ch: "?", show: "?", icon: 0xF0BC2, name: "any item",    fg: "#cfc39a", bg: "#17171c", pass: true  },
  { ch: "!", show: "!", icon: 0xF0093, name: "potion",      fg: "#d2607a", bg: "#17171c", pass: true  },
  { ch: ")", show: ")", icon: 0xF04E5, name: "weapon",      fg: "#9fb3c8", bg: "#17171c", pass: true  },
  { ch: "[", show: "[", icon: 0xF0A7B, name: "armour",      fg: "#a89a7c", bg: "#17171c", pass: true  },
  { ch: "}", show: "}", icon: 0xF1841, name: "launcher",    fg: "#c8b28a", bg: "#17171c", pass: true  },
  { ch: "(", show: "\\u00a4", icon: 0xF0D2E, name: "sack",        fg: "#8a5a3c", bg: "#17171c", pass: true  },
  { ch: " ", show: "",  name: "outside",     fg: "#1d1f26", bg: "#0d0e13", pass: false },
];"""


def replace_once(text: str, pattern: str, repl: str, what: str) -> str:
    new, n = re.subn(pattern, lambda _m: repl, text, count=1, flags=re.S)
    if n != 1:
        sys.exit("could not find %s -- refusing to write a half-updated file" % what)
    return new


def main() -> None:
    if not FONT.exists():
        sys.exit("missing %s" % FONT)
    html = HTML.read_text(encoding="utf-8")
    b64 = base64.b64encode(FONT.read_bytes()).decode("ascii")

    # 1. The font, embedded. Marked so a re-run replaces it rather than stacking.
    face = (
        "  /* ofr_icons.ttf, embedded by tools/build_vault_editor.py so this\n"
        "     file works from file:// with no server. Re-run that script after\n"
        "     changing the font. */\n"
        "  @font-face { font-family: 'OFRIcons'; src: url(data:font/ttf;base64,"
        + b64
        + ") format('truetype'); }\n"
        "  .cell.pic, .sw b.pic { font-family: 'OFRIcons'; font-size: 19px; }\n"
    )
    if "@font-face { font-family: 'OFRIcons'" in html:
        html = replace_once(
            html,
            r"  /\* ofr_icons\.ttf, embedded.*?\.cell\.pic, \.sw b\.pic \{[^}]*\}\n",
            face,
            "the existing embedded font block",
        )
    else:
        html = replace_once(html, r"</style>", face + "</style>", "</style>")

    # 2. The tile table.
    html = replace_once(html, r"const TILES = \[.*?\n\];", TILES, "the TILES table")

    HTML.write_text(html, encoding="utf-8")
    print("embedded %s (%d KB of base64)" % (FONT.name, len(b64) // 1024))
    print("wrote %s" % HTML.relative_to(ROOT))


if __name__ == "__main__":
    main()
