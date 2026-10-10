class_name BestiaryPanel
extends Control

## THE BESTIARY (2026-10-10): every creature and every item, as a page of its
## own, between the legend and the map. The three are one reference in a
## RING -- left and right turn the page, and from any page the other two are
## one press away (Brad: the map is read most, the legend least; a ring makes
## the order not matter).
##
## Two tabs: CREATURES (you and yours, then the wild animals, then the
## monsters) and ITEMS (the catalogue). Each entry is its PORTRAIT from the
## art set in use (PixelSprites.portrait; an item, its card), its tags, what
## it does, and its numbers.
##
## WHAT YOU HAVE NOT MET IS "???": no picture, no shape, no words. The legend's
## old rule, kept: a reference that answers questions you have not asked yet
## is a spoiler wearing a helpful face. A silhouette is still an answer -- a
## dragon-shaped shadow tells a floor-one player there is a dragon. Creatures
## are known from BestiaryLog, items once seen lying or carried
## (BestiaryLog.note_item, from GameState.update_vision). The player and the
## trader are always known, as in the legend.

signal legend_requested()
signal map_requested()

@export var font: Font
@export var font_bold: Font

var state: GameState
var pad_input := false

const CREATURES := &"creatures"
const ITEMS := &"items"
const TABS: Array[StringName] = [CREATURES, ITEMS]
var tab: StringName = CREATURES
## The highlighted entry, per tab.
var _pick := {CREATURES: 0, ITEMS: 0}
var _hover := -1

const MARGIN := 24.0
const PAD := 36.0
const HEAD := 104.0
const GAP := 8.0
## Columns and tile size per tab: 28 creatures fill 7 x 4 exactly, with room
## for a name under each; items are smaller and unnamed (the panel names them).
const COLS := {CREATURES: 7, ITEMS: 8}
const TILE := {CREATURES: 128.0, ITEMS: 92.0}
const LABEL_H := {CREATURES: 22.0, ITEMS: 0.0}
const PORTRAIT := 6

## Textures, by art set and what they are of.
var _tex := {}
var _tex_skin := &""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visible = false
	if font == null:
		font = load("res://assets/fonts/JetBrainsMono-Regular.ttf")
	if font_bold == null:
		font_bold = load("res://assets/fonts/JetBrainsMono-Bold.ttf")

## Opens on `select` -- a creature's look or an item's id -- when given.
func open(select: StringName = &"") -> void:
	visible = true
	_hover = -1
	if select != &"":
		for t in TABS:
			var list := entries(t)
			for i in list.size():
				if list[i]["id"] == select:
					tab = t
					_pick[t] = i
	queue_redraw()

func close() -> void:
	visible = false

# ---------------------------------------------------------------- entries ---

## The tab's entries in order: {"id", "app", "name", "group", "row", "known"}.
func entries(which: StringName = tab) -> Array:
	return creature_entries() if which == CREATURES else item_entries()

static func creature_entries() -> Array:
	var out: Array = [
		{"id": &"player", "app": &"player", "name": "you", "group": &"you", "row": {}, "known": true},
		{"id": &"trader", "app": &"trader", "name": "the trader", "group": &"trader", "row": {}, "known": true},
		{"id": &"bone_ally", "app": &"bone_ally", "name": "your risen bones", "group": &"ally", "row": {},
			"known": BestiaryLog.knows(&"bone_ally")},
	]
	for wild in [true, false]:
		for e in GameState.BESTIARY:
			if bool(e.get("wild", false)) != wild:
				continue
			var app: StringName = e["app"]
			out.append({"id": app, "app": app, "name": String(e["name"]),
				"group": &"wild" if wild else &"monster", "row": e, "known": BestiaryLog.knows(app)})
	out.append({"id": &"killer_rabbit", "app": &"killer_rabbit", "name": "killer rabbit",
		"group": &"monster", "row": {}, "known": BestiaryLog.knows(&"killer_rabbit")})
	return out

static func item_entries() -> Array:
	var out: Array = []
	for id in Item.CATALOGUE:
		var data: Dictionary = Item.CATALOGUE[id]
		out.append({"id": StringName(id), "app": StringName(data.get("app", id)),
			"name": String(data.get("name", id)), "group": &"item", "row": data,
			"known": BestiaryLog.knows_item(StringName(id))})
	return out

## How many of a tab's entries are known.
static func known_count(list: Array) -> int:
	var n := 0
	for e in list:
		if bool(e["known"]):
			n += 1
	return n

# ------------------------------------------------------------------ words ---

## What the panel says about an entry: {"title", "tags", "lines", "stats"}.
## `stats` is [[label, value], ...]. Unknown: "???" and nothing else.
func describe(e: Dictionary) -> Dictionary:
	if not bool(e["known"]):
		return {"title": "???", "tags": "",
			"lines": ["Not found yet." if e["group"] == &"item" else "Not met yet."], "stats": []}
	if e["group"] == &"item":
		return _describe_item(e)
	return _describe_creature(e)

func _describe_creature(e: Dictionary) -> Dictionary:
	var row: Dictionary = e["row"]
	var lines: Array = []
	var stats: Array = []
	var tags := ""
	match e["group"]:
		&"you":
			tags = "you"
			lines.append("Down to the bottom for the Amulet of the Deep, then all the way back up.")
			if state != null and state.player != null:
				stats = [["level", str(state.player.level)], ["HP", str(state.player.max_hp)],
					["power", str(state.player.power)], ["defense", str(state.player.total_defense())]]
		&"trader":
			tags = "trader  ·  first floor of a band"
			lines.append("Trades for what you carry. Never anyone's enemy -- unless you make one.")
		&"ally":
			tags = "your ally"
			lines.append("A skeleton raised to fight beside you. It cannot be healed.")
		_:
			tags = ("wild animal" if e["group"] == &"wild" else "monster") + "  ·  " + \
				("the climb out" if row.has("ascent_from") else
					("depth %d+" % int(row.get("min_depth", 1)) if not row.is_empty() else "the climb"))
			lines.append_array(traits(row))
			if e["id"] == &"killer_rabbit":
				lines.append("A rabbit that ate what it should not have. It hunts now.")
			if not row.is_empty():
				stats = [["HP", str(int(row["hp"]))], ["power", str(int(row["power"]))],
					["defense", str(int(row["def"]))], ["speed", speed_word(int(row["speed"]))]]
	return {"title": String(e["name"]).to_upper(), "tags": tags, "lines": lines, "stats": stats}

## One short sentence per thing a creature does differently, from its own
## bestiary row -- the facts the legend's one-word notes come from.
static func traits(row: Dictionary) -> Array:
	var out: Array = []
	if bool(row.get("wild", false)):
		out.append("No one's enemy until struck.")
	if bool(row.get("tame", false)):
		out.append("Can be tamed.")
	if int(row.get("range", 1)) > 1:
		out.append("Shoots from a distance.")
	if int(row.get("regen", 0)) > 0:
		out.append("Its wounds close as you watch.")
	if String(row.get("ai", "")) == "forager":
		out.append("Forages, and runs from danger.")
	if bool(row.get("eats", false)):
		out.append("Hunts smaller animals.")
	if bool(row.get("pack", false)):
		out.append("Braver in a pack.")
	if int(row.get("wail", 0)) > 0:
		out.append("Its wail wakes the whole floor.")
	if int(row.get("venom", 0)) > 0:
		out.append("Its bite poisons.")
	if bool(row.get("climbs", false)):
		out.append("Flees up the walls.")
	if bool(row.get("webs", false)):
		out.append("Spits webs that hold you fast. Fire frees you.")
	if bool(row.get("flying", false)):
		out.append("Flies.")
	if bool(row.get("phasing", false)):
		out.append("Passes through walls.")
	if bool(row.get("unliving", false)):
		out.append("Not alive: poison cannot touch it.")
	if bool(row.get("scavenge", false)):
		out.append("Picks up what it finds.")
	for key in ["resists", "weak_to"]:
		var els = row.get(key, [])
		if els is Array and not (els as Array).is_empty():
			var names := PackedStringArray()
			for el in els:
				names.append(String(el))
			out.append(("Shrugs off " if key == "resists" else "Weak to ") + ", ".join(names) + ".")
	return out

static func speed_word(speed: int) -> String:
	if speed > 100:
		return "fast"
	if speed < 100:
		return "slow"
	return "even"

## What an item IS, in words: the catalogue's `kind` is mechanical -- food
## and the sack are potions there, the knucklebone a scroll, the satchel
## armour -- so the word comes from what you do with it, and a few by name.
const KIND_BY_ID := {&"amulet": "the amulet", &"arrows": "ammunition", &"bone": "relic",
	&"shovel": "relic", &"trap_glass": "relic", &"rat_ring": "ring", &"satchel": "satchel",
	&"sack": "sack"}

## The legend's own notes for a look (LegendPanel.ITEM_ROWS), as sentences.
const NOTE_BY_APP := {
	&"gem": "Set it at the embers, or use it in the world.",
	&"shield": "Not with a bow.",
	&"ring": "A rat, until it goes cold; a gem warms it.",
	&"shovel": "Raises your last kill; buries the red's dead.",
}
const DAMAGE_WORD := {&"slash": "It slashes.", &"blunt": "It is blunt.", &"pierce": "It pierces."}

static func kind_word(it: Item) -> String:
	if KIND_BY_ID.has(it.id):
		return KIND_BY_ID[it.id]
	match it.kind:
		Item.Kind.WEAPON:
			return "launcher" if it.uses_ammo() else "weapon"
		Item.Kind.ARMOR:
			return "shield" if it.slot == Item.Slot.OFFHAND else "armour"
		Item.Kind.POTION:
			return "food" if it.verb() == "eat" else "potion"
		Item.Kind.SCROLL:
			return "scroll"
		Item.Kind.GEM:
			return "gem"
	return "thing"

func _describe_item(e: Dictionary) -> Dictionary:
	var data: Dictionary = e["row"]
	var it := Item.make(e["id"])
	var lines: Array = []
	var stats: Array = []
	# Where it turns up: a depth for floor loot; nothing for what only drops
	# (meat, the amulet: their min_depth is the table's "never lying about").
	var tags := kind_word(it)
	if data.has("unique"):
		tags += "  ·  one of a kind"
	elif int(data.get("min_depth", 1)) < 100:
		tags += "  ·  depth %d+" % int(data["min_depth"])
	# What you do with it -- the inventory's own verb -- except for spent
	# arrows, which are filed with scrolls and are not read.
	if it.id != &"arrows":
		var verb := it.verb()
		lines.append("%s it." % (verb.substr(0, 1).to_upper() + verb.substr(1)))
	else:
		lines.append("Arrows that have been shot.")
	if NOTE_BY_APP.has(it.appearance):
		lines.append(NOTE_BY_APP[it.appearance])
	if DAMAGE_WORD.has(data.get("dmg", &"")):
		lines.append(DAMAGE_WORD[data["dmg"]])
	# A potion's healing is fixed; a haunch's is set by the animal it came from.
	if it.verb() == "drink" and data.get("effect", &"") == &"heal":
		lines.append("Heals %d." % int(data.get("magnitude", 0)))
	if it.is_two_handed():
		lines.append("Needs both hands.")
	if it.uses_ammo():
		lines.append("Shoots %ss." % String(data.get("ammo_kind", "shot")))
	if int(data.get("don", 0)) > 1:
		lines.append("Takes %d turns to put on." % int(data["don"]))
	if int(data.get("holds", 0)) > 0:
		lines.append("Holds %d things." % int(data["holds"]))
	if it.power_bonus != 0:
		stats.append(["power", "+%d" % it.power_bonus])
	if it.defense_bonus != 0:
		stats.append(["defense", "+%d" % it.defense_bonus])
	if it.range_bonus > 1:
		stats.append(["reach", str(it.range_bonus)])
	if int(data.get("throw", 0)) > 0:
		stats.append(["thrown", str(int(data["throw"]))])
	return {"title": String(e["name"]).to_upper(), "tags": tags, "lines": lines, "stats": stats}

# ------------------------------------------------------------------- input ---

## Arrows move; past the left edge is the legend, past the right edge the
## map; tab (or the pad's shoulders, via main.gd) changes tab; anything else
## closes, as the legend and the map do.
func handle_key(key: int, back := false) -> bool:
	if not visible:
		return false
	var list := entries()
	var cols: int = COLS[tab]
	var i: int = clampi(int(_pick[tab]), 0, maxi(0, list.size() - 1))
	match key:
		KEY_LEFT:
			if i % cols == 0:
				close()
				legend_requested.emit()
				return true
			i -= 1
		KEY_RIGHT:
			if i % cols == cols - 1 or i == list.size() - 1:
				close()
				map_requested.emit()
				return true
			i += 1
		KEY_UP:
			if i - cols >= 0:
				i -= cols
		KEY_DOWN:
			if i + cols < list.size():
				i += cols
		KEY_TAB:
			tab = TABS[posmod(TABS.find(tab) + (-1 if back else 1), TABS.size())]
			queue_redraw()
			return true
		KEY_PERIOD, KEY_ENTER, KEY_KP_ENTER:
			# Confirm (a pad's A) has nothing to open here -- the page is
			# already showing -- and must not close it under a thumb that
			# pressed it to choose (B closes, as everywhere).
			return true
		_:
			close()
			return true
	_pick[tab] = i
	queue_redraw()
	return true

func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		var at := _tile_at(motion.position)
		if at != _hover:
			_hover = at
			if at >= 0:
				_pick[tab] = at
			queue_redraw()
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	for t in TABS:
		if _tab_rect(t).has_point(click.position):
			tab = t
			queue_redraw()
			return
	# The page-turn buttons, for a mouse: the arrows' edges are a keyboard's.
	if _page_rect(-1).has_point(click.position):
		close()
		legend_requested.emit()
		return
	if _page_rect(1).has_point(click.position):
		close()
		map_requested.emit()
		return
	var hit := _tile_at(click.position)
	if hit >= 0:
		_pick[tab] = hit
		queue_redraw()
		return
	if not _panel().has_point(click.position):
		close()

# ---------------------------------------------------------------- layout ---

func _panel() -> Rect2:
	return Rect2(Vector2(MARGIN, MARGIN), size - Vector2(MARGIN, MARGIN) * 2.0)

func _tile_rect(i: int) -> Rect2:
	var p := _panel()
	var cols: int = COLS[tab]
	var t: float = TILE[tab]
	var h: float = t + float(LABEL_H[tab])
	return Rect2(p.position + Vector2(PAD + (i % cols) * (t + GAP), HEAD + (i / cols) * (h + GAP)),
		Vector2(t, h))

func _tile_at(pos: Vector2) -> int:
	for i in entries().size():
		if _tile_rect(i).has_point(pos):
			return i
	return -1

func _tab_rect(t: StringName) -> Rect2:
	var p := _panel()
	var w := 150.0
	var x := p.end.x - PAD - (TABS.size() - TABS.find(t)) * (w + 12.0) + 12.0
	return Rect2(Vector2(x, p.position.y + PAD - 6.0), Vector2(w, 34.0))

## The page-turn buttons in the header, left of the tabs: -1 the legend, +1
## the map.
func _page_rect(side: int) -> Rect2:
	var first := _tab_rect(TABS[0])
	var w := 130.0
	var x := first.position.x - 24.0 - (w + 12.0) * (2 if side < 0 else 1) + 12.0
	return Rect2(Vector2(x, first.position.y), Vector2(w, first.size.y))

## Where the detail column starts: after the creatures' grid, the wider one.
func _detail_rect() -> Rect2:
	var p := _panel()
	var grid_w: float = COLS[CREATURES] * (TILE[CREATURES] + GAP) - GAP
	var x := p.position.x + PAD + grid_w + 40.0
	return Rect2(Vector2(x, p.position.y + HEAD), Vector2(p.end.x - PAD - x, p.size.y - HEAD - PAD - 30.0))

# --------------------------------------------------------------- drawing ---

## The picture for an entry, from the art set in use: a creature's portrait,
## an item's card. null when there is none (and for anything unknown, which
## is never asked).
func picture(e: Dictionary) -> Texture2D:
	if PixelSprites.skin() != _tex_skin:
		_tex.clear()
		_tex_skin = PixelSprites.skin()
	var key := "%s|%s" % [e["group"], e["id"]]
	if not _tex.has(key):
		var parsed: Dictionary = PixelSprites.sprite(e["app"]) if e["group"] == &"item" \
			else PixelSprites.portrait(e["app"])
		var img := PixelSprites.image(parsed) if not parsed.is_empty() else null
		_tex[key] = ImageTexture.create_from_image(img) if img != null else null
	return _tex[key]

## `tex` as large as fits `box` at a WHOLE number of screen pixels a pixel,
## so the art stays square; centred.
static func fit(tex: Texture2D, box: Rect2) -> Rect2:
	var s := maxf(1.0, floorf(minf(box.size.x / tex.get_width(), box.size.y / tex.get_height())))
	var sz := Vector2(tex.get_width(), tex.get_height()) * s
	return Rect2(box.position + (box.size - sz) * 0.5, sz)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.86), true)
	var p := _panel()
	draw_rect(p, Palette.UI_PANEL_BG, true)
	draw_rect(p, Palette.UI_FRAME, false, 1.0)
	var all_c := creature_entries()
	var all_i := item_entries()
	draw_string(font_bold, p.position + Vector2(PAD, PAD + 22.0), "BESTIARY",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Palette.STAIRS)
	draw_string(font, p.position + Vector2(PAD, PAD + 50.0),
		"creatures %d / %d   ·   items %d / %d" % [known_count(all_c), all_c.size(),
			known_count(all_i), all_i.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Palette.UI_DIM)
	for t in TABS:
		var r := _tab_rect(t)
		var on := t == tab
		draw_rect(r, Color(Palette.STAIRS, 0.10) if on else Color(0, 0, 0, 0), true)
		draw_rect(r, Palette.STAIRS if on else Palette.UI_FRAME, false, 2.0 if on else 1.0)
		draw_string(font, Vector2(r.position.x, r.position.y + 23.0), String(t),
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 15, Palette.STAIRS if on else Palette.UI_DIM)

	for side in [-1, 1]:
		var pr := _page_rect(side)
		draw_rect(pr, Palette.UI_FRAME, false, 1.0)
		draw_string(font, Vector2(pr.position.x, pr.position.y + 23.0),
			"<  legend" if side < 0 else "map  >", HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 15,
			Palette.UI_TEXT)

	var list := all_c if tab == CREATURES else all_i
	var pick: int = clampi(int(_pick[tab]), 0, list.size() - 1)
	for i in list.size():
		var e: Dictionary = list[i]
		var r := _tile_rect(i)
		var art := Rect2(r.position + Vector2(4, 4), Vector2(r.size.x - 8.0, float(TILE[tab]) - 8.0))
		draw_rect(r, Color(1, 1, 1, 0.03), true)
		draw_rect(r, Palette.UI_FRAME, false, 1.0)
		if bool(e["known"]):
			var tex := picture(e)
			if tex != null:
				draw_texture_rect(tex, fit(tex, art), false)
			if float(LABEL_H[tab]) > 0.0:
				draw_string(font, Vector2(r.position.x, r.end.y - 6.0), String(e["name"]),
					HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 13, Palette.UI_TEXT)
		else:
			draw_string(font, Vector2(art.position.x, art.position.y + art.size.y * 0.5 + 6.0), "???",
				HORIZONTAL_ALIGNMENT_CENTER, art.size.x, 18, Palette.UI_DIM)
		if i == pick:
			draw_rect(r.grow(1.0), Palette.STAIRS, false, 3.0)

	_draw_detail(list[pick])
	draw_string(font, Vector2(p.position.x + PAD, p.end.y - 18.0), footer(),
		HORIZONTAL_ALIGNMENT_LEFT, p.size.x - PAD * 2.0, 13, Palette.UI_DIM)

## The hint line, for whatever is in the player's hands.
func footer() -> String:
	if pad_input:
		return "d-pad  move      LB / RB  creatures / items      past the left edge  the legend" + \
			"      past the right edge  the map      B  close"
	return "arrows  move      tab  creatures / items      past the left edge  the legend" + \
		"      past the right edge  the map      click  choose      esc  close"

func _draw_detail(e: Dictionary) -> void:
	var d := _detail_rect()
	draw_rect(d, Color(1, 1, 1, 0.02), true)
	draw_rect(d, Palette.UI_FRAME, false, 1.0)
	var info := describe(e)
	# A creature's portrait at PORTRAIT times its 64; an item's card smaller,
	# or a 16-pixel sword would stand 384 high.
	var side := 64.0 * (PORTRAIT if e["group"] != &"item" else 4)
	var box := Rect2(Vector2(d.position.x + (d.size.x - side) * 0.5, d.position.y + 16.0), Vector2(side, side))
	if bool(e["known"]):
		# A warm glow behind the picture, as the torch lights it.
		var c := box.get_center()
		for k in 10:
			draw_circle(c, side * 0.55 * (1.0 - k * 0.09), Color(0.85, 0.45, 0.15, 0.025))
		var tex := picture(e)
		if tex != null:
			draw_texture_rect(tex, fit(tex, box), false)
	var x := d.position.x + 24.0
	var y := box.end.y + 40.0
	draw_string(font_bold, Vector2(x, y), String(info["title"]), HORIZONTAL_ALIGNMENT_LEFT,
		d.size.x - 48.0, 28, Palette.UI_TEXT)
	y += 26.0
	if String(info["tags"]) != "":
		draw_string(font, Vector2(x, y), String(info["tags"]), HORIZONTAL_ALIGNMENT_LEFT,
			d.size.x - 48.0, 15, Palette.STAIRS)
		y += 30.0
	for line in info["lines"]:
		draw_multiline_string(font, Vector2(x, y), String(line), HORIZONTAL_ALIGNMENT_LEFT,
			d.size.x - 48.0, 15, -1, Palette.UI_TEXT)
		var lines_used := font.get_multiline_string_size(String(line), HORIZONTAL_ALIGNMENT_LEFT,
			d.size.x - 48.0, 15).y
		y += maxf(20.0, lines_used + 2.0)
	var stats: Array = info["stats"]
	if not stats.is_empty():
		var sy := d.end.y - 24.0
		var cw := (d.size.x - 48.0) / float(stats.size())
		for k in stats.size():
			var sx := x + cw * k
			draw_string(font, Vector2(sx, sy - 28.0), String(stats[k][0]), HORIZONTAL_ALIGNMENT_LEFT,
				-1, 13, Palette.UI_DIM)
			draw_string(font_bold, Vector2(sx, sy), String(stats[k][1]), HORIZONTAL_ALIGNMENT_LEFT,
				-1, 24, Palette.UI_TEXT)
