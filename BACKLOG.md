# BACKLOG.md — what is built, what is not, and what we decided against

Reconciled against the code on **2026-09-28**, after the breathe pass and the 3D
view were merged. Every "not built" line below was checked against `src/`
rather than trusted from notes — because four entries in an old list were wrong
in the same direction, all claiming something was unbuilt when it had shipped.

**If you add an idea here, say who it came from and what decision it creates.**
An idea that implies no decision for the player is the one filter that has
reliably caught bad suggestions.

**Player feedback lives in `PLAYTESTS.md`** — what testers did, said and asked,
one dated section per session. Decisions that come out of it land here.

---

## Built — do not re-add

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
| **Week of 2026-09-21** | |
| The trader's shop: credit, tiers by depth, piles, relics, "yours", tally page | `Trade`, `TradePanel`, `GameState.trade_*`, `TraderTalk.TALLY` |
| Keyboard hold-to-walk, shared with the stick | `HoldRepeat` |
| Armour takes turns to put on | `Item.don_turns` |
| Controller button pictures | `PadGlyphs`, Kenney Xbox Series font |
| Creatures keep off pits when not pathfinding | `can_creature_step` |
| Traffic: friends swap in doorways and corridors | `_gives_way`, `Entity.want` |
| Naming a character on a controller (name list + alphabet) | `NamePanel.pad_act` |
| A flared torch rekindles a brazier (the race) | `FLARE_KINDLE`, `player_kindle` |
| One gem hidden in each floor's rubble (floor 2 on) | `geode`, `_hide_the_geode` |
| A blank name no longer changes the seeded run | `GameState.choose_name` |
| The bulwark turns aside at most half a blow (was near-immunity) | `_attack`, `block_amount` |
| The gem of the road: first armour stone, rubble only, +1 def per 4 rooms (max 3) per floor | `gem_travel`, `travel_bonus`, `_note_rooms` |
| Trader refuses the road stone; road armour sells only when offered twice | `Trade.refusal`, `road_offered` |
| Guards shut doors behind them (not hunting, doorway clear, silent) | `_shut_behind`, `Entity.shut_behind` |
| Conversations: pad footer names the real keys, B leaves | `TalkPanel.footer` |
| **Day-7 hunt, 2026-09-27** | |
| Shots are fair both ways (symmetric line of fire, player / monster / ally) | `Los.clear_both` |
| A shooter in the dark must stand within 2 cells of your sight's edge | `_fair_from_the_dark`, `DARK_SHOT_GRACE` |
| Click-to-travel opens shut doors instead of standing you in them | `_step_travel` |
| A full pack still takes the stairs / shrine / fungus / rubble | `_use_the_square` |
| The trader is found by identity after a load | `apply_dict` relink |
| Every "pack full" message says what to do, the amulet included | `player_pickup`, `trade_buy` |
| The controller screen shows a binding a later row took, as "unbound" | `PadPanel.row_state` |
| **Breathe pass + 3D view, merged 2026-09-28** (Gabe, Brad, a cloud Claude; guide in `patches/`) | |
| The 3D view: `q` toggles; FFT camera, 45° a press, eight views (diamond / straight) | `DioramaView`, `TURN_STEP`, `view_to_grid` |
| One effects layer both views draw | `fx.gd`, `step_motion.gd`, `creature_marks.gd`, `screen_fx.gd` |
| Impact: lunge, recoil, magic sparks, shatter, red edge, rings, grey on death | `screen_fx.gd`, patch 2 |
| Living light: flicker, fungus breath, magic glow on items, memory fade, remembered trader | `living_light.gd`, `map_memory.gd` |
| Colour by region (hue, never brightness; the climb's purple measured against corrupted monsters) | `region_look.gd` |
| Small life: footfalls, slower steps on heavy ground, spores, drips, bubbles, dust | `small_life.gd` |
| 3D extras: silhouettes behind walls, contact shadows, door swing, camera jolt | patch 6 |
| The trader idles and leans towards you ("full" only) | patch 7 |
| Click-to-move near a watching monster takes one step, then stops (Gabe) | `begin_travel` |

---

## Roadmap — the themes ahead

Updates come in THEMES rather than one idea at a time, so each one can set up
the next. Only the next few days are scheduled; the rest is order, not dates.

**Done:** the trader and its shop, traffic, naming on a controller, the flare
race, the gem of the road; the day-7 hunt's six fixes; and, merged 2026-09-28,
the breathe pass and Gabe's 3D view.

**Next: small things, then play.** See "Next up" below: the new-player fixes from
the 2026-09-26 playtest, David's background music, and the miasma.

**Then: a Dwarf Fortress direction — "which systems fit the game, and would be
fun?"** Brad, 2026-09-28. Both views only DRAW, so this is simulation work.
Start as a brainstorm, not a build. The seed of it is already here, under "The
directional one" below. One rule for everything in it: **every interaction
must leave a trace the player can SEE** — Dwarf Fortress is famously
unreadable, and our own playtest found mud's slowdown invisible until Brad
explained it. The shared effects layer means a new interaction announces an
event once and both views show it.

**The combat update.** Tactics in the spirit of AD&D 2nd edition.
- Creatures get a FACING (the traffic intent `Entity.want` can supply it).
  Flanking does +1; attacking from behind does +2, and the shield may not count.
  It works both ways — packs will flank you.
- Monsters that tire of waiting in a queue look for another way round, which is
  to say they learn to flank on purpose.
- Polearms: javelin (thrown), spear, halberd. They reach two squares and a hit
  passes through to a second enemy in line. Two-handed, so no shield.
  **Brad, 2026-09-28: "ranged" means three things, not one.** Today it means
  a missile in flight (bows, slings). A polearm is MELEE at two squares; a
  thrown spear is a missile again. The code will need the three kept apart --
  reach-2 melee must not go through the shooting path (no ammo, no arrows in
  flight, adjacent-and-next rules) -- and the new reach tint (below, item 5)
  is what shows a spear's two squares.

**A scroll session.** Spells, as scrolls: single-use, or charged for several
uses. More than combat. Fireball and teleport have been discussed; players have
asked for lightning bolt and invisibility (PLAYTESTS 2026-09-26).

**A new-player theme.** An intro sequence on New Game with a skip button (the
trader and why you are here; Brad writes it). The title screen itself is
BUILT (2026-09-28, see Next up 8); How to play and Artwork (a parent's
suggestion, PLAYTESTS 2026-09-26) would be two more rows on it.

---

## Next up

**1. Small fixes from the 2026-09-26 playtest** (see PLAYTESTS.md):
- **The `?` hint** in bold and colour on floors 1–2, back to normal after that or
  once the legend has been opened. Neither teen found the controls alone.
- **Terrain status:** the sidebar's `footing` line becomes a status line with an
  icon ("wading · slowed", "sinking · slowed"); it becomes the home for status
  effects (the miasma is next). Say it in the HERE box too — the Legion player
  learned the game from that box.
- **A clickable "menu" button in the sidebar, and a second menu key** browsers do
  not reserve. In browser fullscreen, Esc leaves fullscreen first; a 10-year-old
  gave up over it. Also set the itch embed smaller (for example 1280×720) — the
  game scales, the 1600-wide frame does not fit a laptop at 125–150%.

**2. David's background music -- MERGED 2026-09-28**, waiting on a listen in
the web build. His `synth.gd` and `sound_deck.gd` came over whole (ours were
unchanged since his base), plus his one hook in `_refresh`; added a separate
music switch (Shift+M, the title's settings), tests, and credit. His preview
WAVs stayed in his folder. Brad may ask David for a title-screen loop.
Original note: (arrived via Gabe, in `~/Documents/ofr-oai`).
Generated in code, no audio files, a motif per band and a bent reprise on the
climb; measured at 1.5% of a core. `main`'s `synth.gd` and `sound_deck.gd` were
identical to his starting point on 2026-09-27 — check again before applying.
Before merging: `.gdignore` its 2.4 MB of preview WAVs, a separate music toggle
(`m` mutes everything today), tests, a listen in the web build, and credit
David by first name.

**3. The miasma.** Designed in full below; the breathe patches left it to us.

**4. Tune the trader.** These numbers were never settled and are marked
PROVISIONAL in `src/sim/trade.gd` — play decides them:
- consumables cost 3 each (a healing potion, a scroll of light, a scroll of
  blinking); two potions and one of each scroll are stocked;
- up to three relics show, each a twice-dead hero's most valuable piece.
Decided while building, worth a second look: credit rather than swaps (lost when
you leave the floor); trading costs no turns; uniques, the amulet, arrows and
bones cannot be traded; the counter opens after the trader speaks.

**5. The 3D view, after play on the web and the Legion:**
- the web build's shaders have not been seen in a browser (press `q` on itch);
- the stick in the diamond views: keys follow the grid lines, so pushing the
  stick along a corridor as it LOOKS walks a grid diagonal — if thumbs fight it,
  it is one line in `DioramaView.view_to_grid()`;
- the per-turn 3D rebuild is ~50 ms; rebuilding only changed cells is the real fix;
- the view tests are light on premise checks — a good day-7 job;
- **the right stick in Firefox on itch -- FIX WAITING ON A TEST (2026-09-28).**
  The pad watch (F8) found it: Godot's web build sends the right stick as
  EVENTS on the trigger axes (axis 5 at +1.00 in its event list) but never
  stores them where `Input.get_joy_axis()` polls -- the polled value sat at
  +0.00 through a full circle. The left stick polls fine. The camera now reads
  each axis as its events last reported it (`Gamepad.track` / `axis`). To
  confirm: F8 in Firefox on itch, circle the right stick -- the `ev` column
  should move and the camera line should reach "firefox-mode" and turn. It may
  need one full circle before it is recognised.
  **Second test, same day: still no turn.** The watch showed `ev +0.00..+1.00`
  on axis 4 with the camera reading 0: Firefox also reports a dead raw axis 4
  (always 0) that Godot writes into the SAME slot every frame, so the last word
  each frame was the dead one. Now the value furthest from zero wins within a
  frame. And Firefox's REAL triggers (axes 6/7, which nothing read) now turn the
  camera too -- a second route whatever the stick does.
  **Third test: CLOSED as "close enough" (Brad, 2026-09-28).** The stick now
  turns the camera in Firefox, intermittently (probably the live value and
  the dead zero landing in different frames); the real triggers still do not.
  Firefox players are advised to turn the 3D camera with `[` `]`, or play on
  keyboard and mouse; Edge/Chrome, Steam and native have full pad support. Do
  not reopen without a new idea -- three evenings went into this one browser. With an Xbox Wireless pad (045e-02fd) Firefox says
  "standard" but reports the right stick's left-right as the LT value resting at
  0.5 (and up-down on RT); the real triggers go to axes 6 and 7. Edge (Chromium),
  Steam and native read it correctly. The game now turns the camera on the
  triggers too, and recognises Firefox's pattern (both "triggers" resting at 0.5
  for a second). Diagnosed with `~/Documents/ofr-hunt/tools/pad-check.html`;
- ~~range is hard to judge in the diamond view~~ BUILT 2026-09-28: while
  aiming, every cell a shot or throw can reach is tinted, in both views
  (`GameState.reach_cells`, asked of `can_reach` so it cannot disagree).
  Strength of the tint wants judging in play.
- **PITS WERE INVISIBLE IN 3D -- FIXED 2026-09-28.** Brad kept falling in. Two
  bugs in the shader's pit: the hole was centred from UV, but the floor is a
  BoxMesh whose top face never covers (0.5, 0.5), so it was never drawn; and
  the lip's edges were as wide as the tile, repainting the hole brown. Now a
  black hole with a stone lip (`tools/probes/screenshot_pit.gd`). The
  shrine's carved ring had the UV bug too.

**6. On-screen pad log.** BUILT 2026-09-28 as the **pad watch** (F8, from
anywhere): Godot's ten axes with the range each has moved, buttons 0-20, the
pad's name and GUID, the browser, the last raw events, and what the 3D camera
read. Still missing: a way to open it on a handheld with no keyboard -- the
controller screen takes raw buttons for rebinding, so no pad button is free
there.

**7. The morgue export.** BUILT 2026-09-28: a pause-menu row. On itch it
downloads `ofr-morgue.txt` -- the only copy there is, since clearing the site's
data erases the browser's user://. On desktop it opens the folder. Brad's one
escape is in his itch browser; this is how it gets out for the retirees.

**8. The title screen.** BUILT 2026-09-28, Brad's design: a remembered,
monster-lit floor behind; the retirement home as a hand-built hall in the 3D
view (three heroes, the traveller, the camera circling, still when effects are
off); continue / new game / Legends Run / settings / exit down the side.
Waiting on play. Open:
- **the Legends Run row is a placeholder**: it appears once the morgue holds an
  escape, and says the home is not open yet;
- **the cottage** (`src/render/title_home.gd`, a stone house on a turf island)
  is kept unused -- Brad has an idea for it;
- sound under the title was not listened to: the placeholder floor behind it
  may play its ambience;
- the escape count reads the text morgue by phrase, because the grave parser's
  pattern cannot match an escape line (no "on depth") -- another reason for
  the JSON morgue.

---

## Known gaps

**One leaked object at every quit since the music (harmless).** Godot reports
an `AudioStreamGeneratorPlayback` leaked at exit whenever the generated music
is playing when the program ends -- with the real audio driver, the dummy one,
headless or windowed, and even after stopping the player in `_exit_tree`.
Engine-side; the process is ending anyway. The quick suite now prints this one
warning after its tally; it is not a failure.

**Test litter in the player's save folder (day-7 job).** Three tests switch to
their own scratch tag inside a loop -- `use_scratch_files("bearfit%d")`
(run_tests.gd ~703), `"pity%d_%d"` (~7900) and a `reach` one -- and never call
`clear_scratch_files()`, so every suite run leaves `scratch_bearfit39_*`,
`scratch_pity59_4_*` and `scratch_reach29_5_*` files behind (now one more each,
legends.json). Harmless, but it is litter in a player-owned folder. Clear and
restore the suite's own tag after each loop.

**InputMap, and when it would be worth migrating.** Suggested by a reviewer, and
the design document names it as the strongest criticism of the input layer. It
is the correct long-term architecture: engine-level actions bound to keys and
buttons together would give keyboard rebinding for free and make the
"modifiers are unreachable from a pad" class impossible.

Deferred on recurring cost. The current translation layer caused real bugs,
which are fixed and guarded. Note that migrating would NOT remove the
stale-config problem — a saved InputMap override shadows new defaults exactly the
way `gamepad.cfg` did. That bug is about persistence, not about the input layer.

**The trigger to revisit:** if keyboard rebinding is ever genuinely wanted —
accessibility, left-handed players, or non-QWERTY layouts where `hjkl` is
miserable.

**The morgue as JSON.** Brad's idea, 2026-09-24. The one-line text morgue has
cost several parsing bugs (the "(element)" suffix that ate weapons, a clause
appended twice, a missing field), and it carries the game's most praised
feature — risen dead and relics (PLAYTESTS 2026-09-26). Convert once into a new
file, never touching the player's `morgue.txt`; store gear as item data rather
than display names. It would also let a bought relic keep its hero's name.
**Priority rose 2026-09-28:** the retired party (Legends) rebuilds heroes from
escape records, and the text line holds no pack and rebuilds gear from display
names. **The record half is BUILT (2026-09-28): `user://legends.json`**
(`LegendsLog`) -- every ending, the whole hero, stats, an id; the text morgue
imported once with duplicates merged; exported from the pause menu. Still
open: the GRAVES still read `morgue.txt`, so relics keeping their hero's name
waits on moving graves over to it.

---

## Designed in full, not built

**The Legends intro -- the game's first cutscene.** Brad's idea, 2026-09-28,
from the cottage built as a first try at the title screen. Build after the
title screen has been played.
1. **Legends Run pressed:** the menu slides away; the cottage
   (`src/render/title_home.gd`, a stone house on a turf island) replaces the
   hall.
2. **Swing to the door:** the orbit speeds up and brings the camera round to
   the front in a second or two -- not a wait for a 48-second pass -- then
   eases.
3. **Push in:** the camera narrows on the lit doorway until the door fills the
   screen, and flares through its warm light rather than cutting to black.
4. **Inside:** the hall (`src/render/title_hall.gd`, the real 3D view) opens
   with the camera just inside its own door, then eases back and up to the
   normal view, and the chosen leader turns and speaks -- through the
   existing TalkPanel, the box players already know from the traveller.
   Expanded later into the Legends story.

Rules: **skippable** by any key or button, straight to the inside; **effects
off cuts straight in** with no camera moves (the 3D view makes one of Brad's
friends unwell). The cottage and the hall should agree: three graves on the
same side, the door on the same wall, windows where the hall has them, the
chimney over the hearth. Until Legends exists, this can replace the Legends
Run placeholder, ending with the leader saying the home is not open yet.

**Miasma.** Brad's, and his Nausicaä reference. A fungus cluster (2x2+) gives
off visible bad air. One tile crossed = 3 damage over 9 steps; three tiles = 1
per step. Cured by eating fungus **or** rabbit meat once clear of it — the
fungus poisons you and the fungus cures you.
- Render as a **background wash**, not a glyph, in both views; billowing only on
  "full". The fungus keeps its glow — the glow invites, the cloud warns.
- A cell state like `brazier_charge`, not a tile type.
- Affects everything, rabbits immune. Monsters route around it, so kiting
  becomes a tactic rather than an AI failure.
- The game's first player status effect — show it in the new status line.

**The coliseum / free-for-all.** Escalating waves, +2 enemies each. All
tombstones present from wave 1, scattered — tombstone COUNT is the real
difficulty dial. Raising is free here and does **not** mark the morgue
reclaimed. Isolate with `use_scratch_files("arena")`. Fungus regrows between
waves and nothing else does. Show elapsed, not turns. Monsters from a director
in code, bypassing the threat ceiling.

**Wolves.** A pack (4+), the game's first genuinely neutral creature — they
ignore you unless provoked. `Faction.NEUTRAL` is used by the trader, which is
found by identity since 2026-09-27, so other neutrals are now safe to add.

**Armour gems for the loot table.** The gem of the road is deliberately kept
OUT of the loot table (`only_from: rubble`), so armour gems in found magic are
still at zero; Brad wants three per slot, like weapons and shields. The hosting
plumbing (`hosts: armour`, binding at the embers) is built. **Mule is probably
dropped** — its blocker is the 24-letter inventory pool, and the fungus bag
covers similar ground. **Dodge stays parked**: it fights
`DAMAGE_FLOOR_FRACTION`, which exists so nothing ever whiffs.

**Hidden traps.** From the playtest ("if I can spot a trap I'll never step on
it"). You MAY spot a trap within 3 cells (a chance, likelier in torchlight — one
more cost to dousing); a trap-finding unique for the offhand adds +50%.

---

## The directional one

**Creatures noticing creatures.** Brad's open-world thesis: emergent systems do
not promise outcomes, they make outcomes possible. `_can_see` shipped, which was
the foundation. What still waits on it: predation, hunting parties,
alarm-raising, packs travelling together, handing items over, blood trails,
fungus spreading. This is the seed of the Dwarf Fortress direction on the
roadmap.

Measured: a killer rabbit cannot beat a healthy bear. What **is** reachable is a
rabbit finishing a bear the player wounded — a scavenger's victory. That is the
shape to aim at.

---

## Ideas, not yet designed

**Push-blocks, and ground with height.** David's Sokoban vault, revived
2026-09-28 when Brad saw the chest on its block in the title's hall. The 3D
view already draws heights (walls 1.35, chests 0.65) though the game beneath is
flat, so a crate is the chest's block without the chest. Most of a push exists:
knockback already moves a thing one cell if the cell beyond is clear, and pits
make a natural goal (a crate fills one). Glyphs Brad chose: `nf-md-texture_box`
F0FE6, ASCII `x`, symbol `¤`. **The hard part is soft-locks** -- a crate in a
corner makes a puzzle unsolvable and there is no undo -- so vault layouts that
cannot lock, or a second exit so failing costs the reward and not the run.
Crossovers: a crate shoved into a doorway holds it against a guard; a raised
platform could give shots from it a bonus (the combat update); a ledge reached
only by pushing a crate over first.

**Mercenaries.** A parent at the playtest: the dead-party system takes many runs
to pay off, so why not hire help? Brad's version: the trader offers RISEN
MONSTERS (not heroes) of the kinds on its own floor. Must not undercut bone
allies — weaker, or lasting one floor. A design conversation.

**Kobold slingers' first floor.** Brad's option: they fire every other round on
the first floor they appear, as a teaching floor. Decide after measuring early
deaths — the dark-shot fix of 2026-09-27 may have been most of the pain.

**The fungus bag** (unique). Store fungus rather than eating it on the spot, as
**rabbit bait and portable light**. A dropped fungus distracts scavengers for a
few turns — a stealth tool, the right register for the ascent. Fungus is
TERRAIN (`Tiles.FUNGUS`), so making it carryable is new plumbing. Watch the
caves: fungus is the deliberate replacement for potions down there.

**Shooting a wall into existence.** A crag gem on a missile weapon, fired at an
empty tile. The new capability is firing at *ground*, which collides with the
guard that refuses a cell with no target. Arrows are a closed resource and sling
stones are knapped, so the same wall costs a permanent resource with a bow and a
renewable one with a sling.

**The Horn of Awakening** (unique, Brad's, designed 2026-09-17, never built).
The third unique, from floor 6. Used, it is dropped where it lands and sounds
for 10 turns — the first noise not centred on the player, loud enough to raise
graves. Designed to be STOLEN (hunting the thief is the mechanic), which needs
monsters to carry what they cannot wear and drop what they merely carry.
Recharges from the world's noise, shown like a launcher's ammo; the gong refills
it. Glyph: md-bugle (0xF0DB4).

**Rename `Entity.charges` → `dash`.** It is a bull-rush flag colliding with
brazier charges in every reader's head.

---

## Declined, and why

- **Money as a currency.** Needs prices for everything, then needs protecting
  from farming. Trade sidesteps both.
- **Custom weapon skins.** Brad's own verdict. Reskinned same-tier weapons are
  cosmetic only; if it ever matters, it belongs in the `RenderTheme` seam.
- **The wizard's tower.** Declined 2026-09-16.
- **One-way teleporter.** Declined 2026-09-16.
- **Stats and chargen.** Deferred indefinitely — stats without varied content
  are just numbers.
- **More animals to look at.** Requested by a player who said they did not like
  the fighting. No decision attached; it is a different game.
- **New Game Plus.** Not declined, deliberately deferred: you have to beat the
  game to see it. If built, scale monster stats, their THREAT and the ceiling by
  one multiplier together, or a doubled ceiling just buys twelve rats.
- **An item that lets you fly.** Asked for by David; declined 2026-09-25.
  Flying over everything would stop about three quarters of all combat — the
  game is built on positioning, doors, corridors and terrain.
- **A glow halo around flames.** Declined in the breathe pass: this is a stealth
  game, and a glow would show light where the game has none.
- **Wizardry-style 3D combat view.** The original vision, dropped early:
  encounter frequency kills modal view-switching. The 3D view built instead is a
  way of seeing the whole game, not a separate screen for fights.

---

## Keeping this honest

The old list drifted because entries were written when a thing was designed and
never revisited when it shipped. Two habits:

1. **Grep before believing a "not built" line.** Four were wrong.
2. **When something ships, move it to the Built table in the same session.**
