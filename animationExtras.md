# Animation extras

This file records the shared bone-chip footfall, melee contact, and confirmed
healing effects, with the code blocks that connect simulation events to both
renderers.

## Bone chips on bones

When the player steps onto a `Tiles.BONES` cell, four pale bone-coloured chips
kick outward as the foot lands. The bones tile is still cleared by the existing
game rule. The visual event preserves the tile type and cell long enough for
the renderers to draw the chips after the map has changed.

### Code blocks

- [`src/sim/game_state.gd`](src/sim/game_state.gd), `_end_player_turn()` —
  while `underfoot == Tiles.BONES`, queues the `bone_step` presentation event
  before replacing the tile with floor. The event does not alter gameplay or
  the existing noise behavior.
- [`src/render/fx.gd`](src/render/fx.gd), `FOOTFALL` — defines the bone chip
  colour, count, lifetime, and movement. `add_events()` handles `bone_step`,
  and `_add_footfall()` builds the shared `sparks` effect. `footfalls()` uses
  that same helper for visible actors whose landing tile remains bones.
- [`src/render/glyph_grid.gd`](src/render/glyph_grid.gd), `sync_motion()` —
  samples ordinary footfalls; `_draw_effects()` dispatches sparks to
  `_draw_burst()`, which draws blocky quarter-cell squares in the classic view.
- [`src/render/diorama_view.gd`](src/render/diorama_view.gd), `sync_motion()`
  and `_draw_fx()` — uses the same `Fx` particle data, then `_add_bits()` draws
  the chips as small cubes in 3D.
- [`src/render/effects.gd`](src/render/effects.gd), `Effects.any()` — gates
  moving footfall particles. They are suppressed by **still** and enabled by
  the moving effects modes (**simple** and **full**).

The player event is needed because `_end_player_turn()` clears the bones tile
before either renderer samples the destination. Other visible actors use the
ordinary `footfalls()` path when their bones tile remains in the map.

## Weapon-shaped melee contact

A successful melee hit gets a brief, faint mark at the struck cell. Slash
weapons make a short curved arc, piercing weapons a straight accent, and blunt
weapons a compact cross-shaped impact. Ranged hits keep their existing shot,
flash, number, and movement feedback without this extra contact mark.

### Code blocks

- [`src/sim/game_state.gd`](src/sim/game_state.gd), `_attack()` — records the
  attack's `damage_type` with its event, preserving the weapon style even if
  the attacker changes or dies before the renderer consumes the event.
- [`src/render/fx.gd`](src/render/fx.gd), `_hit()` — creates the contact only
  for melee and only when motion is enabled. `contact_marks()` returns the
  shared slash, thrust, or blunt layout and hides it outside visible cells.
- [`src/render/glyph_grid.gd`](src/render/glyph_grid.gd), `_draw_effects()` and
  `_draw_contact()` — draws the marks as small snapped blocks over the classic
  grid, without changing the underlying ASCII glyphs.
- [`src/render/diorama_view.gd`](src/render/diorama_view.gd), `_draw_fx()` —
  places the same marks as small 3D cubes using the existing effect-bit mesh.
- [`src/render/effects.gd`](src/render/effects.gd), `Effects.any()` — the new
  contact mark is off in **still** and on in **simple** and **full**. Existing
  hit flash, damage number, and feedback remain available in still mode.

## Confirmed healing cue

When the player actually regains one or more hit points, a small green ring
expands around them. Trying to heal at full health produces no healing cue.
The cue is gated by the effects setting; in still mode the health bar and
existing healing message remain the feedback.

### Code blocks

- [`src/sim/game_state.gd`](src/sim/game_state.gd), `_queue_healing_cue()` —
  queues a `healed` event only when the restored amount is positive. Calls are
  made after actual HP increases from items, fungus, brazier rest, mending
  shrines, level-ups, and the leech gem.
- [`src/render/fx.gd`](src/render/fx.gd), `add_impacts()` — turns `healed`
  events into a brief green ring through the existing shared ring effect.
- [`src/render/glyph_grid.gd`](src/render/glyph_grid.gd), `_draw_effects()` and
  `_draw_ring()`; [`src/render/diorama_view.gd`](src/render/diorama_view.gd),
  `_draw_fx()` — both views draw that same ring data in their own style.
