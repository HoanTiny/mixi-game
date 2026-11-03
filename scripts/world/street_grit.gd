extends Node3D
## Chi tiết đường phố kiểu "Nobody" (dựng một lần sau khi area_builder dựng xong phố của truyện):
##   - Vết bẩn (grunge): vũng nước đọng, lá rơi, vết dầu, rác vụn, vết nứt lớn. Mặt phẳng nằm sát mặt đất, MultiMesh một
##     lần vẽ; kiểu và hạt giống trong INSTANCE_CUSTOM, hình vẽ bằng shader (không cần ảnh, nhẹ cho bản web).
##     Bản Compatibility (web) không có node Decal nên dùng mặt phẳng trong suốt.
##   - Đồ phố dọc vỉa hè trước cửa nhà: thùng rác xanh 240 lít, biển quảng cáo đứng chữ A (vài biển có chữ), hàng xe máy
##     dựng, bàn ghế nhựa quán nước, xe hàng rong. Đặt sát chân nhà (mép trong vỉa hè) để chừa lối đi; tránh cửa các
##     địa điểm của truyện (area.keep_clear). Có viền mực và bóng chân (ink.gd).
## Chỉ dựng trong vòng RADIUS mét quanh tâm các địa điểm (area.dress.center) cho nhẹ máy.

const AreaData := preload("res://scripts/realmap/area_data.gd")
const AreaBuilder := preload("res://scripts/realmap/area_builder.gd")
const Props3D := preload("res://scripts/world/props3d.gd")
const Ink := preload("res://scripts/world/ink.gd")
const UI := preload("res://scripts/ui/ui_kit.gd")

const RADIUS := 230.0
## Độ cao vết bẩn: trên mặt đường (0,05), vạch sơn (0,055).
const DECAL_Y := 0.068
const BOARD_TEXTS := ["CƠM BÌNH DÂN", "SỬA XE", "PHỞ BÒ", "CẮT TÓC", "NƯỚC MÍA", "BÚN CHẢ", "KARAOKE", "NHẬN SỬA ĐIỆN THOẠI",
	"TRÀ ĐÁ", "BÁNH MÌ", "PHÔ TÔ", "CHO THUÊ PHÒNG", "VÁ XE", "CÀ PHÊ", "GIẶT LÀ"]
const BOARD_COLORS := ["c0392b", "e8b52e", "2f6db5", "2e8b57", "e67e22", "f2f2ee", "8e44ad"]

const DECAL_SHADER := """
shader_type spatial;
render_mode depth_draw_never, cull_disabled, shadows_disabled;
// INSTANCE_CUSTOM.r: kiểu (0 vũng nước, 1 lá rơi, 2 vết dầu, 3 rác vụn, 4 vết nứt); .g: hạt giống.
varying float v_kind;
varying float v_seed;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() {
	v_kind = INSTANCE_CUSTOM.r;
	v_seed = INSTANCE_CUSTOM.g * 97.0;
}
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	vec3 col = vec3(0.0);
	float a = 0.0;
	float rough = 0.95;
	float spec = 0.3;
	if (v_kind < 0.5) {
		// Vũng nước: mép loang méo, mặt nước sẫm bóng phản trời.
		float edge = 0.62 + 0.28 * (vnoise(p * 2.6 + v_seed) - 0.5) * 2.0;
		a = (1.0 - smoothstep(edge - 0.08, edge, r)) * 0.82;
		col = vec3(0.07, 0.08, 0.09);
		rough = 0.04;
		spec = 0.9;
	} else if (v_kind < 1.5) {
		// Lá rơi: vài chiếc lá bầu dục xoay ngẫu nhiên, vàng úa, nâu, cam.
		for (int i = 0; i < 9; i++) {
			float fi = float(i);
			vec2 c = vec2(hash(vec2(fi, v_seed)), hash(vec2(v_seed, fi))) * 1.5 - 0.75;
			float ang = hash(vec2(fi * 3.1, v_seed)) * 6.283;
			vec2 d = p - c;
			d = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang))) * d;
			float leaf = length(d / vec2(0.16, 0.07));
			if (leaf < 1.0) {
				float t = hash(vec2(fi, v_seed + 2.0));
				col = mix(vec3(0.55, 0.36, 0.1), mix(vec3(0.62, 0.48, 0.16), vec3(0.42, 0.22, 0.1), step(0.5, t)), t);
				col *= 0.8 + 0.25 * step(abs(d.y), 0.012);
				a = 1.0;
			}
		}
	} else if (v_kind < 2.5) {
		// Vết dầu, nước bẩn: loang mềm màu nâu đen.
		float n = vnoise(p * 3.0 + v_seed);
		a = (1.0 - smoothstep(0.35, 1.0, r + (n - 0.5) * 0.5)) * 0.6;
		col = vec3(0.05, 0.04, 0.03);
		rough = 0.35;
	} else if (v_kind < 3.5) {
		// Rác vụn: mẩu giấy, túi ni lông, nắp chai.
		for (int i = 0; i < 6; i++) {
			float fi = float(i);
			vec2 c = vec2(hash(vec2(fi + 7.0, v_seed)), hash(vec2(v_seed, fi + 7.0))) * 1.5 - 0.75;
			vec2 d = abs(p - c);
			float k = hash(vec2(fi, v_seed + 5.0));
			vec2 sz = k < 0.6 ? vec2(0.1, 0.07) : vec2(0.035);
			if (d.x < sz.x && d.y < sz.y) {
				col = k < 0.3 ? vec3(0.82, 0.8, 0.74) : (k < 0.6 ? vec3(0.55, 0.62, 0.7) : vec3(0.7, 0.12, 0.1));
				a = 0.95;
			}
		}
	} else {
		// Vết nứt lớn: đường gãy đen chạy ngang tấm.
		float y = (vnoise(vec2(p.x * 3.0, v_seed)) - 0.5) * 0.8;
		float br = (vnoise(vec2(p.x * 7.0 + 3.0, v_seed)) - 0.5) * 0.3;
		float line = min(abs(p.y - y), abs(p.y - y - br - 0.25) + step(0.2, abs(p.x - 0.2)));
		a = (1.0 - smoothstep(0.0, 0.03, line)) * (1.0 - smoothstep(0.7, 1.0, abs(p.x))) * 0.9;
		col = vec3(0.03, 0.025, 0.02);
	}
	if (a < 0.01) discard;
	ALBEDO = col;
	ALPHA = a;
	ROUGHNESS = rough;
	SPECULAR = spec;
}
"""

var _rng := RandomNumberGenerator.new()
var _decals: Array = []
var _bins: Array = []
var _boards: Array = []
var _bikes: Array = []
var _stools: Array = []
var _carts: Array = []
var counts := {}


func build(w) -> void:
	_rng.seed = 4242
	var area = w.area
	var center: Vector2 = area.dress.center if area.dress != null else Vector2.ZERO
	var keep: Array = area.keep_clear
	for r in w.city.data.roads:
		if r.tunnel or r.bridge or r.line.size() < 2:
			continue
		var width := float(r.width)
		var hw := width / 2.0
		var sw: float = AreaData.sidewalk(r) if not r.small else 0.0
		AreaBuilder._along(r.line, 3.2, func(p: Vector2, d: Vector2) -> void:
			if p.distance_to(center) > RADIUS:
				return
			var n := d.orthogonal()
			# Vết bẩn trên lòng đường: dầu, vết nứt, vũng nước sát rãnh biên.
			if _rng.randf() < 0.35:
				var off := _rng.randf_range(-hw * 0.7, hw * 0.7)
				_decal(p + n * off, 2 if _rng.randf() < 0.6 else 4, _rng.randf_range(0.6, 1.4), d)
			if width >= 4.5 and _rng.randf() < 0.18:
				var side := -1.0 if _rng.randf() < 0.5 else 1.0
				_decal(p + n * side * (hw - 0.35), 0, _rng.randf_range(0.5, 1.1), d)
			if sw <= 0.0:
				if r.small and _rng.randf() < 0.25:
					_decal(p + n * _rng.randf_range(-hw * 0.6, hw * 0.6), [1, 3, 2][_rng.randi() % 3], _rng.randf_range(0.4, 0.8), d)
				return
			for side in [-1.0, 1.0]:
				var q: Vector2 = p + n * side * (hw + _rng.randf_range(0.3, sw))
				var roll := _rng.randf()
				if roll < 0.18:
					_decal(q, 1, _rng.randf_range(0.5, 0.9), d)
				elif roll < 0.3:
					_decal(q, 3, _rng.randf_range(0.4, 0.7), d)
				elif roll < 0.38:
					_decal(q, 2, _rng.randf_range(0.4, 0.8), d)
				elif roll < 0.43:
					_decal(q, 4, _rng.randf_range(0.6, 1.0), d)
		)
		if sw > 0.8:
			_props_along(r, hw, sw, center, keep)
	_finish(w)


func _decal(p: Vector2, kind: int, size: float, d: Vector2) -> void:
	var yaw := atan2(d.x, d.y) + _rng.randf_range(-0.6, 0.6)
	var b := Basis(Vector3.UP, yaw).scaled(Vector3(size, 1.0, size * (1.0 if kind != 4 else 0.45)))
	_decals.append([Transform3D(b, Vector3(p.x, DECAL_Y + float(kind) * 0.0004, p.y)), kind])


## Đồ phố mép trong vỉa hè (sát chân nhà), cứ chừng 9–16 m một cụm.
func _props_along(r, hw: float, sw: float, center: Vector2, keep: Array) -> void:
	var step := _rng.randf_range(9.0, 16.0)
	AreaBuilder._along(r.line, step, func(p: Vector2, d: Vector2) -> void:
		if p.distance_to(center) > RADIUS:
			return
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var n: Vector2 = d.orthogonal() * side
		var q: Vector2 = p + n * (hw + sw - 0.45)
		if keep.any(func(k: Vector2) -> bool: return k.distance_to(q) < 4.0):
			return
		# Hướng quay ra đường: +z của đồ vật nhìn về phía lòng đường (-n).
		var face := atan2(-n.x, -n.y)
		var roll := _rng.randf()
		if roll < 0.22:
			_bins.append(Transform3D(Basis(Vector3.UP, face + _rng.randf_range(-0.3, 0.3)), Vector3(q.x, 0.05, q.y)))
		elif roll < 0.42:
			_boards.append([Transform3D(Basis(Vector3.UP, face + PI * 0.5 + _rng.randf_range(-0.25, 0.25)), Vector3(q.x, 0.05, q.y)),
				Color(BOARD_COLORS[_rng.randi() % BOARD_COLORS.size()])])
		elif roll < 0.68 and sw > 1.4:
			# Hàng 2–4 xe máy dựng chéo, đầu xe quay ra đường.
			var count := _rng.randi_range(2, 4)
			for k in count:
				var at: Vector2 = q + d * (float(k) - float(count - 1) / 2.0) * 0.85 + n * 0.15
				_bikes.append([Transform3D(Basis(Vector3.UP, face + 0.5), Vector3(at.x, 0.05, at.y)), _bike_color()])
		elif roll < 0.86:
			# Bàn ghế nhựa quán nước: một ghế thấp làm bàn, ba ghế đẩu quanh.
			_stools.append([Transform3D(Basis(), Vector3(q.x, 0.05, q.y)).scaled_local(Vector3(1.25, 1.25, 1.25)), Color("2f6db5")])
			for k in 3:
				var ang := float(k) / 3.0 * TAU + _rng.randf()
				var at: Vector2 = q + Vector2(cos(ang), sin(ang)) * 0.55
				_stools.append([Transform3D(Basis(Vector3.UP, ang), Vector3(at.x, 0.05, at.y)), Color(["c0392b", "2f6db5", "e8b52e"][_rng.randi() % 3])])
		else:
			_carts.append(Transform3D(Basis(Vector3.UP, face + PI * 0.5), Vector3(q.x, 0.05, q.y)))
	)


func _bike_color() -> Color:
	return Color(["c0392b", "1d1d20", "e8e8e2", "2f6db5", "7f8c8d", "8e2d2d", "d35400"][_rng.randi() % 7])


func _finish(w) -> void:
	counts = {"decals": _decals.size(), "bins": _bins.size(), "boards": _boards.size(), "bikes": _bikes.size(),
		"stools": _stools.size(), "carts": _carts.size()}
	# Vết bẩn: một MultiMesh mặt phẳng 1 × 1 m.
	if not _decals.is_empty():
		var q := PlaneMesh.new()
		q.size = Vector2(1, 1)
		var sh := Shader.new()
		sh.code = DECAL_SHADER
		var m := ShaderMaterial.new()
		m.shader = sh
		var mm := _mm(q, _decals.size(), true)
		for i in _decals.size():
			mm.set_instance_transform(i, _decals[i][0])
			mm.set_instance_custom_data(i, Color(float(_decals[i][1]), _rng.randf(), 0, 0))
		_mmi(mm, m, false, false)
	if not _bins.is_empty():
		var mm := _mm(_bin_mesh(), _bins.size())
		for i in _bins.size():
			mm.set_instance_transform(i, _bins[i])
		_mmi(mm, _vc_material(), true, true, 0.42)
	if not _boards.is_empty():
		var mm := _mm(_board_mesh(), _boards.size(), false, true)
		for i in _boards.size():
			mm.set_instance_transform(i, _boards[i][0])
			mm.set_instance_color(i, _boards[i][1])
		_mmi(mm, _vc_material(), true, true, 0.38)
		# Chữ trên vài biển gần tâm phố nhất.
		var near := _boards.duplicate()
		var c: Vector2 = w.area.dress.center
		near.sort_custom(func(a, b) -> bool: return Vector2(a[0].origin.x, a[0].origin.z).distance_to(c) < Vector2(b[0].origin.x, b[0].origin.z).distance_to(c))
		for i in mini(24, near.size()):
			var xf: Transform3D = near[i][0]
			for face in [-1.0, 1.0]:
				var l := Label3D.new()
				l.text = BOARD_TEXTS[(i * 7 + 3) % BOARD_TEXTS.size()]
				l.font = UI.text_font()
				l.font_size = 30
				l.outline_size = 0
				l.modulate = Color("1a1a1a") if (near[i][1] as Color).get_luminance() > 0.55 else Color("f8f4e8")
				l.pixel_size = 0.0045
				l.width = 120.0
				l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				l.double_sided = false
				var tilt := Basis(Vector3.RIGHT, -0.32 * face)
				l.transform = xf * Transform3D(Basis(Vector3.UP, 0.0 if face > 0 else PI) * tilt, Vector3(0, 0.62, 0.2 * face))
				l.set_meta("no_ink", true)
				add_child(l)
	if not _bikes.is_empty():
		var mm := _mm(Props3D.motorbike("tay_ga", false), _bikes.size(), true)
		for i in _bikes.size():
			mm.set_instance_transform(i, _bikes[i][0])
			mm.set_instance_custom_data(i, _bikes[i][1])
		_mmi(mm, Props3D.instanced_material(), true, true, 0.5)
	if not _stools.is_empty():
		var mm := _mm(Props3D.stool("low"), _stools.size(), true)
		for i in _stools.size():
			mm.set_instance_transform(i, _stools[i][0])
			mm.set_instance_custom_data(i, _stools[i][1])
		_mmi(mm, Props3D.instanced_material(), true, false)
	if not _carts.is_empty():
		var mm := _mm(Props3D.cart("che"), _carts.size(), true)
		for i in _carts.size():
			mm.set_instance_transform(i, _carts[i])
			mm.set_instance_custom_data(i, Color(["c0392b", "2f6db5", "e8b52e", "2e8b57"][i % 4]))
		_mmi(mm, Props3D.instanced_material(), true, true, 0.55)


func _mm(mesh: Mesh, n: int, custom := false, colors := false) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = custom
	# Bản Compatibility nhân màu đỉnh với màu instance: bật màu instance (trắng nếu không đặt) cho khỏi đen.
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = n
	if not colors:
		for i in n:
			mm.set_instance_color(i, Color.WHITE)
	return mm


## MultiMeshInstance3D: viền mực, bóng chân (MultiMesh bóng dùng chung các vị trí) nếu blob_r > 0.
func _mmi(mm: MultiMesh, mat: Material, ink: bool, shadows: bool, blob_r := 0.0) -> MultiMeshInstance3D:
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if ink and Ink.enabled:
		mi.material_overlay = Ink.outline()
	else:
		mi.set_meta("no_ink", true)
	add_child(mi)
	if blob_r > 0.0 and Ink.enabled:
		var bm := MultiMesh.new()
		bm.transform_format = MultiMesh.TRANSFORM_3D
		bm.mesh = Ink._blob_mesh_get()
		bm.instance_count = mm.instance_count
		for i in mm.instance_count:
			bm.set_instance_transform(i, Transform3D(Basis(), mm.get_instance_transform(i).origin))
		var bi := MultiMeshInstance3D.new()
		bi.multimesh = bm
		bi.material_override = Ink.blob_material(blob_r)
		bi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bi.set_meta("no_ink", true)
		add_child(bi)
	return mi


static func _vc_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.85
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	return m


static func _box(st: SurfaceTool, c: Vector3, s: Vector3, col: Color) -> void:
	var h := s / 2.0
	var faces := [[Vector3.UP, Vector3.RIGHT, Vector3.BACK], [Vector3.DOWN, Vector3.RIGHT, Vector3.FORWARD],
		[Vector3.RIGHT, Vector3.BACK, Vector3.UP], [Vector3.LEFT, Vector3.FORWARD, Vector3.UP],
		[Vector3.BACK, Vector3.LEFT, Vector3.UP], [Vector3.FORWARD, Vector3.RIGHT, Vector3.UP]]
	for f in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var o: Vector3 = c + n * (h * n.abs()).length()
		var hu: float = (h * u.abs()).length()
		var hv: float = (h * v.abs()).length()
		var pts := [o - u * hu - v * hv, o + u * hu - v * hv, o + u * hu + v * hv, o - u * hu + v * hv]
		for idx in [0, 2, 1, 0, 3, 2]:
			st.set_color(col)
			st.set_normal(n)
			st.add_vertex(pts[idx])


## Thùng rác nhựa xanh 240 lít: thân, nắp, quai, hai bánh đen.
static func _bin_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var green := Color("2e7d32")
	_box(st, Vector3(0, 0.5, 0), Vector3(0.56, 0.9, 0.66), green)
	_box(st, Vector3(0, 0.98, 0.02), Vector3(0.62, 0.07, 0.74), green.darkened(0.25))
	_box(st, Vector3(0, 0.9, -0.36), Vector3(0.5, 0.06, 0.06), green.darkened(0.4))
	for x in [-0.25, 0.25]:
		_box(st, Vector3(x, 0.1, -0.3), Vector3(0.07, 0.2, 0.2), Color("151515"))
	_box(st, Vector3(0, 0.7, 0.34), Vector3(0.3, 0.18, 0.01), Color("f2f2ee"))
	return st.commit()


## Biển quảng cáo đứng chữ A: hai tấm nghiêng tựa nhau, khung sắt; màu tấm là màu instance.
static func _board_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face in [-1.0, 1.0]:
		var tilt := Basis(Vector3.RIGHT, -0.32 * face)
		var c := Vector3(0, 0.5, 0.14 * face)
		var s := Vector3(0.62, 0.9, 0.03)
		# Tấm: hộp mỏng xoay quanh trục x quanh đỉnh chữ A.
		var tmp := SurfaceTool.new()
		tmp.begin(Mesh.PRIMITIVE_TRIANGLES)
		_box(tmp, Vector3.ZERO, s, Color.WHITE)
		var arr := tmp.commit_to_arrays()
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		for i in verts.size():
			st.set_color(Color.WHITE)
			st.set_normal(tilt * norms[i])
			st.add_vertex(tilt * verts[i] + c)
		_box(st, Vector3(0, 0.95, 0), Vector3(0.66, 0.05, 0.06), Color("2b2b2b"))
	return st.commit()
