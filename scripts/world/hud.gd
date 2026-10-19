extends CanvasLayer
## Giao diện đè lên màn phố: bảng mục tiêu góc trái (giống Nobody), tiền và Mệt góc phải,
## bảng địa điểm khi bước vào một nơi, thanh "đang làm", thanh công cụ dưới cùng và các hộp thoại.
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
var _cash_label: Label
var _recv_label: Label
var _fatigue_label: Label
var _fatigue_bar: ProgressBar
var _prompt: PanelContainer
var _prompt_label: Label
var _work: PanelContainer
var _work_title: Label
var _work_clock: Label
var _work_bar: ProgressBar
var _location: PanelContainer
var _loc_title: Label
var _loc_desc: Label
var _loc_cards: VBoxContainer
var _ledger: PanelContainer
var _ledger_text: RichTextLabel
var _log: PanelContainer
var _log_text: RichTextLabel
var _bottom: PanelContainer
var _home_btn: Button
var _working := false
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

	# Hàng trên: mục tiêu bên trái, tiền và Mệt bên phải.
	var top := _pass(HBoxContainer.new(), rows)
	_build_objectives(top)
	_spacer(top)
	_build_status(top)

	# Hàng giữa: sổ / nhật ký bên trái, bảng địa điểm bên phải.
	var middle := _pass(HBoxContainer.new(), rows)
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := _pass(VBoxContainer.new(), middle)
	_ledger = _text_panel(left, "SỔ: PHẢI THU · PHẢI TRẢ · LỜI HỨA · GIA ĐÌNH")
	_ledger_text = _ledger.get_child(0).get_child(1) as RichTextLabel
	_log = _text_panel(left, "NHẬT KÝ")
	_log_text = _log.get_child(0).get_child(1) as RichTextLabel
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
			_ledger.visible = false


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


## Bảng chữ có tiêu đề: con thứ nhất của VBox là tiêu đề, con thứ hai là RichTextLabel.
func _text_panel(parent: Control, title: String) -> PanelContainer:
	var p := _light_panel(parent)
	var v := VBoxContainer.new()
	p.add_child(v)
	v.add_child(UI.label(title, 11, UI.INK_SOFT))
	var t := RichTextLabel.new()
	t.bbcode_enabled = true
	t.custom_minimum_size = Vector2(400, 300)
	t.add_theme_font_size_override("normal_font_size", 13)
	t.add_theme_font_size_override("bold_font_size", 14)
	v.add_child(t)
	p.visible = false
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
	_status.custom_minimum_size = Vector2(290, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_status.add_child(v)
	_day_label = UI.label("", 22, UI.HUD_TEXT)
	v.add_child(_day_label)
	_clock_label = UI.label("", 14, UI.HUD_SOFT)
	v.add_child(_clock_label)
	_cash_label = UI.label("", 26, UI.GOLD)
	v.add_child(_cash_label)
	_recv_label = UI.label("", 12, UI.HUD_SOFT)
	v.add_child(_recv_label)
	_fatigue_label = UI.label("", 12, UI.HUD_SOFT)
	v.add_child(_fatigue_label)
	_fatigue_bar = UI.bar(8)
	v.add_child(_fatigue_bar)


func _build_prompt(parent: Control) -> void:
	_prompt = _dark_panel(parent)
	_prompt_label = UI.label("", 16, UI.HUD_TEXT)
	_prompt.add_child(_prompt_label)
	_prompt.visible = false


func _build_work(parent: Control) -> void:
	_work = _dark_panel(parent)
	_work.custom_minimum_size = Vector2(440, 0)
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
	scroll.custom_minimum_size = Vector2(340, 230)
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


func _build_bottom(parent: Control) -> void:
	_bottom = _dark_panel(parent)
	_bottom.size_flags_vertical = Control.SIZE_SHRINK_END
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	_bottom.add_child(h)
	h.add_child(_tool_button("Sổ", func() -> void:
		_ledger.visible = not _ledger.visible
		_log.visible = false))
	h.add_child(_tool_button("Nhật ký", func() -> void:
		_log.visible = not _log.visible
		_ledger.visible = false))
	h.add_child(_tool_button("Bảng cân bằng", func() -> void: get_tree().change_scene_to_file("res://scenes/board.tscn")))
	_home_btn = _tool_button("Về xóm trọ", func() -> void:
		close_location()
		world.walk_to_location(world.home))
	_home_btn.add_theme_stylebox_override("normal", UI.box(UI.GOLD, UI.GOLD, 8, 10))
	_home_btn.add_theme_stylebox_override("hover", UI.box(UI.GOLD.lightened(0.15), UI.GOLD, 8, 10))
	h.add_child(_home_btn)


func _tool_button(text: String, on_press: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(on_press)
	return b


# ---------------------------------------------------------------- làm việc

## Làm một việc: An vào trong, thanh thời gian chạy, đồng hồ nhảy dần, xong mới tính kết quả.
func _perform(id: String) -> void:
	var a: Dictionary = game.get_action(id)
	var st: Dictionary = game.action_status(a)
	if not st.ok or _working:
		return
	_working = true
	world.set_player_inside(true)
	_work_title.text = str(a.name)
	_work_bar.value = 0.0
	_work.visible = true
	_refresh()
	var start: float = st.start
	var finish: float = start + float(a.hours)
	var seconds := maxf(0.8, float(a.hours) * float(game.cfg.get("workSecondsPerHour", 0.35)))
	var step := func(t: float) -> void:
		var now := lerpf(start, finish, t)
		_work_bar.value = t
		_work_clock.text = GameLogic.hh(now)
		_clock_label.text = "%s  ·  đang bận" % GameLogic.hh(now)
	var done := func() -> void:
		_working = false
		_work.visible = false
		world.set_player_inside(false)
		game.do_action(id)
	var tw := create_tween()
	tw.tween_method(step, 0.0, 1.0, seconds)
	tw.tween_callback(done)


func _go_to_sleep() -> void:
	close_location()
	dialogs.open_night()


# ---------------------------------------------------------------- vẽ lại

func _refresh() -> void:
	var started: bool = game.is_started()
	for p in [_objectives, _status, _bottom]:
		p.visible = started
	_ledger_text.text = UI.ledger_bbcode(game)
	_log_text.text = UI.log_bbcode(game)
	if not started:
		_loc_id = ""
		_location.visible = false
		_update_prompt()
		return
	var s: Dictionary = game.s
	_refresh_objectives(s)
	_day_label.text = "Ngày %d/30 · %s" % [game.day(), game.weekday_name()]
	if not _working:
		_clock_label.text = "%s  ·  còn %s giờ trong ngày" % [GameLogic.hh(minf(game.clock(), 22.0)), GameLogic.num(game.hours_left())]
	_cash_label.text = GameLogic.fmt_money(int(s.cash))
	_recv_label.text = "Phải thu: %s trước ngày 30 · %s sau ngày 30\nPhải trả: %s" % [
		GameLogic.fmt_money(game.receivable_sum(0, 30)), GameLogic.fmt_money(game.receivable_sum(31, 999)), GameLogic.fmt_money(game.payable_sum(999))]
	var warn := float(game.cfg.fatigue.warn)
	_fatigue_label.text = "Mệt %d/100%s" % [int(s.fatigue), "  · cần nghỉ" if game.fatigue_warn() else ""]
	UI.set_bar(_fatigue_bar, float(s.fatigue), 100.0, UI.STAMP if float(s.fatigue) >= warn else (UI.WARN if float(s.fatigue) >= warn - 20 else UI.GOOD))
	_home_btn.disabled = game.is_over() or not s.queue.is_empty()
	_refresh_location()
	_update_prompt()


func _update_prompt() -> void:
	_prompt.visible = game.is_started() and _prompt_id != "" and _prompt_id != "-" and _loc_id == "" and not blocking()


func _objective(text: String, sub: String, state: String) -> void:
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
	_objective_box.add_child(UI.label("%s  %s" % [mark, text], 14, color))
	if sub != "":
		_objective_box.add_child(UI.label("     " + sub, 12, UI.HUD_SOFT))


func _refresh_objectives(s: Dictionary) -> void:
	for c in _objective_box.get_children():
		c.queue_free()
	var deadline := int(game.cfg.housingDeadline)
	var proj: int = game.projected_cash(deadline)
	var best: String = game.best_housing(proj)
	var best_name := "chưa đủ cả chỗ ở tạm" if best == "" else str(game.cfg.housing[best].name)
	_objective("Chốt chỗ ở trước ngày %d" % deadline, "Dự kiến sáng ngày %d: %s · đủ cho %s" % [deadline, GameLogic.fmt_money(proj), best_name], "current")
	if s.route != "A":
		var mid = null
		for r in s.receivables:
			if r.id == "hd_giua":
				mid = r
		var state := "normal"
		if mid != null and mid.status == "collected":
			state = "done"
		elif game.day() > 20:
			state = "failed"
		elif game.day() <= 20:
			state = "current"
		_objective("Nghiệm thu đợt giữa Bến Cạn tối ngày 20", "Tiến độ %d/%d buổi" % [int(s.progress), int(s.progress_need)], state)
	var linh_state := "done" if s.linh.decision != "" else ("current" if game.day() >= 19 else "normal")
	_objective("Nghe Linh nói về chỗ thực tập (ngày 22)", "Quyết định là của Linh", linh_state)
	var due_today := 0
	for p in s.promises:
		if p.status == "open" and int(p.due) == game.day():
			due_today += 1
	if due_today > 0:
		_objective("Lời hứa đến hạn hôm nay: %d" % due_today, "Mở Sổ để xem", "current")
	_objective("Trả chìa khóa phòng cũ cho cô Duyên ngày 30", "", "normal")


func _refresh_location() -> void:
	_location.visible = _loc_id != "" and not game.is_over() and not _working
	if not _location.visible:
		return
	var loc: Dictionary = world.location_info(_loc_id)
	_loc_title.text = loc.name
	_loc_desc.text = loc.desc
	for c in _loc_cards.get_children():
		c.queue_free()
	if _loc_id == world.home:
		var n: Dictionary = game.night_preview()
		var hint := "Kết thúc ngày %d · Mệt −%d qua đêm" % [game.day(), int(n.recover)]
		_loc_cards.add_child(UI.choice("Đi ngủ", hint, "" if game.s.queue.is_empty() else "Còn việc phải chọn", _go_to_sleep))
	var found := 0
	for a in game.actions_at(_loc_id):
		_loc_cards.add_child(UI.action_card(game, a, 320, _perform))
		found += 1
	if found == 0 and _loc_id != world.home:
		_loc_cards.add_child(UI.wrap("Hôm nay ở đây chưa có việc gì cho An.", 13, UI.INK_SOFT, 320))
