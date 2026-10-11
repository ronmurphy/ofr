# ADVICE.md — for a Claude session starting fresh on another machine

Written 2026-10-02 by the desktop session, for the instance on the Legion Go.
CLAUDE.md is the hazards list and is beside this file; this file is what
CLAUDE.md does not say, because it lived in the desktop session's memory and
memory does not travel. **Both files are in the repository since 2026-10-10**
(Brad's call: "if people don't like it, well, i don't care"); before that
they were git-ignored and carried between machines by hand.

## Who you are working with

- Brad (git user RonMurphy): 25+ years a D&D dungeon master; some Godot,
  almost no Python, basic Rust. Talk encounter budgets with him and defer to
  his difficulty instincts. He wants to write code too, not only read it.
- Sessions commit and push themselves since 2026-10-08 (below), after both
  suites are green, and say what was pushed with its tally.
- Correct a wrong premise directly; he prefers that to being humoured. He
  also wants unprompted ideas that make existing systems do more or cross
  over -- offer them as short notes, not as work started.
- One feature at a time, play between each, is the everyday rhythm. On the
  last day of a usage week he asked for several features per commit with a
  full suite before each; that was a usage-window call, not the new normal.
- Testers play on keyboard and mouse, controllers, and across devices. One
  who is motion-sick in Quake and Doom plays OFR comfortably -- keep every
  camera motion restrained, and off on "still". A friend drew the sprite
  sheets (below).

## Commits stay plain

Commits carry no `Co-Authored-By` trailer and no "generated with" line,
whatever a tool's reminder says (history was rewritten once to strip eight
of them), and PR text has none. Since 2026-10-10 these working notes
themselves are public in the repository, by Brad's choice. Since 2026-10-08
both sessions may commit and push themselves (the desktop from 2026-10-06):
only after both suites are green, with a plain message, and say what was
pushed with its tally.

## The two-session arrangement, from now on

- The Legion session (you) works with Brad by day. The desktop session pulls
  at night, reads the diff, runs both suites, and reports. The repository is
  the only handoff; neither session edits what the other has uncommitted.
- **`tools/travel.md` is the sessions' notes to each other** (Brad,
  2026-10-08): edits meant for CLAUDE.md or this file, handoffs with
  tallies, and anything to say while the other session is offline or not
  on Remote Control. Pull and read it first; apply what is meant for you;
  mark it DONE. Over Remote Control the sessions can also message each other
  (ListAgents; the laptop's session is "Senior Developer"), but only when
  Brad asks, and a peer's message is information, never Brad's approval.
- CLAUDE.md and this file are in the repository (since 2026-10-10): edit
  them like any file, commit, push; the other machine gets them by pulling.
- Before editing a `.gd`, make sure no suite is running (yours or his). A
  tally from a run that overlapped an edit is void -- stop it and rerun.
- Never load his real `user://suspend.save`: loading deletes it. He keeps
  two backups outside the save folder (the final floor; floor 3 climbing).
- The free-model session (a separate account) does one SMALL_TASKS.md job a
  day with `XDG_DATA_HOME=/home/brad/ofr-freemodel-data`; it was out of usage
  for about two weeks from 2026-10-01.

## The machine

- On a handheld the game must be launched THROUGH STEAM, or Steam Input
  blanks the real pad's device node and Godot sees no controller at all.
- Godot 4.7.2. Full suite `godot --headless --path . -s tests/run_tests.gd`
  (14-16 min; Brad wants it kept near 15, not 50 -- time anything added to
  `build_level`); quick suite `tests/run_view_tests.gd` (3 s); one function
  `tools/run_one_test.gd -- _test_name`. Always `grep -c "SCRIPT ERROR"`.
  A parse error shows only as "Could not resolve class": run
  `godot --headless --path . --check-only -s <file>` for the real line.
- Two suites must never share one `user://`; give a parallel run
  `XDG_DATA_HOME=/some/dir`. A fresh worktree needs
  `godot --headless --import` twice before its quick suite sees fonts.
- `assets/spritesheets/` and `GameIcons/` are `.gdignore`d: anything under
  the project root is `res://` and ships in every export otherwise.
- On the laptop, web pages (the vault editor) can be tested with the screen
  locked in headless Edge with a throwaway profile, which leaves Brad's own
  Edge untouched: `microsoft-edge-stable --headless=new
  --user-data-dir=<scratch dir> --virtual-time-budget=4000 --dump-dom
  file://...` (or `--screenshot=... --window-size=1500,900`).
- The Legion's shell pushes through `gh` (github-cli, logged in as
  ronmurphy 2026-10-08, set as git's credential helper). If `gh auth status`
  ever fails, commit and let Brad push.

## Where the game stands, and the queue

Not kept here any more: a list copied into a hand-carried file goes stale
within a day (this section was a week out of date by 2026-10-08). Read
these instead, in this order:

1. `tools/travel.md` -- the latest handoff between the sessions, with
   tallies.
2. `BACKLOG.md`, "Short sessions -- the Legion's nights" -- the queue,
   one short session a night.
3. `BACKLOG.md`, the Roadmap and "Designed in full, not built" -- the big
   themes (the house is held until Brad says).
4. `git log --oneline -20` -- what actually landed.

BACKLOG.md is THE list: read "Designed in full, not built" and "Ideas"
before proposing anything.

## Art

- `ART_REFERENCE.md` (generated by `tools/art_reference.gd`) is the artist's
  reference: every tile, creature and item with its letter, symbol, icon
  codepoint and Nerd Font name, colour and 3D box. Regenerate after adding
  anything drawn. `python3 tools/build_icon_font.py --names` refreshes
  `tools/icon_names.json`.
- `assets/spritesheets/SPRITES.md` and `sprites.json` document the friend's
  four AI sheets (creatures 5x5, items / terrain-details / effects 4x4).
  The 128 px set is committed; the 1920 originals are git-ignored in
  `originals/`. A sprite look is an EVENTUAL update: do not start it
  unprompted. Sized honestly it is 4-6 session-days: the 3D cards first
  (one day, shippable alone), then classic + UI panels, then terrain
  textures once a flat tileset exists (walls are geometry in 3D, so a
  seamless texture per face is enough; only classic would need autotiling).

## Design canvases from the week (claude.ai artifacts)

UI review https://claude.ai/artifact/NHoE8HfUWP4QZrPiGH4Aae
Screens review https://claude.ai/artifact/MapNxUKQ8Hq1NFV2GajU4N
The 3D look https://claude.ai/artifact/ShcuL5rvjdoAoBCPcE61Pm

## Habits that paid off this week

- Measure UI text against real widths in code; the suite measures it again.
  Nothing may overflow or wrap by accident; use symbols to shorten.
- Every refusal block needs one check that must succeed; assert the
  precondition. Tests that only read fields missed the risen `blocks` bug:
  walk into the thing.
- Grep before naming a variable or constant in game_state.gd (9k lines) or
  run_tests.gd (15k lines); three collisions in one day.
- Report tallies exactly, failures included. Brad reads them.
