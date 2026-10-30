extends Control
## Màn livestream Shippy (tầng giao diện). Luật ở scripts/systems/commerce.gd: live_begin / live_beat / live_done; màn này
## chỉ dựng buổi (kịch bản, người chốt đơn, người đóng gói), đếm nhịp theo thời gian thật và gom thao tác của người chơi
## trong nhịp đó (voucher, deal chớp nhoáng, trả lời bình luận, đổi món) rồi đưa cho live_beat.
## Phát finished({"state": buổi live}) khi xong, {} nếu thôi trước khi lên sóng. Cùng kiểu với cảnh trò chơi nhỏ
## (hud.gd giữ trong biến minigame để chặn điều khiển phố).

signal finished(result: Dictionary)

const UI := preload("res://scripts/ui/ui_kit.gd")
const GameLogic := preload("res://scripts/game_logic.gd")
const Commerce := preload("res://scripts/systems/commerce.gd")

const LIVE_RED := Color("e0413a")
const NAMES := ["Thu Hà", "Minh Tú", "Lan Anh", "Quang", "Bích Ngọc", "Đức Anh", "Hồng Nhung", "Tuấn", "Mai Phương", "Hải Yến", "Khánh", "Ngân"]
const ASK := ["Shop ơi còn hàng không ạ?", "Giá bao nhiêu vậy shop?", "Ship về Hà Đông mấy ngày?", "Chất vải có nóng không?",
	"Cho xem lại mẫu đi shop", "Có freeship không ạ?", "Hàng có giống ảnh không?", "Mình ở Long Biên lấy trực tiếp được không?"]
const PEAK := ["Đông người xem ghê!", "Mã giảm giá đâu shop ơi", "Chốt cho em 2 cái", "Shop live vui quá", "Ai mua chung không?"]
const DOUBT := ["Hôm trước mua shop khác bị lỗi…", "Sao rẻ thế, hàng thật không?", "Đợi giảm thêm đã"]

var game
var _st: Dictionary = {}
var _phase := "setup"
var _script := "ke_chuyen"
var _closer := 0
var _packer := 0
var _t := 0.0
var _beat_sec := 5.0
var _inp := {}
var _rng := RandomNumberGenerator.new()
var _comments: Array[String] = []

var _box: VBoxContainer
var _viewers: Label
var _timer: ProgressBar
var _feed: VBoxContainer
var _product: Label
var _stats: Label
var _hint: Label
var _btns := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UI.make_theme()
	_rng.randomize()
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.035, 0.03, 0.86)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(Color(UI.CARD, 1.0), UI.LINE, 10, 18))
	panel.custom_minimum_size = Vector2(minf(720.0, get_viewport_rect().size.x - 24.0), 0)
	center.add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	panel.add_child(_box)
	var st: Dictionary = Commerce.biz(game).get("staff", {})
	_closer = int(st.get("closer", 0))
	_packer = int(st.get("packer", 0))
	_beat_sec = float(Commerce.data(game).live.get("seconds", 60)) / float(Commerce.data(game).live.get("beats", 12))
	_setup_screen()


func _clear() -> void:
	for c in _box.get_children():
		c.queue_free()
	_btns.clear()


# ---------------------------------------------------------------- màn dựng buổi

func _setup_screen() -> void:
	_clear()
	var lv: Dictionary = Commerce.data(game).live
	_box.add_child(UI.label("Lên sóng Shippy", 22, UI.INK))
	_box.add_child(UI.wrap("Uy tín shop %d · người xem tăng theo uy tín. Voucher dùng một lần, hiệu quả gấp đôi lúc đông người xem nhất. Deal chớp nhoáng chốt mạnh nhưng có thể nói hớ bị khóa kênh." % int(Commerce.biz(game).rep), 13, UI.INK_SOFT, 680))
	_box.add_child(UI.label("Kịch bản", 13, UI.TIM))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_box.add_child(row)
	for id in lv.scripts:
		var sc: Dictionary = lv.scripts[id]
		var b := Button.new()
		b.toggle_mode = true
		b.button_pressed = id == _script
		b.custom_minimum_size = Vector2(220, 96)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			_script = id
			_setup_screen())
		var v := VBoxContainer.new()
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
		b.add_child(v)
		v.add_child(UI.label(("● " if id == _script else "") + str(sc.name), 14, UI.GOLD if id == _script else UI.INK))
		var d := UI.wrap(str(sc.desc), 11, UI.INK_SOFT, 200)
		d.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(d)
		row.add_child(b)
	_box.add_child(UI.label("Người phụ (trả công sau buổi)", 13, UI.TIM))
	for role in ["closer", "packer"]:
		var info: Dictionary = lv.staff[role]
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 8)
		_box.add_child(r)
		var n: int = _closer if role == "closer" else _packer
		var name := UI.label("%s: %d" % [info.name, n], 14, UI.INK)
		name.custom_minimum_size.x = 190
		r.add_child(name)
		for step in [-1, 1]:
			var b := Button.new()
			b.text = "−" if step < 0 else "+"
			b.custom_minimum_size = Vector2(40, 34)
			b.disabled = (n + step) < 0 or (n + step) > int(info.max)
			b.pressed.connect(func() -> void:
				if role == "closer":
					_closer = clampi(_closer + step, 0, int(info.max))
				else:
					_packer = clampi(_packer + step, 0, int(info.max))
				Commerce.hire(game, role, _closer if role == "closer" else _packer)
				_setup_screen())
			r.add_child(b)
		r.add_child(UI.wrap("%s/người · %s" % [GameLogic.fmt_money(int(info.wage)), str(info.desc)], 11, UI.INK_SOFT, 380))
	var goods := []
	for gid in Commerce.live_goods(game):
		goods.append("%d %s" % [Commerce.qty(game, gid), str(Commerce.good(game, gid).name).to_lower()])
	_box.add_child(UI.wrap("Hàng bán live được: " + (", ".join(goods) if not goods.is_empty() else "không có"), 13, UI.INK_SOFT, 680))
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	_box.add_child(foot)
	var go := Button.new()
	go.text = "Lên sóng  (Space)"
	go.custom_minimum_size = Vector2(200, 44)
	go.add_theme_stylebox_override("normal", UI.box(LIVE_RED.darkened(0.15), LIVE_RED, 8, 10))
	go.add_theme_stylebox_override("hover", UI.box(LIVE_RED, LIVE_RED, 8, 10))
	go.disabled = goods.is_empty()
	go.pressed.connect(_start)
	foot.add_child(go)
	var cancel := Button.new()
	cancel.text = "Thôi  (Esc)"
	cancel.custom_minimum_size = Vector2(140, 44)
	cancel.pressed.connect(func() -> void: finished.emit({}))
	foot.add_child(cancel)


func _start() -> void:
	_st = Commerce.live_begin(game, _script, _closer, _packer)
	_phase = "live"
	_t = 0.0
	_inp = {}
	_comments.clear()
	_clear()
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	_box.add_child(top)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UI.box(LIVE_RED, LIVE_RED, 4, 4))
	badge.add_child(UI.label(" ● LIVE ", 13, Color.WHITE))
	top.add_child(badge)
	_viewers = UI.label("", 15, UI.INK)
	top.add_child(_viewers)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(sp)
	_stats = UI.label("", 14, UI.GOLD)
	top.add_child(_stats)
	_timer = ProgressBar.new()
	_timer.show_percentage = false
	_timer.custom_minimum_size.y = 6
	_timer.max_value = float(_st.beats)
	_box.add_child(_timer)
	_product = UI.label("", 16, UI.INK)
	_box.add_child(_product)
	var feed_panel := PanelContainer.new()
	feed_panel.add_theme_stylebox_override("panel", UI.box(UI.PAPER, UI.LINE, 6, 10))
	feed_panel.custom_minimum_size.y = 210
	_box.add_child(feed_panel)
	_feed = VBoxContainer.new()
	_feed.add_theme_constant_override("separation", 3)
	feed_panel.add_child(_feed)
	_hint = UI.label("", 13, UI.WARN)
	_box.add_child(_hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_box.add_child(row)
	for spec in [["voucher", "1 · Tung voucher"], ["flash", "2 · Deal chớp nhoáng"], ["reply", "3 · Trả lời bình luận"], ["swap", "4 · Đổi món"]]:
		var b := Button.new()
		b.text = spec[1]
		b.custom_minimum_size = Vector2(0, 46)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var key: String = spec[0]
		b.pressed.connect(func() -> void: _press(key))
		row.add_child(b)
		_btns[key] = b
	_say("Shippy", "Buổi live bắt đầu. Kịch bản: " + str(Commerce.data(game).live.scripts[_script].name))
	_update_view({"viewers": 0, "orders": 0, "peak": false})


func _press(key: String) -> void:
	if _phase != "live":
		return
	match key:
		"voucher":
			if not _st.voucher:
				_inp["voucher"] = true
				_btns.voucher.disabled = true
				_say("An", "Voucher giảm %d%% cho 2 phút tới, chốt nhanh kẻo hết!" % int(float(Commerce.data(game).live.voucher.discount) * 100.0))
		"flash":
			if int(_st.cooldown) <= 0 and not _inp.get("flash", false):
				_inp["flash"] = true
				_say("An", "Deal chớp nhoáng! 10 suất đầu tiên giá sốc!")
		"reply":
			if not _inp.get("reply", false):
				_inp["reply"] = true
				_say("An", "Có ạ, hàng thật ảnh thật, chị cứ hỏi thêm nhé!")
		"swap":
			var lg: Array = Commerce.live_goods(game)
			if lg.size() > 1:
				var i := lg.find(str(_st.featured))
				_st["featured"] = lg[(i + 1) % lg.size()]
				_say("An", "Giờ mình chuyển sang %s nhé!" % str(Commerce.good(game, str(_st.featured)).name).to_lower())
				_update_product()


func _say(who: String, text: String, color := Color(0, 0, 0, 0)) -> void:
	var l := UI.wrap("%s:  %s" % [who, text], 13, color if color.a > 0.0 else (UI.GOLD if who == "An" else UI.INK), 660)
	_feed.add_child(l)
	while _feed.get_child_count() > 9:
		var old := _feed.get_child(0)
		_feed.remove_child(old)
		old.queue_free()


func _update_product() -> void:
	var gid := str(_st.featured)
	if gid == "":
		_product.text = "Hết hàng để bán"
		return
	_product.text = "Đang giới thiệu: %s · %s · còn %d %s" % [str(Commerce.good(game, gid).name), GameLogic.fmt_money(Commerce.sell_price(game, gid, "cho")),
		Commerce.qty(game, gid), str(Commerce.good(game, gid).unit)]


func _update_view(res: Dictionary) -> void:
	_viewers.text = "👁 %d người xem" % int(res.get("viewers", 0))
	_stats.text = "%d đơn" % int(_st.total)
	_timer.value = float(_st.beat)
	_btns.flash.disabled = int(_st.cooldown) > 0
	_btns.flash.text = "2 · Deal chớp nhoáng" + ("" if int(_st.cooldown) <= 0 else " (%d)" % int(_st.cooldown))
	_btns.swap.disabled = Commerce.live_goods(game).size() < 2
	var hint := ""
	if res.get("peak", false):
		hint = "Người xem đang đông nhất: lúc tốt để tung voucher!"
	elif res.get("capped", false):
		hint = "Chốt đơn không xuể: thêm người chốt đơn ở buổi sau."
	_hint.text = hint
	_update_product()


func _process(delta: float) -> void:
	if _phase != "live":
		return
	_t += delta
	_timer.value = float(_st.beat) + clampf(_t / _beat_sec, 0.0, 1.0)
	if _t < _beat_sec:
		return
	_t = 0.0
	var res: Dictionary = Commerce.live_beat(game, _st, _inp)
	_inp = {}
	_comment(res)
	_update_view(res)
	if Commerce.live_done(_st):
		_end()


## Bình luận theo nhịp: hỏi giá, nghi ngờ, đông người lúc đỉnh, báo đơn mới.
func _comment(res: Dictionary) -> void:
	var n := 1 + int(res.viewers) / 40
	for i in mini(n, 3):
		var pool: Array = PEAK if res.peak else (DOUBT if _rng.randf() < 0.2 else ASK)
		_say(NAMES[_rng.randi() % NAMES.size()], pool[_rng.randi() % pool.size()], UI.INK_SOFT)
	if int(res.orders) > 0:
		_say("Shippy", "+%d đơn %s%s" % [int(res.orders), str(Commerce.good(game, str(res.good)).name).to_lower(), " (có voucher)" if res.voucher else ""], UI.GOOD)
	if res.banned:
		_say("Shippy", "Kênh bị tạm khóa: nội dung khuyến mãi gây hiểu lầm.", UI.STAMP)


func _end() -> void:
	_phase = "end"
	_clear()
	var lv: Dictionary = Commerce.data(game).live
	_box.add_child(UI.label("Tắt sóng" if not _st.banned else "Kênh bị khóa", 22, UI.INK if not _st.banned else UI.STAMP))
	var lines := []
	for gid in _st.orders:
		var o: Dictionary = _st.orders[gid]
		lines.append("%d %s · %s" % [int(o.qty), str(Commerce.good(game, gid).name).to_lower(), GameLogic.fmt_money(int(o.revenue))])
	var pack := int(lv.get("packerSolo", 10)) + _packer * int(lv.get("packerCap", 25))
	var body := "%d đơn chờ giao.\n%s\n\nĐóng gói được %d đơn%s. Tiền về sau %d ngày nếu khách nhận hàng; đơn bị hoàn mất phí ship hai chiều, hàng về kho." % [
		int(_st.total), "\n".join(lines), pack, (", %d đơn sẽ giao trễ (dễ bị hoàn hơn)" % (int(_st.total) - pack)) if int(_st.total) > pack else "",
		int(Commerce.data(game).returns.get("days", 2))]
	var wage := _closer * int(lv.staff.closer.wage) + _packer * int(lv.staff.packer.wage)
	if wage > 0:
		body += "\nTrả công người phụ: %s." % GameLogic.fmt_money(wage)
	_box.add_child(UI.wrap(body, 14, UI.INK_SOFT, 680))
	var done := Button.new()
	done.text = "Xong  (Space)"
	done.custom_minimum_size = Vector2(180, 44)
	done.pressed.connect(func() -> void: finished.emit({"state": _st}))
	_box.add_child(done)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	get_viewport().set_input_as_handled()
	match _phase:
		"setup":
			if event.keycode == KEY_SPACE and not Commerce.live_goods(game).is_empty():
				_start()
			elif event.keycode == KEY_ESCAPE:
				finished.emit({})
		"live":
			var keys := {KEY_1: "voucher", KEY_2: "flash", KEY_3: "reply", KEY_4: "swap"}
			if keys.has(event.keycode):
				_press(keys[event.keycode])
		"end":
			if event.keycode in [KEY_SPACE, KEY_ENTER]:
				finished.emit({"state": _st})
