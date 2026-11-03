extends SceneTree
## GPU views of layout 2, separate from the archived 1.5 city captures.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	assert(world.city.layout_version == 2)
	world.game.s.queue.clear()
	world.game.s.used = 13.0 - float(world.game.cfg.dayStart)
	world.game.cfg.idleMinutesPerSecond = 0.0
	world.game.s["tips_seen"] = world.game.story.get("tips", []).map(func(t): return str(t.id))
	world.game.changed.emit()
	world.hud._close_tip()
	world.hud.close_location()
	DirAccess.make_dir_recursive_absolute("res://build/compact-preview")
	var bus_only := "--bus-only" in OS.get_cmdline_user_args()
	var destinations := ["ben_xe_6"] if bus_only else ["xom_bo_me", "com_hanh", "tiem_sau", "cho_cau_nho", "hem_dua", "ben_xe_6"]
	for id in destinations:
		world.zoom = 0.12
		world.player.position = world.loc_point(id, 0.0, 1.2)
		world.player.rotation.y = PI
		await _capture(world, id)
	if not bus_only:
		world.zoom = 1.6
		world.player.position = Vector3(14, 0, 20)
		await _capture(world, "overview")
	print("COMPACT_MAP_REVIEW PASS ", 1 if bus_only else 7, " screenshots in build/compact-preview")
	quit()

func _capture(world, tag: String) -> void:
	world.camera.position = world.player.position + world.cam_offset()
	for frame in 60:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/compact-preview/%s.png" % tag)
