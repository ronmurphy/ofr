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
	# EVERY LOOK A CARD CAN SHOW, for the sprite editor (2026-10-09): the
	# creatures above plus the ones no vault places -- you, the trader, your
	# risen bones, the killer rabbit -- and the item looks, each with the
	# canvas its template is drawn on (PixelSprites.canvas_for, from the
	# card's box) and the colour the 3D view really draws it in: an animal in
	# the one colour for animals, Palette.WILD, as the picture look does.
	var cards: Array = []
	var people := [[&"player", "you"], [&"trader", "the trader"],
		[&"bone_ally", "your risen bones"]]
	for pair in people:
		cards.append(_card(letters, pair[0], pair[1], "people and allies",
			BillboardSizes.CREATURE, false))
	for e in GameState.BESTIARY:
		var wild := bool(e.get("wild", false))
		cards.append(_card(letters, e["app"], String(e["name"]),
			"wild animals" if wild else "monsters", BillboardSizes.CREATURE, wild))
	cards.append(_card(letters, &"killer_rabbit", "killer rabbit", "monsters",
		BillboardSizes.CREATURE, false))
	for row in items:
		var names: Array = row["names"]
		cards.append(_card(letters, StringName(row["app"]),
			String(names[0]) if names.size() == 1 else "%s (%d items)" % [row["app"], names.size()],
			"items", BillboardSizes.ITEM, false))
	print("LOOKS_JSON:" + JSON.stringify(cards))
	quit()

func _card(letters: AsciiTheme, app: StringName, label: String, group: String,
		fallback: Vector2, wild: bool) -> Dictionary:
	var look: Dictionary = letters.appearance(app)
	var fg: Color = Palette.WILD if wild else look["fg"]
	var size := PixelSprites.canvas_for(BillboardSizes.box(app, fallback))
	return {"app": String(app), "label": label, "group": group,
		"ch": String(look["ch"]), "fg": "#" + fg.to_html(false),
		"icon": int(GlyphTheme.OVERRIDES.get(app, -1)), "size": [size.x, size.y]}
