extends SceneTree

## Prints the power curve against the threat curve:
##   godot --headless --script res://tests/xp_curve.gd
##
## Not a test -- a measurement. It answers the only question that matters when
## tuning levels: does the player get stronger as fast as the dungeon does, for
## someone who fights everything, someone who fights nothing, and someone in
## between. Re-run it after touching XP_CURVE_A/B, XP_DEPTH_MULTIPLIER, the
## threat ceiling, or the bestiary.

const RUNS := 20
const MAX_DEPTH := 10

func _initialize() -> void:
	print("")
	print("  level thresholds:")
	var probe := GameState.new(1)
	probe.new_game()
	var line := "   "
	for n in range(2, 11):
		line += " L%d:%d" % [n, probe.xp_for_level(n)]
	print(line)
	print("")

	for style in [["ghost   (kills nothing)", 0.0],
			["typical (kills ~40%)", 0.4],
			["butcher (kills all)", 1.0]]:
		var lv := []
		var hp := []
		var pw := []
		var df := []
		var xp := []
		var ceil_at := []
		var mob_pow := []
		for d in MAX_DEPTH:
			lv.append(0.0); hp.append(0.0); pw.append(0.0)
			df.append(0.0); xp.append(0.0); ceil_at.append(0); mob_pow.append(0.0)

		for r in RUNS:
			var gs := GameState.new(50000 + r)
			gs.new_game()
			for i in MAX_DEPTH:
				var total := 0
				for e in gs.entities:
					if not e.is_player:
						total += e.threat
				gs.award_xp(int(round(float(total) * float(style[1]))))
				lv[i] += gs.player.level
				hp[i] += gs.player.max_hp
				pw[i] += gs.player.power
				df[i] += gs.player.defense
				xp[i] += gs.player.xp
				ceil_at[i] = gs.room_threat_ceiling()
				var mp := 0.0
				var n := 0
				for e in gs.entities:
					if not e.is_player:
						mp += e.power
						n += 1
				mob_pow[i] += mp / maxf(1.0, float(n))
				gs.player.x = gs.stairs.x
				gs.player.y = gs.stairs.y
				gs.player_descend()

		print("  %s" % style[0])
		print("    depth  ceiling   level     hp   power   def       xp   mob pow   dmg taken")
		for i in MAX_DEPTH:
			# Assume tier-appropriate armour: roughly +1 defense per 3 depths.
			var gear_def: float = df[i] / RUNS + minf(5.0, float(i) / 2.0)
			var mob: float = mob_pow[i] / RUNS
			var taken: float = maxf(ceil(mob * 0.25), mob - gear_def)
			print("      %-2d      %3d    %5.1f  %5.1f   %5.1f  %4.1f   %6.0f    %5.1f      %5.1f"
				% [i + 1, ceil_at[i], lv[i] / RUNS, hp[i] / RUNS,
				   pw[i] / RUNS, df[i] / RUNS, xp[i] / RUNS, mob, taken])
		print("")
	quit()
