extends SceneTree

## MEASURES: what a candidate enchant curve actually yields, floor by floor.
##
## The rate is chosen against the volume it is applied to, not in the abstract.
## Equipment only -- potions, scrolls and gems can't hold an element, so they
## must never be counted in the denominator the rate is expressed against.
##
## Keyed on EFFECTIVE depth (1-19 unbroken) rather than the mirrored band,
## because the climb should keep escalating rather than replay the descent's
## rates. The band is used only to thin the caves, which are deliberately
## magic-poor: three floors down and three up where the floor itself has to
## keep you alive.

const BASE := 0.08
const PER_DEPTH := 0.016
const CAVES_MULT := 0.55
const CEILING := 0.40

static func rate_for(effective: int) -> float:
	var r: float = BASE + PER_DEPTH * (effective - 1)
	if Bands.of(effective) == Bands.CAVES:
		r *= CAVES_MULT
	return minf(r, CEILING)

func _initialize() -> void:
	GameState.use_scratch_files("enchantcurve")
	var runs := 30

	print("  candidate: base %.2f, +%.3f per depth, caves x%.2f, ceiling %.2f\n"
		% [BASE, PER_DEPTH, CAVES_MULT, CEILING])
	print("  %-6s %-9s %8s %7s %9s" % [
		"depth", "band", "equip", "rate", "magical"])
	print("  " + "-".repeat(44))

	var run_equip := 0.0
	var run_magic := 0.0
	var descent_magic := 0.0
	var climb_magic := 0.0

	for d in range(1, 20):
		var equip := 0
		for i in runs:
			var gs := GameState.new(7700 + d * 40 + i)
			gs.new_game()
			gs.depth = d
			gs.build_level()
			for it in gs.ground:
				# Only what an element could ever bind to.
				if it.is_equipment() and it.kind != Item.Kind.GEM:
					equip += 1
		var per_floor := float(equip) / runs
		var r := rate_for(d)
		var magical := per_floor * r
		run_equip += per_floor
		run_magic += magical
		if d <= 10:
			descent_magic += magical
		else:
			climb_magic += magical
		print("  %-6d %-9s %8.1f %7.0f%% %9.2f" % [
			d, String(Bands.NAMES[Bands.of(d)]), per_floor, r * 100.0, magical])

	print("\n  whole run (19 floors):")
	print("    equipment on floors      %.1f" % run_equip)
	print("    magical                  %.1f  (%.0f%% overall)"
		% [run_magic, 100.0 * run_magic / maxf(run_equip, 0.001)])
	print("    descent (1-10)           %.1f" % descent_magic)
	print("    climb   (11-19)          %.1f" % climb_magic)
	quit()
