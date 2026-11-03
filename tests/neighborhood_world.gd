extends SceneTree
## Real scene regression: guided walk, interaction, transit UI and fresh/save state.
## --headless --path . -s tests/neighborhood_world.gd -- --demo --demo-full
## Add --capture without --headless for actual Compatibility viewport evidence.
const Guide := preload("res://scripts/quest_guide.gd")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var start := Time.get_ticks_msec()
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	await physics_frame
	var build_ms := Time.get_ticks_msec()-start
	world.set_process(false)
	var g = world.game
	g.s.queue.clear()
	g.cfg.idleMinutesPerSecond=0.0
	g.s["tips_seen"]=g.story.get("tips",[]).map(func(t): return str(t.id))
	g.changed.emit()
	world.hud._close_tip()
	world.hud.close_location()
	check(world.city.layout_version==2,"Compact layout is the normal scene")
	check(not root.get_node("GameState")._persist,"Demo does not overwrite the normal save")
	check(g.s.get("world_layout","")=="hn_pho_co:2","World layout migration is stamped")
	check(Guide.active(g).get("location","")=="tiem_sau","Fresh day1 guides to work introduction")
	check(world.hud._guide_location=="tiem_sau","HUD and shared guide match")
	check(not world.objective_spots().is_empty(),"Same objective has a world/minimap marker")
	world.hud._guide_button.pressed.emit()
	check(world._target_loc=="tiem_sau","Guide button starts actual navigation")
	var sequence := ["tiem_sau","cho_cau_nho","tiem_sau","com_hanh","xom_bo_me"]
	for id in sequence:
		world.hud.close_location()
		world.walk_to_location(id)
		var guard := 0
		while world._target != null and guard < 1600:
			guard+=1
			world.player.position+=world._follow_path(0.25)
			check(world.city.walkable(Vector2(world.player.position.x,world.player.position.z)),"Guided route stays walkable: "+id)
		check(guard<1600,"Walk completes: "+id)
		check(world.player.position.distance_to(world.door_of(id))<0.35,"Walk ends at door: "+id)
		check(world.hud.location_open()==id,"Arrival opens correct place: "+id)
		if id in ["com_hanh","xom_bo_me"]:
			await capture(world,id)
	world.hud.close_location()
	g.s.day=3
	g.s.used=4.0
	g.s.cash=50000
	g.s.queue.clear()
	g.changed.emit()
	world.player.position=world.door_of("ben_xe_6")
	world.hud.open_location("ben_xe_6")
	var trips: Array=world.travel_options("ben_xe_6")
	check(trips.size()==3,"Bus panel exposes three routes")
	check(trips.any(func(t): return t.destination=="cau_tre" and t.reason==""),"Day3 visit route available")
	await capture(world,"bus")
	world.walk_to_location("com_hanh")
	world._walk_meters=2.0
	var used: float=g.s.used
	check(world.travel_to("cau_tre"),"Actual bus button route succeeds")
	check(int(g.s.cash)==43000,"Actual travel charges once")
	check(is_equal_approx(float(g.s.used),used+2.0*float(g.cfg.walkHoursPerMeter)+1.0/3.0),"Walking remainder and travel time charged once")
	check(world.player.position.distance_to(world.door_of("cau_tre"))<0.05,"Travel arrives at visible walkable door")
	check(world._target==null and world._path.is_empty() and is_zero_approx(world._travel_pace.speed),"Transit clears previous path and velocity")
	check(world.hud.location_open()=="cau_tre","Destination actions appear after ride")
	await capture(world,"arrival")
	check(world.travel_to("ben_xe_6"),"Return route succeeds")
	var fare_after_return: int=g.s.cash
	world.player.position=world.door_of("xom_bo_me")
	check(not world.travel_to("cau_tre") and int(g.s.cash)==fare_after_return,"Open stale bus panel cannot teleport from home")
	world.hud.close_location()
	world.player.position=world.door_of("xom_bo_me")
	world.zoom=0.7
	await capture(world,"overview")
	var report:={"build_ms":build_ms,"failures":failures,"layout":world.city.layout_version,"locations":world.LOCATIONS.size(),"background_buildings":world.city.data.buildings.size(),"delivery_homes":world.homes.size()}
	var file:=FileAccess.open("res://build/neighborhood-world.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("PASS neighborhood world: guided core walks, HUD/markers, travel cards, guarded fares, arrival and old path reset" if failures.is_empty() else "FAIL neighborhood world: %d"%failures.size())
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func capture(world, label: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args(): return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/neighborhood-preview"))
	world.camera.position=world.player.position+world.cam_offset()
	world.camera.look_at(world.player.position+Vector3.UP,Vector3.UP)
	world._update_cutaway(1.0)
	for frame in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/neighborhood-preview/%s.png"%label)
