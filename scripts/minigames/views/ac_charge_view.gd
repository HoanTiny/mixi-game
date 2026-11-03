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
var _fan := 0.0


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
	_fan += delta * 9.0
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

## Tường vữa (aged-plaster.png bị loại khỏi bản xuất trong export_presets.cfg, nên dùng vật liệu Poly Haven).
const PLASTER := preload("res://assets/ph/textures/plastered_wall_04/plastered_wall_04_diff.jpg")


## Mặt đồng hồ áp suất: viền mạ, mặt trắng, vạch, số, vùng màu, kim có bóng, kính phản chiếu.
func _gauge(c: Vector2, rad: float, value: float, ring: Color, label: String, active: bool) -> void:
	var a0 := PI * 0.75
	var a1 := PI * 2.25
	soft_shadow_circle(c + Vector2(6, 10), rad * 1.08, 0.6)
	draw_circle(c, rad * 1.1, ring.darkened(0.35))
	draw_circle(c, rad * 1.04, Color(0.82, 0.84, 0.86))
	draw_arc(c, rad * 1.02, PI * 1.1, PI * 1.6, 20, Color(1, 1, 1, 0.8), rad * 0.05)
	draw_circle(c, rad * 0.95, ring)
	draw_circle(c, rad * 0.88, Color(0.97, 0.96, 0.93))
	if active:
		var band := float(cfg.get("band", 0.07))
		draw_arc(c, rad * 0.72, lerpf(a0, a1, target - band), lerpf(a0, a1, target + band), 24, Color(0.2, 0.62, 0.32), rad * 0.13)
		draw_arc(c, rad * 0.72, lerpf(a0, a1, 0.92), a1, 12, Color(0.78, 0.15, 0.12), rad * 0.13)
	for i in 41:
		var a := lerpf(a0, a1, i / 40.0)
		var long := i % 5 == 0
		draw_line(c + Vector2(cos(a), sin(a)) * rad * (0.72 if long else 0.78), c + Vector2(cos(a), sin(a)) * rad * 0.84, Color(0.15, 0.15, 0.16), 2.0 if long else 1.0)
		if i % 10 == 0:
			text_at(c + Vector2(cos(a), sin(a)) * rad * 0.58 + Vector2(0, 5), str(i / 10 * (100 if not active else 25)), int(rad * 0.13), Color(0.15, 0.15, 0.16))
	text_at(c + Vector2(0, rad * 0.38), label, int(rad * 0.13), ring.darkened(0.2))
	var an := lerpf(a0, a1, clampf(value, 0.0, 1.0))
	var tip := c + Vector2(cos(an), sin(an)) * rad * 0.8
	draw_line(c + Vector2(4, 5), tip + Vector2(4, 5), Color(0, 0, 0, 0.25), 4.0)
	draw_line(c - Vector2(cos(an), sin(an)) * rad * 0.15, tip, Color(0.8, 0.12, 0.1), 3.5)
	draw_circle(c, rad * 0.08, Color(0.2, 0.2, 0.22))
	# Kính: vệt sáng chéo.
	draw_arc(c, rad * 0.7, PI * 1.15, PI * 1.45, 16, Color(1, 1, 1, 0.35), rad * 0.18)


## Dàn nóng điều hòa: vỏ tôn sơn trắng, lưới quạt tròn, cánh quạt quay, cổng nạp ga.
func _outdoor_unit(r: Rect2) -> Vector2:
	soft_shadow(r, Vector2(10, 14), 16.0, 0.55)
	grad_rect(r, Color(0.93, 0.93, 0.9), Color(0.8, 0.8, 0.77))
	draw_rect(r, Color(0.55, 0.55, 0.53), false, 2.0)
	for j in 16:
		draw_line(Vector2(r.position.x + r.size.x * 0.68, r.position.y + 20 + j * (r.size.y - 40) / 15.0), Vector2(r.end.x - 14, r.position.y + 20 + j * (r.size.y - 40) / 15.0), Color(0.55, 0.55, 0.53), 2.0)
	var fc := Vector2(r.position.x + r.size.x * 0.36, r.get_center().y)
	var fr := r.size.y * 0.4
	draw_circle(fc, fr, Color(0.15, 0.16, 0.17))
	for k in 3:
		var a := _fan + k * TAU / 3.0
		var blade := PackedVector2Array([fc, fc + Vector2(cos(a - 0.35), sin(a - 0.35)) * fr * 0.92, fc + Vector2(cos(a + 0.15), sin(a + 0.15)) * fr * 0.95])
		draw_colored_polygon(blade, Color(0.55, 0.57, 0.6))
	for k in 6:
		draw_arc(fc, fr * (0.3 + k * 0.13), 0, TAU, 40, Color(0.75, 0.75, 0.73), 2.0)
	for k in 8:
		var a := k * TAU / 8.0
		draw_line(fc, fc + Vector2(cos(a), sin(a)) * fr, Color(0.75, 0.75, 0.73), 2.0)
	draw_circle(fc, fr * 0.12, Color(0.7, 0.7, 0.68))
	text_at(Vector2(r.position.x + r.size.x * 0.36, r.end.y - 12), "INVERTER", 13, Color(0.45, 0.45, 0.48))
	var port := Vector2(r.end.x - 26, r.end.y - 40)
	draw_circle(port, 10, Color(0.72, 0.6, 0.3))
	return port


## Bình ga R32: thân thép sơn, vai bo tròn, van, nhãn.
func _cylinder(r: Rect2) -> Vector2:
	var w := r.size.x
	var body := Rect2(r.position + Vector2(0, w * 0.5), Vector2(w, r.size.y - w * 0.5))
	soft_shadow(body, Vector2(8, 10), 12.0, 0.5)
	draw_circle(Vector2(r.get_center().x, body.position.y), w * 0.5, Color(0.3, 0.6, 0.67))
	draw_arc(Vector2(r.get_center().x, body.position.y), w * 0.42, PI * 1.15, PI * 1.5, 12, Color(1, 1, 1, 0.3), 5.0)
	grad_rect(body, Color(0.36, 0.67, 0.74), Color(0.22, 0.46, 0.52), false)
	draw_rect(Rect2(body.position + Vector2(w * 0.12, 0), Vector2(w * 0.08, body.size.y)), Color(1, 1, 1, 0.18))
	draw_rect(Rect2(r.position + Vector2(r.size.x * 0.2, r.size.y * 0.35), Vector2(r.size.x * 0.6, r.size.y * 0.3)), Color(0.95, 0.95, 0.92))
	text_at(Vector2(r.get_center().x, r.position.y + r.size.y * 0.5 + 8), "R32", int(r.size.x * 0.28), Color(0.15, 0.35, 0.4))
	var valve := Vector2(r.get_center().x, r.position.y - 16)
	draw_rect(Rect2(valve - Vector2(8, 0), Vector2(16, 20)), Color(0.7, 0.62, 0.3))
	draw_circle(valve, 14, Color(0.75, 0.15, 0.12) if holding else Color(0.55, 0.12, 0.1))
	return valve


func _draw() -> void:
	tex_fill(Rect2(Vector2.ZERO, size), PLASTER, Color(0.78, 0.74, 0.68), 380.0)
	tex_fill(Rect2(0, size.y * 0.82, size.x, size.y * 0.18), TEX_CONCRETE, Color(0.55, 0.53, 0.5), 300.0)
	var port := _outdoor_unit(Rect2(size.x * 0.03, size.y * 0.3, size.x * 0.33, size.y * 0.5))
	var valve := _cylinder(Rect2(size.x * 0.84, size.y * 0.45, size.x * 0.1, size.y * 0.36))
	# Bộ đồng hồ nạp ga: thân đồng thau, hai núm vặn xanh đỏ, ba dây xanh, đỏ, vàng.
	var mc := Vector2(size.x * 0.6, size.y * 0.47)
	var rad := minf(size.x, size.y) * 0.16
	var body := Rect2(mc + Vector2(-rad * 1.6, rad * 0.75), Vector2(rad * 3.2, rad * 0.55))
	hose(body.position + Vector2(rad * 0.4, body.size.y), Vector2(size.x * 0.45, size.y * 0.95), port, 9.0, Color(0.18, 0.35, 0.75))
	hose(body.position + Vector2(rad * 1.6, body.size.y), Vector2(size.x * 0.72, size.y * 1.0), valve, 9.0, Color(0.85, 0.72, 0.15))
	hose(body.end - Vector2(rad * 0.4, 0), Vector2(size.x * 0.82, size.y * 0.9), Vector2(size.x * 0.99, size.y * 0.7), 9.0, Color(0.75, 0.16, 0.14))
	soft_shadow(body, Vector2(6, 8), 8.0, 0.5)
	grad_rect(body, Color(0.86, 0.74, 0.42), Color(0.62, 0.5, 0.25))
	draw_rect(body, Color(0.4, 0.32, 0.15), false, 2.0)
	var kl := body.position + Vector2(-14, body.size.y * 0.5)
	var kr := Vector2(body.end.x + 14, kl.y)
	for k in [[kl, Color(0.18, 0.35, 0.75), holding], [kr, Color(0.75, 0.16, 0.14), false]]:
		disc(k[0], rad * 0.24, k[1], k[1].darkened(0.4))
		var ka := _t * 3.0 if k[2] else 0.0
		draw_line(k[0], k[0] + Vector2(cos(ka), sin(ka)) * rad * 0.2, Color(1, 1, 1, 0.6), 3.0)
	_gauge(mc + Vector2(-rad * 1.15, 0), rad, needle, Color(0.18, 0.35, 0.75), "THẤP · psi", true)
	_gauge(mc + Vector2(rad * 1.15, 0), rad, clampf(0.35 + needle * 0.4, 0.0, 1.0), Color(0.75, 0.16, 0.14), "CAO · psi", false)
	# Ga xì ra đầu nối khi đang nạp: hơi lạnh trắng.
	if holding and state == "play":
		for k in 6:
			glow(port + Vector2(_rng.randf_range(-10, 10), _rng.randf_range(-24, 6)), _rng.randf_range(10, 22), Color(0.9, 0.95, 1.0, 0.35))
	# Tiến độ giữ kim trong vùng xanh: đèn LED trên thân bộ đồng hồ.
	var need := float(cfg.get("holdSeconds", 5.0))
	for k in 10:
		var lit := held / need >= float(k + 1) / 10.0
		draw_circle(body.position + Vector2(rad * 0.5 + k * rad * 0.24, body.size.y * 0.5), rad * 0.07, Color(0.3, 0.95, 0.4) if lit else Color(0.15, 0.2, 0.15))
	vignette(0.55)
	draw_rect(Rect2(size.x * 0.5 - 200, size.y * 0.05, 400, 34), Color(0, 0, 0, 0.55))
	text_at(Vector2(size.x * 0.5, size.y * 0.05 + 24), "Máy %d/%d · xả ga %d lần" % [mini(unit + 1, int(cfg.get("units", 3))), int(cfg.get("units", 3)), vents], 19, UI.HUD_TEXT)
	text_at(Vector2(size.x * 0.5, size.y * 0.97), "Giữ Space/chuột để mở van nạp ga · kim đồng hồ xanh vào vạch xanh", 15, UI.HUD_TEXT)
