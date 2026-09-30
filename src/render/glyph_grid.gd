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
## Every cell the current shot or throw could reach, tinted faintly while
## aiming. Set by main.gd; empty when not aiming. See GameState.reach_cells.
var reach_cells: Array[Vector2i] = []
var _hover := Vector2i(-1, -1)
var _preview: Array[Vector2i] = []
var _glyph_dx := 0.0
var _glyph_baseline := 0.0
## Torch flicker lives in the renderer, NOT in the simulation. The sim must
## stay deterministic and turn-driven; flicker is a per-frame visual.
##
## Which flickering light owns each cell, as a phase offset -- and now which
## fungus, too. The flicker used to be one number multiplying every lit cell on
## screen, so a brazier on the far side of the map guttered in perfect time with
## your torch. That reads as the whole screen breathing rather than as flames
## burning, and it is why several independent rhythms look so much more alive
## than one. See LivingLight, shared with the 3D view (main.gd hands both views
## the same one), as is MapMemory: how long ago each cell was last seen.
var light := LivingLight.new()
var memory := MapMemory.new()
## Spores, drips, bubbles and dust, also shared -- see SmallLife.
var life := SmallLife.new()
## This floor's colour by region, fetched once a draw -- see RegionLook.
var _region: RegionLook

## The effects in flight and the step glides, shared with the 3D view: see
## Fx and StepMotion, where the rules and their reasons now live. main.gd hands
## both views the same two objects.
var fx := Fx.new()
var motion := StepMotion.new()
## The names the capture tool and the test suite still reach in by, kept
## working: they forward to the shared objects rather than copying them.
var _effects: Array:
	get: return fx.list
var hold_effects: bool:
	get: return fx.hold
	set(value): fx.hold = value
var _motion: Dictionary:
	get: return motion._motion
## Guards against an animation outliving the level it belongs to. Descending
## mid-flight would otherwise draw the old level's arrow on the new one.
var _last_map: DungeonMap = null
## Top-left map cell currently shown.
var _origin := Vector2i.ZERO
## Where the camera is actually drawn, which lags the logical origin so the map
## glides instead of jumping a whole cell mid-stride.
var _camera_visual := Vector2.ZERO

const STEP_TIME := StepMotion.STEP_TIME
## sound_deck.gd keeps its own copy of this, timed to land with the picture.
const SHOT_PER_CELL := Fx.SHOT_PER_CELL

## False for a grid that is only scenery -- the title screen's backdrop. Read
## in _ready, because _ready is where the mouse is claimed, and setting
## mouse_filter from outside was undone whenever _ready ran after it.
var takes_mouse := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if takes_mouse \
		else Control.MOUSE_FILTER_IGNORE
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
	# duplicate() first. load() hands back ONE shared instance per path, so
	# setting fallbacks here also mutated the very object Sidebar.ui_font()
	# builds from -- and the two wire each other in OPPOSITE directions: icons
	# -> text here, text -> icons there. Once both were alive in the scene at
	# the same time that was a loop, and Godot refuses a cyclic chain outright
	# ("Cyclic font fallback" at font.cpp:186). The refusal is a no-op, not a
	# crash, so whichever of the two ran SECOND silently ended up with no
	# fallback at all -- this one losing it is the invisible brazier again.
	#
	# The suite cannot see this: it drops each font as soon as it checks it, and
	# a freed font means the next load() is a fresh instance with nothing to
	# collide with. Only a running game holds both at once. A private copy costs
	# nothing (PackedByteArray is copy-on-write) and cannot collide with anyone.
	var icons: FontFile = load("res://assets/fonts/ofr_icons.ttf").duplicate()
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

## Takes the player's chosen text size. Both numbers move together -- see
## RenderTheme.font_size_for() for why the ratio between them is fixed.
##
## Called at launch as well as on the key, for the same reason
## apply_effects_mode() is: a size chosen last session has to be in force before
## the first frame is drawn, not only once the player presses something.
func apply_text_size() -> void:
	cell_size = RenderTheme.cell_size()
	font_size = RenderTheme.font_size()
	_measure_font()
	queue_redraw()

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
	motion.tick(delta)
	var target := Vector2(_origin)
	if _camera_visual.distance_squared_to(target) > 0.0004:
		_camera_visual = _camera_visual.lerp(target, clampf(delta / STEP_TIME, 0.0, 1.0))
	else:
		_camera_visual = target

	var animating := fx.running() or _motion_running()
	fx.tick(delta)

	# Flicker refreshes at ~15Hz rather than every frame -- see LivingLight.
	# Effects, when running, redraw at full rate.
	var flicker_due := light.tick(delta)

	if animating or flicker_due:
		queue_redraw()

## Turns simulation events into animations -- see Fx.add_events, shared with
## the 3D view. The outcome is already decided by the time this runs.
func play_events(evts: Array) -> void:
	fx.play(evts, font_size, state, motion)
	if fx.running():
		queue_redraw()

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

## Everything still in flight completes at once -- see StepMotion.settle.
func settle_motion() -> void:
	motion.settle()

## Starts a glide for anything that has moved since we last looked.
func sync_motion() -> void:
	if state == null:
		return
	light.rebuild(state)
	memory.update(state)
	life.rebuild(state)
	# Whoever just stepped into water, mud, rubble or bones throws some of it up.
	fx.footfalls(motion.sync(state.entities, state.map), state)

func set_aim_state(cursor: Vector2i, line: Array[Vector2i], valid: bool) -> void:
	aim_cursor = cursor
	aim_line = line
	aim_valid = valid
	queue_redraw()

## Where a creature is drawn: its glide, and for the trader on "full", their
## idling -- SmallLife.idle_offset, shared with the 3D view.
func _visual_cell(e: Entity) -> Vector2:
	var at := motion.visual_cell(e)
	if e == state.trader:
		at += life.idle_offset(e, motion.visual_cell(state.player),
			anim_time if anim_time >= 0.0 else Time.get_ticks_msec() / 1000.0)
	return at

func _motion_running() -> bool:
	return motion.running() or _camera_visual.distance_squared_to(Vector2(_origin)) > 0.0004

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
		fx.watch_map(map)
		_preview.clear()
		# A new level should not inherit the old one's scroll position.
		centre_on_player()
	_update_camera()
	memory.update(state)
	_region = RegionLook.for_depth(state.effective_depth())

	if block_anim:
		_upload_cells()

	# The dark around the map is the region's dark.
	draw_rect(Rect2(Vector2.ZERO, size), _region.backdrop, true)

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

	# The miasma's cloud, over the floor, where you can see it. Information,
	# so on every effects setting -- steady, like the torch's shading.
	for c in state.miasma_cloud():
		if c.x >= x0 and c.x < x1 and c.y >= y0 and c.y < y1 \
				and map.is_visible(c.x, c.y) and map.get_tile(c.x, c.y) != Tiles.FUNGUS_PURPLE:
			draw_rect(Rect2(_screen(c), Vector2(cell_size, cell_size)), Palette.MIASMA, true)

	# Bodies under everything that stands: the dead lie on the floor.
	_draw_bodies()

	# Ground items sit under actors, so a monster standing on loot still reads
	# as the thing you need to deal with first.
	for it in state.ground:
		if map.is_visible(it.x, it.y):
			# Enchanted gear is tinted rather than given its own glyph: ")" is the
			# roguelike's mark for a melee weapon and splitting it would invent
			# notation the genre already settled. Colour is the free channel.
			#
			# NOT gems. A gem carries an element as base catalogue data -- that
			# is what it IS -- so the naive test caught every one and painted
			# them MAGIC blue, taking away the near-white that nothing else in
			# the game uses. A gem is not an enchanted item, it is the thing you
			# bind, and collapsing the two costs exactly the discrimination the
			# palette was built to give. `item.gd:565` already guards the name
			# suffix the same way; this is that guard, in the place it was
			# missed.
			#
			# Both kinds get the blue glow UNDER them, though -- see
			# LivingLight.item_glow. It marks magic lying there without taking
			# the gem's own colour away.
			var glow := LivingLight.item_glow(it)
			if glow.a > 0.0:
				draw_rect(Rect2(_screen(Vector2i(it.x, it.y)), Vector2(cell_size, cell_size)),
					glow, true)
			if it.shows_enchanted():
				_draw_glyph_tinted(it.appearance, Vector2(it.x, it.y), Palette.MAGIC)
			else:
				_draw_glyph(it.appearance, Vector2(it.x, it.y))

	# The trader, remembered where you saw them -- see MapMemory. Out of sight
	# only: in sight, the trader below is the real one.
	var trader := memory.trader_cell
	if trader.x >= 0 and not map.is_visible(trader.x, trader.y) \
			and _memory_strength() > 0.0:
		_draw_glyph_tinted(&"trader", Vector2(trader), MapMemory.trader_colour(), false)

	# Small life, under the creatures, which stand in front of it.
	_draw_small_life()

	for e in state.entities:
		if e.alive and not e.is_player and map.is_visible(e.x, e.y):
			_draw_wound(e)
			# Marked: a frame in the colour of the fungus it carries.
			var spore := CreatureMarks.spore_colour(e)
			if spore.a > 0.0:
				draw_rect(Rect2(_screen_f(_visual_cell(e)) + Vector2(1, 1),
					Vector2(cell_size - 2, cell_size - 2)), spore, false, 2.0)
			# The glyph still says WHICH creature; the colour only says that
			# the climb has been at it. One override rather than a second set
			# of theme entries, because there is nothing per-creature to say.
			if e.corrupted:
				_draw_glyph_tinted(e.appearance, _visual_cell(e), Palette.CORRUPTED)
			elif e.faction == Entity.Faction.PLAYER:
				# The same bargain the ratted player strikes below: the glyph
				# says WHAT it is, the colour says whose it is. A troll dug up
				# with the shovel keeps the troll's shape, because knowing you
				# have a troll is the whole point of having raised one -- and
				# without the tint it would be indistinguishable from the troll
				# about to hit you.
				_draw_glyph_tinted(e.appearance, _visual_cell(e), Palette.ALLY)
			else:
				_draw_glyph(e.appearance, _visual_cell(e))
	if state.player.alive:
		# A rat in the player's own colour. There is no hollow rodent in the
		# font, and there does not need to be: the glyph says WHAT you look
		# like and the colour says it is still you. Measured at 39 deltaE
		# against the rat's brown under all four vision models, so the two can
		# never be confused.
		if state.ratted():
			_draw_glyph_tinted(&"rat", _visual_cell(state.player), Palette.PLAYER)
		else:
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
		# This is the twenty-turn forging window, drawn instead of counted --
		# see LivingLight.embers, which the 3D view draws too. Only while the
		# cell is actually in sight: how hot a brazier still is across the
		# level is not something memory could honestly know.
		elif tile == Tiles.BRAZIER_SPENT and visible_here:
			var heat := state.ember_heat(x, y)
			if heat > 0.0:
				fg = LivingLight.embers(fg, heat, x, y)
				bg = bg.lerp(Palette.EMBERS_BG, heat)

	var tint := _material_tint(map.material_at(x, y), 1.0)

	if visible_here:
		var lit: Color = state.light_map.get_light(x, y) * _flicker_at(x, y)
		# Stone takes the region's colour, brightness kept. The floor keeps
		# its own, because everything that matters lies on it -- see
		# RegionLook for what was measured.
		if RegionLook.is_stone(tile):
			fg = _region.shift(fg)
			bg = _region.shift(bg)
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
		# Still, but not dim, with motion off -- see LivingLight.stairs_pulse.
		var pulse := LivingLight.stairs_pulse()
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
		#
		# And it fades with time: ground you have not seen for a hundred turns
		# starts to go, down to half by five hundred, never below. Landmarks
		# are kept -- see MapMemory.
		var recall := _memory_strength() * memory.fade(x, y, state.turns)
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
	var t := maxf(_thinnest_visible(), cell_size * 0.11)
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

## The thinnest stroke that still lands on a whole pixel of the actual screen.
##
## The floor on wall thickness used to be a flat 1.0, which is one pixel of the
## 1600x900 canvas rather than one pixel of the display. The canvas stretches to
## fit, so a Steam Deck at 1280x800 scales it by 0.8 and that floor arrived as
## 0.8 of a real pixel -- a grey smear instead of a line, and inconsistent from
## one wall to the next depending on where it fell.
##
## Only a screen smaller than the canvas scales below 1.0, which is why this was
## invisible on every desktop it was ever looked at.
func _thinnest_visible() -> float:
	var vp := get_viewport()
	if vp == null:
		return 1.0
	var logical := vp.get_visible_rect().size
	if logical.x <= 0.0 or logical.y <= 0.0:
		return 1.0
	var real := Vector2(DisplayServer.window_get_size())
	var scale := minf(real.x / logical.x, real.y / logical.y)
	if scale <= 0.0:
		return 1.0
	return maxf(1.0, 1.0 / scale)

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
	var wash := CreatureMarks.wound(e)
	if wash.a <= 0.0:
		return
	var at := _screen_f(_visual_cell(e))
	draw_rect(Rect2(at, Vector2(cell_size, cell_size)), wash, true)

func _draw_awareness(e: Entity) -> void:
	var mark := CreatureMarks.awareness(e)
	if mark.is_empty():
		return
	var text: String = mark["text"]
	var colour: Color = mark["colour"]
	var size_px := font_size - 5
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var pos := _screen_f(_visual_cell(e)) + Vector2((cell_size - w) * 0.5, 1.0)
	draw_string(font, pos + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		size_px, Color(0, 0, 0, 0.8))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, colour)

func _centre(cell: Vector2i) -> Vector2:
	return _screen(cell) + Vector2(cell_size, cell_size) * 0.5

func _draw_effects() -> void:
	for e in fx.list:
		var t: float = e["t"]
		if t < 0.0:
			continue
		match e["type"]:
			&"shot":  _draw_shot(e, t)
			&"flash": _draw_flash(e, t)
			&"popup": _draw_popup(e, t)
			&"ring":  _draw_ring(e, t)
			&"shove": _draw_shove(e, t)
			&"sparks": _draw_burst(e, t)
			&"contact": _draw_contact(e, t)
			&"shatter": _draw_shatter(e, t)

## A sound, crossing the floor -- which cells, and how strongly, is
## Fx.ring_cells; this only paints them.
func _draw_ring(e: Dictionary, t: float) -> void:
	var cell := Vector2(cell_size, cell_size)
	# A noise ring's colour unless it carries its own: the light of a level,
	# or a shrine answering a prayer.
	var colour: Color = e.get("colour", Palette.NOISE)
	for hit in Fx.ring_cells(e, t, state.map):
		draw_rect(Rect2(_screen(hit[0]), cell), Color(colour, hit[1]), true)

## The blow that moved you, as a chevron of whole cells -- see Fx.shove_cells.
## Snapped to the grid on purpose: a chevron sliding smoothly between cells
## would be the one moving thing in the game that is not made of blocks.
func _draw_shove(e: Dictionary, t: float) -> void:
	var cell := Vector2(cell_size, cell_size)
	for hit in Fx.shove_cells(e, t, state.map):
		draw_rect(Rect2(_screen(hit[0]), cell), Color(Palette.SHOVE, hit[1]), true)

## Cell by cell, never between: see Fx.shot_cell, which also hides the shot
## over ground you cannot see.
func _draw_shot(e: Dictionary, t: float) -> void:
	var cell := Fx.shot_cell(e, t, state.map)
	if cell.x < 0:
		return
	draw_circle(_centre(cell), maxf(1.5, cell_size * 0.15), Palette.SHOT)

## Sparks and shards -- see Fx.burst_points -- laid on the grid: each piece
## snapped to a quarter of a cell, so a burst reads as blocks breaking rather
## than as smooth particles in a game made of blocks.
func _draw_burst(e: Dictionary, t: float) -> void:
	var q := cell_size * 0.25
	var colour: Color = e["colour"]
	for piece in Fx.burst_points(e, t, state.map):
		var at := _centre(e["cell"]) + (piece[0] as Vector2) * cell_size \
			- Vector2(0.0, (float(piece[1]) - 0.45) * cell_size)
		at = (at / q).floor() * q
		draw_rect(Rect2(at, Vector2(q, q)), Color(colour, float(piece[2])), true)

## Weapon-shaped contact marks, using the shared slash, thrust or blunt layout.
## Small blocks keep the cue legible without changing the ASCII glyphs.
func _draw_contact(e: Dictionary, t: float) -> void:
	var side := maxf(2.0, cell_size * Fx.CONTACT_BLOCK)
	var cell := _centre(e["cell"])
	var colour: Color = e["colour"]
	for mark in Fx.contact_marks(e, t, state.map):
		var at := cell + (mark[0] as Vector2) * cell_size - Vector2(side, side) * 0.5
		draw_rect(Rect2(at, Vector2(side, side)), Color(colour, float(mark[1])), true)

## Spores, bubbles, drips and dust -- which, where and when is SmallLife; this
## only paints them. Blocks an eighth of a cell across, on an eighth-cell grid,
## so they stay part of the block look rather than floating over it; height
## above the floor is drawn as distance up the screen.
func _draw_small_life() -> void:
	var e8 := cell_size * 0.125
	var t := anim_time if anim_time >= 0.0 else Time.get_ticks_msec() / 1000.0
	for m in life.motes(t):
		var at := _screen_f(m[0]) - Vector2(0.0, float(m[1]) * 0.6 * cell_size)
		var side := maxf(e8, snappedf(float(m[3]) * cell_size, e8))
		var corner := ((at - Vector2(side, side) * 0.5) / e8).floor() * e8
		draw_rect(Rect2(corner, Vector2(side, side)), m[2], true)

## A creature breaking apart: its picture fades as its shards fly.
func _draw_shatter(e: Dictionary, t: float) -> void:
	var at: Vector2i = e["cell"]
	var ghost := Fx.shatter_ghost(e, t)
	if ghost > 0.0 and state.map.is_visible(at.x, at.y):
		var app := render_theme.appearance(e["appearance"])
		var m := _metrics(app["ch"])
		draw_char(font, _screen(at) + Vector2(m.x, _baseline(app["ch"], int(m.y))),
			app["ch"], int(m.y), Color(e["colour"], ghost))
	_draw_burst(e, t)

func _draw_flash(e: Dictionary, t: float) -> void:
	var a := Fx.flash_alpha(e, t, state.map)
	if a <= 0.0:
		return
	draw_rect(Rect2(_screen(e["cell"]), Vector2(cell_size, cell_size)),
		Color(e["colour"], a), true)

func _draw_popup(e: Dictionary, t: float) -> void:
	var at: Vector2i = e["cell"]
	if not state.map.is_visible(at.x, at.y):
		return
	var shape := Fx.popup_state(e, t, state.map)
	var pos := _centre(at) + Vector2(0, -cell_size * float(shape[0]))
	var a: float = shape[1]
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

## Shifts hue by `tint` while holding the original brightness -- the same
## shift the regions use, so it lives with them in RegionLook.
func _tint_keeping_luma(c: Color, tint: Color) -> Color:
	return RegionLook.keep_luma(c, tint)

## The flicker a particular cell is under, which is its light's, not the
## screen's -- see LivingLight.pulse. Cells no flame reaches are perfectly
## steady; cells only fungus lights breathe slowly.
func _flicker_at(x: int, y: int) -> float:
	# Only the middle setting runs this. On "full" the shader owns firelight --
	# leaving both would animate every brazier twice -- and on "still" nothing
	# animates at all, which is the entire point of that setting existing.
	if not Effects.timers():
		return 1.0
	return light.pulse(x, y)

## Hand the shader what each cell is, one texel per cell: LivingLight's two
## textures, which it rebuilds only when a turn or the floor has changed.
func _upload_cells() -> void:
	var map := state.map
	light.upload(state, memory)
	var m := material as ShaderMaterial
	if m == null:
		return
	m.set_shader_parameter("cell_data", light.cells)
	m.set_shader_parameter("cell_extra", light.extra)
	# No origin is sent any more. The shader reads its own local position out of
	# the vertex stage, which is the space this control draws in -- see the
	# comment above `varying local_px`. Passing global_position was the bug:
	# it is in stretch space and the shader was comparing it against real
	# framebuffer pixels, which only agree at exactly 1600x900.
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
	return MapMemory.strength_for(state.effective_depth())

## Remembered cave ground, as a fraction of ordinary remembered ground.
const CAVE_MEMORY := 0.45

## Cheap deterministic noise in [0,1) from a cell coordinate.
func _hash01(x: int, y: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663)
	return float(absi(h) % 1024) / 1024.0

func _remembered(c: Color) -> Color:
	var m := c.lerp(Palette.MEMORY, Palette.MEMORY_MIX)
	return Color(m.r * Palette.MEMORY_DIM, m.g * Palette.MEMORY_DIM, m.b * Palette.MEMORY_DIM, 1.0)

## The dead, each its own glyph turned on its side, lit like anything else on
## the floor and rotting through BodyLook. Only where you can see: a body is
## not a landmark, and memory does not keep it.
func _draw_bodies() -> void:
	for b in state.bodies:
		var x: int = int(b["x"])
		var y: int = int(b["y"])
		var age: int = state.turns - int(b["turn"])
		if not BodyLook.showing(age) or not state.map.is_visible(x, y):
			continue
		var app := render_theme.appearance(StringName(b["app"]))
		var ch: String = app["ch"]
		var fg: Color = Palette.CORRUPTED if bool(b.get("corrupted", false)) else app["fg"]
		var col := BodyLook.colour(fg, age)
		var light_here: Color = state.light_map.get_light(x, y) * _flicker_at(x, y)
		col = Color((col * light_here.lerp(Color.WHITE, 0.45)).clamp(), col.a)
		var am := _metrics(ch)
		var half := Vector2(cell_size, cell_size) * 0.5
		draw_set_transform(_screen_f(Vector2(x, y)) + half, PI * 0.5)
		draw_char(font, -half + Vector2(am.x, _baseline(ch, int(am.y))), ch, int(am.y), col)
		draw_set_transform(Vector2.ZERO, 0.0)

func _draw_glyph(id: StringName, cell: Vector2) -> void:
	_draw_glyph_tinted(id, cell, Color(0, 0, 0, 0))

## The same draw, with an optional colour that replaces the theme's own.
##
## Alpha zero means "use the theme", so the ordinary path is unchanged and
## there is one drawing routine rather than two that can drift apart. `lit`
## false draws the colour exactly as given: a remembered picture, which the
## light in that room now has nothing to do with.
func _draw_glyph_tinted(id: StringName, cell: Vector2, tint: Color, lit := true) -> void:
	var app := render_theme.appearance(id)
	var fg: Color = tint if tint.a > 0.0 else app["fg"]
	if lit:
		# Lighting is sampled at the logical cell, not the fractional one -- a
		# glyph mid-stride should not flicker between two rooms' light levels.
		var x := int(round(cell.x))
		var y := int(round(cell.y))
		var light_here: Color = state.light_map.get_light(x, y) * _flicker_at(x, y)
		# Floor of 0.45 so something standing in gloom is still legible.
		# Realism loses to readability every time in a game you play by reading.
		fg = (fg * light_here.lerp(Color.WHITE, 0.45)).clamp()
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
	# Every cell in reach, faint, under the line and the reticle.
	var box := Vector2(cell_size, cell_size)
	for cell in reach_cells:
		draw_rect(Rect2(_screen(cell), box), Color(Palette.AIM_OK, 0.14), true)
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
