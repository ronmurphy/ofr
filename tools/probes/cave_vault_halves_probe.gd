extends SceneTree
## THE OPEN QUESTION IN CLAUDE.md (2026-09-20): descent caves seemed to place
## authored vaults above the rule's p=0.25 and the climb's caves below it.
## A clean measurement: REAL descent cave floors (depth 4-6) against REAL climb
## cave floors (`ascending`, depth 4-6 = effective 16-14), counting floors that
## end with an authored vault. The rule can only place one in a cave, so
## placed <= wanted and the share must sit at or below 0.25. Scratch files.
##   godot --headless --path . -s tools/probes/cave_vault_halves_probe.gd
const PER := 200
func _half(climbing: bool) -> Array:
	var with := 0
	var floors := 0
	var rects := 0
	for d in [4, 5, 6]:
		for i in PER:
			GameState.prerun_turns = 0
			var g := GameState.new(31000 + d * 1000 + i + (500 if climbing else 0))
			g.new_game()
			g.ascending = climbing
			g.depth = d
			g.build_level()
			floors += 1
			rects += g.vault_rects.size()
			if not g.vault_rects.is_empty():
				with += 1
	return [with, floors, rects]
func _initialize() -> void:
	GameState.use_scratch_files("cavehalves")
	for climbing in [false, true]:
		var r := _half(climbing)
		var p := float(r[0]) / float(r[1])
		var sd := sqrt(0.25 * 0.75 / float(r[1]))
		print("%-8s %d of %d floors with a vault = %.3f  (rule 0.25; %+.1f sd)  rects %d"
			% ["climb" if climbing else "descent", r[0], r[1], p, (p - 0.25) / sd, r[2]])
	GameState.clear_scratch_files()
	quit()
