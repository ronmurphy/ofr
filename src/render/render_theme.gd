class_name RenderTheme
extends RefCounted

## The seam between simulation and presentation.
##
## The simulation only ever emits semantic ids -- &"wall", &"goblin". A theme
## turns an id into something drawable. This one returns a character and a
## colour; a Kenney tileset theme would return an atlas region instead, and the
## simulation would never know the difference.
##
## To add a tile-graphics mode later:
##   1. Subclass this and return {"tex": Texture2D, "region": Rect2i, ...}
##   2. Write a TileGrid Control that consumes it, mirroring GlyphGrid
##   3. Swap which node the main scene instantiates
## No file under src/sim/ needs to change.

func appearance(id: StringName) -> Dictionary:
	return {"ch": "?", "fg": Color.MAGENTA}
