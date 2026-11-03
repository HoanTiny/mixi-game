extends Window
const UI := preload("res://scripts/ui/ui_kit.gd")
const Wardrobe := preload("res://scripts/wardrobe.gd")
var world
var game
var avatar
var inventory: VBoxContainer
var status: VBoxContainer
var cash: Label
var selected := ""
var category := "all"
var description: Label
var equip_button: Button

func _ready() -> void:
	title = "An · Nhân vật / Túi đồ"
	size = Vector2i(1080,620)
	min_size = Vector2i(920,560)
	transient = true
	exclusive = true
	theme = UI.make_theme()
	close_requested.connect(queue_free)
	var background := PanelContainer.new()
	background.add_theme_stylebox_override("panel",UI.box(Color("272820"),Color("9c814d"),3,18))
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation",22)
	background.add_child(layout)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 310
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(left)
	left.add_child(UI.label("TÚI ĐỒ",23,UI.GOLD))
	cash = UI.label("",17,UI.HUD_TEXT)
	left.add_child(cash)
	var tabs := HBoxContainer.new()
	left.add_child(tabs)
	for entry in [["all","Tất cả"],["shirt","Áo"],["pants","Quần"]]:
		var tab := Button.new()
		tab.text = entry[1]
		tab.pressed.connect(func() -> void:
			category = entry[0]
			refresh())
		tabs.add_child(tab)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	inventory = VBoxContainer.new()
	inventory.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inventory)
	description = UI.wrap("Chọn món đồ để xem và mặc.\nMua thêm quần áo tại Chợ Cầu Nhỏ.",15,UI.HUD_SOFT,300)
	left.add_child(description)
	equip_button = Button.new()
	equip_button.text = "Mặc món đã chọn"
	equip_button.pressed.connect(func() -> void: Wardrobe.equip(game,selected))
	left.add_child(equip_button)
	var center := VBoxContainer.new()
	layout.add_child(center)
	center.add_child(UI.label("AN  ·  27 TUỔI",22,UI.GOLD))
	var container := SubViewportContainer.new()
	container.custom_minimum_size = Vector2(300,480)
	center.add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(300,480)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	avatar = world.AnCharacter.new()
	viewport.add_child(avatar)
	avatar.setup(Color.WHITE,Color.WHITE)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.position = Vector3(0.18,0.95,3)
	camera.look_at(Vector3(0,0.9,0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.05
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-25,-25,0)
	viewport.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("403b2e")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.7
	viewport.add_child(env)
	center.add_child(UI.label("Thay đồ đã sở hữu · Không tốn phí",13,UI.HUD_SOFT))
	status = VBoxContainer.new()
	status.custom_minimum_size.x = 270
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(status)
	game.changed.connect(refresh)
	refresh()
	popup_centered()

func clear(box: Control) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()

func refresh() -> void:
	if not is_instance_valid(avatar):
		return
	clear(inventory)
	clear(status)
	cash.text = "Tiền mặt  " + game.fmt_money(int(game.s.cash))
	avatar.set_colors(game.s.appearance)
	avatar.set_hair_style(game.s.hair_style)
	var grid := GridContainer.new()
	grid.columns = 2
	inventory.add_child(grid)
	for id in game.s.inventory:
		var item: Dictionary = game.s.inventory[id]
		if category != "all" and item.slot != category:
			continue
		var button := Button.new()
		button.custom_minimum_size = Vector2(145,85)
		button.text = item.name + ("\nĐang mặc" if game.s.equipped[item.slot] == id else "\nTrong túi")
		button.add_theme_color_override("font_color",Color(item.color).lightened(0.4))
		button.add_theme_stylebox_override("normal",UI.box(Color("34362e"),UI.GOLD if selected == id else Color("69624e"),2,8))
		button.pressed.connect(func() -> void:
			selected = id
			refresh())
		grid.add_child(button)
	equip_button.disabled = selected.is_empty() or not game.s.inventory.has(selected)
	if not equip_button.disabled:
		var item: Dictionary = game.s.inventory[selected]
		description.text = item.name + "\n" + ("Áo caro vải dệt, dáng quen thuộc." if item.slot == "shirt" else "Quần jeans, giữ nếp và độ sờn.")
		equip_button.disabled = game.s.equipped[item.slot] == selected
	status.add_child(UI.label("ĐANG TRANG BỊ",20,UI.GOLD))
	for slot in ["shirt","pants"]:
		var item: Dictionary = game.s.inventory[game.s.equipped[slot]]
		status.add_child(UI.wrap(("Áo  ·  " if slot == "shirt" else "Quần  ·  ")+str(item.name),16,UI.HUD_TEXT,260))
	status.add_child(UI.wrap("Tóc  ·  " + ("Cắt gọn" if game.s.hair_style == "neat" else "Tự nhiên") + "\nCắt và nhuộm tại Tiệm tóc đầu ngõ.",14,UI.HUD_SOFT,260))
	status.add_child(HSeparator.new())
	status.add_child(UI.label("SINH HOẠT",20,UI.GOLD))
	for entry in [["satiety","No bụng"],["hygiene","Vệ sinh"],["mood","Tinh thần"],["fatigue","Mệt"]]:
		status.add_child(UI.label("%s  %d/100" % [entry[1],game.s[entry[0]]],15,UI.HUD_TEXT))
		var bar := UI.bar(8)
		bar.value = game.s[entry[0]]
		status.add_child(bar)
	status.add_child(HSeparator.new())
	status.add_child(UI.label("QUAN HỆ",20,UI.GOLD))
	for key in game.s.rep:
		status.add_child(UI.label("%s  ·  %s" % [game.rep_name(key),game.s.rep[key]],13,UI.HUD_SOFT))
	var close := Button.new()
	close.text = "Đóng"
	close.pressed.connect(queue_free)
	status.add_child(close)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		queue_free()
