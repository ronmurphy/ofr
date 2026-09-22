extends SceneTree

## Which player actions can a CONTROLLER actually reach?
##
## Every pad button is translated into a keycode with no modifiers (main.gd
## `_press` builds a bare InputEventKey), so any action that needs shift is
## unreachable from a pad no matter how it is bound.
func _initialize() -> void:
	var cfg := PadConfig.new()
	print("  bound by default:")
	var reachable := {}
	for b in cfg.binds:
		var k := int(cfg.binds[b])
		reachable[k] = true
		print("    %-14s -> %s" % [PadConfig.button_name(int(b)), OS.get_keycode_string(k)])

	print("\n  offered by the rebinding walk-through:")
	var offered := {}
	for row in PadConfig.WALK:
		offered[int(row[0])] = true
	for k in offered:
		print("    %-10s %s" % [OS.get_keycode_string(k), "(bound)" if reachable.has(k) else "(bindable, not bound)"])

	# The actions main.gd can perform, and what each one needs typed.
	var needs := {
		"descend": [KEY_GREATER, "shift+period"],
		"ascend": [KEY_LESS, "shift+comma"],
		"pray": [KEY_P, "p"],
		"torch": [KEY_T, "t"],
		"wait": [KEY_PERIOD, "period"],
		"pick up": [KEY_G, "g"],
	}
	print("\n  can a pad reach it?")
	for act in needs:
		var k: int = needs[act][0]
		var via: String = needs[act][1]
		var ok: bool = reachable.has(k) or offered.has(k)
		print("    %-9s needs %-14s  %s" % [act, via,
			"YES" if ok else "NO -- unreachable from any button"])
	quit()
