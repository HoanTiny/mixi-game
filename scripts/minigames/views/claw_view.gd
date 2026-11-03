extends "res://scripts/minigames/views/minigame_view.gd"
## Máy gắp thú ở quán net: cần gắp tự chạy qua lại trên đống thú bông. Bấm Space (hay chạm) để thả cần đúng chỗ. Cần
## xuống, kẹp, kéo lên; lệch tâm con thú càng nhiều càng dễ tuột giữa đường (máy kẹp lỏng ngẫu nhiên như ngoài đời).
## cfg: tries (số lượt), sweep (lượt qua lại mỗi giây), grip (độ chắc của ngàm 0..1), reach (nửa bề rộng kẹp được, tỉ lệ ngang).
## Kết quả thô: {"score": số thú gắp được / số lượt (tối đa 1), "won", "tries", "fails": số lượt trượt}.

var tries_used := 0
var won := 0
var claw_x := 0.1
var phase := "move"
var depth := 0.0
var holding := -1
var toys: Array = []
var _t := 0.0
var _drop_at := 0.0
var _rng := RandomNumberGenerator.new()


func rules() -> String:
	return "Cần gắp tự chạy qua lại. Bấm Space hoặc chạm để thả cần. Thả trúng giữa con thú thì dễ giữ được; lệch thì hay tuột. Có %d lượt." % int(cfg.get("tries", 5))


func _setup() -> void:
	_rng.randomize()


func _begin() -> void:
	toys = []
	for i in 7:
		toys.append({"x": 0.12 + i * 0.12 + _rng.randf_range(-0.03, 0.03), "col": Color.from_hsv(_rng.randf(), 0.45, 0.95), "gone": false, "kind": i % 3})


## Xác suất giữ được con thú khi thả lệch tâm off (tỉ lệ ngang), độ chắc ngàm grip, nửa bề rộng kẹp reach.
static func hold_chance(off: float, grip: float, reach: float) -> float:
	if absf(off) > reach:
		return 0.0
	return clampf(grip * (1.0 - absf(off) / reach * 0.8), 0.0, 0.95)


func _play_input(event: InputEvent) -> void:
	var down: bool = (event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER]) \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if down and phase == "move":
		phase = "down"
		_drop_at = claw_x


func _play(delta: float) -> void:
	_t += delta
	match phase:
		"move":
			var k := fposmod(_t * float(cfg.get("sweep", 0.35)), 1.0) * 2.0
			claw_x = 0.08 + 0.84 * (k if k <= 1.0 else 2.0 - k)
		"down":
			depth = minf(1.0, depth + delta * 1.4)
			if depth >= 1.0:
				var best := -1
				var best_off := INF
				for i in toys.size():
					if not toys[i].gone and absf(float(toys[i].x) - claw_x) < absf(best_off):
						best = i
						best_off = float(toys[i].x) - claw_x
				holding = -1
				if best >= 0 and _rng.randf() < hold_chance(best_off, float(cfg.get("grip", 0.55)), float(cfg.get("reach", 0.06))):
					holding = best
					toys[best].gone = true
				phase = "up"
		"up":
			depth = maxf(0.0, depth - delta * 1.1)
			if depth <= 0.0:
				tries_used += 1
				if holding >= 0:
					won += 1
				holding = -1
				phase = "move"
				if tries_used >= int(cfg.get("tries", 5)):
					end()


func result() -> Dictionary:
	return {"score": minf(1.0, float(won)), "won": won, "tries": int(cfg.get("tries", 5)), "fails": int(cfg.get("tries", 5)) - won}


func summary(r: Dictionary) -> String:
	return ("Gắp được %d con thú bông." % int(r.won)) if int(r.won) > 0 else "Tuột cả. Máy này kẹp lỏng thật."


# ---------------------------------------------------------------- vẽ

## Thú bông: gấu (tai tròn), thỏ (tai dài), mèo (tai nhọn); thân tròn có bóng, mắt, mõm.
func _plush(p: Vector2, rad: float, col: Color, kind: int) -> void:
	soft_shadow_circle(p + Vector2(4, rad * 0.6), rad * 0.9, 0.35)
	match kind:
		0:
			disc(p + Vector2(-rad * 0.65, -rad * 0.75), rad * 0.38, col, col.darkened(0.3))
			disc(p + Vector2(rad * 0.65, -rad * 0.75), rad * 0.38, col, col.darkened(0.3))
		1:
			for sx in [-1.0, 1.0]:
				var e := PackedVector2Array([p + Vector2(sx * rad * 0.35, -rad * 0.5), p + Vector2(sx * rad * 0.55, -rad * 1.7), p + Vector2(sx * rad * 0.1, -rad * 0.6)])
				draw_colored_polygon(e, col.darkened(0.1))
		_:
			for sx in [-1.0, 1.0]:
				var e := PackedVector2Array([p + Vector2(sx * rad * 0.85, -rad * 0.3), p + Vector2(sx * rad * 0.7, -rad * 1.2), p + Vector2(sx * rad * 0.2, -rad * 0.75)])
				draw_colored_polygon(e, col.darkened(0.1))
	disc(p, rad, col, col.darkened(0.3))
	draw_circle(p + Vector2(0, rad * 0.25), rad * 0.36, col.lightened(0.35))
	draw_circle(p + Vector2(-rad * 0.32, -rad * 0.12), rad * 0.1, Color(0.08, 0.08, 0.08))
	draw_circle(p + Vector2(rad * 0.32, -rad * 0.12), rad * 0.1, Color(0.08, 0.08, 0.08))
	draw_circle(p + Vector2(-rad * 0.29, -rad * 0.16), rad * 0.035, Color(1, 1, 1))
	draw_circle(p + Vector2(0, rad * 0.16), rad * 0.07, Color(0.25, 0.12, 0.1))


func _draw() -> void:
	# Hành lang quán net tối, sàn gạch.
	grad_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.07, 0.12), Color(0.02, 0.02, 0.04))
	var cab := Rect2(size.x * 0.22, size.y * 0.03, size.x * 0.56, size.y * 0.96)
	soft_shadow(cab, Vector2(10, 14), 22.0, 0.7)
	grad_rect(cab, Color(0.85, 0.18, 0.5), Color(0.45, 0.08, 0.3), false)
	# Biển trên nóc: chữ GẮP THÚ, bóng đèn nháy theo vòng.
	var sign_r := Rect2(cab.position + Vector2(24, 14), Vector2(cab.size.x - 48, cab.size.y * 0.1))
	draw_rect(sign_r, Color(0.12, 0.04, 0.12))
	for k in 16:
		var on := (int(_t * 6.0) + k) % 3 == 0
		var bp := Vector2(sign_r.position.x + 12 + k * (sign_r.size.x - 24) / 15.0, sign_r.position.y + 8)
		if on:
			glow(bp, 14.0, Color(1, 0.85, 0.4, 0.9))
		draw_circle(bp, 4, Color(1, 0.9, 0.55) if on else Color(0.45, 0.35, 0.2))
	glow(sign_r.get_center(), sign_r.size.x * 0.45, Color(1, 0.4, 0.75, 0.25))
	text_at(sign_r.get_center() + Vector2(0, 16), "GẮP THÚ", 42, Color(1, 0.92, 0.98))
	# Ô kính: lòng tủ, đèn trần, đống thú bông, cần gắp, kính phản chiếu.
	var box := Rect2(cab.position.x + 30, sign_r.end.y + 16, cab.size.x - 60, cab.size.y * 0.58)
	grad_rect(box, Color(0.22, 0.25, 0.42), Color(0.12, 0.12, 0.22))
	glow(Vector2(box.get_center().x, box.position.y), box.size.x * 0.6, Color(0.9, 0.9, 1.0, 0.3))
	var floor_y := box.end.y - box.size.y * 0.14
	# Đống thú phía sau (trang trí), mờ hơn.
	for row in 2:
		for k in 9:
			_plush(Vector2(box.position.x + 30 + k * (box.size.x - 60) / 8.0 + row * 24.0, floor_y - 58 + row * 26 + float((k * 7) % 9)), 22.0, Color.from_hsv(fposmod(k * 0.13 + row * 0.4, 1.0), 0.35, 0.62 + row * 0.08), (k + row) % 3)
	draw_rect(Rect2(box.position.x, floor_y, box.size.x, box.end.y - floor_y), Color(0.3, 0.26, 0.4))
	for t in toys:
		if t.gone:
			continue
		_plush(Vector2(box.position.x + float(t.x) * box.size.x, floor_y - 12), 25.0, t.col, int(t.get("kind", 0)))
	# Ray và cần gắp ba ngàm.
	var cx := box.position.x + claw_x * box.size.x
	var top := box.position.y + 18
	var cy := top + depth * (floor_y - 52 - top)
	draw_rect(Rect2(box.position.x, top - 8, box.size.x, 10), Color(0.6, 0.62, 0.66))
	draw_rect(Rect2(cx - 22, top - 14, 44, 18), Color(0.75, 0.76, 0.8))
	draw_line(Vector2(cx, top), Vector2(cx, cy), Color(0.82, 0.83, 0.86), 2.0)
	disc(Vector2(cx, cy), 16.0, Color(0.75, 0.76, 0.8), Color(0.4, 0.41, 0.45))
	var open := 30.0 if phase == "move" or (phase == "down" and depth < 0.9) else 12.0
	for sx in [-1.0, 0.0, 1.0]:
		var mid := Vector2(cx + sx * open, cy + 30)
		var tipp := Vector2(cx + sx * open * 0.55, cy + 54)
		draw_line(Vector2(cx, cy), mid, Color(0.72, 0.73, 0.77), 7.0)
		draw_line(mid, tipp, Color(0.72, 0.73, 0.77), 6.0)
		draw_line(Vector2(cx, cy) + Vector2(-1, -1), mid + Vector2(-1, -1), Color(1, 1, 1, 0.5), 1.5)
	if holding >= 0:
		_plush(Vector2(cx, cy + 46), 23.0, toys[holding].col, int(toys[holding].get("kind", 0)))
	# Lỗ trả quà ở góc trái, kính phản chiếu.
	draw_rect(Rect2(box.position.x + 8, floor_y - 70, 90, 70), Color(0.85, 0.85, 0.9, 0.18))
	draw_rect(Rect2(box.position.x + 8, floor_y - 70, 90, 70), Color(1, 1, 1, 0.35), false, 2.0)
	for k in 3:
		var x0 := box.position.x + box.size.x * (0.15 + k * 0.3)
		draw_colored_polygon(PackedVector2Array([Vector2(x0, box.position.y), Vector2(x0 + 40, box.position.y), Vector2(x0 - 60, box.end.y), Vector2(x0 - 100, box.end.y)]), Color(1, 1, 1, 0.05))
	draw_rect(box, Color(0.95, 0.75, 0.9), false, 4.0)
	# Bảng điều khiển: cần gạt, nút đỏ, khe xu.
	var panel := Rect2(cab.position.x + 20, box.end.y + 18, cab.size.x - 40, cab.size.y * 0.13)
	grad_rect(panel, Color(0.25, 0.25, 0.3), Color(0.12, 0.12, 0.15))
	var joy := Vector2(panel.position.x + panel.size.x * 0.25, panel.get_center().y)
	draw_line(joy, joy + Vector2((claw_x - 0.5) * 30.0, -34), Color(0.15, 0.15, 0.16), 8.0)
	disc(joy + Vector2((claw_x - 0.5) * 30.0, -38), 16.0, Color(0.85, 0.15, 0.15), Color(0.45, 0.06, 0.06))
	disc(Vector2(panel.position.x + panel.size.x * 0.65, panel.get_center().y), 24.0 if phase == "move" else 21.0, Color(0.95, 0.25, 0.2), Color(0.5, 0.08, 0.06))
	draw_rect(Rect2(panel.end.x - 70, panel.position.y + 16, 44, 26), Color(0.08, 0.08, 0.1))
	draw_rect(Rect2(panel.end.x - 52, panel.position.y + 20, 8, 18), Color(0.7, 0.6, 0.2))
	text_at(Vector2(panel.end.x - 48, panel.end.y - 10), "XU", 13, Color(0.9, 0.85, 0.6))
	# Viền đèn neon quanh tủ.
	var pulse := 0.6 + 0.4 * sin(_t * 4.0)
	draw_rect(cab, Color(1, 0.5, 0.85, pulse), false, 4.0)
	vignette(0.6)
	text_at(Vector2(size.x * 0.11, size.y * 0.1), "Lượt %d/%d" % [mini(tries_used + 1, int(cfg.get("tries", 5))), int(cfg.get("tries", 5))], 22, UI.HUD_TEXT)
	text_at(Vector2(size.x * 0.11, size.y * 0.16), "Gắp được %d" % won, 20, UI.GOLD)
	text_at(Vector2(size.x * 0.89, size.y * 0.1), "Space hoặc chạm", 16, UI.INK_SOFT)
	text_at(Vector2(size.x * 0.89, size.y * 0.15), "để thả cần", 16, UI.INK_SOFT)
