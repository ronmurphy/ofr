class_name ScreenFx
extends ColorRect

## Effects on the whole map rather than on a cell, drawn ONCE over whichever
## view is showing: the red edge when you are hurt (a heartbeat at the health
## line), a new floor fading in out of the dark, and the world going grey when
## you die. One node for both views, so the two cannot drift apart on these.
##
## Hidden whenever there is nothing to show, so on an ordinary turn it costs
## nothing and changes nothing on screen.

## The effects list the views share (the red edge lives in it, as "hurt"), and
## the game, for the floor and for whether you are dead.
var fx: Fx
var state: GameState

var _last_map: DungeonMap = null
var _fade := 0.0
var _grey := 0.0

## How a new floor arrives: out of black over this long. Motion, so not on
## "still", where the floor is simply there.
const FADE_TIME := 0.35
## How long the world takes to go grey when you die.
const GREY_TIME := 1.5

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform vec2 area = vec2(1296.0, 720.0);
uniform float hurt = 0.0;
uniform float fade = 0.0;
uniform float grey = 0.0;
uniform vec3 edge_colour = vec3(0.78, 0.10, 0.08);
uniform float edge_px = 80.0;

void fragment() {
	vec3 under = texture(screen, SCREEN_UV).rgb;
	float luma = dot(under, vec3(0.299, 0.587, 0.114));
	vec3 c = mix(under, vec3(luma * 0.85), grey);
	// Distance to the nearest edge of the map, in pixels: red at the rim,
	// clear by edge_px in, so the middle of the map is never covered.
	vec2 px = min(UV, vec2(1.0) - UV) * area;
	float rim = 1.0 - smoothstep(0.0, edge_px, min(px.x, px.y));
	c = mix(c, edge_colour, rim * rim * hurt);
	c *= 1.0 - fade;
	COLOR = vec4(c, 1.0);
}
"""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SHADER
	m.shader = shader
	material = m
	visible = false

func _process(delta: float) -> void:
	if state == null or fx == null:
		visible = false
		return
	if state.map != _last_map:
		# A new floor fades in -- but not the very first one, and not on
		# "still".
		if _last_map != null and Effects.any():
			_fade = 1.0
		_last_map = state.map
	_fade = maxf(0.0, _fade - delta / FADE_TIME)
	var want_grey := 1.0 if state.game_over else 0.0
	if Effects.any():
		_grey = move_toward(_grey, want_grey, delta / GREY_TIME)
	else:
		_grey = want_grey
	var hurt := Fx.hurt_now(fx.list)
	visible = hurt > 0.0 or _fade > 0.0 or _grey > 0.0
	if not visible:
		return
	var m := material as ShaderMaterial
	m.set_shader_parameter("area", size)
	m.set_shader_parameter("hurt", hurt)
	m.set_shader_parameter("fade", _fade)
	m.set_shader_parameter("grey", _grey)
