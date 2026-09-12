class_name Sidebar
extends Control

## Character status, plus a look-panel describing whatever the mouse is over.
## Drawn by hand with the same font as the map so the whole screen reads as one
## surface rather than a game with a GUI bolted beside it.

@export var font: Font
@export var font_bold: Font
@export var font_size: int = 15

var state: GameState
var hovered := Vector2i(-1, -1)
var look_mode := false
var aiming := false

var _last_hp := -1
var _hit_at := -10.0

const PAD := 14.0
const LINE := 21.0

## The canonical key table. The third column marks the handful worth keeping
## permanently on screen -- the legend draws all of them, this panel draws only
## those, because a sixteen-row block at the bottom of the sidebar had stopped
## being a reference and started being wallpaper.
##
## One list rather than two, so the short version cannot drift from the long
## one as keys are added.
const KEYS := [
	["arrows / hjklyubn", "move", true],
	[". or 5", "wait / rest", true],
	[">", "descend", false],
	["<", "ascend", false],
	["x", "look", true],
	["g", "pick up", true],
	["i", "inventory", true],
	["t", "torch", false],
	["f / right-click", "shoot", true],
	["w", "swap reach / blade", true],
	["f (no bow)", "throw", false],
	["p", "pray at a shrine", false],
	["m  - +", "sound", false],
	["v", "letters / symbols / pictures", false],
	# Motion, and it is an accessibility setting before it is a taste one --
	# effects like these stop some people playing games at all.
	["e", "still / simple / full", false],
	["esc", "menu", false],
	["click", "travel", false],
]

## What the sidebar itself shows: the essentials, plus the way to everything.
static func essential_keys() -> Array:
	var out := []
	for row in KEYS:
		if row[2]:
			out.append(row)
	out.append(["?", "all keys", true])
	return out

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font == null:
		font = ui_font()
	if font_bold == null:
		font_bold = load("res://assets/fonts/JetBrainsMono-Bold.ttf")

func _process(_delta: float) -> void:
	if state == null:
		return
	var hp := state.player.hp
	if _last_hp >= 0 and hp < _last_hp:
		_hit_at = Time.get_ticks_msec() / 1000.0
	_last_hp = hp

func _draw() -> void:
	if state == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Palette.UI_PANEL_BG, true)
	draw_rect(Rect2(Vector2.ZERO, size), Palette.UI_FRAME, false, 1.0)

	var y := PAD + font.get_ascent(font_size)

	_line(font_bold, y, "OFR", Palette.STAIRS)
	y += LINE
	if state.won:
		_line(font_bold, y, "ESCAPED  turn %d" % state.turns, Palette.STAIRS)
	elif state.ascending:
		_line(font, y, "depth %d  UP    turn %d" % [state.depth, state.turns],
			Palette.AMULET)
	else:
		_line(font, y, "depth %d    turn %d" % [state.depth, state.turns],
			Palette.UI_DIM)
	y += LINE

	# Level, with progress toward the next one. The bar matters more than the
	# number: it answers "is one more fight worth it" at a glance.
	var into := state.xp_into_level()
	var need := maxi(1, state.xp_needed_for_next())
	draw_string(font_bold, Vector2(PAD, y), "level %d" % state.player.level,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.STAIRS)
	draw_string(font, Vector2(PAD, y), "%d/%d" % [into, need],
		HORIZONTAL_ALIGNMENT_RIGHT, size.x - PAD * 2.0, font_size, Palette.UI_DIM)
	y += 7.0
	var xp_w := size.x - PAD * 2.0
	draw_rect(Rect2(Vector2(PAD, y), Vector2(xp_w, 5)), Color("1e1f26"), true)
	draw_rect(Rect2(Vector2(PAD, y), Vector2(xp_w * clampf(float(into) / float(need), 0.0, 1.0), 5)),
		Palette.STAIRS, true)
	y += 5 + LINE * 1.2

	# Health bar. A bar plus the numbers -- the bar for the glance, the numbers
	# for the decision about whether one more fight is survivable.
	var p := state.player
	var frac := float(p.hp) / float(p.max_hp)
	var col := Palette.HP_GOOD
	if frac < 0.3:
		col = Palette.HP_BAD
	elif frac < 0.6:
		col = Palette.HP_WARN

	# Two pulses share one channel: a short flare when hit, and a continuous
	# throb below 30%. Motion at the edge of vision is what catches you while
	# you are reading the map -- which is exactly how the slinger got its kill.
	var now := Time.get_ticks_msec() / 1000.0
	var since_hit := now - _hit_at
	var pulse := 0.0
	if since_hit < 0.45:
		pulse = 1.0 - since_hit / 0.45
	if frac < 0.3:
		pulse = maxf(pulse, 0.30 + 0.30 * sin(now * 7.0))

	_line(font, y, "HP %d/%d" % [p.hp, p.max_hp], col if frac < 0.3 else Palette.UI_TEXT)
	y += 8.0
	var bar_w := size.x - PAD * 2.0
	draw_rect(Rect2(Vector2(PAD, y), Vector2(bar_w, 10)), Color("1e1f26"), true)
	draw_rect(Rect2(Vector2(PAD, y), Vector2(bar_w * frac, 10)), col, true)
	if pulse > 0.0:
		draw_rect(Rect2(Vector2(PAD, y), Vector2(bar_w * frac, 10)),
			Color(1, 1, 1, pulse * 0.42), true)
		draw_rect(Rect2(Vector2(PAD - 2.0, y - 2.0), Vector2(bar_w + 4.0, 14.0)),
			Color(Palette.HP_BAD, pulse * 0.85), false, 2.0)
	draw_rect(Rect2(Vector2(PAD, y), Vector2(bar_w, 10)), Palette.UI_FRAME, false, 1.0)
	y += 10 + LINE

	# Totals, not base values -- what the player needs is the number that
	# actually goes into the damage roll.
	# With a launcher in hand, `power` alone is a lie. Swinging a bow halves
	# your BASE power and the blow lands at the damage floor -- which is how a
	# character reading "power 15" loses to a young dragon every single time
	# while a war axe wins every single time. The number that decides a melee
	# exchange belongs on screen next to the one that decides a shot.
	if p.total_range() > 1:
		_stat_row(y, "power", "%d  melee %d"
			% [p.total_power(), maxi(1, int(p.power / 2))], true)
	else:
		_stat_row(y, "power", str(p.total_power()), p.total_power() != p.power)
	y += LINE
	_stat_row(y, "defense", str(p.total_defense()), p.total_defense() != p.defense)
	y += LINE
	# Reach is shown on the weapon line, so it reads as a property a weapon can
	# have rather than something only monsters get.
	var reach := p.total_range()
	var held: Item = p.equipped.get(Item.Slot.WEAPON, null)
	if held != null and held.uses_ammo():
		# The count belongs beside the reach, because they are read together:
		# how far can I hit, and how many times. An empty quiver is tinted like
		# a wound, since it means the next press of `f` does nothing.
		_stat_row(y, "weapon", "%s r%d x%d"
			% [held.display_name(), reach, held.ammo], held.ammo > 0)
	elif held != null and held.charges > 0:
		# A ring that burns down is a quiver that empties, so it is answered in
		# the same place and the same way: how many more.
		#
		# Exact rather than "charged / low", because the only question anyone
		# asks of it is quantitative -- can I cross this floor as a rat -- and
		# 148 against 40 is that whole question. A band spanning 51 to 149
		# cannot answer it. The highlight going out below RING_LOW is what a
		# band would have bought, and it costs nothing the row was not already
		# doing for a quiver.
		#
		# It matters more than ammo does. An empty quiver means the next `f`
		# does nothing; an empty ring means you stop being a rat wherever you
		# are standing, which by construction is somewhere you chose to be
		# unseen.
		_stat_row(y, "weapon", "%s  x%d" % [held.display_name(), held.charges],
			held.charges > GameState.RING_LOW)
	elif reach > 1:
		_stat_row(y, "weapon", "%s  r%d" % [_slot_name(p, Item.Slot.WEAPON), reach], true)
	else:
		_stat_row(y, "weapon", _slot_name(p, Item.Slot.WEAPON), false)
	y += LINE
	_stat_row(y, "armour", _slot_name(p, Item.Slot.ARMOR), false)
	y += LINE
	# Shown even when empty, so the slot's existence is discoverable without
	# having to find a shield first.
	_stat_row(y, "offhand", _slot_name(p, Item.Slot.OFFHAND),
		p.equipped.has(Item.Slot.OFFHAND))
	y += LINE
	# Footing, because the energy cost of mud was working perfectly and was
	# entirely invisible: one keypress still looked like one turn.
	var ground := state.map.get_tile(state.player.x, state.player.y)
	var pace := Tiles.move_cost(ground)
	var ground_name := String(Tiles.appearance_id(ground)).replace("_", " ")
	if pace > 1.0:
		_stat_row(y, "footing", "%s  x%.1f" % [ground_name, pace], true)
	else:
		_stat_row(y, "footing", "firm", false)
	y += LINE

	# Doused is the unusual, dangerous state, so it is the one that is tinted.
	var torch_text := "lit" if state.torch_lit else "doused"
	var torch_tint := Palette.UI_TEXT if state.torch_lit else Palette.SLEEP
	if state.torch_flare > 0:
		torch_text = "FLARED %d" % state.torch_flare
		torch_tint = Palette.AMULET
	draw_string(font, Vector2(PAD, y), "torch",
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.UI_DIM)
	draw_string(font, Vector2(PAD, y), torch_text,
		HORIZONTAL_ALIGNMENT_RIGHT, size.x - PAD * 2.0, font_size, torch_tint)
	y += LINE * 1.7

	# Look panel. Retitled in look mode so it is obvious the keys are now
	# driving a cursor rather than the player.
	if aiming:
		_line(font_bold, y, "SHOOTING AT", Palette.AIM_OK)
	elif look_mode:
		_line(font_bold, y, "LOOKING AT", Palette.CURSOR)
	else:
		_line(font_bold, y, "UNDER CURSOR", Palette.UI_DIM)
	y += LINE
	for text in _describe():
		_line(font, y, _fit(text), Palette.UI_TEXT)
		y += LINE

	# Derived from the list, not a hand-counted constant. Adding a row to KEYS
	# once pushed the last baseline exactly onto the frame with a hard-coded
	# number -- the fourth time something in this panel had overrun its edge
	# because a count had to be kept in step with a list by hand.
	var shown := essential_keys()
	y = size.y - PAD - LINE * float(shown.size() + 1)
	_line(font_bold, y, "KEYS", Palette.UI_DIM)
	y += LINE
	for row in shown:
		_key_row(y, row[0], row[1])
		y += LINE

func _line(f: Font, y: float, text: String, color: Color) -> void:
	draw_string(f, Vector2(PAD, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _slot_name(p: Entity, slot: int) -> String:
	var item = p.equipped.get(slot, null)
	return "--" if item == null else item.display_name()

## Label left, value right-aligned. `boosted` tints the value so a bonus from
## equipment is visible at a glance without reading the equipment lines.
func _stat_row(y: float, label: String, value: String, boosted: bool) -> void:
	draw_string(font, Vector2(PAD, y), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.UI_DIM)
	draw_string(font, Vector2(PAD, y), _fit(value),
		HORIZONTAL_ALIGNMENT_RIGHT, size.x - PAD * 2.0, font_size,
		Palette.HP_GOOD if boosted else Palette.UI_TEXT)

## Key on the left, action right-aligned against the frame.
##
## The previous version padded the gap with spaces, which is terminal thinking:
## it assumes a fixed panel width and silently pushes "inventory" through the
## edge the moment either string grows. Measured alignment cannot overflow.
func _key_row(y: float, key: String, action: String) -> void:
	draw_string(font, Vector2(PAD, y), key,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.UI_DIM)
	draw_string(font, Vector2(PAD, y), action,
		HORIZONTAL_ALIGNMENT_RIGHT, size.x - PAD * 2.0, font_size, Palette.UI_DIM)

## md-skull_crossbones. Stands in for the words "killed by a", which are eleven
## characters of boilerplate on a panel about twenty-four wide -- enough that
## "killed by a kobold slinger" arrived as "killed by a kobold slin..".
##
## The FA skull is the obvious pick and is NOT in JetBrains Mono Nerd Font, so
## this is the Material Design one, which is also the family every other icon
## in the game comes from.
const SKULL := 0xF068C

## The panel font, with the icon font behind it.
##
## Text first and icons as the FALLBACK -- the opposite order to
## GlyphGrid.map_font(), which is icons first because the map is mostly icons.
## Here almost everything is words and one thing is a picture.
##
## Without this the skull renders as nothing at all: the sidebar loaded plain
## JetBrainsMono, which has no icon range. That is the same failure as the
## invisible shrine and brazier glyphs, which were also a real codepoint drawn
## with a font that did not carry it.
static func ui_font() -> Font:
	var text: FontFile = load("res://assets/fonts/JetBrainsMono-Regular.ttf")
	text.fallbacks = [load("res://assets/fonts/ofr_icons.ttf")]
	return text

## Swaps the words for the picture, in the RENDER layer where glyphs belong.
##
## Morgue.epitaph() is simulation code and deliberately knows nothing about
## fonts or codepoints -- it answers in words, and what those words look like
## is this side's problem. Only the "killed by" causes are touched; a fall or a
## walk back into daylight reads fine as written.
func _skullify(line: String) -> String:
	for prefix in ["killed by a ", "killed by an ", "killed by "]:
		if line.begins_with(prefix):
			return char(SKULL) + " " + line.substr(prefix.length())
	return line

## Same defence for the look panel, where a long item name would otherwise run
## through the frame.
func _fit(text: String) -> String:
	var limit := size.x - PAD * 2.0
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= limit:
		return text
	var out := text
	while out.length() > 1 and font.get_string_size(out + "..",
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > limit:
		out = out.substr(0, out.length() - 1)
	return out + ".."

func _describe() -> Array:
	var m := state.map
	if not m.in_bounds(hovered.x, hovered.y) or not m.is_explored(hovered.x, hovered.y):
		return ["unknown"]
	var out := []
	if m.is_visible(hovered.x, hovered.y):
		for e in state.entities:
			if e.alive and e.x == hovered.x and e.y == hovered.y:
				var tag := "%s  %d/%d hp" % [e.name, e.hp, e.max_hp]
				if e.regen > 0:
					tag += " *"
				out.append(tag)
				# What it is carrying, so a fight can be assessed before it is
				# committed to.
				# One line per piece. Comma-joining them overran the panel and
				# came out as "short sword, leather ..".
				for slot in e.equipped:
					out.append("  " + e.equipped[slot].display_name())
		for it in state.items_at(hovered.x, hovered.y):
			out.append(it.name)
	else:
		out.append("(remembered)")
	var tile := m.get_tile(hovered.x, hovered.y)
	if tile == Tiles.GRAVE and state.grave_at.has(hovered):
		# The whole reason the morgue is worth reading back: the cursor is
		# already how you interrogate anything else on the floor.
		for line in Morgue.epitaph(state.grave_at[hovered]):
			out.append(_skullify(String(line)))
	elif tile == Tiles.SHRINE:
		# Named only once its colour has been learned the hard way.
		out.append(state.shrine_label(int(state.shrine_at.get(hovered, 0))))
	else:
		out.append(String(Tiles.appearance_id(tile)).replace("_", " "))
	return out
