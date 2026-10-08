extends SceneTree

## Checks every vault in assets/vaults/ for the mistakes that are easy to make
## and hard to see:
##   godot --headless --script res://tests/vault_lint.gd
## Or another folder (tools/vaults_waiting/, a scratch folder):
##   godot --headless --script res://tests/vault_lint.gd -- <folder>/
##
## Written before the loader on purpose -- the loader will use the same parse
## and the same rules, so a vault that lints here is a vault that will load.

const DIR := "res://assets/vaults/"

const TERRAIN := {
	"#": "wall", ".": "floor", "_": "cave floor", "+": "closed door",
	"'": "open door", "O": "pillar", "^": "stalagmite", "~": "water",
	"=": "mud", "%": "rubble", ",": "bones", "*": "fungus",
	"v": "purple fungus", ";": "red fungus", "&": "brazier",
	"A": "shrine", "X": "pit", "t": "trap", ">": "stairs down", "<": "stairs up",
	"n": "grave", "C": "chest",
}
const CONTENTS := {"m": "monster", "M": "guardian", "?": "item", "!": "potion",
	")": "weapon", "[": "armour", "}": "launcher", "(": "sack", "r": "rabbit"}
## Cells an actor can occupy. Doors count -- they open. Shrines too: they are
## stood upon, not bumped into. Braziers and pillars are NOT.
##
## `n` is here because a grave is the one standing feature you can walk onto;
## tiles.gd says so explicitly, and the reason is that a headstone which
## blocked movement would be one more thing generation has to prove it never
## wedged into a corridor.
const PASSABLE := [".", "_", "+", "'", "~", "=", "%", ",", "*", "v", ";",
	"A", "X", "t", ">", "<", "n", "m", "M", "?", "!", ")", "[", "}", "(", "r"]
## Creatures by name: a digit on the board, named by a `place N: name` line.
const NAMED := ["1", "2", "3", "4", "5", "6", "7", "8", "9"]
## A cave vault (`kind: cave`) is painted in place of a grown cave, and the
## game drops a grown cave under this many open cells (mapgen _carve_caves).
const CAVE_MIN_CELLS := 24

var _problems := 0
var _warnings := 0

func _initialize() -> void:
	print("")
	var dir := DIR
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		dir = String(args[0]).trim_suffix("/") + "/"
	var d := DirAccess.open(dir)
	if d == null:
		print("  cannot open %s" % dir)
		quit(1)
		return
	# The folder and its subfolders (assets/vaults/caves/, 2026-10-08), as
	# Vault.load_all reads them.
	var names := _vault_files(dir, "")
	for n in names:
		_lint(dir + n, n)
	print("")
	print("  %d problems, %d warnings across %d vaults"
		% [_problems, _warnings, names.size()])
	quit(1 if _problems > 0 else 0)

## Every .txt under `dir`, as paths relative to it ("caves/x.txt").
func _vault_files(dir: String, prefix: String) -> Array:
	var out := []
	var d := DirAccess.open(dir + prefix)
	if d == null:
		return out
	var files := Array(d.get_files())
	files.sort()
	for f in files:
		if String(f).ends_with(".txt"):
			out.append(prefix + String(f))
	var subs := Array(d.get_directories())
	subs.sort()
	for sub in subs:
		out.append_array(_vault_files(dir, prefix + String(sub) + "/"))
	return out

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

	# Creatures by name (2026-10-08): every place line names a real
	# creature; a monster above the room ceiling where the vault starts would
	# be left out there (an animal comes on top of the budget).
	var places := {}
	for key in meta:
		if not String(key).begins_with("place "):
			continue
		var digit := String(key).substr(6).strip_edges()
		var called := String(meta[key])
		if not NAMED.has(digit):
			fail(vault, "'%s' must be 'place' and one digit, 1-9" % key)
			continue
		var row := {}
		for e in GameState.BESTIARY:
			if String(e["name"]) == called:
				row = e
		if row.is_empty():
			fail(vault, "place %s: '%s' is not a creature in the bestiary" % [digit, called])
			continue
		places[digit] = called
		var lowest := int(meta.get("min_depth", "1"))
		if not row.get("wild", false) and int(row["threat"]) > Threat.room_ceiling(lowest):
			warn(vault, "place %s: a %s (threat %d) is over the room ceiling (%d) at depth %d, so it is left out there"
				% [digit, called, int(row["threat"]), Threat.room_ceiling(lowest), lowest])

	for key in ["name", "weight", "min_depth", "max_depth"]:
		if not meta.has(key):
			warn(vault, "no '%s' in the metadata" % key)
	var terrain_mode: String = meta.get("terrain", "fixed")
	if terrain_mode != "fixed" and terrain_mode != "random":
		fail(vault, "terrain must be 'fixed' or 'random', not '%s'" % terrain_mode)

	var kind: String = String(meta.get("kind", "room")).to_lower()
	if kind != "room" and kind != "cave":
		fail(vault, "kind must be 'room' or 'cave', not '%s'" % kind)
	var cave := kind == "cave"
	if cave and String(meta.get("band", "")).to_lower() != "caves":
		warn(vault, "a cave vault is only placed on cave floors; its band should be 'caves'")

	var h := grid.size()
	var w := 0
	for row in grid:
		w = maxi(w, String(row).length())
	if cave:
		if w > 22 or h > 15:
			warn(vault, "%dx%d is larger than the generator's own caves (22x15)" % [w, h])
	elif w > 16 or h > 16:
		warn(vault, "%dx%d is large; the generator reserves the whole box" % [w, h])

	# Unknown glyphs.
	var passable_cells := []
	for y in h:
		var row := String(grid[y])
		for x in w:
			var ch := " " if x >= row.length() else row[x]
			if ch == " ":
				continue
			if NAMED.has(ch):
				if not places.has(ch):
					fail(vault, "'%s' at row %d col %d has no 'place %s:' line" % [ch, y, x, ch])
				passable_cells.append(Vector2i(x, y))
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

	if cave:
		# No doors: the cave connector tunnels in, as into a grown cave.
		if passable_cells.size() < CAVE_MIN_CELLS:
			fail(vault, "a cave vault needs %d open cells; it has %d"
				% [CAVE_MIN_CELLS, passable_cells.size()])
		for c in passable_cells:
			var ch := String(grid[c.y])[c.x]
			if ch == "+" or ch == "'":
				warn(vault, "a cave vault has no doors; the one at row %d col %d is a door in a cave" % [c.y, c.x])
		print("  ok       %-24s %dx%d, cave, %d cells, terrain: %s"
			% [vault, w, h, passable_cells.size(), terrain_mode])
		return

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
