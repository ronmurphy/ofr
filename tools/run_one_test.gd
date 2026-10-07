extends "res://tests/run_tests.gd"

## Runs ONE (or a few) of the full suite's test functions, by name, in seconds
## instead of the whole ten-minute run. For checking a single feature while
## working on it; the full suite is still the gate before a commit.
##
##   godot --headless --path . -s tools/run_one_test.gd -- _test_legends_log _test_bodies_lie_and_rot
##
## Same protections as the suite: scratch files first, cleared after. The
## result is the usual tally; grep it for SCRIPT ERROR as always (CLAUDE.md).
func _initialize() -> void:
	GameState.use_scratch_files("tests")
	# As in the suite: floors build without the pre-run (run_tests.gd).
	GameState.prerun_turns = 0
	var names := OS.get_cmdline_user_args()
	if names.is_empty():
		print("usage: godot --headless --path . -s tools/run_one_test.gd -- _test_name ...")
		quit(2)
		return
	for n in names:
		if not has_method(n):
			print("no such test: %s" % n)
			_failed += 1
			continue
		print("-- %s" % n)
		await call(n)
	GameState.clear_scratch_files()
	print("\n%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
