extends SceneTree

## Measurement probes. Numbers about a generated dungeon, not pass/fail.
##
##     godot --headless --script tools/probes/probe.gd -- <probe> [options]
##
##     census     what a floor contains, by depth: rooms, caves, items by kind,
##                monsters, and the terrain the player can actually use
##     reach      how much of a floor you can walk to from where you start
##     doors      vault doors that open onto solid rock
##     spawns     where each creature ACTUALLY appears, against where its
##                bestiary weighting says it should
##     all        every one of the above
##
##     --seeds N    how many runs to sample (default 40)
##     --offset N   add N to every seed
##     --rotate     pick an offset from the clock, and print it
##
## WHY THIS EXISTS, and why it is separate from the test suite.
##
## The suite answers questions somebody already thought to ask. These answer
## "what do the numbers actually look like", which is a different job: every
## time this project has measured a distribution instead of asserting a
## property, it has found something. Rubble that could never appear in a cave.
## A cave bear that could not afford to live in a cave. Fungus beds that
## quadrupled in area while only doubling in count. A fortress band poorer than
## the floors above it. None of those were reported as bugs -- nothing looked
## wrong, and the comments all said the right thing.
##
## SEED ROTATION is the point of --rotate, and it is the technique that would
## have caught the worst bug this project has shipped. Tests use fixed seed
## bases, so a fault that appears on one floor in 350 can sit green for months:
## the vault-door check ran 60 seeds against exactly that, and passed by luck
## until an unrelated change reshuffled the RNG and landed on a bad map. Rotate
## the offset and anything that only passes on Monday's dungeons shows up.
##
## The offset is always PRINTED, so anything odd can be reproduced exactly with
## --offset <that number>.
##
## Every probe writes through GameState.use_scratch_files() and clears up after
## itself. A dev tool must never touch a path the player owns -- their save,
## their morgue, their bestiary record.

const DEFAULT_SEEDS := 40

var seeds := DEFAULT_SEEDS
var offset := 0

## [depth, climbing]. Depth is the FLOOR NUMBER, 1-10, and the flag says which
## way you are going -- effective_depth() is MAX_DEPTH + (MAX_DEPTH - depth) on
## the way up, so "depth 15" is not a thing you can ask for. Writing it as an
## effective depth is how a check meant to cover the climb spent a week
## measuring the descent twice.
const SWEEP := [
	[1, false], [3, false], [5, false], [6, false], [8, false], [10, false],
	[8, true], [5, true], [2, true],
]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var which := ""
	var i := 0
	while i < args.size():
		var a: String = args[i]
		if a == "--seeds" and i + 1 < args.size():
			i += 1
			seeds = maxi(1, int(args[i]))
		elif a == "--offset" and i + 1 < args.size():
			i += 1
			offset = int(args[i])
		elif a == "--rotate":
			offset = int(Time.get_unix_time_from_system()) % 900000
		elif not a.begins_with("--"):
			which = a
		i += 1

	print("OFR probes -- %d seeds, offset %d" % [seeds, offset])
	print("  reproduce with:  --seeds %d --offset %d" % [seeds, offset])
	print("")
	match which:
		"census": _census()
		"reach": _reach()
		"doors": _doors()
		"spawns": _spawns()
		"all":
			_census()
			_reach()
			_doors()
			_spawns()
		_:
			print("give a probe: census | reach | doors | spawns | all")
	quit()

## The seed a given run/depth/direction uses.
##
## Computed here rather than read back off the RandomNumberGenerator, because
## `rng.seed` advances as numbers are drawn -- reporting it would hand you a
## number that reproduces nothing, which defeats the entire point of printing
## the offset.
func _seed_for(run: int, depth: int, climbing: bool) -> int:
	return offset + run * 97 + depth * 7 + (1 if climbing else 0)

## One built floor, on scratch files, at a real depth and direction.
func _floor(run: int, depth: int, climbing: bool, tag: String) -> GameState:
	var gs := GameState.new(_seed_for(run, depth, climbing))
	gs.use_scratch_files("probe_%s" % tag)
	gs.new_game()
	gs.ascending = climbing
	gs.depth = depth
	gs.build_level()
	return gs

func _label(depth: int, climbing: bool) -> String:
	var eff: int = depth if not climbing else GameState.MAX_DEPTH * 2 - depth
	return "%2d%s %-8s" % [depth, " up" if climbing else "   ",
		Bands.NAMES[Bands.of(eff)]]

## Cells you could stand on, and are not avoided -- the pathfinder's own rule.
func _routable(gs: GameState, x: int, y: int) -> bool:
	return gs.map.is_walkable(x, y) and not Tiles.is_avoided(gs.map.get_tile(x, y))

## Four-way, because movement allows a diagonal only when both orthogonals are
## open -- which is an orthogonal route already. Under-reporting is the safe
## direction for a measurement like this.
func _reachable_from(gs: GameState, start: Vector2i) -> int:
	var seen := {start: true}
	var stack := [start]
	var n := 0
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		n += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = c + d
			if seen.has(q) or not gs.map.in_bounds(q.x, q.y):
				continue
			if not _routable(gs, q.x, q.y):
				continue
			seen[q] = true
			stack.append(q)
	return n

# ------------------------------------------------------------------ census ---

## What a floor holds. The table that found the cave loot drought, the rubble
## that could not reach caves, and a fortress band poorer than the upper one.
func _census() -> void:
	print("CENSUS -- per floor, averaged over %d runs" % seeds)
	print("%-14s %6s %6s %7s %7s %8s %7s %7s %7s" % ["band", "rooms", "caves",
		"items", "mobs", "potions", "rubble", "fungus", "water"])
	for spec in SWEEP:
		var depth: int = spec[0]
		var climbing: bool = spec[1]
		var rooms := 0.0
		var caves := 0.0
		var items := 0.0
		var mobs := 0.0
		var potions := 0.0
		var rubble := 0.0
		var fungus := 0.0
		var water := 0.0
		for run in seeds:
			var gs := _floor(run, depth, climbing, "census")
			rooms += gs.room_rects.size()
			caves += gs.cave_regions.size()
			items += gs.ground.size()
			mobs += gs.entities.size() - 1
			for it in gs.ground:
				if it.kind == Item.Kind.POTION:
					potions += 1
			for y in gs.map.height:
				for x in gs.map.width:
					match gs.map.get_tile(x, y):
						Tiles.RUBBLE: rubble += 1
						Tiles.FUNGUS: fungus += 1
						Tiles.WATER: water += 1
			gs.clear_scratch_files()
		var n := float(seeds)
		print("%-14s %6.2f %6.2f %7.2f %7.2f %8.2f %7.1f %7.1f %7.1f"
			% [_label(depth, climbing), rooms / n, caves / n, items / n, mobs / n,
			potions / n, rubble / n, fungus / n, water / n])
	print("")

# ------------------------------------------------------------------- reach ---

## How much of the floor you can actually walk to from where you woke up.
##
## Not "is the map connected" -- that passed on the floor where the player was
## sealed in an 11x7 box with the stairs, 77 cells against 821 of unreachable
## dungeon. The question has to be asked from the PLAYER's cell.
func _reach() -> void:
	print("REACH -- walkable cells the player can get to")
	print("%-14s %8s %8s %s" % ["band", "worst", "below", "worst seed"])
	for spec in SWEEP:
		var depth: int = spec[0]
		var climbing: bool = spec[1]
		var worst := 1.0
		var worst_at := "--"
		var short := 0
		for run in seeds:
			var gs := _floor(run, depth, climbing, "reach")
			var total := 0
			for y in gs.map.height:
				for x in gs.map.width:
					if _routable(gs, x, y):
						total += 1
			var got := _reachable_from(gs, Vector2i(gs.player.x, gs.player.y))
			var frac := float(got) / float(maxi(total, 1))
			if frac < 0.9999:
				short += 1
			if frac < worst:
				worst = frac
				worst_at = "seed %d (%d of %d)" % [_seed_for(run, depth, climbing), got, total]
			gs.clear_scratch_files()
		print("%-14s %7.1f%% %8d %s"
			% [_label(depth, climbing), worst * 100.0, short, worst_at])
	print("")

# ------------------------------------------------------------------- doors ---

## A vault door with fewer than two walkable sides opens onto rock.
func _doors() -> void:
	print("DOORS -- vault doors that lead nowhere")
	var blind := 0
	var doors := 0
	var bad: Array = []
	for spec in SWEEP:
		var depth: int = spec[0]
		var climbing: bool = spec[1]
		for run in seeds:
			var gs := _floor(run, depth, climbing, "doors")
			for vr in gs.vault_rects:
				for y in range(vr.position.y, vr.end.y):
					for x in range(vr.position.x, vr.end.x):
						var t := gs.map.get_tile(x, y)
						if t != Tiles.DOOR_CLOSED and t != Tiles.DOOR_OPEN:
							continue
						doors += 1
						var touching := 0
						for d in [Vector2i(1, 0), Vector2i(-1, 0),
								Vector2i(0, 1), Vector2i(0, -1)]:
							if gs.map.is_walkable(x + d.x, y + d.y):
								touching += 1
						if touching < 2:
							blind += 1
							bad.append("seed %d d%d%s"
								% [_seed_for(run, depth, climbing), depth,
								" up" if climbing else ""])
			gs.clear_scratch_files()
	print("  %d blind of %d doors (%.2f%%)"
		% [blind, doors, 100.0 * float(blind) / float(maxi(doors, 1))])
	if not bad.is_empty():
		print("  on: ", str(bad.slice(0, 8)))
	print("")

# ------------------------------------------------------------------ spawns ---

## Where a creature ACTUALLY turns up, against where the bestiary says it wants
## to be.
##
## The cave bear carries the strongest cave weighting in the game (2.6) and
## across 87 sightings on the two floors that are four fifths cavern, not one
## stood in a cave -- a cave's threat ceiling is 0.7 of a room's and could not
## afford it until depth 7, by which point the caves band is over. The weight
## never got consulted; it was rejected on price first. Anything whose "caves"
## column is high and whose "in cave" column is low is the same bug again.
func _spawns() -> void:
	print("SPAWNS -- where creatures land, against their cave preference")
	var seen := {}
	var in_cave := {}
	for spec in SWEEP:
		for run in seeds:
			var gs := _floor(run, spec[0], spec[1], "spawns")
			for e in gs.entities:
				if e.is_player or not e.alive:
					continue
				seen[e.name] = int(seen.get(e.name, 0)) + 1
				for r in gs.cave_regions:
					if r.has_point(Vector2i(e.x, e.y)):
						in_cave[e.name] = int(in_cave.get(e.name, 0)) + 1
						break
			gs.clear_scratch_files()
	print("%-16s %8s %8s %9s %s" % ["creature", "seen", "in cave", "caves wt",
		"first depth a cave can afford it"])
	for entry in GameState.BESTIARY:
		var nm: String = entry["name"]
		var n := int(seen.get(nm, 0))
		if n == 0:
			continue
		var weight := float(entry.get("caves", 1.0))
		var threat := int(entry.get("threat", 0))
		var afford := 0
		for d in range(1, 21):
			if int(round(float(GameState.ROOM_THREAT_BASE
					+ GameState.ROOM_THREAT_PER_DEPTH * d)
					* GameState.CAVE_THREAT_SCALE)) >= threat:
				afford = d
				break
		print("%-16s %8d %7.0f%% %9.1f %s"
			% [nm, n, 100.0 * float(in_cave.get(nm, 0)) / float(n), weight,
			("depth %d" % afford) if afford > 0 else "never"])
	print("")
