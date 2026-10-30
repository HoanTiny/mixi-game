extends SceneTree
## Run with -- --demo --demo-full; add --repair-visual with a renderer for screenshots.
var failures := 0
var site
var visual := false

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func key(code: Key, pressed := true, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	event.echo = echo
	site._input(event)

func near(spot: Dictionary) -> void:
	site._player.position = Vector3(spot.pos.x, 0, spot.pos.y + 1.35)
	site._cool = 0.0

func snapshot(name: String) -> void:
	if not visual: return
	site._cam.position = site._player.position + site.CAM_OFF
	site._cam.look_at(site._player.position + Vector3(0, 0.8, 0), Vector3.UP)
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/repair-flow/" + name + ".png")

func _init() -> void:
	await process_frame
	# Without --demo, GameState would run on (and save over) the player's real save.
	if root.get_node("GameState")._persist:
		push_error("Repair work site: run with -- --demo --demo-full so the test cannot save over player progress")
		quit(1)
		return
	create_timer(45).timeout.connect(func(): push_error("Repair test timed out"); quit(1))
	visual = "--repair-visual" in OS.get_cmdline_user_args()
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/repair-flow"))
	site = load("res://scripts/work/work_site.gd").new()
	site.kind = "repair"
	site.title = "Sửa đồ Tiệm Chú Sơn"
	site.cfg = root.get_node("GameState").game.cfg.minigames.repair.duplicate(true)
	site.cfg.machines = [site.cfg.machines[0]] # fan / capacitor
	root.add_child(site)
	site.set_process(false)
	site._start_play()
	var counter: Dictionary = site._counters()[0]
	var bench: Dictionary = site._bench()
	var shelf: Dictionary = site._spots.filter(func(s): return s.type == "shelf")[0]
	var tray: Dictionary = site._spots.filter(func(s): return s.type == "return_tray")[0]
	var block_count: int = site._blocks.size()
	site._customer(counter)
	near(counter)
	key(KEY_E); key(KEY_E, false)
	check(site._carry == ["may:0"], "pick up customer's machine")
	site._act(shelf)
	check(site._carry.size() == 1, "machine occupies both hands")
	key(KEY_Q)
	check(site._carry.is_empty() and counter.node != null, "Q returns machine to customer counter without losing it")
	key(KEY_E); key(KEY_E, false)
	near(bench)
	key(KEY_E); key(KEY_E, false)
	check(not bench.machine.is_empty() and not bench.machine.diagnosed, "machine placed undiagnosed")
	check(not ("Tụ quạt" in bench.label.text), "required component is hidden before diagnosis")
	site._repair_tick(3.0)
	check(not bench.machine.diagnosed, "standing near bench does not diagnose automatically")
	key(KEY_E)
	site._advance_repair_hold(1.0)
	check(site._repair_bar.visible and is_equal_approx(site._repair_bar.value, 1.0), "diagnosis progress appears")
	await snapshot("01_diagnosing")
	key(KEY_E, false)
	check(bench.progress == 0.0 and not bench.machine.diagnosed, "release cancels partial diagnosis")
	key(KEY_E)
	site._advance_repair_hold(1.99)
	check(not bench.machine.diagnosed, "diagnosis requires full two seconds")
	site._advance_repair_hold(0.02)
	check(bench.machine.diagnosed and "Tụ quạt" in bench.label.text, "diagnosis reveals actual correct component")
	key(KEY_E, false)
	# Grab two wrong components; a third cannot enter the hands.
	shelf.key = "phot"
	site._act(shelf); site._cool = 0.0
	shelf.key = "ro_le"
	site._act(shelf); site._cool = 0.0
	shelf.key = "tu"
	site._act(shelf)
	check(site._carry == ["part:phot", "part:ro_le"], "third component rejected at two-hand limit")
	check("Đầy tay rồi" in site._note_l.text, "full hands warning visible")
	var time_before: float = site._time_left
	key(KEY_E)
	check(is_equal_approx(site._time_left, time_before - 5.0), "wrong component deducts exactly five seconds")
	key(KEY_E, true, true)
	site._advance_repair_hold(1.0)
	check(is_equal_approx(site._time_left, time_before - 5.0), "held key echo does not repeatedly penalize")
	check(site._carry.size() == 2 and not bench.machine.fixed, "wrong component remains held and cannot fix machine")
	await snapshot("02_wrong_part")
	key(KEY_E, false)
	key(KEY_Q)
	check(site._carry == ["part:phot"] and not ("rơ le" in site._carry_l.text), "Q drops newest item and immediately refreshes carry HUD")
	site._act(tray)
	check(site._carry.is_empty() and "tay không" in site._carry_l.text, "return tray clears remaining components")
	check(site._blocks.size() == block_count, "discarding creates no floor collision obstacles")
	near(tray)
	await snapshot("04_return_tray")
	near(bench)
	# A wrong item on top must be dropped even if the correct one is underneath.
	site._act(shelf); site._cool = 0.0
	shelf.key = "phot"; site._act(shelf); site._cool = 0.0
	key(KEY_E); key(KEY_E, false)
	check(site._carry == ["part:tu", "part:phot"] and site._repair_phase == "", "last picked wrong part is rejected even with a correct spare")
	key(KEY_Q)
	check(site._carry == ["part:tu"], "Q exposes the correct spare underneath")
	site._act(tray)
	shelf.key = "tu"
	# Correct component is kept until assembly completes.
	site._act(shelf); site._cool = 0.0
	key(KEY_E)
	site._advance_repair_hold(1.0)
	check(site._carry == ["part:tu"] and not bench.machine.fixed, "assembly does not consume or repair immediately")
	site._player.position.x += 5.0
	site._advance_repair_hold(1.0)
	check(site._repair_phase == "" and bench.progress == 0.0, "leaving bench cancels assembly")
	key(KEY_E, false); near(bench)
	key(KEY_E); site._advance_repair_hold(1.0)
	site._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not site._repair_pressed and site._repair_phase == "", "losing focus cancels held input")
	key(KEY_E); site._advance_repair_hold(1.0)
	key(KEY_Q)
	check(site._carry.is_empty() and not bench.machine.fixed and site._repair_phase == "", "dropping during assembly cancels without completing")
	key(KEY_E, false)
	site._act(shelf); site._cool = 0.0
	key(KEY_E)
	site._advance_repair_hold(2.99)
	check(not bench.machine.fixed, "assembly requires full three seconds")
	await snapshot("03_assembling")
	site._advance_repair_hold(0.02)
	check(bench.machine.fixed and site._carry.is_empty(), "successful assembly consumes exactly one component")
	key(KEY_E, false)
	key(KEY_E); key(KEY_E, false)
	check(site._carry == ["may:0"], "finished machine can be collected")
	near(counter); key(KEY_E); key(KEY_E, false)
	check(site._done == 1 and site._bonus > 0 and counter.cust == null, "returning completed machine grants normal reward once")
	key(KEY_E); key(KEY_E, false)
	check(site._done == 1, "repeated handover cannot double reward")
	# Customer impatience cancels the associated work and leaves no ghost carry item.
	site._customer(counter); near(counter); key(KEY_E); key(KEY_E, false)
	near(bench); key(KEY_E); key(KEY_E, false); key(KEY_E)
	site._advance_repair_hold(1.0)
	site._counter_leave(counter)
	check(site._repair_phase == "" and bench.machine.is_empty() and site._carry.is_empty(), "customer departure clears pending diagnosis")
	key(KEY_E, false)
	site._customer(counter); near(counter); key(KEY_E); key(KEY_E, false)
	site._counter_leave(counter)
	check(site._carry.is_empty() and "tay không" in site._carry_l.text, "customer departure updates carry HUD immediately")
	# Last five seconds: a wrong attempt ends the shift without negative timer or repair.
	site._customer(counter); near(counter); key(KEY_E); key(KEY_E, false)
	near(bench); key(KEY_E); key(KEY_E, false); key(KEY_E)
	site._advance_repair_hold(2.0); key(KEY_E, false)
	shelf.key = "phot"; site._act(shelf); site._cool = 0.0
	site._time_left = 3.0
	key(KEY_E)
	check(site._state == "end" and site._time_left == 0.0 and not bench.machine.fixed, "wrong part at deadline ends shift safely")
	check(not root.get_node("GameState")._persist, "test does not save over player progress")
	site.queue_free()
	await process_frame
	print("Repair work site: ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	quit(0 if failures == 0 else 1)
