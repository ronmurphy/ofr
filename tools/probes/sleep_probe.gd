extends SceneTree

## CATCHES: the whole dungeon patrolling, or none of it.
##
## "Bipeds CAN patrol" was once implemented as "bipeds ALWAYS patrol", which
## put 39-59% of every monster on its feet, retired the first rung of the
## awareness ladder and halved what the rat ring is for. Expected now, with
## PATROL_CHANCE by band: upper 17-22%, caves 5-7%, fortress 34-37%, deep 19%.
func _initialize() -> void:
	GameState.use_scratch_files("sleepprobe")
	print("depth  monsters  patrolling  sleeping   %% awake-ish")
	for d in [1,2,3,4,5,6,7,8,9,10]:
		var mobs := 0
		var walk := 0
		var sleep := 0
		for i in 25:
			var gs := GameState.new(7000 + d * 50 + i)
			gs.new_game()
			gs.depth = d
			gs.build_level()
			for e in gs.entities:
				if e.is_player:
					continue
				mobs += 1
				if e.activity == Entity.Activity.PATROLLING:
					walk += 1
				elif e.activity == Entity.Activity.SLEEPING:
					sleep += 1
		print("  %2d     %4d       %4d      %4d      %3.0f%%"
			% [d, mobs, walk, sleep, 100.0 * walk / maxi(1, mobs)])
	GameState.clear_scratch_files()
	quit()
