extends SceneTree

## MEASURES: how many items a floor actually produces, by depth and by band.
##
## Written before the magic-item generator, because "25-30% of items should be
## magical" means nothing until you know what it is a percentage OF. A floor
## making 8 items yields 2 magical; a floor making 25 yields 7. The rate is a
## decision only once the volume is known.
##
## Counts what is ON THE GROUND at generation, plus what monsters are CARRYING,
## because both become loot the player can reach -- carried gear reaches them
## through _drop_loot, gated by LOOT_DROP_CHANCE. Reported separately since the
## generator will likely want to roll on them at different moments.
##
## Gems are counted apart from everything else: they carry weight 0, so the
## ordinary loot roll cannot produce one, and they must never be swept into an
## "items per floor" figure that the enchant rate is then applied to.
func _initialize() -> void:
	GameState.use_scratch_files("lootvol")

	var runs := 40
	print("  %-6s %-9s %8s %8s %8s %8s" % [
		"depth", "band", "ground", "carried", "total", "gems"])
	print("  " + "-".repeat(56))

	# Every descent floor plus three on the climb, to confirm the mirrored
	# bands really do produce the same volume as the floors they fold onto.
	var floors := [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 14, 17]
	var by_band := {}

	for d in floors:
		var ground_n := 0
		var carried_n := 0
		var gems_n := 0
		for i in runs:
			var gs := GameState.new(4400 + d * 50 + i)
			gs.new_game()
			gs.depth = d
			gs.build_level()
			for it in gs.ground:
				if it.kind == Item.Kind.GEM:
					gems_n += 1
				else:
					ground_n += 1
			for e in gs.entities:
				if e.is_player:
					continue
				for it in e.equipped.values():
					if it != null:
						carried_n += 1

		var band: String = String(Bands.NAMES[Bands.of(d)])
		var g := float(ground_n) / runs
		var c := float(carried_n) / runs
		print("  %-6d %-9s %8.1f %8.1f %8.1f %8.2f" % [
			d, band, g, c, g + c, float(gems_n) / runs])

		if not by_band.has(band):
			by_band[band] = [0.0, 0.0, 0]
		var acc: Array = by_band[band]
		acc[0] = float(acc[0]) + g
		acc[1] = float(acc[1]) + c
		acc[2] = int(acc[2]) + 1

	print("\n  per band, averaged over its floors:")
	print("  %-9s %8s %8s %8s" % ["band", "ground", "carried", "total"])
	print("  " + "-".repeat(38))
	for band in by_band:
		var acc: Array = by_band[band]
		var n := int(acc[2])
		var g := float(acc[0]) / n
		var c := float(acc[1]) / n
		print("  %-9s %8.1f %8.1f %8.1f" % [band, g, c, g + c])

	# What a given enchant rate would actually yield, so the number is chosen
	# against the thing it produces rather than in the abstract.
	print("\n  a full descent (floors 1-10), ground items only:")
	var total := 0.0
	for d in range(1, 11):
		var n := 0
		for i in runs:
			var gs := GameState.new(4400 + d * 50 + i)
			gs.new_game()
			gs.depth = d
			gs.build_level()
			for it in gs.ground:
				if it.kind != Item.Kind.GEM and it.is_equipment():
					n += 1
		total += float(n) / runs
	print("    equipment on the floor, whole descent: %.1f" % total)
	for rate in [0.10, 0.20, 0.25, 0.30]:
		print("    at %d%%: %.1f magical over ten floors" % [
			int(rate * 100), total * rate])

	quit()
