extends RefCounted
## Đồ phố Việt cho khu thật (map của truyện, mô hình Dựng khu thật), dựng cùng lúc với nhà ở area_builder.gd:
## - Mặt tiền nhìn ra đường: mái hiên tôn hay bạt, biển hiệu (quanh chỗ của truyện thì có chữ: tạp hóa, phở, sửa
##   xe…), trước vài nhà có bàn ghế nhựa quán cóc.
## - Cột điện bê tông dọc đường, dây điện võng giữa các cột, dây giăng ngang hẻm; cột có thùng điện, có cuộn dây.
## - Cổng hẻm "khu phố văn hóa" ở miệng hẻm có tên, bảng tên đường xanh ở chỗ hai đường có tên gặp nhau.
## Mái hiên, biển hiệu, cổng hẻm nằm trong lưới nhà (kiểu 2 trong shader): nhà hạ thì biển ẩn theo, mái hiên và cổng
## có ô riêng trong ảnh caps nên tự ẩn khi chắn trước An. Chữ là Label3D, update_cut của area_builder bật tắt theo.

const Geo := preload("res://scripts/realmap/geo.gd")
const SEG_CELL := 20.0

var b
var cfg: Dictionary
## Chỉ dựng trong vòng radius mét quanh center; chữ trên biển, cổng, bảng tên đường chỉ trong vòng label_radius;
## tối đa max_labels biển có chữ (gần chỗ của truyện nhất).
var center := Vector2.ZERO
var radius := INF
var label_radius := 0.0
var max_labels := 48
## Dây điện: nhìn xa (mô hình thu nhỏ) thì dây mảnh nhấp nháy, chỉ bật ở màn phố.
var wires := true
## Đổi tên đường thật sang tên hiện trên bảng (map của truyện dùng tên hư cấu).
var name_of := func(s: String) -> String: return s
var font: Font
var _rng := RandomNumberGenerator.new()
var _seg := {}
var _labels := 0
var _stools: Array = []
## Biển có thể ghi chữ: chọn những biển gần các địa điểm của truyện nhất (keep_clear của builder) khi xong.
var _boards: Array = []
## Đếm để in khi thử: nhà xét, có mặt tiền, mái hiên, biển, cột, cổng.
var counts := {"homes": 0, "fronts": 0, "awnings": 0, "boards": 0, "poles": 0, "gates": 0, "signs": 0}
var _st_poles := SurfaceTool.new()
var _st_wires := SurfaceTool.new()


func _init(builder, options: Dictionary) -> void:
	b = builder
	cfg = builder.cfg.get("street", {})
	for k in options:
		set(k, options[k])
	font = builder.font
	_rng.seed = 4242
	_st_poles.begin(Mesh.PRIMITIVE_TRIANGLES)
	_st_wires.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in b.data.roads:
		if r.bridge or r.tunnel or str(r.kind) == "steps":
			continue
		for i in r.line.size() - 1:
			var a: Vector2 = r.line[i]
			var c: Vector2 = r.line[i + 1]
			if a.distance_squared_to(c) < 0.01:
				continue
			var box := Rect2(a, Vector2.ZERO).expand(c).grow(float(r.width) / 2.0 + 6.0)
			for gx in range(floori(box.position.x / SEG_CELL), floori(box.end.x / SEG_CELL) + 1):
				for gy in range(floori(box.position.y / SEG_CELL), floori(box.end.y / SEG_CELL) + 1):
					var k := Vector2i(gx, gy)
					if not _seg.has(k):
						_seg[k] = []
					_seg[k].append([a, c, r])


func _near(p: Vector2, r: float) -> bool:
	return p.distance_to(center) <= r


func _pick(key: String, fallback: Array) -> String:
	var list: Array = cfg.get(key, fallback)
	return str(list[_rng.randi() % list.size()])


# ---------------------------------------------------------------- mặt tiền

## Cạnh nhà nhìn ra đường gần nhất: cạnh dài từ 2,4 m, song song với một đoạn đường, mép đường cách cạnh dưới 5 m
## (bề rộng đường trong OSM hay thiếu phần vỉa hè).
## Trả về {a, b, n (pháp tuyến ra đường), road} hay {} nếu nhà không có mặt tiền.
func _frontage(poly: PackedVector2Array) -> Dictionary:
	var c := Geo.centroid(poly)
	var best := {}
	var best_d := INF
	for i in poly.size():
		var a := poly[i]
		var e := poly[(i + 1) % poly.size()]
		var l := a.distance_to(e)
		if l < 2.4:
			continue
		var d := (e - a) / l
		var n := d.orthogonal()
		var m := (a + e) / 2.0
		if n.dot(m - c) < 0.0:
			n = -n
		var probe := m + n * 1.0
		for s in _seg.get(Vector2i(floori(probe.x / SEG_CELL), floori(probe.y / SEG_CELL)), []):
			var sa: Vector2 = s[0]
			var sb: Vector2 = s[1]
			var sd := (sb - sa).normalized()
			if absf(sd.dot(d)) < 0.85:
				continue
			var q := Geometry2D.get_closest_point_to_segment(m, sa, sb)
			if (q - m).dot(n) <= 0.0:
				continue
			var gap := q.distance_to(m) - float(s[2].width) / 2.0
			if gap < 5.0 and gap < best_d:
				best_d = gap
				best = {"a": a, "b": e, "n": n, "road": s[2]}
	return best


## Mặt tiền một căn (idx: số của căn trong ảnh caps): mái hiên, biển hiệu, chỗ kê bàn ghế quán cóc.
func front(st: SurfaceTool, idx: int, poly: PackedVector2Array, base: float, h: float) -> void:
	if base > 0.5 or h < 3.0 or not _near(Geo.centroid(poly), radius):
		return
	counts.homes += 1
	var f := _frontage(poly)
	if f.is_empty():
		return
	counts.fronts += 1
	var n: Vector2 = f.n
	var d: Vector2 = ((f.b as Vector2) - (f.a as Vector2)).normalized()
	var a: Vector2 = (f.a as Vector2) + d * 0.2
	var e: Vector2 = (f.b as Vector2) - d * 0.2
	var l := a.distance_to(e)
	var small := bool(f.road.small) or float(f.road.width) < 6.0
	if _rng.randf() < float(cfg.get("awningShare", 0.7)):
		var dep := _rng.randf_range(0.9, 1.35)
		var col := Color(_pick("awnings", ["2f6fb0"]))
		var own: int = b._cut_add(PackedVector2Array([a, e, e + n * dep, a + n * dep]), 2.8)
		counts.awnings += 1
		st.set_custom(0, Color(own, 2.0, 0.0, 0.0))
		var hi := 2.75
		var uv2 := Vector2(0.0, hi)
		var lo := 2.45
		_quad(st, Vector3(a.x, hi, a.y), Vector3(e.x, hi, e.y), Vector3(e.x + n.x * dep, lo, e.y + n.y * dep), Vector3(a.x + n.x * dep, lo, a.y + n.y * dep), col, uv2)
		# Diềm trước mái hiên.
		var a2 := a + n * dep
		var e2 := e + n * dep
		_quad(st, Vector3(a2.x, lo, a2.y), Vector3(e2.x, lo, e2.y), Vector3(e2.x, lo - 0.22, e2.y), Vector3(a2.x, lo - 0.22, a2.y), col.darkened(0.15), uv2)
	if h >= 3.9 and l >= 2.0 and _rng.randf() < float(cfg.get("signShare", 0.5)):
		st.set_custom(0, Color(idx, 2.0, 0.0, 0.0))
		counts.boards += 1
		var board := Color(_pick("boards", ["c0392b"]))
		var y0 := 2.95
		var y1 := minf(3.85, h - 0.15)
		var p0 := a + n * 0.12 + d * 0.15
		var p1 := e + n * 0.12 - d * 0.15
		_slab(st, p0, p1, n, 0.1, y0, y1, board, Vector2(0.0, y1))
		var mid := (p0 + p1) / 2.0 + n * 0.07
		if _near(mid, label_radius):
			_boards.append({"idx": idx, "text": _pick("hemSigns" if small else "signs", ["TẠP HÓA"]), "pos": Vector3(mid.x, (y0 + y1) / 2.0, mid.y),
				"n": n, "w": p0.distance_to(p1) - 0.4, "h": y1 - y0 - 0.2, "board": board, "top": y1 + 0.2})
	if _rng.randf() < float(cfg.get("stoolShare", 0.12)):
		_stools.append([(a + e) / 2.0 + n * _rng.randf_range(1.3, 1.9), d])


## Biển hiệu, bảng tên: chữ một mặt (nhìn từ sau không bị ngược), co cỡ chữ cho vừa bảng.
func _label(text: String, pos: Vector3, facing: Vector2, w: float, hgt: float, board: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = font
	l.font_size = 64
	l.pixel_size = 0.0085
	l.outline_size = 0
	l.double_sided = false
	l.modulate = Color("1d1d1d") if board.get_luminance() > 0.6 else Color("fff4c2")
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.font_size).x * l.pixel_size
	var th := float(l.font_size) * l.pixel_size
	var k := minf(1.0, minf(w / maxf(tw, 0.01), hgt / th))
	l.font_size = maxi(8, int(l.font_size * k))
	l.position = pos
	l.rotation.y = atan2(facing.x, facing.y)
	b.add_child(l)
	_labels += 1
	return l


## Tấm phẳng bốn đỉnh (mặt hai phía nhờ cull_disabled của shader nhà).
static func _quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, col: Color, uv2: Vector2) -> void:
	var n := (p1 - p0).cross(p3 - p0).normalized()
	if n.y < 0.0:
		n = -n
	var none := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	b_tri(st, p0, p1, p2, n, col, none, uv2)
	b_tri(st, p0, p2, p3, n, col, none, uv2)


## Tam giác có pháp tuyến n (như AreaBuilder._tri: tự đảo thứ tự đỉnh cho mặt trước quay về phía n).
static func b_tri(st: SurfaceTool, a: Vector3, c: Vector3, e: Vector3, n: Vector3, col: Color, uv: Array, uv2: Vector2) -> void:
	var pts := [a, c, e]
	var uvs: Array = uv
	if (c - a).cross(e - a).dot(n) > 0.0:
		pts = [a, e, c]
		uvs = [uv[0], uv[2], uv[1]]
	for i in 3:
		st.set_normal(n)
		st.set_color(col)
		st.set_uv(uvs[i])
		st.set_uv2(uv2)
		st.add_vertex(pts[i])


## Gọi f(điểm, hướng) đều đặn mỗi step mét dọc đường gấp khúc (như AreaBuilder._along).
static func _along(line: PackedVector2Array, step: float, f: Callable) -> void:
	var carry := step / 2.0
	for i in line.size() - 1:
		var a := line[i]
		var e := line[i + 1]
		var l := a.distance_to(e)
		if l < 0.01:
			continue
		var d := (e - a) / l
		var s := carry
		while s < l:
			f.call(a + d * s, d)
			s += step
		carry = s - l


## Khối dẹt dựng đứng dọc đoạn p0–p1, dày t (về phía n), từ y0 tới y1: biển hiệu, xà cổng.
static func _slab(st: SurfaceTool, p0: Vector2, p1: Vector2, n: Vector2, t: float, y0: float, y1: float, col: Color, uv2 := Vector2(0.0, 0.0)) -> void:
	var q := [p0, p1, p1 + n * t, p0 + n * t]
	var none := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	var mid := (p0 + p1) / 2.0 + n * t / 2.0
	for i in 4:
		var u: Vector2 = q[i]
		var v: Vector2 = q[(i + 1) % 4]
		var nn := Vector3(v.y - u.y, 0, -(v.x - u.x)).normalized()
		if Vector2(nn.x, nn.z).dot((u + v) / 2.0 - mid) < 0.0:
			nn = -nn
		var shade := col if i != 2 else col.darkened(0.1)
		b_tri(st, Vector3(u.x, y0, u.y), Vector3(v.x, y0, v.y), Vector3(v.x, y1, v.y), nn, shade, none, uv2)
		b_tri(st, Vector3(u.x, y0, u.y), Vector3(v.x, y1, v.y), Vector3(u.x, y1, u.y), nn, shade, none, uv2)
	for y in [y0, y1]:
		var up := Vector3.UP if y == y1 else Vector3.DOWN
		b_tri(st, Vector3(q[0].x, y, q[0].y), Vector3(q[1].x, y, q[1].y), Vector3(q[2].x, y, q[2].y), up, col.darkened(0.05), none, uv2)
		b_tri(st, Vector3(q[0].x, y, q[0].y), Vector3(q[2].x, y, q[2].y), Vector3(q[3].x, y, q[3].y), up, col.darkened(0.05), none, uv2)


# ---------------------------------------------------------------- cổng hẻm (trong lưới nhà)

## Cổng hẻm ở miệng các hẻm có tên (đầu chạm đường lớn hơn): hai trụ, xà ngang sơn xanh, chữ khu phố và tên hẻm.
func gates(st: SurfaceTool) -> void:
	var placed: Array[Vector2] = []
	var cands := []
	for r in b.data.roads:
		var name := str(r.name)
		var words := name.split(" ")
		if r.bridge or r.tunnel or words.size() < 2 or not (words[0] in ["Hẻm", "Ngõ", "Ngách", "Kiệt"]) or r.line.size() < 2:
			continue
		for end in [0, r.line.size() - 1]:
			var p: Vector2 = r.line[end]
			if not _near(p, label_radius):
				continue
			var host := _wider_road_at(p, float(r.width))
			if host.is_empty():
				continue
			cands.append([p.distance_to(center), r, end, host])
	cands.sort_custom(func(x, y) -> bool: return float(x[0]) < float(y[0]))
	for c in cands:
		if placed.size() >= 14:
			break
		var r = c[1]
		var end: int = c[2]
		var p: Vector2 = r.line[end]
		if placed.any(func(q: Vector2) -> bool: return q.distance_to(p) < 30.0):
			continue
		var nxt: Vector2 = r.line[1] if end == 0 else r.line[r.line.size() - 2]
		var into := (nxt - p).normalized()
		# Cổng đứng lùi vào trong hẻm, khỏi mép đường lớn.
		var host = c[3]
		var g := p + into * (float(host.width) / 2.0 + 1.2)
		var side := into.orthogonal()
		var hw := float(r.width) / 2.0 + 0.3
		var poly := PackedVector2Array([g - side * (hw + 0.4) - into * 0.3, g + side * (hw + 0.4) - into * 0.3, g + side * (hw + 0.4) + into * 0.3, g - side * (hw + 0.4) + into * 0.3])
		var own: int = b._cut_add(poly, 5.2)
		st.set_custom(0, Color(own, 2.0, 0.0, 0.0))
		var top := Vector2(0.0, 4.7)
		for s in [-1.0, 1.0]:
			var pp: Vector2 = g + side * s * hw
			_slab(st, pp - side * 0.22 - into * 0.22, pp + side * 0.22 - into * 0.22, into, 0.44, 0.0, 4.6, Color("d8d0c0"), top)
		_slab(st, g - side * (hw + 0.4) - into * 0.2, g + side * (hw + 0.4) - into * 0.2, into, 0.4, 4.0, 4.7, Color("2f6fb0"), top)
		var text := "%s\n%s" % [str(cfg.get("gateText", "KHU PHỐ VĂN HÓA")), str(name_of.call(str(r.name))).to_upper()]
		# Chữ quay về phía nam (phía camera) cho đọc được, ở mặt xà bên đó.
		var face := -into if -into.y > 0.0 else into
		var lb := _label(text, Vector3(g.x + face.x * 0.25, 4.35, g.y + face.y * 0.25), face, hw * 2.0 + 0.4, 0.62, Color("2f6fb0"))
		counts.gates += 1
		b._cut_label(own, lb, 4.9)
		placed.append(p)


## Đường rộng hơn w có tim đường cách p dưới 3 m (đầu hẻm chạm đường đó).
func _wider_road_at(p: Vector2, w: float) -> Dictionary:
	var best := {}
	var best_d := 3.0
	for s in _seg.get(Vector2i(floori(p.x / SEG_CELL), floori(p.y / SEG_CELL)), []):
		if float(s[2].width) <= w + 0.5:
			continue
		var dd := Geo.seg_dist(p, s[0], s[1])
		if dd < best_d:
			best_d = dd
			best = s[2]
	return best


# ---------------------------------------------------------------- cột điện, dây điện, bảng tên đường

## Cột điện mỗi poleStep mét bên một mép đường (đường nào bên nấy, không chắn cửa địa điểm), dây võng nối các cột;
## hẻm có dây giăng ngang từng khúc. Bảng tên đường ở chỗ hai đường có tên gặp nhau.
func streets() -> void:
	var step := float(cfg.get("poleStep", 27.0))
	var k := 0
	for r in b.data.roads:
		k += 1
		if r.bridge or r.tunnel or str(r.kind) in ["footway", "path", "steps", "cycleway"] or float(r.width) < 3.5:
			continue
		var hw := float(r.width) / 2.0
		var side := 1.0 if k % 2 == 0 else -1.0
		var off := hw + (1.2 if float(r.width) >= 7.0 and not r.small else 0.35)
		var poles: Array = []
		_along(r.line, step, func(p: Vector2, d: Vector2) -> void:
			var q: Vector2 = p + d.orthogonal() * off * side
			if not _near(q, radius) or not b.walkable(q) or b.keep_clear.any(func(c: Vector2) -> bool: return c.distance_to(q) < 3.0):
				poles.append(null)
				return
			_pole(q, d)
			counts.poles += 1
			poles.append(q))
		if wires:
			for i in poles.size() - 1:
				if poles[i] != null and poles[i + 1] != null:
					for w in 3:
						var y := 7.0 - w * 0.3
						_wire(Vector3(poles[i].x, y, poles[i].y), Vector3(poles[i + 1].x, y, poles[i + 1].y), 0.45 + w * 0.1)
			# Hẻm: dây giăng ngang từ mép này sang mép kia.
			if r.small or float(r.width) < 6.0:
				_along(r.line, _rng.randf_range(7.0, 11.0), func(p: Vector2, d: Vector2) -> void:
					if not _near(p, radius) or _rng.randf() < 0.35:
						return
					var nn := d.orthogonal()
					var sk := d * _rng.randf_range(-1.5, 1.5)
					_wire(Vector3(p.x + nn.x * (hw + 0.4), _rng.randf_range(5.0, 6.6), p.y + nn.y * (hw + 0.4)), Vector3(p.x - nn.x * (hw + 0.4) + sk.x, _rng.randf_range(5.0, 6.6), p.y - nn.y * (hw + 0.4) + sk.y), 0.3))
	_street_signs()
	for pair in [[_st_poles, Color.WHITE], [_st_wires, Color.WHITE]]:
		var mi := MeshInstance3D.new()
		mi.mesh = (pair[0] as SurfaceTool).commit()
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.85
		mi.material_override = m
		if pair[0] == _st_wires:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.add_child(mi)


## Cột điện bê tông vuông 8 m, xà ngang, sứ cách điện; cột chẵn có thùng điện, có cuộn dây thừa.
func _pole(q: Vector2, d: Vector2) -> void:
	var col := Color("7a776f")
	var n := d.orthogonal()
	_box(_st_poles, Vector3(q.x, 0.0, q.y), d, Vector3(0.26, 8.0, 0.26), col)
	_box(_st_poles, Vector3(q.x, 7.15, q.y), n, Vector3(1.7, 0.14, 0.14), col.darkened(0.15))
	if _rng.randf() < 0.45:
		_box(_st_poles, Vector3(q.x + n.x * 0.25, 4.6, q.y + n.y * 0.25), d, Vector3(0.55, 0.8, 0.35), Color("6e7378"))
	if wires and _rng.randf() < 0.5:
		# Cuộn dây thừa quấn quanh cột.
		_box(_st_wires, Vector3(q.x, 5.4, q.y), d, Vector3(0.5, 0.35, 0.5), Color("232325"))


## Hộp đứng tại chân p (giữa đáy), trục dài theo d (mặt đất), kích thước s = (dọc d, cao, ngang).
static func _box(st: SurfaceTool, p: Vector3, d: Vector2, s: Vector3, col: Color) -> void:
	var u := Vector3(d.x, 0, d.y) * s.x / 2.0
	var v := Vector3(-d.y, 0, d.x) * s.z / 2.0
	var y := Vector3(0, s.y, 0)
	var c := [p - u - v, p + u - v, p + u + v, p - u + v]
	var none := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	for i in 4:
		var a: Vector3 = c[i]
		var e: Vector3 = c[(i + 1) % 4]
		var nn := ((a + e) / 2.0 - p).normalized()
		nn.y = 0.0
		b_tri(st, a, e, e + y, nn.normalized(), col, none, Vector2.ZERO)
		b_tri(st, a, e + y, a + y, nn.normalized(), col, none, Vector2.ZERO)
	b_tri(st, c[0] + y, c[1] + y, c[2] + y, Vector3.UP, col.lightened(0.06), none, Vector2.ZERO)
	b_tri(st, c[0] + y, c[2] + y, c[3] + y, Vector3.UP, col.lightened(0.06), none, Vector2.ZERO)


## Dây điện võng xuống sag mét ở giữa: ba khúc dải mỏng nằm ngang (camera luôn nhìn từ trên xuống).
func _wire(p0: Vector3, p1: Vector3, sag: float) -> void:
	var col := Color("2a2a2c")
	var n := 3
	var prev := p0
	var side := Vector3(p1.z - p0.z, 0, -(p1.x - p0.x)).normalized() * 0.025
	var none := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	for i in range(1, n + 1):
		var t := float(i) / n
		var cur := p0.lerp(p1, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0)
		b_tri(_st_wires, prev - side, prev + side, cur + side, Vector3.UP, col, none, Vector2.ZERO)
		b_tri(_st_wires, prev - side, cur + side, cur - side, Vector3.UP, col, none, Vector2.ZERO)
		prev = cur


## Bảng tên đường (nền xanh, chữ trắng) trên cột nhỏ ở góc chỗ hai đường có tên gặp nhau, trong vùng có chữ.
func _street_signs() -> void:
	var done: Array[Vector2] = []
	var roads: Array = b.data.roads.filter(func(r) -> bool:
		return str(r.name) != "" and not r.bridge and not r.tunnel and float(r.width) >= 5.0 and not str(r.name).begins_with("Hẻm"))
	for r in roads:
		for end in [0, r.line.size() - 1]:
			var p: Vector2 = r.line[end]
			if done.size() >= 14 or not _near(p, label_radius) or done.any(func(q: Vector2) -> bool: return q.distance_to(p) < 40.0):
				continue
			for o in roads:
				if is_same(o, r) or str(o.name) == str(r.name):
					continue
				var hit := false
				for i in o.line.size() - 1:
					if Geo.seg_dist(p, o.line[i], o.line[i + 1]) < 2.0:
						hit = true
						break
				if not hit:
					continue
				var nxt: Vector2 = r.line[1] if end == 0 else r.line[r.line.size() - 2]
				var into := (nxt - p).normalized()
				var q := p + into * (float(o.width) / 2.0 + 1.5) + into.orthogonal() * (float(r.width) / 2.0 + 0.5)
				if not b.walkable(q):
					q = p + into * (float(o.width) / 2.0 + 1.5) - into.orthogonal() * (float(r.width) / 2.0 + 0.5)
				_box(_st_poles, Vector3(q.x, 0.0, q.y), into, Vector3(0.08, 3.1, 0.08), Color("5d6166"))
				var face := into.orthogonal()
				if face.y < 0.0:
					face = -face
				_box(_st_poles, Vector3(q.x, 2.7, q.y), face.orthogonal(), Vector3(1.2, 0.34, 0.05), Color("1e5aa8"))
				var text := str(name_of.call(str(r.name)))
				_label(text, Vector3(q.x + face.x * 0.04, 2.87, q.y + face.y * 0.04), face, 1.1, 0.24, Color("1e5aa8"))
				done.append(p)
				counts.signs += 1
				break


# ---------------------------------------------------------------- ghế nhựa quán cóc

## Chữ trên biển hiệu (những biển gần chỗ của truyện nhất), bàn ghế nhựa trước các quán (sau khi có lưới đi bộ:
## chỉ kê chỗ đi được, không vào nhà).
func finish() -> void:
	var spots: Array = b.keep_clear if not b.keep_clear.is_empty() else [center]
	for bd in _boards:
		var p := Vector2(bd.pos.x, bd.pos.z)
		var best := INF
		for s in spots:
			best = minf(best, p.distance_to(s))
		bd["d"] = best
	_boards.sort_custom(func(x, y) -> bool: return float(x.d) < float(y.d))
	for bd in _boards.slice(0, max_labels):
		b._cut_label(int(bd.idx), _label(str(bd.text), bd.pos, bd.n, float(bd.w), float(bd.h), bd.board), float(bd.top))
	var items := []
	for s in _stools:
		var p: Vector2 = s[0]
		var d: Vector2 = s[1]
		if not b.walkable(p):
			continue
		var col := Color(["2f6fb0", "c0392b", "2f6fb0", "e8e4da"][_rng.randi() % 4])
		items.append([p, d, Vector3(0.6, 0.45, 0.6), Color("c0392b") if col == Color("2f6fb0") else Color("2f6fb0")])
		for k in _rng.randi_range(2, 4):
			var a := TAU * k / 4.0 + _rng.randf_range(-0.3, 0.3)
			items.append([p + Vector2(cos(a), sin(a)) * 0.55, d, Vector3(0.3, 0.42 if k % 2 == 0 else 0.26, 0.3), col])
	if items.is_empty():
		return
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.6
	bm.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = bm
	mm.instance_count = items.size()
	for i in items.size():
		var it: Array = items[i]
		var p: Vector2 = it[0]
		var s: Vector3 = it[2]
		var basis := Basis(Vector3.UP, atan2((it[1] as Vector2).x, (it[1] as Vector2).y)).scaled(s)
		mm.set_instance_transform(i, Transform3D(basis, Vector3(p.x, s.y / 2.0, p.y)))
		mm.set_instance_color(i, it[3])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	b.add_child(mmi)
