#!/usr/bin/env bash
# Writes the current git revision into src/sim/build_info.gd, or puts it back.
#
#   tools/stamp_build.sh stamp      # before an export
#   tools/stamp_build.sh restore    # after one
#
# The build scripts call both, with `restore` on a trap so an interrupted or
# failed export cannot leave a stamped file behind -- which would otherwise
# show up as a dirty tree and get committed by accident, baking one build's
# hash into every later one.
#
# Restores by WRITING "dev" rather than by `git checkout`, so it still works
# before this file has ever been committed, and in a tree where the file has
# been deliberately changed.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target="$root/src/sim/build_info.gd"

write() { sed -i "s|^const BUILD := .*|const BUILD := \"$1\"|" "$target"; }

case "${1:-stamp}" in
  stamp)
    # Read BEFORE writing, or this script would see the file it is about to
    # change and report every build as dirty.
    dirty=""
    if [[ -n "$(git -C "$root" status --porcelain 2>/dev/null)" ]]; then
      dirty="+"
    fi
    n="$(git -C "$root" rev-list --count HEAD 2>/dev/null || echo 0)"
    sha="$(git -C "$root" rev-parse --short HEAD 2>/dev/null || echo unknown)"
    write "b${n}${dirty} ${sha}"
    echo "  stamped b${n}${dirty} ${sha}"
    ;;
  restore)
    write "dev"
    ;;
  *)
    echo "usage: stamp_build.sh [stamp|restore]" >&2
    exit 2
    ;;
esac
