extends "res://scripts/minigames/views/minigame_view.gd"
## Ném vòng cổ chai (nhìn ngang): hàng chai đứng trên bàn, An đứng bên trái. Mỗi vòng bấm hai lần: lần đầu chốt góc
## ném (kim đảo qua lại trên cung), lần sau chốt lực (thanh lực lên xuống). Vòng bay theo đường parabol, gió đẩy ngang;
## lúc rơi tới tầm cổ chai mà lọt vào cổ chai nào thì trúng. Có dấu chỗ vòng trước rơi để căn lại.
## Đơn vị mét. cfg: rings, bottles, firstBottle, gap, neck (nửa bề rộng lọt cổ chai), sweep, powerSweep (lượt/giây),
## angleMin, angleMax (độ), speedMin, speedMax (m/s), windMax, windAccel (m/s² ở gió 1).
## Kết quả thô: {"score": số vòng trúng / số vòng, "hits", "rings", "fails": số vòng trượt}.

const HAND := Vector2(0.0, 1.35)
const TABLE_Y := 0.75
const NECK_Y := 1.05
const G := 9.8

## "angle" (đang chọn góc), "power" (đang chọn lực), "fly" (vòng đang bay), "rest" (xem kết quả vòng vừa ném)
var phase := "angle"
var thrown := 0
var hits := 0
var angle := 45.0
var power := 0.5
var wind := 0.0
var landed: Array = []
var _t := 0.0
var _flight: Dictionary = {}
var _last_x := INF
var _rng := RandomNumberGenerator.new()


func rules() -> String:
	return "Bấm Space (hay chạm màn hình) hai lần cho mỗi vòng: lần đầu chốt góc ném, lần sau chốt lực. Gió đẩy vòng sang ngang, xem cờ gió trước khi ném. Vòng lọt vào cổ chai nào là trúng. Có %d vòng." % int(cfg.get("rings", 5))


func _setup() -> void:
	_rng.randomize()


func _begin() -> void:
	_next_ring()


func _next_ring() -> void:
	phase = "angle"
	_t = 0.0
	var wm := float(cfg.get("windMax", 1.0))
	wind = snappedf(_rng.randf_range(-wm, wm), 0.1)


## Chốt góc rồi chốt lực; lần chốt lực là ném.
func press() -> void:
	match phase:
		"angle":
			phase = "power"
			_t = 0.0
		"power":
			_flight = flight(cfg, angle, power, wind)
			phase = "fly"
			_t = 0.0


func _play_input(event: InputEvent) -> void:
	var down: bool = (event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER]) \
		or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if down:
		press()


func _play(delta: float) -> void:
	_t += delta
	match phase:
		"angle":
			var k := _pingpong(_t * float(cfg.get("sweep", 0.5)))
			angle = lerpf(float(cfg.get("angleMin", 30)), float(cfg.get("angleMax", 62)), k)
		"power":
			power = _pingpong(_t * float(cfg.get("powerSweep", 0.4)))
		"fly":
			if _t >= float(_flight.t_end):
				thrown += 1
				_last_x = float(_flight.x)
				if int(_flight.hit) >= 0:
					hits += 1
					landed.append(int(_flight.hit))
				phase = "rest"
				_t = 0.0
		"rest":
			if _t >= 0.9:
				if thrown >= int(cfg.get("rings", 5)):
					end()
				else:
					_next_ring()


## 0 → 1 → 0 theo x (một lượt đi về mỗi đơn vị x).
static func _pingpong(x: float) -> float:
	var f := fposmod(x, 1.0) * 2.0
	return f if f <= 1.0 else 2.0 - f


## Đường bay của một vòng: x khi rơi tới tầm cổ chai, chai trúng (-1 nếu trượt), giờ kết thúc hoạt cảnh và vận tốc,
## gia tốc để vẽ. Không phụ thuộc nút (kiểm tra được headless).
static func flight(c: Dictionary, angle_deg: float, pw: float, w: float) -> Dictionary:
	var v := lerpf(float(c.get("speedMin", 4.6)), float(c.get("speedMax", 6.2)), clampf(pw, 0.0, 1.0))
	var a := deg_to_rad(angle_deg)
	var vx := v * cos(a)
	var vy := v * sin(a)
	var ax := w * float(c.get("windAccel", 1.6))
	var t_neck := (vy + sqrt(vy * vy + 2.0 * G * (HAND.y - NECK_Y))) / G
	var x := HAND.x + vx * t_neck + 0.5 * ax * t_neck * t_neck
	var hit := -1
	for i in int(c.get("bottles", 6)):
		if absf(x - bottle_x(c, i)) <= float(c.get("neck", 0.08)):
			hit = i
	# Trượt thì vòng rơi tiếp xuống mặt bàn (hay đất nếu ra ngoài bàn).
	var floor_y := TABLE_Y if x > bottle_x(c, 0) - 0.3 and x < bottle_x(c, int(c.get("bottles", 6)) - 1) + 0.3 else 0.0
	var t_end := t_neck if hit >= 0 else (vy + sqrt(vy * vy + 2.0 * G * (HAND.y - floor_y))) / G
	return {"x": x, "hit": hit, "t_neck": t_neck, "t_end": t_end, "vx": vx, "vy": vy, "ax": ax}


static func bottle_x(c: Dictionary, i: int) -> float:
	return float(c.get("firstBottle", 2.4)) + float(i) * float(c.get("gap", 0.36))


func result() -> Dictionary:
	var rings := int(cfg.get("rings", 5))
	return {"score": float(hits) / float(maxi(1, rings)), "hits": hits, "rings": rings, "fails": thrown - hits}


func summary(r: Dictionary) -> String:
	return "Trúng %d/%d vòng." % [int(r.hits), int(r.rings)] + ("" if int(r.hits) > 0 else " Lần sau xem kỹ gió rồi hãy ném.")


# ---------------------------------------------------------------- vẽ

## Mét → điểm ảnh: khung rộng 5,6 m (chừa chỗ thanh lực bên trái), cao 2,6 m, đất ở 82% chiều cao màn.
func _px(p: Vector2) -> Vector2:
	return Vector2(size.x * 0.15 + p.x * _m(), size.y * 0.82 - p.y * _m())


func _m() -> float:
	return minf(size.x / 5.6, size.y * 0.7 / 2.6)


func _draw() -> void:
	var s := _m()
	# Trời chạng vạng phố đi bộ, dây đèn, mặt đất.
	draw_rect(Rect2(Vector2.ZERO, size), Color("1d2233"))
	draw_rect(Rect2(0, size.y * 0.45, size.x, size.y * 0.37), Color("2b2a33"))
	for i in 18:
		var x := size.x * (i + 0.5) / 18.0
		var y := size.y * 0.1 + sin(float(i) * 0.7) * 10.0
		draw_circle(Vector2(x, y), 5.0, Color("f5c76a") if i % 3 != 0 else Color("e8735a"))
	draw_rect(Rect2(0, size.y * 0.82, size.x, size.y * 0.18), Color("3a3430"))
	# Bàn và hàng chai.
	var b0 := bottle_x(cfg, 0) - 0.3
	var b1 := bottle_x(cfg, int(cfg.get("bottles", 6)) - 1) + 0.3
	draw_rect(Rect2(_px(Vector2(b0, TABLE_Y)), Vector2((b1 - b0) * s, TABLE_Y * s)), Color("7a4a2a"))
	draw_rect(Rect2(_px(Vector2(b0, TABLE_Y)), Vector2((b1 - b0) * s, 0.05 * s)), Color("a0683c"))
	for i in int(cfg.get("bottles", 6)):
		var bx := bottle_x(cfg, i)
		var body := Rect2(_px(Vector2(bx - 0.05, TABLE_Y + 0.2)), Vector2(0.1 * s, 0.2 * s))
		draw_rect(body, Color("2f7a4a"))
		draw_rect(Rect2(_px(Vector2(bx - 0.02, NECK_Y)), Vector2(0.04 * s, 0.1 * s)), Color("3f9a5e"))
		draw_rect(Rect2(body.position + Vector2(0.015 * s, 0.02 * s), Vector2(0.02 * s, 0.14 * s)), Color(1, 1, 1, 0.25))
		var n := landed.count(i)
		for k in n:
			_ring(_px(Vector2(bx, TABLE_Y + 0.22 + 0.03 * k)), s, Color("f2d04a"))
	# Dấu chỗ vòng trước rơi.
	if _last_x != INF:
		var lp := _px(Vector2(_last_x, NECK_Y))
		draw_line(lp + Vector2(-6, -6), lp + Vector2(6, 6), Color("ff8a7a"), 2.0)
		draw_line(lp + Vector2(-6, 6), lp + Vector2(6, -6), Color("ff8a7a"), 2.0)
	# An: thân, tay ném theo góc.
	var hand := _px(HAND)
	var foot := _px(Vector2(-0.15, 0.0))
	draw_line(foot, foot + Vector2(0, -1.0 * s), Color("d9d2c3"), 6.0)
	draw_circle(foot + Vector2(0, -1.12 * s), 0.11 * s, Color("d9d2c3"))
	var dir := Vector2(cos(deg_to_rad(angle)), -sin(deg_to_rad(angle)))
	draw_line(foot + Vector2(0, -0.85 * s), hand, Color("d9d2c3"), 4.0)
	if phase in ["angle", "power"]:
		draw_line(hand, hand + dir * 0.5 * s, Color(1, 1, 1, 0.8), 2.0)
		_ring(hand, s, Color("f2d04a"))
		# Cung chọn góc.
		var amin := deg_to_rad(float(cfg.get("angleMin", 30)))
		var amax := deg_to_rad(float(cfg.get("angleMax", 62)))
		draw_arc(hand, 0.55 * s, -amax, -amin, 24, Color(1, 1, 1, 0.35), 3.0)
	# Thanh lực bên trái.
	var pr := Rect2(size.x * 0.02, size.y * 0.35, 18, size.y * 0.4)
	draw_rect(pr, Color(0, 0, 0, 0.55))
	var fill := pr.size.y * (power if phase != "angle" else 0.0)
	draw_rect(Rect2(pr.position.x, pr.end.y - fill, pr.size.x, fill), Color("e8b45a"))
	draw_rect(pr, Color(1, 1, 1, 0.4), false, 1.5)
	text_at(Vector2(pr.get_center().x + 4, pr.end.y + 20), "Lực", 13, UI.INK_SOFT)
	# Vòng đang bay.
	if phase == "fly":
		var t := minf(_t, float(_flight.t_end))
		var p := HAND + Vector2(float(_flight.vx) * t + 0.5 * float(_flight.ax) * t * t, float(_flight.vy) * t - 0.5 * G * t * t)
		_ring(_px(p), s, Color("f2d04a"))
	# Gió, số vòng.
	var wc := Vector2(size.x * 0.5, size.y * 0.24)
	text_at(wc, "Gió %s %s" % ["→" if wind > 0.0 else ("←" if wind < 0.0 else "·"), str(absf(wind)).replace(".", ",")], 20, UI.HUD_TEXT)
	var flag := wc + Vector2(-80, -36)
	draw_line(flag, flag + Vector2(0, 30), Color("d9d2c3"), 2.0)
	draw_colored_polygon(PackedVector2Array([flag, flag + Vector2(30.0 * wind, 6), flag + Vector2(0, 12)]), Color("e8735a"))
	text_at(Vector2(size.x * 0.5, size.y * 0.06 + 18), "Vòng %d/%d · Trúng %d" % [mini(thrown + 1, int(cfg.get("rings", 5))), int(cfg.get("rings", 5)), hits], 22, UI.GOLD)
	var hint: String = {"angle": "Bấm để chốt góc ném", "power": "Bấm để chốt lực, ném!", "fly": "", "rest": ""}.get(phase, "")
	if phase == "rest":
		hint = "Trúng!" if int(_flight.hit) >= 0 else "Trượt"
	if state == "play" and hint != "":
		text_at(Vector2(size.x * 0.5, size.y * 0.94), hint, 20, UI.HUD_TEXT)


func _ring(c: Vector2, s: float, col: Color) -> void:
	draw_arc(c, 0.08 * s, 0, TAU, 20, col, 3.0)
