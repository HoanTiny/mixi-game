extends "res://scripts/minigames/views/minigame_view.gd"
## Cờ tướng vỉa hè: giải thế cờ tàn "một nước chiếu bí". Quân đỏ (dưới) đi trước; bấm quân đỏ rồi bấm ô đích. Nước đi
## chiếu bí là giải được thế; đi sai thì ông cụ lắc đầu, còn lượt thì thử lại. Mỗi thế có giờ riêng.
## Thế cờ sinh ngẫu nhiên rồi tự kiểm (luật đủ cho tướng, sĩ, xe, mã cản chân, pháo, tốt, lộ mặt tướng), nên luôn có lời giải.
## cfg: puzzles (số thế), seconds (giờ mỗi thế), tries (số lần đi sai được phép mỗi thế), defenders (quân đen phòng thủ thêm).
## Kết quả thô: {"score": số thế giải / số thế, "solved", "puzzles", "fails": số nước đi sai}.

const COLS := 9
const ROWS := 10
## Tên quân viết chữ Việt (phông web không có chữ Hán).
const NAMES := {"K": "Tướng", "A": "Sĩ", "R": "Xe", "N": "Mã", "C": "Pháo", "P": "Tốt"}

var board := {}
var puzzle := 0
var solved := 0
var wrong := 0
var tries_left := 0
var selected := Vector2i(-1, -1)
var targets: Array = []
var flash := ""
var _t := 0.0
var _rest := -1.0
var _rng := RandomNumberGenerator.new()


func rules() -> String:
	return "Thế cờ tàn: quân đỏ (bên dưới) đi một nước là chiếu bí tướng đen. Bấm vào quân đỏ rồi bấm ô muốn đi (chấm vàng là nước đi được). Mỗi thế %d giây, được đi sai %d lần. Có %d thế." % [int(cfg.get("seconds", 60)), int(cfg.get("tries", 2)) - 1, int(cfg.get("puzzles", 3))]


func _setup() -> void:
	_rng.randomize()


func _begin() -> void:
	_new_puzzle()


func _new_puzzle() -> void:
	board = make_puzzle(_rng, int(cfg.get("defenders", 1)))
	tries_left = int(cfg.get("tries", 2))
	selected = Vector2i(-1, -1)
	targets = []
	flash = ""
	_t = 0.0
	_rest = -1.0


# ---------------------------------------------------------------- luật cờ (tĩnh, kiểm headless)

static func inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < COLS and p.y >= 0 and p.y < ROWS


static func in_palace(p: Vector2i, side: String) -> bool:
	return inside(p) and p.x >= 3 and p.x <= 5 and (p.y <= 2 if side == "b" else p.y >= 7)


## Các ô quân ở p đi tới được (chưa xét tướng mình có bị chiếu sau nước đi).
static func moves(b: Dictionary, p: Vector2i) -> Array:
	var pc: String = b.get(p, "")
	if pc == "":
		return []
	var side := pc.left(1)
	var t := pc.substr(1)
	var out := []
	match t:
		"K":
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = p + d
				if in_palace(q, side) and not str(b.get(q, "")).begins_with(side):
					out.append(q)
		"A":
			for d in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
				var q: Vector2i = p + d
				if in_palace(q, side) and not str(b.get(q, "")).begins_with(side):
					out.append(q)
		"R", "C":
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = p + d
				var jumped := false
				while inside(q):
					var o: String = b.get(q, "")
					if t == "R":
						if o == "":
							out.append(q)
						else:
							if not o.begins_with(side):
								out.append(q)
							break
					else:
						if not jumped:
							if o == "":
								out.append(q)
							else:
								jumped = true
						elif o != "":
							if not o.begins_with(side):
								out.append(q)
							break
					q += d
		"N":
			for d in [Vector2i(1, 2), Vector2i(-1, 2), Vector2i(1, -2), Vector2i(-1, -2), Vector2i(2, 1), Vector2i(-2, 1), Vector2i(2, -1), Vector2i(-2, -1)]:
				var leg := p + (Vector2i(0, d.y / 2) if absi(d.y) == 2 else Vector2i(d.x / 2, 0))
				var q: Vector2i = p + d
				if inside(q) and not b.has(leg) and not str(b.get(q, "")).begins_with(side):
					out.append(q)
		"P":
			var fwd := Vector2i(0, -1) if side == "r" else Vector2i(0, 1)
			var dirs := [fwd]
			var crossed := p.y <= 4 if side == "r" else p.y >= 5
			if crossed:
				dirs.append_array([Vector2i(1, 0), Vector2i(-1, 0)])
			for d in dirs:
				var q: Vector2i = p + d
				if inside(q) and not str(b.get(q, "")).begins_with(side):
					out.append(q)
	return out


static func king(b: Dictionary, side: String) -> Vector2i:
	for p in b:
		if b[p] == side + "K":
			return p
	return Vector2i(-1, -1)


## Tướng bên side đang bị chiếu (kể cả hai tướng nhìn mặt nhau trên một cột trống).
static func in_check(b: Dictionary, side: String) -> bool:
	var k := king(b, side)
	if k.x < 0:
		return true
	var other := "b" if side == "r" else "r"
	var ok := king(b, other)
	if ok.x == k.x:
		var clear := true
		for y in range(mini(k.y, ok.y) + 1, maxi(k.y, ok.y)):
			if b.has(Vector2i(k.x, y)):
				clear = false
				break
		if clear:
			return true
	for p in b:
		if str(b[p]).begins_with(other) and str(b[p]) != other + "K" and moves(b, p).has(k):
			return true
	return false


static func apply(b: Dictionary, from: Vector2i, to: Vector2i) -> Dictionary:
	var n := b.duplicate()
	n[to] = n[from]
	n.erase(from)
	return n


static func legal(b: Dictionary, side: String) -> Array:
	var out := []
	for p in b.keys():
		if str(b[p]).begins_with(side):
			for q in moves(b, p):
				if not in_check(apply(b, p, q), side):
					out.append([p, q])
	return out


static func is_mate(b: Dictionary, side: String) -> bool:
	return in_check(b, side) and legal(b, side).is_empty()


## Các nước đỏ chiếu bí ngay.
static func mates(b: Dictionary) -> Array:
	var out := []
	for m in legal(b, "r"):
		if is_mate(apply(b, m[0], m[1]), "b"):
			out.append(m)
	return out


## Sinh thế cờ: tướng, sĩ đen trong cung, vài quân đỏ tấn công; nhận khi chưa ai bị chiếu và đỏ có 1–2 nước chiếu bí.
static func make_puzzle(rng: RandomNumberGenerator, defenders := 1) -> Dictionary:
	for attempt in 4000:
		var b := {}
		var bk := Vector2i(rng.randi_range(3, 5), rng.randi_range(0, 2))
		b[bk] = "bK"
		var rk := Vector2i(rng.randi_range(3, 5), rng.randi_range(7, 9))
		b[rk] = "rK"
		var palace_b := [Vector2i(3, 0), Vector2i(5, 0), Vector2i(4, 1), Vector2i(3, 2), Vector2i(5, 2)]
		for i in rng.randi_range(0, 2):
			var a: Vector2i = palace_b[rng.randi_range(0, palace_b.size() - 1)]
			if not b.has(a):
				b[a] = "bA"
		for i in defenders:
			var q := Vector2i(rng.randi_range(0, 8), rng.randi_range(0, 4))
			if not b.has(q):
				b[q] = ["bR", "bN", "bC", "bP"][rng.randi_range(0, 3)]
		var kinds := ["rR", "rN", "rC", "rR", "rN", "rP"]
		for i in rng.randi_range(2, 3):
			var q := Vector2i(rng.randi_range(0, 8), rng.randi_range(0, 6))
			if not b.has(q):
				b[q] = kinds[rng.randi_range(0, kinds.size() - 1)]
		if in_check(b, "b") or in_check(b, "r"):
			continue
		var m := mates(b)
		if m.size() >= 1 and m.size() <= 2:
			return b
	return {}


# ---------------------------------------------------------------- chơi

func _click(cell: Vector2i) -> void:
	if _rest >= 0.0:
		return
	if str(board.get(cell, "")).begins_with("r"):
		selected = cell
		targets = []
		for q in moves(board, cell):
			if not in_check(apply(board, cell, q), "r"):
				targets.append(q)
		return
	if selected.x < 0 or not targets.has(cell):
		return
	var after := apply(board, selected, cell)
	if is_mate(after, "b"):
		board = after
		solved += 1
		flash = "Chiếu bí! Ông cụ gật gù."
		_rest = 0.0
	else:
		wrong += 1
		tries_left -= 1
		flash = "Chưa bí, tướng đen còn đường chạy." if tries_left > 0 else "Hết lượt. Ông cụ chỉ cho nước đúng."
		if tries_left <= 0:
			var m := mates(board)
			if not m.is_empty():
				board = apply(board, m[0][0], m[0][1])
			_rest = 0.0
	selected = Vector2i(-1, -1)
	targets = []


func _play_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		var cell := _cell_at(event.position)
		if inside(cell):
			_click(cell)


func _play(delta: float) -> void:
	if _rest >= 0.0:
		_rest += delta
		if _rest >= 1.4:
			puzzle += 1
			if puzzle >= int(cfg.get("puzzles", 3)):
				end()
			else:
				_new_puzzle()
		return
	_t += delta
	if _t >= float(cfg.get("seconds", 60.0)):
		wrong += 1
		flash = "Hết giờ."
		_rest = 0.0


func result() -> Dictionary:
	var n := int(cfg.get("puzzles", 3))
	return {"score": float(solved) / float(maxi(1, n)), "solved": solved, "puzzles": n, "fails": wrong}


func summary(r: Dictionary) -> String:
	return "Giải được %d/%d thế cờ." % [int(r.solved), int(r.puzzles)] + (" Các cụ mời mai ra đánh tiếp." if int(r.solved) >= 2 else "")


# ---------------------------------------------------------------- vẽ

func _cell() -> float:
	return minf(size.x * 0.6 / float(COLS), size.y * 0.78 / float(ROWS))


func _origin() -> Vector2:
	var c := _cell()
	return Vector2(size.x * 0.5 - c * (COLS - 1) / 2.0, size.y * 0.53 - c * (ROWS - 1) / 2.0)


func _pt(p: Vector2i) -> Vector2:
	return _origin() + Vector2(p.x, p.y) * _cell()


func _cell_at(pos: Vector2) -> Vector2i:
	var g := (pos - _origin()) / _cell()
	return Vector2i(roundi(g.x), roundi(g.y))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("1e1a16"))
	var c := _cell()
	var o := _origin()
	draw_rect(Rect2(o - Vector2(c * 0.6, c * 0.6), Vector2(c * (COLS - 1 + 1.2), c * (ROWS - 1 + 1.2))), Color("d9b77c"))
	var line := Color("5a3d1e")
	for y in ROWS:
		draw_line(_pt(Vector2i(0, y)), _pt(Vector2i(COLS - 1, y)), line, 1.5)
	for x in COLS:
		if x == 0 or x == COLS - 1:
			draw_line(_pt(Vector2i(x, 0)), _pt(Vector2i(x, ROWS - 1)), line, 1.5)
		else:
			draw_line(_pt(Vector2i(x, 0)), _pt(Vector2i(x, 4)), line, 1.5)
			draw_line(_pt(Vector2i(x, 5)), _pt(Vector2i(x, ROWS - 1)), line, 1.5)
	for yy in [[0, 2], [7, 9]]:
		draw_line(_pt(Vector2i(3, yy[0])), _pt(Vector2i(5, yy[1])), line, 1.5)
		draw_line(_pt(Vector2i(5, yy[0])), _pt(Vector2i(3, yy[1])), line, 1.5)
	text_at((_pt(Vector2i(2, 4)) + _pt(Vector2i(2, 5))) / 2.0 + Vector2(0, 7), "SỞ HÀ", 18, line)
	text_at((_pt(Vector2i(6, 4)) + _pt(Vector2i(6, 5))) / 2.0 + Vector2(0, 7), "HÁN GIỚI", 18, line)
	for p in board:
		var pc: String = board[p]
		var at := _pt(p)
		draw_circle(at, c * 0.43, Color("f3e3c0"))
		draw_arc(at, c * 0.43, 0, TAU, 32, Color("b0201c") if pc.begins_with("r") else Color("1b1b1b"), 2.5)
		if p == selected:
			draw_arc(at, c * 0.5, 0, TAU, 32, Color("f2d04a"), 3.0)
		text_at(at + Vector2(0, c * 0.1), NAMES.get(pc.substr(1), "?"), int(c * 0.27), Color("b0201c") if pc.begins_with("r") else Color("1b1b1b"))
	for q in targets:
		draw_circle(_pt(q), c * 0.13, Color(0.95, 0.8, 0.25, 0.9))
	var head := "Thế %d/%d · giải %d · còn %d giây" % [mini(puzzle + 1, int(cfg.get("puzzles", 3))), int(cfg.get("puzzles", 3)), solved, maxi(0, int(float(cfg.get("seconds", 60)) - _t))]
	text_at(Vector2(size.x * 0.5, size.y * 0.06), head, 20, UI.HUD_TEXT)
	if flash != "":
		text_at(Vector2(size.x * 0.5, size.y * 0.97), flash, 18, UI.GOLD)
