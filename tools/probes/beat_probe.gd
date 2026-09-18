extends SceneTree

## CATCHES: guards that have stopped walking.
##
## This exact thing shipped broken on 2026-09-15 and took an afternoon and a
## wrong theory to find -- braziers are `walk: false`, so the route was a list
## of cells nothing can stand on and every guard stood still. Before the fix:
## 24 of 132 moved, 0.7 cells of displacement. After: 132 of 132, 27.1 cells.
func _initialize() -> void:
	GameState.use_scratch_files("beatprobe")
	print("depth 3, 25 floors")
	var braziers := 0
	var routes := 0
	var no_route := 0
	var guards := 0
	var movers := 0
	var total_steps := 0
	for i in 25:
		var gs := GameState.new(6100 + i)
		gs.new_game()
		gs.depth = 3
		gs.build_level()
		var b := 0
		for y in gs.map.height:
			for x in gs.map.width:
				var t := gs.map.get_tile(x, y)
				if t == Tiles.BRAZIER or t == Tiles.BRAZIER_SPENT:
					b += 1
		braziers += b
		routes += gs.patrol_route.size()
		if gs.patrol_route.is_empty():
			no_route += 1
		var watch := []
		for e in gs.entities:
			if e.activity == Entity.Activity.PATROLLING:
				watch.append(e)
		guards += watch.size()
		var starts := {}
		for g in watch:
			starts[g] = Vector2i(g.x, g.y)
		for _t in 200:
			for g in watch:
				if g.alive:
					gs._take_ai_turn(g)
		for g in watch:
			var moved: int = Los.steps(g.x, g.y, starts[g].x, starts[g].y)
			total_steps += moved
			if moved > 0:
				movers += 1
	print("  braziers per floor      %.1f" % (float(braziers) / 25.0))
	print("  route length per floor  %.1f" % (float(routes) / 25.0))
	print("  floors with NO route    %d of 25" % no_route)
	print("  patrollers per floor    %.1f" % (float(guards) / 25.0))
	print("  of those, ones that moved in 200 turns: %d of %d" % [movers, guards])
	print("  average displacement    %.1f cells" % (float(total_steps) / maxi(1, guards)))
	GameState.clear_scratch_files()
	quit()
