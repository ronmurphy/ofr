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
var _flicker := 1.0
var _flicker_accum := 0.0

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

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if font == null:
		font = load("res://assets/fonts/JetBrainsMono-Regular.ttf")
	_measure_font()
	set_process(true)

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

## Centres a character in its cell by its own width. Cached: this is called
## once per visible cell per frame, and measuring text is not free.
func _dx(ch: String) -> float:
	if _dx_cache.has(ch):
		return _dx_cache[ch]
	var w := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var dx := (cell_size - w) * 0.5
	_dx_cache[ch] = dx
	return dx

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
	if animating:
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
		var t := Time.get_ticks_msec() / 1000.0
		_flicker = 1.0 + sin(t * 11.0) * 0.035 + sin(t * 23.7) * 0.022 + randf_range(-0.02, 0.02)

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

func _expired(e: Dictionary) -> bool:
	match e["type"]:
		&"shot":  return e["t"] >= e["path"].size() * SHOT_PER_CELL
		&"flash": return e["t"] >= FLASH_LIFE
		&"popup": return e["t"] >= POPUP_LIFE
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

	var tint := _material_tint(map.material_at(x, y), 1.0)

	if visible_here:
		var lit: Color = state.light_map.get_light(x, y) * _flicker
		fg = (fg * tint * lit).clamp()
		bg = (bg * tint * lit).clamp()
	elif tile == Tiles.STAIRS_DOWN:
		# Exempt from memory dimming, and breathing gently so the eye finds it
		# on a large map.
		var pulse := 0.78 + 0.22 * sin(Time.get_ticks_msec() / 620.0)
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
		draw_char(font, origin + Vector2(_dx(ch), _glyph_baseline), ch, font_size, fg)

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
		draw_char(font, origin + Vector2(_dx(BOX[mask]), _glyph_baseline), BOX[mask], font_size, fg)
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

func _draw_awareness(e: Entity) -> void:
	var text := ""
	var colour := Palette.SLEEP
	if e.alertness == Entity.Alert.ASLEEP:
		# Cycles z / zZ / zzZ so it reads as breathing rather than a label.
		var phase := int(Time.get_ticks_msec() / 420.0) % 3
		text = ["z", "zZ", "zzZ"][phase]
	elif e.alertness == Entity.Alert.SUSPICIOUS:
		text = "?"
		colour = Palette.ALERT
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

## Cheap deterministic noise in [0,1) from a cell coordinate.
func _hash01(x: int, y: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663)
	return float(absi(h) % 1024) / 1024.0

func _remembered(c: Color) -> Color:
	var m := c.lerp(Palette.MEMORY, Palette.MEMORY_MIX)
	return Color(m.r * Palette.MEMORY_DIM, m.g * Palette.MEMORY_DIM, m.b * Palette.MEMORY_DIM, 1.0)

func _draw_glyph(id: StringName, cell: Vector2) -> void:
	var app := render_theme.appearance(id)
	var fg: Color = app["fg"]
	# Lighting is sampled at the logical cell, not the fractional one -- a
	# glyph mid-stride should not flicker between two rooms' light levels.
	var x := int(round(cell.x))
	var y := int(round(cell.y))
	var lit: Color = state.light_map.get_light(x, y) * _flicker
	# Floor of 0.45 so something standing in gloom is still legible. Realism
	# loses to readability every time in a game you play by reading.
	fg = (fg * lit.lerp(Color.WHITE, 0.45)).clamp()
	var origin := _screen_f(cell)
	draw_char(font, origin + Vector2(_dx(app["ch"]), _glyph_baseline), app["ch"], font_size, fg)

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
