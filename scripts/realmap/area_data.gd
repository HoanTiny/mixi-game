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
