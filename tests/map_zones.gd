extends "res://tests/opening_visual.gd"
## Run with -- --demo --demo-full; add --capture with a renderer for a screenshot.
const Zones := preload("res://scripts/systems/map_manager.gd")

func run() -> void:
	# Without --demo the world opens on the title screen over the player's real save.
	if root.get_node("GameState")._persist:
		push_error("Map zones: run with -- --demo --demo-full so the test cannot save over player progress")
		quit(1)
		return
	# A script error aborts run() before quit(); fail instead of idling forever.
	create_timer(120).timeout.connect(func(): push_error("Map zones: did not finish"); quit(1))
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	for i in 12: await process_frame
	world.set_process(false)
	var g = world.game
	settle(g)
	g.cfg.idleMinutesPerSecond = 0.0
	g.s.used = 2.0
	g.s.needs_t = g.clock()
	g.s.fatigue = 10.0
	for key in g.s.needs: g.s.needs[key] = 80.0
	g.s.zone = "phuc_tan"
	g._commit()
	world.hud._close_tip()
	check(Zones.definitions(g).size() == 3, "three authored zones")
	check(world.zones_enabled(), "Hanoi world enables navigation")
	check(Zones.current(g) == "phuc_tan", "default home zone")
	var start: float = g.clock()
	var fatigue: float = g.s.fatigue
	check(world.change_zone("ta_hien"), "travel to Ta Hien succeeds")
	check(absf(g.clock() - start - 20.0 / 60.0) < 0.0001, "travel charges twenty minutes once")
	check(float(g.s.fatigue) >= fatigue + 5.0, "travel charges five stamina plus configured hourly decay")
	check(world.player.position.distance_to(world.door_of("ben_can")) < 0.1, "physical arrival at beer street")
	check(Zones.current(g) == "ta_hien", "zone persisted in game state")
	check(Zones.action_block(g, {"location": "xom_bo_me"}) != "", "stale home action blocked")
	check(Zones.action_block(g, {"location": "ben_can"}) == "", "local service action allowed")
	check(world.hud._zone_button.text.contains("Tạ Hiện"), "HUD refreshes zone name")
	check(world.hud._quick.get_child_count() > 0, "contextual action list rendered")
	start = g.clock(); fatigue = g.s.fatigue
	check(not world.change_zone("ta_hien"), "same-zone travel rejected")
	check(g.clock() == start and float(g.s.fatigue) == fatigue, "rejection costs nothing")
	check(world.change_zone("cho_dau_moi"), "travel to labor district")
	check(absf(g.clock() - start - 0.5) < 0.0001, "longer route charges thirty minutes")
	check(world.player.position.distance_to(world.door_of("bai_boc_vac")) < 0.1, "physical arrival at labor yard")
	var old_zone: String = g.s.zone
	g.s.fatigue = 98.0
	start = g.clock()
	check(not world.change_zone("phuc_tan"), "low stamina cannot travel")
	check(g.clock() == start and g.s.zone == old_zone, "failed trip preserves state")
	g.s.fatigue = 10.0
	g.s.used = g.day_end() - float(g.cfg.dayStart) - 0.1
	check(not world.change_zone("phuc_tan"), "not enough time cannot travel")
	g.s.used = 6.0; g.s.needs_t = g.clock(); g.s.queue.clear()
	check(world.change_zone("phuc_tan"), "return home")
	g.s.zone = "invalid"
	Zones.migrate(g)
	check(g.s.zone == "phuc_tan", "unknown saved zone migrates safely")
	g.s.zone = "ta_hien"
	Zones.migrate(g)
	check(g.s.zone == "ta_hien", "valid saved zone is retained")
	g.s.zone = "phuc_tan"; g._commit()
	world.hud._open_zones()
	check(world.hud.blocking(), "zone menu gates world input")
	check(not world.change_zone("ta_hien"), "modal blocks outside travel callbacks")
	world.hud._zone_menu.hide()
	# A walking arrival must refresh state and action keys before pressing E.
	g.s.used = 12.0; g.s.needs_t = g.clock(); g.s.queue.clear()
	g.s.fatigue = 10.0
	g._commit(); settle(g)
	start = g.clock(); fatigue = g.s.fatigue
	world.player.position = world.door_of("ben_can")
	world._process(0.0)
	check(Zones.current(g) == "ta_hien", "walking arrival updates zone without interact")
	check(world.hud._zone_button.text.contains("Tạ Hiện"), "walking arrival refreshes zone label")
	check(world.hud._quick_ids.has("bia_service"), "walking arrival refreshes numbered service action")
	check(g.clock() == start and float(g.s.fatigue) == fatigue, "walking context does not charge fast-travel costs")
	world.hud._open_zones()
	world.player.position = world.door_of("xom_bo_me")
	world._process(0.0)
	check(Zones.current(g) == "ta_hien", "open modal prevents context changes")
	world.hud._zone_menu.hide()
	world._process(0.0)
	check(Zones.current(g) == "phuc_tan", "walking home updates context after modal closes")
	check(not world.hud._quick_ids.has("bia_service"), "old district action key removed")
	if "--capture" in OS.get_cmdline_user_args():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/zones-preview"))
		world.hud._open_zones()
		for i in 8: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/zones-preview/navigation.png")
	print("Map zones: ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	world.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
