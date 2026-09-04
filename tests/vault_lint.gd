extends SceneTree

## Checks every vault in assets/vaults/ for the mistakes that are easy to make
## and hard to see:
##   godot --headless --script res://tests/vault_lint.gd
##
## Written before the loader on purpose -- the loader will use the same parse
## and the same rules, so a vault that lints here is a vault that will load.

const DIR := "res://assets/vaults/"

const TERRAIN := {
	"#": "wall", ".": "floor", "_": "cave floor", "+": "closed door",
	"'": "open door", "O": "pillar", "^": "stalagmite", "~": "water",
	"=": "mud", "%": "rubble", ",": "bones", "*": "fungus", "&": "brazier",
	"A": "shrine", "X": "pit", "t": "trap", ">": "stairs down", "<": "stairs up",
}
const CONTENTS := {"m": "monster", "M": "guardian", "?": "item", "!": "potion",
	")": "weapon", "[": "armour", "}": "launcher"}
## Cells an actor can occupy. Doors count -- they open. Shrines too: they are
## stood upon, not bumped into. Braziers and pillars are NOT.
const PASSABLE := [".", "_", "+", "'", "~", "=", "%", ",", "*", "A", "X", "t",
	">", "<", "m", "M", "?", "!", ")", "[", "}"]

var _problems := 0
var _warnings := 0

func _initialize() -> void:
	print("")
	var d := DirAccess.open(DIR)
	if d == null:
		print("  cannot open %s" % DIR)
		quit(1)
		return
	var names := []
	for f in d.get_files():
		if f.ends_with(".txt"):
			names.append(f)
	names.sort()
	for n in names:
		_lint(DIR + n, n)
	print("")
	print("  %d problems, %d warnings across %d vaults"
		% [_problems, _warnings, names.size()])
	quit(1 if _problems > 0 else 0)

func fail(vault: String, msg: String) -> void:
	_problems += 1
	print("  PROBLEM  %-24s %s" % [vault, msg])

func warn(vault: String, msg: String) -> void:
	_warnings += 1
	print("  warn     %-24s %s" % [vault, msg])

func _lint(path: String, vault: String) -> void:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		fail(vault, "cannot be read")
		return
	var lines := f.get_as_text().split("\n")
	f.close()

	var meta := {}
	var grid := []
	var in_layout := false
	for raw in lines:
		var line := String(raw).trim_suffix("\r")
		if not in_layout:
			if line.strip_edges() == "LAYOUT":
				in_layout = true
			elif line.strip_edges() != "" and not line.begins_with("#"):
				var bits := line.split(":", true, 1)
				if bits.size() == 2:
					meta[bits[0].strip_edges()] = bits[1].strip_edges()
			continue
		grid.append(line)

	if not in_layout:
		fail(vault, "has no LAYOUT line")
		return

	# Blank lines top and bottom are harmless but shift the bounding box, so
	# the loader will trim them. Say so rather than silently differing.
	while not grid.is_empty() and grid[0].strip_edges() == "":
		grid.remove_at(0)
		warn(vault, "leading blank line after LAYOUT (will be trimmed)")
	while not grid.is_empty() and grid[-1].strip_edges() == "":
		grid.remove_at(grid.size() - 1)

	if grid.is_empty():
		fail(vault, "has an empty layout")
		return

	for key in ["name", "weight", "min_depth", "max_depth"]:
		if not meta.has(key):
			warn(vault, "no '%s' in the metadata" % key)
	var terrain_mode: String = meta.get("terrain", "fixed")
	if terrain_mode != "fixed" and terrain_mode != "random":
		fail(vault, "terrain must be 'fixed' or 'random', not '%s'" % terrain_mode)

	var h := grid.size()
	var w := 0
	for row in grid:
		w = maxi(w, String(row).length())
	if w > 16 or h > 16:
		warn(vault, "%dx%d is large; the generator reserves the whole box" % [w, h])

	# Unknown glyphs.
	var passable_cells := []
	for y in h:
		var row := String(grid[y])
		for x in w:
			var ch := " " if x >= row.length() else row[x]
			if ch == " ":
				continue
			if not TERRAIN.has(ch) and not CONTENTS.has(ch):
				fail(vault, "unknown character '%s' at row %d col %d" % [ch, y, x])
				continue
			if PASSABLE.has(ch):
				passable_cells.append(Vector2i(x, y))

	if passable_cells.is_empty():
		fail(vault, "has nowhere to stand")
		return

	# Everything inside must reach everything else inside.
	var open := {}
	for c in passable_cells:
		open[c] = true
	var seen := {passable_cells[0]: true}
	var stack := [passable_cells[0]]
	while not stack.is_empty():
		var cur: Vector2i = stack.pop_back()
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				var n := cur + Vector2i(dx, dy)
				if open.has(n) and not seen.has(n):
					seen[n] = true
					stack.append(n)
	if seen.size() != passable_cells.size():
		var stranded := []
		for c in passable_cells:
			if not seen.has(c):
				stranded.append("row %d col %d" % [c.y, c.x])
		fail(vault, "is not internally connected: %s unreachable from the rest"
			% ", ".join(stranded))

	# A door has to lead somewhere on both counts, or it is decoration.
	var doors := 0
	var outside := 0
	for y in h:
		var row := String(grid[y])
		for x in w:
			var ch := " " if x >= row.length() else row[x]
			if ch != "+" and ch != "'":
				continue
			doors += 1
			var inside_touch := 0
			var outside_touch := 0
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0),
					Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = Vector2i(x, y) + d
				if open.has(n):
					inside_touch += 1
				elif n.x < 0 or n.y < 0 or n.x >= w or n.y >= h:
					outside_touch += 1
				else:
					var nrow := String(grid[n.y])
					var nch := " " if n.x >= nrow.length() else nrow[n.x]
					if nch == " ":
						outside_touch += 1
			if inside_touch == 0:
				fail(vault, "door at row %d col %d opens onto nothing inside" % [y, x])
			if outside_touch > 0:
				outside += 1
	if doors == 0:
		warn(vault, "has no doors; the generator will punch a corridor through a wall")
	elif outside == 0:
		warn(vault, "no door reaches the outside edge; entry will be punched through")

	print("  ok       %-24s %dx%d, %d doors, %d cells, terrain: %s"
		% [vault, w, h, doors, passable_cells.size(), terrain_mode])
