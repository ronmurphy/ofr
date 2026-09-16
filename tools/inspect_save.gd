extends SceneTree

## Dev tool: says what every creature on the suspended floor is actually DOING.
##
##     godot --headless --script res://tools/inspect_save.gd
##
## Written after the third failed attempt in one afternoon to watch a guard
## walk. The first failure was a stale build, the second a route made of cells
## nothing can stand on, the third a save whose monsters predate patrolling
## entirely -- and every one of them would have been answered in seconds by the
## question nobody could ask: what is on this floor, and what is it up to?
##
## READS ONLY. The suspend slot is the player's own run and `load_suspend`
## deliberately DESTROYS it on read -- that deletion is the anti-scum rule --
## so this parses the file itself and never writes, renames or removes
## anything. Scratch paths are set before any GameState exists, so nothing here
## can reach a file the player owns even by accident.

func _initialize() -> void:
	var real_path := GameState.SUSPEND_PATH
	if not FileAccess.file_exists(real_path):
		print("no suspended run at %s" % real_path)
		quit()
		return
	var text := FileAccess.get_file_as_string(real_path)
	# AFTER the read, so the tool cannot be pointed at the player's slot once
	# it owns a GameState.
	GameState.use_scratch_files("inspect")

	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		print("suspend file is not readable json")
		quit()
		return
	var gs := GameState.new(1)
	if not gs.apply_dict(parsed):
		print("suspend file is from a different save version")
		quit()
		return

	var alert := {0: "unaware", 1: "suspicious", 2: "AWAKE", 3: "(old patrol)"}
	var doing := {0: "sleeping", 1: "patrolling", 2: "feeding"}
	print("")
	print("depth %d   turn %d   %s" % [gs.depth, gs.turns,
		"climbing" if gs.ascending else "descending"])
	print("patrol route: %d posts" % gs.patrol_route.size())
	print("")
	print("%-20s %-7s %-11s %-11s %s" % ["what", "where", "knows", "doing", "traits"])
	var walkers := 0
	for e in gs.entities:
		if e.is_player:
			continue
		var traits := []
		if e.patrols:
			traits.append("patrols")
		if e.scavenges:
			traits.append("scavenges")
		if e.faction == Entity.Faction.PLAYER:
			traits.append("ALLY")
		if not e.alive:
			traits.append("dead")
		if e.activity == Entity.Activity.PATROLLING:
			walkers += 1
		print("%-20s %-7s %-11s %-11s %s" % [e.name, "%d,%d" % [e.x, e.y],
			alert.get(e.alertness, "?"), doing.get(e.activity, "?"),
			", ".join(traits)])
	print("")
	print("%d creatures, %d of them walking a round" % [gs.entities.size() - 1, walkers])
	# The thing that cost an afternoon: a floor whose monsters were generated
	# before patrolling existed can never produce one, however long you wait.
	if walkers == 0:
		print("")
		print("NOBODY IS PATROLLING on this floor. If any of them say")
		print("'patrols' above, the watch was simply never rolled -- that is")
		print("a floor generated before the roll existed, and it cannot fix")
		print("itself. Descend, or start a new run.")
	GameState.clear_scratch_files()
	quit()
