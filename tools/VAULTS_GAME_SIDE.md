# Vaults -- the game side of the editor's new format

Written 2026-10-08 by the desktop session, after updating
`tools/vault_editor.html`. The editor now writes two things the game does not
read yet: CAVE VAULTS (`kind: cave`, part 1) and CREATURES BY NAME (`place 1:
cave bear`, part 2). This file is what to change in the game for each. It is
for the Legion session or Brad. The two parts are independent; either can go
first. The cave design is in BACKLOG.md under "Cave vaults (Brad and the
desktop, 2026-10-08)". Read that first.

Until a part lands, vaults using it wait in `tools/vaults_waiting/`.

# Part 1: cave vaults

## What the editor now makes

- A header line `kind: cave` (only caves write it; a missing kind is a room,
  so every existing vault is unchanged). The editor sets `band: caves` and
  depths 4-6 when you pick the cave kind.
- Cells: `_` cave floor, `#` or ` ` (space) both mean ROCK. A cave region is
  rock before the game carves it, so outside the drawn shape is rock. Every
  other letter means what it means in a room vault (`~` `^` `*` `v` `;` `,`
  `=` `%` and the markers `m` `M` `?` `!` `)` `[` `}` `(` `r`).
- No doors. The cave connector tunnels in, as it does into a grown cave.
- One connected area of at least 24 floor cells. The game drops grown caves
  under 24, and the editor fails a cave vault under it.
- Size: anything up to 40x40 in the editor. It warns above 22x15, which is
  the generator's own `CAVE_MAX`.
- The editor's GENERATE CAVE button grows a shape by the game's own rules
  (`CaveGen`: fill 0.46, sealed border, four smoothing passes, birth limit 5,
  largest region). It uses its own seeded rng, so the game never grows that
  cave itself. The game uses the authored cells verbatim.
- Cave vaults are saved in `tools/vaults_waiting/` until the steps below land;
  then move them into `assets/vaults/`.

## The changes, in order

1. **`src/sim/vault.gd`**: `var kind := &"room"`; in `_set_meta`, a
   `"kind": kind = StringName(value.strip_edges().to_lower())` arm; and
   `func is_cave() -> bool: return kind == &"cave"`. TERRAIN and CONTENTS
   are unchanged. Spaces already mean "nothing" to the loader.

2. **`tests/vault_lint.gd`**: read `kind:` too. For a cave: skip the door
   checks; fail under 24 open cells; keep the connectivity check; warn (or
   fail -- Brad's pick) if the band is not `caves`.

3. **`src/sim/mapgen.gd` `_reserve_vaults`**: never reserve a cave vault as
   a room (skip `v.is_cave()` when building `eligible`). On the cave band,
   PREFER cave vaults: when any cave vault is eligible, the band's vault
   (the existing 25% roll, `wanted = 0 if rng.randf() < 0.75 else 1`) goes
   to a cave vault through step 4, and no room vault is reserved there. If
   no cave vault is eligible, today's behaviour stands. Keep the roll where
   it is, so the draw count does not change for floors that place no vault.

4. **`src/sim/mapgen.gd` `_reserve_caves`**: if step 3 chose a cave vault,
   orient it (`Vault.oriented(quarters, mirror)`, as rooms are) and reserve
   ITS box as the first of the floor's cave regions, before the grown ones,
   so a large one finds room. Keep a list of authored regions:
   `{"rect", "grid", "vault"}`, beside `caves`.

5. **`src/sim/mapgen.gd` `_carve_caves`**: for an authored region, paint
   the grid instead of `CaveGen`: `_` becomes `CAVE_FLOOR`, `#` and space
   stay rock, other TERRAIN letters become their tiles (apply the same
   `allow_pits` rule `_stamp_vaults` applies to `X`), and CONTENTS letters
   become `CAVE_FLOOR` (not `FLOOR`, as `_stamp_vaults` lays for rooms) and
   go into `vault_contents` -- `_place_vault_contents` in game_state.gd then
   places them as it does for rooms. Skip the "painted >= 24" drop for it
   (the author and the linter promised). Skip `_scatter_cave_cover` for it
   too if the vault is `terrain: fixed`, and mark its cells in `protected`,
   as `_stamp_vaults` does, so the terrain pass and the drip pools leave it
   as drawn. It stays in `caves`, so `_paint_materials` makes it CAVERN,
   `_connect_caves` joins it, and GameState's `_populate_cave` peoples it
   (monsters, animals, a bear and its den) like any cave.
   THE EDGE: a grown cave gets a one-square rock rim because
   `_naturalise_cave_walls` turns every WALL touching CAVE_FLOOR into ROCK.
   A cave vault must be carved BEFORE that pass runs, so its edge becomes
   rock the same way. The editor draws the whole surround as rock only for
   clarity; in play, only the rim touching the floor is ever seen.

6. **Its name and rect in `vault_rects` / `vault_names`** (game_state.gd,
   after `gen.generate`), so `_corrupt_sites` keeps out of it as it keeps
   out of rooms. Check what else reads `vault_rects` before relying on
   this.

7. **At most twice a run, the second time turned differently.**
   `GameState.cave_vaults_seen: Dictionary` (name -> Array of
   `[quarters, mirror]`), saved in `to_dict`/`apply_dict`, handed to MapGen
   before `generate` and appended to from what MapGen reports it placed. A
   cave vault seen twice is not eligible. Seen once, it is eligible only if
   it may rotate. When the rolled orientation was already used, step to the
   next unused one deterministically (quarters + 1 mod 4, then flip mirror).
   Do NOT re-roll: the number of draws must not depend on the memory
   (CLAUDE.md: content-dependent draw counts move seeds).

8. **`assets/vaults/README.md`**: a "kind: cave" section (the format above).

9. **Tests** (`tests/run_tests.gd`, one function, e.g. `_test_cave_vaults`):
   a test cave vault injected into `GameState._vault_library`, on a cave
   floor where the roll wants one (find a seed by probe), shows up as
   `CAVE_FLOOR` cells inside one of `gen.caves`' regions, is NOT a room, and
   is populated as a cave. When a cave vault is eligible, no room vault is
   placed on the cave band. The repeat memory: a second placement turned
   differently, never a third, saved and loaded. A marker inside works (`r`
   places a rabbit on cave floor). The lint accepts a cave vault and fails
   one under 24 cells. Assert preconditions; one check that must succeed;
   a mutation that fails it. Then extend
   `tools/probes/cave_vault_halves_probe.gd`: cave vaults on about a quarter
   of cave floors, both halves.

10. **Expect seed-pinned tests to move** on cave floors (CLAUDE.md: re-probe
    rather than revert), then the full suite at the end.

11. **Move `tools/vaults_waiting/*.txt` into `assets/vaults/`** and run the
    linter: `godot --headless --script res://tests/vault_lint.gd`.

# Part 2: creatures by name

## What the editor now makes

- Header lines `place N: <bestiary name>`, N a digit 1-9, one per kind used,
  e.g. `place 1: cave bear`. The names are the game's own `GameState.BESTIARY`
  names. The editor's dropdown is dumped from the game by
  `tools/dump_bestiary.gd`, so it never offers a name the game lacks.
- On the board, that digit where the creature stands. Nine kinds at most per
  vault. `m`, `M` and `r` are unchanged.

## The changes

1. **`src/sim/vault.gd`**: `var places: Dictionary = {}` (digit String ->
   name String). In `parse`, before the generic `key: value` split, match
   `place N: name` (the key has a space, so `_set_meta` never sees it
   today). Add `"1".."9"` to CONTENTS.

2. **`tools/build_vault_editor.py`**: its glyph check will then say "vault.gd
   parses these, the editor cannot draw them: 1 2 3 ...". Teach it that the
   digits are the named-creature markers (exclude them from the comparison),
   not tiles.

3. **`tests/vault_lint.gd`**: accept digits; FAIL a digit with no `place`
   line, and a `place` name that is not in `GameState.BESTIARY`. WARN, as the
   editor does, when a named monster's threat is above the room ceiling at the
   vault's `min_depth` (`Threat.room_ceiling`: 10 + 2 a floor), since it would
   be left out there.

4. **`src/sim/mapgen.gd` `_stamp_vaults`** (and the cave carve from part 1):
   a digit cell is floor (CAVE_FLOOR in a cave vault) and goes into
   `vault_contents` as `{"ch": "creature", "name": spot["vault"].places[ch],
   "pos": cell}`.

5. **`src/sim/game_state.gd` `_place_vault_contents`**: a `"creature"` arm.
   Look the row up by NAME in BESTIARY. The rules:
   - Where the game could meet it: effective depth at least `min_depth`; an
     `ascent_from` creature only on the climb from that floor. Otherwise
     nothing is placed. The vault's depth range says which floors it is on;
     this says which of those floors the creature is on.
   - A WILD animal: `_place_kept(at, app)` -- on top of the budget, as `r`
     is (it goes through `_place_pick`, so a wolf brings its pack).
   - A MONSTER: spends the room's budget like `m` (`remaining = ceiling -
     spent`); if its threat (with gear, as `_place_pick` arms it) is more than
     what is left, it is not placed. Same honest outcome as an unaffordable
     `m`: the room is under-populated, never over.
   - No new rng draws beyond what `_place_pick` itself makes, so seeds move
     only on floors whose vaults use names.

6. **Tests**: a vault with `place 1: cave bear` and `place 2: kobold`
   injected into `GameState._vault_library` and stamped. The bear appears
   (wild, outside the budget). The kobold appears and the room's budget is
   spent. An unaffordable monster is left out, while the cheap one beside it
   is placed (one check must succeed). An ascent-only creature is absent on the
   descent and present on the climb. The lint fails a digit with no place
   line and a misspelt name. Mutation: drop the budget rule and the
   over-ceiling case is caught.

7. **`assets/vaults/README.md`**: document `place N: name` and the rules
   above, then move any waiting vaults that use names into `assets/vaults/`
   and run the linter.

## Also changed in the editor today

- The palette is in categories (ground, structure, fungus, features,
  creatures, items), with a dropdown of every creature by name on the
  creatures tab, sorted wild animals then monsters, each with its depth and
  threat. `tools/build_vault_editor.py` gives every tile its category and
  embeds the bestiary from `tools/dump_bestiary.gd` (it needs `godot` on the
  PATH; it refuses to write an editor with an empty dropdown).
- The tile table had lost purple fungus (`v`), red fungus (`;`) and the
  rabbit (`r`). Opening a vault with purple or red fungus silently erased
  those cells, and `tools/build_vault_editor.py` refused to run against
  `vault.gd`. Both are fixed. The script now passes its check (31 glyphs)
  and re-embedded the current icon font.
