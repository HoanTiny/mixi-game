extends Node3D
## Màn Quận 1: dẫn khách Úc đi chợ Bến Thành (việc khach_uc). Đi tới từng điểm dừng theo
## data/tour_ben_thanh.json, chọn cách tiếp khách; xong chuyến thì đón xe buýt về Bình Thạnh,
## lúc đó mới tính tiền công và giờ của việc như mọi việc khác.

const GameLogic := preload("res://scripts/game_logic.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")
const Landmarks := preload("res://scripts/world/landmarks.gd")
const TubeHouse := preload("res://scripts/world/tube_house.gd")
const SPEED := 6.0
## Camera lùi xa và thấp hơn màn phố để thấy cả tháp đồng hồ phía sau.
const CAM_OFFSET := Vector3(0, 15, 30)
const CAM_LOOK := Vector3(0, 7.5, -8)
const AREA_X := Vector2(-46.0, 46.0)
const AREA_Z := Vector2(1.0, 14.0)
const REACH := 2.2

var game
var tour: Dictionary = {}
var action_id := ""
var player: Node3D
var camera: Camera3D
var font: SystemFont
var landmarks
var _guests: Array = []
var _bikes: Array = []
var _rings := {}
var _done: Array = []
var _target = null
var _target_stop := ""
var _start_hour := 8.0
var _step_hours := 2.0
var _busy := false
var _env: Environment
var _sun: DirectionalLight3D
var _lamps: Array = []
# Giao diện
var _clock: Label
var _list: Label
var _dialog: PanelContainer
var _box: VBoxContainer


func _ready() -> void:
	game = get_node("/root/GameState").game
	tour = JSON.parse_string(FileAccess.get_file_as_string("res://data/tour_ben_thanh.json"))
	action_id = get_node("/root/GameState").tour
	if action_id == "":
		action_id = "khach_uc"
	var a: Dictionary = game.get_action(action_id)
	var st: Dictionary = game.action_status(a)
	_start_hour = float(st.get("start", game.clock()))
	_step_hours = float(a.get("hours", 6)) / float(tour.stops.size() + 1)
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI", "Arial", "Noto Sans"])
	_build_world()
	_build_ui()
	_update_light()
	_show(tour.get("title", ""), "", str(tour.intro), [{"label": "Bắt đầu", "on": _close}])


# ---------------------------------------------------------------- dựng cảnh

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _block(size: Vector3, pos: Vector3, c: Color, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c)
	mi.position = pos + Vector3(0, size.y / 2.0, 0)
	(parent if parent else self).add_child(mi)
	return mi


func _label(text: String, pos: Vector3, size: int, parent: Node = null) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = font
	l.font_size = size
	l.pixel_size = 0.01
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.outline_size = 10
	l.modulate = Color("fbf6e9")
	l.outline_modulate = Color(0.08, 0.08, 0.1, 0.9)
	l.no_depth_test = true
	l.position = pos
	(parent if parent else self).add_child(l)
	return l


func _person(shirt: Color, skin: Color, hair: Color) -> Node3D:
	var root := Node3D.new()
	_block(Vector3(0.42, 0.75, 0.24), Vector3.ZERO, Color("3a3d48"), root)
	var torso := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.25
	cap.height = 0.85
	torso.mesh = cap
	torso.material_override = _mat(shirt)
	torso.position = Vector3(0, 1.12, 0)
	root.add_child(torso)
	for part in [[0.19, 0.38, 1.72, skin], [0.2, 0.22, 1.82, hair]]:
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = part[0]
		sm.height = part[1]
		mi.mesh = sm
		mi.material_override = _mat(part[3])
		mi.position = Vector3(0, part[2], 0)
		root.add_child(mi)
	add_child(root)
	return root


func _build_world() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.glow_intensity = 0.9
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 70.0
	add_child(_sun)

	# Nền, vỉa hè trước chợ, đường bùng binh có vạch kẻ.
	_block(Vector3(140, 0.1, 80), Vector3(0, -0.1, 0), Color("4a4b4e"))
	_block(Vector3(100, 0.12, 5.5), Vector3(0, 0, 2.6), Color("b9b2a3"))
	_block(Vector3(100, 0.05, 9.0), Vector3(0, 0, 10.0), Color("3d3e41"))
	var x := -48.0
	while x < 48.0:
		_block(Vector3(1.6, 0.07, 0.12), Vector3(x, 0, 10.0), Color("d8d4c8"))
		x += 3.4
	# Bồn hoa giữa bùng binh phía trước (chỉ thấy một góc).
	_block(Vector3(12, 0.5, 3), Vector3(0, 0, 16.5), Color("6b8e4e"))

	landmarks = Landmarks.new(font)
	landmarks.ben_thanh(self, Vector3.ZERO)
	var tubes := TubeHouse.new(-1.0, font)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1914
	var holder := Node3D.new()
	add_child(holder)
	# Dãy nhà phố sát hai cánh chợ (mỗi cánh dài tới x = ±21,5).
	tubes.fill(holder, -54.0, -22.0, rng)
	tubes.fill(holder, 22.0, 54.0, rng)

	# Xe bánh xèo và ghế nhựa ở góc phải chợ.
	_block(Vector3(1.8, 1.0, 0.9), Vector3(25.0, 0, 1.6), Color("d9d4c7"))
	_block(Vector3(1.9, 0.08, 1.0), Vector3(25.0, 1.9, 1.6), Color("2f6fb0"))
	for sx in [-1.5, -0.5, 0.5, 1.5]:
		_block(Vector3(0.38, 0.42, 0.38), Vector3(25.0 + sx, 0, 3.0), Color("c0392b") if int(sx * 2) % 2 == 0 else Color("2f6fb0"))
	# Đèn đường.
	for lx in [-30.0, -15.0, 0.0, 15.0, 30.0]:
		_block(Vector3(0.14, 5.2, 0.14), Vector3(lx, 0, 5.2), Color("4b4d52"))
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(lx, 5.0, 5.0)
		lamp.omni_range = 11.0
		lamp.light_color = Color("ffcf8a")
		add_child(lamp)
		_lamps.append(lamp)

	# Xe máy chạy quanh bùng binh.
	var brng := RandomNumberGenerator.new()
	brng.seed = 5
	for i in 10:
		var bike := Node3D.new()
		_block(Vector3(1.7, 0.45, 0.32), Vector3(0, 0.3, 0), Color.from_hsv(brng.randf(), 0.5, 0.75), bike)
		_block(Vector3(0.36, 0.7, 0.3), Vector3(-0.1, 0.75, 0), Color.from_hsv(brng.randf(), 0.35, 0.6), bike)
		_block(Vector3(0.32, 0.3, 0.32), Vector3(-0.1, 1.45, 0), Color("c0392b") if i % 3 == 0 else Color("e8e8e8"), bike)
		var lane := 7.6 if i % 2 == 0 else 12.0
		bike.position = Vector3(brng.randf_range(-48, 48), 0, lane)
		bike.rotation.y = 0.0 if lane > 10.0 else PI
		add_child(bike)
		_bikes.append({"node": bike, "dir": 1.0 if lane > 10.0 else -1.0, "speed": brng.randf_range(5.0, 9.0)})

	# Điểm dừng: vòng sáng và tên.
	for s in tour.stops:
		var p := Vector3(float(s.pos[0]), 0, float(s.pos[1]))
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.7
		tm.outer_radius = 0.9
		ring.mesh = tm
		var m := _mat(Color("f2c14e"))
		m.emission_enabled = true
		m.emission = Color("f2c14e")
		ring.material_override = m
		ring.position = p + Vector3(0, 0.15, 0)
		ring.scale = Vector3(1, 0.3, 1)
		add_child(ring)
		_rings[s.id] = ring
		_label(str(s.name), p + Vector3(0, 1.2, 0), 32)

	# Minh và ba vị khách Úc.
	player = _person(Color("3d6fa8"), Color("d6a27a"), Color("1d1a18"))
	player.position = Vector3(-6, 0, 6)
	_label("Minh", Vector3(0, 2.3, 0), 34, player)
	var looks := [["Ông Mark", Color("e74c3c"), Color("b0b0b0")], ["Bà Linda", Color("f1c40f"), Color("e3c16f")], ["Cậu Jack", Color("1abc9c"), Color("a0522d")]]
	for i in looks.size():
		var g := _person(looks[i][1], Color("f1c9a5"), looks[i][2])
		g.position = player.position + Vector3(-1.2 - i * 0.9, 0, 1.0 + (i % 2) * 0.8)
		_label(str(looks[i][0]), Vector3(0, 2.25, 0), 26, g)
		_guests.append({"node": g, "offset": Vector3(-1.3 - i * 0.9, 0, 0.9 + (i % 2) * 0.9)})

	camera = Camera3D.new()
	camera.fov = 40
	add_child(camera)
	camera.position = player.position + CAM_OFFSET
	camera.look_at(player.position + CAM_LOOK, Vector3.UP)
	camera.current = true


## Trời sáng hay tối theo giờ của chuyến đi.
func _update_light() -> void:
	var hour := _hour()
	var night := clampf((hour - 17.5) / 1.5, 0.0, 1.0)
	_env.background_color = Color("9ec6e6").lerp(Color("0b1020"), night)
	_env.ambient_light_color = Color("d6d3ca").lerp(Color("5a5f78"), night)
	_env.ambient_light_energy = lerpf(0.45, 0.35, night)
	_sun.light_energy = lerpf(0.85, 0.12, night)
	# Tỏa sáng chỉ cho neon về đêm; ban ngày bật lên làm tường kem chói trắng.
	_env.glow_enabled = night > 0.3
	_sun.light_color = Color("fff1d6").lerp(Color("8fa0c8"), night)
	_sun.rotation_degrees = Vector3(lerpf(-55, -20, clampf((hour - 6.0) / 12.0, 0, 1)), 35, 0)
	for l in _lamps:
		l.light_energy = 1.8 * night
	landmarks.set_night(night)


func _hour() -> float:
	return _start_hour + _step_hours * float(_done.size())


# ---------------------------------------------------------------- giao diện

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.theme = UI.make_theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	var info := PanelContainer.new()
	info.add_theme_stylebox_override("panel", UI.box(UI.HUD_BG, Color(1, 1, 1, 0.1), 8, 14))
	info.position = Vector2(16, 16)
	root.add_child(info)
	var v := VBoxContainer.new()
	info.add_child(v)
	v.add_child(UI.label("Quận 1 · " + str(tour.title), 17, UI.GOLD))
	_clock = UI.label("", 15, UI.HUD_TEXT)
	v.add_child(_clock)
	_list = UI.label("", 14, UI.HUD_TEXT)
	v.add_child(_list)
	var hint := UI.label("Bấm chuột để đi · WASD · bấm vòng vàng để tới điểm dừng", 12, UI.HUD_SOFT)
	v.add_child(hint)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	_dialog = PanelContainer.new()
	_dialog.custom_minimum_size = Vector2(600, 0)
	_dialog.add_theme_stylebox_override("panel", UI.box(UI.CARD, UI.LINE, 12, 24))
	center.add_child(_dialog)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	_dialog.add_child(_box)
	_dialog.visible = false
	_refresh_ui()


func _refresh_ui() -> void:
	_clock.text = "%s · Ngày %d · Tiền %s" % [GameLogic.hh(_hour()), game.day(), GameLogic.fmt_money(int(game.s.money))]
	var lines := []
	for s in tour.stops:
		lines.append(("✓ " if _done.has(s.id) else "○ ") + str(s.name))
	_list.text = "\n".join(lines)
	for id in _rings:
		_rings[id].visible = not _done.has(id)


## Hộp thoại: tiêu đề, người nói, nội dung và các lựa chọn {label, hint, lock, on}.
func _show(title: String, who: String, text: String, choices: Array) -> void:
	for c in _box.get_children():
		c.queue_free()
	_box.add_child(UI.wrap(title, 24, UI.INK))
	if who != "":
		_box.add_child(UI.label(who, 14, UI.TIM))
	_box.add_child(UI.wrap(text, 15, UI.INK))
	for c in choices:
		_box.add_child(UI.choice(str(c.label), str(c.get("hint", "")), str(c.get("lock", "")), c.on))
	_dialog.visible = true
	_busy = true


func _close() -> void:
	_dialog.visible = false
	_busy = false
	_refresh_ui()


func _open_stop(id: String) -> void:
	var stop: Dictionary = {}
	for s in tour.stops:
		if s.id == id:
			stop = s
	if stop.is_empty() or _done.has(id):
		return
	var choices := []
	for c in stop.choices:
		choices.append({"label": c.label, "hint": c.get("hint", ""), "lock": game.check(c.get("require", {})),
			"on": _choose.bind(stop, c)})
	_show(str(stop.title), str(stop.get("who", "")), str(stop.text), choices)


func _choose(stop: Dictionary, c: Dictionary) -> void:
	game.apply_effects(c.get("effects", {}))
	game._commit()
	_done.append(stop.id)
	_update_light()
	if _done.size() < tour.stops.size():
		_show(str(stop.title), "", str(c.reply), [{"label": "Đi tiếp", "on": _close}])
	else:
		_show(str(stop.title), "", str(c.reply) + "\n\n" + str(tour.outro), [{"label": "Đón xe buýt về Bình Thạnh", "on": _finish}])
	_refresh_ui()


## Xong chuyến: tính tiền công và giờ của việc, quay về trạm xe buýt ở Bình Thạnh.
func _finish() -> void:
	var gs := get_node("/root/GameState")
	if game.action_status(game.get_action(action_id)).ok:
		game.do_action(action_id)
	gs.tour = ""
	gs.spawn_at = "tram_xe_buyt"
	get_tree().change_scene_to_file("res://scenes/world.tscn")


# ---------------------------------------------------------------- vòng lặp

func _unhandled_input(event: InputEvent) -> void:
	if _busy:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var from := camera.project_ray_origin(event.position)
		var dir := camera.project_ray_normal(event.position)
		var hit = Plane(Vector3.UP, 0.0).intersects_ray(from, dir)
		if hit == null:
			return
		_target = Vector3(clampf(hit.x, AREA_X.x, AREA_X.y), 0, clampf(hit.z, AREA_Z.x, AREA_Z.y))
		_target_stop = ""
		for s in tour.stops:
			var p := Vector3(float(s.pos[0]), 0, float(s.pos[1]))
			if not _done.has(s.id) and p.distance_to(hit) < 3.0:
				_target = p
				_target_stop = s.id


func _physics_process(delta: float) -> void:
	var dir := Vector3.ZERO
	if not _busy:
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			dir.x -= 1
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			dir.x += 1
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			dir.z -= 1
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			dir.z += 1
	var step := Vector3.ZERO
	if dir != Vector3.ZERO:
		_target = null
		step = dir.normalized() * SPEED * delta
	elif _target != null and not _busy:
		var to: Vector3 = _target - player.position
		if to.length() <= SPEED * delta:
			player.position = _target
			_target = null
			if _target_stop != "":
				_open_stop(_target_stop)
				_target_stop = ""
		else:
			step = to.normalized() * SPEED * delta
	if step != Vector3.ZERO:
		player.position += step
		player.rotation.y = lerp_angle(player.rotation.y, atan2(step.x, step.z), 0.25)
	player.position.x = clampf(player.position.x, AREA_X.x, AREA_X.y)
	player.position.z = clampf(player.position.z, AREA_Z.x, AREA_Z.y)
	# Đi ngang qua điểm dừng bằng phím cũng mở luôn.
	if not _busy and dir != Vector3.ZERO:
		for s in tour.stops:
			if not _done.has(s.id) and Vector3(float(s.pos[0]), 0, float(s.pos[1])).distance_to(player.position) < REACH * 0.6:
				_open_stop(s.id)
	for g in _guests:
		var n: Node3D = g.node
		var goal: Vector3 = player.position + g.offset
		n.position = n.position.lerp(goal, clampf(delta * 2.2, 0, 1))
		var look: Vector3 = player.position - n.position
		if look.length() > 0.3:
			n.rotation.y = lerp_angle(n.rotation.y, atan2(look.x, look.z), 0.1)
	for b in _bikes:
		var n: Node3D = b.node
		n.position.x += b.dir * b.speed * delta
		if n.position.x > 50.0:
			n.position.x = -50.0
		elif n.position.x < -50.0:
			n.position.x = 50.0
	var pulse := 1.0 + 0.12 * sin(Time.get_ticks_msec() / 180.0)
	for id in _rings:
		_rings[id].scale = Vector3(pulse, 0.3, pulse)
	var goal_cam := player.position + CAM_OFFSET
	camera.position = camera.position.lerp(goal_cam, clampf(delta * 4.0, 0, 1))
	camera.look_at(camera.position - CAM_OFFSET + CAM_LOOK, Vector3.UP)
