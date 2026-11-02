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

func _plate() -> Rect2:
	return Rect2(size.x * 0.08, size.y * 0.22, size.x * 0.84, size.y * 0.56)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("15171c"))
	var r := _plate()
	draw_rect(r, Color("4a4d52"))
	draw_rect(r, Color("2c2e33"), false, 3.0)
	var k := _seed + seam * 3.1
	var row: Array = beads[beads.size() - 1] if not beads.is_empty() else []
	# Rãnh ghép và mối hàn đã đi.
	var prev := Vector2.ZERO
	for i in SAMPLES:
		var x := float(i) / float(SAMPLES - 1)
		var p := Vector2(r.position.x + x * r.size.x, r.position.y + seam_y(cfg, k, x) * r.size.y)
		if i > 0:
			draw_line(prev, p, Color("1b1c1f"), 4.0)
			if not row.is_empty() and int(row[i]) != 0:
				draw_line(prev, p, Color("d9b26a") if int(row[i]) == 1 else Color("6b2c1c"), 9.0)
		prev = p
	var tol := float(cfg.get("tolerance", 0.06)) * r.size.y
	# Mỏ hàn, tia lửa.
	var x := clampf(_t / float(cfg.get("seconds", 24.0)), 0.0, 1.0) if state == "play" else 0.0
	var tip := Vector2(r.position.x + x * r.size.x, r.position.y + tip_y * r.size.y)
	draw_line(tip + Vector2(-30, -70), tip, Color("9aa0a8"), 6.0)
	draw_circle(tip, tol, Color(1, 1, 1, 0.12))
	if holding and state == "play":
		draw_circle(tip, 14.0, Color(1.0, 0.95, 0.75, 0.9))
		for j in 6:
			var a := _rng.randf() * TAU
			draw_line(tip, tip + Vector2(cos(a), sin(a)) * _rng.randf_range(10.0, 34.0), Color("ffd27a"), 2.0)
	text_at(Vector2(size.x * 0.5, size.y * 0.12), "Đường hàn %d/%d · cháy %d · đứt %d" % [mini(seam + 1, int(cfg.get("seams", 3))), int(cfg.get("seams", 3)), burns, gaps], 20, UI.HUD_TEXT)
	text_at(Vector2(size.x * 0.5, size.y * 0.9), "Giữ Space/chuột để hàn · kéo chuột hoặc W/S để bám rãnh", 15, UI.INK_SOFT)
