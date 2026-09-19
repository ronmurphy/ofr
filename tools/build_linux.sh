#!/usr/bin/env bash
# Builds the desktop Linux export and packs it for itch.io.
#
#   tools/build_linux.sh [outdir]      # default: build/linux
#
# This exists for the Steam Deck / ROG Ally / Legion Go players. The web build
# cannot see a gamepad reliably through a browser, and it cannot write
# user://pad_log.txt anywhere you can retrieve it. Both of those are the whole
# point of the controller work, so handheld testing needs a native binary.
#
# The export embeds the .pck inside the executable (binary_format/embed_pck in
# export_presets.cfg), so the result is ONE file. It used to be two -- an
# executable plus a matching .pck -- and copying only the executable gave a
# "Error: Couldn't load project data" dialog and nothing else. One file makes
# that mistake impossible.
#
# It ships as .tar.gz rather than .zip on purpose: tar records the executable
# bit, zip does not. From a zip the player has to know to chmod +x before the
# game will start, which on a handheld usually means it just looks broken.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="${1:-$root/build/linux}"
bin="$out/ofr.x86_64"
archive="$root/build/ofr-linux-x86_64.tar.gz"

mkdir -p "$out" "$root/build"
# ofr.pck is deliberate: it is left over from the pre-embed builds, and a stale
# one sitting beside the new binary is exactly the confusion this change removes.
rm -f "$out"/ofr.x86_64 "$out"/ofr.pck "$archive"

# --path, not cd, for the same reason as build_web.sh: Godot finds the project
# from the working directory otherwise, and the script only works from root.
echo "==> exporting to $out"
godot --headless --path "$root" --export-release "Linux" "$bin"
chmod +x "$bin"

if [[ -f "$out/ofr.pck" ]]; then
  echo "  ! a .pck was produced, so the export did not embed it." >&2
  echo "    check binary_format/embed_pck under [preset.0.options] in" >&2
  echo "    export_presets.cfg -- it needs to be true." >&2
  exit 1
fi

# -C so the archive is flat: ofr.x86_64 at the root, no build/linux/ prefix
# wrapped around it.
echo "==> packing $archive"
tar -czf "$archive" -C "$out" ofr.x86_64

mb() { awk -v b="$1" 'BEGIN { printf "%.1f", b / 1048576 }'; }
printf '\n  %-22s %8s MB\n' "ofr.x86_64" "$(mb "$(stat -c%s "$bin")")"
printf '  %-22s %8s MB   %s\n\n' "$(basename "$archive")" "$(mb "$(stat -c%s "$archive")")" "$archive"

echo "  upload $archive to itch.io and tick \"Linux\" as the platform."
echo "  leave \"This file will be played in the browser\" UNTICKED -- that is"
echo "  the web zip's job."
echo
echo "  to run it on a handheld:"
echo "    tar -xzf $(basename "$archive") && ./ofr.x86_64"
echo
echo "  NOTE: on a Steam Deck, add it to Steam as a non-Steam game and launch"
echo "  it from there. Run from the desktop directly and Steam Input blanks the"
echo "  real device node, so Godot sees no gamepad at all."
echo
echo "  to capture what the pad reports:  ./ofr.x86_64 --pad-log"
echo "  the log lands in ~/.local/share/godot/app_userdata/OFR/pad_log.txt"
