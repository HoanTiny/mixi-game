extends Node3D
## Màn phố 3D kiểu Nobody: con phố ở Bình Thạnh nhìn chéo từ trên xuống. Bấm chuột để đi,
## bấm vào cửa tiệm hoặc người đứng trước cửa để mở việc làm, lớp học ở đó (phím E khi đứng gần).
## Nhà cửa, người, xe lấy mô hình thật theo data/models.json; thiếu file thì dựng khối hình tạm.

const GameLogic := preload("res://scripts/game_logic.gd")
const Hud := preload("res://scripts/world/hud.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")
const Models := preload("res://scripts/world/models.gd")
const Character := preload("res://scripts/world/character.gd")
const Audio := preload("res://scripts/world/audio.gd")
const TubeHouse := preload("res://scripts/world/tube_house.gd")

## Mỗi địa điểm nằm phía bắc con phố, mặt tiền nhìn ra đường (z = -5).
## x: tâm dọc phố · size: rộng, sâu, cao · npc: người đứng trước cửa (bấm vào cũng mở địa điểm),
## npc_id: khóa của người đó trong REPS và data/talks.json.
## tube: dựng thành nhà ống (floors tầng, sign chữ biển hiệu, units số căn liền nhau, shop tầng trệt buôn bán).
const LOCATIONS := {
	"nga_tu": {"name": "Ngã tư Hàng Xanh", "desc": "Phát tờ rơi cho người qua đường.", "x": -64.0, "size": Vector3(0, 0, 0), "color": "8d8a83"},
	"tram_xe_buyt": {"name": "Trạm xe buýt đi Quận 1", "desc": "Đón khách nước ngoài, việc cuối tuần.", "x": -55.0, "size": Vector3(5, 3, 2.8), "color": "3c7d6b"},
	"phuong": {"name": "UBND phường", "desc": "Nhà văn hóa có lớp tiếng Anh tối. Công an phường đăng ký tạm trú.", "x": -45.0, "size": Vector3(12, 8, 7), "color": "e2c55c"},
	"thu_vien": {"name": "Thư viện quận", "desc": "Tự học miễn phí.", "x": -32.0, "size": Vector3(10, 8, 6), "color": "a98467"},
	"trung_tam": {"name": "Trung tâm dạy nghề", "desc": "Khóa điện lạnh và tin học văn phòng.", "x": -19.5, "size": Vector3(11, 8, 8.5), "color": "b9b2dc"},
	"cua_hang": {"name": "Cửa hàng 24 giờ", "desc": "Tuyển thu ngân. Quầy sửa điện thoại bên cạnh.", "x": -8.5, "size": Vector3(8, 7, 4.5), "tube": {"floors": 3, "sign": "CỬA HÀNG 24H"}, "color": "8cc3df"},
	"quan_ca_phe": {"name": "Cà phê Góc Phố", "desc": "Quán Vy làm thêm.", "x": 1.0, "size": Vector3(9, 7, 4.5), "tube": {"floors": 3, "sign": "CÀ PHÊ GÓC PHỐ"}, "color": "6f9474", "npc": "Vy", "npc_id": "vy", "npc_color": "d9776b"},
	"quan_com": {"name": "Quán cơm tấm", "desc": "Cần người rửa bát.", "x": 10.5, "size": Vector3(8, 7, 4.2), "tube": {"floors": 3, "sign": "CƠM TẤM"}, "color": "e39a66"},
	"tra_da": {"name": "Quán trà đá đầu hẻm", "desc": "Hàng xóm ngồi tán chuyện.", "x": 18.0, "size": Vector3(4, 3, 2.6), "tube": {"floors": 2, "shop": false}, "color": "c8503f", "npc": "Ông Tư", "npc_id": "ongTu", "npc_color": "8a8a7a"},
	"tiem_chu_bay": {"name": "Điện lạnh chú Bảy", "desc": "Sửa máy lạnh, học việc, làm thợ.", "x": 25.0, "size": Vector3(7, 7, 4.5), "tube": {"floors": 3, "sign": "ĐIỆN LẠNH BẢY"}, "color": "6f8fa8", "npc": "Chú Bảy", "npc_id": "chuBay", "npc_color": "3f5f7a"},
	"phong_tro": {"name": "Dãy trọ cô Sáu", "desc": "Phòng trọ của Minh.", "x": 36.5, "size": Vector3(12, 8, 9), "tube": {"floors": 3, "sign": "NHÀ TRỌ CÔ SÁU", "units": 3}, "color": "eadcae", "npc": "Cô Sáu", "npc_id": "coSau", "npc_color": "b5577a"},
	"vua_ve_chai": {"name": "Vựa ve chai cô Tám", "desc": "Thu mua chai nhựa, lon nhôm, bìa giấy.", "x": 66.0, "size": Vector3(7, 3.2, 5), "color": "8b7d5b", "npc": "Cô Tám", "npc_color": "6b4f3a"},
	"cong_trinh": {"name": "Công trình", "desc": "Phụ hồ, công nhật.", "x": 51.0, "size": Vector3(14, 9, 10), "color": "9c9a93", "npc": "Tuấn", "npc_id": "tuan", "npc_color": "c9853a"},
}
const FRONT_Z := -5.0
const DOOR_Z := -4.1
const STREET_X := Vector2(-90.0, 76.0)
const STREET_Z := Vector2(-4.6, 4.6)
const SPEED := 6.0
## Camera xa nhất (nhìn toàn phố) và gần nhất (thấy rõ nhân vật); con lăn chuột chỉnh giữa hai mức.
const CAM_OFFSET := Vector3(0, 24, 17)
const CAM_NEAR := Vector3(0, 6.5, 9.0)
const INTERACT_RANGE := 2.4
## Bảng tên tiệm treo ở mặt tiền, không cao hơn mức này để không lọt lên mép trên màn hình dưới bảng mục tiêu.
const SIGN_MAX := 4.6

var game
var hud
var models := Models.new()
var tubes
## Nhà dân có số (địa chỉ giao hàng): {"x", "no", "name"}.
var homes: Array = []
## Mũi tên lơ lửng chỉ chỗ lấy món hoặc nhà khách của đơn giao hàng đang chạy.
var _marker: Node3D
## Nhân vật đứng một chỗ (nhân vật phụ trước cửa) cần chạy hoạt cảnh đứng thở.
var idlers: Array = []
## 0 là gần nhất, 1 là xa nhất.
var zoom := 0.3
## Thùng rác dọc vỉa hè để lục ve chai: {"id", "pos"}.
var bins: Array = []
const BIN_RANGE := 1.4
var audio
var camera: Camera3D
var sun: DirectionalLight3D
var env: Environment
var player: Node3D
var player_body: Node3D
var font: SystemFont
var lamps: Array = []
var door_rings := {}
var walkers: Array = []
var bikes: Array = []

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
	game = GameState.game
	font = UI.text_font()
	_build_environment()
	tubes = TubeHouse.new(FRONT_Z, font)
	_build_street()
	for id in LOCATIONS:
		_build_location(id, LOCATIONS[id])
	_build_fillers()
	_build_props()
	_build_bins()
	_build_traffic()
	player = _character("player", Color("3d6fa8"), Color("2c2f3a"))
	player_body = player.get_child(0)
	add_child(player)
	# Vòng vàng dưới chân để luôn nhận ra Minh giữa đám đông.
	var marker := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.55
	disc.bottom_radius = 0.55
	disc.height = 0.02
	marker.mesh = disc
	var marker_mat := _mat(Color(0.95, 0.76, 0.3, 0.55))
	marker_mat.emission_enabled = true
	marker_mat.emission = Color("f2c14e")
	marker_mat.emission_energy_multiplier = 0.5
	marker.material_override = marker_mat
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	marker.position = Vector3(0, 0.1, 0)
	player.add_child(marker)
	player.add_child(_label3d("Minh", Vector3(0, 2.15, 0), 22))
	player.position = door_of("phong_tro") + Vector3(-1.5, 0, 0.8)
	# Về từ màn khác (xe buýt từ Quận 1) thì hiện ra ở chỗ đó.
	var gs := get_node("/root/GameState")
	if gs.spawn_at != "" and LOCATIONS.has(gs.spawn_at):
		player.position = door_of(gs.spawn_at) + Vector3(1.5, 0, 0.8)
		gs.spawn_at = ""
	camera = Camera3D.new()
	camera.fov = 34
	add_child(camera)
	camera.position = player.position + cam_offset()
	camera.look_at(player.position + Vector3(0, 1, 0), Vector3.UP)
	camera.current = true

	hud = Hud.new()
	hud.world = self
	hud.game = game
	add_child(hud)
	audio = Audio.new()
	audio.world = self
	audio.game = game
	add_child(audio)
	hud.dialogs.visibility_changed.connect(func() -> void:
		if hud.dialogs.visible:
			audio.play("dialog"))
	game.changed.connect(_on_changed)
	_on_changed()
	# Dùng khi chụp màn hình kiểm tra: "-- --demo --demo-open=quan_com" mở sẵn một địa điểm.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--demo-open="):
			var id := arg.substr(12)
			player.position = door_of(id)
			camera.position = player.position + cam_offset()
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
	env.ssao_intensity = 1.6
	env.fog_enabled = true
	env.fog_light_color = Color("8f8c86")
	env.fog_density = 0.004
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)


func _build_street() -> void:
	# Mặt đường, vỉa hè, vạch kẻ và phần đất trống phía sau (nền sẽ thay bằng texture gạch sau).
	_block(Vector3(200, 0.1, 60), Vector3(-7, -0.1, 0), Color("4a4b4e"))
	_block(Vector3(176, 0.05, 6), Vector3(-7, 0, 0), Color("3d3e41"))
	_block(Vector3(176, 0.16, 2.2), Vector3(-7, 0, -4.1), Color("8a8780"))
	_block(Vector3(176, 0.16, 2.2), Vector3(-7, 0, 4.1), Color("8a8780"))
	_block(Vector3(6, 0.06, 26), Vector3(-64, 0, -18), Color("3d3e41"))
	var x := -94.0
	while x < 80.0:
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
	var sign_height := 3.4
	var model := models.spawn("buildings." + id, null, size) if size.x > 0.0 else null
	if model:
		model.position = Vector3(x, 0, FRONT_Z)
		holder.add_child(model)
		sign_height = minf(float(model.get_meta("height")) + 0.8, SIGN_MAX)
	if size.x > 0.0:
		var center := Vector3(x, 0, FRONT_Z - size.z / 2.0)
		if model == null and loc.has("tube"):
			sign_height = _build_tube(id, loc, holder)
		elif model == null:
			_block(size, center, color, holder)
			# Cửa, mái hiên và bảng hiệu ở mặt tiền.
			_block(Vector3(1.6, 2.3, 0.1), Vector3(x, 0, FRONT_Z + 0.02), Color("2a2a2e"), holder)
			if size.y < 3.5:
				sign_height = size.y + 0.6
			else:
				_block(Vector3(size.x * 0.9, 0.12, 1.6), Vector3(x, 2.7, FRONT_Z + 0.8), color.darkened(0.25), holder)
				_block(Vector3(size.x * 0.7, 0.9, 0.12), Vector3(x, 3.0, FRONT_Z + 0.06), Color("f4efe1"), holder)
				for floor_y in range(4, int(size.y) - 1, 3):
					for wx in [-size.x * 0.3, size.x * 0.3]:
						_block(Vector3(1.4, 1.2, 0.08), Vector3(x + wx, floor_y, FRONT_Z + 0.03), Color("5c6f80"), holder)
				sign_height = minf(size.y + 0.8, SIGN_MAX)
			if id == "cong_trinh":
				_scaffold(x, size, holder)
		if id == "tra_da":
			for sx in [-1.2, 0.0, 1.2]:
				_block(Vector3(0.35, 0.4, 0.35), Vector3(x + sx, 0, -3.4), Color("2f6fb0"), holder)
		var body := StaticBody3D.new()
		body.set_meta("loc", id)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.position = center + Vector3(0, size.y / 2.0, 0)
		body.add_child(cs)
		holder.add_child(body)
	else:
		# Ngã tư: không có nhà, chỉ có cột đèn giao thông và một vùng bấm.
		_block(Vector3(0.18, 4.2, 0.18), Vector3(x + 3.2, 0, -4.6), Color("2b2b2b"), holder)
		_block(Vector3(0.45, 1.1, 0.4), Vector3(x + 3.2, 3.4, -4.6), Color("1f1f1f"), holder)
		_glow(Vector3(x + 3.2, 4.25, -4.38), Color("e8483b"), holder)
		var area := StaticBody3D.new()
		area.set_meta("loc", id)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(5, 2, 4)
		cs.shape = bs
		cs.position = Vector3(x, 1, -6)
		area.add_child(cs)
		holder.add_child(area)
	holder.add_child(_label3d(loc.name, Vector3(x, sign_height, FRONT_Z + 0.5), 36))

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

	if loc.has("npc"):
		var npc := _character("npc." + str(loc.get("npc_id", "")), Color(loc.npc_color), Color("3a3a40"))
		npc.position = door_of(id) + Vector3(1.6, 0, 0.2)
		npc.rotation.y = PI
		holder.add_child(npc)
		npc.add_child(_label3d(loc.npc, Vector3(0, 2.0, 0), 22))
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


## Tiệm dựng thành một hoặc vài căn nhà ống liền nhau; biển hiệu đặt ở căn giữa.
func _build_tube(id: String, loc: Dictionary, holder: Node3D) -> float:
	var tube: Dictionary = loc.tube
	var size: Vector3 = loc.size
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var units := int(tube.get("units", 1))
	var w := size.x / float(units)
	var top := 0.0
	for u in units:
		var x: float = float(loc.x) - size.x / 2.0 + w * (float(u) + 0.5)
		var main := u == units / 2
		var wall := Color(loc.color) if main else Color(loc.color).darkened(0.06 * float(u % 2 + 1))
		top = maxf(top, tubes.house(holder, x, w, maxf(size.z, 8.0), int(tube.get("floors", 3)), wall, rng,
			str(tube.get("sign", "")) if main else "", bool(tube.get("shop", true)) and main))
	return minf(top + 0.8, SIGN_MAX)


## Nhà ống chen vào các khoảng trống dọc phố và một dãy nhà cao phía sau cho phố có chiều sâu.
func _build_fillers() -> void:
	var holder := Node3D.new()
	holder.name = "nha_pho"
	add_child(holder)
	var used := [Vector2(-67.5, -60.5)]
	for id in LOCATIONS:
		var loc: Dictionary = LOCATIONS[id]
		if loc.size.x > 0.0:
			used.append(Vector2(float(loc.x) - loc.size.x / 2.0, float(loc.x) + loc.size.x / 2.0))
	used.sort_custom(func(a, b) -> bool: return a.x < b.x)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var x := -96.0
	var centers := []
	for r in used:
		if r.x > x:
			centers.append_array(tubes.fill(holder, x, r.x, rng))
		x = maxf(x, r.y)
	centers.append_array(tubes.fill(holder, x, 80.0, rng))
	tubes.back_row(holder, -96.0, 80.0, FRONT_Z - 16.0, rng)
	# Đánh số nhà lẻ từ đầu phố (phía bắc đường), gắn biển số nhỏ cạnh cửa: địa chỉ để giao hàng.
	centers.sort()
	homes = []
	for i in centers.size():
		var hx: float = centers[i]
		if hx < STREET_X.x - 1.0 or hx > STREET_X.y + 1.0:
			continue
		var no := 1 + 2 * homes.size()
		homes.append({"x": hx, "no": no, "name": "Nhà số %d" % no})
		var plate := Label3D.new()
		plate.text = str(no)
		plate.font = font
		plate.font_size = 40
		plate.pixel_size = 0.01
		plate.modulate = Color("ffffff")
		plate.outline_size = 0
		plate.position = Vector3(hx + 1.2, 2.25, FRONT_Z + 0.2)
		holder.add_child(plate)
		var board := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.5, 0.35, 0.04)
		board.mesh = bm
		board.material_override = _mat(Color("1e5aa8"))
		board.position = Vector3(hx + 1.2, 2.25, FRONT_Z + 0.16)
		holder.add_child(board)


func _scaffold(x: float, size: Vector3, parent: Node3D) -> void:
	var front := FRONT_Z + 0.6
	var px := x - size.x / 2.0
	while px <= x + size.x / 2.0 + 0.01:
		_block(Vector3(0.1, size.y + 1.0, 0.1), Vector3(px, 0, front), Color("b0a48a"), parent)
		px += 2.0
	for y in range(2, int(size.y) + 1, 2):
		_block(Vector3(size.x, 0.08, 0.9), Vector3(x, y, front - 0.3), Color("8a7a5a"), parent)
	_block(Vector3(size.x, size.y * 0.6, 0.05), Vector3(x, size.y * 0.4, front + 0.05), Color(0.2, 0.45, 0.3, 0.55), parent, true)


func _build_props() -> void:
	# Cột điện và dây điện chằng chịt dọc vỉa hè phía bắc.
	# Cột đặt ở chỗ giáp ranh hai căn nhà để không che biển hiệu, cách nhau chừng 10 đến 16 m.
	var edges := []
	for id in LOCATIONS:
		var loc: Dictionary = LOCATIONS[id]
		if loc.size.x > 0.0:
			edges.append(float(loc.x) - loc.size.x / 2.0)
			edges.append(float(loc.x) + loc.size.x / 2.0)
	edges.sort()
	var poles := []
	var last := -92.0
	for e in edges + [76.0]:
		if e - last < 10.0:
			continue
		var px: float = e if e - last <= 16.0 else last + 14.0
		_block(Vector3(0.28, 7.5, 0.28), Vector3(px, 0, -3.3), Color("6b6a66"))
		_block(Vector3(1.6, 0.12, 0.12), Vector3(px, 6.9, -3.3), Color("55544f"))
		poles.append(px)
		last = px
	for i in range(poles.size() - 1):
		for k in 3:
			var a := Vector3(poles[i], 6.95 - k * 0.25, -3.3 + (k - 1) * 0.5)
			var b := Vector3(poles[i + 1], 6.95 - k * 0.25, -3.3 + (k - 1) * 0.5)
			_wire(a, b)
	# Hàng rào sắt, cây và xe máy dựng phía nam như hình mẫu.
	var fx := -94.0
	while fx < 80.0:
		_block(Vector3(3.8, 0.08, 0.08), Vector3(fx + 1.9, 1.05, 5.25), Color("7d7f84"))
		_block(Vector3(0.08, 1.1, 0.08), Vector3(fx, 0, 5.25), Color("7d7f84"))
		fx += 4.0
	var tx := -88.0
	var tree_rng := RandomNumberGenerator.new()
	tree_rng.seed = 5
	while tx < 76.0:
		var tree := models.spawn("tree", tree_rng)
		if tree:
			tree.position = Vector3(tx, 0, 6.6)
			tree.rotation.y = tree_rng.randf() * TAU
			add_child(tree)
			tx += 11.0
			continue
		# Cây ở vỉa hè phía nam nằm giữa camera và phố: để thấp và nhỏ cho khỏi che đường.
		_block(Vector3(0.3, 2.4, 0.3), Vector3(tx, 0, 6.6), Color("5a4634"))
		var crown := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.1
		sm.height = 1.8
		crown.mesh = sm
		crown.material_override = _mat(Color("4f6b45"))
		crown.position = Vector3(tx, 3.0, 6.6)
		add_child(crown)
		tx += 11.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 16:
		var bx := rng.randf_range(-86.0, 72.0)
		var bike := _bike(Color.from_hsv(rng.randf(), 0.45, 0.7), rng)
		bike.position = Vector3(bx, 0, 3.7)
		bike.rotation.y = rng.randf_range(-0.3, 0.3)
		add_child(bike)
	# Đèn đường, bật khi trời tối.
	var lx := -86.0
	while lx < 76.0:
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
	for i in 8:
		var bike := _bike(Color.from_hsv(rng.randf(), 0.5, 0.75), rng)
		var rider := _character("people", Color.from_hsv(rng.randf(), 0.35, 0.6), Color("30323a"), rng, "helmet")
		rider.position = Vector3(0, 0.45, 0)
		# Người mẫu nhìn theo trục z, xe chạy theo trục x: quay người cho ngồi đúng chiều xe.
		rider.rotation.y = PI / 2.0
		Models.play(rider.get_child(0), "sit")
		if rider.get_child(0).has_method("sit"):
			var c: Node3D = rider.get_child(0)
			c.sit(true)
			c.animate(0.0, 0.0)
		bike.add_child(rider)
		var lane := -1.4 if i % 2 == 0 else 1.4
		var dir := 1.0 if lane > 0 else -1.0
		bike.position = Vector3(rng.randf_range(-92, 78), 0, lane)
		bike.rotation.y = 0.0 if dir > 0 else PI
		add_child(bike)
		bikes.append({"node": bike, "dir": dir, "speed": rng.randf_range(6.0, 10.0)})
	for i in 10:
		var w := _character("people", Color.from_hsv(rng.randf(), 0.3, 0.65), Color.from_hsv(rng.randf(), 0.2, 0.35), rng)
		var side := -3.8 if i % 2 == 0 else 3.9
		w.position = Vector3(rng.randf_range(-86, 72), 0, side)
		add_child(w)
		walkers.append({"node": w, "goal": w.position, "speed": rng.randf_range(1.2, 2.0), "wait": rng.randf_range(0, 3)})


# ---------------------------------------------------------------- vòng lặp

func cam_offset() -> Vector3:
	return CAM_NEAR.lerp(CAM_OFFSET, zoom)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		zoom = clampf(zoom + (-0.08 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.08), 0.0, 1.0)
		return
	if hud.blocking():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_pending_click = event.position
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		var bin := nearest_bin()
		if bin != "":
			_scavenge(bin)
			return
		var near := nearest_location()
		if near != "":
			hud.open_location(near)


func _physics_process(delta: float) -> void:
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
		step = key_dir.normalized() * _speed() * delta
	elif _target != null:
		var to: Vector3 = _target - player.position
		to.y = 0
		if to.length() <= _speed() * delta:
			player.position = Vector3(_target.x, 0, _target.z)
			_target = null
			if _target_loc != "":
				hud.open_location(_target_loc)
				_target_loc = ""
		else:
			step = to.normalized() * _speed() * delta
	if step != Vector3.ZERO:
		player.position += step
		_add_walk(step.length())
		audio.step(delta)
		player.rotation.y = lerp_angle(player.rotation.y, atan2(step.x, step.z), 0.25)
		if player_body.has_method("animate"):
			player_body.animate(delta, _speed() / SPEED)
		elif not Models.play(player_body, "walk"):
			_walk_t += delta * 11.0
			player_body.position.y = absf(sin(_walk_t)) * 0.06
	elif player_body.has_method("animate"):
		player_body.animate(delta, 0.0)
	elif not Models.play(player_body, "idle"):
		player_body.position.y = 0.0
	for c in idlers:
		c.animate(delta, 0.0)
	player.position.x = clampf(player.position.x, STREET_X.x, STREET_X.y)
	player.position.z = clampf(player.position.z, STREET_Z.x, STREET_Z.y)

	var cam_goal := player.position + cam_offset()
	camera.position = camera.position.lerp(cam_goal, clampf(delta * 4.0, 0.0, 1.0))
	camera.look_at(camera.position - cam_offset() + Vector3(0, lerpf(1.3, 1.0, zoom), 0), Vector3.UP)

	var near := nearest_location()
	var bin := nearest_bin()
	hud.set_prompt("bin:" + bin if bin != "" else near)
	for id in door_rings:
		var ring: MeshInstance3D = door_rings[id]
		var pulse := 1.0 + (0.12 * sin(Time.get_ticks_msec() / 180.0) if id == near else 0.0)
		ring.scale = Vector3(pulse, 0.3, pulse)
	if hud.location_open() != "" and door_of(hud.location_open()).distance_to(player.position) > INTERACT_RANGE + 1.5:
		hud.close_location()

	_update_traffic(delta)
	_update_delivery()
	_check_day_end()


# ---------------------------------------------------------------- ve chai, phong độ

## Phong độ thấp thì lê bước, đi chậm hẳn.
func _speed() -> float:
	if game.has_needs() and game.phong_do() < float(game.cfg.needs.slowBelow):
		return SPEED * 0.7
	return SPEED


func nearest_bin() -> String:
	for b in bins:
		if Vector3(player.position.x, 0, player.position.z).distance_to(b.pos) < BIN_RANGE:
			return b.id
	return ""


func _scavenge(id: String) -> void:
	var lock: String = game.scrap_lock(id)
	if lock != "":
		_float_text(lock, Color("ffd27a"))
		return
	var got: Dictionary = game.scavenge(id)
	var parts := []
	for k in got:
		if int(got[k]) > 0:
			parts.append("+%d %s" % [int(got[k]), game.cfg.scrap[k].name])
	_float_text(", ".join(parts) if not parts.is_empty() else "Trống trơn", Color("c8e6a0") if not parts.is_empty() else Color("bbbbbb"))
	audio.play("step", 0.6)


func _build_bins() -> void:
	var x := -86.0
	var i := 0
	while x < 74.0:
		var pos := Vector3(x, 0, -3.0 if i % 2 == 0 else 3.4)
		var holder := Node3D.new()
		holder.position = pos
		add_child(holder)
		_block(Vector3(0.6, 0.85, 0.55), Vector3.ZERO, Color("2e7d32"), holder)
		_block(Vector3(0.66, 0.08, 0.6), Vector3(0, 0.85, 0), Color("1b4d20"), holder)
		bins.append({"id": "t%d" % i, "pos": pos})
		x += 10.5 + float(i % 3)
		i += 1


# ---------------------------------------------------------------- giao đồ ăn

## Chỗ cần tới của đơn đang chạy: quán (chưa lấy món) hoặc nhà khách. null nếu không có đơn.
func delivery_target():
	var o: Dictionary = game.delivery_active()
	if o.is_empty():
		return null
	if not o.picked:
		return door_of(str(o.shop))
	return Vector3(float(o.dest_x), 0, DOOR_Z)


## Tạo một đơn mới từ vị trí thật trên phố: quán ngẫu nhiên, giao tới nhà dân hoặc một chỗ khác
## cách quán 15 đến 110 m. Tiền công tính theo cả quãng đi lấy lẫn đi giao.
func make_offer() -> Dictionary:
	var shops: Array = game.cfg.delivery.shops.keys()
	var shop: String = shops.pick_random()
	var sx := door_of(shop).x
	var dests := []
	for h in homes:
		dests.append({"name": h.name, "x": h.x})
	for id in LOCATIONS:
		if id != shop and id != "nga_tu":
			dests.append({"name": str(LOCATIONS[id].name), "x": door_of(id).x})
	dests = dests.filter(func(d) -> bool: return absf(float(d.x) - sx) >= 15.0 and absf(float(d.x) - sx) <= 110.0)
	if dests.is_empty():
		return {}
	var dest: Dictionary = dests.pick_random()
	var meters := absf(player.position.x - sx) + absf(sx - float(dest.x)) + 4.0
	return game.delivery_offer(shop, str(LOCATIONS[shop].name), str(dest.name), float(dest.x), meters)


func _update_delivery() -> void:
	var target = delivery_target()
	if _marker == null:
		_marker = Node3D.new()
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.45
		cm.bottom_radius = 0.0
		cm.height = 0.9
		cone.mesh = cm
		var m := StandardMaterial3D.new()
		m.emission_enabled = true
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cone.material_override = m
		_marker.add_child(cone)
		add_child(_marker)
	_marker.visible = target != null
	if target == null:
		return
	var picked: bool = game.delivery_active().picked
	var c := Color("ff9f1c") if not picked else Color("2ecc71")
	var mat: StandardMaterial3D = _marker.get_child(0).material_override
	mat.albedo_color = c
	_marker.position = target + Vector3(0, 3.4 + 0.25 * sin(Time.get_ticks_msec() / 220.0), 0)
	_marker.rotation.y += 0.04
	if hud.blocking() or Vector3(player.position.x, 0, player.position.z).distance_to(target) > INTERACT_RANGE:
		return
	if not picked:
		game.delivery_pickup()
		_float_text("Đã lấy món", Color("ffd27a"))
		audio.play("done")
	else:
		var r: Dictionary = game.delivery_drop()
		if not r.is_empty():
			_float_text("Giao trễ!" if r.late else ("Tip +" + GameLogic.fmt_k(int(r.tip)) if int(r.tip) > 0 else "Đã giao"),
				Color("ff8a7a") if r.late else Color("7fe0a0"))


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
	if door_of("phong_tro").distance_to(Vector3(player.position.x, 0, player.position.z)) <= INTERACT_RANGE + 1.0:
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
		if n.position.x > 82.0:
			n.position.x = -96.0
		elif n.position.x < -96.0:
			n.position.x = 82.0
	for w in walkers:
		var n: Node3D = w.node
		if float(w.wait) > 0.0:
			w["wait"] = float(w.wait) - delta
			if n.get_child(0).has_method("animate"):
				n.get_child(0).animate(delta, 0.0)
			Models.play(n.get_child(0), "idle")
			continue
		if n.get_child(0).has_method("animate"):
			n.get_child(0).animate(delta, float(w.speed) / 4.0)
		Models.play(n.get_child(0), "walk")
		var to: Vector3 = w.goal - n.position
		if to.length() < 0.2:
			w["goal"] = Vector3(clampf(n.position.x + randf_range(-14, 14), -86, 72), 0, n.position.z)
			w["wait"] = randf_range(0.5, 4.0)
		else:
			var stp: Vector3 = to.normalized() * w.speed * delta
			n.position += stp
			n.rotation.y = atan2(stp.x, stp.z)


func _on_changed() -> void:
	if not game.is_started():
		_last_money = -1
		return
	var money := int(game.s.money)
	if _last_money >= 0 and money != _last_money:
		_float_text(GameLogic.fmt_money(money - _last_money) if money < _last_money else "+" + GameLogic.fmt_money(money - _last_money),
			Color("7fe0a0") if money > _last_money else Color("ff8a7a"))
		audio.play("earn" if money > _last_money else "spend")
	_last_money = money
	# Sang ngày mới: Minh thức dậy trước cửa phòng trọ.
	if game.day() != _last_day:
		if _last_day != -1:
			player.position = door_of("phong_tro") + Vector3(-1.5, 0, 0.8)
			camera.position = player.position + cam_offset()
			_target = null
			_target_loc = ""
			_walk_meters = 0.0
		_last_day = game.day()
	_update_lighting(game.clock())


## Ánh sáng theo giờ trong game: sáng vàng nhạt, trưa gắt, chiều cam, tối đèn đường.
func _update_lighting(hour: float) -> void:
	var t := clampf((hour - 6.0) / 16.0, 0.0, 1.0)
	var elevation := lerpf(18.0, 70.0, sin(t * PI))
	sun.rotation_degrees = Vector3(-elevation, -35.0 + t * 70.0, 0)
	var warm := Color("ffe9cf")
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
	sun.light_energy = 0.35 if hour >= 20.0 else 1.1
	env.ambient_light_color = c.lerp(Color("c9c6be"), 0.5)
	env.ambient_light_energy = 0.35 if hour >= 20.0 else 0.55
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
	mi.material_override = _mat(color)
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


## Người khối tạm: chân, thân, đầu. Con đầu tiên là phần thân để nhún khi đi.
## Người theo mô hình trong models.json (key như "player", "npc.vy", "people"), thiếu thì dựng khối.
## Con đầu tiên luôn là phần thân (mô hình hoặc khối) để nhún nhảy hay phát hoạt cảnh.
## Không có file mô hình thì dựng nhân vật có khớp (character.gd): Minh và nhân vật phụ có ngoại hình riêng,
## người đi đường ngẫu nhiên.
func _character(key: String, shirt: Color, pants: Color, rng: RandomNumberGenerator = null, hat := "") -> Node3D:
	var m := models.spawn(key, rng)
	if m == null:
		var id := "minh" if key == "player" else key.trim_prefix("npc.")
		var look: Dictionary = Character.LOOKS.get(id, {})
		if look.is_empty():
			var r := rng if rng != null else RandomNumberGenerator.new()
			look = Character.random_look(r)
		if hat != "":
			look["hat"] = hat
		var root := Node3D.new()
		root.add_child(Character.make(look))
		if key.begins_with("npc."):
			idlers.append(root.get_child(0))
		return root
	var root := Node3D.new()
	root.add_child(m)
	return root


func _bike(color: Color, rng: RandomNumberGenerator) -> Node3D:
	var m := models.spawn("bike", rng)
	if m == null:
		return _motorbike(color)
	var root := Node3D.new()
	root.add_child(m)
	return root


func _person(shirt: Color, pants: Color) -> Node3D:
	var root := Node3D.new()
	var body := Node3D.new()
	root.add_child(body)
	_block(Vector3(0.42, 0.75, 0.24), Vector3(0, 0, 0), pants, body)
	var torso := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.25
	cap.height = 0.85
	torso.mesh = cap
	torso.material_override = _mat(shirt)
	torso.position = Vector3(0, 1.12, 0)
	body.add_child(torso)
	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.19
	sm.height = 0.38
	head.mesh = sm
	head.material_override = _mat(Color("d6a27a"))
	head.position = Vector3(0, 1.72, 0)
	body.add_child(head)
	var hair := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.2
	hm.height = 0.22
	hair.mesh = hm
	hair.material_override = _mat(Color("1d1a18"))
	hair.position = Vector3(0, 1.82, -0.02)
	body.add_child(hair)
	return root


func _motorbike(color: Color) -> Node3D:
	var root := Node3D.new()
	_block(Vector3(1.7, 0.45, 0.32), Vector3(0, 0.3, 0), color, root)
	_block(Vector3(0.7, 0.18, 0.36), Vector3(-0.2, 0.75, 0), Color("222224"), root)
	_block(Vector3(0.1, 0.55, 0.5), Vector3(0.75, 0.6, 0), Color("38383c"), root)
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
