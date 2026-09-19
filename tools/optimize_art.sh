#!/usr/bin/env bash
# Optimize the ASCII-look art PNGs in assets/art.
#
# These images are opaque (no transparency) and nearly greyscale with a few
# colored accents, so the wins are:
#   1. drop the alpha channel   -> ~25% of every file was a constant 0xFF plane
#   2. quantize to a 64-colour palette (PNG8) -> 24bpp becomes 8bpp
#   3. strip metadata, then re-deflate with oxipng
# 64 colours measures at ~43 dB PSNR on this art, which is visually identical
# (verified by eye on glyph-level crops); dropping to 32 costs 4 dB and saves
# only another ~5%, so 64 is the knee of the curve.
#
# On pngquant: measured on this art and NOT used, deliberately. It is tuned for
# photographic content, and on high-contrast ASCII glyphs ImageMagick's
# quantizer beats it at every quality level -- at a matched ~43 dB, magick at
# 64 colours came out ~10% smaller than pngquant at 32 across four test images.
# oxipng is a different matter: it is a lossless re-deflate and a free ~3.5%,
# so it is used whenever it is installed.
#
# Re-running is safe: an already-optimized file won't shrink further, and the
# script only replaces a file when the new one is actually smaller.
#
# Usage:
#   tools/optimize_art.sh                 # optimize assets/art in place
#   tools/optimize_art.sh --dry-run       # show what would happen, change nothing
#   tools/optimize_art.sh --colors 32     # tighter palette
#   tools/optimize_art.sh --max-dim 0     # skip the downscale step
#   tools/optimize_art.sh path/to/dir_or_file.png ...
set -uo pipefail

COLORS=64
MAX_DIM=720        # new art comes out 1080x1080; 0 disables resizing
MIN_PSNR=38        # refuse to replace a file if quantizing hurt it this much
DRY_RUN=0
TARGETS=()

die() { echo "error: $*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run|-n) DRY_RUN=1; shift ;;
    --colors)     COLORS="${2:?--colors needs a number}"; shift 2 ;;
    --max-dim)    MAX_DIM="${2:?--max-dim needs a number}"; shift 2 ;;
    --min-psnr)   MIN_PSNR="${2:?--min-psnr needs a number}"; shift 2 ;;
    -h|--help)    sed -n '2,/^set /p' "$0" | sed 's/^# \?//;$d'; exit 0 ;;
    -*)           die "unknown option $1" ;;
    *)            TARGETS+=("$1"); shift ;;
  esac
done

command -v magick >/dev/null || die "ImageMagick (magick) not found"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ ${#TARGETS[@]} -eq 0 ]] && TARGETS=("$REPO_ROOT/assets/art")

HAVE_OXIPNG=0; command -v oxipng >/dev/null && HAVE_OXIPNG=1

# Collect the PNGs to work on, skipping Godot's .import sidecars.
FILES=()
for t in "${TARGETS[@]}"; do
  if [[ -d "$t" ]]; then
    while IFS= read -r -d '' f; do FILES+=("$f"); done \
      < <(find "$t" -type f -iname '*.png' ! -iname '*.import' -print0 | sort -z)
  elif [[ -f "$t" ]]; then
    FILES+=("$t")
  else
    die "no such file or directory: $t"
  fi
done
[[ ${#FILES[@]} -eq 0 ]] && die "no PNG files found"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
PNGOPT=(-strip -define png:compression-level=9
        -define png:compression-filter=5 -define png:compression-strategy=1)

total_before=0; total_after=0; changed=0; skipped=0

printf '%-46s %10s %10s %8s  %s\n' FILE BEFORE AFTER SAVED NOTE
printf '%.0s-' {1..92}; printf '\n'

for f in "${FILES[@]}"; do
  name="$(basename "$f")"
  before=$(stat -c%s "$f")
  work="$TMP/work.png"
  out="$TMP/out.png"

  # Keep the alpha channel if it is ever actually used; on this art it never is.
  read -r amin _ < <(magick "$f" -alpha extract -format "%[fx:minima] " info:; echo)
  alpha_args=(-alpha off)
  note=""
  if [[ -n "$amin" && "$amin" != "1" ]]; then
    alpha_args=()
    note="has real alpha, kept"
  fi

  resize_args=()
  if [[ "$MAX_DIM" != "0" ]]; then
    resize_args=(-filter Lanczos -resize "${MAX_DIM}x${MAX_DIM}>")
  fi

  magick "$f" "${alpha_args[@]}" "${resize_args[@]}" "$work" \
    || { echo "  ! failed: $name" >&2; continue; }

  # +dither matters: dithering sprays noise into the flat regions between
  # glyphs and costs more in deflate than it buys back in fidelity.
  magick "$work" +dither -colors "$COLORS" "${PNGOPT[@]}" "PNG8:$out"
  [[ $HAVE_OXIPNG -eq 1 ]] && oxipng -o max --strip safe -q "$out" 2>/dev/null

  after=$(stat -c%s "$out")

  # Quality gate: compare against the resized source, since the downscale is
  # intentional and only the quantization is what we're policing here.
  psnr=$(magick compare -metric PSNR "$work" "$out" null: 2>&1 | awk '{print $1}')
  [[ "$psnr" == "inf" || -z "$psnr" ]] && psnr=99
  if awk -v p="$psnr" -v m="$MIN_PSNR" 'BEGIN{exit !(p<m)}'; then
    printf '%-46s %10d %10s %8s  %s\n' "$name" "$before" "-" "-" "SKIPPED: psnr ${psnr}dB < ${MIN_PSNR}dB"
    skipped=$((skipped+1)); total_before=$((total_before+before)); total_after=$((total_after+before))
    continue
  fi

  if [[ $after -ge $before ]]; then
    printf '%-46s %10d %10s %8s  %s\n' "$name" "$before" "-" "-" "already optimal"
    skipped=$((skipped+1)); total_before=$((total_before+before)); total_after=$((total_after+before))
    continue
  fi

  pct=$(awk -v b="$before" -v a="$after" 'BEGIN{printf "%.0f%%", (b-a)*100/b}')
  if [[ $DRY_RUN -eq 1 ]]; then
    printf '%-46s %10d %10d %8s  %s\n' "$name" "$before" "$after" "$pct" "would write${note:+ ($note)}"
  else
    cp "$out" "$f" || { echo "  ! could not write $f" >&2; continue; }
    printf '%-46s %10d %10d %8s  %s\n' "$name" "$before" "$after" "$pct" "${note:-ok}"
  fi
  changed=$((changed+1)); total_before=$((total_before+before)); total_after=$((total_after+after))
done

printf '%.0s-' {1..92}; printf '\n'
awk -v b="$total_before" -v a="$total_after" -v c="$changed" -v s="$skipped" -v d="$DRY_RUN" 'BEGIN{
  printf "%s %d file(s), left %d alone.  %.2f MB -> %.2f MB  (%.0f%% smaller)\n",
    (d ? "Would optimize" : "Optimized"), c, s, b/1048576, a/1048576, (b?(b-a)*100/b:0)
}'

[[ $HAVE_OXIPNG -eq 0 ]] && echo $'\nhint: install oxipng for a further ~3.5% (lossless); picked up automatically.'

if [[ $DRY_RUN -eq 0 && $changed -gt 0 ]]; then
  echo "note: Godot will re-import these on next editor launch."
fi
