class_name TitleHall
extends DioramaView

## THE RETIREMENT HOME as the game's own 3D view draws it: a small hall in the
## dungeon's style, three heroes round the hearth and the traveller by the
## door. No monsters. The camera turns slowly round them.
##
## Brad, 2026-09-28: "the house should look like a 3d dungeon, in that style,
## just no enemies, and three players, maybe the traveller". It is the real
## renderer on a real (hand-built) floor, so whatever the 3D view learns to
## draw, this learns too. The cottage in title_home.gd is kept for an idea
## Brad has for it.
##
## The floor is built by hand and never saved, played or written anywhere.

## The hall, drawn as text. # wall, . floor, B the hearth (a lit brazier),
## P pillar, C chest, + door, G graves of the ones who did not come home,
## 1-3 the heroes, T the traveller.
const PLAN := [
	"###############",
	"#C...........C#",
	"#.P....2....P.#",
	"#......B......#",
	"#....1...3....#",
	"#.P.........P.#",
	"#G.G.G....T..C#",
	"#######+#######",
]
## Degrees per second. One full turn in a minute: slow enough to read as a
## place rather than a spinning logo.
const ORBIT_SPEED := 6.0

func _ready() -> void:
	super()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.visible = false
	# The dungeon backdrop shows through wherever the hall is not.
	_viewport.transparent_bg = true
	_environment.background_mode = Environment.BG_CLEAR_COLOR
	# No last pass here. It reads the screen behind its rectangle, and on the
	# title that screen is the GAME's view underneath, which it painted over
	# the hall and the backdrop (Brad's first look at the 3D branch,
	# 2026-10-01). A vignette belongs on the game, not on the menu's scenery.
	_post.visible = false
	state = TitleHall.hall_state()
	sync_motion()

## Closer than the game's camera: the whole hall fills the frame.
func _camera_size() -> float:
	return 17.0

func _gui_input(_event: InputEvent) -> void:
	pass

func _process(delta: float) -> void:
	# Still when effects are off -- a player who turned motion off, perhaps
	# because the 3D view makes them unwell, should not meet it on the title.
	if Effects.any():
		_rotation += deg_to_rad(ORBIT_SPEED) * delta
		_rotation_target = _rotation
		_rotation_t = TURN_TIME
	super(delta)

## The hall as a GameState the renderer can draw. The first hero is the
## state's player, which is also where the camera centres.
static func hall_state() -> GameState:
	BestiaryLog.paused = true
	var gs := GameState.new(1)
	gs.new_game()
	var map := DungeonMap.new(gs.map.width, gs.map.height)
	gs.map = map
	gs.light_map = LightMap.new(map.width, map.height)
	gs.entities = [gs.player]
	gs.ground = []
	var ox := map.width / 2 - PLAN[0].length() / 2
	var oy := map.height / 2 - PLAN.size() / 2
	var names := ["Wren", "Fenn", "Edda"]
	for row in PLAN.size():
		var line: String = PLAN[row]
		for col in line.length():
			var x := ox + col
			var y := oy + row
			var ch := line[col]
			var tile := Tiles.FLOOR
			match ch:
				"#": tile = Tiles.WALL
				"B": tile = Tiles.BRAZIER
				"P": tile = Tiles.PILLAR
				"C": tile = Tiles.CHEST
				"G": tile = Tiles.GRAVE
				"+": tile = Tiles.DOOR_CLOSED
			map.set_tile(x, y, tile)
			if ch == "1":
				gs.player.x = x
				gs.player.y = y
			elif ch == "2" or ch == "3":
				var hero := Entity.new(names[int(ch) - 1], &"player", x, y)
				hero.faction = Entity.Faction.PLAYER
				hero.alertness = Entity.Alert.AWAKE
				gs.entities.append(hero)
			elif ch == "T":
				var t := Entity.new("traveller", &"trader", x, y)
				t.faction = Entity.Faction.NEUTRAL
				t.alertness = Entity.Alert.AWAKE
				gs.entities.append(t)
	gs.player_name = names[0]
	gs.pathfinder = Pathfinder.new(map)
	gs._gather_lights()
	gs.update_vision()
	# Everything in the hall seen and lit, and nothing outside it: revealing
	# the whole map would draw the empty rest of it as a black floor, a slab
	# hiding the dungeon behind.
	map.clear_visible()
	for row in PLAN.size():
		for col in PLAN[row].length():
			map.show_cell(ox + col, oy + row)
	map.remember_visible()
	BestiaryLog.paused = false
	return gs
