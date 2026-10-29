extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func settle(g) -> void:
	for i in 30:
		if g.s.queue.is_empty(): return
		g.resolve_first_available()
func screen(bench, point: Vector3) -> Vector2:
	return bench.camera.unproject_position(point)*bench.surface.size/Vector2(bench.viewport.size)+bench.surface.global_position
func mouse(bench, point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position=point
	event.global_position=point
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=pressed
	bench.push_input(event)
func drag(bench, start: Vector3, finish: Vector3) -> void:
	mouse(bench,screen(bench,start),true)
	await process_frame
	var move := InputEventMouseMotion.new()
	move.position=screen(bench,finish)
	move.global_position=move.position
	move.button_mask=MOUSE_BUTTON_MASK_LEFT
	bench.push_input(move)
	await process_frame
	mouse(bench,screen(bench,finish),false)
	await process_frame
func shot(world, loc: String, name: String) -> void:
	world.hud.close_location()
	world.player.position=world.door_of(loc)
	world.camera.position=world.player.position+world.cam_offset()
	world.camera.look_at(world.player.position+Vector3.UP,Vector3.UP)
	world._update_cutaway(1.0)
	world.hud.set_prompt(world.nearest_location())
	for i in 12: await process_frame
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/opening-preview/%s.png"%name)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/opening-preview"))
	root.size=Vector2i(1280,720)
	root.gui_embed_subwindows=true
	var world=load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	for i in 10: await process_frame
	world.set_process(false)
	var g=world.game
	g.cfg.idleMinutesPerSecond=0.0
	g.s.tips_seen=g.story.get("tips",[]).map(func(t): return str(t.id))
	world.hud._close_tip()
	g.changed.emit()
	var opening=world.find_children("*","",false,false).filter(func(n): return n.get_script()==load("res://scripts/world/opening_street.gd"))[0]
	check(opening.shop_fan.visible and not opening.market_fan.visible,"fan starts at repair shop")
	await shot(world,"xom_bo_me","01_home")
	await shot(world,"tiem_sau","02_workshop")
	world.hud.open_location("tiem_sau")
	g.do_action("pho_chao_son")
	for i in 10: await process_frame
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/opening-preview/03_customer.png")
	g.resolve_choice(0)
	check(g.Street.act(g,"tiem_sau","inspect"),"inspect")
	check(g.Street.act(g,"tiem_sau","diagnose_cap"),"diagnose")
	check(g.Street.act(g,"tiem_sau","shop_part"),"source part")
	for i in 8: await process_frame
	world.hud._open_bench()
	var bench=world.hud._bench
	check(is_instance_valid(bench),"HUD opens the actual repair bench")
	if not is_instance_valid(bench): quit(1); return
	for i in 10: await process_frame
	bench.cover_button.pressed.emit()
	await drag(bench,bench.old_part.position+Vector3(0,0.12,0),bench.BIN)
	check(bench.progress().removed,"actual mouse drag removes old part")
	await drag(bench,bench.new_part.position+Vector3(0,0.12,0),bench.SOCKET)
	check(bench.progress().installed,"actual mouse drag installs replacement")
	for point in bench.SCREWS:
		mouse(bench,screen(bench,point),true)
		mouse(bench,screen(bench,point),false)
		await process_frame
	check(g.s.street.job.stage=="test","clicking screws completes assembly")
	bench.test_button.pressed.emit()
	bench.queue_free()
	await process_frame
	check(g.item_count("quat")==1,"test button makes the fan ready to return")
	check(not opening.shop_fan.visible and not opening.market_fan.visible,"fan in inventory, not duplicated")
	g.quest_visit("quat_trai_cay")
	settle(g)
	check(opening.market_fan.visible and not opening.shop_fan.visible,"delivered fan physically at customer stall")
	var angle: float=opening.rotor.rotation.z
	opening._process(0.1)
	check(not is_equal_approx(angle,opening.rotor.rotation.z),"repaired fan spins")
	await shot(world,"cho_cau_nho","04_customer_stall")
	g.do_action("com_voi_ba")
	g.do_action("opening_mango")
	check(opening.mangoes.visible,"family meal leaves visible fruit")
	await shot(world,"xom_bo_me","05_home_return")
	# Same rig, palette and hairstyle are used when entering any work scene.
	g.s.appearance={"hair":"362318","shirt":"735c48","pants":"435266"}
	g.s.hair_style="neat"
	world.update_outfit()
	world.hud._open_minigame("sua_do_le",g.get_action("sua_do_le"))
	for i in 12: await process_frame
	var work=world.hud.minigame
	work._start_play()
	for i in 12: await process_frame
	check(work._body.get_script()==world.player_body.get_script(),"same An rig inside job")
	for key in ["hair","shirt","pants"]:
		var color=work._body.materials[0].get_shader_parameter(key+"_color")
		check(color!=null and color==world.player_body.materials[0].get_shader_parameter(key+"_color"),"same palette: "+key)
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/opening-preview/06_work_avatar.png")
	check(not root.get_node("GameState")._persist,"preview never writes user's save")
	world.queue_free()
	await process_frame
	print("Opening visual: ","PASS" if failures==0 else "FAIL"," failures=",failures)
	quit(0 if failures==0 else 1)
