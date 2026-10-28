extends SceneTree
## Real HUD regression: independent bounds, wheel over description, first-day action,
## keyboard scroll and a permanent close button at common laptop resolutions.
## Run with -- --demo --demo-full; add --capture without --headless for screenshots.
var failures: Array[String] = []
var measurements: Array[Dictionary] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	_run.call_deferred()

func settle() -> void:
	for frame in 6: await process_frame

func contains(outer: Rect2, inner: Rect2) -> bool:
	return outer.grow(1.0).encloses(inner)

func node_text(node: Node) -> String:
	var result := str(node.text) if node is Label or node is Button else ""
	for child in node.get_children(): result += " " + node_text(child)
	return result

func _run() -> void:
	var world = load("res://scenes/world.tscn").instantiate()
	root.add_child(world)
	await settle()
	world.set_process(false)
	var g = world.game
	g.s.queue.clear()
	g.cfg.idleMinutesPerSecond = 0.0
	g.s["tips_seen"] = g.story.get("tips", []).map(func(t): return str(t.id))
	g.changed.emit()
	var hud = world.hud
	hud._close_tip()
	hud.close_location()
	hud._obj_expanded = true
	var fit = root.get_node("ScreenFit")
	for resolution in [Vector2i(1280, 720), Vector2i(1366, 768)]:
		root.size = resolution
		await settle()
		for loc in ["tiem_sau", "ben_xe_6"]:
			hud.close_location()
			world.player.position = world.door_of(loc)
			hud.open_location(loc)
			await settle()
			var label := "%dx%d_%s" % [resolution.x, resolution.y, loc]
			var viewport := Rect2(Vector2.ZERO, fit.view_size())
			var panel: Rect2 = hud._location.get_global_rect()
			var scroll: ScrollContainer = hud._loc_scroll
			check(hud._location.get_parent() == hud._root, label + ": independent of objective row")
			check(contains(viewport, panel) and panel.position.y <= 80.0, label + ": panel stays within viewport")
			check(contains(panel, hud._loc_leave.get_global_rect()), label + ": leave button inside panel")
			check(contains(panel, scroll.get_global_rect()) and scroll.size.y > 200.0, label + ": useful bounded scroll area")
			check(scroll.is_ancestor_of(hud._loc_desc), label + ": description shares the action scroll")
			if loc == "tiem_sau":
				var intro: Control = null
				for card in hud._loc_cards.get_children():
					if "Chào chú Sơn" in node_text(card): intro = card
				check(intro != null, label + ": first introduction action is present")
				check(intro != null and contains(scroll.get_global_rect(), intro.get_global_rect()), label + ": first-day introduction is immediately visible")
				# This day has few cards; also exercise a longer story/context state.
				var original_desc: String = hud._loc_desc.text
				hud._loc_desc.text = original_desc + "\n" + original_desc.repeat(20)
				await settle()
				# Exercise event propagation over the description, the originally stuck area.
				var pointer: Vector2 = scroll.get_global_rect().position + Vector2(60.0, 30.0)
				var motion := InputEventMouseMotion.new()
				motion.position = pointer
				root.push_input(motion, true)
				var wheel := InputEventMouseButton.new()
				wheel.position = pointer
				wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
				wheel.pressed = true
				wheel.factor = 1.0
				root.push_input(wheel, true)
				await settle()
				check(scroll.scroll_vertical > 0, label + ": wheel over description reaches actions")
				var last: Control = hud._loc_cards.get_child(hud._loc_cards.get_child_count() - 1)
				scroll.ensure_control_visible(last)
				await settle()
				check(contains(scroll.get_global_rect(), last.get_global_rect()), label + ": last action can be fully reached")
				check(contains(viewport, hud._loc_leave.get_global_rect()), label + ": close stays visible at end of list")
				if intro != null:
					intro.grab_focus()
					await settle()
					check(contains(scroll.get_global_rect(), intro.get_global_rect()), label + ": focus reveals first-day action")
				hud._loc_desc.text = original_desc
				scroll.scroll_vertical = 0
				await settle()
			measurements.append({"case":label,"panel":str(panel),"scroll":str(scroll.get_global_rect()),"leave":str(hud._loc_leave.get_global_rect())})
			await capture(world, label)
			hud._loc_leave.pressed.emit()
			check(hud.location_open() == "" and not hud._location.visible, label + ": leave closes panel")
	var file := FileAccess.open("res://build/location-panel-layout.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures":failures,"measurements":measurements}, "\t"))
	print("PASS location panel: both laptop resolutions, description wheel, reachable intro/final action, fixed leave" if failures.is_empty() else "FAIL location panel: %d" % failures.size())
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func capture(world, label: String) -> void:
	if not "--capture" in OS.get_cmdline_user_args(): return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/neighborhood-preview"))
	world.camera.position = world.player.position + world.cam_offset()
	world.camera.look_at(world.player.position + Vector3.UP, Vector3.UP)
	world._update_cutaway(1.0)
	await settle()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/neighborhood-preview/location_%s.png" % label)
