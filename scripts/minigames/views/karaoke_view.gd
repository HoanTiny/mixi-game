extends "res://scripts/minigames/views/minigame_view.gd"
## Hát karaoke ở phố Tạ Hiện: nốt nhạc chạy từ phải sang trái trên ba làn (cao, vừa, trầm). Nốt chạm vạch hát thì bấm
## đúng làn: phím J, K, L (hay ↑, →, ↓), hoặc chạm vào làn đó. Lời bài hát chạy bên dưới cho vui.
## cfg: seconds (độ dài bài), bpm (nhịp), window (giây lệch cho phép), speed (tỉ lệ bề ngang mỗi giây).
## Kết quả thô: {"score": phần nốt trúng, "hit", "notes", "fails": nốt trượt + bấm hụt}.

const LYRICS := ["Hà Nội mùa này phố cứ dài thêm", "Đèn vàng hắt xuống vỉa hè quen", "Có người về muộn, áo còn mưa",
	"Hát cho nhau nghe, quên đi chuyện tiền", "Mai lại dậy sớm, lại lên phố"]
const LINE_X := 0.18

var notes: Array = []
var hit := 0
var miss := 0
var stray := 0
var _t := 0.0
var _flash := {}


func rules() -> String:
	return "Nốt chạy từ phải sang trái trên ba làn. Nốt chạm vạch sáng thì bấm đúng làn: J/K/L (hay ↑ → ↓), hoặc chạm vào làn. Bấm hụt cũng tính lỗi. Bài dài %d giây." % int(cfg.get("seconds", 40))


## Bản nhạc cố định theo hạt giống: mảng {t, lane}. Nốt đều theo nhịp, đôi chỗ dồn hai nốt, làn đổi theo giai điệu.
static func chart(c: Dictionary, seed_v: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var beat := 60.0 / float(c.get("bpm", 96))
	var out := []
	var t := 2.0
	var lane := 1
	while t < float(c.get("seconds", 40.0)) - 1.0:
		out.append({"t": t, "lane": lane, "state": 0})
		if rng.randf() < 0.2:
			t += beat * 0.5
		else:
			t += beat * (1.0 if rng.randf() < 0.7 else 2.0)
		lane = clampi(lane + rng.randi_range(-1, 1), 0, 2)
	return out


func _begin() -> void:
	notes = chart(cfg, randi())


func _press(lane: int) -> void:
	var win := float(cfg.get("window", 0.18))
	var best := -1
	var best_d := INF
	for i in notes.size():
		var n: Dictionary = notes[i]
		if int(n.state) == 0 and int(n.lane) == lane:
			var d := absf(float(n.t) - _t)
			if d < best_d:
				best_d = d
				best = i
	if best >= 0 and best_d <= win:
		notes[best].state = 1
		hit += 1
		_flash[lane] = 0.25
	else:
		stray += 1
		_flash[lane] = -0.25


func _play_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_J, KEY_UP: _press(0)
			KEY_K, KEY_RIGHT: _press(1)
			KEY_L, KEY_DOWN: _press(2)
	elif (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		for l in 3:
			if _lane_rect(l).has_point(event.position):
				_press(l)


func _play(delta: float) -> void:
	_t += delta
	var win := float(cfg.get("window", 0.18))
	for n in notes:
		if int(n.state) == 0 and _t - float(n.t) > win:
			n.state = -1
			miss += 1
	for k in _flash.keys():
		_flash[k] = move_toward(float(_flash[k]), 0.0, delta)
	if _t >= float(cfg.get("seconds", 40.0)):
		end()


func result() -> Dictionary:
	var total := maxi(1, notes.size())
	# Bấm hụt trừ điểm nhẹ: hát lệch nhịp vẫn vui nhưng không "cháy".
	var score := maxf(0.0, (float(hit) - 0.25 * float(stray)) / float(total))
	return {"score": score, "hit": hit, "notes": notes.size(), "fails": miss + stray}


func summary(r: Dictionary) -> String:
	var s := float(r.score)
	return "Trúng %d/%d nốt. " % [int(r.hit), int(r.notes)] + ("Cả quán vỗ tay!" if s >= 0.75 else ("Hát cũng được, nhẹ người hẳn." if s >= 0.4 else "Lạc giọng, nhưng cười nhiều."))


# ---------------------------------------------------------------- vẽ

const HAND := preload("res://assets/fonts/PatrickHand-Regular.ttf")


func _lane_rect(l: int) -> Rect2:
	var scr := _screen()
	var top := scr.position.y + scr.size.y * 0.12
	var h := scr.size.y * 0.12
	return Rect2(scr.position.x, top + l * (h + 6.0), scr.size.x, h)


## Màn hình tivi trong phòng hát (vùng chơi), chừa viền tivi và bàn phía dưới.
func _screen() -> Rect2:
	return Rect2(size.x * 0.06, size.y * 0.06, size.x * 0.88, size.y * 0.7)


func _draw() -> void:
	# Phòng hát: tường tối, đèn màu loang, bàn kính phía dưới.
	grad_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.04, 0.12), Color(0.03, 0.02, 0.05))
	for k in 5:
		glow(Vector2(size.x * (0.1 + k * 0.2), size.y * 0.92), size.x * 0.18, [Color(1, 0.3, 0.6, 0.35), Color(0.3, 0.6, 1, 0.3), Color(1, 0.75, 0.2, 0.3)][k % 3])
	var scr := _screen()
	# Viền tivi đen bóng.
	soft_shadow(scr.grow(16), Vector2(0, 12), 20.0, 0.7)
	draw_rect(scr.grow(16), Color(0.05, 0.05, 0.06))
	draw_rect(scr.grow(16), Color(0.25, 0.25, 0.28), false, 2.0)
	# Video nền: phố đêm nhòe đèn (bokeh trôi chậm), trời tím, mặt đường ướt phản chiếu.
	grad_rect(scr, Color(0.16, 0.08, 0.28), Color(0.05, 0.05, 0.12))
	for k in 26:
		var fx := fposmod(float(k) * 0.173 + _t * (0.01 + float(k % 4) * 0.004), 1.0)
		var fy := 0.25 + float((k * 37) % 50) / 100.0
		var col: Color = [Color(1, 0.7, 0.3), Color(1, 0.35, 0.5), Color(0.4, 0.7, 1.0), Color(1, 0.9, 0.6)][k % 4]
		col.a = 0.5
		glow(scr.position + Vector2(fx * scr.size.x, fy * scr.size.y), 14.0 + float((k * 13) % 30), col)
	# Dãy phố cổ in bóng, cửa sổ sáng vàng.
	var bx := scr.position.x
	var k2 := 0
	while bx < scr.end.x:
		var bw := minf(50.0 + float((k2 * 31) % 60), scr.end.x - bx + 4.0)
		var bh := scr.size.y * (0.12 + float((k2 * 17) % 13) / 100.0)
		var br := Rect2(bx, scr.position.y + scr.size.y * 0.78 - bh, bw - 4, bh)
		draw_rect(br, Color(0.06, 0.04, 0.1, 0.9))
		for wy in 4:
			for wx in 2:
				if (k2 + wy * 3 + wx) % 3 != 0 and 14 + wy * 26 + 14 < bh:
					draw_rect(Rect2(br.position + Vector2(8 + wx * (bw * 0.4), 14 + wy * 26), Vector2(10, 14)), Color(1.0, 0.78, 0.4, 0.55))
		bx += bw
		k2 += 1
	grad_rect(Rect2(scr.position.x, scr.position.y + scr.size.y * 0.78, scr.size.x, scr.size.y * 0.22), Color(0.1, 0.06, 0.16, 0.9), Color(0, 0, 0, 0.85))
	# Thanh cao độ: ba làn mờ, nốt là thanh bo tròn có lõi sáng; vạch hát.
	var speed := float(cfg.get("speed", 0.28)) * scr.size.x
	var lx := scr.position.x + scr.size.x * LINE_X
	var cols := [Color("ff7aa8"), Color("7ad8ff"), Color("ffe07a")]
	var keys := ["J", "K", "L"]
	for l in 3:
		var r := _lane_rect(l)
		draw_rect(r, Color(0, 0, 0, 0.35))
		draw_line(Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y), Color(1, 1, 1, 0.08), 1.0)
		var f := float(_flash.get(l, 0.0))
		if f > 0.0:
			glow(Vector2(lx, r.get_center().y), r.size.y * 1.3, Color(0.4, 1.0, 0.6, f * 3.0))
		elif f < 0.0:
			glow(Vector2(lx, r.get_center().y), r.size.y, Color(1.0, 0.3, 0.3, -f * 3.0))
		disc(Vector2(scr.position.x + 26, r.get_center().y), r.size.y * 0.34, Color(0.2, 0.2, 0.24), Color(0.4, 0.4, 0.45))
		text_at(Vector2(scr.position.x + 26, r.get_center().y + 7), keys[l], 18, UI.HUD_TEXT)
	draw_line(Vector2(lx, _lane_rect(0).position.y - 6), Vector2(lx, _lane_rect(2).end.y + 6), Color(1, 1, 1, 0.9), 3.0)
	glow(Vector2(lx, _lane_rect(1).get_center().y), 60.0, Color(1, 1, 1, 0.25))
	for n in notes:
		var x := lx + (float(n.t) - _t) * speed
		if x < scr.position.x + 50 or x > scr.end.x - 54 or int(n.state) == 1:
			continue
		var r := _lane_rect(int(n.lane))
		var col: Color = cols[int(n.lane)] if int(n.state) == 0 else Color(0.35, 0.35, 0.4)
		var bar := Rect2(Vector2(x - 6, r.get_center().y - r.size.y * 0.22), Vector2(48, r.size.y * 0.44))
		glow(bar.get_center(), 34.0, Color(col.r, col.g, col.b, 0.35))
		draw_rect(bar, col.darkened(0.2))
		draw_rect(bar.grow(-3), col)
		draw_rect(Rect2(bar.position + Vector2(4, 3), Vector2(bar.size.x - 8, 3)), Color(1, 1, 1, 0.55))
	# Lời bài hát: phần đã hát đổi màu dần theo nhịp như karaoke thật.
	var li := clampi(int(_t / 8.0), 0, LYRICS.size() - 1)
	var line: String = LYRICS[li]
	var fs := 34
	var w := HAND.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var at := Vector2(scr.get_center().x - w / 2.0, scr.end.y - 34)
	var sung := clampi(int(fposmod(_t, 8.0) / 8.0 * float(line.length() + 4)), 0, line.length())
	draw_string_outline(HAND, at, line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 0.85))
	draw_string(HAND, at, line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1))
	draw_string(HAND, at, line.left(sung), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("4fc3ff"))
	if li + 1 < LYRICS.size():
		text_at(Vector2(scr.get_center().x, scr.end.y - 6), LYRICS[li + 1], 18, Color(1, 1, 1, 0.55))
	# Điểm số góc màn hình, micro trên bàn.
	var pts := int(round(float(result().score) * 100.0))
	draw_rect(Rect2(scr.end.x - 170, scr.position.y + 10, 160, 44), Color(0, 0, 0, 0.5))
	text_at(Vector2(scr.end.x - 90, scr.position.y + 42), "Điểm %d" % pts, 24, Color("ffe07a"))
	var mic := Vector2(size.x * 0.5, size.y * 0.9)
	draw_line(mic + Vector2(-110, 18), mic + Vector2(40, -4), Color(0.12, 0.12, 0.14), 16.0)
	disc(mic + Vector2(52, -6), 20.0, Color(0.6, 0.62, 0.66), Color(0.3, 0.3, 0.33))
	text_at(Vector2(size.x * 0.5, size.y * 0.985), "Trúng %d · trượt %d · J/K/L hay chạm vào làn" % [hit, miss + stray], 15, UI.INK_SOFT)
