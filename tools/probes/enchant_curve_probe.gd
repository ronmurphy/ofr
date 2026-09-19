extends SceneTree

## MEASURES: what the enchant curve actually yields, floor by floor, AS BUILT.
##
## Reads Item.enchant_chance() rather than restating it, so this can never drift
## from the rule it is measuring -- the mistake that had a noise test asserting
## radius 7 for a sound that emits 6.
##
## Counts ENCHANTABLE items, not all equipment. accepts_element() refuses
## anything that is not a weapon, so armour is not in the denominator: an early
## draft of this probe counted it and overstated the yield by the armour share.
## Weapons are also gated by element -- leech and frost are melee-only, return
## is arrows-only -- so a weapon that accepts NOTHING is counted as unenchantable
## too.
func _initialize() -> void:
	GameState.use_scratch_files("enchantcurve")
	var runs := 30

	print("  base %.2f, +%.3f per depth, caves x%.2f, ceiling %.2f\n" % [
		Item.ENCHANT_BASE, Item.ENCHANT_PER_DEPTH,
		Item.ENCHANT_CAVES, Item.ENCHANT_CEILING])
	print("  %-6s %-9s %7s %7s %7s %9s" % [
		"depth", "band", "equip", "ofwhich", "rate", "magical"])
	print("  %-6s %-9s %7s %7s %7s %9s" % [
		"", "", "total", "enchble", "", "observed"])
	print("  " + "-".repeat(50))

	var run_equip := 0.0
	var run_able := 0.0
	var run_magic := 0.0
	var descent := 0.0
	var climb := 0.0

	for d in range(1, 20):
		var equip := 0
		var able := 0
		var magic := 0
		for i in runs:
			var gs := GameState.new(7700 + d * 40 + i)
			gs.new_game()
			gs.depth = d
			gs.build_level()
			# The floor AND what the monsters are holding: both reach the
			# player, carried gear via _drop_loot.
			var seen: Array = []
			for it in gs.ground:
				seen.append(it)
			for e in gs.entities:
				if e.is_player:
					continue
				for held in e.equipped.values():
					if held != null:
						seen.append(held)
			for it in seen:
				if not it.is_equipment() or it.kind == Item.Kind.GEM:
					continue
				equip += 1
				var can := false
				for el in Item.FOUND_ELEMENTS:
					if it.accepts_element(el):
						can = true
						break
				if can:
					able += 1
				if it.element != &"":
					magic += 1

		var e_f := float(equip) / runs
		var a_f := float(able) / runs
		var m_f := float(magic) / runs
		run_equip += e_f
		run_able += a_f
		run_magic += m_f
		if d <= 10:
			descent += m_f
		else:
			climb += m_f
		print("  %-6d %-9s %7.1f %7.1f %6.0f%% %9.2f" % [
			d, String(Bands.NAMES[Bands.of(d)]), e_f, a_f,
			Item.enchant_chance(d) * 100.0, m_f])

	print("\n  whole run (19 floors):")
	print("    equipment                %.1f" % run_equip)
	print("    of which enchantable     %.1f  (%.0f%%)"
		% [run_able, 100.0 * run_able / maxf(run_equip, 0.001)])
	print("    arrived magical          %.1f" % run_magic)
	print("      as %% of enchantable    %.0f%%"
		% [100.0 * run_magic / maxf(run_able, 0.001)])
	print("      as %% of all equipment  %.0f%%"
		% [100.0 * run_magic / maxf(run_equip, 0.001)])
	print("    descent (1-10)           %.1f" % descent)
	print("    climb   (11-19)          %.1f" % climb)
	quit()
