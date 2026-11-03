extends "res://tests/opening_visual.gd"
var world
func snap(name: String) -> void:
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/week-one-preview/%s.png" % name)
func click_named(parent: Node, contains: String) -> bool:
	for button in parent.find_children("*","Button",true,false):
		if button.disabled or not button.is_visible_in_tree(): continue
		for label in button.find_children("*","Label",true,false):
			if label.text.contains(contains):
				button.pressed.emit()
				return true
	return false
func go(loc: String) -> void:
	world.hud.close_location()
	world.player.position = world.door_of(loc)
	world.camera.position = world.player.position+world.cam_offset()
	world.camera.look_at(world.player.position+Vector3.UP,Vector3.UP)
	world._update_cutaway(1.0)
	world.hud.open_location(loc)
	for i in 5: await process_frame
func act_at(mini, spot: Dictionary) -> void:
	mini._player.position = Vector3(spot.pos.x,0,spot.pos.y+0.7)
	mini._cool = 0
	mini._act(spot)
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://build/week-one-preview")
	root.size = Vector2i(1280,800)
	world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	for i in 8: await process_frame
	world.set_process(false)
	var g = world.game
	settle(g)
	g.cfg.idleMinutesPerSecond=0
	g.events=[]; g.s.scenes=[]; g.s.queue=[]
	g.s.tips_seen=g.story.get("tips",[]).map(func(t):return str(t.id))
	world.hud._close_tip()
	g.s.day=5; g.s.used=2.0; g.s.needs_t=8.0; g.s.fatigue=0
	for key in g.s.needs: g.s.needs[key]=100.0
	g.quest_accept("ngay5_ca_hanh"); g._commit()
	await go("com_hanh")
	await snap("01_day5_contract")
	check(click_named(world.hud._loc_cards,"Ca đã hẹn"),"contract card visible and clickable")
	for i in 5: await process_frame
	var mini = world.hud.minigame
	if not is_instance_valid(mini): check(false,"real work scene opens"); quit(1); return
	check(mini.cfg.minRatio == 0.0 and mini.cfg.bonusPerExtra == 0,"contract cannot pass by minimum wage floor or promise unpaid tips")
	mini._start_play(); mini.set_process(false)
	check(mini._ratio()==0.0,"doing no work is a failed contract")
	mini.cfg.eatSec=0.01
	for count in ceili(float(mini.cfg.target)*0.5):
		var table: Dictionary = mini._tables()[0]
		if table.dirty:
			act_at(mini,table)
			act_at(mini,mini._spots.filter(func(s):return s.type=="sink")[0])
		if table.cust == null: mini._seat(table)
		var order: Dictionary = table.order.duplicate()
		for key in order:
			var station: Dictionary = mini._spots.filter(func(s):return s.type=="station" and s.key==key)[0]
			for n in int(order[key]):
				act_at(mini,station); act_at(mini,table)
		await create_timer(0.03).timeout
	check(mini._ratio()>=0.5,"serving actual customer orders meets quota")
	mini._show_end()
	await snap("02_shift_handover")
	var cash: int = g.s.cash
	check(click_named(mini._menu,"Hoàn tất ca"),"work returns through actual finish button")
	await create_timer(2.0).timeout
	check(g.s.cash==cash and g.s.quests.ngay5_ca_hanh.step==1,"HUD result does not pay before handover")
	await go("com_hanh")
	await snap("03_receive_wage")
	check(click_named(world.hud._loc_cards,"★"),"handover card clickable")
	check(g.s.cash==cash+130000,"handover pays exact wage")
	settle(g)
	g.s.day=6; g.s.used=8.0; g.s.needs_t=14.0; g.s.queue=[]
	g.quest_accept("ngay6_phan_gan"); g._commit()
	await go("com_hanh")
	check(click_named(world.hud._loc_cards,"★"),"pick up meal parcel")
	check(g.item_count("com_phan_gan")==1,"real pickup yields parcel")
	await go("cho_cau_nho")
	await snap("04_deliver_meals")
	check(click_named(world.hud._loc_cards,"★"),"customer handover clickable")
	check(g.quest_state("ngay6_phan_gan")=="done","meal delivery completes")
	settle(g)
	root.size=Vector2i(900,650)
	await go("com_hanh")
	await snap("05_compact_hud")
	world.hud.close_location()
	world.set_process(true)
	var frames := []
	var previous := Time.get_ticks_usec()
	for i in 120:
		await process_frame
		var now := Time.get_ticks_usec()
		frames.append(float(now-previous)/1000.0)
		previous=now
	frames.sort()
	var sum := 0.0
	for ms in frames: sum+=ms
	var report := {"viewport":"900x650","mode":"native GL compatibility, standing outside restaurant, simulation running","fps":120000.0/sum,"p95_ms":frames[113],"world_build_ms":world.build_timings}
	var file := FileAccess.open("res://build/week-one-preview/performance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	check(not root.get_node("GameState")._persist,"demo does not save to user slot")
	print("Week one visual: failures=",failures)
	world.queue_free(); await process_frame
	quit(0 if failures==0 else 1)
