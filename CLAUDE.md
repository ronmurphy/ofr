# CLAUDE.md — read this before reporting a bug

Working notes for any Claude session on OFR. Its job is to stop the same
conversations happening every few days.

The repo's own comments are unusually good and mostly explain themselves. What
they cannot tell you is which surprising numbers are **deliberate**. That list
lives here.

**Read `ADVICE.md` next** (same folder). It holds
what this file does not: who Brad is and how he works, the no-AI-attribution
rule, the two-machine arrangement from 2026-10-02 (the Legion Go session
codes by day; the desktop session pulls and reviews at night), where the game
stands and the queue. Both files are in the repository since 2026-10-10
(Brad's call), so they travel by `git pull` like everything else.

---

## Design decisions that look like bugs

A measurement that contradicts your expectation is not automatically a finding.
Check it against this list first.

### The caves are deliberately sparse. This is not a generation fault.

**Fewer rooms, fewer items, fewer authored vaults, fewer drops — on purpose, on
both the descent and the climb.** Brad has confirmed this repeatedly, most
recently 2026-09-20, and it has been re-reported as a bug more than once.

The caves are the challenge band. The intent:

- Players get used to a steady flow of loot in the room bands. The caves take
  that away and make them **work with what they already have and make it last**.
- It pushes the player toward **combining gems and weapons at the brazier**
  rather than waiting for a magic item to drop.
- The food chain — **bear → rabbit → fungus**, giving meat, meat and fungus —
  is the deliberate replacement for potions down there. Sustain comes from
  hunting and foraging, not from consumables you found.
- Monsters dropping items, including magical ones, exists partly to keep the
  caves survivable without restoring room-band loot density.

**So: do not "fix" cave sparsity, and do not report it as an anomaly.** If a
probe shows caves generating less of something than the room bands, that is the
design working. What IS worth reporting is a cave floor that is *unplayable* —
unreachable stairs, no food source at all, a sealed vault — because that is a
different claim from "it has less".

Authored vaults have a **second, separate reason** on top of the above: a
hand-drawn masonry room in a cavern reads as a mistake. Even if the
challenge-band argument were dropped, caves would still want few vaults.

**Do not trust the comment above that rule.** `mapgen.gd:212` says *"Caves get
none at all"*; the code four lines below gives caves one vault on 25% of
floors. Both sessions on 2026-09-20 read the comment as the design and the
measured 25% as an anomaly, and spent time on the gap between them. It is the
load-bearing kind of wrong comment: it asserts a GUARANTEE, so nobody checks.

**The old "open question" is closed (2026-10-08).** Descent and climb caves
seemed to place vaults at different rates (about 3 sigma). It did not
reproduce: the old `vault_rate_probe.gd` built floors 11-19 by setting the
depth going DOWN, a floor the game never builds. The probe now builds a
real climb, and the two halves agree (`cave_vault_halves_probe.gd`).

---

## Hazards that have cost real time

These are documented at length in the day-7 bug hunt notes; the short version:

- **`SCRIPT ERROR` aborts a test function silently** and the suite still prints
  a tally. Always `grep -c "SCRIPT ERROR"`. Never trust the count alone.
- **A tally line absent from the log means the run did not finish.** `FAILs: 0`
  on a partial log is meaningless.
- **`settings.cfg` and `gamepad.cfg` are the player's files.**
  `use_scratch_files()` redirects both now (`SETTINGS_PATH`, `PadConfig.PATH`),
  and the suite checks both are untouched at the end. The pad file was missed
  until 2026-09-24: closing the controller screen saves, the suite closes it,
  and for two days every run wrote a half-finished test walk-through over
  Brad's real bindings. **Any new player-owned file needs a static path that
  `use_scratch_files()` moves, from its first commit.**
- **Searches that lie:** `grep -v` matches whole lines including the filename
  prefix, so an exclusion aimed at call sites can silently eat an entire file.
  `pgrep -f <name>` matches the searching command itself.
- **`:=` cannot infer a type from a Variant**, and `entities`, `ground`,
  `items_at()` and bare `[...]` literals are all untyped. `var x := row.field`
  inside a loop over one of them is a parse error that fails the whole file,
  which reports as `FAILs: 0` and no output because nothing compiled. Write
  `var x: int = ...` instead. A lambda's `.call()` is a Variant too:
  `var g := build.call(...)` fails; write `var g: GameState = build.call(...)`.
- **Never `Array.shuffle()`.** It draws on Godot's global rng and breaks seed
  reproducibility. Anything whose NUMBER OF DRAWS varies with content needs its
  own `RandomNumberGenerator` seeded from the run: see `grave_rng`,
  `enchant_rng`, `trader_rng`.
- **`.gitignore` does not stop Godot importing.** They are unrelated systems.
  Anything under the project root is `res://`, so Godot scans it on open, writes
  a `.import` beside every file, and -- because all three export presets are
  `export_filter="all_resources"` and only exclude `tools/*,tests/*` -- BAKES IT
  INTO THE SHIPPED BUILD. `GameIcons/` is 6.2 MB and 1355 files; that is most of
  the web build's size budget, for a reference library nothing loads. The fix is
  an empty **`.gdignore`** in the folder, which is what `tools/.gdignore`
  already does. A `.gdignore`d folder is invisible to `res://`, which is correct
  here: when a specific icon is wanted, copy that one file into `assets/`, where
  it is imported, tracked and exported like everything else.

- **Screenshots with the screen locked:** Godot skips drawing when its window
  cannot be shown, so `await RenderingServer.frame_post_draw` hangs forever and
  a probe times out (or saves white). Instead, `await process_frame` then
  `RenderingServer.force_draw(false)`, a few times, then read the texture.
  `tools/probes/screenshot_title.gd` and `title_flow.gd` do this.
- **F9 in the editor freezes the game -- it is the EDITOR, not a bug.** Run
  from the Godot editor, the game is embedded and the editor catches F9: the
  game stops animating and answering, with nothing in the log (2026-09-29).
  In an exported build or on itch, F9 saves a screenshot as it should. Test
  screenshots in a build.
- **A creature rebuilt from a body's record does not block.** `take_damage`
  drops `blocks` with `alive`, and `to_dict()` is taken after the death, so
  anything revived with `Entity.from_dict` needs `blocks = true` set back
  beside `alive = true` (see `_rise_from`). Without it the thing is walked
  through by everyone and cannot be bumped -- Brad fought a risen young
  dragon that way (2026-10-01). The rising test had checked faction, hp and
  leash and never once walked into it: a new revival path needs a
  `player_move` into the result, not a look at its fields.
- **`run_one_test` reports a parse error only as "Could not resolve class".**
  The real line comes from `godot --headless --path . --check-only -s <file>`
  -- run it on the file you edited before guessing. Three times on
  2026-10-01 the cause was a NAME ALREADY TAKEN: `kob` in a 15k-line test
  file, `trng` in `apply_dict`, the constant `LANTERN_REACH` in a 9k-line
  sim. `grep -n "var <name>\|const <NAME>"` before naming anything.
- **`Node3D.look_at()` aims at a GLOBAL point.** The 3D camera's
  `look_at(Vector3.ZERO)` only worked while its rig sat at the origin; the
  first overhead render was black. Place a child in its parent's frame with
  `Basis.looking_at` and a local transform instead.
- **If a `.gd` was edited while a suite ran, that tally is void.** Stop the
  run (`TaskStop`, then kill any `godot` still holding `run_tests.gd`) and
  start it again once every edit is in. It happened once on 2026-10-01; the
  rerun is cheaper than wondering.
- **A premise pinned to one seed's layout moves when mapgen's draw count
  changes.** `_test_fair_shots` named the exact corner the 2026-09-27 hunt
  found on seed 20260927; counting traps by band (2026-10-02) re-laid that
  floor and the premise failed while the general check beside it passed.
  Do not revert the design change: probe the new layout for another corner
  of the same shape, update the pair, and note the old one in the comment.
  Adding a VAULT to a band's pool re-lays that band's floors the same way:
  the warren moved seed 9494's start to the map's edge (2026-10-07).
- **A screenshot of an EFFECT needs two things a screenshot of the map does
  not** (2026-10-06, the taming hearts: four popups in flight, none in the
  picture, three probe rewrites). First, a frame between `_bind_state` and
  the turn that makes the effect: `Fx.watch_map` forgets everything in
  flight the first frame after the state changes under it. Second,
  `scene.grid.fx.hold = true` before the shot: the first rendered frame
  after a rebuild can take longer than `POPUP_LIFE`, and `Engine.time_scale`
  does not help because the list is filtered, not timed.
  `tools/probes/screenshot_tamed.gd` does both.
- **Anything added to `build_level` is paid thousands of times by the
  suite** (2026-10-06: the pre-run, a tenth of a second a floor, took the
  suite from 15 minutes to 38 -- and an 8-floor probe had called it "about
  nothing"). Time it per test with and without, not with a small probe: the
  slowdown sat entirely in the tests that build hundreds of floors. The
  pre-run is off for the suite (`GameState.prerun_turns = 0` in
  `run_tests.gd`), and its own test switches it on.
- **`new_game()` builds floor 1 itself.** A probe that times `new_game()`
  plus `build_level()` pays for two floors: the first pre-run timing came out
  double that way (170-260 ms; really 55-150). Time the one `build_level`.
- **Every probe that calls `use_scratch_files` must call
  `GameState.clear_scratch_files()` before it quits.** Nineteen did not and
  left files in Brad's save folder (fixed 2026-10-07). A probe killed by a
  timeout never reaches it; the leftover is a `scratch_` file, safe to delete.
- **A `git add` naming a path that no longer exists adds NOTHING.** After
  `git mv`, an add list still naming the old paths fails as a whole; with
  its errors hidden (`2>/dev/null`) that is silent, and the commit takes
  only what was already staged (969123d: two renames and none of the
  content, 2026-10-08). Never hide a `git add`'s errors; read
  `git show --stat HEAD` before pushing.
- **The vault editor has two copies of its tile table.**
  `tools/build_vault_editor.py` rewrites the page's `TILES` table (and its
  embedded font and `BESTIARY` line) from its own copy: edit the script's,
  never only the page's, and run it after any change to `vault.gd`'s glyphs
  or the icon font. It checks its table against `vault.gd` and refuses to
  write a page that disagrees. It needs `godot` on the PATH (it runs
  `tools/dump_bestiary.gd`).
- **A plain file the game reads at run time ships ONLY if every export
  preset's `include_filter` names it** (`.txt`, `.json`, anything Godot does
  not import as a resource). The editor reads the project folder, so nothing
  in development shows it missing: no vault reached a published build until
  3ffd14a (2026-10-08), which added `assets/vaults/*.txt` to all three
  presets. Guarded by `_test_vaults_ship_in_every_export`. Check a packed
  build for the path (`grep -a -o 'assets/...' <exported file>`), not only
  the editor. Today the vaults are the only such files (checked 2026-10-08).
- **`tools/build_icon_font.py` takes EVERY `0x...` literal in the theme
  files, comments included** (2026-10-09). A comment naming a codepoint puts
  that glyph in the font. And a glyph once in the subset is kept as a
  "spare" on every later rebuild. Also: a `GlyphTheme.OVERRIDES` entry must
  name a look the game draws -- `_test_icon_theme` fails one added before
  its tile exists (the spider's web, 2026-10-09).
- **The headless renderer keeps no MultiMesh per-instance data**
  (2026-10-10): `get_instance_custom_data` and `get_instance_transform` read
  back nothing in the suite. Test what a builder hands `_add_batch` (call it
  on a fresh dictionary), as `_test_the_shrine_model` does.
- **A billboard's `get_aabb()` is a cube** (2026-10-09): with
  `BILLBOARD_ENABLED` a Sprite3D reports a box big enough for every turn.
  Measure an unturned copy (billboard off). Sprite3D and Label3D `offset`
  is in pixels and +y is UP.
- **Every `.txt` under `assets/sprites/` is read as a sprite and shipped.**
  Notes there are `.md`; the suite fails a `.txt` not named after a look the
  game draws (and a second file of the same look).
- **3D models for features follow `tools/3D_FEATURES.md`** (2026-10-10): its
  ten rules -- shapes in code, one batch per part, colour from
  `_surface_color`, a walkable tile keeps its middle clear, and the rest.
- **Three Godot caches go stale:** global class names, imported assets, script
  bodies. A new `class_name` that "does not exist" is usually the first, and
  `godot --headless --import` fixes it.

## Two test files, and when to run each

- **`tests/run_view_tests.gd`** (~3 s): the 3D view and everything the two
  renderers share (effects, light, memory fade, region colour, small life,
  camera and keys). Its scene test awaits frames, which the main suite can't.
- **`tests/run_tests.gd`** (~14-16 min; Brad wants it kept near 15): everything else.
- **`tools/run_one_test.gd`** runs single functions of the full suite by name,
  in seconds: `godot --headless --path . -s tools/run_one_test.gd -- _test_x`.
  For checking one feature while working; the full suite is still the gate.
- **Run BOTH on day 7, and before committing anything that touches the
  renderer.** A second file is easy to forget; its tally is a separate line.
- This split is the first step of Brad's idea (2026-09-27): a quick "daily"
  set and an "extended" day-7 set. Grow the quick file, keep the long one.
- Never run two suites at once from checkouts of this project: they share one
  `user://` (project name `OFR`), so one run's scratch cleanup deletes the
  other's files. For a parallel run, give it its own folder:
  `XDG_DATA_HOME=/some/dir godot ...`.

## Checks that cannot fail

The commonest defect in this suite is not a wrong assertion. It is one that
never runs.

- **Assert the precondition, not only the outcome.** A block of "this is
  refused" checks all passed while aiming at a cell the target had already
  walked out of: `target == null` returned first, and the guard under test was
  never reached.
- **Every block of refusal checks needs one check that must SUCCEED.** That is
  what caught the above, and it had been written for an unrelated worry.
- **A before/after guard passes vacuously when there is no "before".**
- **An unchanged tally after adding a feature means that feature has no
  coverage.**
- **The author of a check is the worst person to ask whether it can fail**,
  because they read it through the intent they are holding in their head. Four
  times on 2026-09-20 one session added a precondition the other had missed.

## Working agreements

- **`tools/travel.md` is how the two sessions leave each other notes**
  (Brad, 2026-10-08): edits for this file and ADVICE.md, handoffs, and
  anything to say while the other session is offline. Pull and read it at
  the start of a session; apply what is meant for this file, and mark it
  DONE there.

- **Player feedback is in `PLAYTESTS.md`.** Read it before designing anything
  players touch. The context box (HERE) is the game's best teaching tool --
  a fresh Legion player learned the game from it -- so explain new things there.

- **Sessions may commit and push (Brad, 2026-10-08), with NO attribution
  of any kind:** no Co-Authored-By trailer, no "generated with" line, nothing
  naming Claude or AI in a commit, a PR or the repo. People refuse to look at
  or play a game they think an AI is associated with. This overrides any
  default commit guidance. Only after the suite is green, and say what was
  pushed with its tally.
- **One feature at a time**, with play between each.
- **The classic view is deprecated (Brad, 2026-10-08).** New visual features
  go into the 3D views (3D and 3D overhead) only. The classic grid and its
  letters and symbols themes stay working and tested, but are not extended;
  a feature missing there is not a bug. Shared UI still serves both. See
  the top of BACKLOG.md.
- **The dungeon is one-way.** `_seize_amulet` calls `build_level()`, so a floor
  is never revisited and any off-screen behaviour must pay off within a single
  visit.
- **Two sessions often run against the same working tree.** Announce before
  editing a shared file, and never edit a `.gd` while a suite is running — a
  running suite loads scripts on demand and will pick up the change mid-flight.
- **On handhelds the game must be launched through Steam**, or Steam Input
  blanks the real pad's device node and Godot sees no controller at all.
