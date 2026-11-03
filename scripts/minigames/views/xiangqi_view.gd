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


const SIDEWALK := preload("res://assets/textures/via_he_albedo.jpg")


## Ghế nhựa đỏ nhìn từ trên (mặt ghế tròn có lỗ thoát nước), chén trà, ấm trà.
func _stool(c: Vector2, rad: float, col: Color) -> void:
	soft_shadow_circle(c + Vector2(10, 14), rad, 0.55)
	draw_circle(c, rad, col.darkened(0.25))
	draw_circle(c, rad * 0.9, col)
	for k in 4:
		var a := k * TAU / 4.0 + 0.4
		draw_circle(c + Vector2(cos(a), sin(a)) * rad * 0.45, rad * 0.08, col.darkened(0.45))
	draw_arc(c, rad * 0.8, PI * 1.1, PI * 1.6, 16, Color(1, 1, 1, 0.25), rad * 0.08)


func _tea_set(c: Vector2) -> void:
	soft_shadow_circle(c + Vector2(8, 12), 46.0, 0.5)
	draw_circle(c, 46, Color(0.85, 0.83, 0.78))
	draw_circle(c, 40, Color(0.93, 0.91, 0.86))
	draw_circle(c, 13, Color(0.8, 0.78, 0.72))
	draw_line(c + Vector2(40, -6), c + Vector2(70, -24), Color(0.85, 0.83, 0.78), 9.0)
	for k in 3:
		var cup := c + Vector2(-70 + k * 32, 70)
		soft_shadow_circle(cup + Vector2(4, 6), 14.0, 0.45)
		draw_circle(cup, 14, Color(0.92, 0.9, 0.85))
		draw_circle(cup, 10, Color(0.62, 0.45, 0.18))


## Quân cờ gỗ: đĩa gỗ nổi khối, vòng khắc trong, chữ son đỏ hay mực đen.
func _piece(at: Vector2, rad: float, pc: String, lifted: bool) -> void:
	var red := pc.begins_with("r")
	var ink := Color(0.7, 0.1, 0.08) if red else Color(0.1, 0.1, 0.1)
	var off := Vector2(4, 8) if lifted else Vector2(2, 4)
	soft_shadow_circle(at + off * (2.0 if lifted else 1.0), rad, 0.55 if lifted else 0.45)
	var p := at - (Vector2(0, 6) if lifted else Vector2.ZERO)
	disc(p, rad, Color(0.93, 0.82, 0.6), Color(0.62, 0.45, 0.25))
	draw_arc(p, rad * 0.78, 0, TAU, 36, ink, 2.0)
	var name: String = NAMES.get(pc.substr(1), "?")
	text_at(p + Vector2(0, rad * 0.2), name, int(rad * (0.62 if name.length() <= 3 else 0.46)), ink)


func _draw() -> void:
	tex_fill(Rect2(Vector2.ZERO, size), SIDEWALK, Color(0.62, 0.58, 0.54), 300.0)
	var c := _cell()
	var o := _origin()
	_stool(Vector2(o.x - c * 2.4, o.y + c * 2.0), c * 1.3, Color(0.8, 0.16, 0.13))
	_stool(Vector2(o.x + c * (COLS - 1) + c * 2.4, o.y + c * 6.8), c * 1.3, Color(0.16, 0.35, 0.72))
	_tea_set(Vector2(o.x + c * (COLS - 1) + c * 2.6, o.y + c * 1.4))
	# Bàn cờ gỗ: khung dày, mặt vân gỗ, nét kẻ mực nâu.
	var board_r := Rect2(o - Vector2(c * 0.75, c * 0.75), Vector2(c * (COLS - 1 + 1.5), c * (ROWS - 1 + 1.5)))
	soft_shadow(board_r, Vector2(10, 16), 18.0, 0.6)
	tex_fill(board_r, TEX_WOOD, Color(2.1, 1.75, 1.3), 260.0)
	draw_rect(board_r, Color(0.35, 0.22, 0.1), false, 6.0)
	draw_rect(board_r.grow(-10), Color(0.35, 0.22, 0.1, 0.5), false, 1.5)
	var line := Color(0.3, 0.18, 0.08, 0.9)
	for y in ROWS:
		draw_line(_pt(Vector2i(0, y)), _pt(Vector2i(COLS - 1, y)), line, 2.0)
	for x in COLS:
		if x == 0 or x == COLS - 1:
			draw_line(_pt(Vector2i(x, 0)), _pt(Vector2i(x, ROWS - 1)), line, 2.0)
		else:
			draw_line(_pt(Vector2i(x, 0)), _pt(Vector2i(x, 4)), line, 2.0)
			draw_line(_pt(Vector2i(x, 5)), _pt(Vector2i(x, ROWS - 1)), line, 2.0)
	for yy in [[0, 2], [7, 9]]:
		draw_line(_pt(Vector2i(3, yy[0])), _pt(Vector2i(5, yy[1])), line, 1.5)
		draw_line(_pt(Vector2i(5, yy[0])), _pt(Vector2i(3, yy[1])), line, 1.5)
	var hand := preload("res://assets/fonts/PatrickHand-Regular.ttf")
	for t in [["SỞ HÀ", 2], ["HÁN GIỚI", 6]]:
		var at: Vector2 = (_pt(Vector2i(t[1], 4)) + _pt(Vector2i(t[1], 5))) / 2.0
		var w := hand.get_string_size(t[0], HORIZONTAL_ALIGNMENT_LEFT, -1, int(c * 0.42)).x
		draw_string(hand, at + Vector2(-w / 2.0, c * 0.15), t[0], HORIZONTAL_ALIGNMENT_LEFT, -1, int(c * 0.42), Color(0.3, 0.18, 0.08, 0.8))
	for q in targets:
		draw_circle(_pt(q), c * 0.16, Color(0.2, 0.55, 0.25, 0.75))
		draw_arc(_pt(q), c * 0.16, 0, TAU, 20, Color(1, 1, 1, 0.6), 1.5)
	for p in board:
		if p != selected:
			_piece(_pt(p), c * 0.44, board[p], false)
	if board.has(selected):
		_piece(_pt(selected), c * 0.46, board[selected], true)
	vignette(0.6)
	var head := "Thế %d/%d · giải %d · còn %d giây" % [mini(puzzle + 1, int(cfg.get("puzzles", 3))), int(cfg.get("puzzles", 3)), solved, maxi(0, int(float(cfg.get("seconds", 60)) - _t))]
	draw_rect(Rect2(size.x * 0.5 - 200, size.y * 0.015, 400, 32), Color(0, 0, 0, 0.55))
	text_at(Vector2(size.x * 0.5, size.y * 0.015 + 23), head, 19, UI.HUD_TEXT)
	if flash != "":
		draw_rect(Rect2(size.x * 0.5 - 260, size.y * 0.94, 520, 34), Color(0, 0, 0, 0.6))
		text_at(Vector2(size.x * 0.5, size.y * 0.94 + 24), flash, 18, UI.GOLD)
