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

func _option_rect(i: int) -> Rect2:
	var w := minf(220.0, size.x * 0.26)
	var gap := 18.0
	var x0 := size.x * 0.5 - (w * 3.0 + gap * 2.0) / 2.0
	return Rect2(x0 + i * (w + gap), size.y * 0.74, w, 64)


static func money(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "." + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("−" if v < 0 else "") + s + out + "đ"


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("1a1d1a"))
	var paper := Rect2(size.x * 0.22, size.y * 0.12, size.x * 0.56, size.y * 0.55)
	draw_rect(paper, Color("efe6cf"))
	for j in 9:
		var y := paper.position.y + 46.0 + j * (paper.size.y - 56.0) / 8.0
		draw_line(Vector2(paper.position.x + 10, y), Vector2(paper.end.x - 10, y), Color("cfc3a5"), 1.0)
	text_at(Vector2(paper.get_center().x, paper.position.y + 32), "Bảng kê ngày · tờ %d/%d" % [mini(sheet + 1, int(cfg.get("rounds", 6))), int(cfg.get("rounds", 6))], 20, Color("3a2f22"))
	for j in lines.size():
		var y := paper.position.y + 76.0 + j * 36.0
		draw_string(font, Vector2(paper.position.x + 24, y), str(lines[j].name), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("3a2f22"))
		var m := money(int(lines[j].v))
		var w := font.get_string_size(m, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
		draw_string(font, Vector2(paper.end.x - 24 - w, y), m, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("2d6a3a") if int(lines[j].v) > 0 else Color("9a2f22"))
	# Giờ còn lại của tờ.
	bar_at(Rect2(paper.position.x, paper.end.y + 10, paper.size.x, 8), 1.0 - _t / float(cfg.get("secondsPerSheet", 14.0)), Color("e8b45a"))
	for i in answers.size():
		var rr := _option_rect(i)
		var col := Color(0.12, 0.13, 0.12, 0.95)
		if picked >= 0 and i == correct:
			col = Color("2d6a3a")
		elif picked == i:
			col = Color("8a2f22")
		draw_rect(rr, col)
		draw_rect(rr, Color(1, 1, 1, 0.3), false, 1.5)
		text_at(rr.get_center() + Vector2(0, 8), "%d · %s" % [i + 1, money(int(answers[i]))], 20, UI.HUD_TEXT)
	text_at(Vector2(size.x * 0.5, size.y * 0.95), "Khớp %d · lệch %d" % [right, wrong], 16, UI.INK_SOFT)
