#!/usr/bin/env bash
# Pushes the built exports to itch.io through butler.
#
#   tools/publish.sh              # all three channels
#   tools/publish.sh linux        # just one
#   tools/publish.sh --force      # publish anyway with a dirty tree
#
# SEPARATE FROM THE BUILD SCRIPTS ON PURPOSE. Building is local, cheap and
# reversible -- it happens a dozen times in an afternoon of testing. Publishing
# is immediate and public. Folding a push into build_linux.sh would mean every
# experiment reached everybody who follows the page, and the only way back is
# to notice and undo it.
#
# It also replaces a five-minute manual loop: open the page in a browser,
# upload three files, then on the handheld download, extract with Ark, and
# copy into place. The itch app does the far half automatically once these
# channels exist.
#
# CHANNEL NAMES ARE LOAD-BEARING. itch reads the platform off the channel:
# "linux" and "windows" get tagged as those platforms, and "html5" is what
# marks the web build playable in the browser. Rename one and the upload still
# succeeds while quietly landing as an untagged file nobody's launcher will
# pick up.
#
# Directories rather than the .tar.gz/.zip, deliberately: butler diffs file by
# file, so after the first upload it sends only the changed bytes, and it
# records the executable bit -- which is the thing build_linux.sh ships a
# tarball to preserve. The archives stay for people downloading by hand.
set -euo pipefail

# Same trick as build_linux.sh: resolved from the script's own location, so it
# does not matter what directory you run it from. Getting this wrong is what
# produced "open build/linux: no such file or directory" the first time.
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
game="ronmurphy/ofr-old-fashioned-roguelike"

force=0
build=0
want=""
for arg in "$@"; do
  case "$arg" in
    --force) force=1 ;;
    --build) build=1 ;;
    linux|windows|html5) want="$arg" ;;
    *) echo "unknown argument: $arg" >&2; exit 2 ;;
  esac
done

# `--build` exists because publishing a stale build is the easy mistake here:
# publish.sh uploads what is in build/, and nothing about running it suggests
# that those files might predate your last commit. Still OFF by default --
# building and publishing stay separate acts, because one is local and cheap
# and the other is public and immediate.
if (( build )); then
  for s in linux windows web; do
    echo "==> building $s"
    "$root/tools/build_$s.sh" >/dev/null
  done
fi

if ! command -v butler >/dev/null; then
  echo "butler is not installed." >&2
  exit 1
fi

# A published build you cannot trace back to a revision is a bug report you
# cannot reproduce. The version stamp below is only meaningful if the tree it
# was built from is committed.
dirty=""
if [[ -n "$(git -C "$root" status --porcelain 2>/dev/null)" ]]; then
  dirty="-dirty"
  if (( force == 0 )); then
    echo "  the working tree has uncommitted changes, so this build cannot be" >&2
    echo "  traced to a commit. Commit first, or pass --force if you meant it." >&2
    git -C "$root" status --short >&2
    exit 1
  fi
fi
version="$(git -C "$root" rev-parse --short HEAD 2>/dev/null || echo unknown)$dirty"

push() {
  local dir="$root/build/$1" channel="$2"
  if [[ ! -d "$dir" ]]; then
    echo "  no $dir -- run tools/build_${3}.sh first" >&2
    return 1
  fi
  # Newer source than build means you are about to publish yesterday's game.
  local newest_src newest_build
  # `|| true` because `head -1` closes the pipe early and find exits non-zero
  # on SIGPIPE, which `set -e` would otherwise treat as a failed publish.
  # build_info.gd is EXCLUDED, and it has to be. tools/stamp_build.sh restores
  # it immediately after each export, so it is always newer than the build that
  # just finished -- which made every build look stale forever, in all three
  # channels, the moment stamping was added. A warning that fires every single
  # time teaches you to ignore it, which is worse than not having one.
  newest_src=$(find "$root/src" "$root/scenes" -type f -newer "$dir" \
    ! -name build_info.gd 2>/dev/null | head -1 || true)
  if [[ -n "$newest_src" ]]; then
    echo "  ! $dir is older than $(basename "$newest_src") -- rebuild first?" >&2
  fi
  echo "==> $channel  ($version)"
  butler push "$dir" "$game:$channel" --userversion "$version"
}

if [[ -n "$want" ]]; then
  case "$want" in
    linux)   push linux   linux   linux ;;
    windows) push windows windows windows ;;
    html5)   push web     html5   web ;;
  esac
else
  push linux   linux   linux
  push windows windows windows
  push web     html5   web
fi

echo
echo "  https://ronmurphy.itch.io/ofr-old-fashioned-roguelike"
echo "  butler status $game     # to watch them finish processing"
