# 3D features: replacing the pictures with models

For any session building or reviewing the 3D view: the Legion, the desktop,
the day-7 reviewer. Written 2026-10-10 by the desktop, at Brad's request,
after the shrine became the first feature model. The aim: the 3D view is the
default now, so terrain features (the shrine, the great gate, graves,
braziers, stairs) should become **3D models** instead of icon cards, one at a
time, without changing anything the game itself decides.

---

## 1. How the 3D view draws a floor today

All in `src/render/diorama_view.gd`, rebuilt by `_rebuild_world()` whenever
the floor changes (never every frame).

| layer | how | where |
|---|---|---|
| floor, walls, rock, pillars, door frames | one **batch per kind**: `_add_batch(batches, kind, transform, colour)`, then `_add_multimeshes` makes ONE `MultiMeshInstance3D` per kind | the tile loop in `_rebuild_world`; mesh table in `_add_multimeshes` |
| doors and gates | the **first models**: posts, header, leaf (`_add_door`); a leaf swings when it opens (`_swings`, `_draw_swings`, on "simple" and "full" only) | `_add_door`, `_gate_leaf()` |
| features (stairs, brazier, grave, shrine, chest, trap, bones, water, fungus) | a **card**: the icon picture on a billboard, or under the pixel look its drawing (`_add_tile_icon` -> `_add_card`) | `_add_tile_icon` |
| creatures, items, bodies | cards (`_add_card`), pictures or drawings | `_add_items_and_entities`, `_add_bodies` |
| light | the sim's light map as a texture the surface shader reads (`_build_cell_light`), plus engine `OmniLight3D`s **mirroring the sim's own sources** (`state.static_lights`, the torch), capped at `LIGHT_CAP` (8) on the web, 32 on Forward+ | `_add_lights` |

**Colour is per instance.** Each batch entry carries a colour (multimesh
custom data) worked out by `_surface_color(tile, x, y, visible)`: the
theme's colour, the shrine's hue, the brazier's heat, the region's tint on
stone, and **memory** (out of sight: dimmed, or transparent when not
recalled). The shared surface shader (`_surface_material(style)`) then lights
it from the light map. So anything drawn through a batch is lit, remembered
and region-tinted for free.

**Two renderer tiers** (`rich`): Forward+ on a PC, Compatibility on the web
(no SSAO, at most 8 lights a mesh). A model must look right on the web tier.

**Effects setting**: "still" (no motion at all), "simple", "full". Anything
that moves is gated on it (`Effects.any()`, `Effects.shaders()`).

---

## 2. The rules for a feature model

1. **Built from simple shapes, in code.** `BoxMesh`, `CylinderMesh`, or a few
   of them merged with `SurfaceTool.append_from` (as `_gate_leaf()` does).
   No imported model files: they would grow the web build, need an art
   pipeline, and fight the blocky look.
2. **One batch per part, never a node per cell.** Add a kind to the mesh
   table in `_add_multimeshes` and call `_add_batch` from the tile loop.
   A rebuild touches every cell; nodes per cell were most of what it cost
   before batching.
3. **Colour from `_surface_color`, never a fixed colour.** That is what makes
   light, memory and region apply. A part that is "stone" takes the wall's
   colour (`_surface_color(Tiles.WALL, ...)`, as door posts do); a part that
   *means* something takes the tile's.
4. **Meaning stays in the colour.** The shrine's hue says which shrine it
   is; a spent brazier's heat is the forging gauge; remembered stairs
   breathe. Whatever the card's colour said, the model's must say.
5. **Light that matters comes from the sim.** A model may be bright (its own
   colour), but it never adds an engine light the sim does not have: what is
   lit is a rule of play, and the light map decides it.
6. **Motion only on "full"**, nothing on "still", and never hiding
   information.
7. **Fits its cell, below `WALL_HEIGHT`** (1.35), readable from the overhead
   view (pitch 80) as well as the 32-degree one, and from all eight turns.
8. **It replaces the card in 3D only.** The classic view keeps its glyph.
   Precedence in 3D: **model, then drawing (pixel look), then picture.** A
   feature with a model ignores a sprite file of the same look.
9. **A walkable tile keeps its middle clear.** Shrines, graves, stairs,
   traps and open doors are stood on; a card stands at the middle of its
   cell, up to 0.6 wide and taller than a wall for the biggest creatures.
   Anything solid goes at the edges or the corners, or stays as flat as the
   floor; test it with something standing on the tile. (A chest is solid
   and bumped: it may fill its cell.)
10. **Tests** (`tests/run_view_tests.gd`): the batch exists with one instance
   per cell, its colour is the tile's, no card is drawn for that cell, and
   its geometry sits in the cell under the walls. Each batch's node is
   named `batch_<kind>`, so a test can find it. **The headless renderer
   keeps no per-instance data:** `get_instance_custom_data` and
   `get_instance_transform` read back nothing in the suite. Check what your
   `_add_<feature>` hands `_add_batch` instead (call it on a fresh
   dictionary), as `_test_the_shrine_model` does.

---

## 3. Built: the shrine (2026-10-10)

`_add_shrine` in `diorama_view.gd`. A low round stone dais, a disc of the
shrine's hue set into its top, and four small crystals of the same hue at
its corners.

| part | mesh | colour |
|---|---|---|
| `shrine_dais` | cylinder, radius 0.46, 0.06 high (as low as the floor's flagstones stand) | stone (`_surface_color(Tiles.WALL, ...)`) |
| `shrine_disc` | cylinder, radius 0.30, 0.012 high, on the dais | the shrine's hue, glowing (style 14) |
| `shrine_crystal` x4 | octahedra (`_crystal()`), 0.14 wide, 0.36 tall, turned 45 degrees, at the four corners (0.36 out along each diagonal), floating at 0.30 | the shrine's hue, glowing |

The dais is surface style 2 (worked stone, as pillars). The disc and the
crystals are **style 14, a glow**, added to `diorama_surface.gdshader` for
them: their own colour, lit as a card is (the cell's light raised to at
least 0.45), so they read in a dim room. It is still only their own colour:
it lights nothing else, and remembered they fade as everything does. No
engine light: the shrine is not a light source in the sim. Tests:
`_test_the_shrine_model` (view suite), including that the middle of the
cell stays clear.

**How it got here, and why it matters for every model:** the first version
was a stepped pedestal with a crystal floating over its middle. It looked
right empty, and its test checked colour and size -- and nobody stood on it.
A shrine is STOOD ON to pray (p, or g), and the player stood inside the
pedestal with the crystal through their head. Brad's question ("how do you
use one now?") found it. Hence rule 9.

**Copy this one** for the next model: a function `_add_<feature>` called
from the tile loop instead of `_add_tile_icon`, its parts added to the mesh
table, colours from `_surface_color`, and a view test.

---

## 4. Designs for the next ones (proposals, not built)

### The great gate -- the way out (BACKLOG "Ideas": the great door)

- **Where:** the climb's last floor, as the exit; possibly also a boss
  vault's door on the way down (seen once, so it stays special).
- **Model:** a wall section TWICE `WALL_HEIGHT`, two leaves of banded wood
  (`door_leaf` boxes with three dark `door_bar`-style bands each), hinged at
  the outer edges; ring handles as small tori or boxes.
- **Opening:** the two leaves swing outward like `_draw_swings`, over about
  0.8 s. **The light** is a screen effect, not an engine light: a white
  bloom from the gap (the post shader `diorama_post.gdshader` already has a
  fade; add a "white" pass), shafts as additive quads fanned out from the
  doorway on Forward+, and a flat wash on the web tier; then the screen
  goes to white and the run ends as an escape.
- **Sim side:** a tile or a vault marker for the gate, the amulet as the
  key, and the escape ending. The view only draws and animates.

### The grave

- A headstone slab (box 0.50 x 0.62 x 0.12, its top rounded with a short
  cylinder on its side) and a low mound (a flattened box) in front of it.
- Stone colour for the slab; the mound in the grave tile's colour.
- **Pairs with the rising bones effect:** when a grave or a body rises, the
  risen card slides up out of the floor over 0.5 s with green motes and a
  few bone bits (the `Fx` system's bits, as `burn` and `shatter` use), on
  "simple" and "full".

### The brazier

- A bowl (a short cylinder, wider at the top) on three legs (thin boxes).
- Lit: the bowl's coals in the fire's colour; the flame stays what it is now
  -- the card, the embers (`_add_embers`) and the engine light, which the sim
  already has.
- Spent: the coals take the heat gauge colour (`_surface_color` already
  blends `BRAZIER_DEAD` to `EMBERS` by `ember_heat`): the forging window,
  readable at a glance. Dead: black coals.

### The stairs

- **Down:** a dark well in the floor with three steps descending into it
  (boxes stepping down below the floor plane, the deepest nearly black).
- **Up:** three steps rising, the top one under `WALL_HEIGHT`.
- Remembered stairs must still breathe: the pulse that `_pulsing` drives on
  the card moves to the steps' colour, or a rim on the well's edge.

### The chest

- Already a box. Add a lid (a slightly wider, shorter box on top), two
  metal bands, a lock plate. Open chests: the lid tipped back.

### Not models

Water, mud, fungus, bones and traps stay ground patterns and cards: they
are flat, and a model would only hide what lies on them.

---

## 5. Related, from the same mock-ups

- **The depth card** (built 2026-10-10, `src/ui/depth_card.gd`): a title
  card on entering a band, never listing what lives there.
- **Eyes in the dark** (a design question for Brad first): a creature that
  has noticed you but stands where you cannot see it shows only its eyes --
  fair warning without saying what it is. Needs a rule for who shows eyes,
  and must not leak positions the sim keeps hidden.
- **Torch fuel**: no -- it would fight the kindle race and the flares.

---

## 6. Order and size

| step | size | why first |
|---|---|---|
| shrine | done | the template |
| grave + rising effect | small | the rise is a moment players see every run |
| brazier | small | most-seen feature; the heat gauge reads better |
| stairs | medium | the down-well needs the floor cut open |
| chest lid | small | |
| great gate | large | needs the sim's escape exit first |
