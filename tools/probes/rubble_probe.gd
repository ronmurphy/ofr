extends SceneTree

## MEASURES: rubble piles per floor (average, min, max) and the gem sources
## beside them -- chests, shrines, sacks, gems on the ground. Written 2026-09-25
## to size the rubble gem: rubble runs 0-114 a floor, so a flat per-pile chance
## was rejected for one hidden gem pile per floor.
##   godot --headless --path . -s tools/probes/rubble_probe.gd
func _initialize() -> void:
	GameState.use_scratch_files("rubbleprobe")
	var runs := 40
	print("  depth band      rubble(avg min max)  chests shrines sacks ground-gems")
	for d in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 14, 17]:
		var tot := 0
		var lo := 99999
		var hi := 0
		var chests := 0
		var shrines := 0
		var sacks := 0
		var gems := 0
		for i in runs:
			var gs := GameState.new(7100 + d * 50 + i)
			gs.new_game()
			if d > GameState.MAX_DEPTH:
				gs.ascending = true
				gs.depth = GameState.MAX_DEPTH * 2 - d
			else:
				gs.depth = d
			gs.build_level()
			var n := 0
			for y in gs.map.height:
				for x in gs.map.width:
					var t := gs.map.get_tile(x, y)
					if t == Tiles.RUBBLE:
						n += 1
					elif t == Tiles.CHEST:
						chests += 1
					elif t == Tiles.SHRINE:
						shrines += 1
			for it in gs.ground:
				if it.id == &"sack":
					sacks += 1
				if it.kind == Item.Kind.GEM:
					gems += 1
			tot += n
			lo = mini(lo, n)
			hi = maxi(hi, n)
		print("  %-5d %-9s %6.1f %4d %4d        %5.2f  %5.2f  %5.2f  %5.2f" % [d,
			Bands.NAMES[Bands.of(d)], float(tot) / runs, lo, hi,
			float(chests) / runs, float(shrines) / runs, float(sacks) / runs,
			float(gems) / runs])
	GameState.clear_scratch_files()
	quit()
