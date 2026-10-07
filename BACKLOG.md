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

**THE NEXT BIG UPDATE: THE HOUSE -- the cosy update (Brad with Steph and
Michelle, 2026-10-06; designed with the desktop session the same afternoon;
not started).** A week of sessions, in slices that each ship alone. It
came from the testers: both asked, every other day, whether the house in
the Legends intro screenshots was "built in yet". Both play The Sims and
Moonlighter. Brad's judgement: it adds cosy play to the game, explains the
house the intro shows, and may draw players the dungeon alone would not.

- **THE ONE RULE: the house TAKES and never GIVES.** Nothing carried out of
  a run ever comes back into a run. The moment it does, every run starts
  with the best gear ever found and the roguelike is gone (Moonlighter gets
  away with it through the shop; we declined the money loop). So: an item
  set down in the house becomes a DISPLAY PIECE, forever -- the first press
  warns ("set here, it becomes a display piece and never comes back"), the
  same press again does it (the bump warning's shape). Decorations,
  trophies, pools, pillars, gardens, gravestones, retirees. A garden's
  green fungus stays at home. Eating or healing AT HOME between floors
  would be the first "give": not at first, and only ever on purpose.
- **The visit (Michelle):** at the stairs, G asks house or next level. The
  house sits BETWEEN floors, where build_level already runs, so the one-way
  dungeon holds: no floor is revisited, nothing freezes mid-floor. A magic
  door in the house, its own colour (a Diablo portal), brings you to the
  NEXT level. The house is a small persistent map of its own, kept across
  runs in a player-owned file (`house.json`; `use_scratch_files` must move
  it FROM ITS FIRST COMMIT -- the gamepad.cfg lesson). Death keeps what
  reached the house: a softer edge, the thing cosy players need.
- **The lot, not a growing map:** a fixed lot about a third of a dungeon
  floor, the starter house in the middle, the boundary wall fixed. The
  house grows by building OUTWARD inside the lot; filling it is the cosy
  endgame. One save shape, one renderer path, no resizing. One editing
  rule: you may never wall yourself off from the portal door (a flood fill,
  as mapgen already keeps stairs reachable). The testers WILL knock down the
  starter walls and add rooms: wall and floor placement with the cursor,
  blocks spent and refunded, is the editor.
- **The builder's kit (Steph):** a floor-1 unique with shelves like the
  forager's satchel, holding materials, not letters: rubble -> blocks (the
  rubble's second use; flint was parked), SCRAP WOOD as a new ground
  decoration like rubble on about every floor, so the player SEES wood (in
  the fiction: the guards' logs, broken furniture, driftwood), and the
  terrain edits we do already: water tiles, mud, pillars taken from the
  floor you are leaving anyway.
- **Recipes:** "this is what you have, so this is what you can build" -- a
  table of costs (a table: 3 wood + 1 block; a basin: 6 blocks + 2 water;
  Brad's numbers), in the TRADER SCREEN's shell: categories (walls,
  furniture, garden, memorials), greyed where unaffordable, placed with the
  cursor, pad filters on the shoulders. No crafting grid.
- **The people:** a hero who escapes with the amulet RETIRES to the house,
  an NPC you can see and who says a line about the run (the HERE box as
  teacher). A hero who died gets a GRAVESTONE in the yard -- and that
  removes them from the dungeon's grave pool (legends.json), so burying
  your own history is a choice with a cost. Legends, graves and bone allies
  meet in one place.
- **Art:** no modelling week. Walls are geometry already; the pillar and
  the stalagmite are primitives (a cylinder, a cone); furniture is eight or
  ten more such shapes -- a slab on posts, a box, a pane, a low box with the
  water material -- built once, reused by every recipe in the family's
  colour, sized by the billboard table; icons for the picture look are
  codepoints the full Nerd Font has (bed, table, chair, lamp, fence,
  flower) -- a theme line, a size, a font rebuild. CLASSIC AND EXTENDED ARE
  NOT SKIPPED: one furniture glyph per family in the family's colour is
  nearly free and keeps the house usable by letters. Lower fidelity, never
  absent. The 3D camera's rules hold in the house (Steph).
- **The house never draws on the run's random stream (2026-10-06).** The
  house is visited between floors, which makes it the natural place to
  build the NEXT floor ahead -- a staircase costs about a fifth of a second
  on the desktop (floor 65-105 ms, the pre-run 55-150 ms;
  `tools/probes/prerun_cost_probe.gd`, corrected 2026-10-07: its first
  version timed new_game's own floor-1 build too and reported double), more
  in a browser -- so the cost
  hides behind something the player is enjoying (Brad's preload idea).
  That is only safe if nothing in the house touches `rng` or any run
  stream: then a floor built early is exactly the floor the stairs would
  have built, and every seed still reproduces. The house gets its own rng,
  or none.
- **Slices, each shippable:** (1) the visit -- stairs choice, the lot with
  the starter house, the portal, the house file, the kit and scrap wood so
  the first visit can gather; (2) building -- rubble, pillars, pools, mud,
  planks placed; the recipe screen; the wall editor and the portal rule;
  (3) the people -- retirees and gravestones from legends.json; (4) the
  Legends intro redone to show the real house. Every house screen measured
  in code and working on the pad from the start.
- **Open for Brad:** the lot's size in cells; the recipe costs; the
  portal's colour; what a retiree says. **Answered 2026-10-06: the visit is
  offered from FLOOR 2 ON** -- on floor 1 there is almost nothing to bring
  home, and a new player's first staircase should just go down.

**Then: a Dwarf Fortress direction — "which systems fit the game, and would be
fun?"** Brad, 2026-09-28. Both views only DRAW, so this is simulation work.
Start as a brainstorm, not a build. The seed of it is already here, under "The
directional one" below. One rule for everything in it: **every interaction
must leave a trace the player can SEE** — Dwarf Fortress is famously
unreadable, and our own playtest found mud's slowdown invisible until Brad
explained it. The shared effects layer means a new interaction announces an
event once and both views show it.

**The Dwarf Fortress plan (Brad and Claude, 2026-09-28).** One web, built a
strand at a time with play between:

    kill -> body -> scavenger spreads spores -> purple (miasma) / red (rises)
         -> fire burns both -> light -> monsters see more
    fleeing + chased -> pit -> next floor, wounded and vengeful
    the traveller turns all of it into gossip

1. **Bodies stay and rot. BUILT 2026-09-28**, waiting on play. The creature's
   own picture on its side (classic) or lying flat and turning with the
   camera (3D), darkening and fading over BODY_ROT = 120 turns, then gone.
   `GameState.bodies` keeps the whole creature for the later strands; one
   `BodyLook` colours it for both views; the shovel takes the body it raises.
2. **The fungus family. BUILT 2026-09-29**, waiting on play -- with the red
   CRAWL pulled forward from strand 4. As built: purple and red are TILES (not
   creatures: one creature per square is a hard rule, and "walk onto it and
   take damage" needs two). Standing on purple hurts 2, red 1. **Reworked the
   same night on Brad's call -- crossing is a CHOICE, never a wall:** walking
   in steps on (and hurts); **G burns** (B on a pad): the fungus AHEAD
   (facing) first, else underfoot, else the nearest beside -- a fire weapon in
   one press, a lit torch in three; the HERE box offers it. The pathfinder
   keeps two grids: CAREFUL (dragon, wizard, arch lich: bestiary "careful",
   and the player's auto-travel) routes round both colours; everyone else
   walks through and takes the damage (flyers do not), and red marks them
   (spore_marked, saved). A fire shot burns it from range. A rat, bat or rabbit
   beside a body seeds it; 15 turns later the body is purple or red (never
   green; none on floors 1-2). Red crawls one square per 3 turns toward the
   nearest body within 8 and CLAIMS it on arrival (strand 4 raises claimed
   bodies); burning a link cuts the chain. Nothing wrong grows within 2 of a
   lit brazier. Brad's table in MapGen.FUNGUS_TABLE. Shows on the minimap.
   Probe: tools/probes/screenshot_fungus.gd. **Later (Brad): the climb has its
   own, worse table (MapGen.FUNGUS_CLIMB_TABLE) and braziers protect only 1
   square. Fungus drawn in a VAULT (`*`) is guaranteed GREEN -- the vaults are
   the climb's reliable food. The vault editor should get symbols for purple
   and red eventually.** Brad's original additions
   (2026-09-28): **fire is the answer
   to the bad fungi** -- a flame weapon or fire gem burns a purple or red one
   away; the caves (4-6) trade a LITTLE green for seeded purple and red;
   monsters do NOT avoid red (walking over it tags them, and a tagged monster
   that dies rises); most avoid purple, but bats (they fly) and rats do not
   care -- rats may SEEK red and purple on purpose, the plague carriers; blood
   trails lead scavengers to bodies. One shared code path for both views.
   GREEN (as now: edible, light) grows only on its own.
   Bodies NEVER grow green -- Brad: eating a fungus that grew from a kill is
   not fun to think about -- they grow PURPLE (poison) or RED (blood), which a
   rat, bat or rabbit passing the body seeds; a few turns later the body is
   gone and the fungus stands there. New tiles APPENDED to Tiles (ints are
   saved). Rabbits eat fungus: purple sickens them, red may raise them.
   Brad's depth table: 1-2 green; 3 green and purple; 4-5 more purple than
   green; 6 red and purple, green rare; 7-9 more red than purple; 10 all
   three; the climb mirrors it. **OPEN: the caves (4-6) rely on green fungus
   as their deliberate potion replacement (CLAUDE.md) -- keep green steady
   there, or accept a harder cave on purpose.**
2b. **BUILT 2026-09-29, waiting on play:** Entity.spores (&"purple"/&"red",
   red wins; old saves' spore_marked -> red); corrupted creatures born purple;
   a purple-marked death is seeded as it falls, a red-marked one CLAIMED with
   red under it; awake marked walkers on plain floor leave their fungus 3% of
   turns (TRAIL_CHANCE; capped 60 per colour); rats not hunting you go to fresh
   unseeded bodies within 8 (stirring to SUSPICIOUS); sleepers hurt by fungus
   shuffle off it and sleep on. The tell: an outline in the spore colour -- 3D
   label outline, classic frame -- from CreatureMarks.spore_colour.
   **Spreading, and the visual tell (Brad, 2026-09-29).** Careless walkers
   carry spores onward. **Any creature that has touched the wrong fungus
   wears its colour** -- a tint or an outline on its picture/glyph, in both
   views -- so the player knows before the kill: RED means "kill this and it
   comes back"; PURPLE means its body will rot into purple fungus.
   **Lore (Brad, 2026-09-29): the climb's CORRUPTED creatures are ones that
   crossed purple fungus and were changed** -- their colour (Palette
   .CORRUPTED) is already that purple, by luck. So corrupted = purple carriers:
   when one dies its body rots straight into purple fungus, and the purple
   outline tell is free for them.
3. **The miasma, redesigned around purple:** ONE purple fungus is a source
   (no 2x2 group needed). **BUILT 2026-09-30 (Brad chose poison over
   time):** each purple breathes a cloud over itself and its 8 neighbours;
   breathing it poisons -- 1 hp a turn, lingering 3 turns after leaving
   (Entity.poisoned, saved). It is air: flyers breathe it. Sidebar status
   "poisoned · N" in purple; HERE says how long; one log line on and off.
4. **Red fungus raises the dead. BUILT 2026-09-30**, waiting on play. As
   built (Brad's calls): a claimed body always has red under it; it rises
   RISE_BASE 4 + its max hp turns after the claim (rat 8, kobold 10, troll 34,
   dragon 59) and never rots while it waits; "twitches" in the log 3 turns
   before; something standing on it holds it down. It gets up as "risen X",
   half hp, power x1.5, Faction.RISEN (appended) -- hostile to you, your allies
   AND the monsters -- held to its room (room_rects, then vault_rects; else 4
   squares round the spot), never opening the door. **BLIND -- it hunts by
   SOUND (Brad, 2026-09-30, the clickers):** any noise whose ring reaches its
   room (a door, a fight, bones) draws it to the spot, where it finds what is
   there; footsteps within RISEN_HEARING 3, or a touch, find you. A rat makes
   no footsteps -- nor does a ring-rat, until noise gives it away. A risen
   SKELETON keeps its eyes and sees through the ring. Real rats are never
   hunted and red never bites them (nor a ring-rat): they are its carriers.
   Its hits mark the victim red (the snowball).
   **A bone ally can catch the red (Brad, 2026-10-01: keep it, warn the
   player).** A risen's blows or red underfoot mark it; marked, if it falls it
   is claimed and rises against you ("risen Erdrick"). The log says so once
   when it is marked -- with "your shovel can bury them" or, without one,
   "fire can burn the body" -- and again when it falls (how many turns).
   The bone ally counts as a skeleton for rising. Shovel allies cannot rise
   (raised once). Found with it: every blow by anyone but you was logged
   "The X hits you", whoever it hit -- now named, and only when seen; heroes
   die by name, not "The Erdrick". Test: _test_a_bone_ally_can_carry_the_red.
   The gong frees it. Living creatures and skeletons rise; wights, shadows,
   liches, banshees and golems do not (red grows, nothing is claimed). Its
   second death is its last: no body claimed, nothing dropped (the first death
   dropped it all), no shovel. Burning the red it lies in burns the body.
   Test: _test_the_red_raises_the_dead. Original design notes follow.
   It is a timer: after some turns the body it
   grew from rises -- less HP, hits harder, hunts the player (Brad: a zombie
   piloted by a fungus, The Last of Us). Burn it before it hatches (strand 6).
   **Brad, 2026-09-29: confined to the room it rose in** -- a zombie room: it
   hunts whatever is inside and never follows you out; go back in prepared, or
   stay out. Caves have no rooms: a radius round where it rose. Proposals: the
   room is readable from its doorway (drifting red spores, a red tint at the
   door); it SNOWBALLS -- whatever the gong or a patrol leads in dies and rises
   too, until someone burns it; and HATCHING TIME SCALES WITH SIZE -- a rat in
   a few turns, a dragon's body much longer, a window to burn it (Brad's red
   fungus young dragon, on floor 10: a boss-sized problem you made yourself). Brad agreed
   the size scaling ("a dragon, you have time to hide") -- and it gives the
   STEALTH play a reason. **The one exception to the room: the gong shrine.**
   Ringing it frees the risen to answer the call, like everything else in
   earshot. Shrine colours are shuffled per run, so "which colour was the
   gong?" becomes knowledge that can save or end a run.
5. **Pits as escape. BUILT 2026-10-01**, waiting on play. As built: a fleeing
   creature counts the turns it runs in your SIGHT and your LIGHT
   (`Entity.chased`; the light at its cell above CHASE_LIGHT 0.25 -- measured
   above the doused torch's glow of 0.13-0.18 and inside a lit torch's reach,
   0.27 six cells out; dark or unseen resets it). At CHASED_TURNS 3 a pit
   beside it is an escape: "The cave bear leaps into the pit!" The fall costs
   it HALF OF WHAT IT HAS LEFT and never kills it (it was near death to be
   fleeing, and a fall that finished it would make the escape a lie) -- no
   roll, so seeds stay reproducible. It goes down vengeful: "vengeful cave
   bear", +REVENGE_POWER 1, threat x REVENGE_XP 1.5 (so more XP), on the
   `fallen` list saved with the run, and lands on the next floor at the open
   square farthest from you (chosen, not rolled), awake and hunting with your
   arrival square as its last sight of you. The trader's greeting on that
   floor adds "Something fell in from above..." (`something_fell`). Nothing
   that flies leaps. Original design: a fleeing monster lit by the player's
   torch several turns running is being chased; then a pit is an escape, not
   a no-go. Also cures fleeing monsters dying in room corners.
6. **Fire.** Flame weapons and the flare ignite fungus (a flare of light, the
   food lost), bones and wooden doors; the answer to red fungus.
6b. **Fire relights a cold brazier. BUILT 2026-09-30**, waiting on play.
   Brad's problem: two or three minutes in, most braziers have guttered, and
   gems want embers. G beside a guttered or black brazier: the fire weapon IN
   HAND gives up its fire (keeps its +, loses "(fire)", can take another
   stone) for BLADE_KINDLE 10; else a gem of fire from the pack is crushed in
   for GEM_KINDLE 15 -- enough to heal, forge, then work the embers, and a new
   reason for the trader's 3-for-1. G burns adjacent fungus FIRST, so a press
   meant for the red never spends fire. A tinderbox unique (two free relights
   a floor) was considered and dropped: it would cancel the brazier clock.
   The legend's black brazier now reads "cold, until fire".
6c. **Gems feed the uniques. BUILT 2026-10-01** (Claude's pick, with burying
   below), waiting on play. As built: at the embers a gem goes into the ring
   (RING_FEED +50, up to RING_FULL 220) or a dull shovel, through the same
   shortlist as gear ("set the gem into what?"); gear that can still take the
   stone is offered first. The ring at 0 goes COLD (unequipped, kept; a cold
   ring will not go on). The shovel goes DULL after a raise (Item.dull, saved;
   old shovels read sharp). Entity.raised marks the one second life (shovel
   and red; old red risen read raised); a raised creature drops nothing; a
   grave's bone ally is NOT raised and still hands its kit back. The shovel
   strips spores from what it raises. Clicking a gem outside its uses now
   says where gems go. Binding's "nothing will kindle it again" corrected.
   Test: _test_gems_feed_the_uniques. Design notes follow.
   Brad: the ring of the rat became the key to surviving the red, so it must
   be reusable; likewise the undertaker's shovel. **You and the red compete
   for the dead, and every body gets at most one second life.**
   - Ring of the rat: at 0 charges it goes COLD instead of crumbling (you
     still turn back mid-room -- the horror stays -- but keep the ring). At a
     brazier's EMBERS, G with the ring in hand feeds it a gem: +50 turns, capped
     at its full 220.
   - Undertaker's shovel: goes DULL after a raise instead of vanishing; one
     gem at the embers gives one more raise (holds one at most).
   - Gaps found while designing, to fix with it: (1) a shovel ally can rise
     again as a red risen -- nothing marks it; one shared "has risen once"
     flag, set by the shovel and the red, checked by `_can_rise`. (2) A
     reusable shovel duplicates gear: the first death drops loot, the ally
     wears a copy, and an ally's death hands back ALL of it -- a raised
     creature must drop nothing, as the red risen already do (grave heroes keep
     their bone rule). (3) The shovel can already snatch a red-claimed body
     inside its 5-turn window (a red body rises in 8+); it should strip the
     spores, or the rescued ally wears the red outline and trails red.
   - **BURYING -- BUILT 2026-10-01**, as below: G, BURY_SPADEFULS 3, each
     DIG_NOISE 6 at your feet; a dull shovel digs. G's order: a fire blade
     burns first, then the shovel buries, then the torch scorches. The crawl
     keeps `red_from` (square -> where it grew from, saved); a lost body
     withers its chain a square a crawl tick (`withering`, saved), tip first,
     stopping at a branch, at a body in reach, or at the source. The shovel's
     raise and the gem of thirst also make the red lose a body. Test:
     _test_burying_and_the_red_withering.
   - **THE UNDERTAKER'S PAY -- Gabe's idea, BUILT 2026-10-01.** The gem's
     other road: every grave dug for the red's dead counts on the shovel
     (Item.laid_to_rest, saved) -- a claimed body, OR the body of a risen
     that fell (the shovel now buries those too; plain bodies it does not).
     BURIALS_TO_SHARPEN 5 sharpen a dull shovel; on a sharp one the count
     holds at 5 and keeps its edge through the next raise -- one raise banked
     at most, as with the gem. The log counts "(3 of 5 laid to rest)"; the
     pack's hint names both roads. Test: _test_the_undertakers_pay.
   - **BURYING (Brad, 2026-10-01): the shovel's second use.** Standing on or
     beside a body the red has CLAIMED but not yet raised, dig it under: it
     never rises. Separate from RAISING (a fresh kill, 5-turn window, an
     ally, costs a gem in 6c). Claude's suggestion: digging takes a few turns
     and is LOUD -- the blind risen hear it -- so burying near a red room is a
     race, and costs time and noise rather than a gem. OPEN: a fresh red kill
     is both raisable and buriable -- the HERE box offers both.
     **The red's response:** if another body is within reach it turns to it
     (the crawl's nearest-body rule already does this). If not, it WITHERS:
     each crawl tick the chain's tip dies back one square toward its source.
     Needs each crawl-grown red square to remember the square it grew from
     (saved), so the withering retraces the real chain; seeded or generated
     red is a source and never withers.
   - Gems then have three sinks: weapons, the ring, the shovel. Brad says gems
     are plentiful (he traded 3-for-1 twice); if the uniques sit idle in play,
     tune gem supply, not the cost.
6d. **Gems in the world. DESIGNED 2026-09-30; build ALL of them, after 6c**
   (Brad: "they are all good ideas"). One rule, set by the fire gem's relight:
   **crush a gem into the world with G where you stand (or throw it), and the
   HERE box says what it will do** -- so every gem is a choice between your
   gear and the floor, and the trader's 3-for-1 gains a purpose. Suggested
   build order, the first three first (each leans only on systems that exist):
   1. **Gem of the boss -> a decoy crash. BUILT 2026-10-01:** the one gem
      that can be thrown (throw 8; the throw key's list; the aim cursor on any
      square in reach, no target needed). It shatters at BOSS_CRASH 10 -- above
      a wail -- so sleepers wake toward it, the blind risen hear it, AND
      hunters that have lost sight of you take the crash as their last sight
      of you (_make_noise alone only turns the unaware). Loud enough to rouse
      a grave, as every loud thing is. Gone when thrown. Test:
      _test_gems_in_the_world. Thrown, it shatters LOUD where it
      lands. The blind risen hunt by sound, so it empties a red room's far
      wall while you take the near one; it also pulls a guard off its round.
   2. **Gem of thirst -> drink the dead. BUILT 2026-10-01:** a plain click on
      the gem (it needs no fire) with a body underfoot or beside you; the
      richest body, half its max hp (THIRST_SHARE); refused at full health
      unless the body is red-claimed. The pack's hint says "drink the X (+N)".
      Test: _test_the_gem_of_thirst. Crushed on a fresh body: you drain
      it for hp and the body is gone -- a THIRD claimant for the dead beside
      the red and the shovel. Denies the red a body when you have no fire.
   3. **Gem of the mirror -> a shrine's true name. BUILT 2026-10-01:** a
      plain click on the gem while STANDING on an unfamiliar shrine names it
      (shrine_known[kind], so every shrine of that colour this run); the
      shrine stays, unprayed. Refused and kept off a shrine or on a known
      one; the pack's hint says "name the shrine". Test:
      _test_gems_in_the_world. Crushed at an unknown
      shrine, it names it. Shrine colours are shuffled per run, so it answers
      "which colour was the gong?" -- the one that frees the risen.
   4. **Gem of frost -> THE FROZEN ROOM (Brad's design). BUILT 2026-10-01**
      with his rule (a): thrown (throw 8, like the boss), it freezes everything
      standing in the room, vault or cave it lands in (a 5x5 patch of
      corridor otherwise) for the region's longer side less one per door in
      its wall ring, FREEZE_MIN 3 .. FREEZE_MAX 12 (caves are huge). Frozen
      is on the creature (`Entity.frozen`, saved): it stands there, its turn
      spent, hears nothing and keeps nothing it did not hear; the mark over
      its head is the count. The ROOM is silent (`frozen_rooms`, saved):
      `_make_noise` inside it carries nowhere. You are never frozen by your
      own stone; an ally standing there is. From the pack it only says it is
      thrown. Not yet: a cold look on the floor itself (both renderers),
      and rule (b) -- a door shut behind you ending it. Original design:
      thrown into a room
      or cave, it freezes everything in it for a number of turns, and SOUND IS
      MUFFLED there meanwhile -- so a player may cross a small room past its
      risen. Always a close call: a 10x10 room gives about 8 turns. **OPEN --
      Brad gave two duration rules, choose at build time:** (a) the room's
      longer side, minus 1 per door; or (b) plus 1 per door, where closing a
      door behind you ends it -- "if the math is right, a near miss". Needs:
      thrown gems (gems do not throw today), a region for caves (rooms have
      `room_rects`; caves need theirs kept -- the risen leash falls back to a
      radius), what "muffled" does to `_make_noise` inside it, and frozen
      creatures neither act nor hear. (Also, from the earlier brainstorm:
      crushed at WATER it could freeze a crossing -- a second, smaller use.)
      **Brad's second version, same day -- THE WET FREEZE:** thrown, it
      freezes every creature (monster or animal) standing in water or WET --
      in water within the last ~3 turns. Frozen: it does not move, it can be
      hit without hitting back, and it does not stay frozen long -- so the
      choice is free blows or a head start. A frozen creature does NOT react
      to any noise made while it was frozen (it is not left holding a `heard`
      spot or woken when it thaws). Needs a "wet until" turn on Entity
      (saved), and builds naturally on the existing `Entity.chilled` from
      frost weapons. **OPEN -- choose at build time: the wet freeze INSTEAD of
      the frozen room, or both** (e.g. the room freeze for everything, water
      making it last longer or hit harder).
   5. **Gem of the crag -> fill a pit. BUILT 2026-10-01.** Crushed over a pit
      beside you (the one you face first): stone pours in and sets, the hole
      is floor and the pathfinder routes through it. The pack offers "fill
      the pit" when one is there. Closes a fleeing monster's escape once
      strand 5 teaches them to use one.
   6. **Gem of returning -> recall. BUILT 2026-10-01.** Crushed beside any
      brazier (lit, spent or cold -- a fire is a landmark) it marks it
      (`recall_mark`, saved, this floor only); a second crushed anywhere
      steps you to the nearest free square beside the mark and spends it.
      Refused beside the mark ("you are at the fire already") and with no
      fire and no mark. The pack says "mark this brazier" / "return to the
      fire". Not yet: the marked brazier drawn as marked on the map.
   7. **Gem of the bulwark -> a barricaded door. BUILT 2026-10-01.** Crushed
      against a door beside you (open or shut, nothing standing in it): a new
      tile, `DOOR_BARRED`, appended to the enum, drawn as the door in stone's
      colour (a stone beam across the leaf in 3D), a landmark the memory keeps,
      in the legend ("holds all but a bear"). "For a while" is measured in
      HEAVES, not turns: anything that OPENS doors spends its turn heaving,
      loudly (DOOR_NOISE), and the bar loses one of `BAR_HOLDS` (10) -- so a
      pack breaks in faster than a straggler and you hear how long you have.
      A bear takes it off its hinges as it does any door; rats go under it;
      you walk into it to lift the bar (spent). Saved with the embers.
   **The HERE box says when a carried gem would work where you stand (Brad,
   2026-10-01, after playing the crag and the bulwark from the pack):** one
   row by the pack key -- "crag: fill the pit", "bulwark: bar the door",
   "returning: mark the fire" / "back to the fire", "mirror: name the
   shrine", "thirst: drink <body> (+n)" -- in the pack hint's own words, one
   gem row at most, and only while the box has room (it holds four rows with
   "every key"; warm + relight + a gem is the fullest it gets). The gems
   thrown or used anywhere (boss, frost, road) are not "here" and stay in
   the pack's hints. `gem_use_here`, measured in the HERE width test over
   every bestiary body.
   8. **Gem of the road -> the way out. BUILT 2026-10-01.** Crushed anywhere:
      the route from you to the stairs (`road_route`, the plain grid, cached
      per turn) is drawn on the minimap and THE FLOOR SO FAR as a dotted line
      in the stairs' colour, with the stairs at its end seen or not (the
      stairs cell is marked explored, so the main map remembers them too).
      For the rest of the floor (`road_shown`, saved); a second is refused.
      Not yet: the line on the main map itself.
Further strands from the same brainstorm, all welcome (Brad: "all of your
ideas are really good"): blood trails that scavengers follow; watchable
hunting; frost freezing water to ice; rubble cracked by force (gems); alarm-
raising kobolds; sleepers drawn to lit braziers; monsters wielding what they
find; trader gossip; a nemesis from the morgue. Every one must leave a trace
the player can SEE.

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

**First, 2026-09-29 -- both moved to SMALL_TASKS.md:** (a) the inventory's labels -- "food & potions" for the
potions tab (haunches were filed under potions), and a "uniques" heading and
tab (the ring of the rat was filed under weapons; the shovel, the Horn later);
(b) **Gabe: a screenshot key -- moved to SMALL_TASKS.md.** F9 (F12 opens browser dev tools, and Steam
takes it for its own); desktop saves a PNG beside the saves and says where --
a static path that use_scratch_files() moves, from its first commit;
itch downloads it through Platform.hand_over, like the morgue; the pad watch
and other overlays left out of the picture.

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

**5b. The camera that follows you (Gabe's request, 2026-09-28). BUILT the
same evening**, waiting on play -- the title's settings, "3D camera". Brad: "works
amazingly great". **Open: make it the default?** Waiting on Gabe, David and
especially Steph (motion sickness) -- ask her to try it with effects on (the
camera swings) and off (it snaps). Also a Firefox answer: in follow mode the
LEFT stick turns you, and the left stick works in Firefox. **Steph (2026-09-28):
no motion sickness from the game even on effects "full".** Still to ask: was
that WITH the follow camera, which swings on every turn? **Yes -- swinging
and snapping, no discomfort. DECIDED: new players start in 3D with the follow
camera (defaults changed 2026-09-28); saved choices are kept.** A settings
option, "camera: fixed / follows you", off by default. In follow mode the
controls become Wizardry's, in our overhead 3D: up = step forward, down = step
back, left/right = turn 45 degrees in place (free, no game turn), diagonals =
step forward-left/right; the camera swings to stay behind the player, so
forward is always up. Snaps instead of swinging when effects are off. **Click-
travel and auto-travel do NOT swing at each corner -- the camera turns once, at
the end** (Brad: swinging every turn was nauseating in another game). The
player gains a FACING, which the combat update's flanking needs anyway.

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

## Short sessions -- the Legion's nights (set 2026-10-07)

While Brad is on the pet-sitting job (to about late October), the Legion
session gets the evenings between the pets' medicines: about an hour or two
of work a night. These are sized for that, ONE A NIGHT, in this order unless
Brad says otherwise. Big themes (the house, gems on any host, the spider,
the bestiary page) wait for Brad and the desktop.

**How a night goes:** pull first (the desktop pushes in the mornings and at
night); message the desktop session when the Legion boots; read the item's
full entry further down this file before starting; single tests while
working, the full suite at the end; commit and push with no attribution
line; mark the item done HERE with the commit and the tally, and as-built
in its own entry.

1. **The latched gate** (Ideas, 2026-10-07): a door no animal passes, its
   own colour, opened by hands, smashed by a bear; a wall to monster
   pathfinding, a door to yours; "a latched gate" under the cursor and in
   the HERE box; a vault letter for it. Then put one on the warren
   (`assets/vaults/the_warren.txt`) and re-run `tools/probes/warren_probe.gd`:
   the rabbits should stay home.
2. **The riders** (Trained animals): the kobold wolf rider and the goblin
   bear rider -- the animal's glyph and stats in the MONSTER's colour,
   MONSTER faction, attacking on sight; fortress floors. Two bestiary rows
   and the colour; the art reference regenerated.
3. **The houndmaster** (Trained animals): an orc or an ogre (Brad's pick)
   with two or three hounds of the wolf's kind in the master's colour,
   MONSTER, via `_spawn_pack`; a kennel vault with a latched gate (item 1).
4. **The master falls, the hounds go wild** -- ASK BRAD FIRST (the desktop's
   suggestion, not yet his yes): on the master's death the survivors turn
   WILD, the provocation loop run backwards (`_turn_to_you` is the model).
5. **Fire as a fear** (the wild creatures update): a lit torch keeps an
   unstruck animal back; read the entry for the wolves' "cornered by flame"
   rule and the bear's exception before starting.
6. **The rat goes WILD** (the wild creatures update): with the threat
   ceiling re-measured before and after (`tools/probes/threat_wild_probe.gd`)
   -- the slime now fills floors 1-2, which was the condition.
7. **Throwing a fungus roots it where it lands** (the satchel's entry):
   throwing exists; the rooting is `player_drop_from_satchel`'s rule
   (open floor only), applied at the landing cell.
8. **The marked brazier drawn as marked** (the gem of returning): both
   views; nothing changes in the sim.
9. **The rabbit's mushroom search from a list** (desktop profile,
   2026-10-07): a rabbit's turn checks 841 cells for a mushroom; keep the
   floor's mushroom cells in a list kept current wherever a FUNGUS tile is
   set or cleared, and search that, with exactly the same choices (row
   order, nearest, not one somebody stands on). A test comparing the old
   search with the new on random floors and positions.
10. **Rename `Entity.charges` -> `dash`** (Ideas): a bull-rush flag that
   reads as brazier charges. Grep every use first, saved games included
   (read the old key as well as the new).

**Waiting on Brad, not code:** the trader's numbers (from play); the right
stick in Firefox on itch (a test); David's music in the web build (a
listen); the frozen room's rule (b); the spider's bite and provocation;
which heart glyph over a tamed wolf.

**For the desktop at night:** reviewing what the Legion pushed; the open
question in CLAUDE.md (descent caves place vaults above p=0.25 and the
climb's below -- instrument `wanted` against what is placed); the house's
first slice written as a full design.

## For the free model

Small, self-contained jobs for the free model live in **`SMALL_TASKS.md`**,
with the rules it works by (tests, both views, "still", no commits). Brad
points it at that file; Claude reviews its commits.

**The fair dark (Brad, 2026-09-29 -- at 2 hp from a young dragon firing out
of the climb's dark). BUILT, waiting on play.** Shooters may stand
DARK_SHOT_GRACE (2) past the edge of your light only with a full torch (or a
burning flare); where the torch is cut down -- caves, the dark climb, doused --
the margin is 0: they must be at the very edge of your light. Magic and fire
shooters (dragon, wizard, arch lich: bestiary "casts") LIGHT their own square
when they fire, this turn and next, so you see what fired and where. The
climb's caves remember the map faintly (0.15) instead of not at all -- one
rule now, MapMemory.strength_for, for both views.

## Known gaps

**One leaked object at every quit since the music (harmless).** Godot reports
an `AudioStreamGeneratorPlayback` leaked at exit whenever the generated music
is playing when the program ends -- with the real audio driver, the dummy one,
headless or windowed, and even after stopping the player in `_exit_tree`.
Engine-side; the process is ending anyway. The quick suite now prints this one
warning after its tally; it is not a failure.

**Test litter in the player's save folder -- FIXED.** The full suite's three
loops (`bearfit`, `pity`, `reach`) clear their scratch tags now. Found still
littering on 2026-10-07 and fixed the same morning (desktop): the QUICK suite
left `scratch_view_tests_settings.cfg` and `_bestiary.txt` on every run, and
19 of the 41 probes that call `use_scratch_files` never cleared theirs. The
quick suite now clears at its end and checks that nothing of its own is left
(a mutation without the clear fails it); every probe calls
`GameState.clear_scratch_files()` before `quit()` (the screenshot probes write
to `SHOT_OUT`, outside the folder, so nothing they make is lost). **For any
new probe: clear before quit.** A probe killed by a timeout never reaches
its clear, so an interrupted run can still leave one file; it is a
`scratch_` file, safe to delete.

**The mirror tell -- BUILT 2026-10-04 (Legion), waiting on play.** What was
built, from the shape below: `CreatureMarks.outline` is the one answer both
views and the sidebar's ring ask -- the spores first (red outranks a shield),
else the mirror, else nothing. Still: a steady frame in `Palette.MAGIC`.
Simple and full: that blue brightening to a pale glint and back, two seconds
a lap, anchored on MAGIC so it reads as that colour shining (Brad: close
enough to be associated with it; the stops are tunable in `CreatureMarks`).
A red risen that kept its shield shows BOTH: the classic view draws the
mirror as a second frame inside the red; the 3D card has one outline, so on
simple and full the two take turns (`single_outline`, 0.9 s each) and on
still the red wins there -- the sidebar ring and the classic view still show
the mirror. A mirror shield LYING on the floor shines the same way in both
views (Brad: the identifier comes before the pickup); on still it is the
plain magic blue every enchanted item wears, and the HERE box names it. The
grid redraws at full rate only while one is in sight (`_has_visible_mirror`,
as for the miasma). Legend: "blue ring -- its shield throws your blows back".
Proof: `tools/probes/screenshot_mirror.gd` renders both views on still and a
strip of frames on full (both looked at on 2026-10-04); tests in
`run_view_tests.gd` (`_test_the_mirror_tell`, and the 3D block in
`_test_both_views_share_one_moment`). Not done: a mirror shield WORN by the
player has no mark, since the sidebar's offhand line already names it.

**The original note, kept for the reasoning.** A monster's mirror shield gave
no warning before it bit (day-7 hunt, 2026-10-04). `_arm_monster` arms weapon and
armour only, but a scavenger takes a SHIELD off the floor (`_better_item_at`
has an offhand branch, `_scavenge` equips into the item's own slot), and a
floor shield can carry `reflect`. Your first sign is your own blow coming back
("The kobold's shield throws it back for N"). Brad's design from 2026-09-21: a
creature wearing reflect gets an animated colour fade on its glyph.

**Brad's shape for it (2026-10-04):** reuse the spore OUTLINE the red and
purple carriers already wear in both views (`CreatureMarks.spore_colour` ->
the thicker outline in `GlyphGrid` and on the 3D card in `DioramaView`) for
anything wearing a reflect shield. On Effects "still", a steady outline in the
colour the player already reads as "a stone" (`Palette.GEM` or
`Palette.MAGIC`); on simple and full, the same outline fading cyan -> blue ->
light blue and round. Colours rough, not fixed. One mechanism, both
renderers, no new system -- and the still form is the motion-sensitive
tester's fallback by construction. Mind the risen: they keep their shields
when they rise.

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

**Taming the wolves -- BUILT 2026-10-06 (Legion), waiting on play.** As
built, from the design below: the wolf row carries `"tame": true`; with the
price in your pack -- haunches to the pack's count (`_tame_price` =
`_pack_size`: two on the upper floors, four in the caves; ANY haunch counts,
bear and wolf included -- Brad's open question, answered yes), or a
knucklebone -- the first move into an unstruck wolf OFFERS instead of
warning ("Move into it again to throw down 4 haunches and tame the pack;
shoot to fight it."), and the same move again pays and turns every wolf of
its kind within `PACK_REACH` to your side (`_tame`, `_turn_to_you`: the
provocation loop run the other way). Haunches first when you have enough,
from the satchel's shelves then the pack (`_spend_haunches`); the bone only
when you do not, since it raises a hero's shade. Without the price the
warning names it. A HEART floats over each wolf that turns (the `tamed`
event, the LEVEL UP popup's shape; `GlyphTheme.TAMED` = md-heart, added to
the icon subset -- Brad may swap the glyph; `Palette.TAMED`). A tamed pack
hunts for you within your reach (`_ally_hunts`: a rabbit's worth, never a
bear) and leaves the haunch for you unless HURT -- then it eats and heals
what the meat would have healed you: the first ally that heals, paid for
from your larder; the ally's walk now steps ONTO meat (`_safe_step_toward`
`onto`). Tamed wolves are allies in every other way: green, listed as
standing with you, following you down, washing in pools, backing out of
the purple, and chaff by the fortress -- the decay. Not built: a tamed
wolf's warning colour (it takes the ally's). Test:
`_test_taming_the_wolves`. The design, kept:

**Taming the wolves (Brad, 2026-10-05 -- designed, not built; about half a
day).** A pack on your side, instead of a bone ally or the risen. Brad can
see players choosing it as their way to play (see "jobs without names",
below).
- **Two prices, one choice.** The offer rides on the bump warning: with a
  knucklebone, or haunches to the pack's count (two on the upper floors,
  four in the caves), the first move into an unprovoked wolf OFFERS instead
  of warning -- "You hold out the knucklebone. The wolf takes it, and the
  pack comes with it." / "You throw down the haunches. The pack eats, and
  is yours." The warning text names what it would take. The bone is rare
  and has another use (a skeleton with a grave's kit, most likely armed),
  the haunches are the caves' sustain: either reads as a real price.
- **The pack turns as one, the other way.** Every wolf within PACK_REACH
  goes to PLAYER -- the provocation loop run backwards, the loop the
  houndmaster's death would also use. Allies follow you down the stairs.
- **Feeding heals -- the first ally that heals, and it is paid for.** The
  no-heal rule on allies is load-bearing (it is why they may follow you
  without becoming a permanent party); this exception keeps it honest
  because the healing is bought with your own food. The rule: a HURT wolf
  of yours eats meat lying about and heals what that meat would have
  healed you (`_eat_here` already does exactly this for hunters); a well
  wolf leaves it, so the pack does not steal your haunches. Nothing else
  heals it; the bone ally stays as it is. Needs a test that WATCHES a fed
  ally, not a look at the code.
- **The payoff: the pack hunts for you.** Wolves hunt rabbits today and
  eat the kill. Yours hunt and leave the haunch unless hurt -- a floor's
  rabbits become a delivery.
- **Wolves drop meat -- BUILT 2026-10-05 (Legion):** a "haunch of wolf"
  (`wolf_meat`, its own entry like the bear's so it never merges with a
  rabbit's), worth a rabbit's base plus depth, no `meal` term; eaten by the
  hunters and the slime like any haunch (`_is_meat`, the one question the
  three id lists became). The wolves you fight feed you; the wolves you
  feed will fight for you. **WATCH THIS ONE (Brad, the same night):** most
  of the testers are Minecraft players, who tame the first wolf they see;
  a haunch of wolf may draw hard pushback. If it does, remove it: the
  wolf's name in `_drop_loot`'s meat test and the `wolf_meat` entry, two
  lines, nothing else knows. No substitute drop then -- a pelt would need
  a use, and the trader buying it is the money loop we declined. The
  taming is the real payoff and survives the haunch going.
- **Decay.** By the fortress a 9 hp wolf is chaff against what lives there,
  so a fed pack decays by being outclassed rather than by a clock. Play
  will say whether that is enough.
- **Open:** does bear meat count toward the haunch price; whether a tamed
  wolf keeps its warning glyph colour or takes the ally's.
- **The tell, when the pack turns (Brad, 2026-10-05 night):** reuse the
  "LEVEL UP" popup (`Fx` `levelup`) -- a red heart floating over each wolf
  that turned, for a few seconds. WHICH heart is Brad's pick when it is
  built: the full font has plenty (`md-heart` U+F02D1, `md-heart_outline`
  U+F02D5, `oct-heart`, more), and any one is a codepoint in the theme and
  a rebuild of the subset. One effect, reusable: Brad foresees testers asking to tame other
  things -- a slime, a bat for a flyer, a cat once there is one -- a "pet"
  system the wolf begins. Not a 151-creature roster; but the heart and the
  turning-as-one loop should be built so a second tameable costs a row.

**Jobs without names (Brad, 2026-10-05 -- a design note, not work).** We
decided against D&D classes, and the game has grown class-LIKE play
anyway, chosen by what you pick up and switchable at any time, like Final
Fantasy Tactics' jobs: a player running wolves is a druid or a ranger (by
weapon); a bone ally a necromancer or a grave cleric; the risen a
necromancer outright; the rat ring a rogue; scrolls a wizard (and WE NEED
MORE SCROLLS -- an idea to grow); none of these, a warrior. The lesson for
new systems: give each "job" its own tools and its own costs, never a
label, and let the player drift between them. The Legends page could one
day NAME a finished run's job from what it used, after the fact, the way
the morgue names a cause of death -- a title earned, never picked.

**The forager's satchel -- BUILT 2026-10-01**, waiting on play. As built: a
unique (`satchel`, min depth 3, through the chest pipe after the ring and the
shovel -- uniques are never on a shelf; a trader price can follow if wanted),
**and guaranteed by the caves (Brad, 2026-10-01: that is what it is FOR --
fungus to pick, haunches to keep; found after the caves it is much less):** a
run reaching the first cave floor (4) without one finds it lying in the far
room, never twice, never on the climb (`_place_the_satchel`, beside the gem
pity). Worn in the OFFHAND, holding ten. Worn, food and potions you pick up go
straight in ("You put the haunch in the satchel (3/10)"), and G on fungus
PICKS it into a stack of up to ten instead of eating it (the HERE box says
"pick the fungus"); the tile goes bare and dark as when eaten. `s` on a
keyboard and d-pad down on a pad open its chooser -- the pack panel in
`satchel_mode`, lettered a.. by position, titled THE SATCHEL -- and a use is
the item's own effect for a turn, after which the chooser CLOSES so the map
shows the heal; a refusal keeps it open. Right-click or the pad's drop sets a
thing down: fungus TAKES ROOT where you stand (open floor only) and glows
again; anything else drops. In the pack, unworn, it opens and works the same.
Full, the pack takes over as before. The pack's pane, on the satchel, names
the key or the pad's button to open it and lists what it holds (Brad, from
play: worn, nothing reminded him). It hangs on a strap and takes NO HAND
(Brad, from play: wearing it put his bow on his back): a bow or a sling and
the satchel are carried together; a shield and a bow still are not. The pad's d-pad down was `>` (G already
goes down the stairs you stand on, so the button was spent twice); inside the
pack d-pad down still drops, and the legend names the pick-up button for the
stairs on a pad. Saved inside the item (`contents`, `count`). NOT built:
the cosmetic glow at your side, and throwing a fungus to root it far off
(no fungus ever sits in the pack; it lives in the satchel). Original design:
absorbs the
old "fungus bag" idea. One pack slot that holds up to 10: nine meat or potions,
and ONE stack of fungus (fungus stacks to 10; so fungus can be PICKED as well
as eaten where it grows). Why: pack heals were invisible (the pack stays open
over the map), the pack was full (Brad's 20/20 held five heals), and a quick
heal mid-fight.
- **Using anything from it costs a turn, and the chooser closes behind it**,
  so the map shows the heal.
- **Worn in the offhand** (a real trade against a shield -- the bulwark
  makes that hurt): a key/button opens the chooser directly; food and potions
  picked up go straight in until it is full; and **the fungus inside still
  glows** -- a small light at your side -- which may draw rabbits (bait).
- **The glow is COSMETIC only** (drawn on simple/full effects, not on still),
  never a light in the rules: monsters notice you by light, and a real glow
  would quietly break stealth -- Brad's kobold walked past him in the dark
  with his torch out (PLAYTESTS 2026-09-28).
- **Dropping a fungus keeps the fungus bag's purpose: it TAKES ROOT** -- an
  ordinary FUNGUS tile, so it is light (fungus already lights), bait (rabbits
  already seek it) and food, with no new rules. A turn, and only on open floor
  (not water or a pit). **Throwing one** (throwing exists) roots it where it
  lands: light a far corner, or lure a rabbit away from your route.
- **In the pack, not worn: still usable** -- open the pack, open the satchel,
  use (a turn, then it closes). Brad: his players are D&D players and will
  look for exactly this bypass; allowing it at the same cost is the right
  call. Worn only adds convenience and the glow.
- The chooser: a small panel like the inventory -- letters for keys, up/down
  and A on a pad, click with a mouse.
- **Open:** the key -- `b` is taken (vi down-left) and all four d-pad
  directions are bound; free **d-pad up** by moving the 3D/classic toggle to
  the pause menu (rarely used now 3D is the default). Where it is found
  (trader? caves, where food matters most?).

**Traps, second pass (Brad and Claude, 2026-10-02) -- BUILT the same
evening**, waiting on play. As built: counts by band in
`MapGen._scatter_features` (upper 0-2, caves 0, fortress 2-5, deep 3-5;
half of the fortress's and the deep's on a threshold, `_threshold_cells`:
the corridor square outside a door); `Pathfinder` holds four grids by two
flags (careful, traps) and only the player's travel, the road's line and
allies avoid FOUND traps -- monsters and the risen route and side-step over
them (`_owns_the_floor`); allies spring hidden traps under them and found
ones they are shoved onto (`_spring_under_allies`, after `_run_world`);
a found trap is stepped over at `TRAP_STEP_OVER` 2x cost, unhurt, still
armed, and a stale walk stops at one; G disarms (`player_disarm`,
`DISARM_BARE` 0.5 / `DISARM_GLASS` 0.9 on `trap_rng`; fumbled, it springs
for half). The HERE box offers "disarm the trap (50%)". NOTE the risen:
written below as springing traps; built as the floor's own dead, who know
it -- only the PLAYER faction springs them. Tests:
`_test_disarming_and_the_floors_own`, `_test_traps_by_band`. Original
design:
From play: Brad never saw a trap and never sprang one. Measured: every floor
lays 0-3 (`mapgen.gd` ~900), in every band, caves included, and only on a
cell open on all eight sides -- the middle of a room, never a corridor or a
doorway -- so a player walking routes rarely crosses one. Three rules, built
together after the counts:
1. **Counts by band, and where.** Upper 0-2; caves NONE (a mechanism in a
   cavern reads wrong, the same reason caves want few vaults -- a rule the
   player can hold); fortress 2-5 with about half in DOORWAYS; floor 10 3-5.
   Hidden traps already route as floor, so a doorway trap no longer severs
   the level the way a visible one did (the 200-seed connectivity test).
   Numbers are Brad's to settle.
2. **It is their floor, all the way.** Monsters already never spring a
   trap; now the pathfinder stops treating a FOUND trap as solid for them,
   or a spotted doorway trap shuts every guard in its room (today a found
   trap is a wall to monsters). Allies and risen are not the floor's own:
   they spring traps as the player does -- the one use a found trap has
   against the world, and a reason to disarm.
3. **The player at a found trap.** Both halves of the 5e feel: (a) STEP
   OVER -- crossing a found trap on purpose is a slow step (double cost),
   no damage, the trap stays armed; (b) DISARM -- G on it, through the
   HERE box's context actions (no new key), a turn; success removes it,
   failure springs it for half damage. The chance is the glass's second
   job: about 50% bare, 90% with the trapwright's glass in the offhand.
Not yet: luring monsters into traps -- it contradicts "their floor" and
makes every found doorway a free kill. **Brad's shape for it, eventual:**
a DISARMED trap is kept as an item and LAID again by the player; then the
roles reverse -- the player knows where it is, the monsters do not, and a
monster steps on it. One rule for both sides: a trap is hidden from
whoever did not lay it. **Parked (Brad, 2026-10-02): not acted on yet.**
The blocker is the inventory: a carried trap is a new item, one more of the
24 letters a keyboard player has and one more pack slot, and the pack is
already the tight resource (his 20/20 held five heals before the satchel).
Circle back when either the letter pool or the pack changes shape -- the
satchel's "a bag that takes no letter" is one model. What it would need
when it does: a `trap` tool item; G on open floor lays it (a turn) into a
second set beside the floor's own, shown to you, hidden from monsters;
monsters spring player-laid traps and never the floor's, your side the
reverse; the same spring and noise of 5, so a laid trap at a doorway is a
lure as much as a wound. About an evening, most of it item plumbing and
the save.

**The pack, in three steps (Brad and Claude, 2026-10-02 night). Step 1
BUILT; steps 2 and 3 are tomorrow's work.** Every feature lately has
wanted an item or more of one, and the pack was the tightest resource in
the game (Brad's 20/20 held five heals; that is what made the satchel).
Brad's picture: a pack of twenty SLOTS, each slot a STACK, worn gear in
its own header and out of the count; the satchel a shelf per kind. Not
Ctrl+letter: a pad has no Ctrl, the browser takes Ctrl+W and Ctrl+R before
the game sees them, and letters are chosen inside the open panel anyway.
1. **Worn gear is not in the pack -- BUILT 2026-10-02**, waiting on play.
   `Entity.pack_count()` (carried and not worn) is what INVENTORY_MAX
   measures: `give_item`, the pickup and the HERE box's "full". Worn gear
   stays in `inventory` with its letter, so every index, the swap key, the
   trader, the gem binding and the save are untouched; the EQUIPPED header
   the panel already drew is now the "worn" row Brad imagined. The title
   line reads "N / 20 in the pack · M worn". Taking something OFF with a
   full pack is refused ("Drop something first"); putting something else
   on in its place is a swap and needs no room. The letter pool (23) covers
   20 + the 3 worn slots exactly (`Entity.WORN_SLOTS`, checked by
   `_test_inventory_letters_dodge_the_keys`). Test:
   `_test_worn_gear_is_not_in_the_pack`.
2. **Stacks in the pack -- BUILT 2026-10-03**, waiting on play. As built:
   `Item.stackable()` (potions, scrolls, gems; never gear, uniques, the
   satchel, a hero's bones or the quiver's arrows), `stacks_with` (same id,
   element, boosts, charges; up to `Item.PACK_STACK` 20), `absorb` (meat's
   worth averaged in, rounded), `split_one`. `give_item` merges before it
   counts, so a full pack still takes one more of what it holds. One leaves
   at a time through `_spend_one`: use (the slot and letter stay while any
   remain, so "drink, drink" works), drop ("You drop one X (x3 left)"),
   throw (the boss and frost gems too), the trader's counter, a gem bound
   or crushed into a brazier. The forge works a stack against itself:
   two leave, one comes back +1 and takes the stack's place in the list
   (`_find_duplicate` returns the stack; refused when three or more would
   remain and no slot is free for the worked one). Pickup says "(b, x3
   now)". Not built: dropping a whole stack at once (one per press for
   now); the satchel still hands food over by slot (step 3). Test:
   `_test_stacks_in_the_pack`. **Gear too, the same day (Brad, from play:
   four daggers in four slots, one of them magic):** PLAIN gear stacks --
   same thing, no element set or found in it (`element == ""`, which is
   what colours it and brackets its name), the same forge level, not worn.
   A dagger +1 stacks only with a dagger +1; anything with an element, the
   ring, a launcher (it carries a quiver) and every unique sit alone. The
   one you WEAR is always a single item: wielding from a stack splits one
   off into its own slot right after the stack (`_toggle_equip`), the swap
   key goes through the same door, and a plain dagger picked up never
   joins the one in hand (`_stack_for` skips worn). Wielding off a stack
   into a FULL pack is refused like taking something off (the stack stays
   and the old piece comes in: one more, and the 23 letters are spent).
   The forge works a dagger stack against itself exactly as it works
   potions: the stack IS the worked one (same row, same letter) and the
   plain ones left move down a row. Original note:
   Like kinds stack to 20 in one slot, one letter. A unique stays one. The twenty is
   the honest limit on KINDS, which is the closet Brad described: twenty
   shelves, and he knows which one the potions are on. Hoarding becomes
   possible; nothing creates more drops, and the caves still starve by what
   falls, so that is the right side to err on.
3. **The satchel as shelves -- BUILT 2026-10-03**, waiting on play. As
   built: `Item.satchel_takes` / `satchel_shelf` -- a shelf per kind it
   takes (food and potions, `satchel_kind`), `holds` 10 to a shelf, full
   only OF THAT KIND: the eleventh potion goes to the pack while a haunch
   still gets its own shelf; fungus has its own shelf, so picking is
   refused only when ten are in. The name reads "forager's satchel (12)",
   everything inside counted; the pickup says "(x3)". An old satchel of
   single haunches folds onto shelves on load (`_stack_the_pack`).
   **Three rules the same evening (Brad):** TAKING IT FILLS IT -- by any
   route (`give_item` -> `_fill_the_satchel`), everything in the pack that
   fits a shelf moves in, ten of each, the rest staying put, and the log
   lists what moved; WORN OR NOT IT WORKS THE SAME -- pickups and fungus
   picking go to `_the_satchel()` wherever it is, the offhand only adds
   the key; IT LIVES WITH YOU -- dropping it is refused ("The satchel stays
   with you"; it could not be sold or thrown already), so no floor of
   thirty things and no message to miss. **Played 2026-10-03 (Brad, floor
   4): nine potions and five haunches moved in on pickup, the bag read
   (14), the chooser showed the two shelves.** Polish from that: the bag
   is SLUNG, not raised (`Item.verb`), and the chooser's title counts the
   satchel ("14 inside · 10 of each", `InventoryPanel.count_line`) rather
   than the pack. Test: `_test_the_foragers_satchel`. Original note: Drop the ten SLOTS and
   say: one row per kind it takes, ten per row ("the satchel holds ten of
   each"). No slot arithmetic between a rabbit haunch and a bear haunch.
   Everything else as built: pick fungus, root it, drop meat, use closes
   the chooser, offhand, takes no hand, fills straight from pickups. Its
   capacity grows with the kinds it accepts; if it ever wants tightening,
   lower the ten, not the rows. Nearly a rename once step 2 stacks the
   pack: `satchel_room()` becomes "is there a row for this kind with room".
   Order: 2 then 3, one evening each with the suite and play between.

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
**Rabbits breathe the purple unharmed (Brad, 2026-10-01):** `_breathe` skips
the forager and both rabbits. Found in play: a rabbit asleep beside the purple
was dead in four turns, and a rabbit living on fungus is the reason its meat
can be the cure when brewing comes. Every other monster in the cloud is
poisoned as the player is (1 hp a turn, three turns, re-poisoned inside).
**SUPERSEDED (2026-09-30):** the miasma as built (strand 3) has no cure --
the poison lingers 3 turns. The rabbit haunch's healing role moved to the
NPC adventurers: a haunch takes the RED out of a marked adventurer.
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
**Folded into the wild creatures update below (2026-10-04).**

**The wild creatures update (Brad, 2026-10-04 -- a future backlog, rough,
not scheduled).** An animal ecology, from the bear and the rabbit outward.

**Step 1, the WILD faction -- BUILT 2026-10-04 (Legion), waiting on play.**
`Entity.Faction.WILD`, appended; the cave bear, rabbit and cave bat carry
`"wild": true` in the bestiary and `monster_from` seats them. The rules:
- `hostile_to`: a wild thing is nothing to a MONSTER (goblins hunt you, not
  rabbits), prey to the RISEN, and your side's enemy only once STRUCK --
  `Entity.provoked`, set in `_attack` when the player or an ally lands a
  blow, saved, and for good. The log says "The cave bear turns on you."
  (not for a forager: a rabbit runs, as before). Two wild things never fight
  each other yet (the food web is a later step).
- Unstruck, `_ai_wild` takes its turn: a forager forages as it always did,
  shying from you or a visible ally (`_what_scares`, never `_foe_for`);
  anything else sleeps until it notices you (awareness still runs, so the
  "?" and "notices you" are true), then keeps `WILD_SPACE` (2) between you
  and it and otherwise wanders or stands. Struck, it falls through to the
  ordinary monster turn with you its foe.
- You may shoot, throw at and walk into a wild thing (`_fair_game`: a bow is
  how you provoke a bear from afar; walking into it strikes it and never
  swaps places). It stops no journey and forbids no rest until struck
  (`visible_monsters` leaves it out; `visible_wild` is for the sidebar).
- A monster goes round a rabbit rather than waiting on it (`_step_toward`
  asks `hostile_to`, not faction; the trader is still never swapped with).
- The killer rabbit is a MONSTER again the moment it turns; a corrupted
  animal is a MONSTER (the purple takes the wild out of it).
- One colour for the kind: `Palette.WILD` (bfa22f, dry grass), on both
  renderers, provoked or not. Measured with check_palette.py's functions
  against the other tints a wild glyph can wear (ALLY, CORRUPTED, the killer
  rabbit's white, PLAYER): 35 deltaE at worst. The bat's purple, the rabbit's
  and bear's browns and the rat's grey no longer appear on the map for these
  three; the theme table still holds them (the legend's own rows read it).
- Sidebar: the wild in sight are listed in their colour, no "!" however
  awake, and counted apart -- "2 hostile · 3 wild", or "1 wild" alone. Struck,
  a bear moves into the hostile count and gets its "!". Legend: "wild -- no
  one's enemy until struck", and "wild  depth N+" on each animal's row.
- Tests: `_test_the_wild_are_no_ones_enemy` (full suite) and the sidebar
  block in `run_view_tests.gd`. `_test_pits_are_an_escape` now provokes its
  bear: only a hunted bear breaks and runs. Proof shots:
  `tools/probes/screenshot_wild.gd`.
- **The grudge (Brad, the same evening):** `Entity.grudge` is the last thing
  that struck a wild creature, whoever's side it was on (a reference, not
  saved: a fright does not survive a reload, where `provoked` does). A
  forager flees it above all else, sight or no sight -- what struck you, you
  know the whereabouts of (`_minds`: alive and within twice its notice
  range) -- and flees any MONSTER it can see as well as your side; a bear
  gives room to you, not to a kobold. Anything else fights its grudge back:
  a bear with a goblin's spear in it hunts the goblin (`_ai_hunter`) and
  stays no enemy of yours; `hostile_to` says yes for either party while the
  grudge lives, which is how a goblin's `_foe_for` turns to the bear beside
  it, and how two wild things will come to fight (the wolf). The bear's
  shove was always universal in `_attack`; a test now says so on a goblin.
- **Open, for play:** the bear still costs 17 threat in a cave that may
  never fight it, so caves with a bear are easier than they were; Brad's
  note below about re-measuring the threat ceiling applies to the bear now,
  not only to the rat. A wild thing hurt by a trap or the fungus is not
  provoked (nobody struck it) and goes on minding its own business.
- **They have to eat too -- BUILT 2026-10-04 (Legion), waiting on play.**
  `"eats": true` on the kobold, kobold slinger, goblin, orc and ogre
  (`Entity.eats`, saved). While UNAWARE of you -- gated like scavenging,
  nothing stops mid-fight for supper -- `_hunt` runs each turn: meat
  underfoot is eaten first (`_eat_here`: gone from the floor, and it heals
  the eater what it would have healed you -- the first monster that heals
  by eating; the slime will be the second); else the nearest game it can
  see within `HUNT_REACH` (6) is hunted with the creature's own fighting,
  `_ai_ranged` for the slinger, `_ai_hunter` for the rest; else it walks to
  the nearest meat lying about, yours included. Game (`_prey_for`): a WILD
  thing no bigger than the hunter, never the bear (`heavy`), and for a
  melee hunter nothing that flies -- a bat is the slinger's. The kill
  leaves the haunch where the rabbit fell and the hunter eats it off the
  floor, so a floor where the goblins got to the rabbits first has less
  meat in it. The rabbit runs from the goblin that speared it (the grudge);
  a bat shot at comes for the slinger. Two fixes the hunt forced, both from
  every earlier fight having had the player on one side: a fight's noise no
  longer rouses the one making it (`_make_noise(..., by)`), and a defender
  struck by any non-player-side attacker turns on what hit it instead of
  "noticing you" (the risen branch in `_attack`, generalised). Legend:
  "eats game  depth N+". Test: `_test_hunters_eat_the_wild`.
- **Bear > rabbit -- BUILT the same night**, after Brad herded a rabbit to
  a bear in play and nothing happened: the bear carries `"eats": true` and,
  awake and unstruck, `_ai_wild` runs the same `_hunt` the goblins have --
  it goes for a rabbit it can see, kills it, eats the haunch, and is still
  no enemy of yours. Never a bear (`heavy`), never you. A rabbit now fears
  a wild thing that eats as it fears a goblin (`_what_scares`). A sleeping
  bear sleeps: it hunts only once awake, which today means once it has
  noticed you. A save from before this has no appetite recorded, so the
  loader backfills `eats` from the bestiary by appearance.
- **Not in this step:** the rat (floors 1-2 need the slime first), the
  wolf, the rest of the food web (wolf > rabbit, spider > bat and rat), fire
  as a fear, the WILD colour freeing the bat's purple in the theme table.
  **Next (agreed with Brad, 2026-10-04):** the wolf, with bear-versus-wolf
  through the grudge; then the slime.
- **The wolf -- BUILT 2026-10-05 (desktop)**, waiting on play. As built:
  WILD, `eats`, depth 3+, caves twice over (`caves: 2.0`), hp 9, power 4,
  def 1, speed 130, flee 0.15; `d` in ascii, md-dog_side in the picture
  look, grey. It comes as a PACK of four: the fauna roll places one and
  `_spawn_pack` sets three more on the nearest open cells round it (no rng
  of its own, so seeds hold), and `max_per_floor: 1` makes that ONE pack a
  floor. Unstruck, the pack is nobody's enemy and hunts rabbits as the bear
  does (`_allies_near` counts only its own kind for a wild thing, so a
  rabbit beside a wolf is supper, not company). STRUCK by you or an ally,
  every wolf of its kind within `PACK_REACH` (8) turns with it -- provoked,
  the grudge on the attacker, awake -- and the log says "The wolf turns on
  you -- and the pack with it."; one further off keeps its peace until it
  is hit itself. Provoked wolves hunt you with `_ai_hunter` and the pack
  AI's "step in with company" rule, and the grudge is saved (`provoked`).
  Bear-versus-wolf is NOT in: two wild things still never fight each other
  (the food web step). Test: `_test_the_wolf_pack`.
  **Where they live (Brad, the same day):** floors 1-6 and 14 on -- the
  upper floors and the caves on both halves -- and never either fortress,
  where a wild pack in masonry reads wrong (the trained animals below are
  the way in there). Built as `bands` on the bestiary row: the bands a
  thing is found in, each with the chance a floor of that band has it at
  all, rolled ONCE A FLOOR on its own rng (`_roll_the_wild`, `fauna_rng`)
  and SET DOWN once (`_place_the_wild`: in a cave if the floor has caves,
  else a room that is not the first; the bear's den forms round it), never
  as a share of the per-area animal roll. Two measurements forced that: a
  share on floor 1, where the wolf and the bear are the only wild things,
  put both on nearly every floor (60/60, 50/60); and a share in the caves
  starved the rabbits the climb's caves exist to feed you with (17 in 30
  floors against a fortress floor's 60 -- `_test_cave_dwellers` caught
  it). Wolf {upper 0.5, caves 0.75}, a PAIR on the upper floors and four
  in the caves (`pack` by band, `_pack_size`); bear {upper 0.3, caves
  0.85}, back on floors 1-3 now a player can walk round it, and one a
  floor everywhere (the caves' second bear is gone with the cap lift). The
  per-area roll is no longer priced by the area's ceiling
  (`WILD_UNPRICED`): that price only ever touched the bear. Measured (60
  seeds a floor, `tools/probes/wolf_band_probe.gd`): upper floors have a
  pack on 43-57% and a bear on 23-35%; cave floors a pack on 65-83% and a
  bear on 75-92%; floors 7-13 none. **The bump warning**, the same batch:
  the first move into an unprovoked wild thing that can hurt you costs no
  turn and says "That is a cave bear, and it has done nothing to you. Move
  into it again to pick the fight."; the same move again attacks; anything
  else in between starts it over (`_meant`, cleared in `_end_player_turn`).
  A rabbit is never warned about (power 0), a provoked animal is your enemy
  already. Without it a floor-1 player with 30 hp who walked into a bear
  by mistake was dead in three of its hits. Tests: `_test_the_wolf_pack`
  (bands measured on both halves), `_test_picking_a_fight_is_deliberate`.
  **From Brad's first play (the same evening): a pack of four, three dead
  when he arrived.** Probe (`tools/probes/wolf_deaths_probe.gd`: cave
  floors, the player waiting 150 turns, each dead wolf's grudge read): of
  97 dead wolves, 65 had been killed BY A WOLF. The hunt took anything wild
  of no greater threat as prey, and a wolf is threat 6 like its packmates,
  so packs ate themselves. Fixed: `_prey_for` never takes the hunter's own
  kind. And a pack now REMEMBERS TOGETHER: a wolf struck by anything --
  an orc, a bear -- hands the grudge to every packmate within PACK_REACH
  (awake, not provoked: no one turns on you for an orc's spear), where
  before an orc camp ate a pack one sleeping wolf at a time. After: 73 of
  434 dead in 150 turns, none by a wolf; orcs 23, bears 13 (a bear hunts
  wolves as it hunts rabbits -- bear-versus-wolf through the grudge, as
  wanted), ogres 8, goblins 6, risen 6, 14 to no attacker (the miasma,
  traps). That is life outside the player and stays.

**The embers come first (Brad's play, 2026-10-05) -- FIXED.** At a
guttering brazier with a bow in hand he pressed the gem of returning to
set it, and the pack crushed it for its own use ("mark this brazier"): the
gems' own uses (6d) were listed before the forge in the pack's hint and in
`player_use`. One predicate, `gem_sets_here(gem)`: at EMBERS with a host
that will take it (or a unique to feed), setting is what the gem does --
the pack's hint says "set into short bow", the HERE box "set the gem of
returning", the letter, the click and the pad's use all go to the forge
with its choice of weapon (`_use_item` routes to `_merge_item`), and
`player_use` binds. At a LIT brazier, or with nothing to hold it, the
gem's own use stands as before. Test: `_test_the_embers_come_first`.
- **The warren: rabbits out of the fortress -- BUILT 2026-10-07 (desktop).**
  Brad: wild animals learned to avoid walls and garrisons, so a fortress
  should not have rabbits loose in it, any more than bears. Measured first:
  without a rule every fortress floor had 2 to 5. As built, the rabbit row
  carries `"not_in": [&"fortress"]` -- the ORDINARY roll never buys one in
  either fortress (7-9, 11-13); every other floor, floor 10 included, is
  exactly as it was (unlike `bands`, which would have made the rabbit one a
  floor and starved the caves). The way in is the garrison's own: a new vault
  marker `r` (a rabbit, wild, outside the budget; in `Vault.CONTENTS`, the
  linter, the vault editor's palette and the README) and the vault
  `the_warren.txt` (fortress band, 9x8, three rabbits, a water trough, the
  butcher's bones by the door; NO mushrooms -- two make a killer rabbit at
  this depth). Measured (`tools/probes/warren_probe.gd`, 40 seeds a depth):
  the warren is on 12-33% of fortress floors, every fortress rabbit is a
  warren rabbit, and after the pre-run the median rabbit is 4 cells from
  where it was drawn, a quarter more than 6 (every creature passes a door:
  rats squeeze, bears smash, the rest open; rabbits keeping to a room would
  want a leash, not built). Bats have faded out by these depths, so the
  warren is now the fortress's only animal life -- and its pre-run nearly
  free. The garrison's hunters may well eat the larder. Test:
  `_test_rabbits_keep_to_the_warren` (a mutation without the rule fails four
  checks).
- **Trained animals (Brad, 2026-10-05 -- designed, not built).** Reusable
  variants from two changes, the faction and the colour: a KOBOLD WOLF
  RIDER and a GOBLIN BEAR RIDER use the animal's icon and ascii in the
  MONSTER's colour (that is the tell: not a wild animal), the animal's
  stats, and are MONSTER, attacking on sight. An ORC or OGRE HOUNDMASTER
  is too big to ride: the master has its own icon and ascii, and its
  hounds -- wolves or bears -- wear the master's colour and are MONSTER.
  These are how the fortress bands (7-9, 11-13) get their animals, since a
  wild pack never rolls there. One thought from the desktop: when the
  master dies, the survivors could go WILD on the spot -- the provoke rule
  run backwards -- a fight you can end early by picking the right target.
  Everything needed exists: `_spawn_pack`, the pack AI, the faction field;
  what is new is a row that says "my pack is this other row, in my colour".

- **A WILD faction, appended** (factions are saved as ints). NEUTRAL cannot
  serve: today it means *inert* -- `_take_ai_turn` gives a neutral no turn at
  all, and `hostile_to` makes it no one's enemy -- which is right for the
  trader and wrong for an animal. WILD acts, lives its own life, and ignores
  you until provoked. The wolf needs exactly this; build it once.
- **Members:** bat, rabbit, rat, bear, wolf, spider. (The rat joined the
  same day, Brad: it is the spider's prey and a creature, not a monster.)
  Mind, when it is built: the giant rat is a depth-1 enemy, so a rat that
  ignores you until provoked thins the first floors; the threat ceiling
  should be re-measured. The ring of the rat (you pass as one) only gets
  more fitting. The slime (below) is the proposed replacement on floors 1-2.
- **One colour for the kind, the glyph for the which** -- as GEM and MAGIC
  already work. A creature colour (`Palette.WILD`, an earth tone); the letter
  or icon says what it is. The rabbit is NOT white: white is the killer
  rabbit's identity. The rabbit (`e0a05c`) and bear (`b5763d`) are browns
  already; the bat's purple (`8e6fa8`) is one of the muted purples
  `palette.gd` has to keep the vivid violet clear of, so moving the bat frees
  room -- and the rat's grey-brown (`8a7f6a`) comes free with it. Brad: the
  bat's purple also now reads as "a purple-spore bat", because purple means
  the poison fungus (the bat's colour is about two months older than the
  fungus, but players will not know that), so the move clears up a
  misreading as well. The new colour needs the palette's dichromacy check. Letters: `s` and
  `w` are taken (skeleton, wight) -- either colour carries it, as the ally `s`
  already does, or the wolf takes `d` (free).
- **The food web:** spider > bat, spider > rat, bear > rabbit, wolf >
  rabbit, rabbit > green fungus. Rats are the plague carriers that seed
  purple and red at bodies, so a den is a natural check on the fungus spread.
- **Fire, an innate fear:** a lit torch keeps every creature back. Bears and
  wolves fight HARDER within 2 of fire -- an animal cornered by flame. (Its
  own constant: `FIRE_SAFE` is 1 and is the fungus rule. Keeping back could
  reuse the giving-way code that already steps things away from a dragon.)

**The spider** (D&D's giant spider by way of Minecraft):
- Ranged, and does not attack you directly: it shoots WEBS, so you spend
  your turns getting free while the others catch up. Cornered, it bites.
- Escapes by walking the walls: the banshee's `_step_phasing`, used only to
  flee. It may end a move inside a wall cell -- deliberately, and it reads
  as clinging there -- and stays killable, because `player_move` tests for a
  creature before it tests the ground.
- **A nest it protects**, always a cave (`cave_regions`): rare in the
  fortress, decent in the upper band, common in the caves. Hostile inside the
  den, indifferent outside it; attacking one or burning its web provokes.
- **Webs are a TILE** (appended), where a shot lands and through the nest.
  Forcing past one costs **200 energy**, two turns -- the same shape as mud's
  move cost of 2.0. Burning it costs **100**, one turn, with the torch or a
  fire melee weapon. That is deliberately faster than the torch's three slow
  scorches on fungus (dry silk): paying attention and using fire is the smart
  move. Struggling is LOUD (`_make_noise`), and since 2026-10-04 hunters walk
  to a noise -- which is how the others catch you, with no coordination.
  Webs hold flyers (the bat, the spider's prey). A bear walks straight
  through.
- **As a risen ally** it webs your enemies. Allies use `_ai_ally`, not their
  bestiary AI, so the web shot must be taught there, as `_ready_weapon`
  taught archers. A RED risen spider webs anything in its room.
- **Open:** the bite's damage; what provokes a wolf pack; how far the torch
  keeps creatures back.

**Allies step out of the poison on their own -- BUILT 2026-10-04 (Legion),
the last thing of the night.** Brad's bear ally died in the purple's cloud
while he stood still, learning the scenario. An ally cannot be healed, so
every turn in the miasma or on the wrong fungus is a pure loss. Now, first
thing in its turn (`_ai_ally`), an ally standing on harmful ground
(`_harmful_ground`: in the cloud, or on purple or red) steps to the nearest
clear cell it can walk to (`_back_out_of_harm`, within `RETREAT_REACH` 5),
even with a foe beside it -- the foe will follow, and it fights better out
of the cloud. Boxed in with nothing clear in reach, it holds. The log says
"The risen cave bear backs out of the poison." once a floor, so the ally
teaches the scenario. And on its way to you or to a quarry it goes ROUND
the purple and its cloud (`_safe_step_toward`): the ally's own breadth-
first walk (`_ally_walk`) treats harmful ground as a wall, because the
shared pathfinder's careful grid routes round fungus SQUARES only and a
route that hugs the purple is in the cloud every step -- the first version
had the ally stepping in and backing out forever at the edge (caught by
the test). With no clear way at all it comes as near as clear ground
allows and waits at the cloud's edge: an ally will not follow you through
the poison. Risen enemies are untouched: the red walks them. Test:
`_test_allies_back_out_of_the_poison`.
- **The desktop's review of the night's six commits (2026-10-04, late).
  Brad's order for 2026-10-05: the ceiling FIRST -- the probe, then the fix
  sized to its number -- then points 2-4, then allies washing, then the
  wolf, the slime and the rest.**
  1. **DONE 2026-10-05 (desktop): measured, then split.** The probe
     (`tools/probes/threat_wild_probe.gd`, 60 seeds a depth) found the
     rabbit never counted in practice (it flees) but the bat was 20-26% of
     the hostile threat on floors 2-4 and the bear 15-30% on 5-7: floors 2-6
     carried a fifth to a third less than the ceiling promised. The fix is
     not a bigger ceiling: AN ANIMAL IS NOT WHAT THE CEILING BUYS.
     `_roll_monster` skips `wild` entries for the budget, and each room
     (FAUNA_CHANCE 0.4) and cave (FAUNA_CHANCE_CAVE 0.6) rolls one animal on
     top by the bestiary's own weights, never SPENT from the budget but still
     PRICED by the area's ceiling (a cramped cave could not afford a bear
     before and still cannot), with the bear capped at one a floor, two in
     the caves band (`_place_fauna`). Measured after: hostile threat per
     floor within a few percent of the old totals at every depth (2: 87 vs
     90; 6: 140 vs 131; 10: 278 vs 281), bats about four a floor on 2-3,
     bears about one a floor from 5 down. The ceiling test sums enemies
     only. First try without the price gave two to four bears a floor. Test:
     `_test_the_wild_are_not_the_budget`. Original note: **Measure the
     ceiling, do not feel it.** The bat was a real depth-2
     enemy and the bear the caves' heaviest; both are nobody's enemy
     unstruck, so floors 2 and 5-6 lost hostile threat the ceiling
     arithmetic still counts. A probe: hostile threat per floor over ~100
     seeds, before (6b4e32c) and after, so the number is known before
     Brad plays the caves -- and the slime's cost is set against that gap.
  2. **DONE 2026-10-05 (Legion).** `_minds` now asks that the grudge still
     be on the floor (`entities.has`, or you); a wolf whose orc leapt into
     a pit no longer hunts the ghost. Original: **A stale grudge.** `grudge` is a live reference and `_minds` tests
     `alive` and distance -- but a creature that leaves `entities` while
     alive (the pit leap) keeps `alive == true` on a stale x/y, so a bear
     could spend turns hunting a ghost. Guard: `entities.has(score) or
     score == player`.
  3. **DONE 2026-10-05 (Legion).** The HERE box over meat reads "pick up the
     haunch of rabbit; eaters about" while anything with an appetite is
     alive on the floor (`_eaters_about`); plain otherwise. Original:
     **Eaters eat what you left lying.** `_hunt` lets a goblin eat a haunch
     the player dropped -- the slime's lure design arriving early. Intended;
     say so where players learn things (the HERE box over a dropped haunch,
     or the legend's "eats game" row), since a dropped haunch is no longer
     a safe stash on a floor with eaters.
  4. **DONE 2026-10-05 (Legion).** `ALLY_WALK_REACH` (30) bounds the follow
     walk; the nearest-cell fallback does the rest. Original: **Bound the
     ally's walk.** `_ally_walk` searches the whole map when it
     cannot reach you (`map.width * map.height`); two boxed-out allies on a
     big floor is two map-sized searches a turn. Cap it (~30 cells) and let
     the "settle for the nearest" fallback do the rest.
- **Allies wash themselves -- BUILT 2026-10-05 (Legion).** Poisoned or
  burning with acid, an ally with a pool nearer than the hurt is long --
  fewer steps than points of hurt left, since every step is a tick taken
  (`_wade_to_water`, the same `_ally_walk`, clear ground only) -- makes for
  the water and stands in it; "The bone skeleton makes for the water." once
  a floor. **A rule changed to make it mean anything:** `_wash` said "a
  risen washes nothing", and every ally you can have is risen, raised from
  a grave or the recent dead, so water would have cleared nothing off the
  very allies this is for. Now the red keeps its dead's SPORES (a risen or
  fungal thing's spores are never washed), but poison and acid wash off
  anything that wades, living or dead -- the miasma kills them as it kills
  the living, so the pool keeps your bear. Tests in
  `_test_allies_back_out_of_the_poison`.
- **Bodies say who killed them -- BUILT 2026-10-06 (Legion).** The body
  record carries `killed_by` (`_killed_by` at `_settle_death`, saved): "torn
  by a wolf" for a wild killer, "slain by you", "slain by your bone
  skeleton", "slain by an orc", and for the floor's own killers the cause
  the death path now names -- "choked by the miasma", "eaten by acid",
  "burned by the red", "killed by a trap". The cursor, which never
  described a body at all before, reads "rabbit's body, torn by a wolf"
  while the body still shows (`body_lines_at`, `BodyLook.showing`), and
  "the red has it: it will rise" under a claimed one. The floor's history,
  read from its dead. Test: `_test_bodies_say_who_killed_them`.

**Any body can be buried -- BUILT 2026-10-04 (Legion).** Brad killed a
rat with the shovel in his pack and found no way to bury it: the shovel dug
only the red's dead, by design ("left for the rats -- digging them earns
nothing"), and the pack's tip said "5 more graves" without saying which.
Now (Brad's call, the night the floor came alive): any body in reach is
offered -- "bury the giant rat (shovel, loud) 0/3" -- and goes under in the
same three loud spadefuls, "The rats will not have it": a buried body feeds
no rat and seeds no fungus, which is the player's lever on the red's spread.
Only the red's dead still PAY toward the edge (`_reds_dead`), so the
dullness after a raise keeps its teeth; the tip reads "dull: a gem, or N
more red graves". With a plain body and the red's dead both in reach, the
red's dead is dug first. Tests in `_test_the_undertakers_pay`.

**A floor alive before you arrive -- BUILT 2026-10-06 (Legion), animals
only.** `GameState._prerun`, at the end of `build_level`: the floor's WILD
things (awake on arrival) live `PRERUN_TURNS` (150) quiet turns before you
are placed -- grazing, drinking, wolves and bears about their day, the
rabbits eating some of the green. Brad's rule is enforced, not hoped for:
while it runs `_attack` lands nothing, `_make_noise` carries nowhere,
`_update_awareness` notices no one, `_scavenge` takes nothing, no rabbit
turns killer; the fungus does not grow and fires do not age (`turns` does
not move); it draws on `prerun_rng`, swapped in, so the main rng ends
where it would have; the log and events it made are thrown away. Test:
`_test_the_floor_was_alive_before_you` (8 floors built with and without:
same creatures, same threat, same main rng, nothing said; the creatures
moved; reproducible; nothing hostile at your feet).

**WHY ONLY THE ANIMALS, AND WHY THE SUITE SKIPS IT (Brad asked for the
reasoning to be kept, 2026-10-06).** Three versions were tried the same
evening, each measured:

1. **Every creature takes the 150 turns** (animals AND hostile monsters).
   - A floor built in about 1.0-1.3 seconds instead of 0.15-0.2.
   - The full suite took **53 minutes** (from 13-15) and failed five
     checks: "every monster starts asleep" (the animals, now awake on
     purpose) and four threat-ceiling checks -- 93 rooms over their
     ceiling on the descent, 141 on the climb, the worst 107 over.
   - The cause of the ceiling breaches, probed: PATROLLERS. Seven guards
     walked the same round for 150 turns and bunched in one guard room at
     81 threat against a ceiling of 24. In play their rounds spread them
     as you move; on arrival that room broke the survivability promise
     ("the room you walk into can be beaten").
   - Profiling also found a real cost in normal play: the rabbit's
     mushroom search scanned the whole map every turn (3 ms a rabbit a
     turn, nine-tenths of the pre-run). Bounded to its nose (`RABBIT_NOSE`)
     -- the same answer for a fraction of the work, in play too.

2. **Only the animals take the turns** (hostile monsters stay placed).
   - Zero rooms over their ceiling (from 20 in the same probe): the
     ceiling bought each room as it is, and no ceiling counts the wild.
   - Guards start their rounds when you arrive, as they always have. What
     is lost: "the guards walked their rounds before you came".
   - The suite passed (2983 / 0 / 0) but still took **38 minutes**. Timed
     per test, with and without, in parallel: ALL the slowdown sat in the
     tests that build hundreds of floors -- connectivity 97 s -> 231 s,
     the room ceilings 82 s -> 188 s, the climb's ceilings 46 s -> 107 s,
     spawn points, cave reachability. The pre-run alone costs about a
     tenth of a second a floor (70-160 ms, measured on its own across the
     bands), and those tests build thousands of floors.

3. **Animals only in the game; OFF for the suite's floors** (as built).
   - `GameState.prerun_turns` is 0 in `run_tests.gd` and `run_one_test.gd`.
     Nothing the generation tests check can move under the pre-run: it
     never touches a wall and never moves a hostile monster.
   - `_test_the_floor_was_alive_before_you` switches it on (and restores
     what it found) and proves the invariants on eight floors.
   - The suite: **16 minutes**, 2983 / 0 / 0. In the game: a tenth of a
     second at each staircase, and the floor's animals are already up,
     spread out and about their day when you arrive.

The lesson, in CLAUDE.md: anything added to `build_level` is paid thousands
of times by the suite; time it per test with and without, not with a small
probe (an 8-floor probe had called version 1's cost "about nothing").

**A floor that was alive before you arrived (Brad and the Legion,
2026-10-04 -- an idea, not scheduled).** Run a few hundred quiet turns of
the ecology at `build_level` before the player is placed: rabbits have
grazed, rats have been to the old bodies and seeded the fungus, patrols have
walked their rounds, the goblins have drifted to the brazier. You walk into
a result, not a fresh board -- which is the one shape of off-screen life
that pays off within a single visit (the dungeon is one-way). **Brad's
rule: nobody dies in the pre-run.** Combat is off; creatures move, eat and
sleep. Then the threat on the floor is exactly what mapgen budgeted, only
rearranged, and the ceiling promise holds untouched -- no births needed to
offset losses, because there are none. Its own `RandomNumberGenerator`
seeded from the run (never the sim's rng: the draw count would move every
seed-pinned premise). Re-measure the ceiling tests after it anyway: a guard
that walked its round for two hundred turns can be standing at the door you
came in by, and that is a feature.

**Tending a low fire with your torch -- BUILT 2026-10-05 (Legion).** Not
the relight below: Brad's worry was that a free relight always in your hand
would make the scroll of light, the fire gem and the fire blade worthless,
and he was right. The split is the dungeon's own: guards never relight a
dead fire, they stoke a low one. So the torch does the guard's job with the
guard's numbers -- a brazier still lit at `BRAZIER_LOW` (4) or less, three
turns of feeding (`TORCH_TENDING`, "feed the fire (torch) 1/3" in the HERE
box, G), and it comes up by `BRAZIER_STOKE` (3), never more than a passing
guard would have given it. A dead brazier stays a paid problem. Progress
is the floor's (`tending`, saved beside `scorched`). Fair both ways: the
guards already tend ("The kobold feeds the fire."). Test:
`_test_tending_the_fire_with_the_torch`. The original note, kept:

**Relighting a cold brazier with your torch (Brad, 2026-10-05 -- an idea,
superseded the same day by the tending above).** Brad sees most fires guttered: a fire loses a
charge every 40 turns and guards stoke the low ones by 3, so a floor whose
watch he killed goes cold -- the system working, with no way to take over
the guards' job. Today a cold brazier costs a fire gem (15) or a fire
blade's binding (10). The pick: THREE TURNS of kindling at a cold brazier
with the lit torch, like the three scorches on fungus (`TORCH_SCORCHES`),
and it comes back at `BRAZIER_STOKE` (3) -- one heal, not a merge -- which
is what a passing guard would have given it. No new item, no letter, built
on the burn-the-fungus verb. Rejected for now: longer burn times (delay the
same cold floor and undo "take healing when you find it"); FLINT knapped
from rubble (a good item, but a pack letter -- park until the pack has room
or it can live in the satchel). And for the pre-run: it moves creatures,
not clocks -- fires do not age during it, so a pre-run floor is one whose
guards tended their fires.

**Monster camps (Brad, 2026-10-04 -- an idea, not scheduled).** Worldgen,
not behaviour: a camp is placed like an authored vault, in a room or a cave
(every floor, the fortress for sure, caves without a bear), and the region's
whole threat budget goes to it -- three goblins and an ogre standing round
a fire, sleepers and a beat that circles it, a barricade tile at the mouth
(close to the barred door). Then a stray monster is a fight and a camp is a
QUESTION: the sidebar and the HERE box say "a camp: 3 goblins and an ogre
at a fire" before you commit. Suits caves better than masonry does: a fire
and bedrolls in a cave read as what a cave is for, where a stone room reads
as a mistake (CLAUDE.md). Most of the behaviour exists: sleeping and
patrolling activities, scavengers, the wake chain, hunters walking to a
noise since day 7.
- **The fire is a CAMPFIRE, not a brazier (Brad's answer, same day).** A
  new light-source tile: rest and heal at it, as at a brazier, but NO
  forging -- so it is never a forge site and never a mark for the returning
  gem, and the tests that count braziers per floor stay true. The monsters
  use it too: they rest and heal at their own fire, and re-stock it. Icon
  `nf-md-campfire` U+F0EDD (checked in the full font 2026-10-04; a line in
  `GlyphTheme` and a rebuild of the subset with `tools/build_icon_font.py`).
  ASCII and the colour: open.
- **Open:** whether a camp's sleepers wake to the barricade being forced;
  what a taken camp is worth (its fire, its gear); how a camp and a wild
  bear share a cave (they do not: a bear's cave gets no camp).

**The slime -- BUILT 2026-10-05 (desktop)**, waiting on play. **It leaves
the run's own things alone (Brad, 2026-10-05; Legion):** `_slime_refuses`
-- the amulet, a unique, the satchel, a named hero's bone -- are neither
swallowed nor walked to; a slime that swallowed the amulet and dissolved in
the miasma out of your sight would have hidden the run's goal. Chests are
tiles, opened by your step alone, so they were never in reach. Tested in
`_test_the_desktops_review_points`. As built: a
floors-1-2 monster (hp 5, power 2, speed 70, threat 2, `j`, md-square_rounded
in the picture look, its own green) kept on every floor at a low no-fade
weight (0.35) as a CARRIER of the red (`SPORE_CARRIERS`; the red lets it be,
as it does the rat); the climb corrupts it through `_roll_corruptible` as
any cheap thing. Its own AI (`_ai_slime`): what lies under it is eaten if
meat or green fungus (gone) and SWALLOWED otherwise (carried, marked
scavenged); anything lying within SCAVENGE_REACH is walked to before
anything else, even with you beside it -- the lure; nothing to take, it
hunts like a hunter. Killed, it drops everything it swallowed, certain
(`_drop_loot` now drops a monster's unworn carry too -- the first monster
that had one). ACID is its own field (`Entity.acid` trait, `acid_turns`
ACID_LINGER 3 at ACID_HURT 1), not the miasma's poison: a rabbit is eaten
by it, `_wash` clears it ("washes the acid off you"), the sidebar chip says
"acid · N" and the HERE box "acid -- 1 hp a turn, N more; water washes it
off"; a death to it reads "eaten by a slime's acid". Test:
`_test_the_slime`. Original design: A MONSTER, not a
wild creature, so it lives here rather than in the update above -- but it
belongs beside it: if the rat goes WILD, floors 1-2 lose their commonest
enemy, and the slime is the classic thing to fill them.
- **Floors 1-2 entry monster, low cost,** and filler wherever a few threat
  points are left over. Mind the TIER_FADE: `weight` decays to zero about six
  depths past `min_depth`, so a min-depth-1 slime stops appearing on the
  descent by about floor 7 on its own. "Filler for other levels" therefore
  wants either a gentler fade for it or a filler rule; the CLIMB needs
  nothing -- `_roll_corruptible` re-admits cheap low-tier things without the
  fade, so a corrupted slime joins the climb's list for free.
- **Icons (both checked in the full Nerd Font in `tools/fonts`, neither used
  yet):** `nf-md-square_rounded` U+F14FB, or `nf-fa-jira` U+EF56. Adding one
  is a line in `GlyphTheme` and a rebuild of the subset
  (`tools/build_icon_font.py`). ASCII: `j` is free -- NetHack's jelly.
- **What it does (Brad, same day).** NOT the Minecraft split -- everyone
  knows that one. It is a SCAVENGER of everything:
  - It hunts down items -- weapons, armour, food, potions, scrolls, all of
    it -- picks them up and carries them away. Left alone long enough it is
    a walking treasure chest, and on death it DROPS EVERYTHING. It moves loot
    and never makes any, so the sparse-caves rule is untouched.
  - **Except what it eats:** meat (bear or rabbit) and fungus DISSOLVE in
    it and are not dropped.
  - **Acid that lingers,** borrowed from the purple: its hit goes on hurting
    a few points after it lands, unless you fight it standing in WATER or
    run to water and wash it off.
  - **The player's tactic:** drop things to lure it -- anything, it wants all
    of it -- and lead it into water to fight it there. (Food is a poor lure:
    it is eaten, not carried.)
- **What the code already has for it:**
  - The lingering hurt is the miasma's poison tick (`Entity.poisoned`,
    POISON_HURT a turn for POISON_LINGER turns), and `_wash` already clears
    `poisoned` in water. It wants its own name in the log and the status
    line -- "acid", and the water's message saying acid, not poison -- so the
    HERE box can teach "wash it off". **Mind the rabbit:** `_breathe` returns
    early for rabbits BEFORE the tick, which is harmless while the miasma is
    the only poison (checked 2026-10-04) -- but acid riding `poisoned` would
    make rabbits immune to it too. Move the guard to the miasma half only.
  - Carrying: a monster's `inventory` is saved, and `_drop_loot` already
    calls the dragon's hoard "the one thing in the dungeon that hoards" and
    says several creatures could be. The slime is the second.
- **Deeper down, a carrier, not a fighter (Brad, 2026-10-04 night):** by
  depth 6 it is a one-hit kill and no threat by damage at all; it keeps
  appearing on the later descent floors as an AGENT of the red -- it eats the
  meat and, like the rat, seeds red spores at the bodies it passes
  (`take_spores` / the body-seeding the rat carriers use) -- so the threat is
  to the floor's food and the floor's dead, not to your hp. On the climb it
  is a corrupted monster through `_roll_corruptible`, which re-admits it
  without the TIER_FADE. So the fade only needs to be gentle enough to keep
  it on the descent as a carrier; a filler rule is not required.
- **Two existing rules it breaks, on purpose -- say so in the code:**
  - `_scavenge` runs only while a creature is UNAWARE ("nothing stops
    mid-fight to try on armour"). The lure needs the slime to go for a
    dropped item even while it hunts you.
  - `Item.scavenged`: "the dungeon may take your things, not eat them." The
    slime eats your food. It is the one thing that does, and only food.
- **Answered (Brad, same day):**
  - **Carrying nothing,** it hunts anything that may have an item -- you
    included -- or, cheaper with the pathfinding and items already there,
    goes for a potion on the floor.
  - **Eating heals it** -- the first monster that heals by eating. New code,
    on a low-level monster.
  - **It eats the red risen.** Bigger takes longer: a risen giant or dragon
    keeps moving and attacking while the acid works on it.
  - **What it is:** no brain -- a kind of red-fungus variant. The red says
    "expand the risen"; the slime says "I hunger. Everything is good."
  - **A red risen slime** -- humorous and terrifying. The red must keep it
    from eating other red risen (one side; `hostile_to` already makes the
    RISEN faction no enemy of itself, but the slime's hunger has to ask too).

**Armour gems -- BUILT 2026-10-01**, waiting on play: three per slot now, as
for weapons and shields. The road (rubble only, +1 defence per 4 rooms, +3
cap, reset per floor) stays out of found magic; **the veil** and **the
lantern** (Brad's pick: polar opposites, neither a defence boost -- the road
is that) are appended to the element table after it, so found magic rolls
them on body armour, which held nothing before, and the weapons' rolls are
untouched. The veil in armour: the light on you counts VEIL_LIGHT 0.6 of
itself when something tries to notice you; from the pack, crushed while
hunted: every hunter not beside you drops to suspicious, forgets its last
sight of you and cannot notice you for VEIL_BLIND 5 turns ("vanish from the
hunt"; refused when nothing hunts you). The lantern in armour: the torch
reaches LANTERN_CELLS 1 further and so do their eyes (`_notice_reach`); from
the pack, crushed: the torch flares as the scroll of light does ("flare the
torch"; refused while flaring). Both min depth 2-3, in the gem roll. Building
the veil found an old quirk in `_make_noise`: a SUSPICIOUS creature outside a
noise's radius was set awake and straight back to ASLEEP with its notice
block wiped, so any noise anywhere calmed a suspicious thing (and undid the
veil); out-of-earshot creatures are now untouched. Original
note: the gem of the road is deliberately kept OUT of the loot table
(`only_from: rubble`); the hosting plumbing (`hosts: armour`, binding at the
embers) was already built. **Mule is probably
dropped** — its blocker is the 24-letter inventory pool, and the fungus bag
covers similar ground. **Dodge stays parked**: it fights
`DAMAGE_FLOOR_FRACTION`, which exists so nothing ever whiffs.

**Hidden traps -- BUILT 2026-10-01**, waiting on play. From the playtest ("if
I can spot a trap I'll never step on it"). As built: every trap the floor lays
starts HIDDEN (`hidden_traps`, saved) -- its square is floor to the eye, the
memory, the minimap and the route, and it springs underfoot ("The floor
clicks under your foot."), ending a walk there. Each turn every hidden trap
within SPOT_REACH 3 that you can see gets a roll on its own rng: SPOT_DARK
0.12 plus SPOT_LIT 0.60 times the light on its square, less a fifth per cell
of distance -- in torchlight a trap two cells off is spotted about half the
time a turn, in the dark about a fifth; the trapwright's glass (a unique for
the OFFHAND, min depth 2, the chest pipe) adds half again. Spotted: "You spot
a trap", the trap tile as before, routed round. Monsters do not spring them
(it is their floor). Walking straight at a lit trap springs it about one time
in six; in the dark most of the time -- one more cost to dousing. The legend
says "hidden until spotted; springs once". `_spot_chance` is the tuning
point. Original design: you MAY spot a trap within 3 cells (a chance,
likelier in torchlight -- one more cost to dousing); a trap-finding unique
for the offhand adds +50%.

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

**The latched gate (Brad, 2026-10-07 -- an option, not asked for).** A door
variant that NOTHING but you gets past: no opener opens it, no rat squeezes
under it, no bear smashes it -- the only door in the game that holds. It
draws exactly as a door in classic and 3D. First use: the warren, whose
rabbits today start in the room and wander (a door stops no creature; after
the pre-run a quarter are more than 6 cells out). Shape, from the desktop:
a second door tile (closed and open), a wall to monster pathfinding and a
door to yours; opened by you it is an ordinary open doorway, so a gate left
open lets the rabbits out, and a guard shutting it behind them latches it
again. More uses: kennels for the houndmaster's wolves (penned until he or
you lets them out), the oubliette's cells, pens at the house for tamed
animals; vault authors get a letter for it. **Keep the look, add the
words:** the rule "every interaction leaves a trace the player can SEE"
means a rat stopping dead at an ordinary-looking door needs explaining, so
the cursor and the HERE box name it "a latched gate".
**Refined the same day (Brad, desktop's suggestion):** its OWN COLOUR in
both views -- the tell, seen before it is read. And ANIMAL-PROOF, not
bear-proof: a latch stops whatever cannot work a latch. No animal opens it
(rabbits, rats, wolves, bats stay their side -- the whole job of a pen
gate); anything with hands does (the garrison's goblins walking in to eat
the larder is a feature); a bear still smashes it as it smashes any door --
a gate is a fence, not a vault door. A truly unbreakable door, if ever
wanted (a boss's vault), is a separate thing.

**Gems on any host, with a different effect there (Brad, 2026-10-07 -- an
idea with a shape, not built).** Today each element has ONE host family
(`Item.ELEMENTS[...]["hosts"]`: fire any weapon, frost and leech melee,
returning bows, bulwark/mirror/boss shields, road/veil/lantern armour). Brad:
let a gem go into a host outside its family and do something CLOSE ENOUGH
there -- not a 1:1 parallel, which would never come out clean. Mostly an
if-then on the host and reused effect code, and it would roughly triple what
the gems can do. His two examples, both of which reuse code that exists:
- **The gem of the boss on a BLUNT weapon: knockback.** On a shield it is the
  bash (twice its tier in damage); on a mace or hammer the blow SHOVES
  (`_attack`'s knockback and `_shove`, built for the cave bear and the cave
  giant -- walls stop it). The crossover is the point: a shove into a pit
  sends the thing a floor down, angry (strand 5); onto a found trap springs
  it; into the purple poisons it; into water washes it. Every hazard on a
  floor becomes a weapon. It also gives the fortress back a knockback threat
  when an orc carries one (no knockback creature lives there since the bear
  left).
- **Returning on a THROWN weapon: Stormbreaker.** A war axe holding the
  returning gem, thrown from the throw menu (weapons already have throw
  ranges), comes back to your hand after a few turns -- the bow's returning
  timer (`_tick_returning`, `GEM_RETURN_STEPS`) pulling the one weapon
  instead of the arrows on the floor. More damage than an arrow, and you are
  empty-handed until it lands back: the offset is the wait.
**What it needs, when designed in full:** a second table, element x host
family -> effect, beside `ELEMENTS` (which stays append-only: its ORDER is
load-bearing for found magic); `accepts_element` and `_default_host` asking
that table; the pack's hint and the HERE box naming the effect ON THAT HOST
("set into war axe: it comes back"), one predicate as `gem_sets_here` is;
and found magic left alone at first -- cross-host effects only by the forge,
so no seed moves and no found item rolls a combination nobody has played.
Pick two or three combinations to start (Brad's two are the natural pair),
play them, then grow the table.

**Tomorrow's order (set 2026-10-05 night, for 2026-10-06):** animals drink
at the pools (half an hour), bodies say who killed them (forty minutes),
then TAMING THE WOLVES as the day's feature (half a day; settle first
whether bear meat counts toward the haunch price -- the Legion's view: yes,
any haunch). The pre-run gets its own session after, when more routines
exist to run. The bestiary page below gets its own UI session, not a slot
in a full day.

**A bestiary page of its own (Brad, 2026-10-05, not asked for yet;
Brad's own thoughts the same night: yes to the page -- legend > bestiary >
overview map as one cycle on cursor, vi keys and the pad; and NO to a
hand-kept markdown file as its source, however tempting for icons and
colours. The page draws from the bestiary rows as the legend does, so it
can never disagree with the floor; a file beside the data is the hand-kept
copy that falls behind -- check_palette.py's shared-glyph groups did
exactly that once. Its own UI session.)** The
legend's creature column grows by a row with every creature added, and it
will keep being added to: the slime and the wolf took it past the window
on 2026-10-05 and the rows now squeeze their pitch to fit (`LegendPanel.
pitch_at`), which is a stopgap. The legend and the overview map are already
pages of one reference (left/right, d-pad on a pad, Brad's Zelda-menu
comparison); the bestiary becomes a third page in that cycle -- legend,
bestiary, map reads as "what the symbols are, who lives here, where you
are" -- or after the map. With a page of its own it can say more per
creature than one line: both looks' glyphs, met or not, where it lives
(the bands), wild / eats / pack, what it drops, the ring tells, and the
run's own count of them met and killed. The legend's creature column then
shrinks back to the marks and the kinds, and stops growing.

**A minimap for the 3D view (Brad, 2026-09-28). BUILT the same night**,
waiting on play: `Sidebar._draw_minimap`, drawn from the overview's own
`MapPanel.draw_marks` so the two cannot disagree; terrain cached as a picture
once a turn; a facing line on your dot; gives way to the look block. Brad's thought: the classic
view as a minimap. Better base: the OVERVIEW map (`o` / from the legend), which
already draws the whole floor compactly. Put it in the sidebar's empty middle
(under UNDER CURSOR), covering nothing of the 3D view. North-up, NOT rotating,
with an arrow for the player's facing -- with the follow camera swinging, a
fixed-north map is what keeps a player oriented. Classic itself stays as a full
option (cheap: shared layer, both views tested), just no longer designed-for
first now that 3D + follow is the default.
**Measured (from Brad's itch screenshot):** the look block (UNDER CURSOR /
LOOKING AT, filled by `x` and the mouse) starts ~300 px down the 720 px
sidebar; the help line is at ~680 -- about 17 lines of room. Its realistic
worst case is 8-9 lines (an armed monster: tag + 3 gear, on a small loot pile,
+ terrain); an epitaph is ~6; each ally row above pushes it down one. The
whole 96x54 floor at 2 px a cell is 192x108 -- about five lines, narrower than
the sidebar's 228 -- so it fits just above the help line and leaves ~11 lines.
**Rule: the minimap gives way** -- not drawn on a frame when the description
would reach it. Information always wins.

**Animals drink -- BUILT 2026-10-06 (Legion).** Its decisions draw on their
own `drink_rng` since the desktop's review the same night (on the main rng
the draw count depended on how many animals were up); and the cursor tags
an unstruck animal "(wild)" so a wandering bear is not read as hunting
you. The pack's rabbit hunt makes ordinary combat noise and can pull a red
room's risen: left as the system working, watch it in play. The first routine in the
dungeon that is not about you. An unbothered wild thing with a pool within
`DRINK_REACH` (6) heads for it now and then (`DRINK_CHANCE` 0.12 a turn,
and once decided it keeps walking: `Entity.drinking` below zero is thirst,
above zero the sip), stands in the water for `DRINK_TURNS` (2) -- "The cave
bear drinks." -- and goes back to its day. A rabbit drinks too when nothing
frightens it; frightened, it runs first. A struck animal has better things
to do; prey beats thirst for a bear. Heals nothing, washes only what
`_wash` would. **And a rule it forced: an animal that is up stays up.** For
a monster, awake means hunting you and losing you means winding down to
sleep; an unstruck wild thing dozed off the moment you left its sight and
had no life of its own (the test found one sip in two hundred turns). Now
`_update_awareness` leaves an unprovoked wild thing awake once woken. This
is the hinge the pre-run turns on: a floor's animals must be up to be found
doing anything. Test: `_test_animals_drink`.

**Drip pools in the caves, and a longer poison -- BUILT 2026-10-05 (Legion).**
Brad, from play: poisoned by the miasma in a cave, no water anywhere near
-- the HERE box's "water washes it off" was a promise the caves rarely kept
(one cave in five was damp), and three lingering turns were gone before
any pool was reached: a decided but useless counter. Now most caves (70%)
hold a drip pool of three to six cells grown from one spot over cave floor
(`MapGen._drip_pool`, its own `pool_rng` so no seed-pinned premise moves),
the small-life drips always fall on cave water so the pool reads as where
the ceiling drips, and `POISON_LINGER` is 5 (was 3): a two-step walk saves
three points instead of one. Tests: `_test_drip_pools_in_the_caves`, and
the drips in the view suite's small-life check. **Ideas from the same talk
(Brad): animals go to the pools to drink** -- they eat already -- and a
camp's monsters could too, once camps exist.

**Water washes it off (Brad, from play, 2026-10-01 night) -- BUILT
2026-10-02**, waiting on play. As built: `GameState._wash`, run underfoot
each turn (the player's in `_end_player_turn`, everything else's in
`_grow_fungus`), before `_breathe` so a pool beside the purple is breathed
again the same turn. Skips the dead (`fungal` or `risen`) and flyers.
Wading is now a noise of `Tiles.WADING_NOISE` 4 (under a fight's 6 and the
graves' 7) through the same `noise_radius` route as bones, so it reaches
the risen's ears and never a headstone. The legend and the HERE box say
both halves. Test: `_test_water_cleanses`. Original note: One rule a player can hold: *water cleanses*. Anything -- you, a
rat, a monster -- that steps into WATER loses the red spores it carries
(`Entity.spores` cleared: the mark's ring goes, its body will not be
claimed), and the purple's poison ends at once for whoever wades (the three
lingering turns, not the cloud itself -- stand beside purple in a pool and
you breathe it again). Why it earns its place: water is slow and loud today
and does nothing else; this makes a pool a place to RUN TO -- wash before
you die so the red cannot have you, break the rats' carrying of spores
across a floor -- and the red already cannot grow or crawl onto water
(`_fungus_can_grow` is floor only), so a pool is a firebreak the player can
read. Message: "The water takes the red off you." / "...off the rat."
Purple-and-water will rarely coincide; it costs nothing to make the rule
whole. Risen are dead things: wading does not wash a RISEN clean.
Build: a hook where a creature's step lands (player_move, _step_travel, the
monster step), a message when seen, one test. The haunch-as-cure for the
poison still waits for brewing; this is the other, placed route.
**The trade (Brad, same night):** washing should COST something, and the
cost is noise -- water makes none today (`Tiles.noise_radius` is 7 for
bones, 0 for all else; "wading" is only slow). Give wading a radius of
about 4 (under combat's 6 and bones' 7) and the pool becomes a choice: wash
the red off, and the blind risen hear you splashing and come. A risen in
water washes nothing -- it is dead, the red has it. The two halves ship
together or the wash is a free lunch.

**"Extra" effects: tilt-shift and fog (Brad, 2026-10-03 night) -- an
idea, not decided.** A fourth step on the `e` cycle: still > simple >
full > extra, extra being full plus a tilt-shift (depth of field, the
overhead view as a miniature on a table) and a drifting fog. Brad is
mostly sure about the tilt-shift and would put it in FULL, but knows
players who like the game as it is and dislike tilt-shift in other games
-- hence a step above full that nobody has to take. What exists: the 3D
view already has a hidden "rich" tier that switches on by itself on
Forward+ (`DioramaView.rich`: screen-space occlusion, soft shadows, the
volumetric fog the miasma uses), so extra is a player switch over that,
plus the two effects. To settle before building: (1) it cannot exist on
the web or mobile build (Compatibility has no depth of field and no
volumetric fog) -- extra collapses to full there and the settings row
must say "PC only", or itch players think the key is broken; (2) fog
must not hide information: the memory fade and the torch's edge already
do the darkening, so keep it thin and beyond the lit radius, never over
a cell the rules say you see; (3) the Q cycle: classic has nothing to
blur or fog (extra = full there), both 3D views take both, and in the
follow camera the focus plane is a fixed distance. About an evening, with
view tests for "extra collapses to full off Forward+" and "still is
untouched"; judging the look needs a build on a Forward+ machine (the
Legion is one). After the Legends intro.

**Destructive environments (Brad, 2026-10-01 night) -- unformed, kept.** He
has carried it three days without a shape. What exists already: bears take
doors off hinges, fire burns fungus (bones and wooden doors designed under
strand 6), the crag fills pits, heaving breaks a bar. The unbuilt half is
walls and pillars that come down, which fights two things: walls are drawn
from their neighbours in the classic view, and generation proves every
floor completable once. To be shaped around a MOMENT first (what would the
player be doing when a wall gives?), not a system.

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

**Kobold slingers' first floor. BUILT 2026-09-28**, waiting on play. Slingers
were 8 of Brad's 22 deaths, all on floors 1-2, and Gabe and David complained
of them too. On their first floor (2, going down) they fire every other turn;
everywhere else they reload 0, 1 or 2 turns at random after a shot (half fire
straight away). Their own rng stream (`reload_rng`). The first reload seen on a
floor says "The kobold slinger fumbles for another stone." Other shooters are
unchanged.

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

**NPC adventurers, and friends for the Legends party (Brad, 2026-09-30,
from Dwarf Fortress's visitors from other fortresses).** Designed, not
scheduled: it belongs with the Legends design (after 6c and 6d).
- Other adventurers wander the dungeon. **Neutral to the player and the
  trader** (the trader is the template: Faction.NEUTRAL, first of its kind).
- **Hunted or not, by what they have done:** an adventurer who has done
  nothing aggressive to the monsters is looked for by nothing. One who has
  may be hunted -- so you sometimes find one in trouble.
- **They want something:** a specific gem, a weapon or armour type. Hand it
  over and you have made a FRIEND. Another sink for gems and gear, and a
  reason for the trader's 3-for-1.
- **Or they need rescuing:** "on your way back through here, can you help me
  escape?" -- you escort them on THAT floor only (the climb passes the depths
  a second time, which is where "on your way back" pays off). Up one floor
  they leave: "Thanks, I was stuck there -- I'll make it back on my own," and
  go quickly for the stairs, faster than you can follow, dodging monsters and
  traps.
- **Friends are kept in legends.json** as whole heroes, as runs already are
  (player-owned file, redirected by use_scratch_files -- CLAUDE.md rule).
- **The Legends party:** your retired hero plus two friends. More than two:
  you pick. None: two are generated.
- **"Can you heal me?" (Brad):** an adventurer with the red outline asks for
  help -- give them a **haunch of rabbit** and it takes the red out of them
  (their spores cleared), and they are a friend. Rabbits already eat fungus;
  their meat as the cure fits the food chain (bear -> rabbit -> fungus).
- Crossovers to consider (Claude): a red-marked adventurer is a friend on a
  timer -- help them, or burn the body before it rises; a friend shares what
  they have seen (the stairs, which colour was the gong), tying in the
  trader-gossip idea.

**Night-of-2026-09-30 ideas (Brad + Claude, after a Copilot review). Ideas
for Brad's call, not scheduled; play the built strands first.**
- **Predation -- live the food chain.** Today "bear -> rabbit -> fungus" is
  only what the PLAYER gets: bears and rabbits are on one side and ignore
  each other. Make a bear that sees a rabbit chase and eat it; rabbits flee
  bears as they flee you. A cave then has a life of its own when you arrive
  (a bear busy with prey is not busy with you; lure one onto rabbits). The
  loop closes through the red: the rabbit's body draws rats or red, rises; a
  bear that chased through red is marked and rises when it dies. **OPEN
  (Brad):** bears eating rabbits means less cave meat, and caves are sparse
  on purpose (CLAUDE.md) -- tension or too harsh? (Rabbits are already spore
  carriers: prey at one end of the chain, spreaders at the other.)
- **Blood trails with three readers.** Wounded creatures (and you) leave a
  short-lived trail. YOU read it (something hurt went that way); SCAVENGERS
  follow it (rats drawn off, or onto you if you bleed); **THE RED follows it**
  -- today it crawls only toward bodies within 8; with blood it tracks the
  wounded before they die. Your own wounds near red draw it a map to you.
- **Purple's job: the counterweight to the red** (Brad: purple is
  under-used; it does little damage, the red is the threat). (1) Its cloud is
  FOG: blocks sight and muffles sound -- cover from the blind risen, at the
  price of the poison. (2) Red cannot grow in purple air: a natural
  firebreak. (3) Plant it from the satchel: purple in a doorway seals the red
  in. Lure risen into it: they rise at half hp, and it already poisons them.
  The ring-rat is NOT immune to purple (the truce is red-only) -- keep it so,
  or a ring-rat in fog is unheard, unseen and unharmed.
- **Brewing at a brazier (needs the satchel).** Base decides the kind,
  fungus decides the subject; costs brazier charge like a merge:
      healing potion + green  = lasting regeneration
      healing potion + purple = miasma resistance (Brad)
      healing potion + red    = BLOODLESS: red cannot bite you, and you leave
                                no blood trail (not hidden from risen ears --
                                that is the ring's job) (Brad)
      meat + green  = bait for animals (feeds predation)
      meat + purple = poisoned bait
      meat + red    = bait for the risen (Brad's bait; red smells blood)

**Books and libraries: game hints as lore (Gabe and David, 2026-10-01;
Brad's library).** Idea, not scheduled -- after 6c, 6d and the rest already
queued. The trader knows a lot but not everything; the dungeon's former
residents left books behind as help articles.
- A **library vault on the first floor of every band:** 1, 4, 7, and on the
  climb 11, 14, 17 (Brad). Several books per library.
- **The caves (4, 14): not a library** -- a masonry room in a cavern "reads
  as a mistake" (CLAUDE.md, the second reason caves get few vaults). An
  ABANDONED CAMP instead: bedroll, dead lantern, a few books by a cold fire --
  whoever wrote them did not make it.
- On the climb, 11/14/17 are the band floors you leave each band through
  (the reverse of the descent) -- fine, but a deliberate choice.
- Each book teaches ONE system in a resident's voice (the red, the ring,
  relighting, the embers, terrain costs) -- the HERE box's teaching as notes.
  PLAYTESTS 2026-09-26: fresh players could not find `?` and could not see
  terrain cost; this reaches them where they explore.
- **A journal, kept ACROSS RUNS (Brad, decided):** read books are kept and
  can be reread from the menu. Two kinds: HELP books (the systems) and LORE
  TOMES (the dungeon's history and story). No single run finds them all --
  the full story takes several plays. Cheap story: the text does the heavy
  lifting, with no large graphics or cutscenes (some can still come later).
  A player-owned file -- its own, or in legends.json -- with a static path
  that use_scratch_files() redirects, from its first commit.
- **The trader buys books** -- he likes to read; a read book still sells.
  **And he LEARNS from them (Brad):** every help book sold to him adds its
  tips to what he says, as his own -- he did read it. Kept across runs with
  the journal, so the trader grows wiser the more you have given him.

**The UI review -- BUILT on branch `ui-review` (2026-10-01), Brad to play,
review and merge.** The canvas: https://claude.ai/artifact/NHoE8HfUWP4QZrPiGH4Aae
Brad's one condition: nothing may overflow or wrap by accident -- so every
new element is laid out by measurement and the quick suite runs the real
strings against the real widths (every bestiary name, every footing x torch
x poison combination, the whole item catalogue, the widest pad button).
Built, one commit each: sidebar condition chips (the brazier's flame and the
ground's own glyph where words were too long -- Brad: symbols shorten), the
IN SIGHT list in the look block's place, the marked ally's two lines; the
log's coloured rule and danger wash; HERE keycaps and the status chip; the
minimap legend and the help button; the shorter 3D hint; the pack's detail
pane with the comparison against what is worn; UI_DIM lifted to 5.1:1.
Two departures from the canvas, both deliberate: the minimap cannot grow (96
squares at 2 px is the panel's width) so it gained a legend instead; an
ally's hp stays a NUMBER, not a bar -- sidebar.gd's own comment argues a bar
means "this refills" and an ally never heals.

**The screens review -- BUILT on branch `screens-review` (2026-10-01), Brad
to play, review and merge.** The canvas:
https://claude.ai/artifact/MapNxUKQ8Hq1NFV2GajU4N
Same rule as the UI review: every new string measured in the quick suite.
- A shared `Keycap` (src/ui/keycap.gd) draws a key as a key through
  PadGlyphs; the HERE box, legend, pause menu and controller screen use it.
- Legend: ground trimmed to what has something to say (floor, walls, rock,
  pillars, stalagmite out; purple and red fungus IN -- the list had never
  listed them); marks gain the spore rings, the risen and the corrupted;
  carry gains gems, the ring, the shovel and food; unknown shrines "not yet
  learned"; keys in two groups as caps, keyboard-only keys dim on a pad;
  ONE movement diagram that cycles vi / numpad / arrows (Brad's idea), held
  on "still". The panel is proven to fit the window -- it was one line over.
- Pause menu: who and where beside the title; caps on a keyboard; on a pad
  no letters, the first row chosen, a pick/back hint line (panel +18px).
- Controller: one "move: left stick" row while the moves are unbound; caps
  with the button's picture and name; dashed "not bound"; cap footers
  (panel +12px; the overflow guard's footer sum follows).
Not done, by choice: WASD is not a movement layout (w swaps weapons), so
the cycle is three layouts, not four.

**The 3D look -- BUILT on branch `look-3d` (2026-10-01), Brad to play on
both tiers and merge.** The canvas: https://claude.ai/artifact/ShcuL5rvjdoAoBCPcE61Pm
The pictures stay; the surfaces and the light change. Built:
- The surface shader is LIT now: the sim's light map goes out as emission at
  MAP_WEIGHT (what is seen, remembered, and how far light reaches stays the
  sim's), and engine lights add direction, masked by `seen` in light() so a
  remembered wall is never lit by a fire out of sight. Relief: the pattern's
  swell, pits and joints tilt the normal, so grooves catch the light.
- OmniLight3D on the sim's own sources (the torch follows the drawn player;
  braziers, fungi), nearest first, LIGHT_CAP 8 on the web (Compatibility
  lights a mesh with 8 and every wall is one mesh), SHADOW_CAP 4 shadows.
- Dark at the foot of every wall: baked gradient strips (one MultiMesh).
- Embers off the nearest lit braziers (CPUParticles3D), not on "still".
- The last pass: vignette and grain on a ColorRect reading the screen
  (hint_screen_texture -- a ColorRect's own TEXTURE is a white pixel, which
  the first version painted the whole view with).
- Brad's two tiers from one project: project.godot runs Forward+ on a PC,
  Compatibility on the web and mobile, with fallback_to_opengl3; the view
  decides `rich` from the renderer actually running (and never headless).
  Rich adds: glow (Compatibility's glow lifted the whole backdrop to grey --
  measured -- so the web keeps its halo quads), SSAO, soft shadows, a
  FogVolume per purple fungus for a volumetric miasma over the flat quad.
- tools/probes/screenshot_look.gd renders the room on either renderer with
  the screen locked (--rendering-method gl_compatibility | forward_plus).
Not done, by choice: creatures stay icon billboards; no new texture files
(the relief is procedural); no SDFGI (a setting later, if wanted).

**The overhead view -- BUILT (2026-10-01), uncommitted, Brad to play.** His
ask: "a view that is still the 3D diorama, but the camera sits top-down, we
keep the same directional camera movement... we are just swapping the 3D
view's camera." Built as a third view on Q, which now CYCLES classic -> 3D ->
3D overhead -> classic (one button reaches all three on a pad; d-pad up is
the same key). Saved as [view] overhead beside diorama/follow, so you come
back to the view you left; the title's "view" row shows which.
- CAMERA_PITCH_OVERHEAD_DEG 80: nearly straight down, a sliver of every
  wall's lit face left showing so a room still reads as a place. Same rig,
  same yaw, same turn keys and follow camera; _place_camera sets the pitch
  in the RIG'S frame (look_at aims at the WORLD origin, and the rig has
  moved by the time the view changes -- the first render was black).
- Cards from above: a billboard at this pitch lies all but flat, so each is
  CENTRED on its cell like a classic glyph, and hung above WALL_HEIGHT
  (overhead_lift): a wall in the cell in front rises towards the camera
  and over the near part of this cell on screen, and would cut a card on
  the floor off. The lift is straight up, so turning the camera does not
  move the items placed at the last rebuild; what the lift does to the
  picture is taken back in the label's pixel offset. Marks sit half a card
  up. Measured in the quick suite: every card within 0.01 px of its cell.
- The strip names the view and what Q gives next; the keys list, the pad
  layout and the legend say "classic / 3D / overhead".
- screenshot_look.gd now takes an overhead shot after the angled one.
