extends SceneTree

## Counts how often a run actually offers a forge:
##   godot --headless --script res://tests/forge_supply.gd
##
## The brazier's ten charges are meant to pose a question -- heal, or forge --
## and the question is only real if forgeable duplicates turn up often enough
## to ask it. This walks a whole run, descent and ascent, gathers every item
## the floors produce, and counts the merges a magpie who kept everything could
## have made. It is an UPPER BOUND: nobody carries twenty items of nothing but
## duplicates.
##
## Equipment merges and consumable merges are counted apart, because only the
## first is a power gain. Merging potions loses hit points on purpose and buys
## back a turn and a slot.

const SCRATCH := "forge_supply"
const RUNS := 40
const MAX_DEPTH := 10

func _initialize() -> void:
	GameState.use_scratch_files(SCRATCH)

	var cap := Item.MAX_UPGRADES
	var gear_merges := 0.0
	var cons_merges := 0.0
	var gear_found := 0.0
	var cons_found := 0.0
	var first_gear := []
	var per_floor_gear := []
	for i in MAX_DEPTH * 2 - 1:
		per_floor_gear.append(0.0)

	for r in RUNS:
		var gs := GameState.new(80000 + r)
		gs.new_game()
		var seen := {}
		var i := 0
		var first := 0
		for d in range(1, MAX_DEPTH + 1):
			_sweep(gs, d, false, seen)
			per_floor_gear[i] = _gear_merges(seen, cap)
			if first == 0 and per_floor_gear[i] > 0:
				first = i + 1
			i += 1
		gs.ascending = true
		for d in range(MAX_DEPTH - 1, 0, -1):
			_sweep(gs, d, true, seen)
			per_floor_gear[i] = _gear_merges(seen, cap)
			if first == 0 and per_floor_gear[i] > 0:
				first = i + 1
			i += 1
		if first > 0:
			first_gear.append(first)

		for key in seen:
			var e: Dictionary = seen[key]
			var n: int = e["n"]
			var merges: int = n - int(ceil(float(n) / float(cap + 1)))
			if e["gear"]:
				gear_merges += merges
				gear_found += n
			else:
				cons_merges += merges
				cons_found += n

	var f := float(RUNS)
	print("")
	print("  forge opportunities over a full run, %d runs, upgrade cap +%d" % [RUNS, cap])
	print("")
	print("  equipment found      %6.1f per run" % (gear_found / f))
	print("  equipment merges     %6.1f per run   <- every one of these is +1 power or +1 defense" % (gear_merges / f))
	print("  consumables found    %6.1f per run" % (cons_found / f))
	print("  consumable merges    %6.1f per run   <- a slot and a turn, not power" % (cons_merges / f))
	print("")
	if first_gear.is_empty():
		print("  no run ever offered an equipment merge")
	else:
		var sum := 0
		for v in first_gear:
			sum += v
		print("  the first equipment merge becomes possible on floor %.1f of 19," % (float(sum) / float(first_gear.size())))
		print("  in %d of %d runs" % [first_gear.size(), RUNS])
	print("")
	print("  These are upper bounds: they assume every duplicate was picked up and")
	print("  carried, which a 20-slot pack does not allow.")
	print("")
	quit()

func _sweep(gs: GameState, d: int, up: bool, seen: Dictionary) -> void:
	gs.depth = d
	gs.build_level()
	for it in gs.ground:
		if not it.can_be_forged():
			continue
		if not seen.has(it.id):
			seen[it.id] = {"n": 0, "gear": it.is_equipment()}
		seen[it.id]["n"] += 1

func _gear_merges(seen: Dictionary, cap: int) -> float:
	var total := 0
	for key in seen:
		var e: Dictionary = seen[key]
		if not e["gear"]:
			continue
		var n: int = e["n"]
		total += n - int(ceil(float(n) / float(cap + 1)))
	return float(total)
