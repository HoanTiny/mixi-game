extends RefCounted
## Map của truyện dựng từ một khu thật đã nướng sẵn (data/maps/<id>.json, xem tools/bake_map.gd) cộng file đặt truyện
## (data/maps/<id>_story.json). Cùng các hàm màn phố cần như city_map.gd: chỗ của từng địa điểm (lô có mặt tiền, hướng
## cửa), đi được không, tìm đường, quãng đường; thêm nhà có số để giao hàng, chỗ đặt thùng rác, chỗ ngập ngày mưa,
## tuyến người bán rong. Tên đường thật đổi sang tên trong truyện; nhãn địa danh thật không hiện.

const Geo := preload("res://scripts/realmap/geo.gd")
const AreaData := preload("res://scripts/realmap/area_data.gd")
const WalkGrid := preload("res://scripts/realmap/walk_grid.gd")
const CityMap := preload("res://scripts/world/city_map.gd")
const AreaBuilder := preload("res://scripts/realmap/area_builder.gd")

const is_real := true

var id := ""
var display := ""
var data
var clip := PackedVector2Array()
var bounds := Rect2()
var grid
var story: Dictionary = {}
var sources := ""
## id địa điểm -> {center, normal, w, d, street, loc}: như lô của city_map, mặt tiền nhìn ra đường thật.
var locs := {}
## Giữ cho các chỗ còn đọc kiểu map cũ (không dùng với map thật).
var plots: Array = []
var streets := {}
var order: Array = []
var fillers: Array = []
## Nhà có số để giao hàng: {pos: Vector2 (trên mép đường trước cửa), no, address}.
var homes: Array = []
## Chỗ đặt thùng rác (mép đường).
var bins: Array = []
## Đoạn đường ngập ngày mưa theo mức: {1: [{a, b, w}], 2: [...]}. Mức 1 sát kênh, mức 2 lan vào trong.
var floods := {1: [], 2: []}
var vendor_routes := {}
var quest_areas := {}
var _names := {}
## Lưới ô 30 m chứa các đoạn đường (tìm đường gần nhất cho nhanh) và lưới 5 m khoảng cách tới mặt nước.
const SEG_CELL := 30.0
var _seg_grid := {}
const WATER_CELL := 5.0
var _water_dist := {}


func _init(map_id: String) -> void:
	id = map_id
	var m = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s.json" % map_id))
	var st = JSON.parse_string(FileAccess.get_file_as_string("res://data/maps/%s_story.json" % map_id))
	story = st if st is Dictionary else {}
	var cfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/realmap.json"))
	data = AreaData.new(Geo.new(float(m.center[0]), float(m.center[1])), cfg)
	data.from_dict(m.data)
	# Nhà ảnh vệ tinh phủ qua hẻm: bỏ trước khi dựng lưới đi bộ, đặt địa điểm (khỏi đi xuyên nhà).
	data.drop_buildings_over_lanes()
	clip = AreaData._pts(m.clip)
	bounds = Geo.bounds(clip)
	sources = str(m.get("sources", ""))
	display = str(story.get("displayName", m.get("name", map_id)))
	_names = story.get("names", {})
	# Nhãn địa danh thật không hiện trong truyện.
	data.pois.clear()
	_index_roads()
	_place_locations()
	grid = WalkGrid.new(data, bounds)
	_block_locations()
	_place_homes()
	_place_bins()
	_place_floods()
	for k in story.get("vendorRoutes", {}):
		var pts := PackedVector2Array()
		for p in story.vendorRoutes[k]:
			pts.append(Vector2(float(p[0]), float(p[1])))
		vendor_routes[k] = pts
	for k in story.get("questAreas", {}):
		var q: Dictionary = story.questAreas[k]
		var c: Vector2 = loc_door(str(q.around)) if locs.has(str(q.get("around", ""))) else Vector2.ZERO
		var r := float(q.get("radius", 80))
		quest_areas[k] = [c.x - r, c.y - r, c.x + r, c.y + r]


# ---------------------------------------------------------------- tên đường

## Tên đường trong truyện: "Hẻm 304 Phạm Thế Hiển" thành "Hẻm 304 Bờ Me"; đường lớn theo bảng names; tên lạ lấy tên dự phòng.
func street_name(real: String) -> String:
	if real == "":
		return ""
	for k in _names:
		if real == k or real == "Đường " + k:
			return str(_names[k])
	var words := real.split(" ")
	if words.size() >= 3 and words[0] in ["Hẻm", "Ngõ", "Ngách", "Kiệt"]:
		var main := " ".join(words.slice(2)).trim_prefix("Đường ")
		var fic := street_name(main).trim_prefix("Đường ").trim_prefix("Đại lộ ")
		return "Hẻm %s %s" % [words[1], fic]
	var fb: Array = story.get("fallbackNames", ["Đường Xóm Mới"])
	return str(fb[absi(hash(real)) % fb.size()])


# ---------------------------------------------------------------- địa điểm

func _index_roads() -> void:
	for r in data.roads:
		if r.bridge or r.tunnel or str(r.kind) in ["footway", "path", "steps", "cycleway"]:
			continue
		for i in r.line.size() - 1:
			var a: Vector2 = r.line[i]
			var b: Vector2 = r.line[i + 1]
			if a.distance_squared_to(b) < 0.01:
				continue
			var box := Rect2(a, Vector2.ZERO).expand(b)
			for gx in range(floori(box.position.x / SEG_CELL), floori(box.end.x / SEG_CELL) + 1):
				for gy in range(floori(box.position.y / SEG_CELL), floori(box.end.y / SEG_CELL) + 1):
					var k := Vector2i(gx, gy)
					if not _seg_grid.has(k):
						_seg_grid[k] = []
					_seg_grid[k].append([a, b, r])


## Đường gần điểm p nhất trong vòng 60 m (bỏ lối đi bộ, cầu): trả về {q: điểm trên tim đường, dir, road, d}.
func _nearest_road(p: Vector2, min_w := 2.5) -> Dictionary:
	var best := {}
	var best_d := INF
	var c := Vector2i(floori(p.x / SEG_CELL), floori(p.y / SEG_CELL))
	for gx in range(c.x - 2, c.x + 3):
		for gy in range(c.y - 2, c.y + 3):
			for seg in _seg_grid.get(Vector2i(gx, gy), []):
				if float(seg[2].width) < min_w:
					continue
				var a: Vector2 = seg[0]
				var ab: Vector2 = seg[1] - a
				var q: Vector2 = a + ab * clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
				var d := q.distance_to(p)
				if d < best_d:
					best_d = d
					best = {"q": q, "dir": ab.normalized(), "road": seg[2], "d": d}
	return best


func _place_locations() -> void:
	for k in story.get("locations", {}):
		var s: Dictionary = story.locations[k]
		var at := Vector2(float(s.at[0]), float(s.at[1]))
		var nr := _nearest_road(at)
		if nr.is_empty():
			continue
		var q: Vector2 = nr.q
		var n: Vector2 = (nr.dir as Vector2).orthogonal()
		if n.dot(q - at) < 0.0:
			n = -n
		var hw := float(nr.road.width) / 2.0
		var c: Vector2 = q - n * (hw + 0.3)
		var w := float(s.get("w", 8))
		var d := float(s.get("d", 10))
		locs[k] = {"center": c, "normal": n, "w": w, "d": d, "street": street_name(str(nr.road.name)), "loc": k, "no": "", "address": "",
			"line": nr.road.line, "road_w": float(nr.road.width)}
		# Dọn nhà thật trong lô (và chắn trước cửa) để dựng nhà của địa điểm.
		var t := Vector2(n.y, -n.x)
		var lot := PackedVector2Array([c - t * (w / 2.0 + 0.5), c + t * (w / 2.0 + 0.5), c + t * (w / 2.0 + 0.5) - n * (d + 0.5), c - t * (w / 2.0 + 0.5) - n * (d + 0.5)])
		data.buildings = data.buildings.filter(func(b) -> bool:
			if not Geo.bounds(b.poly).intersects(Geo.bounds(lot)):
				return true
			if Geometry2D.is_point_in_polygon(Geo.centroid(b.poly), lot):
				return false
			for v in b.poly:
				if Geometry2D.is_point_in_polygon(v, lot):
					return false
			return Geometry2D.intersect_polygons(b.poly, lot).is_empty())


## Nhà của các địa điểm dựng trên lô đã dọn nhà thật (_place_locations), nên lưới đi bộ chưa biết: chặn lô đó, chừa
## mép trước nhà (mái hiên, chỗ đứng trước cửa) để vẫn tới cửa được.
func _block_locations() -> void:
	for k in locs:
		var p: Dictionary = locs[k]
		var c: Vector2 = p.center
		var n: Vector2 = p.normal
		var t := Vector2(n.y, -n.x)
		var hw := float(p.w) / 2.0
		var front := c - n * 0.6
		var back := c - n * float(p.d)
		grid.block_poly(PackedVector2Array([front - t * hw, front + t * hw, back + t * hw, back - t * hw]))


## Đầu hẻm của con đường địa điểm nằm trên: đầu nào chạm đường lớn hơn thì là đầu hẻm; trả về chỗ ở mép hẻm,
## phía dãy nhà của địa điểm, cách miệng hẻm 2,5 m (chỗ trồng cây dừa của Hẻm Dừa).
func alley_mouth(loc_id: String) -> Vector2:
	var p: Dictionary = locs[loc_id]
	var line: PackedVector2Array = p.line
	var best := 0
	var best_d := INF
	for end in [0, line.size() - 1]:
		var e: Vector2 = line[end]
		var nr := _nearest_road(e, float(p.road_w) + 0.5)
		if not nr.is_empty() and float(nr.d) < best_d:
			best_d = float(nr.d)
			best = end
	var e: Vector2 = line[best]
	var nxt: Vector2 = line[1] if best == 0 else line[line.size() - 2]
	var into := (nxt - e).normalized()
	var side := into.orthogonal()
	if side.dot(-(p.normal as Vector2)) < 0.0:
		side = -side
	return e + into * 2.5 + side * (float(p.road_w) / 2.0 + 0.5)


static func footprint(p: Dictionary) -> Rect2:
	return CityMap.footprint(p)


## Chỗ đứng trước cửa: ra khỏi mép mái hiên (sâu 1,5 m), vì mặt tiền quay ngang thì mái hiên che người đứng dưới.
var door_out := 1.9


func loc_door(loc_id: String) -> Vector2:
	var p: Dictionary = locs[loc_id]
	return (p.center as Vector2) + (p.normal as Vector2) * door_out


# ---------------------------------------------------------------- nhà, thùng rác, chỗ ngập

## Nhà có cửa nhìn ra đường trong vòng 10 m: số nhà theo thứ tự dọc đường, lẻ một bên chẵn một bên.
func _place_homes() -> void:
	var by_road := {}
	for b in data.buildings:
		var a := absf(Geo.area(b.poly))
		if a < 20.0 or a > 450.0 or b.worship:
			continue
		var c := Geo.centroid(b.poly)
		var nr := _nearest_road(c, 3.0)
		if nr.is_empty() or float(nr.d) > float(nr.road.width) / 2.0 + 10.0:
			continue
		var name := street_name(str(nr.road.name))
		if name == "":
			continue
		var side_dir: Vector2 = (c - (nr.q as Vector2)).normalized()
		var door: Vector2 = (nr.q as Vector2) + side_dir * maxf(float(nr.road.width) / 2.0 - 0.6, 0.3)
		if not walkable(door):
			continue
		var side := 1 if (nr.dir as Vector2).orthogonal().dot(side_dir) > 0.0 else 0
		if not by_road.has(name):
			by_road[name] = []
		by_road[name].append({"pos": door, "u": door.dot(nr.dir), "side": side})
	for name in by_road:
		var list: Array = by_road[name]
		list.sort_custom(func(x, y) -> bool: return float(x.u) < float(y.u))
		var count := [0, 0]
		for h in list:
			count[h.side] += 1
			var no: int = int(count[h.side]) * 2 - (1 if int(h.side) == 1 else 0)
			homes.append({"pos": h.pos, "no": str(no), "address": "%d %s" % [no, str(name).trim_prefix("Đường ")]})


## Thùng rác mỗi 38 m dọc đường xe chạy (bên mép, chỗ đi được).
func _place_bins() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 47
	for r in data.roads:
		if r.bridge or r.tunnel or str(r.kind) in ["footway", "path", "steps", "cycleway"] or float(r.width) < 3.0:
			continue
		var hw := float(r.width) / 2.0
		AreaBuilder._along(r.line, 38.0, func(p: Vector2, d: Vector2) -> void:
			var q: Vector2 = p + d.orthogonal() * (hw - 0.5) * (1.0 if rng.randf() < 0.5 else -1.0)
			if walkable(q) and Geometry2D.is_point_in_polygon(q, clip):
				bins.append(q))


## Khoảng cách tới mặt nước trên lưới 5 m: tô ô nước rồi loang ra (thuật toán đốt rừng nhiều nguồn).
func _build_water_dist() -> void:
	var q: Array[Vector2i] = []
	for w in data.water:
		var r := Geo.bounds(w.poly)
		for gx in range(floori(r.position.x / WATER_CELL), ceili(r.end.x / WATER_CELL)):
			for gy in range(floori(r.position.y / WATER_CELL), ceili(r.end.y / WATER_CELL)):
				var k := Vector2i(gx, gy)
				if not _water_dist.has(k) and Geometry2D.is_point_in_polygon((Vector2(k) + Vector2(0.5, 0.5)) * WATER_CELL, w.poly):
					_water_dist[k] = 0.0
					q.append(k)
	var lim := ceili(120.0 / WATER_CELL)
	var head := 0
	while head < q.size():
		var k: Vector2i = q[head]
		head += 1
		var d: float = _water_dist[k]
		if d >= lim:
			continue
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = k + o
			if not _water_dist.has(n):
				_water_dist[n] = d + 1.0
				q.append(n)


func water_distance(p: Vector2) -> float:
	return float(_water_dist.get(Vector2i(floori(p.x / WATER_CELL), floori(p.y / WATER_CELL)), 999.0)) * WATER_CELL


## Đoạn đường gần mặt nước: mức 1 trong 30 m (bờ kênh), mức 2 trong 85 m.
func _place_floods() -> void:
	_build_water_dist()
	for r in data.roads:
		if r.bridge or r.tunnel:
			continue
		for i in r.line.size() - 1:
			var a: Vector2 = r.line[i]
			var b: Vector2 = r.line[i + 1]
			var dist := water_distance((a + b) / 2.0)
			var seg := {"a": a, "b": b, "w": float(r.width) + (2.0 if not r.small else 0.6)}
			if dist < 30.0:
				floods[1].append(seg)
				floods[2].append(seg)
			elif dist < 85.0:
				floods[2].append(seg)


# ---------------------------------------------------------------- đi bộ

func walkable(p: Vector2) -> bool:
	return grid.walkable(p)


## Độ cao mặt đất chỗ p: trên mặt cầu thì cao hơn mặt đường (AreaBuilder.BRIDGE_Y), người đi qua cầu không bị lún.
func ground_y(p: Vector2) -> float:
	if _bridges.is_empty():
		for r in data.roads:
			if r.bridge:
				for i in r.line.size() - 1:
					_bridges.append([r.line[i], r.line[i + 1], float(r.width) / 2.0 + 0.3])
		if _bridges.is_empty():
			_bridges.append([Vector2(INF, INF), Vector2(INF, INF), 0.0])
	for s in _bridges:
		if Geo.seg_dist(p, s[0], s[1]) <= float(s[2]):
			return AreaBuilder.BRIDGE_Y
	return 0.0


var _bridges: Array = []


func nearest_walkable(p: Vector2) -> Vector2:
	return grid.nearest_walkable(p)


func path(a: Vector2, b: Vector2) -> PackedVector2Array:
	return grid.path(a, b)


func path_length(a: Vector2, b: Vector2) -> float:
	var pts := path(a, b)
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i - 1].distance_to(pts[i])
	return total if pts.size() > 1 else a.distance_to(b)


## Map thật không có con rạch thẳng như map cũ; giữ cho chỗ còn gọi.
func canal_z(_x: float) -> float:
	return 0.0
