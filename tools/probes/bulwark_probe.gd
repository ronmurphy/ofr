extends SceneTree

## Does the bulwark actually REACH a player, and what did the sixth gem cost?
##
## Two questions the suite cannot answer, because both are about distribution
## rather than rules: whether shields roll the stone as found magic, and how
## much the gem pool was diluted by adding to it.
const RUNS := 240

func _initialize() -> void:
	GameState.use_scratch_files("bulwark")

	# 1. The gem pool, which roll_gem picks from UNIFORMLY.
	var seen := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	for i in RUNS:
		var g := Item.roll_gem(rng, 9)
		if g != null:
			seen[g.name] = int(seen.get(g.name, 0)) + 1
	print("  the gem pool at depth 9, %d draws:" % RUNS)
	for k in seen:
		print("    %-22s %5.1f%%" % [k, 100.0 * int(seen[k]) / RUNS])

	# 2. Found magic on shields, through real generation.
	var shields := 0
	var bulwarks := 0
	var other := 0
	for i in RUNS:
		var gs := GameState.new(7000 + i)
		gs.new_game()
		gs.depth = 5
		gs.build_level()
		for it in gs.ground:
			if it == null or it.slot != Item.Slot.OFFHAND:
				continue
			shields += 1
			if it.element == &"block":
				bulwarks += 1
			elif it.element != &"":
				other += 1
	print("\n  shields found on the floor over %d floors: %d" % [RUNS, shields])
	print("    carrying the bulwark: %d" % bulwarks)
	print("    carrying anything else: %d  (must be 0 -- nothing else fits)" % other)
	quit()
