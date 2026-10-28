extends CanvasLayer
## Giao diện đè lên màn phố, gọn như Nobody: thanh mảnh trên cùng (ngày giờ, tiền, vòng ngày còn lại, nút biểu tượng),
## mục tiêu chữ nổi góc trái, vòng Phong độ góc dưới trái; bảng địa điểm khi bước vào một cửa tiệm và các hộp thoại.
## Bố cục dùng container lồng nhau; mọi container trong suốt với chuột để bấm xuyên xuống cảnh 3D.

const GameLogic := preload("res://scripts/game_logic.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")
const DialogLayer := preload("res://scripts/ui/dialog_layer.gd")
const CharacterPanel := preload("res://scripts/ui/character_panel.gd")
const StreetMap := preload("res://scripts/world/street_map.gd")
const Billiards := preload("res://scripts/work/billiards.gd")
const QuestGuide := preload("res://scripts/quest_guide.gd")
const RepairBench := preload("res://scripts/world/repair_bench.gd")
const ItemIcon := preload("res://scripts/ui/item_icon.gd")
const MoodRing := preload("res://scripts/ui/mood_ring.gd")
const Joystick := preload("res://scripts/ui/joystick.gd")
## Ca làm việc 3D theo trường minigame của việc trong config.json (bricks, site, dishes, repair): mỗi việc một bản đồ
## nhỏ riêng, An tự đi lại làm.
const WorkSite := preload("res://scripts/work/work_site.gd")

var world
var game
## Trò chơi nhỏ đang mở (phụ hồ bưng gạch), null nếu không có.
var minigame: Control
var dialogs: DialogLayer
## Bảng Nhân vật (phím C): hành trang, An 3D, trạng thái, đặc điểm, quan hệ.
var character: CharacterPanel

var _objectives: PanelContainer
var _map: Control
var _big_map: Control
var _loc_scroll: ScrollContainer
var _objective_box: VBoxContainer
var _guide_button: Button
var _guide_location := ""
var _guide_primary_id := ""
var _status: PanelContainer
var _day_label: Label
var _clock_label: Label
var _cash_label: Label
var _recv_label: Label
var _fatigue_label: Label
var _fatigue_bar: ProgressBar
var _prompt: PanelContainer
var _prompt_label: Label
var _location: PanelContainer
var _loc_title: Label
var _loc_desc: Label
var _loc_cards: VBoxContainer
var _loc_leave: Button
## Sổ: phải thu, phải trả, lời hứa, sổ gia đình, thân thiết và đồ đang mang.
var _skills: PanelContainer
var _skills_text: RichTextLabel
var _log: PanelContainer
var _log_text: RichTextLabel
var _bottom: PanelContainer
var _end_day_btn: Button
var _work: PanelContainer
var _pd_label: Label
var _pd_bar: ProgressBar
var _needs_label: Label
var _phone: PanelContainer
var _phone_box: VBoxContainer
var _order_strip: PanelContainer
var _order_label: Label
var _app_on := false
var _offer: Dictionary = {}
var _offer_left := 0.0
var _offer_wait := 3.0
var _phone_tick := 0.0
var _work_title: Label
var _work_clock: Label
var _work_bar: ProgressBar
var _working := false
var _loc_id := ""
var _prompt_id := "-"
var _hint: Label
var _top_row: Control
var _root: Control
var _left_col: Control
var _phone_scroll: ScrollContainer
var _phone_clock: Label
var _phone_batt: ColorRect
var _phone_status: Label
## Điện thoại: bề ngang, chiều cao phần nội dung, màu app Giao Nhanh.
const PHONE_W := 320.0
const PHONE_BODY_H := 430.0
const PHONE_GREEN := Color("0f9d58")
## Thanh mảnh trên cùng (kiểu Nobody): ngày, buổi, giờ, tiền mặt, vòng "còn lại N ngày" ở giữa, các nút biểu tượng.
var _topbar: Control
var _tb_day: Label
var _tb_cash: Label
var _tb_left: Label
var _tb_left_sub: Label
var _tb_icons := {}
## Bảng sinh tồn góc trên bên trái: giờ, buổi, ngày, tiền mặt, thanh Thể lực, Tâm trạng, Độ no.
var _stats: PanelContainer
var _st_clock: Label
var _st_day: Label
var _st_cash: Label
var _st_bars := {}
## Cần điều khiển ảo, nút Chạy (chỉ màn cảm ứng); null trên máy tính.
var joystick: Control = null
## Hành động nhanh ở lời nhắc trước cửa địa điểm (phím 1–3 hay chạm): id việc theo thứ tự.
var _quick: VBoxContainer
var _quick_ids: Array = []
## Vòng Phong độ góc dưới bên trái, các biểu tượng nhu cầu đang thiếu bên cạnh.
var _mood: Control
var _mood_needs: HBoxContainer
## Bảng mục tiêu: chỉ hiện vài mục đầu (ít chữ), bấm vào bảng để xem hết.
var _obj_n := 0
var _obj_hidden := 0
var _obj_expanded := false
## Mở hết các mục mà dài quá phần màn còn trống thì cuộn trong khung này; chỗ bắt đầu chạm để phân biệt chạm với vuốt.
var _obj_scroll: ScrollContainer
var _obj_press := Vector2.ZERO


func _ready() -> void:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.make_theme()
	add_child(root)
	_root = root
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := _pass(MarginContainer.new(), root)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	var rows := _pass(VBoxContainer.new(), margin)
	rows.add_theme_constant_override("separation", 12)

	# Chừa chỗ cho thanh trên cùng; hàng trên chỉ còn bảng mục tiêu bên trái (bản đồ nhỏ, bảng trạng thái cũ giữ lại
	# nhưng ẩn: bản đồ lớn mở bằng phím M hay nút bản đồ, trạng thái ở vòng Phong độ và bảng Nhân vật).
	var gap := _pass(Control.new(), rows)
	gap.custom_minimum_size.y = 34
	var top := _pass(HBoxContainer.new(), rows)
	_top_row = top
	var top_left := _pass(VBoxContainer.new(), top)
	top_left.add_theme_constant_override("separation", 6)
	_build_stats(top_left)
	_build_objectives(top_left)
	_spacer(top)
	_map = StreetMap.new()
	_map.world = world
	top.add_child(_map)
	_spacer(top)
	_build_status(top)

	# Hàng giữa: kỹ năng / nhật ký bên trái. Bảng địa điểm có vùng riêng bên phải,
	# không bị hàng mục tiêu cao đẩy xuống dưới màn hình.
	var middle := _pass(HBoxContainer.new(), rows)
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := _pass(VBoxContainer.new(), middle)
	_left_col = left
	_build_tip(left)
	_build_skills(left)
	_build_log(left)
	_build_phone(left)
	_spacer(middle)
	_build_location(root)

	# Lời nhắc tương tác và thanh "đang làm" ở giữa, phía trên thanh công cụ.
	var prompt_row := _pass(HBoxContainer.new(), rows)
	prompt_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_build_prompt(prompt_row)
	_build_work(prompt_row)
	_build_order_strip(prompt_row)

	# Hàng dưới: hướng dẫn điều khiển bên trái, thanh công cụ bên phải.
	var bottom := _pass(HBoxContainer.new(), rows)
	var hint := UI.label("Chuột trái: đi tới chỗ bấm · Con lăn: gần xa, toàn cảnh · Bấm cửa tiệm hoặc người: tương tác · WASD: đi · E: vào · M: bản đồ · C: nhân vật · Esc: đóng", 12, UI.HUD_TEXT)
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	hint.add_theme_constant_override("outline_size", 5)
	hint.size_flags_vertical = Control.SIZE_SHRINK_END
	# Màn hẹp thì dòng hướng dẫn xuống hàng, nhường đủ chỗ cho thanh công cụ.
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 160
	bottom.add_child(hint)
	_hint = hint
	_build_bottom(bottom)

	# Bản đồ lớn phủ giữa màn hình (phím M hoặc bấm bản nhỏ).
	_big_map = StreetMap.new()
	_big_map.world = world
	_big_map.big = true
	root.add_child(_big_map)
	_map.other = _big_map

	_build_topbar(root)
	_build_mood(root)
	if ScreenFit.touch:
		joystick = Joystick.new()
		joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		joystick.position = Vector2(18, -170)
		root.add_child(joystick)
		# Màn cảm ứng: góc dưới trái dành cho cần điều khiển, vòng Phong độ sang góc dưới phải.
		_mood.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		_mood.offset_left = -116.0
		_mood.offset_right = -32.0
		_mood.offset_top = -150.0
		_mood.offset_bottom = -66.0
	# Tối nhẹ bốn góc màn hình cho mắt dồn vào An và người quanh đó ở giữa.
	var vig := ColorRect.new()
	vig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vig.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vm := ShaderMaterial.new()
	var vs := Shader.new()
	vs.code = VIGNETTE_SHADER
	vm.shader = vs
	vig.material = vm
	root.add_child(vig)
	root.move_child(vig, 0)
	root.move_child(_big_map, -1)

	dialogs = DialogLayer.new()
	dialogs.game = game
	root.add_child(dialogs)
	dialogs.closed.connect(_refresh)
	character = CharacterPanel.new()
	character.world = world
	character.game = game
	add_child(character)
	character.closed.connect(func() -> void: _root.visible = true)
	game.changed.connect(_refresh)
	ScreenFit.changed.connect(_apply_fit)
	_apply_fit()


# ---------------------------------------------------------------- API cho world.gd

func blocking() -> bool:
	return dialogs.visible or (_wardrobe != null and _wardrobe.visible) or (is_instance_valid(_bench) and _bench.visible) or _working or minigame != null or (_big_map != null and _big_map.visible) or (character != null and character.visible)


func location_open() -> String:
	return _loc_id


func open_location(id: String) -> void:
	if not game.is_started() or blocking():
		return
	if _loc_id != id:
		_loc_scroll.scroll_vertical = 0
	_loc_id = id
	_refresh()


func close_location() -> void:
	if _loc_id == "":
		return
	_loc_id = ""
	_refresh()


## Bố cục theo màn hình (ScreenFit): điện thoại nằm ngang thì gọn lại (bản đồ nhỏ hơn; Sổ, Nhật ký, bảng địa điểm,
## điện thoại thấp lại cho vừa; bảng mục tiêu chỉ hiện vài mục đầu); máy cảm ứng ẩn dòng phím tắt.
func _apply_fit() -> void:
	var compact: bool = ScreenFit.compact
	_hint.visible = false
	_map.fit(compact, ScreenFit.view_size())
	_big_map.fit(compact, ScreenFit.view_size())
	var h := _panel_max_h()
	_skills_text.custom_minimum_size = Vector2(380 if compact else 400, h)
	_log_text.custom_minimum_size = Vector2(380 if compact else 380, h)
	_tip.custom_minimum_size.x = 470 if compact else 360
	_tip_label.custom_minimum_size.x = 446 if compact else 336
	# Màn thấp: ô gợi ý nổi ở góc dưới bên trái, trên thanh công cụ và lời nhắc, không chen vào hàng giữa (đẩy thanh
	# công cụ xuống dưới mép màn).
	var tip_parent: Control = _root if compact else _left_col
	if _tip.get_parent() != tip_parent:
		_tip.reparent(tip_parent, false)
		if compact:
			_tip.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
			_tip.grow_vertical = Control.GROW_DIRECTION_BEGIN
			_tip.offset_left = 16.0
			_tip.offset_right = 16.0
			_tip.offset_top = -140.0
			_tip.offset_bottom = -140.0
		else:
			_left_col.move_child(_tip, 0)
	# Ghi lại lời nhắc ở khung hình sau (chữ "Chạm" hay tên phím).
	_prompt_id = "-"
	_refresh()


## Chiều cao tối đa của vùng chữ trong Sổ, Nhật ký, điện thoại; loc: vùng thẻ việc của bảng địa điểm. Màn thấp thì
## hàng trên (mục tiêu, bản đồ nhỏ, trạng thái) cất đi khi bảng mở (_make_room), bảng cao gần hết màn.
func _panel_max_h(loc := false) -> float:
	if not ScreenFit.compact:
		return 420.0
	return clampf(ScreenFit.view_size().y - (300.0 if loc else 220.0), 120.0, 420.0)


## Một bảng giữa màn hình đang mở (Sổ, Nhật ký, điện thoại, địa điểm).
func _panel_open() -> bool:
	return _loc_id != "" or _skills.visible or _log.visible or _phone.visible


## Màn thấp: có bảng mở thì cất hàng trên và ô gợi ý (coi như đã đọc) cho bảng đủ chỗ, khỏi đẩy thanh công cụ xuống
## dưới mép màn.
func _make_room() -> void:
	var busy := ScreenFit.compact and _panel_open()
	if busy and _tip.visible:
		_close_tip()
	_top_row.visible = not busy
	if _mood != null:
		_mood.visible = game.is_started() and not _panel_open()


func set_prompt(id: String) -> void:
	if id == _prompt_id:
		return
	_prompt_id = id
	if id.begins_with("bin:"):
		var lock: String = game.scrap_lock(id.substr(4))
		_prompt_label.text = _key("E") + "Lục thùng rác tìm đồ đồng nát" if lock == "" else "Thùng rác · " + lock
	elif id.begins_with("vendor:"):
		var vname := ""
		for v in world.life.vendors:
			if "vendor:" + str(v.id) == id:
				vname = str(v.cfg.get("name", ""))
		_prompt_label.text = _key("E") + "Mua của hàng rong · " + vname
	elif id != "":
		_prompt_label.text = _key("E") + "Vào " + str(world.location_info(id).name)
	_fill_quick(id)
	_update_prompt()


## Mở bảng Nhân vật; trong lúc mở giấu các bảng của màn phố để nền vẽ mực chỉ có phố.
func open_character() -> void:
	if not game.is_started() or blocking() or world.title_open():
		return
	close_location()
	_root.visible = false
	character.open()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_C, KEY_I]:
		open_character()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_T and game.is_started() \
			and not game.clothes.is_empty() and (_wardrobe == null or not _wardrobe.visible) and not blocking():
		open_wardrobe("all")
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE and _wardrobe != null and _wardrobe.visible:
		_wardrobe.visible = false
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_1, KEY_2, KEY_3] \
			and _prompt.visible and _quick.visible and not blocking():
		var i: int = int(event.keycode - KEY_1)
		if i < _quick_ids.size():
			_perform(str(_quick_ids[i]))
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _loc_id != "":
			close_location()
		elif _log.visible or _skills.visible or _phone.visible:
			_log.visible = false
			_skills.visible = false
			_phone.visible = false
			_make_room()
		elif game.is_started() and not blocking():
			world.open_menu()


# ---------------------------------------------------------------- dựng khối

func _pass(c: Control, parent: Control) -> Control:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	return c


func _spacer(parent: Control) -> void:
	var s := _pass(Control.new(), parent)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _dark_panel(parent: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(UI.HUD_BG, Color(1, 1, 1, 0.1), 8, 14))
	p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(p)
	return p


func _light_panel(parent: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UI.box(Color(UI.CARD, 1.0), UI.LINE, 10, 16))
	p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(p)
	return p


func _build_objectives(parent: Control) -> void:
	_objectives = _dark_panel(parent)
	_objectives.add_theme_stylebox_override("panel", UI.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 6))
	_objectives.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_objectives.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UI.box(UI.GOLD, UI.GOLD, 12, 0))
	badge.custom_minimum_size = Vector2(24, 24)
	var bang := UI.label("!", 16, Color("2a2110"))
	bang.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_child(bang)
	head.add_child(badge)
	head.add_child(_outlined(UI.label("Mục tiêu quan trọng", 17, UI.GOLD)))
	_obj_scroll = ScrollContainer.new()
	_obj_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_obj_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_obj_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(_obj_scroll)
	_objective_box = VBoxContainer.new()
	_objective_box.add_theme_constant_override("separation", 2)
	_obj_scroll.add_child(_objective_box)
	_objective_box.minimum_size_changed.connect(_fit_objectives)
	# Chế độ gọn: chạm vào bảng để xem hết các mục, chạm lần nữa để thu lại (vuốt để cuộn thì không tính là chạm).
	_objectives.gui_input.connect(func(e: InputEvent) -> void:
		if not (e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT):
			return
		if e.pressed:
			_obj_press = e.position
		elif e.position.distance_to(_obj_press) < 12.0:
			_obj_expanded = not _obj_expanded
			# Mở hết bảng thì cất ô gợi ý ở góc dưới (coi như đã đọc), khỏi đè lên các mục.
			if _obj_expanded and _tip.visible:
				_close_tip()
			_refresh())


func _build_status(parent: Control) -> void:
	_status = _dark_panel(parent)
	_status.custom_minimum_size = Vector2(280, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_status.add_child(v)
	_day_label = UI.label("", 22, UI.HUD_TEXT)
	v.add_child(_day_label)
	_clock_label = UI.label("", 14, UI.HUD_SOFT)
	v.add_child(_clock_label)
	# Hai cột tiền: tiền mặt tiêu được, và tiền phải thu / phải trả không cộng chung.
	_cash_label = UI.label("", 26, UI.GOLD)
	v.add_child(_cash_label)
	_recv_label = UI.label("", 12, UI.HUD_SOFT)
	v.add_child(_recv_label)
	_fatigue_label = UI.label("", 12, UI.HUD_SOFT)
	v.add_child(_fatigue_label)
	_fatigue_bar = UI.bar(8)
	v.add_child(_fatigue_bar)
	_pd_label = UI.label("", 12, UI.HUD_SOFT)
	v.add_child(_pd_label)
	_pd_bar = UI.bar(8)
	v.add_child(_pd_bar)
	_needs_label = UI.label("", 12, UI.HUD_SOFT)
	v.add_child(_needs_label)


## Lời nhắc giữa màn hình (vào địa điểm, lục thùng rác): bấm, chạm vào cũng được như phím E.
func _build_prompt(parent: Control) -> void:
	_prompt = _dark_panel(parent)
	_prompt.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_prompt.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			world.interact())
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 2)
	_prompt.add_child(pv)
	_prompt_label = UI.label("", 16, UI.HUD_TEXT)
	pv.add_child(_prompt_label)
	_quick = VBoxContainer.new()
	_quick.add_theme_constant_override("separation", 0)
	_quick.visible = false
	pv.add_child(_quick)
	_prompt.visible = false


## Tên phím đầu lời nhắc trên máy có bàn phím; máy cảm ứng thì ghi "Chạm".
func _key(k: String) -> String:
	return ("Chạm" if ScreenFit.touch else k) + "  ·  "


func _build_work(parent: Control) -> void:
	_work = _dark_panel(parent)
	_work.custom_minimum_size = Vector2(420, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_work.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	_work_title = UI.label("", 17, UI.HUD_TEXT)
	_work_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_work_title)
	_work_clock = UI.label("", 17, UI.GOLD)
	head.add_child(_work_clock)
	_work_bar = UI.bar(10)
	_work_bar.max_value = 1.0
	_work_bar.add_theme_stylebox_override("fill", UI.box(UI.GOLD, UI.GOLD, 5, 0))
	v.add_child(_work_bar)
	_work.visible = false


## Làm một việc ở tiệm: An vào trong, thanh thời gian chạy, đồng hồ nhảy dần, xong mới tính kết quả.
## result: kết quả trò chơi nhỏ (tự làm hoặc làm tự động); việc có minigame mà chưa có kết quả thì mở trò chơi trước.
func _perform(id: String, result: Dictionary = {}) -> void:
	var a: Dictionary = game.get_action(id)
	var st: Dictionary = game.action_status(a)
	if not st.ok or _working or minigame != null:
		return
	if a.has("minigame") and result.is_empty():
		_open_minigame(id, a)
		return
	var start: float = st.start
	var finish: float = start + float(a.hours)
	_working = true
	world.set_player_inside(true)
	_work_title.text = "Đang " + str(a.name).to_lower() if a.group == "work" else str(a.name)
	_work.visible = true
	_refresh()
	var seconds := maxf(0.8, float(a.hours) * float(game.cfg.get("workSecondsPerHour", 0.35)))
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		var now := lerpf(start, finish, t)
		_work_bar.value = t
		_work_clock.text = GameLogic.hh(now)
		_clock_label.text = "%s  ·  đang bận" % GameLogic.hh(now)
		_st_clock.text = GameLogic.hh(now), 0.0, 1.0, seconds)
	tw.tween_callback(func() -> void:
		_working = false
		_work.visible = false
		world.set_player_inside(false)
		world.audio.play("done")
		game.do_action(id, result))


func _build_location(parent: Control) -> void:
	_location = _light_panel(parent)
	_location.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_location.add_child(v)
	_loc_title = UI.label("", 22, UI.INK)
	_loc_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_loc_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(336, 80)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	v.add_child(scroll)
	_loc_scroll = scroll
	# Mô tả và mọi hành động cùng cuộn; con lăn trên đoạn mô tả vẫn tới được các nút.
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	_loc_desc = UI.label("", 13, UI.INK_SOFT)
	_loc_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_loc_desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_loc_desc)
	_loc_cards = VBoxContainer.new()
	_loc_cards.add_theme_constant_override("separation", 8)
	body.add_child(_loc_cards)
	var leave := Button.new()
	_loc_leave = leave
	leave.text = "Rời đi"
	leave.custom_minimum_size.y = 42
	leave.pressed.connect(close_location)
	v.add_child(leave)
	_location.visible = false


func _build_skills(parent: Control) -> void:
	_skills = _light_panel(parent)
	var v := VBoxContainer.new()
	_skills.add_child(v)
	v.add_child(UI.label("SỔ: PHẢI THU · PHẢI TRẢ · LỜI HỨA · GIA ĐÌNH", 11, UI.INK_SOFT))
	_skills_text = RichTextLabel.new()
	_skills_text.bbcode_enabled = true
	_skills_text.custom_minimum_size = Vector2(400, 420)
	_skills_text.add_theme_font_size_override("normal_font_size", 13)
	_skills_text.add_theme_font_size_override("bold_font_size", 14)
	v.add_child(_skills_text)
	_skills.visible = false


## Mở trò chơi nhỏ của việc; xong thì chạy thanh thời gian như mọi việc khác với kết quả vừa chơi.
func _open_minigame(id: String, a: Dictionary) -> void:
	var mcfg: Dictionary = game.cfg.minigames[a.minigame]
	# Cảnh riêng (bàn bi-a) hay cảnh ca làm 3D; trò mới dùng lại cảnh có sẵn (cfg.kind: bricks, site, dishes, repair).
	minigame = Billiards.new() if str(mcfg.get("scene", "")) == "billiards" else WorkSite.new()
	minigame.cfg = mcfg
	minigame.kind = str(mcfg.get("kind", a.minigame))
	minigame.last = game.s.get("job_last", {}).get(id, {})
	minigame.title = str(a.name)
	minigame.finished.connect(func(r: Dictionary) -> void:
		minigame.queue_free()
		minigame = null
		if not r.is_empty():
			_perform(id, r))
	add_child(minigame)
	_refresh()


# ---------------------------------------------------------------- điện thoại: app giao hàng

## Điện thoại cầm tay: vỏ máy đen bo tròn, màn hình có thanh trạng thái (giờ trong game, sóng, pin, tai thỏ), thanh
## tiêu đề app Giao Nhanh màu xanh lá, nội dung cuộn được, vạch home ở đáy.
func _build_phone(parent: Control) -> void:
	_phone = PanelContainer.new()
	var shell := StyleBoxFlat.new()
	shell.bg_color = Color("16181d")
	shell.border_color = Color("3a3e47")
	shell.set_border_width_all(2)
	shell.set_corner_radius_all(38)
	shell.set_content_margin_all(9)
	shell.shadow_color = Color(0, 0, 0, 0.45)
	shell.shadow_size = 14
	shell.shadow_offset = Vector2(0, 6)
	_phone.add_theme_stylebox_override("panel", shell)
	_phone.custom_minimum_size = Vector2(PHONE_W, 0)
	_phone.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(_phone)
	var screen := PanelContainer.new()
	var scr := StyleBoxFlat.new()
	scr.bg_color = Color("f2f4f7")
	scr.set_corner_radius_all(30)
	screen.add_theme_stylebox_override("panel", scr)
	screen.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	_phone.add_child(screen)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	screen.add_child(col)
	# Thanh trạng thái: giờ bên trái, tai thỏ ở giữa, sóng và pin bên phải.
	var bar := MarginContainer.new()
	for side in ["left", "right"]:
		bar.add_theme_constant_override("margin_" + side, 22)
	bar.add_theme_constant_override("margin_top", 8)
	bar.add_theme_constant_override("margin_bottom", 4)
	col.add_child(bar)
	var row := HBoxContainer.new()
	bar.add_child(row)
	_phone_clock = UI.label("06:00", 13, Color("111318"))
	_phone_clock.custom_minimum_size.x = 60
	row.add_child(_phone_clock)
	var mid := CenterContainer.new()
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(mid)
	var notch := Panel.new()
	notch.custom_minimum_size = Vector2(84, 22)
	var ns := StyleBoxFlat.new()
	ns.bg_color = Color("0c0d10")
	ns.set_corner_radius_all(11)
	notch.add_theme_stylebox_override("panel", ns)
	mid.add_child(notch)
	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 5)
	right.alignment = BoxContainer.ALIGNMENT_END
	right.custom_minimum_size.x = 60
	row.add_child(right)
	var bars := HBoxContainer.new()
	bars.add_theme_constant_override("separation", 2)
	bars.alignment = BoxContainer.ALIGNMENT_END
	for i in 4:
		var r := ColorRect.new()
		r.color = Color("111318")
		r.custom_minimum_size = Vector2(3, 4 + i * 2)
		r.size_flags_vertical = Control.SIZE_SHRINK_END
		bars.add_child(r)
	right.add_child(bars)
	right.add_child(UI.label("4G", 11, Color("111318")))
	var batt := Panel.new()
	batt.custom_minimum_size = Vector2(24, 12)
	batt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0, 0, 0, 0)
	bs.border_color = Color("111318")
	bs.set_border_width_all(1)
	bs.set_corner_radius_all(3)
	batt.add_theme_stylebox_override("panel", bs)
	_phone_batt = ColorRect.new()
	_phone_batt.color = Color("111318")
	_phone_batt.position = Vector2(2, 2)
	_phone_batt.size = Vector2(20, 8)
	batt.add_child(_phone_batt)
	right.add_child(batt)
	# Thanh tiêu đề app.
	var head := PanelContainer.new()
	var hs := StyleBoxFlat.new()
	hs.bg_color = PHONE_GREEN
	hs.content_margin_left = 16
	hs.content_margin_right = 16
	hs.content_margin_top = 10
	hs.content_margin_bottom = 12
	head.add_theme_stylebox_override("panel", hs)
	col.add_child(head)
	var hrow := HBoxContainer.new()
	head.add_child(hrow)
	var logo := PanelContainer.new()
	var ls := StyleBoxFlat.new()
	ls.bg_color = Color.WHITE
	ls.set_corner_radius_all(8)
	ls.set_content_margin_all(4)
	logo.add_theme_stylebox_override("panel", ls)
	var lg := UI.label("GN", 13, PHONE_GREEN)
	lg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lg.custom_minimum_size = Vector2(22, 0)
	logo.add_child(lg)
	hrow.add_child(logo)
	hrow.add_theme_constant_override("separation", 10)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.add_child(titles)
	titles.add_child(UI.label("Giao Nhanh", 18, Color.WHITE))
	_phone_status = UI.label("", 12, Color(1, 1, 1, 0.88))
	titles.add_child(_phone_status)
	# Nội dung cuộn được.
	_phone_scroll = ScrollContainer.new()
	_phone_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	# Như điện thoại: không hiện thanh cuộn, lăn chuột hay kéo để cuộn.
	_phone_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	col.add_child(_phone_scroll)
	var pad := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 12)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_phone_scroll.add_child(pad)
	_phone_box = VBoxContainer.new()
	_phone_box.add_theme_constant_override("separation", 10)
	_phone_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(_phone_box)
	# Vạch home.
	var home := CenterContainer.new()
	home.custom_minimum_size.y = 22
	col.add_child(home)
	var pill := Panel.new()
	pill.custom_minimum_size = Vector2(110, 5)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color("1b1d22")
	ps.set_corner_radius_all(3)
	pill.add_theme_stylebox_override("panel", ps)
	home.add_child(pill)
	_phone.visible = false


## Thẻ trắng bo góc trong màn điện thoại.
func _phone_card(accent := Color(0, 0, 0, 0)) -> VBoxContainer:
	var card := PanelContainer.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color.WHITE
	cs.set_corner_radius_all(14)
	cs.set_content_margin_all(12)
	cs.shadow_color = Color(0, 0, 0, 0.08)
	cs.shadow_size = 4
	cs.shadow_offset = Vector2(0, 2)
	if accent.a > 0.0:
		cs.border_color = accent
		cs.border_width_left = 4
	card.add_theme_stylebox_override("panel", cs)
	_phone_box.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	return v


## Một dòng "nhãn: giá trị" trong thẻ đơn.
func _phone_line(parent: Control, key: String, value: String, strong := false) -> void:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 6)
	var k := UI.label(key, 12, Color("7a8090"))
	k.custom_minimum_size.x = 64
	r.add_child(k)
	var v := UI.label(value, 14 if strong else 13, Color("15181f"))
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(v)
	parent.add_child(r)


## Nút kiểu app: primary nền xanh lá, ghost viền xám, danger chữ đỏ; sub là dòng nhỏ bên dưới; lock: khóa kèm lý do.
func _phone_btn(text: String, kind: String, sub: String, lock: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 46 if sub == "" and lock == "" else 58)
	b.disabled = lock != ""
	var bg: Color = {"primary": PHONE_GREEN, "ghost": Color.WHITE, "danger": Color("fff1f0")}[kind]
	var fg: Color = {"primary": Color.WHITE, "ghost": Color("15181f"), "danger": Color("d93025")}[kind]
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = bg.darkened(0.08) if st == "hover" else (bg.darkened(0.16) if st == "pressed" else bg)
		if st == "focus":
			sb.bg_color = Color(0, 0, 0, 0)
		if kind == "ghost":
			sb.border_color = Color("d5d9e2")
			sb.set_border_width_all(1)
		sb.set_corner_radius_all(23)
		b.add_theme_stylebox_override(st, sb)
	b.pressed.connect(on_press)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(v)
	var t := UI.label(text, 15, fg)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	if lock != "" or sub != "":
		var s2 := UI.label(lock if lock != "" else sub, 11, Color("d93025") if lock != "" else fg.lerp(bg, 0.35))
		s2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s2.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(s2)
	if lock != "":
		t.modulate.a = 0.5
	_phone_box.add_child(b)
	return b


func _build_order_strip(parent: Control) -> void:
	_order_strip = _dark_panel(parent)
	_order_label = UI.label("", 15, UI.HUD_TEXT)
	_order_strip.add_child(_order_label)
	_order_strip.visible = false


func _process(delta: float) -> void:
	if not game.is_started() or game.is_over():
		return
	var active: Dictionary = game.delivery_active()
	# Đơn mới tới khi app đang bật, rảnh tay và không có hộp thoại.
	if _app_on and active.is_empty() and _offer.is_empty() and not blocking():
		_offer_wait -= delta
		if _offer_wait <= 0.0:
			_new_offer()
	if not _offer.is_empty():
		_offer_left -= delta
		if _offer_left <= 0.0:
			_offer = {}
			_refresh_phone()
	_phone_tick -= delta
	if _phone_tick <= 0.0:
		_phone_tick = 0.25
		_refresh_guide_distance()
		_warn_needs()
		_update_tip(0.25)
		_update_order_strip(active)
		if _phone.visible:
			_refresh_phone()


## Nhắc một lần mỗi ngày khi đói hay bẩn quá, để người chơi kịp xử lý trước khi mất Sức khỏe.
var _warned := {}


func _warn_needs() -> void:
	if not game.has_needs() or blocking():
		return
	for w in [["fed", 20.0, "Bụng đói cồn cào, đi ăn thôi!"], ["clean", 15.0, "Người bốc mùi, về phòng tắm đi"], ["neat", 15.0, "Quần áo dơ quá, phải giặt"]]:
		var key := "%s_%d" % [w[0], game.day()]
		if game.need(w[0]) < float(w[1]) and not _warned.has(key):
			_warned[key] = true
			world._float_text(str(w[2]), Color("ffb27a"))


func _new_offer() -> void:
	var d: Dictionary = game.cfg.delivery
	var r: Array = d.offerSec if game.delivery_rush() else d.offPeakSec
	_offer_wait = randf_range(float(r[0]), float(r[1]))
	if game.delivery_lock() != "":
		return
	_offer = world.make_offer()
	if _offer.is_empty():
		return
	_offer_left = 12.0
	_phone.visible = true
	_skills.visible = false
	_log.visible = false
	_make_room()
	world.audio.play("dialog")
	_refresh_phone()


func _minutes_left(o: Dictionary) -> int:
	return int(round((float(o.deadline) - game.clock()) * 60.0))


func _update_order_strip(o: Dictionary) -> void:
	_order_strip.visible = not o.is_empty() and not _working
	if o.is_empty():
		return
	var left := _minutes_left(o)
	var where: String = ("Lấy %s ở %s" % [o.item, o.shop_name]) if not o.picked else ("Giao tới %s" % o.dest)
	_order_label.text = "Đơn: %s · %s" % [where, ("còn %d phút" % left) if left >= 0 else ("trễ %d phút" % -left)]
	_order_label.add_theme_color_override("font_color", UI.HUD_TEXT if left >= 10 else (UI.GOLD if left >= 0 else Color("ff8a7a")))


func _refresh_phone() -> void:
	if not _phone.visible:
		return
	for c in _phone_box.get_children():
		c.queue_free()
	# Thanh trạng thái: giờ trong game; pin tụt dần trong ngày.
	var clock: float = game.clock()
	_phone_clock.text = GameLogic.hh(clock)
	var charge := clampf(1.0 - (clock - 6.0) / 20.0, 0.15, 1.0)
	_phone_batt.size.x = 20.0 * charge
	_phone_batt.color = Color("111318") if charge > 0.25 else Color("d93025")
	var lock: String = game.delivery_lock()
	var rush: bool = game.delivery_rush()
	_phone_status.text = ("● Đang nhận đơn" if _app_on else "○ Đã tắt nhận đơn") + (" · giờ cao điểm" if rush else "")
	var o: Dictionary = game.delivery_active()
	if not o.is_empty():
		var left := _minutes_left(o)
		var card := _phone_card(PHONE_GREEN)
		card.add_child(UI.label("ĐƠN ĐANG GIAO", 11, PHONE_GREEN))
		var it := UI.label(str(o.item), 16, Color("15181f"))
		it.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(it)
		_phone_line(card, "Lấy ở", str(o.shop_name) + ("  ✓ đã lấy" if o.picked else ""))
		_phone_line(card, "Giao tới", str(o.dest))
		_phone_line(card, "Tiền công", GameLogic.fmt_k(int(o.pay)), true)
		var due := UI.label("Hạn %s · %s" % [GameLogic.hh(float(o.deadline)), ("còn %d phút" % left) if left >= 0 else "đã trễ"], 13,
			PHONE_GREEN if left >= 10 else (Color("c27c0e") if left >= 0 else Color("d93025")))
		card.add_child(due)
		_phone_btn("Hủy đơn", "danger", "Khách đánh giá 1 sao · Mệt +%d" % int(game.cfg.delivery.cancelFatigue), "", func() -> void:
			game.delivery_cancel()
			_refresh_phone())
	elif not _offer.is_empty():
		var card := _phone_card(Color("f29d38"))
		card.add_child(UI.label("ĐƠN MỚI · tự hủy sau %d giây" % ceili(_offer_left), 11, Color("c27c0e")))
		var timer := ProgressBar.new()
		timer.show_percentage = false
		timer.custom_minimum_size.y = 4
		timer.max_value = 12.0
		timer.value = _offer_left
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color("f29d38")
		fill.set_corner_radius_all(2)
		var back := StyleBoxFlat.new()
		back.bg_color = Color("f1e4d3")
		back.set_corner_radius_all(2)
		timer.add_theme_stylebox_override("fill", fill)
		timer.add_theme_stylebox_override("background", back)
		card.add_child(timer)
		var it := UI.label(str(_offer.item), 16, Color("15181f"))
		it.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(it)
		_phone_line(card, "Lấy ở", str(_offer.shop_name))
		_phone_line(card, "Giao tới", str(_offer.dest))
		_phone_line(card, "Tiền công", GameLogic.fmt_k(int(_offer.pay)), true)
		_phone_line(card, "Giao trước", GameLogic.hh(float(_offer.deadline)))
		_phone_btn("Nhận đơn", "primary", "Mũi tên cam chỉ quán, xanh chỉ nhà khách", "", func() -> void:
			game.delivery_accept(_offer)
			_offer = {}
			_refresh_phone())
		_phone_btn("Bỏ qua", "ghost", "", "", func() -> void:
			_offer = {}
			_refresh_phone())
	else:
		var card := _phone_card()
		card.add_child(UI.label("Đang chờ đơn…" if _app_on else "Bật nhận đơn để có đơn mới", 14, Color("15181f")))
		var info := UI.label(("Giờ cao điểm: đơn nhiều." if rush else "Ngoài giờ cao điểm (10:00–13:30, 17:00–21:00): ít đơn."), 12, Color("7a8090"))
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(info)
	var stats := UI.label("Hôm nay đã giao %d đơn" % game.today_count("giao_hang"), 12, Color("7a8090"))
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phone_box.add_child(stats)
	_phone_btn("Tắt nhận đơn" if _app_on else "Bật nhận đơn", "ghost" if _app_on else "primary", "", lock, func() -> void:
		_app_on = not _app_on
		_offer = {}
		_offer_wait = 2.0
		_refresh_phone())
	_phone_btn("Cất điện thoại", "ghost", "", "", func() -> void:
		_phone.visible = false
		_make_room())
	_fit_phone.call_deferred()


func _fit_phone() -> void:
	# Màn hình điện thoại cao như máy thật; chỗ trống từ đầu máy tới đáy màn game ít hơn thì co lại, nội dung cuộn.
	var chrome := _phone.size.y - _phone_scroll.size.y
	var room := ScreenFit.view_size().y - _phone.global_position.y - chrome - 16.0
	var want := clampf(room, 140.0, PHONE_BODY_H)
	if absf(_phone_scroll.custom_minimum_size.y - want) > 1.0:
		_phone_scroll.custom_minimum_size.y = want
		_phone.reset_size()


func _build_log(parent: Control) -> void:
	_log = _light_panel(parent)
	var v := VBoxContainer.new()
	_log.add_child(v)
	v.add_child(UI.label("NHẬT KÝ", 11, UI.INK_SOFT))
	_log_text = RichTextLabel.new()
	_log_text.bbcode_enabled = true
	_log_text.custom_minimum_size = Vector2(380, 400)
	_log_text.add_theme_font_size_override("normal_font_size", 13)
	_log_text.add_theme_font_size_override("bold_font_size", 15)
	v.add_child(_log_text)
	_log.visible = false


func _build_bottom(parent: Control) -> void:
	_bottom = _dark_panel(parent)
	_bottom.size_flags_vertical = Control.SIZE_SHRINK_END
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	_bottom.add_child(h)
	h.add_child(_tool_button("Nhân vật", open_character))
	h.add_child(_tool_button("Điện thoại", _toggle_phone))
	h.add_child(_tool_button("Sổ", _toggle_skills))
	h.add_child(_tool_button("Nhật ký", _toggle_log))
	h.add_child(_tool_button("Bảng cân bằng", _open_board))
	# Lùi máy quay ra xa ngắm cả khu phố (máy cảm ứng không có con lăn chuột), bấm lần nữa về góc chơi.
	h.add_child(_tool_button("Toàn cảnh", func() -> void: world.toggle_overview()))
	_end_day_btn = _tool_button("Về xóm trọ", _go_home)
	_end_day_btn.add_theme_stylebox_override("normal", UI.box(UI.GOLD, UI.GOLD, 8, 10))
	_end_day_btn.add_theme_stylebox_override("hover", UI.box(UI.GOLD.lightened(0.15), UI.GOLD, 8, 10))
	h.add_child(_end_day_btn)


func _toggle_phone() -> void:
	_phone.visible = not _phone.visible
	_skills.visible = false
	_log.visible = false
	_make_room()
	_refresh_phone()


func _toggle_skills() -> void:
	_skills.visible = not _skills.visible
	_log.visible = false
	_phone.visible = false
	_make_room()


func _toggle_log() -> void:
	_log.visible = not _log.visible
	_skills.visible = false
	_phone.visible = false
	_make_room()


func _open_board() -> void:
	get_tree().change_scene_to_file("res://scenes/board.tscn")


func _go_home() -> void:
	if _end_day_btn.disabled:
		return
	close_location()
	world.walk_to_location(world.home)


## Chữ nổi trên cảnh 3D không cần nền: viền tối quanh chữ.
func _outlined(l: Label) -> Label:
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 5)
	return l


# ---------------------------------------------------------------- thanh trên cùng, vòng Phong độ

const TOPBAR_SHADER := """
shader_type canvas_item;
// Dải tối mờ dần hai đầu và mép dưới, như thanh trên cùng của Nobody.
void fragment() {
	float a = smoothstep(0.0, 0.14, UV.x) * smoothstep(1.0, 0.86, UV.x) * smoothstep(1.0, 0.55, UV.y);
	COLOR = vec4(0.05, 0.05, 0.06, 0.8 * a);
}
"""

const VIGNETTE_SHADER := """
shader_type canvas_item;
void fragment() {
	// Tâm sáng lệch lên trên một chút (chỗ An đứng), mép dưới (mái nhà sát máy quay) tối hơn mép trên.
	vec2 d = (UV - vec2(0.5, 0.45)) * vec2(1.2, 1.0);
	COLOR = vec4(0.02, 0.02, 0.03, smoothstep(0.3, 0.85, length(d)) * 0.65);
}
"""

const MEDAL_SHADER := """
shader_type canvas_item;
// Huy hiệu tròn giữa thanh: nền tối, vành vàng đồng, vân xước nhẹ.
void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p) * 2.0;
	float disc = 1.0 - smoothstep(0.96, 1.0, r);
	float rim = smoothstep(0.8, 0.86, r) * (1.0 - smoothstep(0.93, 0.97, r));
	vec3 col = mix(vec3(0.09, 0.08, 0.07), vec3(0.16, 0.14, 0.11), 1.0 - r);
	col = mix(col, vec3(0.72, 0.56, 0.3), rim);
	COLOR = vec4(col, disc * 0.95);
}
"""


func _build_topbar(root: Control) -> void:
	_topbar = Control.new()
	_topbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_topbar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_topbar.offset_bottom = 44
	root.add_child(_topbar)
	var band := ColorRect.new()
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = TOPBAR_SHADER
	m.shader = sh
	band.material = m
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.anchor_left = 0.5
	band.anchor_right = 0.5
	band.offset_left = -560
	band.offset_right = 560
	band.offset_bottom = 40
	_topbar.add_child(band)
	# Nửa trái (ngày, giờ, tiền) dồn về phía huy hiệu giữa, nửa phải là các nút.
	var left := HBoxContainer.new()
	left.add_theme_constant_override("separation", 22)
	left.alignment = BoxContainer.ALIGNMENT_END
	left.anchor_left = 0.5
	left.anchor_right = 0.5
	left.offset_left = -560
	left.offset_right = -70
	left.offset_top = 4
	left.offset_bottom = 36
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_topbar.add_child(left)
	_tb_day = _outlined(UI.label("", 16, UI.HUD_TEXT))
	left.add_child(_tb_day)
	# Ngày giờ, tiền đã sang bảng sinh tồn góc trên trái: nửa trái thanh trên cùng để trống cho gọn.
	left.visible = false
	var cash := HBoxContainer.new()
	cash.add_theme_constant_override("separation", 8)
	left.add_child(cash)
	var ci := ItemIcon.new("cash", UI.HUD_TEXT)
	ci.custom_minimum_size = Vector2(28, 28)
	cash.add_child(ci)
	_tb_cash = _outlined(UI.label("", 17, UI.GOLD))
	cash.add_child(_tb_cash)
	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.anchor_left = 0.5
	right.anchor_right = 0.5
	right.offset_left = 70
	right.offset_right = 560
	right.offset_top = 2
	right.offset_bottom = 38
	_topbar.add_child(right)
	var specs := [["person", "Nhân vật (C)", open_character], ["book", "Sổ: phải thu, phải trả, lời hứa", _toggle_skills],
		["list", "Nhật ký", _toggle_log], ["phone_line", "Điện thoại", _toggle_phone],
		["map", "Bản đồ (M)", func() -> void: _big_map.toggle()], ["zoom", "Toàn cảnh", func() -> void: world.toggle_overview()],
		["house", "Về chỗ ở ngủ", _go_home]]
	for sp in specs:
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(44, 36)
		b.tooltip_text = sp[1]
		var hover := StyleBoxFlat.new()
		hover.bg_color = Color(1, 1, 1, 0.12)
		hover.set_corner_radius_all(6)
		b.add_theme_stylebox_override("hover", hover)
		b.add_theme_stylebox_override("pressed", hover)
		b.pressed.connect(sp[2])
		var ic := ItemIcon.new(sp[0], Color("e9e4d8"))
		ic.position = Vector2(9, 5)
		ic.size = Vector2(26, 26)
		b.add_child(ic)
		var dot := _outlined(UI.label("!", 15, Color("ff4d3d")))
		dot.position = Vector2(30, -4)
		dot.visible = false
		b.add_child(dot)
		right.add_child(b)
		_tb_icons[sp[0]] = {"button": b, "icon": ic, "dot": dot}
	# Huy hiệu giữa: số ngày còn lại tới mốc của chương.
	var medal := ColorRect.new()
	var mm := ShaderMaterial.new()
	var msh := Shader.new()
	msh.code = MEDAL_SHADER
	mm.shader = msh
	medal.material = mm
	medal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	medal.anchor_left = 0.5
	medal.anchor_right = 0.5
	medal.offset_left = -56
	medal.offset_right = 56
	medal.offset_top = -38
	medal.offset_bottom = 74
	_topbar.add_child(medal)
	_tb_left = _outlined(UI.label("", 30, Color("f3e6c8")))
	_tb_left.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tb_left.position = Vector2(0, 38)
	_tb_left.size = Vector2(112, 36)
	medal.add_child(_tb_left)
	_tb_left_sub = _outlined(UI.label("ngày còn lại", 11, Color("d9c9a3")))
	_tb_left_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tb_left_sub.position = Vector2(0, 74)
	_tb_left_sub.size = Vector2(112, 16)
	medal.add_child(_tb_left_sub)


func _build_stats(parent: Control) -> void:
	_stats = PanelContainer.new()
	_stats.add_theme_stylebox_override("panel", UI.box(Color(0.06, 0.06, 0.08, 0.62), Color(1, 1, 1, 0.08), 8, 10))
	_stats.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_stats.mouse_filter = Control.MOUSE_FILTER_PASS
	_stats.tooltip_text = "Bấm để mở bảng Nhân vật (C)"
	_stats.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			open_character())
	parent.add_child(_stats)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	_st_clock = UI.label("", 24, UI.HUD_TEXT)
	top.add_child(_st_clock)
	var day_col := VBoxContainer.new()
	day_col.add_theme_constant_override("separation", -2)
	day_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(day_col)
	_st_day = UI.label("", 12, UI.HUD_SOFT)
	day_col.add_child(_st_day)
	var cash_row := HBoxContainer.new()
	cash_row.add_theme_constant_override("separation", 6)
	cash_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	day_col.add_child(cash_row)
	var ci := ItemIcon.new("cash", UI.GOLD)
	ci.custom_minimum_size = Vector2(18, 18)
	cash_row.add_child(ci)
	_st_cash = UI.label("", 15, UI.GOLD)
	cash_row.add_child(_st_cash)
	var specs := [["stamina", "Thể lực", "bolt", "100 trừ Mệt. Ngủ, nghỉ, ngồi trà đá để hồi; chạy nhanh (Shift) và làm việc nặng thì tụt."],
		["mood", "Tâm trạng", "heart", "Nghỉ ngơi, trà đá, ăn cơm với bà, nói chuyện với người quen thì vui lên; việc bẩn, ngủ ngoài đường thì xuống."],
		["fed", "Độ no", "bowl", "Ăn ở quán cơm, bánh mì buổi sáng. Đói tới 0 thì Mệt tăng nhanh."]]
	for sp in specs:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 6)
		r.mouse_filter = Control.MOUSE_FILTER_PASS
		r.tooltip_text = sp[3]
		v.add_child(r)
		var ic := ItemIcon.new(sp[2])
		ic.custom_minimum_size = Vector2(18, 18)
		r.add_child(ic)
		var l := UI.label(sp[1], 12, UI.HUD_SOFT)
		l.custom_minimum_size.x = 66
		r.add_child(l)
		var b := UI.bar(8)
		b.custom_minimum_size = Vector2(120, 8)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.add_child(b)
		var n := UI.label("", 12, UI.HUD_TEXT)
		n.custom_minimum_size.x = 26
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		r.add_child(n)
		_st_bars[sp[0]] = {"bar": b, "num": n}


func _refresh_stats(s: Dictionary) -> void:
	var hour: float = game.clock()
	var part := "Sáng" if hour < 11.0 else ("Trưa" if hour < 13.5 else ("Chiều" if hour < 18.0 else "Tối"))
	_st_clock.text = GameLogic.hh(minf(hour, 22.0))
	_st_day.text = "%s · Ngày %d, %s" % [part, game.day(), game.weekday_name()]
	_st_cash.text = GameLogic.fmt_money(int(s.cash))
	var vals := {"stamina": 100.0 - float(s.fatigue), "mood": game.need("mood"), "fed": game.need("fed")}
	for k in _st_bars:
		var x: float = vals[k]
		UI.set_bar(_st_bars[k].bar, x, 100.0, UI.level_color(x / 100.0))
		(_st_bars[k].num as Label).text = str(int(x))


## Hành động nhanh trước cửa địa điểm: tối đa ba việc sinh hoạt (ăn, tắm, nghỉ…) làm được ngay, ghi giá, tác dụng,
## thời gian; việc chưa làm được thì ghi lý do. Phím 1–3 hay bấm, khỏi mở bảng địa điểm.
# ---------------------------------------------------------------- tủ đồ, túi mù

var _wardrobe: PanelContainer
var _wr_tab := "all"
var _wr_body: GridContainer
var _wr_title: Label
var _wr_foot: Label


## Bảng tủ đồ: "new" là các món vừa bóc (lật thẻ theo hạng), "all" là cả tủ theo từng chỗ mặc; bấm Mặc để thay.
func open_wardrobe(tab: String) -> void:
	if _wardrobe == null:
		_wardrobe = _light_panel(_root)
		_wardrobe.custom_minimum_size = Vector2(minf(760.0, get_viewport().get_visible_rect().size.x - 40.0), 0)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 10)
		_wardrobe.add_child(v)
		var head := HBoxContainer.new()
		v.add_child(head)
		_wr_title = UI.label("", 22, UI.INK)
		_wr_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(_wr_title)
		for t in [["new", "Vừa bóc"], ["all", "Tủ đồ"]]:
			var b := Button.new()
			b.text = t[1]
			var tab_id: String = t[0]
			b.pressed.connect(func() -> void: _fill_wardrobe(tab_id))
			head.add_child(b)
		var close := Button.new()
		close.text = "Đóng"
		close.pressed.connect(func() -> void: _wardrobe.visible = false)
		head.add_child(close)
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(0, minf(420.0, get_viewport().get_visible_rect().size.y - 200.0))
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		v.add_child(scroll)
		_wr_body = GridContainer.new()
		_wr_body.columns = 4
		_wr_body.add_theme_constant_override("h_separation", 10)
		_wr_body.add_theme_constant_override("v_separation", 10)
		_wr_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(_wr_body)
		_wr_foot = UI.label("", 13, UI.INK_SOFT)
		_wr_foot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(_wr_foot)
	close_location()
	_wardrobe.visible = true
	_fill_wardrobe(tab)


func _fill_wardrobe(tab: String) -> void:
	_wr_tab = tab
	for c in _wr_body.get_children():
		c.queue_free()
	var w: Dictionary = game.wardrobe()
	var ids: Array = []
	if tab == "new":
		ids = (w.get("last", []) as Array).duplicate()
		_wr_title.text = "Bóc túi mù si-đa" if not ids.is_empty() else "Chưa bóc túi nào"
	else:
		_wr_title.text = "Tủ đồ của An · %d món" % w.owned.size()
		for it in game.clothes.get("items", []):
			if w.owned.has(str(it.id)):
				ids.append(str(it.id))
		ids.sort_custom(func(x, y) -> bool:
			var a: Dictionary = game.cloth(x)
			var b: Dictionary = game.cloth(y)
			return str(a.slot) < str(b.slot) or (str(a.slot) == str(b.slot) and game._rarity_i(str(a.rarity)) > game._rarity_i(str(b.rarity))))
	for id in ids:
		_wr_body.add_child(_cloth_card(str(id)))
	var worn: Array = []
	for slot in w.worn:
		worn.append(str(game.cloth(str(w.worn[slot])).get("name", "")))
	_center_wardrobe.call_deferred()
	_wr_foot.text = "Phong cách: %d (mỗi sáng Tâm trạng +%d). Đang mặc: %s. Túi liền chưa ra Hiếm: %d/%d. Phím T mở tủ đồ." % [
		game.style(), int(minf(8.0, game.style() * 0.5)), ", ".join(worn) if not worn.is_empty() else "đồ cũ ở nhà",
		int(w.get("pity", 0)), int(game.clothes.get("pity", 10))]


## Bảng tủ đồ nằm giữa màn hình (cỡ bảng đổi theo số thẻ).
func _center_wardrobe() -> void:
	_wardrobe.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_wardrobe.reset_size()
	var vp := get_viewport().get_visible_rect().size
	_wardrobe.position = ((vp - _wardrobe.size) / 2.0).max(Vector2(8, 8))


func _cloth_card(id: String) -> Control:
	var it: Dictionary = game.cloth(id)
	var rar: Dictionary = game.clothes.rarities.get(str(it.get("rarity", "thuong")), {})
	var rc := Color(str(rar.get("color", "a8a090")))
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(168, 150)
	card.add_theme_stylebox_override("panel", UI.box(UI.PAPER, rc, 8, 10))
	(card.get_theme_stylebox("panel") as StyleBoxFlat).set_border_width_all(3)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	card.add_child(v)
	var top := HBoxContainer.new()
	v.add_child(top)
	var sw := ColorRect.new()
	sw.color = Color(str(it.get("color", "888888")))
	sw.custom_minimum_size = Vector2(22, 22)
	top.add_child(sw)
	var rl := UI.label(" " + str(rar.get("name", "")).to_upper(), 11, rc.darkened(0.25))
	top.add_child(rl)
	var n := UI.label(str(it.get("name", id)), 14, UI.INK)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.custom_minimum_size = Vector2(148, 0)
	v.add_child(n)
	var info := "%s · phong cách +%d" % [str(game.clothes.slots.get(str(it.slot), it.slot)), int(it.get("style", 0))]
	var have := int(game.wardrobe().owned.get(id, 0))
	if have > 1:
		info += " · có %d cái" % have
	v.add_child(UI.label(info, 11, UI.INK_SOFT))
	for k in it.get("perk", {}):
		var a: Dictionary = game.get_action(str(k))
		v.add_child(UI.label("+%d%% tiền công: %s" % [int(float(it.perk[k]) * 100.0), str(a.get("name", k))], 10, Color("2f7a4a")))
	var worn: bool = game.wardrobe().worn.get(str(it.slot), "") == id
	var b := Button.new()
	b.text = "Đang mặc · cởi ra" if worn else "Mặc"
	b.pressed.connect(func() -> void:
		if worn:
			game.unwear(str(it.slot))
		else:
			game.wear_item(id)
		world.update_outfit()
		_fill_wardrobe(_wr_tab))
	v.add_child(b)
	return card


var _bench: Window


## Bàn sửa 3D của đơn đang ở bước sửa (scripts/world/repair_bench.gd): kéo linh kiện, siết vít.
func _open_bench() -> void:
	if blocking() or _loc_id != "tiem_sau":
		return
	var job: Dictionary = game.s.street.job
	if job.is_empty() or str(job.stage) not in ["repair", "test"]:
		return
	_bench = RepairBench.new()
	_bench.game = game
	add_child(_bench)


## Phím E cạnh hàng rong: mua món đầu tiên đang mua được.
func quick_first() -> void:
	if not _quick_ids.is_empty():
		_perform(str(_quick_ids[0]))


func _fill_quick(id: String) -> void:
	for c in _quick.get_children():
		c.queue_free()
	_quick_ids.clear()
	if id == "" or id == "-" or id.begins_with("bin:") or not game.is_started():
		_quick.visible = false
		return
	var picks: Array = []
	for a in game.actions_at(id):
		if str(a.group) == "life":
			picks.append(a)
	picks.sort_custom(func(x, y) -> bool: return bool(game.action_status(x).ok) and not bool(game.action_status(y).ok))
	for a in picks.slice(0, 3):
		var st: Dictionary = game.action_status(a)
		var parts := [str(a.name)]
		if int(a.get("cost", 0)) > 0:
			parts.append("−" + GameLogic.fmt_money(int(a.cost)))
		var eff: String = UI.effects_text(game, a)
		if eff != "":
			parts.append(eff)
		if a.get("rest", false):
			parts.append("Tâm trạng +%d" % int(game.cfg.needs.get("moodRest", 0)))
		parts.append("%d phút" % int(round(float(a.hours) * 60.0)))
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 13)
		var n := _quick_ids.size() + 1
		if st.ok:
			b.text = "[%d]  %s" % [n, "  ·  ".join(parts)]
			b.add_theme_color_override("font_color", UI.HUD_TEXT)
			b.add_theme_color_override("font_hover_color", UI.GOLD)
			var aid := str(a.id)
			b.pressed.connect(func() -> void: _perform(aid))
			_quick_ids.append(str(a.id))
		else:
			b.text = "      %s  ·  %s" % [str(a.name), str(st.reason) if str(st.reason) != "" else "chưa làm được"]
			b.add_theme_color_override("font_color", Color(UI.HUD_SOFT, 0.7))
			b.disabled = true
			b.add_theme_color_override("font_disabled_color", Color(UI.HUD_SOFT, 0.7))
		_quick.add_child(b)
	_quick.visible = _quick.get_child_count() > 0


func _build_mood(root: Control) -> void:
	_mood = MoodRing.new()
	_mood.custom_minimum_size = Vector2(84, 84)
	_mood.size = Vector2(84, 84)
	_mood.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_mood.position = Vector2(20, -128)
	_mood.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_mood.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
			open_character())
	root.add_child(_mood)
	# Nhu cầu đang thiếu (đói, bẩn, quần áo, mệt) hiện thành biểu tượng nhỏ cạnh vòng.
	_mood_needs = HBoxContainer.new()
	_mood_needs.add_theme_constant_override("separation", 4)
	_mood_needs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mood_needs.position = Vector2(92, 30)
	_mood.add_child(_mood_needs)


func _refresh_topbar(s: Dictionary) -> void:
	var hour: float = game.clock()
	var part := "Buổi sáng" if hour < 11.0 else ("Buổi trưa" if hour < 13.5 else ("Buổi chiều" if hour < 18.0 else "Buổi tối"))
	if ScreenFit.compact:
		_tb_day.text = "Ngày %d · %s" % [game.day(), GameLogic.hh(minf(hour, 22.0))]
	else:
		_tb_day.text = "Ngày %d · %s (%s)   %s" % [game.day(), game.weekday_name(), part, GameLogic.hh(minf(hour, 22.0))]
	_tb_cash.text = GameLogic.fmt_money(int(s.cash))
	var last: int = game.last_day() if game.is_full() else 22
	_tb_left.text = str(maxi(0, last - game.day() + 1))
	var due_today := false
	for p in s.promises:
		if p.status == "open" and int(p.due) == game.day():
			due_today = true
	_tb_icons.book.dot.visible = due_today
	_tb_icons.phone_line.dot.visible = not _offer.is_empty() and not _phone.visible
	(_tb_icons.house.button as Button).disabled = _end_day_btn.disabled
	(_tb_icons.house.icon as Control).modulate.a = 0.35 if _end_day_btn.disabled else 1.0
	(_tb_icons.house.button as Button).tooltip_text = ("Về nhà" if game.chapter() >= 2 else "Về xóm trọ") + " (ngủ, tắm giặt)"
	var pd: float = game.phong_do()
	_mood.set("value", pd)
	_mood.set("word", MoodRing.word_for(pd))
	_mood.tooltip_text = "Phong độ %d · %s\nMệt %d/100 · Tâm trạng %d · No bụng %d · Vệ sinh %d · Quần áo %d\nBấm để mở bảng Nhân vật" % [
		int(pd), "đủ lương" if game.pay_mult() >= 1.0 else "chỉ được %d%% lương" % int(game.pay_mult() * 100.0),
		int(s.fatigue), int(game.need("mood")), int(game.need("fed")), int(game.need("clean")), int(game.need("neat"))]
	_mood.queue_redraw()
	for c in _mood_needs.get_children():
		c.queue_free()
	var lows := []
	if game.fatigue_warn():
		lows.append("moon")
	if game.has_needs():
		for k in [["fed", "bowl"], ["clean", "drop"], ["neat", "tshirt"]]:
			if game.need(k[0]) < 30.0:
				lows.append(k[1])
	for k in lows:
		var ic := ItemIcon.new(k)
		ic.custom_minimum_size = Vector2(26, 26)
		_mood_needs.add_child(ic)


func _tool_button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(on_press)
	return b


# ---------------------------------------------------------------- vẽ lại

func _refresh() -> void:
	var started: bool = game.is_started()
	# Vừa bóc túi mù hay bấm mở tủ đồ (GameLogic._special đặt ui_open).
	if started and str(game.s.get("ui_open", "")) != "":
		var what := str(game.s.ui_open)
		game.s.erase("ui_open")
		open_wardrobe.call_deferred("new" if what == "gacha" else "all")
	for p in [_objectives, _topbar, _mood, _stats]:
		p.visible = started
	if joystick != null:
		joystick.visible = started
	for p in [_status, _bottom, _map]:
		p.visible = false
	if not started:
		_loc_id = ""
		_location.visible = false
		_tip.visible = false
		_tip_id = ""
		_update_prompt()
		return
	var s: Dictionary = game.s
	_refresh_objectives(s)
	var last: int = game.last_day() if game.is_full() else 30
	_day_label.text = "Ngày %d/%d · %s" % [game.day(), last, game.weekday_name()]
	_clock_label.text = "%s  ·  còn %s giờ trong ngày" % [GameLogic.hh(minf(game.clock(), 22.0)), GameLogic.num(game.hours_left())]
	_cash_label.text = GameLogic.fmt_money(int(s.cash))
	_recv_label.text = "Phải thu: %s trước ngày %d · %s sau\nPhải trả: %s" % [
		GameLogic.fmt_k(game.receivable_sum(0, last)), last, GameLogic.fmt_k(game.receivable_sum(last + 1, 999)), GameLogic.fmt_k(game.payable_sum(999))]
	# Điện thoại: bỏ dòng phải thu, phải trả cho bảng gọn (xem trong Sổ).
	_recv_label.visible = not ScreenFit.compact
	var warn := float(game.cfg.fatigue.warn)
	_fatigue_label.text = "Mệt %d/100%s" % [int(s.fatigue), "  · cần nghỉ" if game.fatigue_warn() else ""]
	UI.set_bar(_fatigue_bar, float(s.fatigue), 100.0, UI.STAMP if float(s.fatigue) >= warn else (UI.WARN if float(s.fatigue) >= warn - 20 else UI.GOOD))
	var needs: bool = game.has_needs()
	for c in [_pd_label, _pd_bar, _needs_label]:
		c.visible = needs
	if needs:
		var pd: float = game.phong_do()
		var mult: float = game.pay_mult()
		_pd_label.text = "Phong độ %d · %s" % [int(pd), "đủ lương" if mult >= 1.0 else "chỉ được %d%% lương" % int(mult * 100.0)]
		UI.set_bar(_pd_bar, pd, 100.0, UI.level_color(pd / 100.0))
		_needs_label.text = "No bụng %d · Vệ sinh %d · Quần áo %d" % [int(game.need("fed")), int(game.need("clean")), int(game.need("neat"))]
		var worst := minf(game.need("fed"), minf(game.need("clean"), game.need("neat")))
		_needs_label.add_theme_color_override("font_color", UI.HUD_SOFT if worst >= 35.0 else (UI.GOLD if worst >= 15.0 else Color("ff8a7a")))
	_end_day_btn.disabled = game.is_over() or not s.queue.is_empty() or _working
	_end_day_btn.text = "Về nhà" if game.chapter() >= 2 else "Về xóm trọ"
	_refresh_topbar(s)
	_refresh_stats(s)
	if _prompt_id != "-":
		_fill_quick(_prompt_id)
	_refresh_skills(s)
	_log_text.text = UI.log_bbcode(game)
	_refresh_location()
	_update_prompt()
	_make_room()


func _update_prompt() -> void:
	_prompt.visible = game.is_started() and _prompt_id != "" and _prompt_id != "-" and _loc_id == "" and not blocking()


func _refresh_objectives(s: Dictionary) -> void:
	_guide_button = null
	_guide_location = ""
	_guide_primary_id = ""
	for c in _objective_box.get_children():
		c.queue_free()
	_obj_n = 0
	_obj_hidden = 0
	_fill_objectives(s)
	if _obj_hidden > 0:
		_objective_box.add_child(_outlined(UI.label("     +%d mục nữa · bấm để xem hết" % _obj_hidden, 12, UI.HUD_SOFT)))
	elif _obj_expanded:
		_objective_box.add_child(_outlined(UI.label("     bấm để thu gọn", 12, UI.HUD_SOFT)))
	_fit_objectives()


## Màn thấp, bảng mục tiêu mở hết: khung cuộn cao vừa nội dung, tối đa phần màn còn trống phía trên lời nhắc và thanh
## công cụ (chương 3 có nhiều khoản phải trả, mở hết là dài hơn màn điện thoại nằm ngang). Các lúc khác bảng cao theo
## nội dung như cũ.
func _fit_objectives() -> void:
	var limit: bool = _obj_expanded
	_obj_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if limit else ScrollContainer.SCROLL_MODE_DISABLED
	var h := 0.0
	if limit:
		h = minf(_objective_box.get_combined_minimum_size().y, clampf(ScreenFit.view_size().y - 260.0, 80.0, 600.0))
	if not is_equal_approx(_obj_scroll.custom_minimum_size.y, h):
		_obj_scroll.custom_minimum_size.y = h


func _fill_objectives(s: Dictionary) -> void:
	var targets: Array = QuestGuide.targets(game)
	if not targets.is_empty():
		var primary: Dictionary = targets[0]
		_guide_primary_id = str(primary.id)
		_objective(str(primary.title), _guide_description(primary), "current")
		var loc := str(primary.get("location", ""))
		if bool(primary.get("navigable", true)) and world.LOCATIONS.has(loc):
			_guide_location = loc
			_guide_button = Button.new()
			_guide_button.add_theme_font_size_override("font_size", 12)
			_guide_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			_guide_button.mouse_filter = Control.MOUSE_FILTER_STOP
			_guide_button.pressed.connect(func() -> void:
				# Recheck the current state: a deadline may have passed since redraw.
				var latest: Dictionary = QuestGuide.active(game)
				if latest.is_empty() or not bool(latest.get("navigable", true)): return
				var destination := str(latest.get("location", ""))
				if not world.LOCATIONS.has(destination): return
				close_location()
				_big_map.visible = false
				world.walk_to_location(destination))
			_objective_box.add_child(_guide_button)
			_refresh_guide_distance()
		for other in targets.slice(1):
			# Quest details already have a section below; scene/order/follow-up
			# alternatives share the same descriptions and availability here.
			if str(other.id).begins_with("quest:"): continue
			_objective("Còn có: " + str(other.title), _guide_description(other), "normal")
	if game.chapter() == 2:
		_refresh_objectives2(s)
		return
	if game.chapter() == 5:
		_refresh_objectives5(s)
		return
	if game.chapter() == 4:
		_refresh_objectives4(s)
		return
	if game.chapter() == 3:
		_refresh_objectives3(s)
		return
	var deadline := int(game.cfg.housingDeadline)
	var h: Dictionary = game.housing()
	if h.state == "signed":
		_objective("Chỗ ở: " + str(game.cfg.housing[h.place].name), "Đã chốt" + (" · ở tạm, hẹn tìm tiếp" if game.cfg.housing[h.place].get("temp", false) else ""), "done")
	else:
		var proj: int = game.projected_cash(deadline)
		var best: String = game.best_housing(proj)
		var sub := "Không kiếm thêm thì sáng ngày %d còn %s" % [deadline, GameLogic.fmt_money(proj)]
		sub += " · chưa đủ cả chỗ ở tạm" if best == "" else " · đủ cho %s" % game.cfg.housing[best].name
		# Mốc kế tiếp: chỗ rẻ nhất mà chưa đủ tiền, để người chơi biết còn thiếu bao nhiêu.
		var next := ""
		for k in game.cfg.housing:
			var c := int(game.cfg.housing[k].cost)
			if c > proj and (next == "" or c < int(game.cfg.housing[next].cost)):
				next = k
		if next != "":
			sub += " · thiếu %s cho %s" % [GameLogic.fmt_money(int(game.cfg.housing[next].cost) - proj), game.cfg.housing[next].name]
		if h.state == "reserved":
			sub = "Đã cọc giữ %s, còn thiếu %s · " % [game.cfg.housing[h.place].name, GameLogic.fmt_money(game.housing_cost(h.place))] + sub
		_objective("Ngày %d chốt chỗ ở" % deadline, sub, "current" if game.day() >= 20 else "normal")
	if game.is_full():
		for r in s.receivables:
			if str(r.id).begins_with("luong_cu") and r.status == "pending":
				_objective("Lương cũ: %s" % GameLogic.fmt_money(int(r.amount)), "chưa hẹn ngày trả" if int(r.due) > 90 else "hẹn ngày %d" % int(r.due), "normal")
	if s.route in ["B", "C"]:
		var mid = null
		for r in s.receivables:
			if r.id == "hd_giua":
				mid = r
		var state := "normal"
		if mid != null and mid.status == "collected":
			state = "done"
		elif game.day() > 20:
			state = "failed"
		else:
			state = "current"
		var final_open := false
		for p in s.promises:
			if p.id == "ban_giao_cuoi" and p.status == "open":
				final_open = true
		if final_open:
			_objective("Bàn giao giai đoạn cuối Tạ Hiện trước tối ngày 27", "Tiến độ %d/%d buổi" % [int(s.progress), int(s.progress_need)], "current")
		elif game.day() <= 22:
			var sub := "Tiến độ %d/%d buổi" % [int(s.progress), int(s.progress_need)]
			if state == "current" and int(s.progress) >= int(s.progress_need):
				sub += " · đủ rồi; làm thêm thì tính cho giai đoạn cuối"
			_objective("Nghiệm thu đợt giữa Tạ Hiện tối ngày 20", sub, state)
	if game.day() <= 22:
		var linh_state := "done" if s.linh.decision != "" else ("current" if game.day() >= 19 else "normal")
		_objective("Nghe Linh nói về chỗ thực tập (ngày 22)", "Quyết định là của Linh", linh_state)
	var due_today := 0
	for p in s.promises:
		if p.status == "open" and int(p.due) == game.day():
			due_today += 1
	if due_today > 0:
		_objective("Lời hứa đến hạn hôm nay: %d" % due_today, "Mở Sổ để xem", "current")
	_objective("Trả chìa khóa phòng cũ cho cô Duyên ngày 30", "", "normal")
	_quest_objectives()


## Chương 2: tiền nhà tháng sau, đôi mắt của bà, má, giỗ ông; cảnh chính và việc nhờ như chương 1.
func _refresh_objectives2(s: Dictionary) -> void:
	var due := int(game.cfg.chapter2.rentDue)
	var h: Dictionary = game.housing()
	var rent = null
	for x in s.payables:
		if x.id == ("tien_nha_t2" if game.has_long_home() else "phong_moi"):
			rent = x
	var title := "Tiền nhà tháng sau" if game.has_long_home() else "Phần còn lại phòng mới, dọn sau giỗ"
	if rent == null and not game.has_long_home():
		_objective("Đặt cọc phòng mới trước giỗ ông", "Ở nhờ dì Nga tới sau giỗ · cọc ngõ Gạch hay Ngọc Thụy, dọn sau ngày %d" % due, "current")
	elif rent != null and rent.status == "pending":
		# Dự kiến đã trừ tiền sinh hoạt mỗi tối và các khoản phải trả khác tới ngày đóng.
		var proj: int = game.projected_cash(due)
		var sub := "%s · " % GameLogic.fmt_money(int(rent.amount))
		if proj >= int(rent.amount):
			sub += "không kiếm thêm vẫn đủ"
		else:
			sub += "từ giờ tới tối ngày %d cần kiếm thêm %s (đã tính tiền sinh hoạt)" % [due, GameLogic.fmt_money(int(rent.amount) - proj)]
		_objective("%s (tối ngày %d)" % [title, due], sub, "current" if game.day() >= 54 else "normal")
	elif rent != null:
		_objective(title, "Đã đóng" if rent.status == "paid" else "Chưa đủ, phải hẹn lại", "done" if rent.status == "paid" else "failed")
	for r in s.receivables:
		if r.status == "pending" and int(r.due) <= due and int(r.due) >= game.day():
			_objective("Còn chờ nhận: %s" % r.label, "%s · hạn ngày %d" % [GameLogic.fmt_money(int(r.amount)), int(r.due)], "normal")
	var f: Dictionary = s.flags
	if f.get("daMo", false):
		_objective("Mắt của bà: đã mổ", "Nhỏ thuốc mỗi ngày, không để nước vào mắt", "done")
	elif f.get("moSom", false):
		_objective("Mổ mắt cho bà sáng ngày 43", "Ai đi cùng, ai ở nhà nhỏ thuốc", "current" if game.day() >= 41 else "normal")
	elif f.get("moBhyt", false):
		_objective("Mổ mắt cho bà sáng ngày 46", "Suất bảo hiểm, ngay sau con nước rằm", "current" if game.day() >= 44 else "normal")
	elif f.get("moDoi", false):
		_objective("Bà chọn để sau Tết mới mổ", "Quyết định là của bà", "done")
	elif game.day() <= 36:
		_objective("Đưa bà đi khám mắt sáng ngày 36", "Bệnh viện mắt thành phố, đi xe buýt ở bến xe Giáp Bát", "current" if game.day() >= 35 else "normal")
	else:
		_objective("Cả nhà bàn chuyện mổ mắt (ngày 40)", "Người quyết là bà", "current" if game.day() >= 38 else "normal")
	if f.get("maVe", false) and not s.has("ma"):
		_objective("Mẹ đang ở nhà", "Đi hay ở là quyết định của mẹ", "normal")
	var due_today := 0
	for p in s.promises:
		if p.status == "open" and int(p.due) == game.day():
			due_today += 1
	if due_today > 0:
		_objective("Lời hứa đến hạn hôm nay: %d" % due_today, "Mở Sổ để xem", "current")
	var home_place := str(s.get("home2", {}).get("place", h.place))
	_objective("Giỗ ông ngoại tối ngày 60", "Ở " + str(game.cfg.housing.get(home_place, {}).get("name", "chỗ mới")), "current" if game.day() >= 58 else "normal")
	_quest_objectives()


## Chương 3: tiền nhà tháng sau, cọc tiệm Sáu, nợ còn lại của tháng trước, Vu Lan, Linh, ông Ba, chuyến về quê.
func _refresh_objectives3(s: Dictionary) -> void:
	var f: Dictionary = s.flags
	var rows := [["tien_nha_t3", "Tiền nhà tháng sau", 84], ["coc_tiem", "Cọc mặt bằng tiệm Sơn", 83],
		["do_nghe_sau", "Đợt đầu tiền đồ nghề trả chú Sơn", 84], ["tien_nha_t2", "Tiền nhà tháng trước còn hẹn", 64],
		["phong_moi", "Phần còn lại phòng mới còn hẹn", 64], ["gop_di_nam_3", "Góp tiền chợ nhà dì Nga còn hẹn", 64],
		["gop_di_nam_4", "Góp tiền chợ ở nhờ nhà dì Nga", 84], ["phong_moi_t8", "Phần còn lại phòng mới, dọn mùng 1 tháng Tám", 84]]
	if game.check({"home": "di_nam", "housing_state": "signed"}) == "" and game.day() <= 86:
		_objective("Đặt cọc phòng mới trong tháng Bảy", "Ở nhờ dì Nga tới hết tháng · cọc ngõ Gạch hay Ngọc Thụy, dọn mùng một tháng Tám",
			"current" if game.day() >= 80 else "normal")
	_payable_objectives(s, rows)
	if f.get("tiemKhongNhan", false):
		_objective("Tiệm Sơn: không nhận", "Tiệm về tay người khác, mình giữ nhịp làm cũ", "done")
	elif not (f.get("tiemChung", false) or f.get("tiemMotMinh", false)) and f.get("henTinhTiem", false):
		_objective("Chú Sơn mời sang tiệm", "Quyết trước tối ngày 80 · cọc mặt bằng 3.000.000đ, đồ nghề trả dần", "current" if game.day() >= 78 else "normal")
	if game.day() <= 75:
		_objective("Rằm tháng Bảy · Vu Lan (tối ngày 75)", "Bông hồng cài áo ở chùa đầu đường", "current" if game.day() >= 73 else "normal")
	if not s.has("linh3") and game.day() <= 82:
		_objective("Linh chọn chỗ làm sau thực tập (ngày 82)", "Người quyết là Linh", "normal")
	if not s.has("ong_ba3") and not f.get("ongBaDi", false) and game.day() <= 88:
		_objective("Ông Bảo và cái hiên gỗ", "Họp dân ngày 78 · hạn ký đợt một ngày 85 · ông quyết", "current" if game.day() >= 77 else "normal")
	if (f.get("huaVeQue", false) or f.get("linhDuaBa", false)) and not f.get("veQue", false) and game.day() <= 84:
		_objective("Bà về quê mừng thọ bà Cả (sáng ngày 84)", "%s đưa bà đi · xe ở bến xe Giáp Bát" % ("An" if f.get("huaVeQue", false) else "Linh"),
			"current" if game.day() >= 83 else "normal")
	var due_today := 0
	for p in s.promises:
		if p.status == "open" and int(p.due) == game.day():
			due_today += 1
	if due_today > 0:
		_objective("Lời hứa đến hạn hôm nay: %d" % due_today, "Mở Sổ để xem", "current")
	_objective("Đêm cuối tháng Bảy (tối ngày 90)", "Sáng mùng một tháng Tám chú Sơn giao chìa khóa tiệm", "current" if game.day() >= 88 else "normal")
	_quest_objectives()


## Từng khoản phải trả trong danh sách [id, tên, ngày bắt đầu nhắc gấp]: còn chờ thì ghi số tiền và phần còn phải kiếm,
## đã đóng hay phải hẹn lại thì ghi kết quả.
func _payable_objectives(s: Dictionary, rows: Array) -> void:
	for row in rows:
		var x = null
		for p in s.payables:
			if p.id == row[0]:
				x = p
		if x == null:
			continue
		var due := int(x.due)
		if x.status == "pending":
			# Dự kiến đã trừ tiền sinh hoạt mỗi tối và các khoản phải trả khác tới ngày đóng.
			var proj: int = game.projected_cash(due)
			var sub := "%s · " % GameLogic.fmt_money(int(x.amount))
			if proj >= int(x.amount):
				sub += "không kiếm thêm vẫn đủ"
			else:
				sub += "từ giờ tới tối ngày %d cần kiếm thêm %s (đã tính tiền sinh hoạt)" % [due, GameLogic.fmt_money(int(x.amount) - proj)]
			_objective("%s (tối ngày %d)" % [row[1], due], sub, "current" if game.day() >= int(row[2]) else "normal")
		else:
			_objective(str(row[1]), "Đã đóng" if x.status == "paid" else "Chưa đủ, phải hẹn lại", "done" if x.status == "paid" else "failed")


## Chương 4: tiền nhà, tiền mặt bằng, đồ nghề tháng sau, nợ còn lại của tháng Bảy, đơn quạt của trường, lời mời của anh Quân,
## Trung thu, chú Sáu về quê.
func _refresh_objectives4(s: Dictionary) -> void:
	var f: Dictionary = s.flags
	_payable_objectives(s, [["tien_nha_t4", "Tiền nhà tháng sau", 114], ["mat_bang_t9", "Tiền mặt bằng tiệm tháng sau", 114],
		["do_nghe_sau_2", "Đợt hai tiền đồ nghề trả chú Sơn", 114], ["dien_nuoc_t4", "Điện nước tháng này", 103],
		["tien_nha_t3", "Tiền nhà tháng trước còn hẹn", 94], ["coc_tiem", "Cọc mặt bằng tiệm Sơn còn hẹn", 94],
		["do_nghe_sau", "Đợt đầu tiền đồ nghề còn hẹn", 94], ["gop_di_nam_4", "Góp tiền chợ nhà dì Nga còn hẹn", 94],
		["gop_di_nam_5", "Góp tiền chợ ở nhờ nhà dì Nga", 114], ["phong_moi_t9", "Phần còn lại phòng mới, dọn mùng 1 tháng Chín", 114]])
	if game.check({"home": "di_nam", "housing_state": "signed"}) == "" and game.day() <= 116:
		_objective("Đặt cọc phòng mới trong tháng Tám", "Ở nhờ dì Nga tới hết tháng · cọc ngõ Gạch hay Ngọc Thụy, dọn mùng một tháng Chín",
			"current" if game.day() >= 110 else "normal")
	if f.get("treDonTruong", false):
		_objective("Đơn quạt của trường: trễ", "Ba phòng chưa có quạt sáng khai giảng", "failed")
	elif f.get("donTruongXong", false):
		_objective("Đơn quạt của trường", "Đã nghiệm thu", "done")
	if not f.get("tuChoiQuan", false) and not f.get("vaoTrungTam", false) and f.get("loiMoiQuan", false) and game.day() <= 116:
		_objective("Trả lời anh Quân (ngày 116)", "Thợ chính trung tâm bảo hành · 9 triệu, giờ hành chính", "current" if game.day() >= 114 else "normal")
	if game.day() <= 105:
		_objective("Rằm tháng Tám · Trung thu (tối ngày 105)", "Sân kho trên nền xóm cũ", "current" if game.day() >= 103 else "normal")
	if f.get("chuSauVeQue", false) and game.day() <= 119:
		_objective("Chú Sơn về Thái Bình (sáng ngày 119)", "Chuyến xe sáu giờ ở bến xe Giáp Bát", "current" if game.day() >= 118 else "normal")
	var due_today := 0
	for p in s.promises:
		if p.status == "open" and int(p.due) == game.day():
			due_today += 1
	if due_today > 0:
		_objective("Lời hứa đến hạn hôm nay: %d" % due_today, "Mở Sổ để xem", "current")
	_objective("Đêm cuối tháng Tám (tối ngày 120)", "Tiền nhà tháng sau, sổ tiệm tháng đầu", "current" if game.day() >= 118 else "normal")
	_quest_objectives()


## Chương 5: tiền nhà, mặt bằng, đợt cuối đồ nghề, nợ còn lại của tháng Tám, cái lưng của An, lớp học buổi tối, ông Ba
## nằm viện, con nước rằm tháng Chín, năm mươi tuổi của má.
func _refresh_objectives5(s: Dictionary) -> void:
	var f: Dictionary = s.flags
	_payable_objectives(s, [["tien_nha_t5", "Tiền nhà tháng sau", 144], ["mat_bang_t10", "Tiền mặt bằng tiệm tháng sau", 144],
		["mat_bang_tang", "Phần tăng tiền mặt bằng của cô Tâm", 144], ["do_nghe_sau_3", "Đợt cuối tiền đồ nghề trả chú Sơn", 144],
		["dien_nuoc_t5", "Điện nước tháng này", 133], ["tien_nha_t4", "Tiền nhà tháng trước còn hẹn", 124],
		["mat_bang_t9", "Tiền mặt bằng tháng trước còn hẹn", 124], ["do_nghe_sau_2", "Đợt hai tiền đồ nghề còn hẹn", 124],
		["gop_di_nam_5", "Góp tiền chợ nhà dì Nga còn hẹn", 124], ["gop_di_nam_6", "Góp tiền chợ ở nhờ nhà dì Nga", 144],
		["phong_moi_t10", "Phần còn lại phòng mới, dọn mùng 1 tháng Mười", 144]])
	if game.check({"home": "di_nam", "housing_state": "signed"}) == "" and game.day() <= 146:
		_objective("Đặt cọc phòng mới trong tháng Chín", "Ở nhờ dì Nga tới hết tháng · cọc ngõ Gạch hay Ngọc Thụy, dọn mùng một tháng Mười",
			"current" if game.day() >= 140 else "normal")
	if f.get("dauLung", false) and not f.get("khamLung", false):
		_objective("Cái lưng của An: chưa đi khám", "Trạm y tế phường gần chợ Long Biên · đau mà gồng thì tới lúc gãy", "current")
	elif f.get("khamLung", false):
		_objective("Cái lưng của An: đã khám", "Không khiêng một mình đồ trên hai chục ký", "done")
	if f.get("hocXong", false):
		_objective("Lớp điện lạnh buổi tối", "Đã học xong, có giấy chứng nhận", "done")
	if f.get("ongBaNamVien", false) and not f.get("ongBaXuatVien", false) and game.day() <= 140:
		_objective("Ông Bảo nằm viện", "Phòng chung tầng ba bệnh viện quận · trực đêm chia với anh Tài", "normal")
	if game.day() <= 136:
		_objective("Rằm tháng Chín · triều cường (ngày 135–136)", "Kê máy của khách lên kệ, coi nhà người già", "current" if game.day() >= 133 else "normal")
	if game.day() <= 145:
		_objective("Mẹ tròn năm mươi tuổi (tối ngày 145)", "Hỏi mẹ muốn gì, hay tự lo một bữa", "current" if game.day() >= 142 else "normal")
	var due_today := 0
	for p in s.promises:
		if p.status == "open" and int(p.due) == game.day():
			due_today += 1
	if due_today > 0:
		_objective("Lời hứa đến hạn hôm nay: %d" % due_today, "Mở Sổ để xem", "current")
	_objective("Đêm cuối tháng Chín (tối ngày 150)", "Tiền nhà tháng sau, tờ giấy ghi điều An muốn", "current" if game.day() >= 148 else "normal")
	_quest_objectives()


## Việc nhờ đang làm và người đang cần giúp.
func _quest_objectives() -> void:
	var active: Array = game.quests_active()
	active = active.filter(func(id): return "quest:" + str(id) != _guide_primary_id)
	if ScreenFit.compact and not _obj_expanded:
		# Gọn: mỗi loại một dòng; chạm vào bảng để xem từng việc.
		if not active.is_empty():
			_obj_hidden += active.size()
		if not game.quest_offers().is_empty():
			_obj_hidden += 1
		return
	if not active.is_empty():
		_objective_box.add_child(UI.label("Việc nhờ đang làm", 14, Color("9fc4ff")))
	for id in active:
		var st: Dictionary = game.s.quests[id]
		var urgent: bool = st.has("step_deadline") or float(st.deadline) - game.now_abs() < 3.0
		_objective_box.add_child(UI.label("★  %s · %s" % [game.quest_def(id).title, game.quest_deadline_text(id)], 14, Color("ffb27a") if urgent else Color("9fc4ff")))
		var l := UI.label("     " + game.quest_progress_text(id), 12, UI.HUD_SOFT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(360, 0)
		_objective_box.add_child(l)
	var offers: Array = game.quest_offers()
	if not offers.is_empty():
		var who := []
		for q in offers:
			who.append(str(q.who))
		var l := UI.label("!  Có người cần giúp: " + ", ".join(who) + " (tìm dấu ! trên phố)", 12, UI.GOLD)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(360, 0)
		_objective_box.add_child(l)


func _guide_description(target: Dictionary) -> String:
	var parts := [str(target.step)]
	var loc := str(target.get("location", ""))
	if world.LOCATIONS.has(loc): parts.append(str(world.location_info(loc).name))
	if not str(target.get("reason", "")).is_empty(): parts.append(str(target.reason))
	if not str(target.get("hint", "")).is_empty(): parts.append(str(target.hint))
	return " · ".join(parts)


func _refresh_guide_distance() -> void:
	if not is_instance_valid(_guide_button) or _guide_button.is_queued_for_deletion() or _guide_location == "": return
	if not world.LOCATIONS.has(_guide_location): return
	var preview: Dictionary = world.route_preview(_guide_location)
	var meters := roundi(float(preview.get("meters", 0.0)))
	_guide_button.text = "Tới " + str(world.location_info(_guide_location).name) + (" · %d m" % meters if meters > 3 else " · ngay gần đây")


func _objective(text: String, sub: String, state: String) -> void:
	_obj_n += 1
	var short: bool = not _obj_expanded
	if short and _obj_n > (2 if ScreenFit.compact else 3):
		_obj_hidden += 1
		return
	var color := UI.HUD_TEXT
	var mark := "◆"
	match state:
		"done":
			color = Color("8fd4a6")
			mark = "✓"
		"failed":
			color = Color("ff8a7a")
			mark = "✗"
		"current":
			color = UI.GOLD
	_objective_box.add_child(_outlined(UI.label("%s  %s" % [mark, text], 14, color)))
	# Gọn như Nobody: chỉ mục đang cần làm mới có dòng phụ; bấm mở hết bảng thì hiện đủ.
	if sub != "" and (not short or (state == "current" and _obj_n == 1)):
		var l := UI.label("     " + sub, 12, UI.HUD_SOFT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 380 if ScreenFit.compact else 420
		_objective_box.add_child(_outlined(l))


func _refresh_skills(s: Dictionary) -> void:
	var lines := [UI.ledger_bbcode(game), "", "[b]Thân thiết[/b]"]
	var reps := []
	for k in game.story.reps:
		if s.rep.has(k):
			reps.append("%s %d" % [game.rep_name(k), int(s.rep.get(k, 0))])
	lines.append(" · ".join(reps))
	var inv := []
	for k in s.get("inv", {}):
		if int(s.inv[k]) > 0:
			inv.append("%d %s" % [int(s.inv[k]), game.cfg.scrap[k].name])
	if not inv.is_empty():
		lines.append("")
		lines.append("[b]Đồng nát[/b]: %s (≈ %s)" % [", ".join(inv), GameLogic.fmt_k(game.scrap_value())])
	var carry := []
	for k in s.get("qitems", {}):
		carry.append(game.item_name(k))
	if not carry.is_empty():
		lines.append("[b]Đang mang[/b]: " + ", ".join(carry))
	var keep := []
	for k in game.keepsakes():
		keep.append(str(k.name))
	if not keep.is_empty():
		lines.append("")
		lines.append("[b]Đồ muốn mang theo[/b]: " + ", ".join(keep))
	# Sổ tay: vài dòng gần nhất, mới nhất ở trên.
	var diary: Array = s.get("diary", [])
	if not diary.is_empty():
		lines.append("")
		lines.append("[b]Sổ tay của An[/b]")
		for i in range(diary.size() - 1, maxi(-1, diary.size() - 7), -1):
			lines.append("[color=#6a3db8]Ngày %d[/color] · %s" % [int(diary[i].day), diary[i].text])
	_skills_text.text = "\n".join(lines)


func _refresh_location() -> void:
	# Đang làm thì An ở trong tiệm, giấu bảng cho tới khi xong việc.
	_location.visible = _loc_id != "" and not game.is_over() and not _working
	if not _location.visible:
		return
	var loc: Dictionary = world.location_info(_loc_id)
	_loc_title.text = loc.name
	var context := ""
	if world.real and world.city.street_upgrade and game.chapter() == 1:
		context = preload("res://scripts/world/street_context.gd").describe(_loc_id, game.clock(), bool(game.s.today.get("rain", false)))
	# Practical information must remain readable on touch screens too.
	_loc_desc.text = str(loc.desc) if context.is_empty() else "%s\n%s" % [loc.desc, context]
	for c in _loc_cards.get_children():
		c.queue_free()
	var found := 0
	if _loc_id == world.home:
		var n: Dictionary = game.night_preview()
		_loc_cards.add_child(UI.choice("Đi ngủ", "Kết thúc ngày %d · Mệt −%d qua đêm" % [game.day(), int(n.recover)],
			"" if game.s.queue.is_empty() else "Còn việc phải chọn", func() -> void:
				close_location()
				dialogs.open_night()))
	for id in game.scene_cards_at(_loc_id):
		var e: Dictionary = game.scene_info(id)
		var meta := "Cảnh chính hôm nay · %d phút" % roundi(float(e.get("hours", 0.5)) * 60.0)
		if e.has("window"):
			meta += " · %s–%s" % [GameLogic.hh(float(e.window[0])), GameLogic.hh(float(e.window[1]))]
		if game.scene_wait(id) > 0.0:
			meta += " · chờ tới %s mới bắt đầu" % GameLogic.hh(float(e.window[0]))
		_loc_cards.add_child(_quest_card("◆  " + game.fill(str(e.title)), meta + "\n" + str(e.get("who", "")),
			game.scene_lock(id), game.open_scene.bind(id)))
		found += 1
	# Remote neighborhoods are reached from a named stop with explicit cost/time.
	if world.has_method("travel_options"):
		for trip in world.travel_options(_loc_id):
			var destination := str(trip.destination)
			var meta := "%d phút · %s" % [int(trip.minutes), GameLogic.fmt_money(int(trip.cost))]
			_loc_cards.add_child(UI.choice("Đi xe tới " + str(trip.name), meta, str(trip.get("reason", "")),
				func() -> void: world.travel_to(destination)))
			found += 1
	for who in world.npcs_at(_loc_id):
		var npc := str(who.id)
		_loc_cards.add_child(UI.choice("Nói chuyện với " + str(who.name),
			"%d phút · Thân thiết %d/100" % [roundi(float(game.cfg.get("talkHours", 0.5)) * 60.0), int(game.s.rep.get(npc, 0))],
			game.talk_lock(npc), game.talk.bind(npc)))
	# Người quen của chỗ này đang đi việc riêng: ghi đi đâu, mấy giờ về.
	for note in world.life.notes_at(_loc_id):
		_loc_cards.add_child(UI.choice("%s %s" % [note.name, note.what], "", "Vắng · khoảng %s về" % GameLogic.hh(float(note.back)),
			func() -> void: pass))
	for q in game.quest_offers(_loc_id):
		_loc_cards.add_child(_quest_card("!  Việc nhờ: " + str(q.title), "%s đang cần người giúp. Bấm để nghe chuyện." % q.who, "", game.quest_offer.bind(q.id)))
		found += 1
	for id in game.quest_cards_at(_loc_id):
		var step: Dictionary = game.quest_step(id)
		var meta: String = game.quest_deadline_text(id)
		if float(step.get("hours", 0.0)) > 0.0:
			meta = "%d phút · %s" % [roundi(float(step.hours) * 60.0), meta]
		if game.quest_step_wait(id) > 0.0:
			meta += " · chờ tới %s" % GameLogic.hh(float(step.window[0]))
		_loc_cards.add_child(_quest_card("★  " + str(game.quest_def(id).title), game.quest_progress_text(id) + "\n" + meta,
			game.quest_step_lock(id), game.quest_visit.bind(id)))
		found += 1
	# Đơn sửa đồ (tiệm chú Sơn) và quầy linh kiện (chợ Long Biên): từng bước của đơn, bàn sửa 3D.
	if _loc_id in ["tiem_sau", "cho_cau_nho"] and world.real:
		_loc_cards.add_child(UI.wrap(game.Street.status(game), 12, UI.INK_SOFT, 320))
		var job: Dictionary = game.s.street.job
		if _loc_id == "tiem_sau" and not job.is_empty() and str(job.stage) == "repair":
			_loc_cards.add_child(UI.choice("Mở bàn sửa 3D", "Kéo linh kiện hỏng ra, lắp linh kiện mới, siết hai vít", "", _open_bench))
		for offer in game.Street.options(game, _loc_id):
			var hint := str(offer.hint)
			var meta := "%d phút" % roundi(float(offer.hours) * 60.0)
			if int(offer.cost) > 0:
				meta += " · −" + GameLogic.fmt_money(int(offer.cost))
			var oid := str(offer.id)
			_loc_cards.add_child(UI.choice(str(offer.name), meta + ("\n" + hint if hint != "" else ""), str(offer.reason),
				func() -> void: game.Street.act(game, _loc_id, oid)))
			found += 1
	for g in GameLogic.GROUPS:
		for a in game.visible_actions(g):
			if game.action_loc(a) == _loc_id:
				_loc_cards.add_child(UI.action_card(game, a, 320, _perform))
				found += 1
	if loc.get("scrap", false):
		var v: int = game.scrap_value()
		_loc_cards.add_child(UI.choice("Bán hết đồng nát", ("Được " + GameLogic.fmt_k(v)) if v > 0 else "", "Chưa nhặt được gì, lục thùng rác dọc phố (%s)" % ("chạm lời nhắc" if ScreenFit.touch else "phím E") if v <= 0 else "",
			func() -> void:
				var got: int = game.sell_scrap()
				if got > 0:
					world._float_text("+" + GameLogic.fmt_k(got), Color("7fe0a0"))))
	if found == 0 and _loc_id != world.home and not loc.get("scrap", false):
		_loc_cards.add_child(UI.wrap("Hôm nay ở đây chưa có việc gì cho An.", 13, UI.INK_SOFT, 320))
	_fit_location.call_deferred()


## Khung độc lập luôn nằm trong màn hình; tiêu đề và nút Rời đi cố định ngoài vùng cuộn.
func _fit_location() -> void:
	_location.offset_left = -minf(400.0, ScreenFit.view_size().x - 32.0) - 16.0
	_location.offset_right = -16.0
	_location.offset_top = 64.0
	_location.offset_bottom = -16.0


## Thẻ việc nhờ: nền vàng nhạt để nổi giữa các việc làm, dòng phụ xuống hàng được (bước việc nhờ thường dài).
func _quest_card(title: String, hint: String, lock: String, on_press: Callable) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(320, 92)
	btn.disabled = lock != ""
	btn.add_theme_stylebox_override("normal", UI.box(Color("332f22"), UI.GOLD, 8, 10))
	btn.add_theme_stylebox_override("hover", UI.box(Color("423b27"), UI.GOLD, 8, 10))
	btn.add_theme_stylebox_override("disabled", UI.box(UI.PAPER, Color("6b6250"), 8, 10))
	btn.pressed.connect(on_press)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	btn.add_child(v)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 12
	v.offset_top = 8
	v.offset_right = -12
	v.offset_bottom = -8
	v.add_child(UI.label(title, 15, Color("6b4a00")))
	v.add_child(UI.wrap(hint, 12, UI.INK_SOFT, 296))
	if lock != "" and lock != "-":
		v.add_child(UI.small(lock, UI.STAMP))
	return btn


# ---------------------------------------------------------------- gợi ý cách chơi

## Gợi ý hiện đúng lúc lần đầu gặp (đói, có cảnh chính, Mệt lên…), mỗi cái một lần, lưu trong s.tips_seen.
var _tip: PanelContainer
var _tip_label: Label
var _tip_id := ""
var _tip_time := 0.0
var _tip_cooldown := 0.0


func _build_tip(parent: Control) -> void:
	_tip = PanelContainer.new()
	_tip.add_theme_stylebox_override("panel", UI.box(UI.HUD_BG, UI.GOLD, 8, 12))
	_tip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_tip.custom_minimum_size = Vector2(360, 0)
	parent.add_child(_tip)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_tip.add_child(v)
	v.add_child(UI.label("GỢI Ý", 11, UI.GOLD))
	_tip_label = UI.wrap("", 14, UI.HUD_TEXT, 336)
	v.add_child(_tip_label)
	var ok := Button.new()
	ok.text = "Hiểu rồi"
	ok.size_flags_horizontal = Control.SIZE_SHRINK_END
	ok.pressed.connect(_close_tip)
	v.add_child(ok)
	_tip.visible = false


func _close_tip() -> void:
	# Cất ô trước rồi mới báo đổi trạng thái (vẽ lại HUD có thể gọi lại hàm này qua _make_room).
	var id := _tip_id
	_tip_id = ""
	_tip.visible = false
	if id != "" and game.is_started():
		# Leave room for the street and the conversation just opened. Tutorials
		# should not form a queue of new cards after every acknowledgement.
		_tip_cooldown = 14.0
		if not game.s.has("tips_seen"):
			game.s["tips_seen"] = []
		game.s.tips_seen.append(id)
		game.changed.emit()


func _tip_due(id: String) -> bool:
	var s: Dictionary = game.s
	match id:
		"di_lai":
			return true
		"canh_chinh":
			return not game.scenes_today().is_empty()
		"tien":
			return int(s.stats.get("earned", 0)) > 0
		"an_uong":
			return game.has_needs() and game.need("fed") < 45.0
		"tam_giat":
			return game.has_needs() and (game.need("clean") < 45.0 or game.need("neat") < 45.0)
		"phong_do":
			return game.pay_mult() < 1.0
		"so":
			for p in s.promises:
				if p.status == "open":
					return true
		"noi_chuyen":
			if _loc_id != "":
				return not world.npcs_at(_loc_id).is_empty()
		"met":
			return float(s.fatigue) >= 55.0
		"viec_nho":
			return not game.quest_offers().is_empty()
		"ve_chai":
			return _prompt_id.begins_with("bin:")
		"mua":
			return bool(s.today.get("rain", false))
		"dien_thoai":
			return game.day() >= 2
		"toi":
			return game.clock() >= 19.5
		"cho_o":
			return game.day() >= 3
	return false


func _update_tip(dt: float) -> void:
	if game.is_over():
		_tip.visible = false
	if not game.is_started() or game.is_over() or dialogs.visible:
		return
	if _tip_cooldown > 0.0:
		_tip_cooldown = maxf(0.0, _tip_cooldown - dt)
		return
	if _tip.visible:
		# Tự tắt sau một lúc nếu người chơi không bấm, coi như đã đọc.
		_tip_time += dt
		if _tip_time > 40.0:
			_close_tip()
		return
	# Màn thấp: có bảng mở (hay bảng mục tiêu đang mở hết) thì chờ, khỏi đè ô gợi ý lên bảng.
	if _panel_open() or (ScreenFit.compact and _obj_expanded):
		return
	var seen: Array = game.s.get("tips_seen", [])
	for tip in game.story.get("tips", []):
		if not seen.has(tip.id) and _tip_due(str(tip.id)):
			_tip_id = str(tip.id)
			# Máy cảm ứng: lời gợi ý nói chạm, chụm ngón thay cho chuột, phím.
			_tip_label.text = str(tip.get("textTouch", tip.text)) if ScreenFit.touch else str(tip.text)
			_tip_time = 0.0
			_tip.visible = true
			return
