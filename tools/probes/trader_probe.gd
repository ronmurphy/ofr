extends SceneTree

## MEASURES: that a trader stands on the first floor of every band and nowhere
## else, and that the floor-one trader is actually findable.
##
## The second half is the one that matters. A trader carrying the game's only
## explanation of why you are down here is worthless if the player walks past
## without meeting them, and "near your starting room" is a claim that has to be
## measured rather than asserted -- _place_first_gem shipped putting its gem in
## room 0 and read as the game apologising for its drop rates.
func _initialize() -> void:
	GameState.use_scratch_files("traderprobe")
	var runs := 30

	print("  %-6s %-9s %8s   %s" % ["depth", "band", "traders", "note"])
	print("  " + "-".repeat(46))
	for d in range(1, 20):
		var found := 0
		for i in runs:
			var gs := GameState.new(8800 + d * 30 + i)
			gs.new_game()
			gs.depth = d
			gs.build_level()
			if gs.trader != null:
				found += 1
		var want: bool = GameState.TRADER_FLOORS.has(d)
		var ok: bool = (found == runs) if want else (found == 0)
		print("  %-6d %-9s %5d/%-3d  %s%s" % [
			d, String(Bands.NAMES[Bands.of(d)]), found, runs,
			"expected" if want else "none expected",
			"" if ok else "   <-- WRONG"])

	# How far the player has to walk on floor one, in steps, and whether the
	# trader is ever somewhere they would never go.
	print("\n  floor one: how far the trader is from where you wake")
	var dists: Array[int] = []
	var same_room := 0
	for i in 60:
		var gs := GameState.new(9300 + i)
		gs.new_game()
		gs.depth = 1
		gs.build_level()
		if gs.trader == null:
			continue
		var d := absi(gs.trader.x - gs.player.x) + absi(gs.trader.y - gs.player.y)
		dists.append(d)
		if not gs.room_rects.is_empty() \
				and gs.room_rects[0].has_point(Vector2i(gs.trader.x, gs.trader.y)):
			same_room += 1
	dists.sort()
	if dists.is_empty():
		print("    no traders placed at all")
	else:
		var total := 0
		for v in dists:
			total += v
		print("    placed %d of 60" % dists.size())
		print("    distance  min %d   median %d   max %d   mean %.1f" % [
			dists[0], dists[dists.size() / 2], dists[-1],
			float(total) / dists.size()])
		print("    in your own starting room: %d" % same_room)

	# How often the trader lands on the stairs. Walking into it talks rather
	# than swapping, so a trader on the way down is a floor with no exit.
	print("\n  trader standing on the stairs, 40 seeds per trader floor:")
	var blocked := 0
	var checked := 0
	for d in GameState.TRADER_FLOORS:
		for i in 40:
			var g := GameState.new(2400 + int(d) * 70 + i)
			g.new_game()
			g.depth = int(d)
			g.build_level()
			if g.trader == null:
				continue
			checked += 1
			if Vector2i(g.trader.x, g.trader.y) == g.stairs:
				blocked += 1
	print("    %d of %d floors softlocked" % [blocked, checked])

	# A trader must never be hostile, and nothing must be hostile to it.
	var gs2 := GameState.new(4)
	gs2.new_game()
	gs2.depth = 1
	gs2.build_level()
	if gs2.trader != null:
		var hostile := 0
		for e in gs2.entities:
			if e.hostile_to(gs2.trader) or gs2.trader.hostile_to(e):
				hostile += 1
		print("\n  things hostile to the trader (want 0): %d" % hostile)

	quit()
