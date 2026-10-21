extends Node3D
## Dựng 3D một khu thật từ area_data.gd. Mỗi loại (mặt đất, cỏ, nước, đường, nhà) gộp thành vài lưới lớn
## để chạy nhẹ cả trên trình duyệt với vài nghìn căn nhà:
## - Nhà: đùn đường viền lên theo chiều cao (height, số tầng; thiếu thì lấy 2–5 tầng như nhà ống), màu tường,
##   mái bằng, mái hai dốc, mái bốn dốc, mái chóp theo roof:shape; chùa, đình mái ngói bốn dốc. Mặt tường có ô cửa sổ
##   theo tầng. Nhà che An thì khoét một lỗ nhìn xuyên (shader), không phải giấu cả căn.
## - Đường có vỉa hè, vạch giữa; ngõ nhỏ lát bê tông; cầu có lan can. Sông, hồ, kênh, công viên, sân bóng,
##   tường rào, đường sắt, nhãn tên đường, hồ, chùa, di tích.
## - Lưới đi bộ 1 m: không đi xuyên nhà, tường, mặt nước (trừ trên cầu).

const Geo := preload("res://scripts/realmap/geo.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")

const BUILDING_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 player_pos;
uniform vec3 cam_pos;
uniform float hole = 3.2;
uniform float band_half = 9.0;
uniform float band_depth = 26.0;
varying vec3 wpos;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	// Lỗ nhìn xuyên: bỏ phần nhà nằm giữa camera và An, gần phía An.
	vec3 a = cam_pos;
	vec3 b = player_pos + vec3(0.0, 1.0, 0.0);
	vec3 ab = b - a;
	float t = clamp(dot(wpos - a, ab) / max(dot(ab, ab), 0.001), 0.0, 1.0);
	float d = length(wpos - (a + ab * t));
	if (t > 0.08 && t < 0.985 && d < hole * smoothstep(0.08, 0.7, t) + 0.6) {
		discard;
	}
	// Camera luôn nhìn về hướng bắc: nhà ở dải phía nam (trước mặt camera) gần An bị cắt còn chân tường thấp,
	// như kiểu cắt nhà ở màn phố, để thấy An và mặt phố.
	float dz = wpos.z - player_pos.z;
	if (dz > 1.2 && dz < band_depth && abs(wpos.x - player_pos.x) < band_half + dz * 0.35 && wpos.y > 0.7) {
		discard;
	}
	vec3 col = COLOR.rgb;
	if (UV2.x > 0.5) {
		// Tường: vạch sàn mỗi tầng, ô cửa sổ kính tối, tầng trệt cửa cuốn rộng hơn.
		float fy = fract(UV.y / 3.2);
		float fx = fract(UV.x / 2.6);
		float floor_i = floor(UV.y / 3.2);
		bool win = fy > 0.32 && fy < 0.8 && fx > 0.22 && fx < 0.78 && floor_i >= 1.0 && UV.y < UV2.y - 0.6;
		bool door = floor_i < 1.0 && fy > 0.05 && fy < 0.72 && fx > 0.12 && fx < 0.88 && UV2.y > 4.0;
		if (win) col = mix(col, vec3(0.13, 0.17, 0.21), 0.78);
		if (door) col = mix(col, vec3(0.32, 0.31, 0.3), 0.6);
		if (fy < 0.05) col *= 0.86;
	}
	ALBEDO = col;
	ROUGHNESS = 0.88;
}
"""

var data
var cfg: Dictionary
var font: Font
var building_mat: ShaderMaterial
var grid: AStarGrid2D
var bounds := Rect2()
var labels: Array = []
var _flat := {}
var _rng := RandomNumberGenerator.new()


func build(d, area_rect: Rect2) -> void:
	data = d
	cfg = d.cfg
	bounds = area_rect
	font = UI.text_font()
	building_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = BUILDING_SHADER
	building_mat.shader = sh
	_ground()
	_parks()
	_water()
	_roads()
	_rails()
	_walls()
	_buildings()
	_labels()
	_commit_flat()
	_walk_grid()


# ---------------------------------------------------------------- lưới gộp

## Lấy (tạo) SurfaceTool gộp cho một lớp mặt phẳng (cùng vật liệu).
func _st(key: String) -> SurfaceTool:
	if not _flat.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_flat[key] = st
	return _flat[key]


func _commit_flat() -> void:
	for key in _flat:
		var st: SurfaceTool = _flat[key]
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if key != "walls" else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.92
		if key == "water":
			m.roughness = 0.12
			m.metallic = 0.15
		mi.material_override = m
		add_child(mi)
	_flat.clear()


## Tam giác có pháp tuyến n, tự đảo thứ tự đỉnh cho mặt trước quay về phía n (Godot: mặt trước theo chiều kim đồng hồ).
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3, col: Color, uv := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO], uv2 := Vector2.ZERO) -> void:
	var pts := [a, b, c]
	var uvs: Array = uv
	if (b - a).cross(c - a).dot(n) > 0.0:
		pts = [a, c, b]
		uvs = [uv[0], uv[2], uv[1]]
	for i in 3:
		st.set_normal(n)
		st.set_color(col)
		st.set_uv(uvs[i])
		st.set_uv2(uv2)
		st.add_vertex(pts[i])


## Đa giác phẳng nằm ngang ở độ cao y.
static func _fill(st: SurfaceTool, poly: PackedVector2Array, y: float, col: Color, uv2 := Vector2.ZERO) -> void:
	var idx := Geometry2D.triangulate_polygon(poly)
	for i in range(0, idx.size(), 3):
		_tri(st, Vector3(poly[idx[i]].x, y, poly[idx[i]].y), Vector3(poly[idx[i + 1]].x, y, poly[idx[i + 1]].y),
			Vector3(poly[idx[i + 2]].x, y, poly[idx[i + 2]].y), Vector3.UP, col, [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO], uv2)


## Dải nằm ngang dọc một đường gấp khúc, bề rộng w, có khớp tròn ở các góc.
static func _strip(st: SurfaceTool, line: PackedVector2Array, w: float, y: float, col: Color) -> void:
	var hw := w / 2.0
	for i in line.size() - 1:
		var a := line[i]
		var b := line[i + 1]
		if a.distance_squared_to(b) < 0.0001:
			continue
		var n := (b - a).normalized().orthogonal() * hw
		var q := [a + n, b + n, b - n, a - n]
		_tri(st, _v(q[0], y), _v(q[1], y), _v(q[2], y), Vector3.UP, col)
		_tri(st, _v(q[0], y), _v(q[2], y), _v(q[3], y), Vector3.UP, col)
	for i in line.size():
		if hw < 0.6:
			continue
		var c := line[i]
		for k in 8:
			var a0 := TAU * k / 8.0
			var a1 := TAU * (k + 1) / 8.0
			_tri(st, _v(c, y), _v(c + Vector2(cos(a0), sin(a0)) * hw, y), _v(c + Vector2(cos(a1), sin(a1)) * hw, y), Vector3.UP, col)


static func _v(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)


# ---------------------------------------------------------------- mặt đất, cỏ, nước

func _ground() -> void:
	var r := bounds.grow(60.0)
	_fill(_st("ground"), PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), 0.0, Color("9c958a"))


func _parks() -> void:
	for p in data.parks:
		var col := Color("6f9a4f")
		match str(p.kind):
			"pitch":
				col = Color("5c9a58")
			"playground":
				col = Color("b9a27c")
			"cemetery":
				col = Color("8a9a78")
			"forest", "wood", "nature_reserve":
				col = Color("4f7d40")
		_fill(_st("ground"), p.poly, 0.02, col)
		# Cây trong công viên: rải theo lưới thưa.
		if str(p.kind) in ["park", "garden", "forest", "wood", "nature_reserve", "village_green"]:
			_trees_in(p.poly)


var _trees: Array = []


func _trees_in(poly: PackedVector2Array) -> void:
	var r := Geo.bounds(poly)
	_rng.seed = hash(r.position)
	var step := 9.0
	var x := r.position.x + step / 2.0
	while x < r.end.x:
		var z := r.position.y + step / 2.0
		while z < r.end.y:
			var p := Vector2(x + _rng.randf_range(-3, 3), z + _rng.randf_range(-3, 3))
			if Geometry2D.is_point_in_polygon(p, poly) and _rng.randf() < 0.55 and not _in_water(p):
				_trees.append(p)
			z += step
		x += step


func _in_water(p: Vector2) -> bool:
	for w in data.water:
		if Geo.bounds(w.poly).has_point(p) and Geometry2D.is_point_in_polygon(p, w.poly):
			return true
	return false


func _water() -> void:
	var col := Color("2f5458")
	for w in data.water:
		_fill(_st("water"), w.poly, 0.03, col)
	for w in data.waterways:
		_strip(_st("water"), w.line, float(w.width), 0.035, col)


# ---------------------------------------------------------------- đường

func _roads() -> void:
	var order: Array = data.roads.duplicate()
	# Đường nhỏ vẽ trước, đường lớn đè lên ở chỗ giao nhau.
	order.sort_custom(func(a, b) -> bool: return float(a.width) < float(b.width))
	var i := 0
	for r in order:
		if r.tunnel:
			continue
		var w := float(r.width)
		var y := 0.05 + float(i) * 0.00002
		i += 1
		if r.bridge:
			y = 0.5
		if r.small:
			_strip(_st("ground"), r.line, w, y, Color("a8a296") if str(r.kind) != "steps" else Color("9c958a"))
			continue
		if w >= 7.0:
			# Vỉa hè lát gạch hai bên, rồi mặt nhựa.
			_strip(_st("ground"), r.line, w + 3.2, y - 0.01, Color("c9bfae"))
		_strip(_st("ground"), r.line, w, y, Color("4a4b4e") if w >= 7.0 else Color("66676a"))
		if w >= 8.0:
			_dashes(r.line, y + 0.005)
		if r.bridge:
			_bridge_rails(r.line, w)


func _dashes(line: PackedVector2Array, y: float) -> void:
	var st := _st("ground")
	for i in line.size() - 1:
		var a := line[i]
		var b := line[i + 1]
		var l := a.distance_to(b)
		var dir := (b - a) / maxf(l, 0.001)
		var s := 1.0
		while s + 3.0 < l:
			_strip(st, PackedVector2Array([a + dir * s, a + dir * (s + 3.0)]), 0.15, y, Color("e8e4da"))
			s += 7.0


func _bridge_rails(line: PackedVector2Array, w: float) -> void:
	var st := _st("walls")
	for i in line.size() - 1:
		var a := line[i]
		var b := line[i + 1]
		var n := (b - a).normalized().orthogonal() * (w / 2.0 + 0.1)
		for side in [-1.0, 1.0]:
			_wall_seg(st, a + n * side, b + n * side, 0.5, 1.5, 0.15, Color("8a8478"))


func _rails() -> void:
	for r in data.rails:
		_strip(_st("ground"), r.line, 3.0, 0.04, Color("6b6258"))
		for side in [-0.72, 0.72]:
			var off := PackedVector2Array()
			for i in r.line.size():
				var a: Vector2 = r.line[maxi(i - 1, 0)]
				var b: Vector2 = r.line[mini(i + 1, r.line.size() - 1)]
				off.append(r.line[i] + (b - a).normalized().orthogonal() * side)
			_strip(_st("ground"), off, 0.12, 0.07, Color("3a3a3c"))


# ---------------------------------------------------------------- tường rào

func _walls() -> void:
	var st := _st("walls")
	for w in data.walls:
		var h := float(w.height)
		var t := 0.25
		var col := Color("c8beab")
		match str(w.kind):
			"fence":
				h = h if h > 0.0 else 1.6
				t = 0.08
				col = Color("4a4a48")
			"city_wall":
				h = h if h > 0.0 else 5.0
				t = 1.6
				col = Color("8f7f68")
			"retaining_wall":
				h = h if h > 0.0 else 1.2
			_:
				h = h if h > 0.0 else 2.2
		for i in w.line.size() - 1:
			_wall_seg(st, w.line[i], w.line[i + 1], 0.0, h, t, col)


## Một đoạn tường dày t từ a tới b, đáy y0, cao h.
static func _wall_seg(st: SurfaceTool, a: Vector2, b: Vector2, y0: float, h: float, t: float, col: Color) -> void:
	if a.distance_squared_to(b) < 0.0001:
		return
	var n := (b - a).normalized().orthogonal() * (t / 2.0)
	var q := [a + n, b + n, b - n, a - n]
	var top := y0 + h
	for i in 4:
		var p0: Vector2 = q[i]
		var p1: Vector2 = q[(i + 1) % 4]
		var nn := Vector3(p1.y - p0.y, 0, -(p1.x - p0.x)).normalized()
		var mid := (p0 + p1) / 2.0
		if Vector3(mid.x - (a.x + b.x) / 2.0, 0, mid.y - (a.y + b.y) / 2.0).dot(nn) < 0.0:
			nn = -nn
		_tri(st, _v(p0, y0), _v(p1, y0), _v(p1, top), nn, col)
		_tri(st, _v(p0, y0), _v(p1, top), _v(p0, top), nn, col)
	_tri(st, _v(q[0], top), _v(q[1], top), _v(q[2], top), Vector3.UP, col.lightened(0.08))
	_tri(st, _v(q[0], top), _v(q[2], top), _v(q[3], top), Vector3.UP, col.lightened(0.08))


# ---------------------------------------------------------------- nhà

func _buildings() -> void:
	var bc: Dictionary = cfg.get("buildings", {})
	var palette: Array = bc.get("walls", ["f1e3b8"])
	var lv: Array = bc.get("defaultLevels", [2, 5])
	var lh := float(bc.get("levelHeight", 3.2))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tanks := []
	for b in data.buildings:
		var poly: PackedVector2Array = b.poly
		if poly.size() < 3:
			continue
		var c := Geo.centroid(poly)
		var a := absf(Geo.area(poly))
		_rng.seed = hash(Vector2i(roundi(c.x * 10.0), roundi(c.y * 10.0)))
		var h := float(b.height)
		if h <= 0.0:
			if b.worship:
				h = 7.0
			elif a < 22.0:
				h = lh * _rng.randi_range(1, 2)
			else:
				h = lh * _rng.randi_range(int(lv[0]), int(lv[1])) + 0.4
		var base := float(b.min_height)
		var wall_col: Color = b.colour if b.colour != null else Color(str(palette[_rng.randi() % palette.size()]))
		if b.worship and b.colour == null:
			wall_col = Color(str(bc.get("worshipWall", "d9b56b")))
		var shape := str(b.roof_shape)
		if shape == "" and b.worship:
			shape = "hipped"
		var pitched := shape in ["gabled", "hipped", "pyramidal", "half-hipped", "gambrel", "mansard", "dome", "onion", "round", "skillion", "cone"]
		var roof_col: Color
		if b.roof_colour != null:
			roof_col = b.roof_colour
		elif b.worship:
			roof_col = Color(str(bc.get("worshipRoof", "6e2f22")))
		else:
			roof_col = Color(str(bc.get("pitchedRoof" if pitched else "flatRoof", "8e8a83")))
		var rh := 0.0
		var rect := {}
		if pitched:
			rect = _min_rect(poly)
			rh = float(b.roof_height) if float(b.roof_height) > 0.0 else minf(float(rect.short) * 0.38, 4.5)
			# Có ghi chiều cao tổng thì mái nằm trong chiều cao đó.
			if b.known and h - rh > base + 2.0:
				h -= rh
		_walls_of(st, poly, base, h, wall_col, not b.worship)
		if pitched and float(rect.fill) > 0.82 and shape in ["gabled", "hipped", "half-hipped", "gambrel", "mansard", "skillion"]:
			_rect_roof(st, rect, h, rh, roof_col, wall_col, shape == "gabled" or shape == "skillion")
		elif pitched:
			_pyramid(st, poly, c, h, rh, roof_col)
		else:
			_fill(st, poly, h, roof_col)
			# Bồn nước inox trên sân thượng: thứ thấy khắp phố Việt.
			if a > 28.0 and not b.worship and _rng.randf() < 0.45:
				var tp := c + Vector2(_rng.randf_range(-1.2, 1.2), _rng.randf_range(-1.2, 1.2))
				if Geometry2D.is_point_in_polygon(tp, poly):
					tanks.append(Vector3(tp.x, h, tp.y))
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = building_mat
	add_child(mi)
	_multimesh_tanks(tanks)
	_multimesh_trees()


## Tường quanh đường viền, từ y0 tới y1. UV.x là quãng đường dọc tường, UV.y là độ cao (để shader vẽ cửa sổ theo tầng).
func _walls_of(st: SurfaceTool, poly: PackedVector2Array, y0: float, y1: float, col: Color, windows := true) -> void:
	var c := Geo.centroid(poly)
	var run := 0.0
	# UV2.x = 1: shader vẽ cửa sổ theo tầng; chùa, đình để tường trơn.
	var uv2 := Vector2(1.0 if windows else 0.0, y1 - y0)
	for i in poly.size():
		var p0 := poly[i]
		var p1 := poly[(i + 1) % poly.size()]
		var l := p0.distance_to(p1)
		if l < 0.01:
			continue
		var nn := Vector3(p1.y - p0.y, 0, -(p1.x - p0.x)).normalized()
		var mid := (p0 + p1) / 2.0
		if Vector2(nn.x, nn.z).dot(mid - c) < 0.0:
			nn = -nn
		var shade := col.darkened(0.06) if absf(nn.x) > absf(nn.z) else col
		var u0 := Vector2(run, 0.0)
		var u1 := Vector2(run + l, 0.0)
		var hh := y1 - y0
		_tri(st, _v(p0, y0), _v(p1, y0), _v(p1, y1), nn, shade, [u0, u1, u1 + Vector2(0, hh)], uv2)
		_tri(st, _v(p0, y0), _v(p1, y1), _v(p0, y1), nn, shade, [u0, u1 + Vector2(0, hh), u0 + Vector2(0, hh)], uv2)
		run += l


## Hình chữ nhật nhỏ nhất bao đường viền: tâm, trục dài, cạnh dài, cạnh ngắn, độ lấp (diện tích nhà / diện tích hình).
static func _min_rect(poly: PackedVector2Array) -> Dictionary:
	var best := {}
	var best_a := INF
	for i in poly.size():
		var e := poly[(i + 1) % poly.size()] - poly[i]
		if e.length() < 0.3:
			continue
		var u := e.normalized()
		var v := u.orthogonal()
		var mnu := INF
		var mxu := -INF
		var mnv := INF
		var mxv := -INF
		for p in poly:
			mnu = minf(mnu, p.dot(u))
			mxu = maxf(mxu, p.dot(u))
			mnv = minf(mnv, p.dot(v))
			mxv = maxf(mxv, p.dot(v))
		var ar := (mxu - mnu) * (mxv - mnv)
		if ar < best_a:
			best_a = ar
			var center := u * (mnu + mxu) / 2.0 + v * (mnv + mxv) / 2.0
			if mxu - mnu >= mxv - mnv:
				best = {"c": center, "u": u, "long": mxu - mnu, "short": mxv - mnv}
			else:
				best = {"c": center, "u": v, "long": mxv - mnv, "short": mxu - mnu}
	if best.is_empty():
		return {"c": Geo.centroid(poly), "u": Vector2.RIGHT, "long": 1.0, "short": 1.0, "fill": 0.0}
	best["fill"] = absf(Geo.area(poly)) / maxf(best_a, 0.01)
	return best


## Mái trên hình chữ nhật: hai dốc (gable = true, hai đầu hồi xây tường) hoặc bốn dốc.
func _rect_roof(st: SurfaceTool, r: Dictionary, e: float, rh: float, roof: Color, wall: Color, gable: bool) -> void:
	var c: Vector2 = r.c
	var u: Vector2 = r.u
	var v := u.orthogonal()
	var L := float(r.long) / 2.0 + 0.3
	var S := float(r.short) / 2.0 + 0.3
	var A := _v(c - u * L - v * S, e)
	var B := _v(c + u * L - v * S, e)
	var C := _v(c + u * L + v * S, e)
	var D := _v(c - u * L + v * S, e)
	var ridge := L if gable else maxf(L - S, 0.0)
	var R1 := _v(c - u * ridge, e + rh)
	var R2 := _v(c + u * ridge, e + rh)
	for quad in [[A, B, R2, R1], [D, C, R2, R1]]:
		var n: Vector3 = (quad[1] - quad[0]).cross(quad[3] - quad[0]).normalized()
		if n.y < 0.0:
			n = -n
		_tri(st, quad[0], quad[1], quad[2], n, roof)
		_tri(st, quad[0], quad[2], quad[3], n, roof)
	for tri in [[A, D, R1], [B, C, R2]]:
		var n: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
		var out: Vector3 = tri[0] - _v(c, e)
		if n.dot(out) < 0.0:
			n = -n
		_tri(st, tri[0], tri[1], tri[2], n, wall if gable else roof)


## Mái chóp: mỗi cạnh một tam giác dồn về đỉnh giữa nhà.
func _pyramid(st: SurfaceTool, poly: PackedVector2Array, c: Vector2, e: float, rh: float, roof: Color) -> void:
	var apex := _v(c, e + rh)
	for i in poly.size():
		var a := _v(poly[i], e)
		var b := _v(poly[(i + 1) % poly.size()], e)
		var n := (b - a).cross(apex - a).normalized()
		if n.y < 0.0:
			n = -n
		_tri(st, a, b, apex, n, roof)


func _multimesh_tanks(tanks: Array) -> void:
	if tanks.is_empty():
		return
	var cm := CylinderMesh.new()
	cm.top_radius = 0.55
	cm.bottom_radius = 0.55
	cm.height = 1.3
	cm.radial_segments = 10
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("cfd3d8")
	m.metallic = 0.6
	m.roughness = 0.35
	cm.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cm
	mm.instance_count = tanks.size()
	for i in tanks.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, tanks[i] + Vector3(0, 0.65, 0)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)


func _multimesh_trees() -> void:
	if _trees.is_empty():
		return
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.15
	trunk.bottom_radius = 0.2
	trunk.height = 2.4
	trunk.material = _solid(Color("6b4f3a"))
	var crown := SphereMesh.new()
	crown.radius = 2.1
	crown.height = 3.4
	crown.radial_segments = 8
	crown.rings = 5
	crown.material = _solid(Color("4f7d3c"))
	for pair in [[trunk, 1.2], [crown, 3.6]]:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = pair[0]
		mm.instance_count = _trees.size()
		for i in _trees.size():
			var p: Vector2 = _trees[i]
			var s := 0.8 + fmod(absf(p.x * 13.1 + p.y * 7.7), 0.5)
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), Vector3(p.x, float(pair[1]) * s, p.y)))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		add_child(mmi)


static func _solid(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


# ---------------------------------------------------------------- nhãn tên

func _labels() -> void:
	var placed: Array[Vector2] = []
	# Tên đường nằm sát mặt đường, xoay theo hướng đường, đặt ở đoạn dài nhất.
	for r in data.roads:
		if str(r.name) == "" or r.small and float(r.width) < 3.0:
			continue
		var best := -1
		var best_l := 0.0
		for i in r.line.size() - 1:
			var l: float = r.line[i].distance_to(r.line[i + 1])
			if l > best_l and bounds.has_point((r.line[i] + r.line[i + 1]) / 2.0):
				best_l = l
				best = i
		if best < 0 or best_l < 18.0:
			continue
		var a: Vector2 = r.line[best]
		var b: Vector2 = r.line[best + 1]
		var mid := (a + b) / 2.0
		if placed.any(func(q: Vector2) -> bool: return q.distance_to(mid) < 40.0):
			continue
		placed.append(mid)
		var ang := atan2(b.y - a.y, b.x - a.x)
		if absf(ang) > PI / 2.0:
			ang += PI
		var l := _label(str(r.name), Vector3(mid.x, (0.5 if r.bridge else 0.08) + 0.03, mid.y), 64 if float(r.width) >= 7.0 else 44, false)
		l.rotation = Vector3(-PI / 2.0, -ang, 0)
		l.modulate = Color("fbf6e9")
	for w in data.water:
		if str(w.name) != "" and absf(Geo.area(w.poly)) > 300.0:
			_label(str(w.name), _v(Geo.centroid(w.poly), 1.5), 40, true).modulate = Color("cfe6ee")
	for w in data.waterways:
		if str(w.name) != "" and w.line.size() >= 2:
			var mid: Vector2 = w.line[w.line.size() / 2]
			if bounds.grow(-20).has_point(mid):
				_label(str(w.name), _v(mid, 1.5), 40, true).modulate = Color("cfe6ee")
	for p in data.parks:
		if str(p.name) != "":
			_label(str(p.name), _v(Geo.centroid(p.poly), 1.5), 34, true).modulate = Color("d9efc4")
	for p in data.pois:
		var col := Color("ffd27a") if str(p.kind) == "worship" else Color("f4c7a1")
		var icon := "卍 " if str(p.kind) == "worship" else "◆ "
		_label(icon + str(p.name), _v(p.pos, 9.0), 40, true).modulate = col


func _label(text: String, pos: Vector3, size: int, billboard: bool) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = font
	l.font_size = size
	l.pixel_size = 0.012
	l.outline_size = 10
	l.outline_modulate = Color(0.05, 0.05, 0.08, 0.85)
	l.position = pos
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
	add_child(l)
	labels.append(l)
	return l


# ---------------------------------------------------------------- lưới đi bộ

func _walk_grid() -> void:
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
