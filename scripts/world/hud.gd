extends CanvasLayer
## Giao diện đè lên màn phố: bảng mục tiêu góc trái (giống Nobody), trạng thái góc phải,
## bảng địa điểm khi bước vào một cửa tiệm, thanh công cụ dưới cùng và các hộp thoại.
## Bố cục dùng container lồng nhau; mọi container trong suốt với chuột để bấm xuyên xuống cảnh 3D.

const GameLogic := preload("res://scripts/game_logic.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")
const DialogLayer := preload("res://scripts/ui/dialog_layer.gd")
const StreetMap := preload("res://scripts/world/street_map.gd")
## Trò chơi nhỏ theo trường minigame của việc trong config.json.
const MINIGAMES := {
	"bricks": preload("res://scripts/ui/minigame_bricks.gd"),
	"dishes": preload("res://scripts/ui/minigame_dishes.gd"),
}

var world
var game
## Trò chơi nhỏ đang mở (phụ hồ bưng gạch), null nếu không có.
var minigame: Control
var dialogs: DialogLayer

var _objectives: PanelContainer
var _map: Control
var _big_map: Control
var _loc_scroll: ScrollContainer
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
var _location: PanelContainer
var _loc_title: Label
var _loc_desc: Label
var _loc_cards: VBoxContainer
## Sổ: phải thu, phải trả, lời hứa, sổ gia đình, thân thiết và đồ đang mang.
var _skills: PanelContainer
var _skills_text: RichTextLabel
var _log: PanelContainer
var _log_text: RichTextLabel
var _bottom: PanelContainer
var _end_day_btn: Button
var _work: PanelContainer
var _pd_label: Label
var _pd_bar: ProgressBar
var _needs_label: Label
var _phone: PanelContainer
var _phone_box: VBoxContainer
var _order_strip: PanelContainer
var _order_label: Label
var _app_on := false
var _offer: Dictionary = {}
var _offer_left := 0.0
var _offer_wait := 3.0
var _phone_tick := 0.0
var _work_title: Label
var _work_clock: Label
var _work_bar: ProgressBar
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

	# Hàng trên: mục tiêu bên trái, trạng thái bên phải.
	var top := _pass(HBoxContainer.new(), rows)
	_build_objectives(top)
	_spacer(top)
	_map = StreetMap.new()
	_map.world = world
	top.add_child(_map)
	_spacer(top)
	_build_status(top)

	# Hàng giữa: kỹ năng / nhật ký bên trái, bảng địa điểm bên phải.
	var middle := _pass(HBoxContainer.new(), rows)
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := _pass(VBoxContainer.new(), middle)
	_build_tip(left)
	_build_skills(left)
	_build_log(left)
	_build_phone(left)
	_spacer(middle)
	_build_location(middle)

	# Lời nhắc tương tác và thanh "đang làm" ở giữa, phía trên thanh công cụ.
	var prompt_row := _pass(HBoxContainer.new(), rows)
	prompt_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_build_prompt(prompt_row)
	_build_work(prompt_row)
	_build_order_strip(prompt_row)

	# Hàng dưới: hướng dẫn điều khiển bên trái, thanh công cụ bên phải.
	var bottom := _pass(HBoxContainer.new(), rows)
	var hint := UI.label("Chuột trái: đi tới chỗ bấm · Con lăn: gần xa · Bấm cửa tiệm hoặc người: tương tác · WASD: đi · E: vào · M: bản đồ · Esc: đóng", 12, UI.HUD_TEXT)
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	hint.add_theme_constant_override("outline_size", 5)
	hint.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.add_child(hint)
	_spacer(bottom)
	_build_bottom(bottom)

	# Bản đồ lớn phủ giữa màn hình (phím M hoặc bấm bản nhỏ).
	_big_map = StreetMap.new()
	_big_map.world = world
	_big_map.big = true
	root.add_child(_big_map)
	_map.other = _big_map

	dialogs = DialogLayer.new()
	dialogs.game = game
	root.add_child(dialogs)
	dialogs.closed.connect(_refresh)
	game.changed.connect(_refresh)
	_refresh()


# ---------------------------------------------------------------- API cho world.gd

func blocking() -> bool:
	return dialogs.visible or _working or minigame != null or (_big_map != null and _big_map.visible)


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
	if id.begins_with("bin:"):
		var lock: String = game.scrap_lock(id.substr(4))
		_prompt_label.text = "E  ·  Lục thùng rác tìm ve chai" if lock == "" else "Thùng rác · " + lock
	elif id != "":
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
	# Hai cột tiền: tiền mặt tiêu được, và tiền phải thu / phải trả không cộng chung.
	_cash_label = UI.label("", 26, UI.GOLD)
	v.add_child(_cash_label)
	_recv_label = UI.label("", 12, UI.HUD_SOFT)
	v.add_child(_recv_label)
	_fatigue_label = UI.label("", 12, UI.HUD_SOFT)
	v.add_child(_fatigue_label)
	_fatigue_bar = UI.bar(8)
	v.add_child(_fatigue_bar)
	_pd_label = UI.label("", 12, UI.HUD_SOFT)
	v.add_child(_pd_label)
	_pd_bar = UI.bar(8)
	v.add_child(_pd_bar)
	_needs_label = UI.label("", 12, UI.HUD_SOFT)
	v.add_child(_needs_label)


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
	_work_bar.max_value = 1.0
	_work_bar.add_theme_stylebox_override("fill", UI.box(UI.GOLD, UI.GOLD, 5, 0))
	v.add_child(_work_bar)
	_work.visible = false


## Làm một việc ở tiệm: An vào trong, thanh thời gian chạy, đồng hồ nhảy dần, xong mới tính kết quả.
## result: kết quả trò chơi nhỏ (tự làm hoặc làm tự động); việc có minigame mà chưa có kết quả thì mở trò chơi trước.
func _perform(id: String, result: Dictionary = {}) -> void:
	var a: Dictionary = game.get_action(id)
	var st: Dictionary = game.action_status(a)
	if not st.ok or _working or minigame != null:
		return
	if a.has("minigame") and result.is_empty():
		_open_minigame(id, a)
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
		world.audio.play("done")
		game.do_action(id, result))


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
	scroll.custom_minimum_size = Vector2(336, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_loc_scroll = scroll
	_loc_cards = VBoxContainer.new()
	_loc_cards.add_theme_constant_override("separation", 8)
	scroll.add_child(_loc_cards)
	var leave := Button.new()
	leave.text = "Rời đi"
	leave.pressed.connect(close_location)
	v.add_child(leave)
	_location.visible = false


func _build_skills(parent: Control) -> void:
	_skills = _light_panel(parent)
	var v := VBoxContainer.new()
	_skills.add_child(v)
	v.add_child(UI.label("SỔ: PHẢI THU · PHẢI TRẢ · LỜI HỨA · GIA ĐÌNH", 11, UI.INK_SOFT))
	_skills_text = RichTextLabel.new()
	_skills_text.bbcode_enabled = true
	_skills_text.custom_minimum_size = Vector2(400, 420)
	_skills_text.add_theme_font_size_override("normal_font_size", 13)
	_skills_text.add_theme_font_size_override("bold_font_size", 14)
	v.add_child(_skills_text)
	_skills.visible = false


## Mở trò chơi nhỏ của việc; xong thì chạy thanh thời gian như mọi việc khác với kết quả vừa chơi.
func _open_minigame(id: String, a: Dictionary) -> void:
	minigame = MINIGAMES[a.minigame].new()
	minigame.cfg = game.cfg.minigames[a.minigame]
	minigame.last = game.s.get("job_last", {}).get(id, {})
	minigame.title = str(a.name)
	minigame.finished.connect(func(r: Dictionary) -> void:
		minigame.queue_free()
		minigame = null
		if not r.is_empty():
			_perform(id, r))
	add_child(minigame)
	_refresh()


# ---------------------------------------------------------------- điện thoại: app giao hàng

func _build_phone(parent: Control) -> void:
	_phone = _light_panel(parent)
	_phone.custom_minimum_size = Vector2(330, 0)
	_phone_box = VBoxContainer.new()
	_phone_box.add_theme_constant_override("separation", 8)
	_phone.add_child(_phone_box)
	_phone.visible = false


func _build_order_strip(parent: Control) -> void:
	_order_strip = _dark_panel(parent)
	_order_label = UI.label("", 15, UI.HUD_TEXT)
	_order_strip.add_child(_order_label)
	_order_strip.visible = false


func _process(delta: float) -> void:
	if not game.is_started() or game.is_over():
		return
	var active: Dictionary = game.delivery_active()
	# Đơn mới tới khi app đang bật, rảnh tay và không có hộp thoại.
	if _app_on and active.is_empty() and _offer.is_empty() and not blocking():
		_offer_wait -= delta
		if _offer_wait <= 0.0:
			_new_offer()
	if not _offer.is_empty():
		_offer_left -= delta
		if _offer_left <= 0.0:
			_offer = {}
			_refresh_phone()
	_phone_tick -= delta
	if _phone_tick <= 0.0:
		_phone_tick = 0.25
		_warn_needs()
		_update_tip(0.25)
		_update_order_strip(active)
		if _phone.visible:
			_refresh_phone()


## Nhắc một lần mỗi ngày khi đói hay bẩn quá, để người chơi kịp xử lý trước khi mất Sức khỏe.
var _warned := {}


func _warn_needs() -> void:
	if not game.has_needs() or blocking():
		return
	for w in [["fed", 20.0, "Bụng đói cồn cào, đi ăn thôi!"], ["clean", 15.0, "Người bốc mùi, về phòng tắm đi"], ["neat", 15.0, "Quần áo dơ quá, phải giặt"]]:
		var key := "%s_%d" % [w[0], game.day()]
		if game.need(w[0]) < float(w[1]) and not _warned.has(key):
			_warned[key] = true
			world._float_text(str(w[2]), Color("ffb27a"))


func _new_offer() -> void:
	var d: Dictionary = game.cfg.delivery
	var r: Array = d.offerSec if game.delivery_rush() else d.offPeakSec
	_offer_wait = randf_range(float(r[0]), float(r[1]))
	if game.delivery_lock() != "":
		return
	_offer = world.make_offer()
	if _offer.is_empty():
		return
	_offer_left = 12.0
	_phone.visible = true
	_skills.visible = false
	_log.visible = false
	world.audio.play("dialog")
	_refresh_phone()


func _minutes_left(o: Dictionary) -> int:
	return int(round((float(o.deadline) - game.clock()) * 60.0))


func _update_order_strip(o: Dictionary) -> void:
	_order_strip.visible = not o.is_empty() and not _working
	if o.is_empty():
		return
	var left := _minutes_left(o)
	var where: String = ("Lấy %s ở %s" % [o.item, o.shop_name]) if not o.picked else ("Giao tới %s" % o.dest)
	_order_label.text = "Đơn: %s · %s" % [where, ("còn %d phút" % left) if left >= 0 else ("trễ %d phút" % -left)]
	_order_label.add_theme_color_override("font_color", UI.HUD_TEXT if left >= 10 else (UI.GOLD if left >= 0 else Color("ff8a7a")))


func _refresh_phone() -> void:
	if not _phone.visible:
		return
	for c in _phone_box.get_children():
		c.queue_free()
	_phone_box.add_child(UI.label("App Giao Nhanh", 20, UI.INK))
	var lock: String = game.delivery_lock()
	var rush: bool = game.delivery_rush()
	_phone_box.add_child(UI.wrap(("Giờ cao điểm: đơn nhiều." if rush else "Ngoài giờ cao điểm (10:00–13:30, 17:00–21:00): ít đơn.")
		+ " Đã giao hôm nay: %d đơn." % game.today_count("giao_hang"), 13, UI.INK_SOFT, 300))
	var o: Dictionary = game.delivery_active()
	if not o.is_empty():
		var left := _minutes_left(o)
		_phone_box.add_child(UI.label("ĐƠN ĐANG GIAO", 11, UI.INK_SOFT))
		_phone_box.add_child(UI.wrap("%s\nLấy ở: %s%s\nGiao tới: %s\nTiền công: %s · hạn %s (%s)" % [o.item, o.shop_name, " ✓" if o.picked else "",
			o.dest, GameLogic.fmt_k(int(o.pay)), GameLogic.hh(float(o.deadline)), ("còn %d phút" % left) if left >= 0 else "đã trễ"], 14, UI.INK, 300))
		_phone_box.add_child(UI.choice("Hủy đơn", "Khách đánh giá 1 sao · Tinh thần %d" % int(game.cfg.delivery.cancelMood), "", func() -> void:
			game.delivery_cancel()
			_refresh_phone()))
	elif not _offer.is_empty():
		_phone_box.add_child(UI.label("ĐƠN MỚI · tự hủy sau %d giây" % ceili(_offer_left), 11, UI.TIM))
		_phone_box.add_child(UI.wrap("%s\nLấy ở: %s\nGiao tới: %s\nTiền công: %s · giao trước %s" % [_offer.item, _offer.shop_name, _offer.dest,
			GameLogic.fmt_k(int(_offer.pay)), GameLogic.hh(float(_offer.deadline))], 14, UI.INK, 300))
		_phone_box.add_child(UI.choice("Nhận đơn", "Mũi tên cam chỉ quán, xanh chỉ nhà khách", "", func() -> void:
			game.delivery_accept(_offer)
			_offer = {}
			_refresh_phone()))
		_phone_box.add_child(UI.choice("Bỏ qua", "", "", func() -> void:
			_offer = {}
			_refresh_phone()))
	_phone_box.add_child(UI.choice("Tắt nhận đơn" if _app_on else "Bật nhận đơn",
		"Đang chờ đơn…" if _app_on and o.is_empty() and _offer.is_empty() else "", lock, func() -> void:
			_app_on = not _app_on
			_offer = {}
			_offer_wait = 2.0
			_refresh_phone()))
	_phone_box.add_child(UI.choice("Cất điện thoại", "", "", func() -> void: _phone.visible = false))


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
	h.add_child(_tool_button("Điện thoại", func() -> void:
		_phone.visible = not _phone.visible
		_skills.visible = false
		_log.visible = false
		_refresh_phone()))
	h.add_child(_tool_button("Sổ", func() -> void:
		_skills.visible = not _skills.visible
		_log.visible = false))
	h.add_child(_tool_button("Nhật ký", func() -> void:
		_log.visible = not _log.visible
		_skills.visible = false))
	h.add_child(_tool_button("Bảng cân bằng", func() -> void: get_tree().change_scene_to_file("res://scenes/board.tscn")))
	_end_day_btn = _tool_button("Về xóm trọ", func() -> void:
		close_location()
		world.walk_to_location(world.home))
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
	for p in [_objectives, _status, _bottom, _map]:
		p.visible = started
	if not started:
		_loc_id = ""
		_location.visible = false
		_tip.visible = false
		_tip_id = ""
		_update_prompt()
		return
	var s: Dictionary = game.s
	_refresh_objectives(s)
	_day_label.text = "Ngày %d/30 · %s" % [game.day(), game.weekday_name()]
	_clock_label.text = "%s  ·  còn %s giờ trong ngày" % [GameLogic.hh(minf(game.clock(), 22.0)), GameLogic.num(game.hours_left())]
	_cash_label.text = GameLogic.fmt_money(int(s.cash))
	_recv_label.text = "Phải thu: %s trước ngày 30 · %s sau\nPhải trả: %s" % [
		GameLogic.fmt_k(game.receivable_sum(0, 30)), GameLogic.fmt_k(game.receivable_sum(31, 999)), GameLogic.fmt_k(game.payable_sum(999))]
	var warn := float(game.cfg.fatigue.warn)
	_fatigue_label.text = "Mệt %d/100%s" % [int(s.fatigue), "  · cần nghỉ" if game.fatigue_warn() else ""]
	UI.set_bar(_fatigue_bar, float(s.fatigue), 100.0, UI.STAMP if float(s.fatigue) >= warn else (UI.WARN if float(s.fatigue) >= warn - 20 else UI.GOOD))
	var needs: bool = game.has_needs()
	for c in [_pd_label, _pd_bar, _needs_label]:
		c.visible = needs
	if needs:
		var pd: float = game.phong_do()
		var mult: float = game.pay_mult()
		_pd_label.text = "Phong độ %d · %s" % [int(pd), "đủ lương" if mult >= 1.0 else "chỉ được %d%% lương" % int(mult * 100.0)]
		UI.set_bar(_pd_bar, pd, 100.0, UI.level_color(pd / 100.0))
		_needs_label.text = "No bụng %d · Vệ sinh %d · Quần áo %d" % [int(game.need("fed")), int(game.need("clean")), int(game.need("neat"))]
		var worst := minf(game.need("fed"), minf(game.need("clean"), game.need("neat")))
		_needs_label.add_theme_color_override("font_color", UI.HUD_SOFT if worst >= 35.0 else (UI.GOLD if worst >= 15.0 else Color("ff8a7a")))
	_end_day_btn.disabled = game.is_over() or not s.queue.is_empty() or _working
	_refresh_skills(s)
	_log_text.text = UI.log_bbcode(game)
	_refresh_location()
	_update_prompt()


func _update_prompt() -> void:
	_prompt.visible = game.is_started() and _prompt_id != "" and _prompt_id != "-" and _loc_id == "" and not blocking()


func _refresh_objectives(s: Dictionary) -> void:
	for c in _objective_box.get_children():
		c.queue_free()
	# Cảnh chính hôm nay: đi tới đúng nơi, đúng khung giờ (dấu ◆ vàng trên phố).
	for id in game.scenes_today():
		var e: Dictionary = game.scene_info(id)
		var where := str(world.location_info(str(e.loc)).name)
		if e.has("window"):
			where += " · %s–%s" % [GameLogic.hh(float(e.window[0])), GameLogic.hh(float(e.window[1]))]
		_objective("Hôm nay: " + game.fill(str(e.title)), "Tới " + where, "current")
	var deadline := int(game.cfg.housingDeadline)
	var h: Dictionary = game.housing()
	if h.state == "signed":
		_objective("Chỗ ở: " + str(game.cfg.housing[h.place].name), "Đã chốt" + (" · ở tạm, hẹn tìm tiếp" if game.cfg.housing[h.place].get("temp", false) else ""), "done")
	else:
		var proj: int = game.projected_cash(deadline)
		var best: String = game.best_housing(proj)
		var sub := "Không kiếm thêm thì sáng ngày %d còn %s" % [deadline, GameLogic.fmt_money(proj)]
		sub += " · chưa đủ cả chỗ ở tạm" if best == "" else " · đủ cho %s" % game.cfg.housing[best].name
		# Mốc kế tiếp: chỗ rẻ nhất mà chưa đủ tiền, để người chơi biết còn thiếu bao nhiêu.
		var next := ""
		for k in game.cfg.housing:
			var c := int(game.cfg.housing[k].cost)
			if c > proj and (next == "" or c < int(game.cfg.housing[next].cost)):
				next = k
		if next != "":
			sub += " · thiếu %s cho %s" % [GameLogic.fmt_money(int(game.cfg.housing[next].cost) - proj), game.cfg.housing[next].name]
		if h.state == "reserved":
			sub = "Đã cọc giữ %s, còn thiếu %s · " % [game.cfg.housing[h.place].name, GameLogic.fmt_money(game.housing_cost(h.place))] + sub
		_objective("Ngày %d chốt chỗ ở" % deadline, sub, "current" if game.day() >= 20 else "normal")
	if game.is_full():
		for r in s.receivables:
			if str(r.id).begins_with("luong_cu") and r.status == "pending":
				_objective("Lương cũ: %s" % GameLogic.fmt_money(int(r.amount)), "chưa hẹn ngày trả" if int(r.due) > 90 else "hẹn ngày %d" % int(r.due), "normal")
	if s.route in ["B", "C"]:
		var mid = null
		for r in s.receivables:
			if r.id == "hd_giua":
				mid = r
		var state := "normal"
		if mid != null and mid.status == "collected":
			state = "done"
		elif game.day() > 20:
			state = "failed"
		else:
			state = "current"
		var final_open := false
		for p in s.promises:
			if p.id == "ban_giao_cuoi" and p.status == "open":
				final_open = true
		if final_open:
			_objective("Bàn giao giai đoạn cuối Bến Cạn trước tối ngày 27", "Tiến độ %d/%d buổi" % [int(s.progress), int(s.progress_need)], "current")
		elif game.day() <= 22:
			var sub := "Tiến độ %d/%d buổi" % [int(s.progress), int(s.progress_need)]
			if state == "current" and int(s.progress) >= int(s.progress_need):
				sub += " · đủ rồi; làm thêm thì tính cho giai đoạn cuối"
			_objective("Nghiệm thu đợt giữa Bến Cạn tối ngày 20", sub, state)
	if game.day() <= 22:
		var linh_state := "done" if s.linh.decision != "" else ("current" if game.day() >= 19 else "normal")
		_objective("Nghe Linh nói về chỗ thực tập (ngày 22)", "Quyết định là của Linh", linh_state)
	var due_today := 0
	for p in s.promises:
		if p.status == "open" and int(p.due) == game.day():
			due_today += 1
	if due_today > 0:
		_objective("Lời hứa đến hạn hôm nay: %d" % due_today, "Mở Sổ để xem", "current")
	_objective("Trả chìa khóa phòng cũ cho cô Duyên ngày 30", "", "normal")
	var active: Array = game.quests_active()
	if not active.is_empty():
		_objective_box.add_child(UI.label("Việc nhờ đang làm", 14, Color("9fc4ff")))
	for id in active:
		var st: Dictionary = game.s.quests[id]
		var urgent: bool = st.has("step_deadline") or float(st.deadline) - game.now_abs() < 3.0
		_objective_box.add_child(UI.label("★  %s · %s" % [game.quest_def(id).title, game.quest_deadline_text(id)], 14, Color("ffb27a") if urgent else Color("9fc4ff")))
		var l := UI.label("     " + game.quest_progress_text(id), 12, UI.HUD_SOFT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(360, 0)
		_objective_box.add_child(l)
	var offers: Array = game.quest_offers()
	if not offers.is_empty():
		var who := []
		for q in offers:
			who.append(str(q.who))
		var l := UI.label("!  Có người cần giúp: " + ", ".join(who) + " (tìm dấu ! trên phố)", 12, UI.GOLD)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(360, 0)
		_objective_box.add_child(l)


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


func _refresh_skills(s: Dictionary) -> void:
	var lines := [UI.ledger_bbcode(game), "", "[b]Thân thiết[/b]"]
	var reps := []
	for k in game.story.reps:
		reps.append("%s %d" % [game.rep_name(k), int(s.rep.get(k, 0))])
	lines.append(" · ".join(reps))
	var inv := []
	for k in s.get("inv", {}):
		if int(s.inv[k]) > 0:
			inv.append("%d %s" % [int(s.inv[k]), game.cfg.scrap[k].name])
	if not inv.is_empty():
		lines.append("")
		lines.append("[b]Ve chai[/b]: %s (≈ %s)" % [", ".join(inv), GameLogic.fmt_k(game.scrap_value())])
	var carry := []
	for k in s.get("qitems", {}):
		carry.append(game.item_name(k))
	if not carry.is_empty():
		lines.append("[b]Đang mang[/b]: " + ", ".join(carry))
	var keep := []
	for k in game.keepsakes():
		keep.append(str(k.name))
	if not keep.is_empty():
		lines.append("")
		lines.append("[b]Đồ muốn mang theo[/b]: " + ", ".join(keep))
	# Sổ tay: vài dòng gần nhất, mới nhất ở trên.
	var diary: Array = s.get("diary", [])
	if not diary.is_empty():
		lines.append("")
		lines.append("[b]Sổ tay của An[/b]")
		for i in range(diary.size() - 1, maxi(-1, diary.size() - 7), -1):
			lines.append("[color=#6a3db8]Ngày %d[/color] · %s" % [int(diary[i].day), diary[i].text])
	_skills_text.text = "\n".join(lines)


func _refresh_location() -> void:
	# Đang làm thì An ở trong tiệm, giấu bảng cho tới khi xong việc.
	_location.visible = _loc_id != "" and not game.is_over() and not _working
	if not _location.visible:
		return
	var loc: Dictionary = world.location_info(_loc_id)
	_loc_title.text = loc.name
	_loc_desc.text = loc.desc
	for c in _loc_cards.get_children():
		c.queue_free()
	var found := 0
	if _loc_id == world.home:
		var n: Dictionary = game.night_preview()
		_loc_cards.add_child(UI.choice("Đi ngủ", "Kết thúc ngày %d · Mệt −%d qua đêm" % [game.day(), int(n.recover)],
			"" if game.s.queue.is_empty() else "Còn việc phải chọn", func() -> void:
				close_location()
				dialogs.open_night()))
	for id in game.scene_cards_at(_loc_id):
		var e: Dictionary = game.scene_info(id)
		var meta := "Cảnh chính hôm nay · %d phút" % roundi(float(e.get("hours", 0.5)) * 60.0)
		if e.has("window"):
			meta += " · %s–%s" % [GameLogic.hh(float(e.window[0])), GameLogic.hh(float(e.window[1]))]
		if game.scene_wait(id) > 0.0:
			meta += " · chờ tới %s mới bắt đầu" % GameLogic.hh(float(e.window[0]))
		_loc_cards.add_child(_quest_card("◆  " + game.fill(str(e.title)), meta + "\n" + str(e.get("who", "")),
			game.scene_lock(id), game.open_scene.bind(id)))
		found += 1
	for who in world.npcs_at(_loc_id):
		var npc := str(who.id)
		_loc_cards.add_child(UI.choice("Nói chuyện với " + str(who.name),
			"%d phút · Thân thiết %d/100" % [roundi(float(game.cfg.get("talkHours", 0.5)) * 60.0), int(game.s.rep.get(npc, 0))],
			game.talk_lock(npc), game.talk.bind(npc)))
	# Người quen của chỗ này đang đi việc riêng: ghi đi đâu, mấy giờ về.
	for note in world.life.notes_at(_loc_id):
		_loc_cards.add_child(UI.choice("%s %s" % [note.name, note.what], "", "Vắng · khoảng %s về" % GameLogic.hh(float(note.back)),
			func() -> void: pass))
	for q in game.quest_offers(_loc_id):
		_loc_cards.add_child(_quest_card("!  Việc nhờ: " + str(q.title), "%s đang cần người giúp. Bấm để nghe chuyện." % q.who, "", game.quest_offer.bind(q.id)))
		found += 1
	for id in game.quest_cards_at(_loc_id):
		var step: Dictionary = game.quest_step(id)
		var meta: String = game.quest_deadline_text(id)
		if float(step.get("hours", 0.0)) > 0.0:
			meta = "%d phút · %s" % [roundi(float(step.hours) * 60.0), meta]
		if game.quest_step_wait(id) > 0.0:
			meta += " · chờ tới %s" % GameLogic.hh(float(step.window[0]))
		_loc_cards.add_child(_quest_card("★  " + str(game.quest_def(id).title), game.quest_progress_text(id) + "\n" + meta,
			game.quest_step_lock(id), game.quest_visit.bind(id)))
		found += 1
	for g in GameLogic.GROUPS:
		for a in game.visible_actions(g):
			if a.get("location", "") == _loc_id:
				_loc_cards.add_child(UI.action_card(game, a, 320, _perform))
				found += 1
	if loc.get("scrap", false):
		var v: int = game.scrap_value()
		_loc_cards.add_child(UI.choice("Bán hết ve chai", ("Được " + GameLogic.fmt_k(v)) if v > 0 else "", "Chưa nhặt được gì, lục thùng rác dọc phố (phím E)" if v <= 0 else "",
			func() -> void:
				var got: int = game.sell_scrap()
				if got > 0:
					world._float_text("+" + GameLogic.fmt_k(got), Color("7fe0a0"))))
	if found == 0 and _loc_id != world.home and not loc.get("scrap", false):
		_loc_cards.add_child(UI.wrap("Hôm nay ở đây chưa có việc gì cho An.", 13, UI.INK_SOFT, 320))
	_fit_location.call_deferred()


## Bảng địa điểm cao vừa đủ số thẻ, nhiều quá thì cuộn (tránh khoảng trắng thừa khi chỉ có một việc).
func _fit_location() -> void:
	_loc_scroll.custom_minimum_size.y = minf(_loc_cards.get_combined_minimum_size().y, 420.0)


## Thẻ việc nhờ: nền vàng nhạt để nổi giữa các việc làm, dòng phụ xuống hàng được (bước việc nhờ thường dài).
func _quest_card(title: String, hint: String, lock: String, on_press: Callable) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(320, 92)
	btn.disabled = lock != ""
	btn.add_theme_stylebox_override("normal", UI.box(Color("fff6dc"), UI.GOLD, 8, 10))
	btn.add_theme_stylebox_override("hover", UI.box(Color("ffeec0"), UI.GOLD, 8, 10))
	btn.add_theme_stylebox_override("disabled", UI.box(Color("f6f1e4"), Color("e6d7a8"), 8, 10))
	btn.pressed.connect(on_press)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	btn.add_child(v)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 12
	v.offset_top = 8
	v.offset_right = -12
	v.offset_bottom = -8
	v.add_child(UI.label(title, 15, Color("6b4a00")))
	v.add_child(UI.wrap(hint, 12, UI.INK_SOFT, 296))
	if lock != "" and lock != "-":
		v.add_child(UI.small(lock, UI.STAMP))
	return btn


# ---------------------------------------------------------------- gợi ý cách chơi

## Gợi ý hiện đúng lúc lần đầu gặp (đói, có cảnh chính, Mệt lên…), mỗi cái một lần, lưu trong s.tips_seen.
var _tip: PanelContainer
var _tip_label: Label
var _tip_id := ""
var _tip_time := 0.0


func _build_tip(parent: Control) -> void:
	_tip = PanelContainer.new()
	_tip.add_theme_stylebox_override("panel", UI.box(UI.HUD_BG, UI.GOLD, 8, 12))
	_tip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_tip.custom_minimum_size = Vector2(360, 0)
	parent.add_child(_tip)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_tip.add_child(v)
	v.add_child(UI.label("GỢI Ý", 11, UI.GOLD))
	_tip_label = UI.wrap("", 14, UI.HUD_TEXT, 336)
	v.add_child(_tip_label)
	var ok := Button.new()
	ok.text = "Hiểu rồi"
	ok.size_flags_horizontal = Control.SIZE_SHRINK_END
	ok.pressed.connect(_close_tip)
	v.add_child(ok)
	_tip.visible = false


func _close_tip() -> void:
	if _tip_id != "" and game.is_started():
		if not game.s.has("tips_seen"):
			game.s["tips_seen"] = []
		game.s.tips_seen.append(_tip_id)
		game.changed.emit()
	_tip_id = ""
	_tip.visible = false


func _tip_due(id: String) -> bool:
	var s: Dictionary = game.s
	match id:
		"di_lai":
			return true
		"canh_chinh":
			return not game.scenes_today().is_empty()
		"tien":
			return int(s.stats.get("earned", 0)) > 0
		"an_uong":
			return game.has_needs() and game.need("fed") < 45.0
		"tam_giat":
			return game.has_needs() and (game.need("clean") < 45.0 or game.need("neat") < 45.0)
		"phong_do":
			return game.pay_mult() < 1.0
		"so":
			for p in s.promises:
				if p.status == "open":
					return true
		"noi_chuyen":
			if _loc_id != "":
				return not world.npcs_at(_loc_id).is_empty()
		"met":
			return float(s.fatigue) >= 55.0
		"viec_nho":
			return not game.quest_offers().is_empty()
		"ve_chai":
			return _prompt_id.begins_with("bin:")
		"mua":
			return bool(s.today.get("rain", false))
		"dien_thoai":
			return game.day() >= 2
		"toi":
			return game.clock() >= 19.5
		"cho_o":
			return game.day() >= 3
	return false


func _update_tip(dt: float) -> void:
	if game.is_over():
		_tip.visible = false
	if not game.is_started() or game.is_over() or dialogs.visible:
		return
	if _tip.visible:
		# Tự tắt sau một lúc nếu người chơi không bấm, coi như đã đọc.
		_tip_time += dt
		if _tip_time > 40.0:
			_close_tip()
		return
	var seen: Array = game.s.get("tips_seen", [])
	for tip in game.story.get("tips", []):
		if not seen.has(tip.id) and _tip_due(str(tip.id)):
			_tip_id = str(tip.id)
			_tip_label.text = str(tip.text)
			_tip_time = 0.0
			_tip.visible = true
			return
