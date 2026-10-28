extends SceneTree
## godot --headless --path . -s res://tests/street_prototype.gd -- --demo --street-demo
## Add --capture with a graphical renderer to save three review screenshots.
const City := preload("res://scripts/world/real_city.gd")
const Builder := preload("res://scripts/realmap/area_builder.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var city := City.new("hn_pho_co")
	var ids := ["com_hanh", "tiem_sau", "xom_bo_me"]
	for id in ids:
		var door := city.loc_door(id)
		assert(city.walkable(door), "Blocked prototype door: " + id)
		var path := city.path(city.loc_door("xom_bo_me"), door)
		assert(id == "xom_bo_me" or not path.is_empty(), "No route to " + id)
		if "--street-demo" in OS.get_cmdline_user_args():
			assert(city.loc_door("xom_bo_me").distance_to(door) < 40.0, "Prototype locations are not grouped")
	# A building beside the center ray must still yield to the wider camera corridor.
	var poly := PackedVector2Array([Vector2(1.6, 3), Vector2(3.2, 3), Vector2(3.2, 6), Vector2(1.6, 6)])
	assert(Builder.ray_cap(poly, 10.0, Vector3(0, 8, 12), Vector3.ZERO) < 10.0)
	assert(is_inf(Builder.ray_cap(poly, 10.0, Vector3(20, 8, 12), Vector3(20, 0, 0))))
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	await physics_frame
	if city.pilot_active:
		world.set_process(false)
		# Click through the actual mouth of the alley: a full-lot collider would
		# redirect this to the lodging UI instead of allowing a courtyard path.
		var mouth: Vector2 = city.pilot_walk_points.home
		world.player.position = Vector3(mouth.x, 0, mouth.y)
		world.camera.position = world.player.position + world.cam_offset()
		world.camera.look_at(world.player.position + Vector3(0, 1.3, 0))
		var yard: Vector2 = city.pilot_courtyard
		world._handle_click(world.camera.unproject_position(Vector3(yard.x, 0.14, yard.y)))
		assert(world._target != null and world._target_loc == "", "Alley click intercepted by lodging box")
		assert(Vector2(world._target.x, world._target.z).distance_to(yard) < 0.3, "Click must target yard")
		var route := ["home", "food", "repair", "courtyard", "courtyard_left", "courtyard_right", "home"]
		for stop in route:
			var target: Vector2 = city.pilot_walk_points[stop]
			world.walk_to(Vector3(target.x, 0.14, target.y))
			for tick in 2000:
				if world._target == null:
					break
				world.player.position += world._follow_path(0.12)
				assert(city.walkable(Vector2(world.player.position.x, world.player.position.z)), "Movement crossed blocked cells")
			assert(Vector2(world.player.position.x, world.player.position.z).distance_to(target) < 0.05, "Movement failed to arrive " + stop)
		for id in ids:
			world.player.position = world.door_of(id)
			world.walk_to_location(id)
			for tick in 20:
				if world._target == null:
					break
				world.player.position += world._follow_path(0.12)
			assert(world.hud._loc_id == id, "Location interaction no longer opens " + id)
			world.hud.close_location()
		# Separate upper/roof groups restore when switching back to full overview.
		world.player.position = Vector3(yard.x, 0.14, yard.y)
		world.camera.position = world.player.position + world.cam_offset()
		world._update_cutaway(1.0)
		var house_cut := false
		for o in world.occluders:
			if o.has("architecture"):
				assert(o.architecture.ground.visible and o.node.scale.is_equal_approx(Vector3.ONE))
				house_cut = house_cut or not o.architecture.roof.visible
				if o.architecture.front_walls != null:
					assert(not o.architecture.front_walls.visible, "Front wings must reveal the whole courtyard")
		assert(house_cut, "Courtyard view must cut away obstructing roof")
		await physics_frame
		await process_frame
		world.camera.look_at(world.player.position + Vector3(0, 1.3, 0))
		var yard_side: Vector2 = city.pilot_walk_points.courtyard_right
		world._handle_click(world.camera.unproject_position(Vector3(yard_side.x, 0.14, yard_side.y)))
		assert(world._target_loc == "" and world._target != null, "Hidden front wings must not intercept yard clicks")
		assert(Vector2(world._target.x, world._target.z).distance_to(yard_side) < 0.15, "Visible yard floor must be clickable")
		world._target = null
		world.set_process(true)
	# A consistent midday review can also run on the normal story map (without --street-demo).
	if "--midday" in OS.get_cmdline_user_args():
		world.game.s.used = 13.0 - float(world.game.cfg.dayStart)
		world.game.changed.emit()
	for id in ids:
		world.player.position = world.loc_point(id, 0.0, 0.8)
		world.camera.position = world.player.position + world.cam_offset()
		for frame in 12:
			world._update_cutaway(1.0 / 30.0)
			await process_frame
		if "--capture" in OS.get_cmdline_user_args():
			await RenderingServer.frame_post_draw
			var prefix := "street" if "--street-demo" in OS.get_cmdline_user_args() else "normal-street"
			root.get_texture().get_image().save_png("res://tests/%s-%s-preview.png" % [prefix, id])
	# Intentional overview remains available for inspecting the map.
	world.toggle_overview()
	assert(is_equal_approx(world.zoom, world.ZOOM_MAX))
	world.camera.position = world.player.position + world.cam_offset()
	for frame in 12:
		world._update_cutaway(0.1)
		await process_frame
	for o in world.occluders:
		if o.has("architecture"):
			assert(o.architecture.roof.visible and o.architecture.upper.visible, "Overview must restore authored houses")
			if o.architecture.front_walls != null:
				assert(o.architecture.front_walls.visible, "Overview must restore courtyard wings")
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/street-overview-preview.png")
	world.toggle_overview()
	assert(world.zoom < 1.0)
	print("PASS: street routes, courtyard click, movement, interactions, authored cutaway, overview and scene construction")
	quit()
