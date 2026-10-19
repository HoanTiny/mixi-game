extends Control
## Bảng cân bằng: chơi lát cắt bằng nút bấm, thấy hết dòng tiền, Mệt, sổ lời hứa và sổ gia đình.
## Dùng để thử số liệu nhanh; màn chơi chính là scenes/world.tscn.

const GameLogic := preload("res://scripts/game_logic.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")
const DialogLayer := preload("res://scripts/ui/dialog_layer.gd")

var game
var restart_armed := false
var dialogs: DialogLayer

var day_label: Label
var clock_label: Label
var restart_btn: Button
var money_grid: GridContainer
var fatigue_label: Label
var fatigue_bar: ProgressBar
var progress_label: Label
var people_label: Label
var end_day_btn: Button
var flows := {}
var ledger: RichTextLabel
var log_label: RichTextLabel


func _ready() -> void:
	game = GameState.game
	theme = UI.make_theme()
	_build()
	dialogs = DialogLayer.new()
	dialogs.game = game
	add_child(dialogs)
	game.changed.connect(_refresh)
	_refresh()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = UI.PAPER
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 18)
	root.add_child(header)
	var brand := VBoxContainer.new()
	brand.add_theme_constant_override("separation", 0)
	header.add_child(brand)
	brand.add_child(UI.label("Trước mùa mưa", 28, UI.TIM))
	brand.add_child(UI.label("BẢNG CÂN BẰNG · LÁT CẮT NGÀY 18–22", 11, UI.INK_SOFT))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	day_label = UI.label("", 26, UI.INK)
	day_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(day_label)
	clock_label = UI.label("", 15, UI.INK_SOFT)
	clock_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(clock_label)
	var world_btn := Button.new()
	world_btn.text = "Sang màn phố 3D"
	world_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	world_btn.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/world.tscn"))
	header.add_child(world_btn)
	restart_btn = Button.new()
	restart_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	restart_btn.pressed.connect(_on_restart)
	header.add_child(restart_btn)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	root.add_child(body)
	body.add_child(_build_status())
	body.add_child(_build_actions())
	body.add_child(_build_right())


func _build_status() -> Control:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(320, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 12)
	scroll.add_child(col)

	var money := _panel(col)
	money.add_child(UI.label("HAI CỘT TIỀN", 11, UI.INK_SOFT))
	money_grid = GridContainer.new()
	money_grid.columns = 2
	money_grid.add_theme_constant_override("h_separation", 12)
	money_grid.add_theme_constant_override("v_separation", 4)
	money.add_child(money_grid)

	var body := _panel(col)
	fatigue_label = UI.label("", 13, UI.INK)
	body.add_child(fatigue_label)
	fatigue_bar = UI.bar()
	body.add_child(fatigue_bar)
	progress_label = UI.label("", 13, UI.INK_SOFT)
	progress_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(progress_label)

	var people := _panel(col)
	people.add_child(UI.label("QUAN HỆ", 11, UI.INK_SOFT))
	people_label = UI.label("", 13, UI.INK)
	people_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	people.add_child(people_label)
	return scroll


func _build_actions() -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 12)
	var bar_panel := PanelContainer.new()
	col.add_child(bar_panel)
	var toolbar := HBoxContainer.new()
	bar_panel.add_child(toolbar)
	toolbar.add_child(UI.label("Mỗi tối trừ %s tiền sinh hoạt cả nhà" % GameLogic.fmt_money(int(game.cfg.livingCostPerDay)), 13, UI.INK_SOFT))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)
	end_day_btn = Button.new()
	end_day_btn.pressed.connect(func() -> void: dialogs.open_night())
	toolbar.add_child(end_day_btn)

	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(tabs)
	var i := 0
	for g in GameLogic.GROUPS:
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		tabs.add_child(scroll)
		tabs.set_tab_title(i, GameLogic.GROUPS[g])
		var flow := HFlowContainer.new()
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		flow.add_theme_constant_override("h_separation", 10)
		flow.add_theme_constant_override("v_separation", 10)
		scroll.add_child(flow)
		flows[g] = flow
		i += 1
	return col


func _build_right() -> Control:
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(380, 0)
	ledger = _rich()
	tabs.add_child(ledger)
	tabs.set_tab_title(0, "Sổ")
	log_label = _rich()
	tabs.add_child(log_label)
	tabs.set_tab_title(1, "Nhật ký")
	return tabs


func _rich() -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.add_theme_font_size_override("normal_font_size", 13)
	r.add_theme_font_size_override("bold_font_size", 14)
	return r


func _refresh() -> void:
	restart_btn.text = "Bấm lần nữa để chơi lại" if restart_armed else "Chơi lại"
	log_label.text = UI.log_bbcode(game)
	ledger.text = UI.ledger_bbcode(game)
	if not game.is_started():
		day_label.text = ""
		clock_label.text = ""
		return
	var s: Dictionary = game.s
	day_label.text = "Ngày %d/30" % game.day()
	clock_label.text = "%s · %s · còn %s giờ" % [game.weekday_name(), GameLogic.hh(minf(game.clock(), 22.0)), GameLogic.num(game.hours_left())]

	for c in money_grid.get_children():
		c.queue_free()
	for row in UI.money_lines(game):
		money_grid.add_child(UI.label(row[0], 13, UI.INK_SOFT))
		var v := UI.label(row[1], 14, UI.INK)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		money_grid.add_child(v)

	var warn := float(game.cfg.fatigue.warn)
	fatigue_label.text = "Mệt  %d/100%s" % [int(s.fatigue), "  · cảnh báo" if game.fatigue_warn() else ""]
	UI.set_bar(fatigue_bar, float(s.fatigue), 100.0, UI.STAMP if float(s.fatigue) >= warn else (UI.WARN if float(s.fatigue) >= warn - 20 else UI.GOOD))
	var info := ["Tuyến " + str(s.route)]
	if s.route != "A":
		info.append("Tiến độ hợp đồng %d/%d buổi trước nghiệm thu" % [int(s.progress), int(s.progress_need)])
	info.append("Ngày ở mức cảnh báo: %d · bỏ qua nghỉ: %d" % [int(s.warn_days), int(s.rest_skips)])
	info.append("Linh tin An: %d · Linh muốn: %s" % [int(s.respect), "chỗ xa" if s.linh.wish == "xa" else "chỗ gần"])
	progress_label.text = "\n".join(info)
	var reps := []
	for k in game.story.reps:
		reps.append("%s %d" % [game.rep_name(k), int(s.rep.get(k, 0))])
	people_label.text = "  ·  ".join(reps)

	end_day_btn.text = "Kết thúc ngày %d" % game.day()
	end_day_btn.disabled = game.is_over() or not s.queue.is_empty()
	for g in flows:
		var flow: HFlowContainer = flows[g]
		for child in flow.get_children():
			child.queue_free()
		for a in game.visible_actions(g):
			flow.add_child(UI.action_card(game, a))


func _panel(parent: Control) -> VBoxContainer:
	var p := PanelContainer.new()
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	return v


func _on_restart() -> void:
	if not game.is_started():
		return
	if restart_armed:
		restart_armed = false
		GameState.restart()
		return
	restart_armed = true
	_refresh()
	get_tree().create_timer(3.0).timeout.connect(func() -> void:
		restart_armed = false
		_refresh())
