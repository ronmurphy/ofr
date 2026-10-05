extends SceneTree
## WHO KILLS THE WOLVES (Brad's play, 2026-10-05: a pack of four, three dead
## when he arrived). Builds cave floors, lets the world run with the player
## waiting where it stands, and reads each dead wolf's grudge -- the thing
## that struck it last. Scratch files only.
##   godot --headless --path . -s tools/probes/wolf_deaths_probe.gd
const SEEDS := 40
const TURNS := 150
func _initialize() -> void:
	GameState.use_scratch_files("wolfdeaths")
	var killers := {}
	var packs := 0
	var wolves_seen := 0
	var dead := 0
	var floors_with_dead := 0
	for depth in [2, 4, 5, 6]:
		for i in SEEDS:
			var gs := GameState.new(95000 + depth * 100 + i)
			gs.new_game()
			gs.depth = depth
			gs.build_level()
			var pack: Array = []
			for e in gs.entities:
				if e.appearance == &"wolf":
					pack.append(e)
			if pack.is_empty():
				continue
			packs += 1
			wolves_seen += pack.size()
			gs.player.hp = 10000
			gs.player.max_hp = 10000
			for t in TURNS:
				if gs.game_over:
					break
				gs.player_wait()
			var any := false
			for w in pack:
				if w.alive:
					continue
				dead += 1
				any = true
				var who := "nothing (no grudge)"
				if w.grudge != null:
					who = w.grudge.name + (" [player side]" if w.grudge.faction == Entity.Faction.PLAYER else "")
				killers[who] = int(killers.get(who, 0)) + 1
			if any:
				floors_with_dead += 1
	print("packs %d, wolves %d, dead after %d turns: %d (on %d floors)" % [packs, wolves_seen, TURNS, dead, floors_with_dead])
	for k in killers:
		print("  %-28s %d" % [k, killers[k]])
	quit()
