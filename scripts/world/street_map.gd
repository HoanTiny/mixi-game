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


func _ready() -> void:
	custom_minimum_size = Vector2(900, 560) if big else Vector2(330, 186)
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(func() -> void:
		_hover = ""
		queue_redraw())
	if big:
		visible = false
		set_anchors_preset(Control.PRESET_CENTER)
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
	var title := "Phường An Hòa · bấm để mở bản đồ lớn (M)" if not big else "Bản đồ phường An Hòa · bấm một chỗ để đi tới · M hoặc Esc để đóng"
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
