extends SceneTree

## CHECKS two comments that assert measurements, on seeds rotated from the clock
## (the offset is printed): CAVE_TYPICAL_CELLS (threat.gd, "measured across 388
## caves") and entity.gd's "every depth-1 door generates shut". Both held on
## 2026-09-27. Re-run on hunt days -- a load-bearing number in a comment is a
## claim nobody re-checks.
##   godot --headless --path . -s tools/probes/claims_probe.gd
func _initialize() -> void:
	GameState.use_scratch_files("claimsprobe")
	var offset := int(Time.get_unix_time_from_system()) % 100000
	print("seed offset ", offset)
	var caves := 0
	var cells := 0
	var shut := 0
	var open := 0
	for i in 60:
		var gs := GameState.new(offset + i * 7)
		gs.new_game()
		gs.depth = 1 + (i % 10)
		gs.build_level()
		for r in gs.cave_regions:
			caves += 1
			cells += gs.cave_cells(r)
		if gs.depth == 1:
			for y in gs.map.height:
				for x in gs.map.width:
					var t := gs.map.get_tile(x, y)
					if t == Tiles.DOOR_CLOSED:
						shut += 1
					elif t == Tiles.DOOR_OPEN:
						open += 1
	print("caves %d, average walkable cells %.1f (constant says 113)" % [caves, float(cells) / maxf(1.0, caves)])
	print("depth-1 doors at generation: %d shut, %d open" % [shut, open])
	GameState.clear_scratch_files()
	quit()
