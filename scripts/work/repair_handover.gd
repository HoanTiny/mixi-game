extends Window
## Presentation only. Payment and quest completion have already been committed
## by the existing game logic; closing/skipping never grants another reward.
const UI := preload("res://scripts/ui/ui_kit.gd")
var game
var info: Dictionary = {}
var activity: Node3D

func _ready() -> void:
	title="Khách nhận lại đồ"
	size=Vector2i(760,560); min_size=Vector2i(560,430)
	transient=true; exclusive=true; theme=UI.make_theme()
	close_requested.connect(queue_free)
	var panel := PanelContainer.new(); add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_theme_stylebox_override("panel",UI.box(Color("202824"),Color("776c52"),3,16))
	var column := VBoxContainer.new(); panel.add_child(column)
	column.add_child(UI.label(str(info.get("title","Đã trả món cho khách")),23,UI.GOLD))
	var surface := SubViewportContainer.new(); surface.stretch=true
	surface.size_flags_vertical=Control.SIZE_EXPAND_FILL; surface.custom_minimum_size=Vector2(510,290)
	column.add_child(surface)
	var view := SubViewport.new(); view.size=Vector2i(728,380); view.own_world_3d=true; view.msaa_3d=Viewport.MSAA_2X
	surface.add_child(view)
	activity=preload("res://scripts/work/repair_activity.gd").new()
	activity.game=game; activity.kind=int(info.get("kind",0)); activity.handover=true
	activity.customer_id=str(info.get("customer","DUYEN")); activity.setting=str(info.get("setting","workshop"))
	view.add_child(activity)
	column.add_child(UI.wrap(str(info.get("line","Cảm ơn An. Có gì cô sẽ ghé lại.")),18,UI.HUD_TEXT,680))
	column.add_child(UI.wrap("Tiền công và kết quả công việc đã ghi trong Sổ.",13,UI.HUD_SOFT,680))
	var close := Button.new(); close.text="Trở lại khu phố · Esc"; close.pressed.connect(queue_free); column.add_child(close)
	popup_centered()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE: queue_free()
