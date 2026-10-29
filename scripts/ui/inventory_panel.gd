extends CanvasLayer
## Small modal bag; uses the same persisted stacks as quest/character inventory.
signal closed
const UI := preload("res://scripts/ui/ui_kit.gd")
const ItemIcon := preload("res://scripts/ui/item_icon.gd")
const Inventory := preload("res://scripts/systems/inventory.gd")
var game
var _panel: PanelContainer
var _grid: GridContainer
var _scroll: ScrollContainer
var _title: Label
var _status: Label
var _detail: Label
var _hint: Label
var _use: Button
var _shop_tab: Button
var _quantity: SpinBox
var _selected := ""
var _shop := false

func _ready() -> void:
	layer = 45
	visible = false
	var shade := ColorRect.new()
	shade.color = Color(0.02,0.025,0.02,0.75)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.theme = UI.make_theme()
	_panel.add_theme_stylebox_override("panel",UI.box(Color("1d2724"),Color("ad9565"),10,18))
	center.add_child(_panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation",12)
	_panel.add_child(col)
	var row := HBoxContainer.new()
	col.add_child(row)
	_title = UI.label("BALO",24,UI.GOLD)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_title)
	var close_button := _button("Đóng · Esc",close)
	row.add_child(close_button)
	_status = UI.label("",14,UI.HUD_TEXT)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_status)
	var tabs := HBoxContainer.new()
	col.add_child(tabs)
	tabs.add_child(_button("Đang mang",func(): _shop=false; _selected=""; refresh()))
	_shop_tab = _button("Tạp hóa Phúc Tân",func(): _shop=true; _selected=""; refresh())
	tabs.add_child(_shop_tab)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_scroll)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation",8)
	_grid.add_theme_constant_override("v_separation",8)
	_scroll.add_child(_grid)
	_detail = UI.label("",16,UI.HUD_TEXT)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_detail)
	var footer := HBoxContainer.new()
	col.add_child(footer)
	_quantity = SpinBox.new()
	_quantity.min_value=1; _quantity.max_value=99; _quantity.step=1; _quantity.value=1
	_quantity.custom_minimum_size.x=100
	_quantity.value_changed.connect(func(_v): _show_detail())
	footer.add_child(_quantity)
	_use = _button("Sử dụng",_activate)
	_use.custom_minimum_size.y=46
	_use.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	footer.add_child(_use)
	_hint=UI.label("",13,UI.HUD_SOFT)
	_hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_hint)
	game.changed.connect(_on_changed)
	get_viewport().size_changed.connect(_fit)
	_fit()

func _button(text: String, callback: Callable) -> Button:
	var b:=Button.new()
	b.text=text
	b.custom_minimum_size.y=40
	b.pressed.connect(callback)
	return b

func _fit() -> void:
	if _panel == null: return
	var size: Vector2=get_viewport().get_visible_rect().size
	_panel.custom_minimum_size.x=minf(690,size.x-32)
	_grid.columns=4 if size.x>=700 else (3 if size.x>=490 else 2)
	_scroll.custom_minimum_size.y=clampf(size.y-390,95,275)

func open(shop := false) -> void:
	_shop=shop; visible=true; _hint.text=""
	game.Inventory.migrate(game)
	refresh()

func close() -> void:
	if not visible: return
	visible=false
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE,KEY_B,KEY_I]:
		close()
		get_viewport().set_input_as_handled()

func _on_changed() -> void:
	if visible: refresh()

func refresh() -> void:
	_title.text="TẠP HÓA · PHÚC TÂN" if _shop else "BALO · ĐỒ DÙNG"
	_status.text="%s · %s · Thể lực %d · Độ no %d · Tâm trạng %d · Vệ sinh %d" % [game.hh(game.clock()),game.fmt_money(int(game.s.cash)),int(100-game.s.fatigue),int(game.need("fed")),int(game.need("mood")),int(game.need("clean"))]
	_shop_tab.disabled=Inventory.shop_reason(game)!=""
	_shop_tab.tooltip_text=Inventory.shop_reason(game)
	_quantity.visible=_shop
	for child in _grid.get_children():
		_grid.remove_child(child); child.queue_free()
	var rows: Array=[]
	if _shop:
		for id in Inventory.definitions(game):
			var item: Dictionary=Inventory.definition(game,id)
			if bool(item.get("purchasable",true)): rows.append(item)
	else: rows=Inventory.owned(game)
	if rows.is_empty():
		_selected=""
		var empty:=UI.label("Balo chưa có đồ dùng.\nGhé tạp hóa ở Phúc Tân để mua đồ mang theo.",16,UI.HUD_SOFT)
		empty.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		_grid.add_child(empty)
	else:
		if not rows.any(func(r): return str(r.id)==_selected): _selected=str(rows[0].id)
		for item in rows:
			var id: String=item.id
			var b:=Button.new()
			b.custom_minimum_size=Vector2(132,132)
			b.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			b.add_theme_stylebox_override("normal",UI.box(Color("35473c") if _selected==id else Color("28312c"),UI.GOLD if _selected==id else Color("566052"),6,8))
			b.tooltip_text=str(item.name)+" · "+Inventory.effects_text(item)
			var box:=VBoxContainer.new()
			box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			box.offset_left=6; box.offset_top=7; box.offset_right=-6; box.offset_bottom=-7
			box.mouse_filter=Control.MOUSE_FILTER_IGNORE
			b.add_child(box)
			var icon:=ItemIcon.new(str(item.get("kind","box")))
			icon.custom_minimum_size=Vector2(56,56)
			box.add_child(icon)
			for text in [str(item.name),game.fmt_money(int(item.price))+" / món" if _shop else "×%d" % game.item_count(id)]:
				var label:=UI.label(text,14,UI.HUD_TEXT)
				label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
				label.mouse_filter=Control.MOUSE_FILTER_IGNORE
				box.add_child(label)
			b.pressed.connect(func(): _selected=id; refresh())
			_grid.add_child(b)
	_show_detail()

func _show_detail() -> void:
	var item:=Inventory.definition(game,_selected)
	if item.is_empty():
		_detail.text="Đồ nghề, quần áo và đồ nhiệm vụ vẫn nằm trong bảng Nhân vật (C)."
		_use.disabled=true
		return
	_detail.text=str(item.name)+"\n"+Inventory.effects_text(item)+"\n"+str(item.get("description",""))
	var reason:=Inventory.buy_reason(game,_selected,int(_quantity.value)) if _shop else Inventory.use_reason(game,_selected)
	_use.disabled=reason!=""
	_use.text="Mua %d · %s" % [int(_quantity.value),game.fmt_money(int(item.price)*int(_quantity.value))] if _shop else "Sử dụng · %d phút" % int(item.minutes)
	_use.tooltip_text=reason
	_hint.text=reason if reason!="" else ("Mua để mang theo · mỗi lượt mua tốn 5 phút" if _shop else "Dùng một món; thời gian và nhu cầu được cập nhật ngay.")

func _activate() -> void:
	var id:=_selected
	var ok: bool=game.buy_item(id,int(_quantity.value)) if _shop else game.use_item(id)
	refresh()
	if ok: _hint.text=("Đã mua " if _shop else "Đã dùng ")+str(Inventory.definition(game,id).name)
