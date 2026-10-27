extends RefCounted
## Công trình nhận diện của map phố cổ (story.landmarks trong data/maps/<id>_story.json, sinh bởi
## tools/gen_phocu_map.py), dựng thêm lên trên nhà, đường của area_builder.gd:
## - truss: dàn thép cầu Long Biên (hai bên thành cầu, nóc cong từng nhịp, thanh xiên, giằng ngang trên đầu);
## - viaduct_top: mặt cầu cạn đường sắt trên dãy vòm Phùng Hưng (bản bê tông, lan can thấp, hai đường ray);
## - arches: ô vòm tối trên mặt tường dãy vòm (chỗ tiệm sửa xe, hàn tiện);
## - gables: ba đầu hồi mặt tiền chợ Đồng Xuân;
## - thap_rua: Tháp Rùa ba tầng giữa hồ; red_bridge: lan can đỏ cầu Thê Húc;
## - label: chữ lớn tên khu, chỉ hiện khi An tới gần (nhóm near_tag, tầm LABEL_RANGE m) hay khi thu nhỏ.

const LABEL_RANGE := 60.0
const RUST := Color("5b4a40")
const CONCRETE := Color("8d867b")
const RAIL := Color("3a3632")


static func build(world: Node3D, list: Array, font: Font) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for lm in list:
		match str(lm.get("kind", "")):
			"truss":
				_truss(st, _v2(lm.a), _v2(lm.b), float(lm.get("w", 9.0)), float(lm.get("h", 9.0)), int(lm.get("spans", 2)))
			"viaduct_top":
				_viaduct(st, _v2(lm.a), _v2(lm.b), float(lm.get("y", 7.4)), float(lm.get("w", 14.0)))
			"arches":
				_arches(st, _v2(lm.a), _v2(lm.b), float(lm.get("h", 5.0)), float(lm.get("step", 6.0)))
			"gables":
				_gables(st, _v2(lm.a), _v2(lm.b), int(lm.get("n", 3)), float(lm.get("h", 12.0)), Color(str(lm.get("col", "d8c39b"))))
			"thap_rua":
				_thap_rua(st, _v2(lm.pos))
			"red_bridge":
				_red_bridge(st, _v2(lm.a), _v2(lm.b))
			"label":
				var p := _v2(lm.pos)
				var l := Label3D.new()
				l.text = str(lm.text)
				l.font = font
				l.font_size = 120
				l.outline_size = 22
				l.pixel_size = 0.01
				l.modulate = Color("fff4d8")
				l.outline_modulate = Color(0.1, 0.08, 0.06, 0.9)
				l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				l.no_depth_test = true
				l.position = Vector3(p.x, float(lm.get("y", 10.0)), p.y)
				l.add_to_group("near_tag")
				l.set_meta("range", LABEL_RANGE)
				world.add_child(l)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.85
	mi.material_override = m
	world.add_child(mi)


static func _v2(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	var n := (b - a).cross(c - a).normalized()
	# Mặt nào cũng quay lên trời hay ra ngoài để ánh nắng chiếu được (camera nhìn từ trên xuống).
	if n.y < -0.05:
		n = -n
	for p in [a, b, c]:
		st.set_color(col)
		st.set_normal(n)
		st.add_vertex(p)
	for p in [a, c, b]:
		st.set_color(col)
		st.set_normal(n)
		st.add_vertex(p)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	_tri(st, a, b, c, col)
	_tri(st, a, c, d, col)


## Thanh dầm tiết diện vuông cạnh t nối p0, p1 (đi xiên được).
static func _beam(st: SurfaceTool, p0: Vector3, p1: Vector3, t: float, col: Color) -> void:
	var d := (p1 - p0).normalized()
	var up := Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT
	var s := d.cross(up).normalized() * t / 2.0
	var u := s.cross(d).normalized() * t / 2.0
	var c := [s + u, -s + u, -s - u, s - u]
	for i in 4:
		var a: Vector3 = c[i]
		var b: Vector3 = c[(i + 1) % 4]
		_quad(st, p0 + a, p1 + a, p1 + b, p0 + b, col.darkened(0.08 * i))


## Hộp đáy giữa tại p (y là cao chân), trục dài theo d.
static func _box(st: SurfaceTool, p: Vector3, d: Vector2, len: float, h: float, wid: float, col: Color) -> void:
	var u := Vector3(d.x, 0, d.y) * len / 2.0
	var v := Vector3(-d.y, 0, d.x) * wid / 2.0
	var y := Vector3(0, h, 0)
	var c := [p - u - v, p + u - v, p + u + v, p - u + v]
	for i in 4:
		var a: Vector3 = c[i]
		var b: Vector3 = c[(i + 1) % 4]
		_quad(st, a, b, b + y, a + y, col.darkened(0.06 * (i % 2)))
	_quad(st, c[0] + y, c[1] + y, c[2] + y, c[3] + y, col.lightened(0.06))


static func _truss(st: SurfaceTool, a: Vector2, b: Vector2, w: float, h: float, spans: int) -> void:
	var d := (b - a).normalized()
	var n := d.orthogonal()
	var total := a.distance_to(b)
	var panels := maxi(4, int(total / 5.0))
	var deck := 0.4
	for side in [-1.0, 1.0]:
		var off: Vector2 = n * side * w / 2.0
		var prev_b := Vector3.ZERO
		var prev_t := Vector3.ZERO
		for i in panels + 1:
			var f := float(i) / panels
			var g := a + (b - a) * f + off
			# Nóc cong: mỗi nhịp cao dần vào giữa nhịp như dàn cầu Long Biên.
			var sf := fposmod(f * spans, 1.0)
			if i == panels:
				sf = 0.0
			var top := deck + h * (0.55 + 0.45 * sin(PI * sf))
			var pb := Vector3(g.x, deck, g.y)
			var pt := Vector3(g.x, top, g.y)
			_beam(st, pb, pt, 0.35, RUST)
			if i > 0:
				_beam(st, prev_b, pb, 0.45, RUST)
				_beam(st, prev_t, pt, 0.45, RUST)
				_beam(st, prev_b if i % 2 == 0 else prev_t, pt if i % 2 == 0 else pb, 0.25, RUST.lightened(0.05))
			prev_b = pb
			prev_t = pt
	# Giằng ngang trên đầu, thưa để vẫn thấy người đi trên cầu.
	for i in range(0, panels + 1, 3):
		var g := a + (b - a) * float(i) / panels
		var sf := fposmod(float(i) / panels * spans, 1.0)
		var top := deck + h * (0.55 + 0.45 * sin(PI * sf)) - 0.3
		_beam(st, Vector3(g.x, top, g.y) - Vector3(n.x, 0, n.y) * w / 2.0, Vector3(g.x, top, g.y) + Vector3(n.x, 0, n.y) * w / 2.0, 0.22, RUST)


static func _viaduct(st: SurfaceTool, a: Vector2, b: Vector2, y: float, w: float) -> void:
	var d := (b - a).normalized()
	var n := d.orthogonal()
	var len := a.distance_to(b)
	var mid := (a + b) / 2.0
	_box(st, Vector3(mid.x, y - 0.7, mid.y), d, len, 0.7, w, CONCRETE)
	for side in [-1.0, 1.0]:
		var o: Vector2 = mid + n * side * (w / 2.0 - 0.2)
		_box(st, Vector3(o.x, y, o.y), d, len, 0.9, 0.35, CONCRETE.darkened(0.1))
		# Hai đường ray trên tà vẹt.
		var r: Vector2 = mid + n * side * 0.72
		_box(st, Vector3(r.x, y + 0.18, r.y), d, len, 0.14, 0.12, RAIL)
	_box(st, Vector3(mid.x, y, mid.y), d, len, 0.15, 2.6, Color("6b6258"))
	var k := 0.0
	while k < len:
		var p := a + d * k
		_box(st, Vector3(p.x, y + 0.05, p.y), n, 2.4, 0.13, 0.3, Color("4e3f33"))
		k += 0.9


static func _arches(st: SurfaceTool, a: Vector2, b: Vector2, h: float, step: float) -> void:
	var d := (b - a).normalized()
	var n := d.orthogonal()
	# Ô vòm dán sát mặt tường phía ngoài (phía đường Gầm Cầu, z lớn hơn).
	if n.y < 0.0:
		n = -n
	var len := a.distance_to(b)
	var k := step / 2.0
	var dark := Color("2b241f")
	while k < len:
		var c := a + d * k + n * 0.06
		var r := step * 0.34
		var spring := h - r
		var p0 := c - d * r
		var p1 := c + d * r
		_quad(st, Vector3(p0.x, 0.05, p0.y), Vector3(p1.x, 0.05, p1.y), Vector3(p1.x, spring, p1.y), Vector3(p0.x, spring, p0.y), dark)
		var segs := 8
		var cc := Vector3(c.x, spring, c.y)
		for i in segs:
			var t0 := PI * i / segs
			var t1 := PI * (i + 1) / segs
			var q0 := c + d * r * cos(t0)
			var q1 := c + d * r * cos(t1)
			_tri(st, cc, Vector3(q0.x, spring + r * sin(t0), q0.y), Vector3(q1.x, spring + r * sin(t1), q1.y), dark)
		k += step


static func _gables(st: SurfaceTool, a: Vector2, b: Vector2, count: int, h: float, col: Color) -> void:
	var d := (b - a).normalized()
	var n := d.orthogonal()
	if n.y < 0.0:
		n = -n
	var len := a.distance_to(b)
	var gw := len / count
	for i in count:
		var big := i == count / 2
		var c := a + d * gw * (i + 0.5)
		var wid := gw * (0.62 if big else 0.5)
		var top := h + (3.0 if big else 0.0)
		var p := c + n * 0.6
		_box(st, Vector3(p.x, 0.0, p.y), d, wid, top, 1.2, col)
		var l := p - d * wid / 2.0 + n * 0.61
		var r := p + d * wid / 2.0 + n * 0.61
		_tri(st, Vector3(l.x, top, l.y), Vector3(r.x, top, r.y), Vector3(p.x + n.x * 0.61, top + wid * 0.35, p.y + n.y * 0.61), col.lightened(0.05))
		# Cửa vòm lớn và hàng cửa sổ trên mặt hồi.
		var dark := Color("3a3028")
		var dw := wid * 0.32
		var f := p + n * 0.62
		_quad(st, Vector3(f.x - d.x * dw, 0.05, f.y - d.y * dw), Vector3(f.x + d.x * dw, 0.05, f.y + d.y * dw), Vector3(f.x + d.x * dw, top * 0.42, f.y + d.y * dw), Vector3(f.x - d.x * dw, top * 0.42, f.y - d.y * dw), dark)
		for j in 3:
			var wc := f + d * (j - 1) * wid * 0.28
			_quad(st, Vector3(wc.x - d.x * 0.7, top * 0.6, wc.y - d.y * 0.7), Vector3(wc.x + d.x * 0.7, top * 0.6, wc.y + d.y * 0.7), Vector3(wc.x + d.x * 0.7, top * 0.78, wc.y + d.y * 0.7), Vector3(wc.x - d.x * 0.7, top * 0.78, wc.y - d.y * 0.7), dark)


static func _thap_rua(st: SurfaceTool, p: Vector2) -> void:
	var col := Color("c8b796")
	var y := 0.0
	for tier in [[6.0, 3.2], [4.8, 2.6], [3.6, 2.2], [2.2, 1.6]]:
		_box(st, Vector3(p.x, y, p.y), Vector2.RIGHT, tier[0], tier[1], tier[0], col.darkened(0.04 * y / 3.0))
		# Ô cửa vòm tối bốn mặt.
		var hw: float = tier[0] / 2.0 + 0.02
		var ow: float = tier[0] * 0.18
		for dir in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			var c: Vector2 = p + dir * hw
			var s: Vector2 = dir.orthogonal() * ow
			_quad(st, Vector3(c.x - s.x, y + 0.3, c.y - s.y), Vector3(c.x + s.x, y + 0.3, c.y + s.y), Vector3(c.x + s.x, y + tier[1] * 0.75, c.y + s.y), Vector3(c.x - s.x, y + tier[1] * 0.75, c.y - s.y), Color("3b332b"))
		y += tier[1]
		_box(st, Vector3(p.x, y, p.y), Vector2.RIGHT, tier[0] + 0.6, 0.25, tier[0] + 0.6, Color("9a8a70"))
		y += 0.25
	_beam(st, Vector3(p.x, y, p.y), Vector3(p.x, y + 1.6, p.y), 0.4, Color("8a7a60"))


static func _red_bridge(st: SurfaceTool, a: Vector2, b: Vector2) -> void:
	var d := (b - a).normalized()
	var n := d.orthogonal()
	var red := Color("b3261e")
	var steps := 10
	_box(st, Vector3((a.x + b.x) / 2.0, 0.0, (a.y + b.y) / 2.0), d, a.distance_to(b), 0.08, 2.6, Color("8e2a20"))
	for side in [-1.0, 1.0]:
		var prev := Vector3.ZERO
		for i in steps + 1:
			var f := float(i) / steps
			var g: Vector2 = a + (b - a) * f + n * side * 1.35
			var arch := 0.8 * sin(PI * f)
			var top := Vector3(g.x, 1.0 + arch, g.y)
			_beam(st, Vector3(g.x, 0.0, g.y), top, 0.14, red)
			if i > 0:
				_beam(st, prev, top, 0.16, red)
				_beam(st, prev - Vector3(0, 0.5, 0), top - Vector3(0, 0.5, 0), 0.08, red)
			prev = top
