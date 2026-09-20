extends SceneTree

## VERIFIES the second session's Finding 2 by DOING it rather than reading it:
## can the player kill the trader with a bow or a thrown item, and does
## anything in the game acknowledge that it happened?
##
## Reading the code says two of four attack paths skip the hostility check.
## This fires the arrow. A finding confirmed by running the thing is worth more
## than one confirmed by agreeing with the person who read it.
func _initialize() -> void:
	GameState.use_scratch_files("traderdeath")

	print("  can the player shoot the one thing that wants to talk?\n")

	var shot := 0
	var thrown := 0
	var still_listed := 0
	var runs := 0

	for i in 40:
		var gs := GameState.new(7100 + i)
		gs.new_game()
		gs.depth = 1
		gs.build_level()
		if gs.trader == null:
			continue
		runs += 1

		# Stand where a shot is clear, with a bow that is loaded.
		var bow := Item.make(&"short_bow")
		bow.ammo = bow.ammo_max
		gs.player.equipped[Item.Slot.WEAPON] = bow
		gs.player.x = gs.trader.x
		gs.player.y = gs.trader.y - 2
		if not gs.map.is_walkable(gs.player.x, gs.player.y):
			gs.player.x = gs.trader.x - 2
			gs.player.y = gs.trader.y
			if not gs.map.is_walkable(gs.player.x, gs.player.y):
				runs -= 1
				continue
		gs.update_vision()

		var fired := gs.player_fire(Vector2i(gs.trader.x, gs.trader.y))
		if fired and not gs.trader.alive:
			shot += 1
			# The consequence the codebase already argues must not happen:
			# "a trader who wandered off would turn 'there is a trader on this
			# floor' into a lie the legend tells." Dying is a stronger version
			# of wandering off.
			if gs.trader != null:
				still_listed += 1

	# And the thrown-item path, which has the identical target test.
	for i in 25:
		var gs := GameState.new(7600 + i)
		gs.new_game()
		gs.depth = 1
		gs.build_level()
		if gs.trader == null:
			continue
		var rock := Item.make(&"dagger")
		gs.give_item(rock)
		gs.player.x = gs.trader.x
		gs.player.y = gs.trader.y - 2
		if not gs.map.is_walkable(gs.player.x, gs.player.y):
			continue
		gs.update_vision()
		var idx := gs.player.inventory.find(rock)
		if idx < 0:
			continue
		if gs.player_throw(idx, Vector2i(gs.trader.x, gs.trader.y)) \
				and not gs.trader.alive:
			thrown += 1

	print("    killed with a bow      : %d of %d clear shots" % [shot, runs])
	print("    killed with a throw    : %d of 25 attempts" % thrown)
	print("    state.trader still set : %d of %d kills" % [still_listed, shot])
	print("\n    the legend row is drawn unconditionally, so after any of the")
	print("    above it still reads \"a trader -- first floor of a band\".")
	quit()
