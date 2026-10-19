extends Control
## Trò chơi nhỏ rửa bát: bấm từng vết bẩn trên bát để kỳ cọ (vết to chà hai lần), sạch thì xếp lên giá.
## Xếp bát còn bẩn bị chủ quán trả lại, tính một lỗi. Đủ chỉ tiêu thì đủ công; vượt chỉ tiêu và không lỗi được thưởng.
## Phát finished(result) giống minigame_bricks.gd: {"ratio", "bonus"}, {"auto": true, ...} hoặc {} nếu bỏ.

const UI := preload("res://scripts/ui/ui_kit.gd")
const GameLogic := preload("res://scripts/game_logic.gd")

signal finished(result: Dictionary)

var cfg: Dictionary = {}
var last: Dictionary = {}
var title := "Rửa bát"
var _box: VBoxContainer
var _state := "start"
var _time_left := 0.0
var _clean := 0
var _mistakes := 0
var _spots: Array = []
var _rng := RandomNumberGenerator.new()
var _plate: Control
var _timer_bar: ProgressBar
var _stats: Label
var _note: Label

const PLATE_R := 150.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UI.make_theme()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 0)
	panel.add_theme_stylebox_override("panel", UI.box(UI.CARD, UI.LINE, 12, 22))
	center.add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 12)
	panel.add_child(_box)
	_rng.randomize()
	_show_start()


func _clear() -> void:
	for c in _box.get_children():
		c.queue_free()


func _show_start() -> void:
	_state = "start"
	_clear()
	_box.add_child(UI.label(title.to_upper() + " · QUÁN CƠM TẤM", 12, UI.INK_SOFT))
	_box.add_child(UI.wrap("Rửa sạch chồng bát", 26, UI.INK, 660))
	_box.add_child(UI.wrap("Bấm từng vết bẩn để kỳ cọ, vết to phải chà hai lần. Sạch thì bấm Xếp lên giá (hoặc phím cách). Xếp bát còn bẩn là bị trả lại. Đủ %d cái trong %d giây thì đủ công; rửa vượt chỉ tiêu và không bị trả lại lần nào thì được thưởng." % [int(cfg.target), int(cfg.seconds)], 15, UI.INK, 660))
	_box.add_child(UI.choice("Tự làm", "Làm nhanh, sạch thì được thưởng", "", _start_play))
	if not last.is_empty():
		_box.add_child(UI.choice("Làm tự động", "Như lần trước: %d%% công · thưởng %s" % [int(float(last.ratio) * 100.0), GameLogic.fmt_k(int(last.bonus))], "",
			func() -> void: finished.emit({"ratio": float(last.ratio), "bonus": int(last.bonus), "auto": true})))
	_box.add_child(UI.choice("Thôi, không làm nữa", "", "", func() -> void: finished.emit({})))


func _ratio() -> float:
	return clampf(float(_clean) / float(cfg.target), float(cfg.minRatio), 1.0)


func _bonus() -> int:
	var b := maxi(0, _clean - int(cfg.target)) * int(cfg.bonusPerExtra)
	if _mistakes == 0 and _clean >= int(cfg.target):
		b += int(cfg.cleanBonus)
	return b


func _show_end() -> void:
	_state = "end"
	_clear()
	_box.add_child(UI.label("HẾT CA", 12, UI.INK_SOFT))
	_box.add_child(UI.wrap("Rửa sạch %d/%d cái bát" % [_clean, int(cfg.target)], 26, UI.INK, 660))
	var txt := "Được %d%% tiền công, thưởng %s." % [int(_ratio() * 100.0), GameLogic.fmt_k(_bonus())]
	if _mistakes > 0:
		txt += " Bị trả lại %d cái." % _mistakes
	elif _clean >= int(cfg.target):
		txt += " Chủ quán khen bát sạch bong."
	_box.add_child(UI.wrap(txt, 15, UI.INK, 660))
	_box.add_child(UI.choice("Nhận tiền", "", "", func() -> void: finished.emit({"ratio": _ratio(), "bonus": _bonus()})))


func _start_play() -> void:
	_state = "play"
	_time_left = float(cfg.seconds)
	_clean = 0
	_mistakes = 0
	_clear()
	var head := HBoxContainer.new()
	_box.add_child(head)
	var t := UI.label(title, 20, UI.INK)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	_stats = UI.label("", 15, UI.INK)
	head.add_child(_stats)
	_timer_bar = UI.bar(10)
	_timer_bar.max_value = 1.0
	_box.add_child(_timer_bar)
	_plate = Control.new()
	_plate.custom_minimum_size = Vector2(660, 340)
	_plate.mouse_filter = Control.MOUSE_FILTER_STOP
	_plate.draw.connect(_draw_plate)
	_plate.gui_input.connect(_plate_input)
	_box.add_child(_plate)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_box.add_child(row)
	var stack := UI.choice("Xếp lên giá (phím cách)", "", "", _rack)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(stack)
	_note = UI.label("", 14, UI.TIM)
	_box.add_child(_note)
	_new_dish()


## Bát mới: 2 đến 5 vết bẩn; vết to (cơm cháy, mỡ) phải chà hai lần.
func _new_dish() -> void:
	_spots.clear()
	for i in _rng.randi_range(int(cfg.spots[0]), int(cfg.spots[1])):
		var ang := _rng.randf() * TAU
		var dist := _rng.randf_range(0.0, PLATE_R * 0.72)
		var big := _rng.randf() < 0.4
		_spots.append({"pos": Vector2(cos(ang), sin(ang)) * dist, "r": _rng.randf_range(20.0, 30.0) if big else _rng.randf_range(12.0, 18.0), "hp": 2 if big else 1,
			"col": Color("8a5a2b") if _rng.randf() < 0.6 else Color("b88a3b")})
	_refresh()


func _plate_center() -> Vector2:
	return _plate.size / 2.0


func _draw_plate() -> void:
	var c := _plate_center()
	_plate.draw_circle(c + Vector2(6, 8), PLATE_R, Color(0, 0, 0, 0.12))
	_plate.draw_circle(c, PLATE_R, Color("f4f1ea"))
	_plate.draw_arc(c, PLATE_R * 0.78, 0, TAU, 64, Color("5b8fc7"), 3.0)
	_plate.draw_arc(c, PLATE_R * 0.98, 0, TAU, 64, Color("d6d0c4"), 2.0)
	for s in _spots:
		var a := 0.95 if int(s.hp) > 1 else 0.6
		_plate.draw_circle(c + s.pos, float(s.r), Color(s.col, a))


func _plate_input(event: InputEvent) -> void:
	if _state != "play":
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_scrub(event.position)


## Chà vết bẩn dưới con trỏ: vết to nhỏ lại, chà lần nữa thì sạch.
func _scrub(at: Vector2) -> void:
	var c := _plate_center()
	for i in range(_spots.size() - 1, -1, -1):
		var s: Dictionary = _spots[i]
		if (c + s.pos).distance_to(at) <= float(s.r) + 6.0:
			s["hp"] = int(s.hp) - 1
			s["r"] = float(s.r) * 0.65
			if int(s.hp) <= 0:
				_spots.remove_at(i)
			_note.text = "Sạch rồi, xếp lên giá!" if _spots.is_empty() else ""
			_refresh()
			return


func _rack() -> void:
	if _state != "play":
		return
	if _spots.is_empty():
		_clean += 1
		_note.text = ""
	else:
		_mistakes += 1
		_note.text = "Bát còn bẩn, chủ quán trả lại! (lỗi %d)" % _mistakes
	_new_dish()


func _unhandled_key_input(event: InputEvent) -> void:
	if _state == "play" and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_rack()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	if _state != "play" or not is_instance_valid(_stats):
		return
	_stats.text = "Sạch %d/%d cái · lỗi %d · còn %d giây" % [_clean, int(cfg.target), _mistakes, ceili(maxf(0.0, _time_left))]
	_plate.queue_redraw()


func _process(delta: float) -> void:
	if _state != "play" or not is_instance_valid(_timer_bar):
		return
	_time_left -= delta
	_timer_bar.value = _time_left / float(cfg.seconds)
	_refresh()
	if _time_left <= 0.0:
		_show_end()
