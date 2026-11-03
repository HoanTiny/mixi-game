extends Control
## Lớp hộp thoại: mở đầu, buổi tối, tổng kết lát cắt ở khung giữa màn hình; cảnh truyện, hội thoại và màn kết chương
## chạy thành phụ đề ở cuối màn hình (từng câu, có tên người nói, chạm để sang câu sau), hết lời mới hiện lựa chọn.
## Màn kết chỉ đọc vài câu chính; thẻ hậu truyện, sổ tay mở ở nút "Xem thêm".
## Tự hiện khi trạng thái game cần người chơi chọn, tự ẩn khi không.

const GameLogic := preload("res://scripts/game_logic.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")
const Sub := preload("res://scripts/ui/subtitle_text.gd")
## Tốc độ chữ chạy (ký tự mỗi giây).
const TYPE_SPEED := 55.0

signal closed

var game
var night_open := false
## Màn tiêu đề đang mở: giấu hết bảng thoại cho tới khi vào game.
var hold := false
var _box: VBoxContainer
var _diary_open := false
var _scrim: ColorRect
var _panel_root: ScrollContainer
# Phụ đề: khóa của cảnh đang chạy, các dòng {who, text, big}, dòng đang hiện, số chữ đã hiện, hàm dựng lựa chọn.
var _sub_root: Control
var _sub_head: Label
var _sub_who: Label
var _sub_line: Label
var _sub_hint: Label
var _sub_skip: Button
var _sub_choices: VBoxContainer
var _sub_key := ""
var _sub_lines: Array = []
var _sub_i := 0
var _sub_chars := -1.0
var _sub_build := Callable()
## Nút lấy ra từ _box chờ hiện thành lựa chọn khi hết lời.
var _sub_pending: Array = []
## Màn kết: đã đọc xong phần phụ đề và bấm xem thẻ hậu truyện, sổ tay.
var _ending_full := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim = ColorRect.new()
	_scrim.color = Color(0.05, 0.06, 0.12, 0.6)
	add_child(_scrim)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scroll := ScrollContainer.new()
	_panel_root = scroll
	add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	panel.add_theme_stylebox_override("panel", UI.box(UI.CARD, UI.LINE, 12, 26))
	center.add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	panel.add_child(_box)
	_build_subtitles()
	game.changed.connect(refresh)
	refresh()


func open_night() -> void:
	night_open = true
	refresh()


func refresh() -> void:
	if hold:
		visible = false
		return
	for child in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	var show := true
	var sub := true
	# Màn dựng bằng nhãn và nút (mở đầu, buổi tối, tổng kết, phần "xem thêm" của màn kết) cũng chạy thành phụ đề:
	# dựng như cũ vào _box rồi đổi sang các dòng phụ đề (_box_to_sub).
	var builder := Callable()
	var key := ""
	if not game.is_over():
		_ending_full = false
	if not game.is_started():
		builder = _start
		key = "start"
	elif game.is_over():
		var kind := str(game.s.over.get("kind", ""))
		key = "over|%s|%s|%s" % [kind, str(game.s.over.get("key", "")), str(_diary_open)]
		if kind.begins_with("full") and not _ending_full:
			_sub_ending()
		else:
			match kind:
				"full":
					builder = _ending
				"full2":
					builder = _ending2
				"full3":
					builder = _ending3
				"full4":
					builder = _ending4
				"full5":
					builder = _ending5
				_:
					builder = _report
	elif not game.s.queue.is_empty():
		_sub_event()
	elif night_open:
		builder = _night
		key = "night|%d" % game.day()
	else:
		show = false
		sub = false
	if builder.is_valid() and key != _sub_key:
		builder.call()
		_box_to_sub(key)
	if not sub:
		_sub_key = ""
	_panel_root.visible = false
	_sub_root.visible = sub
	_scrim.color.a = 0.18
	if visible and not show:
		closed.emit()
	visible = show


# ---------------------------------------------------------------- phụ đề

## Đổi các nhãn, nút vừa dựng trong _box thành phụ đề: nhãn mục nhỏ (chữ in) là tên người nói của các dòng sau, tiêu
## đề lớn là dòng to, câu thoại màu tím cắt theo người nói, chữ còn lại là lời kể; nút thành lựa chọn sau khi hết lời.
func _box_to_sub(key: String) -> void:
	for b in _sub_pending:
		if is_instance_valid(b) and b.get_parent() == null:
			b.queue_free()
	_sub_pending = []
	var lines := []
	var head := ""
	var who := ""
	var kids := _box.get_children()
	for idx in kids.size():
		var c = kids[idx]
		# Nhãn đứng ngay trên nút (tên nhóm nút, "Chế độ riêng:") thì bỏ, nút đã tự nói.
		var before_button: bool = idx + 1 < kids.size() and kids[idx + 1] is Button
		if c is Button:
			_box.remove_child(c)
			_sub_pending.append(c)
			continue
		if not (c is Label):
			continue
		var text := str(c.text).strip_edges()
		if text == "":
			continue
		var size: int = c.get_theme_font_size("font_size")
		var color: Color = c.get_theme_color("font_color")
		if before_button and c is Label and (text.ends_with(":") or (size <= 12 and text == text.to_upper())):
			continue
		if size <= 12 and text == text.to_upper():
			if lines.is_empty() and head == "":
				head = text
			else:
				who = _title_case(text)
		elif size >= 24:
			lines.append({"who": "", "text": text, "big": true})
		elif size == 14 and color == UI.TIM and c.autowrap_mode == TextServer.AUTOWRAP_OFF:
			who = text
		elif size >= 17 and color == UI.TIM:
			lines.append_array(Sub.quote(text))
		else:
			for l in Sub.narration(text, who):
				# Dòng "Chị Hạnh · ..." ở phần người ở phố: tên đó là người nói của dòng.
				for nm in game.story.reps.values():
					if str(l.text).begins_with(str(nm) + " · "):
						l["who"] = str(nm)
						l["text"] = str(l.text).substr(str(nm).length() + 3)
						break
				lines.append(l)
	var buttons := _sub_pending
	_sub_start(key, head, lines, func() -> void:
		for b in buttons:
			if is_instance_valid(b):
				_sub_choices.add_child(b))


## "SỔ TAY CỦA AN" thành "Sổ Tay Của An" (giữ nguyên chữ số, khác String.capitalize chèn khoảng trắng trước số).
static func _title_case(s: String) -> String:
	var words := []
	for wd in s.to_lower().split(" ", false):
		words.append(wd.substr(0, 1).to_upper() + wd.substr(1))
	return " ".join(words)


func _build_subtitles() -> void:
	_sub_root = Control.new()
	add_child(_sub_root)
	_sub_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sub_root.gui_input.connect(_on_sub_input)
	var margin := MarginContainer.new()
	_sub_root.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	# Chừa chỗ cho thanh nút ở đáy màn phố.
	margin.add_theme_constant_override("margin_bottom", 96)
	margin.add_theme_constant_override("margin_top", 20)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_END
	col.add_theme_constant_override("separation", 12)
	margin.add_child(col)
	_sub_choices = VBoxContainer.new()
	_sub_choices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub_choices.custom_minimum_size = Vector2(560, 0)
	_sub_choices.size_flags_horizontal = Control.SIZE_SHRINK_END
	_sub_choices.add_theme_constant_override("separation", 8)
	col.add_child(_sub_choices)
	var bar := PanelContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("panel", UI.box(Color(0.06, 0.07, 0.12, 0.9), Color(1, 1, 1, 0.14), 14, 20))
	col.add_child(bar)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 6)
	bar.add_child(v)
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	_sub_head = UI.label("", 12, UI.HUD_SOFT)
	_sub_head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sub_head.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(_sub_head)
	_sub_skip = Button.new()
	_sub_skip.text = "Bỏ qua  ▸▸"
	_sub_skip.flat = true
	_sub_skip.add_theme_color_override("font_color", UI.HUD_SOFT)
	_sub_skip.add_theme_font_size_override("font_size", 13)
	_sub_skip.pressed.connect(_sub_skip_all)
	top.add_child(_sub_skip)
	_sub_who = UI.label("", 18, UI.GOLD)
	v.add_child(_sub_who)
	_sub_line = UI.label("", 21, UI.HUD_TEXT)
	_sub_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sub_line.custom_minimum_size = Vector2(200, 58)
	v.add_child(_sub_line)
	_sub_hint = UI.label("Chạm hay nhấn Space để tiếp  ▸", 12, UI.HUD_SOFT)
	_sub_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_sub_hint)


## Cảnh truyện, đoạn hội thoại, tin nhắn: lời kể rồi lời thoại, hết thì hiện lựa chọn.
func _sub_event() -> void:
	var e: Dictionary = game.current_event()
	if e.is_empty():
		return
	var key := "%s|%d|%d" % [str(game.s.queue[0].id), game.s.queue.size(), game.day()]
	if key == _sub_key:
		return
	var lines := Sub.narration(game.fill(str(e.get("text", ""))))
	lines.append_array(Sub.quote(game.fill(str(e.get("quote", "")))))
	var head: String = "%s  ·  %s" % [str(e.eyebrow), game.fill(str(e.title))] if str(e.get("eyebrow", "")) != "" else game.fill(str(e.title))
	var choices: Array = e.choices
	_sub_start(key, head, lines, func() -> void:
		var i := 0
		for c in choices:
			_sub_choices.add_child(UI.choice("%d · %s" % [i + 1, game.fill(c.label)], game.fill(c.get("hint", "")), game.choice_lock(c), game.resolve_choice.bind(i)))
			i += 1)


## Màn kết chương: tên kết, lời kết, câu nói, "nếu câu chuyện dừng ở đây"; rồi nút chơi tiếp, xem thêm, chơi lại.
func _sub_ending() -> void:
	var over: Dictionary = game.s.over
	var key := "end|%s|%s" % [str(over.get("kind", "")), str(over.get("key", ""))]
	if key == _sub_key:
		return
	var st: Dictionary = game.chapter_story()
	var e: Dictionary = game._merge_variants(st.endings[over.key])
	var head := "Kết chương %d  ·  %s  ·  %s" % [game.chapter(), str(over.key), str(e.tag)]
	var lines := [{"who": "", "text": game.fill(str(e.title)), "big": true}]
	lines.append_array(Sub.narration(game.fill(str(e.text))))
	lines.append_array(Sub.quote(game.fill(str(e.get("quote", "")))))
	lines.append_array(Sub.narration(game.fill(str(e.get("epilogue", ""))), "Nếu câu chuyện dừng ở đây" if game.can_continue() else "Về sau"))
	_sub_start(key, head, lines, func() -> void:
		if game.can_continue():
			var nxt: Dictionary = game.next_story()
			_sub_choices.add_child(UI.choice("Chơi tiếp: " + str(nxt.get("title", "Chương %d" % (game.chapter() + 1))), str(nxt.get("continue", "")), "",
				game.continue_chapter))
		_sub_choices.add_child(UI.choice("Xem thêm: thẻ hậu truyện, người ở phố, sổ tay", "Đọc khi muốn, không bắt buộc", "", func() -> void:
			_ending_full = true
			refresh()))
		_sub_choices.add_child(UI.choice("Chơi lại từ ngày 1", "", "", GameState.restart)))


func _sub_start(key: String, head: String, lines: Array, build: Callable) -> void:
	_sub_key = key
	_sub_head.text = head.to_upper() if head.length() < 40 else head
	_sub_lines = lines.filter(func(l) -> bool: return str(l.text).strip_edges() != "")
	_sub_i = 0
	_sub_build = build
	for c in _sub_choices.get_children():
		_sub_choices.remove_child(c)
		c.queue_free()
	_sub_show()


func _sub_show() -> void:
	if _sub_i >= _sub_lines.size():
		_sub_finish()
		return
	var l: Dictionary = _sub_lines[_sub_i]
	var who := str(l.get("who", ""))
	_sub_who.text = who
	_sub_who.visible = who != ""
	var big: bool = l.get("big", false)
	_sub_line.add_theme_font_size_override("font_size", 30 if big else 21)
	_sub_line.add_theme_color_override("font_color", UI.GOLD if big else (UI.HUD_TEXT if l.get("say", false) else Color("d9dbe6")))
	# Lời thoại (dòng có "say") để trong ngoặc kép; lời kể, mục của màn kết, sổ tay để nguyên.
	_sub_line.text = ("“%s”" % str(l.text).trim_prefix("\"").trim_suffix("\"").trim_prefix("“").trim_suffix("”")) if l.get("say", false) else str(l.text)
	_sub_line.visible_characters = 0
	_sub_chars = 0.0
	_sub_hint.text = "Chạm hay nhấn Space để tiếp  ▸   %d/%d" % [_sub_i + 1, _sub_lines.size()]
	_sub_hint.visible = true
	_sub_skip.visible = true


## Hết lời: giữ câu cuối trên màn hình, hiện lựa chọn (bấm số 1–9 để chọn nhanh).
func _sub_finish() -> void:
	_sub_chars = -1.0
	_sub_line.visible_characters = -1
	_sub_hint.visible = false
	_sub_skip.visible = false
	if _sub_lines.is_empty():
		_sub_who.visible = false
		_sub_line.text = ""
	if _sub_choices.get_child_count() == 0 and _sub_build.is_valid():
		_sub_build.call()


func _process(delta: float) -> void:
	if _sub_chars < 0.0 or not _sub_root.visible:
		return
	_sub_chars += delta * TYPE_SPEED
	var total := _sub_line.get_total_character_count()
	if _sub_chars >= total:
		_sub_chars = -1.0
		_sub_line.visible_characters = -1
	else:
		_sub_line.visible_characters = int(_sub_chars)


## Chạm khi chữ đang chạy thì hiện hết câu; chạm lần nữa sang câu sau.
func _sub_advance() -> void:
	if _sub_i >= _sub_lines.size():
		return
	if _sub_chars >= 0.0:
		_sub_chars = -1.0
		_sub_line.visible_characters = -1
		return
	_sub_i += 1
	_sub_show()


func _sub_skip_all() -> void:
	_sub_i = _sub_lines.size()
	if not _sub_lines.is_empty():
		_sub_i = _sub_lines.size() - 1
		_sub_show()
		_sub_i = _sub_lines.size()
	_sub_finish()


func _on_sub_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and event.pressed):
		_sub_advance()
		accept_event()


func _input(event: InputEvent) -> void:
	if not visible or not _sub_root.visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
		if _sub_i < _sub_lines.size():
			_sub_advance()
			get_viewport().set_input_as_handled()
	elif event.keycode >= KEY_1 and event.keycode <= KEY_9 and _sub_i >= _sub_lines.size():
		var idx: int = event.keycode - KEY_1
		var btns := _sub_choices.get_children().filter(func(b) -> bool: return not b.is_queued_for_deletion())
		if idx < btns.size() and not btns[idx].disabled:
			get_viewport().set_input_as_handled()
			btns[idx].pressed.emit()


func _start() -> void:
	var p: Dictionary = game.story.prologue
	_head(p.eyebrow, p.title, "", p.text, p.quote)
	_box.add_child(UI.choice(p.start, "30 ngày · 1.200.000đ tiền mặt · 3.600.000đ lương cũ còn phải thu", "", game.new_game.bind("full")))
	if not game.story2.is_empty():
		var more := "Hết ngày 30 có nút Chơi tiếp sang %s: thêm 30 ngày ở chỗ mới, mọi lựa chọn của tháng đầu đi theo." % \
			str(game.story2.get("title", "Chương 2 · Mùa mưa"))
		if not game.story3.is_empty():
			more += " Hết ngày 60 chơi tiếp %s (ngày 61–90)." % str(game.story3.get("title", "Chương 3"))
		if not game.story4.is_empty():
			more += " Hết ngày 90 chơi tiếp %s (ngày 91–120)." % str(game.story4.get("title", "Chương 4"))
		if not game.story5.is_empty():
			more += " Hết ngày 120 chơi tiếp %s (ngày 121–150)." % str(game.story5.get("title", "Chương 5"))
		_box.add_child(UI.wrap(more, 12, UI.INK_SOFT))
	_box.add_child(UI.label(p.slicePick, 11, UI.INK_SOFT))
	for k in GameLogic.ROUTES:
		var pre: Dictionary = game.cfg.presets[k]
		_box.add_child(UI.choice(pre.name, pre.desc, "", game.new_game.bind(k)))
	_box.add_child(UI.label("Chế độ riêng, ngoài truyện:", 11, UI.INK_SOFT))
	_box.add_child(UI.choice("Dựng một khu thật ở Việt Nam", "Gõ tên phường, phố; lấy nhà, đường, sông hồ từ OpenStreetMap và Open Buildings rồi đi dạo (cần mạng)", "",
		func() -> void: get_tree().change_scene_to_file("res://scenes/realmap.tscn")))


func _event() -> void:
	var e: Dictionary = game.current_event()
	if e.is_empty():
		return
	_head(e.eyebrow, game.fill(e.title), e.get("who", ""), game.fill(e.text), game.fill(e.get("quote", "")))
	var i := 0
	for c in e.choices:
		_box.add_child(UI.choice(game.fill(c.label), game.fill(c.get("hint", "")), game.choice_lock(c), game.resolve_choice.bind(i)))
		i += 1


func _night() -> void:
	var n: Dictionary = game.night_preview()
	var lines := []
	if int(n.living) > 0:
		lines.append("Sinh hoạt cả nhà: −%s" % GameLogic.fmt_money(n.living))
	lines.append("Ngủ và %s giờ còn trống: Mệt −%d" % [GameLogic.num(n.free_hours), int(n.recover)])
	if int(n.due_pay) > 0:
		lines.append("Đến hạn trả tối nay: %s" % GameLogic.fmt_money(n.due_pay))
	for label in n.due_recv:
		lines.append("Đến hạn nhận: %s" % label)
	if game.fatigue_warn() and not game.s.today.get("rested", false):
		lines.append("Mệt đang ở mức cảnh báo mà hôm nay chưa nghỉ.")
	if n.slice_end:
		lines.append("Đây là đêm cuối của lát cắt. Sau đêm nay sẽ có bảng tổng kết.")
	_head("Ngày %d · %s" % [game.day(), GameLogic.hh(minf(game.clock(), 22.0))], "Đi ngủ?", "", "\n".join(lines), "")
	# Sổ tay: điều An đã chọn hôm nay, rồi một dòng hé lộ ngày mai để người chơi muốn sang ngày.
	var today: Array = game.diary_of(game.day())
	if not today.is_empty():
		_box.add_child(UI.label("SỔ TAY CỦA AN", 11, UI.INK_SOFT))
		_box.add_child(UI.wrap("\n".join(today), 15, UI.TIM))
	var next: String = "" if n.slice_end else game.teaser(game.day() + 1)
	if next != "":
		_box.add_child(UI.label("NGÀY MAI", 11, UI.INK_SOFT))
		_box.add_child(UI.wrap(next, 14, UI.INK))
	_box.add_child(UI.choice("Đi ngủ", "Sang ngày %d" % (game.day() + 1) if not n.slice_end else "Xem tổng kết", "", _end_day))
	# Hết giờ thì không quay lại được nữa, chỉ còn đi ngủ.
	if not game.is_out_of_time():
		_box.add_child(UI.choice("Quay lại", "Tiếp tục ngày %d" % game.day(), "", _cancel_night))


func _report() -> void:
	var r: Dictionary = game.slice_report()
	var deadline := int(game.cfg.housingDeadline)
	_box.add_child(UI.label("TỔNG KẾT LÁT CẮT NGÀY 18–22 · TUYẾN %s" % r.route, 12, UI.TIM))
	var housing_name := "Chưa đủ cả chỗ ở tạm" if r.housing == "" else str(game.cfg.housing[r.housing].name)
	_box.add_child(UI.wrap("Dự kiến sáng ngày %d: %s" % [deadline, GameLogic.fmt_money(r.proj_deadline)], 24, UI.INK))
	_box.add_child(UI.wrap("Đủ cho: " + housing_name, 16, UI.GOOD if r.housing == "hem_dua" else (UI.WARN if r.housing != "" else UI.STAMP)))
	var money := [
		"Tiền mặt bây giờ: %s" % GameLogic.fmt_money(r.cash),
		"Phải thu trước ngày 30: %s · sau ngày 30: %s" % [GameLogic.fmt_money(r.recv_before_30), GameLogic.fmt_money(r.recv_after_30)],
		"Phải trả còn treo: %s" % GameLogic.fmt_money(r.pay_pending),
	]
	if r.route != "A":
		money.append("Tiến độ hợp đồng: %d/%d buổi" % [r.progress, r.need])
	money.append("Mệt: %d · ngày ở mức cảnh báo: %d · lần bỏ qua nghỉ: %d" % [int(r.fatigue), r.warn_days, r.rest_skips])
	_box.add_child(UI.wrap("\n".join(money), 14, UI.INK_SOFT))

	var linh: Dictionary = game.story.linhCards[r.linh_card]
	_box.add_child(UI.label("LINH", 11, UI.INK_SOFT))
	_box.add_child(UI.wrap("%s\n%s" % [linh.title, linh.text], 14, UI.INK))
	var ba: Dictionary = game.story.baTuCards[r.ba_tu_card]
	_box.add_child(UI.label("BÀ TƯ", 11, UI.INK_SOFT))
	_box.add_child(UI.wrap("%s\n%s" % [ba.title, ba.text], 14, UI.INK))

	var promises := []
	for p in r.promises:
		promises.append("• %s · hạn ngày %d · %s" % [p.text, p.due, GameLogic.PROMISE_STATUS.get(p.status, p.status)])
	_box.add_child(UI.label("SỔ LỜI HỨA", 11, UI.INK_SOFT))
	_box.add_child(UI.wrap("\n".join(promises), 13, UI.INK))
	var f: Dictionary = r.family
	_box.add_child(UI.wrap("Sổ gia đình: hỗ trợ %d · ép quyết định %d · che giấu %d · bớt giờ ở nhà %d" % [f.support, f.pressure, f.conceal, f.time_lost], 13, UI.INK_SOFT))

	_box.add_child(UI.choice("Chơi lại lát cắt", "Chọn lại tuyến A, B hoặc C", "", GameState.restart))
	_box.add_child(UI.choice("Sao chép kết quả lượt chơi", "Dán vào chat để phân tích cân bằng", "", func() -> void: DisplayServer.clipboard_set(game.summary())))


## Màn kết 30 ngày: một cảnh chính, thẻ của Linh, thẻ của bà Tư, một thẻ quan hệ nghề, các khoản còn phải xử lý.
## Không có huy chương tốt hay xấu.
func _ending() -> void:
	var over: Dictionary = game.s.over
	var e: Dictionary = game.story.endings[over.key]
	_box.add_child(UI.label("%s · %s" % [str(over.key), str(e.tag).to_upper()], 12, UI.TIM))
	# Phần "xem thêm" sau phụ đề kết: lời kết đã đọc rồi, chỉ còn nút chơi tiếp và các thẻ.
	if not _ending_full:
		_head("", e.title, "", e.text, e.quote)
	_epilogue_or_continue(e)
	var codas: Array = game.codas()
	if not codas.is_empty():
		_box.add_child(UI.label("SAU ĐÓ", 11, UI.INK_SOFT))
		_box.add_child(UI.wrap("\n\n".join(codas), 14, UI.INK))
	var keep: Array = game.keepsakes()
	if not keep.is_empty():
		_box.add_child(UI.label("TRONG THÙNG ĐỒ CUỐI CÙNG", 11, UI.INK_SOFT))
		var items := []
		for k in keep:
			items.append("• %s: %s" % [k.name, k.text])
		_box.add_child(UI.wrap("\n".join(items), 13, UI.INK))
	var h: Dictionary = game.housing()
	var place := str(game.cfg.housing.get(h.place, {}).get("name", "chưa rõ"))
	var lines := [
		"Chỗ ở: %s · Tuyến %s" % [place, str(game.s.route)],
		"Tiền mặt: %s · phải thu sau ngày 30: %s" % [GameLogic.fmt_money(int(game.s.cash)), GameLogic.fmt_money(game.receivable_sum(31, 999))],
	]
	_box.add_child(UI.wrap("\n".join(lines), 14, UI.INK))
	var linh: Dictionary = game.story.linhCards.get(over.linh, {})
	if not linh.is_empty():
		_box.add_child(UI.label("LINH", 11, UI.INK_SOFT))
		_box.add_child(UI.wrap("%s\n%s" % [linh.title, linh.text], 14, UI.INK))
	var ba: Dictionary = game.story.baTuCards.get(over.ba_tu, {})
	if not ba.is_empty():
		_box.add_child(UI.label("BÀ TƯ", 11, UI.INK_SOFT))
		_box.add_child(UI.wrap("%s\n%s" % [ba.title, ba.text], 14, UI.INK))
	var people := []
	for x in game.npc_lines():
		people.append("%s · %s" % [game.rep_name(x.who), x.text])
	if not people.is_empty():
		_box.add_child(UI.label("Ở XÓM VÀ Ở PHỐ", 11, UI.INK_SOFT))
		_box.add_child(UI.wrap("\n\n".join(people), 13, UI.INK))
	var left := []
	for x in game.s.payables:
		if x.status in ["unpaid", "renegotiated"] or (x.status == "pending" and int(x.due) > 30):
			left.append("• %s: %s" % [x.label, GameLogic.fmt_money(int(x.amount))])
	for pr in game.s.promises:
		if pr.status in ["overdue", "renegotiated"]:
			left.append("• %s (%s)" % [pr.text, GameLogic.PROMISE_STATUS.get(pr.status, pr.status)])
	for r in game.s.receivables:
		if r.status == "pending":
			left.append("• Còn chờ nhận: %s %s" % [r.label, GameLogic.fmt_money(int(r.amount))])
	if not left.is_empty():
		_box.add_child(UI.label("CÒN PHẢI XỬ LÝ", 11, UI.INK_SOFT))
		_box.add_child(UI.wrap("\n".join(left), 13, UI.INK_SOFT))
	var diary: Array = game.s.get("diary", [])
	if not diary.is_empty():
		if _diary_open:
			_box.add_child(UI.label("SỔ TAY THÁNG NÀY", 11, UI.INK_SOFT))
			var rows := []
			for x in diary:
				rows.append("Ngày %d · %s" % [int(x.day), x.text])
			_box.add_child(UI.wrap("\n".join(rows), 13, UI.INK))
		_box.add_child(UI.choice("Gấp sổ tay lại" if _diary_open else "Đọc lại sổ tay của An", "%d dòng, từ ngày 1 tới ngày 30" % diary.size(), "", _toggle_diary))
	_box.add_child(UI.choice("Chơi lại từ ngày 1", "", "", GameState.restart))
	_box.add_child(UI.choice("Sao chép kết quả lượt chơi", "Dán vào chat để phân tích cân bằng", "", func() -> void: DisplayServer.clipboard_set(game.summary())))


## Màn kết chương 2 (ngày 60, giỗ ông) và chương 3 (ngày 90, đêm cuối tháng Bảy): cảnh chính, hậu truyện (kèm nút Chơi
## tiếp nếu còn chương sau), "sau đó", đồ giữ lại, các thẻ hậu truyện, từng người ở phố mới và phố cũ, các khoản còn lại.
## Thẻ chương 2 là của má, bà, Linh; thẻ chương 3 chọn theo điều kiện trong story3.cards (game.pick_cards).
func _ending2() -> void:
	_ending_chapter([["MÁ", "maCards", "ma"], ["BÀ TƯ", "baTuCards", "ba_tu"], ["LINH", "linhCards", "linh"]], "TRÊN BÀN THỜ VÀ TRONG NHÀ MỚI", "SỔ TAY HAI THÁNG")


func _ending3() -> void:
	_ending_chapter(_story_cards(game.story3), "TRONG TIỆM VÀ TRONG NHÀ", "SỔ TAY BA THÁNG")


func _ending4() -> void:
	_ending_chapter(_story_cards(game.story4), "TRONG TIỆM VÀ TRONG NHÀ", "SỔ TAY BỐN THÁNG")


func _ending5() -> void:
	_ending_chapter(_story_cards(game.story5), "TRONG TIỆM VÀ TRONG NHÀ", "SỔ TAY NĂM THÁNG")


## Thẻ hậu truyện chọn theo điều kiện (chương 3 trở đi): [nhãn, bảng thẻ, khóa trong s.over.cards].
func _story_cards(st: Dictionary) -> Array:
	var cards := []
	for c in st.get("cards", []):
		cards.append([str(c.title), c.get("items", {}), str(c.id)])
	return cards


## cards: [nhãn, bảng thẻ (tên khóa trong story của chương, hay chính bảng thẻ), khóa trong s.over (chương 3: s.over.cards)].
func _ending_chapter(cards: Array, keep_label: String, diary_label: String) -> void:
	var ch: int = game.chapter()
	var last: int = game.last_day()
	var over: Dictionary = game.s.over
	var st: Dictionary = game.chapter_story()
	# Kết có thể có biến thể (K3 ở sạp chung với Kha hay trước hiên nhà, L3 theo người góp tiệm).
	var e: Dictionary = game._merge_variants(st.endings[over.key])
	_box.add_child(UI.label("CHƯƠNG %d · %s · %s" % [ch, str(over.key), str(e.tag).to_upper()], 12, UI.TIM))
	if not _ending_full:
		_head("", game.fill(str(e.title)), "", game.fill(str(e.text)), game.fill(str(e.quote)))
	_epilogue_or_continue(e)
	var codas: Array = game.codas()
	if not codas.is_empty():
		_box.add_child(UI.label("SAU ĐÓ", 11, UI.INK_SOFT))
		_box.add_child(UI.wrap("\n\n".join(codas), 14, UI.INK))
	var keep: Array = game.keepsakes()
	if not keep.is_empty():
		_box.add_child(UI.label(keep_label, 11, UI.INK_SOFT))
		var items := []
		for k in keep:
			items.append("• %s: %s" % [k.name, k.text])
		_box.add_child(UI.wrap("\n".join(items), 13, UI.INK))
	var h: Dictionary = game.housing()
	var place := str(game.cfg.housing.get(h.place, {}).get("name", "chưa rõ"))
	if h.state == "reserved":
		place = "%s (đã đặt cọc, %s)" % [place, {2: "dọn sau giỗ", 3: "dọn mùng một tháng Tám", 4: "dọn mùng một tháng Chín"}.get(ch, "dọn mùng một tháng Mười")]
	elif h.place == "di_nam":
		place = "Ở nhờ nhà dì Nga"
	_box.add_child(UI.wrap("Chỗ ở: %s · Tuyến %s · Tiền mặt: %s" % [place, str(game.s.route), GameLogic.fmt_money(int(game.s.cash))], 14, UI.INK))
	for c in cards:
		var table: Dictionary = c[1] if c[1] is Dictionary else st.get(str(c[1]), {})
		var key := str(over.get("cards", {}).get(c[2], "")) if ch >= 3 else str(over.get(c[2], ""))
		var card: Dictionary = table.get(key, {})
		if not card.is_empty():
			_box.add_child(UI.label(str(c[0]), 11, UI.INK_SOFT))
			_box.add_child(UI.wrap("%s\n%s" % [game.fill(str(card.title)), game.fill(str(card.text))], 14, UI.INK))
	var people := []
	for x in game.npc_lines():
		people.append("%s · %s" % [game.rep_name(x.who), x.text])
	if not people.is_empty():
		_box.add_child(UI.label("Ở PHỐ MỚI VÀ PHỐ CŨ", 11, UI.INK_SOFT))
		_box.add_child(UI.wrap("\n\n".join(people), 13, UI.INK))
	var left := []
	for x in game.s.payables:
		if x.status in ["unpaid", "renegotiated"] or (x.status == "pending" and int(x.due) > last):
			left.append("• %s: %s" % [x.label, GameLogic.fmt_money(int(x.amount))])
	for pr in game.s.promises:
		if pr.status in ["overdue", "renegotiated"] and int(pr.get("made", 0)) > last - 30:
			left.append("• %s (%s)" % [pr.text, GameLogic.PROMISE_STATUS.get(pr.status, pr.status)])
	if not left.is_empty():
		_box.add_child(UI.label("CÒN PHẢI XỬ LÝ", 11, UI.INK_SOFT))
		_box.add_child(UI.wrap("\n".join(left), 13, UI.INK_SOFT))
	var diary: Array = game.s.get("diary", [])
	if not diary.is_empty():
		if _diary_open:
			_box.add_child(UI.label(diary_label, 11, UI.INK_SOFT))
			var rows := []
			for x in diary:
				rows.append("Ngày %d · %s" % [int(x.day), x.text])
			_box.add_child(UI.wrap("\n".join(rows), 13, UI.INK))
		_box.add_child(UI.choice("Gấp sổ tay lại" if _diary_open else "Đọc lại sổ tay của An", "%d dòng, từ ngày 1 tới ngày %d" % [diary.size(), last], "", _toggle_diary))
	_box.add_child(UI.choice("Chơi lại từ ngày 1", "", "", GameState.restart))
	_box.add_child(UI.choice("Sao chép kết quả lượt chơi", "Dán vào chat để phân tích cân bằng", "", func() -> void: DisplayServer.clipboard_set(game.summary())))


## Hậu truyện của kết: còn chương sau thì hậu truyện chỉ đúng nếu dừng ở đây, kèm nút Chơi tiếp.
func _epilogue_or_continue(e: Dictionary) -> void:
	if game.can_continue():
		var nxt: Dictionary = game.next_story()
		if not _ending_full:
			_box.add_child(UI.label("NẾU CÂU CHUYỆN DỪNG Ở ĐÂY", 11, UI.INK_SOFT))
			_box.add_child(UI.wrap(game.fill(str(e.epilogue)), 14, UI.INK_SOFT))
		_box.add_child(UI.choice("Chơi tiếp: " + str(nxt.get("title", "Chương %d" % (game.chapter() + 1))), str(nxt.get("continue", "")), "",
			game.continue_chapter))
	elif not _ending_full:
		_box.add_child(UI.wrap(game.fill(str(e.epilogue)), 14, UI.INK_SOFT))


func _head(eyebrow: String, title: String, who: String, text: String, quote: String) -> void:
	if eyebrow != "":
		_box.add_child(UI.label(eyebrow.to_upper(), 11, UI.INK_SOFT))
	_box.add_child(UI.wrap(title, 26, UI.INK))
	if who != "":
		_box.add_child(UI.label(who, 14, UI.TIM))
	if text != "":
		_box.add_child(UI.wrap(text, 15, UI.INK))
	if quote != "":
		_box.add_child(UI.wrap(quote, 17, UI.TIM))


func _end_day() -> void:
	night_open = false
	game.finish_day()


func _toggle_diary() -> void:
	_diary_open = not _diary_open
	refresh()


func _cancel_night() -> void:
	night_open = false
	refresh()
