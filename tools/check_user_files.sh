#!/usr/bin/env bash
#
# Proves no dev tool can write to a file the player owns.
#
#   tools/check_user_files.sh
#
# Three tools learned this lesson independently. The test suite called
# clear_suspend() on the real path and deleted a live suspended run on every
# run. The screenshot tool ate the same slot by instantiating the real scene.
# The sound audition tool did too, and went unnoticed for a week. The morgue
# filled with fictional deaths the same way: 868 of 869 entries were test
# output rather than deaths anyone had died.
#
# Every headless tool must call GameState.use_scratch_files() before it
# touches a GameState. This plants a suspend.save, runs all of them, and
# checks the checksum afterwards.
set -uo pipefail
D=~/.local/share/godot/app_userdata/OFR
cd /home/brad/Documents/ofr
S=/tmp/claude-1000/-home-brad-Documents-ofr/23718967-03ec-4fbf-b3c3-9616687223e2/scratchpad

# Plant a desktop suspend that must survive everything, and note the morgue.
echo "PLANTED-SAVE-DO-NOT-DELETE-$(date +%s)" > "$D/suspend.save"
before_save=$(sha256sum "$D/suspend.save" | cut -d' ' -f1)
before_morgue=$(sha256sum "$D/morgue.txt" | cut -d' ' -f1)
echo "planted a suspend.save and recorded both checksums"

for tool in run_tests vault_lint xp_curve; do
  echo "  running $tool ..."
  timeout 400 godot --headless --script "res://tests/$tool.gd" >/dev/null 2>&1
done
echo "  running audition ..."
timeout 200 godot --headless --script res://tests/audition.gd -- "$S" >/dev/null 2>&1
echo "  running capture ..."
timeout 300 godot --script res://tests/capture.gd -- "$S" >/dev/null 2>&1

echo
after_save=$( [ -f "$D/suspend.save" ] && sha256sum "$D/suspend.save" | cut -d' ' -f1 || echo "GONE" )
after_morgue=$(sha256sum "$D/morgue.txt" | cut -d' ' -f1)
echo "suspend.save : $( [ "$before_save" = "$after_save" ] && echo 'UNTOUCHED' || echo "CHANGED/DELETED -> $after_save" )"
echo "morgue.txt   : $( [ "$before_morgue" = "$after_morgue" ] && echo 'UNTOUCHED' || echo 'CHANGED' )"
echo "contents     : $(cat "$D/suspend.save" 2>/dev/null || echo '(file gone)')"
echo
echo "leftover scratch files in user data:"
ls "$D" | grep -i scratch || echo "  none"
rm -f "$D/suspend.save"
echo "(removed the planted file)"
