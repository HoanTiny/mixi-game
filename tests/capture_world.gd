extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.size = Vector2i(1366, 800)
	var scene = load("res://scenes/world.tscn").instantiate()
	root.add_child(scene)
	for i in range(30):
		await process_frame
	# Exercise the actual HUD action/tween and night-dialog flow.
	scene.hud.open_location("xom_bo_me")
	var before: float = scene.game.s.used
	scene.hud._perform("tam")
	await create_timer(1.3).timeout
	if scene.hud.blocking() or not scene.player.visible or scene.game.s.used <= before:
		push_error("HUD bath interaction failed")
		quit(1)
		return
	scene.hud._go_to_sleep()
	await process_frame
	if not scene.hud.dialogs.visible:
		push_error("Night dialog failed")
		quit(1)
		return
	scene.hud.dialogs._cancel_night()
	scene.hud.open_location("xom_bo_me")
	await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("res://tests/daily-life-preview.png")
	scene.hud._go_to_sleep()
	scene.hud.dialogs._end_day()
	await process_frame
	if scene.game.day() != 19 or not scene.player.visible:
		push_error("HUD overnight transition failed")
		quit(1)
		return
	print("HUD interaction PASS; viewport captured")
	quit()
