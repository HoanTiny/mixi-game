extends Control
## Cần điều khiển ảo cho màn cảm ứng (góc dưới bên trái): đặt ngón vào vòng rồi kéo, An đi theo hướng kéo (trên màn là
## hướng bắc, đúng hướng máy quay). Nút "Chạy" bên cạnh bật tắt chạy nhanh. vector: -1..1 mỗi trục, (0, 0) khi thả.

signal sprint_toggled(on: bool)

const RADIUS := 62.0
const KNOB := 28.0

var vector := Vector2.ZERO
var sprint := false
var _touch := -1
var _center := Vector2.ZERO
var _knob := Vector2.ZERO
var _run_btn: Button


func _ready() -> void:
	custom_minimum_size = Vector2(RADIUS * 2.0 + 16.0, RADIUS * 2.0 + 16.0)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	_center = size / 2.0
	_run_btn = Button.new()
	_run_btn.text = "Chạy"
	_run_btn.toggle_mode = true
	_run_btn.focus_mode = Control.FOCUS_NONE
	_run_btn.custom_minimum_size = Vector2(76, 52)
	_run_btn.position = Vector2(size.x + 12.0, size.y - 60.0)
	_run_btn.toggled.connect(func(on: bool) -> void:
		sprint = on
		sprint_toggled.emit(on))
	add_child(_run_btn)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch < 0:
			_touch = event.index
			_move_to(event.position)
		elif not event.pressed and event.index == _touch:
			_release()
		accept_event()
	elif event is InputEventScreenDrag and event.index == _touch:
		_move_to(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		# Chuột (máy tính bật chạm thử) hay chạm giả lập bằng chuột.
		if event.pressed:
			_touch = 99
			_move_to(event.position)
		elif _touch == 99:
			_release()
		accept_event()
	elif event is InputEventMouseMotion and _touch == 99:
		_move_to(event.position)
		accept_event()


func _move_to(p: Vector2) -> void:
	var d := p - _center
	if d.length() > RADIUS:
		d = d.normalized() * RADIUS
	_knob = d
	# Vùng chết nhỏ ở giữa cho khỏi trôi khi ngón tay rung.
	vector = d / RADIUS if d.length() > RADIUS * 0.15 else Vector2.ZERO
	queue_redraw()


func _release() -> void:
	_touch = -1
	_knob = Vector2.ZERO
	vector = Vector2.ZERO
	queue_redraw()


func _draw() -> void:
	draw_circle(_center, RADIUS + 4.0, Color(0, 0, 0, 0.28))
	draw_arc(_center, RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0, true)
	draw_circle(_center + _knob, KNOB, Color(1, 1, 1, 0.55 if _touch >= 0 else 0.35))
	draw_arc(_center + _knob, KNOB, 0, TAU, 32, Color(0, 0, 0, 0.35), 2.0, true)
