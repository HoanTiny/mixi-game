extends "res://scripts/minigames/views/minigame_view.gd"
## Nạp ga điều hòa: kim đồng hồ áp suất tự tụt dần (máy nén hút) và rung nhẹ. Giữ Space / chuột (hay chạm giữ) để mở van
## nạp ga cho kim lên; giữ kim trong vùng xanh đủ số giây là xong một máy. Kim chạm vùng đỏ là xả ga, mất ga và tính lỗi.
## cfg: units (số máy), holdSeconds (giây cần giữ trong vùng xanh mỗi máy), seconds (giờ tối đa mỗi máy), rise, fall
## (tốc độ kim lên khi nạp, tụt khi không nạp, phần thang mỗi giây), band (nửa bề rộng vùng xanh), jitter (rung kim).
## Kết quả thô: {"score": máy xong / số máy (máy dở tính theo phần đã giữ), "done", "units", "fails": số lần xả ga}.

var unit := 0
var needle := 0.2
var vel := 0.0
var holding := false
var held := 0.0
var done := 0
var partial := 0.0
var vents := 0
var target := 0.6
var _t := 0.0
var _in_red := false
var _rng := RandomNumberGenerator.new()


func rules() -> String:
	return "Giữ Space hoặc giữ chuột để mở van nạp ga, kim áp suất lên; buông ra thì kim tụt. Giữ kim trong vùng xanh đủ %d giây là xong một máy. Kim chạm vùng đỏ là xả ga. Có %d máy." % [int(cfg.get("holdSeconds", 5)), int(cfg.get("units", 3))]


func _setup() -> void:
	_rng.randomize()


func _begin() -> void:
	_next_unit()


func _next_unit() -> void:
	needle = 0.15
	vel = 0.0
	held = 0.0
	_t = 0.0
	target = _rng.randf_range(0.45, 0.7)


func _play_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode in [KEY_SPACE, KEY_ENTER]:
		holding = event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		holding = event.pressed
	elif event is InputEventScreenTouch:
		holding = event.pressed


## Một bước của kim: có quán tính để khó giữ (nạp xong kim vẫn còn đà lên).
static func step(c: Dictionary, n: float, v: float, open: bool, dt: float, noise: float) -> Vector2:
	var acc := float(c.get("rise", 0.55)) if open else -float(c.get("fall", 0.32))
	v = lerpf(v, acc, clampf(dt * 3.0, 0.0, 1.0))
	n = clampf(n + v * dt + noise * float(c.get("jitter", 0.02)) * dt * 10.0, 0.0, 1.0)
	return Vector2(n, v)


func _play(delta: float) -> void:
	_t += delta
	var r := step(cfg, needle, vel, holding, delta, _rng.randf_range(-1.0, 1.0))
	needle = r.x
	vel = r.y
	var band := float(cfg.get("band", 0.07))
	if absf(needle - target) <= band:
		held += delta
	var red := needle >= 0.92
	if red and not _in_red:
		vents += 1
		needle = 0.55
		vel = -0.4
	_in_red = red
	var need := float(cfg.get("holdSeconds", 5.0))
	if held >= need or _t >= float(cfg.get("seconds", 25.0)):
		if held >= need:
			done += 1
		else:
			partial += held / need
		unit += 1
		if unit >= int(cfg.get("units", 3)):
			end()
		else:
			_next_unit()


func result() -> Dictionary:
	var n := int(cfg.get("units", 3))
	return {"score": (float(done) + partial) / float(maxi(1, n)), "done": done, "units": n, "fails": vents}


func summary(r: Dictionary) -> String:
	return "Nạp xong %d/%d máy." % [int(r.done), int(r.units)] + ("" if int(r.fails) == 0 else " Xả ga %d lần." % int(r.fails))


# ---------------------------------------------------------------- vẽ

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("161b20"))
	var c := Vector2(size.x * 0.5, size.y * 0.62)
	var rad := minf(size.x, size.y) * 0.32
	var a0 := PI * 0.85
	var a1 := PI * 2.15
	draw_arc(c, rad, a0, a1, 64, Color("e9e6dd"), rad * 0.16)
	var band := float(cfg.get("band", 0.07))
	draw_arc(c, rad, lerpf(a0, a1, target - band), lerpf(a0, a1, target + band), 24, Color("3f9a5e"), rad * 0.16)
	draw_arc(c, rad, lerpf(a0, a1, 0.92), a1, 16, Color("c0392b"), rad * 0.16)
	for i in 11:
		var a := lerpf(a0, a1, i / 10.0)
		draw_line(c + Vector2(cos(a), sin(a)) * rad * 0.78, c + Vector2(cos(a), sin(a)) * rad * 0.9, Color("6b6f75"), 2.0)
	var an := lerpf(a0, a1, needle)
	draw_line(c, c + Vector2(cos(an), sin(an)) * rad * 0.85, Color("d64a3a"), 4.0)
	draw_circle(c, 9.0, Color("2a2d31"))
	# Giây đã giữ trong vùng xanh.
	bar_at(Rect2(size.x * 0.3, size.y * 0.14, size.x * 0.4, 12), held / float(cfg.get("holdSeconds", 5.0)), Color("3f9a5e"))
	text_at(Vector2(size.x * 0.5, size.y * 0.1), "Máy %d/%d · xả ga %d lần" % [mini(unit + 1, int(cfg.get("units", 3))), int(cfg.get("units", 3)), vents], 20, UI.HUD_TEXT)
	text_at(Vector2(size.x * 0.5, size.y * 0.95), "Giữ Space/chuột để nạp ga" + ("  · đang nạp" if holding else ""), 16, UI.INK_SOFT)
