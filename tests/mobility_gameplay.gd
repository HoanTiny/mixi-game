extends SceneTree
## Regression: clothing remains on the same rig through delivery mount/dismount.
## --headless --path . -s res://tests/mobility_gameplay.gd -- --demo --street-demo
const Props := preload("res://scripts/world/props3d.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	world.set_process(false)
	var game = world.game
	game.s.queue.clear()
	game.s.used = 10.0 - float(game.cfg.dayStart)
	game.cfg.idleMinutesPerSecond = 0.0
	game.s.cash = 1000000
	game.s["tips_seen"] = game.story.get("tips", []).map(func(t): return str(t.id))
	game.changed.emit()
	world.hud._close_tip()
	world.hud.close_location()
	var avatar = world.player_body
	assert(avatar.has_method("set_colors") and avatar.has_method("sit"), "Rigged avatar must remain active")
	assert(not avatar.materials.is_empty(), "Missing textured avatar materials")
	var initial_color = avatar.materials[0].get_shader_parameter("shirt_color")
	# Use the active clothes inventory, not the retired Wardrobe.buy API.
	game._own("ao_caro")
	game._own("mu_luoi_trai")
	game.wear_item("ao_caro")
	game.wear_item("mu_luoi_trai")
	world.update_outfit()
	assert(world.player_body == avatar, "Changing clothes replaced the custom rig")
	assert(avatar.materials[0].get_shader_parameter("shirt_color") != initial_color, "Equipping clothes did not update the mesh material")
	assert(game.s.cash == 1000000 and game.wardrobe().worn.ao == "ao_caro")
	assert(avatar._worn.cap.node.visible, "Equipped cap is missing")
	game.do_action("toc_cut_neat")
	assert(game.s.hair_style == "neat")
	world.update_outfit()
	var destination: Vector3 = world.door_of("tiem_sau")
	var offer: Dictionary = game.delivery_offer("com_hanh", "Cơm Hạnh", "Khách phố mẫu", destination.x, 120.0, destination.z)
	game.delivery_accept(offer)
	world._update_ride()
	assert(world._riding and world._ride_bike.visible, "Accepting delivery did not mount the bike")
	assert(world.player_body == avatar and is_equal_approx(avatar.position.z, Props.RIDER_Z))
	assert(avatar.has_method("wear"), "Riding avatar must support a helmet")
	assert(avatar._worn.helmet.node.visible and not avatar._worn.cap.node.visible, "Riding must replace the cap with a helmet")
	for frame in 12:
		avatar.animate(1.0 / 30.0, 1.0)
		await process_frame
	assert(avatar.animation.current_animation != avatar.walk_clip, "Rider changed back to walking on the bike")
	world.player.position = world.loc_point("com_hanh", 0.0, 0.9)
	world.player.rotation.y = 0.55
	if "--capture" in OS.get_cmdline_user_args():
		world.camera.position = world.player.position + Vector3(3.8, 3.1, 5.2)
		world.camera.look_at(world.player.position + Vector3(0, 0.9, 0))
		world.camera.size = 4.1
		world.hud.hide()
		for frame in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/mobility-player-ride-preview.png")
	game.delivery_cancel()
	world._update_ride()
	assert(not world._riding and not world._ride_bike.visible)
	assert(is_zero_approx(avatar.position.z) and world.player_body == avatar, "Dismount did not preserve the same dressed avatar")
	assert(avatar._worn.cap.node.visible and not avatar._worn.helmet.node.visible, "Dismount must restore the equipped cap")
	avatar.animate(1.0 / 30.0, 1.0)
	assert(avatar.animation.current_animation == avatar.walk_clip, "Dismounted avatar cannot walk")
	avatar.animate(1.0 / 30.0, 0.0)
	assert(avatar.animation.current_animation == avatar.idle_clip, "Stopped avatar did not return to idle")
	assert(game.wardrobe().worn.ao == "ao_caro" and game.s.hair_style == "neat", "Delivery changed clothing or hairstyle")
	assert(game.s.cash == 960000, "Visual mounting/dismounting charged extra money")
	print("PASS: wardrobe material, same-rig outfit, haircut, delivery mount, riding animation, dismount, walk/idle and money")
	quit()
