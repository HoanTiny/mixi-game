extends "res://scripts/minigames/views/minigame_view.gd"
## Bê gạch (nhìn ngang): An gánh hai sọt gạch trên đòn gánh từ xe (trái) sang khuôn xếp (phải). Đi đường thì đòn gánh
## chao như con lắc ngược: giữ A / D (hay mũi tên, hay giữ chạm nửa trái / phải màn) để dồn sức về một bên cho cân;
## nghiêng quá maxTilt là đổ gạch, quay lại xe lấy chuyến khác. Tới khuôn thì sọt gạch đung đưa phía trên, bấm Space
## (hay chạm) đúng lúc sọt ở giữa khuôn để thả: lệch trong tolerance là xếp thẳng (1 chuyến), lệch tới hai lần là xếp
## xiêu (0,5 chuyến), xa hơn là đổ. Hết giờ thì tính.
## cfg: seconds, target (số chuyến), walkSec, returnSec, instability, noise, torque, damping, maxTilt, swing, tolerance.
## Kết quả thô: {"score": số chuyến tính được / target, "delivered", "target", "fails": số lần đổ}.

## "carry" (gánh đi), "drop" (căn chỗ thả), "return" (về xe), "fallen" (vừa đổ gạch)
var phase := "carry"
var time_left := 0.0
var walk := 0.0
var tilt := 0.0
var spin := 0.0
## -1 (dồn trái, A) .. 1 (dồn phải, D); đặt từ phím hay chạm, bài kiểm tra đặt thẳng.
var steer := 0.0
var swing_x := 0.0
var delivered := 0.0
var fails := 0
var layers: Array = []
var _t := 0.0
var _gust := 0.0
var _gust_to := 0.0
var _gust_t := 0.0
var _touch := 0.0
var _flash := ""
var _rng := RandomNumberGenerator.new()


func rules() -> String:
	return "Giữ A / D (hay mũi tên, hay giữ chạm nửa trái / phải màn hình) để giữ đòn gánh thăng bằng trên đường đi: lệch phải thì dồn sang trái (A), lệch trái thì dồn sang phải (D). Nghiêng quá vạch đỏ là đổ gạch. Tới khuôn, bấm Space (hay chạm) khi sọt gạch ở giữa khuôn để thả. Cần %d chuyến trong %d giây." % [int(cfg.get("target", 8)), int(float(cfg.get("seconds", 80)))]


func _setup() -> void:
	_rng.randomize()
	time_left = float(cfg.get("seconds", 80))


func _begin() -> void:
	_start_trip()


func _start_trip() -> void:
	phase = "carry"
	walk = 0.0
	tilt = _rng.randf_range(-0.05, 0.05)
	spin = 0.0
	_t = 0.0


func _play(delta: float) -> void:
	time_left -= delta
	if time_left <= 0.0:
		time_left = 0.0
		end()
		return
	var keys := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		keys -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		keys += 1.0
	steer = clampf(keys + _touch, -1.0, 1.0)
	step(delta)


## Một bước mô phỏng (gọi từ _play; bài kiểm tra gọi thẳng với steer tự đặt).
func step(delta: float) -> void:
	_t += delta
	match phase:
		"carry":
			_gust_t -= delta
			if _gust_t <= 0.0:
				_gust_t = _rng.randf_range(0.4, 0.9)
				_gust_to = _rng.randf_range(-1.0, 1.0) * float(cfg.get("noise", 1.4))
			_gust = lerpf(_gust, _gust_to, minf(1.0, delta * 3.0))
			var acc := float(cfg.get("instability", 3.2)) * sin(tilt) + _gust - float(cfg.get("damping", 1.2)) * spin \
				+ steer * float(cfg.get("torque", 7.0))
			spin += acc * delta
			tilt += spin * delta
			walk += delta / float(cfg.get("walkSec", 3.2))
			if absf(tilt) > float(cfg.get("maxTilt", 0.55)):
				fails += 1
				_flash = "Đổ gạch!"
				phase = "fallen"
				_t = 0.0
			elif walk >= 1.0:
				walk = 1.0
				phase = "drop"
				_t = 0.0
		"drop":
			swing_x = sin(_t * TAU * float(cfg.get("swing", 0.7)))
		"return":
			walk -= delta / float(cfg.get("returnSec", 1.2))
			if walk <= 0.0:
				_start_trip()
		"fallen":
			if _t >= 0.8:
				phase = "return"
				walk = maxf(walk, 0.01)


## Thả sọt gạch xuống khuôn tại vị trí đang đung đưa.
func drop() -> void:
	if phase != "drop":
		return
	var err := absf(swing_x)
	var tol := float(cfg.get("tolerance", 0.22))
	if err <= tol:
		delivered += 1.0
		layers.append(swing_x * 0.3)
		_flash = "Xếp thẳng!"
	elif err <= tol * 2.0:
		delivered += 0.5
		layers.append(swing_x * 0.6)
		_flash = "Xiêu một chút"
	else:
		fails += 1
		_flash = "Lệch khuôn, gạch đổ!"
	phase = "return"
	_t = 0.0


func _play_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_W, KEY_UP]:
			drop()
		return
	var pos := Vector2.ZERO
	var pressed := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
		pressed = event.pressed
	elif event is InputEventScreenTouch:
		pos = event.position
		pressed = event.pressed
	else:
		return
	if phase == "drop" and pressed:
		drop()
	else:
		_touch = (-1.0 if pos.x < size.x / 2.0 else 1.0) if pressed else 0.0


func result() -> Dictionary:
	var target := int(cfg.get("target", 8))
	return {"score": delivered / float(maxi(1, target)), "delivered": delivered, "target": target, "fails": fails}


func summary(r: Dictionary) -> String:
	return "Xếp được %s/%d chuyến gạch, đổ %d lần." % [str(r.delivered).replace(".", ",").trim_suffix(",0"), int(r.target), int(r.fails)]


# ---------------------------------------------------------------- vẽ

func _draw() -> void:
	var ground := size.y * 0.78
	var x0 := size.x * 0.14
	var x1 := size.x * 0.8
	# Bãi vật liệu ven sông: trời mù, dải sông, nhịp cầu sắt và dãy nhà xa, bãi đất.
	draw_rect(Rect2(Vector2.ZERO, size), Color("b9c6cc"))
	draw_rect(Rect2(0, size.y * 0.42, size.x, size.y * 0.08), Color("9fb0b2"))
	for i in 9:
		var bx := size.x * (i / 8.0)
		draw_line(Vector2(bx, size.y * 0.36), Vector2(bx + size.x / 16.0, size.y * 0.3), Color("7d878a"), 3.0)
		draw_line(Vector2(bx + size.x / 16.0, size.y * 0.3), Vector2(bx + size.x / 8.0, size.y * 0.36), Color("7d878a"), 3.0)
	draw_line(Vector2(0, size.y * 0.36), Vector2(size.x, size.y * 0.36), Color("6d777a"), 4.0)
	for i in 12:
		var h := size.y * (0.05 + 0.04 * float((i * 7) % 4))
		draw_rect(Rect2(size.x * i / 12.0, size.y * 0.5 - h, size.x / 13.0, h), Color("9aa29a"))
	draw_rect(Rect2(0, size.y * 0.5, size.x, ground - size.y * 0.5), Color("8f9a8a"))
	draw_rect(Rect2(0, ground, size.x, size.y - ground), Color("a08060"))
	var k := size.y / 720.0
	# Xe gạch bên trái, khuôn xếp bên phải với các lớp đã xếp.
	draw_rect(Rect2(size.x * 0.01, ground - 70, size.x * 0.1, 60), Color("4a6a8a"))
	for r in 3:
		for c in 4:
			draw_rect(Rect2(size.x * 0.015 + c * size.x * 0.022, ground - 100 - r * 12, size.x * 0.02, 10), Color("b5532f"))
	var mold := Rect2(x1 + size.x * 0.03, ground - 14, size.x * 0.12, 14)
	draw_rect(mold, Color("6a5a4a"), false, 3.0)
	for i in layers.size():
		var off: float = layers[i] * mold.size.x * 0.5
		draw_rect(Rect2(mold.position.x + off + 4, ground - 14 - (i + 1) * 12, mold.size.x - 8, 11), Color("c0603a"))
	# An gánh gạch.
	var ax := lerpf(x0, x1, walk)
	var shoulder := Vector2(ax, ground - 190.0 * k)
	var hip := Vector2(ax, ground - 95.0 * k)
	draw_line(Vector2(ax - 18.0 * k, ground), hip, Color("2d3a4a"), 10.0 * k)
	draw_line(Vector2(ax + 18.0 * k, ground), hip, Color("2d3a4a"), 10.0 * k)
	draw_line(hip, shoulder + Vector2(0, 10.0 * k), Color("5d7a8a"), 18.0 * k)
	draw_circle(shoulder + Vector2(0, -24.0 * k), 20.0 * k, Color("e0b896"))
	draw_colored_polygon(PackedVector2Array([shoulder + Vector2(-34, -38) * k, shoulder + Vector2(34, -38) * k, shoulder + Vector2(0, -62) * k]), Color("d8c08a"))
	var half := Vector2(cos(tilt), sin(tilt)) * 120.0 * k
	if phase in ["carry", "drop"]:
		draw_line(shoulder - half, shoulder + half, Color("7a5a2a"), 7.0 * k)
		for end_p in [shoulder - half, shoulder + half]:
			if phase == "drop" and end_p == shoulder + half:
				continue
			draw_line(end_p, end_p + Vector2(0, 45.0 * k), Color("5a4a3a"), 2.0)
			draw_rect(Rect2(end_p + Vector2(-26, 45) * k, Vector2(52, 34) * k), Color("b5532f"))
			draw_line(end_p + Vector2(-26, 62) * k, end_p + Vector2(26, 62) * k, Color("8a3a20"), 2.0)
	if phase == "drop":
		var hx := mold.get_center().x + swing_x * mold.size.x
		var hy := ground - 14 - (layers.size() + 1) * 12 - 90.0 * k
		draw_line(Vector2(hx, hy - 50.0 * k), Vector2(hx, hy), Color("5a4a3a"), 2.0)
		draw_rect(Rect2(Vector2(hx - 26.0 * k, hy), Vector2(52, 34) * k), Color("b5532f"))
		draw_dashes(Vector2(mold.get_center().x, hy - 10), Vector2(mold.get_center().x, ground - 14))
	# Thước nghiêng: vùng xanh an toàn, vạch đỏ là đổ.
	var gauge := Rect2(size.x * 0.3, size.y * 0.1, size.x * 0.4, 16)
	var mt := float(cfg.get("maxTilt", 0.55))
	draw_rect(gauge, Color(0, 0, 0, 0.5))
	draw_rect(Rect2(gauge.get_center().x - gauge.size.x * 0.25, gauge.position.y, gauge.size.x * 0.5, gauge.size.y), Color(0.3, 0.7, 0.35, 0.55))
	var needle := gauge.get_center().x + clampf(tilt / mt, -1.0, 1.0) * gauge.size.x * 0.5
	draw_line(Vector2(needle, gauge.position.y - 4), Vector2(needle, gauge.end.y + 4), Color.WHITE, 3.0)
	draw_line(Vector2(gauge.position.x, gauge.position.y - 4), Vector2(gauge.position.x, gauge.end.y + 4), Color("e0604f"), 3.0)
	draw_line(Vector2(gauge.end.x, gauge.position.y - 4), Vector2(gauge.end.x, gauge.end.y + 4), Color("e0604f"), 3.0)
	# Giờ, số chuyến, gợi ý phím.
	bar_at(Rect2(size.x * 0.3, size.y * 0.05, size.x * 0.4, 10), time_left / maxf(1.0, float(cfg.get("seconds", 80))), Color("e8b45a"))
	text_at(Vector2(size.x * 0.5, size.y * 0.2), "Chuyến %s/%d · Đổ %d · %d giây" % [str(delivered).replace(".", ",").trim_suffix(",0"),
		int(cfg.get("target", 8)), fails, int(ceil(time_left))], 22, Color("1c1712"))
	if state == "play":
		var hint: String = {"carry": "Giữ A / D cho cân", "drop": "Bấm Space khi sọt ở giữa khuôn", "return": _flash, "fallen": _flash}.get(phase, "")
		text_at(Vector2(size.x * 0.5, size.y * 0.94), hint, 20, Color("1c1712"))
		for side in [[-1.0, "A"], [1.0, "D"]]:
			var c := Vector2(size.x * (0.06 if side[0] < 0.0 else 0.94), size.y * 0.9)
			draw_circle(c, 26.0, Color(0, 0, 0, 0.55 if steer * side[0] > 0.0 else 0.25))
			text_at(c + Vector2(0, 8), side[1], 24, Color.WHITE)


func draw_dashes(a: Vector2, b: Vector2) -> void:
	var n := int(a.distance_to(b) / 10.0)
	for i in n:
		if i % 2 == 0:
			draw_line(a.lerp(b, float(i) / n), a.lerp(b, float(i + 1) / n), Color(1, 1, 1, 0.6), 2.0)
