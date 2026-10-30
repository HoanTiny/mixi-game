extends RefCounted
## Bản đồ phường An Hòa đọc từ data/map.json: các đoạn đường (đường lớn, đường chợ, bờ kè, hẻm, cầu),
## con rạch, lưới ô đi bộ để tìm đường (AStarGrid2D), lô nhà mặt tiền và số nhà kiểu Sài Gòn (42/7/3).
## Mọi toạ độ 2D là Vector2(x, z) trên mặt đất; x tăng về phía đông, z tăng về phía nam.

const HOUSE_MIN := 3.5
const DEPTH_MAX := 14.0
## Nhà mặt đường lớn sâu hơn, nhà trong hẻm nông hơn (cho hẻm còn chỗ có cửa nhà hai bên).
const DEPTHS := {"duong": Vector2(9.0, 12.0), "cho": Vector2(8.0, 11.0), "bo_ke": Vector2(8.0, 10.5), "hem": Vector2(6.5, 10.0), "hem_nho": Vector2(5.5, 9.0)}
## Lùi vào trong lề đường một chút để An không đi sát rạt vào tường nhà.
const INSET := 0.2

var data: Dictionary
var bounds: Rect2
## id -> đoạn đường đã tính sẵn: rect, axis ("x" chạy ngang, "z" chạy dọc), start/end (đầu hẻm trước), name.
var streets := {}
var order: Array = []
## Lô nhà mặt tiền: {street, side, u, center, normal, w, d, no, address, loc}. loc khác "" là địa điểm của truyện.
var plots: Array = []
## id địa điểm -> lô nhà của nó.
var locs := {}
## Khối nhà phía trong (chỉ thấy mái): {rect: Rect2, h: float}.
var fillers: Array = []
var canal_pts := PackedVector2Array()
var canal_w := 9.0
var _grid := AStarGrid2D.new()
var _foot: Array = []


func _init(path := "res://data/map.json") -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string(path))
	var b: Array = data.bounds
	bounds = Rect2(float(b[0]), float(b[1]), float(b[2]) - float(b[0]), float(b[3]) - float(b[1]))
	for s in data.streets:
		_prep(s)
	for p in data.canal.points:
		canal_pts.append(Vector2(float(p[0]), float(p[1])))
	canal_w = float(data.canal.w)
	_place_locations()
	var rng := RandomNumberGenerator.new()
	rng.seed = 30
	# Đường lớn có tên trước (giữ góc phố), rồi tới hẻm chính, hẻm nhánh.
	for id in _by_rank():
		for side in streets[id].houses:
			_fill_side(id, str(side), rng)
	_number()
	_build_fillers(rng)
	_build_grid()


# ---------------------------------------------------------------- đường

func _prep(s: Dictionary) -> void:
	var a := Vector2(float(s.a[0]), float(s.a[1]))
	var b := Vector2(float(s.b[0]), float(s.b[1]))
	var hw := float(s.w) / 2.0
	var st := s.duplicate(true)
	if absf(a.y - b.y) < 0.01:
		st["axis"] = "x"
		st["lo"] = minf(a.x, b.x)
		st["hi"] = maxf(a.x, b.x)
		st["c"] = a.y
		st["rect"] = Rect2(st.lo, a.y - hw, st.hi - st.lo, hw * 2.0)
	else:
		st["axis"] = "z"
		st["lo"] = minf(a.y, b.y)
		st["hi"] = maxf(a.y, b.y)
		st["c"] = a.x
		st["rect"] = Rect2(a.x - hw, st.lo, hw * 2.0, st.hi - st.lo)
	# Hướng đánh số: từ đầu nối với đường cha (hẻm cụt thì từ phía ngược đầu cụt).
	var start := b if str(s.get("dead_end", "")) == "a" else a
	var finish := a if start == b else b
	st["start"] = start
	st["dir"] = (finish - start).normalized()
	st["display"] = str(s.get("name", ""))
	# Vùng đi được: lùi khỏi tường hai bên một chút, còn hai đầu thì lấn sang đường cha để chỗ giao nhau liền mạch.
	var r: Rect2 = st.rect
	if st.axis == "x":
		st["walk"] = Rect2(r.position.x - 0.4, r.position.y + INSET, r.size.x + 0.8, r.size.y - INSET * 2.0)
	else:
		st["walk"] = Rect2(r.position.x + INSET, r.position.y - 0.4, r.size.x - INSET * 2.0, r.size.y + 0.8)
	st["houses"] = s.get("houses", [])
	streets[str(s.id)] = st
	order.append(str(s.id))


func _by_rank() -> Array:
	var out := []
	for id in order:
		if not streets[id].has("parent"):
			out.append(id)
	var guard := 0
	while out.size() < order.size() and guard < 10:
		guard += 1
		for id in order:
			if not out.has(id) and out.has(str(streets[id].parent)):
				out.append(id)
	return out


func street_name(id: String) -> String:
	return str(streets[id].display)


## Toạ độ dọc theo trục đường của điểm p.
func _u(st: Dictionary, p: Vector2) -> float:
	return p.x if st.axis == "x" else p.y


## Vector pháp tuyến của mặt tiền phía side: hướng từ nhà ra đường.
static func side_normal(side: String) -> Vector2:
	match side:
		"n":
			return Vector2(0, 1)
		"s":
			return Vector2(0, -1)
		"w":
			return Vector2(1, 0)
		_:
			return Vector2(-1, 0)


## Điểm giữa mặt tiền tại toạ độ u trên phía side của đường.
func _facade(st: Dictionary, side: String, u: float) -> Vector2:
	var r: Rect2 = st.rect
	match side:
		"n":
			return Vector2(u, r.position.y)
		"s":
			return Vector2(u, r.end.y)
		"w":
			return Vector2(r.position.x, u)
		_:
			return Vector2(r.end.x, u)


## Góc quay quanh trục y để mặt trước (trục +z cục bộ) nhìn theo pháp tuyến n.
static func rot_y(n: Vector2) -> float:
	return atan2(n.x, n.y)


# ---------------------------------------------------------------- lô nhà

func _plot(street: String, side: String, u: float, w: float, d: float, loc := "") -> Dictionary:
	var st: Dictionary = streets[street]
	var n := side_normal(side)
	var c := _facade(st, side, u)
	return {"street": street, "side": side, "u": u, "center": c, "normal": n, "w": w, "d": d, "no": "", "address": "", "loc": loc}


## Hình chữ nhật nền nhà của lô (mặt tiền tại center, lùi vào trong d mét).
static func footprint(p: Dictionary) -> Rect2:
	var c: Vector2 = p.center
	var n: Vector2 = p.normal
	var t := Vector2(-n.y, n.x)
	var a: Vector2 = c - t * float(p.w) / 2.0
	var b: Vector2 = c + t * float(p.w) / 2.0 - n * float(p.d)
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (a - b).abs())


## Chiều sâu còn trống phía sau mặt tiền: dừng khi chạm đường khác, nền nhà đã có, hoặc mép bản đồ.
## Chạm đường khác thì chỉ lấy một nửa để dãy nhà bên kia còn chỗ quay lưng vào.
func _free_depth(street: String, side: String, u0: float, u1: float) -> float:
	var st: Dictionary = streets[street]
	var n := side_normal(side)
	var best := DEPTH_MAX
	for u in [u0 + 0.3, (u0 + u1) / 2.0, u1 - 0.3]:
		var c := _facade(st, side, u)
		# Chỉ xét những hình chữ nhật nằm trên tia đi vào trong, cho đỡ phải dò cả trăm nền nhà mỗi bước.
		var ray := Rect2(c, Vector2.ZERO).expand(c - n * 30.0).grow(0.1)
		var roads := []
		for id in order:
			if id != street and (streets[id].rect as Rect2).intersects(ray):
				roads.append(streets[id].rect)
		var houses := []
		for f in _foot:
			if (f as Rect2).intersects(ray):
				houses.append(f)
		var d := 0.5
		var halve := false
		while d < 30.0:
			var p := c - n * d
			if not bounds.has_point(p):
				break
			var hit := false
			for r in roads:
				if (r as Rect2).has_point(p):
					hit = true
					halve = true
					break
			if not hit:
				for f in houses:
					if (f as Rect2).has_point(p):
						hit = true
						break
			if hit:
				break
			d += 0.5
		best = minf(best, (d / 2.0 if halve else d) - 0.25)
	return best


func _place_locations() -> void:
	for id in data.locations:
		var l: Dictionary = data.locations[id]
		var p := _plot(str(l.street), str(l.side), float(l.at), float(l.w), float(l.d), str(id))
		plots.append(p)
		locs[str(id)] = p
		_foot.append(footprint(p))


## Lấp nhà ống dọc một phía đường, chừa chỗ giao với đường khác và chỗ đã có địa điểm.
func _fill_side(street: String, side: String, rng: RandomNumberGenerator) -> void:
	var st: Dictionary = streets[street]
	var n := side_normal(side)
	var line := _facade(st, side, 0.0)
	# Dải ngay sau mặt tiền: đường nào cắt qua dải này là chỗ giao, không xây nhà.
	var band: Rect2
	if st.axis == "x":
		band = Rect2(st.lo, line.y - (1.0 if n.y > 0 else -0.01), st.hi - st.lo, 0.99)
	else:
		band = Rect2(line.x - (1.0 if n.x > 0 else -0.01), st.lo, 0.99, st.hi - st.lo)
	var cut := []
	for id in order:
		if id == street:
			continue
		var r: Rect2 = streets[id].rect
		if r.intersects(band):
			cut.append(Vector2(_u(st, r.position), _u(st, r.end)) + Vector2(-0.3, 0.3))
	for p in plots:
		if p.street == street and p.side == side:
			cut.append(Vector2(float(p.u) - float(p.w) / 2.0, float(p.u) + float(p.w) / 2.0))
	cut.sort_custom(func(a, b) -> bool: return a.x < b.x)
	var u: float = st.lo
	var spans := []
	for c in cut:
		if c.x > u:
			spans.append(Vector2(u, c.x))
		u = maxf(u, c.y)
	spans.append(Vector2(u, st.hi))
	for sp in spans:
		var x: float = sp.x
		while sp.y - x >= HOUSE_MIN:
			var w := minf(rng.randf_range(3.8, 5.5), sp.y - x)
			if sp.y - x - w < HOUSE_MIN and sp.y - x - w > 0.0:
				w = sp.y - x
			var dr: Vector2 = DEPTHS.get(str(st.kind), Vector2(8.0, 12.0))
			var d := minf(rng.randf_range(dr.x, dr.y), _free_depth(street, side, x, x + w))
			if d >= 4.0:
				var p := _plot(street, side, x + w / 2.0, w, d)
				plots.append(p)
				_foot.append(footprint(p))
			x += w


# ---------------------------------------------------------------- số nhà, tên hẻm

## Số lẻ bên trái, số chẵn bên phải theo hướng đi từ đầu đường. Hẻm lấy số của căn nhà ngay trước đầu hẻm
## trên đường cha, nhà trong hẻm đánh "42/1, 42/3…", hẻm nhánh "42/7/…" như địa chỉ Sài Gòn.
func _number() -> void:
	for id in _by_rank():
		var st: Dictionary = streets[id]
		var root: String = id
		var prefix := ""
		if st.has("parent"):
			var par: Dictionary = streets[str(st.parent)]
			var no := _entrance_number(str(st.parent), st)
			prefix = (str(par.prefix) + "/" if str(par.prefix) != "" else "") + no
			root = str(par.root)
			if str(st.display) == "":
				st["display"] = "Hẻm " + prefix
			st["official"] = "Hẻm " + prefix
		st["prefix"] = prefix
		st["root"] = root
		var dir: Vector2 = st.dir
		var left := Vector2(dir.y, -dir.x)
		var mine := []
		for p in plots:
			if p.street == id:
				mine.append(p)
		mine.sort_custom(func(a, b) -> bool: return (a.center as Vector2).dot(dir) < (b.center as Vector2).dot(dir))
		var odd := 1
		var even := 2
		for p in mine:
			var k: int
			if (p.normal as Vector2) * -1.0 == left:
				k = odd
				odd += 2
			else:
				k = even
				even += 2
			p["no"] = (prefix + "/" if prefix != "" else "") + str(k)
			p["address"] = "%s %s" % [p.no, streets[root].display]


func _entrance_number(parent: String, child: Dictionary) -> String:
	var par: Dictionary = streets[parent]
	var start: Vector2 = child.start
	var u_in := _u(par, start)
	var best := ""
	var best_u := -INF
	var after := ""
	var after_u := INF
	var sign := 1.0 if _u(par, par.dir) >= 0.0 else -1.0
	var side := _side_of(par, start)
	for p in plots:
		# Chỉ xét nhà cùng phía với đầu hẻm.
		if p.street != parent or p.side != side:
			continue
		var du := (float(p.u) - u_in) * sign
		if du < 0.0 and du > best_u:
			best_u = du
			best = str(p.no)
		elif du >= 0.0 and du < after_u:
			after_u = du
			after = str(p.no)
	var no := best if best != "" else after
	return no.get_slice("/", no.get_slice_count("/") - 1)


## Đầu hẻm nằm ở phía nào của đường cha.
func _side_of(par: Dictionary, p: Vector2) -> String:
	var r: Rect2 = par.rect
	if par.axis == "x":
		return "n" if p.y <= r.get_center().y else "s"
	return "w" if p.x <= r.get_center().x else "e"


# ---------------------------------------------------------------- khối nhà phía trong

## Ô 2 m nào không phải đường, nền nhà, rạch, bờ rạch hay ruộng phía nam thì dựng khối nhà phía trong
## (gộp theo hàng cho nhẹ). Nhìn từ trên xuống thấy mái nhà san sát như phố thật.
func _build_fillers(rng: RandomNumberGenerator) -> void:
	var cell := 2.0
	var south_open: float = float(streets.bo_me.rect.end.y) if streets.has("bo_me") else INF
	var nx := int(ceil(bounds.size.x / cell))
	var nz := int(ceil(bounds.size.y / cell))
	# Tô sẵn các ô bị chiếm (đường, nền nhà) lên một lưới thô rồi quét một lượt.
	var used := PackedByteArray()
	used.resize(nx * nz)
	var rects := []
	for id in order:
		rects.append((streets[id].rect as Rect2).grow(0.4))
	for f in _foot:
		rects.append(f)
	for r in rects:
		var g := (r as Rect2).grow(-0.1)
		for i in range(maxi(0, int(floor((g.position.x - bounds.position.x) / cell))), mini(nx, int(ceil((g.end.x - bounds.position.x) / cell)))):
			for j in range(maxi(0, int(floor((g.position.y - bounds.position.y) / cell))), mini(nz, int(ceil((g.end.y - bounds.position.y) / cell)))):
				used[j * nx + i] = 1
	for j in nz:
		var z := bounds.position.y + j * cell
		var run_start := -1
		for i in nx + 1:
			var free := i < nx and z + cell / 2.0 < south_open and used[j * nx + i] == 0
			if free and run_start < 0:
				run_start = i
			elif not free and run_start >= 0:
				_add_filler_run(bounds.position.x + run_start * cell, bounds.position.x + i * cell, z, cell, rng)
				run_start = -1


func _add_filler_run(x0: float, x1: float, z: float, cell: float, rng: RandomNumberGenerator) -> void:
	var x := x0
	while x < x1 - 0.01:
		var w := minf(rng.randf_range(4.0, 9.0), x1 - x)
		if x1 - x - w < 2.0:
			w = x1 - x
		fillers.append({"rect": Rect2(x, z, w, cell), "h": rng.randf_range(6.0, 13.0)})
		x += w


# ---------------------------------------------------------------- đi bộ, tìm đường

func walkable(p: Vector2) -> bool:
	for id in order:
		if (streets[id].walk as Rect2).has_point(p):
			return true
	return false


## Điểm đi được gần p nhất (bấm chuột vào mái nhà thì đi tới lề đường gần đó).
func nearest_walkable(p: Vector2) -> Vector2:
	if walkable(p):
		return p
	var best := p
	var best_d := INF
	for id in order:
		var r: Rect2 = (streets[id].walk as Rect2).grow(-0.05)
		var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
		var d := q.distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = q
	return best


func _build_grid() -> void:
	var x0 := int(floor(bounds.position.x))
	var z0 := int(floor(bounds.position.y))
	_grid.region = Rect2i(x0, z0, int(ceil(bounds.size.x)) + 1, int(ceil(bounds.size.y)) + 1)
	_grid.cell_size = Vector2.ONE
	_grid.offset = Vector2(0.5, 0.5)
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	_grid.update()
	for i in range(_grid.region.position.x, _grid.region.end.x):
		for j in range(_grid.region.position.y, _grid.region.end.y):
			_grid.set_point_solid(Vector2i(i, j), not walkable(Vector2(i + 0.5, j + 0.5)))


func _cell(p: Vector2) -> Vector2i:
	var c := Vector2i(int(floor(p.x)), int(floor(p.y)))
	if _grid.is_in_boundsv(c) and not _grid.is_point_solid(c):
		return c
	# Điểm sát mép: tìm ô đi được gần nhất trong bán kính nhỏ.
	for r in range(1, 4):
		for dx in range(-r, r + 1):
			for dz in range(-r, r + 1):
				var q := c + Vector2i(dx, dz)
				if _grid.is_in_boundsv(q) and not _grid.is_point_solid(q):
					return q
	return c


## Đường đi từ a tới b theo các con đường, đã rút gọn các điểm thẳng hàng. Rỗng nếu không tới được.
func path(a: Vector2, b: Vector2) -> PackedVector2Array:
	var start := nearest_walkable(a)
	var goal := nearest_walkable(b)
	if _clear(start, goal):
		return PackedVector2Array([start, goal])
	var ids := _grid.get_id_path(_cell(start), _cell(goal))
	if ids.is_empty():
		return PackedVector2Array()
	var pts := PackedVector2Array([start])
	for i in range(1, ids.size() - 1):
		pts.append(Vector2(ids[i]) + Vector2(0.5, 0.5))
	pts.append(goal)
	# Rút gọn: từ mỗi điểm nhảy tới điểm xa nhất còn nhìn thấy trực tiếp mà không xuyên nhà.
	var out := PackedVector2Array([pts[0]])
	var i := 0
	while i < pts.size() - 1:
		var j := pts.size() - 1
		while j > i + 1 and not _clear(pts[i], pts[j]):
			j -= 1
		out.append(pts[j])
		i = j
	return out


func path_length(a: Vector2, b: Vector2) -> float:
	var pts := path(a, b)
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i - 1].distance_to(pts[i])
	return total if pts.size() > 1 else a.distance_to(b)


func _clear(a: Vector2, b: Vector2) -> bool:
	var d := a.distance_to(b)
	var steps := int(ceil(d / 0.4))
	for k in range(steps + 1):
		if not walkable(a.lerp(b, float(k) / float(maxi(steps, 1)))):
			return false
	return true


# ---------------------------------------------------------------- rạch, cửa địa điểm

## Tâm con rạch tại hoành độ x (nội suy theo các điểm của đường rạch).
func canal_z(x: float) -> float:
	for i in range(1, canal_pts.size()):
		var a := canal_pts[i - 1]
		var b := canal_pts[i]
		if x <= b.x:
			return lerpf(a.y, b.y, clampf((x - a.x) / maxf(b.x - a.x, 0.001), 0.0, 1.0))
	return canal_pts[canal_pts.size() - 1].y


## Phường vẽ tay không có mặt cầu cao (xem real_city.ground_y).
func ground_y(_p: Vector2) -> float:
	return 0.0


## Cửa của địa điểm: trên vỉa hè trước mặt tiền, cách mặt tiền door_out mét.
var door_out := 0.9


func loc_door(id: String) -> Vector2:
	var p: Dictionary = locs[id]
	return (p.center as Vector2) + (p.normal as Vector2) * door_out
