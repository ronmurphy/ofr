class_name LightSource
extends RefCounted

## A point light. `color` is its hue at the centre, `color_far` at the rim --
## lerping between them is what gives a torch its warm core and cold edge.

var x: int
var y: int
var radius: int
var color: Color
var color_far: Color
var intensity: float
var flickers: bool

func _init(px: int, py: int, r: int, near: Color, far: Color,
		power: float = 1.0, flicker: bool = false) -> void:
	x = px
	y = py
	radius = r
	color = near
	color_far = far
	intensity = power
	flickers = flicker
