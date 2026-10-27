extends Control
## Bản đồ phường An Hòa vẽ từ data/map.json: đường lớn, hẻm, rạch, cầu, các dãy nhà, chấm địa điểm,
## mũi tên vàng là An, dấu vàng là cảnh chính hôm nay, dấu xanh là chỗ cần tới của việc nhờ.
## Bản nhỏ nằm ở mép trên; bản lớn (big) phủ giữa màn hình, mở bằng phím M hoặc bấm vào bản nhỏ.
## Rê chuột lên chấm để xem tên, bấm chấm để An đi tới đó, bấm chỗ khác trên đường để đi tới chỗ đó.

const UI := preload("res://scripts/ui/ui_kit.gd")
const PAD := 10.0
const TOP := 22.0
const STREET_COLORS := {"duong": Color("8b8780"), "cho": Color("a08a70"), "bo_ke": Color("8f8b84"), "hem": Color("b9b2a3"),
	"hem_nho": Color("c9c0ad"), "cau": Color("a5927a"), "cau_nho": Color("b08a5e")}

var world
var big := false
## Bản lớn đang mở thì bản nhỏ bấm vào sẽ đóng nó lại.
var other: Control
var _hover := ""
var _redraw_t := 0.0
## Map thật: lớp tĩnh (kênh, nhà, đường) vẽ một lần, lớp động (An, dấu, tên) vẽ lại liên tục.
var _base: Control
var _over: Control


func _ready() -> void:
	custom_minimum_size = Vector2(900, 560) if big else Vector2(330, 186)
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(func() -> void:
		_hover = ""
		queue_redraw())
	if world.real:
		_base = Control.new()
		_over = Control.new()
		for c in [_base, _over]:
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
			c.set_anchors_preset(Control.PRESET_FULL_RECT)
			add_child(c)
		_base.draw.connect(_draw_real_static)
		_over.draw.connect(_draw_real_over)
		resized.connect(func() -> void: _base.queue_redraw())
	if big:
		visible = false
		set_anchors_preset(Control.PRESET_CENTER)
		# Nút đóng ở góc trên bên phải (máy cảm ứng không có phím M, Esc).
		var close := Button.new()
		close.text = "Đóng"
		close.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		close.offset_left = -78
		close.offset_top = 6
		close.offset_right = -8
		close.pressed.connect(func() -> void: visible = false)
		add_child(close)
		offset_left = -custom_minimum_size.x / 2.0
		offset_right = custom_minimum_size.x / 2.0
		offset_top = -custom_minimum_size.y / 2.0
		offset_bottom = custom_minimum_size.y / 2.0


func _process(delta: float) -> void:
	if not visible:
		return
	_redraw_t -= delta
	if _redraw_t <= 0.0:
		_redraw_t = 0.08
		if _over != null:
			_over.queue_redraw()
		else:
			queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if not big or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_M:
		toggle()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and visible:
		visible = false
		get_viewport().set_input_as_handled()


## Cỡ theo màn hình (ScreenFit, hud.gd gọi): bản nhỏ gọn lại trên điện thoại; bản lớn vừa khung màn.
func fit(compact: bool, view: Vector2) -> void:
	if big:
		var sz := Vector2(minf(900.0, view.x - 40.0), minf(560.0, view.y - 40.0))
		custom_minimum_size = sz
		offset_left = -sz.x / 2.0
		offset_right = sz.x / 2.0
		offset_top = -sz.y / 2.0
		offset_bottom = sz.y / 2.0
	else:
		custom_minimum_size = Vector2(230, 130) if compact else Vector2(330, 186)
	if _base != null:
		_base.queue_redraw()
	queue_redraw()


## Dòng chữ đầu bản đồ: máy có bàn phím ghi phím tắt, máy cảm ứng ghi chạm.
func _open_hint() -> String:
	return "chạm để mở bản đồ lớn" if ScreenFit.touch else "bấm để mở bản đồ lớn (M)"


func _go_hint() -> String:
	return "chạm một chỗ để đi tới" if ScreenFit.touch else "bấm một chỗ để đi tới · M hoặc Esc để đóng"


func toggle() -> void:
	if big:
		visible = not visible and not world.hud.blocking()
		queue_redraw()


# ---------------------------------------------------------------- toạ độ

func _scale() -> float:
	var b: Rect2 = world.city.bounds
	return minf((size.x - PAD * 2.0) / b.size.x, (size.y - TOP - PAD) / b.size.y)


func _origin() -> Vector2:
	var b: Rect2 = world.city.bounds
	var s := _scale()
	return Vector2((size.x - b.size.x * s) / 2.0, TOP + (size.y - TOP - PAD - b.size.y * s) / 2.0)


func to_map(p: Vector2) -> Vector2:
	return _origin() + (p - world.city.bounds.position) * _scale()


func to_world(m: Vector2) -> Vector2:
	return world.city.bounds.position + (m - _origin()) / _scale()


func _rect(r: Rect2) -> Rect2:
	return Rect2(to_map(r.position), r.size * _scale())


func _nearest(m: Vector2) -> String:
	var best := ""
	var best_d := 12.0 if big else 9.0
	for id in world.LOCATIONS:
		var d := to_map(world.city.loc_door(id)).distance_to(m)
		if d < best_d:
			best = id
			best_d = d
	return best


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := _nearest(event.position)
		if h != _hover:
			_hover = h
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		# Bản lớn tự làm HUD "đang chặn", nên chỉ xét hộp thoại.
		if world.hud.dialogs.visible or (not big and world.hud.blocking()):
			return
		if not big and other != null:
			# Bấm bản nhỏ: mở bản lớn để chọn chỗ đi cho dễ.
			other.toggle()
			return
		world.hud.close_location()
		if _hover != "":
			world.walk_to_location(_hover)
		else:
			var p: Vector2 = to_world(event.position)
			world.walk_to(Vector3(p.x, 0, p.y))
		visible = false


# ---------------------------------------------------------------- vẽ

func _draw() -> void:
	var city = world.city
	var font := get_theme_default_font()
	draw_style_box(UI.box(UI.HUD_BG if not big else Color(0.07, 0.08, 0.11, 0.94), Color(1, 1, 1, 0.12), 8, 0), Rect2(Vector2.ZERO, size))
	if world.real:
		return
	var b: Rect2 = city.bounds
	draw_rect(_rect(b), Color("3a3833"))
	# Ruộng phía nam và rạch.
	if city.streets.has("bo_nam"):
		var z0: float = city.streets.bo_nam.rect.end.y
		draw_rect(_rect(Rect2(b.position.x, z0, b.size.x, b.end.y - z0)), Color("3f5a33"))
	var hw: float = city.canal_w / 2.0
	var x := b.position.x
	var poly_top := PackedVector2Array()
	var poly_bot := PackedVector2Array()
	while x <= b.end.x + 0.01:
		var z: float = city.canal_z(x)
		poly_top.append(to_map(Vector2(x, z - hw)))
		poly_bot.append(to_map(Vector2(x, z + hw)))
		x += 6.0
	poly_bot.reverse()
	draw_colored_polygon(poly_top + poly_bot, Color("4f7f8f"))
	# Dãy nhà: khối phía trong tối, nhà mặt tiền sáng hơn, địa điểm tô màu riêng.
	for f in city.fillers:
		draw_rect(_rect(f.rect), Color("57534b"))
	for p in city.plots:
		if p.loc == "":
			draw_rect(_rect(city.footprint(p)), Color("6e695e"))
	for id in city.order:
		var st: Dictionary = city.streets[id]
		draw_rect(_rect(st.rect), STREET_COLORS.get(str(st.kind), Color("8b8780")))
	# Ngày mưa: chỗ ngập tô xanh nước.
	for r in world.flood_rects():
		draw_rect(_rect(r), Color(0.3, 0.55, 0.68, 0.75))
	for id in city.locs:
		var p: Dictionary = city.locs[id]
		var c := Color(world.LOCATIONS[id].color)
		draw_rect(_rect(city.footprint(p)), c.darkened(0.15))
	if big:
		_draw_names(font)
	# Dấu cảnh chính, việc nhờ và đơn giao hàng.
	for s in world.objective_spots():
		var mp := to_map(Vector2(s[0].x, s[0].z))
		var col: Color = s[1]
		var r := 6.0 if big else 4.5
		draw_colored_polygon(PackedVector2Array([mp + Vector2(0, -r), mp + Vector2(r, 0), mp + Vector2(0, r), mp + Vector2(-r, 0)]), col)
	var target = world.delivery_target()
	if target != null:
		var tp := to_map(Vector2(target.x, target.z))
		draw_circle(tp, 6.0, Color("2ecc71") if world.game.delivery_active().picked else Color("ff9f1c"))
		draw_arc(tp, 9.0, 0, TAU, 20, Color.WHITE, 1.5)
	var open: String = world.hud.location_open()
	var near: String = world.nearest_location()
	var placed: Array[Rect2] = []
	for id in world.LOCATIONS:
		var dp := to_map(city.loc_door(id))
		var r := (6.0 if big else 4.0) + (1.5 if id == _hover or id == open else 0.0)
		draw_circle(dp, r + 1.2, Color(0, 0, 0, 0.6))
		draw_circle(dp, r, Color(world.LOCATIONS[id].color).lightened(0.15))
		if id == open or id == near:
			draw_arc(dp, r + 3.0, 0, TAU, 20, UI.GOLD, 1.5)
		placed.append(Rect2(dp - Vector2(r, r), Vector2(r, r) * 2.0))
	if big:
		for id in world.LOCATIONS:
			_label(font, to_map(city.loc_door(id)), 6.0, str(world.LOCATIONS[id].name), placed)
	_draw_routes(self, font)
	if big:
		_draw_people(self, font)
	# An: mũi tên vàng chỉ theo hướng đang đi.
	var pp := to_map(Vector2(world.player.position.x, world.player.position.z))
	var a: float = world.player.rotation.y
	var fwd := Vector2(sin(a), cos(a))
	var side := Vector2(-fwd.y, fwd.x)
	var k := 1.5 if big else 1.0
	var tri := PackedVector2Array([pp + fwd * 9.0 * k, pp - fwd * 5.0 * k + side * 6.0 * k, pp - fwd * 5.0 * k - side * 6.0 * k])
	draw_colored_polygon(tri, UI.GOLD)
	draw_polyline(tri + PackedVector2Array([tri[0]]), Color(0, 0, 0, 0.7), 1.2)
	# Tiêu đề: tên chỗ đang rê chuột, hay hướng dẫn.
	var title := "Phố cổ Hà Nội · " + _open_hint() if not big else "Bản đồ phố cổ Hà Nội · " + _go_hint()
	var col := UI.HUD_SOFT
	var show_id := _hover if _hover != "" else open
	if show_id != "":
		title = str(world.LOCATIONS[show_id].name)
		col = UI.HUD_TEXT
	var fs := 15 if big else 12
	var w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, Vector2((size.x - w) / 2.0, 16 if not big else 17), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Bản lớn: tên đường dọc theo đường, tên rạch, chú thích.
func _draw_names(font: Font) -> void:
	var city = world.city
	for id in city.order:
		var st: Dictionary = city.streets[id]
		var name := str(st.display)
		if name == "":
			continue
		var r: Rect2 = _rect(st.rect)
		var fs := 12 if str(st.kind) in ["duong", "bo_ke", "cho"] else 11
		var tw := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if tw > maxf(r.size.x, r.size.y) - 6.0:
			continue
		if st.axis == "x":
			var pos := Vector2(r.get_center().x - tw / 2.0, r.get_center().y + fs * 0.35)
			if str(id) == "an_hoa":
				pos.x = r.position.x + r.size.x * 0.62
			elif str(id) == "bo_me":
				pos.x = r.position.x + r.size.x * 0.12
			_text(font, pos, name, fs, Color("f4efe1"))
		else:
			draw_set_transform(r.get_center() + Vector2(fs * 0.35, tw / 2.0), -PI / 2.0)
			_text(font, Vector2.ZERO, name, fs, Color("f4efe1"))
			draw_set_transform(Vector2.ZERO)
	var cx: float = city.bounds.position.x + 30.0
	_text(font, to_map(Vector2(cx, city.canal_z(cx) + 1.0)), str(city.data.canal.name), 12, Color("cfe6ee"))
	if city.streets.has("bo_nam"):
		var fz: float = city.streets.bo_nam.rect.end.y + 6.0
		_text(font, to_map(Vector2(city.bounds.position.x + 40.0, fz)), "Ruộng rau muống", 11, Color("bfd9a8"))
	_text(font, to_map(Vector2(-86.0, -62.0)) + Vector2(2, 12), "Khu công nghiệp", 11, Color("d9d4c8"))


## Tên địa điểm: thử bên phải chấm, rồi bên trái, trên, dưới; chọn chỗ không đè tên đã đặt.
func _label(font: Font, dp: Vector2, r: float, s: String, placed: Array[Rect2]) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var asc := font.get_ascent(13)
	var h := asc + font.get_descent(13)
	var tries := [Vector2(r + 4.0, 4.0), Vector2(-r - 4.0 - w, 4.0), Vector2(-w / 2.0, -r - 8.0), Vector2(-w / 2.0, r + 22.0)]
	var pos: Vector2 = dp + tries[0]
	for t in tries:
		var box := Rect2(dp + t - Vector2(0, asc), Vector2(w, h))
		if placed.all(func(q: Rect2) -> bool: return not q.intersects(box)):
			pos = dp + t
			break
	placed.append(Rect2(pos - Vector2(0, asc), Vector2(w, h)))
	_text(font, pos, s, 13, UI.HUD_TEXT)


func _text(font: Font, pos: Vector2, s: String, fs: int, col: Color) -> void:
	draw_string_outline(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.75))
	draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


# ---------------------------------------------------------------- map thật

func _pts(c: Control, poly: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in poly:
		out.append(to_map(p))
	return out


func _draw_real_static() -> void:
	var city = world.city
	var c := _base
	var b: Rect2 = city.bounds
	c.draw_rect(_rect(b), Color("3a3833"))
	for p in city.data.parks:
		var pts := _pts(c, p.poly)
		if Geometry2D.triangulate_polygon(pts).size() > 0:
			c.draw_colored_polygon(pts, Color("3f5a33"))
	for w in city.data.water:
		var pts := _pts(c, w.poly)
		if Geometry2D.triangulate_polygon(pts).size() > 0:
			c.draw_colored_polygon(pts, Color("4f7f8f"))
	var s := _scale()
	if big or s > 0.25:
		for bd in city.data.buildings:
			var pts := _pts(c, bd.poly)
			if pts.size() >= 3 and Geometry2D.triangulate_polygon(pts).size() > 0:
				c.draw_colored_polygon(pts, Color("5e5a52"))
	var roads: Array = city.data.roads.duplicate()
	roads.sort_custom(func(x, y) -> bool: return float(x.width) < float(y.width))
	for r in roads:
		var w := maxf(float(r.width) * s * (0.8 if big else 0.9), 1.0)
		var col := Color("a5927a") if r.bridge else (Color("8b8780") if not r.small else Color("b9b2a3"))
		if r.small and not big and s < 0.3:
			continue
		c.draw_polyline(_pts(c, r.line), col, w, w > 2.0)
	for id in city.locs:
		var p: Dictionary = city.locs[id]
		var n: Vector2 = p.normal
		var t := Vector2(n.y, -n.x)
		var cc: Vector2 = p.center
		var w := float(p.w)
		var d := float(p.d)
		var quad := PackedVector2Array([to_map(cc - t * w / 2.0), to_map(cc + t * w / 2.0), to_map(cc + t * w / 2.0 - n * d), to_map(cc - t * w / 2.0 - n * d)])
		c.draw_colored_polygon(quad, Color(world.LOCATIONS[id].color).darkened(0.1))
	if big:
		var font := get_theme_default_font()
		# Tên trong truyện: con kênh lớn nhất là rạch Bờ Me; vài đường chính có tên hư cấu.
		var biggest = null
		for w in city.data.water:
			if biggest == null or Geo_area(w.poly) > Geo_area(biggest.poly):
				biggest = w
		if biggest != null:
			_text_on(c, font, to_map(_centroid(biggest.poly)), "Sông Hồng", 13, Color("cfe6ee"))
		# Chỉ ghi tên đường lớn (không ghi tên hẻm), mỗi tên một lần, ở đoạn dài nhất.
		var best := {}
		for r in roads:
			var name: String = city.street_name(str(r.name))
			if name == "" or r.small or name.begins_with("Hẻm") or r.line.size() < 2:
				continue
			var l := 0.0
			for k in r.line.size() - 1:
				l += (r.line[k] as Vector2).distance_to(r.line[k + 1])
			if l > float(best.get(name, [0.0])[0]):
				best[name] = [l, r.line[r.line.size() / 2]]
		for name in best:
			if float(best[name][0]) > 60.0:
				_text_on(c, font, to_map(best[name][1]), name, 12, Color("f4efe1"))


func _draw_real_over() -> void:
	var city = world.city
	var c := _over
	var font := get_theme_default_font()
	for sp in world.objective_spots():
		var mp := to_map(Vector2(sp[0].x, sp[0].z))
		var r := 6.0 if big else 4.5
		c.draw_colored_polygon(PackedVector2Array([mp + Vector2(0, -r), mp + Vector2(r, 0), mp + Vector2(0, r), mp + Vector2(-r, 0)]), sp[1])
	var target = world.delivery_target()
	if target != null:
		var tp := to_map(Vector2(target.x, target.z))
		c.draw_circle(tp, 6.0, Color("2ecc71") if world.game.delivery_active().picked else Color("ff9f1c"))
		c.draw_arc(tp, 9.0, 0, TAU, 20, Color.WHITE, 1.5)
	var open: String = world.hud.location_open()
	var near: String = world.nearest_location()
	var placed: Array[Rect2] = []
	for id in city.locs:
		var dp := to_map(city.loc_door(id))
		var rr := (6.0 if big else 4.0) + (1.5 if id == _hover or id == open else 0.0)
		c.draw_circle(dp, rr + 1.2, Color(0, 0, 0, 0.6))
		c.draw_circle(dp, rr, Color(world.LOCATIONS[id].color).lightened(0.15))
		if id == open or id == near:
			c.draw_arc(dp, rr + 3.0, 0, TAU, 20, UI.GOLD, 1.5)
		placed.append(Rect2(dp - Vector2(rr, rr), Vector2(rr, rr) * 2.0))
	if big:
		for id in city.locs:
			_label_on(c, font, to_map(city.loc_door(id)), 6.0, str(world.LOCATIONS[id].name), placed)
	_draw_routes(c, font)
	if big:
		_draw_people(c, font)
	var pp := to_map(Vector2(world.player.position.x, world.player.position.z))
	var a: float = world.player.rotation.y
	var fwd := Vector2(sin(a), cos(a))
	var side := Vector2(-fwd.y, fwd.x)
	var k := 1.5 if big else 1.0
	var tri := PackedVector2Array([pp + fwd * 9.0 * k, pp - fwd * 5.0 * k + side * 6.0 * k, pp - fwd * 5.0 * k - side * 6.0 * k])
	c.draw_colored_polygon(tri, UI.GOLD)
	c.draw_polyline(tri + PackedVector2Array([tri[0]]), Color(0, 0, 0, 0.7), 1.2)
	var title := "%s · %s" % [city.display, _open_hint()] if not big else "Bản đồ %s · %s" % [city.display, _go_hint()]
	var col := UI.HUD_SOFT
	var show_id := _hover if _hover != "" else open
	if show_id != "":
		title = str(world.LOCATIONS[show_id].name)
		col = UI.HUD_TEXT
	var fs := 15 if big else 12
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	c.draw_string_outline(font, Vector2((size.x - tw) / 2.0, 16 if not big else 17), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.7))
	c.draw_string(font, Vector2((size.x - tw) / 2.0, 16 if not big else 17), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


static func Geo_area(poly: PackedVector2Array) -> float:
	var s := 0.0
	for i in poly.size():
		s += poly[i].x * poly[(i + 1) % poly.size()].y - poly[(i + 1) % poly.size()].x * poly[i].y
	return absf(s) / 2.0


static func _centroid(poly: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in poly:
		c += p
	return c / maxf(poly.size(), 1)


func _text_on(c: Control, font: Font, pos: Vector2, s: String, fs: int, col: Color) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	c.draw_string_outline(font, pos - Vector2(w / 2.0, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.75))
	c.draw_string(font, pos - Vector2(w / 2.0, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


func _label_on(c: Control, font: Font, dp: Vector2, r: float, s: String, placed: Array[Rect2]) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var asc := font.get_ascent(13)
	var h := asc + font.get_descent(13)
	var tries := [Vector2(r + 4.0, 4.0), Vector2(-r - 4.0 - w, 4.0), Vector2(-w / 2.0, -r - 8.0), Vector2(-w / 2.0, r + 22.0)]
	var pos: Vector2 = dp + tries[0]
	for t in tries:
		var box := Rect2(dp + t - Vector2(0, asc), Vector2(w, h))
		if placed.all(func(q: Rect2) -> bool: return not q.intersects(box)):
			pos = dp + t
			break
	placed.append(Rect2(pos - Vector2(0, asc), Vector2(w, h)))
	c.draw_string_outline(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.75))
	c.draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UI.HUD_TEXT)


## Bản lớn: chấm nhỏ cho từng người có tên đang ở đâu (kể cả đang đi đường), chữ cái đầu tên, tên khi rê chuột tới gần.
func _draw_people(c: Control, font: Font) -> void:
	if world.life == null:
		return
	var mouse := get_local_mouse_position()
	for id in world.life.npcs:
		var n: Dictionary = world.life.npcs[id]
		var node: Node3D = n.node
		if not node.visible:
			continue
		var p := to_map(Vector2(node.global_position.x, node.global_position.z))
		var col := Color(world.npc_color(id))
		c.draw_circle(p + Vector2(7, -7), 5.5, Color(0, 0, 0, 0.7))
		c.draw_circle(p + Vector2(7, -7), 4.5, col)
		var name := str(n.name)
		var initial := name.get_slice(" ", name.get_slice_count(" ") - 1).left(1)
		c.draw_string(font, p + Vector2(4.5, -3.5), initial, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)
		if p.distance_to(mouse) < 14.0:
			var wn := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			c.draw_string_outline(font, p + Vector2(14, -10), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color(0, 0, 0, 0.8))
			c.draw_string(font, p + Vector2(14, -10), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

## Đường đang đi: nét vàng đứt quãng; bản lớn rê chuột lên địa điểm: nét trắng mờ kèm số mét, số phút đi bộ.
func _draw_routes(c: Control, font: Font) -> void:
	var ap: PackedVector2Array = world.active_path()
	if ap.size() >= 2:
		var pts := PackedVector2Array()
		for p in ap:
			pts.append(to_map(p))
		for i in pts.size() - 1:
			c.draw_dashed_line(pts[i], pts[i + 1], UI.GOLD, 2.5 if big else 1.8, 6.0 if big else 4.0)
	if big and _hover != "":
		var r: Dictionary = world.route_preview(_hover)
		var pts := PackedVector2Array()
		for p in r.path:
			pts.append(to_map(p))
		if pts.size() >= 2:
			c.draw_polyline(pts, Color(0, 0, 0, 0.55), 5.0, true)
			c.draw_polyline(pts, Color("7fd3ff"), 2.6, true)
			var end := pts[pts.size() - 1]
			var t := "%d m · khoảng %d phút đi bộ" % [roundi(float(r.meters)), maxi(1, roundi(float(r.minutes)))]
			c.draw_string_outline(font, end + Vector2(10, 22), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color(0, 0, 0, 0.8))
			c.draw_string(font, end + Vector2(10, 22), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)

