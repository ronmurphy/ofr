#!/usr/bin/env python3
"""Fills assets/sprites/ with a STARTER drawing for every look the game can put
on a 3D card that has none yet: the look's icon from the game, drawn onto its
canvas by the sprite editor's own "from the game" template code, in the colour
the 3D view draws it, outlined. Something to draw over, so the pixel look is
whole from the first day and gets better one file at a time.

Creatures and items only: terrain features (braziers, stairs, the web...)
keep their pictures until one is drawn by hand.

NEVER OVERWRITES. A look that already has a file anywhere under assets/sprites/
is skipped, so a hand-drawn sprite is safe from this script for good. A new
creature or item in the game gets its starter on the next run.

Each starter carries a first line saying it is one. The editor does not keep
lines it does not know, so a sprite opened and saved from the editor loses the
line -- the file itself then says it has been drawn by hand:

    grep -L "^# starter" -r assets/sprites    # the hand-drawn ones

How: runs tools/sprite_editor.html (rebuild it first with
tools/build_vault_editor.py, which embeds the list of looks) in headless
Microsoft Edge, with a few lines added to a scratch copy that make every
template and print them into the page.

    python3 tools/make_starter_sprites.py
"""
import json
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
EDITOR = ROOT / "tools" / "sprite_editor.html"
OUT = ROOT / "assets" / "sprites"
STARTER = "# starter: the game's icon for this look, made by tools/make_starter_sprites.py -- draw over it"

DUMP_SCRIPT = """
<script>
(async () => {
  const out = {};
  for (const look of LOOKS) {
    await iconTemplate(look);
    out[look.app] = {group: look.group, text: serialise()};
  }
  const pre = document.createElement("pre");
  pre.id = "starter-dump";
  pre.textContent = JSON.stringify(out);
  document.body.appendChild(pre);
})();
</script>
"""


def browser() -> str:
    for name in ("microsoft-edge-stable", "microsoft-edge", "chromium", "google-chrome"):
        path = shutil.which(name)
        if path:
            return path
    sys.exit("no headless browser found (looked for Edge, Chromium, Chrome)")


def existing() -> set:
    return {p.stem for p in OUT.rglob("*.txt")} if OUT.exists() else set()


def main() -> None:
    html = EDITOR.read_text(encoding="utf-8")
    if re.search(r"const LOOKS = \[\];", html):
        sys.exit("the editor's LOOKS list is empty: run tools/build_vault_editor.py first")
    with tempfile.TemporaryDirectory() as tmp:
        page = pathlib.Path(tmp) / "editor.html"
        # The editor ends without a </body>; a script after everything else
        # runs once the editor's own has.
        page.write_text(html + DUMP_SCRIPT, encoding="utf-8")
        dom = subprocess.run(
            [browser(), "--headless=new", "--disable-gpu",
             "--user-data-dir=" + str(pathlib.Path(tmp) / "profile"),
             "--virtual-time-budget=20000", "--dump-dom", page.as_uri()],
            capture_output=True, text=True, timeout=180).stdout
    m = re.search(r'<pre id="starter-dump">(.*?)</pre>', dom, re.S)
    if not m:
        sys.exit("the editor printed no templates -- open it in a browser and look for an error")
    raw = m.group(1).replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", '"').replace("&amp;", "&")
    looks = json.loads(raw)
    have = existing()
    wrote = 0
    for app, row in looks.items():
        # Terrain features keep their pictures until someone DRAWS one: a
        # starter would turn every brazier and staircase into a pictogram.
        if app in have or row["group"] == "terrain features":
            continue
        folder = OUT / ("items" if row["group"] == "items" else "creatures")
        folder.mkdir(parents=True, exist_ok=True)
        (folder / (app + ".txt")).write_text(STARTER + "\n" + row["text"], encoding="utf-8")
        wrote += 1
    print("%d looks, %d already drawn, %d starters written (terrain features are never started)"
          % (len(looks), len(have & set(looks)), wrote))


if __name__ == "__main__":
    main()
