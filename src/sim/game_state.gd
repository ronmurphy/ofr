class_name GameState
extends RefCounted

## The whole simulation. Owns no Godot nodes and knows nothing about drawing.
##
## Everything here can be exercised headless -- see tests/run_tests.gd. That is
## the single most valuable property of this layer: procedural generation and
## combat maths are exactly the things you want to run ten thousand times in a
## loop without a window open.

## The bottom of the dungeon. The amulet waits here and there are no stairs
## down -- the only way on is back the way you came.
const MAX_DEPTH := 10

## A single suspend slot, destroyed the moment it is loaded. That deletion is
## the entire anti-scum mechanism: there is never a point at which a save from
## *before* something went wrong still exists.
## Where the run is written. A `static var`, not a const, so a test suite or a
## screenshot tool can point it somewhere harmless.
##
## It was a const, and the cost of that was a real one: `_test_suspend_round_trip`
## calls clear_suspend() and save_suspend() against whatever this names, so
## every run of the suite deleted the player's actual suspended game. It ran
## dozens of times before anyone noticed, and a run in progress was lost.
##
## Nothing under src/ ever changes these. Only the harnesses do, at startup.
static var SUSPEND_PATH := "user://suspend.save"

## The floor as it was at the moment of death -- a black box, not a save.
##
## Dying leaves nothing behind. The morgue records one line and the suspend
## slot is gone, so a death that felt wrong is unexaminable: "I think a
## patroller killed me" is the most anyone can say afterwards. This writes the
## whole state so `tools/inspect_save.gd` can answer what was actually on the
## floor and what each thing was doing.
##
## OVERWRITTEN each death, deliberately. The interesting one is always the last
## one, and a growing pile of these in a player's directory is litter.
##
## It is NOT a save and must never be loadable as one -- `load_suspend` reads
## SUSPEND_PATH and nothing here changes that. Writing it cannot cost the
## player anything, which is why it is safe to leave switched on in a shipped
## build rather than hidden behind a debug flag.
static var DEATH_PATH := "user://death.save"
## Same reasoning as SUSPEND_PATH. The death tests append real lines to this,
## and 868 of the 869 entries in one player's morgue turned out to be test
## output rather than deaths they had actually died.
static var MORGUE_PATH := "user://morgue.txt"

## The view mode, the effects mode, the volume and whether the trader's
## introduction has been heard. A file the PLAYER owns, so it lives here with
## the other three rather than as a const in each of the four modules that
## write it.
##
## One owner, in sim, because `src/sim` may not reach into `src/render` -- that
## seam is what lets the whole suite run headless. RenderTheme, Effects,
## SoundDeck and TraderTalk all read this.
##
## Restoring after a mutation was tried and is not enough: one test put the
## value back in the wrong PLACE and left the view on ASCII for weeks, another
## put it back in the right place but captured the in-memory DEFAULT instead of
## the player's choice and downgraded his shaders on every run. Both looked
## correct when read. Not writing the file is the only version that cannot be
## got wrong.
static var SETTINGS_PATH := "user://settings.cfg"

## Points both files somewhere the player does not own.
##
## Every headless tool in tests/ must call this before it touches a GameState.
## Three of them had to learn that separately -- the test suite deleted the
## suspend slot on every run, the screenshot tool ate it by instantiating the
## real scene, and the sound audition tool did the same and went unnoticed for
## a week. One named call is harder to forget than two assignments, and it puts
## the reason in one place.
static func use_scratch_files(tag: String) -> void:
	SUSPEND_PATH = "user://scratch_%s_suspend.save" % tag
	MORGUE_PATH = "user://scratch_%s_morgue.txt" % tag
	DEATH_PATH = "user://scratch_%s_death.save" % tag
	# The bestiary is a player-owned record too, and update_vision() writes to
	# it on sight -- so EVERY headless run that builds a level would otherwise
	# append to the real one. Redirected here rather than at each call site,
	# because the call sites are every test and every tool.
	BestiaryLog.use_path("user://scratch_%s_bestiary.txt" % tag)
	# And the settings, which are the player's too.
	#
	# Added after the guard caught TWO tests writing the real file: one restored
	# in the wrong place and left the view on ASCII for weeks, the other
	# restored in the right place but captured the in-memory default instead of
	# the player's choice and downgraded his shaders every run. Both looked
	# correct on inspection. Redirecting is the only version that cannot be
	# written wrong.
	#
	# One path, four readers, so this single line moves all of them.
	SETTINGS_PATH = "user://scratch_%s_settings.cfg" % tag

## Removes whatever use_scratch_files created.
static func clear_scratch_files() -> void:
	BestiaryLog.clear_scratch()
	for path in [SUSPEND_PATH, MORGUE_PATH, DEATH_PATH]:
		if path.contains("scratch_") and FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
const SAVE_VERSION := 1

const MAP_W := 96
const MAP_H := 54
const TORCH_RADIUS := 8
## Dark-adapted eyes: enough to move by, far too little to be seen by. The
## trade between seeing and being seen is the whole mechanic.
const DOUSED_RADIUS := 3

## How far a lit torch reaches in the cave band, and in its corrupted twin on
## the way out.
##
## Measured before choosing: the cave band was expected to be punishing and is
## not. Monsters are populated per ROOM, so trading rooms for caverns removes
## things to fight at the same rate it removes braziers -- across the climb the
## cave floors came out no worse than their neighbours and one came out best.
## The band is poorer and emptier rather than harder, which is what left room
## for this.
##
## Six on the way down: enough to teach that caves are dark. Four on the way
## back, one above doused, where the flare shrine stops being a curiosity.
const CAVE_TORCH := 6
const CORRUPT_TORCH := 4

## The reach of a lit torch on this floor.
func torch_radius() -> int:
	if not Bands.is_caves(effective_depth()):
		return TORCH_RADIUS
	return CORRUPT_TORCH if Bands.is_corrupted(effective_depth()) else CAVE_TORCH

## Resting at a brazier. Each one holds a fixed pool, spent two points at a
## time, and then goes out for good.
## How far a blow or a bowshot carries.
##
## Six, not the four it inherited from the old wake-the-neighbours rule. A
## footstep on bones carries seven; a pitched battle carrying four was the
## odder number of the two.
##
## What this is NOT is a fix for shoot-and-retreat, and the measurement is
## worth recording so nobody tries it again. Firing twelve shots at something
## that cannot catch you draws nobody at all:
##
##     radius 4   94% of the time nobody comes
##     radius 6   79%
##     radius 9   52%
##
## Even at nine -- more than a boneyard -- half the time the archer's corner
## stays empty. Noise is simply the wrong lever: it wakes things, and the
## things it wakes are mostly the same slow ones that could never reach you.
## The exploit is about SPEED, and the answer to it is that shots have to cost
## something. See the ammunition work.
const COMBAT_NOISE := 6

## How far something will walk to answer the vigil.
##
## Sixty, against a default of ten, because the median monster is 31-38 cells
## from the shrine and a floor is 96x54. This is not "they try harder", it is
## "they cross the dungeon", which is what a gong that wakes everything ought
## to mean.
const VIGIL_PURSUIT := 60

## How loud a thing has to be before the dead answer it.
##
## Seven: a bone crunch and up, so combat (6) and a door (6) stay under it and
## a chest (8), a wail (9) and the forge (10) do not.
const GRAVE_ROUSING := 7
const BRAZIER_CHARGE := 10

## How often an untended fire loses a charge, in turns.
##
## THE DUNGEON GAINS A CLOCK. `brazier_charge` only ever fell when the PLAYER
## rested or forged, so a fire on a floor nobody visited burned for ever -- the
## one system in the game where time did not pass unless you were there to
## spend it.
##
## Forty, so a full brazier is gone in four hundred turns: about one long visit.
## The consequence is deliberate and is the real change here -- "save that fire
## for later" stops working, and healing becomes something you take when you
## find it. What keeps that from being a straight nerf is that guards tend
## them, so a floor with a watch on it stays warm and a dead cave does not.
const BRAZIER_BURN_EVERY := 40

## Below this a passing guard will stoke a fire, and by how much.
##
## Brad's design, and it is better than mine was: I had fires simply burning
## down, which is a clock. His adds a LOOP the player can work -- spend a fire,
## hide, let the watch build it back. Three is deliberately awkward against
## MERGE_COST of 4: one top-up buys three hit points but NOT a merge, so the
## second wait is a different decision from the first.
const BRAZIER_LOW := 4
const BRAZIER_STOKE := 3
const BRAZIER_HEAL := 2
## Merging two identical items costs brazier charge, which is the same finite
## pool as healing. That is the whole point: standing at a brazier hurt, with
## two daggers in your pack, should be a real choice between recovering now and
## hitting harder later. Durability was the other candidate and it fails,
## because it punishes using the good item and players simply hoard it.
const MERGE_COST := 4
## A scroll of light poured into a dead brazier relights it, but weakly.
## Deliberately less than a fresh one holds, and deliberately INSTEAD of the
## scroll's reveal rather than as well as it -- otherwise there is no decision,
## just a strictly better way to read the scroll.
const RELIGHT_CHARGE := 6

## Embers.
##
## A brazier that has just gone out will still work metal, once, and then it is
## black for good. This exists because the ten charges are meant to pose a
## question -- heal, or forge -- and a player who needs the hit points never
## gets to answer it. The embers give the answer back without giving back a
## single hit point.
##
## The cost is noise instead of charge, and the twenty turns are what makes the
## noise a real cost. Without a deadline the play is obvious and free: clear
## the floor, then walk back round it forging at every dead brazier, because
## noise prices nothing when nothing is alive to hear it. That is the same hole
## shoot-and-retreat went through -- see COMBAT_NOISE -- and it is worse on the
## way DOWN, where a bow clears a floor for almost no hit points at all. Twenty
## turns is long enough to finish the fight you are in and far too short to
## clear a level, so the decision has to be taken where it is offered.
const EMBER_TURNS := 20
## Louder than a sword blow, because hammering is. Deliberately above bones at
## seven, so on a floor you were sneaking across this is the loudest thing you
## can choose to do.
const FORGE_NOISE := 10
## Shown, not heard: how far the shrine of the vigil's cry is DRAWN. Its actual
## effect is the whole floor.
const CLAMOUR_RING := 24

## A flared torch, in turns. It cannot be smothered while it burns -- that is
## the curse half: you see much further, and so does everything else.
const FLARE_TURNS := 100
const FLARE_MULTIPLIER := 2
## How long the shrine of the quiet keeps a floor from noticing you. Long
## enough to move, or to get the torch out and leave on your own terms.
const QUIET_TURNS := 12

## Ordinary human pace, and what the shrine of the weight costs you until the
## next floor. The energy scheduler has supported this since the beginning and
## nothing has ever moved it.
const BASE_SPEED := 100
const WEIGHT_SPEED := 82

## How often a slain monster's gear survives the fight.
##
## Not 1.0 on purpose. Every kill yielding a usable item would flood the floor,
## and with forging in the game that compounds -- three daggers make a +2
## dagger, so guaranteed drops would accelerate a power curve that already
## outruns monster defense.
const LOOT_DROP_CHANCE := 0.5

## Experience.
##
## A kill is worth its `threat` -- that value already IS this game's challenge
## rating, hand-tuned for what makes something dangerous to a lone character,
## so there is no second table to keep in sync.
##
## Descending pays a multiple of the threat ceiling for the floor just left.
## Tying it to the ceiling means the same number that decides how hard a floor
## may be also decides what surviving it is worth: change one and the other
## follows, with no drift.
##
## The split matters because stealth is intended play. If XP came only from
## kills, creeping past things -- the mode the game is built around -- would
## quietly fall behind the depth curve. Descending is the main driver, fighting
## is the accelerator.
const XP_DEPTH_MULTIPLIER := 6

## Levels cost quadratically more, NOT exponentially like D&D. See the README:
## D&D's curve is shaped around campaign tiers across dozens of sessions, and
## transplanted here it would grant three levels on floor one and then nothing
## for an hour.
const XP_CURVE_A := 18
const XP_CURVE_B := 42

const LEVEL_HP := 5

## What the player starts with, and the other half of the curve above.
##
## Named rather than written as a literal in `new_game` because something else
## now has to reproduce it: the morgue records the LEVEL a dead character
## reached but never their hit points, and `hp_at_level` rebuilds those from
## this pair. Two copies of a growth curve is exactly the sort of thing that
## drifts apart quietly, one balance pass at a time.
const START_HP := 30

## The hit points a hero of this level had.
##
## Deterministic, which is the only reason a bone ally can be as tough as the
## run that died: nothing about max HP is written into the morgue, so it is
## reconstructed from the one number that is.
static func hp_at_level(lvl: int) -> int:
	return START_HP + LEVEL_HP * maxi(0, lvl - 1)

## The least a blow can be reduced to, as a fraction of the attacker's power.
##
## Flat damage reduction has a known failure mode: negligible while small, then
## absolute once defense catches up to power. Measured at depth 8, a levelled
## player in chain mail took the floored minimum of 1 from every orc in the
## game -- sixty hit points against one damage a hit.
##
## A floor tied to the attacker keeps armour worth wearing without ever making
## it immunity, and it makes the armour curve smooth instead of cliff-edged. It
## barely touches the early game: nothing changes at depths 1-3.
const DAMAGE_FLOOR_FRACTION := 0.25

## What a bound gem adds, as a SHARE of the blow rather than a flat number.
##
## Flat was the obvious shape and it is the shape this project already has a
## measured problem with: a +3 is sixty per cent of a level-one hit and twenty
## per cent of a level-fifteen one, so it would deflate exactly the way the
## weapon bonuses do. A share keeps a gem worth what it was worth.
## What a damage type is worth against something that shrugs it off, or that
## it finds.
##
## Deliberately modest. These exist to change WHICH weapon you reach for, not
## to make one useless -- and `DAMAGE_FLOOR_FRACTION` already guarantees every
## blow lands for at least a quarter of your attack, so a resisted weapon can
## never be reduced to nothing. That floor is what makes this safe to add at
## all.
const RESISTED := 0.70
## Raised from 1.40 after play. Reported from a real run: a +5 mace on a wight
## did 14, a +7 war axe did 13. The system WORKED -- the numbers came out of
## the formula exactly -- and it still failed, because one point of damage is
## not worth an inventory slot and a second weapon to swap to. The optimal play
## was "just use the axe", which is the weapon-convergence problem wearing a
## new hat.
##
## At 1.60 the same pair reads 16 against 13. The resist side stays where it
## was: being punished for the wrong weapon is already legible at 0.70, and it
## is the REWARD for carrying the right one that was too thin to notice.
const VULNERABLE := 1.60

## What a prayer is worth beyond the boon itself.
##
## Gems carry weight 0, so the ordinary loot roll cannot produce one -- they came
## from chests and from a single pity placement, and nowhere else. That put gems
## and uniques down the same pipe: every unique added to the game takes a chest
## slot a gem would have had, so a growing list of uniques would quietly starve
## the descent of the one system you build a character with.
##
## Giving shrines their own gem stream separates the two for good. Chests become
## unambiguously the run-defining find; shrines stay the gamble, with a gem as
## one of the good ways a gamble can land. Uniques can now be added forever
## without touching the gem economy, because they no longer share a source.
##
## Rolled on USE and dropped at your feet, not placed in the room. A gem lying
## in a shrine room before you touch anything would be a tell -- and a tell that
## leaks whether the shrine is worth using destroys the only thing shrines are:
## an unknown you pay to learn.
const GEM_SHRINE_CHANCE := 0.30

const GEM_FIRE_SHARE := 0.35
## Leech is deliberately stingier, and it is measured against the BRAZIER's ten
## hit points rather than against the health bar. D&D's vampiric touch is half
## the damage dealt, which here is six or seven a swing -- most of a brazier per
## hit, and it would make the forge pointless. At fifteen per cent a fight and
## a half is worth one brazier.
const GEM_LEECH_SHARE := 0.15
## How long frost holds, and how much it costs. The multiplier is deliberately
## short of mud's 2.0: mud is terrain you can walk around, and this follows you.
const GEM_FROST_TURNS := 5
const GEM_FROST_COST := 1.7
## At most this many spires per blow. Two, because the point is to break a line
## of approach rather than to bury the thing.
const GEM_CRAG_SPIRES := 2

## How many spires a MISSILE weapon raises, by how far it throws.
##
## Brad's design, and the reason it is not simply "stronger weapon, more
## stone": the sling knaps its ammunition out of rubble, which is everywhere,
## while arrows are the only strictly closed resource in the game -- nothing
## ever adds one. So a sling throws one wall and can do it forever, and a war
## bow throws three at a cost the dungeon never refunds.
##
## The weakest option is not worse, it is cheaper. That trade already existed
## in the ammunition; this lets the crag gem read it.
##
## Keyed on reach rather than a table of weapon names, so a polearm or a
## crossbow added later gets an answer without anyone editing this.
const CRAG_SLING_REACH := 4

## How long a spire stands before it subsides.
##
## Brad's call, and it replaces a check rather than adding one. A permanent
## spire can seal a one-wide corridor -- reported from play -- and the floor
## behind it is then unreachable. Detecting that needs a flood fill on every
## connecting blow, which is expensive and only ever says no.
##
## Temporary stone says yes and then undoes itself. It still does the job the
## gem exists for: three turns is long enough to break away from something or
## put a wall between you and it, and not long enough to rebuild the level.
const GEM_CRAG_TURNS := 3

## Cell -> [turn it subsides, the tile that was there before].
##
## Saved with the run, so a spire raised before a suspend does not become
## permanent by outliving the save -- which is how a temporary thing quietly
## turns into the permanent one it was replacing.
var spires: Dictionary = {}
## Steps before loosed arrows come home.
##
## Five is chosen to split the two kinds of scarcity apart. WITHIN a fight five
## steps is a long time, so the quiver you started the fight with is still the
## quiver you fight it with -- the decision about whether a shot is worth an
## arrow survives intact. BETWEEN fights they come back, which removes the walk
## across the room to pick them up. That walk was never a decision: you always
## want your arrows, and the only way to get it wrong is to forget.
const GEM_RETURN_STEPS := 5
## The floors the first gem is guaranteed to appear on, and the flag saying it
## already has.
##
## Measured before this existed: half of depth-2 floors carried no gem at all,
## a third of depth-3 floors, and two thirds of the cave floors -- so roughly
## one run in six reached the third floor having never seen one. A mechanic
## that may simply not occur is a mechanic players do not learn, and this one
## already asks for three things to coincide (a gem, a spent brazier inside its
## twenty-turn window, and the right weapon in hand).
##
## Only the FIRST one is placed. Everything after it is the ordinary roll, so
## the guarantee buys discovery and nothing else.
const GEM_PITY_FLOORS := [2, 3, 4]

## What a sack holds, as cumulative thresholds.
##
## Brad's shape: a weapon is the usual answer, armour next, then something
## enchanted, and a gem is the rare one. Written as a ladder rather than four
## weights so the ordering is visible and a change to one boundary cannot
## silently reorder the tiers.
##
## The MAGIC tier does not roll its own element -- it takes an ordinary weapon
## and applies the same enchant the floor would, so a sack can never contain
## something the gem rules forbid, and the curve that makes deep magic richer
## reaches sacks without anyone wiring it.
const SACK_WEAPON := 0.45
const SACK_ARMOUR := 0.75
const SACK_MAGIC := 0.93
## above SACK_MAGIC: a gem
var gem_found := false
## Which uniques this run has already turned up. One of each per dungeon, so a
## second chest cannot hand you a second ring.
var uniques_found: Dictionary = {}

## How far a chest's hinges carry. The existing ladder: combat 6, bones 7, a
## banshee's wail 9, the forge 10, the vigil shrine 24. Eight puts it above an
## accident and above the fight that earned it, below sustained hammering --
## the reward announces itself more loudly than the work did.
const CHEST_NOISE := 8
## Three quarters. High enough that you should ASSUME the lid is trapped and
## read the room before lifting it, short of certain so the quiet quarter is a
## relief rather than something to plan around. Same reasoning as the graves'
## 45%: a rule that always fires stops being tense and becomes arithmetic.
const CHEST_TRAP_CHANCE := 0.75

## How much harder a rat is to notice. Multiplied into the detection chance, on
## top of the darkness that comes free from having no torch.
##
## Note that losing the torch is NOT a cost for a stealth item -- `lum` is a
## term in the detection formula, so being unlit already makes you harder to
## see. The real price of no torch is that you cannot SEE: navigation, and
## spotting what is ahead.
## The two points at which the ring tells you it is running out.
##
## RING_LOW is ambient: the sidebar stops highlighting the count, because you
## have less than a floor's crossing left and the number has stopped being
## trivia and started being a decision. RING_WARNING is the alarm, once, in the
## log. Two thresholds on purpose -- a warning that fires at the same moment
## the colour changes is one signal wearing two coats, and the useful thing is
## to see it coming BEFORE you are told.
const RING_LOW := 60
const RING_WARNING := 20

const RAT_NOTICE := 0.35
## And on the climb, where nothing expects a rat because there are none.
## Brad's rule, and the best part of the design: the disguise fails because
## there is nothing left to be disguised as.
const RAT_NOTICE_ASCENT := 0.70

const HP_WARN_FRACTION := 0.30

## The threat ceiling.
##
## Deliberately a CEILING, not a budget. A budget would shape every room toward
## a target and flatten the swinginess that makes the game tense; this only
## clips the disasters -- the room that rolls three orcs against a 30 hp
## character with no answer. Density is untouched.
## What the climb does to the things that live near the top.
##
## The ascent has always drawn from the SAME faded pool as the descent, so it
## got harder by ceiling rather than by cast -- more of the same things, not
## different ones. These re-admit the creatures the tier fade has retired,
## worse than they were, so the way out has a population of its own without
## twenty new entries in the bestiary.
##
## They are TRASH on purpose. Doubling a rat gives something worth about four
## threat, which buys bodies, noise and blocked corridors -- not a second boss.
## Scaling them to the floor's tier instead would deliver roughly a hundred
## threat of real danger on top of the room ceiling and end the survivability
## guarantee outright.
const CORRUPT_SCALE := 2.0
## Nothing already worth more than this is worth corrupting. The skeleton sits
## at 8 and is a mid-tier creature; doubled it becomes a peer, which is the one
## thing this must not produce.
const CORRUPT_MAX_BASE := 5
## Floor under a corrupted thing's cost, so the pool cannot fill with rats.
const CORRUPT_MIN_COST := 3

const ROOM_THREAT_BASE := 10
const ROOM_THREAT_PER_DEPTH := 2
## Caverns are open ground, so a lone character cannot use a doorway to turn
## being outnumbered into a series of duels. Less forgiving terrain, smaller
## ceiling.
## What a cave is allowed to hold, as a share of a room's budget -- for a cave
## of TYPICAL size. Bigger caverns scale up from here, smaller ones down.
const CAVE_THREAT_SCALE := 0.7

## The walkable cells in an average cave, measured across 388 of them. The
## scale above is expressed against this number so that an average cave keeps
## exactly the budget it always had: this redistributes danger by size, it does
## not add any.
const CAVE_TYPICAL_CELLS := 113

## Floor and ceiling on that scaling. The upper bound is the thing that matters:
## a cave is never deadlier than a room, which is the bound the old flat 0.7 was
## really there to keep.
const CAVE_SCALE_MIN := 0.5
const CAVE_SCALE_MAX := 1.0


## How fast a monster stops appearing once the dungeon has moved past its tier.
## Without this, rats are as likely on depth 9 as on depth 1.
const TIER_FADE := 0.22
const TIER_GRACE := 1

var rng := RandomNumberGenerator.new()

## A SEPARATE rng for whether a generated weapon arrives enchanted, for exactly
## the reason graves have one -- see the note in the grave placement below.
##
## The enchant roll happens once per item a floor rolls, so putting it on the
## main stream made every later draw depend on how much loot appeared, and the
## whole floor moved. Measured before it was split out: identical seeds gave
## 29269 walls or 28870, 135 monsters or 149, and the guaranteed floor-two gem
## went missing on 9 seeds in 60.
##
## Seeded from the run and the depth, so a save enchants the same way every
## time while touching nothing else on the floor.
var enchant_rng := RandomNumberGenerator.new()

## And one for the trader's room, for the same reason again: it is drawn after
## the floor is already populated, so taking it from the main stream would make
## the number of draws depend on whether this depth has a trader at all.
var trader_rng := RandomNumberGenerator.new()
var map: DungeonMap
var light_map: LightMap
var pathfinder: Pathfinder
var msg_log := MessageLog.new()

var entities: Array = []
var ground: Array = []
var player: Entity
var static_lights: Array = []
## The morgue, read once per run rather than once per floor.
##
## `build_level` is called for every floor of every run, and the test suite
## builds thousands of them -- a file read and a regex pass per level would put
## real time on a suite that already takes minutes. Cached on the instance, not
## statically, because `use_scratch_files` moves the path underneath the tests.
## What this character is called, or "" for the nameless.
##
## Written into the morgue on death, which is the only place it matters: a name
## you never see again is decoration, but a name that comes back three runs
## later attached to a skeleton carrying the gear you died in is a mechanic.
var player_name := ""

var _morgue_cache: Array = []
var _morgue_read := false

func _morgue() -> Array:
	if not _morgue_read:
		_morgue_read = true
		_morgue_cache = Morgue.records(MORGUE_PATH)
	return _morgue_cache

## How many of a floor's own dead it will show at once.
##
## Capped rather than one stone per record: a player who has died eleven times
## on depth 1 should meet a reminder, not a cemetery. The floor still draws
## from all of them, so which graves appear varies by run.
const MAX_GRAVES := 2
## How often a grave that hears bones or a wail actually gives something up.
##
## A CHANCE, not a certainty, and that is the whole mechanic. Brad's rule, from
## running tables: players go cautious the moment they see gravestones, and
## they stay cautious because sometimes nothing happens. A stone that always
## rose would be arithmetic -- clear them first, or route around bones -- and
## the dread would be gone inside one run.
const GRAVE_RISE_CHANCE := 0.45

## Bury the runs that ended on this floor.
##
## Reads the morgue -- the file that has been written every death since the
## game existed and never once been read back. Deaths only: someone who walked
## out into daylight is not buried down here.
func _place_graves() -> void:
	var here: Array = []
	for rec in _morgue():
		if int(rec.get("depth", -1)) == depth:
			here.append(rec)
	if here.is_empty():
		return

	# A SEPARATE rng, and this is not a nicety.
	#
	# Graves are drawn from the morgue, and the morgue GROWS -- every death a
	# player has ever had is in it. Drawing their positions from the run's own
	# rng made the number of draws depend on how many past deaths matched this
	# depth, so the same seed generated a different dungeon once the player had
	# died a few times. Seeded reproducibility is a promise this project makes
	# and _test_generation_is_deterministic exists to keep.
	#
	# Caught by the vault-door test reporting 97 doors one run and 99 the next
	# on identical seeds -- a flaky test that was telling the truth.
	#
	# Seeded from the run and the depth, so graves stay reproducible for a given
	# save while touching nothing else on the floor.
	var grave_rng := RandomNumberGenerator.new()
	grave_rng.seed = int(rng.seed) ^ (depth * 2654435761)

	# Never Array.shuffle() -- a global-rng call in generation is what made
	# every seeded level unreproducible once before.
	for i in range(here.size() - 1, 0, -1):
		var j := grave_rng.randi_range(0, i)
		var tmp: Variant = here[i]
		here[i] = here[j]
		here[j] = tmp

	var wanted := mini(MAX_GRAVES, here.size())
	var placed := 0
	for _try in 200:
		if placed >= wanted:
			return
		var x := grave_rng.randi_range(1, map.width - 2)
		var y := grave_rng.randi_range(1, map.height - 2)
		var cell := Vector2i(x, y)
		# Same rule loot obeys: real standing ground, never a pit or a trap,
		# and never on top of the stairs or the way out.
		if not _can_rest_on(x, y) or grave_at.has(cell) or cell == stairs:
			continue
		if cell == Vector2i(player.x, player.y):
			continue
		map.set_tile(x, y, Tiles.GRAVE)
		grave_at[cell] = here[placed]
		_scatter_bones_around(cell, grave_rng)
		placed += 1

## Bone litter around a headstone.
##
## Brad's call, and it is what makes the whole mechanic reachable: bones carry
## exactly seven cells, so a boneyard in the next room down a corridor is out
## of range, and waiting for the terrain pass to drop bones beside a grave by
## luck is waiting a long time.
##
## Scattered around EVERY grave, armed or not. Putting them only beside stones
## that can rise would make the pairing a reliable warning, and a reliable
## warning is a signpost rather than dread -- the same reason a poor grave is
## allowed to sit in bones and simply never answer.
##
## Drawn from the GRAVE rng, never the generation one. Graves come from the
## morgue and the morgue grows, so spending generation randomness here is
## exactly the bug that made a seed stop reproducing its dungeon once a player
## had died a few times.
func _scatter_bones_around(cell: Vector2i, grave_rng: RandomNumberGenerator) -> void:
	var wanted := grave_rng.randi_range(2, 4)
	var dropped := 0
	# The ring first, then one out, so the litter reads as spreading from the
	# stone rather than as a patch that happens to contain one.
	for step in [1, 2]:
		for dy in range(-step, step + 1):
			for dx in range(-step, step + 1):
				if dropped >= wanted:
					return
				if maxi(absi(dx), absi(dy)) != step:
					continue
				var n := cell + Vector2i(dx, dy)
				if not map.in_bounds(n.x, n.y) or n == stairs:
					continue
				# Plain ground only. Authored terrain, water, doors and hazards
				# all mean something already, and bones would be a lie over
				# any of them.
				var t := map.get_tile(n.x, n.y)
				if t != Tiles.FLOOR and t != Tiles.CAVE_FLOOR:
					continue
				if grave_rng.randf() < 0.45:
					map.set_tile(n.x, n.y, Tiles.BONES)
					dropped += 1

## The stone whose occupant is currently up and about, or (-1,-1).
##
## Kept so the headstone can stay put while the fight is on and go when the
## fight is won. The stone vanishing at the MOMENT of rising was the first
## version, and it left nothing to look at afterwards and no way to tell which
## of the two had woken -- the interesting information disappeared exactly when
## it became interesting.
var risen_grave := Vector2i(-1, -1)


## One rising per floor, ever -- not one at a time.
##
## "One at a time" only slows the obvious exploit: make noise, kill it, make
## noise again, and walk off with two dead runs' equipment. Once per visit
## means "which of the two stones woke?" is a question you get to ask once, and
## there is nothing to farm.
var grave_risen := false

## Steps walked since the last arrows came home. Only counts while a gem of
## returning is actually in hand, so unbinding it stops the clock rather than
## banking progress.
var _return_walk := 0

## Cell -> hit points left in that brazier.
var brazier_charge: Dictionary = {}
## Cell -> the turn its embers go cold. Only ever holds cells that are
## BRAZIER_SPENT right now; a relight or an ember forge drops the entry.
var ember_until: Dictionary = {}
var stairs: Vector2i
## Cave regions carved on this level, kept so tests and later features can
## reason about them.
var cave_regions: Array[Rect2i] = []
## Kept so the encounter maths can be measured after the fact.
var room_rects: Array[Rect2i] = []
## Where the hand-authored rooms landed, kept for tests and later features.
var vault_rects: Array[Rect2i] = []
## Parallel to vault_rects. Several vaults share a bounding box, so a size
## cannot identify one.
var vault_names: Array[String] = []

var torch_lit := true
var depth: int = 1
## Set the moment the amulet is taken. Everything downstream reads
## `effective_depth()` rather than `depth`, which is what makes the climb out
## harder than the climb down.
var ascending := false
var won := false
## What finished the run, for the morgue.
var death_cause := ""

## Cell -> shrine type. Shrines are consumed when used.
var shrine_at: Dictionary = {}
## Cell -> the morgue record buried there.
var grave_at: Dictionary = {}
## Shrine type -> hue index, shuffled once per run so the colours have to be
## learned again each time.
var shrine_hues: Array[int] = []
var shrine_known: Dictionary = {}
## Raised by the shrine of the anvil, for the rest of the run.
var forge_cap_bonus := 0
var torch_flare := 0
var turns: int = 0
## Energy spent by the player, which is game TIME rather than player actions.
##
## `turns` counts keypresses: one step is one turn whether it crossed clean
## stone or mud that cost double and handed the world two moves against you.
## Both numbers are true and they are true about different things, so the run
## keeps both -- turns is the number a speedrunner can optimise directly, this
## is the one the clock has to be built on. See Clock.
var elapsed: int = 0
## True when `elapsed` was reconstructed on load rather than measured, which
## happens for any save written before the counter existed. The end screen
## marks that time with a tilde instead of presenting a guess as a measurement.
var elapsed_estimated: bool = false
## What the run DID, as opposed to what it ended as.
##
## One dictionary rather than a field apiece, because the end screen's rule is
## to skip whatever it has no data for. A save written before any of this
## existed loads `{}`, and the screen shows fewer sections instead of a wall of
## confident zeroes about a run that was never being counted.
var stats: Dictionary = {}
var game_over: bool = false

## Presentation events produced by the turn just resolved.
##
## The simulation NEVER waits for an animation. A shot resolves instantly in
## game time -- exactly as Angband and DCSS do it -- and this queue only tells
## the renderer what to draw after the fact. Anything else would put a reflex
## test inside a turn-based game.
var events: Array = []

var _fov_buffer := PackedByteArray()
## Everything the player has an unobstructed LINE to, however far. Masked by
## light to produce the half of vision that is not about your own torch.
var _sight_buffer := PackedByteArray()

## How bright a cell must be before you can make it out from across a room.
##
## Ambient is Color(0.06, 0.07, 0.11), which is about 0.071 luminance, so this
## has to sit clear of it -- otherwise "lit" means "exists" and the whole floor
## is visible from the stairs.
const LIT_ENOUGH := 0.12

## A guard's lantern: small and dim.
##
## Deliberately weaker than a brazier (radius 6, 0.85) and than your own torch
## (radius 8). It is meant to give the CARRIER away, not to light the room for
## you -- a lantern that revealed the corridor it walks down would hand the
## player a free map and make dousing strictly better than a torch.
##
## Bright enough to clear LIT_ENOUGH at its centre by a wide margin, so a
## moving point of light is unmistakable in the dark; small enough that you
## still cannot see what is holding it until it is inside your own reach.
const LANTERN_REACH := 4
const LANTERN_GLOW := 0.50
## A queued mouse-travel path. Consumed one step per turn, abandoned the
## instant something hostile comes into view.
var _travel: Array[Vector2i] = []
## Set by whichever movement helper an AI turn used, so the scheduler can
## charge for the ground actually crossed.
var _last_move_cost := Scheduler.ACTION_COST
## What the player was standing on last turn, so a change of footing can be
## announced. The energy cost was working perfectly and was completely
## invisible -- one keypress still looked like one turn.
var _last_footing := Tiles.FLOOR
## Latched, so crossing the health line warns once on the way down rather than
## every turn spent under it. A warning that repeats is a warning that gets
## tuned out, which is the opposite of the point.
var _hp_warned := false
## The grave last stood on, so pacing back and forth across one does not
## reprint its epitaph every step.
var _last_grave := Vector2i(-1, -1)
## Read once and shared by every level, since the files never change mid-run.
static var _vault_library: Array[Vault] = []

## Behaviour matters more than the numbers here. Six monsters that all walk at
## you in a straight line are one monster with six stat blocks; the point of
## this pass is that a bat, an archer and a goblin now play differently.
##
## Capital glyphs mark the dangerous variant of a family -- K is a kobold that
## shoots back.
## Behaviour matters more than the numbers here. Six monsters that all walk at
## you in a straight line are one monster with six stat blocks.
##
## `threat` is this game's challenge rating. It is not derived from the stats
## by formula, because the stats do not capture what actually makes something
## dangerous to a lone character: a slinger costs more than its hit points
## suggest because it attacks from safety, and a bat costs more than its damage
## suggests because you cannot disengage from it.
##
## Capital glyphs mark the dangerous variant of a family -- K is a kobold that
## shoots back.
## WHO WALKS A BEAT, and who picks things up.
##
## `"patrol": true` goes on anything BIPEDAL -- kobolds, goblins, orcs, ogres,
## trolls, wights, wizards, giants, skeletons, golems. The rule is Brad's and
## it is about disposition, not danger: wildlife does not march (rat, bat,
## bear, rabbit, harpy, wyvern), and the apex things cannot be bothered -- a
## dragon and an arch lich do not walk rounds, because players come to them
## rather than the other way about. Shadow and banshee are left out for a
## different reason: a creature that walks through walls has no use for a route
## between doors.
##
## `"scavenge": true` is the narrower set -- hands AND the wit to use what it
## finds. The undead keep what they were buried in, and a golem is not going to
## try on a hat.
##
## An earlier version of this note claimed the patrollers were "made things
## rather than living ones", which was true for exactly one evening and was
## never the actual rule.
const BESTIARY := [
	{"name": "giant rat", "app": &"rat", "hp": 4, "power": 2, "def": 0,
	 "speed": 120, "ai": &"hunter", "flee": 0.30, "min_depth": 1, "threat": 2, "caves": 1.8},
	{"name": "kobold", "app": &"kobold", "hp": 6, "power": 3, "def": 0,
	 "speed": 100, "ai": &"hunter", "flee": 0.25, "gear": 0.35, "min_depth": 1, "threat": 3, "caves": 1.5, "patrol": true, "scavenge": true},
	{"name": "kobold slinger", "app": &"slinger", "hp": 5, "power": 3, "def": 0,
	 "speed": 100, "ai": &"ranged", "range": 6, "flee": 0.45, "gear": 0.25, "min_depth": 2,
	 "threat": 6, "caves": 0.5, "patrol": true, "scavenge": true},
	{"name": "cave bat", "app": &"bat", "hp": 5, "power": 3, "def": 0,
	 "speed": 170, "ai": &"erratic", "flee": 0.0, "flying": true, "min_depth": 2, "threat": 5, "caves": 2.6},
	{"name": "goblin", "app": &"goblin", "hp": 9, "power": 4, "def": 1,
	 "speed": 100, "ai": &"pack", "flee": 0.20, "gear": 0.50, "min_depth": 2, "threat": 5, "caves": 2.0, "patrol": true, "scavenge": true},
	{"name": "skeleton", "app": &"skeleton", "hp": 12, "power": 5, "def": 2,
	 "speed": 90, "ai": &"hunter", "flee": 0.0, "gear": 0.40, "min_depth": 3, "threat": 8, "caves": 0.4, "unliving": true, "resists": ["slash", "pierce"], "weak_to": ["blunt"],
	 ## It was set to guard something and never stopped.
	 "patrol": true},
	{"name": "orc", "app": &"orc", "hp": 16, "power": 6, "def": 2,
	 "speed": 100, "ai": &"hunter", "flee": 0.15, "gear": 0.70, "min_depth": 4, "threat": 10, "caves": 1.3, "patrol": true, "scavenge": true},

	# --- deep tiers -------------------------------------------------------
	# Power from 7 upward, because below that a levelled character in chain
	# mail simply stops taking damage and the dungeon gets easier as it goes
	# deeper. These also carry the whole ascent, which runs at effective
	# depths of 10 to 19.
	{"name": "ogre", "app": &"ogre", "hp": 26, "power": 9, "def": 3,
	 "speed": 90, "ai": &"hunter", "flee": 0.12, "gear": 0.50, "heavy": true, "min_depth": 5, "threat": 14, "caves": 1.6, "patrol": true, "scavenge": true},
	{"name": "harpy", "app": &"harpy", "hp": 16, "power": 7, "def": 1,
	 "speed": 160, "ai": &"erratic", "flee": 0.25, "flying": true, "min_depth": 5, "threat": 12, "caves": 1.8},
	{"name": "cave troll", "app": &"troll", "hp": 30, "power": 8, "def": 3,
	 "speed": 90, "ai": &"hunter", "flee": 0.0, "regen": 2, "heavy": true, "min_depth": 6,
	 "threat": 16, "caves": 2.2, "patrol": true, "scavenge": true},
	# The cave band's heavy. Not the hardest thing down there -- what it does
	# instead is MOVE you, which nothing else in the bestiary can. A corridor
	# mouth you were holding, a doorway you backed into, the two cells between
	# you and the stairs: the bear takes all of that away in one hit and then
	# it is between you and where you wanted to be. Cheap to kill, expensive
	# to fight in the wrong place.
	{"name": "cave bear", "app": &"bear", "hp": 34, "power": 9, "def": 3,
	 "speed": 100, "ai": &"hunter", "flee": 0.15, "heavy": true, "min_depth": 5,
	 "threat": 17, "knockback": 2, "caves": 2.6},
	{"name": "wight", "app": &"wight", "hp": 24, "power": 10, "def": 4,
	 "speed": 100, "ai": &"hunter", "flee": 0.0, "gear": 0.60, "min_depth": 7, "threat": 17, "caves": 0.5, "unliving": true, "resists": ["pierce"], "weak_to": ["blunt"], "patrol": true},
	{"name": "wyvern", "app": &"wyvern", "hp": 32, "power": 11, "def": 4,
	 "speed": 140, "ai": &"hunter", "flee": 0.10, "flying": true, "min_depth": 7, "threat": 20, "caves": 2.2},
	# It throws its own rubble, and that is the fix for a monster you could
	# simply walk away from.
	#
	# At speed 70 it is the slowest thing in the game and can never close on a
	# player -- so it was a threat you ignored rather than fought. Reach makes
	# it dangerous at exactly the distance you were comfortable at, and a
	# golem lobbing stone is a better picture than a golem shuffling after you.
	#
	# The threat rises with it: a thing that can only be outwalked is worth
	# less than a thing that can hit you from six cells away.
	#
	# Melee is unchanged and enormous -- if it does reach you, it should be
	# felt.
	{"name": "stone golem", "app": &"golem", "hp": 42, "power": 10, "def": 7,
	 "speed": 70, "ai": &"ranged", "range": 6, "standoff": 2, "flee": 0.0,
	 "heavy": true, "min_depth": 8, "threat": 24, "caves": 0.5, "patrol": true,
	 "resists": ["slash", "pierce"], "weak_to": ["blunt"]},
	{"name": "shadow", "app": &"shadow", "hp": 20, "power": 13, "def": 1,
	 "speed": 130, "ai": &"erratic", "flee": 0.0, "flying": true, "min_depth": 9, "threat": 19, "caves": 1.0, "unliving": true},
	{"name": "young dragon", "app": &"dragon", "hp": 55, "power": 14, "def": 6,
	 "speed": 110, "ai": &"ranged", "range": 5, "flee": 0.0, "flying": true, "min_depth": 10,
	 "threat": 28, "caves": 2.0},

	# The rabbit, and what it turns into.
	#
	# It does not fight you, it OUTBIDS you: it eats the glowing fungus, which
	# is a hit point and, more to the point, a lamp. Nothing else in the
	# bestiary competes for a resource, and that is the reason it is here
	# rather than the joke at the end of it.
	#
	# Faster than the player and it flees, which everywhere else in this file
	# is the mark of a broken monster -- see the wizard, deliberately slowed for
	# exactly that reason. It works here only because it has to STOP TO EAT.
	# Those turns with its head down are the whole window.
	#
	# That window makes it catchable ON FOOT, which is better than the design
	# intended and is worth recording. First play: two melee hits five to
	# nineteen turns apart, landed by predicting which tile it would break to
	# next. A bow makes it easy; legs make it a chase you can win by reading
	# it. "Not catchable without a bow" was the original claim here and play
	# disproved it.
	{"name": "rabbit", "app": &"rabbit", "hp": 6, "power": 0, "def": 0,
	 "speed": 130, "ai": &"forager", "flee": 0.0, "no_fade": true,
	 # Read the COUNT here, not the share. A rabbit is 20% of a cave floor's
	 # population and 11% of a fortress one, which sounds like a warren and is
	 # not: cave floors hold about fourteen monsters, so three rabbits is a
	 # fifth of them by arithmetic alone, and three is the cap we chose.
	 #
	 # This was briefly cut to 0.16 on the strength of those percentages, which
	 # took early floors down to a third of a rabbit each -- and the descent is
	 # precisely where meat has to teach itself before the climb needs it.
	 "max_per_floor": 2, "weight": 0.35, "min_depth": 1, "threat": 3,
	 # Commoner in caves, and the reason is the loot rather than the fiction.
	 # Trading rooms for caverns costs the band its potions -- they are rolled
	 # per room like everything else -- and meat is what the terrain offers
	 # instead. The descent teaches that a haunch is food while it is merely
	 # convenient; the corrupted climb is where it stops being optional.
	 "caves": 2.0},

	# A monster whose weapon is the other monsters.
	#
	# It never attacks. Its whole threat is the cry, and the cry is aimed at
	# the thing the player is actually best at: this game is stealth, and a
	# banshee cannot be hidden from, walled out or outrun. That leaves exactly
	# one answer -- kill it -- which is why it is frail and why it comes to you.
	#
	# It is defined by three exemptions, one from each of the systems the
	# stealth game rests on: no tier fade, no walls, no line of sight. That
	# looks like a lot of carve-outs until you notice they are the same
	# carve-out said three ways.
	{"name": "banshee", "app": &"banshee", "hp": 8, "power": 0, "def": 0,
	 "speed": 100, "ai": &"banshee", "flee": 0.0, "flying": true,
	# Depth 3, not 1, and then forever: `no_fade` and `min_depth` are
	# independent, so it can start late and still never age out. The first two
	# floors are where a player learns that dousing the torch works and that
	# walls are cover -- meeting the thing that ignores both before either has
	# landed teaches nothing.
	 "phasing": true, "senses": true, "wail": 9, "no_fade": true,
	 "max_per_floor": 1, "weight": 0.30, "min_depth": 3, "threat": 8, "unliving": true},

	# --- the casters ------------------------------------------------------
	# Frail, long-armed, and unwilling to be reached. Both fight by refusing
	# the fight, which is the one thing nothing else in the bestiary does.
	#
	# The wizard is SLOWER than the player on purpose. A kiter at equal speed
	# can never be caught and never has to commit, which is precisely the
	# shoot-and-retreat loop COMBAT_NOISE documents as unfixable by noise --
	# handed to the dungeon instead of the player. At 90 it loses a step every
	# time it gives ground, so walking it down works; you simply pay for the
	# walk.
	{"name": "wizard", "app": &"wizard", "hp": 18, "power": 11, "def": 1,
	 "speed": 90, "ai": &"ranged", "range": 7, "standoff": 3, "flee": 0.0,
	 "min_depth": 8, "threat": 22, "caves": 0.4, "patrol": true, "scavenge": true},
	# What the caves have in them on the way back out.
	#
	# Only the SECOND ascent-only creature in the bestiary -- the climb has
	# always drawn from the same faded pool as the descent, so it gets harder
	# by ceiling rather than by cast, and you meet more of the same things
	# instead of different ones. This is the fix for that, applied to the band
	# the bear owns: the same caves, worse.
	#
	# It charges, and that is the whole creature. A bear costs you your ground
	# and leaves you a moment to use; a giant costs you your ground and is
	# already standing in it. Backing toward a corridor stops working, so the
	# answer has to be breaking line instead of retreating -- a different
	# problem, not a bigger one.
	{"name": "cave giant", "app": &"giant", "hp": 48, "power": 13, "def": 4,
	 "speed": 100, "ai": &"hunter", "flee": 0.0, "heavy": true, "min_depth": 10,
	 "ascent_from": 14, "threat": 26, "knockback": 3, "charges": true,
	 "caves": 2.4, "patrol": true, "scavenge": true},
	# Ascent-only, and late on it. `min_depth` stays at the dragon's tier so the
	# fade window is undisturbed; `ascent_from` does the actual gating.
	{"name": "arch lich", "app": &"lich", "hp": 40, "power": 15, "def": 5,
	 "speed": 100, "ai": &"ranged", "range": 8, "standoff": 3, "blink": 12,
	 "flee": 0.0, "min_depth": 10, "ascent_from": 16, "threat": 32, "caves": 0.6, "unliving": true, "resists": ["pierce"], "weak_to": ["blunt"]},
]

## The deepest tier that exists.
##
## Beyond it the tier fade stops progressing. Without this the ascent -- which
## runs at effective depths of 10 to 19 -- would fade every monster in the game
## out of the pool and generate empty floors.
static func deepest_tier() -> int:
	var d := 1
	for e in BESTIARY:
		d = maxi(d, int(e["min_depth"]))
	return d

func _init(seed_value: int = 0) -> void:
	if _vault_library.is_empty():
		_vault_library = Vault.load_all()
	if seed_value == 0:
		rng.randomize()
	else:
		rng.seed = seed_value

func new_game() -> void:
	depth = 1
	turns = 0
	game_over = false
	# A fresh run has met nothing. Cleared here as well as at declaration
	# because new_game() is also the restart path.
	gem_found = false
	uniques_found.clear()
	player = Entity.new("you", &"player", 0, 0)
	# Always named from here on. If nothing was chosen, the dungeon picks one
	# and the player meets it in the sidebar -- the same bargain the shrines
	# make, where you learn what you have by looking rather than by being told.
	#
	# Rolled through the RUN's rng so a seeded game names the same character,
	# which keeps seeded tests and resumed saves honest.
	player.is_player = true
	player.faction = Entity.Faction.PLAYER
	player.max_hp = hp_at_level(1)
	player.hp = player.max_hp
	player.power = 5
	player.defense = 1
	player.light = LightSource.new(0, 0, TORCH_RADIUS,
		Color(1.00, 0.72, 0.36), Color(0.30, 0.34, 0.55), 1.0, true)
	if player_name.strip_edges() == "":
		player_name = Morgue.roll_name(rng)
	_shuffle_shrines()
	build_level()
	msg_log.add("You descend into the dark, torch guttering.", Color(0.85, 0.72, 0.45))

func build_level() -> void:
	# Salted differently from the grave rng, or the two side streams would
	# march in lockstep and a floor's graves would predict its magic.
	enchant_rng.seed = int(rng.seed) ^ (depth * 40503) ^ 0x5EED
	trader_rng.seed = int(rng.seed) ^ (depth * 2246822519) ^ 0x7AAD
	map = DungeonMap.new(MAP_W, MAP_H)
	light_map = LightMap.new(MAP_W, MAP_H)
	_fov_buffer.resize(MAP_W * MAP_H)
	_sight_buffer.resize(MAP_W * MAP_H)

	var gen := MapGen.new(rng)
	# Nothing below the bottom, and falling while climbing out would undo the
	# run rather than complicate it.
	gen.allow_pits = not ascending and depth < MAX_DEPTH
	gen.depth = effective_depth()
	gen.library = _vault_library
	gen.generate(map)

	# Whoever is walking with you comes along. Captured before `entities` is
	# replaced, and put back once the player has somewhere to stand.
	#
	# An ally used to end at the stairs, and every awkward rule around this
	# feature grew out of that one boundary: a forfeit clause, a speech about
	# being bound to the floor, and a cash-out hole underneath both. Letting
	# them follow deletes all three. What keeps it honest is that an ally
	# cannot be healed by anything -- see `_take_ai_turn` -- so it is a
	# decaying resource with a guaranteed end rather than a permanent party.
	var following: Array[Entity] = []
	for e in entities:
		if e.alive and not e.is_player and e.faction == Entity.Faction.PLAYER:
			following.append(e)

	entities = [player]
	ground = []
	static_lights = []
	_travel.clear()

	var rooms := gen.rooms
	# A caves-band floor can come back with no ROOMS at all -- caves are
	# reserved first and can leave nothing a room will fit in. A cave is still
	# somewhere to stand, so it stands in for one.
	#
	# Without this the fallback below fired on a perfectly good level and carved
	# its 11x7 chamber in the corner, unconnected to anything, then put the
	# player AND the stairs inside it. Traced from seed 66043 at depth 5: an
	# isolated 77-cell box against 821 cells of real dungeon the player could
	# never reach. It passed the completability test because the stairs were in
	# the box WITH you -- the floor was winnable and almost entirely invisible.
	#
	# Kept SEPARATE from `rooms` rather than substituted into it: the population
	# pass below indexes gen.archetypes by room number, so handing it caves
	# walks straight off the end of that array.
	var spots: Array[Rect2i] = rooms if not rooms.is_empty() else gen.caves
	if spots.is_empty():
		# Genuinely degenerate: no rooms AND no caves. Carve a chamber so the
		# game never wedges. This is now the last resort it was always meant to
		# be, rather than the routine handling for an all-cave floor.
		for y in range(1, 8):
			for x in range(1, 12):
				map.set_tile(x, y, Tiles.FLOOR)
		spots = [Rect2i(1, 1, 11, 7)] as Array[Rect2i]

	var start := _open_cell_in(spots[0])
	player.x = start.x
	player.y = start.y

	stairs = _open_cell_in(spots[-1])
	if ascending:
		map.set_tile(stairs.x, stairs.y, Tiles.STAIRS_UP)
	elif depth < MAX_DEPTH:
		map.set_tile(stairs.x, stairs.y, Tiles.STAIRS_DOWN)
	else:
		# The bottom. Where the stairs would have been, the amulet.
		var relic := Item.make(&"amulet")
		relic.x = stairs.x
		relic.y = stairs.y
		ground.append(relic)

	# The weight does not follow you down the stairs.
	player.speed = BASE_SPEED

	shrine_at.clear()
	for y in map.height:
		for x in map.width:
			if map.get_tile(x, y) == Tiles.SHRINE:
				shrine_at[Vector2i(x, y)] = rng.randi_range(0, Shrines.COUNT - 1)

	stats["deepest"] = maxi(int(stats.get("deepest", 0)), depth)
	cave_regions = gen.caves.duplicate()
	room_rects = gen.rooms.duplicate()
	hoard_room = -1
	for i in gen.archetypes.size():
		if gen.archetypes[i] == MapGen.Archetype.HOARD:
			hoard_room = i
			break
	brazier_charge.clear()
	ember_until.clear()
	grave_at.clear()
	grave_risen = false
	risen_grave = Vector2i(-1, -1)
	_last_grave = Vector2i(-1, -1)
	for y in map.height:
		for x in map.width:
			if map.get_tile(x, y) == Tiles.BRAZIER:
				brazier_charge[Vector2i(x, y)] = BRAZIER_CHARGE
	# Before the lights are gathered, because the hoard's brazier has to be one
	# of them -- static_lights is derived from the map in _gather_lights and
	# nothing re-derives it afterwards.
	_stock_the_hoard()
	_gather_lights()
	# After the hoard's brazier exists and before anything is placed, so a
	# guard spawned this turn already has somewhere to walk.
	_lay_the_beat()
	_place_graves()
	for i in range(1, rooms.size()):
		_populate_room(rooms[i], gen.archetypes[i])
	for region in gen.caves:
		_populate_cave(region)
	_place_vault_contents(gen)
	_place_first_gem()
	_place_chest()
	# Last, so the trader takes a cell nothing else wanted.
	_place_trader()
	vault_rects.clear()
	vault_names.clear()
	for spot in gen.vault_spots:
		vault_rects.append(spot["rect"])
		vault_names.append(spot["vault"].name)
	# AFTER the vault rects are recorded, because _corrupt_sites reads them to
	# keep out of authored rooms. Called any earlier and it would be checking
	# the previous floor's vaults.
	_place_corrupted()

	# AFTER the floor is populated, so `_nearest_restable` routes them around
	# whatever is already standing there. They arrive beside the player rather
	# than where they were: an ally that was across the map when you took the
	# stairs should not be lost for it.
	for ally in following:
		var spot := _nearest_restable(Vector2i(player.x, player.y))
		if spot.x < 0:
			continue
		ally.x = spot.x
		ally.y = spot.y
		entities.append(ally)

	pathfinder = Pathfinder.new(map)
	update_vision()

## Decoration can now put a pillar or a brazier on a room's exact centre, so
## neither the player nor the stairs can simply be dropped there any more.
## Somewhere a thing can be left lying, or something can stand.
##
## Walkable is not enough, and this is the second time that has bitten.
## Pits and traps are both walkable -- they have to be, or you could never
## step into one -- so `is_walkable` alone happily puts a dagger on a hole in
## the floor. That is not a hazard, it is a hazard BAITED: you cross the room
## to pick the thing up and lose a floor doing it. Reported from play, and it
## cost the run it happened in.
##
## The same rule keeps monsters off them. A monster standing on a pit is stuck
## there forever, because the pathfinder treats avoided ground as solid and so
## cannot plan a single step out of it.
func _can_rest_on(x: int, y: int) -> bool:
	return map.is_walkable(x, y) and not Tiles.is_avoided(map.get_tile(x, y))

func _open_cell_in(room: Rect2i) -> Vector2i:
	var c := room.get_center()
	var best := c
	var best_d := 1 << 30
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			# Never a pit: landing in one after falling through another would
			# be a chain the player never chose to start.
			if not map.is_walkable(x, y) or Tiles.is_avoided(map.get_tile(x, y)):
				continue
			var d := absi(x - c.x) + absi(y - c.y)
			if d < best_d:
				best_d = d
				best = Vector2i(x, y)
	return best

## Braziers are terrain now -- the generator places them, and the lighting
## rig is derived from the map rather than maintained alongside it.
func _gather_lights() -> void:
	static_lights = []
	for y in map.height:
		for x in map.width:
			var t := map.get_tile(x, y)
			if t == Tiles.BRAZIER:
				static_lights.append(LightSource.new(x, y, 6,
					Color(0.95, 0.55, 0.20), Color(0.35, 0.20, 0.30), 0.85, true))
			elif t == Tiles.FUNGUS:
				# Small and cold, so a fungus patch reads as its own thing and
				# never gets mistaken for firelight.
				static_lights.append(LightSource.new(x, y, 3,
					Color(0.34, 0.86, 0.62), Color(0.10, 0.28, 0.22), 0.45, false))

## How dangerous this floor is, as opposed to which floor it is.
##
## Descending they are the same. Climbing out they are not: floor 10 fights at
## depth 10 and floor 1, with the exit in sight, fights at depth 19. Tension
## should peak at the door, not ease off as you near it.
func effective_depth() -> int:
	if not ascending:
		return depth
	return MAX_DEPTH + (MAX_DEPTH - depth)

## Fisher-Yates through the run's own rng, so a seeded run always hides the
## same effect behind the same colour.
func _shuffle_shrines() -> void:
	shrine_hues = []
	for i in Shrines.COUNT:
		shrine_hues.append(i)
	for i in range(shrine_hues.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := shrine_hues[i]
		shrine_hues[i] = shrine_hues[j]
		shrine_hues[j] = swap
	shrine_known.clear()
	forge_cap_bonus = 0

func shrine_hue(kind: int) -> Color:
	if kind < 0 or kind >= shrine_hues.size():
		return Palette.UI_TEXT
	return Shrines.HUES[shrine_hues[kind]]

## What the player may call it. Unknown shrines are named by colour alone.
func shrine_label(kind: int) -> String:
	if shrine_known.has(kind):
		return Shrines.NAMES[kind]
	return "an unfamiliar shrine"

## The forging ceiling, which the anvil raises.
## Is the player wearing the ring right now?
##
## Asked of the equipped weapon rather than a flag, so there is exactly one
## place the truth lives and taking the ring off cannot leave the rat behind.
func ratted() -> bool:
	var held: Variant = player.equipped.get(Item.Slot.WEAPON, null)
	return held != null and held.transforms()

func upgrade_cap() -> int:
	return Item.MAX_UPGRADES + forge_cap_bonus

func item_can_upgrade(item: Item) -> bool:
	return item.can_be_forged() and item.upgrade_level() < upgrade_cap()

## What a step onto this cell costs, for this actor.
## Whether a step from (fx, fy) to (nx, ny) is legal.
##
## The corner rule: a diagonal step needs BOTH of the orthogonal cells beside
## it open. This is exactly what AStarGrid2D enforces with
## DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES, and the point of putting it here is that
## there were four ways to move and only one of them obeyed it.
##
## Hunting monsters route through the pathfinder, so they always did. The
## player, a fleeing monster and an erratic one all moved directly and checked
## only whether the destination was walkable -- so all three could slip through
## the joint between two walls that a hunter had to walk around. Six turns
## around, one turn through: a monster could be shaken off by stepping through
## a gap it was not allowed to follow you into.
##
## Attacks are deliberately NOT subject to this. Reach stays eight-way for
## everyone, which is what players expect and is symmetric. It is only the step
## that the walls get a say in.
func can_step(fx: int, fy: int, nx: int, ny: int) -> bool:
	if not map.is_walkable(nx, ny):
		return false
	if nx == fx or ny == fy:
		return true
	return map.is_walkable(nx, fy) and map.is_walkable(fx, ny)

func move_cost_for(actor: Entity, x: int, y: int) -> int:
	# Frost is on the CREATURE, not the ground, so it is charged before the
	# flying exemption rather than after. A chilled wyvern is still flying; it
	# is just flying badly, and a frost gem that did nothing to the things you
	# most want to slow down would be a gem nobody binds.
	var chill := GEM_FROST_COST if actor.chilled > 0 else 1.0
	if actor.flying:
		return int(round(Scheduler.ACTION_COST * chill))
	var m := Tiles.move_cost(map.get_tile(x, y))
	if actor.heavy and m > 1.0:
		m += 0.6
	return int(round(Scheduler.ACTION_COST * m * chill))

func room_threat_ceiling() -> int:
	return ROOM_THREAT_BASE + ROOM_THREAT_PER_DEPTH * effective_depth()

## What a TYPICAL cave can hold. Kept for callers that are asking about caves in
## general rather than about one particular cave.
func cave_threat_ceiling() -> int:
	return int(round(room_threat_ceiling() * CAVE_THREAT_SCALE))

## The walkable cavern inside a cave's bounding box.
##
## The box is not the cave -- a region is a rectangle with a cave carved through
## it, so the box overstates a narrow winding cavern badly. Counting the cells
## is the only honest measure of how much space is actually in there.
func cave_cells(region: Rect2i) -> int:
	var n := 0
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			if map.in_bounds(x, y) and map.is_walkable(x, y) \
					and map.material_at(x, y) == Materials.CAVERN:
				n += 1
	return n

## What THIS cave can hold, by how big it is.
##
## The flat 0.7 was backwards on its face, and measurement is what showed it: an
## average room is 79 cells and an average cave is 113 -- so a cave was 43%
## LARGER than a room and got 30% LESS danger budget. Per square of floor a cave
## was about half as dangerous as a room, while `_populate_cave`'s own comment
## claimed caves were "wilder than rooms, worth a little more danger". The
## constant and the comment had pointed opposite ways since they were written.
##
## The consequence was a whole class of creature quietly locked out of the place
## it is named for. A cave ceiling of 14 at depth 5 cannot afford a cave bear at
## 17, a cave troll at 16, a wyvern at 20 or a cave giant at 26 -- so the five
## entries carrying the strongest cave weightings in the bestiary were rejected
## on price before the weighting was ever consulted. Measured across rotated
## seeds, the creatures MOST flagged for caves turned up in them least: ogre and
## orc at 1.3-1.6 weight were in caves 43-46% of the time, while cave bear and
## cave troll at 2.2-2.6 managed 13%.
##
## Scaling by size fixes that without making the dark band harder, which was
## Brad's objection to simply raising the number: an average cave lands on 0.7
## exactly as before, so the band's total danger does not move. What moves is
## WHERE it sits. A big cavern can hold something big; a cramped one cannot.
## A floor typically carries one large cave, one small and a couple of ordinary
## ones, so this sorts them rather than lifting them.
func cave_threat_ceiling_for(cells: int) -> int:
	var scale := CAVE_THREAT_SCALE * float(cells) / float(CAVE_TYPICAL_CELLS)
	return int(round(room_threat_ceiling()
		* clampf(scale, CAVE_SCALE_MIN, CAVE_SCALE_MAX)))

## Makes sure the player meets a gem at least once, early.
##
## Runs after the ordinary loot has been scattered, and only if that loot did
## not already produce one -- so on a lucky floor this does nothing at all and
## the guarantee is invisible.
## Which room the generator marked as this band's hoard, or -1.
##
## Generation-time only: a restored save keeps the map it was
## built with and never re-runs this pass, so serialising it would store a fact
## about a floor that will never be generated again.
var hoard_room := -1

## What the band's hoard holds besides the chest: a fire to work at, and
## something to work on.
##
## The brazier is what makes it a room you STOP in rather than a container you
## empty. Measured before adding it, braziers already run about 5.4 a floor, so
## a guaranteed one here is a landmark rather than a power spike -- and it is
## the difference between "open chest, leave" and "this is where I forge the
## thing I just found".
func _stock_the_hoard() -> void:
	if hoard_room < 0 or hoard_room >= room_rects.size():
		return
	var room: Rect2i = room_rects[hoard_room]
	var lit := false
	# Off-centre on purpose: the middle is where _place_chest looks first, and
	# a brazier standing on the chest's cell would cost the room its chest.
	for y in range(room.position.y + 1, room.end.y - 1):
		for x in range(room.position.x + 1, room.end.x - 1):
			var c := Vector2i(x, y)
			if lit or c == room.get_center() or protected_cell(c):
				continue
			if map.get_tile(x, y) != Tiles.FLOOR:
				continue
			map.set_tile(x, y, Tiles.BRAZIER)
			brazier_charge[c] = BRAZIER_CHARGE
			lit = true
	var prize := Item.roll(rng, effective_depth(), enchant_rng)
	if prize != null:
		_drop_item_at(prize, _open_cell_in(room))

## One chest per band, on the band's middle floor.
##
## Brad's rarity call, and it is what stops a pack filling with gems: at a gem
## a floor they were loot, and the inventory was what suffered. A chest is a
## landmark instead -- you see it, you go to it.
##
## Keyed on the MIRRORED depth so the climb gets its own without a second
## table: effective 5 and effective 15 are both the cave band.
func _place_chest() -> void:
	var mirrored := Bands.mirrored(effective_depth())
	# The middle floor of each band, so you are never handed one on arrival
	# and never miss it by taking the stairs early.
	if not [2, 5, 8, 10].has(mirrored):
		return
	if room_rects.is_empty():
		return
	# Tried across every room rather than taken from one.
	#
	# The first version asked `_open_cell_in` for a single room's most central
	# cell and gave up if anything was there -- and by this point the rooms have
	# already been populated, so the middle of a room is exactly where a monster
	# or a piece of loot is standing. Measured: zero chests placed, on every
	# floor that should have carried one.
	# The hoard room first, then everything else.
	#
	# The scan used to start from the LAST room, which is where the stairs are
	# put -- so the band's landmark tended to land beside the exit, the one
	# place you were already going. Trying the hoard first is what gives the
	# chest a destination instead of a location.
	var order: Array[int] = []
	if hoard_room >= 0 and hoard_room < room_rects.size():
		order.append(hoard_room)
	for attempt in room_rects.size():
		var idx := (room_rects.size() - 1 + attempt) % room_rects.size()
		if idx != hoard_room:
			order.append(idx)
	var placed := false
	for which in order:
		var room: Rect2i = room_rects[which]
		for y in range(room.position.y, room.end.y):
			for x in range(room.position.x, room.end.x):
				var c := Vector2i(x, y)
				if c == stairs or c == Vector2i(player.x, player.y):
					continue
				if not _can_rest_on(x, y) or entity_at(x, y) != null:
					continue
				if not items_at(x, y).is_empty():
					continue
				# Never inside a hand-drawn room: an author who wanted a chest
				# in theirs can draw one, and one arriving uninvited would sit
				# on top of what they did draw.
				if protected_cell(c):
					continue
				# OPEN GROUND ONLY, and this is not fussiness.
				#
				# A chest is SOLID. Dropped on the square in front of a room's
				# only door it walls the room shut, and the first version did
				# exactly that: `and completable in every band` failed for
				# caves, fortress and deep at once, and a door was left leading
				# nowhere. Requiring all eight neighbours to be standable puts
				# it in the middle of open floor, where it can never be the
				# only way through.
				if not _ringed_by_floor(c):
					continue
				map.set_tile(x, y, Tiles.CHEST)
				placed = true
				break
			if placed:
				break
		if placed:
			break
	if not placed:
		return

## Is every one of the eight cells around this one standable?
##
## The test for "safe to make solid". Anything narrower than this -- a doorway,
## a corridor, the mouth of a room -- is somewhere a chest could seal.
func _ringed_by_floor(c: Vector2i) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var n := Vector2i(c.x + dx, c.y + dy)
			if not map.in_bounds(n.x, n.y):
				return false
			if not map.is_walkable(n.x, n.y):
				return false
			var t := map.get_tile(n.x, n.y)
			if t == Tiles.DOOR_CLOSED or t == Tiles.DOOR_OPEN:
				return false
	return true

## Lifting the lid.
##
## No lock, because there are no keys -- and adding them means world generation
## that guarantees a key is reachable BEFORE its door, a constraint problem
## whose failure mode is a floor you cannot finish. Brad: "no one leaves a
## chest just open, that's the dungeon master leaving a cursed item disguised
## as a good one." So the price is noise rather than a key.
func _open_chest(at: Vector2i) -> void:
	map.set_tile(at.x, at.y, Tiles.FLOOR)
	pathfinder = Pathfinder.new(map)
	_travel.clear()
	events.append({"kind": &"forge", "to": at})

	# A unique first, if the run has not produced one yet -- they are one per
	# dungeon and a chest is the only way to one. Gems are what a chest holds
	# once the uniques are spent.
	var prize: Item = null
	for key in Item.uniques(effective_depth()):
		if not uniques_found.has(key):
			prize = Item.make(key)
			uniques_found[key] = true
			break
	if prize == null:
		prize = Item.roll_gem(rng, effective_depth())
	if prize != null:
		_drop_item_at(prize, at)
		gem_found = true
		msg_log.add("The lid gives. A %s lies inside." % prize.name,
			Color(0.90, 0.85, 0.60))
	else:
		msg_log.add("The lid gives. Whatever was in it is long gone.",
			Color(0.70, 0.66, 0.60))

	# Louder than the fight that earned it. The ladder: combat 6, bones 7, a
	# banshee 9, the forge 10.
	if rng.randf() < CHEST_TRAP_CHANCE:
		msg_log.add("The hinges shriek. That carried.", Color(0.95, 0.70, 0.40))
		_make_noise(at, CHEST_NOISE, &"forge")

## The floors a trader stands on: the FIRST of each band, going down and coming
## back up.
##
##     1, 4, 7   upper, caves, fortress on the descent
##     11, 14, 17  fortress, caves, upper on the climb
##
## Floor 10 has none on purpose -- it is the amulet's own floor and it is meant
## to be met alone.
##
## Six in a full run, which is the number that prices everything the trader will
## eventually sell. Derived from Bands rather than listed by hand would be
## tidier, but a band's FIRST floor is not something Bands can answer: mirrored()
## folds 11 onto 9, and 9 is a band's last floor, not its first.
const TRADER_FLOORS := [1, 4, 7, 11, 14, 17]

## Where the trader stands, once per floor that has one. Null everywhere else.
var trader: Entity = null

## Stood in a room, not wandering.
##
## On floor ONE specifically, as close to where you woke as a room away, because
## that trader carries the story and a player who never finds them never learns
## why they are down here. Everywhere else they are simply somewhere on the
## floor and finding them is the player's business -- the legend says a trader
## exists, which is enough of a hint to go looking.
## Somewhere in this room a trader can stand without being in the way.
##
## Nearest the middle, like _open_cell_in, but refusing the things that matter
## for something that occupies its cell permanently and cannot be pushed past:
## either staircase, the player's own square, and anything already standing
## there. Answers (-1, -1) when the room has nowhere suitable.
func _trader_cell(room: Rect2i) -> Vector2i:
	var c := room.get_center()
	var best := Vector2i(-1, -1)
	var best_d := 1 << 30
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			var here := Vector2i(x, y)
			var t := map.get_tile(x, y)
			if not map.is_walkable(x, y) or Tiles.is_avoided(t):
				continue
			if here == stairs:
				continue
			# Nor on a feature. Reported from play: the trader was standing on
			# a shrine, which hid it and put a conversation on top of a thing
			# you use. Doors and graves are walkable too and equally wrong --
			# a trader in a doorway blocks it, since bumping talks rather than
			# swapping.
			#
			# Same shape as the stairs bug: anything that holds its cell
			# permanently has to ask what is already there, and `walkable` is
			# not the same question as `empty`.
			if t == Tiles.SHRINE or t == Tiles.GRAVE \
					or t == Tiles.DOOR_CLOSED or t == Tiles.DOOR_OPEN:
				continue
			# Whatever the player is standing on when the floor is built is the
			# way they came in, and blocking it strands them on arrival.
			if player != null and here == Vector2i(player.x, player.y):
				continue
			if entity_at(x, y) != null:
				continue
			var d := absi(x - c.x) + absi(y - c.y)
			if d < best_d:
				best_d = d
				best = here
	return best

func _place_trader() -> void:
	trader = null
	if not TRADER_FLOORS.has(effective_depth()):
		return
	if room_rects.is_empty():
		return

	# The first floor's trader is deliberately findable: the nearest room that
	# is not the one you are standing in. Missing them is possible -- the stairs
	# might be the other way -- but it should take bad luck rather than being
	# the default.
	var want := 0
	if room_rects.size() > 1:
		if effective_depth() == 1:
			var home := room_rects[0].get_center()
			var best := 1 << 30
			for i in range(1, room_rects.size()):
				var c := room_rects[i].get_center()
				var d := absi(c.x - home.x) + absi(c.y - home.y)
				if d < best:
					best = d
					want = i
		else:
			want = trader_rng.randi_range(1, room_rects.size() - 1)
	# NOT _open_cell_in, which picks the cell nearest the room's centre and
	# knows nothing about what is standing on it. That is fine for an item --
	# a potion lying on the stairs is a potion you pick up on your way down --
	# and it is a softlock for the trader.
	#
	# Reported from play: the trader was standing ON the stairs. Walking into it
	# TALKS rather than swapping places, which is what makes it a conversation
	# and not a shove, so the player could not reach the stairs at all and the
	# floor had no exit.
	#
	# Tries the chosen room first and then every other room, because "no
	# trader" is a better failure than "no way down".
	var at := _trader_cell(room_rects[want])
	if at.x < 0:
		for i in room_rects.size():
			if i == want:
				continue
			at = _trader_cell(room_rects[i])
			if at.x >= 0:
				break
	if at.x < 0:
		return

	var t := Entity.new("trader", &"trader", at.x, at.y)
	# NEUTRAL is the whole point, and this is its first use in the game. It
	# fights nobody and nobody fights it -- see Entity.hostile_to. A monster
	# that walked into a trader and killed it would delete the floor's only
	# conversation, and the player would never know it had been there.
	t.faction = Entity.Faction.NEUTRAL
	t.max_hp = 1
	t.hp = 1
	t.power = 0
	t.threat = 0
	# Never rolled into the watch and never given a beat: standing still is what
	# makes them findable, and a trader who wandered off would turn "there is a
	# trader on this floor" into a lie the legend tells.
	t.alertness = Entity.Alert.AWAKE
	# Not SLEEPING, which would draw the "z" over their head and invite the
	# player to stab them in their sleep.
	t.activity = Entity.Activity.PATROLLING
	t.patrols = false
	t.scavenges = false
	entities.append(t)
	trader = t

## Opens a sack, and hands back whatever the tables gave.
##
## Every branch calls a generator that already exists. The point of the sack is
## that it is a REUSABLE drop: anything that hoards rather than wears can carry
## one, and none of them need to know what a sack contains.
##
## Rolls at effective_depth(), so the floor it is opened on decides the draw.
func _open_sack() -> bool:
	var at := effective_depth()
	var roll := rng.randf()
	var prize: Item = null
	var said := ""

	if roll < SACK_WEAPON:
		prize = Item.roll_equipment(rng, at, Item.Slot.WEAPON, enchant_rng)
		said = "Something with an edge."
	elif roll < SACK_ARMOUR:
		prize = Item.roll_equipment(rng, at, Item.Slot.ARMOR, enchant_rng)
		said = "Something to put between you and the dark."
	elif roll < SACK_MAGIC:
		# An ordinary weapon, then the floor's own enchant applied until it
		# takes. Not a separate magic table: routing it through the same
		# accepts_element() rules means a sack can never produce a sling of
		# frost, which the gem system forbids a player from making.
		for _try in 12:
			prize = Item.roll_equipment(rng, at, Item.Slot.WEAPON)
			if prize == null:
				break
			Item._maybe_enchant(prize, enchant_rng, GameState.MAX_DEPTH * 2)
			if prize.element != &"":
				break
		said = "It hums."
	else:
		prize = Item.roll_gem(rng, at)
		said = "A stone, and warm."

	if prize == null:
		# The tables had nothing legal at this depth. Refuse rather than
		# consume: an item that vanishes and gives nothing is a bug report.
		msg_log.add("The sack is empty.", Color(0.7, 0.6, 0.4))
		return false

	_drop_item_at(prize, Vector2i(player.x, player.y))
	msg_log.add("You open the sack. %s a %s." % [said, prize.display_name()],
		Color(0.85, 0.80, 0.60))
	return true

func _place_first_gem() -> void:
	if gem_found or ascending:
		return
	if not GEM_PITY_FLOORS.has(depth):
		return
	for it in ground:
		if it.kind == Item.Kind.GEM:
			gem_found = true
			return
	# There WAS a third test here, and removing it is the fix rather than an
	# omission.
	#
	# It read the player's equipped gear and treated any element as proof that
	# a gem had been met. That inference was sound while binding was the only
	# way an element could exist, and the found-magic generator ended that: a
	# weapon can now arrive enchanted, so the check fired for a player who had
	# never seen a gem.
	#
	# Measured, same seeds, the only difference being the player's weapon:
	# bare-handed, 0 of 120 pity floors went without a gem; carrying a
	# generated enchanted weapon, 120 of 120 did. Not a rare miss -- the
	# guarantee stopped existing. Reachable on roughly one run in ten, which is
	# how often the strongest weapon on depth one is also the magic one.
	#
	# It is deleted rather than repaired because it was never load-bearing.
	# Every genuine way to meet a gem already sets `gem_found` where it
	# happens -- a chest (_place_chest), a heard prayer (_pray_at_shrine), a
	# gem lying on this floor (just above), the pity gem itself -- and the flag
	# is saved and restored with the run. Nothing reaches these lines having
	# truly met one. Tightening the test to "was this element BOUND" would have
	# meant a new field on Item recording provenance, to answer a question
	# nothing else asks.
	#
	# The cost is a save written before `gem_found` existed, carrying a bound
	# gem: that run may be offered one extra gem on depths 2-4. One spare stone
	# is a smaller wrong than a guarantee that silently does not apply.

	# The FARTHEST room from where you woke up, and never room 0.
	#
	# It used to go in room_rects[0], which is the room you start in -- and
	# `_populate_room` deliberately skips index 0, so the pity gem landed in the
	# one room on the floor guaranteed to hold no monsters, a few paces from
	# your feet. Reported from play as "there is a gem waiting for me when I
	# start", which is exactly what it was.
	#
	# That turned a safety net into a gift. A gem you find in a room you cleared
	# reads as loot; a gem lying beside you on arrival reads as the game
	# apologising for its own drop rates. Same item, opposite meaning -- and the
	# placement is the whole difference.
	var where := Rect2i(1, 1, map.width - 2, map.height - 2)
	if room_rects.size() > 1:
		var home := room_rects[0].get_center()
		var best := -1
		for i in range(1, room_rects.size()):
			var c := room_rects[i].get_center()
			var d := absi(c.x - home.x) + absi(c.y - home.y)
			if d > best:
				best = d
				where = room_rects[i]
	elif not room_rects.is_empty():
		where = room_rects[0]
	var at := _open_cell_in(where)
	if at.x < 0:
		return
	# Drawn from the same table as everything else rather than from a
	# hand-picked favourite, so which element you meet first is still yours to
	# discover. Retried because the roll is weighted across the whole catalogue
	# and most of it is not a gem.
	var gem := Item.roll_gem(rng, effective_depth())
	if gem == null:
		return
	gem.x = at.x
	gem.y = at.y
	ground.append(gem)
	gem_found = true

func _populate_room(room: Rect2i, archetype: int) -> void:
	if rng.randf() < 0.55:
		var ix := rng.randi_range(room.position.x, room.end.x - 1)
		var iy := rng.randi_range(room.position.y, room.end.y - 1)
		if _can_rest_on(ix, iy) and Vector2i(ix, iy) != stairs and items_at(ix, iy).is_empty():
			var loot := Item.roll(rng, effective_depth(), enchant_rng)
			if loot != null:
				loot.x = ix
				loot.y = iy
				ground.append(loot)

	# A shrine keeps a guardian; a collapsed room is where things nest.
	#
	# The shrine keeps a heavier one since prayers started paying twice. It was
	# already a boon you gamble for; it is now a boon AND a three-in-ten chance
	# of a gem, and a room worth visiting more should cost more to stand in.
	var bonus := 0
	if archetype == MapGen.Archetype.HOARD:
		# The heaviest room on the floor, because it is the one worth crossing
		# the floor for. A reward that costs nothing to take reads as an
		# apology -- which is exactly what the pity gem lying in the starting
		# room turned out to be, and this is the same mistake at four times the
		# scale if the room is left undefended.
		bonus = 3
	elif archetype == MapGen.Archetype.SHRINE:
		bonus = 2
	elif archetype == MapGen.Archetype.COLLAPSED:
		bonus = 1
	# The count roll is unchanged -- density is intentional. The ceiling only
	# stops that count from landing on something unsurvivable.
	var count := rng.randi_range(0, 2 + effective_depth() / 3) + bonus
	var spent := 0
	var ceiling := room_threat_ceiling()
	for _i in count:
		var cost := _spawn_in(Rect2i(room.position, room.size), ceiling - spent)
		if cost < 0:
			break
		spent += cost

## The climb's own population, bought from its own budget.
##
## A SEPARATE pool, worth the effective depth in threat points, spent after the
## room ceiling has already been spent. Additive rather than competing: the
## descent's behaviour is untouched, and the extra danger on the climb is a
## number you can state -- ceiling + depth, so 42 + 16 at effective 16, about
## 38% more than the floor would otherwise carry.
##
## Growing with depth rather than being a flat bonus is what makes the climb
## ramp. Eleven points near the bottom buys two things; nineteen near the top
## buys four or five.
func _place_corrupted() -> void:
	if not ascending:
		return
	var pool := effective_depth()
	var open_cells := _corrupt_sites()
	if open_cells.is_empty():
		return
	# Spend until nothing affordable is left. The last few points buying one
	# more cheap body is the point of a floor cost rather than a percentage.
	for _guard in 40:
		if pool < CORRUPT_MIN_COST or open_cells.is_empty():
			return
		var entry := _roll_corruptible(pool)
		if entry.is_empty():
			return
		var at: Vector2i = open_cells.pop_back()
		if entity_at(at.x, at.y) != null:
			continue
		var m := monster_from(entry, at.x, at.y)
		_set_the_watch(m)
		_corrupt(m)
		entities.append(m)
		pool -= m.threat

## Makes a creature worse, and charges for it honestly.
##
## The threat rises with the stats, which is what keeps the pool arithmetic
## true: a corrupted thing costs what it is worth, so "nineteen points" means
## nineteen points of danger rather than nineteen points of accounting.
func _corrupt(m: Entity) -> void:
	m.corrupted = true
	m.max_hp = int(round(float(m.max_hp) * CORRUPT_SCALE))
	m.hp = m.max_hp
	m.power = int(round(float(m.power) * CORRUPT_SCALE))
	m.defense = int(round(float(m.defense) * CORRUPT_SCALE))
	m.threat = maxi(CORRUPT_MIN_COST, int(round(float(m.threat) * CORRUPT_SCALE)))
	m.name = "corrupted %s" % m.name

## Something cheap enough to afford, drawn WITHOUT the tier fade.
##
## The fade is the whole reason this function exists. Low-tier creatures are
## never excluded from a floor by cost -- a rat is two threat and always
## affordable -- they are excluded because `weight` decays to zero about six
## depths past their `min_depth`. Corruption is a way to re-admit exactly those
## entries, so applying the fade here would rule out everything it can choose
## from. `_roll_monster` is left alone and keeps fading the main population.
func _roll_corruptible(budget: int) -> Dictionary:
	var pool := []
	for e in BESTIARY:
		if int(e["min_depth"]) > 3 or int(e["threat"]) > CORRUPT_MAX_BASE:
			continue
		# Events rather than populations -- the banshee caps itself per floor
		# and has no business arriving in fours.
		if e.has("max_per_floor") or e.has("ascent_from"):
			continue
		var cost := maxi(CORRUPT_MIN_COST,
			int(round(float(e["threat"]) * CORRUPT_SCALE)))
		if cost > budget:
			continue
		pool.append(e)
	if pool.is_empty():
		return {}
	return pool[rng.randi_range(0, pool.size() - 1)]

## Standing ground away from the player, shuffled, for corrupted arrivals.
##
## THE CORRIDORS, never the rooms. This is not a preference, it is the
## survivability guarantee: `room_threat_ceiling()` promises that the room you
## walk into can be beaten, and `_test_threat_ceiling_holds_on_the_climb`
## checks it room by room. Rooms have already spent that budget by the time
## this runs, so dropping corrupted things into them stacks straight through
## the ceiling -- measured at 218 breaches across 2027 rooms, worst 15 over,
## and it shipped before the suite caught it.
##
## Corridors carry no such promise, and they are the better place anyway: you
## meet the trash BETWEEN rooms, strung out and in the open, which is where
## being swarmed by cheap things actually costs you something.
func _corrupt_sites() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in map.height:
		for x in map.width:
			if not _can_rest_on(x, y) or Vector2i(x, y) == stairs:
				continue
			if Los.steps(x, y, player.x, player.y) < 8:
				continue
			var indoors := false
			for room in room_rects:
				if room.has_point(Vector2i(x, y)):
					indoors = true
					break
			if not indoors:
				for vr in vault_rects:
					if vr.has_point(Vector2i(x, y)):
						indoors = true
						break
			if not indoors:
				out.append(Vector2i(x, y))
	for i in range(out.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := out[i]
		out[i] = out[j]
		out[j] = t
	return out

func _populate_cave(region: Rect2i) -> void:
	# Caves are wilder than rooms, and unlit -- worth a little more danger.
	var count := rng.randi_range(1, 3 + effective_depth() / 3)
	var spent := 0
	# Budgeted by how big this cave actually is. The one-den-per-floor boost
	# this replaces was a patch on the same wound: it let exactly one cave a
	# floor afford a bear, which moved the bear from 0% of caves to 13% and left
	# the other five caves as unable to hold one as before.
	var ceiling := cave_threat_ceiling_for(cave_cells(region))
	for _i in count:
		var cost := _spawn_in(region, ceiling - spent)
		if cost < 0:
			break
		spent += cost
	_make_a_den(region)

## Bones where a bear lives, and nowhere else in a cave.
##
## Brad's rule, and it is better than the one it replaced. Letting caves roll
## BONEYARD the way rooms do would have made bones a texture -- scenery you
## stop reading after the third floor. Tying them to the bear makes them a
## TELL: litter in a cave means something large eats here, and you know that
## before you can see what it is. Bears eat; what they eat does not walk out.
##
## It pays for itself twice, because bones are noise 7. Blunder through the
## den and you announce yourself to the thing whose den it is -- so the warning
## and the punishment for ignoring it are the same tiles.
##
## Deliberately not applied to every large predator. A troll or a giant in a
## cave would spread this thin, and a tell that fits three creatures tells you
## nothing about which one.
func _make_a_den(region: Rect2i) -> void:
	for e in entities:
		if not e.alive or e.appearance != &"bear":
			continue
		if not region.has_point(Vector2i(e.x, e.y)):
			continue
		# Around the bear rather than over the whole cave: a den has a centre,
		# and the litter thinning outwards is what says which way to back off.
		_scatter_bones_around(Vector2i(e.x, e.y), rng)
		return

## Returns the threat spent, or -1 if nothing was placed.
func _spawn_in(area: Rect2i, remaining: int) -> int:
	var mx := rng.randi_range(area.position.x, area.end.x - 1)
	var my := rng.randi_range(area.position.y, area.end.y - 1)
	return _spawn_at(Vector2i(mx, my), -1, remaining)

func _spawn_at(at: Vector2i, tier: int, remaining: int) -> int:
	var mx := at.x
	var my := at.y
	if not _can_rest_on(mx, my) or entity_at(mx, my) != null:
		return 0
	if Vector2i(mx, my) == stairs or Vector2i(mx, my) == Vector2i(player.x, player.y):
		return 0
	var pick := _roll_monster(remaining, tier)
	if pick.is_empty():
		return -1
	var m := monster_from(pick, mx, my)
	_set_the_watch(m)
	# Gear raises what a monster is actually worth facing, so it must raise the
	# threat too. Otherwise a room of armed orcs quietly costs more than its
	# ceiling claims, and the survivability guarantee becomes a lie.
	m.threat += _arm_monster(m, pick, remaining - m.threat)
	entities.append(m)
	return m.threat

## A bestiary entry, made flesh.
##
## Public and static because the TEST SUITE needs it too, and that is the whole
## reason it exists as a function. The suite used to build monsters with its own
## hand-copied version of this list, and three times running a new field was
## added here and forgotten there -- standoff and blink for the casters, then
## phasing, senses and the wail for the banshee. Each time the tests reported
## behaviour the game does not have, which is worse than reporting nothing.
## One list, two callers, no drift.
static func monster_from(entry: Dictionary, x: int, y: int) -> Entity:
	var m := Entity.new(entry["name"], entry["app"], x, y)
	m.max_hp = entry["hp"]
	m.hp = entry["hp"]
	m.power = entry["power"]
	m.defense = entry["def"]
	m.speed = entry["speed"]
	m.ai = entry.get("ai", &"hunter")
	# CAPABILITY, not state. `patrols` says this kind of creature is the sort
	# that walks a beat; whether THIS one currently is gets rolled at spawn --
	# see `_set_the_watch`. Setting it here made every kobold, goblin and orc
	# in the dungeon patrol, which measured at 39-59% of all monsters awake and
	# moving, halved the value of the rat ring and quietly raised difficulty at
	# an unchanged threat ceiling.
	#
	# Foraging is not rolled: a rabbit is always a rabbit.
	m.patrols = entry.get("patrol", false)
	m.scavenges = entry.get("scavenge", false)
	if m.ai == &"forager":
		m.activity = Entity.Activity.FEEDING
	m.attack_range = entry.get("range", 1)
	m.standoff = entry.get("standoff", 1)
	m.blink_range = entry.get("blink", 0)
	m.phasing = entry.get("phasing", false)
	m.knockback = int(entry.get("knockback", 0))
	m.unliving = entry.get("unliving", false)
	m.resists.clear()
	for r in entry.get("resists", []):
		m.resists.append(StringName(r))
	m.weak_to.clear()
	for w in entry.get("weak_to", []):
		m.weak_to.append(StringName(w))
	m.charges = entry.get("charges", false)
	m.senses = entry.get("senses", false)
	m.wail_radius = entry.get("wail", 0)
	m.flee_below = entry.get("flee", 0.0)
	m.regen = entry.get("regen", 0)
	m.flying = entry.get("flying", false)
	m.heavy = entry.get("heavy", false)
	m.threat = int(entry["threat"])
	return m

## Arms a monster within whatever threat budget is left, returning what the
## gear cost. Anything it cannot afford, it does not get.
func _arm_monster(m: Entity, pick: Dictionary, spare: int) -> int:
	var chance: float = pick.get("gear", 0.0)
	if chance <= 0.0 or rng.randf() >= chance:
		return 0

	var spent := 0
	for slot in [Item.Slot.WEAPON, Item.Slot.ARMOR]:
		if rng.randf() > 0.65:
			continue
		var it := Item.roll_equipment(rng, effective_depth(), slot, enchant_rng)
		if it == null:
			continue
		# Melee only. A goblin handed a bow would carry reach its `pack` AI
		# never uses, which reads as a bug rather than a surprise.
		if it.range_bonus > 1:
			continue
		var cost := it.power_bonus + it.defense_bonus
		if spent + cost > spare:
			continue
		m.equipped[slot] = it
		m.inventory.append(it)
		spent += cost
	return spent

## Whatever a corpse leaves behind.
## The stone goes quiet for good once the thing under it has been put down.
##
## Crosses the death off in the morgue as well, so it can never be fought for a
## second copy of the same gear in a later run. The line is MARKED, never
## removed -- see Morgue.mark_reclaimed, which adds a clause and rewrites via a
## temp file rather than editing the one unregenerable file in the game.
func _settle_the_grave() -> void:
	if risen_grave.x < 0:
		return
	# Crossed off before the record goes, and across runs -- the save is
	# per-run, so marking it there would let the same dead character be beaten
	# again next time for another copy of the same gear.
	var rec: Dictionary = grave_at.get(risen_grave, {})
	if rec.has("line"):
		Morgue.mark_reclaimed(MORGUE_PATH, String(rec["line"]))
	if map.get_tile(risen_grave.x, risen_grave.y) == Tiles.GRAVE:
		map.set_tile(risen_grave.x, risen_grave.y, Tiles.FLOOR)
	grave_at.erase(risen_grave)
	if risen_grave == _last_grave:
		_last_grave = Vector2i(-1, -1)
	risen_grave = Vector2i(-1, -1)
	msg_log.add("The headstone crumbles. Whatever was owed here is paid.",
		Color(0.70, 0.72, 0.78))

func _drop_loot(victim: Entity) -> void:
	if victim.appearance == &"rabbit" or victim.appearance == &"killer_rabbit" \
			or victim.appearance == &"bear":
		_drop_meat(victim)
	# A golem falls apart into what it was made of, and what it was throwing.
	#
	# Brad's idea, and it closes the loop: the thing made of rock arms you
	# against the next one. Rubble knaps into sling stones, a sling is blunt,
	# and blunt is what golems are weak to -- so its corpse is ammunition for
	# killing its kin. Nothing here is new; it is four existing rules meeting.
	# A hoard, for the one thing in the dungeon that hoards.
	#
	# Reported by a player who lost three runs getting back to the dragon and
	# was handed nothing for winning: it wears no armour and carries no blade,
	# so the ordinary drop path had nothing of its to give. A sack is the
	# answer rather than a bespoke table, because "this creature kept treasure
	# instead of wearing it" is a thing several creatures could be.
	#
	# It is placed rather than rolled, so killing the dragon always pays. What
	# it pays is still the sack's roll, and it rolls at the depth you open it.
	if victim.appearance == &"dragon":
		var hoard := Item.make(&"sack")
		if hoard != null:
			_drop_item_at(hoard, Vector2i(victim.x, victim.y))

	if victim.appearance == &"golem":
		var at := Vector2i(victim.x, victim.y)
		if map.in_bounds(at.x, at.y) and map.get_tile(at.x, at.y) == Tiles.FLOOR \
				and not protected_cell(at):
			map.set_tile(at.x, at.y, Tiles.RUBBLE)
			msg_log.add("The golem comes apart into a heap of stone.",
				Color(0.78, 0.74, 0.66))
	# Where it fell, unless where it fell is a hole. Nothing can spawn on a
	# hazard any more, but a monster can be pushed or blinked onto one later.
	var at := Vector2i(victim.x, victim.y)
	if not _can_rest_on(at.x, at.y):
		at = _nearest_restable(at)
		if at.x < 0:
			victim.equipped.clear()
			victim.inventory.clear()
			return
	# A risen grave leaves exactly one thing: the bone.
	#
	# Its gear goes ONTO the bone rather than onto the floor, so that from here
	# on exactly one copy of that kit exists anywhere in the world. You get it
	# back when whoever is carrying it finally falls -- which they will, because
	# an ally cannot be healed.
	#
	# This is the rule that dissolved a whole family of problems. While the
	# gear dropped here AND the ally wore a remembered copy, the same chain
	# mail was being worn twice; closing that at the stairs needed a forfeit
	# rule, and the forfeit rule opened a cash-out (summon on the staircase,
	# descend, keep the plate). Conserving the kit from the start means none of
	# those rules have to exist.
	if victim.risen:
		_leave_a_bone(victim, at)
		victim.equipped.clear()
		victim.inventory.clear()
		return
	for slot in victim.equipped:
		var it: Item = victim.equipped[slot]
		# An ally hands back ALL of it, because what it is wearing is the only
		# copy there is. Everything else rolls per item.
		#
		# This gear is the player's own, lost on this floor in an earlier run,
		# and the whole point of the mechanic is reclaiming it. A per-item roll
		# would turn "beat your own corpse and get your bow back" into "beat
		# your own corpse and maybe get nothing", which is a worse offer than
		# not having the mechanic.
		if victim.faction != Entity.Faction.PLAYER and not it.scavenged \
				and rng.randf() > LOOT_DROP_CHANCE:
			continue
		it.x = at.x
		it.y = at.y
		it.letter = ""
		ground.append(it)
		msg_log.add("It drops the %s." % it.display_name(), Color(0.72, 0.78, 0.90))
	victim.equipped.clear()
	victim.inventory.clear()

## What is left of somebody you put back down.
##
## Dropped on the floor rather than handed straight to the pack, so it obeys
## every rule an item already has: it can be left behind, it shows in the look
## panel, and a full inventory is a real decision rather than a silent loss.
##
## The gear is copied by NAME, the same words the morgue writes, so that
## rebuilding the ally later goes through `Item.from_display_name` -- the one
## path that already turns those words back into items. Nothing here needs to
## know what a chain mail is.
func _leave_a_bone(victim: Entity, at: Vector2i) -> void:
	var bone := Item.make(&"bone")
	# "risen Erdrick" was named from the stone; the bone is Erdrick's.
	bone.bone_name = victim.name.trim_prefix("risen ").strip_edges()
	if bone.bone_name == "":
		bone.bone_name = "Nameless"
	# The PACK, not just the hands. A character buried with a bow and an axe
	# has only one of them equipped, and recording the equipped slots alone
	# would quietly lose the other -- which is exactly the second weapon the
	# ally needs in order to have a choice at all.
	for it in victim.inventory:
		bone.bone_gear.append(it.display_name())
	bone.bone_level = victim.level
	bone.name = Item.bone_label(bone.bone_name)
	bone.x = at.x
	bone.y = at.y
	bone.letter = ""
	ground.append(bone)
	msg_log.add("Among the bones, one is still warm. What they carried "
		+ "went with it.", Color(0.70, 0.85, 0.75))

## How far from the player an ally will chase something before it gives up and
## comes back.
##
## A leash, and the reason for one is not balance but legibility: an unleashed
## ally walks off after the nearest thing on the floor, and the player loses
## track of where their help is. Eight is the same order as a monster's notice
## range, so the ally ranges about as far as the things it is fighting.
const ALLY_LEASH := 8

## How long a corpse stays warm enough for the shovel.
##
## Five turns, and the window IS the item. It is short enough that you are
## digging the thing you just killed rather than shopping a battlefield, and it
## makes the order you kill things in matter at the end of a fight: finish the
## troll last, or raise the rat.
const SHOVEL_WINDOW := 5

## How far from the PLAYER an ally at heel will reach to strike.
##
## Two, not one. At one it would only hit what is already beside it, which
## means something attacking you from your far side goes unanswered while your
## bodyguard stands there -- a guard that cannot step around you is not
## guarding. Two lets it cover the cells around you without ever leaving them.
const ALLY_HEEL_REACH := 2

## Weighted by tier, and filtered to what still fits under the ceiling.
##
## A monster is at full weight for its own tier and a grace depth after it,
## then fades. That is what stops depth 9 from spawning giant rats, and it is
## also why the ceiling alone would not be enough: without the fade, deep
## floors would just be many cheap monsters instead of few expensive ones.
## Vault contents are the author's, but they still answer to the level's threat
## ceiling: an over-stuffed vault drops what it cannot afford rather than
## producing a room nobody could survive.
func _place_vault_contents(gen: MapGen) -> void:
	var spent := 0
	var ceiling := room_threat_ceiling()
	for entry in gen.vault_contents:
		var ch: String = entry["ch"]
		var at: Vector2i = entry["pos"]
		match ch:
			"m", "M":
				# A guardian is drawn from two tiers deeper than the floor.
				var tier := effective_depth() + (2 if ch == "M" else 0)
				# _spawn_at answers in three ways and they are not
				# interchangeable: a positive number is threat spent, 0 means
				# that particular cell was unusable (occupied, or the stairs
				# landed on it) and the next marker should still be tried, and
				# -1 means nothing in the bestiary fits what is left of the
				# budget. Adding -1 to `spent` REFUNDS a point of threat for
				# failing, which is backwards; `_spawn_in`'s caller already
				# reads it correctly.
				#
				# That caller breaks and this one continues, on purpose. This
				# loop walks EVERY marker in the vault, loot included, so
				# breaking on an unaffordable monster would also throw away the
				# scroll behind it -- an over-budget room would quietly become
				# an empty one. Skipping just the monster leaves the room
				# under-populated, which is the honest outcome.
				var cost := _spawn_at(at, tier, ceiling - spent)
				if cost < 0:
					continue
				spent += cost
			"?":
				_drop_item_at(Item.roll(rng, effective_depth(), enchant_rng), at)
			"!":
				_drop_item_at(Item.make(&"potion_healing"), at)
			")":
				_drop_item_at(Item.roll_equipment(rng, effective_depth(),
					Item.Slot.WEAPON, enchant_rng), at)
			"[":
				_drop_item_at(Item.roll_equipment(rng, effective_depth(),
					Item.Slot.ARMOR, enchant_rng), at)
			"}":
				_drop_item_at(_roll_launcher(), at)
			"(":
				# A sack, placed rather than rolled. The sack decides its own
				# contents when opened -- see _open_sack -- so an author is
				# choosing "something worth carrying is here", not choosing what
				# it is. That keeps a hand-drawn room from handing out a
				# specific prize the tables would never have given it.
				_drop_item_at(Item.make(&"sack"), at)

## Vault loot goes where the author put it -- unless a later pass turned that
## cell into a hazard, in which case it is nudged to a neighbour rather than
## dropped down a hole.
func _drop_item_at(it: Item, at: Vector2i) -> void:
	if it == null:
		return
	var where := at
	if not _can_rest_on(where.x, where.y):
		where = _nearest_restable(at)
		if where.x < 0:
			return
	it.x = where.x
	it.y = where.y
	ground.append(it)

## The closest cell something can safely sit on, searched outward. Returns
## (-1, -1) when there is nowhere, which is possible in a tightly authored
## vault and means the item is simply not placed.
func _nearest_restable(at: Vector2i) -> Vector2i:
	for radius in range(1, 4):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var c := at + Vector2i(dx, dy)
				if _can_rest_on(c.x, c.y) and items_at(c.x, c.y).is_empty():
					return c
	return Vector2i(-1, -1)

func _roll_launcher() -> Item:
	var pool := []
	for key in Item.CATALOGUE:
		var data: Dictionary = Item.CATALOGUE[key]
		if int(data.get("range", 1)) > 1 and int(data["min_depth"]) <= effective_depth():
			pool.append(key)
	if pool.is_empty():
		return null
	return Item.make(pool[rng.randi_range(0, pool.size() - 1)])

func _roll_monster(remaining: int, tier: int = -1) -> Dictionary:
	var pool := []
	var total := 0.0
	# Past the deepest tier the fade stops advancing, so the heaviest monsters
	# stay at full weight instead of everything vanishing.
	var here := effective_depth() if tier < 0 else tier
	var effective := mini(here, deepest_tier() + TIER_GRACE)
	for e in BESTIARY:
		if e["min_depth"] > here:
			continue
		# Ascent-only things, gated separately from the tier ladder.
		#
		# The obvious way to say "only near the top of the climb" is a deep
		# min_depth, and it is a trap: deepest_tier() is the maximum min_depth
		# in the table and it caps the fade window for EVERYTHING. An entry at
		# min_depth 15 would push that cap from 10 to 15 and fade the dragon,
		# the shadow, the golem and the wight out of the very floors they were
		# written to carry -- an ascent populated by one monster. So the tier
		# stays shallow and the restriction lives here.
		if e.has("ascent_from") and (not ascending or here < int(e["ascent_from"])):
			continue
		# Some things are events, not populations.
		#
		# This exists because of what `no_fade` does further down: holding a
		# weight at 1.0 while every other entry decays toward zero does not
		# merely keep something available, it makes it dominant. Measured at
		# depth 10 the uncapped banshee arrived nine to a floor, and nine
		# alarms wailing in rotation is not a harder dungeon, it is an
		# unplayable one. Availability and frequency are different questions
		# and the tier ladder only answers the first.
		if e.has("max_per_floor"):
			var already := 0
			for other in entities:
				if not other.is_player and other.name == e["name"]:
					already += 1
			var cap := int(e["max_per_floor"])
			# The cave band lifts the cap on things that belong there, or the
			# rabbit's higher weight would just be rolled and refused.
			if Bands.is_caves(here) and float(e.get("caves", 1.0)) > 1.5:
				cap += 1
			if already >= cap:
				continue
		if int(e["threat"]) > remaining:
			continue
		var band := effective - int(e["min_depth"])
		# Most things belong to a tier and age out of the dungeon behind them.
		# A no-fade entry does not: it is as likely on the last floor as the
		# first. Without the exemption a min_depth-1 monster is gone by depth 7,
		# so "haunts every floor" is not something min_depth can express.
		var weight := 1.0
		if not e.get("no_fade", false):
			weight = 1.0 - TIER_FADE * float(maxi(0, band - TIER_GRACE))
		# A thumb on the scale, for entries whose frequency is a design choice
		# rather than a consequence of their tier. Capping the banshee at one a
		# floor stopped the swarm but left it CERTAIN -- present on every floor
		# from three onward, which makes it furniture. It should be a thing that
		# happens, not a thing that is always there.
		weight *= float(e.get("weight", 1.0))

		# What lives in caves, as opposed to what lives in a dungeon.
		#
		# ONE multiplier covers both ends of the band, because the depth pool
		# already differs enormously between them: at effective 4-6 the things
		# eligible to be boosted are bats and goblins, and at 14-16 they are
		# trolls, wyverns and dragons. So the same field produces vermin on the
		# way down and something much worse on the way back, without a second
		# table to keep in step with the first.
		if Bands.is_caves(here):
			weight *= float(e.get("caves", 1.0))
		if weight <= 0.0:
			continue
		total += weight
		pool.append({"entry": e, "weight": weight})

	if pool.is_empty():
		return {}
	var pick := rng.randf() * total
	for p in pool:
		pick -= p["weight"]
		if pick <= 0.0:
			return p["entry"]
	return pool[-1]["entry"]

## Letters the inventory panel must never hand out, because the panel itself
## answers to them while it is open:
##
##   i   closes the inventory
##   f   closes it again, out of the throw picker
##
## Reported from play, and it cost a run's last potion: the pack assigned it
## the letter "i", and every press of that key shut the panel instead of
## drinking it. There was no way to reach the item at all -- shift+i did not
## merge it either, because the close check runs first.
##
## Fixing the key order instead would be worse: "i" would then close the panel
## only when nothing happened to be lettered "i", which is a rule nobody can
## hold in their head. Better that the pool never offers the letter.
##
## `_test_inventory_letters_dodge_the_keys` reads main.gd and fails if a key
## is ever handled inside the inventory block without being listed here.
const RESERVED_LETTERS := "if"
const LETTERS := "abcdeghjklmnopqrstuvwxyz"

## Adds an item to the pack with a stable letter.
##
## Persistent letters matter more than they look. Once the inventory is sorted
## or filtered, a letter derived from screen position would change every time
## you picked something up -- so "quaff b", typed from muscle memory, would
## drink the wrong thing. The letter belongs to the item, not to the row.
func give_item(item: Item) -> bool:
	if player.inventory.size() >= Entity.INVENTORY_MAX:
		return false
	var used := {}
	for it in player.inventory:
		used[it.letter] = true
	# The whole pool, not the first INVENTORY_MAX of it. Iterating to the pack
	# size only worked while the pool was the alphabet and comfortably longer.
	for i in LETTERS.length():
		var ch := LETTERS[i]
		if not used.has(ch):
			item.letter = ch
			break
	player.inventory.append(item)
	return true

## Re-letters anything a suspended run is carrying under a key that cannot be
## pressed.
##
## Saves written before "i" and "f" were reserved can hold an item nobody can
## reach, and reloading is exactly the moment to put that right -- the run in
## which this was found had its last potion stuck that way. Also catches
## duplicates and blanks, which nothing produced but nothing prevented either.
func _relabel_unreachable_items() -> void:
	var seen := {}
	var stuck: Array[Item] = []
	for it in player.inventory:
		if it.letter == "" or RESERVED_LETTERS.contains(it.letter) \
				or seen.has(it.letter):
			stuck.append(it)
			it.letter = ""
		else:
			seen[it.letter] = true
	for it in stuck:
		for i in LETTERS.length():
			var ch := LETTERS[i]
			if not seen.has(ch):
				it.letter = ch
				seen[ch] = true
				break

func items_at(x: int, y: int) -> Array:
	var out := []
	for it in ground:
		if it.x == x and it.y == y:
			out.append(it)
	return out

func entity_at(x: int, y: int) -> Entity:
	for e in entities:
		if e.alive and e.blocks and e.x == x and e.y == y:
			return e
	return null

# ---------------------------------------------------------------- vision ----

func update_vision() -> void:
	var lit_reach := torch_radius()
	var radius := lit_reach if torch_lit else DOUSED_RADIUS
	# A rat is not carrying a torch. This is the honest cost of the ring: not
	# the stealth (being unlit HELPS you hide -- `lum` is a term in the
	# detection formula) but the blindness. You cannot see what is coming.
	if ratted():
		radius = DOUSED_RADIUS
	if torch_flare > 0:
		# The flare burns at full strength wherever you are, which is the point
		# of it in the dark band: on a cave floor it does not merely double your
		# sight, it gives you back the reach you lost and then some.
		radius = TORCH_RADIUS * FLARE_MULTIPLIER
	player.light.x = player.x
	player.light.y = player.y
	if torch_flare > 0:
		player.light.radius = TORCH_RADIUS * FLARE_MULTIPLIER
		player.light.intensity = 1.25
		player.light.color = Color(1.00, 0.94, 0.72)
		player.light.color_far = Color(0.45, 0.48, 0.62)
	elif torch_lit:
		player.light.radius = lit_reach
		player.light.intensity = 1.0
		player.light.color = Color(1.00, 0.72, 0.36)
		player.light.color_far = Color(0.30, 0.34, 0.55)
	else:
		player.light.radius = DOUSED_RADIUS
		player.light.intensity = 0.30
		player.light.color = Color(0.42, 0.50, 0.68)
		player.light.color_far = Color(0.20, 0.24, 0.36)
	var sources := [player.light]
	sources.append_array(static_lights)
	# CARRIED lights. Nothing but the player had one until now, and a monster
	# does not need light to SEE -- `_notices_player` reads the luminance at
	# YOUR cell, not its own. A guard's lantern exists entirely so that you can
	# see it coming.
	for e in entities:
		if not e.alive or e.is_player:
			continue
		# A guard on its rounds carries a lantern, granted the first time it is
		# needed rather than at spawn. Lazy on purpose: `LightSource` is not
		# serialised, so a patroller restored from a save would otherwise come
		# back dark, and this way it simply lights up again on the next turn.
		#
		# It KEEPS the lantern if it spots you and gives chase. A guard hunting
		# you does not put its torch out, and being able to watch it come is
		# the point.
		if e.light == null and e.activity == Entity.Activity.PATROLLING:
			e.light = LightSource.new(e.x, e.y, LANTERN_REACH,
				Color(0.92, 0.64, 0.32), Color(0.26, 0.20, 0.26),
				LANTERN_GLOW, true)
		if e.light != null:
			e.light.x = e.x
			e.light.y = e.y
			sources.append(e.light)
	light_map.compute(map, sources)

	# VISION, in two halves, and the second is new.
	#
	# The first is what it always was: a circle of your own reach, which is
	# your torch, or arm's length when it is out.
	#
	# The second is everything you have a clear LINE to that is actually LIT --
	# by a brazier, a fungus patch, or somebody else's lantern. That is how
	# sight works, and until now this game did not do it: a fire burning in a
	# room ten cells down a clear corridor was, to the player, perfectly dark.
	#
	# Deliberately ADDITIVE. The two are OR-ed, so nothing that was visible
	# before can become invisible -- doused in a pitch-black room you still see
	# your three cells, exactly as you did. This can only ever show you more.
	#
	# The gameplay reason, rather than the aesthetic one: dousing your torch
	# cuts your sight to three cells and a kobold slinger shoots from six, so
	# playing stealthily meant being shot by something you could not see. A
	# carried light restores the warning without giving back the concealment.
	# Sized HERE rather than only in `build_level`, because a GameState can
	# also arrive through `apply_dict` or be assembled by hand in a test, and
	# both hand `Fov.compute` a zero-length buffer otherwise. Cheap to check
	# and it covers every path instead of the three I could think of.
	if _sight_buffer.size() != map.width * map.height:
		_sight_buffer.resize(map.width * map.height)
	Fov.compute(map, player.x, player.y, radius, _fov_buffer)
	Fov.compute(map, player.x, player.y, maxi(map.width, map.height),
		_sight_buffer)
	for i in _fov_buffer.size():
		if _fov_buffer[i] != 0 or _sight_buffer[i] == 0:
			continue
		if light_map.values[i].get_luminance() >= LIT_ENOUGH:
			_fov_buffer[i] = 1
	map.visible_now = _fov_buffer.duplicate()
	map.remember_visible()
	_note_sightings()

## Anything the player can currently SEE goes in the record of what they have
## met, for good and across runs.
##
## Sight rather than combat, because recognising a thing is what the legend is
## for -- you learn what a wight looks like by seeing one, not by killing it,
## and a creature that killed you from out of the dark taught you nothing you
## could look up afterwards.
##
## Sleeping counts. It is on the floor, you are looking at it, and whether it
## has noticed you is a different question the awareness marks already answer.
func _note_sightings() -> void:
	for e in entities:
		if e.is_player or not e.alive:
			continue
		if not map.is_visible(e.x, e.y):
			continue
		# A corrupted thing teaches you the corrupted thing, and nothing about
		# the ordinary one. They are different encounters -- different colour,
		# different fight -- and in practice you always meet the plain version
		# first anyway, since corruption exists only on the climb.
		if e.corrupted:
			BestiaryLog.note_corrupted(e.appearance)
		else:
			BestiaryLog.note(e.appearance)

## Drains the presentation queue. Called by the renderer once per refresh.
func take_events() -> Array:
	var out := events.duplicate()
	events.clear()
	return out

## Everything the player could shoot right now, nearest first. Drives target
## cycling, so the list the cursor walks is exactly the list of legal shots.
func firing_targets(reach: int = -1) -> Array:
	var out := []
	var r := player.total_range() if reach < 0 else reach
	if r <= 1:
		return out
	for e in entities:
		# Hostility, not "is it me". An ally in the firing cycle means the
		# cursor offers it as a shot and tab-targeting walks onto it -- the
		# player would eventually put an arrow through their own bone ally by
		# pressing tab one time too many.
		if not e.alive or not e.hostile_to(player):
			continue
		if can_reach(Vector2i(e.x, e.y), r):
			out.append(e)
	out.sort_custom(func(a, b):
		return Los.steps(player.x, player.y, a.x, a.y) \
			< Los.steps(player.x, player.y, b.x, b.y))
	return out

## One reach test for shooting and throwing alike -- they differ only in how
## far the thing goes.
func can_reach(cell: Vector2i, reach: int) -> bool:
	if reach <= 1:
		return false
	if not map.is_visible(cell.x, cell.y):
		return false
	if Los.steps(player.x, player.y, cell.x, cell.y) > reach:
		return false
	return Los.clear(map, player.x, player.y, cell.x, cell.y)

func can_fire_at(cell: Vector2i) -> bool:
	return can_reach(cell, player.total_range())

func player_fire(cell: Vector2i) -> bool:
	if game_over:
		return false
	if player.total_range() <= 1:
		msg_log.add("You have nothing to shoot with.", Color(0.7, 0.6, 0.4))
		return false
	if not can_fire_at(cell):
		msg_log.add("You have no clear shot there.", Color(0.7, 0.6, 0.4))
		return false

	var target := entity_at(cell.x, cell.y)
	if target == null or target.is_player:
		# Refused rather than spent: a misclick should cost neither a turn nor
		# a shot.
		msg_log.add("There is nothing there to shoot.", Color(0.7, 0.6, 0.4))
		return false
	# Hostility, not "is it me" -- the same rule firing_targets applies, applied
	# again here because the tab cursor is not the only way to choose a target.
	#
	# Tab-cycling already refused neutrals and allies. Right-click did not, and
	# right-click is the path a mouse finds first: no mode, no confirmation,
	# straight to the shot. Measured on 2026-09-20 before this line existed --
	# 40 of 40 clear bow shots killed the trader, deleting the floor's only
	# conversation, and the same gap let you put an arrow through your own
	# risen ally, which is precisely what the comment in firing_targets says
	# must never happen.
	#
	# Gated on hostile_to() rather than on Faction.NEUTRAL directly, so anything
	# marked neutral later inherits the refusal without anyone remembering to
	# come back here. That inheritance is the whole reason the faction exists.
	if not target.hostile_to(player):
		msg_log.add("The %s is not your enemy." % target.name,
			Color(0.7, 0.6, 0.4))
		return false

	var launcher: Item = player.equipped.get(Item.Slot.WEAPON, null)
	if launcher != null and launcher.uses_ammo() and launcher.ammo <= 0:
		msg_log.add("The %s is empty." % launcher.name, Color(0.9, 0.6, 0.35))
		return false

	_travel.clear()
	if launcher != null and launcher.uses_ammo():
		launcher.ammo -= 1
		_spend_shot(launcher, cell)
	_attack(player, target, true)
	_end_player_turn()
	return true

## Where a spent shot ends up.
##
## Arrows survive and land at the target, so they can be walked to and
## gathered. That is the whole point of them: retreating means backing away
## from your own ammunition, so kiting something across a room costs you either
## the arrows or the ground you just gave up. Noise could never do that -- it
## wakes things, and the things it wakes are the slow ones that could not reach
## you anyway.
##
## Stones do not survive. Nobody would cross a room for a slung pebble, and
## there is rubble everywhere to make more.
func _spend_shot(launcher: Item, at: Vector2i) -> void:
	if launcher.ammo_kind != &"arrow":
		return
	if not map.is_walkable(at.x, at.y):
		return
	# Pile into an arrow already lying there rather than scattering singles.
	for it in items_at(at.x, at.y):
		if it.id == &"arrows":
			it.ammo += 1
			return
	var spent := Item.make(&"arrows")
	spent.ammo = 1
	spent.x = at.x
	spent.y = at.y
	ground.append(spent)

## Everything in the pack that could be hurled.
func throwables() -> Array:
	var out := []
	for it in player.inventory:
		if it.is_throwable():
			out.append(it)
	return out

## Hurling something. Weaker than a bow on purpose -- reach should not be free
## twice -- and the weapon lands where it hit, so throwing is a positioning
## decision rather than a consumable.
func player_throw(index: int, cell: Vector2i) -> bool:
	if game_over or index < 0 or index >= player.inventory.size():
		return false
	var item: Item = player.inventory[index]
	if not item.is_throwable():
		msg_log.add("You cannot throw the %s." % item.name, Color(0.7, 0.6, 0.4))
		return false
	if not can_reach(cell, item.throw_range):
		msg_log.add("You cannot reach there with the %s." % item.name,
			Color(0.7, 0.6, 0.4))
		return false

	var target := entity_at(cell.x, cell.y)
	if target == null or target.is_player:
		msg_log.add("There is nothing there to throw at.", Color(0.7, 0.6, 0.4))
		return false
	# Same rule as player_fire, and refused here for the same reason: a thrown
	# item killed the trader on 25 of 25 attempts. Checked BEFORE the item
	# leaves the inventory, so declining the throw does not also cost the thing
	# you were going to throw.
	if not target.hostile_to(player):
		msg_log.add("The %s is not your enemy." % target.name,
			Color(0.7, 0.6, 0.4))
		return false

	_travel.clear()
	if player.is_equipped(item):
		player.equipped.erase(item.slot)
	player.inventory.remove_at(index)
	item.letter = ""

	# Half your own strength behind it, plus whatever the thing is worth.
	var throw_power := item.power_bonus + int(player.power / 2)
	msg_log.add("You hurl the %s." % item.display_name(), Color(0.85, 0.88, 0.68))
	_attack(player, target, true, throw_power)

	# It lands where it struck, whether or not that killed anything.
	item.x = cell.x
	item.y = cell.y
	ground.append(item)

	_end_player_turn()
	return true

## What a queued mouse-walk refuses to keep walking past.
##
## Every visible monster, EXCEPT that eight inches of rat may pass a sleeper.
##
## Brad's rule, and the reasoning is about noise rather than about sight. On
## two feet, walking past a sleeping thing genuinely risks waking it: every
## step calls _make_noise with the tile's radius, and auto-walking blind past
## something you are making noise beside is exactly when you want the game to
## stop and let you look. `ratted()` skips _make_noise entirely, so a rat
## cannot wake it by walking -- the guard was protecting against a risk that
## does not exist in that form, on the one journey the ring exists to make.
##
## A sleeper is still the ONLY exemption. Anything suspicious or awake stops
## you in either form, because those can act, and a rat that gets noticed has
## no hands to answer with.
func _travel_stoppers() -> Array:
	if not ratted():
		return visible_monsters()
	var out := []
	for e in visible_monsters():
		# Unaware AND idle. A patrolling guard is unaware of you but walking,
		# and creeping past it as a rat should not be as free as creeping past
		# something genuinely asleep. Before the activity split this read as
		# "not ASLEEP", which covered patrollers only because patrolling WAS an
		# alertness; keeping both halves preserves that exactly.
		if e.alertness != Entity.Alert.ASLEEP \
				or e.activity != Entity.Activity.SLEEPING:
			out.append(e)
	return out

## Everyone fighting on your side, in the order they were raised.
func allies() -> Array:
	var out := []
	for e in entities:
		if e.alive and not e.is_player and e.faction == Entity.Faction.PLAYER:
			out.append(e)
	return out

func visible_monsters() -> Array:
	var out := []
	for e in entities:
		# Hostile ones only. This list is what stops click-to-travel and what
		# the "you cannot rest with monsters about" checks read, so an ally
		# counted here would halt every journey and forbid every rest simply by
		# walking beside you -- the thing it was summoned to do.
		if e.alive and e.hostile_to(player) and map.is_visible(e.x, e.y):
			out.append(e)
	return out

# ---------------------------------------------------------- player turn ----

## Every one of these returns true if game time actually passed. Returning
## false for a bumped wall is what stops the world taking a free turn while
## the player fumbles at a dead end.

func player_move(dx: int, dy: int) -> bool:
	if game_over:
		return false
	_travel.clear()
	var nx := player.x + dx
	var ny := player.y + dy

	var target := entity_at(nx, ny)
	# Walking into the trader starts a conversation instead of shoving past it.
	#
	# This has to come BEFORE the swap below, which exists for allies: a neutral
	# is not hostile, so without this the player would trade places with the one
	# thing on the floor that wants to talk to them and never find out it did.
	#
	# Free, and it does not end the turn -- the same call as the ally stance
	# key. Nothing on the floor should get a move because you said hello.
	if target != null and target.faction == Entity.Faction.NEUTRAL:
		# "to" is not optional on an event. GlyphGrid.play_events reads it
		# before it looks at the kind, so an event without one freezes the
		# game on the spot -- which is exactly what the first version of this
		# line did when the player walked into the trader.
		events.append({"kind": &"talk", "to": Vector2i(nx, ny),
			"who": target.name})
		return true
	# Change places with it rather than hitting it. An autonomous ally WILL
	# end up in the corridor you are backing down -- that is not an edge case,
	# it is most corridors -- and the alternatives are both bad: bumping it
	# costs you the escape, and attacking it costs you the ally. Swapping is
	# the only version where the help you summoned is not also the thing that
	# traps you. It is free, deliberately: the ally moves on its own turn.
	if target != null and target != player and not target.hostile_to(player):
		var from := Vector2i(player.x, player.y)
		player.x = nx
		player.y = ny
		target.x = from.x
		target.y = from.y
		_end_player_turn(move_cost_for(player, nx, ny))
		return true
	if target != null and target != player:
		if ratted():
			msg_log.add("You have no hands. Whatever you meant to do, you cannot.",
				Color(0.7, 0.6, 0.4))
			return false
		_attack(player, target)
		_end_player_turn()
		return true

	# Opened by walking into it, the way a door is. No key, and the act is
	# unmistakably deliberate -- you cannot cross a chest by accident.
	if map.get_tile(nx, ny) == Tiles.CHEST:
		_open_chest(Vector2i(nx, ny))
		_end_player_turn()
		return true

	# A RAT GOES UNDER IT, and this is the first thing the ring is simply GOOD
	# at. It costs you your hands, your sight and your ability to fight, and
	# until now bought only stealth -- while every rat and rabbit in the
	# dungeon slipped under doors you had to stop and open. `door_style()`
	# already answers SQUEEZES for a small animal; wearing the ring makes you
	# one, so the branch is skipped entirely and the door stays shut behind you.
	if map.get_tile(nx, ny) == Tiles.DOOR_CLOSED and not ratted():
		map.set_tile(nx, ny, Tiles.DOOR_OPEN)
		pathfinder.set_solid(nx, ny, false)
		_work_the_door(Vector2i(nx, ny), "You pull the door open.")
		return true

	if not can_step(player.x, player.y, nx, ny):
		return false

	if map.get_tile(nx, ny) == Tiles.PIT:
		return _fall_into_pit()

	if map.get_tile(nx, ny) == Tiles.TRAP:
		_spring_trap(nx, ny)
		if not player.alive:
			return true

	var cost := move_cost_for(player, nx, ny)
	player.x = nx
	player.y = ny
	_end_player_turn(cost)
	return true

## The last few things you killed, newest last, pruned as they cool.
##
## Stored as dictionaries rather than Entities so it serialises with the run
## for free, and so nothing here can hold a reference to a corpse the rest of
## the game thinks it has finished with.
var recent_dead: Array = []

func _remember_the_dead(victim: Entity) -> void:
	if victim.is_player or victim.faction == Entity.Faction.PLAYER:
		return
	recent_dead.append({"turn": turns, "e": victim.to_dict()})
	var still: Array = []
	for rec in recent_dead:
		if turns - int(rec["turn"]) <= SHOVEL_WINDOW:
			still.append(rec)
	recent_dead = still

## Digs the newest corpse back up, on your side.
##
## THE NEWEST, not the strongest. "Raise what you just killed" is one sentence
## and needs no interface; "raise the best thing within five turns" is a hidden
## rule the player has to reverse-engineer, and it would quietly remove the
## decision that makes the window interesting -- which order you finish a fight
## in. Flip this if it plays badly; it is one loop.
##
## It keeps its OWN shape and its own gear: a raised troll is a troll, and the
## grid draws it in the ally colour so you can still tell whose it is.
func _raise_the_recent_dead() -> bool:
	var pick: Dictionary = {}
	for i in range(recent_dead.size() - 1, -1, -1):
		var rec: Dictionary = recent_dead[i]
		if turns - int(rec["turn"]) <= SHOVEL_WINDOW:
			pick = rec
			break
	if pick.is_empty():
		msg_log.add("Nothing here is fresh enough to answer.",
			Color(0.7, 0.6, 0.4))
		return false
	var spot := _nearest_restable(Vector2i(player.x, player.y))
	if spot.x < 0:
		msg_log.add("There is no room here for anyone else.", Color(0.7, 0.6, 0.4))
		return false

	var risen := Entity.from_dict(pick["e"])
	if risen == null:
		return false
	risen.x = spot.x
	risen.y = spot.y
	risen.alive = true
	risen.faction = Entity.Faction.PLAYER
	risen.ai = &"ally"
	risen.stance = Entity.Stance.LOOSE
	risen.alertness = Entity.Alert.AWAKE
	risen.fleeing = false
	# Half of what it was, the same bargain the bone ally strikes. Whole, a
	# raised young dragon would simply be a second player character.
	risen.max_hp = maxi(1, risen.max_hp / 2)
	risen.hp = risen.max_hp
	risen.name = "risen %s" % risen.name
	entities.append(risen)
	Scheduler.spend(risen, Scheduler.ACTION_COST)
	recent_dead.erase(pick)
	events.append({"kind": &"notice", "to": spot})
	msg_log.add("You turn the earth. The %s rises, and it is yours."
		% String(pick["e"].get("name", "dead")), Color(0.70, 0.90, 0.78))
	return true

## Calls your dead to heel, or lets them off it.
##
## FREE, unlike the torch below, and the difference is deliberate. Dousing the
## torch buys stealth, so charging a turn for it makes it a decision. This buys
## nothing by itself -- it only says where your allies should stand -- and a
## turn's cost would mean nobody ever changed stance mid-fight, which is the
## only moment it matters. The same reasoning that kept the threat ceiling off
## an ally: do not tax the thing you want people to use.
##
## Sets them ALL, because they are one party and the key is one press. Answers
## false when there is nobody to command, so the keypress does not pretend.
func player_ally_stance() -> bool:
	var told := []
	for e in entities:
		if e.alive and not e.is_player and e.faction == Entity.Faction.PLAYER:
			told.append(e)
	if told.is_empty():
		return false
	# Typed through a local rather than inferred from `told[0]`, which is a
	# Variant out of an untyped Array and cannot give `:=` anything to infer.
	var lead: Entity = told[0]
	var to_heel := lead.stance != Entity.Stance.HEEL
	for e in told:
		e.stance = Entity.Stance.HEEL if to_heel else Entity.Stance.LOOSE
	if to_heel:
		msg_log.add("\"Stay close.\" The dead draw in around you.",
			Color(0.70, 0.90, 0.78))
	else:
		msg_log.add("\"Go.\" The dead spread out ahead of you.",
			Color(0.70, 0.90, 0.78))
	return true

## Shuts a door beside you. Nothing in this game could do this until now --
## the player could open one and not close it, which made a door a tax rather
## than a tool.
##
## It is the half that MATTERS, because of what it does to the three door
## styles: shutting one on a goblin buys a turn, on a bear about three, and on
## a rabbit exactly nothing. The same action means something different
## depending on what is chasing you.
##
## Refuses when something is standing in the doorway, which is the obvious
## thing a player will try in a corridor and would otherwise let them close a
## door on a goblin's head.
func player_close_door() -> bool:
	if game_over:
		return false
	var found := Vector2i(-1, -1)
	var blocked := false
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var c := Vector2i(player.x + dx, player.y + dy)
			if not map.in_bounds(c.x, c.y):
				continue
			if map.get_tile(c.x, c.y) != Tiles.DOOR_OPEN:
				continue
			if entity_at(c.x, c.y) != null or not items_at(c.x, c.y).is_empty():
				blocked = true
				continue
			if found.x < 0:
				found = c
	if found.x < 0:
		if blocked:
			msg_log.add("The doorway is not clear.", Color(0.7, 0.6, 0.4))
		else:
			msg_log.add("There is no open door beside you.", Color(0.7, 0.6, 0.4))
		return false
	map.set_tile(found.x, found.y, Tiles.DOOR_CLOSED)
	_travel.clear()
	_work_the_door(found, "You pull the door shut.")
	return true

## How loud working a door is, and what being careful about it costs.
##
## Hinges and a latch in a stone corridor are not quiet, and the game had them
## silent -- you could walk the length of a floor opening doors and wake
## nothing. DOOR_NOISE sits at 6, the same as a fight and one below a bone
## crunch, so it carries without raising the dead.
##
## Doused, you take your time and it makes no sound -- at DOUBLE the energy.
## That is the point of the pair: dousing already costs you sight, and this is
## the first thing it BUYS besides not being seen. "Quiet but slow" becomes a
## posture you choose rather than just being blind in the dark.
const DOOR_NOISE := 6
const DOOR_CAREFUL_COST := 2

func _work_the_door(at: Vector2i, said: String) -> void:
	var careful := not torch_lit or ratted()
	if careful:
		msg_log.add(said + " Quietly.", Color(0.70, 0.74, 0.80))
	else:
		msg_log.add(said, Color(0.78, 0.74, 0.66))
	_end_player_turn(Scheduler.ACTION_COST
		* (DOOR_CAREFUL_COST if careful else 1))
	if not careful:
		_make_noise(at, DOOR_NOISE, &"door")

## Costs a turn on purpose. Going dark is a decision, not a free toggle.
func player_toggle_torch() -> bool:
	if game_over:
		return false
	if torch_flare > 0:
		msg_log.add("The flare will not be smothered. %d turns of it left."
			% torch_flare, Color(0.95, 0.80, 0.45))
		return false
	_travel.clear()
	torch_lit = not torch_lit
	if torch_lit:
		msg_log.add("You uncover the torch. Light floods back.", Color(0.95, 0.78, 0.42))
	else:
		msg_log.add("You smother the torch. The dark closes in.", Color(0.58, 0.64, 0.85))
	_end_player_turn()
	return true

## Waiting beside a lit brazier warms you. The light keeps the dark at bay.
##
## Note what this costs, which is not obvious: resting puts you in the
## brightest cell on the level for several turns while the world keeps taking
## turns. The awareness system makes that genuinely dangerous, which is why
## this heals slowly rather than all at once -- an instant heal would be free,
## and a free heal is not a decision.
## Praying is its own key so that walking onto a shrine can never spring a
## curse. A deliberate act, deliberately.
func player_pray() -> bool:
	if game_over:
		return false
	var here := Vector2i(player.x, player.y)
	if map.get_tile(here.x, here.y) != Tiles.SHRINE:
		msg_log.add("There is nothing here to pray at.", Color(0.7, 0.6, 0.4))
		return false

	var kind := int(shrine_at.get(here, Shrines.MENDING))
	_travel.clear()
	map.set_tile(here.x, here.y, Tiles.FLOOR)
	shrine_at.erase(here)
	shrine_known[kind] = true
	msg_log.add("You lay a hand on the %s." % Shrines.NAMES[kind],
		shrine_hue(kind))
	events.append({"kind": &"pray", "to": here})
	_invoke_shrine(kind)
	_answer_the_prayer(here)
	_end_player_turn()
	return true

## The gem a shrine may leave behind, whatever else it just did to you.
##
## Rolled for EVERY shrine, kind regardless -- including the ones that hurt.
## A shrine that empties the floor's lungs at you and then leaves a stone is a
## better story than a shrine that only pays when it was already being kind, and
## it keeps the gamble honest: a bad outcome you can still walk away from with
## something is a risk worth taking twice.
func _answer_the_prayer(at: Vector2i) -> void:
	if rng.randf() >= GEM_SHRINE_CHANCE:
		msg_log.add("Your whispered prayer falls on deaf stone.",
			Color(0.62, 0.60, 0.66))
		return
	var gem := Item.roll_gem(rng, effective_depth())
	if gem == null:
		msg_log.add("Your whispered prayer falls on deaf stone.",
			Color(0.62, 0.60, 0.66))
		return
	_drop_item_at(gem, at)
	gem_found = true
	msg_log.add("The shrine has heard your prayer.", Color(0.85, 0.80, 0.95))

func _invoke_shrine(kind: int) -> void:
	match kind:
		Shrines.QUIET:
			var n := 0
			for e in entities:
				if e.is_player or not e.alive:
					continue
				e.notice_block = QUIET_TURNS
				if e.alertness != Entity.Alert.ASLEEP \
						or e.activity != Entity.Activity.SLEEPING:
					e.alertness = Entity.Alert.ASLEEP
					# Stops the round too, which is what it did before the
					# split -- patrolling used to BE an alertness, so a hush
					# ended it. Arguably a guard should keep walking and simply
					# fail to notice you; that is a design change, and this
					# refactor is meant to be invisible.
					e.activity = Entity.Activity.SLEEPING
					e.fleeing = false
					n += 1
			msg_log.add("A hush settles. %d things stop looking for you." % n,
				Color(0.70, 0.85, 0.95))

		Shrines.VIGIL:
			# Set directly rather than through wake(), which would log and
			# flash an exclamation mark for every monster on the floor.
			var n := 0
			for e in entities:
				if e.is_player or not e.alive:
					continue
				if e.alertness != Entity.Alert.AWAKE:
					e.alertness = Entity.Alert.AWAKE
					e.last_seen = Vector2i(player.x, player.y)
					e.lost_turns = 0
					n += 1
				# THE WHOLE POINT OF A GONG. Measured before this existed: the
				# shrine woke 244 things on a depth-2 floor and EIGHT of them
				# arrived -- the median one starts 31-38 cells out and a
				# ten-turn memory carries it ten. "Something calls out, and 20
				# things answer" was true about the waking and a lie about the
				# answering.
				e.pursue_turns = VIGIL_PURSUIT
			# The loudest thing in the game, and until now the only one with no
			# picture. It does not wake through _make_noise -- it wakes the
			# whole floor directly, above -- so this is called afterwards purely
			# to put the wavefront on screen. Everything is already awake by
			# now, so it rouses nobody and logs nothing.
			#
			# The radius is a REPRESENTATION rather than a measurement, and this
			# is the one ring where that is true. The effect has no radius; it
			# reaches everything. Twenty-four simply exceeds anything the player
			# can see at once, so from where they stand it is unbounded.
			_make_noise(Vector2i(player.x, player.y), CLAMOUR_RING, &"clamour")
			msg_log.add("Something calls out, and %d things answer." % n,
				Color(0.95, 0.55, 0.40))

		Shrines.EMBERS:
			var n := 0
			for y in map.height:
				for x in map.width:
					if map.get_tile(x, y) != Tiles.BRAZIER_SPENT:
						continue
					map.set_tile(x, y, Tiles.BRAZIER)
					brazier_charge[Vector2i(x, y)] = BRAZIER_CHARGE / 2
					ember_until.erase(Vector2i(x, y))
					n += 1
			_gather_lights()
			msg_log.add("Cold ash catches. %d braziers burn again." % n,
				Color(0.98, 0.78, 0.42))

		Shrines.ANVIL:
			forge_cap_bonus += 1
			msg_log.add("Your hands remember an older craft. Metal will take "
				+ "another edge.", Color(0.85, 0.88, 0.70))

		Shrines.MENDING:
			var healed := player.max_hp - player.hp
			player.hp = player.max_hp
			msg_log.add("Warmth floods through you. %d hit points restored."
				% healed, Color(0.55, 0.85, 0.55))

		Shrines.SUMMONS:
			var before := entities.size()
			var area := Rect2i(player.x - 4, player.y - 4, 9, 9)
			for _i in rng.randi_range(1, 3):
				_spawn_in(area, room_threat_ceiling())
			var made := entities.size() - before
			for i in range(before, entities.size()):
				entities[i].alertness = Entity.Alert.AWAKE
			msg_log.add("The air splits, and %d things step through." % made,
				Color(0.95, 0.50, 0.45))

		Shrines.WEIGHT:
			var blessed := 0
			for slot in player.equipped:
				var it: Item = player.equipped[slot]
				it.upgrade()
				blessed += 1
			player.speed = WEIGHT_SPEED
			if blessed > 0:
				msg_log.add("Your gear drinks it in and grows heavier. You move "
					+ "slower for it.", Color(0.88, 0.86, 0.78))
			else:
				msg_log.add("The weight settles on you with nothing to bless. "
					+ "You move slower for nothing.", Color(0.75, 0.70, 0.62))

		Shrines.FLARE:
			torch_flare = FLARE_TURNS
			torch_lit = true
			msg_log.add("Your torch roars white. You can see far -- and be seen "
				+ "just as far.", Color(1.00, 0.90, 0.55))

## Stepping into a pit. Always deliberate -- the pathfinder routes around them,
## so neither auto-travel nor a monster can put you here.
func _fall_into_pit() -> bool:
	_travel.clear()
	var hurt := rng.randi_range(3, 6 + depth / 2)
	player.take_damage(hurt)
	_tally("taken", hurt)
	msg_log.add("The floor opens. You drop into the dark.", Color(0.85, 0.75, 0.62))

	if not player.alive:
		game_over = true
		death_cause = "broken by a fall"
		events.append({"kind": &"death", "to": Vector2i(player.x, player.y)})
		write_morgue()
		write_death_dump()
		return true

	depth += 1
	build_level()
	msg_log.add("You land hard on depth %d. (-%d hp)" % [depth, hurt],
		Color(0.90, 0.60, 0.45))
	return true

## Springs once and is gone. A trap corridor can be cleared at a price, which
## makes it a toll rather than a permanent wall.
func _spring_trap(x: int, y: int) -> void:
	map.set_tile(x, y,
		Tiles.CAVE_FLOOR if map.material_at(x, y) == Materials.CAVERN
		else Tiles.FLOOR)
	var hurt := rng.randi_range(2, 4 + depth / 2)
	player.take_damage(hurt)
	_tally("taken", hurt)
	msg_log.add("The mechanism snaps shut. (-%d hp)" % hurt, Color(0.92, 0.48, 0.40))
	events.append({"kind": &"trap", "to": Vector2i(x, y)})
	events.append({"kind": &"melee", "from": Vector2i(x, y), "to": Vector2i(x, y),
		"amount": hurt, "on_player": true})
	# Springing one is loud -- but it is not a BONE CRUNCH, and the difference
	# matters. This passed no cause, so it defaulted to &"step" and quietly
	# raised gravestones, against the rule three lines of comment in
	# `_make_noise` insist on: bones and a wail, and nothing else, so that the
	# rule is one a player can hold in their head. A trap doing it as well made
	# that a lie for the life of the project.
	_make_noise(Vector2i(x, y), 5, &"trap")
	if not player.alive:
		game_over = true
		death_cause = "caught in a trap"
		events.append({"kind": &"death", "to": Vector2i(player.x, player.y)})
		write_morgue()
		write_death_dump()

## Loud ground. Noise carries through stone, so this ignores line of sight --
## it is the counterpart to light, and the second thing that can give you away.
func _make_noise(at: Vector2i, radius: int, cause: StringName = &"step") -> void:
	if radius <= 0:
		return
	# Emitted whether or not anything was actually roused. What the player
	# needs to know is that they were LOUD; whether the room happened to be
	# empty is a separate fact, and the message log already carries it.
	events.append({"kind": &"noise", "to": at, "radius": radius, "cause": cause})
	var roused := 0
	for e in entities:
		if e.is_player or not e.alive or e.alertness == Entity.Alert.AWAKE:
			continue
		e.alertness = Entity.Alert.AWAKE
		e.last_seen = at
		e.lost_turns = 0
		e.notice_block = 0
		if Los.steps(e.x, e.y, at.x, at.y) > radius:
			e.alertness = Entity.Alert.ASLEEP
			continue
		roused += 1
	if roused > 0:
		msg_log.add("The noise carries. %d things turn towards it." % roused,
			Color(0.95, 0.70, 0.40))

	# LOUD ENOUGH, rather than a list of causes.
	#
	# This used to read "bones or a wail, and nothing else", which was a pair
	# picked for convenience and defended as being easy to remember. It was not
	# even true -- a sprung trap passed no cause at all, defaulted to &"step",
	# and raised gravestones against the stated rule for the life of the
	# project.
	#
	# The ladder says it better: combat 6, a door 6, bones 7, a chest 8, a wail
	# 9, the forge 10. Anything at GRAVE_ROUSING or above wakes the dead, which
	# is one sentence -- "loud things wake them" -- and it means a chest and a
	# brazier now do, which makes a hoard room with a headstone in it a
	# genuinely worse place to stand and work.
	#
	# COMBAT IS DELIBERATELY BELOW IT. Brad argued for including it: fighting
	# near a stone as a way to force a raise. But `_place_graves` already
	# scatters bones around every gravestone, so the deliberate route exists
	# and is cheaper -- walk over and step on them. And combat is the most
	# frequent loud thing in the game, so including it would fire the 45% roll
	# many times a floor and turn the raise from POSSIBLE into NEAR-CERTAIN.
	# That converts a headstone from a decision into a hazard you route around,
	# which is exactly what GRAVE_RISE_CHANCE's comment argues against.
	if radius >= GRAVE_ROUSING:
		_wake_a_grave(at, radius)

## Something under a headstone hears the noise and answers it.
##
## Only stones that were buried with gear ever rise, which is also the entire
## safeguard: an empty grave has nothing worth fighting for, so it stays quiet.
## Done HERE, on the outcome, rather than by keeping bones and banshees away
## from poor graves during generation -- partly because a banshee walks through
## stone and cannot be kept out of anywhere, but mostly because a reliable
## warning is not dread. If bones only ever appeared beside armed stones, the
## pairing would become a signpost. Sometimes nothing happens is the mechanic.
func _wake_a_grave(at: Vector2i, radius: int) -> void:
	if grave_risen:
		return
	var heard: Array[Vector2i] = []
	for cell in grave_at:
		# Chebyshev, the same metric the noise itself uses to decide who woke.
		if Los.steps(cell.x, cell.y, at.x, at.y) > radius:
			continue
		var rec: Dictionary = grave_at[cell]
		if not rec.has("gear"):
			continue
		# Answered for already, in some earlier run. The stone still stands and
		# still reads -- it just has nothing left to owe.
		if rec.get("reclaimed", false):
			continue
		heard.append(cell)
	if heard.is_empty():
		return
	if rng.randf() >= GRAVE_RISE_CHANCE:
		return
	# Which one is the gamble. Two stones in a room means two possible fights
	# and no way to choose between them.
	var from_cell: Vector2i = heard[rng.randi_range(0, heard.size() - 1)]
	_raise_from(from_cell)

func _raise_from(cell: Vector2i) -> void:
	var rec: Dictionary = grave_at[cell]
	var spot := cell if entity_at(cell.x, cell.y) == null else _nearest_restable(cell)
	if spot.x < 0:
		return
	var entry := {}
	for e in BESTIARY:
		if e["name"] == "skeleton":
			entry = e
	if entry.is_empty():
		return

	var risen := monster_from(entry, spot.x, spot.y)
	risen.risen = true
	risen.alertness = Entity.Alert.AWAKE
	# Named, because the stone beside it is named. A skeleton called "risen dead"
	# standing over a grave that says "Erdrick, who reached level 7" reads as two
	# unrelated things; naming it is what makes the fight ABOUT somebody.
	#
	# Morgue.name_of invents a stable one for the older dead, who were buried
	# before names were written down.
	risen.name = "risen %s" % Morgue.name_of(rec)
	# Carried so it can reach the bone, and from the bone the ally. The morgue
	# knows what level this character reached; nothing else does.
	risen.level = maxi(1, int(rec.get("level", 1)))
	# Wearing what the run died in, and charged for it.
	#
	# The threat ceiling is a survivability promise, and gear is exactly why
	# `_arm_monster` already adds equipment cost to threat -- a room of armed
	# orcs that costs what a room of bare ones costs makes the promise a lie.
	# The same has to be true when the equipment came out of a grave, even
	# though nothing here is rolling against a budget: the number has to mean
	# something later, when this thing is counted.
	for text in rec.get("gear", []):
		var it := Item.from_display_name(String(text))
		if it == null:
			continue
		# A launcher goes in the PACK, not the hands.
		#
		# `_arm_monster` already refuses to arm a melee brain with reach it
		# will never use, and grave gear was slipping past that rule: a risen
		# archer charged into melee swinging its bow. The risen is a plain
		# hunter -- only the ally learned to swap -- so it is given the blade
		# and keeps the bow, which still drops, and still reaches the bone.
		var held: Item = risen.equipped.get(it.slot, null)
		if it.slot != Item.Slot.WEAPON or it.range_bonus <= 1 or held == null:
			risen.equipped[it.slot] = it
		risen.inventory.append(it)
		risen.threat += it.power_bonus + it.defense_bonus
	entities.append(risen)
	grave_risen = true
	# The stone STAYS while its occupant is up. It is the only thing on the
	# floor that says what you are fighting and why, and it is still readable
	# from across the room mid-fight.
	risen_grave = cell
	events.append({"kind": &"noise", "to": spot, "radius": 4, "cause": &"rise"})
	msg_log.add("The stone shifts. Something you buried stands up.",
		Color(0.85, 0.90, 0.95))

## Calls somebody back up, on your side this time.
##
## Built the same way `_raise_from` builds the enemy: the bestiary's skeleton,
## wearing what the morgue says this character was buried in. That is what
## makes an ally's strength the strength of the run that died -- a shallow
## death lends you a skeleton in a dagger, a depth-10 death lends you one in
## plate. Nothing balances that by hand, and nothing needs to.
##
## Returns false without spending the bone when there is nowhere to stand.
## Refusing costs neither the item nor the turn, which is the rule every other
## consumable already follows.
func _summon_ally(bone: Item) -> bool:
	var spot := _nearest_restable(Vector2i(player.x, player.y))
	if spot.x < 0:
		msg_log.add("There is no room here for anyone else.", Color(0.7, 0.6, 0.4))
		return false
	var entry := {}
	for e in BESTIARY:
		if e["name"] == "skeleton":
			entry = e
	if entry.is_empty():
		return false

	var ally := monster_from(entry, spot.x, spot.y)
	# A SHADE OF THE HERO, not a skeleton wearing their coat.
	#
	# Twelve hit points is what the bestiary gives a skeleton, and it made the
	# ally a speed bump at the depths where you most want one: a level-19 grave
	# lent you plate armour on a twelve-point frame, and the first dragon it met
	# ended it. Half of what that character could take is the compromise --
	# enough that a deep grave is worth more than a shallow one, short of
	# raising the dead at full strength.
	#
	# Never WEAKER than a plain skeleton, so a grave from the learning floors
	# still stands up. Armour and shield need no help here: `total_defense`
	# already sums whatever an entity has equipped, whoever it is.
	ally.max_hp = maxi(ally.max_hp, hp_at_level(maxi(1, bone.bone_level)) / 2)
	ally.hp = ally.max_hp
	ally.level = maxi(1, bone.bone_level)
	ally.faction = Entity.Faction.PLAYER
	ally.appearance = &"bone_ally"
	ally.ai = &"ally"
	# Always up. An ally has no awareness state -- see `_take_ai_turn` -- but
	# the field is read in enough places that leaving it ASLEEP would be a trap
	# for whoever touches this next.
	ally.alertness = Entity.Alert.AWAKE
	ally.risen = false
	var who := bone.bone_name if bone.bone_name != "" else "Nameless"
	ally.name = who
	for text in bone.bone_gear:
		var it := Item.from_display_name(String(text))
		if it == null:
			continue
		ally.equipped[it.slot] = it
		ally.inventory.append(it)
		ally.threat += it.power_bonus + it.defense_bonus
	entities.append(ally)
	# Starts with a full turn's worth owed, like anything else that arrives
	# mid-fight, so summoning does not hand you a free extra attack this turn.
	Scheduler.spend(ally, Scheduler.ACTION_COST)
	events.append({"kind": &"notice", "to": spot})
	msg_log.add("%s rises, and stands with you." % who, Color(0.70, 0.90, 0.78))
	return true

## Announces a change of footing, once, when it changes.
func _note_footing() -> void:
	var here := map.get_tile(player.x, player.y)
	if here == _last_footing:
		return
	var was_hard := Tiles.move_cost(_last_footing) > 1.0
	var now_hard := Tiles.move_cost(here) > 1.0
	_last_footing = here

	if now_hard and not was_hard:
		events.append({"kind": &"footing", "to": Vector2i(player.x, player.y),
			"tile": here})
		match here:
			Tiles.MUD:
				msg_log.add("You sink to the ankle. Every step will cost you.",
					Color(0.80, 0.70, 0.55))
			Tiles.WATER:
				msg_log.add("You wade in. The going is slower.",
					Color(0.62, 0.78, 0.90))
			Tiles.RUBBLE:
				msg_log.add("Loose stone shifts underfoot.", Color(0.78, 0.74, 0.66))
			Tiles.BONES:
				msg_log.add("Bone splinters crack under your boots.",
					Color(0.88, 0.85, 0.75))
	elif was_hard and not now_hard:
		msg_log.add("Firm ground again.", Color(0.70, 0.72, 0.70))

func player_wait() -> bool:
	if game_over:
		return false
	_travel.clear()

	var brazier := _adjacent_brazier()
	if brazier.x >= 0 and player.hp < player.max_hp:
		var healed := mini(BRAZIER_HEAL, player.max_hp - player.hp)
		player.hp += healed
		brazier_charge[brazier] = int(brazier_charge[brazier]) - healed
		msg_log.add("You warm yourself at the brazier. (+%d)" % healed,
			Color(0.96, 0.76, 0.44))
		if int(brazier_charge[brazier]) <= 0:
			_gutter(brazier)

	_end_player_turn()
	return true

## Total experience required to have reached `n`.
func xp_for_level(n: int) -> int:
	if n <= 1:
		return 0
	var k := n - 1
	return XP_CURVE_A * k * k + XP_CURVE_B * k

func xp_into_level() -> int:
	# Clamped: level only ever rises through award_xp today, but a drain effect
	# or a loaded save could get here with less xp than the level implies, and
	# a progress bar should not render backwards.
	return maxi(0, player.xp - xp_for_level(player.level))

func xp_needed_for_next() -> int:
	return xp_for_level(player.level + 1) - xp_for_level(player.level)

func award_xp(amount: int) -> void:
	if amount <= 0:
		return
	player.xp += amount
	while player.xp >= xp_for_level(player.level + 1):
		_level_up()

func _level_up() -> void:
	player.level += 1
	player.max_hp += LEVEL_HP
	# Healed by the gain, so a level is a small reprieve as well as a stat bump.
	player.hp = mini(player.max_hp, player.hp + LEVEL_HP)
	if player.level % 2 == 0:
		player.power += 1
	if player.level % 3 == 0:
		player.defense += 1
	msg_log.add("You reach level %d." % player.level, Color(0.98, 0.90, 0.45))
	events.append({"kind": &"levelup", "to": Vector2i(player.x, player.y)})

## Is there any fire beside the player that could forge SOMETHING?
##
## Drives the inventory's forge line, which is why it does not take an item:
## the line is about the place, not the pack.
func can_forge_here() -> bool:
	var b := _adjacent_brazier()
	if b.x >= 0 and int(brazier_charge.get(b, 0)) >= MERGE_COST:
		return true
	return _adjacent_embers().x >= 0

## Whether the fire the player is standing at is a dying one.
##
## Only meaningful where can_forge_here() already holds. A live brazier always
## wins, so this answers "is the only fire here an ember bed".
func forging_in_embers() -> bool:
	var b := _adjacent_brazier()
	if b.x >= 0 and int(brazier_charge.get(b, 0)) >= MERGE_COST:
		return false
	return _adjacent_embers().x >= 0

## Where this particular item would be forged, and how. Empty if nowhere.
##
## One decision, in one place, so the inventory marker and the merge itself can
## never disagree about whether a given item is workable here -- which they
## would the moment embers started refusing potions.
func _forge_site(item: Item) -> Dictionary:
	var lit := _adjacent_brazier()
	if lit.x >= 0 and int(brazier_charge.get(lit, 0)) >= MERGE_COST:
		return {"cell": lit, "embers": false}
	if not _ember_forgeable(item):
		return {}
	var hot := _adjacent_embers()
	if hot.x >= 0:
		return {"cell": hot, "embers": true}
	return {}

## Can this specific item be forged right now? Drives the inventory marker, so
## the mechanic advertises itself instead of relying on the player guessing
## which of the two items involved is the one to click.
func can_forge_item(item: Item) -> bool:
	var donor := _find_duplicate(item)
	if donor == null or donor.upgrade_level() > item.upgrade_level():
		return false
	return item_can_upgrade(item) and not _forge_site(item).is_empty()

## Merge the item at `index` with an identical one from the pack, at a brazier.
func player_merge(index: int) -> bool:
	if game_over or index < 0 or index >= player.inventory.size():
		return false
	var item: Item = player.inventory[index]

	if not item.can_be_forged():
		msg_log.add("The flame has nothing to take hold of.", Color(0.7, 0.6, 0.4))
		return false
	if not item_can_upgrade(item):
		msg_log.add("The %s cannot take another edge." % item.display_name(),
			Color(0.7, 0.6, 0.4))
		return false

	var site := _forge_site(item)
	if site.is_empty():
		msg_log.add(_no_forge_reason(item), Color(0.7, 0.6, 0.4))
		return false
	var brazier: Vector2i = site["cell"]
	var embers: bool = site["embers"]

	var donor := _find_duplicate(item)
	if donor == null:
		msg_log.add("You have nothing else like the %s." % item.name,
			Color(0.7, 0.6, 0.4))
		return false
	# Never spend a better piece to make a worse one equal.
	#
	# `_find_duplicate` already prefers the LEAST upgraded donor, which is
	# right when there is a choice. With exactly one of each there is none: a
	# leather +1 and a plain leather, clicking the plain one, and the +1 is the
	# only thing that can be fed to it. The result was one leather +1 where
	# there had been two pieces -- an item gone and the upgrade bought nothing.
	#
	# Refused rather than redirected, because the player asked for something
	# specific and quietly improving the OTHER item would be a different act
	# than the one they clicked.
	if donor.upgrade_level() > item.upgrade_level():
		msg_log.add("The %s is the better piece. Work that one instead."
			% donor.display_name(), Color(0.7, 0.6, 0.4))
		return false

	_travel.clear()
	if player.is_equipped(donor):
		player.equipped.erase(donor.slot)
	player.inventory.erase(donor)
	donor.letter = ""

	item.upgrade()
	_tally("forges")
	if embers:
		_tally("ember_forges")
	events.append({"kind": &"forge", "to": brazier})

	if embers:
		# Costs no charge because there is none left to cost. It is paid for in
		# noise, and in the brazier itself.
		map.set_tile(brazier.x, brazier.y, Tiles.BRAZIER_DEAD)
		ember_until.erase(brazier)
		# Off the round. A guard has no reason to walk to a fire that will
		# never burn again, and `_lay_the_beat` already counts only lit and
		# spent ones -- it just never ran again after the level was built.
		_lay_the_beat()
		msg_log.add("You hammer it out in the dying coals. (%s)"
			% item.display_name(), Color(0.85, 0.88, 0.70))
		msg_log.add("The brazier goes black. Nothing will kindle it again.",
			Color(0.45, 0.42, 0.42))
		_make_noise(brazier, FORGE_NOISE, &"forge")
	else:
		brazier_charge[brazier] = int(brazier_charge[brazier]) - MERGE_COST
		if item.is_equipment():
			msg_log.add("You work the metal together over the flame. (%s)"
				% item.display_name(), Color(0.85, 0.88, 0.70))
		else:
			msg_log.add("You boil the two down to one, and it thickens. (%s)"
				% item.display_name(), Color(0.85, 0.88, 0.70))
		if int(brazier_charge[brazier]) <= 0:
			_gutter(brazier)

	_end_player_turn()
	return true

## Binds a gem into the weapon in hand, at a dying brazier, forever.
##
## EMBERS ONLY, and the fiction is the mechanic: live flame is too hot to set a
## stone, embers are the right heat. It is also what the ember forge has been
## waiting for -- until now it bought one extra `+1`, which is a consolation
## prize for a brazier you already drained. This makes a sequence out of it:
## warm yourself at a brazier for the ten hit points you wanted anyway, then
## have twenty turns and ONE working to decide between an edge and an element,
## carrying both the stone and the weapon before you start.
## Which equipped piece a gem goes into when the player does not name one.
##
## Asks `accepts_element` rather than naming a slot, because the slot is
## something the ELEMENT already knows: a blocking stone is for the shield hand
## and nothing else will hold it. Naming `Slot.WEAPON` here was the third copy
## of that condition, and the comment above `accepts_element` warns in as many
## words that three copies is how the three stop agreeing.
##
## Deliberately does NOT skip a piece that already holds a stone. Filtering
## those out here would replace "the war axe already holds a gem" with "you
## have nothing in hand to set it into", which is a worse sentence and a false
## one.
func _default_host(gem: Item) -> Variant:
	for slot in [Item.Slot.WEAPON, Item.Slot.OFFHAND, Item.Slot.ARMOR]:
		var it: Variant = player.equipped.get(slot, null)
		if it != null and it.accepts_element(gem.element):
			return it
	return null

func player_bind(index: int, target: int = -1) -> bool:
	if game_over or index < 0 or index >= player.inventory.size():
		return false
	var gem: Item = player.inventory[index]
	if gem.kind != Item.Kind.GEM:
		return false

	# The weapon is CHOSEN, not assumed. Defaulting to whatever is in hand
	# forced the gem into the wrong blade for anyone carrying two: a dagger and
	# a short sword, and no way to say which. -1 still means "the one in hand",
	# which is what the rake-down path and the tests use.
	var blade: Variant = null
	if target >= 0 and target < player.inventory.size():
		blade = player.inventory[target]
		if not blade.is_equipment():
			return false
	else:
		blade = _default_host(gem)
	if blade == null:
		msg_log.add("You have nothing in hand to set it into.",
			Color(0.7, 0.6, 0.4))
		return false
	# One stone, forever. Refused rather than replaced: the whole weight of the
	# choice is that it cannot be taken back, and overwriting would turn a
	# commitment into a preference.
	if blade.element != &"":
		msg_log.add("The %s already holds a gem. It will take no other."
			% blade.display_name(), Color(0.7, 0.6, 0.4))
		return false
	if not blade.accepts_element(gem.element):
		msg_log.add("The %s will not hold that one." % blade.display_name(),
			Color(0.7, 0.6, 0.4))
		return false

	var hot := _adjacent_embers()
	if hot.x < 0:
		var lit := _adjacent_brazier()
		if lit.x >= 0:
			# Raking the fire down: the first of two clicks.
			#
			# Without this a careful player is LOCKED OUT. Warming only works
			# while hurt, so at full health with nothing to merge there is no
			# way to reduce a brazier to coals at all, and the forge ends up
			# gated behind taking damage on purpose. That punishes playing
			# well, which no rule here should.
			#
			# Two deliberate clicks rather than a confirmation dialog: the game
			# has no prompt system, and an action with its own message IS the
			# confirmation. The price is whatever warmth was left -- the same
			# decision the brazier has always posed, with a third branch.
			var lost := int(brazier_charge.get(lit, 0))
			brazier_charge[lit] = 0
			_gutter(lit)
			msg_log.add("You rake the fire down to coals. (%d warmth given up)"
				% lost, Color(0.85, 0.75, 0.55))
			msg_log.add("Set the gem now, before they cool.",
				Color(0.70, 0.74, 0.80))
			_end_player_turn()
			return true
		msg_log.add("You need a guttering brazier to set a gem.",
			Color(0.7, 0.6, 0.4))
		return false

	_travel.clear()
	blade.element = gem.element
	player.inventory.erase(gem)
	gem.letter = ""
	_tally("bindings")
	events.append({"kind": &"forge", "to": hot})

	# Same cost as an ember forge, because it IS one: the brazier is spent.
	map.set_tile(hot.x, hot.y, Tiles.BRAZIER_DEAD)
	ember_until.erase(hot)
	_lay_the_beat()
	msg_log.add("You set the %s into the %s. It drinks the last of the heat."
		% [gem.name, blade.display_name()], Color(0.85, 0.88, 0.70))
	msg_log.add("The brazier goes black. Nothing will kindle it again.",
		Color(0.45, 0.42, 0.42))
	_make_noise(hot, FORGE_NOISE, &"forge")
	_end_player_turn()
	return true

## Can this gem be set right now? Drives the inventory marker, the same way
## can_forge_item does -- so a weapon that already holds one simply never
## offers, rather than refusing after the click.
func can_bind_gem(gem: Item) -> bool:
	if gem.kind != Item.Kind.GEM:
		return false
	var blade: Variant = _default_host(gem)
	if blade == null or blade.element != &"":
		return false
	# True at a LIT brazier too: the click there rakes the fire down, which is
	# a real step toward binding rather than a refusal. Marking it otherwise
	# would hide the only route a healthy player has to the forge.
	return _adjacent_embers().x >= 0 or _adjacent_brazier().x >= 0

## Why there is no forging this, here. Four different situations that all used
## to print "you need a lit brazier", which is a lie in three of them.
func _no_forge_reason(item: Item) -> String:
	var lit := _adjacent_brazier()
	if lit.x >= 0:
		return "The brazier has not the heat left."
	if _adjacent_embers().x >= 0:
		return "Embers will work metal. They will not boil the %s." % item.name
	if _adjacent_spent_brazier().x >= 0:
		return "The ashes have gone cold. There is no working them."
	# Adjacent, not underfoot: a brazier of any kind is an obstacle, so the
	# player is never standing on one to be told about it.
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if map.get_tile(player.x + dx, player.y + dy) == Tiles.BRAZIER_DEAD:
				return "That one is black through. It will take nothing."
	return "You need a lit brazier to work metal."

## Any other item of the same kind, whatever its own upgrade level.
##
## Requiring matched levels was the first version and it made the cost
## geometric -- four daggers for a +2 rather than three. The cap already does
## the balancing, so the simpler rule wins.
## The cheapest thing that can feed this one.
##
## It used to take the first match in pack order, which quietly destroyed
## upgrades: with a potion +1 sitting earlier in the list, merging two plain
## potions consumed the +1 as the donor. You ended up with one +1 where you
## already had one, two plain potions gone, and nothing on screen explaining
## where the good one went. Reported from play as "one of them vanishes and the
## original does not go up".
##
## Taking the LEAST upgraded donor is always the best outcome available, so
## there is never a reason to pick differently: a +1 fed by a plain one becomes
## a +2, while a +1 fed by another +1 becomes a +2 and costs an upgrade to do
## it. Same result, higher price.
func _find_duplicate(item: Item) -> Item:
	var best: Item = null
	for other in player.inventory:
		if other == item or other.id != item.id:
			continue
		if best == null or other.upgrade_level() < best.upgrade_level():
			best = other
	return best

## A brazier reaching the end of its charge, from either use of it.
##
## One place, because the ember clock has to start no matter which way the fire
## was spent -- and a player who burned the last four charges on a forge should
## get the same offer as one who burned them on hit points.
## Fires go out whether or not anyone is warming their hands at them.
##
## Keyed on the turn count rather than a per-brazier timer, so it costs nothing
## to track and a saved run resumes on the same rhythm it left.
func _burn_the_fires_down() -> void:
	if turns % BRAZIER_BURN_EVERY != 0:
		return
	var spent: Array[Vector2i] = []
	for cell in brazier_charge:
		if map.get_tile(cell.x, cell.y) != Tiles.BRAZIER:
			continue
		brazier_charge[cell] = int(brazier_charge[cell]) - 1
		if int(brazier_charge[cell]) <= 0:
			spent.append(cell)
	# Collected first: `_gutter` erases from the dictionary being walked.
	for cell in spent:
		_gutter(cell)

func _gutter(cell: Vector2i) -> void:
	brazier_charge.erase(cell)
	map.set_tile(cell.x, cell.y, Tiles.BRAZIER_SPENT)
	ember_until[cell] = turns + EMBER_TURNS
	_tally("braziers")
	_gather_lights()
	msg_log.add("The brazier gutters out.", Color(0.58, 0.55, 0.50))
	# Said only when there is something in the pack it could be said about, in
	# the same spirit as the inventory's forge line: a hint that fires on all
	# hundred-odd braziers a run burns through is not a hint, it is wallpaper.
	# No count and no timer -- that the heat is going is the whole warning.
	if _has_ember_work():
		msg_log.add("The embers still hold heat enough to work metal. "
			+ "They will not hold it long.", Color(0.86, 0.62, 0.34))

## Is the player carrying anything the embers could actually take?
func _has_ember_work() -> bool:
	for it in player.inventory:
		if _ember_forgeable(it) and item_can_upgrade(it) \
				and _find_duplicate(it) != null:
			return true
	return false

## Embers work metal and nothing else.
##
## A bed of dying coals will let you hammer an edge back into iron; it will not
## hold a decoction at temperature. The rule is fiction first, but it earns its
## keep twice over -- it keeps the ember forge pointed at the one extra +1 it
## was added for, instead of quietly becoming a potion-stacking engine that
## runs on every burnt-out brazier in the dungeon.
func _ember_forgeable(item: Item) -> bool:
	return item.is_equipment()

## How much heat is left in the embers at this cell: 1.0 the turn it guttered,
## falling to 0.0 as they go cold. Zero for anything that is not a dying
## brazier.
##
## Sim-side because the sim owns both halves of the sum, and a query rather
## than a raw dictionary because what the renderer wants is the FRACTION -- how
## much of the decision is left -- not the turn number it happens to be stored
## as. The colour that fraction becomes is the renderer's business entirely.
func ember_heat(x: int, y: int) -> float:
	var cell := Vector2i(x, y)
	if not ember_until.has(cell):
		return 0.0
	var left := int(ember_until[cell]) - turns
	if left <= 0:
		return 0.0
	return clampf(float(left) / float(EMBER_TURNS), 0.0, 1.0)

## An adjacent brazier that has gone out but is still hot enough to forge in.
func _adjacent_embers() -> Vector2i:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var c := Vector2i(player.x + dx, player.y + dy)
			if map.get_tile(c.x, c.y) == Tiles.BRAZIER_SPENT \
					and turns < int(ember_until.get(c, -1)):
				return c
	return Vector2i(-1, -1)

func _adjacent_spent_brazier() -> Vector2i:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var c := Vector2i(player.x + dx, player.y + dy)
			if map.get_tile(c.x, c.y) == Tiles.BRAZIER_SPENT:
				return c
	return Vector2i(-1, -1)

## A lit brazier beside the player with something left in it.
func _adjacent_brazier() -> Vector2i:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var c := Vector2i(player.x + dx, player.y + dy)
			if map.get_tile(c.x, c.y) == Tiles.BRAZIER and int(brazier_charge.get(c, 0)) > 0:
				return c
	return Vector2i(-1, -1)

func player_descend() -> bool:
	if game_over:
		return false
	if map.get_tile(player.x, player.y) != Tiles.STAIRS_DOWN:
		msg_log.add("There are no stairs here.", Color(0.7, 0.6, 0.4))
		return false
	# Paid for the floor just survived, not the one being entered.
	var earned := room_threat_ceiling() * XP_DEPTH_MULTIPLIER
	depth += 1
	build_level()
	msg_log.add("You descend to depth %d." % depth, Color(0.85, 0.72, 0.45))
	award_xp(earned)
	return true

func player_pickup() -> bool:
	if game_over:
		return false
	_travel.clear()
	var here := items_at(player.x, player.y)
	if not here.is_empty() and here[0].id == &"arrows":
		return _gather_ammo(here[0])
	if here.is_empty():
		# WHATEVER THIS SQUARE IS FOR. Gabe's suggestion, by email, and Brad's
		# extension of it to the shrine.
		#
		# This key was ALREADY contextual and nobody had noticed: it gathered
		# arrows, ate fungus, knapped stones or picked something up, four
		# behaviours chosen by what you were standing on. What it did not do
		# was the terrain you stand on deliberately -- so the stairs needed `>`
		# and `<`, which on a pad is `shift`, which a pad cannot send. A
		# controller could not leave floor one.
		#
		# Gabe's actual words were about re-learning: "why not make code as
		# where the G key will know if your ascending or descending, and then
		# do the right action". A tile is never both, so the game already knows
		# and was making the player say it twice.
		#
		# Dispatched on the TILE rather than by trying each action in turn,
		# because every one of these refuses with its own message -- speculative
		# calls would print "There are no stairs here" on open floor.
		var under := map.get_tile(player.x, player.y)
		if under == Tiles.FUNGUS:
			return _eat_fungus()
		if under == Tiles.RUBBLE:
			return _knap_stones()
		if under == Tiles.STAIRS_DOWN:
			return player_descend()
		if under == Tiles.STAIRS_UP:
			return player_ascend()
		if under == Tiles.SHRINE:
			return player_pray()
		msg_log.add("There is nothing here to pick up.", Color(0.7, 0.6, 0.4))
		return false
	if player.inventory.size() >= Entity.INVENTORY_MAX:
		msg_log.add("You cannot carry any more.", Color(0.9, 0.55, 0.35))
		return false
	var item: Item = here[0]
	if item.kind == Item.Kind.AMULET:
		_seize_amulet(item)
		return true
	ground.erase(item)
	give_item(item)
	# Counted here rather than in give_item, which the tests and the starting
	# kit also go through. This is the player deciding to bend down.
	_tally_in("picked", item.name)
	msg_log.add("You pick up the %s (%s)." % [item.name, item.letter],
		Color(0.75, 0.80, 0.90))
	_end_player_turn()
	return true

## Taking the amulet turns the run around.
##
## The dungeon is regenerated rather than restored, which the fiction covers:
## the artefact was trapped, and the depths rearrange behind you. That justifies
## both the new layout and the heavier population, and it costs nothing --
## remembering ten floors would have meant serialising them.
func _seize_amulet(relic: Item) -> void:
	ground.erase(relic)
	give_item(relic)
	ascending = true

	msg_log.add("You lift the Amulet of the Deep. The dungeon shudders.",
		Color(1.00, 0.88, 0.45))
	msg_log.add("Stone grinds on stone. When it stills, nothing is where you "
		+ "left it.", Color(0.85, 0.80, 0.70))
	msg_log.add("More eyes than before catch your torchlight. The way out is "
		+ "up.", Color(0.95, 0.70, 0.40))

	build_level()
	update_vision()

## Climbing out. Pays for the floor survived, exactly as descending does.
## A mouthful of glowing fungus. One point, and the patch goes dark.
##
## Deliberately not worth a detour: at one hit point a turn it is slower than
## resting at a brazier, and a floor only grows a dozen or so of them. What it
## is worth is being taken on the way past -- and it costs the light, which is
## the actual decision. A cave lit by fungus is a cave you can see across.
func _eat_fungus() -> bool:
	if player.hp >= player.max_hp:
		msg_log.add("You are whole. The fungus can keep its light.",
			Color(0.7, 0.6, 0.4))
		return false
	player.hp += 1
	map.set_tile(player.x, player.y,
		Tiles.CAVE_FLOOR if map.material_at(player.x, player.y) == Materials.CAVERN
		else Tiles.FLOOR)
	_gather_lights()
	msg_log.add("You eat the fungus. It is bitter, and the glow goes out. (+1 hp)",
		Color(0.62, 0.85, 0.68))
	_end_player_turn()
	return true

## Rubble is a pile of stones, and a sling wants stones.
##
## It was pure cost before -- slow ground that did nothing else -- and this
## makes a nuisance into a supply without adding anything to the floor. Note
## what it costs: rubble is slow going, so reloading means standing on the one
## terrain that makes retreating harder, and the pile is destroyed by taking
## it, exactly as bones are destroyed by crossing them.
##
## The world is not the constraint. A floor grows about thirty rubble tiles,
## so there are sixty to ninety stones lying around; what limits a sling is
## that it holds ten and every reload is a turn.
func _knap_stones() -> bool:
	# THE ONE IN HAND FIRST, THEN THE PACK.
	#
	# Gabe again, and the complaint was not "let me stockpile stones" -- stones
	# are not an item, they are a counter on the weapon, so there is nowhere for
	# a loose one to live. It was that rubble could only be worked while the
	# sling was EQUIPPED, so topping up meant swapping to it, knapping, and
	# swapping back. The swap costs a turn at each end, which is most of a fight.
	#
	# One pass rather than two helpers, because "no sling at all" and "every
	# sling is full" are different refusals and the old code could only say the
	# first one.
	var held: Variant = player.equipped.get(Item.Slot.WEAPON, null)
	var sling: Item = null
	var any_sling := false
	if held != null and held.ammo_kind == &"stone":
		any_sling = true
		if held.ammo < held.ammo_max:
			sling = held
	if sling == null:
		for it in player.inventory:
			if it.ammo_kind != &"stone":
				continue
			any_sling = true
			if it.ammo < it.ammo_max:
				sling = it
				break
	if sling == null:
		msg_log.add("You have all the stones you can carry." if any_sling
			else "Loose stone, and nothing to sling it with.",
			Color(0.7, 0.6, 0.4))
		return false
	# One stone a tile, so every shot costs a turn spent on rubble somewhere.
	#
	# It gave two or three at first, which worked out at under half a turn per
	# stone -- thirty of them was three or four fights before anyone had to go
	# looking. One apiece makes the price legible: a stone slung is a turn owed.
	# The pouch still holds thirty, so passing a rubble field is worth stopping
	# for rather than something you top up in one action.
	var got := mini(1, sling.ammo_max - sling.ammo)
	sling.ammo += got
	map.set_tile(player.x, player.y,
		Tiles.CAVE_FLOOR if map.material_at(player.x, player.y) == Materials.CAVERN
		else Tiles.FLOOR)
	var into := "" if sling == held else " into the %s in your pack" % sling.name
	msg_log.add("You work a stone loose from the rubble%s. (%d/%d)"
		% [into, sling.ammo, sling.ammo_max], Color(0.80, 0.78, 0.70))
	_end_player_turn()
	return true

## Arrows finding their way home.
##
## Counted in TURNS rather than in tiles moved, because a turn is what the rest
## of this game charges for -- waiting in mud, opening a door and standing still
## all cost one, and an arrow that only came back when you walked would reward
## pacing about rather than fighting.
## The ring burning down, a turn at a time.
##
## Charged by TURNS SPENT AS A RAT rather than by transformation, so changing
## back to use a brazier pauses the drain instead of costing another use. When
## it runs out you are simply a person again, standing wherever you were.
func _burn_the_ring() -> void:
	if not ratted():
		return
	var ring: Item = player.equipped[Item.Slot.WEAPON]
	ring.charges -= 1
	if ring.charges == RING_WARNING:
		msg_log.add("The ring is growing cold on your paw.",
			Color(0.75, 0.70, 0.80))
	if ring.charges > 0:
		return
	player.equipped.erase(Item.Slot.WEAPON)
	player.inventory.erase(ring)
	msg_log.add("The ring crumbles, and you are yourself again.",
		Color(0.85, 0.80, 0.90))
	update_vision()

func _tick_returning() -> void:
	var bow: Variant = player.equipped.get(Item.Slot.WEAPON, null)
	if bow == null or bow.element != &"return":
		_return_walk = 0
		return
	_return_walk += 1
	if _return_walk < GEM_RETURN_STEPS:
		return
	_return_walk = 0
	if bow.ammo >= bow.ammo_max:
		return

	var came := 0
	var from: Array[Vector2i] = []
	for it in ground.duplicate():
		if it.id != &"arrows":
			continue
		var room: int = int(bow.ammo_max) - int(bow.ammo) - came
		if room <= 0:
			break
		var taken: int = mini(it.ammo, room)
		came += taken
		it.ammo -= taken
		from.append(Vector2i(it.x, it.y))
		if it.ammo <= 0:
			ground.erase(it)
	if came <= 0:
		return
	bow.ammo += came
	# One event per pile, so the renderer can draw each flight from where it
	# actually lay rather than from an average of them.
	for at in from:
		events.append({"kind": &"recall", "from": at,
			"to": Vector2i(player.x, player.y)})
	msg_log.add("Your arrows shiver loose and come back. (+%d, %d/%d)"
		% [came, bow.ammo, bow.ammo_max], Color(0.80, 0.85, 0.70))

## Gathering spent arrows back into the quiver.
func _gather_ammo(pile: Item) -> bool:
	var bow: Item = player.equipped.get(Item.Slot.WEAPON, null)
	if bow == null or bow.ammo_kind != &"arrow":
		msg_log.add("You have no bow to put them to.", Color(0.7, 0.6, 0.4))
		return false
	if bow.ammo >= bow.ammo_max:
		msg_log.add("Your quiver is full.", Color(0.7, 0.6, 0.4))
		return false
	var taken := mini(pile.ammo, bow.ammo_max - bow.ammo)
	bow.ammo += taken
	pile.ammo -= taken
	if pile.ammo <= 0:
		ground.erase(pile)
	msg_log.add("You gather %d arrows. (%d/%d)" % [taken, bow.ammo, bow.ammo_max],
		Color(0.80, 0.85, 0.70))
	_end_player_turn()
	return true

func player_ascend() -> bool:
	if game_over:
		return false
	if map.get_tile(player.x, player.y) != Tiles.STAIRS_UP:
		msg_log.add("There is no way up here.", Color(0.7, 0.6, 0.4))
		return false

	var earned := room_threat_ceiling() * XP_DEPTH_MULTIPLIER
	depth -= 1
	if depth <= 0:
		won = true
		game_over = true
		award_xp(earned)
		write_morgue()
		write_death_dump()
		msg_log.add("You climb into daylight, the Amulet of the Deep in hand. "
			+ "You have escaped. Press R to descend again.",
			Color(1.00, 0.92, 0.55))
		return true

	build_level()
	msg_log.add("You climb to depth %d." % depth, Color(0.85, 0.72, 0.45))
	award_xp(earned)
	return true

func player_use(index: int) -> bool:
	if game_over or index < 0 or index >= player.inventory.size():
		return false
	_travel.clear()
	var item: Item = player.inventory[index]

	# One action for the whole list: a potion is drunk, a sword is wielded.
	# The player should not have to remember which verb a slot wants.
	if item.is_equipment():
		_toggle_equip(item)
		_end_player_turn()
		return true

	# A refused effect costs neither the item nor the turn. Wasting a potion to
	# a misclick is the kind of thing that makes people stop playing.
	if not _apply_effect(item):
		return false
	player.inventory.remove_at(index)
	item.letter = ""
	_end_player_turn()
	return true

func _toggle_equip(item: Item) -> void:
	if player.is_equipped(item):
		player.equipped.erase(item.slot)
		msg_log.add("You put away the %s." % item.name)
		return
	var previous: Item = player.equipped.get(item.slot, null)
	player.equipped[item.slot] = item
	if previous == null:
		msg_log.add("You %s the %s." % [item.verb(), item.name], Color(0.80, 0.85, 0.95))
	else:
		msg_log.add("You swap the %s for the %s." % [previous.name, item.name],
			Color(0.80, 0.85, 0.95))
	_free_the_other_hand(item)

## A launcher needs both hands, so a bow and a shield cannot be carried at once.
## Whichever was picked up last wins, and the other is put away rather than
## silently ignored -- an equipment rule the player cannot see is a rule they
## will think is a bug.
func _free_the_other_hand(item: Item) -> void:
	var displaced: Item = null
	if item.is_two_handed():
		displaced = player.equipped.get(Item.Slot.OFFHAND, null)
		if displaced != null:
			player.equipped.erase(Item.Slot.OFFHAND)
	elif item.slot == Item.Slot.OFFHAND:
		var held: Item = player.equipped.get(Item.Slot.WEAPON, null)
		if held != null and held.is_two_handed():
			displaced = held
			player.equipped.erase(Item.Slot.WEAPON)
	if displaced != null:
		msg_log.add("You need both hands for that. The %s goes on your back."
			% displaced.name, Color(0.85, 0.80, 0.62))

## Swap between reach and blade: the best launcher you carry, and the best
## melee weapon you carry.
##
## This exists because of a measured trap. Toe to toe with a young dragon, the
## same character wins 100% of the time with a war axe and 0% with a war bow --
## swinging a launcher halves your power, so every blow lands at the damage
## floor. The axe was in the pack the whole time. One key turns that from a
## menu dive into a reflex.
##
## It costs a turn, like any other change of equipment. Free, and you could
## shoot, swap and strike in one turn, which would undo the whole reason an
## archer fears being closed with.
func player_swap_weapon() -> bool:
	if game_over:
		return false
	var held: Item = player.equipped.get(Item.Slot.WEAPON, null)
	var want_reach := held == null or not held.is_two_handed()
	var best: Item = null
	for it in player.inventory:
		if it.slot != Item.Slot.WEAPON or it == held:
			continue
		# Never swap you INTO something that changes what you are.
		#
		# Reported from play, and it was reachable without trying: throw your
		# dagger, hold a bow, carry the ring, and this key -- the one that
		# exists so a cornered archer can get a blade in his hands -- turned
		# you into a blind, handless rat instead. The panic button is the worst
		# possible place for a surprise.
		#
		# This denies nothing. The ring can still be put on from the pack for
		# the same one turn this key costs, so every strategy rat form allows
		# is exactly as available as it was. What it removes is a shortcut that
		# was also QUIETLY BETTER than the pack: the swap re-raises your shield
		# on the way to a one-handed item, so going this way made you a rat
		# still somehow holding a buckler. Nobody designed that; it fell out of
		# two correct rules meeting.
		if it.transforms():
			continue
		if it.is_two_handed() != want_reach:
			continue
		# Reach for a launcher, raw power for a blade.
		if best == null \
				or (want_reach and it.range_bonus > best.range_bonus) \
				or (not want_reach and it.power_bonus > best.power_bonus):
			best = it
	if best == null:
		msg_log.add("You have nothing to swap to." if want_reach
			else "You have no blade to fall back on.", Color(0.7, 0.6, 0.4))
		return false
	_travel.clear()
	_toggle_equip(best)

	# Going back to a blade frees the hand the launcher was using, so the
	# shield goes back on it.
	#
	# Reported from play, and it is the gap between what this key was described
	# as and what it first did. The offhand rule only ever TOOK the shield away
	# -- a launcher needs both hands -- and nothing ever gave it back, so
	# sling, sword, sling left the buckler in the pack forever. This is meant
	# to swap a posture, not a weapon: reach and no shield, or blade and shield.
	#
	# One turn for the pair rather than one each. Charging separately would
	# make the key slower than doing it by hand out of the inventory, which
	# defeats the point of having it -- and the opposite swap has always given
	# up the shield for free.
	if not best.is_two_handed():
		var shield := _best_offhand()
		if shield != null and not player.is_equipped(shield):
			player.equipped[Item.Slot.OFFHAND] = shield
			msg_log.add("You raise the %s with it." % shield.display_name(),
				Color(0.80, 0.85, 0.95))
	_end_player_turn()
	return true

## The heaviest shield in the pack, upgrades counted.
func _best_offhand() -> Item:
	var best: Item = null
	for it in player.inventory:
		if it.slot != Item.Slot.OFFHAND:
			continue
		if best == null or it.defense_bonus > best.defense_bonus:
			best = it
	return best

func player_drop(index: int) -> bool:
	if game_over or index < 0 or index >= player.inventory.size():
		return false
	_travel.clear()
	var item: Item = player.inventory[index]
	# Dropping something you are wearing takes it off first, rather than
	# leaving a dangling reference in `equipped`.
	if player.is_equipped(item):
		player.equipped.erase(item.slot)
	player.inventory.remove_at(index)
	item.letter = ""
	item.x = player.x
	item.y = player.y
	ground.append(item)
	msg_log.add("You drop the %s." % item.name)
	_end_player_turn()
	return true

## Returns false if the item declined to be used, in which case it is not spent.
func _apply_effect(item: Item) -> bool:
	match item.effect:
		&"summon":
			return _summon_ally(item)
		&"raise_corpse":
			return _raise_the_recent_dead()

		&"open_sack":
			return _open_sack()

		&"heal":
			if player.hp >= player.max_hp:
				msg_log.add("You are already whole.", Color(0.7, 0.6, 0.4))
				return false
			var healed := mini(item.effective_magnitude(), player.max_hp - player.hp)
			player.hp += healed
			msg_log.add("You %s the %s. %d hp restored."
				% [item.verb(), item.display_name(), healed],
				Color(0.55, 0.85, 0.55))
			return true

		&"light":
			var dead := _adjacent_spent_brazier()
			if dead.x >= 0:
				map.set_tile(dead.x, dead.y, Tiles.BRAZIER)
				# A worked scroll carries more fire into the dead coals. The
				# charge IS hit points -- resting takes two off it and gives
				# two back -- so this is the same currency a potion trades in.
				brazier_charge[dead] = RELIGHT_CHARGE \
					+ item.upgrade_level() * item.forge_bonus
				# It is a live fire again; the ember clock belongs to the next
				# time it dies, not to this one.
				ember_until.erase(dead)
				_gather_lights()
				msg_log.add("The scroll's light pours into the dead brazier. "
					+ "It catches, weakly.", Color(0.98, 0.82, 0.45))
				return true

			var buf := PackedByteArray()
			buf.resize(map.width * map.height)
			Fov.compute(map, player.x, player.y, item.effective_magnitude(), buf)
			var revealed := 0
			for i in buf.size():
				if buf[i] != 0 and map.explored[i] == 0:
					map.explored[i] = 1
					revealed += 1
			msg_log.add("Light floods out. %d new cells revealed." % revealed,
				Color(0.95, 0.88, 0.60))
			return true

		&"blink":
			var spots := []
			var r := item.magnitude
			for y in range(maxi(0, player.y - r), mini(map.height, player.y + r + 1)):
				for x in range(maxi(0, player.x - r), mini(map.width, player.x + r + 1)):
					if not map.is_walkable(x, y):
						continue
					if entity_at(x, y) != null:
						continue
					if x == player.x and y == player.y:
						continue
					spots.append(Vector2i(x, y))
			if spots.is_empty():
				msg_log.add("The scroll fizzles -- nowhere to go.", Color(0.7, 0.6, 0.4))
				return false
			var dest: Vector2i = spots[rng.randi_range(0, spots.size() - 1)]
			player.x = dest.x
			player.y = dest.y
			msg_log.add("The world lurches. You are elsewhere.", Color(0.75, 0.70, 0.95))
			return true

	return false

## Begin a mouse-driven walk. Returns false if the destination is unreachable.
func begin_travel(to: Vector2i) -> bool:
	if game_over or not map.is_explored(to.x, to.y):
		return false
	var route := pathfinder.path(Vector2i(player.x, player.y), to)
	if route.is_empty():
		return false
	_travel = route
	return step_travel()

func travelling() -> bool:
	return not _travel.is_empty()

## Advances one step of a queued mouse-travel. Stops for anything interesting.
func step_travel() -> bool:
	if _travel.is_empty() or game_over:
		return false
	if not _travel_stoppers().is_empty():
		_travel.clear()
		msg_log.add("You stop -- something is watching.", Color(0.9, 0.55, 0.35))
		return false
	var next := _travel[0]
	var dx := next.x - player.x
	var dy := next.y - player.y
	if entity_at(next.x, next.y) != null or not map.is_walkable(next.x, next.y):
		_travel.clear()
		return false
	_travel.remove_at(0)
	# Deliberately not player_move(): that clears the travel queue.
	var cost := move_cost_for(player, next.x, next.y)
	player.x = next.x
	player.y = next.y
	_end_player_turn(cost)
	return true

func _end_player_turn(cost: int = Scheduler.ACTION_COST) -> void:
	Scheduler.spend(player, cost)
	turns += 1
	_tick_returning()
	# The cost was already being computed and thrown away. Difficult ground has
	# always charged the world for the time it takes; this is the first thing
	# that charges the record too.
	elapsed += cost
	_note_footing()
	var underfoot := map.get_tile(player.x, player.y)
	# Eight inches of rat crossing a boneyard makes no sound worth hearing.
	# The sharpest thing the ring buys: it is the only way past a gravestone
	# in bones without waking what is under it.
	if not ratted():
		_make_noise(Vector2i(player.x, player.y), Tiles.noise_radius(underfoot))
	_burn_the_ring()
	if underfoot == Tiles.BONES:
		# Crossing it destroys it. That turns a boneyard from a standing toll
		# into something you can PREPARE -- walk it once while things are
		# asleep and far off, and you have bought yourself a silent route for
		# when you need one.
		map.set_tile(player.x, player.y,
			Tiles.CAVE_FLOOR if map.material_at(player.x, player.y) == Materials.CAVERN
			else Tiles.FLOOR)
	var stood := Vector2i(player.x, player.y)
	if grave_at.has(stood) and stood != _last_grave:
		_last_grave = stood
		msg_log.add(Morgue.inscription(grave_at[stood]), Color(0.72, 0.74, 0.80))
	elif not grave_at.has(stood):
		_last_grave = Vector2i(-1, -1)
	if torch_flare > 0:
		torch_flare -= 1
		if torch_flare == 0:
			msg_log.add("The flare gutters down to an ordinary flame.",
				Color(0.80, 0.75, 0.60))
	_burn_the_fires_down()
	_let_the_stone_settle()
	update_vision()
	_run_world()
	update_vision()
	_check_health_warning()

## Matches the fraction at which the sidebar bar starts to throb. The bar is
## the better instrument -- it is continuous, and it is always there -- but it
## sits at the edge of vision while you are reading the map, which is exactly
## how the slinger got its kill in an open cave.
func _check_health_warning() -> void:
	if not player.alive:
		_hp_warned = true
		return
	var low := float(player.hp) / float(player.max_hp) < HP_WARN_FRACTION
	if low and not _hp_warned:
		events.append({"kind": &"lowhp", "to": Vector2i(player.x, player.y)})
	_hp_warned = low

# ----------------------------------------------------------- world turn ----

# ----------------------------------------------------------- persistence ----

static func has_suspend() -> bool:
	return FileAccess.file_exists(SUSPEND_PATH)

static func clear_suspend() -> void:
	if FileAccess.file_exists(SUSPEND_PATH):
		DirAccess.remove_absolute(SUSPEND_PATH)

func save_suspend() -> bool:
	var f := FileAccess.open(SUSPEND_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(to_dict()))
	f.close()
	return true

## Reads the slot and immediately destroys it. That deletion is the entire
## anti-scum mechanism: there is never a moment when a save from *before*
## something went wrong still exists.
static func load_suspend() -> GameState:
	if not has_suspend():
		return null
	var f := FileAccess.open(SUSPEND_PATH, FileAccess.READ)
	if f == null:
		return null
	var text := f.get_as_text()
	f.close()
	clear_suspend()

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	var gs := GameState.new(1)
	if not gs.apply_dict(parsed):
		return null
	return gs

func _shrines_to_dict() -> Dictionary:
	var out := {}
	for cell in shrine_at:
		out["%d,%d" % [cell.x, cell.y]] = int(shrine_at[cell])
	return out

func to_dict() -> Dictionary:
	var mobs := []
	for e in entities:
		mobs.append(e.to_dict())
	var loot := []
	for it in ground:
		loot.append(it.to_dict())
	var charges := {}
	for cell in brazier_charge:
		charges["%d,%d" % [cell.x, cell.y]] = int(brazier_charge[cell])
	# Absolute turn numbers, not remaining turns, because `turns` is saved
	# alongside them and the two have to mean the same thing on reload.
	var embers := {}
	for cell in ember_until:
		embers["%d,%d" % [cell.x, cell.y]] = int(ember_until[cell])
	# Absolute turn numbers, same as the embers above, plus the tile to put
	# back. Without this a suspend taken while stone is up restores a floor
	# with permanent stalagmites -- the exact failure the timer replaced.
	var stone := {}
	for cell in spires:
		var row: Array = spires[cell]
		stone["%d,%d" % [cell.x, cell.y]] = [int(row[0]), int(row[1])]
	var caves := []
	for r in cave_regions:
		caves.append([r.position.x, r.position.y, r.size.x, r.size.y])
	var rooms := []
	for r in room_rects:
		rooms.append([r.position.x, r.position.y, r.size.x, r.size.y])
	var lines := []
	for entry in msg_log.entries:
		var c: Color = entry["color"]
		lines.append({"t": entry["text"], "n": entry["count"], "c": [c.r, c.g, c.b]})

	return {
		"version": SAVE_VERSION,
		# Strings, not numbers: JSON stores numbers as doubles, and a 64-bit
		# rng state would quietly lose its low bits -- so a resumed run would
		# drift away from the one that was saved.
		"seed": str(rng.seed), "state": str(rng.state),
		"depth": depth, "turns": turns, "elapsed": elapsed,
		"elapsed_est": elapsed_estimated,
		"stats": stats, "ascending": ascending,
		"won": won, "game_over": game_over, "torch_lit": torch_lit,
		"cause": death_cause,
		"w": map.width, "h": map.height,
		"tiles": Marshalls.raw_to_base64(map.tiles),
		"material": Marshalls.raw_to_base64(map.material),
		"explored": Marshalls.raw_to_base64(map.explored),
		"stairs": [stairs.x, stairs.y],
		"braziers": charges, "embers": embers, "spires": stone,
		"caves": caves, "rooms": rooms,
		"shrines": _shrines_to_dict(), "graves": _graves_to_dict(),
		"grave_risen": grave_risen,
		"recent_dead": recent_dead,
		"gem_found": gem_found,
		"player_name": player_name,
		"uniques": uniques_found.keys(),
		"risen_grave": [risen_grave.x, risen_grave.y],
		"hues": shrine_hues,
		"known": shrine_known.keys(), "forge_bonus": forge_cap_bonus,
		"flare": torch_flare,
		"entities": mobs, "player": entities.find(player),
		"ground": loot, "log": lines,
	}

func apply_dict(d: Dictionary) -> bool:
	if int(d.get("version", 0)) != SAVE_VERSION:
		return false

	rng.seed = str(d.get("seed", "0")).to_int()
	rng.state = str(d.get("state", "0")).to_int()
	depth = int(d.get("depth", 1))
	# Absent from any save written before the run recorder existed, and absent
	# is the point: `stats` stays empty and the end screen omits what it cannot
	# honestly report. `elapsed` falls back to the turn count at one round
	# each, which is the best guess available and never worse than zero.
	elapsed_estimated = bool(d.get("elapsed_est", not d.has("elapsed")))
	elapsed = int(d.get("elapsed", int(d.get("turns", 0)) * Scheduler.ACTION_COST))
	stats = _stats_from(d.get("stats", {}))
	turns = int(d.get("turns", 0))
	ascending = d.get("ascending", false)
	won = d.get("won", false)
	game_over = d.get("game_over", false)
	torch_lit = d.get("torch_lit", true)
	death_cause = d.get("cause", "")

	map = DungeonMap.new(int(d.get("w", MAP_W)), int(d.get("h", MAP_H)))
	map.tiles = Marshalls.base64_to_raw(d.get("tiles", ""))
	map.material = Marshalls.base64_to_raw(d.get("material", ""))
	map.explored = Marshalls.base64_to_raw(d.get("explored", ""))
	light_map = LightMap.new(map.width, map.height)
	var buf := PackedByteArray()
	buf.resize(map.width * map.height)
	_fov_buffer = buf

	var st: Array = d.get("stairs", [0, 0])
	stairs = Vector2i(int(st[0]), int(st[1]))

	brazier_charge.clear()
	var charges: Dictionary = d.get("braziers", {})
	for key in charges:
		var parts: PackedStringArray = String(key).split(",")
		if parts.size() == 2:
			brazier_charge[Vector2i(parts[0].to_int(), parts[1].to_int())] = int(charges[key])

	spires.clear()
	var stone: Dictionary = d.get("spires", {})
	for key in stone:
		var bits: PackedStringArray = String(key).split(",")
		var row: Array = stone[key]
		if bits.size() == 2 and row.size() == 2:
			spires[Vector2i(bits[0].to_int(), bits[1].to_int())] = \
				[int(row[0]), int(row[1])]

	ember_until.clear()
	var embers: Dictionary = d.get("embers", {})
	for key in embers:
		var bits: PackedStringArray = String(key).split(",")
		if bits.size() == 2:
			ember_until[Vector2i(bits[0].to_int(), bits[1].to_int())] = int(embers[key])

	shrine_at.clear()
	var saved_shrines: Dictionary = d.get("shrines", {})
	for key in saved_shrines:
		var bits: PackedStringArray = String(key).split(",")
		if bits.size() == 2:
			shrine_at[Vector2i(bits[0].to_int(), bits[1].to_int())] = int(saved_shrines[key])
	grave_risen = d.get("grave_risen", false)
	recent_dead = d.get("recent_dead", [])
	# Derived from the map rather than saved, so a resumed run does not depend
	# on a route written by an older version of this code.
	_lay_the_beat()
	gem_found = d.get("gem_found", false)
	player_name = String(d.get("player_name", ""))
	uniques_found.clear()
	for k in d.get("uniques", []):
		uniques_found[StringName(k)] = true
	var rg: Array = d.get("risen_grave", [-1, -1])
	risen_grave = Vector2i(int(rg[0]), int(rg[1])) if rg.size() == 2 \
		else Vector2i(-1, -1)
	grave_at.clear()
	var saved_graves: Dictionary = d.get("graves", {})
	for key in saved_graves:
		var g: PackedStringArray = String(key).split(",")
		if g.size() == 2 and saved_graves[key] is Dictionary:
			grave_at[Vector2i(g[0].to_int(), g[1].to_int())] = saved_graves[key]

	shrine_hues.clear()
	for h in d.get("hues", []):
		shrine_hues.append(int(h))
	shrine_known.clear()
	for k in d.get("known", []):
		shrine_known[int(k)] = true
	forge_cap_bonus = int(d.get("forge_bonus", 0))
	torch_flare = int(d.get("flare", 0))

	cave_regions.clear()
	for r in d.get("caves", []):
		cave_regions.append(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))
	room_rects.clear()
	for r in d.get("rooms", []):
		room_rects.append(Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3])))

	entities = []
	for entry in d.get("entities", []):
		entities.append(Entity.from_dict(entry))
	var pi := int(d.get("player", 0))
	if pi < 0 or pi >= entities.size():
		return false
	player = entities[pi]
	# Derived, never stored: the torch is rebuilt from the saved torch_lit.
	player.light = LightSource.new(player.x, player.y, TORCH_RADIUS,
		Color(1.00, 0.72, 0.36), Color(0.30, 0.34, 0.55), 1.0, true)

	ground = []
	for entry in d.get("ground", []):
		var it := Item.from_dict(entry)
		if it != null:
			ground.append(it)

	msg_log = MessageLog.new()
	for entry in d.get("log", []):
		var c: Array = entry.get("c", [1, 1, 1])
		msg_log.entries.append({"text": entry.get("t", ""),
			"count": int(entry.get("n", 1)),
			"color": Color(float(c[0]), float(c[1]), float(c[2]))})

	_relabel_unreachable_items()
	events = []
	_travel.clear()
	pathfinder = Pathfinder.new(map)
	_gather_lights()
	update_vision()
	return true

# --------------------------------------------------------------- morgue ----

## One counter up. Kept deliberately blunt: every call site is a single line in
## a path that already exists, which is why the whole recording layer is a
## handful of lines rather than a subsystem.
func _tally(key: String, amount: int = 1) -> void:
	stats[key] = int(stats.get(key, 0)) + amount

## One counter up inside a named bucket -- kills by monster, swings by weapon.
func _tally_in(bucket: String, key: String, amount: int = 1) -> void:
	var d: Dictionary = stats.get(bucket, {})
	d[key] = int(d.get(key, 0)) + amount
	stats[bucket] = d

## Seconds underground, for the menu and the end screen.
func time_underground() -> int:
	return Clock.seconds(elapsed)

func morgue_line() -> String:
	var when := Time.get_datetime_string_from_system(false, true)
	var fate := ""
	if won:
		fate = "escaped the dungeon with the Amulet of the Deep"
	elif death_cause != "":
		fate = "%s on depth %d" % [death_cause, depth]
	else:
		fate = "left the dungeon on depth %d" % depth
	var carried := "with the Amulet" if _carrying_amulet() else "empty-handed"
	var line := "%s  level %d  %s, %s, after %d turns" \
		% [when, player.level, fate, carried, turns]
	# The run record, appended rather than replacing anything, so the line stays
	# something you can read and every line already written still parses. This
	# is what a gravestone has to say beyond "someone died here".
	var slain := 0
	var kills: Dictionary = stats.get("kills", {})
	var nemesis := ""
	var most := 0
	for k in kills:
		slain += int(kills[k])
		if int(kills[k]) > most:
			most = int(kills[k])
			nemesis = String(k)
	if slain > 0:
		line += "; %d slain" % slain
		if nemesis != "":
			line += ", most often %s" % nemesis
	# Appended, never inserted. PATTERN is not anchored to the start of the
	# line, so a leading group risks eating part of the timestamp -- and every
	# line already in a player's morgue has to keep parsing. Trailing optional
	# groups are how `slain`, `gear` and `reclaimed` were each added without
	# orphaning what came before, and this follows them.
	#
	# Where it is STORED is not where it is read: the epitaph puts the name
	# first, because "Brad, who reached level 7" is the sentence a gravestone
	# wants and "level 7 ... known as Brad" is not.

	# What they were wearing when it happened.
	#
	# Appended as one more optional clause, the same way the run record was:
	# every line already in a player's morgue still parses, and a death from
	# before this existed simply raises an unarmed skeleton. The older ghosts
	# being the poorer ones is a better outcome than a migration.
	#
	# Display names rather than ids, because a morgue is something you can
	# `cat` and "short bow +1" is the point. Item.from_display_name reads them
	# back off the catalogue.
	var worn: Array[String] = []
	for slot in [Item.Slot.WEAPON, Item.Slot.ARMOR, Item.Slot.OFFHAND]:
		var it: Variant = player.equipped.get(slot, null)
		if it != null:
			worn.append(it.display_name())
	if not worn.is_empty():
		line += "; bearing %s" % ", ".join(worn)
	var called := Morgue.clean_name(player_name)
	if called != "":
		line += "; known as %s" % called
	return line

## JSON has no integers -- every number comes back a double, including the ones
## inside the nested buckets -- so the whole structure is walked back to ints
## rather than leaving "3.0 kills" to surface on the end screen.
func _graves_to_dict() -> Dictionary:
	var out := {}
	for cell in grave_at:
		out["%d,%d" % [cell.x, cell.y]] = grave_at[cell]
	return out

func _stats_from(raw: Variant) -> Dictionary:
	var out := {}
	if not (raw is Dictionary):
		return out
	for key in raw:
		var v: Variant = raw[key]
		if v is Dictionary:
			var inner := {}
			for k in v:
				inner[String(k)] = int(v[k])
			out[String(key)] = inner
		else:
			out[String(key)] = int(v)
	return out

func _carrying_amulet() -> bool:
	for it in player.inventory:
		if it.kind == Item.Kind.AMULET:
			return true
	return false

## The black box. Called wherever the morgue line is written, so every way of
## dying leaves one -- a blow, a pit, a trap.
func write_death_dump() -> void:
	var f := FileAccess.open(DEATH_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(to_dict()))
	f.close()

func write_morgue() -> void:
	var f := FileAccess.open(MORGUE_PATH, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(MORGUE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.seek_end()
	f.store_line(morgue_line())
	f.close()

func _run_world() -> void:
	for _guard in 500:
		var actor := Scheduler.next_actor(entities)
		if actor == null or actor.is_player:
			return
		Scheduler.spend(actor, _take_ai_turn(actor))

## Returns what the turn cost -- difficult ground slows monsters exactly as it
## slows the player, which is the whole reason mud can be used as a shield.
func _take_ai_turn(actor: Entity) -> int:
	if not actor.alive or game_over:
		return Scheduler.ACTION_COST

	# A neutral takes no turn at all.
	#
	# Stated here rather than left to fall out of "it has no foe", because the
	# quiet paths would still run: patrolling would look for a route it has no
	# beat for, scavenging would eye the floor, and morale would count it among
	# the ranks. A trader who wandered off would also turn "there is a trader on
	# this floor" into a lie the legend tells.
	if actor.faction == Entity.Faction.NEUTRAL:
		return Scheduler.ACTION_COST

	# Regeneration ticks even while asleep, so a troll you wounded and fled
	# from is whole again when you come back. That is the point of it.
	#
	# Never for an ally, and stated here rather than left to the fact that a
	# skeleton's regen happens to be zero. "An ally cannot be healed" is the
	# rule that makes a companion who follows you across floors safe -- it is
	# what turns it from a permanent party member into something that only ever
	# wears down -- so it belongs in the code rather than in a coincidence
	# somebody could later tune away.
	if actor.faction != Entity.Faction.PLAYER and actor.regen > 0 \
			and actor.hp < actor.max_hp:
		actor.hp = mini(actor.max_hp, actor.hp + actor.regen)

	if actor.chilled > 0:
		actor.chilled -= 1

	# An ally never sleeps, never loses your trail and cannot be snuck up on,
	# so it skips the awareness system entirely rather than being handed a
	# special case inside it. That system is built on YOUR torchlight and YOUR
	# stealth -- `_notices_player` reads the light at the player's feet and
	# rolls against the rat ring -- and every line of it would be measuring the
	# wrong thing for something standing next to you on purpose.
	if actor.faction == Entity.Faction.PLAYER:
		var quarry := _foe_for(actor)
		_ai_ally(actor, quarry)
		return _last_move_cost

	_update_awareness(actor)
	_last_move_cost = Scheduler.ACTION_COST

	# GIVING WAY comes before everything, including hunting you. Something that
	# has just noticed a dragon has stopped caring about the adventurer, and
	# that is the whole point -- the player sees the room empty out and knows
	# to look at what caused it.
	#
	# No counter and no state: it backs off while the thing is in sight and
	# resumes when it is not, which is self-limiting and needs nothing
	# remembered.
	var dread := _something_dreadful(actor)
	if dread != null and _step_away(actor, dread):
		return _last_move_cost

	# Opportunistic, and checked BEFORE the activity below rather than being one
	# of them: a guard can walk its round and still stoop for a blade. Only
	# while unaware -- nothing stops mid-fight to try on armour.
	if actor.alertness != Entity.Alert.AWAKE and actor.scavenges \
			and _scavenge(actor):
		return _last_move_cost

	# TWO QUESTIONS, ASKED IN ORDER. Has it noticed you -- and if not, what was
	# it doing anyway?
	#
	# Hunting is not an activity in the list below; it is what being AWARE
	# means, and it overrides whatever the creature was busy with. A guard that
	# spots you stops walking its round, and its ACTIVITY is left untouched, so
	# when it loses your trail it simply goes back to it. Nothing has to
	# remember to restore anything.
	if actor.alertness != Entity.Alert.AWAKE:
		match actor.activity:
			Entity.Activity.PATROLLING:
				_ai_patrol(actor)
			Entity.Activity.FEEDING:
				# The player is passed as the thing to shy away from, not as a
				# target: `_ai_forager` flees anything within RABBIT_NOSE and
				# otherwise goes looking for mushrooms.
				var near := _foe_for(actor)
				if near != null:
					_ai_forager(actor, near)
			_:
				# Asleep, or merely stirring: it spends its turn not acting.
				# That pause is the player's window to withdraw, and it is the
				# whole point of the middle state.
				pass
		return _last_move_cost

	_update_morale(actor)

	# Decided ONCE per turn and handed down, rather than each behaviour asking
	# for `player` by name. Every AI below used to name the player directly,
	# which is why an ally would have been invisible: a goblin would walk past
	# the thing hitting it to reach you.
	var foe := _foe_for(actor)
	if foe == null:
		return _last_move_cost

	if actor.fleeing:
		_ai_flee(actor, foe)
		return _last_move_cost

	match actor.ai:
		&"erratic": _ai_erratic(actor, foe)
		&"forager": _ai_forager(actor, foe)
		&"banshee": _ai_banshee(actor, foe)
		&"ranged":  _ai_ranged(actor, foe)
		&"pack":    _ai_pack(actor, foe)
		_:          _ai_hunter(actor, foe)
	return _last_move_cost

## How many of the creatures that COULD walk a beat actually are.
##
## Not all of them, and the difference matters more than it sounds. Setting
## every biped patrolling measured at roughly half of everything in the dungeon
## awake and moving -- which retires the first rung of the awareness ladder,
## halves what the ring of the rat is for, and raises difficulty without the
## threat ceiling noticing.
##
## Rolled per creature rather than per floor, so you cannot learn "this level is
## a patrol level". Two goblins in the same room may differ, which is what
## makes the "z" and the "..." worth reading: the marker is now information
## rather than decoration.
## BY BAND, because where you are should say something about who is awake.
##
## A fortress is built and garrisoned and ought to feel watched; a cave is
## natural and dark and the humanoids in it are squatters rather than a watch.
## Keyed on the band rather than the depth so the climb inherits it for free --
## `Bands.of` folds around the bottom, so effective 15 is caves exactly as 5 is.
const PATROL_CHANCE := {
	Bands.UPPER: 0.35,
	Bands.CAVES: 0.15,
	Bands.FORTRESS: 0.65,
	Bands.DEEP: 0.50,
}

## Decides whether this particular guard is walking tonight.
func _set_the_watch(m: Entity) -> void:
	if not m.patrols:
		return
	var chance: float = PATROL_CHANCE.get(Bands.of(effective_depth()), 0.35)
	if rng.randf() < chance:
		m.activity = Entity.Activity.PATROLLING

## How far a scavenger will go out of its way for something lying on the floor.
##
## Short. It is meant to pick up what it nearly walked over, not to sweep the
## level -- a goblin that crosses two rooms for a dagger stops reading as a
## goblin and starts reading as a magnet.
const SCAVENGE_REACH := 6

## Picks up and puts on anything better than what it already has.
##
## The point of this is not the monster, it is the FLOOR: gear you leave behind
## arms the dungeon. Dropping a short sword because you found a better one
## stops being free, which turns a screen you look at twenty times a run into a
## decision.
##
## Answers whether it spent the turn.
func _scavenge(actor: Entity) -> bool:
	var here := _better_item_at(actor, Vector2i(actor.x, actor.y))
	if here != null:
		ground.erase(here)
		# Marked so killing the thief gives it back for certain. See
		# Item.scavenged -- the dungeon may take your things, not eat them.
		here.scavenged = true
		var shed: Item = actor.equipped.get(here.slot, null)
		actor.equipped[here.slot] = here
		actor.inventory.append(here)
		# Charged to its threat, for the same reason `_arm_monster` charges
		# what it hands out: a better-armed monster is worth more to face, and
		# the number has to keep meaning that or the XP it pays is a lie.
		actor.threat += here.power_bonus + here.defense_bonus
		if shed != null:
			actor.threat -= shed.power_bonus + shed.defense_bonus
			# What it took off goes back on the floor. It is still loot, and a
			# goblin upgrading should not delete a sword from the world.
			shed.x = actor.x
			shed.y = actor.y
			shed.letter = ""
			ground.append(shed)
		if map.is_visible(actor.x, actor.y):
			msg_log.add("The %s takes up the %s." % [actor.name, here.name],
				Color(0.85, 0.78, 0.55))
		return true

	# Nothing underfoot: go and get the nearest thing worth having.
	var want := Vector2i(-1, -1)
	var best := SCAVENGE_REACH + 1
	for it in ground:
		var d := Los.steps(actor.x, actor.y, it.x, it.y)
		if d > SCAVENGE_REACH or d >= best:
			continue
		if _better_item_at(actor, Vector2i(it.x, it.y)) == null:
			continue
		best = d
		want = Vector2i(it.x, it.y)
	if want.x < 0:
		return false
	_step_toward(actor, want)
	return true

## The best thing on that cell this creature would rather be wearing, or null.
func _better_item_at(actor: Entity, at: Vector2i) -> Item:
	var best: Item = null
	var best_gain := 0
	for it in items_at(at.x, at.y):
		if not it.is_equipment() or it.unique or it.transforms():
			continue
		# The same rule `_arm_monster` keeps: never hand reach to a brain that
		# will not use it. Only the ally learned to swap weapons.
		if it.range_bonus > 1 and actor.ai != &"ranged":
			continue
		# A shield is no use to something already holding a bow, and a
		# two-hander means dropping the shield -- neither is a judgement a
		# scavenger should be making.
		if it.is_two_handed() and actor.equipped.has(Item.Slot.OFFHAND):
			continue
		if it.slot == Item.Slot.OFFHAND:
			var held: Item = actor.equipped.get(Item.Slot.WEAPON, null)
			if held != null and held.is_two_handed():
				continue
		var mine: Item = actor.equipped.get(it.slot, null)
		# Typed, not inferred. `items_at` hands back an untyped Array, so `it`
		# is a Variant and `:=` has nothing to work from -- the same parse
		# error `player_ally_stance` hit reaching into `entities`.
		var gain: int = it.power_bonus + it.defense_bonus
		if mine != null:
			gain -= mine.power_bonus + mine.defense_bonus
		if gain > best_gain:
			best_gain = gain
			best = it
	return best

## The posts on this floor, in the order a guard walks them.
##
## Braziers, because they are the only thing on a floor that reads as somewhere
## a guard would BE -- a lit fire is a post, and the route between them is the
## shape of the built part of the level. Ordered by a greedy nearest-neighbour
## tour from the topmost post, which is deterministic (no rng, fixed scan
## order) and looks like a round rather than the zig-zag that sorting by
## coordinate would give.
##
## Spent braziers stay on the circuit. A guard's post does not move because the
## fire went out, and dropping them would make a route quietly reshape itself
## mid-run as fires burn down.
var patrol_route: Array = []

func _lay_the_beat() -> void:
	patrol_route = []
	var posts: Array[Vector2i] = []
	for y in map.height:
		for x in map.width:
			var t := map.get_tile(x, y)
			if t != Tiles.BRAZIER and t != Tiles.BRAZIER_SPENT:
				continue
			# BESIDE the fire, not in it. A brazier is `walk: false`, so a
			# route made of brazier cells is a route to places nothing can
			# stand -- `pathfinder.path` returns empty, `_step_toward` gives
			# up, and every guard in the dungeon stands at attention forever.
			# That is exactly what shipped, and it took Brad sitting in a
			# corner pressing "." two hundred times to find it.
			var beside := _beside(Vector2i(x, y))
			if beside.x >= 0:
				posts.append(beside)
	if posts.size() < 2:
		# One post is a vigil, not a round; none at all is a floor with nothing
		# worth guarding. Either way there is no route, and `_ai_patrol` leaves
		# the guard standing where it is -- still watching, still able to see
		# you, simply not walking.
		return
	var here: Vector2i = posts[0]
	patrol_route.append(here)
	posts.remove_at(0)
	while not posts.is_empty():
		var best := 0
		var best_d := Los.steps(here.x, here.y, posts[0].x, posts[0].y)
		for i in posts.size():
			var d := Los.steps(here.x, here.y, posts[i].x, posts[i].y)
			if d < best_d:
				best_d = d
				best = i
		here = posts[best]
		patrol_route.append(here)
		posts.remove_at(best)

## A guard throwing a log on. Answers true if it spent the turn doing so.
func _tend_the_fire(actor: Entity) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var c := Vector2i(actor.x + dx, actor.y + dy)
			if map.get_tile(c.x, c.y) != Tiles.BRAZIER:
				continue
			var left := int(brazier_charge.get(c, 0))
			if left <= 0 or left > BRAZIER_LOW:
				continue
			brazier_charge[c] = mini(BRAZIER_CHARGE, left + BRAZIER_STOKE)
			_last_move_cost = Scheduler.ACTION_COST
			if map.is_visible(c.x, c.y):
				msg_log.add("The %s feeds the fire." % actor.name,
					Color(0.95, 0.78, 0.45))
			return true
	return false

## A cell a creature can actually stand on, next to something it cannot.
##
## Fixed scan order and no rng, so a seed lays the same beat every time.
func _beside(at: Vector2i) -> Vector2i:
	# TYPED array, not a bare literal. An untyped `[...]` yields Variants, so
	# `at + d` has no inferable type and `:=` is a parse error -- which fails
	# the whole FILE, not the function. Third time this week.
	var around: Array[Vector2i] = [
		Vector2i(0, 1), Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, 0),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	for d in around:
		var c := at + d
		if map.is_walkable(c.x, c.y) and not Tiles.is_avoided(map.get_tile(c.x, c.y)):
			return c
	return Vector2i(-1, -1)

## Walking the round. It is NOT looking for you -- `_update_awareness` has
## already run and would have made it AWAKE if it had seen you -- so this is
## only ever "keep going".
func _ai_patrol(actor: Entity) -> void:
	# A guard's OTHER job. Stoking is its turn, which is what stops a fire
	# being restored for free -- and it only happens where a guard walks, so a
	# garrisoned fortress stays lit and a cave burns down to nothing.
	if _tend_the_fire(actor):
		return
	if patrol_route.is_empty():
		return
	var goal: Vector2i = patrol_route[actor.patrol_at % patrol_route.size()]
	# Arrived: take the next post. Done before moving, so a guard that starts
	# its life standing on a brazier still sets off.
	if Vector2i(actor.x, actor.y) == goal:
		actor.patrol_at = (actor.patrol_at + 1) % patrol_route.size()
		goal = patrol_route[actor.patrol_at]
	_step_toward(actor, goal)

## How far the dead see with no light at all.
##
## Six cells, which at five feet a square is D&D's thirty-foot darkvision --
## Brad's reference, and the reason the number is not rounder. The dungeon has
## several creatures that could justify it; the undead get it because they have
## no eyes to need light for, which is the "it's magic" answer and the honest
## one.
const DARKVISION := 6

## Whether one creature can make out another RIGHT NOW.
##
## A PREDICATE, deliberately, and not remembered awareness. Every creature
## holding what it knows about every other creature is N-squared state that has
## to be serialised and would be miserable to debug -- and nothing we want
## needs it. Predation, fear, ambush and tracking all only ever ask "can this
## thing see that thing at this moment".
##
## The ladder is Brad's: something that SENSES life needs neither eyes nor
## light; the dead see a short way in the dark; everything else needs the thing
## it is looking at to be LIT. That last part is the same rule the player lives
## under -- `_notices_player` reads the luminance at the player's feet -- so a
## monster standing in a dark corner is as hard for a goblin to see as you are.
func _can_see(watcher: Entity, other: Entity) -> bool:
	if watcher == other or not other.alive or not watcher.alive:
		return false
	var d := Los.steps(watcher.x, watcher.y, other.x, other.y)
	if d > watcher.notice_range:
		return false
	if watcher.senses:
		return true
	if not Los.clear(map, watcher.x, watcher.y, other.x, other.y):
		return false
	# Arm's length finds anything, however dark. The same absolute the player's
	# own detection keeps, and for the same reason: being unlit should never
	# mean being untouchable.
	if d <= 1:
		return true
	if watcher.unliving:
		return d <= DARKVISION
	return light_map.get_light(other.x, other.y).get_luminance() >= LIT_ENOUGH

## What this creature is trying to reach: the nearest thing it would fight.
##
## Today this is always the player, because the player is the only thing on
## the player's side -- so threading it through changes no behaviour at all
## until an ally exists. That is deliberate. The targeting layer lands as a
## refactor that the suite can prove inert, and the ally lands on top of a
## seam that already works.
##
## NO RNG, and no shuffle. Ties break on position in `entities`, which is
## stable across a save and a load, so two equidistant targets never make the
## same seed play out differently.
##
## Awareness is NOT consulted here, and that is the current rule rather than an
## oversight: a monster still has to notice YOU before it acts at all
## (`_update_awareness` runs first and is built on your torchlight and your
## stealth). So an ally cannot pull a sleeping monster out of the dark. It can
## only be fought by something already hunting. Whether an ally should be able
## to draw attention on its own is the open design question, and it belongs
## with the confusion beat rather than here.
func _foe_for(actor: Entity) -> Entity:
	var best: Entity = null
	var best_d := 0
	for e in entities:
		if not e.alive or not actor.hostile_to(e):
			continue
		# THE PLAYER STAYS A TARGET WHEN UNSEEN, because an awake monster hunts
		# by `last_seen` and that memory is the whole point of the field.
		# Everything else has to be visible right now.
		#
		# Without this the scan had no range and no sight check at all, so a
		# monster that woke to the player could lock onto an ally thirty cells
		# away through three walls. Nothing had noticed, because an ally is
		# usually standing next to you.
		if not e.is_player and not _can_see(actor, e):
			continue
		var d := Los.steps(actor.x, actor.y, e.x, e.y)
		if best == null or d < best_d:
			best = e
			best_d = d
	return best

func _update_awareness(actor: Entity) -> void:
	var d := Los.steps(actor.x, actor.y, player.x, player.y)

	if actor.alertness == Entity.Alert.AWAKE:
		# Keep track of the player, or eventually lose the trail. Without this
		# a woken monster would pursue across the whole level forever.
		if d <= actor.notice_range * 2 and Los.clear(map, actor.x, actor.y, player.x, player.y):
			actor.last_seen = Vector2i(player.x, player.y)
			actor.lost_turns = 0
		else:
			actor.lost_turns += 1
			if actor.lost_turns > actor.pursue_turns:
				actor.alertness = Entity.Alert.SUSPICIOUS
				actor.calm_turns = 0
				# Back to an ordinary memory. Whatever called it has stopped
				# mattering; the next thing it loses sight of is just a thing
				# it lost sight of.
				actor.pursue_turns = Entity.DEFAULT_PURSUIT
		return

	if actor.notice_block > 0:
		actor.notice_block -= 1
		return

	if _notices_player(actor, d):
		if actor.alertness == Entity.Alert.ASLEEP:
			actor.alertness = Entity.Alert.SUSPICIOUS
			actor.calm_turns = 0
		else:
			wake(actor)
		return

	if actor.alertness == Entity.Alert.SUSPICIOUS:
		actor.calm_turns += 1
		if actor.calm_turns > 6:
			# Back to unaware, and NOTHING else. Whatever it was doing before
			# it noticed you is still recorded in `activity`, so a guard
			# resumes its round on its own -- which is the whole reason the two
			# were split apart.
			actor.alertness = Entity.Alert.ASLEEP

## Light dominates the roll. Carrying a torch is both how you see and how you
## are seen, which is the trade the whole mechanic rests on.
func _notices_player(actor: Entity, d: int) -> bool:
	if d > actor.notice_range:
		return false
	# Something that senses life does not need to see it, and does not care
	# whether the torch is lit. Both of the player's ways of not being found
	# are line-of-sight and light, and this is deaf to both.
	if actor.senses:
		return true
	# The dead are not fooled. Absolute rather than a multiplier: a skeleton
	# sees a rat exactly as well as it sees a person, which makes a graveyard
	# the one place the ring is worth nothing and ties it back to the stones.
	if ratted() and not actor.unliving:
		# Anything adjacent still finds you -- see below -- so this only ever
		# softens the middle distance, which is where sneaking happens.
		var soften := RAT_NOTICE_ASCENT if ascending else RAT_NOTICE
		if rng.randf() >= soften:
			return false
	if not Los.clear(map, actor.x, actor.y, player.x, player.y):
		return false
	# Anything you are standing next to finds you, however dark it is.
	if d <= 1:
		return true

	var lum := light_map.get_light(player.x, player.y).get_luminance()
	var closeness := 1.0 - float(d) / float(actor.notice_range + 1)
	var chance := closeness * (0.10 + 1.6 * lum)
	if actor.alertness == Entity.Alert.SUSPICIOUS:
		chance *= 2.0
	return rng.randf() < clampf(chance, 0.0, 0.95)

func wake(actor: Entity) -> void:
	if actor.alertness == Entity.Alert.AWAKE or not actor.alive:
		return
	actor.alertness = Entity.Alert.AWAKE
	actor.last_seen = Vector2i(player.x, player.y)
	actor.lost_turns = 0
	events.append({"kind": &"notice", "to": Vector2i(actor.x, actor.y)})
	msg_log.add("The %s notices you!" % actor.name, Color(0.98, 0.78, 0.35))

## Nothing rallies yet, since only the player can heal -- but the threshold is
## checked each turn rather than latched, so a healing monster later works
## without touching this.
## How much bigger something has to be before a creature gives it room.
##
## A GAP, not a ratio, and the threat table is why. Threats run 2 to 32, so at
## 4x a goblin would fear a dragon but an ORC would need to meet something at
## 40 -- nothing in the game is that big, and the strong would never fear
## anything. Twelve works the whole way up: a kobold gives way to a troll but
## not an ogre, an orc to a wizard, an ogre to a giant, a bear to the arch lich
## alone, and a dragon to nothing at all.
##
## This is a WARNING SYSTEM as much as a behaviour. Kobolds scattering tells
## the player something is coming before they can see what, which is the
## dungeon speaking through behaviour rather than a message.
const APEX_GAP := 12

## The nearest thing in sight that this creature wants no part of, or null.
##
## Faction is deliberately not consulted: a goblin gives a dragon room whether
## or not they are nominally on the same side. `flee_below` is the gate, which
## is the same one morale uses and already encodes who can be frightened at all
## -- so the undead, the golems and the apex creatures are exempt for free.
func _something_dreadful(actor: Entity) -> Entity:
	if actor.flee_below <= 0.0 or actor.faction == Entity.Faction.PLAYER:
		return null
	var worst: Entity = null
	var near := 0
	for e in entities:
		if e == actor or not e.alive or e.is_player:
			continue
		if e.threat < actor.threat + APEX_GAP:
			continue
		if not _can_see(actor, e):
			continue
		var d := Los.steps(actor.x, actor.y, e.x, e.y)
		if worst == null or d < near:
			worst = e
			near = d
	return worst

## How far a creature looks for company, and for the news that its leader fell.
const MORALE_REACH := 5
## How much braver each nearby ally makes it.
const MORALE_PER_ALLY := 0.05
## How much LESS nerve it has after watching the biggest thing nearby go down.
##
## Large on purpose: a rout should be a rout. Against a flee_below of 0.15 this
## more than triples the point at which it breaks, so a group that was standing
## firm comes apart the moment the ogre drops -- which is the whole scene.
const MORALE_SHAKEN := 0.35
## And how long that lasts, if it survives long enough to steady.
const MORALE_SHAKEN_TURNS := 12

## News travels, but only to things with the wit to understand it.
##
## D&D rolls a morale check when a leader falls. Brad's version of the rule is
## the one this uses: the question is whether the creature is SMART ENOUGH to
## realise, and if it is, it runs. `scavenges` is that test -- the flag is
## already documented as "hands AND the wit to use what it finds", which is
## exactly the set that can reason about its own side. It correctly leaves out
## every animal, and the undead, who patrol but do not scavenge.
##
## The leader is the highest THREAT nearby, because that number exists to say
## what a thing is worth facing. Evaluating stats separately here would be
## admitting the number means nothing.
##
## Uses position rather than `_can_see`, because the thing it is looking at is
## already dead and `_can_see` refuses corpses.
func _rattle_the_ranks(fallen: Entity) -> void:
	for e in entities:
		if e == fallen or not e.alive or e.is_player:
			continue
		if e.faction != fallen.faction or not e.scavenges:
			continue
		# Something that never flees cannot be shaken either.
		if e.flee_below <= 0.0:
			continue
		if Los.steps(e.x, e.y, fallen.x, fallen.y) > e.notice_range:
			continue
		if not Los.clear(map, e.x, e.y, fallen.x, fallen.y):
			continue
		# Was that the biggest thing here, or just another body?
		var biggest := fallen.threat
		for o in entities:
			if o == fallen or o == e or not o.alive or o.is_player:
				continue
			if o.faction != e.faction:
				continue
			if Los.steps(e.x, e.y, o.x, o.y) > MORALE_REACH:
				continue
			biggest = maxi(biggest, o.threat)
		if biggest > fallen.threat:
			continue
		e.shaken = MORALE_SHAKEN_TURNS
		if map.is_visible(e.x, e.y):
			msg_log.add("The %s sees it fall." % e.name, Color(0.85, 0.82, 0.55))

func _update_morale(actor: Entity) -> void:
	if actor.flee_below <= 0.0:
		return
	# WHERE ITS NERVE BREAKS, not how hard it hits. Company steadies it; having
	# watched the biggest thing nearby die does the opposite. Moving the
	# threshold rather than the damage keeps the combat path untouched and
	# keeps every monster worth exactly the threat the floor paid for it.
	var breaks_at := actor.flee_below
	breaks_at -= MORALE_PER_ALLY * float(_allies_near(actor, MORALE_REACH))
	if actor.shaken > 0:
		actor.shaken -= 1
		breaks_at += MORALE_SHAKEN
	breaks_at = clampf(breaks_at, 0.0, 0.95)

	var frac := float(actor.hp) / float(actor.max_hp)
	if not actor.fleeing and frac <= breaks_at:
		actor.fleeing = true
		msg_log.add("The %s turns to flee!" % actor.name, Color(0.78, 0.82, 0.58))
	elif actor.fleeing and frac > breaks_at + 0.25:
		actor.fleeing = false

func _ai_hunter(actor: Entity, foe: Entity) -> void:
	if actor.is_adjacent(foe):
		_attack(actor, foe)
		return
	_step_toward(actor, Vector2i(foe.x, foe.y))

## Puts the right weapon in a creature's hands for the range it is fighting at.
##
## `_arm_monster` refuses to hand a launcher to a melee brain, because "a
## goblin handed a bow would carry reach its `pack` AI never uses, which reads
## as a bug rather than a surprise". GRAVE GEAR BYPASSES THAT GUARD ENTIRELY:
## nothing filters what the morgue says a character was buried in, so an ally
## raised from an archer's grave used to charge into melee swinging a war bow.
##
## Rather than filtering the bow out, this teaches the ally to do what the
## player does -- reach at distance, blade in hand when something closes. The
## player pays a turn for that swap, so the ally pays one too: changing weapons
## IS its action, which is what stops an archer from backing off and shooting
## in the same breath.
##
## Answers whether the swap happened, because that is the whole turn.
func _ready_weapon(actor: Entity, dist: int) -> bool:
	var held: Item = actor.equipped.get(Item.Slot.WEAPON, null)
	var want_reach := dist > 1
	var has_reach := held != null and held.range_bonus > 1
	if want_reach == has_reach:
		return false
	var swap: Item = null
	for it in actor.inventory:
		if it.slot != Item.Slot.WEAPON or it == held:
			continue
		if (it.range_bonus > 1) == want_reach:
			swap = it
			break
	# Nothing else to hold. It fights with what it has rather than standing
	# there empty-handed -- an archer with no blade still swings the bow, which
	# is what a real person cornered with a bow does.
	if swap == null:
		return false
	actor.equipped[Item.Slot.WEAPON] = swap
	if map.is_visible(actor.x, actor.y):
		msg_log.add("%s takes up the %s." % [actor.name, swap.name],
			Color(0.70, 0.85, 0.78))
	return true

## Fights what is near you, and otherwise keeps up.
##
## Deliberately simple, and deliberately NOT commandable. The design rule Brad
## set is that the player controls the TIMING -- when the bone is spent -- and
## nothing after that. An ally you steer is a second character to play, which
## doubles the keys and halves the tension; an ally that just fights is a
## decision you made one turn ago and now have to live with.
##
## The leash is what stops it being annoying. Without it the ally walks off
## after whatever is nearest on the floor, and the player spends the fight
## wondering where their help went.
func _ai_ally(actor: Entity, quarry: Entity) -> void:
	# Something to fight, and near enough to YOU to be worth fighting. Measured
	# from the player rather than from the ally, so it never strays further
	# than its reach however far it has already wandered.
	#
	# The stance is only this number. At heel it will not cross the room for
	# something; loose, it works the whole leash. That one distance is the
	# entire difference between a bodyguard and a hunting dog, and writing it
	# as two behaviours instead would have been two things to keep in step.
	var range_out := ALLY_HEEL_REACH if actor.stance == Entity.Stance.HEEL \
		else ALLY_LEASH
	if quarry != null and Los.steps(player.x, player.y, quarry.x, quarry.y) <= range_out:
		var dist := Los.steps(actor.x, actor.y, quarry.x, quarry.y)
		# Arming itself costs the turn, exactly as the player's swap key does.
		if _ready_weapon(actor, dist):
			return
		if actor.is_adjacent(quarry):
			_attack(actor, quarry)
			return
		# Shoots if it is holding something that shoots and can see to do it.
		# It still closes the distance rather than keeping station: an ally
		# that kites would walk itself off the leash, and the leash is what
		# keeps your help where you can see it.
		if dist <= actor.total_range() \
				and Los.clear(map, actor.x, actor.y, quarry.x, quarry.y):
			_attack(actor, quarry, true)
			return
		_step_toward(actor, Vector2i(quarry.x, quarry.y))
		return
	# Nothing worth doing: come back. Stops at arm's length rather than trying
	# to stand on you -- a companion that crowds the doorway you are backing
	# through is a companion that gets you killed.
	if Los.steps(actor.x, actor.y, player.x, player.y) > 1:
		_step_toward(actor, Vector2i(player.x, player.y))

## Bites when it happens to be beside you, but will not hold a line -- so you
## cannot reliably disengage from one, and cannot reliably corner it either.
func _ai_erratic(actor: Entity, foe: Entity) -> void:
	if actor.is_adjacent(foe) and rng.randf() < 0.7:
		_attack(actor, foe)
		return
	if rng.randf() < 0.6:
		_step_random(actor)
		return
	_step_toward(actor, Vector2i(foe.x, foe.y))

## The behaviour that makes pillars matter: it needs a clear line, so stepping
## behind cover genuinely stops it, and it backs off rather than letting you
## close to melee for free.
func _ai_ranged(actor: Entity, foe: Entity) -> void:
	var dist := Los.steps(actor.x, actor.y, foe.x, foe.y)

	if actor.blink_cool > 0:
		actor.blink_cool -= 1

	# Too close for comfort. A slinger's comfort is one cell; a caster's is
	# three, and the difference is the whole character of the fight.
	if dist <= actor.standoff:
		if actor.blink_range > 0 and actor.blink_cool <= 0 and _blink_away(actor, foe):
			return
		if _step_away(actor, foe):
			return
		# Cornered, with nowhere left to give. Now it has to fight, and a
		# caster in melee is exactly as frail as its hit points suggest.
		if dist <= 1:
			_attack(actor, foe)
			return

	if dist <= actor.total_range() and Los.clear(map, actor.x, actor.y, foe.x, foe.y):
		_attack(actor, foe, true)
		return

	_step_toward(actor, Vector2i(foe.x, foe.y))

## How long after a blink before it can blink again.
##
## The cooldown is the whole reason the arch lich is a fight rather than a
## chore. Without it the player can never close, so the lich chips away from
## range forever and the only counterplay is to walk off the floor. Eight turns
## buys a window to reach it and land blows -- and costs you the ground you
## spent getting there when it goes again.
const BLINK_COOLDOWN := 8

## Somewhere else on the floor, out of arm's reach and preferably out of sight.
func _blink_away(actor: Entity, foe: Entity) -> bool:
	var spots := []
	var r := actor.blink_range
	for y in range(maxi(1, actor.y - r), mini(map.height - 1, actor.y + r + 1)):
		for x in range(maxi(1, actor.x - r), mini(map.width - 1, actor.x + r + 1)):
			if not map.is_walkable(x, y) or Tiles.is_avoided(map.get_tile(x, y)):
				continue
			if entity_at(x, y) != null:
				continue
			# No point reappearing inside its quarry's reach.
			if Los.steps(x, y, foe.x, foe.y) <= actor.standoff:
				continue
			spots.append(Vector2i(x, y))
	if spots.is_empty():
		return false
	var to: Vector2i = spots[rng.randi_range(0, spots.size() - 1)]
	var from := Vector2i(actor.x, actor.y)
	actor.x = to.x
	actor.y = to.y
	actor.blink_cool = BLINK_COOLDOWN
	events.append({"kind": &"blink", "from": from, "to": to})
	# Only remarked on when it happened where you could see it -- otherwise the
	# message is a free report that something you cannot see just moved.
	if map.is_visible(from.x, from.y) or map.is_visible(to.x, to.y):
		msg_log.add("The %s folds out of the air and is elsewhere." % actor.name,
			Color(0.75, 0.70, 0.95))
	_last_move_cost = Scheduler.ACTION_COST
	return true

## Bold with company, hesitant alone -- so a lone goblin hangs back and a pair
## of them commit, which makes thinning a group worth doing.
func _ai_pack(actor: Entity, foe: Entity) -> void:
	if actor.is_adjacent(foe):
		_attack(actor, foe)
		return
	if _allies_near(actor, 5) > 0 or rng.randf() < 0.45:
		_step_toward(actor, Vector2i(foe.x, foe.y))

func _allies_near(actor: Entity, radius: int) -> int:
	var n := 0
	for e in entities:
		# Its OWN side. Reading this as "everything that is not the player"
		# meant your ally counted as company for the goblins standing near it:
		# summoning help would have made the pack braver, which is precisely
		# backwards and would have been very hard to see in play.
		if e == actor or not e.alive or e.faction != actor.faction:
			continue
		if Los.steps(actor.x, actor.y, e.x, e.y) <= radius:
			n += 1
	return n

func _ai_flee(actor: Entity, foe: Entity) -> void:
	if _step_away(actor, foe):
		return
	# Cornered. A trapped animal fights.
	if actor.is_adjacent(foe):
		_attack(actor, foe)

## What a shut door costs, as a multiple of an ordinary stride.
##
## Charged as ENERGY rather than tracked as a state machine, exactly as mud is
## -- "it took three turns" and "it cost three turns of energy" are the same
## thing to the scheduler, and the second needs nothing remembered. A bear does
## not open a door, it goes through it, and that is worth real time.
const DOOR_SHOULDER_COST := 3

## Getting through a shut door. Answers true if the door TOOK THE TURN, in
## which case the creature has not moved.
##
## A bear can knock a door down but can never shut one -- there is nothing in
## `player_close_door` or here that lets it -- which is why the open door you
## find behind you tells you something came through.
func _through_the_door(actor: Entity, at: Vector2i) -> bool:
	if map.get_tile(at.x, at.y) != Tiles.DOOR_CLOSED:
		return false
	var style := actor.door_style()
	if style == Entity.Door.SQUEEZES:
		# Under it, and no slower for it. Brad has watched rabbits do this.
		return false
	_last_move_cost = Scheduler.ACTION_COST
	if style != Entity.Door.SHOULDERS:
		map.set_tile(at.x, at.y, Tiles.DOOR_OPEN)
		if map.is_visible(at.x, at.y):
			msg_log.add("The %s pulls the door open." % actor.name,
				Color(0.78, 0.74, 0.66))
		return true

	_last_move_cost *= DOOR_SHOULDER_COST
	# A bear does not open a door, it DESTROYS one -- Brad has watched it
	# happen. Which does more than sound right: with the door merely opened,
	# shutting it on a bear again would buy another three turns, and again, for
	# as long as you cared to. Gone, the trick works exactly once and leaves a
	# permanent hole in your escape route. An open door might be one you forgot
	# about; a missing door is not ambiguous.
	#
	# EVERYWHERE, authored vaults included. The first version exempted
	# `protected_cell` the way the golem's rubble does, on the grounds that a
	# hand-drawn room's shape belongs to whoever drew it. Brad's call was
	# consistency, and he is right: "sometimes a bear cannot break a door and
	# you cannot tell which" is a worse rule than either one applied
	# everywhere. A vault losing a door only ever makes it more open, so
	# nothing an author drew becomes unreachable.
	map.set_tile(at.x, at.y,
		Tiles.CAVE_FLOOR if map.material_at(at.x, at.y) == Materials.CAVERN
		else Tiles.FLOOR)
	pathfinder.set_solid(at.x, at.y, false)
	if map.is_visible(at.x, at.y):
		msg_log.add("The %s takes the door off its hinges." % actor.name,
			Color(0.92, 0.66, 0.45))
	else:
		msg_log.add("Wood splinters, somewhere out of sight.",
			Color(0.78, 0.70, 0.60))
	return true

func _step_toward(actor: Entity, target: Vector2i) -> void:
	var route := pathfinder.path(Vector2i(actor.x, actor.y), target)
	if route.is_empty():
		return
	var step: Vector2i = route[0]
	var blocker := entity_at(step.x, step.y)
	if blocker != null:
		# YOUR OWN SIDE IS NOT A WALL.
		#
		# The pathfinder routes over ground and knows nothing about creatures,
		# so the shortest line from an ally to its target runs straight through
		# whoever is in the way -- and that is USUALLY THE PLAYER, because
		# standing between your bodyguard and the thing it is fighting is the
		# ordinary geometry of having a bodyguard. Found by a test: an ally at
		# heel sat still for four turns while an orc hit the player from the
		# far side, because its one step was onto the player's cell and it gave
		# up rather than going round.
		#
		# Deliberately narrowed to the same faction. A monster blocked by
		# another monster keeps today's behaviour of simply waiting, which
		# reads fine in a corridor and -- more to the point -- is a difficulty
		# question nobody has measured. Teaching every creature in the game to
		# flow around its neighbours is a real change to how packs reach you,
		# and it does not belong in a bug fix for allies.
		if blocker.faction != actor.faction:
			return
		step = _around(actor, target)
		if step.x < 0:
			return
	if _through_the_door(actor, step):
		return
	_last_move_cost = move_cost_for(actor, step.x, step.y)
	actor.x = step.x
	actor.y = step.y

## A way past a friend: the free neighbour that gets closest to `target`.
##
## Must get STRICTLY closer, or two allies either side of the player would
## shuffle back and forth forever trading the same two cells. No rng and a
## fixed scan order, so a seed replays identically.
func _around(actor: Entity, target: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := Los.steps(actor.x, actor.y, target.x, target.y)
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var nx: int = actor.x + dx
			var ny: int = actor.y + dy
			if not can_step(actor.x, actor.y, nx, ny):
				continue
			if entity_at(nx, ny) != null:
				continue
			var d := Los.steps(nx, ny, target.x, target.y)
			if d < best_d:
				best_d = d
				best = Vector2i(nx, ny)
	return best

## Mouthfuls before a rabbit stops being one.
##
## Two, and the history here is worth keeping because the first number was
## measured honestly and still did nothing.
##
## It was five, then three: a floor grows 5.3 fungus on average (measured), so
## five meant eating essentially every mushroom on the level. Three was meant
## to make the transformation "a thing that happens" -- and it never happened
## once in play, because the tuning was not the binding constraint. Everything
## started ASLEEP and no creature acted until it noticed the player, so a rabbit
## did not eat at all until you arrived, and by then it is busy fleeing you.
## Foragers now forage whether or not anyone is watching (see `_take_ai_turn`),
## which is what makes ANY number here mean something. Two, because the rabbit
## is now competing with the player for the same mushrooms and the race should
## be losable.
const RABBIT_TURNS := 2
## The shallowest floor a rabbit can turn into something else on.
##
## Brad's rule, after dying to one at level 1 with a dagger. The learning floors
## get rabbits and nothing worse; from here down, no hand-holding.
##
## The reason it needs saying at all is that `RABBIT_TURNS` was tuned for a
## transformation that COULD NEVER FIRE -- everything was asleep until the
## player arrived, so no rabbit ever ate twice. The moment that was fixed, a
## depth-5 threat with power 9 started appearing on floor one against a
## character holding a dagger, and nobody had ever balanced it, because until
## this week it did not exist.
##
## Depth is the right lever rather than the threshold: making it rarer
## everywhere would take the surprise out of the caves, where it belongs.
const RABBIT_TURNS_DEPTH := 3

## Turns spent with its head down, unable to react. The window.
const RABBIT_MEAL := 2
## How far it will look for a mushroom.
const RABBIT_NOSE := 14

## Eats the floor out from under you, and runs when looked at.
##
## The order matters: fleeing beats feeding. A rabbit that finished its mouthful
## while you closed would be catchable by walking, which is precisely what the
## speed is there to prevent.
func _ai_forager(actor: Entity, foe: Entity) -> void:
	if actor.busy > 0:
		actor.busy -= 1
		if actor.busy == 0:
			_rabbit_swallows(actor)
		return

	var d := Los.steps(actor.x, actor.y, foe.x, foe.y)
	if d <= RABBIT_NOSE and Los.clear(map, actor.x, actor.y, foe.x, foe.y):
		if _step_away(actor, foe):
			return

	# Head down, if it is standing on supper.
	if map.get_tile(actor.x, actor.y) == Tiles.FUNGUS:
		actor.busy = RABBIT_MEAL
		if map.is_visible(actor.x, actor.y):
			msg_log.add("The rabbit sets to work on the fungus.",
				Color(0.85, 0.78, 0.55))
		return

	var supper := _nearest_fungus(actor)
	if supper.x >= 0:
		_step_toward(actor, supper)
	else:
		_step_random(actor)

func _nearest_fungus(actor: Entity) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := RABBIT_NOSE + 1
	for y in map.height:
		for x in map.width:
			if map.get_tile(x, y) != Tiles.FUNGUS:
				continue
			# Not one somebody is standing on. This picked the nearest mushroom
			# and nothing else, so a rat asleep on the closest one left the
			# rabbit pacing in front of it forever -- watched in play, with two
			# perfectly good mushrooms in the same room. It was not refusing
			# the others; it never looked at them.
			if entity_at(x, y) != null:
				continue
			var d := Los.steps(actor.x, actor.y, x, y)
			if d < best_d:
				best_d = d
				best = Vector2i(x, y)
	return best

## The mouthful lands: the fungus goes out, and the rabbit is one closer to
## being a problem.
func _rabbit_swallows(actor: Entity) -> void:
	if map.get_tile(actor.x, actor.y) != Tiles.FUNGUS:
		return
	map.set_tile(actor.x, actor.y,
		Tiles.CAVE_FLOOR if map.material_at(actor.x, actor.y) == Materials.CAVERN
		else Tiles.FLOOR)
	# The same call the player's own mouthful makes. A fungus is a light as
	# much as it is a hit point, and this is the half that actually stings.
	_gather_lights()
	actor.meal += 1
	if map.is_visible(actor.x, actor.y):
		msg_log.add("The rabbit swallows it, and the glow goes out.",
			Color(0.80, 0.72, 0.50))
	if actor.meal >= RABBIT_TURNS and actor.ai == &"forager" \
			and effective_depth() >= RABBIT_TURNS_DEPTH:
		_rabbit_turns(actor)

## What it becomes. Still frail -- it simply stops running.
func _rabbit_turns(actor: Entity) -> void:
	actor.name = "killer rabbit"
	actor.appearance = &"killer_rabbit"
	actor.ai = &"hunter"
	# And it stops FORAGING, which since the activity split is a separate fact
	# from its `ai`. Setting `ai` alone left `activity` on FEEDING, so the turn
	# loop kept sending it after mushrooms: Brad ate a haunch worth 14 hp,
	# which is eight mouthfuls, from something that should have stopped at two.
	#
	# The test that was meant to catch this asserted `ai == &"hunter"` -- the
	# old MECHANISM rather than the behaviour -- so it went on passing while
	# the thing it described stopped being true.
	actor.activity = Entity.Activity.SLEEPING
	actor.power = 9
	actor.threat = 12
	actor.flee_below = 0.0
	# Said differently when it happens out of sight, the way the banshee's wail
	# already is. `_blink_away` states the rule: a message about something you
	# cannot see is a free report you did not earn.
	#
	# This announced itself unconditionally for the life of the project and it
	# never mattered, because nothing acted until the player was near enough to
	# see it -- so a rabbit could not transform off-screen. Teaching foragers to
	# forage unwatched is what turned a dormant inconsistency into a message
	# arriving from an empty room. Found in play, within an hour.
	if map.is_visible(actor.x, actor.y):
		msg_log.add("The rabbit straightens up. Something has gone very wrong with it.",
			Color(0.95, 0.72, 0.72))
		events.append({"kind": &"notice", "to": Vector2i(actor.x, actor.y)})
	else:
		msg_log.add("Something screams, somewhere in the dark. It does not stop.",
			Color(0.95, 0.72, 0.72))

## Half a brazier, and a little more for every mushroom it got to first.
##
## This was argued the other way first -- worth only what it swallowed, so the
## rabbit could never be a net gain -- on the reasoning that 5 + 1 each makes
## letting it eat the optimal play. Play said otherwise and the objection was
## overweighted: you still have to FIND it again, it is faster than you, the
## chase is five to twenty turns of noise, and at RABBIT_TURNS mouthfuls it
## stops running and starts hitting back. Those are the costs the refund
## argument ignored, and the whole quantity in dispute is a floor's 5.3 fungus.
##
## So: a real reward for winning a real hunt.
const MEAT_BASE := 5

## What a bear is worth, against a brazier's ten charges.
##
## Deliberately the same order as a whole fire, because farming bears SHOULD
## feel like carrying a brazier in your pack. It stays honest through scarcity
## rather than through the number: bears are a cave-band creature, absent from
## the fortress entirely, and two cannot share a cave -- a bear costs 17 threat
## and the largest cave ceiling the game can build is 30.
const MEAT_BEAR := 10
## Meat gains a point every three floors, so a haunch stays worth hunting for.
## Flat, it was a fifth of your hit points on floor four and a twentieth by the
## climb -- the same reason the healing economy deflates, arriving by the same
## route. See the attrition survey.
const MEAT_PER_DEPTH := 3.0

func _drop_meat(victim: Entity) -> void:
	var bear := victim.appearance == &"bear"
	var meat := Item.make(&"bear_meat" if bear else &"meat")
	if meat == null:
		return
	# A bear is a lot of meat, and it is worth MORE than a brazier's whole
	# charge -- which is the point of it. By the time you can kill bears
	# reliably you are carrying a fire around in your pack, and the thing that
	# keeps that honest is how rare they are: one or two a floor in the cave
	# band, and none at all in the fortress.
	#
	# No `meal` term. A rabbit's haunch is worth more for every mushroom it got
	# to first; a bear has not been eating the scenery.
	meat.magnitude = (MEAT_BEAR if bear else MEAT_BASE + victim.meal) \
		+ int(floor(float(effective_depth()) / MEAT_PER_DEPTH))
	var at := Vector2i(victim.x, victim.y)
	if not _can_rest_on(at.x, at.y):
		at = _nearest_restable(at)
		if at.x < 0:
			return
	meat.x = at.x
	meat.y = at.y
	meat.letter = ""
	ground.append(meat)

## How long between cries.
##
## Not every turn. A cry per step wakes a rolling wavefront along the player's
## whole route and turns the log into wallpaper; on this cadence it is a
## discrete event you can hear, place, and race -- kill it before the next one.
const WAIL_EVERY := 3

## Follows, and screams. Never strikes.
##
## The absence of an attack is the design, not an oversight: everything it costs
## you is measured in what else on the floor is now awake, which makes "how many
## turns can I spare to shut it up" the entire decision.
func _ai_banshee(actor: Entity, foe: Entity) -> void:
	if actor.wail_cool > 0:
		actor.wail_cool -= 1
	elif actor.wail_radius > 0:
		actor.wail_cool = WAIL_EVERY
		if map.is_visible(actor.x, actor.y):
			msg_log.add("The banshee wails.", Color(0.85, 0.88, 0.98))
		else:
			msg_log.add("Something wails, somewhere in the dark.",
				Color(0.72, 0.75, 0.88))
		_make_noise(Vector2i(actor.x, actor.y), actor.wail_radius, &"wail")
		return

	# It never closes to strike, so there is no adjacency case -- it simply
	# keeps station on you, through whatever is in the way.
	#
	# Reads the flag rather than assuming it. The first version called the
	# phasing mover unconditionally, which meant `phasing` was decorative: the
	# test asserting a banshee phases could fail while the banshee still walked
	# through walls, because the behaviour was welded to the AI kind. A flag
	# nothing consults is a lie in the save file.
	if actor.phasing:
		_step_phasing(actor, Vector2i(foe.x, foe.y))
	else:
		_step_toward(actor, Vector2i(foe.x, foe.y))

## A step toward the target that ignores walls entirely.
##
## The pathfinder cannot serve here: it routes over walkable ground by
## definition, and the whole point is that stone is not an obstacle. It may
## finish its move inside a wall, and that is deliberate -- landing only on open
## floor would mean it could never cross a wall one cell thick, which is most of
## them. Sitting in the stone also keeps it killable: `player_move` tests for an
## entity before it tests the ground, so walking into the wall it occupies is an
## attack.
func _step_phasing(actor: Entity, target: Vector2i) -> void:
	var dx := signi(target.x - actor.x)
	var dy := signi(target.y - actor.y)
	if dx == 0 and dy == 0:
		return
	# Straight at it, then either axis alone, so a diagonal blocked by another
	# creature still makes progress.
	for step: Vector2i in [Vector2i(dx, dy), Vector2i(dx, 0), Vector2i(0, dy)]:
		if step == Vector2i.ZERO:
			continue
		var nx: int = actor.x + step.x
		var ny: int = actor.y + step.y
		# The rim of the map is the one thing it will not pass -- outside it
		# there is nothing to draw and nowhere to come back from.
		if nx <= 0 or ny <= 0 or nx >= map.width - 1 or ny >= map.height - 1:
			continue
		if entity_at(nx, ny) != null:
			continue
		actor.x = nx
		actor.y = ny
		_last_move_cost = Scheduler.ACTION_COST
		return

func _step_random(actor: Entity) -> void:
	var opts: Array[Vector2i] = []
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var nx: int = actor.x + dx
			var ny: int = actor.y + dy
			if can_step(actor.x, actor.y, nx, ny) and entity_at(nx, ny) == null:
				opts.append(Vector2i(nx, ny))
	if opts.is_empty():
		return
	var pick: Vector2i = opts[rng.randi_range(0, opts.size() - 1)]
	if _through_the_door(actor, pick):
		return
	_last_move_cost = move_cost_for(actor, pick.x, pick.y)
	actor.x = pick.x
	actor.y = pick.y

## Returns false when there is nowhere further from the player to go.
func _step_away(actor: Entity, foe: Entity) -> bool:
	var here := Los.steps(actor.x, actor.y, foe.x, foe.y)
	var best := Vector2i(actor.x, actor.y)
	var best_d := here
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var nx: int = actor.x + dx
			var ny: int = actor.y + dy
			if not can_step(actor.x, actor.y, nx, ny) or entity_at(nx, ny) != null:
				continue
			var d := Los.steps(nx, ny, foe.x, foe.y)
			if d > best_d:
				best_d = d
				best = Vector2i(nx, ny)
	if best_d <= here:
		return false
	if _through_the_door(actor, best):
		return true
	_last_move_cost = move_cost_for(actor, best.x, best.y)
	actor.x = best.x
	actor.y = best.y
	return true

## Shoves a creature directly away from `from`, up to `distance` cells, and
## answers how far it actually went.
##
## Stops at the first cell it cannot occupy, which is what makes the mechanic
## tactical rather than random: a bear in the open costs you two cells of
## ground, and a bear with your back to a wall costs you nothing. Where you
## stand when it connects is the whole decision.
##
## It will not shove anything into a pit or a trap. The codebase already holds
## this line -- `_open_cell_in` refuses to land a falling player in a second
## pit, "a chain the player never chose to start" -- and being knocked to
## another floor by a melee hit is a bigger version of exactly that. Water,
## mud and rubble are fair game: they cost energy, not agency.
func _shove(target: Entity, from: Vector2i, distance: int) -> int:
	var dir := Vector2i(signi(target.x - from.x), signi(target.y - from.y))
	if dir == Vector2i.ZERO:
		return 0
	return _step_along(target, dir, distance)

## Walks a creature `distance` cells in a straight line, stopping at the first
## cell it cannot occupy, and answers how far it got.
##
## Shared by the shove and the charge on purpose: a giant that followed by
## different rules than the blow that made room for it could end up somewhere
## its victim could not have been pushed through -- inside a wall, across a
## pit, or on top of somebody. One mover, one set of rules, and the two can
## never disagree.
func _step_along(who: Entity, dir: Vector2i, distance: int) -> int:
	var dx := dir.x
	var dy := dir.y
	var target := who
	var moved := 0
	for _i in distance:
		var nx := target.x + dx
		var ny := target.y + dy
		if not map.is_walkable(nx, ny):
			break
		if Tiles.is_avoided(map.get_tile(nx, ny)):
			break
		if entity_at(nx, ny) != null:
			break
		target.x = nx
		target.y = ny
		moved += 1
	return moved

## The element bound into whatever this blow was struck with.
##
## Melee only, deliberately. A launcher's gem would fire from across the room
## with none of the risk that makes the ember forge decision hard, and the
## peek-and-duck loop is already the strongest thing an archer has. Reach is
## paid for in damage everywhere else in this game; it should be paid for here
## too.
## How this attacker hurts things. Empty for bare hands, which nothing resists
## and nothing is weak to -- a fist is a fist.
func _damage_type_of(attacker: Entity) -> StringName:
	var held: Variant = attacker.equipped.get(Item.Slot.WEAPON, null)
	if held == null:
		return &""
	return held.damage_type

func _gem_of(attacker: Entity, ranged: bool) -> StringName:
	if ranged:
		return &""
	var held: Variant = attacker.equipped.get(Item.Slot.WEAPON, null)
	if held == null:
		return &""
	return held.element

## What an element does once the blow has landed. Fire is handled at the
## damage line instead, because it changes the number itself.
func _gem_strikes(gem: StringName, attacker: Entity, defender: Entity,
		dmg: int, ranged: bool = false) -> void:
	match gem:
		&"frost":
			if defender.alive:
				defender.chilled = GEM_FROST_TURNS
				if attacker.is_player:
					msg_log.add("Frost creeps over the %s. It slows."
						% defender.name, Color(0.62, 0.82, 0.95))
		&"leech":
			# Rounded UP so a glancing blow still returns something. A gem that
			# gives nothing on a bad hit teaches the player it is unreliable
			# rather than modest.
			var drawn := maxi(1, int(ceil(float(dmg) * GEM_LEECH_SHARE)))
			drawn = mini(drawn, attacker.max_hp - attacker.hp)
			if drawn > 0:
				attacker.hp += drawn
				if attacker.is_player:
					msg_log.add("The gem drinks, and you feel it. (+%d)" % drawn,
						Color(0.80, 0.55, 0.75))
		&"crag":
			_raise_spires(defender, _crag_spires_for(attacker, ranged))

## Stone spires erupt around whatever was hit.
##
## Never on the attacker's own cell and never where anything is standing, so it
## can hem a thing in but can never bury the player who swung. Plain ground
## only -- a spire through water or an authored vault floor would be writing
## over something that already means something.
## How much stone this attacker's weapon tears up.
##
## Melee is unchanged at GEM_CRAG_SPIRES. A missile weapon scales from one at
## the sling's reach, capped at three -- past the war bow there is nothing left
## to earn.
func _crag_spires_for(attacker: Entity, ranged: bool) -> int:
	if not ranged:
		return GEM_CRAG_SPIRES
	var held: Item = attacker.equipped.get(Item.Slot.WEAPON, null)
	if held == null:
		return 1
	var reach := held.range_bonus
	return clampi(1 + int(floor(float(reach - CRAG_SLING_REACH) / 2.0)), 1, 3)

func _raise_spires(target: Entity, count: int) -> void:
	var made := 0
	var spots: Array[Vector2i] = []
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			spots.append(Vector2i(target.x + dx, target.y + dy))
	for i in range(spots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t := spots[i]
		spots[i] = spots[j]
		spots[j] = t
	for c in spots:
		if made >= count:
			break
		if not map.in_bounds(c.x, c.y) or entity_at(c.x, c.y) != null:
			continue
		if c == Vector2i(player.x, player.y) or c == stairs:
			continue
		var t := map.get_tile(c.x, c.y)
		if t != Tiles.FLOOR and t != Tiles.CAVE_FLOOR:
			continue
		if protected_cell(c):
			continue
		spires[c] = [turns + GEM_CRAG_TURNS, t]
		map.set_tile(c.x, c.y, Tiles.STALAGMITE)
		made += 1
	if made > 0:
		if pathfinder != null:
			pathfinder = Pathfinder.new(map)
		msg_log.add("Stone tears up out of the floor around it.",
			Color(0.78, 0.74, 0.66))

## Spires subside on their own.
##
## Restores the tile that was actually there rather than assuming FLOOR: cave
## ground exists and a spire raised on it must not leave a room floor behind.
##
## Skips any cell something is standing on and tries again next turn, so a
## creature hemmed in by stone is never buried inside it when the stone goes.
func _let_the_stone_settle() -> void:
	if spires.is_empty():
		return
	var done: Array[Vector2i] = []
	for cell in spires:
		var row: Array = spires[cell]
		if turns < int(row[0]):
			continue
		if map.get_tile(cell.x, cell.y) != Tiles.STALAGMITE:
			# Something else changed it. Not ours to restore any more.
			done.append(cell)
			continue
		if entity_at(cell.x, cell.y) != null:
			continue
		map.set_tile(cell.x, cell.y, int(row[1]))
		done.append(cell)
	for cell in done:
		spires.erase(cell)
	if not done.is_empty() and pathfinder != null:
		pathfinder = Pathfinder.new(map)

## Is this cell inside a hand-drawn room? Authored terrain is what the author
## drew and nothing gets to rewrite it.
func protected_cell(c: Vector2i) -> bool:
	for vr in vault_rects:
		if vr.has_point(c):
			return true
	return false

## Everything that follows from a death, wherever the blow came from.
##
## EXTRACTED so the shield's reflect can kill. A blow turned back on its owner
## has to drop loot, wake the neighbours, be remembered for the shovel and pay
## experience exactly as a swing does -- and writing a second copy of that here
## is the same mistake as a test that rebuilds a monster by hand. The copy
## looks right, drifts the first time any of it changes, and nothing says so.
func _settle_death(victim: Entity, killer: Entity) -> void:
	if victim.is_player:
		game_over = true
		death_cause = "killed by a %s" % killer.name
		events.append({"kind": &"death", "to": Vector2i(player.x, player.y)})
		write_morgue()
		write_death_dump()
		msg_log.add("You die. Press R to begin again.", Color(1.0, 0.35, 0.35))
	else:
		msg_log.add("The %s dies." % victim.name, Color(0.65, 0.70, 0.85))
		events.append({"kind": &"kill",
			"to": Vector2i(victim.x, victim.y)})
		# Remembered BEFORE the loot drop empties it, so what stands up
		# again is wearing what it fought you in. Serialised with the run,
		# because a suspend in the five turns after a big kill must not
		# quietly cost you the dig.
		_remember_the_dead(victim)
		_rattle_the_ranks(victim)
		_drop_loot(victim)
		if victim.risen:
			_settle_the_grave()
		# Your side's kills, not just your own. An ally that stole your
		# experience would be a reward you are punished for spending --
		# the same mistake as taxing the threat ceiling when one arrives.
		# Its kills are credited to the run because the run paid a grave
		# for them, permanently, and there is no getting that back.
		if killer.faction == Entity.Faction.PLAYER:
			award_xp(victim.threat)
			_tally_in("kills", victim.name)


func _attack(attacker: Entity, defender: Entity, ranged: bool = false,
		power_override: int = -1) -> void:
	var atk := attacker.total_power() if power_override < 0 else power_override

	# Swinging a bow is not fighting. Without this an archer has no reason to
	# fear being adjacent, and the whole peek-and-duck loop has no stakes: you
	# could stand toe to toe with a launcher in hand and lose almost nothing.
	var clumsy := power_override < 0 and not ranged and attacker.total_range() > 1
	if clumsy:
		atk = maxi(1, int(attacker.power / 2))

	# THE SHIELD AS A WEAPON. Twice the tier: buckler +2, kite +4, tower +6.
	#
	# Melee only, and only on a real swing -- a shield bash at bowshot is not a
	# thing, and `power_override` is how thrown rocks and gem effects borrow
	# this function, none of which are you shoving a shield into somebody.
	#
	# Added to `atk` rather than to the final damage, so it flows through the
	# same subtraction and the same floor as any other power. That means it
	# also lifts the floor, which is correct: hitting harder should reach past
	# heavy armour, and that IS what the floor is for.
	#
	# AFTER the clumsy penalty, not before, or swinging a bow would halve the
	# bash too. A launcher claims the offhand so the two cannot co-occur today,
	# but the ordering should not depend on that staying true.
	if not ranged and power_override < 0:
		atk += attacker.offhand_tier(&"bash") * 2

	var raw := atk - defender.total_defense() + rng.randi_range(-1, 1)
	# What it was struck WITH, before the floor is applied -- so a resisted
	# blow still lands for the guaranteed minimum rather than nothing, and a
	# weakness multiplies the real number rather than the floor.
	var kind := _damage_type_of(attacker)
	if kind != &"":
		if defender.resists.has(kind):
			raw = int(round(float(raw) * RESISTED))
		elif defender.weak_to.has(kind):
			raw = int(round(float(raw) * VULNERABLE))
	var least := int(ceil(float(atk) * DAMAGE_FLOOR_FRACTION))
	var dmg := maxi(maxi(1, least), raw)
	# What the bound gem adds, before the blow lands, so fire is part of the
	# number the player is shown rather than a second mysterious deduction.
	var gem := _gem_of(attacker, ranged)
	if gem == &"fire":
		dmg += maxi(1, int(round(float(dmg) * GEM_FIRE_SHARE)))
	# The shield hand, and the ONE thing in this game that reaches past the
	# damage floor.
	#
	# Applied last, after the floor and after fire, because it turns aside the
	# blow that actually lands rather than a number on the way to it. Every
	# message below prints the reduced `dmg`, so the player is never shown a
	# figure the shield already ate.
	#
	# Still floored at 1: nothing in this game does nothing, and a tower shield
	# that made a rat harmless would make the early floors a walk.
	var turned := defender.block_amount()
	if turned > 0:
		var before := dmg
		dmg = maxi(1, dmg - turned)
		turned = before - dmg
	defender.take_damage(dmg)
	if gem != &"":
		_gem_strikes(gem, attacker, defender, dmg, ranged)

	if attacker.is_player:
		_tally("dealt", dmg)
		if ranged:
			_tally("shots")
		else:
			var held: Variant = player.equipped.get(Item.Slot.WEAPON, null)
			_tally_in("swings", held.name if held != null else "bare hands")
	elif defender.is_player:
		_tally("taken", dmg)

	events.append({
		"kind": &"ranged" if ranged else &"melee",
		"from": Vector2i(attacker.x, attacker.y),
		"to": Vector2i(defender.x, defender.y),
		"amount": dmg,
		"on_player": defender.is_player,
	})
	if defender.is_player:
		# Never keep auto-walking into something that is hurting you.
		_travel.clear()
	else:
		wake(defender)

	# Fighting is loud, and it is loud at BOTH ends.
	#
	# This used to wake things within four cells of the defender and nothing
	# else, which left one hole big enough to win the game through: a bowshot
	# was silent where the bow was. An archer's corner was permanently quiet,
	# so shoot-and-retreat cost turns and nothing else -- and eight of fifteen
	# monsters are slower than the player and can never close, so those turns
	# were free. A first-time tester found the loop in one sitting.
	#
	# Routing it through _make_noise rather than waking things directly also
	# means combat obeys the same rule bones do: it carries through stone, and
	# it reaches exactly as far as the radius says.
	_make_noise(Vector2i(defender.x, defender.y), COMBAT_NOISE, &"combat")
	if ranged:
		# A loosed arrow is heard where it was loosed. Twenty-six shots at a
		# stone golem is twenty-six calls for company.
		_make_noise(Vector2i(attacker.x, attacker.y), COMBAT_NOISE, &"combat")

	if attacker.is_player:
		if ranged:
			msg_log.add("You shoot the %s for %d." % [defender.name, dmg],
				Color(0.85, 0.88, 0.68))
		elif clumsy:
			msg_log.add("You club at the %s for %d -- a poor weapon up close."
				% [defender.name, dmg], Color(0.85, 0.75, 0.55))
		else:
			msg_log.add("You hit the %s for %d." % [defender.name, dmg],
				Color(0.80, 0.85, 0.70))
	elif ranged:
		msg_log.add("The %s shoots you for %d." % [attacker.name, dmg], Color(0.95, 0.62, 0.35))
	else:
		msg_log.add("The %s hits you for %d." % [attacker.name, dmg], Color(0.90, 0.45, 0.40))

	# Said out loud, because the whole effect is a number that did NOT happen.
	# Without this the stone reads as no change at all -- the same reason fire
	# is added before the blow lands rather than deducted after it.
	if turned > 0:
		if defender.is_player:
			msg_log.add("Your shield turns %d of it." % turned,
				Color(0.62, 0.78, 0.95))
		elif attacker.is_player:
			msg_log.add("The %s's shield turns %d." % [defender.name, turned],
				Color(0.72, 0.74, 0.80))

	# Shoved only by a connecting melee blow, and only if it survived it. A
	# corpse has nowhere to be pushed to, and a thrown rock that moved you two
	# cells would make every archer a bear.
	if defender.alive and not ranged and attacker.knockback > 0:
		var was := Vector2i(defender.x, defender.y)
		var pushed := _shove(defender, Vector2i(attacker.x, attacker.y),
			attacker.knockback)
		if pushed > 0:
			# The charge: it follows into the ground it just cleared, so the
			# shove buys no distance at all. Capped at how far the target
			# actually went, so a blow stopped by a wall does not teleport the
			# attacker through the target's back.
			if attacker.charges:
				var dir := Vector2i(signi(defender.x - was.x),
					signi(defender.y - was.y))
				if _step_along(attacker, dir, pushed) > 0 and defender.is_player:
					# Said out loud, or the giant simply appears not to have
					# been left behind and the shove reads as having failed.
					msg_log.add("The %s comes with you." % attacker.name,
						Color(0.95, 0.50, 0.35))
			events.append({
				"kind": &"shove", "from": was,
				"to": Vector2i(defender.x, defender.y),
				"on_player": defender.is_player,
			})
			if defender.is_player:
				# The view moved without the player spending a turn on it.
				update_vision()
				msg_log.add("The %s hurls you back." % attacker.name,
					Color(0.90, 0.55, 0.40))
			else:
				msg_log.add("The %s is hurled back." % defender.name,
					Color(0.80, 0.80, 0.70))
		elif defender.is_player:
			# Honest: you were shoved, and something behind you stopped it.
			# Costs no extra damage -- the mechanic is about ground, not hurt.
			msg_log.add("The %s slams you against what is behind you."
				% attacker.name, Color(0.90, 0.55, 0.40))

	if not defender.alive:
		_settle_death(defender, attacker)

	# THE BLOW GIVEN BACK. Tier damage to whoever swung, melee only.
	#
	# Requires the defender to still be STANDING: a shield held by someone who
	# just died turning nothing, and it keeps two deaths from resolving inside
	# one blow, which is the kind of ordering that produces a corpse that still
	# drops loot twice.
	#
	# Dealt straight rather than through _attack, deliberately. Routing it back
	# through here would fire the attacker's own gems, their knockback, their
	# noise, and -- if both sides wore mirrors -- reflect forever.
	if not ranged and defender.alive and attacker.alive:
		var thrown_back := defender.offhand_tier(&"reflect")
		if thrown_back > 0:
			attacker.take_damage(thrown_back)
			if defender.is_player:
				msg_log.add("Your shield throws it back for %d." % thrown_back,
					Color(0.70, 0.86, 0.96))
			elif attacker.is_player:
				msg_log.add("The %s's shield throws it back for %d."
					% [defender.name, thrown_back], Color(0.95, 0.62, 0.35))
			if attacker.is_player:
				_tally("taken", thrown_back)
			# Through the same door a swing uses, so a kill by reflect still
			# drops loot, wakes the floor and pays experience.
			if not attacker.alive:
				_settle_death(attacker, defender)
