extends SceneTree

## CATCHES: scavengers destroying loot, and threat drifting past the budget.
##
## An item on the floor is certain; the same item on a monster is a coin flip
## (LOOT_DROP_CHANCE 0.5), so scavenging silently deleted half of what it took
## -- about 21 items per 20 floors on depth 2 -- until `Item.scavenged` made
## stolen gear always drop. Threat drift of +2.7% to +6.4% over 300 turns is
## expected and accepted; much more than that wants looking at.

## Two questions the scavenger raises and nobody has answered:
##   1. How much floor loot is gone before the player reaches it?
##   2. How much threat does a floor gain after generation priced it?
func _initialize() -> void:
	GameState.use_scratch_files("scavprobe")
	print("depth  loot@gen  loot@300t  taken   threat@gen  threat@300t  drift")
	for d in [2, 5, 8, 10]:
		var g0 := 0
		var g1 := 0
		var t0 := 0
		var t1 := 0
		var runs := 20
		for i in runs:
			var gs := GameState.new(9100 + d * 30 + i)
			gs.new_game()
			gs.depth = d
			gs.build_level()
			for it in gs.ground:
				if it.is_equipment():
					g0 += 1
			for e in gs.entities:
				if not e.is_player:
					t0 += e.threat
			# A floor's worth of turns with nobody in it. The player is parked
			# far away and never acts, so nothing is reacting to them.
			for _t in 300:
				for e in gs.entities:
					if not e.is_player and e.alive:
						gs._take_ai_turn(e)
			for it in gs.ground:
				if it.is_equipment():
					g1 += 1
			for e in gs.entities:
				if not e.is_player and e.alive:
					t1 += e.threat
		var taken := g0 - g1
		print("  %2d     %4d      %4d     %4d      %5d       %5d    %+.1f%%"
			% [d, g0, g1, taken, t0, t1,
			100.0 * (float(t1) - float(t0)) / maxf(1.0, float(t0))])
	GameState.clear_scratch_files()
	quit()
