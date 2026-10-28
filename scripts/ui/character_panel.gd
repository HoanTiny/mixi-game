extends CanvasLayer
## Bảng Nhân vật (phím C, nút hình người trên thanh trên cùng, bấm vòng Phong độ), dựng theo bảng nhân vật của Nobody: trái là hành trang chia
## ngăn (Công cụ, Quần áo, Phế, Đồ giữ) với ô đồ vẽ tay và lời tả; giữa là An 3D đứng xoay được (kéo chuột), quanh là
## bốn ô đang dùng (đồ nghề, quần áo, điện thoại, chỗ ở); phải là trạng thái (mặt Phong độ, Tỉnh táo, No bụng, Vệ
## sinh, Quần áo), đặc điểm tính cách rút ra từ cách đã sống (game_logic.traits) và mối quan hệ với từng người.
## Nền là phố phía sau phủ shader vẽ mực tối của màn đầu.

const UI := preload("res://scripts/ui/ui_kit.gd")
const GameLogic := preload("res://scripts/game_logic.gd")
const TitleScreen := preload("res://scripts/ui/title_screen.gd")
const ItemIcon := preload("res://scripts/ui/item_icon.gd")
const Character := preload("res://scripts/world/character.gd")
const AnCharacter := preload("res://scripts/world/an_character.gd")
const Wardrobe := preload("res://scripts/wardrobe.gd")
const CREAM := Color("ece3d3")
const GOLDEN := Color("e8b45a")
const PANEL_BG := Color(0.1, 0.09, 0.08, 0.93)
const TABS := [["tools", "Công cụ"], ["clothes", "Quần áo"], ["scrap", "Phế"], ["keep", "Đồ giữ"]]
const BADGE_COLORS := ["c0392b", "8e44ad", "2e86c1", "16a085", "d35400", "7f8c8d", "27ae60", "b7950b"]

signal closed

var world
var game
var _root: Control
var _ink_mat: ShaderMaterial
var _tab := "tools"
var _tab_btns := {}
var _grid: GridContainer
var _sel := ""
var _item_title: Label
var _item_desc: Label
var _item_btn: Button
var _cash: Label
var _slots := {}
var _face: Control
var _pd_label: Label
var _bars := {}
## Trạng thái đang có (scripts/systems/survival.gd) và bốn thuộc tính {id: {bar, label}} (scripts/systems/attributes.gd).
var _conds: HFlowContainer
var _attrs := {}
var _traits: HFlowContainer
var _rels: VBoxContainer
var _view: SubViewport
var _turn: Node3D
var _body: Node3D
var _drag := false
var _spin := 0.0
var _portrait_camera: Camera3D
var _portrait_zoom := 1.0


func _ready() -> void:
	layer = 40
	visible = false
	var ink := ColorRect.new()
	ink.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ink_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = TitleScreen.INK_SHADER
	_ink_mat.shader = sh
	_ink_mat.set_shader_parameter("dim", 0.62)
	ink.material = _ink_mat
	ink.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(ink)
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = UI.make_theme()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 18)
	_root.add_child(m)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(row)
	_build_left(row)
	_build_center(row)
	_build_right(row)
	game.changed.connect(func() -> void:
		if visible:
			refresh())


func open() -> void:
	visible = true
	if _turn == null:
		_build_model()
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	closed.emit()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_C, KEY_I]:
		get_viewport().set_input_as_handled()
		close()


func _process(delta: float) -> void:
	if not visible or _turn == null:
		return
	# Keep the whole body in frame when the browser side panel is tall/narrow.
	# Zoom is relative to this fit, rather than a fixed FOV that clips shoulders.
	var aspect := maxf(0.1,float(_view.size.x)/maxf(1.0,float(_view.size.y)))
	var fitted_height := maxf(2.2,0.95/aspect)
	_portrait_camera.fov = clampf(rad_to_deg(2.0*atan(fitted_height/8.8))*_portrait_zoom,18.0,100.0)
	for slot in _slots.values(): slot.panel.visible=aspect>0.42
	if not _drag:
		_spin = lerpf(_spin, 0.0, clampf(delta * 1.5, 0.0, 1.0))
		_turn.rotation.y += _spin * delta
	if _body != null and _body.has_method("animate"):
		_body.animate(delta, 0.0)


# ---------------------------------------------------------------- khung chung

func _panel(parent: Control, width: float) -> VBoxContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = Color(0.42, 0.36, 0.27, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(16)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 10
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size.x = width
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	return v


## Đầu mục: vệt sơn vàng cam, chữ viết tay.
func _heading(parent: Control, text: String, width := 230.0) -> Control:
	var head := Control.new()
	head.custom_minimum_size = Vector2(width, 46)
	parent.add_child(head)
	var band := ColorRect.new()
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = TitleScreen.BRUSH_SHADER
	m.shader = sh
	m.set_shader_parameter("tint", Color(0.85, 0.6, 0.2, 0.95))
	band.material = m
	band.position = Vector2(-26, -4)
	band.size = Vector2(width, 56)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(band)
	var l := _hand(text, 28, Color("1c1712"))
	l.position = Vector2(0, 5)
	head.add_child(l)
	return head


func _hand(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", TitleScreen.HAND)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Nút chữ viết tay trên nền tối viền vàng (như màn đầu).
func _dark_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", TitleScreen.HAND)
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", GOLDEN)
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.18, 0.15, 0.11, 0.95) if st != "hover" else Color(0.26, 0.2, 0.13, 1.0)
		sb.border_color = Color(GOLDEN, 0.55 if st != "hover" else 0.95)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(3)
		b.add_theme_stylebox_override(st, sb)
	return b


func _text(text: String, size: int, color: Color) -> Label:
	var l := UI.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Ô đồ vật: khung tối viền sờn, hình vẽ ở giữa; viền xanh khi đang dùng, vàng khi đang chọn.
func _slot_box(size: float, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.16, 0.15, 0.14, 0.95)
	sb.border_color = border
	sb.set_border_width_all(3 if border.a > 0.6 else 2)
	sb.set_corner_radius_all(2)
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 3
	return sb


# ---------------------------------------------------------------- trái: hành trang

func _build_left(row: HBoxContainer) -> void:
	var v := _panel(row, 410)
	var top := HBoxContainer.new()
	v.add_child(top)
	_heading(top, "Hành trang")
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	_cash = _hand("", 26, GOLDEN)
	top.add_child(_cash)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	v.add_child(tabs)
	for t in TABS:
		var b := Button.new()
		b.text = t[1]
		b.custom_minimum_size = Vector2(88, 34)
		b.add_theme_font_override("font", TitleScreen.HAND)
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(func() -> void:
			_tab = t[0]
			_sel = ""
			refresh())
		tabs.add_child(b)
		_tab_btns[t[0]] = b
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	v.add_child(_grid)
	var line := ColorRect.new()
	line.color = Color(1, 1, 1, 0.12)
	line.custom_minimum_size.y = 1
	v.add_child(line)
	_item_title = _hand("", 26, CREAM)
	_item_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_item_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_item_title.custom_minimum_size.x = 370
	v.add_child(_item_title)
	_item_desc = _text("", 15, Color(CREAM, 0.85))
	_item_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_item_desc.custom_minimum_size.x = 370
	v.add_child(_item_desc)
	_item_btn = _dark_button("")
	_item_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_item_btn.custom_minimum_size = Vector2(160, 38)
	_item_btn.visible = false
	v.add_child(_item_btn)


## Đồ trong ngăn đang mở: [{id, name, kind, desc, count, used, action}].
func _items(tab: String) -> Array:
	var out := []
	if tab=="clothes" and str(game.cfg.get("anModel","rigged"))=="rigged":
		if game.s.get("inventory",{}).is_empty():
			out.append({"id":"an_base","name":"Áo caro và jeans của An","kind":"shirt","count":1,
				"used":str(game.wardrobe().worn.get("ao",""))=="" and str(game.wardrobe().worn.get("quan",""))=="",
				"group":"Quần áo","desc":"Bộ đồ mang theo từ nhà.\nMua thêm đồ tại shop si-đa Hàng Đào; cắt và nhuộm tóc ở tiệm tóc."})
		for id in game.s.get("inventory",{}):
			var item: Dictionary=game.s.inventory[id]
			var slot: String=str(item.slot)
			var bag_slot := "ao" if slot=="shirt" else "quan"
			var used: bool=str(game.s.equipped.get(slot,""))==id and str(game.wardrobe().worn.get(bag_slot,""))==""
			out.append({"id":id,"name":item.name,"kind":"shirt" if slot=="shirt" else "pants","count":1,"used":used,"group":"Quần áo",
				"desc":"Đồ đã sở hữu · Mặc không tốn tiền.\nMua thêm áo và jeans ở chợ; cắt, nhuộm tóc tại tiệm tóc."})
		for id in game.wardrobe().owned:
			var item: Dictionary=game.cloth(id)
			if str(item.get("slot","")) not in ["ao","quan"]: continue
			out.append({"id":id,"name":item.name,"kind":"shirt" if item.slot=="ao" else "pants","count":int(game.wardrobe().owned[id]),
				"used":str(game.wardrobe().worn.get(item.slot,""))==id,"group":"Quần áo","desc":"Đồ từ cửa hàng si-đa · Màu vải hiển thị trên cùng nhân vật An."})
		return out
	var cfg_items: Dictionary = game.cfg.get("items", {})
	match tab:
		"tools", "clothes":
			for it in cfg_items.get(tab, []):
				if game.check(it.get("when", {})) != "":
					continue
				var used: bool = it.has("slot") if tab == "tools" else str(it.id) == game.outfit()
				out.append({"id": it.id, "name": it.name, "kind": it.kind, "desc": it.desc, "count": 1, "used": used,
					"group": "Công cụ" if tab == "tools" else "Quần áo"})
		"scrap":
			for k in game.s.get("inv", {}):
				var n := int(game.s.inv[k])
				var price := int(game.cfg.scrap[k].price)
				out.append({"id": k, "name": str(game.cfg.scrap[k].name).substr(0, 1).to_upper() + str(game.cfg.scrap[k].name).substr(1), "kind": ItemIcon.kind_for(k), "count": n,
					"group": "Đồng nát", "desc": "%d cái · khoảng %s. Bán ở sạp đồng nát của cô Thắm, chợ Long Biên." % [n, GameLogic.fmt_money(n * price)]})
		"keep":
			for k in game.s.get("qitems", {}):
				out.append({"id": k, "name": game.item_name(k), "kind": ItemIcon.kind_for(k), "count": int(game.s.qitems[k]),
					"group": "Đồ việc nhờ", "desc": "Đang mang giúp người ta. Xem bước tiếp theo ở bảng mục tiêu."})
			for ks in game.keepsakes():
				out.append({"id": ks.id, "name": ks.name, "kind": ItemIcon.kind_for(str(ks.id)), "count": 1, "group": "Kỷ vật",
					"desc": str(ks.text).substr(0, 1).to_upper() + str(ks.text).substr(1)})
	return out


func _refresh_items() -> void:
	for k in _tab_btns:
		var b: Button = _tab_btns[k]
		var on: bool = k == _tab
		b.add_theme_color_override("font_color", Color("1c1712") if on else CREAM)
		b.add_theme_color_override("font_hover_color", Color("1c1712") if on else GOLDEN)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(CREAM, 0.95) if on else Color(0.2, 0.18, 0.16, 0.9)
		sb.border_color = Color(1, 1, 1, 0.5)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(3)
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, sb)
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	var items := _items(_tab)
	if _sel == "" and not items.is_empty():
		_sel = str(items[0].id)
	var chosen: Dictionary = {}
	for i in 12:
		var cell := Button.new()
		cell.custom_minimum_size = Vector2(84, 84)
		cell.focus_mode = Control.FOCUS_NONE
		if i < items.size():
			var it: Dictionary = items[i]
			var sel: bool = str(it.id) == _sel
			if sel:
				chosen = it
			var border := GOLDEN if sel else (Color("3ecf6a") if it.get("used", false) else Color(0.4, 0.37, 0.33, 0.8))
			for st in ["normal", "hover", "pressed"]:
				cell.add_theme_stylebox_override(st, _slot_box(84, border if st != "hover" else border.lightened(0.25)))
			var icon := ItemIcon.new(str(it.kind))
			icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			icon.offset_left = 10
			icon.offset_top = 12
			icon.offset_right = -10
			icon.offset_bottom = -8
			cell.add_child(icon)
			if it.get("used", false):
				var tag := UI.label("Đang dùng" if _tab == "tools" else "Đang mặc", 11, Color("3ecf6a"))
				tag.position = Vector2(5, 1)
				cell.add_child(tag)
			if int(it.count) > 1:
				var n := UI.label("×%d" % int(it.count), 14, CREAM)
				n.add_theme_color_override("font_outline_color", Color.BLACK)
				n.add_theme_constant_override("outline_size", 4)
				n.position = Vector2(54, 60)
				cell.add_child(n)
			cell.tooltip_text = str(it.name)
			var id := str(it.id)
			cell.pressed.connect(func() -> void:
				_sel = id
				_refresh_items())
		else:
			for st in ["normal", "hover", "pressed", "disabled"]:
				cell.add_theme_stylebox_override(st, _slot_box(84, Color(0.3, 0.28, 0.25, 0.6)))
			cell.disabled = true
		_grid.add_child(cell)
	_item_btn.visible = false
	if chosen.is_empty():
		_item_title.text = ""
		_item_desc.text = {"scrap": "Chưa có đồ đồng nát. Lục thùng rác dọc vỉa hè (đứng gần, bấm E) để nhặt chai, lon, bìa giấy.",
			"keep": "Chưa có gì. Đồ người ta nhờ mang và những món kỷ niệm sẽ nằm ở đây."}.get(_tab, "")
		return
	_item_title.text = "%s · %s" % [chosen.group, chosen.name]
	_item_desc.text = str(chosen.desc)
	if _tab == "clothes" and not chosen.used:
		_item_btn.visible = true
		_item_btn.text = "Mặc món này"
		for c in _item_btn.pressed.get_connections():
			_item_btn.pressed.disconnect(c.callable)
		var id := str(chosen.id)
		_item_btn.pressed.connect(func() -> void:
			if id=="an_base":
				game.wardrobe().worn.erase("ao"); game.wardrobe().worn.erase("quan"); game._commit()
			elif str(game.cfg.get("anModel","rigged"))=="rigged" and game.s.get("inventory",{}).has(id):
				game.wardrobe().worn.erase("ao" if game.s.inventory[id].slot=="shirt" else "quan")
				Wardrobe.equip(game,id)
			elif str(game.cfg.get("anModel","rigged"))=="rigged": game.wear_item(id)
			else: game.set_outfit(id))


# ---------------------------------------------------------------- giữa: An 3D và các ô đang dùng

func _build_center(row: HBoxContainer) -> void:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(c)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var backdrop_mat := ShaderMaterial.new()
	backdrop_mat.shader = preload("res://scripts/ui/portrait_backdrop.gdshader")
	backdrop.material = backdrop_mat
	c.add_child(backdrop)
	var box := SubViewportContainer.new()
	box.stretch = true
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_top = 10
	box.offset_bottom = -60
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.gui_input.connect(_on_drag)
	c.add_child(box)
	_view = SubViewport.new()
	_view.own_world_3d = true
	_view.transparent_bg = true
	_view.msaa_3d = Viewport.MSAA_4X
	_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	box.add_child(_view)
	var hint := UI.label("Kéo: xoay · Lăn: xem gần", 13, Color(CREAM, 0.7))
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position.y -= 50
	hint.position.x -= 55
	c.add_child(hint)
	# Bốn ô quanh người: trái trên đồ nghề, trái dưới điện thoại, phải trên quần áo, phải dưới chỗ ở.
	var specs := [["tool", "Công cụ", Vector2(-230, -170)], ["phone", "Điện thoại", Vector2(-230, 60)],
		["clothes", "Quần áo", Vector2(140, -130)], ["home", "Chỗ ở", Vector2(140, 100)]]
	for sp in specs:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", _slot_box(92, Color(0.55, 0.47, 0.33, 0.9)))
		p.custom_minimum_size = Vector2(92, 92)
		p.set_anchors_preset(Control.PRESET_CENTER)
		p.position = sp[2]
		p.mouse_filter = Control.MOUSE_FILTER_PASS
		c.add_child(p)
		var holder := Control.new()
		holder.custom_minimum_size = Vector2(92, 92)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_child(holder)
		var icon := ItemIcon.new("")
		icon.position = Vector2(12, 6)
		icon.size = Vector2(68, 64)
		holder.add_child(icon)
		var cap := UI.label(sp[1], 13, Color(CREAM, 0.8))
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cap.position = Vector2(0, 70)
		cap.size = Vector2(92, 18)
		holder.add_child(cap)
		_slots[sp[0]] = {"panel": p, "icon": icon, "cap": cap, "title": sp[1]}


func _build_model() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("c8d2da")
	e.ambient_light_energy = 0.35
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	_view.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, -35, 0)
	key.light_color = Color("fff1e0")
	key.light_energy = 0.55
	key.shadow_enabled = true
	_view.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15, 150, 0)
	rim.light_color = Color("c5d1df")
	rim.light_energy = 0.28
	_view.add_child(rim)
	var floor_mesh := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.55
	disc.bottom_radius = 0.6
	disc.height = 0.04
	floor_mesh.mesh = disc
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0, 0, 0, 0.35)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	floor_mesh.material_override = fm
	_view.add_child(floor_mesh)
	var cam := Camera3D.new()
	_portrait_camera = cam
	cam.fov = 30
	cam.position = Vector3(0, 1.0, 4.4)
	_view.add_child(cam)
	cam.look_at(Vector3(0, 0.9, 0), Vector3.UP)
	cam.current = true
	_turn = Node3D.new()
	_view.add_child(_turn)
	_turn.rotation.y = -0.35
	_dress()


## Dựng lại An trong khung xem theo bộ đang mặc.
func _dress() -> void:
	if str(game.cfg.get("anModel", "rigged")) == "rigged" and AnCharacter.available():
		if not (_body is AnCharacter):
			if is_instance_valid(_body):
				_turn.remove_child(_body)
				_body.queue_free()
			_body = AnCharacter.new()
			_turn.add_child(_body)
			_body.setup(Color.WHITE, Color.WHITE, "An")
		_body.apply_outfit(game)
		return
	var look := Character.an_look(game)
	if _body != null:
		if not (_body is AnCharacter) and str(_body.get("look").get("rb", "")) == str(look.rb):
			return
		_body.queue_free()
	_body = Character.make(look)
	_turn.add_child(_body)


func _on_drag(event: InputEvent) -> void:
	if _turn == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_drag = event.pressed
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_portrait_zoom = clampf(_portrait_zoom + (-0.06 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.06),0.75,1.12)
	elif event is InputEventMouseMotion and _drag:
		_turn.rotation.y += event.relative.x * 0.012
		_spin = event.relative.x * 0.4
	elif event is InputEventScreenDrag:
		_turn.rotation.y += event.relative.x * 0.012


func _refresh_slots() -> void:
	var tools: Array = game.cfg.get("items", {}).get("tools", [])
	var clothes: Array = game.cfg.get("items", {}).get("clothes", [])
	for it in tools:
		if it.has("slot") and _slots.has(it.slot):
			(_slots[it.slot].icon as Control).set("kind", it.kind)
			(_slots[it.slot].panel as Control).tooltip_text = str(it.name)
	for it in clothes:
		if str(it.id) == game.outfit():
			_slots.clothes.icon.set("kind", it.kind)
			(_slots.clothes.panel as Control).tooltip_text = str(it.name)
	if str(game.cfg.get("anModel","rigged"))=="rigged":
		_slots.clothes.icon.set("kind","shirt")
		var worn_names := PackedStringArray()
		for item in _items("clothes"):
			if item.used: worn_names.append(str(item.name))
		(_slots.clothes.panel as Control).tooltip_text = "\n".join(worn_names)
	_slots.home.icon.set("kind", "key")
	var home_name := ""
	if world != null and world.has_method("location_info"):
		home_name = str(world.location_info(game.home_loc()).get("name", ""))
	(_slots.home.panel as Control).tooltip_text = "Chỗ ở: " + home_name
	for k in _slots:
		(_slots[k].icon as Control).queue_redraw()


# ---------------------------------------------------------------- phải: trạng thái, đặc điểm, quan hệ

class Face extends Control:
	## Mặt Phong độ: tròn, màu theo mức, miệng cười hay mếu, mày nhíu khi tệ.
	var value := 100.0

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) * 0.42
		var col := Color("4cc46a") if value >= 55.0 else (Color("e8b45a") if value >= 30.0 else Color("e0604f"))
		draw_circle(c, r + 4, Color(0, 0, 0, 0.6))
		draw_circle(c, r, col.darkened(0.25))
		draw_circle(c - Vector2(r * 0.15, r * 0.15), r * 0.8, col)
		var ink := Color(0.08, 0.07, 0.06)
		draw_circle(c + Vector2(-r * 0.35, -r * 0.2), r * 0.1, ink)
		draw_circle(c + Vector2(r * 0.35, -r * 0.2), r * 0.1, ink)
		var smile := clampf((value - 45.0) / 45.0, -1.0, 1.0)
		var pts := PackedVector2Array()
		for i in 13:
			var t := i / 12.0
			var x := lerpf(-r * 0.45, r * 0.45, t)
			var y := r * 0.35 + smile * r * 0.25 * (1.0 - pow(2.0 * t - 1.0, 2.0))
			pts.append(c + Vector2(x, y))
		draw_polyline(pts, ink, 4.0, true)
		if value < 30.0:
			draw_line(c + Vector2(-r * 0.55, -r * 0.5), c + Vector2(-r * 0.2, -r * 0.38), ink, 3)
			draw_line(c + Vector2(r * 0.55, -r * 0.5), c + Vector2(r * 0.2, -r * 0.38), ink, 3)


func _build_right(row: HBoxContainer) -> void:
	var outer := _panel(row, 400)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 10)
	scroll.add_child(v)
	_heading(v, "Trạng thái")
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	v.add_child(top)
	var face_col := VBoxContainer.new()
	top.add_child(face_col)
	_face = Face.new()
	_face.custom_minimum_size = Vector2(96, 96)
	face_col.add_child(_face)
	_pd_label = _text("", 13, CREAM)
	_pd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pd_label.custom_minimum_size.x = 96
	face_col.add_child(_pd_label)
	var bars := VBoxContainer.new()
	bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bars.add_theme_constant_override("separation", 6)
	top.add_child(bars)
	var specs := [["rested", "Tỉnh táo", "moon", "100 trừ Mệt. Ngủ ở chỗ ở, nghỉ, ngồi trà đá để lại sức."],
		["mood", "Tâm trạng", "heart", "Nghỉ ngơi, trà đá, ăn cơm với bà, nói chuyện với người quen thì vui lên; việc bẩn, ngủ ngoài đường thì xuống."],
		["fed", "No bụng", "bowl", "Ăn ở Cơm Hạnh, bánh mì ở chợ Long Biên buổi sáng. Nhịn tới 0 thì Mệt tăng nhanh."],
		["clean", "Vệ sinh cá nhân", "drop", "Tắm ở chỗ ở. Việc bẩn (ca kho, phụ quán, lục rác) làm bẩn người."],
		["neat", "Quần áo", "tshirt", "Giặt đồ ở chỗ ở. Quần áo nhàu bẩn thì người ta ngại."]]
	for sp in specs:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 8)
		r.tooltip_text = sp[3]
		r.mouse_filter = Control.MOUSE_FILTER_PASS
		bars.add_child(r)
		var ic := ItemIcon.new(sp[2])
		ic.custom_minimum_size = Vector2(34, 34)
		r.add_child(ic)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 1)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.add_child(col)
		var lab := UI.label(sp[1], 13, CREAM)
		col.add_child(lab)
		var b := UI.bar(9)
		col.add_child(b)
		_bars[sp[0]] = {"bar": b, "label": lab, "title": sp[1]}
	_conds = HFlowContainer.new()
	_conds.add_theme_constant_override("h_separation", 8)
	_conds.add_theme_constant_override("v_separation", 8)
	v.add_child(_conds)
	_heading(v, "Thuộc tính")
	for at in game.Attributes.rows(game):
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 8)
		r.tooltip_text = str(at.desc)
		r.mouse_filter = Control.MOUSE_FILTER_PASS
		v.add_child(r)
		var ic := ItemIcon.new(str(at.icon), CREAM)
		ic.custom_minimum_size = Vector2(34, 34)
		r.add_child(ic)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 1)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.add_child(col)
		var lab := UI.label("", 13, CREAM)
		col.add_child(lab)
		var b := UI.bar(9)
		col.add_child(b)
		_attrs[at.id] = {"bar": b, "label": lab}
	_heading(v, "Đặc điểm tính cách", 290)
	_traits = HFlowContainer.new()
	_traits.add_theme_constant_override("h_separation", 8)
	_traits.add_theme_constant_override("v_separation", 8)
	v.add_child(_traits)
	_heading(v, "Mối quan hệ", 230)
	_rels = VBoxContainer.new()
	_rels.add_theme_constant_override("separation", 6)
	v.add_child(_rels)
	var close_btn := _dark_button("Đóng  (C)")
	close_btn.custom_minimum_size = Vector2(140, 38)
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_btn.pressed.connect(close)
	outer.add_child(close_btn)


func _refresh_status() -> void:
	var pd: float = game.phong_do()
	_face.set("value", pd)
	_face.queue_redraw()
	var mult: float = game.pay_mult()
	_pd_label.text = "Phong độ %d\n%s" % [int(pd), "đủ lương" if mult >= 1.0 else "%d%% lương" % int(mult * 100.0)]
	var vals := {"rested": 100.0 - float(game.s.fatigue), "mood": game.need("mood"), "fed": game.need("fed"), "clean": game.need("clean"), "neat": game.need("neat")}
	for k in _bars:
		var x: float = vals[k]
		UI.set_bar(_bars[k].bar, x, 100.0, UI.level_color(x / 100.0))
		(_bars[k].label as Label).text = "%s  %d/100" % [_bars[k].title, int(x)]
	for c in _conds.get_children():
		_conds.remove_child(c)
		c.queue_free()
	for t in game.Survival.active(game):
		_conds.add_child(_chip(str(t.name) + ("  · còn %d giờ" % ceili(float(t.left)) if float(t.left) >= 0.0 else ""), str(t.tone), str(t.desc)))
	for row in game.Attributes.rows(game):
		var full: bool = int(row.next) == 0
		UI.set_bar(_attrs[row.id].bar, 1.0 if full else float(row.xp), 1.0 if full else float(row.next), GOLDEN)
		(_attrs[row.id].label as Label).text = "%s  cấp %d%s" % [row.name, int(row.lv), "  · tối đa" if full else "  · %d/%d XP" % [int(row.xp), int(row.next)]]
	for c in _traits.get_children():
		_traits.remove_child(c)
		c.queue_free()
	for t in game.traits():
		_traits.add_child(_chip(str(t.name), str(t.tone), str(t.desc)))
	for c in _rels.get_children():
		_rels.remove_child(c)
		c.queue_free()
	var keys: Array = game.s.rep.keys()
	keys.sort_custom(func(a, b) -> bool: return int(game.s.rep[a]) > int(game.s.rep[b]))
	for i in keys.size():
		var k: String = keys[i]
		var val := int(game.s.rep[k])
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 10)
		_rels.add_child(r)
		var who: String = game.rep_label(k)
		var badge := PanelContainer.new()
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color(BADGE_COLORS[k.hash() % BADGE_COLORS.size()])
		bs.set_corner_radius_all(15)
		badge.add_theme_stylebox_override("panel", bs)
		badge.custom_minimum_size = Vector2(30, 30)
		var bl := UI.label(who.split(" ")[-1].substr(0, 1), 14, Color.WHITE)
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_child(bl)
		r.add_child(badge)
		var col2 := VBoxContainer.new()
		col2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col2.add_theme_constant_override("separation", 1)
		r.add_child(col2)
		var word := "Thân thiết" if val >= 70 else ("Quen" if val >= 45 else ("Xa cách" if val >= 25 else "Có hiềm khích"))
		col2.add_child(UI.label("%s · %s %d" % [who, word, val], 13, CREAM))
		var b := UI.bar(6)
		UI.set_bar(b, val, 100.0, Color("4cc46a") if val >= 60 else (GOLDEN if val >= 35 else Color("e0604f")))
		col2.add_child(b)


## Thẻ chữ viết tay nền màu theo tone (good xanh lá, bad cam, base xanh dương), rê chuột hiện lời tả.
func _chip(text: String, tone: String, desc: String) -> PanelContainer:
	var chip := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	var col: Color = {"good": Color("2f8f4e"), "bad": Color("c56a1d"), "base": Color("2e6f9e")}.get(tone, Color("555555"))
	sb.bg_color = col
	sb.border_color = col.lightened(0.35)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	chip.add_theme_stylebox_override("panel", sb)
	chip.tooltip_text = desc
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	chip.add_child(_hand(text, 20, Color.WHITE))
	return chip


func refresh() -> void:
	if not game.is_started():
		close()
		return
	_cash.text = GameLogic.fmt_money(int(game.s.cash))
	if _turn != null:
		_dress()
	_refresh_items()
	_refresh_slots()
	_refresh_status()
