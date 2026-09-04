# ofr

An old fashioned roguelike. ASCII-styled, but not a terminal program: it opens
its own window and draws its own glyph grid, so it controls its font, its
palette, its cell geometry and its mouse.

Godot 4.7. Windows and Linux.

## Running

    godot                                        # play
    godot --headless --script res://tests/run_tests.gd   # simulation tests
    godot --headless --script res://tests/xp_curve.gd    # power vs threat curve
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
| `tab` | inside the inventory: cycle the category filter (`shift+tab` backwards) |
| left click | travel to a seen cell, stopping if anything comes into view |
| hover | inspect a cell; the route there is previewed as dots |
| `R` | new game |

## Items

Three consumables -- potion of healing, scroll of light, scroll of blink -- and
six pieces of equipment across two slots: dagger, short sword and war axe;
leather armour, chain mail and plate mail.

The consumables are deliberately **untargeted**.

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
- **One action for the whole list.** Clicking a row does the obvious thing: a
  potion is drunk, a sword is wielded, a worn item is taken off. The player
  should not have to remember which verb a given slot wants.
- **Letters belong to the item, not to the row.** An item is assigned a letter
  when it enters the pack and keeps it until it leaves; the letter is freed for
  reuse afterwards. This is what makes sorting safe. With positional letters,
  picking up a sword would silently rebind the healing potion from `b` to `c`,
  and every key the player had memorised would quietly become wrong.

The list is grouped -- equipped items first, then weapons, armour, potions,
scrolls -- and sorted best-first within each group, so choosing what to wear is
a glance at the top of a group rather than a scan. `tab` filters to one
category; the panel resizes to its contents.

Equipment modifies the `power` and `defense` fields that `Entity` already had,
via `total_power()` and `total_defense()`. Combat reads only those two methods,
so a stat system later slots in there rather than at every call site. **No stat
system was needed to make a sword work** -- that dependency only looks real
when the feature list is read forwards.

## Monsters

Behaviour matters more than the stat block. Six monsters that all walk at you
in a straight line are one monster with six stat blocks, so each family plays
differently instead:

| behaviour | who | what it does |
|---|---|---|
| `hunter` | rat, kobold, skeleton, orc | walks at you and hits you |
| `erratic` | cave bat | moves unpredictably; you cannot reliably disengage *or* corner it |
| `ranged` | kobold slinger | attacks along a clear line, and backs off when you close |
| `pack` | goblin | bold with allies nearby, hesitant alone |

Beyond the deepest tier the fade **stops advancing**, so the heaviest monsters
stay at full weight. Without that clamp the ascent, which runs past depth 10,
would fade every monster in the game out of the pool and generate empty floors.

The deep tiers (ogre, harpy, cave troll, wight, wyvern, stone golem, shadow,
young dragon) run from depth 5 to 10, with power from 7 upward. That floor on
power is not arbitrary: below it a levelled character in chain mail simply
stops taking damage, and the dungeon gets *easier* the deeper you go. They also
carry the entire ascent, which runs at effective depths of 10 to 19.

A **cave troll regenerates** two hit points a turn, awake or asleep. That makes
disengaging a real decision -- wound one, run, come back and it is whole again,
so you either commit to the kill or you wasted the damage. The look panel marks
regenerating monsters with a `*`.

Humanoids can **carry gear** -- a goblin in leather, an orc with a short sword
-- drawn from the same catalogue the player loots, gated by the same depth
rules. Animals and constructs never do.

Two things keep that honest:

- **Gear is paid for in threat.** A monster's `threat` rises by what it is
  carrying, and it is only armed if the room's remaining ceiling can afford it.
  Without that, a room of armed orcs would quietly cost more than its ceiling
  claimed and the survivability guarantee would be a lie.
- **Drops are a coin flip, not a certainty** (`LOOT_DROP_CHANCE`). Guaranteed
  drops would flood the floor, and with forging in the game that compounds --
  three daggers make a +2 dagger.

The look panel lists what a monster is carrying, so a fight can be assessed
before it is committed to.

Any monster can also have a **morale** threshold and run when badly hurt --
except the undead, which never break. A cornered animal with nowhere to run
fights instead.

Capital glyphs mark the dangerous variant of a family: `K` is a kobold that
shoots back.

**`ranged` is the one that pays for the rest.** It needs a clear line, computed
by `los.gd`, so stepping behind a pillar genuinely stops it. Until this pass
the pillars, corridors and torch radius were a tactical stage with nothing on
it that required tactics.

## Combat feedback

A shot **resolves instantly in game time**, exactly as Angband and DCSS do it.
The animation plays afterwards and is pure feedback -- it shows what already
happened, and nothing can be dodged in flight.

That is the turn-based contract, not laziness. Real travel time would put a
reflex test inside a tactical game: the player would have to react during an
animation, punishing a moment of inattention rather than rewarding good
positioning. The dodge already exists, one turn earlier -- it is called not
standing in the archer's line, and it is what the pillars are for. (The
turn-based version of the idea is a *telegraphed* attack: announced on one
turn, landing on the next, so you get a turn to move. Worth having for big slow
enemies later.)

The simulation records events -- `{kind, from, to, amount, on_player}` -- and
`GlyphGrid` drains that queue and animates them. **The simulation never waits
for an animation.** That queue is also what a replay or a scrolling combat log
would need.

What you get:

- a projectile stepping the line at ~28ms per cell (a quarter second per cell
  would add 1.5s to every archer's turn, hundreds of times a run)
- floating damage numbers, drawn with a dark backing so they stay legible
- a hit flash on the cell taking damage
- an HP bar that flares when you are hit and keeps throbbing below 30%
- any damage cancelling auto-travel

Projectiles are never drawn across cells you cannot see, so an animation can
never give away an archer's position.

The effect system is deliberately generic -- a damage number and an overhead
`!` or `zzZ` are the same thing, a marker that appears above a cell and fades.

## Sleep, awareness, and the torch

Monsters start **asleep**. Until this pass everything was omnisciently aware
the instant the player could see it, which handed the initiative to whatever
happened to be in the room.

Three states, not two. A binary asleep/awake makes stealth feel arbitrary --
you are either invisible or caught, with no warning:

| state | marker | behaviour |
|---|---|---|
| asleep | animated `zzZ` | inert; rolls to notice you each turn |
| suspicious | `?` | still inert, but twice as likely to notice; settles after 6 quiet turns |
| awake | a one-shot `!` | full AI; loses the trail after 10 turns without sight |

**The notice roll is dominated by light.** Carrying a torch is both how you see
and how you are seen. `t` smothers it: field of view drops from 8 to 3, the
warm light is replaced by a dim cold radius that reads as dark-adapted eyes,
and you become far harder to spot. Measured over 200 trials at six cells, a lit
torch was noticed **95** times and a doused one **28** -- about a 70% reduction.
It costs a turn, because going dark should be a decision.

Two things always give you away regardless: standing adjacent, and fighting.
Combat noise wakes anything within four cells and deliberately ignores line of
sight, because noise travels through stone.

Markers are drawn from *state* (`zzZ`, `?`) while the `!` is an *event*, so it
fires once on the transition. And no effect is ever drawn over a cell the
player cannot see -- an animation must never give away a position.

## Forging

Two identical weapons or armours can be merged into one at **+1**, capped at
**+2 over base** — so a dagger tops out at +4 and plate at +7. Three of a kind
is the whole cost. Shift+click the survivor in the inventory, or shift+letter.

**It costs brazier charge, from the same pool as healing.** That is the point:
standing at a brazier hurt, with two daggers in your pack, should be a genuine
choice between recovering now and hitting harder later.

Durability was the other candidate for that cost and it fails, for a specific
reason: it punishes *using* the good item, so players hoard the +3 dagger for a
fight that never comes and play the whole run with the +0 one. Brazier charge
gives the same decision, recurring, with no bookkeeping and no hoarding.

Merging never replaces the reason to find better gear — an upgraded dagger
never catches a war axe.

## Resting at braziers

Waiting (`.`) beside a lit brazier restores 2 hit points and draws down a pool
of 10. When the pool runs out the brazier gutters and goes dark for good, so
you can see at a glance which ones you have already burned.

The cost is not obvious and is the reason this heals slowly rather than all at
once: **resting parks you in the brightest cell on the level while the world
keeps taking turns.** Under the awareness rules that is exactly when you are
most likely to be noticed. An instant heal would have been free, and a free
heal is not a decision.

Resting at full health wastes nothing.

## The amulet, and the way out

The dungeon bottoms out at depth 10. There are no stairs down there -- where
they would have been sits the **Amulet of the Deep**, and taking it turns the
run around.

The floor regenerates on pickup rather than being restored, and the fiction
carries that: the artefact was trapped, the depths rearrange behind you, and
more things are awake than were before. That justifies the new layout *and* the
heavier population, and it costs nothing -- remembering ten floors would have
meant serialising them.

**The climb out is harder than the climb down, and it tightens as you near the
exit:**

    effective_depth = MAX_DEPTH + (MAX_DEPTH - current_floor)

Floor 10 fights at depth 10; floor 1, with daylight in sight, fights at depth
19. Measured, the room threat ceiling runs 30 -> 40 -> 48 on the way up, against
12 on floor 1 on the way down -- four times worse in the same place.

Tension should peak at the door, not ease off as you approach it. And because
you no longer need to explore, only to escape, dousing the torch stops being a
tactic and becomes the whole game.

`<` climbs. Everything else is unchanged.

## Experience and levels

A kill is worth its `threat` -- the same number the encounter ceiling is built
from, so there is no second table to keep in sync. Descending pays
`ceiling x 6` for the floor just survived.

**The split exists because stealth is intended play.** If XP came only from
kills, creeping past things would quietly fall behind the depth curve and the
game would punish its own best mode. Measured over 20 runs to depth 10, a
player who kills nothing still earns 46% of what one who kills everything does
-- behind, but not hopeless. Descending drives progress; fighting accelerates
it.

A level grants +5 max hit points (healed immediately), +1 power on even levels
and +1 defense every third.

### Why not D&D's curve

D&D 2024's table is 300 / 900 / 2,700 / 6,500 / 14,000 -- explosive early, then
flattening. That shape is built around campaign tiers across dozens of
sessions, where levels 1-4 are meant to pass quickly. Scaled to a run of this
length it would grant three levels on the first floor and then almost nothing
for an hour. What transfers is the *principle* that each level costs more than
the last; the rate does not. Ours is quadratic rather than exponential.

Run `tests/xp_curve.gd` after changing any of it.

## Room materials

Every room already had an archetype -- plain, pillared, shrine, collapsed,
pool. The renderer drew them all in identical stone, so that information was
generated and then thrown away. `materials.gd` gives each region a semantic
material (stone, flooded, ruin, sanctum, cavern) and the palette turns that
into colour.

**This is navigation, not decoration.** At 96x54 every remembered room used to
look like every other remembered room; now you recall *the flooded room* rather
than *a room*.

Two rules keep it from breaking the thing it sits on top of:

- **The terrain is tinted, never the light.** The lighting channel already
  carries meaning -- warm is lit now, cold blue is remembered -- and tinting a
  flooded room's torchlight blue would make lit ground read as recalled ground.
  Tinting the stone gives the same atmosphere and leaves that signal intact.
- **Remembered terrain keeps its brightness.** The material is re-asserted
  harder after desaturation (`memory_material_boost`, default 1.8) or memory
  washes every room to the same blue -- but luminance is held to what untinted
  memory would have been, so a tinted room never reads as a lit one.

## The camera

The map (96x54) is larger than the visible grid (72x40), so the view scrolls.

It uses a **deadzone**: the camera holds completely still until the player comes
within `scroll_margin` cells of an edge, then follows. A camera locked to the
player slides the entire map on every step, which is disorienting in a game you
read off a grid — you lose track of where things were between turns.

This is renderer-only. `GlyphGrid` keeps an `_origin` cell, `_screen()` converts
map cells to pixels, and `cell_at()` converts back for the mouse. The simulation
has no idea a viewport exists. The draw loop also walks only the visible window
rather than the whole map, which is most of the cost of a redraw on a large
level.

## Level generation

A pipeline of passes in `mapgen.gd`:

    caves reserved -> rooms -> caves carved -> corridors
      -> cave links -> doors -> decoration -> natural stone

Two orderings in there are load-bearing:

- **Caves are reserved before rooms are placed.** The first version placed
  rooms first and looked for a cave-sized gap afterwards. Rooms fill a 72x40
  map so thoroughly that this produced *one cave in a hundred and twenty
  levels*. Claiming the space up front and making rooms route around it turned
  that into roughly 1.4 caves per level.
- **Corridors are carved after caverns.** Cut last, they punch through whatever
  the cellular automaton left behind, so the level stays connected without any
  special-case repair logic.

Rooms get an archetype -- plain, pillared, shrine, collapsed, or pool -- which
decides both decoration and how dangerous the room is. Decoration only ever
paints over plain floor, so it can never bury the stairs, plug a doorway or
overwrite a corridor.

**Pillars are the interesting piece.** A pillar is solid *and* opaque -- the
inverse of a brazier, which is solid but see-through. Because the field of view
and lighting systems already existed, a pillar immediately casts a real shadow
and gives you something to break line of sight behind. Colonnades are laid on
an even lattice inset from the walls, and that spacing guarantees a free cell
between any two pillars, so a colonnade can never seal a room off.

Masonry and natural stone are separate tile types and are drawn differently:
walls get thin box-drawing lines, cavern rock gets a solid fill with
deterministic per-cell jitter. A cave never looks like a bricked-up room.

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
