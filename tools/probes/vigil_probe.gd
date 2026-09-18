extends SceneTree

## CATCHES: the gong being answered by nobody.
##
## Before `pursue_turns` existed the vigil woke 244 things across 12 depth-2
## floors and EIGHT arrived -- the median monster starts 31-38 cells out and an
## ordinary memory is 10 turns. Expected now: GAVE UP should be ZERO. "Reached
## you" is space-limited (about two dozen cells lie within 2 of the player), so
## it is not the number to read.

## The gong says "20 things answer". How many actually arrive?
##
## An awake monster that cannot see the player gives up after 10 turns
## (`lost_turns > 10`), and the map is 96x54 -- so anything more than about ten
## cells away may set off, forget why, and settle down again halfway.
func _initialize() -> void:
	GameState.use_scratch_files("vigilprobe")
	print("depth  woken  reached you  gave up  still coming   median start distance")
	for d in [2, 5, 8]:
		var woken := 0
		var arrived := 0
		var gave_up := 0
		var coming := 0
		var starts := []
		for i in 12:
			var gs := GameState.new(2400 + d * 70 + i)
			gs.new_game()
			gs.depth = d
			gs.build_level()
			var mobs := []
			for e in gs.entities:
				if not e.is_player and e.alive:
					mobs.append(e)
					starts.append(Los.steps(e.x, e.y, gs.player.x, gs.player.y))
			gs._invoke_shrine(Shrines.VIGIL)
			for e in mobs:
				if e.alertness == Entity.Alert.AWAKE:
					woken += 1
			# A generous window: 60 of the player's turns.
			for _t in 60:
				for e in mobs:
					if e.alive:
						gs._take_ai_turn(e)
			for e in mobs:
				if not e.alive:
					continue
				var d2 := Los.steps(e.x, e.y, gs.player.x, gs.player.y)
				if d2 <= 2:
					arrived += 1
				elif e.alertness == Entity.Alert.AWAKE:
					coming += 1
				else:
					gave_up += 1
		starts.sort()
		var med: int = starts[starts.size() / 2] if not starts.is_empty() else 0
		print("  %2d    %4d      %4d      %4d       %4d          %d cells"
			% [d, woken, arrived, gave_up, coming, med])
	GameState.clear_scratch_files()
	quit()
