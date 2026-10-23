extends Control
## Lớp hộp thoại ở giữa màn hình: mở đầu, sự kiện, buổi tối, màn kết 30 ngày (có nút chơi tiếp chương 2),
## màn kết chương 2 và tổng kết lát cắt.
## Tự hiện khi trạng thái game cần người chơi chọn, tự ẩn khi không.

const GameLogic := preload("res://scripts/game_logic.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")

signal closed

var game
var night_open := false
var _box: VBoxContainer
var _diary_open := false


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
		match str(game.s.over.get("kind", "")):
			"full":
				_ending()
			"full2":
				_ending2()
			"full3":
				_ending3()
			_:
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
	if not game.story2.is_empty():
		var more := "Hết ngày 30 có nút Chơi tiếp sang %s: thêm 30 ngày ở chỗ mới, mọi lựa chọn của tháng đầu đi theo." % \
			str(game.story2.get("title", "Chương 2 · Mùa mưa"))
		if not game.story3.is_empty():
			more += " Hết ngày 60 chơi tiếp %s (ngày 61–90)." % str(game.story3.get("title", "Chương 3"))
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
	var cards := []
	for c in game.story3.get("cards", []):
		cards.append([str(c.title), c.get("items", {}), str(c.id)])
	_ending_chapter(cards, "TRONG TIỆM VÀ TRONG NHÀ", "SỔ TAY BA THÁNG")


## cards: [nhãn, bảng thẻ (tên khóa trong story của chương, hay chính bảng thẻ), khóa trong s.over (chương 3: s.over.cards)].
func _ending_chapter(cards: Array, keep_label: String, diary_label: String) -> void:
	var ch: int = game.chapter()
	var last: int = game.last_day()
	var over: Dictionary = game.s.over
	var st: Dictionary = game.chapter_story()
	# Kết có thể có biến thể (K3 ở sạp chung với Kha hay trước hiên nhà, L3 theo người góp tiệm).
	var e: Dictionary = game._merge_variants(st.endings[over.key])
	_box.add_child(UI.label("CHƯƠNG %d · %s · %s" % [ch, str(over.key), str(e.tag).to_upper()], 12, UI.TIM))
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
		place = "%s (đã đặt cọc, %s)" % [place, "dọn sau giỗ" if ch == 2 else "dọn mùng một tháng Tám"]
	elif h.place == "di_nam":
		place = "Ở nhờ nhà dì Năm"
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
		_box.add_child(UI.label("NẾU CÂU CHUYỆN DỪNG Ở ĐÂY", 11, UI.INK_SOFT))
		_box.add_child(UI.wrap(game.fill(str(e.epilogue)), 14, UI.INK_SOFT))
		_box.add_child(UI.choice("Chơi tiếp: " + str(nxt.get("title", "Chương %d" % (game.chapter() + 1))), str(nxt.get("continue", "")), "",
			game.continue_chapter))
	else:
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
