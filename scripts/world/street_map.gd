extends Control
## Bản đồ phố thu nhỏ ở giữa mép trên: mỗi địa điểm là một chấm, mũi tên vàng là Minh.
## Rê chuột lên chấm để xem tên, bấm để Minh đi tới đó.

const UI := preload("res://scripts/ui/ui_kit.gd")
const PAD := 18.0
const LINE_Y := 36.0

var world
var _hover := ""


func _ready() -> void:
	custom_minimum_size = Vector2(540, 58)
	size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(func() -> void:
		_hover = ""
		queue_redraw())


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _px(x: float) -> float:
	return remap(x, world.STREET_X.x, world.STREET_X.y, PAD, size.x - PAD)


func _nearest(mx: float) -> String:
	var best := ""
	var best_d := 14.0
	for id in world.LOCATIONS:
		var d := absf(_px(float(world.LOCATIONS[id].x)) - mx)
		if d < best_d:
			best = id
			best_d = d
	return best


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var h := _nearest(event.position.x)
		if h != _hover:
			_hover = h
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _hover != "" and not world.hud.blocking():
			world.hud.close_location()
			world.walk_to_location(_hover)
		accept_event()


func _draw() -> void:
	draw_style_box(UI.box(UI.HUD_BG, Color(1, 1, 1, 0.1), 8, 0), Rect2(Vector2.ZERO, size))
	var font := get_theme_default_font()
	draw_line(Vector2(PAD, LINE_Y), Vector2(size.x - PAD, LINE_Y), Color(1, 1, 1, 0.25), 2.0)
	var open: String = world.hud.location_open()
	var near: String = world.nearest_location()
	for id in world.LOCATIONS:
		var loc: Dictionary = world.LOCATIONS[id]
		var p := Vector2(_px(float(loc.x)), LINE_Y)
		var r := 6.0 if id == _hover or id == open else 4.5
		draw_circle(p, r, Color(loc.color))
		if id == open or id == near:
			draw_arc(p, r + 3.0, 0, TAU, 20, UI.GOLD, 1.5)
	var px := _px(world.player.position.x)
	draw_colored_polygon(PackedVector2Array([Vector2(px, LINE_Y - 9), Vector2(px - 6, LINE_Y - 19), Vector2(px + 6, LINE_Y - 19)]), UI.GOLD)
	var title := "Bản đồ phố · bấm chấm để đi tới"
	var col := UI.HUD_SOFT
	var show_id := _hover if _hover != "" else open
	if show_id != "":
		title = str(world.LOCATIONS[show_id].name)
		col = UI.HUD_TEXT
	var w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string(font, Vector2((size.x - w) / 2.0, 17), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
