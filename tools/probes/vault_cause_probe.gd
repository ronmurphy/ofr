extends SceneTree

## Tries to KILL the descent/climb cave divergence cheaply, rather than explain
## it expensively.
##
## The original signal was 3.0 sigma on the DIFFERENCE between two halves, at
## ~25 floors per depth. Two problems with that:
##
##   1. Each half alone sat only ~1.8 sigma from the rule's own p=0.25. A
##      difference between two non-results can look significant when the
##      deviations happen to point opposite ways.
##   2. Worse, and mine: the comparison was CHOSEN AFTER SEEING THE DATA. All
##      19 depths were measured, the caves pair looked odd, and that pair was
##      then tested. With that many candidate comparisons available, a post-hoc
##      3 sigma is worth much less than 3 sigma sounds.
##
## So this reports each depth against 0.25 on its own terms, with its own sigma,
## at a sample large enough to decide. The difference between halves is
## deliberately NOT the headline: if both halves sit inside 2 sigma of the rule,
## there is nothing here and the thread closes.
const RUNS := 200
const P := 0.25

func _initialize() -> void:
	GameState.use_scratch_files("vaultcause")

	print("  each depth against the rule's own p=%.2f, n=%d\n" % [P, RUNS])
	print("  %-7s %-9s %8s %8s %9s" % ["depth", "half", "placed", "rate", "sigma"])
	print("  " + "-".repeat(46))

	var totals := {"descent": 0, "climb": 0}
	for d in [4, 5, 6, 14, 15, 16]:
		var placed := 0
		for i in RUNS:
			var gs := GameState.new(9900 + d * 31 + i)
			gs.new_game()
			gs.depth = d
			gs.build_level()
			# A caves floor can hold at most one under this rule, but count
			# rather than assume -- the rule is what is in question.
			placed += gs.vault_rects.size()
		var half: String = "descent" if d < 10 else "climb"
		totals[half] = int(totals[half]) + placed
		var rate := float(placed) / RUNS
		var sd := sqrt(P * (1.0 - P) / RUNS)
		print("  %-7d %-9s %8d %8.3f %+9.1f" % [
			d, half, placed, rate, (rate - P) / sd])

	print("\n  pooled, %d floors each half:" % (RUNS * 3))
	var sd3 := sqrt(P * (1.0 - P) / (RUNS * 3))
	for half in ["descent", "climb"]:
		var rate := float(int(totals[half])) / (RUNS * 3)
		print("    %-9s %.3f   %+.1f sigma from %.2f" % [
			half, rate, (rate - P) / sd3, P])
	print("\n  if both halves sit inside 2 sigma, the thread closes.")
	quit()
