extends SceneTree
## NAPS ON ARRIVAL (2026-10-07): after the pre-run, how many of a floor's
## animals are asleep, and whether bears in dens are. Scratch files only.
##   godot --headless --path . -s tools/probes/nap_probe.gd
const SEEDS := 20
func _initialize() -> void:
	GameState.use_scratch_files("napprobe")
	print("eff  band      animals  asleep  den bears  den asleep")
	for eff: int in [2, 5, 15, 18]:
		var animals := 0
		var asleep := 0
		var dens := 0
		var den_asleep := 0
		for i in SEEDS:
			GameState.prerun_turns = 0
			var g := GameState.new(66000 + eff * 100 + i)
			g.new_game()
			g.ascending = eff > 10
			g.depth = eff if eff <= 10 else 20 - eff
			GameState.prerun_turns = GameState.PRERUN_TURNS
			g.build_level()
			for e in g.entities:
				if not e.alive or not e.is_wild():
					continue
				if e.denned:
					dens += 1
					if e.alertness == Entity.Alert.ASLEEP:
						den_asleep += 1
				elif e.ai != &"forager":
					animals += 1
					if e.alertness == Entity.Alert.ASLEEP:
						asleep += 1
		print("%3d  %-8s  %7d  %6d  %9d  %10d" % [eff, Bands.NAMES[Bands.of(eff)], animals, asleep, dens, den_asleep])
	GameState.clear_scratch_files()
	quit()
