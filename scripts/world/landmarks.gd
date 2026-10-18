extends RefCounted
## Địa danh dựng bằng khối, cùng phong cách với phố nhà ống.
## Gốc tọa độ ở giữa mép trước, mặt tiền nhìn về +z, đáy tại y = 0.

const CREAM := Color("efe0a6")
const CREAM_DARK := Color("d8c27e")
const TRIM := Color("f6efd8")
const DARK := Color("2a2622")
const NEON_BLUE := Color("3fb6ff")
const NEON_RED := Color("ff3b3b")

var font: Font
var _mats := {}
## Đèn neon: bật sáng theo giờ bằng set_night().
var _neon: Array[StandardMaterial3D] = []


func _init(label_font: Font) -> void:
	font = label_font


## glow: đèn neon (sáng mạnh ban đêm); lit: ô cửa hàng sáng đèn, dịu hơn neon.
func _mat(c: Color, glow := false, lit := false) -> StandardMaterial3D:
	var k := c.to_html() + ("g" if glow else "") + ("l" if lit else "")
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.85
		if glow or lit:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = 3.0 if glow else 0.45
		if glow:
			_neon.append(m)
		_mats[k] = m
	return _mats[k]


func _box(p: Node3D, size: Vector3, pos: Vector3, c: Color, glow := false, lit := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(c, glow, lit)
	mi.position = pos + Vector3(0, size.y / 2.0, 0)
	if glow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(mi)
	return mi


## Đĩa tròn quay mặt về +z (mặt đồng hồ, đỉnh vòm cửa).
func _disc(p: Node3D, r: float, depth: float, pos: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = depth
	mi.mesh = cm
	mi.material_override = _mat(c)
	mi.rotation.x = PI / 2.0
	mi.position = pos
	p.add_child(mi)


func _ring(p: Node3D, r: float, pos: Vector3, rot: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r - 0.12
	tm.outer_radius = r
	mi.mesh = tm
	mi.material_override = _mat(c, true)
	mi.rotation = rot
	mi.position = pos
	p.add_child(mi)


## Vòm cửa: ô tối hình chữ nhật, đỉnh nửa tròn.
func _arch(p: Node3D, x: float, w: float, h: float, z: float, c := DARK) -> void:
	_box(p, Vector3(w, h - w / 2.0, 0.1), Vector3(x, 0, z), c)
	_disc(p, w / 2.0, 0.1, Vector3(x, h - w / 2.0, z), c)


## Viền neon dọc theo mép trên một khối (trước và hai bên).
func _neon_edge(p: Node3D, x: float, w: float, y: float, z: float, d: float, c := NEON_BLUE) -> void:
	_box(p, Vector3(w, 0.12, 0.12), Vector3(x, y, z), c, true)
	for s in [-1.0, 1.0]:
		_box(p, Vector3(0.12, 0.12, d), Vector3(x + s * w / 2.0, y, z - d / 2.0), c, true)


func _clock(p: Node3D, pos: Vector3, rot_y: float) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = rot_y
	p.add_child(holder)
	_disc(holder, 1.25, 0.08, Vector3.ZERO, Color("f7f3e6"))
	_disc(holder, 0.75, 0.1, Vector3(0, 0, 0.01), Color("f2c14e"))
	_ring(holder, 1.3, Vector3(0, 0, 0.06), Vector3(PI / 2.0, 0, 0), NEON_BLUE)
	# Kim giờ và kim phút.
	var hand := _box(holder, Vector3(0.08, 0.6, 0.04), Vector3(0, 0, 0.09), DARK)
	hand.rotation.z = 0.9
	var minute := _box(holder, Vector3(0.06, 0.95, 0.04), Vector3(0, 0, 0.1), DARK)
	minute.rotation.z = -2.2


func _flag(p: Node3D, pos: Vector3, h: float, c := Color("da251d")) -> void:
	_box(p, Vector3(0.08, h, 0.08), pos, Color("c9c9c9"))
	_box(p, Vector3(1.4, 0.9, 0.04), pos + Vector3(0.72, h - 1.0, 0), c)


## Chợ Bến Thành: cổng chính có vòm lớn và chữ neon đỏ, tháp đồng hồ hai tầng mái, chóp nhọn,
## hai cánh mặt tiền nhiều vòm, mái nhà lồng phía sau viền neon đỏ.
func ben_thanh(parent: Node3D, origin: Vector3) -> Node3D:
	var p := Node3D.new()
	p.name = "cho_ben_thanh"
	p.position = origin
	parent.add_child(p)

	# Cổng chính.
	var gw := 11.0
	var gh := 8.5
	_box(p, Vector3(gw, gh, 6.0), Vector3(0, 0, -3.0), CREAM)
	_arch(p, 0, 4.6, 6.4, 0.02)
	_box(p, Vector3(4.0, 0.08, 0.05), Vector3(0, 0, 0.08), Color("4a4f55"))
	for s in [-1.0, 1.0]:
		# Trụ hai bên cổng treo băng rôn đỏ.
		_box(p, Vector3(1.4, gh + 0.5, 0.5), Vector3(s * 3.8, 0, 0.1), TRIM)
		_box(p, Vector3(0.9, 5.5, 0.06), Vector3(s * 3.8, 1.6, 0.38), Color("b8261e"))
		_box(p, Vector3(0.35, 0.35, 0.05), Vector3(s * 3.8, 5.6, 0.42), Color("f2c14e"))
		# Ô cửa sổ thông gió.
		_box(p, Vector3(1.1, 0.8, 0.05), Vector3(s * 4.9, 3.0, 0.03), CREAM_DARK)
	_box(p, Vector3(1.2, 1.4, 0.08), Vector3(0, 6.8, 0.05), Color("8a6d3b"))
	_neon_edge(p, 0, gw, gh, 0.0, 6.0)
	for s in [-1.0, 1.0]:
		_box(p, Vector3(0.12, gh, 0.12), Vector3(s * gw / 2.0, 0, 0.0), NEON_BLUE, true)
	var title := Label3D.new()
	title.text = "CHỢ BẾN THÀNH"
	title.font = font
	title.font_size = 150
	title.pixel_size = 0.01
	title.modulate = Color("ff5a4a")
	title.outline_modulate = Color(0.6, 0.05, 0.05, 0.8)
	title.outline_size = 18
	title.position = Vector3(0, gh + 0.85, 0.1)
	p.add_child(title)

	# Tháp đồng hồ phía sau cổng.
	var tw := 6.0
	var tz := -6.0
	var th := 16.5
	_box(p, Vector3(tw, th, tw), Vector3(0, 0, tz), CREAM)
	for s in [-1.0, 1.0]:
		_box(p, Vector3(0.12, th - gh, 0.12), Vector3(s * tw / 2.0, gh, tz + tw / 2.0), NEON_BLUE, true)
		_box(p, Vector3(0.5, th - gh, 0.4), Vector3(s * (tw / 2.0 - 0.25), gh, tz + tw / 2.0 + 0.05), TRIM)
	_clock(p, Vector3(0, 12.6, tz + tw / 2.0 + 0.05), 0.0)
	_clock(p, Vector3(tw / 2.0 + 0.05, 12.6, tz), PI / 2.0)
	_clock(p, Vector3(-tw / 2.0 - 0.05, 12.6, tz), -PI / 2.0)
	# Hai tầng mái xòe, viền neon.
	_box(p, Vector3(tw + 2.2, 0.35, tw + 2.2), Vector3(0, th, tz), TRIM)
	_neon_edge(p, 0, tw + 2.2, th + 0.1, tz + (tw + 2.2) / 2.0, tw + 2.2)
	_box(p, Vector3(tw - 0.6, 1.6, tw - 0.6), Vector3(0, th + 0.35, tz), CREAM)
	_box(p, Vector3(1.6, 0.6, 0.05), Vector3(-1.4, th + 0.8, tz + (tw - 0.6) / 2.0 + 0.01), Color("5b6b7a"))
	_box(p, Vector3(1.6, 0.6, 0.05), Vector3(1.4, th + 0.8, tz + (tw - 0.6) / 2.0 + 0.01), Color("5b6b7a"))
	_box(p, Vector3(tw + 1.4, 0.35, tw + 1.4), Vector3(0, th + 1.95, tz), TRIM)
	_neon_edge(p, 0, tw + 1.4, th + 2.05, tz + (tw + 1.4) / 2.0, tw + 1.4)
	_box(p, Vector3(2.0, 0.8, 2.0), Vector3(0, th + 2.3, tz), CREAM)
	# Chóp nhọn có hai vòng.
	_box(p, Vector3(0.14, 3.6, 0.14), Vector3(0, th + 3.1, tz), Color("dfe6ee"))
	for y in [th + 3.6, th + 4.4]:
		_ring(p, 0.45, Vector3(0, y, tz), Vector3.ZERO, Color("bfe6ff"))

	# Hai cánh mặt tiền, mỗi cánh ba vòm; vòm có cửa hàng sáng đèn.
	var ww := 16.0
	var wh := 6.0
	for s in [-1.0, 1.0]:
		var cx: float = s * (gw / 2.0 + ww / 2.0)
		_box(p, Vector3(ww, wh, 5.0), Vector3(cx, 0, -2.6), CREAM)
		_neon_edge(p, cx, ww, wh, -0.1, 5.0)
		for k in 3:
			var ax: float = cx + s * (-ww / 2.0 + 2.8 + k * 5.0)
			_arch(p, ax, 3.6, 4.8, -0.08, Color("4a4038"))
			_box(p, Vector3(3.0, 2.6, 0.05), Vector3(ax, 0.3, -0.02), Color("f3dfb8"), false, true)
		_flag(p, Vector3(cx + s * 2.0, wh, -1.0), 3.2, Color("da251d") if s < 0 else Color("f2c14e"))

	# Mái nhà lồng phía sau: các dãy mái dốc, viền neon đỏ.
	for k in [-1, 0, 1]:
		var rx: float = float(k) * 12.0
		for side in [-1.0, 1.0]:
			var roof := _box(p, Vector3(10.0, 0.25, 6.5), Vector3(rx, 6.6, -14.0 + side * 2.6), Color("8c3b2a"))
			roof.rotation.x = side * 0.42
			var edge := _box(p, Vector3(10.0, 0.12, 0.12), Vector3(rx, 6.0, -14.0 + side * 5.5), NEON_RED, true)
			edge.rotation.x = 0.0
		_box(p, Vector3(10.0, 0.12, 0.12), Vector3(rx, 7.95, -14.0), NEON_RED, true)
		_box(p, Vector3(10.0, 6.0, 10.0), Vector3(rx, 0, -14.0), CREAM_DARK)
	return p


## Bật hay tắt đèn neon (ban ngày vẫn thấy màu, ban đêm phát sáng).
func set_night(amount: float) -> void:
	for m in _neon:
		m.emission_energy_multiplier = lerpf(0.3, 3.0, clampf(amount, 0.0, 1.0))
