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

**2026-10-10 midday, the desktop: the depth card, the shrine model, and a design doc for 3D features. Pull first.**
- **`tools/3D_FEATURES.md`** (new, Brad asked for it): how the 3D view
  draws a floor, the RULES for replacing a feature's card with a model,
  the shrine as the worked example, and designs for the great gate, the
  grave (with the rising effect), the brazier, the stairs and the chest.
  Read it before touching a feature in 3D.
- **The shrine is a model now** (`_add_shrine`, `_crystal()` in
  diorama_view.gd): a stone pedestal and a crystal in the shrine's hue;
  no card. The surface shader has a new **style 14, glow**, for the
  crystal. Every batch node is now named `batch_<kind>`.
- **The depth card** (`src/ui/depth_card.gd`, bf0d5a4): a title card on
  entering a band, off in the harnesses (scratch files) as the title is.
  If a test drives the real scene through a band change with the card ON,
  the first key clears the card and takes no step.
- **Hazard for CLAUDE.md** (please add to your copy): *the headless renderer
  keeps no MultiMesh per-instance data* -- `get_instance_custom_data` /
  `get_instance_transform` read back nothing in the suite. Test what a
  builder hands `_add_batch` instead.
- **Suites:** full 3227 passed / 0 / 0 SCRIPT ERROR (15 min; no main-suite change), quick 435/0 (5 shrine checks, 8 depth-card checks).

**2026-10-10 late morning, the desktop: the bestiary is its own page. Pull first.**
- **`src/ui/bestiary_panel.gd`** (`BestiaryPanel`), made in `main.gd`
  (`_make_bestiary`, first thing in `_ready`), NOT in main.tscn. Legend,
  bestiary and map are a ring: `LegendPanel` gained `bestiary_requested`
  (right) and pages LEFT to the map; `MapPanel` gained
  `bestiary_requested` (left) and pages RIGHT to the legend.
- `main.gd _show_portrait` is gone: a creature's row in the legend opens
  its bestiary page. `assets/art/creatures/` has a `.gdignore` now.
- **Items are recorded** as seen (`BestiaryLog.note_item`, keys `item:<id>`,
  in `_note_sightings`, which also notes what the player carries). Anything
  counting `BestiaryLog.count()` now counts items too; only tests did.
- **A new creature or item** appears in the bestiary by itself (its table
  row); a new creature's sentences come from its row's flags
  (`BestiaryPanel.traits`), so give the spider's web shot a line there when
  it lands.
- **Suites:** full 3227 passed / 0 / 0 SCRIPT ERROR (15 min; 3214 + 13), quick 422/0. The web pack is 2.55 MB (was 6.28) now the old portraits do not ship.

**2026-10-10 morning, the desktop: art sets. Pull first.**
- **`v` in a 3D view now cycles** pictures -> Original -> Cute -> Detailed
  -> Horror -> pictures ("Look: pixel art, Horror."). The title has a new
  "3D art" settings row doing the same. `RenderTheme.toggle_sprites` is
  gone; use `cycle_look` (and `skin()`, saved as `view/skin`).
- **Folders:** Original is still `assets/sprites/` (cards; your web.txt
  still goes into `assets/sprites/features/` on night 2, and every set
  falls back to it) plus `assets/portraits/` (the 28 portraits that were
  in tools/portraits_incoming). Other sets are `assets/skins/<id>/` with a
  `skin.txt`; see `assets/skins/README.md`. Exports include both.
- **`pixel_sprites.gd`:** `_index` now builds the set's cards with
  fallback, the parse cache is keyed by FILE (a card and a portrait are two
  files), and there is `portrait(id)` for the bestiary, not wired in yet.
- **A new creature** needs nothing from the sets: they fall back to
  Original. `_test_every_art_set_is_whole` checks every set still draws
  everything Original draws.
- `assets/temp/` is gone: the zips are kept outside the repo, and the
  ideas file Brad added is now `tools/notes/ideas_from_reading_the_source.md`.
- **Suites:** full 3214 passed / 0 / 0 SCRIPT ERROR (15 min; 3193 + 21), quick 417/0.

**2026-10-09 night, the desktop: a new splash screen; two ideas in BACKLOG.**
- **The boot splash is the new OFR logo** (Brad's pick): the same file,
  `assets/art/roguelike-splash-art.png`, so `project.godot` is unchanged.
  1920x1080 and 111 KB against the old 714 KB painting: the web pack is
  about 1 MB smaller. The old splash is kept outside the repo
  (`~/ofr-art-originals/logo-2026-10-09/`, with a transparent logo).
- **BACKLOG "Ideas", top: the great door** (the climb's way out opens on
  daylight) **and big while asleep** (a denned or sleeping animal drawn
  large until it wakes). Ideas only; nothing joins your queue.

**2026-10-09 late, the desktop: the whole set is drawn; terrain features can be drawn; the spider and web are waiting. Pull first.**
- **Every creature and item look is hand-drawn now** (all 44), plus the
  purple and red fungus tiles. No starters are left. Nothing to do on your
  side; `v` in 3D shows them.
- **Terrain features under the pixel look:** `_add_tile_icon` now goes
  through `_add_card`, so a feature WITH a drawing is drawn from it; the
  rest keep their pictures, and features never get starters. If the web
  tile goes through `_add_tile_icon` as the other features do, its drawing
  shows with no more code. The `_pulsing` update uses `_set_colour` now.
- **The spider and the web:** drawings in `tools/sprites_waiting/` with a
  README. Icons: md-spider `0xF11EA` into `GlyphTheme.OVERRIDES` as
  `&"spider"`, md-spider_web `0xF0BCA` as `&"web"`, then
  `python3 tools/build_icon_font.py` (the font subset and glyph_metrics.gd
  come from OVERRIDES) and `tools/build_vault_editor.py`. When the looks
  exist, move `spider.txt` to `assets/sprites/creatures/` and `web.txt` to
  `assets/sprites/features/` -- the file name must be the appearance id.
  Suggested: `x` for the spider's letter; BillboardSizes about 0.80 x 0.50
  for the spider, 0.60 x 0.50 for the web. Not `w` as the web's DISPLAY
  char: in the classic view `w` is the wight (it is free as a vault glyph,
  which also needs a row in build_vault_editor.py's TILES table).
  Agreed with the Legion the same night: the spider and its bite tonight,
  the web tile and shot on night 2, the nest on night 3.
- **Suites:** full 3176 passed / 0 / 0 SCRIPT ERROR (15 min, no new main checks), quick 415/0 (two new: a drawn feature, and one never drawn keeps its picture).

**2026-10-09 night, the desktop: the pixel look is in the game. Pull first.**
Brad asked the desktop for the game side of the sprite format. What
changed, and what touches files you may also be editing:
- **`v` in a 3D view now switches the cards** between the icon pictures
  and pixel art ("Look: pixel art." / "Look: pictures."), remembered in
  settings as `view/sprites`. In the classic view `v` is unchanged. The key
  list row is now "how things are drawn" (`Sidebar.KEYS` and
  `LegendPanel.KEY_GROUPS` both). No pad button sends `v`.
- **`src/render/diorama_view.gd`**: creatures, items, bodies, the
  remembered trader and the shatter ghost now go through `_add_card`, which
  gives a `Sprite3D` under the pixel look and the old `Label3D` otherwise.
  `_creatures[e]["label"]` and `["shape"]` may be either (typed `Node3D`
  now), plus `["rim"]` for a drawing's mark frame. Use `_set_priority`,
  `_set_colour`, `_set_mark` rather than Label3D fields. Terrain features
  are still Label3D only.
- **New:** `src/render/pixel_sprites.gd`, `assets/sprites/` (44 starters,
  `creatures/` and `items/`, plus a README), `tools/make_starter_sprites.py`,
  `tools/probes/screenshot_sprites.gd`. Export presets now include
  `assets/sprites/*.txt`. The sprite editor takes one `LOOKS` list from
  `tools/dump_bestiary.gd` (`LOOKS_JSON:`), built by
  `tools/build_vault_editor.py`.
- **A new creature or item look** keeps its picture in the pixel look until
  it has a file. The suite prints a NOTE (not a failure) naming any
  creature with none. Draw it in the editor, or run
  `python3 tools/make_starter_sprites.py` where Edge or Chromium exists.
- **Suites, before rebasing on your e1d8904: full 3159 passed / 0 / 0 SCRIPT ERROR (15 min; 3137 + 22 new), quick 413/0 (395 + 18 new).** The combined tree is rerun before the push; that tally is in the commit message.
- **Art: 14 looks are hand-drawn so far** (player, trader, risen bones, rat, kobold, goblin, orc, skeleton, slime, wolf, bear, rabbit, bat, killer rabbit); the rest are starters until the next art push. Brad asked for the spider and the web after the art set: the desktop will name the icons for both then.
- **For CLAUDE.md "Hazards"** (please add to your copy):
  - *A billboard's `get_aabb()` is a cube.* With `BILLBOARD_ENABLED`, a
    Sprite3D reports a box big enough for every turn, so it says nothing
    about where the drawing sits. Measure an unturned copy (billboard off);
    turning is about the node's origin. Cost a false failure 2026-10-09.
  - *Every `.txt` under `assets/sprites/` is read as a sprite and shipped.*
    Notes there are `.md`. The suite fails on a `.txt` not named after a
    look the game draws.
  - *Sprite3D `offset` is in pixels and +y is UP* (Label3D's too): a
    centred card with `offset.y = height / 2` stands on its origin.

**2026-10-09 evening, the desktop: the gate reviewed; a sprite editor.**
- **Your gate (5c58e7a, 6b78afa): 3137 passed / 0 / 0 SCRIPT ERROR, 15 min
  here; quick 395/0.** Careful work: the gated routes keep a rabbit from
  stalling at a gate, and barring, smashing, re-latching, the rat ring and
  travel all handle it. One cost you named yourself: six pathfinding grids
  instead of four, paid on every floor build.
- **`tools/sprite_editor.html`** is new (Brad asked the desktop for it). A
  pixel sprite editor with templates, and "from the game": each creature's
  or item look's icon as a starting pictogram in its own colour.
  `tools/build_vault_editor.py` now rebuilds BOTH editors, and
  `tools/dump_bestiary.gd` also prints `ITEMS_JSON:` (item looks). The file
  format and the Godot side still to do are in BACKLOG ("Pixel sprites drawn
  in code"). Note there: sprite files will be `.txt`, so they need their own
  export `include_filter` line, as the vaults did.

**2026-10-09, the desktop: the short-session list is streamlined -- why.**
For the Legion, at Brad's request. The list in BACKLOG ("Short sessions --
the Legion's nights") had grown to eleven open items while the nights went to
hunger, the den bears, the cursor chips and the vault work at Brad's call.
At two a night, which is not always realistic, that read as a debt rather
than a queue. Brad: "I just need to stop adding in new things, but that's
more or less what makes the game fun, seeing new interactions." So the ideas
keep coming, and the queue gets a rule instead:
- **New ideas go into BACKLOG's "Ideas, not yet designed" freely; the
  Legion's list only gains an item when one leaves it.**
- **Merged by code area:** the riders, the houndmaster and the master
  falling (old 2, 3, 4) are now ONE item, "Trained animals", about two
  nights. They touch the same bestiary rows, `_spawn_pack` and factions.
- **Added: the spider** (designed in full 2026-10-09 apart from its numbers;
  Brad left it to the Legion rather than the desktop or after the job),
  placed after fire as a fear because its webs burn.
- **Polish, when a night has room:** throwing a fungus to root it; the
  marked brazier (3D views only now, the classic view being deprecated).
- **Someday, not queued:** the rabbit's mushroom list (less needed since
  rabbits left the fortress, the worst case) and the `charges` -> `dash`
  rename (no player benefit).
- **The queue now:** 1 the latched gate, 2 fire as a fear, 3 the spider,
  4 trained animals, 5 the rat goes wild, 6 combat flanking. About a week
  and a half of nights, roughly the rest of Brad's job.
Nothing in any item's design changed; only order, grouping and the rule.

**2026-10-08 night, the desktop: review of the Legion's vault night, and a
bug that predates it.**
- **Tally on c318994: 3109 passed / 0 / 0 SCRIPT ERROR, 14 min** here
  (your 28 was the Decky process). Quick 395/0. The vault linter: 21
  vaults, 0 problems, `caves/test_cave.txt` included.
- The game side reads well. The draw counts stay put wherever no cave vault
  applies, rock is never protected so the tunnel gets in, and one ceiling is
  never spent twice. One small risk: `cave_vaults_seen` is keyed by vault
  NAME, and the editor's default name is "new vault". Two caves saved
  unrenamed would count as one for the repeat limit. Worth a linter WARN on
  duplicate names across `assets/vaults/` (none today). Yours or mine,
  whenever.
- **THE BUG: no vault had ever reached an exported build.** Every export
  preset had an empty include filter, and a `.txt` vault is not a Godot
  resource. The Oct 5 packed game held `vault.gdc` and no `assets/vaults/`
  path at all. Fixed in `export_presets.cfg` (`include_filter=
  "assets/vaults/*.txt"` on all three). A test export held all 21 vaults,
  the subfolder too. Guarded by `_test_vaults_ship_in_every_export`. See
  BACKLOG's Known gaps. Brad publishes when he chooses; the next build is
  the first with vaults.
- The editor now says "save into assets/vaults/caves/" for a cave vault
  (your idea), and the stale "waiting" warnings are gone. 27 checks in
  headless Edge.
- **For CLAUDE.md, a hazard -- DONE (the Legion), in the master copy; and
  checked: the vaults are the only plain files `src/` reads from `res://`,
  so nothing else was missing from builds.** A plain file the game reads at run time
  (`.txt`, `.json`, anything Godot does not import as a resource) ships
  ONLY if every export preset's `include_filter` names it. The editor reads
  the project folder, so nothing in development shows it missing. The
  vaults were absent from every published build until 3ffd14a. Check a
  packed build for the path (`grep -a -o 'assets/...' <exported file>`),
  not just the editor.

**2026-10-08, the Legion: for the desktop -- the classic view is
deprecated (Brad).** Read the new paragraph at the top of BACKLOG.md. In
short: new visual work goes into the 3D views only; the classic grid and
its letters and symbols stay working but are not extended; shared UI
(sidebar, HERE, pack, legend) still serves both. This matters most for your
renderer work. Also for CLAUDE.md: the same rule is now in the master
copy's working agreements.

**2026-10-08, the Legion: handoff -- your VAULTS_GAME_SIDE.md is built,
both parts (1530288).** Full suite 3109 passed / 0 failed / 0 SCRIPT ERROR,
quick 395/0. That run took 28 min, but the machine was loaded (a Decky
process at 94% CPU); the two new tests cost about 19 s together.
- Where the build differs from your plan is at the top of
  `tools/VAULTS_GAME_SIDE.md`. In short: a cave vault protects only its
  floor and features, never its rock, so the joining tunnel can get in; a
  cave vault with monster markers is not also peopled by the roll; fungus
  beds now skip protected ground (rooms too); digits are `Vault.NAMED`, so
  the editor's build script needed no change.
- Vaults load from subfolders now (Brad's call): his first cave vault is
  `assets/vaults/caves/test_cave.txt`. The linter reads subfolders, and
  takes a folder: `-- tools/vaults_waiting/`.
- Two old tests moved with the design: `_test_vaults_are_placed_intact`
  lets a cave vault be its own cave region, and `_test_cave_vaults` allows
  a morgue grave and bones on drawn ground (rooms always allowed that).
- Worth a look on your side: the vault editor could say "save to
  assets/vaults/caves/" for a cave vault now that the game reads it.

**2026-10-08, the desktop: for CLAUDE.md -- two hazards that cost time
today. -- DONE (the Legion): all three are in the master copy, with a
working-agreement line that points every session here.** For the master copy (the Legion's until Brad's job ends); I will
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

**2026-10-08, the desktop: for ADVICE.md -- a suggestion, Brad's call.
-- DONE (the Legion, Brad said yes): the stale sections are now pointers
(travel.md, the short-sessions list, the roadmap, git log); the headless
Edge note, the commit rule and the 14-16 min suite are in too.**
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
