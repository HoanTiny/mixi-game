extends RefCounted
## Đồ phố Việt cho khu thật (map của truyện, mô hình Dựng khu thật), dựng cùng lúc với nhà ở area_builder.gd:
## - Mặt tiền nhìn ra đường: mái hiên tôn hay bạt, biển hiệu (quanh chỗ của truyện thì có chữ: tạp hóa, phở, sửa
##   xe…), trước vài nhà có bàn ghế nhựa quán cóc. Tầng trên có ban công lan can sắt, hoa giấy rủ qua lan can, cục
##   nóng máy lạnh; có nhà lợp mái ngói ở đỉnh mặt tiền.
## - Sân thượng nhà mái bằng: tường lan can, bồn nước nhựa đen, tum cầu thang lợp ngói, giàn hoa giấy, chậu cây.
## - Cột điện bê tông tròn dọc đường, dây điện võng giữa các cột, dây giăng ngang hẻm; xà có sứ cách điện, cột có
##   thùng điện, có cuộn dây, vài cột có bình biến áp.
## - Cổng hẻm "khu phố văn hóa" ở miệng hẻm có tên, bảng tên đường xanh ở chỗ hai đường có tên gặp nhau; ngã tư
##   đường lớn có vạch qua đường kẻ sọc và đèn giao thông.
## Mái hiên, biển hiệu, cổng hẻm nằm trong lưới nhà (kiểu 2 trong shader): nhà hạ thì biển ẩn theo, mái hiên và cổng
## có ô riêng trong ảnh caps nên tự ẩn khi chắn trước An. Ban công, hoa, tum, bồn nhựa, giàn hoa là kiểu 3 (như kiểu 2
## nhưng không bóng), ẩn theo nhà; đồ cao hơn mái thì nâng đỉnh của căn trong ảnh caps (_raise). Chữ là Label3D,
## update_cut của area_builder bật tắt theo.

const Geo := preload("res://scripts/realmap/geo.gd")
const AreaData := preload("res://scripts/realmap/area_data.gd")
const Props3D := preload("res://scripts/world/props3d.gd")
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
## Cho đám đông (crowd.gd): chỗ ngồi ghế đẩu quán cóc [chỗ, hướng mặt về bàn, cao ghế]; trước cửa tiệm có biển hiệu
## [chỗ đứng trên vỉa hè, hướng ra đường]; chân cột điện (người đi bộ đi tránh).
var seats: Array = []
var shops: Array = []
var pole_spots: Array = []
## Biển có thể ghi chữ: chọn những biển gần các địa điểm của truyện nhất (keep_clear của builder) khi xong.
var _boards: Array = []
## Chữ biển hiệu đã dựng {label, day: màu ban ngày} (màn phố đổi một phần thành chữ neon về đêm) và chỗ treo đèn lồng
## trước các biển hiệu {pos: Vector3 mép dưới biển, n: hướng ra đường}.
var sign_labels: Array = []
var lantern_spots: Array = []
## Đếm để in khi thử: nhà xét, có mặt tiền, mái hiên, biển, ban công, mái ngói mặt tiền, sân thượng, tum, cột, cổng.
var counts := {"homes": 0, "fronts": 0, "awnings": 0, "boards": 0, "balconies": 0, "canopies": 0, "roofs": 0, "tums": 0,
	"poles": 0, "gates": 0, "signs": 0, "crossings": 0, "lights": 0}
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
	# Khu Hà Nội: biển hiệu, chữ cổng theo kiểu ngoài Bắc (khóa có đuôi Hanoi trong realmap.json).
	if str(b.region).begins_with("hanoi") and cfg.has(key + "Hanoi"):
		key += "Hanoi"
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


## Một căn (idx: số của căn trong ảnh caps; st: lưới nhà của ô chứa căn): mặt tiền có mái hiên, biển hiệu, chỗ kê bàn
## ghế quán cóc, ban công các tầng trên; nhà mái bằng có đồ trên sân thượng. info: flat (mái bằng), wall (màu tường),
## lh (cao mỗi tầng).
func front(st: SurfaceTool, idx: int, poly: PackedVector2Array, base: float, h: float, info := {}) -> void:
	if base > 0.5 or h < 3.0 or not _near(Geo.centroid(poly), radius):
		return
	counts.homes += 1
	var f := _frontage(poly)
	if bool(info.get("flat", false)) and h < 30.0:
		_roof(st, idx, poly, h, info, f)
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
		shops.append([(a + e) / 2.0 + n * _rng.randf_range(0.7, 1.1) + d * _rng.randf_range(-0.6, 0.6), n])
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
	if h < 30.0:
		_balconies(st, idx, a, e, n, h, info)


# ---------------------------------------------------------------- ban công, sân thượng

## Ban công các tầng trên ở mặt tiền a–e (n: pháp tuyến ra đường): sàn đúc, lan can song sắt, hoa giấy rủ qua lan can
## (flowerShare số nhà có hoa), cục nóng máy lạnh treo tường (acShare mỗi tầng); có nhà lợp mái ngói che ở đỉnh mặt
## tiền (canopyShare). Mặt tiền dài (chung cư, dãy nhà) chia nhiều ban công, mỗi cái chừng 4 m. Ban công, hoa, cục
## nóng ở lưới chi tiết (nhìn xa khỏi vẽ), mái ngói ở lưới nhà.
func _balconies(st: SurfaceTool, idx: int, a: Vector2, e: Vector2, n: Vector2, h: float, info: Dictionary) -> void:
	var lh := float(info.get("lh", 3.2))
	var l := a.distance_to(e)
	if h < lh * 2.0 or l < 2.0:
		return
	var d := (e - a) / l
	var wall: Color = info.get("wall", Color("e8e2d4"))
	var det: SurfaceTool = b._bst((a + e) / 2.0, true)
	det.set_custom(0, Color(idx, 3.0, 0.0, 0.0))
	var flowers := _rng.randf() < float(cfg.get("flowerShare", 0.55))
	var iron := 0.3 if _rng.randf() < 0.7 else 0.4
	var dep := _rng.randf_range(0.8, 1.1)
	var parts := clampi(roundi(l / 4.2), 1, 4)
	var seg := l / parts
	var top_y := 0.0
	for k in range(1, mini(floori((h - 0.4) / lh), 7)):
		var y := k * lh
		if y + 1.4 > h:
			break
		top_y = y
		for p in parts:
			var p0 := a + d * (seg * p + 0.3)
			var p1 := a + d * (seg * (p + 1) - 0.3)
			if p0.distance_to(p1) >= 1.3:
				_balcony(det, p0, p1, n, dep, y, wall, iron, flowers and _rng.randf() < 0.8)
				counts.balconies += 1
		if _rng.randf() < float(cfg.get("acShare", 0.35)):
			_ac(det, a + d * _rng.randf_range(0.5, maxf(l - 0.5, 0.6)), n, d, y + 1.65)
	if top_y > 0.0 and _rng.randf() < float(cfg.get("canopyShare", 0.3)):
		_canopy(st, idx, a, e, n, h, dep + 0.35, wall)


## Một ban công: sàn đúc dày 0,16 m nhô dep mét, lan can cao 1 m ba mặt (song sắt do shader vẽ: UV.x mét dọc lan can,
## UV.y 0..1, UV2.x là màu sắt), hoa giấy trên tay vịn. UV2.y: đỉnh cộng thêm 0,9 m vì ban công nhô về phía An hơn
## tường nhà, phải ẩn sớm hơn khi hạ nhà.
func _balcony(st: SurfaceTool, p0: Vector2, p1: Vector2, n: Vector2, dep: float, y: float, wall: Color, iron: float, flowers: bool) -> void:
	var top := y + 1.9
	_slab(st, p0, p1, n, dep, y - 0.16, y, wall.lightened(0.3), Vector2(0.0, top))
	var q0 := p0 + n * dep
	var q1 := p1 + n * dep
	var run := 0.0
	for pair in [[p0, q0], [q0, q1], [q1, p1]]:
		var u: Vector2 = pair[0]
		var v: Vector2 = pair[1]
		var sl := u.distance_to(v)
		_quad_uv(st, Vector3(u.x, y, u.y), Vector3(v.x, y, v.y), Vector3(v.x, y + 1.0, v.y), Vector3(u.x, y + 1.0, u.y), wall.darkened(0.3),
			[Vector2(run, 0.0), Vector2(run + sl, 0.0), Vector2(run + sl, 1.0), Vector2(run, 1.0)], Vector2(iron, top))
		run += sl
	if flowers:
		_flowers(st, q0, q1, n, y + 1.0, Vector2(0.0, top))


## Hoa giấy trên tay vịn lan can q0–q1: vài chùm hồng sen, hồng phấn xen lá xanh, có chùm rủ xuống mặt trước.
func _flowers(st: SurfaceTool, q0: Vector2, q1: Vector2, n: Vector2, y: float, uv2: Vector2) -> void:
	var l := q0.distance_to(q1)
	var d := (q1 - q0) / maxf(l, 0.01)
	var count := clampi(roundi(l / 1.2), 1, 4)
	for i in count:
		var c := q0 + d * l * (float(i) + _rng.randf_range(0.25, 0.75)) / float(count) + n * 0.05
		var pink := Color(_pick("flowers", ["e0338a", "f26ca7", "d6246e"]))
		_bush(st, Vector3(c.x, y + 0.08, c.y), Vector3(_rng.randf_range(0.35, 0.6), _rng.randf_range(0.25, 0.38), 0.32), pink, d, uv2)
		if _rng.randf() < 0.65:
			var hang := c + d * _rng.randf_range(-0.3, 0.3) + n * 0.12
			_bush(st, Vector3(hang.x, y - 0.42, hang.y), Vector3(0.26, 0.42, 0.16), pink.darkened(0.06), d, uv2)
		if _rng.randf() < 0.55:
			var lf := c + d * _rng.randf_range(0.3, 0.5) - n * 0.05
			_bush(st, Vector3(lf.x, y + 0.12, lf.y), Vector3(0.3, 0.26, 0.26), Color(_pick("leaves", ["4e8a3a"])), d, uv2)


## Cục nóng máy lạnh treo tường (p ở chân tường, y: đáy cục nóng): hộp trắng ngà, mặt trước có ô quạt sẫm.
func _ac(st: SurfaceTool, p: Vector2, n: Vector2, d: Vector2, y: float) -> void:
	var uv2 := Vector2(0.0, y + 1.45)
	_box(st, Vector3(p.x + n.x * 0.16, y, p.y + n.y * 0.16), d, Vector3(0.78, 0.55, 0.3), Color("e6e5df"), uv2)
	var f := p + n * 0.315
	_quad(st, Vector3(f.x - d.x * 0.3, y + 0.08, f.y - d.y * 0.3), Vector3(f.x + d.x * 0.1, y + 0.08, f.y + d.y * 0.1),
		Vector3(f.x + d.x * 0.1, y + 0.47, f.y + d.y * 0.1), Vector3(f.x - d.x * 0.3, y + 0.47, f.y - d.y * 0.3), Color("4a4d52"), uv2)


## Mái ngói giả ở đỉnh mặt tiền a–e (kiểu nhà phố có mái thái): dốc từ trên đỉnh tường xuống, nhô ra out mét, hai
## đầu bịt tường tam giác. Ở lưới nhà (nhìn xa vẫn thấy mái đỏ cam).
func _canopy(st: SurfaceTool, idx: int, a: Vector2, e: Vector2, n: Vector2, h: float, out: float, wall: Color) -> void:
	st.set_custom(0, Color(idx, 3.0, 0.0, 0.0))
	var hi := h + 0.7
	var lo := h - 0.35
	var uv2 := Vector2(0.15, hi + 0.8)
	var a2 := a + n * out
	var e2 := e + n * out
	var up := Vector2(0.0, Vector2(out, hi - lo).length())
	_quad_uv(st, Vector3(a2.x, lo, a2.y), Vector3(e2.x, lo, e2.y), Vector3(e.x, hi, e.y), Vector3(a.x, hi, a.y), _tile(),
		[Vector2.ZERO, Vector2.ZERO, up, up], uv2)
	var none := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	var side := Vector3(e.x - a.x, 0.0, e.y - a.y).normalized()
	b_tri(st, Vector3(a.x, hi, a.y), Vector3(a2.x, lo, a2.y), Vector3(a.x, lo, a.y), -side, wall, none, Vector2(0.0, hi + 0.8))
	b_tri(st, Vector3(e.x, hi, e.y), Vector3(e2.x, lo, e2.y), Vector3(e.x, lo, e.y), side, wall, none, Vector2(0.0, hi + 0.8))
	_raise(idx, hi)
	counts.canopies += 1


## Sân thượng nhà mái bằng: tường lan can thấp quanh mép (thuộc nhà, hạ nhà thì hạ theo), bồn nước nhựa đen; có nhà
## xây tum cầu thang lợp ngói (tumShare), có nhà làm giàn hoa giấy (pergolaShare), kê chậu cây dọc mép (potShare).
## Tum, bồn ở lưới nhà (nhìn xa vẫn thấy), giàn hoa, chậu cây ở lưới chi tiết. f: mặt tiền (tum xây phía sau nhà).
func _roof(st: SurfaceTool, idx: int, poly: PackedVector2Array, h: float, info: Dictionary, f: Dictionary) -> void:
	var area := absf(Geo.area(poly))
	if area < 16.0:
		return
	var c := Geo.centroid(poly)
	var wall: Color = info.get("wall", Color("e8e2d4"))
	st.set_custom(0, Color(idx, 1.0, 0.0, 0.0))
	_parapet(st, poly, h, 0.55, wall.lightened(0.12))
	st.set_custom(0, Color(idx, 3.0, 0.0, 0.0))
	var rect: Dictionary = b._min_rect(poly)
	var u: Vector2 = rect.u
	var used: Array[Vector2] = []
	if area >= 30.0 and float(rect.short) >= 3.2 and _rng.randf() < float(cfg.get("tumShare", 0.3)):
		var w := minf(3.2, float(rect.short) - 1.0)
		var l := minf(3.4, float(rect.long) * 0.45)
		var ends := [(rect.c as Vector2) + u * (float(rect.long) / 2.0 - l / 2.0 - 0.6), (rect.c as Vector2) - u * (float(rect.long) / 2.0 - l / 2.0 - 0.6)]
		var back: Vector2 = ends[_rng.randi() % 2]
		if not f.is_empty():
			var fm := ((f.a as Vector2) + (f.b as Vector2)) / 2.0
			back = ends[0] if (ends[0] as Vector2).distance_to(fm) > (ends[1] as Vector2).distance_to(fm) else ends[1]
		var corners := [back + u * l / 2.0 + u.orthogonal() * w / 2.0, back - u * l / 2.0 + u.orthogonal() * w / 2.0,
			back + u * l / 2.0 - u.orthogonal() * w / 2.0, back - u * l / 2.0 - u.orthogonal() * w / 2.0]
		if corners.all(func(q: Vector2) -> bool: return Geometry2D.is_point_in_polygon(q, poly)):
			_tum(st, idx, back, u, w, l, h, wall)
			used.append(back)
	for i in (2 if area > 60.0 else 1):
		if _rng.randf() > 0.7:
			continue
		var p := _roof_spot(poly, 0.9, used, 1.8)
		if p.x < INF:
			_box(st, Vector3(p.x, h, p.y), u, Vector3(1.1, 0.25, 1.1), Color("a19c92"), Vector2(0.0, h + 1.6))
			_cyl(st, Vector3(p.x, h + 0.25, p.y), 0.5, 0.5, 1.15, Color("2b2d31"), 8, Vector2(0.0, h + 1.6))
			_raise(idx, h + 1.4)
			used.append(p)
	var det: SurfaceTool = b._bst(c, true)
	det.set_custom(0, Color(idx, 3.0, 0.0, 0.0))
	if area >= 25.0 and _rng.randf() < float(cfg.get("pergolaShare", 0.22)):
		var p := _roof_spot(poly, 1.6, used, 2.6)
		if p.x < INF:
			_pergola(det, p, u, 2.0, 2.4, h)
			_raise(idx, h + 2.7)
			used.append(p)
	if _rng.randf() < float(cfg.get("potShare", 0.3)):
		_pots(det, poly, c, h)
	counts.roofs += 1


## Nâng đỉnh của căn idx trong ảnh caps (đồ trên mái cao hơn mái): hạ nhà tính cả món đồ đó.
func _raise(idx: int, top: float) -> void:
	b._cut_tops[idx] = maxf(b._cut_tops[idx], top)


## Điểm ngẫu nhiên trên sân thượng cách mép từ margin mét, cách các chỗ đã dùng từ gap mét; INF nếu không tìm được.
func _roof_spot(poly: PackedVector2Array, margin: float, used: Array[Vector2], gap: float) -> Vector2:
	var r := Geo.bounds(poly)
	for t in 10:
		var p := Vector2(_rng.randf_range(r.position.x, r.end.x), _rng.randf_range(r.position.y, r.end.y))
		if not Geometry2D.is_point_in_polygon(p, poly) or used.any(func(q: Vector2) -> bool: return q.distance_to(p) < gap):
			continue
		var ok := true
		for i in poly.size():
			if Geo.seg_dist(p, poly[i], poly[(i + 1) % poly.size()]) < margin:
				ok = false
				break
		if ok:
			return p
	return Vector2(INF, INF)


## Tường lan can sân thượng cao ph quanh đường viền (một lớp, hai mặt nhờ cull_disabled).
func _parapet(st: SurfaceTool, poly: PackedVector2Array, y: float, ph: float, col: Color) -> void:
	var c := Geo.centroid(poly)
	var none := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		if p.distance_squared_to(q) < 0.01:
			continue
		var nn := Vector3(q.y - p.y, 0.0, -(q.x - p.x)).normalized()
		if Vector2(nn.x, nn.z).dot((p + q) / 2.0 - c) < 0.0:
			nn = -nn
		b_tri(st, Vector3(p.x, y, p.y), Vector3(q.x, y, q.y), Vector3(q.x, y + ph, q.y), nn, col, none, Vector2.ZERO)
		b_tri(st, Vector3(p.x, y, p.y), Vector3(q.x, y + ph, q.y), Vector3(p.x, y + ph, p.y), nn, col, none, Vector2.ZERO)


## Tum cầu thang trên sân thượng (tâm c, dài l theo u, rộng w): khối tường cùng màu nhà có cửa sẫm, mái ngói hai dốc.
func _tum(st: SurfaceTool, idx: int, c: Vector2, u: Vector2, w: float, l: float, y: float, wall: Color) -> void:
	var hgt := 2.6
	var rh := 1.1
	var top := y + hgt + rh
	_box(st, Vector3(c.x, y, c.y), u, Vector3(l, hgt, w), wall, Vector2(0.0, top + 0.8))
	var v := u.orthogonal()
	var door := c + u * (l / 2.0 + 0.01)
	_quad(st, Vector3(door.x - v.x * 0.45, y, door.y - v.y * 0.45), Vector3(door.x + v.x * 0.45, y, door.y + v.y * 0.45),
		Vector3(door.x + v.x * 0.45, y + 2.0, door.y + v.y * 0.45), Vector3(door.x - v.x * 0.45, y + 2.0, door.y - v.y * 0.45), Color("5a4636"), Vector2(0.0, top + 0.8))
	_gable(st, c, u, l / 2.0 + 0.3, w / 2.0 + 0.35, y + hgt, rh, _tile(), wall, top + 0.8)
	_raise(idx, top)
	counts.tums += 1


## Mái ngói hai dốc trên hình chữ nhật tâm c (nóc theo u, dài 2L, rộng 2S) ở độ cao e, cao rh; hai đầu hồi xây tường.
## Mặt mái có UV.y là mét theo dốc để shader vẽ hàng ngói. top: đỉnh để ẩn khi hạ nhà.
func _gable(st: SurfaceTool, c: Vector2, u: Vector2, L: float, S: float, e: float, rh: float, roof: Color, wall: Color, top: float) -> void:
	var v := u.orthogonal()
	var A := Vector3(c.x - u.x * L - v.x * S, e, c.y - u.y * L - v.y * S)
	var B := Vector3(c.x + u.x * L - v.x * S, e, c.y + u.y * L - v.y * S)
	var C := Vector3(c.x + u.x * L + v.x * S, e, c.y + u.y * L + v.y * S)
	var D := Vector3(c.x - u.x * L + v.x * S, e, c.y - u.y * L + v.y * S)
	var R1 := Vector3(c.x - u.x * L, e + rh, c.y - u.y * L)
	var R2 := Vector3(c.x + u.x * L, e + rh, c.y + u.y * L)
	var up := Vector2(0.0, Vector2(S, rh).length())
	for q in [[A, B, R2, R1], [D, C, R2, R1]]:
		_quad_uv(st, q[0], q[1], q[2], q[3], roof, [Vector2.ZERO, Vector2.ZERO, up, up], Vector2(0.15, top))
	var none := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	b_tri(st, A, D, R1, Vector3(-u.x, 0.0, -u.y), wall, none, Vector2(0.0, top))
	b_tri(st, B, C, R2, Vector3(u.x, 0.0, u.y), wall, none, Vector2(0.0, top))


## Màu ngói đỏ cam ngẫu nhiên trong bảng tileRoofs của nhà.
func _tile() -> Color:
	var tiles: Array = b.cfg.get("buildings", {}).get("tileRoofs", ["d9572a"])
	return Color(str(tiles[_rng.randi() % tiles.size()]))


## Giàn hoa giấy trên sân thượng (tâm c, dài l theo u, rộng w, chân ở độ cao y): bốn cột sắt, hai xà, hoa phủ kín mặt
## giàn, vài chùm rủ xuống.
func _pergola(st: SurfaceTool, c: Vector2, u: Vector2, w: float, l: float, y: float) -> void:
	var v := u.orthogonal()
	var top := y + 2.3
	var uv2 := Vector2(0.0, top + 1.2)
	var frame := Color("3a3835")
	for s in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var p: Vector2 = c + u * s.x * l / 2.0 + v * s.y * w / 2.0
		_box(st, Vector3(p.x, y, p.y), u, Vector3(0.08, 2.3, 0.08), frame, uv2)
	for s in [-1.0, 1.0]:
		var p: Vector2 = c + v * s * w / 2.0
		_box(st, Vector3(p.x, top - 0.08, p.y), u, Vector3(l + 0.3, 0.08, 0.08), frame, uv2)
	for i in clampi(roundi(l * w / 1.1), 3, 6):
		var p := c + u * _rng.randf_range(-l / 2.0, l / 2.0) + v * _rng.randf_range(-w / 2.0, w / 2.0)
		var col := Color(_pick("flowers", ["e0338a"])) if _rng.randf() < 0.75 else Color(_pick("leaves", ["4e8a3a"]))
		_bush(st, Vector3(p.x, top + 0.12, p.y), Vector3(_rng.randf_range(0.45, 0.7), 0.3, _rng.randf_range(0.4, 0.6)), col, u, uv2)
	for s in [Vector2(-1, -1), Vector2(1, 1)]:
		var p: Vector2 = c + u * s.x * l / 2.0 + v * s.y * w / 2.0
		_bush(st, Vector3(p.x, top - 0.55, p.y), Vector3(0.25, 0.5, 0.25), Color(_pick("flowers", ["d6246e"])), u, uv2)


## Chậu cây kê dọc mép sân thượng: chậu đất nung, cây xanh hay bông giấy.
func _pots(st: SurfaceTool, poly: PackedVector2Array, c: Vector2, y: float) -> void:
	var uv2 := Vector2(0.0, y + 1.7)
	for i in _rng.randi_range(3, 6):
		var k := _rng.randi() % poly.size()
		var p := poly[k].lerp(poly[(k + 1) % poly.size()], _rng.randf_range(0.15, 0.85))
		p += (c - p).normalized() * 0.45
		if not Geometry2D.is_point_in_polygon(p, poly):
			continue
		_box(st, Vector3(p.x, y, p.y), Vector2.RIGHT, Vector3(0.32, 0.3, 0.32), Color("b5653d"), uv2)
		var col := Color(_pick("leaves", ["4e8a3a"])) if _rng.randf() < 0.6 else Color(_pick("flowers", ["e0338a"]))
		_bush(st, Vector3(p.x, y + 0.5, p.y), Vector3(0.28, 0.3, 0.28), col, Vector2.RIGHT, uv2)


## Bụi lá, chùm hoa: khối tròn đa giác (24 mặt phẳng, hơi méo cho tự nhiên) tâm c, bán kính r = (dọc d, cao, ngang).
func _bush(st: SurfaceTool, c: Vector3, r: Vector3, col: Color, d: Vector2, uv2: Vector2) -> void:
	var u := Vector3(d.x, 0.0, d.y)
	var v := Vector3(-d.y, 0.0, d.x)
	var hi: Array[Vector3] = []
	var lo: Array[Vector3] = []
	for j in 6:
		var th := TAU * (float(j) + _rng.randf_range(-0.2, 0.2)) / 6.0
		var off := (u * cos(th) * r.x + v * sin(th) * r.z) * _rng.randf_range(0.85, 1.15)
		hi.append(c + off * 0.92 + Vector3(0.0, r.y * 0.4, 0.0))
		lo.append(c + off * 0.86 - Vector3(0.0, r.y * 0.35, 0.0))
	var top := c + Vector3(0.0, r.y, 0.0)
	var bot := c - Vector3(0.0, r.y * 0.85, 0.0)
	for j in 6:
		var j2 := (j + 1) % 6
		_face(st, c, top, hi[j], hi[j2], col.lightened(0.1), uv2)
		_face(st, c, hi[j], lo[j], lo[j2], col, uv2)
		_face(st, c, hi[j], lo[j2], hi[j2], col, uv2)
		_face(st, c, bot, lo[j2], lo[j], col.darkened(0.18), uv2)


## Mặt tam giác phẳng của một khối tâm c: pháp tuyến hướng ra ngoài.
static func _face(st: SurfaceTool, c: Vector3, p: Vector3, q: Vector3, r: Vector3, col: Color, uv2: Vector2) -> void:
	var n := (q - p).cross(r - p).normalized()
	if n.dot((p + q + r) / 3.0 - c) < 0.0:
		n = -n
	b_tri(st, p, q, r, n, col, [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO], uv2)


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
	_quad_uv(st, p0, p1, p2, p3, col, [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO], uv2)


## Tấm phẳng bốn đỉnh có UV từng đỉnh (lan can, mái ngói: shader vẽ song sắt, hàng ngói theo UV).
static func _quad_uv(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, col: Color, uvs: Array, uv2: Vector2) -> void:
	var n := (p1 - p0).cross(p3 - p0).normalized()
	if n.y < 0.0:
		n = -n
	b_tri(st, p0, p1, p2, n, col, [uvs[0], uvs[1], uvs[2]], uv2)
	b_tri(st, p0, p2, p3, n, col, [uvs[0], uvs[2], uvs[3]], uv2)


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
func gates() -> void:
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
		var st: SurfaceTool = b._bst(g)
		st.set_custom(0, Color(own, 2.0, 0.0, 0.0))
		var top := Vector2(0.0, 4.7)
		for s in [-1.0, 1.0]:
			var pp: Vector2 = g + side * s * hw
			_slab(st, pp - side * 0.22 - into * 0.22, pp + side * 0.22 - into * 0.22, into, 0.44, 0.0, 4.6, Color("d8d0c0"), top)
		_slab(st, g - side * (hw + 0.4) - into * 0.2, g + side * (hw + 0.4) - into * 0.2, into, 0.4, 4.0, 4.7, Color("2f6fb0"), top)
		var gate_key := "gateTextHanoi" if str(b.region).begins_with("hanoi") and cfg.has("gateTextHanoi") else "gateText"
		var text := "%s\n%s" % [str(cfg.get(gate_key, "KHU PHỐ VĂN HÓA")), str(name_of.call(str(r.name))).to_upper()]
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
		var sw := AreaData.sidewalk(r)
		var off := hw + (sw - 0.4 if sw >= 1.0 else 0.35)
		var poles: Array = []
		_along(r.line, step, func(p: Vector2, d: Vector2) -> void:
			var q: Vector2 = p + d.orthogonal() * off * side
			if not _near(q, radius) or not b.walkable(q) or b.keep_clear.any(func(c: Vector2) -> bool: return c.distance_to(q) < 3.0):
				poles.append(null)
				return
			_pole(q, d)
			counts.poles += 1
			pole_spots.append(q)
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
	_crossings()
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


## Cột điện bê tông ly tâm tròn thon 8 m, xà ngang có ba sứ cách điện; cột có thùng điện, có cuộn dây thừa, vài cột
## có hai bình biến áp trên giá.
func _pole(q: Vector2, d: Vector2) -> void:
	var col := Color("7a776f")
	var n := d.orthogonal()
	_cyl(_st_poles, Vector3(q.x, 0.0, q.y), 0.17, 0.11, 8.0, col)
	_box(_st_poles, Vector3(q.x, 7.15, q.y), n, Vector3(1.7, 0.14, 0.14), col.darkened(0.15))
	for o in [-0.7, 0.0, 0.7]:
		_cyl(_st_poles, Vector3(q.x + n.x * o, 7.29, q.y + n.y * o), 0.05, 0.035, 0.16, Color("e8e4da"), 5)
	if _rng.randf() < 0.45:
		_box(_st_poles, Vector3(q.x + n.x * 0.25, 4.6, q.y + n.y * 0.25), d, Vector3(0.55, 0.8, 0.35), Color("6e7378"))
	if wires and _rng.randf() < 0.5:
		# Cuộn dây thừa quấn quanh cột.
		_box(_st_wires, Vector3(q.x, 5.4, q.y), d, Vector3(0.5, 0.35, 0.5), Color("232325"))
	if counts.poles % 6 == 3:
		# Bình biến áp: giá đỡ, hai bình xám tròn.
		_box(_st_poles, Vector3(q.x - n.x * 0.35, 5.6, q.y - n.y * 0.35), n, Vector3(1.0, 0.08, 0.5), col.darkened(0.2))
		for o in [-0.62, -0.1]:
			_cyl(_st_poles, Vector3(q.x + n.x * o, 5.68, q.y + n.y * o), 0.21, 0.21, 0.62, Color("8d949a"), 8)


## Trụ tròn côn đứng tại chân p: cao h, bán kính r0 ở chân, r1 ở ngọn, segs mặt, nắp trên. uv2: như b_tri (đồ gắn kèm
## nhà thì UV2.y là đỉnh để ẩn khi hạ nhà).
static func _cyl(st: SurfaceTool, p: Vector3, r0: float, r1: float, h: float, col: Color, segs := 7, uv2 := Vector2.ZERO) -> void:
	var none := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	var top := p + Vector3(0, h, 0)
	for j in segs:
		var d0 := Vector3(cos(TAU * j / segs), 0, sin(TAU * j / segs))
		var d1 := Vector3(cos(TAU * (j + 1) / segs), 0, sin(TAU * (j + 1) / segs))
		var nn := (d0 + d1).normalized()
		b_tri(st, p + d0 * r0, p + d1 * r0, top + d1 * r1, nn, col, none, uv2)
		b_tri(st, p + d0 * r0, top + d1 * r1, top + d0 * r1, nn, col, none, uv2)
		b_tri(st, top, top + d0 * r1, top + d1 * r1, Vector3.UP, col.lightened(0.06), none, uv2)


## Hộp đứng tại chân p (giữa đáy), trục dài theo d (mặt đất), kích thước s = (dọc d, cao, ngang).
static func _box(st: SurfaceTool, p: Vector3, d: Vector2, s: Vector3, col: Color, uv2 := Vector2.ZERO) -> void:
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
		b_tri(st, a, e, e + y, nn.normalized(), col, none, uv2)
		b_tri(st, a, e + y, a + y, nn.normalized(), col, none, uv2)
	b_tri(st, c[0] + y, c[1] + y, c[2] + y, Vector3.UP, col.lightened(0.06), none, uv2)
	b_tri(st, c[0] + y, c[2] + y, c[3] + y, Vector3.UP, col.lightened(0.06), none, uv2)


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


## Ngã ba, ngã tư đường lớn (từ 7 m): vạch qua đường kẻ sọc trắng trên mỗi nhánh có đầu chạm đường lớn khác, đèn giao
## thông ở góc (cột, cần vươn ra lòng đường, hộp đèn ba màu quay về phía xe tới). Vạch sơn là lưới riêng dùng vật liệu
## mặt đất, đặt cao hơn mọi mặt đường một chút.
func _crossings() -> void:
	var big: Array = b.data.roads.filter(func(r) -> bool:
		return not r.bridge and not r.tunnel and not r.small and float(r.width) >= 7.0 and r.line.size() >= 2)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var lights: Array[Vector2] = []
	var any := false
	for r in big:
		for end in [0, r.line.size() - 1]:
			var p: Vector2 = r.line[end]
			if not _near(p, radius):
				continue
			var host := {}
			for o in big:
				if is_same(o, r):
					continue
				for i in o.line.size() - 1:
					if Geo.seg_dist(p, o.line[i], o.line[i + 1]) < 2.0:
						host = o
						break
				if not host.is_empty():
					break
			if host.is_empty():
				continue
			var nxt: Vector2 = r.line[1] if end == 0 else r.line[r.line.size() - 2]
			var into := (nxt - p).normalized()
			var side := into.orthogonal()
			var w := float(r.width)
			var q := p + into * (float(host.width) / 2.0 + 2.4)
			var o := -w / 2.0 + 0.5
			while o + 0.45 <= w / 2.0 - 0.4:
				var c := q + side * (o + 0.225)
				_ground_quad(st, c - into * 1.4 - side * 0.225, c + into * 1.4 - side * 0.225, c + into * 1.4 + side * 0.225, c - into * 1.4 + side * 0.225, Color("f1eee6"))
				o += 0.9
			any = true
			counts.crossings += 1
			var pole := q + into * 2.2 + side * (w / 2.0 + 0.8)
			if b.walkable(pole) and not lights.any(func(x: Vector2) -> bool: return x.distance_to(pole) < 8.0):
				_signal(pole, into, side, w)
				lights.append(pole)
	if any:
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = b.ground_material if b.ground_material != null else b.ground_shader_material()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.add_child(mi)


## Tấm sơn nằm trên mặt đường (màu trơn trong vật liệu mặt đất), cao hơn mọi lớp đường.
static func _ground_quad(st: SurfaceTool, p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, col: Color) -> void:
	col.a = 0.0
	var none := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	b_tri(st, Vector3(p0.x, 0.105, p0.y), Vector3(p1.x, 0.105, p1.y), Vector3(p2.x, 0.105, p2.y), Vector3.UP, col, none, Vector2.ZERO)
	b_tri(st, Vector3(p0.x, 0.105, p0.y), Vector3(p2.x, 0.105, p2.y), Vector3(p3.x, 0.105, p3.y), Vector3.UP, col, none, Vector2.ZERO)


## Đèn giao thông ở góc ngã tư (q trên vỉa hè bên phải nhánh đường rộng w, into: hướng từ ngã tư đi ra nhánh, side: phía
## vỉa hè): cột sắt, cần vươn ngang ra giữa nhánh, hộp đèn đỏ vàng xanh quay về phía xe đang chạy tới ngã tư.
func _signal(q: Vector2, into: Vector2, side: Vector2, w: float) -> void:
	var col := Color("3d4146")
	_cyl(_st_poles, Vector3(q.x, 0.0, q.y), 0.11, 0.09, 5.4, col, 7)
	var reach := minf(w * 0.55, 4.5)
	var arm := q - side * reach / 2.0
	_box(_st_poles, Vector3(arm.x, 5.1, arm.y), side, Vector3(reach, 0.12, 0.12), col)
	var head := q - side * (reach - 0.3)
	_box(_st_poles, Vector3(head.x, 4.1, head.y), side, Vector3(0.38, 1.0, 0.3), Color("2a2c30"))
	_box(_st_poles, Vector3(head.x, 5.1 - 0.05, head.y), side, Vector3(0.06, 0.1, 0.06), col)
	var face := head + into * 0.16
	var lit := _rng.randi() % 3
	for k in 3:
		var lamp: Color = [Color("ff3b2f"), Color("ffb020"), Color("35d46a")][k]
		_box(_st_poles, Vector3(face.x, 4.78 - k * 0.3, face.y), side, Vector3(0.2, 0.2, 0.04), lamp if k == lit else lamp.darkened(0.6))
	# Đèn cho người đi bộ, thấp trên thân cột.
	_box(_st_poles, Vector3(q.x + into.x * 0.15, 2.4, q.y + into.y * 0.15), side, Vector3(0.28, 0.4, 0.2), Color("2a2c30"))
	counts.lights += 1


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
		var l := _label(str(bd.text), bd.pos, bd.n, float(bd.w), float(bd.h), bd.board)
		b._cut_label(int(bd.idx), l, float(bd.top))
		sign_labels.append({"label": l, "day": l.modulate})
	for bd in _boards:
		lantern_spots.append({"pos": Vector3(bd.pos.x, float(bd.pos.y) - float(bd.h) / 2.0 - 0.15, bd.pos.z), "n": bd.n, "w": float(bd.w)})
	var items := []
	for s in _stools:
		var p: Vector2 = s[0]
		var d: Vector2 = s[1]
		if not b.walkable(p):
			continue
		var col := Color(["2f6fb0", "c0392b", "2f6fb0", "e8e4da"][_rng.randi() % 4])
		items.append([p, d, "table", Color("c0392b") if col == Color("2f6fb0") else Color("2f6fb0")])
		for k in _rng.randi_range(2, 4):
			var a := TAU * k / 4.0 + _rng.randf_range(-0.3, 0.3)
			var q := p + Vector2(cos(a), sin(a)) * 0.55
			items.append([q, d, "tall" if k % 2 == 0 else "low", col])
			seats.append([q, (p - q).normalized(), 0.42 if k % 2 == 0 else 0.27])
	# Ghế đẩu thấp, ghế cao, bàn (props3d.gd): mỗi loại một MultiMesh, màu từng cái là màu instance.
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.55
	for kind in ["low", "tall", "table"]:
		var mine := items.filter(func(it: Array) -> bool: return it[2] == kind)
		if mine.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = Props3D.stool(kind)
		mm.instance_count = mine.size()
		for i in mine.size():
			var it: Array = mine[i]
			var p: Vector2 = it[0]
			var yaw := atan2((it[1] as Vector2).x, (it[1] as Vector2).y) + 0.4 * float(i % 3)
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, 0.0, p.y)))
			mm.set_instance_color(i, it[3])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = m
		b.add_child(mmi)
