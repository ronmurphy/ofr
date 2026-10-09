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

## Where F9 puts its PNGs. EMPTY means the player's desktop -- Brad: user:// is
## a hidden folder nobody would find (see MainScene.screenshot_folder). Tests
## and tools set it (use_scratch_files), so a suite never writes to a desktop.
static var SCREENSHOT_DIR := ""

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
	# And the controller bindings. The suite closes the controller screen, and
	# closing it saves -- see PadConfig.PATH for what that did to the real file.
	PadConfig.PATH = "user://scratch_%s_gamepad.cfg" % tag
	# And the legends, which every ending appends to. Redirected from the
	# file's first commit, as CLAUDE.md asks of every player-owned file.
	LegendsLog.PATH = "user://scratch_%s_legends.json" % tag
	# Screenshot tests and tools must never write into the player's folder.
	SCREENSHOT_DIR = "user://scratch_%s_screenshots" % tag

## True in a test or a tool: anything that called use_scratch_files. The title
## screen is skipped then -- the harnesses load the real scene and expect to be
## playing.
static func using_scratch() -> bool:
	return SUSPEND_PATH.contains("scratch_")

## Removes whatever use_scratch_files created.
static func clear_scratch_files() -> void:
	BestiaryLog.clear_scratch()
	for path in [SUSPEND_PATH, MORGUE_PATH, DEATH_PATH, SETTINGS_PATH, PadConfig.PATH,
			LegendsLog.PATH]:
		if path.contains("scratch_") and FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	# The screenshots folder too, and what is in it -- a folder, so the loop
	# above never saw it, and every run that took a picture left one behind.
	if SCREENSHOT_DIR.contains("scratch_") and DirAccess.dir_exists_absolute(SCREENSHOT_DIR):
		for f in DirAccess.get_files_at(SCREENSHOT_DIR):
			DirAccess.remove_absolute(SCREENSHOT_DIR.path_join(f))
		DirAccess.remove_absolute(SCREENSHOT_DIR)
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
	var base := TORCH_RADIUS
	if Bands.is_caves(effective_depth()):
		base = CORRUPT_TORCH if Bands.is_corrupted(effective_depth()) else CAVE_TORCH
	# The lantern in your armour: a cell further (and seen from one further,
	# see _notice_reach).
	return base + (LANTERN_CELLS if _armour_element() == &"lantern" else 0)

## ARMOUR GEMS (Brad, 2026-10-01): the road, the veil and the lantern. What
## the body armour carries, or &"" bare.
const VEIL_LIGHT := 0.6
const LANTERN_CELLS := 1
## Turns a hunter the veil shook off cannot notice you again: without this it
## looked once more in the same turn and had you back in torchlight.
const VEIL_BLIND := 5

func _armour_element() -> StringName:
	if player == null:
		return &""
	var worn: Variant = player.equipped.get(Item.Slot.ARMOR, null)
	return worn.element if worn != null else &""

## The light on you as the things that notice you read it: the veil in your
## armour makes it count VEIL_LIGHT of itself.
func _light_on_you() -> float:
	var lum := light_map.get_light(player.x, player.y).get_luminance()
	return lum * VEIL_LIGHT if _armour_element() == &"veil" else lum

## How far this creature can notice you from: its own range, and a cell more
## while the lantern lights you.
func _notice_reach(actor: Entity) -> int:
	return actor.notice_range + (LANTERN_CELLS if _armour_element() == &"lantern" else 0)

## Everything awake and hunting you that could lose the thread: not what
## stands beside you, which finds you however dark it is.
func _hunters() -> Array:
	var out := []
	for e in entities:
		if e.is_player or not e.alive or not e.hostile_to(player) \
				or e.alertness != Entity.Alert.AWAKE or e.is_adjacent(player):
			continue
		out.append(e)
	return out

## THE GEM OF THE VEIL, crushed: the light slides off you and every hunter
## loses the thread at once -- back to suspicious, with no last sight of you.
func _vanish(gem: Item) -> bool:
	var lost := _hunters()
	if lost.is_empty():
		msg_log.add("Nothing is hunting you.", Color(0.7, 0.6, 0.4))
		return false
	for e in lost:
		e.alertness = Entity.Alert.SUSPICIOUS
		e.calm_turns = 0
		e.last_seen = Vector2i(-1, -1)
		e.lost_turns = 0
		e.pursue_turns = Entity.DEFAULT_PURSUIT
		e.notice_block = VEIL_BLIND
	events.append({"kind": &"notice", "to": Vector2i(player.x, player.y)})
	msg_log.add("You crush the %s. The light slides off you: %d thing%s hunting you lose%s the thread."
		% [gem.name, lost.size(), "" if lost.size() == 1 else "s", "s" if lost.size() == 1 else ""],
		Color(0.75, 0.70, 0.95))
	return true

## THE GEM OF THE LANTERN, crushed: the torch flares, as the scroll of light
## makes it -- far sight, and seen as far.
func _flare_with(gem: Item) -> bool:
	if torch_flare > 0:
		msg_log.add("Your torch is flaring already.", Color(0.7, 0.6, 0.4))
		return false
	torch_flare = FLARE_TURNS
	torch_lit = true
	_gather_lights()
	msg_log.add("You crush the %s into the torch. It roars white -- you can see far, and be seen as far."
		% gem.name, Color(1.00, 0.90, 0.55))
	return true

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

## THE FLARE REKINDLES. Brad's design, 2026-09-25, and a race.
##
## Held to a brazier, a flared torch gives its fire to it: the brazier is FILLED
## to a level set by how much flare is left, and the flare is spent doing it.
## The fresher the flare, the bigger the fire -- 15, which is more than any
## brazier is ever built with -- so finding the shrine starts a clock, and the
## flare's own curse (everything sees you coming) runs the whole way.
##
## FILLED TO, never added to. A dead brazier gains the most, which is Brad's
## intent -- this is the ONLY thing in the game that brings back a brazier gone
## black (a scroll of light reaches only a guttered one) -- a weak fire gains
## less, and one already burning at or above the tier is refused so a flare is
## never thrown away on nothing. The best use is usually a fire the player
## killed EARLIER on the floor, raked down or forged out, so the race is a run
## back across known ground. Under 25 turns the flare is light and curse only.
##
## Each row: at least this many flare turns left -> fill the brazier to this.
const FLARE_KINDLE := [[75, 15], [50, 10], [25, 5]]
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
## The cave vaults this run has met, name -> Array of [quarters, mirror]
## (2026-10-08): MapGen offers one twice at most, the second time turned
## differently. Saved.
var cave_vaults_seen: Dictionary = {}

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
## GEMS FEED THE UNIQUES (6c, Brad 2026-09-30). At the embers, any gem can go
## into the ring of the rat or a dull shovel instead of a piece of gear: the
## ring takes RING_FEED turns back, up to the RING_FULL it was found with; the
## shovel gets its edge back for one more raise. Gems are the price: a stone
## in the ring is one your blade never gets.
const RING_FEED := 50
const RING_FULL := 220

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

## The threat ceilings live in `threat.gd` now -- arithmetic that reaches for no
## state at all, which is what made it the one seam worth taking. TIER_FADE and
## TIER_GRACE below stayed: they belong to monster ROLLING, not to the ceiling.


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
## The slingers' reload dice. Its own stream, because how many times it is
## rolled depends on how the fights go -- CLAUDE.md: anything whose number of
## draws varies with content gets its own rng, or it shifts everything after.
var reload_rng := RandomNumberGenerator.new()
## One line per floor the first time a slinger is seen reloading.
var _reload_said := false
## "backs out of the purple", said once a floor: the ally teaches the
## scenario, so the player need not learn it by losing one.
var _retreat_said := false
## "makes for the water", once a floor, for the same reason.
var _wade_said := false

## And one for the trader's room, for the same reason again: it is drawn after
## the floor is already populated, so taking it from the main stream would make
## the number of draws depend on whether this depth has a trader at all.
var trader_rng := RandomNumberGenerator.new()

## GEMS IN THE RUBBLE. Brad's, 2026-09-25: one rubble pile on each floor hides a
## gem, and knapping that pile finds it.
##
## One per floor, not a chance per pile, and the reasoning was measured rather
## than guessed. Rubble runs from none to over a hundred piles a floor (averages
## 20-40 by band -- and the caves carry LESS than the upper floors, not more),
## so any flat per-pile chance would pay rubble-heavy floors several times over.
## One hidden pile makes the odds simply the SHARE of the floor you worked:
## knap a quarter of it, a one-in-four chance; knap all of it, certain. That is
## both of Brad's framings at once -- "1 out of the floor's rubble" and "clear
## every pile and the last one pays".
##
## Rolled, never chosen: choosing belongs to the trader's three-for-one, and a
## chooser for something found in a pile of stones felt wrong to Brad. At most
## one a floor, so it cannot be farmed, and only a sling can knap -- which gives
## the weakest weapon in the game a reason to stay in the pack.
##
## Its own rng, seeded from the run and the floor, so hiding it draws nothing
## from the main stream and every floor generates exactly as it did before.
var geode := Vector2i(-1, -1)
var geode_rng := RandomNumberGenerator.new()
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
## Chooses this floor's gem pile. Scans in a fixed order and draws once from
## its own stream, so the same run always hides it under the same pile.
func _hide_the_geode() -> void:
	geode = Vector2i(-1, -1)
	# Effective depth, so a climb floor does not hide its gem wherever the
	# descent floor it mirrors did.
	geode_rng.seed = int(rng.seed) ^ (effective_depth() * 3266489917) ^ 0x6E0D
	# Not where no gem can exist yet. Floor one has none to give, and a pile
	# hidden there was found by the suite quietly eating itself: the knap
	# consumed it and the roll came back empty.
	if Item.gems_at(effective_depth()).is_empty():
		return
	var piles: Array[Vector2i] = []
	for y in map.height:
		for x in map.width:
			if map.get_tile(x, y) == Tiles.RUBBLE:
				piles.append(Vector2i(x, y))
	if piles.is_empty():
		return
	geode = piles[geode_rng.randi_range(0, piles.size() - 1)]

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
## THE BARRED DOORS (gem of the bulwark, 6d): cell -> how many heaves the bar
## has left. A door is barred for as long as nothing wants through it badly
## enough: each creature that tries and cannot open it spends its turn and
## takes one off this, loudly, so a pack breaks in faster than a straggler.
## Saved, like the embers.
var barred: Dictionary = {}
## The barred cells that were latched GATES (2026-10-09): the bar comes off a
## gate as an open gate, not a plain door. Saved.
var barred_gates: Dictionary = {}
const BAR_HOLDS := 10
## PITS AS ESCAPE (Dwarf Fortress plan, strand 5). A fleeing creature chased
## -- fleeing in your light and your sight CHASED_TURNS turns running -- leaps
## into a pit beside it rather than die in a corner. The fall costs it half
## of what it has left and never kills it (it was near death to be fleeing;
## a fall that finished it would make the escape a lie), and it lands on the
## next floor awake, hunting, and vengeful: a point of power and half again
## the experience. Carried down on this list, saved with the run, like the
## allies that follow you.
var fallen: Array = []
const CHASED_TURNS := 3
## Above the doused torch's glow (0.18 beside you, 0.13 two cells out) and
## inside a lit one's reach (0.27 six cells out): measured, 2026-10-01.
const CHASE_LIGHT := 0.25
const REVENGE_POWER := 1
const REVENGE_XP := 1.5
## Whether something landed on this floor from above -- the trader has heard.
var something_fell := false

## THE FROZEN ROOMS (gem of frost, 6d; Brad's design): [region, until-turn]
## for each room, vault or cave a gem has shattered in. Sound made inside
## carries nowhere until the turn comes. What stood in it when it broke is
## frozen on the creature itself (Entity.frozen), for as many turns.
var frozen_rooms: Array = []
const FREEZE_MIN := 3
const FREEZE_MAX := 12
## The brazier the gem of returning marked this floor, or (-1, -1).
var recall_mark := Vector2i(-1, -1)
## The gem of the road: the route to the stairs is on the map this floor.
var road_shown := false
var _road_cache: Dictionary = {}
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
## The wild thing the player was just warned about bumping (player_move):
## the same move again attacks it. Not saved; a warning repeating after a
## reload is no harm.
var _meant: Entity = null
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
	## THE SLIME (Brad, 2026-10-04; built 2026-10-05). The classic floors-1-2
	## monster, and not the Minecraft one: a SCAVENGER OF EVERYTHING. It goes
	## for anything lying on the floor before anything else, even you, swallows
	## it and carries it (so a slime left alone is a walking chest that drops
	## the lot when it dies -- it moves loot, never makes any); meat and
	## fungus it eats, and those are gone. Its hit leaves ACID that goes on
	## eating for ACID_LINGER turns unless washed off in water -- so drop
	## something to lure it, and fight it standing in a pool. Slow (70), one
	## hit for anyone by depth 6, and kept on the deeper floors at a low
	## weight with no fade as a CARRIER of the red (SPORE_CARRIERS): the
	## threat deep down is to the floor's food and the floor's dead, never to
	## your hp. The climb corrupts it like any cheap thing (_roll_corruptible).
	{"name": "slime", "app": &"slime", "hp": 5, "power": 2, "def": 0,
	 "speed": 70, "ai": &"slime", "flee": 0.0, "min_depth": 1, "threat": 2,
	 "no_fade": true, "weight": 0.35, "caves": 0.8, "acid": true},
	## THE WOLF (Brad's wild creatures update; built 2026-10-05). The first
	## thing that comes as a PACK: the fauna roll that lands one lands its
	## `pack` beside it (_spawn_pack). WILD like the bear -- it hunts the
	## rabbits and keeps its distance from you -- until one is struck: then
	## every wolf within PACK_REACH turns together, and the pack AI it shares
	## with the goblins does the rest (bold with company, which for a wild
	## thing means its own kind: _allies_near). One pack a floor.
	## WHERE IT LIVES (Brad, 2026-10-05): the upper floors and the caves, on
	## both halves -- floors 1-6 and 14 on -- and never a fortress, where a
	## wild pack reads wrong; a trained one with its master is the way in
	## there (BACKLOG). `bands` is that rule (see _roll_the_wild); `pack` is
	## read by band too: a pair on the upper floors, four in the caves.
	{"name": "wolf", "app": &"wolf", "hp": 9, "power": 4, "def": 1,
	 "speed": 130, "ai": &"pack", "flee": 0.15, "min_depth": 1, "threat": 6,
	 "no_fade": true, "bands": {&"upper": 0.5, &"caves": 0.75},
	 "caves": 2.0, "wild": true, "eats": true,
	 "pack": {&"upper": 2, &"caves": 4}, "max_per_floor": 1,
	 ## TAMEABLE (Brad's design 2026-10-05; built 2026-10-06): a knucklebone,
	 ## or haunches to the pack's count, held out at the bump warning turns
	 ## the pack to your side. See _tame.
	 "tame": true},
	{"name": "kobold", "app": &"kobold", "hp": 6, "power": 3, "def": 0,
	 "speed": 100, "ai": &"hunter", "flee": 0.25, "gear": 0.35, "min_depth": 1, "threat": 3, "caves": 1.5, "patrol": true, "scavenge": true, "eats": true},
	{"name": "kobold slinger", "app": &"slinger", "hp": 5, "power": 3, "def": 0,
	 "speed": 100, "ai": &"ranged", "range": 6, "flee": 0.45, "gear": 0.25, "min_depth": 2, "reload": true,
	 "threat": 6, "caves": 0.5, "patrol": true, "scavenge": true, "eats": true},
	{"name": "cave bat", "app": &"bat", "hp": 5, "power": 3, "def": 0,
	 "speed": 170, "ai": &"erratic", "flee": 0.0, "flying": true, "min_depth": 2, "threat": 5, "caves": 2.6,
	 "wild": true},
	{"name": "goblin", "app": &"goblin", "hp": 9, "power": 4, "def": 1,
	 "speed": 100, "ai": &"pack", "flee": 0.20, "gear": 0.50, "min_depth": 2, "threat": 5, "caves": 2.0, "patrol": true, "scavenge": true, "eats": true},
	{"name": "skeleton", "app": &"skeleton", "hp": 12, "power": 5, "def": 2,
	 "speed": 90, "ai": &"hunter", "flee": 0.0, "gear": 0.40, "min_depth": 3, "threat": 8, "caves": 0.4, "unliving": true, "resists": ["slash", "pierce"], "weak_to": ["blunt"],
	 ## It was set to guard something and never stopped.
	 "patrol": true},
	{"name": "orc", "app": &"orc", "hp": 16, "power": 6, "def": 2,
	 "speed": 100, "ai": &"hunter", "flee": 0.15, "gear": 0.70, "min_depth": 4, "threat": 10, "caves": 1.3, "patrol": true, "scavenge": true, "eats": true},

	# --- deep tiers -------------------------------------------------------
	# Power from 7 upward, because below that a levelled character in chain
	# mail simply stops taking damage and the dungeon gets easier as it goes
	# deeper. These also carry the whole ascent, which runs at effective
	# depths of 10 to 19.
	{"name": "ogre", "app": &"ogre", "hp": 26, "power": 9, "def": 3,
	 "speed": 90, "ai": &"hunter", "flee": 0.12, "gear": 0.50, "heavy": true, "min_depth": 5, "threat": 14, "caves": 1.6, "patrol": true, "scavenge": true, "eats": true},
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
	# WILD since 2026-10-04: it minds its own business until struck, and then
	# all of the above is true. Hunting it for its meat is a choice now. And
	# it EATS: awake, it hunts the rabbits (the food web, bear > rabbit).
	# Floors 1-6 and 14 on, like the wolf (Brad, 2026-10-05): it was kept off
	# floors 1-3 while it attacked on sight; wild, a floor-1 player walks
	# round it. The chances: a bear on about a third of the upper floors,
	# not furniture, and on most cave floors, where it is at home.
	{"name": "cave bear", "app": &"bear", "hp": 34, "power": 9, "def": 3,
	 "speed": 100, "ai": &"hunter", "flee": 0.15, "heavy": true, "min_depth": 1,
	 "threat": 17, "knockback": 2, "caves": 2.6, "wild": true, "eats": true,
	 "no_fade": true, "bands": {&"upper": 0.3, &"caves": 0.85},
	 # One a floor, set down by _place_the_wild; the cap is a guard only.
	 "max_per_floor": 1},
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
	 "threat": 28, "caves": 2.0, "careful": true, "casts": true},

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
	 "speed": 130, "ai": &"forager", "flee": 0.0, "no_fade": true, "wild": true,
	 # Read the COUNT here, not the share. A rabbit is 20% of a cave floor's
	 # population and 11% of a fortress one, which sounds like a warren and is
	 # not: cave floors hold about fourteen monsters, so three rabbits is a
	 # fifth of them by arithmetic alone, and three is the cap we chose.
	 #
	 # This was briefly cut to 0.16 on the strength of those percentages, which
	 # took early floors down to a third of a rabbit each -- and the descent is
	 # precisely where meat has to teach itself before the climb needs it.
	 "max_per_floor": 2, "weight": 0.35, "min_depth": 1, "threat": 3,
	 # Never rolled in a fortress, going down or coming up; the warren vault
	 # is the only way in (Brad, 2026-10-07; see _roll_monster).
	 "not_in": [&"fortress"],
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
	 "min_depth": 8, "threat": 22, "caves": 0.4, "patrol": true, "scavenge": true, "careful": true, "casts": true},
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
	 "flee": 0.0, "min_depth": 10, "ascent_from": 16, "threat": 32, "caves": 0.6, "unliving": true, "resists": ["pierce"], "weak_to": ["blunt"], "careful": true, "casts": true},
	# THE SPIDER (the wild creatures update; night 1 of 3, 2026-10-09). WILD,
	# like the bat and the bear: nobody's enemy until struck, on top of the
	# budget, placed by _place_the_wild from `bands`. Upper floors, the caves
	# AND the fortress -- the one wild exception there (Brad: spiders were
	# all over buildings and fortresses). Its bite poisons (`venom`, the
	# miasma's `poisoned`, three turns); it flees up the walls (`climbs`); it
	# hunts bats. Threat 7: above the wolf's 6, so a pack does not take it as
	# game; the bear still does. LAST in the table, so adding it moves none
	# of the earlier rows' wild draws. Its web shot (night 2) and its nest
	# (night 3) are still to come.
	{"name": "spider", "app": &"spider", "hp": 8, "power": 3, "def": 1,
	 "speed": 120, "ai": &"hunter", "flee": 0.5, "min_depth": 1, "threat": 7,
	 "bands": {&"upper": 0.35, &"caves": 0.6, &"fortress": 0.35},
	 "max_per_floor": 1, "wild": true, "eats": true, "venom": 3, "climbs": true},
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

## The name the player chose at the start of a run, or blank for "you pick".
##
## Blank KEEPS the name new_game already rolled. It used to roll a second one
## from the run's rng here -- AFTER the floor was built -- so leaving the field
## blank drew one more number than typing a name did, and the same seed played
## differently depending on whether you named yourself. new_game's roll comes
## before build_level and is part of every run's sequence; this draws nothing.
func choose_name(chosen: String) -> void:
	var clean := Morgue.clean_name(chosen)
	if clean != "":
		player_name = clean

func new_game() -> void:
	depth = 1
	turns = 0
	reclaimed_this_run = []
	game_over = false
	# A fresh run has met nothing. Cleared here as well as at declaration
	# because new_game() is also the restart path.
	gem_found = false
	uniques_found.clear()
	cave_vaults_seen.clear()
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
	reload_rng.seed = int(rng.seed) ^ (depth * 3571) ^ 0x51D6
	fungus_rng.seed = int(rng.seed) ^ (depth * 6151) ^ 0xF6A1
	trap_rng.seed = int(rng.seed) ^ (depth * 7919) ^ 0x7A9D
	drink_rng.seed = int(rng.seed) ^ (depth * 5381) ^ 0xD121
	nap_rng.seed = int(rng.seed) ^ (depth * 6829) ^ 0x5A9E
	hunger_rng.seed = int(rng.seed) ^ (depth * 7253) ^ 0x4C6B
	fauna_rng.seed = int(rng.seed) ^ (effective_depth() * 4297) ^ 0xFA0A
	_cloud_turn = -1
	_cornered_said = {}
	scorched = {}
	mud_under = {}
	tending = {}
	red_from = {}
	withering = []
	_reload_said = false
	_retreat_said = false
	_wade_said = false
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
	gen.cave_seen = cave_vaults_seen
	gen.generate(map)
	for spot in gen.cave_vault_spots:
		var met: Array = cave_vaults_seen.get(spot["vault"].name, [])
		met.append([int(spot["quarters"]), bool(spot["mirror"])])
		cave_vaults_seen[spot["vault"].name] = met

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
	bodies = []
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
	# THE ROAD starts again on every floor: you arrive everywhere at your
	# weakest. The starting room is marked found now, so it never counts.
	rooms_found = {0: true}
	player.travel_rooms = 0
	hoard_room = -1
	for i in gen.archetypes.size():
		if gen.archetypes[i] == MapGen.Archetype.HOARD:
			hoard_room = i
			break
	brazier_charge.clear()
	ember_until.clear()
	barred.clear()
	barred_gates.clear()
	frozen_rooms.clear()
	recall_mark = Vector2i(-1, -1)
	road_shown = false
	_road_cache.clear()
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
	_roll_the_wild()
	for i in range(1, rooms.size()):
		_populate_room(rooms[i], gen.archetypes[i])
	for region in gen.caves:
		# A cave vault whose author placed its own monsters is not peopled
		# by the roll as well: both would spend one ceiling twice. One with
		# no monster markers is peopled like any cave.
		if _authored_monsters(gen, region):
			continue
		_populate_cave(region)
	_place_the_wild(gen)
	_place_vault_contents(gen)
	_assign_beats()
	_place_first_gem()
	_place_the_satchel()
	_place_chest()
	# Last, so the trader takes a cell nothing else wanted.
	_place_trader()
	vault_rects.clear()
	vault_names.clear()
	for spot in gen.vault_spots:
		vault_rects.append(spot["rect"])
		vault_names.append(spot["vault"].name)
	# A cave vault is an authored place too: the corruption keeps out of it,
	# and nothing rewrites its terrain (protected_cell).
	for spot in gen.cave_vault_spots:
		vault_rects.append(spot["rect"])
		vault_names.append(spot["vault"].name)
	# AFTER the vault rects are recorded, because _corrupt_sites reads them to
	# keep out of authored rooms. Called any earlier and it would be checking
	# the previous floor's vaults.
	_place_corrupted()
	# Last of all, once every tile is final: graves, the chest and the trader
	# can all take a rubble cell, and the gem must be under one that stays.
	_hide_the_geode()

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
	_land_the_fallen()
	_hide_the_traps()

	_keep_the_fire_clean()
	pathfinder = Pathfinder.new(map)
	_teach_the_slingers()
	_set_appetites()
	_prerun()
	update_vision()

## HUNGER, FOR THE MONSTERS AND THE ANIMALS (Brad, 2026-10-07). Not for
## you: every way you heal outside a brazier is something swallowed, so you
## live under hunger already (BACKLOG, Declined). For anything that `eats`,
## `Entity.hunger` counts its turns since it last ate. Hungry (HUNGRY_AT), it
## hunts game and goes to meat as every hunter did before; fed, it lets both
## be -- so a bear that has had its rabbit leaves the next one alone for a
## while, and a hungry den bear is worse to wake than a fed one
## (DEN_FED_SCALE). It does not count during the pre-run (or everything
## arrives starving), nor while an animal naps or a bear hibernates; eating
## sets it back to nothing. Your allies hunt for YOU and keep no count.
## Arrival: each eater dealt between nothing and HUNGER_START_MAX, so about
## one in three arrives hungry.
const HUNGER_START_MAX := 300

func _set_appetites() -> void:
	for e in entities:
		if e.alive and e.eats and not e.is_player \
				and e.faction != Entity.Faction.PLAYER:
			e.hunger = hunger_rng.randi_range(0, HUNGER_START_MAX)

## One turn of an eater's hunger (see _set_appetites). Counted by the
## creature's OWN turns, not the clock, on purpose: a fast thing burns more,
## so a speed-130 wolf goes hungry about a third sooner than a bear. Brad
## kept it as metabolism (2026-10-07, raised in the desktop's review).
func _grow_hungry(actor: Entity) -> void:
	if not actor.eats or actor.faction == Entity.Faction.PLAYER or _prerunning:
		return
	if actor.is_wild() and actor.alertness == Entity.Alert.ASLEEP:
		return
	actor.hunger += 1

## A FLOOR THAT WAS ALIVE BEFORE YOU ARRIVED (Brad and the Legion, 2026-10-04;
## built 2026-10-06). The floor gets PRERUN_TURNS quiet turns of its own life
## before you are placed in it: rabbits graze and drink, guards walk their
## rounds and tend their fires, wolves and bears go about their day, a slime
## gathers what lies about. You walk into a result, not a fresh board -- the
## one shape of off-screen life that pays off within a single visit, since
## the dungeon is one-way.
##
## ONLY THE ANIMALS (the same evening). The first version gave every
## creature the turns, and the suite caught what that does: seven patrollers
## walked one round for 150 turns and bunched in a guard room at 81 threat
## against a ceiling of 24 -- the survivability promise broken on arrival.
## So hostile monsters stay exactly where placed (the ceiling bought each
## room as it is) and start their rounds when you arrive, as they always
## have; the wild -- which no ceiling counts -- live their 150 turns.
##
## BRAD'S RULE: NOBODY DIES IN THE PRE-RUN. While it runs, an attack lands
## nothing, noise carries nowhere, nothing notices you, scavengers take no
## gear (that would raise a floor's threat past its ceiling), no rabbit turns
## killer, the fungus does not grow and fires do not age (`turns` does not
## move). So the threat on the floor is exactly what mapgen budgeted, only
## rearranged, and the ceiling promise holds untouched. Monsters already
## hunting you are left out, so nothing gathers at your feet. It draws on
## its own rng, swapped in for the run, so no other roll moves; what it would
## have said or shown is thrown away.
const PRERUN_TURNS := 150
## The turns a floor actually runs. A static only so the suite can build the
## same floor with and without it, to prove the pre-run changes nothing it
## must not; play never touches it.
static var prerun_turns := PRERUN_TURNS
var _prerunning := false
var prerun_rng := RandomNumberGenerator.new()

func _prerun() -> void:
	if prerun_turns <= 0:
		return
	prerun_rng.seed = int(rng.seed) ^ (effective_depth() * 9157) ^ 0x9E1A
	var main := rng
	rng = prerun_rng
	var said: Array = msg_log.entries.duplicate(true)
	_prerunning = true
	# The animals are up: a floor's wild things must be awake to be found
	# doing anything (and once up they stay up -- _update_awareness).
	var living: Array = []
	for e in entities:
		if e.alive and e.is_wild() and not e.provoked:
			# A bear in its den hibernates through it (2026-10-07).
			if not e.denned:
				e.alertness = Entity.Alert.AWAKE
			living.append(e)
	for _turn in prerun_turns:
		for e in living:
			if e.alive:
				_take_ai_turn(e)
	_prerunning = false
	rng = main
	msg_log.entries = said
	events.clear()

## On the first floor a reloading kind appears -- on the way down -- it
## reloads for exactly one turn after every shot: a teaching floor. Whatever
## spawned it (rooms, vaults), it is settled here, once the floor is populated.
func _teach_the_slingers() -> void:
	if ascending:
		return
	for e in entities:
		if e.reload_style == Entity.Reload.RANDOM and depth == first_floor_of(e.appearance):
			e.reload_style = Entity.Reload.STEADY

## The shallowest floor a kind of creature can appear on, from the bestiary.
static func first_floor_of(app: StringName) -> int:
	for entry in BESTIARY:
		if entry["app"] == app:
			return int(entry.get("min_depth", 1))
	return 1

## How many turns a shot costs a reloader before it may shoot again.
func _reload_after_shot(actor: Entity) -> int:
	match actor.reload_style:
		Entity.Reload.STEADY:
			return 1
		Entity.Reload.RANDOM:
			var r := reload_rng.randf()
			return 0 if r < 0.5 else (1 if r < 0.85 else 2)
	return 0

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

## Somewhere a creature can ARRIVE without walking in: a blink, the blink
## scroll, the returning gem, a creature fallen from the floor above.
##
## And walkable is not enough a third time. A shut or barred door is walkable
## because walking INTO it is how it opens, so every arrival that asked only
## that stood its creature inside one -- a lich blinked into a shut, opaque
## door (day 7, 2026-10-04), and the scroll, whose own copy of the rule lacked
## even is_avoided, could set you over a pit with no fall to follow.
##
## A HIDDEN trap is floor here and stays so: landing on one does not spring
## it, because a landing is not a step. Settled by Brad, 2026-10-04: the
## scroll is a panic escape to a square you did not choose, and springing a
## trap you could neither see nor avoid there would be unfair, not tense.
func _can_land_on(x: int, y: int) -> bool:
	var t := map.get_tile(x, y)
	return _can_rest_on(x, y) and not Tiles.is_shut(t)

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
			elif t == Tiles.FUNGUS_PURPLE:
				# Dimmer than the green, and sickly: a glow you do not want.
				static_lights.append(LightSource.new(x, y, 2,
					Color(0.66, 0.44, 0.88), Color(0.22, 0.12, 0.30), 0.40, false))
			elif t == Tiles.FUNGUS_RED:
				static_lights.append(LightSource.new(x, y, 2,
					Color(0.86, 0.26, 0.28), Color(0.30, 0.08, 0.10), 0.40, false))

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

## Where a creature may step when it is NOT following the pathfinder -- going
## round a friend, wandering, fleeing. `can_step` plus the rule the pathfinder
## already keeps: never onto a pit or a trap.
##
## The three hand-rolled steppers asked only `can_step`, and pits are walkable
## (they must be, or the player could not fall in). So a bone ally going round
## the player could sidestep onto a pit -- and there it stayed for good, because
## the pathfinder treats avoided ground as solid and cannot plan one step OFF
## it. Brad saw an ally standing in a pit, never moving again (2026-09-20).
## Monsters do not fall through pits; they keep off them, as items and spawns
## already do (`_can_rest_on`) and as a shove already refuses to push them in.
##
## A FOUND trap is the floor's own business: a monster steps over it (it laid
## it), and only the player's side keeps off it (2026-10-02). No actor given
## means the stricter rule.
func can_creature_step(fx: int, fy: int, nx: int, ny: int, actor: Entity = null) -> bool:
	if not can_step(fx, fy, nx, ny):
		return false
	var t := map.get_tile(nx, ny)
	if t == Tiles.PIT:
		return false
	# A shut latched gate is a wall to anything that cannot work a latch.
	if t == Tiles.GATE_CLOSED and actor != null and _gate_holds(actor):
		return false
	return t != Tiles.TRAP or (actor != null and _owns_the_floor(actor))

## Does a shut latched gate stop this creature? Whatever squeezes under a
## door -- the animals, the small and handless -- except what phases through
## stone. Those with hands lift the latch; the heavy smash it.
func _gate_holds(actor: Entity) -> bool:
	return actor.door_style() == Entity.Door.SQUEEZES and not actor.phasing \
		and not actor.is_player

## A gate opened, shut or smashed: the squeezers' routes learn it.
func _set_gate_route(c: Vector2i) -> void:
	if pathfinder != null:
		pathfinder.set_gate(c.x, c.y, map.get_tile(c.x, c.y) == Tiles.GATE_CLOSED)

## Whether a creature knows this floor's traps: everything that is not on the
## player's side. The risen are the floor's own dead and know it too.
func _owns_the_floor(e: Entity) -> bool:
	return not e.is_player and e.faction != Entity.Faction.PLAYER

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

## Kept as a method because five call sites and two measurement tools use it,
## and because `effective_depth()` is the one piece of state the sum needs.
func room_threat_ceiling() -> int:
	return Threat.room_ceiling(effective_depth())

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
	return Threat.cave_ceiling(effective_depth(), cells)

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
			if Tiles.is_doorway(t):
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

## Which tiers of equipment a trader stocks, by how deep the player has BEEN.
##
## Brad's rule, 2026-09-24: the upper floors sell tier 1, the caves tier 1 and 2,
## and from the fortress on tier 2 and 3 -- no tier 1, because by then a dagger
## is too weak to be worth a place on the shelf, and the trader knows it. So
## floor 6 is the last chance to BUY a dagger; the dungeon still drops them.
##
## Deliberately NOT mirrored, unlike almost everything else keyed on a floor.
## The climb reuses the descent's bands, which would put a floor-17 trader back
## to selling daggers to someone carrying a +3 war axe. Every climb trader
## sells what the deepest floors do, because that is where the player has been.
## (The first version keyed this on `min_depth` and a two-band window, which
## put a mace -- tier 3, one hit for anything on floor 1 -- on the first shelf.)
static func trader_tiers(effective: int) -> Array:
	var deepest := mini(effective, MAX_DEPTH)
	if deepest <= 3:
		return [1]
	if deepest <= 6:
		return [1, 2]
	return [2, 3]

## Fill the trader's shelves.
##
## EQUIPMENT: one of every tradeable piece in the tiers `trader_tiers` allows.
## Brad's rule -- a trader is a reliable way to fill a gap, not a lottery.
## Plain, never enchanted: magic is the enchant roll's job.
##
## CONSUMABLES: PROVISIONAL counts, not yet settled with Brad.
##
## RELICS: up to three twice-dead heroes, each represented by the most valuable
## piece of their kit, drawn from the morgue. Eligible once reclaimed, never
## once sold, and never if reclaimed during this very run.
func _stock_trader() -> void:
	var tiers := trader_tiers(effective_depth())
	var deepest := mini(effective_depth(), MAX_DEPTH)
	for key in Item.CATALOGUE:
		var data: Dictionary = Item.CATALOGUE[key]
		if data.get("unique", false) or not tiers.has(int(data.get("tier", 0))):
			continue
		trader_stock.append({"item": Item.make(key), "relic": "", "hero": ""})

	for key in [&"potion_healing", &"potion_healing", &"scroll_light", &"scroll_blink"]:
		var it := Item.make(key)
		if it != null and int(Item.CATALOGUE[key].get("min_depth", 999)) <= deepest:
			trader_stock.append({"item": it, "relic": "", "hero": ""})

	var heroes: Array = []
	for rec in Morgue.records(MORGUE_PATH):
		if not rec.get("reclaimed", false) or rec.get("sold", false):
			continue
		if reclaimed_this_run.has(String(rec.get("line", ""))):
			continue
		var best: Item = null
		for piece in rec.get("gear", []):
			var it := Item.from_display_name(String(piece))
			if it != null and Trade.worth(it) > 0 \
					and (best == null or Trade.worth(it) > Trade.worth(best)):
				best = it
		if best != null:
			heroes.append({"item": best, "relic": String(rec["line"]),
				"hero": Morgue.name_of(rec)})
	# Fisher-Yates through trader_rng, never Array.shuffle(): that draws on
	# Godot's global rng and makes every seeded run unrepeatable.
	for i in range(heroes.size() - 1, 0, -1):
		var j := trader_rng.randi_range(0, i)
		var tmp = heroes[i]
		heroes[i] = heroes[j]
		heroes[j] = tmp
	for i in mini(3, heroes.size()):
		trader_stock.append(heroes[i])

## Is there a trader to deal with on this floor?
func trader_here() -> bool:
	return trader != null and trader.alive

## Put something from the pack on the counter.
func trade_sell(index: int) -> bool:
	if not trader_here() or index < 0 or index >= player.inventory.size():
		return false
	var it: Item = player.inventory[index]
	var no := Trade.refusal(it)
	if no != "":
		msg_log.add(no, Color(0.85, 0.75, 0.55))
		return false
	# ROAD ARMOUR IS OFFERED TWICE. Selling it is allowed -- a player may just
	# want a different build (Brad) -- but it is the only way this stone ever
	# leaves you, so the first offer is stopped and said out loud. The game has
	# no prompt system; as with raking a brazier down, an action with its own
	# message IS the confirmation. Anything else in between starts it over.
	if Trade.carries_road(it) and road_offered != it:
		road_offered = it
		msg_log.add("The trader stops your hand. \"This carries a stone of the road. Are you sure? Offer it again and it is mine.\"",
			Color(0.85, 0.75, 0.55))
		return false
	road_offered = null
	it = _spend_one(it)
	if Trade.is_gem(it):
		trader_gems += 1
		msg_log.add("The trader takes the %s. (%d of %d toward a gem of your choice)"
			% [it.name, trader_gems, Trade.GEMS_FOR_ONE], Color(0.80, 0.85, 0.95))
		return true
	var w := Trade.worth(it)
	trader_credit += w
	# "yours" marks it on the shelf as something the player brought, so the
	# counter can show it apart from the trader's own stock (Brad, 2026-09-24:
	# his sold sling sat among the shop's and looked like theirs).
	trader_stock.append({"item": it, "relic": "", "hero": "", "yours": true})
	msg_log.add("The trader takes the %s. (+%d, %d credit)"
		% [it.display_name(), w, trader_credit], Color(0.80, 0.85, 0.95))
	return true

## Road armour the player has offered once, awaiting the second offer. Not
## saved: a suspend in the middle of a sale simply asks again.
var road_offered: Item = null

## Take something off the trader's shelf.
func trade_buy(stock_index: int) -> bool:
	road_offered = null
	if not trader_here() or stock_index < 0 or stock_index >= trader_stock.size():
		return false
	var entry: Dictionary = trader_stock[stock_index]
	var it: Item = entry["item"]
	var cost := Trade.price(it)
	if cost > trader_credit:
		msg_log.add("\"That is %d. You have %d with me.\"" % [cost, trader_credit],
			Color(0.85, 0.75, 0.55))
		return false
	if not give_item(it):
		msg_log.add("Your pack is full -- sell or drop something to make room for the %s."
			% it.display_name(), Color(0.9, 0.55, 0.35))
		return false
	trader_credit -= cost
	trader_stock.remove_at(stock_index)
	if String(entry["relic"]) != "":
		Morgue.mark_sold(MORGUE_PATH, String(entry["relic"]))
		msg_log.add("You take %s's %s. \"They would want it used.\""
			% [entry["hero"], it.display_name()], Color(0.80, 0.85, 0.95))
	else:
		msg_log.add("You take the %s. (%d credit left)"
			% [it.display_name(), trader_credit], Color(0.80, 0.85, 0.95))
	return true

## Three offered gems for one of your choice.
func trade_buy_gem(el: StringName) -> bool:
	road_offered = null
	# Only what the three-for-one offers: a stone kept out of the economy, like
	# the gem of the road, cannot be bought by naming it either.
	if not trader_here() or not Item.chosen_elements().has(el):
		return false
	if trader_gems < Trade.GEMS_FOR_ONE:
		msg_log.add("\"Bring me %d gems and choose one.\"" % Trade.GEMS_FOR_ONE,
			Color(0.85, 0.75, 0.55))
		return false
	var gem := Item.make(StringName(Item.ELEMENTS[el]["gem"]))
	if gem == null or not give_item(gem):
		msg_log.add("Your pack is full -- sell or drop something to make room for the %s."
			% (gem.name if gem != null else "gem"), Color(0.9, 0.55, 0.35))
		return false
	trader_gems -= Trade.GEMS_FOR_ONE
	msg_log.add("You take the %s." % gem.name, Color(0.80, 0.85, 0.95))
	return true

## The trader puts something random into an item of yours. Once per trader.
func trade_enchant(index: int) -> bool:
	road_offered = null
	if not trader_here() or index < 0 or index >= player.inventory.size():
		return false
	if trader_rolled:
		msg_log.add("\"I have done what I can for you. Once is all I have.\"",
			Color(0.85, 0.75, 0.55))
		return false
	if trader_credit < Trade.ENCHANT:
		msg_log.add("\"That is %d. You have %d with me.\"" % [Trade.ENCHANT, trader_credit],
			Color(0.85, 0.75, 0.55))
		return false
	var it: Item = player.inventory[index]
	var legal: Array[StringName] = []
	if it.is_equipment() and not it.unique and it.element == &"":
		for el in Item.found_elements():
			if it.accepts_element(el):
				legal.append(el)
	if legal.is_empty():
		msg_log.add("\"There is nothing I can put in that.\"", Color(0.85, 0.75, 0.55))
		return false
	it.element = legal[trader_rng.randi_range(0, legal.size() - 1)]
	trader_credit -= Trade.ENCHANT
	trader_rolled = true
	msg_log.add("The trader works at it a while. It is %s now." % it.display_name(),
		Color(0.80, 0.85, 0.95))
	return true

## Where the trader stands, once per floor that has one. Null everywhere else.
var trader: Entity = null

## THE TRADER'S SIDE OF THE COUNTER, for the trader on this floor.
##
## The economy lives in Trade (prices) and BACKLOG.md (why). This is the
## state, and all of it resets when a floor with a trader is built.
##
## Each entry is {"item": Item, "relic": <morgue line or "">, "hero": <name>}.
## A relic is the last of a twice-dead hero's kit; buying it marks that hero
## `sold` in the morgue so no later run can buy it again.
var trader_stock: Array = []
## Points on the slate. Selling adds, buying spends. What is left stays with
## this trader while you are on this floor -- come back as often as you like --
## and is gone when you leave it.
##
## CREDIT rather than "pick what to give for each purchase", because it is the
## simplest model that fits everything agreed: the trader takes anything, the
## affordable list regenerates after each purchase, and there is no question of
## which offered items were "used up". And selling puts the item into the
## stock at the same price, so a mistaken sale can be bought straight back.
var trader_credit: int = 0
## Gems are their own currency -- see Trade. Offered gems count here.
var trader_gems: int = 0
## One enchant roll per trader. A SERVICE rather than a good: goods are limited
## by stock and price, a service has no stock, so it needs a rule.
var trader_rolled: bool = false
## Heroes reclaimed during THIS run. Their kit already dropped on the floor
## where they fell, so selling it back two floors later would be a duplicate.
var reclaimed_this_run: Array = []

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
			if t == Tiles.SHRINE or t == Tiles.GRAVE or Tiles.is_doorway(t):
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
	trader_stock = []
	trader_credit = 0
	trader_gems = 0
	trader_rolled = false
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
	# After placement, so how much the stock draws cannot move where the trader
	# stands. Both come from trader_rng, and placement has already finished.
	_stock_trader()

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

## The farthest room from where you woke up, and never room 0 -- where a
## guaranteed find is laid so it reads as loot and not as a gift (see
## _place_first_gem). The whole floor when there are no rooms.
func _far_room() -> Rect2i:
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
	return where

## THE SATCHEL BY THE CAVES (Brad, 2026-10-01). The chests may hand it over
## earlier (after the ring and the shovel), but the caves are what it is FOR
## -- fungus to pick, rabbits and bears to eat -- so a run that reaches the
## first cave floor without one finds it lying there, in the far room, and
## never sees a second. Nothing on the climb: by then the chance is spent.
func _place_the_satchel() -> void:
	if ascending or uniques_found.has(&"satchel"):
		return
	for it in player.inventory:
		if it.is_satchel():
			uniques_found[&"satchel"] = true
			return
	if not Bands.is_caves(depth) or Bands.is_caves(depth - 1):
		return
	var at := _open_cell_in(_far_room())
	if at.x < 0:
		return
	_drop_item_at(Item.make(&"satchel"), at)
	uniques_found[&"satchel"] = true

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
	var at := _open_cell_in(_far_room())
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
	_place_fauna(Rect2i(room.position, room.size), FAUNA_CHANCE)

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
	# Brad's lore: the corrupted crossed purple fungus and were changed.
	m.take_spores(&"purple")
	# Changed all the way: a corrupted animal is a monster, and hunts you
	# unstruck. The purple takes the wild out of it (2026-10-04).
	if m.faction == Entity.Faction.WILD:
		m.faction = Entity.Faction.MONSTER
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

## Does a cave vault fill this region with monsters of its author's own?
func _authored_monsters(gen: MapGen, region: Rect2i) -> bool:
	for spot in gen.cave_vault_spots:
		if spot["rect"] != region:
			continue
		for entry in gen.vault_contents:
			var ch: String = entry["ch"]
			if not region.has_point(entry["pos"]):
				continue
			if ch == "m" or ch == "M":
				return true
			# A monster by name counts; an animal by name does not.
			if ch == "creature":
				for e in BESTIARY:
					if String(e["name"]) == String(entry["name"]) and not e.get("wild", false):
						return true
	return false

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
	# The caves are where the animals live: a better chance of one. (The
	# bear, and its den, are placed by _place_the_wild once the floor is.)
	_place_fauna(region, FAUNA_CHANCE_CAVE)

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
func _spawn_in(area: Rect2i, remaining: int, wild_only := false) -> int:
	var mx := rng.randi_range(area.position.x, area.end.x - 1)
	var my := rng.randi_range(area.position.y, area.end.y - 1)
	return _spawn_at(Vector2i(mx, my), -1, remaining, wild_only)

## THE WILD, ON TOP OF THE BUDGET (2026-10-05). Each room and cave has a
## chance of one animal, rolled by the bestiary's own weights, depths and
## bands (the bat's floors, the bear's caves) and never SPENT from the
## threat ceiling: an animal is a cost to nobody until it is struck. Nor is
## it PRICED by the area's ceiling any more (the same evening): that price
## only ever touched the bear -- a floor-1 room's ceiling of 12 could not
## afford a 17 -- and Brad wants the bear on the upper floors now that a
## player can walk round it. The bear and the wolf are not in this roll at
## all any more: see `bands` below. Chances set so the counts match what
## the old budget roll produced (about four to six animals a floor).
const FAUNA_CHANCE := 0.4
const FAUNA_CHANCE_CAVE := 0.6
## No price: an animal's threat is never compared with a ceiling.
const WILD_UNPRICED := 1 << 16

## WHERE A THING LIVES, AND HOW OFTEN (Brad, 2026-10-05). A bestiary row
## with `bands` names the bands it is found in, with the chance that a floor
## of that band has it AT ALL: the wolf's {upper: 0.5, caves: 0.75} is a
## pack on half the upper floors and three cave floors in four. The band
## table is mirrored, so "upper and caves" is floors 1-6 and 14 on and never
## either fortress -- a wild pack in masonry reads wrong; the fortress gets
## its animals trained, with a master (BACKLOG). Decided once a floor, here,
## and SET DOWN once by _place_the_wild, never as a share of the per-area
## roll: a share on floor 1, where the wolf and the bear are the only wild
## things there are, put both on nearly every floor (measured: 60/60 and
## 50/60); and a share in the caves starved the rabbits the climb's caves
## exist to feed you with (17 in 30 floors against a fortress floor's 60).
## Own rng, so the floor's other rolls do not move; not saved, since it is
## only the floor's own population.
var absent_wild: Array = []
var fauna_rng := RandomNumberGenerator.new()

## The floor's banded animals, one each, in a cave where the floor has
## caves and otherwise in a room that is not the first. A bear's den forms
## round it as it did when the cave roll placed the bear.
func _place_the_wild(gen: MapGen) -> void:
	var in_caves := not gen.caves.is_empty()
	var areas: Array[Rect2i] = gen.caves if in_caves else gen.rooms.slice(1)
	if areas.is_empty():
		return
	for e in BESTIARY:
		if not e.has("bands") or absent_wild.has(e["name"]):
			continue
		for _try in 12:
			var area: Rect2i = areas[fauna_rng.randi_range(0, areas.size() - 1)]
			var at := Vector2i(fauna_rng.randi_range(area.position.x, area.end.x - 1),
				fauna_rng.randi_range(area.position.y, area.end.y - 1))
			if not _can_rest_on(at.x, at.y) or entity_at(at.x, at.y) != null \
					or at == stairs or at == Vector2i(player.x, player.y):
				continue
			_place_pick(at, e, -1, WILD_UNPRICED)
			if in_caves and e["app"] == &"bear":
				# Asleep in its den (Brad, 2026-10-07: bears hibernate). The
				# pre-run leaves it asleep, and the den's bones are its alarm.
				var bruin: Entity = entity_at(at.x, at.y)
				if bruin != null:
					bruin.denned = true
					bruin.alertness = Entity.Alert.ASLEEP
				_make_a_den(area)
			break

func _roll_the_wild() -> void:
	absent_wild = []
	var band_name: StringName = Bands.NAMES[Bands.of(effective_depth())]
	for e in BESTIARY:
		if not e.has("bands"):
			continue
		var chance := float((e["bands"] as Dictionary).get(band_name, 0.0))
		if fauna_rng.randf() >= chance:
			absent_wild.append(e["name"])

func _place_fauna(area: Rect2i, chance: float) -> void:
	if rng.randf() < chance:
		_spawn_in(area, WILD_UNPRICED, true)

func _spawn_at(at: Vector2i, tier: int, remaining: int, wild_only := false) -> int:
	var mx := at.x
	var my := at.y
	if not _can_rest_on(mx, my) or entity_at(mx, my) != null:
		return 0
	if Vector2i(mx, my) == stairs or Vector2i(mx, my) == Vector2i(player.x, player.y):
		return 0
	var pick := _roll_monster(remaining, tier, wild_only)
	if pick.is_empty():
		return -1
	return _place_pick(at, pick, tier, remaining)

## The rolled (or chosen) entry, set down at a cell already checked.
func _place_pick(at: Vector2i, pick: Dictionary, tier: int, remaining: int) -> int:
	var mx := at.x
	var my := at.y
	var m := monster_from(pick, mx, my)
	_set_the_watch(m)
	# Gear raises what a monster is actually worth facing, so it must raise the
	# threat too. Otherwise a room of armed orcs quietly costs more than its
	# ceiling claims, and the survivability guarantee becomes a lie.
	m.threat += _arm_monster(m, pick, remaining - m.threat)
	entities.append(m)
	# A pack animal brings its pack (the wolf, 2026-10-05): the rest come on
	# top of the one the roll bought, beside it, and cost the ceiling nothing
	# -- an animal is nobody's enemy until struck.
	var pack := _pack_size(pick, tier)
	if pack > 1:
		_spawn_pack(m, pick, pack - 1)
	return m.threat

## How far a struck wolf's pack turns with it.
const PACK_REACH := 8

## TAMING THE WOLVES (Brad's design 2026-10-05; built 2026-10-06). A pack on
## your side, instead of a bone ally or the risen -- a way to play that
## players will choose (the "jobs without names" note in BACKLOG). Two prices,
## one choice: haunches to the pack's count (a pair's worth on the upper
## floors, four in the caves; any haunch -- bear, rabbit, wolf -- counts), or
## a knucklebone, which has another use and so is a real price too. Haunches
## first when you have enough, the bone only when you do not. The pack turns
## as one, the provocation loop run the other way, and a heart floats over
## each (the `tamed` event). A tamed pack hunts for you (_ally_hunts), heals
## only when hurt and only from meat lying about, follows you down the stairs
## as any ally does, and by the fortress is chaff -- which is its decay.
func _tameable(e: Entity) -> bool:
	return e.alive and e.is_wild() and not e.provoked \
		and bool(_bestiary_row(e.appearance).get("tame", false))

## Haunches to the pack's count: a pair's on the upper floors, four in the caves.
func _tame_price(e: Entity) -> int:
	return _pack_size(_bestiary_row(e.appearance))

func _knucklebone() -> Item:
	for it in player.inventory:
		if it.id == &"bone":
			return it
	return null

## Every haunch you carry, in the satchel's shelves and the pack's stacks.
func _haunches_carried() -> int:
	var n := 0
	var bag := _the_satchel()
	if bag != null:
		for row in bag.contents:
			if _is_meat(row):
				n += row.count
	for it in player.inventory:
		if _is_meat(it):
			n += it.count
	return n

func _can_tame(e: Entity) -> bool:
	return _haunches_carried() >= _tame_price(e) or _knucklebone() != null

## One log line (about 95 characters), the fight's alternative named.
func _tame_offer(e: Entity) -> String:
	var price := _tame_price(e)
	if _haunches_carried() >= price:
		return "That is a %s. Move into it again to tame the pack with %d haunches; shoot to fight it." % [e.name, price]
	return "That is a %s. Move into it again to tame the pack with the knucklebone; shoot to fight it." % e.name

## `n` haunches spent: the satchel's shelves first, then the pack's stacks.
func _spend_haunches(n: int) -> void:
	var bag := _the_satchel()
	if bag != null:
		for row in bag.contents.duplicate():
			if n <= 0:
				break
			if not _is_meat(row):
				continue
			var take := mini(row.count, n)
			row.count -= take
			n -= take
			if row.count <= 0:
				bag.contents.erase(row)
	for it in player.inventory.duplicate():
		while n > 0 and _is_meat(it) and player.inventory.has(it):
			_spend_one(it)
			n -= 1

## The second move into a tameable animal with the price in your pack.
func _tame(target: Entity) -> bool:
	var price := _tame_price(target)
	if _haunches_carried() >= price:
		_spend_haunches(price)
		msg_log.add("You throw down the %s. The pack eats, and is yours."
			% ("haunch" if price == 1 else "haunches"), Color(0.70, 0.90, 0.78))
	else:
		var bone := _knucklebone()
		if bone == null:
			return false
		_spend_one(bone)
		msg_log.add("You hold out the knucklebone. The %s takes it, and the pack comes with it."
			% target.name, Color(0.70, 0.90, 0.78))
	_travel.clear()
	for e in entities:
		if e.alive and e.appearance == target.appearance and e.is_wild() and not e.provoked \
				and Los.steps(e.x, e.y, target.x, target.y) <= PACK_REACH:
			_turn_to_you(e)
	_end_player_turn()
	return true

## One animal to your side: the provocation loop run the other way.
func _turn_to_you(e: Entity) -> void:
	e.faction = Entity.Faction.PLAYER
	e.provoked = false
	e.grudge = null
	e.alertness = Entity.Alert.AWAKE
	e.stance = Entity.Stance.LOOSE
	e.drinking = 0
	events.append({"kind": &"tamed", "to": Vector2i(e.x, e.y)})

## THE PACK HUNTS FOR YOU. An ally with an appetite takes game within your
## reach -- a rabbit's worth of fighting, never a bear -- and leaves the
## haunch for you unless it is HURT: then it eats, and heals what the meat
## would have healed you. The first ally that heals, and it is paid for with
## your own larder; a well wolf never steals from it.
func _ally_hunts(actor: Entity, range_out: int) -> bool:
	var hurt := actor.hp < actor.max_hp
	if hurt and _eat_here(actor):
		return true
	var prey := _prey_for(actor)
	if prey != null and Los.steps(player.x, player.y, prey.x, prey.y) <= range_out:
		if actor.is_adjacent(prey):
			_attack(actor, prey)
		else:
			_safe_step_toward(actor, Vector2i(prey.x, prey.y))
		return true
	if hurt:
		var meat := _meat_near(actor)
		if meat.x >= 0 and Los.steps(player.x, player.y, meat.x, meat.y) <= range_out:
			_safe_step_toward(actor, meat, true)
			return true
	return false

## A pack's size at a depth: a number, or a table by band name (a pair of
## wolves on the upper floors, four in the caves). One, for the packless.
func _pack_size(entry: Dictionary, at_depth: int = -1) -> int:
	var pack: Variant = entry.get("pack", 1)
	if pack is Dictionary:
		var d := effective_depth() if at_depth < 0 else at_depth
		return int(pack.get(Bands.NAMES[Bands.of(d)], 1))
	return int(pack)

## `more` of the same beside `leader`, on the nearest open squares (chosen
## in ring order, not rolled: a draw here would move every later roll).
func _spawn_pack(leader: Entity, pick: Dictionary, more: int) -> void:
	var placed := 0
	for radius in range(1, 4):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if placed >= more:
					return
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var c := Vector2i(leader.x + dx, leader.y + dy)
				if not map.in_bounds(c.x, c.y) or not _can_rest_on(c.x, c.y) \
						or entity_at(c.x, c.y) != null or c == stairs \
						or c == Vector2i(player.x, player.y):
					continue
				var m := monster_from(pick, c.x, c.y)
				_set_the_watch(m)
				entities.append(m)
				placed += 1

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
	# An animal. WILD acts and is nobody's enemy until struck -- see
	# Entity.hostile_to and _ai_wild (Brad, 2026-10-04).
	if bool(entry.get("wild", false)):
		m.faction = Entity.Faction.WILD
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
	m.eats = entry.get("eats", false)
	m.acid = bool(entry.get("acid", false))
	if m.ai == &"forager":
		m.activity = Entity.Activity.FEEDING
	m.attack_range = entry.get("range", 1)
	m.reload_style = Entity.Reload.RANDOM if entry.get("reload", false) else Entity.Reload.NONE
	m.careful = entry.get("careful", false)
	m.casts = entry.get("casts", false)
	m.standoff = entry.get("standoff", 1)
	m.blink_range = entry.get("blink", 0)
	m.phasing = entry.get("phasing", false)
	m.climbs = entry.get("climbs", false)
	m.venom = int(entry.get("venom", 0))
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
		reclaimed_this_run.append(String(rec["line"]))
	if map.get_tile(risen_grave.x, risen_grave.y) == Tiles.GRAVE:
		map.set_tile(risen_grave.x, risen_grave.y, Tiles.FLOOR)
	grave_at.erase(risen_grave)
	if risen_grave == _last_grave:
		_last_grave = Vector2i(-1, -1)
	risen_grave = Vector2i(-1, -1)
	msg_log.add("The headstone crumbles. Whatever was owed here is paid.",
		Color(0.70, 0.72, 0.78))

func _drop_loot(victim: Entity) -> void:
	# Raised once already -- by the red or by the shovel: everything it had
	# dropped when it first died, so what it carries now is a copy. Nothing
	# twice -- not gear, not meat, not the dragon's sack. (A grave's bone ally
	# is not `raised`: its kit is the only copy, and the faction rule below
	# hands it all back.)
	if victim.raised:
		victim.equipped.clear()
		victim.inventory.clear()
		return
	if victim.appearance == &"rabbit" or victim.appearance == &"killer_rabbit" \
			or victim.appearance == &"bear" or victim.appearance == &"wolf":
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
	# WHAT IT CARRIED UNWORN (the slime, 2026-10-05: the first monster to
	# carry things it does not wear). Everything it swallowed is marked
	# scavenged, so all of it comes back out, certain -- the dungeon may take
	# your things, not eat them; anything else unworn rolls like gear does.
	for it in victim.inventory:
		if victim.is_equipped(it):
			continue
		if victim.faction != Entity.Faction.PLAYER and not it.scavenged \
				and rng.randf() > LOOT_DROP_CHANCE:
			continue
		_drop_item_at(it, at)
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
			"r":
				# A rabbit of the garrison's warren (Brad, 2026-10-07): the one
				# way a rabbit is found in a fortress. Wild like any rabbit and
				# never spent from the budget -- an animal is nobody's enemy.
				_place_kept(at, &"rabbit")
			"x":
				# A spider where the author drew it (2026-10-09): wild, on top
				# of the budget, as the rabbit's `r` is.
				_place_kept(at, &"spider")
			"creature":
				# A creature by name (`place N: name`, 2026-10-08).
				var named := _place_named(at, String(entry["name"]), ceiling - spent)
				if named > 0:
					spent += named
			"(":
				# A sack, placed rather than rolled. The sack decides its own
				# contents when opened -- see _open_sack -- so an author is
				# choosing "something worth carrying is here", not choosing what
				# it is. That keeps a hand-drawn room from handing out a
				# specific prize the tables would never have given it.
				_drop_item_at(Item.make(&"sack"), at)

## CREATURES BY NAME (2026-10-08; tools/VAULTS_GAME_SIDE.md part 2). The
## vault's author chose the kind; the game still decides whether it can be
## met here and whether the room can afford it:
## - only where the ordinary roll could meet it: effective depth at least
##   its `min_depth`, and an `ascent_from` creature only on the climb from
##   that floor;
## - a WILD animal on top of the budget, like `r` (a wolf brings its pack);
## - a MONSTER spends the vault's budget like `m`, and is left out when its
##   threat is more than is left -- under-populated, never over.
## No draws beyond what _place_pick makes for its gear. Returns the threat
## spent (0 for an animal, or for nothing placed).
func _place_named(at: Vector2i, called: String, remaining: int) -> int:
	var row: Dictionary = {}
	for e in BESTIARY:
		if String(e["name"]) == called:
			row = e
			break
	if row.is_empty():
		return 0
	var here := effective_depth()
	if int(row["min_depth"]) > here:
		return 0
	if row.has("ascent_from") and (not ascending or here < int(row["ascent_from"])):
		return 0
	if not _can_rest_on(at.x, at.y) or entity_at(at.x, at.y) != null:
		return 0
	if at == stairs or at == Vector2i(player.x, player.y):
		return 0
	if row.get("wild", false):
		_place_pick(at, row, -1, WILD_UNPRICED)
		return 0
	if int(row["threat"]) > remaining:
		return 0
	return _place_pick(at, row, here, remaining)

## One creature of a named kind at a vault cell, if the cell will take it.
## The kind is the author's choice, not a roll: no draw on any stream.
func _place_kept(at: Vector2i, app: StringName) -> void:
	var row := _bestiary_row(app)
	if row.is_empty() or not _can_rest_on(at.x, at.y) or entity_at(at.x, at.y) != null:
		return
	if at == stairs or at == Vector2i(player.x, player.y):
		return
	_place_pick(at, row, -1, WILD_UNPRICED)

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

func _roll_monster(remaining: int, tier: int = -1, wild_only := false) -> Dictionary:
	var pool := []
	var total := 0.0
	# Past the deepest tier the fade stops advancing, so the heaviest monsters
	# stay at full weight instead of everything vanishing.
	var here := effective_depth() if tier < 0 else tier
	var effective := mini(here, deepest_tier() + TIER_GRACE)
	for e in BESTIARY:
		if e["min_depth"] > here:
			continue
		# AN ANIMAL IS NOT WHAT THE CEILING BUYS (2026-10-05). The bat, the
		# bear and the rabbit are nobody's enemy until struck, so their
		# threat in the hostile budget was danger the floor did not have:
		# measured the morning after they went WILD, floors 2-6 carried a
		# fifth to a third less than the ceiling arithmetic promised. The
		# budget rolls enemies only; the wild come on top, by _place_fauna.
		if bool(e.get("wild", false)) != wild_only:
			continue
		# WHERE A THING LIVES (Brad, 2026-10-05): a row that names its bands
		# is a floor feature, on the floor or not by _roll_the_wild and set
		# down by _place_the_wild -- never a share of this roll.
		if e.has("bands"):
			continue
		# NOT IN THESE BANDS, by the ordinary roll (Brad, 2026-10-07): a wild
		# thing that has no business there. The rabbit keeps out of both
		# fortresses -- wild animals learned to avoid walls and garrisons --
		# and comes into one only as the garrison's own, in a warren vault
		# (the `r` marker). Unlike `bands`, the rest of its floors are left
		# exactly as they were: the caves keep every rabbit they had.
		if e.has("not_in") and (e["not_in"] as Array).has(Bands.NAMES[Bands.of(here)]):
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
## `s` since the satchel (2026-10-01): it closes the satchel's chooser.
const RESERVED_LETTERS := "ifs"
## The pool, with the reserved letters left out. Old saves are re-lettered
## on load (_relabel_unreachable_items).
const LETTERS := "abcdeghjklmnopqrtuvwxyz"

## Adds an item to the pack with a stable letter.
##
## Persistent letters matter more than they look. Once the inventory is sorted
## or filtered, a letter derived from screen position would change every time
## you picked something up -- so "quaff b", typed from muscle memory, would
## drink the wrong thing. The letter belongs to the item, not to the row.
##
## LIKE KINDS STACK (2026-10-03): a potion joining a stack of its own kind takes
## no slot and no letter, so a full pack still takes one more of what it holds.
func give_item(item: Item) -> bool:
	var stack := _stack_for(item)
	if stack != null:
		stack.absorb(item)
		return true
	if player.pack_count() >= Entity.INVENTORY_MAX:
		return false
	item.letter = _free_letter()
	player.inventory.append(item)
	if item.is_satchel():
		_fill_the_satchel(item)
	return true

## TAKING THE SATCHEL FILLS IT (Brad, 2026-10-03): by whatever route it
## arrives -- the cave floor, a chest -- everything in the pack that fits a
## shelf moves in, ten of each, and the log lists what moved. A player who
## reaches floor four has a pack full of exactly what it is for; without
## this the old potions sat in the pack while new ones went to the bag.
func _fill_the_satchel(bag: Item) -> void:
	var moved: Array[String] = []
	for it in player.inventory.duplicate():
		if it == bag or not bag.satchel_kind(it):
			continue
		var shelf: Item = null
		for row in bag.contents:
			if row.same_kind_as(it):
				shelf = row
				break
		var room: int = bag.holds - (shelf.count if shelf != null else 0)
		var n := mini(it.count, room)
		if n <= 0:
			continue
		# Whole, the thing itself moves; part of a stack, a piece splits off.
		var piece: Item = it
		if n == it.count:
			player.inventory.erase(it)
			it.letter = ""
		else:
			piece = it.split_one()
			piece.count = n
			it.count -= n
		if shelf != null:
			shelf.absorb(piece)
		else:
			bag.contents.append(piece)
		moved.append(piece.name if n == 1 else "%s x%d" % [piece.name, n])
	if not moved.is_empty():
		msg_log.add("Your food and potions go into the satchel: %s." % ", ".join(moved),
			Color(0.75, 0.80, 0.90))

## Whether the key could take this off the floor: a satchel shelf for it, a
## stack it joins, or a free slot. The one test the key and the HERE box share
## (day-7 hunt, 2026-10-04: they had drifted apart).
func _can_take(item: Item) -> bool:
	var bag := _the_satchel()
	if bag != null and bag.satchel_takes(item):
		return true
	if _stack_for(item) != null:
		return true
	return player.pack_count() < Entity.INVENTORY_MAX

## The stack in the pack this would join, with room, or null. What you are
## wearing is a single thing and never a stack: a plain dagger picked up
## while one is in hand goes to its own slot.
func _stack_for(item: Item) -> Item:
	for it in player.inventory:
		if it.stacks_with(item) and not player.is_equipped(it):
			return it
	return null

## The first letter of the pool nothing in the pack is using.
func _free_letter() -> String:
	var used := {}
	for it in player.inventory:
		used[it.letter] = true
	# The whole pool, not the first INVENTORY_MAX of it. Iterating to the pack
	# size only worked while the pool was the alphabet and comfortably longer.
	for i in LETTERS.length():
		var ch := LETTERS[i]
		if not used.has(ch):
			return ch
	return ""

## Spends ONE of `it`: off the stack if it is one, out of the pack if it is the
## last. Returns the unit spent -- the item itself when it left the pack, a
## split copy when the stack stays -- letterless either way, for the ground or
## the air. The one way anything leaves the pack a unit at a time.
func _spend_one(it: Item) -> Item:
	if it.count > 1:
		it.count -= 1
		return it.split_one()
	if player.is_equipped(it):
		player.equipped.erase(it.slot)
	player.inventory.erase(it)
	it.letter = ""
	return it

## Re-letters anything a suspended run is carrying under a key that cannot be
## pressed.
##
## Saves written before "i" and "f" were reserved can hold an item nobody can
## reach, and reloading is exactly the moment to put that right -- the run in
## which this was found had its last potion stuck that way. Also catches
## duplicates and blanks, which nothing produced but nothing prevented either.
## A pack from before things stacked, or one written straight into the list
## by a save, holds its daggers one to a slot (Brad, 2026-10-03, resuming a
## run: three plain daggers in three rows). Folds like things together on
## load, first one keeping its letter; worn gear is left as it is.
func _stack_the_pack() -> void:
	var kept: Array = []
	for it in player.inventory:
		var home: Item = null
		if not player.is_equipped(it):
			for k in kept:
				if k.stacks_with(it) and not player.is_equipped(k):
					home = k
					break
		if home != null:
			home.absorb(it)
		else:
			kept.append(it)
	player.inventory.clear()
	for k in kept:
		player.inventory.append(k)
	# And the satchel's shelves, which were slots before 2026-10-03.
	for k in kept:
		if not k.is_satchel():
			continue
		var rows: Array = []
		for it in k.contents:
			var shelf: Item = null
			for r in rows:
				if r.same_kind_as(it):
					shelf = r
					break
			if shelf != null:
				shelf.absorb(it)
			else:
				rows.append(it)
		k.contents = rows

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
		# A casting flare: a short, bright burst on the shooter's square.
		if e.flare_until >= turns:
			sources.append(LightSource.new(e.x, e.y, 2,
				Color(1.00, 0.78, 0.50), Color(0.40, 0.26, 0.20), 1.2, false))
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
		if not e.alive or not _fair_game(e):
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
	return Los.clear_both(map, player.x, player.y, cell.x, cell.y)

## Every cell a shot or a throw of this reach could land on: the answer to
## "how far can I shoot" drawn on the floor while aiming. Asked of can_reach
## cell by cell, so the picture can never disagree with the shot -- Brad, on
## the diamond view: "I'm used to counting squares".
func reach_cells(reach: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if reach <= 1:
		return out
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			if dx == 0 and dy == 0:
				continue
			var cell := Vector2i(player.x + dx, player.y + dy)
			if map.in_bounds(cell.x, cell.y) and can_reach(cell, reach):
				out.append(cell)
	return out

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
	# A shot at the wrong fungus: fire burns it from range; nothing else does.
	if target == null and Tiles.is_bad_fungus(map.get_tile(cell.x, cell.y)):
		var sling: Item = player.equipped.get(Item.Slot.WEAPON, null)
		if sling == null or sling.element != &"fire":
			msg_log.add("Only fire will touch it.", Color(0.7, 0.6, 0.4))
			return false
		if sling.uses_ammo():
			if sling.ammo <= 0:
				msg_log.add("The %s is empty." % sling.name, Color(0.9, 0.6, 0.35))
				return false
			sling.ammo -= 1
		_travel.clear()
		_burn_fungus(cell)
		msg_log.add("Your shot burns the fungus away.", Color(0.96, 0.66, 0.36))
		_end_player_turn()
		return true
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
	if not _fair_game(target):
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
	# The gem of the boss wants no target: it is thrown AT A PLACE.
	if item.kind == Item.Kind.GEM and item.element == &"bash":
		return _throw_the_boss(index, cell)
	# So does the gem of frost: the room it shatters in.
	if item.kind == Item.Kind.GEM and item.element == &"frost":
		return _freeze_the_room(index, cell)

	var target := entity_at(cell.x, cell.y)
	if target == null or target.is_player:
		msg_log.add("There is nothing there to throw at.", Color(0.7, 0.6, 0.4))
		return false
	# Same rule as player_fire, and refused here for the same reason: a thrown
	# item killed the trader on 25 of 25 attempts. Checked BEFORE the item
	# leaves the inventory, so declining the throw does not also cost the thing
	# you were going to throw.
	if not _fair_game(target):
		msg_log.add("The %s is not your enemy." % target.name,
			Color(0.7, 0.6, 0.4))
		return false

	_travel.clear()
	item = _spend_one(item)

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

## THE GEM OF THE BOSS IS A DECOY (6d, 2026-09-30). Thrown at any square in
## reach, it shatters with a crash louder than a wail: sleepers wake and turn
## to the spot, the blind risen go to it, and anything hunting you that has
## lost sight of you goes there instead. The gem is gone. Loud enough to
## rouse a grave (GRAVE_ROUSING) -- a crash beside a headstone wakes what is
## under it, as every loud thing does.
const BOSS_CRASH := 10

func _throw_the_boss(index: int, cell: Vector2i) -> bool:
	var gem: Item = _spend_one(player.inventory[index])
	_travel.clear()
	msg_log.add("You hurl the %s. It shatters with a crash that rings through the stone."
		% gem.name, Color(0.85, 0.88, 0.68))
	# Hunters that have lost you go to the crash. _make_noise only turns the
	# unaware; an awake thing keeps hunting its last sight of you, and the
	# decoy's whole use is to hand it a false one.
	var fooled := 0
	for e in entities:
		if e.is_player or not e.alive or e.alertness != Entity.Alert.AWAKE \
				or e.faction == Entity.Faction.RISEN or e.lost_turns == 0:
			continue
		if Los.steps(e.x, e.y, cell.x, cell.y) > BOSS_CRASH:
			continue
		e.last_seen = cell
		fooled += 1
	_make_noise(cell, BOSS_CRASH, &"crash")
	if fooled > 0:
		msg_log.add("%d thing%s hunting you go%s to the sound instead."
			% [fooled, "" if fooled == 1 else "s", "es" if fooled == 1 else ""],
			Color(0.95, 0.70, 0.40))
	_end_player_turn()
	return true

## THE GEM OF THE MIRROR NAMES A SHRINE (6d). Held to an unfamiliar shrine
## you stand on, it shows the shrine for what it is -- and so every shrine of
## that colour this run. Which colour is the gong is the knowledge that frees
## the risen or ends a run; this buys it without the prayer.
func mirror_target() -> int:
	var here := Vector2i(player.x, player.y)
	if map.get_tile(here.x, here.y) != Tiles.SHRINE:
		return -1
	var kind := int(shrine_at.get(here, -1))
	if kind < 0 or shrine_known.has(kind):
		return -1
	return kind

func _show_the_shrine(gem: Item) -> bool:
	if map.get_tile(player.x, player.y) != Tiles.SHRINE:
		msg_log.add("The mirror shows nothing here. Stand on a shrine.", Color(0.7, 0.6, 0.4))
		return false
	var kind := mirror_target()
	if kind < 0:
		msg_log.add("You already know this one for what it is.", Color(0.7, 0.6, 0.4))
		return false
	shrine_known[kind] = true
	msg_log.add("You hold the %s to the shrine. It shows itself: the %s."
		% [gem.name, Shrines.NAMES[kind]], shrine_hue(kind))
	return true

## THE GEM OF THE CRAG FILLS A PIT (6d). Crushed over a pit beside you, stone
## pours in and sets: the hole is floor. A path where there was none, and --
## when strand 5 teaches monsters to flee down them -- a bolt-hole closed.
## The pit you face first, if you face one; else the first found.
func crag_target() -> Vector2i:
	var ahead := Vector2i(player.x, player.y) + player.facing
	if map.in_bounds(ahead.x, ahead.y) and map.get_tile(ahead.x, ahead.y) == Tiles.PIT:
		return ahead
	for i in 8:
		var d := Entity.turned(Vector2i(0, -1), i)
		var c := Vector2i(player.x + d.x, player.y + d.y)
		if map.in_bounds(c.x, c.y) and map.get_tile(c.x, c.y) == Tiles.PIT:
			return c
	return Vector2i(-1, -1)

func _fill_the_pit(gem: Item) -> bool:
	var at := crag_target()
	if at.x < 0:
		msg_log.add("There is no pit beside you to fill.", Color(0.7, 0.6, 0.4))
		return false
	map.set_tile(at.x, at.y,
		Tiles.CAVE_FLOOR if map.material_at(at.x, at.y) == Materials.CAVERN else Tiles.FLOOR)
	# Pits are solid to the pathfinder (never routed through); floor is not.
	pathfinder.set_solid(at.x, at.y, false)
	events.append({"kind": &"notice", "to": at})
	msg_log.add("You crush the %s over the pit. Stone pours in and sets: the floor is whole."
		% gem.name, Color(0.80, 0.78, 0.70))
	return true

## THE GEM OF THE BULWARK BARS A DOOR (6d). Crushed against a door beside
## you -- open or shut, with nothing standing in it -- stone grows across it:
## a shut door nothing that OPENS doors can open. A bear still takes it off
## its hinges (_through_the_door), enough heaving breaks the bar
## (_pound_the_door, BAR_HOLDS), and your own hand lifts it (_unbar). Shuts a
## chase behind you, for a while, and loudly tells you how long.
func bulwark_target() -> Vector2i:
	var found := Vector2i(-1, -1)
	for i in 8:
		var d := Entity.turned(Vector2i(0, -1), i)
		var c := Vector2i(player.x + d.x, player.y + d.y)
		if not map.in_bounds(c.x, c.y):
			continue
		var t := map.get_tile(c.x, c.y)
		# A gate takes the bar as a door does (2026-10-09).
		if t != Tiles.DOOR_OPEN and t != Tiles.DOOR_CLOSED and not Tiles.is_gate(t):
			continue
		if entity_at(c.x, c.y) != null or not items_at(c.x, c.y).is_empty():
			continue
		if found.x < 0 or c == Vector2i(player.x, player.y) + player.facing:
			found = c
	return found

func _bar_the_door(gem: Item) -> bool:
	var at := bulwark_target()
	if at.x < 0:
		var any_door := false
		for i in 8:
			var d := Entity.turned(Vector2i(0, -1), i)
			var c := Vector2i(player.x + d.x, player.y + d.y)
			if map.in_bounds(c.x, c.y) and Tiles.is_doorway(map.get_tile(c.x, c.y)) \
					and map.get_tile(c.x, c.y) != Tiles.DOOR_BARRED:
				any_door = true
		msg_log.add("The doorway is not clear." if any_door
			else "There is no door beside you to bar.", Color(0.7, 0.6, 0.4))
		return false
	if Tiles.is_gate(map.get_tile(at.x, at.y)):
		barred_gates[at] = true
	map.set_tile(at.x, at.y, Tiles.DOOR_BARRED)
	barred[at] = BAR_HOLDS
	events.append({"kind": &"notice", "to": at})
	msg_log.add("You crush the %s against the door. Stone grows across it: barred, to all but a bear."
		% gem.name, Color(0.80, 0.78, 0.70))
	return true

## What a barred doorway is once the bar is off: an open gate if it was a
## gate, else an open door. Forgets the gate either way.
func _unbarred(at: Vector2i) -> int:
	return Tiles.GATE_OPEN if barred_gates.erase(at) else Tiles.DOOR_OPEN

## You lift the bar. The door is open and the bar is spent -- a gem's worth,
## so it is your choice to make.
func _unbar(at: Vector2i) -> void:
	map.set_tile(at.x, at.y, _unbarred(at))
	barred.erase(at)
	pathfinder.set_solid(at.x, at.y, false)
	_work_the_door(at, "You lift the bar and pull the door open.")

## Something that opens doors, at one it cannot: it heaves, loudly, and the
## bar loses one. At nothing left the door bangs open. The turn is spent.
func _pound_the_door(actor: Entity, at: Vector2i) -> bool:
	var left := int(barred.get(at, BAR_HOLDS)) - 1
	_make_noise(at, DOOR_NOISE, &"door")
	if left <= 0:
		map.set_tile(at.x, at.y, _unbarred(at))
		barred.erase(at)
		if map.is_visible(at.x, at.y):
			msg_log.add("The bar gives. The %s bangs the door open." % actor.name,
				Color(0.92, 0.66, 0.45))
		else:
			msg_log.add("Somewhere, a bar splinters and a door bangs open.",
				Color(0.78, 0.70, 0.60))
		return true
	barred[at] = left
	if map.is_visible(at.x, at.y):
		msg_log.add("The %s heaves at the barred door. It holds." % actor.name,
			Color(0.78, 0.74, 0.66))
	else:
		msg_log.add("Something pounds at a barred door.", Color(0.78, 0.70, 0.60))
	return true

## THE GEM OF FROST FREEZES THE ROOM (6d, Brad's design). Thrown into a room
## or cave, it shatters and the cold takes the place: everything standing in
## it is frozen -- it neither acts nor hears, and can be hit without hitting
## back -- and no sound made inside carries, for the room's longer side less
## one per door (his rule (a); FREEZE_MIN..FREEZE_MAX). A 10x10 room with two
## doors gives 8: "if the math is right, a near miss" -- enough to cross a
## small room past its risen, not enough to dawdle. You are never frozen by
## your own stone; your ally is, if it stood there.
func _freeze_the_room(index: int, cell: Vector2i) -> bool:
	var gem: Item = _spend_one(player.inventory[index])
	_travel.clear()
	var region := _region_at(cell)
	var held := clampi(maxi(region.size.x, region.size.y) - _doors_of(region),
		FREEZE_MIN, FREEZE_MAX)
	frozen_rooms.append([region, turns + held])
	var caught := 0
	for e in entities:
		if e.is_player or not e.alive or not region.has_point(Vector2i(e.x, e.y)):
			continue
		e.frozen = held
		caught += 1
	events.append({"kind": &"notice", "to": cell})
	msg_log.add("You hurl the %s. It shatters, and the cold takes the room: %d thing%s frozen, no sound carrying, for %d turns."
		% [gem.name, caught, "" if caught == 1 else "s", held], Color(0.70, 0.85, 0.95))
	_end_player_turn()
	return true

## The room, vault or cave a cell is in; failing all three, a patch of
## corridor round it.
func _region_at(cell: Vector2i) -> Rect2i:
	for room in room_rects:
		if room.has_point(cell):
			return room
	for vr in vault_rects:
		if vr.has_point(cell):
			return vr
	for cave in cave_regions:
		if cave.has_point(cell):
			return cave
	return Rect2i(cell - Vector2i(2, 2), Vector2i(5, 5))

## The doors in the ring of wall round a region.
func _doors_of(region: Rect2i) -> int:
	var count := 0
	var ring := region.grow(1)
	for y in range(ring.position.y, ring.end.y):
		for x in range(ring.position.x, ring.end.x):
			if region.has_point(Vector2i(x, y)) or not map.in_bounds(x, y):
				continue
			var t := map.get_tile(x, y)
			if Tiles.is_doorway(t):
				count += 1
	return count

## Whether a frozen room still swallows sound made at this cell.
func _muffled(at: Vector2i) -> bool:
	for fr in frozen_rooms:
		if turns < int(fr[1]) and (fr[0] as Rect2i).has_point(at):
			return true
	return false

## Rooms whose cold has run out are forgotten, each turn -- and what stands
## frozen thaws by one, on YOUR turn, not its own (Brad, 2026-10-04). Counted
## on its own turns, a speed-170 thing frozen "for 8" moved again after five
## of yours and a slow one outlived the room's silence: the count over its
## head was true only at speed 100. Now room and creature end together.
func _thaw_rooms() -> void:
	frozen_rooms = frozen_rooms.filter(func(fr): return turns < int(fr[1]))
	for e in entities:
		if e.frozen > 0:
			e.frozen -= 1

## THE GEM OF RETURNING RECALLS YOU (6d). Crushed beside a brazier -- lit,
## spent or cold; a fire is a landmark -- it marks it. A second, crushed
## anywhere on the floor, steps you back beside the mark. Two gems for one
## escape keeps it rare; the mark is this floor's only (the dungeon is one-way).
## What the gem would do now: &"mark", &"return", &"here" (beside the mark
## already) or &"" (nothing).
func return_target() -> StringName:
	if recall_mark.x >= 0:
		if maxi(absi(player.x - recall_mark.x), absi(player.y - recall_mark.y)) <= 1:
			return &"here"
		return &"return"
	if _adjacent_any_brazier().x >= 0:
		return &"mark"
	return &""

func _recall(gem: Item) -> bool:
	match return_target():
		&"mark":
			recall_mark = _adjacent_any_brazier()
			events.append({"kind": &"notice", "to": recall_mark})
			msg_log.add("You crush the %s at the brazier. The fire will remember you: a second stone, crushed anywhere, brings you back here."
				% gem.name, Color(0.80, 0.85, 0.70))
			return true
		&"return":
			var spot := _recall_spot(recall_mark)
			if spot.x < 0:
				msg_log.add("There is no room by the fire to return to.", Color(0.7, 0.6, 0.4))
				return false
			var from := Vector2i(player.x, player.y)
			player.x = spot.x
			player.y = spot.y
			events.append({"kind": &"blink", "from": from, "to": spot})
			msg_log.add("You crush the %s. The floor folds under you, and you stand at the fire again."
				% gem.name, Color(0.75, 0.70, 0.95))
			recall_mark = Vector2i(-1, -1)
			return true
		&"here":
			msg_log.add("You are at the fire already.", Color(0.7, 0.6, 0.4))
			return false
	msg_log.add("Crush it beside a brazier first: the fire remembers you, and a second stone brings you back.",
		Color(0.7, 0.6, 0.4))
	return false

## The nearest square beside the mark you can stand on: walkable, nothing
## avoided, and nothing already standing there (_nearest_restable does not
## ask the last, and arriving inside a kobold is not an escape).
func _recall_spot(mark: Vector2i) -> Vector2i:
	for radius in range(1, 4):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if maxi(absi(dx), absi(dy)) != radius:
					continue
				var c := mark + Vector2i(dx, dy)
				if map.in_bounds(c.x, c.y) and _can_land_on(c.x, c.y)						and entity_at(c.x, c.y) == null:
					return c
	return Vector2i(-1, -1)

## THE GEM OF THE ROAD SHOWS THE WAY OUT (6d). Crushed anywhere, the route
## from you to the stairs is drawn on the map for the rest of the floor, and
## the stairs with it, seen or not -- the route-choosing play the red brought
## on, answered by the one gem you have to explore to find.
func _show_the_road(gem: Item) -> bool:
	if road_shown:
		msg_log.add("The way out is already shown.", Color(0.7, 0.6, 0.4))
		return false
	road_shown = true
	_road_cache.clear()
	map.explored[map.idx(stairs.x, stairs.y)] = 1
	events.append({"kind": &"notice", "to": stairs})
	msg_log.add("You crush the %s. A line of light runs out along the floor, away towards the stairs."
		% gem.name, Color(0.95, 0.90, 0.60))
	return true

## The route the road shows: from you to the stairs, worked out again only
## when the turn or your square has changed. Empty until the gem is crushed.
## Round the traps you have FOUND, but straight through purple and red: the
## gem has no idea of fungus dangers (Brad, 2026-10-04), so it can draw a line
## your own travel would refuse -- reading the ground is still yours.
func road_route() -> Array:
	if not road_shown:
		return []
	var key := [turns, player.x, player.y]
	if _road_cache.get("key", null) != key:
		_road_cache["key"] = key
		_road_cache["route"] = Array(pathfinder.path(Vector2i(player.x, player.y), stairs,
			false, true))
	return _road_cache["route"]

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
## Is there anything in sight that should stop the player being carried along?
##
## Hostiles in view stop anything acting on the player's behalf. A direct click
## still takes its one requested step; only the queued part of the route stops.
## This keeps a player from walking several squares into a patroller's path.
func threat_in_view() -> bool:
	return not _travel_stoppers().is_empty()

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

## A haunch of anything: what the hunters eat and the slime dissolves.
static func _is_meat(it: Item) -> bool:
	return it.id == &"meat" or it.id == &"bear_meat" or it.id == &"wolf_meat"

## Is anything alive on this floor that would eat meat left lying? Only the
## HUNGRY count (2026-10-07, the desktop's review): a fed eater leaves meat
## be (_hunt), and a warning about it would cry wolf.
func _eaters_about() -> bool:
	for e in entities:
		if e.alive and not e.is_player and e.is_hungry() and e.faction != Entity.Faction.PLAYER:
			return true
	return false

## What the cursor reads over a body still there to see: "a rabbit's body,
## torn by a wolf" -- and what the red has made of it. Empty when no body
## shows at the cell (rotted away, or the cell unseen).
func body_lines_at(c: Vector2i) -> Array:
	var out := []
	if not map.is_visible(c.x, c.y):
		return out
	for b in bodies:
		if int(b["x"]) != c.x or int(b["y"]) != c.y:
			continue
		if not BodyLook.showing(turns - int(b["turn"])):
			continue
		var who := String(b["e"].get("name", b["app"]))
		var line := "%s's body" % who
		var by := String(b.get("killed_by", ""))
		if by != "":
			line += ", " + by
		out.append(line)
		if bool(b.get("claimed", false)):
			out.append("  the red has it: it will rise")
	return out

## The WILD in sight that are not yet your enemy: listed by the sidebar,
## shootable, and nothing else -- they stop no journey and forbid no rest.
func visible_wild() -> Array:
	var out := []
	for e in entities:
		if e.alive and e.is_wild() and not e.hostile_to(player) \
				and map.is_visible(e.x, e.y):
			out.append(e)
	return out

## What you may shoot, throw at or walk into: your enemies, and the wild --
## hunting a rabbit with a bow is the oldest loop in the game, and a bear
## has to be provokable from a distance (2026-10-04). The trader and your
## allies stay refused, through hostile_to.
func _fair_game(e: Entity) -> bool:
	return e.hostile_to(player) or e.is_wild()

# ---------------------------------------------------------- player turn ----

## Every one of these returns true if game time actually passed. Returning
## false for a bumped wall is what stops the world taking a free turn while
## the player fumbles at a dead end.

func player_move(dx: int, dy: int) -> bool:
	if game_over:
		return false
	_travel.clear()
	# Toward whatever you stepped at or swung at. See Entity.facing.
	if dx != 0 or dy != 0:
		player.facing = Vector2i(signi(dx), signi(dy))
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
	# Not with a WILD thing, which is not your enemy either: walking into a
	# bear is how you pick the fight, and you do not trade places with it.
	if target != null and target != player and not target.hostile_to(player) \
			and not target.is_wild():
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
		# PICKING A FIGHT WITH A WILD THING IS DELIBERATE (the floor-1 bear,
		# 2026-10-05). An animal that has done nothing to you costs no turn
		# on the first bump and says what it is; the same move again, with
		# nothing in between, is the attack. A new player on floor 1 with
		# 30 hp who walks into a bear by mistake would otherwise be dead in
		# three of its hits. A rabbit is never worth the warning (power 0),
		# and a provoked animal is your enemy already and gets none.
		# TAMING (Brad's design 2026-10-05; built 2026-10-06). With the price
		# in your pack -- haunches to the pack's count, or a knucklebone -- the
		# first move into a tameable animal OFFERS instead of warning, and the
		# same move again pays and turns the pack. To fight one while carrying
		# the price, shoot or throw. Without the price, the warning names it.
		if _tameable(target) and _can_tame(target):
			if _meant != target:
				_meant = target
				msg_log.add(_tame_offer(target), Color(0.95, 0.72, 0.45))
				return false
			return _tame(target)
		if target.is_wild() and not target.hostile_to(player) and target.power > 0 \
				and _meant != target:
			_meant = target
			msg_log.add("That is a %s, and it has done nothing to you. Move into it again to pick the fight."
				% target.name, Color(0.95, 0.72, 0.45))
			# Its own line: the log panel holds about 95 characters, and a
			# second sentence on the warning ran off its right edge.
			if _tameable(target):
				msg_log.add("%d haunches, or a knucklebone, would tame the pack instead."
					% _tame_price(target), Color(0.95, 0.72, 0.45))
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
	# A LATCHED GATE: you lift the latch. Wearing the ring you are a rat, and
	# a rat is exactly what the gate is for -- it stops you, and says why.
	if map.get_tile(nx, ny) == Tiles.GATE_CLOSED:
		if ratted():
			msg_log.add("A latched gate. A rat cannot work a latch, and there is no gap under it.",
				Color(0.7, 0.6, 0.4))
			return false
		map.set_tile(nx, ny, Tiles.GATE_OPEN)
		_set_gate_route(Vector2i(nx, ny))
		_work_the_door(Vector2i(nx, ny), "You lift the latch and swing the gate open.")
		return true
	if map.get_tile(nx, ny) == Tiles.DOOR_BARRED and not ratted():
		_unbar(Vector2i(nx, ny))
		return true

	if not can_step(player.x, player.y, nx, ny):
		return false

	if map.get_tile(nx, ny) == Tiles.PIT:
		return _fall_into_pit()

	if hidden_traps.has(Vector2i(nx, ny)):
		hidden_traps.erase(Vector2i(nx, ny))
		msg_log.add("The floor clicks under your foot.", Color(0.92, 0.48, 0.40))
		_spring_trap(nx, ny)
		if not player.alive:
			return true
	elif map.get_tile(nx, ny) == Tiles.TRAP:
		# A trap you have FOUND is stepped over, slowly, and stays armed. The
		# alternative is G: disarm it (2026-10-02; before, walking onto a
		# found trap sprang it, which made spotting one worth nothing in a
		# corridor).
		msg_log.add("You step carefully over the trap.", Color(0.95, 0.80, 0.45))
		player.x = nx
		player.y = ny
		_end_player_turn(move_cost_for(player, nx, ny) * TRAP_STEP_OVER)
		return true

	var cost := move_cost_for(player, nx, ny)
	player.x = nx
	player.y = ny
	_end_player_turn(cost)
	return true

## THE BODIES OF THE DEAD, lying where they fell. The first strand of the Dwarf
## Fortress plan (BACKLOG): later strands seed fungus on them and raise them.
## Each is {x, y, app, turn, corrupted, e} -- `e` the whole creature as the
## save writes it, taken before its loot dropped, so what grows from a body or
## rises out of it later is the thing that died, wearing what it wore.
##
## They rot over BODY_ROT turns and are gone. One floor only, like everything
## off-screen here: a new floor starts with none.
var bodies: Array = []
const BODY_ROT := 120

## THE WRONG FUNGUS (Dwarf Fortress plan, strand 2, 2026-09-29).
## A rat, bat or rabbit passing next to a body carries spores to it; ROOT turns
## later the body is gone and purple or red fungus stands where it lay -- never
## green (Brad: eating a fungus grown from a kill is not fun to think about).
const FUNGUS_ROOT := 15
## Red crawls one square toward the nearest body in reach every CRAWL_EVERY
## turns, a chain you can see and cut; reaching the body CLAIMS it (strand 4
## raises it). So how long a body takes to rise is how far away the red was.
const CRAWL_EVERY := 3
const CRAWL_REACH := 8
## No wrong fungus grows within this of a LIT brazier: fire keeps it off. One
## square: at two it turned most room beds green, doubling the green share of
## the climb (measured 2026-09-29) -- Brad asked for braziers to protect only
## their own ground.
const FIRE_SAFE := 1
## Standing on it hurts: poison more than blood.
const PURPLE_HURT := 2
const RED_HURT := 1
## A torch scorches it away in this many bumps; a fire weapon, in one.
const TORCH_SCORCHES := 3
## A floor can only hold so much crawling red; past this it stops spreading.
const RED_CAP := 60
## Who carries spores from a body.
const SPORE_CARRIERS := [&"rat", &"bat", &"rabbit", &"slime"]
## A marked creature, awake and on plain floor, leaves its fungus behind it on
## this share of its turns: a trail you can read. Brad: 5 was his first
## thought, 3 to start cautious. Capped per colour, so it never runs away.
const TRAIL_CHANCE := 0.03
const PURPLE_CAP := 60
## How far a rat smells a fresh body.
const RAT_NOSE := 8
## THE MIASMA (Dwarf Fortress plan, strand 3; Brad chose poison over time,
## 2026-09-30). Every purple fungus breathes a cloud over itself and the eight
## squares round it. Breathing it poisons: POISON_HURT a turn, lasting
## POISON_LINGER turns after you leave. It is AIR -- flyers breathe it too.
const POISON_HURT := 1
## Five since 2026-10-05 (three before): with drip pools in most caves, a
## two-step walk to water now saves three points instead of one, and the
## HERE box's "water washes it off" is worth acting on. The purple is the
## red's counterweight; a little deadlier is the role.
const POISON_LINGER := 5
## THE RED RAISES THE DEAD (strand 4; Brad's numbers, 2026-09-30). A claimed
## body rises RISE_BASE + its max hp turns after the red takes it -- a rat in 8,
## a young dragon in 59, time to burn it or to hide. It gets up at half its hp
## and hitting RISEN_HITS as hard, hostile to everything with a side, and it
## never leaves the room it rose in (RISEN_REACH squares round the spot in caves
## and corridors) until the gong calls it. Its second death is its last.
const RISE_BASE := 4
const RISEN_HITS := 1.5
const RISEN_REACH := 4
## The log says a body is stirring this many turns before it gets up.
const RISE_WARNING := 3
## THE RISEN ARE BLIND (Brad, 2026-09-30: sound over sight, The Last of Us's
## clickers). They find you by what they hear: any noise whose ring reaches
## them, and footsteps this close. Rats make none -- they are the red's own
## carriers -- and neither does a ring-rat, until noise gives it away. A risen
## SKELETON keeps its eyes, and the dead are not fooled by the ring.
const RISEN_HEARING := 3

## Every square in a purple cloud, as a set, for the views to tint -- worked
## out once a turn (or when fungus changes), not per square per frame. Brad,
## 2026-09-30: the cloud was invisible past the fungus square, so he walked
## into it thinking the squares round it were safe.
var _cloud := {}
var _cloud_turn := -1

func miasma_cloud() -> Dictionary:
	if _cloud_turn == turns:
		return _cloud
	_cloud_turn = turns
	_cloud = {}
	for y in map.height:
		for x in map.width:
			if map.get_tile(x, y) != Tiles.FUNGUS_PURPLE:
				continue
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					_cloud[Vector2i(x + dx, y + dy)] = true
	return _cloud

## In the purple's cloud: on a purple square or beside one.
func in_miasma(x: int, y: int) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if map.get_tile(x + dx, y + dy) == Tiles.FUNGUS_PURPLE:
				return true
	return false

## WATER CLEANSES (Brad, from play, 2026-10-01). One rule a player can hold:
## anything LIVING that stands in water loses the spores it carries -- the
## mark's ring goes, its body will not be claimed -- and the purple's poison
## ends at once. The cloud itself is untouched: stand beside purple in a pool
## and you breathe it again (this runs BEFORE `_breathe`, so that is what
## happens). The red already cannot grow onto water (`_fungus_can_grow`), so
## a pool is a firebreak the player can read, and now a place to RUN TO: wash
## before you die so the red cannot have you; break a rat's carrying of
## spores across the floor. The trade is the noise wading makes
## (Tiles.WADING_NOISE): the blind risen hear the splash.
##
## A risen washes no SPORES: it is a dead thing and the red has it, whichever
## way it got up (`fungal` from the red, `risen` from a grave). Poison and
## acid are another matter (2026-10-05, allies washing themselves): every
## ally you can have is risen, and the miasma kills them as it kills the
## living, so the water takes the poison off anything that wades, dead or
## not. The red keeps its claim; the pool keeps your bear.
##
## Underfoot each turn rather than on each kind of step: a swap, a knockback,
## a fall and every walker's own step all land here, in one place.
func _wash(e: Entity) -> void:
	if not e.alive or e.flying or map.get_tile(e.x, e.y) != Tiles.WATER:
		return
	var dead := e.fungal or e.risen
	var had := "" if dead else String(e.spores)
	var hurting := e.poisoned > 0 or e.acid_turns > 0
	if had == "" and not hurting:
		return
	var burning := e.acid_turns > 0
	if not dead:
		e.spores = &""
	e.poisoned = 0
	e.acid_turns = 0
	if e.is_player:
		msg_log.add("The water washes the %s off you." % ("acid" if burning else "poison"),
			Color(0.62, 0.78, 0.90))
	elif map.is_visible(e.x, e.y) and had != "":
		msg_log.add("The water takes the %s off the %s." % [had, e.name],
			Color(0.62, 0.78, 0.90))
	elif map.is_visible(e.x, e.y) and hurting and e.faction == Entity.Faction.PLAYER:
		msg_log.add("The water washes the %s off %s." % ["acid" if burning else "poison",
			_called(e, false)], Color(0.62, 0.78, 0.90))

## ACID (the slime, 2026-10-05): a slime's hit clings and eats for a few
## turns; water washes it off (_wash). Not the miasma's poison: a rabbit
## breathes the purple unharmed and is eaten by acid like anything else,
## and the log says "acid" where it means it.
const ACID_HURT := 1
const ACID_LINGER := 3

## One turn of acid on a creature. True if it killed.
func _acid_bites(e: Entity) -> bool:
	if e.acid_turns <= 0:
		return false
	e.take_damage(ACID_HURT)
	e.acid_turns -= 1
	if e.is_player:
		_tally("taken", ACID_HURT)
		if e.acid_turns == 0 and e.alive:
			msg_log.add("The acid is spent.", Color(0.70, 0.78, 0.70))
	return not e.alive

## One turn of air for a creature: the cloud poisons (or re-poisons), and the
## poison bites. True if it killed.
func _breathe(e: Entity) -> bool:
	# A rabbit lives on fungus and the purple's air does nothing to it (Brad,
	# 2026-10-01: that is why its meat can be the cure, when brewing comes).
	# Found in play: a rabbit asleep beside the purple was dead in four turns.
	if e.ai == &"forager" or e.appearance == &"rabbit" or e.appearance == &"killer_rabbit":
		return false
	if in_miasma(e.x, e.y):
		if e.is_player and e.poisoned == 0:
			msg_log.add("You breathe the purple miasma. You are poisoned.",
				Color(0.78, 0.60, 0.80))
		e.poisoned = POISON_LINGER
	if e.poisoned <= 0:
		return false
	e.take_damage(POISON_HURT)
	e.poisoned -= 1
	if e.is_player:
		_tally("taken", POISON_HURT)
		if e.poisoned == 0 and e.alive:
			msg_log.add("The poison passes.", Color(0.70, 0.78, 0.70))
	return not e.alive
## Its own stream: how many colour rolls a floor makes depends on how the
## fights go (CLAUDE.md -- anything whose draw count varies gets its own rng).
var fungus_rng := RandomNumberGenerator.new()
## HIDDEN TRAPS (the 2026-09-26 playtest: "if I can spot a trap I'll never
## step on it"; built 2026-10-01). Every trap starts hidden: its square is
## floor, routes as floor, and springs underfoot. Each turn you may SPOT one
## within SPOT_REACH that you can see -- SPOT_DARK a turn in the dark, plus
## SPOT_LIT times the light on its square, less a fifth per cell of distance;
## the trapwright's glass in the offhand adds half again. Spotted, it is the
## trap tile as before. Its own rng: how many rolls a turn makes depends on
## the floor (CLAUDE.md). Both saved.
var hidden_traps: Dictionary = {}
var trap_rng := RandomNumberGenerator.new()
## Animals deciding to drink (2026-10-06): its own stream, because how many
## draws a turn makes depends on how many animals are up, and on the main
## rng that would move every later roll -- the seed-pinned-premise bug
## (CLAUDE.md; caught in the desktop's review the same night). Saved.
var drink_rng := RandomNumberGenerator.new()
## Animals dozing off and waking (2026-10-07): its own stream for the same
## reason as drinking -- the draws a turn depend on how many animals are up.
## Saved.
var nap_rng := RandomNumberGenerator.new()
## Each eater's appetite on arrival (2026-10-07): its own stream, as the
## number of draws is the number of eaters on the floor. Saved.
var hunger_rng := RandomNumberGenerator.new()
const SPOT_REACH := 3
const SPOT_DARK := 0.12
const SPOT_LIT := 0.60
const SPOT_GLASS := 1.5
## Torch scorches landed so far, "x,y" -> count. One floor only.
var scorched: Dictionary = {}
## Turns spent feeding a low fire from the torch, "x,y" -> count. One floor
## only, like the scorches; saved beside them.
var tending: Dictionary = {}
## THE RED'S CHAINS. Each square the crawl grew, -> the square it grew from,
## so a chain that loses its body can die back the way it came. Generated and
## seeded red is a SOURCE: it has no entry and never withers. Saved.
var red_from: Dictionary = {}
## Chains dying back, each an array of squares, tip first; one square per
## crawl tick. Saved.
var withering: Array = []
## BURYING (Brad, 2026-10-01): the undertaker's shovel puts a claimed body
## under before it rises. BURY_SPADEFULS presses of G, each one LOUD -- the
## blind risen hear it -- so beside a red room it is a race. A burial costs
## time and noise; a raise costs a gem. A dull shovel still digs.
const BURY_SPADEFULS := 3
const DIG_NOISE := 6
## THE UNDERTAKER'S PAY (Gabe, 2026-10-01 -- "why didn't we think of that?").
## Every grave dug for the red's dead counts on the shovel; this many sharpen
## a dull one, so a raise is paid for by a gem OR by doing the undertaker's
## job. A sharp shovel's count waits, held at this, and sharpens it the moment
## it dulls -- one raise banked at most, as with the gem.
const BURIALS_TO_SHARPEN := 5

## BODIES SAY WHO KILLED THEM (Brad, 2026-10-05; built 2026-10-06). The
## phrase the cursor reads over a body: "torn by a wolf", "slain by you",
## "choked by the miasma". A rabbit's bare body with a wolf in the cave was
## the only tell that the wolf got there first; now the floor's history
## can be read from its dead without having been witnessed.
func _killed_by(victim: Entity, killer: Entity, cause: String) -> String:
	if cause != "":
		return cause
	if killer == victim or killer == null:
		return ""
	if killer.is_player:
		return "slain by you"
	var who := killer.name
	if killer.faction == Entity.Faction.PLAYER:
		who = "your %s" % killer.name
	elif killer.is_wild():
		return "torn by %s" % _a_or_an(who)
	elif killer.faction == Entity.Faction.RISEN:
		return "slain by %s" % _a_or_an(who)
	else:
		who = _a_or_an(who)
	return "slain by %s" % who

static func _a_or_an(name: String) -> String:
	if name.is_empty():
		return name
	return ("an %s" if name[0].to_lower() in ["a", "e", "i", "o", "u"] else "a %s") % name

func _lay_body(victim: Entity, killed_by := "") -> void:
	# A marked death takes its fungus with it. Purple: seeded as it falls, so
	# it rots into purple with no carrier needed. Red: red grows under it, and
	# if it is a body the red can raise, it is claimed on the spot.
	var at := Vector2i(victim.x, victim.y)
	var seeded := turns if victim.spores == &"purple" else -1
	var can_rise := _can_rise(victim)
	var red := victim.spores == &"red" and _red_can_hold(at)
	var claimed := red and can_rise
	bodies.append({"x": victim.x, "y": victim.y, "app": String(victim.appearance),
		"turn": turns, "corrupted": victim.corrupted, "e": victim.to_dict(),
		"seeded": seeded, "claimed": claimed, "still": not can_rise,
		"rises": turns + _hatch(victim.max_hp) if claimed else -1,
		"killed_by": killed_by})
	if red and map.get_tile(at.x, at.y) != Tiles.FUNGUS_RED and pathfinder != null:
		_set_fungus(at, Tiles.FUNGUS_RED)
	# Your bone ally fell in the red: say how long, and what stops it.
	if claimed and victim.appearance == &"bone_ally":
		msg_log.add("%s falls, and the red takes them. They will rise in %d turns."
			% [victim.name, _hatch(victim.max_hp)], Color(0.92, 0.40, 0.40))
		msg_log.add("Bury them with the shovel before they rise." if _has_shovel()
			else "Burn the body before they rise.", Color(0.88, 0.62, 0.50))

## Whether the red can raise this creature: the living, and skeletons (Brad,
## 2026-09-30: a red-risen skeleton is more zombie than not). Not the other
## undead or the golem -- nothing in them for it to grow in -- and nothing that
## has already come back once, from the red or from a grave.
func _can_rise(e: Entity) -> bool:
	if e.raised or e.risen or e.appearance == &"golem":
		return false
	# A grave's bone ally is a skeleton's frame under a hero's name, so it
	# rises like one (Brad, 2026-10-01: keep it -- and warn the player; see
	# _warn_of_red_allies). It is the one ally that can turn on you.
	return not e.unliving or e.appearance == &"skeleton" or e.appearance == &"bone_ally"

## Red already there, or ground it could grow on.
func _red_can_hold(c: Vector2i) -> bool:
	return map.get_tile(c.x, c.y) == Tiles.FUNGUS_RED or _fungus_can_grow(c)

## How long a claimed body takes to rise: the bigger, the longer.
func _hatch(max_hp: int) -> int:
	return RISE_BASE + max_hp

## True within FIRE_SAFE of a lit brazier, where no wrong fungus will grow.
func _near_fire(c: Vector2i) -> bool:
	for dy in range(-FIRE_SAFE, FIRE_SAFE + 1):
		for dx in range(-FIRE_SAFE, FIRE_SAFE + 1):
			if map.get_tile(c.x + dx, c.y + dy) == Tiles.BRAZIER:
				return true
	return false

## After generation: any purple or red that landed by a lit brazier grows
## green instead. No draws -- the floor decides it, so seeds do not move.
func _keep_the_fire_clean() -> void:
	for y in map.height:
		for x in map.width:
			if Tiles.is_bad_fungus(map.get_tile(x, y)) and _near_fire(Vector2i(x, y)):
				map.set_tile(x, y, Tiles.FUNGUS)

## Where wrong fungus may take hold: plain floor or MUD, away from fire.
## Mud since 2026-10-08 (Brad): fungus loves damp ground, and the red was
## stalling at the first band of mud between it and a body -- measured, it
## never moved -- with nothing on screen to say why. Water and fire stay the
## barriers. What was mud is remembered under the fungus (`mud_under`), and
## comes back when the fungus goes.
func _fungus_can_grow(c: Vector2i) -> bool:
	return _fungus_ground(c) and not _near_fire(c)

## Ground any fungus may grow on, green included: plain floor or mud.
func _fungus_ground(c: Vector2i) -> bool:
	var t := map.get_tile(c.x, c.y)
	return t == Tiles.FLOOR or t == Tiles.CAVE_FLOOR or t == Tiles.MUD

## MUD UNDER FUNGUS (2026-10-08). The map is one layer, so a fungus grown on
## mud replaces it; these are the fungus squares that were mud, so that
## eating, picking, burning or withering the fungus gives the mud back
## (_bare_ground) instead of leaving plain floor -- a garden bed stays a bed.
## While fungus covers it the square walks as fungus, not as mud. One floor
## only; saved.
var mud_under: Dictionary = {}

## Call just before fungus is set on `c`: remember it if it is mud.
func _note_mud(c: Vector2i) -> void:
	if map.get_tile(c.x, c.y) == Tiles.MUD:
		mud_under[c] = true

## The colour a body grows on this floor: Brad's table without its green.
## Empty on floors 1-2, which have no wrong fungus at all.
func _body_fungus() -> int:
	var parts: Array = MapGen.fungus_parts(Bands.mirrored(effective_depth()),
		Bands.is_corrupted(effective_depth()))
	var bad := float(parts[1]) + float(parts[2])
	if bad <= 0.0:
		return -1
	return Tiles.FUNGUS_PURPLE if fungus_rng.randf() * bad < float(parts[1]) \
		else Tiles.FUNGUS_RED

func _set_fungus(c: Vector2i, t: int) -> void:
	if Tiles.is_bad_fungus(t) or t == Tiles.FUNGUS:
		_note_mud(c)
	map.set_tile(c.x, c.y, t)
	_cloud_turn = -1
	pathfinder.set_fungus(c.x, c.y, Tiles.is_bad_fungus(t))
	_gather_lights()

## Spores carried, bodies taken, and red crawling toward the dead. Every
## player turn, after the world has moved, so a rat's step this turn counts.
func _grow_fungus() -> void:
	# Carried: a spore-bearer beside a body seeds it.
	for b in bodies:
		if int(b.get("seeded", -1)) >= 0 or bool(b.get("claimed", false)):
			continue
		var at := Vector2i(int(b["x"]), int(b["y"]))
		for e in entities:
			if e.alive and not e.is_player and e.appearance in SPORE_CARRIERS \
					and absi(e.x - at.x) <= 1 and absi(e.y - at.y) <= 1:
				b["seeded"] = turns
				break
	# Taken: a seeded body becomes fungus once the spores have rooted.
	var still: Array = []
	for b in bodies:
		var at := Vector2i(int(b["x"]), int(b["y"]))
		var seeded := int(b.get("seeded", -1))
		if seeded >= 0 and turns - seeded >= FUNGUS_ROOT and not bool(b.get("claimed", false)):
			# A purple-marked body keeps the tell's promise and rots purple;
			# only an unmarked one, seeded by a passing carrier, rolls the
			# floor's table. (Brad, 2026-09-30: a corrupted kobold rotted red.)
			var grows := Tiles.FUNGUS_PURPLE \
				if String(b["e"].get("spores", "")) == "purple" else _body_fungus()
			if grows >= 0 and _fungus_can_grow(at):
				_set_fungus(at, grows)
				if map.is_visible(at.x, at.y):
					msg_log.add("The %s's body is gone. %s fungus stands where it lay."
						% [String(b["e"].get("name", b["app"])),
						"Purple" if grows == Tiles.FUNGUS_PURPLE else "Red"],
						Color(0.78, 0.60, 0.80) if grows == Tiles.FUNGUS_PURPLE
						else Color(0.88, 0.45, 0.45))
				continue
			b["seeded"] = -2
		still.append(b)
	bodies = still
	# Red crawls toward the dead, and the dead it holds get up. A chain that
	# lost its body dies back first, so a square it gives up is not regrown.
	if turns % CRAWL_EVERY == 0:
		_wither_red()
		_crawl_red()
	_raise_the_red()
	# Trails: marked walkers leave their fungus behind, now and then.
	for e in entities:
		if not e.alive or e.is_player or e.flying or e.spores == &"" \
				or e.alertness == Entity.Alert.ASLEEP:
			continue
		var at := Vector2i(e.x, e.y)
		if not _fungus_can_grow(at) or fungus_rng.randf() >= TRAIL_CHANCE:
			continue
		var colour := Tiles.FUNGUS_RED if e.spores == &"red" else Tiles.FUNGUS_PURPLE
		if _count_tiles(colour) >= (RED_CAP if colour == Tiles.FUNGUS_RED else PURPLE_CAP):
			continue
		_set_fungus(at, colour)
		if map.is_visible(at.x, at.y):
			msg_log.add("The %s leaves %s fungus where it walks." % [e.name, String(e.spores)],
				Color(0.78, 0.60, 0.80) if colour == Tiles.FUNGUS_PURPLE else Color(0.88, 0.45, 0.45))
	# Water cleanses: before the air, so a pool beside the purple is breathed
	# again the same turn.
	for e in entities:
		if not e.is_player:
			_wash(e)
	# Acid, then the miasma: every creature breathes, flyers included.
	for e in entities.duplicate():
		if e.alive and not e.is_player and _acid_bites(e):
			_settle_death(e, e, "eaten by acid")
	for e in entities.duplicate():
		if e.alive and not e.is_player and _breathe(e):
			if map.is_visible(e.x, e.y):
				msg_log.add("The %s chokes on the miasma and dies." % e.name,
					Color(0.65, 0.70, 0.85))
			_settle_death(e, e, "choked by the miasma")
	# Careless walkers pay for it, and red marks them (flyers never touch it).
	for e in entities.duplicate():
		if not e.alive or e.is_player or e.flying:
			continue
		var t := map.get_tile(e.x, e.y)
		if not Tiles.is_bad_fungus(t) or (e.fungal and t == Tiles.FUNGUS_RED):
			continue
		e.take_spores(&"red" if t == Tiles.FUNGUS_RED else &"purple")
		# The red lets its carriers be (Brad, 2026-09-30): it marks a rat and
		# does not bite it.
		if t == Tiles.FUNGUS_RED and (e.appearance == &"rat" or e.appearance == &"slime"):
			continue
		e.take_damage(PURPLE_HURT if t == Tiles.FUNGUS_PURPLE else RED_HURT)
		if e.alive and e.alertness == Entity.Alert.ASLEEP:
			# A sleeper that finds itself in it -- spawned there, or grown
			# under -- stirs, shuffles to safe ground beside it and settles
			# again (Brad, 2026-09-29: rather than dying in its sleep, unseen).
			# The mark and the hurt it already took stay; it stays asleep.
			_shuffle_off_fungus(e, t)
		if not e.alive:
			if map.is_visible(e.x, e.y):
				msg_log.add("The %s dies in the %s fungus." % [e.name,
					"purple" if t == Tiles.FUNGUS_PURPLE else "red"], Color(0.65, 0.70, 0.85))
			# The fungus is the killer: no experience, but a body, loot and the
			# rest of a death, as any other. It stands as its own killer here,
			# with the fungus named for the body's record.
			_settle_death(e, e, "burned by the %s" % ("purple" if t == Tiles.FUNGUS_PURPLE else "red"))

## The claimed dead get up when their time comes -- unless something is
## standing on them, in which case they wait. A few turns before, a body you
## can see stirs, once: the last warning to burn it.
func _raise_the_red() -> void:
	var still: Array = []
	for b in bodies:
		if not bool(b.get("claimed", false)):
			still.append(b)
			continue
		var at := Vector2i(int(b["x"]), int(b["y"]))
		# Claimed in a save from before the rising existed: start its clock.
		if int(b.get("rises", -1)) < 0:
			b["rises"] = turns + _hatch(int(b["e"].get("max_hp", 1)))
		var left := int(b["rises"]) - turns
		if left <= RISE_WARNING and not bool(b.get("stirred", false)) \
				and map.is_visible(at.x, at.y):
			b["stirred"] = true
			msg_log.add("The %s's body twitches in the red fungus."
				% String(b["e"].get("name", b["app"])), Color(0.88, 0.45, 0.45))
		if left > 0 or entity_at(at.x, at.y) != null or not _rise_from(b):
			still.append(b)
	bodies = still

## One body up: the creature it was, at half its hp and hitting harder, on
## the side of nothing. False if the body could not be read.
func _rise_from(b: Dictionary) -> bool:
	var r := Entity.from_dict(b["e"])
	if r == null:
		return false
	var at := Vector2i(int(b["x"]), int(b["y"]))
	r.x = at.x
	r.y = at.y
	r.alive = true
	# The record was taken AFTER it died, and dying drops `blocks` with
	# `alive` (Entity.take_damage) -- so without this a risen thing is walked
	# through, by you and by everything else, and nothing can bump it
	# (entity_at skips what does not block). Brad fought a risen young dragon
	# he kept walking through, 2026-10-01.
	r.blocks = true
	r.faction = Entity.Faction.RISEN
	r.fungal = true
	r.raised = true
	r.spores = &"red"
	r.leash = _leash_at(at)
	r.alertness = Entity.Alert.AWAKE
	r.fleeing = false
	r.flee_below = 0.0
	r.shaken = 0
	r.poisoned = 0
	r.chilled = 0
	r.frozen = 0
	r.acid_turns = 0
	r.regen = 0
	r.careful = false
	r.max_hp = maxi(1, r.max_hp / 2)
	r.hp = r.max_hp
	r.power = maxi(1, ceili(r.power * RISEN_HITS))
	var was := r.name.trim_prefix("risen ")
	r.name = "risen %s" % was
	entities.append(r)
	Scheduler.spend(r, Scheduler.ACTION_COST)
	# The body got up: the shovel cannot have it as well.
	for rec in recent_dead.duplicate():
		var d: Dictionary = rec["e"]
		if int(rec["turn"]) == int(b["turn"]) and int(d.get("x", -1)) == at.x \
				and int(d.get("y", -1)) == at.y:
			recent_dead.erase(rec)
	events.append({"kind": &"notice", "to": at})
	if map.is_visible(at.x, at.y):
		msg_log.add("The %s rises out of the red fungus." % was, Color(0.92, 0.40, 0.40))
	return true

## Where a risen body may walk: the room (or vault) it rose in, else a square
## RISEN_REACH round the spot -- caves and corridors have no walls to hold it.
func _leash_at(at: Vector2i) -> Rect2i:
	for room in room_rects:
		if room.has_point(at):
			return room
	for vr in vault_rects:
		if vr.has_point(at):
			return vr
	return Rect2i(at - Vector2i(RISEN_REACH, RISEN_REACH),
		Vector2i(RISEN_REACH * 2 + 1, RISEN_REACH * 2 + 1))

## THE RISEN (strand 4). The red walks it at the nearest thing with a side --
## you, an ally, a monster -- that it perceives (see _risen_perceives) inside
## its room or at the room's edge (a doorway); failing that, to the last thing
## it heard. It never steps out: go back in prepared, or stay out. Freed by the
## gong, it hunts you wherever you are.
func _ai_risen(actor: Entity) -> void:
	var free := not actor.leash.has_area()
	var reach := actor.leash.grow(1)
	var foe: Entity = null
	var best := 0
	for e in entities:
		if not e.alive or not actor.hostile_to(e):
			continue
		if not free and not reach.has_point(Vector2i(e.x, e.y)):
			continue
		if not (free and e.is_player) and not _risen_perceives(actor, e):
			continue
		var d := Los.steps(actor.x, actor.y, e.x, e.y)
		if foe == null or d < best:
			foe = e
			best = d
	var goal := Vector2i(-1, -1)
	if foe != null:
		if actor.is_adjacent(foe):
			_attack(actor, foe)
			return
		goal = Vector2i(foe.x, foe.y)
	elif actor.heard.x >= 0:
		# Gone to the sound and found nothing: it forgets it.
		if Los.steps(actor.x, actor.y, actor.heard.x, actor.heard.y) <= 1:
			actor.heard = Vector2i(-1, -1)
			return
		goal = actor.heard
	else:
		return
	var from := Vector2i(actor.x, actor.y)
	var held := not free and actor.leash.has_point(from)
	if held:
		# Not even the door: opening it would be a step out.
		var route := pathfinder.path(from, goal)
		if route.is_empty() or not actor.leash.has_point(route[0]):
			return
	_step_toward(actor, goal)
	# A step round a blocker can land outside the room: take it back.
	if held and not actor.leash.has_point(Vector2i(actor.x, actor.y)):
		actor.x = from.x
		actor.y = from.y

## Whether a risen body knows this creature is there. Blind, so: whatever is
## where it last heard something; whatever steps within RISEN_HEARING (or
## touches it) -- except a rat, real or ring. A risen skeleton also SEES, and
## the dead are not fooled by the ring. Real rats it never hunts at all.
func _risen_perceives(actor: Entity, e: Entity) -> bool:
	if e.appearance == &"rat" and not e.is_player:
		return false
	if actor.unliving and _can_see(actor, e):
		return true
	if actor.heard.x >= 0 and Los.steps(e.x, e.y, actor.heard.x, actor.heard.y) <= 1:
		return true
	if e.is_player and ratted():
		return false
	var d := Los.steps(actor.x, actor.y, e.x, e.y)
	if d <= 1:
		return true
	return not e.flying and d <= RISEN_HEARING

func _count_tiles(t: int) -> int:
	var n := 0
	for y in map.height:
		for x in map.width:
			if map.get_tile(x, y) == t:
				n += 1
	return n

## A rat that is not hunting you smells a fresh, unseeded body and goes to it
## (Brad's plague carriers): the aftermath of a fight draws them in. It stirs
## if asleep -- SUSPICIOUS, so it shows. True if it spent its turn on that.
func _rat_to_body(actor: Entity) -> bool:
	var best := Vector2i(-1, -1)
	var best_d := RAT_NOSE + 1
	for b in bodies:
		if int(b.get("seeded", -1)) != -1 or bool(b.get("claimed", false)):
			continue
		var at := Vector2i(int(b["x"]), int(b["y"]))
		var d := Los.steps(actor.x, actor.y, at.x, at.y)
		if d < best_d:
			best_d = d
			best = at
	if best.x < 0:
		return false
	if actor.alertness == Entity.Alert.ASLEEP:
		actor.alertness = Entity.Alert.SUSPICIOUS
	if best_d > 1:
		_step_toward(actor, best)
	return true

func _crawl_red() -> void:
	var reds: Array[Vector2i] = []
	for y in map.height:
		for x in map.width:
			if map.get_tile(x, y) == Tiles.FUNGUS_RED:
				reds.append(Vector2i(x, y))
	if reds.is_empty():
		return
	for b in bodies:
		if bool(b.get("claimed", false)) or bool(b.get("still", false)):
			continue
		var at := Vector2i(int(b["x"]), int(b["y"]))
		if not _red_can_hold(at):
			continue
		var from := Vector2i(-1, -1)
		var best := CRAWL_REACH + 1
		for r in reds:
			var d: int = maxi(absi(r.x - at.x), absi(r.y - at.y))
			if d < best:
				best = d
				from = r
		if from.x < 0:
			continue
		if best <= 1:
			b["claimed"] = true
			b["rises"] = turns + _hatch(int(b["e"].get("max_hp", 1)))
			if map.get_tile(at.x, at.y) != Tiles.FUNGUS_RED:
				_set_fungus(at, Tiles.FUNGUS_RED)
				red_from[at] = from
			if map.is_visible(at.x, at.y):
				msg_log.add("The red fungus reaches the %s's body."
					% String(b["e"].get("name", b["app"])), Color(0.88, 0.45, 0.45))
			continue
		if reds.size() >= RED_CAP:
			continue
		# One square toward the body: the diagonal first, then either axis.
		var step := Vector2i(signi(at.x - from.x), signi(at.y - from.y))
		for s in [step, Vector2i(step.x, 0), Vector2i(0, step.y)]:
			if s == Vector2i.ZERO:
				continue
			var c: Vector2i = from + s
			if _fungus_can_grow(c):
				_set_fungus(c, Tiles.FUNGUS_RED)
				red_from[c] = from
				reds.append(c)
				break

## What a square is under its fungus.
## The chains as rows a save can hold: [x, y, from_x, from_y].
func _red_from_rows() -> Array:
	var rows: Array = []
	for c in red_from:
		var f: Vector2i = red_from[c]
		rows.append([c.x, c.y, f.x, f.y])
	return rows

func _bare_ground(c: Vector2i) -> int:
	if mud_under.erase(c):
		return Tiles.MUD
	return Tiles.CAVE_FLOOR if map.material_at(c.x, c.y) == Materials.CAVERN \
		else Tiles.FLOOR

## A body the red could still go for, within its reach of this square.
func _red_has_another(c: Vector2i) -> bool:
	for b in bodies:
		if bool(b.get("claimed", false)) or bool(b.get("still", false)):
			continue
		var at := Vector2i(int(b["x"]), int(b["y"]))
		if maxi(absi(at.x - c.x), absi(at.y - c.y)) <= CRAWL_REACH and _red_can_hold(at):
			return true
	return false

## The red has lost the body at `at` -- buried, dug up, drunk -- before it
## rose. If another body is in reach the crawl simply turns to it (its
## nearest-body rule needs nothing new). If not, the chain that reached this
## one WITHERS back toward its source, a square a crawl tick (Brad,
## 2026-10-01). A body claimed where it fell sits on its own source: nothing
## to wither.
func _red_loses(at: Vector2i) -> void:
	if _red_has_another(at):
		return
	var chain: Array = []
	var c := at
	while red_from.has(c) and chain.size() <= RED_CAP:
		chain.append(c)
		c = red_from[c]
	if chain.is_empty():
		return
	withering.append(chain)
	if map.is_visible(at.x, at.y):
		msg_log.add("The red fungus draws back from where the body lay.",
			Color(0.88, 0.45, 0.45))

## One square off the tip of every withering chain. A chain stops where a
## branch still grows out of it (another chain lives on from there) or where
## a body has come into reach (the red turns to that instead).
func _wither_red() -> void:
	var still: Array = []
	for chain in withering:
		if chain.is_empty():
			continue
		var c: Vector2i = chain[0]
		if _red_has_another(c) or red_from.values().has(c):
			continue
		if map.get_tile(c.x, c.y) == Tiles.FUNGUS_RED:
			scorched.erase("%d,%d" % [c.x, c.y])
			_set_fungus(c, _bare_ground(c))
		red_from.erase(c)
		chain.remove_at(0)
		if not chain.is_empty():
			still.append(chain)
	withering = still

## The claimed body G would bury: underfoot, then ahead, then round you
## clockwise from your facing. Empty without a shovel in the pack.
func bury_target() -> Dictionary:
	if not _has_shovel():
		return {}
	var here := Vector2i(player.x, player.y)
	var cells: Array[Vector2i] = [here]
	for i in 8:
		cells.append(here + Entity.turned(player.facing, i))
	# The red's dead first, wherever they lie in reach: that grave is a race,
	# and a plain body beside it can wait.
	for c in cells:
		for b in bodies:
			if _reds_dead(b) and int(b["x"]) == c.x and int(b["y"]) == c.y:
				return b
	for c in cells:
		for b in bodies:
			if int(b["x"]) == c.x and int(b["y"]) == c.y:
				return b
	return {}

## The red's dead: a body it has claimed, or one that already rose for it and
## fell again. These are the graves that PAY (the undertaker's pay) -- and
## until 2026-10-04 the only ones the shovel would dig. Any body can be
## buried now (Brad, the night the floor came alive): a buried body feeds no
## rat and seeds no fungus, which is a lever on the floor's whole ecology,
## and the turns and the noise are the price. It still sharpens nothing.
func _reds_dead(b: Dictionary) -> bool:
	return bool(b.get("claimed", false)) or bool(b["e"].get("fungal", false))

func _shovel() -> Item:
	for it in player.inventory:
		if it.dulls():
			return it
	return null

## One more grave on the shovel's count, and its edge back at five.
func _lay_to_rest() -> void:
	var shovel := _shovel()
	if shovel == null:
		return
	shovel.laid_to_rest = mini(BURIALS_TO_SHARPEN, shovel.laid_to_rest + 1)
	if shovel.dull and shovel.laid_to_rest >= BURIALS_TO_SHARPEN:
		shovel.dull = false
		shovel.laid_to_rest = 0
		msg_log.add("Five laid to rest. The shovel's edge comes back: an undertaker's pay.",
			Color(0.80, 0.85, 0.70))
	else:
		msg_log.add("(%d of %d laid to rest)" % [shovel.laid_to_rest, BURIALS_TO_SHARPEN],
			Color(0.70, 0.72, 0.66))

func _has_shovel() -> bool:
	return _shovel() != null

## A BONE ALLY CAN CATCH THE RED (Brad, 2026-10-01: keep the horror, but say
## so). A risen's blows and red underfoot mark an ally like anything else; a
## marked bone ally that falls is claimed and rises against you. The moment it
## is marked, the log says so once, with what stops it.
func _warn_of_red_allies() -> void:
	for e in entities:
		if not _is_red_bone_ally(e) or e.red_warned:
			continue
		e.red_warned = true
		msg_log.add("The red fungus has laid claim to %s. If they fall, they will rise against you."
			% e.name, Color(0.92, 0.40, 0.40))
		msg_log.add("Your shovel can bury them before they rise -- if you are quick enough."
			if _has_shovel() else
			"Fire can burn the body before they rise -- if you are quick enough.",
			Color(0.88, 0.62, 0.50))

func _is_red_bone_ally(e: Entity) -> bool:
	return e.alive and e.appearance == &"bone_ally" \
		and e.faction == Entity.Faction.PLAYER and e.spores == &"red"

## A spadeful over a claimed body. False, spending nothing, without one.
func player_bury() -> bool:
	if game_over:
		return false
	var b := bury_target()
	if b.is_empty():
		return false
	_travel.clear()
	var at := Vector2i(int(b["x"]), int(b["y"]))
	var who := String(b["e"].get("name", b["app"]))
	b["dug"] = int(b.get("dug", 0)) + 1
	# Loud where YOU stand: that is where anything that hears it will come.
	_make_noise(Vector2i(player.x, player.y), DIG_NOISE, &"dig")
	if int(b["dug"]) < BURY_SPADEFULS:
		msg_log.add("You dig at the %s's grave. The noise carries. (%d/%d)"
			% [who, int(b["dug"]), BURY_SPADEFULS], Color(0.80, 0.72, 0.55))
	else:
		bodies.erase(b)
		if bool(b.get("claimed", false)):
			msg_log.add("You turn the last earth over the %s. The red has lost it." % who,
				Color(0.80, 0.85, 0.70))
			_red_loses(at)
			_lay_to_rest()
		elif _reds_dead(b):
			msg_log.add("You turn the last earth over the %s. It will not get up again." % who,
				Color(0.80, 0.85, 0.70))
			_lay_to_rest()
		else:
			# A plain body: nothing to deny the red, so no pay -- but the rats
			# will not find it, and nothing will grow where it lay.
			msg_log.add("You turn the last earth over the %s. The rats will not have it." % who,
				Color(0.80, 0.85, 0.70))
	_end_player_turn()
	return true

## THE GEM OF THIRST DRINKS THE DEAD (6d, 2026-09-30). Crushed against a
## body underfoot or beside you, it drains it and gives you THIRST_SHARE of
## its strength: half its max hp. The body is gone -- a third claimant for the
## dead beside the red and the shovel, and the way to deny the red a body when
## you have no fire. At full health it is refused, unless the red has claimed
## the body: then the denial is the point.
const THIRST_SHARE := 2

## The body the gem would drink: the richest within reach (underfoot or
## beside you) that it WOULD drink -- whole, only one the red has claimed;
## ties go to the earliest laid. Empty for none. The key, the pack and the
## HERE box all ask this one question (day-7 hunt, 2026-10-04: the pack
## offered a drink the key refused, and a claimed body beside a richer plain
## one was never offered at all).
func thirst_target() -> Dictionary:
	var whole := player.hp >= player.max_hp
	var best: Dictionary = {}
	for b in bodies:
		if maxi(absi(int(b["x"]) - player.x), absi(int(b["y"]) - player.y)) > 1:
			continue
		if whole and not bool(b.get("claimed", false)):
			continue
		if best.is_empty() or _thirst_heal(b) > _thirst_heal(best):
			best = b
	return best

func _thirst_heal(b: Dictionary) -> int:
	return maxi(1, int(b["e"].get("max_hp", 2)) / THIRST_SHARE)

func _drink_the_dead(gem: Item) -> bool:
	var b := thirst_target()
	if b.is_empty():
		# Which refusal: nothing to drink, or nothing worth it while whole.
		var near := false
		for body in bodies:
			if maxi(absi(int(body["x"]) - player.x), absi(int(body["y"]) - player.y)) <= 1:
				near = true
		msg_log.add("You are already whole." if near else "There is no body here for it to drink.",
			Color(0.7, 0.6, 0.4))
		return false
	var claimed := bool(b.get("claimed", false))
	var at := Vector2i(int(b["x"]), int(b["y"]))
	var who := String(b["e"].get("name", b["app"]))
	var healed := mini(_thirst_heal(b), player.max_hp - player.hp)
	player.hp += healed
	if healed > 0:
		_queue_healing_cue(healed)
	bodies.erase(b)
	msg_log.add("You crush the %s against the %s's body. It drinks it dry. (+%d hp)"
		% [gem.name, who, healed], Color(0.55, 0.85, 0.55))
	if claimed:
		_red_loses(at)
	return true

## Moves a creature to the nearest safe square beside it: walkable, empty,
## and not the wrong fungus. Stays put if there is none.
func _shuffle_off_fungus(e: Entity, from_tile: int) -> void:
	for i in 8:
		var d := Entity.turned(Vector2i(0, -1), i)
		var c := Vector2i(e.x + d.x, e.y + d.y)
		if not map.is_walkable(c.x, c.y) or Tiles.is_avoided(map.get_tile(c.x, c.y)) \
				or Tiles.is_bad_fungus(map.get_tile(c.x, c.y)) or entity_at(c.x, c.y) != null:
			continue
		var was_seen := map.is_visible(e.x, e.y)
		e.x = c.x
		e.y = c.y
		if was_seen or map.is_visible(c.x, c.y):
			msg_log.add("The %s stirs and shuffles off the %s fungus." % [e.name,
				"purple" if from_tile == Tiles.FUNGUS_PURPLE else "red"],
				Color(0.78, 0.72, 0.62))
		return

## Standing on the wrong fungus hurts, every turn you stay.
func _fungus_underfoot(underfoot: int) -> void:
	if not Tiles.is_bad_fungus(underfoot):
		return
	# Nor a ring-rat: to the red, a rat is a rat.
	if underfoot == Tiles.FUNGUS_RED and ratted():
		return
	var hurt := PURPLE_HURT if underfoot == Tiles.FUNGUS_PURPLE else RED_HURT
	player.take_damage(hurt)
	_tally("taken", hurt)
	msg_log.add(("The purple fungus bursts in your face. (-%d hp)" if underfoot == Tiles.FUNGUS_PURPLE
		else "The red fungus bites at your feet. (-%d hp)") % hurt,
		Color(0.92, 0.48, 0.40))
	events.append({"kind": &"melee", "from": Vector2i(player.x, player.y),
		"to": Vector2i(player.x, player.y), "amount": hurt, "on_player": true})
	if not player.alive:
		game_over = true
		death_cause = "poisoned by purple fungus" if underfoot == Tiles.FUNGUS_PURPLE \
			else "eaten by red fungus"
		events.append({"kind": &"death", "to": Vector2i(player.x, player.y)})
		write_morgue()
		write_death_dump()

## Fire against the wrong fungus, from G: a fire weapon burns it in one, a lit
## torch scorches it away in TORCH_SCORCHES. True if this spent the turn.
func _burn_at(c: Vector2i) -> bool:
	if not Tiles.is_bad_fungus(map.get_tile(c.x, c.y)):
		return false
	var blade: Variant = player.equipped.get(Item.Slot.WEAPON, null)
	var fire: bool = blade != null and blade.element == &"fire"
	var what := "purple" if map.get_tile(c.x, c.y) == Tiles.FUNGUS_PURPLE else "red"
	if fire:
		_burn_fungus(c)
		msg_log.add("Your %s burns the %s fungus away." % [blade.name, what],
			Color(0.96, 0.66, 0.36))
		_end_player_turn()
		return true
	if not torch_lit:
		return false
	var key := "%d,%d" % [c.x, c.y]
	scorched[key] = int(scorched.get(key, 0)) + 1
	if int(scorched[key]) >= TORCH_SCORCHES:
		_burn_fungus(c)
		msg_log.add("Your torch scorches the %s fungus away." % what,
			Color(0.96, 0.66, 0.36))
	else:
		msg_log.add("You scorch the %s fungus with your torch. (%d/%d)"
			% [what, int(scorched[key]), TORCH_SCORCHES], Color(0.90, 0.72, 0.50))
	_end_player_turn()
	return true

func _burn_fungus(c: Vector2i) -> void:
	# A body lying in it burns too: that is how a claimed one is stopped.
	for b in bodies.duplicate():
		if int(b["x"]) == c.x and int(b["y"]) == c.y:
			bodies.erase(b)
			if map.is_visible(c.x, c.y):
				msg_log.add("The %s's body burns with it."
					% String(b["e"].get("name", b["app"])), Color(0.96, 0.66, 0.36))
	scorched.erase("%d,%d" % [c.x, c.y])
	red_from.erase(c)
	_set_fungus(c, _bare_ground(c))
	# The views and sound deck give this a small ember burst, not forge sparks.
	events.append({"kind": &"burn", "to": c})

## Drops the bodies that have rotted away. Every player turn.
func _rot_bodies() -> void:
	if bodies.is_empty():
		return
	var still: Array = []
	for b in bodies:
		# The red holds what it has claimed: it rises, it does not rot.
		if turns - int(b["turn"]) < BODY_ROT or bool(b.get("claimed", false)):
			still.append(b)
	bodies = still

## The last few things you killed, newest last, pruned as they cool.
##
## Stored as dictionaries rather than Entities so it serialises with the run
## for free, and so nothing here can hold a reference to a corpse the rest of
## the game thinks it has finished with.
var recent_dead: Array = []

func _remember_the_dead(victim: Entity) -> void:
	if victim.is_player or victim.faction == Entity.Faction.PLAYER or victim.raised:
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
	risen.blocks = true  # dropped with `alive` when it died; see _rise_from
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
	# Its one second life: the red will not take it again, and it drops
	# nothing when it falls (its gear dropped the first time).
	risen.raised = true
	# Taken from the red, if the red had it: you do not dig up a friend still
	# wearing the fungus, leaving it on the floor behind you as it walks.
	risen.spores = &""
	risen.poisoned = 0
	entities.append(risen)
	Scheduler.spend(risen, Scheduler.ACTION_COST)
	recent_dead.erase(pick)
	# The body got up: it is no longer lying there.
	var from: Dictionary = pick["e"]
	for b in bodies:
		if int(b["turn"]) == int(pick["turn"]) and int(b["x"]) == int(from.get("x", -1)) \
				and int(b["y"]) == int(from.get("y", -1)):
			bodies.erase(b)
			if bool(b.get("claimed", false)):
				_red_loses(Vector2i(int(b["x"]), int(b["y"])))
			break
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
			if not Tiles.is_open_door(map.get_tile(c.x, c.y)):
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
	var gate := map.get_tile(found.x, found.y) == Tiles.GATE_OPEN
	map.set_tile(found.x, found.y, Tiles.closed(map.get_tile(found.x, found.y)))
	_set_gate_route(found)
	_travel.clear()
	_work_the_door(found, "You swing the gate to. The latch drops." if gate
		else "You pull the door shut.")
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
				# The one thing that lets the risen out of their room.
				if e.faction == Entity.Faction.RISEN:
					e.leash = Rect2i()
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
			_queue_healing_cue(healed)
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
				# Called up AT you, so it knows where you were. Without a
				# mark, one stepping through behind a pillar had nowhere to go
				# once hunters followed last_seen (2026-10-04).
				entities[i].last_seen = Vector2i(player.x, player.y)
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

## Every trap the floor laid goes under: its square is floor and the trap is
## in hidden_traps, to be spotted or sprung. After generation, before the
## pathfinder is built from the map, so a hidden one routes as floor.
func _hide_the_traps() -> void:
	hidden_traps.clear()
	for y in map.height:
		for x in map.width:
			if map.get_tile(x, y) != Tiles.TRAP:
				continue
			hidden_traps[Vector2i(x, y)] = true
			map.set_tile(x, y, Tiles.CAVE_FLOOR if map.material_at(x, y) == Materials.CAVERN
				else Tiles.FLOOR)

## The chance, this turn, of spotting the hidden trap at `cell`: nothing out
## of SPOT_REACH or out of sight; else the dark's floor plus the light on the
## square, less a fifth per cell of distance, half again with the glass.
func _spot_chance(cell: Vector2i) -> float:
	var d := Los.steps(player.x, player.y, cell.x, cell.y)
	if d > SPOT_REACH or not map.is_visible(cell.x, cell.y):
		return 0.0
	var lum := light_map.get_light(cell.x, cell.y).get_luminance()
	var chance := (SPOT_DARK + SPOT_LIT * lum) * (1.0 - 0.2 * float(maxi(d, 1) - 1))
	if _spots_traps_better():
		chance *= SPOT_GLASS
	return clampf(chance, 0.0, 1.0)

## The trapwright's glass, worn in the offhand.
func _spots_traps_better() -> bool:
	var off: Variant = player.equipped.get(Item.Slot.OFFHAND, null)
	return off != null and off.id == &"trap_glass"

## Each turn, every hidden trap in reach and in sight gets its roll.
func _spot_traps() -> void:
	if hidden_traps.is_empty() or not player.alive:
		return
	for cell in hidden_traps.keys():
		var chance := _spot_chance(cell)
		if chance > 0.0 and trap_rng.randf() < chance:
			_reveal_trap(cell)

## Seen: the trap tile from now on -- drawn, remembered, and routed round by
## your own side. Monsters walk over it: it is their floor.
func _reveal_trap(cell: Vector2i) -> void:
	hidden_traps.erase(cell)
	map.set_tile(cell.x, cell.y, Tiles.TRAP)
	if pathfinder != null:
		pathfinder.set_trap(cell.x, cell.y, true)
	events.append({"kind": &"notice", "to": cell})
	msg_log.add("You spot a trap.", Color(0.95, 0.80, 0.45))

## Springs once and is gone. A trap corridor can be cleared at a price, which
## makes it a toll rather than a permanent wall.
##
## `victim` is whoever set it off -- the player, or an ally that blundered
## onto it (`_spring_under_allies`); `scale` is the fumbled disarm's half.
func _spring_trap(x: int, y: int, victim: Entity = null, scale := 1.0) -> void:
	if victim == null:
		victim = player
	map.set_tile(x, y,
		Tiles.CAVE_FLOOR if map.material_at(x, y) == Materials.CAVERN
		else Tiles.FLOOR)
	# Sprung, it is floor to every route again. Before 2026-10-02 a found
	# trap the player sprang stayed solid in the pathfinder for the rest of
	# the floor.
	if pathfinder != null:
		pathfinder.set_trap(x, y, false)
	var hurt := maxi(1, int(round(rng.randi_range(2, 4 + depth / 2) * scale)))
	victim.take_damage(hurt)
	if victim.is_player:
		_tally("taken", hurt)
		msg_log.add("The mechanism snaps shut. (-%d hp)" % hurt, Color(0.92, 0.48, 0.40))
	elif map.is_visible(x, y):
		msg_log.add("The mechanism snaps shut under the %s. (-%d hp)" % [victim.name, hurt],
			Color(0.92, 0.48, 0.40))
	events.append({"kind": &"trap", "to": Vector2i(x, y)})
	events.append({"kind": &"melee", "from": Vector2i(x, y), "to": Vector2i(x, y),
		"amount": hurt, "on_player": victim.is_player})
	# Springing one is loud -- but it is not a BONE CRUNCH, and the difference
	# matters. This passed no cause, so it defaulted to &"step" and quietly
	# raised gravestones, against the rule three lines of comment in
	# `_make_noise` insist on: bones and a wail, and nothing else, so that the
	# rule is one a player can hold in their head. A trap doing it as well made
	# that a lie for the life of the project.
	_make_noise(Vector2i(x, y), 5, &"trap")
	if victim.alive:
		return
	if not victim.is_player:
		_settle_death(victim, victim, "killed by a trap")
		return
	game_over = true
	death_cause = "caught in a trap"
	events.append({"kind": &"death", "to": Vector2i(player.x, player.y)})
	write_morgue()
	write_death_dump()

## YOUR OWN SIDE IS NOT THE FLOOR'S OWN. An ally walking at heel springs the
## hidden trap under its next step as you would, and tells you where it was;
## one shoved or swapped onto a found trap springs that. Monsters never do:
## they laid them. Run after the world has moved.
func _spring_under_allies() -> void:
	for e in entities.duplicate():
		if e.is_player or not e.alive or e.flying or _owns_the_floor(e):
			continue
		var at := Vector2i(e.x, e.y)
		if hidden_traps.has(at):
			hidden_traps.erase(at)
			if map.is_visible(at.x, at.y):
				msg_log.add("The floor clicks under the %s." % e.name, Color(0.92, 0.48, 0.40))
			_spring_trap(at.x, at.y, e)
		elif map.get_tile(at.x, at.y) == Tiles.TRAP:
			_spring_trap(at.x, at.y, e)

## DISARMING (Brad, 2026-10-02: the 5e half of a found trap). G beside or on
## one: a turn, and a roll on the trap stream. Made, the trap is gone for
## good; fumbled, it springs under your hands for half. The chance is the
## trapwright's glass's second job.
const DISARM_BARE := 0.5
const DISARM_GLASS := 0.9
## Crossing a found trap on purpose is a slow step and no hurt: you know where
## the plate is and edge round it. The trap stays armed behind you.
const TRAP_STEP_OVER := 2

func disarm_chance() -> float:
	return DISARM_GLASS if _spots_traps_better() else DISARM_BARE

## The found trap G would work on: underfoot, the one you face, or any beside.
func disarm_target() -> Vector2i:
	var here := Vector2i(player.x, player.y)
	if map.get_tile(here.x, here.y) == Tiles.TRAP:
		return here
	if map.get_tile(here.x + player.facing.x, here.y + player.facing.y) == Tiles.TRAP:
		return here + player.facing
	for i in 8:
		var d := Entity.turned(player.facing, i)
		if map.get_tile(here.x + d.x, here.y + d.y) == Tiles.TRAP:
			return here + d
	return Vector2i(-1, -1)

func player_disarm() -> bool:
	if game_over:
		return false
	var c := disarm_target()
	if c.x < 0:
		msg_log.add("There is no trap within reach.", Color(0.7, 0.6, 0.4))
		return false
	if ratted():
		msg_log.add("You have no hands. Whatever you meant to do, you cannot.",
			Color(0.7, 0.6, 0.4))
		return false
	_travel.clear()
	if trap_rng.randf() < disarm_chance():
		map.set_tile(c.x, c.y,
			Tiles.CAVE_FLOOR if map.material_at(c.x, c.y) == Materials.CAVERN else Tiles.FLOOR)
		if pathfinder != null:
			pathfinder.set_trap(c.x, c.y, false)
		msg_log.add("You find the catch and disarm the trap.", Color(0.95, 0.80, 0.45))
	else:
		msg_log.add("Your hand slips. The trap springs under it.", Color(0.92, 0.48, 0.40))
		_spring_trap(c.x, c.y, player, 0.5)
		if game_over:
			return true
	_end_player_turn()
	return true

## Loud ground. Noise carries through stone, so this ignores line of sight --
## it is the counterpart to light, and the second thing that can give you away.
## `by` is whoever made it, and is not roused by it: a goblin's own kill
## would otherwise turn it from hunting rabbits to hunting YOU (2026-10-04,
## the day a monster first struck something that was not the player).
func _make_noise(at: Vector2i, radius: int, cause: StringName = &"step",
		by: Entity = null) -> void:
	if radius <= 0 or _prerunning:
		return
	# Made in a frozen room, it carries nowhere (the gem of frost).
	if _muffled(at):
		return
	# Emitted whether or not anything was actually roused. What the player
	# needs to know is that they were LOUD; whether the room happened to be
	# empty is a separate fact, and the message log already carries it.
	events.append({"kind": &"noise", "to": at, "radius": radius, "cause": cause})
	# The blind dead turn to it -- if it is in their room, or at its edge.
	for e in entities:
		if e.alive and e.frozen == 0 and e.faction == Entity.Faction.RISEN \
				and Los.steps(e.x, e.y, at.x, at.y) <= radius \
				and (not e.leash.has_area() or e.leash.grow(1).has_point(at)):
			e.heard = at
	var roused := 0
	for e in entities:
		if e.is_player or e == by or not e.alive or e.alertness == Entity.Alert.AWAKE:
			continue
		# A frozen thing hears nothing, and is not left holding what it did
		# not hear when it thaws.
		if e.frozen > 0:
			continue
		# Out of earshot, untouched. This used to wake it and put it straight
		# back to SLEEP, which turned a suspicious thing into a sleeping one
		# and wiped its notice block -- the veil's head start, among other
		# things -- on any noise anywhere on the floor (found 2026-10-01).
		if Los.steps(e.x, e.y, at.x, at.y) > radius:
			continue
		e.alertness = Entity.Alert.AWAKE
		e.last_seen = at
		e.lost_turns = 0
		e.notice_block = 0
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
## Room index -> true for every room the player has entered on this floor.
## Room 0 is where the floor starts you, so it is found before you move.
var rooms_found: Dictionary = {0: true}

## THE ROAD. Counts each new ROOM entered on this floor -- not caves, not
## corridors, not the room you started in. Only rooms, which is what keeps the
## gem honest in the caves: measured 2026-09-26, the upper floors average 13
## rooms, the caves 5, the fortress 9-10, the deep floor 13, so a travel stone
## grows to +3 up top, barely +1 in the caves, and hunting stays the way to
## survive down there. Counted whatever you are wearing, so putting the stone
## on halfway through a floor is worth what you have already walked.
func _note_rooms() -> void:
	var here := Vector2i(player.x, player.y)
	for i in room_rects.size():
		if rooms_found.has(i) or not room_rects[i].has_point(here):
			continue
		var before := player.travel_bonus()
		rooms_found[i] = true
		player.travel_rooms = rooms_found.size() - 1
		var after := player.travel_bonus()
		if after > before:
			msg_log.add("The road settles into your armour. (+%d defense)" % after,
				Color(0.80, 0.88, 0.72))
		return

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
		_queue_healing_cue(healed)
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
	var hp_before := player.hp
	player.level += 1
	player.max_hp += LEVEL_HP
	# Healed by the gain, so a level is a small reprieve as well as a stat bump.
	player.hp = mini(player.max_hp, player.hp + LEVEL_HP)
	_queue_healing_cue(player.hp - hp_before)
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
	if forge_wants_room(item):
		return false
	return item_can_upgrade(item) and not _forge_site(item).is_empty()

## A stack of three or more worked with a full pack: the worked one must be
## set apart from the plain ones left, and there is no slot for them. The ONE
## rule the key (player_merge), the ● and the hint all ask (day-7 hunt,
## 2026-10-04 -- they offered the forge the key then refused; Brad: one rule,
## not two).
func forge_wants_room(item: Item) -> bool:
	return item.count >= 3 and player.pack_count() >= Entity.INVENTORY_MAX

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

	# WORKED OUT OF A STACK: two leave it, one comes back better, and the
	# better one is its own slot from then on (a +1 does not stack with the
	# plain ones). It takes the stack's place in the list -- the thing you
	# clicked is the thing that got better -- and the rest shuffle down one.
	# With three or more left and no slot free there is nowhere to set the
	# worked one apart, so the forge is refused before anything is spent.
	if donor == item:
		var rest := item.count - 2
		# The same question the ● and the hint ask -- one rule, not two.
		if forge_wants_room(item):
			msg_log.add("Your pack is full; there is nowhere to set the rest of the %s apart." % item.name,
				Color(0.9, 0.55, 0.35))
			return false
		_travel.clear()
		# The stack itself becomes the worked one (same object, same letter,
		# same row), and the plain ones left over move down a row.
		if rest > 0:
			var others := item.split_one()
			others.count = rest
			others.letter = _free_letter()
			player.inventory.insert(player.inventory.find(item) + 1, others)
		item.count = 1
	else:
		_travel.clear()
		_spend_one(donor)

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

## Would this unique take a gem now? The ring while it is short of full; the
## shovel while it is dull. Any gem: the stone is fuel here, not an element.
func can_feed(it: Item) -> bool:
	if it.transforms():
		return it.charges < RING_FULL
	if it.dulls():
		return it.dull
	return false

## The first unique in the pack that would take a gem, or null.
func _feedable() -> Item:
	for it in player.inventory:
		if can_feed(it):
			return it
	return null

## Where a gem goes when the player does not name a host: a piece of gear
## that can still take it, else a unique that wants feeding, else the gear
## anyway -- so the refusal names the real reason ("already holds a gem").
func _gem_host(gem: Item) -> Variant:
	var host: Variant = _default_host(gem)
	if host != null and host.element == &"":
		return host
	var fed := _feedable()
	if fed != null:
		return fed
	return host

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
		if not blade.is_equipment() and not can_feed(blade):
			return false
	else:
		blade = _gem_host(gem)
	if blade == null:
		msg_log.add("You have nothing in hand to set it into.",
			Color(0.7, 0.6, 0.4))
		return false
	var feeding := can_feed(blade)
	# One stone, forever. Refused rather than replaced: the whole weight of the
	# choice is that it cannot be taken back, and overwriting would turn a
	# commitment into a preference.
	if not feeding and blade.element != &"":
		msg_log.add("The %s already holds a gem. It will take no other."
			% blade.display_name(), Color(0.7, 0.6, 0.4))
		return false
	if not feeding and not blade.accepts_element(gem.element):
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
	gem = _spend_one(gem)
	_tally("bindings")
	events.append({"kind": &"forge", "to": hot})

	# Same cost as an ember forge, because it IS one: the brazier is spent.
	map.set_tile(hot.x, hot.y, Tiles.BRAZIER_DEAD)
	ember_until.erase(hot)
	_lay_the_beat()
	if feeding and blade.transforms():
		var had: int = blade.charges
		blade.charges = mini(RING_FULL, blade.charges + RING_FEED)
		msg_log.add("You press the %s into the ring. It warms on your finger. (+%d, %d/%d)"
			% [gem.name, blade.charges - had, blade.charges, RING_FULL],
			Color(0.85, 0.88, 0.70))
	elif feeding:
		blade.dull = false
		msg_log.add("You grind the %s into the shovel's edge. It will bite again."
			% gem.name, Color(0.85, 0.88, 0.70))
	else:
		blade.element = gem.element
		msg_log.add("You set the %s into the %s. It drinks the last of the heat."
			% [gem.name, blade.display_name()], Color(0.85, 0.88, 0.70))
	# Not "nothing will kindle it again" -- fire relights a black brazier now
	# (a flare, a gem of fire, a fire blade: 6b).
	msg_log.add("The brazier goes black. Only fire will wake it now.",
		Color(0.45, 0.42, 0.42))
	_make_noise(hot, FORGE_NOISE, &"forge")
	_end_player_turn()
	return true

## Can this gem be set right now? Drives the inventory marker, the same way
## can_forge_item does -- so a weapon that already holds one simply never
## offers, rather than refusing after the click.
## THE EMBERS COME FIRST (Brad's play, 2026-10-05). Standing at a guttering
## brazier with a bow in hand and a gem of returning, he pressed the gem and
## it was CRUSHED -- "mark this brazier", the gem's own use -- when he meant
## to set it. A gem's own use is the second thing it does; where it can be
## set, this very turn, into something that will hold it, setting is what
## the gem is for. True only at EMBERS with a willing host: a lit brazier
## is not yet the forge, and the gem's own use stands there.
func gem_sets_here(gem: Item) -> bool:
	if gem.kind != Item.Kind.GEM or _adjacent_embers().x < 0:
		return false
	var host: Variant = _gem_host(gem)
	if host == null:
		return false
	return can_feed(host) or (host.element == &"" and host.accepts_element(gem.element))

func can_bind_gem(gem: Item) -> bool:
	if gem.kind != Item.Kind.GEM:
		return false
	var blade: Variant = _gem_host(gem)
	if blade == null or (blade.element != &"" and not can_feed(blade)):
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
	# Two of a kind in one slot: the stack feeds itself (see player_merge).
	if item.count >= 2:
		return item
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
## What the action key does on a square that has a use of its own.
func _use_the_square(under: int) -> bool:
	match under:
		Tiles.FUNGUS:
			return _pick_fungus() if _can_pick_fungus() else _eat_fungus()
		Tiles.RUBBLE:
			return _knap_stones()
		Tiles.STAIRS_DOWN:
			return player_descend()
		Tiles.STAIRS_UP:
			return player_ascend()
		Tiles.SHRINE:
			return player_pray()
	return false

## Ground that `player_pickup` acts on before it ever looks at a brazier.
const _TILES_THE_KEY_TAKES := [Tiles.FUNGUS, Tiles.RUBBLE, Tiles.STAIRS_DOWN,
	Tiles.STAIRS_UP, Tiles.SHRINE]

## How full a flare with this many turns left would fill a brazier. 0 when it
## is too far gone to kindle anything.
static func flare_kindle(turns_left: int) -> int:
	for row in FLARE_KINDLE:
		if turns_left >= int(row[0]):
			return int(row[1])
	return 0

## Cells as "x,y" strings, for the save.
func _cells_to_strings(cells: Array) -> Array:
	var out := []
	for c in cells:
		out.append("%d,%d" % [c.x, c.y])
	return out

## The bestiary's row for an appearance, or {} -- for the rules a creature
## carries by kind rather than on itself (a pack animal's pack).
func _bestiary_row(app: StringName) -> Dictionary:
	for row in BESTIARY:
		if row["app"] == app:
			return row
	return {}

## Any brazier beside the player, lit, guttered or black.
func _adjacent_any_brazier() -> Vector2i:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var c := Vector2i(player.x + dx, player.y + dy)
			var t := map.get_tile(c.x, c.y)
			if t == Tiles.BRAZIER or t == Tiles.BRAZIER_SPENT or t == Tiles.BRAZIER_DEAD:
				return c
	return Vector2i(-1, -1)

## What a brazier holds now, for the flare's purposes: a guttered or black one
## holds nothing.
func _brazier_holds(c: Vector2i) -> int:
	if map.get_tile(c.x, c.y) != Tiles.BRAZIER:
		return 0
	return int(brazier_charge.get(c, 0))

## The neighbouring brazier the flare would do the most for, or (-1, -1) when
## there is none it can improve. With two beside you, the emptier one -- the
## flare's best use, and the player should not have to aim.
func flare_target() -> Vector2i:
	var give := flare_kindle(torch_flare)
	if torch_flare <= 0 or give <= 0:
		return Vector2i(-1, -1)
	var best := Vector2i(-1, -1)
	var best_holds := give
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var c := Vector2i(player.x + dx, player.y + dy)
			var t := map.get_tile(c.x, c.y)
			if t != Tiles.BRAZIER and t != Tiles.BRAZIER_SPENT and t != Tiles.BRAZIER_DEAD:
				continue
			var holds := _brazier_holds(c)
			if holds < best_holds:
				best_holds = holds
				best = c
	return best

## The flare, given to a brazier. Refuses -- keeping the flare -- when it would
## do nothing, and says why.
func player_kindle() -> bool:
	if game_over:
		return false
	var c := flare_target()
	if c.x < 0:
		if torch_flare > 0 and flare_kindle(torch_flare) <= 0:
			msg_log.add("Your flare is too far gone to kindle anything.",
				Color(0.7, 0.6, 0.4))
		else:
			msg_log.add("The fire already burns hotter than your torch.",
				Color(0.7, 0.6, 0.4))
		return false
	_travel.clear()
	var give := flare_kindle(torch_flare)
	var was := map.get_tile(c.x, c.y)
	map.set_tile(c.x, c.y, Tiles.BRAZIER)
	brazier_charge[c] = give
	# A live fire again; the ember clock belongs to the next time it dies.
	ember_until.erase(c)
	torch_flare = 0
	_gather_lights()
	# Back on the watch's round: guards tend fires, and a relit one is a fire.
	_lay_the_beat()
	_tally("kindled")
	if was == Tiles.BRAZIER_DEAD:
		msg_log.add("You thrust the flaring torch into the black brazier. It catches, "
			+ "and roars. (%d)" % give, Color(1.00, 0.82, 0.45))
	else:
		msg_log.add("You give the flare to the fire. It roars up. (%d)" % give,
			Color(1.00, 0.82, 0.45))
	msg_log.add("Your torch settles to an ordinary flame.", Color(0.80, 0.75, 0.60))
	_end_player_turn()
	return true

## FIRE RELIGHTS A COLD BRAZIER (Brad, 2026-09-30). Two or three minutes in,
## most fires on a floor have guttered, and a gem wants embers -- so the fire
## you carry can buy one back. A gem of fire is crushed into the coals for a
## brazier bigger than any is built with (the top of FLARE_KINDLE): enough to
## heal, then forge, then work the embers. A fire weapon in your hand gives up
## its fire, not itself -- it keeps its +, loses "(fire)", and can take another
## stone -- for an ordinary fire. So the choice is "this brazier, or my answer
## to the red": a fire blade is also what burns fungus in one stroke.
const GEM_KINDLE := 15
const BLADE_KINDLE := BRAZIER_CHARGE

## A guttered or black brazier beside you, or (-1, -1).
func _adjacent_cold_brazier() -> Vector2i:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var c := Vector2i(player.x + dx, player.y + dy)
			var t := map.get_tile(c.x, c.y)
			if t == Tiles.BRAZIER_SPENT or t == Tiles.BRAZIER_DEAD:
				return c
	return Vector2i(-1, -1)

## The fire you would give a cold brazier: the fire weapon IN YOUR HAND first
## (what you hold is what you chose), else a gem of fire from your pack. A
## spare fire weapon in the pack has to be taken in hand first -- deliberate,
## so the key never spends a blade you were not holding. Null for none.
func _fire_to_give() -> Item:
	if _fire_in_hand():
		return player.equipped[Item.Slot.WEAPON]
	for it in player.inventory:
		if it.kind == Item.Kind.GEM and it.element == &"fire":
			return it
	return null

func _relight_charge(fire: Item) -> int:
	return GEM_KINDLE if fire.kind == Item.Kind.GEM else BLADE_KINDLE

## G at a cold brazier with fire to give. False, spending nothing, without.
func player_relight() -> bool:
	if game_over:
		return false
	var c := _adjacent_cold_brazier()
	var fire := _fire_to_give()
	if c.x < 0 or fire == null:
		return false
	_travel.clear()
	var give := _relight_charge(fire)
	var coals := "black" if map.get_tile(c.x, c.y) == Tiles.BRAZIER_DEAD else "dying"
	map.set_tile(c.x, c.y, Tiles.BRAZIER)
	brazier_charge[c] = give
	# A live fire again; the ember clock belongs to the next time it dies.
	ember_until.erase(c)
	_gather_lights()
	_lay_the_beat()
	_tally("kindled")
	if fire.kind == Item.Kind.GEM:
		_spend_one(fire)
		msg_log.add("You crush the %s into the %s coals. The brazier roars up. (%d)"
			% [fire.name, coals, give], Color(1.00, 0.82, 0.45))
	else:
		var was := fire.display_name()
		fire.element = &""
		msg_log.add("You hold the %s to the %s coals. Its fire goes into them, and they catch. (%d)"
			% [was, coals, give], Color(1.00, 0.82, 0.45))
		msg_log.add("The %s is plain again, ready for another stone."
			% fire.display_name(), Color(0.80, 0.75, 0.60))
	_end_player_turn()
	return true

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

## WHAT THIS SQUARE OFFERS, RIGHT NOW. Drives the sidebar's contextual block.
##
## Sim-side rather than in the panel, because it is a question about the world
## and `player_pickup` already answers it. Two places deciding what `g` does
## here would be the same divergence the confirm keys just had -- and this one
## would be worse, because the panel would be telling the player something the
## game does not do.
##
## Ordered by what happens FIRST: an item underfoot wins, exactly as it does in
## player_pickup, so the line never promises the stairs while the key picks up a
## sword.
func actions_here() -> Array:
	var out := []
	# DEAD IS A CONTEXT TOO, and the one where a player most needs telling.
	#
	# Found in play on a Legion Go S: the log said "Press R to begin again" and
	# `r` is not bindable to a pad. Not a dead end -- Start opens the menu and
	# "abandon this run" is in it -- but an instruction naming a key the device
	# does not have is the third bug of that exact shape this week, after the
	# stairs and the missile confirm.
	#
	# The third element is the PAD's route to the same action, used when one is
	# in hand. `r` stays what a keyboard is told, because that is what it has
	# always been and muscle memory is worth more than consistency here.
	if game_over:
		out.append([KEY_R, "begin again", KEY_PERIOD])
		return out

	var here := items_at(player.x, player.y)
	# When the item cannot be taken, the key does what the square is for (see
	# player_pickup), so the offer has to say the same -- through the SAME
	# test, _can_take. "Full" alone was wrong once stacks and the satchel took
	# things a full pack could not (day-7 hunt, 2026-10-04): the box promised
	# the stairs while the key picked up the potion.
	var taken := not here.is_empty() and _can_take(here[0])
	if not here.is_empty() and not (not taken and here[0].id != &"arrows"
			and here[0].kind != Item.Kind.AMULET
			and map.get_tile(player.x, player.y) in _TILES_THE_KEY_TAKES):
		var it: Item = here[0]
		var row := "pick up the %s" % it.name
		# Meat on a floor with eaters is not a stash (the desktop's review,
		# 2026-10-04): the hunters eat what lies about, yours included.
		if _is_meat(it) and _eaters_about():
			row += "; eaters about"
		out.append([KEY_G, "gather arrows" if it.id == &"arrows" else row])
	else:
		match map.get_tile(player.x, player.y):
			Tiles.STAIRS_DOWN:
				out.append([KEY_G, "go down"])
			Tiles.STAIRS_UP:
				out.append([KEY_G, "climb"])
			Tiles.SHRINE:
				out.append([KEY_G, "pray"])
			Tiles.FUNGUS:
				out.append([KEY_G, "pick the fungus" if _can_pick_fungus() else "eat the fungus"])
			Tiles.RUBBLE:
				# Only when there is somewhere for the stone to GO. Reported
				# from play: the panel offered this with no sling carried, and
				# the key then refused it. A hint that promises something the
				# key will not do is worse than no hint, because the player
				# believes it and stops trusting the rest.
				if _stone_holder() != null:
					out.append([KEY_G, "knap a stone"])

	# Warming is the one thing worth saying about a NEIGHBOURING cell, because
	# it is the only action whose opportunity you can stand next to and miss.
	# Only while hurt -- offering it at full health would be noise, and
	# player_wait refuses it anyway.
	if player.hp < player.max_hp and _adjacent_brazier().x >= 0:
		out.append([KEY_PERIOD, "warm yourself"])
	# The flare's offer, only when it would do something -- and only when the
	# key would actually reach it. player_pickup acts on what is underfoot
	# first, and on RUBBLE it tries to knap even with no sling (and refuses),
	# which this list deliberately does not advertise -- so the test is the
	# key's own, not "did anything above claim g".
	if items_at(player.x, player.y).is_empty() \
			and not map.get_tile(player.x, player.y) in _TILES_THE_KEY_TAKES:
		var fire := flare_target()
		var grave := bury_target()
		if fire.x >= 0:
			out.append([KEY_G, "kindle the brazier (%d)" % flare_kindle(torch_flare)])
		elif burn_target().x >= 0 and _fire_in_hand():
			# Taught here, because this box is where players learn the game.
			out.append([KEY_G, "burn the fungus"])
		elif not grave.is_empty():
			out.append([KEY_G, "bury the %s (shovel, loud) %d/%d" % [
				String(grave["e"].get("name", grave["app"])),
				int(grave.get("dug", 0)), BURY_SPADEFULS]])
		elif burn_target().x >= 0 and _can_burn():
			out.append([KEY_G, "scorch the fungus (torch)"])
		elif disarm_target().x >= 0:
			out.append([KEY_G, "disarm the trap (%d%%)" % int(round(disarm_chance() * 100.0))])
		elif tend_target().x >= 0:
			var tc := tend_target()
			out.append([KEY_G, "feed the fire (torch) %d/%d" % [
				int(tending.get("%d,%d" % [tc.x, tc.y], 0)), TORCH_TENDING]])
		elif _adjacent_cold_brazier().x >= 0 and _fire_to_give() != null:
			var f := _fire_to_give()
			# "relight with", not "relight it with": the HERE box holds 42
			# characters of action, and "relight it with the short sword's
			# fire (10)" was 43 (Brad, 2026-10-01). The width test now runs
			# every fire-capable weapon's name through this line.
			out.append([KEY_G, ("relight with the %s (%d)" if f.kind == Item.Kind.GEM
				else "relight with the %s's fire (%d)") % [f.name, _relight_charge(f)]])
	# A GEM THAT WOULD WORK HERE says so, by the pack key (Brad, 2026-10-01:
	# he had to open the pack to find that the crag and the bulwark had a use
	# where he stood). One row at most, and only while the box has room: it
	# holds four rows with "every key", and this is the offer the pack repeats.
	if out.size() < 3:
		for gem in player.inventory:
			if gem.kind != Item.Kind.GEM:
				continue
			var said := gem_use_here(gem)
			if said != "":
				out.append([KEY_I, pack_row(said)])
				break
	return out

## The HERE box's row for something the PACK does (Brad, 2026-10-06: "set the
## gem of frost" by the i key read as a thing to do on the map, with the
## pack shut). Prefixed so the row says where it happens; the pack's own
## hint keeps the bare words (gem_use_here). The box clips at about
## HERE_ROW_CHARS: past it the gem's label gives way ("thirst: drink the
## risen kobold slinger (+12)" -> "pack: drink ..."), keeping the act and
## its number.
const HERE_ROW_CHARS := 42
static func pack_row(said: String) -> String:
	var row := "pack: " + said
	if row.length() > HERE_ROW_CHARS and said.contains(": "):
		row = "pack: " + said.substr(said.find(": ") + 2)
	return row

## What a carried gem would do from this square, in the HERE box's words, or
## "" when it has no use here. The gems thrown or used anywhere (boss, frost,
## the road) are not "here" and say nothing; fire is the relight offer above.
## The pack's hint for the same gem (InventoryPanel._action_hint) ends with
## the same words, so the box and the pack agree.
func gem_use_here(gem: Item) -> String:
	if gem_sets_here(gem):
		return "set the %s" % gem.name
	match gem.element:
		&"crag":
			if crag_target().x >= 0:
				return "crag: fill the pit"
		&"block":
			if bulwark_target().x >= 0:
				return "bulwark: bar the door"
		&"return":
			match return_target():
				&"mark": return "returning: mark the fire"
				&"return": return "returning: back to the fire"
		&"reflect":
			if mirror_target() >= 0:
				return "mirror: name the shrine"
		&"veil":
			if not _hunters().is_empty():
				return "veil: lose every hunter"
		&"leech":
			# thirst_target already refuses a plain body while you are whole.
			var body := thirst_target()
			if not body.is_empty():
				# "drink the", not "drink the": the box holds about 42
				# characters and "risen kobold slinger" is the longest body.
				return "thirst: drink %s (+%d)" % [String(body["e"].get("name", body["app"])),
					_thirst_heal(body)]
	return ""

## Which wrong fungus G would burn: the one AHEAD (your facing -- the follow
## camera's gift to this), else the one you stand on, else the nearest beside
## you, turning clockwise from your facing. (-1, -1) if none.
func burn_target() -> Vector2i:
	var here := Vector2i(player.x, player.y)
	if Tiles.is_bad_fungus(map.get_tile(here.x + player.facing.x, here.y + player.facing.y)):
		return here + player.facing
	if Tiles.is_bad_fungus(map.get_tile(here.x, here.y)):
		return here
	for i in 8:
		var d := Entity.turned(player.facing, i)
		if Tiles.is_bad_fungus(map.get_tile(here.x + d.x, here.y + d.y)):
			return here + d
	return Vector2i(-1, -1)

func _fire_in_hand() -> bool:
	var blade: Variant = player.equipped.get(Item.Slot.WEAPON, null)
	return blade != null and blade.element == &"fire"

func _can_burn() -> bool:
	return _fire_in_hand() or torch_lit

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
		if under in _TILES_THE_KEY_TAKES:
			return _use_the_square(under)
		# Nothing underfoot to act on: a flared torch next to a brazier gives
		# it the fire. A brazier is never underfoot -- it is an obstacle -- so
		# this is the one neighbouring-cell act the key has.
		if torch_flare > 0 and _adjacent_any_brazier().x >= 0:
			return player_kindle()
		# The wrong fungus, beside you or under you: a fire blade burns it in
		# one stroke, which beats everything below. Then a claimed body and a
		# shovel: bury it (loud, but the whole chain dies back). Then the
		# torch's three slow scorches.
		var fungus := burn_target()
		if fungus.x >= 0 and _fire_in_hand():
			return _burn_at(fungus)
		if not bury_target().is_empty():
			return player_bury()
		if fungus.x >= 0 and _can_burn():
			return _burn_at(fungus)
		# A found trap within reach: disarm it (a roll; see player_disarm).
		if disarm_target().x >= 0:
			return player_disarm()
		# A low fire beside you: feed it from the torch (TORCH_TENDING turns).
		if tend_target().x >= 0:
			return player_tend()
		# A cold brazier and fire to give it. After the fungus, deliberately:
		# burning costs nothing, relighting costs a gem or a blade's fire, so a
		# press meant for the red never spends it.
		if _adjacent_cold_brazier().x >= 0 and _fire_to_give() != null:
			return player_relight()
		msg_log.add("There is nothing here to pick up.", Color(0.7, 0.6, 0.4))
		return false
	# THE SATCHEL TAKES FOOD AND POTIONS, worn or in the pack (Brad,
	# 2026-10-03: the offhand only adds the key; the bag works wherever it
	# is): no pack slot spent, and the heal is a key away (the forager's
	# satchel). Ten of each kind; the eleventh goes to the pack as before.
	# The three ways in -- the satchel, a stack, a free slot -- are one
	# question, _can_take, which the HERE box asks too.
	var bag := _the_satchel()
	if bag != null and bag.satchel_takes(here[0]):
		var meal: Item = here[0]
		ground.erase(meal)
		meal.letter = ""
		var shelf := bag.satchel_shelf(meal)
		if shelf != null:
			shelf.absorb(meal)
		else:
			shelf = meal
			bag.contents.append(meal)
		_tally_in("picked", meal.name)
		msg_log.add("You put the %s in the satchel (x%d)."
			% [meal.name, shelf.count], Color(0.75, 0.80, 0.90))
		_end_player_turn()
		return true
	# A stack with room takes one more whatever the count says (2026-10-03).
	if not _can_take(here[0]):
		# A FULL PACK MUST NOT BLOCK THE SQUARE'S OWN USE. Found in the
		# 2026-09-27 hunt: an item lying on the stairs, with a full pack, made
		# this key refuse -- and on a pad this key is the only way down or up.
		# Items do land on stairs (a monster dying there, or what you drop to
		# make room, which lands back underfoot). So when the item cannot be
		# taken, the key does what the square is for, and says why the item
		# stayed. With room in the pack, the item still comes first.
		var square := map.get_tile(player.x, player.y)
		# ANY amulet on the square, not only the first item: safe either way
		# today, but only because of a ground ordering nothing guarantees.
		if square in _TILES_THE_KEY_TAKES \
				and not here.any(func(it): return it.kind == Item.Kind.AMULET):
			msg_log.add("Your pack is full; the %s stays where it lies." % here[0].name,
				Color(0.7, 0.6, 0.4))
			return _use_the_square(square)
		# Say what to DO, for anything -- the amulet included. Brad, 2026-09-27:
		# no special allowance for the amulet, but the most important pickup in
		# the game must not be refused with a message that never names it.
		msg_log.add("Your pack is full -- drop something to make room for the %s."
			% here[0].name, Color(0.9, 0.55, 0.35))
		return false
	var item: Item = here[0]
	if item.kind == Item.Kind.AMULET:
		_seize_amulet(item)
		return true
	ground.erase(item)
	var stack := _stack_for(item)
	give_item(item)
	# Counted here rather than in give_item, which the tests and the starting
	# kit also go through. This is the player deciding to bend down.
	_tally_in("picked", item.name)
	if stack != null:
		msg_log.add("You pick up the %s (%s, x%d now)." % [item.name, stack.letter, stack.count],
			Color(0.75, 0.80, 0.90))
	else:
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
	_queue_healing_cue(1)
	map.set_tile(player.x, player.y, _bare_ground(Vector2i(player.x, player.y)))
	_gather_lights()
	msg_log.add("You eat the fungus. It is bitter, and the glow goes out. (+1 hp)",
		Color(0.62, 0.85, 0.68))
	_end_player_turn()
	return true

## THE FORAGER'S SATCHEL. The one you wear, else the first in the pack (in
## the pack it still works, at the same cost), else null.
func _worn_satchel() -> Item:
	var off: Variant = player.equipped.get(Item.Slot.OFFHAND, null)
	return off if off != null and off.is_satchel() else null

func _the_satchel() -> Item:
	var worn := _worn_satchel()
	if worn != null:
		return worn
	for it in player.inventory:
		if it.is_satchel():
			return it
	return null

## What the satchel you would open holds, in its order.
func satchel_items() -> Array:
	var bag := _the_satchel()
	return bag.contents if bag != null else []

## Carried, with room on the fungus shelf.
func _can_pick_fungus() -> bool:
	var bag := _the_satchel()
	return bag != null and bag.satchel_takes(Item.make(&"fungus"))

## Fungus picked where it grew goes into the worn satchel, stacked; the
## tile is bare floor after, and its light is gone, as when it is eaten.
func _pick_fungus() -> bool:
	var bag := _the_satchel()
	var picked := Item.make(&"fungus")
	var stack := bag.satchel_shelf(picked)
	if stack == null:
		stack = picked
		bag.contents.append(stack)
	else:
		stack.absorb(picked)
	map.set_tile(player.x, player.y, _bare_ground(Vector2i(player.x, player.y)))
	_gather_lights()
	msg_log.add("You pick the fungus. Its glow goes with it into the satchel (x%d)." % stack.count,
		Color(0.62, 0.85, 0.68))
	_end_player_turn()
	return true

## Using something from the satchel: the item's own effect, one of a stack,
## and a turn -- the same turn a potion from the pack costs.
func player_use_from_satchel(index: int) -> bool:
	if game_over:
		return false
	var bag := _the_satchel()
	if bag == null or index < 0 or index >= bag.contents.size():
		return false
	_travel.clear()
	var item: Item = bag.contents[index]
	if not _apply_effect(item):
		return false
	if item.count > 1:
		item.count -= 1
	else:
		bag.contents.remove_at(index)
	_end_player_turn()
	return true

## Setting something down out of the satchel. Fungus TAKES ROOT where you
## stand -- an ordinary fungus tile: light, bait and food again, with no new
## rules -- on open floor only. Anything else is dropped as from the pack.
func player_drop_from_satchel(index: int) -> bool:
	if game_over:
		return false
	var bag := _the_satchel()
	if bag == null or index < 0 or index >= bag.contents.size():
		return false
	_travel.clear()
	var item: Item = bag.contents[index]
	if item.id == &"fungus":
		# Plain floor or mud (2026-10-08: mud is a garden bed).
		if not _fungus_ground(Vector2i(player.x, player.y)):
			msg_log.add("It would not take root here.", Color(0.7, 0.6, 0.4))
			return false
		if item.count > 1:
			item.count -= 1
		else:
			bag.contents.remove_at(index)
		_note_mud(Vector2i(player.x, player.y))
		map.set_tile(player.x, player.y, Tiles.FUNGUS)
		_gather_lights()
		msg_log.add("You set the fungus down. It takes root, and glows.", Color(0.62, 0.85, 0.68))
		_end_player_turn()
		return true
	# One at a time, as from the pack ("one leaves at a time", 2026-10-03).
	# This took the WHOLE shelf -- ten potions on the floor -- while the log
	# said "drop it" (day-7 hunt, 2026-10-04).
	var left := item.count - 1
	var dropped := item
	if left > 0:
		item.count = left
		dropped = item.split_one()
	else:
		bag.contents.remove_at(index)
	dropped.letter = ""
	dropped.x = player.x
	dropped.y = player.y
	ground.append(dropped)
	if left > 0:
		msg_log.add("You take one %s out of the satchel and drop it (x%d left)."
			% [dropped.name, left])
	else:
		msg_log.add("You take the %s out of the satchel and drop it." % dropped.name)
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
## The sling a knapped stone would go into, or null when there is none with room.
##
## In HAND first, then the pack -- Gabe's point: rubble could only be worked
## while the sling was equipped, so topping up meant swapping to it and back, a
## turn at each end.
##
## Extracted so the sidebar hint and the action itself cannot disagree. They did:
## the panel offered "knap a stone" while carrying no sling at all.
func _stone_holder() -> Item:
	var held: Variant = player.equipped.get(Item.Slot.WEAPON, null)
	if held != null and held.ammo_kind == &"stone" and held.ammo < held.ammo_max:
		return held
	for it in player.inventory:
		if it.ammo_kind == &"stone" and it.ammo < it.ammo_max:
			return it
	return null

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
	var sling := _stone_holder()
	var any_sling := false
	for it in player.inventory:
		if it.ammo_kind == &"stone":
			any_sling = true
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
	# The floor's gem pile. Only reachable through a knap that SUCCEEDS: a full
	# pouch refuses above on every pile alike, so trying piles with no room can
	# never tell you which one holds it.
	var here := Vector2i(player.x, player.y)
	if here == geode:
		geode = Vector2i(-1, -1)
		# The rubble roll, which alone can give a gem of the road.
		var gem := Item.roll_rubble_gem(geode_rng, effective_depth())
		if gem != null:
			gem_found = true
			_tally("geodes")
			msg_log.add("Something glints in the broken stone: a %s!" % gem.name,
				Color(0.85, 0.90, 1.00))
			if not give_item(gem):
				_drop_item_at(gem, here)
				msg_log.add("Your pack is full; it lies at your feet.",
					Color(0.9, 0.55, 0.35))
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
	# COLD, not gone (Brad, 2026-09-30: the ring became the key to the red, so
	# it must survive to be used again). You still turn back wherever you are
	# standing -- the horror of running dry mid-room stays -- but you keep the
	# ring, and a gem at the embers warms it (RING_FEED).
	ring.charges = 0
	player.equipped.erase(Item.Slot.WEAPON)
	msg_log.add("The ring goes cold on your paw, and you are yourself again.",
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
		var putting_on := not player.is_equipped(item)
		if putting_on and item.transforms() and item.charges <= 0:
			msg_log.add("The ring is cold. A gem at the embers would warm it.",
				Color(0.7, 0.6, 0.4))
			return false
		# Worn gear is not in the pack, so taking it off needs a slot to put it
		# in. Putting something else ON in its place is a swap and needs none
		# -- unless it comes OFF A STACK, which stays behind in the pack while
		# the old piece comes in: that is one more, and the letters are gone.
		var displaces: bool = player.equipped.has(item.slot) \
			or (item.is_two_handed() and player.equipped.has(Item.Slot.OFFHAND)
				and not player.equipped[Item.Slot.OFFHAND].is_satchel())
		var needs_room: bool = (not putting_on) or (item.count > 1 and displaces)
		if needs_room and player.pack_count() >= Entity.INVENTORY_MAX:
			msg_log.add("Your pack is full; there is nowhere to put the %s. Drop something first."
				% (item.name if not putting_on else player.equipped[item.slot].name
				if player.equipped.has(item.slot) else "shield"), Color(0.9, 0.55, 0.35))
			return false
		_toggle_equip(item)
		# Time to get INTO it -- see Item.don_turns. Taking it off is one turn.
		var took := item.don_turns if putting_on else 1
		if took > 1:
			msg_log.add("It takes %d turns to get into the %s." % [took, item.name],
				Color(0.80, 0.78, 0.62))
		_end_player_turn(Scheduler.ACTION_COST * took)
		return true

	# At the embers with something to set it into, a gem is SET, not spent on
	# its own use (gem_sets_here). The pack's hint and the HERE box say so.
	if item.kind == Item.Kind.GEM and gem_sets_here(item):
		return player_bind(index)
	# A refused effect costs neither the item nor the turn. Wasting a potion to
	# a misclick is the kind of thing that makes people stop playing.
	if not _apply_effect(item):
		return false
	# The shovel is kept, dull, for a gem to sharpen (6c). One off a stack;
	# the slot and its letter stay while any remain, so "drink, drink" works.
	if not item.dulls() and player.inventory.has(item):
		_spend_one(item)
	# EVERY potion and every meal costs a turn. A "first one each turn is free"
	# rule, after D&D's bonus action, was built and taken out again on
	# 2026-09-24. Free in combat it makes fights easier, which Brad did not
	# want; free only out of combat it does nearly nothing, because a turn with
	# nothing hostile in view is worth almost nothing. There was no version of
	# it that earned its place. _test_every_draught_costs_a_turn holds the line.
	_end_player_turn()
	return true

func _toggle_equip(item: Item) -> void:
	if player.is_equipped(item):
		player.equipped.erase(item.slot)
		msg_log.add("You put away the %s." % item.name)
		return
	# Off a stack: the one you wear is its own item from now on, in its own
	# slot right after the stack (Brad, 2026-10-03: three plain daggers in
	# three slots asked for gear to stack; the worn one still has to be ONE).
	if item.count > 1:
		var one := item.split_one()
		one.letter = _free_letter()
		item.count -= 1
		player.inventory.insert(player.inventory.find(item) + 1, one)
		item = one
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
	# The satchel hangs on a strap and takes no hand (Brad, 2026-10-01: it
	# put his weapon on his back): a bow and the satchel are carried together.
	if item.is_two_handed():
		displaced = player.equipped.get(Item.Slot.OFFHAND, null)
		if displaced != null and displaced.is_satchel():
			displaced = null
		if displaced != null:
			player.equipped.erase(Item.Slot.OFFHAND)
	elif item.slot == Item.Slot.OFFHAND and not item.is_satchel():
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
	# IT LIVES WITH YOU (Brad, 2026-10-03). Dropping it would strand a floor's
	# worth of food on the ground or hide it in a line of text; it cannot be
	# sold or thrown either. Found once, the satchel is yours for the run.
	if item.is_satchel():
		msg_log.add("The satchel stays with you.", Color(0.7, 0.6, 0.4))
		return false
	var left := item.count - 1
	# Dropping something you are wearing takes it off first, rather than
	# leaving a dangling reference in `equipped`. Off a stack, one goes.
	var dropped := _spend_one(item)
	dropped.x = player.x
	dropped.y = player.y
	ground.append(dropped)
	if left > 0:
		msg_log.add("You drop one %s (x%d left)." % [dropped.name, left])
	else:
		msg_log.add("You drop the %s." % dropped.name)
	_end_player_turn()
	return true

## Returns false if the item declined to be used, in which case it is not spent.
func _apply_effect(item: Item) -> bool:
	# A gem is not drunk or read. The gem of thirst is the one used on its
	# own -- on a body -- and the rest say where they ARE used, instead of the
	# click doing nothing at all (it did, until 2026-10-01).
	if item.kind == Item.Kind.GEM:
		if item.element == &"leech":
			return _drink_the_dead(item)
		if item.element == &"reflect":
			return _show_the_shrine(item)
		if item.element == &"crag":
			return _fill_the_pit(item)
		if item.element == &"block":
			return _bar_the_door(item)
		if item.element == &"return":
			return _recall(item)
		if item.element == &"travel":
			return _show_the_road(item)
		if item.element == &"veil":
			return _vanish(item)
		if item.element == &"lantern":
			return _flare_with(item)
		if item.element == &"frost":
			msg_log.add("The gem of frost is thrown: it freezes the room it lands in.",
				Color(0.7, 0.6, 0.4))
			return false
		msg_log.add("A gem is set into your gear at a brazier's embers."
			+ (" The gem of the boss can also be thrown." if item.element == &"bash" else ""),
			Color(0.7, 0.6, 0.4))
		return false
	match item.effect:
		&"summon":
			return _summon_ally(item)
		&"raise_corpse":
			if item.dull:
				msg_log.add("The shovel's edge is gone. A gem at the embers would put it back.",
					Color(0.7, 0.6, 0.4))
				return false
			if not _raise_the_recent_dead():
				return false
			if item.dulls():
				if item.laid_to_rest >= BURIALS_TO_SHARPEN:
					# The graves already dug pay for this one (Gabe's rule).
					item.laid_to_rest = 0
					msg_log.add("The graves you dug keep the shovel's edge.",
						Color(0.80, 0.85, 0.70))
				else:
					item.dull = true
					msg_log.add("The shovel's edge is spent.", Color(0.70, 0.66, 0.58))
			return true

		&"open_sack":
			return _open_sack()

		&"heal":
			if player.hp >= player.max_hp:
				msg_log.add("You are already whole.", Color(0.7, 0.6, 0.4))
				return false
			var healed := mini(item.effective_magnitude(), player.max_hp - player.hp)
			player.hp += healed
			_queue_healing_cue(healed)
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
					if not _can_land_on(x, y):
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
	var route := pathfinder.path(Vector2i(player.x, player.y), to, true, true)
	if route.is_empty():
		return false
	_travel = route
	# A click is an explicit movement command. If a monster is watching, honour
	# that command for one cell, then stop the queued travel before it can
	# overshoot into danger. The next click is another deliberate step.
	return _step_travel(true)

func travelling() -> bool:
	return not _travel.is_empty()

## Advances one step of a queued mouse-travel. Stops for anything interesting.
func step_travel() -> bool:
	return _step_travel(false)

func _step_travel(allow_watched_first_step: bool) -> bool:
	if _travel.is_empty() or game_over:
		return false
	var watched := not _travel_stoppers().is_empty()
	if watched and not allow_watched_first_step:
		_travel.clear()
		msg_log.add("You stop -- something is watching.", Color(0.9, 0.55, 0.35))
		return false
	var next := _travel[0]
	var dx := next.x - player.x
	var dy := next.y - player.y
	# Never walk someone into the wrong fungus on their behalf. Monsters cross
	# red freely; the player's route stops short and says why.
	if Tiles.is_bad_fungus(map.get_tile(next.x, next.y)):
		_travel.clear()
		msg_log.add("You stop short of the %s fungus." % ("purple"
			if map.get_tile(next.x, next.y) == Tiles.FUNGUS_PURPLE else "red"),
			Color(0.9, 0.55, 0.35))
		return false
	if entity_at(next.x, next.y) != null or not map.is_walkable(next.x, next.y):
		_travel.clear()
		return false
	# A SHUT DOOR IS OPENED, not walked into. Closed doors are walkable -- you
	# can always get through one -- so the old check let travel set you down
	# INSIDE a shut, opaque door, skipping the open that player_move does.
	# Found in the 2026-09-27 hunt: guards shutting doors on a route made it
	# common, but a route through any door you had shut yourself could do it.
	# Opening costs the turn, as a step does; travel carries on next turn.
	# A rat squeezes under instead, exactly as player_move lets it.
	if map.get_tile(next.x, next.y) == Tiles.DOOR_CLOSED and not ratted():
		map.set_tile(next.x, next.y, Tiles.DOOR_OPEN)
		pathfinder.set_solid(next.x, next.y, false)
		_work_the_door(next, "You pull the door open.")
		return true
	# A latched gate on the route: lifted like a door; a rat stops at it.
	if map.get_tile(next.x, next.y) == Tiles.GATE_CLOSED:
		if ratted():
			_travel.clear()
			msg_log.add("A latched gate. A rat cannot get past it.", Color(0.7, 0.6, 0.4))
			return false
		map.set_tile(next.x, next.y, Tiles.GATE_OPEN)
		_set_gate_route(next)
		_work_the_door(next, "You lift the latch and swing the gate open.")
		return true
	if map.get_tile(next.x, next.y) == Tiles.DOOR_BARRED and not ratted():
		_unbar(next)
		return true
	# A trap found since the route was laid: stop and let the player choose.
	if map.get_tile(next.x, next.y) == Tiles.TRAP:
		_travel.clear()
		msg_log.add("You stop at the trap.", Color(0.9, 0.55, 0.35))
		return false
	# An unseen trap under the next step springs, and the walk ends there.
	if hidden_traps.has(next):
		_travel.clear()
		hidden_traps.erase(next)
		msg_log.add("The floor clicks under your foot.", Color(0.92, 0.48, 0.40))
		_spring_trap(next.x, next.y)
		if not player.alive:
			return true
		player.facing = Vector2i(signi(next.x - player.x), signi(next.y - player.y))
		player.x = next.x
		player.y = next.y
		_end_player_turn(move_cost_for(player, next.x, next.y))
		return true
	_travel.remove_at(0)
	if watched:
		_travel.clear()
	# Deliberately not player_move(): that clears the travel queue.
	var cost := move_cost_for(player, next.x, next.y)
	player.facing = Vector2i(signi(next.x - player.x), signi(next.y - player.y))
	player.x = next.x
	player.y = next.y
	_end_player_turn(cost)
	return true

func _end_player_turn(cost: int = Scheduler.ACTION_COST) -> void:
	Scheduler.spend(player, cost)
	turns += 1
	# The "move into it again" warning holds for one move only.
	_meant = null
	_tick_returning()
	_thaw_rooms()
	_spot_traps()
	_rot_bodies()
	# The cost was already being computed and thrown away. Difficult ground has
	# always charged the world for the time it takes; this is the first thing
	# that charges the record too.
	elapsed += cost
	_note_footing()
	_note_rooms()
	var underfoot := map.get_tile(player.x, player.y)
	# Eight inches of rat crossing a boneyard makes no sound worth hearing.
	# The sharpest thing the ring buys: it is the only way past a gravestone
	# in bones without waking what is under it.
	if not ratted():
		_make_noise(Vector2i(player.x, player.y), Tiles.noise_radius(underfoot))
	_burn_the_ring()
	_fungus_underfoot(underfoot)
	if game_over:
		return
	_wash(player)
	if _acid_bites(player):
		game_over = true
		death_cause = "eaten by a slime's acid"
		events.append({"kind": &"death", "to": Vector2i(player.x, player.y)})
		write_morgue()
		write_death_dump()
		return
	if _breathe(player):
		game_over = true
		death_cause = "poisoned by the miasma"
		events.append({"kind": &"death", "to": Vector2i(player.x, player.y)})
		write_morgue()
		write_death_dump()
		return
	if underfoot == Tiles.BONES:
		# Crossing it destroys it. That turns a boneyard from a standing toll
		# into something you can PREPARE -- walk it once while things are
		# asleep and far off, and you have bought yourself a silent route for
		# when you need one.
		# Keep the stepped-on tile for the renderer: the map changes below before
		# sync_motion can sample it. Fx consumes this presentation-only event in
		# both renderers; it does not change the bone tile's gameplay rules.
		events.append({"kind": &"bone_step", "to": Vector2i(player.x, player.y)})
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
		elif flare_kindle(torch_flare) != flare_kindle(torch_flare + 1):
			# The race made visible: each step down is said, so the player
			# learns the flare is worth less by the turn without doing sums.
			var now := flare_kindle(torch_flare)
			if now > 0:
				msg_log.add("Your flare dims. It would kindle a fire to %d now." % now,
					Color(0.95, 0.80, 0.45))
			else:
				msg_log.add("Your flare is too far gone to kindle a fire. It is only "
					+ "light now.", Color(0.80, 0.75, 0.60))
	_burn_the_fires_down()
	_let_the_stone_settle()
	update_vision()
	_run_world()
	_spring_under_allies()
	_grow_fungus()
	_warn_of_red_allies()
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

## Emit a cue only for hit points that have actually been restored. Fx suppresses
## its moving ring in "still" mode, leaving the health bar and message as the
## feedback there.
func _queue_healing_cue(amount: int) -> void:
	if amount <= 0:
		return
	events.append({"kind": &"healed", "to": Vector2i(player.x, player.y),
		"amount": amount})

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
	var bars := {}
	for cell in barred:
		bars["%d,%d" % [cell.x, cell.y]] = int(barred[cell])
	var frozen := []
	for fr in frozen_rooms:
		var fr_rect: Rect2i = fr[0]
		frozen.append([fr_rect.position.x, fr_rect.position.y, fr_rect.size.x, fr_rect.size.y,
			int(fr[1])])
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
		"braziers": charges, "embers": embers, "spires": stone, "barred": bars,
		"barred_gates": _cells_to_strings(barred_gates.keys()),
		"frozen": frozen, "recall": [recall_mark.x, recall_mark.y], "road": road_shown,
		"caves": caves, "rooms": rooms,
		"shrines": _shrines_to_dict(), "graves": _graves_to_dict(),
		"grave_risen": grave_risen,
		"recent_dead": recent_dead,
		"bodies": bodies,
		"fallen": fallen, "fell": something_fell,
		"reload_rng": [str(reload_rng.seed), str(reload_rng.state)],
		"reload_said": _reload_said,
		"fungus_rng": [str(fungus_rng.seed), str(fungus_rng.state)],
		"trap_rng": [str(trap_rng.seed), str(trap_rng.state)],
		"drink_rng": [str(drink_rng.seed), str(drink_rng.state)],
		"nap_rng": [str(nap_rng.seed), str(nap_rng.state)],
		"hunger_rng": [str(hunger_rng.seed), str(hunger_rng.state)],
		"hidden_traps": _cells_to_strings(hidden_traps.keys()),
		"scorched": scorched,
		"mud_under": _cells_to_strings(mud_under.keys()),
		"tending": tending,
		"red_from": _red_from_rows(),
		"withering": withering.map(func(chain): return chain.map(
			func(c): return [c.x, c.y])),
		"gem_found": gem_found,
		"rooms_found": rooms_found.keys(),
		"player_name": player_name,
		"uniques": uniques_found.keys(),
		"cave_vaults_seen": cave_vaults_seen,
		"risen_grave": [risen_grave.x, risen_grave.y],
		"hues": shrine_hues,
		"known": shrine_known.keys(), "forge_bonus": forge_cap_bonus,
		"flare": torch_flare,
		"entities": mobs, "player": entities.find(player),
		"ground": loot, "log": lines,
		"trader": _trader_to_dict(),
		"reclaimed_run": reclaimed_this_run,
	}

## The trader's counter, for the suspend slot. It was never saved before
## because it only ever talked; with stock and credit, a suspend would have
## restocked the shelves and wiped the slate.
func _trader_to_dict() -> Dictionary:
	var stock := []
	for entry in trader_stock:
		stock.append({"item": (entry["item"] as Item).to_dict(),
			"relic": entry["relic"], "hero": entry["hero"],
			"yours": bool(entry.get("yours", false))})
	return {"stock": stock, "credit": trader_credit, "gems": trader_gems,
		"rolled": trader_rolled,
		# Strings, like the main rng: JSON would round a 64-bit state.
		"rng": [str(trader_rng.seed), str(trader_rng.state)],
		# The gem pile rides with the trader's record rather than beside it:
		# both are "this floor's hidden state", saved and restored together.
		"geode": [geode.x, geode.y],
		"geode_rng": [str(geode_rng.seed), str(geode_rng.state)]}

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
	barred.clear()
	barred_gates.clear()
	var bars: Dictionary = d.get("barred", {})
	for key in bars:
		var bits: PackedStringArray = String(key).split(",")
		if bits.size() == 2:
			barred[Vector2i(bits[0].to_int(), bits[1].to_int())] = int(bars[key])
	for key in d.get("barred_gates", []):
		var bits: PackedStringArray = String(key).split(",")
		if bits.size() == 2:
			barred_gates[Vector2i(bits[0].to_int(), bits[1].to_int())] = true
	frozen_rooms.clear()
	for row in d.get("frozen", []):
		if row.size() == 5:
			frozen_rooms.append([Rect2i(int(row[0]), int(row[1]), int(row[2]), int(row[3])),
				int(row[4])])
	var rm: Array = d.get("recall", [-1, -1])
	recall_mark = Vector2i(int(rm[0]), int(rm[1])) if rm.size() == 2 else Vector2i(-1, -1)
	road_shown = bool(d.get("road", false))
	_road_cache.clear()

	shrine_at.clear()
	var saved_shrines: Dictionary = d.get("shrines", {})
	for key in saved_shrines:
		var bits: PackedStringArray = String(key).split(",")
		if bits.size() == 2:
			shrine_at[Vector2i(bits[0].to_int(), bits[1].to_int())] = int(saved_shrines[key])
	grave_risen = d.get("grave_risen", false)
	recent_dead = d.get("recent_dead", [])
	bodies = d.get("bodies", [])
	fallen = d.get("fallen", [])
	something_fell = bool(d.get("fell", false))
	var rrng: Array = d.get("reload_rng", [])
	if rrng.size() == 2:
		reload_rng.seed = str(rrng[0]).to_int()
		reload_rng.state = str(rrng[1]).to_int()
	_reload_said = bool(d.get("reload_said", false))
	var frng: Array = d.get("fungus_rng", [])
	if frng.size() == 2:
		fungus_rng.seed = str(frng[0]).to_int()
		fungus_rng.state = str(frng[1]).to_int()
	var traps_rng: Array = d.get("trap_rng", [])
	if traps_rng.size() == 2:
		trap_rng.seed = str(traps_rng[0]).to_int()
		trap_rng.state = str(traps_rng[1]).to_int()
	var drinks_rng: Array = d.get("drink_rng", [])
	if drinks_rng.size() == 2:
		drink_rng.seed = str(drinks_rng[0]).to_int()
		drink_rng.state = str(drinks_rng[1]).to_int()
	var naps_rng: Array = d.get("nap_rng", [])
	if naps_rng.size() == 2:
		nap_rng.seed = str(naps_rng[0]).to_int()
		nap_rng.state = str(naps_rng[1]).to_int()
	var hungers_rng: Array = d.get("hunger_rng", [])
	if hungers_rng.size() == 2:
		hunger_rng.seed = str(hungers_rng[0]).to_int()
		hunger_rng.state = str(hungers_rng[1]).to_int()
	hidden_traps.clear()
	for key in d.get("hidden_traps", []):
		var bits: PackedStringArray = String(key).split(",")
		if bits.size() == 2:
			hidden_traps[Vector2i(bits[0].to_int(), bits[1].to_int())] = true
	mud_under = {}
	for key in d.get("mud_under", []):
		var bits: PackedStringArray = String(key).split(",")
		if bits.size() == 2:
			mud_under[Vector2i(bits[0].to_int(), bits[1].to_int())] = true
	scorched = {}
	var sc: Dictionary = d.get("scorched", {})
	for k in sc:
		scorched[String(k)] = int(sc[k])
	tending = {}
	var td: Dictionary = d.get("tending", {})
	for k in td:
		tending[String(k)] = int(td[k])
	red_from = {}
	for row in d.get("red_from", []):
		red_from[Vector2i(int(row[0]), int(row[1]))] = Vector2i(int(row[2]), int(row[3]))
	withering = []
	for chain in d.get("withering", []):
		var squares: Array = []
		for c in chain:
			squares.append(Vector2i(int(c[0]), int(c[1])))
		withering.append(squares)
	# Derived from the map rather than saved, so a resumed run does not depend
	# on a route written by an older version of this code.
	_lay_the_beat()
	gem_found = d.get("gem_found", false)
	rooms_found = {0: true}
	for i in d.get("rooms_found", []):
		rooms_found[int(i)] = true
	player_name = String(d.get("player_name", ""))
	uniques_found.clear()
	for k in d.get("uniques", []):
		uniques_found[StringName(k)] = true
	cave_vaults_seen = {}
	var caves_met: Dictionary = d.get("cave_vaults_seen", {})
	for k in caves_met:
		var turns_met: Array = []
		for t in caves_met[k]:
			turns_met.append([int(t[0]), bool(t[1])])
		cave_vaults_seen[String(k)] = turns_met
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
		var loaded := Entity.from_dict(entry)
		# A save from before 2026-10-04 has no appetite recorded: the bear in
		# it would load without one and never hunt. Backfilled from the
		# bestiary by appearance, once, for saves that lack the key.
		if not entry.has("eats") and not loaded.is_player:
			for row in BESTIARY:
				if row["app"] == loaded.appearance:
					loaded.eats = bool(row.get("eats", false))
		entities.append(loaded)
	var pi := int(d.get("player", 0))
	if pi < 0 or pi >= entities.size():
		return false
	player = entities[pi]
	# Derived, never stored: the torch is rebuilt from the saved torch_lit.
	player.light = LightSource.new(player.x, player.y, TORCH_RADIUS,
		Color(1.00, 0.72, 0.36), Color(0.30, 0.34, 0.55), 1.0, true)

	# The trader, relinked by WHO it is, not by its side. It used to take the last
	# living neutral, which was the trader only because it was the only neutral
	# on a floor -- and neutral was chosen so that others (wolves, mercenaries)
	# could inherit it. With a second neutral, a save and load would point
	# `trader` at that one, and its death would stop the real trader trading for
	# the rest of the floor. Found in the 2026-09-27 hunt.
	trader = null
	for e in entities:
		if e.appearance == &"trader" and e.faction == Entity.Faction.NEUTRAL and e.alive:
			trader = e
			break
	var tr: Dictionary = d.get("trader", {})
	trader_stock = []
	for entry in tr.get("stock", []):
		var it := Item.from_dict(entry.get("item", {}))
		if it != null:
			trader_stock.append({"item": it, "relic": String(entry.get("relic", "")),
				"hero": String(entry.get("hero", "")),
				"yours": bool(entry.get("yours", false))})
	trader_credit = int(tr.get("credit", 0))
	trader_gems = int(tr.get("gems", 0))
	trader_rolled = bool(tr.get("rolled", false))
	var trng: Array = tr.get("rng", [])
	if trng.size() == 2:
		trader_rng.seed = str(trng[0]).to_int()
		trader_rng.state = str(trng[1]).to_int()
	# A save from before gems were hidden in rubble has none on this floor.
	var hidden: Array = tr.get("geode", [-1, -1])
	geode = Vector2i(int(hidden[0]), int(hidden[1]))
	var grng: Array = tr.get("geode_rng", [])
	if grng.size() == 2:
		geode_rng.seed = str(grng[0]).to_int()
		geode_rng.state = str(grng[1]).to_int()
	reclaimed_this_run = Array(d.get("reclaimed_run", []))
	# A save written before the trader existed has no shelves to restore, yet
	# the floor still has its trader standing on it. Without this the player
	# meets a trader with nothing to sell -- which is what happened on the
	# first playtest, 2026-09-24, from a suspend made the day before.
	if trader != null and not d.has("trader"):
		_stock_trader()

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
	_stack_the_pack()
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
	# An escape already says the Amulet in its fate; saying it twice read as
	# "...with the Amulet of the Deep, with the Amulet, after..." (Brad's first
	# Legends entry, 2026-09-30). The importer's escape pattern skips to
	# ", after", so both forms still read.
	var line := "%s  level %d  %s, after %d turns" % [when, player.level, fate, turns] \
		if won else "%s  level %d  %s, %s, after %d turns" \
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
	# Every ending comes through here, so this is where the run's suspend slot
	# goes. It used to survive the ending: the web build writes the slot on
	# every tab switch, so after a death, reloading the page brought you back
	# alive from before the fatal fight -- and after a win, back to the top of
	# the stairs. Brad's itch morgue holds his one escape TWICE, 22 hours
	# apart, same turn count: the win, replayed from a slot written before it.
	clear_suspend()
	# The full record, BEFORE the text line: the very first record imports the
	# text morgue, and must not find this run already in it. See LegendsLog.
	LegendsLog.record(self)
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
	# Frozen (the gem of frost): it stands there, the turn spent. It thaws on
	# your turns, in _thaw_rooms, not on its own. Before the risen and
	# everything else, because it is true of all of them.
	if actor.frozen > 0:
		return Scheduler.ACTION_COST

	# A climber in the stone that is no longer fleeing comes down first: no
	# route starts inside a wall, and it should not hide there for ever.
	if actor.climbs and not actor.fleeing and not map.is_walkable(actor.x, actor.y):
		_climb_down(actor)
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

	# The risen have no awareness to update and nothing to feel: the red
	# walks them at whatever is in their room. See _ai_risen.
	if actor.faction == Entity.Faction.RISEN:
		_last_move_cost = Scheduler.ACTION_COST
		_ai_risen(actor)
		return _last_move_cost

	_grow_hungry(actor)

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

	# AN ANIMAL, UNSTRUCK, LIVES ITS OWN LIFE (Brad, 2026-10-04). Awareness
	# above still runs -- it notices you, and the sidebar says so -- but
	# noticing is not hunting. Struck, it falls through to everything below
	# like any monster, with you its foe (Entity.hostile_to).
	if actor.is_wild() and not actor.provoked:
		# Struck by something not on your side, it fights THAT -- a bear with
		# a goblin's spear in it has a goblin problem, not a you problem. A
		# forager never fights; its grudge is what it runs from (_ai_wild).
		var score := actor.grudge
		if score != null and actor.ai != &"forager" and _minds(actor, score):
			_ai_hunter(actor, score)
			return _last_move_cost
		_ai_wild(actor)
		return _last_move_cost

	# A careful guard shuts the door it just came through. See _shut_behind.
	if actor.alertness != Entity.Alert.AWAKE and _shut_behind(actor):
		return _last_move_cost

	# Opportunistic, and checked BEFORE the activity below rather than being one
	# of them: a guard can walk its round and still stoop for a blade. Only
	# while unaware -- nothing stops mid-fight to try on armour.
	if actor.alertness != Entity.Alert.AWAKE and actor.scavenges \
			and _scavenge(actor):
		return _last_move_cost

	# THEY HAVE TO EAT TOO (Brad, 2026-10-04). While unaware of you, a
	# hunter with `eats` goes after the wild for food, and eats the kill.
	# Gated like scavenging: nothing stops mid-fight for supper.
	if actor.alertness != Entity.Alert.AWAKE and actor.eats and _hunt(actor):
		return _last_move_cost

	# Rats go to fresh bodies when they are not hunting you.
	if actor.alertness != Entity.Alert.AWAKE and actor.appearance == &"rat" \
			and _rat_to_body(actor):
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
				_ai_forager(actor, _what_scares(actor))
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
		# CHASED: fleeing in your light and your sight, turns running. Dark,
		# or out of sight, and the count starts again.
		if map.is_visible(actor.x, actor.y) \
				and light_map.get_light(actor.x, actor.y).get_luminance() >= CHASE_LIGHT:
			actor.chased += 1
		else:
			actor.chased = 0
		if actor.chased >= CHASED_TURNS and _leap_into_a_pit(actor, foe):
			return _last_move_cost
		_ai_flee(actor, foe)
		return _last_move_cost

	# LOST, IT GOES WHERE IT LAST SAW YOU (Brad, 2026-10-04). Until then every
	# awake thing steered by your true position, seen or not: `last_seen` was
	# written in seven places and read in none, so the boss gem's decoy fooled
	# nothing and a far noise pulled the floor toward YOU. Only a sight of you
	# moves the mark (_update_awareness). Not for what senses life -- it never
	# needed to see you -- nor a forager, whose "foe" is what it runs from.
	# But something it can SEE beats a memory (Brad, 2026-10-04): with your
	# ally in view it turns on the ally, and walks your trail only when there
	# is nothing in front of it.
	if foe.is_player and actor.lost_turns > 0 and not actor.senses \
			and actor.ai != &"forager":
		var in_view := _foe_for(actor, true)
		if in_view == null:
			_seek_last_seen(actor)
			return _last_move_cost
		foe = in_view

	match actor.ai:
		&"slime":   _ai_slime(actor, foe)
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
		m.patrol_at = _nearest_post(Vector2i(m.x, m.y))

## THE GUARD STARTS AT ITS NEAREST POST (2026-10-07). Every guard used to start
## its round at post 0, so every guard on the floor walked to the same brazier
## first and then the same round in the same order: they converged and walked
## as a convoy -- Brad's "lines of four", and the seven guards the first
## pre-run piled into one room. Measured over 300 turns of rounds on fortress
## floors: 15 of 23 floors ended with a room over its threat ceiling, the
## worst by 102. Starting each at the post nearest where it was placed spreads
## them round the circuit, and walking the same way at the same pace they
## stay spread. Nearest by steps, the lowest index on a tie: no draw.
func _nearest_post(at: Vector2i) -> int:
	var best := 0
	var best_d := 1 << 30
	for i in patrol_route.size():
		var post: Vector2i = patrol_route[i]
		var d := Los.steps(at.x, at.y, post.x, post.y)
		if d < best_d:
			best_d = d
			best = i
	return best

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
	# Not in the pre-run: gear taken up raises threat past the ceiling.
	if _prerunning:
		return false
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
	# A round re-laid mid-floor (a fire spent at the forge) re-deals the beats.
	_assign_beats()

## EACH GUARD WALKS ITS OWN BEAT (2026-10-07). On one shared one-way round the
## guards formed convoys whatever they started from: anything that costs the
## guard in front a turn -- a door shut behind it, a fire stoked, a sleeper
## stepped round -- lets the one behind close up, and nothing ever opens the
## gap again, so every guard on the round ends in one line (Brad's "lines of
## four"; the first pre-run's seven guards in one room). Measured over 300
## turns on fortress floors: two guards in three walking within two cells of
## another, up to seven in one room, 15 floors of 23 with a room over its
## ceiling. Starting each at its nearest post only moved that to one in two.
## So the round is dealt out: the guards, in order of the post nearest each,
## get consecutive stretches of it, at least two posts each, and walk their
## stretch back and forth. Two guards meet only at the ends of their beats.
## No draw: the deal is fixed by where they stand.
func _assign_beats() -> void:
	var size := patrol_route.size()
	if size < 2:
		return
	var guards: Array = []
	for e in entities:
		# Only what walks a round: the trader is marked as patrolling too, but
		# a neutral takes no turns at all.
		if e.alive and not e.is_player and e.patrols \
				and e.faction != Entity.Faction.NEUTRAL \
				and e.activity == Entity.Activity.PATROLLING:
			guards.append(e)
	if guards.is_empty():
		return
	var near := {}
	for e in guards:
		near[e] = _nearest_post(Vector2i(e.x, e.y))
	# Stable on ties: the order the floor placed them in.
	var order: Array = []
	for i in guards.size():
		order.append(i)
	order.sort_custom(func(a, b):
		var na: int = near[guards[a]]
		var nb: int = near[guards[b]]
		return na < nb or (na == nb and a < b))
	var n := guards.size()
	for k in n:
		var e: Entity = guards[order[k]]
		var lo := int(k * size / n)
		var hi := maxi(lo + 1, int((k + 1) * size / n) - 1)
		if hi >= size:
			hi = size - 1
			lo = mini(lo, hi - 1)
		e.beat_lo = lo
		e.beat_hi = hi
		e.patrol_dir = 1
		e.patrol_at = clampi(int(near[e]), lo, hi)

## TENDING A FIRE WITH YOUR TORCH (Brad, 2026-10-05). The guards' job, handed
## to you with their numbers: a brazier still lit but low (at most
## BRAZIER_LOW), TORCH_TENDING turns of feeding it from the lit torch, and it
## comes up by BRAZIER_STOKE -- never more than a passing guard would have
## given it, so the torch is never better than the watch it stands in for.
## A DEAD brazier is not this: that stays a paid problem -- a scroll of
## light, a fire gem or a fire blade -- so a floor whose watch you killed
## goes cold for good unless you spend something. Brad's worry, and the
## reason for the split: a free relight always in your hand would have made
## those three worthless.
const TORCH_TENDING := 3

## The low fire beside you the torch could feed, or (-1, -1).
func tend_target() -> Vector2i:
	if not torch_lit:
		return Vector2i(-1, -1)
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var c := Vector2i(player.x + dx, player.y + dy)
			if map.get_tile(c.x, c.y) != Tiles.BRAZIER:
				continue
			var left := int(brazier_charge.get(c, 0))
			if left > 0 and left <= BRAZIER_LOW:
				return c
	return Vector2i(-1, -1)

## G beside a low fire with the torch lit. False, spending nothing, without.
func player_tend() -> bool:
	if game_over:
		return false
	var c := tend_target()
	if c.x < 0:
		return false
	_travel.clear()
	var key := "%d,%d" % [c.x, c.y]
	tending[key] = int(tending.get(key, 0)) + 1
	if int(tending[key]) >= TORCH_TENDING:
		tending.erase(key)
		var left := int(brazier_charge.get(c, 0))
		brazier_charge[c] = mini(BRAZIER_CHARGE, left + BRAZIER_STOKE)
		msg_log.add("You feed the fire from your torch. It burns brighter (+%d)." % BRAZIER_STOKE,
			Color(0.95, 0.78, 0.45))
	else:
		msg_log.add("You feed the fire from your torch. (%d/%d)"
			% [int(tending[key]), TORCH_TENDING], Color(0.90, 0.72, 0.50))
	_end_player_turn()
	return true

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
	var size := patrol_route.size()
	# Its own beat, back and forth (see _assign_beats); no beat, the round.
	var beat := actor.beat_hi > actor.beat_lo and actor.beat_hi < size
	var goal: Vector2i = patrol_route[actor.patrol_at % size]
	# Arrived: take the next post. Done before moving, so a guard that starts
	# its life standing on a brazier still sets off.
	if Vector2i(actor.x, actor.y) == goal:
		if beat:
			if actor.patrol_at >= actor.beat_hi:
				actor.patrol_dir = -1
			elif actor.patrol_at <= actor.beat_lo:
				actor.patrol_dir = 1
			actor.patrol_at = clampi(actor.patrol_at + actor.patrol_dir,
				actor.beat_lo, actor.beat_hi)
		else:
			actor.patrol_at = (actor.patrol_at + 1) % size
		goal = patrol_route[actor.patrol_at % size]
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
func _foe_for(actor: Entity, without_you := false) -> Entity:
	var best: Entity = null
	var best_d := 0
	for e in entities:
		if not e.alive or not actor.hostile_to(e):
			continue
		# Asked by a hunter that has LOST you: what can it see instead?
		if without_you and e.is_player:
			continue
		# THE PLAYER STAYS A TARGET WHEN UNSEEN, because an awake monster hunts
		# by `last_seen` and that memory is the whole point of the field (the
		# LOST step in _take_ai_turn -- until 2026-10-04 this comment was the
		# only place that happened). Everything else has to be visible now.
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
	# Nothing notices you before you are there (the pre-run).
	if _prerunning:
		return
	var d := Los.steps(actor.x, actor.y, player.x, player.y)

	if actor.alertness == Entity.Alert.AWAKE:
		# AN ANIMAL THAT IS UP STAYS UP (2026-10-06). For a monster, awake
		# means hunting you, and losing you means winding down to sleep. For
		# an unstruck wild thing awake means up and about -- drinking,
		# grazing, hunting rabbits -- and a bear that dozed off the moment you
		# left its sight had no life of its own (found by the drinking test:
		# one sip in two hundred turns). Struck, it is a hunter like any other.
		if actor.is_wild() and not actor.provoked:
			return
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
	var reach := _notice_reach(actor)
	if d > reach:
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

	var lum := _light_on_you()
	var closeness := 1.0 - float(d) / float(reach + 1)
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
func _rattle_the_ranks(slain: Entity) -> void:
	for e in entities:
		if e == slain or not e.alive or e.is_player:
			continue
		if e.faction != slain.faction or not e.scavenges:
			continue
		# Something that never flees cannot be shaken either.
		if e.flee_below <= 0.0:
			continue
		if Los.steps(e.x, e.y, slain.x, slain.y) > e.notice_range:
			continue
		if not Los.clear(map, e.x, e.y, slain.x, slain.y):
			continue
		# Was that the biggest thing here, or just another body?
		var biggest := slain.threat
		for o in entities:
			if o == slain or o == e or not o.alive or o.is_player:
				continue
			if o.faction != e.faction:
				continue
			if Los.steps(e.x, e.y, o.x, o.y) > MORALE_REACH:
				continue
			biggest = maxi(biggest, o.threat)
		if biggest > slain.threat:
			continue
		e.shaken = MORALE_SHAKEN_TURNS
		if map.is_visible(e.x, e.y):
			msg_log.add("The %s sees it fall." % e.name, Color(0.85, 0.82, 0.55))

func _update_morale(actor: Entity) -> void:
	if actor.flee_below <= 0.0:
		return
	# Cornered by flame, it does not run (fire, 2026-10-09).
	if _cornered_by_flame(actor):
		actor.fleeing = false
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
		actor.chased = 0

func _ai_hunter(actor: Entity, foe: Entity) -> void:
	if actor.is_adjacent(foe):
		_attack(actor, foe)
		return
	_step_toward(actor, Vector2i(foe.x, foe.y))

## A hunter that has lost you walks to where it last saw you -- or to the
## crash or the noise it took for you -- and stands there until it gives up
## the trail (Entity.pursue_turns). Only WHERE it goes changes, not what it
## is: a bat still flits, a lone goblin still hangs back (_ai_pack), and the
## ranged keep fetching stones and winding their blink on the way.
func _seek_last_seen(actor: Entity) -> void:
	if actor.reload_left > 0:
		actor.reload_left -= 1
	if actor.blink_cool > 0:
		actor.blink_cool -= 1
	var to := actor.last_seen
	# No mark at all (a save from before it was kept): nothing to walk to.
	if to.x < 0 or (actor.x == to.x and actor.y == to.y):
		return
	if actor.ai == &"erratic" and rng.randf() < 0.6:
		_step_random(actor)
		return
	if actor.ai == &"pack" and _allies_near(actor, 5) == 0 and rng.randf() >= 0.45:
		return
	_step_toward(actor, to)

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
	# OUT OF THE POISON FIRST (Brad, 2026-10-04: a bear ally died in the
	# purple's cloud while he stood still, learning the scenario). An ally
	# cannot be healed, so every turn in the miasma or on the wrong fungus is
	# a pure loss -- it steps clear before anything else, even with a foe
	# beside it: the foe will follow, and it fights better out of the cloud.
	# Boxed in with nowhere clear in reach, it holds and does what it can.
	if _harmful_ground(actor.x, actor.y) and _back_out_of_harm(actor):
		if not _retreat_said and map.is_visible(actor.x, actor.y):
			_retreat_said = true
			msg_log.add("%s backs out of the poison." % _called(actor, true),
				Color(0.70, 0.78, 0.70))
		return
	# AND WASHES ITSELF (Brad, 2026-10-05). Poisoned or burning, with a pool
	# near enough to be worth the walk -- fewer steps than points of hurt
	# left, since every step is a tick taken -- it wades in, and _wash clears
	# it underfoot. Already in the water, it has only to stand there.
	var stake := actor.poisoned + actor.acid_turns
	if stake > 1 and map.get_tile(actor.x, actor.y) != Tiles.WATER \
			and _wade_to_water(actor, stake - 1):
		if not _wade_said and map.is_visible(actor.x, actor.y):
			_wade_said = true
			msg_log.add("%s makes for the water." % _called(actor, true),
				Color(0.62, 0.78, 0.90))
		return
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
				and Los.clear_both(map, actor.x, actor.y, quarry.x, quarry.y):
			_attack(actor, quarry, true)
			return
		_safe_step_toward(actor, Vector2i(quarry.x, quarry.y))
		return
	# A tamed pack hunts for you, within your reach (taming, 2026-10-06).
	if actor.eats and _ally_hunts(actor, range_out):
		return
	# Nothing worth doing: come back. Stops at arm's length rather than trying
	# to stand on you -- a companion that crowds the doorway you are backing
	# through is a companion that gets you killed.
	if Los.steps(actor.x, actor.y, player.x, player.y) > 1:
		_safe_step_toward(actor, Vector2i(player.x, player.y))

## Ground that hurts whatever stands on it: the purple's cloud (a purple
## square or beside one -- in_miasma), or the wrong fungus underfoot.
func _harmful_ground(x: int, y: int) -> bool:
	return in_miasma(x, y) or Tiles.is_bad_fungus(map.get_tile(x, y))

## How far an ally will look for clear ground before giving up.
const RETREAT_REACH := 5

## One step toward the nearest clear cell it can walk to. False, unmoved,
## when nothing clear is in reach.
func _back_out_of_harm(actor: Entity) -> bool:
	return _ally_walk(actor, func(c: Vector2i) -> bool:
		return not _harmful_ground(c.x, c.y), RETREAT_REACH, false)

## One step toward the nearest pool within `reach`, by clear ground only.
## False, unmoved, when none is near enough.
func _wade_to_water(actor: Entity, reach: int) -> bool:
	return _ally_walk(actor, func(c: Vector2i) -> bool:
		return map.get_tile(c.x, c.y) == Tiles.WATER and not _harmful_ground(c.x, c.y),
		reach, true)

## One step toward `target` by a way that never sets foot on harmful ground,
## stopping at arm's length. False, unmoved, when no such way exists: an
## ally will not follow you through the poison, and waits at its edge. Not
## the pathfinder: its careful grid routes round fungus SQUARES, and a route
## that hugs the purple is in the cloud every step -- which had the ally
## stepping in and backing out, forever, at the edge (found by the test).
## `onto` aims at the cell itself rather than arm's length of it: meat is
## eaten standing on it, where a foe or you are reached beside.
func _safe_step_toward(actor: Entity, target: Vector2i, onto := false) -> bool:
	var near := 0 if onto else 1
	return _ally_walk(actor, func(c: Vector2i) -> bool:
		return Los.steps(c.x, c.y, target.x, target.y) <= near, ALLY_WALK_REACH, true,
		target)

## How far an ally's own walk looks before settling for the nearest cell it
## found. Bounded (the desktop's review, 2026-10-04): two allies boxed out
## of a purple room on a big floor were two map-sized searches a turn.
## Within a room nothing changes; across a floor it comes as near as it
## can, which is what the fallback is for.
const ALLY_WALK_REACH := 30

## The ally's own breadth-first search over the ground it may step on, from
## where it stands (harmful or not) to the nearest cell `is_goal` accepts that
## is empty and, when `clear_only`, not harmful -- and takes the first step
## of that way. Occupied cells are walls for the search: the first step has
## to be onto an empty square, so a friend in the way is a wall for this one
## turn and it goes round next turn. With no goal in reach and a `toward`
## given, it settles for the reachable cell nearest that -- the edge of the
## cloud, waiting for you. Answers whether it moved.
func _ally_walk(actor: Entity, is_goal: Callable, reach: int, clear_only: bool,
		toward := Vector2i(-1, -1)) -> bool:
	var start := Vector2i(actor.x, actor.y)
	var came_from: Dictionary = {start: start}
	var queue: Array[Vector2i] = [start]
	var goal := Vector2i(-1, -1)
	var nearest := start
	var nearest_d := Los.steps(start.x, start.y, toward.x, toward.y) if toward.x >= 0 else 0
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		if c != start and is_goal.call(c):
			goal = c
			break
		if toward.x >= 0 and Los.steps(c.x, c.y, toward.x, toward.y) < nearest_d:
			nearest = c
			nearest_d = Los.steps(c.x, c.y, toward.x, toward.y)
		if Los.steps(start.x, start.y, c.x, c.y) >= reach:
			continue
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var n := Vector2i(c.x + dx, c.y + dy)
				if (dx == 0 and dy == 0) or came_from.has(n):
					continue
				if not can_creature_step(c.x, c.y, n.x, n.y, actor):
					continue
				if entity_at(n.x, n.y) != null:
					continue
				if clear_only and _harmful_ground(n.x, n.y):
					continue
				came_from[n] = c
				queue.append(n)
	if goal.x < 0:
		if nearest == start:
			return false
		goal = nearest
	var step := goal
	while came_from[step] != start:
		step = came_from[step]
	if _through_the_door(actor, step):
		return true
	_last_move_cost = move_cost_for(actor, step.x, step.y)
	actor.x = step.x
	actor.y = step.y
	return true

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
	# Reloading ticks down whatever else it does -- it can still back away.
	var reloading := actor.reload_left > 0
	if reloading:
		actor.reload_left -= 1

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

	if dist <= actor.total_range() \
			and Los.clear_both(map, actor.x, actor.y, foe.x, foe.y) \
			and _fair_from_the_dark(actor, foe):
		if reloading:
			# It holds its ground with a clear shot, fetching a stone. Said
			# once per floor, where you can see it, so the pause is not a
			# mystery -- the rule that every change must leave a trace.
			if not _reload_said and map.is_visible(actor.x, actor.y):
				_reload_said = true
				msg_log.add("The %s fumbles for another stone." % actor.name,
					Color(0.80, 0.78, 0.70))
			return
		_attack(actor, foe, true)
		actor.reload_left = _reload_after_shot(actor)
		# Magic and fire give away the shooter: its square lights up, so you
		# see what fired and where, even from the dark.
		if actor.casts:
			actor.flare_until = turns + CAST_FLARE_TURNS
		return

	_step_toward(actor, Vector2i(foe.x, foe.y))

## How far past the edge of the player's sight a shooter may stand.
const DARK_SHOT_GRACE := 2

## May this shooter fire at its target from where it stands?
##
## THE TORCH RULE, BOUNDED. Brad, 2026-09-27: the one carrying the light is
## half-blinded by it, so the dark seeing you first is fair -- as long as the
## shooter is no more than a cell or two past the edge of what your torch shows
## you. Measured before the rule: of shots fired from cells too dark to see,
## 62% stood 1 cell past the last visible cell on the line, 30% stood 2, and 7%
## stood 3-4. Those last are the ones this refuses: the shooter steps closer
## first, into the edge of your sight, instead of firing from true blackness.
##
## Only when the target is the player -- `is_visible` is the PLAYER's field of
## view, and nothing else in the game has one.
func _fair_from_the_dark(shooter: Entity, target: Entity) -> bool:
	if not target.is_player or map.is_visible(shooter.x, shooter.y):
		return true
	var seen := 0
	for c in Los.path(target.x, target.y, shooter.x, shooter.y):
		if map.is_visible(c.x, c.y):
			seen = maxi(seen, maxi(absi(c.x - target.x), absi(c.y - target.y)))
	return Los.steps(target.x, target.y, shooter.x, shooter.y) - seen <= dark_shot_grace()

## How far past the edge of your light a shooter may stand. DARK_SHOT_GRACE
## with a full torch -- Brad's ruling of 2026-09-27 -- but NONE where the torch
## is cut down (the caves, the dark climb, a doused torch): there a margin of 2
## was half your sight again, and a young dragon (range 5) against a torch of
## 4 always fired from the dark. Brad was at 2 hp from exactly that
## (2026-09-29): shooters must now stand at the very edge of your light.
func dark_shot_grace() -> int:
	# The BAND's torch, not torch_radius(): the lantern in your armour adds a
	# cell to that, and one more tuning step would have handed the caves back
	# the grace Brad took away on 2026-09-29 (day-7 hunt, 2026-10-04).
	if torch_flare > 0 or (torch_lit and not Bands.is_caves(effective_depth())):
		return DARK_SHOT_GRACE
	return 0

## A magic or fire shot lights the shooter for this long: this turn and next.
const CAST_FLARE_TURNS := 1

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
			if not _can_land_on(x, y):
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
		# For a wild thing, its own KIND: a rabbit beside a wolf is supper,
		# not company (2026-10-05).
		if actor.is_wild() and e.appearance != actor.appearance:
			continue
		if Los.steps(actor.x, actor.y, e.x, e.y) <= radius:
			n += 1
	return n

## The pit beside a chased creature is its way out (strand 5). The one
## farthest from what is chasing it; nothing that flies needs one. True if
## it went, and the turn with it.
func _leap_into_a_pit(actor: Entity, foe: Entity) -> bool:
	if actor.flying:
		return false
	var hole := Vector2i(-1, -1)
	var best := -1
	for i in 8:
		var d := Entity.turned(Vector2i(0, -1), i)
		var c := Vector2i(actor.x + d.x, actor.y + d.y)
		if not map.in_bounds(c.x, c.y) or map.get_tile(c.x, c.y) != Tiles.PIT \
				or entity_at(c.x, c.y) != null:
			continue
		var away := Los.steps(c.x, c.y, foe.x, foe.y)
		if away > best:
			best = away
			hole = c
	if hole.x < 0:
		return false
	if map.is_visible(actor.x, actor.y) or map.is_visible(hole.x, hole.y):
		msg_log.add("The %s leaps into the pit!" % actor.name, Color(0.85, 0.75, 0.62))
	events.append({"kind": &"notice", "to": hole})
	# Half of what it has left, never the last of it: it lands WOUNDED.
	actor.hp = maxi(1, actor.hp - actor.hp / 2)
	actor.fleeing = false
	actor.chased = 0
	actor.alertness = Entity.Alert.AWAKE
	actor.lost_turns = 0
	if not actor.vengeful:
		actor.vengeful = true
		actor.power += REVENGE_POWER
		actor.threat = ceili(actor.threat * REVENGE_XP)
		actor.name = "vengeful %s" % actor.name
	actor.x = hole.x
	actor.y = hole.y
	fallen.append(actor.to_dict())
	entities.erase(actor)
	_last_move_cost = Scheduler.ACTION_COST
	return true

## What leapt into a pit on the floor above lands here: somewhere far from
## you, awake, and already hunting -- it knows who it is looking for.
func _land_the_fallen() -> void:
	something_fell = false
	for d in fallen:
		var e := Entity.from_dict(d)
		if e == null:
			continue
		var spot := _far_landing()
		if spot.x < 0:
			continue
		e.x = spot.x
		e.y = spot.y
		e.alive = true
		e.blocks = true
		e.alertness = Entity.Alert.AWAKE
		e.last_seen = Vector2i(player.x, player.y)
		e.lost_turns = 0
		e.fleeing = false
		e.chased = 0
		entities.append(e)
		something_fell = true
	fallen.clear()

## The open square farthest from the player with nothing on it. Chosen, not
## rolled: a draw here would move every later roll of the floor by one.
func _far_landing() -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := -1
	for y in map.height:
		for x in map.width:
			if not _can_land_on(x, y) or entity_at(x, y) != null:
				continue
			var d := Los.steps(x, y, player.x, player.y)
			if d > best_d:
				best_d = d
				best = Vector2i(x, y)
	return best

func _ai_flee(actor: Entity, foe: Entity) -> void:
	# A spider goes up the wall (2026-10-09): the banshee's phasing step,
	# away from what it flees, and it may end the move inside the stone --
	# still killable there, as the banshee is (player_move tests for a
	# creature before the ground).
	if actor.climbs:
		var before := Vector2i(actor.x, actor.y)
		_step_phasing(actor, Vector2i(actor.x + signi(actor.x - foe.x),
			actor.y + signi(actor.y - foe.y)))
		if Vector2i(actor.x, actor.y) != before:
			return
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
	var tile := map.get_tile(at.x, at.y)
	if not Tiles.is_shut(tile):
		return false
	var style := actor.door_style()
	if style == Entity.Door.SQUEEZES:
		# A LATCHED GATE holds it (2026-10-09): no gap under, no hands for the
		# latch. Only a phasing thing goes through, as it goes through stone.
		# The routes and can_creature_step keep a squeezer from choosing the
		# step; this is the backstop, and it spends the turn.
		if tile == Tiles.GATE_CLOSED and not actor.phasing:
			_last_move_cost = Scheduler.ACTION_COST
			return true
		# Under it, and no slower for it. Brad has watched rabbits do this.
		# A bar is above the gap, so under a barred one too.
		return false
	_last_move_cost = Scheduler.ACTION_COST
	if style != Entity.Door.SHOULDERS:
		# Hands cannot lift a bar from the wrong side: they heave at it.
		if tile == Tiles.DOOR_BARRED:
			return _pound_the_door(actor, at)
		map.set_tile(at.x, at.y, Tiles.opened(tile))
		_set_gate_route(at)
		if map.is_visible(at.x, at.y):
			msg_log.add(("The %s lifts the latch and swings the gate open." if tile == Tiles.GATE_CLOSED
				else "The %s pulls the door open.") % actor.name,
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
	barred.erase(at)  # a bar is no more to a bear than the door was
	var smashed_gate := tile == Tiles.GATE_CLOSED or barred_gates.has(at)
	barred_gates.erase(at)
	pathfinder.set_solid(at.x, at.y, false)
	_set_gate_route(at)
	if map.is_visible(at.x, at.y):
		msg_log.add(("The %s smashes the gate to kindling." if smashed_gate
			else "The %s takes the door off its hinges.") % actor.name,
			Color(0.92, 0.66, 0.45))
	else:
		msg_log.add("Wood splinters, somewhere out of sight.",
			Color(0.78, 0.70, 0.60))
	return true

func _step_toward(actor: Entity, target: Vector2i) -> void:
	var route := pathfinder.path(Vector2i(actor.x, actor.y), target, actor.careful,
		not _owns_the_floor(actor), _gate_holds(actor))
	if route.is_empty():
		return
	var step: Vector2i = route[0]
	# Where it is going, for anything that bumps into it. Recorded whether or
	# not the step succeeds: "I moved last turn" and "I am stuck" both have to
	# answer the question, or a friend walking freely ahead of you in a queue
	# reads as standing idle and gets swapped backwards.
	actor.want = step
	actor.want_turn = turns
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
		# The other side IS a wall: a creature never walks through something
		# it would fight. Its own side it first tries to swap with (see
		# `_gives_way` -- head-on and idle friends trade places), and failing
		# that, to go round. Monsters have always gone round monsters; a comment
		# here once claimed they "simply wait", and the code never did.
		# "Something it would fight" is hostile_to, not another faction: a
		# goblin goes round a rabbit now that the two are at peace
		# (2026-10-04). The trader is never traded places with -- a trader
		# who wandered would turn the legend's "there is a trader" into a lie.
		if actor.hostile_to(blocker) or blocker.faction == Entity.Faction.NEUTRAL:
			return
		if _gives_way(actor, blocker):
			_swap_places(actor, blocker)
			return
		step = _around(actor, target)
		if step.x < 0:
			return
	if _through_the_door(actor, step):
		return
	_last_move_cost = move_cost_for(actor, step.x, step.y)
	var from := Vector2i(actor.x, actor.y)
	actor.x = step.x
	actor.y = step.y
	# Stepping OFF an open door: a careful guard will shut it next turn.
	actor.shut_behind = from if Tiles.is_open_door(map.get_tile(from.x, from.y)) \
		and actor.door_style() == Entity.Door.OPENS \
		and actor.alertness != Entity.Alert.AWAKE else Vector2i(-1, -1)

## DOORS SHUT BEHIND THINGS. Brad, 2026-09-25: a deception, and a second tell.
##
## Creatures have always opened doors and bears have always smashed them, but
## nothing shut one -- so an open door you left shut meant "something came
## through". That stays true. Now a door you left OPEN and find shut means
## something CAREFUL came through: a guard on its round. The player's own map
## memory -- every door was shut until they opened it -- is turned against them
## without erasing the tell they already had.
##
## Only door-OPENERS (the patrollers: never a squeezing rat, never a bear),
## only while NOT hunting (a chaser does not stop to tidy up), only the turn
## after stepping off it, and only when the doorway is clear and nobody is
## right behind -- a guard does not shut the door on its own friend or on you.
##
## SILENT, unlike the player's door. Monsters open doors silently too, and a
## noise here would make every guard on its round wake the sleepers along its
## route, turn after turn -- a hidden difficulty change. It costs the guard its
## turn, and if you can see the door, the log says so.
func _shut_behind(actor: Entity) -> bool:
	var door := actor.shut_behind
	if door.x < 0:
		return false
	actor.shut_behind = Vector2i(-1, -1)
	if actor.door_style() != Entity.Door.OPENS \
			or not Tiles.is_open_door(map.get_tile(door.x, door.y)):
		return false
	if maxi(absi(actor.x - door.x), absi(actor.y - door.y)) != 1:
		return false
	if entity_at(door.x, door.y) != null or not items_at(door.x, door.y).is_empty():
		return false
	for e in entities:
		if e == actor or not e.alive:
			continue
		if maxi(absi(e.x - door.x), absi(e.y - door.y)) <= 1:
			return false
	# A gate shut behind a guard latches again (2026-10-09).
	var gate := map.get_tile(door.x, door.y) == Tiles.GATE_OPEN
	map.set_tile(door.x, door.y, Tiles.closed(map.get_tile(door.x, door.y)))
	_set_gate_route(door)
	_last_move_cost = Scheduler.ACTION_COST
	if map.is_visible(door.x, door.y):
		msg_log.add(("The %s swings the gate to behind it; the latch drops." if gate
			else "The %s pulls the door shut behind it.") % actor.name,
			Color(0.78, 0.74, 0.66))
	return true

## How long a creature's last intent counts as current, in turns. Wider than
## one because not everything acts every turn: a slow creature walking a queue
## still means to walk it between its moves.
const TRAFFIC_MEMORY := 3

## TRAFFIC: will this friend trade places so `actor` can pass?
##
## Brad, 2026-09-24/25: kobolds jammed in doorways facing opposite ways, and
## lines of four where nobody could tell who was going where. Going round is no
## help in a doorway or a corridor -- there is no round -- so two creatures
## that each wait for the other waited for ever. The rules, in order:
##
##   1. Never the player. Allies go round you, and you can swap with them.
##   2. Never a friend who is FIGHTING (next to something it would attack).
##      Without this the one behind would swap forward every turn and the
##      player would face a fresh attacker each turn -- a rotating shield wall,
##      which is a large hidden difficulty change, not a traffic fix.
##   3. HEAD-ON: its last intent was MY cell. We want each other's squares;
##      we swap and both get on. A line of three with one going the other way
##      is this, once per turn, until the one has passed through.
##   4. QUEUE: its last intent was somewhere else. It is going my way and is
##      held up itself; I wait my turn, as a queue should.
##   5. IDLE: no intent lately -- a guard on its post, a sleeper, a creature
##      eating. It gives way, one cell back, and walks back on its own turn.
##
## Fixed rules, no rng, so a seeded run replays the same. The obvious next
## step -- a creature that tires of a queue and takes another way round, which
## is to say FLANKS -- is deliberately not here: it changes how fights play,
## and gets its own build once this one has been played.
func _gives_way(actor: Entity, blocker: Entity) -> bool:
	if blocker.is_player or not blocker.alive:
		return false
	if _engaged(blocker):
		return false
	if blocker.want_turn >= turns - TRAFFIC_MEMORY:
		return blocker.want == Vector2i(actor.x, actor.y)
	return true

## Is this creature next to something it would fight?
func _engaged(e: Entity) -> bool:
	for o in entities:
		if o == e or not o.alive:
			continue
		if maxi(absi(o.x - e.x), absi(o.y - e.y)) == 1 and e.hostile_to(o):
			return true
	return false

## Two friends trade squares. The one moving pays for the step; the one moved
## pays nothing and still takes its own turn, as an ally does when the player
## swaps with it. Both cells hold a creature, so neither can be a pit.
##
## A SLEEPER moved aside stirs -- Brad's call. It wakes to suspicion, the state
## a noise leaves things in, and does NOT learn where the player is: a kobold
## elbowed by its friend has no reason to know. A guard walking its round is
## unaware too, but awake; being passed in a doorway is nothing to it.
func _swap_places(actor: Entity, blocker: Entity) -> void:
	var from := Vector2i(actor.x, actor.y)
	_last_move_cost = move_cost_for(actor, blocker.x, blocker.y)
	actor.x = blocker.x
	actor.y = blocker.y
	blocker.x = from.x
	blocker.y = from.y
	if blocker.activity == Entity.Activity.SLEEPING \
			and blocker.alertness == Entity.Alert.ASLEEP:
		blocker.alertness = Entity.Alert.SUSPICIOUS
		blocker.calm_turns = 0

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
			if not can_creature_step(actor.x, actor.y, nx, ny, actor):
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
## How close you may come before an awake animal gives you room.
const WILD_SPACE := 2

## How far a hungry monster looks for game, or for meat lying about.
const HUNT_REACH := 6

## A monster's hunt (Brad, 2026-10-04: "they have to eat, too"). Meat
## underfoot is eaten first; else the nearest prey it can see within
## HUNT_REACH is hunted with the creature's own fighting -- the ranged keep
## their distance and sling, the rest close -- and failing prey, it walks to
## the nearest meat lying about. The kill leaves the haunch where the rabbit
## fell, and the hunter eats it off the floor, so a floor where the goblins
## got to the rabbits first has less meat in it. True of anything the player
## left lying as well. Answers whether the turn was spent.
func _hunt(actor: Entity) -> bool:
	# Fed, it lets game and meat be (hunger, _set_appetites).
	if not actor.is_hungry():
		return false
	if _eat_here(actor):
		return true
	var prey := _prey_for(actor)
	if prey != null:
		if actor.ai == &"ranged":
			_ai_ranged(actor, prey)
		else:
			_ai_hunter(actor, prey)
		return true
	var meat := _meat_near(actor)
	if meat.x >= 0:
		_step_toward(actor, meat)
		return true
	return false

## Game for this hunter: a WILD thing it can see within HUNT_REACH, no
## bigger than itself (the bear is nobody's supper: `heavy`), and for a
## melee hunter nothing that flies -- a bat is the slinger's. Rabbit before
## bear, as Brad asked; in practice rabbit, and bat for the ranged.
func _prey_for(actor: Entity) -> Entity:
	var best: Entity = null
	var best_d := HUNT_REACH + 1
	for e in entities:
		if not _is_game(actor, e):
			continue
		if not _can_see(actor, e):
			continue
		var d := Los.steps(actor.x, actor.y, e.x, e.y)
		if d <= HUNT_REACH and d < best_d:
			best = e
			best_d = d
	return best

## Whether `e` is game for this hunter at all, wherever it stands.
func _is_game(actor: Entity, e: Entity) -> bool:
	if not e.alive or not e.is_wild() or e.heavy or e.threat > actor.threat:
		return false
	# Never its own kind. A wolf is threat 6 like its packmates, and
	# without this the pack ate itself: of 97 wolves found dead on cave
	# floors while the player waited, 65 had a wolf's teeth in them
	# (probe, Brad's "three of four dead when I arrived", 2026-10-05).
	if e.appearance == actor.appearance:
		return false
	# A spider takes a bat as readily (2026-10-09): its web will hold
	# flyers (night 2); until then it bites one within reach.
	if e.flying and actor.ai != &"ranged" and not actor.climbs:
		return false
	return true

## Meat underfoot goes down the hunter's throat: gone from the floor, and
## it heals what it would have healed you (the first monster that heals by
## eating; the slime will be the second). Said where you can see it.
func _eat_here(actor: Entity) -> bool:
	for it in ground:
		if it.x == actor.x and it.y == actor.y and _is_meat(it):
			ground.erase(it)
			actor.hp = mini(actor.max_hp, actor.hp + it.effective_magnitude())
			actor.hunger = 0
			if map.is_visible(actor.x, actor.y):
				msg_log.add("The %s eats the %s." % [actor.name, it.name],
					Color(0.85, 0.78, 0.55))
			return true
	return false

## The nearest meat lying within HUNT_REACH, or (-1, -1).
func _meat_near(actor: Entity) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := HUNT_REACH + 1
	for it in ground:
		if not _is_meat(it):
			continue
		var d := Los.steps(actor.x, actor.y, it.x, it.y)
		if d < best_d and Los.clear(map, actor.x, actor.y, it.x, it.y):
			best = Vector2i(it.x, it.y)
			best_d = d
	return best

## What an unstruck WILD creature does with its turn. A forager forages, as
## it always has, shying from whoever is near. Anything else sleeps until it
## notices you, then keeps its distance -- a step away when you come within
## WILD_SPACE -- and otherwise wanders, or stands. No hunting: that is what
## being struck changes.
func _ai_wild(actor: Entity) -> void:
	if actor.ai == &"forager":
		# Frightened first, as ever; else a drink, else the mushrooms.
		var scare := _what_scares(actor)
		if Los.steps(actor.x, actor.y, scare.x, scare.y) <= RABBIT_NOSE \
				and Los.clear(map, actor.x, actor.y, scare.x, scare.y):
			_ai_forager(actor, scare)
			return
		# Then fire (2026-10-09): a rabbit does not graze beside a flame --
		# but one with a goblin after it runs from the goblin, torch or no.
		if _keeps_back_from_fire(actor):
			return
		if _drinks(actor):
			return
		_ai_forager(actor, scare)
		return
	if actor.alertness != Entity.Alert.AWAKE:
		_stir(actor)
		return
	# A den bear woken watches what woke it: back to sleep, or after it.
	if actor.denned and _keeps_to_the_den(actor):
		return
	# Up and about: a den bear that left is an ordinary bear from now on.
	actor.denned = false
	# FIRE, AN INNATE FEAR: before hunting, drinking or wandering.
	if _keeps_back_from_fire(actor):
		return
	# The food web (Brad, 2026-10-04): a bear hunts the rabbits, with the
	# same hunt the goblins have, and eats what it brings down. Never a bear
	# (heavy), never you (_prey_for looks only at the wild).
	if actor.eats and _hunt(actor):
		return
	var near := _what_scares(actor)
	if Los.steps(actor.x, actor.y, near.x, near.y) <= WILD_SPACE \
			and Los.clear(map, actor.x, actor.y, near.x, near.y) \
			and _step_away(actor, near):
		return
	if _drinks(actor):
		return
	# Nothing to do: now and then, a nap.
	if nap_rng.randf() < NAP_CHANCE:
		actor.alertness = Entity.Alert.ASLEEP
		return
	if rng.randf() < 0.5:
		_step_random(actor)

## SOMETIMES SOMEONE JUST NEEDS A NAP (Brad, 2026-10-07). After the pre-run
## woke every animal and "an animal that is up stays up" kept them so, 150
## turns of wandering left none of them where the floor put them -- and a
## cave bear walked off from the den whose bones were meant to wake it. Now
## an unstruck animal with nothing to do may doze off where it stands; it may
## wake on its own after a while; an awake creature passing beside it may
## wake it; noise and you wake it as they wake anything. If it does not wake,
## it does not. Not a rabbit: a forager is always about its mushrooms. Not a
## den bear on its own: it hibernates until something wakes it.
## The numbers: a nap about every hundred idle turns, lasting about forty.
const NAP_CHANCE := 0.01
const WAKE_CHANCE := 0.025
## The chance a turn that an awake creature beside a sleeper wakes it.
const PASSERBY_WAKE := 0.5

## A sleeping animal's turn: perhaps it wakes. Never a den bear on its own.
func _stir(actor: Entity) -> void:
	if actor.alertness != Entity.Alert.ASLEEP:
		return
	if actor.denned:
		# Hibernating: never on its own, but anything that comes too close
		# wakes it, for certain.
		if _nearest_waker(actor, DEN_WAKE_REACH) != null:
			actor.alertness = Entity.Alert.AWAKE
			actor.den_quiet = 0
			if map.is_visible(actor.x, actor.y):
				msg_log.add("The %s stirs in its den." % actor.name,
					Color(0.95, 0.72, 0.45))
		return
	var passer := false
	for e in entities:
		if e == actor or e.is_player or not e.alive or e.alertness != Entity.Alert.AWAKE:
			continue
		if e.is_adjacent(actor):
			passer = true
			break
	if passer:
		if nap_rng.randf() < PASSERBY_WAKE:
			actor.alertness = Entity.Alert.AWAKE
		return
	if nap_rng.randf() < WAKE_CHANCE:
		actor.alertness = Entity.Alert.AWAKE

## LET SLEEPING BEARS LIE (Brad, 2026-10-07). Waking a bear, on purpose or
## by accident, is not a good thing. Anything that comes within
## DEN_WAKE_REACH of a bear asleep in its den wakes it -- a wolf, a goblin,
## you -- as do noise and a blow. Up, it stays in the den and watches. If
## something it could eat is close, or you are, it may come out after it,
## the likelier the closer: DEN_HUNT_CHANCE a turn for game, DEN_TURN_CHANCE
## for you, by distance. Out, it is an ordinary bear; coming for you, it is
## your enemy as if you had struck it. If nothing is within DEN_SETTLE_REACH
## for DEN_SETTLE_TURNS, it goes back to sleep in the den. A monster that
## is not game (a kobold) wakes it but is not yet a meal: animals and
## monsters do not fight unless struck (the backlog has the idea). In the
## pre-run you are not on the floor yet, and count for nothing.
const DEN_WAKE_REACH := 2
const DEN_SETTLE_REACH := 4
const DEN_SETTLE_TURNS := 3
## Index: steps away (0 unused). Beyond the end, no chance.
const DEN_HUNT_CHANCE := [0.0, 0.25, 0.12]
const DEN_TURN_CHANCE := [0.0, 0.40, 0.20]
## A fed bear is slower to come out after anything (hunger; Brad: "a bear
## WILL attack a person, especially if it is hungry").
const DEN_FED_SCALE := 0.5

## FIRE, AN INNATE FEAR (the wild creatures update; built 2026-10-09, Brad's
## numbers). An UNSTRUCK animal will not stay within FIRE_FEAR_REACH of fire
## -- your lit torch or a lit brazier -- and steps away from it before
## anything else it would do. Douse the torch and they come close again. A
## struck BEAR or WOLF within that reach of fire is CORNERED BY FLAME: it
## hits CORNERED_BONUS harder and will not flee. Monsters ignore fire. In the
## pre-run your torch is not on the floor, so only the braziers count.
const FIRE_FEAR_REACH := 2
const CORNERED_BONUS := 2

## The nearest fire within `reach` of `c`, or (-1, -1): your lit torch (you
## carry it), else a lit brazier.
func _fire_near(c: Vector2i, reach: int = FIRE_FEAR_REACH) -> Vector2i:
	if torch_lit and player.alive and not _prerunning \
			and Los.steps(c.x, c.y, player.x, player.y) <= reach:
		return Vector2i(player.x, player.y)
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			if map.get_tile(c.x + dx, c.y + dy) == Tiles.BRAZIER:
				return Vector2i(c.x + dx, c.y + dy)
	return Vector2i(-1, -1)

## An unstruck animal near fire steps away from it. True if that was its
## turn. Boxed in, it holds its ground and gets on with its turn.
func _keeps_back_from_fire(actor: Entity) -> bool:
	if not actor.is_wild() or actor.provoked:
		return false
	var fire := _fire_near(Vector2i(actor.x, actor.y))
	if fire.x < 0:
		return false
	return _step_away_from(actor, fire)

## A struck bear or wolf with fire within FIRE_FEAR_REACH: cornered by flame.
func _cornered_by_flame(actor: Entity) -> bool:
	if not actor.is_wild() or not actor.provoked:
		return false
	if actor.appearance != &"bear" and actor.appearance != &"wolf":
		return false
	return _fire_near(Vector2i(actor.x, actor.y)).x >= 0

## Which cornered animals the log has named this floor, so it says so once.
var _cornered_said: Dictionary = {}

## The nearest awake thing within `reach` of `actor`: you (always awake,
## except during the pre-run, when you are not there) or any creature.
func _nearest_waker(actor: Entity, reach: int) -> Entity:
	var best: Entity = null
	var best_d := reach + 1
	for e in entities:
		if e == actor or not e.alive:
			continue
		if e.is_player:
			if _prerunning:
				continue
		elif e.alertness != Entity.Alert.AWAKE:
			continue
		var d := Los.steps(actor.x, actor.y, e.x, e.y)
		if d < best_d:
			best = e
			best_d = d
	return best

## A woken den bear's turn. True: it stayed (watching, or back to sleep).
## False: it has come out, an ordinary bear, and the caller carries on.
func _keeps_to_the_den(actor: Entity) -> bool:
	if _nearest_waker(actor, DEN_SETTLE_REACH) == null:
		actor.den_quiet += 1
		if actor.den_quiet >= DEN_SETTLE_TURNS:
			actor.den_quiet = 0
			actor.alertness = Entity.Alert.ASLEEP
		return true
	actor.den_quiet = 0
	# The likeliest draw: the closest thing it would come out for.
	var target: Entity = null
	var chance := 0.0
	for e in entities:
		if e == actor or not e.alive:
			continue
		var table: Array
		if e.is_player:
			if _prerunning:
				continue
			table = DEN_TURN_CHANCE
		elif _is_game(actor, e):
			table = DEN_HUNT_CHANCE
		else:
			continue
		# A bear goes by its nose: dark is no hiding place this close, but
		# a wall between is.
		var d := Los.steps(actor.x, actor.y, e.x, e.y)
		if d >= table.size() or not Los.clear(map, actor.x, actor.y, e.x, e.y):
			continue
		var c: float = table[d]
		if not actor.is_hungry():
			c *= DEN_FED_SCALE
		if c > chance:
			chance = c
			target = e
	if target == null or nap_rng.randf() >= chance:
		return true
	actor.denned = false
	if target.is_player:
		# As if you had struck it: your enemy for good.
		actor.provoked = true
		actor.grudge = player
		actor.last_seen = Vector2i(player.x, player.y)
		actor.lost_turns = 0
		if map.is_visible(actor.x, actor.y):
			msg_log.add("The %s rises from its den and comes for you!" % actor.name,
				Color(0.95, 0.40, 0.35))
		# Rising is its turn; from the next it is a hunter like any other.
		return true
	return false

## ANIMALS DRINK (Brad, 2026-10-05; built 2026-10-06). The first routine
## in the dungeon that is not about you: an unbothered wild thing with a
## pool within DRINK_REACH heads for it now and then, stands at the water
## with its head down for DRINK_TURNS, and goes back to its day. It gives
## the drip pools a second job and the pre-run something to be found
## doing. Purely life: it heals nothing and washes only what _wash would.
const DRINK_REACH := 6
const DRINK_CHANCE := 0.12
const DRINK_TURNS := 2

## True if the turn went on drinking, or on walking to the water for it.
## `drinking` above zero is the sip in progress; BELOW zero is thirst -- it
## has decided on the water and keeps walking until it stands in it (one
## lucky roll a step was a random walk that never arrived). Thirst passes
## if the water is gone from reach.
func _drinks(actor: Entity) -> bool:
	if actor.drinking > 0:
		actor.drinking -= 1
		return true
	if map.get_tile(actor.x, actor.y) == Tiles.WATER:
		if actor.drinking == 0 and drink_rng.randf() >= 0.5:
			return false
		actor.drinking = DRINK_TURNS
		if map.is_visible(actor.x, actor.y):
			msg_log.add("%s drinks." % _called(actor, true), Color(0.62, 0.78, 0.90))
		return true
	if actor.drinking == 0 and drink_rng.randf() >= DRINK_CHANCE:
		return false
	var pool := _water_near(actor, DRINK_REACH)
	if pool.x < 0:
		actor.drinking = 0
		return false
	actor.drinking = -1
	_step_toward(actor, pool)
	return true

## The nearest water within `reach` in a clear line, or (-1, -1).
func _water_near(actor: Entity, reach: int) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := reach + 1
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var c := Vector2i(actor.x + dx, actor.y + dy)
			if not map.in_bounds(c.x, c.y) or map.get_tile(c.x, c.y) != Tiles.WATER:
				continue
			var d := Los.steps(actor.x, actor.y, c.x, c.y)
			if d < best_d and entity_at(c.x, c.y) == null \
					and Los.clear(map, actor.x, actor.y, c.x, c.y):
				best = c
				best_d = d
	return best

## Whether a grudge still weighs: the thing is alive and not long gone. Not
## _can_see -- what struck you, you know the whereabouts of, dark or not;
## a rabbit speared from the shadows runs from the spear.
func _minds(actor: Entity, score: Entity) -> bool:
	# Still ON THE FLOOR: a thing that leapt into a pit leaves `entities`
	# alive, on a stale square, and a pack sharing its grudge would hunt a
	# ghost there (the desktop's review, 2026-10-04; built 2026-10-05).
	if not score.alive or (score != player and not entities.has(score)):
		return false
	return Los.steps(actor.x, actor.y, score.x, score.y) <= actor.notice_range * 2

## What an animal shies from. Whatever struck it last, if that is alive and
## not long gone, before anything else (Brad, 2026-10-04: a rabbit a goblin has
## speared runs from the goblin, not from you). Else the nearest of you, an
## ally of yours it can see, and -- for a forager, which fears everything
## that is not wild -- any monster it can see; a bear gives room to you, not
## to a kobold. Never null: you are always somewhere. Not _foe_for, which
## asks about enemies, and an unstruck animal has none.
func _what_scares(actor: Entity) -> Entity:
	var fright := actor.grudge
	if fright != null and _minds(actor, fright):
		return fright
	var timid := actor.ai == &"forager"
	var best: Entity = player
	var best_d := Los.steps(actor.x, actor.y, player.x, player.y)
	for e in entities:
		if e == actor or not e.alive or e.is_player or e.faction == Entity.Faction.NEUTRAL:
			continue
		# A wild thing fears the wild things that EAT -- a rabbit runs from a
		# bear -- and nothing else wild.
		if e.is_wild() and not e.eats:
			continue
		if not timid and e.faction != Entity.Faction.PLAYER:
			continue
		if not _can_see(actor, e):
			continue
		var d := Los.steps(actor.x, actor.y, e.x, e.y)
		if d < best_d:
			best = e
			best_d = d
	return best

## THE SLIME'S TURN. Anything lying under it is swallowed, meat and fungus
## eaten; anything lying within SCAVENGE_REACH is walked to BEFORE anything
## else -- even with you beside it, which is what makes dropping something
## a lure (Brad, 2026-10-04; the one creature that breaks `_scavenge`'s
## "nothing stops mid-fight" rule, on purpose). Nothing to take: it hunts
## like anything else.
func _ai_slime(actor: Entity, foe: Entity) -> void:
	if _slime_feeds(actor):
		return
	var want := Vector2i(-1, -1)
	var best := SCAVENGE_REACH + 1
	for it in ground:
		if _slime_refuses(it):
			continue
		var d := Los.steps(actor.x, actor.y, it.x, it.y)
		if d < best and Los.clear(map, actor.x, actor.y, it.x, it.y):
			best = d
			want = Vector2i(it.x, it.y)
	if want.x >= 0:
		_step_toward(actor, want)
		return
	_ai_hunter(actor, foe)

## WHAT A SLIME WILL NOT TOUCH (Brad, 2026-10-05): the amulet, a unique,
## the satchel, a named hero's bone -- the run's own things. A slime that
## swallowed the amulet and then dissolved in the miasma out of your sight
## would have left the run's goal somewhere you were not looking. Chests
## are tiles, opened by your step alone, so they were never in reach.
func _slime_refuses(it: Item) -> bool:
	return it.unique or it.kind == Item.Kind.AMULET or it.holds > 0 or it.bone_name != ""

## What a slime does with what it stands on: eats meat and green fungus
## (gone for good), swallows everything else (carried, and dropped whole when
## it dies -- marked `scavenged`, so the drop is certain). True if it fed.
func _slime_feeds(actor: Entity) -> bool:
	if _eat_here(actor):
		return true
	var at := Vector2i(actor.x, actor.y)
	if map.get_tile(at.x, at.y) == Tiles.FUNGUS:
		map.set_tile(at.x, at.y, _bare_ground(at))
		_gather_lights()
		actor.hp = mini(actor.max_hp, actor.hp + 1)
		if map.is_visible(at.x, at.y):
			msg_log.add("The %s dissolves the fungus." % actor.name, Color(0.70, 0.88, 0.50))
		return true
	var it: Item = null
	for candidate in items_at(at.x, at.y):
		if not _slime_refuses(candidate):
			it = candidate
			break
	if it == null:
		return false
	ground.erase(it)
	it.letter = ""
	it.scavenged = true
	actor.inventory.append(it)
	if map.is_visible(at.x, at.y):
		msg_log.add("The %s swallows the %s." % [actor.name, it.display_name()],
			Color(0.70, 0.88, 0.50))
	return true

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
	# Only within the nose's reach: nothing further is ever accepted, and the
	# whole-map scan this was cost 3 ms a rabbit a turn -- nine-tenths of the
	# pre-run (profiled 2026-10-06). Same row order, so ties fall the same way.
	for y in range(maxi(0, actor.y - RABBIT_NOSE), mini(map.height, actor.y + RABBIT_NOSE + 1)):
		for x in range(maxi(0, actor.x - RABBIT_NOSE), mini(map.width, actor.x + RABBIT_NOSE + 1)):
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
	map.set_tile(actor.x, actor.y, _bare_ground(Vector2i(actor.x, actor.y)))
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
	# Not in the pre-run: a killer rabbit is threat the ceiling never bought.
	if _prerunning:
		return
	actor.name = "killer rabbit"
	actor.appearance = &"killer_rabbit"
	actor.ai = &"hunter"
	# And it is an animal no longer: a MONSTER, your enemy unstruck, as it
	# always was before the rabbit went WILD (2026-10-04).
	actor.faction = Entity.Faction.MONSTER
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
	# A wolf leaves its own haunch (2026-10-05): the wolves you fight feed
	# you. Worth a rabbit's base, no `meal` term -- it ate rabbits, not fungus.
	var wolf := victim.appearance == &"wolf"
	var meat := Item.make(&"bear_meat" if bear else (&"wolf_meat" if wolf else &"meat"))
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
	meat.magnitude = (MEAT_BEAR if bear else MEAT_BASE + (0 if wolf else victim.meal)) \
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

## A climber steps out of the stone onto the first free open ground beside
## it, in a fixed order (down, up, right, left, then the diagonals) -- no
## draw, so it moves no seed; boxed in, it waits.
func _climb_down(actor: Entity) -> void:
	for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
			Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
		var c: Vector2i = Vector2i(actor.x, actor.y) + d
		if _can_rest_on(c.x, c.y) and entity_at(c.x, c.y) == null:
			actor.x = c.x
			actor.y = c.y
			return

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
			if can_creature_step(actor.x, actor.y, nx, ny, actor) and entity_at(nx, ny) == null:
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
	return _step_away_from(actor, Vector2i(foe.x, foe.y))

## The same, from a place rather than a creature (a fire, 2026-10-09).
func _step_away_from(actor: Entity, from: Vector2i) -> bool:
	var foe := from
	var here := Los.steps(actor.x, actor.y, foe.x, foe.y)
	var best := Vector2i(actor.x, actor.y)
	var best_d := here
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var nx: int = actor.x + dx
			var ny: int = actor.y + dy
			if not can_creature_step(actor.x, actor.y, nx, ny, actor) or entity_at(nx, ny) != null:
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
					_queue_healing_cue(drawn)
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
## `cause`, when the killer is the victim itself, names what did it -- "the
## miasma", "a trap" -- for the body's record (BODIES SAY WHO KILLED THEM,
## Brad, 2026-10-05; built 2026-10-06).
func _settle_death(victim: Entity, killer: Entity, cause := "") -> void:
	if victim.is_player:
		game_over = true
		death_cause = "killed by a %s" % killer.name
		events.append({"kind": &"death", "to": Vector2i(player.x, player.y)})
		write_morgue()
		write_death_dump()
		# No key named here. The panel says which one, in the language of
		# whatever the player is holding.
		msg_log.add("You die.", Color(1.0, 0.35, 0.35))
	else:
		msg_log.add("%s dies." % _called(victim, true), Color(0.65, 0.70, 0.85))
		events.append({"kind": &"kill",
			"to": Vector2i(victim.x, victim.y)})
		# Remembered BEFORE the loot drop empties it, so what stands up
		# again is wearing what it fought you in. Serialised with the run,
		# because a suspend in the five turns after a big kill must not
		# quietly cost you the dig.
		_remember_the_dead(victim)
		_lay_body(victim, _killed_by(victim, killer, cause))
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


## How the log names a creature: "the goblin" -- but a hero's shade from a
## grave goes by their own name ("Erdrick", never "The Erdrick").
func _called(e: Entity, capital: bool) -> String:
	if e.appearance == &"bone_ally":
		return e.name
	return ("The %s" if capital else "the %s") % e.name

func _attack(attacker: Entity, defender: Entity, ranged: bool = false,
		power_override: int = -1) -> void:
	# Nobody dies in the pre-run (Brad's rule): a hunt there is only a chase.
	if _prerunning:
		return
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
	# Cornered by flame: a struck bear or wolf beside fire fights harder.
	if not ranged and power_override < 0 and _cornered_by_flame(attacker):
		atk += CORNERED_BONUS
		if not _cornered_said.has(attacker) and map.is_visible(attacker.x, attacker.y):
			_cornered_said[attacker] = true
			msg_log.add("Cornered by the flame, the %s fights all the harder!" % attacker.name,
				Color(0.95, 0.55, 0.35))

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
	#
	# AND AT MOST HALF THE BLOW (Brad, 2026-09-26). Floored only at 1, the block
	# took EVERY hit on the climb to 1 against a player in plate +2 and a tower
	# +2 -- young dragon, arch lich, all of it -- because at that defense every
	# blow already lands on the quarter-power floor, and 4 - 3 is 1. Ninety hit
	# points became ninety hits. Capped at half, the bulwark still reaches past
	# the floor, which is what makes it the bulwark: a dragon's 4 becomes 2, an
	# ogre's 3 becomes 2. Twice as hard to wear down, not ninety times.
	var turned := mini(defender.block_amount(), dmg / 2)
	if turned > 0:
		var before := dmg
		dmg = maxi(1, dmg - turned)
		turned = before - dmg
	defender.take_damage(dmg)
	if gem != &"":
		_gem_strikes(gem, attacker, defender, dmg, ranged)
	# The spider's bite: its venom, as the purple's poison (2026-10-09).
	if attacker.venom > 0 and defender.alive and not ranged and not defender.unliving:
		defender.poisoned = maxi(defender.poisoned, attacker.venom)
		if defender.is_player:
			msg_log.add("The %s's bite burns. Poisoned -- water would wash it out." % attacker.name,
				Color(0.78, 0.55, 0.90))
	# The slime's touch: acid that goes on eating (ACID_LINGER turns).
	if attacker.acid and defender.alive and not ranged:
		defender.acid_turns = ACID_LINGER
		if defender.is_player:
			msg_log.add("The %s's acid clings to you. Water would wash it off." % attacker.name,
				Color(0.70, 0.88, 0.50))

	if attacker.is_player:
		_tally("dealt", dmg)
		if ranged:
			_tally("shots")
		else:
			var held: Variant = player.equipped.get(Item.Slot.WEAPON, null)
			_tally_in("swings", held.name if held != null else "bare hands")
	elif defender.is_player:
		_tally("taken", dmg)

	# Snapshot the strike style with the event; FX is consumed after the turn
	# resolves, when either combatant may have moved or died.
	events.append({
		"kind": &"ranged" if ranged else &"melee",
		"from": Vector2i(attacker.x, attacker.y),
		"to": Vector2i(defender.x, defender.y),
		"amount": dmg,
		"on_player": defender.is_player,
		"damage_type": kind,
	})
	if defender.is_player:
		# Never keep auto-walking into something that is hurting you.
		_travel.clear()
	elif not attacker.is_player and attacker.faction != Entity.Faction.PLAYER:
		# Woken by the dead -- or, since 2026-10-04, by a hunting monster --
		# not by you: no "notices you", and it turns on what hit it.
		if defender.alertness != Entity.Alert.AWAKE:
			defender.alertness = Entity.Alert.AWAKE
			defender.last_seen = Vector2i(attacker.x, attacker.y)
			defender.lost_turns = 0
	elif defender.faction != Entity.Faction.RISEN:
		wake(defender)
	# A WILD THING REMEMBERS WHAT STRUCK IT (Entity.grudge): a forager runs
	# from it, anything else fights it back, whoever's side it is on. A PACK
	# remembers together: an orc that spears one wolf has the pack's grudge
	# within PACK_REACH (2026-10-05 -- before this an orc camp ate a pack one
	# wolf at a time, each one's packmates asleep beside it).
	if defender.is_wild() and attacker != defender:
		defender.grudge = attacker
		if _pack_size(_bestiary_row(defender.appearance)) > 1:
			for e in entities:
				if e == defender or not e.alive or e.appearance != defender.appearance \
						or Los.steps(e.x, e.y, defender.x, defender.y) > PACK_REACH:
					continue
				e.grudge = attacker
				e.alertness = Entity.Alert.AWAKE
	# STRUCK BY YOUR SIDE, A WILD THING IS YOUR ENEMY FOR GOOD. A forager
	# says nothing: it runs, as it did before, and "turns on you" would be a
	# lie about a rabbit.
	if defender.is_wild() and not defender.provoked \
			and (attacker.is_player or attacker.faction == Entity.Faction.PLAYER):
		defender.provoked = true
		# A PACK TURNS TOGETHER (the wolf, 2026-10-05): every one of its kind
		# within PACK_REACH takes the same grudge and the same enemy.
		var pack := 0
		if _pack_size(_bestiary_row(defender.appearance)) > 1:
			for e in entities:
				if e == defender or not e.alive or e.appearance != defender.appearance \
						or e.provoked or Los.steps(e.x, e.y, defender.x, defender.y) > PACK_REACH:
					continue
				e.provoked = true
				e.grudge = attacker
				e.alertness = Entity.Alert.AWAKE
				pack += 1
		if defender.alive and defender.ai != &"forager" \
				and map.is_visible(defender.x, defender.y):
			if pack > 0:
				msg_log.add("The %s turns on you -- and the pack with it." % defender.name,
					Color(0.95, 0.72, 0.45))
			else:
				msg_log.add("The %s turns on you." % defender.name, Color(0.95, 0.72, 0.45))
	# A risen hit carries the red: what it kills, rises. The snowball.
	if attacker.fungal and not defender.is_player:
		defender.take_spores(&"red")

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
	_make_noise(Vector2i(defender.x, defender.y), COMBAT_NOISE, &"combat", attacker)
	if ranged:
		# A loosed arrow is heard where it was loosed. Twenty-six shots at a
		# stone golem is twenty-six calls for company.
		_make_noise(Vector2i(attacker.x, attacker.y), COMBAT_NOISE, &"combat", attacker)

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
	elif defender.is_player:
		if ranged:
			msg_log.add("The %s shoots you for %d." % [attacker.name, dmg],
				Color(0.95, 0.62, 0.35))
		else:
			msg_log.add("The %s hits you for %d." % [attacker.name, dmg],
				Color(0.90, 0.45, 0.40))
	elif map.is_visible(defender.x, defender.y) or map.is_visible(attacker.x, attacker.y):
		# Somebody else's fight -- an ally's, or the risen's against the
		# monsters. Every blow here used to read "The X hits you", whoever it
		# hit (found 2026-10-01, when the red made such fights common). Named,
		# and only when seen, so fights out of view do not fill the log.
		msg_log.add("%s %s %s for %d." % [_called(attacker, true),
			"shoots" if ranged else "hits", _called(defender, false), dmg],
			Color(0.78, 0.74, 0.66))

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
