extends SceneTree

## Prints the healing economy against the cost of clearing a floor:
##   godot --headless --script res://tests/attrition.gd
##
## Not a test -- a measurement, in the spirit of xp_curve.gd. It answers the
## question a full run raises and no unit test can: does the dungeon hand out
## enough healing to pay for the damage it deals, at every depth including the
## ascent.
##
## Healing supply is everything a floor holds that restores hit points:
## brazier charge, fungus caps, and healing potions lying on the ground.
## Attrition is what clearing that same floor costs, monster by monster, in a
## straight melee duel at the two sides' actual speeds and the real damage
## formula. Both are then read as a FRACTION OF MAX HP, because max hp grows
## five a level and brazier charge does not.

const SCRATCH := "attrition"
const RUNS := 24
const MAX_DEPTH := 10
## What a floor's monsters are worth in experience to someone who fights most
## but not all of them -- the middle column of xp_curve.gd.
const KILL_RATE := 0.4
const BOW_REACH := 8

func _initialize() -> void:
	GameState.use_scratch_files(SCRATCH)

	var floors := MAX_DEPTH * 2 - 1
	var braz := []
	var fung := []
	var potn := []
	var cost := []
	var bow := []
	var mhp := []
	var lvl := []
	var eff := []
	for i in floors:
		braz.append(0.0); fung.append(0.0); potn.append(0.0)
		cost.append(0.0); bow.append(0.0)
		mhp.append(0.0); lvl.append(0.0); eff.append(0)

	for r in RUNS:
		var gs := GameState.new(70000 + r)
		gs.new_game()
		var i := 0
		for d in range(1, MAX_DEPTH + 1):
			_walk(gs, d, false, i, braz, fung, potn, cost, bow, mhp, lvl, eff)
			i += 1
		gs.ascending = true
		for d in range(MAX_DEPTH - 1, 0, -1):
			_walk(gs, d, true, i, braz, fung, potn, cost, bow, mhp, lvl, eff)
			i += 1

	print("")
	print("  healing economy, %d runs, killing ~%d%% of what it meets" % [RUNS, int(KILL_RATE * 100)])
	print("")
	print("  floor  eff  lvl  maxhp |  brazier  fungus  potion  SUPPLY | COST melee  bow    net")
	for i in floors:
		var n := float(RUNS)
		var hp: float = mhp[i] / n
		var b: float = braz[i] / n
		var f: float = fung[i] / n
		var p: float = potn[i] / n
		var supply := b + f + p
		var c: float = cost[i] / n
		var w: float = bow[i] / n
		var label := "%d" % (i + 1) if i < MAX_DEPTH else "%d up" % (2 * MAX_DEPTH - 1 - i)
		print("  %-5s %4d %4.1f %6.1f | %8.0f %7.0f %7.0f %6d%% | %8d%% %4d%% %+5d%%" % [
			label, eff[i], lvl[i] / n, hp,
			b, f, p, int(round(100.0 * supply / hp)),
			int(round(100.0 * c / hp)), int(round(100.0 * w / hp)),
			int(round(100.0 * (supply - w) / hp))])
	print("")
	print("  All figures are percentages of max hp. COST is the price of killing")
	print("  EVERYTHING on the floor, in melee and with a reach-8 bow. Net is")
	print("  supply minus the bow figure: below zero the floor takes more than it")
	print("  gives back, and the deficit comes out of what was carried in.")
	print("")
	quit()

func _walk(gs: GameState, d: int, up: bool, i: int, braz: Array, fung: Array,
		potn: Array, cost: Array, bow: Array, mhp: Array, lvl: Array,
		eff: Array) -> void:
	gs.depth = d
	gs.build_level()
	eff[i] = gs.effective_depth()

	# Experience is mostly paid for ARRIVING, not for killing -- one floor is
	# worth room_threat_ceiling() * XP_DEPTH_MULTIPLIER -- so a model that only
	# counts kills lands the player nine levels short of a real run.
	gs.award_xp(gs.room_threat_ceiling() * GameState.XP_DEPTH_MULTIPLIER)
	var threat := 0
	for e in gs.entities:
		if not e.is_player:
			threat += e.threat
	gs.award_xp(int(round(float(threat) * KILL_RATE)))
	mhp[i] += gs.player.max_hp
	lvl[i] += gs.player.level

	# --- what the floor gives back ---
	var charge := 0
	for cell in gs.brazier_charge:
		charge += int(gs.brazier_charge[cell])
	braz[i] += charge
	var caps := 0
	for y in GameState.MAP_H:
		for x in GameState.MAP_W:
			if gs.map.get_tile(x, y) == Tiles.FUNGUS:
				caps += 1
	fung[i] += caps
	var pot := 0
	for it in gs.ground:
		if it.effect == &"heal":
			pot += it.effective_magnitude()
	potn[i] += pot

	# --- what the floor costs to clear ---
	var atk := gs.player.total_power() + _weapon_for(gs.effective_depth())
	var def := gs.player.total_defense() + _armour_for(gs.effective_depth())
	var melee := 0.0
	var archer := 0.0
	for e in gs.entities:
		if e.is_player:
			continue
		melee += _duel(atk, def, e, 1)
		archer += _duel(atk, def, e, BOW_REACH)
	cost[i] += melee
	bow[i] += archer

## Gear the model is not wearing. The player entity in this harness never picks
## anything up, so armour has to be supplied, ramping from nothing to the plate
## a real run is wearing by the end.
func _armour_for(depth: int) -> int:
	return mini(8, int(round(float(depth) * 0.45)))

## Likewise the weapon. A war bow +1 is +7 by the end of a real run.
func _weapon_for(depth: int) -> int:
	return mini(7, int(round(float(depth) * 0.40)))

## One duel, average rolls. Returns hit points the player loses killing it.
##
## `reach` is the player's: at 1 the thing is in your face from the first
## swing, at 8 it has to cross seven cells first and eats a shot for every one
## of its steps it is slower than you. That gap is the whole reason the bow is
## worth carrying, so a model that ignores it measures a game nobody plays.
func _duel(atk: int, def: int, m: Entity, reach: int) -> float:
	var to_them := maxi(maxi(1, int(ceil(float(atk) * GameState.DAMAGE_FLOOR_FRACTION))),
		atk - m.total_defense())
	var to_me := maxi(maxi(1, int(ceil(float(m.power) * GameState.DAMAGE_FLOOR_FRACTION))),
		m.power - def)
	var swings: float = ceil(float(m.hp) / float(to_them))
	# Shots landed while it closes. A ranged monster answers in kind and gets
	# none of this grace.
	if reach > 1 and m.ai != &"ranged":
		var free: float = float(reach - 1) * (float(Scheduler.ACTION_COST) / float(m.speed))
		swings = maxf(0.0, swings - free)
	# Energy is handed out in proportion to speed, so a monster at 140 acts
	# 1.4 times for every one of the player's turns at 100.
	var theirs := swings * (float(m.speed) / float(Scheduler.ACTION_COST))
	return theirs * float(to_me)
