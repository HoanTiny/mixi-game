extends Control
## Bản đồ nét để chọn khung cần dựng: đường chính, sông hồ quanh chỗ Nominatim tìm ra (lấy nhẹ từ Overpass),
## một khung vuông màu vàng kéo được (bấm giữ rồi kéo), con lăn chuột đổi cỡ khung trong giới hạn.

signal changed

const UI := preload("res://scripts/ui/ui_kit.gd")

var data
## Cạnh vùng xem trước (mét), tâm là chỗ tìm ra.
var span := 1600.0
var box_c := Vector2.ZERO
var box_size := 400.0
var min_size := 150.0
var max_size := 600.0
## Khung Nominatim trả về (mét), vẽ nét đứt cho biết ranh giới tên khu.
var place_rect := Rect2()
var note := ""
var _drag := false
var _drag_off := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(420, 420)


func reset(rect: Rect2, size_m: float) -> void:
	data = null
	box_c = Vector2.ZERO
	place_rect = rect
	box_size = clampf(size_m, min_size, max_size)
	note = "Đang tải đường nét quanh đây…"
	queue_redraw()


func _scale() -> float:
	return minf(size.x, size.y) / span


func to_screen(p: Vector2) -> Vector2:
	return size / 2.0 + p * _scale()


func to_meters(s: Vector2) -> Vector2:
	return (s - size / 2.0) / _scale()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			box_size = clampf(box_size + (-25.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 25.0), min_size, max_size)
			changed.emit()
			queue_redraw()
			accept_event()
			return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag = event.pressed
		if event.pressed:
			var m := to_meters(event.position)
			# Bấm trong khung thì kéo giữ nguyên chỗ cầm; bấm ngoài thì dời tâm khung tới đó.
			_drag_off = box_c - m if Rect2(box_c - Vector2.ONE * box_size / 2.0, Vector2.ONE * box_size).has_point(m) else Vector2.ZERO
			_move_to(m + _drag_off)
		accept_event()
	elif event is InputEventMouseMotion and _drag:
		_move_to(to_meters(event.position) + _drag_off)
		accept_event()


func _move_to(m: Vector2) -> void:
	var lim := span / 2.0 - box_size / 2.0
	box_c = Vector2(clampf(m.x, -lim, lim), clampf(m.y, -lim, lim))
	changed.emit()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("26292f"))
	var s := _scale()
	if data != null:
		for w in data.water:
			var pts := PackedVector2Array()
			for p in w.poly:
				pts.append(to_screen(p))
			if pts.size() >= 3 and Geometry2D.triangulate_polygon(pts).size() > 0:
				draw_colored_polygon(pts, Color("3f6f80"))
		for w in data.waterways:
			_line(w.line, maxf(float(w.width) * s, 1.5), Color("3f6f80"))
		for r in data.roads:
			var major := float(r.width) >= 8.0
			_line(r.line, maxf(float(r.width) * s * 0.8, 1.0 if not major else 2.0), Color("d8d2c4") if major else Color("8d877c"))
	if place_rect.size != Vector2.ZERO:
		var pr := Rect2(to_screen(place_rect.position), place_rect.size * s)
		_dashed_rect(pr, Color(1, 1, 1, 0.45))
	var br := Rect2(to_screen(box_c - Vector2.ONE * box_size / 2.0), Vector2.ONE * box_size * s)
	draw_rect(br, Color(0.95, 0.76, 0.3, 0.16))
	draw_rect(br, UI.GOLD, false, 2.0)
	var font := get_theme_default_font()
	draw_string(font, br.position + Vector2(6, 18), "%d × %d m" % [roundi(box_size), roundi(box_size)], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.GOLD)
	# Chỗ tìm ra, hướng bắc, thước tỉ lệ.
	draw_circle(to_screen(Vector2.ZERO), 4.0, Color("ff6b5a"))
	draw_string(font, Vector2(size.x - 34, 22), "B ↑", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI.HUD_TEXT)
	var bar := 200.0 * s
	draw_line(Vector2(12, size.y - 14), Vector2(12 + bar, size.y - 14), UI.HUD_TEXT, 2.0)
	draw_string(font, Vector2(12, size.y - 20), "200 m", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.HUD_TEXT)
	if note != "":
		draw_string(font, Vector2(12, 22), note, HORIZONTAL_ALIGNMENT_LEFT, size.x - 60, 13, UI.HUD_SOFT)


func _line(line: PackedVector2Array, w: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for p in line:
		pts.append(to_screen(p))
	if pts.size() >= 2:
		draw_polyline(pts, col, w, true)


func _dashed_rect(r: Rect2, col: Color) -> void:
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		draw_dashed_line(corners[i], corners[(i + 1) % 4], col, 1.5, 6.0)
