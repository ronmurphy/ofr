extends SceneTree
## GUARDS BUNCHING ON THEIR ROUNDS (2026-10-07). Fortress floors; only the
## patrolling guards act, walking their rounds for TURNS turns with nobody to
## notice. Reports, per floor, the most guards in one room and the worst
## room's threat over its ceiling, at the start and at the end. Scratch files.
##   godot --headless --path . -s tools/probes/patrol_bunch_probe.gd
const SEEDS := 24
const TURNS := 300
func _worst(g: GameState, guards: Array) -> Array:
	var most := 0
	var over := 0
	for r in g.room_rects:
		var n := 0
		var threat := 0
		for e in g.entities:
			if e.is_player or not e.alive or e.is_wild():
				continue
			if r.has_point(Vector2i(e.x, e.y)):
				threat += e.threat
				if guards.has(e):
					n += 1
		most = maxi(most, n)
		over = maxi(over, threat - g.room_threat_ceiling())
	return [most, over]
## How close the guards walk: the share of guards with another guard
## within two cells -- a convoy reads high, a spread round low.
func _crowded(guards: Array) -> float:
	var n := 0
	for e in guards:
		for o in guards:
			if o != e and Los.steps(e.x, e.y, o.x, o.y) <= 2:
				n += 1
				break
	return float(n) / maxf(1.0, float(guards.size()))
func _initialize() -> void:
	GameState.use_scratch_files("patrolprobe")
	GameState.prerun_turns = 0
	for plan in ["zero", "nearest", "beats"]:
		_run(plan)
	GameState.clear_scratch_files()
	quit()
## zero: every guard at post 0 on the one shared round (the code before
## 2026-10-07). nearest: the shared round from the post nearest each guard.
## beats: each guard's own stretch, back and forth (as built, 2026-10-07).
func _run(plan: String) -> void:
	var floors := 0
	var start_most := 0
	var end_most := 0
	var end_over_floors := 0
	var worst_over := 0
	var same_first := 0
	var guards_total := 0
	var crowd := 0.0
	var most_sum := 0
	for i in SEEDS:
		var g := GameState.new(55000 + i)
		g.new_game()
		g.depth = 7 + (i % 3)
		g.build_level()
		var guards: Array = []
		for e in g.entities:
			if e.alive and not e.is_player and e.activity == Entity.Activity.PATROLLING:
				guards.append(e)
		if guards.size() < 2:
			continue
		floors += 1
		guards_total += guards.size()
		var k := 0
		for e in guards:
			if plan != "beats":
				e.beat_lo = 0
				e.beat_hi = 0
			match plan:
				"zero": e.patrol_at = 0
				"nearest": e.patrol_at = g._nearest_post(Vector2i(e.x, e.y))
			k += 1
		var firsts := {}
		for e in guards:
			firsts[e.patrol_at % maxi(1, g.patrol_route.size())] = true
		if firsts.size() == 1:
			same_first += 1
		var a := _worst(g, guards)
		start_most = maxi(start_most, a[0])
		for t in TURNS:
			for e in guards:
				if e.alive:
					g._ai_patrol(e)
		var b := _worst(g, guards)
		crowd += _crowded(guards)
		most_sum += b[0]
		end_most = maxi(end_most, b[0])
		if b[1] > 0:
			end_over_floors += 1
		worst_over = maxi(worst_over, b[1])
	print("%-8s one first post on %2d/%d floors | most in a room: max %d, mean %.1f | guards walking within 2 of another: %.0f%% | rooms over ceiling on %d floors (worst %d)"
		% [plan, same_first, floors, end_most, float(most_sum) / maxf(1.0, float(floors)), 100.0 * crowd / maxf(1.0, float(floors)), end_over_floors, worst_over])
