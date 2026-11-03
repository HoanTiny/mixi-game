extends SceneTree
const Logic := preload("res://scripts/game_logic.gd")
var failures := 0
func expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func screen(bench, point: Vector3) -> Vector2:
	return bench.camera.unproject_position(point)*bench.surface.size/Vector2(bench.viewport.size)+bench.surface.global_position
func mouse(bench, point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	bench.push_input(event)
func drag(bench, start: Vector3, finish: Vector3) -> void:
	mouse(bench,screen(bench,start),true)
	await process_frame
	var move := InputEventMouseMotion.new()
	move.position = screen(bench,finish)
	move.global_position = move.position
	move.button_mask = MOUSE_BUTTON_MASK_LEFT
	bench.push_input(move)
	await process_frame
	mouse(bench,screen(bench,finish),false)
	await process_frame
func run() -> void:
	root.size = Vector2i(1366,800)
	root.gui_embed_subwindows = true
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_physics_process(false)
	var g = world.game
	g.s.used=2.0
	g.changed.emit()
	world.player.position = world.door_of("tiem_sau")
	world.hud.open_location("tiem_sau")
	for id in ["accept","inspect","shop_part"]: world.hud._street_action(id)
	world.hud._open_bench()
	var bench = world.hud._bench
	for i in range(10): await process_frame
	expect(world.hud.blocking(),"Bench must block walking")
	var before: float = g.clock()
	var cash: int = g.s.cash
	await drag(bench,bench.new_part.position+Vector3(0,0.12,0),bench.SOCKET)
	expect(not bench.progress().installed,"Cannot install before removal")
	await drag(bench,bench.old_part.position+Vector3(0,0.12,0),Vector3(1.7,0.75,-1.1))
	expect(not bench.progress().removed,"Wrong drop must not advance")
	await drag(bench,bench.old_part.position+Vector3(0,0.12,0),bench.BIN)
	expect(bench.progress().removed,"Mouse drag must remove old part")
	await drag(bench,bench.sample_part.position+Vector3(0,0.12,0),bench.SOCKET)
	expect(not bench.progress().installed,"Wrong component rejected")
	await drag(bench,bench.new_part.position+Vector3(0,0.12,0),bench.SOCKET)
	expect(bench.progress().installed,"Mouse drag must install new part")
	var reloaded := Logic.new()
	reloaded.load_data()
	reloaded.s = JSON.parse_string(JSON.stringify(g.s))
	reloaded.migrate_save()
	expect(reloaded.s.street.job.bench.installed,"Assembly progress saved")
	bench.queue_free()
	await process_frame
	world.hud._open_bench()
	bench = world.hud._bench
	for i in range(6): await process_frame
	expect(bench.progress().installed,"Close and reopen preserves assembly")
	for point in bench.SCREWS:
		mouse(bench,screen(bench,point),true)
		mouse(bench,screen(bench,point),false)
		await process_frame
	expect(g.s.street.job.stage=="test","Two screws finish assembly")
	expect(is_equal_approx(g.clock()-before,0.75) and int(g.s.cash)==cash,"Time charged exactly once, no second part charge")
	mouse(bench,screen(bench,bench.SCREWS[0]),true)
	mouse(bench,screen(bench,bench.SCREWS[0]),false)
	expect(is_equal_approx(g.clock()-before,0.75),"No duplicate repair charge")
	bench.test_button.pressed.emit()
	expect(g.s.street.job.stage=="deliver","Bench test advances order")
	for i in range(10): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/bench-preview.png")
	bench.queue_free()
	await process_frame
	world.hud.close_location()
	# The kettle uses the other component and the same actual mouse input path.
	g.new_pilot()
	g.s.day=2
	g.s.street.xp=2
	g.s.used=2.0
	g.changed.emit()
	world.player.position = world.door_of("tiem_sau")
	world.hud.open_location("tiem_sau")
	for id in ["accept","inspect","shop_part"]: world.hud._street_action(id)
	world.hud._open_bench()
	bench = world.hud._bench
	for i in range(8): await process_frame
	expect(bench.kind==1,"Second order uses a fuse")
	var orbit := InputEventMouseMotion.new()
	orbit.relative = Vector2(35,10)
	orbit.button_mask = MOUSE_BUTTON_MASK_RIGHT
	bench._surface_input(orbit)
	await drag(bench,bench.old_part.position+Vector3(0,0.12,0),bench.BIN)
	await drag(bench,bench.new_part.position+Vector3(0,0.12,0),bench.SOCKET)
	expect(bench.progress().installed,"Kettle drag works after orbit")
	for point in bench.SCREWS:
		mouse(bench,screen(bench,point),true)
		mouse(bench,screen(bench,point),false)
		await process_frame
	expect(g.s.street.job.stage=="test","Kettle assembly finished")
	for i in range(6): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/kettle-bench-preview.png")
	bench.queue_free()
	await process_frame
	world.hud.close_location()
	# Every scheduled destination is reachable; position changes are gradual.
	for hour in [7.0,8.0,10.0,17.0,18.0,20.0]:
		var before_positions := []
		for r in world.residents: before_positions.append(r.node.global_position)
		g.s.used=hour-6.0
		g.changed.emit()
		for i in world.residents.size():
			expect(world.residents[i].node.global_position.is_equal_approx(before_positions[i]),"Schedule must not teleport NPC")
		world.resident_routes.tick(0.1)
		for i in world.residents.size():
			expect(world.residents[i].node.global_position.distance_to(before_positions[i])<=0.166,"NPC speed bounded")
		for i in range(1200): world.resident_routes.tick(0.1)
		for r in world.residents:
			if not r.path.is_empty():
				print("STUCK ",hour," ",r.name," ",r.node.position," next=",r.path[0]," goal=",r.end)
				for other in world.crowd.actors:
					if other!=r.node and other.global_position.distance_to(r.node.global_position)<2: print(" NEAR ",other.global_position)
			expect(r.path.is_empty() and r.reachable,"NPC route reachable: "+r.name)
			expect(r.body.get_meta("loc","")==r.destination,"NPC interaction set on arrival")
	g.s.used=2.0
	g.changed.emit()
	for i in range(80): world.resident_routes.tick(0.1)
	var snapshot: Dictionary = g.s.npc_routes.duplicate(true)
	for r in world.residents: r.erase("path")
	world.resident_routes.refresh()
	for r in world.residents:
		var saved: Array = snapshot[r.name].position
		expect(r.node.global_position.is_equal_approx(Vector3(saved[0],0,saved[1])),"NPC position restored without teleport")
	world.camera.position = world.player.position+world.CAM_OFFSET
	world.camera.look_at(world.player.position+Vector3(0,1,0))
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/npc-routes-preview.png")
	print("Bench and routes: ","PASS" if failures==0 else "FAIL", " failures=",failures)
	quit(0 if failures==0 else 1)
