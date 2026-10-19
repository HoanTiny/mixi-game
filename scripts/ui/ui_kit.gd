extends RefCounted
## Bảng màu, theme và các khối giao diện dùng chung cho màn phố 3D lẫn bảng cân bằng.

const GameLogic := preload("res://scripts/game_logic.gd")

const PAPER := Color("f5f6fb")
const CARD := Color("ffffff")
const LINE := Color("d3d8eb")
const INK := Color("1c2145")
const INK_SOFT := Color("596086")
const TIM := Color("6a3db8")
const TIM_SOFT := Color("eee7fb")
const STAMP := Color("c0352b")
const GOOD := Color("2d7a4c")
const WARN := Color("a5690f")
const GOLD := Color("f2c14e")
## Nền tối trong suốt cho HUD đè lên cảnh 3D, giống bảng mục tiêu của Nobody.
const HUD_BG := Color(0.08, 0.09, 0.14, 0.78)
const HUD_TEXT := Color("f3f1ea")
const HUD_SOFT := Color("b9bccb")
const LOG_COLORS := {"plus": "2d7a4c", "minus": "c0352b", "warn": "a5690f", "event": "6a3db8", "info": "1c2145"}


static var _text_font: SystemFont


## Phông chữ chung: phông hệ thống, thiếu ký hiệu (◆ ✓ ○ ♪) thì lấy từ DejaVu Sans đóng kèm.
## Bản web không có phông hệ thống nên cần phông dự phòng này, nếu không ký hiệu hiện thành ô vuông.
static func text_font() -> SystemFont:
	if _text_font == null:
		_text_font = SystemFont.new()
		_text_font.font_names = PackedStringArray(["Segoe UI", "Arial", "Noto Sans"])
		_text_font.fallbacks = [load("res://assets/fonts/DejaVuSans.ttf")]
	return _text_font


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = text_font()
	t.default_font_size = 15
	t.set_color("font_color", "Label", INK)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(state, "Button", INK)
	t.set_color("font_disabled_color", "Button", INK_SOFT)
	t.set_stylebox("normal", "Button", box(CARD, LINE, 8, 10))
	t.set_stylebox("hover", "Button", box(CARD, TIM, 8, 10))
	t.set_stylebox("pressed", "Button", box(TIM_SOFT, TIM, 8, 10))
	t.set_stylebox("disabled", "Button", box(PAPER, LINE, 8, 10))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PanelContainer", box(CARD, LINE, 10, 14))
	t.set_color("default_color", "RichTextLabel", INK)
	return t


static func box(bg: Color, border: Color, radius := 8, pad := 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	return sb


static func label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func small(text: String, color: Color) -> Label:
	var l := label(text, 12, color)
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l


static func wrap(text: String, size: int, color: Color, width := 560) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l


static func bar(height := 10) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, height)
	b.add_theme_stylebox_override("background", box(Color(0.6, 0.62, 0.72, 0.35), Color(0, 0, 0, 0), 5, 0))
	return b


static func set_bar(b: ProgressBar, value: float, max_value: float, color: Color) -> void:
	b.max_value = maxf(max_value, 1.0)
	b.value = clampf(value, 0.0, b.max_value)
	b.add_theme_stylebox_override("fill", box(color, color, 5, 0))


static func level_color(ratio: float) -> Color:
	if ratio < 0.3:
		return STAMP
	if ratio < 0.6:
		return WARN
	return GOOD


static func esc(t: String) -> String:
	return t.replace("[", "[lb]")


## Nút có tiêu đề và một dòng phụ (gợi ý hoặc lý do bị khóa).
static func choice(title: String, hint: String, lock: String, on_press: Callable) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 58 if (hint != "" or lock != "") else 42)
	btn.disabled = lock != ""
	btn.add_theme_stylebox_override("normal", box(PAPER, LINE, 8, 10))
	btn.add_theme_stylebox_override("hover", box(TIM_SOFT, TIM, 8, 10))
	btn.pressed.connect(on_press)
	var v := _inner(btn, 14)
	var t := label(title, 15, INK)
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(t)
	if lock != "":
		v.add_child(small(lock, STAMP))
		t.modulate.a = 0.5
	elif hint != "":
		v.add_child(small(hint, INK_SOFT))
	return btn


## Thẻ một hành động (việc làm, lớp học, sinh hoạt) với tiền, giờ, hiệu ứng và lý do khóa.
## on_press nhận id hành động; bỏ trống thì làm ngay (bảng cân bằng), màn phố truyền vào để chạy thanh thời gian.
static func action_card(game, a: Dictionary, width := 270, on_press := Callable()) -> Button:
	var st: Dictionary = game.action_status(a)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(width, 104)
	btn.disabled = not st.ok
	btn.tooltip_text = effects_text(game, a)
	btn.pressed.connect((on_press if on_press.is_valid() else game.do_action).bind(a.id))
	var v := _inner(btn, 12)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(top)
	var name_label := label(a.name, 14, INK)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(name_label)
	var pay := pay_text(game, a)
	top.add_child(label(pay[0], 14, pay[1]))

	var meta := ["%s giờ" % GameLogic.num(float(a.hours))]
	if a.has("window"):
		meta.append("%s–%s" % [GameLogic.hh(a.window[0]), GameLogic.hh(a.window[1])])
	if a.get("weekend", false):
		meta.append("cuối tuần")
	if a.has("max_times") and not a.has("days") and not a.has("set_flag"):
		meta.append("buổi %d/%d" % [game.count(a.id), int(a.max_times)])
	if a.has("days"):
		meta.append("đến hết ngày %d" % int(a.days[1]))
	v.add_child(small(" · ".join(meta), INK_SOFT))
	v.add_child(small(effects_text(game, a), INK_SOFT))

	var foot := ""
	var foot_color := TIM
	if not st.ok and st.reason != "":
		foot = st.reason
		foot_color = STAMP
	elif st.ok and float(st.start) > game.clock():
		foot = "Chờ tới %s mới bắt đầu" % GameLogic.hh(st.start)
	elif st.ok and a.has("fee") and game.count(a.id) == 0:
		foot = "Buổi đầu đóng học phí %s" % GameLogic.fmt_k(int(a.fee))
	elif a.has("note"):
		foot = a.note
	if st.ok and a.has("hold_days") and game.day() >= int(a.hold_days[0]) and game.day() <= int(a.hold_days[1]):
		foot = "Sổ tay: lương hôm nay sẽ bị quỵt" if game.notes.has("quyt_luong") else "Lương tuần này trả vào ngày 8"
		foot_color = STAMP
	if foot != "":
		v.add_child(small(foot, foot_color))
	if btn.disabled:
		for i in range(0, 3):
			v.get_child(i).modulate.a = 0.5
	return btn


static func effects_text(game, a: Dictionary) -> String:
	var out := []
	var eff: Dictionary = a.get("effects", {})
	for key in eff:
		var v := float(eff[key])
		var mark := "+" if v > 0 else "−"
		if key == "health":
			out.append("Sức khỏe %s%s" % [mark, GameLogic.num(absf(v))])
		elif key == "mood":
			out.append("Tinh thần %s%s" % [mark, GameLogic.num(absf(v))])
		elif key.begins_with("xp."):
			out.append("%s +%s" % [GameLogic.SKILLS.get(key.substr(3), key), GameLogic.num(v)])
		elif key.begins_with("rep."):
			out.append("%s %s%d" % [GameLogic.REPS.get(key.substr(4), key), mark, int(absf(v))])
	if a.has("focus_xp"):
		out.append("%s +%s" % [GameLogic.SKILLS[game.s.focus], GameLogic.num(float(a.focus_xp))])
	return " · ".join(out)


static func pay_text(game, a: Dictionary) -> Array:
	if a.has("pay"):
		return ["+" + GameLogic.fmt_k(int(a.pay)) + (" + tip" if a.has("tip") else ""), GOOD]
	if a.has("pay_range"):
		return ["+%s–%s" % [GameLogic.fmt_k(int(a.pay_range[0])), GameLogic.fmt_k(int(a.pay_range[1]))], GOOD]
	var cost: int = game.action_money(a)
	if cost > 0:
		return ["−" + GameLogic.fmt_k(cost), STAMP]
	return ["", INK]


## Nhật ký dạng BBCode, ngày mới nhất ở trên, kèm Sổ tay của Minh nếu có.
static func log_bbcode(game) -> String:
	var lines := []
	if not game.notes.is_empty():
		lines.append("[b][color=#6a3db8]Sổ tay của Minh[/color][/b]")
		for n in game.notes:
			lines.append("• " + esc(str(game.story.notes.get(n, n))))
		lines.append("")
	if not game.is_started():
		return "\n".join(lines)
	var entries: Array = game.s.log
	var by_day := {}
	var order := []
	for i in range(maxi(0, entries.size() - 150), entries.size()):
		var e: Dictionary = entries[i]
		var d := int(e.day)
		if not by_day.has(d):
			by_day[d] = []
			order.append(d)
		by_day[d].append(e)
	order.reverse()
	for d in order:
		lines.append("[b][color=#6a3db8]Ngày %d[/color][/b]" % d)
		for e in by_day[d]:
			lines.append("[color=#%s]%s[/color]" % [LOG_COLORS.get(e.k, "1c2145"), esc(e.t)])
	return "\n".join(lines)


static func _inner(btn: Button, pad: int) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 1)
	btn.add_child(v)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = pad
	v.offset_top = 8
	v.offset_right = -pad
	v.offset_bottom = -8
	return v
