extends Control
## Vòng Phong độ góc dưới bên trái màn phố (thay bảng trạng thái to, như vòng cảm xúc của Nobody): vành ngoài chạy theo
## Phong độ (xanh, vàng, đỏ), giữa là mặt vui hay mếu, dưới là một chữ: Tích cực, Bình thường, Uể oải, Kiệt sức.

var value := 100.0
var word := ""


func _draw() -> void:
	var c := Vector2(size.x / 2.0, size.x / 2.0)
	var r := size.x * 0.46
	var col := level_color(value)
	draw_circle(c, r + 3, Color(0, 0, 0, 0.55))
	draw_arc(c, r - 4, 0, TAU, 48, Color(1, 1, 1, 0.14), 7, true)
	draw_arc(c, r - 4, -PI / 2, -PI / 2 + TAU * clampf(value / 100.0, 0.0, 1.0), 48, col, 7, true)
	var fr := r * 0.62
	draw_circle(c, fr, col.darkened(0.55))
	var ink := col.lightened(0.25)
	draw_circle(c + Vector2(-fr * 0.35, -fr * 0.18), fr * 0.11, ink)
	draw_circle(c + Vector2(fr * 0.35, -fr * 0.18), fr * 0.11, ink)
	var smile := clampf((value - 45.0) / 45.0, -1.0, 1.0)
	var pts := PackedVector2Array()
	for i in 11:
		var t := i / 10.0
		pts.append(c + Vector2(lerpf(-fr * 0.42, fr * 0.42, t), fr * 0.32 + smile * fr * 0.22 * (1.0 - pow(2.0 * t - 1.0, 2.0))))
	draw_polyline(pts, ink, 3.0, true)
	var font := get_theme_default_font()
	var ws := font.get_string_size(word, HORIZONTAL_ALIGNMENT_CENTER, -1, 15)
	var at := Vector2((size.x - ws.x) / 2.0, size.x + 14)
	draw_string_outline(font, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, Color(0, 0, 0, 0.85))
	draw_string(font, at, word, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("f3f1ea"))


static func level_color(v: float) -> Color:
	return Color("4cc46a") if v >= 55.0 else (Color("e8b45a") if v >= 30.0 else Color("e0604f"))


static func word_for(v: float) -> String:
	if v >= 70.0:
		return "Tích cực"
	if v >= 55.0:
		return "Bình thường"
	if v >= 30.0:
		return "Uể oải"
	return "Kiệt sức"
