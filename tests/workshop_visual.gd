extends "res://tests/opening_visual.gd"

func snapshot(name: String) -> void:
	for i in 15: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/workshop-preview/"+name+".png")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/workshop-preview"))
	root.size=Vector2i(1280,720); root.gui_embed_subwindows=true
	var world=load("res://scenes/world.tscn").instantiate(); root.add_child(world)
	for i in 14: await process_frame
	world.set_process(false)
	var g=world.game; g.cfg.idleMinutesPerSecond=0.0
	settle(g); g.s.used=2.1
	g.s.tips_seen=g.story.get("tips",[]).map(func(t): return str(t.id))
	world.hud._close_tip(); g._commit()
	g.do_action("pho_chao_son"); g.resolve_choice(0)
	for id in ["inspect","diagnose_cap","shop_part"]: check(g.Street.act(g,"tiem_sau",id),"prepare "+id)
	world.hud.open_location("tiem_sau"); world.hud._open_bench()
	var bench=world.hud._bench
	check(is_instance_valid(bench),"bench opens")
	if not is_instance_valid(bench): quit(1); return
	await snapshot("01_closed")
	var start: float=g.s.used
	await drag(bench,bench.old_part.position+Vector3(0,.12,0),bench.BIN)
	check(not bench.progress().removed,"closed cover prevents removing component")
	bench.cover_button.pressed.emit()
	check(g.s.street.job.cover_open,"cover opening persists in order")
	check(is_equal_approx(start,g.s.used),"opening does not charge repair time twice")
	bench.queue_free(); await process_frame
	world.hud._open_bench(); bench=world.hud._bench
	for i in 30: await process_frame
	check(bench.cover_button.disabled,"reopening preserves open case")
	check(bench.activity.actor.get_script()==world.player_body.get_script(),"work uses actual An rig")
	check(bench.activity.actor._task_pose.repairing,"work pose active")
	await snapshot("02_open")
	await drag(bench,bench.sample_part.position+Vector3(0,.12,0),bench.SOCKET)
	check(not bench.progress().installed,"wrong component rejected")
	await drag(bench,bench.old_part.position+Vector3(0,.12,0),bench.BIN)
	await drag(bench,bench.new_part.position+Vector3(0,.12,0),bench.SOCKET)
	for point in bench.SCREWS:
		mouse(bench,screen(bench,point),true); mouse(bench,screen(bench,point),false); await process_frame
	check(g.s.street.job.stage=="test","drag/drop and screws complete real order")
	await snapshot("03_assembly")
	bench.test_button.pressed.emit()
	check(bench.finished and g.item_count("quat")==1,"test creates one carryable fan")
	var completed_time: float=g.s.used
	bench._test(); check(is_equal_approx(completed_time,g.s.used),"repeated test cannot charge again")
	await snapshot("04_running")
	bench.queue_free(); await process_frame
	g.quest_visit("quat_trai_cay"); settle(g)
	for i in 20: await process_frame
	var receipt=world.hud._bench
	check(is_instance_valid(receipt) and receipt.get_script()==load("res://scripts/work/repair_handover.gd"),"actual quest delivery opens customer scene")
	if is_instance_valid(receipt) and receipt.get_script()==load("res://scripts/work/repair_handover.gd"):
		var cash: int=g.s.cash
		receipt.activity._process(4.0)
		await snapshot("05_customer")
		check(receipt.activity.transferred,"customer visibly takes appliance")
		check(g.s.cash==cash,"handover presentation grants no extra reward")
		receipt.queue_free(); await process_frame
		g.changed.emit()
		for i in 5: await process_frame
		check(not is_instance_valid(world.hud._bench),"unchanged save does not replay handover")
	check(not root.get_node("GameState")._persist,"test never saves over player")
	world.queue_free(); await process_frame
	print("Workshop: ","PASS" if failures==0 else "FAIL"," failures=",failures)
	quit(0 if failures==0 else 1)
