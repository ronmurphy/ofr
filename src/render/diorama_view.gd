class_name DioramaView
extends Control

## A 3D presentation of the same DungeonMap used by GlyphGrid.
##
## The world is still a grid of map cells. This view only changes how those
## cells are presented: blocks for masonry, coloured ground, and the existing
## icon-font pictures on camera-facing Label3D billboards. No simulation code
## or coordinates are changed when the camera turns.
##
## ONE LIGHT. The simulation's light map is the only light here, uploaded as a
## texture the surface shader blends between cells (see _build_cell_light).
## Billboards are sized in cells by BillboardSizes, not by the text size.

signal cell_clicked(cell: Vector2i)
signal cell_right_clicked(cell: Vector2i)

const CELL := 1.0
const WALL_HEIGHT := 1.35
## How much of the map the camera frames at the default text size. The pause
## menu's text size is a zoom in this view: larger text frames fewer cells, and
## every billboard keeps its size in cells, so proportions never change.
const CAMERA_SIZE := 26.0
const BASE_TEXT_SIZE := 18.0
## FINAL FANTASY TACTICS' VIEW. The camera starts turned 45 degrees from the
## grid, so every floor square is a diamond, and looks down at a shallow 32
## degrees. Low walls hide more at this angle -- which is what the silhouettes
## are for (see _add_silhouette).
##
## It turns 45 degrees a press, so EIGHT views alternate between the diamond
## and the grid seen straight on. Brad, 2026-09-27: the diamond is the look,
## but "sometimes you need the not-angled view for navigation". The key mapping
## (view_to_grid) already works at any angle: in a straight view each arrow
## walks exactly where it points, in a diamond view it keeps FFT's rule.
const CAMERA_YAW := PI / 4.0
const TURN_STEP := PI / 4.0
const VIEWS := 8
const CAMERA_PITCH_DEG := 32.0
## The overhead view's pitch (Brad, 2026-10-01): nearly straight down, with
## a sliver of every wall's lit face left showing, so a room still reads as
## a place and not only as a map. The cards are billboards, so from here
## they lie all but flat, like the classic view's glyphs -- see _overhead_lift.
const CAMERA_PITCH_OVERHEAD_DEG := 80.0
## How far above the top of a wall an overhead card hangs -- see overhead_lift.
const OVERHEAD_CLEAR := 0.05
const CAMERA_DISTANCE := 25.0
## Grid steps a key can map to: the four along the grid lines, and the four
## diagonals, for the diagonal keys.
const AXES: Array[Vector2i] = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const DIAGONALS: Array[Vector2i] = [Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(-1, -1)]
const TURN_TIME := 0.18
## Short (the UI review, 2026-10-01): the strip over the map used to spell
## out every key, every turn. It now says which view this is and how to leave
## it; the keys are one press away under ?, and the HERE box teaches the rest.
## The two blanks are this view's name and the next one Q gives (hint_text).
const FOLLOW_HINT := "%s · camera follows you     Q / d-pad up: %s     ? keys"
const DIORAMA_HINT := "%s     [ / ] or right stick: turn     Q / d-pad up: %s     ? keys"
const SURFACE_SHADER: Shader = preload("res://src/render/shaders/diorama_surface.gdshader")
const POST_SHADER: Shader = preload("res://src/render/shaders/diorama_post.gdshader")

## THE 3D LOOK (2026-10-01, from the canvas). The sim's light list becomes
## real OmniLight3Ds so faces brighten toward the fire and blocks cast
## shadows; the surface shader keeps the light map as emission at MAP_WEIGHT
## and masks the lights by what is seen. The Compatibility renderer (the web)
## lights at most LIGHT_CAP per mesh, and every wall on the floor is one
## mesh, so the nearest LIGHT_CAP sources to the player get a light, the
## nearest SHADOW_CAP of those a shadow. Forward+ (a PC, Brad's two tiers)
## has no such cap and gets the extras in _apply_tier.
const LIGHT_CAP := 8
const SHADOW_CAP := 4
const MAP_WEIGHT := 0.55
const LIGHT_ENERGY := 1.4
## How far a sim radius reaches as an engine light: a little past it, so the
## directional light fades out before the sim's reach ends.
const RANGE_PER_CELL := 1.15
## A dark strip along the foot of every wall, the way corners catch no light.
## Baked, because screen-space occlusion is not in the Compatibility renderer.
const AO_DEPTH := 0.32
const AO_ALPHA := 0.55
## Embers off every lit brazier in view, on "simple" and "full".
const EMBERS_PER_BRAZIER := 14
const ASCII_GROUND_TILES := [
	Tiles.FLOOR, Tiles.DOOR_OPEN, Tiles.STAIRS_DOWN, Tiles.STAIRS_UP,
	Tiles.CAVE_FLOOR, Tiles.RUBBLE, Tiles.WATER, Tiles.MUD, Tiles.BONES,
	Tiles.FUNGUS, Tiles.PIT, Tiles.TRAP, Tiles.SHRINE, Tiles.GRAVE,
	Tiles.FUNGUS_PURPLE, Tiles.FUNGUS_RED,
]
## Surface colour alpha that tells the shader "remembered, but show me as I
## am" -- the stairs, which the classic view never lets memory dim.
const LANDMARK := 0.5
## Blend the edge between in-view and remembered ground too. Off: that edge is
## a rule of the game and stays on the cell boundary, as it is in classic.
const SOFT_VIEW_EDGE := false
## Outline thickness as a fraction of the em, what 7px was at 48px.
const OUTLINE_EM := 7.0 / 48.0
## Draw order among billboards. Creatures over the item they stand on, items
## over the feature under them; within one level, nearer over farther.
const PRIORITY_FEATURE := -2
const PRIORITY_ITEM := 0
const PRIORITY_CREATURE := 2
## Words over the scene: awareness markers, then the popups above everything.
const PRIORITY_MARK := 4
const PRIORITY_POPUP := 6
## Where effects sit above the floor, so each stays over the one below it:
## the wound wash, then a hit flash, then rings and chevrons.
const WASH_Y := 0.02
const FLASH_Y := 0.035
const FX_Y := 0.045
## Contact shadows sit under everything else on the floor.
const SHADOW_Y := 0.012
const SHADOW_ALPHA := 0.42
## A hidden part: near-black, with a rim of its own colour at this alpha.
const SILHOUETTE := Color(0.02, 0.02, 0.03, 0.9)
const SILHOUETTE_RIM := 0.55
## How long a door takes to swing open or shut. Motion, so not on "still".
const DOOR_SWING := 0.22
## The camera's jolt when you are hurt, in cells at the strongest hurt. Tiny,
## and only on "full".
const NUDGE := 0.12
## How much stronger the 3D pool under magic is at its heart than the classic
## square -- see _pool_material.
const POOL_GAIN := 2.0

var state: GameState
var look_cursor := Vector2i(-1, -1)
var aim_cursor := Vector2i(-1, -1)
var aim_line: Array[Vector2i] = []
var aim_valid := false
## Every cell the current shot or throw could reach, tinted faintly while
## aiming. Set by main.gd; empty when not aiming. See GameState.reach_cells.
var reach_cells: Array[Vector2i] = []

var _icon_theme := GlyphTheme.new()
var _icon_font: Font
var _floor_font: Font
## One texel per map cell: rgb the light map, a whether the cell is in view.
var _light_img: Image
var _light_tex: ImageTexture
var _viewport: SubViewport
## Kept so a rebuild can give the backdrop this floor's colour by region.
var _environment: Environment
## The engine lights this rebuild placed, and what each was placed for.
var _lights: Array[OmniLight3D] = []
var _torch_light: OmniLight3D = null
## The occlusion strips, counted for the suite.
var ao_count := 0
var ember_count := 0
## True on Forward+ (a PC): screen-space occlusion, volumetric miasma, soft
## shadows. Decided from the renderer actually running, so a PC that fell
## back to OpenGL gets the web look rather than a broken one.
var rich := false
var _post: ColorRect = null
var _post_material: ShaderMaterial = null
var _ao_material: StandardMaterial3D = null
var _ao_quad: PlaneMesh = null
var _camera: Camera3D
var _camera_rig: Node3D
var _scene_root: Node3D
var _overlay_root: Node3D
var _hint: Label
var _dirty := true
var _rebuild_queued := false
var _hover := Vector2i(-1, -1)
var _preview: Array[Vector2i] = []
var _focus := Vector2.ZERO
var _focus_ready := false
var _rotation := CAMERA_YAW
var _rotation_target := CAMERA_YAW
## The overhead view: the same scene, the camera pitched down. Set through
## set_overhead, which moves the camera.
var overhead := false
var _rotation_t := TURN_TIME
## Which of the eight views, 0..7. Even views are diamonds, odd views are
## straight on (see TURN_STEP).
var _view := 0

## The effects in flight and the step glides. main.gd hands this view the same
## two objects the classic grid holds -- see Fx and StepMotion.
var fx := Fx.new()
var motion := StepMotion.new()
## Which light each cell is under, and how long ago each was seen: the same two
## objects again, shared with the classic grid -- see LivingLight and MapMemory.
var light := LivingLight.new()
var memory := MapMemory.new()
## Spores, drips, bubbles and dust: the same one again -- see SmallLife.
var life := SmallLife.new()
## Overridable clock, as on the classic grid, so a screenshot tool can hold the
## light still. Negative means the wall clock.
var anim_time: float = -1.0
## Every surface material the world was built with, so the clock can reach
## them each frame without rebuilding anything.
var _surface_materials: Array[ShaderMaterial] = []
## Pictures whose colour moves between rebuilds: remembered stairs breathing,
## and cooling braziers -- [label, kind, colour, cell, heat].
var _pulsing: Array = []
## Cells with magic lying in them, cell -> item, for the glow under it.
var _glowing_items: Dictionary = {}
## A contact shadow under each item on the floor: [cell, width in cells].
var _item_shadows: Array = []
## Floor dots for this rebuild, [position, colour], drawn as one batch.
var _dots: Array = []
## Doors as last drawn (cell -> open), so a rebuild can tell one has just
## opened or shut, and the doors swinging now: cell -> {"t", "open", "angle",
## "colour"}. See _add_door and _draw_swings.
var _door_open: Dictionary = {}
var _door_map: DungeonMap = null
var _swings: Dictionary = {}
var _leaf_mesh: BoxMesh
var _leaf_material: ShaderMaterial
var _dot_quad: PlaneMesh
var _dot_material: StandardMaterial3D
## This floor's colour by region, fetched once a rebuild -- see RegionLook.
var _region: RegionLook
## Asked for every cell, so worked out once a rebuild: each tile's colour from
## the theme, and how brightly this floor is remembered. -1 is "not yet".
var _theme_fg: Dictionary = {}
var _pictured: Dictionary = {}
var _recall := -1.0
## What moves between rebuilds, per creature: its billboard, the wound wash
## under it, the marker over it, and how tall it stands. Rebuilt with the
## world, repositioned every frame by _update_dynamic.
var _creatures: Dictionary = {}
## Effects are redrawn every frame they run, under their own root so a
## rebuild of the world never touches them.
var _fx_root: Node3D
var _fx_quad: PlaneMesh
var _fx_material: StandardMaterial3D
var _shot_mesh: SphereMesh
var _shot_material: StandardMaterial3D
## Sparks and shards: small cubes, coloured per instance.
var _bit_mesh: BoxMesh
## Contact marks use larger cubes so their shared quarter-cell size reads here too.
var _contact_bit_mesh: BoxMesh
## Drawn over the creatures, as classic draws them: a spark off a blade is in
## front of the thing it struck, never hidden behind it.
var _bit_material: StandardMaterial3D
## The glow under magic on the floor: a soft round pool of blue. The classic
## view's faint square reads as blue on its dark cells, but over a torch-lit 3D
## floor the same square only greyed it, and added light came out lavender. A
## pool strong at its heart keeps the blue and lets the floor show at its edge.
var _pool_quad: PlaneMesh
var _pool_material: StandardMaterial3D
## The same round falloff, for contact shadows: drawn before the blue pools so
## magic's glow lies over the shadow under it, never under it.
var _shadow_material: StandardMaterial3D
## Spores, bubbles, drops and dust: small soft balls, coloured per instance.
## Depth-tested, unlike sparks: a spore behind a wall is behind the wall.
var _mote_mesh: SphereMesh
var _mote_material: StandardMaterial3D
## One map-sized alpha texture and its single floor quad, rebuilt with the map.
var _miasma_image: Image
var _miasma_texture: ImageTexture
var _miasma_material: StandardMaterial3D
var _miasma_node: MeshInstance3D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_viewport()
	_build_hint()
	set_process(true)

func _build_viewport() -> void:
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1296, 720)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(_viewport)
	_viewport.own_world_3d = true
	# The last pass: a vignette and a little grain over the finished frame.
	_post = ColorRect.new()
	_post.name = "Post"
	_post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post.set_anchors_preset(Control.PRESET_FULL_RECT)
	_post_material = ShaderMaterial.new()
	_post_material.shader = POST_SHADER
	_post.material = _post_material
	container.add_child(_post)

	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Palette.BG
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	# A whisper of ambient, so the engine lights have something to lift from;
	# the light map's emission carries the rest of the dark.
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color(0.5, 0.55, 0.7)
	_environment.ambient_light_energy = 0.08
	# Glow: fungus, embers and the pools of magic bleed a little light. On
	# the Compatibility renderer its bloom lifted the whole backdrop to grey
	# (measured with the probe, 2026-10-01), so it is a PC-tier feature --
	# _apply_tier decides -- and the web keeps the halo quads it draws anyway.
	_environment.glow_enabled = false
	_environment.glow_intensity = 0.55
	_environment.glow_bloom = 0.08
	_environment.glow_hdr_threshold = 0.95
	var world_environment := WorldEnvironment.new()
	world_environment.environment = _environment
	_viewport.add_child(world_environment)
	_apply_tier()

	_scene_root = Node3D.new()
	_scene_root.name = "Map"
	_viewport.add_child(_scene_root)
	_overlay_root = Node3D.new()
	_overlay_root.name = "Overlays"
	_scene_root.add_child(_overlay_root)
	_fx_root = Node3D.new()
	_fx_root.name = "Effects"
	_viewport.add_child(_fx_root)
	# Flat squares on the floor for flashes, noise rings and shove chevrons --
	# the same cells classic paints -- coloured per instance.
	_fx_quad = PlaneMesh.new()
	_fx_quad.size = Vector2(0.96, 0.96)
	_fx_material = StandardMaterial3D.new()
	_fx_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_fx_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_fx_material.vertex_color_use_as_albedo = true
	_shot_mesh = SphereMesh.new()
	_shot_mesh.radius = 0.08
	_shot_mesh.height = 0.16
	_shot_material = StandardMaterial3D.new()
	_shot_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shot_material.albedo_color = Palette.SHOT
	_bit_mesh = BoxMesh.new()
	_bit_mesh.size = Vector3(0.08, 0.08, 0.08)
	_contact_bit_mesh = BoxMesh.new()
	_contact_bit_mesh.size = Vector3.ONE * Fx.CONTACT_BLOCK
	_bit_material = _fx_material.duplicate()
	_bit_material.no_depth_test = true
	_bit_material.render_priority = PRIORITY_POPUP - 1
	_pool_quad = PlaneMesh.new()
	_pool_quad.size = Vector2(1.3, 1.3)
	var falloff := Gradient.new()
	falloff.set_color(0, Color(1, 1, 1, 1))
	falloff.set_color(1, Color(1, 1, 1, 0))
	var round_glow := GradientTexture2D.new()
	round_glow.gradient = falloff
	round_glow.fill = GradientTexture2D.FILL_RADIAL
	round_glow.fill_from = Vector2(0.5, 0.5)
	round_glow.fill_to = Vector2(1.0, 0.5)
	_pool_material = StandardMaterial3D.new()
	_pool_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_pool_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pool_material.vertex_color_use_as_albedo = true
	_pool_material.albedo_texture = round_glow
	_pool_material.render_priority = PRIORITY_FEATURE - 1
	_shadow_material = _pool_material.duplicate()
	_shadow_material.render_priority = PRIORITY_FEATURE - 2
	# The floor dot, as the Label3D drew it. That was JetBrains Mono's middle
	# dot -- 0.164 em of ink, at 0.24 cells to the em, so 0.039 cells -- inside
	# Label3D's default black outline. At play zoom that is a small dark mark a
	# couple of pixels across, the floor's colour a speck at its heart that only
	# shows zoomed right in. Same here, matched against a render of the labels:
	# the instance colour in the very middle, black round it, a soft edge.
	var disc := Gradient.new()
	disc.offsets = PackedFloat32Array([0.0, 0.12, 0.25, 0.6, 1.0])
	disc.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 1),
		Color(0, 0, 0, 1), Color(0, 0, 0, 0.9), Color(0, 0, 0, 0)])
	var disc_tex := GradientTexture2D.new()
	disc_tex.gradient = disc
	disc_tex.fill = GradientTexture2D.FILL_RADIAL
	disc_tex.fill_from = Vector2(0.5, 0.5)
	disc_tex.fill_to = Vector2(1.0, 0.5)
	disc_tex.width = 32
	disc_tex.height = 32
	_dot_quad = PlaneMesh.new()
	_dot_quad.size = Vector2(0.09, 0.09)
	_dot_material = StandardMaterial3D.new()
	_dot_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_dot_material.vertex_color_use_as_albedo = true
	_dot_material.vertex_color_is_srgb = true
	_dot_material.albedo_texture = disc_tex
	_dot_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mote_mesh = SphereMesh.new()
	_mote_mesh.radius = 0.5
	_mote_mesh.height = 1.0
	_mote_mesh.radial_segments = 8
	_mote_mesh.rings = 4
	_mote_material = _fx_material.duplicate()
	# The occlusion strip: a quad fading from dark at the wall to nothing a
	# third of a cell out.
	var ao_fall := Gradient.new()
	ao_fall.set_color(0, Color(0, 0, 0, AO_ALPHA))
	ao_fall.set_color(1, Color(0, 0, 0, 0))
	var ao_tex := GradientTexture2D.new()
	ao_tex.gradient = ao_fall
	ao_tex.fill = GradientTexture2D.FILL_LINEAR
	ao_tex.fill_from = Vector2(0.0, 0.5)
	ao_tex.fill_to = Vector2(1.0, 0.5)
	ao_tex.width = 32
	ao_tex.height = 4
	_ao_quad = PlaneMesh.new()
	_ao_quad.size = Vector2(AO_DEPTH, CELL)
	_ao_material = StandardMaterial3D.new()
	_ao_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ao_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ao_material.albedo_texture = ao_tex
	_ao_material.render_priority = PRIORITY_FEATURE - 2

	_camera_rig = Node3D.new()
	_camera_rig.name = "CameraRig"
	_viewport.add_child(_camera_rig)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = CAMERA_SIZE
	_camera.current = true
	_camera_rig.add_child(_camera)
	_place_camera()

	var icon_font: FontFile = load("res://assets/fonts/ofr_icons.ttf").duplicate()
	icon_font.fallbacks = [load("res://assets/fonts/JetBrainsMono-Regular.ttf")]
	_icon_font = icon_font
	_floor_font = load("res://assets/fonts/JetBrainsMono-Regular.ttf")

func _build_hint() -> void:
	_hint = Label.new()
	_hint.text = hint_text()
	_hint.position = Vector2(10, 8)
	_hint.add_theme_font_override("font", load("res://assets/fonts/JetBrainsMono-Regular.ttf"))
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color("e1dfd6"))
	_hint.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_hint.add_theme_constant_override("shadow_offset_x", 1)
	_hint.add_theme_constant_override("shadow_offset_y", 1)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)

func _process(delta: float) -> void:
	if _viewport != null and size.x > 0.0 and size.y > 0.0:
		var wanted := Vector2i(maxi(1, roundi(size.x)), maxi(1, roundi(size.y)))
		if _viewport.size != wanted:
			_viewport.size = wanted
	if state == null:
		return
	var target := _focus_target()
	if not _focus_ready:
		_focus = target
		_focus_ready = true
	elif Effects.any():
		_focus = _focus.lerp(target, clampf(delta / 0.12, 0.0, 1.0))
	else:
		_focus = target
	var clock := anim_time if anim_time >= 0.0 else Time.get_ticks_msec() / 1000.0
	_camera_rig.position = Vector3(_focus.x, 0.0, _focus.y) + camera_nudge(fx.list, clock)
	_camera_rig.rotation.y = _rotation
	if _rotation_t < TURN_TIME:
		_rotation_t = minf(TURN_TIME, _rotation_t + delta)
		var t := _rotation_t / TURN_TIME
		_rotation = lerp_angle(_rotation, _rotation_target, 1.0 - pow(1.0 - t, 2.0))
		_camera_rig.rotation.y = _rotation
	# Bodies turn with the camera, so they read the same way up in every view.
	for label in _body_labels:
		if is_instance_valid(label):
			label.rotation.y = _rotation
	if _dirty and not _rebuild_queued:
		_rebuild_queued = true
		call_deferred("_rebuild_world")
	motion.tick(delta)
	fx.watch_map(state.map)
	fx.tick(delta)
	var now := anim_time if anim_time >= 0.0 else Time.get_ticks_msec() / 1000.0
	for m in _surface_materials:
		m.set_shader_parameter("t", now)
	_update_miasma_opacity(now)
	if not _swings.is_empty():
		for cell in _swings.keys():
			_swings[cell]["t"] += delta
			if float(_swings[cell]["t"]) >= DOOR_SWING:
				_swings.erase(cell)
				_mark_dirty()
	_update_dynamic()

## Same small renderer contract used by main.gd for the classic grid.
func settle_motion() -> void:
	if state == null:
		return
	motion.settle()
	if not _swings.is_empty():
		_swings.clear()
		_mark_dirty()
	_focus = _focus_target()
	_focus_ready = true
	_rotation = _rotation_target
	_rotation_t = TURN_TIME
	if _camera_rig != null:
		_camera_rig.position = Vector3(_focus.x, 0.0, _focus.y)
		_camera_rig.rotation.y = _rotation

func _focus_target() -> Vector2:
	if state.map.in_bounds(look_cursor.x, look_cursor.y):
		return Vector2(look_cursor.x + 0.5, look_cursor.y + 0.5)
	if state.map.in_bounds(aim_cursor.x, aim_cursor.y):
		return Vector2(aim_cursor.x + 0.5, aim_cursor.y + 0.5)
	# Where the player is DRAWN, so the camera glides with the step.
	var at := motion.visual_cell(state.player)
	return Vector2(at.x + 0.5, at.y + 0.5)

func sync_motion() -> void:
	if state != null:
		light.rebuild(state)
		memory.update(state)
		life.rebuild(state)
		# Whoever just stepped into water, mud, rubble or bones throws some of it up.
		fx.footfalls(motion.sync(state.entities, state.map), state)
	_mark_dirty()

func set_aim_state(cursor: Vector2i, line: Array[Vector2i], valid: bool) -> void:
	aim_cursor = cursor
	aim_line = line
	aim_valid = valid
	_mark_dirty()

## Turns the turn's events into effects -- the same list the classic grid
## draws; see Fx.add_events. The world is rebuilt to show the outcome.
func play_events(events: Array) -> void:
	fx.play(events, RenderTheme.font_size(), state, motion)
	_mark_dirty()

func refresh_preview() -> void:
	_preview.clear()
	if state != null and state.map.in_bounds(_hover.x, _hover.y) \
			and state.map.is_explored(_hover.x, _hover.y):
		_preview = state.pathfinder.path(
			Vector2i(state.player.x, state.player.y), _hover)
	if _overlay_root == null or not is_inside_tree():
		_mark_dirty()
	else:
		_rebuild_overlays()

func _draw() -> void:
	_mark_dirty()

func apply_effects_mode() -> void:
	_mark_dirty()

## Text size zooms the camera rather than growing billboards. Read afresh on
## every rebuild (see _camera_size), so a size chosen while the classic view
## was showing is honoured the moment this one appears.
func apply_text_size() -> void:
	_mark_dirty()

func _camera_size() -> float:
	return CAMERA_SIZE * BASE_TEXT_SIZE / float(RenderTheme.cell_size())

## Screen pixels per world unit. The camera is orthographic and keeps its
## height, so this is the same everywhere in the frame.
func _pixels_per_unit() -> float:
	return float(_viewport.size.y) / _camera.size

func forget_metrics() -> void:
	_mark_dirty()

func hovered_cell() -> Vector2i:
	return _hover

## Which way the pad wants the camera to turn: -1..1, left to right.
##
## The right stick first; failing that, the TRIGGERS -- LT turns left, RT turns
## right. The triggers were free, and turning on them suits FFT's camera, but
## the reason they are here is Firefox: with an Xbox Wireless Controller
## (045e-02fd) it labels the pad "standard" and then reports the RIGHT STICK as
## the two trigger values, with the stick's own axes silent. Godot trusts the
## label, so a stick-only camera never turned on itch. Measured by Brad with a
## browser pad-check page, 2026-09-28; through Steam the stick works as it is.
##
## `centred` is Firefox's other half. It reports that stick's left-right as the
## LT VALUE, resting at 0.5 (0 = full left, 1 = full right), and up-down on RT
## the same way -- the real triggers go to axes Godot does not read. So once
## main.gd has seen both "triggers" sit at 0.5 (see looks_like_centred_
## triggers), LT is read as the stick, re-centred, and the triggers are ignored.
## Measured 2026-09-28; Edge and Steam report the pad correctly.
static func turn_intent(right_x: float, left_trigger: float, right_trigger: float,
		centred := false, extra_left := 0.0, extra_right := 0.0) -> float:
	# Firefox's REAL triggers arrive as axes 6 and 7 (its trigger slots carry
	# the right stick). Read first and on their own, so a squeeze turns the
	# camera there whatever the stick is doing. Nothing else uses 6 or 7.
	if extra_right >= 0.5 and extra_left < 0.1:
		return extra_right
	if extra_left >= 0.5 and extra_right < 0.1:
		return -extra_left
	if centred:
		return (left_trigger - 0.5) * 2.0
	if absf(right_x) >= 0.30:
		return right_x
	# A trigger counts only while the other one is at rest (0). Until main.gd
	# has recognised Firefox's mix-up, its stick moves one "trigger" while the
	# other sits at 0.5 -- read as a trigger press, pushing the stick right
	# turned the camera LEFT, and pushing it down turned it right.
	if right_trigger >= 0.30 and left_trigger < 0.10:
		return right_trigger
	if left_trigger >= 0.30 and right_trigger < 0.10:
		return -left_trigger
	return 0.0

## Both triggers resting at the halfway point: no player half-squeezes both and
## holds them still, so this is Firefox's mislabelled stick, not two triggers.
static func looks_like_centred_triggers(left_trigger: float, right_trigger: float) -> bool:
	return absf(left_trigger - 0.5) < 0.05 and absf(right_trigger - 0.5) < 0.05

## The view (0-7) in which the grid step `step` points straight up the screen.
static func view_facing(step: Vector2i) -> int:
	var best := 0
	var best_dot := -INF
	for v in VIEWS:
		var yaw := CAMERA_YAW + float(v) * TURN_STEP
		var d := grid_to_view(step, yaw).normalized().dot(Vector2(0, -1))
		if d > best_dot:
			best_dot = d
			best = v
	return best

## Turns the camera, the short way round, until `step` is straight up the
## screen -- the follow camera. Nothing happens if it already is. Each 45
## degrees is an ordinary rotate_view, so it animates (or snaps, with effects
## off) exactly as a turn by key does.
func face(step: Vector2i) -> void:
	if step == Vector2i.ZERO:
		return
	var delta := posmod(view_facing(step) - _view + 4, VIEWS) - 4
	while delta != 0:
		rotate_view(signi(delta))
		delta -= signi(delta)

## The hint line, for whichever controls are live.
func set_follow_hint(on: bool) -> void:
	_follow_hint = on
	if _hint != null:
		_hint.text = hint_text()

var _follow_hint := false

## The strip's words: which view this is, and which one Q gives next.
func hint_text() -> String:
	var text := FOLLOW_HINT if _follow_hint else DIORAMA_HINT
	return text % (["3D overhead", "classic"] if overhead else ["3D", "overhead"])

## The camera's pitch for this view, in degrees.
func camera_pitch_deg() -> float:
	return CAMERA_PITCH_OVERHEAD_DEG if overhead else CAMERA_PITCH_DEG

## Puts the camera on its rig at the view's pitch, looking at the rig's
## centre. The rig's yaw is the turning camera and is untouched.
func _place_camera() -> void:
	if _camera == null:
		return
	var pitch := deg_to_rad(camera_pitch_deg())
	var at := Vector3(0.0, sin(pitch), cos(pitch)) * CAMERA_DISTANCE
	# In the rig's own frame -- look_at would aim at the WORLD origin, and
	# the rig has usually moved by the time the view changes.
	_camera.transform = Transform3D(Basis.looking_at(-at, Vector3.UP), at)

## Overhead or not. Moves the camera; nothing in the world changes.
func set_overhead(on: bool) -> void:
	if overhead == on:
		return
	overhead = on
	_place_camera()
	if _hint != null:
		_hint.text = hint_text()
	_mark_dirty()

func rotate_view(direction: int) -> void:
	var turn := signi(direction)
	_view = posmod(_view + turn, VIEWS)
	_rotation_target += float(turn) * TURN_STEP
	_rotation_t = 0.0 if Effects.any() else TURN_TIME
	if not Effects.any():
		_rotation = _rotation_target
		_camera_rig.rotation.y = _rotation

## Converts a direction relative to the screen into a DungeonMap direction.
## The player remains on the same cell grid while the camera turns around it.
## Uses where the camera is turning TO, so a key pressed mid-turn already goes
## the new way.
func map_relative_direction(screen_direction: Vector2i) -> Vector2i:
	return view_to_grid(screen_direction, _rotation_target)

## FFT's rule for keys: movement stays on the grid. The four arrows each walk
## along a grid line -- which, with the camera at 45 degrees, runs diagonally
## on screen -- and a diagonal key walks a grid diagonal. With the camera on a
## diagonal, every key sits exactly between two grid directions, so each takes
## the one 45 degrees CLOCKWISE on screen: up walks up-and-right, right walks
## down-and-right, and so on round. A key keeps that direction on screen
## through every turn of the camera.
##
## Along the grid lines rather than straight up the screen because this game is
## full of one-wide corridors that run along the grid: if "up" meant up the
## screen, walking one would take diagonal keys. The trade is that up is
## slanted on screen, the way FFT feels. `yaw` is the camera rig's turn.
static func view_to_grid(screen_direction: Vector2i, yaw: float) -> Vector2i:
	if screen_direction == Vector2i.ZERO:
		return Vector2i.ZERO
	# The key's direction on screen (y down), turned a hair clockwise so a tie
	# between two grid directions always breaks the same way.
	var s := Vector2(screen_direction).normalized().rotated(0.1)
	# Screen right and screen up, on the floor, for a camera turned `yaw`.
	var right := Vector2(cos(yaw), -sin(yaw))
	var up := Vector2(-sin(yaw), -cos(yaw))
	var along := right * s.x - up * s.y
	var diagonal := screen_direction.x != 0 and screen_direction.y != 0
	var best := Vector2i.ZERO
	var best_dot := -INF
	for step in (DIAGONALS if diagonal else AXES):
		var d := Vector2(step).normalized().dot(along)
		if d > best_dot:
			best_dot = d
			best = step
	return best

## Where a grid step shows on screen (y down) for a camera turned `yaw`: the
## inverse of view_to_grid, before snapping. For the tests, and for anything
## that wants to draw an arrow the way a key will go.
static func grid_to_view(step: Vector2i, yaw: float) -> Vector2:
	var right := Vector2(cos(yaw), -sin(yaw))
	var up := Vector2(-sin(yaw), -cos(yaw))
	var g := Vector2(step)
	return Vector2(g.dot(right), -g.dot(up))

func _gui_input(event: InputEvent) -> void:
	if state == null or _camera == null:
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		var c := _cell_from_mouse(motion.position)
		if c != _hover:
			_hover = c
			refresh_preview()
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	var c := _cell_from_mouse(click.position)
	if not state.map.in_bounds(c.x, c.y):
		return
	if click.button_index == MOUSE_BUTTON_LEFT:
		cell_clicked.emit(c)
	elif click.button_index == MOUSE_BUTTON_RIGHT:
		cell_right_clicked.emit(c)
	else:
		return
	accept_event()

func _cell_from_mouse(pos: Vector2) -> Vector2i:
	if _viewport == null or _camera == null:
		return Vector2i(-1, -1)
	var local := pos / size * Vector2(_viewport.size)
	var billboard_cell := _billboard_cell_at(local)
	if billboard_cell.x >= 0:
		return billboard_cell
	var origin := _camera.project_ray_origin(local)
	var direction := _camera.project_ray_normal(local)
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(origin, direction)
	if hit == null:
		return Vector2i(-1, -1)
	var point: Vector3 = hit
	return Vector2i(floori(point.x), floori(point.z))

## The cell of the creature -- or failing that, the item -- whose picture is
## under `screen_pos`. Where pictures overlap, the one whose middle is nearest
## the pointer. With the camera on a diagonal a big creature's box overlaps
## its neighbours: taking the first in the list picked whoever stood next to a
## dragon, and taking the nearest the camera picked the dragon while you
## pointed straight at the player beside it.
func _billboard_cell_at(screen_pos: Vector2) -> Vector2i:
	if state == null:
		return Vector2i(-1, -1)
	var map := state.map
	var best := Vector2i(-1, -1)
	var closest := INF
	for entity in state.entities:
		if not entity.alive or not map.is_visible(entity.x, entity.y):
			continue
		var appearance := _entity_appearance(entity)
		var ch := String(_icon_theme.appearance(appearance).get("ch", "?"))
		var feet := _floor_point(entity.x, entity.y)
		var ink := _ink_size(ch, BillboardSizes.box(appearance, BillboardSizes.CREATURE))
		if _screen_over_billboard(screen_pos, feet, ink):
			var off := _billboard_middle(feet, ink).distance_to(screen_pos)
			if off < closest:
				closest = off
				best = Vector2i(entity.x, entity.y)
	if best.x >= 0:
		return best
	for item in state.ground:
		if not map.is_visible(item.x, item.y):
			continue
		var item_ch := String(_icon_theme.appearance(item.appearance).get("ch", "?"))
		var feet := _floor_point(item.x, item.y)
		var ink := _ink_size(item_ch, BillboardSizes.box(item.appearance, BillboardSizes.ITEM))
		if _screen_over_billboard(screen_pos, feet, ink):
			var off := _billboard_middle(feet, ink).distance_to(screen_pos)
			if off < closest:
				closest = off
				best = Vector2i(item.x, item.y)
	return best

## Where the middle of a picture standing on `feet`, `ink` in size, is on
## screen (viewport pixels).
func _billboard_middle(feet: Vector3, ink: Vector2) -> Vector2:
	return _camera.unproject_position(feet + _camera.global_transform.basis.y * ink.y * 0.5)

## Is `screen_pos` over a picture standing on `feet` and drawn `ink` in size?
## Measured the way _add_billboard places it: feet on the point, drawing up
## the camera's own up axis, since a billboard faces the camera.
func _screen_over_billboard(screen_pos: Vector2, feet: Vector3, ink: Vector2) -> bool:
	var head := feet + _camera.global_transform.basis.y * ink.y
	if _camera.is_position_behind(feet):
		return false
	var bottom := _camera.unproject_position(feet)
	var top := _camera.unproject_position(head)
	var half_width := maxf(8.0, ink.x * _pixels_per_unit() * 0.5)
	return absf(screen_pos.x - bottom.x) <= half_width \
		and screen_pos.y <= bottom.y + 4.0 and screen_pos.y >= minf(top.y, bottom.y - 16.0)

func _mark_dirty() -> void:
	_dirty = true

func _rebuild_world() -> void:
	_rebuild_queued = false
	if not is_inside_tree() or state == null or _scene_root == null:
		return
	_dirty = false
	for child in _scene_root.get_children():
		if child == _overlay_root:
			continue
		_scene_root.remove_child(child)
		child.free()
	_clear_overlays()
	_surface_materials.clear()
	_pulsing.clear()
	_glowing_items.clear()
	_item_shadows.clear()
	_dots.clear()
	_theme_fg.clear()
	_pictured.clear()
	_recall = _memory_strength()
	if state.map != _door_map:
		_door_map = state.map
		_door_open.clear()
		_swings.clear()
	memory.update(state)
	if not _focus_ready:
		_focus = _focus_target()
		_focus_ready = true
		_camera_rig.position = Vector3(_focus.x, 0.0, _focus.y)
	_camera.size = _camera_size()
	_region = RegionLook.for_depth(state.effective_depth())
	# The dark around the map is the region's dark, as in the classic view.
	_environment.background_color = _region.backdrop

	var batches: Dictionary = {}
	var map := state.map
	for y in range(map.height):
		for x in range(map.width):
			var visible := map.is_visible(x, y)
			if not visible and not map.is_explored(x, y):
				continue
			var tile := map.get_tile(x, y)
			var color := _surface_color(tile, x, y, visible)
			if color.a <= 0.0:
				continue
			var solid := tile == Tiles.WALL or tile == Tiles.ROCK \
				or tile == Tiles.PILLAR or tile == Tiles.STALAGMITE \
				or tile == Tiles.DOOR_CLOSED or tile == Tiles.DOOR_BARRED \
				or tile == Tiles.CHEST
			var ground_kind := _ground_surface_kind(tile)
			var kind := ground_kind
			var height := WALL_HEIGHT
			if tile == Tiles.CHEST:
				kind = "chest"
				height = 0.65
			elif tile == Tiles.PILLAR:
				kind = "pillar"
				height = 1.0
			elif tile == Tiles.STALAGMITE:
				kind = "stalagmite"
				height = 1.0
			elif tile == Tiles.ROCK:
				kind = "rock"
				height = WALL_HEIGHT * 0.9
			elif solid:
				kind = "wall"
			var transform := Transform3D(Basis.IDENTITY,
				Vector3(x + 0.5, height * 0.5 if solid else -0.035, y + 0.5))
			if solid:
				var base_transform := Transform3D(Basis.IDENTITY,
					Vector3(x + 0.5, -0.035, y + 0.5))
				_add_batch(batches, ground_kind, base_transform, color)
			var is_door := tile == Tiles.DOOR_CLOSED or tile == Tiles.DOOR_OPEN \
				or tile == Tiles.DOOR_BARRED
			if not is_door:
				_add_batch(batches, kind, transform, color)
			if is_door:
				_add_door(batches, x, y, tile, color, visible)
			elif tile in ASCII_GROUND_TILES:
				if _tile_has_picture(tile):
					_add_tile_icon(tile, x, y, visible)
				else:
					_add_ascii_ground_mark(tile, x, y, visible, color)
			elif _tile_uses_icon(tile):
				_add_tile_icon(tile, x, y, visible)
	_build_cell_light()
	light.upload(state, memory)
	_add_multimeshes(batches)
	_add_lights()
	_add_occlusion()
	_add_embers()
	_add_dots()
	_add_miasma()
	_add_bodies()
	_add_items_and_entities()
	_add_preview_and_cursor()
	_update_dynamic()

func _clear_overlays() -> void:
	if _overlay_root == null:
		return
	for child in _overlay_root.get_children():
		_overlay_root.remove_child(child)
		child.free()

func _rebuild_overlays() -> void:
	_clear_overlays()
	_add_preview_and_cursor()

func _add_batch(batches: Dictionary, kind: String, transform: Transform3D, color: Color) -> void:
	if not batches.has(kind):
		batches[kind] = {"transforms": [], "colors": []}
	var batch: Dictionary = batches[kind]
	batch["transforms"].append(transform)
	batch["colors"].append(color)

func _add_multimeshes(batches: Dictionary) -> void:
	for kind in batches:
		var batch: Dictionary = batches[kind]
		var mesh: Mesh
		var surface_style := int({
			"cave": 4, "rubble": 5, "water": 6, "mud": 7,
			"bones": 8, "fungus": 9, "pit": 10, "stairs": 11,
			"trap": 12, "shrine": 13,
		}.get(kind, 0))
		match kind:
			"wall":
				var masonry := BoxMesh.new()
				masonry.size = Vector3(CELL, WALL_HEIGHT, CELL)
				mesh = masonry
				surface_style = 1
			"rock":
				var rock := BoxMesh.new()
				rock.size = Vector3(CELL * 0.94, WALL_HEIGHT * 0.9, CELL * 0.94)
				mesh = rock
				surface_style = 3
			"door_post":
				var post := BoxMesh.new()
				post.size = Vector3(0.12, WALL_HEIGHT, 0.44)
				mesh = post
				surface_style = 1
			"door_header":
				var header := BoxMesh.new()
				header.size = Vector3(0.80, 0.20, 0.44)
				mesh = header
				surface_style = 1
			"door_leaf":
				var leaf := BoxMesh.new()
				leaf.size = Vector3(0.78, 1.12, 0.12)
				mesh = leaf
				surface_style = 2
			# The bulwark's bar: a beam of stone across the shut leaf.
			"door_bar":
				var bar := BoxMesh.new()
				bar.size = Vector3(0.92, 0.14, 0.24)
				mesh = bar
				surface_style = 1
			"chest":
				var chest := BoxMesh.new()
				chest.size = Vector3(CELL * 0.72, 0.65, CELL * 0.72)
				mesh = chest
				surface_style = 2
			"pillar":
				var pillar := CylinderMesh.new()
				pillar.top_radius = CELL * 0.30
				pillar.bottom_radius = CELL * 0.39
				pillar.height = 1.0
				pillar.radial_segments = 8
				mesh = pillar
				surface_style = 2
			"stalagmite":
				var stalagmite := CylinderMesh.new()
				stalagmite.top_radius = 0.025
				stalagmite.bottom_radius = CELL * 0.40
				stalagmite.height = 1.0
				stalagmite.radial_segments = 7
				mesh = stalagmite
				surface_style = 3
			_:
				var flagstone := BoxMesh.new()
				flagstone.size = Vector3(CELL * 0.98, 0.07, CELL * 0.98)
				mesh = flagstone
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_custom_data = true
		multimesh.mesh = mesh
		var transforms: Array = batch["transforms"]
		var colors: Array = batch["colors"]
		multimesh.instance_count = transforms.size()
		for i in range(transforms.size()):
			multimesh.set_instance_transform(i, transforms[i])
			multimesh.set_instance_custom_data(i, colors[i])
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		instance.material_override = _surface_material(surface_style)
		_scene_root.add_child(instance)
	# A swinging door is drawn on its own (_draw_swings), with the leaf's mesh
	# and material, so it is lit exactly as it will be once it lands.
	_leaf_mesh = BoxMesh.new()
	_leaf_mesh.size = Vector3(0.78, 1.12, 0.12)
	_leaf_material = _surface_material(2)

## THE ENGINE LIGHTS. The torch and the sim's static sources, nearest first,
## as OmniLight3Ds -- up to LIGHT_CAP, because the Compatibility renderer
## lights one mesh with that many and every wall is one mesh. The nearest
## SHADOW_CAP cast shadows. Only sources in view: a remembered brazier lights
## nothing (the shader masks that too, belt and braces).
func _add_lights() -> void:
	_lights.clear()
	_torch_light = null
	var map := state.map
	var sources: Array = []
	for src in state.static_lights:
		if map.is_visible(src.x, src.y):
			sources.append(src)
	var here := Vector2(state.player.x, state.player.y)
	sources.sort_custom(func(a, b):
		return here.distance_squared_to(Vector2(a.x, a.y)) < here.distance_squared_to(Vector2(b.x, b.y)))
	var cap := LIGHT_CAP if not rich else 32
	var placed: Array = []
	if state.player.light != null and state.torch_lit:
		placed.append(state.player.light)
	for src in sources:
		if placed.size() >= cap:
			break
		placed.append(src)
	for i in placed.size():
		var src: LightSource = placed[i]
		var l := OmniLight3D.new()
		l.name = "Light%d" % i
		l.light_color = src.color
		l.light_energy = LIGHT_ENERGY * src.intensity
		l.omni_range = float(src.radius) * RANGE_PER_CELL
		l.omni_attenuation = 1.4
		l.shadow_enabled = i < SHADOW_CAP
		if rich:
			l.light_size = 0.35
			l.shadow_blur = 1.5
		# A hand's height over the floor: a torch held, a brazier's bowl.
		l.position = Vector3(src.x + 0.5, 0.9 if src == state.player.light else 0.6, src.y + 0.5)
		_scene_root.add_child(l)
		_lights.append(l)
		if src == state.player.light:
			_torch_light = l

## The dark at the foot of every wall: one strip per floor cell edge that
## meets something solid, laid on the floor and fading out from the wall.
func _add_occlusion() -> void:
	ao_count = 0
	var map := state.map
	var strips: Array = []
	for y in range(map.height):
		for x in range(map.width):
			if not map.is_visible(x, y) and not map.is_explored(x, y):
				continue
			var t := map.get_tile(x, y)
			if not Tiles.is_walkable(t) or t == Tiles.DOOR_OPEN:
				continue
			for d in AXES:
				var nx := x + d.x
				var ny := y + d.y
				if not map.in_bounds(nx, ny):
					continue
				var nt := map.get_tile(nx, ny)
				if nt == Tiles.WALL or nt == Tiles.ROCK or nt == Tiles.DOOR_CLOSED \
						or nt == Tiles.DOOR_BARRED:
					strips.append([x, y, d])
	if strips.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _ao_quad
	mm.instance_count = strips.size()
	for i in strips.size():
		var x: int = strips[i][0]
		var y: int = strips[i][1]
		var d: Vector2i = strips[i][2]
		# The quad's gradient runs along its local x from dark to clear; turn
		# it so the dark edge lies against the wall.
		var angle := atan2(float(d.y), float(d.x))
		var basis := Basis(Vector3.UP, -angle)
		var centre := Vector3(x + 0.5 + d.x * (0.5 - AO_DEPTH * 0.5), SHADOW_Y + 0.004,
			y + 0.5 + d.y * (0.5 - AO_DEPTH * 0.5))
		mm.set_instance_transform(i, Transform3D(basis, centre))
	ao_count = strips.size()
	var node := MultiMeshInstance3D.new()
	node.name = "Occlusion"
	node.multimesh = mm
	node.material_override = _ao_material
	_scene_root.add_child(node)

## Embers rising off the lit braziers you can see, on simple and full.
func _add_embers() -> void:
	ember_count = 0
	if not Effects.any():
		return
	var map := state.map
	var here := Vector2(state.player.x, state.player.y)
	var braziers: Array = []
	for y in range(map.height):
		for x in range(map.width):
			if map.get_tile(x, y) == Tiles.BRAZIER and map.is_visible(x, y):
				braziers.append(Vector2i(x, y))
	braziers.sort_custom(func(a, b):
		return here.distance_squared_to(Vector2(a)) < here.distance_squared_to(Vector2(b)))
	for i in mini(braziers.size(), 6):
		var c: Vector2i = braziers[i]
		var p := CPUParticles3D.new()
		p.name = "Embers%d" % i
		p.amount = EMBERS_PER_BRAZIER
		p.lifetime = 1.6
		p.preprocess = 1.0
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 0.12
		p.direction = Vector3.UP
		p.spread = 18.0
		p.initial_velocity_min = 0.5
		p.initial_velocity_max = 1.1
		p.gravity = Vector3(0.0, 0.25, 0.0)
		p.scale_amount_min = 0.025
		p.scale_amount_max = 0.05
		p.color = Color(1.0, 0.62, 0.22)
		p.mesh = _mote_mesh
		var mat := _fx_material.duplicate()
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.5, 0.15)
		mat.emission_energy_multiplier = 2.0
		p.material_override = mat
		p.position = Vector3(c.x + 0.5, 0.55, c.y + 0.5)
		_scene_root.add_child(p)
		ember_count += p.amount

## What the renderer running can do beyond the web's (Brad's two tiers): on
## Forward+ the environment gains screen-space occlusion and volumetric fog
## for the miasma, and the lights soft edges. Decided once, from the
## renderer in use rather than the platform, so a fallback to OpenGL on a
## PC gets the web look rather than settings that do nothing.
func _apply_tier() -> void:
	# Headless reports the project's configured method while drawing
	# nothing, so the suite would read a PC it is not running on.
	rich = RenderingServer.get_current_rendering_method() == "forward_plus" \
		and DisplayServer.get_name() != "headless"
	if _environment == null:
		return
	_environment.glow_enabled = rich
	_environment.glow_intensity = 0.35
	_environment.glow_hdr_threshold = 1.1
	_environment.ssao_enabled = rich
	_environment.ssao_radius = 0.8
	_environment.ssao_intensity = 1.6
	_environment.volumetric_fog_enabled = rich
	_environment.volumetric_fog_density = 0.0
	_environment.volumetric_fog_length = 48.0

## A surface material for this rebuild's world: the light, memory, light-that-
## moves and clock, as every mesh in it is drawn with. Kept in
## _surface_materials so the clock reaches it each frame.
func _surface_material(surface_style: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SURFACE_SHADER
	material.set_shader_parameter("surface_style", surface_style)
	material.set_shader_parameter("cell_light", _light_tex)
	material.set_shader_parameter("map_size",
		Vector2(state.map.width, state.map.height))
	material.set_shader_parameter("memory_tint", Palette.MEMORY)
	material.set_shader_parameter("memory_mix", Palette.MEMORY_MIX)
	material.set_shader_parameter("memory_dim", Palette.MEMORY_DIM)
	material.set_shader_parameter("memory_strength", _memory_strength())
	material.set_shader_parameter("soft_view_edge", SOFT_VIEW_EDGE)
	material.set_shader_parameter("cell_data", light.cells)
	material.set_shader_parameter("cell_extra", light.extra)
	material.set_shader_parameter("motion", _motion_level())
	material.set_shader_parameter("t",
		anim_time if anim_time >= 0.0 else Time.get_ticks_msec() / 1000.0)
	material.set_shader_parameter("map_weight", MAP_WEIGHT)
	material.set_shader_parameter("linear_light", rich)
	_surface_materials.append(material)
	return material

## How much of the light may move, for the surface shader: 0 on "still", 1 on
## "simple" (flames flicker, fungus breathes), 2 on "full" (and water catches
## the light and fungus glitters, as the classic shader does).
func _motion_level() -> int:
	if Effects.shaders():
		return 2
	return 1 if Effects.any() else 0

## A cell's own colour, before light or memory: palette, material, and for a
## shrine or a cooling brazier its state. The meshes carry this and the surface
## shader lights it from the light-map texture, so light is applied once.
##
## Alpha 0 means "not drawn" (memory on the corrupted climb). LANDMARK alpha is
## remembered stairs, already in the colour the classic view keeps them.
func _surface_color(tile: int, x: int, y: int, visible: bool) -> Color:
	if not visible:
		if tile == Tiles.STAIRS_DOWN or tile == Tiles.STAIRS_UP:
			return Color(Palette.STAIRS_KNOWN, LANDMARK)
		if _recalled_strength() <= 0.0:
			return Color(0, 0, 0, 0)
	var fg: Color
	if tile == Tiles.WALL:
		fg = Palette.STONE_LIGHT
	elif tile == Tiles.ROCK:
		var h := _hash01(x, y)
		fg = Palette.ROCK_LIGHT.lerp(Palette.ROCK_DARK, h * 0.55)
	elif tile == Tiles.PILLAR or tile == Tiles.STALAGMITE:
		fg = Palette.PILLAR
	else:
		if not _theme_fg.has(tile):
			var app: Dictionary = _icon_theme.appearance(Tiles.appearance_id(tile))
			_theme_fg[tile] = app.get("fg", Palette.FLOOR_FG)
		fg = _theme_fg[tile]
		if tile == Tiles.SHRINE:
			fg = state.shrine_hue(int(state.shrine_at.get(Vector2i(x, y), 0)))
		elif tile == Tiles.BRAZIER_SPENT and visible:
			var heat := state.ember_heat(x, y)
			fg = Palette.BRAZIER_DEAD.lerp(Palette.EMBERS, heat)
	# Stone in view takes the region's colour, brightness kept; the floor and
	# memory do not -- see RegionLook, which the classic view draws from too.
	if visible and _region != null and RegionLook.is_stone(tile):
		fg = _region.shift(fg)
	var material_tint: Color = Palette.MATERIAL_TINT.get(map_material(x, y), Color.WHITE)
	return Color(fg * material_tint, 1.0).clamp()

## The same colour lit or remembered on the CPU, one value per cell. Only the
## flat floor glyphs use it now; the meshes are lit by the shader. `surface` is
## _surface_color's answer when the caller already has it.
func _terrain_color(tile: int, x: int, y: int, visible: bool,
		surface := Color(0, 0, 0, -1)) -> Color:
	var color := surface if surface.a >= 0.0 else _surface_color(tile, x, y, visible)
	if color.a <= 0.0:
		return color
	if color.a < 1.0:
		return Color(color, 1.0)
	if visible:
		return Color(color * state.light_map.get_light(x, y), 1.0).clamp()
	var recalled := _remembered(color) * _recalled_strength() \
		* memory.fade(x, y, state.turns)
	return Color(recalled, 1.0).clamp()

## _memory_strength, from the rebuild's own copy when there is one.
func _recalled_strength() -> float:
	return _recall if _recall >= 0.0 else _memory_strength()

const CAVE_MEMORY := 0.45

## How brightly remembered ground is drawn on this floor: 1 outside the caves,
## CAVE_MEMORY in them, and nothing on the corrupted climb. GlyphGrid's rule.
func _memory_strength() -> float:
	return MapMemory.strength_for(state.effective_depth())

## Hand the surface shader the light, one texel per cell, the way GlyphGrid's
## _upload_cells hands its shader the tiles. rgb is the light map, a is 1 for a
## cell in view now and 0 for one remembered. Half-float, so light where a torch
## and a brazier overlap is not clipped at 1.
##
## Light is written for every cell, seen or not, so smoothing across the edge
## of sight fades towards the light that is really there instead of towards
## black. Whether a cell is SEEN is still read per cell -- see soft_view_edge.
func _build_cell_light() -> void:
	var map := state.map
	if _light_img == null or _light_img.get_width() != map.width \
			or _light_img.get_height() != map.height:
		_light_img = Image.create(map.width, map.height, false, Image.FORMAT_RGBAH)
		_light_tex = null
	for y in range(map.height):
		for x in range(map.width):
			var light := state.light_map.get_light(x, y)
			_light_img.set_pixel(x, y, Color(light.r, light.g, light.b,
				1.0 if map.is_visible(x, y) else 0.0))
	if _light_tex == null:
		_light_tex = ImageTexture.create_from_image(_light_img)
	else:
		_light_tex.update(_light_img)

func map_material(x: int, y: int) -> int:
	return state.map.material_at(x, y)

func _tile_uses_icon(tile: int) -> bool:
	return tile not in ASCII_GROUND_TILES \
		and tile != Tiles.VOID and tile != Tiles.FLOOR and tile != Tiles.WALL \
		and tile != Tiles.ROCK and tile != Tiles.PILLAR \
		and tile != Tiles.PIT and tile != Tiles.STALAGMITE \
		and tile != Tiles.CAVE_FLOOR and tile != Tiles.RUBBLE \
		and tile != Tiles.WATER and tile != Tiles.MUD and tile != Tiles.BONES \
		and tile != Tiles.FUNGUS and tile != Tiles.FUNGUS_PURPLE and tile != Tiles.FUNGUS_RED

func _tile_has_picture(tile: int) -> bool:
	if not _pictured.has(tile):
		var app: Dictionary = _icon_theme.appearance(Tiles.appearance_id(tile))
		_pictured[tile] = GlyphTheme.is_icon(String(app.get("ch", "")))
	return _pictured[tile]

func _add_door(batches: Dictionary, x: int, y: int, tile: int,
		color: Color, visible: bool) -> void:
	var map := state.map
	var along_x := 0
	var along_z := 0
	for offset in [-1, 1]:
		if map.in_bounds(x + offset, y):
			var x_neighbor := map.get_tile(x + offset, y)
			if x_neighbor == Tiles.WALL or x_neighbor == Tiles.ROCK:
				along_x += 1
		if map.in_bounds(x, y + offset):
			var z_neighbor := map.get_tile(x, y + offset)
			if z_neighbor == Tiles.WALL or z_neighbor == Tiles.ROCK:
				along_z += 1
	var angle := PI * 0.5 if along_z > along_x else 0.0
	var basis := Basis(Vector3.UP, angle)
	var center := Vector3(x + 0.5, 0.0, y + 0.5)
	var frame_color := _surface_color(Tiles.WALL, x, y, visible)
	for side in [-1.0, 1.0]:
		var post_at := center + basis * Vector3(side * 0.44, WALL_HEIGHT * 0.5, 0.0)
		_add_batch(batches, "door_post", Transform3D(basis, post_at), frame_color)
	_add_batch(batches, "door_header", Transform3D(basis,
		center + Vector3(0.0, 1.25, 0.0)), frame_color)
	# A door that has just opened or shut swings there instead of jumping,
	# drawn each frame by _draw_swings until it lands; the rebuild after that
	# puts it back with the others.
	var cell := Vector2i(x, y)
	var open := tile == Tiles.DOOR_OPEN
	if _door_open.has(cell) and _door_open[cell] != open and visible and Effects.any():
		_swings[cell] = {"t": 0.0, "open": open, "angle": angle, "colour": color}
	_door_open[cell] = open
	if _swings.has(cell):
		return
	var leaf_basis := basis
	var leaf_at := center + Vector3(0.0, 0.56, 0.0)
	if tile == Tiles.DOOR_OPEN:
		# Swing the leaf ninety degrees into the room from its hinge at the
		# negative end of the opening, leaving the passage visibly clear.
		var open_angle := angle + PI * 0.5
		leaf_basis = Basis(Vector3.UP, open_angle)
		var hinge := center - basis * Vector3(0.39, 0.0, 0.0)
		leaf_at = hinge + leaf_basis * Vector3(0.39, 0.0, 0.0)
		leaf_at.y = 0.56
	else:
		leaf_at = center + Vector3(0.0, 0.56, 0.0)
	if tile == Tiles.DOOR_BARRED:
		# The leaf in the door's own wood; the tile's colour is the stone's.
		_add_batch(batches, "door_leaf", Transform3D(leaf_basis, leaf_at),
			_surface_color(Tiles.DOOR_CLOSED, x, y, visible))
		_add_batch(batches, "door_bar", Transform3D(basis, center + Vector3(0.0, 0.62, 0.0)),
			color)
		return
	_add_batch(batches, "door_leaf", Transform3D(leaf_basis, leaf_at), color)

## Which floor mesh and pattern a tile's ground uses. A table rather than a
## match: this is asked for every cell on every rebuild, and the match was a
## sixth of what rebuilding the world cost.
const GROUND_KINDS := {
	Tiles.CAVE_FLOOR: "cave", Tiles.RUBBLE: "rubble", Tiles.WATER: "water",
	Tiles.MUD: "mud", Tiles.BONES: "bones", Tiles.FUNGUS: "fungus",
	Tiles.FUNGUS_PURPLE: "fungus", Tiles.FUNGUS_RED: "fungus",
	Tiles.PIT: "pit", Tiles.STAIRS_DOWN: "stairs", Tiles.STAIRS_UP: "stairs",
	Tiles.TRAP: "trap", Tiles.SHRINE: "shrine",
}

func _ground_surface_kind(tile: int) -> String:
	return GROUND_KINDS.get(tile, "ground")

func _add_ascii_ground_mark(tile: int, x: int, y: int, visible: bool,
		surface := Color(0, 0, 0, -1)) -> void:
	var app: Dictionary = AsciiTheme.TABLE.get(Tiles.appearance_id(tile), {})
	var mark := String(app.get("ch", ""))
	if mark.is_empty() or mark == " ":
		return
	# The floor's dot is the commonest thing on the map -- a thousand on an
	# explored floor -- and a Label3D each was most of what rebuilding the
	# world cost, every turn. So it is drawn in one batch with all the others
	# (see _add_dots), the size and colour the label gave it.
	if mark == "·" and (tile == Tiles.FLOOR or tile == Tiles.CAVE_FLOOR):
		_dots.append([Vector3(x + 0.5, 0.018, y + 0.5),
			_terrain_color(tile, x, y, visible, surface)])
		return
	var label := Label3D.new()
	label.text = mark
	label.font = _floor_font
	label.font_size = 48
	var width := 0.52 if tile not in [Tiles.FLOOR, Tiles.CAVE_FLOOR] else 0.24
	label.pixel_size = width / 48.0
	label.modulate = _terrain_color(tile, x, y, visible, surface)
	label.shaded = false
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector3(x + 0.5, 0.018, y + 0.5)
	label.rotation_degrees.x = -90.0
	label.no_depth_test = false
	_scene_root.add_child(label)

## Every floor dot of the rebuild, in one MultiMesh -- see _add_ascii_ground_mark.
## The miasma is one map-sized picture: one texel per visible cloud cell, with
## linear filtering to soften the cell corners into a continuous drifting veil.
var miasma_count := 0

func _add_miasma() -> void:
	var map := state.map
	miasma_count = 0
	_miasma_image = null
	_miasma_texture = null
	_miasma_material = null
	_miasma_node = null
	_miasma_image = Image.create(map.width, map.height, false, Image.FORMAT_RGBA8)
	# Keep the cloud hue in transparent texels too, so linear filtering softens
	# alpha at its edge without pulling the colour toward black.
	_miasma_image.fill(Color(Palette.MIASMA.r, Palette.MIASMA.g,
		Palette.MIASMA.b, 0.0))
	for c in state.miasma_cloud():
		if not map_visible(c) or map.get_tile(c.x, c.y) == Tiles.FUNGUS_PURPLE:
			continue
		_miasma_image.set_pixel(c.x, c.y, Palette.MIASMA)
		miasma_count += 1
	if miasma_count == 0:
		_miasma_image = null
		return
	if rich:
		# On Forward+ the cloud is real fog the torch shines through: one
		# FogVolume over each purple fungus, reaching its eight neighbours.
		# The flat quad still goes down beneath it, so the cloud's EDGE stays
		# the cell edge the sim poisons by.
		var fog_mat := FogMaterial.new()
		fog_mat.density = 0.8
		fog_mat.albedo = Color(Palette.MIASMA.r, Palette.MIASMA.g, Palette.MIASMA.b)
		fog_mat.emission = Color(Palette.MIASMA.r, Palette.MIASMA.g, Palette.MIASMA.b) * 0.12
		fog_mat.edge_fade = 0.45
		for y in range(map.height):
			for x in range(map.width):
				if map.get_tile(x, y) != Tiles.FUNGUS_PURPLE or not map_visible(Vector2i(x, y)):
					continue
				var fog := FogVolume.new()
				fog.shape = RenderingServer.FOG_VOLUME_SHAPE_ELLIPSOID
				fog.size = Vector3(2.4, 0.8, 2.4)
				fog.material = fog_mat
				fog.position = Vector3(x + 0.5, 0.5, y + 0.5)
				_scene_root.add_child(fog)
	_miasma_texture = ImageTexture.create_from_image(_miasma_image)
	_miasma_material = StandardMaterial3D.new()
	_miasma_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_miasma_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_miasma_material.albedo_texture = _miasma_texture
	_miasma_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(map.width, map.height)
	_miasma_node = MeshInstance3D.new()
	_miasma_node.name = "MiasmaCloud"
	_miasma_node.mesh = mesh
	_miasma_node.material_override = _miasma_material
	# PlaneMesh is centred on its origin, so this puts its lower-left map corner
	# at world (0, 0) while its pixels remain aligned to the cell grid.
	_miasma_node.position = Vector3(map.width * 0.5, WASH_Y, map.height * 0.5)
	_scene_root.add_child(_miasma_node)
	_update_miasma_opacity(anim_time if anim_time >= 0.0 \
		else Time.get_ticks_msec() / 1000.0)

func _update_miasma_opacity(clock: float) -> void:
	if _miasma_material == null:
		return
	var alpha := MiasmaVisual.alpha_at(clock, Effects.any())
	# The image keeps Palette.MIASMA's requested per-square colour and alpha;
	# this white tint scales only its alpha while the veil drifts.
	_miasma_material.albedo_color = Color(1.0, 1.0, 1.0,
		alpha / Palette.MIASMA.a)

func map_visible(c: Vector2i) -> bool:
	return state.map.in_bounds(c.x, c.y) and state.map.is_visible(c.x, c.y)

## The dead, each its own picture lying flat on its floor cell -- on its side,
## and turned with the camera so it always reads the same way up. Coloured by
## BodyLook, as the classic view colours it. Only where you can see.
var _body_labels: Array[Label3D] = []

func _add_bodies() -> void:
	_body_labels.clear()
	for b in state.bodies:
		var x: int = int(b["x"])
		var y: int = int(b["y"])
		var age: int = state.turns - int(b["turn"])
		if not BodyLook.showing(age) or not state.map.is_visible(x, y):
			continue
		var app: Dictionary = _icon_theme.appearance(StringName(b["app"]))
		var fg: Color = Palette.CORRUPTED if bool(b.get("corrupted", false)) \
			else app.get("fg", Palette.UI_TEXT)
		var label := Label3D.new()
		label.text = String(app.get("ch", "?"))
		label.font = _icon_font
		label.font_size = 64
		label.pixel_size = 0.70 / 64.0
		label.modulate = BodyLook.colour(fg, age)
		label.shaded = false
		label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.position = Vector3(x + 0.5, 0.03, y + 0.5)
		# Flat on the floor (x), on its side (z), and facing the camera (y).
		label.rotation = Vector3(-PI * 0.5, _rotation, PI * 0.5)
		label.no_depth_test = false
		_scene_root.add_child(label)
		_body_labels.append(label)

func _add_dots() -> void:
	if _dots.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _dot_quad
	mm.instance_count = _dots.size()
	for i in _dots.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, _dots[i][0]))
		mm.set_instance_color(i, _dots[i][1])
	var node := MultiMeshInstance3D.new()
	node.name = "FloorDots"
	node.multimesh = mm
	node.material_override = _dot_material
	_scene_root.add_child(node)

func _add_tile_icon(tile: int, x: int, y: int, visible: bool) -> void:
	var id := Tiles.appearance_id(tile)
	var app: Dictionary = _icon_theme.appearance(id)
	var color: Color = app.get("fg", Palette.UI_TEXT)
	if tile == Tiles.SHRINE:
		color = state.shrine_hue(int(state.shrine_at.get(Vector2i(x, y), 0)))
	# Moving colour, as the classic grid draws it: remembered stairs breathe,
	# and a cooling brazier is the forging window's gauge -- see LivingLight.
	var pulse: Array = []
	if not visible and (tile == Tiles.STAIRS_DOWN or tile == Tiles.STAIRS_UP):
		color = Palette.STAIRS_KNOWN * LivingLight.stairs_pulse()
		pulse = [&"stairs", Palette.STAIRS_KNOWN, 0.0]
	elif visible:
		if tile == Tiles.BRAZIER_SPENT and state.ember_heat(x, y) > 0.0:
			var heat := state.ember_heat(x, y)
			pulse = [&"embers", color, heat]
			color = LivingLight.embers(color, heat, x, y)
		color = color * state.light_map.get_light(x, y)
	else:
		color = _remembered(color) * _memory_strength() * memory.fade(x, y, state.turns)
	# Stood on the floor; a chest's picture sits on the lid of its box.
	var feet := _floor_point(x, y)
	if tile == Tiles.CHEST:
		feet.y = 0.66
	var label := _add_billboard(String(app.get("ch", "?")), Color(color, 1.0), feet,
		BillboardSizes.box(id, BillboardSizes.FEATURE))
	label.render_priority = PRIORITY_FEATURE
	label.outline_render_priority = PRIORITY_FEATURE - 1
	if not pulse.is_empty():
		_pulsing.append([label, pulse[0], pulse[1], Vector2i(x, y), pulse[2]])

func _add_items_and_entities() -> void:
	var map := state.map
	# One picture per cell, the last item on top, as the classic grid draws
	# them. Two labels in the same place flicker as they fight over which one
	# is nearer the camera.
	var top_item := {}
	for item in state.ground:
		if map.is_visible(item.x, item.y):
			top_item[Vector2i(item.x, item.y)] = item
			# Any magic in the cell glows, as classic draws every item's glow
			# under the pile -- see LivingLight.item_glow.
			if LivingLight.item_glow(item).a > 0.0:
				_glowing_items[Vector2i(item.x, item.y)] = item
	for at: Vector2i in top_item:
		var item: Item = top_item[at]
		var app: Dictionary = _icon_theme.appearance(item.appearance)
		var color: Color = app.get("fg", Palette.UI_TEXT)
		if item.shows_enchanted():
			color = Palette.MAGIC
		var box := BillboardSizes.box(item.appearance, BillboardSizes.ITEM)
		var label := _add_billboard(String(app.get("ch", "?")), _legible(color, at.x, at.y),
			_floor_point(at.x, at.y), box)
		label.render_priority = PRIORITY_ITEM
		label.outline_render_priority = PRIORITY_ITEM - 1
		_add_silhouette(label, color, PRIORITY_ITEM - 1)
		_item_shadows.append([Vector2(at), _ink_size(String(app.get("ch", "?")), box).x])
	# The trader, remembered where you saw them -- see MapMemory. Out of sight
	# only, and behind walls like the ground: this is memory, not sight.
	var trader := memory.trader_cell
	if trader.x >= 0 and not map.is_visible(trader.x, trader.y) \
			and _memory_strength() > 0.0:
		var ch := String(_icon_theme.appearance(&"trader").get("ch", "?"))
		var remembered := _add_billboard(ch, MapMemory.trader_colour(),
			_floor_point(trader.x, trader.y),
			BillboardSizes.box(&"trader", BillboardSizes.CREATURE))
		remembered.render_priority = PRIORITY_CREATURE
		remembered.outline_render_priority = PRIORITY_CREATURE - 1
	_creatures.clear()
	for entity in state.entities:
		if not entity.alive or not map.is_visible(entity.x, entity.y):
			continue
		var appearance := _entity_appearance(entity)
		var app: Dictionary = _icon_theme.appearance(appearance)
		var color: Color = app.get("fg", Palette.UI_TEXT)
		if entity.corrupted:
			color = Palette.CORRUPTED
		elif entity.faction == Entity.Faction.PLAYER and not entity.is_player:
			# The player is on its own side too, but keeps its own colour: the
			# ally tint is for what fights beside you, as in the classic view.
			color = Palette.ALLY
		if entity.is_player and state.ratted():
			color = Palette.PLAYER
		var box := BillboardSizes.box(appearance, BillboardSizes.CREATURE)
		var label := _add_billboard(String(app.get("ch", "?")),
			_legible(color, entity.x, entity.y), _floor_point(entity.x, entity.y), box)
		label.render_priority = PRIORITY_CREATURE
		label.outline_render_priority = PRIORITY_CREATURE - 1
		# Marked: its outline wears the fungus it carries, and thicker, so it
		# reads before you strike.
		var spore := CreatureMarks.spore_colour(entity)
		if spore.a > 0.0:
			label.outline_modulate = spore
			label.outline_size = maxi(3, label.outline_size * 3)
		var ink := _ink_size(String(app.get("ch", "?")), box)
		var nodes := {"label": label, "tall": ink.y, "wide": ink.x,
			"shape": _add_silhouette(label, color, PRIORITY_CREATURE - 1)}
		if not entity.is_player:
			nodes["mark"] = _add_text("", Color.WHITE, 0.34, PRIORITY_MARK)
		_creatures[entity] = nodes

func _entity_appearance(entity: Entity) -> StringName:
	if entity.is_player and state.ratted():
		return &"rat"
	return entity.appearance

## Lit at its cell, with the classic view's floor of 0.45 under the light:
## something standing in gloom must still be legible.
func _legible(color: Color, x: int, y: int) -> Color:
	var lit := state.light_map.get_light(x, y).lerp(Color.WHITE, 0.45)
	return Color(color * lit, 1.0).clamp()

## Where a billboard stands: the middle of its cell, on the floor.
func _floor_point(x: int, y: int) -> Vector3:
	return Vector3(x + 0.5, 0.01, y + 0.5)

## [advance, ink left, ink bottom, ink right, ink top] in em, from the font
## tool's measurements. A character it never measured gets a letter's shape.
static func _glyph(ch: String) -> Array:
	var cp := ch.unicode_at(0) if not ch.is_empty() else 0x3F
	return GlyphMetrics.GLYPHS.get(cp, [0.6, 0.08, 0.0, 0.52, 0.73])

static func _ink(glyph: Array) -> Vector2:
	return Vector2(maxf(0.05, glyph[3] - glyph[1]), maxf(0.05, glyph[4] - glyph[2]))

## World units per em that fit `ink` into `box` (width, height in cells): as
## large as fits either way, keeping the picture's own shape.
static func _em_for(ink: Vector2, box: Vector2) -> float:
	return minf(box.x / ink.x, box.y / ink.y)

## The drawn size of `ch` in world units once fitted into `box`.
static func _ink_size(ch: String, box: Vector2) -> Vector2:
	var ink := _ink(_glyph(ch))
	return ink * _em_for(ink, box)

## Stands the picture `ch` on `feet`, fitted into `box` -- see BillboardSizes.
## Returns the label so the caller can set its draw order.
##
## Placed by its INK, not its em box. Bottom alignment puts the bottom of the
## line (the font's descent) on `feet`; the offset then moves the glyph so the
## bottom of the drawing is what touches the floor, and centres the drawing
## rather than its advance. Rasterised at about the size it covers on screen,
## so a big billboard is not a small bitmap stretched.
func _add_billboard(ch: String, color: Color, feet: Vector3, box: Vector2,
		on_top := false, parent: Node3D = null) -> Label3D:
	var glyph := _glyph(ch)
	var em := _em_for(_ink(glyph), box)
	var label := Label3D.new()
	label.text = ch
	label.font = _icon_font
	label.font_size = clampi(roundi(em * _pixels_per_unit()), 16, 256)
	label.pixel_size = em / float(label.font_size)
	label.outline_size = maxi(1, roundi(label.font_size * OUTLINE_EM))
	label.modulate = color
	label.shaded = false
	label.outline_modulate = Color("11131a", 0.94)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.offset = Vector2(
		float(glyph[0]) * 0.5 - (float(glyph[1]) + float(glyph[3])) * 0.5,
		-(GlyphMetrics.DESCENT + float(glyph[2]))) * float(label.font_size)
	label.position = feet
	if overhead:
		# Seen from above the card is centred on its cell, as a classic glyph
		# is, and hangs above the walls (overhead_lift). The lift shows on
		# screen as a slide up the screen of lift * cos(pitch), which the
		# offset takes back, in pixels -- so the card is drawn exactly over
		# its cell whichever way the camera has turned.
		var ink_h := _ink(glyph).y
		var lift := overhead_lift(ink_h * em)
		label.offset.y -= (ink_h * 0.5 + lift * cos(deg_to_rad(CAMERA_PITCH_OVERHEAD_DEG)) / em) \
			* float(label.font_size)
		label.position = feet + Vector3.UP * lift
	# Walls in front hide what stands behind them; creatures and items get a
	# silhouette for that part (see _add_silhouette). `on_top` is for effects,
	# which are drawn over everything.
	label.no_depth_test = on_top
	(parent if parent != null else _scene_root).add_child(label)
	return label

## The part of a creature or an item that something solid hides from the
## camera, drawn as a dark shape with a faint rim of its own colour -- so a
## monster behind a wall is still a monster, and still reads as BEHIND it.
##
## Two pictures in one place. The real one is depth-tested, so walls, pillars,
## chests and doors in front of it hide what they should. Under it, this copy
## ignores depth and is drawn first: wherever the real one is hidden, this is
## what shows; wherever it is not, the real one covers it exactly. The copy
## gives nothing away -- creatures and items are only drawn in cells you can
## see, and this only says that what you can see stands behind something.
func _add_silhouette(front: Label3D, colour: Color, priority: int) -> Label3D:
	var back := front.duplicate() as Label3D
	back.modulate = SILHOUETTE
	back.outline_modulate = Color(colour, SILHOUETTE_RIM)
	back.no_depth_test = true
	back.render_priority = priority
	back.outline_render_priority = priority - 1
	front.get_parent().add_child(back)
	return back

## The camera's jolt while you are hurt: a small shake that fades with the red
## edge (Fx.hurt_now), NUDGE cells at the strongest. Only on "full" -- a moving
## camera is exactly what "simple" and "still" are there to spare.
static func camera_nudge(effects: Array, t: float) -> Vector3:
	if not Effects.shaders():
		return Vector3.ZERO
	var hurt := Fx.hurt_now(effects)
	if hurt <= 0.0:
		return Vector3.ZERO
	return Vector3(sin(t * 53.0), 0.0, cos(t * 41.0)) * NUDGE * hurt

## How far to bring a billboard `tall` cells high towards the camera, so it
## does not lean into a wall behind it.
##
## A billboard faces the camera, so at this pitch it leans back by
## tall * sin(pitch). An ordinary creature stays inside its own cell; the
## tallest -- a dragon is 1.4 cells -- would put their heads into the wall
## behind and be silhouetted by it. Moving along the camera's own line of sight
## changes nothing on screen (the camera is orthographic), only what is in
## front of what.
static func lean_pull(tall: float) -> float:
	var pitch := deg_to_rad(CAMERA_PITCH_DEG)
	return maxf(0.0, (tall * sin(pitch) - 0.45) / cos(pitch))

## How high an overhead card `tall` cells high hangs over its cell.
##
## From this pitch a billboard lies within ten degrees of flat, its near edge
## a little below its centre. A wall in the cell in front rises towards the
## camera and, on screen, over the near part of this cell; a card on the
## floor would be cut off by it. So every card hangs with its lowest edge
## above WALL_HEIGHT: nothing on this floor can be in front of it, and a
## glyph is as legible as in the classic view. The lift is straight up, so
## it does not change as the camera turns; what it does to the picture is
## taken back in _add_billboard.
static func overhead_lift(tall: float) -> float:
	return WALL_HEIGHT + OVERHEAD_CLEAR + tall * 0.5 * cos(deg_to_rad(CAMERA_PITCH_OVERHEAD_DEG))

## Everything that moves between rebuilds: creatures gliding through a step,
## the markers travelling over their heads, and the effects in flight. Every
## frame, and cheap -- a few nodes, never the world.
func _update_dynamic() -> void:
	if state == null or _camera == null:
		return
	for p in _pulsing:
		var cell: Vector2i = p[3]
		var colour: Color = p[2]
		if p[1] == &"stairs":
			colour = colour * LivingLight.stairs_pulse()
		else:
			colour = LivingLight.embers(colour, float(p[4]), cell.x, cell.y) \
				* state.light_map.get_light(cell.x, cell.y)
		(p[0] as Label3D).modulate = Color(colour, 1.0).clamp()
	var up := _camera.global_transform.basis.y
	var toward_camera := _camera.global_transform.basis.z
	# The torch goes where you are drawn, mid-glide included.
	if _torch_light != null:
		var at := _floor_at(_drawn_cell(state.player))
		_torch_light.position = Vector3(at.x, 0.9, at.z)
	if _post_material != null and Effects.any():
		_post_material.set_shader_parameter("seed",
			fmod(Time.get_ticks_msec() / 1000.0, 997.0) * 13.0)
	for e in _creatures:
		var nodes: Dictionary = _creatures[e]
		var feet := _floor_at(_drawn_cell(e))
		var tall := float(nodes["tall"])
		var stand := feet + (Vector3.UP * overhead_lift(tall) if overhead
			else toward_camera * lean_pull(tall))
		(nodes["label"] as Label3D).position = stand
		(nodes["shape"] as Label3D).position = stand
		var mark: Label3D = nodes.get("mark")
		if mark == null:
			continue
		var said := CreatureMarks.awareness(e)
		mark.visible = not said.is_empty()
		if mark.visible:
			mark.text = said["text"]
			mark.modulate = said["colour"]
			# Over the head: the card stands on its feet, or from overhead
			# is centred on them, half its height each way.
			mark.position = feet + up * (float(nodes["tall"]) * (0.5 if overhead else 1.0) + 0.08)
	_draw_fx()

## Where a creature is drawn: its glide, and for the trader on "full", their
## idling -- SmallLife.idle_offset, shared with the classic view.
func _drawn_cell(e: Entity) -> Vector2:
	var at := motion.visual_cell(e)
	if e == state.trader:
		at += life.idle_offset(e, motion.visual_cell(state.player),
			anim_time if anim_time >= 0.0 else Time.get_ticks_msec() / 1000.0)
	return at

## The effects in flight and the wound washes, redrawn from nothing each frame.
## Which cells, how strongly and when all come from Fx and CreatureMarks,
## shared with the classic view; only how each looks in 3D is decided here.
func _draw_fx() -> void:
	for child in _fx_root.get_children():
		_fx_root.remove_child(child)
		child.free()
	var map := state.map
	# Squares laid on the floor: [centre in cells, colour, height].
	var glows: Array = []
	# Sparks and shards in the air: [position, colour].
	var bits: Array = []
	# Contact marks keep their shared offsets and fade, with a larger cube mesh.
	var contact_bits: Array = []
	for e in _creatures:
		if e.is_player:
			continue
		var wash := CreatureMarks.wound(e)
		if wash.a > 0.0:
			glows.append([_drawn_cell(e), wash, WASH_Y])
	# A soft dark patch under everything that stands on the floor, so a
	# billboard is ON the floor rather than floating over it: [cell, width].
	# Under creatures it follows the step.
	var shadows: Array = _item_shadows.duplicate()
	for e in _creatures:
		var nodes: Dictionary = _creatures[e]
		shadows.append([_drawn_cell(e), float(nodes["wide"])])
	# Pools of blue under magic: [centre in cells, colour], POOL_GAIN
	# stronger than classic's square at the heart and nothing at the edge.
	var pools: Array = []
	for at: Vector2i in _glowing_items:
		var glow := LivingLight.item_glow(_glowing_items[at])
		if glow.a > 0.0:
			pools.append([Vector2(at), Color(glow, minf(1.0, glow.a * POOL_GAIN))])
	for e in fx.list:
		var t: float = e["t"]
		if t < 0.0:
			continue
		match e["type"]:
			&"flash":
				var a := Fx.flash_alpha(e, t, map)
				if a > 0.0:
					glows.append([Vector2(e["cell"]), Color(e["colour"], a), FLASH_Y])
			&"ring":
				# A noise ring unless it carries its own colour: the light of a
				# level, or a shrine answering a prayer.
				var ring_colour: Color = e.get("colour", Palette.NOISE)
				for hit in Fx.ring_cells(e, t, map):
					glows.append([Vector2(hit[0]), Color(ring_colour, hit[1]), FX_Y])
			&"burn":
				var cell: Vector2i = e["cell"]
				for ember in Fx.burn_points(e, t, map):
					var off: Vector2 = ember[0]
					var colour: Color = ember[3]
					bits.append([Vector3(cell.x + 0.5 + off.x, float(ember[1]),
						cell.y + 0.5 + off.y), Color(colour, float(ember[2]))])
			&"sparks", &"shatter":
				var c: Vector2i = e["cell"]
				if e["type"] == &"shatter":
					var ghost := Fx.shatter_ghost(e, t)
					if ghost > 0.0 and map.is_visible(c.x, c.y):
						var ch := String(_icon_theme.appearance(e["appearance"]).get("ch", "?"))
						_add_billboard(ch, Color(e["colour"], ghost), _floor_point(c.x, c.y),
							BillboardSizes.box(e["appearance"], BillboardSizes.CREATURE),
							true, _fx_root)
				var colour: Color = e["colour"]
				for piece in Fx.burst_points(e, t, map):
					var off: Vector2 = piece[0]
					bits.append([Vector3(c.x + 0.5 + off.x, float(piece[1]), c.y + 0.5 + off.y),
						Color(colour, float(piece[2]))])
			&"contact":
				# Same offsets and fade as classic; only the marks become cubes.
				var contact_cell: Vector2i = e["cell"]
				var contact_colour: Color = e["colour"]
				for mark in Fx.contact_marks(e, t, map):
					var off: Vector2 = mark[0]
					contact_bits.append([Vector3(contact_cell.x + 0.5 + off.x, 0.62,
						contact_cell.y + 0.5 + off.y),
						Color(contact_colour, float(mark[1]))])
			&"shove":
				for hit in Fx.shove_cells(e, t, map):
					glows.append([Vector2(hit[0]), Color(Palette.SHOVE, hit[1]), FX_Y])
			&"shot":
				# Moves smoothly between cells here -- classic steps it cell by
				# cell -- but hides over unseen ground just the same.
				if Fx.shot_cell(e, t, map).x >= 0:
					var ball := MeshInstance3D.new()
					ball.mesh = _shot_mesh
					ball.material_override = _shot_material
					var p := Fx.shot_point(e, t)
					ball.position = Vector3(p.x + 0.5, 0.5, p.y + 0.5)
					_fx_root.add_child(ball)
			&"popup":
				var shape := Fx.popup_state(e, t, map)
				var alpha: float = shape[1]
				if alpha <= 0.0:
					continue
				# Measured against the classic view's popup size, so "!" and
				# LEVEL UP stay the same step larger than a damage number.
				var base := float(RenderTheme.font_size() - 3)
				var em := 0.40 * float(e.get("size", base)) / base
				var popup := _add_text(e["text"], Color(e["colour"], alpha), em,
					PRIORITY_POPUP, _fx_root)
				var c: Vector2i = e["cell"]
				popup.position = Vector3(c.x + 0.5, 0.55 + float(shape[0]) * 0.75, c.y + 0.5)
	if not shadows.is_empty():
		_add_shadows(shadows)
	if not glows.is_empty():
		_add_glows(glows)
	if not pools.is_empty():
		_add_glows(pools, _pool_quad, _pool_material)
	if not bits.is_empty():
		_add_bits(bits)
	if not contact_bits.is_empty():
		_add_bits(contact_bits, _contact_bit_mesh)
	_draw_swings()
	# Small life: which, where and when is SmallLife, shared with classic.
	var motes := life.motes(anim_time if anim_time >= 0.0 else Time.get_ticks_msec() / 1000.0)
	if not motes.is_empty():
		_add_motes(motes)

## Sparks and shards, all in one MultiMesh of small cubes.
func _add_bits(bits: Array, mesh: Mesh = null) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _bit_mesh if mesh == null else mesh
	mm.instance_count = bits.size()
	for i in bits.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, bits[i][0]))
		mm.set_instance_color(i, bits[i][1])
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = _bit_material
	_fx_root.add_child(node)

## Doors part-way through swinging, turning on the same hinge _add_door opens
## them on. Eased out, so a door lands rather than stopping dead.
func _draw_swings() -> void:
	if _swings.is_empty() or _leaf_material == null:
		return
	for cell: Vector2i in _swings:
		var s: Dictionary = _swings[cell]
		var k := clampf(float(s["t"]) / DOOR_SWING, 0.0, 1.0)
		k = 1.0 - pow(1.0 - k, 2.0)
		var opened := k if s["open"] else 1.0 - k
		var angle := float(s["angle"])
		var basis := Basis(Vector3.UP, angle)
		var hinge := Vector3(cell.x + 0.5, 0.0, cell.y + 0.5) - basis * Vector3(0.39, 0.0, 0.0)
		var leaf_basis := Basis(Vector3.UP, angle + opened * PI * 0.5)
		var at := hinge + leaf_basis * Vector3(0.39, 0.0, 0.0)
		at.y = 0.56
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = _leaf_mesh
		mm.instance_count = 1
		mm.set_instance_transform(0, Transform3D(leaf_basis, at))
		mm.set_instance_custom_data(0, s["colour"])
		var node := MultiMeshInstance3D.new()
		node.multimesh = mm
		node.material_override = _leaf_material
		_fx_root.add_child(node)

## Contact shadows, all in one MultiMesh: the pool of light's round falloff,
## in black, a little wider than what stands on it. Round on the floor -- the
## camera's tilt is what flattens it on screen, the same in every view.
func _add_shadows(shadows: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _pool_quad
	mm.instance_count = shadows.size()
	for i in shadows.size():
		var at: Vector2 = shadows[i][0]
		var w := clampf(float(shadows[i][1]) * 1.1, 0.3, 1.2) / _pool_quad.size.x
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(w, 1.0, w)),
			Vector3(at.x + 0.5, SHADOW_Y, at.y + 0.5)))
		mm.set_instance_color(i, Color(0.0, 0.0, 0.0, SHADOW_ALPHA))
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = _shadow_material
	_fx_root.add_child(node)

## Spores, bubbles, drops and dust, all in one MultiMesh: [floor point in cells,
## height, colour, size in cells] each.
func _add_motes(motes: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _mote_mesh
	mm.instance_count = motes.size()
	for i in motes.size():
		var at: Vector2 = motes[i][0]
		var size := float(motes[i][3])
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size),
			Vector3(at.x, float(motes[i][1]), at.y)))
		mm.set_instance_color(i, motes[i][2])
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = _mote_material
	_fx_root.add_child(node)

## Coloured squares on the floor, all in one MultiMesh. The colour goes in per
## instance, so a ring of forty cells is one draw. The height is optional
## (WASH_Y without one); pools of light pass their own mesh and material.
func _add_glows(glows: Array, mesh: Mesh = null, material: Material = null) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh if mesh != null else _fx_quad
	mm.instance_count = glows.size()
	for i in glows.size():
		var at: Vector2 = glows[i][0]
		var y: float = glows[i][2] if glows[i].size() > 2 else WASH_Y
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY,
			Vector3(at.x + 0.5, y, at.y + 0.5)))
		mm.set_instance_color(i, glows[i][1])
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	node.material_override = material if material != null else _fx_material
	_fx_root.add_child(node)

## Words standing over the map: awareness markers and popups, `em` cells tall.
## Always over the scene -- a marker is only ever drawn in a cell you can see.
func _add_text(text: String, colour: Color, em: float, priority: int,
		parent: Node3D = null) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = _floor_font
	label.font_size = clampi(roundi(em * _pixels_per_unit()), 12, 256)
	label.pixel_size = em / float(label.font_size)
	label.outline_size = maxi(1, roundi(label.font_size * OUTLINE_EM))
	label.outline_modulate = Color(0, 0, 0, 0.8 * colour.a)
	label.modulate = colour
	label.shaded = false
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = priority
	label.outline_render_priority = priority - 1
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	(parent if parent != null else _scene_root).add_child(label)
	return label

## The floor point under a (possibly fractional, mid-stride) cell.
func _floor_at(cell: Vector2) -> Vector3:
	return Vector3(cell.x + 0.5, 0.01, cell.y + 0.5)

func _add_preview_and_cursor() -> void:
	if _hover.x >= 0 and state.map.in_bounds(_hover.x, _hover.y):
		for cell in _preview:
			_add_highlight(cell, Palette.PATH_HINT, 0.20)
	if state.map.in_bounds(aim_cursor.x, aim_cursor.y):
		# Reach first and faint, so the line and the reticle sit on top of it.
		for cell in reach_cells:
			if cell != aim_cursor and not (cell in aim_line):
				_add_highlight(cell, Palette.AIM_OK, 0.16)
		var aim_color := Palette.AIM_OK if aim_valid else Palette.AIM_BLOCKED
		for cell in aim_line:
			if cell != aim_cursor:
				_add_highlight(cell, aim_color, 0.45)
	if state.map.in_bounds(look_cursor.x, look_cursor.y):
		_add_highlight(look_cursor, Palette.CURSOR, 0.35)
	elif state.map.in_bounds(aim_cursor.x, aim_cursor.y):
		_add_highlight(aim_cursor,
			Palette.AIM_OK if aim_valid else Palette.AIM_BLOCKED, 0.42)

func _add_highlight(cell: Vector2i, color: Color, alpha: float) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.96, 0.025, 0.96)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color, alpha)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = Vector3(cell.x + 0.5, 0.045, cell.y + 0.5)
	_overlay_root.add_child(instance)

func _remembered(color: Color) -> Color:
	var m := color.lerp(Palette.MEMORY, Palette.MEMORY_MIX)
	return Color(m.r * Palette.MEMORY_DIM, m.g * Palette.MEMORY_DIM,
		m.b * Palette.MEMORY_DIM, 1.0)

func _hash01(x: int, y: int) -> float:
	var h := (x * 73856093) ^ (y * 19349663)
	return float(absi(h) % 1024) / 1024.0
