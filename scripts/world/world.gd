extends Node3D
## Màn phố 3D kiểu Nobody: phường An Hòa nhìn chéo từ trên xuống, dựng theo bản đồ data/map.json
## (đường An Hòa, đường Chợ, đường Bờ Me ven rạch, các hẻm, Cầu Nhỏ, Cầu Tre, dãy nhà bờ nam).
## Bấm chuột để đi: An tự tìm đường theo phố. Bấm vào cửa tiệm hoặc người đứng trước cửa để mở việc ở đó
## (phím E khi đứng gần). Nhà nào nằm giữa camera và An thì tạm ẩn đi cho khỏi che.
## Nhà cửa, người, xe lấy mô hình thật theo data/models.json; thiếu file thì dựng khối hình tạm.

const GameLogic := preload("res://scripts/game_logic.gd")
const Hud := preload("res://scripts/world/hud.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")
const Models := preload("res://scripts/world/models.gd")
const Character := preload("res://scripts/world/character.gd")
const Surfaces := preload("res://scripts/world/surfaces.gd")
const Audio := preload("res://scripts/world/audio.gd")
const TubeHouse := preload("res://scripts/world/tube_house.gd")
const CityMap := preload("res://scripts/world/city_map.gd")
const RainLayer := preload("res://scripts/world/rain_layer.gd")
const StreetLife := preload("res://scripts/world/street_life.gd")

## Xóm trọ của An: nơi xuất phát mỗi sáng và nơi đi ngủ mỗi tối.
const HOME := "xom_bo_me"
## Để HUD đọc được id nhà mà không cần truy cập hằng số qua instance.
var home: String = HOME
## Địa điểm của truyện. Vị trí, bề ngang, chiều sâu nằm ở data/map.json (locations).
## npcs: người đứng trước cửa (bấm vào cũng mở địa điểm), id là khóa trong story.reps và data/talks.json.
## tube: dựng thành nhà ống (floors tầng, sign chữ biển hiệu, units số căn liền nhau, shop tầng trệt buôn bán).
## shelter: mái che trạm xe. stalls: sạp chợ, ghế trà đá · line: dây phơi đồ trước cửa · scrap: chỗ bán ve chai.
const LOCATIONS := {
	"ben_xe_6": {"name": "Bến xe số 6", "desc": "Trạm xe đưa rước công nhân ở đầu đường An Hòa, sát cổng khu công nghiệp. Trung tâm nghề của Linh cũng đi xe ở đây.", "color": "3c7d6b", "shelter": true, "h": 3.0},
	"cho_cau_nho": {"name": "Chợ Cầu Nhỏ", "desc": "Chợ ở đầu Cầu Nhỏ: sạp vật tư, hàng đồ cũ, tiệm photo, sạp ve chai của cô Út và quán trà đá có bảng tin cho thuê phòng.",
		"tube": {"floors": 2, "sign": "CHỢ CẦU NHỎ", "units": 3}, "color": "c8503f", "stalls": true, "scrap": true,
		"npcs": [{"name": "Cô Út ve chai", "id": "", "color": "6b4f3a"}]},
	"com_hanh": {"name": "Cơm Hạnh", "desc": "Quán cơm phần cho người làm ca trên đường An Hòa. Nhận ca phụ, giao cơm, nghe chuyện dãy quán cần sửa điện.",
		"tube": {"floors": 3, "sign": "CƠM HẠNH"}, "color": "e39a66",
		"npcs": [{"name": "Chị Hạnh", "id": "HANH", "color": "c0603a"}, {"name": "Minh", "id": "MINH", "color": "2f5f8a"}]},
	"tiem_sau": {"name": "Tiệm Sáu Sửa", "desc": "Tiệm sửa xe trên đường An Hòa, gần đầu Hẻm 42, có thêm một bàn sửa đồ gia dụng.",
		"tube": {"floors": 3, "sign": "SÁU SỬA XE · ĐỒ ĐIỆN"}, "color": "6f8fa8",
		"npcs": [{"name": "Chú Sáu", "id": "SAU", "color": "3f5f7a"}]},
	"xom_bo_me": {"name": "Xóm trọ Bờ Me", "desc": "Tám phòng quanh khoảng sân nhìn ra rạch, vòi nước chung, dây phơi dưới mái tôn. Về đây để nghỉ và đi ngủ.",
		"tube": {"floors": 3, "sign": "XÓM TRỌ BỜ ME", "units": 3}, "color": "eadcae", "line": true,
		"npcs": [{"name": "Bà Tư", "id": "BA_TU", "color": "8a6f9a"}, {"name": "Linh", "id": "LINH", "color": "d9776b"}, {"name": "Cô Duyên", "id": "DUYEN", "color": "b5577a"}]},
	# Ba chỗ ở mới: Hẻm Dừa gần chợ và gần việc, Cầu Tre bên kia rạch (đi xa hơn), nhà dì Năm ở đầu đường.
	"hem_dua": {"name": "Phòng Hẻm Dừa", "desc": "Hẻm cụt rẽ ra từ đường Chợ, đầu hẻm có cây dừa. Phòng nhỏ, cửa sát mặt hẻm, ít chỗ phơi.",
		"tube": {"floors": 3, "sign": "PHÒNG CHO THUÊ", "shop": false}, "color": "d8c39a", "home": "hem_dua",
		"npcs": [{"name": "Cô chủ phòng", "id": "", "color": "9a6a8a"}]},
	"cau_tre": {"name": "Phòng Cầu Tre", "desc": "Bên kia rạch, qua Cầu Tre. Dãy nhà lưng quay ra kênh; phòng thoáng, có hiên rộng, đi làm xa hơn.",
		"tube": {"floors": 2, "sign": "PHÒNG TRỌ CẦU TRE", "shop": false}, "color": "a9c4a0", "home": "cau_tre",
		"npcs": [{"name": "Chú chủ nhà", "id": "", "color": "5a6a7a"}]},
	"nha_di_nam": {"name": "Nhà dì Năm", "desc": "Nhà dì Năm ở đầu đường An Hòa, gần trạm xe. Ở tạm được bảy ngày, phải gửi bớt đồ.",
		"tube": {"floors": 2, "sign": "", "shop": false}, "color": "e0b08a", "home": "di_nam",
		"npcs": [{"name": "Dì Năm", "id": "", "color": "7a5a4a"}]},
	"ben_can": {"name": "Dãy quán Bến Cạn", "desc": "Năm quán ven rạch cuối đường Bờ Me, chung lối đi và hạ tầng điện cũ. Hợp đồng của anh Phúc.",
		"tube": {"floors": 2, "sign": "DÃY QUÁN BẾN CẠN", "units": 5}, "color": "9c9a93",
		"npcs": [{"name": "Anh Phúc", "id": "PHUC", "color": "c9853a"}, {"name": "Trâm", "id": "TRAM", "color": "2f6f6a"}]},
}
## Cửa của địa điểm: trên vỉa hè, cách mặt tiền chừng này mét.
const DOOR_OUT := 0.9
const SPEED := 6.0
## Camera xa nhất (nhìn toàn phố) và gần nhất (thấy rõ nhân vật); con lăn chuột chỉnh giữa hai mức.
const CAM_OFFSET := Vector3(0, 24, 17)
const CAM_NEAR := Vector3(0, 6.5, 9.0)
const INTERACT_RANGE := 2.4
## Bảng tên tiệm không cao hơn mức này để không lọt lên mép trên màn hình dưới bảng mục tiêu.
const SIGN_MAX := 4.6
## Nhà phía trước lệch sang hai bên trong khoảng này cũng ẩn theo, cho thấy cả người đứng cạnh An.
const CUT_MARGIN := 3.0
const FILLER_SIGNS := ["SỬA XE", "TẠP HÓA", "PHỞ", "CẮT TÓC", "BÁNH MÌ", "PHOTOCOPY", "NHÀ THUỐC", "SIM THẺ", "GỘI ĐẦU", "BÚN BÒ", "ĐIỆN THOẠI", "VẢI SỢI", "CƠM TẤM", "CÀ PHÊ", "HỦ TIẾU", "GẠO"]
const HEM_SIGNS := ["TẠP HÓA", "CẮT TÓC", "CHÈ", "NƯỚC MÍA", "BÁNH CUỐN", "SỬA ĐIỆN THOẠI", "GIẶT ỦI", "BÁNH MÌ"]

var city: CityMap
var game
var hud
var models := Models.new()
var tubes
## Nhà dân có số (địa chỉ giao hàng): {"pos": Vector3 cửa, "no", "name"}.
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
## Khối nhà có thể che An: {"node", "rect": Rect2 nền nhà, "h": chiều cao}.
var occluders: Array = []
## Nhân vật có tên: id -> {node, body, name, loc}; street_life cho họ đi lại theo giờ.
var npc_nodes := {}
var life: Node

## Đích cuối của lượt đi bộ đang chạy (null khi đứng yên) và các điểm rẽ trên đường đi.
var _target = null
var _path := PackedVector2Array()
var _path_i := 0
var _target_loc := ""
var _pending_click = null
var _last_money := -1
var _last_day := -1
var _walk_t := 0.0
## Quãng đường đã đi nhưng chưa quy ra giờ; cộng dồn rồi trừ giờ theo từng nấc 5 phút.
var _walk_meters := 0.0
var _night_prompt_day := -1
var _mat_cache := {}


func _ready() -> void:
	game = GameState.game
	font = UI.text_font()
	city = CityMap.new()
	_build_environment()
	tubes = TubeHouse.new(0.0, font)
	_build_ground()
	_build_streets()
	_build_canal()
	_build_fields()
	for id in LOCATIONS:
		_build_location(id, LOCATIONS[id])
	_build_houses()
	_build_fillers()
	_build_props()
	_build_gates()
	_build_bins()
	_build_grime()
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
	marker.position = Vector3(0, 0.18, 0)
	player.add_child(marker)
	player.add_child(_label3d("An", Vector3(0, 2.15, 0), 22))
	player.position = loc_point(HOME, -1.5, 0.8)
	# Về từ màn khác thì hiện ra ở chỗ đó.
	var gs := get_node("/root/GameState")
	if gs.spawn_at != "" and LOCATIONS.has(gs.spawn_at):
		player.position = loc_point(gs.spawn_at, 1.5, 0.8)
		gs.spawn_at = ""
	camera = Camera3D.new()
	camera.fov = 34
	add_child(camera)
	camera.position = player.position + cam_offset()
	camera.look_at(player.position + Vector3(0, 1, 0), Vector3.UP)
	camera.current = true
	life = StreetLife.new()
	add_child(life)
	life.setup(self)

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
	# Dùng khi chụp màn hình kiểm tra: "-- --demo --demo-open=com_hanh" mở sẵn một địa điểm.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--demo-open="):
			var id := arg.substr(12)
			player.position = door_of(id)
			camera.position = player.position + cam_offset()
			hud.open_location.call_deferred(id)


# ---------------------------------------------------------------- toạ độ

static func _v3(p: Vector2, y := 0.0) -> Vector3:
	return Vector3(p.x, y, p.y)


## Điểm cục bộ của một lô nhà: along dọc mặt tiền (sang phải khi đứng ngoài đường nhìn vào nhà là âm),
## out từ mặt tiền ra đường. Trục +x cục bộ của nút đặt theo rot_y(normal) trùng với hướng này.
static func plot_point(p: Dictionary, along: float, out: float, y := 0.0) -> Vector3:
	var n: Vector2 = p.normal
	var t := Vector2(n.y, -n.x)
	return _v3((p.center as Vector2) + t * along + n * out, y)


func loc_point(id: String, along: float, out: float) -> Vector3:
	return plot_point(city.locs[id], along, DOOR_OUT + out)


## Nút đặt tại giữa mặt tiền của lô, quay cho mặt trước (trục +z cục bộ) nhìn ra đường.
func _frame_node(p: Dictionary, node_name := "") -> Node3D:
	var n := Node3D.new()
	if node_name != "":
		n.name = node_name
	n.position = _v3(p.center)
	n.rotation.y = CityMap.rot_y(p.normal)
	return n


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


## Mặt đất cả phường (để bấm chuột đi) và nền xi măng dưới các dãy nhà.
func _build_ground() -> void:
	var b: Rect2 = city.bounds.grow(30.0)
	var ground_mat := Surfaces.get_mat("tuong_cu", 6.0, Color("6d6a63"))
	_block(Vector3(b.size.x, 0.1, b.size.y), _v3(b.get_center(), -0.1), Color("5d5b56")).material_override = ground_mat
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	ground.add_child(shape)
	add_child(ground)


## Mặt đường theo từng loại: đường lớn trải nhựa có vỉa hè lát gạch và vạch kẻ, hẻm đổ bê tông có rãnh giữa,
## đường bờ kè có vỉa hè phía nhà và lan can phía rạch, cầu có mặt cầu, lan can và trụ.
func _build_streets() -> void:
	var asphalt := Surfaces.get_mat("duong", 4.0, Color("9a9a9a"))
	var paving := Surfaces.get_mat("via_he", 1.85, Color("efe2cc"))
	var concrete := Surfaces.get_mat("via_he", 3.5, Color("cfc8ba"))
	for id in city.order:
		var st: Dictionary = city.streets[id]
		var r: Rect2 = st.rect
		var horiz: bool = st.axis == "x"
		var kind := str(st.kind)
		match kind:
			"duong", "cho", "bo_ke":
				_block(Vector3(r.size.x, 0.05, r.size.y), _v3(r.get_center()), Color("3d3e41")).material_override = asphalt
				var road := float(st.get("road", r.size.y if horiz else r.size.x))
				var cross: float = r.size.y if horiz else r.size.x
				var walk := (cross - road) / 2.0
				var sides := [-1.0, 1.0]
				if kind == "bo_ke":
					# Bờ kè: vỉa hè chỉ ở phía nhà (bắc), phía rạch là lề đá và lan can.
					walk = cross - road
					sides = [-1.0]
				for sgn in sides:
					var off: float = sgn * (cross / 2.0 - walk / 2.0)
					var c := r.get_center() + (Vector2(0, off) if horiz else Vector2(off, 0))
					var sz := Vector3(r.size.x, 0.16, walk) if horiz else Vector3(walk, 0.16, r.size.y)
					_block(sz, _v3(c), Color("8a8780")).material_override = paving
				_lane_marks(st, kind == "duong" and horiz, walk / 2.0 if kind == "bo_ke" else 0.0)
			"hem", "hem_nho":
				_block(Vector3(r.size.x, 0.06, r.size.y), _v3(r.get_center()), Color("a8a296")).material_override = concrete
				# Rãnh thoát nước giữa hẻm, nắp gang từng khúc.
				var gutter := Vector3(r.size.x, 0.02, 0.22) if horiz else Vector3(0.22, 0.02, r.size.y)
				_block(gutter, _v3(r.get_center(), 0.06), Color("55524c"))
			"cau", "cau_nho":
				_build_bridge(st)


## Vạch kẻ: đường tim đứt khúc, vạch qua đường ở đầu đường Chợ.
func _lane_marks(st: Dictionary, main: bool, shift := 0.0) -> void:
	var r: Rect2 = st.rect
	var horiz: bool = st.axis == "x"
	var u: float = st.lo + 1.0
	while u < st.hi - 1.0:
		var p := Vector2(u, st.c + shift) if horiz else Vector2(st.c + shift, u)
		_block(Vector3(1.6, 0.07, 0.12) if horiz else Vector3(0.12, 0.07, 1.6), _v3(p), Color("d8d4c8"))
		u += 3.4
	if main and city.streets.has("duong_cho"):
		var x: float = city.streets.duong_cho.c
		var k := -3.0
		while k <= 3.0:
			_block(Vector3(0.45, 0.075, 4.6), Vector3(x + k, 0, r.get_center().y), Color("e8e4d8"))
			k += 0.9


func _build_bridge(st: Dictionary) -> void:
	var r: Rect2 = st.rect
	var stone := Surfaces.get_mat("tuong_cu", 2.0, Color("8a8478"))
	var deck := _block(Vector3(r.size.x, 0.22, r.size.y), _v3(r.get_center(), 0.0), Color("8a7f72"))
	deck.material_override = stone
	var rail_col := Color("4f5a63") if st.kind == "cau_nho" else Color("5e5a55")
	for sx in [r.position.x + 0.08, r.end.x - 0.08]:
		_block(Vector3(0.1, 0.06, r.size.y), Vector3(sx, 1.0, r.get_center().y), rail_col)
		var z := r.position.y
		while z <= r.end.y:
			_block(Vector3(0.08, 1.0, 0.08), Vector3(sx, 0.2, z), rail_col)
			z += 1.2
	# Trụ cầu dưới nước và tấm biển tên cầu.
	for z in [r.position.y + r.size.y * 0.33, r.position.y + r.size.y * 0.66]:
		_block(Vector3(r.size.x * 0.7, 0.6, 0.6), Vector3(r.get_center().x, -0.55, z), Color("6e6a62"))
	var plate := _label3d(str(st.display).to_upper(), Vector3(r.end.x + 0.3, 1.5, r.position.y + 1.0), 26)
	add_child(plate)


## Con rạch: dải nước uốn theo các điểm của đường rạch, lề đá hai bên, bờ cỏ phía đường Bờ Me
## và bùn dưới chân dãy nhà sàn bờ nam. Ghe xuồng neo dọc bờ.
func _build_canal() -> void:
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color("2c4a4c")
	wm.roughness = 0.18
	wm.metallic = 0.12
	var hw: float = city.canal_w / 2.0
	var north_edge: float = float(city.streets.bo_me.rect.end.y) if city.streets.has("bo_me") else 20.0
	var south_edge: float = float(city.streets.bo_nam.rect.position.y) if city.streets.has("bo_nam") else 44.0
	var water := SurfaceTool.new()
	water.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grass := SurfaceTool.new()
	grass.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mud := SurfaceTool.new()
	mud.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x0: float = city.bounds.position.x - 30.0
	var x := x0
	while x < city.bounds.end.x + 30.0:
		var x2 := x + 2.0
		var z1: float = city.canal_z(x)
		var z2: float = city.canal_z(x2)
		_quad(water, x, x2, z1 - hw, z2 - hw, z1 + hw, z2 + hw, 0.01)
		_quad(grass, x, x2, north_edge, north_edge, z1 - hw, z2 - hw, 0.03)
		_quad(mud, x, x2, z1 + hw, z2 + hw, south_edge, south_edge, 0.02)
		x = x2
	for pair in [[water, wm], [grass, _mat(Color("5f6e43"))], [mud, _mat(Color("5a4e3f"))]]:
		var st: SurfaceTool = pair[0]
		var m: StandardMaterial3D = pair[1]
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	# Lề đá kè dọc mép nước phía bắc, từng đoạn 4 m.
	var stone := Surfaces.get_mat("tuong_cu", 2.0, Color("8a8478"))
	x = city.bounds.position.x
	while x < city.bounds.end.x:
		var z: float = city.canal_z(x + 2.0) - hw
		var edge := _block(Vector3(4.1, 0.3, 0.5), Vector3(x + 2.0, 0.0, z), Color("6e6a62"))
		edge.material_override = stone
		edge.rotation.y = -atan2(city.canal_z(x + 4.0) - city.canal_z(x), 4.0)
		x += 4.0
	# Ghe xuồng neo dọc bờ.
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	for bx in [-80.0, -20.0, 34.0, 66.0]:
		var boat := Node3D.new()
		boat.position = Vector3(bx + rng.randf_range(-4, 4), 0.05, city.canal_z(bx) - hw + 1.6)
		boat.rotation.y = rng.randf_range(-0.12, 0.12)
		_block(Vector3(4.2, 0.45, 1.2), Vector3.ZERO, Color("6b4a32"), boat)
		_block(Vector3(1.6, 0.6, 1.0), Vector3(0.6, 0.45, 0), Color("2f6fb0"), boat)
		add_child(boat)


## Một ô tứ giác nằm ngang: cạnh trái tại x1 (z từ za1 tới zb1), cạnh phải tại x2 (z từ za2 tới zb2).
func _quad(st: SurfaceTool, x1: float, x2: float, za1: float, za2: float, zb1: float, zb2: float, y: float) -> void:
	var a := Vector3(x1, y, za1)
	var b := Vector3(x2, y, za2)
	var c := Vector3(x2, y, zb2)
	var d := Vector3(x1, y, zb1)
	for v in [a, b, c, a, c, d]:
		st.set_normal(Vector3.UP)
		st.add_vertex(v)


## Phía nam hẻm Bờ Nam là ruộng rau muống và bãi đất trống: thấp, không che phố.
func _build_fields() -> void:
	if not city.streets.has("bo_nam"):
		return
	var z0: float = float(city.streets.bo_nam.rect.end.y) + 0.6
	var z1: float = city.bounds.end.y + 20.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 64
	var x := city.bounds.position.x - 20.0
	while x < city.bounds.end.x + 20.0:
		var w := rng.randf_range(12.0, 22.0)
		var paddy := StandardMaterial3D.new()
		paddy.albedo_color = Color("4f7a3a").lerp(Color("6f8f45"), rng.randf())
		paddy.roughness = 0.35
		var f := _block(Vector3(w - 0.8, 0.04, z1 - z0), Vector3(x + w / 2.0, 0.0, (z0 + z1) / 2.0), Color("5a7a40"))
		f.material_override = paddy
		_block(Vector3(0.6, 0.12, z1 - z0), Vector3(x + w - 0.3, 0.0, (z0 + z1) / 2.0), Color("6b5a44"))
		x += w
	_block(Vector3(city.bounds.size.x + 40.0, 0.12, 0.6), Vector3(city.bounds.get_center().x, 0.0, z0), Color("6b5a44"))
	for i in 9:
		var tx := rng.randf_range(city.bounds.position.x, city.bounds.end.x)
		_tree(Vector3(tx, 0, rng.randf_range(z0 + 3.0, z0 + 12.0)), rng, 1.2)


func _build_location(id: String, loc: Dictionary) -> void:
	var p: Dictionary = city.locs[id]
	var w := float(p.w)
	var d := float(p.d)
	var color := Color(loc.color)
	var holder := _frame_node(p, id)
	add_child(holder)
	# Phần nhà nằm trong nút riêng để ẩn đi khi che An; người, vòng cửa, tên vẫn hiện.
	var bld := Node3D.new()
	holder.add_child(bld)
	var sign_height := 3.4
	var top := float(loc.get("h", 6.0))
	var model := models.spawn("buildings." + id, null, Vector3(w, top, d))
	if model:
		bld.add_child(model)
		top = float(model.get_meta("height"))
		sign_height = minf(top + 0.8, SIGN_MAX)
	elif loc.has("tube"):
		top = _build_tube(id, loc, bld, w, d)
		sign_height = minf(top + 0.8, SIGN_MAX)
	elif loc.get("shelter", false):
		_build_shelter(bld, w, d, color)
		top = 3.0
		sign_height = 3.6
	if loc.get("stalls", false):
		_build_stalls(w, holder)
	if loc.get("line", false):
		_build_clothesline(holder)
	var body := StaticBody3D.new()
	body.set_meta("loc", id)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(w, maxf(top, 2.5), d)
	cs.shape = bs
	cs.position = Vector3(0, maxf(top, 2.5) / 2.0, -d / 2.0)
	body.add_child(cs)
	holder.add_child(body)
	holder.add_child(_label3d(str(loc.name), Vector3(0, sign_height, 0.5), 36))
	occluders.append({"node": bld, "rect": CityMap.footprint(p), "h": top})

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
	ring.position = Vector3(0, 0.2, DOOR_OUT)
	ring.scale = Vector3(1, 0.3, 1)
	holder.add_child(ring)
	door_rings[id] = ring

	var slot := 0
	for who in loc.get("npcs", []):
		var npc := _character("npc." + str(who.id), Color(who.color), Color("3a3a40"))
		npc.position = Vector3(1.6 + slot * 1.7, 0, DOOR_OUT + 0.2 + (slot % 2) * 0.45)
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
		if str(who.id) != "":
			npc_nodes[str(who.id)] = {"node": npc, "body": nb, "name": str(who.name), "loc": id}


## Tiệm dựng thành một hoặc vài căn nhà ống liền nhau (toạ độ cục bộ của lô); biển hiệu đặt ở căn giữa.
func _build_tube(id: String, loc: Dictionary, holder: Node3D, width: float, depth: float) -> float:
	var tube: Dictionary = loc.tube
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var units := int(tube.get("units", 1))
	var w := width / float(units)
	var top := 0.0
	for u in units:
		var x: float = -width / 2.0 + w * (float(u) + 0.5)
		var main := u == units / 2
		var wall := Color(loc.color) if main else Color(loc.color).darkened(0.06 * float(u % 2 + 1))
		top = maxf(top, tubes.house(holder, x, w, maxf(depth, 6.0), int(tube.get("floors", 3)), wall, rng,
			str(tube.get("sign", "")) if main else "", bool(tube.get("shop", true)) and main))
	return top


## Mái che trạm xe đưa rước: bốn cột, mái tôn, ghế dài và tấm bảng tuyến xe.
func _build_shelter(holder: Node3D, w: float, d: float, color: Color) -> void:
	for px in [-w / 2.0 + 0.3, w / 2.0 - 0.3]:
		for pz in [-d + 0.3, -0.3]:
			_block(Vector3(0.12, 2.8, 0.12), Vector3(px, 0.16, pz), Color("4b4d52"), holder)
	_block(Vector3(w, 0.12, d + 0.6), Vector3(0, 2.9, -d / 2.0 + 0.2), color, holder)
	_block(Vector3(w - 1.2, 0.45, 0.5), Vector3(0, 0.16, -d + 0.6), Color("8a6a4a"), holder)
	_block(Vector3(1.4, 1.0, 0.08), Vector3(-w / 2.0 + 1.0, 1.6, -d + 0.15), Color("f4efe1"), holder)


## Nhà ống dọc mọi mặt tiền còn trống, đánh số nhà kiểu Sài Gòn (42/3/5) bằng tấm biển xanh cạnh cửa.
func _build_houses() -> void:
	var holder := Node3D.new()
	holder.name = "nha_pho"
	add_child(holder)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	homes = []
	var plate_mat := _mat(Color("1e5aa8"))
	for p in city.plots:
		if p.loc != "":
			continue
		var node := _frame_node(p)
		holder.add_child(node)
		var kind := str(city.streets[p.street].kind)
		var w := float(p.w)
		var floors: int
		var sign := ""
		var shop := false
		match kind:
			"duong", "cho":
				floors = rng.randi_range(2, 5)
				if rng.randf() < 0.6:
					sign = FILLER_SIGNS[rng.randi() % FILLER_SIGNS.size()]
			"bo_ke":
				floors = rng.randi_range(2, 4)
				if rng.randf() < 0.3:
					sign = FILLER_SIGNS[rng.randi() % FILLER_SIGNS.size()]
			_:
				# Nhà trong hẻm và nhà sàn bờ nam thấp hơn, ít bảng hiệu.
				floors = rng.randi_range(1, 2) if str(p.street) == "bo_nam" else rng.randi_range(1, 4)
				if rng.randf() < 0.18:
					sign = HEM_SIGNS[rng.randi() % HEM_SIGNS.size()]
		shop = sign != "" or (kind in ["duong", "cho"] and rng.randf() < 0.3)
		var h: float = tubes.house(node, 0.0, w, float(p.d), floors, tubes.pick(rng, TubeHouse.WALLS), rng, sign, shop)
		if str(p.street) == "bo_nam":
			# Nhà sàn: cọc chống phía sau, lưng nhà chìa ra mép nước.
			for k in 3:
				_block(Vector3(0.18, 1.2, 0.18), Vector3(-w / 2.0 + 0.4 + k * (w - 0.8) / 2.0, -0.9, -float(p.d) + 0.3), Color("4a4038"), node)
		var plate := Label3D.new()
		plate.text = str(p.no)
		plate.font = font
		plate.font_size = 34
		plate.pixel_size = 0.01
		plate.outline_size = 0
		plate.modulate = Color("ffffff")
		plate.position = Vector3(w / 2.0 - 0.75, 2.25, 0.2)
		node.add_child(plate)
		var board := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.62, 0.32, 0.04)
		board.mesh = bm
		board.material_override = plate_mat
		board.position = Vector3(w / 2.0 - 0.75, 2.25, 0.16)
		node.add_child(board)
		_clutter(p, node, rng)
		occluders.append({"node": node, "rect": CityMap.footprint(p), "h": h})
		homes.append({"pos": plot_point(p, 0.0, DOOR_OUT), "no": str(p.no), "name": "Nhà " + str(p.address)})


## Khối nhà phía trong lô phố: chỉ thấy tường cũ và mái, có bồn nước inox trên nóc.
func _build_fillers() -> void:
	var holder := Node3D.new()
	holder.name = "nha_trong"
	add_child(holder)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var mats := []
	for c in TubeHouse.WALLS:
		mats.append(_mat(Color(c).lerp(Color("8f8270"), 0.45)))
	var tank_mat := _mat(Color("d5d9de"))
	for f in city.fillers:
		var r: Rect2 = f.rect
		var h := float(f.h)
		var node := Node3D.new()
		holder.add_child(node)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(r.size.x - 0.1, h, r.size.y - 0.05)
		mi.mesh = bm
		mi.material_override = mats[rng.randi() % mats.size()]
		mi.position = _v3(r.get_center(), h / 2.0)
		node.add_child(mi)
		if rng.randf() < 0.3:
			var tank := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.45
			cm.bottom_radius = 0.45
			cm.height = 1.1
			tank.mesh = cm
			tank.material_override = tank_mat
			tank.position = _v3(r.get_center(), h + 0.55)
			node.add_child(tank)
		occluders.append({"node": node, "rect": r, "h": h})
	# Dãy cao ốc phía bắc, sau khu công nghiệp: chỉ thấy phần trên.
	tubes.back_row(holder, city.bounds.position.x - 20.0, city.bounds.end.x + 20.0, city.bounds.position.y - 1.0, rng)


## Cột điện và dây điện chằng chịt, cây me dọc bờ kè, cây dọc vỉa hè đường lớn, đèn đường, xe máy dựng.
func _build_props() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	if city.streets.has("an_hoa"):
		var st: Dictionary = city.streets.an_hoa
		var r: Rect2 = st.rect
		for side in [r.position.y + 0.6, r.end.y - 0.6]:
			var poles := []
			var x: float = st.lo + 4.0
			while x < st.hi - 2.0:
				if _clear_spot(Vector2(x, side), 1.6):
					_block(Vector3(0.28, 7.5, 0.28), Vector3(x, 0, side), Color("6b6a66"))
					_block(Vector3(1.6, 0.12, 0.12), Vector3(x, 6.9, side), Color("55544f"))
					if poles.size() % 2 == 0:
						_prop("utility_box", Vector3(x, 1.1, side + (0.25 if side < st.c else -0.25)))
					poles.append(x)
				x += 15.0
			for i in range(poles.size() - 1):
				for k in 3:
					_wire(Vector3(poles[i], 6.95 - k * 0.25, side + (k - 1) * 0.4), Vector3(poles[i + 1], 6.95 - k * 0.25, side + (k - 1) * 0.4))
		# Cây và đèn đường ở vỉa hè phía nam, xe máy dựng dọc hai bên.
		var tx: float = st.lo + 8.0
		while tx < st.hi - 4.0:
			var spot := Vector2(tx, r.end.y - 1.3)
			if _clear_spot(spot, 2.5):
				_tree(_v3(spot), rng, 0.8)
			tx += 16.0
		var lx: float = st.lo + 12.0
		while lx < st.hi - 4.0:
			_lamp(Vector3(lx, 0.16, r.end.y - 0.5), PI)
			lx += 20.0
		for i in 26:
			var bx := rng.randf_range(st.lo + 3.0, st.hi - 3.0)
			var bz: float = r.position.y + 1.9 if rng.randf() < 0.5 else r.end.y - 1.9
			if _clear_spot(Vector2(bx, bz), 1.2):
				var bike := _bike(Color.from_hsv(rng.randf(), 0.45, 0.7), rng)
				bike.position = Vector3(bx, 0.16, bz)
				bike.rotation.y = rng.randf_range(-0.3, 0.3) + PI / 2.0
				add_child(bike)
	# Bờ kè: hàng cây me, lan can sắt dọc mép rạch, đèn đường.
	if city.streets.has("bo_me"):
		var st: Dictionary = city.streets.bo_me
		var r: Rect2 = st.rect
		var x: float = st.lo
		while x < st.hi:
			if not _on_bridge(x + 1.0):
				_block(Vector3(2.0, 0.06, 0.06), Vector3(x + 1.0, 1.05, r.end.y + 0.15), Color("5d6166"))
				_block(Vector3(2.0, 0.06, 0.06), Vector3(x + 1.0, 0.55, r.end.y + 0.15), Color("5d6166"))
				_block(Vector3(0.08, 1.1, 0.08), Vector3(x, 0, r.end.y + 0.15), Color("5d6166"))
			x += 2.0
		var mx: float = st.lo + 3.0
		while mx < st.hi:
			if not _on_bridge(mx):
				_tree(Vector3(mx, 0, r.end.y + 2.2), rng, 1.25)
			mx += 9.0
		var lx: float = st.lo + 6.0
		while lx < st.hi:
			if not _on_bridge(lx):
				_lamp(Vector3(lx, 0.0, r.end.y - 0.3), PI)
			lx += 18.0
	# Hẻm: dây điện giăng ngang hẻm từng khúc, đèn tuýp gắn tường.
	for id in city.order:
		var st: Dictionary = city.streets[id]
		if not (str(st.kind) in ["hem", "hem_nho"]):
			continue
		var r: Rect2 = st.rect
		var horiz: bool = st.axis == "x"
		var u: float = st.lo + 3.0
		while u < st.hi - 1.0:
			var h1 := rng.randf_range(5.0, 6.6)
			var h2 := rng.randf_range(5.0, 6.6)
			var off := rng.randf_range(-1.5, 1.5)
			if horiz:
				_wire(Vector3(u, h1, r.position.y + 0.1), Vector3(u + off, h2, r.end.y - 0.1))
			else:
				_wire(Vector3(r.position.x + 0.1, h1, u), Vector3(r.end.x - 0.1, h2, u + off))
			u += rng.randf_range(4.0, 7.0)
		var bike := _bike(Color.from_hsv(rng.randf(), 0.45, 0.7), rng)
		var bp := r.get_center() + (Vector2(rng.randf_range(-r.size.x / 3.0, r.size.x / 3.0), r.size.y / 2.0 - 0.7) if horiz else Vector2(r.size.x / 2.0 - 0.7, rng.randf_range(-r.size.y / 3.0, r.size.y / 3.0)))
		bike.position = _v3(bp, 0.06)
		bike.rotation.y = 0.0 if horiz else PI / 2.0
		add_child(bike)
	# Bờ nam: vài cây đèn, cây dừa.
	if city.streets.has("bo_nam"):
		var st: Dictionary = city.streets.bo_nam
		var lx: float = st.lo + 10.0
		while lx < st.hi:
			if _clear_spot(Vector2(lx, st.rect.position.y + 0.4), 1.5):
				_lamp(Vector3(lx, 0.0, st.rect.position.y + 0.4), 0.0)
			lx += 28.0


func _on_bridge(x: float) -> bool:
	for id in ["cau_nho", "cau_tre"]:
		if city.streets.has(id):
			var r: Rect2 = city.streets[id].rect
			if x > r.position.x - 1.2 and x < r.end.x + 1.2:
				return true
	return false


## Chỗ trống để đặt cây, cột: không sát cửa địa điểm, không chắn đầu hẻm.
func _clear_spot(p: Vector2, r: float) -> bool:
	for id in LOCATIONS:
		if city.loc_door(id).distance_to(p) < r + 1.2:
			return false
	# Điểm nằm ngay trước đầu một hẻm hay đường Chợ thì bỏ, để khỏi chắn lối vào.
	for id in city.order:
		var st: Dictionary = city.streets[id]
		if str(st.kind) in ["hem", "hem_nho", "cho"] and (st.rect as Rect2).grow(1.0).has_point(p) and not (st.walk as Rect2).has_point(p):
			return false
	return true


func _tree(pos: Vector3, rng: RandomNumberGenerator, scale := 1.0) -> void:
	var tree := models.spawn("tree", rng)
	if tree:
		tree.position = pos
		tree.rotation.y = rng.randf() * TAU
		tree.scale = Vector3.ONE * scale
		add_child(tree)
		return
	_block(Vector3(0.3, 2.4 * scale, 0.3), pos, Color("5a4634"))
	for k in 7:
		var crown := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = rng.randf_range(0.45, 0.75) * scale
		sm.height = sm.radius * 1.6
		sm.radial_segments = 10
		sm.rings = 6
		crown.mesh = sm
		crown.material_override = _mat_cached(Color("3d5531").lerp(Color("5f7a3f"), float(k) / 6.0))
		crown.position = pos + Vector3(rng.randf_range(-0.8, 0.8) * scale, (2.7 + rng.randf_range(0.0, 0.9)) * scale, rng.randf_range(-0.7, 0.7) * scale)
		add_child(crown)


func _lamp(pos: Vector3, rot := 0.0) -> void:
	if not _prop("lamp", pos, rot):
		_block(Vector3(0.14, 5.2, 0.14), pos, Color("4b4d52"))
	var lamp := OmniLight3D.new()
	lamp.position = pos + Vector3(0, 4.9, 0)
	lamp.omni_range = 9.0
	lamp.light_color = Color("ffcf8a")
	lamp.light_energy = 0.0
	lamp.visible = false
	add_child(lamp)
	lamps.append(lamp)


## Cổng khu công nghiệp, cổng hẻm "khu phố văn hóa", bảng tên hẻm và đường ở đầu mỗi lối, cây dừa đầu Hẻm Dừa.
func _build_gates() -> void:
	var g: Dictionary = city.data.get("kcn_gate", {})
	if not g.is_empty():
		var gp := Vector2(float(g.pos[0]), float(g.pos[1]))
		for sx in [-5.2, 5.2]:
			_block(Vector3(0.9, 5.6, 0.9), Vector3(gp.x + sx, 0, gp.y), Color("b8b2a6"))
		_block(Vector3(11.4, 0.9, 0.8), Vector3(gp.x, 5.0, gp.y), Color("1e5aa8"))
		add_child(_label3d(str(g.text), Vector3(gp.x, 6.4, gp.y + 0.6), 40))
		_block(Vector3(9.4, 1.6, 0.12), Vector3(gp.x, 0, gp.y + 0.3), Color("7d7f84"))
	for id in city.order:
		var st: Dictionary = city.streets[id]
		if not st.has("parent"):
			continue
		var start: Vector2 = st.start
		var horiz: bool = st.axis == "x"
		var hw: float = (st.rect.size.y if horiz else st.rect.size.x) / 2.0
		var name := str(st.display)
		if str(st.get("official", "")) != "" and str(st.official) != name:
			name += " · " + str(st.official)
		if st.has("gate"):
			# Cổng hẻm: hai trụ, xà ngang sơn xanh, chữ khu phố.
			for s in [-1.0, 1.0]:
				var pp := start + (Vector2(0, s * (hw + 0.25)) if horiz else Vector2(s * (hw + 0.25), 0))
				_block(Vector3(0.45, 4.6, 0.45), _v3(pp), Color("d8d0c0"))
			var bc := start + (Vector2(0.2 * sign(st.dir.x), 0) if horiz else Vector2(0, 0.2 * sign(st.dir.y)))
			_block(Vector3(0.4, 0.7, hw * 2.0 + 1.0) if horiz else Vector3(hw * 2.0 + 1.0, 0.7, 0.4), _v3(bc, 4.3), Color("2f6fb0"))
			var gl := _label3d(name.to_upper() + "\n" + str(st.gate), _v3(bc, 5.4), 26)
			add_child(gl)
		else:
			add_child(_label3d(name, _v3(start + st.dir * 1.5, 3.2), 24))
		if id == "hem_dua":
			# Cây dừa ở góc vỉa hè đường Chợ, ngay đầu hẻm: tên hẻm từ đây mà ra.
			var rng := RandomNumberGenerator.new()
			rng.seed = 5
			_coconut(_v3(start - st.dir * 1.2 + Vector2(0, -float(st.rect.size.y) / 2.0 - 0.7)), rng)
	# Bảng tên các đường lớn ở chỗ giao nhau.
	for id in ["an_hoa", "bo_me", "duong_cho", "bo_nam"]:
		if not city.streets.has(id):
			continue
		var st: Dictionary = city.streets[id]
		var r: Rect2 = st.rect
		var spots := []
		if id == "an_hoa":
			spots = [Vector2(-40.0, r.end.y - 0.4), Vector2(30.0, r.position.y + 0.4)]
		elif id == "duong_cho":
			spots = [Vector2(r.end.x - 0.4, r.position.y + 6.0)]
		elif id == "bo_me":
			spots = [Vector2(-10.0, r.position.y + 0.4), Vector2(62.0, r.position.y + 0.4)]
		else:
			spots = [Vector2(-30.0, r.end.y - 0.3)]
		for sp in spots:
			add_child(_label3d(str(st.display), _v3(sp, 3.6), 24))


func _coconut(pos: Vector3, rng: RandomNumberGenerator) -> void:
	var trunk := _block(Vector3(0.3, 6.5, 0.3), pos, Color("7a6a55"))
	trunk.rotation.z = 0.12
	for k in 7:
		var leaf := _block(Vector3(2.6, 0.06, 0.5), pos + Vector3(0.8, 6.3, 0), Color("4f7a3a").lerp(Color("6f9a4a"), rng.randf()))
		leaf.rotation = Vector3(0, float(k) * TAU / 7.0, -0.45)
		leaf.position = pos + Vector3(0.8 + cos(float(k) * TAU / 7.0) * 1.1, 6.2, -sin(float(k) * TAU / 7.0) * 1.1)


## Sạp chợ trên vỉa hè trước chợ và dọc đường Chợ: bàn gỗ, bạt xanh, thùng nhựa, giỏ hàng; ghế đẩu quán trà đá.
func _build_stalls(w: float, holder: Node3D) -> void:
	var wood := Surfaces.get_mat("tuong_cu", 1.5, Color("9a7a58"))
	for sx in [-w / 2.0 + 1.6, w / 2.0 - 2.2]:
		_stall(Vector3(sx, 0.16, 1.25), holder, wood)
	for sx in [w / 2.0 - 0.6, w / 2.0 + 0.2]:
		if not _prop("stool", Vector3(sx, 0.16, 1.7), randf() * TAU, holder):
			_block(Vector3(0.35, 0.4, 0.35), Vector3(sx, 0.16, 1.7), Color("2f6fb0"), holder)
	# Sạp hai bên đường Chợ, sát mặt tiền nhà.
	if city.streets.has("duong_cho"):
		var st: Dictionary = city.streets.duong_cho
		var r: Rect2 = st.rect
		var z: float = st.lo + 5.0
		while z < st.hi - 3.0:
			for x in [r.position.x + 1.2, r.end.x - 1.2]:
				var node := Node3D.new()
				node.position = Vector3(x, 0.16, z)
				node.rotation.y = PI / 2.0 if x < st.c else -PI / 2.0
				add_child(node)
				_stall(Vector3.ZERO, node, wood)
			z += 6.5


func _stall(pos: Vector3, holder: Node3D, wood: Material) -> void:
	_block(Vector3(2.6, 0.8, 1.2), pos, Color("8a6a4a"), holder).material_override = wood
	var tarp := _block(Vector3(3.0, 0.05, 1.9), pos + Vector3(0, 2.2, 0), Color("2f6fb0"), holder)
	tarp.rotation.x = -0.12
	for px in [-1.3, 1.3]:
		_block(Vector3(0.06, 2.2, 0.06), pos + Vector3(px, 0, 0.8), Color("6b6a66"), holder)
	_prop("basket", pos + Vector3(-0.6, 0.8, 0), randf() * TAU, holder)
	_prop("crate", pos + Vector3(0.7, 0.8, 0.05), randf() * TAU, holder)


## Dây phơi đồ trước xóm trọ, áo quần nhiều màu.
func _build_clothesline(holder: Node3D) -> void:
	for wx in [-5.5, -2.5]:
		_block(Vector3(0.07, 2.3, 0.07), Vector3(wx, 0.16, 1.8), Color("6b6a66"), holder)
	_block(Vector3(3.0, 0.02, 0.02), Vector3(-4.0, 2.35, 1.8), Color("3a3a3a"), holder)
	var shirt_colors := ["e6e2d3", "6f8fb5", "c46a5a", "d9a35b"]
	for i in 4:
		var c := _block(Vector3(0.5, 0.62, 0.03), Vector3(-5.1 + i * 0.72, 1.7, 1.8), Color(shirt_colors[i]), holder)
		c.rotation.z = randf_range(-0.05, 0.05)
		c.add_to_group("do_phoi")


## Đồ đạc bày trước nhà: thùng nhựa chồng nhau, thùng các-tông, chậu cây, giỏ mây.
func _clutter(p: Dictionary, node: Node3D, rng: RandomNumberGenerator) -> void:
	var w := float(p.w)
	for k in rng.randi_range(0, 2):
		var key: String = ["crate", "crate", "box", "plant", "basket", "plant"][rng.randi() % 6]
		var u := rng.randf_range(-w / 2.0 + 0.4, w / 2.0 - 0.4)
		if absf(u) < 0.9:
			continue
		var pos := Vector3(u, 0.16, rng.randf_range(0.25, 0.55))
		_prop(key, pos, rng.randf_range(-0.4, 0.4) + (PI if rng.randf() < 0.5 else 0.0), node)
		if key == "crate" and rng.randf() < 0.5:
			_prop("crate", pos + Vector3(0, 0.3, 0), rng.randf_range(-0.2, 0.2), node)


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


## Vết bẩn, nước đọng, giấy rác vương vãi: phố Sài Gòn không bao giờ sạch bong.
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
	var wet_mat := StandardMaterial3D.new()
	wet_mat.albedo_texture = stain_tex
	wet_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wet_mat.albedo_color = Color(0.12, 0.1, 0.08, 0.45)
	wet_mat.roughness = 0.15
	var dry_mat := wet_mat.duplicate()
	dry_mat.albedo_color = Color(0.25, 0.2, 0.14, 0.35)
	dry_mat.roughness = 0.9
	var paper := _mat(Color("e9e2d0"))
	for id in city.order:
		var r: Rect2 = city.streets[id].rect
		var n := int(r.get_area() / 90.0)
		var horiz: bool = city.streets[id].axis == "x"
		for i in n:
			var p := Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))
			if rng.randf() < 0.7:
				var mi := MeshInstance3D.new()
				var qm := QuadMesh.new()
				var s := rng.randf_range(0.8, 2.6)
				qm.size = Vector2(s, s * rng.randf_range(0.5, 1.0))
				mi.mesh = qm
				mi.material_override = wet_mat if rng.randf() < 0.4 else dry_mat
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mi.position = _v3(p, 0.17)
				mi.rotation = Vector3(-PI / 2.0, rng.randf() * TAU, 0)
				add_child(mi)
			else:
				# Giấy rác dạt vào sát lề, không nằm giữa lòng đường.
				var edge := rng.randf_range(0.3, 1.4) * (1.0 if rng.randf() < 0.5 else -1.0)
				if horiz:
					p.y = (r.position.y if edge > 0.0 else r.end.y) + edge
				else:
					p.x = (r.position.x if edge > 0.0 else r.end.x) + edge
				var mi := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(rng.randf_range(0.15, 0.32), 0.008, rng.randf_range(0.2, 0.35))
				mi.mesh = bm
				mi.material_override = paper
				mi.position = _v3(p, 0.17)
				mi.rotation.y = rng.randf() * TAU
				add_child(mi)


## Thùng rác sát mặt tiền dọc các vỉa hè và hẻm để lục ve chai.
func _build_bins() -> void:
	var i := 0
	for id in city.order:
		var st: Dictionary = city.streets[id]
		var step := 26.0 if str(st.kind) == "duong" else 22.0
		for side in st.houses:
			var n := CityMap.side_normal(str(side))
			var u: float = st.lo + 5.0 + float(i % 3) * 2.0
			while u < st.hi - 4.0:
				var r: Rect2 = st.rect
				var line := Vector2(u, r.position.y) if str(side) == "n" else (Vector2(u, r.end.y) if str(side) == "s" else (Vector2(r.position.x, u) if str(side) == "w" else Vector2(r.end.x, u)))
				var pos := line + n * 0.6
				if city.walkable(pos) and _clear_spot(pos, 1.0):
					_bin(_v3(pos), "t%d" % i, i)
					i += 1
				u += step


func _bin(pos: Vector3, id: String, i: int) -> void:
	var holder := Node3D.new()
	holder.position = pos
	add_child(holder)
	if _prop("trash_can", Vector3(0, 0.16, 0), randf() * TAU, holder):
		if i % 3 != 1:
			_prop("trashbag", Vector3(0.75, 0.16, 0.15), randf() * TAU, holder)
	else:
		_block(Vector3(0.6, 0.85, 0.55), Vector3.ZERO, Color("2e7d32"), holder)
		_block(Vector3(0.66, 0.08, 0.6), Vector3(0, 0.85, 0), Color("1b4d20"), holder)
	bins.append({"id": id, "pos": pos})


## Xe máy chạy theo làn trên đường lớn, đường Bờ Me, đường Chợ; người đi bộ dọc vỉa hè và trong hẻm.
func _build_traffic() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var lanes := []
	if city.streets.has("an_hoa"):
		var st: Dictionary = city.streets.an_hoa
		lanes.append({"axis": "x", "c": st.c - 1.6, "lo": st.lo - 10.0, "hi": st.hi + 10.0, "dir": -1.0, "n": 5})
		lanes.append({"axis": "x", "c": st.c + 1.6, "lo": st.lo - 10.0, "hi": st.hi + 10.0, "dir": 1.0, "n": 5})
	if city.streets.has("bo_me"):
		var st: Dictionary = city.streets.bo_me
		lanes.append({"axis": "x", "c": st.c + 0.2, "lo": st.lo - 10.0, "hi": st.hi, "dir": -1.0, "n": 2})
		lanes.append({"axis": "x", "c": st.c + 1.6, "lo": st.lo - 10.0, "hi": st.hi, "dir": 1.0, "n": 2})
	if city.streets.has("duong_cho"):
		var st: Dictionary = city.streets.duong_cho
		lanes.append({"axis": "z", "c": st.c - 0.9, "lo": st.lo, "hi": st.hi, "dir": -1.0, "n": 1})
		lanes.append({"axis": "z", "c": st.c + 0.9, "lo": st.lo, "hi": st.hi, "dir": 1.0, "n": 1})
	for lane in lanes:
		for i in int(lane.n):
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
			var u := rng.randf_range(float(lane.lo), float(lane.hi))
			var dir := float(lane.dir)
			if lane.axis == "x":
				bike.position = Vector3(u, 0, float(lane.c))
				bike.rotation.y = 0.0 if dir > 0 else PI
			else:
				bike.position = Vector3(float(lane.c), 0, u)
				bike.rotation.y = -PI / 2.0 if dir > 0 else PI / 2.0
			add_child(bike)
			bikes.append({"node": bike, "dir": dir, "speed": rng.randf_range(5.0, 9.0) if lane.n > 2 else rng.randf_range(3.0, 5.0), "lane": lane})
	# Người đi bộ: mỗi người đi tới đi lui trên một vỉa hè hoặc một con hẻm.
	var paths := []
	for id in city.order:
		var st: Dictionary = city.streets[id]
		if str(st.kind) in ["cau", "cau_nho"]:
			continue
		var r: Rect2 = st.rect
		var horiz: bool = st.axis == "x"
		var cross: float = r.size.y if horiz else r.size.x
		var lines := [0.0] if cross < 6.0 else [-cross / 2.0 + 1.0, cross / 2.0 - 1.0]
		if str(st.kind) == "bo_ke":
			lines = [-cross / 2.0 + 1.0]
		for off in lines:
			paths.append({"axis": st.axis, "c": float(st.c) + off, "lo": float(st.lo) + 1.0, "hi": float(st.hi) - 1.0})
	for i in 16:
		var pth: Dictionary = paths[i % paths.size()]
		var w := _character("people", Color.from_hsv(rng.randf(), 0.3, 0.65), Color.from_hsv(rng.randf(), 0.2, 0.35), rng)
		var u := rng.randf_range(float(pth.lo), float(pth.hi))
		w.position = Vector3(u, 0, pth.c) if pth.axis == "x" else Vector3(pth.c, 0, u)
		add_child(w)
		walkers.append({"node": w, "goal": w.position, "speed": rng.randf_range(1.2, 2.0), "wait": rng.randf_range(0, 3), "path": pth})


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
		step = _slide(key_dir.normalized() * _speed() * delta)
	elif _target != null:
		step = _follow_path(_speed() * delta)
	if step != Vector3.ZERO:
		player.position += step
		_add_walk(step.length() * (RainLayer.WADE_COST if _wading() else 1.0))
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

	var cam_goal := player.position + cam_offset()
	camera.position = camera.position.lerp(cam_goal, clampf(delta * 4.0, 0.0, 1.0))
	camera.look_at(camera.position - cam_offset() + Vector3(0, lerpf(1.3, 1.0, zoom), 0), Vector3.UP)
	_update_cutaway()

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


## Đi bằng phím: chỉ bước vào chỗ đi được, chạm tường thì trượt dọc theo tường.
func _slide(step: Vector3) -> Vector3:
	var p := Vector2(player.position.x, player.position.z)
	for s in [Vector2(step.x, step.z), Vector2(step.x, 0), Vector2(0, step.z)]:
		if s != Vector2.ZERO and city.walkable(p + s):
			return Vector3(s.x, 0, s.y)
	return Vector3.ZERO


## Bước theo các điểm rẽ của đường đi; tới điểm cuối thì mở địa điểm (nếu đi tới một nơi).
func _follow_path(dist: float) -> Vector3:
	if _path_i >= _path.size():
		_arrive()
		return Vector3.ZERO
	var wp := _path[_path_i]
	var to := Vector3(wp.x - player.position.x, 0, wp.y - player.position.z)
	if to.length() <= dist:
		_path_i += 1
		if _path_i >= _path.size():
			player.position = Vector3(wp.x, player.position.y, wp.y)
			_arrive()
			return Vector3.ZERO
		return to
	return to.normalized() * dist


func _arrive() -> void:
	_target = null
	if _target_loc != "":
		hud.open_location(_target_loc)
		_target_loc = ""


## Đi bộ tới một điểm trên phố theo đường đi tìm được.
func walk_to(pos: Vector3, loc := "") -> void:
	_path = city.path(Vector2(player.position.x, player.position.z), Vector2(pos.x, pos.z))
	_path_i = 1
	_target_loc = loc
	if _path.size() < 2:
		_target = null
		if loc != "" and door_of(loc).distance_to(player.position) <= INTERACT_RANGE:
			hud.open_location(loc)
		_target_loc = ""
		return
	_target = _v3(_path[_path.size() - 1])


## Nhà nào nằm giữa camera và An (phía nam, đủ cao để che theo góc nhìn hiện tại) thì ẩn đi.
func _update_cutaway() -> void:
	var off := cam_offset()
	var k := off.z / maxf(off.y, 0.1)
	var px := player.position.x
	var pz := player.position.z
	for o in occluders:
		var r: Rect2 = o.rect
		var hide := r.position.x - CUT_MARGIN < px and px < r.end.x + CUT_MARGIN and r.end.y > pz + 0.4 \
			and r.position.y - pz < float(o.h) * k + 1.0
		var node: Node3D = o.node
		if node.visible == hide:
			node.visible = not hide


# ---------------------------------------------------------------- ve chai, phong độ

## Phong độ thấp thì lê bước, đi chậm hẳn.
func _speed() -> float:
	var v := SPEED
	if _wading():
		v *= RainLayer.WADE_SPEED
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


## An đang lội qua chỗ ngập ngày mưa.
func _wading() -> bool:
	return _rain_layer != null and _rain_layer.wading(Vector2(player.position.x, player.position.z))


## Vùng ngập hôm nay (rỗng nếu tạnh), cho bản đồ tô màu.
func flood_rects() -> Array:
	return [] if _rain_layer == null else _rain_layer.flood_rects()


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
	var pos := Vector3(INF, 0, INF)
	for b in bins:
		if b.id == id:
			pos = b.pos
	var got: Dictionary = game.scavenge(id, pos.x, pos.z)
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


# ---------------------------------------------------------------- giao đồ ăn

## Chỗ cần tới của đơn đang chạy: quán (chưa lấy món) hoặc nhà khách. null nếu không có đơn.
func delivery_target():
	var o: Dictionary = game.delivery_active()
	if o.is_empty():
		return null
	if not o.picked:
		return door_of(str(o.shop))
	return Vector3(float(o.dest_x), 0, float(o.get("dest_z", 0.0)))


## Tạo một đơn mới từ vị trí thật trên phố: quán ngẫu nhiên, giao tới nhà dân (địa chỉ kiểu 42/3/5)
## hoặc một chỗ khác cách quán vừa phải. Tiền công tính theo đường đi thật cả lúc lấy lẫn lúc giao.
func make_offer() -> Dictionary:
	var shops: Array = game.cfg.delivery.shops.keys()
	var shop: String = shops.pick_random()
	var sp := door_of(shop)
	var dests := []
	for h in homes:
		dests.append({"name": h.name, "pos": h.pos})
	for id in LOCATIONS:
		if id != shop:
			dests.append({"name": str(LOCATIONS[id].name), "pos": door_of(id)})
	dests = dests.filter(func(d) -> bool:
		var dd: float = (d.pos as Vector3).distance_to(sp)
		return dd >= 15.0 and dd <= 90.0)
	if dests.is_empty():
		return {}
	var dest: Dictionary = dests.pick_random()
	var dp: Vector3 = dest.pos
	var here := Vector2(player.position.x, player.position.z)
	var meters: float = city.path_length(here, Vector2(sp.x, sp.z)) + city.path_length(Vector2(sp.x, sp.z), Vector2(dp.x, dp.z)) + 4.0
	return game.delivery_offer(shop, str(LOCATIONS[shop].name), str(dest.name), dp.x, meters, dp.z)


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
	hud.close_location()
	if col.has_meta("loc"):
		walk_to_location(str(col.get_meta("loc")))
	else:
		walk_to(hit.position)


func _update_traffic(delta: float) -> void:
	for b in bikes:
		var n: Node3D = b.node
		var lane: Dictionary = b.lane
		if lane.axis == "x":
			n.position.x += b.dir * b.speed * delta
			if n.position.x > float(lane.hi):
				n.position.x = float(lane.lo)
			elif n.position.x < float(lane.lo):
				n.position.x = float(lane.hi)
		else:
			n.position.z += b.dir * b.speed * delta
			if n.position.z > float(lane.hi):
				n.position.z = float(lane.lo)
			elif n.position.z < float(lane.lo):
				n.position.z = float(lane.hi)
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
			var pth: Dictionary = w.path
			if pth.axis == "x":
				w["goal"] = Vector3(clampf(n.position.x + randf_range(-14, 14), pth.lo, pth.hi), 0, pth.c)
			else:
				w["goal"] = Vector3(pth.c, 0, clampf(n.position.z + randf_range(-14, 14), pth.lo, pth.hi))
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
			player.position = loc_point(HOME, -1.5, 0.8)
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
	var on := hour >= (16.0 if rain else 18.0)
	for lamp in lamps:
		lamp.visible = on
		lamp.light_energy = 2.2 if on else 0.0
	_set_rain(rain)
	# Mưa: sương xám dày hơn, nhìn xa mờ hẳn.
	env.fog_light_color = Color("8f98a3") if rain else Color("8f8c86")
	env.fog_density = 0.0065 if rain else 0.004
	# Mức ngập: theo rainFlood trong config (ngày 15 mức 1, ngày 29 mức 2).
	var lvl := 0
	if rain:
		lvl = int(game.cfg.get("rainFlood", {}).get(str(game.day()), 1))
	if lvl > 0 and _rain_layer == null:
		_rain_layer = RainLayer.new()
		_rain_layer.world = self
		add_child(_rain_layer)
		_rain_layer.build()
	if _rain_layer != null:
		_rain_layer.apply(lvl, game.s.flags)


var _rain: CPUParticles3D
var _rain_layer: Node3D


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
	return _v3(city.loc_door(id))


## Nhân vật đang ở địa điểm nào ("" nếu đang đi đường hay đi khỏi phường).
func npc_where(id: String) -> String:
	return life.npc_where(id)


## Người có tên đang có mặt ở địa điểm: [{id, name}].
func npcs_at(loc: String) -> Array:
	return life.npcs_at(loc)


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
	walk_to(door_of(id), id)


# ---------------------------------------------------------------- khối hình tạm

func _mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.92
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


## Vật liệu dùng chung theo màu cho những khối lặp lại nhiều (cây, khối nhà).
func _mat_cached(color: Color) -> StandardMaterial3D:
	var k := color.to_html()
	if not _mat_cache.has(k):
		_mat_cache[k] = _mat(color)
	return _mat_cache[k]


## Khối hộp đặt đáy tại pos (pos.y là cao độ đáy).
func _block(size: Vector3, pos: Vector3, color: Color, parent: Node = null, transparent := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat_cached(color)
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


## Dây điện nối hai điểm bất kỳ.
func _wire(a: Vector3, b: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.025
	cm.bottom_radius = 0.025
	cm.height = a.distance_to(b)
	mi.mesh = cm
	mi.material_override = _mat_cached(Color("1d1d1f"))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.position = (a + b) / 2.0
	var dir := (b - a).normalized()
	if absf(dir.dot(Vector3.UP)) < 0.999:
		mi.basis = Basis(Quaternion(Vector3.UP, dir))


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


## Người theo mô hình trong models.json (key như "player", "npc.BA_TU", "people"), thiếu thì dựng nhân vật có khớp
## (character.gd): An và nhân vật phụ có ngoại hình riêng, người đi đường ngẫu nhiên.
## Con đầu tiên luôn là phần thân (mô hình hoặc khối) để nhún nhảy hay phát hoạt cảnh.
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
		wheel.material_override = _mat_cached(Color("1a1a1a"))
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
	_ending_home = Node3D.new()
	add_child(_ending_home)
	var family := ["BA_TU"]
	if str(game.s.linh.decision) != "xa":
		family.append("LINH")
	var i := 0
	for id in family:
		var who := _character("npc." + id, Color("8a6f9a"), Color("3a3a40"))
		who.position = loc_point(loc, 0.9 + i * 1.0, 0.7)
		who.rotation.y = CityMap.rot_y(city.locs[loc].normal) + PI * 0.15
		_ending_home.add_child(who)
		who.add_child(_label3d(game.rep_name(id), Vector3(0, 1.9, 0), 20))
		i += 1
	var pot := loc_point(loc, -1.8, -0.3) + Vector3(0, 0.16, 0)
	if not _prop("plant", pot, 0.0, _ending_home):
		_block(Vector3(0.35, 0.35, 0.35), pot, Color("5f7a3f"), _ending_home)
	_ending_home.add_child(_label3d("Chậu húng của bà", pot + Vector3(0, 0.8, 0), 18))
	player.position = loc_point(loc, -0.2, 1.0)
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


## Những điểm cần tới hôm nay: [vị trí, màu, độ cao dấu]. Bản đồ nhỏ cũng dùng danh sách này.
func objective_spots() -> Array:
	var out := []
	if not game.is_started():
		return out
	for id in game.scenes_today():
		var loc := str(game.scene_info(id).loc)
		if LOCATIONS.has(loc):
			out.append([door_of(loc), Color("f2c14e"), 4.2])
	for id in game.quests_active():
		var t: Dictionary = game.quest_target(id)
		if t.has("loc") and LOCATIONS.has(t.loc):
			out.append([door_of(str(t.loc)), Color("5aa9ff"), 4.2])
		elif t.has("area"):
			for b in bins:
				if game.in_area(t.area, b.pos.x, b.pos.z) and game.scrap_lock(b.id) == "":
					out.append([b.pos, Color("5aa9ff"), 2.2])
	return out


func _refresh_quest_marks() -> void:
	var offers := {}
	for q in game.quest_offers():
		offers[str(q.giver)] = true
	for loc in offers:
		if not _quest_offer_marks.has(loc):
			var l := _label3d("!", Vector3.ZERO, 120)
			l.modulate = Color("f2c14e")
			l.outline_modulate = Color("3a2a00")
			l.position = loc_point(loc, 1.6 if LOCATIONS[loc].has("npcs") else 0.0, 0.2)
			l.set_meta("y", 3.0)
			add_child(l)
			_quest_offer_marks[loc] = l
	for loc in _quest_offer_marks.keys():
		if not offers.has(loc):
			_quest_offer_marks[loc].queue_free()
			_quest_offer_marks.erase(loc)
	var spots := objective_spots()
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
			var p: Vector3 = spots[i][0]
			(m.material_override as StandardMaterial3D).albedo_color = spots[i][1]
			# Hai dấu cùng một cửa thì đặt lệch nhau cho khỏi chồng.
			var dup := 0
			for j in i:
				if spots[j][0] == p:
					dup += 1
			m.position = Vector3(p.x + dup * 0.9, m.position.y, p.z)
			m.set_meta("y", spots[i][2])
