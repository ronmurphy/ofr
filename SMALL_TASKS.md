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
4. **Do NOT run the full suite** (`tests/run_tests.gd`). It takes about ten
   minutes, and checking on it while it runs uses up Brad's usage quickly --
   every check re-reads the whole conversation (2026-09-29: most of a day's
   allowance went to waiting on it). Claude runs the full suite when it
   reviews your work. The quick suite above is your check. Never edit a `.gd`
   file while any suite is running.
   **To run the full-suite tests you wrote or touched**, run just those, in
   seconds, by name:

       XDG_DATA_HOME=/home/brad/ofr-freemodel-data godot --headless --path . -s tools/run_one_test.gd -- _test_name_here > /tmp/one.log 2>&1
       grep -c "SCRIPT ERROR" /tmp/one.log       # must print 0
       tail -1 /tmp/one.log                      # must say 0 failed
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
      quick suite result (N passed, 0 failed, 0 script errors).

## Lessons from reviews

Claude reviews each round. What it found, so the next job avoids it:

- **2026-09-29, round 1 (all four jobs): good work** -- clean code in the
  project's style, careful failure handling, accurate done notes, tests
  written. Two bugs got through:
  1. **The HP bar's heal glow was 14 px short**, so a heal under about 6% of
     max HP (a fungus, +1) drew nothing: one edge was measured with the bar's
     left margin (PAD) and the other without. The tests checked the inputs
     and the popup, not the drawn width. **Lesson: test the thing that is
     DRAWN -- the rectangle, the size -- with the smallest real case (+1).**
  2. **F9 in a browser left every PNG in the page's storage** after handing
     it over as a download. **Lesson: in a browser, user:// is the page's
     own storage, invisible to the player; a file written only to be
     downloaded must be deleted afterwards.**

---

## Jobs

**One-time authorization (Brad, 2026-09-29):** Brad expressly authorized
combining the final three jobs into one uncommitted change because his head was
hurting and he thought looking at a monitor was most likely the issue. He asked
for one quick run followed by one full run after the combined work, and said not
to commit or push so he can review and do that later. This exception is for this
task list only.

- [x] **Inventory labels: "food & potions", and a "uniques" group**
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

  Done 2026-09-29: renamed the food and potion chip/group, added a uniques-only
  chip/group with explicit chip-order cycling, and tightened chip spacing so
  the row fits. Added coverage for unique grouping/filtering, equipped uniques,
  food grouping, cycling, and chip bounds in `inventory_panel.gd` and
  `tests/run_tests.gd`. Quick: 245 passed / 0 failed, 0 script errors. Full:
  2,202 passed / 0 failed, 0 script errors. The full log also includes error
  output from existing malformed-data tests and Godot teardown resource notices.

- [x] **Healing you can see**
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

  Done 2026-09-29: added a brief green flare over the HP bar's restored
  segment in `src/ui/sidebar.gd`, and a motion-gated floating `+N` popup in
  `src/render/fx.gd`; the existing healing ring remains. Added view checks for
  the restored segment, popup amount/colour, full health, and still mode in
  `tests/run_view_tests.gd`. Quick: 250 passed / 0 failed, 0 script errors.
  Full: 2,206 passed / 0 failed, 0 script errors. The full log includes
  expected parse errors from malformed-data fixtures and Godot teardown
  resource notices.

- [x] **Weapon contact marks you can see**
  `Fx.contact_marks` (in `src/render/fx.gd`) draws the melee contact mark as
  blocks a tenth of a cell across, for 0.22 s, in `Palette.HIT_FLASH` -- the
  same colour as the hit flash under it, so players cannot see it. Make the
  blocks about a quarter of a cell, the life about 0.35 s, and give them a
  colour of their own (a steel white, clearly different from HIT_FLASH).
  Keep the three shapes (slash arc, pierce line, blunt cross). Update the
  existing contact tests in `tests/run_view_tests.gd` if they check sizes.

  Done 2026-09-29: enlarged contact marks to a quarter-cell and 0.35 s, and
  gave them a steel-white colour in both renderers while preserving all three
  weapon shapes. Updated contact view checks in `tests/run_view_tests.gd`.
  Quick: 250 passed / 0 failed, 0 script errors. Full: 2,206 passed / 0
  failed, 0 script errors. The full log includes expected parse errors from
  malformed-data fixtures and Godot teardown resource notices.

- [x] **A screenshot key (F9)** -- Gabe's request
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

  Done 2026-09-29: F9 now captures a timestamped PNG without the F8 pad watch,
  saves it under the redirected screenshot directory on desktop, and downloads
  it as `image/png` in the browser; the message log reports the result. Added
  the F9 legend entry and path/key checks in `tests/run_tests.gd`. Quick: 250
  passed / 0 failed, 0 script errors. Full: 2,206 passed / 0 failed, 0 script
  errors. The full log includes expected parse errors from malformed-data
  fixtures and Godot teardown resource notices.

- [ ] **Vault symbols for purple and red fungus**
  In `src/sim/vault.gd`, the `TERRAIN` table maps a vault file's characters to
  tiles; `*` is green fungus (and stays green -- Brad's rule: vault fungus is
  guaranteed green unless drawn otherwise). Add two characters for
  `Tiles.FUNGUS_PURPLE` and `Tiles.FUNGUS_RED`. Suggested: `:` purple, `;`
  red -- first CHECK they are not already used anywhere in vault.gd (content
  markers too) or in any file under `assets/vaults/`; if either is taken, pick
  another hard-to-mistype character and say which. Document them wherever the
  vault format is described (search the repo for the `*` fungus entry). Tests:
  a small vault layout string using both characters produces the two tiles.

- [ ] **Spores off purple and red fungus**
  `src/render/small_life.gd` makes pale green spores drift up off GREEN fungus
  (`Tiles.FUNGUS`), in both views. Make purple and red fungus give off spores
  too, each in its own colour (`Palette.FUNGUS_PURPLE`, `Palette.FUNGUS_RED`),
  sharing the existing limits (MAX_FUNGUS and the nearest-first rule) so a
  big infested cave costs no more than now. Motion only (not on "still"),
  as the green ones already are. Tests in `tests/run_view_tests.gd`: a purple
  fungus in view produces spores of the purple colour; none on still.

- [ ] **A burn effect**
  Burning the wrong fungus (`_burn_fungus` in `src/sim/game_state.gd`) reuses
  the forge's event (`{"kind": &"forge", ...}`) for its picture and sound. Give
  it its own event, `&"burn"`, with its own effect in `src/render/fx.gd` -- a
  short burst of orange and red embers rising from the square, both views,
  not on "still" -- and in `src/audio/sound_deck.gd` have `burn` play the same
  sound the forge does. Remember `Fx.expired` must learn any new effect type
  (read its comment). Tests: burning emits a `burn` event (not `forge`); the
  effect expires; nothing on still.

- [ ] **Test litter in the save folder**
  Three tests in `tests/run_tests.gd` switch to their own scratch files inside
  a loop -- `use_scratch_files("bearfit%d")`, `"pity%d_%d"` and
  `"reach%d_%d_%s"` -- and leave `scratch_bearfit*`, `scratch_pity*` and
  `scratch_reach*` files behind in the player's save folder after every run.
  Clean up after each: call `GameState.clear_scratch_files()` before switching
  tag, and restore the suite's own tag (`"tests"`) after the loop.
  `clear_scratch_files()` (in `src/sim/game_state.gd`) also misses the
  scratch SETTINGS file -- add `SETTINGS_PATH` to what it removes, only when
  the path contains "scratch_" (the same guard the others use; never the real
  settings.cfg). Check: run those three test functions with
  `tools/run_one_test.gd`, then list the save folder
  (`$XDG_DATA_HOME/godot/app_userdata/OFR/`) -- no `scratch_` files left.


- [ ] **The miasma cloud's shape: rounded in 3D, angled corners in classic**
  Today every square of a purple fungus's cloud is tinted as a plain square
  (`Palette.MIASMA`, which is violet at alpha 0.32). The squares are listed by
  `GameState.miasma_cloud()` (a Dictionary of `Vector2i -> true`; skip squares
  whose tile is `Tiles.FUNGUS_PURPLE` -- the fungus draws itself). Change only
  the DRAWING; which squares are in the cloud must not change.
  **3D (`src/render/diorama_view.gd`, `_add_miasma`):** replace the one-quad-
  per-square MultiMesh with ONE flat quad covering the whole map, textured by
  a small picture of the cloud: an `Image` of exactly `map.width` x
  `map.height` pixels (ONE pixel per map square), where a cloud square is
  `Palette.MIASMA` and everything else is fully transparent (alpha 0). Make an
  `ImageTexture` from it and draw it with LINEAR filtering (not nearest) --
  that smoothing is what rounds the corners and merges overlapping clouds
  into one blob. The quad is `map.width` world units by `map.height` world
  units (a map square is exactly 1 world unit), its corner at world (0, 0),
  lying flat at height `WASH_Y` (the constant already used), so pixel (x, y)
  of the image sits exactly over map square (x, y). Material: unshaded, alpha
  transparency, the texture as albedo, texture filter linear. Rebuild it where
  `_add_miasma` is called now (once per world rebuild), and only the squares
  you can see (`map_visible(c)`) go into the picture, as now. Keep
  `miasma_count` = the number of squares painted (a test reads it).
  **Classic (`src/render/glyph_grid.gd`, the "miasma's cloud" loop in
  `_draw`):** keep one tint per square, but draw each as a polygon with its
  OUTER corners cut: for each of the square's four corners, if BOTH of the
  two squares that share that corner edge (the one beside it and the one
  above/below it) are NOT in the cloud, cut that corner off with a straight
  diagonal, removing a triangle whose two short sides are each 30% of
  `cell_size`. Corners inside the cloud stay square, so the cloud's edge
  steps diagonally and its inside stays solid. Same colour, `Palette.MIASMA`.
  **Also, on "simple" and "full" only (`Effects.any()`):** let the cloud
  drift -- in 3D, slowly scroll the texture's offset or wobble its alpha by
  no more than +/-0.08 over about 3 seconds; in classic, the same small alpha
  wobble. On "still", no movement at all.
  **Tests (`tests/run_view_tests.gd`):** the existing check "the miasma's
  cloud is tinted in 3D" must still pass; add a check that the 3D cloud is
  now ONE node (not one per square), and a check of the classic corner rule
  as a pure function (e.g. a static `cut_corners(cell, cloud) -> Array` of
  which corners are cut) on a lone square (all four cut) and on a square in
  the middle of a 3x3 cloud (none cut).
