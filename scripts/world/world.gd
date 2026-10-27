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
const RealCity := preload("res://scripts/world/real_city.gd")
const Landmarks := preload("res://scripts/world/landmarks.gd")
const Geo := preload("res://scripts/realmap/geo.gd")
const AreaBuilder := preload("res://scripts/realmap/area_builder.gd")
const RainLayer := preload("res://scripts/world/rain_layer.gd")
const StreetLife := preload("res://scripts/world/street_life.gd")
const Props3D := preload("res://scripts/world/props3d.gd")
const Traffic := preload("res://scripts/world/traffic.gd")
const Crowd := preload("res://scripts/world/crowd.gd")
const TitleScreen := preload("res://scripts/ui/title_screen.gd")

## Xóm trọ của An ở chương 1: nơi xuất phát mỗi sáng và nơi đi ngủ mỗi tối. Chương 2 "home" là chỗ ở đã chốt
## (game.home_loc()); bà, Linh, má đứng trước cửa chỗ đó, ông Ba ở sát vách.
const HOME := "xom_bo_me"
## Để HUD đọc được id nhà mà không cần truy cập hằng số qua instance.
var home: String = HOME
## Địa điểm của truyện. Vị trí, bề ngang, chiều sâu nằm ở data/map.json (locations).
## npcs: người đứng trước cửa (bấm vào cũng mở địa điểm), id là khóa trong story.reps và data/talks.json.
## tube: dựng thành nhà ống (floors tầng, sign chữ biển hiệu, units số căn liền nhau, shop tầng trệt buôn bán).
## shelter: mái che trạm xe. stalls: sạp chợ, ghế trà đá · line: dây phơi đồ trước cửa · scrap: chỗ bán ve chai.
## LOCATIONS: các địa điểm có trên map đang chơi (lọc từ ALL_LOCATIONS lúc dựng màn phố; map cũ không có chỗ mới của
## giai đoạn 4 thì bỏ qua chỗ đó).
var LOCATIONS: Dictionary = {}
const ALL_LOCATIONS := {
	"ben_xe_6": {"name": "Điểm xe buýt Long Biên", "desc": "Điểm xe buýt Long Biên trên đê Trần Nhật Duật, sát chân cầu: xe đưa rước công nhân ra khu công nghiệp Bắc Thăng Long đón ở đây. Trung tâm nghề của Linh cũng đi xe ở đây.", "color": "3c7d6b", "shelter": true, "h": 3.0},
	"cho_cau_nho": {"name": "Chợ Long Biên", "desc": "Chợ Long Biên dưới chân cầu Long Biên, ngoài đê: chợ đầu mối rau quả, xe tải nông sản về từ nửa đêm, sạp vật tư, hàng đồ cũ, sạp đồng nát của cô Thắm và quán trà đá có bảng tin cho thuê phòng.",
		"tube": {"floors": 2, "sign": "CHỢ LONG BIÊN", "units": 3}, "color": "c8503f", "stalls": true, "scrap": true,
		"npcs": [{"name": "Cô Thắm đồng nát", "id": "", "color": "6b4f3a"}]},
	"com_hanh": {"name": "Cơm Hạnh", "desc": "Quán cơm bình dân của chị Hạnh trong ngõ chợ Đồng Xuân, cho người làm ca, người kéo xe thồ, shipper. Nhận ca phụ, giao cơm, nghe chuyện dãy quán cần sửa điện.",
		"tube": {"floors": 3, "sign": "CƠM HẠNH"}, "color": "e39a66",
		"npcs": [{"name": "Chị Hạnh", "id": "HANH", "color": "c0603a"}, {"name": "Minh", "id": "MINH", "color": "2f5f8a"}]},
	"tiem_sau": {"name": "Tiệm Sơn Sửa", "desc": "Tiệm chú Sơn trong một vòm cầu đường sắt bên phố Gầm Cầu: sửa xe máy, thêm một bàn sửa đồ điện gia dụng. Tàu chạy qua trên đầu thì cả tiệm rung.",
		"tube": {"floors": 3, "sign": "SƠN SỬA XE · ĐỒ ĐIỆN"}, "color": "6f8fa8",
		"npcs": [{"name": "Chú Sơn", "id": "SAU", "color": "3f5f7a"}]},
	"xom_bo_me": {"name": "Xóm trọ Phúc Tân", "desc": "Tám phòng trọ quanh khoảng sân trong ngõ 51 Phúc Tân, ngoài đê, sau lưng là bãi sông Hồng; vòi nước chung, dây phơi dưới mái tôn. Về đây để nghỉ và đi ngủ.",
		"tube": {"floors": 3, "sign": "XÓM TRỌ PHÚC TÂN", "units": 3}, "color": "eadcae", "line": true,
		"npcs": [{"name": "Bà Thoa", "id": "BA_TU", "color": "8a6f9a"}, {"name": "Linh", "id": "LINH", "color": "d9776b"}, {"name": "Cô Duyên", "id": "DUYEN", "color": "b5577a"}]},
	# Ba chỗ ở mới: gác xép ngõ Gạch gần chợ và gần việc, Ngọc Thụy bên kia sông (đi xa hơn), nhà dì Nga trên phố Hàng Chiếu.
	"hem_dua": {"name": "Gác xép ngõ Gạch", "desc": "Gác xép trong ngõ Gạch rẽ ra từ phố Hàng Buồm, đầu ngõ có cây bàng, quanh là quán net, tiệm cầm đồ. Phòng nhỏ, trần thấp, cửa sát mặt ngõ, ít chỗ phơi.",
		"tube": {"floors": 3, "sign": "PHÒNG CHO THUÊ", "shop": false}, "color": "d8c39a", "home": "hem_dua",
		"npcs": [{"name": "Cô chủ phòng", "id": "", "color": "9a6a8a"}]},
	"cau_tre": {"name": "Phòng Ngọc Thụy", "desc": "Bên kia sông, phải đi qua cầu Long Biên. Dãy nhà trên phố Ngọc Thụy, lưng quay ra sông; phòng thoáng, có hiên rộng, đi làm xa hơn.",
		"tube": {"floors": 2, "sign": "PHÒNG TRỌ NGỌC THỤY", "shop": false}, "color": "a9c4a0", "home": "cau_tre",
		"npcs": [{"name": "Chú chủ nhà", "id": "", "color": "5a6a7a"}]},
	"nha_di_nam": {"name": "Nhà dì Nga", "desc": "Nhà dì Nga trên phố Hàng Chiếu, gần chợ Đồng Xuân và điểm xe buýt. Ở tạm được bảy ngày, phải gửi bớt đồ.",
		"tube": {"floors": 2, "sign": "", "shop": false}, "color": "e0b08a", "home": "di_nam",
		"npcs": [{"name": "Dì Nga", "id": "", "color": "7a5a4a"}]},
	"ben_can": {"name": "Dãy quán bia Tạ Hiện", "desc": "Dãy năm quán bia hơi vỉa hè phố Tạ Hiện, chung lối đi và đường điện cũ chằng chịt. Hợp đồng sửa điện của anh Phúc.",
		"tube": {"floors": 2, "sign": "BIA HƠI TẠ HIỆN", "units": 5}, "color": "9c9a93",
		"npcs": [{"name": "Anh Phúc", "id": "PHUC", "color": "c9853a"}, {"name": "Trâm", "id": "TRAM", "color": "2f6f6a"}]},
	# Giai đoạn 4: chỗ làm, dịch vụ, chỗ chơi mới (chỉ có trên map phố cổ hn_pho_co).
	"bai_boc_vac": {"name": "Bãi bốc vác chợ Long Biên", "desc": "Bãi xe tải nông sản sát chợ: tối nào xe rau, xe quả cũng về, cần người bốc dỡ.",
		"color": "6b7d4a", "shelter": true, "crates": true, "h": 3.0,
		"npcs": [{"name": "Anh cai bốc vác", "id": "", "color": "5a4a3a"}]},
	"xe_tho": {"name": "Điểm thuê xe thồ", "desc": "Đầu phố Hàng Chiếu, sau lưng chợ Đồng Xuân: kéo hàng từ kho ra sạp, trả theo chuyến.",
		"color": "8a6a3a", "shelter": true, "carts": true, "h": 3.0,
		"npcs": [{"name": "Chú cho thuê xe", "id": "", "color": "4a5a6a"}]},
	"nha_tro_giuong": {"name": "Nhà trọ giường tầng", "desc": "Ngõ 79 Phúc Tân, 30.000đ một đêm: phòng chung mười hai giường tầng.",
		"tube": {"floors": 2, "sign": "NGHỈ TRỌ 30K/ĐÊM", "shop": false}, "color": "c9b48a",
		"npcs": [{"name": "Bà chủ trọ", "id": "", "color": "7a4a5a"}]},
	"quan_net": {"name": "Quán net Hàng Bạc", "desc": "Mở thâu đêm: tìm việc, đọc tin, chơi một ván, hay gục xuống bàn ngủ qua đêm.",
		"tube": {"floors": 3, "sign": "INTERNET · GAME 24/7"}, "color": "3f4f6a"},
	"cam_do": {"name": "Tiệm cầm đồ ngõ Gạch", "desc": "Cầm đồ lấy tiền ngay, hẹn mười ngày chuộc, có lãi.",
		"tube": {"floors": 3, "sign": "CẦM ĐỒ · CẦM VÀNG"}, "color": "8a3a2a"},
	"ve_so": {"name": "Đại lý vé số Mã Mây", "desc": "Vé 10.000đ một tờ, chiều mở thưởng.",
		"tube": {"floors": 2, "sign": "VÉ SỐ KIẾN THIẾT"}, "color": "d0a030"},
	"ho_guom": {"name": "Ghế đá hồ Gươm", "desc": "Sáng sớm các cụ tập dưỡng sinh, ngày có bàn cờ tướng, tối người ngồi hóng gió.",
		"color": "5f8a5a", "benches": true, "h": 1.0,
		"npcs": [{"name": "Cụ Thiện đánh cờ", "id": "", "color": "6a6a6a"}, {"name": "Cụ Lan dưỡng sinh", "id": "", "color": "9a6a8a"}]},
	# Đời sống phố: shop si-đa túi mù của chị Vy, quán bi-a của anh Dũng.
	"shop_ao": {"name": "Shop si-đa Hàng Đào", "desc": "Hàng thùng về từ cửa khẩu, bán lẻ và bán túi mù 99.000đ: bóc ra gì mặc nấy.",
		"tube": {"floors": 3, "sign": "SI-ĐA · TÚI MÙ 99K"}, "color": "c0507a",
		"npcs": [{"name": "Chị Vy", "id": "VY", "color": "d06a8a"}]},
	"bi_a": {"name": "Quán bi-a anh Dũng", "desc": "Sáu bàn lỗ, quạt trần, tiếng bi lách cách tới khuya; tối thứ Bảy có giải.",
		"tube": {"floors": 2, "sign": "BI-A · 30K/GIỜ"}, "color": "2f6a4a",
		"npcs": [{"name": "Anh Dũng", "id": "DUNG", "color": "3a4a5a"}]}
}
const SPEED := 6.0
## Đi giao hàng thì An chạy xe máy: nhanh gấp chừng này, mỗi mét tốn chừng này phần giờ so với đi bộ.
const RIDE_SPEED := 1.8
## Chạy nhanh (giữ Shift, nút Chạy trên màn cảm ứng): nhanh gấp SPRINT lần, mỗi mét chỉ tốn RUN_TIME giờ đi bộ, cứ
## RUN_FATIGUE_M mét thì Mệt +1; trong ngõ hẹp không chạy được, còn đi chậm lại LANE_SLOW lần vì chật người, xe.
const SPRINT := 1.65
const RUN_TIME := 0.6
const RUN_FATIGUE_M := 70.0
const LANE_SLOW := 0.82
## Kéo màn hình để nhìn quanh: máy quay lệch khỏi An tối đa PAN_MAX mét, An đi lại thì máy quay trôi về.
const PAN_MAX := 80.0
const RIDE_TIME := 0.35
## Camera góc chơi xa (nhìn cả dãy phố) và gần nhất (thấy rõ nhân vật); con lăn chuột chỉnh giữa hai mức, lăn tiếp ra
## xa là nhìn toàn cảnh (CAM_FAR).
const CAM_OFFSET := Vector3(0, 24, 17)
const CAM_NEAR := Vector3(0, 6.5, 9.0)
## Nhìn toàn cảnh (zoom từ 1 tới ZOOM_MAX): máy quay lùi xa, ngắm cả khu phố như mô hình sa bàn.
const CAM_FAR := Vector3(0, 92, 64)
const ZOOM_MAX := 2.0
const INTERACT_RANGE := 2.4
## Bảng tên tiệm không cao hơn mức này để không lọt lên mép trên màn hình dưới bảng mục tiêu.
const SIGN_MAX := 4.6
## Nhà phía trước lệch sang hai bên trong khoảng này cũng ẩn theo, cho thấy cả người đứng cạnh An.
const CUT_MARGIN := 3.0
const FILLER_SIGNS := ["SỬA XE", "TẠP HÓA", "PHỞ", "CẮT TÓC", "BÁNH MÌ", "PHOTOCOPY", "NHÀ THUỐC", "SIM THẺ", "GỘI ĐẦU", "BÚN BÒ", "ĐIỆN THOẠI", "VẢI SỢI", "CƠM TẤM", "CÀ PHÊ", "HỦ TIẾU", "GẠO"]
const HEM_SIGNS := ["TẠP HÓA", "CẮT TÓC", "CHÈ", "NƯỚC MÍA", "BÁNH CUỐN", "SỬA ĐIỆN THOẠI", "GIẶT ỦI", "BÁNH MÌ"]

## Map đang chơi: city_map.gd (phường An Hòa vẽ tay) hay real_city.gd (khu thật nướng sẵn, chọn ở "map" trong config).
var city
var real := false
## Mô hình khu thật (nhà, đường, sông, cây) khi chơi trên map thật.
var area: Node3D
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
## Xe máy của An (hiện khi đang có đơn giao hàng), An đang ngồi trên xe.
var _ride_bike: Node3D
var _riding := false
var font: SystemFont
var lamps: Array = []
var door_rings := {}
var walkers: Array = []
var bikes: Array = []
## Dòng xe chạy trên map thật (traffic.gd); map phường vẽ tay dùng bikes.
var traffic: Node3D = null
## Đám đông trên map thật (crowd.gd): khách quán cóc, chủ tiệm, người đi vỉa hè, trẻ con đá banh.
var crowd: Node3D = null
## Chỗ đông người của truyện trên map thật: [địa điểm, số người đứng quanh cổng, bán kính (m)].
const CROWD_SPOTS := [["cho_cau_nho", 26, 12.0], ["ben_xe_6", 10, 7.0], ["com_hanh", 5, 5.0]]
## Khối nhà có thể che An: {"node", "rect": Rect2 nền nhà, "h": chiều cao}.
var occluders: Array = []
## Nhân vật có tên: id -> {node, body, name, loc}; street_life cho họ đi lại theo giờ.
var npc_nodes := {}
var life: Node
## Màn đầu game (tiêu đề, chọn câu chuyện, tin nhắn mở đầu); null khi chạy thử không qua cảnh chính.
var title: CanvasLayer = null
var _title_hidden: Array = []

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
var _run_meters := 0.0
var _pan := Vector3.ZERO
var _panning := false
var _lane := false
var _lane_t := 0.0
## Giây thật đứng chơi chưa tính vào giờ trong game (đồng hồ kết hợp: đứng yên giờ vẫn trôi chậm).
var _idle_t := 0.0
var _night_prompt_day := -1
var _mat_cache := {}


func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	game = GameState.game
	font = UI.text_font()
	var map_id := _map_id()
	real = map_id != "an_hoa" and FileAccess.file_exists("res://data/maps/%s.json" % map_id)
	city = RealCity.new(map_id) if real else CityMap.new()
	for id in ALL_LOCATIONS:
		if city.locs.has(id):
			LOCATIONS[id] = ALL_LOCATIONS[id]
	_build_environment()
	tubes = TubeHouse.new(0.0, font)
	if real:
		_build_real()
	else:
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
	home = game.home_loc() if game.is_started() and LOCATIONS.has(game.home_loc()) else HOME
	player.position = loc_point(home, -1.5, 0.8)
	# Về từ màn khác thì hiện ra ở chỗ đó.
	var gs := get_node("/root/GameState")
	if gs.spawn_at != "" and LOCATIONS.has(gs.spawn_at):
		player.position = loc_point(gs.spawn_at, 1.5, 0.8)
		gs.spawn_at = ""
	camera = Camera3D.new()
	camera.fov = 34
	# Máy quay phối cảnh đứng xa An 11–110 m: mặt cắt gần 0,1 m không bao giờ cắt cụt mái, tầng trên nhà gần máy.
	camera.near = 0.1
	camera.far = 1500.0
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
	print("[world] dựng màn phố %d ms (map %s)" % [Time.get_ticks_msec() - t0, _map_id()])
	# Vào thẳng chế độ Dựng khu thật: bản web có "?khu" trên địa chỉ, hay đối số "--realmap-auto=…" khi thử tự động.
	var to_realmap := false
	for arg in OS.get_cmdline_user_args():
		to_realmap = to_realmap or arg.begins_with("--realmap-auto=")
	if OS.has_feature("web"):
		to_realmap = to_realmap or str(JavaScriptBridge.eval("window.location.search", true)).contains("khu")
	if to_realmap:
		get_tree().change_scene_to_file.call_deferred("res://scenes/realmap.tscn")
		return
	_open_title()
	# Dùng khi chụp màn hình kiểm tra: "-- --demo --demo-open=com_hanh" mở sẵn một địa điểm.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--demo-open="):
			var id := arg.substr(12)
			player.position = door_of(id)
			camera.position = player.position + cam_offset()
			hud.open_location.call_deferred(id)


## Mở màn tiêu đề khi vào game (chỉ khi đây là cảnh chính và ván chơi thật; bài thử dựng màn phố riêng, các chế độ
## "--demo…" và "--no-title" thì bỏ qua). Trong lúc đó giấu thanh trên dưới, giữ các bảng thoại lại, máy quay do màn tiêu đề điều khiển.
func _open_title() -> void:
	if get_tree().current_scene != self or not GameState._persist or "--no-title" in OS.get_cmdline_user_args():
		return
	TitleScreen.apply_settings(TitleScreen.load_settings())
	title = TitleScreen.new()
	title.world = self
	title.game = game
	add_child(title)
	_hold_for_title(true)
	title.started.connect(func() -> void:
		_hold_for_title(false)
		camera.position = player.position + cam_offset())


func _hold_for_title(on: bool) -> void:
	hud.visible = not on
	hud.dialogs.hold = on
	hud.dialogs.refresh()
	# Nền màn đầu như tranh vẽ: giấu tên người, tên địa điểm nổi trên phố, vào game thì hiện lại đúng những cái đã giấu.
	if on:
		for l in find_children("*", "Label3D", true, false):
			if l.visible:
				l.visible = false
				_title_hidden.append(l)
	else:
		for l in _title_hidden:
			if is_instance_valid(l):
				l.visible = true
		_title_hidden.clear()


## Esc giữa lúc chơi: mở lại màn đầu như menu tạm dừng (Chơi tiếp, Bắt đầu câu chuyện khác, Cài đặt, Thoát).
func open_menu() -> void:
	if title == null or title.visible:
		return
	title.show_page("title")
	_hold_for_title(true)


func title_open() -> bool:
	return title != null and title.visible


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
	return plot_point(city.locs[id], along, city.door_out + out)


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
	# Màu tươi, nắng trong như mô hình phố: không làm nhạt màu, sương mỏng (đổi theo giờ, trời mưa trong _update_lighting).
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.1
	env.adjustment_saturation = 0.94
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.4
	env.fog_enabled = true
	env.fog_light_color = Color("cfe0ec")
	env.fog_density = 0.0012
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 70.0
	if ScreenFit.light_shadows:
		# Điện thoại, trình duyệt: bản đồ bóng nhỏ hơn, hai tầng bóng, tầng gần phủ xa hơn cho đỡ sọc khi nắng xiên.
		RenderingServer.directional_shadow_atlas_set_size(2048, true)
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_split_1 = 0.4
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
	var x: float = city.bounds.position.x - 20.0
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
	if loc.get("benches", false):
		# Ghế đá ven hồ: ba băng ghế quay mặt ra hồ, một bàn cờ tướng giữa hai ghế.
		for i in 3:
			var bx := -w / 2.0 + 1.3 + i * (w - 2.6) / 2.0
			_block(Vector3(1.6, 0.42, 0.45), Vector3(bx, 0.0, -d + 0.6), Color("9a958a"), holder)
		_block(Vector3(0.7, 0.62, 0.7), Vector3(0.0, 0.0, -d / 2.0 - 0.2), Color("8a8478"), holder)
		_block(Vector3(0.6, 0.02, 0.6), Vector3(0.0, 0.62, -d / 2.0 - 0.2), Color("e8d9a8"), holder)
	if loc.get("crates", false):
		# Sọt rau, bao củ, thùng quả chất dưới mái che bãi xe.
		var rng := RandomNumberGenerator.new()
		rng.seed = 41
		for i in 9:
			var col: Color = [Color("6f9a4a"), Color("b85a3a"), Color("c9a86a")][i % 3]
			_block(Vector3(0.6, 0.45, 0.45), Vector3(-w / 2.0 + 0.8 + (i % 5) * 0.9 + rng.randf_range(-0.1, 0.1), (i / 5) * 0.45, -d + 0.8 + (i % 2) * 0.6), col, holder)
	if loc.get("carts", false):
		# Hai chiếc xe thồ gỗ dựng nghiêng cạnh mái che.
		for i in 2:
			var cx := -w / 2.0 + 1.2 + i * 2.4
			_block(Vector3(0.9, 0.08, 1.8), Vector3(cx, 0.55, -d / 2.0), Color("7a5a3a"), holder)
			for side in [-0.48, 0.48]:
				_block(Vector3(0.06, 0.55, 0.55), Vector3(cx + side, 0.0, -d / 2.0 + 0.4), Color("2a2a2a"), holder)
	var body := StaticBody3D.new()
	body.set_meta("loc", id)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(w, maxf(top, 2.5), d)
	cs.shape = bs
	cs.position = Vector3(0, maxf(top, 2.5) / 2.0, -d / 2.0)
	body.add_child(cs)
	holder.add_child(body)
	# Tên địa điểm: thẻ nhỏ ngang cửa (như "Bánh kẹp" trong Nobody), chỉ hiện khi An tới gần.
	var loc_tag := _label3d(str(loc.name), Vector3(0, 3.0, city.door_out + 0.4), 22)
	loc_tag.add_to_group("near_tag")
	loc_tag.set_meta("range", LOC_TAG_RANGE)
	holder.add_child(loc_tag)
	var occ := {"node": bld, "rect": CityMap.footprint(p), "h": top}
	if real:
		occ.merge(_cut_stand_in(p, holder, color, top))
	occluders.append(occ)

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
	ring.position = Vector3(0, 0.2, city.door_out)
	ring.scale = Vector3(1, 0.3, 1)
	holder.add_child(ring)
	door_rings[id] = ring

	var slot := 0
	for who in loc.get("npcs", []):
		var npc := _character("npc." + str(who.id), Color(who.color), Color("3a3a40"))
		npc.position = Vector3(1.6 + slot * 1.7, 0, city.door_out + 0.2 + (slot % 2) * 0.45)
		npc.rotation.y = PI
		holder.add_child(npc)
		npc.add_child(_name_tag(who.name, Vector3(0, 2.0 + (slot % 2) * 0.3, 0)))
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
			npc_nodes[str(who.id)] = {"node": npc, "body": nb, "name": str(who.name), "loc": id, "color": str(who.color)}


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


## Map thật: đường viền lô (để xét có che An không) và khối thay thế khi hạ nhà của địa điểm: hộp màu tường cao 1 m
## (co giãn theo độ cao đang hạ), mặt trên màu vữa sáng như nhà thật bị hạ.
func _cut_stand_in(p: Dictionary, holder: Node3D, color: Color, top: float) -> Dictionary:
	var w := float(p.w)
	var d := maxf(float(p.d), 6.0)
	var n: Vector2 = p.normal
	var t := Vector2(n.y, -n.x)
	var c: Vector2 = p.center
	var poly := PackedVector2Array([c - t * w / 2.0, c + t * w / 2.0, c + t * w / 2.0 - n * d, c - t * w / 2.0 - n * d])
	var pivot := Node3D.new()
	pivot.visible = false
	holder.add_child(pivot)
	var box := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, 1.0, d)
	box.mesh = bm
	box.position = Vector3(0, 0.5, -d / 2.0)
	if _stand_shader == null:
		_stand_shader = Shader.new()
		_stand_shader.code = STAND_SHADER
	var m := ShaderMaterial.new()
	m.shader = _stand_shader
	m.set_shader_parameter("wall", color)
	# Mặt cắt cùng màu với nhà thật bị hạ (shader nhà đổi màu đỉnh sRGB sang tuyến tính rồi pha với màu mặt cắt).
	m.set_shader_parameter("top", AreaBuilder.CUT_COLOR.lerp(color.srgb_to_linear(), 0.2))
	box.material_override = m
	pivot.add_child(box)
	return {"poly": poly, "stand": pivot, "cap": top, "stand_mat": m}


const STAND_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 wall : source_color;
uniform vec3 top;
varying float up;
void vertex() {
	up = NORMAL.y;
}
void fragment() {
	ALBEDO = up > 0.5 ? top : wall;
	ROUGHNESS = 0.9;
}
"""
var _stand_shader: Shader


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
		homes.append({"pos": plot_point(p, 0.0, city.door_out), "no": str(p.no), "name": "Nhà " + str(p.address)})


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
		bike.rotation.y = PI / 2.0 if horiz else 0.0
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
	var trunk := Props3D.instance(Props3D.trunk(), Color("5a4634"))
	trunk.position = pos + Vector3(0, 1.2 * scale, 0)
	trunk.scale = Vector3.ONE * scale
	add_child(trunk)
	var crown := Props3D.instance(Props3D.crown(), Color("3d5531").lerp(Color("6f8a45"), rng.randf()))
	crown.position = pos + Vector3(0, 3.5 * scale, 0)
	crown.scale = Vector3.ONE * scale * 0.78
	crown.rotation.y = rng.randf() * TAU
	add_child(crown)


func _lamp(pos: Vector3, rot := 0.0) -> void:
	if not _prop("lamp", pos, rot):
		_block(Vector3(0.14, 5.2, 0.14), pos, Color("4b4d52"))
	var lamp := OmniLight3D.new()
	lamp.position = pos + Vector3(0, 4.9, 0)
	lamp.omni_range = 11.0
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


## Cây dừa (props3d.gd): thân cong có đốt, tàu lá rủ, buồng dừa.
func _coconut(pos: Vector3, rng: RandomNumberGenerator, parent: Node3D = null) -> void:
	var palm := Props3D.instance(Props3D.palm())
	palm.position = pos
	palm.rotation.y = rng.randf() * TAU
	(parent if parent != null else self).add_child(palm)


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


## Bàn gỗ của các sạp chợ (đám đông trên map thật: người bán đứng sau sạp, người mua đứng trước).
var _stall_tables: Array[Node3D] = []


func _stall(pos: Vector3, holder: Node3D, wood: Material) -> void:
	var table := _block(Vector3(2.6, 0.8, 1.2), pos, Color("8a6a4a"), holder)
	table.material_override = wood
	_stall_tables.append(table)
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
			_ride(bike, rng)
			var u := rng.randf_range(float(lane.lo), float(lane.hi))
			var dir := float(lane.dir)
			if lane.axis == "x":
				bike.position = Vector3(u, 0, float(lane.c))
				bike.rotation.y = PI / 2.0 if dir > 0 else -PI / 2.0
			else:
				bike.position = Vector3(float(lane.c), 0, u)
				bike.rotation.y = 0.0 if dir > 0 else PI
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

## Map chơi: "--map=<id>" khi chạy, không thì "map" trong config.json; "an_hoa" là phường vẽ tay.
func _map_id() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--map="):
			return a.substr(6)
	return str(game.cfg.get("map", "an_hoa"))


# ---------------------------------------------------------------- map thật

## Dựng màn phố trên khu thật: mô hình khu (nhà, đường, kênh, cây, xe đậu), các địa điểm của truyện dựng bằng nhà ống
## có biển hiệu đặt lên lô đã dọn, nhà có số để giao hàng, thùng rác, đèn đường, xe máy và người đi bộ trên đường thật.
func _build_real() -> void:
	area = AreaBuilder.new()
	area.show_labels = false
	# Lòng đường có vân nhựa đường như phường vẽ tay, sẫm hơn cho hợp ánh nắng của màn phố; vỉa hè, sân, hẻm lát gạch,
	# xi măng (xem AreaBuilder.GROUND_SHADER).
	var asphalt := Surfaces.get_mat("duong", 4.0, Color(0.78, 0.76, 0.72), true)
	area.ground_material = AreaBuilder.ground_shader_material(asphalt.albedo_texture, asphalt.normal_texture, Color(0.78, 0.76, 0.72), 4.0)
	area.water_color = Color("234d4a")
	area.park_cars_from = Traffic.PARKED_CARS_FROM
	if ScreenFit.low_power:
		area.detail_range = 120.0
	add_child(area)
	var mid := Vector2.ZERO
	for id in city.locs:
		area.keep_clear.append(city.loc_door(id))
		mid += city.loc_door(id)
	# Đồ phố Việt quanh các địa điểm của truyện; biển hiệu, cổng hẻm, bảng tên đường có chữ ở gần, tên đường hư cấu.
	area.dress_opts = {"center": mid / maxf(city.locs.size(), 1.0), "radius": 300.0, "label_radius": 190.0, "name_of": city.street_name}
	area.build(city.data, city.clip, city.grid)
	for m in area.cut_materials:
		m.set_shader_parameter("cut_on", true)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	ground.add_child(shape)
	add_child(ground)
	for id in LOCATIONS:
		if city.locs.has(id):
			_build_location(id, LOCATIONS[id])
	for h in city.homes:
		homes.append({"pos": _v3(h.pos), "no": str(h.no), "name": "Nhà " + str(h.address)})
	var i := 0
	for b in city.bins:
		_bin(_v3(b), "b%d" % i, i)
		i += 1
	# Map thật rộng hơn: đi bộ tính giờ theo map; vùng tìm của việc nhờ đặt lại theo chỗ chợ thật.
	if city.story.has("walkHoursPerMeter"):
		game.cfg["walkHoursPerMeter"] = float(city.story.walkHoursPerMeter)
	for q in game.quests:
		if city.quest_areas.has(str(q.id)):
			for step in q.get("steps", []):
				if str(step.get("kind", "")) == "find":
					step["area"] = city.quest_areas[str(q.id)]
	_build_real_lamps()
	_build_lanterns()
	_build_lamp_pools()
	_build_real_traffic()
	_build_real_canal()
	Landmarks.build(self, city.story.get("landmarks", []), font)
	# Cây dừa đầu hẻm của Phòng Hẻm Dừa: tên hẻm từ đây mà ra. Đứng chắn trước An thì thu nhỏ như cây thường.
	if city.locs.has("hem_dua"):
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		var palm := Node3D.new()
		palm.position = _v3(city.alley_mouth("hem_dua"))
		add_child(palm)
		_coconut(Vector3.ZERO, rng, palm)
		var c := Vector2(palm.position.x, palm.position.z)
		var sq := PackedVector2Array([c + Vector2(-3, -3), c + Vector2(3, -3), c + Vector2(3, 3), c + Vector2(-3, 3)])
		occluders.append({"node": palm, "rect": Geo.bounds(sq), "h": 6.6, "poly": sq, "cap": 6.6, "stand": null})


## Kênh rạch trên map thật: bờ kè đá dọc mép nước (bỏ các cạnh trùng mép khung), ghe xuồng neo sát bờ,
## vài chiếc ghe chở hàng trôi chầm chậm qua lại giữa dòng.
var boats: Array = []


func _build_real_canal() -> void:
	var stone := Surfaces.get_mat("tuong_cu", 2.0, Color("8a8478"))
	var clip: PackedVector2Array = city.clip
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var moor: Array = []
	for w in city.data.water:
		var poly: PackedVector2Array = w.poly
		var inward := 1.0 if Geometry2D.is_polygon_clockwise(poly) == Geometry2D.is_polygon_clockwise(clip) else -1.0
		for i in poly.size():
			var a := poly[i]
			var b := poly[(i + 1) % poly.size()]
			var mid := (a + b) / 2.0
			# Cạnh nằm trên mép khung là chỗ mặt nước bị cắt, không có bờ.
			var on_edge := false
			for k in clip.size():
				if Geo.seg_dist(mid, clip[k], clip[(k + 1) % clip.size()]) < 1.0:
					on_edge = true
					break
			if on_edge or a.distance_to(b) < 0.5:
				continue
			AreaBuilder._wall_seg(st, a, b, -0.4, 0.75, 0.6, Color("8a8478"))
			# Chỗ neo ghe: cách mép 3,5 m vào lòng kênh.
			var d := (b - a).normalized()
			var n := d.orthogonal() * inward
			AreaBuilder._along(PackedVector2Array([a, b]), 26.0, func(p: Vector2, _dd: Vector2) -> void:
				var q: Vector2 = p - n * 3.5 if Geometry2D.is_point_in_polygon(p - n * 3.5, poly) else p + n * 3.5
				if Geometry2D.is_point_in_polygon(q, poly) and rng.randf() < 0.45:
					moor.append([q, d]))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = stone
	add_child(mi)
	for i in moor.size():
		var m: Array = moor[i]
		var boat := _boat(rng, i % 5 == 0)
		boat.position = _v3(m[0], 0.02)
		boat.rotation.y = atan2((m[1] as Vector2).x, (m[1] as Vector2).y) + rng.randf_range(-0.15, 0.15)
		add_child(boat)
		# Một phần ghe trôi qua lại giữa dòng, đổi chiều khi chạm bờ.
		if i % 4 == 1:
			boats.append({"node": boat, "dir": m[1], "speed": rng.randf_range(0.8, 1.6), "home": m[0], "range": rng.randf_range(25.0, 60.0), "s": 0.0, "sign": 1.0})


## Ghe gỗ (props3d.gd): ghe chở hàng có mui bạt hay mui lá, mắt ghe, máy đuôi tôm, bao hàng; xuồng nhỏ sơn xanh,
## sơn gỗ, có mái chèo. Dài ngắn khác nhau thì co giãn theo chiều dài.
func _boat(rng: RandomNumberGenerator, cargo: bool) -> Node3D:
	var boat := Node3D.new()
	var len := rng.randf_range(5.5, 8.0) if cargo else rng.randf_range(3.5, 4.8)
	var paint := Color(["3f6f9a", "2f5f3a", "8a7a5a", "3f6f9a"][rng.randi() % 4]) if cargo else Color(["4f7f5a", "3f6f8a", "9a6a42", "6a8a5a"][rng.randi() % 4])
	var mi := Props3D.instance(Props3D.boat(cargo), paint)
	mi.scale = Vector3(1, 1, len / float(Props3D.BOAT_LEN["cargo" if cargo else "small"]))
	boat.add_child(mi)
	return boat


func _update_boats(delta: float) -> void:
	for b in boats:
		var n: Node3D = b.node
		b["s"] = float(b.s) + float(b.sign) * float(b.speed) * delta
		var p: Vector2 = (b.home as Vector2) + (b.dir as Vector2) * float(b.s)
		if absf(float(b.s)) > float(b.range) or not _on_water(p):
			b["sign"] = -float(b.sign)
			b["s"] = clampf(float(b.s), -float(b.range), float(b.range))
			p = (b.home as Vector2) + (b.dir as Vector2) * float(b.s)
		n.position = Vector3(p.x, 0.02 + sin(Time.get_ticks_msec() / 700.0 + float(b.range)) * 0.04, p.y)


func _on_water(p: Vector2) -> bool:
	for w in city.data.water:
		if Geometry2D.is_point_in_polygon(p, w.poly):
			return true
	return false


## Chân cột đèn đường trên map thật (đám đông đi tránh).
var _lamp_spots: Array = []


func _build_real_lamps() -> void:
	var placed: Array[Vector2] = []
	for r in city.data.roads:
		if r.small or r.bridge or float(r.width) < 6.0:
			continue
		AreaBuilder._along(r.line, 34.0, func(p: Vector2, d: Vector2) -> void:
			if placed.size() >= 36 or placed.any(func(q: Vector2) -> bool: return q.distance_to(p) < 30.0):
				return
			var q: Vector2 = p + d.orthogonal() * (float(r.width) / 2.0 + 0.6)
			if city.walkable(q):
				placed.append(p)
				_lamp_spots.append(q)
				_lamp(_v3(q), atan2(d.x, d.y)))


## Dòng xe máy, ô tô chạy hai chiều trên đường lớn quanh chỗ của truyện (traffic.gd), người đi bộ trên đường nhỏ và vỉa
## hè.
func _build_real_traffic() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 808
	var small := []
	for r in city.data.roads:
		if r.bridge or r.tunnel or r.line.size() < 2:
			continue
		var l := 0.0
		for k in r.line.size() - 1:
			l += (r.line[k] as Vector2).distance_to(r.line[k + 1])
		if l < 30.0:
			continue
		if (r.small or float(r.width) < 6.0) and str(r.kind) not in ["steps"]:
			small.append({"poly": r.line, "len": l, "off": float(r.width) / 4.0})
	traffic = Traffic.new()
	add_child(traffic)
	# Điện thoại: bớt xe cho nhẹ máy.
	traffic.build(city.data.roads, area.dress.center, 300.0, AreaBuilder.BRIDGE_Y, 0.65 if ScreenFit.low_power else 1.0)
	# Đám đông: đông nhất quanh cổng chợ, bến xe, quán cơm; đi tránh gốc cây, cột điện, cột đèn.
	var hot: Array = []
	for spot in CROWD_SPOTS:
		if city.locs.has(spot[0]):
			hot.append([city.loc_door(spot[0]), spot[1], spot[2]])
	var stalls: Array = []
	for t in _stall_tables:
		if t.is_inside_tree():
			var out := t.global_basis.z
			stalls.append([Vector2(t.global_position.x, t.global_position.z), Vector2(out.x, out.z).normalized()])
	crowd = Crowd.new()
	add_child(crowd)
	crowd.build(area.dress, city.data.roads, area.dress.center, city.walkable, hot, stalls,
		area.tree_spots() + area.dress.pole_spots + _lamp_spots, 0.65 if ScreenFit.low_power else 1.0)
	small.shuffle()
	for k in mini(small.size(), 22):
		var pth: Dictionary = small[k].duplicate()
		pth["off"] = 0.0
		var w := _character("people", Color.from_hsv(rng.randf(), 0.3, 0.65), Color.from_hsv(rng.randf(), 0.2, 0.35), rng)
		var s0 := rng.randf() * float(pth.len)
		var p0 := _poly_at(pth.poly, s0, 0.0)
		w.position = Vector3(p0.x, 0, p0.y)
		add_child(w)
		walkers.append({"node": w, "goal": w.position, "speed": rng.randf_range(1.2, 2.0), "wait": rng.randf_range(0, 3), "path": pth, "s": s0})


## Điểm cách đầu đường gấp khúc s mét, lệch sang phải off mét (làn xe).
static func _poly_at(poly: PackedVector2Array, s: float, off: float) -> Vector2:
	var acc := 0.0
	for i in poly.size() - 1:
		var d := poly[i].distance_to(poly[i + 1])
		if acc + d >= s or i == poly.size() - 2:
			var dir := (poly[i + 1] - poly[i]) / maxf(d, 0.001)
			return poly[i].lerp(poly[i + 1], clampf((s - acc) / maxf(d, 0.001), 0.0, 1.0)) + dir.orthogonal() * off
		acc += d
	return poly[0]


func cam_offset() -> Vector3:
	if zoom > 1.0:
		return CAM_OFFSET.lerp(CAM_FAR, zoom - 1.0)
	return CAM_NEAR.lerp(CAM_OFFSET, zoom)


## Bật tắt nhìn toàn cảnh (nút kính lúp trên thanh trên cùng, cho máy cảm ứng): đang ở gần thì lùi ra xa hẳn, đang xa thì về góc chơi.
func toggle_overview() -> void:
	zoom = 0.3 if zoom > 1.0 else ZOOM_MAX


func _unhandled_input(event: InputEvent) -> void:
	if title_open():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		var up: bool = event.button_index == MOUSE_BUTTON_WHEEL_UP
		# Góc chơi nhích từng chút; quá góc chơi xa thì mỗi nấc lùi nhiều hơn, tới toàn cảnh.
		var step := 0.2 if zoom > 1.0 or (zoom == 1.0 and not up) else 0.08
		zoom = clampf(zoom + (-step if up else step), 0.0, ZOOM_MAX)
		return
	if _pinch(event):
		return
	if hud.blocking():
		return
	# Bấm (chạm) rồi nhả tại chỗ thì An đi tới đó; kéo đi hay đang chụm hai ngón thì thôi. Tọa độ sự kiện ở đây là điểm
	# ảnh thật của cửa sổ (không theo hệ số co giao diện).
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_at = event.position
		elif _press_at != null and not _pinched and not _panning and event.position.distance_to(_press_at) < 14.0 * ScreenFit.dpr:
			_pending_click = event.position
		if not event.pressed:
			_press_at = null
			_panning = false
	elif event is InputEventMouseMotion:
		# Kéo quá 14 điểm ảnh (chuột trái, một ngón) hay giữ chuột phải, chuột giữa mà kéo: nhìn quanh.
		var right: bool = event.button_mask & (MOUSE_BUTTON_MASK_RIGHT | MOUSE_BUTTON_MASK_MIDDLE) != 0
		var left: bool = event.button_mask & MOUSE_BUTTON_MASK_LEFT != 0 and _press_at != null and not _pinched
		if left and not _panning and event.position.distance_to(_press_at) >= 14.0 * ScreenFit.dpr:
			_panning = true
		if right or (left and _panning):
			_pan_by(event.relative)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		interact()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		recenter()


## Phím E, hay chạm vào lời nhắc ở giữa màn hình: lục thùng rác đang đứng cạnh, không thì vào địa điểm gần nhất.
func interact() -> void:
	if hud.blocking():
		return
	var bin := nearest_bin()
	if bin != "":
		_scavenge(bin)
		return
	# Đứng cạnh xe, gánh hàng rong: mua món đầu tiên mua được (phím 1–3 chọn món khác).
	if nearest_vendor() != "":
		hud.quick_first()
		return
	var near := nearest_location()
	if near != "":
		hud.open_location(near)


## Chụm, mở hai ngón trên màn cảm ứng để kéo máy quay gần, xa (như con lăn chuột). Trả true khi đã dùng sự kiện.
var _touches := {}
var _pinch_d0 := 0.0
var _pinch_z0 := 0.0
var _pinched := false
var _press_at = null


func _pinch(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		_pinch_d0 = 0.0
		if _touches.size() >= 2:
			_pinched = true
		elif _touches.is_empty():
			_pinched = false
		return _touches.size() >= 2
	if event is InputEventScreenDrag and _touches.has(event.index):
		_touches[event.index] = event.position
		if _touches.size() < 2:
			return false
		var pts: Array = _touches.values()
		var d := (pts[0] as Vector2).distance_to(pts[1])
		if _pinch_d0 <= 0.0:
			_pinch_d0 = d
			_pinch_z0 = zoom
		else:
			# Chụm lại (khoảng cách nhỏ đi) là lùi ra xa; mỗi 1,5 lần khoảng cách chừng một nấc góc chơi.
			zoom = clampf(_pinch_z0 + log(_pinch_d0 / maxf(d, 1.0)) * 1.4, 0.0, ZOOM_MAX)
		return true
	return false


## Mỗi khung hình (theo nhịp vẽ của màn, không theo nhịp vật lý cố định: màn 120 Hz hay khung hình dao động trên web
## thì An và máy quay vẫn đi đều, không nhảy cóc). Khung hình lâu bất thường (đổi tab) tính như 0,1 giây.
func _process(delta: float) -> void:
	delta = minf(delta, 0.1)
	if title_open():
		# Màn tiêu đề: phố vẫn sống (xe, thuyền) làm nền, An đứng yên.
		RenderingServer.global_shader_parameter_set("focus_depth", 0.0)
		_update_traffic(delta)
		if real:
			_update_boats(delta)
		return
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
		# Cần điều khiển ảo: trên màn là hướng bắc (máy quay nhìn về bắc, không xoay), đẩy nhẹ thì đi chậm hơn.
		if hud.joystick != null and hud.joystick.vector != Vector2.ZERO:
			var jv: Vector2 = hud.joystick.vector
			key_dir += Vector3(jv.x, 0, jv.y) / maxf(jv.length(), 0.001) * minf(jv.length() * 1.3, 1.0)
	_update_lane(delta)
	_update_ride()
	var step := Vector3.ZERO
	if key_dir != Vector3.ZERO:
		_target = null
		_target_loc = ""
		step = _slide(key_dir.limit_length(1.0) * _speed() * delta)
	elif _target != null:
		step = _follow_path(_speed() * delta)
	if step != Vector3.ZERO:
		player.position += step
		player.position.y = lerpf(player.position.y, city.ground_y(Vector2(player.position.x, player.position.z)), clampf(delta * 12.0, 0.0, 1.0))
		var run := sprinting()
		_add_walk(step.length() * (RIDE_TIME if _riding else (RainLayer.WADE_COST if _wading() else (RUN_TIME if run else 1.0))))
		if run:
			_run_meters += step.length()
			if _run_meters >= RUN_FATIGUE_M:
				_run_meters -= RUN_FATIGUE_M
				game.add_fatigue(1.0)
		_idle_t = 0.0
		if not _riding:
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
	_tick_idle(delta, step)

	# Đã kéo màn hình nhìn chỗ khác: An đi tiếp thì máy quay trôi về An.
	if step != Vector3.ZERO and not _panning:
		_pan = _pan.lerp(Vector3.ZERO, clampf(delta * 2.5, 0.0, 1.0))
	var cam_goal := player.position + _pan + cam_offset()
	camera.position = camera.position.lerp(cam_goal, clampf(delta * 4.0, 0.0, 1.0))
	camera.look_at(camera.position - cam_offset() + Vector3(0, lerpf(1.3, 1.0, minf(zoom, 1.0)), 0), Vector3.UP)
	# Nhìn toàn cảnh: bóng đổ phủ xa hơn (mờ hơn một chút), hai tầng bóng cho đỡ lần vẽ; góc chơi giữ bốn tầng để mặt
	# phẳng rộng (nhà hạ, sân) không có sọc khi nắng sớm chiều chiếu xiên.
	var far := clampf(zoom - 1.0, 0.0, 1.0)
	sun.directional_shadow_max_distance = lerpf(50.0, 180.0, far) if ScreenFit.low_power else lerpf(70.0, 240.0, far)
	var shadow_mode := DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if zoom > 1.3 or ScreenFit.light_shadows else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	if sun.directional_shadow_mode != shadow_mode:
		sun.directional_shadow_mode = shadow_mode
	_update_cutaway(delta)

	var near := nearest_location()
	var bin := nearest_bin()
	var vend := nearest_vendor()
	hud.set_prompt("bin:" + bin if bin != "" else ("vendor:" + vend if vend != "" else near))
	for id in door_rings:
		var ring: MeshInstance3D = door_rings[id]
		var pulse := 1.0 + (0.12 * sin(Time.get_ticks_msec() / 180.0) if id == near else 0.0)
		ring.scale = Vector3(pulse, 0.3, pulse)
	if hud.location_open() != "" and door_of(hud.location_open()).distance_to(player.position) > INTERACT_RANGE + 1.5:
		hud.close_location()

	_update_trail()
	_update_tags(delta)
	# Kéo màn hình nhìn chỗ khác thì thôi làm sẫm tiền cảnh (An không còn ở giữa khung).
	RenderingServer.global_shader_parameter_set("focus_depth", camera.position.distance_to(player.position + Vector3(0, 1, 0)) if zoom <= 1.0 and _pan.length() < 6.0 else 0.0)
	_update_traffic(delta)
	if real:
		_update_boats(delta)
	_update_delivery()
	_update_quests()
	if _rain != null and _rain.visible:
		_rain.position = player.position + Vector3(0, 11, 2)
	_check_day_end()


## Đồng hồ kết hợp: đứng chơi trên phố (không bảng nào mở, không đang làm) thì giờ trong game vẫn trôi chậm,
## idleMinutesPerSecond phút mỗi giây thật; đi bộ, làm việc tính giờ như cũ.
func _tick_idle(delta: float, step: Vector3) -> void:
	if step != Vector3.ZERO or not game.is_started() or game.is_over() or not game.s.queue.is_empty() \
			or hud.blocking() or hud._panel_open():
		return
	_idle_t += delta
	if _idle_t >= 5.0:
		game.walk(_idle_t * float(game.cfg.get("idleMinutesPerSecond", 0.0)) / 60.0)
		_idle_t = 0.0


## Kéo màn hình (chuột trái, phải hay giữa; một ngón trên màn cảm ứng) dời máy quay để nhìn quanh. rel là điểm ảnh.
func _pan_by(rel: Vector2) -> void:
	var off := cam_offset()
	var dist := off.length()
	var per_px := 2.0 * dist * tan(deg_to_rad(camera.fov) / 2.0) / maxf(get_viewport().get_visible_rect().size.y, 1.0)
	var pitch_sin := clampf(off.y / dist, 0.3, 1.0)
	_pan.x -= rel.x * per_px
	_pan.z -= rel.y * per_px / pitch_sin
	_pan = _pan.limit_length(PAN_MAX)


## Space: đưa máy quay về An ngay.
func recenter() -> void:
	_pan = Vector3.ZERO


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
	_make_trail()


# ---------------------------------------------------------------- dẫn đường

## Vệt chấm vàng trên mặt đường chỉ lối An đang đi; chấm nào An đi qua rồi thì tắt.
var _trail: MultiMeshInstance3D
var _trail_pts := PackedVector2Array()
const TRAIL_STEP := 2.2


func _make_trail() -> void:
	if _trail == null:
		_trail = MultiMeshInstance3D.new()
		_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var dot := CylinderMesh.new()
		dot.top_radius = 0.28
		dot.bottom_radius = 0.28
		dot.height = 0.02
		dot.radial_segments = 10
		dot.rings = 1
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.95, 0.76, 0.3, 0.85)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.no_depth_test = true
		dot.material = m
		mm.mesh = dot
		_trail.multimesh = mm
		add_child(_trail)
	# Chấm xếp từ đích ngược về An: số chấm còn hiện chính là số chấm phía trước.
	_trail_pts = PackedVector2Array()
	var carry := TRAIL_STEP
	for i in range(_path.size() - 1, 0, -1):
		var a := _path[i]
		var b := _path[i - 1]
		var l := a.distance_to(b)
		var s := carry
		while s < l:
			_trail_pts.append(a.lerp(b, s / l))
			s += TRAIL_STEP
		carry = s - l
	var mm := _trail.multimesh
	mm.instance_count = _trail_pts.size()
	for i in _trail_pts.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, _v3(_trail_pts[i], 0.21)))
	mm.visible_instance_count = _trail_pts.size()
	_trail.visible = true


func _update_trail() -> void:
	if _trail == null or not _trail.visible:
		return
	if _target == null:
		_trail.visible = false
		return
	var here := Vector2(player.position.x, player.position.z)
	var n := _trail.multimesh.visible_instance_count
	while n > 0 and _trail_pts[n - 1].distance_to(here) < 1.2:
		n -= 1
	# Chấm cuối (gần An nhất) đã bị vượt qua thì tắt luôn.
	while n > 1 and _trail_pts[n - 2].distance_to(here) < _trail_pts[n - 1].distance_to(_trail_pts[n - 2]):
		n -= 1
	_trail.multimesh.visible_instance_count = n


## Đường đang đi (còn lại phía trước An), để bản đồ vẽ.
func active_path() -> PackedVector2Array:
	if _target == null or _path_i >= _path.size():
		return PackedVector2Array()
	var out := PackedVector2Array([Vector2(player.position.x, player.position.z)])
	out.append_array(_path.slice(_path_i))
	return out


## Đường từ An tới một địa điểm và số phút đi bộ (giờ trong game), cho bản đồ lớn khi rê chuột.
var _preview_cache := {}


func route_preview(loc: String) -> Dictionary:
	var here := Vector2(player.position.x, player.position.z)
	var key := "%s|%d|%d" % [loc, roundi(here.x / 3.0), roundi(here.y / 3.0)]
	if not _preview_cache.has(key):
		_preview_cache.clear()
		var d: Vector3 = door_of(loc)
		var pts: PackedVector2Array = city.path(here, Vector2(d.x, d.z))
		var m := 0.0
		for i in range(1, pts.size()):
			m += pts[i - 1].distance_to(pts[i])
		_preview_cache[key] = {"path": pts, "meters": m, "minutes": m * float(game.cfg.get("walkHoursPerMeter", 0.0)) * 60.0}
	return _preview_cache[key]


## Đang nhìn toàn cảnh (zoom từ 1,3): nhà để nguyên, không hạ.
var _overview := false


## Nhà nào nằm giữa camera và An (phía nam, đủ cao để che theo góc nhìn hiện tại) thì ẩn đi.
## Map thật: nhà thật hạ dần thành khối thấp (AreaBuilder.update_cut); nhà của địa điểm cũng vậy, thay bằng khối
## cùng màu có mặt cắt sáng hạ thấp dần, tên địa điểm và người trước cửa vẫn hiện.
func _update_cutaway(delta := 0.0) -> void:
	var off := cam_offset()
	var k := off.z / maxf(off.y, 0.1)
	var px := player.position.x
	var pz := player.position.z
	if real:
		var here := Vector2(px, pz)
		# Nhìn toàn cảnh thì thôi hạ nhà: An nhỏ xíu, cả khu phố để nguyên như mô hình.
		var overview := zoom > 1.3
		if overview and not _overview:
			area.reset_cut()
		_overview = overview
		# Tia nhìn từ máy quay thật (kể cả khi đang kéo màn hình) tới chân An.
		var cam := camera.global_position
		if not overview:
			area.update_cut(cam, player.position, delta)
		for o in occluders:
			var top := float(o.h)
			var want := top if overview else minf(AreaBuilder.ray_cap(o.poly, top, cam, player.position), top)
			var cur := move_toward(float(o.cap), want, float(AreaBuilder.CUT.speed) * delta)
			o["cap"] = cur
			var low := cur < top - 0.05
			var node: Node3D = o.node
			if o.stand == null:
				# Cây (dừa): thu nhỏ dần, hạ hẳn thì ẩn.
				node.scale = Vector3.ONE * clampf((cur - AreaBuilder.CUT.stub) / (top - AreaBuilder.CUT.stub), 0.0, 1.0)
				node.visible = node.scale.x > 0.02
				continue
			# Nhà của địa điểm đứng chắn tia nhìn tới An: thay bằng khối cùng màu cắt ngang ở mức đang hạ (nền móng, tầng
			# trệt còn nguyên như nhà búp bê), mọc lại từ từ khi hết che.
			node.visible = not low
			var stand: Node3D = o.stand
			stand.visible = low
			if low:
				stand.scale.y = maxf(cur, 0.05)
		return
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
	var v := SPEED * (RIDE_SPEED if _riding else 1.0)
	if not _riding:
		if _lane:
			v *= LANE_SLOW
		elif sprinting():
			v *= SPRINT
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


## Đang chạy nhanh: giữ Shift hay bật nút Chạy, không đi xe, không ở trong ngõ, chưa quá mệt.
func sprinting() -> bool:
	if _riding or _lane or not game.is_started():
		return false
	if float(game.s.fatigue) >= float(game.cfg.fatigue.max):
		return false
	return Input.is_key_pressed(KEY_SHIFT) or (hud.joystick != null and hud.joystick.sprint)


## An đang trong ngõ hẹp (đường nhỏ dưới 5 m gần nhất): xét lại mỗi 0,3 giây.
func _update_lane(delta: float) -> void:
	_lane_t -= delta
	if _lane_t > 0.0:
		return
	_lane_t = 0.3
	if not real:
		_lane = false
		return
	var nr: Dictionary = city._nearest_road(Vector2(player.position.x, player.position.z), 1.0)
	_lane = not nr.is_empty() and bool(nr.road.small) and float(nr.road.width) < 5.0 and float(nr.d) < float(nr.road.width) / 2.0 + 2.0


## Có đơn giao hàng thì An lên xe máy (đội mũ bảo hiểm, ngồi tư thế lái, hai tay nắm tay lái); giao xong hay hủy đơn
## thì xuống xe.
func _update_ride() -> void:
	var want: bool = game.is_started() and not game.delivery_active().is_empty()
	if want == _riding or not player_body.has_method("sit"):
		return
	_riding = want
	if _ride_bike == null:
		_ride_bike = Props3D.instance(Props3D.motorbike("tay_ga", true), Color("b23a32"))
		player.add_child(_ride_bike)
	_ride_bike.visible = want
	player_body.position.z = Props3D.RIDER_Z if want else 0.0
	player_body.sit(want, Props3D.SEAT_H)
	if player_body.has_method("hold"):
		player_body.hold("ride" if want else "")
	if player_body.has_method("wear"):
		player_body.wear("helmet", want)
	_float_text("Lên xe đi giao" if want else "Dựng xe", Color("ffd27a"))


## Đồ trong tủ (túi mù) vừa thay: áo có thân người thật thì thay thân, mũ thì đội lên đầu (màu theo món).
func update_outfit() -> void:
	dress_player()
	if player_body == null or not player_body.has_method("wear"):
		return
	var hat_id: String = str(game.wardrobe().worn.get("mu", ""))
	var it: Dictionary = game.cloth(hat_id) if hat_id != "" else {}
	for kind in ["cap", "non_la"]:
		player_body.wear(kind, false)
	if it.has("hat") and not _riding:
		player_body.wear(str(it.hat), true, Color(str(it.get("color", "2f6fb0"))))


## Thay bộ quần áo của An (bảng Nhân vật): dựng lại người theo thân mặc bộ mới, giữ nguyên dáng đang ngồi xe.
func dress_player() -> void:
	if player_body == null or not player_body.has_method("wear"):
		return
	var look := Character.an_look(game)
	var cur = player_body.get("look")
	if not cur is Dictionary or str(cur.get("rb", "")) == str(look.rb):
		return
	var body := Character.make(look)
	player.remove_child(player_body)
	player_body.queue_free()
	player.add_child(body)
	player.move_child(body, 0)
	player_body = body
	if _riding:
		_riding = false
		_update_ride()


## An đang lội qua chỗ ngập ngày mưa.
func _wading() -> bool:
	return _rain_layer != null and _rain_layer.wading(Vector2(player.position.x, player.position.z))


## Vùng ngập hôm nay (rỗng nếu tạnh), cho bản đồ tô màu.
func flood_rects() -> Array:
	return [] if _rain_layer == null else _rain_layer.flood_rects()


## Xe, gánh hàng rong đang ra phố ở gần An (trong 2,8 m) có món bán trong config: id người bán, rỗng nếu không có.
func nearest_vendor() -> String:
	if life == null or not game.is_started():
		return ""
	var best := ""
	var best_d := 2.8
	for v in life.vendors:
		var node: Node3D = v.node
		if not node.visible:
			continue
		var d := Vector2(node.position.x - player.position.x, node.position.z - player.position.z).length()
		if d < best_d and not game.actions_at("vendor:" + str(v.id)).is_empty():
			best = str(v.id)
			best_d = d
	return best


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
	if door_of(home).distance_to(Vector3(player.position.x, 0, player.position.z)) <= INTERACT_RANGE + 1.0:
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
	if traffic != null:
		traffic.update(delta, Vector2(player.position.x, player.position.z))
	if crowd != null:
		crowd.update(delta, Vector2(player.position.x, player.position.z))
	for b in bikes:
		var n: Node3D = b.node
		var lane: Dictionary = b.lane
		if lane.has("poly"):
			# Map thật: chạy dọc đường gấp khúc, hết đường thì quay lại đầu.
			b["s"] = fposmod(float(b.s) + float(b.dir) * float(b.speed) * delta, float(lane.len))
			var at := _poly_at(lane.poly, float(b.s), float(lane.off) * float(b.dir))
			var ahead := _poly_at(lane.poly, fposmod(float(b.s) + float(b.dir) * 0.8, float(lane.len)), float(lane.off) * float(b.dir))
			n.position = Vector3(at.x, 0, at.y)
			if ahead.distance_to(at) > 0.01:
				n.rotation.y = atan2(ahead.x - at.x, ahead.y - at.y)
		elif lane.axis == "x":
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
			if pth.has("poly"):
				var g := _poly_at(pth.poly, clampf(float(w.get("s", 0.0)) + randf_range(-14, 14), 0.0, float(pth.len)), float(pth.off))
				w["s"] = clampf(float(w.get("s", 0.0)) + randf_range(-14, 14), 0.0, float(pth.len))
				w["goal"] = Vector3(g.x, 0, g.y)
			elif pth.axis == "x":
				w["goal"] = Vector3(clampf(n.position.x + randf_range(-14, 14), pth.lo, pth.hi), 0, pth.c)
			else:
				w["goal"] = Vector3(pth.c, 0, clampf(n.position.z + randf_range(-14, 14), pth.lo, pth.hi))
			w["wait"] = randf_range(0.5, 4.0)
		else:
			var stp: Vector3 = to.normalized() * w.speed * delta
			n.position += stp
			n.rotation.y = atan2(stp.x, stp.z)


## Chỗ một chiếc xe máy đang chạy gần An để phát tiếng còi; null nếu không có xe.
func horn_spot():
	if traffic != null:
		return traffic.near_vehicle(Vector2(player.position.x, player.position.z))
	if bikes.is_empty():
		return null
	return (bikes.pick_random().node as Node3D).position


func _on_changed() -> void:
	if not game.is_started():
		_last_money = -1
		_clear_ending_home()
		if title != null and not title.visible:
			title.show_page("title")
			_hold_for_title(true)
		return
	_sync_home()
	update_outfit()
	if game.is_over() and str(game.s.over.get("kind", "")) in ["full", "full2", "full3", "full4", "full5"] and _ending_home == null:
		_show_ending_home()
	elif not game.is_over() and _ending_home != null:
		# Chơi tiếp chương sau từ màn kết: dọn hình ảnh khép lại của chương trước.
		_clear_ending_home()
	var money := int(game.s.cash)
	if _last_money >= 0 and money != _last_money:
		_float_text(GameLogic.fmt_money(money - _last_money) if money < _last_money else "+" + GameLogic.fmt_money(money - _last_money),
			Color("7fe0a0") if money > _last_money else Color("ff8a7a"))
		audio.play("earn" if money > _last_money else "spend")
	_last_money = money
	# Sang ngày mới: An thức dậy trước cửa chỗ ở.
	if game.day() != _last_day:
		if _last_day != -1:
			# Ngủ ở nhà trọ giường tầng, quán net, ghế đá (game.sleep_away) thì sáng dậy ở đó.
			var woke: String = str(game.s.get("wake_at", ""))
			game.s.erase("wake_at")
			player.position = loc_point(woke if LOCATIONS.has(woke) else home, -1.5, 0.8)
			camera.position = player.position + cam_offset()
			_target = null
			_target_loc = ""
			_walk_meters = 0.0
		_last_day = game.day()
	_update_lighting(game.clock())


## Đèn lồng đỏ treo dưới một phần biển hiệu trước tiệm (phố cổ Hà Nội): một MultiMesh, ban ngày đỏ trầm, về đêm
## sáng rực (vật liệu phát sáng theo night).
var _lantern_mat: StandardMaterial3D
var _neon := []


## Vầng sáng đèn đường trên mặt đất về đêm: một tấm tròn cộng sáng (không tốn đèn thật) dưới mỗi cột đèn. Bộ dựng hình
## Compatibility chỉ cho mỗi lưới nhận tám đèn, mặt đường gộp thành ít lưới lớn nên đèn OmniLight không phủ hết.
var _pool_mat: ShaderMaterial
const POOL_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform float strength = 0.0;
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = 1.0 - smoothstep(0.0, 1.0, d);
	ALBEDO = vec3(1.0, 0.74, 0.42);
	ALPHA = a * a * strength;
}
"""


func _build_lamp_pools() -> void:
	# Dưới cột đèn; dọc phố mỗi 20 m xen kẽ hai bên (bóng đèn gắn cột điện, đèn hắt từ cửa tiệm); trong ngõ mỗi 15 m
	# một vầng giữa ngõ (bóng đèn treo tường).
	var spots: Array = []
	for l in lamps:
		spots.append((l as Node3D).position)
	if real:
		for r in city.data.roads:
			if r.bridge or r.tunnel or str(r.kind) in ["footway", "path", "steps"]:
				continue
			var hw := float(r.width) / 2.0
			var flip := [1.0]
			var off := 0.0 if r.small else hw + maxf(AreaBuilder.AreaData.sidewalk(r), 1.0) * 0.5
			AreaBuilder._along(r.line, 15.0 if r.small else 20.0, func(p: Vector2, d: Vector2) -> void:
				flip[0] = -flip[0]
				var q: Vector2 = p + d.orthogonal() * off * flip[0]
				if city.walkable(q):
					spots.append(Vector3(q.x, 0, q.y)))
	if spots.is_empty():
		return
	var q := PlaneMesh.new()
	q.size = Vector2(12.0, 12.0)
	var sh := Shader.new()
	sh.code = POOL_SHADER
	_pool_mat = ShaderMaterial.new()
	_pool_mat.shader = sh
	q.material = _pool_mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = q
	mm.instance_count = spots.size()
	for i in spots.size():
		var lp: Vector3 = spots[i]
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(lp.x, city.ground_y(Vector2(lp.x, lp.z)) + 0.09, lp.z)))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_lanterns() -> void:
	if area == null or area.dress == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	var spots: Array = []
	for sp in area.dress.lantern_spots:
		if rng.randf() < 0.3:
			spots.append(sp)
	if spots.size() > 260:
		spots = spots.slice(0, 260)
	if spots.is_empty():
		return
	var mesh := SphereMesh.new()
	mesh.radius = 0.2
	mesh.height = 0.36
	mesh.radial_segments = 10
	mesh.rings = 6
	_lantern_mat = StandardMaterial3D.new()
	_lantern_mat.albedo_color = Color("b3261e")
	_lantern_mat.emission_enabled = true
	_lantern_mat.emission = Color("ff4a2a")
	_lantern_mat.emission_energy_multiplier = 0.0
	_lantern_mat.roughness = 0.6
	mesh.material = _lantern_mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	var xforms := []
	for sp in spots:
		var n: Vector2 = sp.n
		var t := Vector2(n.y, -n.x)
		var base: Vector3 = sp.pos + Vector3(n.x, 0, n.y) * 0.5
		# Đôi đèn lồng hai đầu biển, hay một chiếc giữa biển.
		var offs := [-0.35, 0.35] if float(sp.w) > 2.2 else [0.0]
		for o in offs:
			xforms.append(Transform3D(Basis(), base + Vector3(t.x, 0, t.y) * float(sp.w) * float(o) + Vector3(0, -0.25, 0)))
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# Chữ neon: chừng ba phần mười biển hiệu (cố định theo chữ, chỗ) đổi màu phát sáng về đêm.
	var neon_cols := [Color("ff3d8b"), Color("34e0ff"), Color("ff5a36"), Color("7dff6a"), Color("ffd23f"), Color("c77dff")]
	for e in area.dress.sign_labels:
		var l: Label3D = e.label
		var h := absi(hash(l.text + str(l.position.snapped(Vector3.ONE))))
		if h % 10 < 3:
			_neon.append({"label": l, "day": e.day, "neon": neon_cols[h % neon_cols.size()]})


## Ánh sáng theo giờ trong game: sáng vàng ấm, trưa trong, chiều cam đậm, chạng vạng tím hồng, đêm xanh tím với vầng
## đèn đường vàng, cửa sổ sáng đèn, biển neon, đèn lồng đỏ.
func _update_lighting(hour: float) -> void:
	var t := clampf((hour - 6.0) / 16.0, 0.0, 1.0)
	var elevation := lerpf(24.0, 60.0, sin(t * PI))
	# Nắng chiếu từ phía sau dãy nhà ra đường: bóng nhà đổ dài trên vỉa hè như Nobody.
	sun.rotation_degrees = Vector3(-elevation, 115.0 + t * 130.0, 0)
	var warm := Color("ffcf96")
	var noon := Color("fff1dc")
	var dusk := Color("ff8a48")
	var night := Color("6a74b8")
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
	# Đêm: trăng yếu, để đèn đường, cửa sổ, neon nổi lên.
	var nf := clampf((hour - 17.8) / 1.7, 0.0, 1.0) if not rain else clampf((hour - 16.5) / 1.5, 0.0, 1.0)
	sun.light_energy = lerpf(1.1, 0.22, nf) * (0.35 if rain else 1.0)
	# Vùng bóng hắt sáng xanh nhạt của trời (ngày nắng), xám khi mưa; nền trời sau mô hình cùng màu trời theo giờ.
	var sky := Color("a9d4ee").lerp(Color("f6a36e"), clampf((hour - 16.5) / 2.0, 0.0, 1.0)).lerp(Color("2a2240"), clampf((hour - 18.3) / 1.2, 0.0, 1.0)).lerp(Color("121726"), clampf((hour - 19.5) / 1.5, 0.0, 1.0))
	if rain:
		sky = sky.lerp(Color("7d8794"), 0.75)
	env.background_color = sky
	env.ambient_light_color = c.lerp(Color("b9cde0"), 0.2 if rain else 0.5).lerp(Color("55609a"), nf * 0.7)
	env.ambient_light_energy = lerpf(0.75 if rain else 0.9, 0.62, nf)
	RenderingServer.global_shader_parameter_set("night", nf)
	# Quầng sáng (glow) chỉ bật lúc tối: đèn lồng, chữ neon, cửa sổ lóa nhẹ. Điện thoại tắt cho nhẹ.
	env.glow_enabled = nf > 0.05 and not ScreenFit.low_power
	env.glow_intensity = 0.9 * nf
	env.glow_hdr_threshold = 0.9
	env.glow_bloom = 0.05
	if _lantern_mat != null:
		_lantern_mat.emission_energy_multiplier = lerpf(0.25, 3.2, nf)
	if _pool_mat != null:
		_pool_mat.set_shader_parameter("strength", 0.7 * nf)
	for e in _neon:
		var l: Label3D = e.label
		var col: Color = (e.day as Color).lerp(Color(e.neon) * 2.4, nf)
		col.a = 1.0
		l.modulate = col
	var on := hour >= (16.0 if rain else 17.8)
	if crowd != null:
		crowd.set_time(hour, rain)
	for lamp in lamps:
		lamp.visible = on
		lamp.light_energy = lerpf(1.4, 3.4, nf) if on else 0.0
	_set_rain(rain)
	# Mưa: sương xám dày hơn, nhìn xa mờ hẳn; trời nắng chỉ hơi mờ xa cho có chiều sâu.
	env.fog_light_color = Color("8f98a3") if rain else sky.lerp(Color.WHITE, 0.25)
	env.fog_density = 0.0055 if rain else 0.0012
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

## Thông tin địa điểm; map thật thay lời tả theo địa hình của khu (file đặt truyện).
func location_info(id: String) -> Dictionary:
	var d: Dictionary = LOCATIONS[id]
	if real and city.story.get("descriptions", {}).has(id):
		d = d.duplicate()
		d["desc"] = str(city.story.descriptions[id])
	# Chương 2: xóm cũ đang dỡ làm kho, các chỗ khác có thể đổi lời tả (story2.locations); chương 3 đổi tiếp trên đó
	# (story3.locations).
	if game.is_started():
		for st in [game.story2, game.story3, game.story4, game.story5].slice(0, game.chapter() - 1):
			if st.get("locations", {}).has(id):
				d = d.duplicate()
				d.merge(st.locations[id], true)
	return d


func door_of(id: String) -> Vector3:
	return _v3(city.loc_door(id))


## Màu áo của nhân vật, để chấm trên bản đồ.
func npc_color(id: String) -> String:
	return str(npc_nodes.get(id, {}).get("color", "ffffff"))


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


## Tên người chỉ hiện khi An tới gần (NAME_RANGE m), tên địa điểm trong LOC_TAG_RANGE m: phố đỡ rối chữ như Nobody.
const NAME_RANGE := 7.0
const LOC_TAG_RANGE := 11.0
var _tag_t := 0.0


func _name_tag(text: String, pos: Vector3) -> Label3D:
	var l := _label3d(text, pos, 18)
	l.outline_size = 8
	l.add_to_group("near_tag")
	l.set_meta("range", NAME_RANGE)
	return l


func _update_tags(delta: float) -> void:
	_tag_t -= delta
	if _tag_t > 0.0:
		return
	_tag_t = 0.2
	for l in get_tree().get_nodes_in_group("near_tag"):
		var lb := l as Label3D
		if not lb.is_inside_tree():
			continue
		var d := Vector2(lb.global_position.x - player.position.x, lb.global_position.z - player.position.z).length()
		var on: bool = d < float(lb.get_meta("range", NAME_RANGE)) or zoom > 1.2
		if on != (lb.modulate.a > 0.5):
			lb.modulate.a = 1.0 if on else 0.0
			lb.outline_modulate.a = 0.9 if on else 0.0


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
		var look: Dictionary = Character.an_look(game) if key == "player" else Character.LOOKS.get(id, {})
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


## Xe máy nhìn về +z: theo models.json nếu có file mô hình (nằm dọc trục x, xoay lại), không thì xe dựng bằng code
## (props3d.gd), tay ga hay xe số.
func _bike(color: Color, rng: RandomNumberGenerator) -> Node3D:
	var root := Node3D.new()
	var m := models.spawn("bike", rng)
	if m == null:
		root.add_child(Props3D.instance(Props3D.motorbike("tay_ga" if rng.randf() < 0.62 else "xe_so"), color))
		return root
	m.rotation.y = -PI / 2.0
	root.add_child(m)
	return root


## Người lái đội mũ bảo hiểm ngồi trên xe, đôi khi chở thêm một người ngồi sau.
func _ride(bike: Node3D, rng: RandomNumberGenerator, back_chance := 0.25) -> void:
	for back in ([false, true] if rng.randf() < back_chance else [false]):
		var who := _character("people", Color.from_hsv(rng.randf(), 0.35, 0.6), Color("30323a"), rng, "helmet")
		var body: Node3D = who.get_child(0)
		who.position = Vector3(0, 0, Props3D.BACK_Z if back else Props3D.RIDER_Z)
		Models.play(body, "sit")
		if body.has_method("sit"):
			body.sit(true, Props3D.SEAT_H, back)
			body.animate(0.0, 0.0)
		else:
			who.position.y = 0.45
		bike.add_child(who)


func _float_text(text: String, color: Color) -> void:
	var l := _label3d(text, player.position + Vector3(0, 2.6, 0), 40)
	l.modulate = color
	add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position", l.position + Vector3(0, 1.4, 0), 1.6)
	tw.tween_property(l, "modulate:a", 0.0, 1.6).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)


# ---------------------------------------------------------------- chỗ ở, nhân vật chương 2

## Người nhà đứng trước cửa chỗ ở, theo thứ tự chỗ đứng; ông Ba là hàng xóm sát vách nên đứng xa nhất.
const HOME_NPCS := ["BA_TU", "LINH", "MA", "ONG_BA"]
## Người nhà đứng thành hàng bên trái cửa chỗ ở (phía An thức dậy), mét tính dọc mặt tiền: bên phải cửa là chỗ của
## cô chủ phòng, chú chủ nhà, dì Năm, và mặt tiền nhà thật hay có chỗ nhô ra che người đứng sát cửa.
const HOME_ALONG := -3.2
const HOME_STEP := -1.1
var _npc_home := HOME
## Chương đã thêm nhân vật mới (story2.npcs, story3.npcs, story4.npcs) tới đâu.
var _spawned_chapter := 1


## Chỗ ở đổi (chương 2, chương 3, hay dọn khỏi nhà dì Năm) thì người nhà dời theo; vào chương mới thì thêm nhân vật mới
## của chương đó (vào thẳng chương 3 thì thêm luôn nhân vật của chương 2).
func _sync_home() -> void:
	var h: String = game.home_loc()
	if not LOCATIONS.has(h):
		h = HOME
	home = h
	while _spawned_chapter < game.chapter():
		_spawned_chapter += 1
		for e in game.story_n(_spawned_chapter).get("npcs", []):
			_spawn_npc(e)
	if _npc_home == home:
		return
	_npc_home = home
	var slot := 0
	for id in HOME_NPCS:
		if npc_nodes.has(id):
			_place_npc(id, home, slot)
			slot += 1


## at_home: đứng trong hàng người nhà bên trái cửa; không thì đứng bên phải cửa như người của địa điểm đó.
func _place_npc(id: String, loc: String, slot: int, at_home := true) -> void:
	var n: Dictionary = npc_nodes[id]
	var node: Node3D = n.node
	if at_home:
		node.global_position = loc_point(loc, HOME_ALONG + slot * HOME_STEP, 0.55 + (slot % 2) * 0.35)
	else:
		node.global_position = loc_point(loc, 1.6 + slot * 1.7, 0.2 + (slot % 2) * 0.45)
	node.global_rotation.y = CityMap.rot_y(city.locs[loc].normal) + PI
	n["loc"] = loc
	(n.body as Node).set_meta("loc", loc)
	life.relocate(id, loc)


## Nhân vật mới của chương 2 (story2.npcs): đứng trước cửa địa điểm như nhân vật cũ; "when" là lúc có mặt.
func _spawn_npc(e: Dictionary) -> void:
	var id := str(e.id)
	if npc_nodes.has(id):
		return
	var loc: String = game.loc_of(str(e.loc))
	var npc := _character("npc." + id, Color(str(e.color)), Color("3a3a40"))
	add_child(npc)
	npc.add_child(_name_tag(str(e.name), Vector3(0, 2.0, 0)))
	var nb := StaticBody3D.new()
	nb.set_meta("loc", loc)
	var ncs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 1.9
	ncs.shape = cap
	ncs.position = Vector3(0, 0.95, 0)
	nb.add_child(ncs)
	npc.add_child(nb)
	npc_nodes[id] = {"node": npc, "body": nb, "name": str(e.name), "loc": loc, "color": str(e.color)}
	life.add_npc(id, e.get("when", {}))
	if str(e.loc) == "home":
		_npc_home = ""
	else:
		_place_npc(id, loc, int(e.get("slot", 1)), false)


# ---------------------------------------------------------------- ngày 30

## Hình ảnh khép lại: An đứng trước chỗ ở mới, bà Tư bên cạnh (Linh có mặt nếu không đi thực tập xa),
## chậu húng đặt dưới mái hiên. Hộp thoại kết thúc hiện đè lên cảnh này.
var _ending_home: Node3D


## Dọn cảnh khép lại trước chỗ ở; người trong cảnh đó phải ra khỏi danh sách đứng thở trước khi bị xóa.
func _clear_ending_home() -> void:
	if _ending_home == null:
		return
	for c in idlers.duplicate():
		if _ending_home.is_ancestor_of(c):
			idlers.erase(c)
	_ending_home.queue_free()
	_ending_home = null


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
	if game.chapter() >= 2:
		# Chương 2, chương 3: người nhà đã đứng sẵn trước chỗ ở (má thì tùy má đi hay ở), chỉ thêm chậu húng.
		loc = home
		family = []
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
	_quest_tick -= get_process_delta_time()
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
