extends SceneTree

## CHECKS a measurement written into a comment: mapgen.gd:208 says "Roughly
## three floors in ten have none."
##
## That line sits directly above `wanted = 0 if roll < 0.30`, so it is exactly
## true about the ROLL. The claim a reader takes from it is about floors that
## end up with no authored room, and those are different numbers -- `wanted` is
## a request, and a vault that will not fit is not placed.
##
## Day-7 technique: a comment asserting a measurement is a claim, and a claim
## that nothing re-checks drifts. Two were found lying on 09-18.
func _initialize() -> void:
	GameState.use_scratch_files("vaultrate")
	var runs := 25

	print("  authored rooms actually placed, %d floors per depth\n" % runs)
	print("  %-6s %-9s %7s %7s   %s" % ["depth", "band", "none", "mean", "spread"])
	print("  " + "-".repeat(50))

	var barren := 0
	var floors := 0
	for d in range(1, 20):
		var none := 0
		var total := 0
		var counts := {}
		for i in runs:
			var gs := GameState.new(6600 + d * 25 + i)
			gs.new_game()
			gs.depth = d
			gs.build_level()
			var n := gs.vault_rects.size()
			total += n
			counts[n] = int(counts.get(n, 0)) + 1
			if n == 0:
				none += 1
		barren += none
		floors += runs
		var spread := ""
		for k in [0, 1, 2, 3, 4, 5]:
			if counts.has(k):
				spread += "%d:%d  " % [k, int(counts[k])]
		print("  %-6d %-9s %6.0f%% %7.2f   %s" % [
			d, String(Bands.NAMES[Bands.of(d)]),
			100.0 * none / runs, float(total) / runs, spread])

	print("\n  whole dungeon: %.0f%% of floors have no authored room"
		% [100.0 * barren / floors])
	print("  the comment says roughly 30%")
	quit()
