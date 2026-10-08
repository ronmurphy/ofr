extends SceneTree
## THE BESTIARY, FOR THE VAULT EDITOR (2026-10-08). Prints every creature the
## game can place -- its name, look and where it lives -- as one JSON line
## after the marker BESTIARY_JSON:, read by tools/build_vault_editor.py. From
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
	quit()
