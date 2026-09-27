extends SceneTree

## MEASURES: rooms per floor by band. Written 2026-09-26 to size the gem of the
## road (+1 defense per 4 new rooms): ~13 upper, ~5 caves, ~9-10 fortress, ~13
## deep -- which is why the road stone barely grows in the caves.
##   godot --headless --path . -s tools/probes/room_probe.gd
func _initialize() -> void:
	GameState.use_scratch_files("roomprobe")
	for d in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]:
		var tot := 0
		var lo := 999
		var hi := 0
		for i in 20:
			var gs := GameState.new(9300 + d * 31 + i)
			gs.new_game()
			gs.depth = d
			gs.build_level()
			var n: int = gs.room_rects.size()
			tot += n
			lo = mini(lo, n)
			hi = maxi(hi, n)
		print("  depth %-3d %-9s rooms avg %5.1f  min %d  max %d" % [d, Bands.NAMES[Bands.of(d)], float(tot) / 20.0, lo, hi])
	GameState.clear_scratch_files()
	quit()
