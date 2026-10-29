extends Control
## Màn "Tổng kết cuối ngày" khi đi ngủ (chơi đủ 30 ngày). Số liệu do scripts/systems/hardship.gd soạn (day_summary):
## thu, chi, tiền còn so với sáng (số chạy lên), từng khoản, nhu cầu thay đổi, tiền trọ đêm nay, mục tiêu ngắn hạn,
## sổ tay hôm nay và một dòng hé lộ ngày mai. Phát sleep() khi bấm ngủ (đã trả hay ghi nợ tiền trọ), back() khi quay lại.

signal sleep
signal back

const UI := preload("res://scripts/ui/ui_kit.gd")
const GameLogic := preload("res://scripts/game_logic.gd")
const Hardship := preload("res://scripts/systems/hardship.gd")

var game
var _panel: PanelContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UI.make_theme()
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.015, 0.0)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	create_tween().tween_property(dim, "color:a", 0.72, 0.35)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UI.box(Color(0.07, 0.07, 0.06, 0.97), Color(UI.GOLD, 0.45), 10, 20))
	_panel.custom_minimum_size = Vector2(minf(760.0, get_viewport_rect().size.x - 24.0), 0)
	center.add_child(_panel)
	_build()
	_panel.modulate.a = 0.0
	_panel.scale = Vector2(0.96, 0.96)
	_panel.pivot_offset = _panel.custom_minimum_size / 2.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_panel, "modulate:a", 1.0, 0.3)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _build() -> void:
	var sm: Dictionary = Hardship.day_summary(game)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_panel.add_child(v)
	v.add_child(UI.label("NGÀY %d · %s · %s" % [int(sm.day), game.weekday_name().to_upper(), GameLogic.hh(minf(game.clock(), 22.0))], 12, UI.INK_SOFT))
	v.add_child(UI.label("Tổng kết cuối ngày", 26, UI.GOLD))
	# Ba số lớn: thu, chi, tiền còn (chạy từ 0 lên).
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var delta := int(sm.cash) - int(sm.cash0)
	for spec in [["THU", int(sm.earned), "+", UI.GOOD], ["CHI", int(sm.spent), "−", UI.STAMP], ["CÒN TRONG TÚI", int(sm.cash), "", UI.INK]]:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UI.box(Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.08), 8, 12))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(card)
		var cv := VBoxContainer.new()
		card.add_child(cv)
		cv.add_child(UI.label(spec[0], 11, UI.INK_SOFT))
		var num := UI.label("0đ", 24, spec[3])
		cv.add_child(num)
		_count_up(num, int(spec[1]), str(spec[2]))
		if spec[0] == "CÒN TRONG TÚI":
			cv.add_child(UI.label(("%s%s so với sáng" % ["+" if delta >= 0 else "−", GameLogic.fmt_money(absi(delta))]), 12, UI.GOOD if delta >= 0 else UI.STAMP))
	# Từng khoản thu, chi.
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	v.add_child(cols)
	for spec in [["Khoản thu", sm["in"], UI.GOOD], ["Khoản chi", sm["out"], UI.STAMP]]:
		var c := VBoxContainer.new()
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cols.add_child(c)
		c.add_child(UI.label(spec[0], 13, spec[2]))
		var items: Array = spec[1]
		if items.is_empty():
			c.add_child(UI.label("Không có", 12, UI.INK_SOFT))
		for i in mini(items.size(), 6):
			c.add_child(UI.wrap("· " + str(items[i]), 12, UI.INK, 340))
		if items.size() > 6:
			c.add_child(UI.label("… và %d khoản nữa" % (items.size() - 6), 12, UI.INK_SOFT))
	# Cơ thể hôm nay.
	var body := []
	for k in [["fed", "No bụng"], ["clean", "Vệ sinh"], ["mood", "Tâm trạng"]]:
		var d := float(sm.needs.get(k[0], 0.0))
		body.append("%s %d (%s%d)" % [k[1], int(game.need(k[0])), "+" if d >= 0.0 else "−", int(absf(d))])
	body.append("Mệt %d" % int(sm.fatigue))
	if int(sm.rep) != 0:
		body.append("Quan hệ %s%d" % ["+" if int(sm.rep) > 0 else "−", absi(int(sm.rep))])
	v.add_child(UI.wrap("  ·  ".join(body), 13, UI.INK_SOFT, 720))
	# Tiền trọ và mục tiêu.
	if Hardship.on(game):
		var rent := int(sm.rent)
		var bill := "✓ Đã trả %s tiền trọ đêm nay" % GameLogic.fmt_money(rent) if sm.paid else "Tiền trọ đêm nay %s: chưa trả" % GameLogic.fmt_money(rent)
		v.add_child(UI.label(bill, 15, UI.GOOD if sm.paid else UI.STAMP))
	var goal: Dictionary = sm.goal
	if not goal.is_empty():
		v.add_child(UI.label("Mục tiêu: %s · %s / %s" % [goal.name, GameLogic.fmt_money(int(goal.have)), GameLogic.fmt_money(int(goal.need))], 13, UI.GOLD))
		var b := UI.bar(8)
		v.add_child(b)
		UI.set_bar(b, 0.0, 100.0, UI.GOLD)
		var tw := create_tween()
		tw.tween_interval(0.4)
		tw.tween_method(func(x: float) -> void: UI.set_bar(b, x, 100.0, UI.GOLD), 0.0, float(goal.pct) * 100.0, 0.8)
	var today: Array = game.diary_of(game.day())
	if not today.is_empty():
		v.add_child(UI.label("SỔ TAY CỦA AN", 11, UI.INK_SOFT))
		v.add_child(UI.wrap("\n".join(today.slice(-3)), 14, UI.TIM, 720))
	var next: String = game.teaser(game.day() + 1)
	v.add_child(UI.label("SÁNG MAI", 11, UI.INK_SOFT))
	v.add_child(UI.wrap((next + "\n" if next != "" else "") + "06:00 điện thoại sẽ báo việc thưởng nóng ×2 lương và tin nhắn mới.", 13, UI.INK, 720))
	# Nút.
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	v.add_child(foot)
	var lock := Hardship.sleep_lock(game)
	if lock == "":
		_button(foot, "Ngủ · sang ngày %d  (Space)" % (game.day() + 1), true, func() -> void: sleep.emit())
	else:
		var rent := Hardship.rent(game)
		var can := int(game.s.cash) >= rent
		_button(foot, "Trả %s rồi ngủ" % GameLogic.fmt_money(rent), true, func() -> void:
			if Hardship.pay_rent(game) == "":
				sleep.emit(), not can)
		var u: Dictionary = Hardship.data(game).get("unpaid", {})
		_button(foot, "Xin ghi nợ một đêm (Tâm trạng %d)" % int(u.get("mood", -8)), false, func() -> void: sleep.emit(), can)
	if not game.is_out_of_time():
		_button(foot, "Quay lại  (Esc)", false, func() -> void: back.emit())


func _button(parent: Control, text: String, primary: bool, f: Callable, disabled := false) -> void:
	var b := Button.new()
	b.text = text
	b.disabled = disabled
	b.custom_minimum_size = Vector2(0, 44)
	if primary:
		b.add_theme_stylebox_override("normal", UI.box(Color(UI.GOLD, 0.25), UI.GOLD, 8, 10))
		b.add_theme_stylebox_override("hover", UI.box(Color(UI.GOLD, 0.4), UI.GOLD, 8, 10))
	b.pressed.connect(f)
	parent.add_child(b)


func _count_up(l: Label, to: int, sign: String) -> void:
	var tw := create_tween()
	tw.tween_interval(0.25)
	tw.tween_method(func(x: float) -> void: l.text = sign + GameLogic.fmt_money(int(x)), 0.0, float(to), 0.7).set_ease(Tween.EASE_OUT)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_SPACE and Hardship.sleep_lock(game) == "":
		get_viewport().set_input_as_handled()
		sleep.emit()
	elif event.keycode == KEY_ESCAPE and not game.is_out_of_time():
		get_viewport().set_input_as_handled()
		back.emit()
