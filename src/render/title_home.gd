class_name TitleHome
extends SubViewportContainer

## THE RETIREMENT HOME, in 3D on the title screen, with the camera circling it.
##
## Brad's picture (2026-09-28): the dungeon faded behind, and in front of it
## the house where the heroes who escaped go to live -- the place the Legends
## Run will one day start from. Built from primitives in code, like the rest of
## the 3D view, so it costs no asset files and needs no import.
##
## Its own World3D and a transparent background, so the dungeon backdrop shows
## through wherever the house is not. Nothing here reads the game state.

## One turn of the camera, in seconds. Slow enough to read as a place rather
## than a spinning logo.
const ORBIT_SECONDS := 48.0
const ORBIT_RADIUS := 19.0
const ORBIT_HEIGHT := 8.0

var _pivot: Node3D
var _smoke: CPUParticles3D

func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	var world := Node3D.new()
	vp.add_child(world)
	_build(world)

func _process(delta: float) -> void:
	if Effects.any():
		_pivot.rotation.y += delta * TAU / ORBIT_SECONDS
	_smoke.emitting = Effects.any()

func _mat(c: Color, rough := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m

func _glow(c: Color, energy: float) -> StandardMaterial3D:
	var m := _mat(c)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m

func _box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = b
	mi.material_override = mat
	mi.position = at
	parent.add_child(mi)
	return mi

func _build(world: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.36, 0.52)
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)

	# Moonlight from the back left: cool, low, so the walls have a lit side and
	# a dark side and the windows carry the warmth.
	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.62, 0.70, 0.95)
	moon.light_energy = 0.75
	moon.rotation_degrees = Vector3(-38, -35, 0)
	world.add_child(moon)

	_pivot = Node3D.new()
	world.add_child(_pivot)
	var cam := Camera3D.new()
	cam.position = Vector3(0, ORBIT_HEIGHT, ORBIT_RADIUS)
	cam.fov = 34.0
	_pivot.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0, 0.9, 0))
	# A three-quarter view to start with, not the flat front.
	_pivot.rotation.y = deg_to_rad(-30.0)

	var stone := _mat(Palette.STONE_LIGHT.darkened(0.15))
	var stone_dark := _mat(Palette.STONE_DARK)
	var wood := _mat(Color("5a3d24"))
	var slate := _mat(Color("4a3a44"))
	var lit := _glow(Color(0.95, 0.58, 0.24), 0.9)
	var grass := _mat(Color("1d2419"))

	# The ground it stands on: an island of turf on a rim of stone, so it
	# reads as a place set down in the dark rather than a slab cut off by the
	# frame.
	var rim := CylinderMesh.new()
	rim.top_radius = 5.3
	rim.bottom_radius = 5.0
	rim.height = 0.5
	rim.radial_segments = 10
	var rim_mi := MeshInstance3D.new()
	rim_mi.mesh = rim
	rim_mi.material_override = stone_dark
	rim_mi.position = Vector3(0, -0.3, 0.3)
	world.add_child(rim_mi)
	var turf := CylinderMesh.new()
	turf.top_radius = 5.0
	turf.bottom_radius = 5.0
	turf.height = 0.1
	turf.radial_segments = 10
	var turf_mi := MeshInstance3D.new()
	turf_mi.mesh = turf
	turf_mi.material_override = grass
	turf_mi.position = Vector3(0, -0.02, 0.3)
	world.add_child(turf_mi)
	for i in 5:
		_box(world, Vector3(0.9, 0.06, 0.55), Vector3(0.1 * (i % 2), 0.02,
			2.3 + i * 0.75), stone_dark)

	# The house: stone walls, a pitched slate roof, a chimney.
	var house := Node3D.new()
	world.add_child(house)
	_box(house, Vector3(4.6, 2.2, 3.4), Vector3(0, 1.1, 0), stone)
	_box(house, Vector3(4.8, 0.25, 3.6), Vector3(0, 0.12, 0), stone_dark)
	var roof_mesh := PrismMesh.new()
	roof_mesh.size = Vector3(3.9, 1.5, 5.2)
	var roof := MeshInstance3D.new()
	roof.mesh = roof_mesh
	roof.material_override = slate
	# The prism's ridge runs along its depth, so turned a quarter to run along
	# the house's long side.
	roof.rotation_degrees = Vector3(0, 90, 0)
	roof.position = Vector3(0, 2.2 + 0.75, 0)
	house.add_child(roof)
	_box(house, Vector3(0.6, 1.6, 0.6), Vector3(1.4, 3.1, -0.5), stone_dark)

	# The door, and the windows, lit: somebody is home.
	_box(house, Vector3(0.9, 1.5, 0.12), Vector3(0, 0.85, 1.72), wood)
	for x in [-1.45, 1.45]:
		_box(house, Vector3(0.75, 0.65, 0.1), Vector3(x, 1.3, 1.72), lit)
		_box(house, Vector3(0.9, 0.1, 0.16), Vector3(x, 0.93, 1.74), stone_dark)
	for z in [-0.7, 0.7]:
		_box(house, Vector3(0.1, 0.6, 0.6), Vector3(2.32, 1.3, z), lit)
		_box(house, Vector3(0.1, 0.6, 0.6), Vector3(-2.32, 1.3, z), lit)
	var hearth := OmniLight3D.new()
	hearth.light_color = Color(1.0, 0.66, 0.32)
	hearth.light_energy = 2.2
	hearth.omni_range = 4.5
	hearth.position = Vector3(0, 1.3, 2.4)
	house.add_child(hearth)

	# A bench by the door, for sitting out the evening.
	_box(house, Vector3(1.1, 0.1, 0.35), Vector3(1.55, 0.45, 2.1), wood)
	for x in [1.1, 2.0]:
		_box(house, Vector3(0.1, 0.4, 0.3), Vector3(x, 0.2, 2.1), wood)

	# Three graves at the side: the ones who did not come home. The party is
	# three, and so is this row.
	for i in 3:
		_box(world, Vector3(0.42, 0.6, 0.12), Vector3(-3.5, 0.3, -1.2 + i * 0.9),
			_mat(Palette.GRAVE.darkened(0.45)))

	# Smoke from the chimney, which stops with everything else when effects
	# are switched off.
	_smoke = CPUParticles3D.new()
	_smoke.position = Vector3(1.4, 4.0, -0.5)
	_smoke.amount = 24
	_smoke.lifetime = 5.0
	_smoke.direction = Vector3(0.2, 1, 0)
	_smoke.spread = 12.0
	_smoke.initial_velocity_min = 0.35
	_smoke.initial_velocity_max = 0.55
	_smoke.gravity = Vector3(0.08, 0.02, 0)
	_smoke.scale_amount_min = 0.5
	_smoke.scale_amount_max = 1.1
	var puff := SphereMesh.new()
	puff.radius = 0.16
	puff.height = 0.32
	var puff_mat := StandardMaterial3D.new()
	puff_mat.albedo_color = Color(0.50, 0.52, 0.58, 0.16)
	puff_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	puff.material = puff_mat
	_smoke.mesh = puff
	world.add_child(_smoke)
