extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	world.set_process(false)
	var scheduler = world.get_node("GlobalSystems/EventSchedulerSystem")
	scheduler.set_process(false)
	assert(world.has_node("ScheduledZones"))
	assert(world.get_node("ScheduledZones").get_child_count()==4)
	for zone in world.get_node("ScheduledZones").get_children():
		assert(zone.get_child_count()>0, "Zone must have existing map anchors")
	world.game.s.queue.clear()
	for hour in [17.99,18.0,22.99,23.0]:
		world.game.s.used = hour-float(world.game.cfg.dayStart)
		scheduler.timer=0
		scheduler._process(.3)
		var active: bool = hour>=18 and hour<23
		assert(scheduler.night_root.visible==active)
		for pick in scheduler.night_root.find_children("*","StaticBody3D",true,false):
			assert(pick.collision_layer==(1 if active else 0))
	print("PASS four live zones and night market lights/colliders at all boundaries")
	world.game.s.day=4
	world.game.s.used=8.0-float(world.game.cfg.dayStart)
	world.game.s["tips_seen"]=world.game.story.get("tips",[]).map(func(t): return str(t.id))
	world.game.s.queue.clear()
	world.game.changed.emit()
	world.hud._close_tip()
	world.hud.close_location()
	if world.title != null: world.title.hide()
	world.player.position=world.door_of("bai_boc_vac")
	scheduler.timer=0
	scheduler._process(.3)
	assert(world.game.s.queue.any(func(e): return e.id=="scheduler:construction_halt_and_scrap_guild"), "Walking into Zone 3 must queue its story")
	print("PASS live player position triggers construction event in Zone 3")
	quit()
