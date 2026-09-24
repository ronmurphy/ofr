extends SceneTree

## What a run actually produces, by item, so the trader's exchange rate can be
## set against supply rather than against intuition.
##
## The proposed rate is 3^(tiers up): nine daggers for a war axe. That is only a
## real choice if nine daggers can exist; if the answer is two, the rate is a
## rule nobody ever gets to use.
const RUNS := 40

func _initialize() -> void:
	GameState.use_scratch_files("tradesupply")
	var seen := {}
	var slots := {}
	for i in RUNS:
		var gs := GameState.new(5150 + i)
		gs.new_game()
		var run := {}
		# A whole descent, floor by floor, as a player would meet it.
		for d in range(1, 11):
			gs.depth = d
			gs.build_level()
			for it in gs.ground:
				if not it.is_equipment():
					continue
				run[it.id] = int(run.get(it.id, 0)) + 1
				slots[it.slot] = int(slots.get(it.slot, 0)) + 1
		for id in run:
			if not seen.has(id):
				seen[id] = []
			(seen[id] as Array).append(int(run[id]))

	print("  equipment met over a full descent, %d runs\n" % RUNS)
	print("  %-18s %6s %6s %6s   %s" % ["item", "mean", "max", "min", "tier hint"])
	print("  " + "-".repeat(62))
	var ids := seen.keys()
	ids.sort()
	for id in ids:
		var vals: Array = seen[id]
		var total := 0
		var hi := 0
		var lo := 999
		for v in vals:
			total += int(v)
			hi = maxi(hi, int(v))
			lo = mini(lo, int(v))
		var data: Dictionary = Item.CATALOGUE[id]
		var power := int(data.get("power", 0)) + int(data.get("defense", 0))
		print("  %-18s %6.1f %6d %6d   power/def %d" % [
			id, float(total) / RUNS, hi, lo, power])
	quit()
