class_name PixelSprites
extends RefCounted

## PIXEL SPRITES (2026-10-09): drawings made in tools/sprite_editor.html, read
## from plain text and shown on the 3D view's cards in place of the icon
## pictures when the player picks the pixel look (`v` in a 3D view, see
## RenderTheme.sprites_enabled, and the art set, RenderTheme.skin). 3D
## ONLY: the classic view is deprecated.
##
## ONE FILE PER LOOK, named by the appearance id the game draws: wolf.txt is
## every wolf, meat.txt every haunch, player.txt you. Anything without a file
## keeps its icon picture, so a half-drawn set is still a whole game. A
## subfolder is only for tidiness, as with the vaults (creatures/, items/).
##
## The format, exactly as the editor writes it:
##   name: wolf
##   size: 24x32
##   color a: #141418
##   color b: #bfa22f
##   variant ally: b #7fd69a
##   PIXELS
##   ........aaaa............
## One letter per colour, a-z then A-Z; "." is see-through. A short row is
## padded with "."; a letter with no colour, or anything that is not a
## letter, is see-through. Unknown header lines are skipped, as the editor
## skips them. A variant line changes some letters' colours.
##
## STATES THE GAME ASKS FOR, by variant name: "ally" (on your side),
## "corrupted", and "magic" (an item you can see is enchanted). A drawing
## without the one it is asked for is TINTED in that state's colour -- its
## commonest colour becomes the state's, the others keep their light and
## dark against it -- so what the picture look says by colour, the pixel
## look never drops because a drawing forgot it.
##
## On the card the drawing is cropped to what is drawn and fitted into the
## same box as the picture (BillboardSizes), keeping its shape; nearest
## filtering keeps the pixels square. Templates are drawn at TEXELS_PER_CELL,
## so a set made from them shares one pixel size on screen.
##
## ART SETS (2026-10-10). The folders above are the ORIGINAL set: map cards in
## DIR, and in PORTRAITS the bestiary's larger pictures of the same designs.
## Every other set is a folder under SKINS -- `assets/skins/<id>/` -- with a
## `skin.txt` (its `name:`, and `cards: portraits` when its portraits double
## as its creatures' map cards) and any of `creatures/`, `items/`,
## `features/`, `portraits/`. A set holds only what it changes: every look it
## lacks FALLS BACK to the original, so a half-made set is a whole game.
## Chosen with `v` in a 3D view or the title's "art" row (RenderTheme).
##   cards:     the set's own card folders, over its portraits (if `cards:
##              portraits`), over the original's portraits (likewise), over
##              the original's cards
##   portraits: the set's portraits, over the original's, else the card

const DIR := "res://assets/sprites/"
const PORTRAITS := "res://assets/portraits/"
const SKINS := "res://assets/skins/"
const ORIGINAL := &"original"
## A set's card folders, scanned one by one: never its root, whose
## portraits/ would otherwise be read as cards.
const CARD_FOLDERS := ["creatures/", "items/", "features/"]
const LETTERS := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
const CLEAR := "."
## The editor's limit on a side; a bigger size in a file is cut to it.
const MAX_SIDE := 64
## Pixels per map cell for a template: the player's box (0.60 x 0.85 cells)
## comes to the editor's 24x32 canvas with the outline's margin.
const TEXELS_PER_CELL := 32
const MARGIN := 4
## The variant names the game asks for -- see the header.
const ALLY := "ally"
const CORRUPTED := "corrupted"
const MAGIC := "magic"
## A colour darker than this is an outline, never a drawing's main colour.
const OUTLINE_LUMA := 0.15
## How far the frame round a marked creature reaches out, in pixels.
const RIM := 2

## appearance id -> res:// path of its map card, for the set in use, found
## once (see _index); and the same for bestiary portraits.
static var _paths := {}
static var _portraits := {}
static var _indexed := false
## The art set in use -- see use_skin.
static var _skin: StringName = ORIGINAL
## res:// path -> parsed sprite ({} for a file that did not parse). By path,
## not look: a creature's card and its portrait are two files.
static var _parsed := {}
## Images and textures by what they are of -- see _key.
static var _images := {}
static var _textures := {}

# ------------------------------------------------------------------ reading --

## A sprite file's text as {name, w, h, colours, variants, rows}, or {} when
## it is not one (no PIXELS line, or no size). `colours` maps a letter to a
## Color, `variants` a name to such a map, `rows` holds exactly h strings of
## exactly w characters, each a letter or CLEAR.
static func parse(text: String) -> Dictionary:
	var lines := text.replace("\r", "").split("\n")
	var name := ""
	var w := 0
	var h := 0
	var colours := {}
	var variants := {}
	var at := -1
	for i in lines.size():
		var line := lines[i].strip_edges()
		if line == "PIXELS":
			at = i + 1
			break
		if line.begins_with("name:"):
			name = line.substr(5).strip_edges()
		elif line.begins_with("size:"):
			var dims := line.substr(5).replace(" ", "").split("x")
			if dims.size() == 2 and dims[0].is_valid_int() and dims[1].is_valid_int():
				w = dims[0].to_int()
				h = dims[1].to_int()
		elif line.begins_with("color "):
			var parts := line.substr(6).split(":", true, 1)
			var letter := parts[0].strip_edges()
			if parts.size() == 2 and _is_letter(letter):
				var c := _colour(parts[1])
				if c.a > 0.0:
					colours[letter] = c
		elif line.begins_with("variant "):
			var head := line.substr(8).split(":", true, 1)
			if head.size() < 2 or head[0].strip_edges().is_empty():
				continue
			var changes := {}
			for part in head[1].split(","):
				var bits := part.strip_edges().split(" ", false)
				if bits.size() == 2 and _is_letter(bits[0]):
					var vc := _colour(bits[1])
					if vc.a > 0.0:
						changes[bits[0]] = vc
			variants[head[0].strip_edges()] = changes
	if at < 0 or w <= 0 or h <= 0:
		return {}
	w = mini(w, MAX_SIDE)
	h = mini(h, MAX_SIDE)
	var rows := PackedStringArray()
	for y in h:
		var raw := lines[at + y] if at + y < lines.size() else ""
		var row := ""
		for x in w:
			var ch := raw[x] if x < raw.length() else CLEAR
			row += ch if _is_letter(ch) else CLEAR
		rows.append(row)
	return {"name": name, "w": w, "h": h, "colours": colours,
		"variants": variants, "rows": rows}

static func _is_letter(s: String) -> bool:
	return s.length() == 1 and LETTERS.contains(s)

## "#rrggbb" as a Color, or transparent if it is not one.
static func _colour(s: String) -> Color:
	s = s.strip_edges()
	if s.length() != 7 or not s.begins_with("#") or not s.substr(1).is_valid_hex_number():
		return Color(0, 0, 0, 0)
	return Color(s)

# ------------------------------------------------------------------- images --

## The drawing as an Image, in `variant`'s colours ("" for its own), cropped
## to what is drawn. null if nothing is.
static func image(sprite: Dictionary, variant := "") -> Image:
	if sprite.is_empty():
		return null
	var w: int = sprite["w"]
	var h: int = sprite["h"]
	var palette: Dictionary = (sprite["colours"] as Dictionary).duplicate()
	var changes: Dictionary = (sprite["variants"] as Dictionary).get(variant, {})
	for letter in changes:
		palette[letter] = changes[letter]
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rows: PackedStringArray = sprite["rows"]
	for y in h:
		var row := rows[y]
		for x in w:
			var c: Color = palette.get(row[x], Color(0, 0, 0, 0))
			if c.a > 0.0:
				img.set_pixel(x, y, c)
	var used := img.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return null
	return img.get_region(used)

## The image recoloured in `tint`: its commonest colour that is not an
## outline becomes `tint`, and every other colour keeps its brightness
## against that one -- outlines stay dark, highlights light.
static func tinted(img: Image, tint: Color) -> Image:
	var counts := {}
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a > 0.5:
				var k := c.to_rgba32()
				counts[k] = int(counts.get(k, 0)) + 1
	var main_luma := 0.0
	var best := -1
	for k in counts:
		var luma := Color.hex(k).get_luminance()
		if luma > OUTLINE_LUMA and int(counts[k]) > best:
			best = counts[k]
			main_luma = luma
	if best < 0:
		# All outline: take the brightest there is.
		for k in counts:
			main_luma = maxf(main_luma, Color.hex(k).get_luminance())
	main_luma = maxf(main_luma, 0.05)
	var out := Image.create_empty(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var s := c.get_luminance() / main_luma
			out.set_pixel(x, y, Color(tint.r * s, tint.g * s, tint.b * s, c.a).clamp())
	return out

## The shape of the image for a card's hidden part (DioramaView.
## _add_silhouette): `body` inside, `edge` on its outermost pixels.
static func silhouette(img: Image, body: Color, edge: Color) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var out := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a <= 0.0:
				continue
			var at_edge := false
			for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n := Vector2i(x, y) + d
				if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h or img.get_pixel(n.x, n.y).a <= 0.0:
					at_edge = true
					break
			out.set_pixel(x, y, edge if at_edge else body)
	return out

## A frame RIM pixels wide round the image, in white for the card to colour:
## the mark a creature wears (CreatureMarks.single_outline), which the
## picture look draws as the glyph's outline. RIM larger each way than the
## image, so a card with the same pixel size and offset puts it in place.
## OUTSIDE only: a hole the drawing closes round -- a skull's eyes, the
## player's hollow figure -- is not framed, since the frame card is drawn
## behind the drawing and would show through it.
static func rim(img: Image) -> Image:
	var w := img.get_width() + RIM * 2
	var h := img.get_height() + RIM * 2
	# What is outside: everything see-through reachable from the edge of the
	# padded canvas, whose border is always clear.
	var outside := PackedByteArray()
	outside.resize(w * h)
	var queue := PackedInt32Array([0])
	outside[0] = 1
	var head := 0
	while head < queue.size():
		var i := queue[head]
		head += 1
		var x := i % w
		var y := i / w
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx := x + d.x
			var ny := y + d.y
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var n := ny * w + nx
			if outside[n] == 0 and not _solid(img, nx - RIM, ny - RIM):
				outside[n] = 1
				queue.append(n)
	var out := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	for y in h:
		for x in w:
			if outside[y * w + x] == 0:
				continue
			var near := false
			for dy in range(-RIM, RIM + 1):
				for dx in range(-RIM, RIM + 1):
					if _solid(img, x - RIM + dx, y - RIM + dy):
						near = true
						break
				if near:
					break
			if near:
				out.set_pixel(x, y, Color.WHITE)
	return out

static func _solid(img: Image, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() \
		and img.get_pixel(x, y).a > 0.0

# ----------------------------------------------------------- the game's set --

## Is there a drawing for this look?
static func has(id: StringName) -> bool:
	return not sprite(id).is_empty()

## The parsed drawing for a look's map card, {} if it has none or its file is
## broken.
static func sprite(id: StringName) -> Dictionary:
	_index()
	return _load(_paths[id]) if _paths.has(id) else {}

## The parsed bestiary portrait for a creature: the set's, else the
## original's, else its map card. {} when it has none of them.
static func portrait(id: StringName) -> Dictionary:
	_index()
	if _portraits.has(id):
		var p := _load(_portraits[id])
		if not p.is_empty():
			return p
	return sprite(id)

## The file a creature's portrait comes from, "" for none -- for the suite.
static func portrait_path(id: StringName) -> String:
	_index()
	return String(_portraits.get(id, _paths.get(id, "")))

static func _load(path: String) -> Dictionary:
	if not _parsed.has(path):
		var f := FileAccess.open(path, FileAccess.READ)
		var parsed := {}
		if f != null:
			parsed = parse(f.get_as_text())
			f.close()
		if parsed.is_empty() or image(parsed) == null:
			push_warning("PixelSprites: %s is not a drawing; the picture stays" % path)
			parsed = {}
		_parsed[path] = parsed
	return _parsed[path]

## The image a card shows for `id` in `state` ("" for its own colours, or
## ALLY / CORRUPTED / MAGIC): the drawing's variant of that name if it has
## one, else the drawing tinted `tint`. A transparent `tint` with no variant
## gives the drawing as it is. null when `id` has no drawing.
static func image_for(id: StringName, state := "", tint := Color(0, 0, 0, 0)) -> Image:
	var s := sprite(id)
	if s.is_empty():
		return null
	var drawn := state != "" and (s["variants"] as Dictionary).has(state)
	var key := _key(id, "image", state if drawn else "", Color(0, 0, 0, 0) if drawn else tint)
	if not _images.has(key):
		var img := image(s, state if drawn else "")
		if not drawn and tint.a > 0.0:
			img = tinted(img, tint)
		_images[key] = img
	return _images[key]

## image_for as a texture for a card -- built once and kept.
static func texture(id: StringName, state := "", tint := Color(0, 0, 0, 0)) -> Texture2D:
	var img := image_for(id, state, tint)
	if img == null:
		return null
	return _texture_of(_key(id, "tex", state, tint), img)

static func silhouette_texture(id: StringName, body: Color, edge: Color) -> Texture2D:
	var img := image_for(id)
	if img == null:
		return null
	var key := _key(id, "shape", body.to_html(), edge)
	if not _textures.has(key):
		_textures[key] = ImageTexture.create_from_image(silhouette(img, body, edge))
	return _textures[key]

static func rim_texture(id: StringName) -> Texture2D:
	var img := image_for(id)
	if img == null:
		return null
	var key := _key(id, "rim", "", Color(0, 0, 0, 0))
	if not _textures.has(key):
		_textures[key] = ImageTexture.create_from_image(rim(img))
	return _textures[key]

static func _texture_of(key: String, img: Image) -> Texture2D:
	if not _textures.has(key):
		_textures[key] = ImageTexture.create_from_image(img)
	return _textures[key]

static func _key(id: StringName, kind: String, state: String, tint: Color) -> String:
	return "%s|%s|%s|%s" % [id, kind, state, tint.to_html() if tint.a > 0.0 else ""]

## The canvas a template for `id` is drawn on: its card's box at
## TEXELS_PER_CELL, with MARGIN for the outline. Read by the sprite editor
## (tools/dump_bestiary.gd) so a set made from templates shares one pixel size.
static func canvas_for(box: Vector2) -> Vector2i:
	return Vector2i(ceili(box.x * TEXELS_PER_CELL) + MARGIN,
		ceili(box.y * TEXELS_PER_CELL) + MARGIN).min(Vector2i(MAX_SIDE, MAX_SIDE))

## Which looks have a map card in the set in use, id -> path.
static func paths() -> Dictionary:
	_index()
	return _paths

## Forget everything read, so the next card reads the folders afresh: the
## look's key calls this, so a sprite saved from the editor shows on the
## next press, without restarting the game. The set in use is kept.
static func reload() -> void:
	_paths.clear()
	_portraits.clear()
	_parsed.clear()
	_images.clear()
	_textures.clear()
	_indexed = false

# ------------------------------------------------------------- the art sets --

## Every art set: ORIGINAL first, then each folder under SKINS that has a
## skin.txt, in name order.
static func skins() -> Array[StringName]:
	var out: Array[StringName] = [ORIGINAL]
	var names := DirAccess.get_directories_at(SKINS)
	names.sort()
	for n in names:
		if FileAccess.file_exists(SKINS + n + "/skin.txt"):
			out.append(StringName(n))
	return out

static func skin() -> StringName:
	return _skin

## Shows `id` from now on; a set that is not there is the original, so a
## settings file naming a removed set still loads. Reads the folders afresh
## when the set changes.
static func use_skin(id: StringName) -> void:
	if not skins().has(id):
		id = ORIGINAL
	if id != _skin:
		_skin = id
		reload()

## A set's own name, from its skin.txt (the folder's name if it has none).
static func skin_name(id: StringName) -> String:
	if id == ORIGINAL:
		return "Original"
	return String(_skin_cfg(id).get("name", String(id).capitalize()))

## A set's skin.txt as {"name", "cards"} -- `key: value` lines, `#` comments.
static func _skin_cfg(id: StringName) -> Dictionary:
	var out := {}
	var f := FileAccess.open(SKINS + String(id) + "/skin.txt", FileAccess.READ)
	if f == null:
		return out
	for line in f.get_as_text().replace("\r", "").split("\n"):
		line = line.strip_edges()
		if line.begins_with("#") or not line.contains(":"):
			continue
		var kv := line.split(":", true, 1)
		out[kv[0].strip_edges()] = kv[1].strip_edges()
	f.close()
	return out

static func _index() -> void:
	if _indexed:
		return
	_indexed = true
	_paths = _scan(DIR)
	_portraits = _scan(PORTRAITS)
	if _skin == ORIGINAL:
		return
	var root := SKINS + String(_skin) + "/"
	var own_portraits := _scan(root + "portraits/")
	if _skin_cfg(_skin).get("cards", "") == "portraits":
		_paths.merge(_portraits, true)
		_paths.merge(own_portraits, true)
	for folder: String in CARD_FOLDERS:
		_paths.merge(_scan(root + folder), true)
	_portraits.merge(own_portraits, true)

## Every .txt under `dir_path`, subfolders too, as id -> path. A look drawn
## twice keeps the first found (folders sorted) and says so.
static func _scan(dir_path: String) -> Dictionary:
	var found := {}
	_scan_into(dir_path, found)
	return found

static func _scan_into(dir_path: String, into: Dictionary) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	var names := d.get_files()
	names.sort()
	for file_name in names:
		if not file_name.ends_with(".txt") or file_name == "skin.txt":
			continue
		var id := StringName(file_name.trim_suffix(".txt"))
		if into.has(id):
			push_warning("PixelSprites: %s is drawn twice; %s is used" % [id, into[id]])
			continue
		into[id] = dir_path + file_name
	var subs := d.get_directories()
	subs.sort()
	for sub in subs:
		_scan_into(dir_path + sub + "/", into)
