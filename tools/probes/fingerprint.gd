extends SceneTree

## A fingerprint of what generation actually produces, for comparing two
## versions of the code against each other.
##
## Exists because consolidating the element table touches the ORDER
## `_maybe_enchant` walks, and that order indexes `enchant_rng` -- so a
## refactor that looks purely cosmetic can silently change which element a
## given seed puts on a given item. The suite cannot catch that: its
## determinism test asserts the same seed twice agrees, which stays true when
## both runs are wrong in the same new way.
func _initialize() -> void:
	GameState.use_scratch_files("fingerprint")
	var parts := PackedStringArray()
	for seed in [11, 202, 3003, 40404]:
		for d in [2, 5, 8, 12, 16]:
			var gs := GameState.new(seed)
			gs.new_game()
			gs.depth = d
			gs.build_level()
			var items := PackedStringArray()
			for it in gs.ground:
				items.append("%s:%s" % [it.id, it.element])
			items.sort()
			var mobs := PackedStringArray()
			for e in gs.entities:
				mobs.append(e.name)
			mobs.sort()
			parts.append("%d/%d|%s|%s" % [seed, d,
				",".join(items), ",".join(mobs)])
	print("FINGERPRINT ", "|".join(parts).sha256_text())
	quit()
