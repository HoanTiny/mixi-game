extends Control
## Lớp hộp thoại ở giữa màn hình: mở đầu, sự kiện, buổi tối và kết thúc.
## Tự hiện khi trạng thái game cần người chơi chọn, tự ẩn khi không.

const GameLogic := preload("res://scripts/game_logic.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")

signal closed

var game
var night_open := false
var _box: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scrim := ColorRect.new()
	scrim.color = Color(0.05, 0.06, 0.12, 0.6)
	add_child(scrim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	panel.add_theme_stylebox_override("panel", UI.box(UI.CARD, UI.LINE, 12, 26))
	center.add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	panel.add_child(_box)
	game.changed.connect(refresh)
	refresh()


func open_night() -> void:
	night_open = true
	refresh()


## Đúng khi đang có hộp thoại che màn hình (cảnh 3D nên ngừng nhận chuột).
func is_blocking() -> bool:
	return visible


func refresh() -> void:
	for child in _box.get_children():
		child.queue_free()
	var show := true
	if not game.is_started():
		_start()
	elif game.is_over():
		_ending()
	elif not game.s.queue.is_empty():
		_event()
	elif night_open:
		_night()
	else:
		show = false
	if visible and not show:
		closed.emit()
	visible = show


func _start() -> void:
	var p: Dictionary = game.story.prologue
	_head(p.eyebrow, p.title, "", p.text, "")
	if not game.notes.is_empty():
		_box.add_child(UI.label("SỔ TAY TỪ LẦN TRƯỚC", 11, UI.INK_SOFT))
		for n in game.notes:
			_box.add_child(UI.wrap("• " + str(game.story.notes.get(n, n)), 14, UI.TIM))
	_box.add_child(UI.label("CHỌN MỘT MÓN MANG THEO", 11, UI.INK_SOFT))
	for k in game.story.items:
		var item: Dictionary = game.story.items[k]
		_box.add_child(UI.choice(item.name, item.desc, "", game.new_game.bind(k)))


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
	var shift: Dictionary = game.cfg.nightShift
	var lines := [
		"Ăn uống: %s  −%s" % [n.food_name, GameLogic.fmt_money(n.food_cost)],
		"Giờ còn trống (%s giờ): Sức khỏe +%s" % [GameLogic.num(n.free_hours), GameLogic.num(n.free_health)],
		"Ngủ: Sức khỏe +%d" % int(n.sleep_health),
		"Tinh thần cuối ngày: −%d" % int(n.mood_decay),
	]
	if n.milestone_tonight:
		lines.append("Tối nay xét mốc tiền %s. Tiền ăn được trừ trước, tiền bốc vác được cộng trước khi xét." % GameLogic.fmt_money(game.next_milestone().amount))
	_head("Ngày %d · %s" % [game.day(), GameLogic.hh(minf(game.clock(), 22.0))], "Tối nay làm gì?", "", "\n".join(lines), "")
	_box.add_child(UI.choice("Đi ngủ", "Sang ngày %d" % (game.day() + 1), "", _end_day.bind(false)))
	_box.add_child(UI.choice(shift.name, "+%s · Sức khỏe %d · Tinh thần %d" % [GameLogic.fmt_money(int(shift.pay)), int(shift.health), int(shift.mood)], "", _end_day.bind(true)))
	# Hết giờ thì không quay lại được nữa, chỉ còn ngủ hoặc làm ca đêm.
	if not game.is_out_of_time():
		_box.add_child(UI.choice("Quay lại", "Tiếp tục ngày %d" % game.day(), "", _cancel_night))


func _ending() -> void:
	var over: Dictionary = game.s.over
	var e: Dictionary = game.story.endings[over.key]
	_box.add_child(UI.label(str(e.tag).to_upper(), 12, UI.GOOD if e.good else UI.STAMP))
	_head("", e.title, "", e.text, e.get("quote", ""))
	var s: Dictionary = game.s
	var lines := []
	if over.key == "game_over":
		lines.append("Còn thiếu: " + GameLogic.fmt_money(int(over.short)))
	lines.append("Tiền còn lại: " + GameLogic.fmt_money(int(s.money)))
	lines.append("Tổng đã kiếm: %s · Tổng đã chi: %s" % [GameLogic.fmt_money(int(s.stats.earned)), GameLogic.fmt_money(int(s.stats.spent))])
	var skills := []
	for k in GameLogic.SKILLS:
		skills.append("%s %d" % [GameLogic.SKILLS[k], game.level(k)])
	lines.append(" · ".join(skills))
	_box.add_child(UI.wrap("\n".join(lines), 14, UI.INK_SOFT))
	if not over.new_notes.is_empty():
		_box.add_child(UI.label("SỔ TAY GHI THÊM", 11, UI.INK_SOFT))
		for n in over.new_notes:
			_box.add_child(UI.wrap("• " + str(game.story.notes.get(n, n)), 14, UI.TIM))
	_box.add_child(UI.choice("Chơi lại từ ngày 0", "", "", GameState.restart))
	_box.add_child(UI.choice("Sao chép kết quả lượt chơi", "Dán vào chat để phân tích cân bằng", "", func() -> void: DisplayServer.clipboard_set(game.summary())))


func _head(eyebrow: String, title: String, who: String, text: String, quote: String) -> void:
	if eyebrow != "":
		_box.add_child(UI.label(eyebrow.to_upper(), 11, UI.INK_SOFT))
	_box.add_child(UI.wrap(title, 26, UI.INK))
	if who != "":
		_box.add_child(UI.label(who, 14, UI.TIM))
	if text != "":
		_box.add_child(UI.wrap(text, 15, UI.INK))
	if quote != "":
		_box.add_child(UI.wrap(quote, 18, UI.TIM))


func _end_day(shift: bool) -> void:
	night_open = false
	game.finish_day(shift)


func _cancel_night() -> void:
	night_open = false
	refresh()
