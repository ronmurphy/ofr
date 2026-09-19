extends SceneTree

## Reproduces the two failures the enchant generator introduced, in isolation,
## so the cause is measured rather than guessed.
##
## Both failures point the same way: _maybe_enchant draws from the run's rng,
## so the NUMBER of draws now depends on how many items a floor rolls -- and if
## anything upstream of that varies with the morgue, generation stops being
## reproducible.
func _initialize() -> void:
	GameState.use_scratch_files("enchdet")
	GameState.clear_scratch_files()

	print("  enchant base is %.2f\n" % Item.ENCHANT_BASE)

	var before := _fingerprint()
	print("  fingerprint, clean morgue:   %s" % before)

	for i in 12:
		var d := GameState.new(1)
		d.new_game()
		d.depth = 1 + (i % 6)
		d.player.level = 3
		d.death_cause = "killed by a kobold"
		d.write_morgue()

	var after := _fingerprint()
	print("  fingerprint, 12 buried:      %s" % after)
	print("  match: %s" % ("yes" if before == after else "NO"))

	# How many draws the enchant roll actually takes out of the stream, and
	# whether that count moves with the morgue.
	print("\n  gem on floor two, 60 seeds:")
	var barren := 0
	for i in 60:
		var gs := GameState.new(5200 + i)
		gs.new_game()
		gs.depth = 2
		gs.build_level()
		var found := 0
		for it in gs.ground:
			if it.kind == Item.Kind.GEM:
				found += 1
		if found == 0:
			barren += 1
	print("    barren: %d of 60" % barren)

	GameState.clear_scratch_files()
	quit()

func _fingerprint() -> String:
	var walls := 0
	var doors := 0
	var mobs := 0
	for i in 8:
		var gs := GameState.new(66000 + i)
		gs.new_game()
		gs.depth = 4
		gs.build_level()
		mobs += gs.entities.size()
		for y in GameState.MAP_H:
			for x in GameState.MAP_W:
				var t := gs.map.get_tile(x, y)
				if t == Tiles.WALL:
					walls += 1
				elif t == Tiles.DOOR_CLOSED or t == Tiles.DOOR_OPEN:
					doors += 1
	return "w=%d d=%d m=%d" % [walls, doors, mobs]
