extends SceneTree

## MEASURES: walkable cells per floor, and max HP by level. Written 2026-09-26:
## at +1 hp per 10 cells a "heal by exploring" gem would have given 125-150 hp a
## floor against ~75 from every other source, which is why the road stone
## became DEFENSE per room instead.
##   godot --headless --path . -s tools/probes/walk_probe.gd
func _initialize() -> void:
	GameState.use_scratch_files("walkprobe")
	print("  depth  walkable(avg min max)  max_hp_at_expected_level")
	for d in [1, 3, 5, 7, 10]:
		var tot := 0
		var lo := 99999
		var hi := 0
		for i in 20:
			var gs := GameState.new(9100 + d * 31 + i)
			gs.new_game()
			gs.depth = d
			gs.build_level()
			var n := 0
			for y in gs.map.height:
				for x in gs.map.width:
					if gs.map.is_walkable(x, y):
						n += 1
			tot += n
			lo = mini(lo, n)
			hi = maxi(hi, n)
		print("  %-5d  %6.0f %5d %5d" % [d, float(tot) / 20.0, lo, hi])
	for lv in [1, 3, 5, 8, 11]:
		print("  level %d max hp %d" % [lv, GameState.new(1).hp_at_level(lv)])
	GameState.clear_scratch_files()
	quit()
