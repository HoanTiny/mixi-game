extends SceneTree
## Tạm: chụp đám đông (góc cao chếch ở chợ, quán cóc, trẻ con, người đi bộ, toàn cảnh, góc chơi ở chợ) và in số người.
const TIPS := ["di_lai", "canh_chinh", "tien", "an_uong", "tam_giat", "phong_do", "so", "noi_chuyen", "met", "viec_nho", "ve_chai", "dien_thoai", "toi", "cho_o", "mua"]
func _initialize() -> void:
	create_timer(420.0).timeout.connect(func() -> void:
		print("WATCHDOG quit")
		quit(2))
	_run.call_deferred()
func _snap(path: String, frames := 40) -> void:
	for i in frames:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path.get_file())
func _look(w, from: Vector3, at: Vector3) -> void:
	w.camera.position = from
	w.camera.look_at(at, Vector3.UP)
func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[-1]
	var game = root.get_node("GameState").game
	game.reset()
	game.new_game("full")
	while not game.s.queue.is_empty():
		game.resolve_first_available()
	game.s["tips_seen"] = TIPS.duplicate()
	game.s.used = 3.5
	game._commit()
	var w = load("res://scenes/world.tscn").instantiate()
	root.add_child(w)
	for i in 5:
		await process_frame
	if w.crowd == null:
		print("NO CROWD")
		quit(1)
		return
	print("crowd ", w.crowd.counts)
	var u0 := Time.get_ticks_usec()
	for i in 60:
		w.crowd.update(1.0 / 60.0, Vector2(w.player.position.x, w.player.position.z))
	print("crowd update us/frame ", (Time.get_ticks_usec() - u0) / 60)
	for c in w.hud.get_children():
		if c is CanvasItem:
			c.visible = false
	w.set_process(false)
	var cho: Vector3 = w.door_of("cho_cau_nho")
	_look(w, cho + Vector3(11, 24, 32), cho)
	await _snap(out + "/cao_32.png")
	_look(w, cho + Vector3(8, 12, 12), cho)
	await _snap(out + "/cho.png")
	# Ba chỗ ngồi quán cóc gần chỗ của truyện nhất.
	var center: Vector2 = w.area.dress.center
	var seats: Array = w.area.dress.seats.duplicate()
	seats.sort_custom(func(a, b) -> bool: return (a[0] as Vector2).distance_to(center) < (b[0] as Vector2).distance_to(center))
	for k in mini(1, seats.size()):
		var p: Vector2 = seats[k * 7 % seats.size()][0]
		_look(w, Vector3(p.x + 6.0, 6.5, p.y + 6.0), Vector3(p.x, 0.5, p.y))
		await _snap(out + "/quan_coc_%d.png" % k)
	# Góc chơi thường: An đứng ở cổng chợ.
	w.player.position = cho + Vector3(1.5, 0, 1.5)
	w.set_process(true)
	await _snap(out + "/choi_cho.png", 60)
	quit()
