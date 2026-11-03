extends "res://scripts/minigames/views/minigame_view.gd"
## Ghi sổ thu chi cho tiểu thương: mỗi lượt là một tờ bảng kê vài khoản (bán, nhập, trả nợ), cộng trừ ra số dư cuối
## ngày. Chọn số dư đúng trong ba số (phím 1, 2, 3 hay bấm, chạm) trước khi hết giờ của tờ đó. Sai hay hết giờ là lệch sổ.
## cfg: rounds (số tờ), lines (số khoản mỗi tờ), secondsPerSheet, unit (bội số tiền, nghìn đồng).
## Kết quả thô: {"score": số tờ đúng / số tờ, "right", "rounds", "fails": số tờ lệch}.

var sheet := 0
var right := 0
var wrong := 0
var lines: Array = []
var answers: Array = []
var correct := 0
var picked := -1
var _t := 0.0
var _rest := 0.0
var _rng := RandomNumberGenerator.new()
var _buttons: Array = []

const NAMES_IN := ["Bán rau buổi sáng", "Bán trứng vịt", "Khách trả nợ hôm qua", "Bán gạo 10 cân", "Bán đậu phụ", "Bán thịt ba chỉ"]
const NAMES_OUT := ["Nhập hàng chợ đầu mối", "Trả tiền xe ba gác", "Tiền ghế, tiền vé chợ", "Đá lạnh, túi ni lông", "Trả nợ mối hàng"]


func rules() -> String:
	return "Mỗi tờ bảng kê có vài khoản thu (+) và chi (−). Cộng trừ trong đầu, rồi chọn số dư đúng bằng phím 1, 2, 3 hay bấm vào ô. Mỗi tờ có %d giây. Có %d tờ." % [int(cfg.get("secondsPerSheet", 14)), int(cfg.get("rounds", 6))]


func _setup() -> void:
	_rng.randomize()


func _begin() -> void:
	_new_sheet()


## Tờ bảng kê: khoản (tên, số tiền có dấu) và ba đáp án; đáp án sai lệch đúng kiểu hay nhầm (quên một khoản, nhầm dấu).
static func make_sheet(rng: RandomNumberGenerator, n: int, unit: int) -> Dictionary:
	var items := []
	var total := 0
	for i in n:
		var income := i == 0 or rng.randf() < 0.55
		var v := rng.randi_range(3, 48) * unit * (1 if income else -1)
		items.append({"name": (NAMES_IN if income else NAMES_OUT)[rng.randi_range(0, (NAMES_IN if income else NAMES_OUT).size() - 1)], "v": v})
		total += v
	var skip: int = items[rng.randi_range(1, n - 1)].v
	var wrongs := [total - skip, total - 2 * skip, total + unit * 10 * (1 if rng.randf() < 0.5 else -1)]
	var opts := [total]
	for w in wrongs:
		if not opts.has(w) and opts.size() < 3:
			opts.append(w)
	while opts.size() < 3:
		opts.append(total + unit * rng.randi_range(2, 9))
	opts.shuffle()
	return {"items": items, "total": total, "options": opts}


func _new_sheet() -> void:
	var sh := make_sheet(_rng, int(cfg.get("lines", 4)), int(cfg.get("unit", 1000)))
	lines = sh.items
	answers = sh.options
	correct = answers.find(sh.total)
	picked = -1
	_t = 0.0


func _choose(i: int) -> void:
	if picked >= 0 or i < 0 or i > 2:
		return
	picked = i
	if i == correct:
		right += 1
	else:
		wrong += 1
	_rest = 0.0


func _play_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.keycode
		if k in [KEY_1, KEY_KP_1]: _choose(0)
		elif k in [KEY_2, KEY_KP_2]: _choose(1)
		elif k in [KEY_3, KEY_KP_3]: _choose(2)
	elif (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		for i in 3:
			if _option_rect(i).has_point(event.position):
				_choose(i)


func _play(delta: float) -> void:
	if picked < 0:
		_t += delta
		if _t >= float(cfg.get("secondsPerSheet", 14.0)):
			picked = 3
			wrong += 1
			_rest = 0.0
		return
	_rest += delta
	if _rest >= 0.9:
		sheet += 1
		if sheet >= int(cfg.get("rounds", 6)):
			end()
		else:
			_new_sheet()


func result() -> Dictionary:
	var n := int(cfg.get("rounds", 6))
	return {"score": float(right) / float(maxi(1, n)), "right": right, "rounds": n, "fails": wrong}


func summary(r: Dictionary) -> String:
	return "Khớp %d/%d tờ." % [int(r.right), int(r.rounds)] + ("" if int(r.fails) == 0 else " Lệch %d tờ, phải dò lại." % int(r.fails))


# ---------------------------------------------------------------- vẽ

const PEN := preload("res://assets/fonts/PatrickHand-Regular.ttf")
const INK_BLUE := Color(0.13, 0.22, 0.52)
const INK_RED := Color(0.68, 0.14, 0.12)


func _option_rect(i: int) -> Rect2:
	var w := minf(200.0, size.x * 0.2)
	var gap := 26.0
	var x0 := size.x * 0.5 - (w * 3.0 + gap * 2.0) / 2.0
	return Rect2(x0 + i * (w + gap), size.y * 0.75, w, 78)


static func money(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "." + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("−" if v < 0 else "") + s + out + "đ"


func _pen(at: Vector2, t: String, fs: int, col: Color, right := false) -> void:
	var w := PEN.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(PEN, at - Vector2(w if right else 0.0, 0), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


## Máy tính bỏ túi: vỏ nhựa xám, màn LCD xanh, phím.
func _calculator(r: Rect2) -> void:
	soft_shadow(r, Vector2(8, 12), 12.0, 0.6)
	draw_rect(r, Color(0.2, 0.21, 0.23))
	grad_rect(r.grow(-4), Color(0.3, 0.31, 0.34), Color(0.18, 0.19, 0.2))
	var lcd := Rect2(r.position + Vector2(14, 16), Vector2(r.size.x - 28, 46))
	draw_rect(lcd, Color(0.62, 0.68, 0.55))
	draw_rect(lcd, Color(0.1, 0.1, 0.1, 0.6), false, 2.0)
	var shown := "0." if picked < 0 else money(int(answers[correct])).replace("đ", "").replace(".", "")
	_pen(Vector2(lcd.end.x - 10, lcd.position.y + 36), shown, 30, Color(0.12, 0.14, 0.1), true)
	for row in 4:
		for col in 4:
			var k := Rect2(r.position + Vector2(14 + col * (r.size.x - 28) / 4.0, 80 + row * 40), Vector2((r.size.x - 28) / 4.0 - 6, 32))
			draw_rect(k, Color(0.12, 0.12, 0.13))
			draw_rect(Rect2(k.position, Vector2(k.size.x, k.size.y - 4)), Color(0.38, 0.39, 0.42) if col < 3 else Color(0.75, 0.42, 0.18))
			_pen(k.get_center() + Vector2(-5, 6), ["7", "8", "9", "÷", "4", "5", "6", "×", "1", "2", "3", "−", "0", ".", "=", "+"][row * 4 + col], 18, Color(0.95, 0.95, 0.92))


## Cốc trà đá nhìn từ trên: thành thủy tinh, nước trà nâu, đá viên.
func _tea(c: Vector2, rad: float) -> void:
	soft_shadow_circle(c + Vector2(6, 10), rad, 0.5)
	draw_circle(c, rad, Color(0.85, 0.9, 0.92, 0.35))
	draw_circle(c, rad * 0.86, Color(0.55, 0.33, 0.12, 0.9))
	for k in 4:
		var p := c + Vector2(cos(k * 1.7), sin(k * 1.7)) * rad * 0.4
		draw_rect(Rect2(p - Vector2(9, 9), Vector2(18, 18)), Color(0.92, 0.95, 0.97, 0.75))
	draw_arc(c, rad * 0.93, PI * 1.1, PI * 1.7, 16, Color(1, 1, 1, 0.6), 3.0)


func _draw() -> void:
	# Mặt bàn gỗ sẫm dưới đèn bàn: giữa sáng, mép tối.
	tex_fill(Rect2(Vector2.ZERO, size), TEX_DARK_WOOD, Color(0.78, 0.66, 0.52), 420.0)
	glow(Vector2(size.x * 0.46, size.y * 0.38), size.x * 0.55, Color(1.0, 0.9, 0.7, 0.35))
	# Xấp hóa đơn bên trái.
	for k in 3:
		var hr := Rect2(size.x * 0.04 + k * 6, size.y * 0.16 + k * 10, size.x * 0.13, size.y * 0.32)
		soft_shadow(hr, Vector2(4, 6), 6.0, 0.4)
		draw_rect(hr, Color(0.97, 0.95, 0.9).darkened(0.04 * (2 - k)))
		for j in 7:
			draw_line(hr.position + Vector2(10, 24 + j * 18), hr.position + Vector2(hr.size.x - 10 - (j * 13) % 30, 24 + j * 18), Color(0.4, 0.4, 0.45, 0.55), 1.5)
	# Trang sổ: giấy kẻ dòng xanh, lề đỏ, mép giấy hơi ngả vàng.
	var paper := Rect2(size.x * 0.22, size.y * 0.07, size.x * 0.54, size.y * 0.62)
	soft_shadow(paper, Vector2(8, 14), 14.0, 0.55)
	grad_rect(paper, Color(0.98, 0.96, 0.9), Color(0.93, 0.9, 0.82))
	for j in 13:
		var y := paper.position.y + 62.0 + j * (paper.size.y - 72.0) / 12.0
		draw_line(Vector2(paper.position.x, y), Vector2(paper.end.x, y), Color(0.55, 0.68, 0.85, 0.55), 1.2)
	draw_line(Vector2(paper.position.x + 56, paper.position.y), Vector2(paper.position.x + 56, paper.end.y), Color(0.85, 0.35, 0.35, 0.7), 1.6)
	for j in 6:
		draw_circle(Vector2(paper.position.x + 22, paper.position.y + 40 + j * paper.size.y / 6.0), 7, Color(0.25, 0.2, 0.16))
	_pen(Vector2(paper.position.x + 70, paper.position.y + 44), "Sổ thu chi · sạp chợ Long Biên · tờ %d/%d" % [mini(sheet + 1, int(cfg.get("rounds", 6))), int(cfg.get("rounds", 6))], 26, INK_BLUE)
	var row_h := (paper.size.y - 72.0) / 12.0
	for j in lines.size():
		var y := paper.position.y + 62.0 + (j + 1) * row_h - 6.0
		_pen(Vector2(paper.position.x + 70, y), str(lines[j].name), 24, INK_BLUE)
		_pen(Vector2(paper.end.x - 26, y), money(int(lines[j].v)), 26, INK_BLUE if int(lines[j].v) > 0 else INK_RED, true)
	var sum_y := paper.position.y + 62.0 + (lines.size() + 1.6) * row_h
	draw_line(Vector2(paper.end.x - 190, sum_y - 22), Vector2(paper.end.x - 24, sum_y - 22), INK_BLUE, 2.0)
	_pen(Vector2(paper.position.x + 70, sum_y), "Số dư cuối ngày:", 24, INK_BLUE)
	_pen(Vector2(paper.end.x - 26, sum_y), "?" if picked < 0 else money(int(answers[correct])), 26, INK_BLUE, true)
	# Đồng hồ cát giờ của tờ: vệt bút chì chạy dọc mép dưới trang.
	var left := 1.0 - _t / float(cfg.get("secondsPerSheet", 14.0))
	draw_line(Vector2(paper.position.x + 60, paper.end.y - 14), Vector2(paper.position.x + 60 + (paper.size.x - 90) * clampf(left, 0.0, 1.0), paper.end.y - 14), Color(0.35, 0.35, 0.38, 0.85) if left > 0.3 else INK_RED, 4.0)
	# Bút bi đặt chéo, máy tính, cốc trà đá.
	draw_line(Vector2(paper.end.x - 60, paper.end.y + 30), Vector2(paper.end.x + 90, paper.end.y - 60), Color(0.12, 0.2, 0.55), 10.0)
	draw_line(Vector2(paper.end.x - 60, paper.end.y + 30), Vector2(paper.end.x - 75, paper.end.y + 39), Color(0.85, 0.85, 0.82), 6.0)
	_calculator(Rect2(size.x * 0.81, size.y * 0.12, size.x * 0.15, 260))
	_tea(Vector2(size.x * 0.11, size.y * 0.75), 46.0)
	# Ba đáp án: giấy nhớ vàng dán trên bàn, viết tay.
	for i in answers.size():
		var rr := _option_rect(i)
		soft_shadow(rr, Vector2(5, 8), 8.0, 0.5)
		var col := Color(0.99, 0.9, 0.45)
		if picked >= 0 and i == correct:
			col = Color(0.75, 0.93, 0.6)
		elif picked == i:
			col = Color(0.98, 0.65, 0.6)
		grad_rect(rr, col, col.darkened(0.08))
		draw_rect(Rect2(rr.position, Vector2(rr.size.x, 10)), col.darkened(0.12))
		_pen(rr.position + Vector2(14, 30), "%d" % (i + 1), 22, Color(0.4, 0.35, 0.2))
		_pen(rr.get_center() + Vector2(0, 22), money(int(answers[i])), 30, INK_BLUE)
		if picked >= 0 and i == correct:
			draw_arc(rr.get_center() + Vector2(0, 10), rr.size.x * 0.46, 0, TAU, 32, INK_RED, 3.0)
	vignette(0.6)
	text_at(Vector2(size.x * 0.5, size.y * 0.97), "Khớp %d · lệch %d · phím 1, 2, 3 hay bấm vào giấy" % [right, wrong], 16, UI.HUD_TEXT)
