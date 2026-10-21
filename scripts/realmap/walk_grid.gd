extends RefCounted
## Lưới đi bộ 1 m cho khu thật: không đi xuyên nhà, tường, mặt nước (trừ trên cầu); lòng đường luôn đi được.
## Tìm đường A* rồi rút gọn các điểm thẳng hàng. Dùng cho mô hình Dựng khu thật và map nướng sẵn của truyện.

const Geo := preload("res://scripts/realmap/geo.gd")

var grid: AStarGrid2D


func _init(data, bounds: Rect2) -> void:
	var r := bounds.grow(40.0)
	grid = AStarGrid2D.new()
	grid.region = Rect2i(floori(r.position.x), floori(r.position.y), ceili(r.size.x), ceili(r.size.y))
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
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
## ô nào có phần đáng kể nằm trong nhà thì chặn, đường đi không cắt góc nhà. Nhanh hơn thử từng ô nhiều lần.
func _block_poly(poly: PackedVector2Array) -> void:
	var r := Geo.bounds(poly)
	var n := poly.size()
	for z in range(floori(r.position.y), ceili(r.end.y)):
		for fy in [0.15, 0.5, 0.85]:
			var y: float = z + fy
			var xs := PackedFloat32Array()
			for i in n:
				var a := poly[i]
				var b := poly[(i + 1) % n]
				if (a.y <= y and b.y > y) or (b.y <= y and a.y > y):
					xs.append(a.x + (y - a.y) / (b.y - a.y) * (b.x - a.x))
			xs.sort()
			for k in range(0, xs.size() - 1, 2):
				for x in range(floori(xs[k] + 0.35), ceili(xs[k + 1] - 0.35)):
					var cell := Vector2i(x, z)
					if grid.is_in_boundsv(cell):
						grid.set_point_solid(cell, true)


func _block_line(line: PackedVector2Array, hw: float, solid := true) -> void:
	for i in line.size() - 1:
		var a := line[i]
		var b := line[i + 1]
		var r := Rect2(a, Vector2.ZERO).expand(b).grow(hw + 1.0)
		for x in range(floori(r.position.x), ceili(r.end.x)):
			for z in range(floori(r.position.y), ceili(r.end.y)):
				var cell := Vector2i(x, z)
				if grid.is_in_boundsv(cell) and Geo.seg_dist(Vector2(x + 0.5, z + 0.5), a, b) <= hw:
					grid.set_point_solid(cell, solid)


func walkable(p: Vector2) -> bool:
	var cell := Vector2i(floori(p.x), floori(p.y))
	return grid.is_in_boundsv(cell) and not grid.is_point_solid(cell)


func nearest_walkable(p: Vector2) -> Vector2:
	if walkable(p):
		return p
	for rad in range(1, 40):
		for k in rad * 8:
			var a := TAU * k / float(rad * 8)
			var q := p + Vector2(cos(a), sin(a)) * rad
			if walkable(q):
				return q
	return p


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


func _clear(a: Vector2, b: Vector2) -> bool:
	var steps := int(ceil(a.distance_to(b) / 0.5))
	for k in steps + 1:
		if not walkable(a.lerp(b, float(k) / float(maxi(steps, 1)))):
			return false
	return true
