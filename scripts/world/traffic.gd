extends Node3D
## Dòng xe trên đường thật quanh chỗ của truyện (map thật): xe máy có người lái (có xe chở thêm người ngồi sau), ô tô
## chạy hai chiều, ai đi làn nấy bên phải. Đường cùng tên nối liền nhau gộp thành tuyến; các tuyến có tâm cùng ô CLUSTER
## mét gom chung, mỗi cụm mỗi loại xe một MultiMesh có khung bao cố định (ít lần vẽ, ra ngoài khung nhìn thì khỏi vẽ).
## Cụm xa An quá UPDATE_RANGE mét thì xe vẫn chạy nhưng khỏi cập nhật hình. Tới cuối tuyến xe thu nhỏ dần rồi vòng lại
## đầu tuyến.

const Props3D := preload("res://scripts/world/props3d.gd")
const Geo := preload("res://scripts/realmap/geo.gd")

## Xe máy mỗi mét đường (cả hai chiều), ô tô mỗi mét đường từ 8 m; tối đa cả khu. Tuyến càng xa chỗ của truyện càng
## thưa xe (xem _near_k).
const BIKES_PER_M := 0.16
const CARS_PER_M := 0.018
const MAX_BIKES := 480
const MAX_CARS := 44
const CLUSTER := 220.0
const UPDATE_RANGE := 240.0
## Đường rộng từ chừng này mét mới có ô tô đậu dọc lề (AreaBuilder.park_cars_from): xe máy chạy chừa chỗ.
const PARKED_CARS_FROM := 12.0
## Tới gần đầu, cuối tuyến chừng này mét thì xe thu nhỏ dần (vòng lại đầu tuyến cho đỡ giật).
const FADE := 3.0
## Ba kiểu xe máy chạy: tay ga một người, xe số một người, tay ga chở thêm người ngồi sau (tỉ lệ).
const KINDS := [["tay_ga", false, 0.5], ["xe_so", false, 0.3], ["tay_ga", true, 0.2]]
const BIKE_PAINT := ["b23a32", "2b2d33", "e8e6e1", "3a6ea5", "c9ccd1", "7a2a3a", "e0b23c", "2f6f4f"]
const CAR_PAINT := ["e8e6e1", "2b2d33", "b23a32", "3a6ea5", "c9ccd1", "e0b23c", "5a7d4f"]

## Tuyến: {line, cum (quãng đường tới từng đỉnh), len, width, y, rect}.
var routes: Array = []
## Mỗi nhóm: một cụm, một loại xe: {mm, rect, rid (tuyến của từng xe), s, dir, off, speed, seg}.
var groups: Array = []
var counts := {"routes": 0, "groups": 0, "bikes": 0, "cars": 0}
## Phần xe còn chạy (ngày mưa vắng bớt): xe nào có hash theo số thứ tự nhỏ hơn density thì hiện.
var density := 1.0
var _rng := RandomNumberGenerator.new()


## roads: đường của khu (area_data); chỉ lấy đường lớn (từ 6 m) có đoạn nằm trong vòng radius mét quanh center.
## bridge_y: mặt cầu cao hơn mặt đường chừng này.
func build(roads: Array, center: Vector2, radius: float, bridge_y: float) -> void:
	_rng.seed = 2024
	var picked := roads.filter(func(r) -> bool:
		return not r.small and not r.tunnel and float(r.width) >= 6.0 and r.line.size() >= 2 \
			and str(r.kind) not in ["footway", "path", "steps", "cycleway", "pedestrian"] \
			and Array(r.line).any(func(p: Vector2) -> bool: return p.distance_to(center) < radius))
	routes = _chains(picked).filter(func(r: Dictionary) -> bool: return float(r.len) >= 25.0)
	var total := 0.0
	var car_total := 0.0
	for r in routes:
		r["y"] = bridge_y if r.bridge else 0.0
		r["k"] = _near_k(r.line, center)
		total += float(r.len) * float(r.k)
		if float(r.width) >= 8.0:
			car_total += float(r.len) * float(r.k)
	var k_bike := minf(BIKES_PER_M, float(MAX_BIKES) / maxf(total, 1.0))
	var k_car := minf(CARS_PER_M, float(MAX_CARS) / maxf(car_total, 1.0))
	# Cụm (ô theo tâm tuyến) → loại xe → các xe [tuyến, vị trí, chiều, lệch làn, tốc độ, màu].
	var clusters := {}
	for ri in routes.size():
		var r: Dictionary = routes[ri]
		var w := float(r.width)
		var c := (r.rect as Rect2).get_center()
		var key := Vector2i(floori(c.x / CLUSTER), floori(c.y / CLUSTER))
		if not clusters.has(key):
			clusters[key] = {"rect": r.rect, "kinds": {}}
		clusters[key]["rect"] = (clusters[key].rect as Rect2).merge(r.rect)
		var kinds: Dictionary = clusters[key].kinds
		# Làn bên phải mỗi chiều: ô tô giữa làn trong, xe máy phía ngoài, chừa chỗ xe đậu sát lề.
		var cars := w >= 8.0
		var edge := w / 2.0 - (2.5 if w >= PARKED_CARS_FROM else 1.2)
		var bike_lane := Vector2(2.4, edge) if cars else Vector2(0.55, edge)
		var n := roundi(float(r.len) * float(r.k) * k_bike)
		for kind in KINDS:
			var m := roundi(n * float(kind[2]))
			_add(kinds, "%s|%s" % [kind[0], kind[1]], ri, m, bike_lane, Vector2(6.5, 9.5), BIKE_PAINT)
			counts.bikes += m
		if cars:
			var m := roundi(float(r.len) * float(r.k) * k_car)
			_add(kinds, "car", ri, m, Vector2(1.4, 1.4), Vector2(5.5, 7.5), CAR_PAINT)
			counts.cars += m
	counts.routes = routes.size()
	for key in clusters:
		for kk in clusters[key].kinds:
			var list: Array = clusters[key].kinds[kk]
			if list.is_empty():
				continue
			var parts := str(kk).split("|")
			_group(Props3D.car() if kk == "car" else Props3D.rider_bike(parts[0], parts[1] == "true"), list, clusters[key].rect, kk == "car")


## Độ đông xe của tuyến: đủ trong vòng 65 m quanh chỗ của truyện, xa dần thưa dần, xa hẳn còn một phần ba.
static func _near_k(line: PackedVector2Array, center: Vector2) -> float:
	var d := INF
	for i in line.size() - 1:
		d = minf(d, Geo.seg_dist(center, line[i], line[i + 1]))
	return clampf(1.25 - d / 260.0, 0.33, 1.0)


## Thêm m xe vào danh sách loại xe kk: rải đều dọc tuyến ri, chiều chạy xen kẽ, lệch sang phải trong khoảng lane (mét
## tính từ tim đường), tốc độ trong khoảng speed (m/giây), màu sơn trong bảng paint, sắc áo ngẫu nhiên (kênh a).
func _add(kinds: Dictionary, kk: String, ri: int, m: int, lane: Vector2, speed: Vector2, paint: Array) -> void:
	if not kinds.has(kk):
		kinds[kk] = []
	var total := float(routes[ri].len)
	for i in m:
		var c := Color(str(paint[_rng.randi() % paint.size()]))
		c.a = _rng.randf()
		kinds[kk].append([ri, (float(i) + _rng.randf_range(0.0, 0.8)) / float(m) * total, 1.0 if i % 2 == 0 else -1.0,
			_rng.randf_range(lane.x, maxf(lane.x, lane.y)), _rng.randf_range(speed.x, speed.y), c])


## Một nhóm (cụm, loại xe): MultiMesh khung bao cố định quanh các tuyến trong cụm. shadows: đổ bóng thật (ô tô); xe máy
## đông nên dùng bóng giả có sẵn trong lưới.
func _group(mesh: Mesh, list: Array, rect: Rect2, shadows: bool) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	# Màu sơn ở custom data (sắc áo ở kênh a); màu instance trắng (bản Compatibility nhân màu đỉnh với màu instance).
	mm.use_custom_data = true
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = list.size()
	mm.custom_aabb = AABB(Vector3(rect.position.x - 6.0, -0.5, rect.position.y - 6.0), Vector3(rect.size.x + 12.0, 4.0, rect.size.y + 12.0))
	var g := {"mm": mm, "rect": rect, "rid": PackedInt32Array(), "s": PackedFloat32Array(), "dir": PackedFloat32Array(),
		"off": PackedFloat32Array(), "speed": PackedFloat32Array(), "seg": PackedInt32Array()}
	var rid := PackedInt32Array()
	var s := PackedFloat32Array()
	var dir := PackedFloat32Array()
	var off := PackedFloat32Array()
	var spd := PackedFloat32Array()
	for i in list.size():
		var it: Array = list[i]
		rid.append(int(it[0]))
		s.append(float(it[1]))
		dir.append(float(it[2]))
		off.append(float(it[3]))
		spd.append(float(it[4]))
		mm.set_instance_custom_data(i, it[5])
		mm.set_instance_color(i, Color.WHITE)
	var seg := PackedInt32Array()
	seg.resize(list.size())
	g["rid"] = rid
	g["s"] = s
	g["dir"] = dir
	g["off"] = off
	g["speed"] = spd
	g["seg"] = seg
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = Props3D.instanced_material()
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	groups.append(g)
	counts.groups += 1
	_place(g, 0.0)


## Gộp các đoạn đường cùng tên nối đuôi nhau (đầu đoạn này chạm cuối đoạn kia, đi tiếp gần thẳng) thành tuyến.
static func _chains(roads: Array) -> Array:
	var used := {}
	var out := []
	for i in roads.size():
		if used.has(i):
			continue
		used[i] = true
		var r = roads[i]
		var line := PackedVector2Array(r.line)
		for front in [false, true]:
			var grow := str(r.name) != ""
			while grow:
				grow = false
				var tip: Vector2 = line[0] if front else line[line.size() - 1]
				var prev: Vector2 = line[1] if front else line[line.size() - 2]
				var heading := (tip - prev).normalized()
				for j in roads.size():
					var o = roads[j]
					if used.has(j) or str(o.name) != str(r.name) or o.bridge != r.bridge:
						continue
					var seg := PackedVector2Array(o.line)
					if seg[seg.size() - 1].distance_to(tip) < 1.5:
						seg.reverse()
					elif seg[0].distance_to(tip) >= 1.5:
						continue
					if seg.size() < 2 or (seg[1] - seg[0]).normalized().dot(heading) < 0.7:
						continue
					used[j] = true
					if front:
						seg.reverse()
						line = seg.slice(0, seg.size() - 1) + line
					else:
						line.append_array(seg.slice(1))
					grow = true
					break
		var cum := PackedFloat32Array([0.0])
		for k in line.size() - 1:
			cum.append(cum[k] + line[k].distance_to(line[k + 1]))
		out.append({"line": line, "cum": cum, "len": cum[cum.size() - 1], "width": float(r.width), "bridge": bool(r.bridge), "rect": Geo.bounds(line)})
	return out


## Chỗ một chiếc xe đang chạy gần focus (trong vòng r mét) để phát tiếng còi; null nếu không có.
func near_vehicle(focus: Vector2, r := 60.0):
	var near := groups.filter(func(g: Dictionary) -> bool: return (g.rect as Rect2).grow(r).has_point(focus))
	if near.is_empty():
		return null
	var g: Dictionary = near[_rng.randi() % near.size()]
	var mm: MultiMesh = g.mm
	var best = null
	for t in 6:
		var p := mm.get_instance_transform(_rng.randi() % mm.instance_count).origin
		if best == null or Vector2(p.x, p.z).distance_to(focus) < Vector2(best.x, best.z).distance_to(focus):
			best = p
	return best


## Mỗi khung hình: xe chạy tiếp dọc tuyến; cụm gần chỗ focus (An) thì cập nhật hình.
func update(delta: float, focus: Vector2) -> void:
	for g in groups:
		_place(g, delta, (g.rect as Rect2).grow(UPDATE_RANGE).has_point(focus))


func _place(g: Dictionary, delta: float, near := true) -> void:
	var mm: MultiMesh = g.mm
	var rid: PackedInt32Array = g.rid
	var s: PackedFloat32Array = g.s
	var seg: PackedInt32Array = g.seg
	var dir: PackedFloat32Array = g.dir
	var off: PackedFloat32Array = g.off
	var speed: PackedFloat32Array = g.speed
	for i in s.size():
		var r: Dictionary = routes[rid[i]]
		var cum: PackedFloat32Array = r.cum
		var total: float = r.len
		var last := cum.size() - 2
		var v := s[i] + dir[i] * speed[i] * delta
		if v >= total:
			v -= total
			seg[i] = 0
		elif v < 0.0:
			v += total
			seg[i] = last
		s[i] = v
		if not near:
			continue
		var line: PackedVector2Array = r.line
		var k := seg[i]
		while k < last and v > cum[k + 1]:
			k += 1
		while k > 0 and v < cum[k]:
			k -= 1
		seg[i] = k
		var a := line[k]
		var b := line[k + 1]
		var l := maxf(cum[k + 1] - cum[k], 0.001)
		var d := (b - a) / l
		# Qua khúc quanh: hướng xe chuyển dần từ đoạn trước sang đoạn này trong 2 m đầu đoạn.
		var into := v - cum[k]
		if k > 0 and into < 2.0:
			d = (line[k] - line[k - 1]).normalized().lerp(d, 0.5 + into / 4.0).normalized()
		elif k < last and l - into < 2.0:
			d = d.lerp((line[k + 2] - line[k + 1]).normalized(), 0.5 - (l - into) / 4.0).normalized()
		d *= dir[i]
		# Bên phải chiều chạy: orthogonal() là bên trái.
		var p := a.lerp(b, into / l) - d.orthogonal() * off[i]
		var sc := clampf(minf(v, total - v) / FADE, 0.02, 1.0)
		if density < 1.0 and fmod(float(i) * 0.618034, 1.0) >= density:
			sc = 0.001
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, atan2(d.x, d.y)).scaled(Vector3.ONE * sc), Vector3(p.x, float(r.y), p.y)))
	g["s"] = s
	g["seg"] = seg
