extends Control
## Chỗ làm việc 3D kiểu Nobody: mỗi việc có một bản đồ nhỏ riêng (kho khu công nghiệp, quán cơm, tiệm sửa, công trình
## điện ở Bến Cạn), An tự đi lại trong đó, bưng, đặt, sửa trong một ca có giờ hạn và chỉ tiêu.
##   carry  (kho, công trình): bưng hàng từ đống bỏ lên pallet, thùng cẩu, điểm thi công đúng loại cần.
##   serve  (quán cơm): khách ngồi bàn gọi món, lấy món ở quầy bưng ra; khách ăn xong thì dọn bát về chậu rửa.
##   repair (tiệm sửa): khách mang máy tới quầy, đem lên bàn sửa, lấy đúng linh kiện ở kệ, sửa xong trả khách.
## Đi bằng WASD (hay phím mũi tên) hoặc bấm, chạm xuống sàn; tới gần chỗ cần làm rồi bấm E, Space hay bấm thẳng vào
## chỗ đó. Cùng giao diện với trò chơi nhỏ cũ: cfg (data/config.json minigames), last, title, phát finished(result):
## {"ratio", "bonus"} khi hết ca, {"auto": true, ...} nếu làm tự động như lần trước, {} nếu bỏ.

const UI := preload("res://scripts/ui/ui_kit.gd")
const GameLogic := preload("res://scripts/game_logic.gd")
const Character := preload("res://scripts/world/character.gd")
const WP := preload("res://scripts/work/work_props.gd")

signal finished(result: Dictionary)

const SPEED := 4.4
const BODY_R := 0.35
## Máy quay nghiêng nhìn xuống như ảnh chụp Nobody: cao 10 m, lùi 7,5 m.
const CAM_OFF := Vector3(0, 10.0, 7.5)

var cfg: Dictionary = {}
var last: Dictionary = {}
var title := "Làm việc"
## Khóa trò chơi trong cfg.minigames: bricks (kho), site (công trình), dishes (quán), repair (tiệm).
var kind := "bricks"

var _mode := "carry"
var _state := "start"
var _rng := RandomNumberGenerator.new()
var _time_left := 0.0
var _done := 0
var _bonus := 0
var _miss := 0
var _cool := 0.0

# 3D
var _vp: SubViewport
var _world: Node3D
var _cam: Camera3D
var _player: Node3D
var _body
var _stack: Node3D
var _bounds := Rect2()
var _blocks: Array[Rect2] = []
## Chỗ làm được: {pos: Vector2, reach: float, type: "pile"/"slot"/..., label: Label3D, ...}.
var _spots: Array = []
var _target = null
var _pending = null
var _walkers: Array = []
var _idlers: Array = []
## Đồ đang cầm trên tay: danh sách khóa (loại hàng, món ăn, "dirty", "may:<i>", "part:<k>").
var _carry: Array = []

# Giao diện
var _hud: PanelContainer
var _head_l: Label
var _goal_l: Label
var _bar: ProgressBar
var _carry_l: Label
var _note_l: Label
var _hint_l: Label
var _menu_wrap: CenterContainer
var _menu: VBoxContainer
var _note_t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UI.make_theme()
	_rng.randomize()
	_mode = {"bricks": "carry", "site": "carry", "dishes": "serve", "repair": "repair"}.get(kind, "carry")
	var holder := SubViewportContainer.new()
	holder.stretch = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_2X
	_vp.handle_input_locally = false
	holder.add_child(_vp)
	_world = Node3D.new()
	_vp.add_child(_world)
	_build_light()
	match _mode:
		"serve":
			_build_quan()
		"repair":
			_build_tiem()
		_:
			_build_carry()
	_build_player()
	_build_ui()
	_show_start()


# ---------------------------------------------------------------- dựng cảnh

func _build_light() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("2a2d33")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("9aa3b5")
	e.ambient_light_energy = 0.32
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	_world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -35, 0)
	sun.light_energy = 0.82
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	_world.add_child(sun)
	_cam = Camera3D.new()
	_cam.fov = 46.0
	_world.add_child(_cam)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


## Sàn và tường phủ vật liệu chụp thật; tường sau cao, hai tường bên thấp dần về phía máy quay (như mô hình cắt nửa).
func _floor(w: float, d: float, floor_tex: String, wall_tex: String, wall_tint := Color(1, 1, 1), upper_tex := "") -> void:
	_bounds = Rect2(-w / 2.0, -d / 2.0, w, d)
	WP.box(_world, Vector3(w + 2.0, 0.2, d + 2.0), WP.tex(floor_tex, 0.35), Vector3(0, -0.2, 0))
	var wall := WP.tex(wall_tex, 0.4, wall_tint)
	WP.box(_world, Vector3(w + 1.0, 2.6, 0.3), wall, Vector3(0, 0, -d / 2.0 - 0.15))
	for side in [-1.0, 1.0]:
		WP.box(_world, Vector3(0.3, 2.6, d * 0.45), wall, Vector3(side * (w / 2.0 + 0.15), 0, -d * 0.275))
		WP.box(_world, Vector3(0.3, 1.0, d * 0.55 + 0.5), wall, Vector3(side * (w / 2.0 + 0.15), 0, d * 0.225 + 0.25))
	if upper_tex != "":
		WP.box(_world, Vector3(w + 1.0, 1.2, 0.32), WP.tex(upper_tex, 0.5), Vector3(0, 2.6, -d / 2.0 - 0.15))
	# Chân tường sơn sẫm.
	WP.box(_world, Vector3(w + 0.9, 0.18, 0.06), WP.plain(Color("3a3d42")), Vector3(0, 0, -d / 2.0 + 0.02))


## Mô hình đặt ở (x, z), xoay yaw, có chặn đường đi theo khung w × d.
func _prop(node: Node3D, x: float, z: float, yaw := 0.0, w := 0.0, d := 0.0, y := 0.0) -> Node3D:
	node.position = Vector3(x, y, z)
	node.rotation.y = yaw
	_world.add_child(node)
	if w > 0.0:
		_blocks.append(Rect2(x - w / 2.0, z - d / 2.0, w, d))
	return node


## Đèn treo trần (ngoài khung hình): một bóng sáng ấm.
func _lamp(x: float, z: float) -> void:
	var l := OmniLight3D.new()
	l.position = Vector3(x, 2.2, z)
	l.light_color = Color("ffd9a0")
	l.light_energy = 0.9
	l.omni_range = 6.0
	_world.add_child(l)


## Đặt một món (theo khóa) lên chỗ, trả về nút để gỡ sau.
func _place_item(key: String, pos: Vector3, yaw := 0.0) -> Node3D:
	var n := WP.item(key)
	n.position = pos
	n.rotation.y = yaw
	_world.add_child(n)
	return n


func _label(text: String, x: float, z: float, y := 2.2) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	# Cỡ chữ cố định trên màn, gần hay xa máy quay cũng vậy.
	l.fixed_size = true
	l.font_size = 30
	l.pixel_size = 0.0008
	l.outline_size = 10
	l.outline_modulate = Color(0.08, 0.09, 0.12, 0.95)
	l.position = Vector3(x, y, z)
	_world.add_child(l)
	return l


## Bảng hiệu sơn trên tường sau: tấm tôn màu, chữ trắng.
func _sign(text: String, x: float, z: float, w: float, bg: Color) -> void:
	WP.box(_world, Vector3(w, 0.9, 0.04), WP.plain(bg, 0.6), Vector3(x, 1.55, z))
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = 0.004
	l.modulate = Color("fdf6e3")
	l.outline_size = 0
	l.position = Vector3(x, 2.0, z + 0.03)
	_world.add_child(l)


func _spot(type: String, x: float, z: float, reach: float, text: String) -> Dictionary:
	var s := {"type": type, "pos": Vector2(x, z), "reach": reach, "label": _label(text, x, z)}
	_spots.append(s)
	return s


func _person(look: Dictionary, x: float, z: float, face := 0.0):
	var c = Character.make(look)
	c.position = Vector3(x, 0, z)
	c.rotation.y = face
	_world.add_child(c)
	return c


func _type_color(k: String) -> Color:
	var t: Dictionary = cfg.get("types", {}).get(k, cfg.get("items", {}).get(k, cfg.get("parts", {}).get(k, {})))
	return Color(str(t.get("color", "c8c8c8")))


func _type_name(k: String) -> String:
	var t: Dictionary = cfg.get("types", {}).get(k, cfg.get("items", {}).get(k, cfg.get("parts", {}).get(k, {})))
	return str(t.get("name", k))


# ---------------------------------------------------------------- kho, công trình: bưng hàng

func _build_carry() -> void:
	var site := kind == "site"
	if site:
		_floor(17.0, 12.0, "concrete_floor_02", "rusty_metal_sheet", Color(1, 1, 1), "corrugated_iron")
	else:
		_floor(17.0, 12.0, "concrete_floor_worn_001", "painted_plaster_wall", Color(0.92, 0.94, 1.0), "corrugated_iron")
	var types: Array = cfg.types.keys()
	# Đống hàng bên trái, mỗi loại một đống trên pallet.
	for i in types.size():
		var k: String = types[i]
		var z := -3.6 + i * 3.6
		_prop(WP.pallet(), -6.6, z, 0.0, 1.3, 1.1)
		var h := WP.item_h(k)
		for row in 3:
			for col in 3:
				if row == 2 and col != 1:
					continue
				_place_item(k, Vector3(-7.0 + col * 0.42, 0.124 + row * h, z - 0.2 + (col % 2) * 0.35), _rng.randf_range(-0.15, 0.15))
		_spot("pile", -6.6, z, 1.8, _type_name(k)).merge({"key": k})
	# Chỗ xếp bên phải: pallet trống (kho) hay điểm thi công trên tấm ván (công trình).
	for i in 3:
		var z := -3.6 + i * 3.6
		_prop(WP.pallet(), 5.2, z, PI / 2.0, 1.1, 1.3)
		var s := _spot("slot", 5.2, z, 1.9, "")
		s["boxes"] = []
		_new_slot(s)
	if site:
		_prop(WP.model("wooden_ladder", 1.6), -1.0, -5.3, 0.0, 1.5, 0.6)
		_prop(WP.model("portable_generator", 1.3), 2.4, -5.2, 0.3, 1.1, 0.8)
		for x in [-3.0, -2.2]:
			_prop(WP.model("barrel_03"), x, 5.0, 0.0, 0.7, 0.7)
		for i in 3:
			var box := WP.model("power_box_01")
			box.get_child(0).position.y = 0.25
			_prop(box, -4.0 + i * 1.4, -5.75, 0.0, 0.0, 0.0, 1.3)
		_prop(WP.model("plastic_crate_01", 1.4), 1.0, 5.0, 0.4, 0.6, 0.6)
		_idlers.append(_person(Character.LOOKS.get("TRAM", {}), 0.5, -4.2, 0.0))
	else:
		for x in [-3.0, 0.2]:
			var shelf := _prop(WP.model("wooden_bookshelf_worn", 1.15), x, -5.55, 0.0, 1.7, 0.7)
			for lvl in 3:
				for j in 3:
					_place_item(["mi", "nuoc", "mi"][(j + lvl) % 3], Vector3(x - 0.5 + j * 0.5, 0.08 + lvl * 0.78, -5.6))
		_prop(WP.model("industrial_storage_cart", 1.0), 2.7, -5.3, 0.0, 1.7, 1.2)
		for i in 4:
			_prop(WP.model("barrel_03"), -2.4 + (i % 2) * 0.68, 4.6 + (i / 2) * 0.68, _rng.randf() * TAU)
		_blocks.append(Rect2(-2.8, 4.25, 1.5, 1.5))
		_prop(WP.model("plastic_crate_01", 1.5), 2.2, 4.9, 0.3, 0.6, 0.7)
		for x in [-4.6, 3.4]:
			WP.box(_world, Vector3(0.12, 0.005, 11.0), WP.plain(Color("d6b22e"), 0.6), Vector3(x, 0.0, 0))
		_idlers.append(_person(Character.random_look(_rng), 1.5, -3.8, 0.4))
	for x in [-3.5, 0.5, 4.5]:
		_lamp(x, -1.0)
	_idlers.append(_person(Character.random_look(_rng), -1.2, 3.6, 2.6))


func _new_slot(s: Dictionary) -> void:
	var types: Array = cfg.types.keys()
	var sizes: Array = cfg.sizes
	s["key"] = types[_rng.randi() % types.size()]
	s["need"] = int(sizes[_rng.randi() % sizes.size()])
	s["have"] = 0
	s["value"] = int(s.need) * int(cfg.bonusPerBrick) + (int(s.need) - 2) * int(cfg.bonusPerBrick)
	for b in s.boxes:
		b.queue_free()
	s["boxes"] = []
	_slot_label(s)


func _slot_label(s: Dictionary) -> void:
	(s.label as Label3D).text = "%s %d/%d\n+%s" % [_type_name(str(s.key)), int(s.have), int(s.need), GameLogic.fmt_k(int(s.value))]


func _carry_act(s: Dictionary) -> void:
	if s.type == "pile":
		if _carry.size() >= int(cfg.carry):
			_note("Tay đầy rồi, mang ra chỗ xếp đã.")
			return
		_carry.append(str(s.key))
		_cool = 0.25
	elif s.type == "slot":
		if _carry.is_empty():
			_note("Chỗ này cần %d %s." % [int(s.need) - int(s.have), _type_name(str(s.key)).to_lower()])
			return
		var kept := []
		var put := 0
		for k in _carry:
			if k == s.key and int(s.have) < int(s.need):
				s["have"] = int(s.have) + 1
				put += 1
				var n: int = s.boxes.size()
				s.boxes.append(_place_item(str(k), Vector3(4.8 + (n % 2) * 0.45, 0.124 + (n / 4) * WP.item_h(str(k)), (s.pos as Vector2).y - 0.3 + (n / 2 % 2) * 0.55)))
			else:
				kept.append(k)
		_carry = kept
		if put == 0:
			_note("Không đúng loại: chỗ này cần %s." % _type_name(str(s.key)).to_lower())
			return
		_cool = 0.3
		if int(s.have) >= int(s.need):
			_done += 1
			_bonus += int(s.value)
			_note("%s, +%s" % [str(cfg.get("doneWord", "Đầy pallet")), GameLogic.fmt_k(int(s.value))], true)
			s["have"] = -1
			(s.label as Label3D).text = "Xong!"
			var tw := create_tween()
			for b in s.boxes:
				tw.parallel().tween_property(b, "position:y", 4.0, 0.9)
			tw.tween_callback(_new_slot.bind(s))
		else:
			_slot_label(s)


# ---------------------------------------------------------------- quán cơm: bưng món, dọn bát

func _build_quan() -> void:
	_floor(16.0, 12.0, "worn_tile_floor", "plastered_wall_04", Color(1.0, 0.93, 0.82))
	# Quầy món phía trong (mặt gạch men, thân ván), chị Hạnh đứng sau quầy.
	_blocks.append(Rect2(-5.5, -5.1, 9.0, 1.0))
	WP.box(_world, Vector3(9.0, 0.9, 0.9), WP.tex("brown_planks_05", 0.8), Vector3(-1.0, 0, -4.6))
	WP.box(_world, Vector3(9.1, 0.05, 1.0), WP.plain(Color("d8dde2"), 0.25, 0.6), Vector3(-1.0, 0.9, -4.6))
	_idlers.append(_person(Character.LOOKS.get("HANH", {}), -1.0, -5.5, 0.0))
	var items: Array = cfg.items.keys()
	for i in items.size():
		var k: String = items[i]
		var x := -4.2 + i * 3.2
		# Nồi cơm lớn, nồi canh, thùng trà đá trên quầy; vài tô bày sẵn.
		var big: Node3D = WP.rice_cooker() if k == "com" else (WP.model("pot_enamel_01", 3.0) if k == "canh" else WP.model("plastic_crate_03", 1.4))
		_prop(big, x - 0.45, -4.75, 0.0, 0.0, 0.0, 0.95)
		for j in 3:
			_place_item(k, Vector3(x + 0.2 + j * 0.25, 0.95, -4.4))
		_spot("station", x, -4.6, 1.5, _type_name(k)).merge({"key": k})
	# Chậu rửa inox bên phải, thau bát dơ.
	_blocks.append(Rect2(5.5, -4.2, 1.6, 1.2))
	WP.box(_world, Vector3(1.6, 0.85, 1.2), WP.plain(Color("aeb4ba"), 0.3, 0.8), Vector3(6.3, 0, -3.6))
	WP.box(_world, Vector3(1.2, 0.02, 0.8), WP.plain(Color("6f8fa8"), 0.05, 0.2), Vector3(6.3, 0.85, -3.6))
	_spot("sink", 6.3, -3.6, 1.6, "Chậu rửa")
	# Bàn inox thấp, ghế nhựa trắng.
	var tables := [Vector2(-4.5, 0.4), Vector2(0.0, 0.4), Vector2(-4.5, 3.9), Vector2(0.0, 3.9), Vector2(4.5, 1.8)]
	for p in tables:
		_prop(WP.steel_table(), p.x, p.y, 0.0, 1.3, 0.9)
		for side in [-1.0, 1.0]:
			_prop(WP.model("plastic_monobloc_chair_01"), p.x + side * 0.95, p.y, -side * PI / 2.0)
		var s := _spot("table", p.x, p.y, 1.6, "")
		s["cust"] = null
		s["order"] = {}
		s["dirty"] = false
		s["patience"] = 0.0
		s["bowls"] = []
	_idlers.append(_person(Character.LOOKS.get("MINH", {}), 6.5, 4.5, -2.4))
	# Tủ mát nước ngọt, két nước, chậu cây, bảng giá.
	_blocks.append(Rect2(3.7, -5.7, 1.0, 0.8))
	WP.box(_world, Vector3(1.0, 1.9, 0.8), WP.plain(Color("c0392b"), 0.4), Vector3(4.2, 0, -5.3))
	var glass := WP.plain(Color(0.7, 0.85, 0.95, 0.45), 0.05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	WP.box(_world, Vector3(0.8, 1.4, 0.02), glass, Vector3(4.2, 0.35, -4.89))
	for i in 3:
		_prop(WP.model("plastic_crate_01", 1.4), -6.8, 4.6 - i * 0.65, 0.0)
	_blocks.append(Rect2(-7.2, 3.0, 0.8, 2.0))
	_prop(WP.model("potted_plant_04", 3.0), 7.0, 5.2)
	_sign("CƠM HẠNH\ncơm sườn 35k · canh chua 20k · trà đá 3k", -1.0, -5.98, 5.2, Color("b8322a"))
	for x in [-4.5, 0.0, 4.5]:
		_lamp(x, 1.5)


func _tables() -> Array:
	return _spots.filter(func(s) -> bool: return s.type == "table")


func _serve_tick(delta: float) -> void:
	var free := _tables().filter(func(s) -> bool: return s.cust == null and not s.dirty)
	var seated := _tables().size() - free.size()
	_cool_spawn -= delta
	if _cool_spawn <= 0.0 and not free.is_empty() and seated < int(cfg.get("maxCustomers", 4)):
		_cool_spawn = float(cfg.get("spawnEvery", 6.0)) * _rng.randf_range(0.7, 1.3)
		_seat(free[_rng.randi() % free.size()])
	for s in _tables():
		if s.cust != null and not (s.order as Dictionary).is_empty():
			s["patience"] = float(s.patience) - delta
			_table_label(s)
			if float(s.patience) <= 0.0:
				_miss += 1
				_note("Khách chờ lâu quá, bỏ đi rồi.")
				_leave(s)


var _cool_spawn := 1.0


func _seat(s: Dictionary) -> void:
	var c = _person(Character.random_look(_rng), (s.pos as Vector2).x + 1.05, (s.pos as Vector2).y, -PI / 2.0)
	c.sit(true, 0.5)
	s["cust"] = c
	var order := {}
	var items: Array = cfg.items.keys()
	for i in (1 if _rng.randf() < 0.55 else 2):
		var k: String = items[_rng.randi() % items.size()]
		order[k] = int(order.get(k, 0)) + 1
	s["order"] = order
	s["patience"] = float(cfg.get("patience", 35.0))
	_table_label(s)


func _table_label(s: Dictionary) -> void:
	var l: Label3D = s.label
	if s.dirty:
		l.text = "Bát dơ"
		l.modulate = Color("e0c080")
	elif s.cust == null:
		l.text = ""
	elif (s.order as Dictionary).is_empty():
		l.text = "Đang ăn…"
		l.modulate = Color(1, 1, 1)
	else:
		var parts := []
		for k in s.order:
			parts.append("%s ×%d" % [_type_name(k), int(s.order[k])])
		l.text = "\n".join(parts) + "\n⏱ %d" % ceili(float(s.patience))
		l.modulate = Color(1, 0.55, 0.45) if float(s.patience) < 10.0 else Color(1, 1, 1)


func _leave(s: Dictionary) -> void:
	var c = s.cust
	s["cust"] = null
	s["order"] = {}
	_table_label(s)
	if c != null:
		c.sit(false)
		_walkers.append({"node": c, "to": Vector3(c.position.x, 0, 8.0)})


func _serve_act(s: Dictionary) -> void:
	match str(s.type):
		"station":
			if _carry.has("dirty"):
				_note("Tay đang cầm bát dơ, đem ra chậu rửa đã.")
			elif _carry.size() >= int(cfg.carry):
				_note("Tay đầy rồi.")
			else:
				_carry.append(str(s.key))
				_cool = 0.25
		"sink":
			var n := _carry.count("dirty")
			if n == 0:
				_note("Dọn bát dơ ở bàn rồi đem ra đây rửa.")
				return
			_carry = _carry.filter(func(k) -> bool: return k != "dirty")
			_bonus += n * int(cfg.cleanBonus)
			_note("Rửa xong, +%s" % GameLogic.fmt_k(n * int(cfg.cleanBonus)), true)
		"table":
			if s.dirty:
				if not _carry.is_empty():
					_note("Tay không mới dọn bát được.")
					return
				_carry.append("dirty")
				s["dirty"] = false
				for b in s.bowls:
					b.queue_free()
				s["bowls"] = []
				_table_label(s)
				return
			if s.cust == null or (s.order as Dictionary).is_empty():
				return
			var order: Dictionary = s.order
			var kept := []
			var gave := 0
			for k in _carry:
				if int(order.get(k, 0)) > 0:
					order[k] = int(order[k]) - 1
					if int(order[k]) == 0:
						order.erase(k)
					gave += 1
					s.bowls.append(_place_item(str(k), Vector3((s.pos as Vector2).x - 0.3 + s.bowls.size() * 0.3, 0.75, (s.pos as Vector2).y)))
				else:
					kept.append(k)
			_carry = kept
			if gave == 0:
				_note("Bàn này không gọi món đó.")
				return
			if order.is_empty():
				_done += 1
				var extra := maxi(0, _done - int(cfg.target))
				var tip := int(cfg.bonusPerExtra) if extra > 0 or float(s.patience) > float(cfg.get("patience", 35.0)) * 0.5 else 0
				_bonus += tip
				_note("Đủ món!" + (" Khách khen nhanh, +%s" % GameLogic.fmt_k(tip) if tip > 0 else ""), true)
				_table_label(s)
				var t := get_tree().create_timer(float(cfg.get("eatSec", 4.0)))
				t.timeout.connect(func() -> void:
					if _state != "play":
						return
					s["dirty"] = true
					_leave(s)
					_table_label(s))
			else:
				_table_label(s)


# ---------------------------------------------------------------- tiệm sửa: quầy, bàn sửa, kệ linh kiện

func _build_tiem() -> void:
	_floor(14.0, 11.0, "concrete_floor_worn_001", "painted_plaster_wall", Color(0.78, 0.88, 0.96))
	# Quầy nhận máy phía trước (khách đứng ngoài, phía máy quay), hai chỗ đặt máy.
	_blocks.append(Rect2(-3.0, 3.2, 7.0, 0.8))
	WP.box(_world, Vector3(7.0, 0.95, 0.8), WP.tex("brown_planks_05", 0.8), Vector3(0.5, 0, 3.6))
	WP.box(_world, Vector3(7.1, 0.04, 0.9), WP.tex("brown_planks_05", 0.6, Color(0.8, 0.7, 0.6)), Vector3(0.5, 0.95, 3.6))
	for i in 2:
		var x := -1.5 + i * 4.0
		var s := _spot("counter", x, 3.6, 1.5, "")
		s["cust"] = null
		s["machine"] = {}
		s["wait"] = 0.0
	# Bàn sửa: bàn sắt, ê tô, radio cũ, đèn; cái ghế đẩu của chú Sáu.
	_prop(WP.model("metal_office_desk", 1.4), 1.0, -3.4, PI, 2.8, 1.3)
	_prop(WP.model("bench_vice_01", 1.4), 2.2, -3.55, 0.0, 0.0, 0.0, 1.1)
	_prop(WP.model("boombox", 0.7), -0.2, -3.75, 0.0, 0.0, 0.0, 1.1)
	_prop(WP.model("metal_stool_01"), 1.0, -2.2)
	var bench := _spot("bench", 1.0, -3.4, 1.7, "Bàn sửa")
	bench["machine"] = {}
	bench["progress"] = 0.0
	bench["node"] = null
	# Kệ linh kiện bên trái (hai kệ gỗ xoay ra giữa tiệm), mỗi ngăn một loại có hộp màu.
	_prop(WP.model("wooden_bookshelf_worn", 1.1), -6.1, -2.4, PI / 2.0, 0.7, 1.6)
	_prop(WP.model("wooden_bookshelf_worn", 1.1), -6.1, 0.9, PI / 2.0, 0.7, 1.6)
	var parts: Array = cfg.parts.keys()
	for i in parts.size():
		var k: String = parts[i]
		var z := -3.0 + i * 1.6
		for j in 3:
			WP.box(_world, Vector3(0.22, 0.14, 0.22), WP.plain(_type_color(k), 0.5), Vector3(-6.0, 0.95, z - 0.3 + j * 0.3))
		_spot("shelf", -5.2, z, 1.1, _type_name(k)).merge({"key": k})
	# Tủ đồ nghề, xe dụng cụ, máy chờ sửa xếp góc.
	_prop(WP.model("metal_tool_chest", 1.2), 5.6, -4.9, 0.0, 0.9, 0.6)
	_prop(WP.model("industrial_storage_cart", 0.8), 3.9, -4.9, 0.0, 1.4, 0.9)
	var waiting := ["Quạt bàn", "Nồi cơm điện", "Máy bơm", "Quạt bàn", "Bàn ủi"]
	for i in waiting.size():
		_place_item(waiting[i], Vector3(4.6 + (i % 3) * 0.6, 0.0, -0.8 + (i / 3) * 0.7), _rng.randf_range(-0.5, 0.5))
	_blocks.append(Rect2(4.2, -1.2, 1.9, 1.4))
	_sign("SÁU SỬA ĐIỆN\nbáo giá trước khi sửa", 1.0, -5.48, 3.0, Color("1f4f8a"))
	_idlers.append(_person(Character.LOOKS.get("SAU", {}), 5.5, -3.6, -0.6))
	for x in [-3.0, 1.0, 5.0]:
		_lamp(x, -1.5)


func _counters() -> Array:
	return _spots.filter(func(s) -> bool: return s.type == "counter")


func _bench() -> Dictionary:
	for s in _spots:
		if s.type == "bench":
			return s
	return {}


func _repair_tick(delta: float) -> void:
	_cool_spawn -= delta
	var free := _counters().filter(func(s) -> bool: return s.cust == null)
	if _cool_spawn <= 0.0 and not free.is_empty():
		_cool_spawn = float(cfg.get("spawnEvery", 9.0)) * _rng.randf_range(0.7, 1.3)
		_customer(free[0])
	for s in _counters():
		if s.cust != null:
			s["wait"] = float(s.wait) - delta
			_counter_label(s)
			if float(s.wait) <= 0.0:
				_miss += 1
				_note("Khách chờ lâu quá, mang máy về.")
				_counter_leave(s)
	# Đứng ở bàn sửa có máy và đúng linh kiện thì sửa dần.
	var b := _bench()
	if not (b.machine as Dictionary).is_empty() and bool(b.machine.get("part_ok", false)) and not bool(b.machine.get("fixed", false)):
		if _dist(b) <= float(b.reach):
			b["progress"] = float(b.progress) + delta
			if float(b.progress) >= float(cfg.repairSec):
				b.machine["fixed"] = true
				_note("Sửa xong %s, đem trả khách." % str(b.machine.name).to_lower(), true)
		_bench_label(b)


func _customer(s: Dictionary) -> void:
	var machines: Array = cfg.machines
	var m: Dictionary = (machines[_rng.randi() % machines.size()] as Dictionary).duplicate()
	m["slot"] = _counters().find(s)
	m["fixed"] = false
	m["part_ok"] = false
	var c = _person(Character.random_look(_rng), (s.pos as Vector2).x, 4.7, PI)
	s["cust"] = c
	s["machine"] = m
	s["wait"] = float(cfg.get("patience", 70.0))
	s["node"] = _place_item(str(m.name), Vector3((s.pos as Vector2).x, 1.0, 3.6), PI)
	_counter_label(s)


func _counter_label(s: Dictionary) -> void:
	var l: Label3D = s.label
	if s.cust == null:
		l.text = ""
		return
	var m: Dictionary = s.machine
	var where := "" if m.is_empty() else ("\nđang ở bàn sửa" if not s.has("node") or s.node == null else "\n" + str(m.fault))
	l.text = "%s%s\n⏱ %d" % [str(m.name), where, ceili(float(s.wait))]
	l.modulate = Color(1, 0.55, 0.45) if float(s.wait) < 12.0 else Color(1, 1, 1)


func _counter_leave(s: Dictionary) -> void:
	var c: Node3D = s.cust
	s["cust"] = null
	if s.get("node") != null:
		(s.node as Node3D).queue_free()
	s["node"] = null
	# Máy của khách này đang trên tay hay trên bàn thì bỏ.
	var idx := _counters().find(s)
	_carry = _carry.filter(func(k) -> bool: return k != "may:%d" % idx)
	var b := _bench()
	if not (b.machine as Dictionary).is_empty() and int(b.machine.slot) == idx:
		_clear_bench(b)
	s["machine"] = {}
	_counter_label(s)
	if c != null:
		_walkers.append({"node": c, "to": Vector3(c.position.x + 6.0, 0, 6.5)})


func _bench_label(b: Dictionary) -> void:
	var l: Label3D = b.label
	var m: Dictionary = b.machine
	if m.is_empty():
		l.text = "Bàn sửa"
	elif bool(m.get("fixed", false)):
		l.text = "%s · sửa xong\nđem trả khách" % str(m.name)
	elif bool(m.get("part_ok", false)):
		l.text = "%s · đang sửa %d%%\n(đứng tại bàn)" % [str(m.name), int(100.0 * float(b.progress) / float(cfg.repairSec))]
	else:
		l.text = "%s · %s\ncần: %s" % [str(m.name), str(m.fault), _type_name(str(m.part))]


func _clear_bench(b: Dictionary) -> void:
	if b.get("node") != null:
		(b.node as Node3D).queue_free()
	b["node"] = null
	b["machine"] = {}
	b["progress"] = 0.0
	_bench_label(b)


func _repair_act(s: Dictionary) -> void:
	var b := _bench()
	match str(s.type):
		"counter":
			if s.cust == null:
				return
			var idx := _counters().find(s)
			var key := "may:%d" % idx
			if _carry.has(key):
				var m: Dictionary = s.machine
				if not bool(m.get("fixed", false)):
					_note("Máy chưa sửa, đặt lên bàn sửa đã.")
					return
				_carry.erase(key)
				_done += 1
				var fast := int(cfg.bonusPerFix) if float(s.wait) > float(cfg.get("patience", 70.0)) * 0.4 else int(cfg.bonusPerFix) / 3
				_bonus += fast
				_note("Khách nhận máy, trả tiền, +%s" % GameLogic.fmt_k(fast), true)
				s["node"] = null
				var c: Node3D = s.cust
				s["cust"] = null
				s["machine"] = {}
				_counter_label(s)
				_walkers.append({"node": c, "to": Vector3(c.position.x - 6.0, 0, 6.5)})
			elif s.node != null:
				if not _carry.is_empty():
					_note("Tay đang cầm đồ, cất đã.")
					return
				_carry.append(key)
				(s.node as Node3D).queue_free()
				s["node"] = null
				_counter_label(s)
			else:
				_note("Máy của khách này đang ở bàn sửa.")
		"bench":
			var m: Dictionary = b.machine
			var mine := _carry.filter(func(k) -> bool: return str(k).begins_with("may:"))
			if m.is_empty():
				if mine.is_empty():
					_note("Lấy máy của khách ở quầy đặt lên bàn.")
					return
				var key: String = mine[0]
				_carry.erase(key)
				var cs: Dictionary = _counters()[int(key.substr(4))]
				b["machine"] = cs.machine
				b["progress"] = 0.0
				b["node"] = _place_item(str(cs.machine.name), Vector3(0.6, 1.1, -3.3), PI)
				_bench_label(b)
			elif bool(m.get("fixed", false)):
				if not _carry.is_empty():
					_note("Tay đang cầm đồ.")
					return
				_carry.append("may:%d" % int(m.slot))
				(b.node as Node3D).queue_free()
				b["node"] = null
				b["machine"] = {}
				_bench_label(b)
			elif not bool(m.get("part_ok", false)):
				var parts := _carry.filter(func(k) -> bool: return str(k).begins_with("part:"))
				if parts.is_empty():
					_note("Cần %s, lấy ở kệ bên trái." % _type_name(str(m.part)).to_lower())
					return
				var want := "part:" + str(m.part)
				if not _carry.has(want):
					_note("Không phải hư chỗ này. Máy cần %s." % _type_name(str(m.part)).to_lower())
					return
				_carry.erase(want)
				m["part_ok"] = true
				_bench_label(b)
		"shelf":
			if _carry.size() >= 2:
				_note("Tay đầy rồi.")
				return
			_carry.append("part:" + str(s.key))
			_cool = 0.25


# ---------------------------------------------------------------- An: đi lại, cầm đồ

func _build_player() -> void:
	_player = Node3D.new()
	_world.add_child(_player)
	_body = Character.make(Character.LOOKS.get("AN", {}))
	_player.add_child(_body)
	_stack = Node3D.new()
	_stack.position = Vector3(0, 1.0, 0.45)
	_player.add_child(_stack)
	var ring := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.5
	disc.bottom_radius = 0.5
	disc.height = 0.02
	ring.mesh = disc
	var m := _mat(Color(0.95, 0.8, 0.3, 0.6))
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = m
	ring.position.y = 0.02
	_player.add_child(ring)
	_player.position = Vector3(0, 0, 1.5)
	_cam.position = _player.position + CAM_OFF
	_cam.look_at(_player.position + Vector3(0, 0.8, 0), Vector3.UP)


func _walkable(p: Vector2) -> bool:
	if not _bounds.grow(-BODY_R).has_point(p):
		return false
	for r in _blocks:
		if r.grow(BODY_R).has_point(p):
			return false
	return true


func _move(step: Vector2) -> Vector2:
	var p := Vector2(_player.position.x, _player.position.z)
	for s in [step, Vector2(step.x, 0), Vector2(0, step.y)]:
		if s != Vector2.ZERO and _walkable(p + s):
			return s
	return Vector2.ZERO


func _dist(s: Dictionary) -> float:
	return Vector2(_player.position.x, _player.position.z).distance_to(s.pos)


func _nearest_spot() -> Dictionary:
	var best := {}
	var best_d := INF
	for s in _spots:
		var d := _dist(s)
		if d <= float(s.reach) and d < best_d:
			best = s
			best_d = d
	return best


func _act(s: Dictionary) -> void:
	if _state != "play" or _cool > 0.0 or s.is_empty():
		return
	match _mode:
		"serve":
			_serve_act(s)
		"repair":
			_repair_act(s)
		_:
			_carry_act(s)
	_refresh_carry()


## Đồ trên tay: chồng hộp trước bụng, đổi theo món đang cầm.
func _refresh_carry() -> void:
	for c in _stack.get_children():
		c.queue_free()
	var y := 0.0
	for k in _carry:
		var key := str(k)
		var n: Node3D
		var h := 0.16
		if key.begins_with("may:"):
			var cs: Dictionary = _counters()[int(key.substr(4))]
			key = str(cs.machine.get("name", ""))
			h = 0.45
		if key.begins_with("part:"):
			n = Node3D.new()
			WP.box(n, Vector3(0.22, 0.14, 0.22), WP.plain(_type_color(key.substr(5)), 0.5), Vector3.ZERO)
		else:
			n = WP.item(key)
			h = WP.item_h(key) if not str(k).begins_with("may:") else h
		n.position = Vector3(0, y, 0)
		_stack.add_child(n)
		y += h + 0.01
	_body.hold("push" if not _carry.is_empty() else "")
	if is_instance_valid(_carry_l):
		var names := []
		for k in _carry:
			names.append(_carry_name(str(k)))
		_carry_l.text = "Đang cầm: " + (", ".join(names) if not names.is_empty() else "tay không")


func _carry_name(k: String) -> String:
	if k == "dirty":
		return "chồng bát dơ"
	if k.begins_with("may:"):
		var cs: Dictionary = _counters()[int(k.substr(4))]
		return str(cs.machine.get("name", "máy")).to_lower() + " của khách"
	if k.begins_with("part:"):
		return _type_name(k.substr(5)).to_lower()
	return _type_name(k).to_lower()


func _process(delta: float) -> void:
	_cool = maxf(0.0, _cool - delta)
	for c in _idlers:
		c.animate(delta, 0.0)
	_update_walkers(delta)
	if _note_t > 0.0:
		_note_t -= delta
		if _note_t <= 0.0 and is_instance_valid(_note_l):
			_note_l.text = ""
	var moving := 0.0
	if _state == "play":
		_time_left -= delta
		match _mode:
			"serve":
				_serve_tick(delta)
			"repair":
				_repair_tick(delta)
		var dir := Vector2.ZERO
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			dir.x -= 1
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			dir.x += 1
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			dir.y -= 1
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			dir.y += 1
		var step := Vector2.ZERO
		if dir != Vector2.ZERO:
			_target = null
			_pending = null
			step = _move(dir.normalized() * SPEED * delta)
		elif _target != null:
			var to: Vector2 = (_target as Vector2) - Vector2(_player.position.x, _player.position.z)
			if _pending != null and _dist(_pending) <= float(_pending.reach) * 0.85:
				var s: Dictionary = _pending
				_pending = null
				_target = null
				_act(s)
			elif to.length() < 0.08:
				_target = null
			else:
				step = _move(to.normalized() * minf(SPEED * delta, to.length()))
				if step == Vector2.ZERO:
					# Chạm vật cản: tới gần chỗ cần làm thì làm luôn, không thì dừng.
					if _pending != null and _dist(_pending) <= float(_pending.reach):
						_act(_pending)
					_pending = null
					_target = null
		if step != Vector2.ZERO:
			_player.position += Vector3(step.x, 0, step.y)
			_player.rotation.y = lerp_angle(_player.rotation.y, atan2(step.x, step.y), 0.3)
			moving = 1.0
		_update_hud()
		if _time_left <= 0.0:
			_show_end()
	_body.animate(delta, moving)
	var goal := _player.position + CAM_OFF
	_cam.position = _cam.position.lerp(goal, clampf(delta * 5.0, 0.0, 1.0))
	_cam.look_at(_cam.position - CAM_OFF + Vector3(0, 0.8, 0), Vector3.UP)


func _update_walkers(delta: float) -> void:
	for w in _walkers.duplicate():
		var n = w.node
		if not is_instance_valid(n):
			_walkers.erase(w)
			continue
		var to: Vector3 = (w.to as Vector3) - n.position
		to.y = 0
		if to.length() < 0.2:
			n.queue_free()
			_walkers.erase(w)
			continue
		n.position += to.normalized() * minf(3.0 * delta, to.length())
		n.rotation.y = atan2(to.x, to.z)
		n.animate(delta, 1.0)


func _input(event: InputEvent) -> void:
	if _state != "play":
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_E, KEY_SPACE, KEY_ENTER]:
		_act(_nearest_spot())
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if _state != "play":
		return
	var pos := Vector2.ZERO
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pos = event.position
	else:
		return
	accept_event()
	# Tọa độ màn hình đổi sang tọa độ khung nhìn 3D (khung nhìn co giãn theo cả màn).
	var vp_pos := pos * Vector2(_vp.size) / size
	var from := _cam.project_ray_origin(vp_pos)
	var dir := _cam.project_ray_normal(vp_pos)
	if absf(dir.y) < 0.001:
		return
	var hit := from + dir * (-from.y / dir.y)
	var g := Vector2(hit.x, hit.z)
	# Bấm gần một chỗ làm được (tính cả cái nhãn treo trên đầu) thì đi tới đó rồi làm.
	var best = null
	var best_d := 1.6
	for s in _spots:
		var d: float = (s.pos as Vector2).distance_to(g)
		var lab: Label3D = s.label
		if lab.text != "" and _cam.unproject_position(lab.global_position).distance_to(vp_pos) < 60.0:
			d = 0.0
		if d < best_d:
			best = s
			best_d = d
	if best != null:
		if _dist(best) <= float(best.reach):
			_act(best)
		else:
			_pending = best
			_target = best.pos
	else:
		_pending = null
		_target = g


# ---------------------------------------------------------------- giao diện

func _build_ui() -> void:
	_hud = PanelContainer.new()
	_hud.add_theme_stylebox_override("panel", UI.box(Color(0.06, 0.07, 0.12, 0.86), Color(1, 1, 1, 0.12), 12, 16))
	_hud.position = Vector2(20, 20)
	_hud.custom_minimum_size = Vector2(430, 0)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hud)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(v)
	_head_l = UI.label("", 12, UI.HUD_SOFT)
	v.add_child(_head_l)
	_goal_l = UI.label("", 20, UI.GOLD)
	v.add_child(_goal_l)
	_bar = UI.bar(10)
	_bar.max_value = 1.0
	v.add_child(_bar)
	_carry_l = UI.label("Đang cầm: tay không", 15, UI.HUD_TEXT)
	_carry_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_carry_l)
	_note_l = UI.label("", 15, Color("ffb38a"))
	_note_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note_l.custom_minimum_size = Vector2(400, 0)
	v.add_child(_note_l)
	_hint_l = UI.label("WASD hay bấm xuống sàn để đi · tới gần rồi bấm E (hay bấm thẳng vào chỗ đó) để lấy, đặt, sửa", 13, UI.HUD_TEXT)
	_hint_l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint_l.offset_top = -40
	_hint_l.offset_bottom = -14
	_hint_l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_hint_l.add_theme_constant_override("outline_size", 6)
	add_child(_hint_l)
	_menu_wrap = CenterContainer.new()
	_menu_wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_menu_wrap)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(600, 0)
	panel.add_theme_stylebox_override("panel", UI.box(UI.CARD, UI.LINE, 12, 22))
	_menu_wrap.add_child(panel)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 10)
	panel.add_child(_menu)


func _note(t: String, good := false) -> void:
	_note_l.text = t
	_note_l.add_theme_color_override("font_color", Color("8fe0a0") if good else Color("ffb38a"))
	_note_t = 3.0


func _goal_text() -> String:
	match _mode:
		"serve":
			return "Bưng đủ món %d/%d bàn" % [_done, int(cfg.target)]
		"repair":
			return "Sửa xong, trả khách %d/%d máy" % [_done, int(cfg.target)]
	return "%s %d/%d" % [str(cfg.get("goalWord", "Đầy pallet")), _done, int(cfg.target)]


func _update_hud() -> void:
	_goal_l.text = _goal_text()
	_bar.value = maxf(0.0, _time_left) / float(cfg.seconds)
	_head_l.text = "%s · %s · thưởng %s · còn %d giây" % [str(cfg.get("kicker", "")), title, GameLogic.fmt_k(_bonus), ceili(maxf(0.0, _time_left))]


func _clear_menu() -> void:
	for c in _menu.get_children():
		c.queue_free()


func _how_to() -> String:
	match _mode:
		"serve":
			return "Khách ngồi bàn gọi món (nhãn trên đầu). Tới quầy lấy món (cầm tối đa %d), bưng ra đúng bàn. Khách ăn xong để lại bát dơ: dọn bát đem ra chậu rửa thì được thưởng, bàn dơ thì khách mới không ngồi. Khách chờ lâu quá sẽ bỏ đi. Đủ %d bàn trong %d giây thì đủ công." % [int(cfg.carry), int(cfg.target), int(cfg.seconds)]
		"repair":
			return "Khách mang máy tới quầy. Lấy máy đặt lên bàn sửa, nhãn trên bàn ghi máy hư gì và cần linh kiện nào. Lấy đúng linh kiện ở kệ bên trái, đem tới bàn, đứng tại bàn cho tới khi sửa xong, rồi đem máy trả đúng khách. Trả %d máy trong %d giây thì đủ công; trả nhanh được thưởng thêm." % [int(cfg.target), int(cfg.seconds)]
	return "Tới đống hàng bên trái bưng (tối đa %d %s), đem sang chỗ xếp bên phải đúng loại nhãn ghi. Mỗi chỗ chỉ nhận một loại. Đủ %d chỗ trong %d giây thì đủ công; chỗ càng nhiều món thưởng càng cao." % [int(cfg.carry), str(cfg.get("unit", "món")), int(cfg.target), int(cfg.seconds)]


func _show_start() -> void:
	_state = "start"
	_hud.visible = false
	_hint_l.visible = false
	_menu_wrap.visible = true
	_menu_wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	_clear_menu()
	_menu.add_child(UI.label(title.to_upper() + " · " + str(cfg.get("kicker", "")), 12, UI.INK_SOFT))
	_menu.add_child(UI.wrap(str(cfg.get("heading", "Vào ca")), 26, UI.INK, 560))
	_menu.add_child(UI.wrap(_how_to(), 15, UI.INK, 560))
	_menu.add_child(UI.choice("Tự làm", "Vào chỗ làm, tự đi lại bưng, đặt, sửa", "", _start_play))
	if not last.is_empty():
		_menu.add_child(UI.choice("Làm tự động", "Như lần trước: %d%% công · thưởng %s" % [int(float(last.ratio) * 100.0), GameLogic.fmt_k(int(last.bonus))], "",
			func() -> void: finished.emit({"ratio": float(last.ratio), "bonus": int(last.bonus), "auto": true})))
	_menu.add_child(UI.choice("Thôi, không làm nữa", "", "", func() -> void: finished.emit({})))


func _start_play() -> void:
	_state = "play"
	_time_left = float(cfg.seconds)
	_menu_wrap.visible = false
	_menu_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.visible = true
	_hint_l.visible = true
	_cool_spawn = 0.5
	_update_hud()
	_refresh_carry()


func _ratio() -> float:
	return clampf(float(_done) / float(cfg.target), float(cfg.minRatio), 1.0)


func _show_end() -> void:
	_state = "end"
	_hud.visible = false
	_hint_l.visible = false
	_menu_wrap.visible = true
	_menu_wrap.mouse_filter = Control.MOUSE_FILTER_STOP
	_clear_menu()
	var ratio := _ratio()
	_menu.add_child(UI.label("HẾT CA", 12, UI.INK_SOFT))
	_menu.add_child(UI.wrap(_goal_text(), 26, UI.INK, 560))
	var lines := "Được %d%% tiền công, thưởng thêm %s." % [int(ratio * 100.0), GameLogic.fmt_k(_bonus)]
	if _done < int(cfg.target):
		lines += " Chưa đủ chỉ tiêu nên bị trừ công."
	if _miss > 0:
		lines += " %d khách bỏ đi vì chờ lâu." % _miss
	_menu.add_child(UI.wrap(lines, 15, UI.INK, 560))
	_menu.add_child(UI.choice("Nhận tiền", "", "", func() -> void: finished.emit({"ratio": ratio, "bonus": _bonus})))
