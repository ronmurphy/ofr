# ofr

An old fashioned roguelike. ASCII-styled, but not a terminal program: it opens
its own window and draws its own glyph grid, so it controls its font, its
palette, its cell geometry and its mouse.

Godot 4.7. Windows and Linux.

## Suspending a run

`esc` opens the menu. **Save and quit writes a single slot, and resuming
destroys it.**

That deletion is the whole anti-scum mechanism: there is never a moment when a
save from *before* something went wrong still exists. Save, load (file gone),
play, save again, load again (gone again) -- no rollback exists at any point.
So the save is always available from anywhere, because there is nothing to
ration. Gating it behind an in-world shrine would only punish people whose
lives interrupt them, not people who play badly.

Resuming restores the **exact state** -- your position, the monsters where they
stood, which of them had noticed you, the turn count. Not the top of the floor:
a checkpoint would reintroduce the very scumming this design removes, since you
could die and replay a floor already knowing what is in it.

Abandoning a run forfeits the slot, and dying clears it.

Every finished run appends a line to `user://morgue.txt`:

    2026-09-03 22:14:07  level 8  killed by a wyvern on depth 7, with the Amulet, after 4812 turns

Only `src/sim/` is serialised, which is what the no-Godot-nodes rule was for.

## Running

    godot                                        # play
    godot --headless --script res://tests/run_tests.gd   # simulation tests
    godot --headless --script res://tests/xp_curve.gd    # power vs threat curve
    godot --script res://tests/capture.gd -- /tmp/shots  # screenshots
    godot --headless --script res://tests/audition.gd -- /tmp/wav  # every sound as .wav
    tools/build_web.sh                                  # web export, zipped for itch.io

## Controls

| | |
|---|---|
| `hjklyubn`, numpad | move in **eight** directions; move into something to attack it |
| arrow keys | move in **four** directions only -- they have no diagonals |
| `.` or numpad `5` | wait a turn |
| `>` | descend, when standing on stairs |
| `x` or `;` | look mode: drive a cursor with the movement keys, `esc` to exit |
| `g` or `,` | pick up what you are standing on |
| `i` | inventory — click to use, right-click to drop, or press the item's letter |
| `tab` | inside the inventory: cycle the category filter (`shift+tab` backwards) |
| left click | travel to a seen cell, stopping if anything comes into view |
| hover | inspect a cell; the route there is previewed as dots |
| `?` or `F1` | legend: every glyph in the game, generated from the tables |
| `m` | mute; `-` and `+` set the volume. Kept in `user://settings.cfg` |
| `v` | cycle the view: letters or symbols |
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

## Shooting

Launchers -- sling, short bow, war bow -- sit in the weapon slot and **trade
damage for reach**. At every tier the ranged option is about two points weaker
than the melee one, and that gap is the price of never being adjacent.

Two ways to shoot, because roguelike players split hard on this and neither
half should feel like the afterthought:

- **`f`** opens a targeting cursor on the nearest legal target. `tab` cycles
  (`shift+tab` backwards), the movement keys steer it freely, `enter` fires,
  `esc` cancels.
- **Right-click** a monster and it is shot, no mode and no confirmation.

Right-click rather than left, deliberately: aiming can then never be confused
with the click-to-travel that shares the same map.

The aim line is drawn **green when the shot is legal and red when it is not**,
with the reticle matching. A blocked shot has to *look* blocked before the
player spends a turn discovering it -- which is also what finally makes pillars,
stalagmites and doorways matter from the player's side of the fight rather than
only the monsters'.

Shooting empty floor is refused rather than spent. There is no ammunition, so
nothing is gained by it, and a misclick should cost nothing.

Monsters roll melee weapons only. A goblin handed a bow would carry reach its
`pack` behaviour never uses, which reads as a bug rather than a surprise.

## Throwing

Daggers and swords can be **hurled**; bows, armour and potions cannot, and
light things fly further (dagger 5, short sword 3, war axe 2).

`f` does whatever your hands allow. **Holding a launcher, it shoots. Holding
anything else, it opens the pack filtered to what can be thrown** -- pick one
and the normal targeting cursor appears. That second path is D&D's off-hand
action: your main hand is busy, so you reach for something else.

A thrown weapon **lands where it struck** and can be picked up again, so
throwing is a positioning decision rather than a consumable. It deals its own
bonus plus half your base power, which makes it clearly weaker than a bow --
reach should not be free twice.

This also closes a loop the inventory opened. Spare daggers used to be dead
weight; forging gave them one use and throwing gives them a second, and the two
compete. **Forge the spare into a better blade, or keep it to throw?**

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

## Sound

There are no audio files. Every sound is **synthesized at startup** from a
table of oscillators in `src/audio/synth.gd`, and `src/audio/sound_deck.gd`
plays them off the same event queue the renderer animates from.

Three reasons for generating rather than recording:

1. The screen is a font and a colour table. A recorded door hinge would be the
   only literal thing in the game, and it would sound like it wandered in from
   somewhere else. A square wave belongs next to a `@`.
2. A voice is a Dictionary, so sound is tuned in a text editor beside the tile
   table and the bestiary. The whole game stays editable the same way.
3. Nothing to license, nothing to ship, nothing to load.

The synthesis is primitive on purpose -- oscillator, one-pole lowpass,
sample-and-hold, exponential decay, and that is the whole toolkit. It is
enough, because the ear needs far less than people assume to tell a snapping
mechanism from a breaking bone.

### The rule

**Sound only where it carries information the eye can miss.**

There is no footstep, no swing, no door, no staircase, no pickup. All of those
are fully visible the instant they happen, and a turn-based game where every
keypress chirps is a game people play muted within ten minutes. What is left is
the short list of things the game otherwise only says in the message log --
which is precisely where players stop looking:

| | |
|---|---|
| the noise you make | invisible by design; bones carry seven cells, through stone |
| something noticing you | pairs with the `!` |
| damage, a kill, your death | the health bar is at the edge of vision |
| a trap springing | happens *to* you, with no warning frame |
| a change of footing | the mud slowdown was completely unreadable |
| crossing 30% health | once, on the way down -- a warning that repeats is one that gets ignored |
| a shrine, a forging | rare, and confirmable no other way |

Adding to that list is easy and should be resisted.

### Details that matter

- **Repeats collapse.** Six goblins noticing you at once is one alarm. Played
  straight, six overlapping copies of a 100ms blip is not six alarms, it is a
  click.
- **An arrow's thud waits for the arrow.** The impact sound is held back by the
  same `28ms per cell` the projectile animation uses. Without that, a shot
  across a room is heard before it lands, which reads as a bug even to someone
  who could not say why.
- **Loudness normalisation, not peak.** `gain` in the catalogue is a statement
  of intent, and it has no business being at the mercy of the filter chain. The
  first draft played the voices as summed and the mud squelch came out five
  times quieter than the thud beside it, purely because mud needs a heavy
  lowpass and a lowpass throws away energy. Sounds are now normalised to a
  reference RMS measured over the first 250ms -- roughly the ear's integration
  window, without which a 60ms click and a 1.3s fall are compared on completely
  different terms.
- **Noise is seeded per voice**, so a sound renders identically every launch.
  Unseeded noise is the `Array.shuffle()` bug one layer down, and far harder to
  notice, because nobody diffs a waveform.
- **Settings outlive the run.** Someone who turns the sound off wants it off
  tomorrow, and the suspend slot is destroyed on load -- so it is the wrong
  place to keep anything a player expects to persist.

The decision of what to play is `SoundDeck.choose()`, which touches no node, no
bank and no audio server. That is what lets the mapping be tested headless with
the rest of the game.

## View modes

`v` cycles how the dungeon is drawn. Two modes today:

| | |
|---|---|
| **letters** | `+ ' ~ , * Ω` and `! ? ) } [ "` -- the original |
| **symbols** | `■ □ ≈ ∴ ◌ ✶` and `◔ ≡ † ➜ ◫ ◎` |

Terrain and items change. **Creatures never do**, in either mode, and that is
the whole design of it.

Letters are a taxonomy: `k` is a kobold, `K` is the one that shoots back, `g`
goblin, `G` stone golem. Case and letter carry family and rank for free, across
a bestiary that will keep growing. Symbols carry none of that, and a newcomer
who has never played a roguelike gets no benefit from `k` either -- so creatures
are the half of this problem that wants real pictures, and real pictures mean
an icon font, which is a desktop-sized download. They wait.

The setting persists in `user://settings.cfg`, and the grid, the legend and the
inventory all read one static, because three panels that disagree about the
mode would be worse than having no mode.

### The trap this walked into

The first version of `SymbolTheme` used a shrine gate, a skull, an alembic and
crossed swords. Every one looked right in a terminal. **None of them are in the
font.**

A terminal silently substitutes a system font for a glyph it cannot find, and
so does a desktop Godot build. A *web* build has no system font to fall back
on, so all four would have shipped as empty boxes to anyone playing in a
browser -- and the desktop build would have looked fine the whole time.

What JetBrains Mono actually carries outside ASCII is 43 geometric shapes, 32
block elements, 128 box-drawing pieces, 119 maths operators and 115 technical
symbols -- and in the *pictorial* blocks, exactly **5** miscellaneous symbols
and **12** dingbats. No animals at all. So this mode is abstract-but-evocative,
not pictorial, and it never could have been anything else.

`_test_symbol_theme` now checks every character with `Font.has_char` against
the font the game ships, and checks that none is wider than a cell. Measure the
font, never the terminal.

### Widths

Glyphs are centred **per character**, cached in `GlyphGrid._dx`. That used to
be one number measured from `"M"` and reused, which is correct only while every
glyph is the same width -- and in this font they are not. It is the same lesson
as the dashed walls: one measurement cannot stand in for all of them.

## The web build

One codebase, one scene, one simulation. There is no fork and no `#ifdef` --
`src/platform.gd` is the only file that knows it might be in a browser, and it
knows about exactly three things.

    tools/build_web.sh          # exports and zips for itch.io

### What differs, and why

**1. A browser tab cannot be quit.** `get_tree().quit()` in a browser stops the
main loop and leaves a dead canvas sitting in the page, which looks exactly
like a crash. So the pause menu says *save for later* rather than *save and
quit*, and tells you it is safe to close the tab yourself.

**2. Ctrl+W is one keystroke from destroying a run**, and the canvas is not
allowed to capture it. So the build asks the browser to confirm before the page
goes away -- but only when the run has moved past the last save, which is the
same "unsaved changes" rule every text editor uses. Nagging someone on the way
out of a run that is already written is how a warning gets trained away.

**3. Closing a tab is an accident in a way that closing an application is
not.** The suspend slot is written when the page is hidden.

Point 3 changes a design decision, so be clear about what it does *not* change:
still one slot, still destroyed the moment it is loaded, still no way to roll
back a bad fight. All it does is stop a browser being able to take a run away
in a way the desktop build never could.

That hooks `visibilitychange`, not `beforeunload`. Writes to `user://` land in
IndexedDB and flush asynchronously; beforeunload gives that no time to finish,
while hiding a tab happens long before the page is torn down. It is the
difference between a save that is written and a save that was started.

### Verified in an actual browser

Headless Edge over the DevTools protocol, not by reasoning about it:

- the engine boots, takes keyboard input and renders identically to desktop
- the pause menu shows the web wording
- the unload guard arms on a live run, releases when you save, and re-arms on
  the next turn
- **a run survives a full page reload** -- "You take up where you left off",
  and the slot is still destroyed on load

### Letterboxing

`window/stretch/aspect` is `keep`, not `expand`. The grid, sidebar and log sit
at hand-measured offsets for a 1600x900 surface, so a viewport of another shape
has to be letterboxed rather than handed extra logical space the layout will
not fill. This matters most in a browser, where the canvas is whatever shape
the page gives it.

### Uploading to itch.io

Upload `build/ofr-web.zip`, tick **"This file will be played in the browser"**,
and set the embed to **1600 x 900** with the fullscreen button enabled.

Leave **SharedArrayBuffer support unticked**. It adds cross-origin isolation
headers, which this build does not need -- the export has `thread_support`
off precisely so it runs without them.

`index.html` must be at the *root* of the zip, not inside a folder. That single
mistake is what makes an upload land on a blank page; `build_web.sh` flattens
the archive so it cannot happen.

### Recreating the export preset

`export_presets.cfg` is gitignored, because export configs can carry keystore
paths and passwords. On a fresh clone, add a **Web** preset with:

| | |
|---|---|
| `variant/thread_support` | `false` -- no COOP/COEP headers needed, so it works on itch as-is |
| `html/canvas_resize_policy` | `2` (adaptive) |
| `html/focus_canvas_on_start` | `true` -- otherwise the first keypress goes to the page |
| `vram_texture_compression/for_desktop` | `true` |

Web export templates for the *exact* engine version are needed
(`Editor -> Manage Export Templates`); 4.7 templates will not satisfy a 4.7.2
editor, and the error names the path it wanted.

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

## Shrines

Every level holds one or two **sanctums** -- the gold rooms -- and a sanctum
always holds a shrine. So the room's colour is a promise that one is there,
while the shrine's own colour tells you nothing until you have learned it.

Seven kinds: the quiet (the floor falls asleep and cannot notice you for
twelve turns), the vigil (the floor wakes and knows where you are), embers
(spent braziers rekindle at half charge), the anvil (the forging cap rises for
the rest of the run), mending (a full heal), summons (one to three things
arrive, awake), and the flare (your torch roars for a hundred turns at double
radius and **cannot be smothered**).

**The colour-to-effect mapping is shuffled every run**, through the run's own
rng so a seeded game always hides the same effect behind the same colour. If
blue were always mending, everyone would learn it once and the guess would stop
being a decision. Using a shrine teaches you that colour for the rest of the
run -- the look panel names it afterwards, and calls it "an unfamiliar shrine"
before.

Seven on purpose: at one or two a floor you meet roughly fifteen in a full run,
which is enough to learn five or six colours with confidence. Twelve kinds and
the colour would stop being information at all.

`p` prays. It is its own key, not a step onto the tile, so walking across a
sanctum can never spring a curse.

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

## Motion

Entities are drawn at a **visual position that lags the logical one**, so a
step slides rather than teleporting. The camera glides the same way instead of
jumping a whole cell mid-stride.

This is renderer-only. The simulation resolves a turn instantly and always
will; nothing under `src/sim/` knows any of it exists.

**The rule the whole thing rests on: an animation must never delay input.**
Anything still in flight is settled the instant a new turn starts, so holding a
direction key can never build a backlog. Fast play looks essentially instant;
only considered play looks animated. Get that wrong and a roguelike feels like
wading, which would be a poor joke in a game with mud in it.

It also solves the mud problem properly. The footing row tells you in text what
the game should be showing you -- with motion, a monster visibly takes two
strides while you take one, and difficult ground needs no explanation.

Steps are eased out over 100ms, and an interrupted step resumes from where the
glyph actually looked rather than from the cell it logically left.

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

## Difficult ground

Ground is rolled **separately from archetype**, so the same room shape plays
differently between levels: a pillared hall can be dry on one floor and
knee-deep in mud on the next. Two orthogonal axes multiply the variety instead
of adding to it.

Mud, water and rubble all cost extra to cross -- mud worst, rubble least. The
cost is charged to the **action**, not to the actor's speed, because mud makes
you a slower traveller and not a worse fighter.

Two rules make it interesting rather than merely annoying:

- **Flying things ignore it.** Bats, harpies, wyverns, shadows and dragons.
- **Heavy things suffer worst.** An ogre, troll or golem sinks further than you
  do. That is what makes mud a *tool* rather than only a hazard -- back across
  it and the ogre falls behind while you do not. Measured: 260 against your 200.

Difficult ground is only ever laid over plain floor, so it can never bury a
shrine, a brazier or a staircase, and all of it stays walkable, so it cannot
sever a level.

## Bones, fungus and pits

Three features scattered on top of the ground pass:

- **Bones** cost a little extra to cross, are **loud**, and **crumble as you
  cross them**. That turns a boneyard from a standing toll into something you
  can *prepare*: walk it once while things are asleep and far off, and you have
  bought a silent route for when you need one. Stepping on them
  Stepping on them wakes anything within seven cells, ignoring line of sight,
  because noise goes through stone. Until this, the awareness system had
  exactly one input: light. Now it has two, and a floor you can *see* is
  dangerous to cross quietly.
- **Fungus** glows faintly -- light you did not have to carry and cannot put
  out. Useful, and it also means standing in it makes you visible.
- **Traps** spring once, hurt, make noise and are gone. **Visible**, like pits
  -- every death in this game should be one the player could have avoided, and
  a hidden trap is the one thing that guarantees otherwise.
- **Pits** drop you to the next floor for some damage. They are walkable so
  falling in is always a choice, but the **pathfinder treats them as solid**,
  so neither auto-travel nor a pursuing monster can ever put you down one. You
  never land in another pit, and none generate on the bottom floor or during
  the climb out.

Both pits and traps are placed **only where all eight neighbours are open**.
The pathfinder treats them as solid, so one dropped into a corridor severs the
route -- the 200-seed connectivity test caught precisely that, three levels in
two hundred with unreachable stairs.

## Vaults

Hand-authored rooms in `assets/vaults/*.txt`, read at startup. Roughly seven
floors in ten carry one; a couple carry two. A vault that turns up every single
level is furniture.

**Vaults claim their space before anything else.** They are the least flexible
thing on a level -- a fixed rectangle that cannot be nudged or reshaped -- so
rooms and caverns fit around them rather than the other way round. Every cell a
`terrain: fixed` vault owns is **protected**: corridors, decoration, the terrain
pass and the scattered features all route around it, so a hand-drawn room
survives every later pass exactly as drawn.

Each is joined to the nearest room **through one of its own doors**, rather than
having a corridor punched through a wall wherever it happens to arrive.

**A door that leads nowhere is sealed back into wall.** Forcing a corridor to
every door on a four-door vault would turn it into a crossroads; leaving them
open onto solid rock is a small lie. A door counts as live when it has walkable
ground on two or more sides, which covers both an interior door joining two
halves of a vault and an exterior one a corridor actually reached. The last live
door is never sealed, so this can never cut a vault off.

`rotate: yes` gives free variety on symmetric shapes -- a diamond turned 90° is
still a diamond, but its doors land somewhere new.

Contents (`m M ? ! ) [ }`) are the author's, but still answer to the level's
threat ceiling: an over-stuffed vault drops what it cannot afford rather than
producing a room nobody could survive. `M` draws from two tiers deeper than the
floor.

Author them in `tools/vault_editor.html` -- a single self-contained page, no
build step, opens straight off the filesystem -- or in any text editor.
Validate with `tests/vault_lint.gd`. It shares this parser and these rules, so a
vault that lints is a vault that loads.

### The connectivity net

`_ensure_connected()` runs last and guarantees the level is one connected space
whatever every pass before it did -- flood-filling by the *pathfinder's* rule
(walkable and not avoided, since a region reachable only across a pit is not
reachable at all) and carving between any regions it finds separated.

A safety net rather than a plan. Vaults and caverns both claim ground that
corridors were counting on, and the alternative is discovering that in a seed
nobody ever plays.

## Diagonals

Reported by the person who built the game, after playing it for a week: he did
not know he could move diagonally.

He uses a keyboard with no number pad and had been playing on the arrow keys,
which are orthogonal only, while every monster on the floor moved and struck in
eight directions. The sidebar said `arrows / hjklyubn  move`, which reads as
though the two are the same thing. They are not, and nothing anywhere said so.

Worth being blunt about the consequence: **every difficulty judgement made
before this was made by a player with four directions against enemies with
eight.** "I have never made it past floor 3" may be substantially this.

The fix is a picture rather than a sentence, in the `?` legend:

        y k u     7 8 9
         \|/       \|/
        h-@-l     4-@-6
         /|\       /|\
        b j n     1 2 3
        the arrow keys give you four directions, not eight

### The corner rule

Chasing that down turned up a second thing. **Four pieces of code moved
something, and only one obeyed the corner rule.**

Hunting monsters route through `AStarGrid2D` with
`DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES`, so they never cut between two solid
cells. The player, a fleeing monster and an erratic one all moved directly and
checked only whether the destination was walkable -- so all three could slip
through a wall joint that a hunter had to walk six turns around. A monster
could be shaken off by stepping through a gap it was not allowed to follow you
into.

That was not a designed advantage, it was two code paths disagreeing. The
comment in `pathfinder.gd` even claimed the opposite was happening -- that the
rule existed to stop monsters using gaps the player could not.

`GameState.can_step` is now the single rule, and a test walks **31,880
diagonals across eight dungeons** asserting it agrees with the pathfinder
everywhere. The one deliberate disagreement is pits and traps: they are
walkable but the pathfinder treats them as solid, so auto-travel routes around
rather than dropping you down a hole. Stepping into a pit stays a decision the
player is allowed to make.

**Reach is untouched.** Attacks stay eight-way for everyone, including around a
corner. Only the *step* is something walls get a say in.

### Where reference material lives

The sidebar had grown a sixteen-row key block that had stopped being a
reference and started being wallpaper. It now shows six keys plus `?`, and the
legend carries the full list -- generated from the same table, so the short
version cannot drift from the long one.

## Three connectivity bugs, found from one screenshot

Reported from play: *a brazier in the shrine is blocking the entrance*, plus a
sense that some corridors were arriving at odd angles. That turned out to be
three separate faults, and the second two had been there far longer than the
first.

### 1. Decoration standing in a doorway

`_try_place` only checked that it was painting over plain floor. The comment
above it claimed that meant it "can never plug a doorway", and that was simply
wrong: it stops a brazier landing *on* a door, but nothing stopped one landing
on the floor tile just inside one. `_decorate_shrine` was the worst offender --
it puts braziers two cells either side of the room centre, which in a six-wide
room is the tile in front of the west door.

**16 plugged doorways in 480 levels, every one with a solid decoration beside
it. Zero after.** Solid decorations now refuse any cell that is the only link
between separate patches of open ground, counted by walking the eight
neighbours as a ring. Only braziers were affected -- 6.81 per level to 6.14.
Pillars, shrines and stalagmites were never in bottlenecks to begin with.

That also explains the odd corridors. The plugged door severed a region,
`_ensure_connected` rescued the level by carving a fresh passage in from
somewhere else, and the result was a blocked door *plus* a corridor arriving
from nowhere.

### 2. The connectivity check disagreed with the pathfinder

`_walkable_regions` flood-filled through diagonals. The pathfinder runs
`DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES` and will not cut the corner between two
solid cells. So a room joined to the level by nothing but a diagonal squeeze
counted as connected, `_ensure_connected` saw one region and did nothing, and
the player could not walk through.

Four-way flooding is exactly right rather than merely conservative: any
diagonal step the pathfinder allows needs both adjacent orthogonals open, and
that is an orthogonal route already.

This is the same function that was fixed once before for having the wrong rule
about which *tiles* count. This time it had the wrong rule about which *moves*
do.

### 3. Corridors could not reach a vault

`_carve_h` and `_carve_v` skip `protected` cells so that an authored vault
arrives on the map as it was drawn. But that refusal is silent, and it is
silent in precisely the case where it matters: when the region being connected
*to* is the vault. The corridor stopped at the vault's edge and the vault
stayed an island.

**Five shrines in 250 stood in rooms with no way in** -- the whole vault was
unreachable, not just the shrine. The stairs were always fine, which is why the
200-seed completability test never caught it.

`_ensure_connected` now notices when a carve changed nothing and retries
allowed through vault ground. A vault with one unplanned doorway is a far
better outcome than a vault nobody can enter.

### The rule that came out of it

**`_ensure_connected` must be the last pass that can affect walkability.**
`_seal_blind_doors` used to run after it, which meant sealing a vault's one
live door produced an island nothing checked again. `_naturalise_cave_walls`
still runs afterwards, and that is fine -- it only turns `WALL` into `ROCK`,
and both are solid.

Result: **160 of 160 levels are now a single connected region**, and every
shrine on every one of them can be reached. Before, 25 of 160 had a stranded
region averaging 66 cells -- a whole room each. The encounter curve is
unchanged.

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
