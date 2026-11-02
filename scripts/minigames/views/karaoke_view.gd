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

func _lane_rect(l: int) -> Rect2:
	var top := size.y * 0.22
	var h := size.y * 0.16
	return Rect2(0, top + l * (h + 10.0), size.x, h)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("1a0f24"))
	for i in 24:
		var x := size.x * (i + 0.5) / 24.0
		draw_circle(Vector2(x, size.y * 0.08 + sin(i + _t * 3.0) * 4.0), 4.0, [Color("ff5fa2"), Color("5fd0ff"), Color("ffd35f")][i % 3])
	var speed := float(cfg.get("speed", 0.28)) * size.x
	var lx := size.x * LINE_X
	var cols := [Color("ff7aa8"), Color("7ad8ff"), Color("ffe07a")]
	var keys := ["J", "K", "L"]
	for l in 3:
		var r := _lane_rect(l)
		draw_rect(r, Color(1, 1, 1, 0.05))
		var f := float(_flash.get(l, 0.0))
		if f != 0.0:
			draw_rect(Rect2(r.position, Vector2(lx + 30, r.size.y)), (Color(0.3, 1, 0.5, f * 2.0) if f > 0 else Color(1, 0.3, 0.3, -f * 2.0)))
		text_at(Vector2(30, r.get_center().y + 8), keys[l], 22, UI.HUD_TEXT)
	draw_line(Vector2(lx, _lane_rect(0).position.y), Vector2(lx, _lane_rect(2).end.y), Color("ffffff"), 3.0)
	for n in notes:
		var x := lx + (float(n.t) - _t) * speed
		if x < -30 or x > size.x + 30 or int(n.state) == 1:
			continue
		var r := _lane_rect(int(n.lane))
		var col: Color = cols[int(n.lane)]
		if int(n.state) == -1:
			col = Color(0.4, 0.4, 0.4)
		draw_circle(Vector2(x, r.get_center().y), r.size.y * 0.28, col)
	var li := clampi(int(_t / 8.0), 0, LYRICS.size() - 1)
	text_at(Vector2(size.x * 0.5, size.y * 0.86), LYRICS[li], 24, Color("f3e9ff"))
	text_at(Vector2(size.x * 0.5, size.y * 0.95), "Trúng %d · trượt %d" % [hit, miss + stray], 16, UI.INK_SOFT)
