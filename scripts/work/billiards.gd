extends Control
## Trò chơi nhỏ ở quán bi-a anh Dũng: bàn lỗ nhìn từ trên xuống, kéo chuột (hay ngón tay) lùi ra sau bi cái để ngắm,
## kéo càng xa càng mạnh, thả ra là đánh. Có cfg.shots cơ; ván cược (cfg.target) phải vào đủ số bi mới thắng.
## Cùng giao diện với work_site.gd: cfg (data/config.json minigames), title, phát finished(result):
## {"ratio": 1 thắng hay chơi xong, 0 thua, "bonus": 0}; {} là bỏ ngang.

signal finished(result: Dictionary)

var cfg: Dictionary = {}
var last: Dictionary = {}
var title := "Bi-a"
var kind := "billiards"

const R := 11.0
const POCKET_R := 21.0
const FRICTION := 0.75
const DECEL := 55.0
const MAX_SPEED := 1150.0
const BALL_COLORS := ["e8c020", "2f5fb0", "c03030", "6a2a8a", "e07a2f", "2f8a4a", "8a2a2a"]

var _table := Rect2()
var _balls: Array = []
var _shots_left := 0
var _potted := 0
var _state := "start"
var _aim_from = null
var _aim_now := Vector2.ZERO
var _msg := ""
var _moving := false
var _font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = get_theme_default_font()
	_shots_left = int(cfg.get("shots", 10))
	resized.connect(_layout)
	_layout()
	_rack()


func _layout() -> void:
	var w := minf(size.x - 80.0, (size.y - 170.0) * 2.0)
	var h := w / 2.0
	_table = Rect2((size.x - w) / 2.0, 80.0 + (size.y - 170.0 - h) / 2.0, w, h)
	queue_redraw()


## Bi cái ở điểm đầu bàn, bi màu xếp tam giác ở cuối bàn (tọa độ chuẩn hóa 0..1 theo mặt bàn).
func _rack() -> void:
	_balls.clear()
	_balls.append({"p": Vector2(0.25, 0.5), "v": Vector2.ZERO, "c": Color("f4f1e8"), "cue": true, "in": false})
	var n := int(cfg.get("balls", 7))
	var k := 0
	var row := 0
	while k < n:
		for j in row + 1:
			if k >= n:
				break
			var x := 0.7 + row * (2.0 * R * 0.87) / 760.0 * 2.0
			var y := 0.5 + (j - row / 2.0) * (2.0 * R + 0.5) / 380.0
			_balls.append({"p": Vector2(x, y), "v": Vector2.ZERO, "c": Color(BALL_COLORS[k % BALL_COLORS.size()]), "cue": false, "in": false})
			k += 1
		row += 1


func _to_px(p: Vector2) -> Vector2:
	return _table.position + p * _table.size


func _to_n(px: Vector2) -> Vector2:
	return (px - _table.position) / _table.size


func _cue() -> Dictionary:
	return _balls[0]


func _pockets() -> Array:
	var out := []
	for y in [0.0, 1.0]:
		for x in [0.0, 0.5, 1.0]:
			out.append(_to_px(Vector2(x, y)))
	return out


# ---------------------------------------------------------------- vào, ra

func _gui_input(event: InputEvent) -> void:
	if _state != "play" or _moving:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_aim_from = event.position
			_aim_now = event.position
		elif _aim_from != null:
			var pull: Vector2 = (_aim_from as Vector2) - _aim_now
			_aim_from = null
			if pull.length() > 8.0:
				_shoot(pull.normalized(), clampf(pull.length() / 220.0, 0.05, 1.0))
		accept_event()
	elif event is InputEventMouseMotion and _aim_from != null:
		_aim_now = event.position
		queue_redraw()
		accept_event()


## Đánh bi cái theo hướng dir (khung màn hình), lực 0..1.
func _shoot(dir: Vector2, power: float) -> void:
	if _shots_left <= 0:
		return
	_shots_left -= 1
	_cue().v = dir * power * MAX_SPEED
	_moving = true
	_msg = ""


func _process(delta: float) -> void:
	if _state != "play" or not _moving:
		return
	var steps := 6
	for i in steps:
		_step(delta / steps)
	var still := true
	for b in _balls:
		if not b.in and (b.v as Vector2).length() > 0.0:
			still = false
	queue_redraw()
	if still:
		_moving = false
		_after_shot()


func _step(dt: float) -> void:
	var pockets := _pockets()
	for b in _balls:
		if b.in:
			continue
		var v: Vector2 = b.v
		var sp := v.length()
		if sp <= 0.0:
			continue
		sp = maxf(0.0, sp * exp(-FRICTION * dt) - DECEL * dt)
		v = v.normalized() * sp if sp > 4.0 else Vector2.ZERO
		var px := _to_px(b.p) + v * dt
		# Băng: bật lại, mất bớt lực.
		if px.x < _table.position.x + R or px.x > _table.end.x - R:
			v.x = -v.x * 0.86
			px.x = clampf(px.x, _table.position.x + R, _table.end.x - R)
		if px.y < _table.position.y + R or px.y > _table.end.y - R:
			v.y = -v.y * 0.86
			px.y = clampf(px.y, _table.position.y + R, _table.end.y - R)
		b.v = v
		b.p = _to_n(px)
		for pk in pockets:
			if px.distance_to(pk) < POCKET_R:
				b.in = true
				b.v = Vector2.ZERO
				if b.cue:
					_msg = "Bi cái rơi lỗ, mất lượt đó."
				else:
					_potted += 1
	# Va chạm giữa hai bi cùng khối lượng: đẩy tách, đổi thành phần vận tốc dọc pháp tuyến.
	for i in _balls.size():
		var a: Dictionary = _balls[i]
		if a.in:
			continue
		for j in range(i + 1, _balls.size()):
			var b: Dictionary = _balls[j]
			if b.in:
				continue
			var pa := _to_px(a.p)
			var pb := _to_px(b.p)
			var d := pb - pa
			var dist := d.length()
			if dist < 2.0 * R and dist > 0.001:
				var n := d / dist
				var push := (2.0 * R - dist) / 2.0
				a.p = _to_n(pa - n * push)
				b.p = _to_n(pb + n * push)
				var rel: float = ((a.v as Vector2) - (b.v as Vector2)).dot(n)
				if rel > 0.0:
					var imp := n * rel * 0.96
					a.v = (a.v as Vector2) - imp
					b.v = (b.v as Vector2) + imp


func _after_shot() -> void:
	var cue := _cue()
	if cue.in:
		cue.in = false
		cue.p = Vector2(0.25, 0.5)
		cue.v = Vector2.ZERO
	var left := _balls.filter(func(b) -> bool: return not b.cue and not b.in).size()
	if left == 0 or _shots_left <= 0:
		_end()


## Bi đầu tiên bi cái chạm khi lăn từ p theo dir: [quãng đường tới chỗ chạm, bi] hay [0, null].
func _first_hit(p: Vector2, dir: Vector2) -> Array:
	var best := INF
	var who = null
	for b in _balls:
		if b.cue or b.in:
			continue
		var c := _to_px(b.p) - p
		var t := c.dot(dir)
		if t <= 0.0:
			continue
		var d2 := c.length_squared() - t * t
		var rr := 4.0 * R * R
		if d2 > rr:
			continue
		var s := t - sqrt(rr - d2)
		if s < best:
			best = s
			who = b
	return [best, who] if who != null else [0.0, null]


func _won() -> bool:
	return int(cfg.get("target", 0)) <= 0 or _potted >= int(cfg.get("target", 0))


func _end() -> void:
	_state = "end"
	queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode in [KEY_ENTER, KEY_SPACE, KEY_KP_ENTER]:
		_button()
	elif event.keycode == KEY_ESCAPE and _state == "start":
		finished.emit({})
	get_viewport().set_input_as_handled()


## Nút giữa màn (bắt đầu / xong): bấm chuột vào khung nút hay Enter.
func _button() -> void:
	match _state:
		"start":
			_state = "play"
		"end":
			finished.emit({"ratio": 1.0 if _won() else 0.0, "bonus": 0})
	queue_redraw()


func _input(event: InputEvent) -> void:
	if _state == "play" or not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _button_rect().has_point(get_local_mouse_position()):
			_button()
		elif _state == "start" and _skip_rect().has_point(get_local_mouse_position()):
			finished.emit({})
		get_viewport().set_input_as_handled()


func _button_rect() -> Rect2:
	return Rect2(size.x / 2.0 - 90.0, size.y / 2.0 + 60.0, 180.0, 44.0)


func _skip_rect() -> Rect2:
	return Rect2(size.x / 2.0 - 60.0, size.y / 2.0 + 116.0, 120.0, 32.0)


# ---------------------------------------------------------------- vẽ

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.05, 0.06, 0.94))
	var rail := _table.grow(26.0)
	draw_style_box(_box(Color("5a3218"), 14), rail)
	draw_rect(_table, Color("2f6a4a"))
	for i in 3:
		draw_circle(_to_px(Vector2(0.25, 0.5)), 2.0, Color(1, 1, 1, 0.25))
	draw_line(_to_px(Vector2(0.25, 0.0)), _to_px(Vector2(0.25, 1.0)), Color(1, 1, 1, 0.12), 1.0)
	for pk in _pockets():
		draw_circle(pk, POCKET_R, Color("0e0e0e"))
	for b in _balls:
		if b.in:
			continue
		var p := _to_px(b.p)
		draw_circle(p + Vector2(2, 3), R, Color(0, 0, 0, 0.35))
		draw_circle(p, R, b.c)
		draw_circle(p - Vector2(3.5, 3.5), R * 0.32, Color(1, 1, 1, 0.55))
	# Ngắm: gậy lùi sau bi cái, đường ngắm chấm phía trước.
	if _state == "play" and not _moving and _aim_from != null:
		var cp := _to_px(_cue().p)
		var pull: Vector2 = (_aim_from as Vector2) - _aim_now
		if pull.length() > 4.0:
			var dir := pull.normalized()
			var power := clampf(pull.length() / 220.0, 0.05, 1.0)
			# Dự báo: bi ma ở chỗ bi cái chạm bi đầu tiên trên đường ngắm, vạch hướng bi màu sẽ chạy.
			var hit := _first_hit(cp, dir)
			var reach: float = hit[0] if hit[1] != null else 1600.0
			var k := 0
			while R + 14.0 + k * 22.0 < reach - R and k < 60:
				draw_circle(cp + dir * (R + 14.0 + k * 22.0), 2.2, Color(1, 1, 1, maxf(0.15, 0.55 - k * 0.02)))
				k += 1
			if hit[1] != null:
				var ghost: Vector2 = cp + dir * float(hit[0])
				draw_arc(ghost, R, 0, TAU, 20, Color(1, 1, 1, 0.75), 1.5)
				var bp := _to_px(hit[1].p)
				var go := (bp - ghost).normalized()
				draw_line(bp, bp + go * 90.0, Color(hit[1].c, 0.9), 2.0, true)
			var back := cp - dir * (R + 6.0 + power * 60.0)
			draw_line(back, back - dir * 300.0, Color("c9a46a"), 6.0, true)
			draw_line(back, back - dir * 18.0, Color("f4f1e8"), 6.0, true)
			_text(Vector2(size.x / 2.0, _table.end.y + 56.0), "Lực %d%%" % int(power * 100.0), 16, Color("f4e3b0"))
	var head := "%s · còn %d cơ · vào %d bi" % [title, _shots_left, _potted]
	if int(cfg.get("target", 0)) > 0:
		head += " / cần %d" % int(cfg.target)
	_text(Vector2(size.x / 2.0, 44.0), head, 20, Color.WHITE)
	_text(Vector2(size.x / 2.0, 68.0), _msg if _msg != "" else "Kéo lùi ra sau bi trắng rồi thả để đánh, kéo càng xa càng mạnh.", 13, Color(1, 1, 1, 0.7))
	if _state == "start":
		_panel(str(cfg.get("heading", "Đánh một ván bi-a")), str(cfg.get("rules", "")), "Bắt đầu", true)
	elif _state == "end":
		var t := ""
		if int(cfg.get("target", 0)) > 0:
			t = ("Thắng ván! Vào %d bi, đủ chỉ tiêu." % _potted) if _won() else ("Thua ván: vào %d bi, cần %d." % [_potted, int(cfg.target)])
		else:
			t = "Hết giờ thuê bàn. Vào %d bi." % _potted
		_panel("Hết ván", t, "Xong", false)


func _panel(head: String, body: String, button: String, skip: bool) -> void:
	var r := Rect2(size.x / 2.0 - 260.0, size.y / 2.0 - 110.0, 520.0, 280.0)
	draw_style_box(_box(Color(0.1, 0.1, 0.12, 0.95), 12), r)
	_text(Vector2(size.x / 2.0, r.position.y + 50.0), head, 24, Color("f4e3b0"))
	var lines := body.split("\n")
	for i in lines.size():
		_text(Vector2(size.x / 2.0, r.position.y + 92.0 + i * 22.0), lines[i], 15, Color(1, 1, 1, 0.85))
	draw_style_box(_box(Color("c9a227"), 8), _button_rect())
	_text(_button_rect().get_center() + Vector2(0, 6), button, 17, Color("1a1a1a"))
	if skip:
		_text(_skip_rect().get_center() + Vector2(0, 5), "Thôi, để lúc khác", 13, Color(1, 1, 1, 0.6))


func _text(center: Vector2, t: String, fs: int, col: Color) -> void:
	var w := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string_outline(_font, center - Vector2(w / 2.0, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 4, Color(0, 0, 0, 0.7))
	draw_string(_font, center - Vector2(w / 2.0, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


static func _box(c: Color, r: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(r)
	return sb
