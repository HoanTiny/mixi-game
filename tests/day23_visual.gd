extends "res://tests/opening_visual.gd"

func capture(world, name: String) -> void:
	world.camera.position=world.player.position+world.cam_offset()
	world.camera.look_at(world.player.position+Vector3.UP,Vector3.UP)
	world._update_cutaway(1.0)
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/day23-preview/"+name+".png")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/day23-preview"))
	root.size=Vector2i(1280,720)
	root.gui_embed_subwindows=true
	var world=load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	for i in 12: await process_frame
	world.set_process(false)
	var g=world.game
	g.cfg.idleMinutesPerSecond=0.0
	settle(g)
	g.s.tips_seen=g.story.get("tips",[]).map(func(t): return str(t.id))
	world.hud._close_tip()
	g.s.flags.opening_fan_met=true
	g.s.day=2
	g.s.used=2.0
	g._commit()
	var opening=world.find_children("*","",false,false).filter(func(n): return n.get_script()==load("res://scripts/world/opening_street.gd"))[0]
	check(g.Day23.act(g,"xom_bo_me","arc_meet_late"),"book afternoon")
	world.player.position=world.door_of("tiem_sau")
	world.hud.open_location("tiem_sau")
	for id in ["arc_accept","arc_measure_wire","arc_measure_heater","arc_measure_fuse","arc_diagnose_fuse","arc_quote_new","arc_wait_reply","arc_shop_part"]:
		check(g.Street.act(g,"tiem_sau",id),"real repair dispatch "+id)
	for i in 12: await process_frame
	world.hud._open_bench()
	var bench=world.hud._bench
	check(is_instance_valid(bench),"actual kettle bench available")
	if not is_instance_valid(bench): quit(1); return
	for i in 12: await process_frame
	check("90 phút" in bench.details.text,"bench shows actual duration")
	bench.cover_button.pressed.emit()
	await drag(bench,bench.old_part.position+Vector3(0,0.12,0),bench.BIN)
	await drag(bench,bench.new_part.position+Vector3(0,0.12,0),bench.SOCKET)
	for point in bench.SCREWS:
		mouse(bench,screen(bench,point),true)
		mouse(bench,screen(bench,point),false)
		await process_frame
	check(g.s.street.job.stage=="test","mouse assembles kettle")
	bench.test_button.pressed.emit()
	bench.queue_free()
	await process_frame
	world.hud.close_location()
	check(opening.carry_id=="kettle","physical kettle in player's hands")
	for i in 45: await process_frame
	check(world.player_body.held_kind=="kettle","carrying pose on street")
	check(world.player_body._task_pose.weight>0.95,"carry pose blended in")
	world.hud.set_prompt("")
	await capture(world,"01_carry_kettle")
	# Look closely at hand contact on the real rig.
	world.camera.position=world.player.position+Vector3(2.0,2.2,3.2)
	world.camera.look_at(world.player.position+Vector3(0,0.9,0))
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/day23-preview/02_grip.png")
	world.player.position=world.door_of("cho_cau_nho")
	check(g.Day23.act(g,"cho_cau_nho","arc_deliver"),"return at market")
	check(opening.water_kettle.visible and opening.carry_id=="","kettle moves to stall once")
	await capture(world,"03_market")
	# Linh changes destination through the normal path-following code.
	g.s.used=9.5
	g._commit()
	world.player.position=world.door_of("hem_dua")
	world.life._update_npc("LINH",0.1)
	var n: Dictionary=world.life.npcs.LINH
	check(n.errand.get("to","")=="hem_dua","Linh follows appointment schedule")
	for i in 1600: world.life._update_npc("LINH",0.1)
	check(world.life.npc_where("LINH")=="hem_dua","Linh can reach the room")
	g.s.used=10.0; g._commit()
	check(g.Day23.act(g,"hem_dua","arc_attend"),"meet at agreed time")
	await capture(world,"04_room")
	g.finish_day(); settle(g)
	g.s.used=11.5; g._commit()
	world.player.position=world.door_of("com_hanh")
	world.life._update_npc("LINH",0.1)
	for i in 1600: world.life._update_npc("LINH",0.1)
	world.begin_rest_pose("com_hanh")
	for i in 45: await process_frame
	check(world.player_body.resting and world.player_body._task_pose.resting,"seated rest uses chair pose")
	await capture(world,"05_rest")
	world.camera.position=world.player.position+Vector3(2.0,1.8,3.0)
	world.camera.look_at(world.player.position+Vector3(0,0.65,0))
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/day23-preview/05b_rest_close.png")
	var original: Transform3D=world._rest_origin
	world.end_rest_pose()
	check(not world.player_body.resting and world.player.transform==original,"leaving rest restores navigation position")
	check(g.Day23.act(g,"com_hanh","arc_debrief"),"day three conversation")
	check(not "{" in g.fill(g.current_event().text),"dialogue resolves saved outcome text")
	for i in 10: await process_frame
	await capture(world,"06_evening_conversation")
	check(not root.get_node("GameState")._persist,"visual test never writes user's save")
	world.queue_free()
	await process_frame
	print("Day 2–3 visual: ","PASS" if failures==0 else "FAIL"," failures=",failures)
	quit(0 if failures==0 else 1)
