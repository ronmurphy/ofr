class_name LightMap
extends RefCounted

## Accumulated per-cell illumination.
##
## Deliberately separate from field of view. FOV answers "can this be seen",
## which is game logic the AI also asks. Lighting answers "what colour is it",
## which is presentation. Keeping them apart means a monster in an unlit room
## is still legitimately unseen, rather than merely dark.

var width: int
var height: int
var values: PackedColorArray
var ambient: Color = Color(0.06, 0.07, 0.11)

var _occlusion: PackedByteArray

func _init(w: int, h: int) -> void:
	width = w
	height = h
	values.resize(w * h)
	_occlusion.resize(w * h)

func get_light(x: int, y: int) -> Color:
	return values[y * width + x]

func compute(map: DungeonMap, sources: Array) -> void:
	values.fill(ambient)
	for src in sources:
		_apply(map, src)

func _apply(map: DungeonMap, src: LightSource) -> void:
	# Each light casts its own shadows, so walls actually block it.
	Fov.compute(map, src.x, src.y, src.radius, _occlusion)

	var r := src.radius
	var x0 := maxi(0, src.x - r)
	var x1 := mini(width - 1, src.x + r)
	var y0 := maxi(0, src.y - r)
	var y1 := mini(height - 1, src.y + r)
	var inv_r := 1.0 / float(r)

	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var i := y * width + x
			if _occlusion[i] == 0:
				continue
			var dx := float(x - src.x)
			var dy := float(y - src.y)
			var t := clampf(sqrt(dx * dx + dy * dy) * inv_r, 0.0, 1.0)
			# Quadratic falloff keeps the core bright and the rim soft.
			var falloff := 1.0 - t * t
			if falloff <= 0.0:
				continue
			var tint := src.color.lerp(src.color_far, t)
			var add := tint * (falloff * src.intensity)
			values[i] = values[i] + add
