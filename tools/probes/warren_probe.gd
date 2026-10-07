extends SceneTree
## THE WARREN (Brad, 2026-10-07): rabbits in a fortress only from the warren
## vault. Over fortress floors on both halves: how many have the warren, how
## many rabbits, whether any rabbit is found away from a warren cell (with the
## pre-run off), and how far the warren's rabbits wander in the pre-run.
## A control on caves floors shows their rabbits are untouched. Scratch files.
##   godot --headless --path . -s tools/probes/warren_probe.gd
const SEEDS := 40
func _build(seed_value: int, eff: int, turns: int) -> GameState:
	GameState.prerun_turns = 0
	var g := GameState.new(seed_value)
	g.new_game()
	g.ascending = eff > 10
	g.depth = eff if eff <= 10 else 20 - eff
	GameState.prerun_turns = turns
	g.build_level()
	return g
func _rabbits(g: GameState) -> Array:
	var out := []
	for e in g.entities:
		if e.alive and e.appearance == &"rabbit":
			out.append(Vector2i(e.x, e.y))
	return out
func _initialize() -> void:
	GameState.use_scratch_files("warrenprobe")
	print("eff  band      floors-with-rabbits  rabbits/floor  wander(median, max, share>6)")
	for eff: int in [5, 7, 8, 9, 11, 12, 13, 15]:
		var with := 0
		var total := 0
		var moves := []
		for i in SEEDS:
			var s: int = 99000 + eff * 100 + i
			var still := _build(s, eff, 0)
			var lived := _build(s, eff, GameState.PRERUN_TURNS)
			var a := _rabbits(still)
			var b := _rabbits(lived)
			if a.size() > 0:
				with += 1
			total += a.size()
			if Bands.of(eff) == Bands.FORTRESS:
				for k in mini(a.size(), b.size()):
					moves.append(Los.steps(a[k].x, a[k].y, b[k].x, b[k].y))
		moves.sort()
		var far := 0
		for m in moves:
			if m > 6:
				far += 1
		var med: int = moves[moves.size() / 2] if not moves.is_empty() else 0
		var mx: int = moves[-1] if not moves.is_empty() else 0
		print("%3d  %-8s  %5d/%d  %6.2f   %s" % [eff, Bands.NAMES[Bands.of(eff)], with, SEEDS,
			float(total) / SEEDS, ("%d, %d, %d/%d" % [med, mx, far, moves.size()]) if not moves.is_empty() else "-"])
	GameState.prerun_turns = GameState.PRERUN_TURNS
	GameState.clear_scratch_files()
	quit()
