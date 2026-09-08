"""Can you tell two creatures apart if they share a glyph?

    python3 tools/check_palette.py

Reads the creature colours out of src/render/ascii_theme.gd and checks every
pair that would share an icon, under normal vision and under the three
dichromacies. Anything below deltaE 25 is reported.

Why this exists: while the creatures are letters, colour never has to be
distinct -- `g` and `T` tell a goblin from a cave troll however similar their
greens are, and in the shipped palette those two measure deltaE 5.4. The moment
shape stops carrying the difference, colour has to, and it has to survive the
roughly 8% of men with a red-green deficiency.

The first palette drafted for the icon mode failed exactly there: kobold gold
against goblin green measured 46.7 normally and 14.5 under protanopia. Separate
on LIGHTNESS, not on red-green, and it holds up.

SHARED lists the creatures that would draw the same figure. Edit it when the
icon mapping changes.
"""
import re
import pathlib
import sys

ROOT = pathlib.Path(__file__).parent.parent
THEME = ROOT / "src" / "render" / "ascii_theme.gd"

# Creatures that would draw the same figure, so colour does all the work.
SHARED = {
    "child figure": ["kobold", "goblin"],
    "adult figure": ["orc", "wight", "wizard"],
    "heavy figure": ["ogre", "troll"],
    "dragon":       ["wyvern", "dragon"],
    # Not literally the same glyph -- one ghost is filled and one is hollow --
    # but close enough in silhouette that colour is doing real work, and the
    # two demand opposite responses. Checked as though they shared.
    "ghost shapes": ["shadow", "banshee"],
    # Same glyph, and the colour change IS the tell that it transformed.
    "rabbit":       ["rabbit", "killer_rabbit"],
}

READABLE = 25.0  # deltaE below this is hard to tell apart on a dark ground

# Vienot/Brettel dichromat simulation, applied in linear RGB.
SIM = {
    "protan": [[0.1121, 0.8853, -0.0005], [0.1127, 0.8897, -0.0001],
               [0.0045, 0.0085, 1.0000]],
    "deutan": [[0.2920, 0.7054, -0.0003], [0.2934, 0.7089, 0.0000],
               [-0.0209, 0.0272, 0.9942]],
    "tritan": [[1.0000, 0.1502, -0.1504], [0.0000, 0.8493, 0.1508],
               [0.0000, 0.3174, 0.6826]],
}


def srgb(h):
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))


def lin(c):
    return tuple(u / 12.92 if u <= 0.04045 else ((u + 0.055) / 1.055) ** 2.4
                 for u in c)


def lab(rgb):
    r, g, b = lin(rgb)
    x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047
    y = 0.2126 * r + 0.7152 * g + 0.0722 * b
    z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883

    def f(u):
        return u ** (1 / 3) if u > 0.008856 else 7.787 * u + 16 / 116
    return (116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z)))


def delta_e(a, b):
    return sum((x - y) ** 2 for x, y in zip(lab(a), lab(b))) ** 0.5


def simulate(rgb, kind):
    r, g, b = lin(rgb)
    m = SIM[kind]
    out = [m[i][0] * r + m[i][1] * g + m[i][2] * b for i in range(3)]

    def unlin(u):
        u = max(0.0, min(1.0, u))
        return 12.92 * u if u <= 0.0031308 else 1.055 * (u ** (1 / 2.4)) - 0.055
    return tuple(unlin(u) for u in out)


def load_colours():
    """Creature id -> hex, straight out of the theme table."""
    text = THEME.read_text()
    out = {}
    for m in re.finditer(
            r'&"(\w+)":\s*\{"ch": "(?:[^"]|\\")+", "fg": Color\("([0-9a-fA-F]{6})"\)',
            text):
        out[m.group(1)] = m.group(2)
    return out


# Wounds are drawn as a wash UNDER a creature rather than a tint on it, so they
# do not enter into this at all. That was not the first design: tinting toward a
# shared red collapsed these pairs -- a critical wyvern and a critical dragon
# measured deltaE 15.5 under deuteranopia, which is one creature. Keeping the
# two signals on different properties is what makes them independent.


def main():
    colours = load_colours()
    missing = [c for pair in SHARED.values() for c in pair if c not in colours]
    if missing:
        print("  not found in the theme table: " + ", ".join(missing))
        print("  (SHARED probably needs updating for a rename)")
        return 1

    print()
    print("  creatures that would share a glyph, so colour is all there is:")
    print()
    bad = 0
    for figure, members in SHARED.items():
        for i in range(len(members)):
            for j in range(i + 1, len(members)):
                if True:
                    a, b = srgb(colours[members[i]]), srgb(colours[members[j]])
                    scores = [("normal", delta_e(a, b))]
                    scores += [(k, delta_e(simulate(a, k), simulate(b, k)))
                               for k in SIM]
                    worst = min(s for _, s in scores)
                    line = "  %-13s %-8s vs %-8s " % (
                        figure, members[i], members[j])
                    line += "  ".join("%s %5.1f" % (n, s) for n, s in scores)
                    if worst < READABLE:
                        bad += 1
                        line += "   <-- TOO CLOSE"
                    print(line)
    print()
    if bad:
        print("  %d pair(s) indistinguishable. Separate them on LIGHTNESS --" % bad)
        print("  red against green is the axis that disappears first.")
    else:
        print("  every shared-glyph pair holds up under all four.")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
