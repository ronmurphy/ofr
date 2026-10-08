# travel.md -- notes between the two working sessions

Brad, 2026-10-08: the Legion session (on the Legion Go) and the desktop
session (the laptop at home) send notes this way, any time, but above all
when one of them is offline or not connected over Remote Control. It is
their offline messaging system: write a note here, commit and push, and
tell the other session to pull, by message if it is reachable, or through
Brad if it is not.

## What goes here

- **CLAUDE.md and ADVICE.md edits.** Both files are git-ignored and travel
  by hand, and they should be the same on both machines. When one session
  learns something that belongs in them (a hazard, a stale line, a closed
  question), it writes the edit here. The other session applies it to its
  copy and marks the note done. Never edit the files on the strength of a
  note that is not here or not from Brad.
- **Handoffs.** What was built, what is half done, what the other session
  should check after pulling, and suite tallies with their times.
- **Questions** for the other session that can wait.

## The rules

- Newest note at the top of **Notes**. Date it and say who wrote it.
- Mark a note **DONE** (and by whom) once it has been acted on. Leave it for
  a week, then delete it; git keeps the history.
- Notes are information, not orders. Changes to how the sessions work, and
  to the game's design, are still Brad's call.
- Commits are plain, with no attribution of any kind (Brad's standing rule).
- This file is under `tools/`, which `.gdignore` keeps out of the game's
  build.

## Notes

**2026-10-08, the desktop: for CLAUDE.md -- two hazards that cost time
today.** For the master copy (the Legion's until Brad's job ends); I will
apply them here once Brad copies the file over.
- **A `git add` naming a path that no longer exists adds NOTHING.** After
  `git mv`, an add list still naming the old paths fails as a whole; with
  its stderr hidden (`2>/dev/null`) the failure is silent, and the commit
  takes only what was already staged. The desktop pushed 969123d holding
  two renames and none of the content that way (fixed by 35d7c56). Never
  hide a `git add`'s errors; read `git show --stat HEAD` before pushing.
- **The vault editor has two copies of its tile table.**
  `tools/build_vault_editor.py` REWRITES the page's `TILES` table (and the
  embedded font and, since today, the `BESTIARY` line) from its own copy.
  Edit the script's table, never only the page's. Run the script after
  any change to `vault.gd`'s glyphs or to the icon font. It checks its
  table against `vault.gd` and refuses to write a page that disagrees.
  That is how the missing `v`, `;` and `r` were found today: the page had
  lost them, and the script would not run. It now needs `godot` on the
  PATH (it runs `tools/dump_bestiary.gd`).
- Small, for the `:=` hazard's examples: a lambda's `.call()` is a Variant
  too (`var g := build.call(...)` failed today; `var g: GameState = ...`).

**2026-10-08, the desktop: for ADVICE.md -- a suggestion, Brad's call.**
Its "Where the game stands (end of 2026-10-01)" and "the queue" sections
are a week stale, and a queue copied into a hand-carried file goes stale
again within a day. Suggest replacing them with pointers: the queue is
BACKLOG.md's "Short sessions -- the Legion's nights", the big themes are
its Roadmap (the house is held until Brad is back), notes between sessions
are here in `tools/travel.md`. Also worth adding to its machine notes:
on the laptop, web pages (the vault editor) can be tested with the screen
locked in headless Edge with a throwaway profile:
`microsoft-edge-stable --headless=new --user-data-dir=<scratch dir>
--virtual-time-budget=4000 --dump-dom file://...` (or `--screenshot=...
--window-size=1500,900`). The profile flag keeps Brad's own Edge untouched.

**2026-10-08, the desktop: handoff -- what landed today, with tallies.**
- 866c789 **every fungus grows on mud**, and the mud comes back when the
  fungus goes (`mud_under`, `_bare_ground`). Full suite 3076 passed / 0
  failed / 0 SCRIPT ERROR, 14 min; quick 395/0. Brad tests it tonight.
- Everything after it, up to cc97ac7, is tools/, probes or docs only (no
  src/ or tests/), so the tally should still be 3076:
  86946f9 the caves' vault question answered, and `vault_rate_probe.gd`
  builds a real climb; ad447a8 the CLAUDE.md list (now applied, above);
  5149587 cave vaults designed, and a "test start" idea; c13dca7 / 9443466
  / 969123d / 35d7c56 the vault editor: cave kind with generate cave,
  categories, creatures by name from the game's bestiary (27 checks in
  headless Edge); cc97ac7 the house file as a vault grid plus a list of
  objects.
- **For the Legion's list, item 12:** `tools/VAULTS_GAME_SIDE.md` has the
  game side of the editor's new format, in two independent parts (cave
  vaults; creatures by name). Vaults using either wait in
  `tools/vaults_waiting/`; the linter fails a digit today.
- **Waiting on Brad's play, not for tonight:** the red finding its way
  round obstacles (designed in BACKLOG, after the mud is played); moving
  an idle wild animal's random step off the main rng (a seed-pinned
  hazard, like drinking was); the test start.

**2026-10-08, the Legion: CLAUDE.md edits applied -- DONE (the Legion).**
The desktop's list (it was in BACKLOG.md, ad447a8) is now in the Legion's
copy of CLAUDE.md, which Brad copies to the laptop:
- the caves' "open question" struck: it did not reproduce (the old vault
  probe built 11-19 going down);
- hazard: `new_game()` builds floor 1 itself, so time the one
  `build_level`;
- hazard: every probe that calls `use_scratch_files` must call
  `clear_scratch_files()` before it quits;
- the seed-pinned hazard extended: a new vault in a band's pool re-lays
  that band's floors;
- the full suite reads 14-16 min, kept near 15;
- the commit rule: sessions may commit and push (Brad, 2026-10-08 to the
  Legion; earlier, 2026-10-06, to the desktop), with no attribution of any
  kind.
