extends "res://tests/opening_visual.gd"
func snap(name: String) -> void:
	for i in 6: await process_frame
	if "--capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/phuc-tan-preview/"+name+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/phuc-tan-preview"))
	root.size=Vector2i(1280,800)
	var world=load("res://scenes/world.tscn").instantiate(); root.add_child(world)
	for i in 15: await process_frame
	var g=world.game
	if not g.is_started(): check(false,"demo started"); quit(1); return
	settle(g); g.cfg.idleMinutesPerSecond=0
	g.s.cash=46000; g.s.housing_fund=1400000; g.s.queue=[]
	g.s.tips_seen=g.story.get("tips",[]).map(func(t): return str(t.id))
	world.hud._close_tip()
	world.player.position=world.door_of("xom_bo_me")
	world.camera.position=world.player.position+world.cam_offset()
	world.camera.look_at(world.player.position+Vector3.UP,Vector3.UP)
	g._commit()
	await snap("01_hud")
	check(not world.hud._obj_expanded and world.hud._objective_box.get_child_count()==1,"collapsed HUD contains one objective only")
	check(world.hud._quick_ids==["tam_rua","com_voi_ba","tra_tro_dem"],"home numbered shortcuts stay stable when rent disabled")
	check(world.hud._st_cash.is_visible_in_tree() and world.hud._st_fund.is_visible_in_tree() and world.hud._st_cash.text.contains("46.000") and world.hud._st_fund.text.contains("1.400.000"),"wallet and locked fund visible")
	var tab := InputEventKey.new(); tab.keycode=KEY_TAB; tab.pressed=true
	root.push_input(tab); await process_frame
	check(world.hud._obj_expanded,"objective drawer opens")
	var grandma=world.life.npcs.BA_TU
	check(grandma.node.get_child(0)._sitting and grandma.has("chair"),"grandma seated at home")
	var face: Vector3=grandma.node.global_transform.basis.z.normalized()
	var camera_dir: Vector3=world.camera.global_position-grandma.node.global_position; camera_dir.y=0
	check(face.dot(camera_dir.normalized())>.8,"grandma faces camera in three-quarter view")
	world.hud._toggle_objectives()
	world.hud._tip_id="qa_tip"; world.hud._tip_time=0; world.hud._tip_cooldown=0; world.hud._tip.show()
	world.hud._update_tip(5.5)
	check(world.hud._tip.visible and world.hud._tip.modulate.a<1,"toast fades in sixth second")
	world.hud._update_tip(.5)
	check(not world.hud._tip.visible,"toast releases space after six seconds")
	g.s.needs.clean=25; g._commit()
	world.hud._perform("tam_rua"); world.hud._perform("tam_rua")
	check(world.hud.blocking(),"transition blocks duplicate input")
	await create_timer(.65).timeout
	await snap("02_bath_fade")
	await create_timer(1.0).timeout
	check(g.today_count("tam_rua")==1 and not world.hud._working,"action completes once and releases input")
	check(g.need("clean")>64 and g.need("clean")<65,"bath restores 40 minus quarter-hour decay")
	await snap("03_bath_result")
	g.s.cash=66000; g._commit()
	world.hud._perform("tra_tro_dem")
	await create_timer(1.6).timeout
	check(g.s.cash==6000 and g.Economy.rent_due(g)==0,"rent UI resolves exact charge")
	await snap("04_rent_result")
	g.s.needs.fed=30; g._commit()
	world.hud._perform("com_voi_ba")
	await create_timer(1.6).timeout
	check(g.today_count("com_voi_ba")==1 and g.need("fed")>68 and not world._resting,"meal restores hunger and exits seated pose")
	await snap("07_meal_result")
	check(world.audio._sfx.has("bath") and world.audio._sfx.has("meal"),"water and dishes streams load")
	check(world.find_children("HomeParkedBike*","",true,false).size()==2,"two parked bikes in courtyard")
	check(world.find_children("HomeHangingBulb","",true,false).size()==1,"hanging bulb exists")
	check(not world.life.npcs.BA_TU.node.get_child(0)._sitting and not world.life.npcs.BA_TU.chair.visible,"grandma stands and leaves her chair on scheduled market trip")
	if world.life.npcs.BA_TU.state == "going":
		check(world.life.npcs.BA_TU.node.get_child(0)._state == "walk","departing grandma keeps her walk animation")
	var blocked: Vector3=world.loc_point("xom_bo_me",-2.7,-5.0)
	var passage: Vector3=world.loc_point("xom_bo_me",0,-5.0)
	check(not world.city.walkable(Vector2(blocked.x,blocked.z)) and world.city.walkable(Vector2(passage.x,passage.z)),"bikes block their footprint and leave the lane walkable")
	check(world.door_rings.xom_bo_me.material_override is ShaderMaterial,"ground ring uses pulse shader")
	g.s.used=12; g.s.needs_t=g.clock(); g._commit()
	world.player.position=world.loc_point("xom_bo_me",0,-4.8)
	world.camera.position=world.player.position+world.cam_offset()
	await snap("05_courtyard")
	root.size=Vector2i(900,650)
	await snap("06_compact")
	check(not root.get_node("GameState")._persist,"QA does not overwrite player's save")
	world.queue_free(); await process_frame
	print("Phuc Tan visual: ","PASS" if failures==0 else "FAIL"," failures=",failures)
	quit(0 if failures==0 else 1)
