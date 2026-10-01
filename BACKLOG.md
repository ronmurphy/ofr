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
5. **Pits as escape.** A fleeing monster lit by the player's torch several
   turns running is being chased; then a pit is an escape, not a no-go. It
   lands on the next floor wounded by the fall, awake, hunting, with a
   revenge bonus for the floor and more XP. Carried down on a "fell from
   above" list like following allies; saved with the run. Messages: "The
   kobold leaps into the pit!"; the trader: "Something fell in from above."
   Also cures fleeing monsters dying in room corners.
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
   4. **Gem of frost -> THE FROZEN ROOM (Brad's design).** Thrown into a room
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
   5. **Gem of the crag -> fill a pit.** Stone into the hole: it becomes
      floor. Closes a fleeing monster's escape (strand 5) or makes a path.
   6. **Gem of returning -> recall.** Crushed at a brazier it marks it; a
      second crushed anywhere steps you back. Two gems: an escape kept rare.
   7. **Gem of the bulwark -> a barricaded door.** Monsters cannot open it for
      a while; bears still smash it. Shuts a chase behind you.
   8. **Gem of the road -> the way out.** Shows the route to the stairs on the
      minimap -- the route-choosing play the red brought on.
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

**The forager's satchel (unique; Brad and Claude, 2026-09-29).** Absorbs the
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
