extends "res://tests/opening_visual.gd"

func snapshot(name: String) -> void:
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/design-preview/"+name+".png")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/design-preview"))
	root.size=Vector2i(1280,720)
	root.gui_embed_subwindows=true
	var pool=load("res://scripts/work/billiards.gd").new()
	pool.cfg={"shots":5,"balls":7}
	root.add_child(pool)
	pool._button()
	await snapshot("01_billiards")
	for b in pool._balls:
		var expected: Vector2=pool._to_px(b.p)
		var actual: Vector2=pool._scene.input_point(pool._scene.display(expected))
		check(actual.distance_to(expected)<0.5,"tilted 3D projection and simulation agree")
	var cue: Vector2=pool._to_px(pool._cue().p)
	var down:=InputEventMouseButton.new()
	down.button_index=MOUSE_BUTTON_LEFT; down.pressed=true; down.position=pool._scene.display(cue)
	pool._gui_input(down)
	var motion:=InputEventMouseMotion.new()
	motion.position=pool._scene.display(cue-Vector2(130,10))
	pool._gui_input(motion)
	await snapshot("02_billiards_aim")
	check(pool._scene.cue.visible,"3D cue visible while aiming")
	var up:=InputEventMouseButton.new()
	up.button_index=MOUSE_BUTTON_LEFT; up.pressed=false; up.position=motion.position
	pool._gui_input(up)
	check(pool._shots_left==4 and pool._moving,"mouse shot consumes one turn")
	for i in 30: await process_frame
	check(pool._cue().p.x>0.25,"cue moves along aimed direction")
	root.size=Vector2i(1366,768)
	for i in 12: await process_frame
	var new_pos: Vector2=pool._to_px(pool._cue().p)
	check(pool._scene.input_point(pool._scene.display(new_pos)).distance_to(new_pos)<0.5,"resize preserves aim mapping")
	pool.queue_free(); await process_frame
	root.size=Vector2i(1280,720)
	var world=load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	for i in 16: await process_frame
	world.set_process(false)
	var g=world.game
	g.cfg.idleMinutesPerSecond=0.0
	settle(g)
	g.s.used=2.1; g._commit()
	g.s.tips_seen=g.story.get("tips",[]).map(func(t): return str(t.id))
	world.hud._close_tip()
	var portrait=load("res://scripts/ui/character_panel.gd").new()
	portrait.world=world; portrait.game=g; root.add_child(portrait)
	portrait.open()
	await snapshot("03_character")
	check(portrait._body.get_script()==load("res://scripts/world/an_character.gd"),"portrait uses street An rig")
	var old_body=portrait._body
	portrait.refresh()
	check(portrait._body==old_body,"refresh reuses rig instead of leaking models")
	check(portrait._items("clothes").size()==1,"wardrobe starts with An's actual base outfit")
	g._own("ao_caro")
	portrait._tab="clothes"; portrait._sel="ao_caro"; portrait.refresh()
	portrait._item_btn.pressed.emit()
	check(g.wardrobe().worn.ao=="ao_caro","wardrobe button equips owned shop garment")
	check(portrait._body.materials[0].get_shader_parameter("shirt_color")==world.player_body.materials[0].get_shader_parameter("shirt_color"),"portrait and street use identical dye")
	await snapshot("04b_wardrobe_caro")
	portrait._sel="an_base"; portrait.refresh(); portrait._item_btn.pressed.emit()
	check(not g.wardrobe().worn.has("ao"),"can return to base outfit")
	portrait._turn.rotation.y=0.5
	portrait._portrait_camera.fov=23
	await snapshot("04_character_close")
	portrait.close(); portrait.queue_free(); await process_frame
	g.s.used=2.1; g._commit()
	g.do_action("pho_chao_son"); g.resolve_choice(0)
	for id in ["inspect","diagnose_cap","shop_part"]: check(g.Street.act(g,"tiem_sau",id),"prepare fan "+id)
	world.hud.open_location("tiem_sau")
	world.hud._open_bench()
	var bench=world.hud._bench
	for i in 12: await process_frame
	check(is_instance_valid(bench),"bench opens")
	if not is_instance_valid(bench): quit(1); return
	await snapshot("05_repair_fan")
	await drag(bench,bench.old_part.position+Vector3(0,0.12,0),bench.BIN)
	check(bench.progress().removed and bench.socket_ring.visible,"remove reveals socket")
	await drag(bench,bench.new_part.position+Vector3(0,0.12,0),bench.SOCKET)
	check(bench.progress().installed and not bench.socket_ring.visible,"install hides socket ring")
	for point in bench.SCREWS:
		mouse(bench,screen(bench,point),true); mouse(bench,screen(bench,point),false)
		await process_frame
	check(g.s.street.job.stage=="test","detailed geometry preserves screw hit targets")
	await snapshot("06_repair_ready")
	bench.queue_free(); await process_frame
	world.player.position=world.door_of("tiem_sau")
	world.camera.position=world.player.position+world.cam_offset()
	world.camera.look_at(world.player.position+Vector3.UP)
	world._update_cutaway(1.0)
	world._update_lighting(11.0)
	await snapshot("07_street")
	check(not root.get_node("GameState")._persist,"never saves over user's game")
	world.queue_free(); await process_frame
	print("Visual redesign: ","PASS" if failures==0 else "FAIL"," failures=",failures)
	quit(0 if failures==0 else 1)
