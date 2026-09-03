# ofr

An old fashioned roguelike. ASCII-styled, but not a terminal program: it opens
its own window and draws its own glyph grid, so it controls its font, its
palette, its cell geometry and its mouse.

Godot 4.7. Windows and Linux.

## Running

    godot                                        # play
    godot --headless --script res://tests/run_tests.gd   # simulation tests
    godot --script res://tests/capture.gd -- /tmp/shots  # screenshots

## Controls

| | |
|---|---|
| arrows, `hjklyubn`, numpad | move (8-way); move into something to attack it |
| `.` or numpad `5` | wait a turn |
| `>` | descend, when standing on stairs |
| `x` or `;` | look mode: drive a cursor with the movement keys, `esc` to exit |
| `g` or `,` | pick up what you are standing on |
| `i` | inventory — click to use, right-click to drop, or press the item's letter |
| left click | travel to a seen cell, stopping if anything comes into view |
| hover | inspect a cell; the route there is previewed as dots |
| `R` | new game |

## Items

Three consumables so far: a potion of healing, a scroll of light, and a scroll
of blink. All of them are deliberately **untargeted**.

That is a scope boundary, not an oversight. Targeting needs a cursor, a
line-of-fire check and range validation -- it is its own feature, and folding it
in here would have tripled the size of this step. Fireball waits until there is
something to aim it with.

Two rules the item code keeps, both of which matter more than they look:

- **A refused item costs nothing.** Drinking at full health declines, and
  spends neither the potion nor the turn. Losing a potion to a misclick is the
  kind of thing that makes people put a game down.
- **Inventory lives on `Entity`, not on the player.** Lootable corpses later
  are a read of a field that already exists rather than a new system.

## Layout

    src/sim/      the game. No Godot nodes, no drawing, no input.
    src/render/   glyph grid, palette, themes
    src/ui/       sidebar and message log
    tests/        headless test suite and a screenshot tool

### The one rule

**`src/sim/` never knows how it is drawn.** It owns no nodes, references no
scene tree, and emits only *semantic ids* -- `&"wall"`, `&"goblin"` -- which a
`RenderTheme` turns into something visible.

That single boundary is what buys:

- **Headless tests.** `run_tests.gd` generates two hundred dungeons and asserts
  every one is completable, in under a second, with no window open.
- **A tileset mode later.** Subclass `RenderTheme` to return atlas regions
  instead of characters, write a `TileGrid` mirroring `GlyphGrid`, and swap
  which node the scene instantiates. Nothing under `src/sim/` changes.
- **A party later.** The player is already just an `Entity` with `is_player`
  set, not a special case. Four of them is a list, not a rewrite.

### The other rule

**Game time advances only through `Scheduler`, never in `_process`.** Godot's
frame loop drives animation, flicker and input polling. If it ever drives the
simulation, the game stops being turn-based in ways that are miserable to
debug.

## How the dark works

Two separate systems that are easy -- and wrong -- to conflate:

- **Field of view** is game logic. Recursive shadowcasting in `fov.gd`, near
  perfectly symmetric, so "the player can see it" and "it can see the player"
  agree and the AI can rely on one pass.
- **Lighting** is presentation. `light_map.gd` accumulates coloured light per
  cell; every source casts its own shadows, so a torch stops at a corner
  instead of bleeding through it. Warm at the core, cold at the rim.

Cells are drawn in three states, which is what makes a map feel like a map:
lit now, remembered (cold and dim), and never seen (nothing at all).

Torch flicker lives in the renderer, not the simulation, so the simulation
stays deterministic and seed-reproducible.

## Wall styles

`GlyphGrid.wall_style` is exported: `LINE` (default), `SOLID`, `GLYPH`.

Walls are drawn from a neighbour connection mask rather than a font glyph,
because a box-drawing character only fills ~0.6 of a square cell and a run of
`═` comes out visibly dashed. `GLYPH` mode is kept so the difference is easy to
see for yourself.

## Credits

JetBrains Mono, SIL Open Font License 1.1 -- see
`assets/fonts/JetBrainsMono-OFL.txt`.
