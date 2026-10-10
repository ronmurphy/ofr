class_name Entity
extends RefCounted

## Anything that occupies a cell. The player is not a special case -- it is an
## Entity with `is_player` set. That is deliberate: when a party arrives later,
## it is four of these in a list rather than a new concept.

## RISEN is APPENDED (factions are saved as ints): the dead the red fungus
## raised. Hostile to everything with a side -- you, your allies and the
## monsters alike -- which is what lets a red room snowball.
## WILD is APPENDED (factions are saved as ints). An animal: it acts and lives
## its own life, and is nobody's enemy until it is struck -- see `provoked`.
## NEUTRAL could not serve, because NEUTRAL means INERT: the trader takes no
## turn at all and nothing can be its enemy, which is right for a shopkeeper
## and wrong for a bear (Brad, 2026-10-04; built the same day).
enum Faction { PLAYER, MONSTER, NEUTRAL, RISEN, WILD }

## A WILD thing that has been struck by your side. From then on it is your
## enemy for good: it hunts, it is counted hostile, it stops your rest. Set
## in GameState._attack; saved.
var provoked := false
## The last thing that struck a WILD creature, whoever's side it was on: a
## forager flees it above all else, anything else fights it back (Brad,
## 2026-10-04). A reference, not saved: a fright does not survive a reload,
## where a grudge against your side does (`provoked`). Cleared by nothing --
## a dead grudge is simply ignored.
var grudge: Entity = null

## Whether these two would fight, which is NOT the same question as "is one of
## them the player".
##
## Three places in the game asked `not e.is_player` and meant "is it an enemy":
## the shooting target list, the visible-monster list that stops click-travel,
## and the pack AI's nerve check. They agreed only because the player was the
## only thing on the player's side. The first ally would have appeared in the
## firing cycle, stopped travel every turn just by standing there, and made
## nearby goblins braver by counting as one of THEIR allies -- three different
## symptoms of one wrong question.
##
## NEUTRAL fights nobody. Nothing is neutral yet; it is here because the enum
## already named it and a rabbit that minds its own business is the obvious
## first customer.
func hostile_to(other: Entity) -> bool:
	if other == null or other == self:
		return false
	if faction == Faction.NEUTRAL or other.faction == Faction.NEUTRAL:
		return false
	# A WILD creature: nothing to a monster, which hunts you and not the
	# rabbits (the food web is a later step); prey to the risen, as all the
	# living are; and your enemy only once your side has struck it. Two wild
	# things never fight each other yet.
	if faction == Faction.WILD or other.faction == Faction.WILD:
		var beast := self if faction == Faction.WILD else other
		var them := other if faction == Faction.WILD else self
		# What struck it is its enemy, whatever it is -- and that is how two
		# wild things come to fight (a bear and the wolf that bit it).
		if beast.grudge == them or (them.grudge == beast and them.alive):
			return true
		match them.faction:
			Faction.WILD, Faction.MONSTER:
				return false
			Faction.RISEN:
				return true
			_:
				return beast.provoked
	return faction != other.faction

## Hungry enough to hunt (see `hunger`).
func is_hungry() -> bool:
	return eats and hunger >= HUNGRY_AT

func is_wild() -> bool:
	return faction == Faction.WILD

## Three states rather than two. A binary asleep/awake makes stealth feel
## arbitrary -- you are either invisible or caught, with no warning. The middle
## state is the tell that lets a player back off before it is too late.
## PATROL is APPENDED, never inserted. `alertness` is saved as a plain integer,
## so putting a new value in the middle would silently re-read every monster in
## every existing save as a different state -- the same reason Item.Kind says
## "GEM is last on purpose".
##
## And it is a fourth STATE rather than a fifth `ai` kind, because the thing it
## changes is whether the creature is interested in you, not how it fights. A
## patroller that spots you becomes AWAKE and hunts with whatever `ai` it
## already had; a patroller that loses you goes back to its rounds instead of
## lying down. "Awake" in this game has always meant "coming for you", and this
## is the state that was missing: busy, but not with you.
enum Alert { ASLEEP, SUSPICIOUS, AWAKE, PATROL }

## WHAT IT IS DOING, which is a different question from what it knows.
##
## `alertness` above answers "what does this creature know about the player".
## This answers "what is it busy with". They are orthogonal, and conflating
## them is what made the dungeon a diorama: ASLEEP meant both "has not noticed
## you" (the stealth system) and "is not doing anything" (the world), so
## nothing could be busy without also being alert.
##
## PATROL was bolted onto `Alert` because that was the only axis there was, and
## foragers needed a special case in `_take_ai_turn` checking their `ai` kind.
## Both were patches over this missing concept. With two axes a bear can hunt a
## rabbit while entirely unaware of you, and a guard that loses your trail goes
## back to its round automatically -- its ACTIVITY never changed, only what it
## knew.
##
## SLEEPING is first so it is the zero value: anything that does not say
## otherwise does nothing, which is what every monster did before this existed.
##
## APPEND new activities, never insert -- this saves as a plain integer. There
## is no IDLE here on purpose: it was written, set by nothing and read by
## nothing, which this project has twice found to be worse than a missing
## feature. Wandering will add it, and adding it then is free.
enum Activity { SLEEPING, PATROLLING, FEEDING }

## HOW THIS THING GETS THROUGH A SHUT DOOR.
##
## Doors used to be walkable by everything, so a rabbit strolled through a
## closed one and only the player had to stop and open it -- an obstacle that
## existed for exactly one creature in the dungeon.
##
## Measured before choosing the rule: every room in this dungeon generates with
## its doors SHUT (190 of 190 on depth 1), so making a closed door solid to
## animals would seal roughly half of every species into its birth room for the
## whole run -- median reach 12-27% of the floor. That would have quietly
## undone foraging and wandering. Hence three behaviours rather than two.
##
## SQUEEZES is the default and the fallback, because it is the one that can
## never strand anything.
enum Door { SQUEEZES, OPENS, SHOULDERS }

## Phasing first: something that walks through stone does not care about a door.
## Then size, then hands.
##
## `patrols` stands in for "is a biped" here, and today the two sets are exactly
## the same eleven creatures. If a non-biped is ever given a beat, this wants
## its own flag rather than a second meaning bolted onto that one.
func door_style() -> int:
	if phasing:
		return Door.SQUEEZES
	if heavy:
		return Door.SHOULDERS
	if patrols:
		return Door.OPENS
	return Door.SQUEEZES

var activity: int = Activity.SLEEPING

## How an ally carries itself. Meaningless on anything hostile.
##
## TWO states, not a cycle of many. The player is setting a posture, not
## driving a second character -- the design rule is that they control the
## timing and nothing else -- and a toggle can be read from one sidebar line
## and learned in one press. The obvious temptation is to cycle the existing
## `ai` kinds instead; they are monster personalities built around hunting the
## player (`forager` eats fungus and flees you, `banshee` phases through walls)
## and would be nonsense worn by something on your side.
enum Stance { LOOSE, HEEL }

var stance: int = Stance.LOOSE

## How long it will keep going towards where it last saw you before giving up.
##
## Ten by default, which is right for "I lost sight of him round that corner".
## It is a FIELD rather than a constant because a summons is a different thing
## from a glimpse: the vigil shrine rings across the whole floor, and measured,
## only 3-7% of what it woke ever arrived -- the median monster starts 31-38
## cells away and a ten-turn memory carries it about ten of them. Something
## called from across the dungeon has to be willing to walk across the dungeon.
const DEFAULT_PURSUIT := 10
var pursue_turns: int = DEFAULT_PURSUIT

## Turns left of having watched something bigger than it die.
##
## Not a damage penalty -- a shift in where its nerve breaks. See
## `GameState._update_morale`: confidence and fear both move the threshold the
## creature already had, so nothing new enters the combat path and no monster
## ends up worth more or less to face than the floor paid for it.
var shaken: int = 0

## Whether this thing picks up what it finds and puts it on.
##
## NOT an Activity, deliberately. Scavenging is opportunistic -- you do not
## take it up as an occupation, you notice a sword on your way somewhere -- so
## a guard can walk its round AND stoop for a blade, which a single activity
## field could never express. It is a trait, like `patrols`.
var scavenges := false
## It hunts the wild for food while it is not hunting you, and eats what it
## kills (GameState._hunt). From the bestiary; saved.
var eats := false
## Its blows leave ACID that goes on eating for a few turns (the slime,
## 2026-10-05). From the bestiary; saved.
var acid := false
## Turns of acid left on a creature: ACID_HURT a turn, washed off in water.
## Not the miasma's poison, which rabbits ignore and acid does not. Saved.
var acid_turns := 0

## Whether this thing walks a beat. Separate from `alertness`, which is only
## where it is RIGHT NOW: without a standing flag, a guard that chased you and
## lost you would fall asleep on the spot and never patrol again.
var patrols := false
## Which post on the circuit it is walking towards.
var patrol_at: int = 0
## Its own BEAT: the stretch of the round from post `beat_lo` to `beat_hi`,
## walked back and forth (`patrol_dir`, +1 or -1). hi <= lo means no beat --
## the whole round, as before 2026-10-07 (a save from before then). Saved.
var beat_lo: int = 0
var beat_hi: int = 0
var patrol_dir: int = 1

## TRAFFIC. The cell this creature last meant to step into, and the turn it
## meant to. Written by every pathfinding step, moved or blocked, so a friend
## that bumps into it can ask "where are you going?" -- toward me (head-on: we
## swap), somewhere else (a queue: I wait), or nowhere lately (idle: you give
## way). See GameState._traffic. Saved, so a jam untangles the same way after
## a reload as it would have without one.
var want := Vector2i(-1, -1)
var want_turn: int = -1

## The open door this creature has just stepped off, to shut on its next turn
## if nobody is following. Only ever set for a door-OPENER that is not hunting.
## Saved with `want`, for the same reason.
var shut_behind := Vector2i(-1, -1)

var name: String = "thing"
var appearance: StringName = &"unknown"
var x: int
var y: int
var blocks: bool = true
var is_player: bool = false
var faction: int = Faction.MONSTER

var hp: int = 1
var max_hp: int = 1
var power: int = 1
var defense: int = 0

## Energy economy: an actor gains `speed` per tick and spends
## Scheduler.ACTION_COST to act. speed 100 is the human baseline; 150 is a
## dog, 50 is a zombie. Building this in from the start rather than bolting it
## on later is the difference between a half hour and a painful refactor.
var speed: int = 100
var energy: int = 0

## Carried items. Lives on Entity rather than on the player specifically, so
## lootable corpses later are a read of this field rather than a new system.
var inventory: Array = []
const INVENTORY_MAX := 20
## The slots gear can be worn in (Item.Slot: weapon, armour, offhand). Worn
## gear hangs on you, not in the pack, so a full pack and three worn things
## need INVENTORY_MAX + WORN_SLOTS letters between them.
const WORN_SLOTS := 3

## Item.Slot -> Item. Equipped things stay in `inventory` and are merely
## flagged here, which is how most roguelikes do it and saves inventing a
## second screen to move things between two lists.
var equipped: Dictionary = {}

## How this actor decides what to do. See GameState._take_ai_turn.
##   hunter  - walks at you and hits you
##   erratic - moves unpredictably; hard to disengage from
##   ranged  - attacks along a clear line, and backs off when crowded
##   pack    - bold with allies nearby, hesitant alone
## This game's challenge rating, and what a kill is worth in XP.
var threat: int = 0

var level: int = 1
var xp: int = 0

var ai: StringName = &"none"

## Attacks beyond 1 cell need a clear line of sight, which is what turns a
## pillar from decoration into cover.
var attack_range: int = 1

## How close a ranged attacker lets you get before it gives ground.
##
## One for the slinger and the dragon, which stand and shoot until you are
## actually on top of them. Higher for something that fights at arm's length by
## choice -- and note that a stand-off is only survivable for the PLAYER if the
## thing doing it is slower than they are, or it simply never gets caught.
var standoff: int = 1

## How far this can blink away, and how long before it can do it again. Zero
## range means it cannot -- only the arch lich does, today.
##
## The cooldown is what keeps it a fight rather than a chore: with no cooldown
## a teleporter can never be cornered, so it does nothing but chip you forever,
## which is tedious rather than difficult.
var blink_range: int = 0
var blink_cool: int = 0

## Walks through stone. Nothing else does, and it is half of what makes the
## banshee unanswerable by hiding -- you cannot put a wall between you and it.
var phasing := false
## THE SPIDER (2026-10-09): it walks the walls, but ONLY to flee -- the
## banshee's phasing step, used to get away (GameState._ai_flee). Saved.
var climbs := false
## Turns of poison its bite leaves (`poisoned`, the miasma's own): the
## spider's 3. Zero for everything else. Saved.
var venom: int = 0
## Spits webs (the spider, night 2): a ranged shot that spins a WEB tile under
## its target (GameState._shoot_web). `web_cool` counts the turns until the
## next. Both saved.
var webs := false
var web_cool: int = 0
## How many cells this creature's melee hit shoves its target back. 0 for
## everything that fights by standing still and swinging.
var knockback := 0
## Follows its own knockback into the ground it just cleared, so the shove buys
## the target no distance at all. Meaningless without `knockback`.
var charges := false
## Damage types this shrugs off, and the one that finds it. Lists rather than
## single values: a skeleton has nothing to cut AND nothing to puncture, and an
## arrow goes between the ribs.
##
## Deliberately NOT keyed on `unliving`. A golem resists a sword because it is
## made of rock, a skeleton because there is no flesh on it -- same effect,
## different reason, and a future creature could have one without the other.
var resists: Array[StringName] = []
var weak_to: Array[StringName] = []

## Dead, or never alive in the way that matters. Skeletons, wights, shadows,
## banshees and the lich.
##
## Three separate rules want this and none of them is about combat: a wolf's
## howl wakes the LIVING, a rat disguise does not fool the dead, and a dropped
## fungus offends them rather than drawing them. The stone golem is
## deliberately NOT one -- it was never alive, but it is not a corpse either,
## and every rule here is about things that used to breathe.
var unliving := false

## Turns of frost left on it. Slows its movement, not its attacks -- a chilled
## thing still swings as hard, it just cannot close or flee as fast.
var chilled := 0
## Turns frozen solid (the gem of frost's room): it neither acts nor hears
## until this runs out, and can be hit without hitting back. The PLAYER'S
## turns, whatever its speed (GameState._thaw_rooms).
var frozen := 0

## A low-tier creature the climb has made worse. Cosmetically a colour, but the
## flag is what the renderer and the bestiary key on -- and what stops a
## corrupted thing being mistaken for its own base entry in a save.
var corrupted := false

## Came up out of a grave wearing a dead run's gear. Its kit is the player's
## own, so it hands ALL of it back rather than rolling per item -- see
## GameState._drop_loot.
var risen := false
## Finds you without seeing you, and without caring how dark it is. The other
## half: dousing the torch is the game's main defence, and this ignores it.
var senses := false
## How far its cry carries, and how long until the next one. Zero radius means
## it has no cry. The cooldown is what makes it a rhythm you can race rather
## than a wall of noise.
var wail_radius: int = 0
var wail_cool: int = 0

## Turns this actor is occupied and cannot act. The rabbit's mouthful is the
## only user today, and it is the whole reason the rabbit is catchable: a thing
## faster than you that never stops is not a monster, it is scenery.
var busy: int = 0
## Turns left at the water's edge, head down (GameState._drinks); below
## zero, thirst -- on its way to the water. A wild thing's; saved, so a bear
## mid-drink is still drinking after a reload.
var drinking: int = 0
## A bear asleep in its den (Brad, 2026-10-07: they hibernate). It never
## wakes on its own; noise wakes it -- the den's bones above all, which is
## the den's whole design -- and so does anything within two steps. Up, it
## watches from the den and settles back to sleep, unless it comes out after
## game or after you; out, it is an ordinary animal again
## (GameState._keeps_to_the_den). Saved.
var denned := false
## HUNGER (Brad, 2026-10-07): turns since it last ate, for anything that
## `eats`. At HUNGRY_AT it hunts game and goes to meat; below, it lets both
## be. Hungry by default, so a creature made outside a floor build (a test,
## an old save) behaves as every hunter did before hunger existed; a floor
## deals out real appetites (GameState._set_appetites). Saved.
const HUNGRY_AT := 200
var hunger: int = HUNGRY_AT
## Turns a woken den bear has had nothing near it; at DEN_SETTLE_TURNS it
## goes back to sleep in the den (Brad, 2026-10-07). Saved.
var den_quiet: int = 0
## How much of the floor's fungus this has eaten. Drives both the meat it
## leaves and, at RABBIT_TURNS, what it becomes.
var meal: int = 0

## Runs once hp falls to this fraction of max. 0.0 never breaks -- undead and
## mindless things should not.
var flee_below: float = 0.0
var fleeing: bool = false
## Turns running it has fled in the player's light and sight (strand 5): at
## GameState.CHASED_TURNS a pit beside it is an escape, not a hole.
var chased := 0
## It leapt into a pit to get away and landed a floor down, wounded and
## angry: a point of power and half again the experience, for the floor.
var vengeful := false

## Hit points recovered each turn. A regenerating monster cannot be chipped
## down and then escaped from -- you either commit to the kill or you have
## wasted the damage, which makes disengaging a real decision rather than a
## free one.
var regen: int = 0

## Difficult ground is nothing to something that never touches it.
var flying := false
## And it is worse for something that sinks. Heavy things suffer most in mud,
## which is what makes mud a tool rather than only a hazard -- back across it
## and the ogre falls behind while you do not.
var heavy := false

## Monsters start asleep. Until this pass everything was omnisciently aware the
## instant the player could see it, which handed the initiative to whatever was
## in the room.
var alertness: int = Alert.ASLEEP

## RELOADING, for the kobold slinger -- the single most common killer in the
## morgue (8 of Brad's 22 deaths, all on floors 1-2; Gabe and David complained
## of it too). After a shot it spends turns fetching another stone:
##   STEADY on the first floor slingers appear -- always one turn, so it fires
##          every other turn: a teaching floor;
##   RANDOM everywhere else -- 0, 1 or 2 turns (GameState._reload_after_shot).
## Appended enum; saved as an int.
enum Reload { NONE, STEADY, RANDOM }

## WHICH WAY IT FACES, one of the eight steps. Set by every step and every
## blow. Added for Gabe's follow camera (2026-09-28) -- in that mode forward is
## always up the screen -- and it is also the piece the combat update needs
## for flanking and blows from behind.
var facing := Vector2i(0, -1)

## THE SPORES IT CARRIES: &"" none, &"purple" or &"red" (red wins -- it is the
## worse). Walking on the wrong fungus marks a creature; a corrupted one is
## born purple (Brad's lore: the climb's corrupted crossed purple and were
## changed). Marked creatures leave trails, wear their colour as an outline,
## and die into fungus: purple rots into purple, red is claimed (strand 4
## raises it). Saved.
var spores: StringName = &""

## Walked through the wrong fungus: take its spores. Red is never downgraded.
func take_spores(colour: StringName) -> void:
	if spores != &"red":
		spores = colour
## Knows better than to walk through the wrong fungus: routes round it (the
## careful grid). The smart kinds -- dragons, wizards, liches. Everything else
## walks through and is hurt by it. From the bestiary; saved.
var careful := false
## Shoots with magic or fire (dragons, wizards, liches): a shot LIGHTS its own
## square, so you see what fired and where. From the bestiary; saved.
var casts := false
## Poisoned by the purple miasma: turns of 1 hp still to come. Saved.
var poisoned := 0
## The turn its last flare lasts until; -1 for none. Saved.
var flare_until := -1
## Raised by the red fungus (strand 4). Its second death is its last: its body
## never rises again, it drops nothing (its gear dropped the first time) and
## the shovel will not have it. Saved.
var fungal := false
## Has had its second life, from either claimant: the shovel or the red. Every
## body gets at most one (Brad, 2026-09-30). The red will not raise it again,
## and it drops nothing when it falls -- its gear dropped the first time, so
## anything it carries now is a copy. NOT set on a grave's bone ally, whose
## kit is the only copy there is (see GameState._drop_loot). Saved; a save
## from before this reads a red risen as raised.
var raised := false
## A bone ally the player has been told carries the red, so the warning is
## said once. Saved.
var red_warned := false
## Where a risen body may walk: the room it rose in, or a square round the
## spot in caves and corridors. An empty rect means free -- the gong's call.
## Saved.
var leash := Rect2i()
## Where a risen body last heard something, or (-1, -1). It goes there and
## finds what is there -- that is how a ring-rat is caught. Saved.
var heard := Vector2i(-1, -1)

## The eight steps clockwise from north, on a screen where y grows downward.
const CLOCKWISE: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0),
	Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1)]

## `step` turned `eighths` of a circle clockwise (negative: anticlockwise).
static func turned(step: Vector2i, eighths: int) -> Vector2i:
	var at := CLOCKWISE.find(step)
	if at < 0:
		return step
	return CLOCKWISE[posmod(at + eighths, 8)]
var reload_style: int = Reload.NONE
## Turns still to spend before the next shot.
var reload_left := 0
var notice_range: int = 8
var last_seen := Vector2i(-1, -1)
var lost_turns: int = 0
var calm_turns: int = 0
## Turns during which this cannot notice the player at all. Without it the
## shrine of the quiet buys about two turns -- everything simply re-notices the
## lit figure standing next to it, and the shrine reads as broken.
var notice_block: int = 0
var light: LightSource = null

var alive: bool = true

func _init(n: String, app: StringName, px: int, py: int) -> void:
	name = n
	appearance = app
	x = px
	y = py

## Base power/defense plus whatever is worn. Combat reads only these, so a
## stat system later slots in here rather than at every call site.
func total_power() -> int:
	var v := power
	for slot in equipped:
		v += equipped[slot].power_bonus
	return v

## Effective reach: innate, or whatever is being wielded, whichever is longer.
func total_range() -> int:
	var r := attack_range
	for slot in equipped:
		r = maxi(r, equipped[slot].range_bonus)
	return r

func total_defense() -> int:
	var v := defense
	for slot in equipped:
		v += equipped[slot].defense_bonus
	return v + travel_bonus()

## THE ROAD: new rooms entered on this floor, counted by GameState and reset on
## every new floor. Only the player enters rooms, so on anything else it stays 0
## -- a monster in travel armour is simply carrying it to you.
var travel_rooms: int = 0
const TRAVEL_ROOMS_PER := 4
const TRAVEL_MAX := 3

## What a gem of the road in the body armour adds to defense right now.
## Defense, not block -- see `gem_travel` in the catalogue for why.
func travel_bonus() -> int:
	var armour: Variant = equipped.get(Item.Slot.ARMOR, null)
	if armour == null or armour.element != &"travel":
		return 0
	return mini(TRAVEL_MAX, travel_rooms / TRAVEL_ROOMS_PER)

## What the shield hand turns aside, on top of defense and PAST the damage
## floor. Zero for everybody without a blocking stone bound, which is almost
## everybody.
##
## Lives on Entity rather than on the player, because monsters roll shields out
## of the same catalogue and `_maybe_enchant` can put the stone on one. Brad's
## standing rule: if the player can have something, so can the monsters.
func block_amount() -> int:
	return offhand_tier(&"block")

## The shield hand's tier, if the shield carries this particular stone.
##
## One question for all three shield gems, because they differ only in WHAT
## they do with the tier -- blocking subtracts it, reflect returns it, bash
## adds twice it. Three near-identical lookups is how three of them stop
## agreeing about what counts as a shield.
func offhand_tier(el: StringName) -> int:
	var off: Variant = equipped.get(Item.Slot.OFFHAND, null)
	if off == null or off.element != el:
		return 0
	return off.defense_bonus

## WHAT THE PACK HOLDS against INVENTORY_MAX: everything carried that is not
## worn (Brad, 2026-10-02). Worn gear stays in `inventory` -- every index,
## letter, swap and save works as before -- it simply stops counting. Before
## this a sword, a shield and a coat ate three of the twenty, and the pack
## was the tightest resource in the game.
func pack_count() -> int:
	var n := 0
	for it in inventory:
		if not is_equipped(it):
			n += 1
	return n

func is_equipped(item) -> bool:
	for slot in equipped:
		if equipped[slot] == item:
			return true
	return false

# ------------------------------------------------------------ persistence ---

## Equipped gear is stored as indices into `inventory`, because the two hold
## the SAME objects -- writing them out twice would restore a monster wearing a
## copy of its own armour, and dropping it would leave a duplicate behind.
func to_dict() -> Dictionary:
	var pack := []
	for it in inventory:
		pack.append(it.to_dict())
	var worn := {}
	for slot in equipped:
		var idx := inventory.find(equipped[slot])
		if idx >= 0:
			worn[str(slot)] = idx
	return {
		"name": name, "app": String(appearance), "x": x, "y": y,
		"blocks": blocks, "is_player": is_player, "faction": faction, "provoked": provoked,
		"hp": hp, "max_hp": max_hp, "power": power, "defense": defense,
		"speed": speed, "energy": energy, "threat": threat,
		"level": level, "xp": xp, "ai": String(ai),
		"attack_range": attack_range, "standoff": standoff,
		"blink_range": blink_range, "blink_cool": blink_cool,
		"phasing": phasing, "senses": senses, "knockback": knockback,
		"climbs": climbs, "venom": venom, "webs": webs, "web_cool": web_cool,
		"charges": charges, "risen": risen, "corrupted": corrupted,
		"unliving": unliving,
		"resists": resists, "weak_to": weak_to,
		"chilled": chilled, "frozen": frozen, "acid": acid, "acid_turns": acid_turns,
		"wail_radius": wail_radius, "wail_cool": wail_cool,
		"busy": busy, "meal": meal, "drinking": drinking, "denned": denned, "den_quiet": den_quiet, "hunger": hunger,
		"flee_below": flee_below,
		"fleeing": fleeing, "regen": regen, "alertness": alertness,
		"notice_range": notice_range, "last_seen": [last_seen.x, last_seen.y],
		"lost_turns": lost_turns, "calm_turns": calm_turns,
		"notice_block": notice_block, "alive": alive,
		"stance": stance,
		"reload_style": reload_style, "reload_left": reload_left,
		"facing": [facing.x, facing.y],
		"spores": String(spores), "careful": careful,
		"casts": casts, "flare_until": flare_until, "poisoned": poisoned,
		"fungal": fungal, "raised": raised, "red_warned": red_warned,
		"chased": chased, "vengeful": vengeful,
		"heard": [heard.x, heard.y],
		"leash": [leash.position.x, leash.position.y, leash.size.x, leash.size.y],
		"patrols": patrols, "patrol_at": patrol_at,
		"beat_lo": beat_lo, "beat_hi": beat_hi, "patrol_dir": patrol_dir,
		"scavenges": scavenges, "eats": eats, "shaken": shaken,
		"pursue_turns": pursue_turns,
		"want": [want.x, want.y], "want_turn": want_turn,
		"shut_behind": [shut_behind.x, shut_behind.y],
		"travel_rooms": travel_rooms,
		"activity": activity,
		"flying": flying, "heavy": heavy,
		"inventory": pack, "equipped": worn,
	}

static func from_dict(d: Dictionary) -> Entity:
	var e := Entity.new(d.get("name", "thing"),
		StringName(d.get("app", "unknown")), int(d.get("x", 0)), int(d.get("y", 0)))
	e.blocks = d.get("blocks", true)
	e.is_player = d.get("is_player", false)
	e.faction = int(d.get("faction", Faction.MONSTER))
	e.provoked = bool(d.get("provoked", false))
	e.hp = int(d.get("hp", 1))
	e.max_hp = int(d.get("max_hp", 1))
	e.power = int(d.get("power", 1))
	e.defense = int(d.get("defense", 0))
	e.speed = int(d.get("speed", 100))
	e.energy = int(d.get("energy", 0))
	e.threat = int(d.get("threat", 0))
	e.level = int(d.get("level", 1))
	e.xp = int(d.get("xp", 0))
	e.ai = StringName(d.get("ai", "none"))
	e.attack_range = int(d.get("attack_range", 1))
	e.standoff = int(d.get("standoff", 1))
	e.blink_range = int(d.get("blink_range", 0))
	e.blink_cool = int(d.get("blink_cool", 0))
	e.phasing = bool(d.get("phasing", false))
	e.climbs = bool(d.get("climbs", false))
	e.venom = int(d.get("venom", 0))
	e.webs = bool(d.get("webs", false))
	e.web_cool = int(d.get("web_cool", 0))
	e.senses = bool(d.get("senses", false))
	e.wail_radius = int(d.get("wail_radius", 0))
	e.wail_cool = int(d.get("wail_cool", 0))
	e.busy = int(d.get("busy", 0))
	e.drinking = int(d.get("drinking", 0))
	e.denned = bool(d.get("denned", false))
	e.den_quiet = int(d.get("den_quiet", 0))
	e.hunger = int(d.get("hunger", HUNGRY_AT))
	e.meal = int(d.get("meal", 0))
	e.flee_below = float(d.get("flee_below", 0.0))
	e.fleeing = d.get("fleeing", false)
	e.regen = int(d.get("regen", 0))
	e.alertness = int(d.get("alertness", Alert.ASLEEP))
	e.notice_range = int(d.get("notice_range", 8))
	var seen: Array = d.get("last_seen", [-1, -1])
	e.last_seen = Vector2i(int(seen[0]), int(seen[1]))
	e.lost_turns = int(d.get("lost_turns", 0))
	e.calm_turns = int(d.get("calm_turns", 0))
	e.notice_block = int(d.get("notice_block", 0))
	e.stance = int(d.get("stance", Stance.LOOSE))
	e.reload_style = int(d.get("reload_style", Reload.NONE))
	e.reload_left = int(d.get("reload_left", 0))
	var f: Array = d.get("facing", [0, -1])
	e.facing = Vector2i(int(f[0]), int(f[1]))
	e.spores = StringName(d.get("spores", ""))
	# A save from before purple could mark: its one mark was red.
	if bool(d.get("spore_marked", false)) and e.spores == &"":
		e.spores = &"red"
	e.careful = bool(d.get("careful", false))
	e.casts = bool(d.get("casts", false))
	e.poisoned = int(d.get("poisoned", 0))
	e.flare_until = int(d.get("flare_until", -1))
	e.fungal = bool(d.get("fungal", false))
	e.raised = bool(d.get("raised", e.fungal))
	e.chased = int(d.get("chased", 0))
	e.vengeful = bool(d.get("vengeful", false))
	e.red_warned = bool(d.get("red_warned", false))
	var h: Array = d.get("heard", [-1, -1])
	e.heard = Vector2i(int(h[0]), int(h[1]))
	var l: Array = d.get("leash", [0, 0, 0, 0])
	e.leash = Rect2i(int(l[0]), int(l[1]), int(l[2]), int(l[3]))
	e.patrols = bool(d.get("patrols", false))
	e.scavenges = bool(d.get("scavenges", false))
	e.eats = bool(d.get("eats", false))
	e.shaken = int(d.get("shaken", 0))
	e.pursue_turns = int(d.get("pursue_turns", DEFAULT_PURSUIT))
	var wanted: Array = d.get("want", [-1, -1])
	e.want = Vector2i(int(wanted[0]), int(wanted[1]))
	e.want_turn = int(d.get("want_turn", -1))
	var shut: Array = d.get("shut_behind", [-1, -1])
	e.shut_behind = Vector2i(int(shut[0]), int(shut[1]))
	e.travel_rooms = int(d.get("travel_rooms", 0))
	e.patrol_at = int(d.get("patrol_at", 0))
	e.beat_lo = int(d.get("beat_lo", 0))
	e.beat_hi = int(d.get("beat_hi", 0))
	e.patrol_dir = int(d.get("patrol_dir", 1))
	# MIGRATION, and it has to be here rather than left to the default.
	#
	# `Alert.PATROL` shipped for one evening as a fourth alertness, so saves
	# exist -- including a suspended run -- holding `alertness: 3` and no
	# `activity` at all. Reading those as a plain ASLEEP monster would stop the
	# guard walking for good, silently. The flag covers the other case: a
	# patroller saved mid-chase was AWAKE, so its alertness says nothing about
	# whether it walks a beat.
	if d.has("activity"):
		e.activity = int(d["activity"])
	elif int(d.get("alertness", Alert.ASLEEP)) == Alert.PATROL or e.patrols:
		e.activity = Activity.PATROLLING
	if e.alertness == Alert.PATROL:
		e.alertness = Alert.ASLEEP
	e.flying = d.get("flying", false)
	e.heavy = d.get("heavy", false)
	e.knockback = int(d.get("knockback", 0))
	e.charges = d.get("charges", false)
	e.risen = d.get("risen", false)
	e.corrupted = d.get("corrupted", false)
	e.unliving = d.get("unliving", false)
	e.resists.clear()
	for r in d.get("resists", []):
		e.resists.append(StringName(r))
	e.weak_to.clear()
	for w in d.get("weak_to", []):
		e.weak_to.append(StringName(w))
	e.chilled = int(d.get("chilled", 0))
	e.frozen = int(d.get("frozen", 0))
	e.acid = bool(d.get("acid", false))
	e.acid_turns = int(d.get("acid_turns", 0))
	e.alive = d.get("alive", true)

	for entry in d.get("inventory", []):
		var it := Item.from_dict(entry)
		if it != null:
			e.inventory.append(it)
	var worn: Dictionary = d.get("equipped", {})
	for slot_key in worn:
		var idx := int(worn[slot_key])
		if idx >= 0 and idx < e.inventory.size():
			e.equipped[int(slot_key)] = e.inventory[idx]
	return e

## Chebyshev distance -- the correct adjacency test on an 8-way grid.
func steps_to(other: Entity) -> int:
	return maxi(absi(x - other.x), absi(y - other.y))

## D&D's word for it: at or below half. A second step at a quarter, because by
## then the question has changed from "can I win this" to "can I finish it
## before it finishes me".
enum Wound { WHOLE, BLOODIED, CRITICAL }

func wound() -> int:
	if hp * 4 <= max_hp:
		return Wound.CRITICAL
	if hp * 2 <= max_hp:
		return Wound.BLOODIED
	return Wound.WHOLE

func is_adjacent(other: Entity) -> bool:
	return steps_to(other) == 1

func take_damage(amount: int) -> void:
	hp = maxi(0, hp - amount)
	if hp == 0:
		alive = false
		blocks = false
