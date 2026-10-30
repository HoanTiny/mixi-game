extends SceneTree
## Render three actual gameplay views for visual QA, without changing the user's save.
func _initialize() -> void:
	call_deferred("capture")

func frame(path: String) -> void:
	for i in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)

func capture() -> void:
	root.size = Vector2i(1366,800)
	var scene = load("res://scenes/world.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.hud.close_location()
	scene.game.s.used = 4.0
	scene.game.changed.emit()
	scene._update_lighting(10.0)
	await frame("res://tests/neighborhood-preview.png")
	scene.hud.hide()
	scene.camera.size = 5.2
	scene.player.position = Vector3(6.0,0,-1.5)
	scene.player.rotation.y = 0.3
	await frame("res://tests/character-preview.png")
	scene.camera.size = 14.5
	scene.player.position = scene.door_of("com_hanh")
	scene.camera.position = scene.player.position + scene.CAM_OFFSET
	await frame("res://tests/shop-preview.png")
	var initial: Vector3 = scene.player.position
	scene._target = initial + Vector3(2,0,1)
	var started := Time.get_ticks_msec()
	for i in range(120):
		await process_frame
	var elapsed := Time.get_ticks_msec()-started
	if scene.player.position.distance_to(initial) < 0.5:
		push_error("Character movement failed after model replacement")
		quit(1)
		return
	print("Movement PASS. Sample frame time: ",float(elapsed)/120.0," ms")
	print("Art captures complete. Draw calls: ",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	quit()
