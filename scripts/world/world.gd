extends Node3D
## Màn phố 3D kiểu Nobody: con phố ở Bình Thạnh nhìn chéo từ trên xuống. Bấm chuột để đi,
## bấm vào cửa tiệm hoặc người đứng trước cửa để mở việc làm, lớp học ở đó (phím E khi đứng gần).
## Nhà cửa, người, xe lấy mô hình thật theo data/models.json; thiếu file thì dựng khối hình tạm.

const GameLogic := preload("res://scripts/game_logic.gd")
const Hud := preload("res://scripts/world/hud.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")
const Models := preload("res://scripts/world/models.gd")
const Character := preload("res://scripts/world/character.gd")
const Surfaces := preload("res://scripts/world/surfaces.gd")
const Audio := preload("res://scripts/world/audio.gd")
const TubeHouse := preload("res://scripts/world/tube_house.gd")

## Xóm trọ của An: nơi xuất phát mỗi sáng và nơi đi ngủ mỗi tối.
const HOME := "xom_bo_me"
## Để HUD đọc được id nhà mà không cần truy cập hằng số qua instance.
var home: String = HOME
## Mỗi địa điểm nằm phía bắc con phố, mặt tiền nhìn ra đường (z = -5).
## x: tâm dọc phố · size: rộng, sâu, cao · npcs: người đứng trước cửa (bấm vào cũng mở địa điểm),
## id của người đó là khóa trong story.reps và data/talks.json (trống thì không nói chuyện được).
## tube: dựng thành nhà ống (floors tầng, sign chữ biển hiệu, units số căn liền nhau, shop tầng trệt buôn bán).
## stalls: sạp chợ và ghế trà đá trên vỉa hè · line: dây phơi đồ trước cửa · scrap: chỗ bán ve chai.
const LOCATIONS := {
	"ben_xe_6": {"name": "Bến xe số 6", "desc": "Xe đưa đón công nhân đi kho khu công nghiệp. Trung tâm nghề của Linh cũng đi xe ở đây.", "x": -66.0, "size": Vector3(6, 3, 2.8), "color": "3c7d6b"},
	"cho_cau_nho": {"name": "Chợ Cầu Nhỏ", "desc": "Sạp vật tư, hàng đồ cũ, tiệm photo, sạp ve chai của cô Út và quán trà đá có bảng tin cho thuê phòng.", "x": -42.0, "size": Vector3(13, 7, 4.5),
		"tube": {"floors": 2, "sign": "CHỢ CẦU NHỎ", "units": 2}, "color": "c8503f", "stalls": true, "scrap": true,
		"npcs": [{"name": "Cô Út ve chai", "id": "", "color": "6b4f3a"}]},
	"com_hanh": {"name": "Cơm Hạnh", "desc": "Quán cơm phần cho người làm ca. Nhận ca phụ, giao cơm, nghe chuyện dãy quán cần sửa điện.", "x": -22.0, "size": Vector3(8, 7, 4.2),
		"tube": {"floors": 3, "sign": "CƠM HẠNH"}, "color": "e39a66",
		"npcs": [{"name": "Chị Hạnh", "id": "HANH", "color": "c0603a"}, {"name": "Minh", "id": "MINH", "color": "2f5f8a"}]},
	"tiem_sau": {"name": "Tiệm Sáu Sửa", "desc": "Tiệm sửa xe có thêm một bàn sửa đồ gia dụng.", "x": -9.0, "size": Vector3(8, 7, 4.5),
		"tube": {"floors": 3, "sign": "SÁU SỬA XE · ĐỒ ĐIỆN"}, "color": "6f8fa8",
		"npcs": [{"name": "Chú Sáu", "id": "SAU", "color": "3f5f7a"}]},
	"xom_bo_me": {"name": "Xóm trọ Bờ Me", "desc": "Tám phòng quanh khoảng sân, vòi nước chung, dây phơi dưới mái tôn. Về đây để nghỉ và đi ngủ.", "x": 10.0, "size": Vector3(15, 8, 9),
		"tube": {"floors": 3, "sign": "XÓM TRỌ BỜ ME", "units": 3}, "color": "eadcae", "line": true,
		"npcs": [{"name": "Bà Tư", "id": "BA_TU", "color": "8a6f9a"}, {"name": "Linh", "id": "LINH", "color": "d9776b"}, {"name": "Cô Duyên", "id": "DUYEN", "color": "b5577a"}]},
	# Ba chỗ ở mới: Hẻm Dừa gần chợ và gần việc, Cầu Tre ở cuối phố (đi xa hơn), nhà dì Năm ở đầu phố.
	"hem_dua": {"name": "Phòng Hẻm Dừa", "desc": "Hẻm nhỏ rẽ ra từ phố chính, gần chợ. Phòng nhỏ, cửa sát mặt hẻm, ít chỗ phơi.", "x": -30.5, "size": Vector3(5, 7, 5),
		"tube": {"floors": 3, "sign": "HẺM DỪA · CHO THUÊ PHÒNG", "shop": false}, "color": "d8c39a", "home": "hem_dua",
		"npcs": [{"name": "Cô chủ phòng", "id": "", "color": "9a6a8a"}]},
	"cau_tre": {"name": "Phòng Cầu Tre", "desc": "Cuối phố, qua khỏi Bến Cạn. Phòng thoáng, có hiên rộng; đi làm xa hơn.", "x": 63.0, "size": Vector3(8, 6, 6),
		"tube": {"floors": 2, "sign": "PHÒNG TRỌ CẦU TRE", "shop": false}, "color": "a9c4a0", "home": "cau_tre",
		"npcs": [{"name": "Chú chủ nhà", "id": "", "color": "5a6a7a"}]},
	"nha_di_nam": {"name": "Nhà dì Năm", "desc": "Nhà dì Năm ở đầu phố. Ở tạm được bảy ngày, phải gửi bớt đồ.", "x": -80.0, "size": Vector3(7, 6, 5),
		"tube": {"floors": 2, "sign": "", "shop": false}, "color": "e0b08a", "home": "di_nam",
		"npcs": [{"name": "Dì Năm", "id": "", "color": "7a5a4a"}]},
	"ben_can": {"name": "Dãy quán Bến Cạn", "desc": "Năm quán chung lối đi và hạ tầng cũ bên rạch. Hợp đồng của anh Phúc.", "x": 40.0, "size": Vector3(22, 6, 4.0),
		"tube": {"floors": 2, "sign": "DÃY QUÁN BẾN CẠN", "units": 5}, "color": "9c9a93",
		"npcs": [{"name": "Anh Phúc", "id": "PHUC", "color": "c9853a"}, {"name": "Trâm", "id": "TRAM", "color": "2f6f6a"}]},
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
	_build_canal()
	_build_bins()
	_build_grime()
	_build_clutter()
	_build_traffic()
	player = _character("player", Color("3d6fa8"), Color("2c2f3a"))
	player_body = player.get_child(0)
	add_child(player)
	# Vòng vàng dưới chân để luôn nhận ra An giữa đám đông.
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
	player.add_child(_label3d("An", Vector3(0, 2.15, 0), 22))
	player.position = door_of(HOME) + Vector3(-1.5, 0, 0.8)
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
	# Phản chiếu lấy từ ảnh HDRI phố lúc chiều; vùng bóng được hắt sáng màu vàng nâu ấm như Nobody.
	var sky := Surfaces.sky()
	if sky:
		env.sky = sky
		env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.15
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.82
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
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)


func _build_street() -> void:
	# Mặt đường, vỉa hè, vạch kẻ và phần đất trống phía sau (nền sẽ thay bằng texture gạch sau).
	# Nhựa đường, vỉa hè lát gạch: texture tả thực Poly Haven (thiếu file thì màu trơn).
	var asphalt := Surfaces.get_mat("duong", 4.0, Color("9a9a9a"))
	var paving := Surfaces.get_mat("via_he", 1.85, Color("efe2cc"))
	_block(Vector3(200, 0.1, 60), Vector3(-7, -0.1, 0), Color("4a4b4e")).material_override = asphalt
	_block(Vector3(176, 0.05, 6), Vector3(-7, 0, 0), Color("3d3e41")).material_override = asphalt
	_block(Vector3(176, 0.16, 2.2), Vector3(-7, 0, -4.1), Color("8a8780")).material_override = paving
	_block(Vector3(176, 0.16, 2.2), Vector3(-7, 0, 4.1), Color("8a8780")).material_override = paving
	_block(Vector3(6, 0.06, 26), Vector3(-64, 0, -18), Color("3d3e41")).material_override = asphalt
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
		if loc.get("stalls", false):
			_build_stalls(x, holder)
		if loc.get("line", false):
			_build_clothesline(x, holder)
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

	var slot := 0
	for who in loc.get("npcs", []):
		var npc := _character("npc." + str(who.id), Color(who.color), Color("3a3a40"))
		npc.position = door_of(id) + Vector3(1.6 + slot * 1.7, 0, 0.2 + (slot % 2) * 0.45)
		npc.rotation.y = PI
		holder.add_child(npc)
		npc.add_child(_label3d(who.name, Vector3(0, 2.0 + (slot % 2) * 0.3, 0), 22))
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
		if poles.size() % 2 == 0:
			_prop("utility_box", Vector3(px, 1.1, -3.05))
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
		# Tán lá gồm nhiều chùm xanh đậm nhạt khác nhau cho đỡ giống quả bóng.
		for k in 7:
			var crown := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = tree_rng.randf_range(0.45, 0.75)
			sm.height = sm.radius * 1.6
			sm.radial_segments = 10
			sm.rings = 6
			crown.mesh = sm
			crown.material_override = _mat(Color("3d5531").lerp(Color("5f7a3f"), tree_rng.randf()))
			crown.position = Vector3(tx + tree_rng.randf_range(-0.8, 0.8), 2.7 + tree_rng.randf_range(0.0, 0.9), 6.6 + tree_rng.randf_range(-0.7, 0.7))
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
		if not _prop("lamp", Vector3(lx, 0.16, 4.7), PI):
			_block(Vector3(0.14, 5.2, 0.14), Vector3(lx, 0, 4.7), Color("4b4d52"))
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(lx, 5.0, 3.8)
		lamp.omni_range = 9.0
		lamp.light_color = Color("ffcf8a")
		lamp.light_energy = 0.0
		add_child(lamp)
		lamps.append(lamp)
		lx += 12.0


## Sạp chợ trên vỉa hè: bàn gỗ, bạt xanh, thùng nhựa và giỏ hàng; ghế đẩu của quán trà đá ở góc.
func _build_stalls(x: float, holder: Node3D) -> void:
	var wood := Surfaces.get_mat("tuong_cu", 1.5, Color("9a7a58"))
	for sx in [-4.2, 3.6]:
		_block(Vector3(2.6, 0.8, 1.2), Vector3(x + sx, 0.16, -3.75), Color("8a6a4a"), holder).material_override = wood
		var tarp := _block(Vector3(3.0, 0.05, 1.9), Vector3(x + sx, 2.35, -3.75), Color("2f6fb0"), holder)
		tarp.rotation.x = -0.12
		for px in [-1.3, 1.3]:
			_block(Vector3(0.06, 2.2, 0.06), Vector3(x + sx + px, 0.16, -2.95), Color("6b6a66"), holder)
		_prop("basket", Vector3(x + sx - 0.6, 0.96, -3.75), randf() * TAU, holder)
		_prop("crate", Vector3(x + sx + 0.7, 0.96, -3.7), randf() * TAU, holder)
	for sx in [5.4, 6.2]:
		if not _prop("stool", Vector3(x + sx, 0.16, -3.3), randf() * TAU, holder):
			_block(Vector3(0.35, 0.4, 0.35), Vector3(x + sx, 0.16, -3.3), Color("2f6fb0"), holder)


## Dây phơi đồ trước xóm trọ, áo quần nhiều màu.
func _build_clothesline(x: float, holder: Node3D) -> void:
	for wx in [-5.5, -2.5]:
		_block(Vector3(0.07, 2.3, 0.07), Vector3(x + wx, 0.16, -3.2), Color("6b6a66"), holder)
	_block(Vector3(3.0, 0.02, 0.02), Vector3(x - 4.0, 2.35, -3.2), Color("3a3a3a"), holder)
	var shirt_colors := ["e6e2d3", "6f8fb5", "c46a5a", "d9a35b"]
	for i in 4:
		var c := _block(Vector3(0.5, 0.62, 0.03), Vector3(x - 5.1 + i * 0.72, 1.7, -3.2), Color(shirt_colors[i]), holder)
		c.rotation.z = randf_range(-0.05, 0.05)


## Con rạch chạy dọc phía nam sau hàng cây và cây cầu nhỏ trước chợ Cầu Nhỏ: chi tiết nhận diện phường An Hòa.
func _build_canal() -> void:
	var water := _block(Vector3(180, 0.04, 6.0), Vector3(-7, 0.005, 11.6), Color("3f5a52"))
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.22, 0.32, 0.28)
	wm.roughness = 0.08
	wm.metallic = 0.35
	water.material_override = wm
	var stone := Surfaces.get_mat("tuong_cu", 2.0, Color("8a8478"))
	_block(Vector3(180, 0.3, 0.6), Vector3(-7, 0.0, 8.3), Color("6e6a62")).material_override = stone
	_block(Vector3(180, 0.3, 0.6), Vector3(-7, 0.0, 14.9), Color("6e6a62")).material_override = stone
	var bx := float(LOCATIONS.cho_cau_nho.x) + 3.0
	_block(Vector3(3.0, 0.22, 8.0), Vector3(bx, 0.3, 11.6), Color("8a7f72")).material_override = stone
	for side in [-1.45, 1.45]:
		_block(Vector3(0.12, 0.8, 8.0), Vector3(bx + side, 0.52, 11.6), Color("5e5a55"))


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
	_update_quests()
	if _rain != null and _rain.visible:
		_rain.position = player.position + Vector3(0, 11, 2)
	_check_day_end()


# ---------------------------------------------------------------- ve chai, phong độ

## Phong độ thấp thì lê bước, đi chậm hẳn.
func _speed() -> float:
	var v := SPEED
	if game.has_needs() and game.phong_do() < float(game.cfg.needs.slowBelow):
		v *= 0.7
	# Đang khiêng đồ của việc nhờ (xe đạp, cơm suất, con mèo) thì đi chậm hơn một chút.
	for id in game.quests_active():
		var step: Dictionary = game.quest_step(id)
		if step.get("carry", false):
			var holding := true
			for k in step.get("need_items", {}):
				holding = holding and game.item_count(k) > 0
			if holding:
				v *= 0.8
				break
	return v


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
	var x := INF
	for b in bins:
		if b.id == id:
			x = float(b.pos.x)
	var got: Dictionary = game.scavenge(id, x)
	if got.has("_quest"):
		_float_text(str(got._quest), Color("9fc4ff"))
		audio.play("done")
		got.erase("_quest")
	var parts := []
	for k in got:
		if int(got[k]) > 0:
			parts.append("+%d %s" % [int(got[k]), game.cfg.scrap[k].name])
	_float_text(", ".join(parts) if not parts.is_empty() else "Trống trơn", Color("c8e6a0") if not parts.is_empty() else Color("bbbbbb"))
	audio.play("step", 0.6)


var _prop_rng := RandomNumberGenerator.new()


## Đặt một món đồ trên phố theo models.json (props.<key>). false nếu chưa có file mô hình.
func _prop(key: String, pos: Vector3, rot_y := 0.0, parent: Node = null) -> bool:
	var m := models.spawn("props." + key, _prop_rng)
	if m == null:
		return false
	m.position = pos
	m.rotation.y = rot_y
	(parent if parent != null else self).add_child(m)
	return true


## Đồ đạc bày trước nhà: thùng nhựa chồng lên nhau, thùng các-tông, chậu cây, giỏ mây; bao xi măng ở công trình.
func _build_clutter() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	_prop_rng.seed = 405
	var xs := []
	for h in homes:
		xs.append(float(h.x))
	for id in LOCATIONS:
		if LOCATIONS[id].has("tube"):
			xs.append(float(LOCATIONS[id].x) - 2.5)
			xs.append(float(LOCATIONS[id].x) + 2.5)
	for x in xs:
		for k in rng.randi_range(1, 3):
			var key: String = ["crate", "crate", "box", "plant", "basket", "plant"][rng.randi() % 6]
			var pos := Vector3(x + rng.randf_range(-1.8, 1.8), 0.16, rng.randf_range(-4.75, -4.35))
			if door_of_near(pos):
				continue
			_prop(key, pos, rng.randf_range(-0.4, 0.4) + (PI if rng.randf() < 0.5 else 0.0))
			if key == "crate" and rng.randf() < 0.5:
				_prop("crate", pos + Vector3(0, 0.3, 0), rng.randf_range(-0.2, 0.2))
	# Vật tư chất trước dãy Bến Cạn: bao xi măng, thùng các-tông đựng dây điện.
	var cx: float = LOCATIONS.ben_can.x
	for layer in 2:
		for j in 3 - layer:
			_prop("cement_bag", Vector3(cx + 7.0 + j * 0.8 + layer * 0.4, 0.16 + layer * 0.22, -4.4), rng.randf_range(-0.1, 0.1))


## Không bày đồ chắn ngay trước cửa tiệm (vòng sáng tương tác).
func door_of_near(pos: Vector3) -> bool:
	for id in LOCATIONS:
		if absf(door_of(id).x - pos.x) < 1.3:
			return true
	return false


## Vết bẩn, nước đọng, giấy rác vương vãi và nắp cống: phố Sài Gòn không bao giờ sạch bong.
func _build_grime() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var stain_tex := GradientTexture2D.new()
	stain_tex.fill = GradientTexture2D.FILL_RADIAL
	stain_tex.fill_from = Vector2(0.5, 0.5)
	stain_tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	stain_tex.gradient = g
	for i in 40:
		var mi := MeshInstance3D.new()
		var qm := QuadMesh.new()
		var s := rng.randf_range(0.8, 2.8)
		qm.size = Vector2(s, s * rng.randf_range(0.5, 1.0))
		mi.mesh = qm
		var m := StandardMaterial3D.new()
		m.albedo_texture = stain_tex
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		var wet := rng.randf() < 0.4
		m.albedo_color = Color(0.12, 0.1, 0.08, 0.45) if wet else Color(0.25, 0.2, 0.14, 0.35)
		m.roughness = 0.15 if wet else 0.9
		m.metallic_specular = 0.8 if wet else 0.5
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var side: float = [-4.1, 4.1, rng.randf_range(-2.5, 2.5)][rng.randi() % 3]
		mi.position = Vector3(rng.randf_range(STREET_X.x, STREET_X.y), 0.17 if absf(side) > 3.0 else 0.06, side)
		mi.rotation = Vector3(-PI / 2.0, 0, 0)
		mi.rotation.y = rng.randf() * TAU
		add_child(mi)
	var paper := StandardMaterial3D.new()
	paper.albedo_color = Color("e9e2d0")
	paper.roughness = 0.95
	for i in 70:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(rng.randf_range(0.15, 0.32), 0.008, rng.randf_range(0.2, 0.35))
		mi.mesh = bm
		mi.material_override = paper
		mi.position = Vector3(rng.randf_range(STREET_X.x, STREET_X.y), 0.17, rng.randf_range(-4.9, -3.2) if rng.randf() < 0.6 else rng.randf_range(3.2, 4.9))
		mi.rotation = Vector3(rng.randf_range(-0.1, 0.1), rng.randf() * TAU, rng.randf_range(-0.15, 0.15))
		add_child(mi)
	var lid := Surfaces.get_mat("kim_loai", 0.9, Color("6b6660"))
	for i in 8:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.42
		cm.bottom_radius = 0.42
		cm.height = 0.04
		mi.mesh = cm
		mi.material_override = lid
		mi.position = Vector3(-80.0 + i * 20.0 + rng.randf_range(-4, 4), 0.05 if i % 2 == 0 else 0.17, rng.randf_range(-1.5, 1.5) if i % 2 == 0 else -3.9)
		add_child(mi)


func _build_bins() -> void:
	var x := -86.0
	var i := 0
	while x < 74.0:
		var pos := Vector3(x, 0, -3.0 if i % 2 == 0 else 3.4)
		var holder := Node3D.new()
		holder.position = pos
		add_child(holder)
		if _prop("trash_can", Vector3(0, 0.16, 0), randf() * TAU, holder):
			if i % 3 != 1:
				_prop("trashbag", Vector3(0.75, 0.16, 0.15), randf() * TAU, holder)
		else:
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
		if id != shop:
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
		if _ending_home != null:
			_ending_home.queue_free()
			_ending_home = null
		return
	if game.is_over() and str(game.s.over.get("kind", "")) == "full" and _ending_home == null:
		_show_ending_home()
	var money := int(game.s.cash)
	if _last_money >= 0 and money != _last_money:
		_float_text(GameLogic.fmt_money(money - _last_money) if money < _last_money else "+" + GameLogic.fmt_money(money - _last_money),
			Color("7fe0a0") if money > _last_money else Color("ff8a7a"))
		audio.play("earn" if money > _last_money else "spend")
	_last_money = money
	# Sang ngày mới: An thức dậy trước cửa xóm trọ.
	if game.day() != _last_day:
		if _last_day != -1:
			player.position = door_of(HOME) + Vector3(-1.5, 0, 0.8)
			camera.position = player.position + cam_offset()
			_target = null
			_target_loc = ""
			_walk_meters = 0.0
		_last_day = game.day()
	_update_lighting(game.clock())


## Ánh sáng theo giờ trong game: sáng vàng nhạt, trưa gắt, chiều cam, tối đèn đường.
func _update_lighting(hour: float) -> void:
	var t := clampf((hour - 6.0) / 16.0, 0.0, 1.0)
	var elevation := lerpf(24.0, 60.0, sin(t * PI))
	# Nắng chiếu từ phía sau dãy nhà ra đường: bóng nhà đổ dài trên vỉa hè như Nobody.
	sun.rotation_degrees = Vector3(-elevation, 115.0 + t * 130.0, 0)
	var warm := Color("ffd9a8")
	var noon := Color("fff0dc")
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
	# Ngày mưa (15, 29): trời xám, nắng yếu, đèn đường bật sớm, có mưa rơi quanh An.
	var rain: bool = game.is_started() and bool(game.s.today.get("rain", false))
	if rain:
		c = c.lerp(Color("8a96a8"), 0.7)
	sun.light_color = c
	sun.light_energy = (0.35 if hour >= 20.0 else 1.1) * (0.35 if rain else 1.0)
	env.ambient_light_color = c.lerp(Color("b49a7c"), 0.2 if rain else 0.6)
	env.ambient_light_energy = 0.45 if hour >= 20.0 else (0.75 if rain else 0.95)
	for lamp in lamps:
		lamp.light_energy = 2.2 if hour >= (16.0 if rain else 18.0) else 0.0
	_set_rain(rain)


var _rain: CPUParticles3D


func _set_rain(on: bool) -> void:
	if on and _rain == null:
		_rain = CPUParticles3D.new()
		_rain.amount = 1400
		_rain.lifetime = 0.9
		_rain.local_coords = false
		_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		_rain.emission_box_extents = Vector3(18, 0.5, 13)
		_rain.direction = Vector3(0.08, -1, 0)
		_rain.spread = 3.0
		_rain.initial_velocity_min = 16.0
		_rain.initial_velocity_max = 20.0
		_rain.gravity = Vector3(0, -9.8, 0)
		var drop := BoxMesh.new()
		drop.size = Vector3(0.018, 0.55, 0.018)
		var dm := StandardMaterial3D.new()
		dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dm.albedo_color = Color(0.82, 0.88, 0.95, 0.45)
		drop.material = dm
		_rain.mesh = drop
		add_child(_rain)
	if _rain != null:
		_rain.emitting = on
		_rain.visible = on


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
## Không có file mô hình thì dựng nhân vật có khớp (character.gd): An và nhân vật phụ có ngoại hình riêng,
## người đi đường ngẫu nhiên.
func _character(key: String, shirt: Color, pants: Color, rng: RandomNumberGenerator = null, hat := "") -> Node3D:
	var m := models.spawn(key, rng)
	if m == null:
		var id := "AN" if key == "player" else key.trim_prefix("npc.")
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


# ---------------------------------------------------------------- ngày 30

## Hình ảnh khép lại: An đứng trước chỗ ở mới, bà Tư bên cạnh (Linh có mặt nếu không đi thực tập xa),
## chậu húng đặt dưới mái hiên. Hộp thoại kết thúc hiện đè lên cảnh này.
var _ending_home: Node3D


func _show_ending_home() -> void:
	var place := str(game.housing().place)
	var loc := str(game.cfg.housing.get(place, {}).get("loc", HOME))
	if not LOCATIONS.has(loc):
		loc = HOME
	var door := door_of(loc)
	_ending_home = Node3D.new()
	add_child(_ending_home)
	var family := ["BA_TU"]
	if str(game.s.linh.decision) != "xa":
		family.append("LINH")
	var i := 0
	for id in family:
		var who := _character("npc." + id, Color("8a6f9a"), Color("3a3a40"))
		who.position = door + Vector3(0.9 + i * 1.0, 0, 0.7)
		who.rotation.y = PI * 0.15
		_ending_home.add_child(who)
		who.add_child(_label3d(game.rep_name(id), Vector3(0, 1.9, 0), 20))
		i += 1
	if not _prop("plant", door + Vector3(-1.8, 0.16, -0.3), 0.0, _ending_home):
		_block(Vector3(0.35, 0.35, 0.35), door + Vector3(-1.8, 0.16, -0.3), Color("5f7a3f"), _ending_home)
	_ending_home.add_child(_label3d("Chậu húng của bà", door + Vector3(-1.8, 0.95, -0.3), 18))
	player.position = door + Vector3(-0.2, 0, 1.0)
	player.rotation.y = 0.0
	zoom = 0.15
	camera.position = player.position + cam_offset()
	_target = null
	_target_loc = ""


# ---------------------------------------------------------------- việc nhờ

## Dấu ! vàng trên chỗ có người nhờ việc, dấu ◆ xanh trên chỗ cần tới của việc đang làm,
## dấu ◆ vàng trên chỗ có cảnh chính hôm nay.
var _quest_offer_marks := {}
var _quest_marks: Array = []
var _quest_tick := 0.0


func _update_quests() -> void:
	if not game.is_started():
		return
	var bob := 0.18 * sin(Time.get_ticks_msec() / 260.0)
	_quest_tick -= get_physics_process_delta_time()
	if _quest_tick <= 0.0:
		_quest_tick = 0.3
		_refresh_quest_marks()
	for id in _quest_offer_marks:
		var m: Label3D = _quest_offer_marks[id]
		m.position.y = float(m.get_meta("y")) + bob
	for m in _quest_marks:
		m.position.y = float(m.get_meta("y")) + bob
		m.rotation.y += 0.03
	# Bước "auto": tới nơi là xong (giao cơm tới công trình).
	if hud.blocking():
		return
	for id in game.quests_active():
		var step: Dictionary = game.quest_step(id)
		if step.get("kind", "") == "visit" and step.get("auto", false) and game.quest_step_lock(id) == "" and game.quest_step_wait(id) <= 0.0 \
				and door_of(str(step.loc)).distance_to(Vector3(player.position.x, 0, player.position.z)) <= INTERACT_RANGE:
			game.quest_visit(id)
			audio.play("done")


func _refresh_quest_marks() -> void:
	var offers := {}
	for q in game.quest_offers():
		offers[str(q.giver)] = true
	for loc in offers:
		if not _quest_offer_marks.has(loc):
			var l := _label3d("!", Vector3.ZERO, 120)
			l.modulate = Color("f2c14e")
			l.outline_modulate = Color("3a2a00")
			l.position = door_of(loc) + Vector3(1.6 if LOCATIONS[loc].has("npcs") else 0.0, 0, 0.2)
			l.set_meta("y", 3.0)
			add_child(l)
			_quest_offer_marks[loc] = l
	for loc in _quest_offer_marks.keys():
		if not offers.has(loc):
			_quest_offer_marks[loc].queue_free()
			_quest_offer_marks.erase(loc)
	var spots := []
	var colors := []
	for id in game.scenes_today():
		var loc := str(game.scene_info(id).loc)
		if LOCATIONS.has(loc):
			spots.append(door_of(loc))
			colors.append(Color("f2c14e"))
	for id in game.quests_active():
		var t: Dictionary = game.quest_target(id)
		if t.has("loc") and LOCATIONS.has(t.loc):
			spots.append(door_of(str(t.loc)))
			colors.append(Color("5aa9ff"))
		elif t.has("x"):
			for b in bins:
				if float(b.pos.x) >= float(t.x[0]) and float(b.pos.x) <= float(t.x[1]) and game.scrap_lock(b.id) == "":
					spots.append(Vector3(b.pos.x, 0, b.pos.z))
					colors.append(Color("5aa9ff"))
	while _quest_marks.size() < spots.size():
		var m := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.38
		cm.bottom_radius = 0.0
		cm.height = 0.75
		cm.radial_segments = 4
		m.mesh = cm
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color("5aa9ff")
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(m)
		_quest_marks.append(m)
	for i in _quest_marks.size():
		var m: MeshInstance3D = _quest_marks[i]
		m.visible = i < spots.size()
		if m.visible:
			var p: Vector3 = spots[i]
			(m.material_override as StandardMaterial3D).albedo_color = colors[i]
			# Hai dấu cùng một cửa thì đặt lệch nhau cho khỏi chồng.
			var dup := 0
			for j in i:
				if spots[j] == p:
					dup += 1
			m.position = Vector3(p.x + dup * 0.9, m.position.y, p.z)
			m.set_meta("y", 2.2 if absf(p.z - DOOR_Z) > 0.5 else 4.2)
