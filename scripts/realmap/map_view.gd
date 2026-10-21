extends Control
## Bản đồ nền tối kiểu Tiny Map, vẽ từ dữ liệu OSM (Overpass) của vùng đang xem: đường, nhà, sông hồ, công viên.
## Kéo để dời, con lăn hay nút +/− để phóng. Hai công cụ vẽ vùng cần dựng: khung chữ nhật (bấm giữ rồi kéo)
## và đa giác (bấm từng đỉnh, bấm lại đỉnh đầu hay bấm đúp để khép). Nút thùng rác xóa vùng.
## Tọa độ bên trong là mét quanh một gốc cố định (geo); tìm chỗ xa hơn 30 km thì đổi gốc, xóa dữ liệu cũ.

signal need_data(bbox: Array, with_buildings: bool)
signal shape_changed
signal build_requested

const Geo := preload("res://scripts/realmap/geo.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")

const BG := Color("1d1f25")
const WATER := Color("1f3442")
const PARK := Color("22301f")
const BUILDING := Color("2b2e36")
const BUILDING_EDGE := Color("343843")
const ROAD := Color("3c4049")
const ROAD_MAJOR := Color("4a4f5a")
const ACCENT := Color("ff7a45")
## Vùng xem rộng hơn mức này (mét) thì không tải dữ liệu, chỉ nhắc phóng to.
const MAX_LOAD_SPAN := 4000.0
const BUILDINGS_SPAN := 1800.0

var geo: Geo
var center := Vector2.ZERO
## Mét trên mỗi điểm ảnh.
var mpp := 2.0
var tool := "pan"
## Vùng đã vẽ (mét); rỗng là chưa vẽ.
var shape := PackedVector2Array()
var max_km2 := 1.2
var marker := {}
var note := ""
var busy_loading := false

var _roads: Array = []
var _water: Array = []
var _parks: Array = []
var _buildings: Array = []
var _labels: Array = []
var _loaded: Array[Rect2] = []
var _loaded_bld: Array[Rect2] = []
var _drag := false
var _drag_from := Vector2.ZERO
var _rect_from := Vector2.ZERO
var _poly_open := false
var _hover := Vector2.ZERO
var _idle := 0.0
var _toolbar: HBoxContainer
var _zoom_bar: VBoxContainer
var _build_btn: Button
var _tool_btns := {}


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_CLICK
	if geo == null:
		geo = Geo.new(21.0285, 105.8542)
	# Thanh công cụ vẽ ở góc trên phải, nút phóng ở cạnh phải, nút Dựng ở góc dưới phải.
	_toolbar = HBoxContainer.new()
	_toolbar.add_theme_constant_override("separation", 4)
	add_child(_toolbar)
	for t in [["rect", "▭", "Vẽ khung chữ nhật"], ["poly", "⬠", "Vẽ đa giác: bấm từng đỉnh, bấm đúp để khép"], ["clear", "✕", "Xóa vùng"]]:
		var b := _icon_button(t[1], t[2])
		var id: String = t[0]
		b.pressed.connect(func() -> void: _on_tool(id))
		_toolbar.add_child(b)
		_tool_btns[id] = b
	_zoom_bar = VBoxContainer.new()
	_zoom_bar.add_theme_constant_override("separation", 2)
	add_child(_zoom_bar)
	for t in [["+", 0.6], ["−", 1.0 / 0.6]]:
		var b := _icon_button(t[0], "Phóng to" if t[0] == "+" else "Thu nhỏ")
		var k: float = t[1]
		b.pressed.connect(func() -> void: _zoom_at(size / 2.0, k))
		_zoom_bar.add_child(b)
	_build_btn = Button.new()
	_build_btn.text = "Dựng mô hình 3D"
	_build_btn.add_theme_stylebox_override("normal", UI.box(ACCENT, ACCENT, 8, 10))
	_build_btn.add_theme_stylebox_override("hover", UI.box(ACCENT.lightened(0.1), ACCENT, 8, 10))
	_build_btn.add_theme_stylebox_override("pressed", UI.box(ACCENT.darkened(0.1), ACCENT, 8, 10))
	_build_btn.add_theme_stylebox_override("disabled", UI.box(Color("3a3d45"), Color("3a3d45"), 8, 10))
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		_build_btn.add_theme_color_override(k, Color.WHITE)
	_build_btn.visible = false
	_build_btn.pressed.connect(func() -> void: build_requested.emit())
	add_child(_build_btn)
	resized.connect(_layout)
	_layout()


func _icon_button(text: String, tip: String) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.custom_minimum_size = Vector2(34, 34)
	b.add_theme_stylebox_override("normal", UI.box(Color(0.12, 0.13, 0.16, 0.92), Color(1, 1, 1, 0.08), 7, 4))
	b.add_theme_stylebox_override("hover", UI.box(Color(0.18, 0.19, 0.23, 0.95), Color(1, 1, 1, 0.16), 7, 4))
	b.add_theme_stylebox_override("pressed", UI.box(ACCENT, ACCENT, 7, 4))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, UI.HUD_TEXT)
	return b


func _layout() -> void:
	_toolbar.position = Vector2(size.x - 118, 12)
	_zoom_bar.position = Vector2(size.x - 46, size.y / 2.0 - 36)
	_build_btn.position = Vector2(size.x - 190, size.y - 56)
	_build_btn.size = Vector2(176, 42)


func _on_tool(id: String) -> void:
	if id == "clear":
		shape = PackedVector2Array()
		_poly_open = false
		tool = "pan"
	elif id == "none":
		tool = "pan"
	else:
		tool = "pan" if tool == id else id
		if tool == "poly":
			shape = PackedVector2Array()
			_poly_open = true
	for k in _tool_btns:
		(_tool_btns[k] as Button).add_theme_stylebox_override("normal", UI.box(ACCENT if k == tool else Color(0.12, 0.13, 0.16, 0.92), Color(1, 1, 1, 0.08), 7, 4))
	shape_changed.emit()
	_update_build_btn()
	queue_redraw()


# ---------------------------------------------------------------- tọa độ

func to_screen(m: Vector2) -> Vector2:
	return size / 2.0 + (m - center) / mpp


func to_meters(s: Vector2) -> Vector2:
	return center + (s - size / 2.0) * mpp


func view_rect() -> Rect2:
	return Rect2(to_meters(Vector2.ZERO), size * mpp)


## Bay tới một chỗ (kinh, vĩ độ), cạnh vùng nhìn span mét, cắm cờ có nhãn.
func fly_to(lon: float, lat: float, label: String, span := 1200.0) -> void:
	var p := geo.to_local(lon, lat)
	if p.length() > 30000.0:
		geo = Geo.new(lat, lon)
		_roads.clear()
		_water.clear()
		_parks.clear()
		_buildings.clear()
		_labels.clear()
		_loaded.clear()
		_loaded_bld.clear()
		shape = PackedVector2Array()
		p = Vector2.ZERO
	center = p
	mpp = span / maxf(minf(size.x, size.y), 200.0)
	marker = {"pos": p, "label": label}
	_idle = 0.6
	queue_redraw()


## Vùng đã vẽ theo kinh, vĩ độ.
func shape_lonlat() -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in shape:
		out.append(geo.to_lonlat(p))
	return out


func shape_km2() -> float:
	return absf(Geo.area(shape)) / 1e6 if shape.size() >= 3 and not _poly_open else 0.0


func _update_build_btn() -> void:
	var a := shape_km2()
	_build_btn.visible = a > 0.0
	_build_btn.disabled = a > max_km2
	_build_btn.text = "Dựng mô hình 3D" if a <= max_km2 else "Vùng quá lớn (tối đa %s km²)" % _km(max_km2)


static func _km(a: float) -> String:
	return ("%.2f" % a).replace(".", ",")


# ---------------------------------------------------------------- dữ liệu nền

## Thêm dữ liệu một vùng (area_data.gd đã đổi sang mét theo cùng gốc geo).
func add_data(d, bbox_m: Rect2, with_buildings: bool) -> void:
	_loaded.append(bbox_m)
	if with_buildings:
		_loaded_bld.append(bbox_m)
	for r in d.roads:
		_roads.append({"line": r.line, "w": float(r.width), "small": r.small})
	for w in d.water:
		_water.append(w.poly)
	for w in d.waterways:
		_roads.append({"line": w.line, "w": float(w.width), "water": true})
	for p in d.parks:
		_parks.append(p.poly)
	for b in d.buildings:
		_buildings.append(b.poly)
	for p in d.pois:
		_labels.append({"pos": p.pos, "name": p.name})
	queue_redraw()


func _process(delta: float) -> void:
	# Ngừng kéo, phóng một lúc thì xin dữ liệu cho phần chưa có.
	if _idle > 0.0:
		_idle -= delta
		if _idle <= 0.0:
			_request_data()


func _request_data() -> void:
	var v := view_rect()
	if maxf(v.size.x, v.size.y) > MAX_LOAD_SPAN:
		note = "Phóng to để xem đường phố"
		queue_redraw()
		return
	note = ""
	var with_b := maxf(v.size.x, v.size.y) <= BUILDINGS_SPAN
	var covered := false
	for r in (_loaded_bld if with_b else _loaded):
		if r.encloses(v):
			covered = true
	if covered or busy_loading:
		return
	var big := v.grow(maxf(v.size.x, v.size.y) * 0.25)
	var a := geo.to_lonlat(big.position)
	var b := geo.to_lonlat(big.end)
	need_data.emit([minf(a.y, b.y), minf(a.x, b.x), maxf(a.y, b.y), maxf(a.x, b.x)], with_b)


# ---------------------------------------------------------------- chuột

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_zoom_at(event.position, 0.85 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 0.85)
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var m := to_meters(event.position)
		if tool == "rect":
			if event.pressed:
				_rect_from = m
				shape = PackedVector2Array([m, m, m, m])
				_drag = true
			else:
				_drag = false
				if absf(Geo.area(shape)) < 400.0:
					shape = PackedVector2Array()
				tool = "pan"
				_on_tool("none")
		elif tool == "poly" and event.pressed:
			if event.double_click or (shape.size() >= 3 and to_screen(shape[0]).distance_to(event.position) < 12.0):
				_poly_open = false
				tool = "pan"
				_on_tool("none")
			else:
				shape.append(m)
		else:
			_drag = event.pressed
			_drag_from = event.position
		shape_changed.emit()
		_update_build_btn()
		queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion:
		_hover = event.position
		if _drag and tool == "rect":
			var m := to_meters(event.position)
			shape = PackedVector2Array([_rect_from, Vector2(m.x, _rect_from.y), m, Vector2(_rect_from.x, m.y)])
			shape_changed.emit()
			_update_build_btn()
		elif _drag:
			center -= event.relative * mpp
			_idle = 0.6
		queue_redraw()


func _zoom_at(screen: Vector2, k: float) -> void:
	var before := to_meters(screen)
	mpp = clampf(mpp * k, 0.15, 60.0)
	center += before - to_meters(screen)
	_idle = 0.6
	queue_redraw()


# ---------------------------------------------------------------- vẽ

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BG)
	var v := view_rect().grow(50.0)
	for p in _parks:
		_poly(p, PARK, v)
	for p in _water:
		_poly(p, WATER, v)
	if mpp < 3.5:
		for p in _buildings:
			_poly(p, BUILDING, v, BUILDING_EDGE if mpp < 1.2 else Color(0, 0, 0, 0))
	for r in _roads:
		var w := maxf(float(r.w) / mpp, 1.0)
		if r.get("water", false):
			_line(r.line, w, WATER, v)
		elif r.get("small", false):
			if mpp < 2.5:
				_line(r.line, maxf(w, 1.0), ROAD.darkened(0.15), v)
		else:
			_line(r.line, w, ROAD_MAJOR if float(r.w) >= 8.0 else ROAD, v)
	var font := get_theme_default_font()
	if mpp < 1.6:
		for l in _labels:
			if v.has_point(l.pos):
				_text(font, to_screen(l.pos) + Vector2(-20, 4), str(l.name), 11, Color("8e93a0"))
	# Vùng đã vẽ: tô cam trong suốt, viền cam, ghi diện tích.
	if shape.size() >= 2:
		var pts := PackedVector2Array()
		for p in shape:
			pts.append(to_screen(p))
		if shape.size() >= 3 and not _poly_open and Geometry2D.triangulate_polygon(pts).size() > 0:
			draw_colored_polygon(pts, Color(ACCENT.r, ACCENT.g, ACCENT.b, 0.22))
		var outline := pts.duplicate()
		if not _poly_open:
			outline.append(pts[0])
		elif tool == "poly":
			outline.append(_hover)
		draw_polyline(outline, ACCENT, 2.0, true)
		for p in pts:
			draw_circle(p, 4.0, ACCENT)
		var a := shape_km2()
		if a > 0.0:
			var top := pts[0]
			for p in pts:
				if p.y < top.y:
					top = p
			_text(font, top + Vector2(4, -8), "%s km²" % _km(a), 13, Color.WHITE if a <= max_km2 else Color("ff6b5a"))
	if not marker.is_empty():
		var mp := to_screen(marker.pos)
		draw_circle(mp, 7.0, Color.WHITE)
		draw_circle(mp, 5.0, ACCENT)
		var lw := font.get_string_size(str(marker.label), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		_text(font, mp + Vector2(-lw / 2.0, 22), str(marker.label), 12, Color.WHITE)
	# Thước tỉ lệ.
	var bar_m := _nice(120.0 * mpp)
	var bar := bar_m / mpp
	draw_line(Vector2(14, size.y - 16), Vector2(14 + bar, size.y - 16), Color("c9ccd4"), 2.0)
	_text(font, Vector2(14, size.y - 22), "%d m" % int(bar_m) if bar_m < 1000.0 else "%s km" % _km(bar_m / 1000.0), 11, Color("c9ccd4"))
	if note != "" or busy_loading:
		_text(font, Vector2(14, size.y - 40), "Đang tải đường phố…" if busy_loading else note, 12, Color("c9ccd4"))
	if tool == "poly":
		_text(font, Vector2(14, 64), "Bấm từng đỉnh; bấm lại đỉnh đầu hay bấm đúp để khép", 12, ACCENT)
	elif tool == "rect":
		_text(font, Vector2(14, 64), "Bấm giữ rồi kéo để vẽ khung", 12, ACCENT)


static func _nice(m: float) -> float:
	for s in [10.0, 20.0, 50.0, 100.0, 200.0, 500.0, 1000.0, 2000.0, 5000.0, 10000.0]:
		if s >= m:
			return s
	return 20000.0


func _poly(p: PackedVector2Array, col: Color, v: Rect2, edge := Color(0, 0, 0, 0)) -> void:
	var b := Geo.bounds(p)
	if not v.intersects(b) or b.size.x / mpp < 0.8:
		return
	var pts := PackedVector2Array()
	for q in p:
		pts.append(to_screen(q))
	if Geometry2D.triangulate_polygon(pts).size() > 0:
		draw_colored_polygon(pts, col)
	if edge.a > 0.0:
		pts.append(pts[0])
		draw_polyline(pts, edge, 1.0)


func _line(l: PackedVector2Array, w: float, col: Color, v: Rect2) -> void:
	if l.size() < 2 or not v.intersects(Geo.bounds(l)):
		return
	var pts := PackedVector2Array()
	for q in l:
		pts.append(to_screen(q))
	draw_polyline(pts, col, w, w > 2.0)


func _text(font: Font, pos: Vector2, s: String, fs: int, col: Color) -> void:
	draw_string_outline(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0.08, 0.09, 0.11, 0.9))
	draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
