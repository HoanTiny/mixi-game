extends Control
## Bảng cân bằng: chơi toàn bộ vòng lặp bằng nút bấm, thấy hết chỉ số và mọi hành động một lúc.
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
var money_label: Label
var goal_label: Label
var goal_bar: ProgressBar
var health_label: Label
var health_bar: ProgressBar
var mood_label: Label
var mood_bar: ProgressBar
var skill_rows := {}
var reps_label: Label
var misc_label: Label
var food_select: OptionButton
var focus_select: OptionButton
var end_day_btn: Button
var flows := {}
var log_label: RichTextLabel
var food_keys: Array = []
var focus_keys: Array = []


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
	brand.add_child(UI.label("Lên Phố", 30, UI.TIM))
	brand.add_child(UI.label("BẢNG CÂN BẰNG · VÒNG LẶP 30 NGÀY", 11, UI.INK_SOFT))
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
	body.add_child(_build_log())


func _build_status() -> Control:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 12)
	scroll.add_child(col)

	var top := _panel(col)
	top.add_child(UI.label("TIỀN ĐANG CÓ", 11, UI.INK_SOFT))
	money_label = UI.label("", 28, UI.INK)
	top.add_child(money_label)
	goal_label = UI.label("", 13, UI.INK)
	goal_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	top.add_child(goal_label)
	goal_bar = UI.bar()
	top.add_child(goal_bar)
	health_label = UI.label("", 13, UI.INK)
	top.add_child(health_label)
	health_bar = UI.bar()
	top.add_child(health_bar)
	mood_label = UI.label("", 13, UI.INK)
	top.add_child(mood_label)
	mood_bar = UI.bar()
	top.add_child(mood_bar)

	var skill_panel := _panel(col)
	skill_panel.add_child(UI.label("KỸ NĂNG", 11, UI.INK_SOFT))
	for k in GameLogic.SKILLS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_label := UI.label(GameLogic.SKILLS[k], 13, UI.INK)
		name_label.custom_minimum_size = Vector2(80, 0)
		row.add_child(name_label)
		var b := UI.bar()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
		var lv := UI.label("", 12, UI.INK_SOFT)
		lv.custom_minimum_size = Vector2(32, 0)
		lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(lv)
		skill_panel.add_child(row)
		skill_rows[k] = [b, lv]

	var rep_panel := _panel(col)
	rep_panel.add_child(UI.label("ĐỘ THÂN THIẾT", 11, UI.INK_SOFT))
	reps_label = UI.label("", 13, UI.INK)
	reps_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rep_panel.add_child(reps_label)
	misc_label = UI.label("", 13, UI.INK_SOFT)
	misc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rep_panel.add_child(misc_label)
	return scroll


func _build_actions() -> Control:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 12)
	var bar_panel := PanelContainer.new()
	col.add_child(bar_panel)
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 12)
	bar_panel.add_child(toolbar)
	toolbar.add_child(UI.label("Ăn uống hôm nay", 13, UI.INK_SOFT))
	food_select = OptionButton.new()
	for k in game.cfg.food:
		var f: Dictionary = game.cfg.food[k]
		food_keys.append(k)
		food_select.add_item("%s · %s" % [f.name, GameLogic.fmt_k(int(f.cost))])
	food_select.item_selected.connect(func(i: int) -> void: game.set_food(food_keys[i]))
	toolbar.add_child(food_select)
	toolbar.add_child(UI.label("Tự học", 13, UI.INK_SOFT))
	focus_select = OptionButton.new()
	for k in GameLogic.SKILLS:
		if k == "phapLy":
			continue
		focus_keys.append(k)
		focus_select.add_item(GameLogic.SKILLS[k])
	focus_select.item_selected.connect(func(i: int) -> void: game.set_focus(focus_keys[i]))
	toolbar.add_child(focus_select)
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


func _build_log() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(330, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	v.add_child(UI.label("NHẬT KÝ", 11, UI.INK_SOFT))
	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_label.add_theme_font_size_override("normal_font_size", 13)
	log_label.add_theme_font_size_override("bold_font_size", 15)
	v.add_child(log_label)
	var copy_btn := Button.new()
	copy_btn.text = "Sao chép kết quả lượt chơi"
	copy_btn.pressed.connect(func() -> void: DisplayServer.clipboard_set(game.summary()))
	v.add_child(copy_btn)
	return panel


func _refresh() -> void:
	restart_btn.text = "Bấm lần nữa để chơi lại" if restart_armed else "Chơi lại"
	log_label.text = UI.log_bbcode(game)
	if not game.is_started():
		day_label.text = ""
		clock_label.text = ""
		return
	var s: Dictionary = game.s
	day_label.text = "Ngày %d/30" % game.day()
	clock_label.text = "%s · %s · còn %s giờ" % [game.weekday_name(), GameLogic.hh(minf(game.clock(), 22.0)), GameLogic.num(game.hours_left())]
	money_label.text = GameLogic.fmt_money(int(s.money))
	var m: Dictionary = game.next_milestone()
	var lack := maxi(0, int(m.amount) - int(s.money))
	var days_left: int = int(m.day) - game.day()
	var when := "hạn là tối nay" if days_left == 0 else "còn %d ngày" % days_left
	if lack == 0:
		goal_label.text = "Ngày %d · %s: %s\nĐã đủ tiền cho mốc này" % [m.day, m.label, GameLogic.fmt_money(m.amount)]
	else:
		goal_label.text = "Ngày %d · %s: %s\nCòn thiếu %s · %s" % [m.day, m.label, GameLogic.fmt_money(m.amount), GameLogic.fmt_money(lack), when]
	UI.set_bar(goal_bar, float(s.money), float(m.amount), UI.GOOD if lack == 0 else UI.STAMP)
	health_label.text = "Sức khỏe  %d/%d" % [int(s.health), int(s.health_max)]
	UI.set_bar(health_bar, float(s.health), float(s.health_max), UI.level_color(float(s.health) / float(s.health_max)))
	mood_label.text = "Tinh thần  %d/%d" % [int(s.mood), int(s.mood_max)]
	UI.set_bar(mood_bar, float(s.mood), float(s.mood_max), UI.level_color(float(s.mood) / float(s.mood_max)))
	var per := float(game.cfg.xpPerLevel)
	var max_lv := int(game.cfg.maxLevel)
	for k in skill_rows:
		var row: Array = skill_rows[k]
		UI.set_bar(row[0], float(s.xp[k]), per * max_lv, UI.TIM)
		row[1].text = "%d/%d" % [game.level(k), max_lv]
	var reps := []
	for k in GameLogic.REPS:
		reps.append("%s %d" % [GameLogic.REPS[k], int(s.rep[k])])
	reps_label.text = "  ·  ".join(reps)
	var room_name := "Chưa thuê"
	if s.room != "":
		room_name = game.cfg.rooms[s.room].name
	var lines := [
		"Phòng trọ: " + room_name,
		"Nợ phải trả ngày 30: " + GameLogic.fmt_money(int(s.debt)),
		"Bằng chứng: %d · Chuyến chạy hàng: %d/%d" % [int(s.evidence), int(s.smuggle), int(game.cfg.smuggle.tripsForBadEnding)],
		"Tạm trú: " + ("Đã đăng ký" if s.flags.get("tamTru", false) else "Chưa"),
	]
	if int(s.held) > 0:
		lines.append("Lương đang bị giữ: " + GameLogic.fmt_money(int(s.held)))
	misc_label.text = "\n".join(lines)
	food_select.select(food_keys.find(s.food))
	food_select.disabled = float(s.used) > 0.0 or not s.queue.is_empty()
	focus_select.select(focus_keys.find(s.focus))
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
