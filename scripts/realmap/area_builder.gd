extends Node3D
## Dựng 3D một khu thật từ area_data.gd. Mỗi loại (mặt đất, cỏ, nước, đường, nhà) gộp thành vài lưới lớn
## để chạy nhẹ cả trên trình duyệt với vài nghìn căn nhà:
## - Nhà: đùn đường viền lên theo chiều cao (height, số tầng; thiếu thì lấy 2–5 tầng như nhà ống), màu tường,
##   mái bằng, mái hai dốc, mái bốn dốc, mái chóp theo roof:shape; chùa, đình mái ngói bốn dốc. Mặt tường có ô cửa sổ
##   theo tầng. Nhà che An thì hạ nguyên căn xuống thành khối thấp có mặt cắt sáng (shader), cây che thì thu nhỏ.
## - Đường có vỉa hè, vạch giữa; ngõ nhỏ lát bê tông; cầu có lan can. Sông, hồ, kênh, công viên, sân bóng,
##   tường rào, đường sắt, nhãn tên đường, hồ, chùa, di tích.
## - Lưới đi bộ 1 m: không đi xuyên nhà, tường, mặt nước (trừ trên cầu).
## - Kiểu mô hình thu nhỏ: mọi thứ cắt theo vùng đã vẽ, đặt trên một tấm đế đất; cây (cây OSM, hàng cây, công viên,
##   ven đường), ô tô và xe máy đậu dọc đường, nhãn địa danh có chấm cam.

const Geo := preload("res://scripts/realmap/geo.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")
const WalkGrid := preload("res://scripts/realmap/walk_grid.gd")
const StreetDress := preload("res://scripts/realmap/street_dress.gd")
const Props3D := preload("res://scripts/world/props3d.gd")

const BUILDING_SHADER := """
shader_type spatial;
render_mode cull_disabled;
// Hạ nhà che An: mỗi căn một độ cao tối đa đọc từ ảnh caps (AreaBuilder.update_cut tính bên GDScript, hạ và nâng
// từ từ). Cả căn hạ một lượt, mái thành mặt cắt màu vữa sáng, không khoét lỗ giữa tường.
uniform bool cut_on = false;
uniform sampler2D caps : filter_nearest;
uniform int caps_w = 128;
// Màu mặt cắt của nhà bị hạ.
uniform vec3 cut_color;
// Cây: màu tint nhân độ sáng trong màu đỉnh (tán sáng trên sẫm dưới); cây đứng chắn trước An thì tán thu nhỏ lại,
// thân hạ còn gốc (INSTANCE_CUSTOM.r: 1 bình thường, 0 khi thu hẳn; .g: sắc lá riêng từng cây, 0..1).
// trunk: thân cây, lưới cao 2,4 m tâm ở giữa.
uniform bool flat_color = false;
uniform bool trunk = false;
uniform vec3 tint = vec3(1.0);
varying float v_cut;
varying float v_up;
varying float v_kind;
varying float v_var;

void vertex() {
	v_cut = 0.0;
	v_up = NORMAL.y;
	v_var = flat_color ? INSTANCE_CUSTOM.g : 0.5;
	// CUSTOM0: số thứ tự căn nhà, loại (1 nhà, 2 bồn nước trên mái). Mô hình khu đặt ở gốc tọa độ.
	v_kind = CUSTOM0.y;
	if (cut_on && trunk) {
		VERTEX.y = (VERTEX.y + 1.2) * max(INSTANCE_CUSTOM.r, 0.12) - 1.2;
	} else if (cut_on && flat_color) {
		VERTEX *= INSTANCE_CUSTOM.r;
	} else if (cut_on && CUSTOM0.y > 0.5) {
		int i = int(CUSTOM0.x + 0.5);
		float cap = texelFetch(caps, ivec2(i % caps_w, i / caps_w), 0).r;
		if (CUSTOM0.y > 1.5) {
			// Đồ gắn kèm (bồn nước, mái hiên, biển hiệu, cổng hẻm; UV2.y là đỉnh của món đồ): hạ thấp hơn đỉnh là ẩn.
			if (cap < UV2.y + 0.2) {
				VERTEX = vec3(0.0, -10.0, 0.0);
			}
		} else if (VERTEX.y > cap) {
			UV.y -= VERTEX.y - cap;
			VERTEX.y = cap;
			v_cut = 1.0;
		}
	}
}

void fragment() {
	vec3 col = flat_color ? tint * COLOR.rgb * mix(vec3(0.82, 0.86, 0.95), vec3(1.16, 1.12, 0.92), v_var) : COLOR.rgb;
	if (v_cut > 0.999 && v_up > 0.4) {
		// Mặt cắt của nhà bị hạ: sáng hơn mặt đường hẳn, nhìn ra ngay đâu là nhà, đâu là lối đi.
		col = mix(cut_color, col, 0.2);
	} else if (!flat_color && UV2.x > 0.5) {
		// Tường: vạch sàn mỗi tầng, ô cửa sổ kính tối, tầng trệt cửa cuốn rộng hơn.
		float fy = fract(UV.y / 3.2);
		float fx = fract(UV.x / 2.6);
		float floor_i = floor(UV.y / 3.2);
		bool win = fy > 0.32 && fy < 0.8 && fx > 0.22 && fx < 0.78 && floor_i >= 1.0 && UV.y < UV2.y - 0.6;
		bool door = floor_i < 1.0 && fy > 0.05 && fy < 0.72 && fx > 0.12 && fx < 0.88 && UV2.y > 4.0;
		// Nhìn xa (mỗi ô cửa chỉ còn vài điểm ảnh) thì mờ dần cửa sổ, tránh lấm tấm.
		float fw = max(fwidth(UV.x) / 2.6, fwidth(UV.y) / 3.2);
		float vis = 1.0 - smoothstep(0.12, 0.3, fw);
		if (win) col = mix(col, vec3(0.13, 0.17, 0.21), 0.78 * vis);
		if (door) col = mix(col, vec3(0.32, 0.31, 0.3), 0.6 * vis);
		if (fy < 0.05) col *= mix(1.0, 0.86, vis);
	}
	ALBEDO = col;
	ROUGHNESS = 0.88;
	if (v_kind > 1.5) {
		METALLIC = 0.6;
		ROUGHNESS = 0.35;
	}
}
"""
## Mặt cầu cao hơn mặt đường chừng này (màn phố nâng người đi trên cầu theo, xem real_city.ground_y).
const BRIDGE_Y := 0.5
## Hạ nhà che An (xem cut_target). near_w: nửa bề ngang dải ngay trước mặt An (bằng người); wide_w: dải rộng hai
## bên, hạ ít hơn wide_add mét; beside: căn trong dải rộng phải nằm hẳn phía nam An quá chừng này mới hạ; focus_r:
## khoảng trước mặt An luôn thấy mặt đường; stub: chân tường còn lại; speed: mét mỗi giây khi hạ, nâng; reach: xa nhất
## về phía nam còn phải xét.
const CUT := {"near_w": 0.45, "wide_w": 6.0, "wide_add": 2.0, "beside": 0.5, "focus_r": 2.5, "stub": 0.5, "speed": 30.0, "reach": 45.0}
## Màu mặt cắt của nhà bị hạ (vữa sáng).
const CUT_COLOR := Color(0.66, 0.62, 0.55)
## Giá trị trong ảnh caps nghĩa là căn để nguyên.
const CUT_NONE := 10000.0
const CUT_CELL := 10.0
const CAPS_W := 128
## Cây, xe đậu chia theo ô vuông này (mét) thành nhiều MultiMesh để ô nằm ngoài khung nhìn khỏi phải vẽ.
const TILE := 200.0

var data
var cfg: Dictionary
var font: Font
var building_mat: ShaderMaterial
var grid
var bounds := Rect2()
var labels: Array = []
var clip := PackedVector2Array()
## Đếm cho thẻ thông tin: nhà, cây, xe.
var counts := {"buildings": 0, "trees": 0, "cars": 0}
## Nhãn địa danh thật: tắt khi dùng làm map của truyện (truyện giữ tên hư cấu).
var show_labels := true
## Vật liệu riêng cho lớp mặt đất, đường (map của truyện dùng texture nhựa đường nhân với màu đỉnh); null là màu trơn.
var ground_material: Material = null
## Chỗ không trồng cây ven đường (cửa các địa điểm của truyện), và các vật liệu có cắt khoét quanh An để màn phố cập nhật.
var keep_clear: Array = []
## Màu nước (màn phố của truyện dùng màu kênh đục, sẫm hơn).
var water_color := Color("2b6a8f")
var cut_materials: Array = []
## Đồ phố Việt (street_dress.gd): đặt tùy chọn trước khi build (center, radius, label_radius, wires, name_of);
## để trống là không dựng.
var dress_opts := {}
var dress = null
var _flat := {}
var _rng := RandomNumberGenerator.new()


## clip: vùng đã vẽ (mét, cùng gốc với dữ liệu). walk: lưới đi bộ dựng sẵn (map của truyện), không có thì tự dựng.
func build(d, clip_poly: PackedVector2Array, walk = null) -> void:
	grid = walk
	data = d
	cfg = d.cfg
	clip = clip_poly
	bounds = Geo.bounds(clip)
	data.clip_to(clip)
	counts.buildings = data.buildings.size()
	font = UI.text_font()
	if not dress_opts.is_empty():
		dress = StreetDress.new(self, dress_opts)
	building_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = BUILDING_SHADER
	building_mat.shader = sh
	building_mat.set_shader_parameter("cut_color", CUT_COLOR)
	cut_materials.append(building_mat)
	_ground()
	_parks()
	_water()
	_roads()
	_rails()
	_walls()
	_buildings()
	if show_labels:
		_labels()
	_commit_flat()
	_walk_grid()
	_street_trees()
	_multimesh_trees()
	_vehicles()
	if dress != null:
		dress.streets()
		dress.finish()


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
		if key == "ground" and ground_material != null:
			mi.material_override = ground_material
			add_child(mi)
			continue
		if key == "water":
			m.roughness = 0.5
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
	for i in range(1, line.size() - 1):
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

## Tấm đế: mặt trên là vùng đã vẽ, bốn bề là lớp đất dày 4 m như mô hình sa bàn.
func _ground() -> void:
	_fill(_st("ground"), clip, 0.0, Color("a39c90"))
	var st := _st("walls")
	var c := Geo.centroid(clip)
	for i in clip.size():
		var a := clip[i]
		var b := clip[(i + 1) % clip.size()]
		var nn := Vector3(b.y - a.y, 0, -(b.x - a.x)).normalized()
		if Vector2(nn.x, nn.z).dot((a + b) / 2.0 - c) < 0.0:
			nn = -nn
		_tri(st, _v(a, 0.0), _v(b, 0.0), _v(b, -4.0), nn, Color("7d6a55"))
		_tri(st, _v(a, 0.0), _v(b, -4.0), _v(a, -4.0), nn, Color("7d6a55"))
		_tri(st, _v(a, 0.02), _v(b, 0.02), _v(b, -0.35), nn, Color("5f8a45"))
		_tri(st, _v(a, 0.02), _v(b, -0.35), _v(a, -0.35), nn, Color("5f8a45"))


func _parks() -> void:
	for p in data.parks:
		var col := Color("5a8442")
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
	var col := water_color
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
			y = BRIDGE_Y
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
	st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	for b in data.buildings:
		var poly: PackedVector2Array = b.poly
		if poly.size() < 3:
			continue
		var c := Geo.centroid(poly)
		var a := absf(Geo.area(poly))
		# Số thứ tự căn nhà cho shader hạ nhà: cả căn đọc chung một độ cao trong ảnh caps.
		var idx := _cut_polys.size()
		_cut_polys.append(poly)
		st.set_custom(0, Color(idx, 1.0, 0.0, 0.0))
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
		# Cao ốc từ 30 m: kính xanh xám.
		if b.colour == null and h >= 30.0:
			wall_col = Color(["5d7389", "4a5a6c", "7f8e9c", "d9dde2"][_rng.randi() % 4])
		if b.worship and b.colour == null:
			wall_col = Color(str(bc.get("worshipWall", "d9b56b")))
		var shape := str(b.roof_shape)
		if shape == "" and b.worship:
			shape = "hipped"
		# Nhà thấp nhỏ không ghi mái: một phần lợp ngói đỏ, như ảnh trên cao của phố Việt.
		var tiled := false
		if shape == "" and not b.known and a < 160.0 and h <= 13.5 and _rng.randf() < float(bc.get("tiledShare", 0.38)):
			shape = "gabled"
			tiled = true
		var pitched := shape in ["gabled", "hipped", "pyramidal", "half-hipped", "gambrel", "mansard", "dome", "onion", "round", "skillion", "cone"]
		var roof_col: Color
		if b.roof_colour != null:
			roof_col = b.roof_colour
		elif b.worship:
			roof_col = Color(str(bc.get("worshipRoof", "6e2f22")))
		elif tiled:
			var tiles: Array = bc.get("tileRoofs", ["b5432f"])
			roof_col = Color(str(tiles[_rng.randi() % tiles.size()]))
		elif pitched:
			roof_col = Color(str(bc.get("pitchedRoof", "a5523a")))
		else:
			# Mái bằng: xám bê tông nhiều sắc, hay sẫm theo màu tường.
			var flats := [Color("8a857d"), Color("77736c"), Color("9c9486"), Color("6c6a66"), wall_col.darkened(0.3)]
			roof_col = flats[_rng.randi() % flats.size()]
		var rh := 0.0
		var rect := {}
		if pitched:
			rect = _min_rect(poly)
			rh = float(b.roof_height) if float(b.roof_height) > 0.0 else minf(float(rect.short) * 0.38, 4.5)
			# Có ghi chiều cao tổng thì mái nằm trong chiều cao đó.
			if b.known and h - rh > base + 2.0:
				h -= rh
		_cut_tops.append(h + rh)
		_walls_of(st, poly, base, h, wall_col, not b.worship)
		if pitched and float(rect.fill) > 0.82 and shape in ["gabled", "hipped", "half-hipped", "gambrel", "mansard", "skillion"]:
			_rect_roof(st, rect, h, rh, roof_col, wall_col, shape == "gabled" or shape == "skillion")
		elif pitched:
			_pyramid(st, poly, c, h, rh, roof_col)
		else:
			_fill(st, poly, h, roof_col)
			# Bồn nước inox trên sân thượng: thứ thấy khắp phố Việt. Gộp vào lưới nhà để hạ nhà thì bồn ẩn theo.
			if a > 28.0 and not b.worship and _rng.randf() < 0.45:
				var tp := c + Vector2(_rng.randf_range(-1.2, 1.2), _rng.randf_range(-1.2, 1.2))
				if Geometry2D.is_point_in_polygon(tp, poly):
					st.set_custom(0, Color(idx, 2.0, 0.0, 0.0))
					_tank(st, tp, h)
		if dress != null:
			dress.front(st, idx, poly, base, h)
	if dress != null:
		dress.gates(st)
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = building_mat
	add_child(mi)
	# Lưới ô tìm căn gần An, ảnh caps (mỗi căn một điểm ảnh) cho shader.
	for i in _cut_polys.size():
		var r := Geo.bounds(_cut_polys[i])
		for gx in range(floori(r.position.x / CUT_CELL), floori(r.end.x / CUT_CELL) + 1):
			for gz in range(floori(r.position.y / CUT_CELL), floori(r.end.y / CUT_CELL) + 1):
				var k := Vector2i(gx, gz)
				if not _cut_cells.has(k):
					_cut_cells[k] = PackedInt32Array()
				_cut_cells[k].append(i)
	_cut_img = Image.create(CAPS_W, maxi(1, ceili(_cut_polys.size() / float(CAPS_W))), false, Image.FORMAT_RF)
	_cut_img.fill(Color(CUT_NONE, 0, 0))
	_cut_tex = ImageTexture.create_from_image(_cut_img)
	building_mat.set_shader_parameter("caps", _cut_tex)
	building_mat.set_shader_parameter("caps_w", CAPS_W)


## Bồn nước inox đứng trên mái ở độ cao y (UV2.y giữ đỉnh bồn để shader biết khi nào ẩn bồn).
static func _tank(st: SurfaceTool, p: Vector2, y: float) -> void:
	var col := Color("cfd3d8")
	var r := 0.55
	var top := y + 1.3
	var uv2 := Vector2(0.0, top)
	var none := [Vector2.ZERO, Vector2.ZERO, Vector2.ZERO]
	for k in 10:
		var a0 := TAU * k / 10.0
		var a1 := TAU * (k + 1) / 10.0
		var p0 := p + Vector2(cos(a0), sin(a0)) * r
		var p1 := p + Vector2(cos(a1), sin(a1)) * r
		var n := Vector3(cos((a0 + a1) / 2.0), 0, sin((a0 + a1) / 2.0))
		_tri(st, _v(p0, y), _v(p1, y), _v(p1, top), n, col, none, uv2)
		_tri(st, _v(p0, y), _v(p1, top), _v(p0, top), n, col, none, uv2)
		_tri(st, _v(p, top), _v(p0, top), _v(p1, top), Vector3.UP, col.lightened(0.1), none, uv2)


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


# ---------------------------------------------------------------- hạ nhà che An

## Footprint, đỉnh (tính cả mái) của từng căn theo số thứ tự trong lưới nhà; lưới ô CUT_CELL mét để tìm căn gần An;
## độ cao hiện tại của các căn đang hạ; ảnh caps gửi cho shader. Cây: bán kính tán, lưới ô, độ to hiện tại của tán.
var _cut_polys: Array = []
var _cut_tops := PackedFloat32Array()
var _cut_cells := {}
var _cut_now := {}
var _cut_img: Image
var _cut_tex: ImageTexture
var _cut_labels := {}
## Cây chia theo ô TILE mét, mỗi ô một MultiMesh tán, một MultiMesh thân (ô ngoài tầm nhìn thì khỏi vẽ); _tree_slot[i]:
## (ô, chỗ trong ô) của cây thứ i.
var _crown_mms: Array = []
var _trunk_mms: Array = []
var _tree_slot: Array = []
var _tree_r := PackedFloat32Array()
var _tree_var := PackedFloat32Array()
var _tree_cells := {}
var _crown_now := {}


## Thêm một ô trong ảnh caps cho đồ dựng kèm nhà (mái hiên, cổng hẻm) có đường viền và đỉnh riêng.
func _cut_add(poly: PackedVector2Array, top: float) -> int:
	_cut_polys.append(poly)
	_cut_tops.append(top)
	return _cut_polys.size() - 1


## Chữ gắn với ô idx (biển hiệu theo nhà, chữ cổng hẻm theo cổng): ẩn khi ô hạ thấp hơn thr mét (đỉnh món đồ).
func _cut_label(idx: int, label: Label3D, thr: float) -> void:
	if not _cut_labels.has(idx):
		_cut_labels[idx] = []
	_cut_labels[idx].append([label, thr])


## Độ cao tối đa của một căn (đường viền poly) để không che An đứng ở p; slope là tia nhìn lên bao nhiêu mét cho mỗi
## mét lùi về phía nam (camera nhìn về hướng bắc). INF: không phải hạ.
## - Dải hẹp ngay trước mặt An (rộng bằng người): căn nào chạm dải ở phía nam An thì hạ, sát An còn chân tường,
##   càng xa về phía camera càng được cao.
## - Dải rộng hai bên cho thấy mặt phố quanh An: chỉ hạ căn nằm hẳn phía nam An (căn đứng ngang An, như chính căn
##   An đang đứng trước cửa, để nguyên), hạ ít hơn dải hẹp.
static func cut_target(poly: PackedVector2Array, p: Vector2, slope: float) -> float:
	var best := INF
	var zr := _strip_z(poly, p.x - CUT.near_w, p.x + CUT.near_w)
	if zr.y > p.y:
		best = CUT.stub + maxf(zr.x - p.y - CUT.focus_r, 0.0) * slope
	zr = _strip_z(poly, p.x - CUT.wide_w, p.x + CUT.wide_w)
	if zr.x < INF and zr.x > p.y + CUT.beside:
		best = minf(best, CUT.stub + CUT.wide_add + maxf(zr.x - p.y - CUT.focus_r, 0.0) * slope)
	return best


## Khoảng z (nhỏ nhất, lớn nhất) của phần đa giác nằm trong dải x0 ≤ x ≤ x1; (INF, -INF) nếu không chạm.
## Chỗ cao nhất, thấp nhất của phần giao luôn nằm trên một cạnh đa giác (đã cắt theo dải), nên chỉ cần xét các cạnh.
static func _strip_z(poly: PackedVector2Array, x0: float, x1: float) -> Vector2:
	var lo := INF
	var hi := -INF
	var n := poly.size()
	for i in n:
		var a := poly[i]
		var b := poly[(i + 1) % n]
		if (a.x < x0 and b.x < x0) or (a.x > x1 and b.x > x1):
			continue
		var t0 := 0.0
		var t1 := 1.0
		var dx := b.x - a.x
		if absf(dx) > 1e-6:
			var ta := (x0 - a.x) / dx
			var tb := (x1 - a.x) / dx
			t0 = maxf(0.0, minf(ta, tb))
			t1 = minf(1.0, maxf(ta, tb))
			if t0 > t1:
				continue
		var za := a.y + (b.y - a.y) * t0
		var zb := a.y + (b.y - a.y) * t1
		lo = minf(lo, minf(za, zb))
		hi = maxf(hi, maxf(za, zb))
	return Vector2(lo, hi)


## Mỗi khung hình ở màn phố: căn nào che An (cut_target) thì hạ dần xuống, hết che thì nâng dần lên lại; tán cây chắn
## trước An thu nhỏ dần. p: chỗ An đứng (x, z).
func update_cut(p: Vector2, slope: float, delta: float) -> void:
	if _cut_img == null:
		return
	var cells := _cells_near(p)
	var want := {}
	var seen := {}
	for k in cells:
		for i in _cut_cells.get(k, PackedInt32Array()):
			if seen.has(i):
				continue
			seen[i] = true
			var t := cut_target(_cut_polys[i], p, slope)
			if t < _cut_tops[i]:
				want[i] = t
				if not _cut_now.has(i):
					_cut_now[i] = _cut_tops[i]
	var changed := false
	for i in _cut_now.keys():
		var top: float = _cut_tops[i]
		var was := float(_cut_now[i])
		var cur := move_toward(was, float(want.get(i, top)), float(CUT.speed) * delta)
		if cur == was and want.has(i):
			continue
		changed = true
		if cur >= top and not want.has(i):
			_cut_now.erase(i)
			_cut_img.set_pixel(i % CAPS_W, i / CAPS_W, Color(CUT_NONE, 0, 0))
			cur = CUT_NONE
		else:
			_cut_now[i] = cur
			_cut_img.set_pixel(i % CAPS_W, i / CAPS_W, Color(cur, 0, 0))
		for lb in _cut_labels.get(i, []):
			(lb[0] as Label3D).visible = cur >= float(lb[1])
	if changed:
		_cut_tex.update(_cut_img)
	_update_crowns(cells, p, slope, delta)


## Tán cây: coi như một khối vuông bằng tán; che An (theo cut_target) thì thu nhỏ hẳn, hết che thì to lại.
func _update_crowns(cells: Array, p: Vector2, slope: float, delta: float) -> void:
	if _crown_mms.is_empty():
		return
	var want := {}
	for k in cells:
		for i in _tree_cells.get(k, PackedInt32Array()):
			if want.has(i):
				continue
			var o: Vector2 = _trees[i]
			var r: float = _tree_r[i]
			var sq := PackedVector2Array([o + Vector2(-r, -r), o + Vector2(r, -r), o + Vector2(r, r), o + Vector2(-r, r)])
			# Ngọn tán cao chừng 2,5 lần bán kính: phải hạ thấp hơn thế là tán chắn tầm nhìn.
			if cut_target(sq, p, slope) < r * 2.5:
				want[i] = true
				if not _crown_now.has(i):
					_crown_now[i] = 1.0
	for i in _crown_now.keys():
		var cur := move_toward(float(_crown_now[i]), 0.0 if want.has(i) else 1.0, 5.0 * delta)
		if cur >= 1.0 and not want.has(i):
			_crown_now.erase(i)
		else:
			_crown_now[i] = cur
		_tree_size(i, cur)


## Các ô lưới có thể có căn che An: hai bên An một dải rộng, từ ngang An về phía nam tới reach mét.
func _cells_near(p: Vector2) -> Array:
	var out := []
	for gx in range(floori((p.x - CUT.wide_w - 1.0) / CUT_CELL), floori((p.x + CUT.wide_w + 1.0) / CUT_CELL) + 1):
		for gz in range(floori((p.y - 1.0) / CUT_CELL), floori((p.y + CUT.reach) / CUT_CELL) + 1):
			out.append(Vector2i(gx, gz))
	return out


## Thôi hạ nhà (rời chế độ đi dạo): mọi căn, mọi tán cây về như cũ.
func reset_cut() -> void:
	if _cut_img == null:
		return
	_cut_now.clear()
	_cut_img.fill(Color(CUT_NONE, 0, 0))
	_cut_tex.update(_cut_img)
	for i in _cut_labels:
		for lb in _cut_labels[i]:
			(lb[0] as Label3D).visible = true
	for i in _crown_now:
		_tree_size(i, 1.0)
	_crown_now.clear()


func _multimesh_trees() -> void:
	if _trees.is_empty():
		return
	var trunk := Props3D.trunk()
	var bark := ShaderMaterial.new()
	bark.shader = building_mat.shader
	bark.set_shader_parameter("flat_color", true)
	bark.set_shader_parameter("trunk", true)
	bark.set_shader_parameter("tint", Color("6b4f3a"))
	cut_materials.append(bark)
	var crown := Props3D.crown()
	var leaf := ShaderMaterial.new()
	leaf.shader = building_mat.shader
	leaf.set_shader_parameter("flat_color", true)
	leaf.set_shader_parameter("tint", Color("4f7d3c"))
	cut_materials.append(leaf)
	_tree_slot.resize(_trees.size())
	for i in _trees.size():
		var p: Vector2 = _trees[i]
		_tree_var.append(fposmod(p.x * 0.731 + p.y * 1.37, 1.0))
	var tiles := _tiles(_trees)
	for key in tiles:
		var ids: PackedInt32Array = tiles[key]
		for pair in [[trunk, 1.2, bark, _trunk_mms], [crown, 3.6, leaf, _crown_mms]]:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			# INSTANCE_CUSTOM.r là độ to của cây (1 bình thường, 0 khi thu hẳn vì chắn trước An), .g là sắc lá. Màu
			# instance trắng: bản Compatibility (web) nhân màu đỉnh với màu instance, thiếu thì thành đen.
			mm.use_custom_data = true
			mm.use_colors = true
			mm.mesh = pair[0]
			mm.instance_count = ids.size()
			for j in ids.size():
				var i := ids[j]
				var p: Vector2 = _trees[i]
				var s := 0.8 + fmod(absf(p.x * 13.1 + p.y * 7.7), 0.5)
				var yaw := fmod(absf(p.x * 3.7 - p.y * 5.3), TAU)
				mm.set_instance_transform(j, Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), Vector3(p.x, float(pair[1]) * s, p.y)))
				mm.set_instance_custom_data(j, Color(1, _tree_var[i], 0, 0))
				mm.set_instance_color(j, Color.WHITE)
				_tree_slot[i] = Vector2i(pair[3].size(), j)
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.material_override = pair[2]
			add_child(mmi)
			pair[3].append(mm)
	for i in _trees.size():
		var p: Vector2 = _trees[i]
		var r := 2.1 * (0.8 + fmod(absf(p.x * 13.1 + p.y * 7.7), 0.5))
		_tree_r.append(r)
		for gx in range(floori((p.x - r) / CUT_CELL), floori((p.x + r) / CUT_CELL) + 1):
			for gz in range(floori((p.y - r) / CUT_CELL), floori((p.y + r) / CUT_CELL) + 1):
				var c := Vector2i(gx, gz)
				if not _tree_cells.has(c):
					_tree_cells[c] = PackedInt32Array()
				_tree_cells[c].append(i)


## Độ to của cây thứ i (1 bình thường, 0 thu hẳn) cho shader tán, thân.
func _tree_size(i: int, v: float) -> void:
	var slot: Vector2i = _tree_slot[i]
	var c := Color(v, _tree_var[i], 0, 0)
	(_crown_mms[slot.x] as MultiMesh).set_instance_custom_data(slot.y, c)
	(_trunk_mms[slot.x] as MultiMesh).set_instance_custom_data(slot.y, c)


## Chia các điểm theo ô TILE mét: {ô: các chỉ số điểm trong ô}.
static func _tiles(points: Array) -> Dictionary:
	var out := {}
	for i in points.size():
		var p: Vector2 = points[i]
		var k := Vector2i(floori(p.x / TILE), floori(p.y / TILE))
		if not out.has(k):
			out[k] = PackedInt32Array()
		out[k].append(i)
	return out


static func _solid(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


# ---------------------------------------------------------------- nhãn tên

func _labels() -> void:
	# Chỉ ghi tên địa danh (đền, chùa, di tích, điểm tham quan, tòa nhà lớn có tên), tối đa 14 cái, không chồng nhau.
	var placed: Array[Vector2] = []
	var order: Array = data.pois.duplicate()
	order.sort_custom(func(a, b) -> bool: return int(a.get("rank", 1)) > int(b.get("rank", 1)))
	for p in order:
		if placed.size() >= 9 or placed.any(func(q: Vector2) -> bool: return q.distance_to(p.pos) < 90.0):
			continue
		placed.append(p.pos)
		var h := float(p.get("height", 8.0))
		var l := _label(str(p.name), _v(p.pos, h + 6.0), 26, true)
		l.modulate = Color("fbf6e9")
		var dot := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.6
		sm.height = 3.2
		dot.mesh = sm
		dot.material_override = _solid(Color("ff7a45"))
		dot.position = _v(p.pos, h + 1.5)
		add_child(dot)


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
		l.fixed_size = true
		l.pixel_size = 0.00042
		l.outline_size = 7
	add_child(l)
	labels.append(l)
	return l


# ---------------------------------------------------------------- cây, xe

## Cây ven đường (mỗi 13 m, hai bên, chỗ không vướng nhà hay nước), cây OSM và hàng cây OSM.
func _street_trees() -> void:
	_rng.seed = 77
	for t in data.trees:
		_trees.append(t)
	for r in data.tree_rows:
		_along(r.line, 7.0, func(p: Vector2, _d: Vector2) -> void: _trees.append(p))
	for r in data.roads:
		if r.small or r.bridge or float(r.width) < 6.0:
			continue
		var off := float(r.width) / 2.0 + 1.3
		_along(r.line, 13.0, func(p: Vector2, d: Vector2) -> void:
			for side in [-1.0, 1.0]:
				var q: Vector2 = p + d.orthogonal() * off * side
				if _rng.randf() < 0.6 and walkable(q) and not _in_water(q) and Geometry2D.is_point_in_polygon(q, clip) \
						and not keep_clear.any(func(k: Vector2) -> bool: return k.distance_to(q) < 7.0):
					_trees.append(q))
	counts.trees = _trees.size()


## Gọi f(điểm, hướng) đều đặn mỗi step mét dọc đường gấp khúc.
static func _along(line: PackedVector2Array, step: float, f: Callable) -> void:
	var carry := step / 2.0
	for i in line.size() - 1:
		var a := line[i]
		var b := line[i + 1]
		var l := a.distance_to(b)
		if l < 0.01:
			continue
		var d := (b - a) / l
		var s := carry
		while s < l:
			f.call(a + d * s, d)
			s += step
		carry = s - l


## Ô tô đậu dọc đường lớn (từ 8 m), xe máy dựng sát vỉa hè đường nhỏ: xe dựng bằng code (props3d.gd), nhiều màu.
func _vehicles() -> void:
	_rng.seed = 531
	var cars: Array = []
	var bikes: Array = []
	for r in data.roads:
		if r.bridge or r.tunnel or str(r.kind) in ["footway", "path", "steps", "cycleway"]:
			continue
		var w := float(r.width)
		_along(r.line, 9.0 if w >= 6.0 else 6.0, func(p: Vector2, d: Vector2) -> void:
			var side := -1.0 if _rng.randf() < 0.5 else 1.0
			if w >= 8.0 and _rng.randf() < 0.32:
				var q: Vector2 = p + d.orthogonal() * (w / 2.0 - 1.4) * side
				if Geometry2D.is_point_in_polygon(q, clip) and walkable(q):
					cars.append([q, d])
			elif _rng.randf() < 0.25:
				var q: Vector2 = p + d.orthogonal() * (w / 2.0 - 0.5) * side
				# Mép đường lấn vào nền nhà (nhà vẽ sát đường) thì thôi, khỏi có xe nằm trong nhà.
				if Geometry2D.is_point_in_polygon(q, clip) and walkable(q):
					bikes.append([q, d.orthogonal()]))
	# Ô tô, xe máy (tay ga, xe số xen nhau, bản nhẹ) dựng bằng code (props3d.gd), mỗi chiếc một màu sơn.
	_vehicle_mm(cars, Props3D.car(), [Color("e8e6e1"), Color("2b2d33"), Color("b23a32"), Color("3a6ea5"), Color("c9ccd1"), Color("e0b23c"), Color("5a7d4f")])
	var kinds := [[], []]
	for i in bikes.size():
		kinds[1 if i % 3 == 2 else 0].append(bikes[i])
	var bike_palette := [Color("b23a32"), Color("2b2d33"), Color("e8e6e1"), Color("3a6ea5"), Color("c9ccd1"), Color("7a2a3a"), Color("e0b23c")]
	_vehicle_mm(kinds[0], Props3D.motorbike("tay_ga", false), bike_palette)
	_vehicle_mm(kinds[1], Props3D.motorbike("xe_so", false), bike_palette)
	counts.cars = cars.size() + bikes.size()


## Một loại xe đậu thành một MultiMesh: [chỗ, hướng đầu xe] mỗi chiếc, màu sơn theo bảng xoay vòng; xe máy chiếc
## chẵn chiếc lẻ quay đầu ngược nhau.
func _vehicle_mm(items: Array, mesh: Mesh, palette: Array) -> void:
	var tiles := _tiles(items.map(func(it: Array) -> Vector2: return it[0]))
	for key in tiles:
		var ids: PackedInt32Array = tiles[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		# Màu sơn ở custom data; màu instance trắng (xem _multimesh_trees).
		mm.use_custom_data = true
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = ids.size()
		for j in ids.size():
			var i := ids[j]
			var p: Vector2 = items[i][0]
			var d: Vector2 = items[i][1]
			var yaw := atan2(d.x, d.y) + (PI if i % 2 == 1 else 0.0)
			mm.set_instance_transform(j, Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, 0.0, p.y)))
			mm.set_instance_custom_data(j, palette[i % palette.size()])
			mm.set_instance_color(j, Color.WHITE)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = Props3D.instanced_material()
		add_child(mmi)


# ---------------------------------------------------------------- lưới đi bộ

func _walk_grid() -> void:
	if grid == null:
		grid = WalkGrid.new(data, bounds)


func walkable(p: Vector2) -> bool:
	return grid.walkable(p)


func nearest_walkable(p: Vector2) -> Vector2:
	return grid.nearest_walkable(p)


func path(a: Vector2, b: Vector2) -> PackedVector2Array:
	return grid.path(a, b)
