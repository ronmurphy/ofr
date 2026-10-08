# Cave vaults -- the game side

Written 2026-10-08 by the desktop session, after updating
`tools/vault_editor.html` for cave vaults. This is the game half: what to change
so the game reads `kind: cave`. It is for the Legion session or Brad.
The design is in BACKLOG.md under "Cave vaults (Brad and the desktop,
2026-10-08)". Read that first.

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
- Cave vaults are saved in `tools/cave_vaults/` until the steps below land;
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

11. **Move `tools/cave_vaults/*.txt` into `assets/vaults/`** and run the
    linter: `godot --headless --script res://tests/vault_lint.gd`.

## Also changed in the editor today

- The tile table had lost purple fungus (`v`), red fungus (`;`) and the
  rabbit (`r`). Opening a vault with purple or red fungus silently erased
  those cells, and `tools/build_vault_editor.py` refused to run against
  `vault.gd`. Both are fixed. The script now passes its check (31 glyphs)
  and re-embedded the current icon font.
