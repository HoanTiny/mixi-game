extends Control
## Trò chơi nhỏ phụ hồ kiểu Nobody: bưng đúng loại gạch từ đống bỏ vào thùng cẩu.
## Đủ chỉ tiêu thùng thì đủ công, thiếu thì tính theo tỉ lệ; thùng nhiều gạch thưởng cao hơn.
## Phát finished(result): {"ratio", "bonus"} khi xong, {"auto": true, ...} nếu làm tự động, {} nếu bỏ.

const UI := preload("res://scripts/ui/ui_kit.gd")
const GameLogic := preload("res://scripts/game_logic.gd")

signal finished(result: Dictionary)

var cfg: Dictionary = {}
var last: Dictionary = {}
var title := "Phụ hồ"
var _box: VBoxContainer
var _state := "start"
var _time_left := 0.0
var _busy := 0.0
var _carry: Array[String] = []
var _crates: Array = []
var _filled := 0
var _bonus := 0
var _rng := RandomNumberGenerator.new()
# Ô giao diện cập nhật mỗi khung hình
var _timer_bar: ProgressBar
var _stats: Label
var _carry_row: HBoxContainer
var _crate_row: HBoxContainer
var _note: Label


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
	panel.custom_minimum_size = Vector2(860, 0)
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


# ---------------------------------------------------------------- màn mở đầu và kết quả

func _show_start() -> void:
	_state = "start"
	_clear()
	_box.add_child(UI.label(title.to_upper() + " · CÔNG TRÌNH", 12, UI.INK_SOFT))
	_box.add_child(UI.wrap("Bưng gạch bỏ vào thùng cẩu", 26, UI.INK, 800))
	_box.add_child(UI.wrap("Bấm đống gạch để bưng (tối đa %d viên), bấm thùng để đổ vào. Mỗi thùng chỉ nhận một loại gạch: bỏ nhầm là đổ bỏ. Đủ %d thùng trong %d giây thì đủ công; thùng càng nhiều gạch thưởng càng cao." % [int(cfg.carry), int(cfg.target), int(cfg.seconds)], 15, UI.INK, 800))
	_box.add_child(UI.choice("Tự làm", "Làm khéo thì được thưởng thêm", "", _start_play))
	if not last.is_empty():
		_box.add_child(UI.choice("Làm tự động", "Như lần trước: %d%% công · thưởng %s" % [int(float(last.ratio) * 100.0), GameLogic.fmt_k(int(last.bonus))], "",
			func() -> void: finished.emit({"ratio": float(last.ratio), "bonus": int(last.bonus), "auto": true})))
	_box.add_child(UI.choice("Thôi, không làm nữa", "", "", func() -> void: finished.emit({})))


func _show_end() -> void:
	_state = "end"
	_clear()
	var ratio := _ratio()
	_box.add_child(UI.label("HẾT CA", 12, UI.INK_SOFT))
	_box.add_child(UI.wrap("Đầy %d/%d thùng" % [_filled, int(cfg.target)], 26, UI.INK, 800))
	_box.add_child(UI.wrap("Được %d%% tiền công, thưởng thêm %s." % [int(ratio * 100.0), GameLogic.fmt_k(_bonus)] +
		("" if _filled >= int(cfg.target) else " Chưa đủ chỉ tiêu nên bị trừ công."), 15, UI.INK, 800))
	_box.add_child(UI.choice("Nhận tiền", "", "", func() -> void: finished.emit({"ratio": ratio, "bonus": _bonus})))


func _ratio() -> float:
	return clampf(float(_filled) / float(cfg.target), float(cfg.minRatio), 1.0)


# ---------------------------------------------------------------- màn chơi

func _start_play() -> void:
	_state = "play"
	_time_left = float(cfg.seconds)
	_carry.clear()
	_crates.clear()
	_filled = 0
	_bonus = 0
	for i in 3:
		_crates.append(_new_crate())
	_clear()
	var head := HBoxContainer.new()
	_box.add_child(head)
	var t := UI.label(title + " · bưng gạch", 20, UI.INK)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	_stats = UI.label("", 15, UI.INK)
	head.add_child(_stats)
	_timer_bar = UI.bar(10)
	_timer_bar.max_value = 1.0
	_box.add_child(_timer_bar)

	_box.add_child(UI.label("THÙNG CẨU (bấm để đổ gạch vào)", 11, UI.INK_SOFT))
	_crate_row = HBoxContainer.new()
	_crate_row.add_theme_constant_override("separation", 12)
	_box.add_child(_crate_row)
	_box.add_child(UI.label("ĐỐNG GẠCH (bấm để bưng)", 11, UI.INK_SOFT))
	var piles := HBoxContainer.new()
	piles.add_theme_constant_override("separation", 12)
	_box.add_child(piles)
	for k in cfg.types:
		piles.add_child(_pile_button(k))
	var carry_line := HBoxContainer.new()
	carry_line.add_theme_constant_override("separation", 8)
	_box.add_child(carry_line)
	carry_line.add_child(UI.label("Đang bưng:", 15, UI.INK))
	_carry_row = HBoxContainer.new()
	_carry_row.add_theme_constant_override("separation", 4)
	carry_line.add_child(_carry_row)
	_note = UI.label("", 14, UI.TIM)
	_box.add_child(_note)
	_refresh_play()


func _new_crate() -> Dictionary:
	var types: Array = cfg.types.keys()
	var need: int = cfg.sizes[_rng.randi() % cfg.sizes.size()]
	return {"type": types[_rng.randi() % types.size()], "need": need, "have": 0,
		"value": need * int(cfg.bonusPerBrick) + (need - 2) * int(cfg.bonusPerBrick)}


func _brick(type_key: String, w := 34.0, h := 16.0) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(cfg.types[type_key].color)
	r.custom_minimum_size = Vector2(w, h)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _pile_button(type_key: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(260, 110)
	b.pressed.connect(_pick.bind(type_key))
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.add_child(v)
	for row in 3:
		var h := HBoxContainer.new()
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.add_theme_constant_override("separation", 3)
		v.add_child(h)
		for i in 5 - row:
			h.add_child(_brick(type_key))
	var l := UI.label(str(cfg.types[type_key].name), 15, UI.INK)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l)
	return b


func _refresh_play() -> void:
	if _state != "play":
		return
	_stats.text = "Đầy %d/%d thùng · thưởng %s · còn %d giây" % [_filled, int(cfg.target), GameLogic.fmt_k(_bonus), ceili(_time_left)]
	for c in _carry_row.get_children():
		c.queue_free()
	for k in _carry:
		_carry_row.add_child(_brick(k, 40, 20))
	if _carry.is_empty():
		_carry_row.add_child(UI.label("(tay không)", 14, UI.INK_SOFT))
	for c in _crate_row.get_children():
		c.queue_free()
	for i in _crates.size():
		var cr: Dictionary = _crates[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(260, 120)
		b.pressed.connect(_drop.bind(i))
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		b.add_child(v)
		var name_l := UI.label("Cần %d %s" % [int(cr.need), str(cfg.types[cr.type].name).to_lower()], 15, UI.INK)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(name_l)
		var h := HBoxContainer.new()
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_theme_constant_override("separation", 4)
		v.add_child(h)
		for j in int(cr.need):
			var slot := _brick(cr.type, 40, 20)
			if j >= int(cr.have):
				slot.color = Color(slot.color, 0.18)
			h.add_child(slot)
		var val := UI.label("thưởng +" + GameLogic.fmt_k(int(cr.value)), 13, UI.GOOD)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(val)
		_crate_row.add_child(b)


## Bưng một viên gạch (mất một nhịp đi lại).
func _pick(type_key: String) -> void:
	if _state != "play" or _busy > 0.0:
		return
	if _carry.size() >= int(cfg.carry):
		_note.text = "Tay đầy rồi, đổ vào thùng đã."
		return
	_carry.append(type_key)
	_busy = float(cfg.stepSec)
	_note.text = ""
	_refresh_play()


## Đổ gạch đang bưng vào thùng i: đúng loại thì nhận, sai loại thì đổ bỏ.
func _drop(i: int) -> void:
	if _state != "play" or _busy > 0.0 or _carry.is_empty():
		return
	var cr: Dictionary = _crates[i]
	var wrong := 0
	var kept: Array[String] = []
	for k in _carry:
		if k == cr.type and int(cr.have) < int(cr.need):
			cr["have"] = int(cr.have) + 1
		elif k != cr.type:
			wrong += 1
		else:
			kept.append(k)
	_carry = kept
	_busy = float(cfg.stepSec)
	_note.text = ("Bỏ nhầm %d viên, phải đổ bỏ!" % wrong) if wrong > 0 else ""
	if int(cr.have) >= int(cr.need):
		_filled += 1
		_bonus += int(cr.value)
		_note.text = "Đầy thùng! Cần cẩu kéo lên, +" + GameLogic.fmt_k(int(cr.value))
		_crates[i] = _new_crate()
	_refresh_play()


func _process(delta: float) -> void:
	if _state != "play" or not is_instance_valid(_timer_bar):
		return
	_busy = maxf(0.0, _busy - delta)
	_time_left -= delta
	_timer_bar.value = _time_left / float(cfg.seconds)
	_stats.text = "Đầy %d/%d thùng · thưởng %s · còn %d giây" % [_filled, int(cfg.target), GameLogic.fmt_k(_bonus), ceili(maxf(0.0, _time_left))]
	if _time_left <= 0.0:
		_show_end()
