extends Control
## Thanh hơi nổi trên đầu An (world.stamina, scripts/world/stamina.gd): hiện khi đang chạy hay chưa hồi đủ, đầy hơi thì
## mờ dần rồi ẩn. Xanh khi còn nhiều, vàng khi gần hết, đỏ nhấp nháy kèm chữ "Hụt hơi" khi phải nghỉ.

const UI := preload("res://scripts/ui/ui_kit.gd")
const W := 64.0
const H := 7.0

var _ratio := 1.0
var _winded := false
var _alpha := 0.0
var _t := 0.0
var _font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(W + 40.0, 30.0)
	_font = UI.text_font()


## Mỗi khung hình (hud.gd): đặt thanh trên đầu An theo máy quay, đọc mức hơi.
func update(world, delta: float) -> void:
	_t += delta
	var st = world.stamina
	_ratio = st.ratio()
	_winded = st.winded
	var show: bool = (_ratio < 0.999 or world.sprinting()) and world.camera != null
	_alpha = move_toward(_alpha, 1.0 if show else 0.0, delta * (4.0 if show else 1.5))
	visible = _alpha > 0.01
	if not visible:
		return
	var head: Vector3 = world.player.global_position + Vector3(0, 2.25, 0)
	if world.camera.is_position_behind(head):
		visible = false
		return
	position = world.camera.unproject_position(head) - Vector2(size.x / 2.0, size.y)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2((size.x - W) / 2.0, size.y - H - 2.0), Vector2(W, H))
	var col := Color("8fd18a") if _ratio > 0.5 else (Color("e8b45a") if _ratio > 0.2 else Color("e0604f"))
	if _winded:
		col = Color("e0604f").lerp(Color("ff9a8a"), 0.5 + 0.5 * sin(_t * 9.0))
	draw_rect(r.grow(1.5), Color(0, 0, 0, 0.6 * _alpha))
	draw_rect(Rect2(r.position, Vector2(r.size.x * _ratio, r.size.y)), Color(col, _alpha))
	if _winded:
		var t := "Hụt hơi"
		var w := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string_outline(_font, Vector2((size.x - w) / 2.0, r.position.y - 4.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, _alpha))
		draw_string(_font, Vector2((size.x - w) / 2.0, r.position.y - 4.0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 0.85, 0.8, _alpha))
