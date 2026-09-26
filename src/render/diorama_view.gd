class_name DioramaView
extends Control

## A 3D presentation of the same DungeonMap used by GlyphGrid.
##
## The world is still a grid of map cells. This view only changes how those
## cells are presented: blocks for masonry, coloured ground, and the existing
## icon-font pictures on camera-facing Label3D billboards. No simulation code
## or coordinates are changed when the camera turns.

signal cell_clicked(cell: Vector2i)
signal cell_right_clicked(cell: Vector2i)

const CELL := 1.0
const WALL_HEIGHT := 1.35
const CAMERA_SIZE := 26.0
const CAMERA_HEIGHT := 18.0
const CAMERA_DISTANCE := 18.0
const TURN_TIME := 0.18
const DIORAMA_HINT := "3D view     [ / ] or right stick: turn     click: move     Q / d-pad up: classic"
const SURFACE_SHADER: Shader = preload("res://src/render/shaders/diorama_surface.gdshader")
const ASCII_GROUND_TILES := [
	Tiles.FLOOR, Tiles.DOOR_OPEN, Tiles.STAIRS_DOWN, Tiles.STAIRS_UP,
	Tiles.CAVE_FLOOR, Tiles.RUBBLE, Tiles.WATER, Tiles.MUD, Tiles.BONES,
	Tiles.FUNGUS, Tiles.PIT, Tiles.TRAP, Tiles.SHRINE, Tiles.GRAVE,
]

var state: GameState
var look_cursor := Vector2i(-1, -1)
var aim_cursor := Vector2i(-1, -1)
var aim_line: Array[Vector2i] = []
var aim_valid := false

var _icon_theme := GlyphTheme.new()
var _icon_font: Font
var _floor_font: Font
var _text_scale := 1.0
var _viewport: SubViewport
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
var _rotation := 0.0
var _rotation_target := 0.0
var _rotation_t := TURN_TIME
var _quarter_turns := 0

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

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Palette.BG
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8d91a2")
	environment.ambient_light_energy = 0.42
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.ssao_enabled = true
	environment.ssao_radius = 1.35
	environment.ssao_intensity = 1.15
	environment.ssao_power = 1.25
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_viewport.add_child(world_environment)

	_scene_root = Node3D.new()
	_scene_root.name = "Map"
	_viewport.add_child(_scene_root)
	_overlay_root = Node3D.new()
	_overlay_root.name = "Overlays"
	_scene_root.add_child(_overlay_root)

	_camera_rig = Node3D.new()
	_camera_rig.name = "CameraRig"
	_viewport.add_child(_camera_rig)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.size = CAMERA_SIZE
	_camera.position = Vector3(0.0, CAMERA_HEIGHT, CAMERA_DISTANCE)
	_camera.current = true
	_camera_rig.add_child(_camera)
	_camera.look_at(Vector3.ZERO, Vector3.UP)

	var icon_font: FontFile = load("res://assets/fonts/ofr_icons.ttf").duplicate()
	icon_font.fallbacks = [load("res://assets/fonts/JetBrainsMono-Regular.ttf")]
	_icon_font = icon_font
	_floor_font = load("res://assets/fonts/JetBrainsMono-Regular.ttf")

func _build_hint() -> void:
	_hint = Label.new()
	_hint.text = DIORAMA_HINT
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
	_camera_rig.position = Vector3(_focus.x, 0.0, _focus.y)
	_camera_rig.rotation.y = _rotation
	if _rotation_t < TURN_TIME:
		_rotation_t = minf(TURN_TIME, _rotation_t + delta)
		var t := _rotation_t / TURN_TIME
		_rotation = lerp_angle(_rotation, _rotation_target, 1.0 - pow(1.0 - t, 2.0))
		_camera_rig.rotation.y = _rotation
	if _dirty and not _rebuild_queued:
		_rebuild_queued = true
		call_deferred("_rebuild_world")

## Same small renderer contract used by main.gd for the classic grid.
func settle_motion() -> void:
	if state == null:
		return
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
	return Vector2(state.player.x + 0.5, state.player.y + 0.5)

func sync_motion() -> void:
	_mark_dirty()

func set_aim_state(cursor: Vector2i, line: Array[Vector2i], valid: bool) -> void:
	aim_cursor = cursor
	aim_line = line
	aim_valid = valid
	_mark_dirty()

func play_events(_events: Array) -> void:
	# State changes are already present by the time the event queue reaches the
	# renderer. Rebuilding makes the 3D view show their resolved outcome.
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

func apply_text_size() -> void:
	_text_scale = float(RenderTheme.cell_size()) / 18.0
	_mark_dirty()

func forget_metrics() -> void:
	_mark_dirty()

func hovered_cell() -> Vector2i:
	return _hover

func rotate_view(direction: int) -> void:
	var turn := signi(direction)
	_quarter_turns = posmod(_quarter_turns + turn, 4)
	_rotation_target += float(turn) * PI * 0.5
	_rotation_t = 0.0 if Effects.any() else TURN_TIME
	if not Effects.any():
		_rotation = _rotation_target
		_camera_rig.rotation.y = _rotation

## Converts a direction relative to the screen into a DungeonMap direction.
## The player remains on the same cell grid while the camera turns around it.
func map_relative_direction(screen_direction: Vector2i) -> Vector2i:
	match _quarter_turns:
		1:
			return Vector2i(screen_direction.y, -screen_direction.x)
		2:
			return -screen_direction
		3:
			return Vector2i(-screen_direction.y, screen_direction.x)
	return screen_direction

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

func _billboard_cell_at(screen_pos: Vector2) -> Vector2i:
	if state == null:
		return Vector2i(-1, -1)
	var map := state.map
	for entity in state.entities:
		if not entity.alive or not map.is_visible(entity.x, entity.y):
			continue
		var appearance: StringName = entity.appearance
		if entity.is_player and state.ratted():
			appearance = &"rat"
		var width := _entity_icon_size(appearance) * _text_scale
		var center := Vector3(entity.x + 0.5, 0.82, entity.y + 0.5)
		if _screen_over_billboard(screen_pos, center, width):
			return Vector2i(entity.x, entity.y)
	for item in state.ground:
		if not map.is_visible(item.x, item.y):
			continue
		var item_center := Vector3(item.x + 0.5, 0.18, item.y + 0.5)
		if _screen_over_billboard(screen_pos, item_center, 0.58 * _text_scale):
			return Vector2i(item.x, item.y)
	return Vector2i(-1, -1)

func _screen_over_billboard(screen_pos: Vector2, center: Vector3, width: float) -> bool:
	if _camera.is_position_behind(center):
		return false
	var projected := _camera.unproject_position(center)
	var pixels_per_unit := float(_viewport.size.y) / _camera.size
	var half_width := maxf(8.0, width * pixels_per_unit * 0.42)
	var half_height := maxf(10.0, width * pixels_per_unit * 0.52)
	return absf(screen_pos.x - projected.x) <= half_width \
		and absf(screen_pos.y - projected.y) <= half_height

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
	if not _focus_ready:
		_focus = _focus_target()
		_focus_ready = true
		_camera_rig.position = Vector3(_focus.x, 0.0, _focus.y)

	var batches: Dictionary = {}
	var map := state.map
	for y in range(map.height):
		for x in range(map.width):
			var visible := map.is_visible(x, y)
			if not visible and not map.is_explored(x, y):
				continue
			var tile := map.get_tile(x, y)
			var color := _terrain_color(tile, x, y, visible)
			if color.a <= 0.0:
				continue
			var solid := tile == Tiles.WALL or tile == Tiles.ROCK \
				or tile == Tiles.PILLAR or tile == Tiles.STALAGMITE \
				or tile == Tiles.DOOR_CLOSED or tile == Tiles.CHEST
			var kind := _ground_surface_kind(tile)
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
				_add_batch(batches, _ground_surface_kind(tile), base_transform, color)
			var is_door := tile == Tiles.DOOR_CLOSED or tile == Tiles.DOOR_OPEN
			if not is_door:
				_add_batch(batches, kind, transform, color)
			if is_door:
				_add_door(batches, x, y, tile, color, visible)
			elif tile in ASCII_GROUND_TILES:
				if _tile_has_picture(tile):
					_add_tile_icon(tile, x, y, visible)
				else:
					_add_ascii_ground_mark(tile, x, y, visible)
			elif _tile_uses_icon(tile):
				_add_tile_icon(tile, x, y, visible)
	_add_multimeshes(batches)
	_add_lights()
	_add_items_and_entities()
	_add_preview_and_cursor()

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
		var material := ShaderMaterial.new()
		material.shader = SURFACE_SHADER
		material.set_shader_parameter("surface_style", surface_style)
		material.set_shader_parameter("roughness", 0.9)
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		instance.material_override = material
		_scene_root.add_child(instance)

func _terrain_color(tile: int, x: int, y: int, visible: bool) -> Color:
	var fg: Color
	if tile == Tiles.WALL:
		fg = Palette.STONE_LIGHT
	elif tile == Tiles.ROCK:
		var h := _hash01(x, y)
		fg = Palette.ROCK_LIGHT.lerp(Palette.ROCK_DARK, h * 0.55)
	elif tile == Tiles.PILLAR or tile == Tiles.STALAGMITE:
		fg = Palette.PILLAR
	else:
		var app: Dictionary = _icon_theme.appearance(Tiles.appearance_id(tile))
		fg = app.get("fg", Palette.FLOOR_FG)
		if tile == Tiles.SHRINE:
			fg = state.shrine_hue(int(state.shrine_at.get(Vector2i(x, y), 0)))
		elif tile == Tiles.BRAZIER_SPENT and visible:
			var heat := state.ember_heat(x, y)
			fg = Palette.BRAZIER_DEAD.lerp(Palette.EMBERS, heat)
	var material_tint: Color = Palette.MATERIAL_TINT.get(map_material(x, y), Color.WHITE)
	var color: Color = fg * material_tint
	if visible:
		color = color * state.light_map.get_light(x, y)
	else:
		if tile == Tiles.STAIRS_DOWN or tile == Tiles.STAIRS_UP:
			return Palette.STAIRS_KNOWN
		var recalled := _remembered(color)
		var effective := state.effective_depth()
		if Bands.is_caves(effective):
			if Bands.is_corrupted(effective):
				return Color(0, 0, 0, 0)
			recalled *= DioramaView.CAVE_MEMORY
		color = recalled
	return color.clamp()

const CAVE_MEMORY := 0.45

func map_material(x: int, y: int) -> int:
	return state.map.material_at(x, y)

func _tile_uses_icon(tile: int) -> bool:
	return tile not in ASCII_GROUND_TILES \
		and tile != Tiles.VOID and tile != Tiles.FLOOR and tile != Tiles.WALL \
		and tile != Tiles.ROCK and tile != Tiles.PILLAR \
		and tile != Tiles.PIT and tile != Tiles.STALAGMITE \
		and tile != Tiles.CAVE_FLOOR and tile != Tiles.RUBBLE \
		and tile != Tiles.WATER and tile != Tiles.MUD and tile != Tiles.BONES \
		and tile != Tiles.FUNGUS

func _tile_has_picture(tile: int) -> bool:
	var app: Dictionary = _icon_theme.appearance(Tiles.appearance_id(tile))
	return GlyphTheme.is_icon(String(app.get("ch", "")))

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
	var frame_color := _terrain_color(Tiles.WALL, x, y, visible)
	for side in [-1.0, 1.0]:
		var post_at := center + basis * Vector3(side * 0.44, WALL_HEIGHT * 0.5, 0.0)
		_add_batch(batches, "door_post", Transform3D(basis, post_at), frame_color)
	_add_batch(batches, "door_header", Transform3D(basis,
		center + Vector3(0.0, 1.25, 0.0)), frame_color)
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
	_add_batch(batches, "door_leaf", Transform3D(leaf_basis, leaf_at), color)

func _ground_surface_kind(tile: int) -> String:
	match tile:
		Tiles.CAVE_FLOOR:
			return "cave"
		Tiles.RUBBLE:
			return "rubble"
		Tiles.WATER:
			return "water"
		Tiles.MUD:
			return "mud"
		Tiles.BONES:
			return "bones"
		Tiles.FUNGUS:
			return "fungus"
		Tiles.PIT:
			return "pit"
		Tiles.STAIRS_DOWN, Tiles.STAIRS_UP:
			return "stairs"
		Tiles.TRAP:
			return "trap"
		Tiles.SHRINE:
			return "shrine"
	return "ground"

func _add_ascii_ground_mark(tile: int, x: int, y: int, visible: bool) -> void:
	var app: Dictionary = AsciiTheme.TABLE.get(Tiles.appearance_id(tile), {})
	var mark := String(app.get("ch", ""))
	if mark.is_empty() or mark == " ":
		return
	var label := Label3D.new()
	label.text = mark
	label.font = _floor_font
	label.font_size = 48
	var width := (0.52 if tile not in [Tiles.FLOOR, Tiles.CAVE_FLOOR] else 0.24) * _text_scale
	label.pixel_size = width / 48.0
	label.modulate = _terrain_color(tile, x, y, visible)
	label.shaded = false
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector3(x + 0.5, 0.018, y + 0.5)
	label.rotation_degrees.x = -90.0
	label.no_depth_test = false
	_scene_root.add_child(label)

func _add_tile_icon(tile: int, x: int, y: int, visible: bool) -> void:
	var app: Dictionary = _icon_theme.appearance(Tiles.appearance_id(tile))
	var color: Color = app.get("fg", Palette.UI_TEXT)
	if tile == Tiles.SHRINE:
		color = state.shrine_hue(int(state.shrine_at.get(Vector2i(x, y), 0)))
	if not visible and (tile == Tiles.STAIRS_DOWN or tile == Tiles.STAIRS_UP):
		color = Palette.STAIRS_KNOWN
	elif visible:
		color = color * state.light_map.get_light(x, y)
	else:
		color = _remembered(color)
		if Bands.is_caves(state.effective_depth()):
			color *= CAVE_MEMORY
	var height := 0.12
	if tile == Tiles.DOOR_CLOSED:
		height = 0.98
	elif tile == Tiles.CHEST:
		height = 0.72
	_add_icon(String(app.get("ch", "?")), color,
		Vector3(x + 0.5, height, y + 0.5), 0.66 * _text_scale)

func _add_items_and_entities() -> void:
	var map := state.map
	for item in state.ground:
		if not map.is_visible(item.x, item.y):
			continue
		var app: Dictionary = _icon_theme.appearance(item.appearance)
		var color: Color = app.get("fg", Palette.UI_TEXT)
		if item.shows_enchanted():
			color = Palette.MAGIC
		color = color * state.light_map.get_light(item.x, item.y)
		_add_icon(String(app.get("ch", "?")), color,
			Vector3(item.x + 0.5, 0.18, item.y + 0.5), 0.58 * _text_scale)
	for entity in state.entities:
		if not entity.alive or not map.is_visible(entity.x, entity.y):
			continue
		var appearance: StringName = entity.appearance
		var color := Color.WHITE
		if entity.corrupted:
			color = Palette.CORRUPTED
		elif entity.faction == Entity.Faction.PLAYER:
			color = Palette.ALLY
		if entity.is_player and state.ratted():
			appearance = &"rat"
			color = Palette.PLAYER
		var app: Dictionary = _icon_theme.appearance(appearance)
		if color == Color.WHITE:
			color = app.get("fg", Palette.UI_TEXT)
		color = color * state.light_map.get_light(entity.x, entity.y).lerp(Color.WHITE, 0.2)
		_add_icon(String(app.get("ch", "?")), color,
			Vector3(entity.x + 0.5, 0.82, entity.y + 0.5),
			_entity_icon_size(appearance) * _text_scale)

func _entity_icon_size(appearance: StringName) -> float:
	if appearance in [&"ogre", &"troll", &"giant", &"dragon", &"wyvern", &"bear"]:
		return 0.95
	if appearance in [&"kobold", &"goblin", &"rat", &"bat", &"rabbit", &"killer_rabbit"]:
		return 0.64
	return 0.78

func _add_icon(text_value: String, color: Color, at: Vector3, width: float) -> void:
	var label := Label3D.new()
	label.text = text_value
	label.font = _icon_font
	label.font_size = 48
	label.pixel_size = width / 48.0
	label.modulate = color
	label.shaded = false
	label.outline_size = 7
	label.outline_modulate = Color("11131a", 0.94)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = at
	label.no_depth_test = false
	_scene_root.add_child(label)

func _add_lights() -> void:
	var torch := OmniLight3D.new()
	torch.light_color = state.player.light.color
	torch.light_energy = 0.38 * state.player.light.intensity
	torch.omni_range = maxf(2.0, float(state.player.light.radius))
	torch.shadow_enabled = true
	torch.shadow_opacity = 0.72
	torch.position = Vector3(state.player.x + 0.5, 0.72, state.player.y + 0.5)
	_scene_root.add_child(torch)
	var map := state.map
	for y in range(map.height):
		for x in range(map.width):
			if not map.is_visible(x, y):
				continue
			var tile := map.get_tile(x, y)
			if tile == Tiles.BRAZIER and int(state.brazier_charge.get(Vector2i(x, y), 0)) > 0:
				var heat := float(state.brazier_charge[Vector2i(x, y)]) \
					/ float(GameState.BRAZIER_CHARGE)
				_add_accent_light(Vector3(x + 0.5, 0.5, y + 0.5),
					Color("ff9a4a"), 0.32 + heat * 0.34, 3.8)
			elif tile == Tiles.SHRINE:
				var hue: Color = state.shrine_hue(int(
					state.shrine_at.get(Vector2i(x, y), 0)))
				_add_accent_light(Vector3(x + 0.5, 0.24, y + 0.5), hue, 0.18, 2.5)
			elif tile == Tiles.FUNGUS:
				_add_accent_light(Vector3(x + 0.5, 0.18, y + 0.5),
					Color("78dba6"), 0.11, 1.6)

func _add_accent_light(at: Vector3, color: Color, energy: float, radius: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.shadow_enabled = false
	light.position = at
	_scene_root.add_child(light)

func _add_preview_and_cursor() -> void:
	if _hover.x >= 0 and state.map.in_bounds(_hover.x, _hover.y):
		for cell in _preview:
			_add_highlight(cell, Palette.PATH_HINT, 0.20)
	if state.map.in_bounds(aim_cursor.x, aim_cursor.y):
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
