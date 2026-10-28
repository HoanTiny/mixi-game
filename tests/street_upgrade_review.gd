extends SceneTree
## Graphical, repeatable review: -- --demo --street-demo --review=baseline|after
## Writes captures in tests/ and machine-specific measurements in .godot/.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var label := "after"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--review="):
			label = arg.trim_prefix("--review=").validate_filename()
	var started := Time.get_ticks_usec()
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var build_ms := (Time.get_ticks_usec() - started) / 1000.0
	world.game.s.used = 13.0 - float(world.game.cfg.dayStart)
	world.game.cfg.idleMinutesPerSecond = 0.0
	# Review a played save with tutorials acknowledged; leave all gameplay HUD visible.
	world.game.s["tips_seen"] = world.game.story.get("tips", []).map(func(t): return str(t.id))
	world.game.changed.emit()
	# Dismiss the first tutorial as a player would, retaining the actual gameplay HUD.
	world.hud._close_tip()
	if "--review-ride" in OS.get_cmdline_user_args():
		var destination: Vector3 = world.door_of("tiem_sau")
		var offer: Dictionary = world.game.delivery_offer("com_hanh", "Cơm Hạnh", "Khách phố mẫu", destination.x, 120.0, destination.z)
		world.game.delivery_accept(offer)
		world._update_ride()
	world.player.position = world.loc_point("com_hanh", 0.0, 0.8)
	world.camera.position = world.player.position + world.cam_offset()
	for frame in 60:
		await process_frame
	world.hud._close_tip()
	var samples: Array[float] = []
	var last := Time.get_ticks_usec()
	for frame in 180:
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append((now - last) / 1000.0)
		last = now
	var mean := 0.0
	for ms in samples:
		mean += ms / samples.size()
	samples.sort()
	var report := {
		"riding": world._riding,
		"label": label, "renderer": RenderingServer.get_current_rendering_method(),
		"resolution": str(root.size), "build_ms": build_ms, "mean_frame_ms": mean,
		"average_fps": 1000.0 / maxf(mean, 0.001),
		"p99_frame_ms": samples[mini(samples.size() - 1, ceili(samples.size() * 0.99) - 1)],
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		"static_memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC),
		"video_memory_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED),
		"sample_frames": samples.size(), "note": "Short in-engine sample, not an end-to-end gameplay benchmark; vsync/background scheduling may cap FPS."
	}
	for id in ["com_hanh", "tiem_sau", "xom_bo_me"]:
		world._target = null
		world.player.position = world.loc_point(id, 0.0, 0.8)
		world.camera.position = world.player.position + world.cam_offset()
		for frame in 20:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/%s-%s-preview.png" % [label, id])
	world.zoom = 0.65
	world.camera.position = world.player.position + world.cam_offset()
	for frame in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/%s-street-preview.png" % label)
	if world.city.pilot_active:
		world.zoom = 1.45
		world.player.position = Vector3(44, 0, -134.9)
		await _capture(world, "res://tests/%s-pilot-overview-preview.png" % label)
		world.zoom = 0.12
		var yard: Vector2 = world.city.pilot_courtyard
		world.player.position = Vector3(yard.x, 0.14, yard.y)
		await _capture(world, "res://tests/%s-courtyard-preview.png" % label)
		world.player.position = world.loc_point("com_hanh", 0.0, 0.8)
		world.game.s.used = 19.5 - float(world.game.cfg.dayStart)
		world.game.changed.emit()
		await _capture(world, "res://tests/%s-night-preview.png" % label)
		world.game.s.used = 13.0 - float(world.game.cfg.dayStart)
		world.game.s.today.rain = true
		world.game.changed.emit()
		await _capture(world, "res://tests/%s-rain-preview.png" % label)
	var f := FileAccess.open("res://.godot/street-review-%s.json" % label, FileAccess.WRITE)
	f.store_string(JSON.stringify(report, "\t"))
	print("REVIEW ", JSON.stringify(report))
	quit()

func _capture(world, path: String) -> void:
	world._target = null
	world.camera.position = world.player.position + world.cam_offset()
	world.hud._close_tip()
	for frame in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
