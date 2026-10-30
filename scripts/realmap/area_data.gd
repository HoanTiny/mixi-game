extends RefCounted
## Dữ liệu một khu thật, đã đổi sang mét quanh tâm khu:
## - Từ OSM (Overpass, out geom): nhà vẽ tay (số tầng, chiều cao, màu tường, kiểu và màu mái), đường, sông hồ,
##   kênh rạch, công viên, đình chùa, di tích, tường rào, đường sắt.
## - Ghép nhà Open Buildings: nhà OSM được ưu tiên; nhà Open Buildings bị bỏ nếu độ tin cậy dưới ngưỡng (0,7),
##   trùng chỗ nhà OSM, nằm trên lòng đường hoặc nằm trên mặt nước.

const Geo := preload("res://scripts/realmap/geo.gd")
const CELL := 24.0

var geo: Geo
var cfg: Dictionary
var buildings: Array = []
var roads: Array = []
var water: Array = []
var waterways: Array = []
var parks: Array = []
var walls: Array = []
var rails: Array = []
var pois: Array = []
var trees: Array = []
var tree_rows: Array = []
## Đếm để báo cho người chơi: nhà OSM, nhà Open Buildings giữ lại, bị bỏ vì từng lý do.
var stats := {"osm": 0, "ob": 0, "ob_low": 0, "ob_dup": 0, "ob_road": 0, "ob_water": 0}


func _init(g: Geo, config: Dictionary) -> void:
	geo = g
	cfg = config


## Câu hỏi Overpass cho khung [nam, tây, bắc, đông].
static func query(bb: Array) -> String:
	return """[out:json][timeout:50][bbox:%f,%f,%f,%f];
(
  way["building"];
  relation["building"]["type"="multipolygon"];
  way["building:part"];
  way["highway"];
  way["natural"="water"];
  relation["natural"="water"];
  way["waterway"];
  relation["waterway"="riverbank"];
  way["landuse"~"^(reservoir|basin|grass|recreation_ground|cemetery|village_green|meadow|forest)$"];
  way["leisure"~"^(park|garden|playground|pitch|nature_reserve)$"];
  relation["leisure"="park"];
  way["natural"~"^(wood|scrub|grassland)$"];
  nwr["amenity"="place_of_worship"];
  nwr["historic"];
  way["barrier"~"^(wall|fence|city_wall|retaining_wall)$"];
  way["railway"="rail"];
  node["natural"="tree"];
  way["natural"="tree_row"];
  nwr["tourism"~"^(attraction|museum|viewpoint|artwork)$"]["name"];
  nwr["amenity"~"^(theatre|townhall|post_office|marketplace|hospital|university|school)$"]["name"];
);
out geom;""" % [bb[0], bb[1], bb[2], bb[3]]


## Câu hỏi nhẹ cho bản đồ nền: đường, sông hồ, công viên; phóng gần thì thêm nhà và tên địa danh.
static func preview_query(bb: Array, with_buildings := false) -> String:
	var extra := """
  way["highway"~"^(service|living_street|pedestrian|footway)$"];
  way["building"];
  nwr["amenity"="place_of_worship"]["name"];
  nwr["historic"]["name"];
  nwr["tourism"~"^(attraction|museum)$"]["name"];""" if with_buildings else ""
	return """[out:json][timeout:25][bbox:%f,%f,%f,%f];
(
  way["highway"~"^(motorway|trunk|primary|secondary|tertiary|residential|unclassified|living_street|motorway_link|trunk_link|primary_link|secondary_link)$"];
  way["natural"="water"];
  relation["natural"="water"];
  way["waterway"~"^(river|canal|riverbank|stream)$"];
  way["leisure"~"^(park|garden)$"];%s
);
out geom;""" % [bb[0], bb[1], bb[2], bb[3], extra]


func _line(geom: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in geom:
		if p == null:
			continue
		out.append(geo.to_local(float(p.lon), float(p.lat)))
	return out


# ---------------------------------------------------------------- đọc OSM

func parse_osm(json: Dictionary) -> void:
	var parts := []
	var outlines := []
	for e in json.get("elements", []):
		var tags: Dictionary = e.get("tags", {})
		var kind := str(e.get("type", ""))
		var rings := []
		var line := PackedVector2Array()
		if kind == "way":
			line = _line(e.get("geometry", []))
			if line.size() >= 3 and line[0].distance_squared_to(line[line.size() - 1]) < 0.0004:
				rings.append(Geo.clean_ring(line))
		elif kind == "relation":
			var outers := []
			for m in e.get("members", []):
				if str(m.get("type", "")) == "way" and str(m.get("role", "outer")) in ["outer", ""]:
					outers.append(_line(m.get("geometry", [])))
			for r in Geo.assemble_rings(outers):
				rings.append(Geo.clean_ring(r))
		elif kind == "node":
			var np := geo.to_local(float(e.lon), float(e.lat))
			if str(tags.get("natural", "")) == "tree":
				trees.append(np)
			elif tags.has("name") and (tags.has("amenity") or tags.has("historic") or tags.has("tourism")):
				pois.append({"pos": np, "name": str(tags.name), "kind": _poi_kind(tags), "rank": _poi_rank(tags)})
			continue
		if tags.has("building") or tags.has("building:part"):
			for r in rings:
				if r.size() >= 3:
					var b := _building(r, tags)
					if tags.has("building:part"):
						parts.append(b)
					else:
						outlines.append(b)
			continue
		if tags.has("highway"):
			var hw := str(tags.highway)
			if hw in ["construction", "proposed", "platform", "bus_stop", "elevator"] or line.size() < 2 or str(tags.get("area", "")) == "yes":
				continue
			roads.append({"line": line, "kind": hw, "width": _road_width(tags), "name": str(tags.get("name", "")),
				"bridge": str(tags.get("bridge", "no")) not in ["no", ""], "tunnel": str(tags.get("tunnel", "no")) not in ["no", ""],
				"small": (cfg.get("roads", {}).get("small", []) as Array).has(hw)})
			continue
		if _is_water(tags):
			for r in rings:
				water.append({"poly": r, "name": str(tags.get("name", ""))})
			continue
		if tags.has("waterway") and line.size() >= 2:
			var ww := str(tags.waterway)
			var wdef: Dictionary = cfg.get("waterways", {})
			if wdef.has(ww):
				waterways.append({"line": line, "width": Geo.num(tags.get("width"), float(wdef[ww])), "name": str(tags.get("name", "")), "kind": ww})
			continue
		if _is_park(tags):
			for r in rings:
				parks.append({"poly": r, "kind": str(tags.get("leisure", tags.get("landuse", tags.get("natural", "")))), "name": str(tags.get("name", ""))})
			continue
		if tags.has("barrier") and line.size() >= 2:
			walls.append({"line": line, "kind": str(tags.barrier), "height": Geo.num(tags.get("height"), 0.0)})
			continue
		if str(tags.get("railway", "")) == "rail" and line.size() >= 2:
			rails.append({"line": line})
			continue
		if str(tags.get("natural", "")) == "tree_row" and line.size() >= 2:
			tree_rows.append({"line": line})
			continue
		# Chùa, đình, di tích vẽ thành vùng (không ghi building): chỉ đặt nhãn tên.
		if (tags.has("amenity") or tags.has("historic") or tags.has("tourism")) and tags.has("name"):
			var c := Geo.centroid(rings[0]) if not rings.is_empty() else (line[0] if not line.is_empty() else Vector2.ZERO)
			pois.append({"pos": c, "name": str(tags.name), "kind": _poi_kind(tags), "rank": _poi_rank(tags)})
	# Có building:part thì bỏ đường viền tổng chứa nó, tránh hai khối chồng nhau.
	for o in outlines:
		var keep := true
		for p in parts:
			if Geometry2D.is_point_in_polygon(Geo.centroid(p.poly), o.poly):
				keep = false
				break
		if keep:
			buildings.append(o)
	buildings.append_array(parts)
	# Nhà có tên thành địa danh: đền chùa, di tích, và tòa nhà lớn (từ 800 m²).
	for b in buildings:
		if b.name != "" and (b.worship or b.historic or absf(Geo.area(b.poly)) >= 800.0):
			pois.append({"pos": Geo.centroid(b.poly), "name": b.name, "kind": "worship" if b.worship else "historic",
				"rank": 3 if (b.worship or b.historic) else 2, "height": maxf(float(b.height), 8.0)})
	stats["osm"] = buildings.size()


static func _poi_kind(tags: Dictionary) -> String:
	if str(tags.get("amenity", "")) == "place_of_worship":
		return "worship"
	if tags.has("historic"):
		return "historic"
	return "other"


## Độ ưu tiên nhãn: đền chùa, di tích, điểm tham quan trước; trường, chợ, bệnh viện sau.
static func _poi_rank(tags: Dictionary) -> int:
	if str(tags.get("amenity", "")) == "place_of_worship" or tags.has("historic") or tags.has("tourism"):
		return 3
	return 1


static func _is_water(tags: Dictionary) -> bool:
	return str(tags.get("natural", "")) == "water" or str(tags.get("waterway", "")) == "riverbank" \
		or str(tags.get("landuse", "")) in ["reservoir", "basin"] or (tags.has("water") and not tags.has("building"))


static func _is_park(tags: Dictionary) -> bool:
	return str(tags.get("leisure", "")) in ["park", "garden", "playground", "pitch", "nature_reserve"] \
		or str(tags.get("landuse", "")) in ["grass", "recreation_ground", "cemetery", "village_green", "meadow", "forest"] \
		or str(tags.get("natural", "")) in ["wood", "scrub", "grassland"]


func _road_width(tags: Dictionary) -> float:
	var rc: Dictionary = cfg.get("roads", {})
	var w := Geo.num(tags.get("width"), 0.0)
	if w > 0.5:
		return w
	var lanes := Geo.num(tags.get("lanes"), 0.0)
	if lanes >= 1.0:
		return lanes * 3.2
	return float(rc.get("width", {}).get(str(tags.highway), rc.get("default", 4)))


## Nhà OSM: chiều cao theo height, hay số tầng; màu tường, kiểu mái, màu mái nếu có ghi.
func _building(poly: PackedVector2Array, tags: Dictionary) -> Dictionary:
	var bc: Dictionary = cfg.get("buildings", {})
	var lh := float(bc.get("levelHeight", 3.2))
	var worship := str(tags.get("amenity", "")) == "place_of_worship" or str(tags.get("building", "")) in ["temple", "pagoda", "shrine", "church", "cathedral", "chapel", "mosque"]
	var levels := Geo.num(tags.get("building:levels"), 0.0)
	var roof_levels := Geo.num(tags.get("roof:levels"), 0.0)
	var h := Geo.num(tags.get("height"), 0.0)
	var known := h > 0.0 or levels > 0.0
	if h <= 0.0 and levels > 0.0:
		h = (levels + roof_levels) * lh
	var min_h := Geo.num(tags.get("min_height"), Geo.num(tags.get("building:min_level"), 0.0) * lh)
	return {"poly": poly, "height": h, "known": known, "min_height": min_h, "src": "osm",
		"colour": _colour(tags.get("building:colour", tags.get("colour"))),
		"roof_shape": str(tags.get("roof:shape", "")), "roof_colour": _colour(tags.get("roof:colour")),
		"roof_height": Geo.num(tags.get("roof:height"), 0.0),
		"name": str(tags.get("name", "")), "worship": worship, "historic": tags.has("historic"),
		"kind": str(tags.get("building", tags.get("building:part", "yes")))}


## Màu OSM: "#rrggbb", "#rgb" hay tên màu tiếng Anh. null nếu không có hoặc không đọc được.
static func _colour(v):
	if v == null or str(v).strip_edges() == "":
		return null
	var s := str(v).strip_edges().to_lower()
	if s.begins_with("#") or s.is_valid_html_color():
		return Color.html(s) if s.is_valid_html_color() else null
	var c := Color.from_string(s, Color(0, 0, 0, 0))
	return null if c.a == 0.0 else c


# ---------------------------------------------------------------- ghép Open Buildings

## feats: kết quả của fgb_reader (đường viền theo kinh, vĩ độ, cột confidence).
func merge_open_buildings(feats: Array) -> void:
	var ob: Dictionary = cfg.get("openBuildings", {})
	var min_conf := float(ob.get("minConfidence", 0.7))
	var keep_unknown := bool(ob.get("keepUnknownConfidence", true))
	var bgrid := _grid_polys(buildings.map(func(b): return b.poly))
	var wgrid := _grid_polys(water.map(func(w): return w.poly))
	var rgrid := _grid_lines(roads.filter(func(r): return not r.small and not r.tunnel))
	var wwgrid := _grid_lines(waterways)
	for f in feats:
		var conf = f.props.get("confidence", null)
		var known := conf != null and typeof(conf) in [TYPE_FLOAT, TYPE_INT] and not is_nan(float(conf)) and float(conf) >= 0.0
		if (known and float(conf) < min_conf) or (not known and not keep_unknown):
			stats.ob_low += 1
			continue
		for ring in f.rings:
			var poly := PackedVector2Array()
			for p in ring:
				poly.append(geo.to_local(p.x, p.y))
			poly = Geo.clean_ring(poly)
			if poly.size() < 3:
				continue
			var c := Geo.centroid(poly)
			if _hits_building(poly, c, bgrid):
				stats.ob_dup += 1
				continue
			if _on_line(c, rgrid, 0.9):
				stats.ob_road += 1
				continue
			if _in_poly(c, wgrid) or _on_line(c, wwgrid, 1.0):
				stats.ob_water += 1
				continue
			buildings.append({"poly": poly, "height": 0.0, "known": false, "min_height": 0.0, "src": "ob",
				"colour": null, "roof_shape": "", "roof_colour": null, "roof_height": 0.0, "name": "",
				"worship": false, "historic": false, "kind": "yes", "conf": float(conf) if known else -1.0, "props": f.props})
			stats.ob += 1


static func _cells(r: Rect2) -> Array:
	var out := []
	for gx in range(floori(r.position.x / CELL), floori(r.end.x / CELL) + 1):
		for gy in range(floori(r.position.y / CELL), floori(r.end.y / CELL) + 1):
			out.append(Vector2i(gx, gy))
	return out


static func _grid_polys(polys: Array) -> Dictionary:
	var g := {}
	for p in polys:
		var poly: PackedVector2Array = p
		for c in _cells(Geo.bounds(poly)):
			if not g.has(c):
				g[c] = []
			g[c].append(poly)
	return g


static func _grid_lines(items: Array) -> Dictionary:
	var g := {}
	for it in items:
		var l: PackedVector2Array = it.line
		var hw := float(it.width) / 2.0
		for i in l.size() - 1:
			var seg := [l[i], l[i + 1], hw]
			for c in _cells(Rect2(l[i], Vector2.ZERO).expand(l[i + 1]).grow(hw)):
				if not g.has(c):
					g[c] = []
				g[c].append(seg)
	return g


## Trùng chỗ nhà OSM: tâm nhà này nằm trong nhà OSM, tâm nhà OSM nằm trong nhà này, hay một nửa số đỉnh nằm trong.
func _hits_building(poly: PackedVector2Array, c: Vector2, grid: Dictionary) -> bool:
	var seen := {}
	for cell in _cells(Geo.bounds(poly)):
		for o in grid.get(cell, []):
			var op: PackedVector2Array = o
			if seen.has(op):
				continue
			seen[op] = true
			if not Geo.bounds(op).intersects(Geo.bounds(poly)):
				continue
			if Geometry2D.is_point_in_polygon(c, op) or Geometry2D.is_point_in_polygon(Geo.centroid(op), poly):
				return true
			var inside := 0
			for p in poly:
				if Geometry2D.is_point_in_polygon(p, op):
					inside += 1
			if inside * 2 >= poly.size():
				return true
	return false


static func _on_line(p: Vector2, grid: Dictionary, k: float) -> bool:
	var cell := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	for seg in grid.get(cell, []):
		if Geo.seg_dist(p, seg[0], seg[1]) < float(seg[2]) * k:
			return true
	return false


static func _in_poly(p: Vector2, grid: Dictionary) -> bool:
	var cell := Vector2i(floori(p.x / CELL), floori(p.y / CELL))
	for poly in grid.get(cell, []):
		if Geometry2D.is_point_in_polygon(p, poly):
			return true
	return false


# ---------------------------------------------------------------- cắt theo vùng

## Giữ phần nằm trong vùng clip (mét): đường, kênh, tường bị cắt thành đoạn; hồ, công viên giao với vùng;
## nhà, cây, địa danh giữ nếu tâm nằm trong vùng.
## Tim đường xuyên qua nhà quá chừng này mét thì bỏ nhà (drop_buildings_over_lanes).
const LANE_THROUGH := 1.5
## Mảnh nhà còn lại sau khi cắt hẻm nhỏ hơn chừng này (m²) thì bỏ.
const MIN_PIECE := 8.0


func clip_to(clip: PackedVector2Array) -> void:
	roads = _clip_items(roads, clip)
	waterways = _clip_items(waterways, clip)
	walls = _clip_items(walls, clip)
	rails = _clip_items(rails, clip)
	tree_rows = _clip_items(tree_rows, clip)
	water = _clip_areas(water, clip)
	parks = _clip_areas(parks, clip)
	buildings = buildings.filter(func(b) -> bool: return Geometry2D.is_point_in_polygon(Geo.centroid(b.poly), clip))
	pois = pois.filter(func(p) -> bool: return Geometry2D.is_point_in_polygon(p.pos, clip))
	trees = trees.filter(func(t) -> bool: return Geometry2D.is_point_in_polygon(t, clip))
	drop_buildings_over_lanes()


## Nhà lấy từ ảnh vệ tinh (Open Buildings) hay gộp mái hai dãy nhà thành một khối phủ qua hẻm: tim một con đường, hẻm
## (trừ hầm) chạy xuyên giữa nhà quá LANE_THROUGH mét thì cắt lòng hẻm ra khỏi khối nhà (rộng bằng hẻm, nới 0,3 m mỗi
## bên); mảnh còn lại từ MIN_PIECE m² giữ làm nhà. Hẻm hiện ra, không ai đi xuyên nhà. Nhà ghi trong OSM giữ nguyên (có
## thể là lối đi có mái che thật). Trả về số nhà đã cắt.
func drop_buildings_over_lanes() -> int:
	var g := {}
	for r in roads:
		if r.tunnel or str(r.kind) == "steps":
			continue
		var l: PackedVector2Array = r.line
		var hw := float(r.width) / 2.0 + 0.3
		for i in l.size() - 1:
			for c in _cells(Rect2(l[i], Vector2.ZERO).expand(l[i + 1])):
				if not g.has(c):
					g[c] = []
				g[c].append([l[i], l[i + 1], hw])
	var out := []
	var cut := 0
	for b in buildings:
		if bool(b.known) and str(b.get("src", "")) != "ob":
			out.append(b)
			continue
		var poly: PackedVector2Array = b.poly
		var through := 0.0
		var hits := []
		var seen := {}
		for c in _cells(Geo.bounds(poly)):
			for seg in g.get(c, []):
				var key := Vector4(seg[0].x, seg[0].y, seg[1].x, seg[1].y)
				if seen.has(key):
					continue
				seen[key] = true
				var a: Vector2 = seg[0]
				var e: Vector2 = seg[1]
				var n := maxi(1, ceili(a.distance_to(e) / 0.5))
				var inside := 0.0
				for k in n:
					if Geometry2D.is_point_in_polygon(a.lerp(e, (float(k) + 0.5) / float(n)), poly):
						inside += a.distance_to(e) / float(n)
				if inside > 0.0:
					through += inside
					hits.append(seg)
		if through <= LANE_THROUGH:
			out.append(b)
			continue
		cut += 1
		var pieces: Array = [poly]
		for seg in hits:
			var strip: Array = Geometry2D.offset_polyline(PackedVector2Array([seg[0], seg[1]]), float(seg[2]), Geometry2D.JOIN_SQUARE, Geometry2D.END_SQUARE)
			var next: Array = []
			for pc in pieces:
				var rest: Array = [pc]
				for sp in strip:
					var r2: Array = []
					for x in rest:
						r2.append_array(Geometry2D.clip_polygons(x, sp))
					rest = r2
				next.append_array(rest)
			pieces = next
		for pc in pieces:
			var pp: PackedVector2Array = pc
			# Bỏ lỗ (đường viền ngược chiều) và mảnh vụn.
			# Kết quả cắt: đường viền ngoài ngược chiều kim đồng hồ, lỗ thuận chiều.
			if pp.size() < 3 or Geometry2D.is_polygon_clockwise(pp) or absf(Geo.area(pp)) < MIN_PIECE:
				continue
			var nb: Dictionary = b.duplicate()
			nb["poly"] = pp
			out.append(nb)
	buildings = out
	stats["ob_lane"] = cut
	return cut


static func _clip_items(items: Array, clip: PackedVector2Array) -> Array:
	var out := []
	for it in items:
		for seg in Geometry2D.intersect_polyline_with_polygon(it.line, clip):
			if seg.size() >= 2:
				var c: Dictionary = it.duplicate()
				c["line"] = seg
				out.append(c)
	return out


static func _clip_areas(items: Array, clip: PackedVector2Array) -> Array:
	var out := []
	var cw := Geometry2D.is_polygon_clockwise(clip)
	for it in items:
		for poly in Geometry2D.intersect_polygons(it.poly, clip):
			if poly.size() >= 3 and Geometry2D.is_polygon_clockwise(poly) == cw:
				var c: Dictionary = it.duplicate()
				c["poly"] = poly
				out.append(c)
	return out


# ---------------------------------------------------------------- lưu, đọc map nướng sẵn

## Mảng điểm thành [x, z, x, z…] làm tròn 0,1 m cho file nhỏ.
static func _flat(pts: PackedVector2Array) -> Array:
	var out := []
	for p in pts:
		out.append(snappedf(p.x, 0.1))
		out.append(snappedf(p.y, 0.1))
	return out


static func _pts(a: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, a.size() - 1, 2):
		out.append(Vector2(float(a[i]), float(a[i + 1])))
	return out


static func _hex(c) -> String:
	return "" if c == null else (c as Color).to_html(false)


static func _col(s):
	return null if str(s) == "" else Color(str(s))


## Dữ liệu đã cắt thành từ điển gọn để lưu JSON (map nướng sẵn cho truyện).
func to_dict() -> Dictionary:
	var d := {"buildings": [], "roads": [], "water": [], "waterways": [], "parks": [], "walls": [], "rails": [],
		"trees": [], "tree_rows": [], "pois": [], "stats": stats}
	for b in buildings:
		d.buildings.append({"p": _flat(b.poly), "h": snappedf(float(b.height), 0.1), "k": b.known, "mh": snappedf(float(b.min_height), 0.1),
			"c": _hex(b.colour), "rs": b.roof_shape, "rc": _hex(b.roof_colour), "rh": snappedf(float(b.roof_height), 0.1),
			"n": b.name, "w": b.worship, "hi": b.historic, "s": b.src, "kind": b.kind})
	for r in roads:
		d.roads.append({"l": _flat(r.line), "k": r.kind, "w": r.width, "n": r.name, "b": r.bridge, "t": r.tunnel, "s": r.small})
	for w in water:
		d.water.append({"p": _flat(w.poly), "n": w.name})
	for w in waterways:
		d.waterways.append({"l": _flat(w.line), "w": w.width, "n": w.name, "k": w.kind})
	for p in parks:
		d.parks.append({"p": _flat(p.poly), "k": p.kind, "n": p.name})
	for w in walls:
		d.walls.append({"l": _flat(w.line), "k": w.kind, "h": w.height})
	for r in rails:
		d.rails.append({"l": _flat(r.line)})
	for t in trees:
		d.trees.append_array([snappedf(t.x, 0.1), snappedf(t.y, 0.1)])
	for r in tree_rows:
		d.tree_rows.append({"l": _flat(r.line)})
	for p in pois:
		d.pois.append({"x": snappedf(p.pos.x, 0.1), "z": snappedf(p.pos.y, 0.1), "n": p.name, "k": p.kind, "r": p.get("rank", 1)})
	return d


## Đọc lại từ to_dict().
## Bề ngang vỉa hè mỗi bên đường (mét): map dựng tay ghi riêng từng phố (sw); map lấy từ OSM thì đường từ 7 m có
## vỉa hè 1,6 m, đường 6–7 m có 1,2 m, hẻm không có.
static func sidewalk(r: Dictionary) -> float:
	var sw := float(r.get("sw", -1.0))
	if sw >= 0.0:
		return sw
	var w := float(r.width)
	if bool(r.small) or w < 6.0:
		return 0.0
	return 1.6 if w >= 7.0 else 1.2


func from_dict(d: Dictionary) -> void:
	for b in d.get("buildings", []):
		buildings.append({"poly": _pts(b.p), "height": float(b.h), "known": bool(b.k), "min_height": float(b.mh), "src": str(b.s),
			"colour": _col(b.c), "roof_shape": str(b.rs), "roof_colour": _col(b.rc), "roof_height": float(b.rh),
			"name": str(b.n), "worship": bool(b.w), "historic": bool(b.hi), "kind": str(b.get("kind", "yes"))})
	for r in d.get("roads", []):
		roads.append({"line": _pts(r.l), "kind": str(r.k), "width": float(r.w), "name": str(r.n), "bridge": bool(r.b), "tunnel": bool(r.t), "small": bool(r.s),
			"sw": float(r.get("sw", -1.0))})
	for w in d.get("water", []):
		water.append({"poly": _pts(w.p), "name": str(w.n)})
	for w in d.get("waterways", []):
		waterways.append({"line": _pts(w.l), "width": float(w.w), "name": str(w.n), "kind": str(w.k)})
	for p in d.get("parks", []):
		parks.append({"poly": _pts(p.p), "kind": str(p.k), "name": str(p.n)})
	for w in d.get("walls", []):
		walls.append({"line": _pts(w.l), "kind": str(w.k), "height": float(w.h)})
	for r in d.get("rails", []):
		rails.append({"line": _pts(r.l)})
	trees = Array(_pts(d.get("trees", [])))
	for r in d.get("tree_rows", []):
		tree_rows.append({"line": _pts(r.l)})
	for p in d.get("pois", []):
		pois.append({"pos": Vector2(float(p.x), float(p.z)), "name": str(p.n), "kind": str(p.k), "rank": int(p.r)})
	stats = d.get("stats", stats)

