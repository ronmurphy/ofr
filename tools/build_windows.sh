#!/usr/bin/env bash
# Builds the Windows export and zips it for itch.io.
#
#   tools/build_windows.sh [outdir]    # default: build/windows
#
# Cross-compiled from Linux: Godot's windows_release_x86_64 export template
# does the work, so no Wine or Windows machine is involved.
#
# The export embeds the .pck inside OFR.exe (binary_format/embed_pck in
# export_presets.cfg), so the result is ONE file, same as the Linux build.
#
# .zip rather than .tar.gz here because Windows Explorer opens zip natively and
# nothing on a stock Windows box opens a .tar.gz. The executable bit that makes
# tar the right call on Linux is meaningless on Windows, so there is nothing to
# lose by using zip.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="${1:-$root/build/windows}"
exe="$out/OFR.exe"
archive="$root/build/ofr-windows-x86_64.zip"

mkdir -p "$out" "$root/build"
rm -f "$exe" "$out"/OFR.pck "$out"/OFR.console.exe "$archive"

# --path, not cd: Godot locates the project from the working directory, so
# without this the script only works when run from the project root.
echo "==> exporting to $out"
godot --headless --path "$root" --export-release "Windows" "$exe"

if [[ -f "$out/OFR.pck" ]]; then
  echo "  ! a .pck was produced, so the export did not embed it." >&2
  echo "    check binary_format/embed_pck under [preset.2.options] in" >&2
  echo "    export_presets.cfg -- it needs to be true." >&2
  exit 1
fi

# python3 rather than `zip`, which is not installed here and is not worth a
# dependency for one archive -- same call build_web.sh makes.
echo "==> packing $archive"
python3 - "$out" "$archive" <<'PYZIP'
import sys, zipfile, pathlib
src, dst = pathlib.Path(sys.argv[1]), sys.argv[2]
with zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for f in sorted(src.glob("OFR*.exe")):
        z.write(f, f.name)          # flat: OFR.exe at the archive root
PYZIP

mb() { awk -v b="$1" 'BEGIN { printf "%.1f", b / 1048576 }'; }
printf '\n  %-24s %8s MB\n' "OFR.exe" "$(mb "$(stat -c%s "$exe")")"
printf '  %-24s %8s MB   %s\n\n' "$(basename "$archive")" "$(mb "$(stat -c%s "$archive")")" "$archive"

echo "  upload $archive to itch.io and tick \"Windows\" as the platform."
echo "  leave \"This file will be played in the browser\" UNTICKED -- that is"
echo "  the web zip's job."
echo
echo "  players unzip it and run OFR.exe; there is nothing else to install."
echo "  SmartScreen will warn on first run because the exe is unsigned"
echo "  (codesign/enable is false) -- \"More info\" then \"Run anyway\"."
