#!/usr/bin/env bash
# Builds the web export and zips it the way itch.io wants it.
#
#   tools/build_web.sh [outdir]        # default: build/web
#
# itch.io serves the contents of the zip directly, so index.html has to sit at
# the ROOT of the archive -- not inside a folder. That is the single mistake
# that makes an upload land on a blank page, and `zip -j` is what avoids it.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="${1:-$root/build/web}"
zipfile="$root/build/ofr-web.zip"

mkdir -p "$out" "$root/build"
rm -f "$out"/index.* "$zipfile"

echo "==> exporting to $out"
godot --headless --export-release "Web" "$out/index.html"

# The engine is ~40MB raw and ~10MB gzipped. itch serves it compressed, so the
# number that matters to a player on a phone tether is the second one.
raw=$(du -sb "$out" | cut -f1)
mb() { awk -v b="$1" 'BEGIN { printf "%.1f", b / 1048576 }'; }
# python rather than `zip`, which is not installed everywhere and is not worth
# a dependency for one archive.
echo "==> zipping"
python3 - "$out" "$zipfile" <<'PYZIP'
import sys, zipfile, pathlib
src, dst = pathlib.Path(sys.argv[1]), sys.argv[2]
with zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for f in sorted(src.glob("index.*")):
        z.write(f, f.name)          # flat: index.html at the archive root
PYZIP
gz=$(stat -c%s "$zipfile")

printf '\n  raw      %8s MB\n' "$(mb "$raw")"
printf '  zipped   %8s MB   %s\n\n' "$(mb "$gz")" "$zipfile"

echo "  upload $zipfile to itch.io, tick \"This file will be played in the"
echo "  browser\", and set the embed to 1600 x 900 with fullscreen enabled."
