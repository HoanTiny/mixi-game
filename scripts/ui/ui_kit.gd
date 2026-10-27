extends RefCounted
## Bảng màu, theme và các khối giao diện dùng chung cho màn phố 3D lẫn bảng cân bằng.

const GameLogic := preload("res://scripts/game_logic.gd")

const PAPER := Color("262823")
const CARD := Color("1c201df5")
const LINE := Color("56594b")
const INK := Color("e8e2d2")
const INK_SOFT := Color("b7b6a6")
const TIM := Color("c4ad76")
const TIM_SOFT := Color("3b3e31")
const STAMP := Color("e08c75")
const GOOD := Color("a3b995")
const WARN := Color("d5b576")
const GOLD := Color("d3bd86")
## Nền tối trong suốt cho HUD đè lên cảnh 3D, giống bảng mục tiêu của Nobody.
const HUD_BG := Color(0.07, 0.085, 0.07, 0.84)
const HUD_TEXT := Color("f3f1ea")
const HUD_SOFT := Color("b9bccb")
const LOG_COLORS := {"plus": "a3b995", "minus": "e08c75", "warn": "d5b576", "event": "c4ad76", "info": "e8e2d2"}


static func make_theme() -> Theme:
	var t := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI", "Arial", "Noto Sans"])
	t.default_font = font
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
	t.set_stylebox("panel", "TabContainer", box(CARD, LINE, 8, 12))
	t.set_stylebox("tab_selected", "TabContainer", box(CARD, LINE, 6, 8))
	t.set_stylebox("tab_unselected", "TabContainer", box(PAPER, LINE, 6, 8))
	t.set_stylebox("tab_hovered", "TabContainer", box(TIM_SOFT, LINE, 6, 8))
	t.set_color("font_selected_color", "TabContainer", INK)
	t.set_color("font_unselected_color", "TabContainer", INK_SOFT)
	t.set_color("font_hovered_color", "TabContainer", TIM)
	t.set_color("default_color", "RichTextLabel", INK)
	return t


static func box(bg: Color, border: Color, radius := 8, pad := 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(mini(radius, 3))
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
	if a.has("days"):
		meta.append("chỉ hôm nay" if int(a.days[1]) == game.day() else "đến hết ngày %d" % int(a.days[1]))
	v.add_child(small(" · ".join(meta), INK_SOFT))
	v.add_child(small(effects_text(game, a), INK_SOFT))

	var foot := ""
	var foot_color := TIM
	if not st.ok and st.reason != "":
		foot = st.reason
		foot_color = STAMP
	elif st.ok and float(st.start) > game.clock():
		foot = "Chờ tới %s mới bắt đầu" % GameLogic.hh(st.start)
	elif st.ok and a.group == "work" and float(st.start) + float(a.hours) > float(game.cfg.lateHour):
		foot = "Làm tới cuối tối: Mệt thêm %d" % int(game.cfg.lateFatigue)
		foot_color = WARN
	elif a.has("note"):
		foot = a.note
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
		if not (eff[key] is float or eff[key] is int):
			continue
		var v := float(eff[key])
		var mark := "+" if v > 0 else "−"
		if key == "fatigue":
			out.append("Mệt %s%d" % [mark, int(absf(v))])
		elif key in ["satiety", "hygiene", "mood"]:
			out.append("%s %s%d" % [{"satiety": "No", "hygiene": "Sạch", "mood": "Tinh thần"}[key], mark, int(absf(v))])
		elif key == "progress":
			out.append("Tiến độ +%d" % int(v))
		elif key == "respect":
			out.append("Linh tin %s%d" % [mark, int(absf(v))])
		elif key.begins_with("rep."):
			out.append("%s %s%d" % [game.rep_name(key.substr(4)), mark, int(absf(v))])
	return " · ".join(out)


static func pay_text(game, a: Dictionary) -> Array:
	if a.has("pay"):
		return ["+" + GameLogic.fmt_k(int(a.pay)), GOOD]
	var cost: int = game.action_money(a)
	if cost > 0:
		return ["−" + GameLogic.fmt_k(cost), STAMP]
	return ["", INK]


## Hai cột tiền: tiền mặt và tiền phải thu (trước / sau ngày 30), khoản phải trả, dự kiến ngày chốt chỗ ở.
static func money_lines(game) -> Array:
	var deadline := int(game.cfg.housingDeadline)
	var proj: int = game.projected_cash(deadline)
	var best: String = game.best_housing(proj)
	var best_name := "chưa đủ cả chỗ ở tạm" if best == "" else str(game.cfg.housing[best].name)
	return [
		["Tiền mặt", GameLogic.fmt_money(int(game.s.cash))],
		["Phải thu trước ngày 30", GameLogic.fmt_money(game.receivable_sum(0, 30))],
		["Phải thu sau ngày 30", GameLogic.fmt_money(game.receivable_sum(31, 999))],
		["Phải trả", GameLogic.fmt_money(game.payable_sum(999))],
		["Dự kiến sáng ngày %d" % deadline, GameLogic.fmt_money(proj)],
		["Đủ cho", best_name],
	]


## Sổ: khoản phải thu, phải trả, lời hứa và sổ gia đình, dạng BBCode.
static func ledger_bbcode(game) -> String:
	if not game.is_started():
		return ""
	var s: Dictionary = game.s
	var lines := ["[b]Phải thu[/b]"]
	lines.push_front("Dự kiến tiền nhà đã dự trù 60k/ngày cho bữa ăn của An.\n")
	for r in s.receivables:
		var state := "đã nhận" if r.status == "collected" else "ngày %d" % int(r.due)
		var mark := "" if r.status == "collected" else ("  (cần nghiệm thu)" if r.get("needsProgress", false) else "")
		lines.append("• %s: %s · %s%s" % [esc(r.label), GameLogic.fmt_money(int(r.amount)), state, mark])
	lines.append("")
	lines.append("[b]Phải trả[/b]")
	if s.payables.is_empty():
		lines.append("• Không có")
	for x in s.payables:
		var state: String = {"paid": "đã trả", "unpaid": "[color=#c0352b]chưa trả được[/color]"}.get(x.status, "ngày %d" % int(x.due))
		lines.append("• %s: %s · %s" % [esc(x.label), GameLogic.fmt_money(int(x.amount)), state])
	lines.append("")
	lines.append("[b]Sổ lời hứa[/b]")
	for p in s.promises:
		var st: String = GameLogic.PROMISE_STATUS.get(p.status, p.status)
		var col := "2d7a4c" if p.status == "done" else ("c0352b" if p.status == "overdue" else "1c2145")
		lines.append("• %s · hạn ngày %d · [color=#%s]%s[/color]" % [esc(p.text), int(p.due), col, st])
	if not s.family.is_empty():
		lines.append("")
		lines.append("[b]Sổ gia đình[/b]")
		for f in s.family:
			lines.append("• Ngày %d · %s · %s: %s" % [int(f.day), game.rep_name(f.who), GameLogic.FAMILY_KIND.get(f.kind, f.kind), esc(f.text)])
	return "\n".join(lines)


## Nhật ký dạng BBCode, ngày mới nhất ở trên.
static func log_bbcode(game) -> String:
	var lines := []
	if not game.is_started():
		return ""
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
