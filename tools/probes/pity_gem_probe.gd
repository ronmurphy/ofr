extends SceneTree

## VERIFIES a finding from the second session: the pity-gem guarantee still
## reads "is the player wearing something elemental" when it means "has this
## player bound a gem", and found magic made those two different things.
##
## Two questions, deliberately separate:
##   1. Does the branch fire at all? A yes/no, provable in one build.
##   2. Can a player realistically be wielding found magic that early? A rate,
##      and the thing that decides whether this matters or is theoretical.
func _initialize() -> void:
	GameState.use_scratch_files("pitygem")

	# --- 1. does it fire -----------------------------------------------------
	# A weapon that arrived enchanted, exactly as the generator would produce
	# it: element set, nothing recording that a gem was ever involved.
	print("  1. player wielding a GENERATED enchanted weapon\n")
	var barren_armed := 0
	var barren_bare := 0
	var runs := 40
	for d in GameState.GEM_PITY_FLOORS:
		for i in runs:
			# Bare control, same seed: the only difference is the weapon.
			var bare := GameState.new(3300 + int(d) * 90 + i)
			bare.new_game()
			bare.depth = int(d)
			bare.build_level()
			if not _has_gem(bare):
				barren_bare += 1

			var armed := GameState.new(3300 + int(d) * 90 + i)
			armed.new_game()
			var sword := Item.make(&"short_sword")
			sword.element = &"fire"
			armed.player.equipped[Item.Slot.WEAPON] = sword
			armed.depth = int(d)
			armed.build_level()
			if not _has_gem(armed):
				barren_armed += 1

	var total := GameState.GEM_PITY_FLOORS.size() * runs
	print("    bare-handed player : %d of %d floors had no gem" % [barren_bare, total])
	print("    carrying found magic: %d of %d floors had no gem" % [barren_armed, total])

	# --- 2. could they be, that early ---------------------------------------
	print("\n  2. how often depth 1 offers an enchanted weapon at all\n")
	var offered := 0
	var best_is_magic := 0
	for i in 200:
		var gs := GameState.new(5500 + i)
		gs.new_game()
		gs.depth = 1
		gs.build_level()
		var any := false
		var best_power := -1
		var best_magic := false
		var pool: Array = []
		for it in gs.ground:
			pool.append(it)
		for e in gs.entities:
			if e.is_player:
				continue
			for slot in e.equipped:
				if e.equipped[slot] != null:
					pool.append(e.equipped[slot])
		for it in pool:
			if it.kind != Item.Kind.WEAPON or it.transforms():
				continue
			if it.element != &"":
				any = true
			# What a player actually equips is the strongest thing they find,
			# not the shiniest -- so the rate that matters is how often the
			# BEST weapon on the floor is also the enchanted one.
			if it.power_bonus > best_power:
				best_power = it.power_bonus
				best_magic = it.element != &""
		if any:
			offered += 1
		if best_magic:
			best_is_magic += 1
	print("    a magic weapon existed somewhere : %d of 200 (%.0f%%)"
		% [offered, offered * 0.5])
	print("    the STRONGEST weapon was magic   : %d of 200 (%.0f%%)"
		% [best_is_magic, best_is_magic * 0.5])

	# --- 3. the other session's secondary note ------------------------------
	print("\n  3. do gems carry an element (and so take the MAGIC tint)?\n")
	for key in [&"gem_fire", &"gem_frost", &"gem_leech"]:
		var g := Item.make(key)
		print("    %-12s kind=GEM element=%s  -> tinted: %s"
			% [g.name, g.element, "yes" if g.element != &"" else "no"])

	quit()

func _has_gem(gs: GameState) -> bool:
	for it in gs.ground:
		if it.kind == Item.Kind.GEM:
			return true
	return false
