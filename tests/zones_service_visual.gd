extends "res://tests/opening_visual.gd"
## Integration: physical zone travel -> HUD -> real service modal -> state settlement.

func capture(name: String) -> void:
	for i in 8: await process_frame
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/zones-service-preview/" + name + ".png")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/zones-service-preview"))
	root.size = Vector2i(1280, 800)
	root.gui_embed_subwindows = true
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	for i in 14: await process_frame
	world.set_process(false)
	var g = world.game
	g.cfg.idleMinutesPerSecond = 0.0
	settle(g)
	g.s.tips_seen = g.story.get("tips", []).map(func(t): return str(t.id))
	world.hud._close_tip()
	world.hud.close_location()
	g.s.used = 10.0
	g.s.needs_t = 16.0
	g.s.fatigue = 5.0
	for key in g.s.needs: g.s.needs[key] = 95.0
	g._commit()
	world.hud.set_prompt("xom_bo_me")
	check(g.MapManager.current(g) == "phuc_tan", "starts in Phuc Tan")
	await capture("01_phuc_tan")
	world.hud._open_zones()
	await capture("02_zone_menu")
	world.hud._zone_menu.hide()
	var before_time: float = g.clock()
	check(world.change_zone("ta_hien"), "world moves to Ta Hien")
	check(g.clock() > before_time and g.s.fatigue >= 10.0, "travel charges time and stamina")
	check(world.player.position.distance_to(world.door_of("ben_can")) < 0.2, "actual arrival matches zone")
	check(world.hud._quick_ids.has("bia_service"), "service action rendered in bottom HUD")
	await capture("03_ta_hien")
	for button in world.hud._zone_people.get_children():
		if button is Button:
			check(button.text != "" and button.size.x >= 70.0, "NPC button has readable name and width")
	root.size = Vector2i(720, 900)
	await capture("03b_ta_hien_narrow")
	root.size = Vector2i(1280, 800)
	await process_frame
	world.hud._perform("bia_service")
	var mini = world.hud.minigame
	check(is_instance_valid(mini), "action opens real minigame modal")
	if not is_instance_valid(mini): quit(1); return
	await capture("04_service_intro")
	mini.start()
	mini.set_process(false)
	mini.phase = 0.52
	await capture("05_service_play")
	root.size = Vector2i(720, 900)
	await capture("05b_service_narrow")
	root.size = Vector2i(1280, 800)
	await process_frame
	# Drive the actual view lifecycle; core result and timer logic have dedicated unit coverage.
	for i in int(mini.cfg.get("target", 12)):
		mini.attempted = false
		mini.phase = 0.52
		mini.hit()
	check(mini.state == "end", "serving target reaches results panel")
	await capture("06_service_result")
	var cash: int = g.s.cash
	mini._first_button.pressed.emit()
	await create_timer(2.5).timeout
	check(world.hud.minigame == null and g.today_count("bia_service") == 1, "HUD commits one completed shift")
	check(g.s.cash > cash and g.need("clean") < 95.0 and g.s.fatigue > 10.0, "reward and survival update together")
	check(not g.action_status(g.get_action("bia_service")).ok, "shift cannot be farmed again same day")
	world.hud.close_location()
	check(world.change_zone("cho_dau_moi"), "can visit labor zone after shift")
	await capture("07_labor_zone")
	check(not world.hud._quick_ids.has("bia_service"), "stale service choice disappears in labor zone")
	check(not root.get_node("GameState")._persist, "test never writes player saves")
	var standalone = load("res://scripts/game_logic.gd").new()
	standalone.load_data()
	standalone.new_game("full")
	settle(standalone)
	standalone.s.zone = "ta_hien"
	var observed: Array = []
	var observe_save := func(): observed.append(str(standalone.s.zone))
	standalone.changed.connect(observe_save)
	standalone.finish_day()
	check(not observed.is_empty() and observed[0] == "phuc_tan", "autosave sees morning zone without a World callback")
	standalone.changed.disconnect(observe_save)
	world.queue_free()
	await process_frame
	print("Zones + service visual: ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	quit(0 if failures == 0 else 1)
