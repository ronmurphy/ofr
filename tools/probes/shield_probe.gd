extends SceneTree

## What the three shield stones are actually worth, against the same monster.
##
## They compete for ONE permanent binding, so the only question that matters is
## how they compare to each other -- not whether each does something. Brad tunes
## from this; it is a measurement, not a test.
const SWINGS := 400

func _initialize() -> void:
	GameState.use_scratch_files("shields")
	print("  %d exchanges each, orc against a level-1 character\n" % SWINGS)
	print("  %-14s %8s %8s %8s %9s" % ["shield", "dealt", "taken", "returned", "net"])
	print("  " + "-".repeat(56))

	for tier in [&"buckler", &"kite_shield", &"tower_shield"]:
		for el in [&"", &"block", &"reflect", &"bash"]:
			var gs := GameState.new(31337)
			gs.new_game()
			var orc: Entity = null
			for e in GameState.BESTIARY:
				if e["name"] == "orc":
					orc = GameState.monster_from(e, 0, 0)
			orc.max_hp = 999999
			orc.hp = 999999
			var sh := Item.make(tier)
			if el != &"":
				sh.element = el
			gs.player.equipped[Item.Slot.OFFHAND] = sh
			gs.player.max_hp = 999999
			gs.player.hp = 999999

			var dealt := 0
			var taken := 0
			var returned := 0
			for i in SWINGS:
				var before_orc := orc.hp
				gs._attack(gs.player, orc)
				dealt += before_orc - orc.hp
				var before_me := gs.player.hp
				var before_them := orc.hp
				gs._attack(orc, gs.player)
				taken += before_me - gs.player.hp
				returned += before_them - orc.hp
			var name := "%s %s" % [tier, el if el != &"" else "(none)"]
			print("  %-14s %8d %8d %8d %9d" % [
				String(el) if el != &"" else "none", dealt, taken, returned,
				dealt + returned - taken])
		print("  " + "-".repeat(56))
	print("\n  net = what you dealt, plus what came back, minus what you took.")
	quit()
