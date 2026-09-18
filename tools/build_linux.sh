#!/usr/bin/env bash
# Builds the desktop Linux export -- the one that runs on a handheld.
#
#   tools/build_linux.sh [outdir]      # default: build/linux
#
# This exists for the Steam Deck / ROG Ally / Legion Go players. The web build
# cannot see a gamepad reliably through a browser, and it cannot write
# user://pad_log.txt anywhere you can retrieve it. Both of those are the whole
# point of the controller work, so handheld testing needs a native binary.
#
# The result is TWO files that must travel together: the executable and the
# .pck beside it, with matching basenames. Copying only the executable gives a
# "Error: Couldn't load project data" dialog and nothing else.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="${1:-$root/build/linux}"
bin="$out/ofr.x86_64"

mkdir -p "$out"
rm -f "$out"/ofr.x86_64 "$out"/ofr.pck

# --path, not cd, for the same reason as build_web.sh: Godot finds the project
# from the working directory otherwise, and the script only works from root.
echo "==> exporting to $out"
godot --headless --path "$root" --export-release "Linux" "$bin"
chmod +x "$bin"

mb() { awk -v b="$1" 'BEGIN { printf "%.1f", b / 1048576 }'; }
printf '\n  %-14s %8s MB\n' "ofr.x86_64" "$(mb "$(stat -c%s "$bin")")"
printf '  %-14s %8s MB\n\n' "ofr.pck" "$(mb "$(stat -c%s "$out/ofr.pck")")"

echo "  copy BOTH files to the handheld, keep them in the same folder, then:"
echo "    chmod +x ofr.x86_64 && ./ofr.x86_64"
echo
echo "  to capture what the pad reports:  ./ofr.x86_64 --pad-log"
echo "  the log lands in ~/.local/share/godot/app_userdata/OFR/pad_log.txt"
