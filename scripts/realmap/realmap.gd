extends Control
## Chế độ Dựng khu thật, giao diện kiểu Tiny Map: bên trái bản đồ nền tối (tìm địa điểm, vẽ khung hay đa giác),
## bên phải khung 3D. Bấm Dựng: trình duyệt tự gọi thẳng Overpass (OSM) và Open Buildings (đọc theo byte) cùng lúc,
## thẻ tiến độ bốn bước (OpenStreetMap, Open Buildings, Ghép dữ liệu, Dựng mô hình), rồi hiện mô hình thu nhỏ
## của đúng vùng đã vẽ: xoay, nghiêng, phóng; la bàn; tải về .glb; thả An vào đi dạo.
## Truyện 30 ngày vẫn ở phường An Hòa; đây là chế độ riêng, vào từ màn đầu hay "?khu" trên địa chỉ bản web.
## Thử không cần mạng ngoài: "-- --realmap-config=res://tests/realmap_local.json --realmap-auto=Khu Mẫu"
## (bản web: --realmap-config-json=<chuỗi JSON>), xem tests/realmap_test.gd.

const Geo := preload("res://scripts/realmap/geo.gd")
const Fetcher := preload("res://scripts/realmap/fetcher.gd")
const Fgb := preload("res://scripts/realmap/fgb_reader.gd")
const AreaData := preload("res://scripts/realmap/area_data.gd")
const AreaBuilder := preload("res://scripts/realmap/area_builder.gd")
const MapView := preload("res://scripts/realmap/map_view.gd")
const Character := preload("res://scripts/world/character.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")

const ACCENT := Color("ff7a45")
const PANEL := Color(0.09, 0.1, 0.12, 0.94)
const TEXT := Color("eceef2")
const SOFT := Color("9aa0ad")
const SPEED := 6.0
const WALK_CAM := Vector3(0, 13, 12)
const ATTRIBUTION := "© Những người đóng góp OpenStreetMap (ODbL) · Open Buildings: Google (CC BY 4.0), Microsoft (ODbL), bản gộp VIDA · Nominatim"
const DIRS := ["B", "BĐB", "ĐB", "ĐĐB", "Đ", "ĐĐN", "ĐN", "NĐN", "N", "NTN", "TN", "TTN", "T", "TTB", "TB", "BTB"]

var cfg: Dictionary = {}
var fetcher: Fetcher
var map: Control
var builder: Node3D
var busy := false
var place_name := ""

# Khung 3D.
var _vp: SubViewport
var _vpc: SubViewportContainer
var _world: Node3D
var camera: Camera3D
var _target := Vector3.ZERO
var _yaw := 20.0
var _pitch := 40.0
var _dist := 700.0
var _orbit_drag := 0
var player: Node3D
var walking := false
var _path := PackedVector2Array()
var _path_i := 0

# Lớp giao diện.
var _query: LineEdit
var _results: PanelContainer
var _results_box: VBoxContainer
var _split: HSplitContainer
var _empty: Label
var _card: PanelContainer
var _card_title: Label
var _card_pct: Label
var _card_time: Label
var _card_bar: ProgressBar
var _card_steps := {}
var _card_detail: Label
var _chip: PanelContainer
var _chip_text: Label
var _compass: PanelContainer
var _compass_text: Label
var _walk_btn: Button
var _view_tools: VBoxContainer
var _status: Label
var _shot_dir := ""
var _progress := {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = _dark_theme()
	cfg = _load_cfg()
	fetcher = Fetcher.new(cfg)
	add_child(fetcher)
	fetcher.status.connect(func(t: String) -> void:
		_status.text = t
		print("[realmap] ", t))
	_build_ui()
	_build_world()
	var auto := ""
	var example := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--realmap-auto="):
			auto = a.substr(15)
		elif a == "--realmap-example":
			example = true
		elif a.begins_with("--realmap-shot="):
			_shot_dir = a.substr(15)
	var ex: Dictionary = cfg.get("area", {}).get("example", {})
	map.fly_to.call_deferred(float(ex.get("lon", 105.8542)), float(ex.get("lat", 21.0285)), "", 1600.0)
	if auto != "":
		_query.text = auto
		_auto.call_deferred()
	elif example:
		_example.call_deferred()


## data/realmap.json, đè thêm "--realmap-config=<file>" hay "--realmap-config-json=<chuỗi>" (máy chủ giả khi thử).
func _load_cfg() -> Dictionary:
	var c = JSON.parse_string(FileAccess.get_file_as_string("res://data/realmap.json"))
	var out: Dictionary = c if c is Dictionary else {}
	for a in OS.get_cmdline_user_args():
		var o = null
		if a.begins_with("--realmap-config="):
			o = JSON.parse_string(FileAccess.get_file_as_string(a.substr(17)))
		elif a.begins_with("--realmap-config-json="):
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


# ---------------------------------------------------------------- giao diện

static func _dark_theme() -> Theme:
	var t := Theme.new()
	t.default_font = UI.text_font()
	t.default_font_size = 14
	t.set_color("font_color", "Label", TEXT)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(st, "Button", TEXT)
	t.set_color("font_disabled_color", "Button", SOFT)
	t.set_stylebox("normal", "Button", UI.box(Color(0.16, 0.17, 0.2, 0.95), Color(1, 1, 1, 0.08), 8, 8))
	t.set_stylebox("hover", "Button", UI.box(Color(0.21, 0.22, 0.26, 0.98), Color(1, 1, 1, 0.16), 8, 8))
	t.set_stylebox("pressed", "Button", UI.box(ACCENT.darkened(0.2), ACCENT, 8, 8))
	t.set_stylebox("disabled", "Button", UI.box(Color(0.14, 0.15, 0.17, 0.9), Color(0, 0, 0, 0), 8, 8))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("normal", "LineEdit", UI.box(Color(0.12, 0.13, 0.16, 0.96), Color(1, 1, 1, 0.1), 8, 10))
	t.set_stylebox("focus", "LineEdit", UI.box(Color(0.12, 0.13, 0.16, 0.96), ACCENT, 8, 10))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", SOFT)
	t.set_stylebox("panel", "PanelContainer", UI.box(PANEL, Color(1, 1, 1, 0.08), 10, 12))
	t.set_constant("separation", "HSplitContainer", 6)
	return t


func _label(t: String, fs: int, col: Color, wrap := false) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("121318")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.add_theme_constant_override("separation", 0)
	add_child(col)
	# Thanh trên: tên chế độ, ví dụ, về màn chính.
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", UI.box(Color("16171c"), Color(0, 0, 0, 0), 0, 8))
	col.add_child(top)
	var tr := HBoxContainer.new()
	tr.add_theme_constant_override("separation", 10)
	top.add_child(tr)
	tr.add_child(_label("  ◈ Dựng khu thật", 15, TEXT))
	tr.add_child(_label("Vẽ một khu ở Việt Nam, dựng thành mô hình 3D", 12, SOFT))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tr.add_child(sp)
	_status = _label("", 12, SOFT)
	tr.add_child(_status)
	var ex := Button.new()
	ex.text = "Ví dụ Khương Thượng"
	ex.pressed.connect(_example)
	tr.add_child(ex)
	var home := Button.new()
	home.text = "Về màn chính"
	home.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/world.tscn"))
	tr.add_child(home)
	# Hai nửa: bản đồ | 3D, kéo vạch giữa để đổi tỉ lệ.
	_split = HSplitContainer.new()
	_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_split)
	map = MapView.new()
	map.custom_minimum_size = Vector2(320, 0)
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map.size_flags_stretch_ratio = 1.15
	map.max_km2 = float(cfg.get("area", {}).get("maxKm2", 1.2))
	map.need_data.connect(_load_basemap)
	map.build_requested.connect(_build_area)
	_split.add_child(map)
	_build_search()
	var right := Control.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.clip_contents = true
	_split.add_child(right)
	_vpc = SubViewportContainer.new()
	_vpc.stretch = true
	_vpc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vpc.mouse_filter = Control.MOUSE_FILTER_STOP
	_vpc.gui_input.connect(_view_input)
	right.add_child(_vpc)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_2X
	_vpc.add_child(_vp)
	_empty = _label("Tìm một địa điểm, vẽ khung hay đa giác bên trái rồi bấm Dựng mô hình 3D.\nHoặc bấm Ví dụ Khương Thượng ở trên.", 14, Color("5d6470"))
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.set_anchors_preset(Control.PRESET_CENTER)
	_empty.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_empty.grow_vertical = Control.GROW_DIRECTION_BOTH
	right.add_child(_empty)
	_build_card(right)
	_build_view_overlay(right)
	var att := _label(ATTRIBUTION, 10, Color("6b7280"))
	att.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	att.position = Vector2(10, -20)
	att.grow_vertical = Control.GROW_DIRECTION_BEGIN
	right.add_child(att)


func _build_search() -> void:
	var box := HBoxContainer.new()
	box.position = Vector2(12, 12)
	box.custom_minimum_size = Vector2(330, 0)
	map.add_child(box)
	_query = LineEdit.new()
	_query.placeholder_text = "Tìm địa điểm (ví dụ: Hồ Hoàn Kiếm)"
	_query.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_query.clear_button_enabled = true
	_query.text_submitted.connect(func(_t: String) -> void: _search())
	box.add_child(_query)
	_results = PanelContainer.new()
	_results.position = Vector2(12, 56)
	_results.custom_minimum_size = Vector2(330, 0)
	_results.visible = false
	map.add_child(_results)
	_results_box = VBoxContainer.new()
	_results.add_child(_results_box)


func _build_card(parent: Control) -> void:
	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(300, 0)
	_card.set_anchors_preset(Control.PRESET_CENTER)
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	_card.visible = false
	parent.add_child(_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_card.add_child(v)
	_card_title = _label("", 12, SOFT)
	v.add_child(_card_title)
	var row := HBoxContainer.new()
	v.add_child(row)
	_card_pct = _label("0%", 40, TEXT)
	row.add_child(_card_pct)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	_card_time = _label("", 12, SOFT)
	_card_time.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(_card_time)
	_card_bar = ProgressBar.new()
	_card_bar.show_percentage = false
	_card_bar.custom_minimum_size = Vector2(0, 4)
	_card_bar.add_theme_stylebox_override("background", UI.box(Color(1, 1, 1, 0.08), Color(0, 0, 0, 0), 2, 0))
	_card_bar.add_theme_stylebox_override("fill", UI.box(ACCENT, Color(0, 0, 0, 0), 2, 0))
	v.add_child(_card_bar)
	for k in [["osm", "OpenStreetMap"], ["ob", "Open Buildings"], ["merge", "Ghép dữ liệu"], ["model", "Dựng mô hình"]]:
		var r := HBoxContainer.new()
		v.add_child(r)
		var icon := _label("○", 13, SOFT)
		icon.custom_minimum_size = Vector2(20, 0)
		r.add_child(icon)
		var name := _label(k[1], 13, SOFT)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(name)
		var val := _label("", 12, SOFT)
		r.add_child(val)
		_card_steps[k[0]] = {"icon": icon, "name": name, "val": val}
	var more := Button.new()
	more.text = "Chi tiết"
	more.flat = true
	more.alignment = HORIZONTAL_ALIGNMENT_LEFT
	more.add_theme_color_override("font_color", SOFT)
	v.add_child(more)
	_card_detail = _label("", 11, SOFT, true)
	_card_detail.visible = false
	v.add_child(_card_detail)
	more.pressed.connect(func() -> void: _card_detail.visible = not _card_detail.visible)


func _build_view_overlay(parent: Control) -> void:
	_chip = PanelContainer.new()
	_chip.position = Vector2(12, 12)
	_chip.visible = false
	parent.add_child(_chip)
	_chip_text = _label("", 12, TEXT)
	_chip.add_child(_chip_text)
	_compass = PanelContainer.new()
	_compass.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_compass.position = Vector2(-236, 12)
	_compass.visible = false
	parent.add_child(_compass)
	var ch := HBoxContainer.new()
	ch.add_theme_constant_override("separation", 8)
	_compass.add_child(ch)
	_compass_text = _label("", 12, TEXT)
	_compass_text.custom_minimum_size = Vector2(110, 0)
	ch.add_child(_compass_text)
	var north := Button.new()
	north.text = "B↑"
	north.tooltip_text = "Quay về hướng bắc"
	north.pressed.connect(func() -> void: _tween_view(0.0, _pitch))
	ch.add_child(north)
	var dl := Button.new()
	dl.text = "↓"
	dl.tooltip_text = "Tải mô hình về (.glb)"
	dl.pressed.connect(_download)
	ch.add_child(dl)
	_view_tools = VBoxContainer.new()
	_view_tools.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_view_tools.position = Vector2(-50, -110)
	_view_tools.add_theme_constant_override("separation", 4)
	_view_tools.visible = false
	parent.add_child(_view_tools)
	for t in [["+", "Lại gần"], ["−", "Ra xa"], ["⟲", "Xoay trái"], ["⟳", "Xoay phải"], ["⊞", "Toàn màn hình 3D"]]:
		var b := Button.new()
		b.text = t[0]
		b.tooltip_text = t[1]
		b.custom_minimum_size = Vector2(36, 36)
		var key: String = t[0]
		b.pressed.connect(func() -> void: _view_button(key))
		_view_tools.add_child(b)
	_walk_btn = Button.new()
	_walk_btn.text = "Thả An vào đi dạo"
	_walk_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_walk_btn.position = Vector2(-80, -78)
	_walk_btn.visible = false
	_walk_btn.pressed.connect(_toggle_walk)
	parent.add_child(_walk_btn)


# ---------------------------------------------------------------- thế giới 3D

func _build_world() -> void:
	_world = Node3D.new()
	_vp.add_child(_world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("c3cad2")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("dfe3ea")
	env.ambient_light_energy = 0.36
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.88
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.shadow_blur = 1.2
	sun.shadow_bias = 0.12
	sun.shadow_normal_bias = 2.0
	sun.directional_shadow_max_distance = 1400.0
	sun.rotation_degrees = Vector3(-55, 140, 0)
	sun.light_color = Color("fff1de")
	sun.light_energy = 0.52
	_world.add_child(sun)
	camera = Camera3D.new()
	camera.fov = 32
	camera.far = 6000.0
	_world.add_child(camera)
	_place_camera()


func _place_camera() -> void:
	if walking and player != null:
		return
	var p := deg_to_rad(_pitch)
	var y := deg_to_rad(_yaw)
	camera.position = _target + Vector3(sin(y) * cos(p), sin(p), cos(y) * cos(p)) * _dist
	camera.look_at(_target, Vector3.UP)
	_update_compass()


func _update_compass() -> void:
	var heading := fposmod(-_yaw, 360.0)
	_compass_text.text = "%d° %s\nnghiêng %d°" % [roundi(heading), DIRS[roundi(heading / 22.5) % 16], roundi(90.0 - _pitch)]


func _view_input(event: InputEvent) -> void:
	if builder == null:
		return
	if walking:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var from := camera.project_ray_origin(event.position)
			var dir := camera.project_ray_normal(event.position)
			if dir.y < -0.01:
				var hit := from + dir * (-from.y / dir.y)
				_walk_to(Vector2(hit.x, hit.z))
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_dist = clampf(_dist * (0.88 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 0.88), 40.0, 3000.0)
			_place_camera()
		elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_orbit_drag = event.button_index if event.pressed else 0
	elif event is InputEventMouseMotion and _orbit_drag != 0:
		if _orbit_drag == MOUSE_BUTTON_LEFT and not event.shift_pressed:
			_yaw -= event.relative.x * 0.35
			_pitch = clampf(_pitch + event.relative.y * 0.25, 12.0, 88.0)
		else:
			# Kéo chuột phải (hay Shift + kéo): dời tâm nhìn trên mặt đất.
			var y := deg_to_rad(_yaw)
			var right := Vector3(cos(y), 0, -sin(y))
			var fwd := Vector3(-sin(y), 0, -cos(y))
			_target += (-right * event.relative.x + fwd * event.relative.y) * _dist * 0.0016
		_place_camera()


func _view_button(key: String) -> void:
	match key:
		"+":
			_dist = clampf(_dist * 0.8, 40.0, 3000.0)
		"−":
			_dist = clampf(_dist * 1.25, 40.0, 3000.0)
		"⟲":
			_tween_view(_yaw + 45.0, _pitch)
			return
		"⟳":
			_tween_view(_yaw - 45.0, _pitch)
			return
		"⊞":
			map.visible = not map.visible
	_place_camera()


func _tween_view(yaw: float, pitch: float) -> void:
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		_yaw = lerpf(_yaw, yaw, t)
		_pitch = lerpf(_pitch, pitch, t)
		_place_camera(), 0.0, 1.0, 0.45)


# ---------------------------------------------------------------- bản đồ nền

func _load_basemap(bb: Array, with_buildings: bool) -> void:
	if map.busy_loading:
		return
	map.busy_loading = true
	map.queue_redraw()
	var r: Dictionary = await fetcher.overpass(AreaData.preview_query(bb, with_buildings))
	map.busy_loading = false
	if r.json == null:
		map.note = "Chưa tải được đường phố (%s)" % str(r.error).left(80)
		map.queue_redraw()
		return
	var d := AreaData.new(map.geo, cfg)
	d.parse_osm(r.json)
	var a: Vector2 = map.geo.to_local(float(bb[1]), float(bb[2]))
	var b: Vector2 = map.geo.to_local(float(bb[3]), float(bb[0]))
	map.add_data(d, Rect2(a, Vector2.ZERO).expand(b), with_buildings)
	_status.text = "Bản đồ nền từ %s" % Fetcher._host(str(r.server))


# ---------------------------------------------------------------- tìm

func _search() -> void:
	var q := _query.text.strip_edges()
	if q == "":
		return
	for c in _results_box.get_children():
		c.queue_free()
	_results.visible = true
	_results_box.add_child(_label("Đang tìm…", 12, SOFT))
	var r: Dictionary = await fetcher.search(q)
	for c in _results_box.get_children():
		c.queue_free()
	if str(r.error) != "" or (r.places as Array).is_empty():
		_results_box.add_child(_label(str(r.error) if str(r.error) != "" else "Không thấy \"%s\". Ghi thêm quận, thành phố." % q, 12, SOFT, true))
		return
	for p in r.places:
		var b := Button.new()
		b.text = str(p.name)
		b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(300, 0)
		b.pressed.connect(_pick.bind(p))
		_results_box.add_child(b)


func _pick(p: Dictionary) -> void:
	_results.visible = false
	var label := str(p.name).get_slice(",", 0)
	_query.text = label
	place_name = label
	var span := 900.0
	if (p.bbox as Array).size() == 4:
		var g := Geo.new(float(p.lat), float(p.lon))
		var a := g.to_local(float(p.bbox[2]), float(p.bbox[1]))
		var b := g.to_local(float(p.bbox[3]), float(p.bbox[0]))
		span = clampf(maxf(absf(b.x - a.x), absf(b.y - a.y)) * 1.6, 500.0, 3500.0)
	map.fly_to(float(p.lon), float(p.lat), label, span)


# ---------------------------------------------------------------- dựng

func _example() -> void:
	var ex: Dictionary = cfg.get("area", {}).get("example", {})
	if ex.is_empty() or busy:
		return
	place_name = str(ex.get("name", "Khương Thượng"))
	map.fly_to(float(ex.lon), float(ex.lat), place_name, 1300.0)
	var poly := PackedVector2Array()
	for q in ex.rect:
		poly.append(map.geo.to_local(float(q[0]), float(q[1])))
	map.shape = poly
	map._update_build_btn()
	map.queue_redraw()
	await _build_area()


func _set_step(k: String, state: String, val := "") -> void:
	var s: Dictionary = _card_steps[k]
	s.icon.text = {"wait": "○", "run": "◌", "done": "✔", "fail": "✕"}.get(state, "○")
	var col: Color = {"wait": SOFT, "run": TEXT, "done": Color("57c28a"), "fail": Color("ff6b5a")}.get(state, SOFT)
	s.icon.add_theme_color_override("font_color", col)
	s.name.add_theme_color_override("font_color", TEXT if state != "wait" else SOFT)
	if val != "":
		s.val.text = val


func _build_area() -> void:
	if busy or map.shape_km2() <= 0.0:
		return
	busy = true
	map._build_btn.disabled = true
	if walking:
		_toggle_walk()
	var t0 := Time.get_ticks_msec()
	var ll: PackedVector2Array = map.shape_lonlat()
	var km2: float = map.shape_km2()
	var name := place_name
	if name == "" or map.marker.is_empty() or not Geometry2D.is_point_in_polygon(map.marker.pos, map.shape):
		name = "Vùng mới"
	# Gốc tọa độ 3D đặt ở tâm vùng để số nhỏ, chính xác.
	var c := Geo.centroid(ll)
	var g := Geo.new(c.y, c.x)
	var clip := PackedVector2Array()
	var bb := [INF, INF, -INF, -INF]
	for q in ll:
		clip.append(g.to_local(q.x, q.y))
		bb = [minf(bb[0], q.y), minf(bb[1], q.x), maxf(bb[2], q.y), maxf(bb[3], q.x)]
	_card.visible = true
	_empty.visible = false
	_card_title.text = "Đang dựng · %s · %s km²" % [name, MapView._km(km2)]
	_card_detail.text = ""
	for k in _card_steps:
		_set_step(k, "wait", " ")
	_set_step("osm", "run")
	_set_step("ob", "run")
	_progress = {"osm": 0.0, "ob": 0.0, "merge": 0.0, "model": 0.0, "osm_done": false, "ob_done": false, "t0": t0}
	# 1 và 2 chạy cùng lúc: Overpass và Open Buildings.
	var job := {"osm": null, "ob": null}
	_job_osm(bb, job)
	_job_ob(bb, job, str(cfg.get("iso3", {}).get("vn", "VNM")))
	var shot_card := _shot_dir != ""
	while job.osm == null or job.ob == null:
		await get_tree().process_frame
		_tick_progress()
		if shot_card and _card_bar.value > 30.0:
			shot_card = false
			_save(_shot_dir + "/rm_0_progress.png")
	if job.osm.json == null:
		_set_step("osm", "fail", "lỗi")
		_card_title.text = "Không lấy được dữ liệu OSM"
		_card_detail.text = str(job.osm.error)
		_card_detail.visible = true
		busy = false
		map._build_btn.disabled = false
		return
	# 3. Ghép.
	_set_step("merge", "run")
	await get_tree().process_frame
	var d := AreaData.new(g, cfg)
	d.parse_osm(job.osm.json)
	var feats: Array = job.ob.feats
	d.merge_open_buildings(feats)
	var s: Dictionary = d.stats
	var dropped := int(s.ob_low) + int(s.ob_dup) + int(s.ob_road) + int(s.ob_water)
	_set_step("merge", "done", "%s nhà" % _fmt(int(s.ob)))
	_progress.merge = 1.0
	# 4. Dựng.
	_set_step("model", "run")
	_tick_progress()
	await get_tree().process_frame
	var tb := Time.get_ticks_msec()
	if builder != null:
		builder.queue_free()
	builder = AreaBuilder.new()
	_world.add_child(builder)
	builder.build(d, clip)
	var build_s := (Time.get_ticks_msec() - tb) / 1000.0
	_set_step("model", "done", "%.1f s" % build_s)
	_progress.model = 1.0
	_tick_progress()
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	var n: Dictionary = builder.counts
	_card_title.text = "Xong · %s · %s km²" % [name, MapView._km(km2)]
	_card_detail.text = "OSM từ %s: %s đối tượng, %d nhà vẽ tay.\nOpen Buildings: %s; giữ %d nhà, bỏ %d (tin cậy dưới %.1f: %d · trùng nhà OSM: %d · trên lòng đường: %d · trên mặt nước: %d)." % [
		Fetcher._host(str(job.osm.server)), _fmt((job.osm.json.elements as Array).size()), int(s.osm), str(job.ob.note),
		int(s.ob), dropped, float(cfg.get("openBuildings", {}).get("minConfidence", 0.7)), int(s.ob_low), int(s.ob_dup), int(s.ob_road), int(s.ob_water)]
	print("[realmap] ", _card_detail.text.replace("\n", " "))
	_chip_text.text = "%s\n%s km² · dựng xong trong %s s · %s nhà · %s cây · %s xe" % [name, MapView._km(km2), ("%.1f" % secs).replace(".", ","),
		_fmt(int(n.buildings)), _fmt(int(n.trees)), _fmt(int(n.cars))]
	print("[realmap] ", _chip_text.text.replace("\n", " · "))
	# Đặt camera nhìn chéo cả vùng.
	var r := Geo.bounds(clip)
	_target = Vector3(r.get_center().x, 0, r.get_center().y)
	_dist = maxf(r.size.x, r.size.y) * 1.55 + 80.0
	_yaw = 15.0
	_pitch = 42.0
	_place_camera()
	_chip.visible = true
	_compass.visible = true
	_view_tools.visible = true
	_walk_btn.visible = true
	busy = false
	map._build_btn.disabled = false
	await get_tree().create_timer(1.6).timeout
	_card.visible = false
	if _shot_dir != "":
		_shots()


## 12345 -> "12.345"
static func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "." + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out


func _job_osm(bb: Array, job: Dictionary) -> void:
	var r: Dictionary = await fetcher.overpass(AreaData.query(bb))
	_progress.osm_done = true
	_progress.osm = 1.0
	if r.json != null:
		_set_step("osm", "done", "%s đối tượng" % _fmt((r.json.elements as Array).size()))
	job["osm"] = r


func _job_ob(bb: Array, job: Dictionary, iso3: String) -> void:
	var ob: Dictionary = cfg.get("openBuildings", {})
	var out := {"feats": [], "note": ""}
	if str(ob.get("url", "")) == "":
		out.note = "chưa cấu hình"
	else:
		var reader := Fgb.new(str(ob.url).replace("{iso3}", iso3), fetcher, int(ob.get("mergeGapBytes", 65536)))
		_progress["reader"] = reader
		if await reader.open():
			out.feats = await reader.read_bbox(float(bb[1]), float(bb[0]), float(bb[3]), float(bb[2]), int(ob.get("maxFeatures", 12000)))
			out.note = "đọc %s trong file %s" % [_kb(reader.bytes_read), _gb(reader)] if reader.error == "" else "lỗi: " + reader.error
		else:
			out.note = "không đọc được (%s)" % reader.error
		_set_step("ob", "done" if reader.error == "" else "fail", "%s nhà" % _fmt((out.feats as Array).size()) if reader.error == "" else "lỗi")
	_progress.ob_done = true
	_progress.ob = 1.0
	job["ob"] = out


static func _kb(n: int) -> String:
	return "%d KB" % roundi(n / 1024.0) if n < 1048576 else ("%.1f MB" % (n / 1048576.0)).replace(".", ",")


static func _gb(reader) -> String:
	return "%s nhà" % _fmt(int(reader.count))


## Phần trăm: OSM 45%, Open Buildings 35% (tính theo tầng chỉ mục đã đi), ghép 10%, dựng 10%.
func _tick_progress() -> void:
	var t := (Time.get_ticks_msec() - int(_progress.get("t0", 0))) / 1000.0
	if not bool(_progress.get("osm_done", false)):
		_progress.osm = 0.92 * (1.0 - exp(-t / 9.0))
	if not bool(_progress.get("ob_done", false)) and _progress.has("reader"):
		_progress.ob = clampf(float(_progress.reader.progress), 0.0, 0.97)
	var pct := 45.0 * float(_progress.osm) + 35.0 * float(_progress.ob) + 10.0 * float(_progress.merge) + 10.0 * float(_progress.model)
	_card_pct.text = "%d%%" % int(pct)
	_card_bar.value = pct
	_card_time.text = ("%.1f s" % t).replace(".", ",")


# ---------------------------------------------------------------- tải mô hình

func _download() -> void:
	if builder == null:
		return
	# ShaderMaterial không xuất ra glTF được: tạm thay bằng vật liệu màu đỉnh.
	var swapped := []
	for c in builder.get_children():
		if c is MeshInstance3D and c.material_override is ShaderMaterial:
			var m := StandardMaterial3D.new()
			m.vertex_color_use_as_albedo = true
			swapped.append([c, c.material_override])
			c.material_override = m
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	doc.append_from_scene(builder, state)
	var buf := doc.generate_buffer(state)
	for s in swapped:
		s[0].material_override = s[1]
	var fname := "khu-" + place_name.to_lower().replace(" ", "-").left(40) + ".glb"
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(buf, fname, "model/gltf-binary")
	else:
		var path := "user://" + fname
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_buffer(buf)
		f.close()
		_status.text = "Đã lưu %s" % ProjectSettings.globalize_path(path)
		OS.shell_show_in_file_manager(ProjectSettings.globalize_path(path))


# ---------------------------------------------------------------- đi dạo

func _toggle_walk() -> void:
	walking = not walking
	_walk_btn.text = "✕ Thôi đi dạo" if walking else "Thả An vào đi dạo"
	builder.building_mat.set_shader_parameter("cut_on", walking)
	if walking:
		if player == null:
			player = Node3D.new()
			player.add_child(Character.make(Character.LOOKS.get("AN", {})))
			_world.add_child(player)
		player.visible = true
		var p: Vector2 = builder.nearest_walkable(_nearest_road(Vector2(_target.x, _target.z)))
		player.position = Vector3(p.x, 0, p.y)
		_path = PackedVector2Array()
	elif player != null:
		player.visible = false
		_place_camera()


## Điểm trên đường gần p nhất (ưu tiên đường có tên).
func _nearest_road(p: Vector2) -> Vector2:
	var best := p
	var best_d := INF
	for r in builder.data.roads:
		if r.tunnel or r.bridge:
			continue
		for i in r.line.size() - 1:
			var a: Vector2 = r.line[i]
			var ab: Vector2 = r.line[i + 1] - a
			var q: Vector2 = a + ab * clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
			var d := q.distance_to(p) + (0.0 if str(r.name) != "" else 15.0)
			if d < best_d:
				best_d = d
				best = q
	return best


func _walk_to(p: Vector2) -> void:
	_path = builder.path(Vector2(player.position.x, player.position.z), p)
	_path_i = 1


func _physics_process(delta: float) -> void:
	if not walking or player == null or builder == null:
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
	if _query.has_focus():
		key = Vector2.ZERO
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
	camera.position = camera.position.lerp(player.position + WALK_CAM, clampf(delta * 4.0, 0.0, 1.0))
	camera.look_at(camera.position - WALK_CAM + Vector3(0, 1.2, 0), Vector3.UP)
	builder.building_mat.set_shader_parameter("player_pos", player.position)
	builder.building_mat.set_shader_parameter("cam_pos", camera.global_position)


# ---------------------------------------------------------------- thử tự động

## Tìm tên, chọn kết quả đầu, vẽ khung vuông 500 m quanh đó rồi dựng.
func _auto() -> void:
	await _search()
	var first: Button = null
	for c in _results_box.get_children():
		if c is Button and not c.is_queued_for_deletion():
			first = c
			break
	if first == null:
		print("[realmap] tự thử: không có kết quả")
		return
	first.pressed.emit()
	var c: Vector2 = map.marker.pos
	var h := float(cfg.get("area", {}).get("autoMeters", 500.0)) / 2.0
	map.shape = PackedVector2Array([c + Vector2(-h, -h), c + Vector2(h, -h), c + Vector2(h, h), c + Vector2(-h, h)])
	map._update_build_btn()
	await _build_area()


func _shots() -> void:
	await get_tree().create_timer(1.0).timeout
	_save(_shot_dir + "/rm_1_model.png")
	_tween_view(_yaw - 60.0, 62.0)
	await get_tree().create_timer(1.2).timeout
	_save(_shot_dir + "/rm_2_turn.png")
	_dist *= 0.45
	_place_camera()
	await get_tree().create_timer(1.0).timeout
	_save(_shot_dir + "/rm_3_close.png")
	_toggle_walk()
	for i in 90:
		await get_tree().physics_frame
	_save(_shot_dir + "/rm_4_walk.png")
	get_tree().quit()


func _save(p: String) -> void:
	get_viewport().get_texture().get_image().save_png(p)
	print("[realmap] saved ", p)
