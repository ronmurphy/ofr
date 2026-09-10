class_name GlyphGrid
extends Control

## Draws the simulation as a grid of glyphs.
##
## Three things here are what separate this from a terminal:
##   - square cells, so the dungeon is not vertically stretched and diagonal
##     movement looks correct
##   - per-cell BACKGROUND colour, which almost no terminal roguelike uses well
##     and which is most of what makes the map read as a lit scene
##   - box-drawing walls chosen from neighbours, so rooms have real outlines

signal cell_clicked(cell: Vector2i)
signal cell_right_clicked(cell: Vector2i)

enum WallStyle {
	LINE,   ## procedural single-line box drawing -- always connects
	SOLID,  ## filled blocks, heavier and more "dungeon"
	GLYPH,  ## font box-drawing characters; dashes in a square cell
}

@export var cell_size: int = 18
@export var font_size: int = 16
@export var font: Font
## Purely a taste call, so it is exposed rather than decided. LINE is the
## default because font box-glyphs are only ~0.6 cells wide and leave visible
## gaps in horizontal runs once the cell is square.
@export var wall_style: WallStyle = WallStyle.LINE
## Cells of clearance kept between the player and the viewport edge before the
## camera moves at all.
##
## A camera locked to the player slides the entire map on every single step,
## which is disorienting in a game you read off a grid -- you lose track of
## where things were. A deadzone keeps the map still while you move around a
## room and only scrolls when you approach an edge.
@export var scroll_margin: int = 8
## How hard a room's material is re-asserted on remembered terrain. 1.0 is the
## same strength as lit ground, which memory's desaturation mostly erases;
## above that trades subtlety for legibility at a glance. Purely taste.
@export var memory_material_boost: float = 1.8

## Whether the shader is doing the animating. Driven by the player's Effects
## setting, not set by hand -- see apply_effects_mode().
var block_anim: bool = false
## Multiplies every animation amplitude. 1.0 is the tuned value; turn it up to
## see whether an effect is firing at all.
@export var anim_strength: float = 1.0
## Discrete levels the animation snaps between. 0 is a smooth sine; small
## numbers read as palette cycling, which is the technique the block look
## actually comes from.
@export var anim_steps: int = 4
var _cell_tex: ImageTexture
var _cell_img: Image

var state: GameState
## Read fresh on every draw rather than held, so cycling the view mode reaches
## the grid, the legend and the inventory in the same frame.
var render_theme: RenderTheme:
	get: return RenderTheme.active()

## Horizontal offset per character, cached.
##
## This used to be one number measured from "M" and reused for everything,
## which is correct only while every glyph is the same width. It is not: in
## this very font the shrine gate is 16px and the shield 12px against a 10px
## reference, so a single offset puts them off-centre and pushes the widest of
## them into the neighbouring cell. Same lesson as the dashed walls -- one
## measurement cannot stand in for all of them.
var _dx_cache := {}

# Wall connection bits: N=1 S=2 W=4 E=8
const BOX := {
	0: "█", 1: "║", 2: "║", 3: "║",
	4: "═", 5: "╝", 6: "╗", 7: "╣",
	8: "═", 9: "╚", 10: "╔", 11: "╠",
	12: "═", 13: "╩", 14: "╦", 15: "╬",
}

## Driven by the keyboard look mode. When valid it takes precedence over the
## mouse hover, since the two would otherwise fight for the same highlight.
var look_cursor := Vector2i(-1, -1)
## Targeting. `aim_line` is the path a shot would take and `aim_valid` says
## whether it can actually be taken -- a blocked shot must look blocked before
## the player commits a turn to it.
var aim_cursor := Vector2i(-1, -1)
var aim_line: Array[Vector2i] = []
var aim_valid := false
var _hover := Vector2i(-1, -1)
var _preview: Array[Vector2i] = []
var _glyph_dx := 0.0
var _glyph_baseline := 0.0
## Torch flicker lives here, in the renderer, NOT in the simulation. The sim
## must stay deterministic and turn-driven; flicker is a per-frame visual.
var _flicker_t := 0.0
var _flicker_jitter := 0.0
var _flicker_accum := 0.0
## Which flickering light owns each cell, as a phase offset. -1 means no
## flickering source reaches it, so it holds perfectly still.
##
## The flicker used to be one number multiplying every lit cell on screen, so a
## brazier on the far side of the map guttered in perfect time with your torch.
## That reads as the whole screen breathing rather than as flames burning, and
## it is why several independent rhythms look so much more alive than one.
##
## Rebuilt per refresh rather than per frame: the sources only move when a turn
## passes. The light map itself lives in src/sim/ and accumulates every source
## into one colour per cell, so by the time the renderer sees it, whose light it
## was is gone -- this recovers that without the simulation having to care.
var _phase := PackedFloat32Array()
var _phase_w := 0

## Transient visual effects. Deliberately generic: a floating damage number and
## an overhead "!" or "zzZ" are the same thing -- a marker that appears above a
## cell and fades -- so the awareness pass gets those almost for free.
var _effects: Array = []
## Guards against an animation outliving the level it belongs to. Descending
## mid-flight would otherwise draw the old level's arrow on the new one.
var _last_map: DungeonMap = null
## Top-left map cell currently shown.
var _origin := Vector2i.ZERO
## Where the camera is actually drawn, which lags the logical origin so the map
## glides instead of jumping a whole cell mid-stride.
var _camera_visual := Vector2.ZERO

## Visual positions, which lag the logical ones. Keyed by entity.
##
## The simulation resolves a turn instantly and always will; this only changes
## where things are DRAWN while it settles. Nothing under src/sim/ knows.
var _motion: Dictionary = {}
## Short on purpose. The rule that decides whether this feels good is that an
## animation must never delay input -- see settle_motion().
const STEP_TIME := 0.10

## Roughly DCSS's pace. A quarter-second per cell would add a second and a half
## to every archer's turn, hundreds of times a run.
const SHOT_PER_CELL := 0.028
const FLASH_LIFE := 0.30
const POPUP_LIFE := 0.85
## How long a noise ring dwells on each cell it crosses.
##
## Per CELL, not per ring, so every wavefront travels at the same speed and a
## bigger noise takes longer to arrive rather than moving faster. With a fixed
## lifetime a floor-wide shrine and a footstep on bones crossed their very
## different distances in the same fraction of a second, which read as the loud
## one being quicker rather than larger.
const RING_PER_CELL := 0.045
## How long a knockback chevron stays up. Deliberately the longest effect in
## the game -- longer than a popup -- because it is the only one explaining
## something the player did not do themselves. Brad asked for "a second or
## two"; this is short of that because effects here overlap the next turn, and
## it is the number to raise if the shove still reads as the screen jumping.
const SHOVE_LIFE := 0.80

## Capture-only: stops effects ageing so a screenshot tool can park one at a
## chosen point in its life and photograph it.
##
## The same idea as `anim_time` for the shaders, and it exists for the same
## reason: _shot waits four frames per image, which is easily longer than an
## effect lives, so every attempt to photograph the knockback chevron caught
## the frame after it had already been culled. Three rounds of hunting a
## rendering bug that was not there.
var hold_effects := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if font == null:
		font = map_font()
	_measure_font()
	set_process(true)

## The font the map is drawn with.
##
## The icon subset first, with the full text face behind it as a fallback, and
## the fallback is not decoration. The subset IS JetBrains Mono -- the Nerd Font
## is that face patched -- so the original reasoning was that one font could
## cover all three view modes. What that missed is that pyftsubset threw away
## everything the tool was not told to keep, and the LETTERS theme draws two
## characters outside ASCII: Omega for all three braziers and the cap for a
## shrine. Neither survived the subset.
##
## The failure was silent and asymmetric, which is what made it survive. On the
## map those four tiles drew as bare coloured squares -- a brazier you could
## walk into and not see -- while the legend showed them perfectly, because the
## legend loads the text face directly. Every visual check therefore agreed the
## glyphs existed.
##
## A fallback fixes the class rather than the two characters, so the next entry
## added to a theme cannot reintroduce it. _test_every_theme_glyph_is_drawable
## asserts the whole chain covers every theme.
static func map_font() -> Font:
	var icons: FontFile = load("res://assets/fonts/ofr_icons.ttf")
	icons.fallbacks = [load("res://assets/fonts/JetBrainsMono-Regular.ttf")]
	return icons

func _measure_font() -> void:
	var advance := font.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var ascent := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	_glyph_dx = (cell_size - advance) * 0.5
	_glyph_baseline = (cell_size - (ascent + descent)) * 0.5 + ascent
	_dx_cache.clear()

## Drops the width cache. Called when the view mode changes, since a whole new
## set of characters is about to be drawn.
func forget_metrics() -> void:
	_dx_cache.clear()

## The size a character is drawn at, and how far to inset it. Cached together,
## because both are wanted at the same moment and measuring text is not free.
##
## This used to be one offset measured from "M" and reused for everything,
## which is correct only while every glyph is the same width. It is not: the
## shrine gate is 16px and the shield 12px against a 10px reference, so a
## single offset put them off-centre and pushed the widest into the next cell.
func _metrics(ch: String) -> Vector2:
	if _dx_cache.has(ch):
		return _dx_cache[ch]
	var size := GlyphTheme.draw_size(ch, font_size)
	var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var m := Vector2((cell_size - w) * 0.5, float(size))
	_dx_cache[ch] = m
	return m

## Where the glyph's baseline sits. Icons are drawn centred on the cell rather
## than on a text baseline: they have no notion of x-height or descenders, and
## sitting them on the letters' baseline hangs them too low.
func _baseline(ch: String, size: int) -> float:
	if not GlyphTheme.is_icon(ch):
		return _glyph_baseline
	return (cell_size - (font.get_ascent(size) + font.get_descent(size))) * 0.5 \
		+ font.get_ascent(size)

func _process(delta: float) -> void:
	for e in _motion:
		if float(_motion[e]["t"]) < STEP_TIME:
			_motion[e]["t"] = minf(STEP_TIME, float(_motion[e]["t"]) + delta)
	var target := Vector2(_origin)
	if _camera_visual.distance_squared_to(target) > 0.0004:
		_camera_visual = _camera_visual.lerp(target, clampf(delta / STEP_TIME, 0.0, 1.0))
	else:
		_camera_visual = target

	var animating := not _effects.is_empty() or _motion_running()
	if animating and not hold_effects:
		for e in _effects:
			e["t"] += delta
		_effects = _effects.filter(func(e): return not _expired(e))

	# Flicker refreshes at ~15Hz rather than every frame: cheaper, and a
	# choppier flame reads more like a real torch than a smooth sine does.
	# Effects, when running, redraw at full rate.
	_flicker_accum += delta
	var flicker_due := _flicker_accum >= 1.0 / 15.0
	if flicker_due:
		_flicker_accum = 0.0
		# The time and the jitter are shared; the PHASE is not, which is what
		# stops every flame on the floor moving as one.
		_flicker_t = Time.get_ticks_msec() / 1000.0
		_flicker_jitter = randf_range(-0.02, 0.02)

	if animating or flicker_due:
		queue_redraw()

## Turns simulation events into animations. The outcome is already decided by
## the time this runs -- these only show the player what happened.
func play_events(evts: Array) -> void:
	for e in evts:
		var to: Vector2i = e["to"]

		if e["kind"] == &"levelup":
			_effects.append({"type": &"popup", "cell": to, "t": 0.0,
				"text": "LEVEL UP", "colour": Palette.STAIRS, "size": font_size})
			continue

		# Noise, drawn as the wavefront it already was.
		#
		# The comment below used to say the rest of the queue "has no picture to
		# draw by definition". Noise was the exception hiding in that sentence:
		# the simulation has always known exactly how far a sound carried, and
		# the player could only ever infer it. Showing it turns a hidden rule
		# into something you can plan around -- whether to take the shot when
		# there are two more of them in the next room.
		if e["kind"] == &"noise":
			# Motion, so it answers to the accessibility setting. The message
			# log still reports the same thing in words for anyone playing on
			# "still", so nothing is only available to people who can take the
			# movement.
			if Effects.any():
				var reach := int(e["radius"])
				_effects.append({"type": &"ring", "cell": to, "t": 0.0,
					"radius": reach,
					"life": maxf(0.12, float(reach) * RING_PER_CELL)})
			continue

		if e["kind"] == &"shove":
			# You just moved two cells without pressing anything. Without a
			# mark where you landed that reads as the screen glitching rather
			# than as something having happened to you.
			#
			# A chevron rather than a ring, which is what this was first: a
			# ring says something happened HERE, and the whole point of a
			# shove is that it happened in a DIRECTION.
			if Effects.any():
				var was: Vector2i = e["from"]
				_effects.append({"type": &"shove", "from": was, "to": to,
					"dir": Vector2i(signi(to.x - was.x), signi(to.y - was.y)),
					"t": 0.0, "life": SHOVE_LIFE})
			continue

		if e["kind"] == &"notice":
			# The Metal Gear beat: a big "!" over the head of whatever just
			# clocked you.
			_effects.append({"type": &"popup", "cell": to, "t": 0.0, "text": "!",
				"colour": Palette.ALERT, "size": font_size + 3})
			continue

		# Everything else on the queue is for the ears. The same list feeds
		# SoundDeck, and most of what is on it -- noise carrying through
		# stone, a change of footing, crossing the health line -- has no
		# picture to draw by definition.
		if e["kind"] != &"melee" and e["kind"] != &"ranged":
			continue

		var hostile: bool = e["on_player"]
		var delay := 0.0

		if e["kind"] == &"ranged":
			var line := Los.path(e["from"].x, e["from"].y, to.x, to.y)
			if not line.is_empty():
				_effects.append({"type": &"shot", "path": line, "t": 0.0})
				delay = line.size() * SHOT_PER_CELL

		# Negative time is a delay: the impact lands when the shot arrives.
		_effects.append({"type": &"flash", "cell": to, "t": -delay,
			"colour": Palette.HP_BAD if hostile else Palette.HIT_FLASH})
		_effects.append({"type": &"popup", "cell": to, "t": -delay,
			"text": str(e["amount"]),
			"colour": Palette.HP_BAD if hostile else Palette.UI_TEXT})

	if not _effects.is_empty():
		queue_redraw()

## ADD EVERY NEW EFFECT TYPE HERE. The fallthrough is "expired", so an effect
## this function has not been taught about is created correctly, culled on the
## very first frame, and never draws once -- with nothing wrong in the effect
## itself and nothing logged. The knockback chevron was invisible for exactly
## this reason and took a screenshot to find.
##
## The fallthrough stays `true` on purpose: the other way round, a typo would
## pin an effect on screen forever.
func _expired(e: Dictionary) -> bool:
	match e["type"]:
		&"ring":  return e["t"] >= float(e.get("life", 0.42))
		&"shot":  return e["t"] >= e["path"].size() * SHOT_PER_CELL
		&"flash": return e["t"] >= FLASH_LIFE
		&"popup": return e["t"] >= POPUP_LIFE
		&"shove": return e["t"] >= float(e.get("life", SHOVE_LIFE))
	return true

func grid_size() -> Vector2:
	if state == null:
		return Vector2.ZERO
	return Vector2(state.map.width * cell_size, state.map.height * cell_size)

## Size of the visible window, in cells.
func viewport_cells() -> Vector2i:
	return Vector2i(floori(size.x / cell_size), floori(size.y / cell_size))

## Map cell -> pixel position within this control.
func _screen(cell: Vector2i) -> Vector2:
	return _screen_f(Vector2(cell))

func _screen_f(cell: Vector2) -> Vector2:
	return (cell - _camera_visual) * cell_size

func cell_at(local_pos: Vector2) -> Vector2i:
	return Vector2i(floori(local_pos.x / cell_size + _camera_visual.x),
		floori(local_pos.y / cell_size + _camera_visual.y))

## Snaps the drawn camera onto the logical one.
func settle_camera() -> void:
	_camera_visual = Vector2(_origin)

func centre_on_player() -> void:
	if state == null:
		return
	var vc := viewport_cells()
	_origin = Vector2i(state.player.x - vc.x / 2, state.player.y - vc.y / 2)
	_clamp_origin()
	settle_camera()

func _update_camera() -> void:
	var vc := viewport_cells()
	# Look mode drives the camera, not the player. Look already inspects
	# remembered terrain far outside the torch, so it was never limited to
	# "what is around you" -- the viewport edge stopping it was an accident of
	# the camera rather than a rule.
	var p := Vector2i(state.player.x, state.player.y)
	if state.map.in_bounds(look_cursor.x, look_cursor.y):
		p = look_cursor
	elif state.map.in_bounds(aim_cursor.x, aim_cursor.y):
		p = aim_cursor

	# Only move if the player has come inside the margin. Otherwise leave the
	# view exactly where it was.
	var lo_x := p.x - vc.x + 1 + scroll_margin
	var hi_x := p.x - scroll_margin
	if lo_x <= hi_x:
		_origin.x = clampi(_origin.x, lo_x, hi_x)
	var lo_y := p.y - vc.y + 1 + scroll_margin
	var hi_y := p.y - scroll_margin
	if lo_y <= hi_y:
		_origin.y = clampi(_origin.y, lo_y, hi_y)

	_clamp_origin()

func _clamp_origin() -> void:
	var vc := viewport_cells()
	_origin.x = clampi(_origin.x, 0, maxi(0, state.map.width - vc.x))
	_origin.y = clampi(_origin.y, 0, maxi(0, state.map.height - vc.y))

# ------------------------------------------------------------------ input ---

func _gui_input(event: InputEvent) -> void:
	if state == null:
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		var c := cell_at(motion.position)
		if c != _hover:
			_hover = c
			_update_preview()
			queue_redraw()
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	if click.button_index == MOUSE_BUTTON_LEFT:
		cell_clicked.emit(cell_at(click.position))
	elif click.button_index == MOUSE_BUTTON_RIGHT:
		cell_right_clicked.emit(cell_at(click.position))

func _update_preview() -> void:
	_preview.clear()
	if not state.map.in_bounds(_hover.x, _hover.y):
		return
	if not state.map.is_explored(_hover.x, _hover.y):
		return
	_preview = state.pathfinder.path(Vector2i(state.player.x, state.player.y), _hover)

func hovered_cell() -> Vector2i:
	return _hover

# ------------------------------------------------------------------ motion ---

## Everything still in flight completes at once.
##
## This is the rule the whole feature rests on: holding a direction key must
## never be slower than the simulation. Fast play then looks essentially
## instant, and only considered play looks animated.
func settle_motion() -> void:
	for e in _motion:
		_motion[e]["from"] = _motion[e]["to"]
		_motion[e]["t"] = STEP_TIME

## Starts a tween for anything that has moved since we last looked.
func sync_motion() -> void:
	if state == null:
		return
	_rebuild_phases()
	var seen := {}
	for e in state.entities:
		if not e.alive:
			continue
		seen[e] = true
		var now := Vector2(e.x, e.y)
		if not _motion.has(e):
			_motion[e] = {"from": now, "to": now, "t": STEP_TIME}
			continue
		var m: Dictionary = _motion[e]
		if m["to"] != now:
			m["from"] = _visual_cell(e)
			m["to"] = now
			m["t"] = 0.0
	for e in _motion.keys():
		if not seen.has(e):
			_motion.erase(e)

func _visual_cell(e: Entity) -> Vector2:
	if not _motion.has(e):
		return Vector2(e.x, e.y)
	var m: Dictionary = _motion[e]
	var k := clampf(float(m["t"]) / STEP_TIME, 0.0, 1.0)
	# Eased out, so a step lands rather than drifting to a halt.
	k = 1.0 - pow(1.0 - k, 2.0)
	return (m["from"] as Vector2).lerp(m["to"], k)

func _motion_running() -> bool:
	for e in _motion:
		if float(_motion[e]["t"]) < STEP_TIME:
			return true
	return _camera_visual.distance_squared_to(Vector2(_origin)) > 0.0004

## Recomputed whenever the world changes, not only when the mouse moves.
##
## Without this the dots were stale the moment you touched the keyboard, and
## survived a descent -- drawing the previous floor's route across the new one.
func refresh_preview() -> void:
	_update_preview()

# ----------------------------------------------------------------- drawing ---

func _draw() -> void:
	if state == null:
		return
	var map := state.map
	if map != _last_map:
		_last_map = map
		_effects.clear()
		_preview.clear()
		# A new level should not inherit the old one's scroll position.
		centre_on_player()
	_update_camera()

	if block_anim:
		_upload_cells()

	draw_rect(Rect2(Vector2.ZERO, size), Palette.BG, true)

	# Only the visible window is drawn. On a large map that is most of the
	# cost of a redraw.
	# One extra cell each way, so the partial row and column exposed by a
	# gliding camera are drawn rather than leaving a blank edge.
	var vc := viewport_cells()
	var x0 := maxi(0, _origin.x - 1)
	var y0 := maxi(0, _origin.y - 1)
	var x1 := mini(map.width, _origin.x + vc.x + 2)
	var y1 := mini(map.height, _origin.y + vc.y + 2)
	for y in range(y0, y1):
		for x in range(x0, x1):
			_draw_cell(map, x, y)

	# Ground items sit under actors, so a monster standing on loot still reads
	# as the thing you need to deal with first.
	for it in state.ground:
		if map.is_visible(it.x, it.y):
			_draw_glyph(it.appearance, Vector2(it.x, it.y))

	for e in state.entities:
		if e.alive and not e.is_player and map.is_visible(e.x, e.y):
			_draw_wound(e)
			# The glyph still says WHICH creature; the colour only says that
			# the climb has been at it. One override rather than a second set
			# of theme entries, because there is nothing per-creature to say.
			if e.corrupted:
				_draw_glyph_tinted(e.appearance, _visual_cell(e), Palette.CORRUPTED)
			else:
				_draw_glyph(e.appearance, _visual_cell(e))
	if state.player.alive:
		_draw_glyph(state.player.appearance, _visual_cell(state.player))

	# Awareness markers are state, not events -- they persist for as long as
	# the monster is in that state, unlike the one-shot "!".
	for e in state.entities:
		if e.alive and not e.is_player and map.is_visible(e.x, e.y):
			_draw_awareness(e)

	_draw_preview()
	_draw_aim()
	_draw_cursor()
	_draw_effects()

func _draw_cell(map: DungeonMap, x: int, y: int) -> void:
	var visible_here := map.is_visible(x, y)
	if not visible_here and not map.is_explored(x, y):
		return

	var tile := map.get_tile(x, y)
	var is_wall := tile == Tiles.WALL
	# Masonry buried inside solid rock is never visible in play -- field of
	# view can only reach a wall that faces open space. Skipping it keeps the
	# revealed-map overview readable instead of a field of stray marks.
	if is_wall and not _is_face_wall(map, x, y):
		return
	var ch := ""
	var fg: Color
	var bg: Color

	var is_rock := tile == Tiles.ROCK
	var is_pillar := tile == Tiles.PILLAR
	var is_pit := tile == Tiles.PIT

	if is_wall:
		fg = Palette.STONE_LIGHT
		bg = Palette.STONE_DARK
	elif is_rock:
		# Deterministic per-cell jitter, so natural stone reads as rough rather
		# than as a flat slab, and looks the same every time it is drawn.
		var n := _hash01(x, y)
		fg = Palette.ROCK_LIGHT.lerp(Palette.ROCK_DARK, n * 0.55)
		bg = fg
	elif is_pillar:
		fg = Palette.PILLAR
		bg = Palette.STONE_DARK
	else:
		var app := render_theme.appearance(Tiles.appearance_id(tile))
		ch = app["ch"]
		fg = app["fg"]
		bg = app.get("bg", Palette.BG)
		# A shrine's colour is its whole identity, and it is shuffled per run,
		# so it cannot live in a static theme table.
		if tile == Tiles.SHRINE:
			fg = state.shrine_hue(int(state.shrine_at.get(Vector2i(x, y), 0)))
		# Neither can a dying brazier's, for the same reason: it depends on the
		# turn, not on the tile.
		#
		# This is the twenty-turn forging window, drawn instead of counted.
		# Brad's rule for it was no number on screen -- the player works out
		# what the fade means by watching one go out -- so the gauge has to BE
		# the thing rather than label it. Only while the cell is actually in
		# sight: how hot a brazier still is across the level is not something
		# memory could honestly know.
		elif tile == Tiles.BRAZIER_SPENT and visible_here:
			var heat := state.ember_heat(x, y)
			if heat > 0.0:
				# Coals breathe, and stop breathing as they cool -- the pulse
				# is scaled by the same heat that drives the colour, so the
				# tile visibly goes still before it goes grey. Phase from the
				# cell, so two braziers in a room never pulse together.
				# Held at rest when the player has asked for no motion. The
				# COLOUR ramp stays either way -- that is information about how
				# long the embers have left, not decoration, and turning
				# effects off must not cost you information.
				var beat := 1.0
				if Effects.any():
					beat += 0.10 * heat * sin(
						Time.get_ticks_msec() / 340.0 + _hash01(x, y) * TAU)
				# Hue alone was not enough. Walking EMBERS -> BRAZIER_DEAD
				# moves luminance only 0.386 -> 0.283, so the middle third of
				# the window was a mush of near-identical browns and the gauge
				# could not be read. The glow adds the brightness the hue shift
				# does not carry, and it is tied to the same heat, so the tile
				# dims as well as greys.
				fg = (fg.lerp(Palette.EMBERS, heat) * (1.0 + EMBER_GLOW * heat)
					* beat).clamp()
				bg = bg.lerp(Palette.EMBERS_BG, heat)
				fg.a = 1.0

	var tint := _material_tint(map.material_at(x, y), 1.0)

	if visible_here:
		var lit: Color = state.light_map.get_light(x, y) * _flicker_at(x, y)
		fg = (fg * tint * lit).clamp()
		bg = (bg * tint * lit).clamp()
	elif tile == Tiles.STAIRS_DOWN or tile == Tiles.STAIRS_UP:
		# Exempt from memory dimming, and breathing gently so the eye finds it
		# on a large map.
		#
		# STAIRS_UP was missing from this and it mattered: climbing out, the
		# staircase you are actually walking towards is the one thing on the
		# map that had no exemption. It matters more now that the corrupted
		# caves hide memory entirely -- the way out is the only thing you are
		# allowed to keep remembering, which is both survivable and the right
		# image.
		# Still, but not dim: frozen at the top of its breath rather than the
		# middle, so the stairs stay as findable as they are meant to be.
		var pulse := 1.0
		if Effects.any():
			pulse = 0.78 + 0.22 * sin(Time.get_ticks_msec() / 620.0)
		fg = Color(Palette.STAIRS_KNOWN.r * pulse, Palette.STAIRS_KNOWN.g * pulse,
			Palette.STAIRS_KNOWN.b * pulse, 1.0)
		bg = _remembered(bg)
	else:
		# The material is re-applied, harder, after desaturation -- without it
		# every remembered room washes to the same blue and the whole point,
		# telling one room from another on the memory map, is lost.
		#
		# But brightness is held to exactly what untinted memory would have
		# been. A tint that lifts luminance makes a remembered room read as a
		# lit one, which is the same collision as tinting the torch, arriving
		# by a different route.
		var memory_tint := _material_tint(map.material_at(x, y), memory_material_boost)
		fg = _tint_keeping_luma(_remembered(fg), memory_tint)
		bg = _tint_keeping_luma(_remembered(bg), memory_tint)
		# How much of the floor you get to keep.
		#
		# Caves are darker to remember than built ground; the corrupted ones
		# are not remembered at all. That is the band's whole character in one
		# multiplier -- you cannot map a place that will not stay in your head,
		# so the climb through them is walked blind rather than read off a map
		# you built on the way down.
		var recall := _memory_strength()
		if recall <= 0.0:
			return
		if recall < 1.0:
			fg = Color(fg.r * recall, fg.g * recall, fg.b * recall, 1.0)
			bg = Color(bg.r * recall, bg.g * recall, bg.b * recall, 1.0)

	var origin := _screen(Vector2i(x, y))
	var cell := Vector2(cell_size, cell_size)

	if is_wall:
		_draw_wall(origin, _wall_mask(map, x, y), fg, bg)
		return
	if is_rock:
		# Solid, no box-drawing: caverns were not built by masons.
		draw_rect(Rect2(origin, cell), fg, true)
		return
	if is_pillar:
		draw_rect(Rect2(origin, cell), bg, true)
		draw_circle(origin + cell * 0.5, cell_size * 0.34, fg)
		return
	if is_pit:
		# Drawn rather than lettered: a hole should read as absence, and no
		# glyph says "nothing is there" as plainly as nothing being there.
		draw_rect(Rect2(origin, cell), Palette.BG, true)
		draw_circle(origin + cell * 0.5, cell_size * 0.40, Color(0, 0, 0, 1))
		draw_arc(origin + cell * 0.5, cell_size * 0.40, 0.0, TAU, 14, fg, 1.5)
		return

	draw_rect(Rect2(origin, cell), bg, true)
	if ch != " ":
		var m := _metrics(ch)
		draw_char(font, origin + Vector2(m.x, _baseline(ch, int(m.y))), ch, int(m.y), fg)

## Walls are drawn from their connection mask rather than from a font glyph.
##
## A box-drawing character fills its own advance width, which is about 0.6 of a
## square cell -- so a run of ═ comes out as dashes with gaps between them.
## Drawing the strokes directly connects perfectly at any cell size and stays
## crisp when you change cell_size later.
func _draw_wall(origin: Vector2, mask: int, fg: Color, bg: Color) -> void:
	var cell := Vector2(cell_size, cell_size)

	if wall_style == WallStyle.SOLID:
		draw_rect(Rect2(origin, cell), fg, true)
		return
	if wall_style == WallStyle.GLYPH:
		draw_rect(Rect2(origin, cell), bg, true)
		var bm := _metrics(BOX[mask])
		draw_char(font, origin + Vector2(bm.x, _glyph_baseline), BOX[mask], int(bm.y), fg)
		return

	draw_rect(Rect2(origin, cell), bg, true)
	var c := origin + cell * 0.5
	var t := maxf(1.0, cell_size * 0.11)
	var half := t * 0.5

	if mask == 0:
		draw_rect(Rect2(c - Vector2(t, t) * 0.75, Vector2(t, t) * 1.5), fg, true)
		return
	if mask & 1:  # north
		draw_rect(Rect2(c.x - half, origin.y, t, c.y + half - origin.y), fg, true)
	if mask & 2:  # south
		draw_rect(Rect2(c.x - half, c.y - half, t, origin.y + cell_size - c.y + half), fg, true)
	if mask & 4:  # west
		draw_rect(Rect2(origin.x, c.y - half, c.x + half - origin.x, t), fg, true)
	if mask & 8:  # east
		draw_rect(Rect2(c.x - half, c.y - half, origin.x + cell_size - c.x + half, t), fg, true)

## Walls only connect to other walls that actually face open space. Without
## this every wall in the solid rock would join up and the whole map would be
## a field of ╬.
func _wall_mask(map: DungeonMap, x: int, y: int) -> int:
	var mask := 0
	if _is_face_wall(map, x, y - 1): mask |= 1
	if _is_face_wall(map, x, y + 1): mask |= 2
	if _is_face_wall(map, x - 1, y): mask |= 4
	if _is_face_wall(map, x + 1, y): mask |= 8
	return mask

func _is_face_wall(map: DungeonMap, x: int, y: int) -> bool:
	if not map.in_bounds(x, y) or map.get_tile(x, y) != Tiles.WALL:
		return false
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			if map.is_walkable(x + dx, y + dy):
				return true
	return false

## Blood under a hurt creature, rather than a tint on it.
##
## Tinting was tried and measured first, and it does not work: pulling every
## wounded thing toward the same red collapses the palette that was built to
## keep them apart. At a mix strong enough to read, a critical wyvern and a
## critical dragon came out deltaE 15.5 under deuteranopia -- one creature.
## Half the tint kept them separable but made bloodied and critical look alike,
## which is the same failure wearing the other hat.
##
## A wash underneath is a channel of its own. The creature keeps every bit of
## its own colour, and the two signals cannot interfere because they are not
## competing for the same property.
##
## Deliberately NOT dimmed by the light map. A monster you can see is a monster
## whose condition you can see -- realism loses to readability here exactly as
## it does for the glyph's own brightness floor.
func _draw_wound(e: Entity) -> void:
	var w := e.wound()
	if w == Entity.Wound.WHOLE:
		return
	var tone := Palette.CRITICAL if w == Entity.Wound.CRITICAL else Palette.BLOODIED
	var alpha := Palette.CRITICAL_WASH if w == Entity.Wound.CRITICAL \
		else Palette.BLOODIED_WASH
	var at := _screen_f(_visual_cell(e))
	draw_rect(Rect2(at, Vector2(cell_size, cell_size)), Color(tone, alpha), true)

func _draw_awareness(e: Entity) -> void:
	var text := ""
	var colour := Palette.SLEEP
	if e.alertness == Entity.Alert.ASLEEP:
		# Cycles z / zZ / zzZ so it reads as breathing rather than a label.
		var phase := int(Time.get_ticks_msec() / 420.0) % 3 if Effects.any() else 1
		text = ["z", "zZ", "zzZ"][phase]
	elif e.alertness == Entity.Alert.SUSPICIOUS:
		text = "?"
		colour = Palette.ALERT
	elif e.fleeing:
		# A creature running away looked exactly like one hunting you, which
		# is the difference between spending three turns chasing and letting
		# it go. Every other state had a mark; this one was simply missed.
		text = "<<"
		colour = Palette.FLEEING
	else:
		return

	var size_px := font_size - 5
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var pos := _screen_f(_visual_cell(e)) + Vector2((cell_size - w) * 0.5, 1.0)
	draw_string(font, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		size_px, Color(0, 0, 0, 0.8))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, colour)

func _centre(cell: Vector2i) -> Vector2:
	return _screen(cell) + Vector2(cell_size, cell_size) * 0.5

func _draw_effects() -> void:
	for e in _effects:
		var t: float = e["t"]
		if t < 0.0:
			continue
		match e["type"]:
			&"shot":  _draw_shot(e, t)
			&"flash": _draw_flash(e, t)
			&"popup": _draw_popup(e, t)
			&"ring":  _draw_ring(e, t)
			&"shove": _draw_shove(e, t)

## A sound, crossing the floor.
##
## Chebyshev distance, not Euclidean, because that is the metric _make_noise
## itself uses to decide who heard it -- so the ring is not an impression of
## the noise footprint, it is exactly the footprint. A square wavefront looks
## odd for about a second and then reads as correct, because it IS what the
## rule does.
##
## Drawn only on cells you can see. A banshee wailing somewhere dark should
## arrive as an arc sweeping in from the edge of your vision, not as a marker
## over its head -- the log line for it is deliberately vague and the picture
## must not be less so.
func _draw_ring(e: Dictionary, t: float) -> void:
	var progress := clampf(t / float(e.get("life", 0.42)), 0.0, 1.0)
	var reach: int = e["radius"]
	var at: Vector2i = e["cell"]
	var edge := progress * float(reach)
	# Louder carries further AND hits harder, so the two scale together.
	var loud := clampf(float(reach) / 10.0, 0.25, 1.0)
	# Fades as it goes, like the sound it is standing in for.
	var alpha := (1.0 - progress) * 0.5 * loud
	if alpha <= 0.005:
		return

	var map := state.map
	var cell := Vector2(cell_size, cell_size)
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var d := float(maxi(absi(dx), absi(dy)))
			# One cell thick, so the wavefront is a line and not a filled disc.
			if absf(d - edge) > 0.5:
				continue
			var c := Vector2i(at.x + dx, at.y + dy)
			if not map.in_bounds(c.x, c.y) or not map.is_visible(c.x, c.y):
				continue
			draw_rect(Rect2(_screen(c), cell), Color(Palette.NOISE, alpha), true)

## The blow that moved you, drawn as a chevron pointing the way you went.
##
## Brad's idea, and better than the impact ring it replaces for one reason: a
## ring says something happened HERE, and the whole point of knockback is that
## it happened in a DIRECTION. The player did not press anything, so the effect
## has to answer "why am I over there" rather than just "something occurred".
##
## Three blocks, on the grid, snapped to whole cells. A chevron drawn at
## fractional positions would slide smoothly between cells and be the one
## moving thing in the game that is not made of blocks.
func _draw_shove(e: Dictionary, t: float) -> void:
	var life: float = e.get("life", SHOVE_LIFE)
	var k := clampf(t / life, 0.0, 1.0)
	var from: Vector2i = e["from"]
	var to: Vector2i = e["to"]
	var dir: Vector2i = e["dir"]
	if dir == Vector2i.ZERO:
		return

	# Travels over the first half, then holds and fades: the shove is a shove,
	# not a fade-in. Snapped per cell so it steps rather than glides.
	var span := maxi(absi(to.x - from.x), absi(to.y - from.y))
	# Clamped to `span` so the point ARRIVES at the player and stops there.
	# Unclamped it ran one cell past, which left the chevron sitting beyond you
	# pointing at empty floor -- the force overtaking the thing it moved.
	var step := int(round(clampf(k / 0.5, 0.0, 1.0) * float(span)))
	var tip := from + dir * mini(step + 1, maxi(span, 1))
	var alpha := 1.0 if k < 0.5 else 1.0 - (k - 0.5) / 0.5
	alpha *= 0.75
	if alpha <= 0.005:
		return

	# The arrowhead: the point, and two wings one cell back to either side.
	var perp := Vector2i(-dir.y, dir.x)
	var marks := [tip, tip - dir + perp, tip - dir - perp]
	var map := state.map
	var cell := Vector2(cell_size, cell_size)
	for m: Vector2i in marks:
		if not map.in_bounds(m.x, m.y) or not map.is_visible(m.x, m.y):
			continue
		draw_rect(Rect2(_screen(m), cell), Color(Palette.SHOVE, alpha), true)

func _draw_shot(e: Dictionary, t: float) -> void:
	var line: Array = e["path"]
	var i := clampi(int(t / SHOT_PER_CELL), 0, line.size() - 1)
	var cell: Vector2i = line[i]
	# Never animate through unseen ground -- a visible arrow from an invisible
	# archer would give away a position the player has not earned.
	if not state.map.is_visible(cell.x, cell.y):
		return
	draw_circle(_centre(cell), maxf(1.5, cell_size * 0.15), Palette.SHOT)

func _draw_flash(e: Dictionary, t: float) -> void:
	var cell: Vector2i = e["cell"]
	if not state.map.is_visible(cell.x, cell.y):
		return
	var origin := _screen(cell)
	var a := (1.0 - t / FLASH_LIFE) * 0.5
	draw_rect(Rect2(origin, Vector2(cell_size, cell_size)), Color(e["colour"], a), true)

func _draw_popup(e: Dictionary, t: float) -> void:
	# Same rule as the projectile: never draw an effect over ground the player
	# cannot see, or an animation gives away a position they have not earned.
	var at: Vector2i = e["cell"]
	if not state.map.is_visible(at.x, at.y):
		return
	var k := t / POPUP_LIFE
	var pos := _centre(at) + Vector2(0, -cell_size * (0.35 + k * 1.1))
	var a := 1.0 if k < 0.55 else 1.0 - (k - 0.55) / 0.45
	var text: String = e["text"]
	var size_px: int = e.get("size", font_size - 3)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	# Drawn twice: a dark backing so a number over a lit floor stays readable.
	draw_string(font, pos - Vector2(w * 0.5 - 1.0, -1.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(0, 0, 0, a * 0.8))
	draw_string(font, pos - Vector2(w * 0.5, 0.0), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, Color(e["colour"], a))

## `strength` above 1 over-drives the tint, which is what keeps materials
## legible once memory has desaturated them.
func _material_tint(m: int, strength: float) -> Color:
	var t: Color = Palette.MATERIAL_TINT[m]
	return Color.WHITE.lerp(t, strength)

## Shifts hue by `tint` while holding the original brightness.
func _tint_keeping_luma(c: Color, tint: Color) -> Color:
	var before := c.get_luminance()
	if before <= 0.001:
		return c
	var out := c * tint
	var after := out.get_luminance()
	if after <= 0.001:
		return c
	return (out * (before / after)).clamp()

## Assigns every cell the phase of the nearest flickering light that reaches it.
func _rebuild_phases() -> void:
	var m := state.map
	if _phase.size() != m.width * m.height:
		_phase.resize(m.width * m.height)
		_phase_w = m.width
	_phase.fill(-1.0)

	var lights: Array = []
	if state.player.light != null and state.player.light.flickers:
		lights.append(state.player.light)
	for src in state.static_lights:
		if src.flickers:
			lights.append(src)
	if lights.is_empty():
		return

	for y in m.height:
		for x in m.width:
			var best := 1 << 30
			var phase := -1.0
			for src in lights:
				var dx: int = x - src.x
				var dy: int = y - src.y
				var d := dx * dx + dy * dy
				if d > src.radius * src.radius or d >= best:
					continue
				best = d
				# Position, so two braziers in one room never gutter together.
				phase = float((src.x * 7 + src.y * 13) % 64) * 0.0982
			_phase[y * _phase_w + x] = phase

## The raw phase for a cell, or -1 where no flickering light reaches. Shared by
## the CPU path and the shader upload so the two can never disagree about which
## cells are under a flame.
func _phase_at(x: int, y: int) -> float:
	if _phase.is_empty():
		return -1.0
	var i := y * _phase_w + x
	if i < 0 or i >= _phase.size():
		return -1.0
	return _phase[i]

## The flicker a particular cell is under, which is its light's, not the
## screen's. Cells no flame reaches are perfectly steady.
func _flicker_at(x: int, y: int) -> float:
	# Only the middle setting runs this. On "full" the shader owns firelight --
	# leaving both would animate every brazier twice -- and on "still" nothing
	# animates at all, which is the entire point of that setting existing.
	if not Effects.timers():
		return 1.0
	if _phase.is_empty():
		return 1.0
	var i := y * _phase_w + x
	if i < 0 or i >= _phase.size():
		return 1.0
	var p := _phase[i]
	if p < 0.0:
		return 1.0
	return 1.0 + sin(_flicker_t * 11.0 + p) * 0.035 \
		+ sin(_flicker_t * 23.7 + p * 2.0) * 0.022 + _flicker_jitter

## Cheap deterministic noise in [0,1) from a cell coordinate.
## Extra brightness at the hot end of the ember ramp, on top of the colour.
## Held well under the lit brazier's own brightness -- a spent brazier that
## looks as alive as a burning one tells the player the opposite of the truth.
const EMBER_GLOW := 0.18

## Hand the shader what each cell is, one texel per cell.
##
## Rebuilt per redraw rather than diffed: 96x54 is five thousand texels, which
## is nothing beside the several hundred draw calls the same frame makes -- and
## it means the texture can never disagree with the map.
func _upload_cells() -> void:
	var map := state.map
	if _cell_img == null or _cell_img.get_width() != map.width \
			or _cell_img.get_height() != map.height:
		_cell_img = Image.create(map.width, map.height, false, Image.FORMAT_RGBA8)
		_cell_tex = ImageTexture.create_from_image(_cell_img)
	for y in map.height:
		for x in map.width:
			# Alpha is VISIBILITY, not opacity. Remembered ground must not
			# animate: a pool of water you are only remembering should be as
			# still as the memory of it.
			var seen := 1.0 if map.is_visible(x, y) else 0.0
			# Blue carries the FIRELIGHT PHASE, and carrying it is what makes
			# the shader equal to the timers it replaced.
			#
			# The CPU flicker was never about brazier tiles: _rebuild_phases
			# gives every cell the phase of the nearest flickering light that
			# reaches it, your torch included, so the whole lit area breathes.
			# A shader that only knew tile ids could animate the brazier and
			# nothing else -- which on screen read as the torch flicker simply
			# disappearing when you switched to "full".
			#
			# Zero means no flame reaches here. Everything else is the phase
			# scaled into the remaining 254 values, so a genuine phase of 0 is
			# never mistaken for "unlit".
			var ph := _phase_at(x, y)
			var blue := 0.0
			if ph >= 0.0:
				blue = (floor(ph / TAU * 253.0) + 1.0) / 255.0
			_cell_img.set_pixel(x, y, Color(
				float(map.get_tile(x, y)) / 255.0,
				_hash01(x, y),
				blue,
				seen))
	_cell_tex.update(_cell_img)
	var m := material as ShaderMaterial
	if m == null:
		return
	m.set_shader_parameter("cell_data", _cell_tex)
	m.set_shader_parameter("control_origin", global_position)
	m.set_shader_parameter("camera_cell", _camera_visual)
	m.set_shader_parameter("cell_size", float(cell_size))
	m.set_shader_parameter("map_size", Vector2(map.width, map.height))
	m.set_shader_parameter("t", anim_time if anim_time >= 0.0 else Time.get_ticks_msec() / 1000.0)
	m.set_shader_parameter("strength", anim_strength)
	m.set_shader_parameter("steps", anim_steps)

## Overridable clock, so a screenshot tool can step the animation. Negative
## means "use the wall clock", which is what play does.
var anim_time: float = -1.0

## Follow the player's effects setting.
##
## The shader material is attached and detached rather than left on with the
## animation zeroed, so "still" and "simple" cost exactly what they always did
## -- somebody who turns motion off for accessibility reasons should not still
## be paying for a shader pass.
func apply_effects_mode() -> void:
	block_anim = Effects.shaders()
	if block_anim:
		if material == null:
			var m := ShaderMaterial.new()
			m.shader = load(ANIM_SHADER)
			material = m
	else:
		material = null
	queue_redraw()

const ANIM_SHADER := "res://src/render/shaders/block_anim.gdshader"

## How brightly remembered ground is drawn on this floor.
##
## One outside the cave band, dimmer inside it, and nothing at all on the
## corrupted climb. Staircases are exempt from all of it -- they are handled
## before this is reached -- so however dark the floor becomes, the way on and
## the way out still show.
func _memory_strength() -> float:
	if state == null:
		return 1.0
	var eff := state.effective_depth()
	if not Bands.is_caves(eff):
		return 1.0
	return 0.0 if Bands.is_corrupted(eff) else CAVE_MEMORY

## Remembered cave ground, as a fraction of ordinary remembered ground.
const CAVE_MEMORY := 0.45

func _hash01(x: int, y: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663)
	return float(absi(h) % 1024) / 1024.0

func _remembered(c: Color) -> Color:
	var m := c.lerp(Palette.MEMORY, Palette.MEMORY_MIX)
	return Color(m.r * Palette.MEMORY_DIM, m.g * Palette.MEMORY_DIM, m.b * Palette.MEMORY_DIM, 1.0)

func _draw_glyph(id: StringName, cell: Vector2) -> void:
	_draw_glyph_tinted(id, cell, Color(0, 0, 0, 0))

## The same draw, with an optional colour that replaces the theme's own.
##
## Alpha zero means "use the theme", so the ordinary path is unchanged and
## there is one drawing routine rather than two that can drift apart.
func _draw_glyph_tinted(id: StringName, cell: Vector2, tint: Color) -> void:
	var app := render_theme.appearance(id)
	var fg: Color = tint if tint.a > 0.0 else app["fg"]
	# Lighting is sampled at the logical cell, not the fractional one -- a
	# glyph mid-stride should not flicker between two rooms' light levels.
	var x := int(round(cell.x))
	var y := int(round(cell.y))
	var lit: Color = state.light_map.get_light(x, y) * _flicker_at(x, y)
	# Floor of 0.45 so something standing in gloom is still legible. Realism
	# loses to readability every time in a game you play by reading.
	fg = (fg * lit.lerp(Color.WHITE, 0.45)).clamp()
	var origin := _screen_f(cell)
	var am := _metrics(app["ch"])
	draw_char(font, origin + Vector2(am.x, _baseline(app["ch"], int(am.y))), app["ch"], int(am.y), fg)

func _draw_preview() -> void:
	if _preview.is_empty() or state.game_over:
		return
	if state.map.in_bounds(look_cursor.x, look_cursor.y):
		return
	if state.map.in_bounds(aim_cursor.x, aim_cursor.y):
		return
	var r := cell_size * 0.16
	for cell in _preview:
		draw_circle(_centre(cell), r, Color(Palette.PATH_HINT, 0.55))

func _draw_aim() -> void:
	if not state.map.in_bounds(aim_cursor.x, aim_cursor.y):
		return
	var tint := Palette.AIM_OK if aim_valid else Palette.AIM_BLOCKED
	var r := cell_size * 0.13
	for cell in aim_line:
		if cell == aim_cursor:
			continue
		draw_circle(_centre(cell), r, Color(tint, 0.75))

	# A reticle rather than the plain hover box, so aiming never looks like
	# hovering.
	var o := _screen(aim_cursor)
	var c := Vector2(cell_size, cell_size)
	draw_rect(Rect2(o, c), Color(tint, 0.16), true)
	draw_rect(Rect2(o, c), tint, false, 2.0)
	var arm := cell_size * 0.30
	draw_line(o + Vector2(c.x * 0.5, -arm * 0.6), o + Vector2(c.x * 0.5, arm * 0.2), tint, 1.5)
	draw_line(o + Vector2(c.x * 0.5, c.y + arm * 0.6), o + Vector2(c.x * 0.5, c.y - arm * 0.2), tint, 1.5)

func _draw_cursor() -> void:
	var cell := Vector2(cell_size, cell_size)
	if state.map.in_bounds(aim_cursor.x, aim_cursor.y):
		return
	if state.map.in_bounds(look_cursor.x, look_cursor.y):
		var lo := _screen(look_cursor)
		draw_rect(Rect2(lo, cell), Color(Palette.CURSOR, 0.14), true)
		draw_rect(Rect2(lo, cell), Palette.CURSOR, false, 2.0)
		return
	if not state.map.in_bounds(_hover.x, _hover.y):
		return
	draw_rect(Rect2(_screen(_hover), cell), Color(Palette.CURSOR, 0.85), false, 1.0)
