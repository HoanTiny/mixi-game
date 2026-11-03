extends SceneTree
## Actual pilot gameplay captures; no retouching or replacement assets.
## godot --path . -s res://tests/mobility_motion_review.gd -- --demo --street-demo

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_process(false)
	var game = world.game
	game.s.queue.clear()
	game.cfg.idleMinutesPerSecond = 0.0
	game.s.used = 13.0 - float(game.cfg.dayStart)
	game.s["tips_seen"] = game.story.get("tips", []).map(func(t): return str(t.id))
	game.changed.emit()
	world.hud._close_tip()
	world.hud.close_location()
	world.hud.hide()
	var destination: Vector3 = world.door_of("tiem_sau")
	var offer: Dictionary = game.delivery_offer("com_hanh", "Cơm Hạnh", "Khách phố mẫu", destination.x, 120.0, destination.z)
	game.delivery_accept(offer)
	world._update_ride()
	world.player.position = world.loc_point("com_hanh", -1.5, 1.2)
	world.player.rotation.y = 0.0
	world.walk_to(world.loc_point("tiem_sau", 0.0, 1.2))
	for frame in 10:
		world._process(1.0 / 60.0)
		await process_frame
	assert(absf(world._player_motion.bank) > 0.025, "Capture should show a real path turn")
	await _capture(world, "mobility-motion-turn")
	world._target = null
	for frame in 50:
		world._process(1.0 / 60.0)
		await process_frame
	assert(absf(world._player_motion.bank) < 0.001)
	await _capture(world, "mobility-motion-stop")
	game.s.used = 20.0 - float(game.cfg.dayStart)
	game.changed.emit()
	world._process(1.0 / 60.0)
	assert(world._ride_headlight.visible)
	for frame in 15:
		await process_frame
	await _capture(world, "mobility-motion-night")
	game.delivery_cancel()
	world._update_ride()
	world._process(1.0 / 60.0)
	assert(not world._ride_headlight.visible and world.player_body.position.is_zero_approx())
	print("PASS: in-world turn, stopped pose, night headlight and dismount reviewed with ", RenderingServer.get_current_rendering_method())
	quit()

func _capture(world, label: String) -> void:
	world.camera.position = world.player.position + Vector3(4.8, 3.2, 5.0)
	world.camera.look_at(world.player.position + Vector3(0, 0.88, 0))
	if label.ends_with("night"):
		var forward: Vector3 = world.player.basis.z
		world.camera.position = world.player.position + Vector3(6.4, 5.0, 7.0)
		world.camera.look_at(world.player.position + forward * 1.0 + Vector3(0, 0.65, 0))
	world._update_cutaway(1.0)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/%s-preview.png" % label)
	if label.ends_with("night"):
		# Check the actual light contribution, not just a node's visible flag.
		# Pause animation/particles so only the headlight changes between images.
		world.process_mode = Node.PROCESS_MODE_DISABLED
		Engine.time_scale = 0.0
		world._ride_headlight.visible = false
		await process_frame
		await RenderingServer.frame_post_draw
		var dark := root.get_texture().get_image()
		world._ride_headlight.visible = true
		await process_frame
		await RenderingServer.frame_post_draw
		var lit := root.get_texture().get_image()
		var brighter := 0
		for y in range(0, lit.get_height(), 2):
			for x in range(0, lit.get_width(), 2):
				if lit.get_pixel(x, y).get_luminance() - dark.get_pixel(x, y).get_luminance() > 0.025:
					brighter += 1
		print("HEADLIGHT visibly lit samples=", brighter)
		assert(brighter > 80, "Headlight must visibly illuminate the actual street")
		Engine.time_scale = 1.0
		world.process_mode = Node.PROCESS_MODE_INHERIT
