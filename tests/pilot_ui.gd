extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1366,800)
	root.gui_embed_subwindows = true
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var g = world.game
	assert(g.day()==1 and g.s.mode=="pilot")
	g.elapse(2.0)
	g.changed.emit()
	world.player.position = world.door_of("tiem_sau")
	world.hud.open_location("tiem_sau")
	world.hud._street_action("accept")
	world.hud._street_action("inspect")
	assert(g.s.street.job.stage=="part")
	world.hud._street_action("shop_part")
	assert(g.s.street.job.stage=="repair")
	for i in range(25): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/repair-preview.png")
	world.hud._street_action("fix_cap")
	world.hud._street_action("test")
	world.hud._street_action("deliver")
	assert(g.s.street.completed==1)
	g.elapse(18.0-g.clock())
	g.changed.emit()
	for i in range(1200): world.resident_routes.tick(0.1)
	for resident in world.residents:
		if resident.name=="Linh":
			assert(resident.body.get_meta("loc")=="xom_bo_me")
	g.s.day=5
	g.finish_day()
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/pilot-report.png")
	assert(world.hud.dialogs.visible)
	print("Pilot UI PASS: location interaction, repair stages, NPC schedule, summary")
	quit()
