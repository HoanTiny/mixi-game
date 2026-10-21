extends Node3D
## Chế độ Dựng khu thật: gõ tên khu ở Việt Nam, chọn kết quả Nominatim, chỉnh khung trên bản đồ nét rồi bấm Dựng.
## Trình duyệt tự gọi thẳng Overpass (OSM) và Open Buildings (đọc theo byte), ghép nhà, dựng 3D để An đi dạo.
## Truyện 30 ngày vẫn ở phường An Hòa; đây là chế độ riêng, vào từ màn đầu.
## Bản web: thêm "?khu" vào địa chỉ để vào thẳng chế độ này.
## Thử không cần mạng ngoài: "-- --realmap-config=res://tests/realmap_local.json --realmap-auto=Khu Mẫu"
## (bản web: --realmap-config-json=<chuỗi JSON>), xem tests/realmap_test.gd.

const Geo := preload("res://scripts/realmap/geo.gd")
const Fetcher := preload("res://scripts/realmap/fetcher.gd")
const Fgb := preload("res://scripts/realmap/fgb_reader.gd")
const AreaData := preload("res://scripts/realmap/area_data.gd")
const AreaBuilder := preload("res://scripts/realmap/area_builder.gd")
const AreaPicker := preload("res://scripts/realmap/area_picker.gd")
const Character := preload("res://scripts/world/character.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")

const SPEED := 6.0
const CAM_FAR := Vector3(0, 30, 22)
const CAM_NEAR := Vector3(0, 7, 10)
const ATTRIBUTION := "Dữ liệu: © Những người đóng góp OpenStreetMap (ODbL) · Open Buildings: Google (CC BY 4.0) và Microsoft (ODbL), bản gộp của VIDA · Tìm tên: Nominatim"

var cfg: Dictionary = {}
var fetcher: Fetcher
var geo: Geo
var place: Dictionary = {}
var builder: Node3D
var player: Node3D
var camera: Camera3D
var zoom := 0.45
var busy := false
var _path := PackedVector2Array()
var _path_i := 0

var _ui: Control
var _menu: PanelContainer
var _query: LineEdit
var _results: VBoxContainer
var _picker: Control
var _status: Label
var _build_btn: Button
var _hud: PanelContainer
var _hud_text: Label
var _shot_dir := ""


func _ready() -> void:
	cfg = _load_cfg()
	fetcher = Fetcher.new(cfg)
	add_child(fetcher)
	fetcher.status.connect(func(t: String) -> void: _set_status(t))
	_environment()
	camera = Camera3D.new()
	camera.fov = 34
	camera.position = Vector3(0, 40, 30)
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	_build_ui()
	var auto := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--realmap-auto="):
			auto = a.substr(15)
		elif a.begins_with("--realmap-shot="):
			_shot_dir = a.substr(15)
	if auto != "":
		_query.text = auto
		_auto.call_deferred()


## data/realmap.json, đè thêm file cấu hình khác nếu có "--realmap-config=…" (máy chủ giả khi thử).
func _load_cfg() -> Dictionary:
	var c = JSON.parse_string(FileAccess.get_file_as_string("res://data/realmap.json"))
	var out: Dictionary = c if c is Dictionary else {}
	for a in OS.get_cmdline_user_args():
		var o = null
		if a.begins_with("--realmap-config="):
			o = JSON.parse_string(FileAccess.get_file_as_string(a.substr(17)))
		elif a.begins_with("--realmap-config-json="):
			# Bản web không đọc được file ngoài gói: truyền thẳng chuỗi JSON.
			o = JSON.parse_string(a.substr(22))
		if o is Dictionary:
			_deep_merge(out, o)
	return out


static func _deep_merge(a: Dictionary, b: Dictionary) -> void:
	for k in b:
		if a.get(k) is Dictionary and b[k] is Dictionary:
			_deep_merge(a[k], b[k])
		else:
			a[k] = b[k]


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("9fb3c4")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d6d2c8")
	env.ambient_light_energy = 0.42
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.95
	env.ssao_enabled = true
	env.ssao_radius = 1.4
	env.fog_enabled = true
	env.fog_light_color = Color("aeb6bd")
	env.fog_density = 0.0025
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 120.0
	sun.rotation_degrees = Vector3(-52, 150, 0)
	sun.light_color = Color("fff0dc")
	sun.light_energy = 0.62
	add_child(sun)


# ---------------------------------------------------------------- giao diện

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.theme = UI.make_theme()
	layer.add_child(_ui)
	_menu = PanelContainer.new()
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_theme_stylebox_override("panel", UI.box(Color(0.08, 0.09, 0.12, 0.96), Color(0, 0, 0, 0), 0, 24))
	_ui.add_child(_menu)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	_menu.add_child(row)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(430, 0)
	left.add_theme_constant_override("separation", 10)
	row.add_child(left)
	left.add_child(_hud_label("Dựng một khu thật", 26, UI.HUD_TEXT))
	left.add_child(_hud_label("Gõ tên khu ở Việt Nam (ví dụ: Khương Thượng, Đống Đa). Trình duyệt tự lấy nhà, đường, sông hồ, công viên, đình chùa từ OpenStreetMap, thêm đường viền nhà dò từ ảnh vệ tinh (Open Buildings), rồi dựng thành khu để An đi dạo. Không qua máy chủ nào khác.", 13, UI.HUD_SOFT))
	var q := HBoxContainer.new()
	left.add_child(q)
	_query = LineEdit.new()
	_query.placeholder_text = "Tên phường, phố, khu…"
	_query.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_query.text_submitted.connect(func(_t: String) -> void: _search())
	q.add_child(_query)
	var go := Button.new()
	go.text = "Tìm"
	go.pressed.connect(_search)
	q.add_child(go)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_results = VBoxContainer.new()
	_results.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_results)
	_status = _hud_label("", 13, UI.GOLD)
	left.add_child(_status)
	var back := Button.new()
	back.text = "Về màn chính"
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/world.tscn"))
	left.add_child(back)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	row.add_child(right)
	_picker = AreaPicker.new()
	_picker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var area: Dictionary = cfg.get("area", {})
	_picker.span = float(area.get("previewMeters", 1600))
	_picker.min_size = float(area.get("minMeters", 150))
	_picker.max_size = float(area.get("maxMeters", 600))
	_picker.box_size = float(area.get("defaultMeters", 400))
	_picker.note = "Tìm một khu để hiện bản đồ."
	right.add_child(_picker)
	right.add_child(_hud_label("Kéo khung vàng tới chỗ muốn dựng; con lăn chuột đổi cỡ khung (tối đa %d m)." % int(area.get("maxMeters", 600)), 12, UI.HUD_SOFT))
	_build_btn = Button.new()
	_build_btn.text = "Dựng khu này"
	_build_btn.disabled = true
	_build_btn.pressed.connect(_build_area)
	right.add_child(_build_btn)
	right.add_child(_hud_label(ATTRIBUTION, 11, UI.HUD_SOFT))
	# Bảng khi đang đi dạo.
	_hud = PanelContainer.new()
	_hud.add_theme_stylebox_override("panel", UI.box(UI.HUD_BG, Color(1, 1, 1, 0.12), 10, 14))
	_hud.position = Vector2(16, 16)
	_hud.visible = false
	_ui.add_child(_hud)
	var hv := VBoxContainer.new()
	hv.custom_minimum_size = Vector2(380, 0)
	_hud.add_child(hv)
	_hud_text = _hud_label("", 13, UI.HUD_TEXT)
	hv.add_child(_hud_text)
	hv.add_child(_hud_label("Chuột trái: đi tới chỗ bấm · WASD: đi · con lăn: gần xa", 12, UI.HUD_SOFT))
	var hb := HBoxContainer.new()
	hv.add_child(hb)
	var again := Button.new()
	again.text = "Chọn khu khác"
	again.pressed.connect(_back_to_menu)
	hb.add_child(again)
	var home := Button.new()
	home.text = "Về màn chính"
	home.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/world.tscn"))
	hb.add_child(home)
	hv.add_child(_hud_label(ATTRIBUTION, 10, UI.HUD_SOFT))


func _hud_label(t: String, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _set_status(t: String) -> void:
	_status.text = t
	if _hud.visible:
		return
	print("[realmap] ", t)


# ---------------------------------------------------------------- tìm và chọn khung

func _search() -> void:
	var q := _query.text.strip_edges()
	if q == "" or busy:
		return
	busy = true
	for c in _results.get_children():
		c.queue_free()
	var r: Dictionary = await fetcher.search(q)
	busy = false
	if str(r.error) != "":
		_set_status(str(r.error))
		return
	if (r.places as Array).is_empty():
		_set_status("Không tìm thấy \"%s\". Thử ghi thêm quận, thành phố." % q)
		return
	_set_status("Chọn một kết quả:")
	for p in r.places:
		var b := Button.new()
		b.text = str(p.name)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_pick.bind(p))
		_results.add_child(b)


func _pick(p: Dictionary) -> void:
	if busy:
		return
	place = p
	geo = Geo.new(float(p.lat), float(p.lon))
	var rect := Rect2()
	var size_m := float(cfg.get("area", {}).get("defaultMeters", 400))
	if (p.bbox as Array).size() == 4:
		var a := geo.to_local(float(p.bbox[2]), float(p.bbox[1]))
		var b := geo.to_local(float(p.bbox[3]), float(p.bbox[0]))
		rect = Rect2(a, Vector2.ZERO).expand(b)
		size_m = clampf(maxf(rect.size.x, rect.size.y), _picker.min_size, size_m)
	_picker.reset(rect, size_m)
	_build_btn.disabled = false
	busy = true
	var bb := geo.bbox_around(Vector2.ZERO, _picker.span)
	var r: Dictionary = await fetcher.overpass(AreaData.preview_query(bb))
	busy = false
	if r.json == null:
		_picker.note = "Chưa tải được đường nét (%s). Vẫn dựng được." % str(r.error)
	else:
		var d := AreaData.new(geo, cfg)
		d.parse_osm(r.json)
		_picker.data = d
		_picker.note = ""
		_set_status("Bản đồ nét từ %s. Kéo khung rồi bấm Dựng khu này." % Fetcher._host(str(r.server)))
	_picker.queue_redraw()


# ---------------------------------------------------------------- dựng

func _build_area() -> void:
	if busy or geo == null:
		return
	busy = true
	_build_btn.disabled = true
	var t0 := Time.get_ticks_msec()
	var center: Vector2 = _picker.box_c
	var size_m: float = _picker.box_size
	var bb := geo.bbox_around(center, size_m)
	# 1. OSM qua Overpass (nhiều máy, luật chờ 7 s).
	var r: Dictionary = await fetcher.overpass(AreaData.query(bb))
	if r.json == null:
		_set_status("Không lấy được dữ liệu OSM: %s" % str(r.error))
		busy = false
		_build_btn.disabled = false
		return
	var d := AreaData.new(geo, cfg)
	d.parse_osm(r.json)
	var osm_server := Fetcher._host(str(r.server))
	# 2. Open Buildings: đọc đúng phần byte của khung trong file của nước đó.
	var ob_note := ""
	var iso3 := str(cfg.get("iso3", {}).get(str(place.get("cc", "vn")), ""))
	var ob: Dictionary = cfg.get("openBuildings", {})
	if iso3 != "" and str(ob.get("url", "")) != "":
		var url := str(ob.url).replace("{iso3}", iso3)
		_set_status("Đang đọc Open Buildings (%s)…" % iso3)
		var reader := Fgb.new(url, fetcher, int(ob.get("mergeGapBytes", 65536)))
		if await reader.open():
			var feats: Array = await reader.read_bbox(float(bb[1]), float(bb[0]), float(bb[3]), float(bb[2]), int(ob.get("maxFeatures", 12000)))
			if reader.error == "":
				d.merge_open_buildings(feats)
				ob_note = "đọc %s trong file %s nhà" % [_kb(reader.bytes_read), _num(reader.count)]
			else:
				ob_note = "lỗi: " + reader.error
		else:
			ob_note = "không đọc được (%s)" % reader.error
	else:
		ob_note = "chưa có file cho nước này"
	# 3. Dựng.
	_set_status("Đang dựng %d căn nhà, %d đoạn đường…" % [d.buildings.size(), d.roads.size()])
	await get_tree().process_frame
	if builder != null:
		builder.queue_free()
	var tb := Time.get_ticks_msec()
	builder = AreaBuilder.new()
	add_child(builder)
	builder.build(d, Rect2(center - Vector2.ONE * size_m / 2.0, Vector2.ONE * size_m))
	print("[realmap] dựng 3D và lưới đi bộ: %d ms" % (Time.get_ticks_msec() - tb))
	_spawn_player(center)
	var s: Dictionary = d.stats
	_hud_text.text = "%s\nKhung %d × %d m · %d nhà OSM · %d nhà Open Buildings\nBỏ từ Open Buildings: %d tin cậy dưới %.1f · %d trùng nhà OSM · %d trên lòng đường · %d trên mặt nước\nOSM từ %s · Open Buildings: %s · %.1f giây" % [
		str(place.get("name", "")).get_slice(",", 0) + ", " + str(place.get("name", "")).get_slice(",", 1).strip_edges(),
		int(size_m), int(size_m), int(s.osm), int(s.ob), int(s.ob_low), float(ob.get("minConfidence", 0.7)), int(s.ob_dup), int(s.ob_road), int(s.ob_water),
		osm_server, ob_note, (Time.get_ticks_msec() - t0) / 1000.0]
	print("[realmap] ", _hud_text.text.replace("\n", " | "))
	_menu.visible = false
	_hud.visible = true
	busy = false
	if _shot_dir != "":
		_shots.call_deferred()


static func _kb(n: int) -> String:
	return "%.0f KB" % (n / 1024.0) if n < 1048576 else "%.1f MB" % (n / 1048576.0)


## 12345678 -> "12.345.678"
static func _num(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "." + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out


func _spawn_player(center: Vector2) -> void:
	if player == null:
		player = Node3D.new()
		player.add_child(Character.make(Character.LOOKS.get("AN", {})))
		var marker := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.55
		disc.bottom_radius = 0.55
		disc.height = 0.02
		marker.mesh = disc
		var mm := StandardMaterial3D.new()
		mm.albedo_color = Color(0.95, 0.76, 0.3, 0.6)
		mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mm.emission_enabled = true
		mm.emission = Color("f2c14e")
		marker.material_override = mm
		marker.position.y = 0.12
		player.add_child(marker)
		add_child(player)
	# Đứng trên con đường gần tâm khung nhất (ưu tiên đường có tên), không phải giữa khoảng sân trong khối nhà.
	var best := center
	var best_d := INF
	for r in builder.data.roads:
		if r.tunnel or r.bridge:
			continue
		for i in r.line.size() - 1:
			var a: Vector2 = r.line[i]
			var ab: Vector2 = r.line[i + 1] - a
			var q: Vector2 = a + ab * clampf((center - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
			var d := q.distance_to(center) + (0.0 if str(r.name) != "" else 15.0)
			if d < best_d:
				best_d = d
				best = q
	var p: Vector2 = builder.nearest_walkable(best)
	player.position = Vector3(p.x, 0, p.y)
	_path = PackedVector2Array()
	camera.position = player.position + _cam_offset()


func _back_to_menu() -> void:
	_hud.visible = false
	_menu.visible = true
	_build_btn.disabled = geo == null


# ---------------------------------------------------------------- đi dạo

func _cam_offset() -> Vector3:
	return CAM_NEAR.lerp(CAM_FAR, zoom)


func _unhandled_input(event: InputEvent) -> void:
	if not _hud.visible:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = clampf(zoom + (-0.08 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.08), 0.0, 1.0)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var from := camera.project_ray_origin(event.position)
			var dir := camera.project_ray_normal(event.position)
			if dir.y < -0.01:
				var hit := from + dir * (-from.y / dir.y)
				walk_to(Vector2(hit.x, hit.z))


func walk_to(p: Vector2) -> void:
	_path = builder.path(Vector2(player.position.x, player.position.z), p)
	_path_i = 1


func _physics_process(delta: float) -> void:
	if player == null or builder == null or not _hud.visible:
		return
	var key := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		key.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		key.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		key.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		key.y += 1
	var pos := Vector2(player.position.x, player.position.z)
	var step := Vector2.ZERO
	if key != Vector2.ZERO:
		_path = PackedVector2Array()
		var s := key.normalized() * SPEED * delta
		for t in [s, Vector2(s.x, 0), Vector2(0, s.y)]:
			if builder.walkable(pos + t):
				step = t
				break
	elif _path_i < _path.size():
		var goal := _path[_path_i]
		var d := pos.distance_to(goal)
		if d <= SPEED * delta:
			step = goal - pos
			_path_i += 1
		else:
			step = (goal - pos) / d * SPEED * delta
	var body: Node3D = player.get_child(0)
	if step != Vector2.ZERO:
		player.position += Vector3(step.x, 0, step.y)
		player.rotation.y = lerp_angle(player.rotation.y, atan2(step.x, step.y), 0.25)
	if body.has_method("animate"):
		body.animate(delta, 1.0 if step != Vector2.ZERO else 0.0)
	camera.position = camera.position.lerp(player.position + _cam_offset(), clampf(delta * 4.0, 0.0, 1.0))
	camera.look_at(camera.position - _cam_offset() + Vector3(0, 1.2, 0), Vector3.UP)
	builder.building_mat.set_shader_parameter("player_pos", player.position)
	builder.building_mat.set_shader_parameter("cam_pos", camera.global_position)


# ---------------------------------------------------------------- thử tự động

func _auto() -> void:
	await _search()
	if _results.get_child_count() == 0:
		print("[realmap] tự thử: không có kết quả")
		get_tree().quit(1)
		return
	var first: Button = _results.get_child(0)
	first.pressed.emit()
	while busy:
		await get_tree().process_frame
	await _build_area()


func _shots() -> void:
	for i in 30:
		await get_tree().process_frame
	_save(_shot_dir + "/rm_1_walk.png")
	zoom = 1.0
	for i in 60:
		await get_tree().physics_frame
	_save(_shot_dir + "/rm_2_far.png")
	# Đi bộ thử tới một góc khung để xem tìm đường quanh nhà.
	var target := Vector2(player.position.x, player.position.z) + Vector2(60, -40)
	walk_to(target)
	print("[realmap] đường đi ", _path.size(), " điểm")
	zoom = 0.3
	for i in 240:
		await get_tree().physics_frame
	_save(_shot_dir + "/rm_3_near.png")
	_menu.visible = true
	_hud.visible = false
	for i in 5:
		await get_tree().process_frame
	_save(_shot_dir + "/rm_0_menu.png")
	get_tree().quit()


func _save(p: String) -> void:
	get_viewport().get_texture().get_image().save_png(p)
	print("[realmap] saved ", p)
