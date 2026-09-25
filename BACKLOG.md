# BACKLOG.md — what is built, what is not, and what we decided against

Reconciled against the code on **2026-09-22**. Every "not built" line below was
checked by grepping `src/` rather than trusted from notes — because four
entries in the old list were wrong in the same direction, all claiming
something was unbuilt when it had shipped.

**If you add an idea here, say who it came from and what decision it creates.**
An idea that implies no decision for the player is the one filter that has
reliably caught bad suggestions.

---

## Built — do not re-add

These appear as "designed, NOT built" in older notes. They are all in the code.

| thing | evidence |
|---|---|
| Patrollers | `Entity.patrols`, `Alert.PATROL` |
| Uniques (rat ring, undertaker's shovel) | `Item.CATALOGUE`, `unique` flag |
| Treasure chest | `Tiles.CHEST` |
| Corrupted monsters | `_place_corrupted()`, called from `build_level()` |
| Brazier top-up by guards | `BRAZIER_STOKE`, used in `game_state.gd` |
| Creature awareness | `_can_see(watcher, other)` |
| Scavenger AI | `scavenge` on bestiary entries |
| Banshee death-wail | `wail` |
| Trader presence + intro story | `trader_talk.gd`, `TRADER_FLOORS` |
| Shield gems (bulwark, mirror, boss) | `Item.ELEMENTS` |
| G as the universal action key | `player_pickup()` |
| Build stamp | `BuildInfo.BUILD`, `tools/stamp_build.sh` |
| The trader's shop | `Trade`, `TradePanel`, `GameState.trade_*` |
| Keyboard hold-to-walk, shared with the stick | `HoldRepeat` |
| Armour takes turns to put on | `Item.don_turns` |
| Controller button pictures | `PadGlyphs`, Kenney Xbox Series font |
| Creatures keep off pits when not pathfinding | `can_creature_step` |
| Traffic: friends swap in doorways and corridors | `_gives_way`, `Entity.want` |
| Naming a character on a controller (name list + alphabet) | `NamePanel.pad_act` |
| A flared torch rekindles a brazier (the race) | `FLARE_KINDLE`, `player_kindle` |

---

## Roadmap — the themes ahead

Written 2026-09-25 to share with the testers. Updates now come in THEMES
rather than one idea at a time, so each one can set up the next. Only next
week is scheduled; the rest is order, not dates.

**Just done (this week, being played now).** The trader and its shop. Monsters
that get past each other in doorways instead of jamming. Naming your character
on a controller. A flared torch that can relight a brazier, and a race against
the flare to do it. Creatures no longer get stuck in pits.

**Next week: the breathe pass.** The dungeon should feel alive. All of it
respects the three motion settings (still / simple / full).
- *Impact:* a flash when something is hit, sparks in the colour of a magic
  weapon, monsters that shatter into pieces when they die, a red edge when you
  are hurt, a ring of light when you level up.
- *Living light:* fungus that slowly breathes light, magic weapons that tint
  your torchlight, and a map memory that fades the longer ago you saw it —
  except the landmarks (stairs, doors, braziers, shrines, the trader).
- *Colour by region:* the entrance faintly green, as if you came in from a
  forest; the caves earth brown and grey; the fortress stone greys; the climb
  back out tinged purple with corruption.
- *Small life:* spores drifting off fungus, drips in the caves, bubbles over
  mud, dust in your torchlight.
- *Miasma:* big fungus clusters give off a sickly cloud that hurts anything
  crossing it. Rabbits are immune.

**After that: the combat update.** Tactics in the spirit of AD&D 2nd edition.
- Creatures get a FACING. Attacking with a friend on the far side of your
  target (flanking) does +1; attacking from behind does +2, and the shield may
  not count. It works both ways — packs will flank you.
- Monsters that tire of waiting in a queue look for another way round, which
  is to say they learn to flank on purpose.
- Polearms: javelin (thrown), spear, halberd. They reach two squares and a hit
  passes through to a second enemy in line. Two-handed, so no shield. Fight over
  an ally's shoulder, hold a doorway.

**A scroll session.** Spells, as scrolls: single-use, or charged for several
uses. More than combat. Fireball and teleport have been discussed; the rest is
to design.

**Someday: a 3D mode.** A key swaps between the classic view and a 3D one:
tilted overhead like Diablo, turning in 90-degree steps like Final Fantasy
Tactics, with the same colours and letters — walls stand up as blocks,
creatures as upright letters, and the torch throws real shadows. It never shows
more than classic would, and the turn can snap instantly for anyone who gets
motion sick. Not the "Wizardry-style combat view" declined below: that was a
separate screen for fights; this is a way of seeing the whole game. It starts
as a small experiment.

**Smaller ideas waiting their turn:** wolves (a pack that ignores you unless
provoked); a fungus bag (carry fungus as bait and light); gems from rubble
(being built now); shooting a wall into existence with a crag gem; monsters
that shut doors behind them; the coliseum.

---

## Next up

**1. Tune the trader.** Built 2026-09-24; the full economy is in `src/sim/trade.gd`
and its reasoning in the memory notes. These numbers were NEVER settled and are
marked PROVISIONAL in the code -- play decides them:

- **What consumables cost to buy:** 3 points each for a healing potion, a scroll
  of light and a scroll of blinking. A short sword buys a potion.
- **How many consumables are stocked:** two potions and one of each scroll.
- **How many relics a trader shows:** up to three twice-dead heroes, each as the
  most valuable piece of their kit.

Settled with Brad, 2026-09-24:

- **Which equipment is stocked** goes by tier and by how deep the player has
  BEEN: floors 1-3 sell tier 1; 4-6 tiers 1 and 2; 7 and deeper tiers 2 and 3,
  no tier 1. Floor 6 is the last chance to buy a dagger. Not mirrored on the
  climb -- every climb trader sells tiers 2 and 3. (The first version used a
  `min_depth` window and put a mace on the floor-1 shelf.)
- **Forged items are worth their forging** (`upgrade_level`). The first version
  read `boosts`, which equipment never uses, and sold every +N at base price.
- **Words on the counter:** "credit" and "gems", not "slate" and "stones" --
  stones are sling ammunition.
- **The trader's piles.** The shelf sorts the way a monster that collects would
  sort a hoard, by what a thing is for: everything, things that cut, things you
  wear, things to hide behind, bottles and scrolls, what the dead left. Picture
  buttons with counts; tab / shift+tab, LB / RB, click or wheel. A hero's item
  carries a skull. What the player sold is mint on the shelf and the trader says
  "You gave me this." Brad asked for creativity here, not a copy of the pack.

Decided while building, worth a second look:

- **Credit, not swaps.** Selling puts points on your credit and the item on
  the shelf at the same price; buying spends points. The credit stays with that
  trader while you are on the floor and is lost when you leave.
- **Trading costs no turns**, like talking to the trader always has.
- **Uniques and the amulet cannot be traded.** Neither can arrows or bones.
- **The counter opens after the trader speaks**, including if the story is skipped.

**2. ~~Keyboard auto-repeat.~~ DONE 2026-09-24.** The stick is the only input in the game that
repeats; the d-pad physically cannot, and the keyboard is silenced by the
`echo` filter in `main.gd`. Brad wants desktop to feel like the handheld. Agreed
numbers: `STICK_AGAIN` 0.12 → ~0.25 (8 steps/sec felt like too many), keep
`STICK_FIRST` 0.35, and **add the attack-stop the stick lacks** — travel already
has the rule and the comment.

**3. On-screen pad log.** The diagnostic writes to a file, which a handheld
cannot reach — proved by having to photograph the screen. On a device with no
keyboard and no file manager the only place a diagnostic can go is on screen.

---

## Known gaps

**~~A controller cannot name a character.~~ FIXED 2026-09-25.** Both of Brad's
asks were built: the dungeon's own names to pick from (never the rare three --
they are found, not chosen), and an alphabet walked by the d-pad or stick. A
chooses, B erases, Y flips the case, Start begins. Typing is unchanged.

**InputMap, and when it would be worth migrating.** Suggested by a reviewer, and
the design document names it as the strongest criticism of the input layer. It
is the correct long-term architecture: engine-level actions bound to keys and
buttons together would give keyboard rebinding for free and make the
"modifiers are unreachable from a pad" class impossible.

Deferred on recurring cost. The current translation layer caused one real bug,
which is fixed and guarded. Note that migrating would NOT remove the stale-config
problem — a saved InputMap override shadows new defaults exactly the way
`gamepad.cfg` did. That bug is about persistence, not about the input layer.

**The trigger to revisit:** if keyboard rebinding is ever genuinely wanted —
accessibility, left-handed players, or non-QWERTY layouts where `hjkl` is
miserable. Building that on top of the current system means a second translation
layer, and at that point the seven-file rewrite pays for itself.

---

## Designed in full, not built

**Miasma.** Brad's, and his Nausicaä reference. A fungus cluster (2x2+) gives
off visible bad air. One tile crossed = 3 damage over 9 steps; three tiles = 1
per step. Cured by eating fungus **or** rabbit meat once clear of it — the
fungus poisons you and the fungus cures you.
- Render as a **background wash**, not a glyph: `AsciiTheme.TABLE` carries `bg`
  and all three view modes read it, so letters, symbols and pictures inherit it
  with no per-mode work and no shader dependency.
- A cell state like `brazier_charge`, not a tile type.
- Affects everything, rabbits immune. Add to `Tiles.is_avoided` so monsters
  route around it and kiting becomes a tactic rather than an AI failure.
- Would be the game's first player status effect.

**The coliseum / free-for-all.** Escalating waves, +2 enemies each. All
tombstones present from wave 1, scattered — tombstone COUNT is the real
difficulty dial. Raising is free here and does **not** mark the morgue
reclaimed. Isolate with `use_scratch_files("arena")`. Fungus regrows between
waves and nothing else does. Show elapsed, not turns. Monsters from a director
in code, bypassing the threat ceiling.

**Wolves.** A pack (4+), the game's first genuinely neutral creature — they
ignore you unless provoked. `Faction.NEUTRAL` exists and is now used by the
trader, so the enum is real; wolves would be what makes it matter in combat.

**Armour gems.** Travel (heal by exploring: walkable cells / 10, +1 hp each time
you uncover that many) is the buildable one. **Mule is probably dropped** — its
blocker is the 24-letter inventory pool, i.e. UI work, and the fungus bag covers
similar ground more interestingly. **Dodge stays parked**: it fights
`DAMAGE_FLOOR_FRACTION`, which exists so nothing ever whiffs.

**Doors that close behind things.** Cheapest big win on the "creatures acting on
the map" axis: every door the player has seen was closed until they opened it,
so a closed door reads as unexplored. Something that shuts one behind itself
turns the player's own map-reading against them.
- **It conflicts with a tell that already exists** (noted 2026-09-25). Creatures
  open doors and bears smash them, but nothing ever SHUTS one --
  `_through_the_door` says so on purpose: an open door you left shut is how you
  know something came through. Door-closers would blur that signal to add a new
  one. A design call for Brad, not a build; not to be confused with last week's
  door work (squeezing, shouldering, `c` to close), which is done.

---

## The directional one

**Creatures noticing creatures.** Brad's open-world thesis: emergent systems do
not promise outcomes, they make outcomes possible. `_can_see` shipped, which was
the foundation. What still waits on it: predation, hunting parties,
alarm-raising, packs travelling together, handing items over, blood trails,
fungus spreading.

Measured: a killer rabbit cannot beat a healthy bear. What **is** reachable is a
rabbit finishing a bear the player wounded — a scavenger's victory. That is the
shape to aim at.

---

## Ideas, not yet designed

**The fungus bag** (unique). Store fungus rather than eating it on the spot.
Brad's original idea was **rabbit bait and portable light**, and that is the
version worth building — the healing combiner (meat gains +1 heal per stored
fungus, once) was dropped because healing is already abundant and measured flat
at ~75 hp a floor while max HP triples.

Expanded 2026-09-22: **a dropped fungus distracts scavengers.** They notice it
and stop for a few turns, cycling the existing `..?` / `.?.` / `?..` animation,
then move on. That makes it a stealth tool, which is the right register — the
ascent is a sneak game.
- Placing a tile is easy and already done: the crag gem calls `map.set_tile()`
  and records the cell so `_let_the_stone_settle` can revert it. A fungus would
  be the same call **without** the timer.
- Note fungus is TERRAIN (`Tiles.FUNGUS`), not an item, and `is_luminous` is a
  property of the tile — so making it carryable is new plumbing.
- No "pick up or eat?" prompt needed: if the bag makes G store, eating stays in
  the inventory where every other consumable already lives.
- Watch the caves. Fungus is the deliberate replacement for potions down there,
  so hoarding softens exactly the pressure that band is built on.

**Gems from somewhere other than chests.** Brad's, 2026-09-22: sack ultra-rares,
or a 1-in-100 chance while knapping rubble. The gem pool is 8 now and `roll_gem`
picks uniformly, so every new stone dilutes the others — this fixes that while
giving non-combat actions a payoff.

**Shooting a wall into existence.** A crag gem on a missile weapon, fired at an
empty tile. Half exists already: `accepts_element` allows crag on any weapon, so
a crag bow raises spires around whatever an arrow hits. The new capability is
firing at *ground*, which collides with the guard that refuses a cell with no
target. The good part is the economics: arrows are the only strictly closed
resource in the game, while sling stones are knapped from rubble — so the same
wall costs a permanent resource with a bow and a renewable one with a sling.

**Fireball scroll.** Asked for by a player. Passes the filter: it implies a
decision (where to aim, when to spend it).

**Rename `Entity.charges` → `dash`.** It is a bull-rush flag colliding with
brazier charges in every reader's head.

---

## Declined, and why

- **Money as a currency.** Needs prices for everything, then needs protecting
  from farming. Trade sidesteps both.
- **Custom weapon skins.** Brad's own verdict. Reskinned same-tier weapons are
  cosmetic only, and it overlaps the Kenney art sets already planned as a theme
  system through the `RenderTheme` seam. If it ever matters, it belongs there.
- **The wizard's tower.** Declined 2026-09-16.
- **One-way teleporter.** Declined 2026-09-16.
- **Stats and chargen.** Deferred indefinitely — stats without varied content
  are just numbers. What Brad wants near-term is only "name your character".
- **More animals to look at.** Requested by a player who said they did not like
  the fighting. No decision attached; it is a different game.
- **New Game Plus.** Not declined, deliberately deferred: you have to beat the
  game to see it. If built, scale monster stats, their THREAT and the ceiling by
  one multiplier together, or a doubled ceiling just buys twelve rats.
- **An item that lets you fly.** Asked for by David; declined 2026-09-25.
  Flying over everything would stop about three quarters of all combat — the
  game is built on positioning, doors, corridors and terrain, and flight
  deletes all four.
- **Wizardry-style 3D combat view.** The original vision, dropped early:
  encounter frequency kills modal view-switching. The renderer seam keeps it
  addable.

---

## Keeping this honest

The old list drifted because entries were written when a thing was designed and
never revisited when it shipped. Two habits:

1. **Grep before believing a "not built" line.** Four were wrong.
2. **When something ships, move it to the Built table in the same session.**
