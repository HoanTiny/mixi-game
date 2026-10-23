extends RefCounted
## Đồ vật 3D dựng bằng code, không cần file mô hình: xe máy (tay ga, xe số), ô tô, ghế đẩu và bàn nhựa, xe đẩy bán
## rong (bánh mì, chè, hủ tiếu gõ, ve chai), gánh hàng, ghe chở hàng có mui và xuồng, tán cây, thân cây.
## Mỗi món dựng một lần rồi dùng chung. Màu đỉnh là màu thật (mã màu như trong bảng màu); alpha = 1 đánh dấu phần sơn,
## nhân với màu sơn của từng chiếc: chiếc riêng lẻ lấy màu ở tham số paint (material(màu)), MultiMesh lấy ở
## INSTANCE_CUSTOM (instanced_material()). Xe, ghe, xe đẩy nhìn về +z, gốc ở mặt đất (mặt nước) chính giữa.

const Character := preload("res://scripts/world/character.gd")

const SHADER := """
shader_type spatial;
render_mode cull_back;
// Màu sơn của chiếc này; MultiMesh thì lấy từ INSTANCE_CUSTOM (mã màu sRGB như màu đỉnh). Phần sơn thứ hai (áo người
// lái, alpha màu đỉnh 0,5): paint2, MultiMesh thì lấy sắc màu ở INSTANCE_CUSTOM.a.
uniform vec3 paint : source_color = vec3(0.7, 0.2, 0.2);
uniform vec3 paint2 : source_color = vec3(0.3, 0.5, 0.8);
uniform bool per_instance = false;
// Người đi bộ (MultiMesh): tay chân vung theo nhịp bước. UV.x đánh dấu chi (1, 2 chân trái, phải; 3, 4 tay trái,
// phải), UV.y là độ cao khớp hông, vai; mỗi người một nhịp lệch theo chỗ đứng.
uniform bool swing = false;
uniform float swing_speed = 7.0;
varying vec3 v_paint;
varying vec3 v_paint2;
vec3 shirt(float h) {
	vec3 k = clamp(abs(fract(h + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
	return mix(vec3(1.0), k, 0.55) * 0.88;
}
void vertex() {
	v_paint = per_instance ? pow(INSTANCE_CUSTOM.rgb, vec3(2.2)) : paint;
	v_paint2 = per_instance ? pow(shirt(INSTANCE_CUSTOM.a), vec3(2.2)) : paint2;
	if (swing && UV.x > 0.5) {
		float limb = floor(UV.x + 0.5);
		float side = (limb == 1.0 || limb == 4.0) ? 1.0 : -1.0;
		float phase = dot(MODEL_MATRIX[3].xz, vec2(0.37, 0.71));
		float ang = sin(TIME * swing_speed + phase) * (limb < 2.5 ? 0.45 : 0.35) * side;
		float dy = VERTEX.y - UV.y;
		float dz = VERTEX.z;
		VERTEX.y = UV.y + dy * cos(ang) - dz * sin(ang);
		VERTEX.z = dy * sin(ang) + dz * cos(ang);
	}
}
void fragment() {
	vec3 base = pow(COLOR.rgb, vec3(2.2));
	float k1 = step(0.75, COLOR.a);
	float k2 = step(0.25, COLOR.a) - k1;
	ALBEDO = base * mix(vec3(1.0), v_paint, k1) * mix(vec3(1.0), v_paint2, k2);
	// Phần sơn bóng hơn nhựa, cao su, gỗ.
	ROUGHNESS = mix(0.8, 0.4, k1);
}
"""
## Ngồi xe máy: độ cao khớp hông, chỗ hông người lái và người ngồi sau theo chiều dài xe (xem Character.sit).
const SEAT_H := 0.93
const RIDER_Z := -0.15
const BACK_Z := -0.6
## Chiều dài chuẩn của ghe chở hàng, xuồng: ghe dài ngắn khác nhau thì co giãn theo trục z.
const BOAT_LEN := {"cargo": 7.0, "small": 4.2}
## Tay đẩy của xe đẩy (độ cao, z trong khung xe): người đẩy đứng sau, hai tay nắm ở đây.
const CART_GRIP_Y := 1.0
const CART_GRIP_Z := -0.62

const NB := []

static var _cache := {}
static var _mats := {}
static var _shader: Shader


# ---------------------------------------------------------------- vật liệu

## Vật liệu cho một chiếc có màu sơn paint (dùng chung giữa các chiếc cùng màu).
static func material(paint := Color(1, 1, 1)) -> ShaderMaterial:
	var key := paint.to_html(false)
	if not _mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = _get_shader()
		m.set_shader_parameter("paint", paint)
		_mats[key] = m
	return _mats[key]


## Vật liệu cho MultiMesh: màu sơn từng chiếc ở custom data (bật use_custom_data); bật cả use_colors với màu instance
## trắng, vì bản Compatibility (web) nhân màu đỉnh với màu instance.
static func instanced_material() -> ShaderMaterial:
	if not _mats.has("instanced"):
		var m := ShaderMaterial.new()
		m.shader = _get_shader()
		m.set_shader_parameter("per_instance", true)
		_mats["instanced"] = m
	return _mats["instanced"]


## Vật liệu cho MultiMesh người đi bộ (person("walk")): như instanced_material, tay chân vung theo nhịp speed.
static func walking_material(speed := 7.0) -> ShaderMaterial:
	var key := "walk|%s" % speed
	if not _mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = _get_shader()
		m.set_shader_parameter("per_instance", true)
		m.set_shader_parameter("swing", true)
		m.set_shader_parameter("swing_speed", speed)
		_mats[key] = m
	return _mats[key]


static func glass_material() -> StandardMaterial3D:
	if not _mats.has("glass"):
		var m := StandardMaterial3D.new()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.78, 0.88, 0.92, 0.28)
		m.roughness = 0.08
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats["glass"] = m
	return _mats["glass"]


static func _get_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	return _shader


## Một chiếc đặt riêng: lưới mesh với màu sơn paint; mặt kính (lưới có hai phần) dùng vật liệu kính.
static func instance(mesh: Mesh, paint := Color(1, 1, 1)) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.set_surface_override_material(0, material(paint))
	if mesh.get_surface_count() > 1:
		mi.set_surface_override_material(1, glass_material())
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi


# ---------------------------------------------------------------- màu, hình cơ bản

## Màu cố định (không sơn), tối đi theo shade.
static func _c(hex: String, shade := 1.0) -> Color:
	var c := Color(hex)
	return Color(c.r * shade, c.g * shade, c.b * shade, 0.0)


## Phần sơn: độ sáng shade nhân với màu sơn của chiếc.
static func _p(shade := 1.0) -> Color:
	return Color(shade, shade, shade, 1.0)


## Vòng cho _loft: tâm, nửa bề ngang w, nửa bề cao h (ống đứng: nửa bề dày theo z), màu, độ vuông sq (0 tròn, 0,6 gần vuông).
static func _r(c: Vector3, w: float, h: float, col: Color, sq := 0.0) -> Dictionary:
	return {"c": c, "w": w, "h": h, "col": col, "sq": sq}


## Ống qua các vòng (xem _r), nắp phẳng hai đầu. Ống chạy theo z hay đứng: bề ngang theo x; ống chạy theo x: bề ngang
## theo z. Pháp tuyến nghiêng theo độ loe của ống.
static func _loft(g, rings: Array, segs := 8, cap0 := true, cap1 := true) -> void:
	var n := rings.size()
	var fr := []
	for i in n:
		var ax: Vector3 = ((rings[mini(i + 1, n - 1)].c as Vector3) - (rings[maxi(i - 1, 0)].c as Vector3)).normalized()
		var side := Vector3.RIGHT if absf(ax.x) < 0.9 else Vector3.BACK
		side = (side - ax * ax.dot(side)).normalized()
		var up := ax.cross(side)
		if up.y < -0.1 or (absf(up.y) <= 0.1 and up.z < 0.0):
			up = -up
		fr.append([ax, side, up])
	var rows := []
	for i in n:
		var r: Dictionary = rings[i]
		var ax: Vector3 = fr[i][0]
		var side: Vector3 = fr[i][1]
		var up: Vector3 = fr[i][2]
		var rp: Dictionary = rings[maxi(i - 1, 0)]
		var rn: Dictionary = rings[mini(i + 1, n - 1)]
		var ds := maxf((rn.c as Vector3).distance_to(rp.c), 0.0001)
		var slope := ((float(rn.w) + float(rn.h)) - (float(rp.w) + float(rp.h))) / 2.0 / ds
		var e := 1.0 - float(r.get("sq", 0.0))
		var row := PackedInt32Array()
		for j in segs:
			var th := TAU * (float(j) + 0.5) / float(segs)
			var cx := cos(th)
			var cy := sin(th)
			var px := signf(cx) * pow(absf(cx), e)
			var py := signf(cy) * pow(absf(cy), e)
			var nn: Vector3 = side * signf(cx) * pow(absf(cx), 2.0 - e) / float(r.w) + up * signf(cy) * pow(absf(cy), 2.0 - e) / float(r.h)
			nn = (nn.normalized() - ax * slope).normalized()
			row.append(g.vert((r.c as Vector3) + side * float(r.w) * px + up * float(r.h) * py, nn, r.col, NB))
		rows.append(row)
	for i in n - 1:
		for j in segs:
			var j2 := (j + 1) % segs
			g.tri(rows[i][j], rows[i][j2], rows[i + 1][j2])
			g.tri(rows[i][j], rows[i + 1][j2], rows[i + 1][j])
	for end in [0, n - 1]:
		if (end == 0 and not cap0) or (end == n - 1 and not cap1):
			continue
		var ax: Vector3 = fr[end][0] * (-1.0 if end == 0 else 1.0)
		var r: Dictionary = rings[end]
		var mid: int = g.vert(r.c, ax, r.col, NB)
		var ring := PackedInt32Array()
		for j in segs:
			ring.append(g.vert(g.pts[rows[end][j]], ax, r.col, NB))
		for j in segs:
			g.tri(mid, ring[j], ring[(j + 1) % segs])


## Trụ (côn) từ a tới b, bán kính r0 ở a, r1 ở b.
static func _cyl(g, a: Vector3, b: Vector3, r0: float, r1: float, col: Color, segs := 6, caps := true) -> void:
	_loft(g, [_r(a, r0, r0, col), _r(b, r1, r1, col)], segs, caps, caps)


## Hộp tâm c cỡ s, xoay quanh trục đứng một góc yaw.
static func _box(g, c: Vector3, s: Vector3, col: Color, yaw := 0.0) -> void:
	var bs := Basis(Vector3.UP, yaw)
	var h := s / 2.0
	for ax in 3:
		for sg in [-1.0, 1.0]:
			var nn := Vector3.ZERO
			nn[ax] = sg
			var u := Vector3.ZERO
			u[(ax + 1) % 3] = h[(ax + 1) % 3]
			var v := Vector3.ZERO
			v[(ax + 2) % 3] = h[(ax + 2) % 3]
			var f := nn * h[ax]
			var q := []
			for k in [[-1.0, -1.0], [1.0, -1.0], [1.0, 1.0], [-1.0, 1.0]]:
				q.append(g.vert(c + bs * (f + u * float(k[0]) + v * float(k[1])), bs * nn, col, NB))
			g.tri(q[0], q[1], q[2])
			g.tri(q[0], q[2], q[3])


## Khối tròn tâm c bán kính r: lump làm mặt lồi lõm (tán cây, bao tải), shade_y làm sẫm dần về phía dưới.
static func _blob(g, c: Vector3, r: Vector3, col: Color, rows := 5, cols := 8, lump := 0.0, seed := 0.0, shade_y := 0.0) -> void:
	var ids := []
	for i in rows + 1:
		var th := PI * float(i) / float(rows)
		var row := PackedInt32Array()
		for j in cols:
			var ph := TAU * float(j) / float(cols)
			var u := Vector3(sin(th) * sin(ph), cos(th), sin(th) * cos(ph))
			var k := 1.0 + lump * sin(u.x * 4.1 + seed) * sin(u.y * 3.3 + seed * 1.7) * sin(u.z * 4.7 + seed * 0.6)
			var nn := Vector3(u.x / r.x, u.y / r.y, u.z / r.z).normalized()
			var s := 1.0 - shade_y * (0.5 - 0.5 * u.y)
			row.append(g.vert(c + Vector3(u.x * r.x, u.y * r.y, u.z * r.z) * k, nn, Color(col.r * s, col.g * s, col.b * s, col.a), NB))
		ids.append(row)
	for i in rows:
		for j in cols:
			var j2 := (j + 1) % cols
			g.tri(ids[i][j], ids[i][j2], ids[i + 1][j2])
			g.tri(ids[i][j], ids[i + 1][j2], ids[i + 1][j])


## Bánh xe trục theo x tâm c: lốp đen bo cạnh, mặt bên có vành xám (detail: thêm viền lốp đen quanh vành).
static func _wheel(g, c: Vector3, r: float, w: float, rim: Color, segs := 12, detail := true) -> void:
	var tyre := _c("1b1b1d")
	var hw := w / 2.0
	if detail:
		_loft(g, [_r(c - Vector3(hw, 0, 0), r * 0.9, r * 0.9, tyre), _r(c - Vector3(hw * 0.5, 0, 0), r, r, tyre),
			_r(c + Vector3(hw * 0.5, 0, 0), r, r, tyre), _r(c + Vector3(hw, 0, 0), r * 0.9, r * 0.9, tyre)], segs, false, false)
	else:
		_loft(g, [_r(c - Vector3(hw, 0, 0), r, r, tyre), _r(c + Vector3(hw, 0, 0), r, r, tyre)], segs, false, false)
	for sx in [-1.0, 1.0]:
		var nn := Vector3(sx, 0, 0)
		var cc: Vector3 = c + nn * hw
		var mid: int = g.vert(cc + nn * 0.006, nn, rim, NB)
		if not detail:
			var disc := PackedInt32Array()
			for j in segs:
				var th := TAU * (float(j) + 0.5) / float(segs)
				disc.append(g.vert(cc + Vector3(0, sin(th), cos(th)) * r * 0.62 + nn * 0.003, nn, rim, NB))
			for j in segs:
				g.tri(mid, disc[j], disc[(j + 1) % segs])
			continue
		var outer := r * 0.9
		var inner := r * 0.6
		var ring_o := PackedInt32Array()
		var ring_t := PackedInt32Array()
		var ring_g := PackedInt32Array()
		for j in segs:
			var th := TAU * (float(j) + 0.5) / float(segs)
			var d := Vector3(0, sin(th), cos(th))
			ring_o.append(g.vert(cc + d * outer, nn, tyre, NB))
			ring_t.append(g.vert(cc + d * inner + nn * 0.003, nn, tyre, NB))
			ring_g.append(g.vert(cc + d * inner + nn * 0.003, nn, rim, NB))
		for j in segs:
			var j2 := (j + 1) % segs
			g.tri(ring_o[j], ring_o[j2], ring_t[j2])
			g.tri(ring_o[j], ring_t[j2], ring_t[j])
			g.tri(mid, ring_g[j], ring_g[j2])


## Cung cong (dè xe, mui ghe, thân ghe): ống theo trục a→b, chỉ dựng cung từ góc a0 tới a1 (0 là phía trước hay bên
## phải, π/2 là phía trên), hai mặt. rings: [vị trí 0..1 dọc trục, bán kính ngang, bán kính đứng, lệch cao, màu].
static func _arc(g, a: Vector3, b: Vector3, rings: Array, a0: float, a1: float, segs := 8) -> void:
	var tr := []
	for r in rings:
		tr.append({"c": a.lerp(b, float(r[0])) + Vector3(0, float(r[3]), 0), "rx": float(r[1]), "rz": float(r[2]), "c2": r[4]})
	g.tube(tr, 0, false, false, segs, false, a0, a1)


# ---------------------------------------------------------------- xe máy

## Xe máy: kind "tay_ga" (sàn để chân, yếm to) hay "xe_so" (khung cong, gác chân); detail false là bản nhẹ cho xe đậu
## hàng loạt (MultiMesh). Yên, sàn, tay lái đặt khớp với dáng ngồi của Character (SEAT_H, RIDER_Z, BACK_Z).
static func motorbike(kind := "tay_ga", detail := true) -> ArrayMesh:
	var key := "xe|%s|%s" % [kind, detail]
	if _cache.has(key):
		return _cache[key]
	var g = Character.Mesher.new(false)
	_motorbike(g, kind, detail)
	var m: ArrayMesh = g.commit()
	_cache[key] = m
	return m


## Xe máy đang chạy có người lái (dòng xe MultiMesh, xem traffic.gd): xe bản nhẹ, người lái nắm tay lái, chân để
## trên sàn (tay ga) hay gác chân (xe số); passenger: thêm người ngồi sau.
static func rider_bike(kind := "tay_ga", passenger := false) -> ArrayMesh:
	var key := "chay|%s|%s" % [kind, passenger]
	if _cache.has(key):
		return _cache[key]
	var g = Character.Mesher.new(false)
	_motorbike(g, kind, false)
	_rider(g, RIDER_Z, Vector3(0.15, 0.34, 0.12) if kind == "tay_ga" else Vector3(0.24, 0.35, 0.24), true)
	if passenger:
		_rider(g, BACK_Z, Vector3(0.25, 0.38, -0.3), false)
	# Bóng giả sát mặt đường: dòng xe đông không đổ bóng thật (đỡ vẽ lại vào các tầng bóng nắng).
	var disc := PackedInt32Array()
	var mid: int = g.vert(Vector3(0.0, 0.012, 0.0), Vector3.UP, _c("1c1d20"), NB)
	for j in 10:
		var th := TAU * float(j) / 10.0
		disc.append(g.vert(Vector3(sin(th) * 0.42, 0.012, cos(th) * 1.0 - 0.05), Vector3.UP, _c("26272b"), NB))
	for j in 10:
		g.tri(mid, disc[j], disc[(j + 1) % 10])
	var m: ArrayMesh = g.commit()
	_cache[key] = m
	return m


## Người ngồi xe máy, gộp vào lưới xe: hông ở (0, SEAT_H, hz), bàn chân ở (±foot.x, foot.y, foot.z); driver: hai tay
## nắm tay lái, không thì đặt trên đùi. Áo là phần sơn thứ hai (alpha 0,5: MultiMesh cho mỗi người một màu áo), nón
## bảo hiểm là phần sơn (cùng màu xe).
static func _rider(g, hz: float, foot: Vector3, driver: bool) -> void:
	var skin := _c("c99a72")
	var pants := _c("2f3644")
	var shirt := Color(1.0, 1.0, 1.0, 0.5)
	for sx in [-1.0, 1.0]:
		var hip := Vector3(sx * 0.1, SEAT_H, hz)
		var knee := Vector3(sx * 0.17, SEAT_H + 0.04, hz + 0.4)
		var ft := Vector3(sx * foot.x, foot.y, foot.z)
		_cyl(g, hip, knee, 0.085, 0.07, pants, 5, false)
		_cyl(g, knee, ft + Vector3(0, 0.06, 0), 0.065, 0.05, pants, 5, false)
		_box(g, ft + Vector3(0, 0.03, 0.05), Vector3(0.1, 0.07, 0.22), _c("1e1e22"))
	# Thân từ hông lên vai, người lái chồm tới trước.
	var lean := 0.12 if driver else 0.04
	_loft(g, [_r(Vector3(0, SEAT_H + 0.02, hz - 0.02), 0.16, 0.11, shirt), _r(Vector3(0, SEAT_H + 0.28, hz + lean * 0.5), 0.18, 0.11, shirt),
		_r(Vector3(0, SEAT_H + 0.48, hz + lean), 0.19, 0.1, shirt)], 6)
	var sh_y := SEAT_H + 0.45
	var sh_z := hz + lean
	for sx in [-1.0, 1.0]:
		var sh := Vector3(sx * 0.2, sh_y, sh_z)
		var hand := Vector3(sx * 0.3, 1.08, 0.38) if driver else Vector3(sx * 0.16, SEAT_H + 0.08, hz + 0.3)
		var elbow := sh.lerp(hand, 0.5) + Vector3(sx * 0.05, -0.08, 0.0)
		_cyl(g, sh, elbow, 0.055, 0.05, shirt, 5, false)
		_cyl(g, elbow, hand, 0.045, 0.04, skin, 5, false)
	var head := Vector3(0, sh_y + 0.2, sh_z + 0.03)
	_blob(g, head, Vector3(0.1, 0.12, 0.11), skin, 3, 6)
	_blob(g, head + Vector3(0, 0.045, -0.01), Vector3(0.125, 0.11, 0.135), _p(), 3, 6)


static func _motorbike(g, kind: String, detail: bool) -> void:
	var s := 12 if detail else 6
	var R := 0.27
	var zf := 0.76
	var zr := -0.58
	var dark := _c("2a2a2e")
	var black := _c("161618")
	var metal := _c("8e9196")
	var tay_ga := kind == "tay_ga"
	_wheel(g, Vector3(0, R, zf), R, 0.1, metal, s if detail else 8, detail)
	_wheel(g, Vector3(0, R, zr), R, 0.12, metal, s if detail else 8, detail)
	# Thân sau dưới yên, đuôi vuốt lên.
	if detail:
		_loft(g, [_r(Vector3(0, 0.68, -0.95), 0.05, 0.05, _p()), _r(Vector3(0, 0.66, -0.88), 0.13, 0.11, _p()),
			_r(Vector3(0, 0.6, -0.66), 0.165, 0.17, _p()), _r(Vector3(0, 0.55, -0.38), 0.17, 0.19, _p()),
			_r(Vector3(0, 0.5, -0.14), 0.155, 0.18, _p()), _r(Vector3(0, 0.44, 0.0), 0.12, 0.12, _p(0.92))], s)
		# Yên da đen.
		_loft(g, [_r(Vector3(0, 0.765, -0.9), 0.08, 0.03, black), _r(Vector3(0, 0.79, -0.82), 0.14, 0.05, black),
			_r(Vector3(0, 0.8, -0.4), 0.155, 0.055, black), _r(Vector3(0, 0.79, -0.08), 0.14, 0.05, black),
			_r(Vector3(0, 0.765, 0.02), 0.08, 0.03, black)], s)
	else:
		_loft(g, [_r(Vector3(0, 0.66, -0.9), 0.12, 0.1, _p()), _r(Vector3(0, 0.57, -0.5), 0.17, 0.19, _p()),
			_r(Vector3(0, 0.46, -0.02), 0.13, 0.14, _p(0.92))], s)
		_loft(g, [_r(Vector3(0, 0.78, -0.86), 0.12, 0.04, black), _r(Vector3(0, 0.8, -0.4), 0.155, 0.055, black),
			_r(Vector3(0, 0.775, 0.0), 0.1, 0.04, black)], s)
	if tay_ga:
		# Sàn để chân, bụng xe, yếm trước ôm sau bánh trước vuốt lên tới cổ lái.
		_box(g, Vector3(0, 0.315, 0.16), Vector3(0.3, 0.05, 0.58), dark)
		_loft(g, [_r(Vector3(0, 0.25, -0.12), 0.14, 0.06, _p(0.85), 0.4), _r(Vector3(0, 0.25, 0.44), 0.14, 0.05, _p(0.85), 0.4)], s)
		_loft(g, [_r(Vector3(0, 0.24, 0.45), 0.17, 0.05, _p()), _r(Vector3(0, 0.56, 0.47), 0.2, 0.075, _p()),
			_r(Vector3(0, 0.84, 0.48), 0.17, 0.075, _p()), _r(Vector3(0, 0.98, 0.46), 0.11, 0.065, _p())], s)
	else:
		# Xe số: khung cong từ cổ lái xuống dưới yên, yếm nhỏ, máy lộ ra, gác chân.
		_loft(g, [_r(Vector3(0, 0.98, 0.45), 0.07, 0.06, _p()), _r(Vector3(0, 0.7, 0.36), 0.1, 0.08, _p()),
			_r(Vector3(0, 0.46, 0.18), 0.12, 0.09, _p()), _r(Vector3(0, 0.44, -0.06), 0.13, 0.1, _p(0.92))], s)
		_loft(g, [_r(Vector3(0, 0.36, 0.44), 0.16, 0.035, _p(0.95)), _r(Vector3(0, 0.62, 0.47), 0.18, 0.04, _p(0.95)),
			_r(Vector3(0, 0.86, 0.46), 0.13, 0.04, _p(0.95))], s)
		_box(g, Vector3(0, 0.3, 0.04), Vector3(0.22, 0.2, 0.36), _c("55585e"))
		_cyl(g, Vector3(-0.24, 0.33, 0.27), Vector3(0.24, 0.33, 0.27), 0.018, 0.018, black, 6)
	# Đầu xe ốp nhựa sơn, đèn pha, phuộc, tay lái, tay nắm, gương.
	_blob(g, Vector3(0, 1.06, 0.45), Vector3(0.2, 0.07, 0.13), _p(), 5 if detail else 2, s, 0.0, 0.0, 0.15)
	for sx in [-1.0, 1.0]:
		_cyl(g, Vector3(sx * 0.06, 1.0, 0.47), Vector3(sx * 0.06, R, zf), 0.022, 0.022, metal, 5 if detail else 4, false)
	_cyl(g, Vector3(-0.34, 1.07, 0.385), Vector3(0.34, 1.07, 0.385), 0.019, 0.019, black, 6 if detail else 4)
	# Dè trước ôm trên bánh trước.
	_arc(g, Vector3(-0.07, R, zf), Vector3(0.07, R, zf), [[0.0, R + 0.04, R + 0.04, 0.0, _p()], [1.0, R + 0.04, R + 0.04, 0.0, _p()]],
		deg_to_rad(20.0), deg_to_rad(135.0), 6 if detail else 3)
	if detail:
		# Gác chân sau cho người ngồi sau, đèn pha, đèn hậu, biển số.
		_cyl(g, Vector3(-0.25, 0.36, -0.2), Vector3(0.25, 0.36, -0.2), 0.016, 0.016, black, 6, true)
		_blob(g, Vector3(0, 1.04, 0.575), Vector3(0.09, 0.04, 0.025), _c("f4f1e0"), 3, s)
		_blob(g, Vector3(0, 0.69, -0.955), Vector3(0.075, 0.035, 0.02), _c("b8302a"), 3, s)
		_box(g, Vector3(0, 0.5, -0.92), Vector3(0.17, 0.11, 0.012), _c("e8e6dc"))
		for sx in [-1.0, 1.0]:
			_cyl(g, Vector3(sx * 0.17, 1.09, 0.42), Vector3(sx * 0.24, 1.29, 0.4), 0.009, 0.009, dark, 4, false)
			_blob(g, Vector3(sx * 0.25, 1.32, 0.4), Vector3(0.068, 0.044, 0.014), dark, 3, 8)
		# Máy, ống pô bên phải.
		if tay_ga:
			_box(g, Vector3(0.03, 0.3, -0.36), Vector3(0.2, 0.2, 0.42), _c("3a3c40"))
		_loft(g, [_r(Vector3(-0.13, 0.27, -0.08), 0.025, 0.025, _c("6d6f73")), _r(Vector3(-0.17, 0.33, -0.45), 0.05, 0.05, _c("b8babd")),
			_r(Vector3(-0.17, 0.37, -0.8), 0.045, 0.045, _c("b8babd"))], 8)


# ---------------------------------------------------------------- người đi đường (MultiMesh)

## Người đi đường gọn nhẹ cho đám đông MultiMesh (crowd.gd): pose "stand" đứng, "walk" đứng có đánh dấu tay chân để
## shader vung theo bước (walking_material), "sit" ngồi ghế đẩu thấp hai tay đặt trên gối. Áo là phần sơn (màu ở
## INSTANCE_CUSTOM), quần là phần sơn thứ hai sẫm màu (sắc ở INSTANCE_CUSTOM.a); hat: đội nón lá. Nhìn về +z, chân ở
## mặt đất (ngồi: mông ở độ cao 0,34 m); có bóng giả sát đất như xe máy chạy.
static func person(pose := "stand", hat := false) -> ArrayMesh:
	var key := "nguoi|%s|%s" % [pose, hat]
	if _cache.has(key):
		return _cache[key]
	var g = Character.Mesher.new(false)
	var skin := _c("c99a72")
	var pants := Color(0.42, 0.42, 0.45, 0.5)
	var shirt := _p()
	var walk := pose == "walk"
	var sit := pose == "sit"
	var hip := 0.36 if sit else 0.9
	var shoulder := hip + 0.5
	for sx in [-1.0, 1.0]:
		var uv := Vector2(1.0 if sx < 0.0 else 2.0, hip) if walk else Vector2.ZERO
		var h := Vector3(sx * 0.09, hip, 0.0)
		if sit:
			var knee := Vector3(sx * 0.11, hip + 0.06, 0.4)
			var foot := Vector3(sx * 0.11, 0.07, 0.44)
			_limb(g, h, knee, 0.08, 0.065, pants, Vector2.ZERO)
			_limb(g, knee, foot, 0.06, 0.05, pants, Vector2.ZERO)
			_box(g, foot + Vector3(0, -0.03, 0.05), Vector3(0.1, 0.07, 0.2), _c("1e1e22"))
		else:
			var foot := Vector3(sx * 0.1, 0.08, 0.02)
			_limb(g, h, foot, 0.075, 0.055, pants, uv)
			_limb(g, foot, foot + Vector3(0, -0.06, 0.12), 0.05, 0.045, _c("1e1e22"), uv)
		# Tay: bắp tay áo, cẳng tay da; người ngồi đặt tay lên gối.
		var auv := Vector2(3.0 if sx < 0.0 else 4.0, shoulder) if walk else Vector2.ZERO
		var sh := Vector3(sx * 0.2, shoulder - 0.03, 0.0)
		var hand := Vector3(sx * 0.15, hip + 0.12, 0.34) if sit else Vector3(sx * 0.25, hip - 0.04, 0.03)
		var elbow := sh.lerp(hand, 0.45) + Vector3(sx * 0.04, 0.0, 0.0)
		_limb(g, sh, elbow, 0.055, 0.05, shirt, auv)
		_limb(g, elbow, hand, 0.045, 0.04, skin, auv)
	_loft(g, [_r(Vector3(0, hip + 0.02, -0.01), 0.16, 0.11, shirt), _r(Vector3(0, hip + 0.28, 0.0), 0.18, 0.11, shirt),
		_r(Vector3(0, shoulder, 0.0), 0.19, 0.1, shirt)], 6)
	var head := Vector3(0, shoulder + 0.19, 0.01)
	_blob(g, head, Vector3(0.1, 0.12, 0.11), skin, 3, 6)
	_blob(g, head + Vector3(0, 0.05, -0.025), Vector3(0.108, 0.1, 0.115), _c("1f1a17"), 3, 6)
	if hat:
		_loft(g, [_r(head + Vector3(0, 0.06, 0), 0.3, 0.3, _c("d9c27a")), _r(head + Vector3(0, 0.22, 0), 0.02, 0.02, _c("cbb56c"))], 8, true, false)
	# Bóng giả sát mặt đất.
	var disc := PackedInt32Array()
	var mid: int = g.vert(Vector3(0.0, 0.012, 0.12 if sit else 0.0), Vector3.UP, _c("1c1d20"), NB)
	for j in 8:
		var th := TAU * float(j) / 8.0
		disc.append(g.vert(Vector3(sin(th) * 0.3, 0.012, cos(th) * 0.3 + (0.12 if sit else 0.0)), Vector3.UP, _c("2a2b2f"), NB))
	for j in 8:
		g.tri(mid, disc[j], disc[(j + 1) % 8])
	var m: ArrayMesh = g.commit()
	_cache[key] = m
	return m


## Ống thon từ a tới b (bán kính r0, r1, 5 mặt, nắp hai đầu) mà mọi đỉnh mang UV uv: shader người đi bộ đọc UV để vung
## tay chân quanh khớp.
static func _limb(g, a: Vector3, b: Vector3, r0: float, r1: float, col: Color, uv: Vector2, segs := 5) -> void:
	var ax := (b - a).normalized()
	var side := Vector3.RIGHT if absf(ax.x) < 0.9 else Vector3.BACK
	side = (side - ax * ax.dot(side)).normalized()
	var up := ax.cross(side)
	var ra := PackedInt32Array()
	var rb := PackedInt32Array()
	for j in segs:
		var th := TAU * float(j) / float(segs)
		var d := side * cos(th) + up * sin(th)
		ra.append(g.vert(a + d * r0, d, col, NB, uv))
		rb.append(g.vert(b + d * r1, d, col, NB, uv))
	for j in segs:
		var j2 := (j + 1) % segs
		g.tri(ra[j], ra[j2], rb[j2])
		g.tri(ra[j], rb[j2], rb[j])
	for end in [[a, ra, -ax, r0], [b, rb, ax, r1]]:
		var c: int = g.vert(end[0], end[2], col, NB, uv)
		var ring := PackedInt32Array()
		for j in segs:
			ring.append(g.vert(g.pts[end[1][j]], end[2], col, NB, uv))
		for j in segs:
			g.tri(c, ring[j], ring[(j + 1) % segs])


# ---------------------------------------------------------------- ô tô

## Ô tô con bốn chỗ (dài 4,2 m): thân bo vuông sơn, cabin kính, mui sơn, bốn bánh, đèn trước sau, biển số.
static func car() -> ArrayMesh:
	if _cache.has("car"):
		return _cache.car
	var g = Character.Mesher.new(false)
	var body := [[-2.1, 0.52, 0.8, 0.2], [-2.03, 0.6, 0.86, 0.3], [-1.65, 0.66, 0.875, 0.36], [1.25, 0.64, 0.875, 0.34],
		[1.85, 0.57, 0.86, 0.26], [2.1, 0.5, 0.8, 0.18]]
	var rings := []
	for r in body:
		rings.append(_r(Vector3(0, float(r[1]), float(r[0])), float(r[2]), float(r[3]), _p(), 0.6))
	_loft(g, rings, 12)
	# Cabin kính thu nhỏ dần lên mui (vòng nằm ngang: nửa bề ngang, nửa bề dài), mui sơn.
	var glass := _c("27303a")
	_loft(g, [_r(Vector3(0, 0.94, -0.2), 0.82, 1.15, glass, 0.6), _r(Vector3(0, 1.08, -0.25), 0.76, 0.95, glass, 0.6),
		_r(Vector3(0, 1.3, -0.32), 0.68, 0.7, glass, 0.6)], 12, false, false)
	_loft(g, [_r(Vector3(0, 1.29, -0.32), 0.7, 0.72, _p(), 0.6), _r(Vector3(0, 1.34, -0.32), 0.66, 0.68, _p(), 0.6)], 12, false, true)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_wheel(g, Vector3(sx * 0.76, 0.31, sz * 1.32), 0.31, 0.2, _c("9a9da2"), 10, true)
		_blob(g, Vector3(sx * 0.58, 0.66, 2.04), Vector3(0.15, 0.06, 0.05), _c("f4f1e0"), 3, 8)
		_blob(g, Vector3(sx * 0.62, 0.74, -2.0), Vector3(0.14, 0.05, 0.05), _c("b8302a"), 3, 8)
	_box(g, Vector3(0, 0.45, 2.11), Vector3(0.5, 0.12, 0.02), _c("e8e6dc"))
	_box(g, Vector3(0, 0.55, -2.11), Vector3(0.5, 0.12, 0.02), _c("e8e6dc"))
	var m: ArrayMesh = g.commit()
	_cache["car"] = m
	return m


# ---------------------------------------------------------------- ghế, bàn nhựa

## Ghế đẩu nhựa (thấp 0,27 m hay cao 0,42 m) và bàn nhựa thấp: khối côn bốn mặt có ô khoét sẫm, lỗ cầm trên mặt.
## Màu trắng để MultiMesh tô màu từng cái (màu instance nhân với màu đỉnh).
static func stool(kind := "low") -> ArrayMesh:
	var key := "stool|" + kind
	if _cache.has(key):
		return _cache[key]
	var g = Character.Mesher.new(false)
	match kind:
		"tall":
			_frustum(g, 0.17, 0.145, 0.42, 0.14)
		"table":
			_frustum(g, 0.32, 0.3, 0.46, 0.0)
		_:
			_frustum(g, 0.165, 0.14, 0.27, 0.13)
	var m: ArrayMesh = g.commit()
	_cache[key] = m
	return m


## Khối côn đáy vuông nửa cạnh b0, mặt trên nửa cạnh b1, cao h; ô khoét sẫm mỗi mặt bên; hole: bán kính lỗ cầm.
static func _frustum(g, b0: float, b1: float, h: float, hole: float) -> void:
	var white := Color(1, 1, 1)
	var dim := Color(0.42, 0.42, 0.42)
	var lo := [Vector3(-b0, 0, -b0), Vector3(b0, 0, -b0), Vector3(b0, 0, b0), Vector3(-b0, 0, b0)]
	var hi := [Vector3(-b1, h, -b1), Vector3(b1, h, -b1), Vector3(b1, h, b1), Vector3(-b1, h, b1)]
	for i in 4:
		var a: Vector3 = lo[i]
		var b: Vector3 = lo[(i + 1) % 4]
		var c: Vector3 = hi[(i + 1) % 4]
		var d: Vector3 = hi[i]
		var nn := (b - a).cross(d - a).normalized()
		if nn.dot((a + b) / 2.0 * Vector3(1, 0, 1)) < 0.0:
			nn = -nn
		var q := [g.vert(a, nn, white, NB), g.vert(b, nn, white, NB), g.vert(c, nn, white, NB), g.vert(d, nn, white, NB)]
		g.tri(q[0], q[1], q[2])
		g.tri(q[0], q[2], q[3])
		# Ô khoét giữa mặt bên (chân ghế hai bên): tấm sẫm sát mặt.
		var f := func(u: float, v: float) -> Vector3: return a.lerp(b, u).lerp(d.lerp(c, u), v) + nn * 0.004
		var k := [g.vert(f.call(0.16, 0.0), nn, dim, NB), g.vert(f.call(0.84, 0.0), nn, dim, NB),
			g.vert(f.call(0.8, 0.72), nn, dim, NB), g.vert(f.call(0.2, 0.72), nn, dim, NB)]
		g.tri(k[0], k[1], k[2])
		g.tri(k[0], k[2], k[3])
	var top := [g.vert(hi[0], Vector3.UP, white, NB), g.vert(hi[1], Vector3.UP, white, NB), g.vert(hi[2], Vector3.UP, white, NB), g.vert(hi[3], Vector3.UP, white, NB)]
	g.tri(top[0], top[1], top[2])
	g.tri(top[0], top[2], top[3])
	if hole > 0.0:
		var mid: int = g.vert(Vector3(0, h + 0.003, 0), Vector3.UP, dim, NB)
		var ring := PackedInt32Array()
		for j in 8:
			var th := TAU * float(j) / 8.0
			ring.append(g.vert(Vector3(cos(th) * hole * 0.5, h + 0.003, sin(th) * hole * 0.32), Vector3.UP, dim, NB))
		for j in 8:
			g.tri(mid, ring[j], ring[(j + 1) % 8])


# ---------------------------------------------------------------- xe đẩy, gánh hàng

## Xe đẩy bán rong theo món (id người bán trong schedules.json). Thùng xe là phần sơn (màu cart), hai bánh xe đạp,
## tay đẩy ở phía sau (z âm, chỗ hai tay người đẩy); xe bánh mì, hủ tiếu có tủ kính (phần lưới thứ hai).
static func cart(kind: String) -> ArrayMesh:
	var key := "cart|" + kind
	if _cache.has(key):
		return _cache[key]
	var g = Character.Mesher.new(false)
	var gl = Character.Mesher.new(false)
	var steel := _c("c9ccd1")
	var dark := _c("3a3a3c")
	var w := 0.36
	var l := 0.5
	var top := 0.9
	if kind == "ve_chai":
		top = 0.62
	# Thùng xe, mặt quầy inox, chân chống trước, hai bánh, tay đẩy.
	_loft(g, [_r(Vector3(0, 0.34, 0), w, l, _p(0.9), 0.75), _r(Vector3(0, top, 0), w, l, _p(), 0.75)], 8, true, false)
	_box(g, Vector3(0, top + 0.015, 0), Vector3(w * 2.0 + 0.05, 0.03, l * 2.0 + 0.05), steel)
	_box(g, Vector3(0, 0.6, -l - 0.005), Vector3(w * 1.4, 0.4, 0.01), _p(0.78))
	_cyl(g, Vector3(0, 0.34, l - 0.08), Vector3(0, 0.0, l - 0.05), 0.02, 0.02, dark, 5)
	for sx in [-1.0, 1.0]:
		_wheel(g, Vector3(sx * (w + 0.06), 0.27, -0.08), 0.27, 0.04, _c("9a9da2"), 12, true)
		_cyl(g, Vector3(sx * (w + 0.02), 0.27, -0.08), Vector3(sx * (w - 0.04), 0.27, -0.08), 0.015, 0.015, dark, 4)
		_cyl(g, Vector3(sx * (w - 0.03), top - 0.02, -l + 0.02), Vector3(sx * (w - 0.03), CART_GRIP_Y, CART_GRIP_Z), 0.015, 0.015, steel, 5, false)
	_cyl(g, Vector3(-w, CART_GRIP_Y, CART_GRIP_Z), Vector3(w, CART_GRIP_Y, CART_GRIP_Z), 0.018, 0.018, steel, 6)
	match kind:
		"banh_mi":
			# Tủ kính bày ổ bánh mì, chả, đồ chua; mái tôn nhỏ phía trên.
			_glass_case(g, gl, Vector3(0, top + 0.03, 0.04), Vector3(w - 0.03, 0.42, l - 0.1), steel)
			for i in 7:
				var x := -0.2 + 0.065 * float(i)
				_blob(g, Vector3(x, top + 0.075 + 0.04 * float(i % 2), -0.05 + 0.03 * float(i % 3)), Vector3(0.032, 0.03, 0.15), _c("c98b3c"), 3, 6, 0.0, 0.0, 0.25)
			_box(g, Vector3(0.18, top + 0.08, 0.22), Vector3(0.14, 0.08, 0.12), _c("c97a6a"))
			_box(g, Vector3(-0.17, top + 0.07, 0.24), Vector3(0.12, 0.06, 0.1), _c("e2c46a"))
			_blob(g, Vector3(0.05, top + 0.08, 0.26), Vector3(0.07, 0.04, 0.05), _c("5f8f3e"), 3, 6, 0.2)
		"hu_tieu":
			# Tủ kính có vắt hủ tiếu, rau; nồi nước lèo to phía trước, ống khói nhỏ.
			_glass_case(g, gl, Vector3(0, top + 0.03, -0.17), Vector3(w - 0.03, 0.34, 0.3), steel)
			for i in 4:
				_blob(g, Vector3(-0.2 + 0.13 * float(i), top + 0.08, -0.2), Vector3(0.055, 0.035, 0.06), _c("f0e4c0"), 3, 6, 0.15)
			_blob(g, Vector3(0.15, top + 0.07, -0.05), Vector3(0.06, 0.035, 0.05), _c("5f8f3e"), 3, 6, 0.2)
			_cyl(g, Vector3(0, top + 0.03, 0.31), Vector3(0, top + 0.34, 0.31), 0.18, 0.17, steel, 12)
			_blob(g, Vector3(0, top + 0.35, 0.31), Vector3(0.17, 0.04, 0.17), steel, 3, 12)
			_blob(g, Vector3(0, top + 0.4, 0.31), Vector3(0.03, 0.025, 0.03), dark, 3, 6)
		"che":
			# Hai tầng hũ chè nhiều màu, chồng ly, thùng đá.
			var fills := ["7cb342", "f2c94c", "a33b3b", "f4efe6", "2b2b2b", "c98b3c", "e07a9a", "6aa3b8"]
			var k := 0
			for row in 2:
				for i in 4:
					var x := -0.24 + 0.16 * float(i)
					var z := -0.2 + 0.24 * float(row)
					var y := top + 0.03 + 0.14 * float(1 - row)
					_cyl(g, Vector3(x, y, z), Vector3(x, y + 0.16, z), 0.06, 0.06, _c(fills[k % fills.size()]), 8)
					_cyl(g, Vector3(x, y + 0.16, z), Vector3(x, y + 0.19, z), 0.045, 0.045, _c("d9dde0"), 8)
					k += 1
			_box(g, Vector3(0, top + 0.07, 0.2), Vector3(w * 2.0 - 0.06, 0.08, 0.14), _p(0.8))
			_box(g, Vector3(0, top + 0.1, -0.33), Vector3(w * 2.0 - 0.06, 0.14, 0.02), _p(0.8))
			_cyl(g, Vector3(0.24, top + 0.03, 0.34), Vector3(0.24, top + 0.28, 0.34), 0.1, 0.11, _c("e8edf0"), 10)
			for i in 3:
				_cyl(g, Vector3(-0.22, top + 0.03 + 0.03 * float(i), 0.34), Vector3(-0.22, top + 0.05 + 0.03 * float(i), 0.34), 0.045, 0.05, _c("dfe8ec"), 8)
		"ve_chai":
			# Xe kéo ve chai: song chắn hai bên, giấy các-tông ép, bao tải, chai nhựa.
			for sx in [-1.0, 1.0]:
				for i in 4:
					var z := -l + 0.06 + float(i) * (l * 2.0 - 0.12) / 3.0
					_cyl(g, Vector3(sx * (w - 0.02), top, z), Vector3(sx * (w - 0.02), top + 0.35, z), 0.012, 0.012, dark, 4, false)
				_cyl(g, Vector3(sx * (w - 0.02), top + 0.35, -l + 0.06), Vector3(sx * (w - 0.02), top + 0.35, l - 0.06), 0.014, 0.014, dark, 4)
			for i in 4:
				_box(g, Vector3(0.02 * float(i % 2), top + 0.05 + 0.06 * float(i), -0.12), Vector3(0.6, 0.05, 0.62), _c("a8865a", 1.0 - 0.06 * float(i)), 0.06 * float(i))
			_blob(g, Vector3(-0.08, top + 0.42, 0.18), Vector3(0.26, 0.2, 0.22), _c("e8e4da"), 5, 8, 0.12, 1.0, 0.2)
			for i in 5:
				var x := -0.22 + 0.11 * float(i)
				_cyl(g, Vector3(x, top + 0.36, 0.36), Vector3(x + 0.02, top + 0.36, 0.12), 0.035, 0.03, _c("8fc1d4"), 6)
	var m: ArrayMesh = g.commit()
	if gl.pts.size() > 0:
		gl.st.commit(m)
	_cache[key] = m
	return m


## Tủ kính trên quầy: khung inox bốn góc, mặt kính (lưới gl, vật liệu trong suốt), nóc kính.
static func _glass_case(g, gl, base: Vector3, half: Vector3, steel: Color) -> void:
	var h := half.y
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_cyl(g, base + Vector3(sx * half.x, 0, sz * half.z), base + Vector3(sx * half.x, h, sz * half.z), 0.012, 0.012, steel, 4)
	for sz in [-1.0, 1.0]:
		_cyl(g, base + Vector3(-half.x, h, sz * half.z), base + Vector3(half.x, h, sz * half.z), 0.012, 0.012, steel, 4)
	for sx in [-1.0, 1.0]:
		_cyl(g, base + Vector3(sx * half.x, h, -half.z), base + Vector3(sx * half.x, h, half.z), 0.012, 0.012, steel, 4)
	_box(gl, base + Vector3(0, h / 2.0, 0), Vector3(half.x * 2.0, h, half.z * 2.0), Color(1, 1, 1))


## Gánh hàng trên vai phải (tọa độ trong khung người cao 1,72 m, gắn vào xương ngực): đòn gánh tre, hai thúng treo
## bằng dây; thúng trước có nồi xôi phủ khăn, thúng sau có lá chuối, hộp xốp.
static func ganh() -> ArrayMesh:
	if _cache.has("ganh"):
		return _cache.ganh
	var g = Character.Mesher.new(false)
	var x := -0.13
	var y := 1.5
	var bamboo := Color("c9b27a")
	var basket := Color("a5824f")
	var rope := Color("5a4a36")
	_cyl(g, Vector3(x, y, -0.78), Vector3(x, y, 0.78), 0.022, 0.022, bamboo, 6)
	for sz in [-1.0, 1.0]:
		var c := Vector3(x, 0.5, sz * 0.72)
		_loft(g, [_r(c, 0.14, 0.14, basket), _r(c + Vector3(0, 0.16, 0), 0.21, 0.21, basket)], 10, true, false)
		for k in 3:
			var a := TAU * float(k) / 3.0 + 0.5
			_cyl(g, c + Vector3(cos(a) * 0.2, 0.16, sin(a) * 0.2), Vector3(x, y, sz * 0.72), 0.005, 0.005, rope, 3, false)
		if sz > 0.0:
			_cyl(g, c + Vector3(0, 0.08, 0), c + Vector3(0, 0.26, 0), 0.16, 0.15, Color("b8bcc2"), 10)
			_blob(g, c + Vector3(0, 0.27, 0), Vector3(0.16, 0.05, 0.16), Color("f2efe6"), 3, 10, 0.1)
		else:
			_blob(g, c + Vector3(0, 0.2, 0), Vector3(0.19, 0.05, 0.19), Color("4f8a3a"), 3, 10, 0.2)
			_box(g, c + Vector3(0.0, 0.27, 0.0), Vector3(0.2, 0.08, 0.16), Color("f4f4f0"), 0.3)
	var m: ArrayMesh = g.commit()
	_cache["ganh"] = m
	return m


# ---------------------------------------------------------------- ghe

## Ghe gỗ: thân cong mũi lái vểnh lên (hai mặt), mép mạn, đà ngang, sàn ván; ghe chở hàng có mui (phần sơn), mắt ghe ở
## mũi, máy đuôi tôm, bao hàng; xuồng nhỏ sơn thân, có mái chèo. Dài BOAT_LEN, gốc ở mặt nước giữa ghe.
static func boat(cargo: bool) -> ArrayMesh:
	var key := "boat|%s" % cargo
	if _cache.has(key):
		return _cache[key]
	var g = Character.Mesher.new(false)
	var L: float = BOAT_LEN.cargo if cargo else BOAT_LEN.small
	var B := 0.85 if cargo else 0.55
	var D := 0.55 if cargo else 0.38
	var y0 := 0.42 if cargo else 0.3
	var hull := _c("9a6a42") if cargo else _p()
	var rim := _c("4e3524")
	var ts := [-1.0, -0.93, -0.78, -0.5, -0.15, 0.2, 0.5, 0.75, 0.9, 1.0]
	var rings := []
	var tops := []
	for t in ts:
		var at := absf(t)
		var rx := maxf(B * sqrt(maxf(0.0, 1.0 - pow(at, 2.4))), 0.035)
		var cy := y0 + (0.28 if t > 0.0 else 0.18) * pow(at, 2.5)
		var rz := maxf(D * (1.0 - 0.55 * at * at), 0.12)
		rings.append({"c": Vector3(0, cy, t * L / 2.0), "rx": rx, "rz": rz, "c2": hull})
		tops.append([t * L / 2.0, rx, cy, rz])
	var lift := 0.16
	g.tube(rings, 0, false, false, 10, false, PI - lift, TAU + lift)
	# Mép mạn hai bên.
	for sx in [-1.0, 1.0]:
		var edge := []
		for tp in tops:
			edge.append(_r(Vector3(sx * float(tp[1]) * cos(lift), float(tp[2]) + float(tp[3]) * sin(lift), float(tp[0])), 0.035, 0.035, rim))
		_loft(g, edge, 5)
	# Sàn ván, đà ngang.
	_box(g, Vector3(0, y0 - D * 0.62, 0), Vector3(B * 1.1, 0.03, L * 0.62), _c("8a6a48"))
	for z in [-0.28, 0.05, 0.3]:
		_box(g, Vector3(0, y0 + 0.02, z * L), Vector3(B * 1.85, 0.05, 0.12), rim)
	if cargo:
		# Mui cong che giữa ghe.
		_arc(g, Vector3(0, y0 + 0.2, -0.33 * L), Vector3(0, y0 + 0.2, 0.06 * L),
			[[0.0, B * 0.9, 0.62, 0.0, _p()], [1.0, B * 0.9, 0.62, 0.0, _p()]], 0.0, PI, 10)
		# Mắt ghe hai bên mũi.
		for sx in [-1.0, 1.0]:
			var z := 0.78 * L / 2.0
			var rx := B * sqrt(1.0 - pow(0.78, 2.4))
			var cy := y0 + 0.28 * pow(0.78, 2.5)
			var p := Vector3(sx * (rx * 0.97 + 0.012), cy - 0.08, z)
			_blob(g, p, Vector3(0.014, 0.09, 0.16), _c("f2efe6"), 3, 10)
			_blob(g, p + Vector3(sx * 0.01, 0, 0.03), Vector3(0.014, 0.055, 0.06), _c("1b1b1b"), 3, 8)
			_blob(g, p + Vector3(sx * 0.005, 0.1, -0.01), Vector3(0.014, 0.02, 0.17), _c("b8302a"), 2, 8)
		# Máy đuôi tôm ở lái: máy, cần dài chúc xuống nước.
		_box(g, Vector3(0, y0 + 0.16, -0.42 * L), Vector3(0.32, 0.26, 0.42), _c("4d6b5a"))
		_cyl(g, Vector3(0, y0 + 0.14, -0.45 * L), Vector3(0, -0.05, -0.5 * L - 1.4), 0.03, 0.025, _c("6d6f73"), 5)
		# Bao hàng, sọt dưới mui và phía mũi.
		for i in 6:
			var tier := floorf(float(i) / 3.0)
			var bx := -0.3 + 0.3 * float(i % 3)
			var bz := (0.12 + 0.11 * tier) * L
			_blob(g, Vector3(bx, y0 + 0.02 + 0.08 * tier, bz), Vector3(0.22, 0.13, 0.32), _c("c9bc9c"), 4, 7, 0.08, float(i), 0.25)
		_box(g, Vector3(0.1, y0 + 0.02, -0.18 * L), Vector3(0.5, 0.35, 0.45), _c("b58a52"), 0.2)
	else:
		# Mái chèo nằm dọc lòng xuồng.
		_cyl(g, Vector3(0.18, y0 + 0.02, -0.35 * L), Vector3(0.12, y0 + 0.02, 0.25 * L), 0.018, 0.018, _c("8a6a48"), 4)
		_box(g, Vector3(0.12, y0 + 0.02, 0.29 * L), Vector3(0.12, 0.02, 0.32), _c("8a6a48"))
	var m: ArrayMesh = g.commit()
	_cache[key] = m
	return m


# ---------------------------------------------------------------- cây

## Tán cây lồi lõm: một khối chính và vài chùm lá, sáng ở trên sẫm ở dưới; tâm ở gốc tọa độ, rộng chừng 2,1 m, cao
## chừng 1,7 m mỗi phía (thay SphereMesh cũ của area_builder). Màu trắng xám để nhân với màu lá.
static func crown() -> ArrayMesh:
	if _cache.has("crown"):
		return _cache.crown
	var g = Character.Mesher.new(false)
	var white := Color(1, 1, 1)
	_blob(g, Vector3(0, -0.1, 0), Vector3(1.7, 1.25, 1.7), white, 6, 9, 0.13, 0.4, 0.42)
	var tufts := [[Vector3(0.75, 0.55, 0.35), Vector3(1.0, 0.85, 0.95)], [Vector3(-0.7, 0.5, -0.45), Vector3(1.05, 0.9, 1.0)],
		[Vector3(-0.25, 0.75, 0.8), Vector3(0.9, 0.8, 0.9)], [Vector3(0.35, -0.3, -0.95), Vector3(0.85, 0.75, 0.8)]]
	for i in tufts.size():
		_blob(g, tufts[i][0], tufts[i][1], white, 4, 6, 0.1, float(i) * 1.7, 0.36)
	var m: ArrayMesh = g.commit()
	_cache["crown"] = m
	return m


## Cây dừa cao chừng 6,5 m: thân cong có vòng đốt, buồng dừa dưới ngọn, chín tàu lá vươn ra rồi rủ xuống (gân giữa
## nhô lên, hai mặt). Gốc ở mặt đất; màu thật, không sơn.
static func palm() -> ArrayMesh:
	if _cache.has("palm"):
		return _cache.palm
	var g = Character.Mesher.new(false)
	var rings := []
	var top := Vector3.ZERO
	for i in 11:
		var t := float(i) / 10.0
		top = Vector3(0.6 * t * t, 6.3 * t, 0.12 * t)
		var r := lerpf(0.2, 0.13, t)
		rings.append(_r(top, r, r, _c("8a7a62", 0.86 if i % 2 == 1 else 1.0)))
	_loft(g, rings, 7, false, true)
	for k in 5:
		var a := TAU * float(k) / 5.0
		_blob(g, top + Vector3(cos(a) * 0.17, -0.22 - 0.06 * float(k % 2), sin(a) * 0.17), Vector3(0.11, 0.12, 0.11), _c("6f8a3a"), 3, 6)
	for k in 9:
		var a := TAU * float(k) / 9.0 + 0.25 * float(k % 2)
		var dir := Vector3(cos(a), 0, sin(a))
		var lat := dir.cross(Vector3.UP).normalized()
		var lift := 0.7 if k % 3 == 0 else 0.45
		var col := _c("4f7a3a").lerp(_c("7a9a48"), float(k % 4) / 3.0)
		var prev := []
		for j in 7:
			var u := float(j) / 6.0
			var p: Vector3 = top + dir * (2.7 * u) + Vector3(0, lift * u - 1.9 * u * u, 0)
			var w := 0.05 + 0.34 * sin(PI * minf(u * 1.1, 1.0))
			var tang: Vector3 = dir * 2.7 + Vector3(0, lift - 3.8 * u, 0)
			var up := lat.cross(tang).normalized()
			if up.y < 0.0:
				up = -up
			var row := [p - lat * w - up * w * 0.25, p + up * 0.03, p + lat * w - up * w * 0.25]
			if not prev.is_empty():
				for side in [1.0, -1.0]:
					var ids := []
					for q in prev + row:
						ids.append(g.vert(q, up * side, col, NB))
					for e in 2:
						g.tri(ids[e], ids[e + 1], ids[e + 4])
						g.tri(ids[e], ids[e + 4], ids[e + 3])
			prev = row
	var m: ArrayMesh = g.commit()
	_cache["palm"] = m
	return m


## Thân cây cao 2,4 m tâm ở giữa (như CylinderMesh cũ: shader thân cây hạ theo trục y khi cây chắn trước An), gốc
## loe, hơi cong.
static func trunk() -> ArrayMesh:
	if _cache.has("trunk"):
		return _cache.trunk
	var g = Character.Mesher.new(false)
	var bark := Color(1, 1, 1)
	_loft(g, [_r(Vector3(0, -1.2, 0), 0.21, 0.21, bark), _r(Vector3(0, -0.9, 0), 0.17, 0.17, bark), _r(Vector3(0.03, 0.6, 0.02), 0.14, 0.14, bark),
		_r(Vector3(0.0, 1.3, -0.02), 0.11, 0.11, Color(0.9, 0.9, 0.9))], 6, false, true)
	var m: ArrayMesh = g.commit()
	_cache["trunk"] = m
	return m
