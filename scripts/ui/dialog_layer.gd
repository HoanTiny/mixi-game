extends Control
## Lớp hộp thoại ở giữa màn hình: mở đầu, sự kiện, buổi tối, màn kết 30 ngày và tổng kết lát cắt.
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
	var scroll := ScrollContainer.new()
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
	game.changed.connect(refresh)
	refresh()


func open_night() -> void:
	night_open = true
	refresh()


func refresh() -> void:
	for child in _box.get_children():
		child.queue_free()
	var show := true
	if not game.is_started():
		_start()
	elif game.is_over():
		if str(game.s.over.get("kind", "")) == "full":
			_ending()
		else:
			_report()
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
	_head(p.eyebrow, p.title, "", p.text, p.quote)
	_box.add_child(UI.choice(p.start, "30 ngày · 1.200.000đ tiền mặt · 3.600.000đ lương cũ còn phải thu", "", game.new_game.bind("full")))
	_box.add_child(UI.label(p.slicePick, 11, UI.INK_SOFT))
	for k in GameLogic.ROUTES:
		var pre: Dictionary = game.cfg.presets[k]
		_box.add_child(UI.choice(pre.name, pre.desc, "", game.new_game.bind(k)))


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
	var lines := [
		"Sinh hoạt cả nhà: −%s" % GameLogic.fmt_money(n.living),
		"Ngủ và %s giờ còn trống: Mệt −%d" % [GameLogic.num(n.free_hours), int(n.recover)],
	]
	if int(n.due_pay) > 0:
		lines.append("Đến hạn trả tối nay: %s" % GameLogic.fmt_money(n.due_pay))
	for label in n.due_recv:
		lines.append("Đến hạn nhận: %s" % label)
	if game.fatigue_warn() and not game.s.today.get("rested", false):
		lines.append("Mệt đang ở mức cảnh báo mà hôm nay chưa nghỉ.")
	if n.slice_end:
		lines.append("Đây là đêm cuối của lát cắt. Sau đêm nay sẽ có bảng tổng kết.")
	_head("Ngày %d · %s" % [game.day(), GameLogic.hh(minf(game.clock(), 22.0))], "Đi ngủ?", "", "\n".join(lines), "")
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
	_head("", e.title, "", e.text, e.quote)
	_box.add_child(UI.wrap(e.epilogue, 14, UI.INK_SOFT))
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
	var npc: Dictionary = over.get("npc", {})
	if not npc.is_empty():
		var card: Dictionary = game.story.npcCards[npc.who]
		_box.add_child(UI.label(game.rep_name(npc.who).to_upper(), 11, UI.INK_SOFT))
		_box.add_child(UI.wrap(str(card.good if npc.good else card.bad), 14, UI.INK))
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
	_box.add_child(UI.choice("Chơi lại từ ngày 1", "", "", GameState.restart))
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
		_box.add_child(UI.wrap(quote, 17, UI.TIM))


func _end_day() -> void:
	night_open = false
	game.finish_day()


func _cancel_night() -> void:
	night_open = false
	refresh()
