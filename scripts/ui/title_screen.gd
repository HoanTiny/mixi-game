extends CanvasLayer
## Màn đầu game (giống nhịp các game mô phỏng đời sống): màn tiêu đề trên nền phố vẽ mực, chọn câu chuyện, chọn độ
## khó, rồi mở đầu bằng tin nhắn trên điện thoại trước khi vào ngày 1. Nền là chính màn phố 3D nhìn qua máy quay dựng
## cảnh (world.gd nhường máy quay khi title_open), phủ shader vẽ mực: viền nét, màu ngả nâu, vân giấy, tối bốn góc.
## Cài đặt (âm lượng, toàn màn hình, độ khó, bóng nắng) lưu ở user://settings.json, nạp khi vào game.

const UI := preload("res://scripts/ui/ui_kit.gd")
const GameLogic := preload("res://scripts/game_logic.gd")
const SETTINGS := "user://settings.json"
const VERSION := "Bản 1.10.1 · quan hệ và buôn bán"
const BRUSH := preload("res://assets/fonts/SedgwickAveDisplay-Regular.ttf")
const HAND := preload("res://assets/fonts/PatrickHand-Regular.ttf")
const CREAM := Color("ece3d3")
const RUST := Color("b4532a")
const GOLDEN := Color("e8b45a")

const INK_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
// dim: làm tối nền khi có bảng đè lên; warm: độ ngả nâu.
uniform float dim = 0.0;
uniform float warm = 0.6;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float lum(vec3 c) { return dot(c, vec3(0.299, 0.587, 0.114)); }
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE * 1.4;
	vec3 c = textureLod(screen_tex, uv, 0.0).rgb;
	// Viền nét mực: Sobel trên độ sáng.
	float tl = lum(textureLod(screen_tex, uv + px * vec2(-1, -1), 0.0).rgb);
	float t = lum(textureLod(screen_tex, uv + px * vec2(0, -1), 0.0).rgb);
	float tr = lum(textureLod(screen_tex, uv + px * vec2(1, -1), 0.0).rgb);
	float l = lum(textureLod(screen_tex, uv + px * vec2(-1, 0), 0.0).rgb);
	float r = lum(textureLod(screen_tex, uv + px * vec2(1, 0), 0.0).rgb);
	float bl = lum(textureLod(screen_tex, uv + px * vec2(-1, 1), 0.0).rgb);
	float b = lum(textureLod(screen_tex, uv + px * vec2(0, 1), 0.0).rgb);
	float br = lum(textureLod(screen_tex, uv + px * vec2(1, 1), 0.0).rgb);
	float gx = -tl - 2.0 * l - bl + tr + 2.0 * r + br;
	float gy = -tl - 2.0 * t - tr + bl + 2.0 * b + br;
	float edge = smoothstep(0.1, 0.42, length(vec2(gx, gy)));
	// Màu: bớt rực, ngả nâu, gom bậc như tranh in.
	float y = lum(c);
	vec3 sepia = vec3(y) * vec3(1.08, 0.9, 0.72);
	vec3 col = mix(c, sepia, warm);
	col = floor(col * 7.0 + 0.5) / 7.0 * 0.6 + col * 0.4;
	// Vân giấy, lấm tấm mực.
	float grain = noise(FRAGCOORD.xy / 3.0) * 0.6 + noise(FRAGCOORD.xy / 40.0) * 0.4;
	col *= 0.86 + 0.2 * grain;
	col = mix(col, vec3(0.09, 0.07, 0.06), edge * 0.8);
	// Tối bốn góc.
	vec2 d = uv - 0.5;
	float v = smoothstep(0.95, 0.3, length(d * vec2(1.15, 1.0)));
	col *= mix(0.25, 1.0, v);
	col = mix(col, col * 0.3, dim);
	COLOR = vec4(col, 1.0);
}
"""

## Vệt sơn bút lông sau tiêu đề, sau tên câu chuyện, đầu bảng: dải màu mép xơ.
const BRUSH_SHADER := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.71, 0.33, 0.16, 0.92);
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void fragment() {
	vec2 uv = UV;
	float edge_y = abs(uv.y - 0.5) * 2.0;
	float rough = noise(vec2(uv.x * 30.0, uv.y * 3.0)) * 0.35 + noise(vec2(uv.x * 140.0, uv.y * 8.0)) * 0.2;
	float a = 1.0 - smoothstep(0.55, 0.75, edge_y + rough * 0.6);
	// Đầu, cuối vệt quét mỏng dần, có sợi lông.
	a *= smoothstep(0.0, 0.08 + rough * 0.15, uv.x) * smoothstep(1.0, 0.82 - rough * 0.2, uv.x);
	a *= 0.75 + 0.25 * noise(vec2(uv.x * 220.0, uv.y * 40.0));
	COLOR = vec4(tint.rgb * (0.85 + 0.25 * noise(uv * vec2(60.0, 6.0))), tint.a * a);
}
"""

signal started

var world
var game
var _ink: ColorRect
var _ink_mat: ShaderMaterial
var _pages := {}
var _page := ""
var _story_idx := 0
var _stories: Array = []
var _story_name: Label
var _story_desc: Label
var _story_meta: Label
var _story_list: VBoxContainer
var _diff := "thuong"
var _modal: Control
## Máy quay dựng cảnh: điểm đặt, điểm nhìn, thời gian (cho máy quay đung đưa chậm).
var _shot := {}
var _t := 0.0
# Tin nhắn mở đầu.
var _chat_i := 0
var _msg_i := 0
var _chat_box: VBoxContainer
var _chat_name: Label
var _chat_badge: Label
var _chat_wait := 0.0
var _chat_scroll: ScrollContainer
var _chat_done := false


static func load_settings() -> Dictionary:
	if not FileAccess.file_exists(SETTINGS):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS))
	return d if d is Dictionary else {}


static func save_settings(d: Dictionary) -> void:
	var f := FileAccess.open(SETTINGS, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d))


## Áp cài đặt đã lưu khi vào game: âm lượng, toàn màn hình (bản cài trên máy), bóng nắng nhẹ.
static func apply_settings(d: Dictionary) -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(float(d.get("volume", 0.8)), 0.001)))
	AudioServer.set_bus_mute(bus, float(d.get("volume", 0.8)) <= 0.001)
	if not OS.has_feature("web") and d.has("fullscreen"):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if bool(d.fullscreen) else DisplayServer.WINDOW_MODE_WINDOWED)
	if d.has("light_shadows"):
		ScreenFit.light_shadows = bool(d.light_shadows) or ScreenFit.low_power


func _ready() -> void:
	layer = 90
	_diff = str(load_settings().get("difficulty", "thuong"))
	_ink = ColorRect.new()
	_ink.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ink_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = INK_SHADER
	_ink_mat.shader = sh
	_ink.material = _ink_mat
	_ink.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_ink)
	_build_title()
	_build_stories()
	_build_intro()
	show_page("title")


func _process(delta: float) -> void:
	_t += delta
	if not _shot.is_empty() and world != null:
		# Máy quay đung đưa rất chậm như đang thở.
		var sway := Vector3(sin(_t * 0.23) * 0.35, sin(_t * 0.31) * 0.15, 0.0)
		world.camera.position = (_shot.from as Vector3) + sway
		world.camera.look_at(_shot.at, Vector3.UP)
	if _page == "intro" and not _chat_done:
		_chat_wait -= delta
		if _chat_wait <= 0.0:
			_next_msg()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _page == "intro" and (event is InputEventMouseButton and event.pressed or event is InputEventKey and event.pressed and event.keycode in [KEY_SPACE, KEY_ENTER]):
		# Bấm để tin nhắn tới nhanh hơn; hết tin thì vào game.
		get_viewport().set_input_as_handled()
		if _chat_done:
			_begin()
		else:
			_chat_wait = 0.0
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and _page == "stories":
		get_viewport().set_input_as_handled()
		show_page("title")


# ---------------------------------------------------------------- trang

func show_page(name: String) -> void:
	_page = name
	visible = true
	for k in _pages:
		(_pages[k] as Control).visible = k == name
	_close_modal()
	var dim := {"title": 0.0, "stories": 0.25, "intro": 0.55}
	_ink_mat.set_shader_parameter("dim", dim.get(name, 0.0))
	_set_shot(name)
	if name == "title":
		_refresh_title()
	elif name == "intro":
		_start_chats()


## Góc máy quay cho từng trang: tiêu đề nhìn ngước lên cột điện, dây điện, dãy nhà ống; chọn truyện nhìn sân xóm trọ;
## tin nhắn nhìn xuống đầu hẻm lúc sáng sớm.
func _set_shot(name: String) -> void:
	if world == null:
		return
	var base: Vector3 = world.door_of("xom_bo_me") if world.city.locs.has("xom_bo_me") else world.player.position
	match name:
		"stories":
			_shot = {"from": base + Vector3(-6.0, 4.5, 9.0), "at": base + Vector3(1.0, 1.0, -2.0)}
		"intro":
			_shot = {"from": base + Vector3(3.0, 2.2, 7.5), "at": base + Vector3(-1.0, 1.4, 0.0)}
		_:
			# Màn tiêu đề đứng giữa phố Bờ Me trước quán cơm, nhìn dọc dãy nhà ống, dây điện, quán cóc.
			var street: Vector3 = world.door_of("com_hanh") if world.city.locs.has("com_hanh") else base
			_shot = _title_shot(street)


## Màn tiêu đề: đứng đầu hẻm trước xóm trọ, nhìn dọc dãy nhà ống, ban công, mái tôn tới cuối hẻm.
func _title_shot(base: Vector3) -> Dictionary:
	return {"from": base + Vector3(-14.0, 2.0, 8.0), "at": base + Vector3(10.0, 6.0, -2.0)}


func _page_root(name: String) -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	_pages[name] = c
	return c


# ---------------------------------------------------------------- màn tiêu đề

var _menu: VBoxContainer
var _title_note: Label


func _build_title() -> void:
	var root := _page_root("title")
	var col := VBoxContainer.new()
	col.position = Vector2(70, 50)
	col.add_theme_constant_override("separation", 0)
	root.add_child(col)
	var title_box := Control.new()
	title_box.custom_minimum_size = Vector2(760, 210)
	col.add_child(title_box)
	var stroke := _brush_band(Color(0.45, 0.18, 0.08, 0.85))
	stroke.position = Vector2(-30, 40)
	stroke.size = Vector2(700, 150)
	title_box.add_child(stroke)
	var big := Label.new()
	big.text = "TRÊN PHỐ"
	big.add_theme_font_override("font", BRUSH)
	big.add_theme_font_size_override("font_size", 92)
	big.add_theme_color_override("font_color", CREAM)
	big.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.04))
	big.add_theme_constant_override("outline_size", 10)
	big.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	big.add_theme_constant_override("shadow_offset_x", 4)
	big.add_theme_constant_override("shadow_offset_y", 5)
	big.position = Vector2(0, 30)
	big.rotation = -0.035
	title_box.add_child(big)
	var sub := Label.new()
	sub.text = "Trước mùa mưa · ba mươi ngày ở phố cổ Hà Nội"
	sub.add_theme_font_override("font", HAND)
	sub.add_theme_font_size_override("font_size", 28)
	sub.add_theme_color_override("font_color", GOLDEN)
	sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	sub.add_theme_constant_override("outline_size", 6)
	sub.position = Vector2(300, 150)
	title_box.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size.y = 120
	col.add_child(gap)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 6)
	col.add_child(_menu)
	_title_note = Label.new()
	_title_note.text = VERSION
	_title_note.add_theme_font_size_override("font_size", 13)
	_title_note.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	_title_note.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_title_note.position -= Vector2(180, 36)
	root.add_child(_title_note)


func _refresh_title() -> void:
	for c in _menu.get_children():
		_menu.remove_child(c)
		c.queue_free()
	if game.is_started():
		var where := "Ngày %d · %s" % [game.day(), GameLogic.fmt_money(int(game.s.cash))] if not game.is_over() else "Đã tới màn kết"
		_menu_item("Chơi tiếp", where, func() -> void: _close())
	_menu_item("Bắt đầu", "", func() -> void: show_page("stories"))
	_menu_item("Cài đặt", "", _open_settings)
	_menu_item("Giới thiệu", "", _open_about)
	if not OS.has_feature("web"):
		_menu_item("Thoát", "", func() -> void: get_tree().quit())


## Mục menu chữ viết tay: rê chuột vào thì sáng lên, có mũi tên đầu dòng.
func _menu_item(text: String, sub: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.flat = true
	b.text = "   " + text + ("    " + sub if sub != "" else "")
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", HAND)
	b.add_theme_font_size_override("font_size", 34)
	b.add_theme_color_override("font_color", Color(CREAM, 0.82))
	b.add_theme_color_override("font_hover_color", GOLDEN)
	b.add_theme_color_override("font_pressed_color", GOLDEN)
	b.add_theme_color_override("font_focus_color", GOLDEN)
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	b.add_theme_constant_override("outline_size", 6)
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, empty)
	b.mouse_entered.connect(func() -> void: b.text = "➤ " + text + ("    " + sub if sub != "" else ""))
	b.mouse_exited.connect(func() -> void: b.text = "   " + text + ("    " + sub if sub != "" else ""))
	b.pressed.connect(on_press)
	_menu.add_child(b)
	return b


func _brush_band(tint: Color) -> ColorRect:
	var r := ColorRect.new()
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = BRUSH_SHADER
	m.shader = sh
	m.set_shader_parameter("tint", tint)
	r.material = m
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


# ---------------------------------------------------------------- chọn câu chuyện

func _build_stories() -> void:
	_stories = [{"id": "full", "name": "Trước mùa mưa", "meta": "Truyện chính · 5 chương · 150 ngày · 1.200.000đ tiền mặt",
		"desc": str(game.story.prologue.text)}]
	for k in GameLogic.ROUTES:
		var pre: Dictionary = game.cfg.presets[k]
		_stories.append({"id": k, "name": "Lát cắt · " + str(pre.name), "meta": "Thử nhanh ngày 18–22 · tuyến đã chọn ở ngày 11",
			"desc": str(pre.get("desc", ""))})
	_stories.append({"id": "realmap", "name": "Dựng khu thật", "meta": "Hộp cát · ngoài truyện · cần mạng",
		"desc": "Gõ tên một phường, một con phố ở bất cứ đâu trên đất nước: game lấy nhà, đường, sông hồ từ OpenStreetMap và Open Buildings, dựng thành mô hình phố để đi dạo. Vỉa hè, lề đường lát theo kiểu của vùng đó."})
	var root := _page_root("stories")
	var head := Label.new()
	head.text = "Câu chuyện của bạn"
	head.add_theme_font_override("font", HAND)
	head.add_theme_font_size_override("font_size", 46)
	head.add_theme_color_override("font_color", CREAM)
	head.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	head.add_theme_constant_override("outline_size", 6)
	head.position = Vector2(60, 36)
	root.add_child(head)
	_story_list = VBoxContainer.new()
	_story_list.position = Vector2(56, 130)
	_story_list.add_theme_constant_override("separation", 4)
	root.add_child(_story_list)
	for i in _stories.size():
		var b := Button.new()
		b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_override("font", HAND)
		b.add_theme_font_size_override("font_size", 28)
		b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
		b.add_theme_constant_override("outline_size", 5)
		var empty := StyleBoxEmpty.new()
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, empty)
		b.pressed.connect(_pick_story.bind(i))
		_story_list.add_child(b)
	# Khung bên phải: vệt sơn tên câu chuyện, lời giới thiệu, thông tin.
	var right := VBoxContainer.new()
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.position = Vector2(-560, 120)
	right.custom_minimum_size = Vector2(500, 0)
	right.add_theme_constant_override("separation", 14)
	root.add_child(right)
	var band := Control.new()
	band.custom_minimum_size = Vector2(500, 96)
	right.add_child(band)
	var stroke := _brush_band(Color(0.13, 0.33, 0.47, 0.9))
	stroke.position = Vector2(0, 6)
	stroke.size = Vector2(500, 86)
	band.add_child(stroke)
	_story_name = Label.new()
	_story_name.add_theme_font_override("font", HAND)
	_story_name.add_theme_font_size_override("font_size", 40)
	_story_name.add_theme_color_override("font_color", Color.WHITE)
	_story_name.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_story_name.add_theme_constant_override("outline_size", 4)
	_story_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_story_name.position = Vector2(0, 22)
	_story_name.size = Vector2(500, 56)
	band.add_child(_story_name)
	_story_desc = Label.new()
	_story_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_story_desc.custom_minimum_size = Vector2(500, 0)
	_story_desc.add_theme_font_size_override("font_size", 17)
	_story_desc.add_theme_color_override("font_color", CREAM)
	_story_desc.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_story_desc.add_theme_constant_override("outline_size", 5)
	_story_desc.add_theme_constant_override("line_spacing", 4)
	right.add_child(_story_desc)
	_story_meta = Label.new()
	_story_meta.add_theme_font_size_override("font_size", 14)
	_story_meta.add_theme_color_override("font_color", GOLDEN)
	_story_meta.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_story_meta.add_theme_constant_override("outline_size", 4)
	right.add_child(_story_meta)
	# Nút dưới phải.
	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	row.position = Vector2(-380, -86)
	row.add_theme_constant_override("separation", 16)
	root.add_child(row)
	row.add_child(_dark_button("Quay lại", func() -> void: show_page("title")))
	row.add_child(_dark_button("Vào game", _confirm_story))
	_pick_story(0)


func _pick_story(i: int) -> void:
	_story_idx = i
	var buttons := _story_list.get_children()
	for j in buttons.size():
		var b: Button = buttons[j]
		b.text = ("➤ " if j == i else "   ") + str(_stories[j].name)
		b.add_theme_color_override("font_color", GOLDEN if j == i else Color(CREAM, 0.75))
		b.add_theme_color_override("font_hover_color", GOLDEN)
	var st: Dictionary = _stories[i]
	_story_name.text = str(st.name)
	_story_desc.text = str(st.desc)
	_story_meta.text = str(st.meta)


## Nút chữ trên nền tối viền vàng (Quay lại, Vào game, Xác nhận).
func _dark_button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(170, 48)
	b.add_theme_font_override("font", HAND)
	b.add_theme_font_size_override("font_size", 26)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", GOLDEN)
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.08, 0.06, 0.88) if st != "hover" else Color(0.18, 0.13, 0.08, 0.95)
		sb.border_color = Color(GOLDEN, 0.55 if st != "hover" else 0.95)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(4)
		b.add_theme_stylebox_override(st, sb)
	b.pressed.connect(on_press)
	return b


func _confirm_story() -> void:
	var st: Dictionary = _stories[_story_idx]
	if str(st.id) == "realmap":
		get_tree().change_scene_to_file("res://scenes/realmap.tscn")
		return
	if game.is_started() and not game.is_over():
		_ask_overwrite()
		return
	_open_difficulty()


## Đang có ván chơi dở: hỏi trước khi chơi lại từ đầu.
func _ask_overwrite() -> void:
	var v := _modal_panel("Chơi lại từ đầu?")
	var t := _modal_text("Ván đang chơi (ngày %d, %s) sẽ bị xóa để bắt đầu câu chuyện mới." % [game.day(), GameLogic.fmt_money(int(game.s.cash))])
	v.add_child(t)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	row.add_child(_dark_button("Hủy", _close_modal))
	row.add_child(_dark_button("Chơi lại", func() -> void:
		_close_modal()
		_open_difficulty()))


# ---------------------------------------------------------------- bảng nổi (độ khó, cài đặt, giới thiệu)

func _modal_panel(title: String, width := 560.0) -> VBoxContainer:
	_close_modal()
	_modal = Control.new()
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_modal)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal.add_child(center)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.13, 0.1, 0.08, 0.96)
	sb.border_color = Color(GOLDEN, 0.7)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(0)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 16
	panel.add_theme_stylebox_override("panel", sb)
	panel.custom_minimum_size = Vector2(width, 0)
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	# Đầu bảng: vệt sơn cam, tên bảng chữ bút lông.
	var head := Control.new()
	head.custom_minimum_size = Vector2(width, 64)
	v.add_child(head)
	var stroke := _brush_band(Color(0.78, 0.4, 0.12, 0.95))
	stroke.position = Vector2(-10, 4)
	stroke.size = Vector2(width * 0.62, 58)
	head.add_child(stroke)
	var t := Label.new()
	t.text = title
	t.add_theme_font_override("font", HAND)
	t.add_theme_font_size_override("font_size", 34)
	t.add_theme_color_override("font_color", Color.WHITE)
	t.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.5))
	t.add_theme_constant_override("outline_size", 4)
	t.position = Vector2(22, 10)
	head.add_child(t)
	var pad := MarginContainer.new()
	for side in ["left", "right", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 26)
	v.add_child(pad)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	pad.add_child(body)
	return body


func _modal_text(text: String, size := 16) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", CREAM)
	return l


func _close_modal() -> void:
	if _modal != null:
		_modal.queue_free()
		_modal = null


## Ô chọn: dấu chọn vẽ bằng chữ (○ ●, ☐ ☑) cho rõ trên nền tối, thay biểu tượng mặc định màu xám khó thấy.
func _check(text: String, on: bool, group: ButtonGroup = null) -> CheckBox:
	var c := CheckBox.new()
	var marks := ["○  ", "●  "] if group != null else ["☐  ", "☑  "]
	c.text = marks[int(on)] + text
	c.button_pressed = on
	c.button_group = group
	var none := ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8))
	for icon in ["checked", "unchecked", "radio_checked", "radio_unchecked", "checked_disabled", "unchecked_disabled",
			"radio_checked_disabled", "radio_unchecked_disabled"]:
		c.add_theme_icon_override(icon, none)
	c.toggled.connect(func(pressed: bool) -> void: c.text = marks[int(pressed)] + text)
	c.add_theme_font_override("font", HAND)
	c.add_theme_font_size_override("font_size", 26)
	c.add_theme_color_override("font_color", CREAM)
	c.add_theme_color_override("font_pressed_color", GOLDEN)
	c.add_theme_color_override("font_hover_color", GOLDEN)
	return c


func _open_difficulty() -> void:
	var v := _modal_panel("Chọn độ khó")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 60)
	v.add_child(row)
	var group := ButtonGroup.new()
	var diffs: Dictionary = game.cfg.difficulty
	var desc := _modal_text(str(diffs[_diff].desc))
	for k in ["de", "thuong"]:
		var c := _check(str(diffs[k].name), _diff == k, group)
		c.toggled.connect(func(on: bool) -> void:
			if on:
				_diff = k
				desc.text = str(diffs[k].desc))
		row.add_child(c)
	v.add_child(desc)
	var ok := _dark_button("Xác nhận", func() -> void:
		var st := load_settings()
		st["difficulty"] = _diff
		save_settings(st)
		_close_modal()
		var id := str(_stories[_story_idx].id)
		if id == "full":
			show_page("intro")
		else:
			_begin(id))
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ok)
	var foot := _modal_text("*Có thể đổi lại trong Cài đặt ở màn đầu.", 13)
	foot.add_theme_color_override("font_color", Color(CREAM, 0.6))
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(foot)


func _open_settings() -> void:
	var st := load_settings()
	var v := _modal_panel("Cài đặt")
	v.add_child(_modal_text("Âm lượng"))
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.05
	vol.value = float(st.get("volume", 0.8))
	vol.custom_minimum_size = Vector2(380, 24)
	vol.value_changed.connect(func(x: float) -> void:
		st["volume"] = x
		apply_settings(st)
		save_settings(st))
	v.add_child(vol)
	if not OS.has_feature("web"):
		var fs := _check("Toàn màn hình", DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN)
		fs.toggled.connect(func(on: bool) -> void:
			st["fullscreen"] = on
			apply_settings(st)
			save_settings(st))
		v.add_child(fs)
	var shadows := _check("Bóng nắng nhẹ (máy yếu chạy mượt hơn)", ScreenFit.light_shadows)
	shadows.toggled.connect(func(on: bool) -> void:
		st["light_shadows"] = on
		apply_settings(st)
		save_settings(st))
	v.add_child(shadows)
	v.add_child(_modal_text("Độ khó" + (" (đổi luôn cho ván đang chơi)" if game.is_started() else "")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	v.add_child(row)
	var group := ButtonGroup.new()
	var cur: String = game.difficulty() if game.is_started() else str(st.get("difficulty", "thuong"))
	for k in ["de", "thuong"]:
		var c := _check(str(game.cfg.difficulty[k].name), cur == k, group)
		c.toggled.connect(func(on: bool) -> void:
			if on:
				_diff = k
				st["difficulty"] = k
				save_settings(st)
				game.set_difficulty(k))
		row.add_child(c)
	var close := _dark_button("Xong", _close_modal)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(close)


func _open_about() -> void:
	var v := _modal_panel("Giới thiệu", 620.0)
	v.add_child(_modal_text("Trên Phố là game mô phỏng đời sống ở phố cổ Hà Nội. Truyện chính Trước mùa mưa: An, 27 tuổi, vừa mất việc ở tiệm điện máy, cả nhà còn ba mươi ngày để dọn khỏi xóm trọ Phúc Tân ngoài đê sông Hồng trước mùa mưa. Kiếm tiền bằng các việc làm có thật ngoài phố, lo ăn ngủ tắm giặt, nói chuyện với hàng xóm, và chọn: lo một mình, hay để người khác cùng lo.", 16))
	v.add_child(_modal_text("Phố dựng theo phố cổ Hà Nội (tên phố thật, bố cục giản lược); bản đồ thật ven kênh Tàu Hủ từ OpenStreetMap, Open Buildings. Người: Microsoft Rocketbox (MIT). Đồ vật, vật liệu: Poly Haven (CC0). Chữ: Sedgwick Ave Display, Patrick Hand (SIL OFL). Làm bằng Godot.", 14))
	var close := _dark_button("Đóng", _close_modal)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(close)


# ---------------------------------------------------------------- tin nhắn mở đầu

func _build_intro() -> void:
	var root := _page_root("intro")
	var intro: Dictionary = game.story.prologue.get("intro", {})
	var cap := Label.new()
	cap.text = str(intro.get("caption", "Ngày 1"))
	cap.add_theme_font_override("font", HAND)
	cap.add_theme_font_size_override("font_size", 44)
	cap.add_theme_color_override("font_color", CREAM)
	cap.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	cap.add_theme_constant_override("outline_size", 6)
	cap.position = Vector2(70, 70)
	root.add_child(cap)
	var place := Label.new()
	place.text = str(intro.get("place", ""))
	place.add_theme_font_size_override("font_size", 18)
	place.add_theme_color_override("font_color", GOLDEN)
	place.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	place.add_theme_constant_override("outline_size", 4)
	place.position = Vector2(74, 130)
	root.add_child(place)
	var hint := Label.new()
	hint.text = "Bấm chuột hay phím cách để đọc nhanh"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	hint.position = Vector2(74, 168)
	root.add_child(hint)
	var skip := _dark_button("Bỏ qua", func() -> void: _begin())
	skip.position = Vector2(74, 210)
	root.add_child(skip)
	# Điện thoại bên phải: vỏ đen, thanh trạng thái, tên người gửi, khung tin nhắn.
	var phone := PanelContainer.new()
	var shell := StyleBoxFlat.new()
	shell.bg_color = Color("16181d")
	shell.border_color = Color("4a4e57")
	shell.set_border_width_all(2)
	shell.set_corner_radius_all(42)
	shell.set_content_margin_all(10)
	shell.shadow_color = Color(0, 0, 0, 0.55)
	shell.shadow_size = 22
	phone.add_theme_stylebox_override("panel", shell)
	phone.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	phone.custom_minimum_size = Vector2(380, 640)
	phone.position = Vector2(-470, -320)
	root.add_child(phone)
	var screen := PanelContainer.new()
	var scr := StyleBoxFlat.new()
	scr.bg_color = Color("eef0f3")
	scr.set_corner_radius_all(32)
	screen.add_theme_stylebox_override("panel", scr)
	screen.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	phone.add_child(screen)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	screen.add_child(col)
	var status := MarginContainer.new()
	for side in ["left", "right"]:
		status.add_theme_constant_override("margin_" + side, 24)
	status.add_theme_constant_override("margin_top", 10)
	status.add_theme_constant_override("margin_bottom", 6)
	col.add_child(status)
	var srow := HBoxContainer.new()
	status.add_child(srow)
	srow.add_child(UI.label("5:40", 14, Color("111318")))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	srow.add_child(sp)
	srow.add_child(UI.label("Vietnamobile  4G  62%", 12, Color("111318")))
	var head := PanelContainer.new()
	var hs := StyleBoxFlat.new()
	hs.bg_color = Color.WHITE
	hs.border_color = Color("e2e5ea")
	hs.border_width_bottom = 1
	hs.content_margin_left = 14
	hs.content_margin_right = 14
	hs.content_margin_top = 10
	hs.content_margin_bottom = 10
	head.add_theme_stylebox_override("panel", hs)
	col.add_child(head)
	var hrow := HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 10)
	head.add_child(hrow)
	hrow.add_child(UI.label("‹", 26, Color("1a73e8")))
	_chat_badge = _badge("A", Color("888888"), 34)
	hrow.add_child(_chat_badge.get_parent())
	_chat_name = UI.label("", 16, Color("15181f"))
	_chat_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hrow.add_child(_chat_name)
	_chat_scroll = ScrollContainer.new()
	_chat_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_chat_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_chat_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	col.add_child(_chat_scroll)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_chat_scroll.add_child(pad)
	_chat_box = VBoxContainer.new()
	_chat_box.add_theme_constant_override("separation", 10)
	_chat_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(_chat_box)
	var home := CenterContainer.new()
	home.custom_minimum_size.y = 24
	col.add_child(home)
	var pill := Panel.new()
	pill.custom_minimum_size = Vector2(120, 5)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color("1b1d22")
	ps.set_corner_radius_all(3)
	pill.add_theme_stylebox_override("panel", ps)
	home.add_child(pill)


## Ô tròn có chữ cái đầu tên (ảnh đại diện người gửi). Trả về nhãn chữ, ô là cha của nhãn.
func _badge(letter: String, color: Color, size: float) -> Label:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(size / 2.0))
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(size, size)
	p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var l := UI.label(letter, int(size * 0.45), Color.WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return l


func _start_chats() -> void:
	_chat_i = 0
	_msg_i = 0
	_chat_done = false
	_chat_wait = 0.8
	_show_chat()


func _chats() -> Array:
	return game.story.prologue.get("intro", {}).get("chats", [])


func _show_chat() -> void:
	for c in _chat_box.get_children():
		_chat_box.remove_child(c)
		c.queue_free()
	var chats := _chats()
	if _chat_i >= chats.size():
		return
	var ch: Dictionary = chats[_chat_i]
	_chat_name.text = str(ch.name)
	_chat_badge.text = str(ch.badge)
	var sb: StyleBoxFlat = (_chat_badge.get_parent() as PanelContainer).get_theme_stylebox("panel")
	sb.bg_color = Color(str(ch.color))


## Tin tiếp theo: hết tin của một người thì sang người kế; hết cả thì hiện nút vào ngày 1.
func _next_msg() -> void:
	var chats := _chats()
	if _chat_i >= chats.size():
		_chat_done = true
		return
	var ch: Dictionary = chats[_chat_i]
	var msgs: Array = ch.msgs
	if _msg_i >= msgs.size():
		_chat_i += 1
		_msg_i = 0
		_chat_wait = 1.2
		if _chat_i >= chats.size():
			_chat_done = true
			var go := _dark_button("Vào ngày 1", func() -> void: _begin())
			go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			_chat_box.add_child(go)
			_scroll_down()
		else:
			_show_chat()
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var av := _badge(str(ch.badge), Color(str(ch.color)), 30)
	row.add_child(av.get_parent())
	var bubble := PanelContainer.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color.WHITE
	bs.set_corner_radius_all(14)
	bs.corner_radius_top_left = 4
	bs.set_content_margin_all(10)
	bs.shadow_color = Color(0, 0, 0, 0.06)
	bs.shadow_size = 3
	bubble.add_theme_stylebox_override("panel", bs)
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var text := UI.label(str(msgs[_msg_i]), 15, Color("15181f"))
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 230
	bubble.add_child(text)
	row.add_child(bubble)
	_chat_box.add_child(row)
	_scroll_down()
	if world != null and world.audio != null:
		world.audio.play("dialog")
	_msg_i += 1
	# Tin dài thì đọc lâu hơn.
	_chat_wait = clampf(str(msgs[_msg_i - 1]).length() / 28.0, 1.3, 3.2)


func _scroll_down() -> void:
	await get_tree().process_frame
	_chat_scroll.scroll_vertical = int(_chat_scroll.get_v_scroll_bar().max_value)


# ---------------------------------------------------------------- vào game

func _begin(mode := "full") -> void:
	game.new_game(mode, _diff)
	_close()


func _close() -> void:
	visible = false
	_shot = {}
	started.emit()
