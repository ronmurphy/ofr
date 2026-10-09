extends SceneTree
## THE BESTIARY, FOR THE EDITORS (2026-10-08). Prints every creature the
## game can place -- its name, look and where it lives -- as one JSON line
## after the marker BESTIARY_JSON:, and every item LOOK after ITEMS_JSON:
## (2026-10-09), read by tools/build_vault_editor.py for the vault editor's
## creature list and the sprite editor's templates. From
## the game's own tables, so a creature added to the game reaches the editor's
## dropdown on the next build without anyone copying it by hand.
##   godot --headless --path . -s tools/dump_bestiary.gd
func _initialize() -> void:
	var letters := AsciiTheme.new()
	var rows: Array = []
	for e in GameState.BESTIARY:
		var app: StringName = e["app"]
		var look: Dictionary = letters.appearance(app)
		var fg: Color = look["fg"]
		rows.append({
			"name": String(e["name"]),
			"app": String(app),
			"wild": bool(e.get("wild", false)),
			"threat": int(e.get("threat", 0)),
			"min_depth": int(e.get("min_depth", 1)),
			"ascent": int(e.get("ascent_from", 0)),
			"ch": String(look["ch"]),
			"fg": "#" + fg.to_html(false),
			"icon": int(GlyphTheme.OVERRIDES.get(app, -1)),
		})
	print("BESTIARY_JSON:" + JSON.stringify(rows))
	# ITEMS, once per LOOK (2026-10-09, for the sprite editor's templates):
	# items that share an appearance -- the three haunches, the gems -- share
	# a sprite, so they are listed together under the names that use it.
	var looks := {}
	var order: Array = []
	for id in Item.CATALOGUE:
		var entry: Dictionary = Item.CATALOGUE[id]
		var item_app: StringName = entry.get("app", id)
		if not looks.has(item_app):
			var item_look: Dictionary = letters.appearance(item_app)
			var item_fg: Color = item_look["fg"]
			looks[item_app] = {"app": String(item_app), "names": [],
				"ch": String(item_look["ch"]), "fg": "#" + item_fg.to_html(false),
				"icon": int(GlyphTheme.OVERRIDES.get(item_app, -1))}
			order.append(item_app)
		looks[item_app]["names"].append(String(entry.get("name", id)))
	var items: Array = []
	for item_app in order:
		items.append(looks[item_app])
	print("ITEMS_JSON:" + JSON.stringify(items))
	quit()
