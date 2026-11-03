extends "res://tests/opening_visual.gd"

func snapshot(name: String) -> void:
	for i in 8: await process_frame
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/prompt-preview/" + name + ".png")

func run() -> void:
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/prompt-preview"))
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	for i in 15: await process_frame
	world.set_process(false)
	var g = world.game
	settle(g)
	g.cfg.idleMinutesPerSecond = 0
	g.s.queue = []
	g.s.zone = "ta_hien"
	g.s.used = 12
	g.s.tips_seen = g.story.get("tips", []).map(func(t): return str(t.id))
	g._commit()
	var hud = world.hud
	hud._close_tip()
	world.player.position = world.door_of("ben_can")
	world.camera.position = world.player.position + world.cam_offset()
	world.camera.look_at(world.player.position + Vector3.UP, Vector3.UP)
	hud.set_prompt("")
	await snapshot("01_collapsed")
	check(hud._prompt.visible and not hud._prompt_details.is_visible_in_tree(), "street prompt defaults to collapsed")
	check(hud._prompt.size.y < 80, "collapsed prompt occupies one short strip")
	check(not hud._quick_ids.any(func(id): return str(id).begins_with("talk:")), "empty street anchor does not list unrelated NPCs")
	check(hud._quick.get_child_count() <= 3, "quick list stays bounded")
	hud.reveal_prompt()
	check(hud._prompt_details.is_visible_in_tree(), "explicit interaction reveals options")
	await snapshot("02_expanded")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE; esc.pressed = true
	hud._unhandled_key_input(esc)
	check(not hud._prompt_expanded, "Escape collapses options")
	g._commit()
	await snapshot("03_after_refresh")
	check(not hud._prompt_details.is_visible_in_tree() and hud._prompt.size.y < 80, "state refresh does not reopen or retain tall panel")
	hud.reveal_prompt()
	world.player.position.x += 1.0
	hud._process(0.01)
	check(not hud._prompt_expanded, "walking away collapses options")
	hud.reveal_prompt()
	g.s.zone = "phuc_tan"; g._commit()
	check(not hud._prompt_expanded, "changing zone collapses options")
	world.player.position = world.door_of("xom_bo_me")
	hud.set_prompt("xom_bo_me")
	world.interact()
	check(hud._prompt_expanded and hud.location_open() == "", "first E at venue reveals choices")
	check(hud._quick_ids == ["tam_rua", "com_voi_ba", "tra_tro_dem"], "home shortcuts remain available after expansion")
	world.interact()
	check(hud.location_open() == "xom_bo_me", "second E still opens venue")
	hud.close_location()
	check(not hud._prompt_expanded, "closing venue returns to collapsed prompt")
	root.size = Vector2i(900, 650)
	await snapshot("04_compact")
	check(hud._prompt.size.y < 80, "compact viewport also defaults to short prompt")
	check(not root.get_node("GameState")._persist, "preview never saves over player")
	world.queue_free()
	await process_frame
	print("Prompt declutter: ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	quit(0 if failures == 0 else 1)
