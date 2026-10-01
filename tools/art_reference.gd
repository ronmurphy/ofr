extends SceneTree

## WRITES ART_REFERENCE.md: every tile, creature and item the game draws,
## with its letter, its symbol, its picture (the icon font's codepoint and
## the Nerd Font name it came from), its colour and the size the 3D view
## stands it at -- for an artist drawing a sprite sheet. Read from the real
## tables (the themes, the bestiary, the catalogue, BillboardSizes), so it
## cannot drift from the game. Touches no user:// file.
##
##   godot --headless --path . -s tools/art_reference.gd
const OUT := "res://ART_REFERENCE.md"

func _initialize() -> void:
	var text := _build()
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string(text)
	f.close()
	print("wrote %s (%d lines)" % [OUT, text.count("\n")])
	quit()

## Nerd Font names for the icons: tools/icon_names.json, written from the
## source font's own glyph names by `python3 tools/build_icon_font.py --names`
## (and by every font build); failing that, the comments beside the
## codepoints in glyph_theme.gd (0xF081B   # md-door_closed).
func _icon_names() -> Dictionary:
	var names := {}
	if FileAccess.file_exists("res://tools/icon_names.json"):
		var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string("res://tools/icon_names.json"))
		if parsed is Dictionary:
			for key in parsed:
				if String(parsed[key]) != "":
					names[String(key).trim_prefix("U+").hex_to_int()] = String(parsed[key])
	var src := FileAccess.get_file_as_string("res://src/render/glyph_theme.gd")
	var re := RegEx.new()
	re.compile("(0x[0-9A-Fa-f]+)[^#\\n]*#\\s*((?:md|fa|oct|cod)-[A-Za-z0-9_]+)")
	for m in re.search_all(src):
		var cp := m.get_string(1).hex_to_int()
		if not names.has(cp):
			names[cp] = m.get_string(2)
	return names

func _hex(c: Color) -> String:
	return "#" + c.to_html(false)

func _cp(id: StringName) -> int:
	return int(GlyphTheme.OVERRIDES.get(id, -1))

func _pic(id: StringName, names: Dictionary) -> String:
	var cp := _cp(id)
	if cp < 0:
		return "--"
	return "U+%X (%s)" % [cp, names.get(cp, "?")]

## The drawn shape of an icon: its ink, width to height, from the measured font.
func _aspect(id: StringName) -> String:
	var cp := _cp(id)
	if cp < 0 or not GlyphMetrics.GLYPHS.has(cp):
		return ""
	var g: Array = GlyphMetrics.GLYPHS[cp]
	var w: float = float(g[3]) - float(g[1])
	var h: float = float(g[4]) - float(g[2])
	return "%.2f : 1" % (w / h)

func _box(v: Vector2) -> String:
	return "%.2f x %.2f" % [v.x, v.y]

func _symbol(symbols: RenderTheme, letters: RenderTheme, id: StringName) -> String:
	var s: String = symbols.appearance(id)["ch"]
	return s if s != letters.appearance(id)["ch"] else "(same)"

func _build() -> String:
	var names := _icon_names()
	var letters := AsciiTheme.new()
	var symbols := SymbolTheme.new()
	var out := PackedStringArray()
	var add := func(line: String): out.append(line)

	add.call("# OFR art reference")
	add.call("")
	add.call("Generated %s by `tools/art_reference.gd` from the game's own tables. Regenerate with"
		% Time.get_date_string_from_system())
	add.call("`godot --headless --path . -s tools/art_reference.gd`; do not edit by hand.")
	add.call("")
	add.call("## How the game draws today")
	add.call("")
	add.call("OFR has three looks the player switches between with the `v` key, all drawn from fonts:")
	add.call("")
	add.call("- **letters** -- classic roguelike glyphs, JetBrains Mono.")
	add.call("- **symbols** -- the same, with terrain and items swapped for Unicode shapes; creatures stay letters.")
	add.call("- **pictures** -- icons from `assets/fonts/ofr_icons.ttf`, a subset of JetBrains Mono Nerd Font. Each picture")
	add.call("  is a Nerd Font glyph; the name beside each codepoint below is the icon's name in that set (md- = Material")
	add.call("  Design Icons, fa- = Font Awesome, oct- = Octicons, cod- = Codicons). Anything with no picture falls back to")
	add.call("  its letter in every look.")
	add.call("")
	add.call("**Colour carries family, shape carries rank.** The colour of a thing is the same in all three looks")
	add.call("(the `fg` column); the pictures change shape, never palette. The six humanoids share three figures --")
	add.call("small (kobold, goblin), adult (orc, wight), heavy (ogre, troll, giant) -- and colour tells them apart")
	add.call("inside a class. Sprites should keep that: a kobold and a goblin are the same size and build.")
	add.call("")
	add.call("**Two renderers share the tables.** The classic view is a grid of square cells, one glyph per cell,")
	add.call("at a cell size the player picks: %s px (default %d). The 3D view stands each picture up as a card on"
		% [", ".join(Array(RenderTheme.CELL_SIZES).map(func(c): return str(c))), 18])
	add.call("its cell, fitted into a box measured in cells (the `3D box` column, width x height) -- so a rat stays small")
	add.call("and a dragon is taller than a door (walls are %.2f cells high). Floors are flat tiles with a procedural"
		% DioramaView.WALL_HEIGHT)
	add.call("pattern; walls, rock, pillars, stalagmites, doors, chests and pits are meshes, not pictures.")
	add.call("")
	add.call("**For a sprite sheet.** 64 px per cell is the size that would serve both views (32 is enough for the")
	add.call("classic grid alone). A creature or item sprite would be drawn at its 3D box times the cell size,")
	add.call("anchored bottom-centre on its cell -- e.g. a dragon at 1.60 x 1.30 cells is 102 x 83 px at 64. The")
	add.call("`shape` column is the current icon's ink, width to height, for the silhouette the game sizes today.")
	add.call("Creatures are listed smallest to largest by their standing height.")
	add.call("")

	# ------------------------------------------------------------ fonts ----
	add.call("## Fonts shipped")
	add.call("")
	add.call("| file | what | licence |")
	add.call("|---|---|---|")
	add.call("| `assets/fonts/JetBrainsMono-Regular.ttf`, `-Bold.ttf` | text, the letters and symbols looks | SIL OFL 1.1 |")
	add.call("| `assets/fonts/ofr_icons.ttf` | the pictures look: a subset of JetBrains Mono Nerd Font (Material Design Icons, Apache 2.0; Font Awesome Free, CC BY 4.0; Codicons, CC BY 4.0), built by `tools/build_icon_font.py` | see `assets/fonts/CREDITS.txt` |")
	add.call("| `assets/fonts/kenney_input_xbox_series.ttf` | controller button pictures in hints | CC0 |")
	add.call("")
	add.call("Icons live in the font's private-use area (U+E000 and up); the game draws any such glyph %.0f%% larger"
		% (GlyphTheme.ICON_SCALE * 100.0 - 100.0))
	add.call("than text, times a per-figure scale (small figure x%.2f, armed small x%.2f, heavy figure x%.2f) so the"
		% [GlyphTheme.GLYPH_SCALE[GlyphTheme.SMALL_FIGURE], GlyphTheme.GLYPH_SCALE[GlyphTheme.ARMED_SMALL],
			GlyphTheme.GLYPH_SCALE[GlyphTheme.HEAVY_FIGURE]])
	add.call("ladder reads small < adult < heavy inside one square cell.")
	add.call("")

	# ------------------------------------------------------------ tiles ----
	var tile_ids := {}
	for t in Tiles.DATA:
		tile_ids[Tiles.DATA[t]["id"]] = int(t)
	var item_ids := {}
	for key in Item.CATALOGUE:
		var app: StringName = Item.CATALOGUE[key].get("app", &"")
		if not item_ids.has(app):
			item_ids[app] = []
		item_ids[app].append(String(Item.CATALOGUE[key]["name"]))

	add.call("## Terrain")
	add.call("")
	add.call("Walls and rock have no glyph of their own: the classic view draws them from box-drawing pieces chosen")
	add.call("by their neighbours, the 3D view as blocks. `walk` is whether a creature can stand there, `see` whether")
	add.call("sight and light pass. The legend's note is what the game tells the player about it.")
	add.call("")
	add.call("| tile | letters | symbols | picture | shape | fg | bg | 3D | walk | see | note |")
	add.call("|---|---|---|---|---|---|---|---|---|---|---|")
	for t in Tiles.DATA:
		var id: StringName = Tiles.DATA[t]["id"]
		var a: Dictionary = letters.appearance(id)
		var ch: String = a["ch"]
		var shown := "`%s`" % ch if ch.strip_edges() != "" else "(blank)"
		var drawn := ""
		if LegendPanel.DRAWN.has(id):
			drawn = "procedural (legend shows %s)" % LegendPanel.DRAWN[id]
		var box: Variant = BillboardSizes.BOX.get(id, null)
		var three := ""
		if id == &"void":
			three = "not drawn"
		elif box != null:
			three = "card %s" % _box(box)
		elif id in [&"wall", &"rock", &"pillar", &"stalagmite", &"door_closed", &"door_open",
				&"door_barred", &"chest"]:
			three = "mesh"
		else:
			three = "floor"
		# Walls, rock and pillars are not in the theme table (their glyphs come
		# from their neighbours), so their colours come from the palette here.
		var fg := _hex(a["fg"])
		match id:
			&"wall": fg = "%s / %s (light / dark masonry; hue-shifted per region)" % [_hex(Palette.STONE_LIGHT), _hex(Palette.STONE_DARK)]
			&"rock": fg = "%s / %s (light / dark rock; hue-shifted per region)" % [_hex(Palette.ROCK_LIGHT), _hex(Palette.ROCK_DARK)]
			&"pillar": fg = _hex(Palette.PILLAR)
		add.call("| %s | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |" % [
			String(id).replace("_", " "), drawn if drawn != "" else shown,
			_symbol(symbols, letters, id), _pic(id, names), _aspect(id),
			fg, _hex(a.get("bg", Palette.BG)), three,
			"yes" if Tiles.DATA[t]["walk"] else "no", "yes" if Tiles.DATA[t]["clear"] else "no",
			String(LegendPanel.NOTES.get(int(t), ""))])
	add.call("")

	# -------------------------------------------------------- creatures ----
	add.call("## Creatures, smallest to largest")
	add.call("")
	add.call("Height is the 3D card's box height in cells. `who` lists every bestiary entry wearing the picture, with")
	add.call("the depth it first appears, its hit points and its power; `heavy` creatures shoulder doors open.")
	add.call("")
	var creatures: Array = []
	for id in AsciiTheme.TABLE:
		if tile_ids.has(id) or item_ids.has(id) or id == &"void":
			continue
		creatures.append(id)
	creatures.sort_custom(func(a, b):
		var ba := BillboardSizes.box(a, BillboardSizes.CREATURE)
		var bb := BillboardSizes.box(b, BillboardSizes.CREATURE)
		return ba.y < bb.y if ba.y != bb.y else ba.x < bb.x)
	add.call("| picture id | letters | picture | shape | fg | 3D box (w x h cells) | classic figure scale | who |")
	add.call("|---|---|---|---|---|---|---|---|")
	for id in creatures:
		var a: Dictionary = letters.appearance(id)
		var who := PackedStringArray()
		for e in GameState.BESTIARY:
			if e.get("app", &"") == id:
				who.append("%s (depth %d+, hp %d, power %d%s)" % [e["name"], int(e.get("min_depth", 1)),
					int(e["hp"]), int(e["power"]), ", heavy" if e.get("heavy", false) else ""])
		if who.is_empty():
			match id:
				&"player": who.append("you")
				&"trader": who.append("the trader (neutral)")
				&"bone_ally": who.append("your bone ally (summoned)")
				&"killer_rabbit": who.append("the killer rabbit")
				_: who.append("(not in the bestiary)")
		var cp := _cp(id)
		var scale := "x%.2f" % (float(GlyphTheme.GLYPH_SCALE.get(cp, 1.0)) * GlyphTheme.ICON_SCALE) \
			if cp >= 0 else "letter"
		add.call("| %s | `%s` | %s | %s | %s | %s | %s | %s |" % [
			String(id).replace("_", " "), a["ch"], _pic(id, names), _aspect(id), _hex(a["fg"]),
			_box(BillboardSizes.box(id, BillboardSizes.CREATURE)), scale, "; ".join(who)])
	add.call("")

	# ------------------------------------------------------------ items ----
	add.call("## Items")
	add.call("")
	add.call("One picture per kind of thing, not per item: every gem is the same stone, every sword the same")
	add.call("sword, and the name (read with the look key) says which. `3D box` is the card lying on the floor.")
	add.call("")
	add.call("| picture id | letters | symbols | picture | shape | fg | 3D box | items that wear it |")
	add.call("|---|---|---|---|---|---|---|---|")
	var ids: Array = item_ids.keys()
	ids.sort()
	for id in ids:
		var a: Dictionary = letters.appearance(id)
		var members: Array = item_ids[id]
		members.sort()
		add.call("| %s | `%s` | %s | %s | %s | %s | %s | %s |" % [
			String(id).replace("_", " "), a["ch"], _symbol(symbols, letters, id), _pic(id, names),
			_aspect(id), _hex(a["fg"]), _box(BillboardSizes.box(id, BillboardSizes.ITEM)),
			", ".join(PackedStringArray(members))])
	add.call("")

	# --------------------------------------------------------- the rest ----
	add.call("## Drawn without a glyph")
	add.call("")
	add.call("- **Walls and rock**: box-drawing corners and runs in the classic view (`GlyphGrid.BOX`), chosen from")
	add.call("  the neighbours; masonry or rough rock blocks in 3D, with the region's stone colour.")
	add.call("- **Doors**: a frame of posts and a header, and a leaf that swings; a barred door adds a stone beam.")
	add.call("- **Pits**: a dark hole; **floor dots**: the `.` of empty floor is one batch of small dots in 3D.")
	add.call("- **Light**: the sim's light map tints every surface; braziers and fungus glow; the torch follows you.")
	add.call("- **Marks over creatures** (text, both views): `z`/`zZ`/`zzZ` asleep, `?` suspicious, `.`/`..`/`...`")
	add.call("  on patrol, `<<` fleeing, `!` hunting (in the sidebar list), `✶N` frozen for N turns.")
	add.call("- **The sidebar's skull** (killed by): U+%X (%s)." % [Sidebar.SKULL, names.get(Sidebar.SKULL, "md-skull")])
	add.call("- **Effects**: hit flashes, arrows and sling stones in flight, embers, miasma, blood washes -- drawn")
	add.call("  by each renderer from the same event list, no sprites involved.")
	add.call("")
	add.call("## What a sprite sheet would change")
	add.call("")
	add.call("Both renderers ask a theme `appearance(id)` for a character and a colour and draw text. A sheet would")
	add.call("add a fourth look where that call returns a region of a texture instead: the classic grid blits it")
	add.call("into the cell, the 3D view puts it on the card. Everything keyed by the `picture id` column above")
	add.call("stays as it is; the sheet needs one region per id (tiles, creatures, items), drawn to the sizes here.")
	add.call("")
	return "\n".join(out) + "\n"
