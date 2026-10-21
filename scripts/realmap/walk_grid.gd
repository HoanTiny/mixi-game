extends RefCounted
## Lưới đi bộ 1 m cho khu thật: không đi xuyên nhà, tường, mặt nước (trừ trên cầu); lòng đường luôn đi được.
## Đường, hẻm, vỉa hè, công viên đi bình thường; khe hở giữa các dãy nhà, bãi đất trống vẫn đi được nhưng tính
## đắt gấp OFF_ROAD lần, nên đường tìm được bám theo phố và hẻm như người thật, chỉ chui khe khi không còn lối nào.
## Tìm đường A* rồi rút gọn các điểm thẳng hàng. Dùng cho mô hình Dựng khu thật và map nướng sẵn của truyện.

const Geo := preload("res://scripts/realmap/geo.gd")
const OFF_ROAD := 6.0
const PARK := 1.3
const PARK_KINDS := ["park", "garden", "pitch", "playground", "village_green", "recreation_ground", "pedestrian", "square"]

var grid: AStarGrid2D


func _init(data, bounds: Rect2) -> void:
	var r := bounds.grow(40.0)
	grid = AStarGrid2D.new()
	grid.region = Rect2i(floori(r.position.x), floori(r.position.y), ceili(r.size.x), ceili(r.size.y))
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	grid.fill_weight_scale_region(grid.region, OFF_ROAD)
	for p in data.parks:
		if str(p.kind) in PARK_KINDS:
			_weigh_poly(p.poly, PARK)
	# Mặt đường cộng vỉa hè (đường từ 7 m có vỉa hè lát gạch 1,6 m mỗi bên).
	for rd in data.roads:
		if not rd.tunnel:
			var w := float(rd.width)
			_weigh_line(rd.line, w / 2.0 + (1.6 if w >= 7.0 and not rd.small else 0.5))
	for w in data.water:
		_block_poly(w.poly)
	for w in data.waterways:
		_block_line(w.line, float(w.width) / 2.0)
	for b in data.buildings:
		if float(b.min_height) < 2.0:
			_block_poly(b.poly)
	for w in data.walls:
		_block_line(w.line, 0.35)
	# Lòng đường luôn đi được, kể cả chỗ nhà vẽ lấn ra đường (lỗi vẽ hay gặp); cầu đi được dù bên dưới là nước.
	for rd in data.roads:
		if not rd.tunnel and not rd.bridge and str(rd.kind) not in ["footway", "path", "steps"]:
			_block_line(rd.line, maxf(float(rd.width) / 2.0 - 0.8, 0.5), false)
	for rd in data.roads:
		if rd.bridge:
			_block_line(rd.line, float(rd.width) / 2.0, false)


## Tô kín đa giác lên lưới theo từng hàng (quét ngang ở ba độ cao trong ô), nới mỗi đoạn 0,35 m:
## ô nào có phần đáng kể nằm trong nhà thì chặn, đường đi không cắt góc nhà. Mỗi khúc một lần tô cả dải ô.
func _block_poly(poly: PackedVector2Array) -> void:
	var r := Geo.bounds(poly)
	for z in range(floori(r.position.y), ceili(r.end.y)):
		for fy in [0.15, 0.5, 0.85]:
			var xs := _crossings(poly, z + fy)
			for k in range(0, xs.size() - 1, 2):
				var x0 := floori(xs[k] + 0.35)
				var x1 := ceili(xs[k + 1] - 0.35)
				if x1 > x0:
					grid.fill_solid_region(Rect2i(x0, z, x1 - x0, 1), true)


## Ô trong đa giác (công viên, quảng trường) tính giá đi bộ weight.
func _weigh_poly(poly: PackedVector2Array, weight: float) -> void:
	var r := Geo.bounds(poly)
	for z in range(floori(r.position.y), ceili(r.end.y)):
		var xs := _crossings(poly, z + 0.5)
		for k in range(0, xs.size() - 1, 2):
			var x0 := roundi(xs[k])
			var x1 := roundi(xs[k + 1])
			if x1 > x0:
				grid.fill_weight_scale_region(Rect2i(x0, z, x1 - x0, 1), weight)


## Hoành độ các chỗ đường ngang y cắt cạnh đa giác, xếp tăng dần.
static func _crossings(poly: PackedVector2Array, y: float) -> PackedFloat32Array:
	var xs := PackedFloat32Array()
	var n := poly.size()
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		if (a.y <= y and b.y > y) or (b.y <= y and a.y > y):
			xs.append(a.x + (y - a.y) / (b.y - a.y) * (b.x - a.x))
	xs.sort()
	return xs


## Ô cách tim đường không quá hw mét đi với giá thường.
func _weigh_line(line: PackedVector2Array, hw: float) -> void:
	for i in line.size() - 1:
		var rows := _capsule_rows(line[i], line[i + 1], hw)
		for k in range(0, rows.size(), 3):
			grid.fill_weight_scale_region(Rect2i(rows[k + 1], rows[k], rows[k + 2] - rows[k + 1] + 1, 1), 1.0)


func _block_line(line: PackedVector2Array, hw: float, solid := true) -> void:
	for i in line.size() - 1:
		var rows := _capsule_rows(line[i], line[i + 1], hw)
		for k in range(0, rows.size(), 3):
			grid.fill_solid_region(Rect2i(rows[k + 1], rows[k], rows[k + 2] - rows[k + 1] + 1, 1), solid)


## Các ô có tâm cách đoạn a–b không quá r, theo từng hàng: [z, x đầu, x cuối, z, ...]. Hình con nhộng là hình lồi
## nên mỗi hàng chỉ một khúc: hợp của khúc cắt hai hình tròn ở hai đầu và khúc cắt dải giữa
## (0 ≤ (P − a)·d ≤ l, |(P − a)·n| ≤ r, cả hai tuyến tính theo x).
static func _capsule_rows(a: Vector2, b: Vector2, r: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var l := a.distance_to(b)
	var d := (b - a) / l if l > 0.0001 else Vector2.RIGHT
	var n := d.orthogonal()
	for z in range(floori(minf(a.y, b.y) - r), ceili(maxf(a.y, b.y) + r) + 1):
		var y := z + 0.5
		var lo := INF
		var hi := -INF
		var dy := y - a.y
		if absf(dy) <= r:
			var s := sqrt(r * r - dy * dy)
			lo = a.x - s
			hi = a.x + s
		dy = y - b.y
		if absf(dy) <= r:
			var s := sqrt(r * r - dy * dy)
			lo = minf(lo, b.x - s)
			hi = maxf(hi, b.x + s)
		if l > 0.0001:
			var i0 := -INF
			var i1 := INF
			var ok := true
			# Theo trục d: 0 ≤ (x − a.x)·d.x + (y − a.y)·d.y ≤ l.
			var base := (y - a.y) * d.y
			if absf(d.x) > 1e-6:
				var x0 := (0.0 - base) / d.x + a.x
				var x1 := (l - base) / d.x + a.x
				i0 = minf(x0, x1)
				i1 = maxf(x0, x1)
			elif base < 0.0 or base > l:
				ok = false
			# Theo pháp tuyến n: −r ≤ (x − a.x)·n.x + (y − a.y)·n.y ≤ r.
			base = (y - a.y) * n.y
			if absf(n.x) > 1e-6:
				var x0 := (-r - base) / n.x + a.x
				var x1 := (r - base) / n.x + a.x
				i0 = maxf(i0, minf(x0, x1))
				i1 = minf(i1, maxf(x0, x1))
			elif absf(base) > r:
				ok = false
			if ok and i0 <= i1:
				lo = minf(lo, i0)
				hi = maxf(hi, i1)
		# Ô x có tâm x + 0,5 nằm trong [lo, hi].
		var c0 := ceili(lo - 0.5)
		var c1 := floori(hi - 0.5)
		if lo <= hi and c0 <= c1:
			out.append(z)
			out.append(c0)
			out.append(c1)
	return out


func walkable(p: Vector2) -> bool:
	var cell := Vector2i(floori(p.x), floori(p.y))
	return grid.is_in_boundsv(cell) and not grid.is_point_solid(cell)


## Chỗ đi được gần p nhất; trong vòng 6 m có mặt đường thì lấy mặt đường (bấm vào nhà thì đi tới trước cửa,
## không chui vào khe sau nhà).
func nearest_walkable(p: Vector2) -> Vector2:
	if walkable(p) and _cost(p) <= PARK:
		return p
	for rad in range(1, 7):
		for k in rad * 8:
			var a := TAU * k / float(rad * 8)
			var q := p + Vector2(cos(a), sin(a)) * rad
			if walkable(q) and _cost(q) <= PARK:
				return q
	if walkable(p):
		return p
	for rad in range(1, 40):
		for k in rad * 8:
			var a := TAU * k / float(rad * 8)
			var q := p + Vector2(cos(a), sin(a)) * rad
			if walkable(q):
				return q
	return p


func _cost(p: Vector2) -> float:
	var cell := Vector2i(floori(p.x), floori(p.y))
	return grid.get_point_weight_scale(cell) if grid.is_in_boundsv(cell) else OFF_ROAD


## Đường đi bộ từ a tới b (mét), đã rút gọn các điểm thẳng hàng.
func path(a: Vector2, b: Vector2) -> PackedVector2Array:
	var s := nearest_walkable(a)
	var g := nearest_walkable(b)
	var ids := grid.get_id_path(Vector2i(floori(s.x), floori(s.y)), Vector2i(floori(g.x), floori(g.y)))
	if ids.is_empty():
		return PackedVector2Array()
	var pts := PackedVector2Array([s])
	for i in range(1, ids.size() - 1):
		pts.append(Vector2(ids[i]) + Vector2(0.5, 0.5))
	pts.append(g)
	var out := PackedVector2Array([pts[0]])
	var i := 0
	while i < pts.size() - 1:
		var j := pts.size() - 1
		while j > i + 1 and not _clear(pts[i], pts[j]):
			j -= 1
		out.append(pts[j])
		i = j
	return out


## Đi thẳng từ a tới b được không: không vướng gì, và không cắt qua chỗ đắt hơn cả hai đầu (đang đi trên phố thì
## không đi tắt qua khe nhà hay bãi trống).
func _clear(a: Vector2, b: Vector2) -> bool:
	var steps := int(ceil(a.distance_to(b) / 0.5))
	var lim := maxf(_cost(a), _cost(b))
	for k in steps + 1:
		var q := a.lerp(b, float(k) / float(maxi(steps, 1)))
		if not walkable(q) or _cost(q) > lim:
			return false
	return true
