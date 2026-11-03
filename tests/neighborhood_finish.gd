extends "res://tests/opening_visual.gd"

func snap(name: String) -> void:
	for i in 22: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/neighborhood-preview/"+name+".png")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/neighborhood-preview"))
	root.size=Vector2i(1280,720)
	var world=load("res://scenes/world.tscn").instantiate(); root.add_child(world)
	for i in 16: await process_frame
	world.set_process(false)
	var g=world.game; g.cfg.idleMinutesPerSecond=0.0
	settle(g); g.s.used=6; g._commit()
	g.s.tips_seen=g.story.get("tips",[]).map(func(t): return str(t.id)); world.hud._close_tip()
	check(world.pilot_life._actors.size()==6,"six distinct residents")
	for id in ["com_hanh","tiem_sau","xom_bo_me"]:
		g.s.used=2 if id=="xom_bo_me" else 6
		g._commit(); world.player.position=world.door_of(id)
		world.camera.position=world.player.position+world.cam_offset()*.70
		world.camera.look_at(world.player.position+Vector3(0,1,-1)); world._update_cutaway(1)
		world.hud.close_location(); world.hud.set_prompt(""); world.pilot_life._refresh()
		await snap(id)
		if id=="xom_bo_me":
			world.player.position=world.loc_point(id,0,-5.3)
			world.camera.position=world.player.position+world.cam_offset()*.7
			world.camera.look_at(world.player.position+Vector3.UP); world._update_cutaway(1); world.pilot_life._refresh()
			await snap("courtyard")
		for e in world.pilot_life._actors:
			if e.location==id:
				check(e.actor._activity in ["eat","repair","box","sweep", ""],"activity configured")
	var sources=world.find_children("*","",false,false).filter(func(n): return n.get_script()==load("res://scripts/world/neighborhood_audio.gd"))
	check(sources.size()==1,"one spatial foley controller")
	if not sources.is_empty():
		for s in sources[0].sources: check(s.player.stream!=null,"foley loaded "+str(s.kind))
	var mute := AudioServer.is_bus_mute(0)
	world.hud._toggle_audio(); check(AudioServer.is_bus_mute(0)!=mute,"sound toggle mutes master")
	world.hud._toggle_audio(); check(AudioServer.is_bus_mute(0)==mute,"sound toggle restores master")
	world.begin_rest_pose("com_hanh"); world.player_body.eat(true)
	world.camera.position=world.player.position+Vector3(2,1.7,3)
	world.camera.look_at(world.player.position+Vector3(0,.8,0))
	await create_timer(1.0).timeout
	await snap("an_meal")
	check(world.player_body._task_pose.eating and world.player_body._meal_props.size()==2,"An eats with bowl and chopsticks")
	world.end_rest_pose(); check(not world.player_body._task_pose.eating,"eating stops when leaving chair")
	# A readable seven-person contact sheet using the actual live rigs/materials.
	world.hud.visible=false
	var stage := Node3D.new(); world.add_child(stage); stage.position=world.player.position+Vector3(0,12,0)
	var M=load("res://scripts/work/repair_models.gd")
	M.box(stage,Vector3(0,-.06,0),Vector3(10,.12,3),M.mat("686b61"))
	var Human=load("res://scripts/world/human.gd")
	var looks=world.pilot_life.RESIDENTS
	for i in 7:
		var body: Node3D
		if i==0:
			body=load("res://scripts/world/an_character.gd").new(); stage.add_child(body); body.setup(Color.WHITE,Color.WHITE); body.apply_outfit(g)
		else:
			body=Human.make(looks[i-1]); stage.add_child(body); body.animate(0.0,0.0)
		body.position.x=(i-3)*1.12
	world.camera.projection=Camera3D.PROJECTION_ORTHOGONAL; world.camera.size=5.3
	world.camera.position=stage.position+Vector3(0,2.2,7); world.camera.look_at(stage.position+Vector3(0,.85,0))
	await snap("residents")
	check(not root.get_node("GameState")._persist,"does not write user save")
	world.queue_free(); await process_frame
	print("Neighborhood finish: ","PASS" if failures==0 else "FAIL"," failures=",failures)
	quit(0 if failures==0 else 1)
