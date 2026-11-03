extends "res://scripts/minigames/views/minigame_view.gd"
## Hàn khung cửa sắt (nhìn thẳng tấm phôi): đường ghép nối chạy ngang màn hình, uốn lượn nhẹ. Mỏ hàn tự đi từ trái sang
## phải; giữ Space / chuột (hay chạm giữ) để hàn, kéo chuột lên xuống hoặc W/S, ↑/↓ để giữ đầu que bám rãnh. Lệch khỏi
## rãnh mà vẫn hàn thì mối hàn hỏng (cháy phôi), buông tay giữa chừng thì mối hàn bị đứt.
## cfg: seconds (thời gian đi hết tấm), seams (số đường hàn), tolerance (nửa bề rộng rãnh hàn được, tỉ lệ chiều cao),
## wobble (độ lượn của rãnh), speed (tốc độ lên xuống bằng phím, tỉ lệ chiều cao mỗi giây).
## Kết quả thô: {"score": phần đường hàn đạt, "fails": số đoạn cháy phôi + số chỗ đứt}.

const SAMPLES := 120

var seam := 0
var tip_y := 0.5
var holding := false
var _t := 0.0
## Mỗi đường hàn: mảng SAMPLES ô, 0 chưa hàn, 1 đạt, -1 cháy phôi.
var beads: Array = []
var burns := 0
var gaps := 0
var _was_on := false
var _seed := 0.0
var _rng := RandomNumberGenerator.new()
## Tia lửa {p, v, life}, khói {p, r, life} theo điểm ảnh, chỉ để vẽ.
var _sparks: Array = []
var _smoke: Array = []


func rules() -> String:
	return "Mỏ hàn tự đi từ trái sang phải. Giữ Space hoặc giữ chuột để hàn, kéo chuột lên xuống (hay W/S, ↑/↓) cho đầu que bám đúng rãnh ghép. Lệch rãnh mà vẫn hàn là cháy phôi; buông tay giữa chừng là mối hàn đứt. Có %d đường hàn." % int(cfg.get("seams", 3))


func _setup() -> void:
	_rng.randomize()
	_seed = _rng.randf() * 10.0


func _begin() -> void:
	_next_seam()


func _next_seam() -> void:
	_t = 0.0
	_was_on = false
	var row := []
	row.resize(SAMPLES)
	row.fill(0)
	beads.append(row)
	tip_y = seam_y(cfg, _seed + seam * 3.1, 0.0)


## Độ cao rãnh (0..1 theo chiều cao vùng phôi) tại x (0..1) của đường hàn có hạt giống k.
static func seam_y(c: Dictionary, k: float, x: float) -> float:
	var w := float(c.get("wobble", 0.12))
	return 0.5 + w * sin(x * 6.3 + k) + w * 0.45 * sin(x * 15.0 + k * 1.7)


func _play_input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode in [KEY_SPACE, KEY_ENTER]:
		holding = event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		holding = event.pressed
		_aim(event.position)
	elif event is InputEventScreenTouch:
		holding = event.pressed
		_aim(event.position)
	elif event is InputEventMouseMotion or event is InputEventScreenDrag:
		_aim(event.position)


func _aim(p: Vector2) -> void:
	var r := _plate()
	tip_y = clampf((p.y - r.position.y) / r.size.y, 0.0, 1.0)


func _play(delta: float) -> void:
	_fx(delta)
	var sp := float(cfg.get("speed", 0.6))
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		tip_y = clampf(tip_y - sp * delta, 0.0, 1.0)
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		tip_y = clampf(tip_y + sp * delta, 0.0, 1.0)
	_t += delta
	var x := clampf(_t / float(cfg.get("seconds", 24.0)), 0.0, 1.0)
	var i := mini(SAMPLES - 1, int(x * SAMPLES))
	var row: Array = beads[beads.size() - 1]
	if holding:
		var on := absf(tip_y - seam_y(cfg, _seed + seam * 3.1, x)) <= float(cfg.get("tolerance", 0.06))
		if row[i] == 0:
			row[i] = 1 if on else -1
			if not on and (i == 0 or row[i - 1] != -1):
				burns += 1
		_was_on = true
	elif _was_on and x < 0.98:
		gaps += 1
		_was_on = false
	if x >= 1.0:
		seam += 1
		if seam >= int(cfg.get("seams", 3)):
			end()
		else:
			_next_seam()


func result() -> Dictionary:
	var good := 0
	for row in beads:
		for v in row:
			if int(v) == 1:
				good += 1
	var total := SAMPLES * int(cfg.get("seams", 3))
	return {"score": float(good) / float(maxi(1, total)), "burns": burns, "gaps": gaps, "fails": burns + gaps}


func summary(r: Dictionary) -> String:
	return "Mối hàn đạt %d%% · cháy phôi %d chỗ · đứt %d chỗ." % [int(float(r.score) * 100.0), int(r.burns), int(r.gaps)]


# ---------------------------------------------------------------- vẽ

## Tia lửa văng, rơi theo trọng lực; khói bốc lên, loang dần.
func _fx(delta: float) -> void:
	if holding and size.x > 0.0:
		var tip := _tip()
		for k in 5:
			var a := _rng.randf_range(-PI * 0.95, -PI * 0.05)
			_sparks.append({"p": tip, "v": Vector2(cos(a), sin(a)) * _rng.randf_range(120.0, 420.0), "life": _rng.randf_range(0.25, 0.7)})
		if _rng.randf() < 0.35:
			_smoke.append({"p": tip + Vector2(_rng.randf_range(-6, 6), -8), "r": 10.0, "life": 1.6})
	for sp in _sparks:
		sp.v += Vector2(0, 900.0) * delta
		sp.p += sp.v * delta
		sp.life -= delta
	for sm in _smoke:
		sm.p += Vector2(_rng.randf_range(-12, 18), -46.0) * delta
		sm.r += 22.0 * delta
		sm.life -= delta
	_sparks = _sparks.filter(func(x) -> bool: return float(x.life) > 0.0)
	_smoke = _smoke.filter(func(x) -> bool: return float(x.life) > 0.0)


func _plate() -> Rect2:
	return Rect2(size.x * 0.08, size.y * 0.22, size.x * 0.84, size.y * 0.56)


func _seam_pt(x: float) -> Vector2:
	var r := _plate()
	return Vector2(r.position.x + x * r.size.x, r.position.y + seam_y(cfg, _seed + seam * 3.1, x) * r.size.y)


func _tip() -> Vector2:
	var r := _plate()
	var x := clampf(_t / float(cfg.get("seconds", 24.0)), 0.0, 1.0) if state == "play" else 0.0
	return Vector2(r.position.x + x * r.size.x, r.position.y + tip_y * r.size.y)


## Một tấm phôi thép (đa giác dán ảnh thép) từ mép trên/dưới tới đường rãnh, có mép vát sáng.
func _plate_half(top: bool) -> void:
	var r := _plate()
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var edge := PackedVector2Array()
	var n := 48
	for i in n + 1:
		var x := float(i) / float(n)
		var p := _seam_pt(x) + Vector2(0, -5.0 if top else 5.0)
		pts.append(p)
		edge.append(p)
	pts.append(Vector2(r.end.x, r.position.y if top else r.end.y))
	pts.append(Vector2(r.position.x, r.position.y if top else r.end.y))
	for p in pts:
		uvs.append((p - r.position) / 420.0 + (Vector2(0.37, 0.11) if top else Vector2.ZERO))
	var cols := PackedColorArray()
	for p in pts:
		cols.append(Color(0.62, 0.63, 0.66) if top else Color(0.55, 0.56, 0.6))
	draw_polygon(pts, cols, uvs, TEX_RUSTY)
	# Mép vát của rãnh chữ V: dải sáng (mài) rồi bóng tối sát rãnh.
	draw_polyline(edge, Color(0.92, 0.93, 0.95, 0.55) if top else Color(0.2, 0.21, 0.24, 0.7), 3.0, true)


## Vảy hàn: chuỗi hình bán nguyệt chồng nhau; gần đầu que còn đỏ rực, nguội dần thành bạc, viền vàng rơm, xanh tím do nhiệt.
func _bead(row: Array, current: bool) -> void:
	var tipx := clampf(_t / float(cfg.get("seconds", 24.0)), 0.0, 1.0) if current else 2.0
	for i in SAMPLES:
		var v := int(row[i])
		if v == 0:
			continue
		var x := float(i) / float(SAMPLES - 1)
		var p := _seam_pt(x)
		var heat := clampf(1.0 - (tipx - x) * 9.0, 0.0, 1.0) if current else 0.0
		if v == 1:
			draw_circle(p, 9.0, Color(0.32, 0.22, 0.45, 0.35))
			draw_circle(p, 7.5, Color(0.72, 0.58, 0.3, 0.55))
			var metal := Color(0.66, 0.67, 0.7).lerp(Color(1.0, 0.55, 0.15), heat)
			draw_arc(p + Vector2(-2, 0), 6.5, -PI * 0.5, PI * 0.5, 10, metal, 5.0)
			draw_arc(p + Vector2(-2, -1), 5.0, -PI * 0.35, PI * 0.1, 8, metal.lightened(0.35), 1.5)
			if heat > 0.1:
				glow(p, 22.0 * heat, Color(1.0, 0.5, 0.15, 0.9 * heat))
		else:
			# Cháy phôi: lỗ thủng đen, xỉ nâu, hạt bắn quanh.
			draw_circle(p, 8.0, Color(0.16, 0.1, 0.07))
			draw_circle(p + Vector2(1, 1), 5.0, Color(0.06, 0.04, 0.03))
			if i % 3 == 0:
				draw_circle(p + Vector2(float((i * 37) % 13) - 6.0, float((i * 53) % 17) - 8.0), 1.6, Color(0.3, 0.25, 0.2))


## Kẹp chữ C nhìn từ trên: thân gang đỏ ôm mép tấm, vít me và tay vặn.
func _clamp(at: Vector2, up: bool) -> void:
	var s := -1.0 if up else 1.0
	var body := Color(0.62, 0.13, 0.1)
	soft_shadow(Rect2(at + Vector2(-14, -6 if up else -40), Vector2(28, 46)), Vector2(4, 6), 6.0, 0.5)
	draw_rect(Rect2(at + Vector2(-14, -6 if up else -40), Vector2(28, 46)), body)
	draw_rect(Rect2(at + Vector2(-14, -6 if up else -40), Vector2(28, 6)), body.lightened(0.25))
	draw_rect(Rect2(at + Vector2(-20, (-6 if up else 34)), Vector2(40, 8)), body.darkened(0.25))
	draw_line(at + Vector2(0, 40 * -s), at + Vector2(0, 70 * -s), Color(0.7, 0.71, 0.74), 6.0)
	draw_line(at + Vector2(-16, 70 * -s), at + Vector2(16, 70 * -s), Color(0.55, 0.56, 0.6), 5.0)


func _draw() -> void:
	# Xưởng: sàn bê tông, mặt bàn hàn thép dày.
	tex_fill(Rect2(Vector2.ZERO, size), TEX_CONCRETE, Color(0.32, 0.31, 0.3), 360.0)
	var r := _plate()
	var bench := r.grow(34.0)
	soft_shadow(bench, Vector2(10, 16), 22.0, 0.6)
	tex_fill(bench, TEX_STEEL, Color(0.35, 0.36, 0.38), 220.0)
	draw_rect(bench, Color(0.1, 0.1, 0.11), false, 3.0)
	soft_shadow(r, Vector2(4, 6), 8.0, 0.5)
	_plate_half(true)
	_plate_half(false)
	# Rãnh ghép (khe tối giữa hai tấm).
	var groove := PackedVector2Array()
	for i in 61:
		groove.append(_seam_pt(float(i) / 60.0))
	draw_polyline(groove, Color(0.05, 0.05, 0.06), 6.0, true)
	# Các đường đã hàn xong (mờ phía sau), đường đang hàn.
	if not beads.is_empty():
		_bead(beads[beads.size() - 1], state == "play")
	_clamp(Vector2(r.position.x + 70, r.position.y), true)
	_clamp(Vector2(r.end.x - 70, r.end.y), false)
	var tip := _tip()
	var on := holding and state == "play"
	# Kính hàn tự tối: hồ quang bật thì cả cảnh tối và ám xanh, chỉ còn vùng sáng quanh đầu que.
	if on:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.07, 0.03, 0.5))
		glow(tip, 240.0, Color(0.7, 0.92, 1.0, 0.9))
		glow(tip, 90.0, Color(0.85, 0.97, 1.0, 1.0))
		glow(tip, 36.0, Color(1, 1, 1, 1))
	for sm in _smoke:
		draw_circle(sm.p, sm.r, Color(0.7, 0.72, 0.75, 0.12 * clampf(float(sm.life), 0.0, 1.0)))
	for sp in _sparks:
		var col := Color(1.0, 0.85, 0.4).lerp(Color(1.0, 0.35, 0.1), 1.0 - clampf(float(sp.life) / 0.7, 0.0, 1.0))
		draw_line(sp.p, sp.p - (sp.v as Vector2) * 0.018, col, 2.0, true)
	# Mỏ hàn MIG: chụp khí đồng, cổ cong, tay cầm đen, dây cáp.
	var tilt := Vector2(-0.55, -1.0).normalized()
	var nozzle_end := tip + tilt * 10.0
	var neck := nozzle_end + tilt * 70.0
	draw_line(nozzle_end, neck, Color(0.72, 0.5, 0.28), 16.0)
	draw_line(nozzle_end + Vector2(3, 0), neck + Vector2(3, 0), Color(0.92, 0.72, 0.45, 0.7), 3.0)
	var grip := neck + Vector2(-60, -40)
	draw_line(neck, grip, Color(0.12, 0.12, 0.13), 22.0)
	draw_line(neck + Vector2(-2, -6), grip + Vector2(-2, -6), Color(0.3, 0.3, 0.32), 3.0)
	hose(grip, grip + Vector2(-80, -10), Vector2(0, grip.y - 90), 9.0, Color(0.1, 0.1, 0.11))
	draw_circle(tip, 2.5, Color(0.85, 0.85, 0.85))
	if not on and state == "play":
		draw_arc(tip, float(cfg.get("tolerance", 0.06)) * r.size.y, 0, TAU, 24, Color(1, 1, 1, 0.25), 1.5)
	vignette(0.7)
	var head := "Đường hàn %d/%d · cháy phôi %d · đứt %d" % [mini(seam + 1, int(cfg.get("seams", 3))), int(cfg.get("seams", 3)), burns, gaps]
	draw_rect(Rect2(size.x * 0.5 - 220, size.y * 0.06, 440, 34), Color(0, 0, 0, 0.55))
	text_at(Vector2(size.x * 0.5, size.y * 0.06 + 24), head, 19, UI.HUD_TEXT)
	text_at(Vector2(size.x * 0.5, size.y * 0.95), "Giữ Space/chuột để hàn · kéo chuột hoặc W/S để bám rãnh", 15, UI.INK_SOFT)
