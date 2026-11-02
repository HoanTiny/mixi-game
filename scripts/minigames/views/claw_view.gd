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
		toys.append({"x": 0.12 + i * 0.12 + _rng.randf_range(-0.03, 0.03), "col": Color.from_hsv(_rng.randf(), 0.45, 0.95), "gone": false})


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

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0f1424"))
	var box := Rect2(size.x * 0.2, size.y * 0.1, size.x * 0.6, size.y * 0.78)
	draw_rect(box, Color("23304d"))
	draw_rect(box, Color("ff6fb0"), false, 4.0)
	var floor_y := box.end.y - box.size.y * 0.12
	draw_rect(Rect2(box.position.x, floor_y, box.size.x, box.end.y - floor_y), Color("39314a"))
	for t in toys:
		if t.gone:
			continue
		var p := Vector2(box.position.x + float(t.x) * box.size.x, floor_y - 20)
		draw_circle(p, 22, t.col)
		draw_circle(p + Vector2(-14, -18), 8, t.col)
		draw_circle(p + Vector2(14, -18), 8, t.col)
		draw_circle(p + Vector2(-7, -3), 3, Color("1b1b1b"))
		draw_circle(p + Vector2(7, -3), 3, Color("1b1b1b"))
	var cx := box.position.x + claw_x * box.size.x
	var top := box.position.y + 18
	var cy := top + depth * (floor_y - 46 - top)
	draw_line(Vector2(box.position.x, top), Vector2(box.end.x, top), Color("9aa0a8"), 4.0)
	draw_line(Vector2(cx, top), Vector2(cx, cy), Color("c9ced6"), 2.0)
	var open := 16.0 if phase == "move" or (phase == "down" and depth < 0.9) else 8.0
	draw_line(Vector2(cx, cy), Vector2(cx - open, cy + 20), Color("c9ced6"), 4.0)
	draw_line(Vector2(cx, cy), Vector2(cx + open, cy + 20), Color("c9ced6"), 4.0)
	if holding >= 0:
		draw_circle(Vector2(cx, cy + 34), 20, toys[holding].col)
	text_at(Vector2(size.x * 0.5, size.y * 0.06), "Lượt %d/%d · gắp được %d" % [mini(tries_used + 1, int(cfg.get("tries", 5))), int(cfg.get("tries", 5)), won], 20, UI.HUD_TEXT)
	text_at(Vector2(size.x * 0.5, size.y * 0.96), "Space hoặc chạm để thả cần", 16, UI.INK_SOFT)
