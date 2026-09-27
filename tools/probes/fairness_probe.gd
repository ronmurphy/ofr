extends SceneTree

## MEASURES: can a monster shoot the player where the player cannot shoot back,
## and why. Stands the player on random cells with a real update_vision(), then
## sorts every would-be shooter 2-7 cells away by cause: the one-way line (fixed
## 2026-09-27 by Los.clear_both), the player's field of view, or a shooter in
## darkness (the torch rule). Also prints how far past the sight edge each dark
## shooter stands (Brad's rule: within 2 is fair -- DARK_SHOT_GRACE) and the
## shot-count effect of either-way vs both-ways lines.
##
## Written for the 2026-09-27 day-7 hunt, from a playtester's "they can shoot
## me round a corner and I can't shoot back".
##   godot --headless --path . -s tools/probes/fairness_probe.gd
func _initialize() -> void:
	GameState.use_scratch_files("darkprobe")
	var unfair_line := 0     # monster line clear, player's line back blocked
	var unfair_fov := 0      # both lines clear, lit, but outside the player's view
	var unfair_dark := 0     # monster cell too dark to see: the torch rule, deliberate
	var monster_shots := 0
	var either := 0
	var both := 0
	var positions := 0
	var hist := {}
	for i in 10:
		var gs := GameState.new(31000 + i * 13)
		gs.new_game()
		gs.depth = 1 + (i % 10)
		gs.build_level()
		gs.entities = [gs.player]
		var open: Array[Vector2i] = []
		for y in gs.map.height:
			for x in gs.map.width:
				if gs.map.is_walkable(x, y) and gs.map.is_transparent(x, y):
					open.append(Vector2i(x, y))
		var rng := RandomNumberGenerator.new()
		rng.seed = 5 + i
		for k in 40:
			var a: Vector2i = open[rng.randi_range(0, open.size() - 1)]
			gs.player.x = a.x
			gs.player.y = a.y
			gs.update_vision()
			positions += 1
			for dy in range(-7, 8):
				for dx in range(-7, 8):
					var b := a + Vector2i(dx, dy)
					var d := maxi(absi(dx), absi(dy))
					if d < 2 or not gs.map.in_bounds(b.x, b.y) or not gs.map.is_walkable(b.x, b.y):
						continue
					var mb := Los.clear(gs.map, b.x, b.y, a.x, a.y)
					var pa := Los.clear(gs.map, a.x, a.y, b.x, b.y)
					if mb: monster_shots += 1
					if mb or pa: either += 1
					if mb and pa: both += 1
					if not mb:
						continue
					if gs.can_reach(b, 7):
						continue
					var lit := gs.light_map.get_light(b.x, b.y).get_luminance() >= GameState.LIT_ENOUGH
					if not pa:
						unfair_line += 1
					elif not lit:
						unfair_dark += 1
						# How far past the player's own lit reach, using the edge of
						# what they can actually SEE: the farthest visible cell in line.
						var seen := 0
						for c in Los.path(a.x, a.y, b.x, b.y):
							if gs.map.is_visible(c.x, c.y):
								seen = maxi(seen, maxi(absi(c.x - a.x), absi(c.y - a.y)))
						var past := d - seen
						hist[mini(past, 6)] = int(hist.get(mini(past, 6), 0)) + 1
					else:
						unfair_fov += 1
	print("player positions %d; monster shot lines (range 2-7) today: %d" % [positions, monster_shots])
	print("monster can shoot, player cannot shoot back:")
	print("  because the line back is blocked (one-way line):     %d (%.2f%% of shots)" % [unfair_line, 100.0 * unfair_line / monster_shots])
	print("  lines clear, lit, but outside the player's view:     %d (%.2f%%)" % [unfair_fov, 100.0 * unfair_fov / monster_shots])
	print("  monster's cell too dark to see (torch rule, by design): %d (%.2f%%)" % [unfair_dark, 100.0 * unfair_dark / monster_shots])
	print("fix options, monster shot lines: today %d | clear EITHER way %d (%+.1f%%) | clear BOTH ways %d (%+.1f%%)" % [monster_shots, either, 100.0 * (either - monster_shots) / monster_shots, both, 100.0 * (both - monster_shots) / monster_shots])
	var keys := hist.keys()
	keys.sort()
	for k in keys:
		print("  dark shooter %s cells past the last visible cell on its line: %d" % [str(k) + ("+" if k == 6 else ""), hist[k]])
	GameState.clear_scratch_files()
	quit()
