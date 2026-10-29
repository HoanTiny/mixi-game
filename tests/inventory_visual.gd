extends "res://tests/opening_visual.gd"
func capture(name: String) -> void:
	for i in 10: await process_frame
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/inventory-preview/"+name+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/inventory-preview"))
	root.size=Vector2i(1280,800)
	var world=load("res://scenes/world.tscn").instantiate(); root.add_child(world)
	for i in 14: await process_frame
	world.set_process(false)
	var g=world.game
	settle(g); g.cfg.idleMinutesPerSecond=0
	g.s.tips_seen=g.story.get("tips",[]).map(func(t): return str(t.id)); world.hud._close_tip()
	world.hud.close_location(); g.s.cash=200000
	g.s.zone="phuc_tan"; g.s.fatigue=30; g.s.needs.fed=40; g._commit()
	check(world.hud._tb_icons.has("backpack"),"HUD has backpack button")
	world.hud._tb_icons.backpack.button.pressed.emit()
	var bag=world.hud.inventory
	check(bag.visible and world.hud.blocking(),"backpack opens blocking bag popup")
	await capture("01_empty")
	bag._shop_tab.pressed.emit(); await process_frame
	bag._selected="banh_mi"; bag._quantity.value=3; bag.refresh()
	await capture("02_shop")
	bag._use.pressed.emit()
	check(g.item_count("banh_mi")==3 and g.s.cash==155000,"shop button buys correct stack")
	bag._selected="nuoc_loc"; bag._quantity.value=2; bag.refresh(); bag._use.pressed.emit()
	bag._selected="thuoc_cam"; bag._quantity.value=1; bag.refresh(); bag._use.pressed.emit()
	bag._selected="khan_uot"; bag.refresh(); bag._use.pressed.emit()
	bag._shop=false; bag._selected="banh_mi"; bag.refresh()
	await capture("03_bag")
	var hunger: float=g.need("fed"); var time: float=g.clock()
	bag._use.pressed.emit()
	check(g.item_count("banh_mi")==2 and g.need("fed")>hunger and g.clock()>time,"use button updates stack, needs and clock")
	check(bag._status.text.contains(g.hh(g.clock())),"popup status refreshes immediately")
	root.size=Vector2i(720,900)
	await capture("04_narrow")
	check(bag._panel.size.x<=root.size.x and bag._panel.size.y<=root.size.y,"popup fits narrow viewport")
	bag.close()
	check(not world.hud.blocking() and world.hud._root.visible,"closing restores game HUD/input")
	world.hud._perform("mua_tap_hoa")
	check(bag.visible and bag._shop,"contextual shop action opens purchase grid")
	bag.close()
	check(not root.get_node("GameState")._persist,"test cannot overwrite player save")
	world.queue_free(); await process_frame
	print("Inventory visual: ","PASS" if failures==0 else "FAIL"," failures=",failures)
	quit(0 if failures==0 else 1)
