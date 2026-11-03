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
const CLUSTER := 100.0
const UPDATE_RANGE := 240.0
## Detail is limited to the walking camera's neighbourhood; silhouettes farther
## down the street remain the original cheap, baked batches.
const DETAIL_ENTER := 20.0
const DETAIL_EXIT := 24.0
## Đường rộng từ chừng này mét mới có ô tô đậu dọc lề (AreaBuilder.park_cars_from): xe máy chạy chừa chỗ.
const PARKED_CARS_FROM := 12.0
## Tới gần đầu, cuối tuyến chừng này mét thì xe thu nhỏ dần (vòng lại đầu tuyến cho đỡ giật).
const FADE := 3.0
## Ba kiểu xe máy chạy: tay ga một người, xe số một người, tay ga chở thêm người ngồi sau (tỉ lệ).
const KINDS := [["tay_ga", false, 0.5], ["xe_so", false, 0.3], ["tay_ga", true, 0.2]]
const BIKE_PAINT := ["783c36", "303337", "c5c3b9", "40596a", "9b9fa1", "593039", "8b7958", "455b50"]
## Người lái xe máy (người thật nướng sẵn, xem props3d.gd rider_real), màu mũ bảo hiểm.
const RIDERS := ["m1", "m2", "m3", "m4", "m5", "f1", "f2", "f3", "f4"]
const HELMETS := ["713d37", "c8c6ba", "3f5564", "282a2b", "9b8c65", "71605c", "64705d"]
const CAR_PAINT := ["c7c7bf", "303336", "713b37", "4c6171", "a2a7a8", "8e8067", "5c685c"]

## Tuyến: {line, cum (quãng đường tới từng đỉnh), len, width, y, rect}.
var routes: Array = []
## Mỗi nhóm: một cụm, một loại xe: {mm, rect, rid (tuyến của từng xe), s, dir, off, speed, seg}.
var groups: Array = []
var counts := {"routes": 0, "groups": 0, "bikes": 0, "cars": 0}
## Phần xe còn chạy (ngày mưa vắng bớt): xe nào có hash theo số thứ tự nhỏ hơn density thì hiện.
var density := 1.0
var _rng := RandomNumberGenerator.new()
var _focus := Vector2.ZERO


## roads: đường của khu (area_data); chỉ lấy đường lớn (từ 6 m) có đoạn nằm trong vòng radius mét quanh center.
## bridge_y: mặt cầu cao hơn mặt đường chừng này. amount: nhân số xe (điện thoại bớt xe).
func build(roads: Array, center: Vector2, radius: float, bridge_y: float, amount := 1.0) -> void:
	# build may run again when changing areas. Dispose the previous owned batches
	# before replacing route indices so stale vehicles cannot remain on screen.
	for g in groups:
		(g.node as MultiMeshInstance3D).free()
		if g.detail_node != null:
			(g.detail_node as MultiMeshInstance3D).free()
	groups.clear()
	counts = {"routes": 0, "groups": 0, "bikes": 0, "cars": 0}
	_focus = center
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
	var k_bike := minf(BIKES_PER_M, float(MAX_BIKES) / maxf(total, 1.0)) * amount
	var k_car := minf(CARS_PER_M, float(MAX_CARS) / maxf(car_total, 1.0)) * amount
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
			if kk == "car":
				_group(Props3D.car(false), list, clusters[key].rect, true, true, Props3D.car(true))
				continue
			# Người lái chọn theo cụm và loại xe: mỗi cụm một vẻ (cụm nhỏ nên đi một đoạn đã thấy người khác).
			var h := absi(hash(key)) + (1 if parts[0] == "xe_so" else 0) + (4 if parts[1] == "true" else 0)
			var back: String = RIDERS[(h + 2) % RIDERS.size()] if parts[1] == "true" else ""
			var real := Props3D.rider_real(parts[0], RIDERS[h % RIDERS.size()], back, Color(HELMETS[h % HELMETS.size()]))
			if real != null:
				_group(real, list, clusters[key].rect, false, false,
					Props3D.rider_real(parts[0], RIDERS[h % RIDERS.size()], back, Color(HELMETS[h % HELMETS.size()]), true))
			else:
				_group(Props3D.rider_bike(parts[0], parts[1] == "true"), list, clusters[key].rect, false)


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
func _group(mesh: Mesh, list: Array, rect: Rect2, shadows: bool, override := true, detail_mesh: Mesh = null) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	# Màu sơn ở custom data (sắc áo ở kênh a); màu instance trắng (bản Compatibility nhân màu đỉnh với màu instance).
	mm.use_custom_data = true
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = list.size()
	mm.custom_aabb = AABB(Vector3(rect.position.x - 6.0, -0.5, rect.position.y - 6.0), Vector3(rect.size.x + 12.0, 4.0, rect.size.y + 12.0))
	var g := {"mm": mm, "rect": rect, "rid": PackedInt32Array(), "s": PackedFloat32Array(), "dir": PackedFloat32Array(),
		"off": PackedFloat32Array(), "speed": PackedFloat32Array(), "seg": PackedInt32Array(),
		"node": null, "detail_mm": null, "detail_node": null, "detail_on": PackedByteArray(), "detail_count": 0,
		"detail_slot": PackedInt32Array(), "paints": PackedColorArray(), "poses": [],
		"wheel_phase": PackedFloat32Array(), "wheel_radius": Props3D.wheel_radius(detail_mesh) if detail_mesh != null else 0.27}
	var rid := PackedInt32Array()
	var s := PackedFloat32Array()
	var dir := PackedFloat32Array()
	var off := PackedFloat32Array()
	var spd := PackedFloat32Array()
	var paints := PackedColorArray()
	var wheel_phase := PackedFloat32Array()
	var poses: Array[Transform3D] = []
	for i in list.size():
		var it: Array = list[i]
		rid.append(int(it[0]))
		s.append(float(it[1]))
		dir.append(float(it[2]))
		off.append(float(it[3]))
		spd.append(float(it[4]))
		paints.append(it[5])
		wheel_phase.append(float(it[5].a))
		poses.append(Transform3D.IDENTITY)
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
	g.paints = paints
	g.wheel_phase = wheel_phase
	g.poses = poses
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	if override:
		mi.material_override = Props3D.instanced_material()
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	g.node = mi
	var detail_on := PackedByteArray()
	detail_on.resize(list.size())
	g.detail_on = detail_on
	var detail_slot := PackedInt32Array()
	detail_slot.resize(list.size())
	detail_slot.fill(-1)
	g.detail_slot = detail_slot
	if detail_mesh != null:
		var detail_mm := MultiMesh.new()
		detail_mm.transform_format = MultiMesh.TRANSFORM_3D
		detail_mm.use_custom_data = true
		detail_mm.use_colors = true
		# The geometry cache is also used by parked/staging instances. Only this
		# traffic copy changes its first material; rider and helmet surfaces stay intact.
		var moving_mesh := detail_mesh.duplicate() as ArrayMesh
		moving_mesh.surface_set_material(0, Props3D.moving_instanced_material())
		detail_mm.mesh = moving_mesh
		detail_mm.instance_count = list.size()
		detail_mm.visible_instance_count = 0
		detail_mm.custom_aabb = mm.custom_aabb
		for i in list.size():
			detail_mm.set_instance_color(i, Color.WHITE)
		var detail_node := MultiMeshInstance3D.new()
		detail_node.name = "TrafficNear"
		detail_node.multimesh = detail_mm
		# Close vehicles cast a proper contact shadow. Their own materials preserve
		# rubber, paint, chrome and the photographed rider instead of one override.
		detail_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		add_child(detail_node)
		g.detail_mm = detail_mm
		g.detail_node = detail_node
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
	_focus = focus
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
	var detail_mm: MultiMesh = g.detail_mm
	var detail_on: PackedByteArray = g.detail_on
	var detail_slot: PackedInt32Array = g.detail_slot
	var paints: PackedColorArray = g.paints
	var wheel_phase: PackedFloat32Array = g.wheel_phase
	var poses: Array[Transform3D] = g.poses
	var detail_count := 0
	for i in s.size():
		var r: Dictionary = routes[rid[i]]
		var cum: PackedFloat32Array = r.cum
		var total: float = r.len
		var last := cum.size() - 2
		var travel := s[i] + dir[i] * speed[i] * delta
		# Both directions drive forwards in their own +Z coordinate frame. Keep
		# phase independent from route wrapping and update it even outside view.
		wheel_phase[i] = fposmod(wheel_phase[i] + speed[i] * delta / (TAU * float(g.wheel_radius)), 1.0)
		var v := fposmod(travel, total)
		if travel >= total:
			seg[i] = 0
		elif travel < 0.0:
			seg[i] = last
		s[i] = v
		if not near:
			if detail_mm != null and detail_on[i] == 1:
				# Preserve the last coarse pose when teleporting away; hiding the
				# detailed batch must not leave its coarse instance scaled to zero.
				mm.set_instance_transform(i, poses[i])
				detail_on[i] = 0
			detail_slot[i] = -1
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
		var pose := Transform3D(Basis(Vector3.UP, atan2(d.x, d.y)).scaled(Vector3.ONE * sc), Vector3(p.x, float(r.y), p.y))
		poses[i] = pose
		var hidden_pose := Transform3D(Basis.from_scale(Vector3.ONE * 0.00001), pose.origin)
		if detail_mm != null:
			var radius := DETAIL_EXIT if detail_on[i] == 1 else DETAIL_ENTER
			var close := sc > 0.01 and p.distance_squared_to(_focus) < radius * radius
			detail_on[i] = 1 if close else 0
			detail_slot[i] = detail_count if close else -1
			if close:
				# Compact into a contiguous draw prefix. Zero-scaling distant
				# high-poly instances still submits all their vertices to the GPU.
				detail_mm.set_instance_transform(detail_count, pose)
				var moving_paint := paints[i]
				moving_paint.a = wheel_phase[i]
				detail_mm.set_instance_custom_data(detail_count, moving_paint)
				detail_count += 1
			mm.set_instance_transform(i, hidden_pose if close else pose)
		else:
			mm.set_instance_transform(i, pose)
	g["s"] = s
	g["seg"] = seg
	g.poses = poses
	g.wheel_phase = wheel_phase
	if detail_mm != null:
		# When a cluster is not updated it must not leave frozen near-detail cars.
		(g.detail_node as MultiMeshInstance3D).visible = near and detail_count > 0
		detail_mm.visible_instance_count = detail_count
		g.detail_on = detail_on
		g.detail_slot = detail_slot
		g.detail_count = detail_count
