class_name Vault
extends RefCounted

## A hand-authored room, read from assets/vaults/*.txt.
##
## The parse here is deliberately the same one `tests/vault_lint.gd` uses, so a
## vault that lints is a vault that loads. If the two ever disagree, the linter
## is the one telling the truth to the author and this is the one that has to
## change.

## Source character -> tile. Everything else on a layout line is either a
## content marker or empty space.
const TERRAIN := {
	"#": Tiles.WALL, ".": Tiles.FLOOR, "_": Tiles.CAVE_FLOOR,
	"+": Tiles.DOOR_CLOSED, "'": Tiles.DOOR_OPEN, "O": Tiles.PILLAR,
	"^": Tiles.STALAGMITE, "~": Tiles.WATER, "=": Tiles.MUD,
	"%": Tiles.RUBBLE, ",": Tiles.BONES, "*": Tiles.FUNGUS,
	"&": Tiles.BRAZIER, "A": Tiles.SHRINE, "X": Tiles.PIT, "t": Tiles.TRAP,
	">": Tiles.STAIRS_DOWN, "<": Tiles.STAIRS_UP,
}
## Content markers stand on plain floor; the floor is laid first, then these.
const CONTENTS := ["m", "M", "?", "!", ")", "[", "}"]

var name := "vault"
var weight := 8
var min_depth := 1
var max_depth := 99
var may_rotate := true
var fixed_terrain := true
var rows: Array[String] = []

func size() -> Vector2i:
	var w := 0
	for r in rows:
		w = maxi(w, r.length())
	return Vector2i(w, rows.size())

func glyph_at(x: int, y: int) -> String:
	if y < 0 or y >= rows.size():
		return " "
	var row := rows[y]
	return " " if x < 0 or x >= row.length() else row[x]

# ------------------------------------------------------------------ parsing --

static func parse(text: String, source: String) -> Vault:
	var v := Vault.new()
	v.name = source
	var in_layout := false
	var body: Array[String] = []

	for raw in text.split("\n"):
		var line := String(raw).trim_suffix("\r")
		if not in_layout:
			if line.strip_edges() == "LAYOUT":
				in_layout = true
			elif line.strip_edges() != "" and not line.begins_with("#"):
				var bits := line.split(":", true, 1)
				if bits.size() == 2:
					v._set_meta(bits[0].strip_edges(), bits[1].strip_edges())
			continue
		body.append(line)

	if not in_layout:
		return null
	# Blank lines top and bottom would shift the bounding box for nothing.
	while not body.is_empty() and body[0].strip_edges() == "":
		body.remove_at(0)
	while not body.is_empty() and body[-1].strip_edges() == "":
		body.remove_at(body.size() - 1)
	if body.is_empty():
		return null

	v.rows = body
	return v

func _set_meta(key: String, value: String) -> void:
	match key:
		"name": name = value
		"weight": weight = maxi(0, value.to_int())
		"min_depth": min_depth = value.to_int()
		"max_depth": max_depth = value.to_int()
		"rotate": may_rotate = value.to_lower() != "no"
		"terrain": fixed_terrain = value.to_lower() != "random"

static func load_all(dir_path: String = "res://assets/vaults/") -> Array[Vault]:
	var out: Array[Vault] = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	var names := d.get_files()
	names.sort()
	for file_name in names:
		if not file_name.ends_with(".txt"):
			continue
		var f := FileAccess.open(dir_path + file_name, FileAccess.READ)
		if f == null:
			continue
		var v := parse(f.get_as_text(), file_name.trim_suffix(".txt"))
		f.close()
		if v != null:
			out.append(v)
	return out

# ----------------------------------------------------------------- rotating --

## Returns the layout turned `quarters` x 90 degrees clockwise, optionally
## mirrored first. Symmetric shapes -- diamonds, octagons, circles -- get free
## variety from this: the shape is unchanged but the doors land somewhere new.
func oriented(quarters: int, mirror: bool) -> Array[String]:
	var sz := size()
	var grid: Array[String] = []
	for y in sz.y:
		var row := ""
		for x in sz.x:
			row += glyph_at(sz.x - 1 - x, y) if mirror else glyph_at(x, y)
		grid.append(row)

	for _turn in posmod(quarters, 4):
		var h := grid.size()
		var w := 0
		for r in grid:
			w = maxi(w, r.length())
		var turned: Array[String] = []
		for x in w:
			var row := ""
			for y in range(h - 1, -1, -1):
				var src := grid[y]
				row += " " if x >= src.length() else src[x]
			turned.append(row)
		grid = turned
	return grid
