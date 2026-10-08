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
