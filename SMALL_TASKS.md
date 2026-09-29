# SMALL_TASKS.md — small, self-contained jobs

This file is for an AI coding assistant working on OFR, a Godot 4.7 GDScript
roguelike. It holds the rules for working here and a list of small jobs. Do
**one job at a time**, top to bottom, unless Brad names one.

Claude (the project's main coding assistant) reviews every job afterwards, so
leave clear notes.

---

## Before you start

0. **You work in a separate copy of the project**, not Brad's main one. First,
   bring it up to date: `git pull origin main`. Working on an old version
   means your changes land on stale code and can undo newer work when they
   are merged back.
1. **Read `CLAUDE.md`** in the project root, all of it. The "Hazards that have
   cost real time" and "Checks that cannot fail" sections matter most.
2. Read the job below, then the files it names. The code comments in this
   project are detailed and explain why things are the way they are. Match
   their style: comment the *why*, not the *what*.

## Rules

1. **Never commit, push or publish.** Brad does that by hand -- **one commit
   per job**, so any single job can be undone with one `git revert`. Finish
   the job, leave the changes uncommitted, and say it is ready.
2. **Write tests for whatever you add.** Anything visual, or anything the two
   map views share, goes in `tests/run_view_tests.gd`; everything else in
   `tests/run_tests.gd`. Read a few existing checks and copy their style:
   `check("what should be true", condition, "detail if it fails")`.
   Every block of "this is refused" checks needs one check that must SUCCEED,
   and check the precondition, not only the outcome.
3. **Run the quick suite after every change** (about 3 seconds). Both copies
   of the project share one Godot save folder, so every test command here
   starts with `XDG_DATA_HOME=/home/brad/ofr-freemodel-data`, which gives this
   copy its own:

       XDG_DATA_HOME=/home/brad/ofr-freemodel-data godot --headless --script tests/run_view_tests.gd > /tmp/view.log 2>&1
       grep -c "SCRIPT ERROR" /tmp/view.log      # must print 0
       grep -E "passed, .* failed" /tmp/view.log  # must say 0 failed

   **A tally is not a pass.** A script error stops a test silently and the
   tally still prints, so the error count must be 0 as well.
4. **Run the full suite before you say a job is done** (about 10 minutes):

       XDG_DATA_HOME=/home/brad/ofr-freemodel-data godot --headless --script tests/run_tests.gd > /tmp/full.log 2>&1
       grep -c "SCRIPT ERROR" /tmp/full.log      # must print 0
       grep -E "passed, .* failed" /tmp/full.log  # must say 0 failed

   If the tally line is missing, the run did not finish -- that is a failure.
   Never run two suites at the same time, and never edit a `.gd` file while a
   suite is running.
5. **Both map views.** The game has a classic glyph view (`glyph_grid.gd`) and
   a 3D view (`diorama_view.gd`). Anything drawn on the map must work in both,
   through the shared effects layer (`src/render/fx.gd`): the game records an
   event once and each view draws it.
6. **Respect the "still" effects mode.** `Effects.any()` is false on "still";
   anything that moves or animates must not play then (some players get
   motion sickness).
7. **GDScript traps** (from CLAUDE.md): never `Array.shuffle()`; never
   `var x := something_untyped` inside a loop over `entities`, `ground`,
   `items_at()` or a bare `[...]` -- write `var x: int = ...`; any new file
   the game writes for the player needs a static path that
   `GameState.use_scratch_files()` redirects, from its first commit.
8. **If a job needs a design choice the text does not settle, do not guess.**
   Write your question under the job, leave it unticked, and stop or move on.

## Marking a job done

Tick its box and add a **Done** note under it, like this:

    - [x] **Job name**
      Done 2026-10-02: what you changed (files), which tests you added, and the
      suite results (quick N passed / full N passed, 0 script errors).

---

## Jobs

- [ ] **Inventory labels: "food & potions", and a "uniques" group**
  In `src/ui/inventory_panel.gd`: the tab (chip) labelled "potions" and the
  POTIONS heading also hold food (haunches of meat), so rename them to
  "food & potions" / "FOOD & POTIONS". Add a **uniques** group -- a tab and a
  UNIQUES heading -- for items with `item.unique == true` (the ring of the rat,
  the undertaker's shovel, and more later); a unique appears there and NOT in
  the group its kind would otherwise put it in (the ring currently shows under
  WEAPONS). Equipped items still show under EQUIPPED as now. See the `Filter`
  enum, the chip list and the headings near the top of the file, and the
  filter test around line 162. Check the tab row still fits the panel. Tests:
  a unique lands in uniques and not in weapons; food lands in food & potions.

- [ ] **Healing you can see**
  A `healed` event (it carries `"amount"`) already plays a small green ring on
  the map, but the inventory stays open after drinking or eating, so a heal
  from the pack is never seen. Add: (a) a **green flare on the sidebar's HP
  bar** when HP rises -- the mirror of the red flare when you are hit (see
  `_hit_at` and the `pulse` drawing in `src/ui/sidebar.gd`) -- with the newly
  regained part of the bar glowing briefly; (b) a **floating green "+N"**
  over the player on the map, like the damage numbers (see how `popup`
  effects are made in `src/render/fx.gd`). The popup is motion, so not on
  "still"; the HP bar flare is UI, like the red one. Tests: the popup appears
  for a heal and not at full health; nothing on still.

- [ ] **Weapon contact marks you can see**
  `Fx.contact_marks` (in `src/render/fx.gd`) draws the melee contact mark as
  blocks a tenth of a cell across, for 0.22 s, in `Palette.HIT_FLASH` -- the
  same colour as the hit flash under it, so players cannot see it. Make the
  blocks about a quarter of a cell, the life about 0.35 s, and give them a
  colour of their own (a steel white, clearly different from HIT_FLASH).
  Keep the three shapes (slash arc, pierce line, blunt cross). Update the
  existing contact tests in `tests/run_view_tests.gd` if they check sizes.

- [ ] **A screenshot key (F9)** -- Gabe's request
  F9 saves a picture of the game. (F12 opens a browser's developer tools and
  Steam uses it for its own screenshots, so not F12.) Desktop: save a PNG to a
  screenshots folder under `user://` -- a **static path that
  `GameState.use_scratch_files()` redirects** (CLAUDE.md rule) -- with a
  timestamp in the name, and put a line in the message log saying where it
  went. In a browser (itch.io): hand the picture over as a download using
  `Platform.hand_over` in `src/platform.gd` (the pause menu's morgue export
  already does this). Leave the F8 pad watch out of the picture (hide it for
  that frame). Handle the key in `_unhandled_key_input` in
  `src/render/main.gd`, near the F8 pad watch. Add F9 to the legend's key
  list (`Sidebar.KEYS`). Tests: the path is redirected under scratch files;
  F9 is listed in the legend.
