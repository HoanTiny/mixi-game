extends SceneTree
## Actual Compatibility screenshots of every story location and city context.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var start := Time.get_ticks_msec()
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	assert(world.city.street_upgrade and not world.city.pilot_active)
	var build_ms := Time.get_ticks_msec() - start
	world.game.s.queue.clear()
	world.game.s.used = 13.0 - float(world.game.cfg.dayStart)
	world.game.cfg.idleMinutesPerSecond = 0.0
	world.game.s["tips_seen"] = world.game.story.get("tips", []).map(func(t): return str(t.id))
	world.game.changed.emit()
	world.hud._close_tip()
	world.zoom = 0.12
	var records := []
	for id in world.LOCATIONS:
		world._target = null
		world._travel_pace.reset()
		world.player.position = world.loc_point(id, 0.0, 1.2)
		world.player.rotation.y = PI
		world.camera.position = world.player.position + world.cam_offset()
		world.hud.close_location()
		for frame in 90:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/city-%s-preview.png" % id)
		records.append({"location": id, "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "primitives": Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
	world.zoom = 0.12
	var p: Dictionary = world.city.locs.xom_bo_me
	var court: Vector2 = p.center - p.normal * 6.0
	world.player.position = Vector3(court.x, 0.14, court.y)
	await _capture(world, "courtyard")
	world.player.position = world.loc_point("ben_can", 0.0, 1.2)
	world.game.s.used = 19.5 - float(world.game.cfg.dayStart)
	world.game.changed.emit()
	await _capture(world, "night")
	world.player.position = world.loc_point("cho_cau_nho", 0.0, 1.2)
	world.game.s.used = 13.0 - float(world.game.cfg.dayStart)
	world.game.s.today.rain = true
	world.game.changed.emit()
	await _capture(world, "rain")
	world.game.s.today.rain = false
	world.game.changed.emit()
	world.zoom = 1.6
	world.player.position = Vector3(0, 0, -85)
	await _capture(world, "overview")
	world.zoom = 0.12
	world.player.position = world.loc_point("com_hanh", 0.0, 1.2)
	world.camera.position = world.player.position + world.cam_offset()
	for frame in 60:
		await process_frame
	var samples: Array[float] = []
	var last := Time.get_ticks_usec()
	for frame in 180:
		await process_frame
		var now := Time.get_ticks_usec()
		samples.append(float(now - last) / 1000.0)
		last = now
	var total := 0.0
	for ms in samples:
		total += ms
	samples.sort()
	var result := {"build_ms": build_ms, "renderer": RenderingServer.get_current_rendering_method(), "mean_ms": total / samples.size(), "p99_ms": samples[178], "coverage": world.area.architecture_counts, "locations": records, "note": "180-frame sample, not a whole-city benchmark"}
	FileAccess.open("res://build/city-review.json", FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print("CITY REVIEW ", JSON.stringify(result))
	quit()

func _capture(world, tag: String) -> void:
	world.camera.position = world.player.position + world.cam_offset()
	for frame in 90:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/city-%s-preview.png" % tag)
