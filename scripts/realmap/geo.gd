extends RefCounted
## Đổi kinh độ, vĩ độ sang mét quanh tâm khu (x hướng đông, z hướng nam, giống màn phố: camera nhìn về bắc),
## và vài phép tính hình học trên đa giác phẳng dùng chung khi ghép và dựng.

const M_PER_DEG_LAT := 110574.0
const M_PER_DEG_LON := 111320.0

var lat0 := 0.0
var lon0 := 0.0
var _kx := M_PER_DEG_LON


func _init(lat: float, lon: float) -> void:
	lat0 = lat
	lon0 = lon
	_kx = M_PER_DEG_LON * cos(deg_to_rad(lat))


func to_local(lon: float, lat: float) -> Vector2:
	return Vector2((lon - lon0) * _kx, -(lat - lat0) * M_PER_DEG_LAT)


func to_lonlat(p: Vector2) -> Vector2:
	return Vector2(lon0 + p.x / _kx, lat0 - p.y / M_PER_DEG_LAT)


## Khung kinh vĩ độ [nam, tây, bắc, đông] của hình vuông cạnh size mét quanh điểm p (mét).
func bbox_around(p: Vector2, size: float) -> Array:
	var a := to_lonlat(p - Vector2(size, size) / 2.0)
	var b := to_lonlat(p + Vector2(size, size) / 2.0)
	return [minf(a.y, b.y), minf(a.x, b.x), maxf(a.y, b.y), maxf(a.x, b.x)]


# ---------------------------------------------------------------- đa giác

static func area(poly: PackedVector2Array) -> float:
	var s := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		s += a.x * b.y - b.x * a.y
	return s / 2.0


static func centroid(poly: PackedVector2Array) -> Vector2:
	var a := area(poly)
	if absf(a) < 0.01:
		var c := Vector2.ZERO
		for p in poly:
			c += p
		return c / maxf(poly.size(), 1)
	var cx := 0.0
	var cy := 0.0
	for i in poly.size():
		var p := poly[i]
		var q := poly[(i + 1) % poly.size()]
		var f := p.x * q.y - q.x * p.y
		cx += (p.x + q.x) * f
		cy += (p.y + q.y) * f
	return Vector2(cx, cy) / (6.0 * a)


static func bounds(poly: PackedVector2Array) -> Rect2:
	if poly.is_empty():
		return Rect2()
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	return r


## Bỏ điểm cuối trùng điểm đầu (vòng OSM khép kín) và các điểm trùng liền nhau.
static func clean_ring(poly: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in poly:
		if out.is_empty() or out[out.size() - 1].distance_squared_to(p) > 0.0004:
			out.append(p)
	if out.size() > 1 and out[0].distance_squared_to(out[out.size() - 1]) < 0.0004:
		out.remove_at(out.size() - 1)
	return out


## Khoảng cách từ điểm tới đoạn thẳng ab.
static func seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := 0.0
	var l2 := ab.length_squared()
	if l2 > 0.0:
		t = clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Ghép các đoạn đường viền (thành viên outer của quan hệ multipolygon) thành các vòng khép kín.
static func assemble_rings(lines: Array) -> Array:
	var rings := []
	var open: Array = []
	for l in lines:
		var pl: PackedVector2Array = l
		if pl.size() < 2:
			continue
		if pl[0].distance_squared_to(pl[pl.size() - 1]) < 0.0004:
			rings.append(pl)
		else:
			open.append(pl)
	while not open.is_empty():
		var cur: PackedVector2Array = open.pop_back()
		var grew := true
		while grew and cur[0].distance_squared_to(cur[cur.size() - 1]) >= 0.0004:
			grew = false
			for i in open.size():
				var o: PackedVector2Array = open[i]
				var tail := cur[cur.size() - 1]
				if tail.distance_squared_to(o[0]) < 0.0004:
					cur.append_array(o.slice(1))
				elif tail.distance_squared_to(o[o.size() - 1]) < 0.0004:
					var r := o.duplicate()
					r.reverse()
					cur.append_array(r.slice(1))
				else:
					continue
				open.remove_at(i)
				grew = true
				break
		if cur[0].distance_squared_to(cur[cur.size() - 1]) < 0.0004:
			rings.append(cur)
	return rings


## Đọc số từ tag OSM: "12", "12 m", "12.5m", "3;4" (lấy số đầu). Không đọc được thì trả về def.
static func num(v, def := 0.0) -> float:
	if v == null:
		return def
	var s := str(v).strip_edges().replace(",", ".")
	var digits := ""
	for ch in s:
		if ch in "0123456789." or (ch == "-" and digits == ""):
			digits += ch
		elif digits != "":
			break
	return float(digits) if digits.is_valid_float() else def
