extends SceneTree
## WHERE WOLVES AND BEARS LAND (2026-10-05): floors with a pack or a bear,
## by depth and band, both halves, over seeds. Used to tune the bear's
## upper-floor band weight (about a third of floors wanted) and to confirm
## neither fortress has either. Scratch files only.
##   godot --headless --path . -s tools/probes/wolf_band_probe.gd
const SEEDS := 60
func _initialize() -> void:
	GameState.use_scratch_files("wolfband")
	print("effective band      floors-with-wolves  wolves/floor  floors-with-bear  bears/floor")
	for eff in range(1, 20):
		var wolf_floors := 0
		var wolves := 0
		var bear_floors := 0
		var bears := 0
		for i in SEEDS:
			var gs := GameState.new(90000 + eff * 100 + i)
			gs.new_game()
			gs.ascending = eff > 10
			gs.depth = eff if eff <= 10 else 20 - eff
			gs.build_level()
			var n := 0
			var b := 0
			for e in gs.entities:
				if e.appearance == &"wolf": n += 1
				if e.appearance == &"bear": b += 1
			if n > 0: wolf_floors += 1
			if b > 0: bear_floors += 1
			wolves += n
			bears += b
		print("%9d %-9s %5d/%d  %6.2f  %5d/%d  %6.2f" % [eff, Bands.NAMES[Bands.of(eff)], wolf_floors, SEEDS, float(wolves) / SEEDS, bear_floors, SEEDS, float(bears) / SEEDS])
	quit()
