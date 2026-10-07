extends SceneTree
## WHAT THE PRE-RUN COSTS AT A STAIRCASE (2026-10-06), per effective depth,
## descent and climb: a floor built with the pre-run off and on, same seeds,
## and the difference. Also checks the pre-run's invariants on every floor it
## builds (nobody dies, threat unchanged, main rng untouched). Scratch files.
##   godot --headless --path . -s tools/probes/prerun_cost_probe.gd
const SEEDS := 6
## Returns the floor and the milliseconds its OWN build took. new_game()
## builds floor 1 itself, so it runs with the pre-run off and is not timed:
## the first version of this probe timed both builds and reported the
## pre-run at about twice its real cost (170-260 ms; corrected 2026-10-07).
var last_ms := 0.0
func _build(seed_value: int, eff: int, turns: int) -> GameState:
	GameState.prerun_turns = 0
	var g := GameState.new(seed_value)
	g.new_game()
	g.ascending = eff > 10
	g.depth = eff if eff <= 10 else 20 - eff
	GameState.prerun_turns = turns
	var t0 := Time.get_ticks_usec()
	g.build_level()
	last_ms = (Time.get_ticks_usec() - t0) / 1000.0
	return g
func _census(g: GameState) -> Array:
	var alive := 0
	var threat := 0
	for e in g.entities:
		if not e.is_player and e.alive:
			alive += 1
			threat += e.threat
	return [alive, threat]
func _initialize() -> void:
	GameState.use_scratch_files("prerunprobe")
	print("eff  band      off_ms  on_ms  prerun_ms  animals  broken")
	var worst := 0.0
	for eff: int in [1, 2, 3, 4, 5, 6, 7, 9, 10, 12, 14, 15, 16, 17, 19]:
		var off_ms := 0.0
		var on_ms := 0.0
		var animals := 0
		var broken := 0
		for i in SEEDS:
			var s := 88000 + eff * 100 + i
			var a := _build(s, eff, 0)
			off_ms += last_ms
			var b := _build(s, eff, GameState.PRERUN_TURNS)
			on_ms += last_ms
			for e in b.entities:
				if e.alive and e.is_wild():
					animals += 1
			if _census(a) != _census(b) or a.rng.state != b.rng.state:
				broken += 1
		var pre := (on_ms - off_ms) / SEEDS
		worst = maxf(worst, pre)
		print("%3d  %-8s  %6.0f  %5.0f  %9.0f  %7.1f  %d/%d" % [eff, Bands.NAMES[Bands.of(eff)],
			off_ms / SEEDS, on_ms / SEEDS, pre, float(animals) / SEEDS, broken, SEEDS])
	print("worst pre-run cost per floor: %.0f ms" % worst)
	GameState.prerun_turns = GameState.PRERUN_TURNS
	# Leave nothing in the player's save folder (2026-10-07).
	GameState.clear_scratch_files()
	quit()
