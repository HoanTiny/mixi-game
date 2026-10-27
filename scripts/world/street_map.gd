extends Control
## Bản đồ phường An Hòa vẽ từ data/map.json: đường lớn, hẻm, rạch, cầu, các dãy nhà, chấm địa điểm,
## mũi tên vàng là An, dấu vàng là cảnh chính hôm nay, dấu xanh là chỗ cần tới của việc nhờ.
## Bản nhỏ nằm ở mép trên; bản lớn (big) phủ giữa màn hình, mở bằng phím M hoặc bấm vào bản nhỏ.
## Rê chuột lên chấm để xem tên, bấm chấm để An đi tới đó, bấm chỗ khác trên đường để đi tới chỗ đó.

const UI := preload("res://scripts/ui/ui_kit.gd")
const Geo := preload("res://scripts/realmap/geo.gd")
const AreaData := preload("res://scripts/realmap/area_data.gd")
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
		clip_contents = true
		if world.real:
			# Nút phóng to, thu nhỏ ở góc dưới bên phải (máy cảm ứng không có con lăn).
			for i in 2:
				var zb := Button.new()
				zb.text = "+" if i == 0 else "−"
				zb.custom_minimum_size = Vector2(34, 30)
				zb.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
				zb.offset_left = -84 + i * 40
				zb.offset_right = zb.offset_left + 34
				zb.offset_top = -40
				zb.offset_bottom = -10
				var f := 1.4 if i == 0 else 1.0 / 1.4
				zb.pressed.connect(func() -> void: _zoom_at(_view_center(), f))
				add_child(zb)
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

## Bản lớn phóng to, thu nhỏ bằng con lăn (hay nút +/−), kéo để dời: _zoom 1 là vừa khít cả khu; _center là điểm của
## thế giới nằm giữa khung bản đồ.
const ZOOM_MIN := 1.0
const ZOOM_MAX := 5.0
var _zoom := 1.0
var _center := Vector2.INF
var _drag_from := Vector2.INF
var _dragged := false


func _fit() -> float:
	var b: Rect2 = world.city.bounds
	return minf((size.x - PAD * 2.0) / b.size.x, (size.y - TOP - PAD) / b.size.y)


func _scale() -> float:
	return _fit() * _zoom


func _view_center() -> Vector2:
	return Vector2(size.x / 2.0, TOP + (size.y - TOP - PAD) / 2.0)


func _world_center() -> Vector2:
	return world.city.bounds.get_center() if _center == Vector2.INF else _center


func _origin() -> Vector2:
	return _view_center() - (_world_center() - world.city.bounds.position) * _scale()


func to_map(p: Vector2) -> Vector2:
	return _origin() + (p - world.city.bounds.position) * _scale()


func to_world(m: Vector2) -> Vector2:
	return world.city.bounds.position + (m - _origin()) / _scale()


## Phóng quanh điểm m trên khung (giữ điểm thế giới dưới con trỏ đứng yên), rồi giữ khu phố không trôi ra ngoài.
func _zoom_at(m: Vector2, factor: float) -> void:
	var before := to_world(m)
	_zoom = clampf(_zoom * factor, ZOOM_MIN, ZOOM_MAX)
	_center = _world_center() + before - to_world(m)
	_clamp_center()
	_base.queue_redraw()


func _clamp_center() -> void:
	var b: Rect2 = world.city.bounds
	var half := (size - Vector2(PAD * 2.0, TOP + PAD)) / 2.0 / _scale()
	var c := _world_center()
	c.x = clampf(c.x, b.position.x + minf(half.x, b.size.x / 2.0), b.end.x - minf(half.x, b.size.x / 2.0))
	c.y = clampf(c.y, b.position.y + minf(half.y, b.size.y / 2.0), b.end.y - minf(half.y, b.size.y / 2.0))
	_center = c


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
	if big and world.real and event is InputEventMouseButton and event.pressed \
			and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_zoom_at(event.position, 1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2)
		accept_event()
		return
	if big and world.real and event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		if event.pressed:
			_drag_from = event.position
			_dragged = false
			if event.button_index != MOUSE_BUTTON_LEFT:
				accept_event()
				return
		else:
			_drag_from = Vector2.INF
			if _dragged or event.button_index != MOUSE_BUTTON_LEFT:
				_dragged = false
				accept_event()
				return
			event = event.duplicate()
			event.pressed = true
	if big and world.real and event is InputEventMouseMotion and _drag_from != Vector2.INF:
		if _dragged or event.position.distance_to(_drag_from) > 6.0:
			_dragged = true
			_center = _world_center() - event.relative / _scale()
			_clamp_center()
			_base.queue_redraw()
			accept_event()
			return
	if event is InputEventMouseButton and event.pressed and big and world.real and event.button_index == MOUSE_BUTTON_LEFT \
			and _drag_from != Vector2.INF:
		# Nhả chuột trái mà không kéo: coi như bấm (xử lý bên dưới khi nhả).
		accept_event()
		return
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

## Bản đồ minh họa (kiểu bản đồ game Nobody): đất vàng nâu, mái nhà phố cổ nâu đất, cam gạch có nóc mái; chợ cam có ô
## sạp; phố đêm Tạ Hiện tím hồng; vành công viên cây quanh hồ, Tháp Rùa, đền Ngọc Sơn, cầu Thê Húc đỏ; sông Hồng có bãi
## bồi; cầu Long Biên khung sắt gỉ có đường ray. Tên phố chữ hoa nhỏ nằm trong lòng đường; tên khu lớn; địa điểm là
## biểu tượng tròn theo loại (tên trên dải băng khi phóng gần hay rê chuột).
const LAND := Color("cbbb98")
const ROAD_FILL := Color("6f665b")
const LANE_FILL := Color("8a806f")
const ROAD_EDGE := Color("eadfc4")
const ROOFS := [Color("8c583a"), Color("a36a4f"), Color("735d4d"), Color("b07a52"), Color("9b6b4a")]
const MARKET := Color("d9822b")
const NIGHT := Color("6b2d5c")
const FRENCH := [Color("d9c9a3"), Color("e3d6b4"), Color("c9b48c")]
const WATER := Color("5b8fa8")
const PARK := Color("5f9a6a")
const TREE_A := Color("3a6b4c")
const TREE_B := Color("4d8c63")
const SAND := Color("dcc58f")
const RUST := Color("7a4a32")
## Vùng phố đêm Tạ Hiện – Lương Ngọc Quyến (tọa độ map hn_pho_co).
const NIGHT_ZONE := Rect2(0, -75, 118, 55)
## Loại địa điểm: biểu tượng, màu, tên trong bảng chú thích.
const CATS := {"home": ["Chỗ ở", Color("4f8fd6")], "food": ["Ăn uống", Color("e8a33c")], "work": ["Việc làm", Color("5aa36b")],
	"fun": ["Giải trí", Color("c04f9a")], "bus": ["Bến xe", Color("2fa3a3")], "service": ["Dịch vụ", Color("8a6ad0")],
	"shop": ["Mua sắm", Color("d0507a")]}
const LOC_CAT := {"xom_bo_me": "home", "hem_dua": "home", "cau_tre": "home", "nha_di_nam": "home", "com_hanh": "food",
	"cho_cau_nho": "work", "tiem_sau": "work", "ben_can": "fun", "ben_xe_6": "bus", "bai_boc_vac": "work", "xe_tho": "work",
	"nha_tro_giuong": "home", "quan_net": "fun", "ho_guom": "fun", "cam_do": "service", "ve_so": "service",
	"shop_ao": "shop", "bi_a": "fun"}
## Tên khu lớn hiện ở mọi mức phóng; tên nhỏ (đền, tháp) chỉ khi phóng từ 2.
const SMALL_AREAS := ["THÁP RÙA", "ĐỀN NGỌC SƠN"]


func _pts(c: Control, poly: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in poly:
		out.append(to_map(p))
	return out


func _poly(c: Control, pts: PackedVector2Array, col: Color) -> void:
	if pts.size() >= 3 and Geometry2D.triangulate_polygon(pts).size() > 0:
		c.draw_colored_polygon(pts, col)


func _draw_real_static() -> void:
	var city = world.city
	var c := _base
	var s := _scale()
	c.draw_rect(_rect(city.bounds), LAND)
	var landmarks: Array = city.story.get("landmarks", [])
	# Bãi cỏ, công viên, quảng trường, bãi bồi.
	for p in city.data.parks:
		var col := PARK
		match str(p.kind):
			"sand", "beach":
				col = SAND
			"square", "parking":
				col = Color("d8ccb0")
			"grass":
				col = Color("8fb07a")
		_poly(c, _pts(c, p.poly), col)
	var o := _organic()
	var detail := s > 0.55
	# Sông, hồ: bờ cong méo tự nhiên, viền bờ sáng như nét vẽ tay; bãi cát lồi lõm ven sông; quanh hồ một vòng đường dạo.
	for wp in o.water:
		var pts := _pts(c, wp.p)
		_poly(c, pts, WATER)
		c.draw_polyline(pts + PackedVector2Array([pts[0]]), Color("9cc4d4"), maxf(1.5, 1.2 * s), true)
		if wp.lake:
			for ring in Geometry2D.offset_polygon(wp.p, 3.5):
				var rp := _pts(c, ring)
				c.draw_polyline(rp + PackedVector2Array([rp[0]]), Color("efe3c6"), maxf(2.0, 2.2 * s), true)
	for sb in o.sand:
		var pts := _pts(c, sb)
		_poly(c, pts, SAND)
		c.draw_polyline(pts + PackedVector2Array([pts[0]]), SAND.darkened(0.18), 1.0, true)
	# Nhà: đa giác méo, cắt thành nhiều căn to nhỏ khác nhau; bóng đổ lệch xuống dưới phải, rồi mái (màu rải ngẫu
	# nhiên, gờ mái, nóc), viền sẫm nham nhở như nét cọ.
	var sh := Vector2(1.0, 1.25) * s * 0.9
	for bd in o.bld:
		_poly(c, _pts_off(bd.p, sh), Color(0.16, 0.1, 0.06, 0.38))
	for bd in o.bld:
		var pts := _pts(c, bd.p)
		_poly(c, pts, bd.c)
		c.draw_polyline(pts + PackedVector2Array([pts[0]]), (bd.c as Color).darkened(0.5), 1.2 if detail else 1.0, true)
		if bd.kind == "market":
			_stalls(c, bd.p, bd.c)
		elif detail:
			for seg in bd.roof:
				c.draw_line(to_map(seg[0]), to_map(seg[1]), seg[2], 1.0, true)
	# Chợ Long Biên (lô địa điểm): mái cam có ô sạp.
	if city.locs.has("cho_cau_nho"):
		var q := _loc_quad("cho_cau_nho")
		_poly(c, _pts(c, q), MARKET)
		_stalls(c, q, MARKET)
	# Ngõ ngách: đường nứt hẹp ngoằn ngoèo xuyên vào giữa các khối nhà, có ngõ cụt.
	if detail:
		for al in o.alleys:
			var pts := _pts(c, al)
			c.draw_polyline(pts, Color("5a4e40"), maxf(2.2, 2.0 * s) + 1.5, true)
			c.draw_polyline(pts, Color("8f8474"), maxf(1.6, 2.0 * s), true)
	# Đường: lòng đường phình ra thắt lại, lượn nhẹ; đầu đường bo tròn nên chỗ giao nhau không vuông thành sắc cạnh.
	var roads: Array = city.data.roads.duplicate()
	roads.sort_custom(func(x, y) -> bool: return float(x.width) < float(y.width))
	var strips: Array = o.roads
	strips.sort_custom(func(x, y) -> bool: return float(x.r.width) < float(y.r.width))
	for pass_i in 2:
		for st in strips:
			var r: Dictionary = st.r
			var w := _road_px(r) + ((3.0 if not r.small else 2.0) if pass_i == 0 else 0.0)
			var col: Color = ROAD_EDGE if pass_i == 0 else (LANE_FILL if r.small else ROAD_FILL)
			var strip := _strip_px(st.l, st.f, w)
			_poly(c, strip, col)
			for e in [st.l[0], st.l[st.l.size() - 1]]:
				c.draw_circle(to_map(e), w / 2.0, col)
		if pass_i == 0:
			# Chỗ giao nhau của đường lớn: vạt góc thành khoảng rộng tròn.
			for j in o.joints:
				c.draw_circle(to_map(j[0]), j[1] * s * 0.5 + 3.0, ROAD_EDGE)
		else:
			for j in o.joints:
				c.draw_circle(to_map(j[0]), j[1] * s * 0.5, ROAD_FILL)
	# Cây: từng cụm ven đường, trong vườn hoa, xen giữa khe nhà; mỗi tán một cỡ, một sắc, viền tối, chấm sáng.
	for t in o.trees:
		var tp := to_map(t[0])
		var tr := maxf(1.2, 2.0 * s) * float(t[1])
		c.draw_circle(tp + Vector2(0.5, 0.8) * maxf(1.0, s), tr + 0.6, Color(0.1, 0.18, 0.12, 0.55))
		c.draw_circle(tp, tr, t[2])
		if detail:
			c.draw_circle(tp - Vector2(tr, tr) * 0.3, tr * 0.38, (t[2] as Color).lightened(0.22))
	# Cầu cạn đường sắt trên dãy vòm, cầu Long Biên, cầu Thê Húc, Tháp Rùa.
	for lm in landmarks:
		match str(lm.get("kind", "")):
			"viaduct_top":
				var a := Vector2(lm.a[0], lm.a[1])
				var b := Vector2(lm.b[0], lm.b[1])
				_rail(c, a, b, Color("3a2a20"), 1.6 * s)
			"red_bridge":
				var a := to_map(Vector2(lm.a[0], lm.a[1]))
				var b := to_map(Vector2(lm.b[0], lm.b[1]))
				c.draw_line(a, b, Color("5a1410"), maxf(4.0, 3.4 * s), true)
				c.draw_line(a, b, Color("c8322a"), maxf(2.6, 2.4 * s), true)
			"thap_rua":
				var tp := to_map(Vector2(lm.pos[0], lm.pos[1]))
				var hs := maxf(3.5, 2.6 * s)
				c.draw_rect(Rect2(tp - Vector2(hs, hs), Vector2(hs, hs) * 2.0), Color("d9b65a"))
				c.draw_rect(Rect2(tp - Vector2(hs, hs), Vector2(hs, hs) * 2.0), Color("5a4520"), false, 1.0)
				c.draw_rect(Rect2(tp - Vector2(hs, hs) * 0.45, Vector2(hs, hs) * 0.9), Color("efd88a"))
	for r in city.data.roads:
		if str(r.name).begins_with("Cầu Long Biên"):
			_long_bien(c, r)
	if big:
		var font := get_theme_default_font()
		var placed: Array[Rect2] = []
		# Chừa chỗ cho biểu tượng và dải tên địa điểm (lớp trên) để tên khu, tên phố không nằm dưới.
		for id in city.locs:
			var dp := to_map(city.loc_door(id))
			placed.append(Rect2(dp + Vector2(-60, -14), Vector2(120, 46)))
		_area_names(c, font, landmarks, placed)
		_street_names(c, font, roads, placed)


## Hình vẽ tay của bản đồ minh họa, tính một lần theo tọa độ thế giới (phóng, dời chỉ chiếu lại):
## - bld: căn nhà đa giác méo {p, c, kind, roof: [[a, b, màu]]}, dãy nhà ống cắt thành nhiều căn to nhỏ, lùi lệch;
## - water: sông, hồ bờ cong méo {p, lake}; sand: bãi cát lồi lõm ven sông Hồng;
## - roads: {r, l: đường tâm lượn nhẹ, f: hệ số bề ngang từng điểm}; joints: [chỗ giao đường lớn, bề ngang];
## - alleys: ngõ ngách ngoằn ngoèo; trees: [chỗ, cỡ, màu] theo cụm.
const ROOF_MIX := [Color("8c583a"), Color("a36a4f"), Color("d9822b"), Color("bfa07a"), Color("735d4d"), Color("9b6b4a")]
var _org: Dictionary = {}


func _organic() -> Dictionary:
	if not _org.is_empty():
		return _org
	var city = world.city
	var rng := RandomNumberGenerator.new()
	rng.seed = 20241
	var o := {"bld": [], "water": [], "sand": [], "roads": [], "joints": [], "alleys": [], "trees": []}
	for i in city.data.buildings.size():
		var bd: Dictionary = city.data.buildings[i]
		var kind := str(bd.kind)
		var base: PackedVector2Array = bd.poly
		if base.size() < 3:
			continue
		var cen := _centroid(base)
		var parts: Array = _split_house(base, rng) if kind == "house" and base.size() == 4 else [base]
		if kind == "house":
			parts = _jostle(parts, rng)
		for part in parts:
			var col := _roof_col(kind, cen, rng)
			var amp := 0.5 if kind == "house" else (0.3 if kind in ["villa", "temple", "islet"] else 0.15)
			o.bld.append({"p": _wobble(part, rng, amp), "c": col, "kind": kind,
				"roof": _roof_lines(part, col, rng) if kind in ["house", "villa", "temple"] and part.size() == 4 else []})
	for w in city.data.water:
		var lake := str(w.name).begins_with("Hồ")
		var shore := _resample(w.poly, 6.0)
		if lake:
			shore = _lobes(shore, rng)
		o.water.append({"p": _smooth(_wobble(shore, rng, 2.4 if lake else 2.2), 2), "lake": lake})
		if not lake:
			o.sand = _sand_bars(w.poly, rng)
	for r in city.data.roads:
		if str(r.name).begins_with("Cầu Long Biên"):
			continue
		var line := _resample_line(r.line, 7.0)
		var wob := PackedVector2Array()
		var f := PackedFloat32Array()
		var ph := rng.randf() * TAU
		# Lượn chậm theo chiều dài (một hai khúc cong), đầu đường giữ đúng chỗ để còn nối vào đường khác.
		var amp := 1.7 if not r.small else 0.9
		var waves := clampf(r.line[0].distance_to(r.line[r.line.size() - 1]) / 90.0, 0.6, 2.5)
		for k in line.size():
			var t := float(k) / maxf(line.size() - 1, 1)
			var dir := (line[mini(k + 1, line.size() - 1)] - line[maxi(k - 1, 0)]).normalized()
			var fade := smoothstep(0.0, 0.12, t) * smoothstep(1.0, 0.88, t)
			wob.append(line[k] + dir.orthogonal() * (sin(t * PI * waves + ph) + 0.35 * sin(t * PI * waves * 3.1 + ph * 2.0)) * amp * fade)
			f.append(1.0 + 0.13 * sin(t * 7.1 + ph * 1.7) + 0.06 * sin(t * 17.0 + ph))
		o.roads.append({"r": r, "l": wob, "f": f})
	o.joints = _joints(city.data.roads)
	o.alleys = _alleys(city, rng)
	o.trees = _trees_org(city, rng, o.alleys)
	_org = o
	return o


func _pts_off(poly: PackedVector2Array, off: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in poly:
		out.append(to_map(q) + off)
	return out


## Dải đa giác của đường: bề ngang w điểm ảnh nhân hệ số từng điểm (phình ra, thắt lại).
func _strip_px(line: PackedVector2Array, f: PackedFloat32Array, w: float) -> PackedVector2Array:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for k in line.size():
		var p := to_map(line[k])
		var d := (to_map(line[mini(k + 1, line.size() - 1)]) - to_map(line[maxi(k - 1, 0)])).normalized()
		var n := d.orthogonal() * w * 0.5 * f[k]
		left.append(p + n)
		right.append(p - n)
	right.reverse()
	return left + right


## Hồ: méo theo vài thùy lồi lõm quanh tâm (đầu bắc thuôn, bờ đông phình, một vịnh nhỏ), không còn hình bầu dục đều.
static func _lobes(poly: PackedVector2Array, rng: RandomNumberGenerator) -> PackedVector2Array:
	var c := _centroid(poly)
	var p1 := rng.randf() * TAU
	var p2 := rng.randf() * TAU
	var out := PackedVector2Array()
	for q in poly:
		var d := q - c
		var a := d.angle()
		var k := 1.0 + 0.07 * sin(2.0 * a + p1) + 0.06 * sin(3.0 * a + p2) + 0.035 * sin(5.0 * a + p1 * 1.7)
		out.append(c + d * k)
	return out


static func _resample(poly: PackedVector2Array, step: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var n := maxi(1, int(a.distance_to(b) / step))
		for k in n:
			out.append(a.lerp(b, float(k) / n))
	return out


static func _resample_line(line: PackedVector2Array, step: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in line.size() - 1:
		var n := maxi(1, int(line[i].distance_to(line[i + 1]) / step))
		for k in n:
			out.append(line[i].lerp(line[i + 1], float(k) / n))
	out.append(line[line.size() - 1])
	return out


## Méo đa giác: chia cạnh dài thành đoạn ngắn, xô lệch mỗi đỉnh một chút theo hướng ngẫu nhiên.
static func _wobble(poly: PackedVector2Array, rng: RandomNumberGenerator, amp: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var len := a.distance_to(b)
		var n := maxi(1, int(len / 4.5))
		var nrm := (b - a).normalized().orthogonal()
		for k in n:
			var q := a.lerp(b, float(k) / n)
			var j := rng.randf_range(-amp, amp)
			out.append(q + nrm * j * (0.6 if k > 0 else 1.0) + Vector2(rng.randf_range(-amp, amp), rng.randf_range(-amp, amp)) * (0.5 if k == 0 else 0.2))
	return out


## Làm tròn góc (Chaikin): mỗi vòng thay mỗi cạnh bằng hai điểm 1/4, 3/4.
static func _smooth(poly: PackedVector2Array, iters: int) -> PackedVector2Array:
	var cur := poly
	for it in iters:
		var nxt := PackedVector2Array()
		for i in cur.size():
			var a := cur[i]
			var b := cur[(i + 1) % cur.size()]
			nxt.append(a.lerp(b, 0.25))
			nxt.append(a.lerp(b, 0.75))
		cur = nxt
	return cur


## Dãy nhà ống dài: cắt thành 2–4 căn bề ngang khác nhau, mỗi căn lùi sau lệch một chút, mặt tiền nhô thụt.
static func _split_house(q: PackedVector2Array, rng: RandomNumberGenerator) -> Array:
	var e0 := q[0].distance_to(q[1])
	var e1 := q[1].distance_to(q[2])
	# a0-a1 là cạnh dọc dãy (cạnh dài hơn khi nhà nằm ngang; nhà ống thường mặt tiền hẹp, sâu: cắt theo chiều sâu).
	var long_first := e0 >= e1
	var p0 := q[0] if long_first else q[1]
	var p1 := q[1] if long_first else q[2]
	var p2 := q[2] if long_first else q[3]
	var p3 := q[3] if long_first else q[0]
	var len := maxf(e0, e1)
	if len < 7.0 or rng.randf() < 0.3:
		return [q]
	var cuts := [0.0]
	var t := 0.0
	while true:
		t += rng.randf_range(0.22, 0.5)
		if t > 0.85:
			break
		cuts.append(t)
	cuts.append(1.0)
	var out := []
	for k in cuts.size() - 1:
		var ta: float = cuts[k]
		var tb: float = cuts[k + 1]
		var back := rng.randf_range(0.0, 0.28)
		var front := rng.randf_range(-0.04, 0.06)
		var a0 := p0.lerp(p1, ta)
		var a1 := p0.lerp(p1, tb)
		var b1 := p3.lerp(p2, tb)
		var b0 := p3.lerp(p2, ta)
		out.append(PackedVector2Array([a0.lerp(b0, front), a1.lerp(b1, front), b1.lerp(a1, back), b0.lerp(a0, back)]))
	return out


## Căn nhà xô lệch: xoay ±3° quanh giữa mặt tiền; chừng một phần tư căn có chái nhỏ cơi nới phía sau.
static func _jostle(parts: Array, rng: RandomNumberGenerator) -> Array:
	var out := []
	for q in parts:
		if q.size() != 4:
			out.append(q)
			continue
		var pivot: Vector2 = (q[0] + q[1]) / 2.0
		var ang := rng.randf_range(-0.05, 0.05)
		var r := PackedVector2Array()
		for v in q:
			r.append(pivot + (v - pivot).rotated(ang))
		out.append(r)
		if rng.randf() < 0.25:
			var back_mid: Vector2 = (r[2] + r[3]) / 2.0
			var along: Vector2 = (r[2] - r[3]).normalized()
			var out_dir: Vector2 = (back_mid - pivot).normalized()
			var hw := r[2].distance_to(r[3]) * rng.randf_range(0.2, 0.35)
			var dep := rng.randf_range(1.2, 2.6)
			var off := along * rng.randf_range(-0.25, 0.25) * r[2].distance_to(r[3])
			var b0 := back_mid + off - along * hw
			var b1 := back_mid + off + along * hw
			out.append(PackedVector2Array([b0 - out_dir * 0.3, b1 - out_dir * 0.3, b1 + out_dir * dep, b0 + out_dir * dep]))
	return out


func _roof_col(kind: String, cen: Vector2, rng: RandomNumberGenerator) -> Color:
	var col: Color = ROOF_MIX[rng.randi() % ROOF_MIX.size()]
	match kind:
		"market":
			col = MARKET
		"viaduct":
			col = Color("8a4a32")
		"islet":
			col = Color("9a9480")
		"temple":
			col = Color("b5523a")
		"office", "apartments":
			col = Color("8796a8")
		_:
			if kind in ["villa", "bank", "retail"] or (cen.y > 40.0 and cen.x > 5.0):
				col = FRENCH[rng.randi() % FRENCH.size()]
			elif NIGHT_ZONE.has_point(cen):
				col = col.lerp(NIGHT, 0.6)
	# Nhiễu sáng tối từng mái như nét cọ.
	var k := rng.randf_range(-0.09, 0.09)
	return col.lightened(k) if k > 0.0 else col.darkened(-k)


## Mái: nóc dọc chiều dài căn; mái chéo bốn góc (mái chảy) hay gờ ngói song song nửa mái (mái dốc một bên).
static func _roof_lines(q: PackedVector2Array, col: Color, rng: RandomNumberGenerator) -> Array:
	var e0 := q[0].distance_to(q[1])
	var e1 := q[1].distance_to(q[2])
	var a := (q[0] + q[3]) / 2.0 if e0 >= e1 else (q[0] + q[1]) / 2.0
	var b := (q[1] + q[2]) / 2.0 if e0 >= e1 else (q[3] + q[2]) / 2.0
	var short := minf(e0, e1)
	var dir := (b - a).normalized()
	var ra := a + dir * short * 0.4
	var rb := b - dir * short * 0.4
	var hi := col.lightened(0.22)
	var lo := col.darkened(0.28)
	var out := [[ra, rb, hi]]
	if rng.randf() < 0.55:
		# Mái chảy: bốn đường chéo từ đầu nóc xuống góc.
		var near_a := [q[0], q[3]] if e0 >= e1 else [q[0], q[1]]
		var near_b := [q[1], q[2]] if e0 >= e1 else [q[3], q[2]]
		for c in near_a:
			out.append([ra, c, lo])
		for c in near_b:
			out.append([rb, c, lo])
	else:
		# Gờ ngói: vạch ngang nửa mái phía nắng.
		var side := dir.orthogonal() * short * 0.45
		var k := 1.2
		var len := a.distance_to(b)
		while k < len - 0.6:
			var m := a + dir * k
			out.append([m, m + side, lo])
			k += 1.3
	return out


## Bãi cát lồi lõm bám bờ tây sông Hồng (bờ Phúc Tân), vài bãi nhỏ bờ đông.
static func _sand_bars(river: PackedVector2Array, rng: RandomNumberGenerator) -> Array:
	var bb := Geo.bounds(river)
	var out := []
	var z := bb.position.y + rng.randf_range(10.0, 30.0)
	while z < bb.end.y - 20.0:
		var len := rng.randf_range(24.0, 48.0)
		var west := rng.randf() < 0.75
		var edge := _bank_x(river, z + len / 2.0, west)
		if edge < INF:
			var reach := rng.randf_range(4.0, 10.0) * (1.0 if west else -1.0)
			var pts := PackedVector2Array()
			var n := 12
			for k in n + 1:
				var t := float(k) / n
				var zz := z + len * t
				var bx := _bank_x(river, zz, west)
				if bx == INF:
					continue
				pts.append(Vector2(bx - (1.5 if west else -1.5), zz))
			for k in range(n, -1, -1):
				var t := float(k) / n
				var zz := z + len * t
				var bx := _bank_x(river, zz, west)
				if bx == INF:
					continue
				var bulge := sin(t * PI) * (0.75 + 0.25 * sin(t * 9.0 + z))
				pts.append(Vector2(bx + reach * bulge, zz))
			if pts.size() >= 6:
				out.append(_smooth(pts, 1))
		z += len + rng.randf_range(15.0, 55.0)
	return out


## Hoành độ bờ sông ở tung độ z (bờ tây: nhỏ nhất, bờ đông: lớn nhất) theo các cạnh đa giác.
static func _bank_x(poly: PackedVector2Array, z: float, west: bool) -> float:
	var best := INF if west else -INF
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		if (a.y - z) * (b.y - z) > 0.0 or absf(b.y - a.y) < 1e-6:
			continue
		var x := a.x + (b.x - a.x) * (z - a.y) / (b.y - a.y)
		best = minf(best, x) if west else maxf(best, x)
	return best if absf(best) < 1e8 else INF


## Chỗ giao nhau giữa hai đường lớn (không phải ngõ): đầu một đường nằm trên thân đường kia.
static func _joints(roads: Array) -> Array:
	var out := []
	for r in roads:
		if r.small or r.bridge or r.line.size() < 2:
			continue
		for e in [r.line[0], r.line[r.line.size() - 1]]:
			for q in roads:
				if is_same(q, r) or q.small or q.bridge:
					continue
				for k in q.line.size() - 1:
					if Geo.seg_dist(e, q.line[k], q.line[k + 1]) < float(q.width) * 0.6:
						out.append([e, maxf(float(r.width), float(q.width)) * 1.35])
	return out


## Ngõ ngách: từ mép đường lớn, nhỏ đâm vào trong khối nhà vài đoạn gấp khúc; gặp đường khác thì nối, không thì cụt.
func _alleys(city, rng: RandomNumberGenerator) -> Array:
	var out := []
	var b: Rect2 = city.bounds
	for r in city.data.roads:
		if r.bridge or str(r.name).begins_with("Cầu") or str(r.name).begins_with("Vòng") or str(r.name).begins_with("Đường dạo"):
			continue
		var line: PackedVector2Array = r.line
		for i in line.size() - 1:
			var a := line[i]
			var e := line[i + 1]
			var len := a.distance_to(e)
			var dir := (e - a).normalized()
			var k := rng.randf_range(6.0, 16.0)
			while k < len - 6.0:
				if rng.randf() < 0.42:
					var side := 1.0 if rng.randf() < 0.5 else -1.0
					var n := dir.orthogonal() * side
					var p := a + dir * k + n * (float(r.width) / 2.0 + AreaData.sidewalk(r) + 0.3)
					var pts := PackedVector2Array([p])
					var head := n.rotated(rng.randf_range(-0.35, 0.35))
					for seg in rng.randi_range(2, 4):
						var q := p + head * rng.randf_range(4.0, 9.0)
						if not b.has_point(q) or _in_open(city, q):
							break
						pts.append(q)
						p = q
						if _near_road(city, q, r):
							break
						head = head.rotated(rng.randf_range(-0.8, 0.8))
					if pts.size() >= 2:
						out.append(pts)
				k += rng.randf_range(11.0, 22.0)
	return out


static func _in_open(city, q: Vector2) -> bool:
	for w in city.data.water:
		if Geometry2D.is_point_in_polygon(q, w.poly):
			return true
	for p in city.data.parks:
		if Geometry2D.is_point_in_polygon(q, p.poly):
			return true
	return false


static func _near_road(city, q: Vector2, skip: Dictionary) -> bool:
	for r in city.data.roads:
		if is_same(r, skip):
			continue
		for k in r.line.size() - 1:
			if Geo.seg_dist(q, r.line[k], r.line[k + 1]) < float(r.width) / 2.0 + 1.0:
				return true
	return false


## Cây theo cụm: cây có sẵn xô lệch, mọc thêm một hai cây con quanh; cụm cây trong vườn hoa; cây lọt khe nhà ở đầu ngõ.
func _trees_org(city, rng: RandomNumberGenerator, alleys: Array) -> Array:
	var greens := [TREE_A, TREE_B, Color("5f9e5a"), Color("2f5c40")]
	var out := []
	for t in city.data.trees:
		var c: Vector2 = t + Vector2(rng.randf_range(-1.6, 1.6), rng.randf_range(-1.6, 1.6))
		out.append([c, rng.randf_range(0.75, 1.35), greens[rng.randi() % greens.size()]])
		if rng.randf() < 0.4:
			for k in rng.randi_range(1, 2):
				out.append([c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(2.0, 3.6), rng.randf_range(0.55, 0.9), greens[rng.randi() % greens.size()]])
	for p in city.data.parks:
		if not str(p.kind) in ["park", "garden", "grass"]:
			continue
		var bb := Geo.bounds(p.poly)
		var clusters := int(bb.get_area() / 900.0)
		for k in clusters:
			var c := bb.position + Vector2(rng.randf() * bb.size.x, rng.randf() * bb.size.y)
			if not Geometry2D.is_point_in_polygon(c, p.poly):
				continue
			for m in rng.randi_range(2, 5):
				var q := c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 5.0)
				var wet := false
				for w in city.data.water:
					wet = wet or Geometry2D.is_point_in_polygon(q, w.poly)
				if not wet and Geometry2D.is_point_in_polygon(q, p.poly):
					out.append([q, rng.randf_range(0.7, 1.4), greens[rng.randi() % greens.size()]])
	for al in alleys:
		if rng.randf() < 0.25:
			out.append([al[al.size() - 1] + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)), rng.randf_range(0.6, 0.95), greens[rng.randi() % greens.size()]])
	return out


func _road_px(r: Dictionary) -> float:
	var s := _scale()
	if r.small:
		return maxf(float(r.width) * s, 4.0 if big else 1.5)
	return maxf(float(r.width) * s * 1.15, 11.0 if big else 2.5)


## Ô sạp trong chợ: lưới vạch sẫm mỗi 4 m theo hình bao.
func _stalls(c: Control, poly: PackedVector2Array, col: Color) -> void:
	var s := _scale()
	if s < 0.5:
		return
	var bb := Geo.bounds(poly)
	var line := col.darkened(0.25)
	var x := bb.position.x + 4.0
	while x < bb.end.x - 1.0:
		c.draw_line(to_map(Vector2(x, bb.position.y + 1.0)), to_map(Vector2(x, bb.end.y - 1.0)), line, 1.0)
		x += 4.0
	var z := bb.position.y + 4.0
	while z < bb.end.y - 1.0:
		c.draw_line(to_map(Vector2(bb.position.x + 1.0, z)), to_map(Vector2(bb.end.x - 1.0, z)), line, 1.0)
		z += 4.0


## Nóc mái: nối trung điểm hai cạnh ngắn của căn bốn đỉnh.
func _ridge(c: Control, pts: PackedVector2Array, col: Color) -> void:
	var e0 := pts[0].distance_to(pts[1])
	var e1 := pts[1].distance_to(pts[2])
	var a := (pts[0] + pts[1]) / 2.0 if e0 < e1 else (pts[1] + pts[2]) / 2.0
	var b := (pts[2] + pts[3]) / 2.0 if e0 < e1 else (pts[3] + pts[0]) / 2.0
	var d := (b - a).normalized() * minf(e0, e1) * 0.3
	c.draw_line(a + d, b - d, col.lightened(0.2), 1.0)


## Đường ray: hai thanh ray và tà vẹt.
func _rail(c: Control, a: Vector2, b: Vector2, col: Color, gauge: float) -> void:
	var pa := to_map(a)
	var pb := to_map(b)
	var dir := (pb - pa).normalized()
	var n := dir.orthogonal() * maxf(gauge, 1.5)
	var len := pa.distance_to(pb)
	var step := maxf(4.0, 3.0 * _scale())
	var k := 0.0
	while k < len:
		var m := pa + dir * k
		c.draw_line(m - n * 1.6, m + n * 1.6, col.lightened(0.15), 1.0)
		k += step
	c.draw_line(pa - n, pb - n, col, 1.2)
	c.draw_line(pa + n, pb + n, col, 1.2)


## Cầu Long Biên: mặt cầu nâu gỉ có đường ray giữa; nhịp qua sông có khung sắt chéo hai bên thành cầu.
func _long_bien(c: Control, r: Dictionary) -> void:
	var s := _scale()
	var pts := _pts(c, r.line)
	var w := maxf(float(r.width) * s * 1.5, 10.0 if big else 3.0)
	c.draw_polyline(pts, Color("3a2418"), w + 2.0, true)
	c.draw_polyline(pts, RUST, w, true)
	for i in r.line.size() - 1:
		_rail(c, r.line[i], r.line[i + 1], Color("2a1c14"), 0.9 * s)
	if not r.bridge:
		return
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var dir := (b - a).normalized()
		var n := dir.orthogonal() * (w / 2.0)
		var len := a.distance_to(b)
		var step := maxf(6.0, 5.0 * s)
		var k := 0.0
		var up := true
		while k + step <= len:
			for side in [-1.0, 1.0]:
				var p0: Vector2 = a + dir * k + n * side
				var p1: Vector2 = a + dir * (k + step) + n * side
				c.draw_line(p0, p1, Color("c08a5a"), 1.2)
				c.draw_line(p0 - n * side * (0.0 if up else 0.35), p1 - n * side * (0.35 if up else 0.0), Color("c08a5a"), 1.0)
			up = not up
			k += step


## Tên khu lớn (từ landmarks label của map): chữ hoa thưa, kem, viền tối; tên nhỏ chỉ hiện khi phóng gần.
func _area_names(c: Control, font: Font, landmarks: Array, placed: Array[Rect2]) -> void:
	var fs := int(clampf(12.0 + _zoom * 1.5, 12.0, 18.0))
	for lm in landmarks:
		if str(lm.get("kind", "")) != "label":
			continue
		var t := str(lm.text)
		if t in SMALL_AREAS and _zoom < 2.0:
			continue
		if t == "PHỐ HÀNG BẠC":
			continue
		var p := to_map(Vector2(lm.pos[0], lm.pos[1]))
		var f := fs if not t in SMALL_AREAS else fs - 3
		var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, f).x
		var box := Rect2(p - Vector2(tw / 2.0, f), Vector2(tw, f * 1.3))
		if placed.any(func(q: Rect2) -> bool: return q.intersects(box)):
			continue
		placed.append(box)
		c.draw_string_outline(font, p - Vector2(tw / 2.0, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, f, 5, Color(0.12, 0.08, 0.05, 0.85))
		c.draw_string(font, p - Vector2(tw / 2.0, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, f, Color("fff1d2"))
	# Sông Hồng: chữ dọc giữa dòng.
	for w in world.city.data.water:
		if str(w.name) == "Sông Hồng":
			var bb := Geo.bounds(w.poly)
			var p := to_map(Vector2(bb.get_center().x, world.city.bounds.get_center().y + 40.0))
			_rotated(c, font, p, -PI / 2.0, "S Ô N G   H Ồ N G", fs, Color("dff0f6", 0.85), Color(0.1, 0.2, 0.3, 0.6))


## Tên phố: chữ hoa nhỏ, trắng mờ, xoay theo chiều đường, đặt giữa đoạn dài nhất của mỗi tên, không đè tên khác;
## đường lớn hiện từ mức phóng 1, ngõ hiện khi phóng từ 2,2.
func _street_names(c: Control, font: Font, roads: Array, placed: Array[Rect2]) -> void:
	var best := {}
	for r in roads:
		var name: String = world.city.street_name(str(r.name))
		if name == "" or name.begins_with("Vòng xuyến") or name.begins_with("Cầu ") or r.line.size() < 2:
			continue
		if r.small and _zoom < 2.2:
			continue
		for k in r.line.size() - 1:
			var a: Vector2 = r.line[k]
			var b: Vector2 = r.line[k + 1]
			var l := a.distance_to(b)
			if l > float(best.get(name, [0.0])[0]):
				best[name] = [l, a, b, r]
	var order := best.keys()
	order.sort_custom(func(x, y) -> bool: return float(best[x][0]) > float(best[y][0]))
	for name in order:
		var r: Dictionary = best[name][3]
		var a := to_map(best[name][1])
		var b := to_map(best[name][2])
		if b.x < a.x or (absf(b.x - a.x) < 0.5 and b.y > a.y):
			var t := a
			a = b
			b = t
		var label := String(name).replace("Phố ", "").to_upper()
		var fs := 9 if r.small else int(clampf(9.0 + _zoom, 10.0, 13.0))
		if _road_px(r) < fs + 1.0:
			continue
		var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var mid := (a + b) / 2.0
		if not Rect2(Vector2.ZERO, size).has_point(mid):
			# Đoạn giữa ra ngoài khung: lấy phần đường còn trong khung.
			var vis := Geometry2D.clip_polyline_with_polygon(PackedVector2Array([a, b]),
				PackedVector2Array([Vector2(0, TOP), Vector2(size.x, TOP), Vector2(size.x, size.y), Vector2(0, size.y)]))
			if vis.is_empty():
				continue
			a = vis[0][0]
			b = vis[0][vis[0].size() - 1]
			mid = (a + b) / 2.0
		if a.distance_to(b) < tw + 24.0:
			continue
		var ang := (b - a).angle()
		var half := Vector2(cos(ang), sin(ang)) * (tw / 2.0)
		var box := Rect2(mid - half, Vector2.ZERO).expand(mid + half).grow(fs * 0.6)
		if placed.any(func(q: Rect2) -> bool: return q.intersects(box)):
			continue
		placed.append(box)
		_rotated(c, font, mid, ang, label, fs, Color(1, 1, 1, 0.7), Color(0.25, 0.2, 0.15, 0.35))


## Chữ xoay góc ang quanh tâm p (giữa chữ nằm đúng p, theo chiều dọc cũng canh giữa).
func _rotated(c: Control, font: Font, p: Vector2, ang: float, t: String, fs: int, col: Color, outline: Color) -> void:
	var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var asc := font.get_ascent(fs)
	var h := asc + font.get_descent(fs)
	c.draw_set_transform(p, ang)
	var o := Vector2(-tw / 2.0, asc - h / 2.0)
	if outline.a > 0.0:
		c.draw_string_outline(font, o, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 3, outline)
	c.draw_string(font, o, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	c.draw_set_transform(Vector2.ZERO)


func _loc_quad(id: String) -> PackedVector2Array:
	var p: Dictionary = world.city.locs[id]
	var n: Vector2 = p.normal
	var t := Vector2(n.y, -n.x)
	var cc: Vector2 = p.center
	var w := float(p.w)
	var d := float(p.d)
	return PackedVector2Array([cc - t * w / 2.0, cc + t * w / 2.0, cc + t * w / 2.0 - n * d, cc - t * w / 2.0 - n * d])


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
	_draw_routes(c, font)
	var open: String = world.hud.location_open()
	var near: String = world.nearest_location()
	# Biểu tượng địa điểm, rồi dải tên (rê chuột trước, chỗ ở trước, rồi tới các chỗ khác; đè nhau thì bỏ).
	var placed: Array[Rect2] = []
	var rr := (10.0 if big else 5.0) * (1.0 if _zoom < 2.5 else 1.15)
	for id in city.locs:
		var dp := to_map(city.loc_door(id))
		var cat: String = LOC_CAT.get(id, "work")
		_icon(c, dp, rr + (2.0 if id == _hover else 0.0), cat)
		if id == open or id == near:
			c.draw_arc(dp, rr + 4.0, 0, TAU, 24, UI.GOLD, 2.0)
		placed.append(Rect2(dp - Vector2(rr, rr), Vector2(rr, rr) * 2.0))
	if big:
		var ids: Array = city.locs.keys()
		ids.sort_custom(func(x, y) -> bool: return _pill_rank(x) < _pill_rank(y))
		for id in ids:
			if id != _hover and _zoom < 1.6:
				continue
			_pill(c, font, to_map(city.loc_door(id)) + Vector2(0, rr + 4.0), str(world.LOCATIONS[id].name), placed, id == _hover)
		_draw_people(c, font)
	var pp := to_map(Vector2(world.player.position.x, world.player.position.z))
	var a: float = world.player.rotation.y
	var fwd := Vector2(sin(a), cos(a))
	var side := Vector2(-fwd.y, fwd.x)
	var k := 1.5 if big else 1.0
	var tri := PackedVector2Array([pp + fwd * 9.0 * k, pp - fwd * 5.0 * k + side * 6.0 * k, pp - fwd * 5.0 * k - side * 6.0 * k])
	c.draw_colored_polygon(tri, UI.GOLD)
	c.draw_polyline(tri + PackedVector2Array([tri[0]]), Color(0, 0, 0, 0.7), 1.2)
	# Dải tiêu đề trên cùng, bảng chú thích dưới cùng (bản lớn).
	c.draw_rect(Rect2(0, 0, size.x, TOP + 2.0), Color(0.07, 0.08, 0.11, 0.92))
	var title := "%s · %s" % [city.display, _open_hint()] if not big else "Bản đồ %s · %s" % [city.display, _go_hint()]
	var col := UI.HUD_SOFT
	var show_id := _hover if _hover != "" else open
	if show_id != "":
		title = str(world.LOCATIONS[show_id].name)
		col = UI.HUD_TEXT
	var fs := 15 if big else 12
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	c.draw_string(font, Vector2((size.x - tw) / 2.0, 16 if not big else 17), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	if big:
		_legend(c, font)


func _pill_rank(id: String) -> int:
	if id == _hover:
		return 0
	if id == world.home:
		return 1
	return 2 if LOC_CAT.get(id, "") != "home" else 3


## Dải băng tên dưới biểu tượng: nền đen mờ bo tròn, chữ trắng; đè lên dải khác thì bỏ (trừ khi đang rê chuột).
func _pill(c: Control, font: Font, top_mid: Vector2, t: String, placed: Array[Rect2], force: bool) -> void:
	var fs := 12
	var tw := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var box := Rect2(top_mid - Vector2(tw / 2.0 + 7.0, 0), Vector2(tw + 14.0, fs + 7.0))
	if not force and placed.any(func(q: Rect2) -> bool: return q.intersects(box)):
		return
	placed.append(box)
	c.draw_style_box(UI.box(Color(0.05, 0.05, 0.07, 0.78), Color(1, 1, 1, 0.15), int(box.size.y / 2.0), 0), box)
	c.draw_string(font, box.position + Vector2(7.0, fs + 1.5), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)


## Biểu tượng tròn theo loại địa điểm: nền màu loại, viền trắng, ký hiệu trắng vẽ bằng nét.
func _icon(c: Control, p: Vector2, r: float, cat: String) -> void:
	var col: Color = CATS[cat][1]
	c.draw_circle(p + Vector2(0, 1.5), r + 1.5, Color(0, 0, 0, 0.45))
	c.draw_circle(p, r + 1.5, Color.WHITE)
	c.draw_circle(p, r, col)
	if r < 6.0:
		return
	_glyph(c, p, r * 0.62, cat, Color.WHITE)


func _glyph(c: Control, p: Vector2, u: float, cat: String, ink: Color) -> void:
	match cat:
		"home":
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-u, -0.05 * u), p + Vector2(0, -u), p + Vector2(u, -0.05 * u)]), ink)
			c.draw_rect(Rect2(p + Vector2(-0.68 * u, -0.08 * u), Vector2(1.36 * u, 0.95 * u)), ink)
			c.draw_rect(Rect2(p + Vector2(-0.18 * u, 0.3 * u), Vector2(0.36 * u, 0.57 * u)), Color(0, 0, 0, 0.35))
		"food":
			var bowl := PackedVector2Array()
			for i in 13:
				var t := PI * float(i) / 12.0
				bowl.append(p + Vector2(cos(t) * u, sin(t) * u * 0.75) + Vector2(0, -0.05 * u))
			c.draw_colored_polygon(bowl, ink)
			c.draw_line(p + Vector2(0.1 * u, -0.25 * u), p + Vector2(0.75 * u, -1.0 * u), ink, maxf(1.2, 0.14 * u))
			c.draw_line(p + Vector2(0.35 * u, -0.2 * u), p + Vector2(1.0 * u, -0.85 * u), ink, maxf(1.2, 0.14 * u))
		"work":
			c.draw_rect(Rect2(p + Vector2(-u, -0.45 * u), Vector2(2.0 * u, 1.3 * u)), ink)
			c.draw_rect(Rect2(p + Vector2(-0.38 * u, -0.8 * u), Vector2(0.76 * u, 0.42 * u)), ink, false, maxf(1.2, 0.16 * u))
			c.draw_line(p + Vector2(-u, 0.05 * u), p + Vector2(u, 0.05 * u), Color(0, 0, 0, 0.35), 1.0)
		"fun":
			c.draw_rect(Rect2(p + Vector2(-0.6 * u, -0.55 * u), Vector2(1.0 * u, 1.45 * u)), ink)
			c.draw_arc(p + Vector2(0.45 * u, 0.15 * u), 0.38 * u, -PI / 2.0, PI / 2.0, 8, ink, maxf(1.2, 0.16 * u))
			for fx in [-0.42, -0.1, 0.22]:
				c.draw_circle(p + Vector2(fx * u, -0.62 * u), 0.26 * u, ink)
		"shop":
			# Áo phông: thân, hai tay áo, cổ khoét.
			c.draw_colored_polygon(PackedVector2Array([p + Vector2(-0.45 * u, -0.75 * u), p + Vector2(-1.0 * u, -0.35 * u), p + Vector2(-0.75 * u, 0.05 * u),
				p + Vector2(-0.5 * u, -0.1 * u), p + Vector2(-0.5 * u, 0.9 * u), p + Vector2(0.5 * u, 0.9 * u), p + Vector2(0.5 * u, -0.1 * u),
				p + Vector2(0.75 * u, 0.05 * u), p + Vector2(1.0 * u, -0.35 * u), p + Vector2(0.45 * u, -0.75 * u), p + Vector2(0.0, -0.5 * u)]), ink)
		"service":
			# Đồng xu có vạch đứng như chữ đ.
			c.draw_arc(p, 0.85 * u, 0, TAU, 16, ink, maxf(1.4, 0.2 * u))
			c.draw_line(p + Vector2(0.15 * u, -0.6 * u), p + Vector2(0.15 * u, 0.55 * u), ink, maxf(1.4, 0.2 * u))
			c.draw_circle(p + Vector2(-0.12 * u, 0.2 * u), 0.3 * u, ink)
			c.draw_line(p + Vector2(-0.15 * u, -0.38 * u), p + Vector2(0.45 * u, -0.38 * u), ink, maxf(1.0, 0.14 * u))
		"bus":
			c.draw_rect(Rect2(p + Vector2(-0.85 * u, -0.85 * u), Vector2(1.7 * u, 1.45 * u)), ink)
			c.draw_rect(Rect2(p + Vector2(-0.62 * u, -0.6 * u), Vector2(1.24 * u, 0.5 * u)), Color(0, 0, 0, 0.4))
			c.draw_circle(p + Vector2(-0.5 * u, 0.75 * u), 0.22 * u, ink)
			c.draw_circle(p + Vector2(0.5 * u, 0.75 * u), 0.22 * u, ink)


## Bảng chú thích góc dưới bên trái: năm loại địa điểm, cách phóng, dời.
func _legend(c: Control, font: Font) -> void:
	var fs := 12
	var x := 12.0
	var y := size.y - 34.0
	var w := 0.0
	for k in CATS:
		w += 24.0 + font.get_string_size(str(CATS[k][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 14.0
	var hint := "lăn chuột / nút ± để phóng · kéo để dời"
	var hw := font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
	c.draw_style_box(UI.box(Color(0.05, 0.05, 0.07, 0.8), Color(1, 1, 1, 0.12), 8, 0), Rect2(x - 6.0, y - 4.0, w + hw + 18.0, 30.0))
	for k in CATS:
		_icon(c, Vector2(x + 9.0, y + 11.0), 8.0, k)
		x += 22.0
		c.draw_string(font, Vector2(x, y + 16.0), str(CATS[k][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.HUD_TEXT)
		x += font.get_string_size(str(CATS[k][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 16.0
	c.draw_string(font, Vector2(x + 2.0, y + 15.0), hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UI.HUD_SOFT)


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

