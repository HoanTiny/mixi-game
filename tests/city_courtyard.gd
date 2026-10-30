extends SceneTree
## Normal-map courtyard: hidden north-facing walls cannot intercept floor clicks.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	assert(world.city.street_upgrade and not world.city.pilot_active)
	world.set_process(false)
	world.game.s.queue.clear()
	world.game.s.used = 13.0 - float(world.game.cfg.dayStart)
	world.game.s["tips_seen"] = world.game.story.get("tips", []).map(func(t): return str(t.id))
	world.game.changed.emit()
	world.hud._close_tip()
	world.hud.close_location()
	world.zoom = 0.12
	var p: Dictionary = world.city.locs.xom_bo_me
	var n: Vector2 = p.normal
	var side := Vector2(n.y, -n.x)
	var yard: Vector2 = p.center - n * 6.0
	world.player.position = Vector3(yard.x, 0.14, yard.y)
	world.camera.position = world.player.position + world.cam_offset()
	world.camera.look_at(world.player.position + Vector3(0, 1.3, 0))
	world._update_cutaway(1.0)
	await physics_frame
	await process_frame
	for x in [-2.0, 0.0, 2.0]:
		var target: Vector2 = yard + side * x - n * 1.0
		assert(world.city.walkable(target), "Courtyard target must be walkable")
		world._handle_click(world.camera.unproject_position(Vector3(target.x, 0.14, target.y)))
		assert(world._target_loc == "" and world._target != null, "Hidden courtyard walls captured a floor click")
		assert(Vector2(world._target.x, world._target.z).distance_to(target) < 0.15, "Clicked courtyard floor was snapped elsewhere")
		world._target = null
	if "--capture" in OS.get_cmdline_user_args():
		world._update_tags(1.0)
		for frame in 30:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/city-courtyard-preview.png")
	world.zoom = 1.6
	world._update_cutaway(1.0)
	await physics_frame
	await process_frame
	for o in world.occluders:
		if o.has("architecture") and o.architecture.get("occluding_shell") != null:
			assert(o.architecture.front_walls.visible and o.architecture.occluding_shell.visible, "Overview must restore walls")
			for shape in o.architecture.shell_pick_shapes:
				assert(not shape.disabled, "Overview must restore location click shapes")
	print("PASS normal courtyard: three visible floor clicks, safe navigation and overview restoration")
	quit()
