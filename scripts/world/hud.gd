extends CanvasLayer
## Giao diện đè lên màn phố: bảng mục tiêu góc trái (giống Nobody), trạng thái góc phải,
## bảng địa điểm khi bước vào một cửa tiệm, thanh công cụ dưới cùng và các hộp thoại.
## Bố cục dùng container lồng nhau; mọi container trong suốt với chuột để bấm xuyên xuống cảnh 3D.

const GameLogic := preload("res://scripts/game_logic.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")
const DialogLayer := preload("res://scripts/ui/dialog_layer.gd")

var world
var game
var dialogs: DialogLayer

var _objectives: PanelContainer
var _objective_box: VBoxContainer
var _status: PanelContainer
var _day_label: Label
var _clock_label: Label
var _money_label: Label
var _health_bar: ProgressBar
var _health_label: Label
var _mood_bar: ProgressBar
var _mood_label: Label
var _prompt: PanelContainer
var _prompt_label: Label
var _location: PanelContainer
var _loc_title: Label
var _loc_desc: Label
var _loc_cards: VBoxContainer
var _skills: PanelContainer
var _skills_box: VBoxContainer
var _log: PanelContainer
var _log_text: RichTextLabel
var _bottom: PanelContainer
var _food_select: OptionButton
var _end_day_btn: Button
var _work: PanelContainer
var _work_title: Label
var _work_clock: Label
var _work_bar: ProgressBar
var _working := false
var _food_keys: Array = []
var _loc_id := ""
var _prompt_id := "-"


func _ready() -> void:
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UI.make_theme()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin := _pass(MarginContainer.new(), root)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	var rows := _pass(VBoxContainer.new(), margin)
	rows.add_theme_constant_override("separation", 12)

	# Hàng trên: mục tiêu bên trái, trạng thái bên phải.
	var top := _pass(HBoxContainer.new(), rows)
	_build_objectives(top)
	_spacer(top)
	_build_status(top)

	# Hàng giữa: kỹ năng / nhật ký bên trái, bảng địa điểm bên phải.
	var middle := _pass(HBoxContainer.new(), rows)
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := _pass(VBoxContainer.new(), middle)
	_build_skills(left)
	_build_log(left)
	_spacer(middle)
	_build_location(middle)

	# Lời nhắc tương tác và thanh "đang làm" ở giữa, phía trên thanh công cụ.
	var prompt_row := _pass(HBoxContainer.new(), rows)
	prompt_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_build_prompt(prompt_row)
	_build_work(prompt_row)

	# Hàng dưới: hướng dẫn điều khiển bên trái, thanh công cụ bên phải.
	var bottom := _pass(HBoxContainer.new(), rows)
	var hint := UI.label("Chuột trái: đi tới chỗ bấm · Bấm cửa tiệm hoặc người: tương tác · WASD: đi · E: vào · Esc: đóng", 12, UI.HUD_TEXT)
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	hint.add_theme_constant_override("outline_size", 5)
	hint.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.add_child(hint)
	_spacer(bottom)
	_build_bottom(bottom)

	dialogs = DialogLayer.new()
	dialogs.game = game
	root.add_child(dialogs)
	dialogs.closed.connect(_refresh)
	game.changed.connect(_refresh)
	_refresh()


# ---------------------------------------------------------------- API cho world.gd

func blocking() -> bool:
	return dialogs.visible or _working


func location_open() -> String:
	return _loc_id


func open_location(id: String) -> void:
	if not game.is_started() or blocking():
		return
	_loc_id = id
	_refresh()


func close_location() -> void:
	if _loc_id == "":
		return
	_loc_id = ""
	_refresh()


func set_prompt(id: String) -> void:
	if id == _prompt_id:
		return
	_prompt_id = id
	if id != "":
		_prompt_label.text = "E  ·  Vào " + str(world.location_info(id).name)
	_update_prompt()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _loc_id != "":
			close_location()
		else:
			_log.visible = false
			_skills.visible = false


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
	p.add_theme_stylebox_override("panel", UI.box(Color(0.96, 0.96, 0.98, 0.97), UI.LINE, 10, 16))
	p.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	parent.add_child(p)
	return p


func _build_objectives(parent: Control) -> void:
	_objectives = _dark_panel(parent)
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
	head.add_child(UI.label("Mục tiêu quan trọng", 18, UI.GOLD))
	_objective_box = VBoxContainer.new()
	_objective_box.add_theme_constant_override("separation", 2)
	v.add_child(_objective_box)


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
	_money_label = UI.label("", 26, UI.GOLD)
	v.add_child(_money_label)
	_health_label = UI.label("", 12, UI.HUD_SOFT)
	v.add_child(_health_label)
	_health_bar = UI.bar(8)
	v.add_child(_health_bar)
	_mood_label = UI.label("", 12, UI.HUD_SOFT)
	v.add_child(_mood_label)
	_mood_bar = UI.bar(8)
	v.add_child(_mood_bar)


func _build_prompt(parent: Control) -> void:
	_prompt = _dark_panel(parent)
	_prompt_label = UI.label("", 16, UI.HUD_TEXT)
	_prompt.add_child(_prompt_label)
	_prompt.visible = false


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
	v.add_child(_work_bar)
	_work.visible = false


## Làm một việc ở tiệm: Minh vào trong, thanh thời gian chạy, đồng hồ nhảy dần, xong mới tính kết quả.
func _perform(id: String) -> void:
	var a: Dictionary = game.get_action(id)
	var st: Dictionary = game.action_status(a)
	if not st.ok or _working:
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
		_clock_label.text = "%s  ·  đang bận" % GameLogic.hh(now), 0.0, 1.0, seconds)
	tw.tween_callback(func() -> void:
		_working = false
		_work.visible = false
		world.set_player_inside(false)
		game.do_action(id))
	_work_bar.max_value = 1.0
	_work_bar.add_theme_stylebox_override("fill", UI.box(UI.GOLD, UI.GOLD, 5, 0))


func _build_location(parent: Control) -> void:
	_location = _light_panel(parent)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_location.add_child(v)
	_loc_title = UI.label("", 22, UI.INK)
	v.add_child(_loc_title)
	_loc_desc = UI.label("", 13, UI.INK_SOFT)
	_loc_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_loc_desc.custom_minimum_size = Vector2(320, 0)
	v.add_child(_loc_desc)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(336, 340)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_loc_cards = VBoxContainer.new()
	_loc_cards.add_theme_constant_override("separation", 8)
	scroll.add_child(_loc_cards)
	var leave := Button.new()
	leave.text = "Rời đi"
	leave.pressed.connect(close_location)
	v.add_child(leave)
	_location.visible = false


func _build_skills(parent: Control) -> void:
	_skills = _dark_panel(parent)
	_skills.custom_minimum_size = Vector2(330, 0)
	_skills_box = VBoxContainer.new()
	_skills_box.add_theme_constant_override("separation", 6)
	_skills.add_child(_skills_box)
	_skills.visible = false


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
	var food_label := UI.label("Ăn uống", 13, UI.HUD_SOFT)
	food_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(food_label)
	_food_select = OptionButton.new()
	for k in game.cfg.food:
		var f: Dictionary = game.cfg.food[k]
		_food_keys.append(k)
		_food_select.add_item("%s · %s" % [f.name, GameLogic.fmt_k(int(f.cost))])
	_food_select.item_selected.connect(func(i: int) -> void: game.set_food(_food_keys[i]))
	h.add_child(_food_select)
	h.add_child(_tool_button("Kỹ năng", func() -> void:
		_skills.visible = not _skills.visible
		_log.visible = false))
	h.add_child(_tool_button("Nhật ký", func() -> void:
		_log.visible = not _log.visible
		_skills.visible = false))
	h.add_child(_tool_button("Bảng cân bằng", func() -> void: get_tree().change_scene_to_file("res://scenes/board.tscn")))
	_end_day_btn = _tool_button("Về phòng trọ", func() -> void:
		close_location()
		world.walk_to_location("phong_tro"))
	_end_day_btn.add_theme_stylebox_override("normal", UI.box(UI.GOLD, UI.GOLD, 8, 10))
	_end_day_btn.add_theme_stylebox_override("hover", UI.box(UI.GOLD.lightened(0.15), UI.GOLD, 8, 10))
	h.add_child(_end_day_btn)


func _tool_button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(on_press)
	return b


# ---------------------------------------------------------------- vẽ lại

func _refresh() -> void:
	var started: bool = game.is_started()
	for p in [_objectives, _status, _bottom]:
		p.visible = started
	if not started:
		_loc_id = ""
		_location.visible = false
		_update_prompt()
		return
	var s: Dictionary = game.s
	_refresh_objectives(s)
	_day_label.text = "Ngày %d/30 · %s" % [game.day(), game.weekday_name()]
	_clock_label.text = "%s  ·  còn %s giờ trong ngày" % [GameLogic.hh(minf(game.clock(), 22.0)), GameLogic.num(game.hours_left())]
	_money_label.text = GameLogic.fmt_money(int(s.money))
	_health_label.text = "Sức khỏe %d/%d" % [int(s.health), int(s.health_max)]
	UI.set_bar(_health_bar, float(s.health), float(s.health_max), UI.level_color(float(s.health) / float(s.health_max)))
	_mood_label.text = "Tinh thần %d/%d" % [int(s.mood), int(s.mood_max)]
	UI.set_bar(_mood_bar, float(s.mood), float(s.mood_max), UI.level_color(float(s.mood) / float(s.mood_max)))
	_food_select.select(_food_keys.find(s.food))
	_food_select.disabled = float(s.used) > 0.0 or not s.queue.is_empty()
	_end_day_btn.disabled = game.is_over() or not s.queue.is_empty()
	_refresh_skills(s)
	_log_text.text = UI.log_bbcode(game)
	_refresh_location()
	_update_prompt()


func _update_prompt() -> void:
	_prompt.visible = game.is_started() and _prompt_id != "" and _prompt_id != "-" and _loc_id == "" and not blocking()


func _refresh_objectives(s: Dictionary) -> void:
	for c in _objective_box.get_children():
		c.queue_free()
	var ms: Dictionary = game.cfg.milestones
	var rows := [
		{"day": 10, "text": "Trả lãi %s cho Khoa trước tối ngày 10" % GameLogic.fmt_money(int(ms.day10)),
			"done": int(s.interest_paid) > 0, "failed": game.day() > 10 and int(s.interest_paid) == 0},
		{"day": 20, "text": "Đóng học phí %s cho Lan trước tối ngày 20" % GameLogic.fmt_money(int(ms.day20)),
			"done": s.flags.get("lanNhapHoc", false), "failed": s.flags.get("lanBaoLuu", false)},
		{"day": 30, "text": "Trả nợ Hưng Sẹo %s trước tối ngày 30" % GameLogic.fmt_money(int(s.debt)),
			"done": false, "failed": false},
	]
	var current: Dictionary = game.next_milestone()
	for r in rows:
		var color := UI.HUD_TEXT
		var mark := "◆"
		if r.done:
			color = Color("8fd4a6")
			mark = "✓"
		elif r.failed:
			color = Color("ff8a7a")
			mark = "✗"
		elif int(r.day) == int(current.day):
			color = UI.GOLD
		_objective_box.add_child(UI.label("%s  %s" % [mark, r.text], 14, color))
		if int(r.day) == int(current.day) and not r.done:
			var lack := maxi(0, int(current.amount) - int(s.money))
			var days_left: int = int(current.day) - game.day()
			var when := "hạn là tối nay" if days_left == 0 else "còn %d ngày" % days_left
			var sub := "Đã đủ tiền" if lack == 0 else "Còn thiếu %s · %s" % [GameLogic.fmt_money(lack), when]
			_objective_box.add_child(UI.label("     " + sub, 12, UI.HUD_SOFT))


func _refresh_skills(s: Dictionary) -> void:
	for c in _skills_box.get_children():
		c.queue_free()
	_skills_box.add_child(UI.label("KỸ NĂNG", 11, UI.HUD_SOFT))
	var per := float(game.cfg.xpPerLevel)
	var max_lv := int(game.cfg.maxLevel)
	for k in GameLogic.SKILLS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var n := UI.label(GameLogic.SKILLS[k], 13, UI.HUD_TEXT)
		n.custom_minimum_size = Vector2(80, 0)
		row.add_child(n)
		var b := UI.bar(8)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		UI.set_bar(b, float(s.xp[k]), per * max_lv, Color("a98bea"))
		row.add_child(b)
		row.add_child(UI.label("%d/%d" % [game.level(k), max_lv], 12, UI.HUD_SOFT))
		_skills_box.add_child(row)
	_skills_box.add_child(UI.label("ĐỘ THÂN THIẾT", 11, UI.HUD_SOFT))
	var reps := []
	for k in GameLogic.REPS:
		reps.append("%s %d" % [GameLogic.REPS[k], int(s.rep[k])])
	var rep_label := UI.label("  ·  ".join(reps), 13, UI.HUD_TEXT)
	rep_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rep_label.custom_minimum_size = Vector2(300, 0)
	_skills_box.add_child(rep_label)
	var room_name := "Chưa thuê"
	if s.room != "":
		room_name = game.cfg.rooms[s.room].name
	var lines := [
		"Phòng trọ: " + room_name,
		"Bằng chứng: %d · Chuyến chạy hàng: %d/%d" % [int(s.evidence), int(s.smuggle), int(game.cfg.smuggle.tripsForBadEnding)],
		"Tạm trú: " + ("Đã đăng ký" if s.flags.get("tamTru", false) else "Chưa"),
	]
	if int(s.held) > 0:
		lines.append("Lương đang bị giữ: " + GameLogic.fmt_money(int(s.held)))
	_skills_box.add_child(UI.label("\n".join(lines), 12, UI.HUD_SOFT))


func _refresh_location() -> void:
	_location.visible = _loc_id != "" and not game.is_over()
	if not _location.visible:
		return
	var loc: Dictionary = world.location_info(_loc_id)
	_loc_title.text = loc.name
	_loc_desc.text = loc.desc
	for c in _loc_cards.get_children():
		c.queue_free()
	var found := 0
	for g in GameLogic.GROUPS:
		for a in game.visible_actions(g):
			if a.get("location", "") == _loc_id:
				_loc_cards.add_child(UI.action_card(game, a, 320))
				found += 1
	if found == 0:
		_loc_cards.add_child(UI.wrap("Hôm nay ở đây chưa có việc gì cho Minh.", 13, UI.INK_SOFT, 320))
