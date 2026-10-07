extends SceneTree

## RENDERS the trader's counter to a PNG so its layout can be checked by eye.
## Needs a real display (not --headless) and an UNLOCKED screen -- a locked
## session draws nothing and the file comes out blank white.
##   SHOT_OUT=/tmp/trade.png SHOT_PILE=0 godot --path . --resolution 1600x900 -s tools/probes/screenshot_trade.gd
## SHOT_PILE picks the pile shown (0 = everything); SHOT_EMPTY=1 empties one.

## Renders the trade panel to a PNG. Scratch only; never shipped.
func _initialize() -> void:
	GameState.use_scratch_files("shot")
	_run.call_deferred()

func _run() -> void:
	var out := OS.get_environment("SHOT_OUT")
	var pile := int(OS.get_environment("SHOT_PILE"))
	var gs := GameState.new(4040)
	gs.new_game()
	gs.player.inventory.clear()
	gs.player.equipped.clear()
	var d := Item.make(&"dagger")
	d.upgrade()
	d.upgrade()
	gs.give_item(d)
	var coat := Item.make(&"leather_armour")
	gs.give_item(coat)
	gs.player.equipped[coat.slot] = coat
	gs.give_item(Item.make(&"potion_healing"))
	gs.give_item(Item.make(&"gem_fire"))
	var s1 := Item.make(&"sling")
	gs.give_item(s1)
	gs.trade_sell(gs.player.inventory.find(s1))
	gs.trader_stock.append({"item": Item.from_display_name("leather armour +2"),
		"relic": "x", "hero": "Rodney"})
	if OS.get_environment("SHOT_EMPTY") == "1":
		for i in range(gs.trader_stock.size() - 1, -1, -1):
			if (gs.trader_stock[i]["item"] as Item).slot == Item.Slot.OFFHAND:
				gs.trader_stock.remove_at(i)
	gs.trader_stock.append({"item": Item.from_display_name("short bow +1"),
		"relic": "y", "hero": "deep"})

	var t := TradePanel.new()
	root.add_child(t)
	t.state = gs
	t.size = Vector2(1600, 900)
	t.open()
	if pile > 0:
		t.set_pile(pile)
	else:
		t.side = TradePanel.SHELF
		t._at[TradePanel.SHELF] = t.shelf_rows().find(gs.trader_stock.size() - 3)
	for i in 6:
		await process_frame
	root.get_texture().get_image().save_png(out)
	# Leave nothing in the player's save folder (2026-10-07).
	GameState.clear_scratch_files()
	quit()
