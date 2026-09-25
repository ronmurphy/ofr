class_name Sidebar
extends Control

## Character status, plus a look-panel describing whatever the mouse is over.
## Drawn by hand with the same font as the map so the whole screen reads as one
## surface rather than a game with a GUI bolted beside it.

@export var font: Font
## The icon face, loaded DIRECTLY rather than reached through font fallbacks.
##
## Reported from the itch build: every glyph in this panel came out as a tofu
## box spelling its own codepoint -- "0F0A7B" where the shirt should be -- while
## the map, the legend and the inventory drew theirs correctly.
##
## The asymmetry is the diagnosis. GlyphGrid.map_font() loads ofr_icons.ttf as
## the PRIMARY face; the legend and the inventory keep a separate `icon_font`
## and draw glyphs straight from it. Only this panel asked a text font to reach
## the icons through `fallbacks`, and only this panel failed -- so the font
## ships in the export (the map proves it) and it is fallback RESOLUTION that
## does not survive the web build for astral-plane codepoints.
##
## Desktop resolves those fallbacks happily, which is why the suite never saw
## it: `ui_font().has_char(SKULL)` passes headless and the exported game still
## draws a box.
@export var icon_font: Font
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

## The canonical key table, and now the only place that draws it is the legend.
##
## THREE COLUMNS: what a keyboard is told, what the action is, and the KEYCODE
## that makes the legend device-aware.
##
## There was a fourth -- a flag marking the handful once kept permanently in the
## sidebar. That block is gone (HerePanel answers "what do I press now" far
## better than a static list did), and when it went, the flag became something
## nothing read. The comment left behind claimed "the legend still reads it",
## which was simply false: the legend iterates every row. A flag nothing consults
## is a lie, and one defended by a wrong comment is the worse kind -- both were
## written by this session, eighteen hours apart.
##
## Without it this screen was the last place in the game still naming keys a
## handheld does not have: it read `w  swap reach / blade` on a Legion Go S,
## where the answer is RB. The first column is still what a keyboard player
## sees, because several rows are not one key at all -- "arrows / hjklyubn" is
## nine of them and "m  - +" is three. Where a single keycode exists, a pad
## player is shown the button bound to it instead.
##
## 0 means "no single key", and those rows keep their written form on both
## devices. `pad` is an override for the ones where the controller answer is
## real but is not a button: the stick walks, and saying "arrows" to somebody
## holding a Legion Go is simply wrong.
const KEYS := [
	["arrows / hjklyubn", "move", 0, "stick"],
	[". or 5", "wait / rest", KEY_PERIOD, ""],
	[">", "descend", KEY_GREATER, ""],
	["<", "ascend", KEY_LESS, ""],
	["x", "look", KEY_X, ""],
	["g", "pick up", KEY_G, ""],
	["i", "inventory", KEY_I, ""],
	["t", "torch", KEY_T, ""],
	["f / right-click", "shoot", KEY_F, ""],
	["w", "swap reach / blade", KEY_W, ""],
	# Essential only while somebody is standing with you, which the sidebar
	# cannot express -- so it lives in the full list, where a player goes
	# looking the first time an ally does something they did not want.
	["a", "ally: heel / loose", KEY_A, ""],
	## Worth finding: a shut door buys a turn against a goblin, three against
	## a bear, and nothing at all against a rabbit.
	["c", "close a door", KEY_C, ""],
	["f (no bow)", "throw", KEY_F, ""],
	["p", "pray at a shrine", KEY_P, ""],
	["m  - +", "sound", 0, ""],
	["v", "letters / symbols / pictures", KEY_V, ""],
	# Motion, and it is an accessibility setting before it is a taste one --
	# effects like these stop some people playing games at all.
	["e", "still / simple / full", KEY_E, ""],
	["o", "the map", KEY_O, ""],
	["esc", "menu", KEY_ESCAPE, ""],
	["click", "travel", 0, "--"],
]

## What to show in the first column, for whoever is holding whatever.
##
## Falls back to the written form whenever there is no single key, or the pad has
## nothing bound to it -- an action a controller cannot reach should say so by
## naming the key honestly, not by going blank.
static func key_label(row: Array, cfg: PadConfig, on_pad: bool) -> String:
	if not on_pad:
		return String(row[0])
	# The stick is not a button and has no binding, so it is named here.
	if String(row[1]) == "move":
		return String.chr(PadConfig.STICK_GLYPH)
	if row.size() > 3 and String(row[3]) != "":
		return String(row[3])
	if int(row[2]) != 0 and cfg != null:
		var shown := cfg.icon(int(row[2]), true)
		if shown != "":
			return shown
	return String(row[0])

## Live bindings and which device is in the player's hands, both set by main.gd
## so the help line can name a BUTTON on a handheld.
var pad_cfg: PadConfig = null
var pad_input := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font == null:
		font = ui_font()
	if icon_font == null:
		icon_font = load("res://assets/fonts/ofr_icons.ttf")
	if font_bold == null:
		font_bold = load("res://assets/fonts/JetBrainsMono-Bold.ttf")

func _process(_delta: float) -> void:
	if state == null:
		return
	var hp := state.player.hp
	if _last_hp >= 0 and hp < _last_hp:
		_hit_at = Time.get_ticks_msec() / 1000.0
	_last_hp = hp

## Breathing room between a row's left text and its right-aligned number.
const GAP := 8.0

func _draw() -> void:
	if state == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Palette.UI_PANEL_BG, true)
	draw_rect(Rect2(Vector2.ZERO, size), Palette.UI_FRAME, false, 1.0)

	var y := PAD + font.get_ascent(font_size)

	# Who you are, where the game's own name used to be.
	#
	# "OFR" told you something you already knew. A name earns the line because
	# it is the only place the name is visible during a run -- and because the
	# name matters later: it goes on your gravestone, and a future run's bone
	# ally will carry it.
	_line(font_bold, y, state.player_name if state.player_name != "" else "OFR",
		Palette.STAIRS)
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
		_gear_row(y, "weapon", held, " r%d x%d" % [reach, held.ammo],
			held.ammo > 0)
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
		_gear_row(y, "weapon", held, "  x%d" % held.charges,
			held.charges > GameState.RING_LOW)
	elif held != null and reach > 1:
		_gear_row(y, "weapon", held, "  r%d" % reach, true)
	elif held != null:
		_gear_row(y, "weapon", held, "", false)
	else:
		_stat_row(y, "weapon", "--", false)
	y += LINE
	_gear_slot_row(y, "armour", p, Item.Slot.ARMOR, false)
	y += LINE
	# Shown even when empty, so the slot's existence is discoverable without
	# having to find a shield first.
	_gear_slot_row(y, "offhand", p, Item.Slot.OFFHAND,
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
	y += LINE

	# The flare's prize, while it burns: what it would fill a brazier to right
	# now. Its own row because the sidebar is too narrow for both on one line,
	# and because this is the number the race is run against.
	if state.torch_flare > 0:
		var kindle := GameState.flare_kindle(state.torch_flare)
		draw_string(font, Vector2(PAD, y), "kindles",
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.UI_DIM)
		draw_string(font, Vector2(PAD, y), str(kindle) if kindle > 0 else "--",
			HORIZONTAL_ALIGNMENT_RIGHT, size.x - PAD * 2.0, font_size,
			Palette.AMULET if kindle > 0 else Palette.UI_DIM)
		y += LINE

	# The party, and ONLY when there is one. A row that is empty nine tenths of
	# the time is furniture; this costs no space at all until somebody is
	# standing with you.
	#
	# A LINE, NOT A BAR, and that is the point of it. Your own HP gets a bar
	# because a bar means "this refills". An ally's does not -- nothing in the
	# game heals one -- so it is a budget being spent, closer to torch turns or
	# arrows than to health, and a bare number reads as the countdown it is.
	# The map already says WOUNDED: `_draw_wound` washes any entity orange and
	# then red, allies included. What it cannot say is how much is left.
	var party := state.allies()
	if not party.is_empty():
		y += LINE * 0.7
		_line(font_bold, y, "STANDING WITH YOU", Palette.UI_DIM)
		y += LINE
		for mate in party:
			var stance_text := "heel" if mate.stance == Entity.Stance.HEEL \
				else "loose"
			# RESERVE the hit points before fitting the name.
			#
			# `_fit` takes that argument for exactly this shape of row and the
			# first version of this line did not pass it, so a long name was
			# fitted to the WHOLE panel and the right-aligned numbers drew on
			# top of it: "risen killer rabbit" plus "loose" plus "3/3" came out
			# as a collision, reported from play. The gear rows learned this
			# once already -- a label measured against a limit that something
			# else is also using is not measured at all.
			var hp_text := "%d/%d" % [mate.hp, mate.max_hp]
			var reserve := font.get_string_size(hp_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + GAP
			# Their own colour, so the line and the figure on the map are
			# obviously the same creature.
			draw_string(font, Vector2(PAD, y),
				_fit("%s  %s" % [mate.name, stance_text], reserve),
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.ALLY)
			draw_string(font, Vector2(PAD, y), hp_text,
				HORIZONTAL_ALIGNMENT_RIGHT, size.x - PAD * 2.0, font_size,
				Palette.ALLY if mate.wound() == Entity.Wound.WHOLE
				else Palette.BLOODIED)
			y += LINE
	y += LINE * 0.7

	# Look panel. Retitled in look mode so it is obvious the keys are now
	# driving a cursor rather than the player.
	if aiming:
		_line(font_bold, y, "SHOOTING AT", Palette.AIM_OK)
	elif look_mode:
		_line(font_bold, y, "LOOKING AT", Palette.CURSOR)
	else:
		_line(font_bold, y, "UNDER CURSOR", Palette.UI_DIM)
	y += LINE
	for entry in _describe():
		# A line is either words, or a picture and words. Gear and loot get the
		# picture; creatures, terrain and epitaphs stay text.
		#
		# Brad's call, and the reason is that the alternative is a parser: to
		# glyph EVERYTHING here you would have to pick the pictures back out of
		# sentences like "orc  16/16 hp" and "long dead, and still angry". Some
		# lines are simply easier to read as words, and a creature's glyph is
		# already on the map under the cursor you are pointing with.
		if entry is Dictionary:
			_icon_line(y, String(entry["glyph"]), String(entry["text"]),
				float(entry.get("indent", 0.0)))
		else:
			_line(font, y, _fit(String(entry)), Palette.UI_TEXT)
		y += LINE

	# Derived from the list, not a hand-counted constant. Adding a row to KEYS
	# once pushed the last baseline exactly onto the frame with a hard-coded
	# number -- the fourth time something in this panel had overrun its edge
	# because a count had to be kept in step with a list by hand.
	# ONE LINE WHERE A LIST USED TO BE.
	#
	# The block taught Brad the keys and then went on occupying a third of the
	# panel to remind him of something he knew. `HERE` answers "what do I press
	# NOW" better than a static list ever did, and it ends with the way to the
	# full reference on every square -- so all this has to do is make sure
	# somebody staring at the SIDEBAR still finds it.
	#
	# `Sidebar.KEYS` stays: the legend screen renders the complete list from it,
	# and that is what it was always really for.
	#
	# Named through the bindings, so it reads "press Back for help" on a
	# handheld. A hint that names a key the player's device does not have is the
	# exact bug this panel has been fixing all week.
	y = size.y - PAD - LINE
	var how := PadConfig.key_name(KEY_QUESTION)
	if pad_cfg != null:
		how = pad_cfg.icon(KEY_QUESTION, pad_input)
	PadGlyphs.draw(self, Vector2(PAD, y), "press %s for help" % how, font,
		font_size, Palette.UI_DIM)

func _line(f: Font, y: float, text: String, color: Color) -> void:
	draw_string(f, Vector2(PAD, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

## An equipment slot, drawn with its picture at picture size -- or "--" when
## the slot is empty, which has no picture to draw.
func _gear_slot_row(y: float, label: String, p: Entity, slot: int,
		boosted: bool) -> void:
	var item = p.equipped.get(slot, null)
	if item == null:
		_stat_row(y, label, "--", boosted)
		return
	_gear_row(y, label, item, "", boosted)

## The picture for the kind, the word for which one.
##
## Brad's call, and it is the same trade `_skullify` already makes on the death
## line: a glyph says "ring" in one cell where the words needed eleven, and the
## eleven were what pushed "ring of the rat  x159" through the word "weapon".
## Truncation then ate the answer to the only question the row was asked --
## WHICH ring -- and left "ring of t..".
##
## The theme's glyph rather than a literal, so the panel follows the view mode
## like everything else: an axe in icon mode, ")" in letters, "+" in symbols.
## The row still reads in all three, because the word in brackets was always
## carrying the distinction.
func _gear_glyph(item: Item) -> String:
	return String(RenderTheme.active().appearance(item.appearance).get("ch", "?"))

## Everything except the picture. Separate so the picture can be drawn at icon
## size beside it rather than squashed to letter size inside it.
func _gear_words(item: Item) -> String:
	return " (%s)" % item.tag()

## The facts about a piece that cannot be recovered by looking at it.
##
## Kept apart from the tag because they are protected from truncation and the
## tag is not. Which bow you hold is already said twice over -- by the glyph and
## by the reach -- so the tag is the cheapest thing on the row to lose. A "+2"
## and a bound gem are not recoverable from anything else on screen, and the gem
## cost a chest.
func _gear_up(item: Item) -> String:
	var up := item.upgrade_level()
	return "" if up <= 0 else " +%d" % up

func _gear_el(item: Item) -> String:
	return "" if item.element == &"" else " %s" % item.element


## One equipment row: the picture, then whatever of the words will fit.
func _gear_row(y: float, label: String, item: Item, numbers: String,
		boosted: bool) -> void:
	var glyph := _gear_glyph(item)
	_draw_icon_row(y, label, glyph, gear_row_words(label, glyph,
		_gear_words(item), _gear_up(item), _gear_el(item), numbers), boosted)

## Which face can actually draw this character.
##
## Every measurement and every draw of a glyph goes through here, so a width
## computed for one face can never be used to position text drawn in another.
func _face_for(ch: String) -> Font:
	return icon_font if GlyphTheme.is_icon(ch) and icon_font != null else font

## Label, icon and pre-fitted words, the last two right-aligned as a unit.
##
## The plain row draws label and value as two strings at font_size, and an icon
## inside that string comes out the size of a letter -- reported from play as
## the gear glyphs being tiny next to the same pictures on the map, which go
## through GlyphTheme.draw_size and are 1.55x a letter. The legend and the
## inventory already drew theirs that way; the sidebar was the one panel that
## did not.
##
## The vertical nudge is the legend's, for the legend's reason: an icon has no
## x-height, so sitting it on the text baseline hangs it low.
func _draw_icon_row(y: float, label: String, glyph: String, shown: String,
		boosted: bool) -> void:
	draw_string(font, Vector2(PAD, y), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.UI_DIM)
	var tint: Color = Palette.HP_GOOD if boosted else Palette.UI_TEXT
	var gs := GlyphTheme.draw_size(glyph, font_size)
	var gw := _face_for(glyph).get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, gs).x
	var tw := font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var right := size.x - PAD
	draw_string(font, Vector2(right - tw, y), shown,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, tint)
	draw_string(_face_for(glyph), Vector2(right - tw - gw, y + (font_size - gs) * 0.35),
		glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, gs, tint)

## Label left, value right-aligned. `boosted` tints the value so a bonus from
## equipment is visible at a glance without reading the equipment lines.
func _stat_row(y: float, label: String, value: String, boosted: bool) -> void:
	draw_string(font, Vector2(PAD, y), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Palette.UI_DIM)
	var taken := font.get_string_size(label + "  ", HORIZONTAL_ALIGNMENT_LEFT,
		-1, font_size).x
	draw_string(font, Vector2(PAD, y), _fit(value, taken),
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
	# duplicate() for the reason spelled out in GlyphGrid.map_font(): load()
	# returns a shared instance, both functions set fallbacks on it pointing at
	# each other, and the resulting cycle made Godot discard whichever
	# assignment came second. A private copy keeps the two independent.
	var text: FontFile = load("res://assets/fonts/JetBrainsMono-Regular.ttf").duplicate()
	text.fallbacks = [load("res://assets/fonts/ofr_icons.ttf")]
	return text

## Swaps the words for the picture, in the RENDER layer where glyphs belong.
##
## Morgue.epitaph() is simulation code and deliberately knows nothing about
## fonts or codepoints -- it answers in words, and what those words look like
## is this side's problem. Only the "killed by" causes are touched; a fall or a
## walk back into daylight reads fine as written.
## Answers a picture-line for a death cause, or the words unchanged.
##
## It used to return ONE STRING with the skull inside it, which meant the skull
## could only ever be drawn with whatever face drew the sentence -- the text
## face, reaching the icon through fallbacks. That is exactly the resolution
## that fails in the web export, so "killed by" has been a tofu box on itch
## since the day it shipped, and nobody saw it because you only meet that line
## when you die and you are reading the cause, not the picture.
##
## As a {glyph, text} line the panel draws the skull from the icon face
## directly, the same way the map and the legend always have.
func _skullify(line: String) -> Variant:
	for prefix in ["killed by a ", "killed by an ", "killed by "]:
		if line.begins_with(prefix):
			return {"glyph": char(SKULL), "text": line.substr(prefix.length()),
				"indent": 0.0}
	return line

## Same defence for the look panel, where a long item name would otherwise run
## through the frame.
## `reserve` is whatever else is already drawn on this line.
##
## It defaulted to nothing, which meant a right-aligned value was fitted to the
## WHOLE panel while a left-aligned label sat in the same row -- so a long
## enough value walked straight over the label. Reported from play: "ring of
## the rat  x159" overdrew the word "weapon". `_key_row` has always measured
## its alignment for exactly this reason; `_stat_row` never did.
func _fit(text: String, reserve: float = 0.0) -> String:
	var limit := size.x - PAD * 2.0 - reserve
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= limit:
		return text
	var out := text
	while out.length() > 1 and font.get_string_size(out + "..",
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > limit:
		out = out.substr(0, out.length() - 1)
	return out + ".."

## How much width the words have left, once the label and the icon have taken
## theirs.
func _room_for(label: String, glyph: String) -> float:
	var gs := GlyphTheme.draw_size(glyph, font_size)
	var gw := _face_for(glyph).get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, gs).x
	var lw := font.get_string_size(label + "  ", HORIZONTAL_ALIGNMENT_LEFT,
		-1, font_size).x
	return size.x - PAD * 2.0 - lw - gw

## A gear row, assembled by dropping the least valuable part first.
##
## A fully worked bow carrying a gem wants glyph, tag, "+2", the element, the
## reach and the ammo count, and that does not fit a 256px panel at any icon
## size. So the row is built from what matters rather than truncated from
## whichever end the text happens to run out of:
##
##     numbers   reach, ammo, charges -- the reason the row carries a suffix,
##               and what you act on
##     upgrade   "+2" -- not recoverable by looking at anything else
##     element   a bound gem cost a chest and shows up nowhere else on screen
##     tag       which one it is -- already said by the glyph, and for a
##               launcher said again by the reach. The cheapest thing to lose.
##
## Truncating from the right got this exactly backwards: it ate the ammo count
## to save the word "short", when the picture beside it already said "bow".
func gear_row_words(label: String, glyph: String, tag: String, up: String,
		el: String, numbers: String) -> String:
	var avail := _room_for(label, glyph)
	for candidate in [tag + up + el + numbers, up + el + numbers,
			up + numbers, numbers]:
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT,
				-1, font_size).x <= avail:
			return candidate
	return _fit(numbers, size.x - PAD * 2.0 - avail)

## One look-panel line that leads with a picture.
##
## Same bargain as the gear rows in the stats block: the glyph at icon size
## because that is how it is drawn everywhere else, and the words fitted to
## whatever is left so a long name cannot run through the frame.
func _icon_line(y: float, glyph: String, text: String, indent: float) -> void:
	var gs := GlyphTheme.draw_size(glyph, font_size)
	var gw := _face_for(glyph).get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, gs).x
	var x := PAD + indent
	draw_string(_face_for(glyph), Vector2(x, y + (font_size - gs) * 0.35), glyph,
		HORIZONTAL_ALIGNMENT_LEFT, -1, gs, Palette.UI_TEXT)
	draw_string(font, Vector2(x + gw + 4.0, y),
		_fit(text, indent + gw + 4.0), HORIZONTAL_ALIGNMENT_LEFT, -1,
		font_size, Palette.UI_TEXT)

## A carryable, as a picture and its name.
func _item_line(item: Item, indent: float) -> Dictionary:
	return {
		"glyph": String(RenderTheme.active().appearance(item.appearance).get("ch", "?")),
		"text": item.display_name(),
		"indent": indent,
	}

func _describe() -> Array:
	var m := state.map
	if not m.in_bounds(hovered.x, hovered.y) or not m.is_explored(hovered.x, hovered.y):
		return ["unknown"]
	var out := []
	if m.is_visible(hovered.x, hovered.y):
		for e in state.entities:
			if e.alive and e.x == hovered.x and e.y == hovered.y:
				var tag := "%s  %d/%d hp" % [e.name, e.hp, e.max_hp]
				# WHOSE SIDE IT IS ON, which this panel never said.
				#
				# Reported from a real death: Brad fought in a room holding two
				# skeletons raised from his own morgue, both wearing his own
				# old gear -- "B", his bone ally, and "risen BradTest", a
				# hostile off a gravestone. One word apart. The map colours
				# allies green, but the moment he died the map was gone and all
				# he had was this panel, which told him a name, hit points and
				# a kit, and nothing about which of them was trying to kill him.
				if e.faction == Entity.Faction.PLAYER and not e.is_player:
					tag += "  (yours)"
				if e.regen > 0:
					tag += " *"
				out.append(tag)
				# What it is carrying, so a fight can be assessed before it is
				# committed to.
				# One line per piece. Comma-joining them overran the panel and
				# came out as "short sword, leather ..".
				for slot in e.equipped:
					out.append(_item_line(e.equipped[slot], 10.0))
		for it in state.items_at(hovered.x, hovered.y):
			out.append(_item_line(it, 0.0))
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
