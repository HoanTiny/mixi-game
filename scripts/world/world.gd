extends Node3D
## Màn phố 3D kiểu Nobody: phường An Hòa, thành phố Bình Giang, nhìn chéo từ trên xuống.
## Bấm chuột để đi, bấm vào cửa tiệm hoặc người đứng trước cửa để mở việc ở đó (phím E khi đứng gần).
## Nhà chia gian có vật liệu ảnh; cư dân có hình học cơ thể và khớp chuyển động.

const GameLogic := preload("res://scripts/game_logic.gd")
const Hud := preload("res://scripts/world/hud.gd")
const Citizen := preload("res://scripts/world/citizen.gd")
const AnCharacter := preload("res://scripts/world/an_character.gd")
const Neighborhood := preload("res://scripts/world/neighborhood.gd")
const WEATHERED := preload("res://scripts/world/weathered.gdshader")
var _surface_cache := {}

## Xóm trọ của An: nơi xuất phát mỗi sáng và nơi đi ngủ mỗi tối.
const HOME := "xom_bo_me"
## Để HUD đọc được id nhà mà không cần truy cập hằng số qua instance.
var home: String = HOME
## Mỗi địa điểm nằm phía bắc con phố, mặt tiền nhìn ra đường (z = -5).
## x: tâm dọc phố · size: rộng, sâu, cao · npcs: người đứng trước cửa (bấm vào cũng mở địa điểm)
## · shops: số mặt tiền nhỏ liền nhau · stalls: có sạp và ghế trà đá trên vỉa hè.
const LOCATIONS := {
	"tiem_toc": {"name":"Tiệm tóc đầu ngõ", "desc":"Cắt và nhuộm tóc · 08:00–19:00. Giá gồm công và thuốc nhuộm.", "x":-61.0, "size":Vector3(6,5,3.5), "color":"827363"},
	"ben_xe_6": {"name": "Bến xe số 6", "desc": "Xe đi kho khu công nghiệp và trung tâm nghề của Linh.", "x": -52.0, "size": Vector3(6, 3, 2.8), "color": "3c7d6b"},
	"cho_cau_nho": {"name": "Chợ Cầu Nhỏ", "desc": "Sạp vật tư, hàng đồ cũ, quán trà đá có bảng tin cho thuê phòng.", "x": -38.0, "size": Vector3(12, 6, 3.4), "color": "c8503f", "stalls": true},
	"com_hanh": {"name": "Cơm Hạnh", "desc": "Quán cơm phần cho người làm ca. Nhận ca phụ và giao cơm.", "x": -22.0, "size": Vector3(9, 7, 4.2), "color": "e39a66", "npcs": [{"name": "Chị Hạnh", "color": "c0603a"}]},
	"tiem_sau": {"name": "Tiệm Sáu Sửa", "desc": "Tiệm sửa xe có thêm một bàn sửa đồ gia dụng.", "x": -9.0, "size": Vector3(8, 7, 4.5), "color": "6f8fa8", "npcs": [{"name": "Chú Sáu", "color": "3f5f7a"}]},
	"xom_bo_me": {"name": "Xóm trọ Bờ Me", "desc": "Tám phòng quanh khoảng sân, dây phơi dưới mái tôn. Về đây để ăn cơm, tắm, nghỉ và ngủ.", "x": 8.0, "size": Vector3(16, 7, 7), "color": "9e9785",
		"npcs": [{"name": "Bà Tư", "color": "8a6f9a"}, {"name": "Linh", "color": "d9776b"}, {"name": "Cô Duyên", "color": "b5577a"}]},
	"ben_can": {"name": "Dãy quán Bến Cạn", "desc": "Năm quán chung lối đi và hạ tầng cũ bên rạch. Hợp đồng của anh Phúc.", "x": 34.0, "size": Vector3(22, 7, 4.0), "color": "9c9a93", "shops": 5,
		"npcs": [{"name": "Anh Phúc", "color": "c9853a"}, {"name": "Trâm", "color": "2f6f6a"}]},
}
const SHOP_COLORS := ["d9a35b", "7fa37a", "c46a5a", "6f8fb5", "b59a6f"]
const FRONT_Z := -5.0
const DOOR_Z := -4.1
const STREET_X := Vector2(-68.0, 60.0)
const STREET_Z := Vector2(-4.6, 4.6)
const SPEED := 3.2
const CAM_OFFSET := Vector3(7, 16, 18)
const INTERACT_RANGE := 2.4

var game
var hud
var camera: Camera3D
var sun: DirectionalLight3D
var env: Environment
var player: Node3D
var player_body: Node3D
var font: SystemFont
var lamps: Array = []
var door_rings := {}
var residents: Array = []
var quest_marker: Label3D
var crowd
var resident_routes
var walkers: Array = []
var bikes: Array = []

var _player_path: Array = []
var _path_target = null
var _requested_target = null
var _player_repath := 0.0
var _target = null
var _target_loc := ""
var _pending_click = null
var _last_money := -1
var _last_day := -1
var _walk_t := 0.0
## Quãng đường đã đi nhưng chưa quy ra giờ; cộng dồn rồi trừ giờ theo từng nấc 5 phút.
var _walk_meters := 0.0
var _night_prompt_day := -1


func _ready() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_4X
	# Giữ tên project cũ để user:// tiếp tục tìm đúng thư mục bản lưu.
	DisplayServer.window_set_title("Trước mùa mưa")
	game = GameState.game
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI", "Arial", "Noto Sans"])
	_build_environment()
	_build_street()
	for id in LOCATIONS:
		_build_location(id, LOCATIONS[id])
	_build_props()
	_build_street_details()
	_build_traffic()
	resident_routes = preload("res://scripts/world/resident_routes.gd").new(self)
	player = _person(Color("626a5b"), Color("41453f"), "An")
	player_body = player.get_child(0)
	add_child(player)
	# Vòng vàng dưới chân để luôn nhận ra An giữa đám đông.
	var marker := MeshInstance3D.new()
	var disc := TorusMesh.new()
	disc.inner_radius = 0.35
	disc.outer_radius = 0.39
	marker.mesh = disc
	var marker_mat := _mat(Color(0.95, 0.76, 0.3, 0.55))
	marker_mat.emission_enabled = true
	marker_mat.emission = Color("f2c14e")
	marker_mat.emission_energy_multiplier = 0.5
	marker.material_override = marker_mat
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.position = Vector3(0, 0.2, 0)
	marker.scale.y = 0.15
	player.add_child(marker)
	player.add_child(_label3d("An", Vector3(0, 2.3, 0), 34))
	player.position = door_of(HOME) + Vector3(-1.5, 0, 0.8)
	crowd = preload("res://scripts/world/crowd_motion.gd").new()
	crowd.obstacles = resident_routes.obstacles.duplicate()
	crowd.register(player)
	for r in residents: crowd.register(r.node)
	for w in walkers: crowd.register(w.node)
	for w in walkers: crowd.place(w.node,w.node.global_position)
	crowd.place(player,player.position)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12.0
	add_child(camera)
	camera.position = player.position + CAM_OFFSET
	camera.look_at(player.position + Vector3(0, 1, 0), Vector3.UP)
	camera.current = true

	quest_marker = _label3d("!",Vector3.ZERO,58)
	quest_marker.modulate = Color("efce75")
	add_child(quest_marker)
	hud = Hud.new()
	hud.world = self
	hud.game = game
	add_child(hud)
	game.changed.connect(_on_changed)
	_on_changed()
	if OS.get_cmdline_user_args().has("--street-demo") and OS.get_cmdline_user_args().has("--demo"):
		game.elapse(2.0)
		game.changed.emit()
		crowd.place(player,door_of("tiem_sau")+Vector3(0,0,1.0))
		camera.position=player.position+CAM_OFFSET
	# Dùng khi chụp màn hình kiểm tra: "-- --demo --demo-open=quan_com" mở sẵn một địa điểm.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--demo-open="):
			var id := arg.substr(12)
			player.position = door_of(id)
			camera.position = player.position + CAM_OFFSET
			hud.open_location.call_deferred(id)


# ---------------------------------------------------------------- dựng cảnh

func _build_environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("2b2f38")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c9c6be")
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_light_affect = 0.5
	env.ssao_intensity = 2.1
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.72
	env.adjustment_contrast = 1.12
	env.fog_enabled = true
	env.fog_light_color = Color("8f8c86")
	env.fog_density = 0.004
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.light_angular_distance = 0.5
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)


func _build_street() -> void:
	# Mặt đường, vỉa hè, vạch kẻ và phần đất trống phía sau (nền sẽ thay bằng texture gạch sau).
	_block(Vector3(150, 0.1, 60), Vector3(-4, -0.1, 0), Color("4a4b4e"))
	_block(Vector3(130, 0.05, 6), Vector3(-4, 0, 0), Color("3d3e41"))
	_block(Vector3(130, 0.16, 2.2), Vector3(-4, 0, -4.1), Color("8a8780"))
	_block(Vector3(130, 0.16, 2.2), Vector3(-4, 0, 4.1), Color("8a8780"))
	_block(Vector3(6, 0.06, 26), Vector3(-64, 0, -18), Color("3d3e41"))
	var x := -66.0
	while x < 60.0:
		_block(Vector3(1.6, 0.07, 0.12), Vector3(x, 0, 0), Color("d8d4c8"))
		x += 3.4
	# Mặt đất để bấm chuột đi.
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	ground.add_child(shape)
	add_child(ground)


func _build_location(id: String, loc: Dictionary) -> void:
	var size: Vector3 = loc.size
	var x: float = loc.x
	var color := Color(loc.color)
	var holder := Node3D.new()
	holder.name = id
	add_child(holder)
	var center := Vector3(x, 0, FRONT_Z - size.z / 2.0)
	var architecture := Neighborhood.new()
	architecture.build(self, holder, id, loc)
	var body := StaticBody3D.new()
	body.set_meta("loc", id)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = center + Vector3(0, size.y / 2.0, 0)
	body.add_child(cs)
	holder.add_child(body)

	# Vòng sáng trước cửa: điểm tương tác.
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.55
	torus.outer_radius = 0.72
	ring.mesh = torus
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("f2c14e")
	mat.emission_enabled = true
	mat.emission = Color("f2c14e")
	mat.emission_energy_multiplier = 0.6
	ring.material_override = mat
	ring.position = door_of(id) + Vector3(0, 0.12, 0)
	ring.scale = Vector3(1, 0.3, 1)
	holder.add_child(ring)
	door_rings[id] = ring

	var slot := 0
	for who in loc.get("npcs", []):
		var npc := _person(Color(who.color), Color("3a3a40"), str(who.name))
		npc.position = door_of(id) + Vector3(1.6 + slot * 1.2, 0, 0.2 + (slot % 2) * 0.5)
		npc.rotation.y = 0.15 + slot * 0.3
		holder.add_child(npc)
		npc.add_child(_label3d(who.name, Vector3(0, 2.25 + (slot % 2) * 0.35, 0), 32))
		slot += 1
		var nb := StaticBody3D.new()
		nb.set_meta("loc", id)
		var ncs := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.45
		cap.height = 1.9
		ncs.shape = cap
		ncs.position = Vector3(0, 0.95, 0)
		nb.add_child(ncs)
		npc.add_child(nb)
		residents.append({"node":npc,"body":nb,"name":str(who.name),"home":id,"slot":slot})


## Con rạch chạy dọc phía nam và cây cầu nhỏ trước chợ Cầu Nhỏ, chi tiết nhận diện của phường An Hòa.
func _build_canal() -> void:
	var water := _block(Vector3(140, 0.05, 5.0), Vector3(-4, -0.03, 10.5), Color("4f6f6a"))
	var wm := _mat(Color("4f6f6a"))
	water.material_override = wm
	wm.roughness = 0.15
	wm.metallic = 0.2
	_block(Vector3(140, 0.5, 0.6), Vector3(-4, -0.3, 7.7), Color("6e6a62"))
	var bx := float(LOCATIONS.cho_cau_nho.x)
	_block(Vector3(3.2, 0.25, 7.0), Vector3(bx, 0.15, 10.0), Color("8a7f72"))
	for side in [-1.5, 1.5]:
		_block(Vector3(0.1, 0.9, 7.0), Vector3(bx + side, 0.4, 10.0), Color("5e5a55"))


func _build_props() -> void:
	_build_canal()
	# Cột điện và dây điện chằng chịt dọc vỉa hè phía bắc.
	var poles := []
	var px := -60.0
	while px < 58.0:
		_block(Vector3(0.28, 7.5, 0.28), Vector3(px, 0, -3.3), Color("6b6a66"))
		_block(Vector3(1.6, 0.12, 0.12), Vector3(px, 6.9, -3.3), Color("55544f"))
		poles.append(px)
		px += 14.0
	for i in range(poles.size() - 1):
		for k in 3:
			var a := Vector3(poles[i], 6.95 - k * 0.25, -3.3 + (k - 1) * 0.5)
			var b := Vector3(poles[i + 1], 6.95 - k * 0.25, -3.3 + (k - 1) * 0.5)
			_wire(a, b)
	# Hàng rào sắt, cây và xe máy dựng phía nam như hình mẫu.
	var fx := -68.0
	while fx < 60.0:
		_block(Vector3(3.8, 0.08, 0.08), Vector3(fx + 1.9, 1.05, 5.25), Color("7d7f84"))
		_block(Vector3(0.08, 1.1, 0.08), Vector3(fx, 0, 5.25), Color("7d7f84"))
		fx += 4.0
	var tx := -62.0
	while tx < 58.0:
		_block(Vector3(0.35, 3.2, 0.35), Vector3(tx, 0, 6.6), Color("5a4634"))
		_build_tree_crown(Vector3(tx, 3.2, 6.6))
		tx += 11.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 16:
		var bx := rng.randf_range(-60.0, 56.0)
		var bike := _motorbike(Color.from_hsv(rng.randf(), 0.45, 0.7))
		bike.position = Vector3(bx, 0, 3.7)
		bike.rotation.y = rng.randf_range(-0.3, 0.3)
		add_child(bike)
	# Đèn đường, bật khi trời tối.
	var lx := -58.0
	while lx < 58.0:
		_block(Vector3(0.14, 5.2, 0.14), Vector3(lx, 0, 4.7), Color("4b4d52"))
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(lx, 5.0, 3.8)
		lamp.omni_range = 9.0
		lamp.light_color = Color("ffcf8a")
		lamp.light_energy = 0.0
		add_child(lamp)
		lamps.append(lamp)
		lx += 12.0


func _build_traffic() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 4:
		var bike := _motorbike(Color.from_hsv(rng.randf(), 0.5, 0.75))
		var rider := _person(Color.from_hsv(rng.randf(), 0.35, 0.6), Color("30323a"))
		rider.seated = true
		rider.position = Vector3(-0.15, 0.03, 0)
		rider.rotation.y = PI / 2
		bike.add_child(rider)
		var lane := -1.4 if i % 2 == 0 else 1.4
		var dir := 1.0 if lane > 0 else -1.0
		bike.position = Vector3(rng.randf_range(-66, 58), 0, lane)
		bike.rotation.y = 0.0 if dir > 0 else PI
		add_child(bike)
		bikes.append({"node": bike, "dir": dir, "speed": rng.randf_range(6.0, 10.0)})
	for i in 10:
		var w := _person(Color.from_hsv(rng.randf(), 0.3, 0.65), Color.from_hsv(rng.randf(), 0.2, 0.35))
		var side := -3.8 if i % 2 == 0 else 3.9
		w.position = Vector3(rng.randf_range(-62, 56), 0, side)
		add_child(w)
		walkers.append({"node": w, "goal": w.position, "speed": rng.randf_range(1.2, 2.0), "wait": rng.randf_range(0, 3)})


# ---------------------------------------------------------------- vòng lặp

func _unhandled_input(event: InputEvent) -> void:
	if hud.blocking():
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.size = maxf(10.0, camera.size - 1.0)
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.size = minf(28.0, camera.size + 1.0)
			return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_pending_click = event.position
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		var near := nearest_location()
		if near != "":
			hud.open_location(near)


func _physics_process(delta: float) -> void:
	if _target==null:
		_path_target=null
		_player_path.clear()
	if _pending_click != null:
		_handle_click(_pending_click)
		_pending_click = null

	var key_dir := Vector3.ZERO
	if not hud.blocking():
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			key_dir.x -= 1
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			key_dir.x += 1
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			key_dir.z -= 1
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			key_dir.z += 1
	var step := Vector3.ZERO
	if key_dir != Vector3.ZERO:
		_target = null
		_target_loc = ""
		step = key_dir.normalized() * SPEED * delta
	elif _target != null and not hud.blocking():
		if _target!=_path_target:
			_requested_target=_target
			_plan_player_path()
		_player_repath+=delta
		if _player_repath>1.5: _plan_player_path()
		while not _player_path.is_empty() and player.position.distance_to(_player_path[0])<0.08: _player_path.pop_front()
		var to: Vector3 = (_player_path[0] if not _player_path.is_empty() else _target) - player.position
		to.y = 0
		step = to.normalized() * minf(SPEED * delta,to.length())
	if step != Vector3.ZERO:
		step = crowd.move(player,step/maxf(delta,0.001),delta,key_dir==Vector3.ZERO,player.position.distance_to(_target) if _target!=null else INF)
		_add_walk(step.length())
		if step.length()>0.001: player.rotation.y = lerp_angle(player.rotation.y, atan2(step.x, step.z), 0.25)
		_walk_t += delta * 11.0
	if _target!=null and player.position.distance_to(_target)<0.12:
		_target=null
		if _target_loc!="":
			hud.open_location(_target_loc)
			_target_loc=""
	player.animate_motion(step.length() / maxf(delta,0.001), delta)
	player.position.x = clampf(player.position.x, STREET_X.x, STREET_X.y)
	player.position.z = clampf(player.position.z, STREET_Z.x, STREET_Z.y)

	var cam_goal := player.position + CAM_OFFSET
	camera.position = camera.position.lerp(cam_goal, clampf(delta * 4.0, 0.0, 1.0))
	camera.look_at(camera.position - CAM_OFFSET + Vector3(0, 1, 0), Vector3.UP)

	var near := nearest_location()
	hud.set_prompt(near)
	for id in door_rings:
		var ring: MeshInstance3D = door_rings[id]
		var pulse := 1.0 + (0.12 * sin(Time.get_ticks_msec() / 180.0) if id == near else 0.0)
		ring.scale = Vector3(pulse, 0.3, pulse)
	if hud.location_open() != "" and door_of(hud.location_open()).distance_to(player.position) > INTERACT_RANGE + 1.5:
		hud.close_location()

	if not hud.blocking(): resident_routes.tick(delta)
	_update_traffic(delta)
	_check_day_end()


## Đi bộ tốn giờ: cứ đủ 5 phút trong game thì trừ một lần, tránh lưu file mỗi khung hình.
func _add_walk(meters: float) -> void:
	if not game.is_started() or game.is_over():
		return
	_walk_meters += meters
	var hours: float = _walk_meters * float(game.cfg.get("walkHoursPerMeter", 0.0))
	if hours >= 1.0 / 12.0:
		_walk_meters = 0.0
		game.walk(hours)


## Hết giờ trong ngày: đang ở nhà thì hỏi đi ngủ, còn ở ngoài thì ngủ gục ngoài đường.
func _check_day_end() -> void:
	if hud.blocking() or not game.is_out_of_time() or not game.s.queue.is_empty():
		return
	_target = null
	_target_loc = ""
	if door_of(HOME).distance_to(Vector3(player.position.x, 0, player.position.z)) <= INTERACT_RANGE + 1.0:
		if _night_prompt_day != game.day():
			_night_prompt_day = game.day()
			hud.close_location()
			hud.dialogs.open_night()
	else:
		hud.close_location()
		game.sleep_outside()


func set_player_inside(inside: bool) -> void:
	player.visible = not inside
	if inside:
		_target = null
		_target_loc = ""


func _handle_click(screen_pos: Vector2) -> void:
	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * 300.0
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to))
	if hit.is_empty():
		return
	var col: Object = hit.collider
	if col.has_meta("travelling"):
		_float_text(str(col.get_meta("travelling")),Color("d3bd86"))
		return
	if col.has_meta("loc"):
		var id: String = col.get_meta("loc")
		_target = door_of(id)
		_target_loc = id
	else:
		_target = hit.position
		_target_loc = ""
	hud.close_location()


func _update_traffic(delta: float) -> void:
	for b in bikes:
		var n: Node3D = b.node
		n.position.x += b.dir * b.speed * delta
		if n.position.x > 64.0:
			n.position.x = -70.0
		elif n.position.x < -70.0:
			n.position.x = 64.0
	if not game.is_started() or game.is_over() or hud.blocking(): return
	for w in walkers:
		var n: Node3D = w.node
		if float(w.wait) > 0.0:
			n.animate_motion(0.0, delta)
			w["wait"] = float(w.wait) - delta
			continue
		var to: Vector3 = w.goal - n.position
		if to.length() < 0.2:
			w["goal"] = Vector3(clampf(n.position.x + randf_range(-14, 14), -62, 56), 0, n.position.z)
			if n.position.z<0:
				var point: Vector2 = resident_routes.graph.get_point_position(resident_routes.cell_at(w.goal))
				w.goal=Vector3(point.x,0,point.y)
			w["wait"] = randf_range(0.5, 4.0)
		else:
			var stp: Vector3 = crowd.move(n,to.normalized()*minf(w.speed,to.length()/maxf(delta,0.001)),delta,true,to.length())
			n.rotation.y = atan2(stp.x, stp.z)
			n.animate_motion(stp.length()/maxf(delta,0.001), delta)
			w.stuck = float(w.get("stuck",0.0))+delta if stp.length()<delta*0.2 else 0.0
			if w.stuck>2.0:
				w.goal=n.position
				w.wait=0.6
				w.stuck=0.0


func _on_changed() -> void:
	player.set_colors(game.s.get("appearance", AnCharacter.DEFAULT_COLORS))
	player.set_hair_style(str(game.s.get("hair_style","natural")))
	if not game.is_started():
		_last_money = -1
		return
	var money := int(game.s.cash)
	if _last_money >= 0 and money != _last_money:
		_float_text(GameLogic.fmt_money(money - _last_money) if money < _last_money else "+" + GameLogic.fmt_money(money - _last_money),
			Color("7fe0a0") if money > _last_money else Color("ff8a7a"))
	_last_money = money
	# Sang ngày mới: An thức dậy trước cửa xóm trọ.
	if game.day() != _last_day:
		if _last_day != -1:
			crowd.place(player,door_of(HOME) + Vector3(-1.5, 0, 0.8))
			camera.position = player.position + CAM_OFFSET
			_target = null
			_target_loc = ""
			_walk_meters = 0.0
		_last_day = game.day()
	_update_lighting(game.clock())
	resident_routes.refresh()
	var quest := preload("res://scripts/quest_guide.gd").active(game)
	quest_marker.visible = not quest.is_empty()
	if not quest.is_empty(): quest_marker.position = door_of(quest.location)+Vector3(0,2.8,0)


## Ánh sáng theo giờ trong game: sáng vàng nhạt, trưa gắt, chiều cam, tối đèn đường.
func _update_lighting(hour: float) -> void:
	var t := clampf((hour - 6.0) / 16.0, 0.0, 1.0)
	var elevation := lerpf(18.0, 70.0, sin(t * PI))
	sun.rotation_degrees = Vector3(-elevation, -35.0 + t * 70.0, 0)
	var warm := Color("d6c9b5")
	var noon := Color("fff6e8")
	var dusk := Color("ff9a5c")
	var night := Color("5b6c9a")
	var c: Color
	if hour < 9.0:
		c = warm.lerp(noon, (hour - 6.0) / 3.0)
	elif hour < 16.0:
		c = noon
	elif hour < 19.0:
		c = noon.lerp(dusk, (hour - 16.0) / 3.0)
	else:
		c = dusk.lerp(night, clampf((hour - 19.0) / 2.0, 0.0, 1.0))
	sun.light_color = c
	sun.light_energy = 0.25 if hour >= 20.0 else 0.85
	env.ambient_light_color = c.lerp(Color("c9c6be"), 0.5)
	env.ambient_light_energy = 0.3 if hour >= 20.0 else 0.36
	for lamp in lamps:
		lamp.light_energy = 2.2 if hour >= 18.0 else 0.0


# ---------------------------------------------------------------- truy vấn cho HUD

func location_info(id: String) -> Dictionary:
	return LOCATIONS[id]


func door_of(id: String) -> Vector3:
	return Vector3(float(LOCATIONS[id].x), 0, DOOR_Z)


func nearest_location() -> String:
	var best := ""
	var best_d := INTERACT_RANGE
	for id in LOCATIONS:
		var d := door_of(id).distance_to(Vector3(player.position.x, 0, player.position.z))
		if d < best_d:
			best = id
			best_d = d
	return best


func walk_to_location(id: String) -> void:
	_target = door_of(id)
	_target_loc = id


# ---------------------------------------------------------------- khối hình tạm

func _build_street_details() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 421
	# Gạch vỉa hè có khe, bó vỉa, cống thoát nước và những miếng vá đường.
	for side in [-1.0, 1.0]:
		for i in range(130):
			var x := -68.0 + float(i)
			_block(Vector3(0.97, 0.025, 2.1), Vector3(x, 0.16, side * 4.1), Color("858278").darkened(rng.randf_range(0.0, 0.18)))
			_block(Vector3(0.97, 0.22, 0.16), Vector3(x, 0, side * 3.02), Color("9a9588"))
		for i in range(10):
			var x := -60.0 + i * 12.0
			_block(Vector3(0.8, 0.03, 0.45), Vector3(x, 0.07, side * 2.8), Color("272c29"))
			for bar in range(6):
				_block(Vector3(0.04, 0.025, 0.43), Vector3(x - 0.32 + bar * 0.12, 0.1, side * 2.8), Color("64665d"))
	for i in range(45):
		_block(Vector3(rng.randf_range(0.3, 1.6), 0.004, rng.randf_range(0.25, 0.7)), Vector3(rng.randf_range(-65, 57), 0.052, rng.randf_range(-2.5, 2.5)), Color("353835"))
	for id in LOCATIONS:
		var x := float(LOCATIONS[id].x)
		# Bàn nước / bàn sửa, ghế và thùng hàng trước cửa.
		_block(Vector3(1.5, 0.09, 0.65), Vector3(x - 2.5, 0.8, -3.7), Color("71604b"))
		for dx in [-0.62, 0.62]:
			for dz in [-0.23, 0.23]:
				_block(Vector3(0.06, 0.8, 0.06), Vector3(x - 2.5 + dx, 0, -3.7 + dz), Color("383c36"))
		for i in range(3):
			_block(Vector3(0.14, 0.22, 0.14), Vector3(x - 2.9 + i * 0.35, 0.89, -3.7), Color("b3ad91"))
		_block(Vector3(0.55, 0.45, 0.5), Vector3(x - 2.5, 0, -2.9), Color("52675e"))
		_block(Vector3(0.6, 0.65, 0.55), Vector3(x - 4, 0, -4.5), Color("8b785a"))


func _surface(color: Color) -> Material:
	if color.a < 1.0:
		return _mat(color)
	var key := color.to_html()
	if not _surface_cache.has(key):
		var material := ShaderMaterial.new()
		material.shader = WEATHERED
		material.set_shader_parameter("base_color", color.lerp(Color(color.v, color.v, color.v), 0.28))
		_surface_cache[key] = material
	return _surface_cache[key]

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.92
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


## Khối hộp đặt đáy tại pos (pos.y là cao độ đáy).
func _block(size: Vector3, pos: Vector3, color: Color, parent: Node = null, transparent := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _surface(color)
	if transparent:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos + Vector3(0, size.y / 2.0, 0)
	(parent if parent != null else self).add_child(mi)
	return mi


func _glow(pos: Vector3, color: Color, parent: Node) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	mi.mesh = sm
	var m := _mat(color)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 2.0
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)


func _wire(a: Vector3, b: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.025
	cm.bottom_radius = 0.025
	cm.height = a.distance_to(b)
	mi.mesh = cm
	mi.material_override = _mat(Color("1d1d1f"))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.position = (a + b) / 2.0
	mi.rotation = Vector3(0, 0, PI / 2.0)


func _label3d(text: String, pos: Vector3, size: int) -> Label3D:
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
	return l


## Nhân vật có tỷ lệ cơ thể, trang phục và khớp chuyển động riêng.
func _person(shirt: Color, pants: Color, identity := "resident") -> Node3D:
	if identity == "An":
		var avatar := AnCharacter.new()
		avatar.setup(shirt, pants, identity)
		avatar.set_colors(game.s.get("appearance", AnCharacter.DEFAULT_COLORS))
		return avatar
	var citizen := Citizen.new()
	citizen.setup(shirt, pants, identity)
	return citizen


func _build_tree_crown(origin: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(origin.x)*170)+91
	var leaf := SphereMesh.new()
	leaf.radius = 1.0
	leaf.height = 2.0
	leaf.radial_segments = 8
	leaf.rings = 4
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = leaf
	multimesh.instance_count = 320
	for i in range(320):
		var angle := rng.randf()*TAU
		var r := sqrt(rng.randf())*1.75
		var position := Vector3(sin(angle)*r,rng.randf_range(-0.2,1.6)*(1.0-r*0.2),cos(angle)*r)
		var basis := Basis.from_euler(Vector3(rng.randf_range(-0.5,0.5),angle,rng.randf_range(-0.5,0.5)))
		basis = basis.scaled(Vector3(0.17,0.055,0.35)*rng.randf_range(0.8,1.3))
		multimesh.set_instance_transform(i,Transform3D(basis,position))
		multimesh.set_instance_color(i,Color("4c5841").lightened(rng.randf_range(-0.15,0.15)))
	var foliage := MultiMeshInstance3D.new()
	foliage.multimesh = multimesh
	var mat := _mat(Color("46523b"))
	mat.vertex_color_use_as_albedo = true
	foliage.material_override = mat
	foliage.position = origin
	add_child(foliage)


func _motorbike(color: Color) -> Node3D:
	var root := Node3D.new()
	var paint := _mat(color.lerp(Color("414b47"),0.7))
	Citizen.ellipsoid(root,Vector3(-0.35,0.56,0),Vector3(0.5,0.22,0.22),paint)
	Citizen.ellipsoid(root,Vector3(-0.22,0.79,0),Vector3(0.44,0.075,0.21),_mat(Color("272d29")))
	Citizen.ellipsoid(root,Vector3(0.58,0.7,0),Vector3(0.10,0.40,0.19),paint)
	_block(Vector3(0.75,0.05,0.32),Vector3(0.18,0.32,0),Color("343d35"),root)
	_block(Vector3(0.1,0.06,0.65),Vector3(0.63,1.02,0),Color("3d453e"),root)
	Citizen.ellipsoid(root,Vector3(0.72,0.98,0),Vector3(0.07,0.095,0.14),_mat(Color("c6c3a5")))
	for wx in [-0.62, 0.62]:
		var wheel := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.3
		cm.bottom_radius = 0.3
		cm.height = 0.12
		wheel.mesh = cm
		wheel.material_override = _mat(Color("1a1a1a"))
		wheel.rotation = Vector3(PI / 2.0, 0, 0)
		wheel.position = Vector3(wx, 0.3, 0)
		root.add_child(wheel)
		for side in [-1.0,1.0]:
			var hub := Citizen.ellipsoid(root,Vector3(wx,0.3,side*0.065),Vector3(0.14,0.14,0.014),_mat(Color("8d9286")))
			hub.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


func _float_text(text: String, color: Color) -> void:
	var l := _label3d(text, player.position + Vector3(0, 2.6, 0), 40)
	l.modulate = color
	add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position", l.position + Vector3(0, 1.4, 0), 1.6)
	tw.tween_property(l, "modulate:a", 0.0, 1.6).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)

func _plan_player_path() -> void:
	_player_repath=0.0
	_player_path=[]
	if _requested_target==null: return
	if player.position.z< -1.8 and _requested_target.z< -1.8:
		_player_path=resident_routes.route_for(player,_requested_target)
		if not _player_path.is_empty(): _target=_player_path[-1]
	else: _player_path=[_requested_target]
	_path_target=_target
