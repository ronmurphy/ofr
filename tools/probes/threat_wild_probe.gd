extends SceneTree
## THREAT PER FLOOR, with and without the wild (2026-10-05). Builds each
## depth over many seeds and sums the threat of what is spawned: ALL of it
## (what the ceiling arithmetic counts, and what the player faced before the
## bat, the bear and the rabbit went WILD) against what is HOSTILE unstruck.
## The gap is what the floors lost. Scratch files only.
##   godot --headless --path . -s tools/probes/threat_wild_probe.gd
const SEEDS := 60

func _initialize() -> void:
	GameState.use_scratch_files("threatprobe")
	print("depth  total  hostile  wild   lost%   wild creatures/floor (bat rabbit bear)")
	for depth in range(1, 11):
		var total := 0.0
		var hostile := 0.0
		var wild := 0.0
		var bats := 0
		var rabbits := 0
		var bears := 0
		for i in SEEDS:
			var gs := GameState.new(70000 + depth * 100 + i)
			gs.new_game()
			gs.depth = depth
			gs.build_level()
			for e in gs.entities:
				if e.is_player or not e.alive:
					continue
				total += e.threat
				if e.hostile_to(gs.player):
					hostile += e.threat
				if e.is_wild():
					wild += e.threat
					match String(e.appearance):
						"bat": bats += 1
						"rabbit": rabbits += 1
						"bear": bears += 1
		var lost := 0.0 if total == 0.0 else (total - hostile) / total * 100.0
		print("%5d  %5.1f  %7.1f  %5.1f  %5.1f%%   %.2f %.2f %.2f" % [depth, total / SEEDS,
			hostile / SEEDS, wild / SEEDS, lost, float(bats) / SEEDS, float(rabbits) / SEEDS,
			float(bears) / SEEDS])
	GameState.clear_scratch_files()
	quit()
