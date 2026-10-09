class_name BillboardSizes
extends RefCounted

## How big each picture stands in the 3D view, in map cells.
##
## 3D ONLY. The classic grid has to fit every glyph inside one square cell, so
## its sizes are squeezed into GlyphTheme.GLYPH_SCALE. A billboard has no cell
## to fit: a giant can stand taller than a door and a rat can stay a rat.
##
## Each entry is the BOX a picture is fitted into, as (width, height) in cells.
## The picture keeps its own shape and grows until it meets the box's width or
## its height, whichever comes first. It is measured by its INK, from
## GlyphMetrics, not by its em box -- the font draws the child figure 39% taller
## than the adult one, and sizing by the em box would carry that straight onto
## the screen. So a height here is the height you see.
##
## Keyed by the same appearance ids as the themes. Anything not listed takes
## the default for its kind, below.

const BOX := {
	# --- creatures: the humanoid ladder, then everything else ---------------
	&"player":        Vector2(0.60, 0.85),
	&"trader":        Vector2(0.80, 0.85),
	&"kobold":        Vector2(0.60, 0.60),
	&"goblin":        Vector2(0.60, 0.62),
	&"slinger":       Vector2(0.62, 0.62),
	&"orc":           Vector2(0.80, 0.80),
	&"wight":         Vector2(0.80, 0.82),
	&"wizard":        Vector2(0.80, 0.82),
	&"ogre":          Vector2(0.95, 1.05),
	&"troll":         Vector2(1.00, 1.10),
	&"giant":         Vector2(1.20, 1.40),

	&"rat":           Vector2(0.60, 0.40),
	&"slime":         Vector2(0.62, 0.42),
	&"wolf":          Vector2(0.85, 0.55),
	&"bat":           Vector2(0.75, 0.36),
	&"spider":        Vector2(0.80, 0.50),
	&"rabbit":        Vector2(0.55, 0.45),
	&"killer_rabbit": Vector2(0.60, 0.50),
	&"skeleton":      Vector2(0.70, 0.66),
	&"bone_ally":     Vector2(0.70, 0.66),
	&"harpy":         Vector2(0.90, 0.70),
	&"bear":          Vector2(1.00, 0.85),
	&"golem":         Vector2(0.95, 1.00),
	&"shadow":        Vector2(0.80, 0.85),
	&"banshee":       Vector2(0.80, 0.80),
	&"lich":          Vector2(0.90, 0.90),
	&"wyvern":        Vector2(1.40, 1.10),
	&"dragon":        Vector2(1.60, 1.30),

	# --- carryables, lying on the floor --------------------------------------
	&"gem":           Vector2(0.40, 0.30),
	&"ring":          Vector2(0.36, 0.30),
	&"amulet":        Vector2(0.40, 0.34),
	&"ammo":          Vector2(0.50, 0.30),

	# --- terrain features stood up on their cell -----------------------------
	&"brazier":       Vector2(0.60, 0.60),
	&"brazier_spent": Vector2(0.60, 0.60),
	&"brazier_dead":  Vector2(0.60, 0.60),
	&"grave":         Vector2(0.55, 0.60),
	&"shrine":        Vector2(0.75, 0.70),
	&"chest":         Vector2(0.60, 0.45),
	&"stairs_down":   Vector2(0.60, 0.45),
	&"stairs_up":     Vector2(0.60, 0.45),
	&"trap":          Vector2(0.55, 0.40),
	&"water":         Vector2(0.50, 0.30),
	&"fungus":        Vector2(0.50, 0.40),
	&"purple_fungus": Vector2(0.50, 0.40),
	&"red_fungus":    Vector2(0.50, 0.40),
	&"bones":         Vector2(0.50, 0.30),
}

## Defaults for anything the table does not name.
const CREATURE := Vector2(0.90, 0.80)
const ITEM := Vector2(0.50, 0.36)
const FEATURE := Vector2(0.60, 0.50)

static func box(id: StringName, fallback: Vector2) -> Vector2:
	return BOX.get(id, fallback)
